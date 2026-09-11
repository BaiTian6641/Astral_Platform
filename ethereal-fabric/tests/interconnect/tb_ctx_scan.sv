`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_ctx_scan (testbench, self-checking)
// Description: E2-FAB3 context save/restore capstone — container pause / resume
//              equivalence (ctx-scan-v0.md §6, S02 acceptance: 暂停→恢复后输出
//              序列与不间断运行一致).
//
//              Two identical fabrics run in lockstep:
//                * A (DUT) is PAUSED, SAVED to the context window, then RESTORED;
//                * B keeps running uninterrupted as the reference.
//              After A's restore completes (last shift posedge m), A's FF state
//              must equal A's state at the save point (posedge n), so
//                A_obs[m+k] == B_obs[n+k]  for k = 1..K2
//              (both fabrics sample clb_out_obs post-edge). The image is a
//              self-toggling TFF on tile(0,0) eLUT0 -> obs[0] toggles every
//              cycle: any phase error flips the comparison.
//
//              Engine timing (ctx_scan.sv): start seen at posedge n -> SHIFT;
//              samples scan_out pre-edge at posedges n+1..n+32 (element N-1
//              first, element 0 last); done_r registers one posedge after the
//              last shift (bit counter hits words*32-1) -> the TB observes
//              ctx_done at the negedge with cyc = m+2.
// Maintainer:  BaiTian6641
// Created:     2026-09-11
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/fabric/ctx-scan-v0.md §4/§6 (E2-FAB3);
//              ethereal-plan/components/C03-OCC组件.md §7
`timescale 1ns/1ps

module tb_ctx_scan;
    localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18;
    localparam int CHAIN_BITS  = R * C * N;      // 32
    localparam int CHAIN_WORDS = CHAIN_BITS / 32; // 1
    localparam int K1 = 12;                      // cycles before the pause
    localparam int K2 = 24;                      // post-resume comparison window

    // ---- clock / reset ----
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    // ---- cfg bus (shared: both fabrics get the same image) ----
    logic        cfg_we;
    logic [15:0] cfg_addr;
    logic [31:0] cfg_data;

    task automatic cfg_write(input logic [15:0] a, input logic [31:0] d);
        begin
            @(negedge clk);
            cfg_we = 1'b1; cfg_addr = a; cfg_data = d;
            @(negedge clk);
            cfg_we = 1'b0;
        end
    endtask

    // ---- fabric A (DUT) / B (reference) ----
    logic [R*C*N-1:0]  obs_a, obs_b;
    logic [R*C*32-1:0] vd_a, vd_b;
    logic [R*C*48-1:0] vp_a, vp_b;

    logic scan_en, scan_in, scan_out_a, scan_out_b;

    fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fab_a (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .cfg_we_i     (cfg_we),
        .cfg_addr_i   (cfg_addr),
        .cfg_data_i   (cfg_data),
        .clb_out_obs_o(obs_a),
        .mem_vd_obs_o (vd_a),
        .dsp_vp_obs_o (vp_a),
        .scan_en_i    (scan_en),
        .scan_in_i    (scan_in),
        .scan_out_o   (scan_out_a)
    );

    fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) u_fab_b (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .cfg_we_i     (cfg_we),
        .cfg_addr_i   (cfg_addr),
        .cfg_data_i   (cfg_data),
        .clb_out_obs_o(obs_b),
        .mem_vd_obs_o (vd_b),
        .dsp_vp_obs_o (vp_b),
        .scan_en_i    (1'b0),        // reference: uninterrupted
        .scan_in_i    (1'b0),
        .scan_out_o   (scan_out_b)
    );

    // ---- context engine + window (SSM-T stand-in) ----
    logic        ctx_start, ctx_mode, ctx_busy, ctx_done;
    logic [15:0] ctx_words;
    logic        ram_we;
    logic [0:0]  ram_addr;
    logic [31:0] ram_wdata, ram_rdata;

    ctx_scan #(.AW(1)) u_ctx (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .start_i      (ctx_start),
        .mode_i       (ctx_mode),
        .words_i      (ctx_words),
        .busy_o       (ctx_busy),
        .done_o       (ctx_done),
        .scan_en_o    (scan_en),
        .scan_in_o    (scan_in),
        .scan_out_i   (scan_out_a),
        .ram_we_o     (ram_we),
        .ram_addr_o   (ram_addr),
        .ram_wdata_o  (ram_wdata),
        .ram_rdata_i  (ram_rdata)
    );

    column_cfg_ram #(.ADDR_W(1), .DATA_W(32), .DEPTH(1)) u_ctxram (
        .clk   (clk),
        .we    (ram_we),
        .re    (1'b0),
        .addr  (ram_addr),
        .wdata (ram_wdata),
        .rdata (ram_rdata)
    );

    // ---- traces (post-edge samples, blocking TB style) ----
    logic   a_tr [0:255];
    logic   b_tr [0:255];
    integer cyc = 0;
    always @(posedge clk) begin
        #1;                       // post-edge: a_tr[k] = fabric state after posedge #k
        a_tr[cyc] = obs_a[0];
        b_tr[cyc] = obs_b[0];
        cyc = cyc + 1;
    end
    // Diagnostic: the engine's context-window writes (one word per save).
    always @(posedge clk) begin
        if (ram_we) $display("  [ctx] write addr=%0d data=%h (t=%0t)", ram_addr, ram_wdata, $time);
        if (ctx_done) $display("  [ctx] done (t=%0t)", $time);
    end
    integer errors = 0;
    integer n_save, m_last, k;

    initial begin
        cfg_we = 1'b0; cfg_addr = 16'h0; cfg_data = 32'h0;
        ctx_start = 1'b0; ctx_mode = 1'b0; ctx_words = 16'(CHAIN_WORDS);

        // ---- image: self-toggling TFF on tile(0,0) eLUT0 (tb_hotswap pattern) ----
        cfg_write(16'h0000, 32'h0005555C);   // tt=0x5555, ff_en, ff_rst_en, rst_val=0
        cfg_write(16'h0008, 32'h00000000);   // IIB mux0 = fb j0 (self-contained)
        cfg_write(16'h0009, 32'h00000000);
        cfg_write(16'h000A, 32'h00000000);
        cfg_write(16'h000B, 32'h00000000);

        // ---- reset ----
        @(negedge clk); rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // ---- phase 1: run K1 cycles, both fabrics toggling in lockstep ----
        repeat (K1) @(posedge clk);
        for (k = 1; k <= K1; k = k + 1) begin
            if (a_tr[k] !== b_tr[k]) errors = errors + 1;
        end
        if (errors == 0) $display("  ok: pre-pause lockstep (A==B for %0d cycles)", K1);

        // ---- phase 2: pause + save (A only) ----
        @(negedge clk);
        n_save = cyc;                 // the next posedge's post-edge state is saved
        ctx_mode = 1'b0; ctx_words = 16'(CHAIN_WORDS); ctx_start = 1'b1;
        @(negedge clk); ctx_start = 1'b0;
        // wait for done
        while (!ctx_done) @(negedge clk);
        if (u_ctxram.mem[0][0] !== a_tr[n_save]) begin
            errors = errors + 1;
            $display("  FAIL: saved element0=%b, expected A state %b",
                     u_ctxram.mem[0][0], a_tr[n_save]);
        end else begin
            $display("  ok: context window word0[0] = saved A state (%b)", u_ctxram.mem[0][0]);
        end

        // ---- phase 3: restore (A) ----
        @(negedge clk);
        ctx_mode = 1'b1; ctx_words = 16'(CHAIN_WORDS); ctx_start = 1'b1;
        @(negedge clk); ctx_start = 1'b0;
        while (!ctx_done) @(negedge clk);
        // ctx_done observed at the negedge right after the posedge that set it:
        // the last restore shift was at posedge (cyc - 2).
        m_last = cyc - 2;

        // ---- phase 4: resume; A must replay B's sequence from the save point ----
        for (k = 1; k <= K2; k = k + 1) begin
            @(negedge clk);
            if (a_tr[m_last + k] !== b_tr[n_save + k]) begin
                errors = errors + 1;
                $display("  FAIL: resume k=%0d: A=%b B(ref@n+k)=%b",
                         k, a_tr[m_last + k], b_tr[n_save + k]);
            end
        end
        if (errors == 0)
            $display("  ok: post-resume sequence equals the uninterrupted reference (%0d cycles)", K2);

        if (errors == 0)
            $display("TEST PASSED: ctx_scan pause/save/restore resumes bit-exactly (E2-FAB3, ctx-scan-v0 §6)");
        else
            $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
