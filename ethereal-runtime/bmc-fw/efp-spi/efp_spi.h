/* SPDX-License-Identifier: MIT */
/*
 * efp_spi.h — EFP-SPI front-end for bmc-fw (E1-IO1): emri-v0.md §7 frame
 * decode over the NEORV32 SDI, translating host SPI frames into the SAME
 * EMRI window accesses an AXI host would make (shared-regfile design: the
 * §3.2 write-roles note applies to this front-end as "host").
 *
 * Service model: polled. efp_spi_service() is called from the daemon's poll
 * loops (doorbell + OCC done-wait); it is non-blocking between SPI bytes and
 * blocks at most one EMRI window access when a complete frame is processed.
 * The daemon reads the transport-CRC result via efp_spi_crc_state() (the
 * §7.1 step-5 gate).
 *
 * G1: no dynamic memory (static frame/CRC state only).
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md §7/§7.1.
 */
#ifndef BMC_FW_EFP_SPI_EFP_SPI_H
#define BMC_FW_EFP_SPI_EFP_SPI_H

#include <stdint.h>

/* Transport-CRC session states (spec §7.1; SPI_CRC RD debug state[1:0]). */
#define EFP_SPI_CRC_NONE    0u  /* CRC-less session (no SPI_CRC latch)      */
#define EFP_SPI_CRC_COLLECT 1u  /* accumulating; comparison pending         */
#define EFP_SPI_CRC_OK      2u  /* stream matched the latched CRC16         */
#define EFP_SPI_CRC_ERR     3u  /* mismatch: daemon gate fails the command  */

/* Init the SDI + link state; call once at boot (CS idle). */
void efp_spi_init(void);

/* Poll the SDI: CS-aware frame assembly, response TX feeding, frame
 * execution. Call frequently (daemon poll loops). */
void efp_spi_service(void);

/* Daemon transport-CRC gate (spec §7.1 step 5): EFP_SPI_CRC_* state of the
 * current session. NONE/OK/COLLECT proceed; ERR fails crc_transport. */
uint8_t efp_spi_crc_state(void);

/* Nonzero while a response is mid-delivery (pending or armed-unpopped). */
uint8_t efp_spi_busy(void);

/* Service the SDI until any pending response is fully delivered. The daemon
 * calls this at EFP_CMD accept (the SPI host is clocking poll frames waiting
 * for exactly that response) so the long CPU-bound VERIFY cannot split the
 * depth-1 TX delivery. No-op on the AXI host path. */
void efp_spi_drain(void);

/* Re-sync the frame assembler at a command boundary (drops the at-most-one
 * stale RX byte the depth-1 FIFO can hold after a CPU-away window). */
void efp_spi_resync(void);

#endif /* BMC_FW_EFP_SPI_EFP_SPI_H */
