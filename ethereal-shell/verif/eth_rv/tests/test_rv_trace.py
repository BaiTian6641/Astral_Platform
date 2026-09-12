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
    TRACE_HEADER_V2,
    Commit,
    TraceFormatError,
    format_reg,
    format_trace,
    is_canonical_trace,
    parse_reg,
    parse_trace,
    parse_trace_file,
    stream_has_fp_info,
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
    [
        ("x0", 0),
        ("x31", 31),
        ("X 5", 5),
        ("a0", 10),
        ("sp", 2),
        ("fp", 8),
        ("t6", 31),
        ("f0", 0),
        ("f31", 31),
        ("F 5", 5),
        ("-", None),
    ],
)
def test_register_field_parsing(token: str, expected: int | None) -> None:
    assert parse_reg(token) == expected


@pytest.mark.parametrize("token", ["", "x32", "x", "w5", "v0", "--", "a9", "f32", "f", "fa0"])
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


# --- the FP record (RV-C) ----------------------------------------------------------


def _fp_commits() -> list[Commit]:
    """A stream that exercises every part of the FP record, memory suffix included."""
    return [
        Commit(cycle=1, pc=0x8000_0000, rd=1, value=0x3FF0_0000_0000_0000, rd_is_fp=True),
        Commit(
            cycle=2,
            pc=0x8000_0004,
            rd=4,
            value=0x7FF8_0000_0000_0000,
            rd_is_fp=True,
            fflags=0x10,
        ),
        Commit(cycle=3, pc=0x8000_0008, fflags=0x00, frm=0x01),
        Commit(
            cycle=4,
            pc=0x8000_000C,
            rd=0,
            value=0x8000_0000_0000_0000,
            rd_is_fp=True,
            mem_addr=0x8000_00A8,
        ),
    ]


def test_fp_record_round_trips() -> None:
    """``f<d>`` rds and the keyed ``fflags``/``frm`` tokens survive format+parse."""
    commits = _fp_commits()
    text = format_trace(commits, generator="unit-test")
    assert text.startswith(TRACE_HEADER_V2)  # a stream with FP state is v2
    assert is_canonical_trace(text)
    body = [line for line in text.splitlines() if not line.startswith("#")]
    assert body == [
        "1 0x0000000080000000 f1 0x3ff0000000000000",
        "2 0x0000000080000004 f4 0x7ff8000000000000 fflags=0x10",
        "3 0x0000000080000008 - - fflags=0x00 frm=0x01",
        "4 0x000000008000000c f0 0x8000000000000000 0x00000000800000a8 -",
    ]
    assert parse_trace(text) == commits


def test_fp_keyed_tokens_follow_the_memory_suffix() -> None:
    commit = Commit(
        cycle=1,
        pc=0x1000,
        rd=18,
        value=1,
        rd_is_fp=True,
        mem_addr=0x2000,
        mem_wmask=0x08,
        frm=0x03,
        fflags=0x1F,
    )
    assert commit.format_line() == (
        "1 0x0000000000001000 f18 0x0000000000000001 0x0000000000002000 - - 0x08 "
        "fflags=0x1f frm=0x03"
    )


def test_f0_write_is_kept_and_x0_is_not() -> None:
    fp0 = Commit(cycle=1, pc=0x1000, rd=0, value=1, rd_is_fp=True)
    assert (fp0.rd, fp0.value, fp0.rd_is_fp) == (0, 1, True)
    assert fp0.reg_name == "f0"
    assert fp0.writes_register
    assert Commit(cycle=1, pc=0x1000, rd=0, value=1).rd is None


def test_both_trace_headers_are_canonical() -> None:
    v1 = "# rv_difftest trace v1\n1 0x80000000 x2 0x1\n"
    v2 = "# rv_difftest trace v2\n1 0x80000000 f2 0x1\n"
    assert is_canonical_trace(v1)
    assert is_canonical_trace(v2)
    assert parse_trace(v1) == [Commit(cycle=1, pc=0x8000_0000, rd=2, value=1)]
    assert parse_trace(v2) == [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=1, rd_is_fp=True)
    ]


def test_fp_tokens_round_trip_through_parse_and_format() -> None:
    text = (
        "# rv_difftest trace v2\n"
        "7 0x80000000 f31 0x3ff0000000000000 fflags=0x1f frm=0x7\n"
    )
    commits = parse_trace(text)
    assert commits == [
        Commit(
            cycle=7,
            pc=0x8000_0000,
            rd=31,
            value=0x3FF0_0000_0000_0000,
            rd_is_fp=True,
            fflags=0x1F,
            frm=0x07,
        )
    ]
    body = [line for line in format_trace(commits).splitlines() if not line.startswith("#")]
    assert body == ["7 0x0000000080000000 f31 0x3ff0000000000000 fflags=0x1f frm=0x07"]


def test_keyed_tokens_leave_the_positional_grammar_alone() -> None:
    """A keyed token is split out first, so the 3/4/6/8-field shapes still apply."""
    commits = parse_trace(
        "1 0x80000000 - - fflags=0x02\n"
        "2 0x80000004 a0 7 frm=7\n"
        "3 0x80000008 - - 0x80001000 0x2a fflags=0x00\n"
        "4 0x8000000c - - 0x80002000 - - 0x01 frm=0x03\n"
    )
    assert [commit.fflags for commit in commits] == [0x02, None, 0x00, None]
    assert [commit.frm for commit in commits] == [None, 7, None, 0x03]
    assert commits[1].rd == 10
    assert commits[3].mem_wmask == 0x01


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("1 0x80000000 - - fflags=zz\n", "not a number"),
        ("1 0x80000000 - - fflags=0x20\n", "does not fit in 5 bits"),
        ("1 0x80000000 - - frm=0x8\n", "does not fit in 3 bits"),
        ("1 0x80000000 - - nope=1\n", "unknown keyed field"),
        ("1 0x80000000 - - fflags=1 fflags=2\n", "more than once"),
        ("1 0x80000000 f32 0x1\n", "is not a register"),
        ("1 0x80000000 - - fflags\n", "expected 3 .*fields, got 5"),
    ],
)
def test_malformed_fp_fields_report_the_line(text: str, expected: str) -> None:
    with pytest.raises(TraceFormatError, match=expected) as excinfo:
        parse_trace(text, source="rtl.dump")
    assert str(excinfo.value).startswith("rtl.dump:1: ")


def test_commit_validates_the_fp_state() -> None:
    with pytest.raises(ValueError, match="fflags does not fit in 5 bits"):
        Commit(cycle=1, pc=0, fflags=32)
    with pytest.raises(ValueError, match="frm does not fit in 3 bits"):
        Commit(cycle=1, pc=0, frm=8)
    assert Commit(cycle=1, pc=0, fflags=31, frm=7).has_fp_info
    assert not Commit(cycle=1, pc=0).has_fp_info


def test_format_reg_emits_the_register_class() -> None:
    assert format_reg(7) == "x7"
    assert format_reg(7, is_fp=True) == "f7"
    assert format_reg(None) == "-"
    assert format_reg(None, is_fp=True) == "-"


def test_stream_has_fp_info() -> None:
    """A stream is FP-aware when any commit reports FP state — write or keyed update."""
    plain = [Commit(cycle=1, pc=0x1000), Commit(cycle=2, pc=0x1004, rd=1, value=1)]
    fp_write = [*plain, Commit(cycle=3, pc=0x1008, rd=31, value=1, rd_is_fp=True)]
    csr_only = [*plain, Commit(cycle=3, pc=0x1008, frm=1)]
    assert not stream_has_fp_info(plain)
    assert stream_has_fp_info(fp_write)
    assert stream_has_fp_info(csr_only)
    assert not stream_has_fp_info([])
    # a stream with FP state is still a v2 stream when it is serialized
    assert format_trace(fp_write).startswith(TRACE_HEADER_V2)
    assert format_trace(plain).startswith(TRACE_HEADER_PREFIX)
