`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      clb_t
// Description: Configurable Logic Block tile — N eLUT4 + IIB input crossbar.
// Details:     The v2c fabric placement unit. N eLUT4 (default 8) are fed by an
//              IIB (Input Interconnect Block): the FROZEN v2c feedback-first
//              depopulated crossbar (interconnect-config-v0 §7.2). Every one of
//              the N*K LUT-input muxes keeps ALL N feedback entries (the
//              intra-cluster critical connectivity); only the EXT_IN external
//              inputs are depopulated BY PARITY: mux m = gi*K + gk sees ext
//              pin i iff i%2 == pi(m) = m%2 = gk%2 (9 of 18). The pool is
//              REORGANIZED so every select is pure bit-slicing (no adders):
//                pool[17:0]  = clb_in_i  (external inputs)
//                pool[23:18] = 0         (padding)
//                pool[31:24] = clb_out_o (feedback j at pool[24+j] = {2'b11, j})
//              Select encoding (5 bits, slice-only):
//                sel[4]=1: ext pin {sel[3:0], pi(m)} = 2*sel[3:0] + pi(m)
//                          (legal sel[3:0] = 0..8; 9..15 read padding/fb —
//                          reserved, MUST NOT be programmed, §7.2)
//                sel[4]=0: feedback j = sel[2:0] at pool[{2'b11, j}]
//                          (sel[3] don't-care; sel=0 blank/zero-init = fb j=0)
//              The N LUT outputs feed back into the pool, so combinational
//              feedback (virtual latches / loops) is legal at the user-logic
//              level — this forms a structural combinational loop, suppressed
//              by a scoped UNOPTFLAT waiver (C01 §2.4 problem 2).
//
//              cfg addressing (frozen v1, C01 §2.3; unchanged by v2c):
//                cfg_addr 0..N-1       -> eLUT4 #(addr): loads cfg_data[19:0]
//                cfg_addr N..N+N*K-1   -> IIB mux #(addr-N): loads cfg_data[4:0]
//              (32 IIB points x 5 bits = 160 bits/tile — count unchanged from
//              v1.1; semantics + pool layout changed per §7.2.)
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB2)
//              2026-09-02 - interconnect v2c IIB (E2-FAB5, FROZEN spec §7.2):
//                            feedback-full + ext parity-halved pool, slice-only
//                            5-bit select decode. Port of the validated
//                            prototype generated/icopt/rtl/clb_t_fbfull.sv
//                            (930-check TB). eLUT4 part unchanged.
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/fabric/interconnect-config-v0.md §7.2 (v2c FROZEN) ·
//              ethereal-plan/components/C01-fabric-核心单元.md §2
// Notes:       Reachability invariants (§7.2, mapper contract): R1 every feedback
//              j reaches every LUT input; R2 ext pin i reaches a LUT only through
//              its two same-parity pin slots; R3 each LUT has exactly 2 pin slots
//              per parity class. v1.1->v2c sel translation: fb p=18+j -> sel=j;
//              ext p (0..17) legal iff p%2==pi(m) -> sel = 16 + floor(p/2).
//              Per-elut FF clock-enable (cfg_ce_i) is tied to 1'b1 at CLB level
//              (no CLB-level CE in the frozen §2.3 interface); per-bit CE
//              routing is deferred.
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
    localparam int NK   = N * K;                   // LUT-input mux count (32)
    localparam int SELW = 5;                       // §7.2: 16-entry ext class + 8 fb
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

    // ---- cluster input pool (§7.2 layout) + LUT-input wiring + eLUTs ----
    // (combinational w/ feedback)
    // The pool depends on clb_out_o, which depends on the LUTs, which depend on
    // the pool -> structural combinational loop. Scoped UNOPTFLAT waiver per
    // C01 §2.4 problem 2 (virtual combinational loops are legal user logic).
    /* verilator lint_off UNOPTFLAT */
    logic [31:0] pool;
    always_comb begin
        pool             = '0;
        pool[EXT_IN-1:0] = clb_in_i;   // ext inputs at [0..EXT_IN-1] = [17:0]
        pool[24 +: N]    = clb_out_o;  // feedback j at [24..31] = {2'b11, j}; [23:18] = padding 0
    end

    logic [N-1:0][K-1:0] lut_in;
    genvar gi, gk;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : gen_lut
            for (gk = 0; gk < K; gk = gk + 1) begin : gen_in
                localparam int M = gi*K + gk;
                localparam logic PARITY = (M % 2) != 0;   // pi(m) = m%2 = gk%2 (K even)
                logic [SELW-1:0] sel;
                assign sel = mux_sel_r[M*SELW +: SELW];
                // §7.2 slice-only decode (no adders):
                //   sel[4]=1: ext pin {sel[3:0], PARITY} = 2*sel[3:0]+pi(m)
                //             (sel[3:0]>=9 reads padding/fb — reserved, §7.2)
                //   sel[4]=0: feedback pool[{2'b11, sel[2:0]}] (all N fb visible)
                assign lut_in[gi][gk] = sel[SELW-1]
                    ? pool[{sel[3:0], PARITY}]
                    : pool[{2'b11, sel[2:0]}];
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
