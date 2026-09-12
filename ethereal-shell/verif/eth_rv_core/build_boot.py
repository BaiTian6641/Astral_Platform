#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build ``cor_boot``: the BootROM-handoff corpus program (E2-RV2 increment 5).

The rest of the corpus is built by ``verif/eth_rv/corpus/build_corpus.py`` from a
single linker script based at the memory window base. ``cor_boot`` is linked at
``0x8000_1000`` on purpose — its whole point is that the core can only reach it
through the BootROM's jump (see ``cor_boot.S`` / ``cor_boot.ld``) — so it needs
its own link step. Everything else (toolchain discovery, ISA/flags, ``crt0.S``)
is shared with the corpus builder, which is IMPORTED rather than copied, so the
two builds cannot drift apart.

The ELF lands in the corpus directory next to the others, with the same name
convention, so the runner treats it as one more corpus program::

    python3 ethereal-shell/verif/eth_rv_core/build_boot.py \
        --out generated/rv_difftest/corpus

``--check`` builds into a temporary directory and only verifies the ELF already
present has the expected entry point (a cheap consistency check for CI).
"""

from __future__ import annotations

import argparse
import importlib
import subprocess
import sys
import tempfile
from pathlib import Path
from types import ModuleType

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
CORPUS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv" / "corpus"
DEFAULT_OUT = REPO_ROOT / "generated" / "rv_difftest" / "corpus"

BOOT_ENTRY = 0x8000_1000
"""Where ``cor_boot`` is linked: NOT the memory window base (the whole point)."""


def corpus_builder() -> ModuleType:
    """Import ``build_corpus`` (``verif/eth_rv/corpus``) at run time.

    Imported by NAME rather than ``sys.path`` + ``from … import …`` so that
    ``mypy --strict`` over this package — whose roots do not include the corpus
    directory — is not asked to resolve a module outside them. The toolchain and
    the ISA/flags still come from exactly one place: the corpus builder.
    """
    if str(CORPUS_DIR) not in sys.path:
        sys.path.insert(0, str(CORPUS_DIR))
    return importlib.import_module("build_corpus")


def build(out_dir: Path, *, verbose: bool = False) -> Path:
    """Compile+link ``cor_boot.elf`` into ``out_dir`` and return its path."""
    corpus = corpus_builder()
    gcc = str(corpus.find_toolchain("gcc"))
    out_dir.mkdir(parents=True, exist_ok=True)
    elf = out_dir / "cor_boot.elf"
    argv = [
        gcc,
        *corpus.CFLAGS,
        "-Wl,-T," + str(HERE / "cor_boot.ld"),
        str(CORPUS_DIR / "crt0.S"),
        str(HERE / "cor_boot.S"),
        "-o",
        str(elf),
    ]
    if verbose:
        print("+ " + " ".join(argv))
    proc = subprocess.run(argv, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit(f"build failed: cor_boot (exit {proc.returncode})")
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)
    return elf


def elf_entry(elf: Path) -> int:
    """The ELF's entry point (read without the harness, which needs the file in place)."""
    import struct

    with elf.open("rb") as handle:
        header = handle.read(0x40)
    if header[:4] != b"\x7fELF" or header[4] != 2 or header[5] != 1:  # 64-bit, little-endian
        raise SystemExit(f"{elf}: not a 64-bit little-endian ELF")
    return int(struct.unpack_from("<Q", header, 0x18)[0])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help="corpus directory to write cor_boot.elf into")
    parser.add_argument("--check", action="store_true",
                        help="only verify --out/cor_boot.elf has the expected entry")
    parser.add_argument("--verbose", action="store_true", help="echo the toolchain command")
    args = parser.parse_args(argv)

    if args.check:
        elf = args.out / "cor_boot.elf"
        if not elf.is_file():
            raise SystemExit(f"{elf} is missing: run build_boot.py")
        entry = elf_entry(elf)
        if entry != BOOT_ENTRY:
            raise SystemExit(f"{elf}: entry 0x{entry:016x} != 0x{BOOT_ENTRY:016x}")
        print(f"[cor_boot] {elf} entry 0x{entry:016x} OK")
        return 0

    with tempfile.TemporaryDirectory(prefix="cor_boot_") as tmpdir:
        staged = build(Path(tmpdir), verbose=args.verbose)
        entry = elf_entry(staged)
        if entry != BOOT_ENTRY:
            raise SystemExit(f"cor_boot linked at 0x{entry:016x}, expected 0x{BOOT_ENTRY:016x}")
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "cor_boot.elf").write_bytes(staged.read_bytes())
    print(f"[cor_boot] wrote {args.out / 'cor_boot.elf'} (entry 0x{BOOT_ENTRY:016x})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
