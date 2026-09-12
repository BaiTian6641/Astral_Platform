`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      mfsm_pkg (package)
// Description: mFSM encodings — the SESSION_CMD opcodes, the session FSM states
//              and its error codes (emri-v0.md §2 offset 0x10/0x11, §5).
// Details:     Single source of truth for the mFSM session surface, consumed by
//              mfsm_session/mfsm_top, the testbenches, and the golden model
//              (ethereal-fabric/tests/ebi/ebi_tiny_model.py cross-checks these
//              constants against emri-v0.md's documented encodings).
//
//              SESSION_CMD (§2 offset 0x10): 0=nop, 1=begin_rx, 2=verify
//              (host-done), 3=occ_go, 4=abort. BMC mode ignores it.
//              SESSION_STATUS (§2 offset 0x11): {state[3:0], done[4], err[7:4]}.
//
//              // SPEC DISCREPANCY (reported, not invented — G6): the §2 table
//              // entry `{state[3:0], done[4], err[7:4]}` places `done` at bit 4,
//              // which is inside `err[7:4]` (field overlap: 4+1+4 = 9 bits in an
//              // 8-bit register). §5's prose defines only two fields —
//              // `SESSION_STATUS.state` (0=IDLE,1=RX,2=VERIFY_REQ,3=OCC_GO,
//              // 4=ERROR) and `SESSION_STATUS.err[7:4]` (0=none,1=bad_crc,
//              // 2=occ_locked,3=occ_error) — and defines no `done` semantics.
//              // This package therefore implements state[3:0] + err[7:4] and
//              // leaves bits [7:4] fully owned by err (so err=1/bad_crc and
//              // err=3/occ_error set bit 4 by definition). Options given to the
//              // maintainer in the E2-BMC1 report: (A) drop `done` [implemented],
//              // (B) re-map to state[2:0]+done[3]+err[7:4], (C) keep `done` at a
//              // reserved bit in a v0.9 spec bump.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Modified:    2026-09-13 - created (E2-BMC1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2 (offsets 0x10/0x11) / §5 (mFSM
//              session FSM) · ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3 /
//              §4 · ethereal-plan/components/C05-BMC组件.md §4.2
// Notes:       Bounds for the v0 RX_BUF_CTRL: "v0: depth ≤ 16KB" (emri-v0.md §2
//              offset 0x12). The 5-state FSM is C05 §4.2's "fsm 只有 5 个状态，
//              200 LUT 以内".
package mfsm_pkg;

  // ------------------------------------------------------------------
  // SESSION_CMD opcodes (emri-v0.md §2 offset 0x10)
  // ------------------------------------------------------------------
  localparam logic [7:0] SESSION_CMD_BEGIN_RX = 8'd1;
  localparam logic [7:0] SESSION_CMD_VERIFY   = 8'd2;  // host has verified the image
  localparam logic [7:0] SESSION_CMD_OCC_GO   = 8'd3;  // host confirmed; OCC ops may run
  localparam logic [7:0] SESSION_CMD_ABORT    = 8'd4;

  // ------------------------------------------------------------------
  // Session FSM states (emri-v0.md §5 "SESSION_STATUS.state")
  // ------------------------------------------------------------------
  localparam logic [3:0] SESSION_S_IDLE     = 4'd0;
  localparam logic [3:0] SESSION_S_RX       = 4'd1;
  localparam logic [3:0] SESSION_S_VERIFY   = 4'd2;
  localparam logic [3:0] SESSION_S_OCC_GO   = 4'd3;
  localparam logic [3:0] SESSION_S_ERROR    = 4'd4;

  // ------------------------------------------------------------------
  // Session error codes (emri-v0.md §5 "SESSION_STATUS.err[7:4]")
  // ------------------------------------------------------------------
  localparam logic [3:0] SESSION_ERR_NONE       = 4'd0;
  localparam logic [3:0] SESSION_ERR_OCC_LOCKED = 4'd2;  // OCC reported LOCKED (§3.10)
  localparam logic [3:0] SESSION_ERR_OCC_ERROR  = 4'd3;  // OCC ERROR / NEEDS_BLANK

  // ------------------------------------------------------------------
  // OCC terminal classes (emri-v0.md §4 `done_code`): what the session FSM
  // consumes instead of occ_top's raw status, so the FSM needs no OCC encoding
  // and stays a pure session tracker. mfsm_top decodes occ_status_i into these.
  // ------------------------------------------------------------------
  // The group carries a documented UNUSEDPARAM waiver because consumers differ
  // per build target (mfsm_top decodes all four; mfsm_session compares DONE and
  // LOCKED only, the rest being its other two class branches; the deploy
  // testbench and golden model cover the remainder) — same idiom as emri_pkg.
  /* verilator lint_off UNUSEDPARAM */
  localparam logic [1:0] SESSION_TERM_DONE        = 2'd0;  // clean completion
  localparam logic [1:0] SESSION_TERM_ERROR       = 2'd1;  // occ_top ERROR
  localparam logic [1:0] SESSION_TERM_NEEDS_BLANK = 2'd2;  // E0-FAB5 dirty gate
  localparam logic [1:0] SESSION_TERM_LOCKED      = 2'd3;  // §3.10 lock gate
  /* verilator lint_on UNUSEDPARAM */

  // ------------------------------------------------------------------
  // mFSM-wide encodings kept as the single source of truth (spec-first rule)
  // that a given build target does not consume — under a documented UNUSEDPARAM
  // waiver (same idiom as emri_pkg's forward-compat constants). The consumers
  // differ per target: mfsm_top uses all four terminal classes, mfsm_session uses
  // DONE/LOCKED for its class map, the deploy testbench and the golden model
  // cover the rest.
  //   * SESSION_CMD_NOP — 0 is the no-op command code; mfsm_session compares only
  //     the four acting codes, because "write 0" changes nothing;
  //   * SESSION_STATES — the §5 state count (documentation / TB coverage);
  //   * SESSION_ERR_BAD_CRC — reserved with NO v0 producer: per §5's own G6
  //     resolution the HOST computes Ed25519+CRC32 (the mFSM has no CPU), so a
  //     failed check is the host's to catch (it writes abort, not occ_go).
  // ------------------------------------------------------------------
  /* verilator lint_off UNUSEDPARAM */
  localparam logic [7:0] SESSION_CMD_NOP     = 8'd0;
  localparam int         SESSION_STATES      = 5;
  localparam logic [3:0] SESSION_ERR_BAD_CRC = 4'd1;
  /* verilator lint_on UNUSEDPARAM */

  // ------------------------------------------------------------------
  // SESSION_STATUS bit layout (the two fields §5 actually defines)
  // ------------------------------------------------------------------
  localparam int SESSION_STATUS_STATE_LSB = 0;  // [3:0]
  localparam int SESSION_STATUS_ERR_LSB   = 4;  // [7:4]

  // ------------------------------------------------------------------
  // RX_BUF_CTRL field layout (§2 offset 0x12) + the v0 depth bound.
  // ------------------------------------------------------------------
  localparam int          RX_BUF_DEPTH_LSB  = 0;      // [15:0]
  localparam int          RX_BUF_WRPTR_LSB  = 16;     // [31:16]
  localparam logic [15:0] RX_BUF_MAX_DEPTH  = 16'h4000;  // 16 KiB = 4096 words

endpackage : mfsm_pkg
`default_nettype wire
