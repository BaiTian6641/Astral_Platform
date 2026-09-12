/* SPDX-License-Identifier: MIT
 *
 * Linker script for `cor_boot.S` — the BootROM-handoff corpus program.
 *
 * This is the corpus layout (corpus/link.ld) MOVED: the payload is linked at
 * 0x8000_1000 instead of the memory window base, so nothing about it can be
 * reached by the core's reset PC — only the BootROM's jump can get here. That is
 * the point of the program: a payload entry != RAM base is exactly what the v0
 * harness used to reject, and what `tb_eth_rv_core`'s `+entry` seam exists for.
 *
 * Everything stays inside the first 4 KiB of RAM, below the device tree blob the
 * contract puts at 0x8000_2000:
 *
 *   0x8000_1000  text/rodata/data/bss (this program)
 *   0x8000_1C00  tohost/fromhost (own page-ish slot, the HTIF mailbox)
 *   0x8000_1F00  stack top (grows down; the call depth here is one frame)
 *   0x8000_2000  the DTB — untouched by the payload, asserted by the TB
 *
 * The ASSERT below fails the link rather than silently spilling the program into
 * the tohost slot; the DTB page is a hard boundary, not a convention.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80001000;

  .text.init : { *(.text.init) }
  .text      : { *(.text) *(.text.*) }
  .rodata    : { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) }

  . = ALIGN(16);
  .data      : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) }
  . = ALIGN(16);
  .bss       : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) *(COMMON) }

  . = ALIGN(8);
  _end = .;

  ASSERT(_end <= 0x80001C00, "cor_boot image reaches the tohost slot")

  . = 0x80001C00;
  .tohost : { *(.tohost) }

  /* Stack top: just below the DTB page, with the tohost slot untouched below it. */
  _stack_top = 0x80001F00;
  ASSERT(_stack_top - _end >= 0x300, "cor_boot stack headroom is too small")

  /DISCARD/ : {
    *(.comment)
    *(.riscv.attributes)
    *(.note.GNU-stack)
  }
}
