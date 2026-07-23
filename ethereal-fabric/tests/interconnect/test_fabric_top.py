# SPDX-License-Identifier: MIT
"""cocotb test for fabric_top.sv (task E0-FAB3). Docker-gated (ethereal-sim).

Run:  make -C ethereal-fabric/tests/interconnect sim TOPLEVEL=fabric_top MODULE=test_fabric_top

Purpose: prove the 4x4 grid ELABORATES and clocks without hanging (the
"instantiates" half of the E0-FAB3 acceptance). The "no comb loop" property is
verified at the graph level by fabric_model.py locally; Verilator's structural
UNOPTFLAT check (potential routing rings) is the Docker-gated complement.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_fabric_4x4_elaborates_and_clocks(dut):
    """The 4x4 fabric must elaborate and clock without hanging (no osc loop)."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.cfg_we_i.value = 0
    dut.cfg_addr_i.value = 0
    dut.cfg_data_i.value = 0
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)
    # Clock the whole grid; if the default config had a functional comb loop,
    # a 2-state simulator would not settle — completion of this loop is the check.
    for _ in range(32):
        await RisingEdge(dut.clk_i)
    _ = int(dut.clb_out_obs_o.value)  # read flattens; value may be X pre-config
