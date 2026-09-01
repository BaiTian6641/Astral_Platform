/* SPDX-License-Identifier: MIT */
/*
 * main.c — bmc-fw v0.2: E1-RUN2 daemon entry point.
 *
 * Boot: UART banner, one Ed25519 known-answer selftest (crypto/ed25519.h),
 * EMRI identity probe over the AXI management fabric (XBUS -> eth_wb2axi ->
 * xbar -> emri_axi_adapter -> emri_regfile), then the EFP daemon poll loop
 * (daemon/daemon.c, emri-v0.md sec 3.2): the host stages image metadata in
 * the EMRI window and rings EFP_CMD; the daemon verifies/allocates/loads and
 * reports via EFP_STATUS/EFP_ERR.
 *
 * G1: no dynamic memory (static state only). Bare-metal rv32imc.
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3,
 *           ethereal-spec/control/emri-v0.md §3.2.
 */
#include "drivers/uart.h"
#include "drivers/emri.h"
#include "crypto/ed25519.h"
#include "daemon/daemon.h"

int main(void)
{
    uart_init();
    uart_puts("bmc-fw v0.2 daemon boot\n");

    /* Crypto KAT once at boot (Ed25519 verify is the daemon's gate). */
    uart_puts("ed25519 selftest ");
    uart_puts(eth_ed25519_selftest() ? "OK\n" : "FAIL\n");

    /* EMRI identity probe: MAGIC + CAPABILITIES over the real AXI chain. */
    uint32_t magic = emri_read(EMRI_MAGIC_WORD);   /* expect 0x45544852 */
    uint32_t cap   = emri_read(EMRI_CAP_WORD);     /* expect 0x1 (has_bmc) */
    uart_puts("EMRI MAGIC=");
    uart_puthex32(magic);
    uart_puts(" CAP=");
    uart_puthex32(cap);
    uart_puts("\n");

    daemon_init();
    uart_puts("daemon ready\n");
    daemon_spin();   /* never returns */
    return 0;
}
