/* SPDX-License-Identifier: MIT
 *
 * Corpus program 1/4 — RV64I arithmetic / logic / shift / branch coverage,
 * mixed 32-bit and compressed (C) encodings.
 *
 * Self-checking: each result is cross-checked against an independently computed
 * value (identities and De Morgan laws, not magic constants). `main` returns 0
 * on success, or the index of the first failed check. See crt0.S for the HTIF
 * exit protocol and ../README.md for how the harness consumes these ELFs.
 *
 * Note on the C extension: the `c.sub/c.and/c.or/c.xor/c.subw/c.addw/c.andi/
 * c.srli/c.srai/c.lw/c.ld/c.sw/c.sd/c.addi4spn` forms can only name x8..x15
 * (the 3-bit register fields), which is why those checks use s0/s1.
 */

  /* CK <reg> <expected-constant> <index>: return <index> from main unless equal */
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
  /* ---- add/sub round trip: (a + b) - b == a ---- */
  li      a1, 0x0123456789abcdef
  li      a2, 0x00000000fedcba98
  add     a3, a1, a2
  sub     a4, a3, a2
  CK      a4, 0x0123456789abcdef, 1

  /* ---- sub/add inverse with a negative operand ---- */
  li      a2, -4096
  sub     a3, a1, a2
  add     a4, a3, a2
  CK      a4, 0x0123456789abcdef, 2

  /* ---- De Morgan: (a & b) == ~(~a | ~b) ---- */
  li      a2, 0x0f0f0f0f0f0f0f0f
  and     a3, a1, a2
  not     a4, a1
  not     a5, a2
  or      a4, a4, a5
  not     a4, a4
  bne     a3, a4, .Lfail3

  /* ---- xor is self-inverse; andi/ori/xori immediates ---- */
  li      a2, 0x5555555555555555
  xor     a3, a1, a2
  xor     a3, a3, a2
  CK      a3, 0x0123456789abcdef, 4

  andi    a3, a1, 0x7f
  andi    a4, a3, 0x7f
  bne     a3, a4, .Lfail5

  ori     a3, zero, 0x5a          /* 90 */
  xori    a3, a3, 0xff            /* the immediate is 12-bit: +255, so 90 ^ 255 = 165 */
  CK      a3, 165, 6

  /* ---- shifts: slli/srli round trip, srai/srli sign behaviour ---- */
  li      a2, 0x0000000012345678
  slli    a3, a2, 20
  srli    a3, a3, 20
  CK      a3, 0x0000000012345678, 7

  li      a2, -1
  srai    a3, a2, 63
  CK      a3, -1, 8

  li      a2, 0x8000000000000000
  srli    a3, a2, 63
  CK      a3, 1, 9

  /* ---- 32-bit ops sign-extend their result ---- */
  li      a2, 0x7fffffff
  addiw   a3, a2, 1               /* 0x80000000 -> sign-extended */
  CK      a3, -2147483648, 10

  li      a2, 1
  slliw   a3, a2, 31
  CK      a3, -2147483648, 11

  li      a2, -1
  srliw   a3, a2, 1               /* 0x7fffffff (zero-extended into rd) */
  CK      a3, 0x7fffffff, 12

  li      a2, -2
  sraiw   a3, a2, 1               /* stays -1 */
  CK      a3, -1, 13

  /* ---- comparisons: slt/sltu/slti/sltiu ---- */
  li      a2, -1
  li      a3, 1
  slt     a4, a2, a3              /* signed: -1 < 1 -> 1 */
  CK      a4, 1, 14
  sltu    a4, a2, a3              /* unsigned: 2^64-1 < 1 -> 0 */
  beqz    a4, .Lcmp2
  li      a0, 15
  c.jr    ra
.Lcmp2:
  slti    a4, a2, 0               /* -1 < 0 -> 1 */
  CK      a4, 1, 16
  sltiu   a4, a2, -1              /* imm sign-extends to 2^64-1: not < */
  beqz    a4, .Lcmp3
  li      a0, 17
  c.jr    ra
.Lcmp3:

  /* ---- branches: beq/bne/blt/bge/bltu/bgeu ---- */
  li      a2, -5
  li      a3, 7
  blt     a2, a3, .Lbr1
  li      a0, 18
  c.jr    ra
.Lbr1:
  bge     a3, a2, .Lbr2
  li      a0, 19
  c.jr    ra
.Lbr2:
  bgeu    a3, a2, .Lbr3           /* 7 >=u 0xfffffffffffffffb is false */
  j       .Lbr4
.Lbr3:
  li      a0, 20
  c.jr    ra
.Lbr4:
  li      a2, 0x1000000000000000
  bltu    a3, a2, .Lbr5
  li      a0, 21
  c.jr    ra
.Lbr5:
  beq     a3, a3, .Lbr6
  li      a0, 22
  c.jr    ra
.Lbr6:
  bne     a3, a2, .Lbr7
  li      a0, 23
  c.jr    ra
.Lbr7:

  /* ---- auipc-relative addressing, jal/c.jalr subroutines, stack ld/sd ---- */
  /* `auipc rd, 0` yields the address of the auipc itself, so it must equal a
     `la` of a label placed on it (this is what makes la/medany code correct). */
.Lhere:
  auipc   a2, 0
  la      a3, .Lhere
  bne     a2, a3, .Lfail24
  addi    sp, sp, -16
  sd      ra, 8(sp)
  jal     ra, .Lquad              /* a3 = 42 * 2 = 84 */
  CK      a3, 84, 25
  la      t3, .Lquad
  c.jalr  t3                      /* ra = pc + 2, a3 = 84 */
  CK      a3, 84, 26
  ld      ra, 8(sp)
  addi    sp, sp, 16

  /* ---- compressed (C extension) ALU forms ---- */
  c.li    s0, 21
  c.li    s1, 2
  c.slli  s0, 1                   /* 42 */
  c.add   s0, s1                  /* 44 */
  c.sub   s0, s1                  /* 42 */
  CK      s0, 42, 27

  c.li    s0, 0x0f
  c.andi  s0, 0x03                /* 3 */
  c.li    s1, 0x03
  c.and   s0, s1
  CK      s0, 3, 28

  c.lui   s0, 1                   /* 0x1000 */
  c.srli  s0, 4                   /* 0x100 */
  CK      s0, 0x100, 29

  c.li    s0, -8
  c.srai  s0, 2                   /* -2 */
  CK      s0, -2, 30

  li      s0, 0x40000000
  c.addiw s0, 0
  c.slli  s0, 1                   /* 0x80000000 in a 64-bit register */
  c.addiw s0, 0                   /* truncate + sign-extend: -2^31 */
  CK      s0, -2147483648, 31

  c.li    s0, 5
  c.li    s1, 9
  c.subw  s0, s1                  /* -4 */
  CK      s0, -4, 32

  li      s0, 0x7fffffff
  c.li    s1, 1
  c.addw  s0, s1                  /* wrapped + sign-extended */
  CK      s0, -2147483648, 33

  li      s0, 0x1234
  li      s1, 0x5678
  c.or    s0, s1                  /* 0x567c */
  CK      s0, 0x567c, 34

  c.li    s0, 4
  c.xor   s0, s1                  /* 4 ^ 0x5678 = 0x567c */
  CK      s0, 0x567c, 35

  c.addi  s0, -3                  /* 0x5679 */
  CK      s0, 0x5679, 36
  c.nop

  li      a0, 0
  ret

/* .Lquad: leaf routine returning via ra; reached by jal and by c.jalr */
.Lquad:
  li      a0, 42
  slli    a3, a0, 1
  c.jr    ra

.Lfail3:
  li      a0, 3
  ret
.Lfail5:
  li      a0, 5
  ret
.Lfail24:
  li      a0, 24
  ret

  .section .note.GNU-stack, "", @progbits
