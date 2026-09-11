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
    stream_has_mem_info,
)

EXIT_MATCH = 0
EXIT_DIVERGED = 1
EXIT_ERROR = 2

KIND_PC = "pc_mismatch"
KIND_RD = "rd_mismatch"
KIND_VALUE = "value_mismatch"
KIND_CYCLE = "cycle_mismatch"
KIND_MEM_ADDR = "mem_addr_mismatch"
KIND_MEM_WDATA = "mem_wdata_mismatch"
KIND_MEM_MASK = "mem_mask_mismatch"
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


def _mem_text(commit: Commit) -> str:
    """The memory access of a commit as compact text for a divergence report."""
    if not commit.has_mem_access:
        return "no memory access"
    addr = f"addr=0x{commit.mem_addr:016x}"
    data = "load" if commit.mem_wdata is None else f"store data=0x{commit.mem_wdata:016x}"
    return f"{addr} {data}"


def _lane_mask_is_consistent(mask: int, addr: int) -> bool:
    """True when ``mask`` is a contiguous run of lanes starting at ``addr[2:0]``.

    The masks address byte lanes of the 8-byte-aligned window at ``addr & ~7``
    (the RVFI convention), and every access this core can retire is contained in
    one such window — so a mask that does not start at the access offset, or that
    has holes, is an inconsistent record and is reported.
    """
    offset = addr & 0b111
    if mask & ((1 << offset) - 1):
        return False
    shifted = mask >> offset
    return shifted != 0 and (shifted & (shifted + 1)) == 0


def _mem_divergence(index: int, golden: Commit, dut: Commit) -> Divergence | None:
    """The first memory-stream divergence between two commits, or ``None``.

    ``mem_addr``/``mem_wdata`` are compared when both sides report memory (the
    golden convention is Spike's ``mem`` log). ``mem_rmask``/``mem_wmask`` are
    DUT-only information — Spike has no mask field — so they are checked against
    the golden's load/store direction and for internal consistency instead of
    being compared value by value.
    """
    if golden.mem_addr != dut.mem_addr:
        if dut.mem_addr is None:
            detail = f"golden retires a memory access here, dut reports none ({_mem_text(golden)})"
        elif golden.mem_addr is None:
            detail = f"dut retires a memory access here, golden reports none ({_mem_text(dut)})"
        else:
            detail = (
                f"memory address mismatch: golden 0x{golden.mem_addr:016x} != "
                f"dut 0x{dut.mem_addr:016x}"
            )
        return Divergence(
            index=index,
            kind=KIND_MEM_ADDR,
            cycle=dut.cycle,
            pc=dut.pc,
            rd=dut.rd,
            golden=golden,
            dut=dut,
            detail=detail,
        )
    if dut.mem_addr is None:
        return None
    if golden.mem_wdata != dut.mem_wdata:
        detail = (
            f"memory write data mismatch: golden "
            f"{'load' if golden.mem_wdata is None else f'0x{golden.mem_wdata:016x}'} != dut "
            f"{'load' if dut.mem_wdata is None else f'0x{dut.mem_wdata:016x}'}"
        )
        return Divergence(
            index=index,
            kind=KIND_MEM_WDATA,
            cycle=dut.cycle,
            pc=dut.pc,
            rd=dut.rd,
            golden=golden,
            dut=dut,
            detail=detail,
        )
    return _mask_divergence(index, golden, dut)


def _mask_divergence(index: int, golden: Commit, dut: Commit) -> Divergence | None:
    """Check the DUT's byte-lane masks against the golden direction and themselves."""

    def fail(detail: str) -> Divergence:
        return Divergence(
            index=index,
            kind=KIND_MEM_MASK,
            cycle=dut.cycle,
            pc=dut.pc,
            rd=dut.rd,
            golden=golden,
            dut=dut,
            detail=detail,
        )

    assert dut.mem_addr is not None and golden.mem_addr is not None
    if not dut.has_mem_masks:
        return None
    for name, mask in (("rmask", dut.mem_rmask), ("wmask", dut.mem_wmask)):
        # 0 is the "this is not a load/store" value for the unused direction
        if mask and not _lane_mask_is_consistent(mask, dut.mem_addr):
            return fail(
                f"dut {name}=0x{mask:02x} is not a contiguous run of lanes starting at "
                f"addr[2:0]={dut.mem_addr & 7}"
            )
    if golden.mem_wdata is None:  # the golden says this commit is a load
        if not dut.mem_rmask:
            return fail(
                f"golden retires a load here, dut reports rmask=0x{(dut.mem_rmask or 0):02x} "
                f"(wmask=0x{(dut.mem_wmask or 0):02x})"
            )
    elif not dut.mem_wmask:
        return fail(
            f"golden retires a store here, dut reports wmask=0x{(dut.mem_wmask or 0):02x} "
            f"(rmask=0x{(dut.mem_rmask or 0):02x})"
        )
    if (
        golden.has_mem_masks
        and dut.has_mem_masks
        and (golden.mem_rmask != dut.mem_rmask or golden.mem_wmask != dut.mem_wmask)
    ):
        return fail(
            f"mask mismatch: golden rmask={golden.mem_rmask} wmask={golden.mem_wmask} != "
            f"dut rmask={dut.mem_rmask} wmask={dut.mem_wmask}"
        )
    return None


def first_divergence(
    golden: Iterable[Commit],
    dut: Iterable[Commit],
    *,
    check_cycle: bool = True,
    check_mem: bool = True,
    max_commits: int | None = None,
) -> Divergence | None:
    """The first differing commit, or ``None`` when the streams are identical.

    Order of checks per commit: cycle (optional), pc, register number, register
    value, then the optional memory stream (C14 §5.2) — address, store data and
    the DUT's byte-lane masks. ``max_commits`` stops the comparison after N
    commits (a prefix check for long programs); the streams must still have the
    same length otherwise.

    ``check_mem`` must only be set when *both* streams report their memory
    accesses (``rv_trace.stream_has_mem_info``); the CLI decides that once for
    the whole run so a 4-field DUT dump is compared on pc/rd/value alone and the
    memory stream is reported as not provided rather than silently passing.
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
        if check_mem:
            mem_divergence = _mem_divergence(index, golden_commit, dut_commit)
            if mem_divergence is not None:
                return mem_divergence
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

    golden_aware = stream_has_mem_info(golden_commits)
    dut_aware = stream_has_mem_info(dut_commits)
    check_mem = golden_aware and dut_aware
    divergence = first_divergence(
        golden_commits,
        dut_commits,
        check_cycle=not args.no_cycle_check,
        check_mem=check_mem,
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
        if check_mem:
            accesses = sum(
                1 for commit in golden_commits[:compared] if commit.has_mem_access
            )
            print(
                f"[rv_difftest] memory: active — {accesses} memory access(es) compared "
                "(addr + store data; DUT lane masks checked for direction/consistency)"
            )
        else:
            missing = ", ".join(
                name
                for name, aware in (("golden", golden_aware), ("dut", dut_aware))
                if not aware
            )
            print(
                f"[rv_difftest] memory: not provided — no mem fields in the {missing} stream "
                "(compared pc, rd and value only)"
            )
        return EXIT_MATCH
    for line in divergence.lines(golden_label=golden_label, dut_label=dut.describe()):
        print(line)
    return EXIT_DIVERGED


MODEL_MAX_COMMITS = 1_000_000
"""Commit budget for the model DUT; the corpus reaches `tohost` in a few thousand."""


if __name__ == "__main__":
    raise SystemExit(main())
