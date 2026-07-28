// SPDX-License-Identifier: MIT
// Module:      fir16_dsp
// Function:    16-tap FIR filter with REAL multiplier taps (general coefficients),
//              Verilog-2005 style. This is the C02 §2.6 heterogeneous benchmark:
//              the DSP cascade (acc chain) infers 16x $macc_v2 (dsp_t), vs the
//              E0-MAP5 shift-based fir16.v (power-of-2 taps, 124 eLUT, congested
//              the v1.1 fabric). C02 §2.4: FIR16 = 16 DSP-T in cascade (the
//              physical-DSP MAC chain eliminates the adder-tree entirely).
// Interface:   taps + coefficients are flattened bus ports (combinational inputs
//              for v1, so no clocking harness / sequential state is needed).
// Size est.:   16 $macc_v2 (dsp_t) + 0 eLUT4 datapath (pure DSP cascade).
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §2.4 §2.6
module fir16_dsp (
  input  clk,
  input  [127:0] x,          // 16 taps x 8-bit:  x[8*k +: 8]  = tap k
  input  [255:0] h,          // 16 coeffs x 16-bit: h[16*k +: 16] = coeff k
  output reg signed [47:0] y
);
  function signed [7:0]  tap (input [127:0] v, input integer k); tap  = v[8*k +: 8];  endfunction
  function signed [15:0] coef(input [255:0] v, input integer k); coef = v[16*k +: 16]; endfunction
  reg signed [47:0] acc [0:15];
  integer k;
  always @(posedge clk) begin
    acc[0] <= $signed(tap(x, 0)) * $signed(coef(h, 0));
    for (k = 1; k < 16; k = k + 1)
      acc[k] <= acc[k-1] + $signed(tap(x, k)) * $signed(coef(h, k));
    y <= acc[15];
  end
endmodule
