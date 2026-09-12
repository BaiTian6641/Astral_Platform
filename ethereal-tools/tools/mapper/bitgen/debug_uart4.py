# SPDX-License-Identifier: MIT
"""Scratch debug 4: full dependency graph (tracks+CB+CLB) -> find comb cycles."""
from __future__ import annotations

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_TOOLS = os.path.dirname(os.path.dirname(_HERE))
_INTER = os.path.normpath(os.path.join(
    _TOOLS, "..", "..", "ethereal-fabric", "tests", "interconnect"))
sys.path.insert(0, _INTER)
from bitgen_db import K, EXT_IN, iib_decode  # noqa: E402
from bitgen_pack import db_grid_bounds  # noqa: E402
from sb_model import _SOURCES, _wilton_track  # type: ignore # noqa: E402
from debug_uart import get_db_rc  # noqa: E402

W = 12


def main():
    db, rc = get_db_rc()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    R = max(y for _x, y in db.tiles) - min_y + 1
    C = max(x for x, _y in db.tiles) - min_x + 1

    edges: set[tuple[tuple, tuple]] = set()
    clb_out_net: dict[tuple, str] = {}
    clb_in_net: dict[tuple, str] = {}
    comb_luts: set[tuple] = set()   # (r,c,gi) with ff_en == False

    # CLB internal edges + node naming
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        for gi, net in tl.cluster_outputs.items():
            if net:
                clb_out_net[(r, c, gi)] = net
        for i, net in tl.cluster_inputs.items():
            if net:
                clb_in_net[(r, c, i)] = net
        for gi, ec in tl.eluts.items():
            if not ec.ff_en:
                comb_luts.add((r, c, gi))
                for gk in range(K):
                    kind, idx = iib_decode(tl.iib_mux.get((gi, gk), 0), gk)
                    if kind == "clb.I":
                        if idx < EXT_IN:
                            edges.add((("clb_in", r, c, idx),
                                       ("clb_out", r, c, gi)))
                    else:
                        edges.add((("clb_out", r, c, idx),
                                   ("clb_out", r, c, gi)))

    # routing: SB sel + inject + CB + channel edges
    for (r, c), tr in rc.tiles.items():
        for (d, t), sel in tr.sb_sel.items():
            if sel == 0:
                continue
            if tr.inject.get(t) == d:
                continue                    # inject overrides the mux
            src = _SOURCES[d][sel - 1]
            src_t = _wilton_track(d, src, t, W)
            edges.add((("in", r, c, src, src_t), ("out", r, c, d, t)))
        for j, d in tr.inject.items():
            edges.add((("clb_out", r, c, j), ("out", r, c, d, j)))
        DIRS = ("n", "s", "e", "w")
        for i, k in tr.cb_sel.items():
            p = (i % 2) + 2 * k
            if p < 4 * W:
                d, t = DIRS[p // W], p % W
                edges.add((("out", r, c, d, t), ("clb_in", r, c, i)))

    # channel edges: out_(r,c,d,t) -> in_(neighbor, d, t)
    for r in range(R):
        for c in range(C):
            for t in range(W):
                edges.add((("out", r, c, "n", t), ("in", r - 1, c, "n", t)))
                edges.add((("out", r, c, "s", t), ("in", r + 1, c, "s", t)))
                edges.add((("out", r, c, "e", t), ("in", r, c + 1, "e", t)))
                edges.add((("out", r, c, "w", t), ("in", r, c - 1, "w", t)))

    # trim to reachable/interesting: find SCCs containing comb clb_out nodes
    # Tarjan via simple iterative DFS
    import collections
    adj = collections.defaultdict(list)
    for a, b in edges:
        adj[a].append(b)

    index_counter = [0]
    stack, lowlink, index, on_stack = [], {}, {}, set()
    sccs = []

    for start in list(adj):
        if start in index:
            continue
        work = [(start, 0)]
        while work:
            node, pi = work[-1]
            if pi == 0:
                index[node] = lowlink[node] = index_counter[0]
                index_counter[0] += 1
                stack.append(node)
                on_stack.add(node)
            recurse = False
            children = adj[node]
            for i in range(pi, len(children)):
                ch = children[i]
                if ch not in index:
                    work[-1] = (node, i + 1)
                    work.append((ch, 0))
                    recurse = True
                    break
                elif ch in on_stack:
                    lowlink[node] = min(lowlink[node], index[ch])
            if recurse:
                continue
            if lowlink[node] == index[node]:
                scc = []
                while True:
                    w = stack.pop()
                    on_stack.discard(w)
                    scc.append(w)
                    if w == node:
                        break
                sccs.append(scc)
            work.pop()
            if work:
                parent = work[-1][0]
                lowlink[parent] = min(lowlink[parent], lowlink[node])

    def label(n):
        kind = n[0]
        if kind == "clb_out":
            return f"clb_out[{clb_out_net.get((n[1], n[2], n[3]), n[3])}]@({n[1]},{n[2]})" + \
                   ("" if (n[1], n[2], n[3]) in comb_luts else "[FF]")
        if kind == "clb_in":
            return f"clb_in[{clb_in_net.get((n[1], n[2], n[3]), n[3])}]@({n[1]},{n[2]})"
        return f"{n[0]}_{n[3]}[{n[4]}]@({n[1]},{n[2]})"

    n_cyc = 0
    for scc in sccs:
        if len(scc) > 1:
            n_cyc += 1
            print(f"\n=== CYCLE (SCC size {len(scc)}) ===")
            for n in scc:
                outs = [label(b) for a, b in edges if a == n and b in set(scc)]
                print(f"  {label(n)}  ->  {outs}")
    if n_cyc == 0:
        print("no cycles found in graph WITHOUT cb edges (cb_sel decoding TODO)")


if __name__ == "__main__":
    main()
