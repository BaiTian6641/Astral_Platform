`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      ctx_scan
// Description: Context save/restore engine — shifts the fabric FF scan chain
//              (ctx-scan-v0.md §2/§3) to/from the SSM-T context window.
//              Save : assert scan_en_o, sample scan_out_i pre-edge each clock
//              (element N-1 first), pack element e -> bit e%32 of word e/32,
//              write words to the context RAM (descending address order).
//              Restore: read words ascending, drive scan_in_o MSB-first
//              (element N-1 first — the chain delays one element per shift);
//              after N shifts deassert scan_en_o so the fabric resumes from
//              the restored state.
//              v0: single clock domain; combinational-read context RAM
//              (column_cfg_ram model); the real SSRAM window mapping is
//              C02 §3 ASSUMPTION #1 (hal/glue). Cost: +1 mux per eLUT on the
//              FF data path (C03 §7).
// Maintainer:  BaiTian6641
// Created:     2026-09-11
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/fabric/ctx-scan-v0.md §4 (E2-FAB3);
//              ethereal-plan/components/C03-OCC组件.md §7
// Notes:       words_i is the chain word count (chain length = words_i x 32 bits,
//              e.g. R*C*8 bits / 32 for an all-CLB fabric). The context window
//              read is combinational (column_cfg_ram model).
module ctx_scan #(
    parameter int AW = 1     // context RAM word-address width (chain words)
) (
    input  logic           clk_i,
    input  logic           rst_ni,
    // ---- command interface ----
    input  logic           start_i,       // one-shot pulse (ignored while busy)
    input  logic           mode_i,        // 0 = save, 1 = restore
    input  logic [15:0]    words_i,       // word count (N/32)
    output logic           busy_o,
    output logic           done_o,        // 1-cycle completion pulse
    // ---- scan chain (to fabric_top) ----
    output logic           scan_en_o,
    output logic           scan_in_o,
    input  logic           scan_out_i,
    // ---- context window (SSM-T stand-in; combinational read) ----
    output logic           ram_we_o,
    output logic [AW-1:0]  ram_addr_o,
    output logic [31:0]    ram_wdata_o,
    input  logic [31:0]    ram_rdata_i
);

    localparam logic MODE_SAVE = 1'b0;

    typedef enum logic [1:0] {
        ST_IDLE  = 2'd0,
        ST_SHIFT = 2'd1,
        ST_DONE  = 2'd2
    } state_e;

    state_e         state_r, state_nxt;
    logic           mode_r;
    logic [15:0]    bits_r;        // chain bit counter
    logic [15:0]    words_r;       // latched word count
    logic [31:0]    acc_r;         // save: shift-in accumulator
    logic [31:0]    sreg_r;        // restore: shift-out register
    logic           done_r;

    // ------------------------------------------------------------------
    // Segment 1: next state + datapath control (defaults first, G1)
    // ------------------------------------------------------------------
    logic           scan_en_c;
    logic           ram_we_c;
    logic [AW-1:0]  ram_addr_c;
    logic [31:0]    ram_wdata_c;
    logic [31:0]    sreg_nxt;
    logic [31:0]    acc_nxt;

    always_comb begin
        state_nxt   = state_r;
        scan_en_c   = 1'b0;
        ram_we_c    = 1'b0;
        ram_addr_c  = '0;
        ram_wdata_c = acc_r;
        acc_nxt     = acc_r;
        sreg_nxt    = sreg_r;

        case (state_r)
            ST_IDLE: begin
                if (start_i) state_nxt = ST_SHIFT;
            end
            ST_SHIFT: begin
                scan_en_c = 1'b1;
                if (mode_r == MODE_SAVE) begin
                    // left shift + insert at bit0: sample 1 (element N-1) ends at bit31,
                    // sample N (element 0) at bit0 — element e -> bit e (spec §4)
                    acc_nxt = {acc_r[30:0], scan_out_i};
                    if (bits_r[4:0] == 5'd31) begin
                        ram_we_c    = 1'b1;
                        ram_addr_c  = AW'(words_r - (bits_r >> 5) - 16'd1);
                        ram_wdata_c = {acc_r[30:0], scan_out_i};
                    end
                end else begin
                    // MSB-first: the first driven bit ends at element N-1 after N shifts
                    sreg_nxt = {sreg_r[30:0], 1'b0};
                    if (bits_r[4:0] == 5'd31) begin
                        ram_addr_c = AW'((bits_r >> 5) + 16'd1);
                        sreg_nxt   = ram_rdata_i;          // next word (comb read)
                    end
                end
                if (bits_r == ((words_r << 5) - 16'd1)) state_nxt = ST_DONE;
            end
            ST_DONE: state_nxt = ST_IDLE;
            default: state_nxt = ST_IDLE;
        endcase
    end

    assign busy_o      = (state_r == ST_SHIFT);
    assign done_o      = done_r;
    assign scan_en_o   = scan_en_c;
    assign scan_in_o   = sreg_r[31];       // MSB-first (element N-1 first)
    assign ram_we_o    = ram_we_c;
    assign ram_addr_o  = ram_addr_c;
    assign ram_wdata_o = ram_wdata_c;

    // ------------------------------------------------------------------
    // Segment 2: registers
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state_r <= ST_IDLE;
            mode_r  <= MODE_SAVE;
            bits_r  <= 16'd0;
            words_r <= 16'd0;
            acc_r   <= 32'h0;
            sreg_r  <= 32'h0;
            done_r  <= 1'b0;
        end else begin
            state_r <= state_nxt;
            done_r  <= (state_r == ST_DONE);
            if (state_r == ST_IDLE) begin
                if (start_i) begin
                    mode_r  <= mode_i;
                    words_r <= words_i;
                    bits_r  <= 16'd0;
                    acc_r   <= 32'h0;
                    sreg_r  <= ram_rdata_i;   // restore: preload word 0
                end
            end else if (state_r == ST_SHIFT) begin
                bits_r <= bits_r + 16'd1;
                if (mode_r == MODE_SAVE) acc_r <= acc_nxt;
                else                     sreg_r <= sreg_nxt;
            end
        end
    end

endmodule

`default_nettype wire
