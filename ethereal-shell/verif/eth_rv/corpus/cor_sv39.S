/* SPDX-License-Identifier: MIT
 *
 * Corpus program — Sv39 address translation (E2-RV2 increment 1, C14 §3).
 *
 * The reference for every expected value below is Spike (`--isa=rv64imc`,
 * whose device tree advertises `riscv,sv57`), probed before this program was
 * written: the probe table is in local://rv7-notes.md, and every number here is
 * a probed observation, not a guess.
 *
 * Coverage:
 *   * `satp` WARL: a value whose mode field names a mode this hart does not have
 *     (Sv39 = 8 and Off = 0 are the ones it has) leaves the whole register
 *     unchanged — Spike's CSR_SATP is the virtualized wrapper, whose
 *     unlogged_write() keeps `read()` unless satp_valid(), so the mode, ASID and
 *     PPN are all preserved; a legal mode stores the value verbatim
 *   * the three-level walk: a 3-level leaf mapping, the 2 MiB superpage the
 *     program itself runs on (every fetch below is translated), the page offset
 *     preserved, a store landing at the translated physical address (checked
 *     from M-mode afterwards), and a fetch through a 3-level walk
 *   * the permission matrix: V, R/W/X, the reserved PTE[63:54] bits (N / PBMT /
 *     Svrsw60t59b / reserved), the R=0,W=1 reserved encoding, A and D (Spike has
 *     hardware A/D update off, so a missing A, or a missing D on a store, is a
 *     page fault), the superpage alignment rule and the non-canonical-VA rule
 *   * SUM and MXR in S-mode; a U page is never executable from S-mode
 *   * U-mode: a U page is loadable and storable from U, a non-U page is not, and
 *     `satp` (read and write) and `sfence.vma` are illegal instructions
 *   * `sfence.vma` in both operand forms is legal from S-mode
 *   * M-mode is never translated: the same load that succeeds in S-mode is a
 *     load access fault in M-mode
 *   * `mstatus.TVM`: `satp` and `sfence.vma` become M-only
 *   * the error paths around translation: a PTE read outside the memory window
 *     is an *access* fault (1/5/7, not a page fault) with `mtval` = the virtual
 *     address, and so is a translated access whose physical address no device
 *     claims
 *
 * Registers: the handler owns t0..t5, s0, s2, s3, s4 and s11 (the trap count);
 * the phase code therefore keeps every value that must survive a trap — the test
 * address, the baseline leaf PTE, the armed expectations — in s0/s2/s3/s4/s7/s8/
 * s9/s10/s11. `fail` writes the HTIF exit word directly, so a failure is
 * terminal even though the handler has clobbered `ra`.
 *
 * Every PTE the program writes is followed by `sfence.vma` before the access it
 * is meant to affect: Spike caches PTEs (mmu.cc `pte_cache`) and would otherwise
 * legitimately reuse the stale one.
 */

  /* CK reg, want, index — compare; on mismatch fail with a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  j       fail
.Lck\@:
  .endm

  /* ARM cause, mtval, index — the next trap must have exactly these; the handler
     skips the trapping instruction (by its own length, read at mepc). */
  .macro ARM cause, tval, index
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  li      s9, 0
  li      s10, 0
  .endm

  /* ARMS cause, mtval, index, addr — ARM, and the handler resumes at `addr` in
     the trapping mode (used for fetches, whose mepc is the unfetchable target). */
  .macro ARMS cause, tval, index, addr
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  li      s9, 0
  la      s10, \addr
  .endm

  /* ARMM cause, mtval, index, addr — ARM, and the handler resumes in M-mode at
     `addr` (the U-mode and TVM one-shots). */
  .macro ARMM cause, tval, index, addr
  li      s0, \cause
  li      s2, \tval
  li      s3, \index
  la      s9, \addr
  li      s10, 0
  .endm

  /* ARMU index, addr — the next trap must be the ecall (cause 8) that ends a
     U-mode check, and the handler resumes in M-mode at `addr`. */
  .macro ARMU index, addr
  li      s0, 8
  li      s2, 0
  li      s3, \index
  la      s9, \addr
  li      s10, 0
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

  /* PTEO orv — pt_l0t[0] = the baseline leaf with `orv` set on top. */
  .macro PTEO orv
  la      t0, pt_l0t
  mv      t2, s8
  li      t3, \orv
  or      t2, t2, t3
  sd      t2, 0(t0)
  sfence.vma
  .endm

  /* PTEV val — pt_l0t[0] = an arbitrary PTE value. */
  .macro PTEV val
  la      t0, pt_l0t
  li      t2, \val
  sd      t2, 0(t0)
  sfence.vma
  .endm

  /* ENTERU sel, operand — enter U-mode at the stub with t1 = the action. */
  .macro ENTERU sel, operand
  li      t1, \sel
  li      t2, \operand
  li      t0, 0x80                /* MPP = U, MPIE = 1 */
  csrw    mstatus, t0
  li      t0, 0x40001000          /* the U stub (page B) */
  csrw    mepc, t0
  mret
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      s5, m_handler
  csrw    mtvec, s5
  la      s6, s_handler
  csrw    stvec, s6
  csrw    medeleg, zero
  csrw    mideleg, zero
  li      s11, 0                  /* trap counter */

  /* ---- zero the page tables (pt_root + pt_l1id + pt_l1t + pt_l0t + pt_l1s) */
  la      t0, pt_root
  li      t1, 0
  li      t2, (5 * 4096) / 8
1:
  sd      t1, 0(t0)
  addi    t0, t0, 8
  addi    t2, t2, -1
  bnez    t2, 1b

  /* s8 = the baseline leaf PTE: R|W|X|A|D|V, U = 0, -> the scratch page */
  la      s8, scratch
  srli    s8, s8, 12
  slli    s8, s8, 10
  ori     s8, s8, 0xcf

  /* ---- 1. satp WARL ---------------------------------------------------- */
  csrr    t0, satp                /* reset value: translation off */
  beqz    t0, 1f
  li      a0, 1
  j       fail
1:
  li      t1, 8                   /* a legal Sv39 value: mode|ASID|PPN stored */
  slli    t1, t1, 60
  li      t2, 0x7ff
  slli    t2, t2, 44
  or      t1, t1, t2
  li      t2, 0xabcde
  or      t1, t1, t2              /* a bogus root, never used: replaced below */
  csrw    satp, t1
  csrr    t0, satp
  bne     t0, t1, .Lf2
  li      t0, 4                   /* mode 4: not a mode -> satp is UNCHANGED */
  slli    t0, t0, 60
  li      t2, 0x5
  slli    t2, t2, 44
  or      t0, t0, t2
  li      t2, 0x123456789
  or      t0, t0, t2
  csrw    satp, t0
  csrr    t0, satp
  bne     t0, t1, .Lf3
  li      t0, -1                  /* mode 15: same */
  csrw    satp, t0
  csrr    t0, satp
  bne     t0, t1, .Lf4
  li      t0, 11                  /* Sv64 is not a mode either */
  slli    t0, t0, 60
  csrw    satp, t0
  csrr    t0, satp
  bne     t0, t1, .Lf5
  csrw    satp, zero              /* Off is a mode: it stores, and clears */
  csrr    t0, satp
  CK      t0, 0, 6

  /* ---- 2. build the page tables --------------------------------------- */
  /* root[2] -> pt_l1id; pt_l1id[0] = the 2 MiB identity superpage the whole
     program (code, data, page tables and stack) runs on */
  la      t0, pt_root
  la      t1, pt_l1id
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 16(t0)
  la      t0, pt_l1id
  li      t1, (0x80000 << 10) | 0xcf
  sd      t1, 0(t0)
  /* root[1] -> pt_l1t[0] -> pt_l0t (page A = VA 0x4000_0000, page B = +0x1000) */
  la      t0, pt_root
  la      t1, pt_l1t
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 8(t0)
  la      t0, pt_l1t
  la      t1, pt_l0t
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 0(t0)
  /* pt_l0t[1]: page B (the U-mode code page) -> scratch2, V|R|W|X|U|A|D */
  la      t0, pt_l0t
  la      t1, scratch2
  srli    t1, t1, 12
  slli    t1, t1, 10
  li      t2, 0xdf
  or      t1, t1, t2
  sd      t1, 8(t0)
  /* page A's initial leaf */
  la      t0, pt_l0t
  sd      s8, 0(t0)
  /* root[3] = a level-1 table pointer at PA 0x1_0000_0000 (no device claims it) */
  la      t0, pt_root
  li      t1, (0x100000 << 10) | 0x1
  sd      t1, 24(t0)
  /* root[4] -> pt_l1s[0] = a misaligned 2 MiB superpage (ppn[8:0] != 0) */
  la      t0, pt_root
  la      t1, pt_l1s
  srli    t1, t1, 12
  slli    t1, t1, 10
  ori     t1, t1, 1
  sd      t1, 32(t0)
  la      t0, pt_l1s
  li      t1, (0x80001 << 10) | 0xcf
  sd      t1, 0(t0)

  /* ---- 3. scratch contents and the stubs ------------------------------ */
  la      t2, scratch
  li      t0, 0xfeedfacecafebeef
  sd      t0, 0(t2)
  li      t0, 0x123456789abcdef0
  sd      t0, 8(t2)
  li      t0, 0x00008067          /* jr ra: the fetch-through-a-walk stub */
  sd      t0, 0x100(t2)
  li      t0, 0x00000013
  sd      t0, 0x108(t2)
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

  /* ---- 4. into S-mode with Sv39 on ------------------------------------ */
  la      t0, pt_root
  srli    t0, t0, 12
  li      t1, 8
  slli    t1, t1, 60
  or      t0, t0, t1
  csrw    satp, t0
  li      t0, 0x880               /* MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, s_entry
  csrw    mepc, t0
  mret

  /* =====================================================================
   * S-mode: the walk, the permission matrix, SUM/MXR, sfence.vma
   * ===================================================================== */
  .align 2
s_entry:
  li      s7, 0x40000000          /* the test VA, live across every trap */
  /* the S-mode view of satp (TVM = 0) */
  csrr    t0, satp
  la      t1, pt_root
  srli    t1, t1, 12
  li      t2, 8
  slli    t2, t2, 60
  or      t1, t1, t2
  beq     t0, t1, 1f
  li      a0, 10
  j       fail
1:
  /* 11/12: a 3-level walk, both words of the page (page offset preserved) */
  ld      t0, 0(s7)
  CK      t0, 0xfeedfacecafebeef, 11
  ld      t0, 8(s7)
  CK      t0, 0x123456789abcdef0, 12
  /* 13: a store through the walk; 14: read it back through the same VA */
  li      t2, 0x5a5aa5a55a5aa5a5
  sd      t2, 16(s7)
  ld      t2, 16(s7)
  CK      t2, 0x5a5aa5a55a5aa5a5, 13
  /* 14: a fetch through the walk (VA 0x4000_0100 holds `jr ra`) */
  la      ra, 3f
  li      t1, 0x40000100
  jalr    ra, t1, 0
3:
  /* 15/16: A = 0 is a page fault for a load and for a store */
  PTE0    0x8f                    /* V|R|W|X|D */
  ARM     13, 0x40000000, 20
  ld      t0, 0(s7)
  ARM     15, 0x40000008, 21
  sd      t0, 8(s7)
  /* 17: D = 0 faults a store; 18: it still permits a load */
  PTE0    0x4f                    /* V|R|W|X|A */
  ARM     15, 0x40000008, 22
  sd      t0, 8(s7)
  ld      t2, 0(s7)
  CK      t2, 0xfeedfacecafebeef, 23
  /* 19: V = 0 */
  PTE0    0xce                    /* R|W|X|A|D */
  ARM     13, 0x40000000, 24
  ld      t0, 0(s7)
  /* 20: R = 0 with W = 1 is a reserved encoding */
  PTE0    0xc6                    /* V|W|A|D */
  ARM     13, 0x40000000, 25
  ld      t0, 0(s7)
  /* 21: W = 0 rejects a store; 22: ... and still allows the load */
  PTE0    0xc3                    /* V|R|A|D */
  ARM     15, 0x40000008, 26
  sd      t0, 8(s7)
  ld      t0, 0(s7)
  CK      t0, 0xfeedfacecafebeef, 27
  /* 23: R = 0 with X = 1 is not loadable while MXR = 0 */
  PTE0    0xc9                    /* V|X|A|D */
  ARM     13, 0x40000000, 28
  ld      t0, 0(s7)
  /* 24: MXR = 1 makes it loadable (and sstatus stores SUM/MXR) */
  li      t0, 0x80000
  csrs    sstatus, t0
  csrr    t0, sstatus
  srli    t0, t0, 19
  andi    t0, t0, 1
  CK      t0, 1, 29
  ld      t2, 0(s7)
  CK      t2, 0xfeedfacecafebeef, 30
  /* 25: X = 0 rejects a fetch (instruction page fault, tval = the target) */
  PTE0    0xc7                    /* V|R|W|A|D */
  la      ra, 4f
  li      t1, 0x40000100
  ARMS    12, 0x40000100, 31, 4f
  jalr    ra, t1, 0
4:
  /* 26/27: a U page needs SUM in S-mode */
  PTE0    0xd7                    /* V|R|W|A|D|U */
  ARM     13, 0x40000000, 32
  ld      t0, 0(s7)
  li      t0, 0x40000             /* SUM = 1 (MXR was set above) */
  csrs    sstatus, t0
  csrr    t0, sstatus
  srli    t0, t0, 18
  andi    t0, t0, 3
  CK      t0, 3, 14
  ld      t2, 0(s7)
  CK      t2, 0xfeedfacecafebeef, 33
  /* 28: a U page is never executable from S-mode, even with SUM */
  la      ra, 5f
  li      t1, 0x40000100
  ARMS    12, 0x40000100, 34, 5f
  jalr    ra, t1, 0
5:
  /* 29: SUM = 0 and MXR = 0 again */
  li      t0, 0x80000
  csrc    sstatus, t0
  li      t0, 0x40000
  csrc    sstatus, t0
  csrr    t0, sstatus
  srli    t0, t0, 18
  andi    t0, t0, 3
  CK      t0, 0, 35
  /* 30: reserved PTE bits 63:54 (N, bit 58, bit 54) */
  PTEO    (1 << 63)
  ARM     13, 0x40000000, 36
  ld      t0, 0(s7)
  PTEO    (1 << 58)
  ARM     13, 0x40000000, 37
  ld      t0, 0(s7)
  PTEO    (1 << 54)
  ARM     13, 0x40000000, 38
  ld      t0, 0(s7)
  /* 31: a table PTE at level 0 (plain, with A, and with U) */
  PTEV    ((0x80002 << 10) | 0x01)
  ARM     13, 0x40000000, 39
  ld      t0, 0(s7)
  PTEV    ((0x80002 << 10) | 0xc1)
  ARM     13, 0x40000000, 40
  ld      t0, 0(s7)
  PTEV    ((0x80002 << 10) | 0x11)
  ARM     13, 0x40000000, 41
  ld      t0, 0(s7)
  /* 32: a misaligned 2 MiB superpage (VA 0x1_0000_0000 -> root[4]) */
  ARM     13, 0x100000000, 42
  li      t1, 1
  slli    t1, t1, 32
  ld      t0, 0(t1)
  /* 33: a non-canonical VA (bit 38 set with bits 63:39 clear) */
  PTE0    0xcf
  ARM     13, 0x0000004000000000, 43
  li      t1, 1
  slli    t1, t1, 38
  ld      t0, 0(t1)
  /* 34: a PTE read outside the memory window is an ACCESS fault (5), tval = VA */
  ARM     5, 0xc0000000, 44
  li      t1, 0xc0000000
  ld      t0, 0(t1)
  /* 35: ... and for a fetch it is an instruction access fault (1) */
  la      ra, 6f
  li      t1, 0xc0000000          /* t1 is reset: the check above trapped */
  ARMS    1, 0xc0000000, 45, 6f
  jalr    ra, t1, 0
6:
  /* 36/37: a translated access to a physical address no device claims: 5 / 7 */
  PTEV    ((0x100000 << 10) | 0xc7)
  ARM     5, 0x40000000, 46
  ld      t0, 0(s7)
  ARM     7, 0x40000008, 47
  sd      t0, 8(s7)
  /* 38: sfence.vma in both operand forms is legal here */
  PTE0    0xcf
  sfence.vma
  sfence.vma zero, zero
  sfence.vma t0, t1
  /* back to M-mode for the M-mode and U-mode phases */
  ARMM    9, 0, 48, m_mid
  ecall

  /* =====================================================================
   * M-mode: no translation, then the U-mode one-shots and TVM
   * ===================================================================== */
  .align 2
m_mid:
  /* 39: M-mode ignores satp: this VA is the physical 0x4000_0000 here */
  ARM     5, 0x40000000, 49
  li      t1, 0x40000000
  ld      t0, 0(t1)
  /* 40: the S-mode store really landed at scratch + 16 */
  la      t2, scratch
  ld      t0, 16(t2)
  CK      t0, 0x5a5aa5a55a5aa5a5, 50

  /* ---- U-mode one-shots ------------------------------------------------ */
  /* 41: a U page is loadable from U (the stub records what it read) */
  PTE0    0xdf                    /* V|R|W|X|U|A|D */
  ARMU    51, u_c1
  ENTERU  0, 0x40000000
u_c1:
  la      t2, scratch2
  addi    t2, t2, 0x7f0
  ld      t0, 16(t2)
  CK      t0, 0xfeedfacecafebeef, 51
  /* 42: a U page is storable from U */
  ARMU    52, u_c2
  ENTERU  4, 0x40000008
u_c2:
  la      t2, scratch2
  addi    t2, t2, 0x7f0
  ld      t0, 16(t2)
  CK      t0, 0x5a5aa5a55a5aa5a5, 52
  /* 43: a non-U page is not accessible from U */
  PTE0    0xcf
  ARMM    13, 0x40000000, 53, u_c3
  ENTERU  0, 0x40000000
u_c3:
  /* 44: a U page with W = 0 rejects a U-mode store */
  PTE0    0xdb                    /* V|R|X|U|A|D */
  ARMM    15, 0x40000008, 54, u_c4
  ENTERU  4, 0x40000008
u_c4:
  /* 45/46/47: satp (read, write) and sfence.vma are illegal from U. mtval is
     the offending encoding — spelled out because the handler runs in M-mode,
     where reading the faulting (translated) instruction word is impossible. */
  PTE0    0xdf
  ARMM    2, 0x18002e73, 55, u_c5    /* csrr t3, satp */
  ENTERU  1, 0
u_c5:
  ARMM    2, 0x18039073, 56, u_c6    /* csrw satp, t2 */
  ENTERU  2, 0
u_c6:
  ARMM    2, 0x12000073, 57, u_c7    /* sfence.vma */
  ENTERU  3, 0
u_c7:

  /* ---- TVM: satp and sfence.vma become M-only for S-mode -------------- */
  li      t0, 0x108880            /* TVM (bit 20) = 1, MPP = S, MPIE = 1 */
  csrw    mstatus, t0
  la      t0, tvm_entry
  csrw    mepc, t0
  mret

  .align 2
tvm_entry:
  /* each of these traps in S-mode and resumes in S-mode, so the next one is
     also taken in S-mode — where TVM still applies */
  ARMS    2, 0x180022f3, 58, t_c1    /* csrr t0, satp */
  csrr    t0, satp
t_c1:
  ARMS    2, 0x18029073, 59, t_c2    /* csrw satp, t0 */
  csrw    satp, t0
t_c2:
  ARMS    2, 0x12000073, 60, t_c3    /* sfence.vma */
  sfence.vma
t_c3:
  ARMM    9, 0, 61, m_fin
  ecall

  .align 2
m_fin:
  li      t0, 0x100000
  csrc    mstatus, t0             /* TVM = 0 */
  li      t0, 35
  beq     s11, t0, exit_ok
  li      a0, 70
  j       fail

exit_ok:
  li      a0, 0
  j       fail

  /* a0 = the exit index: write the HTIF exit word and spin (the handler has
     clobbered `ra`, so `ret` is not a way out of a failure) */
fail:
  slli    a0, a0, 1
  ori     a0, a0, 1
  la      t0, tohost
  sd      a0, 0(t0)
9:
  j       9b

.Lf2:
  li      a0, 2
  j       fail
.Lf3:
  li      a0, 3
  j       fail
.Lf4:
  li      a0, 4
  j       fail
.Lf5:
  li      a0, 5
  j       fail

  /* ====================================================================
   * M-mode trap handler. s0/s2/s3 are armed by ARM/ARMS/ARMM/ARMU; s9 != 0
   * resumes in M-mode at s9, s10 != 0 resumes at s10 in the trapping mode,
   * otherwise the trapping instruction is skipped by its own length.
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

  /* The S-mode handler must never run: medeleg = 0 throughout. */
  .align 2
s_handler:
  li      a0, 91
  j       fail

  /* ====================================================================
   * U-mode stub, copied to page B (VA 0x4000_1000) before paging is on.
   * Position-independent: only PC-relative branches and immediate constants.
   * t1 = action, t2 = operand; it always ends in ecall (cause 8), and the
   * positive checks leave their verdict at 0x4000_1800 (scratch2 + 0x800).
   * ==================================================================== */
  .align 3
u_blob:
  li      t3, 0
  beq     t1, t3, 2f
  li      t3, 1
  beq     t1, t3, 3f
  li      t3, 2
  beq     t1, t3, 4f
  li      t3, 4
  beq     t1, t3, 5f
  j       6f
2:
  ld      t3, 0(t2)               /* load through the page under test */
  li      t4, 0x40001800
  sd      t3, 0(t4)
  j       7f
5:
  li      t3, 0x5a5aa5a55a5aa5a5
  sd      t3, 0(t2)               /* store through the page under test */
  li      t4, 0x40001800
  sd      t3, 0(t4)
  j       7f
3:
  csrr    t3, satp                /* illegal from U-mode */
  j       7f
4:
  csrw    satp, t2                /* illegal from U-mode */
  j       7f
6:
  sfence.vma                      /* illegal from U-mode */
7:
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
  .globl pt_l1s
pt_l1s:
  .space 4096
  .align 12
  .globl scratch
scratch:
  .space 4096
  .align 12
  .globl scratch2
scratch2:
  .space 4096
