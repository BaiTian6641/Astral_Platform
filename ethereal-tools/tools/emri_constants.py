# SPDX-License-Identifier: MIT
"""EMRI register constants — Python mirror of emri_pkg.sv.

Single source of truth for the Python side (ethctl, daemon, host driver, sim
TBs). Values MUST match ethereal-shell/rtl/emri/emri_pkg.sv exactly — a
drift here vs the RTL is a silent ABI break. ethereal-spec/control/emri-v0.md
is the spec both derive from.

Plan-Ref: ethereal-spec/control/emri-v0.md sec 2/3/4/7.
"""
from __future__ import annotations

# ---- Magic / ABI ----
EMRI_MAGIC = 0x45544852  # "ETHR"
EMRI_ABI_VERSION = 0x0000_0000  # v0

# ---- Register word-offsets (spec sec 2) ----
R_MAGIC = 0x00
R_ABI_VERSION = 0x01
R_CAPABILITIES = 0x02
R_PLATFORM_ID = 0x03
R_NUM_REGIONS = 0x04
R_REGION_INFO = 0x05
R_REGION_SEL = 0x06
R_OCC_CMD = 0x08
R_OCC_WDATA = 0x09
R_OCC_STATUS = 0x0A
R_OCC_FRAME_ADDR = 0x0B
R_OCC_WORD_COUNT = 0x0C
R_OCC_DECODE = 0x0D
R_OCC_EXPECT_CRC = 0x0E  # v0.5 (spec sec 3.1.1): expected READBACK CRC (RW)
R_OCC_CRC_RESULT = 0x0F  # v0.5 (spec sec 3.1.1): OCC running/streaming CRC (R)
R_SESSION_CMD = 0x10
R_SESSION_STATUS = 0x11
R_RX_BUF_CTRL = 0x12
R_HEALTH_STATUS = 0x20
R_MON_TEMP = 0x30
R_MON_VCCINT = 0x31
# Anomaly monitoring (spec sec 3.8, v0.6): per-region reconfig/watchdog counters,
# spike flags + throttle mask, window/threshold config, event notify.
R_MON_RECFG_COUNT = 0x32  # {region1[31:16], region0[15:0]}, saturating
R_MON_WDT_COUNT = 0x33  # same layout; watchdog/heartbeat events
R_MON_ANOM_STATUS = 0x34  # [7:0] throttle mask, [11:8] spike flags; R/W1C
R_MON_ANOM_WINDOW = 0x35  # observation window in monitor ticks; 0 disables
R_MON_ANOM_THRESH = 0x36  # {wdt[31:16], recfg[15:0]} per-window thresholds
R_MON_NOTIFY = 0x37  # write-1 pulses: bit r=deploy done, bit 8+r=wdt event

# ---- EFP command block (spec sec 3.2, v0.2) ----
# Host<->BMC-daemon mailbox. All plain RW storage in the regfile (no port-role
# distinction); the doorbell/clear convention is software. IMG_DIGEST[0..7]
# occupy 0x18-0x1F, IMG_SIG[0..15] occupy 0x50-0x5F (base offsets below).
R_EFP_CMD = 0x13  # daemon doorbell: 0=nop 1=run 2=stop 3=restart 4=abort
R_EFP_REGION = 0x14  # target region; 0xFF = auto-alloc first free (run only)
R_EFP_IMG_WORDS = 0x15
R_EFP_STATUS = 0x16  # {state[3:0], busy[4], done[5]}
R_EFP_ERR = 0x17  # sticky last-error, cleared on next EFP_CMD
R_EFP_IMG_COLS = 0x21  # v0.3 (spec sec 3.3): fabric columns a run_packed image spans
# Capability-declaration gate (spec sec 3.7, v0.6)
R_CAP_DECL_IO = 0x22  # declared pin-group bitmap: bit g = L1 pin group g
R_CAP_DECL_SVC = 0x23  # declared service bitmap: bit k = proxy index k
R_CAP_STATUS = 0x24  # [0]checked [1]denied [2]throttled [15:8]denied_io bitmap
R_CTX_CMD = 0x26  # v0.7 (spec sec 3.9): bit0=start, bit1=mode (0=save, 1=restore); reads 0
R_CTX_WORDS = 0x27  # chain word count (N/32; 0 invalid)
R_CTX_STATUS = 0x28  # {done[0], busy[1], err[2]}; done/err latched, cleared by CTX_CMD write
CTX_CMD_SAVE = 0x1  # start=1, mode=0
CTX_CMD_RESTORE = 0x3  # start=1, mode=1
CTX_STATUS_DONE = 1 << 0
CTX_STATUS_BUSY = 1 << 1
CTX_STATUS_ERR = 1 << 2
R_IMG_DIGEST = 0x18  # base; +0..7 (32-byte manifest digest)
R_IMG_SIG = 0x50  # base; +0..15 (64-byte Ed25519 signature)
IMG_DIGEST_WORDS = 8
IMG_SIG_WORDS = 16

# EFP doorbell command codes
EFP_CMD_NOP = 0
EFP_CMD_RUN = 1
EFP_CMD_STOP = 2
EFP_CMD_RESTART = 3
EFP_CMD_ABORT = 4
EFP_CMD_RUN_PACKED = 5  # v0.3: bit-packed production-frame deploy (spec sec 3.3)
EFP_CMD_FWUPDATE = 6  # v0.4 (spec sec 3.6): SIM-DEMO dual-partition fw update
EFP_CMD_REBOOT = 7  # v0.4 (spec sec 3.6): SIM-DEMO re-enter boot stub
EFP_CMD_CTX_SAVE = 8  # v0.7 (spec sec 3.9): freeze fabric + save FF context
EFP_CMD_CTX_RESTORE = 9  # v0.7 (spec sec 3.9): restore FF context + resume
EFP_REGION_AUTO = 0xFF
# EFP daemon lifecycle states (EFP_STATUS.state)
EFP_S_IDLE = 0
EFP_S_VERIFY = 1
EFP_S_ALLOC = 2
EFP_S_BLANK = 3
EFP_S_LOAD = 4
EFP_S_READBACK = 5
EFP_S_RUNNING = 6
EFP_S_ERROR = 7
EFP_S_STOPPED = 8
EFP_S_PAUSED = 9  # v0.7 (spec sec 3.9): context saved, fabric frozen

# EFP sticky error codes (EFP_ERR)
EFP_ERR_NONE = 0
EFP_ERR_BAD_SIG = 1
EFP_ERR_REGION_FULL = 2
EFP_ERR_REGION_LOCKED = 3
EFP_ERR_OCC_CRC = 4
EFP_ERR_OCC_REJECT = 5
EFP_ERR_BAD_CMD = 6
EFP_ERR_IMG_LEN_MISMATCH = 7
EFP_ERR_CRC_TRANSPORT = 8  # v0.3 (spec sec 7.1): EFP-SPI OCC_PUSH CRC16 mismatch
EFP_ERR_WATCHDOG_TIMEOUT = 9  # v0.4 (spec sec 3.5): OCC op watchdog fired
EFP_ERR_FWUPDATE = 10  # v0.4 (spec sec 3.6): sim-demo fw-update CRC mismatch
EFP_ERR_CAPABILITY_DENIED = 11  # v0.6 (spec sec 3.7): declared caps exceed grantable
EFP_ERR_RATE_LIMITED = 12  # v0.6 (spec sec 3.8): region throttled by anomaly monitor
EFP_ERR_CTX_ERROR = 13  # v0.7 (spec sec 3.9): context save/restore refused or failed

# ---- Event-log ring (spec sec 3.4, v0.4) ----
# 16-entry ring in the regfile: write 0x39 pushes, read 0x39 pops-oldest,
# write 0x38 with bit16 set clears. Entry = {code[7:0], region[15:8], stamp[31:16]}.
R_EVT_LOG_CTRL = 0x38
R_EVT_LOG_DATA = 0x39
EVT_LOG_DEPTH = 16
EVT_LOG_CLEAR = 0x0001_0000  # write-1-to-bit16-clears
EVT_CODE_WATCHDOG_TIMEOUT = 1
EVT_CODE_HB_MISMATCH = 2
EVT_CODE_SLOT_CHANGE = 3
EVT_CODE_POLICY_DENIED = 4  # v0.6 (spec sec 3.7): capability refusal
EVT_CODE_RATE_LIMITED = 5  # v0.6 (spec sec 3.8): anomaly throttle refusal

# ---- CAPABILITIES bits ----
CAPB_HAS_BMC = 0
CAPB_HAS_DMA = 1
CAPB_HAS_I2C_MON = 2
CAPB_HAS_TRNG = 3
CAPB_HAS_JTAG_DBG = 4
# ---- Capability-declaration gate bit layout (spec sec 3.7, v0.6) ----
CAP_DECL_BITS = 32  # CAP_DECL_IO/CAP_DECL_SVC are 32-bit bitmaps
CAP_STATUS_CHECKED = 0  # bit index of CAP_STATUS[0]
CAP_STATUS_DENIED = 1
CAP_STATUS_THROTTLED = 2
CAP_STATUS_DENIED_IO_LO = 8  # denied_io occupies bits [15:8]

# ---- Anomaly monitor encodings (spec sec 3.8, v0.6) ----
MON_ANOM_THROTTLE_MASK = 0x0000_00FF  # [7:0]: bit r throttles deploys to region r
MON_ANOM_FLAG_LO = 8  # flags [11:8]: 8+r0/9+r1 recfg spike, 10+r0/11+r1 wdt spike
MON_ANOM_WINDOW_DEFAULT = 0x1000  # reset default, // ASSUMPTION: TBD at bring-up
MON_ANOM_THRESH_DEFAULT = 0x0008_0010  # {wdt=8, recfg=16}, // ASSUMPTION: TBD
MON_NOTIFY_WDT_LO = 8  # MON_NOTIFY bit 8+r = watchdog event on region r

# ---- OCC_CMD bitfield (spec sec 3) ----
# OCC_CMD_START is the BIT INDEX of the start trigger (matches emri_pkg.sv,
# where it is used as `host_wdata_i[OCC_CMD_START]`). Build the mask with
# `(1 << OCC_CMD_START)`.
OCC_CMD_CMD_W = 2  # [1:0]
OCC_CMD_REG_W = 4  # [5:2]
OCC_CMD_START = 8  # bit index [8]

# ---- OCC opcodes (must match occ_top) ----
OCC_NOP = 0
OCC_WRITE = 1
OCC_READBACK = 2
OCC_BLANK = 3

# ---- OCC status encoding (must match occ_top status_o) ----
OCC_S_IDLE = 0
OCC_S_BUSY = 1
OCC_S_DONE = 2
OCC_S_ERROR = 3
OCC_S_LOCKED = 4
OCC_S_NEEDS_BLANK = 5

# ---- OCC_STATUS register bit layout (spec sec 4) ----
# [2:0] live status, [3] sticky done_flag, [5:4] sticky done_code,
# [16] sticky crc_error.
OCC_STATUS_DONE_FLAG = 3  # bit index of the sticky completion flag
OCC_STATUS_DONE_CODE_LO = 4  # done_code occupies [5:4]
# done_code values (valid when done_flag=1):
OCC_DONE_DONE = 0
OCC_DONE_ERROR = 1
OCC_DONE_NEEDS_BLANK = 2
OCC_DONE_LOCKED = 3

# ---- EFP-SPI operation opcodes (spec sec 7) ----
SPI_OP_RD = 0
SPI_OP_WR = 1
SPI_OP_BLOCK_RD = 2
SPI_OP_OCC_PUSH = 3

# ---- EFP-SPI response status bytes ----
SPI_STAT_OK = 0x00
SPI_STAT_BAD_OP = 0x01
SPI_STAT_BAD_ADDR = 0x02
SPI_STAT_BUSY = 0x03
SPI_STAT_CRC_ERR = 0x04  # v0.3 (spec sec 7.1): transport CRC16 mismatch
SPI_STAT_NOT_READY = 0xFF  # wire fill: "no response ready — retry" (sec 7.1)

# SPI_CRC latch offset (spec sec 7.1, v0.3): intercepted by the SPI front-end
# (not a regfile storage word).
R_SPI_CRC = 0x3F
