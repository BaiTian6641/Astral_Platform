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
    GoldenConfig,
    SpikeError,
    StopStore,
    build_spike_command,
    is_spike_log,
    last_golden_line,
    normalize_spike_log,
    parse_stop_store,
    truncate_at_stop,
)
from rv_trace import Commit, TraceFormatError, stream_has_fp_info

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
        stop=StopStore(fixture_image.tohost),
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
            stop=StopStore(fixture_image.tohost),
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
        golden_log_text, source=FIXTURE_LOG, stop=StopStore(fixture_image.tohost), entry=fixture_image.entry
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
        stop=StopStore(fixture_image.tohost),
        entry=fixture_image.entry,
    )
    assert "mem 0x0000000080001000" in lines[index]
    assert index < len(lines) - 1  # the tracked fixture keeps a tail of spin-loop lines


def test_last_golden_line_is_minus_one_for_a_useless_log() -> None:
    assert last_golden_line("nothing to see here\n", stop=StopStore(0), entry=None) == -1


def test_multi_register_commit_line_is_rejected() -> None:
    text = "core   0: 3 0x0000000080000000 (0x00000297) x5  0x1 x6  0x2\n"
    with pytest.raises(TraceFormatError, match="more than one integer register"):
        normalize_spike_log(text, source="synthetic.log")


def test_amo_commit_line_keeps_the_write_of_the_read_modify_write() -> None:
    """An AMO is TWO `mem` fields in Spike's log — the normalizer keeps the write.

    `amoadd.w` of 0x55667788 to 0x11223344 logs the read (address only) and then
    the write (address + data); the canonical record carries one access, so the
    write is what survives, with the old value in `rd`. A two-field line that is
    not a read-then-write at one address is still a hard error.
    """
    text = (
        "core   0: 3 0x000000008000003c (0x00c526af) x13 0x0000000011223344 "
        "mem 0x0000000080001000 mem 0x0000000080001000 0x000000006688aacc\n"
    )
    (commit,) = normalize_spike_log(text, source="amo.log")
    assert commit.rd == 13
    assert commit.value == 0x11223344
    assert commit.mem_addr == 0x80001000
    assert commit.mem_wdata == 0x6688AACC


def test_two_memory_accesses_that_are_not_an_amo_are_rejected() -> None:
    text = (
        "core   0: 3 0x000000008000003c (0x00c526af) x13 0x0000000011223344 "
        "mem 0x0000000080001000 mem 0x0000000080001008 0x000000006688aacc\n"
    )
    with pytest.raises(TraceFormatError, match="not an AMO's read-then-write"):
        normalize_spike_log(text, source="bad.log")


def test_wfi_commits_with_no_register_and_no_memory() -> None:
    """`wfi` is an ordinary commit with no architectural effect (E2-RV2 incr. 3)."""
    text = "core   0: 3 0x0000000080000070 (0x10500073)\n"
    (commit,) = normalize_spike_log(text, source="wfi.log")
    assert commit.pc == 0x80000070
    assert commit.insn == 0x10500073
    assert commit.rd is None
    assert commit.mem_addr is None


def test_spike_command_is_pinned_to_the_corpus_flags(tmp_path: Path) -> None:
    config = GoldenConfig(isa=DEFAULT_ISA)
    argv = build_spike_command("/opt/spike", "prog.elf", config=config, log_path=tmp_path / "l.log")
    # the ISA whose misa advertises I|M|A|F|D|C|S|U (0x8000_0000_0014_112d)
    assert DEFAULT_ISA == "rv64imafdc_zicsr_zicntr"
    assert argv[1] == f"--isa={DEFAULT_ISA}"
    assert argv[2] == "-m0x80000000:1048576"
    assert "--log-commits" in argv
    assert argv[0] == "/opt/spike"
    assert argv[-1] == "prog.elf"
    assert argv[-2] == f"--log={tmp_path / 'l.log'}"
    # nothing optional is passed unless it was asked for
    assert not any(flag.startswith(("--dtb", "--bootargs", "--pc=", "--pcs", "--disable-dtb")) for flag in argv)


def test_spike_command_carries_every_golden_flag(tmp_path: Path) -> None:
    config = GoldenConfig(
        dtb=Path("eth_rv.dtb"),
        bootargs="console=ttyS0 earlycon",
        pc=0x8000_2000,
        pcs="0:0x80000000",
        stop=StopStore(0x8000_1000, 1),
    )
    argv = build_spike_command("spike", "prog.elf", config=config, log_path=tmp_path / "l.log")
    assert "--dtb=eth_rv.dtb" in argv
    assert "--bootargs=console=ttyS0 earlycon" in argv
    assert "--pc=0x80002000" in argv
    assert "--pcs=0:0x80000000" in argv
    assert "-m0x80000000:1048576" in argv
    text = config.describe()
    for fragment in ("mem=-m0x80000000:1048576", "dtb=eth_rv.dtb", "pc=0x80002000", "stop=store@0x80001000=0x1"):
        assert fragment in text


def test_disable_dtb_and_dtb_are_mutually_exclusive(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="mutually exclusive"):
        GoldenConfig(dtb=Path("x.dtb"), dtb_enabled=False)


def test_disable_dtb_is_passed_and_recorded(tmp_path: Path) -> None:
    config = GoldenConfig(dtb_enabled=False)
    argv = build_spike_command("spike", "prog.elf", config=config, log_path=tmp_path / "l.log")
    assert "--disable-dtb" in argv
    assert "dtb=disabled" in config.describe()


def test_mem_size_must_be_positive() -> None:
    with pytest.raises(ValueError, match="must be positive"):
        GoldenConfig(mem_size=0)


def test_stop_store_parses_address_and_optional_value() -> None:
    assert parse_stop_store("0x80001000") == StopStore(0x8000_1000)
    assert parse_stop_store("2147487744") == StopStore(0x8000_1000)
    assert parse_stop_store("0x80001000:0x1") == StopStore(0x8000_1000, 1)
    assert parse_stop_store("0x80001000:1") == StopStore(0x8000_1000, 1)
    for bad in ("", "start", "0x80001000:", "0x80001000:0x1:0x2"):
        with pytest.raises(ValueError, match="ADDR"):
            parse_stop_store(bad)


def test_stop_store_matches_only_stores() -> None:
    stop = StopStore(0x8000_1000, 1)
    assert stop.matches(0x8000_1000, 1)
    assert not stop.matches(0x8000_1000, 2)  # wrong value
    assert not stop.matches(0x8000_1000, None)  # a load, not a store
    assert not stop.matches(0x8000_2000, 1)  # wrong address
    assert StopStore(0x8000_1000).matches(0x8000_1000, 0xABC)


def test_truncate_at_stop_cuts_after_the_event() -> None:
    commits = [
        Commit(cycle=index, pc=0x100, rd=None, value=None, mem_addr=0x8000_1000, mem_wdata=index)
        for index in (1, 2, 3)
    ]
    assert [c.cycle for c in truncate_at_stop(commits, StopStore(0x8000_1000, 2))] == [1, 2]
    assert truncate_at_stop(commits, None) == commits
    # a stop event that is never reached is an error, not a silent full-stream pass
    with pytest.raises(TraceFormatError, match="does not reach the stopping store"):
        truncate_at_stop(commits, StopStore(0x9999))


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


# --- the FP record (RV-C) ----------------------------------------------------------


PROBE_FP_LINES = """\
core   0: 3 0x0000000080000030 (0xf20280d3) f1  0x3ff0000000000000
core   0: 3 0x0000000080000042 (0x1a31f253) c1_fflags 0x0000000000000010 f4  0x7ff8000000000000
core   0: 3 0x0000000080000090 (0x003e9073) c1_fflags 0x0000000000000000 c2_frm 0x0000000000000001
core   0: 3 0x0000000080000030 (0xf20280d3) f1  0x3ff0000000000000 c768_mstatus 0x8000000a00006000
core   0: 3 0x0000000080000078 (0x00043907) f18 0x4008000000000000 mem 0x00000000800000a8
core   0: 3 0x0000000080000080 (0x00842987) f19 0xffffffff00000000 mem 0x00000000800000b0
"""
"""The FP probe lines quoted verbatim in ``local://rv8-trace-spec.md`` (Spike 1e05ddac)."""


def test_probe_fp_log_normalizes_to_fp_commits() -> None:
    commits = normalize_spike_log(PROBE_FP_LINES, source="probe.log")
    assert commits == [
        Commit(
            cycle=1,
            pc=0x8000_0030,
            rd=1,
            value=0x3FF0_0000_0000_0000,
            insn=0xF20280D3,
            rd_is_fp=True,
        ),
        Commit(
            cycle=2,
            pc=0x8000_0042,
            rd=4,
            value=0x7FF8_0000_0000_0000,
            insn=0x1A31F253,
            rd_is_fp=True,
            fflags=0x10,
        ),
        # a `csrw fflags/frm` writes no register, only the keyed FP state
        Commit(cycle=3, pc=0x8000_0090, insn=0x003E9073, fflags=0x00, frm=0x01),
        # `c768_mstatus` is logged but carries no canonical field: ignored
        Commit(
            cycle=4,
            pc=0x8000_0030,
            rd=1,
            value=0x3FF0_0000_0000_0000,
            insn=0xF20280D3,
            rd_is_fp=True,
        ),
        # an FP load carries the address only, like an integer load
        Commit(
            cycle=5,
            pc=0x8000_0078,
            rd=18,
            value=0x4008_0000_0000_0000,
            insn=0x00043907,
            rd_is_fp=True,
            mem_addr=0x8000_00A8,
        ),
        # `flw` of a zero word: Spike logs the value already NaN-boxed
        Commit(
            cycle=6,
            pc=0x8000_0080,
            rd=19,
            value=0xFFFF_FFFF_0000_0000,
            insn=0x00842987,
            rd_is_fp=True,
            mem_addr=0x8000_00B0,
        ),
    ]
    assert stream_has_fp_info(commits)


def test_keyed_csr_and_memory_suffix_coexist() -> None:
    commits = normalize_spike_log(
        "core   0: 3 0x0000000080000080 (0x00842987) c1_fflags 0x0000000000000010 "
        "f19 0xffffffff00000000 mem 0x00000000800000b0\n",
        source="synthetic.log",
    )
    assert commits[0].fflags == 0x10
    assert commits[0].mem_addr == 0x8000_00B0
    assert commits[0].mem_wdata is None
    assert commits[0].rd == 19
    assert commits[0].rd_is_fp


def test_f0_write_is_kept_by_normalization() -> None:
    """f0 is a real register: unlike x0 its write is part of the record."""
    commits = normalize_spike_log(
        "core   0: 3 0x0000000080000000 (0xd20280d3) f0  0x3ff0000000000000\n",
        source="synthetic.log",
    )
    assert commits == [
        Commit(
            cycle=1,
            pc=0x8000_0000,
            rd=0,
            value=0x3FF0_0000_0000_0000,
            insn=0xD20280D3,
            rd_is_fp=True,
        )
    ]


def test_integer_only_log_has_no_fp_record(
    golden_log_text: str, fixture_image: Image
) -> None:
    """A pre-FP stream must come out not FP-aware, never silently FP-matching."""
    commits = normalize_spike_log(
        golden_log_text,
        source=FIXTURE_LOG,
        stop=StopStore(fixture_image.tohost),
        entry=fixture_image.entry,
    )
    assert not stream_has_fp_info(commits)
    assert all(not commit.rd_is_fp for commit in commits)
    assert all(commit.fflags is None and commit.frm is None for commit in commits)


def test_multi_fp_register_commit_line_is_rejected() -> None:
    text = "core   0: 3 0x0000000080000000 (0x00000297) f4  0x1 f5  0x2\n"
    with pytest.raises(TraceFormatError, match="more than one floating-point register"):
        normalize_spike_log(text, source="synthetic.log")


def test_commit_line_mixing_register_classes_is_rejected() -> None:
    text = "core   0: 3 0x0000000080000000 (0x00000297) x5  0x1 f4  0x2\n"
    with pytest.raises(TraceFormatError, match="both an integer and a floating-point"):
        normalize_spike_log(text, source="synthetic.log")


def test_duplicate_fp_csr_update_is_rejected() -> None:
    text = "core   0: 3 0x0000000080000000 (0x00000297) c1_fflags 0x1 c1_fflags 0x2\n"
    with pytest.raises(TraceFormatError, match="fflags more than once"):
        normalize_spike_log(text, source="synthetic.log")
