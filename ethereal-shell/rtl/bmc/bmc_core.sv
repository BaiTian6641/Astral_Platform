`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      bmc_core
// Description: ADR-016 swappable BMC core boundary wrapping the vendored NEORV32.
// Details:     Thin SystemVerilog wrapper around the GHDL-converted
//              `neorv32_verilog_wrapper` (see neorv32_verilog_wrapper.v in this
//              directory). This module is the swappable `bmc_core` boundary of
//              ADR-016: the SoC glue outside must depend only on this port set,
//              never on the underlying core, so NEORV32 (primary) can be replaced
//              by VexRiscv (fallback) without touching the rest of the Shell.
//
//              v0 SKELETON: the vendored core is configured MINIMAL (rv32imc +
//              IMEM 16KB ROM-boot + DMEM 16KB + UART0 only, BOOT_MODE_SELECT=2).
//              Only the UART0 TX/RX plus clock/reset are exposed. All future BMC
//              services (XBUS/EBI master to EMRI, SPI/I2C monitors, DMA, debug)
//              are intentionally NOT wired yet — the reserved pins below are tied
//              off / left unconnected on purpose and documented as ASSUMPTIONs in
//              the report (docs/reports/report-P1-bmc-neorv32-sim-20260730.md).
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Modified:    2026-07-30 - initial skeleton (NEORV32 vendored netlist)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C05-BMC组件.md §1 (ADR-016 swappable core)
// Notes:       neorv32_verilog_wrapper is a generated vendor netlist (BSD-3); it
//              is NOT part of the G1 lint gate (see Makefile / README.md). Only
//              THIS wrapper is G1-clean. The unused-output waivers below are for
//              the reserved pins that the minimal core does not yet drive.
module bmc_core (
    input  wire logic clk_i,        // global clock, rising edge
    input  wire logic rst_ni,       // global reset, low-active (async in core)
    // UART0 (host console / hello path) --
    output logic      uart0_txd_o,  // UART0 transmit data
    input  wire logic uart0_rxd_i,  // UART0 receive data
    // Reserved bus / debug pins (tied off for the v0 skeleton) --
    // verilator lint_off UNUSEDSIGNAL
    input  wire logic dbg_en_i,     // reserved: on-chip-debugger enable (unused, OCD off)
    output logic      bus_req_o,    // reserved: external bus request strobe (unused, XBUS off)
    // verilator lint_on UNUSEDSIGNAL
    output logic      heartbeat_o   // reserved: core-alive status (tied to reset for now)
);

    // ------------------------------------------------------------------
    // Reserved outputs: tied off for the minimal skeleton.
    // The XBUS/EBI master and OCD are disabled in the vendored core, so the
    // external bus request never asserts; heartbeat follows "out of reset".
    // ------------------------------------------------------------------
    assign bus_req_o   = 1'b0;
    assign heartbeat_o = rst_ni;

    // ------------------------------------------------------------------
    // NEORV32 (vendored, GHDL-converted). Active-low reset matches directly.
    // The vendored wrapper's rstn_i is low-active & async -> rst_ni drives it.
    // dbg_en_i is intentionally unused in the v0 skeleton: the minimal core is
    // built with OCD_EN=false, so it has no debug input to drive (documented
    // waiver; the pin is reserved for the v1 debug-enabled core).
    // ------------------------------------------------------------------
    // verilator lint_off UNUSEDSIGNAL
    logic dbg_unused;
    // verilator lint_on UNUSEDSIGNAL
    assign dbg_unused = dbg_en_i;

    neorv32_verilog_wrapper u_core (
        .clk_i       (clk_i),
        .rstn_i      (rst_ni),
        .uart0_txd_o (uart0_txd_o),
        .uart0_rxd_i (uart0_rxd_i)
    );

endmodule
`default_nettype wire
