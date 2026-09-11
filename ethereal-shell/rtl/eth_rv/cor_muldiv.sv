`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_muldiv
// Description: RV64M multiply/divide unit for eth_rv (start/valid handshake).
// Details:     Multiplies are one cycle of datapath (the 128-bit product is
//              registered); divisions run a 64-step shift/subtract restoring
//              divider, one quotient bit per clock, so a division costs 65
//              cycles. The EX stage starts an operation once and stalls until
//              `valid_o` pulses, which keeps the multiply and divide latencies
//              behind one uniform handshake.
//
//              Semantics follow the RISC-V M extension exactly, including the
//              two special cases that trip up naive dividers:
//                * divide by zero  -> quotient = all ones, remainder = dividend
//                * INT64_MIN / -1  -> quotient = INT64_MIN, remainder = 0
//              Both fall out of the magnitude/sign scheme below: operands are
//              negated into unsigned magnitudes (INT64_MIN's magnitude is 2^63,
//              which a 64-bit unsigned register holds exactly), the restoring
//              divider works on those, and the sign is applied afterwards. The
//              divide-by-zero case bypasses the divider entirely, because the
//              architectural remainder there is the *signed* dividend, not its
//              magnitude.
//
//              The *.W forms are handled here too: the operands are pre-scaled
//              (sign-extended for divw/remw, zero-extended for divuw/remuw) and
//              the result is truncated to 32 bits and sign-extended, exactly
//              like the RV64M specification's W-forms.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (EX stage, M extension),
//              §5.4 (known traps: mulh/mulhsu/mulhu high halves)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Behavioral (ADR-017): the 128-bit product is written as a plain
//              multiply and left to the platform EDA to infer. No vendor DSP
//              primitives. `start_i` while busy is ignored (the core never does).
module cor_muldiv (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        start_i,     // one-cycle launch pulse
    input  eth_rv_pkg::md_op_e op_i,
    input  logic [63:0] a_i,         // raw rs1
    input  logic [63:0] b_i,         // raw rs2
    output logic [63:0] result_o,    // valid in the cycle `valid_o` is high
    output logic        valid_o      // one-cycle result strobe
);

    typedef enum logic [1:0] {
        MD_IDLE = 2'd0,
        MD_MUL  = 2'd1,
        MD_DIV  = 2'd2,
        MD_DONE = 2'd3
    } md_state_e;

    // ------------------------------------------------- op class decode
    logic        is_mul;
    logic        is_div;
    logic        is_rem;
    logic        is_w_op;
    logic        a_signed;
    logic        b_signed;
    logic [63:0] a_div_eff;
    logic [63:0] b_div_eff;

    logic [63:0] a_s32;
    logic [63:0] a_z32;
    logic [63:0] b_s32;
    logic [63:0] b_z32;

    assign a_s32 = {{32{a_i[31]}}, a_i[31:0]};
    assign a_z32 = {32'd0, a_i[31:0]};
    assign b_s32 = {{32{b_i[31]}}, b_i[31:0]};
    assign b_z32 = {32'd0, b_i[31:0]};

    always_comb begin
        is_mul    = 1'b1;
        is_div    = 1'b0;
        is_rem    = 1'b0;
        is_w_op   = 1'b0;
        a_signed  = 1'b0;
        b_signed  = 1'b0;
        a_div_eff = a_i;
        b_div_eff = b_i;
        unique case (op_i)
            eth_rv_pkg::MD_MUL: begin
                is_mul = 1'b1;
            end
            eth_rv_pkg::MD_MULH: begin
                is_mul = 1'b1; a_signed = 1'b1; b_signed = 1'b1;
            end
            eth_rv_pkg::MD_MULHSU: begin
                is_mul = 1'b1; a_signed = 1'b1;
            end
            eth_rv_pkg::MD_MULHU: begin
                is_mul = 1'b1;
            end
            eth_rv_pkg::MD_MULW: begin
                is_mul = 1'b1; is_w_op = 1'b1;
            end
            eth_rv_pkg::MD_DIV: begin
                is_mul = 1'b0; is_div = 1'b1; a_signed = 1'b1; b_signed = 1'b1;
            end
            eth_rv_pkg::MD_REM: begin
                is_mul = 1'b0; is_div = 1'b1; is_rem = 1'b1;
                a_signed = 1'b1; b_signed = 1'b1;
            end
            eth_rv_pkg::MD_DIVU: begin
                is_mul = 1'b0; is_div = 1'b1;
            end
            eth_rv_pkg::MD_REMU: begin
                is_mul = 1'b0; is_div = 1'b1; is_rem = 1'b1;
            end
            eth_rv_pkg::MD_DIVW: begin
                is_mul = 1'b0; is_div = 1'b1; is_w_op = 1'b1;
                a_signed = 1'b1; b_signed = 1'b1; a_div_eff = a_s32; b_div_eff = b_s32;
            end
            eth_rv_pkg::MD_REMW: begin
                is_mul = 1'b0; is_div = 1'b1; is_rem = 1'b1; is_w_op = 1'b1;
                a_signed = 1'b1; b_signed = 1'b1; a_div_eff = a_s32; b_div_eff = b_s32;
            end
            eth_rv_pkg::MD_DIVUW: begin
                is_mul = 1'b0; is_div = 1'b1; is_w_op = 1'b1;
                a_div_eff = a_z32; b_div_eff = b_z32;
            end
            eth_rv_pkg::MD_REMUW: begin
                is_mul = 1'b0; is_div = 1'b1; is_rem = 1'b1; is_w_op = 1'b1;
                a_div_eff = a_z32; b_div_eff = b_z32;
            end
            default: begin
                is_mul = 1'b1;
            end
        endcase
    end

    // ------------------------------------------------- 128-bit products
    // The high halves come from explicit 128-bit products built inside
    // functions: both operands are widened before the multiply so the product is
    // evaluated at full width (a 64-bit context would silently keep only the low
    // half — precisely the mulh/mulhsu/mulhu trap of C14 §5.4).
    logic [63:0] mul_low;
    logic [63:0] mul_high_ss;
    logic [63:0] mul_high_su;
    logic [63:0] mul_high_uu;

    function automatic logic [63:0] mulh_ss(input logic [63:0] a, input logic [63:0] b);
        // both operands widened to 128 bits -> the product is evaluated at full
        // width; the explicit cast keeps the >>64 exact.
        mulh_ss = 64'(({{64{a[63]}}, a} * {{64{b[63]}}, b}) >> 64);
    endfunction

    function automatic logic [63:0] mulh_su(input logic [63:0] a, input logic [63:0] b);
        // signed(a) * unsigned(b) lies in (-2^127, 2^127), so the low 128 bits of
        // the widened product are exact and their high half is the answer.
        mulh_su = 64'(({{64{a[63]}}, a} * {64'd0, b}) >> 64);
    endfunction

    function automatic logic [63:0] mulh_uu(input logic [63:0] a, input logic [63:0] b);
        mulh_uu = 64'(({64'd0, a} * {64'd0, b}) >> 64);
    endfunction

    assign mul_low     = a_i * b_i;
    assign mul_high_ss = mulh_ss(a_i, b_i);
    assign mul_high_su = mulh_su(a_i, b_i);
    assign mul_high_uu = mulh_uu(a_i, b_i);

    logic [63:0] mul_value;

    always_comb begin
        mul_value = mul_low;
        unique case (op_i)
            eth_rv_pkg::MD_MULH:   mul_value = mul_high_ss;
            eth_rv_pkg::MD_MULHSU: mul_value = mul_high_su;
            eth_rv_pkg::MD_MULHU:  mul_value = mul_high_uu;
            default:               mul_value = mul_low;   // MD_MUL / MD_MULW
        endcase
    end

    // ------------------------------------------------- divider magnitudes
    logic [63:0] a_mag;
    logic [63:0] b_mag;

    assign a_mag = (a_signed && a_div_eff[63]) ? (~a_div_eff + 64'd1) : a_div_eff;
    assign b_mag = (b_signed && b_div_eff[63]) ? (~b_div_eff + 64'd1) : b_div_eff;

    // -------------------------------------------------------- state
    md_state_e   state_r;
    logic [6:0]  count_r;
    logic [63:0] quot_r;
    logic [63:0] rem_r;   // 64 bits: rem < divisor <= 2^64-1 is an invariant
    logic [63:0] dividend_r;
    logic [63:0] divisor_r;
    logic [63:0] a_eff_r;    // effective (pre-scaled) dividend, for divide-by-zero
    logic        a_neg_r;    // dividend was negative
    logic        b_neg_r;    // divisor was negative
    logic        div_zero_r;
    logic        is_rem_r;
    logic        is_w_r;
    logic        is_mul_r;
    logic [63:0] mul_value_r;

    // -------------------------------------------------------- datapath
    logic [64:0] rem_shift;
    logic [64:0] divisor_ext;
    logic        sub_en;

    assign rem_shift   = {rem_r, dividend_r[63]};
    assign divisor_ext = {1'b0, divisor_r};
    assign sub_en      = (rem_shift >= divisor_ext);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r     <= MD_IDLE;
            count_r     <= 7'd0;
            quot_r      <= 64'd0;
            rem_r       <= 64'd0;
            dividend_r  <= 64'd0;
            divisor_r   <= 64'd0;
            a_eff_r     <= 64'd0;
            a_neg_r     <= 1'b0;
            b_neg_r     <= 1'b0;
            div_zero_r  <= 1'b0;
            is_rem_r    <= 1'b0;
            is_w_r      <= 1'b0;
            is_mul_r    <= 1'b0;
            mul_value_r <= 64'd0;
        end else begin
            unique case (state_r)
                MD_IDLE: begin
                    if (start_i) begin
                        a_eff_r     <= a_div_eff;
                        a_neg_r     <= a_signed && a_div_eff[63];
                        b_neg_r     <= b_signed && b_div_eff[63];
                        is_rem_r    <= is_rem;
                        is_w_r      <= is_w_op;
                        is_mul_r    <= is_mul;
                        mul_value_r <= mul_value;
                        if (is_div && (b_mag == 64'd0)) begin
                            // divide by zero: fixed architectural result
                            state_r    <= MD_DONE;
                            div_zero_r <= 1'b1;
                            quot_r     <= 64'd0;
                            rem_r      <= 64'd0;
                        end else if (is_div) begin
                            state_r    <= MD_DIV;
                            count_r    <= 7'd64;
                            quot_r     <= 64'd0;
                            rem_r      <= 64'd0;
                            dividend_r <= a_mag;
                            divisor_r  <= b_mag;
                            div_zero_r <= 1'b0;
                        end else begin
                            state_r    <= MD_MUL;
                            div_zero_r <= 1'b0;
                        end
                    end
                end
                MD_MUL: begin
                    state_r <= MD_DONE;
                end
                MD_DIV: begin
                    dividend_r <= {dividend_r[62:0], 1'b0};
                    if (sub_en) begin
                        rem_r  <= 64'(rem_shift - divisor_ext);
                        quot_r <= {quot_r[62:0], 1'b1};
                    end else begin
                        rem_r  <= 64'(rem_shift);
                        quot_r <= {quot_r[62:0], 1'b0};
                    end
                    if (count_r == 7'd1) begin
                        state_r <= MD_DONE;
                    end else begin
                        count_r <= count_r - 7'd1;
                    end
                end
                MD_DONE: begin
                    state_r <= MD_IDLE;
                end
                default: begin
                    state_r <= MD_IDLE;
                end
            endcase
        end
    end

    // -------------------------------------------------------- result mux
    logic [63:0] q_value;
    logic [63:0] r_value;
    logic [63:0] raw_value;

    always_comb begin
        q_value   = div_zero_r ? 64'hFFFF_FFFF_FFFF_FFFF
                               : ((a_neg_r ^ b_neg_r) ? (~quot_r + 64'd1) : quot_r);
        r_value   = div_zero_r ? a_eff_r
                               : (a_neg_r ? (~rem_r + 64'd1) : rem_r);
        raw_value = is_mul_r ? mul_value_r : (is_rem_r ? r_value : q_value);
        result_o  = is_w_r ? {{32{raw_value[31]}}, raw_value[31:0]} : raw_value;
    end

    assign valid_o = (state_r == MD_DONE);
endmodule
`default_nettype wire
