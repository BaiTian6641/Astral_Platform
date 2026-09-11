# SPDX-License-Identifier: MIT
"""Tests for the worked-example DUT (:mod:`rv_model`) and the image loaders.

The capstone assertion is that the Python interpreter reproduces Spike's commit
stream *exactly* for the model-targeted corpus program, using only the checked-in
fixtures — i.e. the harness's pass path is verified without the toolchain or
Spike being installed. The immediate-decode tables pin the encodings that the
diff loop actually caught bugs in (see ``tests/fixtures`` provenance and
``local://rvdifftest-notes.md``).
"""
from __future__ import annotations

from pathlib import Path

import pytest
from rv_image import Image, ImageError, load_hex_image, load_image
from rv_model import (
    ModelError,
    Rv64ImcModel,
    UnsupportedInstruction,
    run_image,
    trace_text_for_image,
)
from rv_trace import Commit, parse_trace

# --- immediates taken from `riscv64-unknown-elf-objdump -d` of the corpus ELFs -----


@pytest.mark.parametrize(
    ("insn", "expected"),
    [
        (0xA001, 0),  # `j .` spin loop (crt0)
        (0xA019, 6),  # `c.j` forward
        (0xB7FD, -18),  # `j .Lsum` backwards (the imm[5] regression)
    ],
)
def test_cj_immediate(insn: int, expected: int) -> None:
    assert Rv64ImcModel._c_j_imm(insn) == expected


@pytest.mark.parametrize(
    ("insn", "expected"),
    [
        (0xC099, 6),  # c.beqz s1, +6
        (0xE099, 6),  # c.bnez s1, +6
        (0xE8D5, 180),  # c.bnez s1, +180
    ],
)
def test_cb_immediate(insn: int, expected: int) -> None:
    assert Rv64ImcModel._c_b_imm(insn) == expected


def _sp_model() -> Rv64ImcModel:
    """A model with a known sp and no memory, for decode unit tests."""
    model = Rv64ImcModel(Image(name="empty", entry=0, tohost=8, segments=()))
    model.x[2] = 0x8000_A000
    return model


@pytest.mark.parametrize(("insn", "expected"), [(0x713D, -32), (0x6105, 32)])
def test_c_addi16sp_immediate(insn: int, expected: int) -> None:
    """c.addi16sp's immediate is scattered over inst[12], inst[6], inst[5], inst[4:3], inst[2]."""
    model = _sp_model()
    assert (insn >> 13) & 0b111 == 0b011
    rd, value, _ = model._exec_c1(insn, 0b011, (insn >> 7) & 0x1F, 0, 0x1000)
    assert rd == 2
    assert value == (0x8000_A000 + expected) & 0xFFFF_FFFF_FFFF_FFFF


def test_c_addi4spn_immediate() -> None:
    """c.addi4spn scales a 10-bit unsigned immediate by 4 (and must be non-zero)."""
    model = _sp_model()
    insn = 0x0804
    assert (insn >> 13) & 0b111 == 0b000
    rd, value, _ = model._exec_c0(
        insn, 0b000, 8 + ((insn >> 2) & 0b111), 8 + ((insn >> 7) & 0b111), 0x1000
    )
    assert rd == 9  # s1
    assert value == 0x8000_A010


# --- the capstone: model DUT vs the tracked Spike trace ---------------------------


def test_model_reproduces_spike_commit_for_commit(
    fixture_image: Image, golden_commits: list[Commit]
) -> None:
    model_commits = Rv64ImcModel(fixture_image).trace()
    assert len(model_commits) == len(golden_commits) == 116
    assert model_commits == golden_commits
    # the model reports its own instruction words too, for debugging a divergence
    assert model_commits[0].insn == 0x0000_A117


def test_fixture_trace_file_matches_the_log(
    fixtures_dir: Path, golden_commits: list[Commit]
) -> None:
    """The canonical trace file carries the same pc/rd/value stream as the raw log.

    (Instruction words are Spike-log-only metadata: ``insn`` is never written to a
    trace, so compare the four canonical fields.)
    """
    trace = parse_trace((fixtures_dir / "cor_model.trace").read_text(encoding="utf-8"))
    assert len(trace) == len(golden_commits) == 116
    assert [(c.cycle, c.pc, c.rd, c.value) for c in trace] == [
        (c.cycle, c.pc, c.rd, c.value) for c in golden_commits
    ]


def test_run_image_and_text_helpers(fixtures_dir: Path) -> None:
    image_path = fixtures_dir / "cor_model.hex"
    assert run_image(image_path) == Rv64ImcModel(load_hex_image(image_path)).trace()
    text = trace_text_for_image(image_path)
    assert text.startswith("# rv_difftest trace v1")
    assert len(parse_trace(text)) == 116


def test_elf_and_hex_images_agree(corpus_elfs: dict[str, Path], fixtures_dir: Path) -> None:
    """The hex fixture is generated from the ELF, so both must run identically."""
    elf = corpus_elfs["cor_model"]
    other = Rv64ImcModel(load_image(elf)).trace()
    assert other == Rv64ImcModel(load_hex_image(fixtures_dir / "cor_model.hex")).trace()


def test_tohost_store_ends_the_run(fixture_image: Image) -> None:
    model = Rv64ImcModel(fixture_image)
    commits = model.trace()
    assert model.halt_reason == "tohost"
    assert model.mem.read(fixture_image.tohost, 8) == 1  # a0 == 0 -> HTIF "pass"
    assert commits[-1].pc == 0x8000_001E  # `sd a0, 0(t0)`


def test_run_away_program_is_reported() -> None:
    """`jal x0, 0` loops forever: the model must give up instead of hanging."""
    spin = (0x0000_006F).to_bytes(4, "little")
    image = Image(name="spin", entry=0x8000_0000, tohost=0x8000_1000, segments=((0x8000_0000, spin),))
    model = Rv64ImcModel(image, max_commits=8)
    with pytest.raises(ModelError, match="did not write tohost within 8 commits"):
        model.trace()


def test_unsupported_instruction_is_explicit(tmp_path: Path) -> None:
    """Traps/CSRs are outside the model's subset and must say so, not guess."""
    image = tmp_path / "ecall.hex"
    image.write_text(
        "# rv_difftest hex image v1\n# entry 0x80000000\n# tohost 0x80001000\n@80000000 00000073\n",
        encoding="utf-8",
    )
    with pytest.raises(UnsupportedInstruction, match="SYSTEM instruction"):
        Rv64ImcModel(load_hex_image(image)).trace()


def test_hex_image_requires_entry_and_tohost(tmp_path: Path) -> None:
    image = tmp_path / "broken.hex"
    image.write_text("# entry 0x80000000\n@80000000 00000013\n", encoding="utf-8")
    with pytest.raises(ImageError, match="must declare `# entry` and `# tohost`"):
        load_hex_image(image)


def test_hex_image_rejects_bad_words(tmp_path: Path) -> None:
    image = tmp_path / "bad.hex"
    image.write_text(
        "# entry 0x80000000\n# tohost 0x80001000\n@80000000 zzzz\n", encoding="utf-8"
    )
    with pytest.raises(ImageError, match="bad word"):
        load_hex_image(image)


def test_missing_image_is_reported(tmp_path: Path) -> None:
    with pytest.raises(ImageError, match="image not found"):
        load_image(tmp_path / "nope.elf")


def test_sparse_memory_is_zero_filled_and_little_endian() -> None:
    model = Rv64ImcModel(Image(name="mem", entry=0, tohost=0x100, segments=((0x1000, b"\x01\x02"),)))
    assert model.mem.read(0x8000_0000, 8) == 0  # untouched memory reads as zero
    assert model.mem.read(0x1000, 2) == 0x0201  # loaded bytes are little-endian
    model.mem.write(0x1000, 4, 0xDEAD_BEEF)
    assert model.mem.read(0x1000, 4) == 0xDEAD_BEEF
    assert model.mem.read(0x1000, 1) == 0xEF  # low byte first
