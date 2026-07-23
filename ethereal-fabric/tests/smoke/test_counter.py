"""cocotb smoke test for `counter.sv` (task E0-INF3).

SPDX-License-Identifier: MIT
Plan-Ref: ethereal-plan/subsystems/S14-验证与CI基础设施.md §3 (E0-INF3 smoke)

Purpose
-------
Prove the `ethereal-sim` image end-to-end: Verilator compiles the RTL and
cocotb drives a clock + reset and checks the 8-bit counter increments by one
each cycle (wrapping 0xFF -> 0x00). This is the minimum viable regression for
the CI gate (task E0-INF2) before any real fabric RTL lands (E0-FAB1..6).

Run
---
    make -C ethereal-fabric/tests/smoke sim SIM=verilator
or, via the root Makefile:
    make sim
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_counter_increments_after_reset(dut):
    """After sync reset deasserts, count_o increments by 1 each rising edge."""
    # Start a 10 ns-period clock in the background. Requires Verilator
    # `--timing` (passed via EXTRA_ARGS in this dir's Makefile).
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    # Hold reset low across the first rising edge so the sync reset path clears
    # the count before we start checking increments.
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    got = int(dut.count_o.value)
    assert got == 0, f"count not zeroed by reset: got {got}"

    # Deassert reset; from here each rising edge must add 1 (mod 256).
    dut.rst_ni.value = 1
    expected = 0
    for _ in range(64):
        await RisingEdge(dut.clk_i)
        expected = (expected + 1) & 0xFF
        got = int(dut.count_o.value)
        assert got == expected, f"increment mismatch: expected {expected}, got {got}"


@cocotb.test()
async def test_counter_wraps_at_255(dut):
    """Force the count near the top of the range and confirm it wraps to 0."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())

    # Reset to a known 0.
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    assert int(dut.count_o.value) == 0

    # Run 256 cycles -> back to 0 (wrap). 257th cycle would be 1.
    dut.rst_ni.value = 1
    for _ in range(256):
        await RisingEdge(dut.clk_i)
    got = int(dut.count_o.value)
    assert got == 0, f"counter did not wrap after 256 cycles: got {got}"
