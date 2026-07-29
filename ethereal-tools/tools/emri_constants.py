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
R_SESSION_CMD = 0x10
R_SESSION_STATUS = 0x11
R_RX_BUF_CTRL = 0x12
R_HEALTH_STATUS = 0x20
R_MON_TEMP = 0x30
R_MON_VCCINT = 0x31

# ---- CAPABILITIES bits ----
CAPB_HAS_BMC = 0
CAPB_HAS_DMA = 1
CAPB_HAS_I2C_MON = 2
CAPB_HAS_TRNG = 3
CAPB_HAS_JTAG_DBG = 4

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
