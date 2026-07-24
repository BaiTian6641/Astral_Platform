# SPDX-License-Identifier: MIT
"""Frame-map generator for the Ethereal Fabric (task S02-P0#1).

Produces the configuration **frame layout** — the single source of truth shared
by the bitgen (emits frames), the OCC (writes frames), and readback verify.

Frame organization (C03 §1):
  * A **frame** = one COLUMN of tiles' config bits, packed into 32-bit words
    (low-order bit/word first), plus one **CRC16 tail word** (frame-level check).
  * **frame address** = {region[3:0], col[7:0]} (C03 §1.1).
  * **blank frame** = explicit safe config (all-zero: tt=0, mux sel=0=disconnect,
    IO-T oe=0) — NOT "no config"; a deliberate electrical-quiescent pattern.

Per-tile bitfields (frozen v1, match the RTL + spec notes):
  * CLB-T: N eLUT4 x 20 bits  +  N*K IIB-mux x SELW bits   (8*20 + 32*5 = 320)
  * SB   : 4 dirs x W tracks x 2-bit select                (4*12*2 = 96)
  * tile = CLB + SB                                          (416 bits)

This module is pure Python (no simulator) -> unit-testable locally with pytest.
Run:  make test-model   (root) once the find covers ethereal-tools.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field

WORD_W = 32
CRC_W = 16


# ---------------------------------------------------------------------------
# CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, no final xor) — frame check.
# ---------------------------------------------------------------------------
def crc16(words: list[int]) -> int:
    """CRC-16 over a sequence of 32-bit data words (byte-wise, big-endian words)."""
    crc = 0xFFFF
    for w in words:
        wb = [(w >> s) & 0xFF for s in (24, 16, 8, 0)]  # word -> 4 bytes BE
        for b in wb:
            crc ^= b << 8
            for _ in range(8):
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF if (crc & 0x8000) else (crc << 1) & 0xFFFF
    return crc & 0xFFFF


# ---------------------------------------------------------------------------
# Bitfield descriptors (match the frozen specs / RTL).
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class ConfigPoint:
    name: str
    width: int


@dataclass(frozen=True)
class TileType:
    name: str
    points: tuple[ConfigPoint, ...]

    @property
    def width(self) -> int:
        return sum(p.width for p in self.points)


def clb_tile_type(N: int = 8, K: int = 4, sel_w: int = 5) -> TileType:
    nk = N * K
    pts = tuple([ConfigPoint(f"elut{i}", 20) for i in range(N)]
                + [ConfigPoint(f"iib_mux{i}", sel_w) for i in range(nk)])
    return TileType("clb_t", pts)


def sb_tile_type(W: int = 12) -> TileType:
    dirs = ("n", "s", "e", "w")
    pts = tuple(ConfigPoint(f"mux_{d}_{t}", 2) for d in dirs for t in range(W))
    return TileType("switch_box", pts)


# ---------------------------------------------------------------------------
# Frame map
# ---------------------------------------------------------------------------
@dataclass
class FrameMap:
    """Logical frame layout for an R x C fabric (v1: every tile = CLB + SB)."""

    R: int = 4
    C: int = 4
    W: int = 12
    N: int = 8
    K: int = 4
    EXT_IN: int = 18
    sel_w: int = 5
    n_regions: int = 1
    clb: TileType = field(init=False)
    sb: TileType = field(init=False)

    def __post_init__(self) -> None:
        self.clb = clb_tile_type(self.N, self.K, self.sel_w)
        self.sb = sb_tile_type(self.W)

    # -- geometry -----------------------------------------------------------
    @property
    def tile_width(self) -> int:
        return self.clb.width + self.sb.width

    @property
    def column_bits(self) -> int:
        return self.R * self.tile_width

    @property
    def data_words_per_frame(self) -> int:
        return (self.column_bits + WORD_W - 1) // WORD_W

    @property
    def words_per_frame(self) -> int:
        return self.data_words_per_frame + 1  # + CRC tail word

    def frame_addr(self, region: int, col: int) -> int:
        return ((region & 0xF) << 8) | (col & 0xFF)

    def _tile_points(self) -> list[ConfigPoint]:
        return list(self.clb.points) + list(self.sb.points)

    # -- pack / unpack ------------------------------------------------------
    def pack(self, col_config: list[dict]) -> list[int]:
        """Pack one column's per-tile config into 32-bit frame words + CRC tail.

        col_config: list of R tile-configs; each a dict {point_name: value}.
        """
        if len(col_config) != self.R:
            raise ValueError(f"expected {self.R} tile configs, got {len(col_config)}")
        pts = self._tile_points()
        bits: list[int] = []
        for tcfg in col_config:
            for p in pts:
                v = int(tcfg.get(p.name, 0))
                if not 0 <= v < (1 << p.width):
                    raise ValueError(f"{p.name} value {v} exceeds {p.width} bits")
                for b in range(p.width):           # low-order bit first
                    bits.append((v >> b) & 1)
        # pad to a whole number of words
        while len(bits) % WORD_W:
            bits.append(0)
        words = [_pack_bits(bits[i:i + WORD_W]) for i in range(0, len(bits), WORD_W)]
        words.append(crc16(words) & ((1 << CRC_W) - 1))   # CRC tail word
        return words

    def unpack(self, frame_words: list[int]) -> list[dict]:
        """Reverse of pack; verifies the CRC tail word. Raises on CRC mismatch."""
        if len(frame_words) != self.words_per_frame:
            raise ValueError(f"frame must be {self.words_per_frame} words, got {len(frame_words)}")
        data, tail = frame_words[:-1], frame_words[-1]
        expected = crc16(data) & ((1 << CRC_W) - 1)
        if expected != (tail & ((1 << CRC_W) - 1)):
            raise ValueError(f"CRC mismatch: stored {tail & 0xFFFF:#06x} != computed {expected:#06x}")
        bits: list[int] = []
        for w in data:
            for b in range(WORD_W):
                bits.append((w >> b) & 1)
        pts = self._tile_points()
        col_config: list[dict] = []
        i = 0
        for _ in range(self.R):
            tcfg: dict = {}
            for p in pts:
                v = 0
                for b in range(p.width):
                    v |= bits[i + b] << b
                i += p.width
                tcfg[p.name] = v
            col_config.append(tcfg)
        return col_config

    def blank_frame(self) -> list[int]:
        """Explicit safe config: every point = 0 (tt=0, mux sel=0=disconnect)."""
        return self.pack([{} for _ in range(self.R)])

    # -- JSON (single source of truth for bitgen + OCC + readback) ----------
    def to_json(self) -> dict:
        pts = self._tile_points()
        return {
            "version": "0.1",
            "params": {"R": self.R, "C": self.C, "W": self.W, "N": self.N,
                       "K": self.K, "EXT_IN": self.EXT_IN, "sel_w": self.sel_w,
                       "n_regions": self.n_regions},
            "tile_width_bits": self.tile_width,
            "column_bits": self.column_bits,
            "data_words_per_frame": self.data_words_per_frame,
            "words_per_frame": self.words_per_frame,
            "tile_points": [{"name": p.name, "width": p.width} for p in pts],
            "frame_addr_format": {"region": "[11:8]", "col": "[7:0]"},
            "crc": {"algorithm": "CRC-16/CCITT-FALSE", "tail_word": True, "field": "[15:0]"},
        }

    def to_json_str(self) -> str:
        return json.dumps(self.to_json(), indent=2)


def _pack_bits(bits: list[int]) -> int:
    w = 0
    for i, b in enumerate(bits):
        w |= (b & 1) << i
    return w
