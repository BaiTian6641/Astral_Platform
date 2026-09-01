`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      gowin_dsp
// Description: GW5 host-mapping glue for the inference-first 27x18 signed MAC
//              template (ADR-017, C13 §2.1). SAME port interface as
//              eth_inf_dsp_mac: this is the ONLY module allowed to name Gowin
//              DSP primitives, exclusively inside the `ifdef GOWIN_PRIMITIVE
//              branch, which is OFF by default.
// Details:     Build modes (identical discipline to gowin_bsram):
//                DEFAULT: behavioral fallback instantiating eth_inf_dsp_mac —
//                  yosys synth_gowin / GowinSynthesis infer it onto the GW5A
//                  DSP blocks (C13 §1: SUG550E §4.3 device-independent DSP
//                  inference with register absorption); Verilator simulates it.
//                GOWIN_PRIMITIVE (Gowin-EDA only, -DGOWIN_PRIMITIVE):
//                  maps the interface onto GW5A DSP primitives as
//                  documentation-in-code.
//              27x18 MAC mapping notes (GW5A DSP, 45-bit accumulator class):
//                - a_i[26:0] x b_i[17:0] signed multiply   -> MULT27X18
//                  (one DSP slice, input/register absorption ON);
//                - acc_i ? (p += a*b) : (a*b + c) with a 48-bit view
//                  -> MULT27X18 feeding ALU54D (54-bit ALU/accumulator
//                     companion primitive) or the fused MULTADDALU class;
//                - the template's 3-stage pipeline (input regs, mult reg,
//                  out reg) maps to the DSP internal pipeline registers —
//                  EXACTLY why C13 §2.1 red-lines forbid set/async reset
//                  (Gowin DSP registers support sync reset-to-0 only).
// Maintainer:  BaiTian6641
// Created:     2026-09-01
// Tags:        RTL, SYNTH | HAL-GLUE
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.1 §4 ·
//              ethereal-plan/components/C12-平台组件.md §1
// Notes:       ASSUMPTION: MULT27X18 + ALU54D is the intended primitive pair
//              for the acc path; the exact ALU54 opcode encodings and the
//              pipeline-register enable naming must be verified against the
//              licensed GW5A primitive library before a GOWIN_PRIMITIVE build
//              (TBD, 2026-09-01). The lat_sel_i runtime output tap has NO
//              primitive equivalent (physical DSP registers are build-time
//              bypass) — a primitive build must implement the tap in fabric
//              muxes outside the DSP, or freeze LAT at build time (C02 §2.3).
module gowin_dsp #(
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

`ifdef GOWIN_PRIMITIVE
    // ------------------------------------------------------------------
    // Gowin-EDA build branch (NOT compiled by the default open chain).
    //
    // Reference instantiation shape (GW5A DSP class — G6: verify register
    // names/opcodes against the licensed primitive library; ASSUMPTION
    // (TBD, 2026-09-01)):
    //
    //   // Stage: input-registered 27x18 signed multiply -> 45-bit product
    //   MULT27X18 #(
    //       .AREG (1'b1),  // absorb template stage-1 input registers
    //       .BREG (1'b1),
    //       .PREG (1'b1)   // absorb template stage-2 product register
    //   ) u_mult (
    //       .A  (a_i), .B (b_i),
    //       .CLK (clk_i), .CE(en_i), .RESET(!rst_ni),  // sync, clear-to-0 only
    //       .P  (mult45)
    //   );
    //   // Stage: 54-bit accumulate / add (p <= acc ? p + mult : mult + c)
    //   ALU54D #(
    //       .REG_INPUT  (1'b1),
    //       .REG_OUTPUT (1'b1)   // absorb template stage-3 output register
    //   ) u_alu (
    //       .A ({{9{mult45[44]}}, mult45}),            // sign-extend product
    //       .B (acc_r ? p54 : {{6{c_r[47]}}, c_r}),    // accumulate vs addend
    //       .ALU_MODE (/* ADD opcode — TBD per primitive guide */),
    //       .CLK (clk_i), .CE(en_i), .RESET(!rst_ni),
    //       .Z  (p54)
    //   );
    //   // lat_sel_i tap: NOT representable inside the DSP (see Notes); a real
    //   // primitive build must add fabric muxes here or freeze LAT.
    //
    // Commented reference only — enabling the define today fails at elaboration / time-0 on purpose:
    initial begin
        $error("gowin_dsp: GOWIN_PRIMITIVE branch is documentation-in-code only; "
               + "vendor primitive bindings pending G6 verification (2026-09-01). "
               + "Build without -DGOWIN_PRIMITIVE (behavioral inference path).");
    end
    logic _unused_ok;
    assign _unused_ok = &{a_i, b_i, c_i, acc_i, lat_sel_i, rst_ni, en_i};
    assign p_o = '0;
`else
    // ------------------------------------------------------------------
    // DEFAULT branch — pure behavioral inference (open chain + Verilator).
    eth_inf_dsp_mac #(
        .AW (AW),
        .BW (BW)
    ) u_mac (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .en_i      (en_i),
        .a_i       (a_i),
        .b_i       (b_i),
        .c_i       (c_i),
        .acc_i     (acc_i),
        .lat_sel_i (lat_sel_i),
        .p_o       (p_o)
    );
`endif

endmodule

`default_nettype wire
