`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_mgmt_hotswap (testbench, self-checking)
// Description: CAPSTONE — full management-plane dual-image HOT-SWAP on real
//              fabric_top RTL. Wires emri_regfile -> occ_top -> fabric_top, with
//              the OCC frame bus driving fabric_top's cfg port DIRECTLY (cfg-addr-
//              addressed frame format: each 32-bit frame word = one config reg at
//              cfg_addr = frame_base + word_index; the OCC already increments
//              fbus_addr, so no bit-unpacking decoder is needed for v0).
//
//              Deploys image A (a self-contained TFF: clb_out[0] toggles) through
//              the management plane (host -> EMRI -> OCC -> fabric), runs it and
//              observes the toggle, then BLANKs (FABulous red-line) and deploys
//              image B (constant-1) and observes clb_out[0] go constant. Proves
//              runtime reconfiguration driven entirely by the management plane on
//              the actual fabric RTL — the Phase-1 "minimal loop" milestone.
//
// Frame format (v0, cfg-addr-addressed): OCC_FRAME_ADDR = base cfg_addr,
// OCC_WORD_COUNT = N; the host streams N words; word i lands at
// cfg_addr = base + i. BLANK streams N zero words (safe for CLB: tt=0,
// mux=0=disconnect). This is NOT the production bit-packed frame_map format
// (which needs a column-controller decoder for density); it is the v0 sim-loop
// format that trivially matches fabric_top's cfg interface. The bit-packed
// decoder is a documented follow-up.
// Maintainer:  BaiTian6641
// Created: 2026-07-29
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3, ethereal-plan/components/C01-fabric-核心单元.md §5, C03 §0
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". Mirrors
//              tb_hotswap's image A/B (TFF / const1) but driven via EMRI/OCC.
`timescale 1ns/1ps
module tb_mgmt_hotswap;
  import emri_pkg::*;

  // ---- fabric params (2x2 all-CLB, matches tb_hotswap) ----
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18;
  localparam int OBS_W = R*C*N;          // 32

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b1;                    // fabric user reset (config regs persist)
  always #5 clk = ~clk;                  // 100 MHz

  // ---- EMRI host slave port (the TB is the host) ----
  logic        h_req = 1'b0;
  logic        h_we  = 1'b0;
  logic [1:0]  h_op  = SPI_OP_RD;
  logic [15:0] h_addr= 16'h0;
  logic [31:0] h_wd  = 32'h0;
  logic [31:0] h_rd;
  logic        h_ready;

  // ---- EMRI <-> OCC ----
  logic [1:0]  occ_cmd; logic occ_cmd_valid, occ_cmd_ready;
  logic [15:0] occ_frame_addr, occ_word_count;
  logic [31:0] occ_wdata; logic occ_wdata_valid, occ_wdata_ready;
  logic [2:0]  occ_status; logic occ_crc_error, occ_region_locked;

  // ---- OCC <-> fabric_top cfg port (the frame "decoder" = direct wire, v0) ----
  logic [15:0] fbus_addr;
  logic [31:0] fbus_wdata;
  logic        fbus_we;

  // ---- fabric observation ----
  logic [OBS_W-1:0]      clb_out_obs;
  logic [R*C*32-1:0]     mem_vd_obs;
  logic [R*C*48-1:0]     dsp_vp_obs;

  // ---- DUTs ----
  emri_regfile #(
    .HAS_BMC(1'b0), .NUM_REGIONS(2), .PLATFORM_ID(32'h0000_0000),
    .REGION0_INFO(32'h0202_0010), .REGION1_INFO(32'h0202_0010)
  ) u_emri (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(h_req), .host_we_i(h_we), .host_op_i(h_op),
    .host_addr_i(h_addr), .host_wdata_i(h_wd),
    .host_rdata_o(h_rd), .host_ready_o(h_ready),
    .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid), .occ_cmd_ready_i(occ_cmd_ready),
    .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
    .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid), .occ_wdata_ready_i(occ_wdata_ready),
    .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
    .occ_region_locked_o(occ_region_locked)
  );

  occ_top #(.ADDR_W(16), .DATA_W(32)) u_occ (
    .clk_i(clk), .rst_ni(rst_n),
    .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
    .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
    .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid), .wdata_ready_o(occ_wdata_ready),
    // frame bus -> fabric_top cfg port (v0 direct; no bit-unpacking decoder)
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(), .fbus_rdata_i(32'h0),   // fabric_top has no cfg readback (assert functional)
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locked_i(occ_region_locked)
  );

  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fabric (
    .clk_i(clk), .rst_ni(rst_n),
    .cfg_we_i(fbus_we), .cfg_addr_i(fbus_addr), .cfg_data_i(fbus_wdata),
    .clb_out_obs_o(clb_out_obs), .mem_vd_obs_o(mem_vd_obs), .dsp_vp_obs_o(dsp_vp_obs)
  );

  // ============================================================
  // Host driver tasks (EMRI host slave port) + helpers
  // ============================================================
  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  task automatic emri_read(input logic [15:0] a, output logic [31:0] d);
    begin
      @(negedge clk); h_req=1'b1; h_we=1'b0; h_op=SPI_OP_RD; h_addr=a; h_wd=32'h0;
      @(posedge clk); while (!h_ready) @(posedge clk);
      d = h_rd; @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic emri_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk); h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=a; h_wd=d;
      @(posedge clk); while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic emri_cmd(input logic [1:0] cmd, input logic [3:0] region);
    begin
      @(negedge clk); h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=R_OCC_CMD;
      h_wd = (1<<OCC_CMD_START) | ((region & 4'hF) << 2) | cmd;
      @(posedge clk); while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic emri_push(input logic [31:0] d);
    begin
      @(negedge clk); h_req=1'b1; h_we=1'b1; h_op=SPI_OP_OCC_PUSH; h_addr=R_OCC_WDATA; h_wd=d;
      @(posedge clk); while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic wait_occ_done(output logic [1:0] code);
    integer i; logic [31:0] s;
    begin
      i=0; code=2'd0;
      do begin
        emri_read(R_OCC_STATUS, s); i=i+1;
        if (i>4000) begin errors=errors+1; $display("  FAIL: OCC done_flag timeout"); code=2'd1; return; end
      end while (!s[3]);
      code = s[5:4];
    end
  endtask

  // Deploy a frame: BLANK the range then WRITE the words (FABulous red-line).
  // Reads the module-level cur_img[] array (iverilog cannot pass whole arrays
  // to tasks). Set cur_img + call deploy(base, nwords).
  logic [31:0] cur_img[0:15];
  task automatic deploy(input logic [15:0] base, input integer nwords);
    integer k; logic [1:0] dc;
    begin
      // BLANK (safe zeros) the target range first
      emri_write(R_OCC_FRAME_ADDR, {16'h0, base});
      emri_write(R_OCC_WORD_COUNT, nwords);
      emri_cmd(OCC_BLANK, 4'd0);
      wait_occ_done(dc);
      chk(dc==2'd0, "BLANK done_code=DONE");
      // WRITE the image words
      emri_write(R_OCC_FRAME_ADDR, {16'h0, base});
      emri_write(R_OCC_WORD_COUNT, nwords);
      emri_cmd(OCC_WRITE, 4'd0);
      for (k=0; k<nwords; k=k+1) emri_push(cur_img[k]);
      wait_occ_done(dc);
      chk(dc==2'd0, "WRITE done_code=DONE");
    end
  endtask

  // pulse fabric user reset (eLUT FFs -> ff_rst_val; config regs persist)
  task automatic do_reset;
    begin
      @(negedge clk); rst_n=1'b0;
      @(negedge clk); @(negedge clk); rst_n=1'b1;
    end
  endtask

  // ============================================================
  // Test
  // ============================================================
  logic [31:0] rd;
  logic [1:0]  dc;
  logic seen_one, seen_zero;
  integer i;

  initial begin
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 1. EMRI identity (mFSM mode) ----
    emri_read(R_MAGIC, rd);        chk(rd == EMRI_MAGIC, "MAGIC present");
    emri_read(R_CAPABILITIES, rd); chk(rd[CAPB_HAS_BMC] == 1'b0, "mFSM mode");

    // ============================================================
    // IMAGE A: TFF on tile(0,0) eLUT4[0]  -> clb_out_obs[0] toggles
    // tile0 CLB intra 0..11 = eLUT0(TFF) + eLUT1-7(0) + IIB mux0-3(sel18)
    // eLUT0 TFF: tt=0x5555, ff_en=1, ff_rst_en=1, ff_rst_val=0 -> 0x0005555C
    // IIB mux sel=18 (clb_out[0] feedback) -> 0x12
    // ============================================================
    for (i=0;i<16;i=i+1) cur_img[i]=32'h0;
    cur_img[0]=32'h0005555C;                       // eLUT0 TFF
    for (i=8;i<=11;i=i+1) cur_img[i]=32'h00000012; // IIB mux0-3 = feedback sel18
    deploy(16'h0000, 12);
    do_reset();                                   // clb_out[0] -> 0 (ff_rst_val=0)

    // run A: expect toggle (see both 0 and 1)
    seen_one=1'b0; seen_zero=1'b0;
    $display("[A] TFF image - clb_out_obs[0] over cycles:");
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
      if (clb_out_obs[0] === 1'b1) seen_one=1'b1; else if (clb_out_obs[0] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && seen_zero, "image A: clb_out[0] toggled (saw both 0 and 1)");

    // ============================================================
    // HOT-SWAP: BLANK + deploy image B (const1) -> clb_out_obs[0] = const 1
    // tile0 CLB intra 0 = eLUT0 const1: tt=0xFFFF, ff_en=1, ff_rst_en=1, ff_rst_val=1 -> 0x000FFFFE
    // ============================================================
    for (i=0;i<16;i=i+1) cur_img[i]=32'h0;
    cur_img[0]=32'h000FFFFE;                       // eLUT0 const1
    deploy(16'h0000, 1);
    do_reset();                                   // clb_out[0] -> 1 (ff_rst_val=1)

    // run B: expect constant 1
    seen_one=1'b0; seen_zero=1'b0;
    $display("[B] const1 image - clb_out_obs[0] over cycles:");
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
      if (clb_out_obs[0] === 1'b1) seen_one=1'b1; else if (clb_out_obs[0] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && !seen_zero, "image B: clb_out[0] constant 1 (no toggle)");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: management-plane dual-image hot-swap on real fabric (EMRI->OCC->fabric_top)");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // watchdog
  initial begin
    #500000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
