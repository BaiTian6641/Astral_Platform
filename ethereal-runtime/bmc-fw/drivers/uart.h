/* SPDX-License-Identifier: MIT */
/*
 * uart.h — minimal NEORV32 UART0 driver for bmc-fw (E1-BMC2).
 *
 * NEORV32 UART0 register map (fabric clock domain):
 *   CTRL @ 0x00 : bit0 = enable, bit19 = TX FIFO not-full (TX_NFULL)
 *   DATA @ 0x04 : [7:0] = TX/RX data
 * Base 0xFFF50000 (IO region). No dynamic memory; polled TX (bare-metal).
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2,
 *           ethereal-plan/components/C05-BMC组件.md.
 */
#ifndef BMC_FW_UART_H
#define BMC_FW_UART_H

#include <stdint.h>

#define UART0_BASE      ((uintptr_t)0xFFF50000u)
#define UART0_CTRL      (*(volatile uint32_t *)(UART0_BASE + 0x00u))
#define UART0_DATA      (*(volatile uint32_t *)(UART0_BASE + 0x04u))

#define UART_CTRL_EN        (1u << 0)
#define UART_CTRL_TX_NFULL  (1u << 19)

void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);
void uart_puthex32(uint32_t v);

#endif /* BMC_FW_UART_H */
