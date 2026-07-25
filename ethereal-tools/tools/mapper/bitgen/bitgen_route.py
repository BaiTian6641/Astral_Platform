# SPDX-License-Identifier: MIT
"""bitgen_route — PathFinder router on the REAL fabric topology
(task E0-MAP3 increment 4a, ADR-012 refinement Option B).

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2
          (bitgen two-level design — this module is the ROUTING step between
          the LEVEL-1 config DB and the LEVEL-2 frame packer: it produces the
          SB-mux + inject + cb_sel configuration that bitgen_pack leaves
          blank in increment 3).

==============================================================================
DECISION CONTEXT (ADR-012 refinement, maintainer-chosen — do not re-litigate)
==============================================================================
Option B: VPR performs pack/place; WE route on the actual hand-built
``switch_box`` / ``connection_block`` graph (the ``FabricGrid`` from
:mod:`fabric_model`), so every route is *guaranteed realizable* on the real
fabric. VPR's abstract ``rr_graph`` (subset SB + fc-style CB) is NOT used for
routing — it does not match the hand-built fabric and translating it risks
mistranslation. Only the *placed clusters* (the LEVEL-1 bitgen DB's
``cluster_inputs`` / ``cluster_outputs`` net maps) feed net extraction here.

==============================================================================
ROUTING MODEL (faithful to the real fabric — see fabric_model / sb_model)
==============================================================================
Node tuples (identical to ``fabric_model.graph_edges`` localization):
  ``(r, c, "out", dir, t)`` / ``(r, c, "in", dir, t)``   dir∈{n,s,e,w}, t∈0..W-1
  ``(r, c, "clb_out", j)``                                j∈0..N_INJ-1 (=0..7)
  ``(r, c, "clb_in", i)``                                 i∈0..EXT_IN-1 (=0..17)

Possibility-graph edges (every available mux option is an open edge — the
PathFinder picks ONE per contended wire):
  * fixed channel:   ``(r,c,"out",D,t) -> (nb,"in",D',t)``            (CHAN_MAP)
  * SB mux:          ``(r,c,"in",src,t) -> (r,c,"out",dst,t)``  src≠dst (3 options)
  * inject (CB out): ``(r,c,"clb_out",j) -> (r,c,"out",D,j)``  D∈{n,s,e,w}, j<N_INJ
  * CB (CB in):      ``(r,c,"out",D,t) -> (r,c,"clb_in",i)``    all D,t,i

CRITICAL structural fact (from the disjoint SB + bidirectional inject model):
a net driven by ``clb_out[j]`` is **locked to track ``t = j``** for its entire
route. Bidirectional inject lets the signal exit in ANY of the 4 directions
(out_D[j], D chosen by the router per net); the disjoint SB preserves the
track index (``out_D[t]`` ← ``in_?[t]``, same ``t``); there is no track-changing
mux. The signal may travel east/north/south/west but always on track j. The CB
at the sink reads ``out_?[j]`` into ``clb_in[i]``. Consequence: two inter nets
sharing the same driver index ``j`` whose paths must cross on a track-j wire
are *structurally* unresolvable on this v1 fabric — PathFinder will not
converge and the net is reported UNROUTABLE (an honest Phase-0 finding, not a
bug; a track-flexible fabric or placement-aware packing would be the fix).

==============================================================================
PATHFINDER (negotiated congestion — McMurchie/Luebben classic)
==============================================================================
The contended resource is the wire NODE (an ``out_D[t]`` or ``clb_in[i]``; an
``in_D[t]`` channel wire is also a resource but is uniquely sourced so it is
only ever contended when two nets share a physical wire). Cost is driven by the
target node's historical congestion and current occupancy:

    edge_cost(a -> b) = 1 + hist[b] * present_occ[b]

``present_occ[node]`` = #nets whose current routing occupies ``node``;
``hist[node]`` = accumulated historical-congestion penalty. After each iteration
every node with ``present_occ > 1`` is over-used → ``hist[node] += 1``; all nets
are ripped up and re-routed with the updated ``hist``. Convergence == an
iteration with zero over-used nodes. This node-keyed model is the textbook
PathFinder resource formulation; the brief's ``hist[edge]*present_occ[edge]`` is
realized through the edge's target-node resource (the only resources that can
be multi-driven are nodes). Dijkstra is fully deterministic (ties broken by
insertion order via a monotonic counter).
"""
from __future__ import annotations

import heapq
import os
import random
import sys
from collections import defaultdict
from dataclasses import dataclass, field

# -- sys.path bootstrap: bitgen_db/bitgen_pack live in THIS dir; frame_map is --
# -- two dirs up (ethereal-tools/tools/); the fabric golden models live in    --
# -- ethereal-fabric/tests/interconnect/. Adding them makes `from <mod>` work --
# -- regardless of CWD when run via pytest / make test-model.                 --
_HERE = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(os.path.dirname(_HERE))     # ethereal-tools/tools/
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)
_INTERCONNECT = os.path.normpath(os.path.join(
    _HERE, "..", "..", "..", "..", "ethereal-fabric", "tests", "interconnect"))
if _INTERCONNECT not in sys.path:
    sys.path.insert(0, _INTERCONNECT)

from bitgen_db import EXT_IN, N, FabricConfigDB  # noqa: E402
from bitgen_pack import db_grid_bounds  # noqa: E402
from cb_model import ConnectionBlock  # noqa: E402
from fabric_model import CHAN_MAP, FabricGrid  # noqa: E402
from sb_model import DIRS, sources  # noqa: E402

# ---- frozen fabric topology constants (mirror FabricGrid defaults / frame_map)
FABRIC_W = 12
FABRIC_N_INJ = N          # 8 — inject_en count (== clb_out count)
FABRIC_EXT_IN = EXT_IN    # 18 — clb_in count


# =============================================================================
# Data model
# =============================================================================

@dataclass
class Net:
    """A net extracted from the LEVEL-1 DB, classified for routing.

    ``driver_node`` is ``(r, c, "clb_out", j)`` (normalized to the 0-based
    fabric grid); ``None`` for a ``primary_in`` net (externally driven — left
    for incr 4b IO injection). ``sink_nodes`` are ``(r, c, "clb_in", i)``.
    ``n_drivers > 1`` flags a netlist error (multi-driver) — such a net is
    reported UNROUTABLE rather than silently picking one driver.
    """

    name: str
    driver_node: tuple | None
    sink_nodes: list[tuple]
    kind: str                       # "inter" | "primary_in" | "primary_out"
    n_drivers: int = 0


@dataclass
class TileRoute:
    """Per-tile routing config derived from the chosen PathFinder paths."""

    sb_sel: dict[tuple[str, int], int] = field(default_factory=dict)   # (dir,t)->sel
    inject: dict[int, str] = field(default_factory=dict)               # j -> dir
    cb_sel: dict[int, int] = field(default_factory=dict)               # clb_in i -> track


@dataclass
class RouteConfig:
    """The full routing solution + stats."""

    tiles: dict[tuple[int, int], TileRoute] = field(default_factory=dict)
    n_nets: int = 0                  # #inter-cluster nets (the routing input)
    n_routed: int = 0                # #inter nets successfully routed
    n_iters: int = 0                 # PathFinder iterations run
    n_overuse_final: int = 0         # over-used nodes in the final iteration
    converged: bool = False
    unrouted: list[tuple[str, str]] = field(default_factory=list)      # (name, reason)
    n_primary_in: int = 0
    n_primary_out: int = 0
    grid_dims: tuple[int, int, int, int, int] = (0, 0, 0, 0, 0)        # R,C,W,N_INJ,EXT_IN


# =============================================================================
# Helpers
# =============================================================================

def _src_to_sel(dst_dir: str, src_dir: str) -> int:
    """Inverse of ``sb_model._SOURCES``: sel (1..3) so the disjoint SB mux for
    output ``dst_dir`` picks source dir ``src_dir``."""
    return sources(dst_dir).index(src_dir) + 1


# =============================================================================
# Net extraction
# =============================================================================

def extract_nets(db: FabricConfigDB, min_x: int, min_y: int) -> list[Net]:
    """Classify every net in ``db`` by driver/sink presence.

    Normalized coords: ``col = x - min_x``, ``row = y - min_y`` (VPR (x,y) →
    0-based fabric grid). Classification:
      * **inter**        — net is both a cluster output (some tile's
                           ``cluster_outputs[j]``) AND a cluster input (some
                           tile's ``cluster_inputs[i]``). These are routed here.
      * **primary_in**   — net is a cluster input but driven by no cluster
                           output (an external primary input). Left for incr 4b.
      * **primary_out**  — net is a cluster output but feeds no cluster input
                           (an external primary output). Left for incr 4b.
    """
    drivers: dict[str, list[tuple]] = defaultdict(list)
    sinks: dict[str, list[tuple]] = defaultdict(list)
    for (x, y), tile in db.tiles.items():
        r = y - min_y
        c = x - min_x
        for j, net in tile.cluster_outputs.items():
            if net is not None:
                drivers[net].append((r, c, "clb_out", j))
        for i, net in tile.cluster_inputs.items():
            if net is not None:
                sinks[net].append((r, c, "clb_in", i))

    nets: list[Net] = []
    for name in sorted(set(drivers) | set(sinks)):     # deterministic ordering
        dlist = drivers.get(name, [])
        slist = sinks.get(name, [])
        has_d, has_s = bool(dlist), bool(slist)
        if has_d and has_s:
            kind = "inter"
        elif has_s:
            kind = "primary_in"
        elif has_d:
            kind = "primary_out"
        else:                          # unreachable: name is in drivers|sinks
            continue
        nets.append(Net(
            name=name,
            driver_node=dlist[0] if dlist else None,
            sink_nodes=list(slist),
            kind=kind,
            n_drivers=len(dlist),
        ))
    return nets


# =============================================================================
# Possibility-graph construction
# =============================================================================

def _build_possibility_graph(
    R: int, C: int, W: int, N_INJ: int, EXT_IN: int,
    sink_clb_in_nodes: set[tuple],
) -> dict[tuple, list[tuple[tuple, tuple]]]:
    """Directed graph of ALL routable resources (every mux option = an edge).

    ``sink_clb_in_nodes`` prunes CB edges to ONLY the ``clb_in`` nodes that are
    actual sinks of some inter net (a non-sink ``clb_in`` is never a routing
    target, so its CB options are dead weight). This is the only pruning done;
    SB / channel / inject edges are emitted in full (they are the routing
    fabric). Edges carry a ``meta`` tuple for later config extraction:

      ``("chan",)``             fixed channel (no config)
      ``("sb", dst_dir, t, src)``  SB mux  -> sb_sel[(dst_dir,t)] = sel(src)
      ``("inj", j, d)``         inject  -> inject{j: d}  (D in {n,s,e,w})
      ``("cb", i, dir, t)``     CB      -> cb_sel[i] = track_index(dir,t)
    """
    adj: dict[tuple, list[tuple[tuple, tuple]]] = defaultdict(list)

    def add(u: tuple, v: tuple, meta: tuple) -> None:
        adj[u].append((v, meta))

    # group sink clb_in nodes by tile for CB-edge emission
    sinks_by_tile: dict[tuple[int, int], set[int]] = defaultdict(set)
    for node in sink_clb_in_nodes:
        r, c, _kind, i = node               # (r, c, "clb_in", i)
        sinks_by_tile[(r, c)].add(i)

    for r in range(R):
        for c in range(C):
            # 1. fixed channel edges: out_D[t]@(r,c) -> in_D'[t]@(neighbor)
            for od, (dr, dc, ind) in CHAN_MAP.items():
                nr, nc = r + dr, c + dc
                if 0 <= nr < R and 0 <= nc < C:
                    for t in range(W):
                        add((r, c, "out", od, t), (nr, nc, "in", ind, t), ("chan",))
            # 2. SB mux possibility edges: in_src[t] -> out_dst[t] (src != dst)
            for dd in DIRS:
                for sd in DIRS:
                    if sd == dd:
                        continue
                    for t in range(W):
                        add((r, c, "in", sd, t), (r, c, "out", dd, t),
                            ("sb", dd, t, sd))
            # 3. inject possibility edges: clb_out[j] -> out_D[j] for ALL 4 dirs
            #    (bidirectional inject, Option B): the router picks the ONE exit
            #    direction per net (j < N_INJ). SB stays single-driver because
            #    each (dir, j) pair is a distinct track.
            for j in range(N_INJ):
                for d in DIRS:
                    add((r, c, "clb_out", j), (r, c, "out", d, j), ("inj", j, d))
            # 4. CB possibility edges: out_dir[t] -> clb_in[i] (sinks only)
            for i in sinks_by_tile.get((r, c), ()):
                for d in DIRS:
                    for t in range(W):
                        add((r, c, "out", d, t), (r, c, "clb_in", i),
                            ("cb", i, d, t))
    return adj


# =============================================================================
# PathFinder
# =============================================================================

def _dijkstra(
    adj: dict[tuple, list[tuple[tuple, tuple]]],
    src: tuple,
    hist: dict[tuple, float],
    present_occ: dict[tuple, int],
) -> tuple[dict[tuple, float], dict[tuple, tuple[tuple, tuple]]]:
    """Single-source Dijkstra over the possibility graph.

    ``edge_cost(a -> b) = 1 + hist[b] * present_occ[b]``. Returns
    ``(dist, prev)`` where ``prev[b] = (a, meta)`` for path reconstruction.
    Fully deterministic: ties break by a monotonic insertion counter (nodes are
    never compared directly).
    """
    dist: dict[tuple, float] = {src: 0.0}
    prev: dict[tuple, tuple[tuple, tuple]] = {}
    counter = 0
    pq: list[tuple[float, int, tuple]] = [(0.0, counter, src)]
    counter += 1
    while pq:
        d, _cnt, u = heapq.heappop(pq)
        if d > dist.get(u, float("inf")):
            continue
        for v, meta in adj.get(u, ()):
            occ = present_occ.get(v, 0)
            h = hist.get(v, 0.0)
            nd = d + 1.0 + h * occ
            if nd < dist.get(v, float("inf")):
                dist[v] = nd
                prev[v] = (u, meta)
                heapq.heappush(pq, (nd, counter, v))
                counter += 1
    return dist, prev


def _route_net(
    net: Net,
    adj: dict[tuple, list[tuple[tuple, tuple]]],
    hist: dict[tuple, float],
    present_occ: dict[tuple, int],
    N_INJ: int = FABRIC_N_INJ,
) -> tuple[list[tuple[tuple, tuple, tuple]], set[tuple]] | None:
    """Route one net (driver -> every sink) via a per-direction Dijkstra.

    Bidirectional inject (Option B) lets ``clb_out[j]@T`` exit on ONE of the 4
    output directions (out_D[j]) — a per-(tile,j) resource: the net picks ONE
    direction and ALL sinks must be reachable from that single exit. We run
    Dijkstra from EACH of the 4 exit nodes (out_n/s/e/w[j]@T) and pick the
    direction whose tree reaches all sinks with minimum total cost. This
    enforces single-direction inject at the routing level — the constraint the
    possibility-graph inject edges alone cannot express for multi-sink nets (a
    driver Dijkstra through 4 inject edges would let different sinks branch
    through different directions, which the hardware cannot realize).

    Returns ``(edges_used, nodes_used)`` including the chosen inject edge, or
    ``None`` if no direction reaches all sinks / driver clb_out[j] >= N_INJ.
    The inject edge meta ``("inj", j, d)`` is added manually so
    ``_populate_tiles`` records ``inject{j: d}`` exactly as before.
    """
    if net.driver_node is None:
        return None
    r, c, _, j = net.driver_node
    if not (0 <= j < N_INJ):
        return None                      # can't inject (j out of range)
    best_edges: list[tuple[tuple, tuple, tuple]] | None = None
    best_nodes: set[tuple] | None = None
    best_cost = float("inf")
    for d in DIRS:
        exit_node = (r, c, "out", d, j)
        dist, prev = _dijkstra(adj, exit_node, hist, present_occ)
        if not all(s in dist for s in net.sink_nodes):
            continue                      # this direction can't reach all sinks
        total = sum(dist[s] for s in net.sink_nodes)
        if total >= best_cost:
            continue
        # reconstruct edges for this direction (inject edge + tree edges)
        edges: list[tuple[tuple, tuple, tuple]] = [
            (net.driver_node, exit_node, ("inj", j, d))]
        nodes: set[tuple] = {net.driver_node, exit_node}
        ok = True
        for sink in net.sink_nodes:
            cur = sink
            while cur != exit_node:
                step = prev.get(cur)
                if step is None:                 # defensive: should not happen
                    ok = False
                    break
                pu, meta = step
                edges.append((pu, cur, meta))
                cur = pu
                nodes.add(cur)
            nodes.add(sink)
            if not ok:
                break
        if ok:
            best_cost = total
            best_edges = edges
            best_nodes = nodes
    if best_edges is None or best_nodes is None:
        return None
    return best_edges, best_nodes


def route(
    db: FabricConfigDB,
    max_iters: int = 30,
    W: int = FABRIC_W,
    N_INJ: int = FABRIC_N_INJ,
    EXT_IN: int = FABRIC_EXT_IN,
    seed: int = 0,
    verbose: bool = False,
) -> RouteConfig:
    """Route every inter-cluster net in ``db`` on the real fabric topology.

    Returns a :class:`RouteConfig`. Nets that cannot be routed (structural —
    e.g. driver ``clb_out[j>=N_INJ]``, multi-driver netlist error, or track-lock
    congestion that never converges) are listed in ``rc.unrouted`` with a
    reason; the routed nets' per-tile SB/inject/CB config is in ``rc.tiles``.

    PathFinder uses **seeded per-iteration net shuffling** (classic
    negotiated-congestion technique to avoid the systematic bias of a fixed net
    order). The ``seed`` makes results fully reproducible. ``verbose`` prints
    the over-use count per iteration (diagnostic for convergence analysis).
    """
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    R = max_y - min_y + 1
    C = max_x - min_x + 1
    nets = extract_nets(db, min_x, min_y)
    n_pi = sum(1 for n in nets if n.kind == "primary_in")
    n_po = sum(1 for n in nets if n.kind == "primary_out")
    inter = [n for n in nets if n.kind == "inter"]

    rc = RouteConfig(
        n_nets=len(inter), n_primary_in=n_pi, n_primary_out=n_po,
        grid_dims=(R, C, W, N_INJ, EXT_IN),
    )

    # ---- pre-flight: classify each inter net as routable / unroutable -------
    routable: list[Net] = []
    for n in inter:
        assert n.driver_node is not None            # inter nets always have one
        j = n.driver_node[3]
        if n.n_drivers > 1:
            rc.unrouted.append((n.name, f"multi-driver ({n.n_drivers} sources)"))
        elif not (0 <= j < N_INJ):
            rc.unrouted.append(
                (n.name, f"driver clb_out[{j}] >= N_INJ={N_INJ} (can't inject)"))
        else:
            routable.append(n)

    if not routable:
        return rc

    # collect sink clb_in nodes (for CB-edge pruning) + build possibility graph
    sink_clb_in_nodes: set[tuple] = set()
    for n in routable:
        sink_clb_in_nodes.update(n.sink_nodes)
    adj = _build_possibility_graph(R, C, W, N_INJ, EXT_IN, sink_clb_in_nodes)

    # ---- one more structural check: reachability (ignore cost) --------------
    # A net unreachable in the possibility graph is permanently unroutable.
    active: list[Net] = []
    for n in routable:
        dist, _prev = _dijkstra(adj, n.driver_node, {}, defaultdict(int))
        if all(s in dist for s in n.sink_nodes):
            active.append(n)
        else:
            missing = [s for s in n.sink_nodes if s not in dist]
            rc.unrouted.append((n.name, f"unreachable sinks: {missing}"))

    # ---- PathFinder negotiated-congestion loop ------------------------------
    converged, n_iters, n_overuse_final, best_net_edges = _run_pathfinder(
        active, adj, max_iters, seed, verbose, N_INJ)
    rc.converged = converged
    rc.n_iters = n_iters
    rc.n_overuse_final = n_overuse_final

    # ---- nets that never made it into a conflict-free solution --------------
    routed_names = set(best_net_edges) if converged else set()
    if not converged:
        # every active net is effectively unrouted (solution has conflicts);
        # report them so nothing is silently dropped.
        for n in active:
            if n.name not in routed_names:
                rc.unrouted.append(
                    (n.name, f"PathFinder did not converge in {max_iters} iters "
                             f"({rc.n_overuse_final} over-used nodes)"))

    rc.n_routed = len(routed_names)
    _populate_tiles(rc, best_net_edges, W)
    return rc


def _run_pathfinder(
    active: list[Net],
    adj: dict[tuple, list[tuple[tuple, tuple]]],
    max_iters: int,
    seed: int,
    verbose: bool,
    N_INJ: int = FABRIC_N_INJ,
) -> tuple[bool, int, int, dict[str, list[tuple[tuple, tuple, tuple]]]]:
    """Negotiated-congestion PathFinder over an explicit net list.

    Seeded per-iteration net shuffling breaks the systematic bias of a fixed
    net order (a classic PathFinder technique): different nets get routing
    priority each iteration, and accumulating ``hist`` forces a global
    rearrange. The fixed seed keeps results fully reproducible. Returns
    ``(converged, n_iters, n_overuse_final, best_net_edges)``. Exposed (private
    but importable) so a caller can route a SUBSET of nets (e.g. a feasibility
    probe or the routable subset of an over-constrained design) on the same
    possibility graph.
    """
    rng = random.Random(seed)
    hist: dict[tuple, float] = defaultdict(float)
    best_net_edges: dict[str, list[tuple[tuple, tuple, tuple]]] = {}
    converged = False
    n_iters = 0
    n_overuse_final = 0
    for it in range(1, max_iters + 1):
        n_iters = it
        order = list(active)
        rng.shuffle(order)                                   # deterministic shuffle
        present_occ: dict[tuple, int] = defaultdict(int)
        net_edges: dict[str, list[tuple[tuple, tuple, tuple]]] = {}
        for n in order:
            res = _route_net(n, adj, hist, present_occ, N_INJ)
            if res is None:                                   # structural (shouldn't
                continue                                      #  happen post-reachability)
            edges, nodes = res
            net_edges[n.name] = edges
            for nd in nodes:
                present_occ[nd] += 1
        over_used = {nd for nd, c in present_occ.items() if c > 1}
        if verbose:
            print(f"[pathfinder] iter {it:3d}: {len(over_used)} over-used nodes, "
                  f"{sum(present_occ[n] for n in over_used)} total over-uses")
        if not over_used:
            converged = True
            best_net_edges = net_edges
            n_overuse_final = 0
            break
        for nd in over_used:                                  # bump historical cost
            hist[nd] += 1.0
        best_net_edges = net_edges                            # keep last attempt
        n_overuse_final = len(over_used)
    return converged, n_iters, n_overuse_final, best_net_edges


def _populate_tiles(
    rc: RouteConfig,
    net_edges: dict[str, list[tuple[tuple, tuple, tuple]]],
    W: int,
) -> None:
    """Translate the chosen path edges into per-tile SB/inject/CB config."""
    for edges in net_edges.values():
        for (_u, v, meta) in edges:
            r, c = v[0], v[1]
            tr = rc.tiles.setdefault((r, c), TileRoute())
            kind = meta[0]
            if kind == "sb":
                _, dd, t, sd = meta
                tr.sb_sel[(dd, t)] = _src_to_sel(dd, sd)
            elif kind == "inj":
                _, j, d = meta
                tr.inject[j] = d
            elif kind == "cb":
                _, i, d, t = meta
                tr.cb_sel[i] = ConnectionBlock.track_index(d, t, W)
            # "chan" contributes no per-tile config


# =============================================================================
# Apply to a real FabricGrid (validation / realizability proof)
# =============================================================================

def apply_route_to_grid(grid: FabricGrid, rc: RouteConfig) -> None:
    """Configure a :class:`FabricGrid`'s SB + inject + CB per ``rc``.

    Lets ``grid.route_exists(driver, sink)`` reflect the routed solution, which
    is the Option-B realizability proof (the configured real fabric actually
    carries every net). Uses the golden SB/CB high-level helpers so the
    configured state matches the RTL bit-for-bit. Does NOT touch CLB logic or
    ``set_clb_out`` — reachability depends only on the SB/CB mux graph."""
    for (r, c), tr in rc.tiles.items():
        sb = grid.sb[r][c]
        for (dd, t), sel in tr.sb_sel.items():
            sb.route(dd, t, sel)
        for j, d in tr.inject.items():
            sb.inject(j, True, d)
        cb = grid.cb[r][c]
        for i, track in tr.cb_sel.items():
            cb.configure(i, track)
