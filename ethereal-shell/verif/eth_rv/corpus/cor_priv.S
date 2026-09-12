/* SPDX-License-Identifier: MIT
 *
 * Corpus program 9 — privilege modes and the S-mode CSR view (E2-RV1
 * increment 6, C14 §3). The reference for every expected value is Spike
 * (`--isa=rv64imc`, which enables S and U), probed before this program was
 * written; the DiffTest then re-checks every value it reads on both sides.
 *
 * Coverage:
 *   * mstatus WARL: the full write mask (SIE|SPIE|SPP|FS|MPP|MPIE|MIE|MPRV|SUM|
 *     MXR|TVM|TW|TSR), SD derived from FS, MPP legalization (2'b10 -> U)
 *   * sstatus is a view of mstatus: a write through it touches only S bits
 *   * mtvec/stvec clear bit 1 (MODE), sepc/mepc clear bit 0 (IALIGN = 16)
 *   * medeleg/mideleg write masks (0x8b3fe / 0x222 — bit 19 is Zicntr's
 *     hardware-error delegation bit, which is WARL storage here)
 *   * mcounteren/scounteren exist but have a zero write mask without Zicntr
 *   * mip at reset: MTIP is pending (the CLINT's mtime and mtimecmp are both 0)
 *   * mret from M to S: MIE <= MPIE, MPIE <= 1, MPP <= U, the hart enters S
 *   * S-mode: sstatus is readable, sscratch round trips, and every M-mode CSR
 *     (read and write) and mret are illegal instructions
 *   * sret from S to U: SIE <= SPIE, SPIE <= 1, SPP <= U
 *   * U-mode: ecall raises cause 8; sstatus/mstatus/mscratch/sscratch and both
 *     xRET instructions are illegal
 *
 * The mstatus a trap handler reads is the *post-entry* value, so the checks
 * armed with NEXTMS pin exactly the trap-entry bookkeeping (MPP <= the mode that
 * trapped, MPIE <= MIE, MIE <= 0) — and, through MPIE, that mret/sret restored
 * the interrupt-enable stack as they must.
 *
 * `main` returns 0 through a0 (crt0.S), or the index of the first failed check;
 * the trap handler verifies the cause/mtval (and optional mstatus) armed by
 * NEXT, then skips the trapping instruction. The final check counts the traps,
 * so an expectation that is never armed cannot pass unnoticed.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, mtval, index — arm the expectation for the next trap.
     mtval: a value, -1 = do not check, -2 = the 32-bit word at mepc. */
  .macro NEXT cause, mtval, index
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  li      s4, -1                  /* no mstatus expectation */
  .endm

  /* NEXTMS cause, mtval, index, mstatus — NEXT plus the mstatus the handler
     must observe when the trap is taken. */
  .macro NEXTMS cause, mtval, index, mstatus
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  li      s4, \mstatus
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      s5, m_handler           /* kept live: the mtvec tests clobber mtvec */
  csrw    mtvec, s5
  la      s6, s_handler
  csrw    stvec, s6
  csrw    medeleg, zero
  csrw    mideleg, zero
  li      s11, 0                  /* trap counter */

  /* ---- 1. mstatus WARL round trips ------------------------------------- */
  csrr    t0, mstatus             /* reset value: MPP = U, SXL = UXL = 2 */
  CK      t0, 0x0000000a00000000, 1
  li      t0, -1
  csrw    mstatus, t0
  csrr    t0, mstatus             /* FS = 3 sets SD; every WARL bit is stored */
  CK      t0, 0x8000000a007e79aa, 2
  csrr    t0, sstatus             /* the S-mode view of the same register */
  CK      t0, 0x80000002000c6122, 3
  csrw    mstatus, zero
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000000, 4
  li      t0, 0x2000              /* FS = 1: SD stays clear */
  csrw    mstatus, t0
  csrr    t0, mstatus
  CK      t0, 0x0000000a00002000, 5
  li      t0, 0x1000              /* MPP = 2'b10 is not a mode: legalizes to U */
  csrw    mstatus, t0
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000000, 6
  li      t0, 0x800               /* MPP = S is kept */
  csrw    mstatus, t0
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000800, 7
  csrw    mstatus, zero
  /* sstatus writes only touch S bits (and leave MPP/MPIE/MIE alone) */
  li      t0, -1
  csrw    sstatus, t0
  csrr    t0, mstatus
  CK      t0, 0x8000000a000c6122, 8
  csrw    mstatus, zero
  csrr    t0, sstatus
  CK      t0, 0x0000000200000000, 9

  /* ---- 2. tvec/epc WARL ------------------------------------------------- */
  li      t0, 0x8000000f          /* mtvec keeps MODE bit 0, clears bit 1 */
  csrw    mtvec, t0
  csrr    t0, mtvec
  CK      t0, 0x8000000d, 10
  li      t0, -1
  csrw    stvec, t0
  csrr    t0, stvec
  CK      t0, 0xfffffffffffffffd, 11
  csrw    stvec, s6               /* restore the handlers before any trap */
  csrw    mtvec, s5
  li      t0, -1
  csrw    sepc, t0
  csrr    t0, sepc
  CK      t0, 0xfffffffffffffffe, 12
  csrw    sepc, zero

  /* ---- 3. delegation registers and the S-mode scratch/status CSRs ------ */
  li      t0, -1
  csrw    medeleg, t0
  csrr    t0, medeleg
  CK      t0, 0x000000000008b3fe, 13
  csrw    medeleg, zero
  csrw    mideleg, t0
  csrr    t0, mideleg
  CK      t0, 0x0000000000000222, 14
  csrw    mideleg, zero
  li      t0, 0xdeadbeefcafebabe
  csrw    scause, t0
  csrw    stval, t0
  csrw    sscratch, t0
  csrr    t1, scause
  bne     t1, t0, .Lf15
  csrr    t1, stval
  bne     t1, t0, .Lf16
  csrr    t1, sscratch
  bne     t1, t0, .Lf17
  csrw    scause, zero
  csrw    stval, zero
  csrw    sscratch, zero
  /* mcounteren/scounteren are WARL 0x7 since Zicntr landed (E2-RV2 increment 4):
     the mask is Spike's `counteren_mask`, so an all-ones write reads back
     CY|TM|IR (local://rv10-counter-notes.md §1.1). */
  li      t0, -1
  csrw    mcounteren, t0
  csrr    t0, mcounteren
  CK      t0, 7, 18
  csrw    scounteren, t0
  csrr    t0, scounteren
  CK      t0, 7, 19

  /* ---- 4. mip: MTIP pending at reset (CLINT mtime = mtimecmp = 0) ------- */
  csrr    t0, mip
  CK      t0, 0x0000000000000080, 20
  csrr    t0, mie
  CK      t0, 0, 21

  /* ---- 5. mret to S-mode ------------------------------------------------ */
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  mret                            /* -> S: MIE <= MPIE, MPIE <= 1, MPP <= U */
  .align 2
s_code:
  csrr    t0, sstatus             /* readable in S: UXL only */
  CK      t0, 0x0000000200000000, 22
  li      t0, 0x1234
  csrw    sscratch, t0
  csrr    t0, sscratch
  CK      t0, 0x1234, 23
  /* ecall from S: the handler checks the post-entry mstatus, which pins
     MPP <= S, MPIE <= MIE (1, so mret did restore MIE) and MIE <= 0 */
  NEXTMS  9, 0, 24, 0x0000000a00000880
  ecall
  /* every M-mode CSR is illegal from S — reads and writes alike */
  NEXT    2, -2, 25
  csrr    t0, mstatus
  NEXT    2, -2, 26
  csrw    mstatus, zero
  NEXT    2, -2, 27
  csrr    t0, mscratch
  NEXT    2, -2, 28
  csrw    mscratch, zero
  NEXT    2, -2, 29
  csrr    t0, medeleg
  NEXT    2, -2, 30
  csrw    mideleg, zero
  /* mret is M-only; sret is legal from S */
  NEXT    2, -2, 31
  mret
  /* ---- 6. sret from S to U ---------------------------------------------- */
  li      t0, 0
  csrw    sstatus, zero           /* SPP = U, SIE = 0, SPIE = 0 */
  la      t0, u_code
  csrw    sepc, t0
  sret                            /* -> U: SIE <= SPIE, SPIE <= 1, SPP <= U */
  .align 2
u_code:
  /* ecall from U: post-entry mstatus pins MPP <= U, MPIE <= MIE and shows
     SPIE = 1 (set by the sret) with SIE = 0 */
  NEXTMS  8, 0, 32, 0x0000000a000000a0
  ecall
  /* U-mode may touch none of the privileged CSRs, and neither xRET */
  NEXT    2, -2, 33
  csrr    t0, sstatus
  NEXT    2, -2, 34
  csrr    t0, mstatus
  NEXT    2, -2, 35
  csrw    mscratch, t0
  NEXT    2, -2, 36
  csrw    sscratch, t0
  NEXT    2, -2, 37
  sret
  NEXT    2, -2, 38
  mret
  /* ---- 7. every expected trap happened, and no other -------------------- */
  li      t0, 15
  bne     s11, t0, .Lf40
  li      a0, 0
  j       exit_ok

  .align 2
.Lf15:
  li      a0, 15
  ret
.Lf16:
  li      a0, 16
  ret
.Lf17:
  li      a0, 17
  ret
.Lf40:
  li      a0, 40
  ret

  /* ====================================================================
   * M-mode trap handler: verify the expectation, skip the trap, mret.
   * (s0/s2/s3/s4 are armed by NEXT/NEXTMS; t0..t5 are scratch, s11 counts.)
   * ==================================================================== */
  .align 2
m_handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  li      t4, -1
  beq     s4, t4, .Lhno_ms
  csrr    t2, mstatus
  bne     t2, s4, .Lhbad
.Lhno_ms:
  li      t4, -1
  beq     s2, t4, .Lhadv
  csrr    t5, mtval
  csrr    t1, mepc
  li      t4, -2
  beq     s2, t4, .Lhword
  bne     t5, s2, .Lhbad
  j       .Lhadv
.Lhword:
  lhu     t2, 0(t1)
  lhu     t3, 2(t1)
  slli    t3, t3, 16
  or      t2, t2, t3
  bne     t5, t2, .Lhbad
.Lhadv:
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
  li      a0, 90
  ret

  /* The S-mode handler should never run here: medeleg = 0 throughout. If it
     does, fail loudly rather than silently passing a check. */
  .align 2
s_handler:
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
