# SPDX-License-Identifier: MIT
"""Golden reference model for ``switch_box`` — the fabric SB (task E0-FAB3).

Mirrors ``ethereal-fabric/rtl/interconnect/switch_box.sv`` bit-for-bit.
Disjoint unidirectional topology (v1, C01 §3.3): for each output track t in
each direction D in {N,S,E,W}, a registered 2-bit select picks one of the 3
SAME-INDEX input tracks of the OTHER 3 directions, or disconnects (drives 0).

cfg addressing (v1, C01 §3.3)::
    addr = DIR*W + t   ;  DIR: 0=N,1=S,2=E,3=W ;  t: 0..W-1
    data = sel         ;  0=disconnect, 1/2/3 = the 3 sources (ascending dir order)

Per-output-direction source map (sel 1/2/3 -> the 3 other dirs, ascending)::
    N(0) -> [S(1), E(2), W(3)]
    S(1) -> [N(0), E(2), W(3)]
    E(2) -> [N(0), S(1), W(3)]
    W(3) -> [N(0), S(1), E(2)]

Pure Python (no cocotb) -> unit-testable locally with pytest. Also exposes
:meth:`dependency_edges` for the fabric-level combinational-cycle detector:
each active (non-disconnect) mux yields one directed edge
``(("in", <src_dir>, t), ("out", <dst_dir>, t))``. The fabric cycle detector
composes these in->out edges with channel edges that connect an SB's
``("out", D, t)`` to the neighbor SB's ``("in", D, t)``.

Note: unconfigured selects are treated as 0 (disconnect); the RTL's ``sel_r``
has no reset and is written by OCC before un-halt (config-before-run, C03).
"""
from __future__ import annotations

DIRS = ("n", "s", "e", "w")
DIR_IDX = {"n": 0, "s": 1, "e": 2, "w": 3}

# For output dir d (key), the 3 selectable source dirs in sel-order (1, 2, 3).
# (the 3 dirs != d, enumerated in ascending index order)
_SOURCES: dict[str, tuple[str, str, str]] = {
    "n": ("s", "e", "w"),
    "s": ("n", "e", "w"),
    "e": ("n", "s", "w"),
    "w": ("n", "s", "e"),
}


def sources(direction: str) -> tuple[str, str, str]:
    """Return the 3 source dirs (sel 1/2/3) for output ``direction``."""
    return _SOURCES[direction]


class SwitchBox:
    """Cycle-accurate switch-box reference model (v1 W=12, 4 directions)."""

    def __init__(self, W: int = 12) -> None:
        if W < 1:
            raise ValueError("W must be >= 1")
        self.W = W
        # $clog2(4*W): bits to address 0..4*W-1 (6 for W=12)
        self.AW = max(1, (4 * W - 1).bit_length())
        self.NSEL = 4 * W                       # 48 for W=12
        # sel[(dir_idx, track)] in {0,1,2,3}; absent entry == 0 (disconnect)
        self.sel: dict[tuple[int, int], int] = {}

    # -- addressing helpers -------------------------------------------------
    def addr(self, direction: str, track: int) -> int:
        """cfg_addr = DIR*W + t  (DIR: 0=N,1=S,2=E,3=W)."""
        return DIR_IDX[direction] * self.W + track

    def decode(self, addr: int) -> tuple[int, int]:
        """Inverse of :meth:`addr` -> (dir_idx, track)."""
        return addr // self.W, addr % self.W

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> "SwitchBox":
        """Write sel for cfg_addr (mirrors the RTL config-write port)."""
        addr &= (1 << self.AW) - 1               # mask to AW bits (port width)
        if addr < self.NSEL:
            d_idx, t = self.decode(addr)
            self.sel[(d_idx, t)] = data & 0b11
        return self

    def route(self, direction: str, track: int, sel: int) -> "SwitchBox":
        """High-level helper: set the select for (direction, track)."""
        if direction not in DIR_IDX:
            raise ValueError(f"direction must be one of {DIRS}")
        if not 0 <= track < self.W:
            raise ValueError(f"track out of range 0..{self.W - 1}")
        self.sel[(DIR_IDX[direction], track)] = sel & 0b11
        return self

    def sel_of(self, direction: str, track: int) -> int:
        """Read back the configured select (0 if unconfigured)."""
        return self.sel.get((DIR_IDX[direction], track), 0)

    # -- combinational evaluation ------------------------------------------
    @staticmethod
    def _to_int(val, W: int) -> int:
        if isinstance(val, int):
            return val
        v = 0
        for i, b in enumerate(val):
            if i >= W:
                break
            if b:
                v |= 1 << i
        return v

    def outputs(self, in_n, in_s, in_e, in_w):
        """Evaluate the mux network. Returns (out_n, out_s, out_e, out_w) ints.

        Inputs are bitmasks (LSB = track 0); lists/tuples of bits are also
        accepted (index i -> track i). Disconnect (sel 0) drives 0.
        """
        ins = {
            "n": self._to_int(in_n, self.W),
            "s": self._to_int(in_s, self.W),
            "e": self._to_int(in_e, self.W),
            "w": self._to_int(in_w, self.W),
        }
        out = {"n": 0, "s": 0, "e": 0, "w": 0}
        for (d_idx, t), sel in self.sel.items():
            if sel == 0:
                continue                        # disconnect: drives 0
            d = DIRS[d_idx]
            src = _SOURCES[d][sel - 1]          # sel 1..3 -> sources index 0..2
            if (ins[src] >> t) & 1:
                out[d] |= 1 << t
        return out["n"], out["s"], out["e"], out["w"]

    # -- fabric cycle-detector interface -----------------------------------
    def dependency_edges(self) -> set[tuple[tuple, tuple]]:
        """Directed edges created by the CURRENT config.

        One edge per active (non-disconnect) mux::
            (("in",  <src_dir>, t), ("out", <dst_dir>, t))
        sel 0 (disconnect) adds no edge. Faithful to the mux selections so the
        fabric-level cycle detector can compose SB in->out edges with channel
        out->in edges between neighboring SBs.
        """
        edges: set[tuple[tuple, tuple]] = set()
        for (d_idx, t), sel in self.sel.items():
            if sel == 0:
                continue
            d = DIRS[d_idx]
            src = _SOURCES[d][sel - 1]
            edges.add((("in", src, t), ("out", d, t)))
        return edges
