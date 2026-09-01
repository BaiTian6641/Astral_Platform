# SPDX-License-Identifier: MIT
#
# crt0.S — bmc-fw startup for the NEORV32 BMC core (E1-RUN2, DMEM-exec boot).
#
# NEORV32 reset jumps to mtvec = IMEM base (0x00000000); link.ld places
# .boot (this file) first so _start lands at 0x0. This stub sets the stack
# pointer (top of DMEM), clears .bss, then calls main() — which lives in
# DMEM, not IMEM:
#
#   BOOTSTRAP NOTE (2026-09-01): the vendored GHDL netlist's IMEM ROM is
#   physically 256 words / 1 KiB (imem_rom reads addr_i[9:2]; see
#   ethereal-shell/rtl/bmc/README.md) although the wrapper is labelled
#   "16 KB". The E1-RUN2 firmware (Ed25519 + SHA-512 + daemon, ~8 KiB)
#   cannot fit in 1 KiB, so the sim bootstrap is: this <=1 KiB stub in the
#   IMEM ROM + the full firmware image backdoor-preloaded into DMEM by the
#   testbench ($readmemh into the 4 dmem_ram byte-lane sprams). There is NO
#   ROM->RAM .data copy: the DMEM preload already carries .data contents;
#   crt0 only clears .bss. main() returning parks the core in a wfi loop.
#
#   ASSUMPTION (TBD 2026-09-01): DMEM-exec is a SIM-ONLY bootstrap. Real
#   hardware needs the netlist regenerated with a >=16 KiB IMEM ROM (or a
#   ROM->DMEM bootloader) — tracked as an E1-BMC1 follow-up; see
#   docs/reports/report-E1-RUN2-daemon-20260901.md "待确认" #1.
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

    /* Clear .bss (the DMEM backdoor preload covers .text/.data only). */
    lui     a1, %hi(__bss_start)
    addi    a1, a1, %lo(__bss_start)
    lui     a2, %hi(__bss_end)
    addi    a2, a2, %lo(__bss_end)
1:  beq     a1, a2, 2f
    sw      x0, 0(a1)
    addi    a1, a1, 4
    beq     x0, x0, 1b
2:

    /* Call main (in DMEM). */
    call    main

    /* main returned: park the core (idle). */
3:  wfi
    beq     x0, x0, 3b

    .size   _start, .-_start
