# SPDX-License-Identifier: MIT
"""Tests for the console-UART half of the RTL DiffTest runner (C14 §8 checkpoint 5).

Two things are checked here, hermetically (no toolchain, no Verilator, no Spike):

* the assertion the RTL runner applies to the testbench's `+uart=` record — the
  byte string, the frame count, the 8N1 framing and the bit rate of the
  inter-frame gaps must all be the ones `cor_hello.S` produces, and each of them
  fails on its own when it is wrong; and
* that the string the runner *expects* is the string the program *writes*: the
  expected payload lives in `run_difftest.py` and the data in `cor_hello.S`, so
  the two are re-read against each other here rather than trusted.
"""
from __future__ import annotations

import importlib.util
import re
import sys
from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

REPO_ROOT = Path(__file__).resolve().parents[4]
RUNNER_PATH = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "run_difftest.py"
HELLO_SOURCE = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv" / "corpus" / "cor_hello.S"


def _load_runner() -> ModuleType:
    """Import ``run_difftest.py`` by path (it is a script, not an importable package)."""
    spec = importlib.util.spec_from_file_location("rv_core_runner", RUNNER_PATH)
    if spec is None or spec.loader is None:  # pragma: no cover - import machinery failure
        raise RuntimeError(f"cannot load {RUNNER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module  # dataclasses resolve cls.__module__ through this
    spec.loader.exec_module(module)
    return module


runner = _load_runner()
HELLO = runner.HELLO_STRING


def record_text(
    data: bytes = HELLO,
    *,
    bit_cycles: int = 16,
    frames: int | None = None,
    header_bytes: int | None = None,
    errors: int = 0,
    overflow: int = 0,
    gap_min: int | None = None,
    gap_max: int | None = None,
) -> str:
    """A `+uart=` record as ``tb_eth_rv_core.sv`` writes it (all fields overridable)."""
    frame_cycles = 10 * bit_cycles
    return (
        "# eth_rv uart rx v1\n"
        f"# bit_cycles: {bit_cycles} frame_cycles: {frame_cycles} "
        f"bytes: {len(data) if header_bytes is None else header_bytes} "
        f"frames: {len(data) if frames is None else frames} errors: {errors} "
        f"overflow: {overflow} drain_cycles: 2200\n"
        f"# gap_min: {frame_cycles if gap_min is None else gap_min} "
        f"gap_max: {frame_cycles if gap_max is None else gap_max}\n"
        f"data: {data.hex()}\n"
    )


# --- the program and the assertion agree -------------------------------------------


def test_expected_string_is_the_one_the_program_writes() -> None:
    """`HELLO_STRING` must be the bytes of the `.ascii` in `cor_hello.S`."""
    source = HELLO_SOURCE.read_text(encoding="utf-8")
    match = re.search(r'\.ascii\s+"([^"]*)"', source)
    assert match is not None, "cor_hello.S has no .ascii message"
    written = match.group(1).encode("latin-1").decode("unicode_escape").encode("latin-1")
    assert written == HELLO
    assert HELLO.endswith(b"\n")


def test_the_program_drives_the_mapped_uart_page() -> None:
    """The addresses in the program are the ones the SoC decodes (mux + Spike)."""
    source = HELLO_SOURCE.read_text(encoding="utf-8")
    assert ".equ UART_BASE,     0x10000000" in source
    assert ".equ UART_LSR_OFF,  5" in source


def test_only_hello_has_a_console_payload() -> None:
    """Every other corpus program must leave the serial line idle."""
    assert runner.EXPECTED_UART == {"cor_hello": HELLO}
    assert "cor_hello" in runner.CORPUS_PROGRAMS
    for name in runner.EXPECTED_UART:
        assert name in runner.CORPUS_PROGRAMS


def test_runner_builds_the_uart_decoding_sources() -> None:
    """The RTL build must include the peripheral and its decoder."""
    names = [path.name for path in runner.RTL_SOURCES]
    assert "eth_rv_uart.sv" in names
    assert "eth_rv_mmio_mux.sv" in names


# --- the record parser -------------------------------------------------------------


def test_record_round_trip(tmp_path: Path) -> None:
    path = tmp_path / "hello.uart"
    path.write_text(record_text(), encoding="ascii")
    record = runner.parse_uart_record(path)
    assert record.data == HELLO
    assert record.text == HELLO.decode("latin-1")
    assert (record.bit_cycles, record.frame_cycles) == (16, 160)
    assert (record.frames, record.errors, record.overflow) == (len(HELLO), 0, False)
    assert (record.header_bytes, record.drain_cycles) == (len(HELLO), 2200)


def test_idle_record_is_accepted(tmp_path: Path) -> None:
    """A program that never touches the UART produces an empty payload."""
    path = tmp_path / "idle.uart"
    path.write_text(
        record_text(b"", frames=0, gap_min=0, gap_max=0), encoding="ascii"
    )
    record = runner.parse_uart_record(path)
    assert record.data == b""
    assert runner.uart_problems(record, b"") == []


def test_malformed_record_is_a_setup_error(tmp_path: Path) -> None:
    path = tmp_path / "junk.uart"
    path.write_text("hello, eth_rv!\n", encoding="ascii")
    with pytest.raises(runner.SetupError, match="not an eth_rv UART record"):
        runner.parse_uart_record(path)


# --- the assertion -----------------------------------------------------------------


def _record(tmp_path: Path, text: str) -> Any:
    """Parse `text` as a `+uart=` record through the runner's own reader.

    (`Any`: the runner is loaded by path, so its `UartRecord` is not visible to
    static analysis here — the fields asserted below are what matters.)
    """
    path = tmp_path / "record.uart"
    path.write_text(text, encoding="ascii")
    return runner.parse_uart_record(path)


def test_good_record_passes_every_check(tmp_path: Path) -> None:
    assert runner.uart_problems(_record(tmp_path, record_text()), HELLO) == []


@pytest.mark.parametrize(
    ("make_record", "expected"),
    [
        (lambda: record_text(b"iello, eth_rv!\n"), "payload"),
        (lambda: record_text(header_bytes=99), "header says 99 bytes"),
        (lambda: record_text(frames=3), "3 frames carried"),
        (lambda: record_text(errors=1), "1 framing error(s)"),
        (lambda: record_text(overflow=1), "transmit queue overflowed"),
        (
            lambda: record_text().replace("frame_cycles: 160", "frame_cycles: 150"),
            "10 * bit_cycles",
        ),
        (lambda: record_text(gap_max=161), "bit timing: inter-frame gap 160..161"),
        (lambda: record_text(gap_min=159), "bit timing: inter-frame gap 159..160"),
    ],
)
def test_each_uart_property_fails_on_its_own(
    tmp_path: Path, make_record: Callable[[], str], expected: str
) -> None:
    """Every field of the record is load-bearing: corrupt one, the check reports it."""
    record = _record(tmp_path, make_record())
    problems = runner.uart_problems(record, HELLO)
    assert any(expected in problem for problem in problems), problems


def test_a_single_frame_has_no_gap_to_check(tmp_path: Path) -> None:
    """A one-byte burst cannot state a bit rate: the gap check must stand down."""
    record = _record(tmp_path, record_text(b"h", gap_min=0, gap_max=0))
    assert runner.uart_problems(record, b"h") == []


def test_report_names_the_program_and_the_payload(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """The success line is the evidence: the string, the frames and the bit rate."""
    record = _record(tmp_path, record_text())
    assert runner.report_uart("cor_hello", record, HELLO, expect_fault=False) == 0
    out = capsys.readouterr().out
    assert "'hello, eth_rv!\\n'" in out
    assert "15 frames of 160 cycles (16-cycle bit cell)" in out
    assert "gap 160..160" in out


def test_negative_control_must_break_the_assertion(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """With --uart-fault the check has to FAIL; an intact payload is a bug."""
    intact = _record(tmp_path, record_text())
    assert runner.report_uart("cor_hello", intact, HELLO, expect_fault=True) == 1
    assert "negative control NOT caught" in capsys.readouterr().out

    corrupted = _record(tmp_path, record_text(b"iello, eth_rv!\n"))
    assert runner.report_uart("cor_hello", corrupted, HELLO, expect_fault=True) == 0
    assert "negative control caught" in capsys.readouterr().out


def test_negative_control_skips_programs_without_a_payload(tmp_path: Path) -> None:
    """A program that never uses the console has no line fault to catch."""
    idle = _record(tmp_path, record_text(b"", frames=0, gap_min=0, gap_max=0))
    assert runner.report_uart("cor_alu", idle, b"", expect_fault=True) == 0


# --- the line-fault spec -----------------------------------------------------------


@pytest.mark.parametrize(("spec", "expected"), [("0:1", (0, 1)), ("3:9", (3, 9)), ("12:0", (12, 0))])
def test_uart_fault_spec_is_parsed(spec: str, expected: tuple[int, int]) -> None:
    assert runner.parse_uart_fault(spec) == expected


@pytest.mark.parametrize("spec", ["", "1", "1:", ":1", "1:10", "a:b"])
def test_bad_uart_fault_spec_is_refused(spec: str) -> None:
    with pytest.raises(runner.SetupError, match="FRAME:BIT"):
        runner.parse_uart_fault(spec)
