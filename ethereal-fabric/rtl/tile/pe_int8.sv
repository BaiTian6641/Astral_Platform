`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      pe_int8
// Description: INT8 processing element of the NPU-Tiny 8x8 weight-stationary
//              systolic array (activation passes RIGHT, partial sum passes DOWN).
// Details:     Per PE: INT8 x INT8 -> INT16 exact product, added to the partial
//              sum arriving from the PE above and latched into a 32-bit
//              accumulator. The activation is registered on its way to the right
//              neighbour (1 cycle/column skew); the accumulator is registered on
//              its way down (1 cycle/row skew). Full adder is behavioral, no
//              vendor primitive (ADR-017) — the EDA infers the multiplier.
//              Arithmetic contract (see docs/reports/report-E3-SVC1-*.md §4):
//                product = signed(a_i) * signed(w_r)            exact, 16-bit
//                acc_nxt = sat_i32(acc_in + product)              SATURATING
//              Saturation is applied at EVERY accumulate step (each PE add),
//              not only at the end: an accumulation that exceeds +2^31-1 pins to
//              0x7FFFFFFF (and -2^31 for the negative rail) and raises the
//              sticky per-PE ovf flag. The same rule is mirrored by the Python
//              golden model (tests/npu/npu_model.py, sat_add_i32).
//              ASSUMPTION (2026-09-13): the plan S11/C11 fixes neither wrap nor
//              saturation for the 32-bit accumulator; this tile SATURATES per
//              step (TFLite/gemmlowp lineage). Hardware-verified on both rails by
//              tb_npu_sat.sv. (TBD, 2026-09-13 — maintainer confirmation.)
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S11-Service-Tile.md §2.2 ·
//              ethereal-plan/components/C11-NPU-Tiny组件.md §1.2 §1.3
// Notes:       LEAK_INJECT is a VERIFICATION-ONLY negative-control hook (default
//              0 = production behaviour, logic optimises away): with 1'b1 the
//              session clear skips the accumulator/weight registers so the
//              isolation TB can prove its no-leak assertions are able to fail.
module pe_int8 #(
    parameter bit LEAK_INJECT = 1'b0
) (
    input  logic               clk_i,
    input  logic               rst_ni,      // synchronous reset, reset value 0 only
    input  logic               clr_i,       // session clear (blank, 1 cycle)
    input  logic               en_i,        // MAC/clock enable (RUN + DRAIN)
    input  logic               w_load_i,    // latch w_i into the weight register
    input  logic signed [7:0]  w_i,         // weight bus (row broadcast)
    input  logic signed [7:0]  a_i,         // activation in (from the left / row bus)
    input  logic signed [31:0] psum_i,      // partial sum in (from the PE above)
    output logic signed [7:0]  a_o,         // activation out (to the right, registered)
    output logic signed [31:0] psum_o,      // partial sum out (down, registered)
    output logic signed [7:0]  w_o,         // weight register observability (no logic)
    output logic               ovf_o        // sticky saturate flag (cleared by clr_i)
);
    logic signed [7:0]  a_r;
    logic signed [7:0]  w_r;
    logic signed [31:0] acc_r;
    logic               ovf_r;

    // Exact INT8 x INT8 product. `ETH_DSPSTYLE (C13 §2.1 / ADR-017) is the only
    // vendor-specific hook and only ever *asks* the platform EDA to use a DSP —
    // no vendor primitive appears anywhere in this file.
`include "eth_config.svh"
    `ETH_DSPSTYLE
    logic signed [15:0] prod_16;
    logic signed [16:0] prod_17;
    logic signed [32:0] sum_33;
    logic signed [31:0] acc_nxt;
    logic               sat_hi;
    logic               sat_lo;

    assign prod_16 = a_i * w_r;

    // Saturation at every accumulate step (33-bit signed add, then rails).
    always_comb begin
        prod_17 = {prod_16[15], prod_16};
        sum_33  = {{1{psum_i[31]}}, psum_i} + {{16{prod_17[16]}}, prod_17};
        sat_hi  = (sum_33 > 33'sd2147483647);
        sat_lo  = (sum_33 < -33'sd2147483648);
        acc_nxt = sat_hi ? 32'sh7FFFFFFF : (sat_lo ? 32'sh80000000 : sum_33[31:0]);
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            a_r   <= 8'sd0;
            w_r   <= 8'sd0;
            acc_r <= 32'sd0;
            ovf_r <= 1'b0;
        end else if (clr_i) begin
            // Session clear: the PE is part of the session state and MUST blank
            // (no cross-container residue). LEAK_INJECT=1 skips acc/w_r on purpose.
            a_r   <= 8'sd0;
            ovf_r <= 1'b0;
            if (!LEAK_INJECT) begin
                w_r   <= 8'sd0;
                acc_r <= 32'sd0;
            end
        end else begin
            if (w_load_i) begin
                w_r <= w_i;
            end
            if (en_i) begin
                a_r   <= a_i;
                acc_r <= acc_nxt;
                ovf_r <= ovf_r | sat_hi | sat_lo;
            end
        end
    end

    assign a_o    = a_r;
    assign psum_o = acc_r;
    assign w_o    = w_r;
    assign ovf_o  = ovf_r;
endmodule

`default_nettype wire
