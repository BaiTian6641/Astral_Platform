`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_ebi_tiny (testbench, self-checking)
// Description: E0-SHL1 acceptance — EBI-Tiny bus + address-map decoder against a
//              bus functional model (BFM): directed decode/aliasing/error checks
//              plus a 10,000-operation DETERMINISTIC pseudo-random read/write
//              consistency sweep (S04 §4 "BFM 随机读写 10k 次一致").
// Details:     The DUT (ebi_tiny, NUM_REGIONS=2 -> 6 windows) is wired to six
//              behavioral window slaves, each a 256-word model memory preloaded
//              with a window-KEYed pattern, so a transaction that lands in the
//              WRONG window is detected even when the address math is only off by
//              one page. The slaves implement the two properties a real window
//              must have:
//                * COMMIT on `win_valid_o && win_we_o && (win_idx_o == w) &&
//                  win_ready_i[w]` — exactly ONE commit per request even while
//                  the request is held across stall cycles;
//                * answer the read COMBINATIONALLY from the intra-window offset
//                  while the request is held (the accept cycle sees the data).
//              Error injection: window 0 (shell) answers offset 0xFFC with
//              win_err_i; windows 4 (service) and 5 (io) are read-only (a write
//              errors). Undecoded pages, and a region page >= NUM_REGIONS (a
//              window that does not exist), must be answered ready+err by the
//              decoder itself — never a hang.
//
//              CHECKS
//               1. per-window decode/select (window index + write strobe) and
//                  cross-window isolation (no crosstalk; read-only windows keep
//                  their preloaded pattern);
//               2. address-map boundaries (last word of a window vs first word of
//                  the next; region range end; unmapped pages);
//               3. slave error propagation (reserved offset, read-only windows)
//                  and that an errored write has NO side effect;
//               4. hold-until-ready: window 1 (OCC) accepts only when its service
//                  phase reaches 2, so a held request must wait; the BFM asserts
//                  it observed the wait AND that exactly one word was committed;
//               5. 10,000 random accesses: every access's err expectation matches,
//                  every successful read returns the model word, and the per-window
//                  commit counters equal the BFM's per-window write counts (no
//                  lost, duplicated or miscounted transaction) — with coverage
//                  counters proving the sweep hit reads, writes and every window.
//              Randomness is a fixed-seed xorshift32 LFSR (no $random), so a
//              failure is reproducible from the seed alone.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md §2/§4
//              (EBI-Tiny + "BFM 随机读写 10k 次一致" acceptance) ·
//              docs/Ethereal-平台实施蓝图-v2.md §4.2 (address map) ·
//              docs/adr/ADR-006 (profile) / ADR-018 (small-device fallback)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED". Run:
//              iverilog -g2012 -o /tmp/tb_ebi ethereal-shell/rtl/ebi/ebi_pkg.sv \
//                ethereal-shell/rtl/ebi/ebi_tiny.sv \
//                ethereal-fabric/tests/ebi/tb_ebi_tiny.sv && vvp /tmp/tb_ebi
`timescale 1ns/1ps
module tb_ebi_tiny;
  import ebi_pkg::*;

  // ---- DUT geometry ----
  localparam int NUM_REGIONS = 2;
  localparam int NUM_WINDOWS = 4 + NUM_REGIONS;   // 6

  // ---- window indices (ebi_pkg order: shell, occ, regions, service, io) ----
  localparam int WIN_SHELL   = EBI_WIN_SHELL_CSR;      // 0
  localparam int WIN_OCC     = EBI_WIN_OCC;            // 1
  localparam int WIN_R0      = EBI_WIN_REGION0;        // 2
  localparam int WIN_R1      = WIN_R0 + 1;             // 3
  localparam int WIN_SERVICE = WIN_R0 + NUM_REGIONS;   // 4
  localparam int WIN_IO      = WIN_SERVICE + 1;        // 5

  // ---- TB model geometry ----
  localparam int  MIB_WORDS = 256;                 // model words per window
  localparam int  N_OPS     = 10000;               // BFM random ops (S04 acceptance)
  localparam logic [31:0] KEY = 32'hA5A5_0000;     // window key base

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;   // 100 MHz

  // ---- master (BFM) side ----
  logic        req    = 1'b0;
  logic        we     = 1'b0;
  logic [31:0] addr   = 32'h0;
  logic [31:0] wdata  = 32'h0;
  logic [3:0]  wstrb  = 4'hF;
  logic [31:0] rdata;
  logic        ready;
  logic        err;

  // ---- decoded window fan-out ----
  logic                win_valid;
  logic [2:0]          win_idx;
  logic                win_we;
  logic [15:0]         win_addr;
  logic [31:0]         win_wdata;
  logic [3:0]          win_wstrb;
  logic [NUM_WINDOWS*32-1:0] win_rdata;
  logic [NUM_WINDOWS-1:0]    win_ready;
  logic [NUM_WINDOWS-1:0]    win_err;

  ebi_tiny #(.NUM_REGIONS(NUM_REGIONS)) dut (
    .req_i(req), .we_i(we), .addr_i(addr), .wdata_i(wdata), .wstrb_i(wstrb),
    .rdata_o(rdata), .ready_o(ready), .err_o(err),
    .win_valid_o(win_valid), .win_idx_o(win_idx), .win_we_o(win_we),
    .win_addr_o(win_addr), .win_wdata_o(win_wdata), .win_wstrb_o(win_wstrb),
    .win_rdata_i(win_rdata), .win_ready_i(win_ready), .win_err_i(win_err)
  );

  // ============================================================
  // Window slave models (module-level arrays: iverilog cannot pass arrays into
  // tasks)
  // ============================================================
  logic [31:0] mem_shell [0:MIB_WORDS-1];
  logic [31:0] mem_occ   [0:MIB_WORDS-1];
  logic [31:0] mem_r0    [0:MIB_WORDS-1];
  logic [31:0] mem_r1    [0:MIB_WORDS-1];
  logic [31:0] mem_svc   [0:MIB_WORDS-1];
  logic [31:0] mem_io    [0:MIB_WORDS-1];

  logic [7:0] midx;
  assign midx = win_addr[9:2];   // model word index (intra-window, word-aligned)

  // Commit counters: one per accepted transaction, per window.
  integer commit_shell, commit_occ, commit_r0, commit_r1, commit_svc, commit_io;
  // BFM-issued write counters per window (the expected commit deltas).
  integer bfm_w_shell, bfm_w_occ, bfm_w_r0, bfm_w_r1, bfm_w_svc, bfm_w_io;

  // Accept strobes: the exactly-once commit condition of the bus contract —
  // valid AND selected AND a write AND the slave itself ready, and NOT an error
  // response (a slave that raises win_err_i must have taken no side effect).
  logic acc_shell, acc_occ, acc_r0, acc_r1, acc_svc, acc_io;
  assign acc_shell = win_valid && win_we && (win_idx == WIN_SHELL[2:0])   && win_ready[WIN_SHELL]   && !win_err[WIN_SHELL];
  assign acc_occ   = win_valid && win_we && (win_idx == WIN_OCC[2:0])     && win_ready[WIN_OCC]     && !win_err[WIN_OCC];
  assign acc_r0    = win_valid && win_we && (win_idx == WIN_R0[2:0])      && win_ready[WIN_R0]      && !win_err[WIN_R0];
  assign acc_r1    = win_valid && win_we && (win_idx == WIN_R1[2:0])      && win_ready[WIN_R1]      && !win_err[WIN_R1];
  assign acc_svc   = win_valid && win_we && (win_idx == WIN_SERVICE[2:0]) && win_ready[WIN_SERVICE] && !win_err[WIN_SERVICE];
  assign acc_io    = win_valid && win_we && (win_idx == WIN_IO[2:0])      && win_ready[WIN_IO]      && !win_err[WIN_IO];

  // ---- window 1 (OCC) service phase: accepts only when the phase reaches 2, so
  //      every OCC transaction is held for two extra cycles. ----
  logic [1:0] occ_phase_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      occ_phase_r <= 2'd0;
    end else if (win_valid && (win_idx == WIN_OCC[2:0])) begin
      occ_phase_r <= (occ_phase_r == 2'd2) ? 2'd0 : occ_phase_r + 2'd1;
    end
  end
  logic occ_ready_w;
  assign occ_ready_w = (occ_phase_r == 2'd2);

  // ---- per-window ready: all combinational-ready except the OCC phase stall ----
  assign win_ready[WIN_SHELL]   = 1'b1;
  assign win_ready[WIN_OCC]     = occ_ready_w;
  assign win_ready[WIN_R0]      = 1'b1;
  assign win_ready[WIN_R1]      = 1'b1;
  assign win_ready[WIN_SERVICE] = 1'b1;
  assign win_ready[WIN_IO]      = 1'b1;

  // ---- per-window error injection ----
  //   shell  : offset 0x0FFC is a reserved word (any access errors);
  //   service: read-only window (a write errors);
  //   io     : read-only window (a write errors).
  assign win_err[WIN_SHELL]   = (win_addr == 16'h0FFC);
  assign win_err[WIN_OCC]     = 1'b0;
  assign win_err[WIN_R0]      = 1'b0;
  assign win_err[WIN_R1]      = 1'b0;
  assign win_err[WIN_SERVICE] = win_we;
  assign win_err[WIN_IO]      = win_we;

  // ---- combinational read data per window (stable while the request is held) ----
  always_comb begin
    win_rdata = {(NUM_WINDOWS*32){1'b0}};
    case (win_idx)
      WIN_SHELL[2:0]:   win_rdata[32*WIN_SHELL   +: 32] = mem_shell[midx];
      WIN_OCC[2:0]:     win_rdata[32*WIN_OCC     +: 32] = mem_occ[midx];
      WIN_R0[2:0]:      win_rdata[32*WIN_R0      +: 32] = mem_r0[midx];
      WIN_R1[2:0]:      win_rdata[32*WIN_R1      +: 32] = mem_r1[midx];
      WIN_SERVICE[2:0]: win_rdata[32*WIN_SERVICE +: 32] = mem_svc[midx];
      WIN_IO[2:0]:      win_rdata[32*WIN_IO      +: 32] = mem_io[midx];
      default:          win_rdata = {(NUM_WINDOWS*32){1'b0}};
    endcase
  end

  // ---- synchronous commits + counters ----
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      commit_shell <= 0; commit_occ <= 0; commit_r0 <= 0;
      commit_r1 <= 0; commit_svc <= 0; commit_io <= 0;
    end else begin
      if (acc_shell) begin mem_shell[midx] <= win_wdata; commit_shell <= commit_shell + 1; end
      if (acc_occ)   begin mem_occ[midx]   <= win_wdata; commit_occ   <= commit_occ   + 1; end
      if (acc_r0)    begin mem_r0[midx]    <= win_wdata; commit_r0    <= commit_r0    + 1; end
      if (acc_r1)    begin mem_r1[midx]    <= win_wdata; commit_r1    <= commit_r1    + 1; end
      if (acc_svc)   begin mem_svc[midx]   <= win_wdata; commit_svc   <= commit_svc   + 1; end
      if (acc_io)    begin mem_io[midx]    <= win_wdata; commit_io    <= commit_io    + 1; end
    end
  end

  // ============================================================
  // BFM + checks
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

  // ---- deterministic xorshift32 (fixed seed; no $random) ----
  logic [31:0] lfsr_r;
  function automatic logic [31:0] xorshift(input logic [31:0] x);
    logic [31:0] y;
    begin
      y = x;
      y = y ^ (y << 13);
      y = y ^ (y >> 17);
      y = y ^ (y << 5);
      xorshift = y;
    end
  endfunction

  // ---- hold-until-ready bus transaction (the EBI-Tiny master contract) ----
  integer        wait_cycles;
  logic [2:0]    last_idx;
  logic          last_valid;
  logic [31:0]   last_wdata;
  task automatic bus_op(input logic [31:0] a, input logic wr, input logic [31:0] d,
                        output logic [31:0] rd, output logic er);
    begin
      @(negedge clk);
      req = 1'b1; we = wr; addr = a; wdata = d; wstrb = 4'hF;
      #1;                                   // combinational decode settles
      wait_cycles = 0;
      while (!ready) begin                  // hold the request until accepted
        if (wait_cycles > 100) begin
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
      rd         = rdata;
      er         = err;
      last_idx   = win_idx;
      last_valid = win_valid;
      last_wdata = win_wdata;
      @(negedge clk);
      req = 1'b0; we = 1'b0; wstrb = 4'h0;
      #1;
    end
  endtask

  // ---- TB expectation of err for an address (map + injected window errors) ----
  function automatic logic exp_err(input logic [31:0] a, input logic wr);
    logic [15:0] page;
    logic [15:0] off;
    begin
      page    = a[31:16];
      off     = a[15:0];
      exp_err = 1'b0;
      case (page)
        16'h0000: exp_err = (off[11:0] == 12'hFFC);   // shell reserved word
        16'h0001: exp_err = 1'b0;                     // occ
        16'h0010: exp_err = 1'b0;                     // region 0
        16'h0011: exp_err = 1'b0;                     // region 1
        16'h0020: exp_err = wr;                       // service: read-only
        16'h0030: exp_err = wr;                       // io: read-only
        default:  exp_err = 1'b1;                     // unmapped / no such region
      endcase
    end
  endfunction

  // ---- window base address (the ebi_pkg map; window index != page for regions) ----
  function automatic logic [31:0] win_base(input integer w);
    begin
      case (w)
        WIN_SHELL:   win_base = EBI_SHELL_CSR_BASE;
        WIN_OCC:     win_base = EBI_OCC_BASE;
        WIN_R0:      win_base = EBI_REGION_BASE;
        WIN_R1:      win_base = EBI_REGION_BASE + EBI_WINDOW_BYTES;
        WIN_SERVICE: win_base = EBI_SERVICE_BASE;
        WIN_IO:      win_base = EBI_IO_BASE;
        default:     win_base = 32'h0;
      endcase
    end
  endfunction

  // ---- TB expectation of the window index for a decoded address ----
  function automatic integer exp_win(input logic [31:0] a);
    logic [15:0] page;
    begin
      page = a[31:16];
      case (page)
        16'h0000: exp_win = WIN_SHELL;
        16'h0001: exp_win = WIN_OCC;
        16'h0010: exp_win = WIN_R0;
        16'h0011: exp_win = WIN_R1;
        16'h0020: exp_win = WIN_SERVICE;
        16'h0030: exp_win = WIN_IO;
        default:  exp_win = -1;
      endcase
    end
  endfunction

  // ---- model read over the window memories ----
  logic [31:0] model_rd;
  task automatic model_read(input integer w, input logic [7:0] ix, output logic [31:0] d);
    begin
      case (w)
        WIN_SHELL:   d = mem_shell[ix];
        WIN_OCC:     d = mem_occ[ix];
        WIN_R0:      d = mem_r0[ix];
        WIN_R1:      d = mem_r1[ix];
        WIN_SERVICE: d = mem_svc[ix];
        WIN_IO:      d = mem_io[ix];
        default:     d = 32'h0;
      endcase
    end
  endtask

  // ---- preload each window with a KEY-tagged pattern (window id in bits [23:20])
  logic [31:0] keys [0:NUM_WINDOWS-1];
  integer      pi, pj;
  task automatic preload;
    begin
      for (pi = 0; pi < MIB_WORDS; pi = pi + 1) begin
        for (pj = 0; pj < NUM_WINDOWS; pj = pj + 1) begin
          case (pj)
            WIN_SHELL:   mem_shell[pi] = KEY | (pj[31:0] << 20) | pi[31:0];
            WIN_OCC:     mem_occ[pi]   = KEY | (pj[31:0] << 20) | pi[31:0];
            WIN_R0:      mem_r0[pi]    = KEY | (pj[31:0] << 20) | pi[31:0];
            WIN_R1:      mem_r1[pi]    = KEY | (pj[31:0] << 20) | pi[31:0];
            WIN_SERVICE: mem_svc[pi]   = KEY | (pj[31:0] << 20) | pi[31:0];
            WIN_IO:      mem_io[pi]    = KEY | (pj[31:0] << 20) | pi[31:0];
            default: ;
          endcase
        end
      end
    end
  endtask

  // ============================================================
  // Test
  // ============================================================
  integer      i, w, ix;
  logic [31:0] op_addr, op_data, exp_rd, rd_w;
  logic        op_we, er_w;
  integer      seen_wait;
  integer      n_rd, n_wr;
  integer      hits [0:NUM_WINDOWS-1];
  integer      base_shell, base_occ, base_r0, base_r1;

  initial begin
    commit_shell = 0; commit_occ = 0; commit_r0 = 0;
    commit_r1 = 0; commit_svc = 0; commit_io = 0;
    bfm_w_shell = 0; bfm_w_occ = 0; bfm_w_r0 = 0;
    bfm_w_r1 = 0; bfm_w_svc = 0; bfm_w_io = 0;
    n_rd = 0; n_wr = 0;
    // Deterministic by default; +SEED=<hex> overrides the LFSR seed for replay or
    // extra exploration (the reported acceptance run uses the default seed).
    lfsr_r = 32'h1234_5678;
    void'($value$plusargs("SEED=%h", lfsr_r));
    if (lfsr_r == 32'h0) lfsr_r = 32'h1234_5678;  // xorshift32 fixed point: never all-zero

    preload();
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);

    // ============================================================
    // 1. Directed: per-window select + cross-window isolation
    // ============================================================
    $display("[ebi_tiny] 1. directed window decode + isolation");
    for (w = 0; w < NUM_WINDOWS; w = w + 1) begin
      op_addr = win_base(w) | 32'h0000_0100;
      op_data = 32'hDEAD_0000 | w[31:0];
      bus_op(op_addr, 1'b1, op_data, rd_w, er_w);
      chk(er_w == (w >= WIN_SERVICE), "directed write err expectation");
      if (er_w == 1'b0) begin
        chk(last_valid == 1'b1,               "write decoded: win_valid_o");
        chk(last_idx == w[2:0],               "write decoded: win_idx_o");
        chk(last_wdata == op_data,            "write decoded: wdata forwarded");
      end
    end
    // writable windows must read back their own word; read-only windows must still
    // hold the preloaded pattern (no write side effect at all)
    for (w = 0; w < NUM_WINDOWS; w = w + 1) begin
      op_addr = win_base(w) | 32'h0000_0100;
      model_read(w, 8'h40, exp_rd);            // offset 0x100 -> word 0x40
      bus_op(op_addr, 1'b0, 32'h0, rd_w, er_w);
      chk(er_w == 1'b0, "isolation read accepted");
      if (w < WIN_SERVICE) begin
        chk(rd_w == (32'hDEAD_0000 | w[31:0]), "writable window read-back");
      end else begin
        chk(rd_w == exp_rd, "read-only window pattern kept");
      end
    end

    // ============================================================
    // 2. Directed: address-map boundaries + unimplemented pages
    // ============================================================
    $display("[ebi_tiny] 2. map boundaries / unimplemented pages");
    bus_op(32'h0000_0FFC, 1'b1, 32'h1, rd_w, er_w);
    chk(er_w == 1'b1, "shell reserved word errors");
    bus_op(32'h0001_0000, 1'b1, 32'h2, rd_w, er_w);
    chk((er_w == 1'b0) && (last_idx == WIN_OCC[2:0]), "occ page first word: decoded");
    bus_op(32'h0001_0000, 1'b0, 32'h0, rd_w, er_w);
    chk(rd_w == 32'h2, "occ page first word stored");
    bus_op(32'h0012_0000, 1'b1, 32'h3, rd_w, er_w);
    chk(er_w == 1'b1, "no-such-region page is an error");
    bus_op(32'h0002_0000, 1'b1, 32'h4, rd_w, er_w); chk(er_w == 1'b1, "0x0002_0000 unmapped");
    bus_op(32'h000F_0000, 1'b1, 32'h4, rd_w, er_w); chk(er_w == 1'b1, "0x000F_0000 unmapped");
    bus_op(32'h0040_0000, 1'b1, 32'h4, rd_w, er_w); chk(er_w == 1'b1, "0x0040_0000 unmapped");
    bus_op(32'hFFFF_FFFF, 1'b1, 32'h4, rd_w, er_w); chk(er_w == 1'b1, "0xFFFF_FFFF unmapped");
    bus_op(32'h0011_FFFC, 1'b1, 32'h5, rd_w, er_w);
    chk((er_w == 1'b0) && (last_idx == WIN_R1[2:0]), "region 1 last word accepted");
    bus_op(32'h0020_0000, 1'b0, 32'h0, rd_w, er_w); chk(er_w == 1'b0, "service window readable");
    bus_op(32'h0030_0000, 1'b0, 32'h0, rd_w, er_w); chk(er_w == 1'b0, "io window readable");

    // ============================================================
    // 3. Directed: slave error propagation has no write side effect
    // ============================================================
    $display("[ebi_tiny] 3. slave error propagation");
    bus_op(32'h0000_0FFC, 1'b0, 32'h0, rd_w, er_w);
    chk(er_w == 1'b1, "shell slave error on read");
    bus_op(32'h0020_0100, 1'b1, 32'hBAD, rd_w, er_w);
    chk(er_w == 1'b1, "service window read-only");
    bus_op(32'h0030_0100, 1'b1, 32'hBAD, rd_w, er_w);
    chk(er_w == 1'b1, "io window read-only");
    model_read(WIN_SERVICE, 8'h40, exp_rd);
    bus_op(32'h0020_0100, 1'b0, 32'h0, rd_w, er_w);
    chk((er_w == 1'b0) && (rd_w == exp_rd), "errored write: no side effect");
    model_read(WIN_IO, 8'h40, exp_rd);
    bus_op(32'h0030_0100, 1'b0, 32'h0, rd_w, er_w);
    chk((er_w == 1'b0) && (rd_w == exp_rd), "errored io write: no effect");

    // ============================================================
    // 4. Directed: hold-until-ready on the stalling OCC window
    // ============================================================
    $display("[ebi_tiny] 4. hold-until-ready (OCC window accepts every 3rd cycle)");
    bus_op(32'h0001_0200, 1'b1, 32'hC0FFEE, rd_w, er_w);
    seen_wait = wait_cycles;
    chk(er_w == 1'b0, "stalled OCC write accepted");
    chk(seen_wait >= 2, "OCC write held >= 2 cycles");
    bus_op(32'h0001_0200, 1'b0, 32'h0, rd_w, er_w);
    chk(rd_w == 32'hC0FFEE, "OCC write committed once");
    chk(win_valid == 1'b0, "win_valid_o low when idle");

    // ============================================================
    // 5. BFM random read/write consistency sweep (10,000 ops)
    // ============================================================
    $display("[ebi_tiny] 5. BFM random sweep (%0d ops)", N_OPS);
    for (w = 0; w < NUM_WINDOWS; w = w + 1) hits[w] = 0;
    // accounting baseline: commit deltas over the sweep must equal BFM writes
    base_shell = commit_shell; base_occ = commit_occ;
    base_r0    = commit_r0;    base_r1  = commit_r1;
    bfm_w_shell = 0; bfm_w_occ = 0; bfm_w_r0 = 0; bfm_w_r1 = 0;

    for (i = 0; i < N_OPS; i = i + 1) begin
      lfsr_r = xorshift(lfsr_r);
      op_we  = lfsr_r[31];
      case (lfsr_r[10:8])
        3'd0:    op_addr = 32'h0000_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd1:    op_addr = 32'h0001_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd2:    op_addr = 32'h0010_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd3:    op_addr = 32'h0011_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd4:    op_addr = 32'h0020_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd5:    op_addr = 32'h0030_0000 | {20'h0, lfsr_r[11:2], 2'b00};
        3'd6:    op_addr = 32'h0002_0000 | {20'h0, lfsr_r[11:2], 2'b00};  // unmapped
        3'd7: begin                                                       // corner offsets
          case (lfsr_r[13:12])
            2'd0: op_addr = 32'h0000_0FFC;   // shell reserved word
            2'd1: op_addr = 32'h0012_0000;   // no such region
            2'd2: op_addr = 32'h0011_FFFC;   // last region word
            2'd3: op_addr = 32'hFFFF_FFFC;   // unmapped
          endcase
        end
      endcase
      lfsr_r  = xorshift(lfsr_r);
      op_data = lfsr_r;

      bus_op(op_addr, op_we, op_data, rd_w, er_w);

      // (a) error expectation
      chk(er_w == exp_err(op_addr, op_we), "random op err expectation");

      w  = exp_win(op_addr);
      ix = op_addr[9:2];
      if (w >= 0) hits[w] = hits[w] + 1;
      if (op_we) n_wr = n_wr + 1; else n_rd = n_rd + 1;

      if (!er_w) begin
        if (op_we) begin
          // (b) the model must now hold the written word
          case (w)
            WIN_SHELL: begin mem_shell[ix] = op_data; bfm_w_shell = bfm_w_shell + 1; end
            WIN_OCC:   begin mem_occ[ix]   = op_data; bfm_w_occ   = bfm_w_occ   + 1; end
            WIN_R0:    begin mem_r0[ix]    = op_data; bfm_w_r0    = bfm_w_r0    + 1; end
            WIN_R1:    begin mem_r1[ix]    = op_data; bfm_w_r1    = bfm_w_r1    + 1; end
            default: ;
          endcase
        end else begin
          // (c) a successful read returns exactly the model word
          case (w)
            WIN_SHELL:   exp_rd = mem_shell[ix];
            WIN_OCC:     exp_rd = mem_occ[ix];
            WIN_R0:      exp_rd = mem_r0[ix];
            WIN_R1:      exp_rd = mem_r1[ix];
            WIN_SERVICE: exp_rd = mem_svc[ix];
            WIN_IO:      exp_rd = mem_io[ix];
            default:     exp_rd = 32'h0;
          endcase
          chk(rd_w == exp_rd, "random read = model word");
        end
      end
    end

    // ============================================================
    // 6. Exactly-once accounting + sweep coverage
    // ============================================================
    $display("[ebi_tiny] 6. per-window commit accounting + coverage");
    $display("[ebi_tiny]    commits/bfm: shell=%0d/%0d occ=%0d/%0d r0=%0d/%0d r1=%0d/%0d svc=%0d io=%0d (read-only windows must stay 0)",
             commit_shell - base_shell, bfm_w_shell,
             commit_occ   - base_occ,   bfm_w_occ,
             commit_r0    - base_r0,    bfm_w_r0,
             commit_r1    - base_r1,    bfm_w_r1,
             commit_svc, commit_io);
    chk((commit_shell - base_shell) == bfm_w_shell, "shell commits == BFM writes");
    chk((commit_occ   - base_occ)   == bfm_w_occ,   "occ commits == BFM writes");
    chk((commit_r0    - base_r0)    == bfm_w_r0,    "region0 commits == BFM writes");
    chk((commit_r1    - base_r1)    == bfm_w_r1,    "region1 commits == BFM writes");
    chk((n_rd > 0) && (n_wr > 0), "sweep has reads and writes");
    for (w = 0; w < NUM_WINDOWS; w = w + 1)
      chk(hits[w] > 0, "sweep hit every window");

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: EBI-Tiny decode + BFM random consistency (%0d checks, %0d ops, rd=%0d wr=%0d)",
               checks, N_OPS, n_rd, n_wr);
    else
      $display("TEST FAILED: %0d error(s) in %0d checks", errors, checks);
    $finish;
  end

  // watchdog
  initial begin
    #50000000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
