/* SPDX-License-Identifier: MIT
 *
 * Corpus program 3/4 — RV64M coverage, including the corner cases a hand-written
 * multiplier/divider gets wrong: signed vs unsigned high halves, truncation
 * toward zero, divide-by-zero, and INT64_MIN / -1 overflow.
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S).
 */

  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  c.jr    ra
.Lck\@:
  .endm

  .section .text
  .globl main
  .align 2
main:
  /* ---- 1. mul low half, cross-checked with repeated addition ---- */
  li      a1, 0x123456789abcdef0
  li      a2, 3
  mul     a3, a1, a2
  add     a4, a1, a1
  add     a4, a4, a1
  bne     a3, a4, .Lfail1

  /* ---- 2. high halves of a large product ---- */
  li      a1, 0x8000000000000000   /* -2^63 signed, +2^63 unsigned */
  li      a2, 2
  mulh    a3, a1, a2               /* (-2^63 * 2) >> 64 = -1 */
  CK      a3, -1, 2
  mulhu   a3, a1, a2               /* (2^63 * 2) >> 64 = 1 */
  CK      a3, 1, 3
  mulhsu  a3, a1, a2               /* signed(1st) * unsigned(2nd) = -1 */
  CK      a3, -1, 4

  /* ---- 3. div/rem identity: q*d + r == n ---- */
  li      a1, 1000
  li      a2, 7
  div     a3, a1, a2               /* 142 */
  rem     a4, a1, a2               /* 6 */
  mul     a5, a3, a2
  add     a5, a5, a4
  bne     a5, a1, .Lfail5
  CK      a3, 142, 6
  CK      a4, 6, 7

  /* ---- 4. signed division truncates toward zero; remainder takes dividend sign ---- */
  li      a1, -1000
  li      a2, 7
  div     a3, a1, a2               /* -142 */
  rem     a4, a1, a2               /* -6 */
  CK      a3, -142, 8
  CK      a4, -6, 9

  /* ---- 5. divide by zero: quotient = -1, remainder = dividend ---- */
  li      a2, 0
  div     a3, a1, a2
  CK      a3, -1, 10
  rem     a4, a1, a2
  CK      a4, -1000, 11
  divu    a3, a1, a2               /* unsigned: 2^64-1 */
  CK      a3, -1, 12
  remu    a4, a1, a2
  CK      a4, -1000, 13

  /* ---- 6. signed overflow: INT64_MIN / -1 ---- */
  li      a1, -9223372036854775808
  li      a2, -1
  div     a3, a1, a2               /* stays INT64_MIN */
  CK      a3, -9223372036854775808, 14
  rem     a4, a1, a2               /* 0 */
  CK      a4, 0, 15

  /* ---- 7. W-forms sign-extend their 32-bit result ---- */
  li      a1, 0x7fffffff
  li      a2, 2
  mulw    a3, a1, a2               /* 0xfffffffe -> -2 */
  CK      a3, -2, 16
  divw    a3, a1, a2               /* 0x3fffffff */
  CK      a3, 0x3fffffff, 17
  remw    a3, a1, a2               /* 1 */
  CK      a3, 1, 18

  li      a1, -7
  li      a2, 2
  divuw   a3, a1, a2               /* (2^32-7)/2 = 0x7ffffffc */
  CK      a3, 0x7ffffffc, 19
  remuw   a3, a1, a2               /* 1 */
  CK      a3, 1, 20

  /* ---- 8. mulhsu with a negative signed operand and a big unsigned one ---- */
  li      a1, -1
  li      a2, -1
  mulhsu  a3, a1, a2               /* -1 * (2^64-1) >> 64 = -1 */
  CK      a3, -1, 21

  li      a0, 0
  ret

.Lfail1:
  li      a0, 1
  ret
.Lfail5:
  li      a0, 5
  ret

  .section .note.GNU-stack, "", @progbits
