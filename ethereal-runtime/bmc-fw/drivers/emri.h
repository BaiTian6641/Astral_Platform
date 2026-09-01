/* SPDX-License-Identifier: MIT */
/*
 * emri.h — EMRI management-register access for bmc-fw (C side).
 *
 * The BMC reaches the EMRI register plane through the in-house AXI fabric:
 * a load/store to EMRI_WIN_BASE routes XBUS -> eth_wb2axi -> eth_axi_xbar ->
 * emri_axi_adapter -> emri_regfile. EMRI_WIN_BASE = 0x4000_2000 (the xbar
 * ADDR_MAP window in the sim TBs).
 *
 * Register word offsets MUST match ethereal-shell/rtl/emri/emri_pkg.sv and
 * ethereal-tools/tools/emri_constants.py (single ABI; drift = silent break).
 * Plan-Ref: ethereal-spec/control/emri-v0.md §2/§3/§3.2/§4;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md.
 */
#ifndef BMC_FW_EMRI_H
#define BMC_FW_EMRI_H

#include <stdint.h>

/* AXI window base for the EMRI peripheral (xbar slave). */
#define EMRI_WIN_BASE   ((uintptr_t)0x40002000u)

/* Word offsets (emri_pkg.sv R_*; byte = word*4). */
#define EMRI_MAGIC_WORD        0x00u  /* R_MAGIC        -> 0x45544852 "ETHR" */
#define EMRI_ABI_VERSION_WORD  0x01u  /* R_ABI_VERSION  -> v0 */
#define EMRI_CAP_WORD          0x02u  /* R_CAPABILITIES -> bit0 has_bmc */
#define EMRI_PLATFORM_ID_WORD  0x03u  /* R_PLATFORM_ID */
#define EMRI_NUM_REGIONS_WORD  0x04u  /* R_NUM_REGIONS  -> v0: 2 */
#define EMRI_OCC_CMD_WORD      0x08u  /* R_OCC_CMD      (sec 3) */
#define EMRI_OCC_WDATA_WORD    0x09u  /* R_OCC_WDATA    (W stream) */
#define EMRI_OCC_STATUS_WORD   0x0Au  /* R_OCC_STATUS   (sec 4) */
#define EMRI_OCC_FRAME_ADDR_WORD  0x0Bu  /* R_OCC_FRAME_ADDR */
#define EMRI_OCC_WORD_COUNT_WORD  0x0Cu  /* R_OCC_WORD_COUNT */
/* EFP command block (v0.2, spec sec 3.2): host<->daemon mailbox. */
#define EMRI_EFP_CMD_WORD      0x13u  /* R_EFP_CMD      doorbell */
#define EMRI_EFP_REGION_WORD   0x14u  /* R_EFP_REGION   0xFF = auto */
#define EMRI_EFP_IMG_WORDS_WORD 0x15u /* R_EFP_IMG_WORDS */
#define EMRI_EFP_STATUS_WORD   0x16u  /* R_EFP_STATUS   {state,busy,done} */
#define EMRI_EFP_ERR_WORD      0x17u  /* R_EFP_ERR      sticky error */
#define EMRI_IMG_DIGEST_WORD   0x18u  /* R_IMG_DIGEST   base, +0..7 */
#define EMRI_IMG_SIG_WORD      0x50u  /* R_IMG_SIG      base, +0..15 */

/* OCC_CMD bitfield (spec sec 3; emri_pkg OCC_CMD_*). */
#define EMRI_OCC_CMD_START     (1u << 8)
#define EMRI_OCC_OP_NOP        0u
#define EMRI_OCC_OP_WRITE      1u
#define EMRI_OCC_OP_READBACK   2u
#define EMRI_OCC_OP_BLANK      3u

/* OCC_STATUS bitfield (spec sec 4). */
#define EMRI_OCC_STATUS_DONE_FLAG (1u << 3)  /* sticky completion pending */
#define EMRI_OCC_STATUS_DONE_CODE(s) (((s) >> 4) & 0x3u) /* 0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED */
#define EMRI_OCC_STATUS_CRC_ERROR (1u << 16) /* sticky crc_error */

/* EMRI register read (word offset). */
static inline uint32_t emri_read(uint32_t word_off)
{
    return *(volatile uint32_t *)(EMRI_WIN_BASE + (word_off * 4u));
}

/* EMRI register write (word offset). */
static inline void emri_write(uint32_t word_off, uint32_t value)
{
    *(volatile uint32_t *)(EMRI_WIN_BASE + (word_off * 4u)) = value;
}

#endif /* BMC_FW_EMRI_H */
