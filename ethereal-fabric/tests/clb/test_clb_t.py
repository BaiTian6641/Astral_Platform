# SPDX-License-Identifier: MIT
"""cocotb test for clb_t.sv vs the golden model (task E0-FAB2).

Docker-gated: requires the ethereal-sim image (Verilator + cocotb).
Run:  make -C ethereal-fabric/tests/clb sim TOPLEVEL=clb_t MODULE=test_clb_t

Strategy: configure every LUT input from an EXTERNAL source (acyclic by
construction -> no combinational loop, deterministic settle), then drive random
external inputs + reset and compare clb_out_o to a cycle-locked ClbT model. On
every clock edge the model is advanced (so the eLUT FFs — which in the DUT update
every edge since cfg_ce_i is tied high at CLB level — stay in lockstep); config
registers are applied AFTER the edge (matching non-blocking update in the DUT).
"""
from __future__ import annotations

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from clb_t_model import ClbT

N, K, EXT = 8, 4, 18
N_STIM = 200


def _word(bits: int) -> int:
    return bits & 0xFFFFF


@cocotb.test()
async def test_clb_t_vs_golden_model(dut):
    """Acyclic-config CLB: DUT clb_out matches the golden model over 200 cycles."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    rng = random.Random(0xC1B7)  # "C L B"
    model = ClbT(N, K, EXT)

    dut.cfg_we_i.value = 0
    dut.cfg_addr_i.value = 0
    dut.cfg_data_i.value = 0
    dut.clb_in_i.value = 0
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    model.clock(0, rst_n=1)
    await RisingEdge(dut.clk_i)
    model.clock(0, rst_n=1)

    # ---- configuration: each LUT input from a random EXTERNAL source (acyclic) ----
    for i in range(N):
        word = _word(rng.getrandbits(20))
        dut.cfg_we_i.value = 1
        dut.cfg_addr_i.value = i
        dut.cfg_data_i.value = word
        dut.clb_in_i.value = 0
        dut.rst_ni.value = 1
        await RisingEdge(dut.clk_i)
        model.clock(0, rst_n=1)      # FFs advance (old config); cfg regs update below
        model.configure(i, word)
        for k in range(K):
            src = rng.randrange(EXT)
            addr = N + i * K + k
            dut.cfg_addr_i.value = addr
            dut.cfg_data_i.value = src
            await RisingEdge(dut.clk_i)
            model.clock(0, rst_n=1)
            model.configure(addr, src)

    # ---- one cfg_we=0 edge to settle post-config state ----
    dut.cfg_we_i.value = 0
    dut.clb_in_i.value = 0
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    model.clock(0, rst_n=1)

    # ---- functional stimulus: compare clb_out each cycle ----
    for t in range(N_STIM):
        ext = rng.getrandbits(EXT)
        rst_n = rng.choice((0, 1))
        dut.cfg_we_i.value = 0
        dut.clb_in_i.value = ext
        dut.rst_ni.value = rst_n
        await RisingEdge(dut.clk_i)
        expected = model.clock(ext, rst_n=rst_n)
        exp_word = sum((b & 1) << idx for idx, b in enumerate(expected))
        got = int(dut.clb_out_o.value)
        assert got == exp_word, (
            f"cycle {t}: ext=0x{ext:05x} rst_n={rst_n}: "
            f"DUT clb_out=0x{got:02x} != model 0x{exp_word:02x}"
        )
