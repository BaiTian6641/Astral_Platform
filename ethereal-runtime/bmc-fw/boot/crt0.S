# SPDX-License-Identifier: MIT
#
# crt0.S — bmc-fw startup for the NEORV32 BMC core (E1-BMC2, boot-from-ROM).
#
# NEORV32 reset jumps to mtvec = IMEM base (0x00000000); link.ld places
# .text.crt0 first so _start lands at 0x0. This does the minimal C runtime
# setup: set the stack pointer (top of DMEM), copy .data (ROM->RAM), clear
# .bss, then call main(). main() returning parks the core in a wfi loop.
#
# Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2 (boot),
#           ethereal-plan/components/C05-BMC组件.md.
#
# G1: no dynamic memory; bare-metal; -march=rv32imc -mabi=ilp32.

    .section .text.crt0
    .globl  _start
    .type   _start, @function

_start:
    /* Set up the stack pointer to the top of DMEM. */
    lui     sp, %hi(__stack_top)
    addi    sp, sp, %lo(__stack_top)

    /* Copy initialized .data from ROM (LMA) to RAM (VMA). */
    lui     a0, %hi(__data_lma)     /* src = ROM LMA */
    addi    a0, a0, %lo(__data_lma)
    lui     a1, %hi(__data_start)   /* dst = RAM VMA */
    addi    a1, a1, %lo(__data_start)
    lui     a2, %hi(__data_end)     /* end */
    addi    a2, a2, %lo(__data_end)
1:  beq     a1, a2, 2f
    lw      a3, 0(a0)
    sw      a3, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    beq     x0, x0, 1b
2:

    /* Clear .bss. */
    lui     a1, %hi(__bss_start)
    addi    a1, a1, %lo(__bss_start)
    lui     a2, %hi(__bss_end)
    addi    a2, a2, %lo(__bss_end)
3:  beq     a1, a2, 4f
    sw      x0, 0(a1)
    addi    a1, a1, 4
    beq     x0, x0, 3b
4:

    /* Call main. */
    call    main

    /* main returned: park the core (idle). */
5:  wfi
    beq     x0, x0, 5b

    .size   _start, .-_start
