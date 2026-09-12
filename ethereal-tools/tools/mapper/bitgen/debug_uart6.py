# SPDX-License-Identifier: MIT
"""Scratch debug 6: find oscillating track bits in the outer fixpoint."""
from __future__ import annotations

import os
import sys
import collections

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from bitgen_pack import db_grid_bounds  # noqa: E402
import fabric_sim  # noqa: E402
from debug_uart import get_db_rc, stream, Ref  # noqa: E402


def main():
    db, rc = get_db_rc()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    sim = fabric_sim.FabricSim(db, rc, min_x, min_y)

    # advance to tick 300 (DATA phase) using tick() as-is
    state: dict = {}
    stim = stream()
    for t, rx in enumerate(stim):
        if t == 300:
            break
        _po, state = sim.tick({"rx": rx}, state)

    R, C, N_elt = sim.R, sim.C, sim.N
    ff_by_tile: dict[tuple[int, int], dict[int, int]] = {}
    for (r, c, gi), bit in state.items():
        ff_by_tile.setdefault((r, c), {})[gi] = bit & 1
    pi = {"rx": stim[300]}

    out_n = [[0] * C for _ in range(R)]
    out_s = [[0] * C for _ in range(R)]
    out_e = [[0] * C for _ in range(R)]
    out_w = [[0] * C for _ in range(R)]
    W = 12
    flip = collections.Counter()
    DIRS = ("n", "s", "e", "w")
    for it in range(300):
        for r in range(R):
            row_above = out_s[r - 1] if r > 0 else None
            row_below = out_n[r + 1] if r < R - 1 else None
            for c in range(C):
                tm = sim.tiles[r][c]
                in_n = row_above[c] if row_above is not None else 0
                in_s = row_below[c] if row_below is not None else 0
                in_e = out_w[r][c + 1] if c < C - 1 else 0
                in_w = out_e[r][c - 1] if c > 0 else 0
                tl = tm.logic
                if tl is not None:
                    clb_in_bits = tm.cb.clb_in(
                        out_n[r][c], out_s[r][c], out_e[r][c], out_w[r][c])
                    for i in range(sim.EXT_IN):
                        net = tl.cluster_inputs.get(i)
                        if net is not None and net in pi:
                            clb_in_bits[i] = pi[net] & 1
                    clb_out_bits = fabric_sim.clb_eval_bits(
                        tl, clb_in_bits, ff_by_tile.get((r, c)))
                    clb_out_packed = 0
                    for j in range(N_elt):
                        clb_out_packed |= (clb_out_bits[j] & 1) << j
                else:
                    clb_out_packed = 0
                n_n, n_s, n_e, n_w = tm.sb.outputs(
                    in_n, in_s, in_e, in_w, clb_out_packed)
                old = (out_n[r][c], out_s[r][c], out_e[r][c], out_w[r][c])
                new = (n_n, n_s, n_e, n_w)
                if old != new:
                    for di in range(4):
                        x = old[di] ^ new[di]
                        t = 0
                        while x:
                            if x & 1:
                                flip[(r, c, DIRS[di], t)] += 1
                            x >>= 1
                            t += 1
                out_n[r][c], out_s[r][c], out_e[r][c], out_w[r][c] = new

    print(f"top flipping nodes over 300 iters (of {len(flip)} ever flipped):")
    for (r, c, d, t), n in flip.most_common(20):
        print(f"  out_{d}[{t}] @ (r={r},c={c}): changed {n} times")


if __name__ == "__main__":
    main()
