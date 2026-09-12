/* SPDX-License-Identifier: MIT
 *
 * Corpus program 18 — `wfi` (E2-RV2 increment 3): the commit, the wait
 * condition, and the interrupt that ends the wait.
 *
 * The pinned Spike ends a wait when `mip & mie` becomes non-zero
 * (`processor.cc take_pending_interrupt()` clears `in_wfi` as soon as ANY
 * locally enabled source is pending), so the wait is not "until an interrupt is
 * taken": a pending source masked by `mstatus.MIE` still ends it, and a WFI
 * entered with `mip & mie != 0` never waits at all. That is what this program
 * pins:
 *
 *   case 1 (MTIP): mtimecmp = 0 (MTIP pending) + mie.MTIE, with mstatus.MIE = 0.
 *   case 2 (MSIP): msip = 1 (MSIP pending) + mie.MSIE, with mstatus.MIE = 0.
 *
 * In both, the WFI commits (it must not stall — a "wait until the interrupt is
 * actually taken" implementation would hang here), the raw store right behind
 * it is the first instruction of the interrupt that ends the wait, and the
 * handler records `mcause`/`mepc`: the cause is the source's IRQ code and
 * `mepc` is the instruction the trap pre-empted (the `after_enable` label),
 * which is exactly how Spike reports a boundary taken at a serializing CSR
 * write.
 *
 * Both cases therefore ARM the source with `mstatus.MIE = 0` and ENABLE it with
 * the serializing `csrs mstatus` — which is what real firmware does, and the
 * only pattern where a cycle-accurate core and Spike agree on WHERE the trap
 * lands: Spike samples interrupts at serializing instructions / WFI / chunk
 * ends (execute.cc), so an interrupt armed by a plain store while MIE is already
 * set is noticed one or more instructions later than a core that samples every
 * boundary (see ../README.md "wfi").
 *
 * The wait ITSELF is not observable on this SoC: it needs a source that becomes
 * pending with no instruction executing, and a single hart ticks its own mtime.
 * The RTL implements it (stall while `mip & mie == 0`) and the formal cover
 * `wfi_wait` witnesses the state; the corpus cannot drive it, and does not
 * pretend to.
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
  la      s0, wlog                /* two 16-byte records: (mcause, mepc) */
  la      t0, mtrap
  csrw    mtvec, t0
  csrw    mstatus, zero           /* MIE = 0 (and MPP = U, MPIE = 0) */
  csrw    mie, zero
  li      t0, 0x222               /* SSIP/STIP/SEIP: drop any software-pending bit */
  csrc    mip, t0
  lui     t0, 0x2000
  sw      zero, 0(t0)             /* msip = 0 */
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* mtimecmp = -1: MTIP clear */

  /* ---------------- case 1: MTIP pending, locally enabled, MIE = 0 --------- */
  lui     t0, 0x2004
  sd      zero, 0(t0)             /* mtimecmp = 0: MTIP pending */
  li      t0, 0x80                /* mie.MTIE */
  csrw    mie, t0
  li      s1, 0x1111
  wfi                             /* `mip & mie` != 0: commits, does not wait */
  li      s2, 0x2222              /* ... so this runs */
  CK      s2, 0x2222, 1
  CK      s1, 0x1111, 2
  li      t0, 0x8                 /* mstatus.MIE */
  csrs    mstatus, t0             /* the pending MTIP is taken at the next boundary */
after_enable1:
  li      s3, 0x3333              /* the handler returns here (mepc) */
  CK      s3, 0x3333, 3

  /* ---------------- case 2: MSIP pending, locally enabled, MIE = 0 ---------
   * MIE must be masked again on purpose: `mret` restores it from MPIE, which the
   * case-1 trap left set, so without this write the MSIP armed below would be
   * taken at the very next serializing instruction (the `csrw mie`) instead of
   * after the WFI. */
  csrw    mstatus, zero
  csrw    mie, zero
  lui     t0, 0x2000
  li      t1, 1
  sw      t1, 0(t0)               /* msip = 1: MSIP pending */
  li      t0, 0x8                 /* mie.MSIE */
  csrw    mie, t0
  li      s4, 0x4444
  wfi                             /* the same rule, a different source */
  li      s5, 0x5555
  CK      s5, 0x5555, 4
  CK      s4, 0x4444, 5
  li      t0, 0x8
  csrs    mstatus, t0
after_enable2:
  li      s6, 0x6666              /* the handler returns here (mepc) */
  CK      s6, 0x6666, 6

  /* ---------------- the two handler records ------------------------------- */
  ld      t0, 0(s0)               /* case 1 mcause: M timer interrupt */
  CK      t0, 0x8000000000000007, 7
  la      t1, after_enable1
  ld      t2, 8(s0)               /* case 1 mepc: the pre-empted instruction */
  beq     t2, t1, .Lrec1
  li      a0, 8
  c.jr    ra
.Lrec1:
  ld      t0, 16(s0)              /* case 2 mcause: M software interrupt */
  CK      t0, 0x8000000000000003, 9
  la      t1, after_enable2
  ld      t2, 24(s0)              /* case 2 mepc */
  beq     t2, t1, .Lrec2
  li      a0, 10
  c.jr    ra
.Lrec2:
  li      a0, 0
  ret

  /* ---- trap handler: record (mcause, mepc), silence every source, resume --
   * It clobbers only t0-t4, which the program does not keep live across a trap
   * (an earlier draft clobbered the address register of the instruction behind
   * the trap and turned a real trap into a different one). */
  .align 2
mtrap:
  csrr    t1, mcause
  csrr    t2, mepc
  la      t4, wrec
  ld      t0, 0(t4)               /* record index */
  addi    t3, t0, 1
  sd      t3, 0(t4)               /* ... advance it */
  slli    t0, t0, 4               /* 16 bytes per record */
  la      t3, wlog
  add     t3, t3, t0
  sd      t1, 0(t3)
  sd      t2, 8(t3)
  lui     t0, 0x2004
  li      t1, -1
  sd      t1, 0(t0)               /* mtimecmp = -1: MTIP clear */
  lui     t0, 0x2000
  sw      zero, 0(t0)             /* msip = 0 */
  csrw    mie, zero               /* no source can fire again while MIE is off */
  mret

  .section .data
  .align 3
wrec:
  .dword 0
wlog:
  .space 32

  .section .note.GNU-stack, "", @progbits
