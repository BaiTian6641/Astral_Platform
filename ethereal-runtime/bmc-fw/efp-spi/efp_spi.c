/* SPDX-License-Identifier: MIT */
/*
 * efp_spi.c — EFP-SPI front-end (E1-IO1): emri-v0.md §7 7-byte request/
 * response frames over the NEORV32 SDI + §7.1 CRC16 transport integrity.
 *
 * Link realization (spec §7.1 "link convention"), SDI FIFO depth = 1:
 *   - CS-low delimits ONE BYTE (8-bit frames with CS): the SDI pops the TX
 *     FIFO at byte completion and reloads the shift register 3 fabric clocks
 *     later, so with a depth-1 FIFO the CPU cannot sustain back-to-back
 *     bytes inside one CS pulse — the host pulses CS per byte and the
 *     firmware re-arms the TX FIFO whenever it is empty.
 *   - A §7 "frame" = 7 byte-pulses: {OP, ADDR[15:8], ADDR[7:0], DATA BE32}.
 *     RX is drained per byte (CPU has a whole byte period; depth 1 is fine).
 *   - Pipelined responses at BYTE granularity: while receiving request frame
 *     N the device shifts out the response to frame N-1 (resp[0] arms as soon
 *     as frame N-1 is processed), or 0xFF fill bytes ("not ready — retry")
 *     when no response is pending. TX-empty hardware fill is 0x00, so the
 *     host treats both 0xFF and any wrong-ADDR-echo as "retry".
 *   - Frame-boundary re-sync: with no RX byte for >RX_IDLE_RESET serviced
 *     CS-high gaps the assembler resets (inter-byte gaps are short, the
 *     inter-frame gap is long — Modbus-RTU-style delimiter). The daemon also
 *     resyncs the assembler at every EFP_CMD accept (before VERIFY starves
 *     the SDI), and drains any pending response first (efp_spi_drain) — the
 *     SPI host is clocking poll frames waiting for exactly that response.
 *   - Host discipline (what makes this safe with a polled depth-1 link):
 *     strictly one request in flight; retry/poll frames are the ALL-ZERO
 *     RD-MAGIC frame, so a misassembled frame after a CPU-away window
 *     (Ed25519 VERIFY) is always a harmless RD MAGIC; WR/OCC_PUSH requests
 *     are re-issued only when the device provably never saw them (a response
 *     to a LATER poll arrived first — responses are delivered in order).
 *
 * OP handling: RD/WR = single EMRI window access (drivers/emri.h — the SAME
 * AXI path the daemon uses); OCC_PUSH = OCC_WDATA passthrough + CRC16
 * accumulate; BLOCK_RD = BAD_OP (v0); WR 0x3F (SPI_CRC) = latch the expected
 * CRC16 (intercepted, not regfile storage); RD 0x3F = CRC debug readback.
 * BUSY(0x03) is unused in v0 (single outstanding request, see spec note).
 *
 * CRC16 session (spec §7.1): CCITT-FALSE (poly 0x1021, init 0xFFFF, no final
 * xor) over the big-endian bytes of each OCC_PUSH payload word — identical to
 * frame_map.crc16 (== the packed frame's own CRC16 tail word). WR EFP_CMD
 * (any code) resets accumulator/count and snapshots the session word total
 * (EFP_IMG_WORDS x EFP_IMG_COLS for run_packed, x1 for run); the comparison
 * completes when the push count reaches the total (before the OCC's last
 * completion flag, so the daemon gate never waits). While EFP_SPI_CRC_ERR is
 * latched every response carries STATUS=0x04 (CRC_ERR) — RDs still return
 * data — until the next EFP_CMD write.
 *
 * WARNING (v0, per §7 OCC_PUSH note): an OCC_PUSH while the OCC is not armed
 * stalls on the regfile wdata skid backpressure — the host streams only while
 * the daemon is in LOAD (§3.3 step 3), same discipline as the AXI host path.
 *
 * G1: no dynamic memory; all state static. -Wall -Wextra -Werror clean.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md §7/§7.1/§3.2/§3.3.
 */
#include "efp-spi/efp_spi.h"
#include "efp-spi/sdi.h"
#include "drivers/emri.h"
#include "daemon/daemon.h"

/* ------------------------------------------------------------------ */
/* §7 opcodes / status bytes (mirror emri_pkg.sv / emri_constants.py)  */
/* ------------------------------------------------------------------ */
#define SPI_OP_RD       0x00u
#define SPI_OP_WR       0x01u
#define SPI_OP_BLOCK_RD 0x02u
#define SPI_OP_OCC_PUSH 0x03u

#define SPI_STAT_OK      0x00u
#define SPI_STAT_BAD_OP  0x01u
#define SPI_STAT_BAD_ADDR 0x02u
/* 0x03 BUSY unused in v0 (single outstanding request; spec §7.1). */
#define SPI_STAT_CRC_ERR 0x04u
#define SPI_FILL_NOT_READY 0xFFu  /* "no response ready — retry" (§7.1) */

#define SPI_FRAME_LEN   7u
#define EMRI_WIN_LAST   0x5Fu     /* window covers 0x00..0x5F (96 words) */

/* Frame-boundary re-sync: this many serviced CS-high gaps without an RX byte
 * reset the assembler. Far above the inter-byte gap (a few service loops;
 * ~13 even inside the back-to-back efp_spi_drain), far below the host's
 * inter-frame gap (§7.1 link convention: 50 µs = ~50 daemon-poll services). */
#define RX_IDLE_RESET   25u

/* ------------------------------------------------------------------ */
/* Link state (static)                                                 */
/* ------------------------------------------------------------------ */
static uint8_t  rx_buf[SPI_FRAME_LEN]; /* request being assembled        */
static uint32_t rx_idx;
static uint32_t rx_idle;               /* serviced CS-high gaps, no byte */

static uint8_t  resp[SPI_FRAME_LEN];   /* response being delivered       */
static uint32_t resp_idx;              /* next byte to arm               */
static uint8_t  resp_pend;             /* resp[0..6] not all armed yet   */
static uint8_t  resp_armed;            /* a resp byte armed, not popped  */
static uint32_t build_seq;             /* ++ per response built          */
static uint32_t done_seq;              /* ++ per response settled (fully
                                        * delivered, or replaced mid-way) */

/* ------------------------------------------------------------------ */
/* CRC16 transport-integrity session state (spec §7.1)                 */
/* ------------------------------------------------------------------ */
static uint16_t crc_acc;
static uint16_t crc_expected;
static uint8_t  crc_armed;             /* SPI_CRC latched, awaiting cmd  */
static uint32_t push_count;
static uint32_t crc_total;             /* words x cols snapshot at cmd   */
static uint8_t  crc_state;             /* EFP_SPI_CRC_*                  */

uint8_t efp_spi_crc_state(void)
{
    return crc_state;
}

/* CRC-16/CCITT-FALSE over the 4 big-endian bytes of one payload word
 * (frame_map.crc16 identical). */
static uint16_t crc16_word(uint16_t crc, uint32_t w)
{
    for (int32_t s = 24; s >= 0; s -= 8) {
        crc = (uint16_t)(crc ^ (uint16_t)(((w >> s) & 0xFFu) << 8));
        for (uint32_t b = 0u; b < 8u; b++) {
            uint16_t shifted = (uint16_t)(crc << 1);
            crc = (uint16_t)((crc & 0x8000u) != 0u ? (shifted ^ 0x1021u)
                                                   : shifted);
        }
    }
    return crc;
}

/* EFP_CMD write (any code) = session boundary (spec §7.1 step 2). */
static void crc_session_reset(uint32_t cmd)
{
    uint32_t words = emri_read(EMRI_EFP_IMG_WORDS_WORD) & 0xFFFFu;
    uint32_t cols  = emri_read(EMRI_EFP_IMG_COLS_WORD) & 0xFFu;
    crc_acc   = 0xFFFFu;
    push_count = 0u;
    crc_total = words * ((cmd == EFP_CMD_RUN_PACKED && cols != 0u) ? cols : 1u);
    crc_state = (crc_armed != 0u) ? EFP_SPI_CRC_COLLECT : EFP_SPI_CRC_NONE;
    crc_armed = 0u;  /* one-shot: consumed by this command */
}

/* ------------------------------------------------------------------ */
/* Frame execution -> EMRI window access (shared regfile, §3.2 host    */
/* role). Builds resp[].                                               */
/* ------------------------------------------------------------------ */
static void process_frame(void)
{
    uint32_t op   = rx_buf[0];
    uint32_t addr = ((uint32_t)rx_buf[1] << 8) | (uint32_t)rx_buf[2];
    uint32_t data = ((uint32_t)rx_buf[3] << 24) | ((uint32_t)rx_buf[4] << 16) |
                    ((uint32_t)rx_buf[5] << 8) | (uint32_t)rx_buf[6];
    uint8_t  status = SPI_STAT_OK;
    uint32_t rdata  = 0u;

    /* Sticky CRC_ERR surfaces on every response until the next EFP_CMD write
     * (spec §7.1 step 6): RDs still return their data; EFP_CMD writes still
     * execute (they clear the condition); ALL other writes/pushes are
     * suppressed — a failed session's tail (or a resent frame) must not touch
     * the regfile/OCC after the daemon gate has fired. */
    uint8_t crc_blocked = 0u;
    if (crc_state == EFP_SPI_CRC_ERR) {
        status = SPI_STAT_CRC_ERR;
        if (op != SPI_OP_RD &&
            !(op == SPI_OP_WR && addr == EMRI_EFP_CMD_WORD)) {
            crc_blocked = 1u;
        }
    }

    switch (op) {
    case SPI_OP_RD:
        if (addr == EMRI_SPI_CRC_WORD) {
            rdata = ((uint32_t)crc_state << 16) | (uint32_t)crc_acc;
        } else if (addr <= EMRI_WIN_LAST) {
            rdata = emri_read(addr);
        } else {
            status = (status == SPI_STAT_OK) ? SPI_STAT_BAD_ADDR : status;
        }
        break;
    case SPI_OP_WR:
        if (crc_blocked != 0u) {
            break;  /* CRC_ERR latched: suppressed (§7.1 step 6) */
        }
        if (addr == EMRI_SPI_CRC_WORD) {
            crc_expected = (uint16_t)(data & 0xFFFFu);
            crc_armed = 1u;
        } else if (addr <= EMRI_WIN_LAST) {
            emri_write(addr, data);
            if (addr == EMRI_EFP_CMD_WORD) {
                crc_session_reset(data & 0xFFu);
            }
        } else {
            status = (status == SPI_STAT_OK) ? SPI_STAT_BAD_ADDR : status;
        }
        break;
    case SPI_OP_OCC_PUSH:
        if (crc_blocked != 0u) {
            break;  /* CRC_ERR latched: suppressed (§7.1 step 6) */
        }
        if (addr != EMRI_OCC_WDATA_WORD) {
            status = (status == SPI_STAT_OK) ? SPI_STAT_BAD_ADDR : status;
            break;
        }
        /* Session word-count guard (§7.1 step 4): a push beyond the staged
         * session total can never belong to this frame — a resent frame the
         * device cannot distinguish from a host bug. Answer BUSY and do NOT
         * forward: the OCC was armed for exactly crc_total words, so
         * forwarding would overfeed the frame (or hard-block the regfile
         * wdata skid once the OCC completed). CRC-less sessions (total==0)
         * forward freely, mimicking the AXI host path. */
        if (crc_state != EFP_SPI_CRC_NONE && crc_total != 0u &&
            push_count >= crc_total) {
            status = (status == SPI_STAT_OK) ? 0x03u /* BUSY */ : status;
            break;
        }
        /* Accumulate BEFORE the (potentially blocking) OCC_WDATA write: the
         * comparison then strictly precedes the OCC completion the daemon
         * waits on (spec §7.1 step 4). */
        if (crc_state == EFP_SPI_CRC_COLLECT) {
            crc_acc = crc16_word(crc_acc, data);
            push_count++;
            if (push_count == crc_total && crc_total != 0u) {
                crc_state = (crc_acc == crc_expected) ? EFP_SPI_CRC_OK
                                                      : EFP_SPI_CRC_ERR;
            }
        }
        emri_write(EMRI_OCC_WDATA_WORD, data);
        break;
    case SPI_OP_BLOCK_RD:
    default:
        status = (status == SPI_STAT_OK) ? SPI_STAT_BAD_OP : status;
        break;
    }

    /* A still-undelivered previous response is replaced (only reachable when
     * the host abandoned it — protocol violation — or for the stale MAGIC
     * tail after a CPU-away window; §7.1 retry recovers either way). Count it
     * settled so build_seq/done_seq stay paired for efp_spi_drain. */
    if (resp_pend != 0u || resp_armed != 0u) {
        SDI_CTRL = SDI_CTRL_EN | SDI_CTRL_CLR_TX;
        resp_armed = 0u;
        resp_pend  = 0u;
        done_seq++;
    }
    resp[0] = status;
    resp[1] = rx_buf[1];
    resp[2] = rx_buf[2];
    resp[3] = (uint8_t)(rdata >> 24);
    resp[4] = (uint8_t)(rdata >> 16);
    resp[5] = (uint8_t)(rdata >> 8);
    resp[6] = (uint8_t)(rdata);
    resp_pend = 1u;
    build_seq++;
    /* Displace any armed FILL byte (worthless) so the NEXT byte pulse already
     * shifts resp[0] — the shifter loads the FIFO head at CS fall, long
     * before a polled CPU could react. If a pulse is mid-shift this touches
     * only the FIFO, never the shift register. */
    SDI_CTRL = SDI_CTRL_EN | SDI_CTRL_CLR_TX;
    SDI_DATA = (uint32_t)resp[0];
    resp_idx   = 1u;
    resp_armed = 1u;
}

/* ------------------------------------------------------------------ */
/* Polled link service                                                 */
/* ------------------------------------------------------------------ */
void efp_spi_service(void)
{
    uint32_t ctrl = SDI_CTRL;

    /* Pop tracking FIRST: a TX FIFO that reads empty has had its armed byte
     * pulled by the shifter since the last visit (response bytes are pushed
     * only by process_frame's displacement and by the fill branch below, so
     * empty-at-entry means the previous byte went on the wire). */
    if ((ctrl & SDI_CTRL_TX_EMPTY) != 0u && resp_armed != 0u) {
        resp_armed = 0u;
        if (resp_pend == 0u) {
            done_seq++;  /* the response's last byte was delivered */
        }
    }

    /* RX: drain the byte (depth-1 FIFO, one byte period of slack). */
    if ((ctrl & SDI_CTRL_RX_EMPTY) == 0u) {
        rx_buf[rx_idx] = (uint8_t)(SDI_DATA & 0xFFu);
        rx_idx++;
        rx_idle = 0u;
        if (rx_idx == SPI_FRAME_LEN) {
            rx_idx = 0u;
            process_frame();
        }
    } else if ((ctrl & SDI_CTRL_CS_ACTIVE) == 0u) {
        /* CS-high gap without a byte: count towards the frame delimiter. */
        if (rx_idle < 0xFFFFFFFFu) {
            rx_idle++;
        }
        if (rx_idle > RX_IDLE_RESET) {
            rx_idx = 0u;  /* inter-frame gap: realign the assembler */
        }
    } else {
        /* CS low, byte in flight: nothing to do. */
    }

    /* TX: refill the FIFO (response bytes in order, else 0xFF fill). After
     * process_frame's displacement the FIFO is never empty with an unarmed
     * response pending, so a fill push here means genuinely nothing to say. */
    if ((SDI_CTRL & SDI_CTRL_TX_EMPTY) != 0u) {
        if (resp_pend != 0u) {
            SDI_DATA = (uint32_t)resp[resp_idx];
            resp_idx++;
            resp_armed = 1u;
            if (resp_idx == SPI_FRAME_LEN) {
                resp_pend = 0u;
            }
        } else {
            SDI_DATA = (uint32_t)SPI_FILL_NOT_READY;
        }
    }
}

/* A response is mid-delivery (pending arm or armed-but-unpopped). */
uint8_t efp_spi_busy(void)
{
    return (uint8_t)(resp_pend != 0u || resp_armed != 0u);
}

/* Drain the responses that exist AT ENTRY (the SPI host is clocking poll
 * frames waiting for the command response) — called by the daemon before a
 * command's long CPU-bound phases (VERIFY) would starve the depth-1 TX path
 * and split the delivery. Responses built by poll frames DURING the drain do
 * not extend it (sequence-targeted). Bounded: a host that stops clocking
 * degrades to a split response (its §7.1 retry re-issues), never a hang.
 * No-op on the AXI host path (nothing pending). */
void efp_spi_drain(void)
{
    uint32_t target = build_seq;
    uint32_t bound  = 1000000u;  /* ~10 ms at 100 MHz; delivery needs ~36 µs */
    while (done_seq < target && bound != 0u) {
        efp_spi_service();
        bound--;
    }
}

/* Re-sync the frame assembler at a command boundary (drops the at-most-one
 * stale RX byte the depth-1 FIFO may hold after a CPU-away window). */
void efp_spi_resync(void)
{
    rx_idx  = 0u;
    rx_idle = 0u;
    SDI_CTRL = SDI_CTRL_EN | SDI_CTRL_CLR_RX;
}

void efp_spi_init(void)
{
    rx_idx = 0u;
    rx_idle = 0u;
    resp_idx = 0u;
    resp_pend = 0u;
    resp_armed = 0u;
    build_seq = 0u;
    done_seq = 0u;
    crc_acc = 0xFFFFu;
    crc_expected = 0u;
    crc_armed = 0u;
    push_count = 0u;
    crc_total = 0u;
    crc_state = EFP_SPI_CRC_NONE;
    sdi_init();
}
