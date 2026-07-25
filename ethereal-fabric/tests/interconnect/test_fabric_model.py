# SPDX-License-Identifier: MIT
"""pytest suite for the fabric-grid routing model (task E0-FAB3).

Validates the E0-FAB3 acceptance "4x4 grid, no combinational loop" at the
graph level (locally, no Verilator): topology self-consistency, default-config
acyclicity, an acyclic routing stays acyclic, and a deliberately cyclic ring is
detected. The structural Verilator UNOPTFLAT check is Docker-gated.

Run: make test-model  (root) — collects test_*_model.py everywhere.
"""
from __future__ import annotations

import pytest

from fabric_model import FabricGrid

W = 12


# ---- 1. topology self-consistency (C01 §3.5) --------------------------------

def test_topology_self_consistent():
    g = FabricGrid(4, 4, W)
    assert g.topology_self_consistent() is True
    # channel edges: each in-grid (tile,out_dir) neighbour contributes W edges
    assert g.n_channel_edges() > 0
    # hand count: sum over tiles of (#in-grid neighbour dirs) * W
    expected = 0
    for r in range(4):
        for c in range(4):
            ndirs = 0
            for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                if 0 <= r + dr < 4 and 0 <= c + dc < 4:
                    ndirs += 1
            expected += ndirs * W
    assert g.n_channel_edges() == expected  # = 48 tiles-neighbour-dirs * 12 = 576? (4x4: corners2*4 + edges3*8 + interior4*4 = 8+24+16=48) *12 = 576


def test_graph_nodes_well_formed():
    g = FabricGrid(2, 2, W)
    for a, b in g.graph_edges():
        for node in (a, b):
            r, c = node[0], node[1]
            assert 0 <= r < 2 and 0 <= c < 2
            # node shapes:
            #   (r, c, "in"/"out", dir, t) -> 5-tuple (channel + SB track)
            #   (r, c, "clb_out", j)        -> 4-tuple (routable-CB source)
            #   (r, c, "clb_in", i)         -> 4-tuple (CB sink)
            if len(node) == 5:
                _, _, side, d, t = node
                assert side in ("in", "out")
                assert d in ("n", "s", "e", "w")
                assert 0 <= t < W
            else:
                assert len(node) == 4
                assert node[2] in ("clb_in", "clb_out")
                assert isinstance(node[3], int) and node[3] >= 0


# ---- 2. THE acceptance: default config has NO comb loop --------------------

def test_default_no_comb_loop_4x4():
    g = FabricGrid(4, 4, W)
    assert g.has_comb_loop() is False


def test_default_no_comb_loop_various_sizes():
    for R, C in [(1, 1), (2, 2), (2, 3), (4, 4), (3, 5)]:
        g = FabricGrid(R, C, W)
        assert g.has_comb_loop() is False, f"default {R}x{C} should be acyclic"


# ---- 3. an acyclic routing stays acyclic ------------------------------------

def test_acyclic_routing():
    """Route one east-going hop on track 0 (does not close a loop)."""
    g = FabricGrid(4, 4, W)
    # (0,0): out_e[0] <- in_s[0]   (addr = DIR_E*W + t = 2*12+0 = 24; out_e sel2 = in_s)
    g.configure_sb(0, 0, 24, 2)
    assert g.has_comb_loop() is False


# ---- 4. a deliberately cyclic ring IS detected -----------------------------

def test_cyclic_ring_detected():
    """Close a 4-tile ring on track 0: (0,0)->(0,1)->(1,1)->(1,0)->(0,0)."""
    g = FabricGrid(2, 2, W)
    # addr = DIR*W + t ; DIR: 0=N,1=S,2=E,3=W ; sel: out_X selk per sb_model table
    g.configure_sb(0, 0, 2 * W + 0, 2)   # out_e <- in_s   (out_e sel2 = in_s)
    g.configure_sb(0, 1, 1 * W + 0, 3)   # out_s <- in_w   (out_s sel3 = in_w)
    g.configure_sb(1, 1, 3 * W + 0, 1)   # out_w <- in_n   (out_w sel1 = in_n)
    g.configure_sb(1, 0, 0 * W + 0, 2)   # out_n <- in_e   (out_n sel2 = in_e)
    assert g.has_comb_loop() is True


def test_ring_breaks_when_one_mux_disconnects():
    """Disconnecting any one mux of the ring must remove the cycle."""
    g = FabricGrid(2, 2, W)
    g.configure_sb(0, 0, 2 * W + 0, 2)
    g.configure_sb(0, 1, 1 * W + 0, 3)
    g.configure_sb(1, 1, 3 * W + 0, 1)
    g.configure_sb(1, 0, 0 * W + 0, 2)
    assert g.has_comb_loop() is True
    g.configure_sb(1, 0, 0 * W + 0, 0)   # break the ring (disconnect)
    assert g.has_comb_loop() is False


# ---- 5. routable-CB injection (clb_out source -> out_e) ---------------------

def test_injection_keeps_default_fabric_acyclic():
    """Injection edges are clb_out -> out_e source edges (no incoming edge on
    clb_out) -> cannot form a cycle. Default fabric stays acyclic."""
    g = FabricGrid(4, 4, W)
    # inject_en[0]=1, dir=2(E); data = 1 | (2<<1) = 5
    g.configure_sb(1, 1, 4 * W + 0, 5)
    g.set_clb_out(1, 1, 1)               # clb_out[0] = 1
    assert g.has_comb_loop() is False
    # the injection edge must appear, localized to tile (1,1)
    assert ((1, 1, "clb_out", 0), (1, 1, "out", "e", 0)) in g.graph_edges()


def test_injection_breaks_ring_via_source():
    """Routing a ring segment through the injection path (a source) breaks the
    combinational cycle: clb_out has no incoming edge, so the chain dead-ends."""
    g = FabricGrid(2, 2, W)
    g.set_clb_out(0, 0, 1)               # tile (0,0) clb_out[0] = 1
    g.configure_sb(0, 0, 4 * W + 0, 5)   # (0,0) inject east: out_e[0] <- clb_out[0]
    g.configure_sb(0, 1, 1 * W + 0, 3)   # (0,1) out_s <- in_w
    g.configure_sb(1, 1, 3 * W + 0, 1)   # (1,1) out_w <- in_n
    g.configure_sb(1, 0, 0 * W + 0, 2)   # (1,0) out_n <- in_e
    assert g.has_comb_loop() is False


def test_injection_tile_outputs_passes_clb_out():
    """tile_outputs() feeds the stored clb_out vector to the tile's SB."""
    g = FabricGrid(2, 2, W)
    g.configure_sb(0, 0, 4 * W + 2, 5)   # inject_en[2], dir=E; data = 1|(2<<1)
    g.set_clb_out(0, 0, 1 << 2)          # clb_out[2] = 1
    _on, _os, oe, _ow = g.tile_outputs(0, 0, 0, 0, 0, 0)
    assert ((oe >> 2) & 1) == 1


# ---- 6. connection_block (input-side routable CB, task E0-FAB3b) -------------
#
# Each tile now also has a ConnectionBlock (clb_in = mux of 4*W local SB output
# tracks). The CB's dependency_edges end at "clb_in" sinks -> cannot form a
# routing cycle. The default config (all sel=0 -> out_n[0]) is HW-accurate post
# zero-init (sel_r is reset-less; OCC configures before run, C03).

def test_default_acyclic_with_cb():
    """Default grid is acyclic even though CB edges exist (clb_in is a sink)."""
    for R, C in [(4, 4), (1, 2)]:
        g = FabricGrid(R, C, W)
        assert g.has_comb_loop() is False, f"default {R}x{C} with CB must be acyclic"


def test_cb_edges_present():
    """graph_edges includes CB edges: count == R*C*EXT_IN, each ends at clb_in."""
    R, C = 4, 4
    g = FabricGrid(R, C, W)
    edges = g.graph_edges()
    cb_edges = [e for e in edges if len(e[1]) == 4 and e[1][2] == "clb_in"]
    assert len(cb_edges) == R * C * g.EXT_IN
    for src, dst in cb_edges:
        assert dst[2] == "clb_in"
        # src is an "out" track node (same shape as SB/channel out nodes)
        assert src[2] == "out"
        assert src[3] in ("n", "s", "e", "w")


def test_cb_edges_localize_to_tile():
    g = FabricGrid(2, 2, W)
    edges = g.graph_edges()
    # one CB edge ending at (0,1,"clb_in",0) must exist (default sel=0 -> out_n[0])
    assert ((0, 1, "out", "n", 0), (0, 1, "clb_in", 0)) in edges
    assert ((1, 0, "out", "n", 0), (1, 0, "clb_in", 0)) in edges


def test_cb_configure_via_unit_cb():
    """FabricGrid.configure with UNIT_CB writes the CB sel of that tile."""
    g = FabricGrid(2, 2, W)
    g.configure(tile_idx=0, unit=FabricGrid.UNIT_CB, intra=3, data=5)
    r, c = g.tile_rc(0)
    assert g.cb[r][c].sel_of(3) == 5
    # the change is reflected in the graph: clb_in[3]@(0,0) now sourced by
    # track 5 = ("n", 5) (5 < W)
    assert ((0, 0, "out", "n", 5), (0, 0, "clb_in", 3)) in g.graph_edges()


# ---- 7. THE KEY TEST: end-to-end routability -------------------------------
#
# Prove a path exists from tile0.clb_out[0] -> tile1.clb_in[0]:
#   tile0 SB inject_en[0]=1            clb_out[0] -> out_e[0]
#   channel                           out_e[0]@(0,0) -> in_w[0]@(0,1)
#   tile1 SB out_n sel=3 (src=w)       in_w[0] -> out_n[0]
#   tile1 CB clb_in[0] sel=0           out_n[0] -> clb_in[0]

def test_routability_end_to_end():
    """1x2 grid: tile0.clb_out[0] -> tile1.clb_in[0] is routable."""
    g = FabricGrid(R=1, C=2, W=W, N_INJ=8, EXT_IN=18)

    # tile0 (idx 0): SB inject_en[0]=1, dir=E (data=5) -> out_e[0] <- clb_out[0]
    g.configure(tile_idx=0, unit=FabricGrid.UNIT_SB, intra=4 * W + 0, data=5)
    # tile1 (idx 1): SB route in_w[0] -> out_n[0]. out_n sources=[s,e,w], sel=3=w
    g.configure(tile_idx=1, unit=FabricGrid.UNIT_SB, intra=0, data=3)
    # tile1 (idx 1): CB clb_in[0] sel=0 -> out_n[0]
    g.configure(tile_idx=1, unit=FabricGrid.UNIT_CB, intra=0, data=0)

    assert g.route_exists((0, 0, "clb_out", 0), (0, 1, "clb_in", 0)) is True

    # sanity: the routing stays acyclic (it dead-ends at the clb_in sink)
    assert g.has_comb_loop() is False


def test_routability_negative_control():
    """With tile0 inject DISABLED, the route must not exist."""
    g = FabricGrid(R=1, C=2, W=W, N_INJ=8, EXT_IN=18)
    # tile1 routing is the same, but tile0 inject_en[0] stays 0 (default)
    g.configure(tile_idx=1, unit=FabricGrid.UNIT_SB, intra=0, data=3)
    g.configure(tile_idx=1, unit=FabricGrid.UNIT_CB, intra=0, data=0)
    assert g.route_exists((0, 0, "clb_out", 0), (0, 1, "clb_in", 0)) is False


def test_routability_route_exists_trivial_self():
    """A node is trivially reachable from itself (zero-length path)."""
    g = FabricGrid(2, 2, W)
    # any node present in the graph reaches itself
    assert g.route_exists((0, 0, "clb_in", 0), (0, 0, "clb_in", 0)) is True


def test_routability_no_path_to_isolated_node():
    """A clb_out source with no injection has no outgoing edge -> no path."""
    g = FabricGrid(1, 2, W)
    # default config: clb_out[0]@(0,0) has no edge (inject disabled)
    assert g.route_exists((0, 0, "clb_out", 0), (0, 1, "clb_in", 0)) is False


# ---- 8. bidirectional inject routability (west/south/north) -----------------
#
# Bidirectional inject (Option B): clb_out[j] can exit in ANY of the 4 dirs.
# Each test places the driver so its inject direction points at the sink.

@pytest.mark.parametrize(
    "inject_dir, R, C, drv_idx, sink_idx, sink_sb_addr, sink_sb_sel, sink_cb_sel",
    [
        # east  : drv west of sink;  channel out_e -> in_w;  sink out_n<-in_w sel3
        ("e", 1, 2, 0, 1, 0 * W + 0, 3, 0),
        # west  : drv east of sink;  channel out_w -> in_e;  sink out_n<-in_e sel2
        ("w", 1, 2, 1, 0, 0 * W + 0, 2, 0),
        # south : drv north of sink; channel out_s -> in_n;  sink out_e<-in_n sel1
        ("s", 2, 1, 0, 1, 2 * W + 0, 1, 2 * W),
        # north : drv south of sink; channel out_n -> in_s;  sink out_n<-in_s sel1
        ("n", 2, 1, 1, 0, 0 * W + 0, 1, 0),
    ],
)
def test_routability_inject_all_directions(
    inject_dir, R, C, drv_idx, sink_idx, sink_sb_addr, sink_sb_sel, sink_cb_sel):
    """clb_out[0]@drv injects toward inject_dir -> reaches clb_in[0]@sink."""
    g = FabricGrid(R=R, C=C, W=W, N_INJ=8, EXT_IN=18)
    dir_idx = {"n": 0, "s": 1, "e": 2, "w": 3}[inject_dir]
    inject_data = 1 | (dir_idx << 1)               # en=1, dir
    g.configure(tile_idx=drv_idx, unit=FabricGrid.UNIT_SB,
                intra=4 * W + 0, data=inject_data)
    g.configure(tile_idx=sink_idx, unit=FabricGrid.UNIT_SB,
                intra=sink_sb_addr, data=sink_sb_sel)
    g.configure(tile_idx=sink_idx, unit=FabricGrid.UNIT_CB,
                intra=0, data=sink_cb_sel)
    drv_rc = g.tile_rc(drv_idx)
    sink_rc = g.tile_rc(sink_idx)
    assert g.route_exists(
        (drv_rc[0], drv_rc[1], "clb_out", 0),
        (sink_rc[0], sink_rc[1], "clb_in", 0)) is True
    assert g.has_comb_loop() is False
