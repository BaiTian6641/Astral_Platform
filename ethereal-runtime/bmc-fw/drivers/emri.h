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
#define EMRI_REGION_INFO_WORD  0x05u  /* R_REGION_INFO (windowed by REGION_SEL) */
#define EMRI_REGION_SEL_WORD   0x06u  /* R_REGION_SEL  (v0.1, sec 6) */
#define EMRI_OCC_CMD_WORD      0x08u  /* R_OCC_CMD      (sec 3) */
#define EMRI_OCC_WDATA_WORD    0x09u  /* R_OCC_WDATA    (W stream) */
#define EMRI_OCC_STATUS_WORD   0x0Au  /* R_OCC_STATUS   (sec 4) */
#define EMRI_OCC_FRAME_ADDR_WORD  0x0Bu  /* R_OCC_FRAME_ADDR */
#define EMRI_OCC_WORD_COUNT_WORD  0x0Cu  /* R_OCC_WORD_COUNT */
#define EMRI_OCC_DECODE_WORD   0x0Du  /* R_OCC_DECODE   (sec 3.1, frame_decoder trigger) */
#define EMRI_OCC_EXPECT_CRC_WORD  0x0Eu  /* R_OCC_EXPECT_CRC (v0.5, sec 3.1.1) */
#define EMRI_OCC_CRC_RESULT_WORD  0x0Fu  /* R_OCC_CRC_RESULT (v0.5, sec 3.1.1) */
/* EFP command block (v0.2, spec sec 3.2): host<->daemon mailbox. */
#define EMRI_EFP_CMD_WORD      0x13u  /* R_EFP_CMD      doorbell */
#define EMRI_EFP_REGION_WORD   0x14u  /* R_EFP_REGION   0xFF = auto */
#define EMRI_EFP_IMG_WORDS_WORD 0x15u /* R_EFP_IMG_WORDS */
#define EMRI_EFP_STATUS_WORD   0x16u  /* R_EFP_STATUS   {state,busy,done} */
#define EMRI_EFP_ERR_WORD      0x17u  /* R_EFP_ERR      sticky error */
#define EMRI_EFP_IMG_COLS_WORD 0x21u  /* R_EFP_IMG_COLS (v0.3, sec 3.3: run_packed column count) */
/* Context save/restore engine (v0.7, spec sec 3.9). */
#define EMRI_CTX_CMD_WORD    0x26u /* R_CTX_CMD    W: bit0=start, bit1=mode (0=save) */
#define EMRI_CTX_WORDS_WORD  0x27u /* R_CTX_WORDS  RW: chain words (N/32; 0 invalid) */
#define EMRI_CTX_STATUS_WORD 0x28u /* R_CTX_STATUS R: {done[0], busy[1], err[2]} */
#define EMRI_CTX_CMD_SAVE     0x1u /* start=1, mode=0 */
#define EMRI_CTX_CMD_RESTORE  0x3u /* start=1, mode=1 */
#define EMRI_CTX_STATUS_DONE  (1u << 0)
#define EMRI_CTX_STATUS_BUSY  (1u << 1)
#define EMRI_CTX_STATUS_ERR   (1u << 2)
/* Region lock matrix (v0.8, spec sec 3.10; C03 sec 5). */
#define EMRI_LKM_STATUS_WORD  0x29u /* R_LKM_STATUS R: [7:0] region locks, [8] global */
#define EMRI_LKM_CMD_WORD     0x2Au /* R_LKM_CMD    W: [3:0] op, [7:4] region index */
#define EMRI_LKM_OP_LOCK       0x1u /* lock region */
#define EMRI_LKM_OP_UNLOCK     0x2u /* unlock region */
#define EMRI_LKM_OP_LOCK_ALL   0x3u /* global lock */
#define EMRI_LKM_OP_UNLOCK_ALL 0x4u /* global unlock */
#define EMRI_LKM_STATUS_GLOBAL (1u << 8)
/* Capability-declaration gate (v0.6 sec 3.7): the host stages the compact
 * capabilities.yaml bitmap before EFP_CMD; CAP_STATUS is the RTL verdict
 * (read-only — cap_decl_* are plain RW staging, CAP_STATUS is produced by the
 * regfile comparator). */
#define EMRI_CAP_DECL_IO_WORD  0x22u  /* R_CAP_DECL_IO  declared pin-group bitmap */
#define EMRI_CAP_DECL_SVC_WORD 0x23u  /* R_CAP_DECL_SVC declared service bitmap */
#define EMRI_CAP_STATUS_WORD   0x24u  /* R_CAP_STATUS  HW verdict (emri_regfile) */
/* CAP_STATUS bitfield (spec sec 2/§3.7). */
#define EMRI_CAP_STATUS_CHECKED   (1u << 0)                       /* decl staged */
#define EMRI_CAP_STATUS_DENIED    (1u << 1)                       /* declared ⊄ grantable */
#define EMRI_CAP_STATUS_THROTTLED (1u << 2)                       /* §3.8 throttle mask */
#define EMRI_CAP_STATUS_DENIED_IO(s) (((s) >> 8) & 0xFFu)         /* offending bitmap low byte */
/* Anomaly monitoring v1 (v0.6 sec 3.8): counters/window/threshold live in the
 * RTL monitor; the daemon only reads the status and writes MON_NOTIFY pulses. */
#define EMRI_MON_RECFG_COUNT_WORD 0x32u /* {region1[31:16], region0[15:0]} deploys */
#define EMRI_MON_WDT_COUNT_WORD   0x33u /* same layout: watchdog/heartbeat events */
#define EMRI_MON_ANOM_STATUS_WORD 0x34u /* [7:0] throttle, [11:8] spike flags, W1C */
#define EMRI_MON_ANOM_WINDOW_WORD 0x35u /* ticks/window; 0 disables the monitor */
#define EMRI_MON_ANOM_THRESH_WORD 0x36u /* {wdt[31:16], recfg[15:0]} per-window */
#define EMRI_MON_NOTIFY_WORD      0x37u /* write-1 pulse into the HW counters */
/* MON_ANOM_STATUS bitfield: throttle mask bit r, spike flags 8+r (reconfig
 * rate) / 10+r (watchdog rate); a set flag also sets throttle bit r. */
#define EMRI_MON_ANOM_THROTTLE(r)   (1u << (r))
#define EMRI_MON_ANOM_FLAG_RECFG(r) (1u << (8u + (r)))
#define EMRI_MON_ANOM_FLAG_WDT(r)   (1u << (10u + (r)))
/* MON_NOTIFY write-1 pulses: bit r = deploy completed in region r (recfg
 * counter +1); bit 8+r = sec 3.5 watchdog/heartbeat event on region r. */
#define EMRI_MON_NOTIFY_DEPLOY(r) (1u << (r))
#define EMRI_MON_NOTIFY_WDT(r)    (1u << (8u + (r)))
#define EMRI_IMG_DIGEST_WORD   0x18u  /* R_IMG_DIGEST   base, +0..7 */
#define EMRI_IMG_SIG_WORD      0x50u  /* R_IMG_SIG      base, +0..15 */
/* SPI_CRC @ 0x3F (v0.3, spec sec 7.1): EFP-SPI transport-CRC16 latch. NOT a
 * regfile storage word — intercepted by the efp-spi front-end (efp-spi/). */
#define EMRI_SPI_CRC_WORD      0x3Fu
/* Event-log ring (v0.4, spec sec 3.4): the daemon WRITES 0x39 to push an
 * entry {code[7:0], region[15:8], stamp[31:16]}; the host pops via reads of
 * 0x39 and clears via a write of bit16 to 0x38. The daemon NEVER reads 0x39
 * (a read pops the oldest entry). */
#define EMRI_EVT_LOG_CTRL_WORD 0x38u /* R: {count[15:0], wr_ptr[31:16]}  */
#define EMRI_EVT_LOG_DATA_WORD 0x39u /* W: push entry / R(host): pop-oldest */
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
