`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      fabric_top
// Description: Parameterized R x C fabric grid of clb_t + switch_box + channels.
// Details:     Each tile holds one clb_t + one switch_box + one connection_block,
//   wired by unidirectional W-track channels (N/S/E/W). The routable CB is now
//   COMPLETE: (a) output side — clb_out[j] is injected onto out_e[j] via the
//   switch_box inject_en config (Step 1); (b) input side — each clb_in[i] is a
//   mux selecting one of the 4*W local SB output tracks via connection_block
//   (Step 2). Together this yields end-to-end routability:
//   CLB.out -> SB.out_e (inject) -> channel -> neighbour SB -> track ->
//   connection_block -> CLB.in. The switch_box remains the single driver of
//   every track (no multi-drive). Acceptance (phase-0): a 4x4 grid instantiates
//   with NO combinational loop in the default (all-mux-disconnected) config —
//   verified at the graph level by tests/interconnect/fabric_model.py (Kahn
//   cycle detection) and by an end-to-end routability TB; the Verilator
//   UNOPTFLAT check is Docker-gated.
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB3)
//              2026-07-25 - routable CB Step 2: connection_block integrated
//                            (clb_in = mux of 4*W tracks); cfg unit field
//                            widened to 2 bits (CLB/SB/CB); tile_idx shifted.
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3 §5
// Notes:       ASSUMPTION (TBD 2026-07-24): SB topology is the disjoint
//   unidirectional v1 reference (see switch_box.sv), VPR-refinable per C01
//   §3.3 / §6#4. Assumes W <= EXT_IN (defaults 12 <= 18) and EXT_IN <= 64
//   (so $clog2(EXT_IN) <= 6 fits in the intra field). Scoped UNOPTFLAT waiver
//   covers the SB+channel routing network (potential rings) — consistent with
//   C01 §2.4 / §3 (virtual routing loop freedom; default config disconnects all
//   muxes so there is no functional loop). connection_block.sel_r is reset-less
//   (OCC configures before run; same pattern as SB inject_en / clb_t mux_sel).
//   config addressing:
//   cfg_addr_i = {tile_idx[TIW-1:0] @ bits [7+TIW:8], unit[1:0] @ [7:6],
//                 intra[5:0] @ [5:0]},  unit = 2'b00 CLB / 2'b01 SB / 2'b10 CB.

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
    localparam int AW_SB  = $clog2(4*W+N);     // switch_box cfg-addr width (sel+inject; =6 for W12,N8)
    localparam int AW_CB  = $clog2(EXT_IN);     // connection_block cfg-addr width (which clb_in; =5 for EXT_IN18)
    localparam int TW_CB  = $clog2(4*W);        // connection_block track-index width (=6 for W12)
    localparam int ADDR_USED = 8 + TIW;         // cfg_addr bits actually decoded

    // Sink any reserved upper cfg_addr bits beyond the decoded field (parametric on TIW).
    generate
        if (ADDR_USED < 16) begin : g_unused_addr
            logic _unused_ok;
            assign _unused_ok = ^cfg_addr_i[15:ADDR_USED];
        end
    endgenerate

    // ---- cfg field decode ----
    // unit @ [7:6]: 2'b00=CLB, 2'b01=SB, 2'b10=CB(connection_block), 2'b11=reserved.
    logic [5:0]     intra;
    logic [1:0]     unit;
    logic [TIW-1:0] tile_idx;
    assign intra      = cfg_addr_i[5:0];
    assign unit       = cfg_addr_i[7:6];
    assign tile_idx   = cfg_addr_i[7+TIW:8];

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
                localparam logic [TIW-1:0] MY_IDX = TIW'(r*C + c);
                wire sel_tile   = (tile_idx == MY_IDX);
                wire clb_cfg_we = cfg_we_i && sel_tile && (unit == 2'b00);
                wire sb_cfg_we  = cfg_we_i && sel_tile && (unit == 2'b01);
                wire cb_cfg_we  = cfg_we_i && sel_tile && (unit == 2'b10);

                // ---- per-tile CLB I/O (declared first; SB reads clb_out, CB drives clb_in) ----
                logic [N-1:0]      clb_out_local;
                logic [EXT_IN-1:0] clb_in_local;

                // ---- switch box (clb_out injected onto out_e per inject_en; SB is sole track driver) ----
                switch_box #(.W(W), .N_INJ(N)) u_sb (
                    .clk_i      (clk_i),
                    .cfg_we_i   (sb_cfg_we),
                    .cfg_addr_i (intra[AW_SB-1:0]),
                    .cfg_data_i (cfg_data_i[1:0]),
                    .in_n       (sb_in_n[r][c]),
                    .in_s       (sb_in_s[r][c]),
                    .in_e       (sb_in_e[r][c]),
                    .in_w       (sb_in_w[r][c]),
                    .clb_out_i  (clb_out_local),
                    .out_n      (sb_out_n[r][c]),
                    .out_s      (sb_out_s[r][c]),
                    .out_e      (sb_out_e[r][c]),
                    .out_w      (sb_out_w[r][c])
                );

                // ---- input connection_block (each clb_in = mux of 4*W local SB output tracks) ----
                connection_block #(.W(W), .N_CB(EXT_IN)) u_cb (
                    .clk_i      (clk_i),
                    .cfg_we_i   (cb_cfg_we),
                    .cfg_addr_i (intra[AW_CB-1:0]),
                    .cfg_data_i (cfg_data_i[TW_CB-1:0]),
                    .out_n      (sb_out_n[r][c]),
                    .out_s      (sb_out_s[r][c]),
                    .out_e      (sb_out_e[r][c]),
                    .out_w      (sb_out_w[r][c]),
                    .clb_in_o   (clb_in_local)
                );

                // ---- CLB ----
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
