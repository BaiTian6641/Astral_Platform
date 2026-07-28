`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_inf_dsp_mac
// Description: Inference-first fixed-point multiply-accumulate template (ADR-017, C13 §2.1).
// Details:     Pure behavioral signed MAC. NO vendor primitives — the platform
//              EDA (GowinSynthesis / Vivado / Yosys) INFERS this as a physical
//              DSP block (27x18 target). Fully Verilator-simulatable.
//              Coding red-lines honored (C13 §2.1): SIGNED operands; operand
//              widths <= 27x18 (single DSP); sufficient pipelining (LAT);
//              synchronous reset, RESET VALUE ONLY 0 (a set/async reset BLOCKS
//              DSP inference, UG949); no async reset anywhere.
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.1 · C02 §2
module eth_inf_dsp_mac #(
    parameter int AW  = 27,    // operand A width (<=27 for one DSP)
    parameter int BW  = 18,    // operand B width (<=18 for one DSP)
    parameter int LAT = 3      // pipeline latency (input-reg -> mult -> out)
) (
    input  logic              clk_i,
    input  logic              rst_ni,     // synchronous reset (reset value = 0 ONLY)
    input  logic              en_i,       // clock-enable
    input  logic signed [AW-1:0] a_i,
    input  logic signed [BW-1:0] b_i,
    input  logic signed [47:0]   c_i,     // addend / cascade-in
    input  logic                 acc_i,   // 1 = accumulate (p += a*b); 0 = a*b + c
    output logic signed [47:0]   p_o
);
`include "eth_config.svh"
    `ETH_DSPSTYLE
    // Stage 1: input registers (synchronous reset to 0; enable).
    logic signed [AW-1:0] a_r;
    logic signed [BW-1:0] b_r;
    logic signed [47:0]   c_r;
    logic                 acc_r;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            a_r <= '0; b_r <= '0; c_r <= '0; acc_r <= 1'b0;
        end else if (en_i) begin
            a_r <= a_i; b_r <= b_i; c_r <= c_i; acc_r <= acc_i;
        end
    end

    // Stage 2: multiply (registered). signed * signed -> signed (2x width, fits 48).
    // Skipped entirely when LAT < 2 (combinational a_r*b_r feeds stage 3).
    logic signed [47:0] mult_s;          // product into stage 3
    logic signed [47:0] c_s;             // c into stage 3
    logic               acc_s;           // acc into stage 3
    if (LAT >= 2) begin : g_mult_reg
        logic signed [47:0] mult_r;
        logic signed [47:0] c_r2;
        logic               acc_r2;
        always_ff @(posedge clk_i) begin
            if (!rst_ni) begin
                mult_r <= '0; c_r2 <= '0; acc_r2 <= 1'b0;
            end else if (en_i) begin
                mult_r <= a_r * b_r;      // DSP multiplier inference point
                c_r2   <= c_r;
                acc_r2 <= acc_r;
            end
        end
        assign mult_s = mult_r; assign c_s = c_r2; assign acc_s = acc_r2;
    end else begin : g_mult_comb
        assign mult_s = a_r * b_r; assign c_s = c_r; assign acc_s = acc_r;
    end

    // Stage 3: accumulate / add (registered when LAT >= 3; else combinational).
    if (LAT >= 3) begin : g_out_reg
        logic signed [47:0] p_r;
        always_ff @(posedge clk_i) begin
            if (!rst_ni) begin
                p_r <= '0;
            end else if (en_i) begin
                p_r <= acc_s ? (p_r + mult_s) : (mult_s + c_s);  // DSP accumulator/add
            end
        end
        assign p_o = p_r;
    end else begin : g_out_comb
        assign p_o = acc_s ? (mult_s + c_s) : (mult_s + c_s);
    end
endmodule

`default_nettype wire
