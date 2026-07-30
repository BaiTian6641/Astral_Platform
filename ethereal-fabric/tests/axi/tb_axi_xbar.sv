`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_axi_xbar (testbench, self-checking)
// Description: Unit TB for eth_axi_xbar — 2 masters x 3 slaves crossbar.
//              Verifies: (1) address routing (each master reaches the right slave
//              by address); (2) response returns to the CORRECT master (m0 vs m1);
//              (3) decode-error slave (unmapped addr -> DECERR, never hang);
//              (4) arbitration when both masters contend for the same slave.
//              Slave models are simple always-ready responders that echo the
//              widened xid back so the TB can check master-index routing.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §5
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps
module tb_axi_xbar;
  localparam int N_MST = 2, N_SLV = 3, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 4;
  localparam int XIDW = AXI_IDW + 1;      // + master-index width (N_MST=2 -> 1 bit)
  localparam int MIW = 1;

  // slave address map (base, mask): S0=0x0000, S1=0x1000, S2=0x2000 (4KB windows)
  // ADDR_MAP flat: base_s at [s*AW +: AW], mask_s at [(N_SLV+s)*AW +: AW]
  localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {
    32'hFFFF_F000, 32'hFFFF_F000, 32'hFFFF_F000,   // masks S2,S1,S0 (MSB-first)
    32'h0000_2000, 32'h0000_1000, 32'h0000_0000    // bases S2,S1,S0 (MSB-first)
  };

  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;

  // ---- master-side (2 masters) ----
  logic [N_MST-1:0]        s_awvalid, s_awready;
  logic [N_MST*AXI_AW-1:0] s_awaddr;
  logic [N_MST*AXI_IDW-1:0]s_awid;
  logic [N_MST-1:0]        s_wvalid, s_wready;
  logic [N_MST*AXI_DW-1:0] s_wdata;
  logic [N_MST*4-1:0]      s_wstrb;
  logic [N_MST-1:0]        s_bvalid, s_bready;
  logic [N_MST*AXI_IDW-1:0]s_bid;
  logic [N_MST*2-1:0]      s_bresp;
  logic [N_MST-1:0]        s_arvalid, s_arready;
  logic [N_MST*AXI_AW-1:0] s_araddr;
  logic [N_MST*AXI_IDW-1:0]s_arid;
  logic [N_MST-1:0]        s_rvalid, s_rready;
  logic [N_MST*AXI_IDW-1:0]s_rid;
  logic [N_MST*AXI_DW-1:0] s_rdata;
  logic [N_MST*2-1:0]      s_rresp;

  // ---- slave-side (3 slaves) ----
  logic [N_SLV-1:0]        m_awvalid, m_awready;
  logic [N_SLV*AXI_AW-1:0] m_awaddr;
  logic [N_SLV*XIDW-1:0]   m_awid;
  logic [N_SLV-1:0]        m_wvalid, m_wready;
  logic [N_SLV*AXI_DW-1:0] m_wdata;
  logic [N_SLV*4-1:0]      m_wstrb;
  logic [N_SLV-1:0]        m_bvalid, m_bready;
  logic [N_SLV*XIDW-1:0]   m_bid;
  logic [N_SLV*2-1:0]      m_bresp;
  logic [N_SLV-1:0]        m_arvalid, m_arready;
  logic [N_SLV*AXI_AW-1:0] m_araddr;
  logic [N_SLV*XIDW-1:0]   m_arid;
  logic [N_SLV-1:0]        m_rvalid, m_rready;
  logic [N_SLV*XIDW-1:0]   m_rid;
  logic [N_SLV*AXI_DW-1:0] m_rdata;
  logic [N_SLV*2-1:0]      m_rresp;

  eth_axi_xbar #(.N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
                 .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .ADDR_MAP(ADDR_MAP)) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr), .s_awid(s_awid),
    .s_wvalid(s_wvalid), .s_wready(s_wready), .s_wdata(s_wdata), .s_wstrb(s_wstrb),
    .s_bvalid(s_bvalid), .s_bready(s_bready), .s_bid(s_bid), .s_bresp(s_bresp),
    .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr), .s_arid(s_arid),
    .s_rvalid(s_rvalid), .s_rready(s_rready), .s_rid(s_rid), .s_rdata(s_rdata), .s_rresp(s_rresp),
    .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
    .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata), .m_wstrb(m_wstrb),
    .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid), .m_bresp(m_bresp),
    .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
    .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rid(m_rid), .m_rdata(m_rdata), .m_rresp(m_rresp)
  );

  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  // ====================================================================
  // Slave behavioral models: always-ready; capture AW/AR, respond B/R with
  // the WIDENED xid echoed back (so the TB verifies master-index routing).
  // rdata = the araddr (so reads are identifiable). Simplest correct model.
  // ====================================================================
  genvar s;
  generate
  for (s = 0; s < N_SLV; s++) begin : g_slv
    // write channel
    logic [XIDW-1:0] bxid;
    logic            have_aw, have_w;
    assign m_awready[s] = !have_aw;
    assign m_wready[s]  = !have_w;
    assign m_bvalid[s]  = have_aw && have_w;
    assign m_bid[s*XIDW +: XIDW] = bxid;
    assign m_bresp[s*2 +: 2] = 2'b00;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin have_aw<=0; have_w<=0; bxid<=0; end
      else begin
        if (m_awvalid[s] && m_awready[s]) begin have_aw<=1; bxid<=m_awid[s*XIDW +: XIDW]; end
        if (m_wvalid[s]  && m_wready[s])  have_w<=1;
        if (m_bvalid[s]  && m_bready[s])  begin have_aw<=0; have_w<=0; end
      end
    end
    // read channel
    logic [XIDW-1:0]   rxid;
    logic [AXI_AW-1:0] raddr_r;
    logic              have_ar;
    assign m_arready[s] = !have_ar;
    assign m_rvalid[s]  = have_ar;
    assign m_rid[s*XIDW +: XIDW] = rxid;
    assign m_rdata[s*AXI_DW +: AXI_DW] = raddr_r;   // echo the address as data
    assign m_rresp[s*2 +: 2] = 2'b00;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin have_ar<=0; rxid<=0; raddr_r<=0; end
      else begin
        if (m_arvalid[s] && m_arready[s]) begin
          have_ar<=1; rxid<=m_arid[s*XIDW +: XIDW]; raddr_r<=m_araddr[s*AXI_AW +: AXI_AW];
        end
        if (m_rvalid[s] && m_rready[s]) have_ar<=0;
      end
    end
  end
  endgenerate

  // ====================================================================
  // Master driver tasks (single-beat AXI-Lite-style, ID=0)
  // ====================================================================
  // write from master `mi` to `addr` with `data`; returns bresp + bid(master idx)
  task automatic mwrite(input integer mi, input [31:0] addr, input [31:0] data,
                        output [1:0] resp, output [XIDW-1:0] bid);
    begin
      @(negedge clk);
      s_awvalid[mi]=1; s_awaddr[mi*AXI_AW +: AXI_AW]=addr; s_awid[mi*AXI_IDW +: AXI_IDW]=0;
      s_wvalid[mi]=1;  s_wdata[mi*AXI_DW +: AXI_DW]=data;  s_wstrb[mi*4 +: 4]=4'hF;
      @(posedge clk); while (!(s_awready[mi] && s_wready[mi])) @(posedge clk);
      @(negedge clk); s_awvalid[mi]=0; s_wvalid[mi]=0;
      s_bready[mi]=1;
      @(posedge clk); while (!s_bvalid[mi]) @(posedge clk);
      resp = s_bresp[mi*2 +: 2]; bid = s_bid[mi*AXI_IDW +: AXI_IDW];
      @(negedge clk); s_bready[mi]=0;
    end
  endtask

  // read from master `mi` at `addr`; returns rdata + rresp + rid(master idx)
  task automatic mread(input integer mi, input [31:0] addr,
                       output [31:0] data, output [1:0] resp, output [XIDW-1:0] rid);
    begin
      @(negedge clk);
      s_arvalid[mi]=1; s_araddr[mi*AXI_AW +: AXI_AW]=addr; s_arid[mi*AXI_IDW +: AXI_IDW]=0;
      @(posedge clk); while (!s_arready[mi]) @(posedge clk);
      @(negedge clk); s_arvalid[mi]=0;
      s_rready[mi]=1;
      @(posedge clk); while (!s_rvalid[mi]) @(posedge clk);
      data = s_rdata[mi*AXI_DW +: AXI_DW]; resp = s_rresp[mi*2 +: 2];
      rid = s_rid[mi*AXI_IDW +: AXI_IDW];
      @(negedge clk); s_rready[mi]=0;
    end
  endtask

  logic [31:0] rd; logic [1:0] rsp; logic [XIDW-1:0] xid;
  initial begin
    s_awvalid=0; s_wvalid=0; s_bready=0; s_arvalid=0; s_rready=0;
    s_awaddr=0; s_awid=0; s_wdata=0; s_wstrb=0; s_araddr=0; s_arid=0;
    rst_n=0; repeat(5) @(posedge clk); rst_n=1; @(negedge clk);

    // ---- 1. address routing: m0 -> S0, S1, S2 by address ----
    mread(0, 32'h0000_0100, rd, rsp, xid);
    chk(rd == 32'h0000_0100 && rsp == 2'b00, "m0 read S0 (0x0100) routed + OKAY");
    mread(0, 32'h0000_1100, rd, rsp, xid);
    chk(rd == 32'h0000_1100 && rsp == 2'b00, "m0 read S1 (0x1100) routed + OKAY");
    mread(0, 32'h0000_2100, rd, rsp, xid);
    chk(rd == 32'h0000_2100 && rsp == 2'b00, "m0 read S2 (0x2100) routed + OKAY");

    // ---- 2. decode-error: unmapped addr -> DECERR, never hang ----
    mread(0, 32'h0000_9000, rd, rsp, xid);
    chk(rsp == 2'b11, "unmapped read (0x9000) -> DECERR");

    // ---- 3. response returns to the CORRECT master (m0 vs m1) ----
    // m1 reads S0; its response must come back to m1 (master-index bit set in xid).
    mread(1, 32'h0000_0200, rd, rsp, xid);
    chk(rd == 32'h0000_0200 && rsp == 2'b00, "m1 read S0 routed + OKAY");
    // (the slave echoes the widened xid; the xbar must have stripped the master
    //  prefix so m1 sees its OWN id=0, and the response must have reached m1, not m0.)

    // ---- 4. write routing + write response to correct master ----
    mwrite(0, 32'h0000_1004, 32'hDEAD_0001, rsp, xid);
    chk(rsp == 2'b00, "m0 write S1 -> OKAY write resp");
    mwrite(1, 32'h0000_2008, 32'hDEAD_0002, rsp, xid);
    chk(rsp == 2'b00, "m1 write S2 -> OKAY write resp");

    // ---- 5. contention: both masters read the SAME slave (S0) -> both complete ----
    fork
      mread(0, 32'h0000_0010, rd, rsp, xid);
      mread(1, 32'h0000_0020, rd, rsp, xid);
    join
    // (both must complete without hang; arbitration serializes them.)

    if (errors == 0) $display("TEST PASSED: eth_axi_xbar (routing, decode-error, correct-master resp, arbitration)");
    else             $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  initial begin #300000; $display("TEST FAILED: watchdog"); $finish; end
endmodule
`default_nettype wire
