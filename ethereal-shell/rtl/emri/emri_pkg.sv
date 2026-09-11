`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      emri_pkg (package)
// Description: EMRI (Ethereal Management Register Interface) constants & encodings.
// Details:     Single source of truth for the EMRI register map (v0), the EFP-SPI
//              operation opcodes, and the OCC status encoding mirror. Must stay in
//              sync with ethereal-spec/control/emri-v0.md (spec-first rule).
// Modified:    2026-09-11 - v0.6: capability-gate (§3.7) + anomaly-monitor (§3.8)
//              offsets, sim allowed masks, monitor tick divider, event codes 4/5.
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3/§4/§7 (§3.7/§3.8 v0.6)
// Notes:       v0 scope: minimum for the sim-complete minimal loop (mFSM → OCC).
package emri_pkg;

  // ------------------------------------------------------------------
  // Magic / ABI
  // ------------------------------------------------------------------
  localparam logic [31:0] EMRI_MAGIC       = 32'h45544852;  // "ETHR"
  localparam logic [31:0] EMRI_ABI_VERSION = 32'h0000_0000;  // v0

  // ------------------------------------------------------------------
  // Register word-offsets (spec §2). Word-addressed.
  // ------------------------------------------------------------------
  localparam logic [15:0] R_MAGIC          = 16'h00;
  localparam logic [15:0] R_ABI_VERSION    = 16'h01;
  localparam logic [15:0] R_CAPABILITIES   = 16'h02;
  localparam logic [15:0] R_PLATFORM_ID    = 16'h03;
  localparam logic [15:0] R_NUM_REGIONS    = 16'h04;
  localparam logic [15:0] R_REGION_SEL     = 16'h06;  // write: region index for REGION_INFO
  localparam logic [15:0] R_REGION_INFO    = 16'h05;  // read: geometry of REGION_SEL
  localparam logic [15:0] R_OCC_CMD        = 16'h08;
  localparam logic [15:0] R_OCC_WDATA      = 16'h09;
  localparam logic [15:0] R_OCC_STATUS     = 16'h0A;
  localparam logic [15:0] R_OCC_FRAME_ADDR = 16'h0B;
  localparam logic [15:0] R_OCC_WORD_COUNT = 16'h0C;
  // R_OCC_DECODE @ 0x0D — hardware DECODE trigger: a write pulses dec_start_o
  // (-> frame_decoder.start_i) so a packed deploy is self-contained over the
  // register ABI (no host/TB sideband strobe). v0.1 (emri-v0.md §3.1).
  localparam logic [15:0] R_OCC_DECODE     = 16'h0D;
  // v0.5 §3.1.1: READBACK compares its stream CRC against OCC_EXPECT_CRC
  // (latched by occ_top at command accept); OCC_CRC_RESULT exposes the
  // running/streaming CRC (after WRITE/BLANK = that stream's final CRC).
  localparam logic [15:0] R_OCC_EXPECT_CRC = 16'h0E;
  localparam logic [15:0] R_OCC_CRC_RESULT = 16'h0F;
  localparam logic [15:0] R_SESSION_CMD    = 16'h10;
  localparam logic [15:0] R_SESSION_STATUS = 16'h11;
  localparam logic [15:0] R_RX_BUF_CTRL    = 16'h12;
  localparam logic [15:0] R_HEALTH_STATUS  = 16'h20;
  localparam logic [15:0] R_MON_TEMP       = 16'h30;
  localparam logic [15:0] R_MON_VCCINT     = 16'h31;
  // v0.6 §3.7 capability-declaration gate. The host stages a compact bitmap
  // from capabilities.yaml before the EFP_CMD doorbell; the regfile exposes it
  // + the hardware verdict (CAP_STATUS). ALLOWED_* are the v0 sim platform
  // inventory ("declared ⊆ grantable"): pin groups 0..7 / EBI proxy indices
  // 0..7 — mirrored by the daemon/BMC (ethereal-runtime/security/capcheck.py
  // SIM_ALLOWED_*_MASK) and replaced by the Board Manifest pin table in
  // E1-IO3/E2-IO1.
  // ASSUMPTION: sim allowed-mask stands in for the Board Manifest + proxy
  // inventory (TBD, 2026-09-11; spec §3.7 v0 sim scope).
  localparam logic [15:0] R_CAP_DECL_IO    = 16'h22;
  localparam logic [15:0] R_CAP_DECL_SVC   = 16'h23;
  localparam logic [15:0] R_CAP_STATUS     = 16'h24;
  localparam logic [31:0] ALLOWED_IO_GROUPS = 32'h0000_00FF;  // groups 0..7
  localparam logic [31:0] ALLOWED_SERVICES  = 32'h0000_00FF;  // proxies 0..7

  // v0.6 §3.8 anomaly monitoring v1: real-time per-region counters + per-window
  // spike thresholds in the regfile (1 monitor tick = EMRI_MON_TICK_DIV
  // clocks). MON_ANOM_WINDOW/MON_ANOM_THRESH reset to the spec defaults
  // (0x1000 / 0x0008_0010) — see emri_regfile.
  localparam logic [15:0] R_MON_RECFG_COUNT = 16'h32;
  localparam logic [15:0] R_MON_WDT_COUNT   = 16'h33;
  localparam logic [15:0] R_MON_ANOM_STATUS = 16'h34;
  localparam logic [15:0] R_MON_ANOM_WINDOW = 16'h35;
  localparam logic [15:0] R_MON_ANOM_THRESH = 16'h36;
  localparam logic [15:0] R_MON_NOTIFY      = 16'h37;
  localparam int          EMRI_MON_TICK_DIV = 4096;  // clocks per monitor tick
  // ASSUMPTION: window length/thresholds TBD at bring-up (TBD, 2026-09-11).
  localparam logic [15:0] EMRI_MON_ANOM_WINDOW_DEF = 16'h1000;
  localparam logic [31:0] EMRI_MON_ANOM_THRESH_DEF = 32'h0008_0010;  // {wdt,recfg}
  // Event-log ring (v0.4, spec §3.4): 16-entry ring in the regfile; daemon
  // writes entries via R_EVT_LOG_DATA (push), host reads them back (pop-
  // oldest) and clears via R_EVT_LOG_CTRL write-1-to-bit16.
  localparam logic [15:0] R_EVT_LOG_CTRL   = 16'h38;
  localparam logic [15:0] R_EVT_LOG_DATA   = 16'h39;
  localparam int          EVT_LOG_DEPTH    = 16;      // ring capacity (entries)
  localparam logic [31:0] EVT_LOG_CLEAR    = 32'h0001_0000;  // W1C bit16

  // ------------------------------------------------------------------
  // EFP command block (spec §3.2, v0.2) — host<->BMC-daemon mailbox.
  // All plain RW storage in the regfile (no port-role distinction); the
  // doorbell/clear convention is software (the daemon clears EFP_CMD on
  // accept). IMG_DIGEST[0..7] occupy 0x18-0x1F, IMG_SIG[0..15] 0x50-0x5F.
  // ------------------------------------------------------------------
  localparam logic [15:0] R_EFP_CMD        = 16'h13;  // daemon doorbell
  localparam logic [15:0] R_EFP_REGION     = 16'h14;  // 0xFF = auto-alloc
  localparam logic [15:0] R_EFP_IMG_WORDS  = 16'h15;
  localparam logic [15:0] R_EFP_STATUS     = 16'h16;  // {state[3:0],busy,done}
  localparam logic [15:0] R_EFP_ERR        = 16'h17;  // sticky last-error
  localparam logic [15:0] R_IMG_DIGEST     = 16'h18;  // base; +0..7
  // R_EFP_IMG_COLS @ 0x21 — fabric-column count of a run_packed image
  // (v0.3, emri-v0.md §3.3). Plain RW storage like the other EFP regs.
  localparam logic [15:0] R_EFP_IMG_COLS   = 16'h21;
  localparam logic [15:0] R_IMG_SIG        = 16'h50;  // base; +0..15
  localparam int          IMG_DIGEST_WORDS = 8;       // 32 B manifest digest
  localparam int          IMG_SIG_WORDS    = 16;      // 64 B Ed25519 sig

  // ------------------------------------------------------------------
  // CAPABILITIES bits (spec §2)
  // ------------------------------------------------------------------
  // The following capability-bit + opcode/status constants are the spec ABI
  // source of truth (ethereal-spec/control/emri-v0.md). The v0 regfile only
  // consumes a subset (CAPB_HAS_BMC, OCC_CMD_START, SPI_OP_WR/OCC_PUSH); the
  // rest are picked up by the SPI slave, mFSM session FSM, host driver, and
  // testbenches built in the next increments. They are kept here (single
  // definition) under a documented UNUSEDPARAM waiver rather than scattered.
  /* verilator lint_off UNUSEDPARAM */
  localparam int CAPB_HAS_BMC      = 0;  // used by emri_regfile
  localparam int CAPB_HAS_DMA      = 1;
  localparam int CAPB_HAS_I2C_MON  = 2;
  localparam int CAPB_HAS_TRNG     = 3;
  localparam int CAPB_HAS_JTAG_DBG = 4;

  // ------------------------------------------------------------------
  // OCC_CMD bitfield (spec §3)
  // ------------------------------------------------------------------
  localparam int OCC_CMD_CMD_W   = 2;   // [1:0]
  localparam int OCC_CMD_REG_W   = 4;   // [5:2]
  localparam int OCC_CMD_START   = 8;   // [8]   (used by emri_regfile)

  // OCC opcodes (must match occ_top)
  localparam logic [1:0] OCC_NOP      = 2'd0;
  localparam logic [1:0] OCC_WRITE    = 2'd1;
  localparam logic [1:0] OCC_READBACK = 2'd2;
  localparam logic [1:0] OCC_BLANK    = 2'd3;

  // OCC status encoding (must match occ_top status_o)
  localparam logic [2:0] OCC_S_IDLE         = 3'd0;
  localparam logic [2:0] OCC_S_BUSY         = 3'd1;
  localparam logic [2:0] OCC_S_DONE         = 3'd2;
  localparam logic [2:0] OCC_S_ERROR        = 3'd3;
  localparam logic [2:0] OCC_S_LOCKED       = 3'd4;
  localparam logic [2:0] OCC_S_NEEDS_BLANK  = 3'd5;

  // ------------------------------------------------------------------
  // EFP-SPI operation opcodes (spec §7)
  // ------------------------------------------------------------------
  localparam logic [1:0] SPI_OP_RD        = 2'd0;
  localparam logic [1:0] SPI_OP_WR        = 2'd1;  // used by emri_regfile
  localparam logic [1:0] SPI_OP_BLOCK_RD  = 2'd2;
  localparam logic [1:0] SPI_OP_OCC_PUSH  = 2'd3;  // used by emri_regfile

  // EFP-SPI response status bytes (spec §7)
  localparam logic [7:0] SPI_STAT_OK      = 8'h00;
  localparam logic [7:0] SPI_STAT_BAD_OP  = 8'h01;
  localparam logic [7:0] SPI_STAT_BAD_ADDR= 8'h02;
  localparam logic [7:0] SPI_STAT_BUSY    = 8'h03;
  localparam logic [7:0] SPI_STAT_CRC_ERR = 8'h04;  // §7.1 transport CRC16 mismatch
  localparam logic [7:0] SPI_STAT_NOT_READY = 8'hFF;  // wire fill "retry" (§7.1)

  // SPI_CRC latch offset (spec §7.1, v0.3): intercepted by the SPI front-end
  // (no regfile storage word; 0x3F stays reserved in the regfile itself).
  localparam logic [15:0] R_SPI_CRC       = 16'h3F;

  // ------------------------------------------------------------------
  // EFP doorbell command codes (spec §3.2; EFP_CMD[7:0])
  // ------------------------------------------------------------------
  localparam logic [7:0] EFP_CMD_NOP     = 8'd0;
  localparam logic [7:0] EFP_CMD_RUN     = 8'd1;
  localparam logic [7:0] EFP_CMD_STOP    = 8'd2;
  localparam logic [7:0] EFP_CMD_RESTART = 8'd3;
  localparam logic [7:0] EFP_CMD_ABORT   = 8'd4;
  localparam logic [7:0] EFP_CMD_RUN_PACKED = 8'd5;  // v0.3 bit-packed deploy (§3.3)
  localparam logic [7:0] EFP_CMD_FWUPDATE = 8'd6;   // v0.4 §3.6 SIM-DEMO (E1-BMC2)
  localparam logic [7:0] EFP_CMD_REBOOT   = 8'd7;   // v0.4 §3.6 SIM-DEMO (E1-BMC2)
  localparam logic [7:0] EFP_REGION_AUTO = 8'hFF;  // auto first-free (run only)

  // EFP daemon lifecycle states (spec §3.2; EFP_STATUS.state[3:0])
  localparam logic [3:0] EFP_S_IDLE     = 4'd0;
  localparam logic [3:0] EFP_S_VERIFY   = 4'd1;
  localparam logic [3:0] EFP_S_ALLOC    = 4'd2;
  localparam logic [3:0] EFP_S_BLANK    = 4'd3;
  localparam logic [3:0] EFP_S_LOAD     = 4'd4;
  localparam logic [3:0] EFP_S_READBACK = 4'd5;
  localparam logic [3:0] EFP_S_RUNNING  = 4'd6;
  localparam logic [3:0] EFP_S_ERROR    = 4'd7;
  localparam logic [3:0] EFP_S_STOPPED  = 4'd8;

  // EFP sticky error codes (spec §3.2; EFP_ERR[7:0])
  localparam logic [7:0] EFP_ERR_NONE             = 8'd0;
  localparam logic [7:0] EFP_ERR_BAD_SIG          = 8'd1;
  localparam logic [7:0] EFP_ERR_REGION_FULL      = 8'd2;
  localparam logic [7:0] EFP_ERR_REGION_LOCKED    = 8'd3;
  localparam logic [7:0] EFP_ERR_OCC_CRC          = 8'd4;
  localparam logic [7:0] EFP_ERR_OCC_REJECT       = 8'd5;
  localparam logic [7:0] EFP_ERR_BAD_CMD          = 8'd6;
  localparam logic [7:0] EFP_ERR_IMG_LEN_MISMATCH = 8'd7;
  localparam logic [7:0] EFP_ERR_CRC_TRANSPORT    = 8'd8;  // §7.1 SPI CRC16 gate
  localparam logic [7:0] EFP_ERR_WATCHDOG_TIMEOUT = 8'd9;   // v0.4 §3.5 OCC op watchdog
  localparam logic [7:0] EFP_ERR_FWUPDATE         = 8'd10;  // v0.4 §3.6 sim-demo CRC mismatch
  localparam logic [7:0] EFP_ERR_CAPABILITY_DENIED = 8'd11;  // v0.6 §3.7 declared ⊄ grantable
  localparam logic [7:0] EFP_ERR_RATE_LIMITED      = 8'd12;  // v0.6 §3.8 region throttled

  // ------------------------------------------------------------------
  // Event-log ring entry codes (v0.4, spec §3.4; entry {code[7:0],
  // region[15:8], stamp[31:16]}). Producers: daemon (codes 1-2),
  // fwupdate demo firmware (code 3).
  // ------------------------------------------------------------------
  localparam logic [7:0] EVT_CODE_WATCHDOG_TIMEOUT = 8'd1;
  localparam logic [7:0] EVT_CODE_HB_MISMATCH      = 8'd2;
  localparam logic [7:0] EVT_CODE_SLOT_CHANGE      = 8'd3;
  localparam logic [7:0] EVT_CODE_POLICY_DENIED    = 8'd4;  // v0.6 §3.7 (daemon-pushed)
  localparam logic [7:0] EVT_CODE_ANOMALY_THROTTLE = 8'd5;  // v0.6 §3.8 (hw + daemon)
  /* verilator lint_on UNUSEDPARAM */

endpackage : emri_pkg
