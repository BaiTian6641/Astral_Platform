/* SPDX-License-Identifier: MIT */
/*
 * main_script.c — E2-AST1 MCU scripted-deployment firmware entry point
 * (SIM-SCOPED variant; emri-v0.md sec 3.6 convention for sim-demo commands).
 *
 * Boot: UART banner, EMRI identity probe, EFP-SPI front-end init, then the
 * PRODUCTION daemon poll loop (daemon_spin) with the EFP_CMD_SCRIPT
 * extension handler registered (script_register) — i.e. this firmware is the
 * daemon plus a firmware-side script interpreter. A host stages a signed
 * image (spec sec 3.2 step 1) and rings EFP_CMD=SCRIPT with EFP_REGION = the
 * flash script slot; the BMC then deploys/probes/marks/stops it on its own.
 *
 * Without script_register() the same daemon answers EFP_CMD_SCRIPT with
 * bad_cmd, which is what the production firmware (main.c) does — the exact
 * convention sec 3.6 uses for FWUPDATE/REBOOT.
 *
 * G1: no dynamic memory. Bare-metal rv32imc. -Wall -Wextra -Werror clean.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2/§3.6;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3;
 *           ethereal-plan/phases/phase-2-异构与双平台.md §3 (circuit-breaker).
 */
#include "drivers/uart.h"
#include "drivers/emri.h"
#include "efp-spi/efp_spi.h"
#include "daemon/daemon.h"
#include "script/script.h"

int main(void)
{
    uart_init();
    uart_puts("bmc-fw script deploy demo boot\n");

    /* EMRI identity probe (same chain as main.c). */
    uint32_t magic = emri_read(EMRI_MAGIC_WORD);
    uint32_t cap   = emri_read(EMRI_CAP_WORD);
    uart_puts("EMRI MAGIC=");
    uart_puthex32(magic);
    uart_puts(" CAP=");
    uart_puthex32(cap);
    uart_puts("\n");

    efp_spi_init();   /* no-op stub: this variant has no EFP-SPI front-end */
    uart_puts("efp-spi none (sim variant)\n");

    daemon_init();
    script_register();
    uart_puts("daemon ready (script deploy)\n");
    daemon_spin();   /* the production loop; never returns */
    return 0;
}
