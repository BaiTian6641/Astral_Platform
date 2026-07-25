# SPDX-License-Identifier: MIT
"""Golden reference model for ``switch_box`` — the fabric SB (task E0-FAB3).

Mirrors ``ethereal-fabric/rtl/interconnect/switch_box.sv`` bit-for-bit.
Disjoint unidirectional topology (v1, C01 §3.3): for each output track t in
each direction D in {N,S,E,W}, a registered 2-bit select picks one of the 3
SAME-INDEX input tracks of the OTHER 3 directions, or disconnects (drives 0).

cfg addressing (v2, C01 §3.3 + routable CB)::
    addr = DIR*W + t           ;  DIR: 0=N,1=S,2=E,3=W ;  t: 0..W-1  (range 0..4W-1)
    data = sel                 ;  0=disconnect, 1/2/3 = the 3 sources (ascending order)
    addr = 4W + j              ;  j: 0..N_INJ-1  (range 4W..4W+N_INJ-1)
    data[0] = inject_en[j]     ;  1 = out_e[j] <- clb_out[j] (overrides disjoint sel)

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
    """Cycle-accurate switch-box reference model (v2: disjoint unidir + routable CB).

    W tracks per direction (default 12); N_INJ injectable CLB outputs (default 8)
    that can override out_e[0..N_INJ-1] via inject_en (routable connection block).
    """

    def __init__(self, W: int = 12, N_INJ: int = 8) -> None:
        if W < 1:
            raise ValueError("W must be >= 1")
        if not 0 <= N_INJ <= W:
            raise ValueError("N_INJ must satisfy 0 <= N_INJ <= W")
        self.W = W
        self.N_INJ = N_INJ
        # $clog2(4*W+N_INJ): bits to address 0..4*W+N_INJ-1 (6 for W=12,N_INJ=8)
        self.AW = max(1, (4 * W + N_INJ - 1).bit_length())
        self.NSEL = 4 * W                       # 48 disjoint (DIR,t) selects
        self.NINJ = N_INJ                       # inject_en bits (routable CB)
        # sel[(dir_idx, track)] in {0,1,2,3}; absent entry == 0 (disconnect)
        self.sel: dict[tuple[int, int], int] = {}
        # inject_en: set of clb_out indices j (0..N_INJ-1) driving out_e[j]
        self.inject_en: set[int] = set()

    # -- addressing helpers -------------------------------------------------
    def addr(self, direction: str, track: int) -> int:
        """cfg_addr = DIR*W + t  (DIR: 0=N,1=S,2=E,3=W)."""
        return DIR_IDX[direction] * self.W + track

    def decode(self, addr: int) -> tuple[int, int]:
        """Inverse of :meth:`addr` -> (dir_idx, track)."""
        return addr // self.W, addr % self.W

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> "SwitchBox":
        """Write config for cfg_addr (mirrors the RTL config-write port).

        addr 0..4W-1            -> sel (data & 0b11)
        addr 4W..4W+N_INJ-1     -> inject_en[addr-4W] (data & 1)
        addr >= 4W+N_INJ        -> ignored (out of range after AW-bit masking)
        """
        addr &= (1 << self.AW) - 1               # mask to AW bits (port width)
        if addr < self.NSEL:
            d_idx, t = self.decode(addr)
            self.sel[(d_idx, t)] = data & 0b11
        elif addr < self.NSEL + self.NINJ:
            j = addr - self.NSEL
            if data & 1:
                self.inject_en.add(j)
            else:
                self.inject_en.discard(j)
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

    def inject(self, track: int, enable: bool) -> "SwitchBox":
        """High-level helper: set/clear inject_en[track] (clb_out -> out_e)."""
        if not 0 <= track < self.NINJ:
            raise ValueError(f"track out of range 0..{self.NINJ - 1}")
        if enable:
            self.inject_en.add(track)
        else:
            self.inject_en.discard(track)
        return self

    def inject_of(self, track: int) -> bool:
        """Read back inject_en[track] (False if unconfigured)."""
        return track in self.inject_en

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

    def outputs(self, in_n, in_s, in_e, in_w, clb_out=0):
        """Evaluate the mux network. Returns (out_n, out_s, out_e, out_w) ints.

        Inputs are bitmasks (LSB = track 0); lists/tuples of bits are also
        accepted (index i -> track i). Disconnect (sel 0) drives 0.

        ``clb_out`` is the N_INJ-bit local CLB-output vector (routable CB):
        for each j with inject_en[j] set, out_e[j] = clb_out[j], OVERRIDING the
        disjoint sel (mirrors the RTL ``inj_en_r[j] ? clb_out_i[j] : <sel>``).
        Default 0 -> disjoint-only behavior (backward compatible).
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
            # routable CB: out_e[t<N_INJ] with inject_en[t] set is driven by
            # clb_out, NOT the disjoint sel -> skip the disjoint contribution.
            if d == "e" and t < self.NINJ and t in self.inject_en:
                continue
            src = _SOURCES[d][sel - 1]          # sel 1..3 -> sources index 0..2
            if (ins[src] >> t) & 1:
                out[d] |= 1 << t
        # routable CB: inject clb_out[j] -> out_e[j] for each enabled j
        clb = self._to_int(clb_out, self.NINJ)
        for j in self.inject_en:
            if (clb >> j) & 1:
                out["e"] |= 1 << j
            else:
                out["e"] &= ~(1 << j)
        return out["n"], out["s"], out["e"], out["w"]

    # -- fabric cycle-detector interface -----------------------------------
    def dependency_edges(self) -> set[tuple[tuple, tuple]]:
        """Directed edges created by the CURRENT config.

        One edge per active (non-disconnect) disjoint mux::
            (("in",  <src_dir>, t), ("out", <dst_dir>, t))
        sel 0 (disconnect) adds no edge. Routable-CB injection adds, for each
        j with inject_en[j] set, an edge::
            (("clb_out", j), ("out", "e", j))
        and SUPPRESSES the disjoint out_e[j] edge (inject overrides the mux).
        ``("clb_out", j)`` is a source node (no incoming edge) -> cannot by
        itself form a cycle. Faithful to the mux selections so the fabric-level
        cycle detector can compose SB in->out edges with channel out->in edges.
        """
        edges: set[tuple[tuple, tuple]] = set()
        for (d_idx, t), sel in self.sel.items():
            if sel == 0:
                continue
            d = DIRS[d_idx]
            if d == "e" and t < self.NINJ and t in self.inject_en:
                continue                        # inject overrides disjoint sel
            src = _SOURCES[d][sel - 1]
            edges.add((("in", src, t), ("out", d, t)))
        for j in self.inject_en:
            edges.add((("clb_out", j), ("out", "e", j)))
        return edges
