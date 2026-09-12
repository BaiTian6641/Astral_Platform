/* SPDX-License-Identifier: MIT
 *
 * Corpus program 23 — the console UART's RECEIVE path (E2-RV2 increment 6 / S5,
 * E2-RV2 G8). The register semantics are the pinned Spike's `riscv/ns16550.cc`,
 * probed before the RTL was written (local://rv11-plic-notes.md §1.2):
 *
 *   * LSR is `TEMT|THRE` (the transmitter is never busy) with `DR` set while the
 *     receive queue is not empty: 0x60 idle, 0x61 with a byte;
 *   * reading RBR pops the queue and clears DR when the last byte leaves it; an
 *     empty read returns 0;
 *   * IIR is `0xC0 | ((IER.RDI && DR) ? 4 : 0) | (IER.THRI ? 2 : 0)`, and 0xC1
 *     when neither holds — Spike ORs the two causes, so IER = 0b11 with data
 *     pending reads 0xC6, which no real 16550 would;
 *   * `MCR.LOOP` routes a THR store into the receive queue instead of the line
 *     (Spike's `store`, the one injection route a DiffTest can drive) and does
 *     NOT require FCR's FIFO enable;
 *   * `FCR.CLEAR_RCVR` drops the queue and DR, and both FCR clear bits
 *     self-clear;
 *   * the receive queue is 64 deep and the 65th byte is dropped silently;
 *   * MSR reads 0xB0 (DCD|DSR|CTS — the constant this slice corrected from the
 *     old 0xD0, which no program had read);
 *   * DLAB routes the data registers to DLL/DLM (DLM has no reset value in
 *     Spike, so this program writes it before reading it);
 *   * the page is one-byte-register only: a wider access is an access fault.
 *
 * The serial *receiver* itself (`uart_rx_i`) has no golden model — Spike's
 * ns16550 is fed by a terminal a batch run cannot drive — so it is checked by
 * the testbench (`+uart_rx=`, tb_eth_rv_core.sv), not here.
 *
 * The last check turns loopback OFF and transmits one byte, so the console
 * carries exactly `'Z'`: that is this program's EXPECTED_UART payload in
 * verif/eth_rv_core/run_difftest.py (and the testbench's frame-timing assertion
 * then covers the transmit path this slice did not touch).
 *
 * Checks are numbered; `main` returns the number of the first failure.
 */

  .macro CKQ reg, want, index
  li      t6, \want
  beq     \reg, t6, .Lck\@
  li      a0, \index
  ret
.Lck\@:
  .endm

  .equ    UART,        0x10000000
  .equ    UART_TX_OFF, 0

  .section .text
  .globl main
  .align 2
main:
  la      t0, uart_trap
  csrw    mtvec, t0
  li      s0, UART
  /* ---- 1..10. reset values --------------------------------------------- */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 1             /* LSR = TEMT|THRE */
  lbu     t0, 6(s0)
  CKQ     t0, 0xb0, 2             /* MSR = DCD|DSR|CTS */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 3             /* IIR = 0xc0 | NO_INT */
  lbu     t0, 4(s0)
  CKQ     t0, 0x08, 4             /* MCR = OUT2 */
  lbu     t0, 1(s0)
  CKQ     t0, 0, 5                /* IER */
  lbu     t0, 3(s0)
  CKQ     t0, 0, 6                /* LCR */
  lbu     t0, 7(s0)
  CKQ     t0, 0, 7                /* SCR */
  lbu     t0, 0(s0)
  CKQ     t0, 0, 8                /* RBR with an empty queue */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 9             /* ... and DR stays clear */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 10

  /* ---- 11..19. loopback: one byte in, one byte out ---------------------- */
  li      t0, 0x18
  sb      t0, 4(s0)               /* MCR = LOOP | OUT2 */
  li      t0, 1
  sb      t0, 1(s0)               /* IER = RDI */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 11            /* no data yet: NO_INT */
  li      t0, 0x41
  sb      t0, 0(s0)               /* loopback push: 'A' */
  lbu     t0, 5(s0)
  CKQ     t0, 0x61, 12            /* DR set */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc4, 13            /* IIR = RDI */
  lbu     t0, 1(s0)
  CKQ     t0, 1, 14               /* IER read back */
  lbu     t0, 0(s0)
  CKQ     t0, 0x41, 15            /* RBR returns the byte ... */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 16            /* ... and the read drained the queue */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 17
  lbu     t0, 0(s0)
  CKQ     t0, 0, 18               /* an empty read is 0 */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 19

  /* ---- 20..25. FIFO order ---------------------------------------------- */
  li      t0, 0x31
  sb      t0, 0(s0)
  li      t0, 0x32
  sb      t0, 0(s0)
  li      t0, 0x33
  sb      t0, 0(s0)
  lbu     t0, 5(s0)
  CKQ     t0, 0x61, 20
  lbu     t0, 0(s0)
  CKQ     t0, 0x31, 21
  lbu     t0, 5(s0)
  CKQ     t0, 0x61, 22            /* still two bytes queued */
  lbu     t0, 0(s0)
  CKQ     t0, 0x32, 23
  lbu     t0, 0(s0)
  CKQ     t0, 0x33, 24
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 25

  /* ---- 26..30. the IIR is the OR of RDI and THRI ------------------------ */
  li      t0, 3
  sb      t0, 1(s0)               /* IER = RDI | THRI */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc2, 26            /* THRI: the transmitter is always ready */
  li      t0, 0x42
  sb      t0, 0(s0)               /* push */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc6, 27            /* Spike ORs the causes: 0xc4 | 0xc2 */
  li      t0, 2
  sb      t0, 1(s0)               /* IER = THRI only */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc2, 28            /* DR is set, but RDI is disabled */
  li      t0, 0
  sb      t0, 1(s0)               /* IER = 0 */
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 29
  lbu     t0, 5(s0)
  CKQ     t0, 0x61, 30            /* one byte is still queued */

  /* ---- 31..34. FCR clears the queue ------------------------------------ */
  li      t0, 0x02
  sb      t0, 2(s0)               /* FCR = CLEAR_RCVR */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 31
  lbu     t0, 0(s0)
  CKQ     t0, 0, 32
  li      t0, 0x04
  sb      t0, 2(s0)               /* FCR = CLEAR_XMIT (no state to clear) */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 33
  li      t0, 0x01
  sb      t0, 2(s0)               /* FCR = ENABLE_FIFO (stored, unobservable) */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 34

  /* ---- 35..40. DLAB routes the data registers -------------------------- */
  li      t0, 0x80
  sb      t0, 3(s0)               /* LCR = DLAB */
  lbu     t0, 0(s0)
  CKQ     t0, 0x0c, 35            /* DLL reset value */
  li      t0, 0x55
  sb      t0, 0(s0)               /* DLL = 0x55 ... */
  sb      t0, 1(s0)               /* ... DLM = 0x55 (write before reading: Spike
                                     leaves DLM uninitialised) */
  lbu     t0, 0(s0)
  CKQ     t0, 0x55, 36
  lbu     t0, 1(s0)
  CKQ     t0, 0x55, 37
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 38            /* IIR is not routed by DLAB */
  li      t0, 0
  sb      t0, 3(s0)               /* LCR = 0 */
  lbu     t0, 0(s0)
  CKQ     t0, 0, 39               /* RBR again (the queue is empty) */
  lbu     t0, 3(s0)
  CKQ     t0, 0, 40

  /* ---- 41..44. the status registers are not writable ------------------- */
  li      t0, 0xff
  sb      t0, 5(s0)
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 41
  sb      t0, 6(s0)
  lbu     t0, 6(s0)
  CKQ     t0, 0xb0, 42
  li      t0, 0xa5
  sb      t0, 7(s0)
  lbu     t0, 7(s0)
  CKQ     t0, 0xa5, 43
  sb      t0, 7(s0)
  lbu     t0, 7(s0)
  CKQ     t0, 0xa5, 44

  /* ---- 45..49. the receive queue is 64 deep ---------------------------- */
  li      s1, 65
  li      t1, 0x5a
1:
  sb      t1, 0(s0)               /* 65 pushes: the last one is dropped */
  addi    s1, s1, -1
  bnez    s1, 1b
  li      s1, 64
2:
  lbu     t0, 0(s0)
  CKQ     t0, 0x5a, 45            /* the first 64 came back in order */
  addi    s1, s1, -1
  bnez    s1, 2b
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 46            /* the queue is empty: the 65th byte was dropped */
  lbu     t0, 0(s0)
  CKQ     t0, 0, 47
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 48
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 49

  /* ---- 50..53. loopback off: the store reaches the LINE, not the queue -- */
  li      t0, 0x08
  sb      t0, 4(s0)               /* MCR = OUT2 (loopback off) */
  li      t0, 0x5a
  sb      t0, 0(s0)               /* the one byte this program puts on the console */
  lbu     t0, 5(s0)
  CKQ     t0, 0x60, 50            /* nothing was queued */
  lbu     t0, 0(s0)
  CKQ     t0, 0, 51
  lbu     t0, 2(s0)
  CKQ     t0, 0xc1, 52
  li      t0, 0x18
  sb      t0, 4(s0)               /* loopback on again */
  li      t0, 0x5b
  sb      t0, 0(s0)
  lbu     t0, 0(s0)
  CKQ     t0, 0x5b, 53

  /* ---- 54. a wider access to the page is an access fault --------------- */
  lw      t0, 0(s0)               /* only the byte register file is served */
  CKQ     s8, 5, 54               /* load access fault */
  CKQ     s9, UART, 55            /* ... with mtval = the address */

  li      a0, 0
  ret

  /* ====================================================================
   * Trap handler: record mcause/mtval in s8/s9 and skip a 4-byte
   * instruction (only the 4-byte access above is expected to fault).
   * ==================================================================== */
  .align 2
uart_trap:
  csrr    s8, mcause
  csrr    s9, mtval
  csrr    t0, mepc
  addi    t0, t0, 4
  csrw    mepc, t0
  mret

  .section .note.GNU-stack, "", @progbits
