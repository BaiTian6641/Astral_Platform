/* SPDX-License-Identifier: MIT
 *
 * Corpus program 2/4 — load/store coverage: all widths, sign/zero extension,
 * little-endian byte order, .bss/.data addressing, indexed loads, stack traffic.
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
  la      s0, buf                 /* x8: the C-extension prime register class */

  /* ---- 1. doubleword round trip ---- */
  li      t0, 0x0123456789abcdef
  sd      t0, 0(s0)
  ld      t1, 0(s0)
  CK      t1, 0x0123456789abcdef, 1

  /* ---- 2. word: lw sign-extends, lwu zero-extends ---- */
  li      t0, 0x80000000
  sw      t0, 8(s0)
  lw      t1, 8(s0)
  CK      t1, -2147483648, 2
  lwu     t1, 8(s0)
  CK      t1, 0x80000000, 3

  /* ---- 3. halfword: lh sign-extends, lhu zero-extends ---- */
  li      t0, 0xff80
  sh      t0, 16(s0)
  lh      t1, 16(s0)
  CK      t1, -128, 4
  lhu     t1, 16(s0)
  CK      t1, 0xff80, 5

  /* ---- 4. byte: lbu/lb ---- */
  li      t0, 0x7f
  sb      t0, 24(s0)
  lbu     t1, 24(s0)
  CK      t1, 0x7f, 6
  li      t0, 0x81
  sb      t0, 25(s0)
  lb      t1, 25(s0)
  CK      t1, -127, 7

  /* ---- 5. little-endian byte order of a doubleword ---- */
  li      t0, 0x0102030405060708
  sd      t0, 32(s0)
  lbu     t1, 32(s0)              /* lowest byte: 0x08 */
  CK      t1, 8, 8
  lbu     t1, 39(s0)              /* highest byte: 0x01 */
  CK      t1, 1, 9

  /* ---- 6. loop over a .data array: indexed loads + branch ---- */
  la      s1, data_words
  li      t0, 0                  /* index */
  li      t2, 0                  /* sum */
  li      t3, 4                  /* element count */
.Lsum:
  bge     t0, t3, .Lsum_done
  slli    t4, t0, 3              /* index * 8 */
  add     t4, s1, t4
  ld      t5, 0(t4)
  add     t2, t2, t5
  addi    t0, t0, 1
  j       .Lsum
.Lsum_done:
  CK      t2, 0xAAAAAAAAAAAAAAAA, 10  /* 0x1111… × (1+2+3+4) = 0xAAAA… */

  /* ---- 7. compressed stack traffic (c.ldsp/c.sdsp) ---- */
  addi    sp, sp, -32
  li      t0, 0x1122334455667788
  sd      t0, 8(sp)
  ld      t1, 8(sp)
  CK      t1, 0x1122334455667788, 11
  c.swsp  t1, 16(sp)              /* compressed word store to the stack */
  c.lwsp  t1, 16(sp)
  CK      t1, 0x55667788, 12
  c.sdsp  t0, 0(sp)
  c.ldsp  t1, 0(sp)
  CK      t1, 0x1122334455667788, 13

  /* ---- 8. compressed c.sw/c.lw/c.sd/c.ld (x8..x15 only) ---- */
  li      s1, 0x0badf00d
  c.sw    s1, 4(s0)
  c.lw    s1, 4(s0)
  CK      s1, 0x0badf00d, 14
  li      s1, 0x00c0ffee
  c.sd    s1, 48(s0)
  c.ld    s1, 48(s0)
  CK      s1, 0x00c0ffee, 15

  addi    sp, sp, 32
  li      a0, 0
  ret

  .section .data
  .align 3
data_words:
  .dword 0x1111111111111111
  .dword 0x2222222222222222
  .dword 0x3333333333333333
  .dword 0x4444444444444444

  .section .bss
  .align 3
buf:
  .space 128

  .section .note.GNU-stack, "", @progbits
