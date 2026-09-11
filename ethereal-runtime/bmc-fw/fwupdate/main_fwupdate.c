/* SPDX-License-Identifier: MIT */
/*
 * main_fwupdate.c — E1-BMC2 dual-partition self-update demo entry point
 * (SIM-SCOPED firmware variant; emri-v0.md sec 3.6, v0.4).
 *
 * Boot: UART banner, then the boot stub (fwupdate_boot: pick ACTIVE slot,
 * CRC32-verify with last-known-good fallback, XIP jump), then the update
 * server doorbell loop (fwupdate_server). The production daemon firmware
 * (main.c) is UNCHANGED and answers EFP_CMD=6/7 with bad_cmd.
 *
 * G1: no dynamic memory. Bare-metal rv32imc.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.4/3.6 (v0.4);
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2.
 */
#include "drivers/uart.h"
#include "fwupdate/fwupdate.h"

int main(void)
{
    uart_init();
    uart_puts("bmc-fw fwupdate demo boot\n");

    fwupdate_boot();      /* slot select + CRC + XIP jump (returns) */
    fwupdate_server();    /* doorbell loop; never returns */
    return 0;
}
