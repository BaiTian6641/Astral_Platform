# SPDX-License-Identifier: MIT
"""pytest suite for the connection_block golden reference model (task E0-FAB3b).

Validates the input-side routable CB spec locally (no Verilator/Docker).
Core acceptance: the pool mapping ``{out_w, out_e, out_s, out_n}`` maps track
indices to (direction, t) bit-for-bit, every clb_in mux reads exactly the
selected track, reset-less ``sel`` defaults to 0 (reads out_n[0], NOT a
disconnect), and ``dependency_edges`` emits one ``out -> clb_in`` edge per
clb_in (clb_in is a sink -> acyclic).

Run: ``make test-model`` (root) or
``pytest ethereal-fabric/tests/interconnect/test_cb_model.py -v``
"""
from __future__ import annotations

import pytest
from cb_model import DIRS, ConnectionBlock

W = 12
N_CB = 18


# ---- 1. parameter derivation -------------------------------------------------

def test_params_default():
    cb = ConnectionBlock()
    assert cb.W == 12
    assert cb.N_CB == 18
    assert cb.POOL == 4 * W                       # 48
    assert cb.TW == 6                             # $clog2(48) = 6
    assert cb.AW == 5                             # $clog2(18) = 5


def test_params_custom():
    cb = ConnectionBlock(W=8, N_CB=10)
    assert cb.POOL == 32
    assert cb.TW == 5                             # $clog2(32) = 5
    assert cb.AW == 4                             # $clog2(10) = 4


def test_params_reject_invalid():
    with pytest.raises(ValueError):
        ConnectionBlock(W=0)
    with pytest.raises(ValueError):
        ConnectionBlock(N_CB=0)


# ---- 2. pool mapping: track_index forward + inverse -------------------------

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_track_index_forward(d, t):
    """track_index(dir, t) -> the pool bit for that (dir, t)."""
    cb = ConnectionBlock()
    k = cb.track_index_of(d, t)
    if d == "n":
        assert k == t
    elif d == "s":
        assert k == W + t
    elif d == "e":
        assert k == 2 * W + t
    else:  # w
        assert k == 3 * W + t
    assert 0 <= k < cb.POOL


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_dir_t_inverse_of_track_index(d, t):
    """dir_t_of(track_index(d, t)) == (d, t)."""
    cb = ConnectionBlock()
    k = cb.track_index_of(d, t)
    assert cb.dir_t_of(k) == (d, t)


@pytest.mark.parametrize("k", range(4 * W))
def test_track_index_inverse_of_dir_t(k):
    """track_index(*dir_t_of(k)) == k."""
    cb = ConnectionBlock()
    d, t = cb.dir_t_of(k)
    assert cb.track_index_of(d, t) == k


def test_dir_t_boundaries():
    cb = ConnectionBlock()
    assert cb.dir_t_of(0) == ("n", 0)
    assert cb.dir_t_of(W - 1) == ("n", W - 1)
    assert cb.dir_t_of(W) == ("s", 0)
    assert cb.dir_t_of(2 * W - 1) == ("s", W - 1)
    assert cb.dir_t_of(2 * W) == ("e", 0)
    assert cb.dir_t_of(3 * W - 1) == ("e", W - 1)
    assert cb.dir_t_of(3 * W) == ("w", 0)
    assert cb.dir_t_of(4 * W - 1) == ("w", W - 1)


def test_track_index_static_helper():
    # static helper usable without an instance
    assert ConnectionBlock.track_index("n", 3, W) == 3
    assert ConnectionBlock.track_index("s", 3, W) == W + 3
    assert ConnectionBlock.track_index("e", 3, W) == 2 * W + 3
    assert ConnectionBlock.track_index("w", 3, W) == 3 * W + 3


def test_track_index_bad_dir():
    with pytest.raises(ValueError):
        ConnectionBlock.track_index("x", 0, W)


# ---- 3. configure: write sel + masking --------------------------------------

def test_configure_writes_sel():
    cb = ConnectionBlock()
    cb.configure(5, 2 * W + 3)            # clb_in[5] -> out_e[3]
    assert cb.sel_of(5) == 2 * W + 3
    # other clb_ins untouched (default 0)
    assert cb.sel_of(0) == 0
    assert cb.sel_of(17) == 0


def test_configure_data_masked_to_tw_bits():
    cb = ConnectionBlock()
    # data beyond TW bits is masked off (TW=6 -> mask 0x3F)
    cb.configure(0, (1 << cb.TW) | 0b101)      # top bit dropped -> 0b101 = 5
    assert cb.sel_of(0) == 5


def test_configure_addr_masked_to_aw_bits():
    cb = ConnectionBlock()
    # addr beyond AW bits masked (AW=5 -> mask 0x1F); 32 == 0b100000 -> 0
    cb.configure(1 << cb.AW, 7)                 # addr 32 -> clb_in[0]
    assert cb.sel_of(0) == 7
    assert cb.sel_of(1) == 0


def test_configure_ignores_oob_addr():
    # addr masked to AW bits but still >= N_CB -> ignored (RTL array bounded)
    cb = ConnectionBlock(W=12, N_CB=18)
    assert cb.AW == 5                           # can encode 0..31
    cb.configure(20, 9)                         # 20 >= N_CB(18) -> ignored
    assert all(cb.sel_of(i) == 0 for i in range(cb.N_CB))


def test_configure_last_write_wins():
    cb = ConnectionBlock()
    cb.configure(2, 1)
    cb.configure(2, 2 * W + 4)
    assert cb.sel_of(2) == 2 * W + 4


def test_configure_returns_self():
    cb = ConnectionBlock()
    assert cb.configure(0, 0) is cb


# ---- 4. reset-less default: all sel = 0 -> reads out_n[0] -------------------

def test_default_sel_all_zero():
    cb = ConnectionBlock()
    assert cb.sel == [0] * N_CB


def test_default_clb_in_reads_out_n_zero():
    # default sel=0 reads out_n[0]; drive only out_n[0] -> every clb_in = 1
    cb = ConnectionBlock()
    ins_n = 1 << 0
    ci = cb.clb_in(ins_n, 0, 0, 0)
    assert ci == [1] * N_CB
    # with out_n[0]=0 -> every clb_in = 0
    assert cb.clb_in(0, 0, 0, 0) == [0] * N_CB


# ---- 5. clb_in evaluation: bit-for-bit mux correctness ----------------------

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_clb_in_reads_selected_track(d, t):
    """For each (dir, t): sel=track_index(d,t) -> clb_in reads out_d[t]."""
    cb = ConnectionBlock()
    k = cb.track_index_of(d, t)
    cb.configure(0, k)
    ins = {"n": 0, "s": 0, "e": 0, "w": 0}
    ins[d] = 1 << t
    ci = cb.clb_in(ins["n"], ins["s"], ins["e"], ins["w"])
    assert ci[0] == 1
    # isolation: clb_in[1] (default sel=0 -> out_n[0]) reads EXACTLY out_n[0]
    # and nothing else. out_n[0] == (ins_n >> 0) & 1; so ci[1] must equal that
    # bit regardless of what other track/dir is driven (it never picks up out_d[t]
    # for d != "n" or t != 0).
    expected_default = (ins["n"] >> 0) & 1
    assert ci[1] == expected_default
    assert ci[2] == expected_default


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_clb_in_negative_unselected_track(d, t):
    """Drive every OTHER track/direction bit t=1; clb_in[0] (sel=d,t) stays 0."""
    cb = ConnectionBlock()
    k = cb.track_index_of(d, t)
    cb.configure(0, k)
    ins = {"n": 0, "s": 0, "e": 0, "w": 0}
    for dd in DIRS:
        if dd != d:
            ins[dd] = 1 << t
    ci = cb.clb_in(ins["n"], ins["s"], ins["e"], ins["w"])
    assert ci[0] == 0


def test_clb_in_multiple_independent_muxes():
    cb = ConnectionBlock()
    cb.configure(0, cb.track_index_of("n", 0))    # clb_in[0] -> out_n[0]
    cb.configure(1, cb.track_index_of("e", 5))    # clb_in[1] -> out_e[5]
    cb.configure(2, cb.track_index_of("w", 11))   # clb_in[2] -> out_w[11]
    cb.configure(3, cb.track_index_of("s", 7))    # clb_in[3] -> out_s[7]
    ins_n = 1 << 0
    ins_s = 1 << 7
    ins_e = 1 << 5
    ins_w = 1 << 11
    ci = cb.clb_in(ins_n, ins_s, ins_e, ins_w)
    assert ci[0] == 1
    assert ci[1] == 1
    assert ci[2] == 1
    assert ci[3] == 1
    # remaining clb_ins (sel=0 -> out_n[0]) all read 1 as well
    assert ci[4:] == [1] * (N_CB - 4)


def test_clb_in_accepts_bit_lists():
    cb = ConnectionBlock()
    cb.configure(0, cb.track_index_of("e", 3))
    # pass out_e as a bit-list (index 3 = track 3)
    out_e_list = [0] * W
    out_e_list[3] = 1
    ci = cb.clb_in(0, 0, out_e_list, 0)
    assert ci[0] == 1


def test_clb_in_returns_n_cb_bits():
    cb = ConnectionBlock()
    ci = cb.clb_in(0, 0, 0, 0)
    assert isinstance(ci, list)
    assert len(ci) == N_CB


def test_clb_in_all_four_dirs_via_one_tile():
    # configure 4 distinct clb_ins to the 4 different directions
    cb = ConnectionBlock()
    cb.configure(0, cb.track_index_of("n", 1))
    cb.configure(1, cb.track_index_of("s", 2))
    cb.configure(2, cb.track_index_of("e", 3))
    cb.configure(3, cb.track_index_of("w", 4))
    ci = cb.clb_in(1 << 1, 1 << 2, 1 << 3, 1 << 4)
    assert ci[0] == 1 and ci[1] == 1 and ci[2] == 1 and ci[3] == 1


# ---- 6. dependency_edges ----------------------------------------------------

def test_edges_default_count_is_n_cb():
    # default sel=0 -> one edge per clb_in (out_n[0] -> clb_in[i])
    cb = ConnectionBlock()
    edges = cb.dependency_edges()
    assert len(edges) == N_CB
    for i in range(N_CB):
        assert (("out", "n", 0), ("clb_in", i)) in edges


def test_edges_all_dst_are_clb_in():
    cb = ConnectionBlock()
    for i in range(N_CB):
        cb.configure(i, (i * 3) % cb.POOL)     # arbitrary track per clb_in
    edges = cb.dependency_edges()
    for src, dst in edges:
        assert dst[0] == "clb_in"
        assert isinstance(dst[1], int) and 0 <= dst[1] < N_CB


def test_edges_all_src_are_out():
    cb = ConnectionBlock()
    for i in range(N_CB):
        cb.configure(i, (i * 5) % cb.POOL)
    edges = cb.dependency_edges()
    for src, dst in edges:
        assert src[0] == "out"
        assert src[1] in DIRS
        assert isinstance(src[2], int) and 0 <= src[2] < W


def test_edges_reflect_sel_change():
    cb = ConnectionBlock()
    cb.configure(4, cb.track_index_of("w", 9))    # clb_in[4] -> out_w[9]
    edges = cb.dependency_edges()
    assert (("out", "w", 9), ("clb_in", 4)) in edges
    # default edges for the other clb_ins still point at out_n[0]
    assert (("out", "n", 0), ("clb_in", 0)) in edges
    assert len(edges) == N_CB


def test_edges_count_constant_n_cb():
    # no matter the config, exactly N_CB edges (one sink edge per clb_in)
    cb = ConnectionBlock()
    cb.configure(0, 0)
    cb.configure(1, W)
    cb.configure(2, 2 * W)
    cb.configure(3, 3 * W)
    assert len(cb.dependency_edges()) == N_CB


def test_edges_clb_in_is_sink():
    # no edge has a clb_in as its SOURCE -> clb_in cannot be in a cycle
    cb = ConnectionBlock()
    for i in range(0, N_CB, 2):
        cb.configure(i, (i + 1) % cb.POOL)
    edges = cb.dependency_edges()
    assert all(src[0] != "clb_in" for src, _ in edges)
