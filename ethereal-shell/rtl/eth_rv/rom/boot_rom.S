/* SPDX-License-Identifier: CERN-OHL-S-2.0
 *
 * eth_rv BootROM (E2-RV2 increment 5, S3) — the M-mode stub the core starts
 * executing on after reset.
 *
 * CONTRACT (fixed by the S3 interface, mirrors Spike's reset vector shape):
 *   * the ROM lives at ROM_BASE = 0x0000_1000, 4 KiB (word 0 of the region is
 *     the first instruction executed at reset — `eth_rv_pkg::RESET_PC`);
 *   * it leaves a0 = mhartid (0: the design is one hart) and
 *     a1 = 0x8000_2000 (the DTB the harness loads into RAM at that address);
 *   * it jumps to the 64-bit payload entry stored as a DATA word at ROM offset
 *     ROM_ENTRY_OFF = 32 (word 8), so the harness can point the same ROM at any
 *     payload entry — exactly how Spike's own reset vector takes its start PC
 *     from word 6 of its ROM (`sim_t::set_rom`, riscv/sim.cc). The testbench
 *     patches those two words from `+entry=<addr>` before reset.
 *
 * THE STEP-COUNT WORD (offset 28, word 7) is the second number in the image the
 * rest of the design consumes: `(_rom_stub_end - _rom_start) / 4`, i.e. how many
 * instructions this stub runs before it hands off. `eth_rv_boot_rom` exports it
 * and `eth_rv_clint` uses it to swallow exactly those step pulses, so the hart's
 * instruction-count cadence (which `mtime`/`time` are a staircase of) is what the
 * GOLDEN model sees — whose own reset vector is *not* this stub and whose
 * pre-program instruction count the testbench supplies as the CLINT preload. The
 * count is computed by the linker from the stub's own bytes, so editing the stub
 * cannot silently shift the time phase: it either fits (and the count follows) or
 * `.org` fails the build.
 *
 * `.option norvc` is what makes that derivation exact: every instruction is four
 * bytes, so instructions == bytes / 4. `_rom_stub_end` MUST stay at or below the
 * step-count word's offset — a longer stub makes the `.org` fail the build rather
 * than overwrite the word (and a shorter one leaves never-executed zero padding,
 * which is fine).
 *
 * WHY THE a1 SEQUENCE IS SPELLED OUT: `li a1, 0x8000_2000` cannot be a single
 * LUI — LUI sign-extends bit 31, so it would yield 0xffff_ffff_8000_2000 — and
 * a PC-relative pair cannot reach an address 2 GiB away while keeping the low
 * 12 bits. The three-instruction LUI/SLLI/SRLI below is the exact, stable
 * encoding (the assembler's own `li` expansion for this constant is four
 * instructions, which would not fit the fixed 28-byte pre-step-word area).
 *
 * ASSEMBLY: see build_rom.py (toolchain flags match the corpus builder).
 */

    .equ ROM_BASE,      0x00001000          /* reset vector (eth_rv_pkg RESET_PC) */
    .equ ROM_STEP_OFF,  28                  /* word 7: the stub's instruction count */
    .equ ROM_ENTRY_OFF, 32                  /* word 8: the 64-bit payload entry   */

    /* a1 = the device tree blob address. Overridable (`-DDTB_ADDR=…`) so a build
     * can produce a deliberately wrong ROM: the negative control for the
     * testbench's boot-handshake check. */
#ifndef DTB_ADDR
#define DTB_ADDR 0x80002000
#endif

    .option norvc                           /* fixed 4-byte instructions: count = bytes/4 */

    .section .text.init, "ax"
    .globl _rom_start
    .align 2
_rom_start:
    auipc   t0, 0                           /* t0 = ROM_BASE: the entry word's base */
    lui     a1, DTB_ADDR >> 12              /* a1 = 0xffff_ffff_8000_2000 (sign-extended) */
    slli    a1, a1, 32                      /* a1 = 0x8000_2000_0000_0000 */
    srli    a1, a1, 32                      /* a1 = 0x0000_0000_8000_2000 */
    csrr    a0, mhartid                     /* a0 = hart id (0: single hart) */
    ld      t0, ROM_ENTRY_OFF(t0)           /* t0 = the 64-bit payload entry */
    jr      t0                              /* hand off to the payload */
_rom_stub_end:

    /* The stub's instruction count, right after the stub: word 7 of the region,
     * read by the CLINT as its step skip. Link-time difference of two symbols in
     * this section, so it is derived, not typed. */
    .org    ROM_STEP_OFF
    .globl  _rom_steps
_rom_steps:
    .word   (_rom_stub_end - _rom_start) / 4

    /* The 64-bit payload entry, at the offset the `ld` above reads. It is a
     * LINKER value (PROVIDE(PAYLOAD_ENTRY) in boot_rom.ld, overridable with
     * `--defsym`) so a build can bake any entry; the harness overrides it at
     * run time by patching these two words in the loaded image. */
    .org    ROM_ENTRY_OFF
    .globl  _rom_entry
_rom_entry:
    .dword  PAYLOAD_ENTRY

    /* The rest of the 4 KiB region is filled with zeros by the linker. */
    .section .note.GNU-stack, "", @progbits
