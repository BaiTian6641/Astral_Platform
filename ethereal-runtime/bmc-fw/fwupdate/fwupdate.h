/* SPDX-License-Identifier: MIT */
/*
 * fwupdate.h — E1-BMC2 dual-partition FW self-update demo (SIM-SCOPED).
 *
 * emri-v0.md sec 3.6 (v0.4): two FW slots in a TB-writable XBUS-attached
 * memory standing in for external SPI flash. The boot stub picks the
 * ACTIVE-flagged slot, CRC32-verifies it (falling back to the other slot
 * = last-known-good on mismatch), and executes the slot payload in place
 * (XIP through XBUS). fw_update receives a new image over the REUSED EFP
 * staging registers, CRC32-verifies it, writes the slot, marks it active,
 * and re-enters the boot stub ("reboot" — EMULATED: the vendored NEORV32
 * netlist exposes no reachable in-core soft reset; ASSUMPTION TBD
 * 2026-09-08).
 *
 * ASSUMPTION (TBD 2026-09-08): this firmware is a SIM-ONLY demo of the
 * partition MECHANISM; real SPI flash, Boot-ROM anchoring and anti-
 * rollback are E2-SEC1/E2-BMC scope. The production daemon firmware
 * answers EFP_CMD=6/7 with bad_cmd (spec sec 3.6).
 *
 * G1: no dynamic memory (static state only). Bare-metal rv32imc.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.4/3.6 (v0.4);
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md.
 */
#ifndef BMC_FW_FWUPDATE_FWUPDATE_H
#define BMC_FW_FWUPDATE_FWUPDATE_H

#include <stdint.h>

/* "Flash" stand-in: XBUS window in the fwupdate TB (tb_bmc_fwupdate.sv),
 * 512 B = 128 words. NOT the EMRI window (that is 0x4000_2000). */
#define FW_FLASH_BASE   ((uintptr_t)0x40010000u)
#define FW_FLASH_WORDS  128u
#define FW_SLOTS        2u

/* Slot layout (word offsets within the flash window):
 *   slot s base = s * FW_SLOT_WORDS
 *   +0 magic, +1 version, +2 len(payload words), +3 crc32(payload),
 *   +4 flags (bit0 = active), +5.. payload (XIP entry = base + 5). */
#define FW_SLOT_WORDS   64u
#define FW_HDR_WORDS    5u
#define FW_SLOT_MAGIC   0x46445731u /* "FDW1" */

/* Payload word count (padded; the staging window IMG_SIG[0..15] size). */
#define FW_PAYLOAD_WORDS 16u

/* Slot flags. */
#define FW_FLAG_ACTIVE  0x1u

/* Scan slots, CRC-verify, (fall back,) jump to the payload entry; pushes
 * an EVT_LOG slot_change entry (region=slot, stamp=version) per selection.
 * Returns after the payload returns. */
void fwupdate_boot(void);

/* Boot-stub command server: poll the EFP_CMD doorbell forever.
 *   EFP_CMD=6 fwupdate: stage -> CRC32 verify -> slot write -> mark
 *                       active -> event -> re-boot into it
 *   EFP_CMD=7 reboot  : re-enter fwupdate_boot (fallback demo)
 * Never returns. */
void fwupdate_server(void);

#endif /* BMC_FW_FWUPDATE_FWUPDATE_H */
