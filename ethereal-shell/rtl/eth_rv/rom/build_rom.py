#!/usr/bin/env python3
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""Build the eth_rv BootROM image (``boot_rom.S`` -> ``boot_rom.hex``).

The BootROM is a flat 4 KiB region at ``0x0000_1000`` holding the M-mode reset
stub the core executes first (see ``boot_rom.S`` for the handoff contract). This
script assembles + links it with the corpus toolchain and writes the
``$readmemh`` image the testbench preloads into ``eth_rv_boot_rom`` via
``+rom=<file>``:

    @<word_index:04x>
    <word value:08x>

``word_index`` is the 32-bit word index inside the 4 KiB region; the value is
the word itself (``$readmemh`` reads the first character as the MSB, so a word
value is written big-endian hex, exactly like the corpus hex fixtures). Only
non-zero words are written — the testbench zero-fills the array before loading,
so the image is deterministic without spelling out 1024 zeros.

The entry word (``ROM_ENTRY_OFF`` = 32, words 8/9) is what the harness patches at
run time, so ``--entry`` here only fixes the *default* image (an image that boots
the ordinary corpus at its link base).

Usage::

    python3 rtl/eth_rv/rom/build_rom.py                 # (re)write boot_rom.hex
    python3 rtl/eth_rv/rom/build_rom.py --check         # verify it is up to date
    python3 rtl/eth_rv/rom/build_rom.py --out /tmp/bad.hex --a1 0xdead0000
                        # deliberately wrong a1: the negative control for the TB's
                        # boot-handshake check (must make the run FAIL)
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
REPO_ROOT = HERE.parents[3]
CORPUS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv" / "corpus"

def corpus_builder() -> ModuleType:
    """Import ``build_corpus`` (``verif/eth_rv/corpus``) at run time.

    Imported by NAME rather than ``sys.path`` + ``from … import …``: the corpus
    directory is not a mypy root, and this keeps the toolchain lookup and the
    ISA/flags in exactly one place while staying ``mypy --strict`` clean. The ROM
    is a companion of the corpus image, so it must be assembled exactly like it.
    """
    if str(CORPUS_DIR) not in sys.path:
        sys.path.insert(0, str(CORPUS_DIR))
    return importlib.import_module("build_corpus")

ROM_BASE = 0x00001000
ROM_BYTES = 4096
ROM_WORDS = ROM_BYTES // 4
ROM_STEP_WORD = 7   # offset 28: the stub's instruction count (boot_rom.S, linker-derived)
ROM_ENTRY_WORD = 8  # offset 32: the 64-bit payload entry (boot_rom.S)
DTB_ADDR = 0x80002000
DEFAULT_ENTRY = 0x80000000

DEFAULT_OUT = HERE / "boot_rom.hex"


def header(stub_steps: int) -> str:
    """The image header. `stub_steps` is read back OUT of the built image (word
    ROM_STEP_WORD), so the file states the number the CLINT will actually
    swallow — a value the linker derived from the stub's own bytes."""
    return (
        "# eth_rv boot rom hex v1\n"
        f"# base 0x{ROM_BASE:08x} bytes {ROM_BYTES} words {ROM_WORDS} "
        f"step_word {ROM_STEP_WORD} stub_steps {stub_steps} entry_word {ROM_ENTRY_WORD}\n"
        "# generated from boot_rom.S by rtl/eth_rv/rom/build_rom.py -- do not edit\n"
    )


def image_word(image: bytes, index: int) -> int:
    """One 32-bit word of the built image."""
    return int.from_bytes(image[index * 4 : index * 4 + 4], "little")


def build_binary(*, a1: int, entry: int, tmp: Path) -> bytes:
    """Assemble + link the stub, and return the zero-padded 4 KiB image bytes."""
    corpus = corpus_builder()
    # The corpus flags minus the `-Wl,` ones: assembling/linking is split into two
    # commands below, and a link option on the `-c` command is at best noise.
    asflags = tuple(flag for flag in corpus.CFLAGS if not flag.startswith("-Wl,"))
    gcc = str(corpus.find_toolchain("gcc"))
    obj = tmp / "boot_rom.o"
    elf = tmp / "boot_rom.elf"
    binary = tmp / "boot_rom.bin"
    steps = [
        [gcc, *asflags, f"-DDTB_ADDR={a1:#x}",
         "-c", str(HERE / "boot_rom.S"), "-o", str(obj)],
        [
            gcc,
            *corpus.CFLAGS,
            f"-Wl,--defsym=PAYLOAD_ENTRY={entry:#x}",
            "-Wl,-T," + str(HERE / "boot_rom.ld"),
            str(obj),
            "-o",
            str(elf),
        ],
        [str(corpus.find_toolchain("objcopy")), "-O", "binary", str(elf), str(binary)],
    ]
    for argv in steps:
        proc = subprocess.run(argv, capture_output=True, text=True, check=False)
        if proc.returncode != 0:
            sys.stderr.write(proc.stdout + proc.stderr)
            raise SystemExit(f"boot ROM build failed: {' '.join(argv)}")
        if proc.stderr.strip():
            sys.stderr.write(proc.stderr)
    image = binary.read_bytes()
    if len(image) > ROM_BYTES:
        raise SystemExit(f"boot ROM image is {len(image)} bytes, region is {ROM_BYTES}")
    return image + bytes(ROM_BYTES - len(image))


def image_to_hex(image: bytes) -> str:
    """Render the 4 KiB image as the sparse ``$readmemh`` text the TB loads."""
    steps = image_word(image, ROM_STEP_WORD)
    if steps == 0:
        raise SystemExit("the built ROM has no stub step count (word "
                         f"{ROM_STEP_WORD}): did boot_rom.S lose its _rom_steps word?")
    lines = [header(steps)]
    for index in range(ROM_WORDS):
        word = image_word(image, index)
        if word:
            lines.append(f"@{index:04x} {word:08x}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="hex image to write")
    parser.add_argument("--entry", type=lambda s: int(s, 0), default=DEFAULT_ENTRY,
                        help="payload entry baked into the image (default: the RAM base)")
    parser.add_argument("--a1", type=lambda s: int(s, 0), default=DTB_ADDR,
                        help="DTB address the stub leaves in a1 (default: the contract value)")
    parser.add_argument("--check", action="store_true",
                        help="do not write: fail if --out does not match a fresh build")
    args = parser.parse_args(argv)

    with tempfile.TemporaryDirectory(prefix="eth_rv_rom_") as tmpdir:
        image = build_binary(a1=args.a1, entry=args.entry, tmp=Path(tmpdir))
    text = image_to_hex(image)
    if args.check:
        current = args.out.read_text(encoding="ascii") if args.out.is_file() else ""
        if current != text:
            raise SystemExit(f"{args.out} is out of date: rerun build_rom.py")
        print(f"[eth_rv rom] {args.out} is up to date ({len(text.splitlines())} lines)")
        return 0
    args.out.write_text(text, encoding="ascii")
    print(f"[eth_rv rom] wrote {args.out} ({len(text.splitlines())} lines, "
          f"stub_steps={image_word(image, ROM_STEP_WORD)}, "
          f"entry=0x{args.entry:016x}, a1=0x{args.a1:016x})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
