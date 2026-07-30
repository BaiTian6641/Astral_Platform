`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      shell_tb_het_packed (testbench, self-checking)
// Description: HETEROGENEOUS packed capstone — deploy a bit-packed frame to a
//              HETEROGENEOUS fabric (col0 = [MEM_T(row0), CLB_T(row1)]) via the
//              full management plane: host -> emri_regfile -> occ_top ->
//              frame_decoder -> fabric_top(TILE_TYPE het). Proves the frame
//              decoder's MEM/DSP compound-point demux on real heterogeneous RTL.
//
//              Asserts (all through the packed path):
//                1. MEM demux: after deploy, the MEM tile's config regs hold
//                   mem_mode / mem_vbus_ctrl / mem_vd_i (backdoor peek into
//                   fabric_top's mem mode_r / va_r / vd_i_r via the obs port
//                   + unit-11 reads where available). Functional check is the
//                   CLB toggle (below); the MEM demux is checked by the decode
//                   unit TB + a backdoor probe here.
//                2. CLB function: image A (TFF on the CLB tile's eLUT0) toggles
//                   clb_out_obs[0]; image B (const1) -> constant 1. (Same
//                   observable as shell_tb_mgmt_packed but on the het fabric.)
//
//   The het CLB tile is (row1,col0) = row-major tile index r*C+c = 1*2+0 = 2,
//   so clb_out_obs_o[16:16+8] = tile2's CLB outputs; eLUT0 -> bit 16.
//
// Frames: generated/tb_frames_het/ (pack_tb_frames.py --het). col0 = 27 DATA
// words + CRC16 tail (frame_map.pack_column, MEM+CLB mix). This TB $readmemh's
// them (regenerate first: pack_tb_frames.py --het --out generated/tb_frames_het).
// Maintainer:  BaiTian6641
// Created: 2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/fabric/heterogeneous-config-v0.md §2/§3 ·
//              ethereal-plan/components/C02-fabric-异构tile.md §1.3 ·
//              docs/reports/report-P1-frame-decoder-20260730.md
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". Decoder
//              start_i is a PULSE (one per deploy), as in shell_tb_mgmt_packed.
`timescale 1ns/1ps
module shell_tb_het_packed;
  import emri_pkg::*;

  // ---- het fabric params (2x2: col0=[MEM,CLB], col1=[DSP,CLB]) ----
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
  localparam int OBS_W = R*C*N;                 // 32 (all-tile clb_out bits)
  // TILE_TYPE: idx r*C+c, 8-bit entries LSB-first. row0: [MEM(1),DSP(2)] (col0,col1)
  //            row1: [CLB(0),CLB(0)]. => entry0=MEM,1=DSP,2=CLB,3=CLB
  localparam logic [R*C*8-1:0] TILE_TYPE = {8'd0, 8'd0, 8'd2, 8'd1};  // {e3,e2,e1,e0}
  localparam int NWORDS    = 27;                // column_data_words(0) for het col0
  localparam int MAX_WORDS = 28;                // >= max column words
  localparam int FRAME_WORDS = NWORDS + 1;      // + CRC16 tail in the .hex

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b1;                           // fabric user reset (config regs persist)
  always #5 clk = ~clk;                         // 100 MHz

  // ---- EMRI host slave port ----
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

  // ---- OCC <-> frame_decoder ----
  logic [15:0] fbus_addr; logic [31:0] fbus_wdata; logic fbus_we;

  // ---- frame_decoder <-> fabric cfg ----
  logic        dec_cfg_we; logic [15:0] dec_cfg_addr; logic [31:0] dec_cfg_data;
  logic        dec_start = 1'b0; logic dec_busy, dec_done, dec_crc_error;

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
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(), .fbus_rdata_i(32'h0),
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locked_i(occ_region_locked)
  );

  frame_decoder #(
    .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN), .SELW(SELW),
    .TILE_TYPE(TILE_TYPE), .MAX_WORDS(MAX_WORDS)
  ) u_dec (
    .clk_i(clk), .rst_ni(rst_n),
    .start_i(dec_start), .col_i(8'd0),
    .busy_o(dec_busy), .done_o(dec_done),
    .fbus_addr_i(fbus_addr), .fbus_wdata_i(fbus_wdata), .fbus_we_i(fbus_we),
    .frame_base_i(16'h0000),
    .cfg_we_o(dec_cfg_we), .cfg_addr_o(dec_cfg_addr), .cfg_data_o(dec_cfg_data),
    .crc_error_o(dec_crc_error)
  );

  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN),
               .TILE_TYPE(TILE_TYPE)) u_fabric (
    .clk_i(clk), .rst_ni(rst_n),
    .cfg_we_i(dec_cfg_we), .cfg_addr_i(dec_cfg_addr), .cfg_data_i(dec_cfg_data),
    .clb_out_obs_o(clb_out_obs), .mem_vd_obs_o(mem_vd_obs), .dsp_vp_obs_o(dsp_vp_obs)
  );

  // ---- host tasks (mirror shell_tb_mgmt_packed) ----
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
        if (i>8000) begin errors=errors+1; $display("  FAIL: OCC done_flag timeout"); code=2'd1; return; end
      end while (!s[3]);
      code = s[5:4];
    end
  endtask

  // Deploy a bit-packed column (BLANK then WRITE), decoder start pulsed per deploy.
  integer k;
  logic [1:0] dc;
  logic [31:0] cur_img[0:FRAME_WORDS-1];
  task automatic deploy_packed(input integer nwords);
    begin
      // BLANK (safe zeros -> MEM mode=0, CLB tt=0; fabric goes quiet)
      emri_write(R_OCC_FRAME_ADDR, 32'h0);
      emri_write(R_OCC_WORD_COUNT, nwords);
      @(negedge clk); dec_start = 1'b1;
      @(negedge clk); dec_start = 1'b0;
      emri_cmd(OCC_BLANK, 4'd0);
      wait_occ_done(dc);
      chk(dc==2'd0, "BLANK done_code=DONE");
      k=0; while (!dec_done && k<8000) begin @(posedge clk); k=k+1; end
      chk(dec_done==1'b1, "frame_decoder done after BLANK decode");
      @(negedge clk);

      // WRITE the packed image
      emri_write(R_OCC_FRAME_ADDR, 32'h0);
      emri_write(R_OCC_WORD_COUNT, nwords);
      @(negedge clk); dec_start = 1'b1;
      @(negedge clk); dec_start = 1'b0;
      emri_cmd(OCC_WRITE, 4'd0);
      for (k=0; k<nwords; k=k+1) emri_push(cur_img[k]);
      wait_occ_done(dc);
      chk(dc==2'd0, "WRITE done_code=DONE");
      k=0; while (!dec_done && k<8000) begin @(posedge clk); k=k+1; end
      chk(dec_done==1'b1, "frame_decoder done after WRITE decode");
      @(negedge clk);
    end
  endtask

  task automatic do_reset;
    begin
      @(negedge clk); rst_n=1'b0;
      @(negedge clk); @(negedge clk); rst_n=1'b1;
    end
  endtask

  // ---- test ----
  logic [31:0] img_a [0:FRAME_WORDS-1];
  logic [31:0] img_b [0:FRAME_WORDS-1];
  logic [31:0] rd;
  logic seen_one, seen_zero;
  integer i;
  // het CLB tile = row-major idx 2 -> its 8 clb_out bits at clb_out_obs[16 +: 8];
  // eLUT0 = bit 16.
  localparam int CLB_OBS_BIT = 16;

  initial begin
    $readmemh("generated/tb_frames_het/het_col0_img_a.hex", img_a);
    $readmemh("generated/tb_frames_het/het_col0_img_b.hex", img_b);
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 1. EMRI identity ----
    emri_read(R_MAGIC, rd);        chk(rd == EMRI_MAGIC, "MAGIC present");
    emri_read(R_CAPABILITIES, rd); chk(rd[CAPB_HAS_BMC] == 1'b0, "mFSM mode");

    // ============================================================
    // IMAGE A (het packed): TFF on the CLB tile (idx2) eLUT0 -> toggles
    // (the MEM tile gets a benign mode + a demux-probing vbus_ctrl/vd_i)
    // ============================================================
    for (i=0;i<FRAME_WORDS;i=i+1) cur_img[i]=img_a[i];
    deploy_packed(NWORDS);
    do_reset();

    seen_one=1'b0; seen_zero=1'b0;
    $display("[A/het] TFF image - clb_out_obs[%0d] over cycles:", CLB_OBS_BIT);
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[%0d] = %b", i, CLB_OBS_BIT, clb_out_obs[CLB_OBS_BIT]);
      if (clb_out_obs[CLB_OBS_BIT] === 1'b1) seen_one=1'b1;
      else if (clb_out_obs[CLB_OBS_BIT] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && seen_zero, "image A (het packed): CLB tile eLUT0 toggled");

    // ---- MEM demux backdoor probe: the MEM tile (row0,col0 -> g_row[0].g_col[0]
    //      .g_mem_t) decoded its config regs from the packed frame.
    //      mem_t.mode_r = 0x0001 (intra0), mem_va_r = 5 / mem_ven_r = 1 (intra1).
    chk(u_fabric.g_row[0].g_col[0].g_mem_t.u_mem_t.mode_r == 16'h0001,
        "MEM demux: mem_mode_r decoded (0x0001, intra0)");
    chk(u_fabric.g_row[0].g_col[0].g_mem_t.mem_va_r == 14'd5,
        "MEM demux: mem_va_r decoded (5, from mem_vbus_ctrl[13:0])");
    chk(u_fabric.g_row[0].g_col[0].g_mem_t.mem_ven_r == 1'b1,
        "MEM demux: mem_ven_r decoded (1, from mem_vbus_ctrl[16])");

    // ============================================================
    // HOT-SWAP (het packed): BLANK + image B (const1) -> constant 1
    // ============================================================
    for (i=0;i<FRAME_WORDS;i=i+1) cur_img[i]=img_b[i];
    deploy_packed(NWORDS);
    do_reset();

    seen_one=1'b0; seen_zero=1'b0;
    $display("[B/het] const1 image - clb_out_obs[%0d] over cycles:", CLB_OBS_BIT);
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[%0d] = %b", i, CLB_OBS_BIT, clb_out_obs[CLB_OBS_BIT]);
      if (clb_out_obs[CLB_OBS_BIT] === 1'b1) seen_one=1'b1;
      else if (clb_out_obs[CLB_OBS_BIT] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && !seen_zero, "image B (het packed): CLB tile eLUT0 constant 1");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: het mgmt-plane packed hot-swap (EMRI->OCC->frame_decoder->het fabric_top; MEM demux + CLB function)");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // watchdog
  initial begin
    #5000000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
