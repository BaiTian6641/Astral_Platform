`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_frame_decoder (testbench, self-checking)
// Description: Unit TB for frame_decoder — proves the bit-packed column decode
//              against frame_map.py's pack_column() (the SoT) on a 2x2 all-CLB
//              fabric. A Python helper (ethereal-tools/tools/pack_tb_frames.py)
//              packs a KNOWN non-trivial column-0 config into dec_col0.hex; this
//              TB streams those words into the decoder over the OCC frame bus,
//              captures every cfg write the decoder emits, and checks a handful
//              of points (an eLUT truth-table word, IIB mux selects, a CB select,
//              an SB Wilton select, and an SB inject {dir,en}) against the values
//              the helper recorded in manifest.json.
//
//              The expected values are baked in below (mirroring manifest.json);
//              they were cross-checked against a Python golden model of the
//              decoder's CB->SB->logic walk. See docs/reports/report-P1-frame-
//              decoder-*.md for the mapping table.
// Maintainer:  BaiTian6641
// Created: 2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §5 · C03 §0 ·
//              ethereal-spec/fabric/heterogeneous-config-v0.md §3
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps
module tb_frame_decoder;

  // ---- fabric/frame params (2x2 all-CLB, matches the helper) ----
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
  localparam int MAX_WORDS = (R*548 + 31)/32;    // 35
  localparam int NWORDS    = 35;                 // column_data_words(0)
  localparam int FRAME_WORDS = NWORDS + 1;       // + CRC16 tail word in the .hex

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b1;
  always #5 clk = ~clk;                          // 100 MHz

  // ---- decoder stimulus ----
  logic        start = 1'b0;
  logic [7:0]  col = 8'd0;
  logic        busy, done, crc_error;
  logic [15:0] fbus_addr = 16'h0;
  logic [31:0] fbus_wdata = 32'h0;
  logic        fbus_we = 1'b0;
  logic [15:0] frame_base = 16'h0000;
  // ---- decoder cfg out ----
  logic        cfg_we;
  logic [15:0] cfg_addr;
  logic [31:0] cfg_data;

  // ---- DUT ----
  frame_decoder #(
    .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN), .SELW(SELW),
    .TILE_TYPE({(R*C*8){1'b0}}), .MAX_WORDS(MAX_WORDS)
  ) u_dec (
    .clk_i(clk), .rst_ni(rst_n),
    .start_i(start), .col_i(col), .busy_o(busy), .done_o(done),
    .fbus_addr_i(fbus_addr), .fbus_wdata_i(fbus_wdata), .fbus_we_i(fbus_we),
    .frame_base_i(frame_base),
    .cfg_we_o(cfg_we), .cfg_addr_o(cfg_addr), .cfg_data_o(cfg_data),
    .crc_error_o(crc_error)
  );

  // ---- frame data (from the helper): DATA words + CRC tail (tail unread) ----
  logic [31:0] frame [0:FRAME_WORDS-1];

  // ---- capture every cfg write ----
  localparam int MAX_WRITES = 256;
  logic [15:0] cap_addr [0:MAX_WRITES-1];
  logic [31:0] cap_data [0:MAX_WRITES-1];
  integer nwrites = 0;
  always @(posedge clk) begin
    if (cfg_we) begin
      cap_addr[nwrites] <= cfg_addr;
      cap_data[nwrites] <= cfg_data;
      nwrites <= nwrites + 1;
    end
  end

  // ---- helpers ----
  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  // find a captured write by address; returns data, sets the global `found`.
  // iverilog disallows output ports on functions, so `found` is a module var.
  logic found;
  function automatic logic [31:0] find_data(input logic [15:0] a);
    integer i;
    begin
      find_data = 32'hDEAD_BEEF;
      found = 1'b0;
      for (i = 0; i < MAX_WRITES; i = i + 1) begin
        if (i < nwrites && cap_addr[i] == a && !found) begin
          find_data = cap_data[i];
          found = 1'b1;
        end
      end
    end
  endfunction

  // cfg_addr constructor: {tile[TIW-1:0]@8, unit@6, intra@0}, TIW=2
  function automatic logic [15:0] mkaddr(input int tile, input int unit, input int intra);
    mkaddr = 16'((tile << 8) | (unit << 6) | intra);
  endfunction

  integer i;
  logic [31:0] d;

  initial begin
    $readmemh("generated/tb_frames/dec_col0.hex", frame);
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    chk(busy == 1'b0, "decoder idle at reset");
    chk(crc_error == 1'b0, "crc_error tied 0 in v0");

    // ---- start a decode for column 0 ----
    @(negedge clk); col = 8'd0; start = 1'b1;
    @(negedge clk); start = 1'b0;
    chk(busy == 1'b1, "decoder busy after start");

    // ---- stream the column's DATA words over the OCC frame bus ----
    for (i = 0; i < NWORDS; i = i + 1) begin
      @(negedge clk);
      fbus_we    = 1'b1;
      fbus_addr  = frame_base + 16'(i);
      fbus_wdata = frame[i];
      @(posedge clk);            // decoder captures on this edge
    end
    @(negedge clk); fbus_we = 1'b0; fbus_wdata = 32'h0;

    // ---- wait for decode to complete ----
    i = 0;
    while (!done && i < 5000) begin @(posedge clk); i = i + 1; end
    chk(done == 1'b1, "decoder asserted done");
    @(negedge clk);
    chk(busy == 1'b0, "decoder back to idle after done");

    // ---- expected total writes: 2 tiles x (18 CB + 48 SBmux + 8 SBinj + 40 CLB) ----
    $display("[dec] captured %0d cfg writes (expected 228)", nwrites);
    chk(nwrites == 228, "total cfg-write count = 228");

    // ---- spot-check the manifest points (tile 0 unless noted) ----
    // eLUT0 truth-table/config word (CLB unit0 intra0)
    d = find_data(mkaddr(0,0,0));
    chk(found && d == 32'h000A5A5A, "elut0 config word decoded");
    // IIB mux0 = sel18 (CLB unit0 intra8)
    d = find_data(mkaddr(0,0,8));
    chk(found && d == 32'd18, "iib_mux0 select decoded");
    // IIB mux31 = sel21 (CLB unit0 intra39)
    d = find_data(mkaddr(0,0,39));
    chk(found && d == 32'd21, "iib_mux31 select decoded");
    // CB cb_sel_0 = 5 (CB unit2 intra0)
    d = find_data(mkaddr(0,2,0));
    chk(found && d == 32'd5, "cb_sel_0 decoded");
    // CB cb_sel_17 = 40 (CB unit2 intra17)
    d = find_data(mkaddr(0,2,17));
    chk(found && d == 32'd40, "cb_sel_17 decoded");
    // SB mux_n_0 = 1 (SB unit1 intra0)
    d = find_data(mkaddr(0,1,0));
    chk(found && d == 32'd1, "mux_n_0 Wilton sel decoded");
    // SB mux_e_5 = 2 (SB unit1 intra 24+5=29)
    d = find_data(mkaddr(0,1,29));
    chk(found && d == 32'd2, "mux_e_5 Wilton sel decoded");
    // SB inject j=0 = {dir=2(E)@2:1, en=1@0} = 3'b101 = 5 (SB unit1 intra48)
    d = find_data(mkaddr(0,1,48));
    chk(found && d == 32'd5, "inj_0 {dir,en} demux decoded");

    // ---- tile(row1,col0) boundary crossing: row-major idx = r*C+c = 1*2+0 = 2 ----
    // (fabric_top MY_IDX = r*C+c; the decoder emits tile=2 for this tile.)
    // cb_sel_2=7 (tile2 CB unit2 intra2)
    d = find_data(mkaddr(2,2,2));
    chk(found && d == 32'd7, "tile(row1) cb_sel_2 decoded (tile-boundary offset)");
    // tile(row1,col0) elut7 = 0xF0F0F (CLB unit0 intra7)
    d = find_data(mkaddr(2,0,7));
    chk(found && d == 32'h000F0F0F, "tile(row1) elut7 decoded (tile-boundary offset)");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: frame_decoder decodes bit-packed column per frame_map.pack_column");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // watchdog
  initial begin
    #200000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
