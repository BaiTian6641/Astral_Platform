/* SPDX-License-Identifier: MIT
 *
 * Corpus program 17 — the A extension (E2-RV2 increment 3): lr/sc and the nine
 * amo.* read-modify-write forms in both widths, plus their misaligned traps.
 *
 * The whole A extension is deterministic on a single hart — the RMW is atomic by
 * construction and both simulators agree bit for bit on every result — with ONE
 * boundary the program is written around (documented in ../README.md "The A
 * extension"):
 *
 *   * SC's success/failure is what the RESERVATION state says, and the
 *     reservation's size/granularity is microarchitectural. Both simulators here
 *     implement the same simple rule — the reservation is one (valid, address)
 *     pair: `lr` arms it, `sc` compares the exact address and then consumes it,
 *     and NOTHING else (no store, no AMO, no trap) invalidates it — so the
 *     program arms a reservation immediately before each `sc` whose outcome it
 *     pins, and the two "cannot succeed" cases (no live reservation, and a
 *     mismatched address) are set up explicitly. The cases where the rule is
 *     *interesting* (a load, a store to another word, an AMO to the same word
 *     between the lr and the sc) are pinned as successful, because that is what
 *     the pinned Spike does and what eth_rv's reservation implements.
 *
 * Checks: rd (including the `.w` sign extension and the upper-half preserve),
 * the memory word the AMO stores, the store/no-store of a success/failure `sc`,
 * the aq/rl forms (accepted, no ordering effect on one hart), rd = x0, and the
 * six misaligned traps (cause 4 for lr, 6 for amo/sc, mtval = the address, no
 * memory change, no rd update).
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S).
 */

  /* register check: return `index` when `reg` != `want` */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  c.jr    ra
.Lck\@:
  .endm

  /* memory check: the doubleword at `off(s0)` must be `want` */
  .macro CKM off, want, index
  ld      t5, \off(s0)
  CK      t5, \want, \index
  .endm

  /* one AMO check: seed `init` (the upper half is garbage for the .w forms and
   * must survive them), run `insn rd, rs2, (addr)`, then compare rd with
   * `want_old` and the doubleword at the address with `want_new` */
  .macro AMO_CK insn, off, rs2, init, want_old, want_new, idx_rd, idx_mem
  li      t2, \init
  sd      t2, \off(s0)
  li      t3, \rs2
  addi    t0, s0, \off
  \insn   t1, t3, (t0)
  CK      t1, \want_old, \idx_rd
  CKM     \off, \want_new, \idx_mem
  .endm

  /* the same check with rd = x0: the register result is dropped, the memory
   * effect must still happen (and the commit must carry no register write) */
  .macro AMO_CK_X0 insn, off, rs2, init, want_new, idx_mem
  li      t2, \init
  sd      t2, \off(s0)
  li      t3, \rs2
  addi    t0, s0, \off
  \insn   x0, t3, (t0)
  CKM     \off, \want_new, \idx_mem
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      s0, abuf                /* 8-aligned scratch; the misaligned tests use s0+2 / s0+4 */

  /* ================================================================
   * 1. the nine amo.* forms, .w (32-bit) ---------------------------
   * The seed's upper word (0xdeadbeef) is NOT part of the access: a .w
   * AMO must leave it alone. rs2 also carries garbage above bit 31 in
   * the add form, which the 32-bit operation must ignore.
   * ================================================================ */
  AMO_CK  amoadd.w, 0, 0xdeadbeef55667788, 0xdeadbeef11223344,  0x11223344, 0xdeadbeef6688aacc, 1, 101
  AMO_CK  amoswap.w, 8, 0x0000000099aabbcc, 0xdeadbeef11223344, 0x11223344, 0xdeadbeef99aabbcc, 2, 102
  AMO_CK  amoxor.w, 16, 0x00000000ffffffff, 0xdeadbeef11223344, 0x11223344, 0xdeadbeefeeddccbb, 3, 103
  AMO_CK  amoand.w, 24, 0x00000000ff00ff00, 0xdeadbeef11223344, 0x11223344, 0xdeadbeef11003300, 4, 104
  AMO_CK  amoor.w,  32, 0x00000000ff00ff00, 0xdeadbeef11223344, 0x11223344, 0xdeadbeefff22ff44, 5, 105
  /* signed min/max on a NEGATIVE word: also pins the sext32 rd result */
  AMO_CK  amomin.w, 40, 0x0000000000000001, 0xdeadbeef80000000, 0xffffffff80000000, 0xdeadbeef80000000, 6, 106
  AMO_CK  amomax.w, 48, 0x0000000000000001, 0xdeadbeef80000000, 0xffffffff80000000, 0xdeadbeef00000001, 7, 107
  AMO_CK  amominu.w, 56, 0x0000000000000001, 0xdeadbeef80000000, 0xffffffff80000000, 0xdeadbeef00000001, 8, 108
  AMO_CK  amomaxu.w, 64, 0x0000000000000001, 0xdeadbeef80000000, 0xffffffff80000000, 0xdeadbeef80000000, 9, 109

  /* ================================================================
   * 2. the nine amo.* forms, .d (64-bit) ---------------------------
   * rd is the full old doubleword here — no sign extension.
   * ================================================================ */
  AMO_CK  amoadd.d, 72, 0x00000000deadbeef, 0x0000000000001234, 0x0000000000001234, 0x00000000deadd123, 10, 110
  AMO_CK  amoswap.d, 80, 0x0123456789abcdef, 0x0000000000001234, 0x0000000000001234, 0x0123456789abcdef, 11, 111
  AMO_CK  amoxor.d, 88, 0xffffffffffffffff, 0x0f0f0f0f0f0f0f0f, 0x0f0f0f0f0f0f0f0f, 0xf0f0f0f0f0f0f0f0, 12, 112
  AMO_CK  amoand.d, 96, 0x00000000ffff0000, 0x0123456789abcdef, 0x0123456789abcdef, 0x0000000089ab0000, 13, 113
  AMO_CK  amoor.d, 104, 0x00000000ffff0000, 0x0123456789abcdef, 0x0123456789abcdef, 0x01234567ffffcdef, 14, 114
  /* signed forms on the most-negative doubleword, unsigned forms on the same seed:
   * min/max differ between the two precisely because the sign bit is set */
  AMO_CK  amomin.d, 112, 0x0000000000000001, 0x8000000000000000, 0x8000000000000000, 0x8000000000000000, 15, 115
  AMO_CK  amomax.d, 120, 0x0000000000000001, 0x8000000000000000, 0x8000000000000000, 0x0000000000000001, 16, 116
  AMO_CK  amominu.d, 128, 0x0000000000000001, 0x8000000000000000, 0x8000000000000000, 0x0000000000000001, 17, 117
  AMO_CK  amomaxu.d, 136, 0x0000000000000001, 0x8000000000000000, 0x8000000000000000, 0x8000000000000000, 18, 118

  /* ================================================================
   * 3. rd = x0: the memory effect happens, no architectural write -----
   * ================================================================ */
  AMO_CK_X0 amoadd.w, 144, 0x0000000000000001, 0xdeadbeef00000041, 0xdeadbeef00000042, 19
  AMO_CK_X0 amoswap.d, 152, 0x5555555555555555, 0x0000000000000000, 0x5555555555555555, 20

  /* ================================================================
   * 4. lr.w / sc.w: the success path and the memory it writes --------
   * ================================================================ */
  li      t2, 0x0000000011223344
  sd      t2, 160(s0)
  addi    t0, s0, 160
  lr.w    t1, (t0)                /* rd = sext32(0x11223344) */
  CK      t1, 0x0000000011223344, 21
  li      t2, 0x0000000055667788
  sc.w    t3, t2, (t0)            /* success: rd = 0 */
  CK      t3, 0, 22
  CKM     160, 0x0000000055667788, 23

  /* 4b. lr.d / sc.d round trip */
  li      t2, 0x0123456789abcdef
  sd      t2, 168(s0)
  addi    t0, s0, 168
  lr.d    t1, (t0)
  CK      t1, 0x0123456789abcdef, 24
  li      t2, 0xfedcba9876543210
  sc.d    t3, t2, (t0)
  CK      t3, 0, 25
  CKM     168, 0xfedcba9876543210, 26

  /* 4c. an lr whose value is discarded (rd = x0) still arms, and an sc whose
   * failure flag is discarded (rd = x0) still stores */
  li      t2, 0x00000000cafebabe
  sd      t2, 176(s0)
  addi    t0, s0, 176
  lr.w    x0, (t0)
  li      t2, 0x00000000deadbabe
  sc.w    x0, t2, (t0)
  CKM     176, 0x00000000deadbabe, 27

  /* ================================================================
   * 5. what does and does not break a reservation --------------------
   * Each case arms its own reservation right before the sc.
   * ================================================================ */

  /* 5a. a LOAD between the lr and the sc: the sc still succeeds */
  li      t2, 0x00000000000000aa
  sd      t2, 184(s0)
  addi    t0, s0, 184
  lr.w    t1, (t0)
  lw      t4, 184(s0)             /* the load must not consume the reservation */
  li      t2, 0x00000000000000bb
  sc.w    t3, t2, (t0)
  CK      t3, 0, 28
  CKM     184, 0x00000000000000bb, 29

  /* 5b. a STORE to a DIFFERENT word between the lr and the sc: still succeeds */
  li      t2, 0x00000000000000cc
  sd      t2, 192(s0)
  addi    t0, s0, 192
  lr.w    t1, (t0)
  li      t4, 0x00000000000000dd
  sd      t4, 200(s0)             /* another address entirely */
  li      t2, 0x00000000000000ee
  sc.w    t3, t2, (t0)
  CK      t3, 0, 30
  CKM     192, 0x00000000000000ee, 31
  CKM     200, 0x00000000000000dd, 32

  /* 5c. an AMO to the SAME word between the lr and the sc: still succeeds —
   * this is the pinned Spike's rule (an ordinary store or an AMO does not
   * invalidate the reservation; only an sc consumes it) */
  li      t2, 0x0000000000000f0f
  sd      t2, 208(s0)
  addi    t0, s0, 208
  lr.w    t1, (t0)
  li      t3, 0x00000000000000f0
  amoadd.w t4, t3, (t0)           /* memory becomes 0x0fff */
  CK      t4, 0x0000000000000f0f, 33
  li      t2, 0x0000000000000fff
  sc.w    t5, t2, (t0)
  CK      t5, 0, 34
  CKM     208, 0x0000000000000fff, 35

  /* ================================================================
   * 6. the sc failure modes ------------------------------------------
   * ================================================================ */

  /* 6a. lr at A, sc at B (A + 8): the reservation is for a different address,
   * so the sc fails (rd = 1) and B is untouched. The sc CONSUMES the
   * reservation even when it fails, which 6b then relies on. */
  li      t2, 0x0000000000000011
  sd      t2, 216(s0)
  li      t2, 0x0000000000000022
  sd      t2, 224(s0)
  addi    t0, s0, 216
  addi    t1, s0, 224
  lr.w    t3, (t0)
  li      t4, 0x0000000000000033
  sc.w    t5, t4, (t1)            /* mismatched address: fail */
  CK      t5, 1, 36
  CKM     224, 0x0000000000000022, 37

  /* 6b. sc with no live reservation at all (6a consumed the last one): fail,
   * and the word keeps its value */
  addi    t0, s0, 232
  li      t2, 0x0000000000000044
  sd      t2, 232(s0)
  li      t4, 0x0000000000000055
  sc.w    t5, t4, (t0)            /* no lr: fail */
  CK      t5, 1, 38
  CKM     232, 0x0000000000000044, 39

  /* 6c. two sc for one lr: the first succeeds and consumes the reservation,
   * the second fails and stores nothing */
  li      t2, 0x0000000000000066
  sd      t2, 240(s0)
  addi    t0, s0, 240
  lr.w    t1, (t0)
  li      t4, 0x0000000000000077
  sc.w    t5, t4, (t0)
  CK      t5, 0, 40
  li      t4, 0x0000000000000088
  sc.w    t5, t4, (t0)            /* no reservation left */
  CK      t5, 1, 41
  CKM     240, 0x0000000000000077, 42

  /* 6d. lr.d followed by an sc.w: the width does not matter for the reservation,
   * but the address does — the whole doubleword is one reservation */
  li      t2, 0x0000000000000099
  sd      t2, 248(s0)
  addi    t0, s0, 248
  lr.d    t1, (t0)
  li      t4, 0x00000000000000aa
  sc.w    t5, t4, (t0)            /* same address: succeeds */
  CK      t5, 0, 43
  CKM     248, 0x00000000000000aa, 44

  /* ================================================================
   * 7. the aq/rl forms: accepted, and identical on one hart ------------
   * ================================================================ */
  AMO_CK  amoadd.w.aq, 256, 0x0000000000000001, 0x0000000000000010, 0x0000000000000010, 0x0000000000000011, 45, 145
  AMO_CK  amoadd.w.rl, 264, 0x0000000000000001, 0x0000000000000010, 0x0000000000000010, 0x0000000000000011, 46, 146
  AMO_CK  amoadd.w.aqrl, 272, 0x0000000000000001, 0x0000000000000010, 0x0000000000000010, 0x0000000000000011, 47, 147
  AMO_CK  amomaxu.d.aqrl, 280, 0x0000000000000002, 0x0000000000000001, 0x0000000000000001, 0x0000000000000002, 48, 148
  li      t2, 0x0000000000000012
  sd      t2, 288(s0)
  addi    t0, s0, 288
  lr.w.aq t1, (t0)
  li      t4, 0x0000000000000013
  sc.w.rl t5, t4, (t0)
  CK      t5, 0, 49
  CKM     288, 0x0000000000000013, 50

  /* ================================================================
   * 8. misaligned accesses: cause 4 for lr, cause 6 for amo/sc ---------
   * The handler records (mcause, mtval) and skips the instruction; main
   * compares the six records at the end. None of them may touch memory.
   * ================================================================ */
  li      t2, 0x00000000deadc0de
  sd      t2, 296(s0)             /* the aligned word the +2 accesses would hit */
  li      t2, 0x00000000cafebabe
  sd      t2, 304(s0)             /* ... and the aligned word for the +4 accesses */

  la      t0, atrap
  csrw    mtvec, t0

  addi    t0, s0, 298             /* word-misaligned (s0 + 296 + 2) */
  li      t3, 0x0000000000000001
  lr.w    t1, (t0)                /* cause 4 */
  sc.w    t1, t3, (t0)            /* cause 6 */
  amoadd.w t1, t3, (t0)           /* cause 6 */

  addi    t0, s0, 308             /* doubleword-misaligned (s0 + 304 + 4) */
  lr.d    t1, (t0)                /* cause 4 */
  sc.d    t1, t3, (t0)            /* cause 6 */
  amoadd.d t1, t3, (t0)           /* cause 6 */

  /* the six records, in trap order */
  la      t0, atrap_log
  ld      t2, 0(t0)
  CK      t2, 4, 52
  addi    t3, s0, 298
  ld      t2, 8(t0)
  beq     t2, t3, .Ltrap1
  li      a0, 53
  c.jr    ra
.Ltrap1:
  ld      t2, 16(t0)
  CK      t2, 6, 54
  ld      t2, 24(t0)
  beq     t2, t3, .Ltrap2
  li      a0, 55
  c.jr    ra
.Ltrap2:
  ld      t2, 32(t0)
  CK      t2, 6, 56
  ld      t2, 40(t0)
  beq     t2, t3, .Ltrap3
  li      a0, 57
  c.jr    ra
.Ltrap3:
  addi    t3, s0, 308
  ld      t2, 48(t0)
  CK      t2, 4, 58
  ld      t2, 56(t0)
  beq     t2, t3, .Ltrap4
  li      a0, 59
  c.jr    ra
.Ltrap4:
  ld      t2, 64(t0)
  CK      t2, 6, 60
  ld      t2, 72(t0)
  beq     t2, t3, .Ltrap5
  li      a0, 61
  c.jr    ra
.Ltrap5:
  ld      t2, 80(t0)
  CK      t2, 6, 62
  ld      t2, 88(t0)
  beq     t2, t3, .Ltrap6
  li      a0, 63
  c.jr    ra
.Ltrap6:
  /* ... and neither word was modified by any of the six faulting accesses */
  CKM     296, 0x00000000deadc0de, 64
  CKM     304, 0x00000000cafebabe, 65

  li      a0, 0
  ret

  /* ---- trap handler: record (mcause, mtval), skip the instruction ---- */
  /* The faulting sequences below keep their address in t0 and their store data
   * in t3 across the trap, so the handler saves and restores every temporary it
   * touches — a clobbered t0 would send the *next* misaligned access to the
   * handler's own scratch area and turn the trap under test into a different
   * one (found the hard way). */
  .align 2
atrap:
  addi    sp, sp, -64
  sd      t0, 0(sp)
  sd      t1, 8(sp)
  sd      t2, 16(sp)
  sd      t3, 24(sp)
  sd      t4, 32(sp)
  sd      t5, 40(sp)
  sd      t6, 48(sp)
  csrr    t4, mcause
  csrr    t5, mtval
  la      t6, atrap_log
  la      t2, atrap_idx
  ld      t3, 0(t2)
  slli    t0, t3, 4               /* 16 bytes per record */
  add     t6, t6, t0
  sd      t4, 0(t6)
  sd      t5, 8(t6)
  addi    t3, t3, 1
  sd      t3, 0(t2)
  csrr    t4, mepc
  addi    t4, t4, 4               /* every faulting instruction here is 4 bytes */
  csrw    mepc, t4
  ld      t0, 0(sp)
  ld      t1, 8(sp)
  ld      t2, 16(sp)
  ld      t3, 24(sp)
  ld      t4, 32(sp)
  ld      t5, 40(sp)
  ld      t6, 48(sp)
  addi    sp, sp, 64
  mret

  .section .data
  .align 3
atrap_idx:
  .dword 0
atrap_log:
  .space 96

  .section .bss
  .align 6
abuf:
  .space 384

  .section .note.GNU-stack, "", @progbits
