/* SPDX-License-Identifier: MIT
 *
 * Corpus program 19 — Zicntr and the counter enables (E2-RV2 increment 4).
 *
 * Every expected value below was probed on the pinned Spike
 * (`--isa=rv64imafdc_zicsr_zicntr`, commit 1e05ddac) before this program was
 * written; the probe table is `local://rv10-counter-notes.md` (§1.2 counters,
 * §1.5 permissions) and the DiffTest re-checks every value on both sides.
 *
 * Coverage:
 *   * `mcounteren`/`scounteren` are WARL 0x7 (CY|TM|IR) and `mcountinhibit` 0x5
 *     (CY|IR — the inhibit register has no timer bit), all three reset to 0
 *   * a write to `mcycle`/`minstret` stores exactly the written value, while the
 *     counter is inhibited *and* while it runs; the writing instruction itself
 *     does not add one (Spike's `wide_counter_csr_t::written` precedent)
 *   * `mcycle`/`minstret` and their read-only proxies `cycle`/`instret` advance
 *     by exactly one per retired instruction (Spike's CPI = 1 model), so a
 *     delta over a fixed instruction window is a constant
 *   * `mcountinhibit.CY` freezes `cycle` alone and `.IR` freezes `instret` alone
 *   * writes to the read-only proxies (`cycle`/`time`/`instret`) are illegal in
 *     every mode, while the read form (`csrrs rd, x, x0`) is legal
 *   * the `time` staircase: `rdtime` in a long TRAP-FREE loop is compared commit
 *     by commit against Spike, and the CLINT `mtime` load is stored beside it
 *     (the two are one value function — see the README's boundary note). The
 *     loop runs before any trap in this program on purpose: a trap ends Spike's
 *     step early (`n = instret`), which shifts the tick phase in a way no
 *     hart-side counter reproduces (`cor_time`'s documented boundary)
 *   * the permission chain: `mcounteren` gates S-mode reads and, together with
 *     `scounteren`, U-mode reads — each combination is exercised U-mode by an
 *     `ecall` excursion that lets the M-mode handler re-program the enables
 *
 * `main` returns 0 on success, or the index of the first failed check (crt0.S);
 * the trap handler verifies each armed cause and skips the trapping
 * instruction, and the final check counts the traps so an expectation that is
 * never armed cannot pass unnoticed.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, index — arm the expectation for the next trap (an illegal
     instruction, checked by cause alone: all of these carry mtval = the
     instruction word, which the handler verifies). */
  .macro NEXT cause, index
  li      s0, \cause
  li      s2, -2
  li      s3, \index
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
  li      s0, 0                   /* no expectation armed */
  li      s10, 0                  /* U-mode excursion index */

  /* ---- 1. the enable registers' WARL masks ------------------------------ */
  li      t0, -1
  csrw    mcountinhibit, t0
  csrr    t1, mcountinhibit
  CK      t1, 5, 1
  csrw    mcountinhibit, zero
  li      t0, -1
  csrw    mcounteren, t0
  csrr    t1, mcounteren
  CK      t1, 7, 2
  li      t0, -1
  csrw    scounteren, t0
  csrr    t1, scounteren
  CK      t1, 7, 3
  csrw    mcounteren, zero
  csrw    scounteren, zero

  /* ---- 2. exact writes while both counters are inhibited ---------------- */
  li      t0, 5                   /* CY|IR inhibited */
  csrw    mcountinhibit, t0
  li      t0, 0x1000
  csrw    mcycle, t0
  li      t0, 0x3000
  csrw    minstret, t0
  nop
  nop
  nop
  csrr    t1, mcycle
  CK      t1, 0x1000, 4
  csrr    t1, minstret
  CK      t1, 0x3000, 5
  csrr    t1, cycle
  CK      t1, 0x1000, 6
  csrr    t1, instret
  CK      t1, 0x3000, 7
  csrw    mcountinhibit, zero

  /* ---- 3. deltas: one count per retired instruction --------------------- */
  csrw    mcycle, zero
  csrw    minstret, zero
  rdcycle t0
  rdinstret t1
  nop
  nop
  nop
  rdcycle t2
  rdinstret t3
  sub     t2, t2, t0
  sub     t3, t3, t1
  CK      t2, 5, 8                /* 5 instructions retired between the reads */
  CK      t3, 5, 9
  /* write then read: the very next instruction sees the written value */
  li      t0, 0x1234
  csrw    mcycle, t0
  csrr    t1, cycle
  CK      t1, 0x1234, 10

  /* ---- 4. mcountinhibit gates each counter separately ------------------- */
  csrw    mcycle, zero
  csrw    minstret, zero
  li      t0, 1                   /* CY: `cycle` freezes, `instret` keeps going */
  csrw    mcountinhibit, t0
  nop
  nop
  rdcycle t2
  rdinstret t3
  CK      t2, 3, 11
  CK      t3, 5, 12
  li      t0, 4                   /* IR: the other way round */
  csrw    mcountinhibit, t0
  csrw    mcycle, zero
  csrw    minstret, zero
  nop
  nop
  rdcycle t2
  rdinstret t3
  CK      t2, 3, 13
  CK      t3, 0, 14
  csrw    mcountinhibit, zero

  /* ---- 5. the `time` staircase (TRAP-FREE: no trap before this point) --- */
  la      s7, stair
  li      s9, 0
  lui     t0, 0x200c              /* mtime @ 0x200bff8 */
  addi    t0, t0, -8
  li      s8, 1450                /* ~10150 instructions: crosses 5000 and 10000 */
1:
  rdtime  t1
  ld      t2, 0(t0)
  sd      t1, 0(s7)
  sd      t2, 8(s7)
  addi    s7, s7, 16
  addi    s9, s9, 1
  bne     s9, s8, 1b

  /* ---- 6. the read-only proxies reject every write form ----------------- */
  NEXT    2, 15
  csrw    cycle, t0
  NEXT    2, 16
  csrw    time, t0
  NEXT    2, 17
  csrw    instret, t0
  NEXT    2, 18
  csrrw   t1, cycle, t0
  /* The read forms are legal, but a legal `rdtime` commits a VALUE and the
     tick phase after a trap is not reproducible (the boundary above), so these
     three read with rd = x0: the access still has to pass the permission check
     without a value being compared. */
  csrrs   x0, cycle, x0
  csrrs   x0, time, x0
  csrrs   x0, instret, x0
  csrrc   x0, instret, x0

  /* ---- 7. S-mode gating: mcounteren alone ------------------------------- */
  li      t0, 0x880               /* MPP = S (bits 12:11 = 01), MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  csrw    mcounteren, zero
  csrw    scounteren, zero
  mret
  .align 2
s_code:
  NEXT    2, 19                   /* mcounteren.CY = 0 */
  rdcycle t0
  NEXT    2, 20
  rdtime  t0
  NEXT    2, 21
  rdinstret t0
  NEXT    2, 22
  csrr    t0, mcounteren          /* M-level CSR from S */
  NEXT    9, 23                   /* the S-mode excursion switch */
  ecall
  /* S excursion 1: mcounteren.TM only -> `rdtime` opens, `rdcycle` stays out */
  NEXT    2, 24
  rdcycle t0
  csrrs   x0, time, x0            /* legal: the TM bit is set (no value kept) */
  NEXT    9, 25
  ecall
  /* S excursion 2: mcounteren = 7 -> `cycle`/`instret` open for S */
  csrrs   x0, cycle, x0
  csrrs   x0, instret, x0
  /* scounteren is still 0, so U-mode needs the second gate next */
  li      t0, 0
  csrw    sstatus, zero           /* SPP = U */
  la      t0, u_code
  csrw    sepc, t0
  sret
  .align 2
u_code:
  NEXT    2, 26                   /* scounteren.CY = 0 */
  rdcycle t0
  NEXT    2, 27
  rdtime  t0
  NEXT    2, 28
  rdinstret t0
  NEXT    2, 29
  csrw    scounteren, t0          /* S-level CSR from U */
  NEXT    8, 30                   /* the U-mode excursion switch */
  ecall
  /* U excursion 1: mcounteren = 7, scounteren = 7 -> all three legal */
  csrrs   x0, cycle, x0
  csrrs   x0, time, x0
  csrrs   x0, instret, x0
  NEXT    8, 31
  ecall
  /* U excursion 2: mcounteren = CY only, scounteren = 7 */
  csrrs   x0, cycle, x0
  NEXT    2, 32
  rdtime  t0
  NEXT    2, 33
  rdinstret t0
  NEXT    8, 34
  ecall
  /* U excursion 3: mcounteren = 7, scounteren = TM only */
  NEXT    2, 35
  rdcycle t0
  csrrs   x0, time, x0
  NEXT    2, 36
  rdinstret t0
  NEXT    8, 37
  ecall
  /* U excursion 4: mcounteren = 0, scounteren = 0 -> everything traps again */
  NEXT    2, 38
  rdtime  t0
  /* ---- 8. every expected trap happened, and no other -------------------- */
  li      t0, 24
  bne     s11, t0, .Lf37
  li      a0, 0
  j       exit_ok

.Lf37:
  li      a0, 37
  j       fail

exit_ok:
  li      a0, 0
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

  /* A failed check bails out here with the index in a0 (one shift, then the
     HTIF exit store) — reachable from M and from U mode alike. */
fail:
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

  /* ====================================================================
   * M-mode trap handler. s0 = the armed cause, s3 = the check index.
   * mcause 8 (a U-mode ecall) is the excursion switch: the handler
   * re-programs the counter enables and returns to U with mepc advanced.
   * ==================================================================== */
  .align 2
m_handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  li      t4, 8
  beq     t0, t4, .Lexc
  li      t4, 9
  beq     t0, t4, .Lexc   /* the S-mode excursion switch (same mechanism) */
  beq     t0, s0, .Lchk
  j       .Lhbad
.Lchk:
  /* mtval of an illegal instruction is the instruction word itself */
  csrr    t5, mtval
  csrr    t1, mepc
  lhu     t2, 0(t1)
  lhu     t3, 2(t1)
  slli    t3, t3, 16
  or      t2, t2, t3
  bne     t5, t2, .Lhbad
  j       .Lskip
.Lexc:
  addi    s10, s10, 1             /* excursion index */
  li      t4, 1
  beq     s10, t4, .Lx1
  li      t4, 2
  beq     s10, t4, .Lx2
  li      t4, 3
  beq     s10, t4, .Lx3
  li      t4, 4
  beq     s10, t4, .Lx4
  li      t4, 5
  beq     s10, t4, .Lx5
  li      t4, 6
  beq     s10, t4, .Lx6
  j       .Lhbad
  /* S excursion 1: the TM bit alone opens `time` for S-mode */
.Lx1:
  li      t4, 2
  csrw    mcounteren, t4
  j       .Lskip
  /* S excursion 2: all three enabled for S (scounteren is still 0) */
.Lx2:
  li      t4, 7
  csrw    mcounteren, t4
  j       .Lskip
  /* U excursion 1: both gates open */
.Lx3:
  li      t4, 7
  csrw    mcounteren, t4
  csrw    scounteren, t4
  j       .Lskip
  /* U excursion 2: mcounteren.CY alone with both scounteren gates open */
.Lx4:
  li      t4, 1
  csrw    mcounteren, t4
  li      t4, 7
  csrw    scounteren, t4
  j       .Lskip
  /* U excursion 3: only the TM bit crosses both gates */
.Lx5:
  li      t4, 7
  csrw    mcounteren, t4
  li      t4, 2
  csrw    scounteren, t4
  j       .Lskip
  /* U excursion 4: both gates closed again */
.Lx6:
  csrw    mcounteren, zero
  csrw    scounteren, zero
  j       .Lskip
.Lskip:
  csrr    t1, mepc
  lhu     t2, 0(t1)
  andi    t3, t2, 3
  li      t4, 3
  beq     t3, t4, .L32
  addi    t1, t1, 2
  j       .Lgo
.L32:
  addi    t1, t1, 4
.Lgo:
  csrw    mepc, t1
  mret
.Lhbad:
  li      a0, 99
  ret

  /* The S-mode handler must never run here: medeleg = 0 throughout. */
  .align 2
s_handler:
  li      a0, 98
  ret

  .section .bss
  .align 3
stair: .space 20800             /* 1300 x (rdtime, mtime load) */

  .section .note.GNU-stack, "", @progbits
