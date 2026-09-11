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
from emri_constants import (
    OCC_BLANK,
    OCC_CMD_START,
    OCC_STATUS_DONE_FLAG,
    OCC_WRITE,
    R_OCC_CMD,
    R_OCC_DECODE,
    R_OCC_FRAME_ADDR,
    R_OCC_STATUS,
    R_OCC_WDATA,
    R_OCC_WORD_COUNT,
)

NOP = 0x00000013

# IMEM ROM physical depth in the vendored minimal netlist (neorv32_imem_rom
# memory reg[255:0]); the image is padded to this many 32-bit words.
ROM_WORDS = 256

# XBUS target window. NEORV32 XBUS = the "void": any access outside
# IMEM(0x00000000) / DMEM(0x80000000) / IO(0xFFE00000+) routes to XBUS, and the
# full 32-bit CPU address forwards to xbus_adr_o unchanged (neorv32_xbus.vhd
# `xbus_adr_o <= bus_req.addr`). 0x40000000 is safely clear of all internal
# regions -> routed to XBUS -> our eth_wb2axi -> the eth_axi fabric.
XBUS_BASE = 0x40000000

# Second XBUS window (xbar mode): routed by eth_axi_xbar to a SECOND slave,
# proving address decode. 4 KiB-apart windows match the TB's ADDR_MAP masks.
XBUS2_BASE = 0x40001000

# EMRI management window (emri mode): the xbar routes this to the
# emri_axi_adapter -> emri_regfile peripheral. Matches tb_bmc_axi_emri.
EMRI_BASE = 0x40002000

# OCC byte offsets within the EMRI window (register word-offset * 4).
OFF_OCC_CMD = R_OCC_CMD * 4
OFF_OCC_WDATA = R_OCC_WDATA * 4
OFF_OCC_STATUS = R_OCC_STATUS * 4
OFF_OCC_FRAME_ADDR = R_OCC_FRAME_ADDR * 4
OFF_OCC_WORD_COUNT = R_OCC_WORD_COUNT * 4
OFF_OCC_DECODE = R_OCC_DECODE * 4


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


def _add(rd: int, rs1: int, rs2: int) -> int:
    return (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0110011


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


def _blt(rs1: int, rs2: int, imm: int) -> int:
    # BLT: branch if rs1 < rs2 (signed). funct3 = 100.
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (0b100 << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 0x1) << 7)
        | 0b1100011
    )


def _bne(rs1: int, rs2: int, imm: int) -> int:
    # BNE: branch if rs1 != rs2. funct3 = 001.
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (0b001 << 12)
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


def _emit_char(prog: list[int], ch: str) -> None:
    """Append the poll-TX-then-store sequence for one character.

    Assumes x5 = UART0 base and UART0 already enabled. Uses x6 (char) + x7
    (poll scratch).
    """
    prog.append(_addi(6, 0, ord(ch)))  # x6 = char
    poll = len(prog)  # index of the poll loop head (in words)
    prog.append(_lw(7, 0, 5))  # x7 = CTRL
    prog.append(_srli(7, 7, 19))  # TX_NFULL -> bit0
    prog.append(_andi(7, 7, 1))  # isolate
    prog.append(_beq(7, 0, (poll - len(prog)) * 4))  # spin while full
    prog.append(_sw(6, 4, 5))  # DATA = char


def _emit_hex_nibble(prog: list[int], reg: int) -> None:
    """Append code that prints the low nibble of ``reg`` as one hex char.

    Uses x10 (nibble/char) + x11 (constant 10) + x7 (poll scratch). UART0 must
    already be enabled with x5 = base. The digit/letter select uses BLT with a
    fixed-up branch offset, then a JAL skips the digit path.
    """
    prog.append(_andi(10, reg, 0xF))  # x10 = reg & 0xF
    prog.append(_addi(11, 0, 10))  # x11 = 10
    blt_idx = len(prog)
    prog.append(0)  # placeholder: BLT x10, x11 -> digit path (fixed below)
    # >= 10 (letter) path: char = 'A' + (x10 - 10) = x10 + 55 (uppercase hex,
    # matching the tb_bmc_axi_master expected message "AX 5AA5C33C\n")
    prog.append(_addi(10, 10, 55))
    jal_idx = len(prog)
    prog.append(0)  # placeholder: JAL -> store (skip digit path, fixed below)
    digit_idx = len(prog)
    prog.append(_addi(10, 10, ord("0")))  # digit path: char = '0' + x10
    store_idx = len(prog)
    # fix up branch/jump targets (offsets are byte-relative to the instruction)
    prog[blt_idx] = _blt(10, 11, (digit_idx - blt_idx) * 4)
    prog[jal_idx] = _jal(0, (store_idx - jal_idx) * 4)
    # poll TX-not-full then store the char in x10
    poll = len(prog)
    prog.append(_lw(7, 0, 5))
    prog.append(_srli(7, 7, 19))
    prog.append(_andi(7, 7, 1))
    prog.append(_beq(7, 0, (poll - len(prog)) * 4))
    prog.append(_sw(10, 4, 5))


def _const32(rd: int, val: int) -> list[int]:
    """Return the LUI+ADDI pair loading the 32-bit constant ``val`` into ``rd``.

    LUI shifts a 20-bit immediate left by 12; ADDI adds a signed 12-bit
    immediate. The standard split is hi20 = (val >> 12) + carry, lo_s = low
    12 bits sign-adjusted (carry when the low 12 bits have the top bit set,
    which ADDI would subtract from hi).
    """
    lo12 = val & 0xFFF
    carry = 1 if lo12 >= 0x800 else 0
    hi20 = ((val >> 12) + carry) & 0xFFFFF
    lo_s = lo12 - 0x1000 if lo12 >= 0x800 else lo12
    return [_lui(rd, hi20), _addi(rd, rd, lo_s)]


def _emit_hex32(prog: list[int], reg: int) -> None:
    """Append code printing all 8 hex digits of ``reg`` (MSB-first)."""
    for i in range(8):
        prog.append(_srli(10, reg, 28 - i * 4))  # bring nibble i (from MSB) to low
        _emit_hex_nibble(prog, 10)


def build_words(message: str) -> list[int]:
    """Return the hello image as a list of 32-bit words, padded to ``ROM_WORDS``."""
    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
    ]
    for ch in message:
        _emit_char(prog, ch)
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def build_words_xbus(wval: int) -> list[int]:
    """Image that does an XBUS write+readback and prints the value over UART0.

    Writes ``wval`` to the XBUS-window register at ``XBUS_BASE`` (via the
    eth_wb2axi bridge -> eth_axi slave), reads it back, then prints "AX" + a
    space + 8 hex digits (MSB-first) + "\\n" over UART0. This proves the BMC
    drives the AXI fabric end-to-end.
    """
    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
        _lui(28, XBUS_BASE >> 12),  # x28 = XBUS base 0x40000000 (LUI imm<<12)
    ]
    prog += _const32(29, wval)  # x29 = wval
    prog.append(_sw(29, 0, 28))  # XBUS[0x40000000] = wval   (AXI write)
    prog.append(_lw(30, 0, 28))  # x30 = XBUS[0x40000000]    (AXI read back)
    _emit_char(prog, "A")  # banner
    _emit_char(prog, "X")
    _emit_char(prog, " ")
    _emit_hex32(prog, 30)  # print 8 hex digits of x30, MSB-first
    _emit_char(prog, "\n")
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def build_words_xbar(wval0: int, wval1: int) -> list[int]:
    """Image exercising the BMC -> eth_wb2axi -> eth_axi_xbar -> 2 slaves path.

    Writes ``wval0`` to window 0 (``XBUS_BASE``) and ``wval1`` to window 1
    (``XBUS2_BASE``) — the xbar routes each by address decode — reads both
    back, then prints "XB " + hex(wval0) + " " + hex(wval1) + "\\n" over
    UART0. Proves the BMC drives the xbar fabric end-to-end incl. routing.

    Register plan: x5=UART0 base, x6/x7 UART scratch, x10/x11 hex scratch,
    x28=win0 base, x27=win1 base, x30=readback0, x25=readback1.
    """
    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
        _lui(28, XBUS_BASE >> 12),  # x28 = win0 base 0x40000000
        _lui(27, XBUS2_BASE >> 12),  # x27 = win1 base 0x40001000
    ]
    prog += _const32(29, wval0)  # x29 = wval0
    prog.append(_sw(29, 0, 28))  # win0[0] = wval0   (AXI write, route slave0)
    prog += _const32(26, wval1)  # x26 = wval1
    prog.append(_sw(26, 0, 27))  # win1[0] = wval1   (AXI write, route slave1)
    prog.append(_lw(30, 0, 28))  # x30 = win0[0]     (read back slave0)
    prog.append(_lw(25, 0, 27))  # x25 = win1[0]     (read back slave1)
    _emit_char(prog, "X")  # banner
    _emit_char(prog, "B")
    _emit_char(prog, " ")
    _emit_hex32(prog, 30)
    _emit_char(prog, " ")
    _emit_hex32(prog, 25)
    _emit_char(prog, "\n")
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def build_words_emri() -> list[int]:
    """Image reading EMRI identity registers via the AXI management path.

    Chain: NEORV32 -> XBUS -> eth_wb2axi -> eth_axi_xbar -> emri_axi_adapter
    -> emri_regfile. Reads MAGIC (word 0) and CAPABILITIES (word 2) from the
    EMRI window at ``EMRI_BASE`` and prints "EM " + hex(magic) + " " +
    hex(capabilities) + "\\n" over UART0. With HAS_BMC=1 the expected output
    is "EM 45544852 00000001\\n" — proving the BMC reaches the management
    register plane through the AXI fabric end-to-end.

    Register plan: x5=UART0 base, x6/x7 UART scratch, x10/x11 hex scratch,
    x27=EMRI window base, x30=MAGIC readback, x25=CAPABILITIES readback.
    """
    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
        _lui(27, EMRI_BASE >> 12),  # x27 = EMRI window base 0x40002000
        _lw(30, 0, 27),  # x30 = EMRI.MAGIC         (word 0, byte 0x00)
        _lw(25, 8, 27),  # x25 = EMRI.CAPABILITIES  (word 2, byte 0x08)
    ]
    _emit_char(prog, "E")  # banner
    _emit_char(prog, "M")
    _emit_char(prog, " ")
    _emit_hex32(prog, 30)
    _emit_char(prog, " ")
    _emit_hex32(prog, 25)
    _emit_char(prog, "\n")
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def build_words_occ(frame_addr: int, data: list[int]) -> list[int]:
    """Image driving a real OCC region-config WRITE via the AXI mgmt path.

    Chain: NEORV32 -> XBUS -> eth_wb2axi -> eth_axi_xbar -> emri_axi_adapter
    -> emri_regfile -> occ_top -> column_cfg_ram. This is the Phase-D loop
    closure: the BMC (not a host BFM) streams a config frame into the fabric.

    Sequence (mirrors the host sequence in tb_emri_occ_loop.sv):
      1. OCC_FRAME_ADDR = frame_addr, OCC_WORD_COUNT = len(data)
      2. OCC_CMD = START | WRITE | region(frame_addr top 4 bits)
      3. push each data word via OCC_WDATA (the BMC `sw` stalls until the
         skid accepts it — backpressure is transparent, no firmware polling)
      4. poll OCC_STATUS until the sticky done_flag (bit3), check done_code
         [5:4]==0 (DONE), then print "OC " + hex(status) + "\\n".

    On a clean reset all regions start non-dirty (E0-FAB5), so the first WRITE
    is accepted without a BLANK. After a successful WRITE of N words at frame
    base F, OCC_STATUS reads: done_flag=1, done_code=0, live=IDLE, crc=0,
    region=0, frame_echo=F -> for F=0 the word is exactly 0x00000008.

    Register plan: x5=UART0 base, x6/x7 UART scratch, x10/x11 hex scratch,
    x27=EMRI window base, x28=frame addr, x29=word count / data word,
    x30=cmd / status readback, x31=poll scratch.
    """
    n = len(data)
    # region_id[15:12] (emri-v0.md sec 2, OCC_FRAME_ADDR v0.6).
    region = (frame_addr >> 12) & 0xF
    cmd_word = (1 << OCC_CMD_START) | (region << 2) | OCC_WRITE

    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
        _lui(27, EMRI_BASE >> 12),  # x27 = EMRI window base 0x40002000
    ]
    # 1. frame address + word count
    prog += _const32(28, frame_addr)  # x28 = frame_addr
    prog.append(_sw(28, OFF_OCC_FRAME_ADDR, 27))  # OCC_FRAME_ADDR = frame_addr
    prog += _const32(29, n)  # x29 = N
    prog.append(_sw(29, OFF_OCC_WORD_COUNT, 27))  # OCC_WORD_COUNT = N
    # 2. issue WRITE command (held until occ_top accepts via host_ready)
    prog += _const32(30, cmd_word)  # x30 = START|WRITE|region
    prog.append(_sw(30, OFF_OCC_CMD, 27))  # OCC_CMD = start write
    # 3. stream the config words (unrolled; each `sw` stalls until accepted)
    for w in data:
        prog += _const32(29, w & 0xFFFFFFFF)  # x29 = data word
        prog.append(_sw(29, OFF_OCC_WDATA, 27))  # OCC_WDATA push
    # 4. poll done_flag (bit3)
    poll = len(prog)
    prog.append(_lw(30, OFF_OCC_STATUS, 27))  # x30 = OCC_STATUS
    prog.append(_andi(31, 30, 1 << OCC_STATUS_DONE_FLAG))  # x31 = done_flag
    prog.append(_beq(31, 0, (poll - len(prog)) * 4))  # spin while 0
    # 5. re-read status and print it (deterministic: 0x00000008 for frame 0)
    prog.append(_lw(30, OFF_OCC_STATUS, 27))  # x30 = OCC_STATUS (final)
    _emit_char(prog, "O")  # banner
    _emit_char(prog, "C")
    _emit_char(prog, " ")
    _emit_hex32(prog, 30)
    _emit_char(prog, "\n")
    prog.append(_jal(0, 0))  # halt

    if len(prog) > ROM_WORDS:
        raise ValueError(f"program too large: {len(prog)} words > {ROM_WORDS}")
    return prog + [NOP] * (ROM_WORDS - len(prog))


def build_words_occ_fabric(frame_words: list[int]) -> list[int]:
    """Image streaming a REAL packed config frame into the fabric (Phase E).

    Chain: NEORV32 -> XBUS -> eth_wb2axi -> eth_axi_xbar -> emri_axi_adapter
    -> emri_regfile -> occ_top -> frame_decoder -> fabric_top. The BMC (not a
    host BFM) configures a real fabric region with a packed column image.

    Sequence (self-contained deploy, emri-v0.md §3.1):
      1. OCC_FRAME_ADDR=0 == ``column_frame_base(0, 0)`` in the v0.6 layout
         {region_id[15:12], col_id[11:8], word[7:0]} (emri-v0.md sec 2, 0x0B),
         OCC_WORD_COUNT=N (N = DATA words, CRC tail excluded)
      2. OCC_DECODE = col 0  -> pulses dec_start_o (frame_decoder starts capture)
      3. OCC_CMD = START|WRITE|region0
      4. loop: read each packed word from a ROM data table (IMEM) and push it
         via OCC_WDATA (the `sw` stalls until the skid accepts it — no polling)
      5. poll OCC_STATUS done_flag (bit3), re-read status, print
         "OF " + hex(status) + "\\n". Clean WRITE of frame 0 -> 0x00000008.

    The packed ``frame_words`` (``pack_tb_frames.py`` output, tail dropped) are
    appended as a data table AFTER the code; the push loop reads them from IMEM
    (mapped at 0x0) via a base register whose value is fixed up once the code
    length is known.

    Register plan: x5=UART0 base, x6/x7 UART scratch, x8=const scratch,
    x26=table base, x27=EMRI base, x28=loop counter, x29=data word,
    x30=cmd/status, x31=poll scratch.
    """
    n = len(frame_words)
    region = 0
    cmd_word = (1 << OCC_CMD_START) | (region << 2) | OCC_WRITE

    prog: list[int] = [
        _lui(5, 0xFFF50),  # x5 = UART0 base 0xFFF50000
        _addi(6, 0, 1),  # x6 = UART_CTRL_EN
        _sw(6, 0, 5),  # CTRL = enable
        _lui(27, EMRI_BASE >> 12),  # x27 = EMRI window base 0x40002000
        _sw(0, OFF_OCC_FRAME_ADDR, 27),  # OCC_FRAME_ADDR = 0
    ]
    prog += _const32(8, n)  # x8 = N
    prog.append(_sw(8, OFF_OCC_WORD_COUNT, 27))  # OCC_WORD_COUNT = N

    # ---- BLANK the column first (FABulous red line; clears X-init cfg SRAM) ---
    prog += _const32(8, 0)  # x8 = col 0
    prog.append(_sw(8, OFF_OCC_DECODE, 27))  # OCC_DECODE (pulse dec_start)
    prog += _const32(8, (1 << OCC_CMD_START) | (region << 2) | OCC_BLANK)
    prog.append(_sw(8, OFF_OCC_CMD, 27))  # OCC_CMD = START|BLANK
    poll = len(prog)  # poll for BLANK done
    prog.append(_lw(30, OFF_OCC_STATUS, 27))
    prog.append(_andi(31, 30, 1 << OCC_STATUS_DONE_FLAG))
    prog.append(_beq(31, 0, (poll - len(prog)) * 4))

    # ---- WRITE the packed image ---------------------------------------------
    prog += _const32(8, 0)  # x8 = col 0
    prog.append(_sw(8, OFF_OCC_DECODE, 27))  # OCC_DECODE (pulse dec_start)
    prog += _const32(8, cmd_word)  # x8 = START|WRITE|region0
    prog.append(_sw(8, OFF_OCC_CMD, 27))  # OCC_CMD = start write
    # push loop over the ROM data table
    prog += _const32(28, n)  # x28 = counter = N
    tbl_fix_idx = len(prog)  # where const32(26, table_base) goes (fixed below)
    prog += [0, 0]  # placeholder: const32(26, table_base)
    loop_head = len(prog)
    prog.append(_lw(29, 0, 26))  # x29 = table[i]
    prog.append(_sw(29, OFF_OCC_WDATA, 27))  # OCC_WDATA push
    prog.append(_addi(26, 26, 4))  # x26 += 4 (next word)
    prog.append(_addi(28, 28, -1))  # counter--
    prog.append(_bne(28, 0, (loop_head - len(prog)) * 4))  # loop while != 0
    # poll done_flag (bit3)
    poll = len(prog)
    prog.append(_lw(30, OFF_OCC_STATUS, 27))  # x30 = OCC_STATUS
    prog.append(_andi(31, 30, 1 << OCC_STATUS_DONE_FLAG))  # x31 = done_flag
    prog.append(_beq(31, 0, (poll - len(prog)) * 4))  # spin while 0
    # re-read status and print it
    prog.append(_lw(30, OFF_OCC_STATUS, 27))  # x30 = OCC_STATUS (final)
    _emit_char(prog, "O")  # banner
    _emit_char(prog, "F")
    _emit_char(prog, " ")
    _emit_hex32(prog, 30)
    _emit_char(prog, "\n")
    prog.append(_jal(0, 0))  # halt
    # data table starts right after the code; fix up the table-base load
    table_base_byte = len(prog) * 4  # IMEM is mapped at 0x0, word i at byte 4*i
    prog[tbl_fix_idx : tbl_fix_idx + 2] = _const32(26, table_base_byte)
    prog += [w & 0xFFFFFFFF for w in frame_words]  # the packed column data

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
        help="message to print over UART0 (default 'HI\\n'); ignored when --mode=xbus",
    )
    parser.add_argument(
        "--mode",
        choices=["hello", "xbus", "xbar", "emri", "occ", "occ-fabric"],
        default="hello",
        help="hello = print --message; xbus = XBUS write+readback, print value; "
        "xbar = two-window write+readback via eth_axi_xbar, print both values; "
        "emri = read EMRI MAGIC+CAPABILITIES via the AXI path, print both; "
        "occ = stream an OCC config frame via the AXI mgmt path, print status; "
        "occ-fabric = stream a REAL packed frame (needs --frame-hex) into the "
        "fabric via R_OCC_DECODE, print status",
    )
    parser.add_argument(
        "--wval",
        default="0x5AA5C33C",
        help="32-bit value the xbus mode writes/reads (default 0x5AA5C33C); "
        "xbar mode window-0 value",
    )
    parser.add_argument(
        "--wval2",
        default="0xC33C5AA5",
        help="xbar mode window-1 value (default 0xC33C5AA5)",
    )
    parser.add_argument(
        "--frame-addr",
        dest="frame_addr",
        default="0x0",
        help="occ mode: config frame base address (default 0x0)",
    )
    parser.add_argument(
        "--occ-data",
        dest="occ_data",
        default="0xC0DE0000,0xC0DE0001,0xC0DE0002,0xC0DE0003",
        help="occ mode: comma-separated config words to stream (default 4x 0xC0DE000i)",
    )
    parser.add_argument(
        "--frame-hex",
        dest="frame_hex",
        default=None,
        help="occ-fabric mode: path to a packed frame .hex (pack_tb_frames.py "
        "output); the CRC tail word is dropped, DATA words are streamed",
    )
    args = parser.parse_args(argv)

    if args.mode == "occ-fabric":
        if not args.frame_hex:
            parser.error("--mode occ-fabric requires --frame-hex <path>")
        lines = [
            ln.strip()
            for ln in Path(args.frame_hex).read_text().splitlines()
            if ln.strip()
        ]
        all_words = [int(ln, 16) & 0xFFFFFFFF for ln in lines]
        data_words = all_words[:-1]  # drop the CRC16 tail (last word)
        words = build_words_occ_fabric(data_words)
        note = (
            f"mode=occ-fabric n={len(data_words)} from {args.frame_hex} "
            f"(prints 'OF ' + OCC_STATUS hex + '\\n')"
        )
    elif args.mode == "occ":
        frame_addr = int(args.frame_addr, 0) & 0xFFFFFFFF
        data = [int(v, 0) & 0xFFFFFFFF for v in args.occ_data.split(",")]
        words = build_words_occ(frame_addr, data)
        note = (
            f"mode=occ frame=0x{frame_addr:x} n={len(data)} "
            f"(prints 'OC ' + OCC_STATUS hex + '\\n')"
        )
    elif args.mode == "emri":
        words = build_words_emri()
        note = "mode=emri (prints 'EM ' + MAGIC hex + ' ' + CAP hex + '\\n')"
    elif args.mode == "xbar":
        wval0 = int(args.wval, 0) & 0xFFFFFFFF
        wval1 = int(args.wval2, 0) & 0xFFFFFFFF
        words = build_words_xbar(wval0, wval1)
        note = (
            f"mode=xbar wval0=0x{wval0:08x} wval1=0x{wval1:08x} "
            f"(prints 'XB ' + 8 hex + ' ' + 8 hex + '\\n')"
        )
    elif args.mode == "xbus":
        wval = int(args.wval, 0) & 0xFFFFFFFF
        words = build_words_xbus(wval)
        note = f"mode=xbus wval=0x{wval:08x} (prints 'AX ' + 8 hex + '\\n')"
    else:
        message = args.message.encode().decode("unicode_escape")
        words = build_words(message)
        note = f"mode=hello message={message!r}"

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("".join(f"{w:08x}\n" for w in words))
    print(f"[gen_bmc_hello] wrote {len(words)} words -> {args.out} ({note})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
