/* SPDX-License-Identifier: MIT
 *
 * Corpus program — F and D floating-point coverage (E2-RV2 / RV-C increment 2).
 *
 * One self-checking program over every FP instruction class the core implements:
 * arithmetic (add/sub/mul/div/sqrt and the four fused forms), sign injection,
 * min/max, comparisons, classification, conversions, moves, loads/stores
 * (including the compressed FP forms), the rounding modes, the accrued
 * exception flags, NaNs and subnormals, and the mstatus.FS clean-to-dirty
 * transition.
 *
 * HOW THE EXPECTED VALUES WERE PRODUCED
 * Every constant compared against below is the value the Spike golden model
 * wrote into a register during a `--log-commits` run of *this same source*,
 * built with `-DPROBE`. In PROBE mode the CK macro dumps the register under
 * test into s10 instead of comparing it, so the k-th `s10` write in the commit
 * log is the expected value of the k-th check here. Nothing is derived from a
 * hand computation, so a check can only pass if the DUT reproduces the golden
 * model bit for bit. Example:
 *
 *   PATH=$PWD/generated/rv_difftest/dtc:$PATH \
 *   generated/rv_difftest/spike/install/bin/spike --isa=rv64imfdc_zicsr \
 *     --log-commits cor_fp_probe.elf 2>&1 | grep -n ' x26 '
 *
 * Register conventions inside this file: t0 holds CSR staging, t3 the raw
 * immediate fed to LDD/LDS, t5 the result read back by CKD/CKW, t6 the CK
 * comparison scratch, s9 the .data buffer address. s10/s11 are written by the
 * PROBE build only. f31 is deliberately never written: check 2 pins that an
 * untouched FP register reads zero at reset. No integer register is read before
 * it is written, and no `misa`/`fence`/`wfi` is used.
 *
 * THREE SPIKE BEHAVIOURS THIS PROGRAM PINS, all read out of --log-commits runs
 * (the DUT has to match the golden model, not the prose):
 *
 *   * mstatus.FS only goes Dirty when FP *state is written* — an FPR write or an
 *     fflags/frm/fcsr write. FSD, FMV.X.D, FCLASS, the comparisons and frflags
 *     only read FP state and leave FS Initial (checks 3 and 7), and a CSR write
 *     may put a Dirty FS back to Initial (check 5).
 *   * FLT and FLE raise NV for a *quiet* NaN operand (Spike calls softfloat's
 *     f64_lt/f64_le), while FEQ stays silent (checks 122 and 129).
 *   * NaN results are the canonical quiet NaN: Spike propagates neither the
 *     payload nor the sign of a NaN operand (checks 306 and 310).
 *
 * `main` returns 0 on success or the id of the first failed check (crt0.S).
 */

  /* CK <reg> <expected> <id> — return <id> from main unless reg == expected.
     The PROBE build replaces the comparison with a dump of the register and of
     the live fflags into s10/s11, which is what makes the expected constants
     below re-derivable from a Spike log (see the header). */
#ifdef PROBE
  .macro CK reg, want, id
  mv      s10, \reg
  csrr    s11, fflags
  .endm
#else
  .macro CK reg, want, id
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \id
  ret
.Lck\@:
  .endm
#endif

  /* LDD <fd> <bits> — materialise a raw double bit pattern into <fd>. */
  .macro LDD fd, bits
  li      t3, \bits
  fmv.d.x \fd, t3
  .endm

  /* LDS <fd> <bits> — materialise a raw single bit pattern into <fd> (boxed). */
  .macro LDS fd, bits
  li      t3, \bits
  fmv.w.x \fd, t3
  .endm

  /* CKD <fd> <want> <id> — compare the raw 64 bits of <fd>, so a NaN-boxing
     difference is a failure even when the numeric value would compare equal. */
  .macro CKD fd, want, id
  fmv.x.d t5, \fd
  CK      t5, \want, \id
  .endm

  /* CKW <fd> <want> <id> — compare the low 32 bits of <fd>, sign-extended into
     the 64-bit destination by FMV.X.W (the F-extension move contract). */
  .macro CKW fd, want, id
  fmv.x.w t5, \fd
  CK      t5, \want, \id
  .endm

  /* CVTI <op> <sz> <rm> <bits> <want> <id> — convert one operand to an integer
     with an explicit rounding mode. <sz> picks the source format. */
  .macro CVTI op, sz, rm, bits, want, id
  .ifc \sz,s
  LDS     f1, \bits
  .else
  LDD     f1, \bits
  .endif
  \op     t1, f1, \rm
  CK      t1, \want, \id
  .endm

  /* CVTD <op> <sz> <frmcode> <bits> <want> <id> — same, but the instruction uses
     rm = dyn (the assembler default) and frm carries the rounding mode. */
  .macro CVTD op, sz, frmcode, bits, want, id
  .ifc \sz,s
  LDS     f1, \bits
  .else
  LDD     f1, \bits
  .endif
  li      t0, \frmcode
  csrw    frm, t0
  \op     t1, f1
  CK      t1, \want, \id
  .endm

  /* RNDD <rm> <wA> <wB> <wC> <idA> <idB> <idC> — the rounding-mode probe in
     double precision: a tie at 1+2^-53, the negative tie, and a value just above
     the tie. The three answers together separate all five rounding modes. */
  .macro RNDD rm, wA, wB, wC, idA, idB, idC
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x3ca0000000000000
  fadd.d  f3, f1, f2, \rm
  CKD     f3, \wA, \idA
  LDD     f1, 0xbff0000000000000
  LDD     f2, 0xbca0000000000000
  fadd.d  f3, f1, f2, \rm
  CKD     f3, \wB, \idB
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x3ca0000002000000
  fadd.d  f3, f1, f2, \rm
  CKD     f3, \wC, \idC
  .endm

  /* RNDDY <frmcode> <wA> <wB> <wC> <idA> <idB> <idC> — as RNDD, but the adds
     carry rm = dyn and the mode is programmed into frm first. */
  .macro RNDDY frmcode, wA, wB, wC, idA, idB, idC
  li      t0, \frmcode
  csrw    frm, t0
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x3ca0000000000000
  fadd.d  f3, f1, f2
  CKD     f3, \wA, \idA
  LDD     f1, 0xbff0000000000000
  LDD     f2, 0xbca0000000000000
  fadd.d  f3, f1, f2
  CKD     f3, \wB, \idB
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x3ca0000002000000
  fadd.d  f3, f1, f2
  CKD     f3, \wC, \idC
  .endm

  /* RNDS <rm> … — the same three-op probe in single precision. */
  .macro RNDS rm, wA, wB, wC, idA, idB, idC
  LDS     f1, 0x3f800000
  LDS     f2, 0x33800000
  fadd.s  f3, f1, f2, \rm
  CKD     f3, \wA, \idA
  LDS     f1, 0xbf800000
  LDS     f2, 0xb3800000
  fadd.s  f3, f1, f2, \rm
  CKD     f3, \wB, \idB
  LDS     f1, 0x3f800000
  LDS     f2, 0x33800002
  fadd.s  f3, f1, f2, \rm
  CKD     f3, \wC, \idC
  .endm

  .section .text
  .globl main
  .align 2
main:
  /* ================================================================== *
   * 0. FP enable and the mstatus.FS transitions (1..7).
   *
   * Spike sets FS to Dirty only when an instruction WRITES floating-point
   * state: an FPR write (FLD, FMV.D.X, arithmetic) or an fflags/frm/fcsr
   * write. Instructions that only read FP state — FSD, FMV.X.D, the
   * comparisons, FCLASS, frflags — leave FS alone, and a CSR write can put
   * FS back to Initial. The five mstatus checks below pin exactly that.
   * ================================================================== */
  li      t0, 0x2000                      /* mstatus.FS = 01 (Initial) */
  csrs    mstatus, t0
  csrr    t1, mstatus
  CK      t1, 0x0000000a00002000, 1                     /* FS = Initial, SD clear */

  fmv.x.d t1, f31                         /* f31 was never written */
  CK      t1, 0x0000000000000000, 2                     /* an untouched FP register reads 0 */
  csrr    t1, mstatus
  CK      t1, 0x0000000a00002000, 3                     /* reading an FPR left FS clean */

  la      s9, fbuf
  li      t0, 0x3ff8000000000000
  fmv.d.x f1, t0                          /* ... but writing one dirties it */
  csrr    t1, mstatus
  CK      t1, 0x8000000a00006000, 4                     /* FS = Dirty, SD set */

  li      t0, 0x4000
  csrc    mstatus, t0                     /* FS back to Initial */
  csrr    t1, mstatus
  CK      t1, 0x0000000a00002000, 5
  fld     f1, 0(s9)                       /* a load writes an FPR ... */
  csrr    t1, mstatus
  CK      t1, 0x8000000a00006000, 6                     /* ... so FS is Dirty again */

  li      t0, 0x4000
  csrc    mstatus, t0                     /* FS back to Initial */
  fsd     f1, 8(s9)                       /* a store only READS fp state */
  csrr    t1, mstatus
  CK      t1, 0x0000000a00002000, 7                     /* so FS is still Initial */

  /* ================================================================== *
   * 1. D arithmetic (8..18)
   * ================================================================== */
  LDD     f1, 0x3ff8000000000000          /* 1.5  */
  LDD     f2, 0x4002000000000000          /* 2.25 */
  fadd.d  f3, f1, f2
  CKD     f3, 0x400e000000000000, 8
  fsub.d  f3, f1, f2
  CKD     f3, 0xbfe8000000000000, 9
  fmul.d  f3, f1, f2
  CKD     f3, 0x400b000000000000, 10
  fdiv.d  f3, f1, f2                      /* 2/3: inexact, round to nearest */
  CKD     f3, 0x3fe5555555555555, 11

  LDD     f1, 0x4002000000000000
  fsqrt.d f3, f1
  CKD     f3, 0x3ff8000000000000, 12                    /* sqrt(2.25) = 1.5 exactly */
  LDD     f1, 0x4000000000000000
  fsqrt.d f3, f1
  CKD     f3, 0x3ff6a09e667f3bcd, 13                    /* sqrt(2) is inexact */

  LDD     f1, 0x3ff8000000000000          /* 1.5  */
  LDD     f2, 0x4002000000000000          /* 2.25 */
  LDD     f4, 0x3fd0000000000000          /* 0.25 */
  fmadd.d f3, f1, f2, f4
  CKD     f3, 0x400d000000000000, 14
  fmsub.d f3, f1, f2, f4
  CKD     f3, 0x4009000000000000, 15
  fnmsub.d f3, f1, f2, f4
  CKD     f3, 0xc009000000000000, 16
  fnmadd.d f3, f1, f2, f4
  CKD     f3, 0xc00d000000000000, 17

  /* (1+2^-52)*(1-2^-52) - 1 is exactly -2^-104: a single-rounding FMA returns
     it, an unfused multiply-then-add rounds the intermediate to 1.0 and adds
     -1.0, giving +0. This one check separates the two implementations. */
  LDD     f1, 0x3ff0000000000001
  LDD     f2, 0x3feffffffffffffe
  LDD     f4, 0xbff0000000000000
  fmadd.d f3, f1, f2, f4
  CKD     f3, 0xb970000000000000, 18

  /* ================================================================== *
   * 2. S arithmetic (19..29) — every result is NaN-boxed, so these
   *    checks also pin the S-result boxing contract.
   * ================================================================== */
  LDS     f1, 0x3fc00000                  /* 1.5f  */
  LDS     f2, 0x40100000                  /* 2.25f */
  fadd.s  f3, f1, f2
  CKD     f3, 0xffffffff40700000, 19
  fsub.s  f3, f1, f2
  CKD     f3, 0xffffffffbf400000, 20
  fmul.s  f3, f1, f2
  CKD     f3, 0xffffffff40580000, 21
  fdiv.s  f3, f1, f2
  CKD     f3, 0xffffffff3f2aaaab, 22

  LDS     f1, 0x40100000
  fsqrt.s f3, f1
  CKD     f3, 0xffffffff3fc00000, 23
  LDS     f1, 0x40000000
  fsqrt.s f3, f1
  CKD     f3, 0xffffffff3fb504f3, 24

  LDS     f1, 0x3fc00000
  LDS     f2, 0x40100000
  LDS     f4, 0x3e800000                  /* 0.25f */
  fmadd.s f3, f1, f2, f4
  CKD     f3, 0xffffffff40680000, 25
  fmsub.s f3, f1, f2, f4
  CKD     f3, 0xffffffff40480000, 26
  fnmsub.s f3, f1, f2, f4
  CKD     f3, 0xffffffffc0480000, 27
  fnmadd.s f3, f1, f2, f4
  CKD     f3, 0xffffffffc0680000, 28

  LDS     f1, 0x3f800001                  /* 1+2^-23 */
  LDS     f2, 0x3f7ffffe                  /* 1-2^-23 */
  LDS     f4, 0xbf800000                  /* -1.0f   */
  fmadd.s f3, f1, f2, f4
  CKD     f3, 0xffffffffa8800000, 29                    /* exactly -2^-46 with one rounding */

  /* ================================================================== *
   * 3. rounding modes, explicit rm field (30..44)
   * ================================================================== */
  RNDD    rne, 0x3ff0000000000000, 0xbff0000000000000, 0x3ff0000000000001, 30, 31, 32
  RNDD    rtz, 0x3ff0000000000000, 0xbff0000000000000, 0x3ff0000000000000, 33, 34, 35
  RNDD    rdn, 0x3ff0000000000000, 0xbff0000000000001, 0x3ff0000000000000, 36, 37, 38
  RNDD    rup, 0x3ff0000000000001, 0xbff0000000000000, 0x3ff0000000000001, 39, 40, 41
  RNDD    rmm, 0x3ff0000000000001, 0xbff0000000000001, 0x3ff0000000000001, 42, 43, 44

  /* ================================================================== *
   * 4. rounding modes through frm + rm = dyn (45..59)
   * ================================================================== */
  RNDDY   0, 0x3ff0000000000000, 0xbff0000000000000, 0x3ff0000000000001, 45, 46, 47   /* RNE */
  RNDDY   1, 0x3ff0000000000000, 0xbff0000000000000, 0x3ff0000000000000, 48, 49, 50   /* RTZ */
  RNDDY   2, 0x3ff0000000000000, 0xbff0000000000001, 0x3ff0000000000000, 51, 52, 53   /* RDN */
  RNDDY   3, 0x3ff0000000000001, 0xbff0000000000000, 0x3ff0000000000001, 54, 55, 56   /* RUP */
  RNDDY   4, 0x3ff0000000000001, 0xbff0000000000001, 0x3ff0000000000001, 57, 58, 59   /* RMM */

  /* ================================================================== *
   * 5. rounding modes in single precision (60..74)
   * ================================================================== */
  RNDS    rne, 0xffffffff3f800000, 0xffffffffbf800000, 0xffffffff3f800001, 60, 61, 62
  RNDS    rtz, 0xffffffff3f800000, 0xffffffffbf800000, 0xffffffff3f800000, 63, 64, 65
  RNDS    rdn, 0xffffffff3f800000, 0xffffffffbf800001, 0xffffffff3f800000, 66, 67, 68
  RNDS    rup, 0xffffffff3f800001, 0xffffffffbf800000, 0xffffffff3f800001, 69, 70, 71
  RNDS    rmm, 0xffffffff3f800001, 0xffffffffbf800001, 0xffffffff3f800001, 72, 73, 74
  li      t0, 0
  csrw    frm, t0                         /* back to RNE for the rest */

  /* ================================================================== *
   * 6. sign injection, D (75..81)
   * ================================================================== */
  LDD     f1, 0x3ff8000000000000          /* +1.5 */
  LDD     f2, 0xbff0000000000000          /* -1.0 */
  fsgnj.d f3, f1, f2
  CKD     f3, 0xbff8000000000000, 75                    /* magnitude of a, sign of b */
  fsgnjn.d f3, f1, f2
  CKD     f3, 0x3ff8000000000000, 76
  fsgnjx.d f3, f1, f2
  CKD     f3, 0xbff8000000000000, 77
  fsgnj.d f3, f2, f2
  CKD     f3, 0xbff0000000000000, 78
  fsgnjx.d f3, f2, f2
  CKD     f3, 0x3ff0000000000000, 79                    /* equal signs xor to positive */
  LDD     f1, 0x7ff8000000000000          /* qNaN (here a: sign is copied) */
  LDD     f2, 0xbff0000000000000
  fsgnj.d f3, f1, f2
  CKD     f3, 0xfff8000000000000, 80                    /* payload survives, sign inverts */
  fsgnjx.d f3, f1, f1
  CKD     f3, 0x7ff8000000000000, 81                    /* positive sign again */

  /* ================================================================== *
   * 7. sign injection, S (82..86)
   * ================================================================== */
  LDS     f1, 0x3fc00000
  LDS     f2, 0xbf800000
  fsgnj.s f3, f1, f2
  CKD     f3, 0xffffffffbfc00000, 82
  fsgnjn.s f3, f1, f2
  CKD     f3, 0xffffffff3fc00000, 83
  fsgnjx.s f3, f1, f2
  CKD     f3, 0xffffffffbfc00000, 84
  LDS     f1, 0x7fc00000                  /* qNaNf */
  fsgnj.s f3, f1, f2
  CKD     f3, 0xffffffffffc00000, 85
  fsgnjx.s f3, f1, f1
  CKD     f3, 0xffffffff7fc00000, 86

  /* ================================================================== *
   * 8. fmin/fmax, D (87..96)
   * ================================================================== */
  LDD     f1, 0x3ff8000000000000          /* +1.5  */
  LDD     f2, 0xc004000000000000          /* -2.5  */
  fmin.d  f3, f1, f2
  CKD     f3, 0xc004000000000000, 87
  fmax.d  f3, f1, f2
  CKD     f3, 0x3ff8000000000000, 88
  fmin.d  f3, f2, f1
  CKD     f3, 0xc004000000000000, 89
  fmax.d  f3, f2, f1
  CKD     f3, 0x3ff8000000000000, 90

  LDD     f1, 0x0000000000000000          /* +0.0 */
  LDD     f2, 0x8000000000000000          /* -0.0 */
  fmin.d  f3, f1, f2
  CKD     f3, 0x8000000000000000, 91                    /* fmin(+0,-0) = -0 */
  fmax.d  f3, f1, f2
  CKD     f3, 0x0000000000000000, 92                    /* fmax(+0,-0) = +0 */
  fmin.d  f3, f2, f1
  CKD     f3, 0x8000000000000000, 93

  LDD     f1, 0x7ff8000000000000          /* quiet NaN */
  LDD     f2, 0x3ff0000000000000          /* +1.0 */
  fmin.d  f3, f1, f2
  CKD     f3, 0x3ff0000000000000, 94                    /* the non-NaN operand wins */
  fmax.d  f3, f2, f1
  CKD     f3, 0x3ff0000000000000, 95
  fmin.d  f3, f1, f1
  CKD     f3, 0x7ff8000000000000, 96                    /* both NaN -> canonical NaN */

  /* signalling NaN operand: the non-NaN operand still wins, and NV is raised */
  csrw    fflags, zero
  LDD     f1, 0x7ff0000000000001          /* sNaN */
  LDD     f2, 0x3ff0000000000000
  fmin.d  f3, f1, f2
  CKD     f3, 0x3ff0000000000000, 97
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 98
  csrw    fflags, zero

  /* ================================================================== *
   * 9. fmin/fmax, S (99..103)
   * ================================================================== */
  LDS     f1, 0x00000000
  LDS     f2, 0x80000000
  fmin.s  f3, f1, f2
  CKD     f3, 0xffffffff80000000, 99
  fmax.s  f3, f1, f2
  CKD     f3, 0xffffffff00000000, 100
  LDS     f1, 0x7fc00000
  LDS     f2, 0x3f800000
  fmin.s  f3, f1, f2
  CKD     f3, 0xffffffff3f800000, 101
  fmax.s  f3, f2, f1
  CKD     f3, 0xffffffff3f800000, 102
  fmax.s  f3, f1, f1
  CKD     f3, 0xffffffff7fc00000, 103

  /* ================================================================== *
   * 10. comparisons, D (104..122)
   * ================================================================== */
  LDD     f1, 0x3ff0000000000000          /* 1.0 */
  LDD     f2, 0x4000000000000000          /* 2.0 */
  feq.d   t1, f1, f2
  CK      t1, 0x0000000000000000, 104
  flt.d   t1, f1, f2
  CK      t1, 0x0000000000000001, 105
  fle.d   t1, f1, f2
  CK      t1, 0x0000000000000001, 106
  feq.d   t1, f2, f2
  CK      t1, 0x0000000000000001, 107
  flt.d   t1, f2, f2
  CK      t1, 0x0000000000000000, 108
  fle.d   t1, f2, f2
  CK      t1, 0x0000000000000001, 109
  feq.d   t1, f2, f1
  CK      t1, 0x0000000000000000, 110
  flt.d   t1, f2, f1
  CK      t1, 0x0000000000000000, 111
  fle.d   t1, f2, f1
  CK      t1, 0x0000000000000000, 112

  /* a quiet NaN compares false against everything, and silently */
  csrw    fflags, zero
  LDD     f4, 0x7ff8000000000000          /* qNaN */
  feq.d   t1, f4, f1
  CK      t1, 0x0000000000000000, 113
  flt.d   t1, f4, f1
  CK      t1, 0x0000000000000000, 114
  fle.d   t1, f4, f1
  CK      t1, 0x0000000000000000, 115
  feq.d   t1, f1, f4
  CK      t1, 0x0000000000000000, 116
  flt.d   t1, f1, f4
  CK      t1, 0x0000000000000000, 117
  fle.d   t1, f1, f4
  CK      t1, 0x0000000000000000, 118
  feq.d   t1, f4, f4
  CK      t1, 0x0000000000000000, 119
  flt.d   t1, f4, f4
  CK      t1, 0x0000000000000000, 120
  fle.d   t1, f4, f4
  CK      t1, 0x0000000000000000, 121
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 122                   /* FEQ is silent; FLT and FLE are not */

  /* ================================================================== *
   * 11. comparisons, S (123..132)
   * ================================================================== */
  LDS     f1, 0x3f800000
  LDS     f2, 0x40000000
  feq.s   t1, f1, f2
  CK      t1, 0x0000000000000000, 123
  flt.s   t1, f1, f2
  CK      t1, 0x0000000000000001, 124
  fle.s   t1, f1, f2
  CK      t1, 0x0000000000000001, 125
  csrw    fflags, zero
  LDS     f4, 0x7fc00000                  /* qNaNf */
  feq.s   t1, f4, f4
  CK      t1, 0x0000000000000000, 126
  flt.s   t1, f4, f1
  CK      t1, 0x0000000000000000, 127
  fle.s   t1, f1, f4
  CK      t1, 0x0000000000000000, 128
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 129

  /* a signalling NaN does signal, in comparison as in arithmetic */
  csrw    fflags, zero
  LDS     f4, 0x7f800001                  /* sNaNf */
  flt.s   t1, f4, f1
  CK      t1, 0x0000000000000000, 130
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 131
  feq.s   t1, f4, f4
  CK      t1, 0x0000000000000000, 132
  csrw    fflags, zero

  /* ================================================================== *
   * 12. fclass, D (133..142)
   * ================================================================== */
  LDD     f1, 0x0000000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000010, 133                   /* +0     */
  LDD     f1, 0x8000000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000008, 134                   /* -0     */
  LDD     f1, 0x7ff0000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000080, 135                   /* +inf   */
  LDD     f1, 0xfff0000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000001, 136                   /* -inf   */
  LDD     f1, 0x7ff8000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000200, 137                   /* qNaN   */
  LDD     f1, 0x7ff0000000000001
  fclass.d t1, f1
  CK      t1, 0x0000000000000100, 138                   /* sNaN   */
  LDD     f1, 0x3ff8000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000040, 139                   /* normal */
  LDD     f1, 0xbff8000000000000
  fclass.d t1, f1
  CK      t1, 0x0000000000000002, 140                   /* negative normal */
  LDD     f1, 0x0000000000000001
  fclass.d t1, f1
  CK      t1, 0x0000000000000020, 141                   /* positive subnormal */
  LDD     f1, 0x8000000000000001
  fclass.d t1, f1
  CK      t1, 0x0000000000000004, 142                   /* negative subnormal */

  /* ================================================================== *
   * 13. fclass, S (143..152)
   * ================================================================== */
  LDS     f1, 0x00000000
  fclass.s t1, f1
  CK      t1, 0x0000000000000010, 143
  LDS     f1, 0x80000000
  fclass.s t1, f1
  CK      t1, 0x0000000000000008, 144
  LDS     f1, 0x7f800000
  fclass.s t1, f1
  CK      t1, 0x0000000000000080, 145
  LDS     f1, 0xff800000
  fclass.s t1, f1
  CK      t1, 0x0000000000000001, 146
  LDS     f1, 0x7fc00000
  fclass.s t1, f1
  CK      t1, 0x0000000000000200, 147
  LDS     f1, 0x7f800001
  fclass.s t1, f1
  CK      t1, 0x0000000000000100, 148
  LDS     f1, 0x3fc00000
  fclass.s t1, f1
  CK      t1, 0x0000000000000040, 149
  LDS     f1, 0xbfc00000
  fclass.s t1, f1
  CK      t1, 0x0000000000000002, 150
  LDS     f1, 0x00000001
  fclass.s t1, f1
  CK      t1, 0x0000000000000020, 151
  LDS     f1, 0x80000001
  fclass.s t1, f1
  CK      t1, 0x0000000000000004, 152

  /* ================================================================== *
   * 14. FP -> integer conversions (153..)
   *     2.5 is a tie, 2.7 is just above a tie: the pair separates RNE,
   *     RMM and RTZ/RUP/RDN; the negative tie separates RTZ from RDN.
   * ================================================================== */
  CVTI    fcvt.w.s, s, rne, 0x40200000, 0x0000000000000002, 153
  CVTI    fcvt.w.s, s, rtz, 0x40200000, 0x0000000000000002, 154
  CVTI    fcvt.w.s, s, rdn, 0x40200000, 0x0000000000000002, 155
  CVTI    fcvt.w.s, s, rup, 0x40200000, 0x0000000000000003, 156
  CVTI    fcvt.w.s, s, rmm, 0x40200000, 0x0000000000000003, 157
  CVTI    fcvt.w.s, s, rne, 0xc0200000, 0xfffffffffffffffe, 158
  CVTI    fcvt.w.s, s, rtz, 0xc0200000, 0xfffffffffffffffe, 159
  CVTI    fcvt.w.s, s, rdn, 0xc0200000, 0xfffffffffffffffd, 160
  CVTI    fcvt.w.s, s, rup, 0xc0200000, 0xfffffffffffffffe, 161
  CVTI    fcvt.w.s, s, rmm, 0xc0200000, 0xfffffffffffffffd, 162
  CVTI    fcvt.w.s, s, rne, 0x402ccccd, 0x0000000000000003, 163
  CVTI    fcvt.w.s, s, rtz, 0x402ccccd, 0x0000000000000002, 164
  CVTI    fcvt.w.s, s, rdn, 0x402ccccd, 0x0000000000000002, 165
  CVTI    fcvt.w.s, s, rup, 0x402ccccd, 0x0000000000000003, 166
  CVTI    fcvt.w.s, s, rmm, 0x402ccccd, 0x0000000000000003, 167

  CVTI    fcvt.w.d, d, rne, 0x4004000000000000, 0x0000000000000002, 168
  CVTI    fcvt.w.d, d, rtz, 0x4004000000000000, 0x0000000000000002, 169
  CVTI    fcvt.w.d, d, rdn, 0x4004000000000000, 0x0000000000000002, 170
  CVTI    fcvt.w.d, d, rup, 0x4004000000000000, 0x0000000000000003, 171
  CVTI    fcvt.w.d, d, rmm, 0x4004000000000000, 0x0000000000000003, 172
  CVTI    fcvt.w.d, d, rne, 0xc004000000000000, 0xfffffffffffffffe, 173
  CVTI    fcvt.w.d, d, rtz, 0xc004000000000000, 0xfffffffffffffffe, 174
  CVTI    fcvt.w.d, d, rdn, 0xc004000000000000, 0xfffffffffffffffd, 175
  CVTI    fcvt.w.d, d, rup, 0xc004000000000000, 0xfffffffffffffffe, 176
  CVTI    fcvt.w.d, d, rmm, 0xc004000000000000, 0xfffffffffffffffd, 177
  CVTI    fcvt.w.d, d, rne, 0x400599999999999a, 0x0000000000000003, 178
  CVTI    fcvt.w.d, d, rtz, 0x400599999999999a, 0x0000000000000002, 179
  CVTI    fcvt.w.d, d, rdn, 0x400599999999999a, 0x0000000000000002, 180
  CVTI    fcvt.w.d, d, rup, 0x400599999999999a, 0x0000000000000003, 181
  CVTI    fcvt.w.d, d, rmm, 0x400599999999999a, 0x0000000000000003, 182

  /* unsigned word: the tie still rounds, and a negative input saturates */
  CVTI    fcvt.wu.s, s, rne, 0x40200000, 0x0000000000000002, 183
  CVTI    fcvt.wu.s, s, rtz, 0x40200000, 0x0000000000000002, 184
  CVTI    fcvt.wu.s, s, rdn, 0x40200000, 0x0000000000000002, 185
  CVTI    fcvt.wu.s, s, rup, 0x40200000, 0x0000000000000003, 186
  CVTI    fcvt.wu.s, s, rmm, 0x40200000, 0x0000000000000003, 187
  CVTI    fcvt.wu.s, s, rne, 0xc0200000, 0x0000000000000000, 188
  CVTI    fcvt.wu.d, d, rne, 0x4004000000000000, 0x0000000000000002, 189
  CVTI    fcvt.wu.d, d, rtz, 0x4004000000000000, 0x0000000000000002, 190
  CVTI    fcvt.wu.d, d, rdn, 0x4004000000000000, 0x0000000000000002, 191
  CVTI    fcvt.wu.d, d, rup, 0x4004000000000000, 0x0000000000000003, 192
  CVTI    fcvt.wu.d, d, rmm, 0x4004000000000000, 0x0000000000000003, 193
  CVTI    fcvt.wu.d, d, rne, 0xc004000000000000, 0x0000000000000000, 194

  /* long: the same tie, now the saturation boundary is 2^63 */
  CVTI    fcvt.l.s, s, rne, 0x40200000, 0x0000000000000002, 195
  CVTI    fcvt.l.s, s, rtz, 0x40200000, 0x0000000000000002, 196
  CVTI    fcvt.l.s, s, rdn, 0x40200000, 0x0000000000000002, 197
  CVTI    fcvt.l.s, s, rup, 0x40200000, 0x0000000000000003, 198
  CVTI    fcvt.l.s, s, rmm, 0x40200000, 0x0000000000000003, 199
  CVTI    fcvt.l.s, s, rne, 0xc0200000, 0xfffffffffffffffe, 200
  CVTI    fcvt.l.s, s, rtz, 0xc0200000, 0xfffffffffffffffe, 201
  CVTI    fcvt.l.s, s, rdn, 0xc0200000, 0xfffffffffffffffd, 202
  CVTI    fcvt.l.s, s, rup, 0xc0200000, 0xfffffffffffffffe, 203
  CVTI    fcvt.l.s, s, rmm, 0xc0200000, 0xfffffffffffffffd, 204

  CVTI    fcvt.l.d, d, rne, 0x4004000000000000, 0x0000000000000002, 205
  CVTI    fcvt.l.d, d, rtz, 0x4004000000000000, 0x0000000000000002, 206
  CVTI    fcvt.l.d, d, rdn, 0x4004000000000000, 0x0000000000000002, 207
  CVTI    fcvt.l.d, d, rup, 0x4004000000000000, 0x0000000000000003, 208
  CVTI    fcvt.l.d, d, rmm, 0x4004000000000000, 0x0000000000000003, 209
  CVTI    fcvt.l.d, d, rne, 0xc004000000000000, 0xfffffffffffffffe, 210
  CVTI    fcvt.l.d, d, rtz, 0xc004000000000000, 0xfffffffffffffffe, 211
  CVTI    fcvt.l.d, d, rdn, 0xc004000000000000, 0xfffffffffffffffd, 212
  CVTI    fcvt.l.d, d, rup, 0xc004000000000000, 0xfffffffffffffffe, 213
  CVTI    fcvt.l.d, d, rmm, 0xc004000000000000, 0xfffffffffffffffd, 214

  CVTI    fcvt.lu.s, s, rne, 0x40200000, 0x0000000000000002, 215
  CVTI    fcvt.lu.s, s, rtz, 0x40200000, 0x0000000000000002, 216
  CVTI    fcvt.lu.s, s, rdn, 0x40200000, 0x0000000000000002, 217
  CVTI    fcvt.lu.s, s, rup, 0x40200000, 0x0000000000000003, 218
  CVTI    fcvt.lu.s, s, rmm, 0x40200000, 0x0000000000000003, 219
  CVTI    fcvt.lu.d, d, rne, 0x4004000000000000, 0x0000000000000002, 220
  CVTI    fcvt.lu.d, d, rtz, 0x4004000000000000, 0x0000000000000002, 221
  CVTI    fcvt.lu.d, d, rdn, 0x4004000000000000, 0x0000000000000002, 222
  CVTI    fcvt.lu.d, d, rup, 0x4004000000000000, 0x0000000000000003, 223
  CVTI    fcvt.lu.d, d, rmm, 0x4004000000000000, 0x0000000000000003, 224

  /* the same conversions with rm = dyn, the mode programmed through frm */
  CVTD    fcvt.w.d, d, 0, 0x4004000000000000, 0x0000000000000002, 225
  CVTD    fcvt.w.d, d, 1, 0x4004000000000000, 0x0000000000000002, 226
  CVTD    fcvt.w.d, d, 2, 0x4004000000000000, 0x0000000000000002, 227
  CVTD    fcvt.w.d, d, 3, 0x4004000000000000, 0x0000000000000003, 228
  CVTD    fcvt.w.d, d, 4, 0x4004000000000000, 0x0000000000000003, 229
  CVTD    fcvt.l.s, s, 0, 0xc0200000, 0xfffffffffffffffe, 230
  CVTD    fcvt.l.s, s, 1, 0xc0200000, 0xfffffffffffffffe, 231
  CVTD    fcvt.l.s, s, 2, 0xc0200000, 0xfffffffffffffffd, 232
  CVTD    fcvt.l.s, s, 3, 0xc0200000, 0xfffffffffffffffe, 233
  CVTD    fcvt.l.s, s, 4, 0xc0200000, 0xfffffffffffffffd, 234
  li      t0, 0
  csrw    frm, t0

  /* saturation / invalid input: the result is the largest representable
     magnitude and NV is raised (the flag is checked after each group) */
  csrw    fflags, zero
  LDD     f1, 0x4202a05f20000000          /* 1e10 */
  fcvt.w.d t1, f1, rne
  CK      t1, 0x000000007fffffff, 235
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 236
  csrw    fflags, zero
  LDD     f1, 0xc202a05f20000000
  fcvt.w.d t1, f1, rne
  CK      t1, 0xffffffff80000000, 237
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 238
  csrw    fflags, zero
  LDD     f1, 0x46293e5939a08cea          /* 1e30 */
  fcvt.l.d t1, f1, rne
  CK      t1, 0x7fffffffffffffff, 239
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 240
  csrw    fflags, zero
  LDD     f1, 0x7ff8000000000000          /* qNaN -> NaN is invalid */
  fcvt.w.d t1, f1, rne
  CK      t1, 0x000000007fffffff, 241
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 242
  csrw    fflags, zero
  LDD     f1, 0xbff0000000000000          /* -1.0 into an unsigned long */
  fcvt.lu.d t1, f1, rne
  CK      t1, 0x0000000000000000, 243
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 244
  csrw    fflags, zero
  LDS     f1, 0xbf800000                  /* -1.0f into an unsigned word */
  fcvt.wu.s t1, f1, rne
  CK      t1, 0x0000000000000000, 245
  csrr    t2, fflags
  CK      t2, 0x0000000000000010, 246
  csrw    fflags, zero

  /* ================================================================== *
   * 15. integer -> FP conversions (247..)
   * ================================================================== */
  li      t2, -1
  fcvt.s.w f3, t2
  CKD     f3, 0xffffffffbf800000, 247                   /* -1.0f, NaN-boxed */
  fcvt.d.w f3, t2
  CKD     f3, 0xbff0000000000000, 248
  fcvt.s.l f3, t2
  CKD     f3, 0xffffffffbf800000, 249
  fcvt.d.l f3, t2
  CKD     f3, 0xbff0000000000000, 250

  /* 0xffffffff is 4294967295 as unsigned: exact in double, rounded in single */
  li      t2, 0xffffffff
  fcvt.s.wu f3, t2
  CKD     f3, 0xffffffff4f800000, 251
  fcvt.d.wu f3, t2
  CKD     f3, 0x41efffffffe00000, 252

  li      t2, -1
  csrw    fflags, zero
  fcvt.s.wu f3, t2                       /* 2^64-1 -> rounds to 2^64 */
  CKD     f3, 0xffffffff4f800000, 253
  csrr    t4, fflags
  CK      t4, 0x0000000000000001, 254
  csrw    fflags, zero
  fcvt.s.lu f3, t2
  CKD     f3, 0xffffffff5f800000, 255
  csrr    t4, fflags
  CK      t4, 0x0000000000000001, 256
  csrw    fflags, zero
  fcvt.d.lu f3, t2
  CKD     f3, 0x43f0000000000000, 257
  csrr    t4, fflags
  CK      t4, 0x0000000000000001, 258
  csrw    fflags, zero

  /* NaN-boxing of the S result seen raw, and the S/D width conversions */
  li      t2, -1
  fcvt.s.w f3, t2
  fmv.x.d t5, f3
  CK      t5, 0xffffffffbf800000, 259
  LDD     f1, 0x3fd5555555555555          /* 1/3 as a double */
  csrw    fflags, zero
  fcvt.s.d f3, f1
  CKD     f3, 0xffffffff3eaaaaab, 260
  csrr    t4, fflags
  CK      t4, 0x0000000000000001, 261
  csrw    fflags, zero
  LDS     f1, 0x3fc00000                  /* 1.5f, exact in double */
  fcvt.d.s f3, f1
  CKD     f3, 0x3ff8000000000000, 262
  csrr    t4, fflags
  CK      t4, 0x0000000000000000, 263

  /* ================================================================== *
   * 16. moves (264..271)
   * ================================================================== */
  li      t2, 0x3f800000
  fmv.w.x f3, t2
  fmv.x.d t5, f3
  CK      t5, 0xffffffff3f800000, 264                   /* a single is NaN-boxed by FMV.W.X */

  li      t2, 0x3ff8000000000000          /* 1.5 as a double */
  fmv.d.x f3, t2
  fmv.x.d t5, f3
  CK      t5, 0x3ff8000000000000, 265
  fmv.x.w t5, f3
  CK      t5, 0x0000000000000000, 266                   /* low 32 bits are zero */

  LDS     f4, 0xc0000000                  /* -2.0f */
  fmv.x.w t5, f4
  CK      t5, 0xffffffffc0000000, 267                   /* FMV.X.W sign-extends bit 31 */

  LDS     f4, 0x3fc00000
  fmv.x.w t5, f4
  CK      t5, 0x000000003fc00000, 268                   /* ... and zero-extends a positive one */

  LDS     f4, 0x3fc00000
  fmv.s   f5, f4
  fmv.x.d t5, f5
  CK      t5, 0xffffffff3fc00000, 269                   /* copy of a boxed single */

  LDD     f4, 0x3ff8000000000000
  fmv.s   f5, f4                          /* the source is not a boxed single: canonical NaN */
  fmv.x.d t5, f5
  CK      t5, 0xffffffff7fc00000, 270

  LDD     f4, 0xbff8000000000000
  fmv.d   f5, f4
  fmv.x.d t5, f5
  CK      t5, 0xbff8000000000000, 271

  /* ================================================================== *
   * 17. loads and stores (272..)
   * ================================================================== */
  la      s9, fbuf
  li      t2, 0x1122334455667788
  sd      t2, 0(s9)
  LDS     f4, 0x3fc00000                  /* 1.5f */
  fsw     f4, 0(s9)
  ld      t5, 0(s9)
  CK      t5, 0x112233443fc00000, 272                   /* FSW wrote only the low 32 bits */

  LDS     f4, 0x00000000
  flw     f4, 0(s9)
  fmv.x.d t5, f4
  CK      t5, 0xffffffff3fc00000, 273                   /* FLW NaN-boxes what it loaded */

  LDD     f4, 0xbff8000000000000
  fsd     f4, 8(s9)
  ld      t5, 8(s9)
  CK      t5, 0xbff8000000000000, 274
  LDD     f5, 0x0000000000000000
  fld     f5, 8(s9)
  fmv.x.d t5, f5
  CK      t5, 0xbff8000000000000, 275

  /* the compressed forms: c.fld/c.fsd need an x8..x15 base and f8..f15 */
  la      a0, fbuf
  LDD     f8, 0x4004000000000000          /* 2.5 */
  c.fsd   f8, 0(a0)
  ld      t5, 0(a0)
  CK      t5, 0x4004000000000000, 276
  LDD     f9, 0x0000000000000000
  c.fld   f9, 0(a0)
  fmv.x.d t5, f9
  CK      t5, 0x4004000000000000, 277

  /* ... and the stack-pointer forms, which name any FPR */
  addi    sp, sp, -16
  LDD     f8, 0xc004000000000000          /* -2.5 */
  c.fsdsp f8, 0(sp)
  ld      t5, 0(sp)
  CK      t5, 0xc004000000000000, 278
  LDD     f9, 0x0000000000000000
  c.fldsp f9, 0(sp)
  fmv.x.d t5, f9
  CK      t5, 0xc004000000000000, 279
  addi    sp, sp, 16

  /* ================================================================== *
   * 18. accrued exception flags (280..)
   * ================================================================== */
  csrw    fflags, zero
  csrr    t1, fflags
  CK      t1, 0x0000000000000000, 280                   /* the write cleared everything */

  /* NX: 1.0 + 2^-60 rounds back to 1.0, inexactly */
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x3c30000000000000
  fadd.d  f3, f1, f2
  CKD     f3, 0x3ff0000000000000, 281
  csrr    t1, fflags
  CK      t1, 0x0000000000000001, 282                   /* NX */
  csrr    t1, fflags
  CK      t1, 0x0000000000000001, 283                   /* reading frflags does not clear it */

  /* DZ: a finite over zero is exactly infinite, and only DZ is raised */
  csrw    fflags, zero
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x0000000000000000
  fdiv.d  f3, f1, f2
  CKD     f3, 0x7ff0000000000000, 284
  csrr    t1, fflags
  CK      t1, 0x0000000000000008, 285                   /* DZ */
  csrw    fflags, zero
  LDD     f1, 0xbff0000000000000
  fdiv.d  f3, f1, f2
  CKD     f3, 0xfff0000000000000, 286                   /* -inf */
  csrr    t1, fflags
  CK      t1, 0x0000000000000008, 287

  /* OF: the largest double times two overflows to infinity, inexactly */
  csrw    fflags, zero
  LDD     f1, 0x7fefffffffffffff
  LDD     f2, 0x4000000000000000
  fmul.d  f3, f1, f2
  CKD     f3, 0x7ff0000000000000, 288
  csrr    t1, fflags
  CK      t1, 0x0000000000000005, 289                   /* OF|NX */
  csrw    fflags, zero
  LDD     f1, 0xffefffffffffffff
  fmul.d  f3, f1, f2
  CKD     f3, 0xfff0000000000000, 290
  csrr    t1, fflags
  CK      t1, 0x0000000000000005, 291

  /* NV: 0/0, inf-inf and sqrt(-1) are all invalid */
  csrw    fflags, zero
  LDD     f1, 0x0000000000000000
  fdiv.d  f3, f1, f1
  CKD     f3, 0x7ff8000000000000, 292                   /* the canonical quiet NaN */
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 293                   /* NV */
  csrw    fflags, zero
  LDD     f1, 0x7ff0000000000000
  fsub.d  f3, f1, f1
  CKD     f3, 0x7ff8000000000000, 294
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 295
  csrw    fflags, zero
  LDD     f1, 0xbff0000000000000
  fsqrt.d f3, f1
  CKD     f3, 0x7ff8000000000000, 296
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 297

  /* UF: a subnormal product is tiny, so the inexact flag comes with it */
  csrw    fflags, zero
  LDD     f1, 0x0000000000000001          /* smallest subnormal */
  LDD     f2, 0x3fe0000000000000          /* 0.5 */
  fmul.d  f3, f1, f2
  CKD     f3, 0x0000000000000000, 298
  csrr    t1, fflags
  CK      t1, 0x0000000000000003, 299                   /* UF|NX */

  /* an exact subnormal result raises nothing at all */
  csrw    fflags, zero
  LDD     f1, 0x0010000000000000          /* smallest normal, halved */
  fdiv.d  f3, f1, f2
  CKD     f3, 0x0020000000000000, 300
  csrr    t1, fflags
  CK      t1, 0x0000000000000000, 301

  /* two flag-producing operations accrue both */
  csrw    fflags, zero
  LDD     f1, 0x7fefffffffffffff
  LDD     f2, 0x4000000000000000
  fmul.d  f3, f1, f2                      /* OF|NX */
  LDD     f1, 0x3ff0000000000000
  LDD     f2, 0x0000000000000000
  fdiv.d  f3, f1, f2                      /* DZ */
  csrr    t1, fflags
  CK      t1, 0x000000000000000d, 302                   /* all three bits */

  /* fcsr is frm:fcsr.fflags, and frflags is its low five bits */
  li      t0, 0x2a
  csrw    fcsr, t0                        /* frm = 1 (RTZ), fflags = 0xa */
  csrr    t1, fcsr
  CK      t1, 0x000000000000002a, 303
  csrr    t1, frm
  CK      t1, 0x0000000000000001, 304
  csrr    t1, fflags
  CK      t1, 0x000000000000000a, 305
  li      t0, 0
  csrw    frm, t0
  csrw    fflags, zero

  /* ================================================================== *
   * 19. NaNs (306..)
   * ================================================================== */
  csrw    fflags, zero
  LDD     f1, 0x7ff8000000000001          /* quiet NaN with a payload */
  LDD     f2, 0x3ff0000000000000
  fadd.d  f3, f1, f2
  CKD     f3, 0x7ff8000000000000, 306                   /* Spike canonicalises the NaN */
  csrr    t1, fflags
  CK      t1, 0x0000000000000000, 307                   /* and nothing is raised */
  csrw    fflags, zero
  LDD     f1, 0x7ff0000000000001          /* signalling NaN */
  fadd.d  f3, f1, f2
  CKD     f3, 0x7ff8000000000000, 308                   /* the canonical quiet NaN */
  csrr    t1, fflags
  CK      t1, 0x0000000000000010, 309                   /* NV */
  csrw    fflags, zero
  LDD     f1, 0xfff8000000000001          /* negative quiet NaN */
  fadd.d  f3, f1, f2
  CKD     f3, 0x7ff8000000000000, 310                   /* canonical NaN, sign dropped */
  csrw    fflags, zero
  LDS     f1, 0x7fc00000
  fadd.s  f3, f1, f1
  CKD     f3, 0xffffffff7fc00000, 311                   /* canonical single, still boxed */
  csrw    fflags, zero

  /* ================================================================== *
   * 20. subnormals (312..)
   * ================================================================== */
  csrw    fflags, zero
  LDD     f1, 0x0000000000000001          /* subnormal operand */
  LDD     f2, 0x3ff0000000000000
  fadd.d  f3, f1, f2
  CKD     f3, 0x3ff0000000000000, 312                   /* absorbed, inexactly */
  csrr    t1, fflags
  CK      t1, 0x0000000000000001, 313
  csrw    fflags, zero
  LDD     f1, 0x0000000000000003
  LDD     f2, 0x3ff0000000000000
  fadd.d  f3, f1, f2
  CKD     f3, 0x3ff0000000000000, 314
  csrr    t1, fflags
  CK      t1, 0x0000000000000001, 315                   /* inexact all the same */
  csrw    fflags, zero
  LDD     f1, 0x0008000000000000          /* a subnormal itself */
  LDD     f2, 0x4000000000000000
  fmul.d  f3, f1, f2
  CKD     f3, 0x0010000000000000, 316                   /* exact, no flag */
  csrr    t1, fflags
  CK      t1, 0x0000000000000000, 317
  csrw    fflags, zero
  LDD     f1, 0x0000000000000001
  fsqrt.d f3, f1
  CKD     f3, 0x1e60000000000000, 318
  csrr    t1, fflags
  CK      t1, 0x0000000000000000, 319                   /* 2^-1074 has an exact root, 2^-537 */
  LDD     f1, 0x0000000000000001
  feq.d   t1, f1, f1
  CK      t1, 0x0000000000000001, 320                   /* subnormals compare equal */
  LDD     f2, 0x8000000000000001
  fmin.d  f3, f1, f2
  CKD     f3, 0x8000000000000001, 321
  fmax.d  f3, f1, f2
  CKD     f3, 0x0000000000000001, 322
  csrw    fflags, zero

  li      a0, 0
  ret

  .section .data
  .align 3
fbuf:
  .dword 0x0123456789abcdef
  .dword 0xfedcba9876543210
  .dword 0
  .dword 0

  .section .note.GNU-stack, "", @progbits
