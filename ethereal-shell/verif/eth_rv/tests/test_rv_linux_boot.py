#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""S4 (E2-RV2 increment 7) contract tests: the Linux-boot profile, its device tree,
the S4 BootROM image and the runner's plusargs.

These are all *static* checks — no simulator, no network, no built images — so they
run in the same pytest sweep as the rest of the harness (``make verif-rv``) and fail
on the things that would otherwise only show up as a mysterious boot failure:

* the device tree the kernel will be handed (window, console, no `sstc`, tokens),
* the S4 BootROM layout (Spike's reset vector, the moved entry word and step word,
  the tree inside the 4 KiB page, and the "does not fit" failure),
* the runner's plusargs (a1, the ROM-resident tree, the entry, the marker, the
  synchronisation point) and Spike's argv (same window, same tree),
* the initramfs init script and the milestone it prints.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path
from types import ModuleType

import pytest

HERE = Path(__file__).resolve().parent
ETH_RV_DIR = HERE.parent                 # verif/eth_rv
VERIF_DIR = ETH_RV_DIR.parent            # verif
RUNNER_DIR = VERIF_DIR / "eth_rv_core"   # verif/eth_rv_core

sys.path.insert(0, str(ETH_RV_DIR))

import rv_platform  # noqa: E402


def _load(path: Path, name: str) -> ModuleType:
    """Import a script (``.py``) by path — neither is an importable package."""
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


builder = _load(ETH_RV_DIR / "build_linux_boot.py", "s4_build_linux_boot")
runner = _load(RUNNER_DIR / "run_linux_boot.py", "s4_run_linux_boot")


def _dts_text() -> str:
    return (ETH_RV_DIR / "eth_rv_linux.dts").read_text(encoding="utf-8")


def _init_text() -> str:
    return (ETH_RV_DIR / "s4" / "init").read_text(encoding="utf-8")


# --- the profile ------------------------------------------------------------------


def test_linux_window_holds_the_whole_layout() -> None:
    """The 40 MiB window is the plan's arithmetic, not a round number."""
    window = rv_platform.LINUX_RAM_WINDOW_BYTES
    assert window == 40 * (1 << 20)
    # kernel: text_offset is both the kernel's and OpenSBI's jump offset
    assert rv_platform.LINUX_KERNEL_ADDR == rv_platform.RAM_BASE + 0x20_0000
    assert rv_platform.LINUX_KERNEL_ADDR == rv_platform.RAM_BASE + rv_platform.LINUX_KERNEL_TEXT_OFFSET
    # the stock OpenSBI FDT slot is the last thing placed in RAM before the initramfs
    assert rv_platform.LINUX_DTB_ADDR == rv_platform.RAM_BASE + 0x220_0000
    assert rv_platform.LINUX_DTB_ADDR < rv_platform.LINUX_INITRD_END
    assert rv_platform.LINUX_INITRD_END == rv_platform.RAM_BASE + window - 0x1000
    # firmware and kernel do not overlap
    assert rv_platform.LINUX_FW_ADDR == rv_platform.RAM_BASE
    assert rv_platform.LINUX_FW_ADDR < rv_platform.LINUX_KERNEL_ADDR


def test_linux_dts_declares_the_boot_contract() -> None:
    """The tree the kernel gets: window, console, initramfs tokens, no `sstc`."""
    text = re.sub(r"//[^\n]*", "", _dts_text())
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    assert "linux,initrd-start = <@INITRD_START@>" in text
    assert "linux,initrd-end = <@INITRD_END@>" in text
    assert 'bootargs = "console=ttyS0 earlycon"' in text
    assert "stdout-path = &serial0" in text
    assert f"0x{rv_platform.LINUX_RAM_WINDOW_BYTES:x}>" in text  # memory: 40 MiB
    assert f'riscv,isa = "{rv_platform.ISA_STRING}"' in text
    assert 'mmu-type = "riscv,sv39"' in text
    assert "clock-frequency = <10000000>" in text  # what a 8250 probe needs
    assert "interrupts-extended = <&cpu0_intc 11 &cpu0_intc 9>" in text
    # declared absences: the hart has no stimecmp, no IMSIC/APIC, no cache ops
    for absent in ("sstc", "imsic", "aplic", "zicbom", "zicboz"):
        assert absent not in text, f"{absent} must not be advertised"
    assert "plic@c000000" in text and "riscv,ndev = <31>" in text


def test_init_script_prints_the_milestone() -> None:
    """The initramfs's PID 1 announces itself with the byte string the TB stops on."""
    text = _init_text()
    assert "@MILESTONE@" in text, "the build substitutes the marker into this token"
    assert text.startswith("#!/bin/busybox sh")
    marker = rv_platform.LINUX_MILESTONE
    assert marker.decode("ascii").isprintable()
    assert b"@MILESTONE@" not in marker
    # the marker is echoed as its own line, so a decoder sees it as a whole line
    assert 'echo "@MILESTONE@"' in text


# --- the S4 BootROM ---------------------------------------------------------------


def test_s4_boot_rom_mirrors_spikes_reset_vector(tmp_path: Path) -> None:
    """The DUT's ROM and Spike's ROM agree on every word the core ever fetches.

    Spike's own reset vector is five instructions that take the payload entry from
    word 6 and leave a1 = ROM base + 32; the DUT's ROM must be that, or the firmware
    portion is not diffable. The only deliberate difference is word 5 (the stub's
    instruction count for the CLINT), which the stub never executes.
    """
    dtb = b"\xd0\x0d\xfe\xed" + bytes(64)
    manifest = builder.build_rom(tmp_path, dtb)
    assert manifest["rom_entry_word"] == 6
    assert manifest["rom_stub_word"] == 5
    assert manifest["rom_stub_steps"] == 5
    image = (tmp_path / manifest["boot_rom_bin"]).read_bytes()
    words = [int.from_bytes(image[4 * i : 4 * i + 4], "little") for i in range(10)]
    reset_vec_size = 8
    assert words[0] == 0x297  # auipc t0, 0
    assert words[1] == 0x28593 + (reset_vec_size * 4 << 20)  # addi a1, t0, 32
    assert words[2] == 0xF1402573  # csrr a0, mhartid
    assert words[3] == 0x0182B283  # ld t0, 24(t0)
    assert words[4] == 0x00028067  # jr t0
    assert words[5] == rv_platform.LINUX_ROM_STUB_STEPS
    entry = words[6] | (words[7] << 32)
    assert entry == rv_platform.LINUX_FW_ENTRY
    assert image[32 : 32 + len(dtb)] == dtb  # the tree at a1 = ROM_BASE + 32
    assert rv_platform.LINUX_ROM_DTB_ADDR - rv_platform.ROM_BASE == 32
    # the hex image the TB loads says the same thing
    hex_text = (tmp_path / manifest["boot_rom_hex"]).read_text(encoding="ascii")
    assert "entry_word 6" in hex_text and "stub_word 5" in hex_text
    assert f"@{builder.ROM_DTB_OFFSET // 4:04x} edfe0dd0" in hex_text


def test_s4_boot_rom_refuses_a_tree_that_does_not_fit(tmp_path: Path) -> None:
    """The tree shares the 4 KiB page with the reset vector: 4064 B is the budget."""
    too_big = b"\xd0\x0d\xfe\xed" + bytes(builder.ROM_BYTES)
    with pytest.raises(builder.BuildError, match="does not fit"):
        builder.build_rom(tmp_path, too_big)


# --- the runner -------------------------------------------------------------------


def _fake_images(tmp_path: Path) -> dict[str, object]:
    """A manifest plus the image files the runner reads, without a real build."""
    (tmp_path / "fw_jump.bin").write_bytes(bytes(0x40))
    (tmp_path / "Image").write_bytes(bytes(0x40))
    dtb = b"\xd0\x0d\xfe\xed" + bytes(0x20)
    (tmp_path / "eth_rv_linux.dtb").write_bytes(dtb)
    size = 0x1000
    (tmp_path / "initramfs.cpio.gz").write_bytes(bytes(size))
    return {
        "dt": {"dtb": "eth_rv_linux.dtb", "initrd_start": rv_platform.LINUX_INITRD_END - size},
        "rom": {"boot_rom_hex": "boot_rom_s4.hex"},
        "opensbi": {"fw_jump_elf": "fw_jump.elf"},
    }


def test_runner_pins_the_s4_boot_contract(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """`+a1_addr`/`+rom_dtb`/`+entry`/`+mem_bytes` are the S4 profile, not defaults."""
    monkeypatch.setattr(runner, "S4_DIR", tmp_path)
    manifest = _fake_images(tmp_path)
    argv = runner.rtl_argv(
        tmp_path / "Veth_rv_tb", out=tmp_path, manifest=manifest, trace=None,
        stop_pc=None, max_cycles=1000, max_traps=10,
    )
    joined = " ".join(argv)
    assert f"+mem_bytes={rv_platform.LINUX_RAM_WINDOW_BYTES}" in joined
    assert f"+entry=0x{rv_platform.LINUX_FW_ENTRY:x}" in joined
    assert f"+a1_addr=0x{rv_platform.LINUX_ROM_DTB_ADDR:x}" in joined
    assert "+rom_dtb=1" in joined
    assert f"+uart_marker={rv_platform.LINUX_MILESTONE.hex()}" in joined
    assert not any(arg.startswith("+trace=") for arg in argv), "no trace unless asked"
    assert not any(arg.startswith("+stop_pc=") for arg in argv)
    diff = runner.rtl_argv(
        tmp_path / "Veth_rv_tb", out=tmp_path, manifest=manifest, trace=tmp_path / "t",
        stop_pc=rv_platform.LINUX_KERNEL_ADDR, max_cycles=1000, max_traps=10,
    )
    assert f"+stop_pc=0x{rv_platform.LINUX_KERNEL_ADDR:x}" in " ".join(diff)
    assert f"+trace={tmp_path / 't'}" in " ".join(diff)


def test_runner_memory_image_places_every_blob(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Firmware, kernel, tree and initramfs land at the profile's addresses."""
    monkeypatch.setattr(runner, "S4_DIR", tmp_path)
    manifest = _fake_images(tmp_path)
    image = runner.build_memory_image(tmp_path, manifest)
    placed = dict(image.segments)
    assert set(placed) == {
        rv_platform.LINUX_FW_ADDR,
        rv_platform.LINUX_KERNEL_ADDR,
        rv_platform.LINUX_DTB_ADDR,
        manifest["dt"]["initrd_start"],  # type: ignore[index]
    }
    assert image.entry == rv_platform.LINUX_FW_ENTRY
    assert placed[rv_platform.LINUX_DTB_ADDR].startswith(b"\xd0\x0d\xfe\xed")


def test_spike_argv_uses_the_same_window_and_tree() -> None:
    """Spike is given the same window, tree, kernel and initramfs the DUT preloads."""
    manifest = {
        "dt": {"dtb": "eth_rv_linux.dtb"},
        "opensbi": {"fw_jump_elf": "fw_jump.elf"},
    }
    argv = runner.spike_argv(manifest)
    assert f"-m0x{rv_platform.RAM_BASE:x}:{rv_platform.LINUX_RAM_WINDOW_BYTES}" in argv
    assert any(arg.startswith("--dtb=") for arg in argv)
    assert any(arg.startswith("--kernel=") for arg in argv)
    assert any(arg.startswith("--initrd=") for arg in argv)
    assert argv[-1].endswith("fw_jump.elf")
    assert f"--isa={rv_platform.ISA_STRING}" in argv
