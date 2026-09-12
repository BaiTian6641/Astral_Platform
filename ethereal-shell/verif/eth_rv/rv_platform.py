# SPDX-License-Identifier: MIT
"""The ``eth_rv`` SoC contract: address map, boot handshake and DiffTest cadence.

Every number in this module is mirrored by two checked-in artefacts, and
``tests/test_rv_platform.py`` pins all three together so they cannot drift:

* ``ethereal-shell/core.yaml`` — the SoC configuration a board build reads
  (hart count, ISA string, memory window, BootROM/DTB addresses, clock).
* ``eth_rv.dts`` — the device tree the harness points Spike at with ``--dtb``.

A Python copy exists because the runner and the Spike golden generator must size
the memory window *identically* on both sides of the DiffTest — ``-m0x8000_0000:
<size>`` for Spike, ``-DETH_RV_MEM_BYTES=<size>`` for the Verilated testbench —
without parsing YAML on every run. The checked-in files stay the human-readable
contract; this module is what the harness executes.

BOOT PATH (S3, fixed interface)
-------------------------------

::

    reset -> BootROM @ 0x0000_1000 (4 KiB, M-mode stub)
               a0 = mhartid (0)
               a1 = DTB @ 0x8000_2000
               jr  <payload entry, word 8 of the ROM image>
             payload @ 0x8000_0000 (the RAM window base)

The payload entry is a linker value; the harness patches the ROM's entry word
from the ELF it loads (``+entry=`` / ``--entry``), which is why the DT and the
payload can move without rebuilding the ROM.

BOUNDARY — ``timebase-frequency``
---------------------------------

The DT declares :data:`TIMEBASE_FREQUENCY` because Spike's device tree schema
requires one and Spike's CLINT *is* an instruction-count-driven RTC
(``CPU_HZ / INSNS_PER_RTC_TICK`` = 1 GHz / 100). Our CLINT advances ``mtime`` on
the same DiffTest cadence today, so the two sides agree during a DiffTest — but
this is **not a board oscillator**: in SoC mode a real RTC tick input drives
``mtime`` (see the E2-RV2 report, G9) and this node is a placeholder. Any
frequency-derived software behaviour (baud programming, timers) is therefore out
of contract until that input exists; the UART's ``clock-frequency`` is the same
placeholder.
"""
from __future__ import annotations

import re
from pathlib import Path

# --- the pinned configuration -----------------------------------------------------

ISA_STRING = "rv64imafdc_zicsr_zicntr"
"""The ``riscv,isa`` string both cores advertise (``misa`` = 0x8000_0000_0014_112d)."""

HART_COUNT = 1
"""Harts in the S3 configuration (``a0`` is always 0 until this grows)."""

RAM_BASE = 0x8000_0000
"""RAM window base: the corpus link address, the DTB's home and a1's page."""

RAM_WINDOW_BYTES = 1 << 20
"""The single memory-window size (1 MiB), shared by TB, AXI master and runner.

The historical pin was 256 KiB in the behavioural testbench and 1 MiB behind
``eth_rv_axi_master``; S3 collapsed the two into this one number so Spike's
``-m`` can be set to it exactly and the "RTL memory is smaller than Spike DRAM"
deviation disappears.
"""

ROM_BASE = 0x0000_1000
"""BootROM base — mirrors Spike's ``DEFAULT_RSTVEC``; the core resets here."""

ROM_BYTES = 0x1000
"""BootROM size: one 4 KiB page, same as Spike's own boot ROM."""

ROM_STEP_OFFSET = 28
"""Byte offset of the stub's instruction-count word inside the ROM image (word 7).

The testbench derives the CLINT's ``mtime`` phase from it, so the harness must
preserve it when it transcribes an ELF into a ROM image (``write_rom_image``);
the checked-in ``rom/boot_rom.hex`` already carries it. It sits immediately
before :data:`ROM_ENTRY_OFFSET` because the stub's fixed 28-byte body ends there
(``.option norvc`` keeps the count exact).
"""

ROM_ENTRY_OFFSET = 32
"""Byte offset of the 64-bit payload entry inside the ROM image (word 8).

The stub ``ld``\\s it, so the harness can point one ROM at any payload; Spike's
own reset vector takes its start PC from an offset in the same spirit.
"""

DTB_ADDR = 0x8000_2000
"""Device tree blob address, 8 KiB into RAM; a1 is set to exactly this."""

DTB_PATH_REL = Path("generated/rv_difftest/eth_rv.dtb")
"""Where the compiled device tree blob is written (gitignored build output)."""

DTS_PATH_REL = Path("ethereal-shell/verif/eth_rv/eth_rv.dts")
"""The checked-in device tree source."""

CORE_YAML_PATH_REL = Path("ethereal-shell/core.yaml")
"""The checked-in SoC configuration this module mirrors."""

# --- device addresses the DT declares ---------------------------------------------

UART_BASE = 0x1000_0000
"""Console UART base (``eth_rv_uart``; Spike's ``ns16550`` model)."""

UART_REG_BYTES = 0x100
"""Register window the DT declares (``compatible = "ns16550a"``).

The RTL decodes a whole 4 KiB page and byte-aliases it the way Spike's model
does (see ``eth_rv_mmio_mux.sv``); the DT keeps the register-window convention
every driver expects and the page aliasing stays an RTL boundary.
"""

CLINT_BASE = 0x0200_0000
"""CLINT base (``eth_rv_clint``; matches Spike's default ``CLINT_BASE``)."""

CLINT_BYTES = 0xC000
"""CLINT window size (``mtimecmp``/``mtime`` + ``msip``)."""

PLIC_BASE = 0x0C00_0000
"""PLIC base (``eth_rv_plic``; matches Spike's default ``PLIC_BASE``).

E2-RV2 increment 6 (S5) turned the device-tree node below from a golden-side
placeholder into real hardware: the SoC's external-interrupt controller, with the
console UART as its source ``UART_IRQ`` and two contexts — context 0 feeding the
hart's ``meip_i`` and context 1 its ``seip_i`` (the S-mode path ``mideleg.SEI``
needs). A kernel attaches the UART's driver to the S context.
"""

PLIC_BYTES = 0x0100_0000
"""PLIC window size — Spike's ``PLIC_SIZE``; the node's ``reg`` says the same."""

PLIC_NDEV = 31
"""Interrupt sources the configuration has (Spike's ``PLIC_NDEV``; ``riscv,ndev``).

Source ids run 1..31 and source 0 does not exist; only source ``UART_IRQ`` is wired.
"""

PLIC_PRIO_BITS = 4
"""Priority width in bits — Spike's ``PLIC_PRIO_BITS``; ``riscv,max-priority`` is 2**4-1."""

UART_IRQ = 1
"""The console UART's PLIC source id (Spike's ``NS16550_INTERRUPT_ID``).

The device tree states it as the UART node's first ``interrupts`` cell.
"""

# --- cadence placeholder ----------------------------------------------------------

CLOCK_HZ = 1_000_000_000
"""Placeholder core clock for the DT's ``clock-frequency`` (Spike's ``CPU_HZ``)."""

TIMEBASE_FREQUENCY = CLOCK_HZ // 100
"""The DiffTest ``timebase-frequency``; see the module docstring boundary."""

DEFAULT_BOOTARGS = "console=ttyS0 earlycon"
"""Spike's kernel bootargs default, so a golden run matches Spike with no flag."""

# --- the S4 Linux-boot profile (E2-RV2 increment 7) --------------------------------
#
# Everything above is the S3/S5 *DiffTest corpus* contract: a 1 MiB window with the
# corpus linked at RAM_BASE and the DTB right above it. The S4 milestone boots a
# real kernel, which needs a different profile for one reason only — the kernel is
# 22.4 MiB before the device tree and initramfs are placed. These are the numbers
# the S4 boot uses on BOTH sides (the BootROM's a1, the `+mem` image the testbench
# preloads, and Spike's `-m`/`--dtb`/`--kernel`/`--initrd`).

LINUX_RAM_WINDOW_BYTES = 40 * (1 << 20)
"""The S4 RAM window (40 MiB) — the kernel's own footprint plus room for the DT,
initramfs and firmware: OpenSBI 0x8000_0000..0x8004_2000, kernel
0x8020_0000..0x817D_6000 (``text_offset`` 0x200000, ``image_size`` 0x15D6000),
DTB 0x8220_0000, initramfs at the top. Recorded in ``core.yaml`` as
``linux_ram_window_bytes``."""

LINUX_FW_ADDR = RAM_BASE
"""Where the OpenSBI ``fw_jump`` image is loaded: the RAM base, which is also its
link address (``FW_TEXT_START``) and the BootROM's handoff target."""

LINUX_FW_ENTRY = RAM_BASE
"""The OpenSBI entry the S4 BootROM's entry word holds (``fw_jump.elf`` e_entry)."""

LINUX_KERNEL_ADDR = RAM_BASE + 0x20_0000
"""The kernel ``Image`` load address: ``FW_JUMP_OFFSET`` (OpenSBI's jump target)
and the image's own ``text_offset`` — the two have to agree, which is exactly what
the first field of the RISC-V image header states."""

LINUX_KERNEL_TEXT_OFFSET = 0x20_0000
"""The ``text_offset`` the S4 kernel image header must declare (checked at build)."""

LINUX_DTB_ADDR = RAM_BASE + 0x220_0000
"""The device tree address the *kernel* is given: ``FW_JUMP_FDT_ADDR``, the stock
OpenSBI slot, which ``fw_jump`` relocates the tree to (``fw_base.S`` copies from
the incoming a1 to ``fw_next_arg1()``) before entering the kernel."""

LINUX_ROM_DTB_ADDR = ROM_BASE + 0x20
"""Where the S4 *BootROM* keeps the device tree: 0x1020, Spike's own reset-ROM slot.

The S4 BootROM is Spike's reset vector byte for byte — five instructions that load
the payload entry from offset 24, leave a1 = this address and jump — followed by the
tree. Aligning the two sides' a1 is what makes the firmware portion diffable at all
(Spike's a1 is this value, and it is not configurable); the firmware then relocates
the tree to :data:`LINUX_DTB_ADDR` on its own. The S4 ROM is 4096 B, so the tree has
4064 B; the build fails if it does not fit.
"""

LINUX_ROM_STEP_WORD = 5
"""The S4 ROM word holding the stub's instruction count (the CLINT's step skip).

Word 7 is the stub step-count word in the S3 layout, but the S4 stub takes its
entry from words 6/7 (Spike's position), so its count moves up to word 5 — the
first word the five-instruction stub never executes.
"""

LINUX_ROM_ENTRY_WORD = 6
"""The S4 ROM word holding the 64-bit payload entry (Spike's word 6)."""

LINUX_ROM_STUB_STEPS = 5
"""Instructions the S4 stub retires before the handoff (Spike's reset vector)."""

LINUX_INITRD_END = RAM_BASE + LINUX_RAM_WINDOW_BYTES - 0x1000
"""Top of the initramfs window (last 4 KiB page reserved), Spike's ``--initrd``
convention: ``initrd_end = mem_base + mem_size - 0x1000``. ``initrd_start`` is
``initrd_end - <initramfs size>``, which is why :file:`eth_rv_linux.dts` is a
template: the S4 build substitutes the two addresses it computes."""

LINUX_MILESTONE = b"eth_rv S4: MILESTONE-REACHED"
"""The console line that ends the S4 run: the initramfs's ``/init`` announcing
itself *after* the kernel has handed control to userspace. The testbench decodes
the UART line and stops on this byte string (`+uart_marker=`), so the milestone is
a byte-exact console assertion and not a wall-clock guess. It is substituted into
the checked-in init script at build time, so the script and the assertion cannot
drift apart."""

LINUX_DTS_PATH_REL = Path("ethereal-shell/verif/eth_rv/eth_rv_linux.dts")
"""The checked-in S4 device tree *template* (its ``@INITRD_*@`` tokens are filled
in with :data:`LINUX_INITRD_END` and ``LINUX_INITRD_END - size``)."""

LINUX_INIT_PATH_REL = Path("ethereal-shell/verif/eth_rv/s4/init")
"""The checked-in initramfs ``/init`` script (the milestone marker's source)."""

LINUX_BUILD_DIR_REL = Path("generated/rv_difftest/s4")
"""Where the S4 build writes its images and manifest (gitignored)."""

LINUX_WORK_DIR_REL = Path("build/s4-linux")
"""Where the S4 build keeps its checkout, downloads and unpacked trees."""

_INT_RE = re.compile(r"^[+-]?(?:0[xX][0-9a-fA-F]+|\d+)$")


def repo_root() -> Path | None:
    """Repository root (the directory holding ``AGENTS.md``), or ``None``."""
    for parent in Path(__file__).resolve().parents:
        if (parent / "AGENTS.md").is_file():
            return parent
    return None


def core_yaml_path() -> Path | None:
    """The checked-in ``ethereal-shell/core.yaml``, or ``None`` outside the repo."""
    root = repo_root()
    return None if root is None else root / CORE_YAML_PATH_REL


def dts_path() -> Path | None:
    """The checked-in ``eth_rv.dts``, or ``None`` outside the repo."""
    root = repo_root()
    return None if root is None else root / DTS_PATH_REL


def dtb_path() -> Path | None:
    """Where the compiled DTB is expected, or ``None`` outside the repo."""
    root = repo_root()
    return None if root is None else root / DTB_PATH_REL


def read_core_yaml(path: str | Path | None = None) -> dict[str, int | str]:
    """Read the flat ``key: value`` subset ``core.yaml`` uses.

    The SoC contract is deliberately a flat mapping of scalars: every value is
    either a string or an integer literal, so the harness needs no YAML
    dependency to check that the checked-in configuration still agrees with
    :data:`ISA_STRING`, :data:`RAM_WINDOW_BYTES` and the rest. Nested structures
    are a hard error, not silently ignored — a config the harness cannot read is
    worse than a config that is wrong.
    """
    source = Path(path) if path is not None else core_yaml_path()
    if source is None or not source.is_file():
        raise FileNotFoundError(f"core.yaml not found: {source}")
    values: dict[str, int | str] = {}
    for lineno, raw in enumerate(source.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.endswith(":") or line.startswith("-"):
            raise ValueError(f"{source}:{lineno}: core.yaml must stay a flat key: value map")
        key, sep, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if not sep or not key or not value:
            raise ValueError(f"{source}:{lineno}: expected `key: value`")
        values[key] = int(value, 0) if _INT_RE.match(value) else value
    return values
