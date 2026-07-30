# SPDX-License-Identifier: MIT
"""pack_tb_frames — golden frame generator for the frame_decoder testbenches.

Builds the bit-packed column frames (via :mod:`frame_map`, the SoT) consumed by
``tb_frame_decoder.sv`` and ``shell_tb_mgmt_packed.sv``, and writes them as
``$readmemh`` hex files plus a small ``*.mk``/JSON manifest of expected values.

The frame format is the PRODUCTION bit-packed format (``frame_map.pack_column``),
per-column, **CB(108) -> SB(120) -> logic(CLB 320 / MEM 70 / DSP 118)**, LSB-first,
plus a CRC16 tail word. This is the bridge the frame_decoder RTL decodes.

Run (repo root, venv):
    .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames

Outputs (under --out):
    dec_col0.hex     2x2 col-0 frame with a KNOWN non-trivial config (unit TB).
    img_a_col0.hex   image A = TFF on tile(0,0) eLUT0 (capstone).
    img_b_col0.hex   image B = const1 on tile(0,0) eLUT0 (capstone).
    blank_col0.hex   all-zero safe (blank) frame.
    manifest.json    expected geometry + a handful of check-points for the TBs.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

# frame_map.py lives in ethereal-tools/tools/ (same dir as this file's parent).
_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from frame_map import FrameMap

# Frozen fabric constants (match fabric_top / the 2x2 testbenches).
R, C, W, N, K, EXT_IN = 2, 2, 12, 8, 4, 18

# eLUT4 20-bit config word: {tt[15:0], ff_en, ff_rst_en, ff_rst_val, out_inv}
#   [19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv.
TFF_WORD = (0x5555 << 4) | 0b1100      # toggle: tt=0x5555, ff_en, rst_en, rst_val=0
CONST1_WORD = (0xFFFF << 4) | 0b1110   # const 1: tt=0xFFFF, ff_en, rst_en, rst_val=1


def _write_hex(path: str, words: list[int]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(f"{w & 0xFFFFFFFF:08x}\n" for w in words)


def build(fm: FrameMap) -> dict[str, list[int]]:
    """Build all frames; returns name -> word list."""
    # --- unit-TB frame: a KNOWN non-trivial config on col 0 -------------------
    # tile(0,0): elut0 tt + a couple of iib mux + a couple of cb_sel + sb mux.
    # tile(1,0): one cb_sel + one sb mux to cross the tile boundary.
    dec0 = {
        "elut0": 0x000A5A5A,            # 20-bit eLUT0 (tt=0xA5A5, ff_en=1...)
        "elut3": 0x0003C3C3,
        "iib_mux0": 18,                 # feedback sel
        "iib_mux7": 9,
        "iib_mux31": 21,
        "mux_n_0": 1,                   # SB Wilton sel
        "mux_e_5": 2,
        "mux_w_11": 3,
        "inj_en_0": 1, "inj_dir_0": 2,  # inject j=0 onto E
        "inj_en_3": 1, "inj_dir_3": 0,  # inject j=3 onto N
        "cb_sel_0": 5,
        "cb_sel_17": 40,
    }
    dec1 = {
        "cb_sel_2": 7,
        "mux_s_4": 1,
        "elut7": 0x000F0F0F,
    }
    dec_col0 = fm.pack_column(0, [dec0, dec1])

    # --- capstone images (2x2 all-CLB, col 0) --------------------------------
    img_a = fm.pack_column(0, [
        {"elut0": TFF_WORD,
         "iib_mux0": 18, "iib_mux1": 18, "iib_mux2": 18, "iib_mux3": 18},
        {},
    ])
    img_b = fm.pack_column(0, [{"elut0": CONST1_WORD}, {}])
    blank = fm.blank_column(0)

    return {
        "dec_col0": dec_col0,
        "img_a_col0": img_a,
        "img_b_col0": img_b,
        "blank_col0": blank,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default="generated/tb_frames",
                    help="output directory for hex files + manifest")
    args = ap.parse_args()

    fm = FrameMap(R=R, C=C, W=W, N=N, K=K, EXT_IN=EXT_IN)
    frames = build(fm)

    os.makedirs(args.out, exist_ok=True)
    for name, words in frames.items():
        _write_hex(os.path.join(args.out, f"{name}.hex"), words)

    manifest = {
        "params": {"R": R, "C": C, "W": W, "N": N, "K": K, "EXT_IN": EXT_IN},
        "column_data_words": fm.column_data_words(0),
        "words_per_frame": fm.column_data_words(0) + 1,
        "tff_word": TFF_WORD,
        "const1_word": CONST1_WORD,
        "frames": {name: len(words) for name, words in frames.items()},
        # expected decode checks for tb_frame_decoder (unit TB), tile(0,0):
        #   cfg_addr = {tile_idx@[8+:TIW], unit@[7:6], intra@[5:0]}; TIW=2 for 2x2.
        # NOTE on tile index: cfg_addr tile field is ROW-MAJOR (tile_idx = r*C+c,
        # matching fabric_top MY_IDX = r*C+c). For the 2x2 column-0 decode the two
        # tiles are (row0,col0)->tile 0 and (row1,col0)->tile 2 (NOT 1). The
        # dec_col0 "tile(1,0)" points below therefore use tile index 2.
        "checks": {
            "elut0":   {"tile": 0, "unit": 0, "intra": 0,  "data": 0x000A5A5A},
            "iib_mux0": {"tile": 0, "unit": 0, "intra": 8,  "data": 18},
            "iib_mux31": {"tile": 0, "unit": 0, "intra": 39, "data": 21},
            "cb_sel_0": {"tile": 0, "unit": 2, "intra": 0,  "data": 5},
            "cb_sel_17": {"tile": 0, "unit": 2, "intra": 17, "data": 40},
            "mux_n_0":  {"tile": 0, "unit": 1, "intra": 0,  "data": 1},
            "mux_e_5":  {"tile": 0, "unit": 1, "intra": 29, "data": 2},
            "inj_0":    {"tile": 0, "unit": 1, "intra": 48, "data": (2 << 1) | 1},
            # tile(row1,col0) = row-major index 2 (boundary-crossing checks):
            "t1_cb_sel_2": {"tile": 2, "unit": 2, "intra": 2, "data": 7},
            "t1_elut7":    {"tile": 2, "unit": 0, "intra": 7, "data": 0x000F0F0F},
        },
    }
    with open(os.path.join(args.out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print(f"[pack_tb_frames] wrote {len(frames)} frames + manifest to {args.out}")
    print(f"[pack_tb_frames] column_data_words={fm.column_data_words(0)} "
          f"words_per_frame={fm.column_data_words(0) + 1}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
