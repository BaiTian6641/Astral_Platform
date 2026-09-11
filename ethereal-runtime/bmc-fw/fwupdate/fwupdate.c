/* SPDX-License-Identifier: MIT */
/*
 * fwupdate.c — E1-BMC2 dual-partition FW self-update demo (SIM-SCOPED,
 * emri-v0.md sec 3.6, v0.4). See fwupdate.h for the scope/ASSUMPTIONs.
 *
 * Boot stub + update server:
 *   fwupdate_boot()   : pick ACTIVE slot -> CRC32 verify -> (fallback to
 *                       the other slot on mismatch) -> XIP jump to the
 *                       slot payload (entry = slot_base + 5 words).
 *   fwupdate_server() : EFP_CMD=6 fwupdate — receive the new image words
 *                       over the REUSED EFP staging registers
 *                       (IMG_SIG[0..15] payload, IMG_DIGEST[0] expected
 *                       CRC32 trailer, EFP_IMG_WORDS word count,
 *                       EFP_IMG_COLS new version, EFP_REGION target slot),
 *                       verify, write slot + header, mark active (target
 *                       first), push an event-ring slot_change entry,
 *                       "reboot" (re-enter the boot stub).
 *                       EFP_CMD=7 reboot — re-enter the boot stub on
 *                       demand (the corrupted-slot fallback demo).
 *
 * The CRC32 is byte-wise MSB-first over each 32-bit word, poly 0x04C11DB7,
 * init 0xFFFFFFFF, no final xor — IDENTICAL to occ_top's streaming CRC32
 * (self-consistency, not interop; spec sec 3.6 step 2).
 *
 * G1: no dynamic memory; static state only. -Wall -Wextra -Werror clean.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.4/3.6 (v0.4).
 */
#include "fwupdate/fwupdate.h"
#include "drivers/emri.h"
#include "drivers/uart.h"
#include "daemon/daemon.h" /* EFP_CMD/EFP_ERR/EVT_* codes (single ABI) */

/* Event-ring stamp: this firmware has no tick source; reuse the boot/boot
 * count as the stamp (spec sec 3.4: stamps order events, not wall time).
 * ASSUMPTION (TBD 2026-09-08): demo-scoped monotonic counter. */
static uint16_t g_seq;

/* ------------------------------------------------------------------ */
/* Flash stand-in access (XBUS window; word-addressed)                  */
/* ------------------------------------------------------------------ */
static uint32_t flash_rd(uint32_t word_off)
{
    return *(volatile uint32_t *)(FW_FLASH_BASE + word_off * 4u);
}

static void flash_wr(uint32_t word_off, uint32_t val)
{
    *(volatile uint32_t *)(FW_FLASH_BASE + word_off * 4u) = val;
}

/* ------------------------------------------------------------------ */
/* CRC32 — identical algorithm to occ_top's streaming CRC32             */
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

static uint32_t slot_payload_crc(uint32_t slot)
{
    uint32_t base = slot * FW_SLOT_WORDS;
    uint32_t crc  = 0xFFFFFFFFu;
    for (uint32_t i = 0u; i < FW_PAYLOAD_WORDS; i++) {
        crc = crc32_word(crc, flash_rd(base + FW_HDR_WORDS + i));
    }
    return crc;
}

static uint32_t slot_flags(uint32_t slot)
{
    return flash_rd(slot * FW_SLOT_WORDS + 4u);
}

/* ------------------------------------------------------------------ */
/* Event ring (spec sec 3.4): {code, region=slot, stamp=seq}            */
/* ------------------------------------------------------------------ */
static void event_push(uint8_t code, uint8_t slot, uint16_t stamp)
{
    emri_write(EMRI_EVT_LOG_DATA_WORD,
               ((uint32_t)stamp << 16) | ((uint32_t)slot << 8) |
                   (uint32_t)code);
}

/* ------------------------------------------------------------------ */
/* Boot stub                                                            */
/* ------------------------------------------------------------------ */
static void slot_jump(uint32_t slot)
{
    typedef void (*entry_fn)(void);
    uintptr_t entry =
        FW_FLASH_BASE + (slot * FW_SLOT_WORDS + FW_HDR_WORDS) * 4u;
    uart_puts("payload: ");
    ((entry_fn)entry)(); /* XIP through XBUS; returns here */
    uart_puts("\n");
}

/* "boot: slot <A|B> v<version>" — the selection line the crc ok/FAIL
 * paths share (the TB's observable contract; the no-image path keeps its
 * own wording). Version = slot header word 1 (E1-BMC2 demo: 1 digit). */
static void boot_print_selection(uint32_t slot, uint32_t base)
{
    uart_puts("boot: slot ");
    uart_putc((char)('A' + (int32_t)slot));
    uart_puts(" v");
    uart_putc((char)('0' + (int32_t)flash_rd(base + 1u)));
}

void fwupdate_boot(void)
{
    uint32_t active;

    /* Pick the ACTIVE-flagged slot (both/neither flagged -> A, v0 demo). */
    if ((slot_flags(1u) & FW_FLAG_ACTIVE) != 0u &&
        (slot_flags(0u) & FW_FLAG_ACTIVE) == 0u) {
        active = 1u;
    } else {
        active = 0u;
    }

    for (uint32_t attempt = 0u; attempt < 2u; attempt++) {
        uint32_t slot = (attempt == 0u) ? active : (1u - active);
        uint32_t base = slot * FW_SLOT_WORDS;

        if (flash_rd(base) != FW_SLOT_MAGIC) {
            uart_puts("boot: slot ");
            uart_putc((char)('A' + (int32_t)slot));
            uart_puts(" no image\n");
            continue;
        }
        if (slot_payload_crc(slot) == flash_rd(base + 3u)) {
            boot_print_selection(slot, base);
            uart_puts(" crc ok\n");
            event_push(EVT_CODE_SLOT_CHANGE, (uint8_t)slot, ++g_seq);
            slot_jump(slot);
            return;
        }
        boot_print_selection(slot, base);
        uart_puts(" crc FAIL\n");
        if (attempt == 0u) {
            uart_puts("boot: fallback to last-known-good\n");
        }
    }
    uart_puts("boot: NO VALID SLOT (halted)\n");
    for (;;) {
        /* nothing left to run */
    }
}

/* ------------------------------------------------------------------ */
/* fw_update (EFP_CMD=6): staged receive -> CRC32 -> slot write ->      */
/* active-mark -> event -> re-boot (spec sec 3.6 step 1-3)              */
/* ------------------------------------------------------------------ */
static void do_fwupdate(void)
{
    uint32_t slot = emri_read(EMRI_EFP_REGION_WORD) & 0xFFu;
    uint32_t words = emri_read(EMRI_EFP_IMG_WORDS_WORD) & 0xFFFFu;
    uint32_t ver = emri_read(EMRI_EFP_IMG_COLS_WORD) & 0xFu;

    uart_puts("fw: update slot ");
    uart_putc((char)('A' + (int32_t)slot));
    uart_puts(" v");
    uart_putc((char)('0' + (int32_t)ver));
    uart_puts("\n");

    if (slot >= FW_SLOTS || words != FW_PAYLOAD_WORDS) {
        emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_BAD_CMD);
        uart_puts("fw: bad staging\n");
        return;
    }

    /* CRC32-verify the staged image against the trailer (IMG_DIGEST[0]). */
    uint32_t crc = 0xFFFFFFFFu;
    for (uint32_t i = 0u; i < words; i++) {
        crc = crc32_word(crc, emri_read(EMRI_IMG_SIG_WORD + i));
    }
    if (crc != emri_read(EMRI_IMG_DIGEST_WORD)) {
        emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_FWUPDATE);
        uart_puts("fw: crc BAD (no flash write)\n");
        return;
    }
    uart_puts("fw: crc ok\n");

    /* Write slot payload + header, then mark active (target first, then
     * clear the other slot's flag — a crash between the two leaves BOTH
     * active, which the boot stub resolves to A; documented v0 ordering). */
    uint32_t base = slot * FW_SLOT_WORDS;
    for (uint32_t i = 0u; i < words; i++) {
        flash_wr(base + FW_HDR_WORDS + i,
                 emri_read(EMRI_IMG_SIG_WORD + i));
    }
    flash_wr(base + 0u, FW_SLOT_MAGIC);
    flash_wr(base + 1u, ver);
    flash_wr(base + 2u, words);
    flash_wr(base + 3u, crc);
    flash_wr(base + 4u, FW_FLAG_ACTIVE);
    flash_wr((1u - slot) * FW_SLOT_WORDS + 4u, 0u);
    event_push(EVT_CODE_SLOT_CHANGE, (uint8_t)slot, ++g_seq);
    uart_puts("fw: slot ");
    uart_putc((char)('A' + (int32_t)slot));
    uart_puts(" active, reboot\n");

    fwupdate_boot(); /* emulated soft reset (fwupdate.h ASSUMPTION) */
}

void fwupdate_server(void)
{
    for (;;) {
        uint32_t cmd = emri_read(EMRI_EFP_CMD_WORD) & 0xFFu;
        if (cmd == EFP_CMD_NOP) {
            continue;
        }
        emri_write(EMRI_EFP_CMD_WORD, EFP_CMD_NOP); /* clear doorbell */
        emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_NONE);
        emri_write(EMRI_EFP_STATUS_WORD, EFP_STATUS_BUSY);

        switch (cmd) {
        case EFP_CMD_FWUPDATE:
            do_fwupdate();
            break;
        case EFP_CMD_REBOOT:
            uart_puts("fw: reboot\n");
            fwupdate_boot();
            break;
        default:
            emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_BAD_CMD);
            uart_puts("fw: bad_cmd\n");
            break;
        }

        /* Terminal: done (or ERROR already reported via EFP_ERR). */
        uint32_t err = emri_read(EMRI_EFP_ERR_WORD) & 0xFFu;
        emri_write(EMRI_EFP_STATUS_WORD,
                   EFP_STATUS_DONE |
                       (uint32_t)((err != EFP_ERR_NONE) ? EFP_S_ERROR
                                                        : EFP_S_IDLE));
    }
}
