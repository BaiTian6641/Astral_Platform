# SPDX-License-Identifier: MIT
"""pytest suite for the switch_box golden reference model (task E0-FAB3).

Validates the SB spec locally (no Verilator/Docker). Core acceptance: for
every (direction, track, sel in 1..3) the correct same-index source is routed
to out_DIR[t] with full isolation of all other tracks/directions; sel0
disconnects (drives 0); self-consistency of the source map; and the
dependency_edges() output used by the fabric-level cycle detector.

Run: ``make test-model`` (root) or
``pytest ethereal-fabric/tests/interconnect/test_sb_model.py -v``
"""
from __future__ import annotations

import pytest

from sb_model import DIRS, DIR_IDX, SwitchBox, _SOURCES, sources

W = 12
MASK = (1 << W) - 1


# ---- 1. parameter derivation -------------------------------------------------

def test_params_v1():
    sb = SwitchBox(W=12)
    assert sb.AW == 6               # $clog2(4*12+8) = $clog2(56) = 6
    assert sb.NSEL == 48
    assert sb.NINJ == 8             # default routable-CB injectable count


def test_no_reset_default_disconnect():
    # unconfigured selects behave as disconnect -> all-zero outputs even with
    # all-one inputs (mirrors OCC configures-before-run; sel_r has no reset)
    sb = SwitchBox(W=12)
    assert sb.outputs(MASK, MASK, MASK, MASK) == (0, 0, 0, 0)


# ---- 2. addressing round-trip ------------------------------------------------

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_addr_decode_roundtrip(d, t):
    sb = SwitchBox(W=12)
    a = sb.addr(d, t)
    assert a == DIR_IDX[d] * W + t
    di, tt = sb.decode(a)
    assert di == DIR_IDX[d]
    assert tt == t


@pytest.mark.parametrize("a", range(4 * W))
def test_config_roundtrip(a):
    sb = SwitchBox(W=12)
    data = a % 4                     # cycle 0..3
    sb.configure(a, data)
    di, t = sb.decode(a)
    assert sb.sel.get((di, t), 0) == data


def test_configure_masks_addr_and_data():
    sb = SwitchBox(W=12)
    # addr beyond SB_END (NSEL+NINJ = 56) is ignored (AW-bit mask then range)
    sb.configure(sb.NSEL + sb.NINJ, 1)   # addr 56 -> out of range
    assert sb.sel == {}
    assert sb.inject_en == set()
    # data masked to low 2 bits (sel path)
    sb.configure(0, 0b101)           # -> sel 0b01 = 1
    assert sb.sel[(0, 0)] == 1
    sb.configure(1, 0b110)           # -> sel 0b10 = 2
    assert sb.sel[(0, 1)] == 2
    # inject path: addr in [NSEL, NSEL+NINJ), data[0]=en, data[2:1]=dir
    sb.configure(sb.NSEL, 0b101)     # addr 48 -> en[0]=1, dir[0]=2 (E)
    assert 0 in sb.inject_en
    assert sb.inject_dir[0] == 2
    sb.configure(sb.NSEL, 0b100)     # addr 48 -> en[0]=0
    assert 0 not in sb.inject_en
    assert 0 not in sb.inject_dir


def test_route_matches_configure():
    sb1 = SwitchBox(W=12).route("e", 5, 3)
    sb2 = SwitchBox(W=12).configure(DIR_IDX["e"] * W + 5, 3)
    assert sb1.sel == sb2.sel


# ---- 3. source map self-consistency ----------------------------------------

def test_sources_helper_matches_table():
    assert sources("n") == ("s", "e", "w")
    assert sources("s") == ("n", "e", "w")
    assert sources("e") == ("n", "s", "w")
    assert sources("w") == ("n", "s", "e")


def test_sources_self_consistency():
    # each output dir has exactly 3 distinct sources, none == itself
    for d in DIRS:
        srcs = _SOURCES[d]
        assert len(set(srcs)) == 3
        assert d not in srcs
        # union of sources == the 3 other dirs
        assert set(srcs) == (set(DIRS) - {d})


def test_each_output_has_three_sources_plus_disconnect():
    # self-consistency: for every (d, t) the 3 real sources are the other dirs
    for d in DIRS:
        for t in range(W):
            srcs = _SOURCES[d]
            assert len(srcs) == 3
            assert d not in srcs


# ---- 4. core acceptance: per (direction, track, sel) source correctness ----

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
@pytest.mark.parametrize("sel", (1, 2, 3))
def test_source_correctness_positive(d, t, sel):
    # drive ONLY the expected source dir's track t -> must appear at out[d][t]
    sb = SwitchBox(W=12).route(d, t, sel)
    src = _SOURCES[d][sel - 1]
    ins = {dd: 0 for dd in DIRS}
    ins[src] = 1 << t
    outs = dict(zip(DIRS, sb.outputs(ins["n"], ins["s"], ins["e"], ins["w"])))
    # out[d] bit t == 1
    assert ((outs[d] >> t) & 1) == 1
    # out[d] has no other bit set (same-index only)
    assert (outs[d] & ~(1 << t)) == 0
    # every other out direction is fully isolated (== 0)
    for dd in DIRS:
        if dd != d:
            assert outs[dd] == 0


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
@pytest.mark.parametrize("sel", (1, 2, 3))
def test_source_correctness_negative(d, t, sel):
    # expected source bit t = 0, all OTHER dirs' bit t = 1 -> out[d][t] must be 0
    sb = SwitchBox(W=12).route(d, t, sel)
    src = _SOURCES[d][sel - 1]
    ins = {dd: 0 for dd in DIRS}
    for dd in DIRS:
        if dd != src:
            ins[dd] = 1 << t
    outs = dict(zip(DIRS, sb.outputs(ins["n"], ins["s"], ins["e"], ins["w"])))
    assert ((outs[d] >> t) & 1) == 0


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
@pytest.mark.parametrize("sel", (1, 2, 3))
def test_source_is_exactly_one_of_three(d, t, sel):
    # among the 3 candidate sources, only the selected one's bit propagates
    sb = SwitchBox(W=12).route(d, t, sel)
    srcs = _SOURCES[d]
    expected = srcs[sel - 1]
    ins = {dd: 0 for dd in DIRS}
    for i, s in enumerate(srcs):
        ins[s] = 1 << t            # all 3 candidates carry bit t
    outs = dict(zip(DIRS, sb.outputs(ins["n"], ins["s"], ins["e"], ins["w"])))
    assert ((outs[d] >> t) & 1) == 1
    # flip ONLY the expected source to 0 -> output must drop to 0
    ins[expected] = 0
    outs2 = dict(zip(DIRS, sb.outputs(ins["n"], ins["s"], ins["e"], ins["w"])))
    assert ((outs2[d] >> t) & 1) == 0


# ---- 5. disconnect ----------------------------------------------------------

@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_disconnect_explicit(d, t):
    sb = SwitchBox(W=12).route(d, t, 0)
    outs = dict(zip(DIRS, sb.outputs(MASK, MASK, MASK, MASK)))
    assert ((outs[d] >> t) & 1) == 0


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("t", range(W))
def test_disconnect_full_word_zero(d, t):
    sb = SwitchBox(W=12)
    for dd in DIRS:
        for tt in range(W):
            sb.route(dd, tt, 0)     # every mux disconnected
    assert sb.outputs(MASK, MASK, MASK, MASK) == (0, 0, 0, 0)


# ---- 6. independence / multi-mux interaction --------------------------------

def test_independence_adjacent_tracks():
    sb = SwitchBox(W=12)
    sb.route("n", 0, 1)             # out_n[0] <- in_s[0]
    sb.route("n", 1, 2)             # out_n[1] <- in_e[1]
    on, *_ = sb.outputs(0, 1, 2, 0)  # in_s=1 (bit0), in_e=2 (bit1)
    assert on == 0b11


def test_independence_different_dirs():
    sb = SwitchBox(W=12)
    sb.route("n", 3, 1)             # <- in_s[3]
    sb.route("e", 7, 2)             # <- in_s[7]
    sb.route("w", 0, 3)             # <- in_e[0]
    ins_s = (1 << 3) | (1 << 7)
    on, os_, oe, ow = sb.outputs(0, ins_s, 1, 0)
    assert (on >> 3) & 1            # in_s[3] -> out_n[3]
    assert (oe >> 7) & 1            # in_s[7] -> out_e[7]
    assert ow & 1                   # in_e[0] -> out_w[0]
    # no stray bits
    assert on == (1 << 3)
    assert oe == (1 << 7)
    assert ow == 1


def test_last_write_wins():
    sb = SwitchBox(W=12)
    sb.route("n", 0, 1)
    sb.route("n", 0, 2)             # overwrite -> now in_e[0]
    on, *_ = sb.outputs(0, 0, 1, 0)
    assert on == 1


# ---- 7. dependency_edges (fabric cycle-detector interface) ------------------

def test_edges_basic():
    sb = SwitchBox(W=12)
    sb.route("n", 0, 1)             # out_n[0] <- in_s[0]
    sb.route("e", 5, 3)             # out_e[5] <- in_w[5]
    sb.route("s", 2, 0)             # disconnect -> no edge
    edges = sb.dependency_edges()
    assert (("in", "s", 0), ("out", "n", 0)) in edges
    assert (("in", "w", 5), ("out", "e", 5)) in edges
    assert len(edges) == 2
    assert not any(dst == ("out", "s", 2) for _, dst in edges)


def test_edges_all_active():
    sb = SwitchBox(W=12)
    for d in DIRS:
        for t in range(W):
            sb.route(d, t, 1)       # sel 1 -> first source
    edges = sb.dependency_edges()
    assert len(edges) == 4 * W
    for d in DIRS:
        src = _SOURCES[d][0]
        assert (("in", src, 0), ("out", d, 0)) in edges


def test_edges_all_disconnect_empty():
    sb = SwitchBox(W=12)
    for d in DIRS:
        for t in range(W):
            sb.route(d, t, 0)
    assert sb.dependency_edges() == set()


def test_edges_unconfigured_empty():
    assert SwitchBox(W=12).dependency_edges() == set()


@pytest.mark.parametrize("d", DIRS)
@pytest.mark.parametrize("sel", (1, 2, 3))
def test_edges_one_per_active_mux(d, sel):
    sb = SwitchBox(W=12)
    for t in range(W):
        sb.route(d, t, sel)
    edges = sb.dependency_edges()
    assert len(edges) == W
    src = _SOURCES[d][sel - 1]
    for t in range(W):
        assert (("in", src, t), ("out", d, t)) in edges


def test_edges_node_shape():
    # node naming convention documented for the fabric cycle detector
    sb = SwitchBox(W=12).route("n", 4, 2)   # out_n[4] <- in_e[4]
    (edge,) = sb.dependency_edges()
    src_node, dst_node = edge
    assert src_node == ("in", "e", 4)
    assert dst_node == ("out", "n", 4)
    assert src_node[0] == "in" and dst_node[0] == "out"


# ---- 8. bidirectional inject (clb_out[j] -> out_D[j], D configurable) -------

def test_inject_en_routes_clb_out_to_out_e():
    sb = SwitchBox(W=12)                   # N_INJ=8 default
    sb.inject(3, True)                     # inject_en[3] = 1, default dir "e"
    oe = sb.outputs(0, 0, 0, 0, clb_out=1 << 3)[2]
    assert ((oe >> 3) & 1) == 1            # clb_out[3] -> out_e[3]
    assert (oe & ~(1 << 3)) == 0           # only bit 3


def test_inject_cleared_falls_back_to_disjoint():
    sb = SwitchBox(W=12)
    sb.route("e", 3, 1)                    # disjoint: out_e[3] <- in_n[3]
    sb.inject(3, False)                    # inject disabled
    # clb_out[3]=1 but inject off -> out_e[3] follows disjoint sel (in_n[3])
    oe = sb.outputs(1 << 3, 0, 0, 0, clb_out=1 << 3)[2]
    assert ((oe >> 3) & 1) == 1
    # in_n[3]=0, clb_out[3]=1, inject off -> out_e[3] = 0 (clb_out ignored)
    oe2 = sb.outputs(0, 0, 0, 0, clb_out=1 << 3)[2]
    assert ((oe2 >> 3) & 1) == 0


def test_inject_overrides_disjoint_sel():
    # even when disjoint sel points elsewhere, inject_en wins
    sb = SwitchBox(W=12)
    sb.route("e", 3, 1)                    # disjoint: out_e[3] <- in_n[3]
    sb.inject(3, True)                     # inject overrides
    # in_n[3]=1, clb_out[3]=0 -> out_e[3] must be 0 (inject wins)
    oe = sb.outputs(1 << 3, 0, 0, 0, clb_out=0)[2]
    assert ((oe >> 3) & 1) == 0


def test_inject_via_configure_addr():
    sb = SwitchBox(W=12)
    # addr 53 -> inject_en[5]=1, inject_dir[5]=2 (E); data = 1 | (2<<1) = 5
    sb.configure(sb.NSEL + 5, 5)
    en, d = sb.inject_of(5)
    assert en is True and d == "e"
    oe = sb.outputs(0, 0, 0, 0, clb_out=1 << 5)[2]
    assert ((oe >> 5) & 1) == 1
    sb.configure(sb.NSEL + 5, 0)           # clear (en=0)
    en2, d2 = sb.inject_of(5)
    assert en2 is False and d2 is None


def test_inject_dir_cfg_encoding():
    # data = en | (dir_idx << 1) for each direction
    for d_idx, d_name in enumerate(DIRS):
        sb = SwitchBox(W=12)
        sb.configure(sb.NSEL + 1, 1 | (d_idx << 1))
        en, rd = sb.inject_of(1)
        assert en is True and rd == d_name


@pytest.mark.parametrize("d", DIRS)
def test_inject_bidirectional_outputs(d):
    # inject clb_out[3] toward each direction; only out_d[3] carries it
    sb = SwitchBox(W=12)
    sb.inject(3, True, d)
    en, rd = sb.inject_of(3)
    assert en is True and rd == d
    outs = dict(zip(DIRS, sb.outputs(0, 0, 0, 0, clb_out=1 << 3)))
    assert ((outs[d] >> 3) & 1) == 1           # clb_out[3] -> out_d[3]
    for d2 in DIRS:
        if d2 != d:
            assert ((outs[d2] >> 3) & 1) == 0  # no leak into other dirs


@pytest.mark.parametrize("d", DIRS)
def test_inject_bidirectional_edges(d):
    sb = SwitchBox(W=12)
    sb.inject(2, True, d)
    edges = sb.dependency_edges()
    assert (("clb_out", 2), ("out", d, 2)) in edges


@pytest.mark.parametrize("d", DIRS)
def test_inject_bidirectional_suppresses_disjoint(d):
    # inject overrides the disjoint sel ONLY for the injected direction.
    sb = SwitchBox(W=12)
    sb.route(d, 4, 1)                     # disjoint sel for out_d[4] (sel 1)
    sb.inject(4, True, d)                 # override out_d[4]
    edges = sb.dependency_edges()
    src = _SOURCES[d][0]                  # sel 1 source dir
    assert (("in", src, 4), ("out", d, 4)) not in edges  # disjoint suppressed
    assert (("clb_out", 4), ("out", d, 4)) in edges       # inject edge appears


def test_inject_edges_in_dependency_graph():
    sb = SwitchBox(W=12)
    sb.inject(2, True)
    sb.inject(7, True)
    edges = sb.dependency_edges()
    assert (("clb_out", 2), ("out", "e", 2)) in edges
    assert (("clb_out", 7), ("out", "e", 7)) in edges


def test_inject_suppresses_disjoint_out_e_edge():
    # inject_en[j]=1 overrides out_e[j] -> its disjoint in->out_e edge must
    # NOT appear (faithful to the RTL mux); the injection edge appears instead.
    sb = SwitchBox(W=12)
    sb.route("e", 4, 1)                    # disjoint: in_n[4] -> out_e[4]
    sb.route("n", 4, 1)                    # disjoint: in_s[4] -> out_n[4]
    sb.inject(4, True)                     # override out_e[4]
    edges = sb.dependency_edges()
    assert (("in", "n", 4), ("out", "e", 4)) not in edges
    assert (("clb_out", 4), ("out", "e", 4)) in edges
    # disjoint edge for the non-injected direction is unaffected
    assert (("in", "s", 4), ("out", "n", 4)) in edges


def test_inject_edges_empty_by_default():
    # default config (no inject_en) -> no clb_out edges (acyclic baseline)
    assert SwitchBox(W=12).dependency_edges() == set()
