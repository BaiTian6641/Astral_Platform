# SPDX-License-Identifier: MIT
"""Worked-example DUT for the ``eth_rv`` DiffTest harness (S15 §2.2).

This is the *second* implementation the harness diffs against Spike: a small,
bit-accurate RV64IMC interpreter written in Python. It exists so that the
lockstep protocol has a real, runnable DUT **today**, before ``eth_rv`` RTL is
written — the RTL testbench plugs in exactly where this module sits
(see ``README.md`` → "How the future ``eth_rv`` RTL core plugs in").

Supported ISA subset (anything else raises :class:`UnsupportedInstruction`):

* RV64I: LUI/AUIPC/JAL/JALR/branches/loads/stores/OP-IMM/OP/OP-IMM-32/OP-32, FENCE.
* RV64M: mul/mulh/mulhsu/mulhu/div/divu/rem/remu and their ``*W`` forms.
* RV64C: the integer compressed forms (c.addi, c.li, c.mv, c.add, c.j, c.jr,
  c.jalr, c.beqz/c.bnez, c.lw/c.ld/c.sw/c.sd + SP variants, c.slli/c.srli/c.srai/
  c.andi/c.sub/c.xor/c.or/c.and/c.subw/c.addw, c.addi4spn, c.addi16sp, c.lui,
  c.addiw, c.nop). Floating-point compressed forms are rejected.

Deliberately *not* modelled: CSRs, traps (``ecall``/``ebreak``), interrupts, MMU,
atomics, floating point. The corpus (``corpus/``) stays inside the subset above.

Program input: an ELF or a ``.hex`` image (see :mod:`rv_image`). Execution stops
after the commit that writes a non-zero value to ``tohost`` — the same HTIF exit
Spike uses, so both traces end on the same instruction.
"""
from __future__ import annotations

from collections.abc import Iterator
from dataclasses import replace
from pathlib import Path

from rv_image import Image, load_image
from rv_trace import Commit, format_trace

XLEN = 64
MASK64 = (1 << XLEN) - 1
MASK32 = (1 << 32) - 1
PAGE_BITS = 12
PAGE_SIZE = 1 << PAGE_BITS
PAGE_MASK = PAGE_SIZE - 1

DEFAULT_MAX_COMMITS = 1_000_000
"""Guard against a program that never reaches its ``tohost`` store."""


class ModelError(RuntimeError):
    """The example DUT cannot run this program (bad image, trap, run-away)."""


class UnsupportedInstruction(ModelError):
    """The interpreter met an instruction outside its documented subset."""


def _lane_mask(size: int, addr: int) -> int:
    """Byte lanes of the 8-byte-aligned window at ``addr & ~7`` covered by ``size`` bytes."""
    return ((1 << size) - 1) << (addr & 0b111)


def _with_mem_access(commit: Commit, mem: tuple[int, int, int | None] | None) -> Commit:
    """Attach one memory access to a commit, or return it unchanged.

    ``mem`` is ``(addr, size, store data or None)`` for the instruction the model
    just executed. The masks use the RVFI lane convention (lanes of the window at
    ``addr & ~7``); a load marks ``rmask``, a store ``wmask``.
    """
    if mem is None:
        return commit
    addr, size, data = mem
    mask = _lane_mask(size, addr)
    if data is None:
        return replace(commit, mem_addr=addr, mem_rmask=mask, mem_wmask=0)
    return replace(commit, mem_addr=addr, mem_wdata=data, mem_rmask=0, mem_wmask=mask)


def _sext(value: int, bits: int) -> int:
    """Sign-extend the low ``bits`` of ``value``."""
    sign = 1 << (bits - 1)
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & sign else value


def _signed32(value: int) -> int:
    """The signed value of the low 32 bits."""
    return _sext(value & MASK32, 32)


def _bit(insn: int, index: int) -> int:
    """Bit ``index`` of ``insn``."""
    return (insn >> index) & 1


class SparseMemory:
    """Byte-addressable little-endian memory backed by 4 KiB pages.

    Sparse because the corpus lives near 0x8000_0000 and a dense array would be
    gigabytes; pages are allocated on first touch, exactly like Spike's memory
    map is sparse.
    """

    __slots__ = ("_pages",)

    def __init__(self) -> None:
        self._pages: dict[int, bytearray] = {}

    def _page_for_read(self, addr: int) -> bytearray | None:
        return self._pages.get((addr & MASK64) >> PAGE_BITS)

    def _page_for_write(self, addr: int) -> bytearray:
        index = (addr & MASK64) >> PAGE_BITS
        page = self._pages.get(index)
        if page is None:
            page = bytearray(PAGE_SIZE)
            self._pages[index] = page
        return page

    def read(self, addr: int, size: int) -> int:
        """Little-endian read of ``size`` bytes at ``addr`` (0 when never written)."""
        value = 0
        for offset in range(size):
            page = self._page_for_read(addr + offset)
            byte = 0 if page is None else page[(addr + offset) & PAGE_MASK]
            value |= byte << (8 * offset)
        return value

    def write(self, addr: int, size: int, value: int) -> None:
        """Little-endian write of the low ``size`` bytes of ``value`` at ``addr``."""
        for offset in range(size):
            page = self._page_for_write(addr + offset)
            page[(addr + offset) & PAGE_MASK] = (value >> (8 * offset)) & 0xFF

    def load(self, addr: int, data: bytes) -> None:
        """Write a byte string at ``addr`` (segment loading)."""
        for offset, byte in enumerate(data):
            page = self._page_for_write(addr + offset)
            page[(addr + offset) & PAGE_MASK] = byte


class Rv64ImcModel:
    """RV64IMC interpreter that emits one :class:`~rv_trace.Commit` per instruction."""

    def __init__(self, image: Image, *, max_commits: int = DEFAULT_MAX_COMMITS) -> None:
        self.image = image
        self.max_commits = max_commits
        self.x = [0] * 32
        self.pc = image.entry
        self.mem = SparseMemory()
        self.cycle = 0
        self.halt_reason: str | None = None
        self._halt = False
        self._mem: tuple[int, int, int | None] | None = None
        """``(addr, size, store data or None)`` of the instruction being executed."""
        for addr, data in image.segments:
            self.mem.load(addr, data)
        self.mem.write(image.tohost, 8, 0)

    # -- execution ---------------------------------------------------------

    def step(self) -> Commit:
        """Execute one instruction and return its commit record.

        The commit carries the instruction's memory access when it has one
        (C14 §5.2), in the same convention Spike's ``--log-commits`` uses: the
        exact address, the store data truncated to the access size (unshifted),
        and the byte-lane masks of the 8-byte-aligned window at ``addr & ~7``.
        """
        self._mem = None
        pc = self.pc
        half = self.mem.read(pc, 2)
        if half & 0b11 != 0b11:
            insn = half
            rd, value, next_pc = self._exec_compressed(insn, pc)
        else:
            insn = self.mem.read(pc, 4)
            rd, value, next_pc = self._exec_32(insn, pc)
        if rd is not None:
            value = 0 if value is None else value & MASK64
            if rd == 0:  # x0 is hard-wired zero (Commit drops the write as well)
                rd, value = None, None
            else:
                self.x[rd] = value
        self.pc = next_pc
        self.cycle += 1
        commit = Commit(cycle=self.cycle, pc=pc, rd=rd, value=value, insn=insn)
        return _with_mem_access(commit, self._mem)

    def run(self) -> Iterator[Commit]:
        """Yield commits until the program's ``tohost`` store (HTIF exit)."""
        while not self._halt and self.cycle < self.max_commits:
            yield self.step()
        if self._halt:
            return
        raise ModelError(
            f"program did not write tohost within {self.max_commits} commits "
            f"(last pc 0x{self.pc:016x}); raise max_commits if that is expected"
        )

    def trace(self) -> list[Commit]:
        """The whole commit trace as a list."""
        return list(self.run())

    def trace_text(self, *, generator: str | None = None) -> str:
        """The commit trace in canonical text form."""
        label = generator or f"rv_model {self.image.name}"
        return format_trace(self.trace(), generator=label)

    # -- memory helpers ----------------------------------------------------

    def _load(self, addr: int, size: int, signed: bool) -> int:
        self._mem = (addr, size, None)
        value = self.mem.read(addr, size)
        return _sext(value, size * 8) if signed else value

    def _store(self, addr: int, size: int, value: int) -> None:
        self._mem = (addr, size, value & ((1 << (size * 8)) - 1))
        self.mem.write(addr, size, value & ((1 << (size * 8)) - 1))
        tohost = self.image.tohost
        if tohost is not None and addr <= tohost < addr + size and self.mem.read(tohost, 8) != 0:
            self._halt = True
            self.halt_reason = "tohost"

    # -- RV64I/M (32-bit encodings) ---------------------------------------

    def _exec_32(self, insn: int, pc: int) -> tuple[int | None, int | None, int]:
        opcode = insn & 0x7F
        rd = (insn >> 7) & 0x1F
        funct3 = (insn >> 12) & 0x7
        rs1 = (insn >> 15) & 0x1F
        rs2 = (insn >> 20) & 0x1F
        funct7 = (insn >> 25) & 0x7F
        next_pc = (pc + 4) & MASK64
        if opcode == 0x37:  # LUI
            return rd, _sext(insn & 0xFFFFF000, 32), next_pc
        if opcode == 0x17:  # AUIPC
            return rd, (pc + _sext(insn & 0xFFFFF000, 32)) & MASK64, next_pc
        if opcode == 0x6F:  # JAL
            return rd, next_pc, (pc + self._imm_j(insn)) & MASK64
        if opcode == 0x67:  # JALR
            if funct3 != 0:
                raise UnsupportedInstruction(f"jalr funct3={funct3} at 0x{pc:016x}")
            target = (self.x[rs1] + _sext(insn >> 20, 12)) & MASK64 & ~1
            return rd, next_pc, target
        if opcode == 0x63:  # BRANCH
            taken = self._branch_taken(funct3, self.x[rs1], self.x[rs2], pc)
            return None, None, (pc + self._imm_b(insn)) & MASK64 if taken else next_pc
        if opcode == 0x03:  # LOAD
            return self._load_instr(insn, funct3, rd, rs1, pc)
        if opcode == 0x23:  # STORE
            self._exec_store(funct3, insn, rs1, rs2)
            return None, None, next_pc
        if opcode == 0x13:  # OP-IMM
            return rd, self._op_imm(insn, funct3, funct7, rs1, pc), next_pc
        if opcode == 0x1B:  # OP-IMM-32
            return rd, self._op_imm_32(insn, funct3, funct7, rs1, pc), next_pc
        if opcode == 0x33:  # OP
            return rd, self._op(insn, funct3, funct7, rs1, rs2, pc), next_pc
        if opcode == 0x3B:  # OP-32
            return rd, self._op_32(insn, funct3, funct7, rs1, rs2, pc), next_pc
        if opcode == 0x0F:  # MISC-MEM (fence / fence.i): no architectural effect
            return None, None, next_pc
        if opcode == 0x73:
            raise UnsupportedInstruction(
                f"SYSTEM instruction at 0x{pc:016x} (traps/CSRs are not modelled)"
            )
        raise UnsupportedInstruction(f"unsupported opcode 0x{opcode:02x} at 0x{pc:016x}")

    def _imm_i(self, insn: int) -> int:
        return _sext(insn >> 20, 12)

    def _imm_s(self, insn: int) -> int:
        return _sext(((insn >> 25) << 5) | ((insn >> 7) & 0x1F), 12)

    def _imm_b(self, insn: int) -> int:
        return _sext(
            (_bit(insn, 31) << 12)
            | (_bit(insn, 7) << 11)
            | (((insn >> 25) & 0x3F) << 5)
            | (((insn >> 8) & 0xF) << 1),
            13,
        )

    def _imm_j(self, insn: int) -> int:
        return _sext(
            (_bit(insn, 31) << 20)
            | (((insn >> 12) & 0xFF) << 12)
            | (_bit(insn, 20) << 11)
            | (((insn >> 21) & 0x3FF) << 1),
            21,
        )

    def _load_instr(
        self, insn: int, funct3: int, rd: int, rs1: int, pc: int
    ) -> tuple[int | None, int | None, int]:
        sizes = {0b000: (1, True), 0b001: (2, True), 0b010: (4, True), 0b011: (8, False),
                 0b100: (1, False), 0b101: (2, False), 0b110: (4, False)}
        if funct3 not in sizes:
            raise UnsupportedInstruction(f"load funct3={funct3} at 0x{pc:016x}")
        size, signed = sizes[funct3]
        addr = (self.x[rs1] + self._imm_i(insn)) & MASK64
        return rd, self._load(addr, size, signed), (pc + 4) & MASK64

    def _exec_store(self, funct3: int, insn: int, rs1: int, rs2: int) -> None:
        sizes = {0b000: 1, 0b001: 2, 0b010: 4, 0b011: 8}
        if funct3 not in sizes:
            raise UnsupportedInstruction(f"store funct3={funct3}")
        addr = (self.x[rs1] + self._imm_s(insn)) & MASK64
        self._store(addr, sizes[funct3], self.x[rs2])

    def _branch_taken(self, funct3: int, lhs: int, rhs: int, pc: int) -> bool:
        slt = _sext(lhs, 64) < _sext(rhs, 64)
        sltu = lhs < rhs
        table = {0b000: lhs == rhs, 0b001: lhs != rhs, 0b100: slt, 0b101: not slt,
                 0b110: sltu, 0b111: not sltu}
        if funct3 not in table:
            raise UnsupportedInstruction(f"branch funct3={funct3} at 0x{pc:016x}")
        return table[funct3]

    def _op_imm(self, insn: int, funct3: int, funct7: int, rs1: int, pc: int) -> int:
        lhs = self.x[rs1]
        imm = self._imm_i(insn)
        if funct3 == 0b000:
            return (lhs + imm) & MASK64
        if funct3 == 0b001:  # slli: shamt[5] lives in insn[25], insn[31:26] must be zero
            if funct7 >> 1:
                raise UnsupportedInstruction(f"slli with bad funct7 at 0x{pc:016x}")
            return (lhs << ((insn >> 20) & 0x3F)) & MASK64
        if funct3 == 0b010:
            return int(_sext(lhs, 64) < imm)
        if funct3 == 0b011:
            return int(lhs < (imm & MASK64))
        if funct3 == 0b100:
            return lhs ^ (imm & MASK64)
        if funct3 == 0b101:  # srli (funct7>>1 == 0) / srai (funct7>>1 == 0b010000)
            shamt = (insn >> 20) & 0x3F
            if funct7 >> 1 == 0b010000:
                return (_sext(lhs, 64) >> shamt) & MASK64
            if funct7 >> 1 == 0:
                return lhs >> shamt
            raise UnsupportedInstruction(f"srli/srai with bad funct7 at 0x{pc:016x}")
        if funct3 == 0b110:
            return lhs | (imm & MASK64)
        if funct3 == 0b111:
            return lhs & (imm & MASK64)
        raise UnsupportedInstruction(f"op-imm funct3={funct3} at 0x{pc:016x}")

    def _op_imm_32(self, insn: int, funct3: int, funct7: int, rs1: int, pc: int) -> int:
        lhs = self.x[rs1]
        if funct3 == 0b000:  # addiw
            return _sext((lhs + self._imm_i(insn)) & MASK32, 32) & MASK64
        if funct3 == 0b001:  # slliw: 5-bit shamt, so all of funct7 must be zero
            if funct7:
                raise UnsupportedInstruction(f"slliw with bad funct7 at 0x{pc:016x}")
            return _sext((lhs << ((insn >> 20) & 0x1F)) & MASK32, 32) & MASK64
        if funct3 == 0b101:  # srliw / sraiw
            shamt = (insn >> 20) & 0x1F
            if funct7 == 0b0100000:
                return _sext((_signed32(lhs) >> shamt) & MASK32, 32) & MASK64
            if funct7 == 0:
                return _sext((lhs & MASK32) >> shamt, 32) & MASK64
        raise UnsupportedInstruction(f"op-imm-32 funct3={funct3} at 0x{pc:016x}")

    def _op(self, insn: int, funct3: int, funct7: int, rs1: int, rs2: int, pc: int) -> int:
        lhs, rhs = self.x[rs1], self.x[rs2]
        if funct7 == 0b0000001:
            return self._m_op(funct3, lhs, rhs, pc)
        if funct7 not in (0b0000000, 0b0100000):
            raise UnsupportedInstruction(f"op funct3={funct3} funct7={funct7} at 0x{pc:016x}")
        if funct3 == 0b000:
            return (lhs + rhs) & MASK64 if funct7 == 0 else (lhs - rhs) & MASK64
        if funct3 == 0b001:
            if funct7:
                raise UnsupportedInstruction(f"sll with funct7=0x20 at 0x{pc:016x}")
            return (lhs << (rhs & 0x3F)) & MASK64
        if funct3 == 0b010:
            return int(_sext(lhs, 64) < _sext(rhs, 64))
        if funct3 == 0b011:
            return int(lhs < rhs)
        if funct3 == 0b100:
            return lhs ^ rhs
        if funct3 == 0b101:
            if funct7:
                return (_sext(lhs, 64) >> (rhs & 0x3F)) & MASK64
            return lhs >> (rhs & 0x3F)
        if funct3 == 0b110:
            return lhs | rhs
        if funct3 == 0b111:
            return lhs & rhs
        raise UnsupportedInstruction(f"op funct3={funct3} at 0x{pc:016x}")

    def _op_32(self, insn: int, funct3: int, funct7: int, rs1: int, rs2: int, pc: int) -> int:
        lhs, rhs = self.x[rs1], self.x[rs2]
        if funct7 == 0b0000001:
            return self._m_op_32(funct3, lhs, rhs, pc)
        if funct7 not in (0b0000000, 0b0100000):
            raise UnsupportedInstruction(f"op-32 funct3={funct3} funct7={funct7} at 0x{pc:016x}")
        if funct3 == 0b000:
            result = (lhs + rhs) & MASK32 if funct7 == 0 else (lhs - rhs) & MASK32
        elif funct3 == 0b001:
            if funct7:
                raise UnsupportedInstruction(f"sllw with funct7=0x20 at 0x{pc:016x}")
            result = (lhs << (rhs & 0x1F)) & MASK32
        elif funct3 == 0b101:
            if funct7:
                result = (_signed32(lhs) >> (rhs & 0x1F)) & MASK32
            else:
                result = (lhs & MASK32) >> (rhs & 0x1F)
        else:
            raise UnsupportedInstruction(f"op-32 funct3={funct3} at 0x{pc:016x}")
        return _sext(result, 32) & MASK64

    def _m_op(self, funct3: int, lhs: int, rhs: int, pc: int) -> int:
        if funct3 == 0b000:  # mul: low half
            return (lhs * rhs) & MASK64
        if funct3 == 0b001:  # mulh: high half, both operands signed
            return ((_sext(lhs, 64) * _sext(rhs, 64)) >> 64) & MASK64
        if funct3 == 0b010:  # mulhsu: high half, first signed / second unsigned
            return ((_sext(lhs, 64) * rhs) >> 64) & MASK64
        if funct3 == 0b011:  # mulhu: high half, both unsigned
            return ((lhs * rhs) >> 64) & MASK64
        if funct3 in (0b100, 0b110):
            quotient, remainder = self._div(_sext(lhs, 64), _sext(rhs, 64))
            return (quotient if funct3 == 0b100 else remainder) & MASK64
        if funct3 in (0b101, 0b111):
            quotient, remainder = self._div(lhs, rhs)
            return (quotient if funct3 == 0b101 else remainder) & MASK64
        raise UnsupportedInstruction(f"m-extension funct3={funct3} at 0x{pc:016x}")

    def _m_op_32(self, funct3: int, lhs: int, rhs: int, pc: int) -> int:
        lhs32, rhs32 = _signed32(lhs), _signed32(rhs)
        if funct3 == 0b000:
            return _sext((lhs * rhs) & MASK32, 32) & MASK64
        if funct3 in (0b100, 0b110):
            quotient, remainder = self._div(lhs32, rhs32)
            return _sext((quotient if funct3 == 0b100 else remainder) & MASK32, 32) & MASK64
        if funct3 in (0b101, 0b111):
            quotient, remainder = self._div(lhs & MASK32, rhs & MASK32)
            return _sext((quotient if funct3 == 0b101 else remainder) & MASK32, 32) & MASK64
        raise UnsupportedInstruction(f"m-extension-32 funct3={funct3} at 0x{pc:016x}")

    @staticmethod
    def _div(dividend: int, divisor: int) -> tuple[int, int]:
        """RISC-V division semantics, including divide-by-zero and overflow."""
        if divisor == 0:
            return -1, dividend
        quotient = abs(dividend) // abs(divisor)
        if (dividend < 0) != (divisor < 0):
            quotient = -quotient
        return quotient, dividend - quotient * divisor

    # -- RV64C (16-bit encodings) -----------------------------------------

    def _exec_compressed(self, insn: int, pc: int) -> tuple[int | None, int | None, int]:
        quadrant = insn & 0b11
        funct3 = (insn >> 13) & 0b111
        next_pc = (pc + 2) & MASK64
        rd = (insn >> 7) & 0x1F
        rs2 = (insn >> 2) & 0x1F
        prime_rd = 8 + ((insn >> 2) & 0b111)
        prime_rs1 = 8 + ((insn >> 7) & 0b111)
        if quadrant == 0b00:
            return self._exec_c0(insn, funct3, prime_rd, prime_rs1, pc)
        if quadrant == 0b01:
            return self._exec_c1(insn, funct3, rd, next_pc, pc)
        if quadrant == 0b10:
            return self._exec_c2(insn, funct3, rd, rs2, next_pc, pc)
        raise UnsupportedInstruction(f"compressed quadrant 3 at 0x{pc:016x}")

    def _exec_c0(
        self, insn: int, funct3: int, prime_rd: int, prime_rs1: int, pc: int
    ) -> tuple[int | None, int | None, int]:
        next_pc = (pc + 2) & MASK64
        if funct3 == 0b000:  # c.addi4spn
            imm = (
                ((insn >> 7) & 0x30)
                | ((insn >> 1) & 0x3C0)
                | ((insn >> 4) & 0x04)
                | ((insn >> 2) & 0x08)
            )
            if imm == 0:
                raise UnsupportedInstruction(f"c.addi4spn with zero immediate at 0x{pc:016x}")
            return prime_rd, (self.x[2] + imm) & MASK64, next_pc
        if funct3 == 0b010:  # c.lw
            addr = (self.x[prime_rs1] + self._c_lw_imm(insn)) & MASK64
            return prime_rd, self._load(addr, 4, True), next_pc
        if funct3 == 0b011:  # c.ld
            addr = (self.x[prime_rs1] + self._c_ld_imm(insn)) & MASK64
            return prime_rd, self._load(addr, 8, False), next_pc
        if funct3 == 0b110:  # c.sw
            addr = (self.x[prime_rs1] + self._c_lw_imm(insn)) & MASK64
            self._store(addr, 4, self.x[prime_rd])
            return None, None, next_pc
        if funct3 == 0b111:  # c.sd
            addr = (self.x[prime_rs1] + self._c_ld_imm(insn)) & MASK64
            self._store(addr, 8, self.x[prime_rd])
            return None, None, next_pc
        raise UnsupportedInstruction(
            f"compressed quadrant-0 funct3={funct3} at 0x{pc:016x} (floating point/reserved)"
        )

    def _exec_c1(
        self, insn: int, funct3: int, rd: int, next_pc: int, pc: int
    ) -> tuple[int | None, int | None, int]:
        prime_rd = 8 + ((insn >> 7) & 0b111)
        imm6 = _sext((_bit(insn, 12) << 5) | ((insn >> 2) & 0x1F), 6)
        if funct3 == 0b000:  # c.addi / c.nop
            return rd, (self.x[rd] + imm6) & MASK64, next_pc
        if funct3 == 0b001:  # c.addiw
            if rd == 0:
                raise UnsupportedInstruction(f"c.addiw rd=0 (reserved) at 0x{pc:016x}")
            return rd, _sext((self.x[rd] + imm6) & MASK32, 32) & MASK64, next_pc
        if funct3 == 0b010:  # c.li
            return rd, imm6 & MASK64, next_pc
        if funct3 == 0b011:
            if rd == 2:  # c.addi16sp: imm[9]=i12, imm[4]=i6, imm[8:7]=i4:3, imm[6]=i5, imm[5]=i2
                imm = (
                    (_bit(insn, 12) << 9)
                    | (_bit(insn, 6) << 4)
                    | (((insn >> 3) & 0b11) << 7)
                    | (_bit(insn, 5) << 6)
                    | (_bit(insn, 2) << 5)
                )
                return rd, (self.x[2] + _sext(imm, 10)) & MASK64, next_pc
            # c.lui: imm = sext(imm6) << 12 (rd = 0 is a hint, rd = 2 is c.addi16sp above)
            return rd, (imm6 << 12) & MASK64, next_pc
        if funct3 == 0b100:
            return self._exec_c1_alu(insn, prime_rd, imm6, pc)
        if funct3 in (0b101, 0b110, 0b111):  # c.j / c.beqz / c.bnez
            offset = self._c_j_imm(insn) if funct3 == 0b101 else self._c_b_imm(insn)
            taken = funct3 == 0b101
            if funct3 == 0b110:
                taken = self.x[prime_rd] == 0
            elif funct3 == 0b111:
                taken = self.x[prime_rd] != 0
            return None, None, (pc + offset) & MASK64 if taken else next_pc
        raise UnsupportedInstruction(f"compressed quadrant-1 funct3={funct3} at 0x{pc:016x}")

    def _exec_c1_alu(
        self, insn: int, prime_rd: int, imm6: int, pc: int
    ) -> tuple[int | None, int | None, int]:
        next_pc = (pc + 2) & MASK64
        funct2 = (insn >> 10) & 0b11
        prime_rs2 = 8 + ((insn >> 2) & 0b111)
        if funct2 == 0b00:  # c.srli: shamt[5] = insn[12]
            shamt = (_bit(insn, 12) << 5) | ((insn >> 2) & 0x1F)
            return prime_rd, self.x[prime_rd] >> shamt, next_pc
        if funct2 == 0b01:  # c.srai
            shamt = (_bit(insn, 12) << 5) | ((insn >> 2) & 0x1F)
            return prime_rd, (_sext(self.x[prime_rd], 64) >> shamt) & MASK64, next_pc
        if funct2 == 0b10:  # c.andi
            return prime_rd, self.x[prime_rd] & (imm6 & MASK64), next_pc
        lhs, rhs = self.x[prime_rd], self.x[prime_rs2]
        word = _bit(insn, 12)
        sub = (insn >> 5) & 0b11
        if not word:
            if sub == 0b00:  # c.sub
                return prime_rd, (lhs - rhs) & MASK64, next_pc
            if sub == 0b01:  # c.xor
                return prime_rd, lhs ^ rhs, next_pc
            if sub == 0b10:  # c.or
                return prime_rd, lhs | rhs, next_pc
            return prime_rd, lhs & rhs, next_pc  # c.and
        if sub == 0b00:  # c.subw
            return prime_rd, _sext((lhs - rhs) & MASK32, 32) & MASK64, next_pc
        if sub == 0b01:  # c.addw
            return prime_rd, _sext((lhs + rhs) & MASK32, 32) & MASK64, next_pc
        raise UnsupportedInstruction(f"compressed alu sub-op {word}/{sub} at 0x{pc:016x}")

    def _exec_c2(
        self, insn: int, funct3: int, rd: int, rs2: int, next_pc: int, pc: int
    ) -> tuple[int | None, int | None, int]:
        if funct3 == 0b000:  # c.slli: shamt[5] = insn[12]
            shamt = (_bit(insn, 12) << 5) | ((insn >> 2) & 0x1F)
            return rd, (self.x[rd] << shamt) & MASK64, next_pc
        if funct3 == 0b010:  # c.lwsp
            if rd == 0:
                raise UnsupportedInstruction(f"c.lwsp rd=0 (reserved) at 0x{pc:016x}")
            imm = (_bit(insn, 12) << 5) | (((insn >> 4) & 0b111) << 2) | (((insn >> 2) & 0b11) << 6)
            return rd, self._load((self.x[2] + imm) & MASK64, 4, True), next_pc
        if funct3 == 0b011:  # c.ldsp
            if rd == 0:
                raise UnsupportedInstruction(f"c.ldsp rd=0 (reserved) at 0x{pc:016x}")
            imm = (_bit(insn, 12) << 5) | (((insn >> 5) & 0b11) << 3) | (((insn >> 2) & 0b111) << 6)
            return rd, self._load((self.x[2] + imm) & MASK64, 8, False), next_pc
        if funct3 == 0b100:
            if _bit(insn, 12):
                if rs2 == 0 and rd == 0:
                    raise UnsupportedInstruction(f"c.ebreak at 0x{pc:016x}")
                if rs2 == 0:  # c.jalr
                    return 1, next_pc, self.x[rd] & MASK64
                return rd, (self.x[rd] + self.x[rs2]) & MASK64, next_pc  # c.add
            if rs2 == 0:  # c.jr
                if rd == 0:
                    raise UnsupportedInstruction(f"c.jr x0 (reserved) at 0x{pc:016x}")
                return None, None, self.x[rd] & MASK64
            return rd, self.x[rs2], next_pc  # c.mv
        if funct3 == 0b110:  # c.swsp
            imm = (((insn >> 9) & 0b1111) << 2) | (((insn >> 7) & 0b11) << 6)
            self._store((self.x[2] + imm) & MASK64, 4, self.x[rs2])
            return None, None, next_pc
        if funct3 == 0b111:  # c.sdsp
            imm = (((insn >> 10) & 0b111) << 3) | (((insn >> 7) & 0b111) << 6)
            self._store((self.x[2] + imm) & MASK64, 8, self.x[rs2])
            return None, None, next_pc
        raise UnsupportedInstruction(
            f"compressed quadrant-2 funct3={funct3} at 0x{pc:016x} (floating point)"
        )

    @staticmethod
    def _c_lw_imm(insn: int) -> int:
        return (_bit(insn, 5) << 6) | (((insn >> 10) & 0b111) << 3) | (_bit(insn, 6) << 2)

    @staticmethod
    def _c_ld_imm(insn: int) -> int:
        return (((insn >> 10) & 0b111) << 3) | (((insn >> 5) & 0b11) << 6)

    @staticmethod
    def _c_j_imm(insn: int) -> int:
        return _sext(
            (_bit(insn, 12) << 11)
            | (_bit(insn, 11) << 4)
            | (_bit(insn, 10) << 9)
            | (_bit(insn, 9) << 8)
            | (_bit(insn, 8) << 10)
            | (_bit(insn, 7) << 6)
            | (_bit(insn, 6) << 7)
            | (_bit(insn, 5) << 3)
            | (_bit(insn, 4) << 2)
            | (_bit(insn, 3) << 1)
            | (_bit(insn, 2) << 5),
            12,
        )

    @staticmethod
    def _c_b_imm(insn: int) -> int:
        return _sext(
            (_bit(insn, 12) << 8)
            | (((insn >> 10) & 0b11) << 3)
            | (((insn >> 5) & 0b11) << 6)
            | (((insn >> 3) & 0b11) << 1)
            | (_bit(insn, 2) << 5),
            9,
        )


def run_image(path: str | Path, *, max_commits: int = DEFAULT_MAX_COMMITS) -> list[Commit]:
    """Load an image and return its full commit trace (convenience entry point)."""
    model = Rv64ImcModel(load_image(path), max_commits=max_commits)
    return model.trace()


def trace_text_for_image(path: str | Path, *, max_commits: int = DEFAULT_MAX_COMMITS) -> str:
    """Load an image and return its commit trace in canonical text form."""
    image = load_image(path)
    model = Rv64ImcModel(image, max_commits=max_commits)
    return model.trace_text(generator=f"rv_model {image.name}")
