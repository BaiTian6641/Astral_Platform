/* SPDX-License-Identifier: MIT */
/*
 * script.c — E2-AST1 MCU scripted deployment: the firmware-side interpreter
 * (SIM-SCOPED v1; see script.h for the format, the opcode table and the spec
 * ask, and docs/reports/ for the acceptance report).
 *
 * The interpreter is deliberately tiny and fully bounded (G1: NO dynamic
 * memory — a 4-deep static loop stack, a static instruction budget, a static
 * POLL budget; the script itself is READ from the flash stand-in window over
 * XBUS one word at a time, never copied). Every op is typed and validated
 * before it touches hardware; any doubt fails the script instead of guessing.
 *
 * The point of the design: a script DEPLOY/STOP op runs the daemon's OWN
 * EFP_CMD_RUN/EFP_CMD_STOP handler (daemon_dispatch), so a scripted
 * deployment is the same machinery, same Ed25519 gate, same OCC lifecycle,
 * same EFP_ERR/EFP_STATUS observability as a host doorbell — the script only
 * decides the SEQUENCE. No WASM, no language, no runtime: the "Type-F
 * container deployed and driven by a firmware-side script" story on the MCU.
 *
 * UART trace contract (what a host/testbench observes):
 *   "script: run slot <n>\n"        — slot accepted (magic/version/len/CRC ok)
 *   "script: deploy r<n>\n"         — DEPLOY op issued (inner daemon logs follow)
 *   "script: stop r<n>\n"           — STOP op issued
 *   "script: poll <word> ok\n"      — POLL condition satisfied
 *   "script: err ok\n"              — CHECK_ERR matched
 *   "<marker bytes>"                — UART op output (verbatim)
 *   "script: done ok\n"             — END reached, every check passed
 *   "script: err <name>\n"          — typed failure (no further ops run)
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2/§3.4/§3.6;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3;
 *           ethereal-plan/phases/phase-2-异构与双平台.md §3 (circuit-breaker:
 *           the MCU scripted-deployment degraded demo while WASM is blocked).
 */
#include "script/script.h"
#include "drivers/emri.h"
#include "drivers/uart.h"
#include "daemon/daemon.h"
#include "efp-spi/efp_spi.h"

/* ------------------------------------------------------------------ */
/* Script slot access (flash stand-in window; word-addressed)           */
/* ------------------------------------------------------------------ */
static uint32_t script_rd(uint32_t word_off)
{
    return *(volatile uint32_t *)(SCRIPT_FLASH_BASE + word_off * 4u);
}

/* ------------------------------------------------------------------ */
/* CRC32 — identical algorithm to occ_top's streaming CRC32 and to      */
/* fwupdate.c (poly 0x04C11DB7, init 0xFFFFFFFF, MSB-byte-first per      */
/* word, no final xor). The two firmware variants are separate images,   */
/* so the static helper is not duplicated in any one binary.            */
/* ------------------------------------------------------------------ */
static uint32_t crc32_word(uint32_t crc, uint32_t w)
{
    for (int32_t by = 0; by < 4; by++) {
        uint8_t b = (uint8_t)((w >> 24) & 0xFFu); /* MSB byte first */
        crc ^= (uint32_t)b << 24;
        for (int32_t bit = 0; bit < 8; bit++) {
            if ((crc & 0x80000000u) != 0u) {
                crc = (crc << 1) ^ 0x04C11DB7u;
            } else {
                crc <<= 1;
            }
        }
        w <<= 8;
    }
    return crc;
}

static uint32_t slot_body_crc(uint32_t base, uint32_t len)
{
    uint32_t crc = 0xFFFFFFFFu;
    for (uint32_t i = 0u; i < len; i++) {
        crc = crc32_word(crc, script_rd(base + SCRIPT_HDR_WORDS + i));
    }
    return crc;
}

/* ------------------------------------------------------------------ */
/* Trace helpers                                                        */
/* ------------------------------------------------------------------ */
static void print_status(uint8_t status)
{
    switch (status) {
    case SCRIPT_OK:             uart_puts("ok"); break;
    case SCRIPT_ERR_SLOT:       uart_puts("bad slot"); break;
    case SCRIPT_ERR_MAGIC:      uart_puts("bad magic"); break;
    case SCRIPT_ERR_VERSION:    uart_puts("bad version"); break;
    case SCRIPT_ERR_LENGTH:     uart_puts("bad length"); break;
    case SCRIPT_ERR_CRC:        uart_puts("crc bad"); break;
    case SCRIPT_ERR_OPCODE:     uart_puts("bad opcode"); break;
    case SCRIPT_ERR_OPERAND:    uart_puts("bad operand"); break;
    case SCRIPT_ERR_PC:         uart_puts("pc out of range"); break;
    case SCRIPT_ERR_LOOP:       uart_puts("loop mismatch"); break;
    case SCRIPT_ERR_BUDGET:     uart_puts("insn budget"); break;
    case SCRIPT_ERR_POLL:       uart_puts("poll timeout"); break;
    case SCRIPT_ERR_CHECK:      uart_puts("check failed"); break;
    default:                    uart_puts("unknown"); break;
    }
}

static void print_region(const char *tag, uint32_t region)
{
    uart_puts("script: ");
    uart_puts(tag);
    uart_puts(" r");
    if (region == EFP_REGION_AUTO) {
        uart_puts("auto");
    } else {
        uart_putc((char)('0' + (int32_t)region));
    }
    uart_puts("\n");
}

/* ------------------------------------------------------------------ */
/* Ops                                                                  */
/* ------------------------------------------------------------------ */
/* Run one EFP command through the daemon's own handler. The sticky error
 * is cleared first, exactly as the daemon clears it at doorbell accept
 * (spec sec 3.2), so a following CHECK_ERR reads THIS op's verdict. */
static void script_issue(uint8_t cmd, uint8_t region)
{
    emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_NONE);
    emri_write(EMRI_EFP_REGION_WORD, (uint32_t)region);
    daemon_dispatch(cmd, region);
}

/* 0x03 POLL: read EMRI word `word` until (v & mask) == value. */
static uint8_t poll_word(uint32_t word, uint32_t mask, uint32_t value)
{
    for (uint32_t i = 0u; i < SCRIPT_POLL_BUDGET; i++) {
        if ((emri_read(word) & mask) == value) {
            return 0u;
        }
        efp_spi_service();
    }
    return 1u;
}

/* 0x05 UART: emit n bytes packed LSB-first across ceil(n/4) words. */
static void emit_marker(uint32_t base, uint32_t first_word, uint32_t n)
{
    for (uint32_t i = 0u; i < n; i++) {
        uint32_t w = script_rd(base + SCRIPT_HDR_WORDS + first_word + (i >> 2u));
        uart_putc((char)((w >> (8u * (i & 3u))) & 0xFFu));
    }
}

/* ------------------------------------------------------------------ */
/* Interpreter                                                          */
/* ------------------------------------------------------------------ */
struct script_loop {
    uint32_t count; /* remaining iterations of the innermost open loop */
    uint32_t body;  /* instruction index of the opening LOOP */
};

uint8_t script_run(uint8_t index)
{
    uint8_t status = SCRIPT_OK;

    /* --- slot header + integrity gate ------------------------------ */
    if (index >= SCRIPT_MAX_SLOTS) {
        uart_puts("script: err ");
        print_status(SCRIPT_ERR_SLOT);
        uart_puts("\n");
        return SCRIPT_ERR_SLOT;
    }
    uint32_t base = (uint32_t)index * SCRIPT_SLOT_WORDS;
    if (script_rd(base + 0u) != SCRIPT_MAGIC) {
        status = SCRIPT_ERR_MAGIC;
    } else if (script_rd(base + 1u) != SCRIPT_VERSION) {
        status = SCRIPT_ERR_VERSION;
    } else if (script_rd(base + 2u) == 0u ||
               script_rd(base + 2u) > SCRIPT_MAX_INSN) {
        status = SCRIPT_ERR_LENGTH;
    } else if (slot_body_crc(base, script_rd(base + 2u)) !=
               script_rd(base + 3u)) {
        status = SCRIPT_ERR_CRC;
    }
    if (status != SCRIPT_OK) {
        uart_puts("script: err ");
        print_status(status);
        uart_puts("\n");
        return status;
    }

    uint32_t len = script_rd(base + 2u);
    uart_puts("script: run slot ");
    uart_putc((char)('0' + (int32_t)index));
    uart_puts("\n");

    /* --- execute --------------------------------------------------- */
    struct script_loop loops[SCRIPT_LOOP_DEPTH];
    uint32_t depth  = 0u;
    uint32_t pc     = 0u;
    uint32_t budget = SCRIPT_INSN_BUDGET;
    uint8_t  halted = 0u;

    while (pc < len && halted == 0u && status == SCRIPT_OK) {
        if (budget == 0u) {
            status = SCRIPT_ERR_BUDGET;
            break;
        }
        budget--;

        uint32_t insn = script_rd(base + SCRIPT_HDR_WORDS + pc);
        uint32_t op   = insn >> 24;
        uint32_t arg  = insn & 0xFFFFFFu;
        uint32_t next = pc + 1u;

        switch (op) {
        case SCRIPT_OP_END:
            /* A malformed program must not be silently accepted: an END with
             * a loop still open is an unpaired LOOP/LOOPEND. */
            if (depth != 0u) {
                status = SCRIPT_ERR_LOOP;
                break;
            }
            halted = 1u;
            break;

        case SCRIPT_OP_DEPLOY:
        case SCRIPT_OP_STOP: {
            uint32_t region = arg & 0xFFu;
            if (region != EFP_REGION_AUTO && region >= DAEMON_NUM_REGIONS) {
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            print_region((op == SCRIPT_OP_DEPLOY) ? "deploy" : "stop", region);
            script_issue((op == SCRIPT_OP_DEPLOY) ? (uint8_t)EFP_CMD_RUN
                                                  : (uint8_t)EFP_CMD_STOP,
                         (uint8_t)region);
            break;
        }

        case SCRIPT_OP_POLL: {
            if (pc + 2u > len) {
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            uint32_t word = arg & 0xFFFFu;
            uint32_t imm  = script_rd(base + SCRIPT_HDR_WORDS + pc + 1u);
            uint32_t mask = (imm >> 16) & 0xFFFFu;
            uint32_t val  = imm & 0xFFFFu;
            uart_puts("script: poll ");
            uart_puthex16(word);
            if (mask == 0u) {
                uart_puts(" mask0\n");
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            if (poll_word(word, mask, val) != 0u) {
                uart_puts(" timeout\n");
                status = SCRIPT_ERR_POLL;
                break;
            }
            uart_puts(" ok\n");
            next = pc + 2u;
            break;
        }

        case SCRIPT_OP_CHECK_ERR: {
            uint32_t want = arg & 0xFFu;
            uint32_t got  = emri_read(EMRI_EFP_ERR_WORD) & 0xFFu;
            if (got != want) {
                uart_puts("script: err mismatch want ");
                uart_puthex32(want);
                uart_puts(" got ");
                uart_puthex32(got);
                uart_puts("\n");
                status = SCRIPT_ERR_CHECK;
                break;
            }
            uart_puts("script: err ok\n");
            break;
        }

        case SCRIPT_OP_UART: {
            uint32_t n = arg & 0xFFu;
            uint32_t words = (n + 3u) / 4u;
            if (n == 0u || n > SCRIPT_UART_MAX || pc + 1u + words > len) {
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            emit_marker(base, pc + 1u, n);
            next = pc + 1u + words;
            break;
        }

        case SCRIPT_OP_WAIT:
            if (arg == 0u || arg > SCRIPT_WAIT_MAX) {
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            for (uint32_t i = 0u; i < arg; i++) {
                efp_spi_service();
            }
            break;

        case SCRIPT_OP_LOOP:
            if (arg == 0u || depth >= SCRIPT_LOOP_DEPTH) {
                status = SCRIPT_ERR_OPERAND;
                break;
            }
            loops[depth].count = arg;
            loops[depth].body  = pc;
            depth++;
            break;

        case SCRIPT_OP_LOOPEND:
            if (depth == 0u) {
                status = SCRIPT_ERR_LOOP;
                break;
            }
            loops[depth - 1u].count--;
            if (loops[depth - 1u].count != 0u) {
                next = loops[depth - 1u].body + 1u;
            } else {
                depth--;
            }
            break;

        default:
            status = SCRIPT_ERR_OPCODE;
            break;
        }

        if (status == SCRIPT_OK && halted == 0u) {
            pc = next;
        }
    }

    if (status == SCRIPT_OK && halted == 0u) {
        status = SCRIPT_ERR_PC; /* fell off the end without END */
    }

    uart_puts("script: ");
    if (status == SCRIPT_OK) {
        uart_puts("done ok\n");
    } else {
        uart_puts("err ");
        print_status(status);
        uart_puts("\n");
    }
    return status;
}

/* ------------------------------------------------------------------ */
/* EFP_CMD_SCRIPT hook (daemon extension command)                       */
/* ------------------------------------------------------------------ */
/* The daemon applies a non-NONE return through its own error path
 * (EFP_ERR + state ERROR). A script that ends OK keeps whatever sticky
 * EFP_ERR its inner commands produced (e.g. bad_sig after a rejected
 * image — that verdict is the command's, and CHECK_ERR asserted it). */
static uint8_t script_hook(uint8_t region_sel)
{
    return (script_run(region_sel) == SCRIPT_OK) ? (uint8_t)EFP_ERR_NONE
                                                 : (uint8_t)EFP_ERR_BAD_CMD;
}

void script_register(void)
{
    daemon_set_ext_handler(script_hook);
}
