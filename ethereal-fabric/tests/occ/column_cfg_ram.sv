`timescale 1ns/1ps
`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      column_cfg_ram
// Description: Simulation model of the per-column configuration storage behind the OCC frame bus.
// Details:     Synchronous-write, COMBINATIONAL-read RAM. Stands in for the real
//              column controller + distributed config storage (C03 §0) during OCC
//              v0 verification (task E0-FAB4). The `mem` array is intentionally
//              exposed so the testbench can backdoor-poke individual words for
//              the CRC-tamper check (C03 §4 readback-verify failure injection).
//
//              This is a SIMULATION MODEL, not synthesizable: a real column store
//              is distributed across tile columns with broadcast column-select +
//              intra-column second-level decode (C01 §2.4 / C03 §0), and the
//              readback path is the column controller's `re` channel (C13 §2.3
//              config read port on eth_inf_lutram). None of that topology is
//              modeled here — only the flat address/data behavior the OCC needs
//              to exercise its WRITE / READBACK / BLANK / CRC logic.
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C03-OCC组件.md §0
// Notes:       simulation model, not synthesizable. `re` is accepted for frame-bus
//              interface parity but unused (read is combinational in v0); it is
//              sunk into _unused_re so a stray lint pass stays clean.
module column_cfg_ram #(
    parameter int ADDR_W = 16,
    parameter int DATA_W = 32,
    parameter int DEPTH  = 8192
)(
    input  logic                clk,
    input  logic                we,
    input  logic                re,          // unused in v0 (combinational read)
    input  logic [ADDR_W-1:0]   addr,
    input  logic [DATA_W-1:0]   wdata,
    output logic [DATA_W-1:0]   rdata
);
    logic [DATA_W-1:0] mem [0:DEPTH-1];

    // synchronous write
    always_ff @(posedge clk) begin
        if (we) mem[addr] <= wdata;
    end

    // combinational read (v0 sim convenience: same-cycle readback data)
    always_comb begin
        rdata = mem[addr];
    end

    // sink unused read strobe
    logic _unused_re;
    assign _unused_re = re;

endmodule

`default_nettype wire
