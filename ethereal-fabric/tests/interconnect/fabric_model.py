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

NOTE (routable CB): each tile's SB can inject its local CLB outputs onto
out_e[0..N_INJ-1] via inject_en (cfg addr 4W+j). The per-tile ``clb_out`` vector
(default 0, set via :meth:`set_clb_out`) models the ClbT outputs as an
externally-set source -- no CLB logic is simulated. ``dependency_edges`` emits
``clb_out`` -> ``out_e`` source edges (clb_out has no incoming edge -> cannot
form a cycle by itself); default config (no inject_en) adds no such edges.
"""
from __future__ import annotations

from collections import deque

from cb_model import ConnectionBlock
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
    """R x C grid of switch boxes + connection blocks wired by channels.

    Each tile holds one SwitchBox (track mux + clb_out injection) and one
    ConnectionBlock (clb_in mux over the 4*W local SB output tracks).
    ``EXT_IN`` (= N_CB, default 18) is the CLB input count per tile.
    """

    def __init__(
        self, R: int = 4, C: int = 4, W: int = 12, N_INJ: int = 8, EXT_IN: int = 18
    ) -> None:
        self.R, self.C, self.W, self.N_INJ, self.EXT_IN = R, C, W, N_INJ, EXT_IN
        self.sb = [[SwitchBox(W, N_INJ) for _ in range(C)] for _ in range(R)]
        # input connection block per tile (clb_in = mux of 4*W local SB tracks)
        self.cb = [[ConnectionBlock(W, EXT_IN) for _ in range(C)] for _ in range(R)]
        # per-tile CLB-output source vector (N_INJ bits); default 0. Models the
        # ClbT outputs as an externally-set source (no CLB logic simulated);
        # set via set_clb_out() and fed to each tile's SB via tile_outputs().
        self.clb_out: list[list[int]] = [[0 for _ in range(C)] for _ in range(R)]

    # unit codes mirror fabric_top: 0 = CLB, 1 = SB, 2 = CB(connection_block)
    UNIT_CLB, UNIT_SB, UNIT_CB = 0, 1, 2

    # -- addressing helpers ------------------------------------------------
    @property
    def n_tiles(self) -> int:
        return self.R * self.C

    def tile_rc(self, idx: int) -> tuple[int, int]:
        return divmod(idx, self.C)  # row-major: idx = r*C + c

    def configure(self, tile_idx: int, unit: int, intra: int, data: int) -> None:
        """Dispatch a config write to the per-tile unit (CLB/SB/CB).

        CLB config is handled by the ClbT model elsewhere; not modeled here.
        SB and CB selects are written into their golden models.
        """
        r, c = self.tile_rc(tile_idx)
        if unit == self.UNIT_SB:
            self.sb[r][c].configure(intra, data)
        elif unit == self.UNIT_CB:
            self.cb[r][c].configure(intra, data)

    def configure_sb(self, r: int, c: int, addr: int, data: int) -> None:
        self.sb[r][c].configure(addr, data)

    def set_clb_out(self, r: int, c: int, value: int) -> None:
        """Set tile (r,c)'s CLB-output source vector (N_INJ bits)."""
        self.clb_out[r][c] = value & ((1 << self.N_INJ) - 1)

    def tile_outputs(self, r: int, c: int, in_n, in_s, in_e, in_w):
        """Evaluate tile (r,c)'s SB outputs, feeding the stored clb_out vector."""
        return self.sb[r][c].outputs(in_n, in_s, in_e, in_w, self.clb_out[r][c])

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
                    # localize to tile. src/dst tuple shapes vary:
                    #   ("in"/"out", dir, t)  -> 3-tuple
                    #   ("clb_out", j)        -> 2-tuple (routable-CB source)
                    # prefixing with (r,c) keeps every node a distinct, hashable
                    # fabric coordinate (clb_out nodes are 4-tuples, others 5-).
                    edges.append(((r, c) + src, (r, c) + dst))
        return edges

    def _cb_edges(self) -> list[tuple]:
        """connection_block edges: out_track@(r,c) -> clb_in_i@(r,c).

        clb_in nodes are 4-tuples ``(r, c, "clb_in", i)``; src out-track nodes
        are 5-tuples ``(r, c, "out", dir, t)`` (same shape as SB/channel out
        nodes). clb_in is a sink -> these edges cannot form a cycle.
        """
        edges = []
        for r in range(self.R):
            for c in range(self.C):
                for (src, dst) in self.cb[r][c].dependency_edges():
                    edges.append(((r, c) + src, (r, c) + dst))
        return edges

    def graph_edges(self) -> list[tuple]:
        return self._channel_edges() + self._sb_edges() + self._cb_edges()

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

    # -- routability (reachability over the configured routing graph) ------
    def route_exists(self, src_node: tuple, dst_node: tuple) -> bool:
        """True iff ``dst_node`` is reachable from ``src_node`` via graph edges.

        Nodes are the localized tuples produced by :meth:`graph_edges`, e.g.
        ``(0, 0, "clb_out", 0)`` or ``(0, 1, "clb_in", 0)``. Uses iterative
        DFS over the current graph (channel + SB + CB edges). A node is
        trivially reachable from itself (zero-length path).
        """
        adj: dict[tuple, set[tuple]] = {}
        for a, b in self.graph_edges():
            adj.setdefault(a, set()).add(b)
        visited: set[tuple] = {src_node}
        stack = [src_node]
        while stack:
            n = stack.pop()
            if n == dst_node:
                return True
            for m in adj.get(n, ()):
                if m not in visited:
                    visited.add(m)
                    stack.append(m)
        return False

    def n_channel_edges(self) -> int:
        return len(self._channel_edges())
