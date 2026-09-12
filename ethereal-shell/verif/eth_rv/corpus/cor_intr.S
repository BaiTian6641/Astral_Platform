/* SPDX-License-Identifier: MIT
 *
 * Corpus program 11 — interrupts whose timing the *program* controls (E2-RV1
 * increment 6, C14 §3). Spike checks for a pending, enabled interrupt before it
 * executes each instruction, so a program that makes an interrupt pending at a
 * known point knows exactly which instruction must NOT retire — this program
 * pins that instruction with a label and makes the handler check `mepc`/`sepc`:
 * the interrupt must land *before* it.
 *
 * Coverage (all of it deterministic, no reliance on the value of `mtime`):
 *   * M-mode timer interrupt: the CLINT's mtimecmp = 0 keeps MTIP pending
 *     (mtime >= 0 forever), so enabling MTIE + MIE fires it immediately; the
 *     handler clears it by setting mtimecmp = -1 (mtime < 2^64-1 forever)
 *   * M-mode software interrupt through the CLINT's MSIP register
 *   * priority: with MSIP and MTIP both pending, MSI (3) is taken before MTI (7)
 *   * software/timer/external pending bits written straight through `mip`
 *     (SSI 1, STI 5, SEI 9) — the one place a program can arm them itself
 *   * a NEGATIVE CONTROL: with MIE = 0 a pending, enabled interrupt must not be
 *     taken (checked by the interrupt counter and by `mip` still showing it)
 *   * vectored mode: an interrupt with mtvec MODE = 1 enters at
 *     `base + 4 * cause` (the stub at base+28 proves which vector was taken)
 *   * delegation: with mideleg.SSIP = 1, an S-mode software interrupt (armed by
 *     writing sip.SSIP, the only pending bit S-mode may set) goes to stvec with
 *     scause = 1 | (1 << 63), SPP = S, SPIE <= sstatus.SIE, SIE <= 0, stval = 0,
 *     and sret returns without advancing sepc (the interrupted instruction was
 *     never executed)
 *
 * expectations: M handler — s5 = expected mcause (-1 any, -2 vectored), s3 =
 * expected mepc (-1 any), s2 = expected post-entry mstatus (-1 any), s4 = which
 * sources to clear (bit0 msip, bit1 mtimecmp, bit2 mip SW bits); S handler — the
 * same fields against scause/sepc/sstatus. s6/s10 count M/S interrupts.
 *
 * INTERRUPT-TAKING BOUNDARY (a documented difference, kept out of the corpus):
 * this RTL takes a pending, enabled interrupt at the next instruction boundary,
 * while Spike only breaks its execution loop at a *serialization* point — the
 * barrier before a CSR instruction, or the boundary right after a CSR/xRET
 * instruction (riscv/decode_macros.h validate_csr + serialize). The two agree
 * exactly when the source is armed by a CSR write, or when the enabling write is
 * the instruction immediately before the intended trap point; every test below
 * is written that way, and the handler pins the instruction with a label. A
 * program that arms a source with a store and then runs non-serializing
 * instructions while enabled would diverge — that window is NOT compared.
 *
 * mtime itself is NEVER read here: its absolute value is a documented boundary
 * of the DiffTest (Spike ticks it from its own step counter, and a trap makes
 * that counter diverge from any hart-side count), so every timer check uses only
 * the two phase-independent comparisons, `mtimecmp = 0` and `mtimecmp = -1`.
 */

  .macro CKQ reg, want, index
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
  la      s7, mbuf                /* M-mode interrupt records */
  la      s9, sbuf                /* S-mode interrupt records */
  li      s6, 0
  li      s10, 0
  la      s11, irq_handler
  csrw    mtvec, s11

  /* ---- 0. quiet start: no enables, no pending bits ---------------------- */
  csrw    mie, zero
  csrw    mstatus, zero           /* MIE = 0 */
  lui     t0, 0x2004              /* mtimecmp = -1: MTIP permanently clear */
  li      t1, -1
  sd      t1, 0(t0)
  lui     t0, 0x2000              /* msip = 0 */
  sw      zero, 0(t0)
  li      t1, 0x222               /* mip: clear SSIP/STIP/SEIP */
  csrc    mip, t1
  csrr    t0, mip
  CKQ     t0, 0, 1

  /* ---- 1. NEGATIVE CONTROL: pending + enabled, but MIE = 0 ------------- */
  li      t0, 0xaaa
  csrw    mie, t0
  li      t0, 2
  csrw    mip, t0                 /* SSIP pending */
  csrr    t0, mip
  CKQ     t0, 0x2, 2              /* pending is visible ... */
  CKQ     s6, 0, 3                /* ... and no interrupt was taken */
  li      t0, 0x222
  csrc    mip, t0
  csrw    mie, zero

  /* ---- 2. M timer interrupt (MTIP = mtime >= mtimecmp) ------------------ */
  lui     t0, 0x2004
  sd      zero, 0(t0)             /* mtimecmp = 0: MTIP pending */
  csrr    t0, mip
  CKQ     t0, 0x80, 4
  la      s3, 1f                  /* the interrupt lands BEFORE this label */
  li      s5, 0x8000000000000007  /* expect MTI (interrupt bit set) */
  li      s2, 0xa00001880         /* post-entry mstatus */
  li      s4, 0b110               /* clear mtimecmp + mip SW bits */
  li      t0, 0x80
  csrw    mie, t0
  li      t0, 8
  csrw    mstatus, t0             /* MIE = 1 -> MTI taken now */
1:
  CKQ     s6, 1, 5

  /* ---- 3. M software interrupt through the CLINT's msip ----------------- */
  la      s3, 1f
  li      s5, 0x8000000000000003  /* expect MSI */
  li      s2, 0xa00001880
  li      s4, 0b101               /* clear msip + mip SW bits */
  csrw    mstatus, zero           /* MIE = 0 while the source is armed */
  li      t0, 8
  csrw    mie, t0                 /* MSIE */
  li      t0, 1
  lui     t1, 0x2000
  sw      t0, 0(t1)               /* msip = 1: MSIP pending */
  li      t0, 8
  csrw    mstatus, t0             /* MIE = 1 -> MSI taken now */
1:
  CKQ     s6, 2, 6

  /* ---- 4. priority: MSI (3) outranks MTI (7) ---------------------------- */
  la      s3, 1f
  li      s5, 0x8000000000000003  /* MSI wins the priority */
  li      s2, 0xa00001880
  li      s4, 0b111               /* clear everything after the one interrupt */
  csrw    mstatus, zero           /* MIE = 0 while the sources are armed */
  li      t0, 0x88
  csrw    mie, t0                 /* MSIE | MTIE */
  lui     t0, 0x2004
  sd      zero, 0(t0)             /* MTIP pending */
  li      t0, 1
  lui     t1, 0x2000
  sw      t0, 0(t1)               /* MSIP pending too */
  li      t0, 8
  csrw    mstatus, t0             /* MIE = 1 -> one interrupt, cause 3 */
1:
  CKQ     s6, 3, 7

  /* ---- 5. pending bits written straight through mip --------------------- */
  la      s3, 1f
  li      s5, 0x8000000000000001  /* SSI */
  li      s2, 0xa00001880
  li      s4, 0b100
  csrw    mstatus, zero           /* MIE = 0 while the source is armed */
  li      t0, 2
  csrw    mie, t0
  li      t0, 2
  csrw    mip, t0
  li      t0, 8
  csrw    mstatus, t0
1:
  CKQ     s6, 4, 8

  la      s3, 1f
  li      s5, 0x8000000000000005  /* STI */
  li      s2, 0xa00001880
  li      s4, 0b100
  csrw    mstatus, zero           /* MIE = 0 while the source is armed */
  li      t0, 0x20
  csrw    mie, t0
  li      t0, 0x20
  csrw    mip, t0
  li      t0, 8
  csrw    mstatus, t0
1:
  CKQ     s6, 5, 9

  la      s3, 1f
  li      s5, 0x8000000000000009  /* SEI */
  li      s2, 0xa00001880
  li      s4, 0b100
  csrw    mstatus, zero           /* MIE = 0 while the source is armed */
  li      t0, 0x200
  csrw    mie, t0
  li      t0, 0x200
  csrw    mip, t0
  li      t0, 8
  csrw    mstatus, t0
1:
  CKQ     s6, 6, 10

  /* ---- 6. vectored mode: the entry is base + 4 * cause ------------------ */
  li      t0, 0x222
  csrc    mip, t0
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* MTIP off again */
  la      t0, vec_base
  ori     t0, t0, 1               /* MODE = 1 */
  csrw    mtvec, t0
  la      s3, 1f
  li      s5, -2                  /* the stub records which vector ran */
  li      s2, -1
  li      s4, 0b110
  csrw    mstatus, zero           /* MIE = 0 while the source is armed */
  li      t0, 0x80
  csrw    mie, t0
  lui     t0, 0x2004
  sd      zero, 0(t0)             /* MTIP pending */
  li      t0, 8
  csrw    mstatus, t0             /* MIE = 1 -> vectored MTI (base + 28) */
1:
  csrw    mtvec, s11              /* direct mode again */
  CKQ     s6, 7, 11
  CKQ     s1, 7, 12               /* the cause-7 stub really ran */

  /* ---- 7. delegated S-mode software interrupt --------------------------- */
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* no M interrupt sources left */
  li      t0, 0x222
  csrw    mideleg, t0             /* SSI/STI/SEI delegated to S */
  la      t0, s_irq_handler
  csrw    stvec, t0
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  mret
  .align 2
s_code:
  li      t0, 2
  csrw    sie, t0                 /* SSIE (mideleg.SSIP = 1, so it sticks) */
  csrr    t0, sie
  CKQ     t0, 2, 13
  li      t0, 2
  csrs    sstatus, t0             /* SIE = 1 */
  la      s3, 1f                  /* sepc is the interrupted instruction */
  li      s5, 0x8000000000000001  /* SSI, interrupt bit set */
  li      s2, 0x0000000200000120  /* SPP = S, SPIE <= SIE(1), SIE <= 0 */
  li      s4, 0b100
  li      t0, 2
  csrw    sip, t0                 /* SSIP pending -> delegated to stvec */
1:
  CKQ     s10, 1, 14
  csrr    t0, sstatus             /* sret restored SIE and set SPIE */
  CKQ     t0, 0x0000000200000022, 15

  /* ---- 8. counts -------------------------------------------------------- */
  CKQ     s6, 7, 16
  CKQ     s10, 1, 17
  li      a0, 0
  j       exit_ok

  /* ====================================================================
   * M-mode interrupt handler. Expectations in s5/s3/s2/s4 (see the header).
   * ==================================================================== */
  .align 2
irq_handler:
  csrr    t0, mcause
  csrr    t1, mepc
  csrr    t2, mstatus
  csrr    t3, mtval
  sd      t0, 0(s7)
  sd      t1, 8(s7)
  sd      t2, 16(s7)
  sd      t3, 24(s7)
  addi    s7, s7, 32
  addi    s6, s6, 1
  li      t4, -1
  beq     s5, t4, .Lino_cause
  li      t4, -2
  beq     s5, t4, .Livec
  bne     t0, s5, .Libad
  j       .Lino_cause
.Livec:
  li      t4, 7
  bne     s1, t4, .Libad
.Lino_cause:
  li      t4, -1
  beq     s3, t4, .Lino_pc
  bne     t1, s3, .Libad
.Lino_pc:
  li      t4, -1
  beq     s2, t4, .Lino_ms
  bne     t2, s2, .Libad
.Lino_ms:
  andi    t4, s4, 1
  beqz    t4, .Lino_tick
  lui     t0, 0x2000
  sw      zero, 0(t0)             /* msip = 0 */
.Lino_tick:
  andi    t4, s4, 2
  beqz    t4, .Lino_sw
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* mtimecmp = -1: MTIP clear */
.Lino_sw:
  andi    t4, s4, 4
  beqz    t4, .Lino_done
  li      t1, 0x222
  csrc    mip, t1                 /* SSIP/STIP/SEIP clear */
.Lino_done:
  mret
.Libad:
  li      a0, 92
  ret

  /* ====================================================================
   * S-mode interrupt handler. Same expectation fields, against
   * scause/sepc/sstatus; it must NOT advance sepc — the interrupted
   * instruction never executed and has to run after sret.
   * ==================================================================== */
  .align 2
s_irq_handler:
  csrr    t0, scause
  csrr    t1, sepc
  csrr    t2, sstatus
  csrr    t3, stval
  sd      t0, 0(s9)
  sd      t1, 8(s9)
  sd      t2, 16(s9)
  sd      t3, 24(s9)
  addi    s9, s9, 32
  addi    s10, s10, 1
  li      t4, -1
  beq     s5, t4, .Lsno_cause
  bne     t0, s5, .Lsbad
.Lsno_cause:
  li      t4, -1
  beq     s3, t4, .Lsno_pc
  bne     t1, s3, .Lsbad
.Lsno_pc:
  li      t4, -1
  beq     s2, t4, .Lsno_sw
  bne     t2, s2, .Lsbad
.Lsno_sw:
  andi    t4, s4, 4
  beqz    t4, .Lsdone
  li      t1, 0x222
  csrc    sip, t1                 /* sip writes only SSIP, which is delegated */
.Lsdone:
  sret
.Lsbad:
  li      a0, 93
  ret

  /* Vector table for MODE = 1: an interrupt enters at base + 4 * cause.
     Only the vectors this program can take carry a stub; the rest are a trap
     back into the handler with a marker no test can satisfy. */
  .align 5
  .option push
  .option norvc
vec_base:
  li      s1, 0
  j       irq_handler             /* +0 */
  .space  4
  li      s1, 3
  j       irq_handler             /* +12: MSI (cause 3) */
  .space  8
  li      s1, 7
  j       irq_handler             /* +28: MTI (cause 7) */
  .option pop

exit_ok:
  li      a0, 0
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

  .section .data
  .align 3
mbuf: .space 512
sbuf: .space 512

  .section .note.GNU-stack, "", @progbits
