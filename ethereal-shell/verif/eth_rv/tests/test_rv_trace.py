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
    stream_has_mem_info,
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
        ("1 0x80000000 x2 0x1 0x2\n", 1, "expected 3 .*fields, got 5"),
        ("1 0xzzzz x2 0x1\n", 1, "not a number"),
        ("1 0x80000000 q7 0x1\n", 1, "is not a register"),
        ("1 0x80000000 - 0x1\n", 1, "without a register write"),
        ("0 0x80000000 x2 0x1\n", 1, "cycle must be >= 1"),
        ("0x80000000 x2\n", 1, "expected 3 .*fields, got 2"),
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


# --- the optional memory suffix (C14 §5.2) ----------------------------------------


def test_memory_suffix_round_trips() -> None:
    """6 fields carry addr + store data; 8 add the byte-lane masks."""
    commits = [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000),
        Commit(cycle=2, pc=0x8000_0004, mem_addr=0x8000_1000, mem_wdata=1),
        Commit(cycle=3, pc=0x8000_0008, rd=10, value=7, mem_addr=0x8000_1FF8),
        Commit(cycle=4, pc=0x8000_000C, mem_addr=0x8000_2000, mem_wmask=0x08),
    ]
    text = format_trace(commits)
    body = [line for line in text.splitlines() if not line.startswith("#")]
    assert body == [
        "1 0x0000000080000000 x2 0x000000008000a000",
        "2 0x0000000080000004 - - 0x0000000080001000 0x0000000000000001",
        "3 0x0000000080000008 x10 0x0000000000000007 0x0000000080001ff8 -",
        "4 0x000000008000000c - - 0x0000000080002000 - - 0x08",
    ]
    assert parse_trace(text) == commits


def test_memory_suffix_accepts_dashes_and_both_masks() -> None:
    commits = parse_trace("7 0x80000000 - - - - - -\n8 0x80000004 - - 0x20 0x2a 0xf0 -\n")
    assert not commits[0].has_mem_access
    assert not commits[0].has_mem_masks
    assert commits[1].mem_addr == 0x20
    assert commits[1].mem_wdata == 0x2A
    assert commits[1].mem_rmask == 0xF0
    assert commits[1].mem_wmask is None
    assert commits[1].has_mem_masks


def test_memory_masks_are_eight_bit() -> None:
    with pytest.raises(ValueError, match="mem_wmask does not fit in 8 bits"):
        Commit(cycle=1, pc=0, mem_addr=0, mem_wmask=0x100)


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("1 0x80000000 - - - 0x1\n", "without a mem_addr"),
        ("1 0x80000000 - - 0x1 0x2 0x3\n", "expected 3 .*fields, got 7"),
        ("1 0x80000000 - - 0x80000000 0x1 0xzz -\n", "not a number"),
        ("1 0x80000000 - - 0x80000000 0x1 0x100 -\n", "does not fit in 8 bits"),
    ],
)
def test_malformed_memory_fields_report_the_line(text: str, expected: str) -> None:
    with pytest.raises(TraceFormatError, match=expected) as excinfo:
        parse_trace(text, source="rtl.dump")
    assert str(excinfo.value).startswith("rtl.dump:1: ")


def test_commit_rejects_inconsistent_masks() -> None:
    with pytest.raises(ValueError, match="cannot be both a load and a store"):
        Commit(cycle=1, pc=0, mem_addr=0, mem_rmask=0x01, mem_wmask=0x02)
    with pytest.raises(ValueError, match="must mark at least one byte"):
        Commit(cycle=1, pc=0, mem_addr=0, mem_rmask=0, mem_wmask=0)
    with pytest.raises(ValueError, match="must not carry mem_wdata"):
        Commit(cycle=1, pc=0, mem_wdata=1)


def test_stream_has_mem_info() -> None:
    """A stream is memory-aware when at least one commit reports an access."""
    memory_less = [Commit(cycle=1, pc=0x1000), Commit(cycle=2, pc=0x1004, rd=1, value=1)]
    memory_aware = [*memory_less, Commit(cycle=3, pc=0x1008, mem_addr=0x2000)]
    assert not stream_has_mem_info(memory_less)
    assert stream_has_mem_info(memory_aware)
    assert not stream_has_mem_info([])


def test_mem_helpers_preserve_the_rest_of_the_record() -> None:
    commit = Commit(cycle=3, pc=0x1000, rd=5, value=1, insn=0x13, mem_addr=0x2000, mem_wmask=0x01)
    assert commit.with_value(9).mem_addr == 0x2000
    assert commit.with_pc(0x2004).mem_wmask == 0x01
    assert commit.with_rd(6).mem_addr == 0x2000
    assert commit.with_rd(0).mem_addr == 0x2000
    assert commit.with_cycle(9).mem_addr == 0x2000
    assert commit.with_mem_addr(0x3000).pc == 0x1000
    assert commit.with_mem_wdata(0x2A).mem_addr == 0x2000
    assert commit.with_mem_rmask(0x01).mem_wmask is None   # a load XOR a store
    assert commit.with_mem_wmask(0x02).mem_rmask is None
    # a commit without a memory access ignores memory-field tweaks
    plain = Commit(cycle=1, pc=0x1000)
    assert plain.with_mem_wdata(1) == plain
    assert plain.with_mem_wmask(1) == plain
