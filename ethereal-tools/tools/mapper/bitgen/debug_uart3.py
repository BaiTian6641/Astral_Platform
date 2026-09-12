# SPDX-License-Identifier: MIT
"""Scratch debug 3: convergence diagnostics per tick around 913."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from bitgen_pack import db_grid_bounds  # noqa: E402
import fabric_sim  # noqa: E402
from debug_uart import get_db_rc, stream  # noqa: E402


def main():
    db, rc = get_db_rc()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    sim = fabric_sim.FabricSim(db, rc, min_x, min_y)

    # find the rx_stop FF key
    key = None
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        for gi, net in tl.cluster_outputs.items():
            if net == "rx_stop":
                key = (r, c, gi)
    print(f"rx_stop key = {key}")

    state: dict = {}
    stim = stream()
    bad = 0
    max_seen = 0
    for t, rx in enumerate(stim):
        # replicate tick() but with diagnostics + max_iters=256
        sim.evaluate({"rx": rx}, max_iters=256, ff_state=state or {})
        nxt = dict(sim.last_ff_next)
        it1, cv1 = sim.last_iters, sim.converged
        sim.evaluate({"rx": rx}, max_iters=256, ff_state=nxt)
        it2, cv2 = sim.last_iters, sim.converged
        state = nxt
        max_seen = max(max_seen, it1, it2)
        if not cv1 or not cv2:
            bad += 1
            if bad <= 5:
                print(f"tick {t}: UNCONVERGED it1={it1} cv1={cv1} "
                      f"it2={it2} cv2={cv2}")
        if 910 <= t <= 916:
            print(f"tick {t} rx={rx}: it1={it1} cv={cv1} it2={it2} cv2={cv2} "
                  f"rx_stop_state={state.get(key)} "
                  f"rx_stop_D_was={nxt.get(key)}")
    print(f"max iters seen = {max_seen}; unconverged ticks = {bad}/{len(stim)}")


if __name__ == "__main__":
    main()
