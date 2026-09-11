`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      emri_regfile
// Description: EMRI register file (v0) — the unified management register ABI.
// Details:     Owns the v0 register map (ethereal-spec/control/emri-v0.md §2):
//                * read-only identity/capability/status mirrors (MAGIC, ABI,
//                  CAPABILITIES, PLATFORM_ID, NUM_REGIONS, REGION_INFO, HEALTH,
//                  MON_*);
//                * read/write OCC control regs (OCC_FRAME_ADDR, OCC_WORD_COUNT);
//                * the OCC command/data passthrough (OCC_CMD.start -> occ_cmd_valid,
//                  OCC_WDATA / EFP-SPI OCC_PUSH -> occ_wdata_valid) with OCC
//                  backpressure propagated to the host as a stalled ready;
//                * OCC_STATUS assembled from occ_status_i / occ_crc_error_i.
//
//              v0.2 (spec §3.2): the EFP command block (EFP_CMD/EFP_REGION/
//              EFP_IMG_WORDS/EFP_STATUS/EFP_ERR + IMG_DIGEST[0..7] +
//              IMG_SIG[0..15]; v0.3 §3.3 adds EFP_IMG_COLS @ 0x21) is
//              implemented as PLAIN RW storage — the
//              regfile has no port-role distinction; the host/daemon
//              doorbell-and-clear discipline is a software convention.
//
//              v0.6 (spec §3.7/§3.8): the CAPABILITY-DECLARATION GATE
//              (CAP_DECL_IO/CAP_DECL_SVC plain RW staging + a read-only
//              CAP_STATUS comparator: checked latch / live denied / live
//              throttled / denied_io low byte) and the ANOMALY MONITOR v1
//              (MON_NOTIFY write-pulses -> per-region saturating
//              MON_RECFG_COUNT/MON_WDT_COUNT; a 4096-clock tick divider drives
//              the MON_ANOM_WINDOW observation window; per-window counter
//              deltas above MON_ANOM_THRESH set the MON_ANOM_STATUS spike
//              flags [11:8] + throttle mask [7:0], and the first flag 0->1 per
//              region per window pushes a code-5 event into the §3.4 ring).
//
//              Region lock (occ_region_locked_o) is hardwired 0 in v0: blank-before-
//              write is already hardware-enforced inside occ_top (E0-FAB5 dirty bit
//              + S_NEEDS_BLANK), and v0 has no per-region lifecycle lock yet.
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Modified:    2026-09-11 - v0.6 capability gate (§3.7) + anomaly monitor (§3.8)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3/§4 (§3.7/§3.8 v0.6)
// Notes:       G1: default_nettype none, always_ff non-blocking, no latches
//              (read mux is combinational with a default). Single host slave port
//              (fabric clock domain); the SPI slave / BMC bus feeds this port.
module emri_regfile #(
  parameter bit          HAS_BMC         = 1'b0,    // 0 = mFSM mode (cap bit0)
  parameter int          NUM_REGIONS     = 2,        // v0 fixed (ADR-004 build-time)
  parameter logic [31:0] PLATFORM_ID     = 32'h0000_0000,  // 0 = sim
  // Static per-region geometry {cols[31:24],rows[23:16],tiles[15:0]} (v0: 2 regions)
  parameter logic [31:0] REGION0_INFO    = 32'h0202_0010,  // 2x2 = 16 tiles (4x4 fabric /2)
  parameter logic [31:0] REGION1_INFO    = 32'h0202_0010,
  parameter logic [15:0] MON_TEMP_SIM    = 16'h0019,  // 25 C placeholder
  parameter logic [15:0] MON_VCCINT_SIM  = 16'h0338   // ASSUMPTION 824mV (spec §9)
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // -- Host register-access slave (fabric clock domain; SPI slave / BMC bus feeds this)
  input  logic        host_req_i,     // request valid
  input  logic        host_we_i,      // 1 = write
  input  logic [1:0]  host_op_i,      // EFP-SPI OP (RD/WR/BLOCK_RD/OCC_PUSH)
  input  logic [15:0] host_addr_i,    // word offset
  input  logic [31:0] host_wdata_i,
  output logic [31:0] host_rdata_o,
  output logic        host_ready_o,   // 1-cycle accept/response pulse

  // -- OCC master (drives occ_top)
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
  output logic        occ_region_locked_o,  // v0: hardwired 0 (see Details)
  output logic [31:0] occ_expect_crc_o,     // v0.5 §3.1.1: expected READBACK CRC (regfile storage)
  input  logic [31:0] occ_crc_result_i,     // v0.5 §3.1.1: occ_top running/streaming CRC

  // -- frame_decoder start trigger (v0.1, emri-v0.md §3.1)
  output logic        dec_start_o,          // 1-cycle pulse on R_OCC_DECODE write
  output logic [7:0]  dec_col_o,            // target fabric column (col_i)
  input  logic        dec_busy_i            // frame_decoder busy_o (write backpressure)
);
  // emri_pkg constants, aliased via explicit package scoping. (Yosys's
  // default SV frontend used for the formal/sby build does not accept
  // `import pkg::*;` — slang/surelog unavailable in this build. Explicit
  // scoping works in Yosys, iverilog, and verilator, and still uses the
  // shared emri_pkg single source of truth — no ABI drift.)
  localparam logic [31:0] EMRI_MAGIC       = emri_pkg::EMRI_MAGIC;
  localparam logic [31:0] EMRI_ABI_VERSION = emri_pkg::EMRI_ABI_VERSION;
  localparam logic [15:0] R_MAGIC          = emri_pkg::R_MAGIC;
  localparam logic [15:0] R_ABI_VERSION    = emri_pkg::R_ABI_VERSION;
  localparam logic [15:0] R_CAPABILITIES   = emri_pkg::R_CAPABILITIES;
  localparam logic [15:0] R_PLATFORM_ID    = emri_pkg::R_PLATFORM_ID;
  localparam logic [15:0] R_NUM_REGIONS    = emri_pkg::R_NUM_REGIONS;
  localparam logic [15:0] R_REGION_SEL     = emri_pkg::R_REGION_SEL;
  localparam logic [15:0] R_REGION_INFO    = emri_pkg::R_REGION_INFO;
  localparam logic [15:0] R_OCC_CMD        = emri_pkg::R_OCC_CMD;
  localparam logic [15:0] R_OCC_WDATA      = emri_pkg::R_OCC_WDATA;
  localparam logic [15:0] R_OCC_STATUS     = emri_pkg::R_OCC_STATUS;
  localparam logic [15:0] R_OCC_FRAME_ADDR = emri_pkg::R_OCC_FRAME_ADDR;
  localparam logic [15:0] R_OCC_WORD_COUNT = emri_pkg::R_OCC_WORD_COUNT;
  localparam logic [15:0] R_OCC_DECODE     = emri_pkg::R_OCC_DECODE;
  localparam logic [15:0] R_OCC_EXPECT_CRC = emri_pkg::R_OCC_EXPECT_CRC;
  localparam logic [15:0] R_OCC_CRC_RESULT = emri_pkg::R_OCC_CRC_RESULT;
  localparam logic [15:0] R_SESSION_CMD    = emri_pkg::R_SESSION_CMD;
  localparam logic [15:0] R_SESSION_STATUS = emri_pkg::R_SESSION_STATUS;
  localparam logic [15:0] R_RX_BUF_CTRL    = emri_pkg::R_RX_BUF_CTRL;
  localparam logic [15:0] R_EVT_LOG_CTRL   = emri_pkg::R_EVT_LOG_CTRL;
  localparam logic [15:0] R_EVT_LOG_DATA   = emri_pkg::R_EVT_LOG_DATA;
  localparam int          EVT_LOG_DEPTH    = emri_pkg::EVT_LOG_DEPTH;
  localparam logic [31:0] EVT_LOG_CLEAR    = emri_pkg::EVT_LOG_CLEAR;
  localparam logic [15:0] R_HEALTH_STATUS  = emri_pkg::R_HEALTH_STATUS;
  localparam logic [15:0] R_MON_TEMP       = emri_pkg::R_MON_TEMP;
  localparam logic [15:0] R_MON_VCCINT     = emri_pkg::R_MON_VCCINT;
  localparam logic [15:0] R_CAP_DECL_IO    = emri_pkg::R_CAP_DECL_IO;
  localparam logic [15:0] R_CAP_DECL_SVC   = emri_pkg::R_CAP_DECL_SVC;
  localparam logic [15:0] R_CAP_STATUS     = emri_pkg::R_CAP_STATUS;
  localparam logic [31:0] ALLOWED_IO_GROUPS = emri_pkg::ALLOWED_IO_GROUPS;
  localparam logic [31:0] ALLOWED_SERVICES  = emri_pkg::ALLOWED_SERVICES;
  localparam logic [15:0] R_MON_RECFG_COUNT = emri_pkg::R_MON_RECFG_COUNT;
  localparam logic [15:0] R_MON_WDT_COUNT   = emri_pkg::R_MON_WDT_COUNT;
  localparam logic [15:0] R_MON_ANOM_STATUS = emri_pkg::R_MON_ANOM_STATUS;
  localparam logic [15:0] R_MON_ANOM_WINDOW = emri_pkg::R_MON_ANOM_WINDOW;
  localparam logic [15:0] R_MON_ANOM_THRESH = emri_pkg::R_MON_ANOM_THRESH;
  localparam logic [15:0] R_MON_NOTIFY      = emri_pkg::R_MON_NOTIFY;
  localparam int          EMRI_MON_TICK_DIV = emri_pkg::EMRI_MON_TICK_DIV;
  localparam logic [15:0] MON_ANOM_WINDOW_DEF = emri_pkg::EMRI_MON_ANOM_WINDOW_DEF;
  localparam logic [31:0] MON_ANOM_THRESH_DEF = emri_pkg::EMRI_MON_ANOM_THRESH_DEF;
  localparam logic [7:0]  EVT_CODE_ANOMALY_THROTTLE = emri_pkg::EVT_CODE_ANOMALY_THROTTLE;
  localparam logic [15:0] R_EFP_CMD        = emri_pkg::R_EFP_CMD;
  localparam logic [15:0] R_EFP_REGION     = emri_pkg::R_EFP_REGION;
  localparam logic [15:0] R_EFP_IMG_WORDS  = emri_pkg::R_EFP_IMG_WORDS;
  localparam logic [15:0] R_EFP_STATUS     = emri_pkg::R_EFP_STATUS;
  localparam logic [15:0] R_EFP_ERR        = emri_pkg::R_EFP_ERR;
  localparam logic [15:0] R_EFP_IMG_COLS   = emri_pkg::R_EFP_IMG_COLS;
  localparam logic [15:0] R_IMG_DIGEST     = emri_pkg::R_IMG_DIGEST;
  localparam logic [15:0] R_IMG_SIG        = emri_pkg::R_IMG_SIG;
  localparam int          IMG_DIGEST_WORDS = emri_pkg::IMG_DIGEST_WORDS;
  localparam int          IMG_SIG_WORDS    = emri_pkg::IMG_SIG_WORDS;
  localparam int          OCC_CMD_START    = emri_pkg::OCC_CMD_START;
  localparam logic [2:0]  OCC_S_DONE       = emri_pkg::OCC_S_DONE;
  localparam logic [2:0]  OCC_S_ERROR      = emri_pkg::OCC_S_ERROR;
  localparam logic [2:0]  OCC_S_LOCKED     = emri_pkg::OCC_S_LOCKED;
  localparam logic [2:0]  OCC_S_NEEDS_BLANK = emri_pkg::OCC_S_NEEDS_BLANK;
  localparam logic [1:0]  SPI_OP_WR        = emri_pkg::SPI_OP_WR;
  localparam logic [1:0]  SPI_OP_OCC_PUSH  = emri_pkg::SPI_OP_OCC_PUSH;

  // ------------------------------------------------------------------
  // Capabilities (parameter-derived; spec §2). v0: only has_bmc is meaningful;
  //  DMA/I2C/TRNG/JTAG are 0 (not yet implemented). BMC mode sets has_bmc=1.
  // ------------------------------------------------------------------
  logic [31:0] capabilities_w;
  assign capabilities_w = {31'h0, HAS_BMC};

  // Health (v0: all-ok bitmap, bit-per-region). bit0=r0, bit8=r1, bit16=r2, bit24=r3.
  logic [31:0] health_status_w;
  assign health_status_w =
      (NUM_REGIONS > 0 ? 32'h0000_0001 : 32'h0) |
      (NUM_REGIONS > 1 ? 32'h0000_0100 : 32'h0) |
      (NUM_REGIONS > 2 ? 32'h0001_0000 : 32'h0) |
      (NUM_REGIONS > 3 ? 32'h0100_0000 : 32'h0);

  // ------------------------------------------------------------------
  // RW configuration registers
  // ------------------------------------------------------------------
  logic [15:0] occ_frame_addr_r;
  logic [15:0] occ_word_count_r;
  logic [31:0] occ_expect_crc_r;   // v0.5 §3.1.1 (plain RW storage)
  logic [7:0]  region_sel_r;
  // OCC command latch (held until occ_cmd_ready pulse)
  logic [1:0]  occ_cmd_r;
  logic [3:0]  occ_region_r;
  logic        occ_start_r;
  // OCC wdata staging (1-cycle pulse on host OCC_PUSH / OCC_WDATA write)
  logic [31:0] occ_wdata_r;
  logic        occ_wdata_pending_r;
  // SESSION_CMD/STATUS plain storage (v0: no device FSM consumes them)
  logic [7:0]  session_cmd_r;
  logic [7:0]  session_status_r;
  // RX_BUF_CTRL (v0: host-readable placeholder; depth fixed)
  logic [15:0] rx_buf_depth_w = 16'h4000;  // 16 KB

  // ------------------------------------------------------------------
  // EFP command block storage (v0.2, spec §3.2). All PLAIN RW storage —
  // the regfile has no port-role distinction; the doorbell protocol
  // (host writes EFP_CMD, the BMC daemon clears it to NOP on accept and
  // owns EFP_STATUS/EFP_ERR) is a software convention only.
  // ------------------------------------------------------------------
  logic [7:0]  efp_cmd_r;
  logic [7:0]  efp_region_r;
  logic [15:0] efp_img_words_r;
  logic [7:0]  efp_status_r;
  logic [7:0]  efp_err_r;
  logic [7:0]  efp_img_cols_r;  // v0.3 (spec §3.3): run_packed column count
  logic [31:0] img_digest_r [IMG_DIGEST_WORDS];  // 32 B manifest digest
  logic [31:0] img_sig_r   [IMG_SIG_WORDS];      // 64 B Ed25519 signature
  // ------------------------------------------------------------------
  // v0.6 §3.7 capability-declaration gate storage. CAP_DECL_IO/CAP_DECL_SVC
  // are PLAIN RW staging storage: the host writes them from capabilities.yaml
  // BEFORE the EFP_CMD doorbell (§3.7 step 1), so they are NOT cleared by an
  // EFP_CMD write — only CAP_STATUS is cleared per session (spec §3.7 rule 3:
  // a stale bitmap is the host's responsibility to overwrite). cap_checked_r
  // records "a declaration was staged this session" (first CAP_DECL write
  // since reset / the last EFP_CMD write); denied/throttled/denied_io are LIVE
  // comparator outputs (spec §2 offset 0x24).
  // ------------------------------------------------------------------
  logic [31:0] cap_decl_io_r;
  logic [31:0] cap_decl_svc_r;
  logic        cap_checked_r;

  // ------------------------------------------------------------------
  // v0.6 §3.8 anomaly-monitor storage. MON_ANOM_WINDOW/MON_ANOM_THRESH and
  // MON_ANOM_STATUS reset to their SPEC DEFAULTS (0x1000 / 0x0008_0010 / 0) —
  // unlike the reset-less plain-RW config registers elsewhere in this file.
  // The monitor is 2-region by spec: MON_RECFG_COUNT/MON_WDT_COUNT pack
  // {region1[31:16], region0[15:0]} and MON_ANOM_STATUS[11:8] allocates four
  // flag bits (8+r recfg, 10+r wdt, r=0,1). The v0 fabric has NUM_REGIONS=2
  // (ADR-004 build-time), so MON_NOTIFY bits [7:2]/[15:10] address regions
  // that do not exist and are ignored.
  // ------------------------------------------------------------------
  localparam int MON_REGIONS = 2;   // spec count/flag layout capacity
  localparam int MON_DIV_W   = $clog2(EMRI_MON_TICK_DIV);
  logic [15:0] mon_anom_window_r;   // ticks per observation window; 0 disables
  logic [31:0] mon_anom_thresh_r;   // {wdt[31:16], recfg[15:0]}
  logic [31:0] mon_anom_status_r;   // throttle [7:0] + spike flags [11:8], R/W1C
  logic [15:0] mon_recfg_cnt_r  [MON_REGIONS];  // saturating deploy counters
  logic [15:0] mon_wdt_cnt_r    [MON_REGIONS];  // saturating watchdog counters
  logic [15:0] mon_recfg_snap_r [MON_REGIONS];  // per-window delta baselines
  logic [15:0] mon_wdt_snap_r   [MON_REGIONS];
  logic [MON_REGIONS-1:0] mon_evt_owed_r;       // code-5 event pending/region
  logic [15:0] mon_evt_stamp_r  [MON_REGIONS];  // stamp latched at flag set
  logic [MON_DIV_W-1:0] mon_div_r;   // monitor clock divider -> one tick
  logic [15:0] mon_tick_cnt_r;       // free-running tick counter (event stamp)
  logic [15:0] mon_win_cnt_r;        // ticks elapsed in the current window

  // v0.6 decode + combinational helper signals (assigned in the sections below)
  logic        mon_notify_w;         // MON_NOTIFY write pulse this cycle
  logic        mon_anom_w1c_w;       // MON_ANOM_STATUS write-1-clears
  logic        addr_is_cap_decl_w;   // CAP_DECL_IO/CAP_DECL_SVC write
  logic        addr_is_efp_cmd_w;    // EFP_CMD doorbell write
  logic        mon_tick_w;           // 1-cycle monitor tick strobe
  logic        mon_win_expire_w;     // tick that completes the window
  logic [31:0] cap_denied_io_off_w;  // cap_decl_io_r & ~ALLOWED_IO_GROUPS
  logic        cap_denied_w;
  logic [7:0]  cap_denied_io_w;
  logic        cap_throttled_w;
  logic [MON_REGIONS-1:0] mon_recfg_spike_w;
  logic [MON_REGIONS-1:0] mon_wdt_spike_w;
  logic [MON_REGIONS-1:0] mon_evt_set_w;     // first flag 0->1 this window
  logic [MON_REGIONS-1:0] mon_evt_sel_w;     // one-hot: region pushed now
  logic                   mon_evt_sel_valid_w;
  logic [7:0]  mon_evt_region_w;
  logic [15:0] mon_evt_stamp_w;

  // ------------------------------------------------------------------
  // Decode helpers
  // ------------------------------------------------------------------
  logic addr_is_occ_cmd_start;
  assign addr_is_occ_cmd_start = host_req_i && host_we_i &&
                                 (host_op_i == SPI_OP_WR) &&
                                 (host_addr_i == R_OCC_CMD) &&
                                 host_wdata_i[OCC_CMD_START];

  logic addr_is_occ_wdata_push;
  assign addr_is_occ_wdata_push = host_req_i && host_we_i &&
                                  ((host_op_i == SPI_OP_OCC_PUSH) ||
                                   ((host_op_i == SPI_OP_WR) && (host_addr_i == R_OCC_WDATA)));

  // ------------------------------------------------------------------
  // OCC command valid: hold while start pending until accepted
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_cmd_r         <= 2'd0;
      occ_region_r      <= 4'd0;
      occ_start_r       <= 1'b0;
    end else begin
      if (addr_is_occ_cmd_start && !occ_start_r) begin
        // Latch a new command only when no outstanding one (host must wait ready)
        occ_cmd_r    <= host_wdata_i[1:0];
        occ_region_r <= host_wdata_i[5:2];
        occ_start_r  <= 1'b1;
      end else if (occ_start_r && occ_cmd_ready_i) begin
        occ_start_r <= 1'b0;  // accepted
      end
    end
  end
  assign occ_cmd_o        = occ_cmd_r;
  assign occ_cmd_valid_o  = occ_start_r;
  assign occ_frame_addr_o = occ_frame_addr_r;
  assign occ_word_count_o = occ_word_count_r;
  assign occ_expect_crc_o = occ_expect_crc_r;
  assign occ_region_locked_o = 1'b0;  // v0 (see Details)

  // ------------------------------------------------------------------
  // OCC wdata staging: a host OCC_PUSH write loads the skid buffer; the
  // buffer drains to OCC honoring wdata_ready. v0 depth = 1 (host must
  // observe ready=BUSY and retry while the skid is full). Backpressure
  // surfaces as host_ready_o held low until occ_wdata_ready_i.
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_wdata_r        <= 32'h0;
      occ_wdata_pending_r<= 1'b0;
    end else begin
      if (occ_wdata_pending_r && occ_wdata_ready_i) begin
        occ_wdata_pending_r <= 1'b0;  // drained
      end
      // A new host load is only accepted when the skid is empty (or draining
      // this same cycle) — gated via host_ready_o below.
      if (addr_is_occ_wdata_push && (!occ_wdata_pending_r || occ_wdata_ready_i)) begin
        occ_wdata_r         <= host_wdata_i;
        occ_wdata_pending_r <= 1'b1;
      end
    end
  end
  assign occ_wdata_o       = occ_wdata_r;
  assign occ_wdata_valid_o = occ_wdata_pending_r;

  // ------------------------------------------------------------------
  // Plain RW registers
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_frame_addr_r <= 16'h0;
      occ_word_count_r <= 16'h0;
      occ_expect_crc_r <= 32'h0;
      region_sel_r     <= 8'h0;
      session_cmd_r    <= 8'h0;
      session_status_r <= 8'h0;
      efp_cmd_r        <= 8'h0;
      efp_region_r     <= 8'h0;
      efp_img_words_r  <= 16'h0;
      efp_status_r     <= 8'h0;
      efp_err_r        <= 8'h0;
      efp_img_cols_r   <= 8'h0;
      cap_decl_io_r    <= 32'h0;
      cap_decl_svc_r   <= 32'h0;
      // v0.6 §3.8: these two carry their SPEC RESET DEFAULTS (unlike the
      // reset-less config registers above): 0x1000 ticks/window and
      // {wdt=0x0008, recfg=0x0010} thresholds (spec §2 offsets 0x35/0x36).
      mon_anom_window_r <= MON_ANOM_WINDOW_DEF;
      mon_anom_thresh_r <= MON_ANOM_THRESH_DEF;
    end else if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR)) begin
      case (host_addr_i)
        R_OCC_FRAME_ADDR: occ_frame_addr_r <= host_wdata_i[15:0];
        R_OCC_WORD_COUNT: occ_word_count_r <= host_wdata_i[15:0];
        R_OCC_EXPECT_CRC: occ_expect_crc_r <= host_wdata_i;
        R_REGION_SEL:     region_sel_r     <= host_wdata_i[7:0];
        R_SESSION_CMD:    session_cmd_r    <= host_wdata_i[7:0];
        R_EFP_CMD:        efp_cmd_r        <= host_wdata_i[7:0];
        R_EFP_REGION:     efp_region_r     <= host_wdata_i[7:0];
        R_EFP_IMG_WORDS:  efp_img_words_r  <= host_wdata_i[15:0];
        R_EFP_STATUS:     efp_status_r     <= host_wdata_i[7:0];
        R_EFP_ERR:        efp_err_r        <= host_wdata_i[7:0];
        R_EFP_IMG_COLS:   efp_img_cols_r   <= host_wdata_i[7:0];
        R_CAP_DECL_IO:    cap_decl_io_r    <= host_wdata_i;
        R_CAP_DECL_SVC:   cap_decl_svc_r   <= host_wdata_i;
        R_MON_ANOM_WINDOW: mon_anom_window_r <= host_wdata_i[15:0];
        R_MON_ANOM_THRESH: mon_anom_thresh_r <= host_wdata_i;
        default: ; // others RO or handled above/below
      endcase
    end
  end

  // IMG_DIGEST / IMG_SIG word storage (one always_ff per word via genvar —
  // G1: no procedural loops inside always_*). Word i holds bytes [4i+3:4i]
  // (little-endian in-word), ascending word order (spec §3.2 byte order).
  genvar gi;
  generate
    for (gi = 0; gi < IMG_DIGEST_WORDS; gi++) begin : g_img_digest
      localparam logic [15:0] WORD_ADDR = R_IMG_DIGEST + 16'(gi);
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          img_digest_r[gi] <= 32'h0;
        end else if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                     (host_addr_i == WORD_ADDR)) begin
          img_digest_r[gi] <= host_wdata_i;
        end
      end
    end
    for (gi = 0; gi < IMG_SIG_WORDS; gi++) begin : g_img_sig
      localparam logic [15:0] WORD_ADDR = R_IMG_SIG + 16'(gi);
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          img_sig_r[gi] <= 32'h0;
        end else if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                     (host_addr_i == WORD_ADDR)) begin
          img_sig_r[gi] <= host_wdata_i;
        end
      end
    end
  endgenerate

  // ------------------------------------------------------------------
  // Event-log ring (v0.4, spec sec 3.4): plain storage + two monotonic
  // 16-bit pointers, no port-role distinction (roles are software: the
  // daemon WRITES R_EVT_LOG_DATA to push, the host READS it to pop and
  // writes R_EVT_LOG_CTRL bit16 to clear).
  //   * push (write R_EVT_LOG_DATA): the written word IS the entry
  //     {code[7:0], region[15:8], stamp[31:16]}; pushing into a FULL ring
  //     overwrites the oldest entry (read pointer auto-advances).
  //   * pop (accepted read of R_EVT_LOG_DATA): returns the OLDEST
  //     un-popped entry and advances the read pointer. An EMPTY ring
  //     reads 0 and does NOT advance (host polling is idempotent).
  //   * clear (write R_EVT_LOG_CTRL with wdata[16]=1): wr=rd=0.
  // count = wr - rd as an unsigned 16-bit difference: the pointers stay
  // within EVT_LOG_DEPTH of each other, so the modular difference is exact
  // even across the 2^16 wrap. Storage index = ptr mod EVT_LOG_DEPTH
  // (ASSUMPTION: EVT_LOG_DEPTH is a power of two — 16 in v0.4).
  // The array carries no reset: entries are only readable while
  // count != 0, i.e. after they were written.
  // ------------------------------------------------------------------
  localparam int EVT_LOG_IDXW = (EVT_LOG_DEPTH > 1) ? $clog2(EVT_LOG_DEPTH) : 1;

  logic [31:0] evt_q [EVT_LOG_DEPTH];
  logic [15:0] evt_wr_ptr_r;
  logic [15:0] evt_rd_ptr_r;
  logic [15:0] evt_count_w;
  assign evt_count_w = evt_wr_ptr_r - evt_rd_ptr_r;

  logic evt_push, evt_pop, evt_clr;
  logic evt_push_host_w;             // bus push (daemon writes R_EVT_LOG_DATA)
  logic evt_push_hw_w;               // monitor code-5 push (v0.6 §3.8)
  logic [31:0] evt_push_data_w;      // winning entry word
  assign evt_push_host_w = host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                           (host_addr_i == R_EVT_LOG_DATA);
  assign evt_pop  = host_req_i && !host_we_i &&
                    (host_addr_i == R_EVT_LOG_DATA) && (evt_count_w != 16'd0);
  assign evt_clr  = host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                    (host_addr_i == R_EVT_LOG_CTRL) &&
                    ((host_wdata_i & EVT_LOG_CLEAR) != 32'h0);
  // ONE push port, two producers (v0.6 §3.8 anomaly events). The bus push has
  // priority — an accepted host write must never be dropped; the monitor event
  // waits for a free cycle (its owed bit clears only on the cycle it is
  // actually pushed), so no entry is lost or mis-ordered. A ring CLEAR wins
  // too (it drops every entry anyway). Monitor-side selector/stamp are in the
  // anomaly-monitor section below; the entry is
  // {code[7:0], region[15:8], stamp[31:16]} (spec §3.4).
  assign evt_push_hw_w   = mon_evt_sel_valid_w && !evt_push_host_w && !evt_clr;
  // Entry byte order per spec §3.4 / the v0.4 TB: [7:0]=code, [15:8]=region,
  // [31:16]=stamp — i.e. {stamp, region, code} MSB-first in Verilog.
  assign evt_push_data_w = evt_push_host_w
                           ? host_wdata_i
                           : {mon_evt_stamp_w, mon_evt_region_w,
                              EVT_CODE_ANOMALY_THROTTLE};
  assign evt_push = evt_push_host_w || evt_push_hw_w;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      evt_wr_ptr_r <= 16'h0;
      evt_rd_ptr_r <= 16'h0;
    end else if (evt_clr) begin
      evt_wr_ptr_r <= 16'h0;
      evt_rd_ptr_r <= 16'h0;
    end else if (evt_push) begin
      evt_q[evt_wr_ptr_r[EVT_LOG_IDXW-1:0]] <= evt_push_data_w;
      evt_wr_ptr_r <= evt_wr_ptr_r + 16'd1;
      if (evt_count_w == 16'(EVT_LOG_DEPTH)) begin
        evt_rd_ptr_r <= evt_rd_ptr_r + 16'd1;  // full: drop the oldest
      end
    end else if (evt_pop) begin
      evt_rd_ptr_r <= evt_rd_ptr_r + 16'd1;
    end
  end
  // ==================================================================
  // v0.6 §3.7 capability-declaration gate
  //   CAP_DECL_IO/CAP_DECL_SVC are plain RW staging (the host stages the
  //   capabilities.yaml bitmap BEFORE the EFP_CMD doorbell, §3.7 step 1).
  //   CAP_STATUS is READ-ONLY and produced here:
  //     [0]     checked   — a declaration was staged this session: latches on
  //                         the first CAP_DECL write, clears on EVERY EFP_CMD
  //                         write (spec §3.7: "the regfile clears CAP_STATUS
  //                         on every EFP_CMD write").
  //     [1]     denied    — LIVE: declared_io ⊄ ALLOWED_IO_GROUPS or
  //                         declared_svc ⊄ ALLOWED_SERVICES. An empty bitmap
  //                         is always a subset, so an empty declaration is
  //                         allowed (spec §3.7 rule 1).
  //     [2]     throttled — LIVE: OR of the §3.8 throttle mask.
  //     [15:8]  denied_io — low 8 bits of the offending group bitmap
  //                         (declared_io & ~ALLOWED_IO_GROUPS).
  // ==================================================================
  assign addr_is_cap_decl_w  = host_req_i && host_we_i &&
                               (host_op_i == SPI_OP_WR) &&
                               ((host_addr_i == R_CAP_DECL_IO) ||
                                (host_addr_i == R_CAP_DECL_SVC));
  assign addr_is_efp_cmd_w   = host_req_i && host_we_i &&
                               (host_op_i == SPI_OP_WR) &&
                               (host_addr_i == R_EFP_CMD);
  assign cap_denied_io_off_w = cap_decl_io_r & ~ALLOWED_IO_GROUPS;
  assign cap_denied_w        = (cap_denied_io_off_w != 32'h0) ||
                               ((cap_decl_svc_r & ~ALLOWED_SERVICES) != 32'h0);
  // NOTE: with the v0 sim inventory (groups/proxies 0..7 -> mask 0xFF) every
  // refused bit lies in [31:8], so denied_io necessarily reads 0 on a refusal;
  // in general it is the low byte of the offending bitmap (a narrower allowed
  // mask makes it non-zero). Host-side twin: capcheck.py SIM_ALLOWED_*_MASK.
  assign cap_denied_io_w = cap_denied_io_off_w[7:0];
  assign cap_throttled_w = |mon_anom_status_r[7:0];  // §3.8 throttle mask

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cap_checked_r <= 1'b0;
    end else if (addr_is_efp_cmd_w) begin
      cap_checked_r <= 1'b0;            // new session: the verdict is cleared
    end else if (addr_is_cap_decl_w) begin
      cap_checked_r <= 1'b1;            // first declaration of this session
    end
  end

  // ==================================================================
  // v0.6 §3.8 anomaly monitoring v1
  //   One monitor tick = EMRI_MON_TICK_DIV (4096) clocks (fixed divider).
  //   MON_NOTIFY write: bit r increments MON_RECFG_COUNT region r, bit 8+r
  //   increments MON_WDT_COUNT region r (both saturate at 0xFFFF per region).
  //   On window expiry: delta = counter − snapshot; delta_recfg > thr_recfg
  //   sets flag 8+r, delta_wdt > thr_wdt sets flag 10+r; a set flag also sets
  //   throttle bit r; snapshot ← counter. The first flag 0->1 for a region in
  //   a window pushes event code 5 (anomaly_throttle) into the §3.4 ring.
  //   MON_ANOM_WINDOW = 0 disables the monitor: no flag is ever set, the
  //   counters still count.
  // ==================================================================
  assign mon_notify_w   = host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                          (host_addr_i == R_MON_NOTIFY);
  assign mon_anom_w1c_w = host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                          (host_addr_i == R_MON_ANOM_STATUS);

  // ---- monitor tick divider + observation-window counter ----
  // A MON_ANOM_WINDOW write takes effect on the in-flight window (the counter
  // is not restarted): 0 freezes the counter and disables all flag setting, a
  // non-zero length is compared from the next tick on.
  assign mon_tick_w       = (mon_div_r == MON_DIV_W'(EMRI_MON_TICK_DIV - 1));
  assign mon_win_expire_w = mon_tick_w && (mon_anom_window_r != 16'h0) &&
                            ((mon_win_cnt_r + 16'd1) >= mon_anom_window_r);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mon_div_r      <= '0;
      mon_tick_cnt_r <= 16'h0;
      mon_win_cnt_r  <= 16'h0;
    end else if (mon_tick_w) begin
      mon_div_r      <= '0;
      mon_tick_cnt_r <= mon_tick_cnt_r + 16'd1;   // free-running (wraps)
      if (mon_anom_window_r == 16'h0) begin
        mon_win_cnt_r <= 16'h0;                   // monitor disabled
      end else begin
        mon_win_cnt_r <= mon_win_expire_w ? 16'h0 : (mon_win_cnt_r + 16'd1);
      end
    end else begin
      mon_div_r <= mon_div_r + MON_DIV_W'(1);
    end
  end

  // ---- per-region counters (saturating), window baselines, spike detect ----
  // MON_NOTIFY bits [7:2]/[15:10] address regions the 2-region v0 fabric does
  // not have; they are ignored (the notify layout permits 8 regions, the count
  // and flag registers only define 2 — spec §2/§3.8).
  genvar gm;
  generate
    for (gm = 0; gm < MON_REGIONS; gm++) begin : g_mon_region
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          mon_recfg_cnt_r[gm] <= 16'h0;
          mon_wdt_cnt_r[gm]   <= 16'h0;
        end else begin
          if (mon_notify_w && host_wdata_i[gm] &&
              (mon_recfg_cnt_r[gm] != 16'hFFFF)) begin
            mon_recfg_cnt_r[gm] <= mon_recfg_cnt_r[gm] + 16'd1;
          end
          if (mon_notify_w && host_wdata_i[8 + gm] &&
              (mon_wdt_cnt_r[gm] != 16'hFFFF)) begin
            mon_wdt_cnt_r[gm] <= mon_wdt_cnt_r[gm] + 16'd1;
          end
        end
      end

      // Window baseline. While the monitor is disabled the baseline tracks the
      // counter, so re-enabling the window never fires on a stale accumulation.
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          mon_recfg_snap_r[gm] <= 16'h0;
          mon_wdt_snap_r[gm]   <= 16'h0;
        end else if (mon_win_expire_w || (mon_anom_window_r == 16'h0)) begin
          mon_recfg_snap_r[gm] <= mon_recfg_cnt_r[gm];
          mon_wdt_snap_r[gm]   <= mon_wdt_cnt_r[gm];
        end
      end

      // delta = counter − snapshot. The counters are monotonic non-decreasing
      // (saturating at 0xFFFF), so the unsigned difference never wraps; once a
      // counter saturates its delta simply stops growing.
      assign mon_recfg_spike_w[gm] = mon_win_expire_w &&
          ((mon_recfg_cnt_r[gm] - mon_recfg_snap_r[gm]) > mon_anom_thresh_r[15:0]);
      assign mon_wdt_spike_w[gm]   = mon_win_expire_w &&
          ((mon_wdt_cnt_r[gm] - mon_wdt_snap_r[gm]) > mon_anom_thresh_r[31:16]);
    end
  endgenerate

  // ---- MON_ANOM_STATUS: R/W1C throttle mask [7:0] + spike flags [11:8] ----
  // One storage word: a host write clears the 1-bits it writes (W1C — the
  // §3.8 host-initiated release); a spike sets its flag AND its region's
  // throttle bit. A spike concurrent with a W1C wins: a fresh anomaly must not
  // be dismissible by a stale clear. Bits [7:2] (no region in the 2-region
  // fabric) and [31:12] are never set and stay 0.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mon_anom_status_r <= 32'h0;
    end else begin
      if (mon_anom_w1c_w) begin
        mon_anom_status_r <= mon_anom_status_r & ~host_wdata_i;
      end
      if (mon_recfg_spike_w[0]) begin
        mon_anom_status_r[8] <= 1'b1;   // reconfig-rate spike, region 0
        mon_anom_status_r[0] <= 1'b1;   // throttle region 0
      end
      if (mon_recfg_spike_w[1]) begin
        mon_anom_status_r[9] <= 1'b1;   // reconfig-rate spike, region 1
        mon_anom_status_r[1] <= 1'b1;   // throttle region 1
      end
      if (mon_wdt_spike_w[0]) begin
        mon_anom_status_r[10] <= 1'b1;  // watchdog-rate spike, region 0
        mon_anom_status_r[0]  <= 1'b1;
      end
      if (mon_wdt_spike_w[1]) begin
        mon_anom_status_r[11] <= 1'b1;  // watchdog-rate spike, region 1
        mon_anom_status_r[1]  <= 1'b1;
      end
    end
  end

  // ---- code-5 event handshake to the §3.4 ring (push arbiter above) ----
  // "First flag 0->1 for a region in a window": a spike whose flag bit is not
  // already set owes exactly one event; a region that stays flagged across
  // windows does not re-push. The owed bit is sticky until the ring actually
  // pushes it (the bus push has priority), and the tick stamp is latched at
  // flag-set time (spec §3.4: producer-supplied 16-bit tick, no RTC in v0).
  genvar ge;
  generate
    for (ge = 0; ge < MON_REGIONS; ge++) begin : g_mon_evt
      assign mon_evt_set_w[ge] = mon_win_expire_w &&
          ((mon_recfg_spike_w[ge] && !mon_anom_status_r[8 + ge]) ||
           (mon_wdt_spike_w[ge]   && !mon_anom_status_r[10 + ge]));

      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          mon_evt_owed_r[ge]  <= 1'b0;
          mon_evt_stamp_r[ge] <= 16'h0;
        end else if (mon_evt_set_w[ge]) begin
          mon_evt_owed_r[ge]  <= 1'b1;      // a new event supersedes a push
          mon_evt_stamp_r[ge] <= mon_tick_cnt_r;
        end else if (evt_push_hw_w && mon_evt_sel_w[ge]) begin
          mon_evt_owed_r[ge] <= 1'b0;       // pushed this cycle
        end
      end
    end
  endgenerate

  // Lowest-index owed region is pushed first (both regions can owe an event in
  // the same window-expiry cycle; each then gets its own push cycle).
  always_comb begin
    mon_evt_sel_w       = {MON_REGIONS{1'b0}};
    mon_evt_sel_valid_w = 1'b1;
    unique casez (mon_evt_owed_r)
      2'b?1:   mon_evt_sel_w = 2'b01;   // region 0 owed (lowest index wins)
      2'b10:   mon_evt_sel_w = 2'b10;   // region 1 owed
      default: mon_evt_sel_valid_w = 1'b0;
    endcase
  end
  assign mon_evt_region_w = mon_evt_sel_w[0] ? 8'd0 : 8'd1;
  assign mon_evt_stamp_w  = mon_evt_sel_w[0] ? mon_evt_stamp_r[0]
                                             : mon_evt_stamp_r[1];

  // ------------------------------------------------------------------
  // OCC_DECODE start trigger (v0.1, spec §3.1): a write to R_OCC_DECODE
  // latches col_id and pulses dec_start_o for ONE fabric-clock cycle
  // (-> frame_decoder.start_i), making a packed deploy self-contained over
  // the register ABI (no host/TB sideband strobe).
  //   SELF-TIMING BACKPRESSURE: the write is held (host_ready_o low) while the
  // decoder is BUSY (dec_busy_i), and the start pulse fires only when the
  // write is ACCEPTED (decoder idle). This makes back-to-back deploys
  // (BLANK then WRITE) self-sequencing: the BMC's next R_OCC_DECODE write
  // stalls until the previous decode completes, so its start_i is never
  // dropped (the decoder ignores start_i while busy). Reads as 0.
  // ------------------------------------------------------------------
  logic       dec_start_r;
  logic [7:0] dec_col_r;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dec_start_r <= 1'b0;
      dec_col_r   <= 8'h0;
    end else begin
      dec_start_r <= 1'b0;  // default: single-cycle pulse
      if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
          (host_addr_i == R_OCC_DECODE) && !dec_busy_i && !dec_start_r) begin
        dec_start_r <= 1'b1;
        dec_col_r   <= host_wdata_i[7:0];
      end
    end
  end
  assign dec_start_o = dec_start_r;
  assign dec_col_o   = dec_col_r;

  // ------------------------------------------------------------------
  // REGION_INFO read (windowed by region_sel_r)
  // ------------------------------------------------------------------
  logic [31:0] region_info_w;
  always_comb begin
    region_info_w = 32'h0;
    case (region_sel_r)
      8'd0: region_info_w = REGION0_INFO;
      8'd1: region_info_w = REGION1_INFO;
      default: region_info_w = 32'h0;
    endcase
  end

  // ------------------------------------------------------------------
  // OCC sticky completion (HOST-POLLABLE). occ_top emits S_DONE/S_ERROR/
  // S_NEEDS_BLANK/S_LOCKED for exactly ONE cycle — unobservable by a host
  // that polls over SPI (ms-scale). The regfile latches the completion into
  // sticky bits cleared on the next OCC_CMD.start write, so ethctl can poll.
  //   occ_done_flag_r : 1 = a completion occurred since the last cmd start
  //   occ_done_code_r : 0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED (valid when flag=1)
  // Exposed in OCC_STATUS[3] (flag) and [5:4] (code) — spec §4 reserved bits.
  // ------------------------------------------------------------------
  logic        occ_done_flag_r;
  logic [1:0]  occ_done_code_r;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_done_flag_r <= 1'b0;
      occ_done_code_r <= 2'd0;
    end else begin
      // a new command start clears any prior completion (fresh cycle)
      if (addr_is_occ_cmd_start && !occ_start_r) begin
        occ_done_flag_r <= 1'b0;
        occ_done_code_r <= 2'd0;
      end else begin
        unique case (occ_status_i)
          OCC_S_DONE:        begin occ_done_flag_r <= 1'b1; occ_done_code_r <= 2'd0; end
          OCC_S_ERROR:       begin occ_done_flag_r <= 1'b1; occ_done_code_r <= 2'd1; end
          OCC_S_NEEDS_BLANK: begin occ_done_flag_r <= 1'b1; occ_done_code_r <= 2'd2; end
          OCC_S_LOCKED:      begin occ_done_flag_r <= 1'b1; occ_done_code_r <= 2'd3; end
          default: ; // IDLE/BUSY: hold
        endcase
      end
    end
  end

  // ------------------------------------------------------------------
  // OCC_STATUS read assembly (spec §4):
  //   [2:0]  live occ_status_i (IDLE/BUSY/DONE-pulse/...)
  //   [3]    occ_done_flag_r   (sticky completion pending — host polls THIS)
  //   [5:4]  occ_done_code_r   (0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED)
  //   [11:8] region_id (v0: 0)
  //   [16]   occ_crc_error_i (sticky from occ_top)
  //   [31:17] frame_addr echo
  // ------------------------------------------------------------------
  logic [31:0] occ_status_w;
  always_comb begin
    occ_status_w = 32'h0;
    occ_status_w[2:0]  = occ_status_i;
    occ_status_w[3]    = occ_done_flag_r;
    occ_status_w[5:4]  = occ_done_code_r;
    occ_status_w[11:8] = 4'h0;
    occ_status_w[16]   = occ_crc_error_i;
    occ_status_w[31:17]= occ_frame_addr_r[14:0];
  end

  // ------------------------------------------------------------------
  // Read mux (combinational, with default)
  // ------------------------------------------------------------------
  always_comb begin
    host_rdata_o = 32'h0;  // default
    case (host_addr_i)
      R_MAGIC:          host_rdata_o = EMRI_MAGIC;
      R_ABI_VERSION:    host_rdata_o = EMRI_ABI_VERSION;
      R_CAPABILITIES:   host_rdata_o = capabilities_w;
      R_PLATFORM_ID:    host_rdata_o = PLATFORM_ID;
      R_NUM_REGIONS:    host_rdata_o = {24'h0, NUM_REGIONS[7:0]};
      R_REGION_INFO:    host_rdata_o = region_info_w;
      R_OCC_CMD:        host_rdata_o = {23'h0, occ_start_r, 2'h0, occ_region_r, occ_cmd_r};
      R_OCC_WDATA:      host_rdata_o = 32'h0;          // write-only
      R_OCC_STATUS:     host_rdata_o = occ_status_w;
      R_OCC_FRAME_ADDR: host_rdata_o = {16'h0, occ_frame_addr_r};
      R_OCC_WORD_COUNT: host_rdata_o = {16'h0, occ_word_count_r};
      R_OCC_EXPECT_CRC: host_rdata_o = occ_expect_crc_r;
      R_OCC_CRC_RESULT: host_rdata_o = occ_crc_result_i;
      R_SESSION_CMD:    host_rdata_o = {24'h0, session_cmd_r};
      R_SESSION_STATUS: host_rdata_o = {24'h0, session_status_r};
      R_RX_BUF_CTRL:    host_rdata_o = {16'h0, rx_buf_depth_w};
      R_EFP_CMD:        host_rdata_o = {24'h0, efp_cmd_r};
      R_EFP_REGION:     host_rdata_o = {24'h0, efp_region_r};
      R_EFP_IMG_WORDS:  host_rdata_o = {16'h0, efp_img_words_r};
      R_EFP_STATUS:     host_rdata_o = {24'h0, efp_status_r};
      R_EFP_ERR:        host_rdata_o = {24'h0, efp_err_r};
      R_EFP_IMG_COLS:   host_rdata_o = {24'h0, efp_img_cols_r};
      R_EVT_LOG_CTRL:   host_rdata_o = {evt_wr_ptr_r, evt_count_w};
      R_EVT_LOG_DATA:   host_rdata_o = (evt_count_w != 16'd0)
                                      ? evt_q[evt_rd_ptr_r[EVT_LOG_IDXW-1:0]]
                                      : 32'h0;
      R_HEALTH_STATUS:  host_rdata_o = health_status_w;
      R_MON_TEMP:       host_rdata_o = {16'h0, MON_TEMP_SIM};
      R_MON_VCCINT:     host_rdata_o = {16'h0, MON_VCCINT_SIM};
      // ---- v0.6 §3.7 capability-declaration gate ----
      R_CAP_DECL_IO:    host_rdata_o = cap_decl_io_r;
      R_CAP_DECL_SVC:   host_rdata_o = cap_decl_svc_r;
      R_CAP_STATUS:     host_rdata_o = {16'h0, cap_denied_io_w, 5'h0,
                                        cap_throttled_w, cap_denied_w,
                                        cap_checked_r};
      // ---- v0.6 §3.8 anomaly monitoring v1 ----
      R_MON_RECFG_COUNT: host_rdata_o = {mon_recfg_cnt_r[1], mon_recfg_cnt_r[0]};
      R_MON_WDT_COUNT:   host_rdata_o = {mon_wdt_cnt_r[1], mon_wdt_cnt_r[0]};
      R_MON_ANOM_STATUS: host_rdata_o = mon_anom_status_r;
      R_MON_ANOM_WINDOW: host_rdata_o = {16'h0, mon_anom_window_r};
      R_MON_ANOM_THRESH: host_rdata_o = mon_anom_thresh_r;
      R_MON_NOTIFY:      host_rdata_o = 32'h0;  // write-only (spec §3.8)
      default: begin
        // IMG_DIGEST (0x18-0x1F) / IMG_SIG (0x50-0x5F) word windows; every other
        // offset is reserved and reads as 0 (v0.6 map: 0x07, 0x25-0x2F,
        // 0x3A-0x3E, 0x3F = SPI_CRC front-end intercept, 0x60+ — spec §2).
        if ((host_addr_i >= R_IMG_DIGEST) &&
            (host_addr_i < (R_IMG_DIGEST + 16'(IMG_DIGEST_WORDS)))) begin
          host_rdata_o = img_digest_r[3'(host_addr_i - R_IMG_DIGEST)];
        end else if ((host_addr_i >= R_IMG_SIG) &&
                     (host_addr_i < (R_IMG_SIG + 16'(IMG_SIG_WORDS)))) begin
          host_rdata_o = img_sig_r[4'(host_addr_i - R_IMG_SIG)];
        end else begin
          host_rdata_o = 32'h0;  // reserved read-as-0
        end
      end
    endcase
  end

  // ------------------------------------------------------------------
  // host_ready_o: when is the host request accepted this cycle?
  //   * Read: always ready (combinational rdata).
  //   * Write to RO/reserved: ready (accepted, ignored).
  //   * Write OCC_CMD.start: ready when occ_cmd accepted (occ_cmd_ready_i while
  //     start pending) — multi-cycle stall possible.
  //   * OCC_WDATA push: ready when skid can accept (empty or draining).
  //   * Other writes: ready immediately.
  // ------------------------------------------------------------------
  always_comb begin
    host_ready_o = 1'b0;
    if (!host_req_i) begin
      host_ready_o = 1'b0;
    end else if (!host_we_i) begin
      // Read or BLOCK_RD (BLOCK_RD unsupported -> BAD_OP path handled at SPI layer;
      // here a read returns data). Always ready.
      host_ready_o = 1'b1;
    end else begin
      // Write
      if (addr_is_occ_cmd_start) begin
        // Ready when the latched command is accepted by OCC.
        host_ready_o = occ_start_r && occ_cmd_ready_i;
      end else if (addr_is_occ_wdata_push) begin
        host_ready_o = !occ_wdata_pending_r || occ_wdata_ready_i;
      end else if (host_addr_i == R_OCC_DECODE) begin
        // DECODE trigger: ready only when the frame_decoder is idle AND no
        // start pulse is already in flight. The decoder ignores start_i while
        // busy, and dec_busy_i only rises one cycle AFTER dec_start_o (when
        // the decoder enters STREAM), so without the !dec_start_r term a
        // second trigger in the dec_start pulse window would be silently
        // dropped. Gating on both makes multi-command deploys airtight.
        host_ready_o = !dec_busy_i && !dec_start_r;
      end else begin
        host_ready_o = 1'b1;  // plain RW / RO-write: immediate
      end
    end
  end

`ifdef FORMAL
    // ==================================================================
    // Formal properties (SymbiYosys, see formal/emri_r_occ_decode.sby).
    // Prove the R_OCC_DECODE sequencing contract (regression guard for the
    // 2026-08-30 dec_start-dropped-when-busy fix + the dec_start-pulse-window
    // hardening): the start pulse fires ONLY on an accepted write while the
    // decoder is IDLE and no pulse is in flight, the write is back-pressured
    // (host_ready = !dec_busy_i && !dec_start_r), the pulse is single-cycle,
    // and the column id is latched.
    // ==================================================================
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;

    // Initialize deterministically: hold reset for the first cycle.
    always_ff @(posedge clk_i) begin
        if (!past_valid) assume(!rst_ni);
    end

    // ---- Assumptions on the environment (host driver + frame_decoder) --------
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // The host driver (emri_axi_adapter) holds a request + payload
            // stable until it is accepted (host_ready_o high).
            if ($past(host_req_i) && !$past(host_ready_o)) begin
                assume(host_req_i);
                assume(host_we_i    == $past(host_we_i));
                assume(host_op_i    == $past(host_op_i));
                assume(host_addr_i  == $past(host_addr_i));
                assume(host_wdata_i == $past(host_wdata_i));
            end
            // dec_busy_i is a free input (the decoder may be busy or idle).
        end
    end

    // ---- Assertions on the dec_start logic ------------------------------------
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // prop 1 (REGRESSION GUARD): dec_start_o is only generated when
            // the decoder was IDLE at acceptance time ($past) — a trigger can
            // never be issued-then-ignored. (dec_busy_i at the pulse cycle is
            // the decoder's RESPONSE to the trigger, external to this module,
            // so the provable form is the acceptance-time condition.)
            if (dec_start_o) assert($past(!dec_busy_i));

            // prop 2: the R_OCC_DECODE write is back-pressured by decoder busy
            // OR an in-flight start pulse (airtight self-sequencing).
            if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR) &&
                (host_addr_i == R_OCC_DECODE))
                assert(host_ready_o == (!dec_busy_i && !dec_start_r));

            // prop 3: dec_start_o is a single-cycle pulse.
            if ($past(dec_start_o)) assert(!dec_start_o);

            // prop 4: the column id is latched from the accepted write.
            if (dec_start_o) assert(dec_col_o == $past(host_wdata_i[7:0]));
        end
    end
`endif

endmodule
