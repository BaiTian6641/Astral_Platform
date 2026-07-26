# SPDX-License-Identifier: MIT
"""pytest for bitgen_route — PathFinder on the real fabric topology
(task E0-MAP3 increment 4a, refined to the WILTON SB 2026-07-26).

Validates the Option-B router. HEADLINE: c432 — as placed by VPR — now ROUTES
CONFLICT-FREE on the v1.1 fabric after the 2026-07-26 Wilton SB change (Fs=3,
track-permuting). History: the prior disjoint SB track-LOCKED every net to
track ``t = driver_j`` for its whole route (no track-change mux), so c432's
tracks 7 (7 nets) and 2 (6 nets) were structurally over-subscribed and
PathFinder could not converge (incr 4a Cause 2). Bidirectional inject had
already fixed Cause 1 (east-edge driver stranding). Wilton breaks the locking:
a signal changes track index at each SB hop, so contended wires detour — c432
converges in ~46 iters with all 29 inter-cluster nets routed and zero over-used
nodes, and every driver->sink pair is ``route_exists`` True on the configured
real FabricGrid (the Option-B realizability proof).

``test_c432_routes_conflict_free`` is THE gate (convergence + reachability);
``test_c432_wilton_resolves_cause2`` is a regression guard proving the formerly
infeasible tracks 2 & 7 now route even in isolation; the feasible-subset and
synthetic 1x2 cases cover the router's soundness on smaller inputs.
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

# Tracks that were STRUCTURALLY infeasible under the prior disjoint SB (Cause 2:
# over-subscribed — j=2 had 6 nets, j=7 had 7 nets). Under the Wilton SB these
# now route conflict-free even in isolation (see test_c432_wilton_resolves_cause2).
C432_INFEASIBLE_TRACKS = (2, 7)


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
# 2. THE GATE: c432 routes conflict-free on the v1.1 (Wilton) fabric
# =============================================================================

def test_c432_routes_conflict_free():
    """HEADLINE: c432 routes conflict-free on the v1.1 (Wilton) fabric.

    All 29 inter-cluster nets route with zero over-used nodes, and every
    driver->sink pair is ``route_exists`` True on the configured real
    FabricGrid (the Option-B realizability proof). Under the prior disjoint SB
    this test was ``xfail`` (Cause 2 track-locking); the 2026-07-26 Wilton SB
    (Fs=3, track-permuting) resolves it. Convergence at seed=0 is ~46 iters
    (deterministic); ``max_iters`` carries margin.
    """
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    rc = route(db, max_iters=100, seed=0)
    print(f"\n[c432 route] n_nets={rc.n_nets} n_routed={rc.n_routed} "
          f"n_iters={rc.n_iters} n_overuse_final={rc.n_overuse_final} "
          f"converged={rc.converged} unrouted_count={len(rc.unrouted)}")
    assert rc.converged
    assert rc.n_routed == rc.n_nets
    assert rc.n_overuse_final == 0
    assert rc.unrouted == []

    # realizability proof: every driver->sink route_exists on the real grid
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    R, C = max_y - min_y + 1, max_x - min_x + 1
    grid = FabricGrid(R=R, C=C, W=12, N_INJ=8, EXT_IN=18)
    apply_route_to_grid(grid, rc)
    nets = extract_nets(db, min_x, min_y)
    inter = [n for n in nets if n.kind == "inter"]
    checked = 0
    for n in inter:
        for sink in n.sink_nodes:
            assert grid.route_exists(n.driver_node, sink), (
                f"net {n.name}: route_exists failed {n.driver_node} -> {sink}")
            checked += 1
    print(f"[c432 route] {checked} driver->sink pairs all route_exists True")

    # structural no-multi-drive: an injected out_D[j] never also carries an SB sel
    for (r, c), tr in rc.tiles.items():
        for j, d in tr.inject.items():
            assert tr.sb_sel.get((d, j), 0) == 0, (
                f"tile ({r},{c}): out_{d}[{j}] multi-driven (inject + SB sel)")


# =============================================================================
# 3. REGRESSION GUARD: Wilton resolves Cause 2 (formerly-infeasible tracks)
# =============================================================================

def test_c432_wilton_resolves_cause2():
    """Regression guard for the Wilton fix.

    The tracks that were STRUCTURALLY infeasible under the disjoint SB (Cause 2:
    tracks 2 & 7, over-subscribed with 6/7 nets) still carry many nets under the
    same VPR placement — yet each now converges conflict-free EVEN IN ISOLATION
    under the Wilton SB. PASSING = the Wilton fix is real and stable; this
    breaks loudly if the SB topology ever regresses to disjoint track-locking.
    """
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    R, C = max_y - min_y + 1, max_x - min_x + 1
    nets = extract_nets(db, min_x, min_y)
    inter = [n for n in nets if n.kind == "inter"]
    j_counts = Counter(n.driver_node[3] for n in inter)
    print(f"\n[cause2] per-track driver counts: {dict(sorted(j_counts.items()))}")
    # the formerly over-subscribed tracks still carry many nets...
    for j_bad in C432_INFEASIBLE_TRACKS:
        assert j_counts[j_bad] >= 5, (
            f"track j={j_bad} no longer over-subscribed; re-examine the guard")
    sink_clb_in = set()
    for n in inter:
        sink_clb_in.update(n.sink_nodes)
    adj = bitgen_route._build_possibility_graph(R, C, 12, 8, 18, sink_clb_in)
    # ...yet each now converges in isolation (was impossible under disjoint)
    for j_bad in C432_INFEASIBLE_TRACKS:
        sub = [n for n in inter if n.driver_node[3] == j_bad]
        conv, n_iters, ou, _edges = bitgen_route._run_pathfinder(
            sub, adj, max_iters=60, seed=0, verbose=False)
        print(f"[cause2] track j={j_bad} alone ({len(sub)} nets): "
              f"converged={conv}, iters={n_iters}, over-used={ou}")
        assert conv, (
            f"track j={j_bad} did NOT converge under Wilton — Cause 2 regressed?")
        assert ou == 0


# =============================================================================
# 4. POSITIVE: a subset is realizable on the real fabric (router soundness)
# =============================================================================

def test_c432_feasible_subset_routable():
    """Route a SUBSET of c432 (exclude the formerly-infeasible tracks 2 & 7).
    It MUST converge, and every routed net's driver->sink must be
    ``route_exists`` True on the real ``FabricGrid`` — the Option-B realizability
    proof, on a smaller input. (Under the Wilton SB the FULL design now routes —
    see ``test_c432_routes_conflict_free`` — so this is a redundant-but-valid
    soundness check on the subset; it predates the Wilton fix as the only
    positive c432 routability evidence under the disjoint SB.)

    Cross-track nets never share wires on the disjoint portion of the path, so
    routing each track independently is exact."""
    from bitgen_pack import db_grid_bounds
    db = _build_c432_db()
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    R, C = max_y - min_y + 1, max_x - min_x + 1
    W, N_INJ, EXT_IN_v = 12, 8, 18

    nets = extract_nets(db, min_x, min_y)
    inter = [n for n in nets if n.kind == "inter"]
    feasible = [n for n in inter if n.driver_node[3] not in C432_INFEASIBLE_TRACKS]
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
        for j, d in tr.inject.items():
            assert tr.sb_sel.get((d, j), 0) == 0, (
                f"tile ({r},{c}): out_{d}[{j}] multi-driven (inject + SB sel)")


# =============================================================================
# 5. Synthetic 1x2 sanity test
# =============================================================================

def test_synthetic_1x2_single_net():
    """A 1x2 fabric: route clb_out[0]@(0,0) -> clb_in[0]@(0,1). Must produce
    inject{0}@(0,0), a valid SB path, cb_sel[0]@(0,1), and route_exists True."""
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
    assert 0 in rc.tiles[(0, 0)].inject, "driver tile must inject clb_out[0]"
    assert 0 in rc.tiles[(0, 1)].cb_sel, "sink tile must select clb_in[0]"
    track = rc.tiles[(0, 1)].cb_sel[0]
    assert 0 <= track < 4 * 12

    R, C, W, N_INJ, EXT_IN_v = rc.grid_dims
    assert (R, C) == (1, 2)
    grid = FabricGrid(R=R, C=C, W=W, N_INJ=N_INJ, EXT_IN=EXT_IN_v)
    apply_route_to_grid(grid, rc)
    assert grid.route_exists((0, 0, "clb_out", 0), (0, 1, "clb_in", 0)) is True
