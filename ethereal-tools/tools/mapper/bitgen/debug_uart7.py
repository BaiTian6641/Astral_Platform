# SPDX-License-Identifier: MIT
"""Scratch debug 7: decode drivers of the oscillating ring nodes."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_INTER = os.path.normpath(os.path.join(
    _HERE, "..", "..", "..", "..", "ethereal-fabric", "tests", "interconnect"))
if _INTER not in sys.path:
    sys.path.insert(0, _INTER)

from bitgen_db import K, iib_decode  # noqa: E402
from bitgen_pack import db_grid_bounds  # noqa: E402
from sb_model import _SOURCES, _wilton_track  # type: ignore # noqa: E402
from debug_uart import get_db_rc  # noqa: E402

W = 12
DIRS = ("n", "s", "e", "w")
RING = [(1, 2, "e", 0), (1, 1, "n", 0), (0, 1, "e", 10), (0, 2, "s", 11)]


def main():
    db, rc = get_db_rc()
    min_x, min_y, _a, _b = db_grid_bounds(db)
    tl_of = {}
    for (x, y), tl in db.tiles.items():
        tl_of[(y - min_y, x - min_x)] = tl

    for (r, c) in [(1, 2), (1, 1), (0, 1), (0, 2)]:
        tr = rc.tiles[(r, c)]
        tl = tl_of[(r, c)]
        print(f"\n=== tile (r={r},c={c}) ===")
        print("  injects: " + ", ".join(
            f"clb_out[{j}]={tl.cluster_outputs.get(j)} -> out_{d}[{j}]"
            for j, d in sorted(tr.inject.items())))
        for i, k in sorted(tr.cb_sel.items()):
            p = (i % 2) + 2 * k
            d, t = DIRS[p // W], p % W
            print(f"  cb: clb_in[{i:2d}] ({tl.cluster_inputs.get(i)})"
                  f" <- out_{d}[{t}]")
        for gi, ec in sorted(tl.eluts.items()):
            srcs = []
            for gk in range(K):
                kind, idx = iib_decode(tl.iib_mux.get((gi, gk), 0), gk)
                if kind == "clb.I":
                    srcs.append(f"I{idx}:{tl.cluster_inputs.get(idx)}")
                else:
                    srcs.append(f"F{idx}:{tl.cluster_outputs.get(idx)}"
                                f"{'*' if tl.eluts[idx].ff_en else ''}")
            print(f"  LUT gi={gi} out={tl.cluster_outputs.get(gi)} "
                  f"ff={ec.ff_en} in=[{', '.join(srcs)}]")

    print("\n=== ring node drivers ===")
    for (r, c, d, t) in RING:
        tr = rc.tiles[(r, c)]
        tl = tl_of[(r, c)]
        inj = tr.inject.get(t)
        sel = tr.sb_sel.get((d, t))
        desc = ""
        if inj == d:
            desc += f"INJECT clb_out[{t}]={tl.cluster_outputs.get(t)}"
        if sel:
            src = _SOURCES[d][sel - 1]
            src_t = _wilton_track(d, src, t, W)
            desc += f" MUX sel={sel} <- in_{src}[{src_t}]"
        if not desc:
            desc = "DISCONNECT(0)"
        rr = {"n": (r - 1, c), "s": (r + 1, c),
              "e": (r, c + 1), "w": (r, c - 1)}[d]
        nxt = rc.tiles.get(rr)
        if nxt:
            for (dd, tt), s in nxt.sb_sel.items():
                if s:
                    sd = _SOURCES[dd][s - 1]
                    if sd == d and _wilton_track(dd, sd, tt, W) == t:
                        desc += f" | muxed onward: out_{dd}[{tt}]@{rr}"
            if nxt.inject.get(t) == d:
                desc += f" | !! INJECT-CONFLICT at {rr}"
        print(f"out_{d}[{t}]@({r},{c}): {desc}")

    # which clb_in taps READ each ring node (local CBs)
    print("\n=== CB taps on ring tracks ===")
    for (r, c) in {(1, 2), (1, 1), (0, 1), (0, 2)}:
        tr = rc.tiles[(r, c)]
        tl = tl_of[(r, c)]
        for i, k in sorted(tr.cb_sel.items()):
            p = (i % 2) + 2 * k
            d, t = DIRS[p // W], p % W
            if (r, c, d, t) in RING:
                readers = []
                for gi, ec in tl.eluts.items():
                    for gk in range(K):
                        kind, idx = iib_decode(
                            tl.iib_mux.get((gi, gk), 0), gk)
                        if kind == "clb.I" and idx == i:
                            readers.append(
                                f"gi={gi}({tl.cluster_outputs.get(gi)},"
                                f"ff={ec.ff_en})")
                print(f"  out_{d}[{t}]@({r},{c}) -> clb_in[{i}] "
                      f"({tl.cluster_inputs.get(i)}) read by {readers}")


if __name__ == "__main__":
    main()
