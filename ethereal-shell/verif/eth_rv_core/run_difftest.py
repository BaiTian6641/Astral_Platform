#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""RTL half of the ``eth_rv`` DiffTest loop: run the corpus on the Verilated core.

Pipeline per corpus ELF (C14 §5):

1. load the ELF with the harness's own image loader (``rv_image``) and flatten it
   into the ``$readmemh`` image the testbench consumes (``tb_eth_rv_core.sv``);
   the payload entry no longer has to be the window base (`--rom`/`+entry=`),
2. hand the testbench the boot contract: the window size it was compiled with
   (`+mem_bytes=`), the BootROM (`+rom=`), the device tree at ``DTB_ADDR``
   (`+dtb=`, also woven into the memory image) and the stop event
   (`+stop_addr=`/`+stop_value=`),
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

    # boot path: a BootROM image, the device tree at the contract address, and the
    # golden pinned to the same 1 MiB window the TB was compiled with
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_model \\
        --rom ethereal-shell/rtl/eth_rv/rom/boot_rom.hex \\
        --dtb ethereal-shell/verif/eth_rv/eth_rv.dts

    # stop both streams at one architectural event instead of the tohost symbol
    python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_model \\
        --stop-store 0x80001000:0x1
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
RTL_DIR = REPO_ROOT / "ethereal-shell" / "rtl" / "eth_rv"
HARNESS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv"
DEFAULT_CORPUS = REPO_ROOT / "generated" / "rv_difftest" / "corpus"
DEFAULT_WORK = REPO_ROOT / "generated" / "rv_difftest" / "rtl"

RTL_SOURCES = [
    RTL_DIR / "eth_rv_pkg.sv",
    RTL_DIR / "cor_alu.sv",
    RTL_DIR / "cor_muldiv.sv",
    RTL_DIR / "cor_lsu.sv",
    RTL_DIR / "cor_regfile.sv",
     RTL_DIR / "cor_decoder.sv",
    # Sv39 address translation (E2-RV2 increment 1): the page-table walker.
    RTL_DIR / "cor_mmu.sv",
    # F/D floating point (E2-RV2 increment 2): the register file and the FPU.
    RTL_DIR / "cor_fp_regfile.sv",
    RTL_DIR / "cor_fpu.sv",
    RTL_DIR / "eth_rv_core.sv",
    # SoC MMIO: the console UART and the address decoder in front of the D port
    # (C14 §4). Both sit in front of either memory path, so they are part of
    # every build.
    RTL_DIR / "eth_rv_uart.sv",
    # The BootROM (E2-RV2 increment 5, S3): the 4 KiB region at 0x1000 the core
    # resets into; `eth_rv_mmio_mux` instantiates it, so it is part of every build.
    RTL_DIR / "eth_rv_boot_rom.sv",
    # The PLIC (E2-RV2 increment 6, S5): the interrupt controller whose M/S
    # contexts drive the hart's meip_i/seip_i, also instantiated by the MMIO mux.
    RTL_DIR / "eth_rv_plic.sv",
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
    # E2-RV2 increment 1: Sv39 translation, its permission matrix and its faults
    # (see verif/eth_rv/README.md "Sv39 translation").
    "cor_sv39",
    "cor_pgfault",
    # E2-RV2 increment 2: the F/D floating-point extensions. `cor_fp` compares
    # every FP register value and every fflags/frm accrual against Spike through
    # the trace v2 record; `cor_fptrap` pins the FS=Off illegal-instruction rule
    # on FP instructions, FP loads/stores and the FP CSRs (see verif/eth_rv/README.md).
    "cor_fp",
    "cor_fptrap",
    # E2-RV2 increment 3: the ISA floor firmware needs — the A extension
    # (lr/sc/amo in both widths, the reservation rules, the misaligned traps) and
    # `wfi` with its `mip & mie` wake rule (see verif/eth_rv/README.md "The A
    # extension" and "wfi").
    "cor_atomic",
    "cor_wfi",
    # E2-RV2 increment 4: Zicntr with the counter enables and the inhibit
    # register (`cor_counters`: the trap-free `time` staircase, the mcycle/
    # minstret write and inhibit rules, the deltas, and the S/U permission
    # chain) plus the identification/envcfg/HPM floor (`cor_csrid`).
    "cor_counters",
    "cor_csrid",
    # E2-RV2 increment 5 (S3): the BootROM handoff check. Linked at a NON-BASE
    # entry (0x8000_1000) so it can only be reached through the reset vector —
    # the one corpus program whose whole point is that the image loader and the
    # testbench must not assume entry == window base.
    "cor_boot",
    # E2-RV2 increment 7 (S4): the unaligned DATA access path — mcause 4/6 with
    # mtval = the address, the faulting instruction writing nothing, the
    # page-crossing case, and the trap-emulate-resume route the S4 kernel's own
    # probe takes (OpenSBI's `sbi_misaligned_load_handler`). No earlier corpus
    # program touched a misaligned datum, which is why five increments of
    # DiffTest never compared this path against Spike.
    "cor_misalign",
    # E2-RV2 increment 7 (S4): the M-mode MPRV data access (OpenSBI's
    # `sbi_load_u8` sets mstatus.MPRV around a byte read, so the emulation's
    # access is translated with the trapped mode's privilege). The program also
    # pins the operand hazard the emulation's own
    # `csrrs a5, mstatus; <stalling access>; csrw mstatus, a5` sequence hits:
    # a consumer held in EX past its producer's write-back used to act on the
    # stale register-file value (see the RTL's ID/EX stage and README
    # "MPRV and the stalled-operand hazard").
    "cor_mprv",
    # E2-RV2 increment 7 (S4): the PMP CSR floor the firmware programs — reset
    # state, write masks, the L-bit lock, and the RV64-absent pmpcfg1/pmpcfg3
    # staying illegal. Storage semantics only; enforcement is a documented gap.
    "cor_pmp",
    # E2-RV2 increment 6 (S5): the devices a usable Linux needs — the PLIC with
    # its S-mode external-interrupt path, and the console UART's receive path
    # (RBR/LSR.DR/FCR/loopback/IIR and the RX interrupt as PLIC source 1).
    "cor_plic",
    "cor_uart_rx",
]

BOOT_PROGRAM = "cor_boot"
"""The one corpus program linked at a non-base entry (own linker script)."""

BOOT_BUILDER = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "build_boot.py"
"""Builder for ``cor_boot``: it links at 0x8000_1000, so it has its own link step."""

HELLO_STRING = b"hello, eth_rv!\n"
"""The console string ``corpus/cor_hello.S`` writes — the C14 §8 checkpoint 5 vehicle.

The testbench decodes the SoC UART's serial line at its own divisor and writes
what it received to ``+uart=<file>``; every program is then held to its expected
payload below. `test_rv_uart.py` re-reads this constant against `cor_hello.S`,
so the program and the assertion cannot drift apart."""

EXPECTED_UART: dict[str, bytes] = {
    "cor_hello": HELLO_STRING,
    # `cor_uart_rx` drives the receive register interface through MCR loopback (no
    # transmit) except for its last check, which turns loopback off and puts
    # exactly one byte on the line — the transmit-path assertion this program's
    # `EXPECTED_UART` payload pins.
    "cor_uart_rx": b"Z",
}
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

# The SoC contract lives in one module (verif/eth_rv/rv_platform.py), mirrored by
# ethereal-shell/core.yaml and eth_rv.dts and pinned by that suite's tests. The
# runner imports it rather than restating any address, so the window Spike is
# given with -m and the window the testbench compiles with cannot drift apart.
from rv_image import Image, load_elf_image, load_elf_segments
from rv_platform import (
    DTB_ADDR,
    RAM_BASE,
    RAM_WINDOW_BYTES,
    ROM_BASE,
    ROM_BYTES,
    ROM_ENTRY_OFFSET,
)
from rv_spike import SpikeError, StopStore, ensure_dtb, parse_stop_store

MEM_BASE = RAM_BASE
"""RAM window base: the corpus link address and the DTB's home (rv_platform)."""

MEM_WINDOW_BYTES = RAM_WINDOW_BYTES
"""The one memory-window size (rv_platform / core.yaml); Spike gets it as -m too."""


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


def build_corpus(corpus_dir: Path, programs: Sequence[str]) -> None:
    """Build the requested corpus ELFs if they are not there yet.

    Only what the run asked for is built (``--only`` does not drag in the whole
    corpus). ``cor_boot`` is built by its own script — it links at a non-base
    entry — but that builder imports the corpus builder rather than copying it,
    so the two toolchain/ISA configurations cannot drift apart.
    """
    missing = [name for name in programs if not (corpus_dir / f"{name}.elf").is_file()]
    corpus_missing = [name for name in missing if name != BOOT_PROGRAM]
    if corpus_missing:
        print(f"[rv-rtl] corpus missing under {corpus_dir}, building it")
        builder = HARNESS_DIR / "corpus" / "build_corpus.py"
        done = run([sys.executable, str(builder), "--out", str(corpus_dir)], cwd=REPO_ROOT)
        if done.returncode != 0:
            raise SetupError(f"corpus build failed:\n{done.stdout}\n{done.stderr}")
    if BOOT_PROGRAM in missing and BOOT_BUILDER.is_file():
        done = run([sys.executable, str(BOOT_BUILDER), "--out", str(corpus_dir)], cwd=REPO_ROOT)
        if done.returncode != 0:
            raise SetupError(f"cor_boot build failed:\n{done.stdout}\n{done.stderr}")


@dataclass(frozen=True, slots=True)
class MemoryImage:
    """A window image the testbench can ``$readmemh``, plus how to run it."""

    path: Path
    base: int
    size: int
    entry: int
    tohost: int
    word_count: int


class _ImageWindow:
    """A base/size-bounded byte window that renders as the TB's 64-bit word image."""

    def __init__(self, base: int, size: int, name: str) -> None:
        self.base = base
        self.size = size
        self.name = name
        self.spans: list[tuple[int, int, str]] = []
        self.bytes: dict[int, int] = {}

    def place(self, addr: int, data: bytes, owner: str, *, exclusive: bool = False) -> None:
        """Write ``data`` at ``addr``; ``exclusive`` spans may not overlap anything."""
        start, end = addr, addr + len(data)
        if start < self.base or end > self.base + self.size:
            raise SetupError(
                f"{self.name}: {owner} byte 0x{start:016x}..0x{end:016x} is outside the "
                f"0x{self.base:016x}..0x{self.base + self.size:016x} window"
            )
        if exclusive:
            for other_start, other_end, other in self.spans:
                if start < other_end and other_start < end:
                    raise SetupError(
                        f"{self.name}: {owner} 0x{start:016x}..0x{end:016x} overlaps "
                        f"{other} 0x{other_start:016x}..0x{other_end:016x}"
                    )
        self.spans.append((start, end, owner))
        for offset, byte in enumerate(data):
            self.bytes[addr + offset] = byte

    def render(self) -> tuple[dict[int, bytearray], int]:
        """The touched 64-bit words (indexed from ``base``) and their count."""
        words: dict[int, bytearray] = {}
        for where, byte in self.bytes.items():
            index = (where - self.base) >> 3
            slot = words.setdefault(index, bytearray(8))
            slot[where & 7] = byte
        return words, len(words)


def write_window_image(
    image: Image,
    image_path: Path,
    *,
    base: int = MEM_BASE,
    size: int = MEM_WINDOW_BYTES,
    blobs: Sequence[tuple[int, bytes, str]] = (),
) -> MemoryImage:
    """Flatten a program image (plus optional blobs) into the TB's ``$readmemh`` form.

    Words are indexed from ``base``, so the file's address N is the 64-bit word at
    ``base + 8*N`` — the mapping ``tb_eth_rv_core.sv`` uses. ``entry`` is no longer
    required to equal ``base``: the TB takes the payload entry as a plusarg and
    starts its trace there, so a program loaded anywhere in the window is loadable.
    ``blobs`` are raw ``(addr, bytes, name)`` ranges placed in the same window —
    the device tree at :data:`DTB_ADDR` — and a blob that collides with a loaded
    segment is an error rather than a silent overwrite.
    """
    window = _ImageWindow(base, size, image.name)
    for addr, data in image.segments:
        window.place(addr, data, "segment")
    for addr, data, name in blobs:
        window.place(addr, data, name, exclusive=True)
    words, count = window.render()
    lines: list[str] = []
    for index in sorted(words):
        lines.append(f"@{index:08x}")
        # $readmemh reads the first character as the MSB, so a little-endian
        # word lands in the file byte-reversed.
        lines.append(bytes(words[index][::-1]).hex())
    image_path.write_text("\n".join(lines) + "\n", encoding="ascii")
    return MemoryImage(
        path=image_path,
        base=base,
        size=size,
        entry=image.entry,
        tohost=image.tohost,
        word_count=count,
    )


def write_memory_image(
    elf: Path,
    image_path: Path,
    *,
    base: int = MEM_BASE,
    size: int = MEM_WINDOW_BYTES,
    blobs: Sequence[tuple[int, bytes, str]] = (),
) -> MemoryImage:
    """Load ``elf`` and flatten it with :func:`write_window_image`."""
    return write_window_image(load_elf_image(elf), image_path, base=base, size=size, blobs=blobs)


@dataclass(frozen=True, slots=True)
class RomImage:
    """A BootROM image for the TB's ``+rom=`` plusarg (32-bit sparse words)."""

    path: Path
    source: Path
    word_count: int
    entry: int | None


_TB_ROM_LINE = re.compile(r"^@[0-9a-fA-F]{1,8}\s+[0-9a-fA-F]{8}$")


def write_rom_image(source: Path, image_path: Path, *, base: int = ROM_BASE) -> RomImage:
    """Transcribe a BootROM source into the TB's 32-bit ``$readmemh`` image.

    Two sources are accepted. An already-built ROM hex (``@<word:04x> <value:08x>``,
    the format ``rtl/eth_rv/rom/build_rom.py`` writes) is passed through verbatim
    — that is the file to use, since it is the one the drift check rebuilds.

    An ELF is transcribed here: every segment byte is kept (so the stub's own
    data words, e.g. its instruction-count word at ROM offset 28 that the CLINT's
    ``mtime`` phase is derived from, survive) and the 64-bit payload entry is
    written at :data:`ROM_ENTRY_OFFSET` on top of it. Transcribe an ELF built from
    the current ``boot_rom.S``; a hand-rolled stub without the step word will be
    rejected by the testbench.
    """
    src = Path(source)
    if not src.is_file():
        raise SetupError(f"ROM image not found: {src}")
    blob = src.read_bytes()
    if blob[:4] != b"\x7fELF":
        lines = blob.decode("ascii", errors="replace").splitlines()
        word_count = sum(1 for line in lines if _TB_ROM_LINE.match(line.strip()))
        if word_count == 0:
            raise SetupError(
                f"{src}: not an ELF and not a boot-rom hex image "
                "(want `@<word_index:04x> <value:08x>` lines)"
            )
        image_path.write_bytes(blob)
        return RomImage(path=image_path, source=src, word_count=word_count, entry=None)
    entry, segments = load_elf_segments(src)
    window = _ImageWindow(base, ROM_BYTES, src.name)
    for addr, data in segments:
        window.place(addr, data, "segment")
    words: dict[int, int] = {}
    for where, byte in window.bytes.items():
        index = (where - base) >> 2
        words[index] = words.get(index, 0) | (byte << (8 * (where & 3)))
    words[ROM_ENTRY_OFFSET // 4] = entry & 0xFFFF_FFFF
    words[ROM_ENTRY_OFFSET // 4 + 1] = (entry >> 32) & 0xFFFF_FFFF
    text = "".join(
        f"@{index:04x} {word:08x}\n" for index, word in sorted(words.items()) if word
    )
    image_path.write_text(text, encoding="ascii")
    return RomImage(path=image_path, source=src, word_count=len(words), entry=entry)


def verilator_defines(dram: bool, line_beats: int) -> list[str]:
    """The compile-time knobs the TB is built with (window size is the contract).

    ``-DETH_RV_MEM_BYTES`` is the same number Spike is given with ``-m`` and the
    ROM/runner use; the testbench asserts its ``+mem_bytes=`` plusarg against it,
    so a stale model built with a different window cannot pass silently.
    """
    defines = [f"-DETH_RV_MEM_BYTES={MEM_WINDOW_BYTES}"]
    if dram:
        defines += ["-DETH_RV_DRAM_AXI", f"-DETH_RV_LINE_BEATS={line_beats}"]
    return defines


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
    defines = verilator_defines(dram, line_beats)
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
    mem: MemoryImage
    rom: RomImage | None = None


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


def tb_argv(
    exe: Path,
    *,
    mem: MemoryImage,
    trace_path: Path,
    uart_path: Path,
    mem_lat: int,
    rom: RomImage | None = None,
    dtb: Path | None = None,
    stop: StopStore | None = None,
    fault: str | None = None,
    uart_fault: str | None = None,
    plusargs: Sequence[str] | None = None,
) -> list[str]:
    """The testbench plusargs for one run (exposed so tests can assert them).

    The S3 boot contract lives here: `+base=`/`+mem_bytes=` pin the window the
    model was compiled with, `+entry=` is the payload entry the BootROM hands off
    to (the TB starts its trace there), `+rom=`/`+dtb=` supply the BootROM and the
    blob at :data:`DTB_ADDR`, and `+stop_addr=`/`+stop_value=` name the store the
    run must end at — the same event the comparator cuts the golden stream at.
    """
    argv = [
        str(exe),
        f"+mem={mem.path}",
        f"+trace={trace_path}",
        f"+uart={uart_path}",
        f"+base=0x{mem.base:x}",
        f"+entry=0x{mem.entry:x}",
        f"+tohost=0x{mem.tohost:x}",
        f"+memlat={mem_lat}",
        f"+mem_bytes={mem.size}",
    ]
    if rom is not None:
        argv.append(f"+rom={rom.path}")
    if dtb is not None:
        argv.append(f"+dtb={dtb}")
    if stop is not None:
        argv.append(f"+stop_addr=0x{stop.addr:x}")
        if stop.value is not None:
            argv.append(f"+stop_value=0x{stop.value:x}")
    if fault is not None:
        index, field, value = parse_fault(fault)
        argv += [f"+fault_index={index}", f"+fault_field={field}", f"+fault_value=0x{value:x}"]
    if uart_fault is not None:
        frame, bit = parse_uart_fault(uart_fault)
        argv += [f"+uart_fault_frame={frame}", f"+uart_fault_bit={bit}"]
    # pass-through negative controls (`+no_dmem_err=1`, `+dmem_corrupt_addr=…`
    # `+dmem_corrupt_xor=…`, `+trace_traps=1`, …) — see verif/eth_rv/README.md
    argv += list(plusargs or [])
    return argv


def run_rtl(
    exe: Path,
    elf: Path,
    work_dir: Path,
    *,
    mem_lat: int,
    fault: str | None,
    quiet: bool,
    uart_fault: str | None = None,
    plusargs: list[str] | None = None,
    rom: RomImage | None = None,
    dtb: Path | None = None,
    stop: StopStore | None = None,
) -> RtlRun:
    """Run the RTL on one ELF; produce its commit trace and console record.

    `+uart=<file>` asks the testbench for what its receiver decoded off the
    console UART's serial line (the C14 §8 checkpoint 5 evidence), and
    `uart_fault` = ``FRAME:BIT`` inverts one bit cell of one received frame — the
    negative control that proves the UART assertion is live.

    The boot contract rides on plusargs: `+rom=` (BootROM at ``ROM_BASE``),
    `+entry=` (the payload entry the ROM hands off to; the TB starts its trace
    there), `+dtb=` (the blob at :data:`DTB_ADDR`, also woven into `+mem=`),
    `+mem_bytes=` (assert the compiled window matches), and `+stop_addr=`/
    `+stop_value=` (the same event the comparator stops both streams at).
    """
    stem = elf.stem if fault is None else f"{elf.stem}.fault"
    image_path = work_dir / f"{elf.stem}.mem.hex"
    trace_path = work_dir / f"{stem}.trace"
    uart_path = work_dir / f"{elf.stem}.uart"
    blobs: tuple[tuple[int, bytes, str], ...] = ()
    if dtb is not None:
        blobs = ((DTB_ADDR, Path(dtb).read_bytes(), "dtb"),)
    mem = write_memory_image(elf, image_path, blobs=blobs)
    argv = tb_argv(
        exe,
        mem=mem,
        trace_path=trace_path,
        uart_path=uart_path,
        mem_lat=mem_lat,
        rom=rom,
        dtb=dtb,
        stop=stop,
        fault=fault,
        uart_fault=uart_fault,
        plusargs=plusargs,
    )
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
        mem=mem,
        rom=rom,
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
    is the negative control for the memory comparison (C14 §5.2), and
    ``fflags``/``frm`` corrupt the FP record, the negative control for the FP
    comparison (E2-RV2 increment 2).
    """
    match = re.fullmatch(
        r"(\d+):(pc|rd|value|mem_addr|mem_wdata|fflags|frm)=(0x[0-9a-fA-F]+|\d+)",
        spec.strip(),
    )
    if match is None:
        raise SetupError(
            f"--fault wants INDEX:{{pc,rd,value,mem_addr,mem_wdata,fflags,frm}}=VALUE, "
            f"got {spec!r}"
        )
    return int(match.group(1)), match.group(2), int(match.group(3), 0)


def compare(
    elf: Path, trace: Path, *, quiet: bool, stop: StopStore | None = None, dtb: Path | None = None
) -> tuple[bool, str]:
    """Run the harness comparator against the RTL dump; returns (matched, report).

    The golden is pinned to the same window the testbench compiled with
    (``-m0x80000000:<size>``) and, when asked, to the same device tree and stop
    event — so the comparison cannot silently use a different configuration on
    the two sides (E2-RV2 §3 item 7).
    """
    argv = [
        sys.executable,
        str(HARNESS_DIR / "rv_difftest.py"),
        "--elf",
        str(elf),
        "--dut",
        f"dump:{trace}",
        "--mem-base",
        f"0x{MEM_BASE:x}",
        "--mem-size",
        str(MEM_WINDOW_BYTES),
    ]
    if dtb is not None:
        argv += ["--dtb", str(dtb)]
    if stop is not None:
        spec = f"0x{stop.addr:x}" if stop.value is None else f"0x{stop.addr:x}:0x{stop.value:x}"
        argv += ["--stop-store", spec]
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
    parser.add_argument(
        "--rom",
        type=Path,
        default=None,
        help=(
            "BootROM source for +rom=. Prefer the checked-in hex "
            "(rtl/eth_rv/rom/boot_rom.hex), which carries the stub's step-count word; an "
            f"ELF built from boot_rom.S is transcribed here (entry word at offset {ROM_ENTRY_OFFSET})"
        ),
    )
    parser.add_argument(
        "--dtb",
        type=Path,
        default=None,
        help=(
            f"device tree blob loaded at 0x{DTB_ADDR:x} (a .dts is compiled on demand with "
            "the harness's dtc) and passed to Spike's golden run, so both sides read the "
            "same tree; omitted = no DT (the ordinary corpus programs do not use one)"
        ),
    )
    parser.add_argument(
        "--stop-store",
        default=None,
        metavar="ADDR[:VALUE]",
        help=(
            "end both streams after a store to ADDR (hex or decimal), optionally requiring "
            "VALUE, instead of the ELF's tohost symbol; passed to the TB as "
            "+stop_addr/+stop_value and to the comparator as --stop-store"
        ),
    )
    parser.add_argument("--quiet", action="store_true", help="only print the harness verdicts")
    parser.add_argument(
        "--tb-plusarg",
        action="append",
        default=[],
        help=(
            "extra +plusarg for the testbench, verbatim (repeatable). The Sv39 negative "
            "controls use it: +no_dmem_err=1 (a PTE read answered as a silent success), "
            "+dmem_corrupt_addr=ADDR +dmem_corrupt_xor=XOR (a page table read corrupted, "
            "i.e. a fault injected on a walk), +trace_traps=1 (print every trap)"
        ),
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    programs = args.only if args.only else list(CORPUS_PROGRAMS)
    try:
        build_corpus(args.corpus_dir, programs)
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
    try:
        stop = parse_stop_store(args.stop_store) if args.stop_store is not None else None
        rom = (
            write_rom_image(args.rom, args.work_dir / "rom.hex")
            if args.rom is not None
            else None
        )
        dtb = ensure_dtb(args.dtb) if args.dtb is not None else None
    except (SetupError, SpikeError, ValueError) as exc:
        sys.stderr.write(f"[rv-rtl] error: {exc}\n")
        return 2
    print(
        f"[rv-rtl] window: -m0x{MEM_BASE:x}:{MEM_WINDOW_BYTES} "
        f"(TB -DETH_RV_MEM_BYTES={MEM_WINDOW_BYTES})"
    )
    if rom is not None:
        entry = "-" if rom.entry is None else f"0x{rom.entry:x}"
        print(f"[rv-rtl] rom: {rom.source} -> {rom.path} (payload entry word: {entry})")
    if dtb is not None:
        print(f"[rv-rtl] dtb: {dtb} @ 0x{DTB_ADDR:x}")
    print(
        "[rv-rtl] stop: "
        + ("tohost (the ELF symbol)" if stop is None else stop.describe())
        + " (golden and DUT end at the same store)"
    )
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
                plusargs=args.tb_plusarg,
                rom=rom,
                dtb=dtb,
                stop=stop,
            )
        except SetupError as exc:
            sys.stderr.write(f"[rv-rtl] error: {exc}\n")
            return 2

        expected = EXPECTED_UART.get(name, b"")
        if args.fault is None:
            matched, report = compare(elf, rtl.trace, quiet=args.quiet, stop=stop, dtb=dtb)
            print(f"[rv-rtl] {name}: {rtl.status}")
            print(report)
            failures += report_uart(
                name, rtl.uart, expected, expect_fault=args.uart_fault is not None
            )
            if not matched:
                failures += 1
        else:
            index, field, value = parse_fault(args.fault)
            matched, report = compare(elf, rtl.trace, quiet=args.quiet, stop=stop, dtb=dtb)
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
