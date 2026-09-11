/* SPDX-License-Identifier: MIT
 *
 * Corpus program 7/7 — the C14 §8 checkpoint 5 bring-up vehicle: a bare-metal
 * `hello` over the SoC console UART (MMIO, ns16550 subset; `eth_rv_uart` behind
 * `eth_rv_mmio_mux` at 0x1000_0000, the same page Spike's own ns16550 answers on).
 *
 * `main` returns 0 on success or the index of the first failed check (crt0.S),
 * and crt0 then performs the HTIF exit write, so this program is both the
 * bring-up vehicle and an ordinary DiffTest corpus program:
 *
 *   * the RTL testbench decodes the serial line at the UART's divisor and the
 *     runner asserts the exact byte string `hello_msg` (see
 *     verif/eth_rv_core/run_difftest.py), and
 *   * because every UART access is an ordinary D-port access, it also has to
 *     MATCH Spike's commit/memory trace — the poll below is written so that it
 *     can: `LSR` reads TEMT|THRE (0x60) on BOTH sides at all times (Spike's
 *     ns16550 transmitter is never busy, and the SoC's UART mirrors that
 *     register-visible model — see the header of rtl/eth_rv/eth_rv_uart.sv), so
 *     the loop below retires exactly one poll iteration per byte under Spike and
 *     under the RTL. A poll that waited on real divider-paced timing would take
 *     a different number of iterations on each side and the streams could not
 *     match.
 *
 * The program does NOT wait for the line to drain: the string is short enough to
 * sit in the UART's transmit queue (FIFO_DEPTH = 64), and the testbench keeps
 * the simulation running after the HTIF store until the UART goes idle — by then
 * the commit trace is already closed, so the extra cycles cannot affect the
 * DiffTest.
 *
 * The message lives in `.rodata` and its length is an assembler expression, so
 * the byte-count check below cannot drift from the data.
 */

  .equ UART_BASE,     0x10000000        /* console page (ns16550 subset)      */
  .equ UART_LSR_OFF,  5                 /* line status register (byte offset) */
  .equ LSR_THRE,      0x20              /* transmitter holding register empty */
  .equ LSR_TEMT_THRE, 0x60              /* ... and transmitter empty          */

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
  la      s0, hello_msg                 /* x8:  message cursor              */
  la      s1, hello_msg_end             /* x9:  message end                 */
  la      s5, hello_msg                 /* x21: message start (length check) */
  li      s2, UART_BASE                 /* x18: console base                */
  li      s3, LSR_THRE                  /* x19: readiness mask              */
  li      s4, UART_BASE + UART_LSR_OFF  /* x20: line status register        */

.Lsend:
  lbu     t0, 0(s4)                     /* poll LSR.THRE ...                */
  and     t0, t0, s3
  beqz    t0, .Lsend                    /* ... until the transmitter is ready */
  lbu     t0, 0(s0)                     /* next message byte                */
  sb      t0, 0(s2)                     /* THR: transmit it                 */
  addi    s0, s0, 1
  bltu    s0, s1, .Lsend

  /* ---- self-checks ---- */
  lbu     t0, 0(s4)                     /* 1: LSR is exactly TEMT|THRE once idle
                                           (the value Spike's ns16550 reads, so
                                           the trace comparison sees 0x60 too) */
  CK      t0, LSR_TEMT_THRE, 1

  sub     t0, s0, s5                    /* 2: every message byte was polled and
                                           handed to the transmitter          */
  la      t1, hello_msg_end             /*    the cursor reached the end of the
                                           message (a label difference, so the
                                           check cannot drift from the data)  */
  sub     t1, t1, s5
  beq     t0, t1, .Llen_ok
  li      a0, 2
  c.jr    ra
.Llen_ok:

  li      a0, 0
  ret

  .section .rodata
  .align 2
  .globl hello_msg
hello_msg:
  .ascii "hello, eth_rv!\n"
  .globl hello_msg_end
hello_msg_end:
  .byte 0                               /* not transmitted: the loop stops at
                                           hello_msg_end, not at a NUL        */

  .section .note.GNU-stack, "", @progbits
