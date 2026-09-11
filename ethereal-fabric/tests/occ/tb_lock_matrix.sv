`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_lock_matrix (testbench, self-checking)
// Description: Region lock matrix end-to-end TB (v0.8 EMRI §3.10 + C03 §5,
//              E2-SEC1b) on REAL RTL: host -> emri_regfile (LKM_CMD/LKM_STATUS)
//              -> occ_top (frame-bus write gate) -> column_cfg_ram.
// Details:     Proves the acceptance contract of E2-SEC1b:
//                1. LKM_CMD locks a region and LKM_STATUS reports the SAME
//                   hardware bits (register surface == gate input);
//                2. a WRITE targeting a locked region is REFUSED with
//                   OCC_STATUS.done_code = LOCKED (3), no frame-bus write strobe
//                   is issued, and the config RAM is word-identical before/after;
//                3. READBACK stays allowed on a locked region (same stream CRC
//                   -> done_code DONE, crc_error = 0) — §3.10 rule 3;
//                4. unlock -> the same WRITE succeeds;
//                5. the global lock (opcode 3) gates every region, including a
//                   region whose own bit is clear;
//                6. opcodes 3/4 touch ONLY the global bit — after opcode 4 a
//                   region that was region-locked stays locked (and still gates
//                   writes) until opcode 2 clears it explicitly;
//                7. per-region isolation (locking region 1 does not disturb
//                   region 0 and vice versa);
//                8. BLANK is gated exactly like WRITE; region indices >= 8 and
//                   unknown opcodes are no-ops.
//              The refusal check is a RAM-content comparison around the refused
//              command plus a frame-bus write-strobe counter, so "refused" means
//              provably no write reached the config store (not merely a status
//              code).
//              The WRITE-refusal path also covers the host-handshake fix: a
//              refused OCC command never asserts cmd_ready, so the regfile
//              releases the held host transaction on the terminal status
//              (otherwise the single host port would stall forever and the
//              LOCKED status could never be read — spec §3.10 rule 2).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3.10 (v0.8, E2-SEC1b),
//              ethereal-plan/components/C03-OCC组件.md §5
// Notes:       iverilog -g2012 self-checking; prints TEST PASSED / TEST FAILED.
//              Run (repo root):
//                iverilog -g2012 -o /tmp/tb_lock_matrix \
//                  ethereal-shell/rtl/emri/emri_pkg.sv \
//                  ethereal-shell/rtl/emri/emri_regfile.sv \
//                  ethereal-fabric/rtl/occ/occ_top.sv \
//                  ethereal-fabric/tests/occ/column_cfg_ram.sv \
//                  ethereal-fabric/tests/occ/tb_lock_matrix.sv && vvp /tmp/tb_lock_matrix
`timescale 1ns/1ps
module tb_lock_matrix;
  import emri_pkg::*;

  localparam int  ADDR_W = 16;
  localparam int  DATA_W = 32;
  localparam int  NWORDS = 8;

  localparam logic [15:0] R0_FRAME_A = 16'h0000;  // region 0 (frame_addr[15:12]=0)
  localparam logic [15:0] R0_FRAME_B = 16'h0040;  // region 0, second column window
  localparam logic [15:0] R1_FRAME_A = 16'h1000;  // region 1 (frame_addr[15:12]=1)

  localparam logic [7:0]  LKM_BIT0   = 8'h01;     // LKM_STATUS region-0 bit
  localparam logic [7:0]  LKM_BIT1   = 8'h02;     // LKM_STATUS region-1 bit

  // ---- clock / reset ----
  logic clk   = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;  // 100 MHz

  // ---- EMRI host slave port (this TB is the host) ----
  logic        h_req  = 1'b0;
  logic        h_we   = 1'b0;
  logic [1:0]  h_op   = SPI_OP_RD;
  logic [15:0] h_addr = 16'h0;
  logic [31:0] h_wd   = 32'h0;
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
  logic [7:0]  occ_region_locks;
  logic        occ_global_lock;

  // ---- OCC <-> column_cfg_ram (frame bus) ----
  logic [ADDR_W-1:0] fbus_addr;
  logic [DATA_W-1:0] fbus_wdata;
  logic              fbus_we;
  logic              fbus_re;
  logic [DATA_W-1:0] fbus_rdata;

  logic [31:0] occ_expect_crc_w;   // v0.5 §3.1.1 (OCC expected-CRC gate)
  logic [31:0] occ_crc_result_w;   // v0.5 §3.1.1 (OCC running CRC)

  emri_regfile #(
    .HAS_BMC(1'b0), .NUM_REGIONS(2),
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
    .occ_region_locks_o(occ_region_locks), .occ_global_lock_o(occ_global_lock),
    .occ_expect_crc_o(occ_expect_crc_w),
    .occ_crc_result_i(occ_crc_result_w)
  );

  occ_top #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_occ (
    .clk_i(clk), .rst_ni(rst_n),
    .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
    .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
    .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid), .wdata_ready_o(occ_wdata_ready),
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locks_i(occ_region_locks), .global_lock_i(occ_global_lock),
    .expect_crc_i(occ_expect_crc_w),
    .crc_result_o(occ_crc_result_w)
  );

  column_cfg_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(8192)) u_ram (
    .clk(clk), .we(fbus_we), .re(fbus_re), .addr(fbus_addr),
    .wdata(fbus_wdata), .rdata(fbus_rdata)
  );

  // Frame-bus write-strobe counter: a refused command must leave it unchanged.
  integer we_strobes = 0;
  always_ff @(posedge clk) begin
    if (fbus_we) we_strobes <= we_strobes + 1;
  end

  // ============================================================
  // Host driver tasks (EMRI host-slave protocol, as in tb_emri_occ_loop)
  // ============================================================
  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end end
  endtask

  task automatic emri_read(input logic [15:0] a, output logic [31:0] d);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b0; h_op=SPI_OP_RD; h_addr=a; h_wd=32'h0;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      d = h_rd;
      @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic emri_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=a; h_wd=d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  // OCC_CMD with the start bit. For a REFUSED command occ_top never asserts
  // cmd_ready; the regfile releases the write on the terminal LOCKED/NEEDS_BLANK
  // status, so h_ready still pulses and this task terminates.
  task automatic emri_cmd(input logic [1:0] cmd, input logic [3:0] region);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=R_OCC_CMD;
      h_wd = (1<<OCC_CMD_START) | ((region & 4'hF) << 2) | cmd;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  task automatic emri_push(input logic [31:0] d);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_OCC_PUSH; h_addr=R_OCC_WDATA; h_wd=d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  // Poll OCC_STATUS[3] (sticky done_flag); return done_code = [5:4]
  // 0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED.
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

  // LKM_CMD word = {region index [7:4], opcode [3:0]} (spec §3.10).
  task automatic lock_region(input logic [3:0] r);
    begin emri_write(R_LKM_CMD, {24'h0, r, LKM_OP_LOCK}); end
  endtask

  task automatic unlock_region(input logic [3:0] r);
    begin emri_write(R_LKM_CMD, {24'h0, r, LKM_OP_UNLOCK}); end
  endtask

  task automatic global_lock_set;
    begin emri_write(R_LKM_CMD, {28'h0, LKM_OP_GLOBAL_SET}); end
  endtask

  task automatic global_lock_clear;
    begin emri_write(R_LKM_CMD, {28'h0, LKM_OP_GLOBAL_CLEAR}); end
  endtask

  // LKM_STATUS readback compare (exp is the full 32-bit status word).
  task automatic lkm_expect(input logic [31:0] exp, input [255:0] msg);
    logic [31:0] v;
    begin
      emri_read(R_LKM_STATUS, v);
      if (v !== exp) begin
        errors = errors + 1;
        $display("  FAIL: %0s (LKM_STATUS=%h expected %h)", msg, v, exp);
      end
    end
  endtask

  // Issue BLANK/WRITE and assert the done_code (dc: 0=DONE 1=ERROR
  // 2=NEEDS_BLANK 3=LOCKED).
  task automatic occ_cmd_expect(input logic [1:0] cmd, input logic [3:0] region,
                                input logic [1:0] exp, input [255:0] msg);
    logic [1:0] dc;
    begin
      emri_cmd(cmd, region);
      wait_occ_done(dc);
      if (dc !== exp) begin
        errors = errors + 1;
        $display("  FAIL: %0s (done_code=%0d expected %0d)", msg, dc, exp);
      end
    end
  endtask

  // ============================================================
  // Test sequence
  // ============================================================
  logic [31:0] rd;
  logic [31:0] crc_a, crc_b;    // captured WRITE stream CRCs
  logic [1:0]  dc;
  integer i, k;
  logic [31:0] expect_word;

  initial begin
    // ---- reset ----
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 0. reset state: no locks, LKM_CMD reads 0, gate inputs clear ----
    lkm_expect(32'h0000_0000, "reset: all locks clear (spec §3.10 rule 6)");
    emri_read(R_LKM_CMD, rd);
    chk(rd == 32'h0, "LKM_CMD reads 0 (write-only)");
    chk(occ_region_locks == 8'h00 && occ_global_lock == 1'b0,
        "occ gate inputs clear at reset");

    // ---- 1. baseline region-0 deploy (BLANK -> WRITE -> READBACK) ----
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    occ_cmd_expect(OCC_BLANK, 4'd0, 2'd0, "baseline BLANK region 0");
    for (i = 0; i < NWORDS; i = i + 1)
      chk(u_ram.mem[R0_FRAME_A + i] === 32'h0, "baseline BLANK zeroed RAM");

    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_cmd(OCC_WRITE, 4'd0);
    for (i = 0; i < NWORDS; i = i + 1) emri_push(32'hC0DE_0000 + i);
    wait_occ_done(dc);
    chk(dc == 2'd0, "baseline WRITE region 0 done_code=DONE");
    for (i = 0; i < NWORDS; i = i + 1)
      chk(u_ram.mem[R0_FRAME_A + i] === (32'hC0DE_0000 + i), "baseline RAM = frame");
    emri_read(R_OCC_CRC_RESULT, crc_a);   // gate value for the readback below

    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_write(R_OCC_EXPECT_CRC, crc_a);
    occ_cmd_expect(OCC_READBACK, 4'd0, 2'd0, "baseline READBACK region 0");
    emri_read(R_OCC_STATUS, rd);
    chk(rd[16] == 1'b0, "baseline READBACK crc_error=0");

    // ---- 2. lock region 0 -> LKM_STATUS bit0 ----
    lock_region(4'd0);
    lkm_expect({23'h0, 1'b0, LKM_BIT0}, "lock region 0 -> LKM_STATUS bit0");
    chk(occ_region_locks == LKM_BIT0 && occ_global_lock == 1'b0,
        "occ gate sees region-0 lock");

    // ---- 3. REFUSED WRITE to the locked region 0 (+ RAM proof) ----
    begin : refused_write
      logic [DATA_W-1:0] snap [0:NWORDS-1];
      integer w0, w1, bad;
      bad = 0;
      for (k = 0; k < NWORDS; k = k + 1) snap[k] = u_ram.mem[R0_FRAME_B + k];
      w0 = we_strobes;
      emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_B});
      emri_write(R_OCC_WORD_COUNT, NWORDS);
      // No OCC_WDATA push: the command must be refused before any data moves.
      occ_cmd_expect(OCC_WRITE, 4'd0, 2'd3, "locked WRITE region 0 -> LOCKED");
      w1 = we_strobes;
      chk(w1 == w0, "refused WRITE issued no frame-bus write strobe");
      for (k = 0; k < NWORDS; k = k + 1) begin
        if (u_ram.mem[R0_FRAME_B + k] !== snap[k]) begin
          bad = bad + 1;
          $display("  FAIL: refused WRITE modified RAM[0x%04x]", R0_FRAME_B + k);
        end
      end
      chk(bad == 0, "refused WRITE left the config RAM word-identical");
    end

    // ---- 4. READBACK on the locked region stays allowed (§3.10 rule 3) ----
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_write(R_OCC_EXPECT_CRC, crc_a);
    occ_cmd_expect(OCC_READBACK, 4'd0, 2'd0, "READBACK allowed while region 0 locked");
    emri_read(R_OCC_STATUS, rd);
    chk(rd[16] == 1'b0, "locked READBACK crc_error=0 (read path intact)");

    // ---- 5. lock region 1 too -> per-region bitmap + untouched RAM ----
    lock_region(4'd1);
    lkm_expect({23'h0, 1'b0, (LKM_BIT1 | LKM_BIT0)}, "lock region 1 -> bits {1,0}");
    begin : refuse_r1
      logic [DATA_W-1:0] snap1 [0:NWORDS-1];
      integer bad;
      bad = 0;
      for (k = 0; k < NWORDS; k = k + 1) snap1[k] = u_ram.mem[R1_FRAME_A + k];
      // occ_top keys the region off frame_addr[15:12] (C03 §1.1).
      emri_write(R_OCC_FRAME_ADDR, {16'h0, R1_FRAME_A});
      emri_write(R_OCC_WORD_COUNT, NWORDS);
      occ_cmd_expect(OCC_WRITE, 4'd1, 2'd3, "locked WRITE region 1 -> LOCKED");
      for (k = 0; k < NWORDS; k = k + 1) begin
        if (u_ram.mem[R1_FRAME_A + k] !== snap1[k]) begin
          bad = bad + 1;
          $display("  FAIL: refused region-1 WRITE modified RAM[0x%04x]", R1_FRAME_A + k);
        end
      end
      chk(bad == 0, "refused region-1 WRITE left RAM word-identical");
    end

    // ---- 6. unlock region 0 -> bit isolation ----
    unlock_region(4'd0);
    lkm_expect({23'h0, 1'b0, LKM_BIT1}, "unlock region 0 -> only bit1 set");
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R1_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    occ_cmd_expect(OCC_WRITE, 4'd1, 2'd3, "region-1 still locked after region-0 unlock");

    // ---- 7. unlocked region 0 accepts BLANK + WRITE again ----
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_B});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    occ_cmd_expect(OCC_BLANK, 4'd0, 2'd0, "unlocked BLANK region 0 -> DONE");
    emri_cmd(OCC_WRITE, 4'd0);
    for (i = 0; i < NWORDS; i = i + 1) emri_push(32'hA5A5_0000 + i);
    wait_occ_done(dc);
    chk(dc == 2'd0, "unlocked WRITE region 0 -> DONE");
    for (i = 0; i < NWORDS; i = i + 1)
      chk(u_ram.mem[R0_FRAME_B + i] === (32'hA5A5_0000 + i), "unlocked RAM = frame");
    emri_read(R_OCC_CRC_RESULT, crc_b);

    // ---- 8. global lock (opcode 3) gates an UNLOCKED region ----
    global_lock_set;
    lkm_expect({23'h0, 1'b1, LKM_BIT1}, "global lock -> LKM_STATUS[8] set");
    chk(occ_global_lock == 1'b1 && occ_region_locks == LKM_BIT1,
        "occ gate sees global lock + region-1 bit");
    begin : global_refuse
      logic [DATA_W-1:0] snap0 [0:NWORDS-1];
      logic [DATA_W-1:0] snap1 [0:NWORDS-1];
      integer w0, w1, bad;
      bad = 0;
      for (k = 0; k < NWORDS; k = k + 1) begin
        snap0[k] = u_ram.mem[R0_FRAME_A + k];
        snap1[k] = u_ram.mem[R0_FRAME_B + k];
      end
      w0 = we_strobes;
      // region 0 has NO lock bit set, yet the global lock gates it.
      emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_A});
      emri_write(R_OCC_WORD_COUNT, NWORDS);
      occ_cmd_expect(OCC_WRITE, 4'd0, 2'd3, "global lock gates unlocked region 0");
      // BLANK is gated exactly like WRITE (C03 §5 "write enable closed").
      emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_B});
      emri_write(R_OCC_WORD_COUNT, NWORDS);
      occ_cmd_expect(OCC_BLANK, 4'd0, 2'd3, "global lock gates BLANK region 0");
      w1 = we_strobes;
      chk(w1 == w0, "globally-locked WRITE/BLANK issued no write strobes");
      for (k = 0; k < NWORDS; k = k + 1) begin
        if (u_ram.mem[R0_FRAME_A + k] !== snap0[k]) begin
          bad = bad + 1;
          $display("  FAIL: global lock WRITE modified RAM[0x%04x]", R0_FRAME_A + k);
        end
        if (u_ram.mem[R0_FRAME_B + k] !== snap1[k]) begin
          bad = bad + 1;
          $display("  FAIL: global lock BLANK modified RAM[0x%04x]", R0_FRAME_B + k);
        end
      end
  chk(bad == 0, "global lock refused WRITE/BLANK left RAM word-identical");
    end

    // ---- 9. READBACK still allowed under the global lock ----
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R0_FRAME_B});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_write(R_OCC_EXPECT_CRC, crc_b);
    occ_cmd_expect(OCC_READBACK, 4'd0, 2'd0, "READBACK allowed under global lock");

    // ---- 10. opcode 4 clears ONLY the global bit (spec §3.10) ----
    global_lock_clear;
    lkm_expect({23'h0, 1'b0, LKM_BIT1},
        "opcode 4 clears global only (region 1 stays locked)");
    chk(occ_global_lock == 1'b0 && occ_region_locks == LKM_BIT1,
        "occ gate: global clear, region-1 lock persists");
    // the surviving region lock still gates writes
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R1_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    occ_cmd_expect(OCC_WRITE, 4'd1, 2'd3, "region 1 still locked after global clear");
    // opcode 2 clears that region explicitly
    unlock_region(4'd1);
    lkm_expect(32'h0000_0000, "opcode 2 clears region 1");
    chk(occ_region_locks == 8'h00 && occ_global_lock == 1'b0,
        "occ gate clear after opcode 2");

    // ---- 11. region 1 is writable again ----
    emri_write(R_OCC_FRAME_ADDR, {16'h0, R1_FRAME_A});
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    occ_cmd_expect(OCC_BLANK, 4'd1, 2'd0, "post-unlock BLANK region 1 -> DONE");
    emri_cmd(OCC_WRITE, 4'd1);
    for (i = 0; i < NWORDS; i = i + 1) emri_push(32'hBEEF_0000 + i);
    wait_occ_done(dc);
    chk(dc == 2'd0, "post-unlock WRITE region 1 -> DONE");
    for (i = 0; i < NWORDS; i = i + 1)
      chk(u_ram.mem[R1_FRAME_A + i] === (32'hBEEF_0000 + i), "region-1 RAM = frame");

    // ---- 12. no-op commands: out-of-range region index / unknown opcode ----
    // region index 8 has no LKM_STATUS bit (spec §2 bitmap is [7:0]) -> no-op.
    emri_write(R_LKM_CMD, {24'h0, 4'd8, LKM_OP_LOCK});
    lkm_expect(32'h0000_0000, "region index 8 is not lockable (no status bit)");
    emri_write(R_LKM_CMD, 32'h0000_0005);   // opcode 5: reserved
    lkm_expect(32'h0000_0000, "reserved opcode 5 is a no-op");
    emri_write(R_LKM_CMD, 32'h0000_0000);   // opcode 0: nop
    lkm_expect(32'h0000_0000, "opcode 0 is a no-op");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: region lock matrix (LKM_CMD/LKM_STATUS + per-region OCC write gate)");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // watchdog
  initial begin
    #400000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
