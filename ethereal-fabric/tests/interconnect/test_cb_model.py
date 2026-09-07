# SPDX-License-Identifier: MIT
"""pytest suite for the connection_block golden reference model (interconnect
v2c, frozen spec interconnect-config-v0.md section 7.1; task E2-FAB5).

Validates the v2c input-side CB locally (no Verilator/Docker). Core acceptance:
the stratified subset decode ``clb_in[i] = pool[(i mod CB_DIV) + CB_DIV*k_i]``
(Fc=0.5 at CB_DIV=2: each input reads the 24 tracks with t mod 2 == i mod 2,
balanced 9 inputs per track), the 5-bit subset-index config write, reserved
k >= 24 rejection, the blank default (k=0 -> out_n[i mod 2], NOT a disconnect),
and ``dependency_edges`` emitting one parity-pruned ``out -> clb_in`` edge per
clb_in (clb_in is a sink -> acyclic).

Run: ``make test-model`` (root) or
``pytest ethereal-fabric/tests/interconnect/test_cb_model.py -v``
"""
from __future__ import annotations

import pytest
from cb_model import DIRS, ConnectionBlock

W = 12
N_CB = 18


# ---- 1. parameter derivation (v2c section 7.1) -------------------------------

def test_params_default():
    cb = ConnectionBlock()
    assert cb.W == 12
    assert cb.N_CB == 18
    assert cb.CB_DIV == 2
    assert cb.POOL == 4 * W                       # 48
    assert cb.NSUB == 24                          # 4*W/CB_DIV tracks per input
    assert cb.TW == 5                             # $clog2(24) = 5 (v2c: was 6)
    assert cb.AW == 5                             # $clog2(18) = 5


def test_params_div1_is_v11_bit_identical():
    # DIV=1 -> full 48-track fan-in, 6-bit absolute track select (v1.1)
    cb = ConnectionBlock(CB_DIV=1)
    assert cb.NSUB == 48
    assert cb.TW == 6
    cb.configure(5, 2 * W + 3)                    # absolute track 27
    assert cb.pool_index(5, 27) == 27


def test_params_custom():
    cb = ConnectionBlock(W=8, N_CB=10, CB_DIV=2)
    assert cb.POOL == 32
    assert cb.NSUB == 16
    assert cb.TW == 4                             # $clog2(16) = 4
    assert cb.AW == 4                             # $clog2(10) = 4


def test_params_reject_invalid():
    with pytest.raises(ValueError):
        ConnectionBlock(W=0)
    with pytest.raises(ValueError):
        ConnectionBlock(N_CB=0)
    with pytest.raises(ValueError):
        ConnectionBlock(CB_DIV=0)
    with pytest.raises(ValueError):
        ConnectionBlock(W=12, CB_DIV=5)           # must divide 4*W


# ---- 2. pool mapping: track_index forward + inverse (unchanged layout) -----

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


def test_track_index_static_helper():
    assert ConnectionBlock.track_index("n", 3, W) == 3
    assert ConnectionBlock.track_index("s", 3, W) == W + 3
    assert ConnectionBlock.track_index("e", 3, W) == 2 * W + 3
    assert ConnectionBlock.track_index("w", 3, W) == 3 * W + 3


def test_track_index_bad_dir():
    with pytest.raises(ValueError):
        ConnectionBlock.track_index("x", 0, W)


# ---- 3. v2c subset-index <-> absolute track conversion (section 7.1) --------

def test_pool_index_formula():
    cb = ConnectionBlock()
    # clb_in[i] k -> pool[(i mod 2) + 2*k]
    assert cb.pool_index(0, 0) == 0
    assert cb.pool_index(1, 0) == 1
    assert cb.pool_index(0, 23) == 46
    assert cb.pool_index(1, 23) == 47
    assert cb.pool_index(5, 7) == 1 + 14 == 15


def test_subset_index_translation():
    # v1.1 absolute track p is representable for input i iff p mod 2 == i mod 2;
    # then k = floor(p/2) (spec section 7.1 translation rule).
    cb = ConnectionBlock()
    for i in range(N_CB):
        for p in range(4 * W):
            if p % 2 == i % 2:
                assert cb.subset_index(i, p) == p // 2
                assert cb.pool_index(i, p // 2) == p
                assert cb.reachable(i, p) is True
            else:
                assert cb.reachable(i, p) is False
                with pytest.raises(ValueError):
                    cb.subset_index(i, p)


def test_subset_fc_balanced():
    # every track readable by exactly N_CB/2 = 9 of the 18 inputs (balanced)
    cb = ConnectionBlock()
    for p in range(4 * W):
        assert sum(1 for i in range(N_CB) if cb.reachable(i, p)) == N_CB // 2
    # every input sees exactly 24 tracks = Fc 0.5 of the 48-track pool
    for i in range(N_CB):
        assert sum(1 for p in range(4 * W) if cb.reachable(i, p)) == 24


# ---- 4. configure: write sel + masking + reserved rejection -----------------

def test_configure_writes_sel():
    cb = ConnectionBlock()
    cb.configure(5, 13)                           # clb_in[5] k=13 -> pool[27]
    assert cb.sel_of(5) == 13
    assert cb.sel_of(0) == 0
    assert cb.sel_of(17) == 0


def test_configure_data_masked_to_tw_bits():
    cb = ConnectionBlock()
    # data beyond TW bits is masked off (TW=5 -> mask 0x1F)
    cb.configure(0, (1 << cb.TW) | 0b101)         # top bit dropped -> 5
    assert cb.sel_of(0) == 5


def test_configure_reserved_k_rejected():
    # k = 24..31 (5-bit encodable) index pool[>=48] -> MUST NOT be programmed
    cb = ConnectionBlock()
    for k in range(24, 32):
        with pytest.raises(ValueError, match="reserved"):
            cb.configure(3, k)
    assert cb.sel_of(3) == 0                      # unchanged
    cb.configure(3, 23)                           # max legal k
    assert cb.sel_of(3) == 23


def test_configure_addr_masked_to_aw_bits():
    cb = ConnectionBlock()
    cb.configure(1 << cb.AW, 7)                   # addr 32 -> clb_in[0]
    assert cb.sel_of(0) == 7
    assert cb.sel_of(1) == 0


def test_configure_ignores_oob_addr():
    cb = ConnectionBlock(W=12, N_CB=18)
    assert cb.AW == 5
    cb.configure(20, 9)                           # 20 >= N_CB(18) -> ignored
    assert all(cb.sel_of(i) == 0 for i in range(cb.N_CB))


def test_configure_last_write_wins():
    cb = ConnectionBlock()
    cb.configure(2, 1)
    cb.configure(2, 20)
    assert cb.sel_of(2) == 20


def test_configure_returns_self():
    cb = ConnectionBlock()
    assert cb.configure(0, 0) is cb


# ---- 5. reset-less default: all k = 0 -> reads out_n[i mod 2] (v2c section 7.7)

def test_default_sel_all_zero():
    cb = ConnectionBlock()
    assert cb.sel == [0] * N_CB


def test_default_clb_in_reads_out_n_parity_track():
    # v2c blank semantics: k=0 -> clb_in[i] reads out_n[i mod 2] (a real track,
    # not a disconnect; was out_n[0] for every input in v1.1).
    cb = ConnectionBlock()
    ci = cb.clb_in(0b10, 0, 0, 0)                 # drive only out_n[1]
    assert ci == [i % 2 for i in range(N_CB)]
    ci = cb.clb_in(0b01, 0, 0, 0)                 # drive only out_n[0]
    assert ci == [1 - (i % 2) for i in range(N_CB)]
    assert cb.clb_in(0, 0, 0, 0) == [0] * N_CB


# ---- 6. clb_in evaluation: bit-for-bit subset mux correctness ---------------

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_clb_in_reads_selected_track(d, t):
    """For each (dir, t) and a parity-matching input: k selects out_d[t]."""
    cb = ConnectionBlock()
    p = cb.track_index_of(d, t)
    i = p % 2                                     # a clb_in that can read track p
    cb.configure(i, cb.subset_index(i, p))
    ins = {"n": 0, "s": 0, "e": 0, "w": 0}
    ins[d] = 1 << t
    ci = cb.clb_in(ins["n"], ins["s"], ins["e"], ins["w"])
    assert ci[i] == 1
    # isolation: the opposite-parity input (default k=0 -> out_n[(i+1)%2])
    # never picks up out_d[t] unless that happens to be its default track
    j = i + 1 if i + 1 < N_CB else i - 1
    expected_default = (ins["n"] >> (j % 2)) & 1
    assert ci[j] == expected_default


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_clb_in_negative_unselected_track(d, t):
    """Drive every OTHER-direction bit t=1; the selected clb_in stays 0."""
    cb = ConnectionBlock()
    p = cb.track_index_of(d, t)
    i = p % 2
    cb.configure(i, cb.subset_index(i, p))
    ins = {"n": 0, "s": 0, "e": 0, "w": 0}
    for dd in DIRS:
        if dd != d:
            ins[dd] = 1 << t
    ci = cb.clb_in(ins["n"], ins["s"], ins["e"], ins["w"])
    assert ci[i] == 0


def test_clb_in_multiple_independent_muxes():
    cb = ConnectionBlock()
    # clb_in[0] (even) -> out_n[0] (k=0); clb_in[1] (odd) -> out_e[5] (k=14);
    # clb_in[2] (even) -> out_w[10] (k=23); clb_in[3] (odd) -> out_s[7] (k=9)
    cb.configure(0, cb.subset_index(0, cb.track_index_of("n", 0)))
    cb.configure(1, cb.subset_index(1, cb.track_index_of("e", 5)))
    cb.configure(2, cb.subset_index(2, cb.track_index_of("w", 10)))
    cb.configure(3, cb.subset_index(3, cb.track_index_of("s", 7)))
    ci = cb.clb_in(1 << 0, 1 << 7, 1 << 5, 1 << 10)
    assert ci[0] == 1 and ci[1] == 1 and ci[2] == 1 and ci[3] == 1
    # remaining: even inputs default to out_n[0]=1, odd to out_n[1]=0
    for i in range(4, N_CB):
        assert ci[i] == (1 if i % 2 == 0 else 0)


def test_clb_in_accepts_bit_lists():
    cb = ConnectionBlock()
    cb.configure(0, cb.subset_index(0, cb.track_index_of("e", 4)))
    out_e_list = [0] * W
    out_e_list[4] = 1
    ci = cb.clb_in(0, 0, out_e_list, 0)
    assert ci[0] == 1


def test_clb_in_returns_n_cb_bits():
    cb = ConnectionBlock()
    ci = cb.clb_in(0, 0, 0, 0)
    assert isinstance(ci, list)
    assert len(ci) == N_CB


def test_clb_in_all_four_dirs_via_one_tile():
    # configure 4 same-parity clb_ins to the 4 different directions
    cb = ConnectionBlock()
    cb.configure(0, cb.subset_index(0, cb.track_index_of("n", 2)))
    cb.configure(2, cb.subset_index(2, cb.track_index_of("s", 4)))
    cb.configure(4, cb.subset_index(4, cb.track_index_of("e", 6)))
    cb.configure(6, cb.subset_index(6, cb.track_index_of("w", 8)))
    ci = cb.clb_in(1 << 2, 1 << 4, 1 << 6, 1 << 8)
    assert ci[0] == 1 and ci[2] == 1 and ci[4] == 1 and ci[6] == 1


# ---- 7. dependency_edges (parity-pruned per v2c) -----------------------------

def test_edges_default_count_is_n_cb():
    # default k=0 -> one edge per clb_in (out_n[i mod 2] -> clb_in[i])
    cb = ConnectionBlock()
    edges = cb.dependency_edges()
    assert len(edges) == N_CB
    for i in range(N_CB):
        assert (("out", "n", i % 2), ("clb_in", i)) in edges


def test_edges_all_dst_are_clb_in():
    cb = ConnectionBlock()
    for i in range(N_CB):
        cb.configure(i, (i * 3) % cb.NSUB)        # arbitrary legal k per clb_in
    edges = cb.dependency_edges()
    for src, dst in edges:
        assert dst[0] == "clb_in"
        assert isinstance(dst[1], int) and 0 <= dst[1] < N_CB


def test_edges_all_src_are_parity_reachable_out_tracks():
    cb = ConnectionBlock()
    for i in range(N_CB):
        cb.configure(i, (i * 5) % cb.NSUB)
    edges = cb.dependency_edges()
    for src, dst in edges:
        assert src[0] == "out"
        assert src[1] in DIRS
        assert isinstance(src[2], int) and 0 <= src[2] < W
        # v2c parity pruning: the source track index is in the clb_in's subset
        p = cb.track_index_of(src[1], src[2])
        assert p % 2 == dst[1] % 2


def test_edges_reflect_sel_change():
    cb = ConnectionBlock()
    cb.configure(4, cb.subset_index(4, cb.track_index_of("w", 10)))
    edges = cb.dependency_edges()
    assert (("out", "w", 10), ("clb_in", 4)) in edges
    assert (("out", "n", 0), ("clb_in", 0)) in edges     # default k=0, i even
    assert (("out", "n", 1), ("clb_in", 1)) in edges     # default k=0, i odd
    assert len(edges) == N_CB


def test_edges_count_constant_n_cb():
    # no matter the config, exactly N_CB edges (one sink edge per clb_in)
    cb = ConnectionBlock()
    for i in range(N_CB):
        cb.configure(i, (i * 7) % cb.NSUB)
    assert len(cb.dependency_edges()) == N_CB
