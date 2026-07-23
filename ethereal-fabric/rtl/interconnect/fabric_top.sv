`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      fabric_top
// Description: Parameterized R x C fabric grid of clb_t + switch_box + channels.
// Details:     v1 E0-FAB3 instantiation. Each tile holds one clb_t and one
//   switch_box, wired by unidirectional W-track channels (N/S/E/W). The
//   CLB<->channel connection is a minimal v1 tap (clb_in reads this tile's
//   east-going SB tracks; clb_out is observable) — the full routable CB
//   (clb_out -> track injection) is a LATER design step with the frame-map
//   (S02-P0#1), OCC (E0-FAB4) and VPR (E0-MAP2). Acceptance (phase-0 E0-FAB3):
//   a 4x4 grid instantiates with NO combinational loop in the default config —
//   the routing logic is verified at the graph level by
//   tests/interconnect/fabric_model.py (Kahn cycle detection); the Verilator
//   UNOPTFLAT check is Docker-gated.
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB3)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3 §5
// Notes:       ASSUMPTION (TBD 2026-07-24): SB topology is the disjoint
//   unidirectional v1 reference (see switch_box.sv), VPR-refinable per C01
//   §3.3 / §6#4. Assumes W <= EXT_IN (defaults 12 <= 18). Scoped UNOPTFLAT
//   waiver covers the SB+channel routing network (potential rings) — consistent
//   with C01 §2.4 / §3 (virtual routing loop freedom; default config disconnects
//   all muxes so there is no functional loop). config addressing:
//   cfg_addr_i = {tile_idx[TIW-1:0] @ bits [6+TIW:7], unit @ bit[6], intra[5:0]}.

module fabric_top #(
    parameter int R = 4,
    parameter int C = 4,
    parameter int W = 12,
    parameter int N = 8,
    parameter int K = 4,
    parameter int EXT_IN = 18
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    input  logic              cfg_we_i,
    input  logic [15:0]       cfg_addr_i,
    input  logic [31:0]       cfg_data_i,
    output logic [R*C*N-1:0]  clb_out_obs_o   // flattened CLB outputs (observable)
);
    localparam int NTILES = R*C;
    localparam int TIW    = $clog2(NTILES);   // tile-index width
    localparam int AW_SB  = $clog2(4*W);      // switch_box cfg-addr width (=6)

    // ---- cfg field decode ----
    logic [5:0]     intra;
    logic           unit_is_sb;               // 0 = CLB, 1 = SB
    logic [TIW-1:0] tile_idx;
    assign intra      = cfg_addr_i[5:0];
    assign unit_is_sb = cfg_addr_i[6];
    assign tile_idx   = cfg_addr_i[6+TIW:7];

    // ---- per-tile SB I/O bundles (2D unpacked arrays) ----
    wire [W-1:0] sb_in_n  [R][C], sb_in_s  [R][C], sb_in_e  [R][C], sb_in_w  [R][C];
    wire [W-1:0] sb_out_n [R][C], sb_out_s [R][C], sb_out_e [R][C], sb_out_w [R][C];

    /* verilator lint_off UNOPTFLAT */
    genvar r, c;
    generate
        for (r = 0; r < R; r = r + 1) begin : g_row
            for (c = 0; c < C; c = c + 1) begin : g_col
                // ---- channel inputs from neighbours (0 at grid edges) ----
                if (r > 0) begin : g_in_n
                    assign sb_in_n[r][c] = sb_out_s[r-1][c];
                end else begin : g_in_n_edge
                    assign sb_in_n[r][c] = {W{1'b0}};
                end
                if (r < R-1) begin : g_in_s
                    assign sb_in_s[r][c] = sb_out_n[r+1][c];
                end else begin : g_in_s_edge
                    assign sb_in_s[r][c] = {W{1'b0}};
                end
                if (c < C-1) begin : g_in_e
                    assign sb_in_e[r][c] = sb_out_w[r][c+1];
                end else begin : g_in_e_edge
                    assign sb_in_e[r][c] = {W{1'b0}};
                end
                if (c > 0) begin : g_in_w
                    assign sb_in_w[r][c] = sb_out_e[r][c-1];
                end else begin : g_in_w_edge
                    assign sb_in_w[r][c] = {W{1'b0}};
                end

                // ---- tile select + per-unit config decode ----
                localparam logic [TIW-1:0] MY_IDX = (r*C + c)[TIW-1:0];
                wire sel_tile   = (tile_idx == MY_IDX);
                wire clb_cfg_we = cfg_we_i &&  sel_tile && ~unit_is_sb;
                wire sb_cfg_we  = cfg_we_i &&  sel_tile &&  unit_is_sb;

                // ---- switch box ----
                switch_box #(.W(W)) u_sb (
                    .clk_i      (clk_i),
                    .cfg_we_i   (sb_cfg_we),
                    .cfg_addr_i (intra[AW_SB-1:0]),
                    .cfg_data_i (cfg_data_i[1:0]),
                    .in_n       (sb_in_n[r][c]),
                    .in_s       (sb_in_s[r][c]),
                    .in_e       (sb_in_e[r][c]),
                    .in_w       (sb_in_w[r][c]),
                    .out_n      (sb_out_n[r][c]),
                    .out_s      (sb_out_s[r][c]),
                    .out_e      (sb_out_e[r][c]),
                    .out_w      (sb_out_w[r][c])
                );

                // ---- CLB (minimal v1 tap: clb_in reads this tile's east-going tracks) ----
                logic [EXT_IN-1:0] clb_in_local;
                logic [N-1:0]      clb_out_local;
                always_comb begin
                    clb_in_local         = '0;
                    clb_in_local[W-1:0]  = sb_out_e[r][c];
                end
                clb_t #(.N(N), .K(K), .EXT_IN(EXT_IN)) u_clb (
                    .clk_i      (clk_i),
                    .rst_ni     (rst_ni),
                    .clb_in_i   (clb_in_local),
                    .clb_out_o  (clb_out_local),
                    .cfg_we_i   (clb_cfg_we),
                    .cfg_addr_i (intra[5:0]),
                    .cfg_data_i (cfg_data_i)
                );

                assign clb_out_obs_o[(r*C+c)*N +: N] = clb_out_local;
            end
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */

endmodule

`default_nettype wire
