`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      mfsm_session
// Description: mFSM session FSM — the 5-state host-driven session tracker of
//              emri-v0.md §5 (C05 §4.2) plus the v0 rx-buffer accounting that
//              feeds RX_BUF_CTRL (offset 0x12).
// Details:     STATES / EDGES (emri-v0.md §5 state diagram, "present and
//              meaningful only in mFSM mode (HAS_BMC=0)"):
//
//                IDLE       --begin_rx-->                  RX
//                RX         --rx_buf full OR verify-->     VERIFY_REQ
//                RX         --abort-->                     IDLE
//                VERIFY_REQ --occ_go-->                    OCC_GO
//                VERIFY_REQ --abort-->                     IDLE
//                OCC_GO     --OCC terminal DONE-->         IDLE
//                OCC_GO     --OCC terminal other-->        ERROR (err=occ_locked/occ_error)
//                ERROR      --abort-->                     IDLE
//
//              The FSM is a SESSION TRACKER, not a gate: §1/§8 keep the v0 mFSM
//              host-driven ("the host streams OCC_WDATA directly to the OCC
//              through the regfile's passthrough; the host implements the session
//              FSM"), so no EMRI access is blocked by the session state — the
//              host issues OCC_CMD/OCC_WDATA itself while the FSM tracks the
//              session outcome. See the report's ASSUMPTION list.
//
//              TERMINAL OBSERVATION (why there is a latch here): §4 explains that
//              occ_top's DONE/ERROR/LOCKED/NEEDS_BLANK status is a ONE-CYCLE
//              pulse — invisible to a poller and just as invisible to this FSM if
//              the pulse lands before the host writes occ_go (the normal order:
//              the last rx push lets the OCC complete the WRITE before the host
//              has signalled "verified"). So any terminal status observed while a
//              session is live is LATCHED (first terminal wins) and consumed when
//              the FSM is in OCC_GO. This is the same reason the register file
//              latches the sticky done_flag (§4 "use [3]/[5:4] instead").
//              The latch is cleared by begin_rx (a new session) and by the
//              OCC_GO completion it produced.
//
//              TERMINAL CLASS MAP (the state diagram shows only DONE/ERROR; the
//              err codes of §5 fix the two refusals):
//                DONE        -> IDLE,  err=none
//                LOCKED      -> ERROR, err=2 occ_locked   (§3.10 lock gate)
//                ERROR       -> ERROR, err=3 occ_error
//                NEEDS_BLANK -> ERROR, err=3 occ_error
//                // ASSUMPTION: §5 defines no err code for NEEDS_BLANK (the
//                // blank-before-write refusal, E0-FAB5 dirty gate, TBD
//                // 2026-09-13). Leaving the FSM in OCC_GO forever would be a hang
//                // and no code may be invented (G6), so the refusal is reported
//                // as the generic OCC error it is. Option B of the report's open
//                // list: a new err code (needs a spec bump).
//              // err=1 bad_crc has NO v0 producer: per §5's own G6 resolution the
//              // HOST computes Ed25519+CRC32 (the mFSM has no CPU), so a failed
//              // check is the host's to catch — the host writes abort, never
//              // occ_go. The code stays reserved/unused, exactly as encoded.
//
//              RX ACCOUNTING (offset 0x12, `{wr_ptr[31:16], depth[15:0]}`): v0 has
//              no device-side rx_buf (§1 defers the rx_buf + its device FSM to
//              v0.1: "the host streams OCC_WDATA directly to the OCC through the
//              regfile's passthrough"), so the "rx_buf" is the host-served push
//              stream and THIS block owns both fields of the register:
//                * depth  = host-written (§2: RW; "v0: depth ≤ 16KB" is a host
//                           contract — an over-bound value is stored verbatim,
//                           since no error response is defined and clamping would
//                           silently change host-visible state);
//                * wr_ptr = host-written on an RX_BUF_CTRL write (rebase), else
//                           advanced by hardware per accepted push, wrapping at
//                           16 bits;
//                * "rx_buf full" = depth != 0 && wr_ptr >= depth (`>=`, not `==`:
//                           a rebase below the current count must still read as
//                           full, never as a stuck session).
//              // ASSUMPTION: wr_ptr is hardware-advanced while §2 only says RW
//              // (TBD, 2026-09-13); the alternative is a host-maintained pointer
//              // (then there is no hardware counting and "full" is signalled by
//              // the host alone).
//
//              All state resets to the idle/empty encoding; no vendor primitive,
//              and the only state is the 5-state FSM, the terminal latch and the
//              rx pointer/depth registers (C05 §4.2 budget: "200 LUT 以内").
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Modified:    2026-09-13 - created (E2-BMC1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2 (0x10/0x11/0x12) / §4 (sticky
//              status rationale) / §5 (mFSM session FSM) ·
//              ethereal-plan/components/C05-BMC组件.md §4.2 (5-state FSM, rx_buf) ·
//              ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3
// Notes:       G1: typedef enum + two-segment FSM, always_ff non-blocking,
//              always_comb defaults first, no procedural loops. iverilog -g2012.
module mfsm_session (
  input  logic        clk_i,
  input  logic        rst_ni,

  // -- host session command: an ACCEPTED write to SESSION_CMD (offset 0x10)
  input  logic [7:0]  cmd_i,          // mfsm_pkg::SESSION_CMD_* (0 = nop)
  input  logic        cmd_valid_i,    // 1-cycle strobe

  // -- image-receive accounting: an ACCEPTED push (write to OCC_WDATA, 0x09)
  input  logic        rx_push_i,
  // -- host write to RX_BUF_CTRL (0x12): rebases wr_ptr / stores depth
  input  logic        rx_ctrl_wr_i,
  input  logic [31:0] rx_ctrl_wdata_i,
  output logic [31:0] rx_ctrl_o,      // {wr_ptr[31:16], depth[15:0]}

  // -- OCC terminal observation, decoded by the caller (mfsm_pkg::SESSION_TERM_*):
  //    the FSM consumes a terminal CLASS, not occ_top's raw status, so it carries
  //    no OCC encoding and stays a pure session tracker.
  input  logic        occ_term_valid_i,  // a terminal status is present this cycle
  input  logic [1:0]  occ_term_code_i,   // mfsm_pkg::SESSION_TERM_*

  // -- SESSION_STATUS word (emri-v0.md §5: state[3:0] + err[7:4])
  output logic [7:0]  status_o
);
  // ------------------------------------------------------------------
  // Encodings (single source of truth: mfsm_pkg; spec §2/§5). SESSION_CMD=0
  // (nop) needs no decode: no state changes, so only the four acting codes are
  // compared.
  // ------------------------------------------------------------------
  localparam logic [7:0] CMD_BEGIN_RX = mfsm_pkg::SESSION_CMD_BEGIN_RX;
  localparam logic [7:0] CMD_VERIFY   = mfsm_pkg::SESSION_CMD_VERIFY;
  localparam logic [7:0] CMD_OCC_GO   = mfsm_pkg::SESSION_CMD_OCC_GO;
  localparam logic [7:0] CMD_ABORT    = mfsm_pkg::SESSION_CMD_ABORT;

  localparam logic [3:0] ERR_NONE       = mfsm_pkg::SESSION_ERR_NONE;
  localparam logic [3:0] ERR_OCC_LOCKED = mfsm_pkg::SESSION_ERR_OCC_LOCKED;
  localparam logic [3:0] ERR_OCC_ERROR  = mfsm_pkg::SESSION_ERR_OCC_ERROR;

  localparam logic [1:0] TERM_DONE        = mfsm_pkg::SESSION_TERM_DONE;
  localparam logic [1:0] TERM_LOCKED      = mfsm_pkg::SESSION_TERM_LOCKED;

  localparam int          WRPTR_LSB        = mfsm_pkg::RX_BUF_WRPTR_LSB;
  localparam int          DEPTH_LSB        = mfsm_pkg::RX_BUF_DEPTH_LSB;
  localparam logic [15:0] RX_DEPTH_DEFAULT = mfsm_pkg::RX_BUF_MAX_DEPTH;

  // ------------------------------------------------------------------
  // FSM state (typedef enum + two-segment style, G1)
  // ------------------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE   = mfsm_pkg::SESSION_S_IDLE,
    S_RX     = mfsm_pkg::SESSION_S_RX,
    S_VERIFY = mfsm_pkg::SESSION_S_VERIFY,
    S_OCC_GO = mfsm_pkg::SESSION_S_OCC_GO,
    S_ERROR  = mfsm_pkg::SESSION_S_ERROR
  } sess_state_e;

  sess_state_e state_r, state_nxt;
  logic [3:0]  err_r,   err_nxt;

  // ------------------------------------------------------------------
  // Command strobes (one cycle each)
  // ------------------------------------------------------------------
  logic cmd_begin_w, cmd_verify_w, cmd_occ_go_w, cmd_abort_w;
  assign cmd_begin_w  = cmd_valid_i && (cmd_i == CMD_BEGIN_RX);
  assign cmd_verify_w = cmd_valid_i && (cmd_i == CMD_VERIFY);
  assign cmd_occ_go_w = cmd_valid_i && (cmd_i == CMD_OCC_GO);
  assign cmd_abort_w  = cmd_valid_i && (cmd_i == CMD_ABORT);

  // ------------------------------------------------------------------
  // RX_BUF_CTRL storage + accounting (see the header's RX ACCOUNTING note)
  // ------------------------------------------------------------------
  logic [15:0] rx_depth_r;
  logic [15:0] rx_wr_ptr_r;
  logic        rx_full_w;      // wr_ptr reached the host-staged depth
  logic        rx_push_w;      // this cycle's push is being counted

  assign rx_full_w = (rx_depth_r != 16'd0) && (rx_wr_ptr_r >= rx_depth_r);
  assign rx_push_w = rx_push_i;
  assign rx_ctrl_o = {rx_wr_ptr_r, rx_depth_r};

  // ------------------------------------------------------------------
  // OCC terminal observation (§4: terminal status is a 1-cycle pulse; latch the
  // first one seen while a session is live, consume it in OCC_GO).
  // ------------------------------------------------------------------
  logic        term_seen_r;   // a terminal was latched (first wins)
  logic [1:0]  term_code_r;
  logic        term_any_w;      // a terminal is available for the session
  logic [1:0]  term_use_code_w; // ... and its code (the latched one wins)

  assign term_any_w      = term_seen_r || occ_term_valid_i;
  assign term_use_code_w = term_seen_r ? term_code_r : occ_term_code_i;

  // consumable only in OCC_GO (the state the §5 diagram defines the edge in)
  logic term_consume_w;
  assign term_consume_w = (state_r == S_OCC_GO) && term_any_w;

  // ------------------------------------------------------------------
  // Next-state logic (combinational, defaults first)
  // ------------------------------------------------------------------
  always_comb begin
    state_nxt = state_r;
    err_nxt   = err_r;
    unique case (state_r)
      S_IDLE: begin
        if (cmd_begin_w) state_nxt = S_RX;
      end
      S_RX: begin
        if (cmd_abort_w)                     state_nxt = S_IDLE;
        else if (cmd_verify_w || rx_full_w)  state_nxt = S_VERIFY;
      end
      S_VERIFY: begin
        if (cmd_abort_w)       state_nxt = S_IDLE;
        else if (cmd_occ_go_w) state_nxt = S_OCC_GO;
      end
      S_OCC_GO: begin
        if (term_consume_w) begin
          if (term_use_code_w == TERM_DONE) begin
            state_nxt = S_IDLE;
            err_nxt   = ERR_NONE;
          end else begin
            state_nxt = S_ERROR;
            err_nxt   = (term_use_code_w == TERM_LOCKED) ? ERR_OCC_LOCKED : ERR_OCC_ERROR;
          end
        end
      end
      S_ERROR: begin
        if (cmd_abort_w) state_nxt = S_IDLE;
      end
      default: state_nxt = S_IDLE;
    endcase
    // A new session always clears the error field (§5: err is the session's
    // reason code and is meaningful only in ERROR / on the refusals above).
    if (cmd_begin_w || cmd_abort_w) err_nxt = ERR_NONE;
  end

  // ------------------------------------------------------------------
  // Sequential state
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_r     <= S_IDLE;
      err_r       <= ERR_NONE;
      term_seen_r <= 1'b0;
      term_code_r <= 2'd0;
      rx_depth_r  <= RX_DEPTH_DEFAULT;
      rx_wr_ptr_r <= 16'h0;
    end else begin
      state_r <= state_nxt;
      err_r   <= err_nxt;

      // terminal latch: the first terminal of the session wins; cleared by a new
      // session (begin_rx) and by the completion it produced in OCC_GO.
      if (cmd_begin_w || term_consume_w) begin
        term_seen_r <= 1'b0;
        term_code_r <= 2'd0;
      end else if (occ_term_valid_i) begin
        term_seen_r <= 1'b1;
        term_code_r <= occ_term_code_i;
      end

      // rx accounting: begin_rx starts a fresh image session (pointer to 0);
      // a host RX_BUF_CTRL write rebases both fields; each accepted push advances
      // the pointer (wrapping at 16 bits — an image beyond the v0 16 KiB bound
      // cannot be staged anyway, and the wrap keeps "full" monotone in a session).
      if (cmd_begin_w) begin
        rx_wr_ptr_r <= 16'h0;
      end else if (rx_ctrl_wr_i) begin
        rx_depth_r  <= rx_ctrl_wdata_i[DEPTH_LSB +: 16];
        rx_wr_ptr_r <= rx_ctrl_wdata_i[WRPTR_LSB +: 16];
      end else if (rx_push_w) begin
        rx_wr_ptr_r <= rx_wr_ptr_r + 16'd1;
      end
    end
  end

  // SESSION_STATUS word: state[3:0] + err[7:4] (spec §5; see mfsm_pkg for the
  // reported §2 `done[4]` field-overlap discrepancy).
  always_comb begin
    status_o = 8'h0;
    status_o[mfsm_pkg::SESSION_STATUS_STATE_LSB +: 4] = state_r;
    status_o[mfsm_pkg::SESSION_STATUS_ERR_LSB   +: 4] = err_r;
  end

endmodule
`default_nettype wire
