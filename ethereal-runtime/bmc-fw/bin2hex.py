#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""bin2hex.py — convert raw binary firmware images to $readmemh hex images.

Two modes:

  bin2hex.py <in.bin> <out.hex> [pad_words]
      Word mode: one 32-bit word per line as %08x, for the IMEM ROM backdoor
      (same format gen_bmc_hello.py emits). Pads to a 4-byte boundary;
      pad_words pads with zero words to the ROM's physical depth.

  bin2hex.py --lanes <N> <depth> <in.bin> <out_prefix>
      Byte-lane mode (E1-RUN2 DMEM-exec bootstrap): splits the image into N
      byte lanes and writes <out_prefix>{0..N-1}.hex, one %02x byte per line,
      lane k holding bytes [k::N] at word index (offset // N) — matching the
      NEORV32 dmem_ram byte-lane spram arrays. Each lane file is padded with
      zero bytes to <depth> entries (silences the $readmemh range warning).

Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2.
"""

from __future__ import annotations

import sys
from pathlib import Path


def _lanes(argv: list[str]) -> int:
    # bin2hex.py --lanes <N> <depth> <in.bin> <out_prefix>
    if len(argv) != 6:
        print(
            f"usage: {argv[0]} --lanes <N> <depth> <in.bin> <out_prefix>",
            file=sys.stderr,
        )
        return 2
    n_lanes = int(argv[2], 0)
    depth = int(argv[3], 0)
    data = Path(argv[4]).read_bytes()
    out_prefix = argv[5]
    pad = (-len(data)) % n_lanes
    if pad:
        data += b"\x00" * pad
    lanes = [bytearray() for _ in range(n_lanes)]
    for off in range(0, len(data), n_lanes):
        for k in range(n_lanes):
            lanes[k].append(data[off + k])
    for k in range(n_lanes):
        if len(lanes[k]) > depth:
            print(f"[bin2hex] ERROR: lane {k} overflow ({len(lanes[k])} > {depth})",
                  file=sys.stderr)
            return 1
        lanes[k] += b"\x00" * (depth - len(lanes[k]))
        out = Path(f"{out_prefix}{k}.hex")
        out.write_text("\n".join(f"{b:02x}" for b in lanes[k]) + "\n")
    print(f"[bin2hex] {len(data)} bytes -> {n_lanes} lanes x {depth} -> "
          f"{out_prefix}{{0..{n_lanes - 1}}}.hex")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "--lanes":
        return _lanes(argv)
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
