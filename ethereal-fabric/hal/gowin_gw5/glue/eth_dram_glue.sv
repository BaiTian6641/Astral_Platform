`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dram_glue  (GW5 provider)
// Description: Gowin GW5 DRAM backend for the `eth_dram_ctrl` socket — the
//              ADR-017 vendor-glue slot for the GW5 hard-DDR3 PHY+controller IP.
// Details:     SEAM (see eth_dram_ctrl.sv "SEAM CONTRACT"): this module provides
//              GW5 provider of the DRAM seam (file name == module name; the vendor
//              directory selects the provider). Provides exactly the parameter
//              list and full AXI4 slave channel set of the
//              socket's default implementation, so `eth_dram_ctrl` can bind it
//              by defining ETH_DRAM_VENDOR_GLUE. Exactly ONE file on a build's
//              file list may define `eth_dram_glue`; adding two providers fails
//              elaboration on purpose (one DRAM implementation per target).
//
//              DEFAULT branch (no GOWIN_PRIMITIVE) = the ADR-017 Verilator-safe
//              stub: the GW5 DDR3 controller is a NON-INFERABLE vendor hard
//              block, so every simulation / open-chain build (Verilator, iverilog,
//              yosys+nextpnr) binds the behavioral AXI4 memory `eth_dram_stub`
//              here. That is what lets the whole SoC simulate on a GW5 target
//              without the hard IP (S15 §4, ADR-018 §4 row 2). The file list must
//              therefore also carry ethereal-shell/rtl/dram/eth_dram_stub.sv.
//
//              GOWIN_PRIMITIVE branch = documentation-in-code ONLY (G6): the
//              GW5A DDR3 Memory Interface in AXI4 mode is instantiated there in
//              the Gowin-EDA build. Its real integration — DDR3 pin assignment,
//              DQS read training, DFI/PHY timing closure, calibration, refresh —
//              is a HARDWARE BRING-UP task on the physical Tang Mega 138K and is
//              explicitly NOT part of E2-DRAM1 (S15 §4: "GW5 hard-DDR3 封装是硬件
//              bring-up 任务"; before that bring-up the GW5 app cluster runs the
//              no-DDR profile: BootROM + on-chip SRAM + optional SPI-flash/PSRAM).
//
//              Vendor specifics therefore live ONLY in this file (ADR-017 /
//              C13 §4 exception zone); the socket and the stub are vendor-free.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - created (E2-DRAM1)
// Tags:        HAL-GLUE, SIM-STUB
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §4 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §4 (DRAM = wrapped
//              per-target component) · ADR-017 (inference-first; vendor
//              primitives only in hal/<vendor>/glue/, always with a stub)
// Notes:       ASSUMPTION (TBD, 2026-09-12): Gowin's GW5A DDR3 controller in
//              AXI4 mode exposes an AXI4 slave of the GW5A DDR3 IP family
//              (primitive/module spellings to be verified against the licensed
//              Gowin primitive library before a GOWIN_PRIMITIVE build exists).
//              ASSUMPTION (TBD, 2026-09-12): the GW5A DDR3 AXI4 port's ID width
//              and burst support match this socket's AXI_IDW/AxLEN range; any
//              adaptation (ID narrowing, burst splitting) belongs in THIS file,
//              never in the shell socket or the stub.
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

`ifdef GOWIN_PRIMITIVE
    // ------------------------------------------------------------------
    // Gowin-EDA build branch — NOT compiled by the default/open chain.
    //
    // Reference instantiation shape (G6: verify the GW5A DDR3 AXI4 controller's
    // module/primitive name, its parameter spellings, its AXI ID width and its
    // burst/AxSIZE support against the licensed Gowin primitive library before
    // enabling this branch; ASSUMPTION (TBD, 2026-09-12)):
    //
    //   GOWIN_DDR3_AXI4 #(
    //       .AXI_ADDR_WIDTH (AXI_AW),
    //       .AXI_DATA_WIDTH (AXI_DW),
    //       .AXI_ID_WIDTH   (AXI_IDW)
    //   ) u_ddr3_axi4 (
    //       .clk_i(clk_i), .rst_ni(rst_ni),
    //       .s_axi_awvalid(s_axi_awvalid), ... /* full AXI4 slave channel set */
    //   );
    //
    // The real block additionally needs: DDR3 pin LOC constraints, the DDR3
    // reset/clocking network (see gowin_clkstub.sv), DQS read training and the
    // Gowin EDA calibration flow — a configuration-time hardware bring-up task,
    // not RTL.
    //
    // Commented reference only — enabling the define today fails at elaboration /
    // time-0 on purpose:
    initial begin
        // NOTE: a single-line literal on purpose — iverilog 14 renders a
        // '+' concatenated string argument of $error as a number, hiding the
        // message (the same pattern in gowin_clkstub.sv hits this).
        $error("gowin_gw5/glue/eth_dram_glue: GOWIN_PRIMITIVE branch is documentation-in-code only; GW5A DDR3 AXI4 controller bindings and the board pinout are pending G6 verification plus the S15 sec4 hardware bring-up task (2026-09-12); build without -DGOWIN_PRIMITIVE (behavioral stub path).");
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
    // The GW5 target is exercised end-to-end by binding the same behavioral
    // AXI4 memory the vendor-free path uses.
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
