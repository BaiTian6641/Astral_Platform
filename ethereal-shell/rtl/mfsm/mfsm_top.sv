`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      mfsm_top
// Description: mFSM — the small-device (Profile-E) register-based management
//              unit: the EMRI register face in mFSM mode plus the §5 session FSM.
//              No CPU, host-driven (ADR-014); the same EMRI ABI as the BMC
//              (ADR-015), so ethctl is transparent to which side it talks to.
// Details:     COMPOSITION. `mfsm_top` = `emri_regfile #(HAS_BMC=0)` (the EMRI
//              register face, reused verbatim — the ABI is not re-implemented)
//              + `mfsm_session` (the 5-state session FSM of emri-v0.md §5). The
//              wrapper adds exactly three things:
//                1. the EBI-Tiny shell-CSR slave shape (byte-addressed window
//                   offset + byte strobes) that ebi_tiny delivers;
//                2. interception of the two registers whose state belongs to the
//                   session FSM rather than to plain storage:
//                     * SESSION_STATUS (0x11) reads return the LIVE
//                       {state[3:0], err[7:4]} of mfsm_session (spec §5) — the
//                       regfile's plain storage would hold the last host-written
//                       word, which is not a status at all;
//                     * RX_BUF_CTRL (0x12) reads return the LIVE
//                       {wr_ptr[31:16], depth[15:0]} maintained by mfsm_session
//                       (spec §2 offset 0x12). This shadows the regfile's own
//                       read-back, which hardwires wr_ptr=0 and returns only
//                       `depth` (emri_regfile.sv "R_RX_BUF_CTRL: {16'h0,
//                       rx_buf_depth_w}") — a spec-vs-implementation
//                       discrepancy reported by E2-BMC1, not re-created here;
//                     * SESSION_CMD (0x10) writes are forwarded to the FSM as
//                       commands AND stored by the regfile (spec §2 marks it RW,
//                       so the last written code stays readable).
//                3. the live OCC status observation the session FSM needs.
//              Everything else (identity/capability/status mirrors, the OCC
//              passthrough with its backpressure, the EFP block, the event ring,
//              capability gate, anomaly monitor, context surface, lock matrix) is
//              the register face's own behaviour — untouched, so BMC and mFSM
//              cannot drift apart on it.
//
//              CAPABILITIES: HAS_BMC=0 is the ONLY ABI field that differs between
//              the two implementations (spec §1 principle 1: "The ONLY field that
//              differs is CAPABILITIES.has_bmc"), which the deploy testbench
//              asserts by sweeping the whole map against a BMC-mode regfile.
//
//              HOST ACCESS RULES (EBI-Tiny shell-CSR window):
//                * the request is HELD until ready_o (one-cycle accept), rdata_o
//                  valid in that cycle — the same contract as emri_regfile's host
//                  port and as ebi_tiny's master port, so no adapter is needed;
//                * the register word offset is `addr_i[15:2]` (the byte->word
//                  conversion of emri_axi_adapter's `(addr - REG_BASE) >> 2`), so
//                  an EBI-Tiny host and an AXI host address one register map;
//                * a write with partial byte strobes (wstrb != 4'hF) is answered
//                  as an ERROR and NOT forwarded: EMRI registers are 32-bit word
//                  registers and byte-lane writes have no meaning (emri-v0.md §2);
//                  this mirrors emri_axi_adapter's documented SLVERR rule;
//                * an unassigned offset INSIDE the window is NOT an error: the
//                  register face reads reserved offsets as 0 and ignores writes
//                  (§2 "Reserved ranges: read-as-0, write-ignored"); only an
//                  address outside every ebi_tiny window is an error there.
//
//              PROFILE-E SCOPE: no CPU, no NoC, no arbitration — this is the
//              ADR-006/ADR-014 degraded path. `rtl/ebi/ebi_tiny.sv` is the bus it
//              terminates (see mfsm_ebi_top for the wired Shell-CSR integration).
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Modified:    2026-09-13 - created (E2-BMC1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3/§4 (mFSM =
//              "无 CPU 的寄存器式管理单元"; unified EMRI ABI) ·
//              ethereal-plan/components/C05-BMC组件.md §3.1/§3.2/§4.1 ·
//              ethereal-spec/control/emri-v0.md §1 (one map, two implementations;
//              v0 mFSM scope), §2 (map), §5 (session FSM), §8 (BMC vs mFSM table)
// Notes:       G1: no procedural loops, always_comb defaults first, ports _i/_o.
//              Lint: `verilator --lint-only -Wall` clean; iverilog -g2012. End-to-end
//              evidence: ethereal-fabric/tests/mfsm/tb_mfsm_ebi_deploy.sv.
module mfsm_top #(
  parameter int          NUM_REGIONS     = 2,          // v0 fixed (ADR-004 build-time)
  parameter logic [31:0] PLATFORM_ID     = 32'h0000_0000,  // 0 = sim
  parameter logic [31:0] REGION0_INFO    = 32'h0202_0010,
  parameter logic [31:0] REGION1_INFO    = 32'h0202_0010,
  parameter logic [15:0] MON_TEMP_SIM    = 16'h0019,   // 25 C placeholder (spec §9)
  parameter logic [15:0] MON_VCCINT_SIM  = 16'h0338    // ASSUMPTION 824mV (spec §9)
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // -- EBI-Tiny shell-CSR slave (intra-window byte offset; see the header)
  input  logic        req_i,
  input  logic        we_i,
  input  logic [15:0] addr_i,      // byte offset inside the Shell-CSR window
  input  logic [31:0] wdata_i,
  input  logic [3:0]  wstrb_i,
  output logic [31:0] rdata_o,
  output logic        ready_o,     // 1-cycle accept/response (held until high)
  output logic        err_o,       // with ready_o: partial-strobe write refused

  // -- OCC master (drives occ_top; identical shape to emri_regfile)
  output logic [1:0]  occ_cmd_o,
  output logic        occ_cmd_valid_o,
  input  logic        occ_cmd_ready_i,
  output logic [15:0] occ_frame_addr_o,
  output logic [15:0] occ_word_count_o,
  output logic [31:0] occ_wdata_o,
  output logic        occ_wdata_valid_o,
  input  logic        occ_wdata_ready_i,
  input  logic [2:0]  occ_status_i,
  input  logic        occ_crc_error_i,
  output logic [7:0]  occ_region_locks_o,
  output logic        occ_global_lock_o,
  output logic [31:0] occ_expect_crc_o,
  input  logic [31:0] occ_crc_result_i,

  // -- frame_decoder start trigger (0x0D; packed deploy)
  output logic        dec_start_o,
  output logic [7:0]  dec_col_o,
  input  logic        dec_busy_i,

  // -- ctx_scan engine command/status (0x26-0x28; the engine + context RAM live
  //    at the integration level, exactly as in emri_regfile)
  output logic        ctx_start_o,
  output logic        ctx_mode_o,
  output logic [15:0] ctx_words_o,
  input  logic        ctx_busy_i,
  input  logic        ctx_done_i,
  input  logic        ctx_err_i
);
  // ------------------------------------------------------------------
  // Register word offset: byte offset -> EMRI word offset (emri_axi_adapter's
  // (addr - REG_BASE) >> 2 conversion, applied to the window offset).
  // The 14-bit word field is zero-extended to the register face's 16-bit port;
  // the map's highest offset (IMG_SIG[15] = 0x5F) fits with room to spare.
  // ------------------------------------------------------------------
  logic [15:0] word_addr_w;
  assign word_addr_w = {2'b00, addr_i[15:2]};

  // The two low bits of the byte offset are the word-offset fraction: EMRI
  // registers are 32-bit word registers, so byte-lane addressing carries no
  // meaning and the bits are deliberately ignored — identical to
  // emri_axi_adapter's `(addr - REG_BASE) >> 2`, which is what keeps an EBI-Tiny
  // host and an AXI host on one register map. Fold them into a reduction sink so
  // -Wall stays clean (house idiom: emri_axi_adapter / eth_axi_lite_slave).
  // verilator lint_off UNUSEDSIGNAL
  logic unused_ok;
  assign unused_ok = &{1'b0, addr_i[1:0]};
  // verilator lint_on UNUSEDSIGNAL

  // ------------------------------------------------------------------
  // Host write classification
  //   partial_wr_w : byte-lane write to a 32-bit register -> refused with err
  //   rf_req_w     : the request actually presented to the register face
  //   wr_accept_w  : the register face ACCEPTED a write this cycle (its ready
  //                  already includes OCC wdata-skid and frame-decoder
  //                  backpressure, so "accepted push" == OCC accepted the word)
  // ------------------------------------------------------------------
  logic partial_wr_w, rf_req_w, rf_ready_w, wr_accept_w;
  assign partial_wr_w = req_i && we_i && (wstrb_i != 4'hF);
  assign rf_req_w     = req_i && !partial_wr_w;
  assign wr_accept_w  = rf_req_w && we_i && rf_ready_w;

  assign ready_o = partial_wr_w ? req_i : rf_ready_w;
  assign err_o   = partial_wr_w ? req_i : 1'b0;

  // ------------------------------------------------------------------
  // Session hooks (an accepted SESSION_CMD / OCC_WDATA / RX_BUF_CTRL write)
  // ------------------------------------------------------------------
  logic sess_cmd_wr_w, rx_push_w, rx_ctrl_wr_w;
  assign sess_cmd_wr_w = wr_accept_w && (word_addr_w == emri_pkg::R_SESSION_CMD);
  assign rx_push_w     = wr_accept_w && (word_addr_w == emri_pkg::R_OCC_WDATA);
  assign rx_ctrl_wr_w  = wr_accept_w && (word_addr_w == emri_pkg::R_RX_BUF_CTRL);

  // ------------------------------------------------------------------
  // Session FSM (spec §5). The OCC terminal class decode lives here — this is
  // the EMRI/OCC-aware layer — so the FSM consumes a terminal class, not a raw
  // occ_top status (emri-v0.md §4 done_code ordering: DONE/ERROR/NEEDS_BLANK/LOCKED).
  // ------------------------------------------------------------------
  logic        occ_term_valid_w;
  logic [1:0]  occ_term_code_w;
  logic [7:0]  sess_status_w;
  logic [31:0] sess_rx_ctrl_w;

  always_comb begin
    occ_term_valid_w = 1'b1;
    occ_term_code_w  = mfsm_pkg::SESSION_TERM_ERROR;   // generic error default
    unique case (occ_status_i)
      emri_pkg::OCC_S_DONE:        occ_term_code_w = mfsm_pkg::SESSION_TERM_DONE;
      emri_pkg::OCC_S_ERROR:       occ_term_code_w = mfsm_pkg::SESSION_TERM_ERROR;
      emri_pkg::OCC_S_NEEDS_BLANK: occ_term_code_w = mfsm_pkg::SESSION_TERM_NEEDS_BLANK;
      emri_pkg::OCC_S_LOCKED:      occ_term_code_w = mfsm_pkg::SESSION_TERM_LOCKED;
      default:                     occ_term_valid_w = 1'b0;  // IDLE/BUSY: not terminal
    endcase
  end

  mfsm_session u_session (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .cmd_i(wdata_i[7:0]), .cmd_valid_i(sess_cmd_wr_w),
    .rx_push_i(rx_push_w),
    .rx_ctrl_wr_i(rx_ctrl_wr_w), .rx_ctrl_wdata_i(wdata_i), .rx_ctrl_o(sess_rx_ctrl_w),
    .occ_term_valid_i(occ_term_valid_w), .occ_term_code_i(occ_term_code_w),
    .status_o(sess_status_w)
  );

  // ------------------------------------------------------------------
  // EMRI register face (mFSM mode: HAS_BMC=0 -> CAPABILITIES.has_bmc=0)
  // ------------------------------------------------------------------
  logic [31:0] rf_rdata_w;
  logic [31:0] rf_expect_crc_w;   // 0x0E storage -> OCC expected-CRC gate

  emri_regfile #(
    .HAS_BMC(1'b0),
    .NUM_REGIONS(NUM_REGIONS),
    .PLATFORM_ID(PLATFORM_ID),
    .REGION0_INFO(REGION0_INFO),
    .REGION1_INFO(REGION1_INFO),
    .MON_TEMP_SIM(MON_TEMP_SIM),
    .MON_VCCINT_SIM(MON_VCCINT_SIM)
  ) u_regfile (
    .clk_i(clk_i), .rst_ni(rst_ni),
    .host_req_i(rf_req_w),
    .host_we_i(we_i),
    // EBI-Tiny has no op field: a write is a write (SPI_OP_WR) and a read a read
    // (SPI_OP_RD). The EFP-SPI OCC_PUSH op is a TRANSPORT shortcut that the SPI
    // front-end resolves into a plain write of OCC_WDATA — which the register face
    // already treats as a push (emri_regfile "addr_is_occ_wdata_push" accepts
    // (op==WR && addr==R_OCC_WDATA)). No op distinction is lost on this profile.
    .host_op_i(we_i ? emri_pkg::SPI_OP_WR : emri_pkg::SPI_OP_RD),
    .host_addr_i(word_addr_w), .host_wdata_i(wdata_i),
    .host_rdata_o(rf_rdata_w), .host_ready_o(rf_ready_w),
    .occ_cmd_o(occ_cmd_o), .occ_cmd_valid_o(occ_cmd_valid_o),
    .occ_cmd_ready_i(occ_cmd_ready_i),
    .occ_frame_addr_o(occ_frame_addr_o), .occ_word_count_o(occ_word_count_o),
    .occ_wdata_o(occ_wdata_o), .occ_wdata_valid_o(occ_wdata_valid_o),
    .occ_wdata_ready_i(occ_wdata_ready_i),
    .occ_status_i(occ_status_i), .occ_crc_error_i(occ_crc_error_i),
    .occ_region_locks_o(occ_region_locks_o), .occ_global_lock_o(occ_global_lock_o),
    .occ_expect_crc_o(rf_expect_crc_w), .occ_crc_result_i(occ_crc_result_i),
    .dec_start_o(dec_start_o), .dec_col_o(dec_col_o), .dec_busy_i(dec_busy_i),
    .ctx_start_o(ctx_start_o), .ctx_mode_o(ctx_mode_o), .ctx_words_o(ctx_words_o),
    .ctx_busy_i(ctx_busy_i), .ctx_done_i(ctx_done_i), .ctx_err_i(ctx_err_i)
  );
  assign occ_expect_crc_o = rf_expect_crc_w;

  // ------------------------------------------------------------------
  // Read mux: the two session-owned registers override the register face; every
  // other offset is the register face's own read-back (identity, capability,
  // OCC status sticky bits, EFP block, ring, monitors, locks, ...).
  // ------------------------------------------------------------------
  logic        rd_ovr_w;
  logic [31:0] rd_ovr_data_w;

  always_comb begin
    rd_ovr_w      = 1'b0;
    rd_ovr_data_w = 32'h0;
    if (!we_i && (word_addr_w == emri_pkg::R_SESSION_STATUS)) begin
      rd_ovr_w = 1'b1;
      rd_ovr_data_w[7:0] = sess_status_w;   // {err[7:4], state[3:0]} (spec §5)
    end else if (!we_i && (word_addr_w == emri_pkg::R_RX_BUF_CTRL)) begin
      rd_ovr_w      = 1'b1;
      rd_ovr_data_w = sess_rx_ctrl_w;
    end
  end

  assign rdata_o = (rd_ovr_w && rf_ready_w) ? rd_ovr_data_w : rf_rdata_w;

endmodule
`default_nettype wire
