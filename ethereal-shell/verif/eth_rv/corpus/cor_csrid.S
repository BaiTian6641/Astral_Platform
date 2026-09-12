/* SPDX-License-Identifier: MIT
 *
 * Corpus program 20 — the identification / environment-configuration floor
 * (E2-RV2 increment 4).
 *
 * Every expected value is a probed observation of the pinned Spike
 * (`--isa=rv64imafdc_zicsr_zicntr`, commit 1e05ddac); the probe table is
 * `local://rv10-counter-notes.md` §1.1/§1.6 and the DiffTest re-checks every
 * value on both sides.
 *
 * Coverage:
 *   * the read-only identification CSRs: `mvendorid` 0, `marchid` 5 (Spike's
 *     own id), `mimpid` 0, `mconfigptr` 0, `mhartid` 0 — a *write* to any of
 *     them is an illegal instruction, not a silent drop
 *   * `menvcfg`/`senvcfg`: reset 0, FIOM-only write mask (bit 0), so writing
 *     all-ones reads back exactly 1 and every other bit is zero
 *   * the RV32-only halves (and the CSRs of extensions this hart does not have)
 *     stay ILLEGAL on RV64: `mcycleh`, `minstreth`, `mstatush`, `menvcfgh`,
 *     `senvcfgh`, the odd `pmpcfg1`/`pmpcfg3`, and — because the golden ISA
 *     string does not enable Zihpm — the user `hpmcounter3`/`hpmcounter3h`
 *   * the machine performance-counter floor: `mhpmcounter3..31` and
 *     `mhpmevent3..31` are legal, read zero and swallow every write
 *   * the S-mode view: `senvcfg` is an S-level CSR (writable from S) while
 *     `menvcfg` and the identification CSRs stay M-only
 *
 * `main` returns 0 on success, or the index of the first failed check (crt0.S);
 * the handler verifies each armed cause and mtval, and the final check counts
 * the traps, so an expectation that is never armed cannot pass unnoticed.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, index — arm the expectation for the next trap. */
  .macro NEXT cause, index
  li      s0, \cause
  li      s2, -2                  /* mtval: check the instruction word */
  li      s3, \index
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      s5, m_handler
  csrw    mtvec, s5
  csrw    medeleg, zero
  csrw    mideleg, zero
  li      s11, 0
  li      s0, 0

  /* ---- 1. the identification CSRs, read --------------------------------- */
  csrr    t0, mvendorid
  CK      t0, 0, 1
  csrr    t0, marchid
  CK      t0, 5, 2
  csrr    t0, mimpid
  CK      t0, 0, 3
  csrr    t0, mconfigptr
  CK      t0, 0, 4
  csrr    t0, mhartid
  CK      t0, 0, 5

  /* ---- 2. ... and write: every one of them is read-only ----------------- */
  li      t0, -1
  NEXT    2, 6
  csrw    mvendorid, t0
  NEXT    2, 7
  csrw    marchid, t0
  NEXT    2, 8
  csrw    mimpid, t0
  NEXT    2, 9
  csrw    mconfigptr, t0
  NEXT    2, 10
  csrw    mhartid, t0

  /* ---- 3. menvcfg / senvcfg: FIOM-only ---------------------------------- */
  csrr    t0, menvcfg
  CK      t0, 0, 11
  li      t0, -1
  csrw    menvcfg, t0
  csrr    t1, menvcfg
  CK      t1, 1, 12
  li      t0, 3                   /* only bit 0 is writable */
  csrw    menvcfg, t0
  csrr    t1, menvcfg
  CK      t1, 1, 13
  csrw    menvcfg, zero
  csrr    t1, menvcfg
  CK      t1, 0, 14
  csrr    t0, senvcfg
  CK      t0, 0, 15
  li      t0, -1
  csrw    senvcfg, t0
  csrr    t1, senvcfg
  CK      t1, 1, 16
  csrw    senvcfg, zero
  csrr    t1, senvcfg
  CK      t1, 0, 17

  /* ---- 4. the RV32-only halves and the Zihpm proxies stay illegal ------- */
  NEXT    2, 18
  csrr    t0, mcycleh
  NEXT    2, 19
  csrr    t0, minstreth
  NEXT    2, 20
  csrr    t0, mstatush
  NEXT    2, 21
  csrr    t0, menvcfgh
  NEXT    2, 22
  csrr    t0, 0x11a               /* senvcfgh: not a binutils CSR name */
  NEXT    2, 23
  csrr    t0, pmpcfg1             /* pmpcfg is even-register only on RV64 */
  NEXT    2, 24
  csrr    t0, pmpcfg3
  NEXT    2, 25
  csrr    t0, hpmcounter3         /* user proxies need Zihpm */
  NEXT    2, 26
  csrr    t0, hpmcounter3h

  /* ---- 5. the machine performance counters: zero, writes dropped -------- */
  csrr    t0, mhpmcounter3
  CK      t0, 0, 27
  li      t0, -1
  csrw    mhpmcounter3, t0
  csrr    t0, mhpmcounter3
  CK      t0, 0, 28
  csrr    t0, mhpmevent3
  CK      t0, 0, 29
  li      t0, -1
  csrw    mhpmevent3, t0
  csrr    t0, mhpmevent3
  CK      t0, 0, 30
  csrr    t0, mhpmcounter31
  CK      t0, 0, 31
  csrr    t0, mhpmevent31
  CK      t0, 0, 32

  /* ---- 6. the S-mode view: senvcfg is S-level, menvcfg/identity are not -- */
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_code
  csrw    mepc, t0
  mret
  .align 2
s_code:
  li      t0, 1
  csrw    senvcfg, t0             /* legal from S */
  csrr    t1, senvcfg
  CK      t1, 1, 33
  csrw    senvcfg, zero
  NEXT    2, 34
  csrr    t0, menvcfg             /* M-level CSR from S */
  NEXT    2, 35
  csrr    t0, mvendorid
  /* ---- 7. every expected trap happened, and no other -------------------- */
  li      t0, 16
  bne     s11, t0, .Lf36
  li      a0, 0
  j       exit_ok

.Lf36:
  li      a0, 36
  j       fail

exit_ok:
  li      a0, 0
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

fail:
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b

  /* ====================================================================
   * M-mode trap handler: verify the armed cause and mtval, then skip the
   * trapping instruction (2- or 4-byte).
   * ==================================================================== */
  .align 2
m_handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  beq     t0, s0, .Lchk
  j       .Lhbad
.Lchk:
  csrr    t5, mtval
  csrr    t1, mepc
  lhu     t2, 0(t1)
  lhu     t3, 2(t1)
  slli    t3, t3, 16
  or      t2, t2, t3
  bne     t5, t2, .Lhbad
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
  j       fail

  .section .note.GNU-stack, "", @progbits
