#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the ``eth_rv`` DiffTest corpus: bare-metal RV64IMFDC ELFs + hex fixtures.

Every ``corpus/cor_*.S`` is linked against ``corpus/crt0.S`` and
``corpus/link.ld`` with the local bare-metal toolchain and written to
``generated/rv_difftest/corpus/<name>.elf`` (gitignored — nothing here is
vendored).

``--hex-out DIR`` additionally emits the self-describing hex images consumed by
the Python model DUT (:mod:`rv_model`), and ``--golden-out DIR`` runs each
program under Spike (needs the built spike) and writes both the raw
``--log-commits`` output and the canonical golden trace.

All three kinds of file are checked into ``tests/fixtures`` so pytest can verify
the model DUT and the trace normalizer with neither the toolchain nor Spike
present. The tracked raw log is truncated :data:`LOG_TAIL_LINES` lines past the
HTIF exit store; the truncation is deterministic, so regenerating reproduces it.

Usage::

    python3 corpus/build_corpus.py                                    # build all programs
    python3 corpus/build_corpus.py --only cor_alu                     # one program
    python3 corpus/build_corpus.py --only cor_model \\
        --hex-out tests/fixtures --golden-out tests/fixtures          # refresh fixtures
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ETH_RV_DIR = HERE.parent
REPO_ROOT = HERE.parents[2]
DEFAULT_OUT_DIR = REPO_ROOT / "generated" / "rv_difftest" / "corpus"

TOOLCHAIN_PREFIX = "riscv64-unknown-elf-"
MARCH = "rv64imafdc_zicsr_zicntr"
"""ISA the corpus is built for: RV64IMAFDC + the CSR instructions.

``I``/``M``/``A``/``F``/``D``/``C`` are what the core implements and advertises in
``misa`` (0x800000000014112d) — ``A`` being lr/sc/amo, which ``cor_atomic.S``
exercises, and ``wfi`` (which needs no extension letter) in ``cor_wfi.S``;
``Zicsr`` is not implied by ``I`` in binutils any
more, so the CSR/FP-control programs need it spelled out. It changes nothing for
the integer programs — they contain no FP or CSR instruction and assemble to the
same bytes. Spike enables ``zicsr`` by default for this ISA string, and the whole
corpus is built with ``-mabi=lp64`` (soft-float ABI): the FP programs drive the
FP registers directly and never call libc."""
MABI = "lp64"

CFLAGS: tuple[str, ...] = (
    f"-march={MARCH}",
    f"-mabi={MABI}",
    "-mcmodel=medany",  # PC-relative `la`: absolute LUI cannot express 0x8000_xxxx on RV64
    "-mno-relax",  # keep the authored encodings (and their compressed forms) intact
    "-nostdlib",
    "-nostartfiles",
    "-ffreestanding",
    "-fno-builtin",
    "-Wl,--build-id=none",
    "-Wl,--no-warn-rwx-segments",  # one PT_LOAD covers text+data in the flat corpus image
)


def find_toolchain(name: str) -> str:
    """Locate ``riscv64-unknown-elf-<name>`` (``$RISCV_PREFIX`` wins, then PATH, then ~/tools)."""
    override = os.environ.get("RISCV_PREFIX")
    candidates: list[Path] = []
    if override:
        candidates.append(Path(override) / f"{TOOLCHAIN_PREFIX}{name}")
    candidates.append(Path(Path.home() / "tools" / "riscv" / "usr" / "bin" / f"{TOOLCHAIN_PREFIX}{name}"))
    on_path = shutil.which(f"{TOOLCHAIN_PREFIX}{name}")
    if on_path:
        candidates.append(Path(on_path))
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    raise SystemExit(
        f"toolchain not found: {TOOLCHAIN_PREFIX}{name}\n"
        "set $RISCV_PREFIX to the toolchain bin directory, or put "
        f"{TOOLCHAIN_PREFIX}gcc on PATH (see README.md)"
    )


def corpus_sources() -> list[Path]:
    return sorted(HERE.glob("cor_*.S"))


def build_one(source: Path, out_dir: Path, *, verbose: bool = False) -> Path:
    """Compile+link one corpus program; returns the ELF path."""
    gcc = find_toolchain("gcc")
    out_dir.mkdir(parents=True, exist_ok=True)
    elf = out_dir / f"{source.stem}.elf"
    argv = [
        gcc,
        *CFLAGS,
        "-Wl,-T," + str(HERE / "link.ld"),
        str(HERE / "crt0.S"),
        str(source),
        "-o",
        str(elf),
    ]
    if verbose:
        print("+ " + " ".join(argv))
    proc = subprocess.run(argv, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit(f"build failed: {source.name} (exit {proc.returncode})")
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)
    return elf


LOG_TAIL_LINES = 50
"""Raw-log lines kept after the HTIF exit store when writing a tracked log fixture."""


def elf_to_hex(elf: Path, out_path: Path) -> None:
    """Write the ELF's loaded segments as a self-describing hex image (model input)."""
    sys.path.insert(0, str(ETH_RV_DIR))
    from rv_image import (
        load_elf_image,
    )

    image = load_elf_image(elf)
    lines = [
        "# rv_difftest hex image v1",
        f"# entry 0x{image.entry:016x}",
        f"# tohost 0x{image.tohost:016x}",
        f"# generated from {elf.name} by corpus/build_corpus.py --hex-out",
        f"# corpus source: {elf.stem}.S   (checked in so pytest needs no toolchain)",
        "# all-zero words are omitted: memory is zero-initialised in both simulators",
    ]
    for addr, data in image.segments:
        for offset in range(0, len(data), 16):
            chunk = data[offset : offset + 16]
            # words are hex *values* (the loader stores them little-endian), not raw bytes
            words = [
                int.from_bytes(chunk[i : i + 4], "little")
                for i in range(0, len(chunk) - len(chunk) % 4, 4)
            ]
            if not any(words):
                continue
            lines.append(f"@{addr + offset:08x} " + " ".join(f"{word:08x}" for word in words))
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_golden_fixtures(elf: Path, out_dir: Path, *, spike: str | Path | None = None) -> tuple[int, Path, Path]:
    """Write the tracked golden fixtures for ``elf``: the raw log and the canonical trace.

    Returns ``(golden commit count, raw log path, canonical trace path)``. The raw
    log is truncated :data:`LOG_TAIL_LINES` lines past the HTIF exit store so the
    checked-in file stays small; the canonical trace is what ``--golden`` consumes.
    """
    sys.path.insert(0, str(ETH_RV_DIR))
    from rv_image import load_elf_image
    from rv_spike import (
        DEFAULT_ISA,
        last_golden_line,
        run_spike,
        trace_text_for_elf,
    )

    image = load_elf_image(elf)
    run = run_spike(elf, spike=spike)
    lines = run.log.splitlines()
    last = last_golden_line(run.log, source=str(elf), tohost=image.tohost, entry=image.entry)
    kept = lines[: last + 1 + LOG_TAIL_LINES] if last >= 0 else lines
    log_path = out_dir / f"{elf.stem}.spike_log.txt"
    log_path.write_text(
        "\n".join(
            [
                f"# raw output of: spike --isa={DEFAULT_ISA} -l --log-commits --log=... {elf.name}",
                f"# {run.version} · generator: corpus/build_corpus.py --golden-out",
                (
                    f"# truncated after {LOG_TAIL_LINES} lines past the HTIF exit store "
                    f"(line {last + 1}); the golden stream ends there ({len(run.commits)} commits)"
                ),
                *kept,
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    trace_path = out_dir / f"{elf.stem}.trace"
    trace_text, _ = trace_text_for_elf(elf, spike=spike)
    trace_path.write_text(trace_text, encoding="utf-8")
    return len(run.commits), log_path, trace_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT_DIR, help="ELF output directory")
    parser.add_argument("--only", action="append", default=[], help="build only this program (repeatable)")
    parser.add_argument("--hex-out", type=Path, default=None, help="also emit <name>.hex here")
    parser.add_argument(
        "--golden-out", type=Path, default=None, help="also emit <name>.spike_log.txt and <name>.trace here"
    )
    parser.add_argument("--spike", type=Path, default=None, help="spike binary for --golden-out")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    sources = corpus_sources()
    if args.only:
        wanted = set(args.only)
        sources = [s for s in sources if s.stem in wanted]
        missing = wanted - {s.stem for s in sources}
        if missing:
            raise SystemExit(f"no such corpus program: {', '.join(sorted(missing))}")
    if not sources:
        raise SystemExit("no corpus programs found")

    print(f"[corpus] toolchain: {find_toolchain('gcc')}")
    print(f"[corpus] march={MARCH} mabi={MABI} mcmodel=medany -nostdlib")
    for source in sources:
        elf = build_one(source, args.out, verbose=args.verbose)
        size = elf.stat().st_size
        print(f"[corpus] {source.name:16s} -> {elf} ({size} bytes)")
        if args.hex_out is not None:
            args.hex_out.mkdir(parents=True, exist_ok=True)
            hex_path = args.hex_out / f"{source.stem}.hex"
            elf_to_hex(elf, hex_path)
            print(f"[corpus]   hex image -> {hex_path}")
        if args.golden_out is not None:
            args.golden_out.mkdir(parents=True, exist_ok=True)
            commits, log_path, trace_path = write_golden_fixtures(
                elf, args.golden_out, spike=args.spike
            )
            print(f"[corpus]   {commits} golden commits -> {log_path.name}, {trace_path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
