`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      emri_pkg (package)
// Description: EMRI (Ethereal Management Register Interface) constants & encodings.
// Details:     Single source of truth for the EMRI register map (v0), the EFP-SPI
//              operation opcodes, and the OCC status encoding mirror. Must stay in
//              sync with ethereal-spec/control/emri-v0.md (spec-first rule).
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3/§4/§7
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
  // (R_OCC_DECODE @ 0x0D — a hardware DECODE trigger that pulses frame_decoder
  //  start from the regfile — is a v0.1 feature, not yet implemented. The v0
  //  bit-packed path drives the decoder's start_i directly (host/testbench
  //  pulse). 0x0D stays reserved in the EMRI spec for that v0.1 register.)
  localparam logic [15:0] R_SESSION_CMD    = 16'h10;
  localparam logic [15:0] R_SESSION_STATUS = 16'h11;
  localparam logic [15:0] R_RX_BUF_CTRL    = 16'h12;
  localparam logic [15:0] R_HEALTH_STATUS  = 16'h20;
  localparam logic [15:0] R_MON_TEMP       = 16'h30;
  localparam logic [15:0] R_MON_VCCINT     = 16'h31;

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
  /* verilator lint_on UNUSEDPARAM */

endpackage : emri_pkg
