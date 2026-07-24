`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      clb_t
// Description: Configurable Logic Block tile — N eLUT4 + IIB input crossbar.
// Details:     The v1 fabric placement unit. N eLUT4 (default 8) are fed by an
//              IIB (Input Interconnect Block): a parameterized FULL-INPUT
//              CROSSBAR where each of the N*K LUT inputs is a mux selecting any
//              of the I = EXT_IN + N cluster inputs (external inputs + N
//              feedback from the LUT outputs). The N LUT outputs feed back into
//              the pool, so combinational feedback (virtual latches / loops) is
//              legal at the user-logic level — this forms a structural
//              combinational loop, suppressed by a scoped UNOPTFLAT waiver
//              (C01 §2.4 problem 2).
//
//              cfg addressing (frozen v1, C01 §2.3):
//                cfg_addr 0..N-1       -> eLUT4 #(addr): loads cfg_data[19:0]
//                cfg_addr N..N+N*K-1   -> IIB mux #(addr-N): loads cfg_data[SELW-1:0]
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB2)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §2
// Notes:       ASSUMPTION (TBD 2026-07-24): v1 IIB is a FLAT full-input
//              crossbar (N*K muxes, each I:1). C01 §2.2/§2.4 mention a two-level
//              Clos (26->16->4); that is the v2 area optimization (§2.5
//              Landy/Stitt). The flat crossbar is the only reading consistent
//              with the FROZEN cfg interface (N*K mux points, no stage-1 config)
//              and is a SUPERSET of Clos connectivity (guarantees the
//              "any input -> any LUT input" acceptance). Swapping to Clos later
//              only changes mux-array internals — the cfg interface is invariant.
//              Per-elut FF clock-enable (cfg_ce_i) is tied to 1'b1 at CLB level
//              (no CLB-level CE in the frozen §2.3 interface); per-bit CE
//              routing is deferred. C01's "low 6 bits" per mux is the field
//              budget; v1 uses SELW=$clog2(POOL)=5 bits for I=26 (1 reserved).

module clb_t #(
    parameter int N      = 8,    // eLUT4 count per cluster
    parameter int K      = 4,    // eLUT4 input width
    parameter int EXT_IN = 18    // external cluster inputs (from CB)
) (
    input  logic              clk_i,
    input  logic              rst_ni,
    input  logic [EXT_IN-1:0] clb_in_i,
    output logic [N-1:0]      clb_out_o,
    input  logic              cfg_we_i,
    input  logic [5:0]        cfg_addr_i,
    input  logic [31:0]       cfg_data_i
);
    // Scoped UNOPTFLAT waiver (module scope): the CLB feedback
    // (clb_out_o -> pool -> eLUTs -> clb_out_o) is intended virtual logic
    // (C01 §2.4 problem 2). At module scope so it covers the port signal the
    // lint tool attributes the cycle to.
    /* verilator lint_off UNOPTFLAT */
    // ---- derived parameters ----
    localparam int I    = EXT_IN + N;              // total cluster inputs (26)
    localparam int NK   = N * K;                   // LUT-input mux count (32)
    localparam int POOL = 1 << $clog2(I);          // pow2 >= I (32): index space
    localparam int SELW = $clog2(POOL);            // mux select width (5)
    localparam int AW   = 6;                       // cfg_addr width (frozen)
    localparam logic [AW-1:0] LUT_END = AW'(N);           // 8
    localparam logic [AW-1:0] MUX_END = AW'(N + NK);      // 40

    // cfg_data_i is 32-bit per the frozen C01 §2.3 interface; only [19:0]
    // (eLUT) / [SELW-1:0] (mux) are used. Sink the reserved upper bits so the
    // lint tool does not flag them unused.
    logic _unused_ok;
    assign _unused_ok = ^{cfg_data_i[31:20]};

    // ---- IIB mux-select configuration (packed: NK selects x SELW bits) ----
    logic [NK*SELW-1:0] mux_sel_r;

    // ---- per-eLUT config-write decode (1-hot over the N LUTs) ----
    logic [N-1:0] lut_cfg_we;
    always_comb begin
        lut_cfg_we = '0;
        if (cfg_we_i && (cfg_addr_i < LUT_END)) begin
            lut_cfg_we[cfg_addr_i[$clog2(N)-1:0]] = 1'b1;
        end
    end

    // ---- IIB mux-select config write ----
    always_ff @(posedge clk_i) begin
        if (cfg_we_i && (cfg_addr_i >= LUT_END) && (cfg_addr_i < MUX_END)) begin
            mux_sel_r[(int'(cfg_addr_i) - int'(LUT_END))*SELW +: SELW] <= cfg_data_i[SELW-1:0];
        end
    end

    // ---- cluster input pool + LUT-input wiring + eLUTs (combinational w/ feedback) ----
    // The pool depends on clb_out_o, which depends on the LUTs, which depend on
    // the pool -> structural combinational loop. Scoped UNOPTFLAT waiver per
    // C01 §2.4 problem 2 (virtual combinational loops are legal user logic).
    /* verilator lint_off UNOPTFLAT */
    logic [POOL-1:0] pool;
    always_comb begin
        pool        = '0;
        pool[I-1:0] = {clb_out_o, clb_in_i}; // [0..EXT_IN-1]=ext, [EXT_IN..I-1]=fb
    end

    logic [N-1:0][K-1:0] lut_in;
    genvar gi, gk;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_lut
            for (gk = 0; gk < K; gk = gk + 1) begin : gen_in
                assign lut_in[gi][gk] = pool[mux_sel_r[(gi*K + gk)*SELW +: SELW]];
            end
            elut4 u_elut (
                .clk_i      (clk_i),
                .rst_ni     (rst_ni),
                .vin_i      (lut_in[gi]),
                .vout_o     (clb_out_o[gi]),
                .cfg_we_i   (lut_cfg_we[gi]),
                .cfg_data_i (cfg_data_i[19:0]),
                .cfg_ce_i   (1'b1)
            );
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */

endmodule

`default_nettype wire
