# SPDX-License-Identifier: MIT
"""Scratch debug 5: dump tile (3,0) LUT wiring vs blif ground truth."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from bitgen_db import K, EXT_IN, iib_decode  # noqa: E402
from debug_uart import get_db_rc  # noqa: E402


def main():
    db, rc = get_db_rc()
    tgt = None
    for (x, y), tl in db.tiles.items():
        if (x, y) == (0 + 1, 3 + 1):   # (r=3,c=0) -> VPR (x=0? c=x-min_x)
            tgt = tl
    # careful: r=y-min_y=3, c=x-min_x=0 -> (x,y) = (0+1, 3+1) = (1,4)
    tgt = db.tiles.get((1, 4))
    print(f"tile (1,4) = (r=3,c=0): {'FOUND' if tgt else 'MISSING'}")
    if not tgt:
        return
    print("cluster_inputs:")
    for i in sorted(tgt.cluster_inputs):
        print(f"  clb.I[{i:2d}] = {tgt.cluster_inputs[i]}")
    print("LUTs:")
    for gi in sorted(tgt.eluts):
        ec = tgt.eluts[gi]
        srcs = []
        for gk in range(K):
            kind, idx = iib_decode(tgt.iib_mux.get((gi, gk), 0), gk)
            if kind == "clb.I":
                srcs.append(f"I{idx}:{tgt.cluster_inputs.get(idx)}")
            else:
                jn = tgt.cluster_outputs.get(idx)
                jff = "*" if (tgt.eluts.get(idx) and tgt.eluts[idx].ff_en) else ""
                srcs.append(f"F{idx}:{jn}{jff}")
        print(f"  gi={gi} out={tgt.cluster_outputs.get(gi)}"
              f" ff={ec.ff_en} tt={ec.tt:#06x} in=[{', '.join(srcs)}]")


if __name__ == "__main__":
    main()
