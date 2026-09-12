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
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from rv_image import load_elf_image
from rv_trace import Commit, TraceFormatError, format_trace

DEFAULT_ISA = "rv64imafdc_zicsr_zicntr"
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


def repo_root() -> Path | None:
    """Repository root (the directory holding ``AGENTS.md``), or ``None`` if not found."""
    for parent in Path(__file__).resolve().parents:
        if (parent / "AGENTS.md").is_file():
            return parent
    return None


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

    def describe(self) -> str:
        """One-line provenance string used in ``rv_difftest`` summaries."""
        return f"spike[{self.isa}] {self.elf.name} ({self.version})"


def build_spike_command(spike: str | Path, elf: str | Path, *, isa: str, log_path: Path) -> list[str]:
    """Argv used for a commit-logged run (exposed so tests can assert it)."""
    return [
        str(spike),
        f"--isa={isa}",
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
    isa: str = DEFAULT_ISA,
    timeout: float = 300.0,
) -> SpikeRun:
    """Run ``elf`` under Spike and return its normalized commit trace."""
    binary = find_spike(spike)
    elf_path = Path(elf)
    if not elf_path.is_file():
        raise SpikeError(f"ELF not found: {elf_path}")
    with tempfile.TemporaryDirectory(prefix="rv_difftest_spike_") as tmpdir:
        log_path = Path(tmpdir) / "spike.log"
        argv = build_spike_command(binary, elf_path, isa=isa, log_path=log_path)
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
                f"spike timed out after {timeout:.0f}s on {elf_path.name}: the program "
                "never wrote a non-zero value to `tohost` (the corpus exit protocol)"
            ) from None
        except OSError as exc:
            raise SpikeError(f"cannot execute {binary}: {exc}") from None
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    if proc.returncode != 0:
        raise SpikeError(
            f"spike exited with {proc.returncode} on {elf_path.name}: "
            f"{(proc.stderr or proc.stdout or '').strip()[:400]}"
        )
    image = load_elf_image(elf_path)
    commits = normalize_spike_log(
        log, source=f"spike:{elf_path.name}", tohost=image.tohost, entry=image.entry
    )
    if not commits:
        raise SpikeError(
            f"spike produced no commit lines for {elf_path.name} — is the ELF loadable "
            f"and built for {isa}?"
        )
    return SpikeRun(
        spike=binary,
        version=spike_version(binary),
        elf=elf_path,
        isa=isa,
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
    tohost: int | None = None,
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

    ``tohost``: drop everything after the store that writes the HTIF mailbox.
    Spike keeps committing the program's final spin loop for thousands of
    instructions after the exit store arms the HTIF, and the DUT stops at the
    store — so the mailbox address is where the golden stream ends.
    """
    return [commit for _, commit in iter_spike_commits(text, source=source, tohost=tohost, entry=entry)]


def iter_spike_commits(
    text: str,
    *,
    source: str = "<spike log>",
    tohost: int | None = None,
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
        if tohost is not None and _writes_htif_mailbox(rest, tohost):
            return


def last_golden_line(text: str, *, source: str = "<spike log>", tohost: int | None, entry: int | None) -> int:
    """0-based index of the last line the golden stream consumes, or ``-1`` if none."""
    last = -1
    for lineno, _ in iter_spike_commits(text, source=source, tohost=tohost, entry=entry):
        last = lineno
    return last


def _writes_htif_mailbox(rest: str, tohost: int) -> bool:
    """True when a commit line's ``mem`` field stores to the HTIF mailbox.

    The mailbox store is a store, so Spike logs data with it — the ``data`` group
    is what distinguishes a store from the address-only entry of a load.
    """
    return any(
        int(mem.group("addr"), 16) == tohost and mem.group("data") is not None
        for mem in _MEM_RE.finditer(rest)
    )



def trace_text_for_elf(
    elf: str | Path,
    *,
    spike: str | Path | None = None,
    isa: str = DEFAULT_ISA,
    timeout: float = 300.0,
) -> tuple[str, SpikeRun]:
    """Run Spike and return ``(canonical trace text, run metadata)``."""
    run = run_spike(elf, spike=spike, isa=isa, timeout=timeout)
    return format_trace(run.commits, generator=run.describe()), run
