/* SPDX-License-Identifier: MIT
 *
 * Corpus program — the BootROM handoff check (E2-RV2 increment 5, S3).
 *
 * The other corpus programs are loaded at the memory window base and the core
 * starts executing them directly. This one is the opposite: it is linked at a
 * NON-BASE entry (0x8000_1000, see cor_boot.ld) and is only ever reached through
 * the reset path, which is what the slice exists to prove:
 *
 *     reset -> BootROM (0x1000) -> a0 = hart id, a1 = DTB address
 *           -> jr to the 64-bit payload entry word -> this program
 *
 * `main` therefore checks the two architectural inputs the ROM handoff defines,
 * and then does an ordinary self-check of its own:
 *
 *   1. a0 == 0 (the hart id: one hart in this configuration);
 *   2. a1 != 0 and a1 is 8-byte aligned (a device-tree pointer, and one the FDT
 *      format requires to be aligned);
 *   3. a data round trip through `.data` (`boot_marker`), which proves the
 *      NON-BASE image was actually loaded at its link address.
 *
 * Any failure returns the check's number from `main`; crt0 turns that into the
 * HTIF exit code, so a failing check shows up as a different tohost store in the
 * commit trace as well as in the harness's exit status.
 *
 * WHAT IS DELIBERATELY *NOT* CHECKED HERE — the DTB contents. a1 is a DUT-side
 * contract value (0x8000_2000, the address the contract puts the blob at), but
 * the golden model boots through Spike's OWN reset vector, whose a1 is Spike's
 * DTB (0x1020). Reading a word through a1 would therefore put a DUT address next
 * to a Spike address in the compared memory stream and could never MATCH. The
 * exact a1 value and the FDT at that address are asserted where they are
 * observable: the testbench checks the ROM's a0/a1 values and the entry word at
 * the handoff, and `+dtb=<file>` has it check the FDT magic at 0x8000_2000 (see
 * tb_eth_rv_core.sv and local://s3-rtl-notes.md). A golden run that starts Spike
 * at 0x1000 with `--disable-dtb --pc=0x1000` over an image carrying the same ROM
 * compares the stub itself, and the DTB check can then be added here.
 *
 * The program is tiny on purpose: it lives below 0x8000_1C00 (the tohost page)
 * and its stack top is 0x8000_1F00, so the whole payload stays clear of the
 * device tree blob at 0x8000_2000 — the "DTB 8 KiB into RAM is clear of a small
 * payload" half of the contract.
 */

    .equ DT_MARKER, 0x5a5a5a5a

    .section .text
    .globl main
    .align 2
main:
    /* 1: a0 must be the hart id (0). */
    bnez    a0, .Lfail_a0

    /* 2: a1 must be a non-null, 8-byte aligned pointer (an FDT blob). */
    beqz    a1, .Lfail_a1
    andi    t0, a1, 7
    bnez    t0, .Lfail_align

    /* 3: the payload's own data round trip. */
    la      t0, boot_marker
    ld      t1, 0(t0)
    li      t2, DT_MARKER
    bne     t1, t2, .Lfail_marker

    li      a0, 0
    ret

.Lfail_a0:
    li      a0, 1
    ret
.Lfail_a1:
    li      a0, 2
    ret
.Lfail_align:
    li      a0, 3
    ret
.Lfail_marker:
    li      a0, 4
    ret

    .section .data
    .align 3
    .globl boot_marker
boot_marker:
    .dword DT_MARKER

    .section .note.GNU-stack, "", @progbits
