# SPDX-License-Identifier: MIT
"""pytest suite for the clb_t golden reference model (task E0-FAB2, updated to
interconnect **v2c**, frozen spec interconnect-config-v0.md section 7.2).

Validates the CLB spec locally (no Verilator/Docker). Key acceptance: the v2c
IIB select encoding (feedback-first depopulated crossbar) and its reachability
invariants — **R1** every feedback j reaches every LUT input, **R2** ext pin i
reaches a LUT only through its parity-class pins, **R3** two pin slots per
parity class per LUT — plus a registered-feedback toggle circuit (exercises
feedback routing + FF + settle).

Run: ``make test-model`` (root) or
``pytest ethereal-fabric/tests/clb/test_clb_t_model.py -v``
"""
from __future__ import annotations

import random

import pytest

from clb_t_model import ClbT

V1 = dict(N=8, K=4, EXT_IN=18)


# ---- 1. parameter derivation + config addressing ----------------------------

def test_params_v1():
    c = ClbT(**V1)
    assert (c.I, c.NK, c.POOL, c.SELW) == (26, 32, 32, 5)
    assert c.FB_BASE == 24                       # v2c: feedback j at pool[24+j]
    assert c.lut_end == 8 and c.mux_end == 40


def test_config_decode_elut_vs_mux():
    c = ClbT(**V1)
    # addr 0..7 -> eLUT
    c.configure(3, 0xABCD0)            # low 20 bits matter; elut gets 0xABCD0 & 0xFFFFF
    assert c.eluts[3].config.to_word() == (0xABCD0 & 0xFFFFF)
    # addr 8..39 -> IIB mux; addr-N indexes the mux
    c.configure(8 + 5, 0b11010)        # mux #5
    assert c.mux_sel[5] == 0b11010
    # reserved addr ignored
    c.configure(60, 0x123)
    assert all(m == 0 for i, m in enumerate(c.mux_sel) if i != 5)


def test_route_helper():
    c = ClbT(**V1)
    c.route(lut=2, pin=1, source=3)    # v2c sel 3 = feedback j=3
    assert c.mux_sel[2 * 4 + 1] == 3


# ---- 2. v2c select encoding (section 7.2 bit-slicing) ------------------------

def test_sel_encode_decode_roundtrip():
    c = ClbT(**V1)
    # feedback: sel = j, decodes to pool 24+j from EVERY pin (R1)
    for j in range(c.N):
        assert c.sel_fb(j) == j
        for gk in range(c.K):
            assert c.pool_index_of(gk, c.sel_fb(j)) == 24 + j
    # external: sel = 16 + i//2, decodes to pool i ONLY on parity-matching pins
    for i in range(c.EXT_IN):
        for gk in range(c.K):
            if gk % 2 == i % 2:
                sel = c.sel_ext(gk, i)
                assert sel == 0b10000 | (i // 2)
                assert c.pool_index_of(gk, sel) == i
            else:
                with pytest.raises(ValueError, match="R2 parity"):
                    c.sel_ext(gk, i)


def test_sel_reserved_values():
    c = ClbT(**V1)
    # sel[4]=1 with sel[3:0] = 9..15 -> pool padding/fb region (MUST NOT be
    # programmed; the model decodes anyway, padding reads 0)
    for k in range(9, 16):
        idx = c.pool_index_of(0, 0b10000 | k)
        assert idx == 2 * k                             # 18..30 (padding/fb)
    # sel[4]=0: sel[3] is don't-care (8+j decodes to feedback j as well)
    for j in range(c.N):
        assert c.pool_index_of(0, 0b01000 | j) == 24 + j
    with pytest.raises(ValueError):
        c.sel_fb(8)
    with pytest.raises(ValueError):
        c.sel_ext(0, 18)


def test_pool_layout():
    # v2c pool: ext[0..17], zero padding[18..23], feedback j at [24..31]
    c = ClbT(**V1)
    c.clb_out = [1, 0, 1, 0, 0, 0, 0, 0]
    pool = c._pool(0b101)                     # ext bits 0 and 2
    assert pool[0] == 1 and pool[1] == 0 and pool[2] == 1
    assert all(pool[p] == 0 for p in range(18, 24))     # padding
    assert pool[24] == 1 and pool[25] == 0 and pool[26] == 1  # feedback
    assert len(pool) == 32


# ---- 3. IIB connectivity exhaustion under v2c (R1-R3 acceptance) ------------

def test_connectivity_exhaustion_feedback_r1():
    """R1: every feedback j reaches EVERY LUT input (all gi, all gk)."""
    c = ClbT(**V1)
    for i in range(c.N):
        for k in range(c.K):
            for j in range(c.N):
                c.mux_sel = [0] * c.NK
                c.clb_out = [0] * c.N
                c.route(i, k, c.sel_fb(j))
                c.clb_out[j] = 1                # drive the feedback source
                pool = c._pool(0)
                vin = c._lut_vin(i, pool)
                assert ((vin >> k) & 1) == 1, (
                    f"R1 fail: fb{j} -> LUT{i}.in{k} (vin={vin:04b})")


def test_connectivity_exhaustion_ext_r2():
    """R2: ext pin i reaches LUT gi.in[gk] iff i mod 2 == gk mod 2."""
    c = ClbT(**V1)
    for i in range(c.N):
        for k in range(c.K):
            for s in range(c.EXT_IN):
                c.mux_sel = [0] * c.NK
                c.clb_out = [0] * c.N
                ext = 1 << s
                if s % 2 == k % 2:
                    c.route(i, k, c.sel_ext(k, s))
                    pool = c._pool(ext)
                    vin = c._lut_vin(i, pool)
                    assert ((vin >> k) & 1) == 1, (
                        f"R2 fail: clb_in[{s}] -> LUT{i}.in{k} should reach")
                else:
                    # parity-mismatched: no legal sel exists; verify every
                    # legal sel at this pin leaves bit k at 0 for this drive.
                    for sel in range(32):
                        c.mux_sel = [0] * c.NK
                        c.route(i, k, sel)
                        idx = c.pool_index_of(k, sel)
                        if 18 <= idx < 24:
                            continue            # reserved decode region (skip)
                        pool = c._pool(ext)
                        vin = c._lut_vin(i, pool)
                        assert ((vin >> k) & 1) == 0, (
                            f"R2 violated: clb_in[{s}] reached LUT{i}.in{k} "
                            f"via sel={sel}")


def test_parity_slots_r3():
    """R3: within one LUT, each parity class has exactly 2 pin slots."""
    c = ClbT(**V1)
    for i in range(c.N):
        even = [k for k in range(c.K) if c.parity(k) == 0]
        odd = [k for k in range(c.K) if c.parity(k) == 1]
        assert even == [0, 2] and odd == [1, 3]


# ---- 4. registered-feedback circuit: a self-toggling FF ---------------------
# LUT0 = NOT(its own output), registered -> toggles every clock.

def _config_toggle(c: ClbT) -> None:
    # LUT0 input0 <- LUT0 feedback = v2c sel 0 (feedback j=0)
    c.route(0, 0, c.sel_fb(0))
    # inverter of bit0: tt[0]=1, tt[1]=0 (other inputs tied to fb j=0 too;
    # with all four pins reading the same feedback, vin in {0,15} -> toggle)
    c.configure_elut(0, word=((0x0001) << 4) | (1 << 3) | (1 << 2) | (1 << 1))
    # word = {tt=0x0001, ff_en=1, ff_rst_en=1, ff_rst_val=1, out_inv=0}
    # tie LUT0 inputs 1..3 to feedback j=0 as well (harmless; sel 0 = default)
    for k in (1, 2, 3):
        c.route(0, k, c.sel_fb(0))


def test_toggle_ff_feedback():
    c = ClbT(**V1)
    _config_toggle(c)
    # elut0 reset value = 1 -> after a reset edge clb_out[0]=1
    c.clock(0, rst_n=0)
    assert c.clb_out[0] == 1
    # now toggle with rst released: 1 -> 0 -> 1 -> 0 ...
    seq = [c.clock(0, rst_n=1)[0] for _ in range(6)]
    assert seq == [0, 1, 0, 1, 0, 1]


# ---- 5. acyclic random config: settle converges + outputs stable ------------

def test_random_acyclic_settles_and_stable():
    """All-LUTs-from-external (no feedback) acyclic configs must settle, and
    combinational outputs must be a pure function of (config, ext_in)."""
    rng = random.Random(20240724)
    for _ in range(200):
        c = ClbT(**V1)
        for i in range(c.N):
            # each LUT input from a random EXTERNAL source of the pin's parity
            # class (acyclic by construction; v2c-legal sels only)
            for k in range(c.K):
                i_ext = rng.randrange(c.EXT_IN // 2) * 2 + (k % 2)
                c.route(i, k, c.sel_ext(k, i_ext))
            c.configure_elut(i, rng.getrandbits(20) & ~(1 << 3))  # ff_en=0
        ext = rng.getrandbits(c.EXT_IN)
        out1 = c.outputs(ext)
        out2 = c.outputs(ext)   # re-eval: must be identical (purely comb, settled)
        assert out1 == out2
        # independent recompute of each LUT output for cross-check
        pool = c._pool(ext)
        for i in range(c.N):
            vin = c._lut_vin(i, pool)
            expected = c.eluts[i].comb_out(vin)
            assert out1[i] == expected


def test_comb_loop_detected():
    """A pure combinational loop (LUT0 = NOT(LUT0 output), NOT registered) must
    be detected (settle raises) rather than silently mis-evaluated."""
    c = ClbT(**V1)
    c.route(0, 0, c.sel_fb(0))                        # LUT0.in0 <- LUT0 out (comb fb)
    c.configure_elut(0, word=(0x0001 << 4))           # tt=inverter, ff_en=0 -> comb loop
    with pytest.raises(RuntimeError):
        c.outputs(0)


def test_blank_default_reads_feedback_j0():
    """v2c blank semantics (section 7.7): zero-init IIB sel=0 reads feedback
    j=0 (was clb_in[0] in v1.1) — a blanked LUT self-reads fb[0]."""
    c = ClbT(**V1)
    c.clb_out = [1] + [0] * 7
    pool = c._pool(0)                     # all ext = 0
    # every mux at default sel=0 -> vin bit k = fb[0] = 1 for every LUT
    for i in range(c.N):
        vin = c._lut_vin(i, pool)
        assert vin == 0b1111
