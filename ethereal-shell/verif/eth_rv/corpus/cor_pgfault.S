/* SPDX-License-Identifier: MIT
 *
 * Corpus program — page faults and their delegation (E2-RV2 increment 1, C14 §3).
 *
 * Where `cor_sv39.S` walks the permission matrix, this program pins the fault
 * path itself: the three page-fault causes, the `mtval`/`stval` they carry (the
 * virtual address, never the physical one), which of them `medeleg` hands to
 * S-mode, the S-mode trap-entry bookkeeping, and the rule that a trap taken in
 * M-mode is never delegated. Every expectation below was probed against Spike
 * first (see local://rv7-notes.md).
 *
 * Coverage:
 *   * causes 13 / 15 / 12 raised in S-mode with `medeleg = 0` are handled by the
 *     M-mode handler with `mtval` = the faulting virtual address (for the fetch
 *     fault, the faulting *target*)
 *   * with `medeleg = 0b1011_0000_0000_0000` (12/13/15) the same faults land in
 *     the S-mode handler, which checks `scause`, `stval`, `sepc` (the faulting
 *     instruction's own address) and `sstatus.SPP` before resuming
 *   * a page fault raised in U-mode is delegated too (SPP = U) and the U-mode
 *     code continues after the `sret`
 *   * a trap raised IN M-mode is never delegated, whatever `medeleg` says
 *   * `medeleg`'s write mask keeps exactly 1..9, 12, 13 and 15
 *
 * Registers: the M-mode handler owns t0..t5, s0, s2, s3, s9, s10, s11 and a0;
 * the S-mode handler reads s0/s2/s3/s4/s5 and writes only t0 (so t1/t4 survive it
 * and the U-mode stub can use them). The phase code keeps its live state in the
 * s-registers.
 */

  /* CK reg, want, index — compare; on mismatch fail with a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  j       fail
.Lck\@:
  .endm

  /* ARM cause, mtval, index — the next M-mode trap must have exactly these. */
  .macro ARM cause, tval, index
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  li      s9, 0
  li      s10, 0
  .endm

  /* ARMS cause, mtval, index, addr — ... and the handler resumes at `addr`
     in the trapping mode (a fetch fault's mepc is the unfetchable target). */
  .macro ARMS cause, tval, index, addr
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  li      s9, 0
  la      s10, \addr
  .endm

  /* ARMM cause, mtval, index, addr — ... and the handler resumes in M-mode at
     `addr` (the phase switches and the U-mode exit). */
  .macro ARMM cause, tval, index, addr
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  la      s9, \addr
  li      s10, 0
  .endm

  /* SDARM scause, stval, sepc, spp, resume — arm the S-mode handler. */
  .macro SDARM cause, val, epc, spp, resume
  li      s0, \cause
  li      s2, \val
  la      s3, \epc
  li      s4, \spp
  la      s5, \resume
  .endm

  /* PTE0 flags — pt_l0t[0] = the scratch leaf with exactly these low-10-bit flags. */
  .macro PTE0 flags
  la      t0, pt_l0t
  mv      t2, s8
  li      t3, ~0x3ff
  and     t2, t2, t3
  li      t3, \flags
  or      t2, t2, t3
  sd      t2, 0(t0)
  sfence.vma
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      t0, m_handler
  csrw    mtvec, t0
  la      t0, s_handler
  csrw    stvec, t0
  csrw    medeleg, zero
  csrw    mideleg, zero
  li      s11, 0

  /* ---- zero the page tables (pt_root + pt_l1id + pt_l1t + pt_l0t) ------ */
  la      t0, pt_root
  li      t1, 0
  li      t2, (4 * 4096) / 8
1:
  sd      t1, 0(t0)
  addi    t0, t0, 8
  addi    t2, t2, -1
  bnez    t2, 1b

  /* s8 = the baseline leaf PTE */
  la      s8, scratch
  srli    s8, s8, 12
  slli    s8, s8, 10
  ori     s8, s8, 0xcf

  /* ---- medeleg's write mask, and the three page-fault bits ------------ */
  li      t0, -1
  csrw    medeleg, t0
  csrr    t0, medeleg
  CK      t0, 0x000000000000b3fe, 1
  li      t0, 0xb000              /* exactly 12 / 13 / 15 */
  csrw    medeleg, t0
  csrr    t0, medeleg
  CK      t0, 0xb000, 2
  csrw    medeleg, zero           /* phase 1 is not delegated */
  csrw    mideleg, zero

  /* ---- the page tables ------------------------------------------------ */
  la      t0, pt_root
  la      t1, pt_l1id
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 16(t0)              /* root[2] -> pt_l1id */
  la      t0, pt_l1id
  li      t1, (0x80000 << 10) | 0xcf
  sd      t1, 0(t0)               /* the 2 MiB identity superpage */
  la      t0, pt_root
  la      t1, pt_l1t
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 8(t0)               /* root[1] -> pt_l1t */
  la      t0, pt_l1t
  la      t1, pt_l0t
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 0(t0)               /* pt_l1t[0] -> pt_l0t */
  la      t0, pt_l0t
  sd      s8, 0(t0)               /* page A -> scratch */
  la      t0, pt_l0t
  la      t1, scratch2
  srli    t1, t1, 12
  slli    t1, t1, 10
  li      t2, 0xdf                /* page B -> scratch2, V|R|W|X|U|A|D */
  or      t1, t1, t2
  sd      t1, 8(t0)
  /* scratch: a known value, for the positive controls */
  la      t2, scratch
  li      t0, 0xfeedfacecafebeef
  sd      t0, 0(t2)
  /* copy the U-mode stub into page B */
  la      t0, u_blob
  la      t1, scratch2
  la      t2, u_blob_end
  sub     t2, t2, t0
2:
  ld      t3, 0(t0)
  sd      t3, 0(t1)
  addi    t0, t0, 8
  addi    t1, t1, 8
  addi    t2, t2, -8
  bgtz    t2, 2b

  /* ---- into S-mode, medeleg = 0 --------------------------------------- */
  la      t0, pt_root
  srli    t0, t0, 12
  li      t1, 8
  slli    t1, t1, 60
  or      t0, t0, t1
  csrw    satp, t0
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_phase1
  csrw    mepc, t0
  mret

  /* =====================================================================
   * S-mode phase 1: medeleg = 0, so the M-mode handler takes the faults
   * ===================================================================== */
  .align 2
s_phase1:
  li      s7, 0x40000000
  /* 10: a load page fault carries the virtual address */
  PTE0    0xce                    /* V = 0 */
  ARM     13, 0x40000000, 10
  ld      t0, 0(s7)
  /* 11: and so does a store page fault */
  ARM     15, 0x40000008, 11
  sd      t0, 8(s7)
  /* 12: an instruction page fault (the target is mapped, but not executable) */
  PTE0    0xc7                    /* V|R|W|A|D */
  la      ra, 3f
  li      t1, 0x40000000
  ARMS    12, 0x40000000, 12, 3f
  jalr    ra, t1, 0
3:
  ARMM    9, 0, 13, m_phase2
  ecall

  /* =====================================================================
   * M-mode: turn delegation on, then back into S-mode
   * ===================================================================== */
  .align 2
m_phase2:
  li      t0, 0xb000
  csrw    medeleg, t0
  li      t0, 0x880
  csrw    mstatus, t0
  la      t0, s_phase2
  csrw    mepc, t0
  mret

  /* =====================================================================
   * S-mode phase 2: medeleg = 12|13|15, so the S-mode handler takes them
   * ===================================================================== */
  .align 2
s_phase2:
  li      s7, 0x40000000
  /* 20: a delegated load page fault */
  PTE0    0xce                    /* V = 0 */
  SDARM   13, 0x40000000, ld_a, 1, after_a
ld_a:
  ld      t0, 0(s7)
after_a:
  /* 21: a delegated store page fault */
  SDARM   15, 0x40000008, sd_a, 1, after_b
sd_a:
  sd      t0, 8(s7)
after_b:
  /* 22: a delegated instruction page fault (sepc/stval are the fetch VA) */
  PTE0    0xc7                    /* V|R|W|A|D */
  li      s0, 12
  li      s2, 0x40000000
  li      s3, 0x40000000
  li      s4, 1                   /* SPP = S */
  la      s5, after_ic
  jr      s7                      /* fetch VA 0x4000_0000: not executable */
after_ic:
  ARMM    9, 0, 23, m_phase3
  ecall

  /* =====================================================================
   * M-mode: a trap in M-mode is never delegated, then the U-mode one
   * ===================================================================== */
  .align 2
m_phase3:
  /* 24: medeleg is still 0xb000, but this trap is raised in M-mode, where
     translation is off: the physical 0x4000_0000 no device claims, so the
     M-mode handler takes the access fault (the S handler must not run) */
  ARM     5, 0x40000000, 24
  li      t1, 0x40000000
  ld      t0, 0(t1)
  /* 25: the same kind of fault raised in U-mode IS delegated to S-mode
     (SPP = U) and the U code continues after the sret. The sepc/stval the S
     handler checks are the stub's own VAs, computed from the blob offset
     because the blob is copied to page B. */
  PTE0    0xcf                    /* page A: V|R|W|X|A|D, still not a U page */
  li      s0, 13
  li      s2, 0x40000000
  li      s4, 0                   /* SPP = U */
  la      t0, u_ld
  la      t1, u_blob
  sub     t0, t0, t1
  li      t1, 0x40001000
  add     t0, t0, t1
  mv      s3, t0                  /* sepc = the faulting U-mode load */
  la      t0, u_after
  la      t1, u_blob
  sub     t0, t0, t1
  li      t1, 0x40001000
  add     t0, t0, t1
  mv      s5, t0                  /* the S handler resumes there, still in U */
  li      t1, 0x40000000          /* the address the U-mode load uses */
  la      t4, m_fin               /* where the U-mode ecall resumes (M-mode) */
  li      t0, 0x80                /* MPP = U, MPIE = 1 */
  csrw    mstatus, t0
  li      t0, 0x40001000
  csrw    mepc, t0
  mret

  .align 2
m_fin:
  li      t0, 11
  beq     s11, t0, exit_ok
  li      a0, 30
  j       fail

exit_ok:
  li      a0, 0
  j       fail

fail:
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
9:
  j       9b

  /* ====================================================================
   * M-mode trap handler: s0/s2/s3 armed, s9 = resume in M-mode at s9,
   * s10 = resume at s10 in the trapping mode, else skip the instruction.
   * ==================================================================== */
  .align 2
m_handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  csrr    t1, mepc
  csrr    t5, mtval
  bne     t5, s2, .Lhbad
  bnez    s9, .Lhmode
  bnez    s10, .Lhres
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
.Lhres:
  csrw    mepc, s10
  li      s10, 0
  mret
.Lhmode:
  li      t0, 0x1880              /* MPP = M, MPIE = 1, MIE = 0 */
  csrw    mstatus, t0
  csrw    mepc, s9
  li      s9, 0
  mret
.Lhbad:
  li      a0, 90
  j       fail

  /* ====================================================================
   * S-mode trap handler (reached only with medeleg set): verify scause,
   * stval, sepc and sstatus.SPP against the armed expectations, then resume
   * at s5. Writes t0 only, so t1/t4 survive for the U-mode stub.
   * ==================================================================== */
  .align 2
s_handler:
  addi    s11, s11, 1             /* the same counter as the M handler's */
  csrr    t0, scause
  bne     t0, s0, .Lhsbad
  csrr    t0, stval
  bne     t0, s2, .Lhsbad
  csrr    t0, sepc
  bne     t0, s3, .Lhsbad
  csrr    t0, sstatus
  srli    t0, t0, 8
  andi    t0, t0, 1
  bne     t0, s4, .Lhsbad
  csrw    sepc, s5
  sret
.Lhsbad:
  li      a0, 91
  j       fail

  /* ====================================================================
   * U-mode stub, copied into page B (VA 0x4000_1000) before paging is on.
   * t1 = the address of the load under test, t4 = where the ecall resumes
   * in M-mode (armed here because the S handler's job is done by then).
   * ==================================================================== */
  .align 3
u_blob:
u_ld:
  ld      t0, 0(t1)               /* page A is not a U page: U-mode page fault */
u_after:
  li      s0, 8                   /* the ecall from U ... */
  li      s2, 0                   /* ... carries mtval = 0 ... */
  mv      s9, t4                  /* ... and resumes in M-mode at m_fin */
  ecall
  nop
  nop
  nop
  nop
u_blob_end:

  .section .bss
  .align 12
  .globl pt_root
pt_root:
  .space 4096
  .align 12
  .globl pt_l1id
pt_l1id:
  .space 4096
  .align 12
  .globl pt_l1t
pt_l1t:
  .space 4096
  .align 12
  .globl pt_l0t
pt_l0t:
  .space 4096
  .align 12
  .globl scratch
scratch:
  .space 4096
  .align 12
  .globl scratch2
scratch2:
  .space 4096
