# SPDX-License-Identifier: MIT
"""Tests for the comparator and the ``rv_difftest.py`` CLI (the harness's outputs).

The CLI tests are the acceptance contract: exit ``0`` with a summary on a full
match, exit ``1`` naming the exact pc/register/cycle of the first divergence, and
exit ``2`` (never ``1``) for malformed or unusable input.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest
from rv_difftest import (
    EXIT_DIVERGED,
    EXIT_ERROR,
    EXIT_MATCH,
    KIND_CYCLE,
    KIND_EXTRA,
    KIND_MEM_ADDR,
    KIND_MEM_MASK,
    KIND_MEM_WDATA,
    KIND_PC,
    KIND_RD,
    KIND_TRUNCATED,
    KIND_VALUE,
    first_divergence,
    load_golden,
)
from rv_trace import Commit, TraceFormatError, format_trace

GOLDEN_COMMITS = 116

MODEL_DUT_PROGRAMS = ("cor_alu", "cor_mem", "cor_muldiv", "cor_model")
"""Corpus programs the worked-example model DUT can run (it has no CSR/trap path)."""


def _commits() -> list[Commit]:
    return [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000),
        Commit(cycle=2, pc=0x8000_0004),
        Commit(cycle=3, pc=0x8000_0008, rd=10, value=42),
    ]


def _run_cli(
    cli_path: Path, *args: str, cwd: Path | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(cli_path), *args],
        capture_output=True,
        text=True,
        check=False,
        cwd=str(cwd) if cwd is not None else None,
    )


# --- comparator -------------------------------------------------------------------


def test_identical_streams_match() -> None:
    assert first_divergence(_commits(), _commits()) is None


@pytest.mark.parametrize(
    ("index", "mutate", "kind", "cycle"),
    [
        (1, "pc", KIND_PC, 2),
        (2, "rd", KIND_RD, 3),
        (2, "value", KIND_VALUE, 3),
        (1, "cycle", KIND_CYCLE, 77),
    ],
)
def test_first_divergence_reports_exact_position(
    index: int, mutate: str, kind: str, cycle: int
) -> None:
    golden = _commits()
    dut = list(golden)
    commit = golden[index]
    if mutate == "pc":
        dut[index] = commit.with_pc(0xDEAD_BEEF)
    elif mutate == "rd":
        dut[index] = commit.with_rd(9)
    elif mutate == "value":
        dut[index] = commit.with_value((commit.value or 0) ^ 0xFF)
    else:
        dut[index] = Commit(cycle=77, pc=commit.pc, rd=commit.rd, value=commit.value)
    divergence = first_divergence(golden, dut)
    assert divergence is not None
    assert (divergence.index, divergence.kind, divergence.cycle) == (index, kind, cycle)
    assert divergence.golden == commit


def test_cycle_check_can_be_disabled() -> None:
    """A DUT that reports real commit cycles cannot match Spike's ordinals."""
    dut = [Commit(cycle=c.cycle * 10, pc=c.pc, rd=c.rd, value=c.value) for c in _commits()]
    assert first_divergence(_commits(), dut) is not None
    assert first_divergence(_commits(), dut, check_cycle=False) is None


def test_truncated_dut_stream_is_a_divergence() -> None:
    divergence = first_divergence(_commits(), _commits()[:2])
    assert divergence is not None
    assert divergence.kind == KIND_TRUNCATED
    assert (divergence.index, divergence.cycle, divergence.pc) == (2, 3, 0x8000_0008)
    assert divergence.dut is None


def test_extra_dut_commits_are_a_divergence() -> None:
    divergence = first_divergence(_commits()[:2], _commits())
    assert divergence is not None
    assert divergence.kind == KIND_EXTRA
    assert (divergence.index, divergence.cycle) == (2, 3)
    assert divergence.golden is None


def test_max_commits_compares_a_prefix() -> None:
    dut = _commits() + [Commit(cycle=4, pc=0x8000_000C, rd=1, value=7)]
    assert first_divergence(_commits(), dut, max_commits=3) is None
    assert first_divergence(_commits(), dut, max_commits=4) is not None


def test_divergence_report_names_pc_register_and_cycle() -> None:
    divergence = first_divergence(_commits(), [*_commits()[:2], _commits()[2].with_value(7)])
    assert divergence is not None
    report = "\n".join(divergence.lines(golden_label="spike", dut_label="model"))
    assert "DIVERGENCE (value_mismatch) at commit #2 (cycle 3)" in report
    assert "pc=0x0000000080000008" in report
    assert "rd=x10" in report
    assert "golden [spike]: 3 0x0000000080000008 x10 0x000000000000002a" in report
    assert "dut    [model]: 3 0x0000000080000008 x10 0x0000000000000007" in report


# --- the memory stream (C14 §5.2) --------------------------------------------------


def _memory_commits() -> list[Commit]:
    """Two commits that agree except in the details each check looks at."""
    return [
        Commit(cycle=1, pc=0x8000_0000),
        Commit(cycle=2, pc=0x8000_0004, mem_addr=0x8000_1003, mem_wdata=0x2A, mem_wmask=0x08),
        Commit(cycle=3, pc=0x8000_0008, rd=9, value=7, mem_addr=0x8000_2004, mem_rmask=0xF0),
    ]


def test_memory_stream_matches_through_the_comparator() -> None:
    assert first_divergence(_memory_commits(), _memory_commits()) is None


@pytest.mark.parametrize(
    ("index", "mutate", "kind"),
    [
        (1, "addr", KIND_MEM_ADDR),
        (1, "wdata", KIND_MEM_WDATA),
        (2, "addr", KIND_MEM_ADDR),
        (2, "wdata", KIND_MEM_WDATA),
        (1, "drop", KIND_MEM_ADDR),
        (2, "invent", KIND_MEM_ADDR),
        (1, "rmask_flip", KIND_MEM_MASK),
        (1, "bad_mask", KIND_MEM_MASK),
    ],
)
def test_first_memory_divergence_reports_exact_position(
    index: int, mutate: str, kind: str
) -> None:
    golden = _memory_commits()
    dut = list(golden)
    commit = golden[index]
    if mutate == "addr":
        dut[index] = commit.with_mem_addr(0xDEAD_0000)
    elif mutate == "wdata":
        dut[index] = commit.with_mem_wdata((commit.mem_wdata or 0) ^ 0xFF)
    elif mutate == "drop":
        dut[index] = Commit(cycle=commit.cycle, pc=commit.pc, rd=commit.rd, value=commit.value)
    elif mutate == "invent":
        dut[index] = Commit(
            cycle=commit.cycle, pc=commit.pc, rd=commit.rd, value=commit.value, mem_addr=0x1234
        )
    elif mutate == "rmask_flip":  # the golden says "store", the DUT says "load"
        dut[index] = Commit(
            cycle=commit.cycle, pc=commit.pc, mem_addr=commit.mem_addr, mem_wdata=commit.mem_wdata,
            mem_rmask=0x08,
        )
    else:  # a mask that does not start at the access offset
        dut[index] = Commit(
            cycle=commit.cycle, pc=commit.pc, mem_addr=0x8000_1003, mem_wdata=commit.mem_wdata,
            mem_wmask=0x01,
        )
    divergence = first_divergence(golden, dut)
    assert divergence is not None
    assert (divergence.index, divergence.kind, divergence.cycle) == (index, kind, commit.cycle)
    assert divergence.golden == commit


def test_memory_check_can_be_disabled() -> None:
    """A DUT that reports no memory at all must still compare on pc/rd/value."""
    golden = _memory_commits()
    dut = [Commit(cycle=c.cycle, pc=c.pc, rd=c.rd, value=c.value) for c in golden]
    assert first_divergence(golden, dut) is not None
    assert first_divergence(golden, dut, check_mem=False) is None


def test_memory_report_shows_both_sides() -> None:
    golden = _memory_commits()
    dut = [*golden[:1], golden[1].with_mem_addr(0x8000_DEAD), golden[2]]
    divergence = first_divergence(golden, dut)
    assert divergence is not None
    report = "\n".join(divergence.lines(golden_label="spike", dut_label="rtl"))
    assert "DIVERGENCE (mem_addr_mismatch) at commit #1 (cycle 2)" in report
    assert "golden [spike]: 2 0x0000000080000004 - - 0x0000000080001003" in report
    assert "dut    [rtl]: 2 0x0000000080000004 - - 0x000000008000dead" in report
    assert "memory address mismatch" in report


# --- golden loading ----------------------------------------------------------------


def test_load_golden_accepts_canonical_traces() -> None:
    assert load_golden(format_trace(_commits()), source="unit") == _commits()


def test_raw_spike_log_without_elf_is_refused() -> None:
    with pytest.raises(TraceFormatError, match="raw Spike log"):
        load_golden("core   0: 3 0x0000000080000000 (0x00000297) x5  0x1\n", source="log")


def test_unrecognized_golden_text_is_refused() -> None:
    with pytest.raises(TraceFormatError, match="neither a canonical trace"):
        load_golden("hello world\n", source="unit")


# --- CLI ---------------------------------------------------------------------------


def test_cli_match_exits_zero_with_a_summary(cli_path: Path, fixtures_dir: Path) -> None:
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.trace"),
        "--dut",
        f"model:{fixtures_dir / 'cor_model.hex'}",
    )
    assert result.returncode == EXIT_MATCH
    assert f"MATCH: {GOLDEN_COMMITS} commits compared, 0 divergence" in result.stdout
    assert result.stderr == ""


def test_cli_dump_dut_round_trip(cli_path: Path, fixtures_dir: Path, tmp_path: Path) -> None:
    """The DUT side may be a plain trace file — the RTL testbench's output shape."""
    dump = tmp_path / "with_cycles.dump"
    dump.write_text((fixtures_dir / "cor_model.trace").read_text(encoding="utf-8"), encoding="utf-8")
    result = _run_cli(cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{dump}")
    assert result.returncode == EXIT_MATCH
    assert "memory: active" in result.stdout

    # a bare `pc rd value` dump has no memory information: the comparison must say
    # so instead of silently claiming the memory stream matched (C14 §5.2)
    bare = tmp_path / "bare.dump"
    body = [line for line in (fixtures_dir / "cor_model.trace").read_text().splitlines() if not line.startswith("#")]
    bare.write_text("\n".join(" ".join(line.split()[1:4]) for line in body) + "\n", encoding="utf-8")
    result = _run_cli(cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{bare}")
    assert result.returncode == EXIT_MATCH
    assert "memory: not provided" in result.stdout


def test_cli_injected_divergence_exits_one_with_exact_position(
    cli_path: Path, fixtures_dir: Path
) -> None:
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.trace"),
        "--dut",
        f"model:{fixtures_dir / 'cor_model.hex'}",
        "--inject",
        "12:value=0xdeadbeef",
    )
    assert result.returncode == EXIT_DIVERGED
    assert "DIVERGENCE (value_mismatch) at commit #12 (cycle 13)" in result.stdout
    assert "pc=0x000000008000003c" in result.stdout
    assert "rd=x9" in result.stdout
    assert "0x00000000deadbeef" in result.stdout


def test_cli_injected_pc_divergence(cli_path: Path, fixtures_dir: Path) -> None:
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.trace"),
        "--dut",
        f"model:{fixtures_dir / 'cor_model.hex'}",
        "--inject",
        "40:pc=0x80000000",
    )
    assert result.returncode == EXIT_DIVERGED
    assert "DIVERGENCE (pc_mismatch) at commit #40" in result.stdout


def test_cli_malformed_dump_exits_two(cli_path: Path, fixtures_dir: Path, tmp_path: Path) -> None:
    bad = tmp_path / "bad.dump"
    bad.write_text("1 0xnothex x2 0x1\n", encoding="utf-8")
    result = _run_cli(cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{bad}")
    assert result.returncode == EXIT_ERROR
    assert "error:" in result.stderr
    assert "bad.dump:1" in result.stderr


def _first_store(lines: list[str]) -> tuple[int, int]:
    """``(line index, 0-based commit index)`` of the fixture trace's first store."""
    commit_index = -1
    for line_index, line in enumerate(lines):
        if line.startswith("#") or not line.strip():
            continue
        commit_index += 1
        fields = line.split()
        if len(fields) == 6 and fields[5] != "-":
            return line_index, commit_index
    raise AssertionError("the fixture trace has no store")


@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        ("wdata", "mem_wdata_mismatch"),
        ("wmask_flip", "mem_mask_mismatch"),
    ],
)
def test_cli_catches_a_corrupted_memory_stream(
    cli_path: Path, fixtures_dir: Path, tmp_path: Path, mutation: str, expected: str
) -> None:
    """The memory-stream negative control, hermetically (no RTL, no Spike).

    The golden trace is Spike's; the DUT dump is the same stream with one store
    corrupted — the first divergence must land on exactly that commit, with both
    sides printed. The second case keeps the store data and flips the byte-lane
    direction instead, which only the mask cross-check can catch.
    """
    lines = (fixtures_dir / "cor_model.trace").read_text(encoding="utf-8").splitlines()
    line_index, commit_index = _first_store(lines)
    fields = lines[line_index].split()
    if mutation == "wdata":
        fields[5] = "0x00000000deadbeef"
    else:  # keep the data, report the access as a read of the same byte
        fields += ["0x01", "-"]
    lines[line_index] = " ".join(fields)
    corrupt = tmp_path / "corrupted.dump"
    corrupt.write_text("\n".join(lines) + "\n", encoding="utf-8")
    result = _run_cli(
        cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{corrupt}"
    )
    assert result.returncode == EXIT_DIVERGED
    assert f"DIVERGENCE ({expected}) at commit #{commit_index}" in result.stdout
    assert "golden" in result.stdout and "dut" in result.stdout


def test_cli_memory_not_provided_is_reported_not_claimed(
    cli_path: Path, fixtures_dir: Path, tmp_path: Path
) -> None:
    """A 4-field golden (no memory information) must not silently "pass" memory."""
    lines = [
        " ".join(line.split()[:4])
        for line in (fixtures_dir / "cor_model.trace").read_text(encoding="utf-8").splitlines()
        if not line.startswith("#") and line.strip()
    ]
    stripped = tmp_path / "no_mem.trace"
    stripped.write_text(
        "\n".join(["# rv_difftest trace v1", *lines]) + "\n", encoding="utf-8"
    )
    result = _run_cli(
        cli_path, "--golden", str(stripped), "--dut", f"dump:{fixtures_dir / 'cor_model.trace'}"
    )
    assert result.returncode == EXIT_MATCH
    assert "memory: not provided" in result.stdout
    assert "golden" in result.stdout.split("memory: not provided", 1)[1]


def test_cli_memory_injection_is_caught(
    cli_path: Path, fixtures_dir: Path, tmp_path: Path
) -> None:
    """``--inject INDEX:mem_addr=…`` moves a store and the comparator reports it."""
    lines = (fixtures_dir / "cor_model.trace").read_text(encoding="utf-8").splitlines()
    _, commit_index = _first_store(lines)
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.trace"),
        "--dut",
        f"dump:{fixtures_dir / 'cor_model.trace'}",
        "--inject",
        f"{commit_index}:mem_addr=0x8000dead",
    )
    assert result.returncode == EXIT_DIVERGED
    assert f"DIVERGENCE (mem_addr_mismatch) at commit #{commit_index}" in result.stdout
    assert "0x000000008000dead" in result.stdout


def test_cli_raw_log_golden_needs_the_elf(cli_path: Path, fixtures_dir: Path) -> None:
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.spike_log.txt"),
        "--dut",
        f"model:{fixtures_dir / 'cor_model.hex'}",
    )
    assert result.returncode == EXIT_ERROR
    assert "raw Spike log" in result.stderr


def test_cli_raw_log_golden_with_elf_hints(
    cli_path: Path, fixtures_dir: Path, corpus_elfs: dict[str, Path]
) -> None:
    result = _run_cli(
        cli_path,
        "--golden",
        str(fixtures_dir / "cor_model.spike_log.txt"),
        "--elf",
        str(corpus_elfs["cor_model"]),
        "--dut",
        f"model:{fixtures_dir / 'cor_model.hex'}",
    )
    assert result.returncode == EXIT_MATCH
    assert "golden = spike-log:cor_model.spike_log.txt" in result.stdout


def test_cli_requires_a_golden_and_a_dut(cli_path: Path) -> None:
    assert _run_cli(cli_path, "--dut", "dump:/dev/null").returncode == EXIT_ERROR
    assert _run_cli(cli_path, "--elf", "x.elf").returncode == EXIT_ERROR


def test_cli_spike_end_to_end(
    cli_path: Path, corpus_elfs: dict[str, Path], spike_binary: Path
) -> None:
    """The real flow: ELF golden from Spike vs the ELF running in the model DUT.

    Only the programs inside the model DUT's documented subset: it is an
    RV64IMC interpreter without a CSR/trap path (``cor_csr``/``cor_trap`` raise
    ``UnsupportedInstruction`` by design — they are the RTL's corpus).
    """
    for name in MODEL_DUT_PROGRAMS:
        elf = corpus_elfs[name]
        result = _run_cli(cli_path, "--elf", str(elf), "--dut", f"model:{elf}", "--spike", str(spike_binary))
        assert result.returncode == EXIT_MATCH, result.stdout + result.stderr
        assert "MATCH:" in result.stdout
        assert "memory: active" in result.stdout


def test_cli_spike_end_to_end_catches_a_wrong_dut(
    cli_path: Path, corpus_elfs: dict[str, Path], spike_binary: Path
) -> None:
    """Corrupt one register value the DUT reports and Spike must catch it."""
    from rv_spike import run_spike

    elf = corpus_elfs["cor_muldiv"]
    golden = run_spike(elf, spike=spike_binary).commits
    index = next(i for i, commit in enumerate(golden) if commit.value is not None)
    wrong = golden[index].value ^ 1  # type: ignore[operator]
    result = _run_cli(
        cli_path,
        "--elf",
        str(elf),
        "--dut",
        f"model:{elf}",
        "--spike",
        str(spike_binary),
        "--inject",
        f"{index}:value={wrong:#x}",
    )
    assert result.returncode == EXIT_DIVERGED
    assert f"DIVERGENCE (value_mismatch) at commit #{index}" in result.stdout
