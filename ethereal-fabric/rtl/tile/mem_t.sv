`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      mem_t
// Description: Memory tile — a virtual block RAM wrapped with a config mode
//              register (C02 §1). Sits beside CLB-T/DSP-T in the fabric.
// Details:     Wraps eth_inf_ram (ADR-017: behavioral, EDA-inferred BSRAM).
//              Virtual side exposes a fixed 32-bit data / 14-bit address /
//              4-bit byte-enable / clk / en interface; config writes a 16-bit
//              mode word. v1 vbus-ifies the interface to the fabric's cfg/obs
//              convention (virtual interconnect wiring is the vbus layer).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C02-fabric-异构tile.md §1 · C13 §2.2
// Notes:       mode word bitfield (frozen v1): mode_r[2:0]=geometry (0=RAM,
//              others reserved), [3]=fifo_flags_en, [4]=ecc_en, [5]=rom_init_en.
module mem_t #(
    parameter int AW = 11,               // RAM address width (2^AW x 32b)
    parameter INIT_HEX = ""              // optional ROM preload (OCC-issued)
) (
    input  logic        clk_i,          // virtual clock
    input  logic        rst_ni,         // unused by the RAM (no-reset, ADR-017)
    input  logic        ven_i,          // virtual chip-enable
    input  logic [13:0] va_i,           // virtual address (AW-1:0 used)
    input  logic [31:0] vd_i,           // virtual write data
    input  logic [3:0]  vwe_i,          // virtual byte-write-enable
    output logic [31:0] vd_o,           // virtual read data (synchronous, 1-cycle)
    input  logic        cfg_we_i,       // config write enable (1 cycle)
    input  logic [15:0] cfg_data_i      // mode word
);
    // ---- config mode register ----
    logic [15:0] mode_r;
    always_ff @(posedge clk_i) begin
        if (cfg_we_i) begin
            mode_r <= cfg_data_i;
        end
    end

    // ---- behavioral RAM (eth_inf_ram: EDA-inferred BSRAM) ----
    // Read-first synchronous read. ven_i gates clock-enable (power, C02 §1.3).
    eth_inf_ram #(.AW(AW), .DW(32), .INIT_HEX(INIT_HEX)) u_ram (
        .clk_i   (clk_i),
        .en_i    (ven_i),
        .we_i    (|vwe_i),
        .be_i    (vwe_i),
        .addr_i  (va_i[AW-1:0]),
        .wdata_i (vd_i),
        .rdata_o (vd_o)
    );

    // rst_ni and the upper va_i bits are unused in v1 (RAM has no reset; va_i
    // wider than AW). Sink them so lint does not flag them.
    logic _unused_ok;
    assign _unused_ok = rst_ni & ^{va_i[13:AW], mode_r};
endmodule

`default_nettype wire
