# SPDX-License-Identifier: MIT
"""Tests for Spike log normalization (:mod:`rv_spike`).

The fixture log in ``tests/fixtures`` is real Spike output (provenance in its
header), including the two things normalization must cut off: Spike's own boot
ROM before the program and the program's spin loop after the HTIF exit store.
"""
from __future__ import annotations

import struct
from pathlib import Path

import pytest
from rv_image import Image, ImageError, load_elf_image
from rv_spike import (
    DEFAULT_ISA,
    SpikeError,
    build_spike_command,
    is_spike_log,
    last_golden_line,
    normalize_spike_log,
)
from rv_trace import TraceFormatError

FIXTURE_LOG = "cor_model.spike_log.txt"
FIXTURE_HEX = "cor_model.hex"
GOLDEN_COMMITS = 116


def test_is_spike_log_discriminates() -> None:
    assert is_spike_log("core   0: 3 0x0000000080000000 (0x00000297) x5  0x1\n")
    assert not is_spike_log("# rv_difftest trace v1\n1 0x80000000 - -\n")
    assert not is_spike_log("core   0: 0x0000000080000000 (0x00000297) auipc t0, 0x0\n")


def test_log_skips_boot_rom_and_stops_at_htif_store(
    golden_log_text: str, fixture_image: Image
) -> None:
    commits = normalize_spike_log(
        golden_log_text,
        source=FIXTURE_LOG,
        tohost=fixture_image.tohost,
        entry=fixture_image.entry,
    )
    assert len(commits) == GOLDEN_COMMITS
    assert commits[0].pc == fixture_image.entry
    assert commits[0].insn == 0x0000_A117  # auipc sp, 0xa
    assert commits[0].rd == 2
    assert [commit.cycle for commit in commits] == list(range(1, GOLDEN_COMMITS + 1))
    assert all(commit.pc >= fixture_image.entry for commit in commits)
    # the stream ends on the HTIF exit store: no register write, stores to the mailbox
    exit_line = golden_log_text.splitlines()[
        last_golden_line(
            golden_log_text,
            tohost=fixture_image.tohost,
            entry=fixture_image.entry,
        )
    ]
    assert commits[-1].rd is None
    assert f"0x{commits[-1].pc:016x}" in exit_line
    assert f"mem 0x{fixture_image.tohost:016x}" in exit_line


def test_log_without_entry_keeps_boot_rom(golden_log_text: str, fixture_image: Image) -> None:
    """Without an entry address the stream starts at Spike's debug ROM (pc 0x1000)."""
    commits = normalize_spike_log(golden_log_text, source=FIXTURE_LOG)
    assert commits[0].pc == 0x1000
    assert (0x1000, 5) in {(commit.pc, commit.rd) for commit in commits}
    # no tohost cut either: the program's spin loop is included
    assert len(commits) > GOLDEN_COMMITS


def test_compressed_instruction_words_are_captured(
    golden_log_text: str, fixture_image: Image
) -> None:
    commits = normalize_spike_log(
        golden_log_text, source=FIXTURE_LOG, tohost=fixture_image.tohost, entry=fixture_image.entry
    )
    widths = {commit.insn.bit_length() for commit in commits if commit.insn is not None}
    assert min(widths) <= 16  # 16-bit compressed instructions survive normalization
    assert max(widths) > 16  # and so do 32-bit ones


def test_last_golden_line_points_at_the_exit_store(
    golden_log_text: str, fixture_image: Image
) -> None:
    lines = golden_log_text.splitlines()
    index = last_golden_line(
        golden_log_text,
        source=FIXTURE_LOG,
        tohost=fixture_image.tohost,
        entry=fixture_image.entry,
    )
    assert "mem 0x0000000080001000" in lines[index]
    assert index < len(lines) - 1  # the tracked fixture keeps a tail of spin-loop lines


def test_last_golden_line_is_minus_one_for_a_useless_log() -> None:
    assert last_golden_line("nothing to see here\n", tohost=0, entry=None) == -1


def test_multi_register_commit_line_is_rejected() -> None:
    text = "core   0: 3 0x0000000080000000 (0x00000297) x5  0x1 x6  0x2\n"
    with pytest.raises(TraceFormatError, match="more than one integer register"):
        normalize_spike_log(text, source="synthetic.log")


def test_spike_command_is_pinned_to_the_corpus_flags(tmp_path: Path) -> None:
    argv = build_spike_command("/opt/spike", "prog.elf", isa=DEFAULT_ISA, log_path=tmp_path / "l.log")
    assert argv[1] == "--isa=rv64imc"
    assert "--log-commits" in argv
    assert argv[0] == "/opt/spike"
    assert argv[-1] == "prog.elf"
    assert argv[-2] == f"--log={tmp_path / 'l.log'}"


def test_missing_spike_binary_is_reported(tmp_path: Path) -> None:
    from rv_spike import find_spike

    with pytest.raises(SpikeError, match="not found"):
        find_spike(tmp_path / "nope")


def test_non_elf_image_is_rejected(tmp_path: Path, fixtures_dir: Path) -> None:
    plain = tmp_path / "not.elf"
    plain.write_bytes((fixtures_dir / FIXTURE_HEX).read_bytes())
    with pytest.raises(ImageError, match="not an ELF file"):
        load_elf_image(plain)


def test_elf_without_tohost_symbol_is_rejected(tmp_path: Path) -> None:
    """A valid-looking ELF with no symbol table cannot drive the exit protocol."""
    header = bytearray(64)
    header[0:4] = b"\x7fELF"
    header[4] = 2  # ELFCLASS64
    header[5] = 1  # ELFDATA2LSB
    struct.pack_into("<Q", header, 24, 0x8000_0000)  # e_entry
    struct.pack_into("<Q", header, 32, 64)  # e_phoff
    struct.pack_into("<HH", header, 54, 56, 1)  # e_phentsize, e_phnum
    phdr = bytearray(56)
    struct.pack_into("<I", phdr, 0, 1)  # PT_LOAD
    struct.pack_into("<QQ", phdr, 8, 120, 0x8000_0000)  # p_offset, p_vaddr
    struct.pack_into("<Q", phdr, 32, 4)  # p_filesz
    elf = tmp_path / "nosym.elf"
    elf.write_bytes(bytes(header) + bytes(phdr) + b"\x13\x00\x00\x00")
    with pytest.raises(ImageError, match="no `tohost` symbol"):
        load_elf_image(elf)
