`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_hotswap
// Description: Phase-0 dual-image HOT-SWAP demo on the real fabric_top RTL.
// Details:     Loads image A (a self-contained TFF: clb_out[0] toggles each
//              cycle via eLUT4[0] FF + IIB feedback), runs it, then performs a
//              BLANK-before-write (the C03 §3 red-line, E0-FAB5) and loads image
//              B (constant-1), and verifies the fabric's observed behavior
//              changes from toggle -> constant. Proves runtime reconfiguration
//              (hot-swap) on the actual fabric RTL via host direct-drive (the
//              Phase-0 circuit-breaker path; the full EBI/OCC/frame-bus Shell
//              is E0-SHL1/2). No external IO needed (self-contained feedback).
// Maintainer:  BaiTian6641
// Created:     2026-07-26
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/phases/phase-0-*.md (dual-image hot-swap demo)
// Notes:       cfg layout (fabric_top v1.1, 2x2 grid TIW=2):
//                cfg_addr = {tile_idx[9:8], unit[7:6], intra[5:0]}
//                unit 2'b00=CLB. intra 0..7 = eLUT4 #(intra); 8..39 = IIB mux #(intra-8).
//              eLUT4 cfg_data[19:0] = {tt[19:4], ff_en[3], ff_rst_en[2], ff_rst_val[1], out_inv[0]}.
//              Image A eLUT4[0]: tt=0x5555 (NOT pin0), ff_en=1, ff_rst_en=1, ff_rst_val=0
//                -> registered ~clb_out[0] -> TOGGLE. IIB pin0 sel=18 (clb_out[0] feedback).
//              Image B eLUT4[0]: tt=0xFFFF (const 1), ff_en=1, ff_rst_en=1, ff_rst_val=1 -> const 1.
`timescale 1ns/1ps

module tb_hotswap;
    localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18;
    localparam int OBS_W = R*C*N;          // 32

    logic                        clk = 1'b0;
    logic                        rst_ni = 1'b1;
    logic                        cfg_we = 1'b0;
    logic [15:0]                 cfg_addr = '0;
    logic [31:0]                 cfg_data = '0;
    logic [OBS_W-1:0]            clb_out_obs;

    fabric_top #(.R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN)) dut (
        .clk_i(clk), .rst_ni(rst_ni),
        .cfg_we_i(cfg_we), .cfg_addr_i(cfg_addr), .cfg_data_i(cfg_data),
        .clb_out_obs_o(clb_out_obs)
    );

    always #5 clk = ~clk;                 // 100 MHz

    // one config-register write (1-cycle cfg_we pulse on the cfg clock)
    task cfg_write(input [15:0] a, input [31:0] d);
        begin
            @(negedge clk); cfg_addr = a; cfg_data = d; cfg_we = 1'b1;
            @(negedge clk); cfg_we = 1'b0;
        end
    endtask

    // assert user reset for 2 cycles (resets eLUT4 FFs to ff_rst_val)
    task do_reset;
        begin
            @(negedge clk); rst_ni = 1'b0;
            @(negedge clk); @(negedge clk); rst_ni = 1'b1;
        end
    endtask

    integer i, errors;
    logic seen_one, seen_zero;

    initial begin
        errors = 0;
        // dump for waveform inspection (optional)
        // $dumpfile("/tmp/tb_hotswap.vcd"); $dumpvars(0, tb_hotswap);

        // ============================================================
        // IMAGE A: TFF on tile(0,0) eLUT4[0]  -> clb_out_obs[0] toggles
        // ============================================================
        // eLUT4[0] @ tile0: addr {2'b00,2'b00,6'd0}=0x0000 ; data tt=0x5555,ff_en,ff_rst_en
        cfg_write(16'h0000, 32'h0005555C);   // tt=0x5555, ff_en=1, ff_rst_en=1, ff_rst_val=0
        // IIB mux0..3 (eLUT4[0] pins 0-3) @ tile0: ALL sel=18 (clb_out[0] feedback).
        // Makes eLUT4[0] self-contained — vin depends only on its own clean FF
        // output, not on X reset-less clb_in/CB/SB (iverilog X-propagation guard).
        cfg_write(16'h0008, 32'h00000012);   // intra 8  = mux(gi0,gk0)
        cfg_write(16'h0009, 32'h00000012);   // intra 9  = mux(gi0,gk1)
        cfg_write(16'h000A, 32'h00000012);   // intra 10 = mux(gi0,gk2)
        cfg_write(16'h000B, 32'h00000012);   // intra 11 = mux(gi0,gk3)

        do_reset();                          // clb_out[0] -> 0 (ff_rst_val)

        // run A: observe clb_out_obs[0]; expect toggle (0 -> 1 -> 0 -> 1 ...)
        seen_one = 1'b0; seen_zero = 1'b0;
        $display("[A] toggle image — clb_out_obs[0] over cycles:");
        for (i = 0; i < 6; i = i + 1) begin
            @(negedge clk);
            $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
            if (clb_out_obs[0] === 1'b1) seen_one  = 1'b1;
            if (clb_out_obs[0] === 1'b0) seen_zero = 1'b1;
        end
        if (!(seen_one && seen_zero)) begin
            errors = errors + 1;
            $display("FAIL: image A did NOT toggle (seen_one=%b seen_zero=%b)", seen_one, seen_zero);
        end else $display("    -> image A toggles OK");

        // ============================================================
        // BLANK-before-write (C03 §3 red-line): zero the configured points
        // ============================================================
        cfg_write(16'h0000, 32'h00000000);   // eLUT4[0] = 0 (tt=0, ff off)
        cfg_write(16'h0008, 32'h00000000);   // IIB mux0 = 0
        cfg_write(16'h0009, 32'h00000000);   // mux1 = 0
        cfg_write(16'h000A, 32'h00000000);   // mux2 = 0
        cfg_write(16'h000B, 32'h00000000);   // mux3 = 0

        // ============================================================
        // IMAGE B: constant-1 on tile(0,0) eLUT4[0] -> clb_out_obs[0] = 1
        // ============================================================
        cfg_write(16'h0000, 32'h000FFFFE);   // tt=0xFFFF, ff_en=1, ff_rst_en=1, ff_rst_val=1
        cfg_write(16'h0008, 32'h00000012);   // mux0..3 = 18 (re-set after blank; self-contained)
        cfg_write(16'h0009, 32'h00000012);
        cfg_write(16'h000A, 32'h00000012);
        cfg_write(16'h000B, 32'h00000012);

        do_reset();                          // clb_out[0] -> 1 (ff_rst_val=1)

        // run B: observe clb_out_obs[0]; expect constant 1
        $display("[B] constant-1 image — clb_out_obs[0] over cycles:");
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk);
            $display("    cyc %0d : clb_out[0] = %b", i, clb_out_obs[0]);
            if (clb_out_obs[0] !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: image B clb_out[0] /= 1 at cyc %0d (got %b)", i, clb_out_obs[0]);
            end
        end
        if (errors == 0) $display("    -> image B constant-1 OK");

        // ============================================================
        // verdict
        // ============================================================
        if (errors == 0) $display("TEST PASSED: dual-image hot-swap (toggle -> blank -> const-1) on fabric_top RTL");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
