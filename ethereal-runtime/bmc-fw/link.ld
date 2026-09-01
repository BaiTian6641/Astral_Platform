/* SPDX-License-Identifier: MIT */
/*
 * link.ld — bmc-fw linker script for the NEORV32 BMC core (E1-RUN2,
 *           DMEM-exec sim bootstrap).
 *
 * Memory map (must match ethereal-shell/rtl/bmc/bmc_core.sv):
 *   IMEM (ROM, boot)  : ORIGIN 0x00000000, 1 KiB physical in the vendored
 *                       GHDL netlist (imem_rom reads addr_i[9:2] — 256 words;
 *                       the "16 KB" wrapper label is the configured, not the
 *                       realized, size). Holds ONLY the .boot stub (crt0).
 *   DMEM (RAM)        : ORIGIN 0x80000000, 16 KiB. Holds the whole firmware
 *                       (.text/.rodata/.data/.bss + stack); the testbench
 *                       backdoor-preloads .text/.rodata/.data into DMEM and
 *                       the boot stub jumps here (see crt0.S BOOTSTRAP NOTE).
 *   IO                : 0xFFE00000+ (UART0 @ 0xFFF50000)
 *   mtvec             : IMEM base 0x00000000 (NEORV32 reset = IMEM base)
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2,
 *           ethereal-plan/components/C05-BMC组件.md.
 */

OUTPUT_ARCH("riscv")
OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 1K
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 16K
}

SECTIONS
{
    /* Boot stub: the only ROM-resident code (fits the 1 KiB physical ROM). */
    .boot : {
        *(.text.crt0)      /* entry first */
        . = ALIGN(4);
    } > ROM

    /* Code + read-only data + initialized data all live in DMEM (RAM),
     * backdoor-preloaded by the testbench (no ROM->RAM copy in crt0). */
    . = ALIGN(4);
    .text : {
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        . = ALIGN(4);
    } > RAM

    . = ALIGN(4);
    .data : {
        . = ALIGN(4);
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
    } > RAM

    /* Zero-initialized data (crt0 clears; not part of the preload image). */
    . = ALIGN(4);
    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /* Stack grows down from the top of DMEM. */
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.eh_frame*) }
}
