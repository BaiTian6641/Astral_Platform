/* SPDX-License-Identifier: MIT */
/*
 * uart.c — minimal NEORV32 UART0 driver for bmc-fw (E1-BMC2).
 * Polled TX (bare-metal, no IRQ); no dynamic memory.
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2.
 */
#include "uart.h"

void uart_init(void)
{
    /* Enable UART0 (PRSC=0, BAUD=0 -> fastest; matches the sim skeleton). */
    UART0_CTRL = UART_CTRL_EN;
}

void uart_putc(char c)
{
    /* Spin while the TX FIFO is full (TX_NFULL==0 means full). */
    while ((UART0_CTRL & UART_CTRL_TX_NFULL) == 0u) {
        /* busy-wait */
    }
    UART0_DATA = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

void uart_puthex32(uint32_t v)
{
    static const char hexdig[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hexdig[(v >> i) & 0xFu]);
    }
}

void uart_puthex16(uint32_t v)
{
    static const char hexdig[] = "0123456789ABCDEF";
    for (int i = 12; i >= 0; i -= 4) {
        uart_putc(hexdig[(v >> i) & 0xFu]);
    }
}

void uart_puthex8(uint32_t v)
{
    static const char hexdig[] = "0123456789ABCDEF";
    uart_putc(hexdig[(v >> 4) & 0xFu]);
    uart_putc(hexdig[v & 0xFu]);
}
