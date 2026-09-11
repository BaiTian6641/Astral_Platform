`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dram_glue  (Zynq provider)
// Description: Zynq UltraScale+ DRAM backend for the `eth_dram_ctrl` socket —
//              the HAL binding to the PS DDR exposed through a PS AXI slave port.
// Details:     SEAM (see eth_dram_ctrl.sv "SEAM CONTRACT"): this module provides
//              Zynq provider of the DRAM seam (file name == module name; the vendor
//              directory selects the provider). Provides exactly the parameter
//              list and full AXI4 slave channel set of the
//              socket's default implementation, so `eth_dram_ctrl` can bind it
//              by defining ETH_DRAM_VENDOR_GLUE. Exactly ONE file on a build's
//              file list may define `eth_dram_glue`; adding two providers fails
//              elaboration on purpose (one DRAM implementation per target).
//
//              WHY THE SEAM IS ALREADY AXI4-LEVEL HERE: on Zynq US+ the PL reaches
//              DDR through the PS's own AXI slave ports (S_AXI_HP*_FPD / HPC), i.e.
//              the vendor memory IS an AXI4 memory slave from our side of the
//              boundary. So the Zynq DRAM "implementation" is a PORT BINDING, not
//              an RTL block: the block design connects the PS AXI slave port to
//              this socket. Everything that must still be RTL — AXI ID-width
//              adaptation (the PS port's ID width is a block-design parameter that
//              need not equal AXI_IDW), response remapping, or burst splitting for
//              a narrowed PS port — belongs in THIS file, never in the shell
//              socket or the behavioral stub.
//
//              DEFAULT branch (no XILINX_PS_DDR) = the ADR-017 Verilator-safe
//              stub: binds the behavioral AXI4 memory `eth_dram_stub`, so a Zynq
//              target's whole SoC simulates without the PS (and the open
//              yosys/nextpnr chain stays vendor-free). The file list must also
//              carry ethereal-shell/rtl/dram/eth_dram_stub.sv.
//              XILINX_PS_DDR branch = documentation-in-code ONLY (G6): the real
//              binding happens in the Vivado block design (PS + this socket as an
//              AXI slave) together with the DDR MC configuration and the board's
//              PS DDR pinout — a HARDWARE BRING-UP task, not part of E2-DRAM1.
//              (There is deliberately no vendor primitive here: the PS is instantiated
//              by the block design, not by our RTL, and ADR-017 forbids vendor IP in
//              own RTL — this file only ever documents the binding + any adaptation.)
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - created (E2-DRAM1)
// Tags:        HAL-GLUE, SIM-STUB
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §4 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §4 (DRAM = wrapped
//              per-target component) · ADR-017 (inference-first; vendor
//              specifics only in hal/<vendor>/glue/, always with a stub)
// Notes:       ASSUMPTION (TBD, 2026-09-12): the exact Zynq US+ board model and its
//              PS DDR configuration are still open (docs/ARCHITECTURE-OVERVIEW §9,
//              memory/04-roadmap-phases.md open questions). Until the board is
//              confirmed, MEM_BASE/MEM_BYTES and the PS port's AXI ID width are
//              socket parameters to be set by the integrating top, and the DDR
//              window must match the block design's PS address map.
module eth_dram_glue #(
    parameter int AXI_AW     = 32,
    parameter int AXI_DW     = 64,
    parameter int AXI_IDW    = 4,
    parameter logic [AXI_AW-1:0] MEM_BASE = 32'h8000_0000,
    parameter int MEM_BYTES  = 1 << 20,
    parameter int RD_LATENCY = 4,
    parameter int WR_LATENCY = 2
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- AXI4 write address channel (AW) ----
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    input  logic [AXI_AW-1:0]       s_axi_awaddr,
    input  logic [AXI_IDW-1:0]      s_axi_awid,
    input  logic [7:0]              s_axi_awlen,
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,
    input  logic [3:0]              s_axi_awcache,
    input  logic [2:0]              s_axi_awprot,
    input  logic [3:0]              s_axi_awqos,
    input  logic [3:0]              s_axi_awregion,
    input  logic                    s_axi_awlock,
    // ---- AXI4 write data channel (W) ----
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic [AXI_DW-1:0]       s_axi_wdata,
    input  logic [AXI_DW/8-1:0]     s_axi_wstrb,
    input  logic                    s_axi_wlast,
    // ---- AXI4 write response channel (B) ----
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    output logic [1:0]              s_axi_bresp,
    output logic [AXI_IDW-1:0]      s_axi_bid,
    // ---- AXI4 read address channel (AR) ----
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    input  logic [AXI_AW-1:0]       s_axi_araddr,
    input  logic [AXI_IDW-1:0]      s_axi_arid,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,
    input  logic [3:0]              s_axi_arcache,
    input  logic [2:0]              s_axi_arprot,
    input  logic [3:0]              s_axi_arqos,
    input  logic [3:0]              s_axi_arregion,
    input  logic                    s_axi_arlock,
    // ---- AXI4 read data channel (R) ----
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic [AXI_DW-1:0]       s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic [AXI_IDW-1:0]      s_axi_rid
);

`ifdef XILINX_PS_DDR
    // ------------------------------------------------------------------
    // Vivado block-design branch — NOT compiled by the default/open chain.
    //
    // There is no primitive to instantiate here: the PS is created by the block
    // design and our socket is connected as an AXI4 slave of a PS port. The
    // bring-up work is (G6 — verify against the confirmed board model):
    //   1. Block design: Zynq US+ PS with an S_AXI_HP*_FPD/HPC port enabled;
    //      set the PS port's data width (64) and ID width; enable the DDR MC
    //      (DDR4/LPDDR4) with the board's DDR parameters.
    //   2. Address map: place MEM_BASE/MEM_BYTES of this socket inside the PS DDR
    //      window (a PS port is addressed in the PL's address space).
    //   3. If the PS port's ID width != AXI_IDW, insert the ID adaptation HERE
    //      (widen on the request side, mask/narrow on B/R), never in the socket.
    //   4. Constraints: PS DDR pinout comes from the board preset; no PL LOC
    //      constraints for DDR.
    // This is a hardware bring-up task (S15 §4 / ADR-018 §4 row 1), out of scope
    // for E2-DRAM1.
    //
    // Deliberately fails at elaboration / time-0 so a mis-set define is loud:
    initial begin
        // NOTE: a single-line literal on purpose — iverilog 14 renders a
        // '+' concatenated string argument of $error as a number, hiding the
        // message (the same pattern in gowin_clkstub.sv hits this).
        $error("zynq/glue/eth_dram_glue: XILINX_PS_DDR branch is documentation-in-code only; the Zynq DRAM binding is a Vivado block-design task on the confirmed board model plus the S15 sec4 hardware bring-up (2026-09-12); build without -DXILINX_PS_DDR (behavioral stub path).");
    end
    assign s_axi_awready = 1'b0;
    assign s_axi_wready  = 1'b0;
    assign s_axi_bvalid  = 1'b0;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bid     = {AXI_IDW{1'b0}};
    assign s_axi_arready = 1'b0;
    assign s_axi_rvalid  = 1'b0;
    assign s_axi_rdata   = {AXI_DW{1'b0}};
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = 1'b0;
    assign s_axi_rid     = {AXI_IDW{1'b0}};
`else
    // ------------------------------------------------------------------
    // DEFAULT branch — ADR-017 behavioral stub (simulation + open chain).
    // ------------------------------------------------------------------
    eth_dram_stub #(
        .AXI_AW     (AXI_AW),
        .AXI_DW     (AXI_DW),
        .AXI_IDW    (AXI_IDW),
        .MEM_BASE   (MEM_BASE),
        .MEM_BYTES  (MEM_BYTES),
        .RD_LATENCY (RD_LATENCY),
        .WR_LATENCY (WR_LATENCY)
    ) u_stub (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awid     (s_axi_awid),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awcache  (s_axi_awcache),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awqos    (s_axi_awqos),
        .s_axi_awregion (s_axi_awregion),
        .s_axi_awlock   (s_axi_awlock),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bid      (s_axi_bid),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arid     (s_axi_arid),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arcache  (s_axi_arcache),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arqos    (s_axi_arqos),
        .s_axi_arregion (s_axi_arregion),
        .s_axi_arlock   (s_axi_arlock),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rid      (s_axi_rid)
    );
`endif

endmodule

`default_nettype wire
