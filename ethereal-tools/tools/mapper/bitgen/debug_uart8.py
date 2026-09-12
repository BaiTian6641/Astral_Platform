# SPDX-License-Identifier: MIT
"""Scratch debug 8: find cluster_inputs pins with no cb_sel (non-PI)."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from bitgen_pack import db_grid_bounds  # noqa: E402
from debug_uart import get_db_rc  # noqa: E402

W = 12
DIRS = ("n", "s", "e", "w")


def main():
    db, rc = get_db_rc()
    min_x, min_y, _a, _b = db_grid_bounds(db)
    pi = set(db.primary_inputs)
    print(f"primary inputs: {sorted(pi)}")
    print(f"po: {sorted(db.primary_outputs)}  aliases: {db.po_aliases}")
    bad = 0
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        tr = rc.tiles.get((r, c))
        cb = tr.cb_sel if tr else {}
        for i, net in sorted(tl.cluster_inputs.items()):
            if net is None or net in pi:
                continue
            if i not in cb:
                bad += 1
                print(f"UNROUTED: (r={r},c={c}) clb_in[{i}] needs net {net}"
                      f" but cb_sel keys={sorted(cb)}")
    print(f"total unrouted non-PI cluster inputs: {bad}")

    # also: is rxs[1] even a name the db knows? which nets drive what
    all_out_nets = {}
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        for gi, net in tl.cluster_outputs.items():
            if net:
                all_out_nets.setdefault(net, []).append((r, c, gi))
    for n in ("rxs[1]", "rx_stop", "rx_data", "$abc$1043$new_n133"):
        print(f"net {n}: driven at {all_out_nets.get(n)}")


if __name__ == "__main__":
    main()
