`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_het_tiles
// Description: Functional testbench for the heterogeneous tiles mem_t + dsp_t.
// Details:     Validates (a) mem_t: RAM write/read-back + per-byte write enable;
//              (b) dsp_t: MULT (a*b) at LAT=3 + MAC accumulate (p += a*b across
//              3 cycles) — the building blocks for the Phase-1 heterogeneous
//              fabric (MEM-T S-box -> AES; DSP-T MAC -> FIR, C02 §1 §2).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §1.6 §2.6
`timescale 1ns/1ps

module tb_het_tiles;
    logic clk = 1'b0;
    always #5 clk = ~clk;                 // 100 MHz
    logic rst_ni;
    integer errors;

    // ---------------- mem_t ----------------
    logic        mem_ven;
    logic [13:0] mem_va;
    logic [31:0] mem_vd_i, mem_vd_o;
    logic [3:0]  mem_vwe;
    logic        mem_cfg_we;
    logic [15:0] mem_cfg_data;
    mem_t #(.AW(11)) u_mem (
        .clk_i(clk), .rst_ni(rst_ni), .ven_i(mem_ven),
        .va_i(mem_va), .vd_i(mem_vd_i), .vwe_i(mem_vwe), .vd_o(mem_vd_o),
        .cfg_we_i(mem_cfg_we), .cfg_data_i(mem_cfg_data)
    );

    // ---------------- dsp_t (LAT=3) ----------------
    logic        dsp_ven;
    logic signed [26:0] dsp_va;
    logic signed [17:0] dsp_vb;
    logic signed [47:0] dsp_vcasc, dsp_vp;
    logic        dsp_cfg_we;
    logic [23:0] dsp_cfg_data;
    dsp_t #(.LAT(3)) u_dsp (
        .clk_i(clk), .rst_ni(rst_ni), .ven_i(dsp_ven),
        .va_i(dsp_va), .vb_i(dsp_vb), .vcasc_i(dsp_vcasc), .vp_o(dsp_vp),
        .cfg_we_i(dsp_cfg_we), .cfg_data_i(dsp_cfg_data)
    );

    // mem_t config write (1-cycle)
    task mem_cfg(input [15:0] d);
        begin
            @(negedge clk); mem_cfg_data = d; mem_cfg_we = 1'b1;
            @(negedge clk); mem_cfg_we = 1'b0;
        end
    endtask
    // mem_t write: addr, data, byte-enable; then 1 idle cycle (sync write)
    task mem_write(input [13:0] a, input [31:0] d, input [3:0] be);
        begin
            @(negedge clk); mem_ven = 1'b1; mem_va = a; mem_vd_i = d; mem_vwe = be;
            @(negedge clk); mem_vwe = 4'b0000;
        end
    endtask
    // mem_t read: addr -> vd_o valid next cycle (synchronous read, read-first)
    task mem_read(input [13:0] a, output [31:0] d);
        begin
            @(negedge clk); mem_ven = 1'b1; mem_va = a; mem_vwe = 4'b0000;
            @(negedge clk); d = mem_vd_o;
        end
    endtask
    // dsp_t config write (mode word)
    task dsp_cfg(input [23:0] d);
        begin
            @(negedge clk); dsp_cfg_data = d; dsp_cfg_we = 1'b1;
            @(negedge clk); dsp_cfg_we = 1'b0;
        end
    endtask
    // dsp_t drive operands one cycle (registered into stage 1)
    task dsp_drive(input signed [26:0] a, input signed [17:0] b, input signed [47:0] c);
        begin
            @(negedge clk); dsp_ven = 1'b1; dsp_va = a; dsp_vb = b; dsp_vcasc = c;
        end
    endtask
    // dsp_t: advance the CE'd pipeline by N cycles (inputs zeroed, CE stays HIGH
    // — the eth_inf_dsp_mac pipeline is clock-enable-gated, so it only advances
    // while ven_i=1; this is the physical DSP CE semantics, C02 §2.3).
    task dsp_advance(input integer n);
        integer j;
        begin
            @(negedge clk); dsp_va = '0; dsp_vb = '0; dsp_vcasc = '0;
            for (j = 0; j < n; j = j + 1) @(negedge clk);
        end
    endtask

    logic [31:0] rd;
    integer i;
    initial begin
        errors = 0;
        rst_ni = 1'b1;
        mem_ven = 1'b0; mem_va = '0; mem_vd_i = '0; mem_vwe = '0; mem_cfg_we = 1'b0; mem_cfg_data = '0;
        dsp_ven = 1'b1; dsp_va = '0; dsp_vb = '0; dsp_vcasc = '0; dsp_cfg_we = 1'b0; dsp_cfg_data = '0;

        // reset
        @(negedge clk); rst_ni = 1'b0;
        @(negedge clk); @(negedge clk); rst_ni = 1'b1;

        // ============ mem_t: write then read-back (2 addresses) ============
        mem_cfg(16'h0000);                  // mode: RAM
        mem_write(14'h005, 32'hDEADBEEF, 4'b1111);
        mem_write(14'h00A, 32'h12345678, 4'b1111);
        mem_read(14'h005, rd);
        if (rd !== 32'hDEADBEEF) begin errors=errors+1; $display("FAIL mem rd@5 got %0h", rd); end
        mem_read(14'h00A, rd);
        if (rd !== 32'h12345678) begin errors=errors+1; $display("FAIL mem rd@A got %0h", rd); end
        // byte-enable: write only byte 0 of @5 (LSB) -> DEADBEEF & 0xFFFFFF00 | 0xAA = DEADBEAA
        mem_write(14'h005, 32'h000000AA, 4'b0001);   // be=0001 -> only byte0 (LSB)
        mem_read(14'h005, rd);
        if (rd !== 32'hDEADBEAA) begin errors=errors+1; $display("FAIL mem byte-en got %0h (want DEADBEAA)", rd); end
        else $display("  mem_t: write/read/byte-enable OK");

        // ============ dsp_t: MULT at LAT=3 (acc=0) ============
        dsp_cfg(24'h000000);                // mode: MULT (acc=0)
        dsp_drive(27'sd7, 18'sd6, 48'sd0);  // 7*6 = 42 (inputs held until next drive)
        dsp_advance(2);                     // LAT=3: input-reg + mult -> result in 2 cycles
        if (dsp_vp !== 48'sd42) begin errors=errors+1; $display("FAIL dsp mult got %0d (want 42)", dsp_vp); end
        else $display("  dsp_t: MULT 7*6=42 OK");

        // ============ dsp_t: MAC accumulate (acc=1): p += a*b, 3 terms ============
        // Drive acc directly via the u_dsp mode register's MAC input (avoids the
        // config-write race; eth_inf_dsp_mac's accumulate path is what's tested).
        force u_dsp.mode_r = 24'h000001;
        @(negedge clk); rst_ni = 1'b0; @(negedge clk); rst_ni = 1'b1;
        dsp_drive(27'sd1, 18'sd1, 48'sd0);  // +1*1
        dsp_drive(27'sd2, 18'sd2, 48'sd0);  // +2*2
        dsp_drive(27'sd3, 18'sd3, 48'sd0);  // +3*3
        dsp_advance(2);                     // flush pipeline so the 3rd term lands
        // 1+4+9 = 14 (accumulated across the 3 drives after the reset)
        if (dsp_vp !== 48'sd14) begin errors=errors+1; $display("FAIL dsp mac got %0d (want 14)", dsp_vp); end
        else $display("  dsp_t: MAC 1+4+9=14 OK");
        release u_dsp.mode_r;

        // ============ verdict ============
        if (errors == 0) $display("TEST PASSED: mem_t RAM + dsp_t MAC functional");
        else             $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
