# SPDX-License-Identifier: MIT
#
# slot_payload.S — E1-BMC2 sim-demo FW slot payload (SIM-SCOPED).
#
# One 16-word (padded) RV32IMC image per slot, XIP-executed from the TB
# "flash" stand-in window at the slot's payload entry (slot base + 5 words;
# -Ttext sets that address at build time — see bmc-fw/Makefile `slots`).
#
# The payload proves SLOT-SPECIFIC CODE ran: it prints its compiled-in
# version digit + '\n' over UART0 (the boot stub prints the "payload: "
# prefix immediately before the jump). SLOT_VER comes from -D at build.
#
# UART0 (NEORV32 IO region, no XBUS): CTRL @ +0 bit19 = TX FIFO not-full,
# DATA @ +4. Two bytes only — the TX wait loop is unrolled twice.
#
# G1: bare-metal, no runtime, no stack use, position-independent
# (no absolute data references).
#
# Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.6 (v0.4).

#ifndef SLOT_VER
#error "build with -D SLOT_VER=<1|2>"
#endif

    .section .text
    .globl slot_payload
    .type  slot_payload, @function
slot_payload:
    li      a2, 0xfff50000      # UART0 base (CTRL@0, DATA@4)
    li      a1, 0x80000         # CTRL.TX_NFULL mask (bit 19)
    li      a0, 48 + SLOT_VER   # '0' + version digit
1:  lw      a3, 0(a2)           # wait for TX FIFO not full
    and     a3, a3, a1
    beqz    a3, 1b
    sw      a0, 4(a2)           # print the digit
    li      a0, 10              # '\n'
2:  lw      a3, 0(a2)
    and     a3, a3, a1
    beqz    a3, 2b
    sw      a0, 4(a2)
    ret                         # back to the boot stub

    .size slot_payload, . - slot_payload
