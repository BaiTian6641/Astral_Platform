/* SPDX-License-Identifier: MIT
 *
 * Corpus program 6/6 — the M-mode trap path (C14 §3, checkpoint 4 part 2).
 *
 * Exercises every exception RV-B implements, with a handler that checks the
 * architectural bookkeeping (mcause / mepc / mtval), skips the trapping
 * instruction and returns with mret:
 *
 *   * ecall from M-mode        mcause 11, mtval 0
 *   * ebreak                   mcause 3,  mtval = pc        (compressed and 32-bit forms)
 *   * illegal instruction      mcause 2,  mtval = the instruction word (32-bit and compressed)
 *   * load address misaligned  mcause 4,  mtval = the address (halfword/word/dword)
 *   * store address misaligned mcause 6,  mtval = the address (dword/halfword/compressed)
 *   * unimplemented CSR        mcause 2  (mstatush does not exist on RV64; 0x7c0/0xbc0 are not implemented)
 *   * mstatus bookkeeping      MPP = M and MIE <= 0 on trap; MIE <= MPIE, MPIE <= 1, MPP <= U on mret
 *   * trap semantics           the trapping instruction retires NOTHING: a
 *                              misaligned store leaves memory untouched and a
 *                              misaligned load leaves its destination untouched
 *   * mtvec MODE               a MODE = 1 (vectored) base still traps to
 *                              `base & ~1` for an exception — the golden model
 *                              vectors interrupts only, and RV-B has none
 *
 * The handler advances mepc by the length of the trapping instruction (2 or 4
 * bytes, read from the low bits of the halfword at mepc), so the program also
 * pins that a trap leaves the return address intact apart from that.
 *
 * The expected mcause/mtval of the next trap live in s0/s2 (armed by NEXT);
 * `main` returns 0 on success or a non-zero check index (crt0.S), and the
 * handler returns a0 = 99 if the expectation does not hold — visible both as a
 * non-zero Spike exit status and as a divergent commit trace.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index.
     t6 is the macro's scratch, the trap handler below uses t0..t5 only. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, mtval-expectation, index — arm the expectation for the trap the
     next instruction must raise. The mtval expectation is a value, or
     -1 = do not check, -2 = "the 32-bit word at mepc", -3 = "mepc itself"
     (breakpoint), -4 = "the 16-bit instruction image at mepc". */
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

  .section .text
  .globl main
  .align 2
main:
  la      t0, handler
  csrw    mtvec, t0
  li      s11, 0                  /* trap counter */

  /* ---- 1. ecall from M-mode: cause 11, mtval 0, mepc past the ecall ------ */
  NEXT    11, 0, 1
  auipc   s4, 0                   /* s4 = this pc; the 4-byte ecall follows it */
  ecall
  csrr    t0, mcause
  CK      t0, 11, 2
  csrr    t0, mepc                /* handler advanced mepc past the ecall */
  addi    t1, s4, 8
  bne     t0, t1, .Lf3
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000080, 4   /* MIE = 0, MPIE = 1, MPP = U after mret */

  /* ---- 2. ebreak: cause 3, mtval = the pc of the ebreak ----------------- */
  NEXT    3, -3, 5
  .hword  0x9002                  /* C.EBREAK (the compressed form `ebreak` picks) */
  csrr    t0, mcause
  CK      t0, 3, 6

  NEXT    3, -3, 35
  .word   0x00100073              /* EBREAK, the 32-bit form */
  csrr    t0, mcause
  CK      t0, 3, 36

  /* ---- 3. illegal instruction (32-bit): cause 2, mtval = the word -------- */
  NEXT    2, -2, 7
  .word   0xffffffff
  csrr    t0, mcause
  CK      t0, 2, 8

  /* ---- 4. illegal compressed instruction: cause 2, mtval = the image ---- */
  NEXT    2, -4, 9
  .hword  0x0000                  /* c.unimp */
  csrr    t0, mcause
  CK      t0, 2, 10

  /* ---- 5. an unimplemented CSR access is illegal, never silent ---------- */
  NEXT    2, -2, 11
  csrr    t0, mstatush            /* 0x310: does not exist on RV64 */
  NEXT    2, -2, 12
  csrr    t0, 0x7c0               /* custom read/write, not implemented here */
  NEXT    2, -2, 13
  csrw    0xbc0, x0               /* the write side of the same rule */
  csrr    t0, mcause
  CK      t0, 2, 14

  /* ---- 6. load/store address misaligned --------------------------------- */
  /* Everything that must survive a trap lives in an s register: the handler
     owns t0..t5, and the trap is the point of this section. */
  la      s5, buf
  li      s8, 0x1122334455667788
  sd      s8, 0(s5)               /* aligned reference value */

  li      s7, 0x1234
  addi    s6, s5, 1
  NEXTR   4, s6, 15
  ld      s7, 0(s6)               /* misaligned dword load */
  CK      s7, 0x1234, 16          /* ... which must not write its destination */

  addi    s6, s5, 1
  NEXTR   4, s6, 17
  lh      s7, 0(s6)               /* misaligned halfword load (odd address) */
  addi    s6, s5, 2
  NEXTR   4, s6, 18
  lw      s7, 0(s6)               /* misaligned word load */

  addi    s6, s5, 3
  NEXTR   6, s6, 19
  sd      s8, 0(s6)               /* misaligned dword store: must not write */
  ld      s7, 0(s5)
  bne     s7, s8, .Lf20

  addi    s6, s5, 1
  NEXTR   6, s6, 21
  sh      s8, 0(s6)               /* misaligned halfword store */

  /* compressed store form: c.sw with a misaligned base in a prime register */
  la      a1, buf
  addi    a1, a1, 1
  li      a2, 0x11223344
  NEXTR   6, a1, 22
  c.sw    a2, 0(a1)
  ld      s7, 0(s5)
  bne     s7, s8, .Lf23

  /* ---- 7. a MODE = 1 mtvec still traps to `base & ~1` ------------------- */
  la      t0, handler
  ori     t0, t0, 1
  csrw    mtvec, t0
  NEXT    11, 0, 24
  ecall
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000080, 25
  la      t0, handler
  csrw    mtvec, t0

  /* ---- 8. every expected trap happened, and no other ------------------- */
  li      t0, 15
  bne     s11, t0, .Lf26

  li      a0, 0
  ret

  /* ---- failure returns (offset so they never collide with a check) ------ */
.Lf3:
  li      a0, 30
  ret
.Lf20:
  li      a0, 31
  ret
.Lf23:
  li      a0, 32
  ret
.Lf26:
  li      a0, 33
  ret

  /* ===================================================================
   * trap handler: verify the expectation armed with NEXT, then resume
   * after the trapping instruction.
   * =================================================================== */
  .align 2
handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  li      t4, -1
  beq     s2, t4, .Lhadv         /* no mtval expectation */
  csrr    t5, mtval
  csrr    t1, mepc
  li      t4, -2
  beq     s2, t4, .Lhword        /* expect the 32-bit instruction word */
  li      t4, -3
  beq     s2, t4, .Lhpc          /* expect the pc itself (breakpoint) */
  li      t4, -4
  beq     s2, t4, .Lhhalf        /* expect the 16-bit instruction image */
  bne     t5, s2, .Lhbad
  j       .Lhadv
.Lhword:
  lhu     t2, 0(t1)
  lhu     t3, 2(t1)
  slli    t3, t3, 16
  or      t2, t2, t3
  bne     t5, t2, .Lhbad
  j       .Lhadv
.Lhhalf:
  lhu     t2, 0(t1)
  bne     t5, t2, .Lhbad
  j       .Lhadv
.Lhpc:
  bne     t5, t1, .Lhbad
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

.Lhbad:
  li      a0, 99
  ret

  .section .bss
  .align 3
buf:
  .space 32

  .section .note.GNU-stack, "", @progbits
