# SPDX-License-Identifier: MIT
"""Golden reference model for ``connection_block`` — input-side routable CB.

Mirrors ``ethereal-fabric/rtl/interconnect/connection_block.sv`` bit-for-bit
(task E0-FAB3b, "routable CB Step 2"). Each of the N_CB CLB inputs
(``clb_in[0..N_CB-1]``) selects one of the 4*W local switch-box output tracks
via a registered track-index select. This is the input half of the routable CB
(the output half — clb_out injection onto out_e — lives in ``switch_box``).

Pool layout (bit indexing of the 4*W flattened pool; RTL concatenation
MSB..LSB = ``{out_w, out_e, out_s, out_n}``)::

    pool[0 .. W-1]   = out_n[0..W-1]      (track index 0..W-1)
    pool[W .. 2W-1]  = out_s[0..W-1]      (track index W..2W-1)
    pool[2W .. 3W-1] = out_e[0..W-1]      (track index 2W..3W-1)
    pool[3W .. 4W-1] = out_w[0..W-1]      (track index 3W..4W-1)

so track index k maps to::

    k <  W   -> ("n", k)
    k < 2W   -> ("s", k - W)
    k < 3W   -> ("e", k - 2W)
    else     -> ("w", k - 3W)

cfg addressing (v2, C01 §3 + routable CB)::

    cfg_addr (AW bits) -> which clb_in (0..N_CB-1)
    cfg_data (TW bits) -> track index (0..4*W-1) stored into sel[addr]

Pure Python (no cocotb) -> unit-testable locally with pytest. Also exposes
:meth:`dependency_edges` for the fabric-level routability / cycle detector:
each clb_in ``i`` contributes ONE directed edge
``(("out", <dir>, <t>), ("clb_in", i))``. Because ``clb_in`` is a SINK (no
outgoing edge), these edges cannot form a routing cycle regardless of how many
are present.

Note: ``sel_r`` in the RTL has NO reset; OCC writes all selects before un-halt
(config-before-run, C03). To match the post-zero-init HW reality, this model
defaults EVERY ``sel[i]`` to 0 — and unlike the SB model where unconfigured
sel = 0 means "disconnect", here sel = 0 READS ``out_n[0]`` (a real track, not
a disconnect). So a default (zero-init) CB emits a deterministic edge from
``out_n[0]`` to each ``clb_in``; that is HW-accurate and cannot form a cycle
because clb_in is a sink.
"""
from __future__ import annotations

DIRS = ("n", "s", "e", "w")


class ConnectionBlock:
    """Bit-for-bit reference model for the input-side connection_block.

    W tracks per direction (default 12); N_CB CLB inputs (default 18 = EXT_IN).
    Each ``clb_in[i] = pool[sel[i]]`` where pool is the flattened
    ``{out_w, out_e, out_s, out_n}`` and ``sel[i]`` in 0..4*W-1 is a track index.
    """

    def __init__(self, W: int = 12, N_CB: int = 18) -> None:
        if W < 1:
            raise ValueError("W must be >= 1")
        if N_CB < 1:
            raise ValueError("N_CB must be >= 1")
        self.W = W
        self.N_CB = N_CB
        self.POOL = 4 * W                              # 48 for W=12
        # $clog2(4*W): bits to address 0..4*W-1 (6 for W=12)
        self.TW = max(1, (self.POOL - 1).bit_length())
        # $clog2(N_CB): bits to address 0..N_CB-1 (5 for N_CB=18)
        self.AW = max(1, (N_CB - 1).bit_length())
        # sel[i] in 0..4*W-1; reset-less in RTL -> defaults to 0 (out_n[0]).
        # NOT a dict: deterministic zero default matches post-zero-init HW.
        self.sel: list[int] = [0] * N_CB

    # -- pool / track mapping helpers --------------------------------------
    @staticmethod
    def track_index(direction: str, t: int, W: int) -> int:
        """Inverse of the pool mapping: (direction, track t) -> track index.

        direction in {"n","s","e","w"}, t in 0..W-1.
        """
        if direction == "n":
            base = 0
        elif direction == "s":
            base = W
        elif direction == "e":
            base = 2 * W
        elif direction == "w":
            base = 3 * W
        else:
            raise ValueError(f"direction must be one of {DIRS}")
        return base + t

    def track_index_of(self, direction: str, t: int) -> int:
        """Instance helper for :meth:`track_index` using this CB's W."""
        return self.track_index(direction, t, self.W)

    @staticmethod
    def _dir_t_of(track: int, W: int) -> tuple[str, int]:
        """Forward pool mapping: track index -> (direction, t)."""
        if track < W:
            return "n", track
        if track < 2 * W:
            return "s", track - W
        if track < 3 * W:
            return "e", track - 2 * W
        return "w", track - 3 * W

    def dir_t_of(self, track: int) -> tuple[str, int]:
        """Instance helper for :meth:`_dir_t_of` using this CB's W."""
        return self._dir_t_of(track, self.W)

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> ConnectionBlock:
        """Write config for cfg_addr (mirrors the RTL config-write port).

        ``addr`` masked to AW bits selects which clb_in (0..N_CB-1); values that
        still fall outside 0..N_CB-1 after masking are ignored (mirrors the
        RTL's bounded ``sel_r[...]`` array — OCC only writes valid indices).
        ``data`` masked to TW bits is the track index (0..4*W-1).
        """
        a = addr & ((1 << self.AW) - 1)
        if 0 <= a < self.N_CB:
            self.sel[a] = data & ((1 << self.TW) - 1)
        return self

    def sel_of(self, i: int) -> int:
        """Read back the configured sel for clb_in ``i`` (0 if unconfigured)."""
        return self.sel[i]

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

    def clb_in(self, out_n, out_s, out_e, out_w) -> list[int]:
        """Evaluate the N_CB input muxes. Returns a list of N_CB bits.

        Inputs are W-bit ints (LSB = track 0) or bit-lists/tuples.
        ``clb_in[i] = pool[sel[i]]`` where ``pool = {out_w,out_e,out_s,out_n}``.
        """
        n = self._to_int(out_n, self.W)
        s = self._to_int(out_s, self.W)
        e = self._to_int(out_e, self.W)
        w = self._to_int(out_w, self.W)
        # pool as a flat int: bit k == track k (RTL concatenation MSB..LSB)
        pool = (w << (3 * self.W)) | (e << (2 * self.W)) | (s << self.W) | n
        return [((pool >> self.sel[i]) & 1) for i in range(self.N_CB)]

    # -- fabric routability / cycle-detector interface ---------------------
    def dependency_edges(self) -> set[tuple[tuple, tuple]]:
        """Directed edges created by the CURRENT config.

        One edge per clb_in ``i`` (sel defaults to 0, so EVERY clb_in has an
        edge)::

            (("out", <src_dir>, <src_t>), ("clb_in", i))

        Because ``clb_in`` is a SINK (no outgoing edge), these edges cannot
        form a routing cycle regardless of how many are present. Faithful to
        the RTL mux so the fabric-level cycle detector composes
        ``out -> clb_in`` edges with SB-internal and channel edges.
        """
        edges: set[tuple[tuple, tuple]] = set()
        for i in range(self.N_CB):
            d, t = self._dir_t_of(self.sel[i], self.W)
            edges.add((("out", d, t), ("clb_in", i)))
        return edges
