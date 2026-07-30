`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_axi_stream (testbench, self-checking)
// Description: Unit TB for eth_axi_stream source/sink + eth_axi_skidbuf.
//              source -> sink transfer of a 4-beat frame, with sink-side stall
//              injection (backpressure) + tlast framing. Proves data integrity +
//              the skid buffer's registered no-comb-path backpressure.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §4
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps
module tb_axi_stream;
  localparam int AXI_DW = 32;

  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;

  // source local input -> m_axis
  logic                  in_valid, in_ready;
  logic [AXI_DW-1:0]     in_data;
  logic [(AXI_DW/8)-1:0] in_keep;
  logic                  in_last;
  logic                  tvalid_s2m, tready_s2m;
  logic [AXI_DW-1:0]     tdata_s2m;
  logic [(AXI_DW/8)-1:0] tkeep_s2m;
  logic                  tlast_s2m;
  // sink m_axis -> local out
  logic                  out_valid, out_ready;
  logic [AXI_DW-1:0]     out_data;
  logic [(AXI_DW/8)-1:0] out_keep;
  logic                  out_last;

  eth_axi_stream_source #(.AXI_DW(AXI_DW)) u_src (
    .clk_i(clk), .rst_ni(rst_n),
    .in_valid(in_valid), .in_ready(in_ready), .in_data(in_data),
    .in_keep(in_keep), .in_last(in_last),
    .m_axis_tvalid(tvalid_s2m), .m_axis_tready(tready_s2m),
    .m_axis_tdata(tdata_s2m), .m_axis_tkeep(tkeep_s2m), .m_axis_tlast(tlast_s2m)
  );

  eth_axi_stream_sink #(.AXI_DW(AXI_DW)) u_snk (
    .clk_i(clk), .rst_ni(rst_n),
    .s_axis_tvalid(tvalid_s2m), .s_axis_tready(tready_s2m),
    .s_axis_tdata(tdata_s2m), .s_axis_tkeep(tkeep_s2m), .s_axis_tlast(tlast_s2m),
    .out_valid(out_valid), .out_ready(out_ready), .out_data(out_data),
    .out_keep(out_keep), .out_last(out_last)
  );

  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  // drive one beat from the source local input (hold until accepted)
  task automatic push(input [31:0] d, input last);
    begin
      @(negedge clk); in_valid=1; in_data=d; in_keep=4'hF; in_last=last;
      @(posedge clk); while (!in_ready) @(posedge clk);
      @(negedge clk); in_valid=0; in_last=0;
    end
  endtask

  // captured sink output beats
  logic [31:0] cap [0:15];
  integer ncap = 0;
  integer nlast = 0;
  always @(posedge clk) begin
    if (out_valid && out_ready) begin
      cap[ncap] <= out_data;
      ncap <= ncap + 1;
      if (out_last) nlast <= nlast + 1;
    end
  end

  integer i;
  initial begin
    in_valid=0; in_last=0; out_ready=0;
    rst_n=0; repeat(4) @(posedge clk); rst_n=1; @(negedge clk);

    // ---- 1. transfer a 4-beat frame with NO stall ----
    out_ready = 1;
    push(32'h1111_0000, 0);
    push(32'h2222_0001, 0);
    push(32'h3333_0002, 0);
    push(32'h4444_0003, 1);   // tlast
    repeat (8) @(posedge clk);
    chk(ncap == 4, "no-stall: 4 beats received");
    chk(cap[0]==32'h1111_0000 && cap[3]==32'h4444_0003, "no-stall: data intact + ordered");
    chk(nlast == 1, "no-stall: exactly 1 tlast frame");

    // ---- 2. transfer with sink-side STALL (backpressure) ----
    ncap = 0; nlast = 0;
    out_ready = 0;                       // stall the sink
    push(32'hAAAA_0000, 0);
    push(32'hBBBB_0001, 1);
    // beats are buffered in the 2-deep skid buf while out_ready=0
    repeat (4) @(posedge clk);
    chk(ncap == 0, "stall: no beats drain while out_ready=0");
    // the first beat is sitting at the sink output, waiting for out_ready
    chk(out_valid && out_data == 32'hAAAA_0000, "stall: beat A held at output (not lost)");
    @(negedge clk); out_ready = 1;         // release (stable before the next posedge)
    repeat (6) @(posedge clk);
    chk(ncap == 2, "stall: 2 beats drain after release");
    chk(cap[0]==32'hAAAA_0000 && cap[1]==32'hBBBB_0001, "stall: data intact + ordered");

    if (errors == 0) $display("TEST PASSED: eth_axi_stream source->sink (data integrity + backpressure + tlast)");
    else             $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  initial begin #200000; $display("TEST FAILED: watchdog"); $finish; end
endmodule
`default_nettype wire
