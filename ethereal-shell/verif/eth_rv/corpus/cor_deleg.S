/* SPDX-License-Identifier: MIT
 *
 * Corpus program 10 — trap delegation (E2-RV1 increment 6, C14 §3). With
 * `medeleg` set, an exception raised below M-mode is handled at `stvec` with
 * `scause`/`sepc`/`stval`/`sstatus` instead of `mtvec`/`mcause`/`mepc`/`mtval`/
 * `mstatus`; a trap raised *in* M-mode is never delegated, whatever the
 * registers say. Every expected value is Spike's, probed before the RTL was
 * touched, and the DiffTest re-checks the whole stream.
 *
 * Coverage:
 *   * medeleg bit 9/8/5 delegation of ecall-from-S, ecall-from-U and a load
 *     access fault (the UART page rejects a non-byte access on both sides)
 *   * the S-mode stack: scause/sepc/stval, SPP <= the mode that trapped,
 *     SPIE <= SIE, SIE <= 0, and sret returning to SPP with SIE <= SPIE
 *   * a cause that is NOT delegated still takes the M-mode path (MPP <= S)
 *   * a trap raised in M-mode is not delegated even with its medeleg bit set
 *
 * expectations: the M handler checks s0 (mcause), s2 (mtval, -2 = the word at
 * mepc, -1 = don't care) and s4 (mstatus, -1 = don't care); the S handler checks
 * s7 (scause), s8 (sstatus, -1 = don't care) and s9 (stval, -1 = don't care).
 * s11 counts traps on both paths, and the final check compares it.
 */

  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* ---- M-mode expectations (trap taken to mtvec) ---- */
  .macro NEXTM cause, mtval, mstatus, index
  li      s0, \cause
  li      s2, \mtval
  li      s4, \mstatus
  li      s3, \index
  .endm

  /* ---- S-mode expectations (trap delegated to stvec) ---- */
  .macro NEXTS scause, stval, sstatus, index
  li      s7, \scause
  li      s9, \stval
  li      s8, \sstatus
  li      s10, \index
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      s5, m_handler
  csrw    mtvec, s5
  la      s6, s_handler
  csrw    stvec, s6
  csrw    medeleg, zero
  csrw    mideleg, zero
  li      s11, 0

  /* ---- 1. an M-mode trap is never delegated, even with the bit set ------ */
  li      t0, 0x4                 /* delegate illegal instructions (cause 2) */
  csrw    medeleg, t0
  NEXTM   2, -2, 0x0000000a00001800, 1
  .word   0xffffffff              /* illegal in M: goes to mtvec, not stvec */
  /* ---- 2. ecall from M: cause 11, and bit 11 is not even writable ------ */
  li      t0, -1
  csrw    medeleg, t0
  csrr    t0, medeleg             /* the full core mask is 0xb3fe */
  CK      t0, 0x000000000000b3fe, 2
  li      t0, 0x80
  csrw    medeleg, t0             /* 0x80 = cause 7 only */
  NEXTM   11, 0, 0x0000000a00001800, 3
  ecall                           /* M-mode ecall is never delegated */
  /* ---- 3. delegate ecall-from-S, ecall-from-U and load access faults ---- */
  li      t0, 0x320               /* bits 9, 8, 5 */
  csrw    medeleg, t0
  csrr    t0, medeleg
  CK      t0, 0x320, 4

  /* enter S-mode */
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  mret
  .align 2
s_code:
  /* ---- 4. illegal instruction in S: cause 2 is NOT delegated here ------ */
  NEXTM   2, -2, 0x0000000a00000880, 5
  .word   0xffffffff
  /* ---- 5. delegated ecall from S: the S-mode stack --------------------- */
  NEXTS   9, 0, 0x0000000200000100, 6
  ecall                           /* -> stvec: scause 9, SPP = S, SIE = 0 */
  /* ---- 6. SIE stacking across a delegated trap -------------------------- */
  li      t0, 2
  csrs    sstatus, t0             /* SIE = 1 */
  NEXTS   9, 0, 0x0000000200000120, 7
  ecall                           /* SPIE <= 1, SIE <= 0 inside the handler */
  csrr    t0, sstatus             /* sret restored SIE <= SPIE, and set SPIE */
  CK      t0, 0x0000000200000022, 8
  /* ---- 7. drop to U and delegate an ecall from U ------------------------ */
  li      t0, 0
  csrw    sstatus, zero           /* SPP = U, SIE = 0 */
  la      t0, u_code
  csrw    sepc, t0
  sret
  .align 2
u_code:
  NEXTS   8, 0, 0x0000000200000000, 9
  ecall                           /* -> stvec: scause 8, SPP <= U */
  /* ---- 8. an undelegated cause from U still goes to M ------------------ */
  NEXTM   2, -1, 0x0000000a000000a0, 10
  .word   0xffffffff
  /* ---- 9. a delegated load access fault from U -------------------------- */
  li      t0, 0x10000000          /* the UART page rejects a 4-byte load */
  NEXTS   5, 0x10000000, 0x0000000200000000, 11
  lw      t1, 0(t0)
  /* ---- 10. every expected trap happened, and no other ------------------- */
  li      t0, 8
  bne     s11, t0, .Lf40
  li      a0, 0
  j       exit_ok

  .align 2
.Lf40:
  li      a0, 40
  ret

  /* ====================================================================
   * M-mode handler (s0/s2/s4 armed by NEXTM)
   * ==================================================================== */
  .align 2
m_handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lmbad
  li      t4, -1
  beq     s4, t4, .Lmno_ms
  csrr    t2, mstatus
  bne     t2, s4, .Lmbad
.Lmno_ms:
  li      t4, -1
  beq     s2, t4, .Lmadv
  csrr    t5, mtval
  csrr    t1, mepc
  li      t4, -2
  beq     s2, t4, .Lmword
  bne     t5, s2, .Lmbad
  j       .Lmadv
.Lmword:
  lhu     t2, 0(t1)
  lhu     t3, 2(t1)
  slli    t3, t3, 16
  or      t2, t2, t3
  bne     t5, t2, .Lmbad
.Lmadv:
  csrr    t1, mepc
  addi    t1, t1, 4               /* every trapping instruction here is 32-bit */
  csrw    mepc, t1
  mret
.Lmbad:
  li      a0, 90
  ret

  /* ====================================================================
   * S-mode handler (s7/s8/s9 armed by NEXTS)
   * ==================================================================== */
  .align 2
s_handler:
  addi    s11, s11, 1
  csrr    t0, scause
  bne     t0, s7, .Lhbad
  li      t4, -1
  beq     s8, t4, .Lsno_status
  csrr    t2, sstatus
  bne     t2, s8, .Lhbad
.Lsno_status:
  li      t4, -1
  beq     s9, t4, .Lsadv
  csrr    t3, stval
  bne     t3, s9, .Lhbad
.Lsadv:
  csrr    t1, sepc
  addi    t1, t1, 4
  csrw    sepc, t1
  sret
.Lhbad:
  li      a0, 91
  ret

exit_ok:
  li      a0, 0
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

  .section .note.GNU-stack, "", @progbits
