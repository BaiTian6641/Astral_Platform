/* SPDX-License-Identifier: MIT */
/*
 * spi_none.c — no-op EFP-SPI front-end for the E2-AST1 scripted-deployment
 * firmware variant (SIM-SCOPED).
 *
 * WHY: this variant links the production daemon (daemon/daemon.c), whose
 * idle loop, OCC done-wait and sec 7.1 transport-CRC gate call the EFP-SPI
 * poll hooks. The demo it drives uses the AXI host path only (the SDI pins
 * are tied off in tb_bmc_script), and the 16 KiB sim DMEM cannot hold the
 * real front-end (efp-spi/ + sdi.o = 1144 B of code) AND the ~2 KiB Ed25519
 * verify stack the scripted deploy needs on top of the daemon's footprint:
 * with the front-end linked, the variant hard-faults (trap to mtvec -> reboot)
 * inside eth_ed25519_verify because its image leaves only 1808 B of stack.
 * Dropping it restores ~1.1 KiB of headroom (measured: image 14456 B -> 13312 B
 * of the 16 KiB DMEM).
 * To restore the front-end, swap spi_none.o back to sdi.o + efp_spi.o in the
 * Makefile's SCRIPT_OBJS — and give the core a larger DMEM first.
 * (Same sim-scope convention as the E1-BMC2 fwupdate variant, which links no
 * EFP-SPI either.)
 *
 * Semantics: a CRC-less session (EFP_SPI_CRC_NONE) is exactly what the
 * daemon's sec 7.1 gate expects from a pure AXI host, so the no-ops preserve
 * the AXI-host behavior of the daemon's command path.
 *
 * G1: no dynamic memory.
 *
 * Plan-Ref: ethereal-spec/control/emri-v0.md §7/§7.1;
 *           ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3.
 */
#include "efp-spi/efp_spi.h"

void efp_spi_init(void)
{
    /* no EFP-SPI front-end in this variant */
}

void efp_spi_service(void)
{
    /* no EFP-SPI front-end in this variant */
}

void efp_spi_drain(void)
{
    /* no EFP-SPI front-end in this variant */
}

void efp_spi_resync(void)
{
    /* no EFP-SPI front-end in this variant */
}

uint8_t efp_spi_crc_state(void)
{
    return EFP_SPI_CRC_NONE; /* AXI-host path: no transport-CRC session */
}
