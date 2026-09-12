/* SPDX-License-Identifier: MIT
 *
 * Corpus program — MPRV-translated M-mode data access (E2-RV2 S4 gap closure).
 *
 * The S4 Linux boot died here, so this program reproduces the exact mechanism in
 * ~40 instructions. The kernel's `check_unaligned_access_emulated()` (Alpine
 * linux-lts 6.18.48, arch/riscv/kernel/traps_misaligned.c) executes one
 * deliberately unaligned 8-byte load and expects the *architectural* trap
 * (mcause 4). With OpenSBI v1.3 as the M-mode firmware the trap is not delegated
 * to S-mode (`sbi_fwft_set(SBI_FWFT_MISALIGNED_EXC_DELEG)` predates v1.5, so
 * `unaligned_access_init()` gives up), so the MISALIGNED trap is taken in
 * M-mode and `sbi_misaligned_load_handler()` emulates it: for each of the eight
 * bytes it calls `sbi_load_u8()`, which sets `mstatus.MPRV`, does an `lbu`, and
 * restores mstatus — so every one of those byte reads is a **translated M-mode
 * access whose privilege is `mstatus.MPP` = the mode that trapped (S)**.
 *
 * That is the one access class no earlier corpus program exercised: an M-mode
 * data access with MPRV = 1 (E2-RV2 increments 1..7 covered S/U-mode translation
 * and untranslated M-mode). The S4 run showed what a disagreement looks like:
 * the emulating `lbu` at `addr+1` raised a LOAD PAGE FAULT (`cause 13`,
 * `stval = addr+1`) instead of translating, OpenSBI redirected it to S-mode with
 * the *original* `mepc`, and Linux panicked on a page fault it never asked for.
 *
 * The program's phases, in order:
 *   1. S-mode, Sv39 on: a plain translated load (the baseline), then the kernel's
 *      own misaligned `ld` — trapped in M-mode (medeleg = 0) and emulated the
 *      way OpenSBI does it: byte-at-a-time, `MPRV` set around each `lbu`. The
 *      emulated value must land in the destination register and the trap's
 *      `mtval` must be the address the instruction named.
 *   2. M-mode: the same `lbu` with `MPRV = 1` and `MPP` = S (the emulation's
 *      access: must translate and read the datum), then with `MPP` = U (must be
 *      a page fault — the leaf is U = 0) and with `MPP` = M (must NOT translate:
 *      a physical access to 0x4000_0001, which nothing claims).
 *   3. A U = 1 leaf for contrast: `MPP` = U translates it, `MPP` = S does not
 *      (SUM = 0), which is what makes phase 2's MPP = U page fault an answer
 *      about the leaf and not about MPRV being ignored.
 *
 * Every expected value below is a Spike observation, probed before the program
 * was written (local://rv13-s4-notes.md has the commands and outputs).
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S);
 * the handler returns a0 = 99 for a wrong cause/mtval and 98 for an unexpected
 * trap.
 */

  /* CK reg, want, index — compare; on mismatch fail with a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  j       fail
.Lck\@:
  .endm

  /* CKV pointer, want, index — compare memory against an immediate. */
  .macro CKV ptr, want, index
  la      t6, \ptr
  ld      t6, 0(t6)
  li      t5, \want
  beq     t6, t5, .Lcv\@
  li      a0, \index
  j       fail
.Lcv\@:
  .endm

  /* ARMVAL — save the recorded (cause, tval, count) as the expectation; the
     checks compare against the saved copies so the handler can keep
     overwriting the live slots. */
  .macro ARMVAL
  la      t0, rec_cause
  ld      t0, 0(t0)
  la      t1, exp_cause
  sd      t0, 0(t1)
  la      t0, rec_tval
  ld      t0, 0(t0)
  la      t1, exp_tval
  sd      t0, 0(t1)
  .endm

  /* CLRREC — clear the live record (cause, tval and the trap count). Each phase
     clears it before its access, so "no trap" is `rec_count == 0` and a stray
     trap is caught by the count rather than by a stale cause. */
  .macro CLRREC
  la      t0, rec_cause
  sd      zero, 0(t0)
  la      t0, rec_tval
  sd      zero, 0(t0)
  la      t0, rec_count
  sd      zero, 0(t0)
  .endm

  /* EXPECT cause, tval, index — the next trap must have had exactly these,
     checked from the saved expectation. */
  .macro EXPECT cause, tval, index
  CKV     exp_cause, \cause, \index
  CKV     exp_tval, \tval, \index
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      t0, m_handler
  csrw    mtvec, t0
  csrw    medeleg, zero           /* the misaligned trap stays in M-mode */
  csrw    mideleg, zero
  CLRREC

  /* ---- zero the page tables (root + l1id + l1 + l0) ------------------- */
  la      t0, pt_root
  li      t1, 0
  li      t2, (4 * 4096) / 8
1:
  sd      t1, 0(t0)
  addi    t0, t0, 8
  addi    t2, t2, -1
  bnez    t2, 1b

  /* root[2] -> pt_l1id; pt_l1id[0] = the 2 MiB identity superpage the whole
     program (code, data, page tables, stack) runs on, X included: every fetch
     below is translated. VA 0x8000_0000 has VPN[2] = 2 and VPN[1] = 0, so the
     root index is 2 and the L1 index is 0. */
  la      t0, pt_root
  la      t1, pt_l1id
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 16(t0)
  la      t0, pt_l1id
  li      t1, (0x80000 << 10) | 0xcf
  sd      t1, 0(t0)

  /* the test VA 0x4000_0000: root[1] -> pt_l1[0] -> pt_l0[0] = the leaf that
     maps the datum page. V|R|W|A|D, U = 0 — a kernel data page, exactly the
     shape of the S4 kernel's stack/scratch leaf (pte 0x…e7). */
  la      t0, pt_root
  la      t1, pt_l1
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 8(t0)
  la      t0, pt_l1
  la      t1, pt_l0
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 0(t0)
  la      t0, pt_l0
  la      t1, dpage
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 0xc7
  sd      t1, 0(t0)

  /* the datum, written physically in M-mode (M-mode is never translated while
     MPRV is clear): bytes 01..10 so a misaligned read has a distinct value. */
  la      t0, dpage
  li      t1, 0x0807060504030201
  sd      t1, 0(t0)
  li      t1, 0x100f0e0d0c0b0a09
  sd      t1, 8(t0)

  /* satp = Sv39 | root>>12 */
  la      t0, pt_root
  srli    t0, t0, 12
  li      t1, 8
  slli    t1, t1, 60
  or      t0, t0, t1
  csrw    satp, t0
  sfence.vma

  /* into S-mode (MPP = S, MPIE = 1) */
  li      t0, 0x880
  csrw    mstatus, t0
  la      t0, s_entry
  csrw    mepc, t0
  mret

  /* =====================================================================
   * S-mode: the baseline load, then the kernel's own misaligned probe.
   * ===================================================================== */
  .align 2
s_entry:
  li      s7, 0x40000000
  ld      s5, 0(s7)               /* 1: a plain translated load */
  CK      s5, 0x0807060504030201, 1

  /* 2: the kernel's `ld %[tmp], 1(%[ptr])`. It must raise cause 4 with
     mtval = the address the instruction named; the M-mode handler (playing
     OpenSBI) emulates it and the value must land in s5. */
  li      s5, 0
  ld      s5, 1(s7)
  CK      s5, 0x0908070605040302, 2
  ARMVAL
  EXPECT  4, 0x40000001, 3
  CKV     rec_count, 1, 4

  ecall                           /* back to M-mode (medeleg = 0) */

  /* =====================================================================
   * M-mode: MPRV. Each check arms the record, sets mstatus from scratch, makes
   * ONE access, and clears mstatus again before it touches any memory — because
   * with MPRV set *every* M-mode data access is translated, including the
   * bookkeeping ones, and the handler's mret leaves MPP = U (spec), which would
   * make them all fault. The trap handler restores mstatus around its own
   * accesses, so the discipline here is only about the checks.
   * ===================================================================== */

  /* 5: MPRV + MPP = S — OpenSBI's `sbi_load_u8` access, the one that faulted
     in the S4 boot. MPP = S (0x800) | MPIE (0x80) | MPRV (0x20000). */
.Lm_mprv_s:
  csrw    mstatus, zero
  CLRREC
  li      t0, 0x20880
  csrw    mstatus, t0
  li      t1, 0x40000000
  lbu     t2, 1(t1)               /* byte dpage[1] through the S translation */
  csrw    mstatus, zero
  CK      t2, 0x02, 5
  ARMVAL
  EXPECT  0, 0, 6
  CKV     rec_count, 0, 7

  /* 6: MPRV + MPP = U against the U = 0 leaf: the same access, one privilege
     down, must be a page fault with mtval = the address. This is the control
     that makes check 5 an answer about translation rather than about MPRV
     being ignored (with MPRV ignored the access would be physical and fault
     with cause 5, and with MPP ignored it would succeed). */
  csrw    mstatus, zero
  CLRREC
  li      t0, 0x20080              /* MPP = U | MPIE | MPRV */
  csrw    mstatus, t0
  li      t1, 0x40000000
  lbu     t2, 1(t1)               /* must fault: U access to a U = 0 leaf */
  csrw    mstatus, zero
  ARMVAL
  EXPECT  13, 0x40000001, 8
  CKV     rec_count, 1, 9

  /* 7: MPRV + MPP = M: no translation at all (Spike: the mode is M, so the
     access is physical). 0x4000_0001 is not memory on either side, so the
     answer is an access fault, NOT a page fault — the discriminator between
     "translated with the wrong privilege" and "not translated". */
  csrw    mstatus, zero
  CLRREC
  li      t0, 0x1800 | 0x80 | 0x20000   /* MPP = M | MPIE | MPRV */
  csrw    mstatus, t0
  li      t1, 0x40000000
  lbu     t2, 1(t1)               /* physical: nothing claims 0x4000_0001 */
  csrw    mstatus, zero
  ARMVAL
  EXPECT  5, 0x40000001, 10
  CKV     rec_count, 1, 11

  /* 8: the U = 1 leaf. MPRV + MPP = U translates it (the U/S rule passes), so
     this is a positive control for the U privilege path. */
  csrw    mstatus, zero
  CLRREC
  la      t0, pt_l0
  la      t1, dpage
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 0xd7             /* V|R|W|U|A|D */
  sd      t1, 0(t0)
  sfence.vma
  li      t0, 0x20080              /* MPP = U | MPIE | MPRV */
  csrw    mstatus, t0
  li      t1, 0x40000000
  lbu     t2, 1(t1)
  csrw    mstatus, zero
  CK      t2, 0x02, 12
  ARMVAL
  EXPECT  0, 0, 13
  CKV     rec_count, 0, 14

  /* 9: and the same U = 1 leaf from S-mode with SUM = 0 must be a page fault
     (the U/S rule is about the *access*, so it must not be bypassed by the
     privilege MPRV selected). */
  csrw    mstatus, zero
  CLRREC
  li      t0, 0x20880              /* MPP = S | MPIE | MPRV, SUM = 0 */
  csrw    mstatus, t0
  li      t1, 0x40000000
  lbu     t2, 1(t1)               /* SUM = 0: an S access to a U page faults */
  csrw    mstatus, zero
  ARMVAL
  EXPECT  13, 0x40000001, 15
  CKV     rec_count, 1, 16

  /* ---- all checks passed --------------------------------------------- */
  li      a0, 0
  ret

  /* ===================================================================
   * M-mode trap handler: records (cause, tval) and plays OpenSBI for the
   * misaligned load in check 2 — eight byte reads, each with MPRV set around
   * an `lbu` and mstatus restored afterwards (`sbi_load_u8`), then the value
   * into s5 (the destination the trapped instruction named, checked below).
   * =================================================================== */
  .align 2
m_handler:
  addi    sp, sp, -64
  sd      t0, 0(sp)
  sd      t1, 8(sp)
  sd      t2, 16(sp)
  sd      t3, 24(sp)
  sd      t4, 32(sp)
  sd      t5, 40(sp)
  sd      t6, 48(sp)

  csrr    t0, mcause
  csrr    t1, mtval
  csrr    t2, mepc
  li      t3, 9
  beq     t0, t3, .Lhenv           /* the ecall that ends the S-mode phase */
  li      t3, 4
  bne     t0, t3, .Lhskip          /* only the armed traps are expected here */

  /* record */
  la      t3, rec_cause
  sd      t0, 0(t3)
  la      t3, rec_tval
  sd      t1, 0(t3)
  la      t3, rec_count
  ld      t4, 0(t3)
  addi    t4, t4, 1
  sd      t4, 0(t3)

  /* emulate: value = sum over i of lbu(addr + i) << (8*i). The destination is
     the program's s5 — the only misaligned load in it — and check 2 verifies
     the emulated value landed there, so a wrong destination cannot pass. */
  la      t3, rec_addr
  sd      t1, 0(t3)
  la      t3, rec_val
  sd      zero, 0(t3)
  li      t0, 0                    /* i */
.Lhemu:
  la      t1, rec_addr
  ld      t1, 0(t1)
  add     t1, t1, t0               /* addr + i */
  li      t2, 0x20000
  csrrs   t2, mstatus, t2          /* mstatus |= MPRV; t2 = the old value */
  lbu     t3, 0(t1)                /* sbi_load_u8's access */
  csrw    mstatus, t2              /* restore (MPP included) */
  slli    t0, t0, 3
  sll     t3, t3, t0
  srli    t0, t0, 3
  /* PROBE: mstatus as the hart reads it, right before the access that follows
     the restore — the DiffTest compares this store, so a privilege/MPRV
     disagreement shows up here rather than as an unexplained fault. */
  csrr    t5, mstatus
  la      t1, rec_status
  sd      t5, 0(t1)
  la      t1, rec_val
  ld      t4, 0(t1)
  or      t4, t4, t3
  sd      t4, 0(t1)
  addi    t0, t0, 1
  li      t5, 8
  blt     t0, t5, .Lhemu
  la      t1, rec_val
  ld      s5, 0(t1)                /* SET_RD(insn, regs, val) */

  /* advance past the trapping instruction by its own length */
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
  j       .Lhret

  /* every other trap: record it and step over it, so a wrong cause or mtval
     shows up as a failed check rather than as a hang */
.Lhskip:
  la      t3, rec_cause
  sd      t0, 0(t3)
  la      t3, rec_tval
  sd      t1, 0(t3)
  la      t3, rec_count
  ld      t4, 0(t3)
  addi    t4, t4, 1
  sd      t4, 0(t3)
  csrr    t1, mepc
  lhu     t2, 0(t1)
  andi    t3, t2, 3
  li      t4, 3
  beq     t3, t4, .Lh32
  addi    t1, t1, 2
  csrw    mepc, t1
  j       .Lhret

  /* the ecall: resume in M-mode at .Lm_entry (the MPRV phase). MPP = M is what
     makes the mret return to M-mode rather than back to S-mode. */
.Lhenv:
  la      t1, .Lm_entry
  csrw    mepc, t1
  csrr    t1, mstatus
  li      t3, ~0x1800
  and     t1, t1, t3
  li      t3, 0x1800
  or      t1, t1, t3
  csrw    mstatus, t1
  j       .Lhret

.Lhbad:
  li      a0, 99
  j       fail

.Lhret:
  ld      t0, 0(sp)
  ld      t1, 8(sp)
  ld      t2, 16(sp)
  ld      t3, 24(sp)
  ld      t4, 32(sp)
  ld      t5, 40(sp)
  ld      t6, 48(sp)
  addi    sp, sp, 64
  mret

.Lm_entry:
  j       .Lm_mprv_s

  /* a0 = the exit index: write the HTIF exit word and spin (the handler has
     clobbered `ra`, so `ret` is not a way out of a failure) */
fail:
  csrw    mstatus, zero           /* the exit store must not be translated */
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
9:
  j       9b

  /* .Lm_entry above is reached by the ecall handler's mret; the MPRV checks
     run from there. Kept as a label right after the handler so the address is
     an immediate (auipc/addi) rather than a load. */

  .section .bss
  .align 3
rec_cause:
  .space 8
rec_tval:
  .space 8
rec_count:
  .space 8
rec_addr:
  .space 8
rec_val:
  .space 8
rec_status:
  .space 8
exp_cause:
  .space 8
exp_tval:
  .space 8
  .align 12
dpage:
  .space 4096
  .align 12
pt_root:
  .space 4096
  .align 12
pt_l1id:
  .space 4096
  .align 12
pt_l1:
  .space 4096
  .align 12
pt_l0:
  .space 4096

  .section .note.GNU-stack, "", @progbits
