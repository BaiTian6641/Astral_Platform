`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_inf_ram
// Description: Inference-first synchronous block-RAM template (ADR-017, C13 §2.2).
// Details:     Pure behavioral synchronous-read RAM with per-byte write enable
//              and optional initial content. Uses NO vendor primitives — the
//              platform EDA (GowinSynthesis / Vivado / Yosys) INFERS this as
//              physical BSRAM / BRAM / M20K. Fully Verilator-simulatable.
//              Coding red-lines honored (C13 §2.2): synchronous read
//              (read-first), NO reset on the RAM array (resets block RAM
//              inference), per-byte write enable, sync enable.
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.2 · C02 §1
module eth_inf_ram #(
    parameter int AW    = 11,              // address width (2^AW entries)
    parameter int DW    = 32,              // data width (byte-aligned)
    parameter int NBYTES = DW / 8,         // byte-write-enable width
    parameter INIT_HEX = ""                // optional $readmemh init (ROM preload)
) (
    input  logic                clk_i,
    input  logic                en_i,       // clock-enable / chip-enable
    input  logic                we_i,       // write enable
    input  logic [NBYTES-1:0]   be_i,       // per-byte write enable
    input  logic [AW-1:0]       addr_i,
    input  logic [DW-1:0]       wdata_i,
    output logic [DW-1:0]       rdata_o
);
    // RAM array. `ETH_RAMSTYLE maps to a per-target attribute via
    // `eth_config.svh (generic/Verilator branch: empty). Inference requires
    // NO reset on this array.
`include "eth_config.svh"
    `ETH_RAMSTYLE
    logic [DW-1:0] mem [0:(1<<AW)-1];

    // Optional initial content (ROM preload; also configuration, C02 §1.4).
    initial begin
        if (INIT_HEX != "") begin
            $readmemh(INIT_HEX, mem);
        end
    end

    // Synchronous read + per-byte write (read-first on write: rdata is the
    // OLD value, matching physical BSRAM semantics).
    always_ff @(posedge clk_i) begin
        if (en_i) begin
            if (we_i) begin
                for (int b = 0; b < NBYTES; b = b + 1) begin
                    if (be_i[b]) begin
                        mem[addr_i][b*8 +: 8] <= wdata_i[b*8 +: 8];
                    end
                end
            end
            rdata_o <= mem[addr_i];
        end
    end
endmodule

`default_nettype wire
