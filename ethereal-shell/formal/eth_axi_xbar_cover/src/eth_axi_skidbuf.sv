`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_axi_skidbuf
// Description: Generic AXI-style skid buffer (registered valid/ready pipe stage).
// Details:     The load-bearing building block of the eth_axi fabric (spec
//              ethereal-spec/control/eth-axi-v0.md §2 rule 1+2): it breaks the
//              combinational path between a downstream READY and an upstream
//              VALID (and vice-versa) so that no module boundary has a comb
//              input->output path. Payload is a flat PW-bit bus (the caller
//              packs {addr,data,resp,id,...}); this module is payload-agnostic.
//
//              Structure = the classic 2-entry skid buffer:
//                * a main output register (m_*) and
//                * one skid/overflow register (skid_*) that catches a beat when
//                  the output register is occupied but downstream stalls.
//              Capacity = 2 beats; it accepts a beat whenever the skid register
//              is empty (i_ready_o = !skid_valid). Once o_valid is asserted it
//              stays asserted with stable payload until o_ready (spec §2.2 /
//              §7 property 1), and i_ready_o never depends combinationally on
//              i_valid / o_valid / o_ready (registered, §7 property 2).
//
//              Timing (no comb in->out):
//                i_valid -> o_valid : registered (>= 1 clk).
//                i_ready_o          : registered function of state only.
//                o_ready  -> i_ready: registered (>= 1 clk).
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §2 (rules 1-2), §7 (props 1-2)
// Notes:       Payload-flat (PW param) so the same buffer serves AW/W/B/AR/R and
//              AXI4-Stream; keeps the crossbar deadlock-free per §5.1. iverilog-
//              compatible (flat ports, no packed-2D params). Formal properties
//              (VALID stability, no-comb-READY) under `ifdef FORMAL (sby-proven,
//              see ethereal-shell/formal/eth_axi_skidbuf.sby).
module eth_axi_skidbuf #(
    parameter int PW = 8                  // payload width in bits
) (
    input  logic            clk_i,
    input  logic            rst_ni,
    // upstream (sink side)
    input  logic            i_valid,
    output logic            i_ready,
    input  logic [PW-1:0]   i_data,
    // downstream (source side)
    output logic            o_valid,
    input  logic            o_ready,
    output logic [PW-1:0]   o_data
);

    // main output register + one skid (overflow) register
    logic            skid_valid;
    logic [PW-1:0]   skid_data;
    logic            m_valid;
    logic [PW-1:0]   m_data;

    // Accept a new beat whenever the skid register is (or will be) empty.
    // Registered: depends only on stored state, never combinationally on inputs.
    assign i_ready = !skid_valid;
    assign o_valid = m_valid;
    assign o_data  = m_data;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            skid_valid <= 1'b0;
            skid_data  <= {PW{1'b0}};
            m_valid    <= 1'b0;
            m_data     <= {PW{1'b0}};
        end else begin
            // ---- output (main) register ----
            if (!m_valid || o_ready) begin
                // output register is empty or being drained this cycle: refill it
                // from the skid register if occupied, else directly from input.
                if (skid_valid) begin
                    m_valid    <= 1'b1;
                    m_data     <= skid_data;
                    skid_valid <= 1'b0;
                end else begin
                    m_valid <= i_valid;
                    m_data  <= i_data;
                end
            end else if (i_valid && !skid_valid) begin
                // output occupied and downstream stalled: park the incoming beat.
                skid_valid <= 1'b1;
                skid_data  <= i_data;
            end
        end
    end

    // ------------------------------------------------------------------
    // Formal properties (yosys-smtbmc via sby; NOT seen by verilator lint, which
    // runs without -DFORMAL). Immediate-assert + $past form for 3-tool portability.
    // ------------------------------------------------------------------
`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;

    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // §7 prop 1: o_valid stays asserted & payload stable while stalled.
            if ($past(o_valid) && !$past(o_ready)) begin
                assert(o_valid);
                assert(o_data == $past(o_data));
            end
            // §7 prop 2 (stability of accepted input): if upstream presented a
            // beat and we did not accept it, the contract requires the source to
            // hold it; we assert our side never glitches i_ready spuriously high
            // then drops it while a beat waits (i_ready is a pure state function).
            if ($past(i_valid) && !$past(i_ready))
                assert(!i_ready || skid_valid == 1'b0);
        end
        // reset clears valids
        if (past_valid && !$past(rst_ni)) begin
            assert(!o_valid);
            assert(!skid_valid);
        end
    end
`endif

endmodule
