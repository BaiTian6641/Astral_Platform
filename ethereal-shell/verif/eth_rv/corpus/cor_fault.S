/* SPDX-License-Identifier: MIT
 *
 * Corpus program 8/8 — the port ERROR RESPONSE (E2-RV1 increment 5, C14 §4).
 *
 * Every access the platform cannot serve must come back as the architectural
 * trap Spike raises for it, never as a silent success and never as a hang. The
 * program drives each class, with the usual handler checking mcause/mtval against
 * the expectation armed by the NEXT* macros:
 *
 *   * an address no region claims (0x2000_0000 / 0x4000_0000): load access fault
 *     (mcause 5) and store access fault (mcause 7), mtval = the address — and
 *     the faulting load writes NOTHING to its destination register;
 *   * a 64-bit address above the D port's AXI window whose LOW 32 BITS alias the
 *     DRAM window (0x1_8000_0000): still an access fault — the address must not
 *     be truncated into a valid window and quietly succeed;
 *   * the console page (0x1000_0000), where the ns16550 register file is one byte
 *     wide: any wider access is rejected (mcause 5/7) exactly as Spike's
 *     `ns16550_t::load/store` rejects `len != reg_io_width`, and the rejected
 *     store must NOT reach the transmit register;
 *   * the console page's BYTE offsets: 0x…008..0x…FFF are NOT "unimplemented".
 *     Spike's device decodes `addr &= 7`, so every page offset aliases onto one
 *     of the eight byte registers — reading 0x1000_0010 reads the receiver (0),
 *     and 0x1000_000F after writing the scratch register at 0x1000_0007 reads the
 *     written value back. These two checks are the regression control for the
 *     wedge this increment removed: a decoder that refuses those offsets hangs
 *     the D port instead of aliasing, and the run dies on the testbench's
 *     bounded-cycle wedge guard with the faulting address.
 *   * a fetch outside mapped memory (jalr to 0x2000_0000): instruction access
 *     fault (mcause 1), mepc = mtval = the faulting fetch address — the jalr
 *     itself retires (its link is written), which is what Spike does too.
 *
 * The expectations are Spike's, read off the golden model rather than guessed:
 * `generated/rv_difftest/spike` run on this program is what the DiffTest
 * compares against, and each pair below is checked twice — once by this program's
 * handler (so a wrong cause/tval is a non-zero exit *and* a divergent trace) and
 * once by the RTL-vs-Spike commit comparison.
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S), and
 * the handler returns a0 = 99 if a trap's cause/mtval does not match what the
 * program armed; the final check pins the exact trap count, so a missing trap (a
 * silent success) is caught as well as a wrong one.
 *
 * Addresses are deliberately chosen in holes both models agree on: below the
 * DRAM base there is no device, so Spike's `bus_t` finds nothing for them (its
 * `mmio_load/fetch` returns false -> access fault), and they are outside the
 * RTL's memory window. An address inside Spike's nominal DRAM window but past
 * the RTL socket's window (0x8000_0000 + 1 MiB) would NOT agree — Spike's DRAM is
 * the whole 2 GiB — so no check uses one.
 */

  .equ UART_BASE, 0x10000000

  /* CK reg, want, index — compare; on mismatch return a0 = index.
     t6 is the macro's scratch, the trap handler below uses t0..t6 only. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, mtval, index — arm the expectation for the trap the next
     instruction must raise. mtval is a value, or -1 = do not check. */
  .macro NEXT cause, mtval, index
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  .endm

  /* NEXTR cause, mtval-register, index — like NEXT, for a computed address. */
  .macro NEXTR cause, mtval_reg, index
  li      s0, \cause
  mv      s2, \mtval_reg
  li      s3, \index
  .endm

  /* NEXTF target_reg, resume_label, index — for the fetch-fault check: the trap
     is at `*target_reg`, which is NOT a mapped address, so the handler must not
     try to read the instruction there; it returns to `resume_label` instead. */
  .macro NEXTF cause, target_reg, resume_label, index
  li      s0, \cause
  mv      s2, \target_reg
  li      s3, \index
  la      s10, \resume_label
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      t0, handler
  csrw    mtvec, t0
  li      s11, 0                  /* trap counter */

  /* ==== 1. loads from an address no region claims: cause 5, mtval = addr ==== */
  li      s6, 0x20000000
  li      s7, 0x1122334455667788  /* sentinel: a faulting load must not write it */
  NEXT    5, 0x20000000, 1
  ld      s7, 0(s6)
  CK      s7, 0x1122334455667788, 2

  li      s6, 0x20000008
  NEXT    5, 0x20000008, 3
  lw      s7, 0(s6)
  CK      s7, 0x1122334455667788, 4

  li      s6, 0x20001000
  NEXT    5, 0x20001000, 5
  lh      s7, 0(s6)

  li      s6, 0x40000000
  NEXT    5, 0x40000000, 6
  lbu     s7, 0(s6)

  /* ---- 2. above the AXI window, low 32 bits alias DRAM: still a fault ---- */
  li      s6, 0x180000000
  NEXT    5, 0x180000000, 7
  ld      s7, 0(s6)
  CK      s7, 0x1122334455667788, 8

  /* ==== 3. stores to an address no region claims: cause 7, mtval = addr ==== */
  li      s8, 0x5a5a5a5a
  li      s6, 0x20000020
  NEXT    7, 0x20000020, 9
  sd      s8, 0(s6)

  li      s6, 0x40000000
  NEXT    7, 0x40000000, 10
  sb      s8, 0(s6)

  /* ==== 4. the console page is one byte wide: wider access = access fault ==== */
  li      s6, UART_BASE
  NEXT    5, UART_BASE, 11
  lw      s7, 0(s6)               /* Spike: reg_io_width != len -> load fault */
  NEXT    7, UART_BASE, 12
  sw      s8, 0(s6)               /* ... and the store must not transmit */
  li      s6, UART_BASE + 0xffc
  NEXT    5, UART_BASE + 0xffc, 13
  lw      s7, 0(s6)               /* page-crossing + wrong width */

  /* ==== 5. ... while BYTE offsets alias (the old wedge, now Spike's alias) ==== */
  li      s6, UART_BASE + 7       /* scratch register (offset 7) */
  li      s7, 0x5a
  sb      s7, 0(s6)
  li      s6, UART_BASE + 0xf     /* 0xf & 7 = 7 -> the scratch register */
  lbu     s8, 0(s6)
  CK      s8, 0x5a, 14
  li      s6, UART_BASE + 0x10    /* 0x10 & 7 = 0 -> the receiver (nothing sent) */
  lbu     s8, 0(s6)
  CK      s8, 0, 15

  /* ==== 6. mapped memory still works after all of that ==== */
  la      s5, buf
  li      s7, 0x0102030405060708
  sd      s7, 0(s5)
  ld      s8, 0(s5)
  CK      s8, 0x0102030405060708, 16

  /* ==== 7. a fetch outside mapped memory: cause 1, mepc = mtval = the pc ==== */
  la      s4, .Lfa_resume         /* the jalr's link, checked below */
  li      s6, 0x20000000
  NEXTF   1, s6, .Lfa_resume, 17
  jalr    s7, s6                  /* retires; the fetch at 0x2000_0000 traps */
.Lfa_resume:
  bne     s7, s4, .Lf18           /* the jalr itself retired and wrote its link */

  /* ==== 8. every expected trap happened, and no other ==== */
  li      t0, 11
  bne     s11, t0, .Lf19

  li      a0, 0
  ret

  /* ---- failure returns (indices the checks do not use as their own) ---- */
.Lf18:
  li      a0, 18
  ret
.Lf19:
  li      a0, 19
  ret

  /* ===================================================================
   * trap handler: verify the expectation armed with NEXT*, then resume
   * after the trapping instruction.
   * =================================================================== */
  .align 2
handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  csrr    t5, mtval
  li      t4, 1
  beq     t0, t4, .Lhfetch        /* cause 1: there is no instruction at mepc */
  li      t4, -1
  beq     s2, t4, .Lhadv          /* no mtval expectation */
  bne     t5, s2, .Lhbad
.Lhadv:
  /* advance mepc past the trapping instruction (2 bytes when compressed) */
  csrr    t1, mepc
  lhu     t2, 0(t1)
  andi    t3, t2, 3
  li      t4, 3
  beq     t3, t4, .Lh32
  addi    t1, t1, 2
  j       .Lhgo
.Lh32:
  addi    t1, t1, 4
.Lhgo:
  csrw    mepc, t1
  mret

  /* a fetch fault: mepc and mtval are both the address that could not be
     fetched, and the resume point is the one the program armed (the trapping
     "instruction" was never fetched, so there is nothing to step over). */
.Lhfetch:
  bne     t5, s2, .Lhbad
  csrr    t1, mepc
  bne     t1, s2, .Lhbad
  csrw    mepc, s10
  mret

.Lhbad:
  li      a0, 99
  ret

  .section .bss
  .align 3
buf:
  .space 32

  .section .note.GNU-stack, "", @progbits
