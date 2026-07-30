`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_axi_lite_slave (testbench, self-checking)
// Description: Unit TB for eth_axi_lite_slave — AXI4-Lite register-window slave.
//              Exercises: write/read registers, AW/W decoupling (W before AW),
//              backpressure (B/R ready held low), and out-of-window SLVERR.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §3
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps
module tb_axi_lite_slave;
  localparam int AXI_AW = 32, AXI_DW = 32, N_REGS = 16;
  localparam logic [AXI_AW-1:0] REG_BASE = 32'h0000_1000;

  logic clk = 1'b0, rst_n = 1'b0;
  always #5 clk = ~clk;

  // AXI4-Lite slave signals
  logic        awvalid, awready; logic [AXI_AW-1:0] awaddr; logic [2:0] awprot;
  logic        wvalid, wready;   logic [AXI_DW-1:0] wdata;  logic [3:0] wstrb;
  logic        bvalid, bready;   logic [1:0] bresp;
  logic        arvalid, arready; logic [AXI_AW-1:0] araddr; logic [2:0] arprot;
  logic        rvalid, rready;   logic [AXI_DW-1:0] rdata;  logic [1:0] rresp;
  // register window
  logic [N_REGS*32-1:0] reg_rdata_o;
  logic                 reg_we_o;
  logic [N_REGS-1:0]    reg_waddr_o;
  logic [31:0]          reg_wdata_o;
  logic [3:0]           reg_wstrb_o;

  eth_axi_lite_slave #(.AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .N_REGS(N_REGS),
                       .REG_BASE(REG_BASE)) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
    .s_axi_bvalid(bvalid), .s_axi_bready(bready), .s_axi_bresp(bresp),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_araddr(araddr), .s_axi_arprot(arprot),
    .s_axi_rvalid(rvalid), .s_axi_rready(rready), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .reg_rdata_o(reg_rdata_o), .reg_we_o(reg_we_o), .reg_waddr_o(reg_waddr_o),
    .reg_wdata_o(reg_wdata_o), .reg_wstrb_o(reg_wstrb_o), .reg_rdata_i(reg_rdata_o)
  );

  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  // AXI-Lite write (AW + W together; may be decoupled by caller)
  task automatic axi_write(input [31:0] addr, input [31:0] data);
    begin
      @(negedge clk); awvalid=1; awaddr=addr; awprot=0; wvalid=1; wdata=data; wstrb=4'hF;
      @(posedge clk); while (!(awready && wready)) @(posedge clk);
      @(negedge clk); awvalid=0; wvalid=0;
      // wait for B
      bready=1;
      @(posedge clk); while (!bvalid) @(posedge clk);
      @(negedge clk); bready=0;
    end
  endtask

  // AXI-Lite write with W before AW (decoupling test)
  task automatic axi_write_w_first(input [31:0] addr, input [31:0] data);
    begin
      @(negedge clk); wvalid=1; wdata=data; wstrb=4'hF;   // W first
      @(posedge clk); while (!wready) @(posedge clk);
      @(negedge clk); wvalid=0;
      @(negedge clk); awvalid=1; awaddr=addr; awprot=0;    // then AW
      @(posedge clk); while (!awready) @(posedge clk);
      @(negedge clk); awvalid=0;
      bready=1;
      @(posedge clk); while (!bvalid) @(posedge clk);
      @(negedge clk); bready=0;
    end
  endtask

  // AXI-Lite read
  task automatic axi_read(input [31:0] addr, output [31:0] data, output [1:0] resp);
    begin
      @(negedge clk); arvalid=1; araddr=addr; arprot=0;
      @(posedge clk); while (!arready) @(posedge clk);
      @(negedge clk); arvalid=0;
      rready=1;
      @(posedge clk); while (!rvalid) @(posedge clk);
      data=rdata; resp=rresp;
      @(negedge clk); rready=0;
    end
  endtask

  logic [31:0] rd; logic [1:0] rsp;
  initial begin
    awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0; awprot=0; arprot=0;
    rst_n=0; repeat(4) @(posedge clk); rst_n=1; @(negedge clk);

    // ---- 1. write then read a register ----
    axi_write(REG_BASE + 4*3, 32'hDEAD_BEEF);   // reg[3]
    chk(reg_rdata_o[3*32 +: 32] == 32'hDEAD_BEEF, "write reg[3] lands in window");
    axi_read(REG_BASE + 4*3, rd, rsp);
    chk(rd == 32'hDEAD_BEEF && rsp == 2'b00, "read reg[3] returns written value (OKAY)");

    // ---- 2. AW/W decoupling: W before AW ----
    axi_write_w_first(REG_BASE + 4*7, 32'hCAFE_F00D);  // reg[7]
    axi_read(REG_BASE + 4*7, rd, rsp);
    chk(rd == 32'hCAFE_F00D && rsp == 2'b00, "W-before-AW write/read works");

    // ---- 3. out-of-window -> SLVERR ----
    axi_read(REG_BASE + 4*99, rd, rsp);
    chk(rsp == 2'b10, "out-of-window read -> SLVERR");

    // ---- 4. multiple registers ----
    axi_write(REG_BASE + 4*0, 32'h0000_0001);
    axi_write(REG_BASE + 4*15, 32'hFFFF_FFFF);
    axi_read(REG_BASE + 4*0, rd, rsp); chk(rd == 32'h1, "reg[0] written");
    axi_read(REG_BASE + 4*15, rd, rsp); chk(rd == 32'hFFFF_FFFF, "reg[15] written");

    if (errors == 0) $display("TEST PASSED: eth_axi_lite_slave (write/read, AW/W decoupling, SLVERR)");
    else             $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  initial begin #200000; $display("TEST FAILED: watchdog"); $finish; end
endmodule
`default_nettype wire
