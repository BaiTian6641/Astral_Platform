/* SPDX-License-Identifier: MIT
 *
 * Corpus program — UNALIGNED DATA ACCESS (E2-RV2 increment 7, S4 gap closure).
 *
 * Five increments of DiffTest missed this: every corpus program up to `cor_plic`
 * touches data that is naturally aligned, so the core's load/store
 * *address-misaligned* path (mcause 4/6, mtval = the address) was never compared
 * against Spike. The S4 Linux boot found it instead — the kernel's
 * `check_unaligned_access_emulated` executes one deliberately unaligned `ld` and
 * died with `cause = 1`, `stval = epc` — which is why this program exists.
 *
 * WHAT THE CONTRACT IS (Spike, read off the golden model rather than guessed):
 *   * an access a single aligned beat cannot serve raises the *misaligned* trap:
 *     mcause 4 for a load, 6 for a store, mtval = the VIRTUAL address the
 *     instruction named (Spike: `trap_load_address_misaligned` /
 *     `trap_store_address_misaligned` with tval = the effective address);
 *   * the faulting instruction writes NOTHING to its destination register and
 *     the faulting store writes NO memory;
 *   * the trap is taken even when the misaligned access fits inside ONE page, and
 *     also when it crosses a page boundary (Spike only emulates misaligned
 *     accesses when `Zicclsm` is in the ISA, which this SoC's `riscv,isa` does not
 *     advertise on either side);
 *   * an ALIGNED access at the same addresses must NOT trap — the trap counter at
 *     the end pins the exact count, so a handler that fires on everything is
 *     caught as loudly as one that never fires.
 *
 * The last check is the S4 kernel's own scenario in miniature: the handler
 * EMULATES the unaligned load (byte-wise into an aligned scratch buffer) and
 * resumes at the next instruction, which is what OpenSBI's
 * `sbi_misaligned_load_handler` does for the firmware. If a trap cannot be
 * emulated and resumed, the kernel's probe cannot pass, no matter what cause it
 * reports.
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S);
 * the handler returns a0 = 99 for a wrong cause/mtval, and the DiffTest compares
 * every commit against Spike on top of that.
 */

  /* CK reg, want, index — compare; on mismatch return a0 = index. */
  .macro CK reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  /* NEXT cause, mtval, index — arm the trap the next instruction must raise. */
  .macro NEXT cause, mtval, index
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  li      s9, 0                   /* no emulation: the trap just steps over */
  .endm

  /* NEXTEMU cause, mtval, index — same, and the handler emulates the load into
     s7 before resuming (the OpenSBI route). */
  .macro NEXTEMU cause, mtval, index
  li      s0, \cause
  li      s2, \mtval
  li      s3, \index
  li      s9, 1
  .endm

  .section .text
  .globl main
  .align 2
main:
  la      t0, handler
  csrw    mtvec, t0
  li      s11, 0                  /* trap counter */

  /* the scratch buffer: 16 aligned bytes, and the misaligned views of it */
  la      s5, ubuf
  li      s7, 0x0102030405060708
  sd      s7, 0(s5)               /* aligned store: must NOT trap (checked below) */
  li      s4, 0x8877665544332211  /* sentinel for the faulting loads */
  li      s10, 0                  /* trap count taken by the aligned stores */

  /* ==== 1. an unaligned 64-bit load inside one page: cause 4, mtval = addr ==== */
  addi    s6, s5, 1
  mv      s7, s4
  NEXT    4, 0x0, 1
  mv      s2, s6                  /* mtval expectation needs the computed address */
  ld      s7, 0(s6)
  CK      s7, 0x8877665544332211, 2   /* a faulting load writes nothing */

  /* ==== 2. an unaligned 64-bit store inside one page: cause 6, mtval = addr ==== */
  addi    s6, s5, 3
  li      s8, 0xdeadbeefcafebabe
  NEXT    6, 0x0, 3
  mv      s2, s6
  sd      s8, 0(s6)
  ld      s8, 0(s5)               /* the store must not have landed anywhere */
  CK      s8, 0x0102030405060708, 4

  /* ==== 3. narrower misaligned accesses are the same trap ==== */
  addi    s6, s5, 1
  NEXT    4, 0x0, 5
  mv      s2, s6
  lh      s7, 0(s6)
  addi    s6, s5, 2
  NEXT    4, 0x0, 6
  mv      s2, s6
  lw      s7, 0(s6)
  addi    s6, s5, 5
  NEXT    6, 0x0, 7
  mv      s2, s6
  sh      s8, 0(s6)

  /* ==== 4. a misaligned access that CROSSES a page boundary: still cause 4 ==== */
  la      s6, ubuf
  li      t0, -4096               /* ~0xfff: the page base of the buffer */
  and     s6, s6, t0
  li      t0, 4093                /* last 3 bytes of that page: ld spans two pages */
  add     s6, s6, t0
  NEXT    4, 0x0, 8
  mv      s2, s6
  ld      s7, 0(s6)

  /* ==== 5. the S4 kernel's case: emulate the unaligned load and resume ==== */
  addi    s6, s5, 1
  NEXTEMU 4, 0x0, 9
  mv      s2, s6
  ld      s7, 0(s6)               /* the handler emulates this load into s7 */
  CK      s7, 0x0001020304050607, 10

  /* ==== 6. aligned accesses at the same addresses still work ==== */
  ld      s7, 0(s5)
  CK      s7, 0x0102030405060708, 11
  addi    s6, s5, 8
  li      s7, 0x1112131415161718
  sd      s7, 0(s6)
  ld      s8, 0(s6)
  CK      s8, 0x1112131415161718, 12

  /* NOTE ON S-MODE (kept out of this program on purpose): the S4 kernel's own
     failing case is an unaligned load in *S-mode* with OpenSBI's delegation mask
     (cause 4 not delegated). An earlier revision of this file ran exactly that
     sequence in-line — set `medeleg` to OpenSBI's mask, `mret` into S-mode, take
     the trap in M-mode, emulate, `mret` back — and the RTL behaved correctly
     (9 traps, the emulated value landed); but the *golden* side did not
     reproduce Spike's S-mode behaviour from a synthetic `mstatus`/`medeleg`
     setup, so the program does not hold on both sides and cannot be a corpus
     program. Reproducing it needs the firmware's real state (that is what the S4
     boot itself provides). The M-mode contract below is the part that is
     verified against Spike, and it is the part that was missing.

  /* ==== 7. exactly the armed traps happened ==== */
  li      t0, 7                   /* checks 1..7 above, one trap each */
  bne     s11, t0, .Lm13

  li      a0, 0
  ret

.Lm13:
  li      a0, 13
  ret

  /* ===================================================================
   * trap handler: verify the armed expectation, then either step over the
   * instruction or emulate the load (s9 = 1) the way OpenSBI does.
   * =================================================================== */
  .align 2
handler:
  addi    s11, s11, 1
  csrr    t0, mcause
  bne     t0, s0, .Lhbad
  csrr    t5, mtval               /* t5 = the address the instruction named */
  bne     t5, s2, .Lhbad
  beqz    s9, .Lhadv

  /* emulate an unaligned 8-byte load at t5 into s7: byte-wise into an aligned
     scratch buffer, then one aligned load (this is the OpenSBI route; the
     handler must not simply step over the instruction or the value is lost). */
  la      t1, ebuf
  li      t2, 0
.Lhemu:
  add     t3, t5, t2
  lbu     t4, 0(t3)
  add     t3, t1, t2
  sb      t4, 0(t3)
  addi    t2, t2, 1
  li      t4, 8
  blt     t2, t4, .Lhemu
  ld      s7, 0(t1)

.Lhadv:
  csrr    t1, mepc                /* advance past the trapping instruction */
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

  .section .bss
  .align 3
ubuf:
  .space 16
ebuf:
  .space 8
