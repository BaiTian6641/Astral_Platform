# SPDX-License-Identifier: MIT
"""Canonical commit-trace format for the ``eth_rv`` DiffTest harness (S15 §2.2).

    # rv_difftest trace v2
    # generator: spike 1e05ddac (rv64imafdc_zicsr)
    # fields: cycle pc rd value [mem_addr mem_wdata [mem_rmask mem_wmask]] [fflags=0x.. frm=0x..]
    1 0x0000000080000000 x02 0x0000000080001000
    2 0x0000000080000004 - -
    3 0x0000000080000008 f1 0x3ff0000000000000 fflags=0x10
    4 0x000000008000000c x10 0x0000000000000013 0x0000000080001ff8 0x000000000000002a 0x00 0x08

Field semantics
  * ``cycle`` — commit ordinal of this instruction. Spike is not cycle-accurate,
    so the golden stream uses the retirement index (1-based); a DUT that knows
    its real commit cycles (an RTL testbench) may put those there instead and the
    comparator will check them (``--no-cycle-check`` to relax).
  * ``pc``    — 64-bit program counter of the retired instruction.
  * ``rd``    — ``x0``..``x31`` (or an ABI name: ``a0``, ``sp`` …) when the
    instruction writes an integer architectural register, ``f0``..``f31`` when it
    writes a floating-point one, ``-`` when it does not (stores, branches,
    ``jal x0`` …).  Writes to ``x0`` are dropped — x0 is hard-wired zero in
    RISC-V, so logging them is meaningless, and Spike does not log them either.
    ``f0`` is a real register, so an FP write to index 0 is **kept** (only ``x0``
    is dropped).
  * ``value`` — 64-bit value written to ``rd`` (for an FP write: the raw,
    already NaN-boxed register value); ``-`` when ``rd`` is ``-``.
  * ``mem_addr`` / ``mem_wdata`` — the memory access of the retired
    instruction, in the golden model's own convention (Spike's
    ``--log-commits`` ``mem <addr> [<data>]`` field, C14 §5.2): the exact byte
    address, and for a store the *low* ``size`` bytes of the stored register
    (unshifted, size-truncated). ``-``/``-`` means "no memory access"; a load
    carries an address but ``mem_wdata`` is ``-``.
  * an **A-extension AMO** (``amoadd.w`` …) is one architectural memory access
    that reads and writes the same address, and it is reported as its **write**:
    ``mem_addr``/``mem_wdata`` are the address and the value stored back, and the
    old value is in ``rd`` (the instruction's destination). Spike logs such an
    instruction as two ``mem`` fields — the read of the old value, then the write
    of the result — and the golden normalizer keeps the second one, so both sides
    of a DiffTest agree on the single-access record without a format version
    change (see ``rv_spike.iter_spike_commits`` and verif/eth_rv/README.md). An
    ``lr`` reports its read, an ``sc`` that stores reports its write, and an ``sc``
    whose reservation was lost reports **no** memory access at all.
  * ``mem_rmask`` / ``mem_wmask`` — byte lanes of the 8-byte-aligned window at
    ``mem_addr & ~7`` that the access reads/writes (the RVFI convention), or
    ``-`` when the producer does not report masks. Spike has no mask field, so
    the golden stream leaves them ``-``; a DUT that reports them gets them
    cross-checked against the golden's load/store direction and for internal
    consistency (``rv_difftest``).

The memory suffix is **optional and variable width**: a 4-field line carries no
memory information at all, a 6-field line adds ``mem_addr mem_wdata`` and an
8-field line adds the two masks. A stream that never carries memory information
is still compared on ``pc``/``rd``/``value``, and the comparison reports the
memory stream as "not provided" instead of silently passing it. Note that
``mem_addr`` present with ``-`` for every other memory field means "this commit
has no memory access", which is different from a 4-field line only at the
stream level (a *producer* that knows about memory vs one that does not) — see
:func:`stream_has_mem_info`.

The FP record is **optional and keyed**: an FP register write uses the ``f<d>``
``rd`` class, and the FP control state an instruction wrote is appended *after*
the positional fields as ``fflags=0x..`` (5 bits) then ``frm=0x..`` (3 bits). A
``csrw fflags`` writes no register, so a keyed field may appear on a ``- -``
commit. Keyed tokens are the only place a line contains ``=``, so the parser
splits every ``=``-bearing token out of the line first and the positional
3/4/6/8-field grammar is untouched. The header is ``v2`` once a stream carries FP
state and ``v1`` otherwise; both count as canonical
(:func:`is_canonical_trace`), and a v1 stream simply has no FP record (see
:func:`stream_has_fp_info`).

A *lenient* 3-field line (``pc rd value``) is also accepted on the DUT side, with
``cycle`` taken from the line ordinal. That is the shape a hand-written Verilator
testbench ``$fwrite`` naturally produces (see ``--dut dump:``). Lines are
``#``-commented, blank lines are skipped.
"""
from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, replace
from pathlib import Path

TRACE_HEADER_PREFIX = "# rv_difftest trace v1"
"""First line of a canonical (normalized) trace file."""

TRACE_HEADER_V2 = "# rv_difftest trace v2"
"""Canonical header of a stream that carries FP state (``f<d>`` rd or keyed tokens)."""

TRACE_HEADERS = (TRACE_HEADER_PREFIX, TRACE_HEADER_V2)
"""Headers :func:`is_canonical_trace` accepts (a v1 stream simply has no FP record)."""

XLEN = 64
"""Trace values are 64-bit (RV64)."""

REG_BITS = 5
"""Register index width: 32 integer registers and 32 floating-point registers."""

FFLAGS_BITS = 5
"""``fflags`` carries 5 exception-flag bits (NV DZ OF UF NX)."""

FRM_BITS = 3
"""``frm`` carries 3 rounding-mode bits."""

_KEYED_BITS: dict[str, int] = {"fflags": FFLAGS_BITS, "frm": FRM_BITS}
"""Keyed (``name=value``) trace tokens and the width of the field each one carries."""

_ABI_NAMES: dict[str, int] = {
    "zero": 0,
    "ra": 1,
    "sp": 2,
    "gp": 3,
    "tp": 4,
    "t0": 5,
    "t1": 6,
    "t2": 7,
    "s0": 8,
    "fp": 8,
    "s1": 9,
    "a0": 10,
    "a1": 11,
    "a2": 12,
    "a3": 13,
    "a4": 14,
    "a5": 15,
    "a6": 16,
    "a7": 17,
    "s2": 18,
    "s3": 19,
    "s4": 20,
    "s5": 21,
    "s6": 22,
    "s7": 23,
    "s8": 24,
    "s9": 25,
    "s10": 26,
    "s11": 27,
    "t3": 28,
    "t4": 29,
    "t5": 30,
    "t6": 31,
}
"""ABI register names accepted by :func:`parse_reg` (the RTL adapter sees these)."""

NO_WRITE = "-"
"""Field place-holder for "this instruction wrote no register"."""


class TraceFormatError(ValueError):
    """A trace line does not follow the canonical format (or cannot be).

    The message always carries the source and 1-based line number so that a
    harness run against a malformed DUT dump fails loudly at the offending line.
    """

    def __init__(self, message: str, *, source: str, line: int | None = None) -> None:
        self.message = message
        self.source = source
        self.line = line
        where = source if line is None else f"{source}:{line}"
        super().__init__(f"{where}: {message}")


@dataclass(frozen=True, slots=True, eq=True)
class Commit:
    """One retired instruction: the unit of comparison between golden and DUT.

    ``insn`` is the raw instruction word when the producer knows it (Spike does);
    it is informational only — the comparator never looks at it, so DUTs that do
    not expose instruction bits (e.g. a ``pc rd value`` dump) stay compatible.

    ``mem_addr``/``mem_wdata``/``mem_rmask``/``mem_wmask`` are the optional memory
    access of the commit (C14 §5.2). An all-``None`` commit is a commit without
    memory information *and* a commit that performs no memory access — the two
    are distinguished at the stream level by :func:`stream_has_mem_info`.
    ``mem_addr`` is the exact byte address; ``mem_wdata`` the store data in the
    golden convention (low ``size`` bytes, unshifted); the masks are byte lanes of
    the window at ``mem_addr & ~7``.

    ``rd_is_fp`` selects the register class ``rd`` names (``f<rd>`` instead of
    ``x<rd>``); an FP write to index 0 is a real update (``f0``), so only ``x0`` is
    dropped. ``fflags``/``frm`` are the FP control state the instruction wrote
    (the new full value of the CSR, 5 and 3 bits), or ``None`` when it wrote
    neither — they are the keyed ``fflags=0x..``/``frm=0x..`` trace tokens, and
    like the memory suffix they make FP awareness a *stream* property
    (:func:`stream_has_fp_info`).
    """

    cycle: int
    pc: int
    rd: int | None = None
    value: int | None = None
    insn: int | None = None
    mem_addr: int | None = None
    mem_wdata: int | None = None
    mem_rmask: int | None = None
    mem_wmask: int | None = None
    rd_is_fp: bool = False
    fflags: int | None = None
    frm: int | None = None

    def __post_init__(self) -> None:
        if self.cycle < 1:
            raise ValueError(f"commit cycle must be >= 1, got {self.cycle}")
        _check_word(self.pc, "pc")
        if self.insn is not None:
            _check_word(self.insn, "insn", bits=32)
        if self.rd is None:
            if self.value is not None:
                raise ValueError("commit with no rd must not carry a value")
        else:
            if not 0 <= self.rd < (1 << REG_BITS):
                raise ValueError(f"register index out of range: {self.rd}")
            if self.rd == 0 and not self.rd_is_fp:
                # x0 is hard-wired zero: a logged x0 write is not a register
                # update. Drop it here so no producer can inject a phantom diff.
                # f0 is a real register, so an FP write to index 0 is kept.
                object.__setattr__(self, "rd", None)
                object.__setattr__(self, "value", None)
            elif self.value is None:
                raise ValueError("commit that writes a register must carry a value")
            else:
                _check_word(self.value, "value")
        if self.fflags is not None:
            _check_word(self.fflags, "fflags", bits=FFLAGS_BITS)
        if self.frm is not None:
            _check_word(self.frm, "frm", bits=FRM_BITS)
        if self.mem_addr is None:
            for name in ("mem_wdata", "mem_rmask", "mem_wmask"):
                if getattr(self, name) is not None:
                    raise ValueError(f"commit with no mem_addr must not carry {name}")
            return
        _check_word(self.mem_addr, "mem_addr")
        if self.mem_wdata is not None:
            _check_word(self.mem_wdata, "mem_wdata")
        for name in ("mem_rmask", "mem_wmask"):
            mask = getattr(self, name)
            if mask is not None and not 0 <= mask < (1 << 8):
                raise ValueError(f"{name} does not fit in 8 bits: {mask!r}")
        if self.mem_rmask is not None and self.mem_wmask is not None:
            # One instruction is either a load or a store, so only one of the two
            # directions may mark bytes; 0 is the "not this direction" value.
            if self.mem_rmask and self.mem_wmask:
                raise ValueError(
                    "a memory access cannot be both a load and a store "
                    f"(rmask {self.mem_rmask:#04x}, wmask {self.mem_wmask:#04x})"
                )
            if not (self.mem_rmask | self.mem_wmask):
                raise ValueError("a memory access must mark at least one byte")

    @property
    def has_mem_access(self) -> bool:
        """True when this commit retires a load or a store."""
        return self.mem_addr is not None

    @property
    def has_mem_masks(self) -> bool:
        """True when this commit carries the byte-lane masks (DUT-side detail)."""
        return self.mem_rmask is not None or self.mem_wmask is not None

    @property
    def has_fp_info(self) -> bool:
        """True when this commit carries FP state (an FP write or a keyed CSR update)."""
        return self.rd_is_fp or self.fflags is not None or self.frm is not None

    @property
    def writes_register(self) -> bool:
        """True when this commit updates an architectural register (rd != x0)."""
        return self.rd is not None

    @property
    def reg_name(self) -> str:
        """``rd`` as ``x<i>``/``f<i>`` text, or :data:`NO_WRITE`."""
        return format_reg(self.rd, is_fp=self.rd_is_fp)

    @property
    def value_text(self) -> str:
        """``value`` as 64-bit hex text, or :data:`NO_WRITE`."""
        return NO_WRITE if self.value is None else f"0x{self.value:016x}"

    def format_line(self) -> str:
        """This commit as one canonical trace line (no trailing newline).

        The memory suffix is omitted entirely for a commit without memory
        information, so a producer that knows nothing about memory keeps
        emitting the 4-field line; the keyed FP control state is appended after
        the memory suffix (``fflags`` before ``frm``).
        """
        fields = [f"{self.cycle} 0x{self.pc:016x} {self.reg_name} {self.value_text}"]
        mem = self._mem_text()
        if mem is not None:
            fields.append(mem)
        keyed = self._keyed_text()
        if keyed is not None:
            fields.append(keyed)
        return " ".join(fields)

    def _mem_text(self) -> str | None:
        """The memory suffix of a trace line, or ``None`` when there is none."""
        if not self.has_mem_access and not self.has_mem_masks:
            return None
        addr = NO_WRITE if self.mem_addr is None else f"0x{self.mem_addr:016x}"
        wdata = NO_WRITE if self.mem_wdata is None else f"0x{self.mem_wdata:016x}"
        if not self.has_mem_masks:
            return f"{addr} {wdata}"
        rmask = NO_WRITE if self.mem_rmask is None else f"0x{self.mem_rmask:02x}"
        wmask = NO_WRITE if self.mem_wmask is None else f"0x{self.mem_wmask:02x}"
        return f"{addr} {wdata} {rmask} {wmask}"

    def _keyed_text(self) -> str | None:
        """The ``fflags=0x..``/``frm=0x..`` keyed tokens of a trace line, or ``None``."""
        tokens = []
        if self.fflags is not None:
            tokens.append(f"fflags=0x{self.fflags:02x}")
        if self.frm is not None:
            tokens.append(f"frm=0x{self.frm:02x}")
        return None if not tokens else " ".join(tokens)

    def with_value(self, value: int) -> Commit:
        """A copy of this commit whose register value is ``value``."""
        if self.rd is None:
            return self
        return replace(self, value=value)

    def with_pc(self, pc: int) -> Commit:
        """A copy of this commit at ``pc`` (value/flags unchanged)."""
        return replace(self, pc=pc)

    def with_rd(self, rd: int) -> Commit:
        """A copy of this commit writing register ``rd`` (x0 -> no write).

        A commit that had no architectural write has no value to keep, so the
        invented write carries 0 — enough for the comparator to report the
        register-number divergence, which is what a fault injection is after.
        """
        if rd == 0:
            # x0 is dropped again, so the commit is back to no architectural
            # write — and therefore not an FP write either (class included).
            return replace(self, rd=None, value=None, rd_is_fp=False)
        value = 0 if self.value is None else self.value
        return replace(self, rd=rd, value=value)

    def with_cycle(self, cycle: int) -> Commit:
        """A copy of this commit at cycle ``cycle``."""
        return replace(self, cycle=cycle)

    def with_mem_addr(self, addr: int) -> Commit:
        """A copy of this commit at memory address ``addr``."""
        return replace(self, mem_addr=addr)

    def with_mem_wdata(self, wdata: int) -> Commit:
        """A copy of this commit storing ``wdata``."""
        if self.mem_addr is None:
            return self
        return replace(self, mem_wdata=wdata)

    def with_mem_rmask(self, mask: int) -> Commit:
        """A copy of this commit whose memory access reads ``mask`` lanes.

        The write mask is cleared: an access is a load or a store, never both.
        """
        if self.mem_addr is None:
            return self
        return replace(self, mem_rmask=mask, mem_wmask=None)

    def with_mem_wmask(self, mask: int) -> Commit:
        """A copy of this commit whose memory access writes ``mask`` lanes.

        The read mask is cleared: an access is a load or a store, never both.
        """
        if self.mem_addr is None:
            return self
        return replace(self, mem_wmask=mask, mem_rmask=None)


def _check_word(value: int, what: str, *, bits: int = XLEN) -> None:
    if not 0 <= value < (1 << bits):
        raise ValueError(f"{what} does not fit in {bits} bits: {value!r}")


def format_reg(rd: int | None, *, is_fp: bool = False) -> str:
    """Render a register index as trace text (``x7``/``f7``), or ``-`` for no write."""
    if rd is None:
        return NO_WRITE
    return f"{'f' if is_fp else 'x'}{rd}"


def parse_reg_field(token: str) -> tuple[int | None, bool]:
    """Parse a register field into ``(index, is_fp)``.

    ``x7``/``x 7``/``a0``/``sp``… -> ``(7, False)``, ``f7``/``f 7`` -> ``(7, True)``,
    ``-`` -> ``(None, False)``. Raises :class:`ValueError` for garbage (callers
    wrap it with source/line context).
    """
    text = token.strip().lower()
    if text == NO_WRITE:
        return None, False
    if text in _ABI_NAMES:
        return _ABI_NAMES[text], False
    for prefix, is_fp in (("x", False), ("f", True)):
        if not text.startswith(prefix):
            continue
        digits = text[1:].strip()
        if digits.isdigit():
            index = int(digits)
            if 0 <= index < (1 << REG_BITS):
                return index, is_fp
            raise ValueError(f"register index out of range: {token!r}")
    raise ValueError(f"not a register: {token!r}")


def parse_reg(token: str) -> int | None:
    """Parse a register field: ``x7``, ``f7``, ``x 7``, ``a0``/``sp``… or ``-``.

    Returns ``None`` for :data:`NO_WRITE`. The register *class* is not part of the
    return value; :func:`parse_reg_field` is the parser the trace itself uses.
    """
    return parse_reg_field(token)[0]


def is_reg_token(token: str) -> bool:
    """True when ``token`` is a syntactically valid register field."""
    try:
        parse_reg_field(token)
    except ValueError:
        return False
    return True


def parse_word(token: str, *, bits: int = XLEN) -> int:
    """Parse an unsigned decimal/hex word that must fit in ``bits``."""
    text = token.strip().lower()
    try:
        value = int(text, 16) if text.startswith("0x") else int(text, 10)
    except ValueError:
        raise ValueError(f"not a number: {token!r}") from None
    _check_word(value, "value", bits=bits)
    return value


def parse_trace(
    text: str,
    *,
    source: str = "<text>",
    implicit_cycle: bool = True,
) -> list[Commit]:
    """Parse trace text into commits.

    ``pc rd value`` lines (3 fields) are accepted when ``implicit_cycle`` is set;
    their cycle is the 1-based line ordinal of the commit. Explicit cycles must be
    non-decreasing. ``insn`` is never parsed from text — only from Spike logs.

    A line may carry the optional memory suffix: 6 fields add ``mem_addr
    mem_wdata`` and 8 fields add the two byte-lane masks (see the module
    docstring). ``-`` means "absent": a ``-`` address is a commit without a memory
    access, a ``-`` data field is a load, and ``-`` masks mean the producer does
    not report them. The memory suffix always requires an explicit cycle — a
    lenient (cycle-implicit) line is exactly 3 fields.

    Keyed tokens (``fflags=0x..`` / ``frm=0x..``) are split out of the line before
    the positional parse, so the field-count grammar above is unchanged; an
    ``f<d>`` ``rd`` field marks a floating-point register write.
    """
    commits: list[Commit] = []
    last_cycle = 0
    for lineno, raw in enumerate(text.splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        tokens = line.split()
        keyed = [token for token in tokens if "=" in token]
        fields = [token for token in tokens if "=" not in token]
        if len(fields) not in (3, 4, 6, 8):
            raise TraceFormatError(
                "expected 3 (<pc> <rd> <value>), 4 (<cycle> <pc> <rd> <value>), "
                "6 (+ <mem_addr> <mem_wdata>) or 8 (+ <mem_rmask> <mem_wmask>) fields, "
                f"got {len(fields)}: {line!r}",
                source=source,
                line=lineno,
            )
        if len(fields) >= 4:
            cycle = _word(fields[0], source=source, line=lineno, what="cycle")
            if cycle < 1:
                raise TraceFormatError(
                    f"cycle must be >= 1, got {cycle}", source=source, line=lineno
                )
            if cycle < last_cycle:
                raise TraceFormatError(
                    f"cycle {cycle} goes backwards (previous {last_cycle})",
                    source=source,
                    line=lineno,
                )
            last_cycle = cycle
            pc_token, rd_token, value_token = fields[1], fields[2], fields[3]
        else:
            if not implicit_cycle:
                raise TraceFormatError(
                    "expected 4 fields (<cycle> <pc> <rd> <value>); a DUT dump must "
                    "produce explicit cycles in this mode",
                    source=source,
                    line=lineno,
                )
            cycle = len(commits) + 1
            last_cycle = cycle
            pc_token, rd_token, value_token = fields[0], fields[1], fields[2]
        if not is_reg_token(rd_token):
            raise TraceFormatError(
                f"field {3 if len(fields) >= 4 else 2} is not a register: {rd_token!r}",
                source=source,
                line=lineno,
            )
        mem_tokens = fields[4:] if len(fields) >= 6 else []
        try:
            pc = parse_word(pc_token, bits=XLEN)
            rd, rd_is_fp = parse_reg_field(rd_token)
            value = None if value_token.strip() == NO_WRITE else parse_word(value_token)
            mem_addr, mem_wdata, mem_rmask, mem_wmask = _mem_fields(mem_tokens)
            fflags, frm = _keyed_fields(keyed)
        except ValueError as exc:
            raise TraceFormatError(str(exc), source=source, line=lineno) from None
        if rd is None and value is not None:
            raise TraceFormatError(
                f"value {value_token!r} given for a commit without a register write",
                source=source,
                line=lineno,
            )
        try:
            commits.append(
                Commit(
                    cycle=cycle,
                    pc=pc,
                    rd=rd,
                    value=value,
                    mem_addr=mem_addr,
                    mem_wdata=mem_wdata,
                    mem_rmask=mem_rmask,
                    mem_wmask=mem_wmask,
                    rd_is_fp=rd_is_fp,
                    fflags=fflags,
                    frm=frm,
                )
            )
        except ValueError as exc:  # pragma: no cover - defensive; fields are checked above
            raise TraceFormatError(str(exc), source=source, line=lineno) from None
    return commits


def parse_trace_file(path: str | Path, *, implicit_cycle: bool = True) -> list[Commit]:
    """Read and parse a trace file (see :func:`parse_trace`)."""
    trace_path = Path(path)
    try:
        text = trace_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise TraceFormatError(f"cannot read trace: {exc}", source=str(trace_path)) from None
    return parse_trace(text, source=str(trace_path), implicit_cycle=implicit_cycle)


def _word(token: str, *, source: str, line: int, what: str) -> int:
    try:
        return parse_word(token)
    except ValueError as exc:
        raise TraceFormatError(f"{what}: {exc}", source=source, line=line) from None


def format_trace(
    commits: Iterable[Commit],
    *,
    generator: str | None = None,
    note: str | None = None,
) -> str:
    """Serialize commits as a canonical trace file (header + one line each).

    The header is v2 once any commit carries FP state and v1 otherwise (a v1
    stream has no FP record by definition). Commits that carry no memory
    information stay 4-field lines; a memory access adds ``mem_addr mem_wdata``
    and, when the masks are known, ``mem_rmask mem_wmask``; the FP control state
    an instruction wrote is appended as the keyed ``fflags=0x.. frm=0x..`` tokens.
    """
    stream = list(commits)
    header = [TRACE_HEADER_V2 if stream_has_fp_info(stream) else TRACE_HEADER_PREFIX]
    if generator is not None:
        header.append(f"# generator: {generator}")
    header.append(
        "# fields: cycle pc rd value [mem_addr mem_wdata [mem_rmask mem_wmask]] "
        "[fflags=0x.. frm=0x..]"
    )
    header.append(
        f"# {NO_WRITE} in rd = retired without an architectural register write; "
        "f<d> = a floating-point register write (f0 included)"
    )
    header.append(
        f"# {NO_WRITE} in mem_addr = no memory access; {NO_WRITE} in mem_wdata = a load; "
        f"{NO_WRITE} masks = the producer does not report byte lanes"
    )
    header.append(
        "# keyed fflags=/frm= (after the memory suffix) = the FP control state this "
        "instruction wrote (5 / 3 bits)"
    )
    if note is not None:
        for line in note.splitlines():
            header.append(f"# {line}")
    body = [commit.format_line() for commit in stream]
    return "\n".join([*header, *body]) + "\n"


def _keyed_fields(tokens: list[str]) -> tuple[int | None, int | None]:
    """Parse a trace line's keyed tokens into ``(fflags, frm)``.

    ``[]`` -> ``(None, None)``; ``fflags=0x..`` / ``frm=0x..`` -> the value of the
    matching field (each parsed at its own width). Raises :class:`ValueError` for
    an unknown key, a repeated key or garbage; the caller adds the source/line
    context.
    """
    found: dict[str, int] = {}
    for token in tokens:
        name, _, text = token.partition("=")
        key = name.strip().lower()
        bits = _KEYED_BITS.get(key)
        if bits is None:
            raise ValueError(f"unknown keyed field: {token!r}")
        if key in found:
            raise ValueError(f"keyed field {key!r} given more than once")
        found[key] = parse_word(text, bits=bits)
    return found.get("fflags"), found.get("frm")


def _mem_fields(
    tokens: list[str],
) -> tuple[int | None, int | None, int | None, int | None]:
    """Parse a trace line's optional memory suffix into ``(addr, wdata, rmask, wmask)``.

    ``[]`` -> no memory information at all; 2 tokens -> ``addr wdata``; 4 tokens ->
    the byte-lane masks as well. ``-`` means "absent". Raises :class:`ValueError`
    for garbage or for data/masks without an address; the caller adds the
    source/line context.
    """
    if not tokens:
        return None, None, None, None
    if len(tokens) not in (2, 4):  # pragma: no cover - the line parser guards the width
        raise ValueError(f"expected 2 or 4 memory fields, got {len(tokens)}")
    parsed: list[int | None] = []
    for index, token in enumerate(tokens):
        if token.strip() == NO_WRITE:
            parsed.append(None)
        else:
            parsed.append(parse_word(token, bits=8 if index >= 2 else XLEN))
    if parsed[0] is None and any(item is not None for item in parsed[1:]):
        raise ValueError(f"memory data {tokens[1:]!r} given without a mem_addr")
    if len(parsed) == 2:
        return parsed[0], parsed[1], None, None
    return parsed[0], parsed[1], parsed[2], parsed[3]


def stream_has_mem_info(commits: Iterable[Commit]) -> bool:
    """True when a commit stream reports its memory accesses (C14 §5.2).

    The trace format cannot mark a single commit as "memory-aware but idle" — an
    idle commit is all-``-`` and therefore indistinguishable from a 4-field
    (memory-less) line. Awareness is a *stream* property: a producer that knows
    about memory reports the accesses it performs, and every corpus program
    performs at least the HTIF exit store, so "any commit with a memory access"
    is a reliable and honest test. A producer that does not report memory at all
    yields ``False`` and the comparator reports the memory stream as not provided
    instead of silently passing it.
    """
    return any(commit.has_mem_access for commit in commits)


def stream_has_fp_info(commits: Iterable[Commit]) -> bool:
    """True when a commit stream reports FP state (an FP write or a keyed update).

    Mirrors :func:`stream_has_mem_info` (the FP record is keyed and optional, so a
    stream that never carries it is indistinguishable from a pre-FP producer at
    the commit level). A stream without any FP record yields ``False`` and the
    comparator reports the FP record as *not provided* instead of silently passing
    it; only two FP-aware streams are compared field by field.
    """
    return any(commit.has_fp_info for commit in commits)


def is_canonical_trace(text: str) -> bool:
    """True when ``text`` starts with a canonical trace header (v1 or v2)."""
    for raw in text.splitlines():
        if not raw.strip():
            continue
        return raw.startswith(TRACE_HEADERS)
    return False
