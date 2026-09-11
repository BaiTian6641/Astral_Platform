# SPDX-License-Identifier: MIT
"""DUT-side trace adapters for the ``eth_rv`` DiffTest harness (S15 §2.2).

This is the seam the future ``eth_rv`` RTL core plugs into. A DUT is anything
that can hand the harness an ordered stream of :class:`~rv_trace.Commit` records;
three adapters ship today, and selecting one is a CLI argument:

``--dut dump:PATH``
    A trace file: either the canonical 4-field format, or a bare
    ``pc rd value`` dump (cycle = line ordinal) as a Verilator testbench would
    ``$fwrite`` it.
``--dut model:PATH``
    The worked-example Python DUT (:mod:`rv_model`) running an ELF or hex image.
``--dut callback:MODULE:FUNC``
    ``FUNC()`` returns an iterable of ``Commit`` or trace-line strings. This is
    the in-process hook: a Verilator/cocotb testbench can import this module,
    build commits as it retires instructions, and let the harness diff them.

The RTL testbench is expected to write one line per retired instruction with the
*architectural* effects only (pc, rd, value) — the same contract Spike's
``--log-commits`` satisfies — so no other change to the harness is needed when
``eth_rv`` lands.
"""
from __future__ import annotations

import importlib
import sys
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from rv_trace import Commit, parse_reg, parse_trace, parse_trace_file

PREFIX_DUMP = "dump:"
PREFIX_MODEL = "model:"
PREFIX_CALLBACK = "callback:"


class DutSpecError(ValueError):
    """The ``--dut`` specification is malformed or cannot be loaded."""


class CommitSource(Protocol):
    """The DUT contract: an ordered commit stream plus a label for the report."""

    def iter_commits(self) -> Iterator[Commit]:
        """Yield this DUT's commits in retirement order."""
        ...

    def describe(self) -> str:
        """One-line provenance label used in the harness summary."""
        ...


@dataclass(frozen=True, slots=True)
class TextDumpDUT:
    """DUT trace file (canonical trace or bare ``pc rd value`` dump)."""

    path: Path
    implicit_cycle: bool = True

    def iter_commits(self) -> Iterator[Commit]:
        return iter(parse_trace_file(self.path, implicit_cycle=self.implicit_cycle))

    def describe(self) -> str:
        return f"dump:{self.path}"


@dataclass(frozen=True, slots=True)
class CallbackDUT:
    """DUT driven by ``MODULE:FUNC`` in-process (the RTL testbench hook)."""

    module: str
    func: str
    extra_paths: tuple[Path, ...] = ()

    def iter_commits(self) -> Iterator[Commit]:
        for path in reversed(self.extra_paths):
            if str(path) not in sys.path:
                sys.path.insert(0, str(path))
        try:
            module = importlib.import_module(self.module)
        except ImportError as exc:
            raise DutSpecError(f"cannot import DUT module {self.module!r}: {exc}") from None
        try:
            hook = getattr(module, self.func)
        except AttributeError:
            raise DutSpecError(f"{self.module!r} has no attribute {self.func!r}") from None
        produced = hook()
        return iter(coerce_commits(produced, source=f"{self.module}:{self.func}"))

    def describe(self) -> str:
        return f"callback:{self.module}:{self.func}"


@dataclass(frozen=True, slots=True)
class ModelDUT:
    """The worked-example Python DUT running an ELF/hex image (:mod:`rv_model`)."""

    path: Path
    max_commits: int

    def iter_commits(self) -> Iterator[Commit]:
        # imported lazily: the model DUT is optional, the adapters above are not
        from rv_image import load_image
        from rv_model import ModelError, Rv64ImcModel

        try:
            image = load_image(self.path)
        except (OSError, RuntimeError) as exc:
            raise DutSpecError(f"cannot load DUT image {self.path}: {exc}") from None
        model = Rv64ImcModel(image, max_commits=self.max_commits)
        try:
            return iter(model.trace())
        except ModelError as exc:
            raise DutSpecError(f"model DUT failed on {self.path}: {exc}") from None

    def describe(self) -> str:
        return f"model:{self.path}"


def coerce_commits(produced: Iterable[Commit | str], *, source: str) -> list[Commit]:
    """Normalize a callback's output: :class:`Commit` objects pass through, text is parsed."""
    lines: list[str] = []
    commits: list[Commit] = []
    for item in produced:
        if isinstance(item, Commit):
            commits.append(item)
        elif isinstance(item, str):
            lines.append(item)
        else:
            raise DutSpecError(f"{source}: yielded {type(item).__name__}, expected Commit or str")
    if lines:
        commits.extend(parse_trace("\n".join(lines), source=source))
    return commits


def load_dut(spec: str, *, path_dirs: Iterable[Path] = (), max_commits: int = 1_000_000) -> CommitSource:
    """Build a DUT from a ``--dut`` specification.

    ``dump:PATH`` / ``model:PATH`` / ``callback:MODULE:FUNC`` — see the module
    docstring. Anything else is a usage error.
    """
    if spec.startswith(PREFIX_DUMP):
        return TextDumpDUT(Path(spec[len(PREFIX_DUMP) :]).expanduser())
    if spec.startswith(PREFIX_MODEL):
        return ModelDUT(Path(spec[len(PREFIX_MODEL) :]).expanduser(), max_commits)
    if spec.startswith(PREFIX_CALLBACK):
        rest = spec[len(PREFIX_CALLBACK) :]
        module, sep, func = rest.rpartition(":")
        if not sep or not module or not func:
            raise DutSpecError(f"--dut {spec!r}: expected callback:MODULE:FUNC")
        return CallbackDUT(module, func, tuple(path_dirs))
    raise DutSpecError(
        f"--dut {spec!r}: expected dump:PATH, model:PATH or callback:MODULE:FUNC"
    )


# ---------------------------------------------------------------------------
# Fault injection — harness self-test and demo aid
# ---------------------------------------------------------------------------

INJECTION_FIELDS = ("pc", "rd", "value", "cycle")


@dataclass(frozen=True, slots=True)
class Injection:
    """One deliberate corruption: ``INDEX:FIELD=VALUE`` (e.g. ``12:value=0xdeadbeef``)."""

    index: int
    field: str
    value: int

    @staticmethod
    def parse(spec: str) -> Injection:
        """Parse ``INDEX:FIELD=VALUE``; ``FIELD`` is pc/rd/value/cycle."""
        index_text, sep, rest = spec.partition(":")
        field, eq, value_text = rest.partition("=")
        if not sep or not eq:
            raise DutSpecError(f"--inject {spec!r}: expected INDEX:FIELD=VALUE")
        field = field.strip().lower()
        if field not in INJECTION_FIELDS:
            raise DutSpecError(
                f"--inject {spec!r}: FIELD must be one of {', '.join(INJECTION_FIELDS)}"
            )
        try:
            index = int(index_text, 10)
        except ValueError:
            raise DutSpecError(f"--inject {spec!r}: INDEX must be a decimal commit number") from None
        if index < 0:
            raise DutSpecError(f"--inject {spec!r}: INDEX must be >= 0")
        return Injection(index=index, field=field, value=_parse_field_value(spec, field, value_text))


def _parse_field_value(spec: str, field: str, text: str) -> int:
    """The VALUE half of an injection: a register name for ``rd``, else a number."""
    token = text.strip().lower()
    if field == "rd":
        try:
            rd = parse_reg(token)
        except ValueError:
            raise DutSpecError(f"--inject {spec!r}: {text!r} is not a register") from None
        if rd is None:
            raise DutSpecError(
                f"--inject {spec!r}: `-` is not a register (inject a pc/value to corrupt a "
                "no-write commit)"
            )
        return rd
    try:
        return int(token, 16) if token.startswith("0x") else int(token, 10)
    except ValueError:
        raise DutSpecError(f"--inject {spec!r}: {text!r} is not a number") from None


@dataclass(frozen=True, slots=True)
class InjectedDUT:
    """Wrap a DUT and corrupt specific commits (harness self-test / demo)."""

    source: CommitSource
    injections: tuple[Injection, ...]

    def iter_commits(self) -> Iterator[Commit]:
        for index, commit in enumerate(self.source.iter_commits()):
            yield apply_injections(commit, index, self.injections)

    def describe(self) -> str:
        rendered = " ".join(f"{i.index}:{i.field}={i.value:#x}" for i in self.injections)
        return f"{self.source.describe()} +inject[{rendered}]"


def apply_injections(commit: Commit, index: int, injections: Iterable[Injection]) -> Commit:
    """Return ``commit`` with every injection targeting ``index`` applied."""
    for injection in injections:
        if injection.index != index:
            continue
        commit = apply_injection(commit, injection)
    return commit


def apply_injection(commit: Commit, injection: Injection) -> Commit:
    """Return a copy of ``commit`` with one field replaced.

    Injecting ``rd`` onto a commit that wrote no register gives it a register
    write (which is exactly the kind of DUT bug the harness must catch).
    """
    if injection.field == "pc":
        return commit.with_pc(injection.value)
    if injection.field == "value":
        return commit.with_value(injection.value)
    if injection.field == "rd":
        return commit.with_rd(injection.value)
    if injection.field == "cycle":
        return Commit(
            cycle=injection.value, pc=commit.pc, rd=commit.rd, value=commit.value, insn=commit.insn
        )
    raise DutSpecError(f"cannot inject field {injection.field!r}")  # pragma: no cover - parse guards
