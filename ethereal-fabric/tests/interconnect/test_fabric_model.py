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
            r, c, side, d, t = node
            assert 0 <= r < 2 and 0 <= c < 2
            assert side in ("in", "out")
            assert d in ("n", "s", "e", "w")
            assert 0 <= t < W


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
    g.configure_sb(1, 1, 4 * W + 0, 1)   # inject_en[0] on tile (1,1)
    g.set_clb_out(1, 1, 1)               # clb_out[0] = 1
    assert g.has_comb_loop() is False
    # the injection edge must appear, localized to tile (1,1)
    assert ((1, 1, "clb_out", 0), (1, 1, "out", "e", 0)) in g.graph_edges()


def test_injection_breaks_ring_via_source():
    """Routing a ring segment through the injection path (a source) breaks the
    combinational cycle: clb_out has no incoming edge, so the chain dead-ends."""
    g = FabricGrid(2, 2, W)
    g.set_clb_out(0, 0, 1)               # tile (0,0) clb_out[0] = 1
    g.configure_sb(0, 0, 4 * W + 0, 1)   # (0,0) out_e[0] <- clb_out[0] (inject)
    g.configure_sb(0, 1, 1 * W + 0, 3)   # (0,1) out_s <- in_w
    g.configure_sb(1, 1, 3 * W + 0, 1)   # (1,1) out_w <- in_n
    g.configure_sb(1, 0, 0 * W + 0, 2)   # (1,0) out_n <- in_e
    assert g.has_comb_loop() is False


def test_injection_tile_outputs_passes_clb_out():
    """tile_outputs() feeds the stored clb_out vector to the tile's SB."""
    g = FabricGrid(2, 2, W)
    g.configure_sb(0, 0, 4 * W + 2, 1)   # inject_en[2]
    g.set_clb_out(0, 0, 1 << 2)          # clb_out[2] = 1
    _on, _os, oe, _ow = g.tile_outputs(0, 0, 0, 0, 0, 0)
    assert ((oe >> 2) & 1) == 1
