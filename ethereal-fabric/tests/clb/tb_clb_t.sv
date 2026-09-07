`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_clb_t
// Description: Self-checking SystemVerilog testbench for clb_t (N=8 eLUT4 + IIB,
//              interconnect v2c, FROZEN spec §7.2).
// Details:     Default params (N=8, K=4, EXT_IN=18). v2c IIB pool layout (§7.2):
//                pool[17:0]  = clb_in_i  (external)
//                pool[23:18] = 0         (padding)
//                pool[31:24] = clb_out_o (feedback j at pool[24+j] = {2'b11, j})
//              Mux m = gi*K + gk (m=0..31) has ext parity class pi(m) = m%2 = gk%2.
//              Select encoding (5 bits, slice-only):
//                sel[4]=1: ext pin 2*sel[3:0]+pi(m)   (legal sel[3:0] = 0..8)
//                sel[4]=0: feedback j = sel[2:0]      (sel[3] don't-care)
//              Blank sel=0 = feedback j=0 (was clb_in[0] in v1.1, §7.7).
//              cfg_addr: 0..7  -> eLUT #(addr)  [cfg_data[19:0]]
//                         8..39 -> IIB mux #(addr-8) [cfg_data[4:0]]
//              IMPORTANT (iverilog / usage model): clb_t config registers (tt_r,
//              mux_sel_r) have NO reset by design — the OCC configures EVERY
//              point before un-halt (C03). Unconfigured muxes stay X and poison
//              the LUT inputs (vin=X -> comb=tt[X]=X). v2c X-containment note
//              (§7.7): blanked muxes self-read fb[0], so a blanked LUT ring is
//              an X fixed point UNTIL a defined value is injected. This TB
//              therefore inits every LUT as an FF-held const-0 (ff_en=1,
//              ff_rst_en=1, ff_rst_val=0) + every mux sel=0 and pulses rst_ni,
//              giving a fully defined all-0 cluster state before any check.
//              Covers:
//                (1) registered-feedback toggle FF: elut0 as inverter (tt=0x0001)
//                    with ff_en=1 + sync reset val=1, muxes 0..3 sel=0 = fb j=0
//                    (clb_out[0] fb; v1.1 sel=18 -> v2c sel=j translation, §7.2);
//                    after a reset edge clb_out[0] toggles 1->0->1->0.
//                (2) combinational route: elut1 buffer/inverter of clb_in[0]
//                    through the parity-aware v2c ext encoding (active pin gk=0,
//                    pi=0, sel=16 -> ext pin 0; tt=0xAAAA/0x5555 pick vin[0]).
//                (3) R1 connectivity exhaust: EVERY feedback j=0..7 from EVERY
//                    mux m=0..31 (256 checks) against reset-held FF constants.
//                (4) R2/R3 ext parity exhaust: every legal ext sel[3:0]=0..8 from
//                    every mux, 2 complementary clb_in patterns (576 checks) —
//                    mux m only ever reads ext pins with i%2 == m%2.
//                (5) reserved-encoding observation (§7.2: sel[4]=1 with
//                    sel[3:0]=9..15 reads padding/fb — MUST NOT be programmed).
//              Run with: iverilog -g2012 -o /tmp/tb_clb_t tb_clb_t.sv ../../rtl/clb/clb_t.sv ../../rtl/clb/elut4.sv && vvp /tmp/tb_clb_t
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-09-02 - v2c IIB (E2-FAB5, spec §7.2): pool reorganization +
//                            parity ext classes + slice-only sel; R1/R2 exhaust.
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/fabric/interconnect-config-v0.md §7.2 (v2c FROZEN)
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
//              Mux inputs are observed via the hierarchical probe dut.lut_in[gi][gk]
//              (packed [N-1:0][K-1:0]; iverilog -g2012 handles the 2D select).
module tb_clb_t;
    logic         clk;
    logic         rst_n;
    logic [17:0]  clb_in;
    logic [7:0]   clb_out;
    logic         cfg_we;
    logic [5:0]   cfg_addr;
    logic [31:0]  cfg_data;

    int errors = 0;
    int i, m, j, kk;

    // FF-held feedback constant pattern for the exhaust (clb_out[j] = PAT[j])
    localparam logic [7:0] PAT = 8'hA5;   // bit j: j even -> 1 for 0,2; see table

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

    // pulse user reset (2 cycles low) — resets eLUT4 FFs to ff_rst_val
    task do_reset;
        begin
            @(negedge clk); rst_n = 1'b0;
            @(negedge clk); @(negedge clk); rst_n = 1'b1;
        end
    endtask

    // Mux-input probe: sample the whole packed lut_in vector hierarchically into
    // a flat local (iverilog forbids VARIABLE indices both into a hierarchical
    // select and into a local 2D packed array; a flat-vector bit-select with a
    // computed index is fine). lut_in[gi][gk] == lut_in_flat[gi*4+gk] == [m].
    logic [31:0] lut_in_flat;
    always_comb lut_in_flat = dut.lut_in;

    // check a probed mux input against an expected defined bit
    task expect_pin(input int mm, input logic exp);
        begin
            if (lut_in_flat[mm] !== exp) begin
                errors = errors + 1;
                $display("FAIL: mux %0d (LUT %0d pin %0d) expected %b got %b",
                         mm, mm/4, mm%4, exp, lut_in_flat[mm]);
            end
        end
    endtask

    logic [17:0] ext_pat;

    initial begin
        // =========================================================
        // FULL deterministic init (X-free under v2c): every eLUT = FF-held
        // const-0 (cfg 0xC: tt=0, ff_en=1, ff_rst_en=1, ff_rst_val=0), every
        // IIB mux sel=0 (= fb j=0, the v2c blank default). A reset pulse then
        // forces clb_out = 0x00, which makes fb0 = 0, so every mux input is
        // defined (v2c blanked-LUT self-read of fb[0] would otherwise hold X).
        // =========================================================
        for (i = 0; i < 8; i = i + 1)  cfg_write(i, 32'h0000_000C);
        for (i = 8; i < 40; i = i + 1) cfg_write(i, 32'h0000_0000);
        do_reset();
        @(negedge clk); #1;
        if (clb_out !== 8'b0) begin
            errors = errors + 1;
            $display("FAIL init: clb_out=%b (exp 0)", clb_out);
        end

        // =========================================================
        // Test 1: registered-feedback toggle FF on clb_out[0]
        //   elut0: tt=0x0001 (comb=~in0), ff_en=1, ff_rst_en=1, ff_rst_val=1
        //          cfg_data[19:0] = {0x0001,1,1,1,0} = 0x1E
        //   muxes 0..3 (addr 8..11): sel=0 -> fb j=0 = pool[24] = clb_out[0]
        //     (v1.1 sel=18 -> v2c sel=j translation, §7.2)
        //     => vin = {4{clb_out[0]}} ; comb = tt[vin] = ~clb_out[0]
        // =========================================================
        cfg_write(0, 32'h0000_001E);            // elut0 inverter + registered
        for (i = 8; i < 12; i = i + 1)          // muxes 0,1,2,3 -> sel 0 (fb0)
            cfg_write(i, 32'h0000_0000);

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
        // (clb_out[0] is defined here, so the fb0 self-read settles to tt[*]=0)
        cfg_write(0, 32'h0000_0000);
        @(negedge clk); #1;

        // =========================================================
        // Test 2: combinational route through elut1 (v2c parity-aware ext sel)
        //   elut1 muxes (4..7, addr 12..15): active pin is gk=0 (pi=0) reading
        //   ext pin 0 via sel = {1'b1, 4'd0} = 16. The odd-parity pins gk=1,3
        //   CANNOT reach clb_in[0] (§7.2 R2); they are parked on ext pin 1
        //   (sel=16 -> 2*0+pi=1) — defined, and ignored by the truth tables
        //   below (tt picks vin[0] only):
        //     buffer   tt=0xAAAA (comb = vin[0])   -> cfg 0xAAAA0
        //     inverter tt=0x5555 (comb = ~vin[0])  -> cfg 0x55550
        //   Resulting vin = {clb_in[1], clb_in[0], clb_in[1], clb_in[0]}.
        // =========================================================
        for (i = 12; i < 16; i = i + 1)         // elut1 muxes -> sel 16
            cfg_write(i, 32'h0000_0010);        // sel[4]=1, sel[3:0]=0 -> ext pin pi(m)

        // --- buffer of clb_in[0] on clb_out[1] ---
        cfg_write(1, 32'h000A_AAA0);            // elut1 buffer of vin[0] (ff_en=0)
        @(negedge clk); clb_in = 18'h0;         // clb_in[0]=0
        #1;
        if (clb_out[1] !== 1'b0) begin
            errors = errors + 1; $display("FAIL buf in0: exp 0 got %b", clb_out[1]); end
        @(negedge clk); clb_in = 18'h1;         // clb_in[0]=1
        #1;
        if (clb_out[1] !== 1'b1) begin
            errors = errors + 1; $display("FAIL buf in1: exp 1 got %b", clb_out[1]); end

        // --- inverter of clb_in[0] on clb_out[1] ---
        cfg_write(1, 32'h0005_5550);            // elut1 inverter of vin[0] (ff_en=0)
        @(negedge clk); clb_in = 18'h0;         // clb_in[0]=0 -> out 1
        #1;
        if (clb_out[1] !== 1'b1) begin
            errors = errors + 1; $display("FAIL inv in0: exp 1 got %b", clb_out[1]); end
        @(negedge clk); clb_in = 18'h1;         // clb_in[0]=1 -> out 0
        #1;
        if (clb_out[1] !== 1'b0) begin
            errors = errors + 1; $display("FAIL inv in1: exp 0 got %b", clb_out[1]); end

        // =========================================================
        // Test 3: R1 connectivity exhaust — every fb j from every mux m.
        //   Hold all 8 eLUTs as FF constants (clb_out = PAT = 8'hA5) under an
        //   asserted reset; then per (m, j): sel(m) = {1'b0, x, j[2:0]} = j and
        //   probe dut.lut_in[m/4][m%4] === PAT[j]. Reset-held FFs make the fb
        //   values independent of the (changing) mux configs.
        // =========================================================
        for (i = 0; i < 8; i = i + 1)
            cfg_write(i, 32'h0000_000C | (PAT[i] << 1));  // FF-held const PAT[i]
        @(negedge clk); rst_n = 1'b0;                     // hold reset for the exhaust
        @(negedge clk); @(negedge clk); #1;
        if (clb_out !== PAT) begin
            errors = errors + 1;
            $display("FAIL exhaust setup: clb_out=%b (exp %b)", clb_out, PAT);
        end

        for (m = 0; m < 32; m = m + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                cfg_write(8 + m, 32'(j));        // sel[4]=0 -> fb j
                #1;
                expect_pin(m, PAT[j]);
            end
        end

        // =========================================================
        // Test 4: R2/R3 ext parity exhaust — every legal ext entry from every
        //   mux, 2 complementary patterns. sel(m) = {1'b1, kk[3:0]} = 16+kk must
        //   read ext pin 2*kk + (m%2) (parity class of the mux, §7.2).
        // =========================================================
        ext_pat = 18'h15555;                     // bit i = 1 for even i (i<17)
        for (i = 0; i < 2; i = i + 1) begin
            clb_in = ext_pat;
            @(negedge clk); #1;
            for (m = 0; m < 32; m = m + 1) begin
                for (kk = 0; kk < 9; kk = kk + 1) begin
                    cfg_write(8 + m, 32'(16 + kk));
                    #1;
                    expect_pin(m, ext_pat[2*kk + (m % 2)]);
                end
            end
            ext_pat = 18'h2AAAA;                 // complement (bit i = 1 for odd i)
        end

        // =========================================================
        // Test 5: reserved encodings (§7.2: sel[4]=1, sel[3:0]=9..15 — MUST NOT
        //   be programmed). Observation only, documents this implementation:
        //   sel[3:0]=9..11 read the zero padding pool[18..23]; sel[3:0]=12..15
        //   alias the feedback entries pool[24..31].
        // =========================================================
        cfg_write(8, 32'd25);  #1;  // mux0 (pi=0): idx {9,0}=18 -> padding 0
        expect_pin(0, 1'b0);
        cfg_write(8, 32'd31);  #1;  // mux0 (pi=0): idx {15,0}=30 -> fb6 = PAT[6] = 0
        expect_pin(0, PAT[6]);
        cfg_write(9, 32'd25);  #1;  // mux1 (pi=1): idx {9,1}=19 -> padding 0
        expect_pin(1, 1'b0);
        cfg_write(9, 32'd31);  #1;  // mux1 (pi=1): idx {15,1}=31 -> fb7 = PAT[7] = 1
        expect_pin(1, PAT[7]);

        @(negedge clk); rst_n = 1'b1;           // release reset

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
