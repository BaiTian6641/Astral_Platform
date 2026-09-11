`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_axi_xbar_burst (testbench, self-checking)
// Description: E2-AXI2 acceptance TB — AXI4 INCR bursts through `eth_axi_xbar`
//              (BURST_EN=1) into the REAL DRAM socket chain
//              (`eth_dram_ctrl` + `eth_dram_stub`), checked PER BEAT against a
//              DIRECT connection of the same master to an identically
//              configured DRAM socket (the baseline) and against a TB-local
//              reference memory.
// Details:     Two independent DRAM sockets hold identical images:
//                * `u_dram_d` — master 0 wired straight to the socket (the
//                  v0.1 "direct connect" baseline, eth-axi-v0.md §9.6);
//                * `u_dram_x` — behind `u_xbar` (1 master x 1 slave + the
//                  built-in DECERR slave), which is what this task adds.
//              One master BFM (`drv_*`, master-indexed) drives whichever path
//              `sel` selects, so every stage runs the SAME stimulus twice and
//              the two runs are compared beat-by-beat:
//                1. memory init sweep (full-width INCR bursts) + reference
//                   memory, so every later read is a defined value;
//                2. single-beat (AxLEN=0) and multi-beat INCR bursts
//                   (len 1/3/7/15/63, size 0..3, unaligned starts, AXI4
//                   aligned-address rule) — write then read on both paths,
//                   per-beat RDATA/RRESP/RLAST/RID + BRESP/BID comparison;
//                3. W/R backpressure inside a burst (beat gaps + RREADY stalls);
//                4. error traffic through the same path: DECERR (unmapped ->
//                   the xbar's built-in error slave vs the DRAM window check),
//                   SLVERR (AxBURST=WRAP) and a 4 KiB-crossing burst — the two
//                   paths must agree on code AND on the beat shape
//                   (DECERR read = one beat, RDATA=0, RLAST=1; §5.3 / §9.4);
//                5. a second master (xbar-only, master index 1) running its own
//                   burst concurrently with master 0 into the same DRAM window
//                   — nonzero xid prefix/strip for bursts + per-destination
//                   lock-step spanning a whole burst (the write engine is
//                   single-outstanding, so the xbar must serialize them).
//              The master ID is non-zero (4'h5 / 4'h3) everywhere so the
//              response-ID strip is exercised on both the direct path (IDW=4)
//              and the xbar path (slave-side IDW=5 = {mst_idx, orig_id}).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §5 (crossbar), §5.2 (v0.1
//              bursts), §5.3 (decode-error slave), §9 (DRAM socket contract);
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §4
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              Run:
//                iverilog -g2012 -o /tmp/tb_xbar_burst \
//                  ethereal-shell/rtl/axi/eth_axi_skidbuf.sv \
//                  ethereal-shell/rtl/axi/eth_axi_xbar.sv \
//                  ethereal-shell/rtl/dram/eth_dram_stub.sv \
//                  ethereal-shell/rtl/dram/eth_dram_ctrl.sv \
//                  ethereal-fabric/tests/axi/tb_axi_xbar_burst.sv && \
//                vvp /tmp/tb_xbar_burst
`timescale 1ns/1ps
module tb_axi_xbar_burst;

    // ---------------- configuration ----------------
    localparam int N_MST   = 2;            // xbar masters (1 real + 1 BFM)
    localparam int N_SLV   = 1;            // xbar slaves (the DRAM window)
    localparam int AXI_AW  = 32;
    localparam int AXI_DW  = 64;
    localparam int AXI_IDW = 4;            // master-side transaction ID width
    localparam int MIW     = 1;            // N_MST=2 -> clog2 = 1
    localparam int XIDW    = AXI_IDW + MIW;// slave-side xid width (5)
    localparam int STRB_W  = AXI_DW / 8;
    localparam int LOG_STRB = 3;

    localparam logic [31:0] MEM_BASE  = 32'h8000_0000;
    localparam int          MEM_BYTES = 16 * 1024;
    localparam int          MEM_WORDS = MEM_BYTES / STRB_W;
    localparam int          RD_LATENCY = 4;
    localparam int          WR_LATENCY = 2;
    // base at [0*AW +: AW], mask at [(N_SLV+0)*AW +: AW] — the 16 KiB window
    localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP =
        {32'hFFFF_C000, MEM_BASE};

    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10, DECERR = 2'b11;
    localparam logic [1:0] FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10;

    localparam int SEL_DIRECT = 0, SEL_XBAR = 1;

    // ---------------- clock / reset ----------------
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic sel = SEL_DIRECT;      // which path the BFM drives

    // ==================================================================
    // Driver-side (virtual) AXI4 masters, one per master index.
    // ==================================================================
    logic [N_MST-1:0]         drv_awvalid, drv_awready;
    logic [N_MST*AXI_AW-1:0]  drv_awaddr;
    logic [N_MST*AXI_IDW-1:0] drv_awid;
    logic [N_MST*8-1:0]       drv_awlen;
    logic [N_MST*3-1:0]       drv_awsize;
    logic [N_MST*2-1:0]       drv_awburst;
    logic [N_MST-1:0]         drv_wvalid, drv_wready;
    logic [N_MST*AXI_DW-1:0]  drv_wdata;
    logic [N_MST*STRB_W-1:0]  drv_wstrb;
    logic [N_MST-1:0]         drv_wlast;
    logic [N_MST-1:0]         drv_bvalid, drv_bready;
    logic [N_MST*AXI_IDW-1:0] drv_bid;
    logic [N_MST*2-1:0]       drv_bresp;
    logic [N_MST-1:0]         drv_arvalid, drv_arready;
    logic [N_MST*AXI_AW-1:0]  drv_araddr;
    logic [N_MST*AXI_IDW-1:0] drv_arid;
    logic [N_MST*8-1:0]       drv_arlen;
    logic [N_MST*3-1:0]       drv_arsize;
    logic [N_MST*2-1:0]       drv_arburst;
    logic [N_MST-1:0]         drv_rvalid, drv_rready;
    logic [N_MST*AXI_DW-1:0]  drv_rdata;
    logic [N_MST*2-1:0]       drv_rresp;
    logic [N_MST-1:0]         drv_rlast;
    logic [N_MST*AXI_IDW-1:0] drv_rid;

    // ==================================================================
    // Direct baseline path: the BFM's master 0 -> eth_dram_ctrl -> stub
    // ==================================================================
    logic        d_awvalid, d_awready;
    logic [31:0] d_awaddr;
    logic [3:0]  d_awid;
    logic [7:0]  d_awlen;
    logic [2:0]  d_awsize;
    logic [1:0]  d_awburst;
    logic        d_wvalid, d_wready, d_wlast;
    logic [63:0] d_wdata;
    logic [7:0]  d_wstrb;
    logic        d_bvalid, d_bready;
    logic [1:0]  d_bresp;
    logic [3:0]  d_bid;
    logic        d_arvalid, d_arready;
    logic [31:0] d_araddr;
    logic [3:0]  d_arid;
    logic [7:0]  d_arlen;
    logic [2:0]  d_arsize;
    logic [1:0]  d_arburst;
    logic        d_rvalid, d_rready, d_rlast;
    logic [63:0] d_rdata;
    logic [1:0]  d_rresp;
    logic [3:0]  d_rid;

    assign d_awvalid = (sel == SEL_DIRECT) ? drv_awvalid[0] : 1'b0;
    assign d_awaddr  = drv_awaddr[0*AXI_AW +: AXI_AW];
    assign d_awid    = drv_awid[0*AXI_IDW +: AXI_IDW];
    assign d_awlen   = drv_awlen[0*8 +: 8];
    assign d_awsize  = drv_awsize[0*3 +: 3];
    assign d_awburst = drv_awburst[0*2 +: 2];
    assign d_wvalid  = (sel == SEL_DIRECT) ? drv_wvalid[0] : 1'b0;
    assign d_wdata   = drv_wdata[0*AXI_DW +: AXI_DW];
    assign d_wstrb   = drv_wstrb[0*STRB_W +: STRB_W];
    assign d_wlast   = (sel == SEL_DIRECT) ? drv_wlast[0] : 1'b0;
    assign d_bready  = (sel == SEL_DIRECT) ? drv_bready[0] : 1'b0;
    assign d_arvalid = (sel == SEL_DIRECT) ? drv_arvalid[0] : 1'b0;
    assign d_araddr  = drv_araddr[0*AXI_AW +: AXI_AW];
    assign d_arid    = drv_arid[0*AXI_IDW +: AXI_IDW];
    assign d_arlen   = drv_arlen[0*8 +: 8];
    assign d_arsize  = drv_arsize[0*3 +: 3];
    assign d_arburst = drv_arburst[0*2 +: 2];
    assign d_rready  = (sel == SEL_DIRECT) ? drv_rready[0] : 1'b0;

    eth_dram_ctrl #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .AXI_IDW(AXI_IDW),
        .MEM_BASE(MEM_BASE), .MEM_BYTES(MEM_BYTES),
        .RD_LATENCY(RD_LATENCY), .WR_LATENCY(WR_LATENCY)
    ) u_dram_d (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(d_awvalid), .s_axi_awready(d_awready),
        .s_axi_awaddr(d_awaddr), .s_axi_awid(d_awid), .s_axi_awlen(d_awlen),
        .s_axi_awsize(d_awsize), .s_axi_awburst(d_awburst),
        .s_axi_awcache(4'h0), .s_axi_awprot(3'h0), .s_axi_awqos(4'h0),
        .s_axi_awregion(4'h0), .s_axi_awlock(1'b0),
        .s_axi_wvalid(d_wvalid), .s_axi_wready(d_wready), .s_axi_wdata(d_wdata),
        .s_axi_wstrb(d_wstrb), .s_axi_wlast(d_wlast),
        .s_axi_bvalid(d_bvalid), .s_axi_bready(d_bready), .s_axi_bresp(d_bresp),
        .s_axi_bid(d_bid),
        .s_axi_arvalid(d_arvalid), .s_axi_arready(d_arready),
        .s_axi_araddr(d_araddr), .s_axi_arid(d_arid), .s_axi_arlen(d_arlen),
        .s_axi_arsize(d_arsize), .s_axi_arburst(d_arburst),
        .s_axi_arcache(4'h0), .s_axi_arprot(3'h0), .s_axi_arqos(4'h0),
        .s_axi_arregion(4'h0), .s_axi_arlock(1'b0),
        .s_axi_rvalid(d_rvalid), .s_axi_rready(d_rready), .s_axi_rdata(d_rdata),
        .s_axi_rresp(d_rresp), .s_axi_rlast(d_rlast), .s_axi_rid(d_rid)
    );

    // ==================================================================
    // Xbar path: BFM masters -> eth_axi_xbar (BURST_EN=1) -> DRAM socket
    // ==================================================================
    logic [N_MST-1:0]         x_awvalid, x_awready;
    logic [N_MST*AXI_AW-1:0]  x_awaddr;
    logic [N_MST*AXI_IDW-1:0] x_awid;
    logic [N_MST*8-1:0]       x_awlen;
    logic [N_MST*3-1:0]       x_awsize;
    logic [N_MST*2-1:0]       x_awburst;
    logic [N_MST-1:0]         x_wvalid, x_wready;
    logic [N_MST*AXI_DW-1:0]  x_wdata;
    logic [N_MST*STRB_W-1:0]  x_wstrb;
    logic [N_MST-1:0]         x_wlast;
    logic [N_MST-1:0]         x_bvalid, x_bready;
    logic [N_MST*AXI_IDW-1:0] x_bid;
    logic [N_MST*2-1:0]       x_bresp;
    logic [N_MST-1:0]         x_arvalid, x_arready;
    logic [N_MST*AXI_AW-1:0]  x_araddr;
    logic [N_MST*AXI_IDW-1:0] x_arid;
    logic [N_MST*8-1:0]       x_arlen;
    logic [N_MST*3-1:0]       x_arsize;
    logic [N_MST*2-1:0]       x_arburst;
    logic [N_MST-1:0]         x_rvalid, x_rready;
    logic [N_MST*AXI_DW-1:0]  x_rdata;
    logic [N_MST*2-1:0]       x_rresp;
    logic [N_MST-1:0]         x_rlast;
    logic [N_MST*AXI_IDW-1:0] x_rid;

    // slave-side (xbar -> DRAM)
    logic                m_awvalid, m_awready;
    logic [31:0]         m_awaddr;
    logic [XIDW-1:0]     m_awid;
    logic [7:0]          m_awlen;
    logic [2:0]          m_awsize;
    logic [1:0]          m_awburst;
    logic                m_wvalid, m_wready, m_wlast;
    logic [63:0]         m_wdata;
    logic [7:0]          m_wstrb;
    logic                m_bvalid, m_bready;
    logic [1:0]          m_bresp;
    logic [XIDW-1:0]     m_bid;
    logic                m_arvalid, m_arready;
    logic [31:0]         m_araddr;
    logic [XIDW-1:0]     m_arid;
    logic [7:0]          m_arlen;
    logic [2:0]          m_arsize;
    logic [1:0]          m_arburst;
    logic                m_rvalid, m_rready, m_rlast;
    logic [63:0]         m_rdata;
    logic [1:0]          m_rresp;
    logic [XIDW-1:0]     m_rid;

    assign x_awvalid = (sel == SEL_XBAR) ? drv_awvalid : {N_MST{1'b0}};
    assign x_awaddr  = drv_awaddr;
    assign x_awid    = drv_awid;
    assign x_awlen   = drv_awlen;
    assign x_awsize  = drv_awsize;
    assign x_awburst = drv_awburst;
    assign x_wvalid  = (sel == SEL_XBAR) ? drv_wvalid : {N_MST{1'b0}};
    assign x_wdata   = drv_wdata;
    assign x_wstrb   = drv_wstrb;
    assign x_wlast   = (sel == SEL_XBAR) ? drv_wlast : {N_MST{1'b0}};
    assign x_bready  = (sel == SEL_XBAR) ? drv_bready : {N_MST{1'b0}};
    assign x_arvalid = (sel == SEL_XBAR) ? drv_arvalid : {N_MST{1'b0}};
    assign x_araddr  = drv_araddr;
    assign x_arid    = drv_arid;
    assign x_arlen   = drv_arlen;
    assign x_arsize  = drv_arsize;
    assign x_arburst = drv_arburst;
    assign x_rready  = (sel == SEL_XBAR) ? drv_rready : {N_MST{1'b0}};

    // readback mux into the BFM (direct when sel==DIRECT, xbar otherwise)
    assign drv_awready = (sel == SEL_XBAR) ? x_awready : {1'b0, d_awready};
    assign drv_wready  = (sel == SEL_XBAR) ? x_wready  : {1'b0, d_wready};
    assign drv_bvalid  = (sel == SEL_XBAR) ? x_bvalid  : {1'b0, d_bvalid};
    assign drv_bresp   = (sel == SEL_XBAR) ? x_bresp
                                           : {2'b00, d_bresp};
    assign drv_bid     = (sel == SEL_XBAR) ? x_bid
                                           : {{AXI_IDW{1'b0}}, d_bid};
    assign drv_arready = (sel == SEL_XBAR) ? x_arready : {1'b0, d_arready};
    assign drv_rvalid  = (sel == SEL_XBAR) ? x_rvalid  : {1'b0, d_rvalid};
    assign drv_rdata   = (sel == SEL_XBAR) ? x_rdata
                                           : {{AXI_DW{1'b0}}, d_rdata};
    assign drv_rresp   = (sel == SEL_XBAR) ? x_rresp
                                           : {2'b00, d_rresp};
    assign drv_rlast   = (sel == SEL_XBAR) ? x_rlast  : {1'b0, d_rlast};
    assign drv_rid     = (sel == SEL_XBAR) ? x_rid
                                           : {{AXI_IDW{1'b0}}, d_rid};

    eth_axi_xbar #(
        .N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
        .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .BURST_EN(1'b1), .ADDR_MAP(ADDR_MAP)
    ) u_xbar (
        .clk_i(clk), .rst_ni(rst_n),
        .s_awvalid(x_awvalid), .s_awready(x_awready), .s_awaddr(x_awaddr),
        .s_awid(x_awid), .s_awlen(x_awlen), .s_awsize(x_awsize),
        .s_awburst(x_awburst),
        .s_wvalid(x_wvalid), .s_wready(x_wready), .s_wdata(x_wdata),
        .s_wstrb(x_wstrb), .s_wlast(x_wlast),
        .s_bvalid(x_bvalid), .s_bready(x_bready), .s_bid(x_bid),
        .s_bresp(x_bresp),
        .s_arvalid(x_arvalid), .s_arready(x_arready), .s_araddr(x_araddr),
        .s_arid(x_arid), .s_arlen(x_arlen), .s_arsize(x_arsize),
        .s_arburst(x_arburst),
        .s_rvalid(x_rvalid), .s_rready(x_rready), .s_rid(x_rid),
        .s_rdata(x_rdata), .s_rresp(x_rresp), .s_rlast(x_rlast),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr),
        .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata),
        .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid),
        .m_bresp(m_bresp),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr),
        .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rid(m_rid),
        .m_rdata(m_rdata), .m_rresp(m_rresp), .m_rlast(m_rlast)
    );

    eth_dram_ctrl #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .AXI_IDW(XIDW),
        .MEM_BASE(MEM_BASE), .MEM_BYTES(MEM_BYTES),
        .RD_LATENCY(RD_LATENCY), .WR_LATENCY(WR_LATENCY)
    ) u_dram_x (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_awaddr(m_awaddr), .s_axi_awid(m_awid), .s_axi_awlen(m_awlen),
        .s_axi_awsize(m_awsize), .s_axi_awburst(m_awburst),
        .s_axi_awcache(4'h0), .s_axi_awprot(3'h0), .s_axi_awqos(4'h0),
        .s_axi_awregion(4'h0), .s_axi_awlock(1'b0),
        .s_axi_wvalid(m_wvalid), .s_axi_wready(m_wready), .s_axi_wdata(m_wdata),
        .s_axi_wstrb(m_wstrb), .s_axi_wlast(m_wlast),
        .s_axi_bvalid(m_bvalid), .s_axi_bready(m_bready), .s_axi_bresp(m_bresp),
        .s_axi_bid(m_bid),
        .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_araddr(m_araddr), .s_axi_arid(m_arid), .s_axi_arlen(m_arlen),
        .s_axi_arsize(m_arsize), .s_axi_arburst(m_arburst),
        .s_axi_arcache(4'h0), .s_axi_arprot(3'h0), .s_axi_arqos(4'h0),
        .s_axi_arregion(4'h0), .s_axi_arlock(1'b0),
        .s_axi_rvalid(m_rvalid), .s_axi_rready(m_rready), .s_axi_rdata(m_rdata),
        .s_axi_rresp(m_rresp), .s_axi_rlast(m_rlast), .s_axi_rid(m_rid)
    );

    // ==================================================================
    // Scoreboard + reference memory
    // ==================================================================
    integer errors = 0;
    integer checks = 0;

    task automatic chk(input bit cond, input [1023:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    logic [AXI_DW-1:0] ref_mem [0:MEM_WORDS-1];

    // AXI4 INCR beat address (IHI0022G §A3.4.1): beat 0 = Start, beat N>0 =
    // align_down(Start, 2^AxSIZE) + N*2^AxSIZE.
    function automatic logic [31:0] beat_addr(input [31:0] start, input int n,
                                              input [2:0] size);
        logic [31:0] inc, abase;
        begin
            inc       = 32'd1 << size;
            abase     = start & ~(inc - 32'd1);
            beat_addr = (n == 0) ? start : (abase + n * inc);
        end
    endfunction

    // Valid WSTRB lanes for a beat: the 2^AxSIZE addressed bytes inside the
    // containing bus word.
    function automatic logic [7:0] lane_mask(input [31:0] addr, input [2:0] size);
        logic [15:0] nbytes, mm;
        logic [7:0]  l;
        begin
            nbytes = 16'd1 << size;
            mm     = (16'd1 << nbytes) - 16'd1;      // 0x01/0x03/0x0F/0xFF
            l      = mm[7:0];
            lane_mask = l << addr[2:0];
        end
    endfunction

    function automatic logic [AXI_DW-1:0] beat_data(input [31:0] ba);
        beat_data = {ba, ~ba};
    endfunction

    function automatic logic [AXI_IDW-1:0] id_of(input integer mi);
        id_of = (mi == 0) ? 4'h5 : 4'h3;
    endfunction

    task automatic ref_commit(input [31:0] addr, input [7:0] len,
                              input [2:0] size, input [1:0] resp);
        integer i, li;
        logic [31:0] ba;
        logic [AXI_DW-1:0] data;
        logic [7:0] strb;
        begin
            if (resp == OKAY) begin
                for (i = 0; i <= int'(len); i = i + 1) begin
                    ba   = beat_addr(addr, i, size);
                    data = beat_data(ba);
                    strb = lane_mask(ba, size);
                    for (li = 0; li < STRB_W; li = li + 1)
                        if (strb[li])
                            ref_mem[(ba - MEM_BASE) >> LOG_STRB][li*8 +: 8]
                                = data[li*8 +: 8];
                end
            end
        end
    endtask

    // ==================================================================
    // BFM: per-master logs + drivers
    // ==================================================================
    integer rd_n [0:N_MST-1];
    logic [AXI_DW-1:0] lg_dat0 [0:255];
    logic [1:0]        lg_rsp0 [0:255];
    logic              lg_lst0 [0:255];
    logic [AXI_IDW-1:0] lg_id0 [0:255];
    logic [AXI_DW-1:0] lg_dat1 [0:255];
    logic [1:0]        lg_rsp1 [0:255];
    logic              lg_lst1 [0:255];
    logic [AXI_IDW-1:0] lg_id1 [0:255];

    // baseline (direct-path) snapshot of a read burst
    integer            ref_n;
    logic [AXI_DW-1:0] ref_dat [0:255];
    logic [1:0]        ref_rsp [0:255];
    logic              ref_lst [0:255];
    logic [AXI_IDW-1:0] ref_id [0:255];

    logic [1:0]        got_bresp [0:N_MST-1];
    logic [AXI_IDW-1:0] got_bid  [0:N_MST-1];

    task automatic aw_beat(input integer mi, input [31:0] addr, input [7:0] len,
                           input [2:0] size, input [1:0] burst);
        begin
            @(negedge clk);
            drv_awvalid[mi] = 1'b1;
            drv_awaddr[mi*AXI_AW +: AXI_AW] = addr;
            drv_awid[mi*AXI_IDW +: AXI_IDW] = id_of(mi);
            drv_awlen[mi*8 +: 8]            = len;
            drv_awsize[mi*3 +: 3]           = size;
            drv_awburst[mi*2 +: 2]          = burst;
            @(posedge clk);
            while (!drv_awready[mi]) @(posedge clk);
            @(negedge clk);
            drv_awvalid[mi] = 1'b0;
        end
    endtask

    task automatic ar_beat(input integer mi, input [31:0] addr, input [7:0] len,
                           input [2:0] size, input [1:0] burst);
        begin
            @(negedge clk);
            drv_arvalid[mi] = 1'b1;
            drv_araddr[mi*AXI_AW +: AXI_AW] = addr;
            drv_arid[mi*AXI_IDW +: AXI_IDW] = id_of(mi);
            drv_arlen[mi*8 +: 8]            = len;
            drv_arsize[mi*3 +: 3]           = size;
            drv_arburst[mi*2 +: 2]          = burst;
            @(posedge clk);
            while (!drv_arready[mi]) @(posedge clk);
            @(negedge clk);
            drv_arvalid[mi] = 1'b0;
        end
    endtask

    // One write burst: AW -> len+1 W beats (legal WSTRB lanes, WLAST on the
    // last) -> B. `wgap` inserts idle cycles between W beats (backpressure).
    task automatic wr_burst(input integer mi, input [31:0] addr, input [7:0] len,
                            input [2:0] size, input [1:0] burst, input integer wgap);
        integer i;
        logic [31:0] ba;
        begin
            aw_beat(mi, addr, len, size, burst);
            for (i = 0; i <= int'(len); i = i + 1) begin
                ba = beat_addr(addr, i, size);
                @(negedge clk);
                drv_wvalid[mi] = 1'b1;
                drv_wdata[mi*AXI_DW +: AXI_DW] = beat_data(ba);
                drv_wstrb[mi*STRB_W +: STRB_W] = lane_mask(ba, size);
                drv_wlast[mi]  = (i == int'(len));
                @(posedge clk);
                while (!drv_wready[mi]) @(posedge clk);
                @(negedge clk);
                drv_wvalid[mi] = 1'b0;
                drv_wlast[mi]  = 1'b0;
                if (wgap > 0) repeat (wgap) @(negedge clk);
            end
            @(negedge clk);
            drv_bready[mi] = 1'b1;
            @(posedge clk);
            while (!drv_bvalid[mi]) @(posedge clk);
            got_bresp[mi] = drv_bresp[mi*2 +: 2];
            got_bid[mi]   = drv_bid[mi*AXI_IDW +: AXI_IDW];
            @(negedge clk);
            drv_bready[mi] = 1'b0;
        end
    endtask

    // One read burst: AR -> R beats until RLAST (or a 256-beat budget), logged
    // per master. `rgap` stalls RREADY after each beat (backpressure).
    task automatic rd_burst(input integer mi, input [31:0] addr, input [7:0] len,
                            input [2:0] size, input [1:0] burst, input integer rgap);
        integer i, done, n;
        begin
            ar_beat(mi, addr, len, size, burst);
            rd_n[mi] = 0;
            done = 0;
            @(negedge clk);
            drv_rready[mi] = 1'b1;
            for (i = 0; (i < 256) && (done == 0); i = i + 1) begin
                @(posedge clk);
                while (!drv_rvalid[mi]) @(posedge clk);
                n = rd_n[mi];
                if (mi == 0) begin
                    lg_dat0[n] = drv_rdata[0*AXI_DW +: AXI_DW];
                    lg_rsp0[n] = drv_rresp[0*2 +: 2];
                    lg_lst0[n] = drv_rlast[0];
                    lg_id0[n]  = drv_rid[0*AXI_IDW +: AXI_IDW];
                end else begin
                    lg_dat1[n] = drv_rdata[1*AXI_DW +: AXI_DW];
                    lg_rsp1[n] = drv_rresp[1*2 +: 2];
                    lg_lst1[n] = drv_rlast[1];
                    lg_id1[n]  = drv_rid[1*AXI_IDW +: AXI_IDW];
                end
                rd_n[mi] = n + 1;
                if (drv_rlast[mi]) done = 1;
                else if (rgap > 0) begin
                    @(negedge clk);
                    drv_rready[mi] = 1'b0;
                    repeat (rgap) @(negedge clk);
                    drv_rready[mi] = 1'b1;
                end
            end
            @(negedge clk);
            drv_rready[mi] = 1'b0;
        end
    endtask

    task automatic save_ref();
        integer i;
        begin
            ref_n = rd_n[0];
            for (i = 0; i < ref_n; i = i + 1) begin
                ref_dat[i] = lg_dat0[i];
                ref_rsp[i] = lg_rsp0[i];
                ref_lst[i] = lg_lst0[i];
                ref_id[i]  = lg_id0[i];
            end
        end
    endtask

    // per-beat comparison of the current master-0 read burst vs the baseline
    task automatic cmp_ref(input [1023:0] what);
        integer i;
        begin
            chk(rd_n[0] == ref_n, {what, ": R beat count == direct baseline"});
            for (i = 0; (i < rd_n[0]) && (i < ref_n); i = i + 1) begin
                chk(lg_dat0[i] == ref_dat[i], {what, ": RDATA beat == baseline"});
                chk(lg_rsp0[i] == ref_rsp[i], {what, ": RRESP beat == baseline"});
                chk(lg_lst0[i] == ref_lst[i], {what, ": RLAST beat == baseline"});
                chk(lg_id0[i]  == ref_id[i],  {what, ": RID beat == baseline"});
            end
        end
    endtask

    // check the logged beats against the TB reference memory (words are
    // returned whole, so a partially-written word still compares correctly)
    task automatic chk_vs_refmem(input integer mi, input [31:0] addr,
                                 input [2:0] size, input [1023:0] what);
        integer i;
        logic [31:0] ba;
        begin
            for (i = 0; i < rd_n[mi]; i = i + 1) begin
                if (lg_rsp0[i] == OKAY) begin
                    ba = beat_addr(addr, i, size);
                    if (mi == 0)
                        chk(lg_dat0[i] == ref_mem[(ba - MEM_BASE) >> LOG_STRB],
                            {what, ": RDATA == reference memory"});
                    else
                        chk(lg_dat1[i] == ref_mem[(ba - MEM_BASE) >> LOG_STRB],
                            {what, ": RDATA == reference memory"});
                end
            end
        end
    endtask

    // ==================================================================
    // Stimulus
    // ==================================================================
    localparam logic [7:0] LEN_SWEEP = 8'd255;   // 256-beat init bursts

    integer w, idx;
    integer len_tab [0:7];
    integer sz_tab  [0:7];
    logic [31:0] ad_tab [0:7];
    integer n_cfg;

    initial begin
        // ---------------- default drive ----------------
        sel = SEL_DIRECT;
        drv_awvalid = {N_MST{1'b0}}; drv_wvalid = {N_MST{1'b0}};
        drv_bready  = {N_MST{1'b0}}; drv_arvalid = {N_MST{1'b0}};
        drv_rready  = {N_MST{1'b0}};
        drv_awaddr = {N_MST*AXI_AW{1'b0}}; drv_awid = {N_MST*AXI_IDW{1'b0}};
        drv_awlen = {N_MST*8{1'b0}}; drv_awsize = {N_MST*3{1'b0}};
        drv_awburst = {N_MST*2{1'b0}};
        drv_wdata = {N_MST*AXI_DW{1'b0}}; drv_wstrb = {N_MST*STRB_W{1'b0}};
        drv_wlast = {N_MST{1'b0}};
        drv_araddr = {N_MST*AXI_AW{1'b0}}; drv_arid = {N_MST*AXI_IDW{1'b0}};
        drv_arlen = {N_MST*8{1'b0}}; drv_arsize = {N_MST*3{1'b0}};
        drv_arburst = {N_MST*2{1'b0}};
        for (idx = 0; idx < N_MST; idx = idx + 1) rd_n[idx] = 0;

        rst_n = 1'b0;
        repeat (6) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // ================= 0. memory init sweep ==========================
        // Full-width INCR bursts fill the whole window on BOTH paths so every
        // later read is a defined value.
        // The two paths own INDEPENDENT DRAM sockets, so both images must be
        // filled: the sweep runs once per path (the direct one also builds the
        // TB reference memory), then the xbar-path image is read back in full.
        for (w = 0; w < MEM_WORDS; w = w + 256) begin
            sel = SEL_DIRECT;
            wr_burst(0, MEM_BASE + w*8, LEN_SWEEP, 3'd3, INCR, 0);
            chk(got_bresp[0] == OKAY, "init sweep write OKAY (direct)");
            chk(got_bid[0]   == id_of(0), "init sweep BID == master id");
            ref_commit(MEM_BASE + w*8, LEN_SWEEP, 3'd3, got_bresp[0]);

            sel = SEL_XBAR;
            wr_burst(0, MEM_BASE + w*8, LEN_SWEEP, 3'd3, INCR, 0);
            chk(got_bresp[0] == OKAY, "init sweep write OKAY (xbar)");
        end

        // Full-window readback THROUGH the xbar: every beat of every 256-beat
        // burst must equal the reference memory (write + read path end to end).
        for (w = 0; w < MEM_WORDS; w = w + 256) begin
            sel = SEL_XBAR;
            rd_burst(0, MEM_BASE + w*8, LEN_SWEEP, 3'd3, INCR, 0);
            chk(rd_n[0] == 256, "xbar full-window readback beat count");
            chk_vs_refmem(0, MEM_BASE + w*8, 3'd3, "xbar full-window readback");
        end

        // ================= 1+2. burst shapes, direct vs xbar ============
        // {addr, len, size}: single beat, multi-beat, unaligned start, wide
        // and narrow AxSIZE, and a long burst.
        ad_tab[0] = MEM_BASE + 32'h0040; len_tab[0] = 0;     sz_tab[0] = 3;
        ad_tab[1] = MEM_BASE + 32'h0080; len_tab[1] = 1;     sz_tab[1] = 3;
        ad_tab[2] = MEM_BASE + 32'h0100; len_tab[2] = 3;     sz_tab[2] = 3;
        ad_tab[3] = MEM_BASE + 32'h0200; len_tab[3] = 7;     sz_tab[3] = 2;
        ad_tab[4] = MEM_BASE + 32'h0300; len_tab[4] = 15;    sz_tab[4] = 3;
        ad_tab[5] = MEM_BASE + 32'h0404; len_tab[5] = 3;     sz_tab[5] = 1;
        ad_tab[6] = MEM_BASE + 32'h0500; len_tab[6] = 1;     sz_tab[6] = 0;
        ad_tab[7] = MEM_BASE + 32'h0600; len_tab[7] = 63;    sz_tab[7] = 3;
        n_cfg = 8;

        for (idx = 0; idx < n_cfg; idx = idx + 1) begin
            // ---- direct baseline ----
            sel = SEL_DIRECT;
            wr_burst(0, ad_tab[idx], len_tab[idx][7:0], sz_tab[idx][2:0], INCR, 0);
            chk(got_bresp[0] == OKAY, "direct write burst OKAY");
            chk(got_bid[0]   == id_of(0), "direct write BID == master id");
            ref_commit(ad_tab[idx], len_tab[idx][7:0], sz_tab[idx][2:0],
                       got_bresp[0]);
            rd_burst(0, ad_tab[idx], len_tab[idx][7:0], sz_tab[idx][2:0],
                     INCR, 0);
            save_ref();
            chk(rd_n[0] == (len_tab[idx] + 1),
                "direct read beat count == AxLEN+1");
            chk_vs_refmem(0, ad_tab[idx], sz_tab[idx][2:0], "direct read");

            // ---- through the xbar ----
            sel = SEL_XBAR;
            wr_burst(0, ad_tab[idx], len_tab[idx][7:0], sz_tab[idx][2:0], INCR, 0);
            chk(got_bresp[0] == OKAY, "xbar write burst OKAY");
            chk(got_bid[0]   == id_of(0), "xbar write BID == master id");
            rd_burst(0, ad_tab[idx], len_tab[idx][7:0], sz_tab[idx][2:0],
                     INCR, 0);
            cmp_ref("xbar read == direct baseline");
            chk_vs_refmem(0, ad_tab[idx], sz_tab[idx][2:0], "xbar read");
        end

        // ================= 3. backpressure inside a burst ===============
        // Slow W beats + stalled RREADY, both paths, same shape.
        sel = SEL_DIRECT;
        wr_burst(0, MEM_BASE + 32'h0700, 8'd7, 3'd3, INCR, 3);
        ref_commit(MEM_BASE + 32'h0700, 8'd7, 3'd3, got_bresp[0]);
        rd_burst(0, MEM_BASE + 32'h0700, 8'd7, 3'd3, INCR, 5);
        save_ref();
        sel = SEL_XBAR;
        wr_burst(0, MEM_BASE + 32'h0700, 8'd7, 3'd3, INCR, 3);
        chk(got_bresp[0] == OKAY, "xbar backpressured write OKAY");
        rd_burst(0, MEM_BASE + 32'h0700, 8'd7, 3'd3, INCR, 5);
        cmp_ref("xbar backpressured read == direct baseline");
        chk(rd_n[0] == 8, "backpressured read beat count == 8");

        // ================= 4. error traffic =============================
        // (a) DECERR write burst (outside the window -> the xbar's built-in
        //     error slave vs the DRAM socket's window check).
        sel = SEL_DIRECT;
        wr_burst(0, MEM_BASE + MEM_BYTES + 32'h40, 8'd3, 3'd3, INCR, 0);
        chk(got_bresp[0] == DECERR, "direct DECERR write burst");
        chk(got_bid[0]   == id_of(0), "direct DECERR write BID");
        rd_burst(0, MEM_BASE + MEM_BYTES + 32'h40, 8'd3, 3'd3, INCR, 0);
        save_ref();
        chk(ref_n == 1 && ref_rsp[0] == DECERR && ref_lst[0] == 1'b1,
            "direct DECERR read: one last beat");
        sel = SEL_XBAR;
        wr_burst(0, MEM_BASE + MEM_BYTES + 32'h40, 8'd3, 3'd3, INCR, 0);
        chk(got_bresp[0] == DECERR, "xbar DECERR write burst");
        chk(got_bid[0]   == id_of(0), "xbar DECERR write BID");
        rd_burst(0, MEM_BASE + MEM_BYTES + 32'h40, 8'd3, 3'd3, INCR, 0);
        cmp_ref("xbar DECERR read == direct baseline");

        // (b) SLVERR: AxBURST=WRAP (WRAP/FIXED are rejected by the memory
        //     slave; the xbar must forward the burst unchanged).
        sel = SEL_DIRECT;
        wr_burst(0, MEM_BASE + 32'h0800, 8'd3, 3'd3, WRAP, 0);
        chk(got_bresp[0] == SLVERR, "direct WRAP write burst -> SLVERR");
        rd_burst(0, MEM_BASE + 32'h0800, 8'd3, 3'd3, WRAP, 0);
        save_ref();
        sel = SEL_XBAR;
        wr_burst(0, MEM_BASE + 32'h0800, 8'd3, 3'd3, WRAP, 0);
        chk(got_bresp[0] == SLVERR, "xbar WRAP write burst -> SLVERR");
        rd_burst(0, MEM_BASE + 32'h0800, 8'd3, 3'd3, WRAP, 0);
        cmp_ref("xbar WRAP read == direct baseline");

        // (c) 4 KiB-crossing INCR burst -> SLVERR on both paths.
        sel = SEL_DIRECT;
        wr_burst(0, MEM_BASE + 32'h0FF8, 8'd3, 3'd3, INCR, 0);
        chk(got_bresp[0] == SLVERR, "direct 4KiB-crossing write -> SLVERR");
        rd_burst(0, MEM_BASE + 32'h0FF8, 8'd3, 3'd3, INCR, 0);
        save_ref();
        sel = SEL_XBAR;
        wr_burst(0, MEM_BASE + 32'h0FF8, 8'd3, 3'd3, INCR, 0);
        chk(got_bresp[0] == SLVERR, "xbar 4KiB-crossing write -> SLVERR");
        rd_burst(0, MEM_BASE + 32'h0FF8, 8'd3, 3'd3, INCR, 0);
        cmp_ref("xbar 4KiB-crossing read == direct baseline");

        // ================= 5. two masters, concurrent bursts ============
        // Master 1 exists only behind the xbar. Both masters write their own
        // burst into the same DRAM window at the same time: the DRAM write
        // engine is single-outstanding, so the per-destination lock-step must
        // serialize them (and the xid prefix/strip must still identify the
        // right master for a whole burst).
        sel = SEL_XBAR;
        fork
            wr_burst(1, MEM_BASE + 32'h0A00, 8'd3, 3'd3, INCR, 0);
            wr_burst(0, MEM_BASE + 32'h0A80, 8'd7, 3'd3, INCR, 0);
        join
        chk(got_bresp[1] == OKAY, "m1 concurrent write burst OKAY");
        chk(got_bid[1]   == id_of(1), "m1 write BID == m1 id (xid strip)");
        chk(got_bresp[0] == OKAY, "m0 concurrent write burst OKAY");
        chk(got_bid[0]   == id_of(0), "m0 write BID == m0 id (xid strip)");
        ref_commit(MEM_BASE + 32'h0A00, 8'd3, 3'd3, got_bresp[1]);
        ref_commit(MEM_BASE + 32'h0A80, 8'd7, 3'd3, got_bresp[0]);

        // concurrent reads of both scored regions, then check the images
        fork
            rd_burst(1, MEM_BASE + 32'h0A00, 8'd3, 3'd3, INCR, 0);
            rd_burst(0, MEM_BASE + 32'h0A80, 8'd7, 3'd3, INCR, 0);
        join
        chk(rd_n[1] == 4, "m1 concurrent read beat count");
        chk(lg_id1[0] == id_of(1), "m1 RID == m1 id (xid strip)");
        chk_vs_refmem(1, MEM_BASE + 32'h0A00, 3'd3, "m1 concurrent read");
        chk(rd_n[0] == 8, "m0 concurrent read beat count");
        chk(lg_id0[0] == id_of(0), "m0 RID == m0 id (xid strip)");
        chk_vs_refmem(0, MEM_BASE + 32'h0A80, 3'd3, "m0 concurrent read");

        // ================= summary =====================================
        if (errors == 0)
            $display("TEST PASSED: eth_axi_xbar BURST_EN=1 — INCR bursts through the xbar match the direct baseline (%0d checks)",
                     checks);
        else
            $display("TEST FAILED: %0d errors / %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("TEST FAILED: watchdog (%0d checks, %0d errors)", checks, errors);
        $finish;
    end
endmodule
`default_nettype wire
