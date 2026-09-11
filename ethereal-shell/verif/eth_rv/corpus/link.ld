/* SPDX-License-Identifier: MIT
 *
 * Linker script for the eth_rv DiffTest corpus (S15 §2.2).
 *
 * Layout: everything lives in Spike's default DRAM window (0x8000_0000 + 2 GiB),
 * and the HTIF `tohost`/`fromhost` mailbox sits on its own page so that Spike
 * (and the Python model DUT) can detect the exit store unambiguously.
 * The stack grows down from `_stack_top`, which the linker places past the
 * mailbox — nothing in the corpus relies on stack contents surviving.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;

  .text.init : { *(.text.init) }
  .text      : { *(.text) *(.text.*) }
  .rodata    : { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) }

  . = ALIGN(16);
  .data      : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) }
  . = ALIGN(16);
  .bss       : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) *(COMMON) }

  . = ALIGN(8);
  _end = .;

  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }

  . = ALIGN(0x1000);
  _stack_top = . + 0x8000;
}
