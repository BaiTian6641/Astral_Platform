`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_emri_regfile (testbench, self-checking)
// Description: Exercises the EMRI register file (v0): identity reads, RW config,
//              REGION_INFO windowing, OCC command passthrough (cmd_valid +
//              accept), OCC wdata streaming with backpressure, OCC_STATUS mirror,
//              reserved-read-as-0.
// Details:     Uses a minimal OCC stub (NOT the real occ_top) so the test stays
//              focused on EMRI's register/passthrough behavior. The stub:
//                * accepts a command 1 cycle after cmd_valid (cmd_ready pulse);
//                * for WRITE consumes word_count wdata beats (wdata_ready
//                  forced low for 2 cycles mid-stream to exercise backpressure);
//                * for BLANK self-completes in word_count cycles;
//                * drives status IDLE->BUSY->DONE(1cyc)->IDLE.
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3/§4
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED" on success.
`timescale 1ns/1ps
module tb_emri_regfile;
  import emri_pkg::*;

  // ---- DUT parameters (mFSM mode) ----
  localparam bit          HAS_BMC        = 1'b0;
  localparam int          NUM_REGIONS    = 2;
  localparam logic [31:0] PLATFORM_ID    = 32'h0000_0000;  // sim
  localparam logic [31:0] REGION0_INFO   = 32'h0202_0010;
  localparam logic [31:0] REGION1_INFO   = 32'h0202_0010;

  // ---- Clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;  // 100 MHz

  // ---- Host slave port (fabric domain) ----
  logic        host_req  = 1'b0;
  logic        host_we   = 1'b0;
  logic [1:0]  host_op   = SPI_OP_RD;
  logic [15:0] host_addr = 16'h0;
  logic [31:0] host_wdata= 32'h0;
  logic [31:0] host_rdata;
  logic        host_ready;

  // ---- OCC master port (DUT outputs + stub inputs) ----
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

  // ---- DUT ----
  emri_regfile #(
    .HAS_BMC(HAS_BMC), .NUM_REGIONS(NUM_REGIONS),
    .PLATFORM_ID(PLATFORM_ID),
    .REGION0_INFO(REGION0_INFO), .REGION1_INFO(REGION1_INFO)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
    .host_addr_i(host_addr), .host_wdata_i(host_wdata),
    .host_rdata_o(host_rdata), .host_ready_o(host_ready),
    .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid),
    .occ_cmd_ready_i(occ_cmd_ready),
    .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
    .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
    .occ_wdata_ready_i(occ_wdata_ready),
    .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
    .occ_region_locked_o(occ_region_locked)
  );

  // ============================================================
  // OCC stub
  //   * cmd_ready: 1-cycle pulse the cycle after cmd_valid seen in IDLE.
  //   * WRITE: consumes word_count wdata beats; wdata_ready held LOW for a
  //     fixed 2-cycle window starting at beat 1 to exercise host backpressure.
  //   * BLANK/READBACK: self-complete in word_count cycles (no wdata stream).
  //   * status: IDLE -> BUSY (ACCEPT/RUN) -> IDLE (DONE is implicit: 1cyc BUSY
  //     transition is enough for the EMRI read; v0 stub does not pulse DONE).
  // ============================================================
  typedef enum logic [1:0] { ST_IDLE=0, ST_ACCEPT=1, ST_RUN=2 } stub_st_e;
  stub_st_e stub_st = ST_IDLE;
  logic [1:0]  stub_cmd_r;
  logic [15:0] stub_wc_r;
  logic [15:0] stub_beat_r;
  logic        stall_done_r;   // has the 2-cycle beat-1 stall been injected?
  logic [1:0]  stall_cnt_r;    // counts down the 2 stall cycles
  logic        stub_wdata_ready;

  always_comb begin
    occ_status    = OCC_S_IDLE;
    occ_crc_error = 1'b0;
    case (stub_st)
      ST_IDLE:    occ_status = OCC_S_IDLE;
      ST_ACCEPT:  occ_status = OCC_S_BUSY;
      ST_RUN:     occ_status = OCC_S_BUSY;
      default:    occ_status = OCC_S_IDLE;
    endcase
  end

  // wdata_ready: only during WRITE in RUN, outside the injected stall window.
  always_comb begin
    stub_wdata_ready = 1'b0;
    if (stub_st == ST_RUN && stub_cmd_r == OCC_WRITE && stall_cnt_r == 2'd0) begin
      stub_wdata_ready = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stub_st       <= ST_IDLE;
      occ_cmd_ready <= 1'b0;
      stub_cmd_r    <= 2'd0;
      stub_wc_r     <= 16'd0;
      stub_beat_r   <= 16'd0;
      stall_done_r  <= 1'b0;
      stall_cnt_r   <= 2'd0;
      occ_wdata_ready <= 1'b0;
    end else begin
      occ_cmd_ready <= 1'b0;  // default deassert (pulse style)
      case (stub_st)
        ST_IDLE: begin
          if (occ_cmd_valid) begin
            stub_cmd_r  <= occ_cmd;
            stub_wc_r   <= occ_word_count;
            stub_beat_r <= 16'd0;
            stall_done_r<= 1'b0;
            stall_cnt_r <= 2'd0;
            occ_cmd_ready<= 1'b1;  // accept this cycle
            stub_st     <= ST_ACCEPT;
          end
        end
        ST_ACCEPT: begin
          // For BLANK/READBACK: count word_count cycles here, no wdata.
          if (stub_cmd_r == OCC_BLANK || stub_cmd_r == OCC_READBACK) begin
            if (stub_beat_r + 16'd1 >= stub_wc_r) stub_st <= ST_IDLE;
            else                                  stub_beat_r <= stub_beat_r + 16'd1;
          end else begin
            // WRITE -> move to RUN and wait for wdata there
            stub_st <= ST_RUN;
          end
        end
        ST_RUN: begin
          if (stub_cmd_r == OCC_WRITE) begin
            // inject a 2-cycle stall once, at the start of beat 1
            if (stub_beat_r == 16'd1 && !stall_done_r) begin
              if (stall_cnt_r == 2'd0)      stall_cnt_r <= 2'd2;        // arm
              else if (stall_cnt_r != 2'd0) begin
                stall_cnt_r <= stall_cnt_r - 2'd1;
                if (stall_cnt_r == 2'd1) stall_done_r <= 1'b1;          // stall over
              end
            end else if (occ_wdata_valid && stub_wdata_ready) begin
              if (stub_beat_r + 16'd1 >= stub_wc_r) begin
                stub_st <= ST_IDLE;        // DONE
              end else begin
                stub_beat_r <= stub_beat_r + 16'd1;
              end
            end
          end else begin
            stub_st <= ST_IDLE;            // defensive (BLANK handled in ACCEPT)
          end
        end
      endcase
      // mirror the combinational stub_wdata_ready onto the output reg the DUT reads
      occ_wdata_ready <= stub_wdata_ready;
    end
  end

  // ============================================================
  // Host driver tasks
  // ============================================================
  task automatic host_read(input logic [15:0] a, output logic [31:0] d);
    begin
      @(negedge clk);
      host_req=1'b1; host_we=1'b0; host_op=SPI_OP_RD; host_addr=a; host_wdata=32'h0;
      @(posedge clk);
      while (!host_ready) @(posedge clk);
      d = host_rdata;
      @(negedge clk);
      host_req=1'b0;
    end
  endtask

  task automatic host_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      host_req=1'b1; host_we=1'b1; host_op=SPI_OP_WR; host_addr=a; host_wdata=d;
      @(posedge clk);
      while (!host_ready) @(posedge clk);
      @(negedge clk);
      host_req=1'b0;
    end
  endtask

  task automatic host_push(input logic [31:0] d);
    begin
      @(negedge clk);
      host_req=1'b1; host_we=1'b1; host_op=SPI_OP_OCC_PUSH; host_addr=R_OCC_WDATA; host_wdata=d;
      @(posedge clk);
      while (!host_ready) @(posedge clk);
      @(negedge clk);
      host_req=1'b0;
    end
  endtask

  // assertion helper
  int errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin
      if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end
    end
  endtask

  // ============================================================
  // Test sequence
  // ============================================================
  logic [31:0] rd;
  initial begin
    // reset
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 1. Identity reads ----
    host_read(R_MAGIC, rd);        chk(rd == EMRI_MAGIC, "MAGIC");
    host_read(R_ABI_VERSION, rd);  chk(rd == 32'h0, "ABI_VERSION");
    host_read(R_CAPABILITIES, rd); chk(rd[CAPB_HAS_BMC] == 1'b0, "CAPS has_bmc=0 (mFSM)");
    host_read(R_PLATFORM_ID, rd);  chk(rd == PLATFORM_ID, "PLATFORM_ID");
    host_read(R_NUM_REGIONS, rd);  chk(rd[7:0] == NUM_REGIONS, "NUM_REGIONS=2");

    // ---- 2. REGION_INFO windowing ----
    host_write(R_REGION_SEL, 32'h0000);  // select region 0
    host_read(R_REGION_INFO, rd);        chk(rd == REGION0_INFO, "REGION_INFO[0]");
    host_write(R_REGION_SEL, 32'h0001);  // select region 1
    host_read(R_REGION_INFO, rd);        chk(rd == REGION1_INFO, "REGION_INFO[1]");

    // ---- 3. RW config regs ----
    host_write(R_OCC_FRAME_ADDR, 32'h0000_ABCD);
    host_read(R_OCC_FRAME_ADDR, rd); chk(rd[15:0] == 16'hABCD, "OCC_FRAME_ADDR RW");
    host_write(R_OCC_WORD_COUNT, 32'h0000_0004);
    host_read(R_OCC_WORD_COUNT, rd); chk(rd[15:0] == 16'd4, "OCC_WORD_COUNT RW");

    // ---- 4. OCC BLANK command (no wdata stream) ----
    host_write(R_OCC_FRAME_ADDR, 32'h0000_1000);
    host_write(R_OCC_WORD_COUNT, 32'h0000_0003);
    // OCC_CMD = {start=1 @bit8, region=1 @bits[5:2], cmd=BLANK=3 @bits[1:0]}
    host_write(R_OCC_CMD, 32'h0000_010F);  // 0x10F = bit8 + region1(0x0C) + BLANK(3)
    // wait for stub to return to IDLE
    timeout_wait_idle();
    chk(occ_region_locked == 1'b0, "region_locked hardwired 0");

    // ---- 5. OCC WRITE: set frame addr + word count, issue WRITE cmd, then
    //         push 4 data words sequentially (single host bus — no concurrency).
    host_write(R_OCC_FRAME_ADDR, 32'h0000_2000);
    host_write(R_OCC_WORD_COUNT, 32'h0000_0004);
    // issue WRITE command (completes when OCC accepts the cmd)
    host_write(R_OCC_CMD, 32'h0000_010D);  // start + region1 + WRITE(1)
    // push 4 data words (host_push stalls on the injected beat-1 backpressure)
    host_push(32'hAAAA_0000);
    host_push(32'hBBBB_0001);
    host_push(32'hCCCC_0002);
    host_push(32'hDDDD_0003);
    timeout_wait_idle();

    // ---- 6. OCC_STATUS read ----
    host_read(R_OCC_STATUS, rd);
    chk(rd[2:0] == OCC_S_IDLE, "OCC_STATUS.status=IDLE after done");

    // ---- 7. Reserved read-as-0 ----
    host_read(16'h07, rd);   chk(rd == 32'h0, "reserved 0x07 read-as-0");
    host_read(16'h0F, rd);   chk(rd == 32'h0, "reserved 0x0F read-as-0");
    host_read(16'hFF, rd);   chk(rd == 32'h0, "reserved 0xFF read-as-0");

    // ---- 8. HEALTH + MON ----
    host_read(R_HEALTH_STATUS, rd); chk(rd[0]==1'b1 && rd[8]==1'b1, "HEALTH all-ok");
    host_read(R_MON_TEMP, rd);      chk(rd[15:0] == 16'h0019, "MON_TEMP 25C");

    // ---- report ----
    if (errors == 0) $display("TEST PASSED: emri_regfile (EMRI v0 register ABI + OCC passthrough)");
    else             $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // wait for the OCC stub to return to IDLE (bounded)
  task automatic timeout_wait_idle;
    integer i;
    begin
      i = 0;
      while (stub_st != ST_IDLE && i < 200) begin @(posedge clk); i = i + 1; end
      if (i >= 200) begin
        errors = errors + 1;
        $display("  FAIL: timeout waiting for OCC stub IDLE");
      end
    end
  endtask

  // global watchdog
  initial begin
    #100000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
