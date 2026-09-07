# SPDX-License-Identifier: MIT
"""Golden reference model for ``connection_block`` — input-side routable CB.

Mirrors ``ethereal-fabric/rtl/interconnect/connection_block.sv`` bit-for-bit
(interconnect **v2c**, frozen spec ``interconnect-config-v0.md`` §7.1,
E2-FAB5). Each of the N_CB CLB inputs (``clb_in[0..N_CB-1]``) selects one of a
**stratified subset** of the 4*W local switch-box output tracks via a
registered **subset index** ``k_i`` (Fc = 1/CB_DIV depopulation; CB_DIV=2 ->
Fc=0.5). This is the input half of the routable CB (the output half — clb_out
injection — lives in ``switch_box``).

Pool layout (bit indexing of the 4*W flattened pool; RTL concatenation
MSB..LSB = ``{out_w, out_e, out_s, out_n}``)::

    pool[0 .. W-1]   = out_n[0..W-1]      (track index 0..W-1)
    pool[W .. 2W-1]  = out_s[0..W-1]      (track index W..2W-1)
    pool[2W .. 3W-1] = out_e[0..W-1]      (track index 2W..3W-1)
    pool[3W .. 4W-1] = out_w[0..W-1]      (track index 3W..4W-1)

Mux semantics (v2c §7.1; CB_DIV=2 for W=12)::

    clb_in_o[i] = pool[(i mod CB_DIV) + CB_DIV * k_i]    k_i in 0..(4*W/CB_DIV)-1

Since W=12 is even, ``(d*W+t) mod 2 == t mod 2``, so ``clb_in[i]`` can read
``out_d[t]`` for every direction d and every track t with
``t mod 2 == i mod 2`` (6 tracks/direction x 4 dirs = 24, Fc = 24/48 = 0.5).
Every track remains readable by 9 of the 18 inputs (balanced). CB_DIV=1 is
bit-identical to the v1.1 full CB (Fc=1.0).

cfg addressing (v2c §7.1: addressing unchanged, data narrowed to 5 bits)::

    cfg_addr (AW bits) -> which clb_in (0..N_CB-1)
    cfg_data (TW bits) -> subset index k_i (0..4*W/CB_DIV-1), TW = 5 for W=12/DIV=2

**Reserved values**: ``k_i = 24..31`` (5-bit encodable) index ``pool[>=48]`` ->
undefined, MUST NOT be programmed (RTL simulation reads X; this model reads 0
and :meth:`configure` raises on them — the mapper must never emit them).
``k_i = 0`` (blank/zero-init) is legal: ``clb_in[i]`` reads ``out_n[i mod 2]``
— a real track, not a disconnect (v2c §7.7; was ``out_n[0]`` in v1.1).

v1.1 -> v2c value translation: a v1.1 absolute track ``p`` is representable
for input ``i`` iff ``p mod 2 == i mod 2``; then ``k = floor(p/2)`` (see
:meth:`subset_index`). The router's CB possibility edges are pruned to exactly
these pairs (bitgen_route, mirroring ``generated/icopt/route/route_check.py``
with ``cb_div=2``).

Pure Python (no cocotb) -> unit-testable locally with pytest. Also exposes
:meth:`dependency_edges` for the fabric-level routability / cycle detector:
each clb_in ``i`` contributes ONE directed edge
``(("out", <dir>, <t>), ("clb_in", i))``. Because ``clb_in`` is a SINK (no
outgoing edge), these edges cannot form a routing cycle regardless of how many
are present.

Note: ``sel_r`` in the RTL has NO reset; OCC writes all selects before un-halt
(config-before-run, C03). To match the post-zero-init HW reality, this model
defaults EVERY ``sel[i]`` to 0 — and unlike the SB model where unconfigured
sel = 0 means "disconnect", here sel = 0 READS ``out_n[i mod 2]`` (a real
track). So a default (zero-init) CB emits a deterministic edge from
``out_n[i mod 2]`` to each ``clb_in``; that is HW-accurate and cannot form a
cycle because clb_in is a sink.
"""
from __future__ import annotations

DIRS = ("n", "s", "e", "w")


class ConnectionBlock:
    """Bit-for-bit reference model for the input-side connection_block (v2c).

    W tracks per direction (default 12); N_CB CLB inputs (default 18 = EXT_IN);
    CB_DIV stratification divisor (default 2 = v2c Fc=0.5; 1 = v1.1 full).
    Each ``clb_in[i] = pool[(i % CB_DIV) + CB_DIV * sel[i]]`` where pool is the
    flattened ``{out_w, out_e, out_s, out_n}`` and ``sel[i]`` is the subset
    index ``k_i`` in 0..4*W/CB_DIV-1.
    """

    def __init__(self, W: int = 12, N_CB: int = 18, CB_DIV: int = 2) -> None:
        if W < 1:
            raise ValueError("W must be >= 1")
        if N_CB < 1:
            raise ValueError("N_CB must be >= 1")
        if CB_DIV < 1 or (4 * W) % CB_DIV:
            raise ValueError("CB_DIV must be >= 1 and divide 4*W")
        self.W = W
        self.N_CB = N_CB
        self.CB_DIV = CB_DIV
        self.POOL = 4 * W                              # 48 for W=12
        self.NSUB = self.POOL // CB_DIV                # 24 for W=12/DIV=2
        # subset-index width: $clog2(4*W/CB_DIV) (5 for W=12/DIV=2)
        self.TW = max(1, (self.NSUB - 1).bit_length())
        # $clog2(N_CB): bits to address 0..N_CB-1 (5 for N_CB=18)
        self.AW = max(1, (N_CB - 1).bit_length())
        # sel[i] in 0..NSUB-1; reset-less in RTL -> defaults to 0
        # (reads out_n[i % CB_DIV]). NOT a dict: deterministic zero default
        # matches post-zero-init HW.
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

    # -- v2c subset-index <-> absolute track conversion (§7.1) -------------
    def pool_index(self, i: int, k: int) -> int:
        """Absolute pool track index for clb_in ``i`` subset index ``k``.

        ``pool_index = (i % CB_DIV) + CB_DIV * k``. ``k`` is NOT range-checked
        here (reserved k values are the programmer's error — see
        :meth:`configure`).
        """
        return (i % self.CB_DIV) + self.CB_DIV * k

    def subset_index(self, i: int, track: int) -> int:
        """Subset index ``k`` selecting absolute pool ``track`` for clb_in ``i``.

        Raises ValueError if ``track`` is not in clb_in ``i``'s stratified
        subset (``track % CB_DIV != i % CB_DIV`` — those tracks are physically
        unreachable for that input under v2c).
        """
        if not 0 <= track < self.POOL:
            raise ValueError(f"track {track} out of pool 0..{self.POOL - 1}")
        if track % self.CB_DIV != i % self.CB_DIV:
            raise ValueError(
                f"track {track} unreachable for clb_in[{i}] under "
                f"CB_DIV={self.CB_DIV} (parity {track % self.CB_DIV} != "
                f"{i % self.CB_DIV})")
        return track // self.CB_DIV

    def reachable(self, i: int, track: int) -> bool:
        """True iff clb_in ``i`` can read absolute pool ``track`` under v2c."""
        return 0 <= track < self.POOL and track % self.CB_DIV == i % self.CB_DIV

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> ConnectionBlock:
        """Write config for cfg_addr (mirrors the RTL config-write port).

        ``addr`` masked to AW bits selects which clb_in (0..N_CB-1); values that
        still fall outside 0..N_CB-1 after masking are ignored (mirrors the
        RTL's bounded ``sel_r[...]`` array — OCC only writes valid indices).
        ``data`` masked to TW bits is the **subset index** k (0..NSUB-1).
        Reserved values k in NSUB..2**TW-1 (24..31 for W=12/DIV=2) are
        MUST-NOT-PROGRAM (§7.1: undefined, RTL reads X) — this model raises.
        """
        a = addr & ((1 << self.AW) - 1)
        k = data & ((1 << self.TW) - 1)
        if k >= self.NSUB:
            raise ValueError(
                f"reserved CB subset index k={k} (>= {self.NSUB}) — "
                f"MUST NOT be programmed (v2c §7.1)")
        if 0 <= a < self.N_CB:
            self.sel[a] = k
        return self

    def sel_of(self, i: int) -> int:
        """Read back the configured subset index for clb_in ``i`` (0 if unset)."""
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
        ``clb_in[i] = pool[(i % CB_DIV) + CB_DIV * sel[i]]`` where
        ``pool = {out_w,out_e,out_s,out_n}`` (v2c §7.1 stratified subset).
        """
        n = self._to_int(out_n, self.W)
        s = self._to_int(out_s, self.W)
        e = self._to_int(out_e, self.W)
        w = self._to_int(out_w, self.W)
        # pool as a flat int: bit k == track k (RTL concatenation MSB..LSB)
        pool = (w << (3 * self.W)) | (e << (2 * self.W)) | (s << self.W) | n
        return [((pool >> self.pool_index(i, self.sel[i])) & 1)
                for i in range(self.N_CB)]

    # -- fabric routability / cycle-detector interface ---------------------
    def dependency_edges(self) -> set[tuple[tuple, tuple]]:
        """Directed edges created by the CURRENT config.

        One edge per clb_in ``i`` (sel defaults to 0, so EVERY clb_in has an
        edge)::

            (("out", <src_dir>, <src_t>), ("clb_in", i))

        where ``(<src_dir>, <src_t>) = dir_t_of(pool_index(i, sel[i]))`` — the
        v2c subset decode, so only parity-reachable tracks ever appear (the
        graph-level form of the §7.1 pruning). Because ``clb_in`` is a SINK
        (no outgoing edge), these edges cannot form a routing cycle regardless
        of how many are present. Faithful to the RTL mux so the fabric-level
        cycle detector composes ``out -> clb_in`` edges with SB-internal and
        channel edges.
        """
        edges: set[tuple[tuple, tuple]] = set()
        for i in range(self.N_CB):
            d, t = self._dir_t_of(self.pool_index(i, self.sel[i]), self.W)
            edges.add((("out", d, t), ("clb_in", i)))
        return edges
