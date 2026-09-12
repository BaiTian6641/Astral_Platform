# SPDX-License-Identifier: MIT
"""Tests for the DUT-side adapters (:mod:`rv_dut`).

These cover the seam the future ``eth_rv`` RTL core plugs into: a trace file, an
in-process callback (what a Verilator testbench uses) and the built-in model DUT,
plus the fault injection the harness uses to prove its own first-divergence path.
"""
from __future__ import annotations

from pathlib import Path

import pytest
from rv_dut import (
    INJECTION_FIELDS,
    DutSpecError,
    InjectedDUT,
    Injection,
    apply_injection,
    apply_injections,
    load_dut,
)
from rv_image import load_hex_image
from rv_model import Rv64ImcModel
from rv_trace import Commit, format_trace


def _commits() -> list[Commit]:
    return [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=0x8000_A000),
        Commit(cycle=2, pc=0x8000_0004),
        Commit(cycle=3, pc=0x8000_0008, rd=10, value=42),
    ]


def test_dump_adapter_reads_a_trace_file(tmp_path: Path) -> None:
    path = tmp_path / "dut.trace"
    path.write_text(format_trace(_commits()), encoding="utf-8")
    dut = load_dut(f"dump:{path}")
    assert dut.describe() == f"dump:{path}"
    assert list(dut.iter_commits()) == _commits()


def test_dump_adapter_accepts_a_bare_pc_rd_value_dump(tmp_path: Path) -> None:
    path = tmp_path / "dut.dump"
    path.write_text("80000000 x2 0x8000a000\n80000008 a0 42\n", encoding="utf-8")
    assert [commit.cycle for commit in load_dut(f"dump:{path}").iter_commits()] == [1, 2]


def test_model_adapter_runs_the_fixture_image(fixtures_dir: Path) -> None:
    image_path = fixtures_dir / "cor_model.hex"
    dut = load_dut(f"model:{image_path}")
    assert list(dut.iter_commits()) == Rv64ImcModel(load_hex_image(image_path)).trace()
    assert dut.describe().startswith("model:")


def test_model_adapter_reports_a_broken_image(tmp_path: Path) -> None:
    """An image outside the model's subset must fail loudly, not silently truncate."""
    bad = tmp_path / "bad.hex"
    bad.write_text(
        "# entry 0x80000000\n# tohost 0x80001000\n@80000000 00000073\n", encoding="utf-8"
    )
    dut = load_dut(f"model:{bad}")
    with pytest.raises(DutSpecError, match="model DUT failed on .*SYSTEM instruction"):
        list(dut.iter_commits())


def test_model_adapter_reports_a_missing_image(tmp_path: Path) -> None:
    with pytest.raises(DutSpecError, match="cannot load DUT image"):
        list(load_dut(f"model:{tmp_path / 'nope.hex'}").iter_commits())


def test_callback_adapter_accepts_commits_and_trace_lines(tmp_path: Path) -> None:
    module = tmp_path / "tb_hook.py"
    module.write_text(
        "from rv_trace import Commit\n"
        "\n"
        "def commits():\n"
        "    return [Commit(cycle=1, pc=0x80000000, rd=2, value=0x8000a000), '2 0x80000004 - -']\n",
        encoding="utf-8",
    )
    dut = load_dut("callback:tb_hook:commits", path_dirs=[tmp_path])
    assert list(dut.iter_commits()) == _commits()[:2]
    assert dut.describe() == "callback:tb_hook:commits"


def test_callback_adapter_error_paths(tmp_path: Path) -> None:
    with pytest.raises(DutSpecError, match="cannot import DUT module"):
        list(load_dut("callback:no_such_module:commits", path_dirs=[tmp_path]).iter_commits())

    # a unique module name per test: importlib caches by name across tests
    module = tmp_path / "tb_hook_missing_attr.py"
    module.write_text("def other():\n    return []\n", encoding="utf-8")
    with pytest.raises(DutSpecError, match="has no attribute"):
        list(load_dut("callback:tb_hook_missing_attr:commits", path_dirs=[tmp_path]).iter_commits())


def test_callback_adapter_rejects_unexpected_payload(tmp_path: Path) -> None:
    module = tmp_path / "tb_hook_bad_payload.py"
    module.write_text("def commits():\n    return [3.14]\n", encoding="utf-8")
    with pytest.raises(DutSpecError, match="expected Commit or str"):
        list(load_dut("callback:tb_hook_bad_payload:commits", path_dirs=[tmp_path]).iter_commits())


@pytest.mark.parametrize("spec", ["", "traces/dut.trace", "dump", "callback:module", "callback::func"])
def test_bad_dut_specs_are_rejected(spec: str) -> None:
    with pytest.raises(DutSpecError):
        load_dut(spec)


@pytest.mark.parametrize(
    ("spec", "field", "value"),
    [
        ("12:value=0xdeadbeef", "value", 0xDEAD_BEEF),
        ("12:pc=0x80000000", "pc", 0x8000_0000),
        ("12:rd=x9", "rd", 9),
        ("12:rd=a0", "rd", 10),
        ("12:cycle=99", "cycle", 99),
        ("12:value=42", "value", 42),
        ("12:fflags=0x1f", "fflags", 31),
        ("12:frm=7", "frm", 7),
    ],
)
def test_injection_specs_parse(spec: str, field: str, value: int) -> None:
    injection = Injection.parse(spec)
    assert (injection.index, injection.field, injection.value) == (12, field, value)


@pytest.mark.parametrize(
    "spec",
    [
        "12",
        "12:value",
        "12:nope=1",
        "x:value=1",
        "-1:value=1",
        "12:value=zz",
        "12:rd=-",
        "12:rd=x99",
        "12:fflags=32",
        "12:fflags=-1",
        "12:frm=8",
    ],
)
def test_bad_injection_specs_are_rejected(spec: str) -> None:
    with pytest.raises(DutSpecError):
        Injection.parse(spec)


def test_injections_target_one_commit() -> None:
    """A value injection rewrites the register value the DUT reported."""
    injected = apply_injection(_commits()[2], Injection.parse("2:value=0xdeadbeef"))
    assert injected.value == 0xDEAD_BEEF
    assert injected.rd == 10


def test_injecting_a_register_onto_a_no_write_commit_adds_the_write() -> None:
    """The invented write carries 0: the comparator still reports the rd divergence."""
    commit = Commit(cycle=2, pc=0x8000_0004)
    injected = apply_injection(commit, Injection.parse("2:rd=x9"))
    assert injected.rd == 9
    assert injected.value == 0
    assert commit == Commit(cycle=2, pc=0x8000_0004)  # the original is untouched


def test_apply_injections_filters_by_index() -> None:
    commits = _commits()
    injections = (Injection.parse("0:value=1"), Injection.parse("2:value=3"))
    assert [apply_injections(commit, index, injections) for index, commit in enumerate(commits)] == [
        Commit(cycle=1, pc=0x8000_0000, rd=2, value=1),
        commits[1],
        Commit(cycle=3, pc=0x8000_0008, rd=10, value=3),
    ]


def test_injected_dut_wraps_another_source(tmp_path: Path) -> None:
    path = tmp_path / "dut.trace"
    path.write_text(format_trace(_commits()), encoding="utf-8")
    dut = InjectedDUT(load_dut(f"dump:{path}"), (Injection.parse("0:cycle=42"),))
    commits = list(dut.iter_commits())
    assert commits[0].cycle == 42
    assert commits[1:] == _commits()[1:]
    assert "+inject[0:cycle=0x2a]" in dut.describe()


# --- FP-record injection (RV-C) ----------------------------------------------------


def test_injection_fields_cover_the_fp_record() -> None:
    assert {"fflags", "frm"} <= set(INJECTION_FIELDS)


def test_fp_injections_replace_the_control_state() -> None:
    """Injecting ``fflags``/``frm`` corrupts the keyed FP record and nothing else."""
    commit = Commit(
        cycle=3,
        pc=0x8000_0008,
        rd=4,
        value=0x7FF8_0000_0000_0000,
        rd_is_fp=True,
        fflags=0x10,
    )
    injected = apply_injection(commit, Injection.parse("3:fflags=0x1f"))
    assert (injected.fflags, injected.rd, injected.rd_is_fp, injected.value) == (
        0x1F,
        4,
        True,
        0x7FF8_0000_0000_0000,
    )
    assert injected.mem_addr is None  # an FP injection never invents a memory access
    assert commit.fflags == 0x10  # the original is untouched
    # a commit that reported no frm gets one, so the comparator can report it
    assert apply_injection(commit, Injection.parse("3:frm=1")).frm == 1


def test_value_injection_corrupts_the_raw_fp_value() -> None:
    """The FP value rides in ``value``, so no FP-specific field is needed for it."""
    commit = Commit(cycle=1, pc=0x8000_0000, rd=1, value=0x3FF0_0000_0000_0000, rd_is_fp=True)
    injected = apply_injection(commit, Injection.parse("0:value=0xdeadbeef"))
    assert (injected.value, injected.rd, injected.rd_is_fp) == (0xDEAD_BEEF, 1, True)
