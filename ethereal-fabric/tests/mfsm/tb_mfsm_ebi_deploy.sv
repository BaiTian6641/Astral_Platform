`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_mfsm_ebi_deploy (testbench, self-checking)
// Description: E2-BMC1 acceptance — the mFSM as the small-device (Profile-E)
//              management unit: host script -> EBI-Tiny -> mFSM (EMRI ABI) ->
//              OCC -> real fabric_top, doing the FULL deploy flow, plus the
//              ADR-015 "ethctl is transparent" evidence and the emri-v0.md §5
//              session-FSM coverage.
//
//   host BFM (EBI-Tiny master)
//     -> ebi_tiny (address-map decoder, Shell-CSR window)
//       -> mfsm_top (emri_regfile HAS_BMC=0 + mfsm_session)
//         -> occ_top -> [frame bus] -> {fabric_top cfg port, column_cfg_ram mirror}
//
//              WHAT IS CHECKED
//               A. EMRI identity in mFSM mode (MAGIC/ABI/CAPABILITIES.has_bmc=0/
//                  NUM_REGIONS/REGION_INFO/HEALTH/MON) and the byte->word map.
//               B. ADR-015 ABI PARITY: a BMC-mode emri_regfile is instantiated
//                  beside the mFSM and the WHOLE register map (0x00-0x3F and
//                  0x50-0x5F) is swept on both; the set of differing offsets must
//                  be exactly {CAPABILITIES} — emri-v0.md §1 principle 1: "The
//                  ONLY field that differs is CAPABILITIES.has_bmc".
//               C. FULL DEPLOY FLOW, host-driven (emri-v0.md §1/§8 mFSM column):
//                  BLANK -> begin_rx -> arm WRITE -> stream 12 image words
//                  (rx_buf accounting -> VERIFY_REQ) -> verify -> occ_go -> OCC
//                  DONE -> READBACK gated by OCC_EXPECT_CRC (ADR-019: "the mFSM
//                  host flow MUST set OCC_EXPECT_CRC before every READBACK") ->
//                  fabric configured (TFF toggles / const1 steady) -> dual-image
//                  HOT-SWAP -> image B.
//               D. The two session terminal paths: the OCC op completing BEFORE
//                  occ_go (latched) and AFTER occ_go (live) — plus the §5 5-state
//                  coverage monitor.
//               E. Session corner cases: abort from RX/VERIFY_REQ/ERROR, no-op
//                  occ_go/verify from the wrong state, OCC LOCKED -> err=occ_locked,
//                  OCC CRC ERROR -> err=occ_error, NEEDS_BLANK -> err=occ_error
//                  (the reported ASSUMPTION), and err=bad_crc NEVER produced.
//               F. EBI-Tiny termination rules: unimplemented windows/pages answer
//                  ready+err (never a hang), and a partial-strobe write to a
//                  32-bit register is refused with err and no side effect.
//
//              The OCC frame bus drives fabric_top's cfg port (write) AND a
//              column_cfg_ram mirror that serves the READBACK — the same
//              verification structure as tb_emri_occ_loop (E0-FAB4). The mirror
//              is what makes the ADR-019 CRC gate meaningful: READBACK returns
//              exactly the words the WRITE streamed.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3/§4 (mFSM
//              acceptance: 上位机脚本经 EMRI 驱动完整部署流程; ethctl 无感;
//              5 状态覆盖) · ethereal-plan/components/C05-BMC组件.md §4 ·
//              ethereal-spec/control/emri-v0.md §1/§2/§3/§4/§5/§8 ·
//              docs/adr/ADR-014/ADR-015 · docs/adr/ADR-019 (OCC_EXPECT_CRC gate
//              is an explicit E2-BMC1 contract item)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". Run:
//              iverilog -g2012 -o /tmp/tb_mfsm -Iethereal-fabric/rtl/inf \
//                ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv \
//                ethereal-shell/rtl/ebi/ebi_pkg.sv ethereal-shell/rtl/ebi/ebi_tiny.sv \
//                ethereal-shell/rtl/mfsm/mfsm_pkg.sv ethereal-shell/rtl/mfsm/mfsm_session.sv \
//                ethereal-shell/rtl/mfsm/mfsm_top.sv ethereal-fabric/rtl/occ/occ_top.sv \
//                ethereal-fabric/tests/occ/column_cfg_ram.sv \
//                ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv \
//                ethereal-fabric/rtl/interconnect/switch_box.sv \
//                ethereal-fabric/rtl/interconnect/connection_block.sv \
//                ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv \
//                ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv \
//                ethereal-fabric/rtl/interconnect/fabric_top.sv \
//                ethereal-fabric/tests/mfsm/tb_mfsm_ebi_deploy.sv && vvp /tmp/tb_mfsm
`timescale 1ns/1ps
module tb_mfsm_ebi_deploy;
  import emri_pkg::*;
  import ebi_pkg::*;
  import mfsm_pkg::*;

  // ---- fabric params (2x2 all-CLB, same as tb_mgmt_hotswap) ----
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18;
  localparam int OBS_W = R*C*N;   // 32

  // ---- EBI-Tiny geometry (2 regions -> 6 windows) ----
  localparam int NUM_REGIONS = 2;
  localparam int NUM_WINDOWS = 4 + NUM_REGIONS;

  // ---- image deploy geometry (v0 cfg-addr-addressed frame format) ----
  localparam logic [15:0] IMG_WORDS = 16'd12;
  localparam logic [15:0] FRAME_BASE = 16'h0000;   // region 0, column 0

  // ---- clock / resets ----
  logic clk   = 1'b0;
  logic rst_n = 1'b0;      // management plane + OCC + fabric user reset
  logic fab_rst_n = 1'b0;  // fabric user reset only (config registers persist)
  always #5 clk = ~clk;    // 100 MHz

  // ============================================================
  // Host BFM on EBI-Tiny (the external MCU / SPI front-end)
  // ============================================================
  logic        h_req   = 1'b0;
  logic        h_we    = 1'b0;
  logic [31:0] h_addr  = 32'h0;
  logic [31:0] h_wdata = 32'h0;
  logic [3:0]  h_wstrb = 4'hF;
  logic [31:0] h_rdata;
  logic        h_ready;
  logic        h_err;

  logic                win_valid;
  logic [2:0]          win_idx;
  logic                win_we;
  logic [15:0]         win_addr;
  logic [31:0]         win_wdata;
  logic [3:0]          win_wstrb;
  logic [NUM_WINDOWS*32-1:0] win_rdata;
  logic [NUM_WINDOWS-1:0]    win_ready;
  logic [NUM_WINDOWS-1:0]    win_err;

  // ============================================================
  // mFSM management unit (the DUT): EMRI face + session FSM
  // ============================================================
  logic [31:0] m_occ_expect_crc;   // 0x0E storage -> OCC expected-CRC gate
  logic [31:0] m_occ_crc_result;   // 0x0F read-back <- OCC running CRC
  logic [1:0]  occ_cmd;
  logic        occ_cmd_valid, occ_cmd_ready;
  logic [15:0] occ_frame_addr, occ_word_count;
  logic [31:0] occ_wdata;
  logic        occ_wdata_valid, occ_wdata_ready;
  logic [2:0]  occ_status;
  logic        occ_crc_error;
  logic [7:0]  occ_region_locks;
  logic        occ_global_lock;
  logic        dec_start, dec_busy_o;
  logic [7:0]  dec_col;
  logic        ctx_start, ctx_mode;
  logic [15:0] ctx_words;

  logic        shell_sel_w;
  logic [31:0] shell_rdata_w;
  logic        shell_ready_w, shell_err_w;

  assign shell_sel_w = win_valid && (win_idx == 3'd0);

  mfsm_top #(
    .NUM_REGIONS(NUM_REGIONS), .PLATFORM_ID(32'h0000_0000),
    .REGION0_INFO(32'h0202_0010), .REGION1_INFO(32'h0202_0010)
  ) u_mfsm (
    .clk_i(clk), .rst_ni(rst_n),
    // EBI-Tiny Shell-CSR window slave (byte-addressed)
    .req_i(shell_sel_w), .we_i(win_we), .addr_i(win_addr),
    .wdata_i(win_wdata), .wstrb_i(win_wstrb),
    .rdata_o(shell_rdata_w), .ready_o(shell_ready_w), .err_o(shell_err_w),
    // OCC master
    .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid), .occ_cmd_ready_i(occ_cmd_ready),
    .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
    .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
    .occ_wdata_ready_i(occ_wdata_ready),
    .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
    .occ_region_locks_o(occ_region_locks), .occ_global_lock_o(occ_global_lock),
    .occ_expect_crc_o(m_occ_expect_crc), .occ_crc_result_i(m_occ_crc_result),
    // frame decoder trigger (packed path; unused by the v0 cfg-addr TB)
    .dec_start_o(dec_start), .dec_col_o(dec_col), .dec_busy_i(dec_busy_o),
    // context engine surface (no engine on this small-device profile)
    .ctx_start_o(ctx_start), .ctx_mode_o(ctx_mode), .ctx_words_o(ctx_words),
    .ctx_busy_i(1'b0), .ctx_done_i(1'b0), .ctx_err_i(1'b0)
  );

  // ============================================================
  // EBI-Tiny decoder: shell window -> mFSM; every other window is UNIMPLEMENTED
  // in this TB and is therefore terminated with ready+err (a defined error, never
  // a hang) — the termination rule ebi_tiny documents.
  // ============================================================
  ebi_tiny #(.NUM_REGIONS(NUM_REGIONS)) u_ebi (
    .req_i(h_req), .we_i(h_we), .addr_i(h_addr), .wdata_i(h_wdata), .wstrb_i(h_wstrb),
    .rdata_o(h_rdata), .ready_o(h_ready), .err_o(h_err),
    .win_valid_o(win_valid), .win_idx_o(win_idx), .win_we_o(win_we),
    .win_addr_o(win_addr), .win_wdata_o(win_wdata), .win_wstrb_o(win_wstrb),
    .win_rdata_i(win_rdata), .win_ready_i(win_ready), .win_err_i(win_err)
  );

  assign win_rdata = {32'h0 /*io*/, 32'h0 /*service*/, 32'h0 /*region1*/,
                      32'h0 /*region0*/, 32'h0 /*occ*/, shell_rdata_w /*shell*/};
  assign win_ready = {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, shell_ready_w};
  assign win_err   = {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, shell_err_w};

  // ============================================================
  // OCC + frame bus -> {fabric_top cfg port, readback mirror}
  // ============================================================
  logic [15:0] fbus_addr;
  logic [31:0] fbus_wdata;
  logic [31:0] fbus_rdata;
  logic        fbus_we, fbus_re;

  occ_top #(.ADDR_W(16), .DATA_W(32)) u_occ (
    .clk_i(clk), .rst_ni(rst_n),
    .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
    .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
    .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid), .wdata_ready_o(occ_wdata_ready),
    .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata), .fbus_we_o(fbus_we),
    .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
    .status_o(occ_status), .crc_error_o(occ_crc_error),
    .region_locks_i(occ_region_locks), .global_lock_i(occ_global_lock),
    .expect_crc_i(m_occ_expect_crc), .crc_result_o(m_occ_crc_result)
  );

  // readback mirror: same writes, combinational read (the v0 readback channel)
  column_cfg_ram #(.ADDR_W(16), .DATA_W(32)) u_cfg (
    .clk(clk), .we(fbus_we), .re(fbus_re),
    .addr(fbus_addr), .wdata(fbus_wdata), .rdata(fbus_rdata)
  );

  logic [OBS_W-1:0]  clb_out_obs;
  logic [R*C*32-1:0] mem_vd_obs;
  logic [R*C*48-1:0] dsp_vp_obs;

  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fabric (
    .clk_i(clk), .rst_ni(fab_rst_n),
    .cfg_we_i(fbus_we), .cfg_addr_i(fbus_addr), .cfg_data_i(fbus_wdata),
    .clb_out_obs_o(clb_out_obs), .mem_vd_obs_o(mem_vd_obs), .dsp_vp_obs_o(dsp_vp_obs),
    .scan_en_i(1'b0), .scan_in_i(1'b0), .scan_out_o()
  );

  // ============================================================
  // BMC-mode EMRI register face (the ABI-parity reference) + its idle OCC stub
  // ============================================================
  logic        b_req = 1'b0, b_we = 1'b0;
  logic [1:0]  b_op = SPI_OP_RD;
  logic [15:0] b_addr = 16'h0;
  logic [31:0] b_wdata = 32'h0;
  logic [31:0] b_rdata;
  logic        b_ready;

  emri_regfile #(
    .HAS_BMC(1'b1), .NUM_REGIONS(NUM_REGIONS), .PLATFORM_ID(32'h0000_0000),
    .REGION0_INFO(32'h0202_0010), .REGION1_INFO(32'h0202_0010)
  ) u_bmc (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(b_req), .host_we_i(b_we), .host_op_i(b_op),
    .host_addr_i(b_addr), .host_wdata_i(b_wdata),
    .host_rdata_o(b_rdata), .host_ready_o(b_ready),
    // The parity reference sees the SAME OCC inputs as the mFSM (same status,
    // same sticky CRC error, same running CRC), so the sweep compares the two
    // register faces on identical stimulus — the only difference left is the one
    // the spec allows (CAPABILITIES.has_bmc). Nothing drives its OCC command
    // outputs: the reference is read-only in this TB.
    .occ_cmd_o(), .occ_cmd_valid_o(), .occ_cmd_ready_i(1'b1),
    .occ_frame_addr_o(), .occ_word_count_o(), .occ_wdata_o(), .occ_wdata_valid_o(),
    .occ_wdata_ready_i(1'b1),
    .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
    .occ_region_locks_o(), .occ_global_lock_o(),
    .occ_expect_crc_o(), .occ_crc_result_i(m_occ_crc_result),
    .dec_start_o(), .dec_col_o(), .dec_busy_i(1'b0),
    .ctx_start_o(), .ctx_mode_o(), .ctx_words_o(),
    .ctx_busy_i(1'b0), .ctx_done_i(1'b0), .ctx_err_i(1'b0)
  );

  // ============================================================
  // Observability taps (TB-only): the session status word and a monitor proving
  // every §5 state is visited (a state like OCC_GO can be one cycle long, so
  // polling alone would be racy — the monitor is the coverage evidence).
  // ============================================================
  logic [7:0] sess_status_tap;
  assign sess_status_tap = u_mfsm.u_session.status_o;

  integer state_visits [0:SESSION_STATES-1];
  logic   bad_crc_seen;
  integer si;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bad_crc_seen <= 1'b0;
      for (si = 0; si < SESSION_STATES; si = si + 1) state_visits[si] <= 0;
    end else begin
      state_visits[sess_status_tap[SESSION_STATUS_STATE_LSB +: 4]]
          <= state_visits[sess_status_tap[SESSION_STATUS_STATE_LSB +: 4]] + 1;
      if (sess_status_tap[SESSION_STATUS_ERR_LSB +: 4] == SESSION_ERR_BAD_CRC)
        bad_crc_seen <= 1'b1;
    end
  end

  // ============================================================
  // Checks / BFM tasks
  // ============================================================
  integer errors = 0;
  integer checks = 0;
  task automatic chk(input logic cond, input [255:0] msg);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("  FAIL: %0s (t=%0t)", msg, $time);
      end
    end
  endtask

  // ---- EBI-Tiny transaction with explicit byte strobes ----
  integer wait_cycles;
  task automatic bus_op_s(input logic [31:0] a, input logic wr, input logic [31:0] d,
                         input logic [3:0] strb,
                         output logic [31:0] rd, output logic er);
    begin
      @(negedge clk);
      h_req = 1'b1; h_we = wr; h_addr = a; h_wdata = d; h_wstrb = strb;
      #1;
      wait_cycles = 0;
      while (!h_ready) begin
        if (wait_cycles > 200) begin
          // a held request that is never accepted is a fatal protocol failure: end
          // the run without printing TEST PASSED (no `disable` here — Verilator
          // mis-parses `disable` of the enclosing task's argument list)
          $display("  FAIL: bus_op timed out (addr=%08x we=%b)", a, wr);
          $display("TEST FAILED: bus_op timeout");
          $finish;
        end
        @(negedge clk); #1;
        wait_cycles = wait_cycles + 1;
      end
      rd = h_rdata; er = h_err;
      @(negedge clk);
      h_req = 1'b0; h_we = 1'b0; h_wstrb = 4'h0;
      #1;
    end
  endtask

  logic [31:0] rd_tmp;
  logic        er_tmp;
  task automatic bus_op(input logic [31:0] a, input logic wr, input logic [31:0] d,
                        output logic [31:0] rd, output logic er);
    begin
      bus_op_s(a, wr, d, 4'hF, rd, er);
    end
  endtask

  // ---- EMRI register access over EBI-Tiny (word offset -> byte address) ----
  logic [31:0] rv;
  logic        ev;
  task automatic ap(input logic [15:0] word, input logic [31:0] d);
    begin
      bus_op({16'h0, word} << 2, 1'b1, d, rd_tmp, ev);
      chk(ev == 1'b0, "EMRI write accepted");
    end
  endtask

  task automatic ard(input logic [15:0] word, output logic [31:0] d);
    begin
      bus_op({16'h0, word} << 2, 1'b0, 32'h0, d, ev);
      chk(ev == 1'b0, "EMRI read accepted");
    end
  endtask

  // ---- BMC-mode regfile access (the parity reference; word offset direct) ----
  task automatic bmc_rd(input logic [15:0] word, output logic [31:0] d);
    begin
      @(negedge clk);
      b_req = 1'b1; b_we = 1'b0; b_op = SPI_OP_RD; b_addr = word; b_wdata = 32'h0;
      @(posedge clk); while (!b_ready) @(posedge clk);
      d = b_rdata;
      @(negedge clk); b_req = 1'b0;
    end
  endtask

  // ---- OCC helpers ----
  logic [31:0] st_rv;
  logic [1:0]  dc_w;
  task automatic occ_issue(input logic [1:0] cmd, input logic [3:0] region);
    begin
      ap(R_OCC_CMD, (32'h1 << OCC_CMD_START) | ({28'h0, region} << 2) | {30'h0, cmd});
    end
  endtask

  task automatic wait_occ_done(output logic [1:0] code);
    integer i;
    begin
      i = 0;
      st_rv = 32'h0;
      do begin
        ard(R_OCC_STATUS, st_rv);
        i = i + 1;
        if (i > 4000) begin
          errors = errors + 1;
          $display("  FAIL: OCC done_flag timeout");
          code = 2'd1;
          return;
        end
      end while (st_rv[3] == 1'b0);
      code = st_rv[5:4];
    end
  endtask

  task automatic deploy_blank(input logic [15:0] base, input integer nwords);
    begin
      ap(R_OCC_FRAME_ADDR, {16'h0, base});
      ap(R_OCC_WORD_COUNT, nwords[15:0]);
      occ_issue(OCC_BLANK, 4'd0);
      wait_occ_done(dc_w);
      chk(dc_w == 2'd0, "BLANK done_code=DONE");
    end
  endtask

  task automatic deploy_write_arm(input logic [15:0] base, input integer nwords);
    begin
      ap(R_OCC_FRAME_ADDR, {16'h0, base});
      ap(R_OCC_WORD_COUNT, nwords[15:0]);
      occ_issue(OCC_WRITE, 4'd0);
    end
  endtask

  task automatic occ_push(input logic [31:0] d);
    begin
      ap(R_OCC_WDATA, d);
    end
  endtask

  // ADR-019 contract: the mFSM host flow MUST set OCC_EXPECT_CRC before every
  // READBACK (the value captured from OCC_CRC_RESULT after the WRITE/BLANK).
  task automatic readback_crc_gated(output logic [1:0] code, output logic crc_err);
    begin
      ard(R_OCC_CRC_RESULT, rv);
      ap(R_OCC_EXPECT_CRC, rv);
      occ_issue(OCC_READBACK, 4'd0);
      wait_occ_done(code);
      ard(R_OCC_STATUS, st_rv);
      crc_err = st_rv[16];
    end
  endtask

  // ---- session helpers ----
  task automatic sess_cmd(input logic [7:0] c);
    begin
      ap(R_SESSION_CMD, {24'h0, c});
    end
  endtask

  task automatic sess_expect(input logic [3:0] want_state, input logic [3:0] want_err,
                             input [255:0] msg);
    begin
      ard(R_SESSION_STATUS, rv);
      chk((rv[SESSION_STATUS_STATE_LSB +: 4] == want_state) &&
          (rv[SESSION_STATUS_ERR_LSB +: 4] == want_err), msg);
    end
  endtask

  // ---- image words (the same TFF / const1 images as tb_mgmt_hotswap) ----
  logic [31:0] img_a [0:15];
  logic [31:0] img_b [0:15];
  integer i, k;

  task automatic load_images;
    begin
      for (i = 0; i < 16; i = i + 1) begin
        img_a[i] = 32'h0;
        img_b[i] = 32'h0;
      end
      // image A: eLUT0 TFF (tt=0x5555, ff_en, ff_rst_en, ff_rst_val=0) at cfg 0
      img_a[0] = 32'h0005555C;
      // image B: eLUT0 const1
      img_b[0] = 32'h000FFFFE;
    end
  endtask

  task automatic fab_reset;
    begin
      @(negedge clk); fab_rst_n = 1'b0;
      @(negedge clk); @(negedge clk); fab_rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic observe_toggle(input logic expect_toggle, input [255:0] msg);
    integer j;
    logic seen_one, seen_zero;
    begin
      seen_one = 1'b0; seen_zero = 1'b0;
      for (j = 0; j < 8; j = j + 1) begin
        @(negedge clk);
        if (clb_out_obs[0] === 1'b1) seen_one = 1'b1;
        if (clb_out_obs[0] === 1'b0) seen_zero = 1'b1;
      end
      if (expect_toggle) chk(seen_one && seen_zero, msg);
      else               chk(seen_one && !seen_zero, msg);
    end
  endtask

  // ---- ABI parity sweep over the whole register map ----
  integer parity_diffs;
  logic [31:0] m_rd, b_rd_w;
  integer off_i;
  task automatic parity_sweep;
    begin
      parity_diffs = 0;
      // 0x00-0x3F (identity/status/OCC/session/EFP/telemetry) and 0x50-0x5F (IMG_SIG)
      for (off_i = 0; off_i < 64; off_i = off_i + 1) begin
        ard(off_i[15:0], m_rd);
        bmc_rd(off_i[15:0], b_rd_w);
        if (m_rd !== b_rd_w) begin
          parity_diffs = parity_diffs + 1;
          if (off_i != R_CAPABILITIES)
            $display("    parity mismatch @0x%02x: mfsm=%08x bmc=%08x", off_i, m_rd, b_rd_w);
        end
      end
      for (off_i = 80; off_i <= 95; off_i = off_i + 1) begin
        ard(off_i[15:0], m_rd);
        bmc_rd(off_i[15:0], b_rd_w);
        if (m_rd !== b_rd_w) begin
          parity_diffs = parity_diffs + 1;
          $display("    parity mismatch @0x%02x: mfsm=%08x bmc=%08x", off_i, m_rd, b_rd_w);
        end
      end
      // exactly ONE differing offset, and it must be CAPABILITIES
      chk(parity_diffs == 1, "parity: one differing offset");
      ard(R_CAPABILITIES, m_rd);
      bmc_rd(R_CAPABILITIES, b_rd_w);
      chk(m_rd[CAPB_HAS_BMC] == 1'b0, "mFSM CAPABILITIES.has_bmc = 0");
      chk(b_rd_w[CAPB_HAS_BMC] == 1'b1, "BMC CAPABILITIES.has_bmc = 1");
      $display("[mfsm]    parity sweep: %0d differing offsets (expect 1 = CAPABILITIES)",
               parity_diffs);
    end
  endtask

  // ============================================================
  // Test
  // ============================================================
  logic [31:0] rd_w;
  logic [1:0]  dc;
  logic        crc_err_w;

  initial begin
    load_images();
    rst_n = 1'b0;
    fab_rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    fab_rst_n = 1'b1;
    @(negedge clk);

    // ============================================================
    // A. EMRI identity in mFSM mode
    // ============================================================
    $display("[mfsm] A. EMRI identity (mFSM mode)");
    ard(R_MAGIC, rd_w);          chk(rd_w == EMRI_MAGIC, "MAGIC = 0x45544852");
    ard(R_ABI_VERSION, rd_w);    chk(rd_w == EMRI_ABI_VERSION, "ABI_VERSION = v0");
    ard(R_CAPABILITIES, rd_w);   chk(rd_w[CAPB_HAS_BMC] == 1'b0, "mode = mFSM");
    ard(R_PLATFORM_ID, rd_w);    chk(rd_w == 32'h0, "PLATFORM_ID = sim");
    ard(R_NUM_REGIONS, rd_w);    chk(rd_w[7:0] == 8'd2, "NUM_REGIONS = 2");
    ap(R_REGION_SEL, 32'h0);
    ard(R_REGION_INFO, rd_w);    chk(rd_w == 32'h0202_0010, "REGION0_INFO");
    ap(R_REGION_SEL, 32'h1);
    ard(R_REGION_INFO, rd_w);    chk(rd_w == 32'h0202_0010, "REGION1_INFO");
    ard(R_HEALTH_STATUS, rd_w);  chk(rd_w == 32'h0000_0101, "HEALTH_STATUS all-ok");
    ard(R_MON_TEMP, rd_w);       chk(rd_w == 32'h0000_0019, "MON_TEMP = 25C");
    ard(R_SESSION_STATUS, rd_w); chk(rd_w == 32'h0, "SESSION_STATUS idle at reset");
    ard(R_RX_BUF_CTRL, rd_w);    chk(rd_w == 32'h0000_4000, "RX_BUF_CTRL reset value");
    // reserved offsets read as 0 (spec §2)
    ard(16'h07, rd_w);           chk(rd_w == 32'h0, "reserved 0x07 reads 0");
    ard(16'h2B, rd_w);           chk(rd_w == 32'h0, "reserved 0x2B reads 0");
    ap(16'h07, 32'hDEAD_BEEF);   // write-ignored
    ard(16'h07, rd_w);           chk(rd_w == 32'h0, "reserved 0x07 write ignored");

    // EBI-Tiny termination rules
    bus_op(32'h0002_0000, 1'b1, 32'h1, rd_tmp, ev);  chk(ev == 1'b1, "undecoded page errors");
    bus_op(32'h0001_0000, 1'b1, 32'h1, rd_tmp, ev);  chk(ev == 1'b1, "OCC window unimplemented -> err");
    bus_op_s({16'h0, R_OCC_FRAME_ADDR} << 2, 1'b1, 32'h1234_5678, 4'h3, rd_tmp, ev);
    chk(ev == 1'b1, "partial-strobe write refused");
    ard(R_OCC_FRAME_ADDR, rd_w); chk(rd_w == 32'h0, "refused write: no effect");

    // ============================================================
    // B. ABI parity (ADR-015: ethctl cannot tell BMC from mFSM)
    // ============================================================
    $display("[mfsm] B. ABI parity sweep vs a BMC-mode register face");
    parity_sweep();

    // ============================================================
    // C. FULL DEPLOY FLOW - image A (TFF), terminal latched before occ_go
    // ============================================================
    $display("[mfsm] C. deploy image A through EBI-Tiny -> mFSM -> OCC -> fabric");
    deploy_blank(FRAME_BASE, IMG_WORDS);
    ap(R_RX_BUF_CTRL, {16'h0, IMG_WORDS});         // depth 12, wr_ptr 0
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_expect(SESSION_S_RX, SESSION_ERR_NONE, "begin_rx -> RX");
    ard(R_RX_BUF_CTRL, rd_w); chk(rd_w[31:16] == 16'h0, "wr_ptr cleared by begin_rx");
    deploy_write_arm(FRAME_BASE, IMG_WORDS);       // arm the OCC WRITE
    for (k = 0; k < IMG_WORDS; k = k + 1) begin
      occ_push(img_a[k]);
      // rx accounting: the pointer must track the accepted pushes
      if (k == 0) begin
        ard(R_RX_BUF_CTRL, rd_w);
        chk(rd_w[31:16] == 16'd1, "wr_ptr advanced on push");
        sess_expect(SESSION_S_RX, SESSION_ERR_NONE, "still RX before the buffer is full");
      end
    end
    ard(R_RX_BUF_CTRL, rd_w);
    chk(rd_w[31:16] == IMG_WORDS, "wr_ptr == depth after 12 pushes");
    sess_expect(SESSION_S_VERIFY, SESSION_ERR_NONE, "rx_buf full -> VERIFY_REQ (auto)");
    // a host 'verify' in VERIFY_REQ is a no-op (diagram has the edge from RX only)
    sess_cmd(SESSION_CMD_VERIFY);
    sess_expect(SESSION_S_VERIFY, SESSION_ERR_NONE, "verify in VERIFY_REQ is a no-op");
    // occ_go consumes the latched terminal (the WRITE completed before occ_go)
    sess_cmd(SESSION_CMD_OCC_GO);
    repeat (3) @(negedge clk);
    sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "occ_go -> IDLE on the latched OCC DONE");
    // ADR-019 contract: CRC-gated READBACK
    readback_crc_gated(dc, crc_err_w);
    chk(dc == 2'd0, "READBACK done_code=DONE");
    chk(crc_err_w == 1'b0, "READBACK crc_error=0");
    // the session command register is RW (spec §2)
    ard(R_SESSION_CMD, rd_w); chk(rd_w[7:0] == SESSION_CMD_OCC_GO, "SESSION_CMD reads back");
    // run the deployed image: TFF toggles
    fab_reset();
    observe_toggle(1'b1, "image A: clb_out[0] toggled");
    $display("[mfsm]    image A deployed: %0d words, CRC-gated readback OK", IMG_WORDS);

    // ============================================================
    // D. HOT-SWAP to image B (const1), terminal observed live in OCC_GO
    // ============================================================
    $display("[mfsm] D. hot-swap to image B (terminal arrives while in OCC_GO)");
    deploy_blank(FRAME_BASE, IMG_WORDS);
    ap(R_RX_BUF_CTRL, {16'h0, IMG_WORDS});
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_expect(SESSION_S_RX, SESSION_ERR_NONE, "image B: begin_rx -> RX");
    deploy_write_arm(FRAME_BASE, IMG_WORDS);
    for (k = 0; k < 11; k = k + 1) occ_push(img_b[k]);   // 11 of 12: OCC cannot finish
    sess_cmd(SESSION_CMD_VERIFY);                        // host-done -> VERIFY_REQ
    sess_expect(SESSION_S_VERIFY, SESSION_ERR_NONE, "explicit verify -> VERIFY_REQ");
    sess_cmd(SESSION_CMD_OCC_GO);
    sess_expect(SESSION_S_OCC_GO, SESSION_ERR_NONE, "occ_go -> OCC_GO (no terminal yet)");
    occ_push(img_b[11]);                                 // completes the OCC WRITE
    repeat (3) @(negedge clk);
    sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "live OCC DONE in OCC_GO -> IDLE");
    readback_crc_gated(dc, crc_err_w);
    chk((dc == 2'd0) && (crc_err_w == 1'b0), "image B READBACK clean");
    fab_reset();
    observe_toggle(1'b0, "image B: clb_out[0] constant 1 (hot-swap works)");
    $display("[mfsm]    image B deployed: hot-swap verified");

    // ============================================================
    // E. Session corner cases
    // ============================================================
    $display("[mfsm] E. session corner cases");

    // E1. abort from RX
    ap(R_RX_BUF_CTRL, {16'h0, IMG_WORDS});
    sess_cmd(SESSION_CMD_BEGIN_RX);  sess_expect(SESSION_S_RX, SESSION_ERR_NONE, "E1 in RX");
    sess_cmd(SESSION_CMD_ABORT);     sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "abort from RX -> IDLE");

    // E2. abort from VERIFY_REQ
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_cmd(SESSION_CMD_VERIFY);    sess_expect(SESSION_S_VERIFY, SESSION_ERR_NONE, "E2 in VERIFY_REQ");
    sess_cmd(SESSION_CMD_ABORT);     sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "abort from VERIFY_REQ -> IDLE");

    // E3. occ_go from the wrong states is a no-op (diagram: only VERIFY_REQ -> OCC_GO)
    sess_cmd(SESSION_CMD_OCC_GO);    sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "occ_go in IDLE is a no-op");
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_cmd(SESSION_CMD_OCC_GO);    sess_expect(SESSION_S_RX, SESSION_ERR_NONE, "occ_go in RX is a no-op");
    sess_cmd(SESSION_CMD_ABORT);

    // E4. OCC LOCKED -> err=occ_locked (§3.10 hardware gate, real occ_top status)
    ap(R_LKM_CMD, 32'h0000_0001);                 // opcode 1 = lock region 0
    ard(R_LKM_STATUS, rd_w); chk(rd_w[0] == 1'b1, "region 0 locked (LKM_STATUS)");
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_cmd(SESSION_CMD_VERIFY);
    sess_cmd(SESSION_CMD_OCC_GO);
    sess_expect(SESSION_S_OCC_GO, SESSION_ERR_NONE, "E4 in OCC_GO");
    deploy_write_arm(FRAME_BASE, IMG_WORDS);       // refused by the lock gate
    wait_occ_done(dc);
    chk(dc == 2'd3, "locked WRITE: done_code=LOCKED");
    repeat (2) @(negedge clk);
    sess_expect(SESSION_S_ERROR, SESSION_ERR_OCC_LOCKED, "LOCKED -> ERROR err=occ_locked");
    sess_cmd(SESSION_CMD_ABORT);
    sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "abort from ERROR -> IDLE");
    ap(R_LKM_CMD, 32'h0000_0002);                 // opcode 2 = unlock region 0
    ard(R_LKM_STATUS, rd_w); chk(rd_w[0] == 1'b0, "region 0 unlocked");

    // E5. OCC READBACK CRC mismatch -> err=occ_error
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_cmd(SESSION_CMD_VERIFY);
    sess_cmd(SESSION_CMD_OCC_GO);
    sess_expect(SESSION_S_OCC_GO, SESSION_ERR_NONE, "E5 in OCC_GO");
    ap(R_OCC_EXPECT_CRC, 32'hDEAD_BEEF);           // wrong expected CRC
    ap(R_OCC_FRAME_ADDR, {16'h0, FRAME_BASE});
    ap(R_OCC_WORD_COUNT, {16'h0, IMG_WORDS});
    occ_issue(OCC_READBACK, 4'd0);
    wait_occ_done(dc);
    chk(dc == 2'd1, "bad-expect READBACK: ERROR code");
    repeat (2) @(negedge clk);
    sess_expect(SESSION_S_ERROR, SESSION_ERR_OCC_ERROR, "OCC ERROR -> err=occ_error");
    sess_cmd(SESSION_CMD_ABORT);

    // E6. dirty region: a WRITE without BLANK -> NEEDS_BLANK -> err=occ_error
    //     (region 0 is dirty after the image-B WRITE/READBACK; no BLANK issued)
    sess_cmd(SESSION_CMD_BEGIN_RX);
    sess_cmd(SESSION_CMD_VERIFY);
    sess_cmd(SESSION_CMD_OCC_GO);
    sess_expect(SESSION_S_OCC_GO, SESSION_ERR_NONE, "E6 in OCC_GO");
    deploy_write_arm(FRAME_BASE, IMG_WORDS);       // refused: needs blank
    wait_occ_done(dc);
    chk(dc == 2'd2, "dirty WRITE: done_code=NEEDS_BLANK");
    repeat (2) @(negedge clk);
    sess_expect(SESSION_S_ERROR, SESSION_ERR_OCC_ERROR, "NEEDS_BLANK -> err=occ_error");
    sess_cmd(SESSION_CMD_ABORT);
    sess_expect(SESSION_S_IDLE, SESSION_ERR_NONE, "abort after E6 -> IDLE");

    // E7. err=bad_crc has no v0 producer (§5 G6: the host verifies)
    chk(bad_crc_seen == 1'b0, "err=bad_crc was never produced");

    // ============================================================
    // F. §5 state coverage (the monitor, not polling: OCC_GO can be 1 cycle)
    // ============================================================
    $display("[mfsm] F. session FSM state coverage");
    for (si = 0; si < SESSION_STATES; si = si + 1)
      $display("[mfsm]    state %0d visited %0d times", si, state_visits[si]);
    for (si = 0; si < SESSION_STATES; si = si + 1)
      chk(state_visits[si] > 0, "every §5 state visited");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: mFSM EMRI ABI parity + full deploy flow on EBI-Tiny (%0d checks)", checks);
    else
      $display("TEST FAILED: %0d error(s) in %0d checks", errors, checks);
    $finish;
  end

  // watchdog
  initial begin
    #20000000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
