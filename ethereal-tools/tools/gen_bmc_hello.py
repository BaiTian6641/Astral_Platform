# SPDX-License-Identifier: MIT
"""gen_bmc_hello — hand-crafted rv32 "hello" IMEM image for the NEORV32 BMC sim.

Plan-Ref: ethereal-plan/components/C05-BMC组件.md (ADR-016 bmc_core).

There is NO RISC-V gcc/binutils on the authoring box (only qemu user-mode), so
the documented upstream ``image_gen`` flow (compile a C app -> ELF -> image)
cannot run locally. For the v0 skeleton we instead hand-assemble a tiny rv32
program that makes the vendored NEORV32 (BOOT_MODE_SELECT=2, IMEM-as-ROM) write
a short message to UART0 TX, then emit it as a ``$readmemh`` word image that the
SV testbench (``tb_bmc_hello.sv``) preloads into the IMEM ROM via a backdoor.

Program (all rv32i, no compressed/M so it runs on the minimal rv32imc core):

    RESET (mtvec = IMEM base 0x00000000, 4-byte aligned, vectored -> +0 here):
      lui  x5, 0xfff50        # x5  = UART0 base 0xFFF50000
      li   x6, 1              # x6  = UART_CTRL_EN (bit0)
      sw   x6, 0(x5)          # CTRL  = enable (PRSC=0, BAUD=0 -> max baud)
      # for each char: poll TX-not-full, then store to DATA
      li   x6, <char>         # x6 = char (reloaded per char)
    poll:  lw  x7, 0(x5)      # x7 = CTRL
           srli x7, x7, 19    # bring UART_CTRL_TX_NFULL (bit19) to bit0
           andi x7, x7, 1     # isolate it
           beq  x7, x0, poll  # spin while FIFO full
      sw   x6, 4(x5)          # DATA = char
      jal  x0, 0              # halt (infinite loop)

Note: a full-word ``sw`` to DATA works because ``UART_DATA_RTX`` is bits[7:0].
The skeleton's TX FIFO is 1 deep, so between characters we poll CTRL bit 19
(`UART_CTRL_TX_NFULL`) and only store the next byte once the UART has drained
the previous one (the CPU stores far faster than the 2-clock/bit UART shifts).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# NOP = addi x0, x0, 0 (used to pad the image; harmless if ever executed).
NOP = 0x00000013

# IMEM ROM physical depth in the vendored minimal netlist (neorv32_imem_rom
# memory reg[255:0]); the image is padded to this many 32-bit words.
ROM_WORDS = 256


def _lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0b0110111


def _addi(rd: int, rs1: int, imm: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0010011


def _sw(rs2: int, imm: int, rs1: int) -> int:
    return (
        (((imm >> 5) & 0x7F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (0b010 << 12)
        | ((imm & 0x1F) << 7)
        | 0b0100011
    )


def _lw(rd: int, imm: int, rs1: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0b0000011


def _srli(rd: int, rs1: int, shamt: int) -> int:
    return ((shamt & 0x1F) << 20) | (rs1 << 15) | (0b101 << 12) | (rd << 7) | 0b0010011


def _andi(rd: int, rs1: int, imm: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (0b111 << 12) | (rd << 7) | 0b0010011


def _beq(rs1: int, rs2: int, imm: int) -> int:
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (0b000 << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 0x1) << 7)
        | 0b1100011
    )


def _jal(rd: int, imm: int) -> int:
    return (
        (((imm >> 20) & 0x1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 0x1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | (rd << 7)
        | 0b1101111
    )


def build_words(message: str) -> list[int]:
    """Return the image as a list of 32-bit words, padded to ``ROM_WORDS``."""
    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
    ]
    for ch in message:
        prog.append(_addi(6, 0, ord(ch)))  # x6 = char
        poll = len(prog)  # index of the poll loop head (in words)
        prog.append(_lw(7, 0, 5))  # x7 = CTRL
        prog.append(_srli(7, 7, 19))  # TX_NFULL -> bit0
        prog.append(_andi(7, 7, 1))  # isolate
        prog.append(_beq(7, 0, (poll - len(prog)) * 4))  # spin while full
        prog.append(_sw(6, 4, 5))  # DATA = char
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="output .hex file (one 32-bit word per line, for $readmemh)",
    )
    parser.add_argument(
        "--message",
        default="HI\n",
        help="message to print over UART0 (default 'HI\\n')",
    )
    args = parser.parse_args(argv)

    message = args.message.encode().decode("unicode_escape")
    words = build_words(message)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("".join(f"{w:08x}\n" for w in words))
    print(f"[gen_bmc_hello] wrote {len(words)} words -> {args.out} (message={message!r})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
