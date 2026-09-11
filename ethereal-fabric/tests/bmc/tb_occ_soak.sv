`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_occ_soak (testbench, self-checking)
// Description: E1-DMO2 OCC-level SOAK — the literal 2x10000 hot-swap count at
//              the configuration/storage layer: SWAPS BLANK->WRITE->READBACK
//              swaps alternating the two regions (10000 per region), every
//              swap verified three ways:
//                1) OCC READBACK against the v0.5 expected-CRC gate (the sticky
//                   crc_error must stay 0, done_code must be DONE);
//                2) column_cfg_ram shadow model — the target region's words
//                   equal the streamed image, the NEIGHBOR region's words stay
//                   byte-identical (zero cross-region corruption);
//                3) status invariants (done_flag + done_code every swap).
//
//              Why this layer: a daemon-level 2x10000 would cost 20000 Ed25519
//              verifies (~22-32 days wall in sim, verify-bound); the OCC layer
//              runs the same swap semantics in seconds. The daemon-level
//              rotation integration is proven by tb_hotswap_stress (scaled
//              rounds); the literal daemon count is silicon scope
//              (report-E1-DMO2).
//
//              DUT chain: TB host port -> emri_regfile (mFSM mode) -> occ_top
//                         -> column_cfg_ram (readback + shadow model)
// Maintainer:  BaiTian6641
// Created:     2026-09-11
// Tags:        TESTBENCH
// Plan-Ref:    docs/ethereal-tasks.yaml E1-DMO2; ethereal-spec/control/emri-v0.md
//              §3.1.1 (expected-CRC gate) + §3.3 (packed deploys)
// Notes:       Verilator --binary --timing (small design, no NEORV32 netlist).
//              SWAPS default 20000 (= 2 regions x 10000 swaps); override with
//              -DSOAK_SWAPS=<n> for a smoke run. Image words come from
//              gen_daemon_vectors.py --svh-packed (same signed images as the
//              daemon TBs; the soak drives the OCC directly).
`timescale 1ns/1ps

module tb_occ_soak;
  import emri_pkg::*;
  // Packed image DATA words + signatures (same generated contract as the
  // daemon TBs; the soak uses the word lists and drives the OCC directly).
  `include "tb_daemon_packed_vectors.svh"

  localparam int ADDR_W = 16;
  localparam int DATA_W = 32;
  localparam int NWORDS = DAEMON_IMGP_NWORDS;   // 34 DATA words (2x2 v2c)
  localparam int REGIONS = 2;
`ifdef SOAK_SWAPS
  localparam int SWAPS = `SOAK_SWAPS;
`else
  localparam int SWAPS = 20000;                 // 2 regions x 10000 swaps
`endif

  // region r's per-column frame base (daemon convention: OCC_FRAME_ADDR v0.6 {region[15:12],col[11:8],word[7:0]} — region<<12 | col<<8, col == r)
  function automatic logic [15:0] reg_base(input int r);
      reg_base = 16'((r << 12) | (r << 8));
  endfunction

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;  // 100 MHz

  // ---- EMRI host slave port (the TB is the host) ----
  logic        h_req = 1'b0;
  logic        h_we  = 1'b0;
  logic [1:0]  h_op  = SPI_OP_RD;
  logic [15:0] h_addr = 16'h0;
  logic [31:0] h_wd  = 32'h0;
  logic [31:0] h_rd;
  logic        h_ready;

  // ---- EMRI <-> OCC master ----
  logic [1:0]  occ_cmd;
  logic        occ_cmd_valid;
  logic        occ_cmd_ready;
  logic [15:0] occ_frame_addr;
  logic [15:0] occ_word_count;
  logic [31:0] occ_wdata;
  logic        occ_wdata_valid;
  logic        occ_wdata_ready;
  logic [2:0]  occ_status;
  logic        occ_crc_error;
  logic        occ_region_locked;

  // ---- OCC <-> column_cfg_ram (frame bus) ----
  logic [ADDR_W-1:0] fbus_addr;
  logic [DATA_W-1:0] fbus_wdata;
  logic              fbus_we;
  logic              fbus_re;
  logic [DATA_W-1:0] fbus_rdata;

  logic [31:0] occ_expect_crc_w;   // v0.5 §3.1.1
  logic [31:0] occ_crc_result_w;   // v0.5 §3.1.1

  emri_regfile #(
    .HAS_BMC(1'b0), .NUM_REGIONS(REGIONS),
    .PLATFORM_ID(32'h0000_0000),
    .REGION0_INFO(32'h0202_0010), .REGION1_INFO(32'h0202_0010)
  ) u_emri (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(h_req), .host_we_i(h_we), .host_op_i(h_op),
    .host_addr_i(h_addr), .host_wdata_i(h_wd),
    .host_rdata_o(h_rd), .host_ready_o(h_ready),
    .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid),
    .occ_cmd_ready_i(occ_cmd_ready),
    .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
    .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
    .occ_wdata_ready_i(occ_wdata_ready),
    .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
    .occ_region_locked_o(occ_region_locked),
    .occ_expect_crc_o(occ_expect_crc_w),
    .occ_crc_result_i(occ_crc_result_w)
  );

  occ_top #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_occ (
    .clk_i(clk), .rst_ni(rst_n),
    .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
    .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
    .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid),
    .wdata_ready_o(occ_wdata_ready),
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locked_i(occ_region_locked),
    .expect_crc_i(occ_expect_crc_w),
    .crc_result_o(occ_crc_result_w)
  );

  column_cfg_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(8192)) u_ram (
    .clk(clk), .we(fbus_we), .re(fbus_re), .addr(fbus_addr),
    .wdata(fbus_wdata), .rdata(fbus_rdata)
  );

  // ============================================================
  // Host driver tasks (mirror the EMRI host slave port protocol)
  // ============================================================
  integer errors = 0;

  task automatic chk(input logic cond, input string msg);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s", msg);
      end
    end
  endtask

  task automatic emri_read(input logic [15:0] a, output logic [31:0] d);
    begin
      @(negedge clk);
      h_req = 1'b1; h_we = 1'b0; h_op = SPI_OP_RD; h_addr = a; h_wd = 32'h0;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      d = h_rd;
      @(negedge clk); h_req = 1'b0;
    end
  endtask

  task automatic emri_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      h_req = 1'b1; h_we = 1'b1; h_op = SPI_OP_WR; h_addr = a; h_wd = d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req = 1'b0;
    end
  endtask

  task automatic emri_cmd(input logic [1:0] cmd, input logic [3:0] region);
    begin
      @(negedge clk);
      h_req = 1'b1; h_we = 1'b1; h_op = SPI_OP_WR; h_addr = R_OCC_CMD;
      h_wd = (1 << OCC_CMD_START) | ((region & 4'hF) << 2) | cmd;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req = 1'b0;
    end
  endtask

  task automatic emri_push(input logic [31:0] d);
    begin
      @(negedge clk);
      h_req = 1'b1; h_we = 1'b1; h_op = SPI_OP_OCC_PUSH; h_addr = R_OCC_WDATA;
      h_wd = d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req = 1'b0;
    end
  endtask

  task automatic wait_occ_done(output logic [1:0] code);
    integer i;
    logic [31:0] s;
    begin
      i = 0;
      code = 2'd0;
      do begin
        emri_read(R_OCC_STATUS, s);
        i = i + 1;
        if (i > 2000) begin
          errors = errors + 1;
          $display("  FAIL: timeout waiting OCC done_flag (status=%h)", s);
          code = 2'd1;
          return;
        end
      end while (!s[3]);
      code = s[5:4];
    end
  endtask

  // ============================================================
  // Soak
  // ============================================================
  logic [31:0] img [0:1][0:NWORDS-1];        // {image A, image B}
  logic [31:0] shadow [0:REGIONS-1][0:NWORDS-1];
  logic [31:0] rd;
  logic [1:0]  dc;
  int          swap_idx;
  int          rgn;
  int          sel;
  int          total_mismatch;
  integer      j;

  task automatic check_region(input int r, input string tag);
    integer m;
    integer bad;
    begin
      bad = 0;
      for (m = 0; m < NWORDS; m = m + 1)
        if (u_ram.mem[reg_base(r) + m] !== shadow[r][m]) bad = bad + 1;
      if (bad != 0) begin
        total_mismatch = total_mismatch + bad;
        $display("  FAIL: %0s (%0d word mismatch)", tag, bad);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    h_req = 1'b0;
    h_we = 1'b0;
    h_op = SPI_OP_RD;
    h_addr = 16'h0;
    h_wd = 32'h0;
    total_mismatch = 0;

    for (j = 0; j < NWORDS; j = j + 1) begin
      img[0][j] = DAEMON_IMGP_WORDS[j];
      img[1][j] = DAEMON_IMGP_B_WORDS[j];
      shadow[0][j] = 32'h0;
      shadow[1][j] = 32'h0;
    end

    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- zero both regions (shadow baseline; RAM reads X before any write) ----
    for (rgn = 0; rgn < REGIONS; rgn = rgn + 1) begin
      emri_write(R_OCC_FRAME_ADDR, {16'h0, reg_base(rgn)});
      emri_write(R_OCC_WORD_COUNT, 32'(NWORDS));
      emri_cmd(OCC_BLANK, 4'(rgn));
      wait_occ_done(dc);
      chk(dc == 2'd0, "baseline BLANK done_code=DONE");
    end

    $display("[soak] %0d swaps (2 regions x %0d), %0d DATA words/column",
             SWAPS, SWAPS / 2, NWORDS);

    for (swap_idx = 0; swap_idx < SWAPS; swap_idx = swap_idx + 1) begin
      rgn = swap_idx % REGIONS;
      sel = (swap_idx / REGIONS) % 2;        // alternate A/B per region

      // ---- BLANK ----
      emri_write(R_OCC_FRAME_ADDR, {16'h0, reg_base(rgn)});
      emri_write(R_OCC_WORD_COUNT, 32'(NWORDS));
      emri_cmd(OCC_BLANK, 4'(rgn));
      wait_occ_done(dc);
      chk(dc == 2'd0, "swap: BLANK done_code=DONE");

      // ---- WRITE the selected image ----
      emri_write(R_OCC_FRAME_ADDR, {16'h0, reg_base(rgn)});
      emri_write(R_OCC_WORD_COUNT, 32'(NWORDS));
      emri_cmd(OCC_WRITE, 4'(rgn));
      for (j = 0; j < NWORDS; j = j + 1) emri_push(img[sel][j]);
      wait_occ_done(dc);
      chk(dc == 2'd0, "swap: WRITE done_code=DONE");

      // ---- capture the write CRC + arm the v0.5 gate ----
      emri_read(R_OCC_CRC_RESULT, rd);
      emri_write(R_OCC_EXPECT_CRC, rd);

      // ---- READBACK (CRC compare against the armed value) ----
      emri_write(R_OCC_FRAME_ADDR, {16'h0, reg_base(rgn)});
      emri_write(R_OCC_WORD_COUNT, 32'(NWORDS));
      emri_cmd(OCC_READBACK, 4'(rgn));
      wait_occ_done(dc);
      chk(dc == 2'd0, "swap: READBACK done_code=DONE (CRC match)");
      emri_read(R_OCC_STATUS, rd);
      chk(rd[16] == 1'b0, "swap: sticky crc_error stays 0");

      // ---- shadow model: target == image, neighbor byte-identical ----
      for (j = 0; j < NWORDS; j = j + 1) shadow[rgn][j] = img[sel][j];
      check_region(rgn, "swap: target column == streamed image");
      check_region(1 - rgn, "swap: neighbor column byte-identical");

      if ((swap_idx % 2000) == 0)
        $display("[soak] swap %0d/%0d (region %0d, image %0s)",
                 swap_idx, SWAPS, rgn, (sel == 1) ? "B" : "A");
    end

    $display("[soak] done: %0d swaps, errors=%0d, word mismatches=%0d",
             SWAPS, errors, total_mismatch);
    if (errors == 0)
      $display("TEST PASSED: E1-DMO2 OCC soak — %0d swaps (2 regions x %0d), zero config corruption, zero cross-region interference", SWAPS, SWAPS / 2);
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // -- Watchdog (safety cap; the soak expects ~1.3e6 cycles = 13 ms sim) ---------
  initial begin
    repeat (2) #(1000000000);   // 2 s sim hard cap
    $display("TEST FAILED: soak timeout (swap=%0d errors=%0d)", swap_idx, errors);
    $finish;
  end

endmodule

`default_nettype wire
