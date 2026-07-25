# SPDX-License-Identifier: MIT
"""bitgen_sim — pure-Python cluster/tile evaluator for the LEVEL-1 config DB.

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2 (task E0-MAP3
          increment 1). Evaluates a ``TileLogic`` (from bitgen_db) against a set
          of input net values and returns the cluster's driven nets. Mirrors the
          clb_t.sv / elut4.sv hardware semantics:

              vin = {pin3,pin2,pin1,pin0}            (pin0 = LSB)
              comb = tt[vin]                          (physical-order TT)
              muxed = ff_state[gi] if ff_en else comb (registered vs combinational)
              vout  = muxed ^ out_inv

          Pool select 0..17 = external ``clb_in`` net, 18..25 = feedback from
          eLUT4 ``(sel-18)``. Combinational feedback (virtual loops, legal user
          logic per C01 §2.4) is resolved by iterating to a fixpoint; for
          acyclic combinational clusters (e.g. c17) one pass suffices.

          FF modelling is intentionally minimal: ``ff_state`` is an opaque
          stored-state map supplied by the caller (a clocked driver is a later
          increment). For combinational c17 all ``ff_en`` are False, so the
          simulator is fully bit-true there.
"""
from __future__ import annotations

from bitgen_db import EXT_IN, FB_BASE, K, N, ElutConfig, TileLogic


def simulate_tile(
    tile: TileLogic,
    input_bits: dict[str, int],
    ff_state: dict[int, int] | None = None,
    max_iters: int = N + 2,
) -> dict[str, int]:
    """Evaluate a TileLogic, returning ``{driven_net: bit}``.

    ``input_bits``: net -> 0/1 for every source net the tile reads (primary
    inputs + any constants). ``ff_state``: eLUT4 index -> stored FF bit, used
    only when ``ElutConfig.ff_en`` is True. Unused/unset sources read as 0.
    """
    ff_state = ff_state or {}
    clb_out: dict[int, int] = {gi: 0 for gi in range(N)}
    # seed registered outputs from ff_state so combinational readers see them
    for gi, ec in tile.eluts.items():
        if ec.ff_en and gi in ff_state:
            clb_out[gi] = ff_state[gi] & 1

    def _elut_out(gi: int, ec: ElutConfig) -> int:
        vin = 0
        for gk in range(K):
            sel = tile.iib_mux.get((gi, gk), 0)
            if sel < EXT_IN:
                net = tile.cluster_inputs.get(sel)
                bit = input_bits.get(net, 0) if net is not None else 0
            else:
                bit = clb_out.get(sel - FB_BASE, 0)
            vin |= (bit & 1) << gk
        if ec.ff_en:
            muxed = ff_state.get(gi, 1 if ec.ff_rst_val else 0) & 1
        else:
            muxed = (ec.tt >> vin) & 1
        return muxed ^ (1 if ec.out_inv else 0)

    for _ in range(max_iters):
        changed = False
        for gi, ec in tile.eluts.items():
            out = _elut_out(gi, ec)
            if clb_out.get(gi) != out:
                clb_out[gi] = out
                changed = True
        if not changed:
            break

    return {net: clb_out[gi]
            for gi, net in tile.cluster_outputs.items()
            if net is not None}
