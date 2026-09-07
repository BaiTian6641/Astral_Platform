/* SPDX-License-Identifier: MIT */
/*
 * sdi.c — NEORV32 SDI (SPI device) CSR driver (E1-IO1). See sdi.h.
 */
#include "efp-spi/sdi.h"

void sdi_init(void)
{
    /* EN + flush in one write: the CLR bits are self-clearing write pulses;
     * EN must be reasserted on every CTRL write or the module switches off. */
    SDI_CTRL = SDI_CTRL_EN | SDI_CTRL_CLR_RX | SDI_CTRL_CLR_TX;
}
