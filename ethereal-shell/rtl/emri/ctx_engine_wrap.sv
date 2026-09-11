`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      ctx_engine_wrap
// Description: EMRI context-engine wrapper — owns `ctx_scan` + the context
//              window port and folds the PAUSED fabric-freeze into the
//              fabric-facing scan enable.
// Details:     Integration-level companion of `emri_regfile` (v0.7 §3.9,
//              E2-FAB3b). The regfile drives the command port and latches the
//              completion; this module sits between it and the fabric:
//
//                emri_regfile.ctx_start_o/ctx_mode_o/ctx_words_o -> start_i/
//                mode_i/words_i; ctx_busy_i/ctx_done_i <- busy_o/done_o.
//                scan_en_o/scan_in_o/scan_out_i -> fabric_top scan chain;
//                ram_we_o/ram_addr_o/ram_wdata_o/ram_rdata_i -> the context
//                window (column_cfg_ram model / SSM-T window).
//
//              A completed ctx_save must leave the container frozen for the
//              whole PAUSED period (emri-v0.md §3.9 table row 2). `ctx_scan`
//              deasserts its own scan_en in its terminal cycle, so this wrapper
//              holds `ctx_armed` — armed by a completing save, released by a
//              completing restore (or reset) — and drives the fabric-facing
//              `scan_en_o = (engine_scan_en | ctx_armed | save-bridge)
//              & ~restore-release`. The terminal-cycle bridge/release is what
//              makes the hold seamless: the save must not miss the cycle the
//              engine's own scan_en falls, and the restore must not shift the
//              just-restored image a second time. While held the fabric has no
//              LUT capture, so the container cannot advance, and the saved
//              image in the context window is what the restore reloads.
//              `err_o` is 0 in v0: `ctx_scan` (ctx-scan-v0.md §4) has no error
//              output, so CTX_STATUS.err has no engine source yet.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3.9 (E2-FAB3b);
//              ethereal-spec/fabric/ctx-scan-v0.md §4
// Notes:       G1: default_nettype none, always_ff non-blocking, sized literals.
module ctx_engine_wrap #(
    parameter int AW = 1     // context RAM word-address width (chain words)
) (
    input  logic           clk_i,
    input  logic           rst_ni,
    // ---- command port (from emri_regfile) ----
    input  logic           start_i,     // 1-cycle pulse (ignored while busy)
    input  logic           mode_i,      // 0 = save, 1 = restore
    input  logic [15:0]    words_i,     // chain word count (N/32)
    output logic           busy_o,
    output logic           done_o,      // 1-cycle completion pulse
    output logic           err_o,       // v0: no engine error source
    // ---- fabric scan chain (freeze folded in) ----
    output logic           scan_en_o,
    output logic           scan_in_o,
    input  logic           scan_out_i,
    // ---- context window ----
    output logic           ram_we_o,
    output logic [AW-1:0]  ram_addr_o,
    output logic [31:0]    ram_wdata_o,
    input  logic [31:0]    ram_rdata_i
);

    logic eng_scan_en;
    logic busy_d;       // busy_o one cycle ago (detects the engine's last shift)
    logic armed_r;      // 1 = context saved, fabric held frozen (PAUSED)
    logic mode_r;       // mode latched at the accepted start
    logic eng_last_w;   // high for the engine's terminal cycle (busy falling)
    logic save_bridge_w;
    logic restore_release_w;

    ctx_scan #(.AW(AW)) u_ctx_scan (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .start_i     (start_i),
        .mode_i      (mode_i),
        .words_i     (words_i),
        .busy_o      (busy_o),
        .done_o      (done_o),
        .scan_en_o   (eng_scan_en),
        .scan_in_o   (scan_in_o),
        .scan_out_i  (scan_out_i),
        .ram_we_o    (ram_we_o),
        .ram_addr_o  (ram_addr_o),
        .ram_wdata_o (ram_wdata_o),
        .ram_rdata_i (ram_rdata_i)
    );

    // ------------------------------------------------------------------
    // PAUSED freeze arming (emri-v0.md §3.9 row 2)
    //   `eng_last_w` is the engine's terminal cycle: busy_o falls on the edge
    //   AFTER the final shift, so it is high for exactly the cycle in which
    //   the engine has already dropped its own scan_en. That is the cycle the
    //   hold must be applied (save: bridge the gap into PAUSED) or removed
    //   (restore: leave scan_en low so the restored image is not shifted
    //   again). `mode_r` is latched on the start the engine accepts (busy_o
    //   low = IDLE), so the terminal cycle can be attributed without reaching
    //   into the engine.
    // ------------------------------------------------------------------
    assign eng_last_w        = busy_d && !busy_o;
    assign save_bridge_w     = eng_last_w && (mode_r == 1'b0);
    assign restore_release_w = eng_last_w && (mode_r == 1'b1);
    assign scan_en_o         = (eng_scan_en | armed_r | save_bridge_w)
                               & ~restore_release_w;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            busy_d  <= 1'b0;
            armed_r <= 1'b0;
            mode_r  <= 1'b0;
        end else begin
            busy_d <= busy_o;
            if (start_i && !busy_o) begin
                mode_r <= mode_i;
            end
            if (eng_last_w) begin
                armed_r <= (mode_r == 1'b0);   // save -> hold; restore -> release
            end
        end
    end

    assign err_o = 1'b0;   // v0: ctx_scan has no error output

endmodule

`default_nettype wire
