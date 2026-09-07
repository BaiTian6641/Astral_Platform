`timescale 1ns/1ps
`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_connection_block
// Description: Self-checking SystemVerilog testbench for connection_block
//              (interconnect v2c, FROZEN spec §7.1: W=12, N_CB=18, CB_DIV=2).
// Details:     Exercises the v2c stratified-depopulated input CB mux network:
//                cfg_addr = clb_in index   (0..N_CB-1, masked to $clog2(N_CB) bits)
//                cfg_data = subset index k (0..4*W/CB_DIV-1 = 0..23, 5 bits)
//                clb_in_o[i] = pool[(i % CB_DIV) + CB_DIV*k]
//              where pool = {out_w, out_e, out_s, out_n} so:
//                pool[0..11]=out_n, [12..23]=out_s, [24..35]=out_e, [36..47]=out_w.
//              At W=12/CB_DIV=2 the subset is a PARITY CLASS: clb_in[i] can read
//              out_d[t] iff t%2 == i%2 (6 tracks/dir x 4 dirs = 24, Fc=0.5).
//              Covers:
//                (0) zero-init + blank default: k=0 reads out_n[i%2] (§7.1);
//                (1) directed per-direction reachability + negatives (parity);
//                (2) parity-class proof: an opposite-parity track is UNREACHABLE
//                    for every legal k (k sweep with only that track driven);
//                (3) full exhaust: all 18 inputs x all 24 legal k x 2 pool
//                    patterns, checked against the §7.1 index formula;
//                (4) isolation sweep (one input programmed, all others k=0);
//                (5) reserved k=24..31 note: k=24 reads pool[>=48] -> X in
//                    simulation (undefined, MUST NOT be programmed, §7.1).
//              Run: iverilog -g2012 -o /tmp/tb_cb connection_block.sv tb_connection_block.sv && vvp /tmp/tb_cb
// Maintainer:  BaiTian6641
// Created:     2026-07-25
// Modified:    2026-09-02 - v2c (E2-FAB5, spec §7.1): 6-bit absolute track ->
//                            5-bit subset index k; parity-class checks + exhaust.
// Tags:        RTL TESTBENCH
// Plan-Ref:    ethereal-spec/fabric/interconnect-config-v0.md §7.1 (v2c FROZEN)
// Notes:       sel_r has NO reset (OCC configures before run, C03) -> at sim
//              start it is X -> X-propagates through the mux -> corrupts checks.
//              The TB ZERO-INITs all 18 sel_r (cfg addr 0..N_CB-1, data=0) in a
//              reset/config phase before checks (mirrors tb_switch_box.sv's
//              zero-init lesson). v2c blank default: k=0 reads out_n[i%2]
//              (was out_n[0] in v1.1) — a real track, NOT a disconnect.
module tb_connection_block;
    localparam int W      = 12;
    localparam int N_CB   = 18;     // number of CLB inputs (EXT_IN)
    localparam int CB_DIV = 2;      // v2c depopulation divisor (§7.1)
    localparam int POOL   = 4*W;    // 48 tracks
    localparam int NSUB   = POOL/CB_DIV;  // 24 tracks visible per input

    logic                       clk;
    logic                       cfg_we;
    logic [$clog2(N_CB)-1:0]    cfg_addr;   // 5 bits for N_CB=18
    logic [$clog2(NSUB)-1:0]    cfg_data;   // 5 bits for NSUB=24 (v2c §7.1)
    logic [W-1:0]               out_n, out_s, out_e, out_w;
    logic [N_CB-1:0]            clb_in_o;

    int errors = 0;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT (v2c defaults: CB_DIV=2) ----
    connection_block #(.W(W), .N_CB(N_CB), .CB_DIV(CB_DIV)) dut (
        .clk_i      (clk),
        .cfg_we_i   (cfg_we),
        .cfg_addr_i (cfg_addr),
        .cfg_data_i (cfg_data),
        .out_n      (out_n),
        .out_s      (out_s),
        .out_e      (out_e),
        .out_w      (out_w),
        .clb_in_o   (clb_in_o)
    );

    // ---- defaults ----
    initial begin
        cfg_we   = 1'b0;
        cfg_addr = '0;
        cfg_data = '0;
        out_n = '0;  out_s = '0;  out_e = '0;  out_w = '0;
    end

    // ---- config write: pulse cfg_we_i=1 for one clock ----
    //   a in 0..N_CB-1  -> which clb_in
    //   d in 0..NSUB-1  -> subset index k (§7.1)
    task cfg_write(input int a, input int d);
        begin
            @(negedge clk);
            cfg_addr = a[$clog2(N_CB)-1:0];   // truncates to addr width
            cfg_data = d[$clog2(NSUB)-1:0];   // truncates to data width
            cfg_we   = 1'b1;
            @(negedge clk);
            cfg_we   = 1'b0;
        end
    endtask

    // ---- deterministic pool test pattern (any fixed per-bit function; the
    //      exhaust compares the DUT against the same function of the §7.1 index).
    //      Mixed so adjacent same-parity pool bits differ often. ----
    function automatic logic pool_bit(input int p);
        return (((p*37 + 11) >> 3) ^ (p >> 1) ^ p) & 1;
    endfunction

    // drive the 4 dir bundles so that pool[p] = pool_bit(p) ^ pol
    task drive_pool(input logic pol);
        int t;
        begin
            for (t = 0; t < W; t = t + 1) begin
                out_n[t] = pool_bit(t)       ^ pol;
                out_s[t] = pool_bit(W + t)   ^ pol;
                out_e[t] = pool_bit(2*W + t) ^ pol;
                out_w[t] = pool_bit(3*W + t) ^ pol;
            end
        end
    endtask

    // ---- check helpers (no string type -> iverilog-safe) ----
    task expect_one(input int idx, input logic got);
        begin
            if (got !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: clb_in[%0d] expected 1 got=%b", idx, got);
            end
        end
    endtask

    task expect_zero(input int idx, input logic got);
        begin
            if (got !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: clb_in[%0d] expected 0 got=%b", idx, got);
            end
        end
    endtask

    task expect_bit(input int idx, input logic exp, input logic got);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL: clb_in[%0d] expected %b got=%b", idx, exp, got);
            end
        end
    endtask

    int i, k, pol;

    initial begin
        // =========================================================
        // ZERO-INIT: write k=0 for ALL 18 clb_ins. sel_r has no reset,
        // so without this it X-propagates through the mux and corrupts every
        // check. (Mirrors tb_switch_box.sv's zero-init lesson, C03
        // config-before-run.)
        // =========================================================
        for (i = 0; i < N_CB; i = i + 1) begin
            cfg_write(i, 0);
        end

        // =========================================================
        // (0) blank default (§7.1): k=0 -> clb_in[i] reads out_n[i%2]
        //     (a real track, NOT a disconnect). out_n = 12'hAAA reads
        //     bit0=0,bit1=1 alternating.
        // =========================================================
        out_n = 12'hAAA; out_s = '0; out_e = '0; out_w = '0;
        #1;
        for (i = 0; i < N_CB; i = i + 1) begin
            expect_bit(i, 1'b0 ^ (i % 2), clb_in_o[i]);  // out_n[0]=0, out_n[1]=1
        end

        // =========================================================
        // (1a) clb_in[0] (even) k=0 -> out_n[0]
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(0, 0);                   // k=0 -> pool[0] = out_n[0]
        out_n[0] = 1'b1;
        #1;
        expect_one(0, clb_in_o[0]);
        // negative: drive out_n[2] (same parity, DIFFERENT k) -> stays 0
        out_n = 1'b1 << 2;
        #1;
        expect_zero(0, clb_in_o[0]);

        // =========================================================
        // (1b) clb_in[3] (odd) k=12 -> pool[1+24]=pool[25] = out_e[1]
        //      (v1.1 check used out_e[0]; v2c: odd input reaches only odd t)
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(3, 12);                  // pool[(3%2)+2*12] = pool[25] = out_e[1]
        out_e[1] = 1'b1;
        #1;
        expect_one(3, clb_in_o[3]);
        // negative: drive out_e[3] only (same dir, other odd track) -> 0
        out_e = 1'b1 << 3;
        #1;
        expect_zero(3, clb_in_o[3]);
        // negative: drive out_e[0] only (EVEN track — unreachable class) -> 0
        out_e = 1'b1 << 0;
        #1;
        expect_zero(3, clb_in_o[3]);

        // =========================================================
        // (1c) clb_in[5] (odd) k=19 -> pool[1+38]=pool[39] = out_w[3]
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(5, 19);                  // pool[39] = out_w[3]
        out_w[3] = 1'b1;
        #1;
        expect_one(5, clb_in_o[5]);
        out_w = 1'b1 << 1;                 // other odd track -> 0
        #1;
        expect_zero(5, clb_in_o[5]);

        // =========================================================
        // (1d) clb_in[10] (even) k=8 -> pool[0+16]=pool[16] = out_s[4]
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(10, 8);                  // pool[16] = out_s[4]
        out_s[4] = 1'b1;
        #1;
        expect_one(10, clb_in_o[10]);
        out_s = 1'b1 << 6;                 // other even track -> 0
        #1;
        expect_zero(10, clb_in_o[10]);

        // =========================================================
        // (2) parity-class proof: an ODD track is unreachable from EVEN
        //     clb_in[0] for EVERY legal k (and vice versa for clb_in[1]).
        // =========================================================
        out_n = 1'b1 << 1; out_s = '0; out_e = '0; out_w = '0;  // only out_n[1] (odd)
        for (k = 0; k < NSUB; k = k + 1) begin
            cfg_write(0, k);
            #1;
            expect_zero(0, clb_in_o[0]);   // even input can never read t=1
        end
        out_n = 1'b1 << 0;                 // only out_n[0] (even)
        for (k = 0; k < NSUB; k = k + 1) begin
            cfg_write(1, k);
            #1;
            expect_zero(1, clb_in_o[1]);   // odd input can never read t=0
        end

        // =========================================================
        // (3) FULL EXHAUST: all 18 inputs x all 24 legal k x 2 patterns,
        //     checked against the §7.1 formula pool[(i%2) + 2*k].
        // =========================================================
        for (pol = 0; pol < 2; pol = pol + 1) begin
            drive_pool(pol[0]);
            for (i = 0; i < N_CB; i = i + 1) begin
                for (k = 0; k < NSUB; k = k + 1) begin
                    cfg_write(i, k);
                    #1;
                    expect_bit(i, pool_bit((i % CB_DIV) + CB_DIV*k) ^ pol[0], clb_in_o[i]);
                end
            end
        end

        // =========================================================
        // (4) isolation sweep: clb_in[7] k=13 -> pool[1+26]=pool[27]=out_e[3];
        //     re-init all OTHERS to k=0 -> read out_n[i%2]. With out_n=0 they
        //     must all read 0 while clb_in[7] reads out_e[3]=1.
        // =========================================================
        for (i = 0; i < N_CB; i = i + 1) begin
            if (i != 7) cfg_write(i, 0);
        end
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(7, 13);                  // pool[27] = out_e[3]
        out_e = 1'b1 << 3;
        #1;
        expect_one(7, clb_in_o[7]);
        for (i = 0; i < N_CB; i = i + 1) begin
            if (i != 7) begin
                expect_zero(i, clb_in_o[i]);   // k=0 -> out_n[i%2] -> 0
            end
        end

        // =========================================================
        // (5) RESERVED k (§7.1): k=24..31 index pool[>=48] -> undefined;
        //     the LRM out-of-range bit-select reads X in simulation.
        //     MUST NOT be programmed — this check only documents the sim view.
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(0, 24);                  // pool[48] -> out of range
        #1;
        if (clb_in_o[0] !== 1'bx) begin
            errors = errors + 1;
            $display("FAIL: reserved k=24 expected X (out-of-range) got=%b", clb_in_o[0]);
        end
        cfg_write(0, 0);                   // restore a legal value
        #1;

        // =========================================================
        // summary
        // =========================================================
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED (%0d errors)", errors);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #50_000_000;
        $display("TEST FAILED (timeout)");
        $finish;
    end
endmodule
`default_nettype wire
