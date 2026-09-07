/* SPDX-License-Identifier: MIT */
/*
 * sdi.h — NEORV32 SDI (SPI device) CSR driver for bmc-fw (E1-IO1 EFP-SPI).
 *
 * The SDI is the NEORV32 SPI *device* peripheral: an external host drives
 * sdi_clk_i/sdi_csn_i/sdi_dat_i (MOSI), the core shifts out sdi_dat_o (MISO).
 * Byte-level transfers, MSB-first, mode 0 (no CPOL config bit at the vendored
 * commit). Releasing CS before 8 bits discards the partial byte.
 *
 * CSR map (base 0xFFF70000, NEORV32 IO region — internal, NOT over XBUS):
 *   CTRL @ 0x00 : bit0 EN, bit1 CLR_RX (w, self-clearing), bit2 CLR_TX (w),
 *                 bit24 RX_EMPTY (r), bit26 TX_EMPTY (r), bit31 CS_ACTIVE (r)
 *   DATA @ 0x04 : write pushes the TX FIFO (depth 1, IO_SDI_FIFO=1; TX empty
 *                 shifts out 0x00), read pops the RX FIFO.
 * (docs/datasheet/soc_sdi.adoc; report-E1-IO1-sdi-regen-20260902.md)
 *
 * G1: no dynamic memory. Polled (fast IRQ channel 11 deliberately unused in
 * v0 — the daemon interleaves efp_spi_service() in its poll loops).
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md §7/§7.1;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3.
 */
#ifndef BMC_FW_EFP_SPI_SDI_H
#define BMC_FW_EFP_SPI_SDI_H

#include <stdint.h>

#define SDI_BASE        ((uintptr_t)0xFFF70000u)
#define SDI_CTRL        (*(volatile uint32_t *)(SDI_BASE + 0x00u))
#define SDI_DATA        (*(volatile uint32_t *)(SDI_BASE + 0x04u))

#define SDI_CTRL_EN         (1u << 0)
#define SDI_CTRL_CLR_RX     (1u << 1)
#define SDI_CTRL_CLR_TX     (1u << 2)
#define SDI_CTRL_RX_EMPTY   (1u << 24)
#define SDI_CTRL_TX_EMPTY   (1u << 26)
#define SDI_CTRL_CS_ACTIVE  (1u << 31u)

/* Enable the SDI and flush both FIFOs (call once at boot, CS idle). */
void sdi_init(void);

/* Flush RX+TX FIFOs (EN stays set; CLR bits are self-clearing pulses). */
static inline void sdi_flush(void)
{
    SDI_CTRL = SDI_CTRL_EN | SDI_CTRL_CLR_RX | SDI_CTRL_CLR_TX;
}

#endif /* BMC_FW_EFP_SPI_SDI_H */
