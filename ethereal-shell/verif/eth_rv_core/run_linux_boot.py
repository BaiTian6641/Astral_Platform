#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the S4 Linux boot (OpenSBI -> Linux) on Spike, on the RTL, or both.

The S4 image pair is built by ``verif/eth_rv/build_linux_boot.py``; this script
only *runs* it, in three modes that answer three different questions:

``--spike``
    Boot the pair under Spike (``--kernel``, ``--dtb``, ``--initrd`` and the
    OpenSBI ELF as the program). It proves the images and the device tree are
    self-consistent with no RTL involved — the reference the RTL is compared to —
    and its console output is the byte string the RTL run must reproduce.

``--rtl``
    Boot the same pair on the Verilated ``eth_rv`` SoC: a 40 MiB window
    (``-DETH_RV_MEM_BYTES``), the S4 BootROM (Spike's reset vector with the device
    tree in the same 4 KiB page), the kernel at ``FW_JUMP_OFFSET``, the initramfs
    at the top of the window, and the testbench's console-marker stop. The proof
    is the console: the run ends when userspace's milestone line has been decoded
    off the UART *line*, byte by byte, at the transmitter's own bit rate.

``--difftest``
    The firmware portion only, commit by commit against Spike. Both sides start at
    the OpenSBI entry with the *same* a1 (the S4 BootROM is Spike's reset vector,
    so the two agree on the tree's address and on the five instructions that got
    there) and the DUT run stops at the kernel entry — the declared synchronisation
    point. The golden is Spike's own commit log up to the same point.

Usage::

    python3 ethereal-shell/verif/eth_rv_core/run_linux_boot.py --build --spike
    python3 ethereal-shell/verif/eth_rv_core/run_linux_boot.py --build --rtl
    python3 ethereal-shell/verif/eth_rv_core/run_linux_boot.py --rtl --dram
    python3 ethereal-shell/verif/eth_rv_core/run_linux_boot.py --difftest
    python3 ethereal-shell/verif/eth_rv_core/run_linux_boot.py --all
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
HARNESS_DIR = HERE.parent / "eth_rv"
REPO_ROOT = HERE.parents[2]
for _path in (str(HERE), str(HARNESS_DIR)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import rv_platform  # noqa: E402
from rv_image import Image  # noqa: E402
from rv_spike import (  # noqa: E402
    GoldenConfig,
    find_spike,
    normalize_spike_log,
    spike_environment,
    spike_version,
)
from run_difftest import (  # noqa: E402
    DRAM_SOURCES,
    RTL_SOURCES,
    TB_SOURCE,
    SetupError,
    _tool,
    parse_uart_record,
    run,
    write_window_image,
)

BUILD_SCRIPT = HARNESS_DIR / "build_linux_boot.py"
"""The S4 image builder this runner consumes (``--build`` shells out to it)."""

S4_DIR = REPO_ROOT / rv_platform.LINUX_BUILD_DIR_REL
"""Where the built images and manifest live (gitignored)."""

WORK_DIR = REPO_ROOT / "generated" / "rv_difftest" / "s4" / "run"
"""Run scratch: the memory image, the model, the console traces."""

SPIKE_STUB_STEPS = rv_platform.LINUX_ROM_STUB_STEPS
"""Spike's own reset vector length: what its step counter has counted when the
OpenSBI entry retires, and therefore the golden bound ``--instructions`` adds."""

LINUX_UART_FIFO_DEPTH = 65536
"""The S4 build's UART transmit/receive queue depth (bytes).

The TB's default is 64, which is right for a corpus program that prints a string;
a Linux boot prints ~12 KiB before the initramfs handoff and cannot be
back-pressured (the UART's LSR reports TEMT|THRE permanently, exactly as Spike's
model does), so the queue has to absorb a printk burst. 64 KiB is ~64x the largest
single-line burst the kernel can produce and is a model parameter, not a claim
about hardware — the register semantics are untouched, which is what keeps the
firmware DiffTest aligned with Spike."""

STATUS_RE = re.compile(
    r"ETH_RV_TB: PASS (?P<commits>\d+) commits \((?P<compressed>\d+) compressed\), "
    r"(?P<cycles>\d+) cycles, (?P<loads>\d+) loads, (?P<stores>\d+) stores, "
    r"(?P<traps>\d+) traps \((?P<irqs>\d+) interrupts, (?P<access>\d+) access faults, "
    r"(?P<pgfaults>\d+) page faults, last mcause=(?P<cause>\d+)\)"
)
"""The testbench's PASS line, which is where the S4 numbers come from."""

BUDGET_RE = re.compile(r"ETH_RV_TB: FAIL stopped at (?P<commits>\d+) commits after (?P<cycles>\d+) cycles")
"""The FAIL line a run that hit the cycle budget ends with. Its commit count is
still a usable DiffTest prefix (the dump is closed before the verdict), which is
what makes a bounded debugging run informative rather than just a failure."""


class S4Error(RuntimeError):
    """The run cannot proceed (missing images, missing tool, bad result)."""


# --- images -----------------------------------------------------------------------


def load_manifest(out: Path = S4_DIR) -> dict[str, Any]:
    path = out / "manifest.json"
    if not path.is_file():
        raise S4Error(f"no S4 manifest at {path}: run build_linux_boot.py --build first")
    manifest: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return manifest


def initrd_start(manifest: dict[str, Any]) -> int:
    """Where the initramfs starts: the DT's own ``linux,initrd-start``."""
    return int(manifest["dt"]["initrd_start"])


def build_memory_image(out: Path, manifest: dict[str, Any]) -> Image:
    """The S4 memory image: firmware, kernel, tree and initramfs at their addresses.

    One image for both sides of the boot: Spike is given the same contents through
    its own loaders (``--kernel`` + the OpenSBI ELF + ``--initrd`` + ``--dtb``), and
    the addresses here are the ones the plan and the device tree state. The tree is
    present twice on purpose — in the BootROM (where the firmware's a1 points) and
    at the stock ``FW_JUMP_FDT_ADDR`` slot, which is where ``fw_jump`` relocates it
    to before entering the kernel.
    """
    initrd = (out / "initramfs.cpio.gz").read_bytes()
    if initrd_start(manifest) + len(initrd) != rv_platform.LINUX_INITRD_END:
        raise S4Error(
            "the manifest's initrd window does not add up to LINUX_INITRD_END: "
            "the DT and the image would disagree"
        )
    return Image(
        name="s4-linux",
        entry=rv_platform.LINUX_FW_ENTRY,
        tohost=0,
        segments=(
            (rv_platform.LINUX_FW_ADDR, (out / "fw_jump.bin").read_bytes()),
            (rv_platform.LINUX_KERNEL_ADDR, (out / "Image").read_bytes()),
            (rv_platform.LINUX_DTB_ADDR, (out / manifest["dt"]["dtb"]).read_bytes()),
            (initrd_start(manifest), initrd),
        ),
    )


def write_memory_image(out: Path, manifest: dict[str, Any], *, rebuild: bool) -> Path:
    """Render the ``+mem=`` image once and reuse it while its inputs are unchanged.

    The image is ~24 MiB of data rendered as ~57 MB of ``$readmemh`` text, so it is
    built once and keyed on its inputs' timestamps rather than on every run.
    """
    image_path = out / "s4.mem.hex"
    inputs = [out / "fw_jump.bin", out / "Image", out / manifest["dt"]["dtb"],
              out / "initramfs.cpio.gz"]
    if image_path.is_file() and not rebuild:
        newest = max(path.stat().st_mtime for path in inputs)
        if image_path.stat().st_mtime >= newest:
            return image_path
    image = build_memory_image(out, manifest)
    window = write_window_image(
        image, image_path, base=rv_platform.RAM_BASE, size=rv_platform.LINUX_RAM_WINDOW_BYTES
    )
    print(
        f"[s4] memory image: {window.word_count} non-zero words over "
        f"{rv_platform.LINUX_RAM_WINDOW_BYTES / (1 << 20):.0f} MiB -> {image_path.name}"
    )
    return image_path


# --- Spike ------------------------------------------------------------------------


def spike_argv(manifest: dict[str, Any]) -> list[str]:
    """The Spike command the S4 boot uses (the reference run)."""
    return [
        str(find_spike()),
        f"--isa={rv_platform.ISA_STRING}",
        f"-m0x{rv_platform.RAM_BASE:x}:{rv_platform.LINUX_RAM_WINDOW_BYTES}",
        f"--dtb={S4_DIR / manifest['dt']['dtb']}",
        f"--kernel={S4_DIR / 'Image'}",
        f"--initrd={S4_DIR / 'initramfs.cpio.gz'}",
        str(S4_DIR / manifest["opensbi"]["fw_jump_elf"]),
    ]


def run_spike_milestone(
    manifest: dict[str, Any], *, timeout: float, console_path: Path
) -> tuple[float, bytes, str]:
    """Run Spike until the console carries the milestone; returns (wall, bytes, note).

    Spike has no ``tohost`` symbol to stop at (the OpenSBI ELF is a firmware, not a
    DiffTest program), so the stop is the same console marker the RTL uses: the
    process is killed once the marker has been seen on its stdout. That also makes
    the wall-clock number the boot time to the milestone, not to an instruction
    budget.
    """
    argv = spike_argv(manifest)
    marker = rv_platform.LINUX_MILESTONE
    started = time.time()
    proc = subprocess.Popen(
        argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=REPO_ROOT,
        env=spike_environment(),
    )
    assert proc.stdout is not None
    chunks: list[bytes] = []
    tail = bytearray()
    seen = False
    deadline = started + timeout
    while True:
        chunk = proc.stdout.read(1)
        if not chunk:
            break
        chunks.append(chunk)
        tail += chunk
        if len(tail) > len(marker):
            del tail[: len(tail) - len(marker)]
        if bytes(tail) == marker:
            seen = True
            proc.kill()
            break
        if time.time() > deadline:
            proc.kill()
            raise S4Error(f"spike did not reach the milestone within {timeout:.0f}s")
    wall = time.time() - started
    proc.wait()
    data = b"".join(chunks)
    console_path.write_bytes(data)
    note = "milestone seen" if seen else f"process exited (rc={proc.returncode}) before the milestone"
    return wall, data, note


# --- RTL --------------------------------------------------------------------------


def build_model(out: Path, *, dram: bool, line_beats: int, rebuild: bool) -> Path:
    """Verilate the S4 testbench: 40 MiB window, the S4 ROM word layout."""
    verilator = _tool("verilator")
    mode = f"dram{line_beats}" if dram else "beat"
    obj_dir = out / f"obj_s4_{mode}"
    exe = obj_dir / "Veth_rv_tb"
    sources = [*RTL_SOURCES, *(DRAM_SOURCES if dram else []), TB_SOURCE]
    if exe.is_file() and not rebuild and not any(
        path.stat().st_mtime > exe.stat().st_mtime for path in sources
    ):
        return exe
    obj_dir.mkdir(parents=True, exist_ok=True)
    defines = [
        f"-DETH_RV_MEM_BYTES={rv_platform.LINUX_RAM_WINDOW_BYTES}",
        f"-DETH_RV_CLINT_PRELOAD={SPIKE_STUB_STEPS}",
        # mtime 1:1 with retired instructions: a Linux kernel's delay loops wait on the
        # timebase, and Spike's 1-tick-per-100-instructions cadence turns every microsecond
        # of udelay into ~100x the instructions (measured: the boot stalls in __delay).
        "-DETH_RV_CLINT_TICK_STEPS=1",
        "-DETH_RV_CLINT_TICK_ADVANCE=1",
        f"-DETH_RV_ROM_ENTRY_WORD={rv_platform.LINUX_ROM_ENTRY_WORD}",
        f"-DETH_RV_ROM_STUB_WORD={rv_platform.LINUX_ROM_STEP_WORD}",
        # The console queue (see the TB): a boot's printk bursts far exceed the
        # corpus's few bytes.
        f"-DETH_RV_UART_FIFO_DEPTH={LINUX_UART_FIFO_DEPTH}",
    ]
    if dram:
        defines += ["-DETH_RV_DRAM_AXI", f"-DETH_RV_LINE_BEATS={line_beats}"]
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
    ]
    print(f"[s4] verilating the {mode} model ({len(sources)} sources) ...", flush=True)
    done = run(argv, cwd=REPO_ROOT)
    if done.returncode != 0 or not exe.is_file():
        raise S4Error(f"verilator build failed:\n{done.stdout}\n{done.stderr}")
    return exe


def rtl_argv(
    exe: Path,
    *,
    out: Path,
    manifest: dict[str, Any],
    trace: Path | None,
    stop_pc: int | None,
    max_cycles: int,
    max_traps: int,
    stop_trap_cause: int | None = None,
) -> list[str]:
    """The S4 testbench plusargs (the boot contract, one place)."""
    argv = [
        str(exe),
        f"+mem={out / 's4.mem.hex'}",
        f"+rom={out / manifest['rom']['boot_rom_hex']}",
        f"+base=0x{rv_platform.RAM_BASE:x}",
        f"+entry=0x{rv_platform.LINUX_FW_ENTRY:x}",
        f"+mem_bytes={rv_platform.LINUX_RAM_WINDOW_BYTES}",
        f"+a1_addr=0x{rv_platform.LINUX_ROM_DTB_ADDR:x}",
        "+rom_dtb=1",
        f"+max_cycles={max_cycles}",
        f"+max_traps={max_traps}",
        # No store is the end of a Linux boot, and `tohost`'s default (the RAM base)
        # is a byte the kernel itself may write: park it on an address nothing maps.
        "+tohost=0xfffffffffffffff8",
        f"+uart={out / 's4.uart'}",
        f"+uart_marker={rv_platform.LINUX_MILESTONE.hex()}",
        "+uart_drain=2000000",
    ]
    if trace is not None:
        argv.append(f"+trace={trace}")
    if stop_pc is not None:
        argv.append(f"+stop_pc=0x{stop_pc:x}")
    if stop_trap_cause is not None:
        # `+stop_trap_cause`: halt at the first trap that is not this cause. For the
        # beat-build boot the declared kind is 9 (SBI ecalls), so the run ends at the
        # trap nobody asked for instead of somewhere in the last 10^9 cycles.
        argv += ["+trace_traps=1", f"+stop_trap_cause={stop_trap_cause}"]
    return argv


def run_rtl(
    exe: Path,
    argv: list[str],
    *,
    out: Path,
    timeout: float,
    console_path: Path,
) -> tuple[float, str, bytes]:
    """Run the S4 model to completion; returns (wall, PASS line, console bytes)."""
    started = time.time()
    proc = subprocess.Popen(argv, cwd=REPO_ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    try:
        stdout, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, _ = proc.communicate()
        console_path.write_text(stdout, encoding="utf-8")
        raise S4Error(f"the RTL run did not finish within {timeout:.0f}s") from None
    wall = time.time() - started
    console_path.write_text(stdout, encoding="utf-8")
    status = next(
        (line for line in stdout.splitlines() if line.startswith("ETH_RV_TB:")),
        f"ETH_RV_TB: no status line (exit {proc.returncode})",
    )
    if "PASS" not in status:
        raise S4Error(f"the RTL run did not complete cleanly: {status}\n{stdout[-4000:]}")
    uart = parse_uart_record(out / "s4.uart")
    return wall, status, uart.data


def report_rtl(out: Path, status: str, wall: float, console: bytes, *, dram: bool) -> dict[str, Any]:
    """Print the S4 console evidence and return it as a dictionary.

    The milestone is asserted to be *inside* the received bytes, the framing is
    asserted clean, and the page-fault count is asserted non-zero: a Linux boot that
    never faulted a page did not go through the kernel's Sv39 A/D handling at all,
    which is exactly the RTL behaviour this milestone exists to exercise.
    """
    match = STATUS_RE.search(status)
    if match is None:
        raise S4Error(f"cannot parse the testbench PASS line: {status}")
    uart = parse_uart_record(out / "s4.uart")
    numbers = {key: int(value) for key, value in match.groupdict().items()}
    milestone = rv_platform.LINUX_MILESTONE
    text = console.decode("latin-1")
    print(f"[s4] {'DRAM/AXI' if dram else 'beat'} D-port run: {wall:.1f} s wall")
    print(f"[s4] {status}")
    print(
        f"[s4] console: {len(console)} bytes in {uart.frames} frames, "
        f"{uart.errors} framing errors, drain {uart.drain_cycles} cycles, "
        f"gap {uart.gap_min}..{uart.gap_max} (frame {uart.frame_cycles} cycles)"
    )
    if milestone not in console:
        raise S4Error(
            f"the console does not carry the milestone {milestone!r} — the run stopped for "
            f"another reason (last bytes: {console[-200:]!r})"
        )
    if uart.errors != 0 or uart.overflow:
        raise S4Error(f"console framing errors={uart.errors} overflow={uart.overflow}")
    if numbers["pgfaults"] <= 0:
        raise S4Error("no page faults: the kernel's Sv39 A/D handling did not run")
    print("[s4] console (verbatim, final lines):")
    for line in text.splitlines()[-6:]:
        print(f"[s4]   {line}")
    return {
        "wall_s": wall,
        "numbers": numbers,
        "console_bytes": len(console),
        "uart_errors": uart.errors,
        "uart_frames": uart.frames,
        "console_sha256": hashlib.sha256(console).hexdigest(),
    }


# --- DiffTest ---------------------------------------------------------------------


def golden_commits(manifest: dict[str, Any], *, instructions: int, timeout: float) -> list[Any]:
    """Spike's firmware commit stream, bounded to ``instructions`` retires.

    ``--instructions`` is what makes this practical: an unbounded ``--log-commits``
    run of a Linux boot logs a hundred million commits. The bound is
    ``SPIKE_STUB_STEPS + <DUT commits> + slack``, and the truncation at the OpenSBI
    entry (``entry``) drops Spike's own reset vector, so the golden starts exactly
    where the DUT's trace does.
    """
    # NOTE: no `--pc`. Spike's `--pc` bypasses its own reset ROM, and with it the
    # ROM's a1 (the device-tree pointer): the hart would enter OpenSBI with a1 = 0
    # and the very second instruction (`add s1, a1, zero`) would already diverge.
    # The ELF's entry *is* LINUX_FW_ENTRY, which is where the ROM jumps anyway.
    config = GoldenConfig(
        isa=rv_platform.ISA_STRING,
        mem_base=rv_platform.RAM_BASE,
        mem_size=rv_platform.LINUX_RAM_WINDOW_BYTES,
        dtb=S4_DIR / manifest["dt"]["dtb"],
    )
    argv = [
        str(find_spike()),
        f"--isa={config.isa}",
        *config.arguments(),
        "--instructions=" + str(instructions),
        "-l",
        "--log-commits",
        f"--log={WORK_DIR / 'spike_fw.log'}",
        str(S4_DIR / manifest["opensbi"]["fw_jump_elf"]),
    ]
    print(f"[s4] spike golden: {' '.join(argv[1:4])} --instructions={instructions} ...", flush=True)
    done = subprocess.run(argv, cwd=REPO_ROOT, capture_output=True, text=True,
                          timeout=timeout, env=spike_environment())
    if done.returncode != 0:
        raise S4Error(f"spike exited {done.returncode}: {(done.stderr or done.stdout)[:400]}")
    log = (WORK_DIR / "spike_fw.log").read_text(encoding="utf-8", errors="replace")
    commits = normalize_spike_log(log, source="spike:s4-firmware",
                                  entry=rv_platform.LINUX_FW_ENTRY)
    if not commits:
        raise S4Error("spike produced no firmware commits — is the ELF loadable?")
    return commits


def run_difftest(
    exe: Path,
    out: Path,
    manifest: dict[str, Any],
    *,
    timeout: float,
    max_traps: int,
    max_cycles: int = 200_000_000,
) -> dict[str, Any]:
    """DiffTest the firmware portion: DUT trace vs Spike, up to the kernel entry.

    ``max_cycles`` is a bound on the *DUT* run (and a debugging knob): the firmware
    reaching the kernel entry takes a few hundred thousand cycles, so the default is
    already generous. If the DUT stops short of the synchronisation point the
    comparison is made over the prefix it did produce, which is exactly what makes a
    divergence early in the firmware readable.
    """
    trace = WORK_DIR / "s4_fw.trace"
    argv = rtl_argv(
        exe, out=out, manifest=manifest, trace=trace,
        stop_pc=rv_platform.LINUX_KERNEL_ADDR, max_cycles=max_cycles, max_traps=max_traps,
    )
    print("[s4] DiffTest: DUT firmware run (stop at the kernel entry) ...", flush=True)
    try:
        wall, status, _ = run_rtl(
            exe, argv, out=out, timeout=timeout, console_path=WORK_DIR / "s4_fw.tb.log"
        )
    except S4Error as exc:
        # A budget stop is still a usable prefix: the DUT dump is complete up to the
        # commit that hit the bound, and the golden is cut to the same length below.
        print(f"[s4] DiffTest: {exc}")
        wall = 0.0
        lines = (WORK_DIR / "s4_fw.tb.log").read_text("utf-8", "replace").splitlines()
        status = next((line for line in lines if STATUS_RE.search(line)), "")
        if not status:
            status = next((line for line in lines if BUDGET_RE.search(line)), "")
        if not status:
            raise
    match = STATUS_RE.search(status) or BUDGET_RE.search(status)
    if match is None:
        raise S4Error(f"cannot parse the testbench status line: {status}")
    dut_commits = int(match.group("commits"))
    print(f"[s4] DiffTest: DUT firmware = {dut_commits} commits, cycles={match.group('cycles')}")

    from rv_trace import format_trace  # local import: only the DiffTest needs the writer

    golden = golden_commits(
        manifest, instructions=SPIKE_STUB_STEPS + dut_commits + 64, timeout=timeout
    )
    golden_path = WORK_DIR / "s4_fw.golden"
    golden_path.write_text(format_trace(golden, generator="spike s4 firmware"), encoding="utf-8")
    print(f"[s4] DiffTest: golden = {len(golden)} commits (Spike, firmware portion)")

    comparator = [
        sys.executable,
        str(HARNESS_DIR / "rv_difftest.py"),
        "--golden",
        str(golden_path),
        "--dut",
        f"dump:{trace}",
        "--mem-base",
        f"0x{rv_platform.RAM_BASE:x}",
        "--mem-size",
        str(rv_platform.LINUX_RAM_WINDOW_BYTES),
        "--max-commits",
        str(dut_commits),
    ]
    done = run(comparator, cwd=HARNESS_DIR)
    report = (done.stdout + done.stderr).strip()
    matched = done.returncode == 0
    print(report)
    if not matched:
        raise S4Error("the firmware portion does not match Spike (see the divergence above)")
    return {"wall_s": wall, "dut_commits": dut_commits, "golden_commits": len(golden),
            "matched": matched, "sync_point": f"0x{rv_platform.LINUX_KERNEL_ADDR:x}",
            "spike_version": spike_version(find_spike())}


# --- CLI --------------------------------------------------------------------------


def build_images(refresh: bool) -> None:
    argv = [sys.executable, str(BUILD_SCRIPT)]
    if refresh:
        argv.append("--refresh")
    done = run(argv, cwd=REPO_ROOT)
    if done.returncode != 0:
        raise S4Error(f"the S4 image build failed (exit {done.returncode})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--build", action="store_true", help="build the images first")
    parser.add_argument("--refresh", action="store_true", help="re-download during --build")
    parser.add_argument("--spike", action="store_true", help="run the Spike reference boot")
    parser.add_argument("--rtl", action="store_true", help="run the S4 boot on the RTL")
    parser.add_argument("--difftest", action="store_true", help="DiffTest the firmware portion")
    parser.add_argument("--all", action="store_true", help="--spike + --rtl + --difftest")
    parser.add_argument("--dram", action="store_true", help="use the AXI/DRAM D-port build")
    parser.add_argument("--axi-line-beats", type=int, default=8, choices=(1, 2, 4, 8, 16))
    parser.add_argument("--timeout", type=float, default=7200.0, help="wall-clock bound per run")
    parser.add_argument("--max-traps", type=int, default=2_000_000, help="the TB trap budget")
    parser.add_argument("--max-cycles", type=int, default=2_000_000_000,
                        help="the TB cycle budget (a bound, not an expectation)")
    parser.add_argument("--rebuild", action="store_true", help="force a Verilator rebuild")
    parser.add_argument(
        "--stop-trap-cause",
        type=int,
        default=None,
        help=(
            "halt the RTL run at the first trap whose cause is not this one, with "
            "+trace_traps=1 (e.g. 9 declares the boot's SBI ecalls as expected and "
            "stops at the trap that killed it)"
        ),
    )
    parser.add_argument("--quiet", action="store_true", help="only the summaries")
    args = parser.parse_args(argv)
    modes = {"spike": args.spike, "rtl": args.rtl, "difftest": args.difftest}
    if args.all:
        modes = dict.fromkeys(modes, True)
    if not any(modes.values()):
        parser.error("pick at least one of --spike/--rtl/--difftest/--all")
    try:
        if args.build:
            build_images(args.refresh)
        manifest = load_manifest()
        WORK_DIR.mkdir(parents=True, exist_ok=True)
        summary: dict[str, Any] = {"spike": spike_version(find_spike())}
        if modes["spike"]:
            wall, console, note = run_spike_milestone(
                manifest, timeout=args.timeout, console_path=WORK_DIR / "s4.spike.console"
            )
            summary["spike_run"] = {"wall_s": wall, "console_bytes": len(console), "note": note}
            print(f"[s4] spike: {wall:.2f} s wall to the milestone, {len(console)} console bytes ({note})")
        if modes["rtl"]:
            write_memory_image(S4_DIR, manifest, rebuild=args.rebuild)
            exe = build_model(S4_DIR, dram=args.dram, line_beats=args.axi_line_beats,
                              rebuild=args.rebuild)
            tb_argv = rtl_argv(
                exe, out=S4_DIR, manifest=manifest, trace=None, stop_pc=None,
                max_cycles=args.max_cycles, max_traps=args.max_traps,
                stop_trap_cause=args.stop_trap_cause,
            )
            print("[s4] RTL boot: 40 MiB window, console-marker stop ...", flush=True)
            wall, status, console = run_rtl(
                exe, tb_argv, out=S4_DIR, timeout=args.timeout,
                console_path=WORK_DIR / "s4.rtl.console",
            )
            (WORK_DIR / "s4.rtl.uart.txt").write_bytes(console)
            summary["rtl_run"] = report_rtl(S4_DIR, status, wall, console, dram=args.dram)
            if modes["spike"]:
                spike_console = (WORK_DIR / "s4.spike.console").read_bytes()
                _compare_console(spike_console, console, summary)
        if modes["difftest"]:
            write_memory_image(S4_DIR, manifest, rebuild=args.rebuild)
            exe = build_model(S4_DIR, dram=False, line_beats=args.axi_line_beats, rebuild=args.rebuild)
            summary["difftest"] = run_difftest(
                exe, S4_DIR, manifest, timeout=args.timeout, max_traps=args.max_traps,
                max_cycles=args.max_cycles,
            )
        (WORK_DIR / "summary.json").write_text(
            json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except (S4Error, SetupError) as exc:
        sys.stderr.write(f"[s4] error: {exc}\n")
        return 2
    print(f"[s4] summary written to {WORK_DIR / 'summary.json'}")
    return 0


def _compare_console(spike_console: bytes, rtl_console: bytes, summary: dict[str, Any]) -> None:
    """Hold the RTL's console against Spike's, byte for byte, up to the marker.

    Spike's own run is killed at the marker, so its output ends around the same
    place; the RTL's receiver may have a few extra bytes after the marker's last
    frame. The comparison therefore uses the RTL console as the reference prefix
    and reports the first differing byte, which is the useful diagnostic.
    """
    prefix = spike_console[: len(rtl_console)]
    if prefix == rtl_console:
        summary["console_match"] = {
            "matched": True,
            "bytes": len(rtl_console),
            "note": "the RTL console is byte-identical to Spike's up to the milestone",
        }
        print(f"[s4] console DIFFTEST: {len(rtl_console)} bytes byte-identical to Spike")
        return
    for index, (spike_byte, rtl_byte) in enumerate(zip(prefix, rtl_console)):
        if spike_byte != rtl_byte:
            summary["console_match"] = {
                "matched": False,
                "byte_index": index,
                "spike": spike_byte,
                "rtl": rtl_byte,
            }
            print(
                f"[s4] console DIFFTEST: differs at byte {index}: "
                f"spike 0x{spike_byte:02x} vs rtl 0x{rtl_byte:02x}"
            )
            break
    else:
        summary["console_match"] = {
            "matched": len(rtl_console) <= len(spike_console),
            "rtl_bytes": len(rtl_console),
            "spike_bytes": len(spike_console),
        }
        print(
            f"[s4] console DIFFTEST: spike ran {len(spike_console)} bytes, "
            f"rtl {len(rtl_console)}"
        )


if __name__ == "__main__":
    raise SystemExit(main())
