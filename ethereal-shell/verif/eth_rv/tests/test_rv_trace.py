# SPDX-License-Identifier: MIT
"""Tests for the canonical trace format (:mod:`rv_trace`).

The format is the contract between the golden generator, the DUT adapters and
the comparator, so these tests pin the wire format, the lenient DUT-side dialect
and — most importantly — that malformed input fails loudly with a line number
instead of silently producing a short/empty trace.
"""
from __future__ import annotations

from pathlib import Path

import pytest
from rv_trace import (
    TRACE_HEADER_PREFIX,
    Commit,
    TraceFormatError,
    format_trace,
    is_canonical_trace,
    parse_reg,
    parse_trace,
    parse_trace_file,
)


def test_round_trip_preserves_every_field() -> None:
    commits = [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000),
        Commit(cycle=2, pc=0x8000_0004),
        Commit(cycle=3, pc=0x8000_0008, rd=31, value=0xFFFF_FFFF_FFFF_FFFF),
    ]
    text = format_trace(commits, generator="unit-test")
    assert text.startswith(TRACE_HEADER_PREFIX)
    assert is_canonical_trace(text)
    assert parse_trace(text) == commits


def test_canonical_line_layout() -> None:
    text = format_trace([Commit(cycle=7, pc=0x8000_0024, rd=8, value=0x2C)])
    body = [line for line in text.splitlines() if not line.startswith("#")]
    assert body == ["7 0x0000000080000024 x8 0x000000000000002c"]


def test_no_write_commit_renders_dashes() -> None:
    text = format_trace([Commit(cycle=1, pc=0x1000)])
    assert text.splitlines()[-1] == "1 0x0000000000001000 - -"


def test_x0_writes_are_dropped() -> None:
    """RISC-V x0 is hard-wired zero: logging a write to it is not an architectural update."""
    commit = Commit(cycle=1, pc=0x1000, rd=0, value=0xDEAD)
    assert commit.rd is None
    assert commit.value is None
    assert not commit.writes_register


def test_bare_pc_rd_value_dump_gets_ordinal_cycles() -> None:
    """The shape a hand-written Verilator testbench `$fwrite` produces."""
    commits = parse_trace("0x80000000 a0 0x7\n0x80000004 sp 0x8000a000\n")
    assert commits == [
        Commit(cycle=1, pc=0x8000_0000, rd=10, value=7),
        Commit(cycle=2, pc=0x8000_0004, rd=2, value=0x8000_A000),
    ]


def test_bare_dump_can_be_rejected() -> None:
    with pytest.raises(TraceFormatError, match="expected 4 fields"):
        parse_trace("0x80000000 a0 0x7\n", implicit_cycle=False)


def test_comments_trailing_whitespace_and_blank_lines() -> None:
    text = """
    # a comment
    1 0x80000000 x2 0x8000a000   # trailing note

    2 0x80000004 -            -
    """
    assert parse_trace(text) == [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000),
        Commit(cycle=2, pc=0x8000_0004),
    ]


def test_decimal_and_upper_case_hex_are_accepted() -> None:
    commits = parse_trace("1 2147483648 X2 0X8000A000\n")
    assert commits == [Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000)]


@pytest.mark.parametrize(
    ("text", "line", "expected"),
    [
        ("1 0x80000000 x2 0x1 0x2\n", 1, "expected 3 .* or 4 .* fields, got 5"),
        ("1 0xzzzz x2 0x1\n", 1, "not a number"),
        ("1 0x80000000 q7 0x1\n", 1, "is not a register"),
        ("1 0x80000000 - 0x1\n", 1, "without a register write"),
        ("0 0x80000000 x2 0x1\n", 1, "cycle must be >= 1"),
        ("0x80000000 x2\n", 1, "expected 3 .* or 4 .* fields, got 2"),
        ("1 0x80000000 x32 0x1\n", 1, "is not a register"),
        ("1 0x80000000 x2 0x1\n\n3 0xzzzz x2 0x1\n", 3, "not a number"),
        ("1 0x80000000 x2 0x1\n3 0x80000004 x2 0x1\n2 0x80000008 x2 0x1\n", 3, "goes backwards"),
    ],
)
def test_malformed_lines_report_the_offending_line(text: str, line: int, expected: str) -> None:
    with pytest.raises(TraceFormatError, match=expected) as excinfo:
        parse_trace(text, source="dut.dump")
    assert excinfo.value.source == "dut.dump"
    assert excinfo.value.line == line
    assert str(excinfo.value).startswith(f"dut.dump:{line}: ")


def test_missing_file_is_a_trace_error(tmp_path: Path) -> None:
    with pytest.raises(TraceFormatError, match="cannot read trace"):
        parse_trace_file(tmp_path / "nope.trace")


@pytest.mark.parametrize(
    ("token", "expected"),
    [("x0", 0), ("x31", 31), ("X 5", 5), ("a0", 10), ("sp", 2), ("fp", 8), ("t6", 31), ("-", None)],
)
def test_register_field_parsing(token: str, expected: int | None) -> None:
    assert parse_reg(token) == expected


@pytest.mark.parametrize("token", ["", "x32", "x", "w5", "v0", "--", "a9"])
def test_register_field_rejects_garbage(token: str) -> None:
    with pytest.raises(ValueError, match="not a register|out of range"):
        parse_reg(token)


def test_commit_validation() -> None:
    with pytest.raises(ValueError, match="cycle must be >= 1"):
        Commit(cycle=0, pc=0)
    with pytest.raises(ValueError, match="must not carry a value"):
        Commit(cycle=1, pc=0, value=1)
    with pytest.raises(ValueError, match="must carry a value"):
        Commit(cycle=1, pc=0, rd=5)
    with pytest.raises(ValueError, match="does not fit in 64 bits"):
        Commit(cycle=1, pc=1 << 64)
    with pytest.raises(ValueError, match="register index out of range"):
        Commit(cycle=1, pc=0, rd=32, value=0)


def test_commit_helpers_rebuild_the_record() -> None:
    commit = Commit(cycle=3, pc=0x1000, rd=5, value=1, insn=0x13)
    assert commit.with_value(9).value == 9
    assert commit.with_pc(0x2000).pc == 0x2000
    assert commit.with_rd(6).rd == 6
    assert commit.with_rd(0).rd is None
    assert commit.reg_name == "x5"
    assert commit.value_text == "0x0000000000000001"


def test_non_canonical_text_is_detected() -> None:
    assert not is_canonical_trace("1 0x80000000 - -\n")
    assert not is_canonical_trace("")
