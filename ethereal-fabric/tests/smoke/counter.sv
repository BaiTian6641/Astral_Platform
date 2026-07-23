`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      counter
// Description: 8-bit free-running counter — Phase-0 simulation smoke test.
// Details:     Not part of the fabric design; exists only to prove the
//              ethereal-sim image (Verilator lint + cocotb sim) end-to-end for
//              task E0-INF3. Follows rule G1: `default_nettype none`, a single
//              `always_ff` with non-blocking assigns, width'd literals, and
//              register/port naming `_r` / `_i` / `_o`.
// Maintainer:  ethereal-fpga
// Created:     2026-07-24
// Modified:    2026-07-24 - initial smoke test for E0-INF3
// Tags:        RTL, SYNTH, TESTBENCH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §1
//              (smoke-test reference; counter itself is NOT a C01 fabric core
//               unit — see S14 / phase-0 for the real owner of this artifact)
// Notes:       Lint-clean under `verilator --lint-only -Wall`.
//              ASSUMPTION: Plan-Ref to C01 is nominal per the E0-INF3 task
//              brief; this module is pure sim infrastructure, not a fabric
//              element. (待确认, 2026-07-24)
module counter (
    input  wire        clk_i,     // fabric-style user clock
    input  wire        rst_ni,    // active-low SYNCHRONOUS reset
    output wire [7:0]  count_o    // free-running count value
);

    logic [7:0] count_r;

    // Single sequential block, non-blocking only, sync active-low reset.
    // Wraps 0xFF -> 0x00 naturally (8-bit + 8-bit = 8-bit, no WIDTH warning).
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            count_r <= 8'h00;
        end else begin
            count_r <= count_r + 8'h01;
        end
    end

    assign count_o = count_r;

endmodule

`default_nettype wire
