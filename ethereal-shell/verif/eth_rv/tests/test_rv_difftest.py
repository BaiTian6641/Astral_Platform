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
    KIND_PC,
    KIND_RD,
    KIND_TRUNCATED,
    KIND_VALUE,
    first_divergence,
    load_golden,
)
from rv_trace import Commit, TraceFormatError, format_trace

GOLDEN_COMMITS = 116


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
    assert _run_cli(cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{dump}").returncode == EXIT_MATCH

    bare = tmp_path / "bare.dump"
    body = [line for line in (fixtures_dir / "cor_model.trace").read_text().splitlines() if not line.startswith("#")]
    bare.write_text("\n".join(" ".join(line.split()[1:]) for line in body) + "\n", encoding="utf-8")
    result = _run_cli(cli_path, "--golden", str(fixtures_dir / "cor_model.trace"), "--dut", f"dump:{bare}")
    assert result.returncode == EXIT_MATCH


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
    """The real flow: ELF golden from Spike vs the ELF running in the model DUT."""
    for name, elf in sorted(corpus_elfs.items()):
        result = _run_cli(cli_path, "--elf", str(elf), "--dut", f"model:{elf}", "--spike", str(spike_binary))
        assert result.returncode == EXIT_MATCH, result.stdout + result.stderr
        assert "MATCH:" in result.stdout


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
