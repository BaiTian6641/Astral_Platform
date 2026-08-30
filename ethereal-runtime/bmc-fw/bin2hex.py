#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""bin2hex.py — convert a raw binary firmware image to a $readmemh hex image.

Reads a little-endian rv32 binary (bmc-fw .bin) and writes one 32-bit word per
line as %08x, for backdoor $readmemh preload into the NEORV32 IMEM ROM (the
same format gen_bmc_hello.py emits). Pads to a 4-byte boundary.

Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2.
"""

from __future__ import annotations

import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    # argv[3] (optional): pad the image to this many 32-bit words (with 0x0),
    # matching the IMEM ROM physical depth so $readmemh fills the whole array
    # (silences the "not enough words" range warning; the tail never executes).
    if len(argv) not in (3, 4):
        print(f"usage: {argv[0]} <in.bin> <out.hex> [pad_words]", file=sys.stderr)
        return 2
    data = Path(argv[1]).read_bytes()
    # pad to a whole 32-bit word
    pad = (-len(data)) % 4
    if pad:
        data += b"\x00" * pad
    lines = []
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i : i + 4], byteorder="little")
        lines.append(f"{word:08x}")
    if len(argv) == 4:
        target = int(argv[3], 0)
        while len(lines) < target:
            lines.append("00000000")
    Path(argv[2]).write_text("\n".join(lines) + "\n")
    print(f"[bin2hex] {len(data)} bytes -> {len(lines)} words -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
