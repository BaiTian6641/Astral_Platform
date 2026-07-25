`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      connection_block
// Description: Input-side CB — muxes SB output tracks into CLB inputs (routable CB).
// Details:     Each of the N_CB CLB inputs selects one of the 4*W tracks available
//              at this tile (out_n/s/e/w from the local switch_box). Pool layout:
//              pool[0..W-1]=out_n, [W..2W-1]=out_s, [2W..3W-1]=out_e, [3W..4W-1]=out_w.
//              Config: cfg_addr selects which clb_in (0..N_CB-1); cfg_data is the
//              track index (0..4*W-1). This is the input half of the routable CB
//              (the output half is switch_box's clb_out injection onto out_e).
// Maintainer:  BaiTian6641
// Created:     2026-07-25
// Modified:    2026-07-25 - initial implementation (routable CB, E0-FAB3b)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3 (CB)
// Notes:       No combinational loop (clb_in reads out_* from the SB; no feedback
//              within this module). sel_r has no reset — OCC configures before run.
module connection_block #(
    parameter int W    = 12,
    parameter int N_CB = 18   // number of CLB inputs (EXT_IN)
) (
    input  logic                    clk_i,
    input  logic                    cfg_we_i,
    input  logic [$clog2(N_CB)-1:0] cfg_addr_i,   // 0..N_CB-1
    input  logic [$clog2(4*W)-1:0]  cfg_data_i,   // track index 0..4*W-1
    input  logic [W-1:0]            out_n,
    input  logic [W-1:0]            out_s,
    input  logic [W-1:0]            out_e,
    input  logic [W-1:0]            out_w,
    output logic [N_CB-1:0]         clb_in_o
);
    localparam int POOL  = 4*W;
    localparam int SELW  = $clog2(POOL);
    localparam int AW    = $clog2(N_CB);

    // track pool (flattened 4*W)
    logic [POOL-1:0] pool;
    assign pool = {out_w, out_e, out_s, out_n};   // [0..W-1]=n, [W..2W-1]=s, [2W..3W-1]=e, [3W..]=w

    // per-clb_in track select
    logic [SELW-1:0] sel_r [0:N_CB-1];

    always_ff @(posedge clk_i) begin
        if (cfg_we_i) begin
            sel_r[cfg_addr_i[AW-1:0]] <= cfg_data_i[SELW-1:0];
        end
    end

    genvar i;
    generate
        for (i = 0; i < N_CB; i = i + 1) begin : gen_cb
            assign clb_in_o[i] = pool[sel_r[i]];
        end
    endgenerate
endmodule

`default_nettype wire
