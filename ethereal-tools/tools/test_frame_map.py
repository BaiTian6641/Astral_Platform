# SPDX-License-Identifier: MIT
"""pytest for the frame-map generator (task S02-P0#1).

Validates the S02-P0#1 acceptance "readback consistent" (pack -> unpack
round-trips) plus CRC tamper detection, blank-frame safety, and geometry.
Pure Python (no simulator). Run via `make test-model`.
"""
from __future__ import annotations

import random

import pytest

from frame_map import (FrameMap, crc16, clb_tile_type, sb_tile_type, cb_tile_type,
                       mem_tile_type, dsp_tile_type, TT_CLB, TT_MEM, TT_DSP)

V1 = dict(R=4, C=4, W=12, N=8, K=4, EXT_IN=18)


# ---- 1. geometry -----------------------------------------------------------

def test_bitfield_widths():
    assert clb_tile_type().width == 8 * 20 + 32 * 5 == 320
    assert sb_tile_type().width == 4 * 12 * 2 + 8 + 8 * 2 == 120   # mux + inj_en + inj_dir
    assert cb_tile_type().width == 18 * 6 == 108            # N_CB sel x $clog2(4W)=6
    fm = FrameMap(**V1)
    assert fm.tile_width == 548                             # CLB 320 + SB 120 + CB 108
    assert fm.column_bits == 4 * 548 == 2192
    assert fm.data_words_per_frame == (2192 + 31) // 32 == 69
    assert fm.words_per_frame == 70             # +1 CRC tail word


# ---- 1b. heterogeneous tile types (Phase-1, Stage 4) ------------------------

def test_het_tile_type_widths():
    assert mem_tile_type().width == 16 + 22 + 32 == 70      # mode + vbus_ctrl + vd_i
    assert dsp_tile_type().width == 24 + 27 + 18 + 1 + 48 == 118  # mode+va+vb+ven+vcasc


def test_het_layout_geometry():
    # 2x2: col0=[MEM,CLB], col1=[CLB,DSP]  (matches fabric_2x2_het.yaml)
    layout = [[TT_MEM, TT_CLB], [TT_CLB, TT_DSP]]
    fm = FrameMap(R=2, C=2, TILE_LAYOUT=layout)
    # col0 = (CB108+SB120+MEM70) + (CB108+SB120+CLB320) = 298+548 = 846 bits
    assert fm.column_bits_at(0) == 846
    # col1 = (CB108+SB120+CLB320) + (CB108+SB120+DSP118) = 548+346 = 894 bits
    assert fm.column_bits_at(1) == 894
    assert fm.column_data_words(0) == (846 + 31) // 32
    assert fm.column_data_words(1) == (894 + 31) // 32
    # per-tile-type points: base CB+SB + logic
    mem_pts = {p.name for p in fm.tile_points_at(0, 0)}
    assert {"cb_sel_0", "mux_n_0", "inj_en_0", "mem_mode", "mem_vd_i"} <= mem_pts
    dsp_pts = {p.name for p in fm.tile_points_at(1, 1)}
    assert {"cb_sel_0", "mux_e_0", "dsp_mode", "dsp_vcasc"} <= dsp_pts


def test_het_pack_unpack_roundtrip():
    layout = [[TT_MEM, TT_CLB], [TT_CLB, TT_DSP]]
    fm = FrameMap(R=2, C=2, TILE_LAYOUT=layout)
    # column 0: MEM tile + CLB tile
    cfg0 = [{"mem_mode": 5, "mem_vbus_ctrl": 0x12345, "mem_vd_i": 0xCAFEBABE},
            {"elut0": 0x5555, "iib_mux0": 18}]
    f0 = fm.pack_column(0, cfg0)
    assert len(f0) == fm.column_data_words(0) + 1
    u0 = fm.unpack_column(0, f0)
    assert u0[0]["mem_mode"] == 5 and u0[0]["mem_vd_i"] == 0xCAFEBABE
    assert u0[1]["elut0"] == 0x5555 and u0[1]["iib_mux0"] == 18
    # column 1: CLB tile + DSP tile
    cfg1 = [{"elut0": 0x1234}, {"dsp_mode": 7, "dsp_va": 42, "dsp_vb": 6,
                                "dsp_ven": 1, "dsp_vcasc": 0xABCDEF}]
    f1 = fm.pack_column(1, cfg1)
    u1 = fm.unpack_column(1, f1)
    assert u1[0]["elut0"] == 0x1234
    assert u1[1]["dsp_mode"] == 7 and u1[1]["dsp_va"] == 42
    assert u1[1]["dsp_vb"] == 6 and u1[1]["dsp_vcasc"] == 0xABCDEF


def test_het_blank_column():
    layout = [[TT_MEM, TT_CLB], [TT_CLB, TT_DSP]]
    fm = FrameMap(R=2, C=2, TILE_LAYOUT=layout)
    for c in range(fm.C):
        blank = fm.blank_column(c)
        u = fm.unpack_column(c, blank)
        assert all(v == 0 for tile in u for v in tile.values())


def test_het_layout_shape_validation():
    # wrong shape (not C columns / not R rows) must raise
    import pytest as _pt
    with _pt.raises(ValueError):
        FrameMap(R=2, C=2, TILE_LAYOUT=[[TT_CLB, TT_CLB]])          # only 1 column
    with _pt.raises(ValueError):
        FrameMap(R=2, C=2, TILE_LAYOUT=[[TT_CLB], [TT_CLB]])        # only 1 row/col


def test_frame_addr_format():
    fm = FrameMap(**V1)
    assert fm.frame_addr(0, 0) == 0x000
    assert fm.frame_addr(1, 2) == 0x102          # region<<8 | col
    assert fm.frame_addr(0xF, 0xFF) == 0xFFF


# ---- 2. THE acceptance: readback round-trip --------------------------------

def _rand_col_config(fm: FrameMap, rng: random.Random) -> list[dict]:
    pts = fm._tile_points()
    return [
        {p.name: rng.getrandbits(p.width) for p in pts}
        for _ in range(fm.R)
    ]


@pytest.mark.parametrize("seed", range(300))
def test_pack_unpack_roundtrip(seed: int):
    fm = FrameMap(**V1)
    rng = random.Random(seed + 7000)
    cfg = _rand_col_config(fm, rng)
    frame = fm.pack(cfg)
    assert len(frame) == fm.words_per_frame
    back = fm.unpack(frame)
    assert back == cfg, f"round-trip mismatch (seed={seed})"


def test_pack_length_constant():
    fm = FrameMap(**V1)
    rng = random.Random(42)
    for _ in range(50):
        assert len(fm.pack(_rand_col_config(fm, rng))) == fm.words_per_frame


# ---- 3. CRC tamper detection ----------------------------------------------

def test_crc_tamper_data_detected():
    fm = FrameMap(**V1)
    frame = fm.pack(_rand_col_config(fm, random.Random(1)))
    for w_idx in range(fm.data_words_per_frame):
        bad = list(frame)
        bad[w_idx] ^= 1                          # flip one bit in a data word
        with pytest.raises(ValueError, match="CRC mismatch"):
            fm.unpack(bad)


def test_crc_tamper_tail_detected():
    fm = FrameMap(**V1)
    frame = fm.pack(_rand_col_config(fm, random.Random(2)))
    bad = list(frame)
    bad[-1] ^= 0x0001                           # corrupt the CRC tail word
    with pytest.raises(ValueError, match="CRC mismatch"):
        fm.unpack(bad)


def test_wrong_length_rejected():
    fm = FrameMap(**V1)
    with pytest.raises(ValueError, match="frame must be"):
        fm.unpack([0] * 10)


# ---- 4. blank frame (explicit safe config) --------------------------------

def test_blank_is_all_zero_and_roundtrips():
    fm = FrameMap(**V1)
    blank = fm.blank_frame()
    assert len(blank) == fm.words_per_frame
    back = fm.unpack(blank)
    # every config point is 0 (tt=0, mux sel=0=disconnect) -> electrical quiescent
    for tcfg in back:
        assert all(v == 0 for v in tcfg.values())
    # all-zero data words (only the CRC tail may differ)
    assert all(w == 0 for w in blank[:-1])


def test_blank_crc_consistency():
    fm = FrameMap(**V1)
    blank = fm.blank_frame()
    assert (blank[-1] & 0xFFFF) == (crc16(blank[:-1]) & 0xFFFF)


# ---- 5. JSON (single source of truth) -------------------------------------

def test_to_json_structure():
    fm = FrameMap(**V1)
    j = fm.to_json()
    assert j["version"] == "0.1"
    assert j["params"]["R"] == 4 and j["params"]["C"] == 4
    assert j["data_words_per_frame"] == 69
    assert j["words_per_frame"] == 70
    assert j["crc"]["tail_word"] is True
    assert len(j["tile_points"]) == 8 + 32 + 48 + 8 + 8 + 18  # 8 elut + 32 iib + 48 sb-mux + 8 inj_en + 8 inj_dir + 18 cb = 122
    # round-trip serializable
    import json
    json.loads(fm.to_json_str())
