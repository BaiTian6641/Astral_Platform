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
//              The vendored core is rv32imc + IMEM(16KB ROM-boot) + DMEM(16KB) +
//              UART0 + **XBUS (Wishbone master)**. This wrapper instantiates the
//              in-house `eth_wb2axi` bridge (Wishbone -> AXI4-Lite master) so the
//              BMC drives the in-house `eth_axi` fabric as a first-class AXI
//              master (ADR-018 BMC integration). The AXI master channels are
//              exposed on this port set for the SoC/xbar to consume.
//
//              XBUS = the NEORV32 "void": any access outside IMEM(0x00000000) /
//              DMEM(0x80000000) / IO(0xFFE00000+) routes to XBUS (see the report
//              docs/reports/report-P1-bmc-axi-bridge-20260808.md for the window).
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Modified:    2026-08-08 - enable XBUS, add eth_wb2axi AXI master bridge
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C05-BMC组件.md §1 (ADR-016 swappable core);
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md (BMC = AXI master)
// Notes:       neorv32_verilog_wrapper is a generated vendor netlist (BSD-3); it
//              is NOT part of the G1 lint gate (see Makefile / README.md). Only
//              THIS wrapper + eth_wb2axi are G1-clean. The XBUS cti/tag outputs
//              are unused (classic single transfers only) — documented waiver.
module bmc_core #(
    parameter int AXI_AW = 32,             // AXI address width
    parameter int AXI_DW = 32              // AXI data width (v0 = 32)
) (
    input  wire logic clk_i,        // global clock, rising edge
    input  wire logic rst_ni,       // global reset, low-active (async in core)
    // UART0 (host console / hello path) --
    output logic      uart0_txd_o,  // UART0 transmit data
    input  wire logic uart0_rxd_i,  // UART0 receive data
    // AXI4 master (to the eth_axi fabric / xbar) --
    // AW
    output logic                  m_axi_awvalid,
    input  wire logic             m_axi_awready,
    output logic [AXI_AW-1:0]     m_axi_awaddr,
    output logic [2:0]            m_axi_awprot,
    // W
    output logic                  m_axi_wvalid,
    input  wire logic             m_axi_wready,
    output logic [AXI_DW-1:0]     m_axi_wdata,
    output logic [(AXI_DW/8)-1:0] m_axi_wstrb,
    // B
    input  wire logic             m_axi_bvalid,
    output logic                  m_axi_bready,
    input  wire logic [1:0]       m_axi_bresp,
    // AR
    output logic                  m_axi_arvalid,
    input  wire logic             m_axi_arready,
    output logic [AXI_AW-1:0]     m_axi_araddr,
    output logic [2:0]            m_axi_arprot,
    // R
    input  wire logic             m_axi_rvalid,
    output logic                  m_axi_rready,
    input  wire logic [AXI_DW-1:0] m_axi_rdata,
    input  wire logic [1:0]       m_axi_rresp,
    // Status / debug --
    // verilator lint_off UNUSEDSIGNAL
    input  wire logic dbg_en_i,     // reserved: on-chip-debugger enable (unused, OCD off)
    // verilator lint_on UNUSEDSIGNAL
    output logic      heartbeat_o   // core-alive status (tied to reset for now)
);

    assign heartbeat_o = rst_ni;

    // ------------------------------------------------------------------
    // XBUS (Wishbone) wires between the vendored core and the WB->AXI bridge.
    // ------------------------------------------------------------------
    logic [31:0]        xbus_adr;
    logic [31:0]        xbus_dat_o;   // core write data -> bridge
    logic [31:0]        xbus_dat_i;   // bridge read data -> core
    logic               xbus_we;
    logic [3:0]         xbus_sel;
    logic               xbus_stb;
    logic               xbus_cyc;
    logic               xbus_ack;
    logic               xbus_err;
    // cti/tag are pass-through-ignored by the bridge (classic transfers only).
    logic [2:0]         xbus_cti;
    logic [2:0]         xbus_tag;

    // dbg_en_i is intentionally unused (OCD_EN=false): fold into a reduction so
    // -Wall stays clean (documented waiver; pin reserved for the v1 debug core).
    // verilator lint_off UNUSEDSIGNAL
    logic unused_ok;
    assign unused_ok = &{1'b0, dbg_en_i, xbus_cti, xbus_tag};
    // verilator lint_on UNUSEDSIGNAL

    // ------------------------------------------------------------------
    // NEORV32 (vendored, GHDL-converted). Active-low reset matches directly.
    // XBUS_EN=true in the vendored config -> the XBUS master ports are live.
    // ------------------------------------------------------------------
    neorv32_verilog_wrapper u_core (
        .clk_i       (clk_i),
        .rstn_i      (rst_ni),
        .uart0_txd_o (uart0_txd_o),
        .uart0_rxd_i (uart0_rxd_i),
        .xbus_adr_o  (xbus_adr),
        .xbus_dat_o  (xbus_dat_o),
        .xbus_cti_o  (xbus_cti),
        .xbus_tag_o  (xbus_tag),
        .xbus_we_o   (xbus_we),
        .xbus_sel_o  (xbus_sel),
        .xbus_stb_o  (xbus_stb),
        .xbus_cyc_o  (xbus_cyc),
        .xbus_dat_i  (xbus_dat_i),
        .xbus_ack_i  (xbus_ack),
        .xbus_err_i  (xbus_err)
    );

    // ------------------------------------------------------------------
    // In-house Wishbone -> AXI4-Lite master bridge (BMC = AXI master, ADR-018).
    // ------------------------------------------------------------------
    eth_wb2axi #(.AXI_AW(AXI_AW), .AXI_DW(AXI_DW)) u_wb2axi (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .wb_adr_i       (xbus_adr),
        .wb_dat_i       (xbus_dat_o),
        .wb_dat_o       (xbus_dat_i),
        .wb_we_i        (xbus_we),
        .wb_sel_i       (xbus_sel),
        .wb_stb_i       (xbus_stb),
        .wb_cyc_i       (xbus_cyc),
        .wb_ack_o       (xbus_ack),
        .wb_err_o       (xbus_err),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awprot   (m_axi_awprot),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arprot   (m_axi_arprot),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp)
    );

endmodule
`default_nettype wire
