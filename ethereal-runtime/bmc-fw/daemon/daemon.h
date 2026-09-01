/* SPDX-License-Identifier: MIT */
/*
 * daemon.h — E1-RUN2 BMC daemon: EFP command-block lifecycle engine.
 *
 * The daemon is the BMC half of the host<->BMC mailbox (emri-v0.md sec 3.2,
 * v0.2): the host stages IMG_DIGEST/IMG_SIG/EFP_IMG_WORDS/EFP_REGION, rings
 * EFP_CMD, and polls EFP_STATUS/EFP_ERR; the daemon verifies the image
 * signature (Ed25519 against the compiled-in trusted key, keyring.h),
 * allocates a region, and drives the OCC lifecycle (BLANK -> WRITE arm ->
 * host streams OCC_WDATA -> READBACK) to RUNNING.
 *
 * The EFP_* constants below MUST mirror ethereal-shell/rtl/emri/emri_pkg.sv
 * and ethereal-tools/tools/emri_constants.py (single ABI; drift = silent
 * break). G1: no dynamic memory (static region table only).
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2/§4;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3.
 */
#ifndef BMC_FW_DAEMON_DAEMON_H
#define BMC_FW_DAEMON_DAEMON_H

#include <stdint.h>

/* EFP doorbell command codes (emri_pkg.sv EFP_CMD_*). */
#define EFP_CMD_NOP     0u
#define EFP_CMD_RUN     1u
#define EFP_CMD_STOP    2u
#define EFP_CMD_RESTART 3u
#define EFP_CMD_ABORT   4u
#define EFP_REGION_AUTO 0xFFu /* auto-allocate first free (run only) */

/* EFP daemon lifecycle states (EFP_STATUS.state[3:0]). */
#define EFP_S_IDLE     0u
#define EFP_S_VERIFY   1u
#define EFP_S_ALLOC    2u
#define EFP_S_BLANK    3u
#define EFP_S_LOAD     4u
#define EFP_S_READBACK 5u
#define EFP_S_RUNNING  6u
#define EFP_S_ERROR    7u
#define EFP_S_STOPPED  8u

/* EFP_STATUS bit layout: {state[3:0], busy[4], done[5]}. */
#define EFP_STATUS_BUSY (1u << 4)
#define EFP_STATUS_DONE (1u << 5)

/* EFP sticky error codes (EFP_ERR; emri_pkg.sv EFP_ERR_*). */
#define EFP_ERR_NONE             0u
#define EFP_ERR_BAD_SIG          1u
#define EFP_ERR_REGION_FULL      2u
#define EFP_ERR_REGION_LOCKED    3u
#define EFP_ERR_OCC_CRC          4u
#define EFP_ERR_OCC_REJECT       5u
#define EFP_ERR_BAD_CMD          6u
#define EFP_ERR_IMG_LEN_MISMATCH 7u

/* Region count: v0 fixed at 2 (ADR-004 build-time; NUM_REGIONS reg = 2). */
#define DAEMON_NUM_REGIONS 2u

/* Reset the region table and EFP status registers; call once at boot. */
void daemon_init(void);

/* Daemon main loop: poll the EFP_CMD doorbell forever; each accepted command
 * runs to completion (single outstanding command, spec sec 3.2). Never
 * returns. */
void daemon_spin(void);

#endif /* BMC_FW_DAEMON_DAEMON_H */
