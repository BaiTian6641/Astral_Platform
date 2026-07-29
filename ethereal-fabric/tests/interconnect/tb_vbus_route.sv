`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_vbus_route
// Description: vbus->routing integration TB (Stage 5b+, Phase-1).
// Details:     Proves the heterogeneous tile's wide datapath connects to the
//              virtual routing (SB inject + CB) in BOTH directions, using a
//              self-contained 1x2 fabric (tile0=MEM_T + its own CLB, tile1=CLB).
//              A MEM_T tile carries its own CLB-T (C02 §5), so each loop closes
//              on tile0 itself — no neighbour hop needed.
//
//              TEST A — vbus-OUT (tile output -> routing -> CLB):
//                MEM@tile0 reads mem[5]=0xCAFEBABE (vd_o[3:0]=1110). vbus_out_sel=1
//                routes vd_o[3:0] to the SB inject (out_e[3:0]); the CB feeds those
//                tracks to the tile0 CLB's clb_in[3:0]; 4 eLUTs buffer them. Assert
//                clb_obs[3:0] == vd_o[3:0] (== 4'b1110). Proves each of the 4 bits
//                routes independently through SB inject + CB.
//
//              TEST B — vbus-IN (CLB -> routing -> tile operand):
//                The tile0 CLB emits a constant pattern clb_out[3:0]=4'b0101 (==5)
//                via LUT truth tables. vbus_out_sel=0 (CLB drives inject) -> SB ->
//                CB -> clb_in[7:0]=00000101. vbus_in_sel=1 routes clb_in[7:0] to
//                the MEM va_i[7:0] operand (mem_va_r forced to 0 meanwhile). Assert
//                the MEM reads addr 5 (== 0xCAFEBABE), NOT addr 0 (== 0x11111111) —
//                so the address genuinely came from routing, not the register.
//
//              Bandwidth limit (documented): at W=12 only N=8 operand/inject bits
//              flow per direction per cycle; full 32-bit mem datapath needs W>=32.
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §1.2 §2.2 · Stage 5b+
// Notes:       cfg layout (1x2, TIW=1): cfg_addr = {tile_idx[8], unit[7:6], intra[5:0]}.
//   unit 2'b00=CLB, 2'b01=SB, 2'b10=CB, 2'b11=TILE-MODE/vbus. tile0=MEM_T, tile1=CLB.
//   SB (W=12): cfg_addr 0..47 = Wilton sel; 48..55 = inject[en@0, dir@2:1] (0=N,1=S,2=E,3=W).
//   CB (W=12): cfg_addr 0..17 = clb_in idx; data = track idx (pool {out_w,out_e,out_s,out_n},
//              out_n@[0..11], out_s@[12..23], out_e@[24..35], out_w@[36..47]).
//   eLUT4 cfg_data[19:0]: [19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv.
//   CLB IIB cfg_addr: 0..7=eLUT#; 8..39=mux# (8+gi*K+gk), data[4:0]=pool idx (clb_in@[0..17]).
`timescale 1ns/1ps

module tb_vbus_route;
    localparam int R = 1, C = 2, N = 8;
    // TILE_TYPE: tile0=MEM_T(1), tile1=CLB(0). LSB-first entries.
    localparam logic [R*C*8-1:0] TT = {8'd0, 8'd1};

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

    // cfg write helper: (tile_idx, unit, intra, data). TIW=1 -> tile at bit [8].
    task cw(input int t, input int u, input int a, input [31:0] d);
        begin
            @(negedge clk);
            cfg_addr = (t << 8) | (u << 6) | a;
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
        //      the SB inject + vbus-ctrl registers drive operands. Reset-free
        //      config regs (like SB/CB sel_r) -> this TB writes the defaults.
        cw(0, 2'b11, 6, 32'h0);   // tile0 (MEM) vbus_out_sel = 0 (CLB inject)
        cw(0, 2'b11, 7, 32'h0);   // tile0 (MEM) vbus_in_sel  = 0 (register operands)

        // ================================================================
        // Preload MEM: mem[0]=0x00000000, mem[5]=0xCAFEBABE (register-driven
        // vbus-ctrl; vbus_in_sel defaults to 0 = registers).
        // vbus-ctrl word A: va_i[13:0]@[13:0], ven_i@[16], vwe_i[3:0]@[21:18].
        // SAFE sequence: disable the write (vwe=0) BEFORE changing vd_i/address,
        // so loading a new vd_i does not spuriously overwrite the prior address.
        // ================================================================
        // write mem[0]=0: enable write @0, then load vd_i=0, settle, stop write.
        cw(0, 2'b11, 1, (4'b1111 << 18) | (1 << 16) | 14'h0000);         // va=0,ven=1,vwe=F
        cw(0, 2'b11, 2, 32'h00000000);                                   // vd_i=0 (writes mem[0])
        @(negedge clk); @(negedge clk);                                  // sync write
        cw(0, 2'b11, 1, (4'b0000 << 18) | (1 << 16) | 14'h0000);         // va=0,ven=1,vwe=0 (stop write)
        // write mem[5]=0xCAFEBABE: addr already moved to 5 before vd_i changes,
        // so the transient vd_i write lands at addr 5 (final value = CAFEBABE).
        cw(0, 2'b11, 1, (4'b1111 << 18) | (1 << 16) | 14'h0005);         // va=5,ven=1,vwe=F
        cw(0, 2'b11, 2, 32'hCAFEBABE);                                   // vd_i=CAFEBABE (writes mem[5])
        @(negedge clk); @(negedge clk);                                  // sync write
        cw(0, 2'b11, 1, (4'b0000 << 18) | (1 << 16) | 14'h0005);         // park read @5 (vwe=0)
        @(negedge clk); @(negedge clk);                                  // sync read latency
        if (mem_obs[31:0] !== 32'hCAFEBABE) begin
            errors = errors + 1;
            $display("FAIL: preload read mem[5] got %0h (want CAFEBABE)", mem_obs[31:0]);
        end

        // ================================================================
        // TEST A — vbus-OUT: MEM vd_o[3:0] -> SB inject -> CB -> CLB buffer
        // ================================================================
        // tile0 CLB: 4 eLUTs as combinational buffers (clb_out[k]=clb_in[k]).
        //   tt=0xAAAA -> out=i0; ff_en=0. cfg_data[19:0]=0xAAAA0.
        //   NOTE: a LUT4 is indexed by ALL 4 inputs -> if any input bit is X the
        //   read is X. So wire all 4 inputs of eLUT[k] to pool[k]=clb_in[k]; then
        //   the index is {clb_in[k]}x4 (fully defined once the CB drives it) and
        //   tt=0xAAAA still yields out=clb_in[k] (tt[0]=0, tt[15]=1).
        cw(0, 2'b00, 0, 32'h000AAAA0);
        cw(0, 2'b00, 1, 32'h000AAAA0);
        cw(0, 2'b00, 2, 32'h000AAAA0);
        cw(0, 2'b00, 3, 32'h000AAAA0);
        // IIB: eLUT[k] inputs 0..3 all <- pool[k]=clb_in[k]. cfg_addr=8+4k+gk, data=k.
        cw(0, 2'b00, 8,  32'd0); cw(0, 2'b00, 9,  32'd0); cw(0, 2'b00, 10, 32'd0); cw(0, 2'b00, 11, 32'd0);
        cw(0, 2'b00, 12, 32'd1); cw(0, 2'b00, 13, 32'd1); cw(0, 2'b00, 14, 32'd1); cw(0, 2'b00, 15, 32'd1);
        cw(0, 2'b00, 16, 32'd2); cw(0, 2'b00, 17, 32'd2); cw(0, 2'b00, 18, 32'd2); cw(0, 2'b00, 19, 32'd2);
        cw(0, 2'b00, 20, 32'd3); cw(0, 2'b00, 21, 32'd3); cw(0, 2'b00, 22, 32'd3); cw(0, 2'b00, 23, 32'd3);
        // vbus-OUT select: MEM vd_o low bits drive the SB inject.
        cw(0, 2'b11, 6, 32'h1);              // vbus_out_sel = 1
        // SB inject: clb_out_for_sb[0..3] -> out_e[0..3] (dir=E=2 -> data[2:0]=101=5).
        cw(0, 2'b01, 48, 32'd5);
        cw(0, 2'b01, 49, 32'd5);
        cw(0, 2'b01, 50, 32'd5);
        cw(0, 2'b01, 51, 32'd5);
        // CB: clb_in[0..3] <- out_e[0..3] (out_e pool base = 2*W = 24).
        cw(0, 2'b10, 0, 32'd24);
        cw(0, 2'b10, 1, 32'd25);
        cw(0, 2'b10, 2, 32'd26);
        cw(0, 2'b10, 3, 32'd27);
        @(negedge clk);                       // combinational path settle
        // vd_o[3:0] = 0xCAFEBABE low nibble = 0xE = 4'b1110.
        if (clb_obs[3:0] !== mem_obs[3:0]) begin
            errors = errors + 1;
            $display("FAIL [vbus-OUT]: clb_obs[3:0]=%b != mem vd_o[3:0]=%b", clb_obs[3:0], mem_obs[3:0]);
        end else if (clb_obs[3:0] !== 4'b1110) begin
            errors = errors + 1;
            $display("FAIL [vbus-OUT]: clb_obs[3:0]=%b != expected 1110", clb_obs[3:0]);
        end else begin
            $display("  [vbus-OUT] MEM vd_o[3:0]=%b -> SB inject -> CB -> CLB buffer OK", mem_obs[3:0]);
        end

        // ================================================================
        // TEST B — vbus-IN: CLB constant pattern -> routing -> MEM va_i operand
        // ================================================================
        // Drive a FULL-BYTE constant clb_out[7:0]=8'b00000101 (=5) via the eLUT
        // virtual FFs held in reset (ff_en=1, ff_rst_en=1, ff_rst_val=bit). A pure-
        // combinational constant (tt=0xFFFF) still reads X because the LUT4 index
        // carries X bits from the routing/feedback loop; the reset-held FF forces a
        // defined value independent of inputs. eLUT0/2=const1, eLUT1/3..7=const0.
        //   cfg_data[19:0]: [19:4]=tt(0),[3]=ff_en=1,[2]=ff_rst_en=1,[1]=ff_rst_val,[0]=0
        //   const1 = 0x0000E, const0 = 0x0000C.
        cw(0, 2'b00, 0, 32'h0000000E);       // eLUT0 -> const 1
        cw(0, 2'b00, 1, 32'h0000000C);       // eLUT1 -> const 0
        cw(0, 2'b00, 2, 32'h0000000E);       // eLUT2 -> const 1
        cw(0, 2'b00, 3, 32'h0000000C);       // eLUT3 -> const 0
        cw(0, 2'b00, 4, 32'h0000000C);       // eLUT4 -> const 0
        cw(0, 2'b00, 5, 32'h0000000C);       // eLUT5 -> const 0
        cw(0, 2'b00, 6, 32'h0000000C);       // eLUT6 -> const 0
        cw(0, 2'b00, 7, 32'h0000000C);       // eLUT7 -> const 0
        // Hold user reset so the eLUT FFs stay at their reset values (constants).
        // Config regs + the RAM (no reset) are unaffected -> MEM keeps reading.
        @(negedge clk); rst_ni = 1'b0;
        @(negedge clk);
        // Inject ALL 8 constant bits onto out_e[0..7] (inj_en=1, dir=E=2 -> data 5).
        cw(0, 2'b01, 48, 32'd5); cw(0, 2'b01, 49, 32'd5);
        cw(0, 2'b01, 50, 32'd5); cw(0, 2'b01, 51, 32'd5);
        cw(0, 2'b01, 52, 32'd5); cw(0, 2'b01, 53, 32'd5);
        cw(0, 2'b01, 54, 32'd5); cw(0, 2'b01, 55, 32'd5);
        // CB: clb_in[0..7] <- out_e[0..7] (out_e pool base = 2*W = 24). No track
        // depends on an unconfigured SB Wilton select (all 8 sourced from inject).
        cw(0, 2'b10, 0, 32'd24); cw(0, 2'b10, 1, 32'd25);
        cw(0, 2'b10, 2, 32'd26); cw(0, 2'b10, 3, 32'd27);
        cw(0, 2'b10, 4, 32'd28); cw(0, 2'b10, 5, 32'd29);
        cw(0, 2'b10, 6, 32'd30); cw(0, 2'b10, 7, 32'd31);
        // Force register va=0 (so register-driven path would read addr 0, NOT 5).
        cw(0, 2'b11, 1, (4'b0000 << 18) | (1 << 16) | 14'h0000);   // va_r=0, ven=1, vwe=0
        // vbus-OUT: CLB drives inject (clb_out=00000101 -> out_e -> CB -> clb_in=5).
        cw(0, 2'b11, 6, 32'h0);              // vbus_out_sel = 0 (CLB drives inject)
        // vbus-IN: route clb_in[7:0] to va_i[7:0] -> va_i = 00000101 = 5.
        cw(0, 2'b11, 7, 32'h1);              // vbus_in_sel = 1
        @(negedge clk); @(negedge clk);      // sync read latency (va_i=5 now)
        if (mem_obs[31:0] === 32'hCAFEBABE) begin
            $display("  [vbus-IN] CLB pattern 00000101 -> routing -> MEM va_i=5 -> read CAFEBABE OK");
        end else begin
            errors = errors + 1;
            $display("FAIL [vbus-IN]: mem read %0h (want CAFEBABE from addr 5 driven by routing)", mem_obs[31:0]);
        end
        // Sanity: switching vbus_in_sel back to 0 (register va=0) must read addr 0
        // (== 0x00000000), proving the address genuinely came from routing above.
        cw(0, 2'b11, 7, 32'h0);              // vbus_in_sel = 0 (register-driven va=0)
        @(negedge clk); @(negedge clk);
        if (mem_obs[31:0] !== 32'h00000000) begin
            errors = errors + 1;
            $display("FAIL [vbus-IN sanity]: register-driven va=0 read %0h (want 00000000)", mem_obs[31:0]);
        end else begin
            $display("  [vbus-IN sanity] vbus_in_sel=0 -> register va=0 -> read 00000000 OK");
        end

        // ================================================================
        if (errors == 0) $display("TEST PASSED: vbus->routing integration (MEM vd_o->SB->CB->CLB + CLB->routing->MEM va_i)");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
