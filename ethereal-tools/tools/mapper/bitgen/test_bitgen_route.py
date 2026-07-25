# SPDX-License-Identifier: MIT
"""pytest for bitgen_route — PathFinder on the real fabric topology
(task E0-MAP3 increment 4a).

Validates the Option-B router and SURFACES a key Phase-0 architectural finding:
on the v1 fabric (east-only inject + disjoint track-locked SB) c432 — as placed
by VPR — is NOT routable, for two independent structural reasons (see
``test_c432_routing_infeasibility_finding``). The router itself is proven sound
on a feasible subset (``test_c432_feasible_subset_routable`` proves
route_exists reachability on the real fabric for every net that IS routable)
and on a synthetic 1x2 case.

Per the task brief ("If c432 PathFinder doesn't converge in 30 iters, REPORT
(don't fake)"), the non-convergence is reported, not faked: the convergence
test is ``xfail(strict=True)`` documenting the finding, and the specific
infeasibility facts are asserted by a PASSING test so they cannot be silently
regressed or faked away.
"""
from __future__ import annotations

import os
from collections import Counter

import pytest

# importing bitgen_route first bootstraps sys.path for fabric_model / sb_model /
# cb_model / bitgen_db / bitgen_pack (see its module-level sys.path setup).
import bitgen_route
from bitgen_db import EXT_IN, N, build_db
from bitgen_route import (RouteConfig, apply_route_to_grid, extract_nets, route)
from fabric_model import FabricGrid

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MAPPER = os.path.join(REPO, "generated", "mapper")

C432_INFEASIBLE_TRACKS = (2, 7)      # over-subscribed (see finding test)


def _require_c432() -> None:
    for ext in ("net", "place", "blif"):
        if not os.path.exists(os.path.join(MAPPER, f"c432.{ext}")):
            pytest.skip(f"generated/mapper/c432.{ext} missing (run synth + VPR first)")


def _build_c432_db():
    _require_c432()
    return build_db(os.path.join(MAPPER, "c432.net"),
                    os.path.join(MAPPER, "c432.place"),
                    os.path.join(MAPPER, "c432.blif"))


# =============================================================================
# 1. Net extraction
# =============================================================================

def test_route_extract_nets_c432():
    """Inter-cluster nets exist; each has a driver clb_out[j<N] and >=1 sink;
    PI/PO categories are reported."""
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    nets = extract_nets(db, min_x, min_y)

    inter = [n for n in nets if n.kind == "inter"]
    n_pi = sum(1 for n in nets if n.kind == "primary_in")
    n_po = sum(1 for n in nets if n.kind == "primary_out")
    assert len(inter) > 0, "c432 should have inter-cluster nets (9 clusters)"
    for n in inter:
        assert n.driver_node is not None
        assert n.driver_node[2] == "clb_out"
        assert n.driver_node[3] < N, (
            f"net {n.name}: driver clb_out[{n.driver_node[3]}] >= N={N} "
            f"(inject-pin constraint violation)")
        assert len(n.sink_nodes) >= 1
    print(f"\n[c432 nets] inter={len(inter)} primary_in={n_pi} primary_out={n_po}")


# =============================================================================
# 2. THE KEY TEST: c432 routes conflict-free  (xfail — see finding below)
# =============================================================================

@pytest.mark.xfail(
    strict=True,
    reason=(
        "Phase-0 finding (E0-MAP3 incr 4a): c432 is NOT routable on the v1 "
        "fabric as placed by VPR. Two independent structural causes: (a) east-"
        "only inject strands the 3 nets driven from the eastmost column "
        "(c=C-1) — their signal can only reach the driver's own tile; "
        "(b) disjoint track-locked SB over-subscribes tracks 7 (7 nets) and "
        "2 (6 nets), which never converge even in isolation (>=14 over-used "
        "nodes across 200 iters x 5 seeds). Root cause: VPR packs nets to fle "
        "indices (-> fabric tracks) with no awareness of the fabric's track "
        "locking. This xfail is STRICT: if a fabric/tooling change makes c432 "
        "routable, it will XPASS and flag the change for review. See the "
        "acceptance report and test_c432_routing_infeasibility_finding."))
def test_c432_routes_conflict_free():
    """PathFinder would route ALL inter-cluster nets with zero over-used
    resources IF c432 were routable on the v1 fabric. It is not (xfail)."""
    db = _build_c432_db()
    rc = route(db)
    print(f"\n[c432 route] n_nets={rc.n_nets} n_routed={rc.n_routed} "
          f"n_iters={rc.n_iters} n_overuse_final={rc.n_overuse_final} "
          f"converged={rc.converged} unrouted_count={len(rc.unrouted)}")
    assert rc.converged
    assert rc.n_routed == rc.n_nets
    assert rc.n_overuse_final == 0
    assert rc.unrouted == []


# =============================================================================
# 3. THE FINDING (executable, PASSING) — documents the infeasibility precisely
# =============================================================================

def test_c432_routing_infeasibility_finding():
    """Asserts the specific structural facts behind c432's non-routability on
    the v1 fabric. PASSING = the finding is real and stable; if the router were
    ever 'fixed' to fake convergence, this test would break."""
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    rc = route(db, max_iters=30, seed=0)

    # ---- (a) non-convergence on the full design ----------------------------
    assert not rc.converged, "expected non-convergence (the finding)"
    assert rc.n_overuse_final > 0
    print(f"\n[finding] full-design: converged={rc.converged}, "
          f"{rc.n_overuse_final} over-used nodes at iter {rc.n_iters}")

    # ---- (b) east-edge-stranded nets (east-only inject) --------------------
    # A net driven from column c=C-1 whose sinks lie outside the driver tile is
    # structurally unreachable: inject emits ONLY east (out_e[j]) and there is
    # no east neighbor, so the signal cannot leave the driver tile.
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    C = max_x - min_x + 1
    nets = extract_nets(db, min_x, min_y)
    inter = [n for n in nets if n.kind == "inter"]
    east_edge_stranded = []
    for n in inter:
        d = n.driver_node
        assert d is not None
        drv_r, drv_c = d[0], d[1]
        if drv_c == C - 1:                                   # eastmost column
            outside = [s for s in n.sink_nodes
                       if not (s[0] == drv_r and s[1] == drv_c)]
            if outside:
                east_edge_stranded.append(n.name)
    assert len(east_edge_stranded) == 3, (
        f"expected exactly 3 east-edge-stranded nets, got {east_edge_stranded}")
    unreachable_names = {name for name, _reason in rc.unrouted
                         if "unreachable" in _reason}
    assert set(east_edge_stranded).issubset(unreachable_names)
    print(f"[finding] east-edge-stranded (east-only inject): {east_edge_stranded}")

    # ---- (c) over-subscribed tracks (track-locked disjoint SB) -------------
    # Tracks 7 (7 nets) and 2 (6 nets) never converge even in isolation.
    j_counts = Counter(n.driver_node[3] for n in inter)
    over_subs = [j for j, c in j_counts.items() if c >= 5]
    print(f"[finding] per-track driver counts: {dict(j_counts)}; "
          f"over-subscribed (>=5 nets): {over_subs}")
    assert set(C432_INFEASIBLE_TRACKS).issubset(set(over_subs))
    # prove tracks 7 and 2 are individually infeasible on the real topology
    R = max_y - min_y + 1
    sink_clb_in = set()
    for n in inter:
        sink_clb_in.update(n.sink_nodes)
    adj = bitgen_route._build_possibility_graph(R, C, 12, 8, 18, sink_clb_in)
    for j_bad in C432_INFEASIBLE_TRACKS:
        sub = [n for n in inter if n.driver_node[3] == j_bad]
        conv, _it, ou, _edges = bitgen_route._run_pathfinder(
            sub, adj, max_iters=60, seed=0, verbose=False)
        print(f"[finding] track j={j_bad} alone ({len(sub)} nets): "
              f"converged={conv}, over-used={ou}")
        assert not conv, (
            f"track j={j_bad} unexpectedly routed — re-examine the finding")


# =============================================================================
# 4. POSITIVE: the routable subset IS realizable on the real fabric
# =============================================================================

def test_c432_feasible_subset_routable():
    """Route the FEASIBLE subset of c432 (exclude the over-subscribed tracks 2
    & 7 and the east-edge-stranded nets). It MUST converge, and every routed
    net's driver->sink must be ``route_exists`` True on the real ``FabricGrid``
    — the Option-B realizability proof, on the subset the v1 fabric can carry.

    Cross-track nets never share wires (track-j wires are disjoint from
    track-j' wires), so routing each feasible track independently is exact."""
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    R, C = max_y - min_y + 1, max_x - min_x + 1
    W, N_INJ, EXT_IN_v = 12, 8, 18

    nets = extract_nets(db, min_x, min_y)
    inter = [n for n in nets if n.kind == "inter"]
    feasible = []
    for n in inter:
        d = n.driver_node
        assert d is not None
        if d[3] in C432_INFEASIBLE_TRACKS:
            continue
        if d[1] == C - 1:                          # east-edge driver (stranded)
            continue
        feasible.append(n)
    assert len(feasible) > 0

    sink_clb_in = set()
    for n in feasible:
        sink_clb_in.update(n.sink_nodes)
    adj = bitgen_route._build_possibility_graph(R, C, W, N_INJ, EXT_IN_v, sink_clb_in)
    conv, n_iters, ou, net_edges = bitgen_route._run_pathfinder(
        feasible, adj, max_iters=60, seed=0, verbose=False)
    print(f"\n[feasible subset] {len(feasible)} nets: converged={conv} "
          f"iters={n_iters} over-used={ou}")
    assert conv, f"feasible subset did not converge ({ou} over-used) — router bug?"

    rc = RouteConfig(grid_dims=(R, C, W, N_INJ, EXT_IN_v))
    bitgen_route._populate_tiles(rc, net_edges, W)
    grid = FabricGrid(R=R, C=C, W=W, N_INJ=N_INJ, EXT_IN=EXT_IN_v)
    apply_route_to_grid(grid, rc)

    checked = 0
    for n in feasible:
        for sink in n.sink_nodes:
            assert grid.route_exists(n.driver_node, sink), (
                f"net {n.name}: route_exists failed {n.driver_node} -> {sink}")
            checked += 1
    print(f"[feasible subset] {checked} driver->sink pairs all route_exists True")

    # structural no-multi-drive on the feasible subset
    for (r, c), tr in rc.tiles.items():
        for j in tr.inject_en:
            assert tr.sb_sel.get(("e", j), 0) == 0, (
                f"tile ({r},{c}): out_e[{j}] multi-driven")


# =============================================================================
# 5. Synthetic 1x2 sanity test
# =============================================================================

def test_synthetic_1x2_single_net():
    """A 1x2 fabric: route clb_out[0]@(0,0) -> clb_in[0]@(0,1). Must produce
    inject_en{0}@(0,0), a valid SB path, cb_sel[0]@(0,1), and route_exists True."""
    from bitgen_db import FabricConfigDB, TileLogic
    t0 = TileLogic(cluster_inputs={i: None for i in range(EXT_IN)},
                   cluster_outputs={j: None for j in range(N)})
    t0.cluster_outputs[0] = "x"
    t1 = TileLogic(cluster_inputs={i: None for i in range(EXT_IN)},
                   cluster_outputs={j: None for j in range(N)})
    t1.cluster_inputs[0] = "x"
    db = FabricConfigDB()
    db.tiles[(0, 0)] = t0          # VPR grid (x,y): driver at x=0
    db.tiles[(1, 0)] = t1          # sink at x=1 (east of driver)
    db.primary_inputs = []
    db.primary_outputs = []

    rc = route(db, max_iters=10)
    assert rc.converged, f"synthetic net didn't converge: {rc.unrouted}"
    assert rc.n_nets == 1 and rc.n_routed == 1
    assert (0, 0) in rc.tiles and (0, 1) in rc.tiles
    assert 0 in rc.tiles[(0, 0)].inject_en, "driver tile must inject clb_out[0]"
    assert 0 in rc.tiles[(0, 1)].cb_sel, "sink tile must select clb_in[0]"
    track = rc.tiles[(0, 1)].cb_sel[0]
    assert 0 <= track < 4 * 12

    R, C, W, N_INJ, EXT_IN_v = rc.grid_dims
    assert (R, C) == (1, 2)
    grid = FabricGrid(R=R, C=C, W=W, N_INJ=N_INJ, EXT_IN=EXT_IN_v)
    apply_route_to_grid(grid, rc)
    assert grid.route_exists((0, 0, "clb_out", 0), (0, 1, "clb_in", 0)) is True
