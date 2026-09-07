# SPDX-License-Identifier: MIT
"""Performance model — config size / OCC latency / virtual-Fmax numbers for docs/performance-model.md.

Task E0-SHL3. Every figure quoted in docs/performance-model.md is produced by this script.

Sources of truth:
  * frame_map.FrameMap            — per-tile config bitfields (interconnect v2c:
                                    CLB 320 + SB 120 + CB 90 = 530 bits/tile,
                                    frozen spec interconnect-config-v0.md
                                    section 7.4)
  * occ_top.sv FSM (occ/occ_top.sv) — WRITE/BLANK/READBACK cycle counts
  * report-E0-MAP2 / incr4c Wilton — VPR c432 CPD/Fmax (cited, not recomputed)

Geometry (frame = one column of tiles, C03 §1):
  * bits/tile  = |CLB| + |SB| + |CB|              (FrameMap.tile_width)
  * bits/col   = R * bits/tile                    (homogeneous)
  * data words = ceil(bits/col / 32)
  * frame      = data words + 1 CRC16 tail word
  * image      = sum over columns, 32-bit words little-endian-packed

OCC latency (occ_top.sv, two-segment FSM; 1 word/cycle stream):
  * WRITE    frame : 1 (accept) + N (stream) + 1 (DONE)   = N + 2 cycles
  * BLANK    frame : 1 (accept) + N (stream) + 1 (DONE)   = N + 2 cycles
  * READBACK frame : 1 (accept) + N (stream) + 1 (to CMP) + 1 (CMP) = N + 3
  N is the number of words the OCC moves (``word_count_i``); for a full frame
  the host/BMC streams the data words *plus* the frame CRC16 tail word as one
  ordinary word (OCC keeps its own CRC32 over the streamed data).

Run:  python3 ethereal-tools/tools/perf_model.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from frame_map import TT_CLB, TT_DSP, TT_MEM, FrameMap

N_REGIONS = 1  # v1 fabric descriptors (n_regions=1)


def bits_to_words(bits: int, word_w: int = 32) -> int:
    return (bits + word_w - 1) // word_w


def hom_geometry(r: int, c: int) -> dict:
    fm = FrameMap(R=r, C=c)
    data_words = fm.data_words_per_frame
    words = fm.words_per_frame  # + CRC16 tail word
    total_words = c * words * N_REGIONS
    return {
        "R": r, "C": c,
        "bits_per_tile": fm.tile_width,
        "bits_per_col": fm.column_bits,
        "data_words_per_frame": data_words,
        "words_per_frame": words,
        "frames": c * N_REGIONS,
        "total_words": total_words,
        "total_bytes": total_words * 4,
    }


def het_geometry() -> dict:
    # Reference 2x2-het layout (fabric_2x2_het.yaml, report P1 Stage 4):
    # col0 = [MEM, CLB], col1 = [DSP, CLB]  (TILE_LAYOUT[col][row]).
    layout = [[TT_MEM, TT_CLB], [TT_DSP, TT_CLB]]
    fm = FrameMap(R=2, C=2, TILE_LAYOUT=layout)
    cols = []
    total_words = 0
    for col in range(fm.C):
        dw = fm.column_data_words(col)
        words = dw + 1  # + CRC16 tail word
        cols.append({"col": col, "bits": fm.column_bits_at(col),
                     "data_words": dw, "words": words})
        total_words += words
    return {"layout": layout, "columns": cols,
            "total_words": total_words, "total_bytes": total_words * 4}


def occ_cycles(n_words: int) -> dict:
    """Cycle counts per frame, straight from the occ_top.sv FSM."""
    return {
        "write": n_words + 2,     # accept + N stream + DONE
        "blank": n_words + 2,
        "readback": n_words + 3,  # accept + N stream + to-CMP + CMP
    }


def fabric_cycles(words_per_frame: list[int]) -> dict:
    """Whole-image cycle counts (one command per frame, sequential)."""
    per = [occ_cycles(n) for n in words_per_frame]
    return {
        "write": sum(p["write"] for p in per),
        "blank": sum(p["blank"] for p in per),
        "readback": sum(p["readback"] for p in per),
        "hot_swap": sum(p["blank"] + p["write"] for p in per),
        "hot_swap_verified": sum(p["blank"] + p["write"] + p["readback"] for p in per),
    }


def us(cycles: float, f_mhz: float) -> float:
    return cycles / f_mhz  # cycles / (f_MHz) = time in microseconds


def spi_us(total_bytes: int, f_mhz: float) -> float:
    return total_bytes * 8.0 / f_mhz  # bit-serial: bytes*8 / f_MHz = us


def main() -> None:
    print("=== Config geometry (v2c tile = CLB 320 + SB 120 + CB 90 = 530 bits) ===")
    fm = FrameMap()
    print(f"tile_width={fm.tile_width} (clb={fm.clb.width} sb={fm.sb.width} cb={fm.cblock.width})")
    g22, g44 = hom_geometry(2, 2), hom_geometry(4, 4)
    gh = het_geometry()
    for g in (g22, g44):
        print(f"{g['R']}x{g['C']} hom: col={g['bits_per_col']} bits -> "
              f"{g['data_words_per_frame']} data + 1 CRC = {g['words_per_frame']} words/frame; "
              f"image = {g['frames']} frames x {g['words_per_frame']} words = "
              f"{g['total_words']} words = {g['total_bytes']} bytes")
    print(f"2x2 het: cols={gh['columns']}; image = {gh['total_words']} words = {gh['total_bytes']} bytes")

    print("\n=== OCC cycle counts (occ_top.sv FSM) ===")
    print("per-frame write/blank = N+2, readback = N+3 (N = streamed words)")
    fc44 = fabric_cycles([g44["words_per_frame"]] * 4)
    fch = fabric_cycles([c["words"] for c in gh["columns"]])
    print("4x4 hom:", fc44)
    print("2x2 het:", fch)

    print("\n=== Config time, 4x4 full image ===")
    for f in (50.0, 100.0):
        print(f"@ {f:.0f} MHz: write={us(fc44['write'], f):.2f} us, "
              f"blank+write={us(fc44['hot_swap'], f):.2f} us, "
              f"blank+write+readback={us(fc44['hot_swap_verified'], f):.2f} us")
    for fspi in (10.0, 20.0, 50.0):
        print(f"SPI @ {fspi:.0f} MHz: {spi_us(g44['total_bytes'], fspi):.1f} us "
              f"({g44['total_bytes']} bytes bit-serial)")
    print(f"2x2 het SPI @ 20 MHz: {spi_us(gh['total_bytes'], 20.0):.1f} us")
    print(f"2x2 het OCC @ 50 MHz: write={us(fch['write'], 50.0):.2f} us, "
          f"hot_swap={us(fch['hot_swap'], 50.0):.2f} us")

    print("\n=== Cross-check vs tracked artifacts ===")
    ref = json.loads(Path("generated/fabric_2x2_het/frame_map.json").read_text())
    pdw = ref["heterogeneous"]["per_column_data_words"]
    mine = [c["data_words"] for c in gh["columns"]]
    assert pdw == mine, (pdw, mine)
    assert ref["tile_width_bits"] == fm.tile_width
    print(f"het frame_map.json per_column_data_words={pdw} == computed {mine} OK; "
          f"tile_width_bits={ref['tile_width_bits']} OK")


if __name__ == "__main__":
    main()
