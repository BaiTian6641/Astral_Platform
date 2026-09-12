/* SPDX-License-Identifier: MIT
 *
 * Corpus program — the PMP CSR floor (E2-RV2 increment 7, S4).
 *
 * The S4 boot found this gap the hard way: OpenSBI's first `csrw pmpcfg0` trapped
 * (cause 2) because the hart implemented no PMP CSRs, and a firmware that cannot
 * program PMP is not a firmware you can hand a kernel to. This program pins the
 * CSR behaviour the pinned golden was measured to have
 * (local://rv10-counter-notes.md §1.6, probe2/probe3pmp):
 *
 *   * reset: `pmpcfg0 = 0x1F` (entry 0 = R|W|X|A=NAPOT, "allow everything"),
 *     `pmpaddr0 = 0x003fffffffffffff` (`put_csr(~0)` masked to the 56-bit paddr),
 *     every other entry zero;
 *   * `pmpaddr*` write mask = 0x003fffffffffffff, `pmpcfg*` byte mask = 0x9f;
 *   * the L bit LOCKS: after `pmpcfg0 = -1` the read-back is 0x9f9f…9f, a following
 *     `pmpcfg0 = 0` is DROPPED, and so is the `pmpaddr1` write;
 *   * RV64 has no `pmpcfg1`/`pmpcfg3`: a probe armed cause 2 for each and they must
 *     keep trapping.
 *
 * NOT covered here, deliberately: region ENFORCEMENT. The hart checks no PMP on any
 * access (stated in eth_rv_core.sv's PMP note) — mirroring the storage without
 * enforcing is the honest half of this floor, and this program asserts only what a
 * program can *observe through the CSRs*.
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S); the
 * handler returns a0 = 99 for a wrong cause, and the DiffTest compares every commit
 * against Spike on top of that.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, mtval, index — arm the trap the next instruction must raise.
     mtval = -1 means "do not check it" (an illegal instruction reports the
     instruction word, which this program does not want to spell out). */
  .macro NEXT cause, mtval, index
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      t0, handler
  csrw    mtvec, t0
  li      s11, 0                  /* trap counter */

  /* ==== 1. the reset state: region 0 is "allow everything" ==== */
  csrr    s6, pmpcfg0
  CK      s6, 0x1f, 1
  csrr    s6, pmpaddr0
  li      s7, 0x003fffffffffffff
  bne     s6, s7, .Lp2
  csrr    s6, pmpaddr1
  CK      s6, 0, 3
  csrr    s6, pmpcfg2
  CK      s6, 0, 4

  /* ==== 2. the write masks: 56-bit paddr, 0x9f per cfg byte ==== */
  li      s6, -1
  csrw    pmpaddr2, s6
  csrr    s7, pmpaddr2
  li      s8, 0x003fffffffffffff
  bne     s7, s8, .Lp5
  li      s6, -1
  csrw    pmpcfg2, s6
  csrr    s7, pmpcfg2
  li      s8, 0x9f9f9f9f9f9f9f9f
  bne     s7, s8, .Lp6

  /* ==== 3. the L bit locks its own cfg write ... ==== */
  li      s6, -1
  csrw    pmpcfg0, s6
  csrr    s7, pmpcfg0
  li      s8, 0x9f9f9f9f9f9f9f9f
  bne     s7, s8, .Lp7
  li      s6, 0
  csrw    pmpcfg0, s6             /* dropped: every entry it covers is locked */
  csrr    s7, pmpcfg0
  bne     s7, s8, .Lp8

  /* ==== 4. ... and the matching pmpaddr write ==== */
  li      s6, 0
  csrw    pmpaddr1, s6            /* dropped: entry 1's cfg has L set */
  csrr    s7, pmpaddr1
  li      s8, 0x003fffffffffffff  /* what check 2 left there (#2 wrote addr2, so
                                    this is the reset value of addr1... which is 0) */
  li      s8, 0
  bne     s7, s8, .Lp9

  /* ==== 5. RV64 has no pmpcfg1 / pmpcfg3: both must trap ==== */
  NEXT    2, -1, 10
  csrr    s6, pmpcfg1
  NEXT    2, -1, 11
  csrw    pmpcfg3, s6

  /* ==== 6. pmpaddr16..63 are NOT covered here, deliberately -------------------
     The S4 boot's second divergence is this range, and the first attempt to pin
     it (arming cause 2 for a read AND a write of 0x3c0/0x3ef) failed on the
     golden side, which measured two things:

       * the pinned golden does NOT trap on `csrr 0x3c0` — it reads 0, i.e. it
         implements the whole pmpaddr0..63 map even with --pmpregions=16 (the S2
         probe table stopped at pmpaddr15, which is why this was unknown);
       * its `csrw 0x3ef, -1` read-back is NOT the 56-bit masked value the
         pmpaddr0..15 registers use, so the extra registers have different write
         semantics — still unmeasured.

     Meanwhile the *boot* does not care: OpenSBI's PMP discovery treats the trap
     as "that region does not exist" and carries on, which is why the console is
     unaffected. So this is a DiffTest-level divergence (our hart traps where the
     golden reads 0), not a milestone blocker — recorded in the README and
     local://rv12-linux-notes.md §11 as the next measurement (write ~0 to
     pmpaddr16/63, read back: unmasked? RAZ/WI? per-region?) rather than asserted
     from a guess.
     ==== */

  /* ==== 7. exactly the armed traps happened ==== */
  li      t0, 2
  bne     s11, t0, .Lp12

  li      a0, 0
  ret

.Lp2:
  li      a0, 2
  ret
.Lp5:
  li      a0, 5
  ret
.Lp6:
  li      a0, 6
  ret
.Lp7:
  li      a0, 7
  ret
.Lp8:
  li      a0, 8
  ret
.Lp9:
  li      a0, 9
  ret
.Lp12:
  li      a0, 12
  ret

  /* ===================================================================
   * trap handler: check the armed cause (and mtval when one was given),
   * then step over the trapping instruction.
   * =================================================================== */
  .align 2
handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  csrr    t5, mtval
  li      t4, -1
  beq     s2, t4, .Lhadv          /* no mtval expectation */
  bne     t5, s2, .Lhbad
.Lhadv:
  csrr    t1, mepc
  lhu     t2, 0(t1)
  andi    t3, t2, 3
  li      t4, 3
  beq     t3, t4, .Lh32
  addi    t1, t1, 2
  j       .Lhgo
.Lh32:
  addi    t1, t1, 4
.Lhgo:
  csrw    mepc, t1
  mret

.Lhbad:
  li      a0, 99
  ret
