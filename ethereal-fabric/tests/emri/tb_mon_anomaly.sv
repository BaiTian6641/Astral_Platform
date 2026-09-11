`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_mon_anomaly (testbench, self-checking)
// Description: Exercises the EMRI v0.6 security half in emri_regfile:
//              the §3.7 capability-declaration gate (CAP_DECL_IO/CAP_DECL_SVC
//              staging + the read-only CAP_STATUS comparator) and the §3.8
//              anomaly monitor v1 (MON_NOTIFY counting, saturating per-region
//              counters, observation window + spike thresholds, throttle mask,
//              W1C release, code-5 event-ring pushes).
// Details:     Drives the host register port directly (no SPI/AXI adapter) and
//              ties off the unused OCC/frame-decoder inputs, so the test stays
//              focused on the register semantics. The observation window is
//              shrunk via MON_ANOM_WINDOW (RW) to a few ticks, and the DUT's
//              monitor divider (dut.mon_div_r) is probed hierarchically to
//              align notify bursts to a window boundary — a burst that would
//              straddle an expiry would split its delta and make the check
//              flaky. Covers: reset defaults; capability allow/deny/checked
//              latch/EFP_CMD clear; counter increments + per-region isolation +
//              saturation (0xFFFF then one more); window expiry -> spike flag +
//              throttle + one code-5 ring entry; no re-push while a region stays
//              flagged; W1C partial/full release re-arming the next event;
//              reconfig and watchdog spikes on both regions; a raised threshold
//              suppressing the flag; MON_ANOM_WINDOW=0 disabling all flags while
//              the counters still count (and no stale-delta spike on re-enable);
//              same-cycle host-push/monitor-push ring arbitration (bus push
//              priority, deferred event still lands, no ring corruption).
// Maintainer:  BaiTian6641
// Created:     2026-09-11
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3.7/§3.8
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED" on success.
//              Run: iverilog -g2012 -o /tmp/tb_mon \
//                     ethereal-shell/rtl/emri/emri_pkg.sv \
//                     ethereal-shell/rtl/emri/emri_regfile.sv \
//                     ethereal-fabric/tests/emri/tb_mon_anomaly.sv && vvp /tmp/tb_mon
`timescale 1ns/1ps
module tb_mon_anomaly;
  import emri_pkg::*;

  // ---- shrunk observation window used by this TB ----
  localparam int MON_TICK  = 4096;              // clocks per monitor tick (§3.8)
  localparam int WIN_TICKS = 4;                 // window written by the TB
  localparam int WIN_CLKS  = WIN_TICKS * MON_TICK;

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

  // ---- DUT (OCC / frame-decoder inputs tied off; not exercised here) ----
  emri_regfile #(
    .HAS_BMC(1'b0), .NUM_REGIONS(2)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
    .host_addr_i(host_addr), .host_wdata_i(host_wdata),
    .host_rdata_o(host_rdata), .host_ready_o(host_ready),
    .occ_cmd_o(), .occ_cmd_valid_o(), .occ_cmd_ready_i(1'b0),
    .occ_frame_addr_o(), .occ_word_count_o(),
    .occ_wdata_o(), .occ_wdata_valid_o(), .occ_wdata_ready_i(1'b1),
    .occ_status_i(OCC_S_IDLE), .occ_crc_error_i(1'b0),
    .occ_region_locked_o(),
    .occ_expect_crc_o(), .occ_crc_result_i(32'h0),
    .dec_start_o(), .dec_col_o(), .dec_busy_i(1'b0)
  );

  // ============================================================
  // Host driver tasks (same idiom as tb_emri_regfile)
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

  // ============================================================
  // Monitor-window helpers (white-box divider probe for deterministic phase)
  // ============================================================
  // Align to the cycle just after a monitor tick (the DUT divider reloads to 0
  // on the tick edge) -> a following notify burst has a full window of headroom
  // and can never straddle a window expiry.
  task automatic align_to_tick;
    begin
      while (dut.mon_div_r != 0) @(posedge clk);
    end
  endtask

  // Notify burst placed inside one window (aligned first).
  task automatic notify_burst(input logic [31:0] w, input int n);
    begin
      align_to_tick();
      for (int i = 0; i < n; i = i + 1) host_write(R_MON_NOTIFY, w);
    end
  endtask

  // Exactly one window expiry must elapse after an aligned burst: the next
  // expiry is at most WIN_CLKS away, the one after that needs another full
  // window (>= 2*WIN_CLKS), so a WIN_CLKS + 512 cycle wait covers it once.
  task automatic wait_expiry;
    begin
      repeat (WIN_CLKS + 512) @(posedge clk);
    end
  endtask

  // assertion helpers
  int errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin
      if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end
    end
  endtask
  task automatic chk_eq(input logic [31:0] got, input logic [31:0] exp,
                        input [255:0] msg);
    begin
      if (got !== exp) begin
        errors = errors + 1;
        $display("  FAIL: %0s (got 0x%08x, exp 0x%08x)", msg, got, exp);
      end
    end
  endtask

  // ============================================================
  // Test sequence
  // ============================================================
  logic [31:0] rd;
  logic [31:0] recfg_before, wdt_before;
  int          poll_cnt;
  int          sat_n;

  initial begin
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ================= 1. Reset defaults (spec §2 offsets 0x24/0x32-0x36) ====
    host_read(R_CAP_STATUS, rd);      chk_eq(rd, 32'h0, "CAP_STATUS reset 0");
    host_read(R_MON_ANOM_STATUS, rd); chk_eq(rd, 32'h0, "MON_ANOM_STATUS reset 0");
    host_read(R_MON_ANOM_WINDOW, rd); chk_eq(rd, 32'h0000_1000, "MON_ANOM_WINDOW reset 0x1000");
    host_read(R_MON_ANOM_THRESH, rd); chk_eq(rd, 32'h0008_0010, "MON_ANOM_THRESH reset 0x0008_0010");
    host_read(R_MON_RECFG_COUNT, rd); chk_eq(rd, 32'h0, "MON_RECFG_COUNT reset 0");
    host_read(R_MON_WDT_COUNT, rd);   chk_eq(rd, 32'h0, "MON_WDT_COUNT reset 0");
    host_read(R_MON_NOTIFY, rd);      chk_eq(rd, 32'h0, "MON_NOTIFY reads 0");
    host_read(R_CAP_DECL_IO, rd);     chk_eq(rd, 32'h0, "CAP_DECL_IO reset 0");
    host_read(R_CAP_DECL_SVC, rd);    chk_eq(rd, 32'h0, "CAP_DECL_SVC reset 0");

    // ================= 2. Capability gate (§3.7) ===========================
    // Empty declaration: no CAP_DECL write yet -> checked=0, denied=0.
    host_read(R_CAP_STATUS, rd);
    chk(rd[0] == 1'b0 && rd[1] == 1'b0 && rd[2] == 1'b0, "empty decl: checked/denied/throttled = 0");

    // An explicit (still empty) declaration write latches checked.
    host_write(R_CAP_DECL_IO, 32'h0000_0000);
    host_read(R_CAP_STATUS, rd);
    chk(rd[0] == 1'b1 && rd[1] == 1'b0, "checked latches on first CAP_DECL write");

    // ... and the EFP_CMD doorbell clears the verdict for the next session.
    host_write(R_EFP_CMD, 32'h0000_0001);
    host_read(R_CAP_STATUS, rd);      chk_eq(rd, 32'h0, "EFP_CMD write clears CAP_STATUS");
    // (staging must survive the doorbell: the host writes CAP_DECL BEFORE it)
    host_write(R_CAP_DECL_IO, 32'h0000_0003);
    host_write(R_EFP_CMD, 32'h0000_0001);
    host_read(R_CAP_DECL_IO, rd);     chk_eq(rd, 32'h3, "CAP_DECL_IO survives the doorbell");
    host_read(R_CAP_STATUS, rd);      chk(rd[0] == 1'b0, "checked cleared again by EFP_CMD");

    // Allow: all declared bits inside the sim inventory mask (0..7 allowed).
    host_write(R_CAP_DECL_IO, ALLOWED_IO_GROUPS);
    host_write(R_CAP_DECL_SVC, ALLOWED_SERVICES);
    host_read(R_CAP_STATUS, rd);
    chk(rd[0] == 1'b1 && rd[1] == 1'b0 && rd[15:8] == 8'h0, "max allowed decl: checked, not denied");

    // Deny (IO): bit 8 = pin group 8, outside the granted groups 0..7.
    // NOTE: a group id that does not fit the 32-bit bitmap at all (e.g. the
    // assignment's "group 200") is refused host-side at pre-flight
    // (capcheck.py stage 2) and can never appear in CAP_DECL_IO; the register
    // sees the first in-range offending group, bit 8.
    host_write(R_CAP_DECL_IO, 32'h0000_0104);   // group 2 (allowed) + group 8 (refused)
    host_read(R_CAP_STATUS, rd);
    chk(rd[1] == 1'b1, "denied set for a declared group outside the inventory");
    chk(rd[2] == 1'b0, "throttled unaffected by a capability deny");
    // denied_io = LOW 8 bits of the offending bitmap (declared & ~allowed).
    // With the sim mask 0xFF the offending bits are all in [31:8], so the field
    // is 0 here; the check pins the field's definition (not the declaration
    // echo: the allowed group 2 in the low byte must NOT show up).
    chk_eq({24'h0, rd[15:8]},
           ((32'h0000_0104 & ~ALLOWED_IO_GROUPS) & 32'h0000_00FF),
           "denied_io = low byte of the offending bitmap");

    // Deny (service): proxy index 9, outside the granted proxies 0..7.
    host_write(R_CAP_DECL_IO, 32'h0000_0000);
    host_write(R_CAP_DECL_SVC, 32'h0000_0200);
    host_read(R_CAP_STATUS, rd);
    chk(rd[1] == 1'b1 && rd[15:8] == 8'h0, "service deny sets denied (no IO offender)");
    host_write(R_CAP_DECL_SVC, 32'h0000_0000);
    host_read(R_CAP_STATUS, rd);      chk_eq(rd[1:0], 2'b01, "cleared decl -> denied drops, checked stays");

    // Wide declaration (every bit set) is refused too; CAP_STATUS is RO.
    host_write(R_CAP_DECL_IO, 32'hFFFF_FFFF);
    host_write(R_CAP_DECL_SVC, 32'hFFFF_FFFF);
    host_read(R_CAP_STATUS, rd);
    chk(rd[1] == 1'b1, "all-ones declaration denied");
    host_write(R_CAP_STATUS, 32'hFFFF_FFFF);   // RO: must not take
    host_read(R_CAP_STATUS, rd);
    chk(rd[1] == 1'b1 && rd[0] == 1'b1 && rd[2] == 1'b0, "CAP_STATUS write ignored (read-only)");
    host_write(R_CAP_DECL_IO, 32'h0000_0000);
    host_write(R_CAP_DECL_SVC, 32'h0000_0000);
    host_read(R_CAP_STATUS, rd);      chk_eq(rd[1:0], 2'b01, "declaration cleared");

    // ================= 3. MON_NOTIFY counting (§3.8) =======================
    host_write(R_MON_NOTIFY, 32'h0000_0001);   // bit 0  -> recfg region 0
    host_write(R_MON_NOTIFY, 32'h0000_0001);
    host_write(R_MON_NOTIFY, 32'h0000_0001);
    host_read(R_MON_RECFG_COUNT, rd);  chk_eq(rd, 32'h0000_0003, "recfg r0 = 3");
    host_write(R_MON_NOTIFY, 32'h0000_0002);   // bit 1  -> recfg region 1
    for (int i = 0; i < 4; i = i + 1) host_write(R_MON_NOTIFY, 32'h0000_0002);
    host_read(R_MON_RECFG_COUNT, rd);  chk_eq(rd, 32'h0005_0003, "recfg = {r1=5, r0=3} (isolation)");
    host_write(R_MON_NOTIFY, 32'h0000_0100);   // bit 8  -> wdt region 0
    host_write(R_MON_NOTIFY, 32'h0000_0100);
    host_read(R_MON_WDT_COUNT, rd);    chk_eq(rd, 32'h0000_0002, "wdt r0 = 2");
    host_write(R_MON_NOTIFY, 32'h0000_0200);   // bit 9  -> wdt region 1
    host_read(R_MON_WDT_COUNT, rd);    chk_eq(rd, 32'h0001_0002, "wdt = {r1=1, r0=2}");
    host_read(R_MON_RECFG_COUNT, rd);  chk_eq(rd, 32'h0005_0003, "wdt notifies leave recfg alone");
    host_read(R_MON_NOTIFY, rd);       chk_eq(rd, 32'h0, "MON_NOTIFY still reads 0 (write-only)");
    // One notify word can pulse both counters of a region.
    host_write(R_MON_NOTIFY, 32'h0000_0101);   // recfg r0 + wdt r0
    host_read(R_MON_RECFG_COUNT, rd);  chk_eq(rd[15:0], 16'd4, "b0+b8 in one write: recfg r0 +1");
    host_read(R_MON_WDT_COUNT, rd);    chk_eq(rd[15:0], 16'd3, "b0+b8 in one write: wdt r0 +1");

    // ================= 4. Window expiry / spike / throttle / event ==========
    host_write(R_MON_ANOM_WINDOW, WIN_TICKS);
    // Prime: one expiry with the small step-3 counts (< thresholds) snapshots
    // the baselines, so the spike windows below start from a clean delta.
    align_to_tick(); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "no flag while deltas are below threshold");

    // Reconfig-rate spike, region 0: delta 17 > thr_recfg 16.
    notify_burst(32'h0000_0001, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);
    chk_eq(rd, 32'h0000_0101, "recfg spike r0: flag8 + throttle0");
    host_read(R_CAP_STATUS, rd);       chk(rd[2] == 1'b1, "CAP_STATUS throttled is live");
    host_read(R_EVT_LOG_CTRL, rd);     chk_eq(rd[15:0], 16'd1, "one code-5 event pushed");
    host_read(R_EVT_LOG_DATA, rd);
    chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE && rd[15:8] == 8'd0, "event = {code 5, region 0}");

    // A region that STAYS flagged does not re-push (first 0->1 per window).
    notify_burst(32'h0000_0001, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0101, "flag unchanged on a repeat spike");
    host_read(R_EVT_LOG_CTRL, rd);     chk_eq(rd[15:0], 16'd0, "no duplicate code-5 event");

    // W1C: partial clear keeps the un-written bits; full clear releases both.
    host_write(R_MON_ANOM_STATUS, 32'h0000_0100);
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0001, "W1C clears only the written bit");
    host_write(R_MON_ANOM_STATUS, 32'h0000_0001);
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "W1C clears the throttle bit");
    host_read(R_CAP_STATUS, rd);       chk(rd[2] == 1'b0, "throttled drops after W1C release");

    // Release re-arms the monitor: the next spike is a fresh 0->1 transition.
    notify_burst(32'h0000_0001, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0101, "re-armed flag after W1C");
    host_read(R_EVT_LOG_CTRL, rd);     chk_eq(rd[15:0], 16'd1, "release pushes a new code-5 event");
    host_read(R_EVT_LOG_DATA, rd);     chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE, "new event is code 5");

    // Region 1 reconfig spike -> flag9 + throttle1 + region-1 event.
    host_write(R_MON_ANOM_STATUS, 32'h0000_0101);
    notify_burst(32'h0000_0002, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0202, "recfg spike r1: flag9 + throttle1");
    host_read(R_EVT_LOG_DATA, rd);
    chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE && rd[15:8] == 8'd1, "event = {code 5, region 1}");

    // Watchdog-rate spike, region 0: delta 9 > thr_wdt 8 -> flag10 + throttle0.
    host_write(R_MON_ANOM_STATUS, 32'h0000_0202);
    notify_burst(32'h0000_0100, 9); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0401, "wdt spike r0: flag10 + throttle0");
    host_read(R_EVT_LOG_DATA, rd);
    chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE && rd[15:8] == 8'd0, "wdt spike pushes code 5 (r0)");

    // A raised threshold suppresses the flag (delta must EXCEED it).
    host_write(R_MON_ANOM_STATUS, 32'h0000_0401);
    host_write(R_MON_ANOM_THRESH, 32'h0008_FFFF);   // recfg thr 0xFFFF
    notify_burst(32'h0000_0001, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "delta 17 <= thr 0xFFFF: no flag");
    host_write(R_MON_ANOM_THRESH, 32'h0008_0010);   // restore spec default

    // ================= 5. MON_ANOM_WINDOW = 0 disables the monitor =========
    host_write(R_MON_ANOM_WINDOW, 32'h0);
    host_read(R_MON_RECFG_COUNT, rd);  recfg_before = rd;
    host_read(R_MON_WDT_COUNT, rd);    wdt_before   = rd;
    notify_burst(32'h0000_0001, 20);    // would exceed thr_recfg if enabled
    notify_burst(32'h0000_0100, 20);    // would exceed thr_wdt if enabled
    repeat (2 * WIN_CLKS) @(posedge clk);   // two full windows of disabled time
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "disabled monitor never sets a flag");
    host_read(R_MON_RECFG_COUNT, rd);
    chk_eq(rd[15:0], recfg_before[15:0] + 16'd20, "disabled: recfg counter still counts");
    host_read(R_MON_WDT_COUNT, rd);
    chk_eq(rd[15:0], wdt_before[15:0] + 16'd20, "disabled: wdt counter still counts");

    // Re-enabling must not fire on the accumulation gathered while disabled
    // (the window baselines track the counters while the monitor is off).
    host_write(R_MON_ANOM_WINDOW, WIN_TICKS);
    align_to_tick(); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "no stale-delta spike after re-enable");
    // ... and the monitor is live again.
    notify_burst(32'h0000_0001, 17); wait_expiry();
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0000_0101, "re-enabled monitor spikes again");
    host_read(R_EVT_LOG_DATA, rd);     // drain that event so the ring starts empty
    chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE && rd[15:8] == 8'd0,
        "re-enabled spike pushed a code-5 r0 event");

    // ================= 6. Ring push arbitration (host vs monitor) ===========
    // window = 1 tick: the spike lands on the next monitor tick. Align, burst,
    // then wait for the owed event and contend with a bus push on the exact
    // cycle the hardware push would fire.
    host_write(R_MON_ANOM_STATUS, 32'h0000_0101);
    host_write(R_MON_ANOM_WINDOW, 32'h0000_0001);
    align_to_tick();
    for (int i = 0; i < 17; i = i + 1) host_write(R_MON_NOTIFY, 32'h0000_0001);
    // Poll the owed flag at the negedge (mid-cycle, after the DUT's
    // non-blocking updates have settled) so the exit lands one cycle before the
    // hardware push edge; a posedge-sampled read could observe the stale value
    // and assert the bus request one cycle late.
    poll_cnt = 0;
    while (!dut.mon_evt_owed_r[0] && poll_cnt < 20000) begin
      @(negedge clk); poll_cnt = poll_cnt + 1;
    end
    chk(dut.mon_evt_owed_r[0] === 1'b1, "code-5 event owed after the window expiry");
    // Bus push on the cycle the hw push is due -> the bus entry wins, the
    // monitor event is deferred (not dropped).
    host_req=1'b1; host_we=1'b1; host_op=SPI_OP_WR; host_addr=R_EVT_LOG_DATA;
    host_wdata=32'hA5A5_0001;
    @(posedge clk);
    chk(host_ready === 1'b1, "contended bus push accepted");
    @(negedge clk);
    host_req=1'b0;
    @(posedge clk);                    // deferred monitor push lands here
    host_read(R_EVT_LOG_CTRL, rd);     chk_eq(rd[15:0], 16'd2, "both producers' entries counted");
    host_read(R_EVT_LOG_DATA, rd);     chk_eq(rd, 32'hA5A5_0001, "bus push kept priority (entry #1)");
    host_read(R_EVT_LOG_DATA, rd);
    chk(rd[7:0] == EVT_CODE_ANOMALY_THROTTLE && rd[15:8] == 8'd0,
        "deferred event still pushed (entry #2, code 5 r0)");
    chk(dut.mon_evt_owed_r[0] === 1'b0, "owed event consumed exactly once");
    host_read(R_EVT_LOG_CTRL, rd);     chk_eq(rd[15:0], 16'd0, "ring fully drained");

    // ================= 7. Counter saturation (per region, 0xFFFF) ===========
    // Monitor disabled so the >0xFFFF burst cannot raise flags; counters still
    // count (already shown above). Release the flag left set by step 6 first.
    host_write(R_MON_ANOM_WINDOW, 32'h0);
    host_write(R_MON_ANOM_STATUS, 32'h0000_0101);
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "step-6 flag released before the burst");
    host_read(R_MON_RECFG_COUNT, rd);  recfg_before = rd;
    host_read(R_MON_WDT_COUNT, rd);    wdt_before   = rd;
    sat_n = 32'hFFFF - {16'h0, recfg_before[31:16]};
    for (int i = 0; i < sat_n; i = i + 1) host_write(R_MON_NOTIFY, 32'h0000_0002);
    host_read(R_MON_RECFG_COUNT, rd);
    chk_eq(rd[31:16], 16'hFFFF, "region-1 recfg counter saturates at 0xFFFF");
    chk_eq(rd[15:0], recfg_before[15:0], "region-0 counter unaffected by region-1 notifies");
    host_write(R_MON_NOTIFY, 32'h0000_0002);   // one more: must not wrap
    host_read(R_MON_RECFG_COUNT, rd);
    chk_eq(rd[31:16], 16'hFFFF, "saturated counter holds (no wrap)");
    host_read(R_MON_WDT_COUNT, rd);    chk_eq(rd, wdt_before, "recfg notifies leave wdt untouched");
    host_read(R_MON_NOTIFY, rd);       chk_eq(rd, 32'h0, "MON_NOTIFY reads 0 after 64k pulses");
    host_read(R_MON_ANOM_STATUS, rd);  chk_eq(rd, 32'h0, "no flag from the saturated-counter burst");

    // ================= report =============================================
    if (errors == 0)
      $display("TEST PASSED: mon_anomaly (EMRI v0.6 capability gate + anomaly monitor v1)");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // global watchdog (the window/saturation tests are ~3 ms of sim time)
  initial begin
    #20000000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
