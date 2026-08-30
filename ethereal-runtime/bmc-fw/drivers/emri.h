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
 * Plan-Ref: ethereal-spec/control/emri-v0.md §2/§3;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md.
 */
#ifndef BMC_FW_EMRI_H
#define BMC_FW_EMRI_H

#include <stdint.h>

/* AXI window base for the EMRI peripheral (xbar slave). */
#define EMRI_WIN_BASE   ((uintptr_t)0x40002000u)

/* Word offsets (emri_pkg.sv R_*; byte = word*4). */
#define EMRI_MAGIC_WORD       0x00u   /* R_MAGIC        -> 0x45544852 "ETHR" */
#define EMRI_ABI_VERSION_WORD 0x01u   /* R_ABI_VERSION  -> v0 */
#define EMRI_CAP_WORD         0x02u   /* R_CAPABILITIES -> bit0 has_bmc */
#define EMRI_PLATFORM_ID_WORD 0x03u   /* R_PLATFORM_ID */
#define EMRI_NUM_REGIONS_WORD 0x04u   /* R_NUM_REGIONS  -> v0: 2 */

/* EMRI register read (word offset). */
static inline uint32_t emri_read(uint32_t word_off)
{
    return *(volatile uint32_t *)(EMRI_WIN_BASE + (word_off * 4u));
}

#endif /* BMC_FW_EMRI_H */
