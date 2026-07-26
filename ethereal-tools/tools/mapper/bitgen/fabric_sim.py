# SPDX-License-Identifier: MIT
"""fabric_sim — fabric-level simulator (task E0-MAP3 incr 4d, the ACCEPTANCE).

Loads the LEVEL-1 logic config DB (bitgen_db) + the routed fabric config
(bitgen_route.RouteConfig) and *runs* the configured fabric to a combinational
fixpoint, returning the primary-output net values. This is the capstone of the
mapping chain (synth -> VPR pack/place -> bitgen DB -> Wilton router ->
fabric sim) and is validated bit-true against an independent iverilog golden
of the ISCAS85 c432 benchmark (see ``test_fabric_sim.test_c432_bittrue``).

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2
          (E0-MAP3 increment 4d — fabric simulator).

==============================================================================
MODEL — faithful to the RTL + golden interconnect models
==============================================================================
Per fabric tile ``(r, c)`` (normalized: ``row = y - min_y``, ``col = x - min_x``):
  * one ``SwitchBox`` (Wilton SB + bidirectional inject) configured from
    ``RouteConfig.tiles[(r,c)]`` — ``sb_sel -> sb.route``, ``inject -> sb.inject``.
  * one ``ConnectionBlock`` (input-side routable CB) configured from
    ``RouteConfig.tiles[(r,c)].cb_sel`` — ``cb.configure(i, track)``.
  * the ``TileLogic`` (CLB) from ``db.tiles[(c+min_x, r+min_y)]``.

Channel wiring (mirrors ``fabric_model.CHAN_MAP``): for tile ``(r,c)`` the
incoming tracks are gathered from the NEIGHBORS' outputs::

    in_n@(r,c) = out_s@(r-1,c)     # out_n -> in_s@(r-1,c)  [reverse]
    in_s@(r,c) = out_n@(r+1,c)     # out_s -> in_n@(r+1,c)
    in_e@(r,c) = out_w@(r,c+1)     # out_e -> in_w@(r,c+1)
    in_w@(r,c) = out_e@(r,c-1)     # out_w -> in_e@(r,c-1)

Per outer iteration (Gauss-Seidel, in-place, fixed tile order = deterministic):
  1. gather ``in_*`` from current neighbor ``out_*`` (0 off-grid).
  2. ``clb_in_bits = cb.clb_in(out_n, out_s, out_e, out_w)`` — the CB reads the
     LOCAL tile's own ``out_*`` tracks (the routable-CB taps).
  3. PRIMARY-INPUT INJECTION (IO model, see ASSUMPTION below): for every
     ``clb_in`` index ``i`` whose ``cluster_inputs[i]`` net is a primary input
     present in ``pi_values``, OVERRIDE ``clb_in_bits[i] = pi_values[net]``.
     PIs bypass the CB entirely — they are externally driven (this models the
     IO-T path the RTL does not yet have).
  4. ``clb_out_bits = clb_eval_bits(tile_logic, clb_in_bits)`` — the bit-level
     CLB evaluator (mirrors ``clb_t.sv`` / ``elut4.sv``; inner fixpoint over
     the eLUT-output feedback pool 18..25).
  5. ``new_out_* = sb.outputs(in_n, in_s, in_e, in_w, clb_out=pack(clb_out_bits))``
     — Wilton routing + this tile's own clb_out injection.
  Fixpoint: stop when no ``out_*`` changes across the grid (combinational — c432
  has 0 FFs). Primary outputs: for each ``(r,c,gi)`` whose
  ``cluster_outputs[gi]`` net is in ``db.primary_outputs`` ->
  ``result[net] = clb_out_bits[gi]``.

ASSUMPTION (IO-injection model, G6 — TBD, 2026-07-26): the RTL fabric has no
IO-T yet. PIs enter the simulated fabric by directly driving the ``clb_in``
slot each cluster marks as that primary input (``cluster_inputs[i] == PI_net``),
bypassing the connection block. POs exit by reading the driver cluster's
``clb_out[gi]`` where ``cluster_outputs[gi] == PO_net``. This is a sim-level
IO model — it does NOT model the future IO-T register path or pin routing, and
it assumes VPR packed each PI into exactly one ``clb_in`` slot per consuming
cluster (true for c432). When a real IO-T lands, this injection hook moves into
the IO-T model and ``simulate_fabric`` reads the PO at the IO-T instead.

ASSUMPTION (fixpoint iterations): c432 is acyclic combinational with ~5 cluster
logic levels; Gauss-Seidel relaxation converges in well under 64 outer iters
(measured ~15-20). ``max_iters`` carries margin; non-convergence == a real bug
(routing comb-loop or evaluator error), never silently loosened.
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass

# -- sys.path bootstrap: bitgen_db / bitgen_route live in THIS dir; the fabric --
# -- golden models live in ethereal-fabric/tests/interconnect/. Mirrors         --
# -- bitgen_route's bootstrap so `from <mod>` works regardless of CWD.          --
_HERE = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(os.path.dirname(_HERE))     # ethereal-tools/tools/
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)
_INTERCONNECT = os.path.normpath(os.path.join(
    _HERE, "..", "..", "..", "..", "ethereal-fabric", "tests", "interconnect"))
if _INTERCONNECT not in sys.path:
    sys.path.insert(0, _INTERCONNECT)

from bitgen_db import (EXT_IN, FB_BASE, K, N, ElutConfig,  # noqa: E402
                       FabricConfigDB, TileLogic)
from bitgen_route import RouteConfig  # noqa: E402
from cb_model import ConnectionBlock  # noqa: E402
from sb_model import SwitchBox  # noqa: E402


# =============================================================================
# Bit-level CLB evaluator (mirrors clb_t.sv / elut4.sv EXACTLY)
# =============================================================================

def clb_eval_bits(
    tile: TileLogic,
    clb_in_bits: list[int],
    ff_state: dict[int, int] | None = None,
) -> list[int]:
    """Evaluate a ``TileLogic`` -> ``clb_out[0..N-1]`` bit list.

    Bit-level mirror of ``clb_t.sv`` + ``elut4.sv``::

        pool[0..EXT_IN-1]   = clb_in_bits (external cluster inputs)
        pool[EXT_IN..I-1]   = clb_out feedback (pool sel 18..25 -> eLUT4 (sel-18))
        lut_in[gi][gk]      = pool[iib_mux.get((gi,gk), 0)]
        vin                 = {pin3,pin2,pin1,pin0}   (pin0 = LSB)
        comb                = (tt >> vin) & 1          (physical-pin-order TT)
        muxed               = ff_state[gi] if ff_en else comb
        vout                = muxed ^ out_inv

    The eLUT-output feedback (pool 18..25 depends on clb_out, which depends on
    the pool) is resolved by an inner fixpoint (N+2 iters, like
    ``bitgen_sim.simulate_tile``). For combinational clusters (c432: ff_en=0
    everywhere, no intra-cluster feedback) one pass is enough; the loop is the
    general-case guard for legal virtual combinational loops (C01 §2.4).

    ``ff_state`` carries stored FF bits used only when ``ElutConfig.ff_en`` is
    True (c432 has none). Unused/unset sources read as 0 (matches the pool
    zero-init in the RTL).
    """
    ff_state = ff_state or {}
    clb_out: list[int] = [0] * N
    # seed registered outputs from ff_state so combinational readers see them
    for gi, ec in tile.eluts.items():
        if ec.ff_en and gi in ff_state:
            clb_out[gi] = ff_state[gi] & 1

    def _pool_bit(sel: int) -> int:
        if sel < EXT_IN:
            return clb_in_bits[sel] & 1
        return clb_out[sel - FB_BASE] & 1           # feedback eLUT4 (sel - 18)

    def _elut_out(gi: int, ec: ElutConfig) -> int:
        vin = 0
        for gk in range(K):
            vin |= _pool_bit(tile.iib_mux.get((gi, gk), 0)) << gk
        if ec.ff_en:
            muxed = ff_state.get(gi, 1 if ec.ff_rst_val else 0) & 1
        else:
            muxed = (ec.tt >> vin) & 1
        return muxed ^ (1 if ec.out_inv else 0)

    for _ in range(N + 2):
        changed = False
        for gi, ec in tile.eluts.items():
            out = _elut_out(gi, ec)
            if clb_out[gi] != out:
                clb_out[gi] = out
                changed = True
        if not changed:
            break
    return clb_out


# =============================================================================
# Fabric simulator
# =============================================================================

@dataclass
class _TileModels:
    """Per-tile configured models + logic lookup (built once, reused)."""

    sb: SwitchBox
    cb: ConnectionBlock
    logic: TileLogic | None


class FabricSim:
    """Pre-configured fabric simulator: build once, ``evaluate`` per PI vector.

    Building the SwitchBox / ConnectionBlock models from a ``RouteConfig`` is
    pure setup (the routing config does not change between input vectors); only
    the ``out_*`` track state and the PI values differ per evaluation. So a
    batch golden comparison (>=200 vectors) builds the models ONCE here and
    calls :meth:`evaluate` per vector.
    """

    def __init__(
        self,
        db: FabricConfigDB,
        rc: RouteConfig,
        min_x: int,
        min_y: int,
        *,
        W: int = 12,
        N_elt: int = N,
        ext_in: int = EXT_IN,
    ) -> None:
        if not db.tiles:
            raise ValueError("FabricConfigDB has no tiles")
        self.db = db
        self.rc = rc
        self.min_x = min_x
        self.min_y = min_y
        self.W = W
        self.N = N_elt            # eLUT4 / clb_out / inject count
        self.EXT_IN = ext_in      # clb_in count
        xs = [x for (x, _y) in db.tiles]
        ys = [y for (_x, y) in db.tiles]
        max_x, max_y = max(xs), max(ys)
        self.R = max_y - min_y + 1
        self.C = max_x - min_x + 1

        # build + configure per-tile models for the FULL R x C grid (tiles with
        # no routing config stay at default = all-disconnect SB / zero CB sel,
        # which correctly drives 0 on every track).
        self.tiles: list[list[_TileModels]] = [
            [_TileModels(SwitchBox(W, N_elt), ConnectionBlock(W, ext_in), None)
             for _ in range(self.C)]
            for _ in range(self.R)]
        for (r, c), tr in rc.tiles.items():
            if not (0 <= r < self.R and 0 <= c < self.C):
                raise ValueError(
                    f"RouteConfig tile ({r},{c}) out of grid R={self.R} C={self.C}")
            tm = self.tiles[r][c]
            for (dd, t), sel in tr.sb_sel.items():
                tm.sb.route(dd, t, sel)
            for j, d in tr.inject.items():
                tm.sb.inject(j, True, d)
            for i, track in tr.cb_sel.items():
                tm.cb.configure(i, track)
        # attach the TileLogic (CLB) where a db tile exists (logic tiles); other
        # tiles stay logic=None (routing-only or empty).
        for (x, y), tile_logic in db.tiles.items():
            r, c = y - min_y, x - min_x
            if 0 <= r < self.R and 0 <= c < self.C:
                self.tiles[r][c].logic = tile_logic

        # precompute PO taps: (r, c, gi, net) for every cluster_output net that
        # is a primary output of the design.
        self.po_taps: list[tuple[int, int, int, str]] = []
        for (x, y), tl in db.tiles.items():
            r, c = y - min_y, x - min_x
            for gi, net in tl.cluster_outputs.items():
                if net is not None and net in db.primary_outputs:
                    self.po_taps.append((r, c, gi, net))

        # diagnostics from the last evaluate()
        self.last_iters: int = 0
        self.converged: bool = False

    def evaluate(
        self,
        pi_values: dict[str, int],
        max_iters: int = 64,
    ) -> dict[str, int]:
        """Run the configured fabric to a combinational fixpoint under PIs.

        Returns ``{primary_output_net: bit}`` for every PO net found at a
        driver cluster's ``clb_out``. Deterministic (fixed tile iteration
        order). Sets ``self.last_iters`` / ``self.converged`` for diagnostics.
        """
        R, C, N_elt = self.R, self.C, self.N
        out_n = [[0] * C for _ in range(R)]
        out_s = [[0] * C for _ in range(R)]
        out_e = [[0] * C for _ in range(R)]
        out_w = [[0] * C for _ in range(R)]
        # last-computed clb_out bits per tile (used for PO extraction at the
        # stable fixpoint; updated every pass).
        clb_out_bits_grid: list[list[list[int]]] = [
            [[0] * N_elt for _ in range(C)] for _ in range(R)]

        iters = 0
        converged = False
        for it in range(max_iters):
            iters = it + 1
            changed = False
            for r in range(R):
                row_above = out_s[r - 1] if r > 0 else None
                row_below = out_n[r + 1] if r < R - 1 else None
                for c in range(C):
                    tm = self.tiles[r][c]
                    # 1. gather incoming channels from current neighbor outs.
                    in_n = row_above[c] if row_above is not None else 0   # out_s@(r-1,c)
                    in_s = row_below[c] if row_below is not None else 0   # out_n@(r+1,c)
                    in_e = out_w[r][c + 1] if c < C - 1 else 0            # out_w@(r,c+1)
                    in_w = out_e[r][c - 1] if c > 0 else 0                # out_e@(r,c-1)

                    tl = tm.logic
                    if tl is not None:
                        # 2. CB reads THIS tile's local out_* tracks.
                        clb_in_bits = tm.cb.clb_in(
                            out_n[r][c], out_s[r][c], out_e[r][c], out_w[r][c])
                        # 3. PRIMARY-INPUT injection: override clb_in slots
                        #    marked as primary inputs (IO model, see docstring).
                        for i in range(self.EXT_IN):
                            net = tl.cluster_inputs.get(i)
                            if net is not None and net in pi_values:
                                clb_in_bits[i] = pi_values[net] & 1
                        # 4. CLB evaluation (inner fixpoint over eLUT feedback).
                        clb_out_bits = clb_eval_bits(tl, clb_in_bits)
                        clb_out_bits_grid[r][c] = clb_out_bits
                        clb_out_packed = 0
                        for j in range(N_elt):
                            clb_out_packed |= (clb_out_bits[j] & 1) << j
                    else:
                        clb_out_packed = 0      # routing-only / empty tile

                    # 5. SB outputs: Wilton routing of in_* + own clb_out inject.
                    n_n, n_s, n_e, n_w = tm.sb.outputs(
                        in_n, in_s, in_e, in_w, clb_out_packed)
                    if (n_n != out_n[r][c] or n_s != out_s[r][c]
                            or n_e != out_e[r][c] or n_w != out_w[r][c]):
                        changed = True
                        out_n[r][c] = n_n
                        out_s[r][c] = n_s
                        out_e[r][c] = n_e
                        out_w[r][c] = n_w
            if not changed:
                converged = True
                break

        self.last_iters = iters
        self.converged = converged

        # primary outputs: read the driver cluster's clb_out at the fixpoint.
        result: dict[str, int] = {}
        for (r, c, gi, net) in self.po_taps:
            result[net] = clb_out_bits_grid[r][c][gi] & 1
        return result


def simulate_fabric(
    db: FabricConfigDB,
    rc: RouteConfig,
    pi_values: dict[str, int],
    min_x: int,
    min_y: int,
    *,
    W: int = 12,
    N: int = 8,
    EXT_IN: int = 18,
    max_iters: int = 64,
) -> dict[str, int]:
    """One-shot fabric simulation -> ``{primary_output_net: bit}``.

    Thin wrapper around :class:`FabricSim` (builds models each call). For batch
    evaluation across many PI vectors, construct a ``FabricSim`` once and call
    ``evaluate`` per vector (avoids rebuilding the SB/CB models).
    """
    sim = FabricSim(db, rc, min_x, min_y, W=W, N_elt=N, ext_in=EXT_IN)
    return sim.evaluate(pi_values, max_iters=max_iters)
