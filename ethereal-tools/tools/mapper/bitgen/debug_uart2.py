# SPDX-License-Identifier: MIT
"""Scratch debug 2: trace the D-path of rxs[1] at the divergence tick 913."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from bitgen_db import K, iib_decode  # noqa: E402
from bitgen_pack import db_grid_bounds  # noqa: E402
import fabric_sim  # noqa: E402
from debug_uart import Ref, get_db_rc, stream  # noqa: E402


def main():
    db, rc = get_db_rc()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    sim = fabric_sim.FabricSim(db, rc, min_x, min_y)

    # locate FF eLUTs by Q net name
    ff_at: dict[str, tuple[int, int, int]] = {}
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        for gi, ec in tl.eluts.items():
            if ec.ff_en:
                net = tl.cluster_outputs.get(gi)
                if net:
                    ff_at[net] = (r, c, gi)
    print("FF placement:")
    for net in sorted(ff_at):
        r, c, gi = ff_at[net]
        print(f"  {net:12s} tile (r={r},c={c}) gi={gi}")

    # trace D sources of rxs[1] and rxs[2]
    for qnet in ("rx_stop", "rxs[2]"):
        r, c, gi = ff_at[qnet]
        tl = db.tiles[(c + min_x, r + min_y)]
        print(f"\n{qnet}: tile (r={r},c={c}) gi={gi} tt={tl.eluts[gi].tt:#06x}")
        for gk in range(K):
            kind, idx = iib_decode(tl.iib_mux.get((gi, gk), 0), gk)
            if kind == "clb.I":
                src = f"clb.I[{idx}] = {tl.cluster_inputs.get(idx)}"
            else:
                jnet = tl.cluster_outputs.get(idx)
                jff = " (FF)" if (tl.eluts.get(idx) is not None
                                  and tl.eluts[idx].ff_en) else ""
                src = f"clb_out[{idx}] = {jnet}{jff}"
            print(f"  lut_in[{gk}] <- {src}")

    # what the D-LUT of rxs[1] actually sees pre-edge at tick 913
    ref = Ref()
    state: dict = {}
    stim = stream()
    for t, rx in enumerate(stim):
        if t == 913:
            break
        ref.step(rx)
        _po, state = sim.tick({"rx": rx}, state)

    # re-run evaluate pre-edge and capture clb_in of the rxs[1] tile
    r1, c1, g1 = ff_at["rx_stop"]
    tl1 = db.tiles[(c1 + min_x, r1 + min_y)]
    saved_io = {}

    orig_eval = fabric_sim.clb_eval_bits

    def spy_eval(tile, clb_in_bits, ff_state=None):
        out = orig_eval(tile, clb_in_bits, ff_state)
        if tile is tl1:
            saved_io["in"] = list(clb_in_bits)
            saved_io["out"] = list(out)
            saved_io["ff"] = dict(ff_state or {})
        return out

    fabric_sim.clb_eval_bits = spy_eval
    sim.evaluate({"rx": 0}, max_iters=128, ff_state=state)
    fabric_sim.clb_eval_bits = orig_eval

    print(f"\npre-edge (tick 913) snapshot at rxs[1] tile (r={r1},c={c1}):")
    for gk in range(K):
        kind, idx = iib_decode(tl1.iib_mux.get((g1, gk), 0), gk)
        if kind == "clb.I":
            print(f"  lut_in[{gk}] pin clb.I[{idx}] ({tl1.cluster_inputs.get(idx)}"
                  f") = {saved_io['in'][idx]}")
        else:
            print(f"  lut_in[{gk}] feedback clb_out[{idx}] "
                  f"({tl1.cluster_outputs.get(idx)}) = {saved_io['out'][idx]}")
    ec = tl1.eluts[g1]
    print(f"  tt={ec.tt:#06x} -> D = tt[vin] should be 1 (marker at rxs[2])")
    print(f"  last_ff_next[rxs[1]] = {sim.last_ff_next.get((r1, c1, g1))}")
    print(f"  full last_ff_next rxs[1] tile: "
          f"{ {k: v for k, v in sim.last_ff_next.items() if k[:2] == (r1, c1)} }")


if __name__ == "__main__":
    main()
