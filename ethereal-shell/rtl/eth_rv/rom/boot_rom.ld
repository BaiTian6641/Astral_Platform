/* SPDX-License-Identifier: CERN-OHL-S-2.0
 *
 * Linker script for the eth_rv BootROM (see boot_rom.S).
 *
 * The image is a flat 4 KiB region at ROM_BASE = 0x0000_1000: the stub, the
 * 64-bit payload-entry word at offset 32, and zeros to the region end. The
 * harness loads the region verbatim (build_rom.py -> boot_rom.hex ->
 * tb_eth_rv_core `+rom=` / `eth_rv_boot_rom`), so the only requirement here is
 * that nothing lands outside it.
 *
 * PAYLOAD_ENTRY is the entry value baked into the image (the harness overrides
 * it at run time): 0x8000_0000 is the memory window base the corpus links at,
 * so an unmodified ROM boots the ordinary corpus.
 */
OUTPUT_ARCH(riscv)
ENTRY(_rom_start)

PROVIDE(PAYLOAD_ENTRY = 0x80000000);

SECTIONS
{
  . = 0x00001000;

  .text : {
    _rom_start_addr = .;
    *(.text.init)
    *(.text)
    *(.text.*)
    . = ALIGN(4);
    _rom_end = .;
  }

  ASSERT(_rom_start_addr == 0x00001000, "BootROM does not start at ROM_BASE")
  ASSERT(_rom_end <= 0x00002000, "BootROM image overflows the 4 KiB region")

  /DISCARD/ : {
    *(.comment)
    *(.riscv.attributes)
    *(.note.GNU-stack)
  }
}
