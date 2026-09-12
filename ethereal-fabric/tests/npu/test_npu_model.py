# SPDX-License-Identifier: MIT
"""Golden-model pytest suite for the NPU-Tiny INT8 tile (E3-SVC1).

Runs locally with no simulator (``make test-model``): it pins the numeric contract
that ``ethereal-fabric/rtl/tile/{pe_int8,npu_arr8,npu_t}.sv`` implements and that
``tb_npu_t.sv`` / ``tb_npu_tinyml.sv`` compare against, guards the generated vector
files against drift, and models the session-isolation semantics that
``tb_npu_isolation.sv`` asserts on hardware.

Run: ``make test-model`` or
``pytest ethereal-fabric/tests/npu/test_npu_model.py -v``
"""
from __future__ import annotations

import gen_npu_vectors as gen
import npu_model as m
import pytest

I32_MAX = m.I32_MAX
I32_MIN = m.I32_MIN


# ---- 1. arithmetic contract -------------------------------------------------

def test_product_is_exact_int8():
    assert m.as_i8(127) * m.as_i8(127) == 16129
    assert m.as_i8(-128) * m.as_i8(-128) == 16384
    assert m.as_i8(-128) * m.as_i8(127) == -16256
    with pytest.raises(ValueError):
        m.as_i8(128)


def test_sat_add_boundaries():
    assert m.sat_add_i32(0, 0) == (0, False)
    assert m.sat_add_i32(I32_MAX, 0) == (I32_MAX, False)
    assert m.sat_add_i32(I32_MAX - 1, 1) == (I32_MAX, False)
    assert m.sat_add_i32(I32_MAX, 1) == (I32_MAX, True)
    assert m.sat_add_i32(I32_MIN + 1, -1) == (I32_MIN, False)
    assert m.sat_add_i32(I32_MIN, -1) == (I32_MIN, True)
    assert m.sat_add_i32(I32_MIN, I32_MIN) == (I32_MIN, True)


def test_saturation_is_per_step_not_final():
    """The RTL saturates at every PE add; a 'sum then saturate' model would differ."""
    a = [[127] * 8]
    w = [[127] * 8 for _ in range(8)]
    res = m.chunk_gemm(a, w, 1)
    # 8 steps of +16129 never reach +2^31, so no saturation here
    assert res.c[0][0] == 8 * 16129 and not res.ovf
    # a deep chain that does saturate: build it with the C-buffer accumulate
    c_hi = [[I32_MAX] + [0] * 7] + [[0] * 8 for _ in range(7)]
    a2 = [[1] + [0] * 7]
    w2 = [[1] + [0] * 7] + [[0] * 8 for _ in range(7)]
    step = m.gemm(a2, w2, 1, 8, c_prev=c_hi, acc_en=True)
    assert step.c[0][0] == I32_MAX and step.ovf
    # per-step saturation (not final-only): max-1 + 1 then the negative rail
    c_neg = [[I32_MIN] + [0] * 7] + [[0] * 8 for _ in range(7)]
    step2 = m.gemm(a2, w2, 1, 8, c_prev=c_neg, acc_en=True)
    assert step2.c[0][0] == I32_MIN + 1 and not step2.ovf
    assert m.sat_add_i32(I32_MIN, -5) == (I32_MIN, True)


def test_gemm_matches_naive_reference():
    a = m  # silence unused-import style tools
    del a
    a_mat = [[(i * 7 + j * 3) % 256 - 128 for j in range(8)] for i in range(8)]
    w_mat = [[(i * 5 - j * 9) % 256 - 128 for j in range(8)] for i in range(8)]
    got = m.gemm(a_mat, w_mat, 8, 8)
    for i in range(8):
        for j in range(8):
            acc = 0
            for k in range(8):
                acc += a_mat[i][k] * w_mat[k][j]
            assert got.c[i][j] == acc, (i, j)
    assert not got.ovf


def test_gemm_tiling_k16_accumulates():
    a16 = [[(i + j) % 128 - 64 for j in range(16)] for i in range(4)]
    w16 = [[(i * 3 + j) % 128 - 64 for j in range(8)] for i in range(16)]
    chunk0 = m.gemm([row[:8] for row in a16], [row[:] for row in w16[:8]], 4, 8)
    chunk1 = m.gemm([row[8:] for row in a16], [row[:] for row in w16[8:]],
                    4, 8, c_prev=chunk0.c, acc_en=True)
    whole = m.gemm(a16, w16, 4, 16)
    assert chunk1.c == whole.c
    assert chunk1.ovf == whole.ovf


def test_unwritten_rows_keep_their_value():
    """Rows >= M are never captured, so a stale C buffer survives there — the exact
    cross-container leak the RTL must prevent by blanking at a session boundary."""
    c_prev = [[7] * 8 for _ in range(8)]
    res = m.gemm([[1] * 8], [[1] * 8 for _ in range(8)], 1, 8, c_prev=c_prev)
    assert res.c[0] == [8] * 8
    assert res.c[1] == [7] * 8      # untouched residue in the model
    blanked = m.gemm([[1] * 8], [[1] * 8 for _ in range(8)], 1, 8)
    assert blanked.c[1] == [0] * 8  # with a proper session blank


def test_geometry_rejects_bad_descriptor():
    with pytest.raises(ValueError):
        m.gemm([[0] * 8], [[0] * 8 for _ in range(8)], 9, 8)
    with pytest.raises(ValueError):
        m.gemm([[0] * 8], [[0] * 8 for _ in range(8)], 1, 12)


# ---- 2. host-side activation quantization -----------------------------------

def test_requant_rules():
    assert m.requant_i8(0) == 0
    assert m.requant_i8(127) == 0            # (127+128)>>8 == 0
    assert m.requant_i8(128) == 1
    assert m.requant_i8(255) == 1
    assert m.requant_i8(1000) == 4
    assert m.requant_i8(-1) == 0             # floor((127)/256) == 0
    assert m.requant_i8(-129) == -1
    assert m.requant_i8(1 << 20) == 127      # clamps at the INT8 rail
    assert m.requant_i8(-(1 << 20)) == -128


# ---- 3. TinyML demo determinism ---------------------------------------------

def test_tinyml_demo_is_reproducible_and_argmax_stable():
    text, summary = gen.build_tinyml_vectors()
    assert text == gen.build_tinyml_vectors()[0]
    assert summary["class"] == 1
    assert summary["y1_q"] == [20, 0, 20, 35, 68, 33, 4, 97]
    assert summary["y2"][:4] == [2188, 8188, 3045, -10104]
    assert summary["ovf"] == 0
    # the class is the argmax of the four scored outputs, checked independently
    scored = summary["y2"][:4]
    assert max(range(4), key=lambda i: scored[i]) == summary["class"]


def test_tinyml_layer1_bias_fold_matches_the_two_chunk_run():
    """Layer 1 is a K=16 session; the model's mlp_infer and the two-chunk script
    must agree (both are used to build the vector file)."""
    x = gen.lcg(0xF001, 8, -128, 127)
    w1 = gen._mat(gen.lcg(0xF101, 64, -128, 127), 8, 8)
    b1 = gen.lcg(0xF201, 8, -100, 100)
    w2 = gen._mat(gen.lcg(0xF301, 64, -128, 127), 8, 8)
    for k in range(8):
        for n in range(4, 8):
            w2[k][n] = 0
    res = m.mlp_infer(x, w1, b1, w2, n_classes=4)
    c1 = m.gemm([x], w1, m=1, k=8)
    a_b = [[1] + [0] * 7]
    w_b = [[b1[n] for n in range(8)]] + [[0] * 8 for _ in range(7)]
    two_chunk = m.gemm(a_b, w_b, m=1, k=8, c_prev=c1.c, acc_en=True)
    assert two_chunk.c == res.y1
    assert res.cls == 1


# ---- 4. session isolation semantics ----------------------------------------

def test_session_blank_removes_all_state():
    st = m.SessionState().loaded(7)
    assert st.datapath_residue > 0 and st.control_residue > 0
    clean = st.blank()
    assert clean.datapath_residue == 0 and clean.control_residue == 0


def test_leak_injection_is_observable():
    """Negative control: with the leak, residue survives the boundary — this is what
    tb_npu_isolation's obs_* and C_RD checks must detect (and do, see the report)."""
    st = m.SessionState().loaded(7)
    leaked = st.blank(leak=True)
    assert leaked.datapath_residue > 0        # arrays keep the residue
    assert leaked.control_residue == 0        # control still resets (machine works)
    assert leaked.cbuf == st.cbuf             # a readable cross-container leak


def test_isolation_vectors_expose_cross_container_data_when_blank_is_skipped():
    """Container 2 runs M=2, so rows 2..7 of C are never rewritten: without the
    session blank they remain container 1's results (the leak the TB flags)."""
    a1 = gen._mat(gen.lcg(0xA001, 64, -128, 127), 8, 8)
    w1 = gen._mat(gen.lcg(0xB001, 64, -128, 127), 8, 8)
    a2 = gen._mat(gen.lcg(0xC001, 16, -128, 127), 2, 8)
    w2 = gen._mat(gen.lcg(0xD001, 64, -128, 127), 8, 8)
    c1 = m.gemm(a1, w1, m=8, k=8)
    leaky = m.gemm(a2, w2, m=2, k=8, c_prev=c1.c)     # no blank => stale rows
    clean = m.gemm(a2, w2, m=2, k=8)                  # blank => rows 2..7 zero
    assert leaky.c[3] == c1.c[3] and any(v != 0 for v in leaky.c[3])
    assert clean.c[3] == [0] * 8


# ---- 5. vector-file drift guard --------------------------------------------

def test_vectors_up_to_date():
    """The checked-in vectors must equal what the generator produces today."""
    for name, content in gen.build_all().items():
        path = gen.VECTOR_DIR / name
        assert path.exists(), f"missing vector file {path}"
        assert path.read_text(encoding="ascii") == content, f"{name} is stale"


def test_vectors_stream_shape():
    """Every generic case stream is self-consistent: header + m*8 A + 64 W + 64 C."""
    for name in ("npu_gemm_cases.txt", "npu_iso_cases.txt"):
        toks = (gen.VECTOR_DIR / name).read_text(encoding="ascii").split()
        i = 0
        cases = 0
        while i < len(toks):
            mm, nn, acc, tag = (int(toks[i + k]) for k in range(4))
            i += 4
            assert 1 <= mm <= 8 and nn == 8 and acc in (0, 1) and tag >= 0
            i += mm * 8 + 64 + 64
            cases += 1
        assert i == len(toks), f"{name}: {len(toks) - i} trailing token(s)"
        assert cases >= 4
