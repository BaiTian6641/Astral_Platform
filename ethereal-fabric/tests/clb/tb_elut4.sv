`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_elut4
// Description: Self-checking SystemVerilog testbench for elut4 (virtual LUT4 + FF).
// Details:     Exercises the frozen C01 §1.3 interface:
//                cfg_data_i = {tt[15:0], ff_en, ff_rst_en, ff_rst_val, out_inv}
//              Covers: (1) combinational LUT4 (ff_en=0) over >=100 random tt x all
//              16 vin; (2) out_inv flip; (3) registered path (ff_en=1) with sync
//              reset tracking vff; (4) config persistence across a user-reset pulse.
//              Run with: iverilog -g2012 -o /tmp/tb_elut4 tb_elut4.sv ../../rtl/clb/elut4.sv && vvp /tmp/tb_elut4
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §1
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
module tb_elut4;
    logic        clk;
    logic        rst_n;
    logic [3:0]  vin;
    logic        vout;
    logic        cfg_we;
    logic [19:0] cfg_data;
    logic        cfg_ce;

    int errors = 0;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT ----
    elut4 dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .vin_i     (vin),
        .vout_o    (vout),
        .cfg_we_i  (cfg_we),
        .cfg_data_i(cfg_data),
        .cfg_ce_i  (cfg_ce)
    );

    // ---- defaults ----
    initial begin
        rst_n    = 1'b1;
        vin      = 4'b0;
        cfg_we   = 1'b0;
        cfg_data = 20'b0;
        cfg_ce   = 1'b1;     // CLB ties cfg_ce_i=1'b1; mirror that here
    end

    // ---- config write: pulse cfg_we_i=1 for exactly one clock ----
    task cfg_write(input logic [19:0] d);
        begin
            @(negedge clk);
            cfg_data = d;
            cfg_we   = 1'b1;
            @(negedge clk);
            cfg_we   = 1'b0;
        end
    endtask

    // ---- pack cfg_data word from fields ----
    function automatic logic [19:0] pack(input logic [15:0] tt,
                                         input logic ff_en,
                                         input logic ff_rst_en,
                                         input logic ff_rst_val,
                                         input logic out_inv);
        pack = {tt, ff_en, ff_rst_en, ff_rst_val, out_inv};
    endfunction

    int          i, j;
    logic [15:0] rtt;
    logic        expb;

    initial begin
        // =========================================================
        // 1) Combinational LUT4 (ff_en=0, out_inv=0): >=100 random tt x all 16 vin
        // =========================================================
        for (i = 0; i < 120; i = i + 1) begin
            rtt = $random;
            cfg_write(pack(rtt, 1'b0, 1'b0, 1'b0, 1'b0));
            for (j = 0; j < 16; j = j + 1) begin
                @(negedge clk);
                vin = j;          // truncate to low 4 bits (j in 0..15)
                #1;               // let comb settle
                expb = rtt[j];
                if (vout !== expb) begin
                    errors = errors + 1;
                    $display("FAIL comb: tt=%h vin=%0d exp=%b got=%b", rtt, j, expb, vout);
                end
            end
        end

        // =========================================================
        // 2) out_inv=1 (ff_en=0): vout must be ~tt[vin]
        // =========================================================
        for (i = 0; i < 40; i = i + 1) begin
            rtt = $random;
            cfg_write(pack(rtt, 1'b0, 1'b0, 1'b0, 1'b1));   // out_inv=1
            for (j = 0; j < 16; j = j + 1) begin
                @(negedge clk);
                vin = j;
                #1;
                expb = ~rtt[j];
                if (vout !== expb) begin
                    errors = errors + 1;
                    $display("FAIL inv: tt=%h vin=%0d exp=%b got=%b", rtt, j, expb, vout);
                end
            end
        end

        // =========================================================
        // 3) Registered path (ff_en=1, sync reset): vout tracks vff
        //    tt = 0xAAAA -> bit0=0, bit1=1, bit2=0
        // =========================================================
        rtt = 16'hAAAA;
        cfg_write(pack(rtt, 1'b1, 1'b1, 1'b0, 1'b0));  // ff_en=1, ff_rst_en=1, ff_rst_val=0
        // assert reset -> vff <= 0
        @(negedge clk); rst_n = 1'b0;
        @(negedge clk); #1;
        if (vout !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL reg reset: exp 0 got %b", vout);
        end
        rst_n = 1'b1;
        // vin=1 -> comb=tt[1]=1 -> next clock vff=1
        @(negedge clk); vin = 4'd1;
        @(negedge clk); #1;
        if (vout !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL reg vin1: exp 1 got %b", vout);
        end
        // vin=0 -> comb=tt[0]=0 -> next clock vff=0
        @(negedge clk); vin = 4'd0;
        @(negedge clk); #1;
        if (vout !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL reg vin0: exp 0 got %b", vout);
        end

        // =========================================================
        // 4) Config persists across a user-reset pulse (ff_en still 1)
        //    After reset, clock with vin=2 -> vff=tt[2]
        // =========================================================
        @(negedge clk); rst_n = 1'b0;
        @(negedge clk); rst_n = 1'b1;
        @(negedge clk); vin = 4'd2;     // comb = tt[2]
        @(negedge clk); #1;
        expb = rtt[2];
        if (vout !== expb) begin
            errors = errors + 1;
            $display("FAIL persist: tt=%h vin=2 exp=%b got=%b", rtt, expb, vout);
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
