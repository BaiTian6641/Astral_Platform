/* SPDX-License-Identifier: MIT
 *
 * Corpus program 12 — the CLINT's MTIME read path (E2-RV1 increment 6). Spike
 * ticks `mtime` from its own execution-step counter: `INSNS_PER_RTC_TICK` (100)
 * instructions per RTC tick, with the simulator's 5000-step interleave adding
 * `INTERLEAVE / INSNS_PER_RTC_TICK` (50) at a time. For a TRAP-FREE program that
 * is a staircase of the retired-instruction count,
 *
 *     mtime = 50 * floor((5 + k) / 5000)
 *
 * where k is the instruction's index and the 5 is the pinned Spike's boot ROM
 * (auipc / addi / csrr / ld / jr — five instructions before the ELF entry).
 * `eth_rv_clint` reproduces exactly that: it counts the hart's
 * executed-instruction strobe with the boot-ROM preload and presents the
 * register read with the "steps before this load" adjustment.
 *
 * This program therefore reads MTIME in a long trap-free loop and stores every
 * value; the DiffTest compares the whole staircase, so the read path is *proved*
 * against Spike's convention rather than asserted. The boundary that remains —
 * and is documented rather than compared — is a program that TRAPS: Spike ends
 * its step early on a trap (`n = instret`), which shifts the tick phase in a way
 * no hart-side counter can reproduce, so no corpus program reads MTIME after a
 * trap (the interrupt program uses only `mtimecmp = 0` / `= -1`, which are
 * phase-independent).
 *
 * `main` returns 0; the check is the stored staircase, compared by the harness.
 */

  .section .text
  .globl main
  .align 2
main:
  la      s7, buf
  li      s9, 0
  lui     t0, 0x200c              /* mtime @ 0x200bff8 */
  addi    t0, t0, -8
  li      s8, 1300                /* ~6500 instructions: crosses 5000 twice */
loop:
  ld      t1, 0(t0)               /* read mtime */
  sd      t1, 0(s7)
  addi    s7, s7, 8
  addi    s9, s9, 1
  bne     s9, s8, loop
  li      a0, 0
  ret

  .section .bss
  .align 3
buf: .space 11264

  .section .note.GNU-stack, "", @progbits
