`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_ctx_multiword (testbench, self-checking)
// Description: E2-FAB3b multi-word context round trip driven END-TO-END through
//              the EMRI v0.7 §3.9 register surface (CTX_CMD / CTX_WORDS /
//              CTX_STATUS @ 0x26-0x28), across `ctx_engine_wrap` (the real
//              ctx_scan engine + the PAUSED freeze) and a 2-word scan chain
//              (R=2, C=4 -> N = R*C*8 = 64 bits = 2 words).
//
//              Topology (the integration boundary the regfile keeps clean):
//                host register bus -> emri_regfile -> ctx_start_o/ctx_mode_o/
//                ctx_words_o -> ctx_engine_wrap -> fabric A scan chain
//                ctx_engine_wrap RAM port -> column_cfg_ram (context window)
//              fabric B is the uninterrupted reference twin (same image).
//
//              ALL 8 tiles x 8 eLUTs are configured (tt + IIB feedback ring), so
//              the whole 64-bit chain image is DEFINED (no x) and changes every
//              cycle — otherwise the x-propagation of unconfigured LUTs would
//              make the comparison vacuous.
//
//              Checks, in order:
//                1. pre-pause lockstep (A == B), x-free chain image;
//                2. save: CTX_CMD{start=1,mode=0} -> CTX_STATUS.busy high ->
//                   done latched; the SAVE writes the context window in
//                   DESCENDING word order (word1 then word0, ctx-scan §4) and
//                   both words are bit-exact against the fabric's captured vff
//                   chain image (word0 = elements 0..31, word1 = 32..63);
//                3. PAUSED freeze (emri-v0 §3.9 row 2): after the save completes
//                   the fabric-facing scan_en stays high for the whole PAUSED
//                   period, and once the chain has flushed the vff image is
//                   static over a 24-cycle window (the container cannot advance);
//                4. done latch + clear-on-CTX_CMD: the restore's CTX_CMD write
//                   clears done and the next read shows done=0/busy=1;
//                5. restore: CTX_CMD{start=1,mode=1}; element N-1 is word1's
//                   MSB, so the engine READS the window descending (word1 then
//                   word0, ctx-scan §4 "element N-1 first"); when it completes
//                   the freeze is released (scan_en low again);
//                6. resume: A's post-restore output sequence is bit-exact
//                   against B's uninterrupted sequence from the save point;
//                7. CTX_WORDS=0: a CTX_CMD start does NOT run the engine
//                   (no start pulse, no bus activity, CTX_STATUS stays 0) —
//                   the §3.9 rule-3 refusal/EFP_ERR=13 belongs to the daemon.
//
//              err_o is 0 in v0 (ctx_scan has no error output); the
//              register-surface err latch is covered by tb_emri_regfile.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3.9 (E2-FAB3b);
//              ethereal-spec/fabric/ctx-scan-v0.md §4/§6
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED" on success.
`timescale 1ns/1ps
module tb_ctx_multiword;
  import emri_pkg::*;

  localparam int R = 2, C = 4, W = 12, N = 8, K = 4, EXT_IN = 18;
  localparam int NTILES     = R * C;            // 8
  localparam int CHAIN_BITS = R * C * N;        // 64
  localparam int CHAIN_WORDS= CHAIN_BITS / 32;  // 2
  localparam int K1 = 12;                       // cycles before the pause
  localparam int K2 = 24;                       // post-resume comparison window
  localparam int TRACE_DEPTH = 4096;            // enough for the whole run

  // ---- clock / reset ----
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // ---- cfg bus (shared image to both fabrics) ----
  logic        cfg_we;
  logic [15:0] cfg_addr;
  logic [31:0] cfg_data;

  // ---- host register bus -> emri_regfile ----
  logic        host_req, host_we, host_ready;
  logic [1:0]  host_op;
  logic [15:0] host_addr;
  logic [31:0] host_wdata, host_rdata;

  // ---- fabrics A (DUT) / B (reference) ----
  logic [R*C*N-1:0]  obs_a, obs_b;
  logic [R*C*32-1:0] vd_a, vd_b;
  logic [R*C*48-1:0] vp_a, vp_b;
  logic scan_en, scan_in, scan_out_a, scan_out_b;

  // ---- regfile <-> wrapper command/status + context window ----
  logic        ctx_start, ctx_mode, ctx_busy, ctx_done, ctx_err;
  logic [15:0] ctx_words;
  logic        ram_we;
  logic [0:0]  ram_addr;
  logic [31:0] ram_wdata, ram_rdata;

  // ============================================================
  // DUT: emri_regfile (mFSM mode; OCC/decoder ports tied off — unused here)
  // ============================================================
  logic [1:0]  occ_cmd;
  logic        occ_cmd_valid;
  logic [15:0] occ_frame_addr, occ_word_count;
  logic [31:0] occ_wdata;
  logic        occ_wdata_valid;
  logic        dec_start;
  logic [7:0]  dec_col;

  emri_regfile #(
    .HAS_BMC(1'b0), .NUM_REGIONS(2), .PLATFORM_ID(32'h0)
  ) u_emri (
    .clk_i(clk), .rst_ni(rst_n),
    .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
    .host_addr_i(host_addr), .host_wdata_i(host_wdata),
    .host_rdata_o(host_rdata), .host_ready_o(host_ready),
    .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid),
    .occ_cmd_ready_i(1'b0),
    .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
    .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
    .occ_wdata_ready_i(1'b0),
    .occ_status_i(OCC_S_IDLE), .occ_crc_error_i(1'b0),
    .occ_region_locked_o(),
    .occ_expect_crc_o(), .occ_crc_result_i(32'h0),
    .dec_start_o(dec_start), .dec_col_o(dec_col), .dec_busy_i(1'b0),
    // v0.7 §3.9 engine command/status (engine + freeze live in the wrapper)
    .ctx_start_o(ctx_start), .ctx_mode_o(ctx_mode), .ctx_words_o(ctx_words),
    .ctx_busy_i(ctx_busy), .ctx_done_i(ctx_done), .ctx_err_i(ctx_err)
  );

  // ============================================================
  // Fabrics: A is the context DUT, B the uninterrupted reference twin
  // ============================================================
  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fab_a (
    .clk_i(clk), .rst_ni(rst_n),
    .cfg_we_i(cfg_we), .cfg_addr_i(cfg_addr), .cfg_data_i(cfg_data),
    .clb_out_obs_o(obs_a), .mem_vd_obs_o(vd_a), .dsp_vp_obs_o(vp_a),
    .scan_en_i(scan_en), .scan_in_i(scan_in), .scan_out_o(scan_out_a)
  );

  fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fab_b (
    .clk_i(clk), .rst_ni(rst_n),
    .cfg_we_i(cfg_we), .cfg_addr_i(cfg_addr), .cfg_data_i(cfg_data),
    .clb_out_obs_o(obs_b), .mem_vd_obs_o(vd_b), .dsp_vp_obs_o(vp_b),
    .scan_en_i(1'b0), .scan_in_i(1'b0), .scan_out_o(scan_out_b)
  );

  // ---- context engine wrapper (integration level) + window ----
  ctx_engine_wrap #(.AW(1)) u_ctxeng (
    .clk_i(clk), .rst_ni(rst_n),
    .start_i(ctx_start), .mode_i(ctx_mode), .words_i(ctx_words),
    .busy_o(ctx_busy), .done_o(ctx_done), .err_o(ctx_err),
    .scan_en_o(scan_en), .scan_in_o(scan_in), .scan_out_i(scan_out_a),
    .ram_we_o(ram_we), .ram_addr_o(ram_addr),
    .ram_wdata_o(ram_wdata), .ram_rdata_i(ram_rdata)
  );

  column_cfg_ram #(.ADDR_W(1), .DATA_W(32), .DEPTH(2)) u_ctxram (
    .clk(clk), .we(ram_we), .re(1'b0),
    .addr(ram_addr), .wdata(ram_wdata), .rdata(ram_rdata)
  );

  // ============================================================
  // Chain-image probe: reconstruct element e = tile_rm*N + gi from each tile's
  // eLUT vff (ctx-scan-v0.md §2 chain order), so the saved words can be
  // compared bit-exactly.
  // ============================================================
  logic [CHAIN_BITS-1:0] snap_a;
  genvar gsr, gsc, gsg;
  generate
    for (gsr = 0; gsr < R; gsr = gsr + 1) begin : g_snap_r
      for (gsc = 0; gsc < C; gsc = gsc + 1) begin : g_snap_c
        for (gsg = 0; gsg < N; gsg = gsg + 1) begin : g_snap_g
          assign snap_a[((gsr*C + gsc)*N) + gsg] =
            u_fab_a.g_row[gsr].g_col[gsc].u_clb.gen_lut[gsg].u_elut.vff_r;
        end
      end
    end
  endgenerate

  // ============================================================
  // Traces / monitors (post-edge TB sampling, blocking style)
  // ============================================================
  logic [CHAIN_BITS-1:0] a_tr [0:TRACE_DEPTH-1];
  logic [CHAIN_BITS-1:0] b_tr [0:TRACE_DEPTH-1];
  logic [CHAIN_BITS-1:0] snap_tr [0:TRACE_DEPTH-1];
  integer cyc = 0;
  always @(posedge clk) begin
    #1;                                   // post-edge sample of state after this edge
    a_tr[cyc]    = obs_a;
    b_tr[cyc]    = obs_b;
    snap_tr[cyc] = snap_a;
    cyc = cyc + 1;
  end

  // save: log the context-window write order (must be descending word address)
  logic        save_phase = 1'b0;
  logic [0:0]  save_addr_log [0:7];
  logic [31:0] save_data_log [0:7];
  integer      save_writes = 0;
  always @(posedge clk) begin
    if (save_phase && ram_we) begin
      save_addr_log[save_writes] = ram_addr;
      save_data_log[save_writes] = ram_wdata;
      save_writes = save_writes + 1;
    end
  end

  // restore: log when each window word is first read (must be ascending)
  logic   restore_phase = 1'b0;
  integer first_addr0_cyc = -1;
  integer first_addr1_cyc = -1;
  always @(posedge clk) begin
    if (restore_phase) begin
      if ((ram_addr == 1'b1) && (first_addr1_cyc < 0)) first_addr1_cyc = cyc;
      if ((ram_addr == 1'b0) && (first_addr0_cyc < 0)) first_addr0_cyc = cyc;
    end
  end

  // PAUSED window: scan_en must stay high the whole time (freeze)
  logic   paused_phase = 1'b0;
  integer freeze_violations = 0;
  always @(posedge clk) begin
    if (paused_phase && (scan_en !== 1'b1)) freeze_violations = freeze_violations + 1;
  end

  // PAUSED window (after the flush): the vff image must never change again.
  // Counting CHANGES (not a two-sample compare) keeps the check meaningful for
  // images whose free-running dynamics is periodic.
  logic                     fwin = 1'b0;
  integer                   frozen_changes = 0;
  logic [CHAIN_BITS-1:0]    fwin_prev;
  always @(posedge clk) begin
    if (!fwin) begin
      frozen_changes = 0;
    end else if (snap_a !== fwin_prev) begin
      frozen_changes = frozen_changes + 1;
    end
    fwin_prev = snap_a;
  end

  // engine start-pulse counter (the CTX_WORDS=0 no-start proof)
  integer ctx_start_pulses = 0;
  always @(posedge clk) if (ctx_start) ctx_start_pulses = ctx_start_pulses + 1;

  // restore completion edge (sticky done is seen later; this pins m_last)
  integer restore_done_cyc = -1;
  always @(negedge clk) if (restore_phase && ctx_done) restore_done_cyc = cyc;

  // ============================================================
  // Checks
  // ============================================================
  integer errors = 0;
  task automatic chk(input cond, input [255:0] msg);
    begin
      if (!cond) begin errors = errors + 1; $display("  FAIL: %0s", msg); end
    end
  endtask

  // ============================================================
  // Host driver tasks
  // ============================================================
  task automatic cfg_write(input logic [15:0] a, input logic [31:0] d);
    begin
      @(negedge clk);
      cfg_we = 1'b1; cfg_addr = a; cfg_data = d;
      @(negedge clk);
      cfg_we = 1'b0;
    end
  endtask

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

  // Poll CTX_STATUS until done latches (sticky), bounded.
  task automatic wait_ctx_done(output logic [31:0] st);
    integer i;
    begin
      st = 32'h0;
      i = 0;
      while (!st[CTX_STATUS_DONE] && i < 400) begin
        host_read(R_CTX_STATUS, st);
        i = i + 1;
      end
      if (i >= 400) begin
        errors = errors + 1;
        $display("  FAIL: timeout waiting for CTX_STATUS.done");
      end
    end
  endtask

  logic [31:0] rd;
  integer      n_save, m_last, k;

  // ============================================================
  // Test sequence
  // ============================================================
  initial begin
    cfg_we   = 1'b0; cfg_addr = 16'h0; cfg_data = 32'h0;
    host_req = 1'b0; host_we  = 1'b0;  host_op = SPI_OP_RD;
    host_addr= 16'h0; host_wdata = 32'h0;
    // context window: known-zero (the real SSRAM is uninitialised; a defined
    // window keeps the save's scan_in and the RAM content checks deterministic)
    for (int w = 0; w < 2; w = w + 1) u_ctxram.mem[w] = 32'h0;

    // ---- image: configure EVERY tile/eLUT so the whole chain is defined and
    //      time-varying. Each eLUT captures a tile-rotated ring neighbour
    //      (feedback j = (gi+1+t) % N), alternating invert (0x5555) / buffer
    //      (0xAAAA), with a per-element reset value; tiles therefore hold
    //      different, moving 8-bit patterns. ----
    for (int t = 0; t < NTILES; t = t + 1) begin
      for (int gi = 0; gi < N; gi = gi + 1) begin
        logic [15:0] tt;
        logic        rv;
        // Polarity/reset depend on t>>2 so tiles t and t+4 differ: element e
        // maps to element e+32 across those tiles, and a periodic image would
        // survive a wrong word order unnoticed.
        tt = (((gi ^ (t >> 2)) & 1) == 0) ? 16'h5555 : 16'hAAAA;
        rv = ((((t >> 2) + gi) & 1) != 0);
        // eLUT cfg: {tt[15:0], ff_en=1, ff_rst_en=1, ff_rst_val, out_inv=0}
        cfg_write((16'(t) << 8) | 16'(gi), {tt, 1'b1, 1'b1, rv, 1'b0});
        // IIB cfg: all K inputs -> feedback j = (gi + 1 + t) % N (sel[4]=0)
        for (int gk = 0; gk < K; gk = gk + 1) begin
          cfg_write((16'(t) << 8) | 16'(8 + gi*K + gk),
                    32'((gi + 1 + t) % N));
        end
      end
    end

    // ---- reset ----
    @(negedge clk); rst_n = 1'b0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    // ---- 0. CTX register reset values ----
    host_read(R_CTX_CMD, rd);     chk(rd == 32'h0, "CTX_CMD reads 0");
    host_read(R_CTX_WORDS, rd);   chk(rd == 32'h0, "CTX_WORDS reset 0");
    host_read(R_CTX_STATUS, rd);  chk(rd == 32'h0, "CTX_STATUS reset 0");
    chk(CHAIN_WORDS == 2, "2x4 fabric chain is 2 words");

    // ---- phase 1: run K1 cycles, both fabrics toggling in lockstep ----
    repeat (K1) @(posedge clk);
    for (k = 1; k <= K1-1; k = k + 1) begin
      if (a_tr[k] !== b_tr[k]) errors = errors + 1;
    end
    if (errors == 0) $display("  ok: pre-pause lockstep (A==B for %0d cycles)", K1-1);
    chk(a_tr[K1-1] !== {CHAIN_BITS{1'bx}}, "chain image is x-free");

    // ---- phase 2: SAVE through the EMRI registers ----
    host_write(R_CTX_WORDS, 32'(CHAIN_WORDS));
    host_read(R_CTX_WORDS, rd);   chk(rd == 32'(CHAIN_WORDS), "CTX_WORDS RW = 2");

    // CTX_CMD is registered into ctx_start_o, so ctx_scan accepts the command
    // one posedge after the write is accepted: the engine's freeze point (the
    // chain image it saves) is the state after that next edge.
    @(negedge clk);
    n_save    = cyc + 1;
    save_phase = 1'b1;
    host_req=1'b1; host_we=1'b1; host_op=SPI_OP_WR;
    host_addr=R_CTX_CMD; host_wdata={30'h0, 1'b0, 1'b1};  // {mode=0, start=1}
    @(posedge clk);                       // accepted: ctx_start_o pulses
    @(negedge clk); host_req=1'b0;

    host_read(R_CTX_STATUS, rd);
    chk(rd[CTX_STATUS_BUSY] == 1'b1 && rd[CTX_STATUS_DONE] == 1'b0,
        "save: busy=1 while shifting");
    wait_ctx_done(rd);
    chk(rd[CTX_STATUS_DONE] == 1'b1 && rd[CTX_STATUS_BUSY] == 1'b0,
        "save: done latched, busy low");
    save_phase = 1'b0;

    // save window content: bit-exact against the frozen chain image
    $display("  [ctx] save writes: %0d, addr order %0d -> %0d, data %h %h",
             save_writes, save_addr_log[0], save_addr_log[1],
             save_data_log[0], save_data_log[1]);
    chk(save_writes == 2, "save wrote exactly 2 words");
    chk(save_addr_log[0] == 1'b1 && save_addr_log[1] == 1'b0,
        "save addr order is 1 then 0");
    chk(u_ctxram.mem[0] === snap_tr[n_save][31:0], "saved word0 == image[31:0]");
    chk(u_ctxram.mem[1] === snap_tr[n_save][63:32], "saved word1 == image[63:32]");
    if ((u_ctxram.mem[0] === snap_tr[n_save][31:0]) &&
        (u_ctxram.mem[1] === snap_tr[n_save][63:32]))
      $display("  ok: 2-word context window is bit-exact (%h %h)",
               u_ctxram.mem[1], u_ctxram.mem[0]);

    // ---- phase 3: PAUSED freeze (emri-v0 §3.9 row 2) ----
    // The wrapper holds scan_en high from save-done to restore-done. Let the
    // static scan_in flush the chain (N shifts), then the vff image must be
    // static over a 24-cycle window: the container cannot advance.
    paused_phase = 1'b1;
    repeat (CHAIN_BITS + 8) @(negedge clk);   // static scan_in flushes the chain
    fwin = 1'b1;
    repeat (24) @(negedge clk);
    fwin = 1'b0;
    chk(scan_en === 1'b1, "PAUSED: scan_en held high");
    chk(frozen_changes == 0, "PAUSED: FFs never change");
    $display("  ok: PAUSED freeze held (scan_en=1, 0 FF changes in %0d cycles; image %h)",
             24, snap_a);

    // ---- phase 4: RESTORE through the EMRI registers ----
    // PAUSED ends when the restore is commanded; the release itself is checked
    // after the completion (the wrapper drops scan_en at the restore's done).
    chk(scan_en === 1'b1, "freeze still held at the restore command");
    paused_phase  = 1'b0;
    restore_phase = 1'b1;
    // a CTX_CMD write clears done; the restore command must also show busy
    @(negedge clk);
    host_req=1'b1; host_we=1'b1; host_op=SPI_OP_WR;
    host_addr=R_CTX_CMD; host_wdata={30'h0, 1'b1, 1'b1};  // {mode=1, start=1}
    @(posedge clk);
    @(negedge clk); host_req=1'b0;
    host_read(R_CTX_STATUS, rd);
    chk(rd[CTX_STATUS_DONE] == 1'b0 && rd[CTX_STATUS_BUSY] == 1'b1,
        "CTX_CMD clears done; busy=1");
    wait_ctx_done(rd);
    chk(rd[CTX_STATUS_DONE] == 1'b1, "restore: done latched");
    restore_phase = 1'b0;
    paused_phase  = 1'b0;
    chk(first_addr1_cyc >= 0 && first_addr0_cyc > first_addr1_cyc,
        "restore reads words 1 then 0");
    $display("  [ctx] restore first reads: word1 @%0d, word0 @%0d",
             first_addr1_cyc, first_addr0_cyc);
    repeat (2) @(negedge clk);
    chk(scan_en === 1'b0, "restore done releases the freeze");
    chk(freeze_violations == 0, "scan_en high for all of PAUSED");

    // ctx_scan.sv: done_r registers one edge after the last shift; the TB
    // observed it at this negedge, so the last shift was at (cyc - 2).
    m_last = restore_done_cyc - 2;
    chk(restore_done_cyc >= 0, "restore done observed");

    // ---- phase 5: resume; A must replay B's sequence from the save point ----
    for (k = 1; k <= K2; k = k + 1) begin
      @(negedge clk);
      if (a_tr[m_last + k] !== b_tr[n_save + k]) begin
        errors = errors + 1;
        $display("  FAIL: resume k=%0d: A=%h B(ref@n+k)=%h", k,
                 a_tr[m_last + k], b_tr[n_save + k]);
      end
    end
    if (errors == 0)
      $display("  ok: post-restore sequence equals the reference (%0d cycles, %0d bits)",
               K2, CHAIN_BITS);

    // ---- phase 6: CTX_WORDS=0 must NOT start the engine ----
    host_write(R_CTX_WORDS, 32'h0);
    host_read(R_CTX_WORDS, rd);  chk(rd == 32'h0, "CTX_WORDS back to 0");
    begin
      integer pulses_before;
      integer writes_before;
      pulses_before = ctx_start_pulses;
      writes_before = save_writes;
      @(negedge clk);
      host_req=1'b1; host_we=1'b1; host_op=SPI_OP_WR;
      host_addr=R_CTX_CMD; host_wdata=32'h0000_0001;  // start=1, mode=0, words=0
      @(posedge clk);
      @(negedge clk); host_req=1'b0;
      // let any (buggy) pulse/bus write show up
      repeat (4) @(posedge clk);
      chk(ctx_start_pulses == pulses_before, "CTX_WORDS=0: no start pulse");
      chk(save_writes == writes_before, "CTX_WORDS=0: no RAM bus activity");
      host_read(R_CTX_STATUS, rd);
      chk(rd == 32'h0, "CTX_WORDS=0: CTX_STATUS stays 0");
    end

    // ---- report ----
    if (errors == 0)
      $display("TEST PASSED: ctx multiword save/restore via EMRI CTX_* (2-word chain, bit-exact)");
    else
      $display("TEST FAILED: %0d errors", errors);
    $finish;
  end

  // global watchdog
  initial begin
    #200000;
    $display("TEST FAILED: global watchdog timeout");
    $finish;
  end
endmodule
`default_nettype wire
