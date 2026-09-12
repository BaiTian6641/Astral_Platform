`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_fpu
// Description: IEEE-754 binary32/binary64 unit for eth_rv (F/D), start/valid handshake.
// Details:     One unit for the whole F and D extension: arithmetic (add, subtract,
//              multiply, divide, square root and the four fused multiply-add
//              forms), sign injection, min/max, the three comparisons, classify,
//              the register moves and every conversion form. The RTL mirrors the
//              algorithms of the golden model's SoftFloat (the Berkeley SoftFloat
//              copy inside the pinned Spike), so the *results*, the `fflags`
//              accrual and the NaN / infinity / zero-sign corner cases agree by
//              construction rather than by hope:
//
//                * every finite input is unpacked to an EXACT (sign, significand
//                  integer, exponent-of-LSB) triple. Subnormals, zeros and the
//                  (un)boxed single-precision values need no special datapath: they
//                  are just small or zero significands.
//                * add / subtract / multiply / multiply-add are ONE exact
//                  fixed-point datapath: the 106-bit product of the two 53-bit
//                  significands is aligned with the third operand in a 192-bit
//                  window whose bottom sits far below the rounding position (an
//                  operand that falls outside degrades to a sticky bit, which is
//                  far too low to affect the rounding), and the exact sum is
//                  rounded ONCE. That is what makes the fused forms
//                  single-rounded (a multiply-then-add pair is not) and it removes
//                  every double-rounding question.
//                * divide is a 58-step restoring division of the normalized
//                  significands; square root is a 60-step restoring digit-by-digit
//                  root. Both deliver the exact leading bits plus a sticky bit, so
//                  the same single rounding step finishes them.
//                * the rounding step (extract / round / carry / normalize) is
//                  shared and takes the target precision as DATA: the S forms use
//                  the identical datapath with binary32's P = 24 and exponent
//                  limits, so no single-precision operation is ever produced by
//                  rounding a double result (the classic double-rounding trap of
//                  `fmadd.s` and `fcvt.s.d`). Tininess is detected after rounding,
//                  this Spike build's `init_detectTininess`.
//                * the special cases are decided BEFORE the datapath from
//                  SoftFloat's own case analysis: a NaN result is always the
//                  canonical NaN (`ffff_ffff_7fc0_0000` boxed for S), the sign of
//                  an exact zero follows the operation rule (round-toward-minus
//                  gives -0), `0 * inf` and `inf - inf` raise NV, a finite value
//                  divided by zero raises DZ.
//
//              Handshake: `start_i` latches the decoded operation and the three
//              operands; `valid_o` pulses one cycle with `result_o`/`fflags_o`
//              valid. Everything but divide (60 cycles) and square root (62)
//              completes in the second cycle. The core stalls EX until `valid_o`,
//              exactly like the M extension's cor_muldiv.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (EX stage, F/D),
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Behavioral (ADR-017): the significand multiply is written as a plain
//              `*` on widened operands for the platform EDA to infer; no vendor DSP
//              primitives, no `real`, no unsynthesizable tasks. Barrel shifts and
//              leading-zero counters are `generate`-free pure functions and
//              variable part-selects (G1: no procedural loops in `always_*`).
module cor_fpu (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               start_i,      // one-cycle launch pulse
    input  eth_rv_pkg::fp_op_e op_i,
    input  logic               single_i,     // destination/operand format is binary32
    input  logic               src_single_i, // FP->FP cvt: the SOURCE is binary32
    input  logic [1:0]         iw_i,         // cvt integer form: 0=w 1=wu 2=l 3=lu
    input  logic [2:0]         rm_i,         // validated rounding mode (0..4)
    input  logic [63:0]        a_i,          // rs1 raw (FP bits, or the integer source)
    input  logic [63:0]        b_i,          // rs2 raw (FP bits)
    input  logic [63:0]        c_i,          // rs3 raw (fused forms)
    output logic [63:0]        result_o,     // valid in the cycle `valid_o` is high
    output logic [4:0]         fflags_o,     // NV DZ OF UF NX, as `fflags`
    output logic               valid_o
);

    localparam int unsigned W        = 192;   // alignment / summation window
    localparam int unsigned P_D      = 53;
    localparam int unsigned P_S      = 24;
    localparam int unsigned KEEP_D   = P_D + 2;   // significand + guard + round
    localparam int unsigned KEEP_S   = P_S + 2;
    localparam int unsigned DIV_ITERS = 58;
    localparam int unsigned SQRT_ITERS = 60;

    localparam logic signed [15:0] D_EMIN = -16'sd1022;
    localparam logic signed [15:0] S_EMIN = -16'sd126;
    localparam logic signed [15:0] D_EMAX = 16'sd1023;
    localparam logic signed [15:0] S_EMAX = 16'sd127;
    localparam logic signed [15:0] D_BIAS = 16'sd1023;
    localparam logic signed [15:0] S_BIAS = 16'sd127;

    localparam logic [63:0] D_QNAN = 64'h7ff8_0000_0000_0000;
    localparam logic [63:0] S_QNAN = 64'hffff_ffff_7fc0_0000;

    localparam logic [4:0] FF_NX = 5'h01;
    localparam logic [4:0] FF_UF = 5'h02;
    localparam logic [4:0] FF_OF = 5'h04;
    localparam logic [4:0] FF_DZ = 5'h08;
    localparam logic [4:0] FF_NV = 5'h10;

    // =====================================================================
    // canonical operand record and its unpackers
    // =====================================================================
    typedef struct packed {
        logic               sign;
        logic [59:0]        mant;     // exact significand (integer), 0 when zero
        logic signed [15:0] e;        // value = mant * 2**e
        logic               is_zero;
        logic               is_inf;
        logic               is_nan;
        logic               is_snan;
    } fp_u_t;

    // The sign + exact magnitude triple alone: what the arithmetic datapath needs.
    typedef struct packed {
        logic               sign;
        logic [59:0]        mant;
        logic signed [15:0] e;
    } fp_mag_t;
    // ---- fclass (SoftFloat's classify, RISC-V's ten bits) ----
    // Bit 0 is -inf and bit 9 is a quiet NaN. The operand is the UNBOXED value, so
    // an unboxed single-precision register classifies as qNaN, exactly like Spike.
    function automatic logic [9:0] fclass_s(input logic [31:0] x);
        logic [7:0]  ef;
        logic [22:0] frac;
        begin
            ef   = x[30:23];
            frac = x[22:0];
            if (ef == 8'hff) begin
                if (frac == 23'd0) fclass_s = x[31] ? 10'h001 : 10'h080;
                else               fclass_s = frac[22] ? 10'h200 : 10'h100;
            end else if (ef == 8'd0) begin
                if (frac == 23'd0) fclass_s = x[31] ? 10'h008 : 10'h010;
                else               fclass_s = x[31] ? 10'h004 : 10'h020;
            end else begin
                fclass_s = x[31] ? 10'h002 : 10'h040;
            end
        end
    endfunction

    function automatic logic [9:0] fclass_d(input logic [63:0] x);
        logic [10:0] ef;
        logic [51:0] frac;
        begin
            ef   = x[62:52];
            frac = x[51:0];
            if (ef == 11'h7ff) begin
                if (frac == 52'd0) fclass_d = x[63] ? 10'h001 : 10'h080;
                else               fclass_d = frac[51] ? 10'h200 : 10'h100;
            end else if (ef == 11'd0) begin
                if (frac == 52'd0) fclass_d = x[63] ? 10'h008 : 10'h010;
                else               fclass_d = x[63] ? 10'h004 : 10'h020;
            end else begin
                fclass_d = x[63] ? 10'h002 : 10'h040;
            end
        end
    endfunction
    function automatic fp_u_t unpack_d(input logic [63:0] x);
        fp_u_t       r;
        logic [10:0] ef;
        logic [51:0] frac;
        begin
            ef   = x[62:52];
            frac = x[51:0];
            r.sign = x[63];
            r.mant = 60'd0;
            r.e    = 16'sd0;
            r.is_zero = 1'b0;
            r.is_inf  = 1'b0;
            r.is_nan  = 1'b0;
            r.is_snan = 1'b0;
            if (ef == 11'h7ff) begin
                if (frac == 52'd0) begin
                    r.is_inf = 1'b1;
                end else begin
                    r.is_nan  = 1'b1;
                    r.is_snan = ~frac[51];
                end
            end else if (ef == 11'd0) begin
                if (frac == 52'd0) begin
                    r.is_zero = 1'b1;
                end else begin
                    r.mant = {8'd0, frac};
                    r.e    = -16'sd1074;
                end
            end else begin
                r.mant = {7'd0, 1'b1, frac};
                r.e    = $signed({5'd0, ef}) - 16'sd1075;
            end
            unpack_d = r;
        end
    endfunction

    function automatic fp_u_t unpack_s(input logic [31:0] x);
        fp_u_t       r;
        logic [7:0]  ef;
        logic [22:0] frac;
        begin
            ef   = x[30:23];
            frac = x[22:0];
            r.sign = x[31];
            r.mant = 60'd0;
            r.e    = 16'sd0;
            r.is_zero = 1'b0;
            r.is_inf  = 1'b0;
            r.is_nan  = 1'b0;
            r.is_snan = 1'b0;
            if (ef == 8'hff) begin
                if (frac == 23'd0) begin
                    r.is_inf = 1'b1;
                end else begin
                    r.is_nan  = 1'b1;
                    r.is_snan = ~frac[22];
                end
            end else if (ef == 8'd0) begin
                if (frac == 23'd0) begin
                    r.is_zero = 1'b1;
                end else begin
                    r.mant = {37'd0, frac};
                    r.e    = -16'sd149;
                end
            end else begin
                r.mant = {36'd0, 1'b1, frac};
                r.e    = $signed({8'd0, ef}) - 16'sd150;
            end
            unpack_s = r;
        end
    endfunction

    function automatic logic [63:0] pack_d(input logic sign, input logic [10:0] ef,
                                           input logic [51:0] frac);
        pack_d = {sign, ef, frac};
    endfunction

    function automatic logic [63:0] pack_s(input logic sign, input logic [7:0] ef,
                                           input logic [22:0] frac);
        pack_s = {32'hffff_ffff, sign, ef, frac};
    endfunction

    // A single-precision register is NaN-boxed when its upper half is all ones;
    // an unboxed one reads as the canonical NaN (Spike's `unboxF32`).
    function automatic logic [31:0] unbox32(input logic [63:0] x);
        unbox32 = (x[63:32] == 32'hffff_ffff) ? x[31:0] : 32'h7fc0_0000;
    endfunction
    // ---- leading-zero helpers (pure functions: no procedural loops) ----
    function automatic logic [4:0] clz16(input logic [15:0] v);
        begin
            if      (v[15]) clz16 = 5'd0;
            else if (v[14]) clz16 = 5'd1;
            else if (v[13]) clz16 = 5'd2;
            else if (v[12]) clz16 = 5'd3;
            else if (v[11]) clz16 = 5'd4;
            else if (v[10]) clz16 = 5'd5;
            else if (v[9])  clz16 = 5'd6;
            else if (v[8])  clz16 = 5'd7;
            else if (v[7])  clz16 = 5'd8;
            else if (v[6])  clz16 = 5'd9;
            else if (v[5])  clz16 = 5'd10;
            else if (v[4])  clz16 = 5'd11;
            else if (v[3])  clz16 = 5'd12;
            else if (v[2])  clz16 = 5'd13;
            else if (v[1])  clz16 = 5'd14;
            else if (v[0])  clz16 = 5'd15;
            else            clz16 = 5'd16;
        end
    endfunction

    function automatic logic [7:0] clz192(input logic [W-1:0] v);
        begin
            if      (v[191:176] != 16'd0) clz192 = {3'd0, clz16(v[191:176])};
            else if (v[175:160] != 16'd0) clz192 = 8'(9'd16  + {4'd0, clz16(v[175:160])});
            else if (v[159:144] != 16'd0) clz192 = 8'(9'd32  + {4'd0, clz16(v[159:144])});
            else if (v[143:128] != 16'd0) clz192 = 8'(9'd48  + {4'd0, clz16(v[143:128])});
            else if (v[127:112] != 16'd0) clz192 = 8'(9'd64  + {4'd0, clz16(v[127:112])});
            else if (v[111:96]  != 16'd0) clz192 = 8'(9'd80  + {4'd0, clz16(v[111:96])});
            else if (v[95:80]   != 16'd0) clz192 = 8'(9'd96  + {4'd0, clz16(v[95:80])});
            else if (v[79:64]   != 16'd0) clz192 = 8'(9'd112 + {4'd0, clz16(v[79:64])});
            else if (v[63:48]   != 16'd0) clz192 = 8'(9'd128 + {4'd0, clz16(v[63:48])});
            else if (v[47:32]   != 16'd0) clz192 = 8'(9'd144 + {4'd0, clz16(v[47:32])});
            else if (v[31:16]   != 16'd0) clz192 = 8'(9'd160 + {4'd0, clz16(v[31:16])});
            else                          clz192 = 8'(9'd176 + {4'd0, clz16(v[15:0])});
        end
    endfunction

    // =====================================================================
    // latched operation
    // =====================================================================
    typedef enum logic [1:0] { ST_IDLE = 2'd0, ST_WORK = 2'd1, ST_DONE = 2'd2 } st_e;

    st_e                 st_r;
    eth_rv_pkg::fp_op_e  op_r;
    logic                single_r;
    logic                src_single_r;
    logic [1:0]          iw_r;
    logic [2:0]          rm_r;
    logic [63:0]         a_r, b_r, c_r;
    logic [63:0]         res_r;
    logic [4:0]          ff_r;

    logic [6:0]          cnt_r;
    logic                run_r;

    logic [55:0]         dv_rem_r;
    logic [59:0]         dv_quot_r;
    logic [52:0]         dv_div_r;
    logic signed [15:0]  dv_e_r;
    logic                dv_sign_r;

    logic [119:0]        sq_rad_r;
    logic [59:0]         sq_root_r;
    logic [63:0]         sq_rem_r;
    logic signed [15:0]  sq_e_r;
    logic                sq_sign_r;

    // =====================================================================
    // operand values the operation actually sees
    // =====================================================================
    // For binary32 operands Spike UNBOXES first (`f32(READ_FREG)`: a register whose
    // upper 32 bits are not all ones reads as the canonical NaN), and for the
    // FP->FP conversion the source format is the *source*, not the destination.
    logic        src_s;
    logic [63:0] a_v, b_v, c_v;
    fp_u_t       ua, ub, uc, usrc;

    assign src_s = (op_r == eth_rv_pkg::FP_CVT_FP_FP) ? src_single_r : single_r;

    always_comb begin
        a_v = a_r;
        b_v = b_r;
        c_v = c_r;
        if (src_s) begin
            a_v = {32'd0, unbox32(a_r)};
            b_v = {32'd0, unbox32(b_r)};
            c_v = {32'd0, unbox32(c_r)};
        end
        if (src_s) begin
            ua = unpack_s(a_v[31:0]);
            ub = unpack_s(b_v[31:0]);
            uc = unpack_s(c_v[31:0]);
            usrc = unpack_s(a_v[31:0]);
        end else begin
            ua = unpack_d(a_v);
            ub = unpack_d(b_v);
            uc = unpack_d(c_v);
            usrc = unpack_d(a_v);
        end
    end

    // =====================================================================
    // exact fixed-point datapath:  +-(a*b) + +-(c)     (also add / sub / mul)
    // =====================================================================
    logic                prod_neg, add_neg;   // effective sign folds
     fp_mag_t             a_eff, c_eff;
    logic [59:0]         bmul_mant;
    logic signed [15:0]  bmul_e;
    logic [105:0]        prod;
    logic signed [15:0]  topp, topc, ehi, elo, sp, sc;
    logic [W-1:0]        pp, cc;
    logic                stick_p, stick_c;
    logic [W:0]          sum_ext;
    logic [W-1:0]        wmag;
    logic                wneg, wsticky, pz, cz;
    logic [63:0]         c_eff_bits;

    always_comb begin
        prod_neg = 1'b0;
        add_neg  = 1'b0;
        unique case (op_r)
            eth_rv_pkg::FP_SUB:   add_neg  = 1'b1;
            eth_rv_pkg::FP_MSUB:  add_neg  = 1'b1;
            eth_rv_pkg::FP_NMADD: begin prod_neg = 1'b1; add_neg = 1'b1; end
            eth_rv_pkg::FP_NMSUB: prod_neg = 1'b1;
            default: ;
        endcase
        a_eff.sign = ua.sign ^ prod_neg;
        a_eff.mant = ua.mant;
        a_eff.e    = ua.e;
        c_eff.sign = uc.sign ^ add_neg;
        c_eff.mant = uc.mant;
        c_eff.e    = uc.e;
        if (op_r == eth_rv_pkg::FP_MUL) begin
            // a plain multiply has no addend: rs3 is not part of its encoding, so
            // whatever the register file returned there must be ignored
            c_eff.mant = 60'd0;
        end
        if ((op_r == eth_rv_pkg::FP_ADD) || (op_r == eth_rv_pkg::FP_SUB)) begin
            a_eff.sign = ua.sign;                 // the unit multiplier is unsigned
        end
        if (src_s) begin
            c_eff_bits = {32'hffff_ffff, (c_r[31] ^ add_neg), c_r[30:0]};
        end else begin
            c_eff_bits = {c_r[63] ^ add_neg, c_r[62:0]};
        end
    end

    always_comb begin
        if ((op_r == eth_rv_pkg::FP_ADD) || (op_r == eth_rv_pkg::FP_SUB)) begin
            bmul_mant = 60'd1;
            bmul_e    = 16'sd0;
        end else begin
            bmul_mant = ub.mant;
            bmul_e    = ub.e;
        end
    end

    always_comb begin
        logic [15:0] pm, cm;
        prod = 106'(a_eff.mant) * 106'(bmul_mant);
         pm   = (prod == 106'd0) ? 16'd0
                                : (16'd191 - {8'd0, clz192({86'd0, prod})});
        cm   = (c_eff.mant == 60'd0) ? 16'd0
                                     : (16'd191 - {8'd0, clz192({132'd0, c_eff.mant})});
        topp = (prod == 106'd0) ? 16'sd0
                                : ($signed(a_eff.e) + $signed(bmul_e) + $signed(pm));
        topc = (c_eff.mant == 60'd0) ? 16'sd0 : ($signed(c_eff.e) + $signed(cm));
        if ((prod == 106'd0) && (c_eff.mant == 60'd0)) begin
            ehi = 16'sd0;
        end else if (prod == 106'd0) begin
            ehi = topc;
        end else if (c_eff.mant == 60'd0) begin
            ehi = topp;
        end else begin
            ehi = (topp > topc) ? topp : topc;
        end
        elo = ehi - 16'sd190;
        sp  = (prod == 106'd0) ? 16'sd0 : ($signed(a_eff.e) + $signed(bmul_e) - elo);
        sc  = (c_eff.mant == 60'd0) ? 16'sd0 : ($signed(c_eff.e) - elo);
        pp  = {W{1'b0}};
        cc  = {W{1'b0}};
        stick_p = 1'b0;
        stick_c = 1'b0;
        if (prod != 106'd0) begin
            if (sp < 16'sd0) begin
                stick_p = 1'b1;
            end else begin
                pp = W'(106'(prod)) << sp[7:0];
            end
        end
        if (c_eff.mant != 60'd0) begin
            if (sc < 16'sd0) begin
                stick_c = 1'b1;
            end else begin
                cc = W'(60'(c_eff.mant)) << sc[7:0];
            end
        end
    end

    always_comb begin
        logic [W:0] pp_ext, cc_ext, pp_neg, cc_neg;
        pp_ext = {1'b0, pp};
        cc_ext = {1'b0, cc};
        pp_neg = ~pp_ext + 193'd1;
        cc_neg = ~cc_ext + 193'd1;
        sum_ext = (a_eff.sign ? pp_neg : pp_ext) + (c_eff.sign ? cc_neg : cc_ext);
        wneg    = sum_ext[W];
        wmag    = wneg ? (~sum_ext[W-1:0] + {{(W-1){1'b0}}, 1'b1}) : sum_ext[W-1:0];
        wsticky = stick_p | stick_c;
        pz      = (prod == 106'd0);
        cz      = uc.is_zero;
    end

    // =====================================================================
    // divide: normalized significands, restoring division
    // =====================================================================
    logic [52:0]        dv_na, dv_nb;
    logic signed [15:0] dv_ea, dv_eb;

    always_comb begin
         logic [7:0]  za, zb;
        logic [7:0]  sa, sb;
        za = clz192({132'd0, ua.mant});
        zb = clz192({132'd0, ub.mant});
        if (single_r) begin
            sa = (za > 8'd168) ? (za - 8'd168) : 8'd0;
            sb = (zb > 8'd168) ? (zb - 8'd168) : 8'd0;
        end else begin
            sa = (za > 8'd139) ? (za - 8'd139) : 8'd0;
            sb = (zb > 8'd139) ? (zb - 8'd139) : 8'd0;
        end
        dv_na = 53'(ua.mant) << sa;
        dv_nb = 53'(ub.mant) << sb;
        dv_ea = ua.e - $signed({8'd0, sa});
        dv_eb = ub.e - $signed({8'd0, sb});
    end

    // =====================================================================
    // square root: radicand scaling and exponent
    // =====================================================================
    logic [119:0]       sq_rad_init;
    logic signed [15:0] sq_e_init;

    always_comb begin
        logic [7:0]  za;
        logic [7:0]  sa;
        logic        odd;
        logic [60:0] m2;
        logic signed [15:0] ep;
        za  = clz192({132'd0, ua.mant});
        // shift the significand so its MSB sits at bit P-1: clz192 over the
        // 192-bit field is 192 - bitlen, so the shift is clz - (192 - P).
        sa  = single_r ? ((za > 8'd168) ? (za - 8'd168) : 8'd0)
                       : ((za > 8'd139) ? (za - 8'd139) : 8'd0);
        ep  = ua.e - $signed({8'd0, sa});
        odd = ep[0];
        m2  = 61'(ua.mant) << sa;
        if (odd) begin
            m2 = m2 << 1;
        end
        // the radicand is scaled by an EVEN amount so its bit length lands just
        // under the 120-bit window: binary64 -> 64, binary32 -> 94.
         if (single_r) begin
            sq_rad_init = 120'(m2) << 7'd94;
            sq_e_init   = ((ep - $signed({15'd0, odd})) / 16'sd2) - 16'sd47;
        end else begin
            sq_rad_init = 120'(m2) << 7'd64;
            sq_e_init   = ((ep - $signed({15'd0, odd})) / 16'sd2) - 16'sd32;
        end
    end

    // =====================================================================
    // rounding: exact (sign, mant, e, sticky) -> packed result + flags
    // =====================================================================
    logic [63:0]        f2i_res;
    logic [4:0]         f2i_ff;
    logic [63:0]        int_src;
    logic               int_neg;
    logic [63:0]        int_mag;

    logic [63:0]        rnd_res;
    logic [4:0]         rnd_ff;

    always_comb begin
        // the integer source of the int -> fp conversions
        if (iw_r[1]) begin
            int_src = a_r;
        end else if (iw_r[0]) begin
            int_src = {32'd0, a_r[31:0]};
        end else begin
            int_src = {{32{a_r[31]}}, a_r[31:0]};
        end
        int_neg = ~iw_r[0] && int_src[63];
        int_mag = int_neg ? (~int_src + 64'd1) : int_src;
    end

    always_comb begin
        // The rounder's inputs are resolved HERE, in the same block that consumes
        // them: a separate always_comb driving them would be read one delta stale by
        // this one (the adder, the divider, the root and the conversions each hand
        // the rounder a different magnitude).
        logic               rf_sign, rf_sticky, rf_single, rf_zero_rm;
        logic [W-1:0]       rf_mant;
        logic signed [15:0] rf_e;
        logic signed [15:0] emin, emax, bias;
        logic [15:0]        plen, keep;
        logic signed [15:0] msb_e;
        logic signed [15:0] sh;
        logic [7:0]         shr_l;
         logic [KEEP_D-1:0]  kept_w;
        logic [KEEP_D-1:0]  kept;
        logic [15:0]        rnm;
        logic               guard, rndbit, stk, inc, carry, inex;
        logic [P_D-1:0]     sigp;
        logic [P_D:0]       sigc;
        logic signed [15:0] eres;
        logic [P_D:0]       sub_sig;
        logic               normal_result;
         logic               ext_sticky;
        logic [KEEP_D:0]    fine_sum;
        logic               fine_inc, fine_carry;

        // The result's sign is the DOMINANT operand's: `wneg` says the addend won
        // the magnitude fight in the adder, so the product's sign only survives
        // when it did not. (Getting this wrong flips `fmadd` by a sign bit
        // whenever |c| > |a*b| and the two have opposite signs.)
        // For every add/subtract/multiply/fused form the sign of a NONZERO result is
        // simply the sign of the exact sum, which the 2's-complement adder already
        // carries in `wneg` — the product's sign and the addend's sign are both
        // folded in before the addition, so no "which operand won" rule is needed
        // (and any such rule loses a sign bit whenever the product dominates with
        // the opposite sign to the addend). The exact-zero cases never reach here:
        // a zero product takes the special-case path above, and a genuine
        // cancellation lands in the packer's zero branch with the rm sign rule.
        rf_sign    = wneg;
        rf_mant    = wmag;
        rf_e       = elo;
        rf_sticky  = wsticky;
        rf_single  = single_r;
        rf_zero_rm = 1'b1;          // arith/fused: an exact zero follows the rm rule
        if (op_r == eth_rv_pkg::FP_DIV) begin
            rf_sign    = dv_sign_r;
            rf_mant    = {132'd0, dv_quot_r};
            rf_e       = dv_e_r;
            rf_sticky  = (dv_rem_r != 56'd0);
            rf_zero_rm = 1'b0;
        end else if (op_r == eth_rv_pkg::FP_SQRT) begin
            rf_sign    = sq_sign_r;
            rf_mant    = {132'd0, sq_root_r};
            rf_e       = sq_e_r;
            rf_sticky  = (sq_rem_r != 64'd0);
            rf_zero_rm = 1'b0;
        end else if (op_r == eth_rv_pkg::FP_CVT_I_FP) begin
            rf_sign    = int_neg;
            rf_mant    = {128'd0, int_mag};
            rf_e       = 16'sd0;
            rf_sticky  = 1'b0;
            rf_zero_rm = 1'b0;
        end else if (op_r == eth_rv_pkg::FP_CVT_FP_FP) begin
            rf_sign    = usrc.sign;
            rf_mant    = {132'd0, usrc.mant};
            rf_e       = usrc.e;
            rf_sticky  = 1'b0;
            rf_zero_rm = 1'b0;
        end

        // Defaults FIRST (G1): a local that is only assigned inside one branch
        // would otherwise infer a latch — yosys rejects the design outright and
        // a lint-only flow would hide it.
        inc       = 1'b0;
        inex      = 1'b0;
        carry     = 1'b0;
        guard     = 1'b0;
        rndbit    = 1'b0;
        stk       = 1'b0;
        sigp      = {P_D{1'b0}};
        sigc      = {(P_D+1){1'b0}};
        eres      = 16'sd0;
        sub_sig   = {(P_D+1){1'b0}};
        normal_result = 1'b0;
        fine_inc  = 1'b0;
        fine_carry = 1'b0;
        fine_sum  = {(KEEP_D+1){1'b0}};

        emin = rf_single ? S_EMIN : D_EMIN;
        emax = rf_single ? S_EMAX : D_EMAX;
        bias = rf_single ? S_BIAS : D_BIAS;
        plen = rf_single ? 16'd24  : 16'd53;
        keep = rf_single ? 16'd26  : 16'd55;
        // the bit length of THIS operation's exact magnitude — the adder, the
        // divider, the root and the conversions all hand the rounder a different
        // width, so it is measured here and not inherited from the adder
        rnm  = (rf_mant == {W{1'b0}}) ? 16'd0 : (16'd192 - {8'd0, clz192(rf_mant)});

        msb_e = (rnm == 16'd0) ? 16'sd0 : (rf_e + $signed(rnm) - 16'sd1);
        sh    = 16'sd0;
        if (rnm != 16'd0) begin
            if (msb_e >= emin) begin
                sh = $signed(rnm) - keep;
            end else begin
                sh = (emin - plen - 16'sd1) - rf_e;
            end
        end
        kept_w     = KEEP_D'(rf_mant);
        ext_sticky = rf_sticky;
        shr_l      = 8'(16'sd0 - sh);
        if ((rnm != 16'd0) && (sh > 16'sd0)) begin
            if (sh >= $signed(16'd192)) begin
                kept_w     = {KEEP_D{1'b0}};
                ext_sticky = rf_sticky | (rf_mant != {W{1'b0}});
            end else begin
                kept_w     = KEEP_D'(rf_mant >> sh[7:0]);
                ext_sticky = rf_sticky
                             | (|(rf_mant & ((W'(1) << sh[7:0]) - W'(1))));
            end
        end else if ((rnm != 16'd0) && (sh < 16'sd0)) begin
            kept_w = KEEP_D'(rf_mant << shr_l);
        end
        kept = kept_w;

        rnd_res = 64'd0;
        rnd_ff  = 5'd0;
        if (rnm == 16'd0) begin
            logic zsign;
            zsign = rf_zero_rm ? (rm_r == eth_rv_pkg::RM_RDN) : rf_sign;
            rnd_res = rf_single ? pack_s(zsign, 8'd0, 23'd0)
                                 : pack_d(zsign, 11'd0, 52'd0);
        end else begin
            if (rf_single) begin
                sigp   = {29'd0, kept[KEEP_S-1:2]};
                guard  = kept[1];
                rndbit = kept[0];
            end else begin
                sigp   = kept[KEEP_D-1:2];
                guard  = kept[1];
                rndbit = kept[0];
            end
            stk = ext_sticky;
            unique case (rm_r)
                eth_rv_pkg::RM_RNE: inc = guard & (rndbit | stk | sigp[0]);
                eth_rv_pkg::RM_RTZ: inc = 1'b0;
                eth_rv_pkg::RM_RDN: inc = (guard | rndbit | stk) & rf_sign;
                eth_rv_pkg::RM_RUP: inc = (guard | rndbit | stk) & ~rf_sign;
                default:            inc = guard;
            endcase
            inex = guard | rndbit | stk;
            sigc = {1'b0, sigp} + {{P_D{1'b0}}, inc};
            // the carry out of the SIGNIFICAND: bit P of the destination format,
            // which is P_S = 24 for a single result and P_D = 53 for a double one.
            // Using the double width for both loses a binade on every single
            // rounding that overflows (fcvt.s.wu of 2^32-1, fmul.s at a boundary).
            carry = rf_single ? sigc[P_S] : sigc[P_D];
            eres  = msb_e + (carry ? 16'sd1 : 16'sd0);
            if (eres > emax) begin
                logic to_inf;
                unique case (rm_r)
                    eth_rv_pkg::RM_RTZ: to_inf = 1'b0;
                    eth_rv_pkg::RM_RUP: to_inf = ~rf_sign;
                    eth_rv_pkg::RM_RDN: to_inf = rf_sign;
                    default:            to_inf = 1'b1;
                endcase
                rnd_res = rf_single
                          ? (pack_s(rf_sign, 8'hff, 23'd0) - (to_inf ? 64'd0 : 64'd1))
                          : (pack_d(rf_sign, 11'h7ff, 52'd0) - (to_inf ? 64'd0 : 64'd1));
                rnd_ff  = FF_OF | FF_NX;
            end else if (eres >= emin) begin
                rnd_res = rf_single
                          ? pack_s(rf_sign, 8'(eres + bias), sigc[P_S-2:0])
                          : pack_d(rf_sign, 11'(eres + bias), sigc[P_D-2:0]);
                rnd_ff  = inex ? FF_NX : 5'd0;
            end else begin
                // subnormal (or the minimum normal, when the rounding carries into
                // the hidden bit). The significand sits at the subnormal LSB.
                sub_sig       = sigc;
                normal_result = rf_single ? (sub_sig[P_S-1] | sub_sig[P_S])
                                          : (sub_sig[P_D-1] | sub_sig[P_D]);
                if (normal_result) begin
                    rnd_res = rf_single ? pack_s(rf_sign, 8'd1, 23'd0)
                                         : pack_d(rf_sign, 11'd1, 52'd0);
                 end else if (rf_single) begin
                    rnd_res = {32'hffff_ffff, rf_sign, 8'd0, sub_sig[P_S-2:0]};
                end else begin
                    rnd_res = {rf_sign, 11'd0, sub_sig[P_D-2:0]};
                end
                rnd_ff = inex ? FF_NX : 5'd0;
                // tininess after rounding: would the value rounded to `plen`
                // significant bits (unbounded exponent) still be below the minimum
                // normal?  That is exactly "the finer rounding does not carry".
                fine_inc = 1'b0;
                unique case (rm_r)
                    eth_rv_pkg::RM_RNE: fine_inc = kept[0] & (ext_sticky | kept[1]);
                    eth_rv_pkg::RM_RTZ: fine_inc = 1'b0;
                    eth_rv_pkg::RM_RDN: fine_inc = (kept[0] | ext_sticky) & rf_sign;
                    eth_rv_pkg::RM_RUP: fine_inc = (kept[0] | ext_sticky) & ~rf_sign;
                    default:            fine_inc = kept[0];
                endcase
                 fine_sum   = {1'b0, kept[KEEP_D-1:1]} + {{KEEP_D{1'b0}}, fine_inc};
                fine_carry = |(fine_sum >> plen[5:0]);
                if (inex && !fine_carry) begin
                    rnd_ff = rnd_ff | FF_UF;
                end
            end
        end
    end

    // =====================================================================
    // fp -> integer conversions (fcvt.{w,wu,l,lu}.{s,d})
    // =====================================================================
     always_comb begin
        logic signed [15:0] sh, msb_e;
        logic [15:0]        nm;
        logic [7:0]         shl;
        logic [63:0]        mant_ext, mag;
        logic               guard, rndbit, stk, inc, inex, in_range, neg, uns, is32;
        logic [63:0]        sat;
        is32  = ~iw_r[1];
        uns   = iw_r[0];
        neg   = usrc.sign;
        nm    = (usrc.mant == 60'd0) ? 16'd0 : (16'd192 - {8'd0, clz192({132'd0, usrc.mant})});
         // (the magnitude compare below is done on the bit patterns, which order
        // identically for equal-signed non-NaN values)
        msb_e = (nm == 16'd0) ? 16'sd0 : (usrc.e + $signed(nm) - 16'sd1);
        sh    = -usrc.e;
        shl   = 8'(16'sd0 - sh);
        mant_ext = 64'(usrc.mant);
        mag   = 64'd0;
        guard = 1'b0;
        rndbit = 1'b0;
        stk = 1'b0;
        in_range = !usrc.is_nan && !usrc.is_inf;
          if (usrc.is_zero || (nm == 16'd0)) begin
            in_range = !(usrc.is_nan || usrc.is_inf);
        end
        if (usrc.is_nan || usrc.is_inf) begin
            mag = 64'hffff_ffff_ffff_ffff;
        end else if (nm == 16'd0) begin
            mag = 64'd0;
        end else if (sh < 16'sd0) begin
            // A value at or above 2^64 cannot fit ANY of these destinations, and
            // its left-shifted magnitude would silently drop the high bits and
            // then pass the range check. The exponent decides it up front.
            if (((-sh) > 16'sd64) || (msb_e >= 16'sd64)) begin
                in_range = 1'b0;
                mag = 64'hffff_ffff_ffff_ffff;
            end else begin
                mag = mant_ext << shl;
            end
        end else if (sh == 16'sd0) begin
            mag = mant_ext;
        end else if (sh >= 16'sd64) begin
            mag = 64'd0;
            stk = (mant_ext != 64'd0);
        end else begin
            mag = mant_ext >> sh[5:0];
            if (sh == 16'sd1) begin
                guard = mant_ext[0];
            end else begin
                guard  = mant_ext[sh[5:0] - 6'd1];
                rndbit = mant_ext[sh[5:0] - 6'd2];
                stk    = |(mant_ext & ((64'd1 << (sh[5:0] - 6'd2)) - 64'd1));
            end
        end
        unique case (rm_r)
            eth_rv_pkg::RM_RNE: inc = guard & (rndbit | stk | mag[0]);
            eth_rv_pkg::RM_RTZ: inc = 1'b0;
            eth_rv_pkg::RM_RDN: inc = (guard | rndbit | stk) & neg;
            eth_rv_pkg::RM_RUP: inc = (guard | rndbit | stk) & ~neg;
            default:            inc = guard;
        endcase
        mag = (nm == 16'd0) ? 64'd0 : (mag + {63'd0, inc});
        inex = (guard | rndbit | stk);
        // range check on the rounded magnitude
        if (is32) begin
            if (uns) begin
                if (neg && (mag != 64'd0)) in_range = 1'b0;
                if (mag > 64'd4294967295) in_range = 1'b0;
            end else if (neg) begin
                if (mag > 64'd2147483648) in_range = 1'b0;
            end else if (mag > 64'd2147483647) begin
                in_range = 1'b0;
            end
        end else if (uns) begin
            if (neg && (mag != 64'd0)) in_range = 1'b0;
        end else if (neg) begin
            if (mag > 64'h8000_0000_0000_0000) in_range = 1'b0;
        end else if (mag > 64'h7fff_ffff_ffff_ffff) begin
            in_range = 1'b0;
        end
        sat = 64'd0;
        if (is32) begin
            if (uns) begin
                sat = neg ? 64'd0 : 64'h0000_0000_ffff_ffff;
            end else begin
                sat = neg ? 64'hffff_ffff_8000_0000 : 64'h0000_0000_7fff_ffff;
            end
        end else if (uns) begin
            sat = neg ? 64'd0 : 64'hffff_ffff_ffff_ffff;
        end else begin
            sat = neg ? 64'h8000_0000_0000_0000 : 64'h7fff_ffff_ffff_ffff;
        end
        if (in_range) begin
            f2i_res = neg ? (~mag + 64'd1) : mag;
            f2i_ff  = inex ? FF_NX : 5'd0;
        end else begin
            f2i_res = sat;
            f2i_ff  = FF_NV;
        end
        if (is32) begin
            f2i_res = {{32{f2i_res[31]}}, f2i_res[31:0]};
        end
    end

    // =====================================================================
    // comparisons and min/max (hardware, no rounding)
    // =====================================================================
    logic        lt_ab, eq_ab, lt_ba, eq_zero;
    logic [63:0] cmp_res, minmax_res;
    logic [4:0]  cmp_ff, minmax_ff;

    always_comb begin
        logic [63:0] ma, mb;
        // Equal-signed non-NaN values of one format order identically as bit
        // patterns, so the magnitude compare needs no exponent arithmetic.
        ma = src_s ? {33'd0, a_v[30:0]} : {1'b0, a_v[62:0]};
        mb = src_s ? {33'd0, b_v[30:0]} : {1'b0, b_v[62:0]};
        eq_ab = (ua.mant == 60'd0) && (ub.mant == 60'd0);
        if (!eq_ab) begin
            eq_ab = (ua.sign == ub.sign) && (ua.mant == ub.mant) && (ua.e == ub.e);
        end
        // ±0 compare EQUAL, so the sign may only decide the order when the two are
        // not both zero — otherwise `flt`/`fle` would report -0 < +0 and `fmax`
        // would keep -0 where IEEE requires +0.
        eq_zero = ua.is_zero && ub.is_zero;
        lt_ab = 1'b0;
        lt_ba = 1'b0;
        if (!ua.is_nan && !ub.is_nan) begin
            if (ua.sign != ub.sign) begin
                lt_ab = ua.sign && !eq_zero;
                lt_ba = ub.sign && !eq_zero;
            end else if (ua.sign) begin
                lt_ab = (ma > mb);        // more negative
                lt_ba = (mb > ma);
            end else begin
                lt_ab = (ma < mb);
                lt_ba = (mb < ma);
            end
        end
        cmp_res = 64'd0;
        cmp_ff  = 5'd0;
        if (ua.is_nan || ub.is_nan) begin
            if (op_r == eth_rv_pkg::FP_EQ) begin
                cmp_ff = (ua.is_snan || ub.is_snan) ? FF_NV : 5'd0;
            end else begin
                cmp_ff = FF_NV;
            end
        end else begin
            unique case (op_r)
                eth_rv_pkg::FP_EQ: cmp_res = {63'd0, eq_ab};
                eth_rv_pkg::FP_LT: cmp_res = {63'd0, lt_ab};
                default:           cmp_res = {63'd0, lt_ab | eq_ab};
            endcase
        end
    end

    always_comb begin
        logic [63:0] chosen;
        minmax_ff = (ua.is_snan || ub.is_snan) ? FF_NV : 5'd0;
        if (ua.is_nan && ub.is_nan) begin
            chosen = single_r ? S_QNAN : D_QNAN;
        end else if (ua.is_nan) begin
            chosen = single_r ? {32'hffff_ffff, b_v[31:0]} : b_v;
        end else if (ub.is_nan) begin
            chosen = single_r ? {32'hffff_ffff, a_v[31:0]} : a_v;
        end else if (op_r == eth_rv_pkg::FP_MIN) begin
            chosen = (lt_ab || (eq_ab && ua.sign))
                     ? (single_r ? {32'hffff_ffff, a_v[31:0]} : a_v)
                     : (single_r ? {32'hffff_ffff, b_v[31:0]} : b_v);
        end else begin
            // Spike's fmax: `greater` means b is the larger (or they are equal and
            // b is the negative one), and the answer is then a — the opposite
            // select to fmin's, which is where the ±0 case goes wrong if it is
            // written the other way round.
            chosen = (lt_ba || (eq_ab && ub.sign))
                     ? (single_r ? {32'hffff_ffff, a_v[31:0]} : a_v)
                     : (single_r ? {32'hffff_ffff, b_v[31:0]} : b_v);
        end
        minmax_res = chosen;
    end

    // =====================================================================
    // special cases (NaN / infinity / zero) decided before the datapath
    // =====================================================================
    logic        spec;
    logic [63:0] spec_res;
    logic [4:0]  spec_ff;
    // true when this encoding actually names a third source (the fused and the
    // add/subtract forms do; a plain multiply does not)
    logic        c_is_operand;
    assign c_is_operand = eth_rv_pkg::fp_op_is_fma(op_r)
                          || (op_r == eth_rv_pkg::FP_ADD)
                          || (op_r == eth_rv_pkg::FP_SUB);

    always_comb begin
        logic psign, csign;
        spec     = 1'b0;
        spec_res = 64'd0;
        spec_ff  = 5'd0;
        psign = a_eff.sign ^ ub.sign;
        csign = c_eff.sign;
        if ((op_r == eth_rv_pkg::FP_ADD) || (op_r == eth_rv_pkg::FP_SUB)) begin
            psign = ua.sign;
            csign = ub.sign ^ add_neg;
        end
        unique case (op_r)
            eth_rv_pkg::FP_ADD, eth_rv_pkg::FP_SUB, eth_rv_pkg::FP_MUL,
            eth_rv_pkg::FP_MADD, eth_rv_pkg::FP_MSUB, eth_rv_pkg::FP_NMADD,
            eth_rv_pkg::FP_NMSUB: begin
                // `c` is a real operand only for the fused forms and for
                // add/subtract (where the core routes rs2 into the addend port).
                // A plain multiply's rs3 field is part of funct7, so the register
                // file's port C holds an unrelated register — it must not be
                // allowed to poison the result with a NaN.
                if (ua.is_nan || ub.is_nan || (uc.is_nan && c_is_operand)) begin
                    spec     = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = (ua.is_snan || ub.is_snan
                                || (uc.is_snan && c_is_operand)) ? FF_NV : 5'd0;
                end else if (op_r == eth_rv_pkg::FP_MUL) begin
                    if ((ua.is_inf && ub.is_zero) || (ub.is_inf && ua.is_zero)) begin
                        spec = 1'b1;
                        spec_res = single_r ? S_QNAN : D_QNAN;
                        spec_ff  = FF_NV;
                    end else if (ua.is_inf || ub.is_inf) begin
                        spec = 1'b1;
                        spec_res = single_r ? pack_s(psign, 8'hff, 23'd0)
                                            : pack_d(psign, 11'h7ff, 52'd0);
                    end else if (ua.is_zero || ub.is_zero) begin
                        spec = 1'b1;
                        spec_res = single_r ? pack_s(psign, 8'd0, 23'd0)
                                            : pack_d(psign, 11'd0, 52'd0);
                    end
                end else if ((op_r == eth_rv_pkg::FP_ADD) || (op_r == eth_rv_pkg::FP_SUB)) begin
                    if (ua.is_inf && ub.is_inf && (psign != csign)) begin
                        spec = 1'b1;
                        spec_res = single_r ? S_QNAN : D_QNAN;
                        spec_ff  = FF_NV;
                    end else if (ua.is_inf) begin
                        spec = 1'b1;
                        spec_res = single_r ? pack_s(psign, 8'hff, 23'd0)
                                            : pack_d(psign, 11'h7ff, 52'd0);
                    end else if (ub.is_inf) begin
                        spec = 1'b1;
                        spec_res = single_r ? pack_s(csign, 8'hff, 23'd0)
                                            : pack_d(csign, 11'h7ff, 52'd0);
                    end
                end else begin
                    // fused: infinity handling of SoftFloat's mulAdd
                    if (ua.is_inf || ub.is_inf) begin
                        spec = 1'b1;
                        if (ua.is_zero || ub.is_zero) begin
                            spec_res = single_r ? S_QNAN : D_QNAN;
                            spec_ff  = FF_NV;
                        end else if (uc.is_inf && (csign != psign)) begin
                            spec_res = single_r ? S_QNAN : D_QNAN;
                            spec_ff  = FF_NV;
                        end else begin
                            spec_res = single_r ? pack_s(psign, 8'hff, 23'd0)
                                                : pack_d(psign, 11'h7ff, 52'd0);
                        end
                    end
                end
                if (!spec && pz) begin
                    // the product is zero: the result is the addend (already
                    // representable), with SoftFloat's zero-sign rule when both
                    // addends are zero.
                    spec = 1'b1;
                    if (cz) begin
                        if (psign == csign) begin
                            spec_res = single_r ? pack_s(psign, 8'd0, 23'd0)
                                                : pack_d(psign, 11'd0, 52'd0);
                        end else begin
                            spec_res = single_r
                                ? pack_s(rm_r == eth_rv_pkg::RM_RDN, 8'd0, 23'd0)
                                : pack_d(rm_r == eth_rv_pkg::RM_RDN, 11'd0, 52'd0);
                        end
                    end else begin
                        spec_res = c_eff_bits;
                    end
                end
            end
            eth_rv_pkg::FP_DIV: begin
                if (ua.is_nan || ub.is_nan) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = (ua.is_snan || ub.is_snan) ? FF_NV : 5'd0;
                end else if (ua.is_inf && ub.is_inf) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = FF_NV;
                end else if (ua.is_zero && ub.is_zero) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = FF_NV;
                end else if (ub.is_zero) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(ua.sign ^ ub.sign, 8'hff, 23'd0)
                                        : pack_d(ua.sign ^ ub.sign, 11'h7ff, 52'd0);
                    spec_ff  = FF_DZ;
                end else if (ua.is_inf) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(ua.sign ^ ub.sign, 8'hff, 23'd0)
                                        : pack_d(ua.sign ^ ub.sign, 11'h7ff, 52'd0);
                end else if (ub.is_inf || ua.is_zero) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(ua.sign ^ ub.sign, 8'd0, 23'd0)
                                        : pack_d(ua.sign ^ ub.sign, 11'd0, 52'd0);
                end
            end
             eth_rv_pkg::FP_SQRT: begin
                if (ua.is_nan) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = ua.is_snan ? FF_NV : 5'd0;
                end else if (ua.is_zero) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(ua.sign, 8'd0, 23'd0)
                                        : pack_d(ua.sign, 11'd0, 52'd0);
                end else if (ua.sign) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = FF_NV;
                end else if (ua.is_inf) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(1'b0, 8'hff, 23'd0)
                                        : pack_d(1'b0, 11'h7ff, 52'd0);
                end
            end
            // FP -> FP conversion: a NaN source becomes the destination format's
            // canonical NaN (raising NV for a signaling NaN), an infinity keeps its
            // sign. Everything else goes through the shared rounder, so
            // `fcvt.s.d` rounds exactly once.
            eth_rv_pkg::FP_CVT_FP_FP: begin
                if (usrc.is_nan) begin
                    spec = 1'b1;
                    spec_res = single_r ? S_QNAN : D_QNAN;
                    spec_ff  = usrc.is_snan ? FF_NV : 5'd0;
                end else if (usrc.is_inf) begin
                    spec = 1'b1;
                    spec_res = single_r ? pack_s(usrc.sign, 8'hff, 23'd0)
                                        : pack_d(usrc.sign, 11'h7ff, 52'd0);
                end
            end
            default: ;
        endcase
    end

    // =====================================================================
    // combinational result select
    // =====================================================================
    logic [63:0] comb_res;
    logic [4:0]  comb_ff;

    always_comb begin
        comb_res = spec ? spec_res : rnd_res;
        comb_ff  = spec ? spec_ff  : rnd_ff;
        unique case (op_r)
            eth_rv_pkg::FP_SGNJ, eth_rv_pkg::FP_SGNJN, eth_rv_pkg::FP_SGNJX: begin
                if (single_r) begin
                    unique case (op_r)
                        eth_rv_pkg::FP_SGNJ:  comb_res = {32'hffff_ffff, b_v[31], a_v[30:0]};
                        eth_rv_pkg::FP_SGNJN: comb_res = {32'hffff_ffff, ~b_v[31], a_v[30:0]};
                        default:              comb_res = {32'hffff_ffff, a_v[31] ^ b_v[31],
                                                          a_v[30:0]};
                    endcase
                end else begin
                    unique case (op_r)
                        eth_rv_pkg::FP_SGNJ:  comb_res = {b_v[63], a_v[62:0]};
                        eth_rv_pkg::FP_SGNJN: comb_res = {~b_v[63], a_v[62:0]};
                        default:              comb_res = {a_v[63] ^ b_v[63], a_v[62:0]};
                    endcase
                end
                comb_ff = 5'd0;
            end
            eth_rv_pkg::FP_MIN, eth_rv_pkg::FP_MAX: begin
                comb_res = minmax_res;
                comb_ff  = minmax_ff;
            end
            eth_rv_pkg::FP_EQ, eth_rv_pkg::FP_LT, eth_rv_pkg::FP_LE: begin
                comb_res = cmp_res;
                comb_ff  = cmp_ff;
            end
             eth_rv_pkg::FP_CLASS: begin
                comb_res = {54'd0, single_r ? fclass_s(a_v[31:0]) : fclass_d(a_v)};
                comb_ff  = 5'd0;
            end
            eth_rv_pkg::FP_MV_X_FP: begin
                comb_res = single_r ? {{32{a_r[31]}}, a_r[31:0]} : a_r;
                comb_ff  = 5'd0;
            end
            eth_rv_pkg::FP_MV_FP_X: begin
                comb_res = single_r ? {32'hffff_ffff, a_r[31:0]} : a_r;
                comb_ff  = 5'd0;
            end
            eth_rv_pkg::FP_CVT_FP_I: begin
                comb_res = f2i_res;
                comb_ff  = f2i_ff;
            end
            default: ;
        endcase
    end

    // =====================================================================
    // sequential: handshake, latched operands, iterative work
    // =====================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            st_r        <= ST_IDLE;
            op_r        <= eth_rv_pkg::FP_NONE;
            single_r    <= 1'b0;
            src_single_r <= 1'b0;
            iw_r        <= 2'd0;
            rm_r        <= 3'd0;
            a_r         <= 64'd0;
            b_r         <= 64'd0;
            c_r         <= 64'd0;
            res_r       <= 64'd0;
            ff_r        <= 5'd0;
            cnt_r       <= 7'd0;
            run_r       <= 1'b0;
            dv_rem_r    <= 56'd0;
            dv_quot_r   <= 60'd0;
            dv_div_r    <= 53'd0;
            dv_e_r      <= 16'sd0;
            dv_sign_r   <= 1'b0;
            sq_rad_r    <= 120'd0;
            sq_root_r   <= 60'd0;
            sq_rem_r    <= 64'd0;
            sq_e_r      <= 16'sd0;
            sq_sign_r   <= 1'b0;
        end else begin
            unique case (st_r)
                 ST_IDLE: begin
                    if (start_i) begin
                        op_r         <= op_i;
                        single_r     <= single_i;
                        src_single_r <= src_single_i;
                        iw_r         <= iw_i;
                        rm_r         <= rm_i;
                        a_r          <= a_i;
                        b_r          <= b_i;
                        c_r          <= c_i;
                        run_r        <= 1'b0;
                        cnt_r        <= 7'd0;
                        st_r         <= ST_WORK;
                    end
                end
                ST_WORK: begin
                    if (!run_r) begin
                        if (op_r == eth_rv_pkg::FP_DIV) begin
                            // seed the restoring division: the leading quotient bit
                            // is the normalization comparison itself
                            if (dv_na >= dv_nb) begin
                                dv_rem_r  <= 56'(dv_na - dv_nb);
                                dv_quot_r <= 60'd1;
                            end else begin
                                dv_rem_r  <= 56'(dv_na);
                                dv_quot_r <= 60'd0;
                            end
                            dv_div_r  <= dv_nb;
                            dv_sign_r <= ua.sign ^ ub.sign;
                             dv_e_r    <= dv_ea - dv_eb - 16'sd58;
                            cnt_r     <= 7'(DIV_ITERS);
                            run_r     <= 1'b1;
                        end else if (op_r == eth_rv_pkg::FP_SQRT) begin
                            sq_rad_r  <= sq_rad_init;
                            sq_root_r <= 60'd0;
                            sq_rem_r  <= 64'd0;
                            sq_e_r    <= sq_e_init;
                            sq_sign_r <= 1'b0;
                            cnt_r     <= 7'(SQRT_ITERS);
                            run_r     <= 1'b1;
                        end else begin
                            // everything else resolves combinationally from the
                            // latched operands and is committed right here. `run_r`
                            // MUST stay clear: leaving it set would make the next
                            // divide or square root skip its own initialisation and
                            // latch the stale state (a zero root, in practice).
                            res_r <= comb_res;
                            ff_r  <= comb_ff;
                            run_r <= 1'b0;
                            st_r  <= ST_DONE;
                        end
                    end else if (cnt_r != 7'd0) begin
                        if (op_r == eth_rv_pkg::FP_DIV) begin
                            logic [56:0] sh_rem;
                            sh_rem = {dv_rem_r, 1'b0};
                            if (sh_rem >= {4'd0, dv_div_r}) begin
                                dv_rem_r  <= 56'(sh_rem - {4'd0, dv_div_r});
                                dv_quot_r <= {dv_quot_r[58:0], 1'b1};
                            end else begin
                                dv_rem_r  <= sh_rem[55:0];
                                dv_quot_r <= {dv_quot_r[58:0], 1'b0};
                            end
                        end else begin
                            logic [63:0] sh_rem;
                            logic [63:0] trial;
                            sh_rem = {sq_rem_r[61:0], sq_rad_r[119:118]};
                            trial  = {2'd0, sq_root_r, 2'b01};
                            if (sh_rem >= trial) begin
                                sq_rem_r  <= sh_rem - trial;
                                sq_root_r <= {sq_root_r[58:0], 1'b1};
                            end else begin
                                sq_rem_r  <= sh_rem;
                                sq_root_r <= {sq_root_r[58:0], 1'b0};
                            end
                            sq_rad_r <= {sq_rad_r[117:0], 2'b00};
                        end
                        cnt_r <= cnt_r - 7'd1;
                    end else begin
                        res_r <= comb_res;
                        ff_r  <= comb_ff;
                        run_r <= 1'b0;
                        st_r  <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    st_r <= ST_IDLE;
                end
                default: st_r <= ST_IDLE;
            endcase
        end
    end

    assign valid_o  = (st_r == ST_DONE);
    assign result_o = res_r;
    assign fflags_o = ff_r;

endmodule
`default_nettype wire
