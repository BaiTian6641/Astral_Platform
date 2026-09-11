/* SPDX-License-Identifier: MIT
 *
 * Bare-metal startup for the eth_rv DiffTest corpus (S15 §2.2).
 *
 * Contract every corpus program follows (documented in ../README.md):
 *   * `main` takes no arguments and returns an int in a0:  0 = self-check OK,
 *     anything else = which check failed.
 *   * crt0 sets up the stack, calls `main`, then performs the HTIF exit write
 *     `tohost = (code << 1) | 1` — the protocol Spike's `fesvr` uses to stop the
 *     simulation, and the store the Python model DUT halts on.
 *   * the program then spins in place (never executed: Spike and the model both
 *     stop at the store).
 *
 * Built with `-mcmodel=medany` (see build_corpus.py) so that `la` expands to a
 * PC-relative auipc/addi pair: absolute LUI addressing cannot materialize
 * 0x8000_xxxx on RV64, where LUI sign-extends from bit 31.
 */

  .section .text.init, "ax"
  .globl _start
  .align 2
_start:
  la      sp, _stack_top
  call    main
  slli    a0, a0, 1          /* HTIF: exit code lives in bits 63:1 */
  ori     a0, a0, 1          /* bit 0 set = "exit requested"         */
  la      t0, tohost
  sd      a0, 0(t0)
1:
  j       1b                 /* unreachable: both simulators stop above */

  .section .tohost, "aw", @progbits
  .align 3
  .globl tohost
tohost:
  .dword 0
  .align 3
  .globl fromhost
fromhost:
  .dword 0

  .section .note.GNU-stack, "", @progbits
