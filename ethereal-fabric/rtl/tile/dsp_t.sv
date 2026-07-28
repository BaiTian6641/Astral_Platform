`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      dsp_t
// Description: DSP tile — a virtual multiply-accumulate unit wrapped with a
//              config mode register (C02 §2). Sits beside CLB-T/MEM-T.
// Details:     Wraps eth_inf_dsp_mac (ADR-017: behavioral signed MAC, EDA-inferred
//              DSP). Virtual side exposes 27x18 operands + 48-bit cascade/
//              accumulate output. Config writes a 24-bit mode word selecting
//              operation (MULT/MAC) and pipeline latency. The mode word drives
//              eth_inf_dsp_mac's acc_i (MAC vs MULT) — the physical LUT cost is
//              ~zero (the DSP hard block already exists on the die).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §2 · C13 §2.1
// Notes:       mode word bitfield (frozen v1): mode_r[0]=acc (1=MAC/accumulate,
//              0=MULT a*b+c), [2:1]=pipeline LAT (0..3) — passed to the MAC's LAT
//              param only if regenerated; at runtime LAT is build-time. [23:3] reserved.
module dsp_t #(
    parameter int LAT = 3                // pipeline latency (build-time, C02 §2.3)
) (
    input  logic        clk_i,
    input  logic        rst_ni,         // synchronous reset (MAC: reset-to-0 only)
    input  logic        ven_i,          // virtual enable
    input  logic signed [26:0] va_i,    // operand A (27-bit, C02 §2.3)
    input  logic signed [17:0] vb_i,    // operand B (18-bit)
    input  logic signed [47:0] vcasc_i, // cascade-in / addend
    output logic signed [47:0] vp_o,    // product / accumulator output
    input  logic        cfg_we_i,       // config write enable (1 cycle)
    input  logic [23:0] cfg_data_i      // mode word
);
    // ---- config mode register ----
    logic [23:0] mode_r;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mode_r <= '0;               // reset to MULT (acc=0), no set
        end else if (cfg_we_i) begin
            mode_r <= cfg_data_i;
        end
    end

    // ---- behavioral MAC (eth_inf_dsp_mac: EDA-inferred DSP) ----
    eth_inf_dsp_mac #(.AW(27), .BW(18), .LAT(LAT)) u_mac (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .en_i   (ven_i),
        .a_i    (va_i),
        .b_i    (vb_i),
        .c_i    (vcasc_i),
        .acc_i  (mode_r[0]),
        .p_o    (vp_o)
    );

    // mode_r[23:1] reserved in v1; sink the unused upper bits.
    logic _unused_ok;
    assign _unused_ok = ^{mode_r[23:1]};
endmodule

`default_nettype wire
