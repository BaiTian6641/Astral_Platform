`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_regfile
// Description: 32 x 64-bit integer register file for eth_rv (x0 hard-wired to zero).
// Details:     One write port (WB), two combinational read ports (ID). Read data
//              *is* bypassed from the write port (write-first / "internal bypass"):
//              when the WB stage writes the register an ID-stage instruction is
//              reading in that same cycle, the read returns the new value.
//              That hazard cannot be fixed by the EX-stage forwarding network
//              (by the time the consumer reaches EX the producer has left WB),
//              and it is a real one — it shows up as a stale operand on the
//              third instruction after an ALU producer, which is exactly how the
//              DiffTest caught it (cor_alu commit #50 at pc 0x8000_00c4).
//
//              x0 is forced to zero at the read ports as well as being
//              write-protected, so a stray write to x0 can never leak into an
//              operand (and the bypass never fires for it). The array itself is
//              deliberately not reset: on FPGA the registers come up undefined,
//              which is architecturally legal, and the 2-state simulation model
//              zeroes it, matching the DiffTest reference model's `x = [0]*32`
//              initialisation.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (ID stage, forwarding)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Behavioral RAM description (ADR-017): no vendor primitives.
module cor_regfile (
    input  logic            clk_i,
    input  logic            rst_ni,
    input  logic            we_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] waddr_i,
    input  logic [63:0]     wdata_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] raddr_a_i,
    input  logic [eth_rv_pkg::REG_ADDR-1:0] raddr_b_i,
    output logic [63:0]     rdata_a_o,
    output logic [63:0]     rdata_b_o
);

    logic [63:0] regs_r [eth_rv_pkg::REG_NUM];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // No array reset on purpose (see the header note).
        end else if (we_i && (waddr_i != 5'd0)) begin
            regs_r[waddr_i] <= wdata_i;
        end
    end

    // read port A with the write-first bypass
    always_comb begin
        rdata_a_o = regs_r[raddr_a_i];
        if (raddr_a_i == 5'd0) begin
            rdata_a_o = 64'd0;
        end else if (we_i && (waddr_i == raddr_a_i)) begin
            rdata_a_o = wdata_i;
        end
    end

    // read port B with the write-first bypass
    always_comb begin
        rdata_b_o = regs_r[raddr_b_i];
        if (raddr_b_i == 5'd0) begin
            rdata_b_o = 64'd0;
        end else if (we_i && (waddr_i == raddr_b_i)) begin
            rdata_b_o = wdata_i;
        end
    end

endmodule
`default_nettype wire
