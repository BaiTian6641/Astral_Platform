# SPDX-License-Identifier: MIT
"""pytest for the frame-map generator (task S02-P0#1).

Validates the S02-P0#1 acceptance "readback consistent" (pack -> unpack
round-trips) plus CRC tamper detection, blank-frame safety, and geometry.
Pure Python (no simulator). Run via `make test-model`.
"""
from __future__ import annotations

import random

import pytest

from frame_map import FrameMap, crc16, clb_tile_type, sb_tile_type, cb_tile_type

V1 = dict(R=4, C=4, W=12, N=8, K=4, EXT_IN=18)


# ---- 1. geometry -----------------------------------------------------------

def test_bitfield_widths():
    assert clb_tile_type().width == 8 * 20 + 32 * 5 == 320
    assert sb_tile_type().width == 4 * 12 * 2 + 8 == 104      # mux + N_INJ inject_en
    assert cb_tile_type().width == 18 * 6 == 108            # N_CB sel x $clog2(4W)=6
    fm = FrameMap(**V1)
    assert fm.tile_width == 532                             # CLB 320 + SB 104 + CB 108
    assert fm.column_bits == 4 * 532 == 2128
    assert fm.data_words_per_frame == (2128 + 31) // 32 == 67
    assert fm.words_per_frame == 68             # +1 CRC tail word


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
    assert j["data_words_per_frame"] == 67
    assert j["words_per_frame"] == 68
    assert j["crc"]["tail_word"] is True
    assert len(j["tile_points"]) == 8 + 32 + 48 + 8 + 18  # 8 elut + 32 iib + 48 sb-mux + 8 inj + 18 cb = 114
    # round-trip serializable
    import json
    json.loads(fm.to_json_str())
