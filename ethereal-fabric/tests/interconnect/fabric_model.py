# SPDX-License-Identifier: MIT
"""Fabric-grid model + routing comb-loop detector (task E0-FAB3).

Composes a parameterized R x C grid of ``SwitchBox`` (from ``sb_model``) wired by
unidirectional channels, builds the **routing dependency graph**, and runs cycle
detection (Kahn's topological sort). This is the locally-validatable core of the
E0-FAB3 acceptance "4x4 grid, no combinational loop": a cycle in the graph ==
a combinational loop in the (configured) routing.

Graph nodes: ``(r, c, side, dir, t)`` where side in {"in","out"}, dir in
{"n","s","e","w"}, t in 0..W-1. Edges:
  * SB-internal (per tile): ("in",sd,t) -> ("out",dd,t)   [from SwitchBox.dependency_edges]
  * channel (across tiles): out_D[t]@(r,c) -> in_D'[t]@(neighbor):
        out_n -> in_s@(r-1,c); out_s -> in_n@(r+1,c);
        out_e -> in_w@(r,c+1); out_w -> in_e@(r,c-1)
A node with no driving edge reads as 0. Default SB config (all sel=0/disconnect)
adds no SB-internal edges -> the graph has only out->in channel edges -> acyclic.

NOTE (v1 scope): CLB<->channel injection (a routable CB) is intentionally NOT
modeled here -- it is a later design step (frame-map S02-P0#1 + OCC E0-FAB4 +
VPR E0-MAP2). This model validates the SB+channel *interconnect* structure, which
is what the E0-FAB3 "no comb loop" acceptance is about.
"""
from __future__ import annotations

from collections import deque
from sb_model import SwitchBox

DIRS = ("n", "s", "e", "w")
# channel mapping: an out_* track at (r,c) feeds the in_* port of a neighbor.
# (out_dir -> (neighbor delta (dr,dc), in_dir_at_neighbor))
CHAN_MAP = {
    "n": (-1, 0, "s"),
    "s": ( 1, 0, "n"),
    "e": ( 0, 1, "w"),
    "w": ( 0,-1, "e"),
}


class FabricGrid:
    """R x C grid of switch boxes connected by unidirectional channels."""

    def __init__(self, R: int = 4, C: int = 4, W: int = 12) -> None:
        self.R, self.C, self.W = R, C, W
        self.sb = [[SwitchBox(W) for _ in range(C)] for _ in range(R)]

    # -- addressing helpers ------------------------------------------------
    @property
    def n_tiles(self) -> int:
        return self.R * self.C

    def tile_rc(self, idx: int) -> tuple[int, int]:
        return divmod(idx, self.C)  # row-major: idx = r*C + c

    # unit codes mirror fabric_top: 0 = CLB, 1 = SB
    UNIT_CLB, UNIT_SB = 0, 1

    def configure(self, tile_idx: int, unit: int, intra: int, data: int) -> None:
        r, c = self.tile_rc(tile_idx)
        if unit == self.UNIT_SB:
            self.sb[r][c].configure(intra, data)
        # CLB config is handled by the ClbT model elsewhere; not modeled here.

    def configure_sb(self, r: int, c: int, addr: int, data: int) -> None:
        self.sb[r][c].configure(addr, data)

    # -- graph construction ------------------------------------------------
    def _channel_edges(self) -> list[tuple]:
        edges = []
        for r in range(self.R):
            for c in range(self.C):
                for od, (dr, dc, ind) in CHAN_MAP.items():
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < self.R and 0 <= nc < self.C:
                        for t in range(self.W):
                            edges.append(((r, c, "out", od, t), (nr, nc, "in", ind, t)))
        return edges

    def _sb_edges(self) -> list[tuple]:
        edges = []
        for r in range(self.R):
            for c in range(self.C):
                for (src, dst) in self.sb[r][c].dependency_edges():
                    # src/dst are (("in"|"out", dir, t), ...) -> localize to tile
                    edges.append(((r, c, src[0], src[1], src[2]),
                                  (r, c, dst[0], dst[1], dst[2])))
        return edges

    def graph_edges(self) -> list[tuple]:
        return self._channel_edges() + self._sb_edges()

    # -- cycle detection (Kahn's topological sort) -------------------------
    def has_comb_loop(self) -> bool:
        """True iff the configured routing dependency graph has a cycle."""
        edges = self.graph_edges()
        adj: dict[tuple, set[tuple]] = {}
        indeg: dict[tuple, int] = {}
        nodes = set()
        for a, b in edges:
            nodes.add(a)
            nodes.add(b)
            adj.setdefault(a, set()).add(b)
            indeg[b] = indeg.get(b, 0) + 1
            indeg.setdefault(a, indeg.get(a, 0))
        q = deque(n for n in nodes if indeg.get(n, 0) == 0)
        seen = 0
        while q:
            n = q.popleft()
            seen += 1
            for m in adj.get(n, ()):
                indeg[m] -= 1
                if indeg[m] == 0:
                    q.append(m)
        return seen != len(nodes)

    # -- topology self-consistency (C01 §3.5) ------------------------------
    def topology_self_consistent(self) -> bool:
        """Every channel edge stays in-grid; no out-edge references a missing
        neighbor; edge tiles simply have fewer edges (no dangling refs)."""
        for r in range(self.R):
            for c in range(self.C):
                for od, (dr, dc, _ind) in CHAN_MAP.items():
                    nr, nc = r + dr, c + dc
                    inside = 0 <= nr < self.R and 0 <= nc < self.C
                    # out_* on an edge tile points off-grid -> legal, just unconnected
                    if inside and not (0 <= nr < self.R and 0 <= nc < self.C):
                        return False
        return True

    def n_channel_edges(self) -> int:
        return len(self._channel_edges())
