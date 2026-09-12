/* SPDX-License-Identifier: MIT
 *
 * Corpus program — the mstatus.FS = Off path and the illegal-instruction trap
 * it produces (E2-RV2 / RV-C increment 2).
 *
 * At reset mstatus.FS is Off, so every instruction that touches floating-point
 * state is an illegal instruction (mcause = 2) whose mtval is the offending
 * instruction word and whose mepc is its own pc. This program walks the FP
 * instructions one at a time with a trap handler installed, checks the
 * architectural bookkeeping of each trap, and then re-runs the same operations
 * with FS = Initial to show they succeed.
 *
 * Covered, one trap per instruction (each with its own check id):
 *   FLD, FSD, FLW, FSW                     32-bit forms
 *   FADD.D, FMV.X.W, FMV.W.X, FMV.X.D      arithmetic and the moves
 *   frflags, csrw fcsr, fscsr, csrr frm, csrw frm
 *   C.FLD, C.FSD, C.FLDSP, C.FSDSP         2-byte forms
 *
 * The handler checks mcause, mtval and mepc against the expectation armed by
 * ARM, then advances mepc by `mtval[1:0] != 2'b11 ? 2 : 4` — so this program
 * also pins that the compressed FP forms advance mepc by two bytes and the
 * 32-bit ones by four. A handler that skips too much is caught by the pair of
 * CKs that brackets each trapped instruction: the marker written before the
 * trap and the one computed from it after the trap must both survive.
 *
 * HOW THE EXPECTED VALUES WERE PRODUCED: as in cor_fp.S — built with -DPROBE,
 * where CK dumps the register under test into s10 and the handler dumps each
 * observed (mcause, mtval, mepc) into a1/a2/a3, and every constant below is
 * read out of a Spike `--log-commits` run. The armed instruction words were
 * also cross-checked against `objdump -d` of the same ELF.
 *
 * `main` returns 0 on success or the id of the first failed check; a handler
 * that sees the wrong trap record returns the armed case id instead, and crt0.S
 * turns either into the process exit status.
 */

  /* CK <reg> <expected> <id> — return <id> from main unless reg == expected. */
#ifdef PROBE
  .macro CK reg, want, id
  mv      s10, \reg
  .endm

  /* ARM <word> <id> — arm the expectation for the trap the next instruction
     raises; PROBE mode leaves the trap record to the handler's dumps. */
  .macro ARM word, id
  la      s4, 1f
1:
  .endm
#else
  .macro CK reg, want, id
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \id
  ret
.Lck\@:
  .endm

  /* ARM <word> <id> — expect mcause 2, mtval = <word> and mepc = the address of
     the very next instruction (where the label at the end of the macro lands). */
  .macro ARM word, id
  li      s0, 2
  li      s2, \word
  li      s3, \id
  la      s4, 1f
1:
  .endm
#endif

  .section .text
  .globl main
  .align 2
main:
  /* FS is Off at reset: reading mstatus is legal, and it reads exactly this */
  csrr    t0, mstatus
  CK      t0, 0x0000000a00000000, 1

  la      t0, handler
  csrw    mtvec, t0
  la      s9, fbuf
  li      t2, 0x3fc00000                  /* operand for the FMV.W.X case */
  li      t4, 0x20                        /* operand for the fcsr cases */

  /* ---- 1. FLD, 32-bit form (s9 is not a compressed base register) -------- */
  li      s6, 0x6101
  ARM     0x000cb087, 2
  fld     f1, 0(s9)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006101, 3
  CK      s5, 0x0000000000006102, 4

  /* ---- 2. FSD ----------------------------------------------------------- */
  li      s6, 0x6102
  ARM     0x001cb027, 5
  fsd     f1, 0(s9)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006102, 6
  CK      s5, 0x0000000000006103, 7

  /* ---- 3. FLW ----------------------------------------------------------- */
  li      s6, 0x6103
  ARM     0x008ca107, 8
  flw     f2, 8(s9)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006103, 9
  CK      s5, 0x0000000000006104, 10

  /* ---- 4. FSW ----------------------------------------------------------- */
  li      s6, 0x6104
  ARM     0x002ca627, 11
  fsw     f2, 12(s9)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006104, 12
  CK      s5, 0x0000000000006105, 13

  /* ---- 5. FADD.D -------------------------------------------------------- */
  li      s6, 0x6105
  ARM     0x0210f1d3, 14
  fadd.d  f3, f1, f1
  addi    s5, s6, 1
  CK      s6, 0x0000000000006105, 15
  CK      s5, 0x0000000000006106, 16

  /* ---- 6. FMV.X.W ------------------------------------------------------- */
  li      s6, 0x6106
  ARM     0xe0008353, 17
  fmv.x.w t1, f1
  addi    s5, s6, 1
  CK      s6, 0x0000000000006106, 18
  CK      s5, 0x0000000000006107, 19

  /* ---- 7. FMV.W.X ------------------------------------------------------- */
  li      s6, 0x6107
  ARM     0xf0038253, 20
  fmv.w.x f4, t2
  addi    s5, s6, 1
  CK      s6, 0x0000000000006107, 21
  CK      s5, 0x0000000000006108, 22

  /* ---- 8. FMV.X.D ------------------------------------------------------- */
  li      s6, 0x6108
  ARM     0xe2008353, 23
  fmv.x.d t1, f1
  addi    s5, s6, 1
  CK      s6, 0x0000000000006108, 24
  CK      s5, 0x0000000000006109, 25

  /* ---- 9. frflags: csrr, fflags ----------------------------------------- */
  li      s6, 0x6109
  ARM     0x00102373, 26
  csrr    t1, fflags
  addi    s5, s6, 1
  CK      s6, 0x0000000000006109, 27
  CK      s5, 0x000000000000610a, 28

  /* ---- 10. csrw fcsr ---------------------------------------------------- */
  li      s6, 0x610a
  ARM     0x003e9073, 29
  csrw    fcsr, t4
  addi    s5, s6, 1
  CK      s6, 0x000000000000610a, 30
  CK      s5, 0x000000000000610b, 31

  /* ---- 11. fscsr, the read/write pseudo-instruction --------------------- */
  li      s6, 0x610b
  ARM     0x003e9373, 32
  fscsr   t1, t4
  addi    s5, s6, 1
  CK      s6, 0x000000000000610b, 33
  CK      s5, 0x000000000000610c, 34

  /* ---- 12. csrr frm ----------------------------------------------------- */
  li      s6, 0x610c
  ARM     0x00202373, 35
  csrr    t1, frm
  addi    s5, s6, 1
  CK      s6, 0x000000000000610c, 36
  CK      s5, 0x000000000000610d, 37

  /* ---- 13. csrw frm ----------------------------------------------------- */
  li      t4, 2
  li      s6, 0x610d
  ARM     0x002e9073, 38
  csrw    frm, t4
  addi    s5, s6, 1
  CK      s6, 0x000000000000610d, 39
  CK      s5, 0x000000000000610e, 40

  /* ---- 14. C.FLD: the compressed form advances mepc by two bytes -------- */
  la      a0, fbuf
  li      s6, 0x610e
  ARM     0x00002100, 41
  c.fld   f8, 0(a0)
  addi    s5, s6, 1
  CK      s6, 0x000000000000610e, 42
  CK      s5, 0x000000000000610f, 43

  /* ---- 15. C.FSD -------------------------------------------------------- */
  li      s6, 0x610f
  ARM     0x0000a100, 44
  c.fsd   f8, 0(a0)
  addi    s5, s6, 1
  CK      s6, 0x000000000000610f, 45
  CK      s5, 0x0000000000006110, 46

  /* ---- 16. C.FLDSP ------------------------------------------------------ */
  li      s6, 0x6110
  ARM     0x00002402, 47
  c.fldsp f8, 0(sp)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006110, 48
  CK      s5, 0x0000000000006111, 49

  /* ---- 17. C.FSDSP ------------------------------------------------------ */
  li      s6, 0x6111
  ARM     0x0000a022, 50
  c.fsdsp f8, 0(sp)
  addi    s5, s6, 1
  CK      s6, 0x0000000000006111, 51
  CK      s5, 0x0000000000006112, 52

  /* ================================================================== *
   * the same operations with FS = Initial (53..67)
   * ================================================================== */
  li      t0, 0x2000
  csrw    mstatus, t0                     /* FS: Off -> Initial */
  csrr    t1, mstatus
  CK      t1, 0x0000000a00002000, 53

  la      s9, fbuf
  fld     f1, 0(s9)                       /* a load is legal now */
  fmv.x.d t1, f1
  CK      t1, 0x3ff8000000000000, 54
  fsd     f1, 16(s9)                      /* ... and so is a store */
  ld      t1, 16(s9)
  CK      t1, 0x3ff8000000000000, 55

  flw     f2, 8(s9)                       /* the compressed-width load */
  fmv.x.d t1, f2
  CK      t1, 0xffffffff40490fdb, 56
  fsw     f2, 12(s9)
  lwu     t1, 12(s9)
  CK      t1, 0x0000000040490fdb, 57

  li      t0, 0x4008000000000000          /* 3.0 */
  fmv.d.x f5, t0
  fadd.d  f3, f1, f5                      /* 1.5 + 3.0 */
  fmv.x.d t1, f3
  CK      t1, 0x4012000000000000, 58

  li      t0, 0xc0000000                  /* -2.0f */
  fmv.w.x f4, t0
  fmv.x.d t1, f4
  CK      t1, 0xffffffffc0000000, 59
  fmv.x.w t1, f4
  CK      t1, 0xffffffffc0000000, 60

  csrr    t1, fflags                      /* nothing above raised a flag */
  CK      t1, 0x0000000000000000, 61
  csrr    t1, fcsr
  CK      t1, 0x0000000000000000, 62
  csrr    t1, frm
  CK      t1, 0x0000000000000000, 63
  li      t4, 3
  csrw    frm, t4
  csrr    t1, frm
  CK      t1, 0x0000000000000003, 64
  csrr    t1, fcsr                        /* frm in bits 7:5, fflags in 4:0 */
  CK      t1, 0x0000000000000060, 65
  li      t4, 0
  csrw    fcsr, t4

  /* every trapping instruction trapped exactly once, and none other */
  CK      s8, 0x0000000000000011, 66

  csrr    t1, mstatus                     /* FS is Dirty now, and SD is set */
  CK      t1, 0x8000000a00006000, 67

  li      a0, 0
  ret

  /* ===================================================================
   * trap handler: verify the armed expectation, then resume after the
   * trapped instruction (mtval[1:0] gives that instruction's length).
   * =================================================================== */
  .align 2
handler:
  csrr    t0, mcause
  csrr    t1, mtval
  csrr    t2, mepc
#ifdef PROBE
  mv      a1, t0                          /* dump the observed trap record */
  mv      a2, t1
  mv      a3, t2
#else
  bne     t0, s0, .Lhbad
  bne     t1, s2, .Lhval
  bne     t2, s4, .Lhpc
#endif
  andi    t3, t1, 3
  li      t4, 3
  beq     t3, t4, .Lh32
  addi    t2, t2, 2
  j       .Lhgo
.Lh32:
  addi    t2, t2, 4
.Lhgo:
  csrw    mepc, t2
  addi    s8, s8, 1
  mret

#ifndef PROBE
.Lhbad:
  li      s7, 1                           /* which field of the record failed */
  mv      a0, s3
  ret
.Lhval:
  li      s7, 2
  mv      a0, s3
  ret
.Lhpc:
  li      s7, 3
  mv      a0, s3
  ret
#endif

  .section .data
  .align 3
fbuf:
  .dword 0x3ff8000000000000               /* 1.5, at offset 0  */
  .word  0x40490fdb                       /* pi, as a single, at offset 8 */
  .word  0
  .dword 0                                /* offset 16 */

  .section .note.GNU-stack, "", @progbits
