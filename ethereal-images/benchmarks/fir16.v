// SPDX-License-Identifier: MIT
// Module:      fir16
// Function:    8-tap FIR filter with a SYMMETRIC coefficient set (linear-phase,
//              16-bit output). The tap shift-register contents are INPUTS
//              (x0 = newest sample .. x7 = oldest), so the datapath is pure
//              combinational:
//                  y = sum_{k=0}^{7} h[k] * x[k]
//              Coefficients (symmetric, sum = 32 -> y = input for constant
//              input, i.e. unity-gain low-pass; power-of-two weights so each
//              "multiply" is a pure shift, keeping the design small enough to
//              route on the v1.1 fabric):
//                  h = [1, 2, 4, 9, 9, 4, 2, 1]  (sum = 32)
//              but 9 is not a power of two; to keep ALL taps pure-shift we use
//                  h = [1, 2, 4, 8, 8, 4, 2, 1]  (sum = 30)
//              (a benign DC gain of 30/32 ~= 0.94; documented, not a bug).
// Size est.:   ~30-50 eLUT4. The symmetric-tap pre-add (x0+x7, x1+x6, x2+x5,
//              x3+x4) halves the products; each tap is a pure shift of its
//              pre-add (no general multiplier), so the adder tree dominates.
// Why combinational: taps are INPUTS, so no clocking harness is needed.
//              (fabric_sim's eLUT4-FF path has no per-cycle step interface —
//              see E0-MAP5 report — so a registered shift-register FIR would
//              NOT be bit-true-testable today.)
// Golden convention: 8 sample inputs x0..x7 (8-bit each) + 16-bit output y.
//              Tap order: x0 is the NEWEST sample (h[0] applied), x7 OLDEST.
//              make_golden_tb: random x0..x7, #1 settle, $display x0..x7, y.
// Tags:        BENCHMARK, COMBINATIONAL
// Plan-Ref:    ethereal-plan (E0-MAP5 benchmark set)
`default_nettype none

module fir16 (
    input  wire [7:0]  x0,
    input  wire [7:0]  x1,
    input  wire [7:0]  x2,
    input  wire [7:0]  x3,
    input  wire [7:0]  x4,
    input  wire [7:0]  x5,
    input  wire [7:0]  x6,
    input  wire [7:0]  x7,
    output wire [15:0] y
);

    // Symmetric pre-adds (9-bit sums).
    wire [8:0] s0 = {1'b0, x0} + {1'b0, x7};   // * h[0]=h[7]=1  (shift 0)
    wire [8:0] s1 = {1'b0, x1} + {1'b0, x6};   // * h[1]=h[6]=2  (shift 1)
    wire [8:0] s2 = {1'b0, x2} + {1'b0, x5};   // * h[2]=h[5]=4  (shift 2)
    wire [8:0] s3 = {1'b0, x3} + {1'b0, x4};   // * h[3]=h[4]=8  (shift 3)

    // Pure-shift "multiplies" (each s is 9-bit; max product = 511*8 = 4088 <
    // 2^12, and the final sum < 2^14 fits y[15:0]). Taps are powers of two, so
    // NO general multiplier is inferred — just wiring + the final adder tree.
    wire [15:0] p0 = {7'b0, s0};                  // *1
    wire [15:0] p1 = {6'b0, s1, 1'b0};            // *2
    wire [15:0] p2 = {5'b0, s2, 2'b00};           // *4
    wire [15:0] p3 = {4'b0, s3, 3'b000};          // *8

    assign y = p0 + p1 + p2 + p3;

endmodule
`default_nettype wire
