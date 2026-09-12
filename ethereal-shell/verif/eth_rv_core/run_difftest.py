#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""RTL half of the ``eth_rv`` DiffTest loop: run the corpus on the Verilated core.

Pipeline per corpus ELF (C14 §5):

1. load the ELF with the harness's own image loader (``rv_image`` — the harness is
   used, never modified),
2. flatten it into the ``$readmemh`` image the testbench consumes
   (``tb_eth_rv_core.sv``),
3. build/run the Verilator ``--binary --timing`` model, which dumps one
   ``cycle pc rd value`` line per retired instruction plus the optional
   ``mem_addr mem_wdata mem_rmask mem_wmask`` suffix (C14 §5.2),
4. hand that dump to ``rv_difftest.py --dut dump:...`` for comparison against the
   Spike golden stream — pc/rd/value *and* the memory stream — and propagate its
   verdict,
5. for the console (C14 §8 checkpoint 5): the testbench decodes the SoC UART's
   serial line at its own divisor and writes what it received to ``+uart=<file>``;
   every program is held to its `EXPECTED_UART` payload — `cor_hello` to its
   string, every other program to an idle line (`cor_fault` included: its
   rejected stores must never reach the transmit register).

Exit status: ``0`` when every requested ELF MATCHes and every console payload is
the expected one (and, for ``--fault``/``--uart-fault``, when the injected fault
is caught), ``1`` otherwise, ``2`` on a setup/toolchain error.

Examples::

    # all eight corpus programs
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --all

    # one program, with a one-cycle-latency memory (exercises the stall path)
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_model --memlat 1

    # negative control: corrupt one trace record and watch the harness catch it
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_alu --fault 12:value=0xdeadbeef

    # the same corpus with the D port on AXI4 into the DRAM socket (8-beat reads)
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --all --dram

    # negative control for the UART: break one bit cell of the first byte on the line
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_hello --uart-fault 0:1
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
RTL_DIR = REPO_ROOT / "ethereal-shell" / "rtl" / "eth_rv"
HARNESS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv"
DEFAULT_CORPUS = REPO_ROOT / "generated" / "rv_difftest" / "corpus"
DEFAULT_WORK = REPO_ROOT / "generated" / "rv_difftest" / "rtl"

MEM_BASE = 0x8000_0000
"""Corpus link base (corpus/link.ld) == the core's reset PC (eth_rv_pkg RESET_PC)."""

MEM_WINDOW_BYTES = 32_768 * 8
"""Must match ``MEM_WORDS`` in tb_eth_rv_core.sv (256 KiB)."""

RTL_SOURCES = [
    RTL_DIR / "eth_rv_pkg.sv",
    RTL_DIR / "cor_alu.sv",
    RTL_DIR / "cor_muldiv.sv",
    RTL_DIR / "cor_lsu.sv",
    RTL_DIR / "cor_regfile.sv",
    RTL_DIR / "cor_decoder.sv",
    RTL_DIR / "eth_rv_core.sv",
    # SoC MMIO: the console UART and the address decoder in front of the D port
    # (C14 §4). Both sit in front of either memory path, so they are part of
    # every build.
    RTL_DIR / "eth_rv_uart.sv",
    RTL_DIR / "eth_rv_mmio_mux.sv",
]

# `--dram` build only: the AXI4 master in front of the DRAM socket (C14 §4/§6).
DRAM_SOURCES = [
    RTL_DIR / "eth_rv_axi_master.sv",
    REPO_ROOT / "ethereal-shell" / "rtl" / "dram" / "eth_dram_stub.sv",
    REPO_ROOT / "ethereal-shell" / "rtl" / "dram" / "eth_dram_ctrl.sv",
]
TB_SOURCE = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "tb_eth_rv_core.sv"

CORPUS_PROGRAMS = [
    "cor_alu",
    "cor_mem",
    "cor_muldiv",
    "cor_model",
    "cor_csr",
    "cor_trap",
    # E2-RV1 increment 6: privilege modes, S-mode CSRs, trap delegation and the
    # program-driven interrupt sources (see verif/eth_rv/README.md).
    "cor_priv",
    "cor_deleg",
    "cor_intr",
    "cor_time",
    "cor_hello",
    "cor_fault",
]

HELLO_STRING = b"hello, eth_rv!\n"
"""The console string ``corpus/cor_hello.S`` writes — the C14 §8 checkpoint 5 vehicle.

The testbench decodes the SoC UART's serial line at its own divisor and writes
what it received to ``+uart=<file>``; every program is then held to its expected
payload below. `test_rv_uart.py` re-reads this constant against `cor_hello.S`,
so the program and the assertion cannot drift apart."""

EXPECTED_UART: dict[str, bytes] = {"cor_hello": HELLO_STRING}
"""Expected console output per corpus program: only `hello` uses the UART, and
the other programs must leave the line completely idle (a stray device access
would show up here as bytes nobody asked for). `cor_fault` writes a byte to the
UART's scratch register, so a line that is NOT idle there means a non-byte store
was transmitted instead of rejected."""

UART_RECORD_PATTERN = re.compile(
    r"^# eth_rv uart rx v1\n"
    r"# bit_cycles: (?P<bit>\d+) frame_cycles: (?P<frame>\d+) bytes: (?P<bytes>\d+) "
    r"frames: (?P<frames>\d+) errors: (?P<errors>\d+) overflow: (?P<overflow>\d+) "
    r"drain_cycles: (?P<drain>\d+)\n"
    r"# gap_min: (?P<gap_min>\d+) gap_max: (?P<gap_max>\d+)\n"
    r"data: (?P<data>[0-9a-f]*)\n$"
)

DIVERGE_RE = re.compile(r"DIVERGENCE \((\w+)\) at commit #(\d+) \(cycle (\d+)\)")

sys.path.insert(0, str(HARNESS_DIR))

from rv_image import load_elf_image  # (imported after the sys.path insert above)


class SetupError(RuntimeError):
    """The run cannot start (toolchain, corpus, image or build problem)."""


def _tool(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise SetupError(
            f"{name} not found on PATH "
            "(verilator: PATH=$HOME/oss-cad-suite/bin:$PATH; corpus: riscv64-unknown-elf-gcc)"
        )
    return found


def run(
    argv: list[str], *, cwd: Path | None = None, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    """Run a command, echoing it unless quiet; raises SetupError on a missing tool."""
    if not quiet:
        print(f"  $ {' '.join(argv)}", flush=True)
    try:
        return subprocess.run(
            argv, cwd=cwd, capture_output=True, text=True, check=False, timeout=1800
        )
    except FileNotFoundError as exc:  # pragma: no cover - guarded by _tool()
        raise SetupError(str(exc)) from None
    except subprocess.TimeoutExpired:
        raise SetupError(f"timeout: {' '.join(argv)}") from None


def build_corpus(corpus_dir: Path) -> None:
    """Build the bare-metal corpus ELFs if they are not there yet."""
    if all((corpus_dir / f"{name}.elf").is_file() for name in CORPUS_PROGRAMS):
        return
    print(f"[rv-rtl] corpus missing under {corpus_dir}, building it")
    builder = HARNESS_DIR / "corpus" / "build_corpus.py"
    done = run([sys.executable, str(builder), "--out", str(corpus_dir)], cwd=REPO_ROOT)
    if done.returncode != 0:
        raise SetupError(f"corpus build failed:\n{done.stdout}\n{done.stderr}")


def write_memory_image(elf: Path, image_path: Path) -> tuple[int, int]:
    """Flatten an ELF into the ``$readmemh`` image the testbench loads.

    Returns ``(tohost, word_count)``. Words are indexed from :data:`MEM_BASE`, so
    the file's address N is the 64-bit word at ``MEM_BASE + 8*N`` — the same
    mapping ``tb_eth_rv_core.sv`` uses.
    """
    image = load_elf_image(elf)
    if image.entry != MEM_BASE:
        raise SetupError(
            f"{elf.name}: entry 0x{image.entry:016x} != core reset PC 0x{MEM_BASE:016x} "
            "(the v0 TB loads a window based at the corpus link address)"
        )
    words: dict[int, bytearray] = {}
    for addr, data in image.segments:
        for offset, byte in enumerate(data):
            where = addr + offset
            if not MEM_BASE <= where < MEM_BASE + MEM_WINDOW_BYTES:
                raise SetupError(
                    f"{elf.name}: segment byte 0x{where:016x} is outside the "
                    f"0x{MEM_BASE:016x}..0x{MEM_BASE + MEM_WINDOW_BYTES:016x} window"
                )
            index = (where - MEM_BASE) >> 3
            slot = words.setdefault(index, bytearray(8))
            slot[where & 7] = byte
    lines = []
    for index in sorted(words):
        lines.append(f"@{index:08x}")
        # $readmemh reads the first character as the MSB, so a little-endian
        # word lands in the file byte-reversed.
        lines.append(bytes(words[index][::-1]).hex())
    image_path.write_text("\n".join(lines) + "\n", encoding="ascii")
    return image.tohost, len(words)


def build_model(
    work_dir: Path, mem_lat: int, rebuild: bool, *, dram: bool = False, line_beats: int = 8
) -> Path:
    """Verilate + compile the testbench; returns the executable path.

    ``dram`` selects the AXI4 D-port build (``-DETH_RV_DRAM_AXI``): the core's
    data port goes through ``eth_rv_axi_master`` into ``eth_dram_ctrl`` +
    ``eth_dram_stub`` instead of the testbench's behavioral beat memory, and
    ``line_beats`` picks the master's read line fill (>1 = INCR bursts).
    """
    verilator = _tool("verilator")
    mode = f"dram{line_beats}" if dram else "beat"
    obj_dir = work_dir / f"obj_{mode}_lat{mem_lat}"
    exe = obj_dir / "Veth_rv_tb"
    sources = [*RTL_SOURCES, *(DRAM_SOURCES if dram else [])]
    if exe.is_file() and not rebuild and not _stale(exe, sources):
        return exe
    obj_dir.mkdir(parents=True, exist_ok=True)
    defines = [f"-DETH_RV_LINE_BEATS={line_beats}"] if dram else []
    if dram:
        defines.insert(0, "-DETH_RV_DRAM_AXI")
    argv = [
        verilator,
        "--binary",
        "--timing",
        "--top-module",
        "tb_eth_rv_core",
        "-Mdir",
        str(obj_dir),
        "-o",
        "Veth_rv_tb",
        *defines,
        *[str(path) for path in sources],
        str(TB_SOURCE),
    ]
    done = run(argv, cwd=REPO_ROOT)
    if done.returncode != 0 or not exe.is_file():
        raise SetupError(f"verilator build failed:\n{done.stdout}\n{done.stderr}")
    return exe


@dataclass(frozen=True, slots=True)
class RtlRun:
    """Outcome of one testbench invocation."""

    elf: Path
    trace: Path
    commits: int
    status: str
    stdout: str
    uart: UartRecord


@dataclass(frozen=True, slots=True)
class UartRecord:
    """What the testbench's receiver decoded off the console UART's serial line.

    The testbench samples each 8N1 frame at the center of its ten bit cells with
    the same divisor the transmitter was built with, so these fields are a
    bit-timing statement, not just a byte count: `frame_cycles` is the exact
    length of a frame, and `gap_min`/`gap_max` are the measured start-edge-to-
    start-edge distances inside the burst (they must all equal `frame_cycles`).
    """

    bit_cycles: int
    frame_cycles: int
    header_bytes: int
    data: bytes
    frames: int
    errors: int
    overflow: bool
    drain_cycles: int
    gap_min: int
    gap_max: int

    @property
    def text(self) -> str:
        """The received bytes as text (latin-1: the assertion is byte-exact)."""
        return self.data.decode("latin-1")


def parse_uart_record(path: Path) -> UartRecord:
    """Parse the `+uart=<file>` record; a malformed record is a setup error."""
    match = UART_RECORD_PATTERN.match(path.read_text(encoding="ascii"))
    if match is None:
        raise SetupError(f"{path}: not an eth_rv UART record (see tb_eth_rv_core.sv)")
    return UartRecord(
        bit_cycles=int(match.group("bit")),
        frame_cycles=int(match.group("frame")),
        header_bytes=int(match.group("bytes")),
        data=bytes.fromhex(match.group("data")),
        frames=int(match.group("frames")),
        errors=int(match.group("errors")),
        overflow=bool(int(match.group("overflow"))),
        drain_cycles=int(match.group("drain")),
        gap_min=int(match.group("gap_min")),
        gap_max=int(match.group("gap_max")),
    )


def uart_problems(record: UartRecord, expected: bytes) -> list[str]:
    """Every way the console evidence can fail to be the string the program wrote.

    The checks are the point of checkpoint 5, so they are stated separately and
    reported verbatim: the byte string, the frame count that carried it, the
    framing (start/stop) errors, the bit rate of every inter-frame gap, and the
    "no byte was dropped" condition at the transmitter.
    """
    problems: list[str] = []
    if record.data != expected:
        problems.append(f"payload {record.text!r} != expected {expected.decode('latin-1')!r}")
    if record.header_bytes != len(record.data):
        problems.append(
            f"header says {record.header_bytes} bytes, payload carries {len(record.data)}"
        )
    if record.frames != len(record.data):
        problems.append(f"{record.frames} frames carried {len(record.data)} bytes")
    if record.errors:
        problems.append(f"{record.errors} framing error(s)")
    if record.overflow:
        problems.append("the transmit queue overflowed (bytes were dropped)")
    if record.frame_cycles != 10 * record.bit_cycles:
        problems.append(
            f"frame_cycles {record.frame_cycles} != 10 * bit_cycles {record.bit_cycles}"
        )
    if record.frames > 1 and (record.gap_min, record.gap_max) != (
        record.frame_cycles,
        record.frame_cycles,
    ):
        problems.append(
            f"bit timing: inter-frame gap {record.gap_min}..{record.gap_max} cycles, "
            f"expected exactly {record.frame_cycles}"
        )
    return problems


def report_uart(
    name: str, record: UartRecord, expected: bytes, *, expect_fault: bool
) -> int:
    """Print the console-UART verdict for one program; returns the failure count.

    In the normal mode a program must have emitted exactly its expected payload
    and nothing else (`EXPECTED_UART`); with `--uart-fault` the injected line
    fault must instead have BROKEN that assertion — the negative control that
    shows the check is live rather than tautological.
    """
    problems = uart_problems(record, expected)
    # `ascii()` is repr with the non-ASCII bytes escaped: the payload is printed
    # the way a log line should show it (a `\n` stays visible, a stray 0xE9 does
    # not reach the terminal raw).
    payload = ascii(record.text)
    detail = (
        f"{record.frames} frames of {record.frame_cycles} cycles "
        f"({record.bit_cycles}-cycle bit cell), gap {record.gap_min}..{record.gap_max}, "
        f"{record.errors} frame error(s), drain {record.drain_cycles} cycles"
    )
    if not expect_fault:
        if problems:
            print(f"[rv-rtl] {name}: UART FAIL: {'; '.join(problems)}")
            return 1
        print(f"[rv-rtl] {name}: UART {len(record.data)} bytes {payload} — {detail}")
        return 0
    if not expected:
        print(f"[rv-rtl] {name}: UART idle, no line-fault target (nothing to corrupt)")
        return 0
    if problems:
        print(f"[rv-rtl] {name}: UART negative control caught: {'; '.join(problems)}")
        return 0
    print(f"[rv-rtl] {name}: UART negative control NOT caught (payload {payload} arrived intact)")
    return 1


def _stale(exe: Path, sources: list[Path]) -> bool:
    """True when any RTL/TB source is newer than the built model."""
    built = exe.stat().st_mtime
    return any(path.stat().st_mtime > built for path in [*sources, TB_SOURCE])


def run_rtl(
    exe: Path,
    elf: Path,
    work_dir: Path,
    *,
    mem_lat: int,
    fault: str | None,
    quiet: bool,
    uart_fault: str | None = None,
) -> RtlRun:
    """Run the RTL on one ELF; produce its commit trace and console record.

    `+uart=<file>` asks the testbench for what its receiver decoded off the
    console UART's serial line (the C14 §8 checkpoint 5 evidence), and
    `uart_fault` = ``FRAME:BIT`` inverts one bit cell of one received frame — the
    negative control that proves the UART assertion is live.
    """
    stem = elf.stem if fault is None else f"{elf.stem}.fault"
    image_path = work_dir / f"{elf.stem}.mem.hex"
    trace_path = work_dir / f"{stem}.trace"
    uart_path = work_dir / f"{elf.stem}.uart"
    tohost, _ = write_memory_image(elf, image_path)
    argv = [
        str(exe),
        f"+mem={image_path}",
        f"+trace={trace_path}",
        f"+uart={uart_path}",
        f"+base=0x{MEM_BASE:x}",
        f"+tohost=0x{tohost:x}",
        f"+memlat={mem_lat}",
    ]
    if fault is not None:
        index, field, value = parse_fault(fault)
        argv += [f"+fault_index={index}", f"+fault_field={field}", f"+fault_value=0x{value:x}"]
    if uart_fault is not None:
        frame, bit = parse_uart_fault(uart_fault)
        argv += [f"+uart_fault_frame={frame}", f"+uart_fault_bit={bit}"]
    done = run(argv, cwd=REPO_ROOT, quiet=quiet)
    banner = "ETH_RV_TB:"
    status = next(
        (line for line in done.stdout.splitlines() if line.startswith(banner)),
        f"{banner} no status line (exit {done.returncode})",
    )
    if "PASS" not in status:
        raise SetupError(f"{elf.name}: RTL run did not complete cleanly: {status}\n{done.stdout}")
    commits = int(re.search(r"PASS (\d+) commits", status).group(1))  # type: ignore[union-attr]
    return RtlRun(
        elf=elf,
        trace=trace_path,
        commits=commits,
        status=status,
        stdout=done.stdout,
        uart=parse_uart_record(uart_path),
    )


def parse_uart_fault(spec: str) -> tuple[int, int]:
    """``FRAME:BIT`` -> ``(frame, bit)`` for the UART line-fault negative control.

    ``BIT`` is a bit cell of the frame (0 = start, 1..8 = data LSB first,
    9 = stop); the testbench inverts the line for the whole cell, so the received
    byte — or the frame's framing — must change.
    """
    match = re.fullmatch(r"(\d+):(\d+)", spec.strip())
    if match is None or int(match.group(2)) > 9:
        raise SetupError(f"--uart-fault wants FRAME:BIT (BIT 0..9), got {spec!r}")
    return int(match.group(1)), int(match.group(2))


def parse_fault(spec: str) -> tuple[int, str, int]:
    """``INDEX:FIELD=VALUE`` -> ``(index, field, value)`` (same shape as --inject).

    ``mem_addr``/``mem_wdata`` corrupt the memory stream the trace reports, which
    is the negative control for the memory comparison (C14 §5.2).
    """
    match = re.fullmatch(
        r"(\d+):(pc|rd|value|mem_addr|mem_wdata)=(0x[0-9a-fA-F]+|\d+)", spec.strip()
    )
    if match is None:
        raise SetupError(
            f"--fault wants INDEX:{{pc,rd,value,mem_addr,mem_wdata}}=VALUE, got {spec!r}"
        )
    return int(match.group(1)), match.group(2), int(match.group(3), 0)


def compare(elf: Path, trace: Path, *, quiet: bool) -> tuple[bool, str]:
    """Run the harness comparator against the RTL dump; returns (matched, report)."""
    argv = [
        sys.executable,
        str(HARNESS_DIR / "rv_difftest.py"),
        "--elf",
        str(elf),
        "--dut",
        f"dump:{trace}",
    ]
    done = run(argv, cwd=HARNESS_DIR, quiet=quiet)
    report = (done.stdout + done.stderr).strip()
    return done.returncode == 0, report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="run_difftest.py",
        description="Run the eth_rv RTL on the DiffTest corpus and compare it with Spike",
    )
    pick = parser.add_mutually_exclusive_group()
    pick.add_argument("--all", action="store_true", help="run every corpus program (default)")
    pick.add_argument("--only", action="append", default=[], help="program name (repeatable)")
    parser.add_argument("--corpus-dir", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--work-dir", type=Path, default=DEFAULT_WORK)
    parser.add_argument("--memlat", type=int, default=0, help="memory latency in cycles")
    parser.add_argument(
        "--fault",
        default=None,
        help=(
            "negative control: INDEX:{pc,rd,value,mem_addr,mem_wdata}=VALUE corrupts one "
            "trace record (the mem_* fields exercise the memory comparison)"
        ),
    )
    parser.add_argument("--rebuild", action="store_true", help="force a Verilator rebuild")
    parser.add_argument(
        "--dram",
        action="store_true",
        help=(
            "drive the D port through eth_rv_axi_master into eth_dram_ctrl + "
            "eth_dram_stub (full AXI4 INCR) instead of the behavioral beat memory"
        ),
    )
    parser.add_argument(
        "--uart-fault",
        default=None,
        help=(
            "negative control for the console-UART assertion: FRAME:BIT inverts one bit "
            "cell of one received frame on the line (the trace must still MATCH and the "
            "string check must fail)"
        ),
    )
    parser.add_argument(
        "--axi-line-beats",
        type=int,
        default=8,
        choices=(1, 2, 4, 8, 16),
        help="--dram: read line fill in beats (1 = one beat per transaction, the default is 8)",
    )
    parser.add_argument("--quiet", action="store_true", help="only print the harness verdicts")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    programs = args.only if args.only else list(CORPUS_PROGRAMS)
    try:
        build_corpus(args.corpus_dir)
        args.work_dir.mkdir(parents=True, exist_ok=True)
        exe = build_model(
            args.work_dir,
            args.memlat,
            args.rebuild,
            dram=args.dram,
            line_beats=args.axi_line_beats,
        )
    except SetupError as exc:
        sys.stderr.write(f"[rv-rtl] error: {exc}\n")
        return 2
    if args.dram:
        print(
            f"[rv-rtl] D port: eth_rv_axi_master -> eth_dram_ctrl (+stub), "
            f"read line fill {args.axi_line_beats} beat(s)"
        )

    failures = 0
    for name in programs:
        elf = args.corpus_dir / f"{name}.elf"
        if not elf.is_file():
            sys.stderr.write(f"[rv-rtl] error: no such corpus ELF: {elf}\n")
            return 2
        try:
            rtl = run_rtl(
                exe,
                elf,
                args.work_dir,
                mem_lat=args.memlat,
                fault=args.fault,
                quiet=args.quiet,
                uart_fault=args.uart_fault,
            )
        except SetupError as exc:
            sys.stderr.write(f"[rv-rtl] error: {exc}\n")
            return 2

        expected = EXPECTED_UART.get(name, b"")
        if args.fault is None:
            matched, report = compare(elf, rtl.trace, quiet=args.quiet)
            print(f"[rv-rtl] {name}: {rtl.status}")
            print(report)
            failures += report_uart(
                name, rtl.uart, expected, expect_fault=args.uart_fault is not None
            )
            if not matched:
                failures += 1
        else:
            index, field, value = parse_fault(args.fault)
            matched, report = compare(elf, rtl.trace, quiet=args.quiet)
            print(f"[rv-rtl] {name}: negative control {field}@#{index}=0x{value:x}")
            print(report)
            caught = DIVERGE_RE.search(report)
            if matched or caught is None or int(caught.group(2)) != index:
                sys.stderr.write(
                    f"[rv-rtl] error: fault injection not caught at commit #{index}\n"
                )
                failures += 1
            else:
                print(
                    f"[rv-rtl] OK: harness caught the injected {field} fault at commit "
                    f"#{caught.group(2)} (cycle {caught.group(3)}, kind {caught.group(1)})"
                )

    if failures:
        print(f"[rv-rtl] FAIL: {failures} of {len(programs)} corpus program(s) did not match")
        return 1
    if args.fault is not None:
        verb = "negative control caught"
    elif args.uart_fault is not None:
        verb = "MATCH vs Spike + UART negative control caught"
    else:
        verb = "MATCH vs Spike + console asserted"
    print(f"[rv-rtl] OK: {len(programs)} corpus program(s), {verb}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
