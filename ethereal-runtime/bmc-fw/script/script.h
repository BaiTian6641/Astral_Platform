/* SPDX-License-Identifier: MIT */
/*
 * script.h — E2-AST1 MCU scripted deployment: the flash-resident deployment
 * script format + the firmware-side interpreter API (SIM-SCOPED v1: the
 * command path is EFP_CMD_SCRIPT, which is NOT in emri-v0.md yet — see the
 * "spec ask" note at the bottom).
 *
 * WHY: an MCU-side (BMC) deployment script is a tiny, typed, flash-resident
 * bytecode that the BMC executes through its EXISTING EFP/EMRI/OCC machinery:
 * "the Type-F container is deployed and driven by a firmware-side script",
 * with no WASM runtime on the device. It is a policy/sequencing artifact
 * (deploy -> probe -> mark -> stop), NOT a general-purpose language: no
 * arithmetic, no data memory, no calls, no self-modification.
 *
 * WHERE: the script lives in the external-flash stand-in window the sim
 * already uses for firmware images (E1-BMC2 fwupdate/, 0x4001_0000, XBUS) and
 * is read word-wise over XBUS at run time — the interpreter holds no copy.
 * Two 64-word slots fit the 512 B window; a slot holds a 4-word header plus
 * up to 60 instruction words.
 *
 * ----------------------------------------------------------------------
 * SCRIPT FORMAT (v1) — one slot = header(4 words) + instruction words
 * ----------------------------------------------------------------------
 * Header (flash words 0..3 of the slot; all little-endian 32-bit words):
 *   +0  magic    0x53435231 "SCR1"
 *   +1  version  1
 *   +2  length   number of instruction words that follow the header
 *                (1..60; the executed program is exactly these words)
 *   +3  crc32    CRC32 over the `length` instruction words, same algorithm as
 *                occ_top / fwupdate.c (poly 0x04C11DB7, init 0xFFFFFFFF,
 *                MSB-byte-first per word, no final xor). The interpreter
 *                refuses a slot whose CRC does not match (INTEGRITY GATE).
 *
 * Instruction (one 32-bit word):
 *   [31:24] opcode
 *   [23:0]  operand — meaning per opcode; operand-carrying ops consume
 *           following words (counted in `length`)
 *
 * OPCODE TABLE (v1)
 *   0x00 END        —        halt; script status OK.
 *   0x01 DEPLOY     region   run the STAGED image into `region` (0..1, or
 *                            0xFF = auto) through the daemon's own EFP_CMD_RUN
 *                            handler: Ed25519 verify -> ALLOC -> BLANK ->
 *                            LOAD (host streams OCC_WDATA) -> READBACK ->
 *                            RUNNING + EFP_ERR=0. Requires the host to have
 *                            staged IMG_DIGEST/IMG_SIG/EFP_IMG_WORDS first
 *                            (spec sec 3.2 step 1) — the BMC script is the
 *                            sequencing/deployment policy, the manifest and
 *                            signature stay in the EMRI staging window.
 *   0x02 STOP       region   run EFP_CMD_STOP on `region` (BLANK + STOPPED).
 *   0x03 POLL       word     + IMMEDIATE WORD {mask[31:16], value[15:0]}:
 *                            read EMRI word `word` until (v & mask) == value;
 *                            the "read EMRI status / wait for a state" op,
 *                            budget-bounded (SCRIPT_POLL_BUDGET) -> on expiry
 *                            the script fails with SCRIPT_ERR_POLL.
 *   0x04 CHECK_ERR  err      require EFP_ERR[7:0] == err, else the script
 *                            fails with SCRIPT_ERR_CHECK (records the
 *                            actual value in the UART trace).
 *   0x05 UART       n        + ceil(n/4) IMMEDIATE WORDS carrying n ASCII
 *                            bytes LSB-first per word: emit them on UART0
 *                            (n = 1..SCRIPT_UART_MAX). The deployment
 *                            marker/telemetry op.
 *   0x06 WAIT       n        idle n service iterations (efp_spi_service()),
 *                            i.e. a bounded pace/settle delay.
 *   0x07 LOOP       n        open a loop body executed n times (n >= 1);
 *                            static nesting stack, depth SCRIPT_LOOP_DEPTH.
 *   0x08 LOOPEND    —        close the innermost loop (jump back to the body
 *                            start while iterations remain).
 *
 * Rejected at run time (typed status; nothing is deployed): unknown opcode,
 * bad slot/version/length, CRC mismatch, unpaired LOOP/LOOPEND, LOOP count 0,
 * over-long UART op, pc running past the body, instruction budget exhausted,
 * CHECK_ERR mismatch, POLL budget expired.
 *
 * SPEC ASK (parent folds into ethereal-spec/control/emri-v0.md; NOT done
 * here — this repo is spec-first, and a spec change is not this task's):
 *   - EFP doorbell command code 10 = EFP_CMD_SCRIPT, operand = script slot
 *     index in EFP_REGION (sim-scoped reuse today, exactly like the sec 3.6
 *     sim-demo reuse of EFP_IMG_COLS for the fw-update version).
 *   - a read-only status word R_SCRIPT_STATUS (proposed word offset 0x3A)
 *     carrying {status[7:0], slot[15:8]} so a host can read the last script
 *     verdict without parsing UART; today the verdict is UART-only
 *     ("script: done ok" / "script: err <name>") and the interpreter error
 *     maps onto EFP_ERR=bad_cmd (6) for register visibility.
 *
 * G1: no dynamic memory (static loop stack + static state only).
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2/§3.4/§3.6;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3;
 *           ethereal-plan/phases/phase-2-异构与双平台.md §3 (circuit-breaker:
 *           the MCU scripted-deployment degraded demo while the WASM line is
 *           blocked).
 */
#ifndef BMC_FW_SCRIPT_SCRIPT_H
#define BMC_FW_SCRIPT_SCRIPT_H

#include <stdint.h>

/* ------------------------------------------------------------------ */
/* Script window (external-flash stand-in; SIM-SCOPED)                  */
/* ------------------------------------------------------------------ */
/* XBUS window in tb_bmc_script.sv, 512 B = 128 words. Same window base as
 * the E1-BMC2 fwupdate flash stand-in (that variant is a separate firmware
 * build, so the two never share a window at run time). */
#define SCRIPT_FLASH_BASE   ((uintptr_t)0x40010000u)
#define SCRIPT_WINDOW_WORDS 128u
#define SCRIPT_SLOT_WORDS   64u  /* header + instructions, per slot */
#define SCRIPT_MAX_SLOTS    2u   /* SCRIPT_WINDOW_WORDS / SCRIPT_SLOT_WORDS */

/* Header words (offsets within a slot). */
#define SCRIPT_HDR_WORDS  4u
#define SCRIPT_MAGIC      0x53435231u /* "SCR1" */
#define SCRIPT_VERSION    1u
#define SCRIPT_MAX_INSN   (SCRIPT_SLOT_WORDS - SCRIPT_HDR_WORDS)

/* ------------------------------------------------------------------ */
/* Opcodes (script.h format table; the generator mirrors these)         */
/* ------------------------------------------------------------------ */
#define SCRIPT_OP_END       0x00u
#define SCRIPT_OP_DEPLOY    0x01u
#define SCRIPT_OP_STOP      0x02u
#define SCRIPT_OP_POLL      0x03u
#define SCRIPT_OP_CHECK_ERR 0x04u
#define SCRIPT_OP_UART      0x05u
#define SCRIPT_OP_WAIT      0x06u
#define SCRIPT_OP_LOOP      0x07u
#define SCRIPT_OP_LOOPEND   0x08u

/* ------------------------------------------------------------------ */
/* Status codes (script_run return; also UART-printed by name)          */
/* ------------------------------------------------------------------ */
#define SCRIPT_OK              0u  /* END reached, all checks passed */
#define SCRIPT_ERR_SLOT        1u  /* script index >= SCRIPT_MAX_SLOTS */
#define SCRIPT_ERR_MAGIC       2u  /* bad slot magic */
#define SCRIPT_ERR_VERSION     3u  /* unsupported format version */
#define SCRIPT_ERR_LENGTH      4u  /* length 0 or > SCRIPT_MAX_INSN */
#define SCRIPT_ERR_CRC         5u  /* integrity gate: header CRC mismatch */
#define SCRIPT_ERR_OPCODE      6u  /* unknown opcode */
#define SCRIPT_ERR_OPERAND     7u  /* op-specific operand out of range */
#define SCRIPT_ERR_PC          8u  /* pc ran past the body / END missing */
#define SCRIPT_ERR_LOOP        9u  /* unpaired LOOP/LOOPEND, depth exceeded */
#define SCRIPT_ERR_BUDGET      10u /* instruction budget exhausted */
#define SCRIPT_ERR_POLL        11u /* POLL budget expired */
#define SCRIPT_ERR_CHECK       12u /* CHECK_ERR mismatch */

/* ------------------------------------------------------------------ */
/* Interpreter budgets (bounded, static: no dynamic state)              */
/* ------------------------------------------------------------------ */
#define SCRIPT_LOOP_DEPTH   4u
#define SCRIPT_INSN_BUDGET  4096u        /* executed instructions per run */
#define SCRIPT_POLL_BUDGET  (1u << 20)   /* POLL service iterations */
#define SCRIPT_UART_MAX     64u          /* bytes per UART op */
#define SCRIPT_WAIT_MAX     (1u << 16)   /* WAIT service iterations */

/* Install the EFP_CMD_SCRIPT handler on the daemon (daemon_set_ext_handler).
 * Call once at boot, after daemon_init(); a firmware that does NOT call this
 * answers EFP_CMD_SCRIPT with bad_cmd (the production behavior). */
void script_register(void);

/* Run the deployment script in flash slot `index` to completion. Returns
 * SCRIPT_OK or a SCRIPT_ERR_* code; always leaves a trace on UART0. */
uint8_t script_run(uint8_t index);

#endif /* BMC_FW_SCRIPT_SCRIPT_H */
