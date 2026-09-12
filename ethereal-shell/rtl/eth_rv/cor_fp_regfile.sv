`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_fp_regfile
// Description: 32 x 64-bit floating-point register file f0..f31 for eth_rv (F/D).
// Details:     Unlike the integer file, f0 is an ordinary register: there is no
//              hard-wired zero and no write protection. Three combinational read
//              ports (rs1/rs2/rs3 — the fused multiply-add forms name a third
//              source) and one write port (WB), with the same write-first bypass
//              the integer file uses: a WB write in the cycle an ID read names the
//              same register returns the NEW value (that hazard is invisible to
//              the EX forwarding network, which only covers producers still in
//              flight).
//
//              Reset state: the array IS reset to zero. Spike's FPR starts at 0
//              (`corpus/cor_fp.S` probes an untouched register), and the RISC-V
//              F extension makes the f registers' reset contents architecturally
//              *unspecified*, so zero is a legal choice and the one that makes the
//              DiffTest deterministic from the first FP instruction. The integer
//              file deliberately chose the other way round (unreset, matching the
//              model's `x = [0]*32` in 2-state simulation); FP takes the explicit
//              reset because a corpus program may read a register it never wrote
//              and the golden answer for that read is Spike's zero.
//
//              The values stored are the raw 64-bit register contents, already
//              NaN-boxed for the single-precision forms (the FPU boxes every .s
//              result and the MEM stage boxes `flw`) — the file is a plain bit
//              store and never interprets its contents.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (ID stage, F/D),
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Behavioral RAM description (ADR-017): no vendor primitives. The
//              reset is the module's only procedural loop (a for over the array):
//              the formal flow's yosys frontend cannot parse an assignment pattern
//              for a memory array, and this spelling is accepted by yosys,
//              and by the simulators alike.
module cor_fp_regfile (
    input  logic            clk_i,
    input  logic            rst_ni,
    input  logic            we_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] waddr_i,
    input  logic [63:0]     wdata_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] raddr_a_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] raddr_b_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] raddr_c_i,
    output logic [63:0]     rdata_a_o,
    output logic [63:0]     rdata_b_o,
    output logic [63:0]     rdata_c_o
);

    logic [63:0] regs_r [eth_rv_pkg::REG_NUM];
    integer      rst_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // A reset loop rather than an assignment pattern: the formal flow's
            // yosys frontend rejects `regs_r <= '{...}` for a memory array
            // ("syntax error, unexpected '{'"), and this is the portable spelling.
            // It is the ONE procedural loop in this module and it exists only in
            // the reset branch (G1's loop rule is about datapath logic).
            for (rst_i = 0; rst_i < eth_rv_pkg::REG_NUM; rst_i = rst_i + 1) begin
                regs_r[rst_i] <= 64'd0;
            end
        end else if (we_i) begin
            regs_r[waddr_i] <= wdata_i;
        end
    end

    // read port A with the write-first bypass
    always_comb begin
        rdata_a_o = regs_r[raddr_a_i];
        if (we_i && (waddr_i == raddr_a_i)) begin
            rdata_a_o = wdata_i;
        end
    end

    // read port B with the write-first bypass
    always_comb begin
        rdata_b_o = regs_r[raddr_b_i];
        if (we_i && (waddr_i == raddr_b_i)) begin
            rdata_b_o = wdata_i;
        end
    end

    // read port C (rs3, fused multiply-add) with the write-first bypass
    always_comb begin
        rdata_c_o = regs_r[raddr_c_i];
        if (we_i && (waddr_i == raddr_c_i)) begin
            rdata_c_o = wdata_i;
        end
    end

endmodule
`default_nettype wire
