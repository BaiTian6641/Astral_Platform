`timescale 1ns/1ps
`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_connection_block
// Description: Self-checking SystemVerilog testbench for connection_block (W=12, N_CB=18).
// Details:     Exercises the input-side routable CB mux network (C01 §3):
//                cfg_addr = clb_in index  (0..N_CB-1,  masked to $clog2(N_CB) bits)
//                cfg_data = track index   (0..4*W-1,   masked to $clog2(4*W) bits)
//                clb_in_o[i] = pool[sel_r[i]]
//              where pool = {out_w, out_e, out_s, out_n} so:
//                track 0..W-1   -> out_n[track]
//                track W..2W-1  -> out_s[track-W]
//                track 2W..3W-1 -> out_e[track-2W]
//                track 3W..4W-1 -> out_w[track-3W]
//              Covers all 4 source dirs (n/s/e/w) via specific clb_in configs,
//              plus a negative isolation check (unselected track does not leak)
//              and a full-tile isolation sweep.
//              Run: iverilog -g2012 -o /tmp/tb_cb connection_block.sv tb_connection_block.sv && vvp /tmp/tb_cb
// Maintainer:  BaiTian6641
// Created:     2026-07-25
// Tags:        RTL TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3 (CB)
// Notes:       sel_r has NO reset (OCC configures before run, C03) -> at sim
//              start it is X -> X-propagates through the mux -> corrupts checks.
//              The TB ZERO-INITs all 18 sel_r (cfg addr 0..N_CB-1, data=0) in a
//              reset/config phase before checks (mirrors tb_switch_box.sv's
//              zero-init lesson). After zero-init, default sel=0 reads out_n[0]
//              (NOT a disconnect).
module tb_connection_block;
    localparam int W    = 12;
    localparam int N_CB = 18;       // number of CLB inputs (EXT_IN)

    logic                     clk;
    logic                     cfg_we;
    logic [$clog2(N_CB)-1:0]  cfg_addr;   // 5 bits for N_CB=18
    logic [$clog2(4*W)-1:0]   cfg_data;   // 6 bits for W=12
    logic [W-1:0]             out_n, out_s, out_e, out_w;
    logic [N_CB-1:0]          clb_in_o;

    int errors = 0;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT ----
    connection_block #(.W(W), .N_CB(N_CB)) dut (
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
    //   a in 0..N_CB-1   -> which clb_in
    //   d in 0..4*W-1    -> track index (sel)
    task cfg_write(input int a, input int d);
        begin
            @(negedge clk);
            cfg_addr = a[$clog2(N_CB)-1:0];   // truncates to addr width
            cfg_data = d[$clog2(4*W)-1:0];    // truncates to data width
            cfg_we   = 1'b1;
            @(negedge clk);
            cfg_we   = 1'b0;
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

    int i;

    initial begin
        // =========================================================
        // ZERO-INIT: write sel=0 for ALL 18 clb_ins. sel_r has no reset,
        // so without this it X-propagates through the mux and corrupts every
        // check. Default sel=0 reads out_n[0] (NOT a disconnect).
        // (Mirrors tb_switch_box.sv's zero-init lesson, C03 config-before-run.)
        // =========================================================
        for (i = 0; i < N_CB; i = i + 1) begin
            cfg_write(i, 0);
        end

        // =========================================================
        // (1) clb_in[0] sel=0 (track 0 -> out_n[0])
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(0, 0);                  // sel[0] = track 0 (out_n[0])
        out_n[0] = 1'b1;
        #1;                               // let comb settle
        expect_one(0, clb_in_o[0]);

        // negative: drive out_n[1] (a DIFFERENT track) -> clb_in[0] stays 0
        out_n = 1'b1 << 1;                // only bit 1 set
        #1;
        expect_zero(0, clb_in_o[0]);

        // =========================================================
        // (2) clb_in[3] sel=2W+0=24 (out_e[0])
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(3, 2*W + 0);             // sel[3] = track 24 (out_e[0])
        out_e[0] = 1'b1;
        #1;
        expect_one(3, clb_in_o[3]);

        // negative: drive out_e[1] only -> clb_in[3]=0
        out_e = 1'b1 << 1;
        #1;
        expect_zero(3, clb_in_o[3]);

        // =========================================================
        // (3) clb_in[5] sel=3W+2=38 (out_w[2])
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(5, 3*W + 2);             // sel[5] = track 38 (out_w[2])
        out_w[2] = 1'b1;
        #1;
        expect_one(5, clb_in_o[5]);

        // negative: drive out_w[3] only -> clb_in[5]=0
        out_w = 1'b1 << 3;
        #1;
        expect_zero(5, clb_in_o[5]);

        // =========================================================
        // (4) clb_in[10] sel=W+4=16 (out_s[4])
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(10, W + 4);              // sel[10] = track 16 (out_s[4])
        out_s[4] = 1'b1;
        #1;
        expect_one(10, clb_in_o[10]);

        // negative: drive out_s[5] only -> clb_in[10]=0
        out_s = 1'b1 << 5;
        #1;
        expect_zero(10, clb_in_o[10]);

        // =========================================================
        // (5) full isolation sweep: clb_in[7] sel=out_e[3] (2W+3=27);
        //     every OTHER clb_in still sel=0 -> reads out_n[0]. With out_n=0,
        //     all those clb_ins must read 0 while clb_in[7] reads out_e[3]=1.
        // =========================================================
        out_n = '0; out_s = '0; out_e = '0; out_w = '0;
        cfg_write(7, 2*W + 3);             // sel[7] = track 27 (out_e[3])
        out_e = 1'b1 << 3;                 // only out_e[3] driven
        #1;
        expect_one(7, clb_in_o[7]);
        for (i = 0; i < N_CB; i = i + 1) begin
            if (i != 7) begin
                expect_zero(i, clb_in_o[i]);   // sel=0 -> out_n[0] -> 0
            end
        end

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
