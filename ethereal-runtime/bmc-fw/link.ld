/* SPDX-License-Identifier: MIT */
/*
 * link.ld — bmc-fw linker script for the NEORV32 BMC core (E1-BMC2).
 *
 * Memory map (must match ethereal-shell/rtl/bmc/bmc_core.sv):
 *   IMEM (ROM, boot)  : ORIGIN 0x00000000, 16 KiB  (BOOT_MODE_SELECT=2 -> boot here)
 *   DMEM (RAM)        : ORIGIN 0x80000000, 16 KiB
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
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 16K
}

SECTIONS
{
    /* Code + read-only data execute in place from ROM (IMEM). */
    .text : {
        *(.text.crt0)      /* entry first */
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        . = ALIGN(4);
    } > ROM

    /* Initialized data: VMA in RAM, LMA in ROM (crt0 copies ROM->RAM). */
    . = ALIGN(4);
    .data : AT(ADDR(.text) + SIZEOF(.text)) {
        . = ALIGN(4);
        __data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM
    __data_lma = LOADADDR(.data);

    /* Zero-initialized data (crt0 clears). */
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
