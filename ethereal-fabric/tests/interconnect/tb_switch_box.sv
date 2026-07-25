`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_switch_box
// Description: Self-checking SystemVerilog testbench for switch_box (W=12).
// Details:     Exercises the frozen C01 §3.3 disjoint unidirectional topology:
//                cfg_addr = DIR*W + t   (DIR: 0=N,1=S,2=E,3=W ; t: 0..W-1)
//                cfg_data[1:0] = sel:  0=disconnect(drive 0),
//                                      1/2/3 = same-index input track of the 3
//                                              OTHER directions (ascending order)
//              For output dir d, the source dir of a given sel (1..3) is:
//                src = (sel-1 < d) ? (sel-1) : sel
//              Covers: for every direction, every sel 0..3, every track 0..11;
//              plus routable-CB injection (inject_en[j], clb_out[j] -> out_e[j]).
//              Run with: iverilog -g2012 -o /tmp/tb_switch_box tb_switch_box.sv ../../rtl/interconnect/switch_box.sv && vvp /tmp/tb_switch_box
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
module tb_switch_box;
    localparam int W     = 12;
    localparam int N_INJ = 8;       // routable-CB injectable CLB-output count

    logic             clk;
    logic             cfg_we;
    logic [5:0]       cfg_addr;     // $clog2(4*W+N_INJ) = 6 for W=12,N_INJ=8
    logic [1:0]       cfg_data;
    logic [W-1:0]     in_n, in_s, in_e, in_w;
    logic [N_INJ-1:0] clb_out;      // local CLB outputs -> inject onto out_e[0..N_INJ-1]
    logic [W-1:0]     out_n, out_s, out_e, out_w;

    int errors = 0;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT ----
    switch_box #(.W(W), .N_INJ(N_INJ)) dut (
        .clk_i     (clk),
        .cfg_we_i  (cfg_we),
        .cfg_addr_i(cfg_addr),
        .cfg_data_i(cfg_data),
        .in_n      (in_n),
        .in_s      (in_s),
        .in_e      (in_e),
        .in_w      (in_w),
        .clb_out_i (clb_out),
        .out_n     (out_n),
        .out_s     (out_s),
        .out_e     (out_e),
        .out_w     (out_w)
    );

    // ---- defaults ----
    initial begin
        cfg_we   = 1'b0;
        cfg_addr = 6'b0;
        cfg_data = 2'b0;
        in_n = '0;  in_s = '0;  in_e = '0;  in_w = '0;
        clb_out = '0;
    end

    // ---- config write: pulse cfg_we_i=1 for one clock ----
    //   a in 0..4W-1          -> sel (d in 0..3)
    //   a in 4W..4W+N_INJ-1   -> inject_en[a-4W] (d[0])
    task cfg_write(input int a, input int d);
        begin
            @(negedge clk);
            cfg_addr = a;            // truncates to [5:0], a in 0..4W+N_INJ-1
            cfg_data = d;            // truncates to [1:0]
            cfg_we   = 1'b1;
            @(negedge clk);
            cfg_we   = 1'b0;
        end
    endtask

    int outd, sel, t, sd;
    logic got;
    logic exp;

    initial begin
        // ---- initialize ALL config (sel + inject_en) to 0 ----
        // RTL sel_r/inj_en_r have NO reset; write them to a known state before
        // evaluating outputs (mirrors OCC configures-before-run, C03). Required
        // so the disjoint checks for out_e[0..N_INJ-1] see inj_en_r=0 (otherwise
        // the inject mux would propagate X and corrupt the disjoint checks).
        for (int a = 0; a < 4*W + N_INJ; a = a + 1) begin
            cfg_write(a, 0);
        end

        for (outd = 0; outd < 4; outd = outd + 1) begin
            for (sel = 0; sel < 4; sel = sel + 1) begin
                for (t = 0; t < W; t = t + 1) begin
                    // configure this (out dir, track) select
                    cfg_write(outd*W + t, sel);

                    // drive inputs: zero all, then set the selected source track
                    in_n = '0; in_s = '0; in_e = '0; in_w = '0;
                    if (sel != 0) begin
                        sd = ((sel - 1) < outd) ? (sel - 1) : sel;
                        case (sd)
                            0: in_n[t] = 1'b1;
                            1: in_s[t] = 1'b1;
                            2: in_e[t] = 1'b1;
                            3: in_w[t] = 1'b1;
                        endcase
                    end
                    #1;   // let comb settle

                    // read the configured output track
                    case (outd)
                        0: got = out_n[t];
                        1: got = out_s[t];
                        2: got = out_e[t];
                        3: got = out_w[t];
                    endcase

                    exp = (sel == 0) ? 1'b0 : 1'b1;
                    if (got !== exp) begin
                        errors = errors + 1;
                        $display("FAIL: outd=%0d sel=%0d t=%0d src=%0d exp=%b got=%b",
                                 outd, sel, t, sd, exp, got);
                    end
                end
            end
        end

        // =========================================================
        // routable-CB injection: clb_out[j] -> out_e[j] (j < N_INJ)
        // =========================================================
        // reset all config to a clean state (all disconnect, no inject)
        for (int a = 0; a < 4*W + N_INJ; a = a + 1) begin
            cfg_write(a, 0);
        end
        in_n = '0; in_s = '0; in_e = '0; in_w = '0;
        clb_out = '0;

        // (1) inject_en[5]=1, clb_out[5]=1, channels=0 -> out_e = bit5 only
        cfg_write(4*W + 5, 1);            // addr 53 -> inject_en[5] = 1
        clb_out[5] = 1'b1;
        #1;
        if (out_e !== 12'h020) begin       // only bit 5 set
            errors = errors + 1;
            $display("FAIL: inject_en[5]=1 clb_out[5]=1 -> out_e exp=0x020 got=%h", out_e);
        end
        if (out_n !== '0 || out_s !== '0 || out_w !== '0) begin
            errors = errors + 1;
            $display("FAIL: injection leaked n/s/w out_n=%h out_s=%h out_w=%h", out_n, out_s, out_w);
        end

        // (2) clear inject_en[5] -> out_e[5] follows disjoint sel (0 -> drive 0)
        cfg_write(4*W + 5, 0);
        #1;
        if (out_e[5] !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: inject_en[5]=0 disjoint sel=0 -> out_e[5] exp=0 got=%b", out_e[5]);
        end

        // (3) disjoint sel out_e[5]<-in_n[5] (sel 1), inject off, in_n[5]=1 -> 1
        cfg_write(2*W + 5, 1);            // out_e sel 1 = in_n
        in_n = 1 << 5;
        #1;
        if (out_e[5] !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: disjoint out_e[5]<-in_n[5] (inject off) exp=1 got=%b", out_e[5]);
        end

        // (4) re-enable inject_en[5] with clb_out[5]=0, in_n[5]=1 -> inject wins -> 0
        clb_out[5] = 1'b0;
        cfg_write(4*W + 5, 1);
        #1;
        if (out_e[5] !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: inject overrides disjoint (in_n[5]=1,clb_out[5]=0) exp=0 got=%b", out_e[5]);
        end

        // cleanup
        clb_out = '0;
        in_n = '0;

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
