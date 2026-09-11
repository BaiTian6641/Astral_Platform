# SPDX-License-Identifier: MIT
"""Source-level invariants of the port-error corpus program (``cor_fault.S``).

``cor_fault`` is the self-checking program for the D/I-port error responses
(E2-RV1 increment 5): every access the platform cannot serve must arrive as an
access fault with Spike's ``mcause``/``mtval``, and every check it makes is armed
by the ``NEXT``/``NEXTR``/``NEXTF`` macros in its own source. Those two facts are
what the tests below pin down, because the RTL-vs-Spike DiffTest can only catch a
wrong *trap* — an expectation the program never arms, or a final trap count that
no longer matches the expectations, would quietly weaken the self-check without
changing a single commit of the trace:

* the program stays in the runner's corpus and keeps the console line idle (its
  rejected stores must never reach the UART's transmit register);
* every armed expectation is one of the three access-fault causes (1/5/7) — the
  taxonomy Spike was run against, not an invented one;
* the final ``s11`` trap-count check counts exactly the armed expectations;
* the program keeps its regression control for the wedge this increment removed:
  byte accesses at the console page offsets (0x…0F / 0x…10) that the old decoder
  refused to answer.

Nothing here needs a simulator, Spike or the toolchain: it reads the checked-in
sources, like ``test_rv_uart.py`` does for ``cor_hello.S``.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path
from types import ModuleType

import pytest

REPO_ROOT = Path(__file__).resolve().parents[4]
RUNNER_PATH = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "run_difftest.py"
FAULT_SOURCE = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv" / "corpus" / "cor_fault.S"

ARM_RE = re.compile(r"^\s*NEXT(?:R|F)?\s+(\S+?),", re.MULTILINE)
"""An armed trap expectation: ``NEXT cause, mtval, index`` (and its two variants)."""

COUNT_RE = re.compile(r"li\s+t0,\s*(\d+)\s*\n\s*bne\s+s11,\s*t0")
"""The program's final check: ``s11`` (the trap counter) must equal that constant."""

COUNTER_COMMENT = "every expected trap happened"
"""The section comment that introduces the final trap-count check."""


def _load_runner() -> ModuleType:
    """Import ``run_difftest.py`` by path (it is a script, not an importable package)."""
    spec = importlib.util.spec_from_file_location("rv_rtl_runner_fault", RUNNER_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


runner = _load_runner()


def _source() -> str:
    return FAULT_SOURCE.read_text(encoding="utf-8")


def _armed_causes() -> list[int]:
    return [int(match.group(1), 0) for match in ARM_RE.finditer(_source())]


def test_the_program_is_in_the_corpus_and_keeps_the_console_idle() -> None:
    """`cor_fault` runs with the rest, and its rejected UART stores emit nothing."""
    assert "cor_fault" in runner.CORPUS_PROGRAMS
    assert runner.EXPECTED_UART.get("cor_fault", b"") == b""
    assert FAULT_SOURCE.is_file()


def test_every_armed_expectation_is_an_access_fault() -> None:
    """The program only ever expects mcause 1/5/7 — the Spike-verified taxonomy."""
    causes = _armed_causes()
    assert causes, "cor_fault.S arms no trap expectations"
    assert set(causes) == {1, 5, 7}, f"unexpected causes armed: {sorted(set(causes))}"


def test_the_final_trap_count_matches_the_armed_expectations() -> None:
    """`s11` must be checked against exactly the number of armed expectations."""
    source = _source()
    section = source.index(COUNTER_COMMENT)
    match = COUNT_RE.search(source, section)
    assert match is not None, "cor_fault.S has no `li t0, N` / `bne s11, t0` check"
    assert int(match.group(1)) == len(_armed_causes())
    # ... and the check is the LAST thing main does before it returns 0, so a
    # missing trap cannot be swallowed by an earlier exit.
    assert "li      a0, 0\n  ret" in source[section:]


@pytest.mark.parametrize("offset", ["0xf", "0x10"])
def test_the_wedge_control_reads_the_offsets_that_used_to_hang(offset: str) -> None:
    """The byte offsets the old decoder refused are touched by the program."""
    assert f"UART_BASE + {offset}" in _source()
