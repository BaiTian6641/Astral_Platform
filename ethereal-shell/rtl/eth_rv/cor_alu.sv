`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_alu
// Description: RV64I integer ALU for eth_rv (add/sub/shift/compare/logic + W-forms).
// Details:     Pure combinational, no state. Two result trees are computed in
//              parallel — the 64-bit tree and the 32-bit "word" tree that the
//              RV64 *.W encodings (addw/subw/sllw/srlw/sraw/*iw) need — and
//              `w_i` picks the word tree with a sign-extend. Keeping the word
//              tree separate means no per-op truncation logic and no width
//              warnings: each tree is exactly as wide as its result.
//
//              Shift amounts come from the low 6 bits (RV64) of operand B; the
//              word tree uses the low 5 bits, which is exactly what the RISC-V
//              spec requires for *.W shifts.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (EX stage)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Behavioral only (ADR-017): no vendor primitives, no DSP inference hints.
//              `alu_op_e` lives in eth_rv_pkg.
module cor_alu (
    input  eth_rv_pkg::alu_op_e op_i,
    input  logic                w_i,    // 1 = 32-bit word op (truncate + sign-extend)
    input  logic [eth_rv_pkg::XLEN-1:0] a_i,
    input  logic [eth_rv_pkg::XLEN-1:0] b_i,
    output logic [eth_rv_pkg::XLEN-1:0] res_o
);

    logic [63:0] res_64;
    logic [31:0] res_w;

    // ------------------------------------------------------------- 64-bit tree
    always_comb begin
        res_64 = 64'd0;
        unique case (op_i)
            eth_rv_pkg::ALU_ADD:   res_64 = a_i + b_i;
            eth_rv_pkg::ALU_SUB:   res_64 = a_i - b_i;
            eth_rv_pkg::ALU_SLL:   res_64 = a_i << b_i[5:0];
            eth_rv_pkg::ALU_SLT:   res_64 = {{63{1'b0}}, ($signed(a_i) < $signed(b_i))};
            eth_rv_pkg::ALU_SLTU:  res_64 = {{63{1'b0}}, (a_i < b_i)};
            eth_rv_pkg::ALU_XOR:   res_64 = a_i ^ b_i;
            eth_rv_pkg::ALU_SRL:   res_64 = a_i >> b_i[5:0];
            eth_rv_pkg::ALU_SRA:   res_64 = $signed(a_i) >>> b_i[5:0];
            eth_rv_pkg::ALU_OR:    res_64 = a_i | b_i;
            eth_rv_pkg::ALU_AND:   res_64 = a_i & b_i;
            eth_rv_pkg::ALU_PASSB: res_64 = b_i;
            default:               res_64 = 64'd0;
        endcase
    end

    // ---------------------------------------------------------- 32-bit tree
    // Only the *.W-legal ops narrow here; the rest fall back to the 64-bit
    // result's low half so the sign-extend below stays meaningful.
    always_comb begin
        res_w = res_64[31:0];
        unique case (op_i)
            eth_rv_pkg::ALU_ADD: res_w = a_i[31:0] + b_i[31:0];
            eth_rv_pkg::ALU_SUB: res_w = a_i[31:0] - b_i[31:0];
            eth_rv_pkg::ALU_SLL: res_w = a_i[31:0] << b_i[4:0];
            eth_rv_pkg::ALU_SRL: res_w = a_i[31:0] >> b_i[4:0];
            eth_rv_pkg::ALU_SRA: res_w = $signed(a_i[31:0]) >>> b_i[4:0];
            default:             res_w = res_64[31:0];
        endcase
    end

    assign res_o = w_i ? {{32{res_w[31]}}, res_w} : res_64;

endmodule
`default_nettype wire
