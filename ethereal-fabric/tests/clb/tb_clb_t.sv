`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_clb_t
// Description: Self-checking SystemVerilog testbench for clb_t (N=8 eLUT4 + IIB).
// Details:     Default params (N=8, K=4, EXT_IN=18). Pool layout (C01 §2):
//                pool[17:0]  = clb_in_i      (external)
//                pool[25:18] = clb_out_o     (feedback)  -> clb_out[0] == pool[18]
//              cfg_addr: 0..7  -> eLUT #(addr)  [cfg_data[19:0]]
//                         8..39 -> IIB mux #(addr-8) [cfg_data[4:0]]; mux index = gi*K+gk
//              IMPORTANT (iverilog / usage model): clb_t config registers (tt_r,
//              mux_sel_r) have NO reset by design — the OCC configures EVERY
//              point before un-halt (C03). Unconfigured muxes stay X and poison
//              the LUT inputs (vin=X -> comb=tt[X]=X). So this TB performs a
//              FULL deterministic init (all 8 LUTs + all 32 muxes = 0) before any
//              functional check. With tt=0 the LUT output is 0 for ANY vin, so
//              the init state is X-free.
//              Covers:
//                (1) registered-feedback toggle FF: elut0 as inverter (tt=0x0001)
//                    with ff_en=1 + sync reset val=1, muxes 0..3 sel=18
//                    (clb_out[0] fb); after a reset edge clb_out[0] toggles 1->0->1->0.
//                (2) combinational route: elut1 buffer of clb_in[0] (all 4 LUT
//                    inputs sel=0 -> pool[0]=clb_in[0], so tt=0x8000 = buffer when
//                    vin=15); also an inverter tt=0x0001.
//              Run with: iverilog -g2012 -o /tmp/tb_clb_t tb_clb_t.sv ../../rtl/clb/clb_t.sv ../../rtl/clb/elut4.sv && vvp /tmp/tb_clb_t
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §2
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
module tb_clb_t;
    logic         clk;
    logic         rst_n;
    logic [17:0]  clb_in;
    logic [7:0]   clb_out;
    logic         cfg_we;
    logic [5:0]   cfg_addr;
    logic [31:0]  cfg_data;

    int errors = 0;
    int i;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT (default params) ----
    clb_t dut (
        .clk_i     (clk),
        .rst_ni    (rst_n),
        .clb_in_i  (clb_in),
        .clb_out_o (clb_out),
        .cfg_we_i  (cfg_we),
        .cfg_addr_i(cfg_addr),
        .cfg_data_i(cfg_data)
    );

    // ---- defaults ----
    initial begin
        rst_n    = 1'b1;
        clb_in   = 18'b0;
        cfg_we   = 1'b0;
        cfg_addr = 6'b0;
        cfg_data = 32'b0;
    end

    // ---- config write: pulse cfg_we_i=1 for one clock ----
    task cfg_write(input int a, input logic [31:0] d);
        begin
            @(negedge clk);
            cfg_addr = a;            // truncate to [5:0] (a in 0..39)
            cfg_data = d;
            cfg_we   = 1'b1;
            @(negedge clk);
            cfg_we   = 1'b0;
        end
    endtask

    initial begin
        // =========================================================
        // FULL deterministic init: zero all 8 eLUT configs (addr 0..7)
        // and all 32 IIB mux selects (addr 8..39). With tt=0 every LUT
        // outputs 0 for any vin, so the cluster is X-free and stable.
        // =========================================================
        for (i = 0; i < 8; i = i + 1)  cfg_write(i, 32'h0000_0000);
        for (i = 8; i < 40; i = i + 1) cfg_write(i, 32'h0000_0000);
        @(negedge clk); #1;
        if (clb_out !== 8'b0) begin
            errors = errors + 1;
            $display("FAIL init: clb_out=%b (exp 0)", clb_out);
        end

        // =========================================================
        // Test 1: registered-feedback toggle FF on clb_out[0]
        //   elut0: tt=0x0001 (comb=~in0), ff_en=1, ff_rst_en=1, ff_rst_val=1
        //          cfg_data[19:0] = {0x0001,1,1,1,0} = 0x1E
        //   muxes 0..3 (addr 8..11): sel=18 -> pool[18]=clb_out[0]
        //     => vin = {4{clb_out[0]}} ; comb = tt[vin] = ~clb_out[0]
        // =========================================================
        cfg_write(0, 32'h0000_001E);            // elut0 inverter + registered
        for (i = 8; i < 12; i = i + 1)          // muxes 0,1,2,3 -> sel 18
            cfg_write(i, 32'h0000_0012);

        // assert reset -> vff(clb_out[0]) <= 1
        @(negedge clk); rst_n = 1'b0;
        @(negedge clk); #1;
        if (clb_out[0] !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL toggle reset: exp 1 got %b", clb_out[0]);
        end
        // release reset; vff <= comb = ~clb_out[0] each clock -> toggles
        rst_n = 1'b1;
        @(negedge clk); #1;
        if (clb_out[0] !== 1'b0) begin
            errors = errors + 1; $display("FAIL toggle t1: exp 0 got %b", clb_out[0]); end
        @(negedge clk); #1;
        if (clb_out[0] !== 1'b1) begin
            errors = errors + 1; $display("FAIL toggle t2: exp 1 got %b", clb_out[0]); end
        @(negedge clk); #1;
        if (clb_out[0] !== 1'b0) begin
            errors = errors + 1; $display("FAIL toggle t3: exp 0 got %b", clb_out[0]); end
        @(negedge clk); #1;
        if (clb_out[0] !== 1'b1) begin
            errors = errors + 1; $display("FAIL toggle t4: exp 1 got %b", clb_out[0]); end

        // park elut0 as a stable 0 (tt=0, ff_en=0) so it stops toggling
        cfg_write(0, 32'h0000_0000);
        @(negedge clk); #1;

        // =========================================================
        // Test 2: combinational route through elut1
        //   elut1 muxes (4..7, addr 12..15) still sel=0 (from init) ->
        //     all 4 elut1 inputs = pool[0] = clb_in[0], vin = {4{clb_in[0]}}.
        //   Buffer:   tt=0x8000 (comb=1 when vin=15) -> cfg_data=0x80000
        //   Inverter: tt=0x0001 (comb=0 when vin=15, =1 when vin=0) -> cfg=0x10
        // =========================================================
        // --- buffer of clb_in[0] on clb_out[1] ---
        cfg_write(1, 32'h0008_0000);            // elut1 buffer (ff_en=0)
        @(negedge clk); clb_in = 18'h0;         // clb_in[0]=0
        #1;
        if (clb_out[1] !== 1'b0) begin
            errors = errors + 1; $display("FAIL buf in0: exp 0 got %b", clb_out[1]); end
        @(negedge clk); clb_in = 18'h1;         // clb_in[0]=1
        #1;
        if (clb_out[1] !== 1'b1) begin
            errors = errors + 1; $display("FAIL buf in1: exp 1 got %b", clb_out[1]); end

        // --- inverter of clb_in[0] on clb_out[1] ---
        cfg_write(1, 32'h0000_0010);            // elut1 inverter tt=0x0001 (ff_en=0)
        @(negedge clk); clb_in = 18'h0;         // clb_in[0]=0 -> out 1
        #1;
        if (clb_out[1] !== 1'b1) begin
            errors = errors + 1; $display("FAIL inv in0: exp 1 got %b", clb_out[1]); end
        @(negedge clk); clb_in = 18'h1;         // clb_in[0]=1 -> out 0
        #1;
        if (clb_out[1] !== 1'b0) begin
            errors = errors + 1; $display("FAIL inv in1: exp 0 got %b", clb_out[1]); end

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
