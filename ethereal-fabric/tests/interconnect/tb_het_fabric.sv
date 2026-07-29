`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_het_fabric
// Description: Heterogeneous fabric integration TB (Stage 3, Phase-1).
// Details:     2x2 fabric_top with TILE_TYPE = {CLB, CLB, DSP_T, MEM_T} (tile0=
//              MEM_T, tile1=DSP_T, tiles2-3=CLB). Validates: (1) the OCC can
//              CONFIGURE a mem_t (write RAM via vbus-ctrl) and a dsp_t (write
//              mode + operands via vbus-ctrl) through fabric_top's cfg unit 11;
//              (2) the tiles COMPUTE (mem read-back, dsp MULT) and are observable
//              on mem_vd_obs_o / dsp_vp_obs_o; (3) a CLB tile on the same fabric
//              still configures + the SB/CB interconnect is intact. Proves the
//              heterogeneous tiles sit + are OCC-configurable + observable in the
//              real fabric_top RTL. vbus v1 (config/obs plumbed; full virtual-
//              routing vbus = Stage 4-5).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §0 · Stage 3 (P1)
// Notes:       cfg layout (2x2, TIW=2): cfg_addr = {tile_idx[9:8], unit[7:6], intra[5:0]}.
//   unit 2'b11 = TILE-MODE/vbus-ctrl. tile_idx: 0=tile0(MEM_T), 1=tile1(DSP_T).
//   MEM_T intra: 0=mode, 1=vbus-ctrl(va@13:0, ven@16, vwe@21:18), 2=vd_i.
//   DSP_T intra: 0=mode, 1=va_i@26:0, 2=vb_i@17:0, 3=ven@0, 4/5=vcasc hi/lo.
`timescale 1ns/1ps

module tb_het_fabric;
    localparam int R = 2, C = 2, N = 8;
    // TILE_TYPE: tile0=MEM_T(1), tile1=DSP_T(2), tile2/3=CLB(0). LSB-first entries.
    localparam logic [R*C*8-1:0] TT = {8'd0, 8'd0, 8'd2, 8'd1};

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst_ni, cfg_we;
    logic [15:0] cfg_addr;
    logic [31:0] cfg_data;
    logic [R*C*N-1:0]  clb_obs;
    logic [R*C*32-1:0] mem_obs;
    logic [R*C*48-1:0] dsp_obs;

    fabric_top #(.R(R), .C(C), .TILE_TYPE(TT)) dut (
        .clk_i(clk), .rst_ni(rst_ni),
        .cfg_we_i(cfg_we), .cfg_addr_i(cfg_addr), .cfg_data_i(cfg_data),
        .clb_out_obs_o(clb_obs), .mem_vd_obs_o(mem_obs), .dsp_vp_obs_o(dsp_obs)
    );

    // cfg write helper: (tile_idx, unit, intra, data)
    task cw(input int t, input int u, input int a, input [31:0] d);
        begin
            @(negedge clk);
            cfg_addr = (t << 8) | (u << 6) | a;   // TIW=2 -> tile at [9:8]
            cfg_data = d; cfg_we = 1'b1;
            @(negedge clk); cfg_we = 1'b0;
        end
    endtask

    integer errors;
    initial begin
        errors = 0;
        rst_ni = 1'b1; cfg_we = 1'b0; cfg_addr = '0; cfg_data = '0;
        @(negedge clk); rst_ni = 1'b0; @(negedge clk); @(negedge clk); rst_ni = 1'b1;

        // ---- vbus->routing mux defaults (cfg unit 11 intra 6/7 = 0): CLB drives
        //      the SB inject + vbus-ctrl registers drive operands. The vbus select
        //      regs are reset-free (like SB/CB sel_r; OCC configures before run),
        //      so this TB — which stands in for the OCC — writes them explicitly.
        //      tile0=MEM_T, tile1=DSP_T.
        cw(0, 2'b11, 6, 32'h0);   // MEM vbus_out_sel = 0 (CLB inject)
        cw(0, 2'b11, 7, 32'h0);   // MEM vbus_in_sel  = 0 (register operands)
        cw(1, 2'b11, 6, 32'h0);   // DSP vbus_out_sel = 0 (CLB inject)
        cw(1, 2'b11, 7, 32'h0);   // DSP vbus_in_sel  = 0 (register operands)

        // ================================================================
        // MEM_T @ tile0 (unit 11): write RAM @5 = 0xCAFEBABE, then read back
        // vbus-ctrl word A: va_i[13:0] @ [13:0], ven_i @ [16], vwe_i[3:0] @ [21:18]
        // ================================================================
        cw(0, 2'b11, 1, (32'h0 | (4'b1111 << 18) | (1 << 16) | 14'h0005)); // va=5, ven=1, vwe=1111
        cw(0, 2'b11, 2, 32'hCAFEBABE);                                     // vd_i = data (write)
        // idle 2 cycles to let the sync RAM write land (we+both en needed on ONE cycle)
        @(negedge clk); @(negedge clk);
        // read: set va=5, ven=1, vwe=0
        cw(0, 2'b11, 1, (32'h0 | (4'b0000 << 18) | (1 << 16) | 14'h0005)); // va=5, ven=1, vwe=0
        @(negedge clk); @(negedge clk);                                    // sync read latency
        if (mem_obs[31:0] !== 32'hCAFEBABE) begin
            errors = errors + 1;
            $display("FAIL: mem_t read-back got %0h (want CAFEBABE)", mem_obs[31:0]);
        end else $display("  mem_t @ tile0: OCC config + write/read OK (CAFEBABE)");

        // ================================================================
        // DSP_T @ tile1 (unit 11): MULT 7*6=42 via mode + operand vbus-ctrl
        // ================================================================
        cw(1, 2'b11, 0, 32'h000004);   // mode: MULT (acc=0), lat_sel=2 (mult-stage)
        cw(1, 2'b11, 1, 32'd7);        // va_i = 7
        cw(1, 2'b11, 2, 32'd6);        // vb_i = 6
        cw(1, 2'b11, 4, 32'h00000000); // vcasc_i hi = 0 (else c_r2 X)
        cw(1, 2'b11, 5, 32'h00000000); // vcasc_i lo = 0
        cw(1, 2'b11, 3, 32'h000001);   // ven = 1
        // flush the reset-less MAC config (mode_r/vcasc start X; the pipeline output
        // is X until configured + a few cycles — same reset-less-config lesson).
        repeat (4) @(negedge clk);
        // tile1 (DSP_T) is at dsp_obs bits [1*48 +: 48] = [95:48]
        if (dsp_obs[95:48] !== 48'd42) begin
            errors = errors + 1;
            $display("FAIL: dsp_t MULT got %0d (want 42)", dsp_obs[95:48]);
        end else $display("  dsp_t @ tile1: OCC config + MULT 7*6=42 OK");

        // ================================================================
        // CLB tile @ tile2 (unit 00): configure eLUT4 (config decode intact on het fabric)
        // ================================================================
        cw(2, 2'b00, 0, 32'h0005555C);  // tile2 eLUT4[0]: tt=0x5555, ff_en, ff_rst_en
        cw(2, 2'b00, 8, 32'h00000012);  // tile2 IIB mux0..3 = 18 (self-contained feedback)
        cw(2, 2'b00, 9, 32'h00000012);
        cw(2, 2'b00, 10, 32'h00000012);
        cw(2, 2'b00, 11, 32'h00000012);
        @(negedge clk); rst_ni = 1'b0; @(negedge clk); rst_ni = 1'b1;
        // tile2 is index 2 -> clb_obs[2*8+0] = clb_out[0] should toggle
        @(negedge clk);
        begin
            logic t0, t1;
            t0 = clb_obs[2*8];
            @(negedge clk); t1 = clb_obs[2*8];
            if (t0 === t1) begin
                errors = errors + 1;
                $display("FAIL: CLB tile2 did not toggle (clb_out[0]=%b %b)", t0, t1);
            end else $display("  CLB tile2: config + toggle OK (interconnect intact)");
        end

        // ================================================================
        if (errors == 0) $display("TEST PASSED: heterogeneous fabric (MEM_T + DSP_T + CLB) integrates in fabric_top");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
