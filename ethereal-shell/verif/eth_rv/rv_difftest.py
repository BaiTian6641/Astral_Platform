#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""DiffTest driver for the ``eth_rv`` core (S15 §2.2: "验证 >> RTL — 第一天就上 DiffTest").

Lockstep-diffs a golden commit stream against a DUT commit stream and reports the
**first** divergence with its pc / register / cycle. Exit status:

===== ==========================================================
``0``  every commit matched (summary printed)
``1``  first divergence found (pc / rd / cycle printed)
``2``  usage, I/O, toolchain or trace-format error (nothing compared)
===== ==========================================================

Golden side — at least one of (``--golden`` wins when both are given):
  ``--elf ELF``      run the ELF under Spike and use its commit log (the real flow)
  ``--golden TRACE`` replay a captured canonical trace file — no Spike needed.
                     A *raw* Spike log is also accepted, in which case ``--elf``
                     must be given as well so the harness knows the entry point
                     and the ``tohost`` mailbox the stream must stop at

DUT side — exactly one:
  ``--dut dump:PATH``            trace file (canonical, or bare ``pc rd value``)
  ``--dut model:PATH``           the worked-example Python DUT (ELF or hex image)
  ``--dut callback:MODULE:FUNC`` in-process adapter returning commits/trace lines

Examples::

    ./rv_difftest.py --elf ../../../../generated/rv_difftest/corpus/cor_alu.elf \\
                     --dut model:../../../../generated/rv_difftest/corpus/cor_alu.elf
    ./rv_difftest.py --elf cor.elf --dut model:cor.elf --inject 12:value=0xdeadbeef
"""
from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path

from rv_dut import CommitSource, DutSpecError, InjectedDUT, Injection, load_dut
from rv_image import ImageError, load_elf_image
from rv_spike import SpikeError, is_spike_log, normalize_spike_log, run_spike
from rv_trace import (
    Commit,
    TraceFormatError,
    format_reg,
    is_canonical_trace,
    parse_trace,
)

EXIT_MATCH = 0
EXIT_DIVERGED = 1
EXIT_ERROR = 2

KIND_PC = "pc_mismatch"
KIND_RD = "rd_mismatch"
KIND_VALUE = "value_mismatch"
KIND_CYCLE = "cycle_mismatch"
KIND_TRUNCATED = "dut_trace_truncated"
KIND_EXTRA = "dut_trace_extra_commits"


@dataclass(frozen=True, slots=True)
class Divergence:
    """The first place two commit streams disagree."""

    index: int
    """0-based commit index of the divergence (the DUT's Nth retired instruction)."""
    kind: str
    cycle: int
    pc: int
    rd: int | None
    golden: Commit | None
    dut: Commit | None
    detail: str

    def lines(self, *, golden_label: str, dut_label: str) -> list[str]:
        """Human-readable report: pc, register and cycle of the first divergence."""
        header = (
            f"DIVERGENCE ({self.kind}) at commit #{self.index} (cycle {self.cycle}): "
            f"pc=0x{self.pc:016x} rd={format_reg(self.rd)}"
        )
        report = [header]
        report.append(f"  golden [{golden_label}]: {_render(self.golden)}")
        report.append(f"  dut    [{dut_label}]: {_render(self.dut)}")
        report.append(f"  detail: {self.detail}")
        return report


def _render(commit: Commit | None) -> str:
    return "<stream ended>" if commit is None else commit.format_line()


def first_divergence(
    golden: Iterable[Commit],
    dut: Iterable[Commit],
    *,
    check_cycle: bool = True,
    max_commits: int | None = None,
) -> Divergence | None:
    """The first differing commit, or ``None`` when the streams are identical.

    Order of checks per commit: cycle (optional), pc, register number, register
    value. ``max_commits`` stops the comparison after N commits (a prefix check
    for long programs); the streams must still have the same length otherwise.
    """
    golden_iter = iter(golden)
    dut_iter = iter(dut)
    index = 0
    while max_commits is None or index < max_commits:
        golden_commit = next(golden_iter, None)
        dut_commit = next(dut_iter, None)
        if golden_commit is None and dut_commit is None:
            return None
        if golden_commit is None and dut_commit is not None:
            return Divergence(
                index=index,
                kind=KIND_EXTRA,
                cycle=dut_commit.cycle,
                pc=dut_commit.pc,
                rd=dut_commit.rd,
                golden=None,
                dut=dut_commit,
                detail=(
                    f"DUT retired {_remaining(dut_iter) + 1} extra commit(s); "
                    "the golden stream ended here"
                ),
            )
        if golden_commit is not None and dut_commit is None:
            return Divergence(
                index=index,
                kind=KIND_TRUNCATED,
                cycle=golden_commit.cycle,
                pc=golden_commit.pc,
                rd=golden_commit.rd,
                golden=golden_commit,
                dut=None,
                detail=(
                    f"DUT stream ended after {index} commit(s); golden "
                    f"({_remaining(golden_iter) + 1} more) continues"
                ),
            )
        if golden_commit is None or dut_commit is None:  # pragma: no cover - exhaustive above
            raise AssertionError("unreachable: both streams ended or neither")
        if check_cycle and golden_commit.cycle != dut_commit.cycle:
            return Divergence(
                index=index,
                kind=KIND_CYCLE,
                cycle=dut_commit.cycle,
                pc=golden_commit.pc,
                rd=golden_commit.rd,
                golden=golden_commit,
                dut=dut_commit,
                detail=(
                    f"cycle mismatch: golden {golden_commit.cycle} != dut {dut_commit.cycle}"
                ),
            )
        if golden_commit.pc != dut_commit.pc:
            return Divergence(
                index=index,
                kind=KIND_PC,
                cycle=dut_commit.cycle,
                pc=dut_commit.pc,
                rd=golden_commit.rd,
                golden=golden_commit,
                dut=dut_commit,
                detail=(
                    f"pc mismatch: golden 0x{golden_commit.pc:016x} != dut 0x{dut_commit.pc:016x}"
                    " (divergent control flow)"
                ),
            )
        if golden_commit.rd != dut_commit.rd:
            return Divergence(
                index=index,
                kind=KIND_RD,
                cycle=dut_commit.cycle,
                pc=dut_commit.pc,
                rd=dut_commit.rd,
                golden=golden_commit,
                dut=dut_commit,
                detail=(
                    f"register mismatch at pc 0x{dut_commit.pc:016x}: golden writes "
                    f"{format_reg(golden_commit.rd)}, dut writes {format_reg(dut_commit.rd)}"
                ),
            )
        if golden_commit.value != dut_commit.value:
            return Divergence(
                index=index,
                kind=KIND_VALUE,
                cycle=dut_commit.cycle,
                pc=dut_commit.pc,
                rd=dut_commit.rd,
                golden=golden_commit,
                dut=dut_commit,
                detail=(
                    f"value mismatch: golden {golden_commit.value_text} != "
                    f"dut {dut_commit.value_text}"
                ),
            )
        index += 1
    return None


def _remaining(iterator: Iterator[Commit]) -> int:
    return sum(1 for _ in iterator)


def load_golden(text: str, *, source: str, elf: Path | None = None) -> list[Commit]:
    """Parse a captured golden stream: a canonical trace file or a raw Spike log.

    A raw Spike log carries Spike's boot ROM before the program and its spin loop
    after the HTIF exit store, so it needs ``elf`` for the entry point and the
    ``tohost`` mailbox to cut both off (see :func:`rv_spike.normalize_spike_log`).
    """
    if is_canonical_trace(text):
        return parse_trace(text, source=source)
    if is_spike_log(text):
        if elf is None:
            raise TraceFormatError(
                "this is a raw Spike log; pass --elf as well so the harness knows the "
                "entry point and the tohost mailbox (or convert it with "
                "rv_spike.normalize_spike_log)",
                source=source,
            )
        image = load_elf_image(elf)
        return normalize_spike_log(text, source=source, tohost=image.tohost, entry=image.entry)
    raise TraceFormatError(
        "neither a canonical trace (# rv_difftest trace v1) nor a Spike commit log",
        source=source,
    )


def golden_from_elf(
    elf: Path,
    *,
    spike: str | Path | None,
    isa: str,
    timeout: float,
) -> tuple[list[Commit], str]:
    """Run ``elf`` under Spike; returns ``(commits, label)``."""
    run = run_spike(elf, spike=spike, isa=isa, timeout=timeout)
    return run.commits, run.describe()


def golden_from_trace(path: Path, *, elf: Path | None = None) -> tuple[list[Commit], str]:
    """Load a captured golden stream; returns ``(commits, label)``.

    A canonical trace file needs nothing else. A raw Spike log needs ``elf`` so
    that the harness can skip Spike's boot ROM and stop at the ``tohost`` store.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise TraceFormatError(f"cannot read golden trace: {exc}", source=str(path)) from None
    kind = "spike-log" if is_spike_log(text) else "trace"
    return load_golden(text, source=str(path), elf=elf), f"{kind}:{path.name}"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="rv_difftest.py",
        description="DiffTest lockstep comparison for the eth_rv core (golden vs DUT commit trace)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--elf", type=Path, help="ELF under test (Spike golden source / hints)")
    parser.add_argument("--golden", type=Path, help="captured golden trace file (skips Spike)")
    parser.add_argument("--dut", required=True, help="dump:PATH | model:PATH | callback:MODULE:FUNC")
    parser.add_argument("--dut-path", type=Path, action="append", default=[], help="extra sys.path entry")
    parser.add_argument("--inject", action="append", default=[], help="INDEX:FIELD=VALUE fault injection")
    parser.add_argument("--isa", default="rv64imc", help="Spike --isa string (default: rv64imc)")
    parser.add_argument("--spike", type=Path, default=None, help="spike binary to use")
    parser.add_argument("--timeout", type=float, default=300.0, help="spike timeout in seconds")
    parser.add_argument("--max-commits", type=int, default=None, help="compare only the first N commits")
    parser.add_argument(
        "--no-cycle-check",
        action="store_true",
        help="ignore the cycle field (DUT reports real cycles, golden reports ordinals)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entry point; returns the process exit status (see the module docstring)."""
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.elf is None and args.golden is None:
        parser.error("one of --elf (golden from Spike) or --golden is required")
    try:
        if args.elf is not None and args.golden is None:
            golden_commits, golden_label = golden_from_elf(
                args.elf, spike=args.spike, isa=args.isa, timeout=args.timeout
            )
        elif args.golden is not None:
            golden_commits, golden_label = golden_from_trace(args.golden, elf=args.elf)
        else:  # pragma: no cover - guarded below by the "at least one" check
            sys.stderr.write("[rv_difftest] error: one of --elf/--golden is required\n")
            return EXIT_ERROR
        dut: CommitSource = load_dut(args.dut, path_dirs=args.dut_path, max_commits=MODEL_MAX_COMMITS)
        if args.inject:
            dut = InjectedDUT(dut, tuple(Injection.parse(spec) for spec in args.inject))
        dut_commits = list(dut.iter_commits())
    except (DutSpecError, TraceFormatError, SpikeError, ImageError) as exc:
        sys.stderr.write(f"[rv_difftest] error: {exc}\n")
        return EXIT_ERROR

    divergence = first_divergence(
        golden_commits,
        dut_commits,
        check_cycle=not args.no_cycle_check,
        max_commits=args.max_commits,
    )
    print(f"[rv_difftest] golden = {golden_label} ({len(golden_commits)} commits)")
    print(f"[rv_difftest] dut    = {dut.describe()} ({len(dut_commits)} commits)")
    if divergence is None:
        compared = min(len(golden_commits), len(dut_commits))
        scope = f" (prefix of {args.max_commits})" if args.max_commits is not None else ""
        print(
            f"MATCH: {compared} commits compared{scope}, 0 divergence — pc, rd and value agree"
        )
        return EXIT_MATCH
    for line in divergence.lines(golden_label=golden_label, dut_label=dut.describe()):
        print(line)
    return EXIT_DIVERGED


MODEL_MAX_COMMITS = 1_000_000
"""Commit budget for the model DUT; the corpus reaches `tohost` in a few thousand."""


if __name__ == "__main__":
    raise SystemExit(main())
