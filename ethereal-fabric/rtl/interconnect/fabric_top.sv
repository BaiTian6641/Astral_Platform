`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      fabric_top
// Description: Parameterized R x C HETEROGENEOUS fabric grid (CLB-T / MEM-T /
//              DSP-T) + switch_box + channels (Phase-1, Stage 3).
// Details:     Each tile holds a switch_box + connection_block + a LOGIC tile
//              (CLB-T by default; MEM-T or DSP-T for heterogeneous tiles per the
//              TILE_TYPE map, C02). The routable CB (input CB + bidirectional
//              clb_out inject) and the Wilton SB are as in v1.1 (see switch_box).
//              TILE_TYPE is a build-time (fabric.yaml / fabric-gen) parameter;
//              the heterogeneous tile's config mode word + operand/RAM-control
//              registers are written via cfg unit 2'b11 (intra selects the
//              register). The wide tile vbus (mem va/vd/vwe, dsp va/vb/vcasc) is
//              driven by per-tile vbus-control registers (cfg-written); tile
//              outputs (mem vd_o, dsp vp_o) are observed on vbus_obs_o. v1
//              vbus: not yet woven into the virtual routing (that is the
//              mapping-chain stage, Stage 4-5, when Yosys/VPR target the tiles);
//              the integration here proves the heterogeneous tiles sit + are
//              OCC-configurable in the real fabric.
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB3)
//              2026-07-25 - routable CB Step 2: connection_block integrated
//              2026-07-26 - bidirectional inject + Wilton SB (v1.1)
//              2026-07-28 - HETEROGENEOUS: TILE_TYPE map + mem_t/dsp_t + cfg
//                            unit 11 + per-tile vbus control regs (Stage 3, P1).
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3 §5 ·
//              ethereal-plan/components/C02-fabric-异构tile.md §0 §5
// Notes:       config addressing (v1.1 + het):
//   cfg_addr_i = {tile_idx[TIW-1:0] @ bits [7+TIW:8], unit[1:0] @ [7:6],
//                 intra[5:0] @ [5:0]}
//   unit: 2'b00=CLB (clb_t), 2'b01=SB (switch_box), 2'b10=CB (connection_block),
//         2'b11=TILE-MODE / vbus-control (heterogeneous tiles; CLB ignores it).
//   TILE-MODE intra (per TILE_TYPE):
//     MEM_T (TILE_TYPE=1): intra=0 -> mem mode_r[15:0]; intra=1 -> vbus-ctrl
//         word A (va_i[13:0] @ [13:0], ven_i @ [16], vwe_i[3:0] @ [21:18]);
//         intra=2 -> vd_i[31:0] (write data). (ROM init: use eth_inf_ram INIT_HEX
//         at build, or OCC rom.hex writes, C02 §1.4 — vbus ctrl drives them here.)
//     DSP_T (TILE_TYPE=2): intra=0 -> dsp mode_r[23:0] (acc/lat_sel);
//         intra=1 -> va_i[26:0]; intra=2 -> vb_i[17:0]; intra=3 -> ven_i @ [0];
//         intra=4/5 -> vcasc_i[47:16] / vcasc_i[15:0].
//   CLB (TILE_TYPE=0): TILE-MODE is a no-op.
module fabric_top #(
    parameter int R = 4,
    parameter int C = 4,
    parameter int W = 12,
    parameter int N = 8,
    parameter int K = 4,
    parameter int EXT_IN = 18,
    /* verilator lint_off UNUSEDPARAM */
    parameter int MEM_AW = 11,             // mem_t RAM address width (used when a MEM_T tile is placed)
    /* verilator lint_on UNUSEDPARAM */
    // TILE_TYPE: R*C-entry build-time map (from fabric.yaml / fabric-gen).
    //   0=CLB_T (default all), 1=MEM_T, 2=DSP_T. Flattened MSB-first? No —
    //   index r*C+c, each entry 8 bits wide, entry 0 at the LSB end.
    parameter logic [R*C*8-1:0] TILE_TYPE = {(R*C*8){1'b0}}
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    input  logic              cfg_we_i,
    input  logic [15:0]       cfg_addr_i,
    input  logic [31:0]       cfg_data_i,
    output logic [R*C*N-1:0]  clb_out_obs_o,  // flattened CLB outputs (observable)
    output logic [R*C*32-1:0] mem_vd_obs_o,   // flattened mem_t vd_o (observable)
    output logic [R*C*48-1:0] dsp_vp_obs_o    // flattened dsp_t vp_o (observable)
);
    localparam int NTILES = R*C;
    localparam int TIW    = $clog2(NTILES);
    localparam int AW_SB  = $clog2(4*W+N);
    localparam int AW_CB  = $clog2(EXT_IN);
    localparam int TW_CB  = $clog2(4*W);
    localparam int ADDR_USED = 8 + TIW;

    // TILE_TYPE extraction helper (8-bit entry at index idx, LSB-first).
    function automatic logic [7:0] tile_type_at(input int idx);
        return TILE_TYPE[idx*8 +: 8];
    endfunction

    // Sink any reserved upper cfg_addr bits beyond the decoded field.
    generate
        if (ADDR_USED < 16) begin : g_unused_addr
            logic _unused_ok;
            assign _unused_ok = ^cfg_addr_i[15:ADDR_USED];
        end
    endgenerate

    // ---- cfg field decode ----
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
                localparam logic [7:0]     MY_TYPE = tile_type_at(r*C + c);
                wire sel_tile   = (tile_idx == MY_IDX);
                wire clb_cfg_we = cfg_we_i && sel_tile && (unit == 2'b00);
                wire sb_cfg_we  = cfg_we_i && sel_tile && (unit == 2'b01);
                wire cb_cfg_we  = cfg_we_i && sel_tile && (unit == 2'b10);
                wire tmode_cfg_we = cfg_we_i && sel_tile && (unit == 2'b11);

                // ---- per-tile CLB I/O ----
                logic [N-1:0]      clb_out_local;
                logic [EXT_IN-1:0] clb_in_local;

                // ---- heterogeneous tile (by MY_TYPE): vbus control regs + instance ----
                // Declared only for heterogeneous tiles so pure-CLB tiles carry no
                // dead registers (UNUSEDSIGNAL). unit 11 (tmode) writes them.
                logic [31:0] mem_vd_o_local;
                logic [47:0] dsp_vp_o_local;
                if (MY_TYPE == 8'd1) begin : g_mem_t
                    // ---- MEM_T: vbus control regs (unit 11, intra 1/2) + tile ----
                    logic        mem_ven_r;
                    logic [13:0] mem_va_r;
                    logic [31:0] mem_vd_i_r;
                    logic [3:0]  mem_vwe_r;
                    always_ff @(posedge clk_i) begin
                        if (tmode_cfg_we) begin
                            if (intra == 6'd1) begin
                                mem_va_r  <= cfg_data_i[13:0];
                                mem_ven_r <= cfg_data_i[16];
                                mem_vwe_r <= cfg_data_i[21:18];
                            end else if (intra == 6'd2) begin
                                mem_vd_i_r <= cfg_data_i;
                            end
                        end
                    end
                    mem_t #(.AW(MEM_AW)) u_mem_t (
                        .clk_i      (clk_i),
                        .rst_ni     (rst_ni),
                        .ven_i      (mem_ven_r),
                        .va_i       (mem_va_r),
                        .vd_i       (mem_vd_i_r),
                        .vwe_i      (mem_vwe_r),
                        .vd_o       (mem_vd_o_local),
                        .cfg_we_i   (tmode_cfg_we && (intra == 6'd0)),
                        .cfg_data_i (cfg_data_i[15:0])
                    );
                    assign dsp_vp_o_local = '0;
                end else if (MY_TYPE == 8'd2) begin : g_dsp_t
                    // ---- DSP_T: vbus control regs (unit 11, intra 1..5) + tile ----
                    logic        dsp_ven_r;
                    logic signed [26:0] dsp_va_r;
                    logic signed [17:0] dsp_vb_r;
                    logic signed [47:0] dsp_vcasc_r;
                    always_ff @(posedge clk_i) begin
                        if (tmode_cfg_we) begin
                            if (intra == 6'd1)      dsp_va_r    <= cfg_data_i[26:0];
                            else if (intra == 6'd2) dsp_vb_r    <= cfg_data_i[17:0];
                            else if (intra == 6'd3) dsp_ven_r   <= cfg_data_i[0];
                            else if (intra == 6'd4) dsp_vcasc_r[47:16] <= cfg_data_i[31:0];
                            else if (intra == 6'd5) dsp_vcasc_r[15:0]  <= cfg_data_i[15:0];
                        end
                    end
                    dsp_t u_dsp_t (
                        .clk_i      (clk_i),
                        .rst_ni     (rst_ni),
                        .ven_i      (dsp_ven_r),
                        .va_i       (dsp_va_r),
                        .vb_i       (dsp_vb_r),
                        .vcasc_i    (dsp_vcasc_r),
                        .vp_o       (dsp_vp_o_local),
                        .cfg_we_i   (tmode_cfg_we && (intra == 6'd0)),
                        .cfg_data_i (cfg_data_i[23:0])
                    );
                    assign mem_vd_o_local = '0;
                end else begin : g_no_het
                    // pure-CLB tile: no het instance; tmode (unit 11) writes are a
                    // no-op. Drive the obs outputs from the (unused) tmode decode so
                    // it is not flagged as an undriven/unused signal.
                    assign mem_vd_o_local = {31'b0, tmode_cfg_we & 1'b0};
                    assign dsp_vp_o_local = 48'b0;
                end

                // ---- switch box ----
                switch_box #(.W(W), .N_INJ(N)) u_sb (
                    .clk_i      (clk_i),
                    .cfg_we_i   (sb_cfg_we),
                    .cfg_addr_i (intra[AW_SB-1:0]),
                    .cfg_data_i (cfg_data_i[2:0]),
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

                // ---- input connection_block ----
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

                // ---- CLB (logic tile; MEM/DSP tiles leave this tile's CLB in place
                // for now — a heterogeneous tile is a logic tile PLUS its hard block;
                // C02 §5 region: MEM/DSP sit alongside, the tile's CLB-T is usable) ----
                clb_t #(.N(N), .K(K), .EXT_IN(EXT_IN)) u_clb (
                    .clk_i      (clk_i),
                    .rst_ni     (rst_ni),
                    .clb_in_i   (clb_in_local),
                    .clb_out_o  (clb_out_local),
                    .cfg_we_i   (clb_cfg_we),
                    .cfg_addr_i (intra[5:0]),
                    .cfg_data_i (cfg_data_i)
                );

                assign clb_out_obs_o[(r*C+c)*N +: N]    = clb_out_local;
                assign mem_vd_obs_o[(r*C+c)*32 +: 32]    = mem_vd_o_local;
                assign dsp_vp_obs_o[(r*C+c)*48 +: 48]    = dsp_vp_o_local;
            end
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */

endmodule

`default_nettype wire
