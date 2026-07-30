`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      shell_tb_mgmt_packed (testbench, self-checking)
// Description: CAPSTONE (bit-PACKED path) — full management-plane dual-image
//              HOT-SWAP on real fabric_top RTL, but deploying the PRODUCTION
//              bit-packed frame format through frame_decoder (the C01 §5 / C03 §0
//              column controller) instead of the v0 cfg-addr-addressed direct
//              wire of tb_mgmt_hotswap.
//
//   host -> emri_regfile -> occ_top -> [frame bus] -> frame_decoder -> fabric_top
//
//              The OCC streams the column's bit-packed DATA words (frame_map
//              .pack_column: per-tile CB(108)->SB(120)->logic(CLB 320), LSB-first
//              + CRC16 tail); the decoder buffers the column, then walks the bit
//              fields issuing one fabric cfg write per config point. This is the
//              SAME observable outcome as tb_mgmt_hotswap (image A TFF toggles,
//              image B const1) but reached via the real bitgen frame format.
//
// Frame/hex bridge: the frames are produced by the frame_map.py SoT via
//   .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames
// (img_a_col0.hex = TFF, img_b_col0.hex = const1, both 2x2 col-0, 35 DATA words
// + 1 CRC16 tail). This TB $readmemh's those files (regenerate before running).
//
// Decoder handshake (this TB drives it explicitly): the decoder's `start_i` is
// pulsed for the duration of each OCC WRITE (and BLANK) stream so the decoder
// buffers the words as the OCC emits them, then auto-decodes when the stream
// completes. See the deploy_packed task. (A future EMRI v0.1 DECODE command would
// make the start self-contained in hardware; v0 uses this explicit handshake —
// see the report's ASSUMPTION list.)
// Maintainer:  BaiTian6641
// Created: 2026-07-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3 · ethereal-plan/components/
//              C01-fabric-核心单元.md §5 · C03-OCC组件.md §0 ·
//              ethereal-spec/fabric/heterogeneous-config-v0.md §3
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". Mirror of
//              tb_mgmt_hotswap's image A/B but via the PACKED frame_decoder path.
`timescale 1ns/1ps
module shell_tb_mgmt_packed;
  import emri_pkg::*;

  // ---- fabric params (2x2 all-CLB, matches tb_mgmt_hotswap / the helper) ----
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
  localparam int OBS_W = R*C*N;                 // 32
  localparam int MAX_WORDS = (R*548 + 31)/32;   // 35
  localparam int NWORDS    = 35;                // column_data_words(0)
  localparam int FRAME_WORDS = NWORDS + 1;      // + CRC16 tail in the .hex

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b1;                           // fabric user reset (config regs persist)
  always #5 clk = ~clk;                         // 100 MHz

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

  // ---- OCC <-> frame_decoder (frame bus) ----
  logic [15:0] fbus_addr;
  logic [31:0] fbus_wdata;
  logic        fbus_we;

  // ---- frame_decoder <-> fabric_top cfg port ----
  logic        dec_cfg_we;
  logic [15:0] dec_cfg_addr;
  logic [31:0] dec_cfg_data;
  logic        dec_start = 1'b0;
  logic        dec_busy, dec_done, dec_crc_error;

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
    // frame bus -> frame_decoder (production bit-packed path)
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(), .fbus_rdata_i(32'h0),   // no cfg readback on fabric_top (assert functional)
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locked_i(occ_region_locked)
  );

  frame_decoder #(
    .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN), .SELW(SELW),
    .TILE_TYPE({(R*C*8){1'b0}}), .MAX_WORDS(MAX_WORDS)
  ) u_dec (
    .clk_i(clk), .rst_ni(rst_n),
    .start_i(dec_start), .col_i(8'd0),
    .busy_o(dec_busy), .done_o(dec_done),
    .fbus_addr_i(fbus_addr), .fbus_wdata_i(fbus_wdata), .fbus_we_i(fbus_we),
    .frame_base_i(16'h0000),
    .cfg_we_o(dec_cfg_we), .cfg_addr_o(dec_cfg_addr), .cfg_data_o(dec_cfg_data),
    .crc_error_o(dec_crc_error)
  );

  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fabric (
    .clk_i(clk), .rst_ni(rst_n),
    .cfg_we_i(dec_cfg_we), .cfg_addr_i(dec_cfg_addr), .cfg_data_i(dec_cfg_data),
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
        if (i>8000) begin errors=errors+1; $display("  FAIL: OCC done_flag timeout"); code=2'd1; return; end
      end while (!s[3]);
      code = s[5:4];
    end
  endtask

  // Deploy a bit-packed column: BLANK (safe zeros) the column then WRITE the
  // packed image words; the decoder decodes each stream into fabric cfg writes.
  // Reads the module-level cur_img[] (iverilog cannot pass arrays to tasks).
  integer k;
  logic [1:0] dc;
  logic [31:0] cur_img[0:FRAME_WORDS-1];
  task automatic deploy_packed(input integer nwords);
    begin
      // ---- BLANK the column first (FABulous red-line) ----
      // Pulse dec_start ONCE: the decoder begins capturing the OCC stream
      // (blank = zero words -> safe CLB config written to fabric).
      emri_write(R_OCC_FRAME_ADDR, 32'h0);
      emri_write(R_OCC_WORD_COUNT, nwords);
      @(negedge clk); dec_start = 1'b1;      // 1-cycle pulse: begin capture
      @(negedge clk); dec_start = 1'b0;
      emri_cmd(OCC_BLANK, 4'd0);
      wait_occ_done(dc);
      chk(dc==2'd0, "BLANK done_code=DONE");
      // wait for the decoder to finish the BLANK decode (blank config applied)
      k=0;
      while (!dec_done && k<8000) begin @(posedge clk); k=k+1; end
      chk(dec_done==1'b1, "frame_decoder done after BLANK decode");
      @(negedge clk);

      // ---- WRITE the packed image ----
      emri_write(R_OCC_FRAME_ADDR, 32'h0);
      emri_write(R_OCC_WORD_COUNT, nwords);
      @(negedge clk); dec_start = 1'b1;      // 1-cycle pulse: begin capture
      @(negedge clk); dec_start = 1'b0;
      emri_cmd(OCC_WRITE, 4'd0);
      for (k=0; k<nwords; k=k+1) emri_push(cur_img[k]);
      wait_occ_done(dc);
      chk(dc==2'd0, "WRITE done_code=DONE");
      // wait for the decoder to finish the WRITE decode (image applied)
      k=0;
      while (!dec_done && k<8000) begin @(posedge clk); k=k+1; end
      chk(dec_done==1'b1, "frame_decoder done after WRITE decode");
      @(negedge clk);
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
  logic [31:0] img_a [0:FRAME_WORDS-1];
  logic [31:0] img_b [0:FRAME_WORDS-1];
  logic [31:0] rd;
  logic [1:0]  dc_unused;
  logic seen_one, seen_zero;
  integer i;

  initial begin
    $readmemh("generated/tb_frames/img_a_col0.hex", img_a);
    $readmemh("generated/tb_frames/img_b_col0.hex", img_b);
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 1. EMRI identity (mFSM mode) ----
    emri_read(R_MAGIC, rd);        chk(rd == EMRI_MAGIC, "MAGIC present");
    emri_read(R_CAPABILITIES, rd); chk(rd[CAPB_HAS_BMC] == 1'b0, "mFSM mode");

    // ============================================================
    // IMAGE A (bit-packed): TFF on tile(0,0) eLUT0 -> clb_out_obs[0] toggles
    // ============================================================
    for (i=0;i<FRAME_WORDS;i=i+1) cur_img[i]=img_a[i];
    deploy_packed(NWORDS);
    do_reset();                                   // clb_out[0] -> 0 (ff_rst_val=0)

    seen_one=1'b0; seen_zero=1'b0;
    $display("[A] packed TFF image - clb_out_obs[0] over cycles:");
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
      if (clb_out_obs[0] === 1'b1) seen_one=1'b1; else if (clb_out_obs[0] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && seen_zero, "image A (packed): clb_out[0] toggled (saw both 0 and 1)");

    // ============================================================
    // HOT-SWAP (bit-packed): BLANK + deploy image B (const1) -> constant 1
    // ============================================================
    for (i=0;i<FRAME_WORDS;i=i+1) cur_img[i]=img_b[i];
    deploy_packed(NWORDS);
    do_reset();                                   // clb_out[0] -> 1 (ff_rst_val=1)

    seen_one=1'b0; seen_zero=1'b0;
    $display("[B] packed const1 image - clb_out_obs[0] over cycles:");
    for (i=0;i<8;i=i+1) begin
      @(negedge clk);
      $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
      if (clb_out_obs[0] === 1'b1) seen_one=1'b1; else if (clb_out_obs[0] === 1'b0) seen_zero=1'b1;
    end
    chk(seen_one && !seen_zero, "image B (packed): clb_out[0] constant 1 (no toggle)");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: mgmt-plane dual-image hot-swap via PACKED frame_decoder (EMRI->OCC->frame_decoder->fabric_top)");
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
