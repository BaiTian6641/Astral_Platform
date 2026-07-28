`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_inf_dsp_mac
// Description: Inference-first fixed-point multiply-accumulate template (ADR-017, C13 §2.1).
// Details:     Pure behavioral signed MAC. NO vendor primitives — the platform
//              EDA (GowinSynthesis / Vivado / Yosys) INFERS this as a physical
//              DSP block (27x18 target). Fully Verilator-simulatable.
//              Coding red-lines honored (C13 §2.1): SIGNED operands; operand
//              widths <= 27x18 (single DSP); sufficient pipelining (always 3
//              stages built — required for DSP inference); synchronous reset,
//              RESET VALUE ONLY 0 (a set/async reset BLOCKS DSP inference,
//              UG949); no async reset anywhere.
//              The full 3-stage pipeline is ALWAYS built (good DSP inference);
//              `lat_sel_i` taps the OUTPUT at stage 0/1/2/3 (runtime latency,
//              C02 §2.3 — frequency-vs-latency is image-selectable).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Modified:    2026-07-28 - runtime-latency output tap (was build-time LAT param)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.1 · C02 §2
module eth_inf_dsp_mac #(
    parameter int AW = 27,     // operand A width (<=27 for one DSP)
    parameter int BW = 18      // operand B width (<=18 for one DSP)
) (
    input  logic              clk_i,
    input  logic              rst_ni,     // synchronous reset (reset value = 0 ONLY)
    input  logic              en_i,       // clock-enable
    input  logic signed [AW-1:0] a_i,
    input  logic signed [BW-1:0] b_i,
    input  logic signed [47:0]   c_i,     // addend / cascade-in
    input  logic                 acc_i,   // 1 = accumulate (p += a*b); 0 = a*b + c
    input  logic [1:0]           lat_sel_i, // output latency tap: 0/1/2/3 stages
    output logic signed [47:0]   p_o
);
`include "eth_config.svh"
    `ETH_DSPSTYLE
    // Stage 1: input registers (sync reset to 0; enable).
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

    // Stage 2: multiply (registered). signed*signed -> signed (fits 48). DSP inference point.
    logic signed [47:0] mult_r;
    logic signed [47:0] c_r2;
    logic               acc_r2;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mult_r <= '0; c_r2 <= '0; acc_r2 <= 1'b0;
        end else if (en_i) begin
            mult_r <= a_r * b_r;
            c_r2   <= c_r;
            acc_r2 <= acc_r;
        end
    end

    // Stage 3: accumulate / add (registered, reset-to-0 only). DSP accumulator/add.
    logic signed [47:0] p_r;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            p_r <= '0;
        end else if (en_i) begin
            p_r <= acc_r2 ? (p_r + mult_r) : (mult_r + c_r2);
        end
    end

    // Output latency tap (runtime, C02 §2.3). Only lat_sel=3 (p_r) accumulates
    // (p_r is the accumulator register); lat 0/1/2 are non-accumulating views:
    //   0 -> combinational a*b + c (bypass); 1 -> mult-stage product; 2/3 -> p_r.
    logic signed [47:0] p0, p1, p2, p3;
    assign p0 = a_i * b_i + c_i;   // bypass (non-registered)
    assign p1 = mult_r + c_r2;     // mult-stage (acc ignored)
    assign p2 = p_r;               // out-stage
    assign p3 = p_r;               // out-stage (full LAT 3)
    always_comb begin
        case (lat_sel_i)
            2'd0:    p_o = p0;
            2'd1:    p_o = p1;
            2'd2:    p_o = p2;
            default: p_o = p3;
        endcase
    end
endmodule

`default_nettype wire
