# SPDX-License-Identifier: MIT
"""Spike golden-trace generator for the ``eth_rv`` DiffTest harness (S15 §2.2).

Runs an ELF under the pinned Spike build (``generated/rv_difftest/spike``, see
:data:`BUILD_COMMANDS`) with commit logging enabled and normalizes Spike's log
into the canonical trace of :mod:`rv_trace`::

    core   0: 3 0x0000000080000000 (0x00000297) x 5  0x0000000080001000
    core   0: 3 0x00000000800000f8 (0x6082) x1  0x0000000000000000 mem 0x0000000080009fe0
    core   0: 3 0x00000000800000fc (0x00a2b023) mem 0x0000000080001000 0x0000000000000001
    core   0: 3 0x0000000080000030 (0xf20280d3) f1  0x3ff0000000000000
    core   0: 3 0x0000000080000042 (0x1a31f253) c1_fflags 0x0000000000000010 f4  0x7ff8000000000000
    -> 1 0x0000000080000000 x5 0x0000000080001000
    -> 2 0x00000000800000f8 x1 0x0000000000000000 0x0000000080009fe0 -
    -> 3 0x00000000800000fc - - 0x0000000080001000 0x0000000000000001
    -> 4 0x0000000080000030 f1 0x3ff0000000000000
    -> 5 0x0000000080000042 f4 0x7ff8000000000000 fflags=0x10

Upstream Spike prints one line per retired instruction containing the privilege,
pc, instruction word, every register (``x``/``f``/``c`` prefixes) or vector
update, and ``mem`` read/write addresses. The register write and the memory
access are part of the canonical record (the latter as the optional
``mem_addr``/``mem_wdata`` suffix of :mod:`rv_trace` — see C14 §5.2); ``insn`` is
carried along for diagnostics. Spike is not cycle-accurate, so ``cycle`` is the
retirement ordinal.

The FP record rides on the same line: ``f<n> <raw 64-bit value>`` is an FP
register write (``rd_is_fp``; the value is already NaN-boxed) and
``c1_fflags``/``c2_frm`` are the keyed FP control-state updates. Spike logs
*every* CSR write (``c768_mstatus`` included) but the canonical trace has no
integer-CSR field, so only the two FP CSRs are kept and ``mstatus`` is ignored —
see the FP boundary in ``local://rv8-trace-spec.md``.

An instruction that **traps** is not committed: Spike logs the exception instead
of a commit line, so a trapping instruction appears in neither the golden stream
nor (correctly implemented) a DUT's trace. The exception lines and the ``-l``
disassembly lines do not match :data:`_COMMIT_RE` and are ignored.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from collections.abc import Iterable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

from rv_image import load_elf_image
from rv_platform import (
    DEFAULT_BOOTARGS,
    DTB_PATH_REL,
    ISA_STRING,
    RAM_BASE,
    RAM_WINDOW_BYTES,
    repo_root,
)
from rv_trace import Commit, TraceFormatError, format_trace

DEFAULT_ISA = ISA_STRING
"""ISA string the corpus is built for (RV-C: RV64IMAFDC + Zicsr, no MMU).

I|M|A|F|D|C|S|U is what the core advertises in ``misa`` (0x800000000014112d).
``Zicsr`` is spelled out because binutils no longer implies it from ``I`` and the
CSR/FP-control programs need it; Spike enables it for this ISA by default. The
corpus is built for the same string (``corpus/build_corpus.py`` MARCH), so a
program that uses the A extension or ``wfi`` assembles and runs identically under
both simulators."""

SPIKE_ENV_VAR = "RV_DIFFTEST_SPIKE"
"""Environment variable that overrides the Spike binary location."""

SPIKE_REL_PATH = Path("generated/rv_difftest/spike/install/bin/spike")
"""Where this harness builds Spike (gitignored, never vendored in the tree)."""

DTC_REL_PATH = Path("generated/rv_difftest/dtc")
"""Where this harness builds `dtc` — Spike shells out to it at run time to build a DTB."""

DTC_DIR_ENV_VAR = "RV_DIFFTEST_DTC"
"""Environment variable that overrides the ``dtc`` directory."""

BUILD_COMMANDS = f"""\
mkdir -p generated/rv_difftest && cd generated/rv_difftest
git clone https://github.com/riscv-software-src/riscv-isa-sim.git spike
git clone https://github.com/dgibson/dtc.git dtc            # spike needs `dtc` (configure + run)
make -C dtc -j"$(nproc)" NO_PYTHON=1                        # -> generated/rv_difftest/dtc/dtc
cd spike && mkdir -p build && cd build
PATH="$PWD/../../../dtc:$PATH" ../configure --prefix="$PWD/../install"
make -j"$(nproc)" && make install                           # -> {SPIKE_REL_PATH}
""" + """\
# pinned commits used by this harness:
#   riscv-isa-sim 1e05ddac3a6c351bfc0aeed0cf3a68940e7200ab (2026-09-11)
#   dtc           7a1e017926004ecff5fce62d62d42ce9f3e00082 (2026-09-08)
"""

_COMMIT_RE = re.compile(
    r"^core\s*(?P<core>\d+):\s*(?P<priv>\d+)\s+0x(?P<pc>[0-9a-fA-F]+)"
    r"\s+\(0x(?P<insn>[0-9a-fA-F]+)\)(?P<rest>.*)$"
)
"""One Spike commit-log line (``--log-commits``); the ``-l`` disassembly lines do not match."""

_XREG_RE = re.compile(r"\bx(?P<rd>\d+)\s+(?P<value>0x[0-9a-fA-F]+)\b")
"""Integer register update inside a commit line (``v`` updates are ignored)."""

_FREG_RE = re.compile(r"\bf(?P<rd>\d+)\s+(?P<value>0x[0-9a-fA-F]+)\b")
"""Floating-point register update inside a commit line (``f1  0x3ff0…``).

Spike logs the raw, already NaN-boxed 64-bit FP register value, which is exactly
what ``rv_trace.Commit.value`` carries for an FP write.
"""

_CSR_RE = re.compile(r"\bc(?P<addr>\d+)_(?P<name>[a-z0-9]+)\s+0x(?P<value>[0-9a-fA-F]+)")
"""One CSR write inside a commit line: ``c<addr>_<name> <value>``.

Spike logs every CSR write this way (``c1_fflags``, ``c2_frm``, ``c768_mstatus``,
…). Only :data:`_FP_CSR_NAMES` are part of the canonical record; the rest (the
integer CSRs) are ignored — the trace has no field for them.
"""

_FP_CSR_NAMES = ("fflags", "frm")
"""The two CSR write names that map onto the keyed trace fields of :mod:`rv_trace`."""
_MEM_RE = re.compile(r"\bmem\s+0x(?P<addr>[0-9a-fA-F]+)(?:\s+0x(?P<data>[0-9a-fA-F]+))?\b")
"""One memory access inside a commit line: ``mem <addr> [<data>]``.

Spike logs a store with its data and a load with the address only, and logs the
data already truncated to the access size (``sb`` of ``0x1234`` prints
``mem 0x… 0x34``) — that is the convention the trace's ``mem_wdata`` uses
(C14 §5.2), so it compares byte for byte against a DUT.

An A-extension read-modify-write is the ONE case where a commit line carries two
of these fields: Spike's AMO logs the read of the old value (the address only)
and then the write of the result (address + data), both at the same address.
:func:`iter_spike_commits` keeps the write and drops the read — the "report the
write" convention the DUT's trace uses for an AMO (a single-access record whose
``mem_wdata`` is the value stored back, paired with the old value in ``rd``).
See verif/eth_rv/README.md "The A extension".
"""


class SpikeError(RuntimeError):
    """Spike could not be found, did not run, or produced no usable trace."""


@dataclass(frozen=True, slots=True)
class StopStore:
    """The store that ends a run: an address, optionally a pinned value.

    A run's architectural end is a store the program makes; the HTIF mailbox
    (``tohost``) is just the one the corpus uses by default. ``value=None``
    stops on the first store to ``addr``; pinning the value as well is how two
    runs are shown to stop at the *same architectural event* rather than merely
    at the same address.
    """

    addr: int
    value: int | None = None

    def matches(self, mem_addr: int | None, mem_wdata: int | None) -> bool:
        """True when this commit is the stopping store (a load never matches)."""
        if mem_addr != self.addr or mem_wdata is None:
            return False
        return self.value is None or mem_wdata == self.value

    def describe(self) -> str:
        """``store@0x…`` / ``store@0x…=0x…`` for the PASS line."""
        suffix = "" if self.value is None else f"=0x{self.value:x}"
        return f"store@0x{self.addr:x}{suffix}"


def _int_literal(text: str) -> int:
    """Parse a CLI integer: ``0x…`` is hex, everything else is decimal."""
    return int(text, 16) if text[:2].lower() == "0x" else int(text, 10)


_STOP_STORE_RE = re.compile(
    r"^(?P<addr>0[xX][0-9a-fA-F]+|\d+)(?::(?P<value>0[xX][0-9a-fA-F]+|\d+))?$"
)


def parse_stop_store(spec: str) -> StopStore:
    """Parse ``ADDR[:VALUE]`` (hex or decimal) into a :class:`StopStore`."""
    match = _STOP_STORE_RE.match(spec.strip())
    if match is None:
        raise ValueError(f"want ADDR[:VALUE] (hex or decimal), got {spec!r}")
    value = match.group("value")
    return StopStore(
        addr=_int_literal(match.group("addr")),
        value=None if value is None else _int_literal(value),
    )


def truncate_at_stop(
    commits: Iterable[Commit], stop: StopStore | None, *, source: str = "<stream>"
) -> list[Commit]:
    """Cut a commit stream *after* the stopping store (no-op when ``stop`` is None).

    The golden side stops inside the log parser; a DUT dump and a canonical trace
    arrive whole, so the comparator uses this to end both streams at the same
    architectural event. A stream that never reaches the event is an **error**, not
    a silently longer comparison: ``--stop-store`` must mean the same thing on both
    sides, and a typo in the address should not turn into a whole-stream pass.
    """
    if stop is None:
        return list(commits)
    kept: list[Commit] = []
    for commit in commits:
        kept.append(commit)
        if stop.matches(commit.mem_addr, commit.mem_wdata):
            return kept
    raise TraceFormatError(
        f"the stream does not reach the stopping store ({stop.describe()})", source=source
    )


@dataclass(frozen=True, slots=True)
class GoldenConfig:
    """How a golden run is pinned: ISA, memory window, DT, bootargs, PC and stop.

    ``stop=None`` means the historical default — stop at the ELF's ``tohost``
    symbol. Every other field is only passed to Spike when set, so the harness's
    default argv is exactly the pre-S3 one plus the memory window.
    """

    isa: str = DEFAULT_ISA
    mem_base: int = RAM_BASE
    mem_size: int = RAM_WINDOW_BYTES
    dtb: Path | None = None
    bootargs: str | None = None
    pc: int | None = None
    pcs: str | None = None
    dtb_enabled: bool = True
    stop: StopStore | None = None

    def __post_init__(self) -> None:
        if not self.dtb_enabled and self.dtb is not None:
            raise ValueError("--dtb and --disable-dtb are mutually exclusive")
        if self.mem_size <= 0:
            raise ValueError(f"memory window size must be positive, got {self.mem_size}")

    def memory_argument(self) -> str:
        """Spike's region form ``-m0x80000000:1048576`` (bytes, 4 KiB aligned)."""
        return f"-m0x{self.mem_base:x}:{self.mem_size}"

    def arguments(self) -> list[str]:
        """The argv fragment that carries this configuration."""
        args = [self.memory_argument()]
        if not self.dtb_enabled:
            args.append("--disable-dtb")
        elif self.dtb is not None:
            args.append(f"--dtb={self.dtb}")
        if self.bootargs is not None:
            args.append(f"--bootargs={self.bootargs}")
        if self.pc is not None:
            args.append(f"--pc=0x{self.pc:x}")
        if self.pcs is not None:
            args.append(f"--pcs={self.pcs}")
        return args

    def describe(self) -> str:
        """One-line, audit-ready rendering of every pinned knob."""
        if not self.dtb_enabled:
            dtb = "disabled"
        elif self.dtb is not None:
            dtb = self.dtb.name
        else:
            dtb = "spike-auto"
        bootargs = DEFAULT_BOOTARGS if self.bootargs is None else self.bootargs
        pc = "elf-entry" if self.pc is None else f"0x{self.pc:x}"
        stop = "tohost" if self.stop is None else self.stop.describe()
        text = (
            f"isa={self.isa} mem={self.memory_argument()} dtb={dtb} "
            f"bootargs={bootargs!r} pc={pc} stop={stop}"
        )
        return text if self.pcs is None else f"{text} pcs={self.pcs}"


def default_spike_path() -> Path | None:
    """Repo-relative Spike binary of :data:`SPIKE_REL_PATH`, if it was built."""
    root = repo_root()
    if root is None:
        return None
    candidate = root / SPIKE_REL_PATH
    return candidate if candidate.is_file() else None


def default_dtc_dir() -> Path | None:
    """Directory holding the built ``dtc`` binary, if this harness built one."""
    override = os.environ.get(DTC_DIR_ENV_VAR)
    if override:
        return Path(override) if Path(override).is_dir() else None
    root = repo_root()
    if root is None:
        return None
    candidate = root / DTC_REL_PATH
    return candidate if (candidate / "dtc").is_file() else None


def find_dtc(explicit: str | Path | None = None) -> Path:
    """Locate the ``dtc`` binary: explicit (file or dir), ``$RV_DIFFTEST_DTC``, repo, PATH."""
    if explicit is not None:
        path = Path(explicit)
        if path.is_dir():
            path = path / "dtc"
        if not path.is_file():
            raise SpikeError(f"dtc binary not found: {path}")
        return path
    built = default_dtc_dir()
    if built is not None:
        return built / "dtc"
    on_path = shutil.which("dtc")
    if on_path is not None:
        return Path(on_path)
    raise SpikeError(
        "no dtc binary found (looked at the explicit path, "
        f"${DTC_DIR_ENV_VAR}, <repo>/{DTC_REL_PATH}, $PATH).\n"
        f"Build it with:\n{BUILD_COMMANDS}"
    )


def compile_dts(
    dts: str | Path, dtb: str | Path | None = None, *, dtc: str | Path | None = None
) -> Path:
    """Compile a device tree source into a blob (``dtc -I dts -O dtb``)."""
    source = Path(dts)
    if not source.is_file():
        raise SpikeError(f"device tree source not found: {source}")
    out = Path(dtb) if dtb is not None else source.with_suffix(".dtb")
    try:
        proc = subprocess.run(
            [str(find_dtc(dtc)), "-I", "dts", "-O", "dtb", "-o", str(out), str(source)],
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
    except OSError as exc:
        raise SpikeError(f"cannot execute dtc: {exc}") from None
    except subprocess.TimeoutExpired:
        raise SpikeError(f"dtc timed out compiling {source}") from None
    if proc.returncode != 0 or not out.is_file():
        detail = (proc.stderr or proc.stdout or "").strip()[:400]
        raise SpikeError(f"dtc failed on {source}: {detail}")
    return out


def ensure_dtb(
    path: str | Path, *, dtb: str | Path | None = None, dtc: str | Path | None = None
) -> Path:
    """Return a device tree blob path, compiling a ``*.dts`` on demand.

    A compiled tree lands at ``dtb`` when given, otherwise at the harness's
    build output (``generated/rv_difftest/eth_rv.dtb``) so compiling the
    checked-in source never writes into the source tree.
    """
    candidate = Path(path)
    if candidate.suffix == ".dts":
        root = repo_root()
        out = Path(dtb) if dtb is not None else (root / DTB_PATH_REL if root else None)
        return compile_dts(candidate, out, dtc=dtc)
    if not candidate.is_file():
        raise SpikeError(f"device tree blob not found: {candidate}")
    return candidate


def find_spike(explicit: str | Path | None = None) -> Path:
    """Locate the Spike binary: explicit argument, ``$RV_DIFFTEST_SPIKE``, repo build, PATH."""
    if explicit is not None:
        path = Path(explicit)
        if not path.is_file():
            raise SpikeError(f"spike binary not found: {path}")
        return path
    from_env = os.environ.get(SPIKE_ENV_VAR)
    if from_env:
        path = Path(from_env)
        if not path.is_file():
            raise SpikeError(f"${SPIKE_ENV_VAR}={from_env}: not a file")
        return path
    built = default_spike_path()
    if built is not None:
        return built
    on_path = shutil.which("spike")
    if on_path is not None:
        return Path(on_path)
    raise SpikeError(
        "no spike binary found (looked at --spike, "
        f"${SPIKE_ENV_VAR}, <repo>/{SPIKE_REL_PATH}, $PATH).\n"
        f"Build it with:\n{BUILD_COMMANDS}"
    )


def spike_version(spike: str | Path) -> str:
    """Spike's version banner (``Spike RISC-V ISA Simulator <version>``).

    Upstream Spike has no ``--version`` flag — the banner is the first line of
    ``--help`` — so probe that and fall back to the binary path.
    """
    try:
        proc = subprocess.run(
            [str(spike), "--help"],
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
    except OSError as exc:
        raise SpikeError(f"cannot execute {spike}: {exc}") from None
    text = (proc.stdout or "") + (proc.stderr or "")
    for line in text.splitlines():
        if line.strip().startswith("Spike"):
            return line.strip()
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return str(spike)


@dataclass(frozen=True, slots=True)
class SpikeRun:
    """Everything a caller needs to explain where a golden trace came from."""

    spike: Path
    version: str
    elf: Path
    isa: str
    returncode: int
    log: str
    commits: list[Commit]
    config: GoldenConfig = field(default_factory=GoldenConfig)

    def describe(self) -> str:
        """One-line provenance string used in ``rv_difftest`` summaries."""
        return f"spike[{self.isa}] {self.elf.name} ({self.version})"

    def config_text(self) -> str:
        """The pinned golden configuration (recorded in the PASS line)."""
        return self.config.describe()


def build_spike_command(
    spike: str | Path, elf: str | Path, *, config: GoldenConfig, log_path: Path
) -> list[str]:
    """Argv used for a commit-logged run (exposed so tests can assert it)."""
    return [
        str(spike),
        f"--isa={config.isa}",
        *config.arguments(),
        "-l",  # disassembly in the log: human debugging, ignored by the parser
        "--log-commits",  # ONE line per retired instruction: priv pc (insn) regs mem
        f"--log={log_path}",
        str(elf),
    ]


def spike_environment() -> dict[str, str]:
    """``os.environ`` plus the harness's ``dtc`` directory on PATH.

    Spike spawns ``dtc`` at run time to build its device tree; without it Spike
    cannot boot the ELF at all ("Failed to run dtc"). The harness builds dtc next
    to Spike, so make sure the child process can find it.
    """
    env = dict(os.environ)
    dtc_dir = default_dtc_dir()
    if dtc_dir is not None and shutil.which("dtc", path=env.get("PATH", "")) is None:
        env["PATH"] = f"{dtc_dir}{os.pathsep}{env.get('PATH', '')}"
    return env


def run_spike(
    elf: str | Path,
    *,
    spike: str | Path | None = None,
    config: GoldenConfig | None = None,
    isa: str = DEFAULT_ISA,
    timeout: float = 300.0,
) -> SpikeRun:
    """Run ``elf`` under Spike and return its normalized commit trace.

    ``config`` pins the run: memory window, device tree, bootargs, start PC and
    the stop event. Omitting it reproduces the historical run exactly — corpus
    ISA, Spike's default memory, its auto-generated device tree, the ELF entry
    point and the ``tohost`` symbol as the stop.
    """
    golden = config if config is not None else GoldenConfig(isa=isa)
    binary = find_spike(spike)
    elf_path = Path(elf)
    if not elf_path.is_file():
        raise SpikeError(f"ELF not found: {elf_path}")
    image = load_elf_image(elf_path)
    stop = golden.stop if golden.stop is not None else StopStore(image.tohost)
    entry = golden.pc if golden.pc is not None else image.entry
    with tempfile.TemporaryDirectory(prefix="rv_difftest_spike_") as tmpdir:
        log_path = Path(tmpdir) / "spike.log"
        argv = build_spike_command(binary, elf_path, config=golden, log_path=log_path)
        try:
            proc = subprocess.run(
                argv,
                capture_output=True,
                text=True,
                check=False,
                timeout=timeout,
                env=spike_environment(),
            )
        except subprocess.TimeoutExpired:
            raise SpikeError(
                f"spike timed out after {timeout:.0f}s on {elf_path.name}: the stopping "
                f"store ({stop.describe()}) was never retired"
            ) from None
        except OSError as exc:
            raise SpikeError(f"cannot execute {binary}: {exc}") from None
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    if proc.returncode != 0:
        raise SpikeError(
            f"spike exited with {proc.returncode} on {elf_path.name}: "
            f"{(proc.stderr or proc.stdout or '').strip()[:400]}"
        )
    commits = normalize_spike_log(log, source=f"spike:{elf_path.name}", stop=stop, entry=entry)
    if not commits:
        raise SpikeError(
            f"spike produced no commit lines for {elf_path.name} — is the ELF loadable "
            f"and built for {golden.isa}?"
        )
    return SpikeRun(
        spike=binary,
        version=spike_version(binary),
        elf=elf_path,
        isa=golden.isa,
        config=golden,
        returncode=proc.returncode,
        log=log,
        commits=commits,
    )


def is_spike_log(text: str) -> bool:
    """True when ``text`` looks like Spike's ``--log-commits`` output."""
    return any(_COMMIT_RE.match(line) for line in text.splitlines())


def normalize_spike_log(
    text: str,
    *,
    source: str = "<spike log>",
    stop: StopStore | None = None,
    entry: int | None = None,
) -> list[Commit]:
    """Convert Spike's ``--log-commits`` output into canonical commits.

    Lines that are not commit lines (``-l`` disassembly, the debug ROM banner,
    HTIF chatter) are ignored. ``cycle`` is the 1-based retirement ordinal —
    Spike has no cycle concept to offer. Malformed commit lines raise
    :class:`~rv_trace.TraceFormatError` so a changed Spike log format fails loudly
    instead of silently producing an empty/short golden stream.

    ``entry``: start at the first commit at the ELF entry point. Spike boots
    through its own debug ROM (``0x1000``: ``auipc`` / ``csrr mhartid`` /
    ``ld`` / ``jr``), which is not part of the DUT and must not be diffed.

    ``stop``: drop everything after the store named by the :class:`StopStore`.
    Spike keeps committing the program's final spin loop for thousands of
    instructions after an exit store arms the HTIF, and the DUT stops at the
    store — so the stopping event is where the golden stream ends. The default
    (``stop=None`` here; ``--stop-store`` on the CLI) is the ``tohost`` mailbox,
    which is the corpus's exit protocol.
    """
    commits = [commit for _, commit in iter_spike_commits(text, source=source, stop=stop, entry=entry)]
    if stop is not None and not (
        commits and stop.matches(commits[-1].mem_addr, commits[-1].mem_wdata)
    ):
        raise TraceFormatError(
            f"the stream does not end at the stopping store ({stop.describe()}): the "
            "stop event was never retired",
            source=source,
        )
    return commits


def iter_spike_commits(
    text: str,
    *,
    source: str = "<spike log>",
    stop: StopStore | None = None,
    entry: int | None = None,
) -> Iterator[tuple[int, Commit]]:
    """Yield ``(0-based line index, commit)`` for the commits that make up the golden stream."""
    index = 0
    reached_entry = entry is None
    for lineno, raw in enumerate(text.splitlines()):
        match = _COMMIT_RE.match(raw)
        if match is None:
            continue
        pc = int(match.group("pc"), 16)
        if not reached_entry:
            reached_entry = pc == entry
            if not reached_entry:
                continue
        insn = int(match.group("insn"), 16)
        rest = match.group("rest")
        rd: int | None = None
        value: int | None = None
        for reg_match in _XREG_RE.finditer(rest):
            reg = int(reg_match.group("rd"))
            if reg == 0:  # pragma: no cover - Spike never logs x0
                continue
            if rd is not None:
                raise TraceFormatError(
                    "spike commit line updates more than one integer register",
                    source=source,
                    line=lineno + 1,
                )
            rd = reg
            value = int(reg_match.group("value"), 16)
        fp_rd: int | None = None
        fp_value: int | None = None
        for freg_match in _FREG_RE.finditer(rest):
            if fp_rd is not None:
                raise TraceFormatError(
                    "spike commit line updates more than one floating-point register",
                    source=source,
                    line=lineno + 1,
                )
            fp_rd = int(freg_match.group("rd"))
            fp_value = int(freg_match.group("value"), 16)
        if rd is not None and fp_rd is not None:
            # one commit record carries one architectural write: a line that
            # updates both classes cannot be normalized without dropping one
            raise TraceFormatError(
                "spike commit line updates both an integer and a floating-point register",
                source=source,
                line=lineno + 1,
            )
        is_fp_write = fp_rd is not None
        if is_fp_write:
            # f0 is a real register, so it is kept (unlike x0 above)
            rd, value = fp_rd, fp_value
        # Spike's `mem` fields: zero (an instruction with no memory access), one
        # (a load's address, or a store's address + data) or TWO for an AMO — the
        # read of the old value followed by the write of the result, both at the
        # same address. A read-modify-write is one architectural memory access, so
        # the canonical record keeps the WRITE (the last field): its data is the
        # value stored back and `rd` carries the old value, which is what pins the
        # whole RMW. Anything else with more than one access is a log the harness
        # does not understand and must not silently normalize.
        mems = [
            (int(m.group("addr"), 16), None if m.group("data") is None else int(m.group("data"), 16))
            for m in _MEM_RE.finditer(rest)
        ]
        mem_addr: int | None = None
        mem_wdata: int | None = None
        if len(mems) == 1:
            mem_addr, mem_wdata = mems[0]
        elif len(mems) == 2:
            (read_addr, read_data), (write_addr, write_data) = mems
            if read_data is not None or write_data is None or read_addr != write_addr:
                raise TraceFormatError(
                    "spike commit line reports two memory accesses that are not an "
                    f"AMO's read-then-write at one address: 0x{read_addr:x} "
                    f"({'-' if read_data is None else f'0x{read_data:x}'}) then "
                    f"0x{write_addr:x} ({'-' if write_data is None else f'0x{write_data:x}'})",
                    source=source,
                    line=lineno + 1,
                )
            mem_addr, mem_wdata = write_addr, write_data
        elif len(mems) > 2:
            raise TraceFormatError(
                f"spike commit line reports {len(mems)} memory accesses",
                source=source,
                line=lineno + 1,
            )
        keyed: dict[str, int] = {}
        for csr_match in _CSR_RE.finditer(rest):
            name = csr_match.group("name")
            if name not in _FP_CSR_NAMES:
                continue  # an integer CSR (c768_mstatus …): no canonical field
            if name in keyed:
                raise TraceFormatError(
                    f"spike commit line updates {name} more than once",
                    source=source,
                    line=lineno + 1,
                )
            keyed[name] = int(csr_match.group("value"), 16)
        yield lineno, Commit(
            cycle=index + 1,
            pc=pc,
            rd=rd,
            value=value,
            insn=insn,
            mem_addr=mem_addr,
            mem_wdata=mem_wdata,
            rd_is_fp=is_fp_write,
            fflags=keyed.get("fflags"),
            frm=keyed.get("frm"),
        )
        index += 1
        if stop is not None and _writes_stop(rest, stop):
            return


def last_golden_line(
    text: str, *, source: str = "<spike log>", stop: StopStore | None, entry: int | None
) -> int:
    """0-based index of the last line the golden stream consumes, or ``-1`` if none."""
    last = -1
    for lineno, _ in iter_spike_commits(text, source=source, stop=stop, entry=entry):
        last = lineno
    return last


def _writes_stop(rest: str, stop: StopStore) -> bool:
    """True when a commit line's ``mem`` field stores the stopping value.

    A store is what Spike logs *with* data, so the ``data`` group is what
    distinguishes the stopping store from the address-only entry of a load; an
    AMO's trailing read-modify-write field is the store and is the one kept.
    """
    for mem in _MEM_RE.finditer(rest):
        data = mem.group("data")
        if data is None:
            continue
        if stop.matches(int(mem.group("addr"), 16), int(data, 16)):
            return True
    return False


def trace_text_for_elf(
    elf: str | Path,
    *,
    spike: str | Path | None = None,
    config: GoldenConfig | None = None,
    isa: str = DEFAULT_ISA,
    timeout: float = 300.0,
) -> tuple[str, SpikeRun]:
    """Run Spike and return ``(canonical trace text, run metadata)``."""
    run = run_spike(elf, spike=spike, config=config, isa=isa, timeout=timeout)
    return format_trace(run.commits, generator=run.describe()), run
