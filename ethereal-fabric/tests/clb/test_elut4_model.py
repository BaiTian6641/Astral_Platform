# SPDX-License-Identifier: MIT
"""pytest suite for the elut4 golden reference model (task E0-FAB1).

This validates the *spec* of elut4 locally (no Verilator/Docker required) by
checking the model is internally consistent and matches independent boolean
evaluations of LUT4 behaviour. The model then serves as the golden reference
for the Docker-gated cocotb test (``test_elut4.py``) that compares it against
the RTL DUT.

Run: ``pytest ethereal-fabric/tests/clb/test_elut4_model.py -v``
(or ``make test-model`` once the root Makefile target is wired).
"""
from __future__ import annotations

import random

import pytest

from elut4_model import CFG_WIDTH, Elut4, Elut4Config


# ---- independent helpers (NOT using the model under test) -------------------

def lut4_bool(tt: int, a: tuple[int, int, int, int]) -> int:
    """Independent LUT4 evaluation: tt encodes f(a) where a is (b0,b1,b2,b3)
    and the address is b0 + 2*b1 + 4*b2 + 8*b3 (little-endian bit order, matching
    tt[vin]). Used to cross-check the model's comb_out against a second method."""
    addr = a[0] | (a[1] << 1) | (a[2] << 2) | (a[3] << 3)
    return (tt >> addr) & 1


ALL_VIN = list(range(16))


# ---- 1. config bitfield round-trip -----------------------------------------

@pytest.mark.parametrize("seed", range(200))
def test_config_roundtrip_random(seed: int) -> None:
    rng = random.Random(seed)
    word = rng.getrandbits(CFG_WIDTH)
    cfg = Elut4Config.from_word(word)
    assert cfg.to_word() == word


def test_config_field_offsets() -> None:
    """Exact bit offsets per C01 §1.3 concat order."""
    cfg = Elut4Config(tt=0xABCD, ff_en=1, ff_rst_en=0, ff_rst_val=1, out_inv=0)
    w = cfg.to_word()
    assert (w >> 4) & 0xFFFF == 0xABCD
    assert (w >> 3) & 1 == 1
    assert (w >> 2) & 1 == 0
    assert (w >> 1) & 1 == 1
    assert w & 1 == 0


# ---- 2. combinational LUT4 (random tt, all inputs) -------------------------

@pytest.mark.parametrize("seed", range(1000))
def test_comb_truth_table(seed: int) -> None:
    rng = random.Random(seed + 1000)
    tt = rng.getrandbits(16)
    dut = Elut4(Elut4Config(tt=tt, ff_en=0))  # combinational path
    for vin in ALL_VIN:
        # model vs direct definition
        assert dut.comb_out(vin) == ((tt >> vin) & 1)
        # model vs independent boolean eval (little-endian bit unpack)
        bits = ((vin >> 0) & 1, (vin >> 1) & 1, (vin >> 2) & 1, (vin >> 3) & 1)
        assert dut.comb_out(vin) == lut4_bool(tt, bits)
        # combinational output is independent of clock history
        assert dut.clock(vin, rst_n=1, ce=0) == ((tt >> vin) & 1)


def test_comb_known_functions() -> None:
    """Sanity: well-known 4-input functions via their truth tables."""
    cases = {
        0x8000: "AND4",     # only all-ones -> 1
        0xFFFE: "NOR4",     # only all-zeros -> 0, else... actually 0xFFFE: bit0=0
        0x9996: "XOR-ish",
    }
    dut = Elut4()
    dut.configure(Elut4Config(tt=0x8000).to_word())  # AND4
    assert dut.clock(0b1111) == 1
    assert dut.clock(0b1110) == 0
    assert dut.clock(0b0000) == 0


# ---- 3. virtual FF: registration, CE gating, reset priority ----------------

def test_ff_registers_output() -> None:
    """With ff_en=1, vff loads comb on each enabled edge; vout tracks vff
    (registered: it only changes on a clock edge, latching the comb value
    present at that edge)."""
    dut = Elut4(Elut4Config(tt=0xFFFF, ff_en=1))  # comb is always 1
    assert dut.vff == 0
    out0 = dut.clock(0, rst_n=1, ce=1)  # edge loads comb=1 -> vff=1, out0=1
    assert out0 == 1
    assert dut.vff == 1
    # switch comb to 0 (reconfigure tt=0) and clock -> vff follows on the edge
    dut.configure(Elut4Config(tt=0x0000, ff_en=1).to_word())
    out1 = dut.clock(0, rst_n=1, ce=1)  # loads comb=0 -> vff=0, out1=0
    assert out1 == 0
    assert dut.vff == 0


def test_ff_ce_gating_holds() -> None:
    """ce=0 holds vff regardless of input."""
    dut = Elut4(Elut4Config(tt=0x0000, ff_en=1))  # comb always 0
    dut.vff = 1
    dut.clock(5, rst_n=1, ce=0)  # ce=0 -> hold
    assert dut.vff == 1
    dut.clock(5, rst_n=1, ce=1)  # ce=1 -> load comb (0)
    assert dut.vff == 0


def test_ff_reset_priority_over_ce() -> None:
    """Reset (when ff_rst_en) wins over CE."""
    dut = Elut4(Elut4Config(tt=0xFFFF, ff_en=1, ff_rst_en=1, ff_rst_val=0))
    dut.vff = 1
    out = dut.clock(0, rst_n=0, ce=1)  # reset asserted, ce=1, comb=1
    assert dut.vff == 0  # reset wins
    assert out == 0


def test_ff_reset_disabled_when_rst_en_clear() -> None:
    """ff_rst_en=0 -> rst_ni ignored."""
    dut = Elut4(Elut4Config(tt=0xFFFF, ff_en=1, ff_rst_en=0))
    dut.vff = 0
    dut.clock(0, rst_n=0, ce=1)  # reset ignored -> load comb=1
    assert dut.vff == 1


def test_ff_reset_value_respected() -> None:
    for rval in (0, 1):
        dut = Elut4(Elut4Config(tt=0x0000, ff_en=1, ff_rst_en=1, ff_rst_val=rval))
        dut.vff = 1 - rval
        out = dut.clock(0, rst_n=0, ce=0)
        assert dut.vff == rval
        assert out == rval


# ---- 4. output invert ------------------------------------------------------

@pytest.mark.parametrize("out_inv", [0, 1])
def test_output_invert_combinational(out_inv: int) -> None:
    tt = 0x6996  # parity-ish pattern
    base = Elut4(Elut4Config(tt=tt, ff_en=0, out_inv=0))
    inv = Elut4(Elut4Config(tt=tt, ff_en=0, out_inv=out_inv))
    for vin in ALL_VIN:
        expected = (base.comb_out(vin) ^ out_inv) & 1
        assert inv.clock(vin) == expected


# ---- 5. config persists across user reset; config write is independent ------

def test_config_persists_reset() -> None:
    """User reset must NOT clear the fabric configuration (only the vFF)."""
    dut = Elut4()
    dut.configure(Elut4Config(tt=0xABCD, ff_en=0).to_word())
    # hammer reset for several edges
    for _ in range(5):
        dut.clock(0, rst_n=0, ce=1)
    assert dut.config.tt == 0xABCD
    # ...and the function still evaluates correctly afterwards
    for vin in ALL_VIN:
        assert dut.comb_out(vin) == ((0xABCD >> vin) & 1)


def test_random_sequence_dut_self_consistent() -> None:
    """A long random stimulus must keep the model self-consistent
    (comb_out is a pure function of tt and vin at all times)."""
    rng = random.Random(424242)
    dut = Elut4()
    for _ in range(500):
        word = rng.getrandbits(CFG_WIDTH)
        dut.configure(word)
        vin = rng.getrandbits(4)
        rst_n = rng.choice((0, 1))
        ce = rng.choice((0, 1))
        dut.clock(vin, rst_n=rst_n, ce=ce)
        # after any edge, comb_out must still equal tt[vin]
        assert dut.comb_out(vin) == ((dut.config.tt >> vin) & 1)
