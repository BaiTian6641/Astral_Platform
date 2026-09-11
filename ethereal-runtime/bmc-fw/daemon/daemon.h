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
#define EFP_CMD_RUN_PACKED 5u /* v0.3: bit-packed production-frame deploy (sec 3.3) */
#define EFP_CMD_FWUPDATE   6u /* v0.4 sec 3.6: SIM-DEMO (E1-BMC2). The production
                               * daemon answers this (and REBOOT) bad_cmd. */
#define EFP_CMD_REBOOT     7u /* v0.4 sec 3.6: SIM-DEMO re-enter boot stub */
#define EFP_CMD_CTX_SAVE    8u /* v0.7 sec 3.9: freeze fabric + save FF context
                               * (requires the region RUNNING) */
#define EFP_CMD_CTX_RESTORE 9u /* v0.7 sec 3.9: restore FF context + resume
                               * (requires the region PAUSED) */
#define EFP_CMD_SCRIPT     10u /* E2-AST1 SIM-DEMO (NOT yet in emri-v0.md): run
                               * the flash-resident deployment script selected
                               * by EFP_REGION. Only a firmware that installs
                               * an extension handler (daemon_set_ext_handler)
                               * answers it; the production daemon and any
                               * variant without a handler answer bad_cmd —
                               * the same convention as FWUPDATE/REBOOT (6/7,
                               * spec sec 3.6). */
#define EFP_REGION_AUTO 0xFFu /* auto-allocate first free (run only) */

#define EFP_S_IDLE     0u
#define EFP_S_VERIFY   1u
#define EFP_S_ALLOC    2u
#define EFP_S_BLANK    3u
#define EFP_S_LOAD     4u
#define EFP_S_READBACK 5u
#define EFP_S_RUNNING  6u
#define EFP_S_ERROR    7u
#define EFP_S_STOPPED  8u
#define EFP_S_PAUSED   9u /* v0.7 sec 3.9: context saved, fabric frozen */

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
#define EFP_ERR_CRC_TRANSPORT    8u /* v0.3 sec 7.1: EFP-SPI OCC_PUSH CRC16 mismatch */
#define EFP_ERR_WATCHDOG_TIMEOUT 9u /* v0.4 sec 3.5: OCC op watchdog fired */
#define EFP_ERR_FWUPDATE        10u /* v0.4 sec 3.6 (sim-demo): fw-update CRC mismatch */
#define EFP_ERR_CAPABILITY_DENIED 11u /* v0.6 sec 3.7: staged capability declaration
                                       * exceeds the grantable platform set */
#define EFP_ERR_RATE_LIMITED      12u /* v0.6 sec 3.8: target region throttled by
                                       * the anomaly monitor */
#define EFP_ERR_CTX_ERROR         13u /* v0.7 sec 3.9: context save/restore refused
                                       * (wrong lifecycle state, words=0) or the
                                       * engine reported an error */

/* Event-log entry codes (emri-v0.md sec 3.4; entry = {code, region, stamp}). */
#define EVT_CODE_WATCHDOG_TIMEOUT 1u /* sec 3.5: op watchdog fired on region */
#define EVT_CODE_HB_MISMATCH      2u /* sec 3.5: heartbeat READBACK CRC mismatch */
#define EVT_CODE_SLOT_CHANGE      3u /* sec 3.6 (sim-demo): slot selected/updated */
#define EVT_CODE_POLICY_DENIED    4u /* v0.6 sec 3.7: capability gate refused the
                                      * staged declaration (EFP_ERR=11). Code 5
                                      * (anomaly_throttle) is pushed by the RTL
                                      * monitor, not the daemon. */

/* OCC op watchdog budget (sec 3.5): occ_wait_done poll iterations before the
 * daemon declares the op starved. One iteration = efp_spi_service() + one
 * EMRI OCC_STATUS read ~= 100 fabric cycles, so 2^20 iterations ~= 1.05e8
 * cycles ~= 1.05 s @ 100 MHz. Worst LEGIT case is LOAD pacing: 4096 words
 * (16 KiB rx_buf bound) over a 1 MHz EFP-SPI link ~= 0.23 s — >4.5x margin;
 * AXI hosts are ~10^3x faster. BLANK/READBACK are self-driven (us). */
#define OCC_WDT_POLL_BUDGET (1u << 20)

/* Region heartbeat interval (sec 3.5): daemon IDLE poll-loop iterations
 * between READBACK liveness probes of RUNNING regions. ~= 2e7 cycles
 * ~= 0.2 s @ 100 MHz; live-session command gaps are us-ms, so the probe
 * only runs in genuinely idle stretches. v0 simplification: READBACK CRC
 * stands in for a HW heartbeat tap (E2 scope). */
#define DAEMON_HB_INTERVAL 200000u

/* Region count: v0 fixed at 2 (ADR-004 build-time; NUM_REGIONS reg = 2). */
#define DAEMON_NUM_REGIONS 2u
/* Fabric column count: v0 sim fabric is 2x2 -> 2 columns. v0 region->column
 * mapping ASSUMPTION (emri-v0.md sec 3.3): region r covers the columns
 * starting at column r. */
#define DAEMON_FAB_COLS 2u

/* Reset the region table and EFP status registers; call once at boot. */
void daemon_init(void);

/* Daemon main loop: poll the EFP_CMD doorbell forever; each accepted command
 * runs to completion (single outstanding command, spec sec 3.2). Never
 * returns. */
void daemon_spin(void);

/* Dispatch ONE accepted EFP command to its handler (the daemon_spin command
 * table, spec sec 3.2) with NO doorbell framing — the caller owns accept /
 * busy / squelch. A firmware-side script interpreter (E2-AST1 script/script.c)
 * calls this once per script DEPLOY/STOP op, so a scripted deployment drives
 * the SAME handlers as a host doorbell. */
void daemon_dispatch(uint8_t cmd, uint8_t region_sel);

/* Optional handler for SIM-DEMO commands that are not in daemon_dispatch
 * (E2-AST1 EFP_CMD_SCRIPT): receives EFP_REGION and returns an EFP_ERR_*
 * code (EFP_ERR_NONE on success), which the dispatcher applies via the
 * regular error path. NULL (the default, and the production firmware) means
 * such a command fails with bad_cmd. Install from main() after
 * daemon_init(). */
typedef uint8_t (*daemon_ext_fn)(uint8_t region_sel);
void daemon_set_ext_handler(daemon_ext_fn fn);

#endif /* BMC_FW_DAEMON_DAEMON_H */
