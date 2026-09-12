/* SPDX-License-Identifier: MIT
 *
 * Corpus program 5/6 — M-mode CSR semantics (C14 §3, checkpoint 4 part 1).
 *
 * Every check is a pure read/write round trip, so this program takes no trap at
 * all: it pins the WARL behaviour of the CSRs the core implements. The values it
 * compares against are the ones the Spike golden model produces for RV64IMFDC —
 * including `misa` (MXL=64 | I | M | F | D | C | S | U) and the mstatus XL fields
 * — which is what makes reading a CSR a *comparable* event in the DiffTest (the
 * value lands in a register and the commit record carries it).
 *
 * Coverage:
 *   * mhartid (read-only zero)
 *   * mscratch: csrrw/csrrs/csrrc + csrrwi/csrrsi/csrrci, "rs1 = x0 does not
 *     write", "old value goes to rd"
 *   * misa: read-only, a write is ignored
 *   * mie: writable only in the interrupt-enable bits (mask 0xaaa)
 *   * mip: an access is legal and must not trap (its value is NOT compared: the
 *     golden model's mip reflects its CLINT, and RV-B has no interrupt source yet
 *     — a documented C14 gap)
 *   * mtvec: fully writable, MODE bits preserved (bit 0 included)
 *   * mepc: bit 0 read-only zero (IALIGN = 16)
 *   * mcause/mtval: fully writable
 *   * mstatus: MIE/MPIE/MPP writable, everything else (incl. SXL/UXL) read-only
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S).
 * No trap is expected here: a trap would send the program into uninitialised
 * mtvec and show up as a divergent/hung trace, which is itself the failure.
 */

  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  .section .text
  .globl main
  .align 2
main:
  /* ---- 1. mhartid: single hart, index 0 --------------------------------- */
  csrr    t0, mhartid
  CK      t0, 0, 1

  /* ---- 2. mscratch round trip (register forms) -------------------------- */
  li      t0, 0x123456789abcdef0
  csrw    mscratch, t0
  csrr    t1, mscratch
  bne     t0, t1, .Lf2

  li      t1, 1
  csrrs   t2, mscratch, t1        /* t2 = old, mscratch = old | 1 */
  bne     t2, t0, .Lf3
  csrr    t3, mscratch
  li      t4, 0x123456789abcdef1
  bne     t3, t4, .Lf4

  li      t1, 0x10
  csrrc   t2, mscratch, t1        /* t2 = old, mscratch = old & ~0x10 */
  bne     t2, t4, .Lf5
  csrr    t3, mscratch
  li      t4, 0x123456789abcdee1
  bne     t3, t4, .Lf6

  csrrs   t2, mscratch, x0        /* rs1 = x0: read only, no write */
  bne     t2, t4, .Lf7

  /* ---- 3. mscratch immediate forms ------------------------------------- */
  csrrwi  t2, mscratch, 0         /* t2 = old, mscratch = 0 */
  bne     t2, t4, .Lf8
  csrrsi  t3, mscratch, 5         /* t3 = 0, mscratch = 5 */
  bnez    t3, .Lf9
  csrr    t4, mscratch
  CK      t4, 5, 10
  csrrci  t5, mscratch, 4         /* t5 = 5, mscratch = 5 & ~4 = 1 */
  CK      t5, 5, 11
  csrr    t4, mscratch
  CK      t4, 1, 12
  csrw    mscratch, zero

  /* ---- 4. misa: read-only, write ignored ------------------------------- */
  li      t0, -1
  csrw    misa, t0
  csrr    t1, misa
  CK      t1, 0x800000000014112c, 13   /* MXL=64, I|M|F|D|C|S|U */

  /* ---- 5. mie: only the interrupt-enable bits are writable -------------- */
  csrw    mie, zero
  csrr    t1, mie
  CK      t1, 0, 14
  li      t0, -1
  csrw    mie, t0
  csrr    t1, mie
  CK      t1, 0xaaa, 15
  csrw    mie, zero

  /* ---- 6. mip: the access must be legal (value is a documented gap) ----- */
  csrw    mip, zero               /* rd = x0: no register value is compared */

  /* ---- 7. mtvec: fully writable, MODE bits verbatim --------------------- */
  csrw    mtvec, zero
  csrr    t1, mtvec
  CK      t1, 0, 16
  li      t0, 0x8000000d          /* odd: MODE = 1, base = 0x8000_000c */
  csrw    mtvec, t0
  csrr    t1, mtvec
  CK      t1, 0x8000000d, 17
  csrw    mtvec, zero

  /* ---- 8. mepc: bit 0 is read-only zero --------------------------------- */
  li      t0, -1
  csrw    mepc, t0
  csrr    t1, mepc
  CK      t1, 0xfffffffffffffffe, 18
  csrw    mepc, zero

  /* ---- 9. mcause / mtval: fully writable -------------------------------- */
  li      t0, 0xdeadbeefcafebabe
  csrw    mcause, t0
  csrr    t1, mcause
  bne     t1, t0, .Lf19
  csrw    mtval, t0
  csrr    t1, mtval
  bne     t1, t0, .Lf20
  csrw    mcause, zero
  csrw    mtval, zero

  /* ---- 10. mstatus: MIE/MPIE/MPP writable, the rest read-only ----------- */
  li      t0, 0x1880              /* MPIE, MPP=M, MIE */
  csrw    mstatus, t0
  csrr    t1, mstatus
  CK      t1, 0x0000000a00001880, 21
  csrw    mstatus, zero
  csrr    t1, mstatus
  CK      t1, 0x0000000a00000000, 22

  /* ---- 11. a read with rd = x0 is legal and writes no register ---------- */
  csrr    x0, mscratch
  csrr    x0, mstatus

  li      a0, 0
  ret

.Lf2:
  li      a0, 2
  ret
.Lf3:
  li      a0, 3
  ret
.Lf4:
  li      a0, 4
  ret
.Lf5:
  li      a0, 5
  ret
.Lf6:
  li      a0, 6
  ret
.Lf7:
  li      a0, 7
  ret
.Lf8:
  li      a0, 8
  ret
.Lf9:
  li      a0, 9
  ret
.Lf19:
  li      a0, 19
  ret
.Lf20:
  li      a0, 20
  ret

  .section .note.GNU-stack, "", @progbits
