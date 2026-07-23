# SPDX-License-Identifier: MIT
"""pytest suite for the clb_t golden reference model (task E0-FAB2).

Validates the CLB spec locally (no Verilator/Docker). Key acceptance: IIB
connectivity exhaustion ("any cluster input -> any LUT input routable") plus a
registered-feedback toggle circuit (exercises feedback routing + FF + settle).

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
    c.route(lut=2, pin=1, source=20)   # LUT2 input1 <- pool[20] (feedback src 2)
    assert c.mux_sel[2 * 4 + 1] == 20


# ---- 2. IIB connectivity exhaustion (core acceptance) ----------------------
# For every (LUT i, input k, cluster-input source s), route source s to LUT i
# input k, drive ONLY source s, and assert the routed bit reads back.

def test_connectivity_exhaustion():
    c = ClbT(**V1)
    for i in range(c.N):
        for k in range(c.K):
            for s in range(c.I):  # 0..25 (external 0..17 + feedback 18..25)
                # fresh routing: only this one mux set to s, others to a zero source
                c.mux_sel = [0] * c.NK
                c.clb_out = [0] * c.N
                c.route(i, k, s)
                ext = (1 << s) if s < c.EXT_IN else 0
                if s >= c.EXT_IN:
                    c.clb_out[s - c.EXT_IN] = 1   # drive the feedback source directly
                pool = c._pool(ext)
                vin = c._lut_vin(i, pool)
                assert ((vin >> k) & 1) == 1, (
                    f"connectivity fail: src{s} -> LUT{i}.in{k} (vin={vin:04b})"
                )


# ---- 3. registered-feedback circuit: a self-toggling FF --------------------
# LUT0 = NOT(its own output), registered -> toggles every clock.

def _config_toggle(c: ClbT) -> None:
    # LUT0 input0 <- LUT0 feedback = pool index EXT_IN+0 = 18
    c.route(0, 0, c.EXT_IN + 0)
    # inverter of bit0: tt[0]=1, tt[1]=0 (other inputs tied to 0 via mux=0->pool0=0)
    c.configure_elut(0, word=((0x0001) << 4) | (1 << 3) | (1 << 2) | (1 << 1))
    # word = {tt=0x0001, ff_en=1, ff_rst_en=1, ff_rst_val=1, out_inv=0}
    # tie LUT0 inputs 1..3 to source 0 (pool[0]=ext bit0=0) -> harmless
    for k in (1, 2, 3):
        c.route(0, k, 0)


def test_toggle_ff_feedback():
    c = ClbT(**V1)
    _config_toggle(c)
    # elut0 reset value = 1 -> after a reset edge clb_out[0]=1
    c.clock(0, rst_n=0)
    assert c.clb_out[0] == 1
    # now toggle with rst released: 1 -> 0 -> 1 -> 0 ...
    seq = [c.clock(0, rst_n=1)[0] for _ in range(6)]
    assert seq == [0, 1, 0, 1, 0, 1]


# ---- 4. acyclic random config: settle converges + outputs stable -----------

def test_random_acyclic_settles_and_stable():
    """All-LUTs-from-external (no feedback) acyclic configs must settle, and
    combinational outputs must be a pure function of (config, ext_in)."""
    rng = random.Random(20240724)
    for _ in range(200):
        c = ClbT(**V1)
        for i in range(c.N):
            # each LUT input from a random EXTERNAL source (acyclic by construction)
            for k in range(c.K):
                c.route(i, k, rng.randrange(c.EXT_IN))
            c.configure_elut(i, rng.getrandbits(20) & ~(1 << 3))  # ff_en=0 (pure comb)
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
    c.route(0, 0, c.EXT_IN + 0)                       # LUT0.in0 <- LUT0 out (comb fb)
    c.configure_elut(0, word=(0x0001 << 4))           # tt=inverter, ff_en=0 -> comb loop
    with pytest.raises(RuntimeError):
        c.outputs(0)
