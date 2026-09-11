`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dram_ctrl
// Description: SoC-facing DRAM socket — the ONLY path from the SoC to DRAM is
//              this standard AXI4 memory-slave interface (S15 §4 / ADR-018 §4).
//              The implementation behind it is per-target and swappable.
// Details:     THE SEAM (ADR-017 inference-first; S15 §4 "封装式 DRAM 组件").
//              The implementation module is selected at BUILD time by the file
//              list + one define — never by a parameter (a parameter cannot
//              select a module without elaborating a module that may not exist):
//
//                * DEFAULT (no define): `eth_dram_stub` — the behavioral AXI4
//                  memory (ADR-017 requires every DRAM implementation to ship a
//                  stub that is safe for Verilator, so the whole SoC simulates). This is
//                  the path used by `make lint`, `make test-sv`, Verilator and
//                  the open yosys/nextpnr chain.
//                * `-DETH_DRAM_VENDOR_GLUE`: `eth_dram_glue` — supplied by the
//                  per-target file list, exactly one provider per build:
//                    GW5  : ethereal-fabric/hal/gowin_gw5/glue/eth_dram_glue.sv
//                    Zynq : ethereal-fabric/hal/zynq/glue/eth_dram_glue.sv
//                  (both define `module eth_dram_glue`; a build that adds two
//                  providers fails to elaborate on purpose — that is the
//                  one-implementation-per-target rule made mechanical).
//
//              SEAM CONTRACT — the implementation module MUST provide, with
//              these EXACT names, (a) the parameters below and (b) the full
//              AXI4 slave channel set:
//
//                params : AXI_AW, AXI_DW, AXI_IDW, MEM_BASE, MEM_BYTES,
//                         RD_LATENCY, WR_LATENCY
//                AW     : s_axi_awvalid, s_axi_awready, s_axi_awaddr[AXI_AW],
//                         s_axi_awid[AXI_IDW], s_axi_awlen[7:0], s_axi_awsize[2:0],
//                         s_axi_awburst[1:0], s_axi_awcache[3:0], s_axi_awprot[2:0],
//                         s_axi_awqos[3:0], s_axi_awregion[3:0], s_axi_awlock
//                W      : s_axi_wvalid, s_axi_wready, s_axi_wdata[AXI_DW],
//                         s_axi_wstrb[AXI_DW/8], s_axi_wlast
//                B      : s_axi_bvalid, s_axi_bready, s_axi_bresp[1:0], s_axi_bid[AXI_IDW]
//                AR     : s_axi_arvalid, s_axi_arready, s_axi_araddr[AXI_AW],
//                         s_axi_arid[AXI_IDW], s_axi_arlen[7:0], s_axi_arsize[2:0],
//                         s_axi_arburst[1:0], s_axi_arcache[3:0], s_axi_arprot[2:0],
//                         s_axi_arqos[3:0], s_axi_arregion[3:0], s_axi_arlock
//                R      : s_axi_rvalid, s_axi_rready, s_axi_rdata[AXI_DW],
//                         s_axi_rresp[1:0], s_axi_rlast, s_axi_rid[AXI_IDW]
//                clock  : clk_i, rst_ni (async assert / sync release, active low)
//
//              The seam is deliberately AXI4-level, not a native DDR bus: both
//              real targets already present an AXI4 memory slave (Zynq US+ PS
//              DDR via an S_AXI_HP*_FPD port; the Gowin GW5 hard-DDR3
//              controller IP in its AXI4 mode), so the SoC sees one frozen
//              socket and no own-RTL ever learns a vendor bus. A future own DDR
//              controller (tapeout, S15 §4 row 3) binds to the same seam.
//
//              This module is a pure socket: it forwards the frozen parameter
//              surface and the complete AXI4 channel set and adds NO state, so
//              the socket's timing/response contract is exactly its
//              implementation's (the stub's documented policy is the reference:
//              eth_dram_stub.sv, "ERROR CONTRACT" / "TIMING").
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - created (E2-DRAM1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §4 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §4 (DRAM = wrapped
//              component, per-target HAL) · ADR-017 (inference-first, vendor
//              primitives only in hal/<vendor>/glue/ + always a Verilator stub) ·
//              ethereal-spec/control/eth-axi-v0.md §2 §3.1
// Notes:       SPEC GAP (found 2026-09-12, reported in the E2-DRAM1 notes): the
//              v0 slave-side port list of `eth_axi_xbar` carries no
//              AxLEN/AxSIZE/AxBURST/WLAST/RLAST (eth-axi-v0.md §5.2 defers
//              bursts to v0.1), so this full-AXI4 socket cannot yet be wired
//              behind the v0 crossbar — the burst channels exist here and in the
//              stub, and the crossbar's v0.1 burst extension is the missing
//              piece. Standalone (BMC/DMA/app-cluster direct, or via the v0.1
//              xbar) it is complete.
//              ASSUMPTION (TBD, 2026-09-12): MEM_BASE = 0x8000_0000 (no frozen
//              SoC memory map yet) — the integrating top sets the real window.
module eth_dram_ctrl #(
    parameter int AXI_AW     = 32,                 // AXI4 address width
    parameter int AXI_DW     = 64,                 // AXI4 data width (32/64)
    parameter int AXI_IDW    = 4,                  // AXI4 transaction ID width
    parameter logic [AXI_AW-1:0] MEM_BASE = 32'h8000_0000,  // window base (ASSUMPTION)
    parameter int MEM_BYTES  = 1 << 20,            // window size in bytes
    parameter int RD_LATENCY = 4,                  // AR -> first R beat latency
    parameter int WR_LATENCY = 2                   // last W beat -> B latency
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

    // ------------------------------------------------------------------
    // Backend selection (build-level; see the SEAM CONTRACT above).
    // ------------------------------------------------------------------
`ifdef ETH_DRAM_VENDOR_GLUE
    `define ETH_DRAM_IMPL eth_dram_glue
`else
    `define ETH_DRAM_IMPL eth_dram_stub
`endif

    `ETH_DRAM_IMPL #(
        .AXI_AW     (AXI_AW),
        .AXI_DW     (AXI_DW),
        .AXI_IDW    (AXI_IDW),
        .MEM_BASE   (MEM_BASE),
        .MEM_BYTES  (MEM_BYTES),
        .RD_LATENCY (RD_LATENCY),
        .WR_LATENCY (WR_LATENCY)
    ) u_impl (
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

`undef ETH_DRAM_IMPL

endmodule

`default_nettype wire
