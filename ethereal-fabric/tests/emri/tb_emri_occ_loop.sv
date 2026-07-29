`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_emri_occ_loop (testbench, self-checking)
// Description: CAPSTONE — the sim-complete management-plane minimal loop.
//              Instantiates the REAL emri_regfile + occ_top + column_cfg_ram and
//              drives a full deploy+verify cycle through the EMRI host port,
//              mirroring ethctl's Daemon.deploy sequence (S08 §2.1):
//                1. read EMRI identity (MAGIC / CAPABILITIES — mFSM mode);
//                2. BLANK the region's frames (OCC_CMD BLANK);
//                3. WRITE config frames (OCC_CMD WRITE + stream OCC_WDATA);
//                4. READBACK + verify CRC32 (OCC_CMD READBACK, crc_error==0);
//                5. backdoor-check column_cfg_ram holds the written words.
//              This proves host -> EMRI -> OCC -> config-storage end-to-end on
//              real RTL. (Fabric configuration via direct cfg is proven by
//              tb_hotswap; the frame-decoder stitching config-storage -> fabric
//              is the next integration — see report.)
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3, ethereal-plan/subsystems/S08-运行时daemon与ethctl.md §2.1
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". The host
//              register-write sequence here is identical to the Python Daemon's
//              (test_ethctl.py::test_plan_has_blank_then_write_order).
`timescale 1ns/1ps
module tb_emri_occ_loop;
  import emri_pkg::*;

  // ---- params ----
  localparam int  ADDR_W = 16;
  localparam int  DATA_W = 32;
  localparam int  NWORDS = 12;          // frames = 12 config words

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;  // 100 MHz

  // ---- EMRI host slave port (the TB is the host) ----
  logic        h_req = 1'b0;
  logic        h_we  = 1'b0;
  logic [1:0]  h_op  = SPI_OP_RD;
  logic [15:0] h_addr= 16'h0;
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

  // ---- DUTs ----
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
    .occ_region_locked_o(occ_region_locked)
  );

  occ_top #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_occ (
    .clk_i(clk), .rst_ni(rst_n),
    .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
    .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
    .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid), .wdata_ready_o(occ_wdata_ready),
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locked_i(occ_region_locked)
  );

  column_cfg_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(8192)) u_ram (
    .clk(clk), .we(fbus_we), .re(fbus_re), .addr(fbus_addr),
    .wdata(fbus_wdata), .rdata(fbus_rdata)
  );

  // ============================================================
  // Host driver tasks (mirror the EMRI host slave port protocol)
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

  // plain register write (immediate ready): REGION_SEL / FRAME_ADDR / WORD_COUNT
  task automatic emri_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=a; h_wd=d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);
      @(negedge clk); h_req=1'b0;
    end
  endtask

  // OCC_CMD with start bit (multi-cycle: ready = occ_cmd_ready)
  task automatic emri_cmd(input logic [1:0] cmd, input logic [3:0] region);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_WR; h_addr=R_OCC_CMD;
      h_wd = (1<<OCC_CMD_START) | ((region & 4'hF) << 2) | cmd;
      @(posedge clk);
      while (!h_ready) @(posedge clk);   // waits occ_cmd accept
      @(negedge clk); h_req=1'b0;
    end
  endtask

  // OCC_WDATA push (OCC_PUSH op; ready = occ_wdata_ready, may stall)
  task automatic emri_push(input logic [31:0] d);
    begin
      @(negedge clk);
      h_req=1'b1; h_we=1'b1; h_op=SPI_OP_OCC_PUSH; h_addr=R_OCC_WDATA; h_wd=d;
      @(posedge clk);
      while (!h_ready) @(posedge clk);   // honors OCC backpressure
      @(negedge clk); h_req=1'b0;
    end
  endtask

  // poll OCC_STATUS sticky done_flag[3] until set (host-pollable; occ_top's
  // DONE pulses for 1 cycle, invisible to a poller, so the regfile latches it).
  // returns done_code in [5:4]: 0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED.
  // Does NOT auto-fail — the caller asserts the expected code (the tamper test
  // EXPECTS ERROR).
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
          code = 2'd1;  // treat as error
          return;
        end
      end while (!s[3]);
      code = s[5:4];
    end
  endtask

  // ============================================================
  // Test
  // ============================================================
  logic [31:0] rd;
  logic [1:0] dc;   // OCC done_code from wait_occ_done
  integer i;
  logic [31:0] expected;
  initial begin
    // reset
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ---- 1. EMRI identity (mFSM mode) ----
    emri_read(R_MAGIC, rd);        chk(rd == EMRI_MAGIC, "MAGIC present");
    emri_read(R_CAPABILITIES, rd); chk(rd[CAPB_HAS_BMC] == 1'b0, "mFSM mode (has_bmc=0)");
    emri_read(R_NUM_REGIONS, rd);  chk(rd[7:0] == 2, "NUM_REGIONS=2");

    // ---- 2. BLANK region 0 (frame_addr=0, NWORDS words) ----
    emri_write(R_OCC_FRAME_ADDR, 32'h0000_0000);
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_cmd(OCC_BLANK, 4'd0);
    wait_occ_done(dc);
    chk(dc == 2'd0, "BLANK done_code=DONE");
    // verify the RAM region was zeroed
    for (i = 0; i < NWORDS; i = i + 1)
      chk(u_ram.mem[i] == 32'h0, "BLANK zeroed RAM word");

    // ---- 3. WRITE the config frames (12 distinct words) ----
    emri_write(R_OCC_FRAME_ADDR, 32'h0000_0000);
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_cmd(OCC_WRITE, 4'd0);
    for (i = 0; i < NWORDS; i = i + 1)
      emri_push(32'hC0DE_0000 + i);   // distinct, verifiable pattern
    wait_occ_done(dc);
    chk(dc == 2'd0, "WRITE done_code=DONE");

    // ---- 4. READBACK + CRC verify (deploy-verify cycle) ----
    emri_write(R_OCC_FRAME_ADDR, 32'h0000_0000);
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_cmd(OCC_READBACK, 4'd0);
    wait_occ_done(dc);
    chk(dc == 2'd0, "READBACK done_code=DONE");
    emri_read(R_OCC_STATUS, rd);
    chk(rd[16] == 1'b0, "READBACK crc_error=0 (deploy verified)");

    // ---- 5. backdoor-check RAM holds the written frames ----
    for (i = 0; i < NWORDS; i = i + 1) begin
      expected = 32'hC0DE_0000 + i;
      chk(u_ram.mem[i] == expected, "RAM word matches pushed frame");
    end

    // ---- 6. tamper + re-readback -> crc_error=1 (negative control) ----
    u_ram.mem[3] = 32'hDEAD_BEEF;   // backdoor flip
    emri_write(R_OCC_FRAME_ADDR, 32'h0000_0000);
    emri_write(R_OCC_WORD_COUNT, NWORDS);
    emri_cmd(OCC_READBACK, 4'd0);
    wait_occ_done(dc);
    chk(dc == 2'd1, "tamper: READBACK done_code=ERROR");
    emri_read(R_OCC_STATUS, rd);
    chk(rd[16] == 1'b1, "tamper detected: crc_error=1 after word flip");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: EMRI->OCC->cfgRAM deploy+verify minimal loop (mFSM, real RTL)");
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
