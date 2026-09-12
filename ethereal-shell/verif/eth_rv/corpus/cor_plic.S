/* SPDX-License-Identifier: MIT
 *
 * Corpus program 22 — the PLIC and the S-mode external-interrupt path
 * (E2-RV2 increment 6 / S5, C14 §8; the device E2-RV2 G7 was missing).
 *
 * The register semantics of the PLIC are the pinned Spike's `riscv/plic.cc`,
 * probed before this program was written (local://rv11-plic-notes.md §1.1), and
 * several of the checks below pin a *quirk* of that model rather than the spec:
 *
 *   * enable → pending → claim → complete, with the level-triggered rule that a
 *     complete with the source still asserting re-raises the context's line;
 *   * the threshold masks `priority <= threshold` (so a source at equal priority
 *     is masked, and priority 0 is never delivered);
 *   * the arbitration uses the priority LATCHED with the pending bit: a source
 *     that becomes pending while its priority is 0 stays masked after the program
 *     raises the priority, until its enable bit is written again. Spike's
 *     `pending_priority` is a snapshot, and a DiffTest has to reproduce it;
 *   * the pending word is read-only, priority ids past the sources swallow writes,
 *     source 0 does not exist, and only 4-/8-byte accesses are served — a subword
 *     access is an access fault (cause 5/7 with `mtval` = the address);
 *   * the M context drives `mip.MEIP` and the S context `mip.SEIP`, so an S-mode
 *     kernel takes a real external interrupt through `mideleg.SEI` with
 *     `scause = 9 | (1 << 63)` — the whole point of this slice;
 *   * the S mode context is where a driver would attach: the UART's RX interrupt
 *     (`(IER.RDI && LSR.DR) | IER.THRI`, Spike's rule) is PLIC source 1.
 *
 * The source is raised through the UART's MCR loopback, because that is the one
 * byte-injection route a DiffTest can drive (`cor_uart_rx` compares the receive
 * register interface itself; the serial receiver is TB-checked — see
 * verif/eth_rv/README.md). Every UART store here happens with MCR.LOOP set, so
 * nothing is transmitted and the console stays idle.
 *
 * INTERRUPT-TAKING BOUNDARY (the documented DiffTest boundary, see cor_intr.S):
 * this RTL takes a pending, enabled interrupt at the next instruction boundary,
 * Spike only breaks its loop at a serialization point. Every delivery test below
 * therefore arms the source with a CSR write (or with a store that leaves the
 * source masked until the CSR write that enables it), and pins the interrupted
 * instruction with a label.
 *
 * Checks are numbered; `main` returns the number of the first failure (rc = 0
 * means every check passed). The M handler's exception path records mcause/mtval
 * in s8/s9 and skips a 4-byte instruction — only 4-byte faults are probed.
 */

  .macro CKQ reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* PLIC/UART constants (Spike's platform.h values; core.yaml mirrors them) */
  .equ    PLIC_PRIO,   0x0c000000
  .equ    PLIC_PEND,   0x0c001000
  .equ    PLIC_EN_M,   0x0c002000
  .equ    PLIC_EN_S,   0x0c002080
  .equ    PLIC_CTX_M,  0x0c200000
  .equ    PLIC_CTX_S,  0x0c201000
  .equ    UART,        0x10000000

  .section .text
  .globl main
  .align 2
main:
  la      s11, irq_handler
  csrw    mtvec, s11
  li      s0, PLIC_PRIO
  li      s1, PLIC_EN_M
  li      s7, PLIC_CTX_M
  li      s6, 0                   /* M-mode interrupt count */
  li      s10, 0                  /* S-mode interrupt count */
  csrw    mie, zero
  csrw    mstatus, zero           /* MIE = 0 */
  li      t0, 0x222
  csrc    mip, t0                 /* clear the software pending bits */
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* mtimecmp = -1: MTIP never pending */
  csrr    t0, mip
  CKQ     t0, 0, 1                /* a quiet start: mip = 0 */

  /* ---- 2..9. reset state of every PLIC register ------------------------- */
  lw      t0, 4(s0)
  CKQ     t0, 0, 2                /* priority[1] */
  lw      t0, 0(s0)
  CKQ     t0, 0, 3                /* priority[0] */
  li      t1, PLIC_PEND
  lw      t0, 0(t1)
  CKQ     t0, 0, 4                /* pending word 0 */
  lw      t0, 0(s1)
  CKQ     t0, 0, 5                /* enable, context 0 */
  lw      t0, 0x80(s1)
  CKQ     t0, 0, 6                /* enable, context 1 */
  lw      t0, 0(s7)
  CKQ     t0, 0, 7                /* threshold, context 0 */
  lw      t0, 4(s7)
  CKQ     t0, 0, 8                /* claim, context 0 (nothing pending) */
  li      t2, PLIC_CTX_S
  lw      t0, 4(t2)
  CKQ     t0, 0, 9                /* claim, context 1 */

  /* ---- 10..13. WARL priority and the ids that do not exist -------------- */
  li      t0, -1
  sw      t0, 4(s0)
  lw      t0, 4(s0)
  CKQ     t0, 0xf, 10             /* 4-bit priority */
  li      t0, 3
  sw      t0, 4(s0)
  li      t0, -1
  sw      t0, 0(s0)
  lw      t0, 0(s0)
  CKQ     t0, 0, 11               /* source 0 does not exist: write dropped */
  li      t0, 0x7f
  sw      t0, 0x7c(s0)
  lw      t0, 0x7c(s0)
  CKQ     t0, 0xf, 12             /* priority[31] */
  li      t0, 0x7f
  sw      t0, 0x80(s0)
  lw      t0, 0x80(s0)
  CKQ     t0, 0, 13               /* id 32 is past the sources */

  /* ---- 14. the pending word is read-only -------------------------------- */
  li      t0, -1
  sw      t0, 0(t1)
  lw      t0, 0(t1)
  CKQ     t0, 0, 14

  /* ---- 15..16. enable: source 0's bit is masked off --------------------- */
  li      t0, -1
  sw      t0, 0(s1)
  lw      t0, 0(s1)
  CKQ     t0, -2, 15              /* `lw` sign-extends: the word is 0xFFFFFFFE */
  sw      zero, 0(s1)
  li      t0, 2
  sw      t0, 0x80(s1)
  lw      t0, 0x80(s1)
  CKQ     t0, 2, 16
  sw      zero, 0x80(s1)

  /* ---- 17..18. the threshold is 4 bits --------------------------------- */
  li      t0, 0x1f
  sw      t0, 0(s7)
  lw      t0, 0(s7)
  CKQ     t0, 0xf, 17
  li      t0, 0x10
  sw      t0, 0(s7)
  lw      t0, 0(s7)
  CKQ     t0, 0, 18
  sw      zero, 0(s7)

  /* ---- 19..27. access classes (the M handler records and skips) ---------
     The handler clobbers t0..t4, so every base a faulting access needs is
     reloaded after the trap that precedes it. */
  lbu     t0, 0(t1)               /* a subword read: Spike serves only 4/8 bytes */
  CKQ     s8, 5, 19               /* load access fault ... */
  CKQ     s9, PLIC_PEND, 20       /* ... with mtval = the address */
  li      t1, PLIC_PEND
  sb      zero, 0(t1)             /* and a subword store */
  CKQ     s8, 7, 21
  CKQ     s9, PLIC_PEND, 22
  sw      zero, 8(s7)             /* a reserved context offset: writes fault */
  CKQ     s8, 7, 23
  CKQ     s9, PLIC_CTX_M + 8, 24
  lw      t0, 8(s7)               /* ... but its read is 0 with no fault */
  CKQ     t0, 0, 25
  CKQ     s8, 7, 26               /* (the recorded cause is still the store fault) */
  li      t2, PLIC_CTX_M + 0x2000
  lw      t0, 0(t2)               /* context 2 does not exist */
  CKQ     s8, 5, 27

  /* ---- 28..39. level -> pending, claim, complete ------------------------ */
  li      t0, 3
  sw      t0, 4(s0)               /* priority[1] = 3 */
  li      t0, 2
  sw      t0, 0(s1)               /* enable source 1 for the M context */
  li      t5, UART
  li      t1, PLIC_PEND           /* (the fault probes above clobbered t1) */
  li      t0, 0x18
  sb      t0, 4(t5)               /* MCR = LOOP | OUT2 */
  li      t0, 1
  sb      t0, 1(t5)               /* IER = RDI */
  lbu     t0, 2(t5)
  CKQ     t0, 0xc1, 28            /* IIR: no interrupt yet */
  li      t0, 0x41
  sb      t0, 0(t5)               /* loopback push: DR = 1, the UART line rises */
  csrr    t0, mip
  CKQ     t0, 0x800, 29           /* MEIP, raised by the PLIC's M context */
  lw      t0, 0(t1)
  CKQ     t0, 2, 30               /* pending word 0 */
  lbu     t0, 5(t5)
  CKQ     t0, 0x61, 31            /* LSR = TEMT|THRE|DR */
  lbu     t0, 2(t5)
  CKQ     t0, 0xc4, 32            /* IIR = 0xc0 | RDI */
  lw      t0, 4(s7)
  CKQ     t0, 1, 33               /* claim = source 1 */
  csrr    t0, mip
  CKQ     t0, 0, 34               /* claimed: the line drops although the level is high */
  lw      t0, 4(s7)
  CKQ     t0, 0, 35               /* a second claim returns 0 */
  li      t0, 1
  sw      t0, 4(s7)               /* complete: the level is still high -> pending survives */
  csrr    t0, mip
  CKQ     t0, 0x800, 36           /* re-raised */
  lbu     t0, 0(t5)
  CKQ     t0, 0x41, 37            /* RBR pops the byte ... */
  csrr    t0, mip
  CKQ     t0, 0, 38               /* ... the UART line falls -> pending/claimed cleared */
  lw      t0, 4(s7)
  CKQ     t0, 0, 39
  lbu     t0, 5(t5)
  CKQ     t0, 0x60, 40            /* LSR idle again */

  /* ---- 41..53. threshold masking and the latched pending priority ------- */
  li      t0, 0x42
  sb      t0, 0(t5)               /* raise the level again */
  csrr    t0, mip
  CKQ     t0, 0x800, 41
  li      t0, 3
  sw      t0, 0(s7)               /* threshold == priority -> masked */
  csrr    t0, mip
  CKQ     t0, 0, 42
  li      t0, 2
  sw      t0, 0(s7)               /* threshold < priority -> delivered */
  csrr    t0, mip
  CKQ     t0, 0x800, 43
  lw      t0, 4(s7)
  CKQ     t0, 1, 44
  lbu     t0, 0(t5)
  CKQ     t0, 0x42, 45
  csrr    t0, mip
  CKQ     t0, 0, 46
  sw      zero, 0(s7)
  sw      zero, 4(s0)             /* priority[1] = 0 ... */
  li      t0, 0x43
  sb      t0, 0(t5)               /* ... and the level rises: pending_priority latches 0 */
  csrr    t0, mip
  CKQ     t0, 0, 47
  li      t0, 3
  sw      t0, 4(s0)               /* raising the priority does NOT change the latch */
  csrr    t0, mip
  CKQ     t0, 0, 48
  li      t0, 3
  sw      t0, 0(s7)
  sw      zero, 0(s7)             /* neither does the threshold knob */
  csrr    t0, mip
  CKQ     t0, 0, 49
  sw      zero, 0(s1)             /* re-enabling re-latches it ... */
  li      t0, 2
  sw      t0, 0(s1)
  csrr    t0, mip
  CKQ     t0, 0x800, 50           /* ... and now it is delivered */
  lw      t0, 4(s7)
  CKQ     t0, 1, 51
  lbu     t0, 0(t5)
  CKQ     t0, 0x43, 52
  csrr    t0, mip
  CKQ     t0, 0, 53

  /* ---- 54. the M-mode external interrupt ------------------------------- */
  la      s3, 1f                  /* the interrupted instruction */
  li      s5, 0x800000000000000b  /* MEI */
  li      s2, 0xa00001880         /* post-entry mstatus (MPP = M, MPIE = 1, MIE = 0) */
  li      s4, 0b11                /* handler clears: claim the M context, then read RBR */
  li      t0, 0x44
  sb      t0, 0(t5)               /* the source is pending while MIE = 0 */
  csrr    t0, mip
  CKQ     t0, 0x800, 54
  li      t0, 8
  csrw    mstatus, t0             /* MIE = 1, nothing enabled yet */
  li      t0, 0x800
  csrw    mie, t0                 /* MEIE: the enabling CSR write -> the trap lands below */
1:
  CKQ     s6, 1, 55
  csrr    t0, mstatus
  CKQ     t0, 0xa00000088, 56     /* mret: MIE <= MPIE(1), MPIE <= 1, MPP <= U */
  csrr    t0, mip
  CKQ     t0, 0, 57               /* the handler cleared the source and the claim */

  /* ---- 58..60. the S-mode SEI path through mideleg.SEI ------------------ */
  sw      zero, 0(s1)             /* the M context hands source 1 to S */
  li      t0, 0x222
  csrw    mideleg, t0             /* SSI/STI/SEI delegated */
  csrw    mie, zero               /* no M-mode sources */
  la      t0, s_irq_handler
  csrw    stvec, t0
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  mret
  .align 2
s_code:
  /* In S-mode: attach the PLIC's S context to source 1 and raise it while the
     interrupt is still disabled, then enable it with a CSR write. */
  li      t0, 3
  sw      t0, 4(s0)               /* priority[1] = 3 */
  li      t0, 2
  sw      t0, 0x80(s1)            /* enable source 1 for the S context */
  csrr    t0, sie
  CKQ     t0, 0, 58               /* sie is 0 until it is written */
  csrr    t0, sstatus
  CKQ     t0, 0x0000000200000000, 59  /* the S-owned bits are still clear
                                         (MPIE/MPP are not visible through sstatus) */
  li      t1, UART
  li      t0, 0x18
  sb      t0, 4(t1)               /* MCR = LOOP | OUT2 */
  li      t0, 1
  sb      t0, 1(t1)               /* IER = RDI */
  li      t0, 0x45
  sb      t0, 0(t1)               /* the source is pending, SIE = 0 so nothing traps */
  csrr    t0, sip
  CKQ     t0, 0x200, 60           /* sip sees the PLIC's SEIP (mideleg.SEI is set) */
  lw      t0, 0x80(s1)            /* `mip` itself is M-mode-only: read the enable back */
  CKQ     t0, 2, 61
  mv      t0, s10
  CKQ     t0, 0, 62               /* no S interrupt yet */
  la      s3, 1f
  li      s5, 0x8000000000000009  /* SEI */
  li      s2, 0x0000000200000120  /* post-entry sstatus (SPP = S, SPIE = 1, SIE = 0) */
  li      s4, 0b100               /* handler clears: claim the S context, then RBR */
  li      t0, 0x200
  csrs    sie, t0                 /* SEIE (mideleg.SEI is set, so it sticks) */
  li      t0, 2
  csrs    sstatus, t0             /* SIE = 1: the enabling write -> the trap lands below */
1:
  CKQ     s10, 1, 63
  csrr    t0, sstatus
  CKQ     t0, 0x0000000200000022, 64  /* sret restored SIE and set SPIE */
  csrr    t0, sip
  CKQ     t0, 0, 65               /* the S handler cleared the source */
  li      t0, 0x9
  csrc    sip, t0                 /* (SEIP is not software-writable from S: no change) */
  csrr    t0, sip
  CKQ     t0, 0, 66
  ecall                           /* S-mode ecall -> M (medeleg is 0), where main resumes */
  /* (execution resumes in M-mode at the instruction after the `ecall`, whose
     mepc the M handler advanced by 4 — a 4-byte instruction, as the note says) */

  /* ---- 67..70. counts, and the S test did not disturb the M context ----- */
  CKQ     s6, 1, 67
  CKQ     s10, 1, 68
  csrr    t0, sip
  CKQ     t0, 0, 69
  lw      t0, 0x80(s1)
  CKQ     t0, 2, 70
  li      a0, 0
  ret

  /* ====================================================================
   * M-mode trap handler. Interrupts: the expectation fields s5 (cause),
   * s3 (mepc), s2 (mstatus) and s4 (which sources to clear) — `-1` means
   * "any", as in cor_intr.S. Exceptions: record mcause/mtval in s8/s9 and
   * skip a 4-byte instruction (every fault probed above is a 4-byte one).
   * ==================================================================== */
  .align 2
irq_handler:
  csrr    t0, mcause
  csrr    t1, mepc
  csrr    t3, mtval
  bltz    t0, m_intr

  /* --- exception: record it and skip the instruction ------------------- */
  mv      s8, t0
  mv      s9, t3
  addi    t1, t1, 4
  csrw    mepc, t1
  mret

  /* --- interrupt ------------------------------------------------------ */
m_intr:
  addi    s6, s6, 1
  csrr    t2, mstatus
  li      t4, -1
  beq     s5, t4, .Lino_cause
  bne     t0, s5, .Libad
.Lino_cause:
  li      t4, -1
  beq     s3, t4, .Lino_pc
  bne     t1, s3, .Libad
.Lino_pc:
  li      t4, -1
  beq     s2, t4, .Lino_val
  bne     t2, s2, .Libad
.Lino_val:
  bnez    t3, .Libad             /* an interrupt's tval is 0 */
  andi    t4, s4, 1
  beqz    t4, .Lino_rbr
  li      t0, PLIC_CTX_M
  lw      t1, 4(t0)              /* claim: the M context's line drops */
  sw      t1, 4(t0)              /* complete the id we just claimed */
.Lino_rbr:
  andi    t4, s4, 2
  beqz    t4, .Lino_done
  li      t0, UART
  lbu     t1, 0(t0)              /* RBR: the level falls, pending/claimed clear */
.Lino_done:
  mret
.Libad:
  li      a0, 91
  ret

  /* ====================================================================
   * S-mode interrupt handler: the same fields against scause/sepc/sstatus.
   * It must NOT advance sepc — the interrupted instruction never ran.
   * ==================================================================== */
  .align 2
s_irq_handler:
  addi    s10, s10, 1
  csrr    t0, scause
  csrr    t1, sepc
  csrr    t2, sstatus
  csrr    t3, stval
  li      t4, -1
  beq     s5, t4, .Lsno_cause
  bne     t0, s5, .Lsbad
.Lsno_cause:
  li      t4, -1
  beq     s3, t4, .Lsno_pc
  bne     t1, s3, .Lsbad
.Lsno_pc:
  li      t4, -1
  beq     s2, t4, .Lsno_val
  bne     t2, s2, .Lsbad
.Lsno_val:
  bnez    t3, .Lsbad
  andi    t4, s4, 4
  beqz    t4, .Lsdone
  li      t0, PLIC_CTX_S
  lw      t1, 4(t0)              /* claim on the S context */
  sw      t1, 4(t0)              /* complete */
  li      t0, UART
  lbu     t1, 0(t0)              /* RBR: the level falls -> the S context clears */
.Lsdone:
  sret
.Lsbad:
  li      a0, 93
  ret

  .section .note.GNU-stack, "", @progbits
