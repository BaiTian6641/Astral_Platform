/* SPDX-License-Identifier: MIT */
/*
 * daemon.c — E1-RUN2 BMC daemon (EFP command-block lifecycle engine).
 *
 * Implements the BMC-mode flow of emri-v0.md sec 3.2 against the EMRI
 * register plane (drivers/emri.h) and the Ed25519 verifier (crypto/):
 *
 *   run     : VERIFY (hex-UTF-8 digest Ed25519 vs keyring trusted pk)
 *             -> ALLOC (0xFF = first FREE; explicit = FREE only)
 *             -> BLANK (mandatory, blank-before-write red line)
 *             -> LOAD (arm WRITE; the HOST streams OCC_WDATA while the
 *                daemon supervises OCC_STATUS sticky done_flag/done_code)
 *             -> READBACK (crc/ERROR -> occ_crc) -> RUNNING, done=1
 *   stop    : BLANK the region -> STOPPED, region FREE
 *   restart : stop + re-run the last staged metadata (digest/sig/words are
 *             retained in the EMRI window until the host overwrites them)
 *   abort   : best-effort BLANK -> IDLE
 *   run_packed (v0.3, sec 3.3): VERIFY/ALLOC as run, then the per-column
 *             OCC_DECODE loop (sec 3.1): BLANK each covered column, per
 *             column DECODE+WRITE arm + host streams EFP_IMG_WORDS DATA
 *             words, READBACK per column -> RUNNING
 *
 * EFP_STATUS.state is updated at every transition; EFP_ERR is sticky until
 * the next EFP_CMD write (cleared by the daemon on accept). A doorbell write
 * that arrives while busy is squelched and flagged bad_cmd (spec sec 3.2).
 *
 * G1: no dynamic memory; the region table + staged-metadata cache are static.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2/§4;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3.
 */
#include "daemon.h"
#include "keyring.h"
#include "drivers/emri.h"
#include "drivers/uart.h"
#include "crypto/ed25519.h"
#include "efp-spi/efp_spi.h"

/* ------------------------------------------------------------------ */
/* Region table (static RAM; regions are build-time, ADR-004)          */
/* ------------------------------------------------------------------ */
typedef enum {
    REGION_FREE = 0, /* no image loaded (or stopped + blanked) */
    REGION_RUNNING,  /* image deployed and running            */
} region_state_e;

typedef struct {
    region_state_e state;
    uint16_t       img_words; /* frame words of the running image (for stop);
                               * run_packed: PER-COLUMN DATA word count      */
    uint8_t        img_cols;  /* run_packed: covered columns (0 = legacy run) */
} region_t;

static region_t g_regions[DAEMON_NUM_REGIONS];

/* Last staged run metadata locator (restart source). The digest/signature
 * words themselves stay in the EMRI IMG_DIGEST/IMG_SIG window registers until
 * the host overwrites them (spec sec 3.2 restart note), so only the region +
 * word count + validity are cached here. */
static uint8_t  g_last_region;
static uint16_t g_last_words;
static uint8_t  g_staged;
static uint8_t  g_last_packed; /* last staged image was run_packed (sec 3.3) */

/* Daemon status shadow (EFP_STATUS byte = {state[3:0], busy[4], done[5]}). */
static uint8_t g_state;
static uint8_t g_busy;
static uint8_t g_done;

/* ------------------------------------------------------------------ */
/* EFP status/error helpers                                            */
/* ------------------------------------------------------------------ */
static void efp_status_sync(void)
{
    emri_write(EMRI_EFP_STATUS_WORD,
               (uint32_t)g_state | (g_busy ? EFP_STATUS_BUSY : 0u) |
                   (g_done ? EFP_STATUS_DONE : 0u));
}

static void set_state(uint8_t state)
{
    g_state = state;
    efp_status_sync();
}

static void set_err(uint8_t err)
{
    emri_write(EMRI_EFP_ERR_WORD, (uint32_t)err);
}

static void print_err(uint8_t err)
{
    switch (err) {
    case EFP_ERR_BAD_SIG:          uart_puts("bad_sig"); break;
    case EFP_ERR_REGION_FULL:      uart_puts("region_full"); break;
    case EFP_ERR_REGION_LOCKED:    uart_puts("region_locked"); break;
    case EFP_ERR_OCC_CRC:          uart_puts("occ_crc"); break;
    case EFP_ERR_OCC_REJECT:       uart_puts("occ_reject"); break;
    case EFP_ERR_BAD_CMD:          uart_puts("bad_cmd"); break;
    case EFP_ERR_IMG_LEN_MISMATCH: uart_puts("img_len_mismatch"); break;
    case EFP_ERR_CRC_TRANSPORT:  uart_puts("crc_transport"); break;
    default:                       uart_puts("unknown"); break;
    }
}

/* Fail the current command: sticky EFP_ERR, state ERROR, busy=0. */
static void fail(uint8_t err)
{
    set_err(err);
    uart_puts("err ");
    print_err(err);
    uart_puts("\n");
    set_state(EFP_S_ERROR);   /* busy stays 1; the dispatcher clears it */
    uart_puts("st ERROR\n");
}

/* ------------------------------------------------------------------ */
/* OCC helpers (daemon drives OCC through the EMRI passthrough regs)   */
/* ------------------------------------------------------------------ */

/* Region frame base: OCC_FRAME_ADDR.{region_id[15:12]} (spec sec 2/§3). */
static uint32_t region_frame_base(uint8_t region)
{
    return (uint32_t)region << 12;
}

static void occ_issue(uint32_t op, uint8_t region)
{
    emri_write(EMRI_OCC_CMD_WORD,
               EMRI_OCC_CMD_START | ((uint32_t)region << 2) | op);
}

/* Poll the sticky done_flag (spec sec 4 bit [3]); returns the raw status. */
static uint32_t occ_wait_done(void)
{
    uint32_t s;
    do {
        efp_spi_service();  /* host streams OCC_WDATA over SPI during LOAD */
        s = emri_read(EMRI_OCC_STATUS_WORD);
    } while ((s & EMRI_OCC_STATUS_DONE_FLAG) == 0u);
    return s;
}

/* Map an OCC completion to an EFP error code (spec sec 3.2 step 5/6):
 * NEEDS_BLANK (dirty-region WRITE reject) -> occ_reject; sticky crc_error or
 * done_code ERROR -> occ_crc; done_code LOCKED -> region_locked. */
static uint8_t occ_check(uint32_t status)
{
    uint32_t code = EMRI_OCC_STATUS_DONE_CODE(status);
    if ((status & EMRI_OCC_STATUS_CRC_ERROR) != 0u) {
        return EFP_ERR_OCC_CRC;
    }
    if (code == 0u) {
        return EFP_ERR_NONE;
    }
    if (code == 2u) {
        return EFP_ERR_OCC_REJECT;
    }
    if (code == 3u) {
        return EFP_ERR_REGION_LOCKED;
    }
    return EFP_ERR_OCC_CRC;
}

/* BLANK a region (mandatory blank-before-write; OCC self-streams zeros).
 * Returns EFP_ERR_NONE on success (prints "blank ok"), else the error. */
static uint8_t occ_blank_region(uint8_t region, uint16_t words)
{
    set_state(EFP_S_BLANK);
    uart_puts("st BLANK\n");
    emri_write(EMRI_OCC_FRAME_ADDR_WORD, region_frame_base(region));
    emri_write(EMRI_OCC_WORD_COUNT_WORD, (uint32_t)words);
    occ_issue(EMRI_OCC_OP_BLANK, region);
    uint8_t err = occ_check(occ_wait_done());
    if (err == EFP_ERR_NONE) {
        uart_puts("blank ok\n");
    }
    return err;
}

/* BLANK one fabric column of a packed image (sec 3.3 step 2). The
 * OCC_DECODE pulse before the BLANK starts the frame_decoder capture so the
 * OCC's zero stream is decoded into fabric cfg writes (sec 3.1); the write
 * self-times against a busy decoder (regfile backpressure). */
static uint8_t occ_blank_column(uint8_t region, uint32_t col, uint16_t words)
{
    set_state(EFP_S_BLANK);
    uart_puts("st BLANK c");
    uart_putc((char)('0' + (int32_t)col));
    uart_puts("\n");
    emri_write(EMRI_OCC_FRAME_ADDR_WORD,
               region_frame_base(region) | (col << 4));
    emri_write(EMRI_OCC_WORD_COUNT_WORD, (uint32_t)words);
    emri_write(EMRI_OCC_DECODE_WORD, col);
    occ_issue(EMRI_OCC_OP_BLANK, region);
    uint8_t err = occ_check(occ_wait_done());
    if (err == EFP_ERR_NONE) {
        uart_puts("blank c");
        uart_putc((char)('0' + (int32_t)col));
        uart_puts(" ok\n");
    }
    return err;
}

/* BLANK every column a packed region covers (stop/abort of a packed image). */
static uint8_t occ_blank_packed(uint8_t region, uint8_t cols, uint16_t words)
{
    for (uint32_t c = (uint32_t)region; c < (uint32_t)region + (uint32_t)cols;
         c++) {
        uint8_t err = occ_blank_column(region, c, words);
        if (err != EFP_ERR_NONE) {
            return err;
        }
    }
    return EFP_ERR_NONE;
}

/* ------------------------------------------------------------------ */
/* VERIFY: hex-encode the 32-byte manifest digest to 64 lowercase-hex   */
/* chars (matching ethimg, which signs the hex-UTF-8 digest) and verify */
/* the Ed25519 signature against the trusted key (spec sec 3.2 step 3). */
/* ------------------------------------------------------------------ */
static uint8_t verify_staged_image(void)
{
    uint8_t digest[32];
    uint8_t sig[64];
    uint8_t hex[64];
    static const char hexdig[] = "0123456789abcdef";

    for (uint32_t i = 0u; i < 8u; i++) {
        uint32_t w = emri_read(EMRI_IMG_DIGEST_WORD + i); /* LE in-word */
        digest[4u * i + 0u] = (uint8_t)(w & 0xFFu);
        digest[4u * i + 1u] = (uint8_t)((w >> 8) & 0xFFu);
        digest[4u * i + 2u] = (uint8_t)((w >> 16) & 0xFFu);
        digest[4u * i + 3u] = (uint8_t)((w >> 24) & 0xFFu);
    }
    for (uint32_t i = 0u; i < 16u; i++) {
        uint32_t w = emri_read(EMRI_IMG_SIG_WORD + i);
        sig[4u * i + 0u] = (uint8_t)(w & 0xFFu);
        sig[4u * i + 1u] = (uint8_t)((w >> 8) & 0xFFu);
        sig[4u * i + 2u] = (uint8_t)((w >> 16) & 0xFFu);
        sig[4u * i + 3u] = (uint8_t)((w >> 24) & 0xFFu);
    }
    for (uint32_t i = 0u; i < 32u; i++) {
        hex[2u * i + 0u] = (uint8_t)hexdig[(digest[i] >> 4) & 0xFu];
        hex[2u * i + 1u] = (uint8_t)hexdig[digest[i] & 0xFu];
    }
    return (uint8_t)eth_ed25519_verify(sig, ETH_TRUSTED_PK, hex, 64u);
}

/* ------------------------------------------------------------------ */
/* ALLOC: 0xFF = first FREE; explicit index = that region if FREE.     */
/* (A RUNNING region is not available -> region_full; spec sec 3.2.     */
/*  v0 note: the OCC region lock is hardwired 0 in the regfile, so      */
/*  region_locked is only reachable via an OCC done_code==LOCKED.)      */
/* ------------------------------------------------------------------ */
static int32_t alloc_region(uint8_t region_sel)
{
    if (region_sel == EFP_REGION_AUTO) {
        for (uint32_t i = 0u; i < DAEMON_NUM_REGIONS; i++) {
            if (g_regions[i].state == REGION_FREE) {
                return (int32_t)i;
            }
        }
        return -1;
    }
    if (region_sel >= DAEMON_NUM_REGIONS) {
        return -1;
    }
    if (g_regions[region_sel].state != REGION_FREE) {
        return -1;
    }
    return (int32_t)region_sel;
}

/* ------------------------------------------------------------------ */
/* run (also the re-run half of restart): VERIFY -> ALLOC -> BLANK ->  */
/* LOAD -> READBACK -> RUNNING. The host streams OCC_WDATA while the   */
/* daemon is in LOAD polling OCC_STATUS. Between LOAD and READBACK the */
/* transport-CRC gate (sec 7.1 step 5) fails a CRC-mismatched EFP-SPI  */
/* session with crc_transport (region re-blanked, never RUNNING).      */
/* ------------------------------------------------------------------ */
static void do_run(uint8_t region_sel)
{
    set_state(EFP_S_VERIFY);
    uart_puts("st VERIFY\n");

    uint16_t words = (uint16_t)(emri_read(EMRI_EFP_IMG_WORDS_WORD) & 0xFFFFu);
    if (words == 0u) {
        fail(EFP_ERR_IMG_LEN_MISMATCH);
        return;
    }
    if (verify_staged_image() == 0u) {
        fail(EFP_ERR_BAD_SIG);
        return;
    }
    uart_puts("verify ok\n");

    set_state(EFP_S_ALLOC);
    uart_puts("st ALLOC\n");
    int32_t region = alloc_region(region_sel);
    if (region < 0) {
        fail(EFP_ERR_REGION_FULL);
        return;
    }
    uart_puts("alloc r");
    uart_putc((char)('0' + region));
    uart_puts("\n");

    uint8_t err = occ_blank_region((uint8_t)region, words);
    if (err != EFP_ERR_NONE) {
        fail(err);
        return;
    }

    /* Arm WRITE: OCC_FRAME_ADDR/WORD_COUNT from EFP_IMG_WORDS, then the
     * host streams the frame words through OCC_WDATA (same passthrough as
     * mFSM mode) while the daemon supervises OCC_STATUS (sec 3.2 step 5).
     * The WRITE command is issued BEFORE the LOAD state becomes visible so
     * that a host observing LOAD (or the "st LOAD" log line) can stream
     * immediately: the OCC is already consuming the wdata skid, so a stream
     * write can never hard-block the daemon's own EMRI traffic behind a
     * full skid with the OCC unarmed. */
    emri_write(EMRI_OCC_FRAME_ADDR_WORD, region_frame_base((uint8_t)region));
    emri_write(EMRI_OCC_WORD_COUNT_WORD, (uint32_t)words);
    occ_issue(EMRI_OCC_OP_WRITE, (uint8_t)region);
    set_state(EFP_S_LOAD);
    uart_puts("st LOAD\n");
    err = occ_check(occ_wait_done());
    if (err != EFP_ERR_NONE) {
        fail(err);
        return;
    }
    uart_puts("load ok\n");

    /* Transport-CRC gate (sec 7.1 step 5): an EFP-SPI session whose OCC_PUSH
     * stream mismatched the latched CRC16 never reaches READBACK/RUNNING;
     * re-BLANK to restore the pre-command blank state. CRC-less (AXI host)
     * sessions read EFP_SPI_CRC_NONE here and pass through. */
    if (efp_spi_crc_state() == EFP_SPI_CRC_ERR) {
        (void)occ_blank_region((uint8_t)region, words);
        fail(EFP_ERR_CRC_TRANSPORT);
        return;
    }

    set_state(EFP_S_READBACK);
    uart_puts("st READBACK\n");
    occ_issue(EMRI_OCC_OP_READBACK, (uint8_t)region);
    err = occ_check(occ_wait_done());
    if (err != EFP_ERR_NONE) {
        /* region stays non-RUNNING (spec sec 3.2 step 6) */
        fail(err);
        return;
    }
    uart_puts("readback ok\n");

    g_regions[region].state     = REGION_RUNNING;
    g_regions[region].img_words = words;
    g_regions[region].img_cols  = 0u;
    g_last_region = (uint8_t)region;
    g_last_words  = words;
    g_staged      = 1u;
    g_last_packed = 0u;
    g_done        = 1u;
    set_state(EFP_S_RUNNING);   /* busy stays 1; the dispatcher clears it */
    uart_puts("st RUNNING r");
    uart_putc((char)('0' + region));
    uart_puts(" done\n");
}

/* ------------------------------------------------------------------ */
/* run_packed (sec 3.3, v0.3): deploy a BIT-PACKED production frame set  */
/* through the per-column OCC_DECODE loop (sec 3.1). VERIFY/ALLOC as     */
/* run; then BLANK each covered column, then per column: program         */
/* OCC_FRAME_ADDR={region,col} + OCC_WORD_COUNT=EFP_IMG_WORDS            */
/* (PER-COLUMN DATA word count — v0 homogeneous, tail excluded), pulse   */
/* OCC_DECODE(col), arm WRITE; the HOST streams the column's DATA words  */
/* via OCC_WDATA while the daemon polls OCC_STATUS. READBACK per column  */
/* (CRC check), then RUNNING. State codes repeat per column (sec 3.3).   */
/* ------------------------------------------------------------------ */
static void do_run_packed(uint8_t region_sel)
{
    set_state(EFP_S_VERIFY);
    uart_puts("st VERIFY\n");

    uint16_t words = (uint16_t)(emri_read(EMRI_EFP_IMG_WORDS_WORD) & 0xFFFFu);
    uint8_t cols = (uint8_t)(emri_read(EMRI_EFP_IMG_COLS_WORD) & 0xFFu);
    if (words == 0u || cols == 0u) {
        fail(EFP_ERR_IMG_LEN_MISMATCH);
        return;
    }
    if (verify_staged_image() == 0u) {
        fail(EFP_ERR_BAD_SIG);
        return;
    }
    uart_puts("verify ok\n");

    set_state(EFP_S_ALLOC);
    uart_puts("st ALLOC\n");
    int32_t region = alloc_region(region_sel);
    if (region < 0) {
        fail(EFP_ERR_REGION_FULL);
        return;
    }
    /* v0 region->column mapping ASSUMPTION (sec 3.3): region r covers the
     * columns starting at column r; the range must fit the fabric. */
    if ((uint32_t)region + (uint32_t)cols > DAEMON_FAB_COLS) {
        fail(EFP_ERR_IMG_LEN_MISMATCH);
        return;
    }
    uart_puts("alloc r");
    uart_putc((char)('0' + region));
    uart_puts(" cols ");
    uart_putc((char)('0' + (int32_t)cols));
    uart_puts("\n");

    uint8_t err = occ_blank_packed((uint8_t)region, cols, words);
    if (err != EFP_ERR_NONE) {
        fail(err);
        return;
    }

    /* LOAD per column: program + DECODE + arm WRITE BEFORE the LOAD state
     * becomes visible (same anti-deadlock ordering as do_run: the OCC must
     * already be consuming the wdata skid when the host observes LOAD). The
     * host detects the arm as state==LOAD + OCC_STATUS.done_flag==0, bounded
     * by the previous column's done_flag==1 (sec 3.3 step 3). */
    for (uint32_t c = (uint32_t)region; c < (uint32_t)region + (uint32_t)cols;
         c++) {
        emri_write(EMRI_OCC_FRAME_ADDR_WORD,
                   region_frame_base((uint8_t)region) | (c << 4));
        emri_write(EMRI_OCC_WORD_COUNT_WORD, (uint32_t)words);
        emri_write(EMRI_OCC_DECODE_WORD, c);
        occ_issue(EMRI_OCC_OP_WRITE, (uint8_t)region);
        set_state(EFP_S_LOAD);
        uart_puts("st LOAD c");
        uart_putc((char)('0' + (int32_t)c));
        uart_puts("\n");
        err = occ_check(occ_wait_done());
        if (err != EFP_ERR_NONE) {
            fail(err);
            return;
        }
        uart_puts("load c");
        uart_putc((char)('0' + (int32_t)c));
        uart_puts(" ok\n");
    }

    /* Transport-CRC gate (sec 7.1 step 5): after the LAST column's LOAD the
     * OCC_PUSH stream is complete and the front-end's comparison has
     * completed (it precedes the OCC completion, step 4). On mismatch:
     * re-BLANK the covered columns, EFP_ERR=crc_transport, never RUNNING. */
    if (efp_spi_crc_state() == EFP_SPI_CRC_ERR) {
        uart_puts("crc_transport gate: re-blank\n");
        (void)occ_blank_packed((uint8_t)region, cols, words);
        fail(EFP_ERR_CRC_TRANSPORT);
        return;
    }

    /* READBACK per column (OCC streaming-CRC check, sec 3.3 step 4). */
    for (uint32_t c = (uint32_t)region; c < (uint32_t)region + (uint32_t)cols;
         c++) {
        set_state(EFP_S_READBACK);
        uart_puts("st READBACK c");
        uart_putc((char)('0' + (int32_t)c));
        uart_puts("\n");
        emri_write(EMRI_OCC_FRAME_ADDR_WORD,
                   region_frame_base((uint8_t)region) | (c << 4));
        emri_write(EMRI_OCC_WORD_COUNT_WORD, (uint32_t)words);
        occ_issue(EMRI_OCC_OP_READBACK, (uint8_t)region);
        err = occ_check(occ_wait_done());
        if (err != EFP_ERR_NONE) {
            /* region stays non-RUNNING (spec sec 3.2 step 6) */
            fail(err);
            return;
        }
        uart_puts("readback c");
        uart_putc((char)('0' + (int32_t)c));
        uart_puts(" ok\n");
    }

    g_regions[region].state     = REGION_RUNNING;
    g_regions[region].img_words = words;
    g_regions[region].img_cols  = cols;
    g_last_region = (uint8_t)region;
    g_last_words  = words;
    g_staged      = 1u;
    g_last_packed = 1u;
    g_done        = 1u;
    set_state(EFP_S_RUNNING);   /* busy stays 1; the dispatcher clears it */
    uart_puts("st RUNNING r");
    uart_putc((char)('0' + region));
    uart_puts(" done\n");
}

/* stop: BLANK the region, state STOPPED, region FREE (spec sec 3.2). A
 * packed (run_packed) region is blanked per column (sec 3.3). */
static void do_stop(uint8_t region_sel)
{
    if (region_sel >= DAEMON_NUM_REGIONS) {
        fail(EFP_ERR_BAD_CMD);
        return;
    }
    if (g_regions[region_sel].state == REGION_RUNNING) {
        uint8_t err;
        if (g_regions[region_sel].img_cols != 0u) {
            err = occ_blank_packed(region_sel, g_regions[region_sel].img_cols,
                                   g_regions[region_sel].img_words);
        } else {
            err = occ_blank_region(region_sel, g_regions[region_sel].img_words);
        }
        if (err != EFP_ERR_NONE) {
            fail(err);
            return;
        }
    }
    g_regions[region_sel].state     = REGION_FREE;
    g_regions[region_sel].img_words = 0u;
    g_regions[region_sel].img_cols  = 0u;
    g_done = 0u;
    set_state(EFP_S_STOPPED);   /* busy stays 1; the dispatcher clears it */
    uart_puts("st STOPPED r");
    uart_putc((char)('0' + (int32_t)region_sel));
    uart_puts("\n");
}

/* restart: stop + re-run with the last staged metadata (sec 3.2). A packed
 * image re-runs the PACKED flow (EFP_IMG_COLS is retained too, sec 3.3). */
static void do_restart(void)
{
    if (g_staged == 0u) {
        fail(EFP_ERR_BAD_CMD);
        return;
    }
    uint8_t region = g_last_region;
    if (g_regions[region].state == REGION_RUNNING) {
        uint8_t err;
        if (g_regions[region].img_cols != 0u) {
            err = occ_blank_packed(region, g_regions[region].img_cols,
                                   g_regions[region].img_words);
        } else {
            err = occ_blank_region(region, g_regions[region].img_words);
        }
        if (err != EFP_ERR_NONE) {
            fail(err);
            return;
        }
        g_regions[region].state     = REGION_FREE;
        g_regions[region].img_words = 0u;
        g_regions[region].img_cols  = 0u;
    }
    /* EFP_IMG_WORDS/IMG_DIGEST/IMG_SIG still hold the last staged image. */
    if ((emri_read(EMRI_EFP_IMG_WORDS_WORD) & 0xFFFFu) != (uint32_t)g_last_words) {
        fail(EFP_ERR_IMG_LEN_MISMATCH);
        return;
    }
    if (g_last_packed != 0u) {
        do_run_packed(region);
    } else {
        do_run(region);
    }
}

/* abort: best-effort BLANK of running regions, state IDLE (sec 3.2). */
static void do_abort(void)
{
    for (uint32_t i = 0u; i < DAEMON_NUM_REGIONS; i++) {
        if (g_regions[i].state == REGION_RUNNING) {
            if (g_regions[i].img_cols != 0u) {
                (void)occ_blank_packed((uint8_t)i, g_regions[i].img_cols,
                                       g_regions[i].img_words);
            } else {
                (void)occ_blank_region((uint8_t)i, g_regions[i].img_words);
            }
            g_regions[i].state     = REGION_FREE;
            g_regions[i].img_words = 0u;
            g_regions[i].img_cols  = 0u;
        }
    }
    g_done = 0u;
    set_state(EFP_S_IDLE);      /* busy stays 1; the dispatcher clears it */
    uart_puts("st IDLE\n");
}

/* ------------------------------------------------------------------ */
/* Doorbell loop. The EFP-SPI front-end (efp-spi/, E1-IO1) is serviced  */
/* from this loop and from occ_wait_done: its frames write the SAME     */
/* EMRI window regs an AXI host would (shared regfile, sec 3.2/7.1).    */
/* The transport-CRC16 gate (sec 7.1 step 5) runs between the last      */
/* column's LOAD and READBACK: EFP_SPI_CRC_ERR -> re-BLANK +            */
/* EFP_ERR=crc_transport (8), never RUNNING; CRC-less sessions (AXI     */
/* host path) are unaffected.                                           */
/* ------------------------------------------------------------------ */
void daemon_init(void)
{
    for (uint32_t i = 0u; i < DAEMON_NUM_REGIONS; i++) {
        g_regions[i].state     = REGION_FREE;
        g_regions[i].img_words = 0u;
        g_regions[i].img_cols  = 0u;
    }
    g_last_region = 0u;
    g_last_words  = 0u;
    g_staged      = 0u;
    g_last_packed = 0u;
    g_state = EFP_S_IDLE;
    g_busy  = 0u;
    g_done  = 0u;
    emri_write(EMRI_EFP_CMD_WORD, EFP_CMD_NOP);
    emri_write(EMRI_EFP_ERR_WORD, EFP_ERR_NONE);
    efp_status_sync();
}

void daemon_spin(void)
{
    for (;;) {
        uint32_t cmd = emri_read(EMRI_EFP_CMD_WORD) & 0xFFu;
        if (cmd == EFP_CMD_NOP) {
            efp_spi_service();  /* EFP-SPI front-end (E1-IO1, sec 7) */
            continue;
        }
        /* EFP-SPI (sec 7.1): finish delivering any pending response BEFORE
         * the command's CPU-bound phases (VERIFY) starve the depth-1 SDI TX
         * path — the SPI host is clocking poll frames waiting for exactly
         * that response, so this converges in one host frame. Then resync
         * the frame assembler at the command boundary. No-ops for the AXI
         * host path (nothing pending). */
        efp_spi_drain();
        efp_spi_resync();
        /* Accept: clear the doorbell (daemon write, sec 3.2) and clear the
         * sticky error; mark busy. */
        emri_write(EMRI_EFP_CMD_WORD, EFP_CMD_NOP);
        set_err(EFP_ERR_NONE);
        g_done = 0u;
        g_busy = 1u;
        efp_status_sync();
        uint8_t region_sel = (uint8_t)(emri_read(EMRI_EFP_REGION_WORD) & 0xFFu);

        switch (cmd) {
        case EFP_CMD_RUN:
            uart_puts("cmd run\n");
            do_run(region_sel);
            break;
        case EFP_CMD_STOP:
            uart_puts("cmd stop\n");
            do_stop(region_sel);
            break;
        case EFP_CMD_RESTART:
            uart_puts("cmd restart\n");
            do_restart();
            break;
        case EFP_CMD_ABORT:
            uart_puts("cmd abort\n");
            do_abort();
            break;
        case EFP_CMD_RUN_PACKED:
            uart_puts("cmd run_packed\n");
            do_run_packed(region_sel);
            break;
        default:
            fail(EFP_ERR_BAD_CMD);
            break;
        }

        /* Doorbell-while-busy squelch (sec 3.2): a command written while
         * busy is ignored and flagged bad_cmd. Checked BEFORE busy clears:
         * a compliant host writes EFP_CMD only after reading busy=0, which
         * is strictly after this point, so a non-NOP sample here can only
         * be a while-busy write. */
        if ((emri_read(EMRI_EFP_CMD_WORD) & 0xFFu) != EFP_CMD_NOP) {
            emri_write(EMRI_EFP_CMD_WORD, EFP_CMD_NOP);
            if ((emri_read(EMRI_EFP_ERR_WORD) & 0xFFu) == EFP_ERR_NONE) {
                set_err(EFP_ERR_BAD_CMD);
            }
        }
        g_busy = 0u;
        efp_status_sync();
    }
}
