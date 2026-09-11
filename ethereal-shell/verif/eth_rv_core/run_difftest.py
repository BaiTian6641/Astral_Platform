#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""RTL half of the ``eth_rv`` DiffTest loop: run the corpus on the Verilated core.

Pipeline per corpus ELF (C14 §5):

1. load the ELF with the harness's own image loader (``rv_image`` — the harness is
   used, never modified),
2. flatten it into the ``$readmemh`` image the testbench consumes
   (``tb_eth_rv_core.sv``),
3. build/run the Verilator ``--binary --timing`` model, which dumps one
   ``cycle pc rd value`` line per retired instruction plus the optional
   ``mem_addr mem_wdata mem_rmask mem_wmask`` suffix (C14 §5.2),
4. hand that dump to ``rv_difftest.py --dut dump:...`` for comparison against the
   Spike golden stream — pc/rd/value *and* the memory stream — and propagate its
   verdict.

Exit status: ``0`` when every requested ELF MATCHes (and, for ``--fault``, when the
injected fault is caught at the expected commit), ``1`` otherwise, ``2`` on a
setup/toolchain error.

Examples::

    # all four corpus programs
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --all

    # one program, with a one-cycle-latency memory (exercises the stall path)
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_model --memlat 1

    # negative control: corrupt one trace record and watch the harness catch it
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_alu --fault 12:value=0xdeadbeef
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
RTL_DIR = REPO_ROOT / "ethereal-shell" / "rtl" / "eth_rv"
HARNESS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv"
DEFAULT_CORPUS = REPO_ROOT / "generated" / "rv_difftest" / "corpus"
DEFAULT_WORK = REPO_ROOT / "generated" / "rv_difftest" / "rtl"

MEM_BASE = 0x8000_0000
"""Corpus link base (corpus/link.ld) == the core's reset PC (eth_rv_pkg RESET_PC)."""

MEM_WINDOW_BYTES = 32_768 * 8
"""Must match ``MEM_WORDS`` in tb_eth_rv_core.sv (256 KiB)."""

RTL_SOURCES = [
    RTL_DIR / "eth_rv_pkg.sv",
    RTL_DIR / "cor_alu.sv",
    RTL_DIR / "cor_muldiv.sv",
    RTL_DIR / "cor_lsu.sv",
    RTL_DIR / "cor_regfile.sv",
    RTL_DIR / "cor_decoder.sv",
    RTL_DIR / "eth_rv_core.sv",
]
TB_SOURCE = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "tb_eth_rv_core.sv"

CORPUS_PROGRAMS = ["cor_alu", "cor_mem", "cor_muldiv", "cor_model", "cor_csr", "cor_trap"]

DIVERGE_RE = re.compile(r"DIVERGENCE \((\w+)\) at commit #(\d+) \(cycle (\d+)\)")

sys.path.insert(0, str(HARNESS_DIR))

from rv_image import load_elf_image  # (imported after the sys.path insert above)


class SetupError(RuntimeError):
    """The run cannot start (toolchain, corpus, image or build problem)."""


def _tool(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise SetupError(
            f"{name} not found on PATH "
            "(verilator: PATH=$HOME/oss-cad-suite/bin:$PATH; corpus: riscv64-unknown-elf-gcc)"
        )
    return found


def run(
    argv: list[str], *, cwd: Path | None = None, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    """Run a command, echoing it unless quiet; raises SetupError on a missing tool."""
    if not quiet:
        print(f"  $ {' '.join(argv)}", flush=True)
    try:
        return subprocess.run(
            argv, cwd=cwd, capture_output=True, text=True, check=False, timeout=1800
        )
    except FileNotFoundError as exc:  # pragma: no cover - guarded by _tool()
        raise SetupError(str(exc)) from None
    except subprocess.TimeoutExpired:
        raise SetupError(f"timeout: {' '.join(argv)}") from None


def build_corpus(corpus_dir: Path) -> None:
    """Build the bare-metal corpus ELFs if they are not there yet."""
    if all((corpus_dir / f"{name}.elf").is_file() for name in CORPUS_PROGRAMS):
        return
    print(f"[rv-rtl] corpus missing under {corpus_dir}, building it")
    builder = HARNESS_DIR / "corpus" / "build_corpus.py"
    done = run([sys.executable, str(builder), "--out", str(corpus_dir)], cwd=REPO_ROOT)
    if done.returncode != 0:
        raise SetupError(f"corpus build failed:\n{done.stdout}\n{done.stderr}")


def write_memory_image(elf: Path, image_path: Path) -> tuple[int, int]:
    """Flatten an ELF into the ``$readmemh`` image the testbench loads.

    Returns ``(tohost, word_count)``. Words are indexed from :data:`MEM_BASE`, so
    the file's address N is the 64-bit word at ``MEM_BASE + 8*N`` — the same
    mapping ``tb_eth_rv_core.sv`` uses.
    """
    image = load_elf_image(elf)
    if image.entry != MEM_BASE:
        raise SetupError(
            f"{elf.name}: entry 0x{image.entry:016x} != core reset PC 0x{MEM_BASE:016x} "
            "(the v0 TB loads a window based at the corpus link address)"
        )
    words: dict[int, bytearray] = {}
    for addr, data in image.segments:
        for offset, byte in enumerate(data):
            where = addr + offset
            if not MEM_BASE <= where < MEM_BASE + MEM_WINDOW_BYTES:
                raise SetupError(
                    f"{elf.name}: segment byte 0x{where:016x} is outside the "
                    f"0x{MEM_BASE:016x}..0x{MEM_BASE + MEM_WINDOW_BYTES:016x} window"
                )
            index = (where - MEM_BASE) >> 3
            slot = words.setdefault(index, bytearray(8))
            slot[where & 7] = byte
    lines = []
    for index in sorted(words):
        lines.append(f"@{index:08x}")
        # $readmemh reads the first character as the MSB, so a little-endian
        # word lands in the file byte-reversed.
        lines.append(bytes(words[index][::-1]).hex())
    image_path.write_text("\n".join(lines) + "\n", encoding="ascii")
    return image.tohost, len(words)


def build_model(work_dir: Path, mem_lat: int, rebuild: bool) -> Path:
    """Verilate + compile the testbench; returns the executable path."""
    verilator = _tool("verilator")
    obj_dir = work_dir / f"obj_{ 'lat' + str(mem_lat) if mem_lat else 'lat0' }"
    exe = obj_dir / "Veth_rv_tb"
    if exe.is_file() and not rebuild and not _stale(exe):
        return exe
    obj_dir.mkdir(parents=True, exist_ok=True)
    argv = [
        verilator,
        "--binary",
        "--timing",
        "--top-module",
        "tb_eth_rv_core",
        "-Mdir",
        str(obj_dir),
        "-o",
        "Veth_rv_tb",
        *[str(path) for path in RTL_SOURCES],
        str(TB_SOURCE),
    ]
    done = run(argv, cwd=REPO_ROOT)
    if done.returncode != 0 or not exe.is_file():
        raise SetupError(f"verilator build failed:\n{done.stdout}\n{done.stderr}")
    return exe


@dataclass(frozen=True, slots=True)
class RtlRun:
    """Outcome of one testbench invocation."""

    elf: Path
    trace: Path
    commits: int
    status: str
    stdout: str


def _stale(exe: Path) -> bool:
    """True when any RTL/TB source is newer than the built model."""
    built = exe.stat().st_mtime
    return any(path.stat().st_mtime > built for path in [*RTL_SOURCES, TB_SOURCE])


def run_rtl(
    exe: Path, elf: Path, work_dir: Path, *, mem_lat: int, fault: str | None, quiet: bool
) -> RtlRun:
    """Run the RTL on one ELF and produce its commit trace file."""
    stem = elf.stem if fault is None else f"{elf.stem}.fault"
    image_path = work_dir / f"{elf.stem}.mem.hex"
    trace_path = work_dir / f"{stem}.trace"
    tohost, _ = write_memory_image(elf, image_path)
    argv = [
        str(exe),
        f"+mem={image_path}",
        f"+trace={trace_path}",
        f"+base=0x{MEM_BASE:x}",
        f"+tohost=0x{tohost:x}",
        f"+memlat={mem_lat}",
    ]
    if fault is not None:
        index, field, value = parse_fault(fault)
        argv += [f"+fault_index={index}", f"+fault_field={field}", f"+fault_value=0x{value:x}"]
    done = run(argv, cwd=REPO_ROOT, quiet=quiet)
    banner = "ETH_RV_TB:"
    status = next(
        (line for line in done.stdout.splitlines() if line.startswith(banner)),
        f"{banner} no status line (exit {done.returncode})",
    )
    if "PASS" not in status:
        raise SetupError(f"{elf.name}: RTL run did not complete cleanly: {status}\n{done.stdout}")
    commits = int(re.search(r"PASS (\d+) commits", status).group(1))  # type: ignore[union-attr]
    return RtlRun(
        elf=elf, trace=trace_path, commits=commits, status=status, stdout=done.stdout
    )


def parse_fault(spec: str) -> tuple[int, str, int]:
    """``INDEX:FIELD=VALUE`` -> ``(index, field, value)`` (same shape as --inject).

    ``mem_addr``/``mem_wdata`` corrupt the memory stream the trace reports, which
    is the negative control for the memory comparison (C14 §5.2).
    """
    match = re.fullmatch(
        r"(\d+):(pc|rd|value|mem_addr|mem_wdata)=(0x[0-9a-fA-F]+|\d+)", spec.strip()
    )
    if match is None:
        raise SetupError(
            f"--fault wants INDEX:{{pc,rd,value,mem_addr,mem_wdata}}=VALUE, got {spec!r}"
        )
    return int(match.group(1)), match.group(2), int(match.group(3), 0)


def compare(elf: Path, trace: Path, *, quiet: bool) -> tuple[bool, str]:
    """Run the harness comparator against the RTL dump; returns (matched, report)."""
    argv = [
        sys.executable,
        str(HARNESS_DIR / "rv_difftest.py"),
        "--elf",
        str(elf),
        "--dut",
        f"dump:{trace}",
    ]
    done = run(argv, cwd=HARNESS_DIR, quiet=quiet)
    report = (done.stdout + done.stderr).strip()
    return done.returncode == 0, report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="run_difftest.py",
        description="Run the eth_rv RTL on the DiffTest corpus and compare it with Spike",
    )
    pick = parser.add_mutually_exclusive_group()
    pick.add_argument("--all", action="store_true", help="run all four corpus programs (default)")
    pick.add_argument("--only", action="append", default=[], help="program name (repeatable)")
    parser.add_argument("--corpus-dir", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK)
    parser.add_argument("--memlat", type=int, default=0, help="memory latency in cycles")
    parser.add_argument(
        "--fault",
        default=None,
        help=(
            "negative control: INDEX:{pc,rd,value,mem_addr,mem_wdata}=VALUE corrupts one "
            "trace record (the mem_* fields exercise the memory comparison)"
        ),
    )
    parser.add_argument("--rebuild", action="store_true", help="force a Verilator rebuild")
    parser.add_argument("--quiet", action="store_true", help="only print the harness verdicts")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    programs = args.only if args.only else list(CORPUS_PROGRAMS)
    try:
        build_corpus(args.corpus_dir)
        args.work_dir.mkdir(parents=True, exist_ok=True)
        exe = build_model(args.work_dir, args.memlat, args.rebuild)
    except SetupError as exc:
        sys.stderr.write(f"[rv-rtl] error: {exc}\n")
        return 2

    failures = 0
    for name in programs:
        elf = args.corpus_dir / f"{name}.elf"
        if not elf.is_file():
            sys.stderr.write(f"[rv-rtl] error: no such corpus ELF: {elf}\n")
            return 2
        try:
            rtl = run_rtl(exe, elf, args.work_dir, mem_lat=args.memlat, fault=args.fault, quiet=args.quiet)
        except SetupError as exc:
            sys.stderr.write(f"[rv-rtl] error: {exc}\n")
            return 2

        if args.fault is None:
            matched, report = compare(elf, rtl.trace, quiet=args.quiet)
            print(f"[rv-rtl] {name}: {rtl.status}")
            print(report)
            if matched:
                continue
            failures += 1
        else:
            index, field, value = parse_fault(args.fault)
            matched, report = compare(elf, rtl.trace, quiet=args.quiet)
            print(f"[rv-rtl] {name}: negative control {field}@#{index}=0x{value:x}")
            print(report)
            caught = DIVERGE_RE.search(report)
            if matched or caught is None or int(caught.group(2)) != index:
                sys.stderr.write(
                    f"[rv-rtl] error: fault injection not caught at commit #{index}\n"
                )
                failures += 1
            else:
                print(
                    f"[rv-rtl] OK: harness caught the injected {field} fault at commit "
                    f"#{caught.group(2)} (cycle {caught.group(3)}, kind {caught.group(1)})"
                )

    if failures:
        print(f"[rv-rtl] FAIL: {failures} of {len(programs)} corpus program(s) did not match")
        return 1
    verb = "negative control caught" if args.fault is not None else "MATCH vs Spike"
    print(f"[rv-rtl] OK: {len(programs)} corpus program(s), {verb}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
