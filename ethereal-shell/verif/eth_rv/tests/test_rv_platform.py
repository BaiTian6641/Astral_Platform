# SPDX-License-Identifier: MIT
"""The S3 SoC contract: ``core.yaml``, the device tree and the harness agree.

Three artefacts state the same numbers, and this file is what keeps them from
drifting apart:

* ``ethereal-shell/core.yaml`` — the checked-in SoC configuration a board build
  reads (hart count, ISA string, window, BootROM/DTB addresses, clock),
* ``eth_rv.dts`` — the device tree the harness hands Spike with ``--dtb``,
* ``rv_platform.py`` — what the runner and the golden generator actually execute.

It also pins the image-loading half of the contract: a payload entry no longer has
to be the window base, the window is bounded, a blob (the device tree) may not
overwrite a loaded segment, and a BootROM is transcribed into the testbench's
32-bit word format. Nothing here needs a toolchain, Spike or Verilator — the dtc
check skips when the harness's ``dtc`` was not built.
"""

from __future__ import annotations

import importlib.util
import os
import re
import struct
import subprocess
import sys
from pathlib import Path
from types import ModuleType

import pytest
import rv_platform
from rv_image import Image
from rv_spike import SpikeError, StopStore, compile_dts, find_dtc

REPO_ROOT = Path(__file__).resolve().parents[4]
HARNESS_DIR = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv"
RUNNER_PATH = REPO_ROOT / "ethereal-shell" / "verif" / "eth_rv_core" / "run_difftest.py"


def _load_runner() -> ModuleType:
    """Import ``run_difftest.py`` by path (it is a script, not an importable package)."""
    spec = importlib.util.spec_from_file_location("rv_rtl_runner_boot", RUNNER_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


runner = _load_runner()


# --- core.yaml ---------------------------------------------------------------------


def test_core_yaml_matches_the_platform_module() -> None:
    """Every contract number is stated once in Python and once in ``core.yaml``."""
    values = rv_platform.read_core_yaml()
    assert values == {
        "hart_count": rv_platform.HART_COUNT,
        "isa": rv_platform.ISA_STRING,
        "ram_base": rv_platform.RAM_BASE,
        "ram_window_bytes": rv_platform.RAM_WINDOW_BYTES,
        "rom_base": rv_platform.ROM_BASE,
        "rom_bytes": rv_platform.ROM_BYTES,
        "rom_step_offset": rv_platform.ROM_STEP_OFFSET,
        "rom_entry_offset": rv_platform.ROM_ENTRY_OFFSET,
        "dtb_addr": rv_platform.DTB_ADDR,
        "uart_base": rv_platform.UART_BASE,
        "uart_reg_bytes": rv_platform.UART_REG_BYTES,
        "clint_base": rv_platform.CLINT_BASE,
        "clint_bytes": rv_platform.CLINT_BYTES,
        "plic_base": rv_platform.PLIC_BASE,
        "plic_bytes": rv_platform.PLIC_BYTES,
        "plic_ndev": rv_platform.PLIC_NDEV,
        "plic_prio_bits": rv_platform.PLIC_PRIO_BITS,
        "uart_irq": rv_platform.UART_IRQ,
        "clock_hz": rv_platform.CLOCK_HZ,
        "timebase_frequency": rv_platform.TIMEBASE_FREQUENCY,
        # the S4 Linux-boot profile (E2-RV2 increment 7): the same file, a second
        # address plan — see rv_platform's S4 section and eth_rv_linux.dts
        "linux_ram_window_bytes": rv_platform.LINUX_RAM_WINDOW_BYTES,
        "linux_fw_addr": rv_platform.LINUX_FW_ADDR,
        "linux_kernel_addr": rv_platform.LINUX_KERNEL_ADDR,
        "linux_dtb_addr": rv_platform.LINUX_DTB_ADDR,
        "linux_rom_dtb_addr": rv_platform.LINUX_ROM_DTB_ADDR,
        "linux_initrd_end": rv_platform.LINUX_INITRD_END,
    }


def test_core_yaml_is_a_flat_key_value_map(tmp_path: Path) -> None:
    """A nested structure the harness cannot read must fail, not be ignored."""
    bad = tmp_path / "core.yaml"
    bad.write_text("cpus:\n  - hart\n", encoding="utf-8")
    with pytest.raises(ValueError, match="flat key: value"):
        rv_platform.read_core_yaml(bad)
    bad.write_text("hart_count\n", encoding="utf-8")
    with pytest.raises(ValueError, match="key: value"):
        rv_platform.read_core_yaml(bad)


# --- the device tree ----------------------------------------------------------------


def _dts_text() -> str:
    path = rv_platform.dts_path()
    assert path is not None and path.is_file()
    return path.read_text(encoding="utf-8")


def _reg(node: str, text: str) -> tuple[int, int]:
    """``(base, size)`` of a 2-cell ``reg`` in the node whose label/handle matches."""
    match = re.search(
        rf'{node}\s*\{{[^}}]*?reg = <0x[0-9a-f]+ 0x([0-9a-f]+) 0x[0-9a-f]+ 0x([0-9a-f]+)>;',
        text,
        re.DOTALL,
    )
    assert match is not None, f"no reg property found for {node}"
    return int(match.group(1), 16), int(match.group(2), 16)


def test_device_tree_declares_the_contract_memory_window() -> None:
    text = _dts_text()
    base, size = _reg(r"memory@[0-9a-f]+", text)
    assert (base, size) == (rv_platform.RAM_BASE, rv_platform.RAM_WINDOW_BYTES)


def test_device_tree_declares_the_same_uart_and_clint() -> None:
    text = _dts_text()
    assert _reg(r"serial@[0-9a-f]+", text) == (rv_platform.UART_BASE, rv_platform.UART_REG_BYTES)
    assert _reg(r"clint@[0-9a-f]+", text) == (rv_platform.CLINT_BASE, rv_platform.CLINT_BYTES)


def test_device_tree_declares_the_plic_and_the_uart_source() -> None:
    """The PLIC node is real hardware since E2-RV2 increment 6, not a placeholder.

    Its window, source count and priority width are the contract's, its
    ``interrupts-extended`` names each hart's M context (11) and then its S
    context (9) — Spike's order, which is what makes the second one the hart's
    ``mip.SEIP`` — and the UART node hangs off it as source ``UART_IRQ`` with a
    level trigger.
    """
    text = _dts_text()
    assert _reg(r"plic@[0-9a-f]+", text) == (rv_platform.PLIC_BASE, rv_platform.PLIC_BYTES)
    assert f"riscv,ndev = <{rv_platform.PLIC_NDEV}>" in text
    assert f"riscv,max-priority = <{(1 << rv_platform.PLIC_PRIO_BITS) - 1}>" in text
    assert 'compatible = "riscv,plic0"' in text
    contexts = re.search(r"plic@[0-9a-f]+\s*\{[^}]*?interrupts-extended = <([^>]*)>;", text)
    assert contexts is not None, "the PLIC node has no interrupts-extended"
    assert [int(cell.split()[-1]) for cell in contexts.group(1).split("&cpu0_intc")[1:]] == [
        11,  # the hart's M context: meip_i
        9,   # ... and its S context: seip_i
    ]
    uart = re.search(r"serial@[0-9a-f]+\s*\{[^}]*\}", text)
    assert uart is not None
    assert "interrupt-parent = <&plic>;" in uart.group(0)
    assert f"interrupts = <{rv_platform.UART_IRQ} 4>;" in uart.group(0)


def test_device_tree_declares_the_pinned_cpu() -> None:
    text = _dts_text()
    assert f'riscv,isa = "{rv_platform.ISA_STRING}"' in text
    assert text.count("cpu@") == rv_platform.HART_COUNT
    assert f"timebase-frequency = <{rv_platform.TIMEBASE_FREQUENCY}>" in text
    assert f"clock-frequency = <{rv_platform.CLOCK_HZ}>" in text
    # the timebase boundary is stated next to the number, not only in the README
    assert "DiffTest" in text and "placeholder" in text


def test_device_tree_compiles_with_the_harness_dtc(tmp_path: Path) -> None:
    """The checked-in source is a real, compilable device tree."""
    try:
        find_dtc()
    except SpikeError as exc:  # pragma: no cover - depends on the local build
        pytest.skip(f"dtc not available: {exc}")
    source = rv_platform.dts_path()
    assert source is not None
    out = compile_dts(source, tmp_path / "eth_rv.dtb")
    assert out.read_bytes()[:4] == b"\xd0\x0d\xfe\xed"  # the FDT magic, big-endian


# --- program images: base/entry are not the window base -----------------------------


def _words(path: Path) -> dict[int, bytes]:
    """Read back a ``@index`` / 16-hex-digit-word image."""
    lines = [line for line in path.read_text(encoding="ascii").splitlines() if line]
    assert len(lines) % 2 == 0
    return {int(lines[i][1:], 16): bytes.fromhex(lines[i + 1]) for i in range(0, len(lines), 2)}


def _memory(path: Path, base: int) -> dict[int, bytes]:
    """The image as byte ranges at their absolute addresses."""
    return {base + 8 * index: word[::-1] for index, word in _words(path).items()}


def test_window_image_accepts_any_entry_and_places_blobs(tmp_path: Path) -> None:
    image = Image(
        name="prog.elf",
        entry=0x8000_0004,
        tohost=0x8000_1000,
        segments=((0x8000_0000, b"\x13\x00\x00\x00\x17\x01\x00\x00"),),
    )
    dtb = b"\xd0\x0d\xfe\xed\x00\x00\x00\x00"
    out = runner.write_window_image(
        image, tmp_path / "prog.mem.hex", blobs=((rv_platform.DTB_ADDR, dtb, "dtb"),)
    )
    assert out.entry == 0x8000_0004  # != the window base: no longer rejected
    assert out.base == rv_platform.RAM_BASE
    assert out.size == rv_platform.RAM_WINDOW_BYTES
    mem = _memory(out.path, out.base)
    assert mem[0x8000_0000][:4] == b"\x13\x00\x00\x00"
    assert mem[rv_platform.DTB_ADDR][:4] == b"\xd0\x0d\xfe\xed"  # word index 1024
    assert out.word_count == 2


def test_window_image_refuses_bytes_outside_the_window(tmp_path: Path) -> None:
    outside = rv_platform.RAM_BASE + rv_platform.RAM_WINDOW_BYTES
    image = Image(name="bad.elf", entry=outside, tohost=outside, segments=((outside, b"\x00"),))
    with pytest.raises(runner.SetupError, match="outside"):
        runner.write_window_image(image, tmp_path / "bad.mem.hex")


def test_window_image_refuses_a_blob_that_overwrites_a_segment(tmp_path: Path) -> None:
    image = Image(
        name="prog.elf", entry=0x8000_0000, tohost=0x8000_1000,
        segments=((0x8000_0000, b"\x00" * 8),),
    )
    with pytest.raises(runner.SetupError, match="overlaps"):
        runner.write_window_image(
            image, tmp_path / "overlap.mem.hex", blobs=((0x8000_0000, b"\x01", "dtb"),)
        )


# --- the BootROM image ---------------------------------------------------------------


def _elf(path: Path, *, entry: int, vaddr: int, data: bytes) -> Path:
    """A minimal ELF64 LE with one PT_LOAD segment (enough for segment extraction)."""
    header = bytearray(64)
    header[0:4] = b"\x7fELF"
    header[4] = 2  # ELFCLASS64
    header[5] = 1  # ELFDATA2LSB
    struct.pack_into("<Q", header, 24, entry)
    struct.pack_into("<Q", header, 32, 64)  # e_phoff
    struct.pack_into("<HH", header, 54, 56, 1)  # e_phentsize, e_phnum
    phdr = bytearray(56)
    struct.pack_into("<I", phdr, 0, 1)  # PT_LOAD
    struct.pack_into("<QQ", phdr, 8, 64 + 56, vaddr)  # p_offset, p_vaddr
    struct.pack_into("<Q", phdr, 32, len(data))  # p_filesz
    path.write_bytes(bytes(header) + bytes(phdr) + data)
    return path


def test_rom_image_passes_through_a_boot_rom_hex(tmp_path: Path) -> None:
    source = tmp_path / "boot_rom.hex"
    source.write_text("# header\n@0000 00000013\n@0008 80000000\n@0009 00000000\n")
    out = runner.write_rom_image(source, tmp_path / "out.hex")
    assert out.path.read_text(encoding="ascii") == source.read_text(encoding="ascii")
    assert out.word_count == 3
    assert out.entry is None


def test_rom_image_rejects_a_file_that_is_neither_elf_nor_hex(tmp_path: Path) -> None:
    source = tmp_path / "nonsense.bin"
    source.write_bytes(b"not a rom")
    with pytest.raises(runner.SetupError, match="not an ELF"):
        runner.write_rom_image(source, tmp_path / "out.hex")


def test_runner_window_is_the_contract_window() -> None:
    """The runner states no address of its own: it imports the contract."""
    assert runner.MEM_BASE == rv_platform.RAM_BASE
    assert runner.MEM_WINDOW_BYTES == rv_platform.RAM_WINDOW_BYTES
    assert f"-DETH_RV_MEM_BYTES={rv_platform.RAM_WINDOW_BYTES}" in runner.verilator_defines(False, 8)
    assert runner.verilator_defines(True, 4) == [
        f"-DETH_RV_MEM_BYTES={rv_platform.RAM_WINDOW_BYTES}",
        "-DETH_RV_DRAM_AXI",
        "-DETH_RV_LINE_BEATS=4",
    ]


def test_tb_argv_carries_the_boot_contract(tmp_path: Path) -> None:
    """Every S3 knob reaches the testbench as a plusarg, none is invented ad hoc."""
    mem = runner.MemoryImage(
        path=tmp_path / "prog.mem.hex",
        base=rv_platform.RAM_BASE,
        size=rv_platform.RAM_WINDOW_BYTES,
        entry=0x8000_0004,
        tohost=0x8000_1000,
        word_count=2,
    )
    rom = runner.RomImage(
        path=tmp_path / "rom.hex", source=tmp_path / "boot_rom.elf", word_count=3, entry=None
    )
    dtb = tmp_path / "eth_rv.dtb"
    argv = runner.tb_argv(
        tmp_path / "Veth_rv_tb",
        mem=mem,
        trace_path=tmp_path / "prog.trace",
        uart_path=tmp_path / "prog.uart",
        mem_lat=1,
        rom=rom,
        dtb=dtb,
        stop=StopStore(0x8000_01A4, 0x0BADF00D),
    )
    assert f"+mem={tmp_path / 'prog.mem.hex'}" in argv
    assert "+base=0x80000000" in argv
    assert "+entry=0x80000004" in argv  # the payload entry, not the window base
    assert "+tohost=0x80001000" in argv
    assert f"+mem_bytes={rv_platform.RAM_WINDOW_BYTES}" in argv
    assert f"+rom={tmp_path / 'rom.hex'}" in argv
    assert f"+dtb={dtb}" in argv
    assert "+stop_addr=0x800001a4" in argv
    assert "+stop_value=0xbadf00d" in argv


def test_tb_argv_omits_the_optional_contract_plusargs(tmp_path: Path) -> None:
    mem = runner.MemoryImage(
        path=tmp_path / "m.hex", base=rv_platform.RAM_BASE, size=rv_platform.RAM_WINDOW_BYTES,
        entry=0x8000_0000, tohost=0x8000_1000, word_count=2,
    )
    argv = runner.tb_argv(
        tmp_path / "tb", mem=mem, trace_path=tmp_path / "t.trace",
        uart_path=tmp_path / "t.uart", mem_lat=0,
    )
    assert not any(arg.startswith(("+rom=", "+dtb=", "+stop_addr=", "+stop_value=")) for arg in argv)


def test_checked_in_boot_rom_hex_is_up_to_date(riscv_gcc: str) -> None:
    """The ROM image the testbench loads is generated; it must not drift from its source.

    ``build_rom.py`` is the only producer of ``rom/boot_rom.hex``, and
    :data:`rv_platform.ROM_ENTRY_OFFSET` is the word its payload entry lands in.
    ``--check`` rebuilds into a temporary directory and compares, so a hand-edited
    image or a changed stub fails here instead of at run time.
    """
    script = REPO_ROOT / "ethereal-shell" / "rtl" / "eth_rv" / "rom" / "build_rom.py"
    if not script.is_file():
        pytest.skip(f"the BootROM builder is not present: {script}")
    env = {**os.environ, "RISCV_PREFIX": str(Path(riscv_gcc).parent)}
    proc = subprocess.run(
        [sys.executable, str(script), "--check"],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert proc.returncode == 0, f"{proc.stdout}\n{proc.stderr}"
    assert "up to date" in proc.stdout


def test_rom_image_transcribes_an_elf_with_its_entry_at_the_contract_offset(tmp_path: Path) -> None:
    # the stub's own data words are 28 bytes in: word 7 is the step count the
    # CLINT's mtime phase is derived from (boot_rom.S), so transcription must keep
    # it and only overlay the payload entry at word 8.
    step = rv_platform.ROM_STEP_OFFSET
    assert step + 4 == rv_platform.ROM_ENTRY_OFFSET  # step word immediately before entry
    stub = b"\x13\x00\x00\x00" + bytes(step - 4) + (7).to_bytes(4, "little")
    elf = _elf(
        tmp_path / "boot_rom.elf",
        entry=0x8000_0004,
        vaddr=rv_platform.ROM_BASE,
        data=stub,
    )
    out = runner.write_rom_image(elf, tmp_path / "boot_rom.hex")
    assert out.entry == 0x8000_0004
    words = {
        int(line.split()[0][1:], 16): int(line.split()[1], 16)
        for line in out.path.read_text(encoding="ascii").splitlines()
    }
    assert words[0] == 0x00000013  # the first instruction at ROM_BASE
    assert words[step // 4] == 7  # the stub step count survives the transcription
    entry_word = rv_platform.ROM_ENTRY_OFFSET // 4
    assert entry_word == step // 4 + 1
    assert words[entry_word] == 0x8000_0004
    assert words.get(entry_word + 1, 0) == 0  # sparse: a zero high word is omitted
