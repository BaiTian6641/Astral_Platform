`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      switch_box
// Description: Virtual FPGA switch box — disjoint unidirectional routing mux.
// Details:     Sits at a channel intersection. For each output track t in each
//              of the 4 directions (N/S/E/W, W tracks each), a registered 2-bit
//              select picks one of the 3 SAME-INDEX input tracks of the OTHER 3
//              directions, or disconnects (drives 1'b0). This is the standard
//              VPR-compatible disjoint unidirectional topology. Mux outputs are
//              combinational; selects are registered config.
//
//              Per-output-track source map (frozen v1 sel order, C01 §3.3):
//                out_n[t]: sel1=in_s[t], sel2=in_e[t], sel3=in_w[t]
//                out_s[t]: sel1=in_n[t], sel2=in_e[t], sel3=in_w[t]
//                out_e[t]: sel1=in_n[t], sel2=in_s[t], sel3=in_w[t]
//                out_w[t]: sel1=in_n[t], sel2=in_s[t], sel3=in_e[t]
//                sel0 -> disconnect (drive 1'b0)
//              i.e. for output dir d, sel1/2/3 enumerate the 3 dirs != d in
//              ascending index order (DIR: 0=N,1=S,2=E,3=W).
//
//              cfg addressing (v1, C01 §3.3):
//                cfg_addr = DIR*W + t   (DIR: 0=N,1=S,2=E,3=W ; t: 0..W-1)
//                cfg_addr < 4*W         -> sel_r[addr] <- cfg_data_i[1:0]
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB3)
//              2026-07-25 - routable CB: clb_out injection on out_e[0..N_INJ-1]
//              2026-07-26 - BIDIRECTIONAL inject (Option B): clb_out[j] injects
//                            onto a CONFIGURABLE out_D[j] (D=inj_dir[j]), not
//                            east-only. Fixes east-edge driver stranding found
//                            by the c432 routing (E0-MAP3 incr 4a). cfg_data->3 bit.
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §3
// Notes:       ASSUMPTION (TBD 2026-07-24): v1 topology is DISJOINT
//              UNIDIRECTIONAL (each output track t muxes same-index tracks of
//              the other 3 dirs). C01 §3.3 problem 1 requires the final SB
//              topology table to be validated by VPR routability experiments
//              (subsystem S03, task E0-MAP2) before freezing; this disjoint
//              pattern is the preliminary, parameterized placeholder. C01 §3.3
//              problem 2 locks v1 to UNIDIRECTIONAL channels (each dir W=12).
//              Routing muxes form structural combinational loops when SBs are
//              chained at the fabric level (legal virtual routing, C01 §2.4
//              problem 2); a scoped UNOPTFLAT waiver wraps the mux-output
//              combinational region, mirroring clb_t.sv. NOTE: an isolated SB
//              has NO within-module loop (out = f(in, sel)); UNOPTFLAT only
//              arises under fabric-level SB chaining — the waiver is scoped
//              here pre-emptively (currently a no-op on the isolated module;
//              it localizes the exemption at the mux source for fabric
//              integration). 4*W assumed non-power-of-2 so SB_END fits in AW
//              bits (true for frozen W=12: 48 < 64). sel_r has NO reset — OCC
//              writes all selects before un-halt (config-before-run, C03).
module switch_box #(
    parameter int W     = 12,   // tracks per direction (channel width)
    parameter int N_INJ = 8    // injectable CLB-output count (<= W); routable CB
) (
    input  logic                            clk_i,
    input  logic                            cfg_we_i,
    input  logic [$clog2(4*W+N_INJ)-1:0]    cfg_addr_i,  // 0..4W-1 = sel | 4W..4W+N_INJ-1 = inject(en+dir)
    input  logic [2:0]                      cfg_data_i,  // sel:[1:0]; inject: [0]=en, [2:1]=dir(0=N,1=S,2=E,3=W)
    input  logic [W-1:0]                    in_n,
    input  logic [W-1:0]                    in_s,
    input  logic [W-1:0]                    in_e,
    input  logic [W-1:0]                    in_w,
    input  logic [N_INJ-1:0]                clb_out_i,   // local CLB outputs -> inject onto out_D[j] (D=inj_dir[j])
    output logic [W-1:0]                    out_n,
    output logic [W-1:0]                    out_s,
    output logic [W-1:0]                    out_e,
    output logic [W-1:0]                    out_w
);
    // ---- derived parameters ----
    localparam int AW              = $clog2(4*W+N_INJ);  // addr width (6 for W=12,N_INJ=8: 56<64)
    localparam int NSEL            = 4*W;                // 48 disjoint (DIR,t) selects
    localparam int NINJ            = N_INJ;              // inject_en bits
    localparam int DW              = 2;                  // select width
    localparam logic [AW-1:0] SEL_END = AW'(NSEL);        // 48
    localparam logic [AW-1:0] SB_END  = AW'(NSEL + NINJ); // 56

    // direction index encoding (matches cfg_addr = DIR*W + t)
    localparam int DIR_N = 0;
    localparam int DIR_S = 1;
    localparam int DIR_E = 2;
    localparam int DIR_W = 3;

    // ---- per-(DIR,t) disjoint select config (packed: 4*W selects x 2 bits) ----
    logic [NSEL*DW-1:0] sel_r;
    // ---- routable CB (bidirectional): per-clb_out inject enable + direction ----
    //   inj_en_r[j] : 1 = inject clb_out[j] onto out_D[j] (D = inj_dir_r[j])
    //   inj_dir_r[j]: 0=N, 1=S, 2=E, 3=W (== DIR_* codes). One direction per j
    //                 -> SB stays the single driver of every track (no multi-drive).
    logic [NINJ-1:0]   inj_en_r;
    logic [NINJ*2-1:0] inj_dir_r;

    // ---- config write (no reset; OCC configures before run) ----
    //   addr 0..NSEL-1      -> sel_r (2-bit disjoint select)
    //   addr NSEL..SB_END-1 -> inj_en_r[addr-NSEL] <- data[0]; inj_dir_r[..] <- data[2:1]
    always_ff @(posedge clk_i) begin
        if (cfg_we_i) begin
            if (cfg_addr_i < SEL_END) begin
                sel_r[cfg_addr_i*DW +: DW] <= cfg_data_i[DW-1:0];
            end else if (cfg_addr_i < SB_END) begin
                inj_en_r[int'(cfg_addr_i) - int'(SEL_END)]             <= cfg_data_i[0];
                inj_dir_r[(int'(cfg_addr_i) - int'(SEL_END))*2 +: 2]   <= cfg_data_i[2:1];
            end
        end
    end

    // ---- disjoint unidirectional routing muxes (combinational) ----
    // For output direction d, sel 1/2/3 select the same-index (t) input track
    // of the 3 OTHER directions in ascending dir-index order; sel 0 disconnects
    // (drives 1'b0). Structural comb loops arise only when SBs are chained in
    // fabric_top (legal virtual routing, C01 §2.4 problem 2 / §3.3) — scoped
    // UNOPTFLAT waiver wraps the mux-output region, mirroring clb_t.sv.
    /* verilator lint_off UNOPTFLAT */
    genvar gt;
    generate
        // Bidirectional inject: for each dir D and track t<N_INJ, if inj_en_r[t]
        // and inj_dir_r[t]==D, out_D[t] = clb_out_i[t] (overrides disjoint sel).
        // inj_dir encoding: 0=N(out_n), 1=S(out_s), 2=E(out_e), 3=W(out_w).
        // out_n[t] (DIR_N): disjoint sources S,E,W; inject when inj_dir==N(0)
        for (gt = 0; gt < W; gt = gt + 1) begin : gen_n
            if (gt < N_INJ) begin : gen_n_inj
                assign out_n[gt] = (inj_en_r[gt] && (inj_dir_r[gt*2 +: 2] == 2'd0)) ? clb_out_i[gt] :
                                   (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd1) ? in_s[gt] :
                                   (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd2) ? in_e[gt] :
                                   (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end else begin : gen_n_disj
                assign out_n[gt] = (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd1) ? in_s[gt] :
                                   (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd2) ? in_e[gt] :
                                   (sel_r[(DIR_N*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end
        end
        // out_s[t] (DIR_S): disjoint sources N,E,W; inject when inj_dir==S(1)
        for (gt = 0; gt < W; gt = gt + 1) begin : gen_s
            if (gt < N_INJ) begin : gen_s_inj
                assign out_s[gt] = (inj_en_r[gt] && (inj_dir_r[gt*2 +: 2] == 2'd1)) ? clb_out_i[gt] :
                                   (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd2) ? in_e[gt] :
                                   (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end else begin : gen_s_disj
                assign out_s[gt] = (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd2) ? in_e[gt] :
                                   (sel_r[(DIR_S*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end
        end
        // out_e[t] (DIR_E): disjoint sources N,S,W; inject when inj_dir==E(2)
        for (gt = 0; gt < W; gt = gt + 1) begin : gen_e
            if (gt < N_INJ) begin : gen_e_inj
                assign out_e[gt] = (inj_en_r[gt] && (inj_dir_r[gt*2 +: 2] == 2'd2)) ? clb_out_i[gt] :
                                   (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd2) ? in_s[gt] :
                                   (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end else begin : gen_e_disj
                assign out_e[gt] = (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd2) ? in_s[gt] :
                                   (sel_r[(DIR_E*W + gt)*DW +: DW] == 2'd3) ? in_w[gt] : 1'b0;
            end
        end
        // out_w[t] (DIR_W): disjoint sources N,S,E; inject when inj_dir==W(3)
        for (gt = 0; gt < W; gt = gt + 1) begin : gen_w
            if (gt < N_INJ) begin : gen_w_inj
                assign out_w[gt] = (inj_en_r[gt] && (inj_dir_r[gt*2 +: 2] == 2'd3)) ? clb_out_i[gt] :
                                   (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd2) ? in_s[gt] :
                                   (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd3) ? in_e[gt] : 1'b0;
            end else begin : gen_w_disj
                assign out_w[gt] = (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd1) ? in_n[gt] :
                                   (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd2) ? in_s[gt] :
                                   (sel_r[(DIR_W*W + gt)*DW +: DW] == 2'd3) ? in_e[gt] : 1'b0;
            end
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */

endmodule

`default_nettype wire
