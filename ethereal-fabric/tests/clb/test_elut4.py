# SPDX-License-Identifier: MIT
"""cocotb test for elut4.sv vs the golden model (task E0-FAB1).

Docker-gated: requires the ethereal-sim image (Verilator + cocotb).
Run:  make -C ethereal-fabric/tests/clb test SIM=verilator   (inside ethereal-sim)

Strategy: drive the DUT and a cycle-locked golden model (elut4_model.Elut4) with
identical random stimulus and assert ``dut.vout_o == model`` after every
non-configuration edge. During a cfg_we edge the output is UNDEFINED by design
(OCC blanks the region during configuration, C01 §1.4), so we do not compare on
that edge — but we still advance the model so its ``vff`` stays in lockstep with
the DUT (the DUT's vff samples the *old* config on that same edge).
"""
from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from elut4_model import Elut4

N_CONFIGS = 1000


def _drive(dut, vin: int, rst_n: int, ce: int, cfg_we: int, word: int) -> None:
    """Apply stimulus for the upcoming edge (call before awaiting the edge)."""
    dut.vin_i.value = vin
    dut.rst_ni.value = rst_n
    dut.cfg_ce_i.value = ce
    dut.cfg_we_i.value = cfg_we
    if cfg_we:
        dut.cfg_data_i.value = word


@cocotb.test()
async def test_elut4_vs_golden_model(dut):
    """1000 random configs × random stimulus: DUT matches the golden model."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    rng = random.Random(0xE1F4)  # "E LUT 4"
    model = Elut4()

    # ---- init: load config=0, sync the model, define vff (kill X-propagation) ----
    _drive(dut, vin=0, rst_n=1, ce=1, cfg_we=1, word=0)
    await RisingEdge(dut.clk_i)
    model.clock(0, rst_n=1, ce=1)   # vff advances with old (default) config
    model.configure(0)              # config -> 0, matching the DUT post-edge
    _drive(dut, vin=0, rst_n=1, ce=1, cfg_we=0, word=0)
    await RisingEdge(dut.clk_i)
    model.clock(0, rst_n=1, ce=1)   # vff -> 0, now fully defined

    # ---- randomized config + stimulus loop ----
    for i in range(N_CONFIGS):
        word = rng.getrandbits(20)
        vin, rst_n, ce = rng.getrandbits(4), rng.choice((0, 1)), rng.choice((0, 1))

        # configuration edge: output undefined, but keep model vff in lockstep
        model.clock(vin, rst_n=rst_n, ce=ce)   # vff uses OLD config (matches DUT)
        model.configure(word)                   # switch to NEW config (matches DUT)
        _drive(dut, vin, rst_n, ce, cfg_we=1, word=word)
        await RisingEdge(dut.clk_i)

        # functional edges: compare DUT vout to the model
        for _ in range(rng.randint(1, 4)):
            vin = rng.getrandbits(4)
            rst_n = rng.choice((0, 1))
            ce = rng.choice((0, 1))
            _drive(dut, vin, rst_n, ce, cfg_we=0, word=0)
            await RisingEdge(dut.clk_i)
            expected = model.clock(vin, rst_n=rst_n, ce=ce)
            got = int(dut.vout_o.value)
            assert got == expected, (
                f"iter {i} word=0x{word:05x} vin={vin:04b} "
                f"rst_n={rst_n} ce={ce}: DUT vout={got} != model {expected}"
            )
