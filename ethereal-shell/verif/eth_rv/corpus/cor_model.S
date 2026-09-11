/* SPDX-License-Identifier: MIT
 *
 * Corpus program 4/4 — the *model-targeted* program: one deliberate instance of
 * every compressed (C) form the Python worked-example DUT (`rv_model.py`)
 * implements, plus the RV64I/M instructions it needs to run at all.
 *
 * Why this program exists: `tests/fixtures/cor_model.{hex,spike_log.txt}` are checked
 * in from this ELF. The hex image lets pytest run the model DUT with no toolchain
 * and no Spike, and the logged Spike trace is the golden stream that proves the
 * model retires the same instruction sequence. Keep this program small — the
 * fixtures are regenerated from it (`corpus/build_corpus.py --hex-out`).
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
  /* ---- compressed ALU forms on the prime register class (x8..x15) ---- */
  c.li    s0, 21
  c.li    s1, 2
  c.slli  s0, 1                   /* 42 */
  c.add   s0, s1                  /* 44 */
  c.sub   s0, s1                  /* 42 */
  CK      s0, 42, 1

  c.andi  s0, 0x0f                /* 42 & 15 = 10 */
  c.li    s1, 0x0a
  c.and   s0, s1                  /* 10 & 10 = 10 */
  CK      s0, 10, 2

  c.li    s0, 0x0c
  c.li    s1, 0x03
  c.or    s0, s1                  /* 15 */
  c.li    s1, 0x0f
  c.xor   s0, s1                  /* 0 */
  CK      s0, 0, 3

  c.li    s0, -8
  c.srai  s0, 2                   /* -2 */
  CK      s0, -2, 4

  c.lui   s0, 1                   /* 0x1000 */
  c.srli  s0, 4                   /* 0x100 */
  CK      s0, 0x100, 5

  c.li    s0, 5
  c.li    s1, 9
  c.subw  s0, s1                  /* -4 */
  CK      s0, -4, 6

  li      s0, 0x7fffffff
  c.li    s1, 1
  c.addw  s0, s1                  /* wrap + sign-extend: -2^31 */
  CK      s0, -2147483648, 7

  li      s0, 0x40000000
  c.addiw s0, 0
  c.slli  s0, 1                   /* 0x80000000 in a 64-bit register */
  c.addiw s0, 0                   /* truncate + sign-extend: -2^31 */
  CK      s0, -2147483648, 8

  /* ---- compressed moves, unconditional/conditional jumps, calls ---- */
  c.li    t0, 7
  c.mv    s0, t0
  CK      s0, 7, 9
  c.add   s0, t0                  /* 14 */
  CK      s0, 14, 10
  c.nop

  c.li    s1, 0
  c.beqz  s1, .Lzero              /* taken (x8..x15 only) */
  li      a0, 11
  c.jr    ra
.Lzero:
  c.bnez  s1, .Lfail12            /* not taken */
  c.li    s1, 3
  c.bnez  s1, .Lnz                /* taken */
  li      a0, 13
  c.jr    ra
.Lnz:
  c.j     .Lj1                    /* unconditional compressed jump */
  li      a0, 14
  c.jr    ra
.Lj1:
  c.addi16sp sp, -32
  c.sdsp  ra, 0(sp)
  la      t2, .Lsub
  c.jalr  t2                      /* ra = pc + 2; .Lsub returns via c.jr */
  c.ldsp  ra, 0(sp)
  c.addi16sp sp, 32
  CK      s0, 31, 15

  /* ---- compressed frame addressing ---- */
  c.addi4spn s1, sp, 16           /* s1 = sp + 16 */
  sub     t0, s1, sp
  CK      t0, 16, 16

  /* ---- compressed loads/stores on the prime register class ---- */
  la      s0, mbuf
  li      s1, 0x0badf00d
  c.sw    s1, 4(s0)
  c.lw    s1, 4(s0)
  CK      s1, 0x0badf00d, 17
  li      s1, 0x00c0ffee
  c.sd    s1, 8(s0)
  c.ld    s1, 8(s0)
  CK      s1, 0x00c0ffee, 18

  /* ---- compressed stack-pointer forms (c.swsp/c.lwsp/c.sdsp/c.ldsp) ---- */
  c.addi16sp sp, -32
  c.sdsp  ra, 0(sp)
  li      t3, 0x55667788
  c.swsp  t3, 16(sp)
  c.lwsp  t4, 16(sp)
  CK      t4, 0x55667788, 19
  c.sdsp  t3, 24(sp)
  c.ldsp  t5, 24(sp)
  CK      t5, 0x55667788, 20
  c.ldsp  ra, 0(sp)
  c.addi16sp sp, 32

  li      a0, 0
  ret

.Lsub:
  c.li    s0, 31                  /* 6-bit signed immediate: must fit in [-32, 31] */
  c.jr    ra

.Lfail12:
  li      a0, 12
  ret

  .section .data
  .align 3
mbuf:
  .dword 0
  .dword 0

  .section .note.GNU-stack, "", @progbits
