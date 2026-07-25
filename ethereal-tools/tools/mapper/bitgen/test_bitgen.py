# SPDX-License-Identifier: MIT
"""pytest for bitgen_db + bitgen_sim (task E0-MAP3 increment 1).

Includes THE bit-true validation ``test_c17_bittrue``: the LEVEL-1 config DB
extracted from VPR's c17 pack/place + Yosys BLIF is evaluated by bitgen_sim and
compared against a golden table produced by iverilog-simulating the ORIGINAL
c17.v over all 32 input combinations. iverilog is required for that one test
(skip otherwise); all other tests are pure Python.
"""
from __future__ import annotations

import copy
import itertools
import os
import shutil
import subprocess

import pytest

from bitgen_db import (FB_BASE, N, ElutConfig, TileLogic,
                       blif_names_to_logical_tt, build_db, elut_cfg_word,
                       iib_sel_for, parse_blif, permute_tt)
from bitgen_sim import simulate_tile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MAPPER = os.path.join(REPO, "generated", "mapper")
BENCH = os.path.join(REPO, "ethereal-images", "benchmarks")

IVERILOG = shutil.which("iverilog") and shutil.which("vvp")


# =============================================================================
# Unit tests: cfg-word packing, iib sel, TT computation, permutation
# =============================================================================

def test_elut_cfg_word_uses_rtl_layout():
    # RTL elut4.sv: [19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv.
    # (See bitgen_db docstring ASSUMPTION re: brief vs RTL discrepancy.)
    ec = ElutConfig(tt=0xABCD, ff_en=True, ff_rst_en=True, ff_rst_val=False, out_inv=True)
    w = elut_cfg_word(ec)
    assert w & 0xFFFFF == w
    assert (w >> 4) & 0xFFFF == 0xABCD
    assert (w >> 3) & 1 == 1     # ff_en
    assert (w >> 2) & 1 == 1     # ff_rst_en
    assert (w >> 1) & 1 == 0     # ff_rst_val
    assert w & 1 == 1            # out_inv
    # zeroed control bits leave only the TT in [19:4]
    assert elut_cfg_word(ElutConfig(tt=0x000F)) == 0x000F << 4


def test_iib_sel_for():
    assert iib_sel_for(0, 0, ("clb.I", 0)) == 0
    assert iib_sel_for(0, 0, ("clb.I", 17)) == 17
    assert iib_sel_for(0, 0, ("fle", 0)) == FB_BASE + 0
    assert iib_sel_for(0, 0, ("fle", 7)) == FB_BASE + 7 == 25
    with pytest.raises(ValueError):
        iib_sel_for(0, 0, ("bogus", 1))   # type: ignore[arg-type]


def test_blif_names_to_logical_tt_2input_and():
    # .names a b out   cubes "11 1" -> AND. MSB-first: a=bit1,b=bit0 -> TT bit3=1.
    tt = blif_names_to_logical_tt(["a", "b"], [("11", 1)])
    assert tt == 0b1000  # only combo a=1,b=1 -> index 3


def test_blif_names_to_logical_tt_with_dontcare():
    # .names a b out  "1- 1" -> out=1 when a=1 (b anything) -> combos idx 2,3.
    tt = blif_names_to_logical_tt(["a", "b"], [("1-", 1)])
    assert tt == 0b1100


def _bit_reverse_4(tt: int) -> int:
    out = 0
    for p in range(16):
        if (tt >> p) & 1:
            r = ((p & 1) << 3) | ((p & 2) << 1) | ((p & 4) >> 1) | ((p & 8) >> 3)
            out |= 1 << r
    return out


def test_permute_tt_identity_and_known_swap():
    base = 0b1011000011100101
    # [3,2,1,0] reconciles logical-MSB-first (input[0]=bit3) with the hardware
    # pin0=LSB assembly, so it is the IDENTITY-preserving map.
    assert permute_tt(base, [3, 2, 1, 0]) == base
    # [0,1,2,3] leaves the index in bit-reversed order
    assert permute_tt(base, [0, 1, 2, 3]) == _bit_reverse_4(base)
    # every physical->logical permutation is a bijection over the 16 TT bits
    for m in itertools.permutations(range(4)):
        assert bin(permute_tt(base, list(m))).count("1") == bin(base).count("1")


# =============================================================================
# Structural DB tests
# =============================================================================

def _require_c17():
    for ext in ("net", "place", "blif"):
        if not os.path.exists(os.path.join(MAPPER, f"c17.{ext}")):
            pytest.skip(f"generated/mapper/c17.{ext} missing (run synth + VPR first)")


def _require_c432():
    for ext in ("net", "place", "blif"):
        if not os.path.exists(os.path.join(MAPPER, f"c432.{ext}")):
            pytest.skip(f"generated/mapper/c432.{ext} missing (run synth + VPR first)")


def test_c17_db_structure():
    _require_c17()
    db = build_db(os.path.join(MAPPER, "c17.net"),
                  os.path.join(MAPPER, "c17.place"),
                  os.path.join(MAPPER, "c17.blif"))
    assert db.primary_inputs == ["N1", "N2", "N3", "N6", "N7"]
    assert db.primary_outputs == ["N22", "N23"]
    assert len(db.tiles) == 1, f"expected 1 cluster tile, got {list(db.tiles)}"
    tile = next(iter(db.tiles.values()))
    assert set(tile.eluts.keys()) == {6, 7}              # fle[6]=N22, fle[7]=N23
    assert tile.cluster_outputs[6] == "N22"
    assert tile.cluster_outputs[7] == "N23"
    # clb.I mapping from .net: N3 N2 N1 N6 N7 open ...
    assert tile.cluster_inputs[0] == "N3"
    assert tile.cluster_inputs[1] == "N2"
    assert tile.cluster_inputs[2] == "N1"
    assert tile.cluster_inputs[3] == "N6"
    assert tile.cluster_inputs[4] == "N7"
    assert tile.cluster_inputs[5] is None
    # every eLUT4 has a non-trivial TT (c17 is not constant)
    for gi, ec in tile.eluts.items():
        assert ec.tt not in (0x0000, 0xFFFF)
        assert ec.ff_en is False                                      # c17 is combinational


def test_c432_db_structure():
    _require_c432()
    db = build_db(os.path.join(MAPPER, "c432.net"),
                  os.path.join(MAPPER, "c432.place"),
                  os.path.join(MAPPER, "c432.blif"))
    assert len(db.tiles) == 9, f"expected 9 cluster tiles, got {len(db.tiles)}"
    total_eluts = sum(len(t.eluts) for t in db.tiles.values())
    assert total_eluts == 62, f"expected 62 eLUT4, got {total_eluts}"
    # every eLUT4 carries a non-trivial TT and every IIB mux resolves to a valid sel
    for tile in db.tiles.values():
        for gi, ec in tile.eluts.items():
            assert 0 <= ec.tt <= 0xFFFF
            assert ec.tt not in (0x0000, 0xFFFF), f"tile eLUT {gi} has trivial TT"
        for (gi, gk), sel in tile.iib_mux.items():
            assert 0 <= sel <= FB_BASE + N - 1, f"({gi},{gk}) sel {sel} out of range"
            assert (gi, gk) in tile.iib_mux


# =============================================================================
# THE bit-true validation: c17 vs iverilog golden
# =============================================================================

_GOLDEN_TB = """\
`timescale 1ns/1ps
module golden_c17_tb;
    reg N1, N2, N3, N6, N7;
    wire N22, N23;
    integer i;
    c17 dut(.N1(N1), .N2(N2), .N3(N3), .N6(N6), .N7(N7), .N22(N22), .N23(N23));
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            {N1, N2, N3, N6, N7} = i[4:0];
            #1;
            $display("%0d %0d %0d %0d %0d %0d %0d", N1, N2, N3, N6, N7, N22, N23);
        end
        $finish;
    end
endmodule
"""


def _golden_c17() -> dict[tuple[int, int, int, int, int], tuple[int, int]]:
    tb_path = os.path.join(MAPPER, "golden_c17_tb.v")
    with open(tb_path, "w", encoding="utf-8") as fh:
        fh.write(_GOLDEN_TB)
    sim = os.path.join("/tmp", "golden_c17")
    res = subprocess.run(
        ["iverilog", "-g2012", "-o", sim,
         os.path.join(BENCH, "c17.v"), tb_path],
        capture_output=True, text=True,
    )
    assert res.returncode == 0, f"iverilog failed:\n{res.stderr}"
    res = subprocess.run(["vvp", sim], capture_output=True, text=True)
    assert res.returncode == 0, f"vvp failed:\n{res.stderr}"
    golden: dict[tuple[int, int, int, int, int], tuple[int, int]] = {}
    for line in res.stdout.splitlines():
        parts = line.split()
        if len(parts) == 7:
            n1, n2, n3, n6, n7, o22, o23 = (int(x) for x in parts)
            golden[(n1, n2, n3, n6, n7)] = (o22, o23)
    assert len(golden) == 32, f"expected 32 golden rows, got {len(golden)}"
    return golden


def _eval_tile(tile: TileLogic,
               inputs: tuple[int, int, int, int, int]) -> tuple[int, int]:
    n1, n2, n3, n6, n7 = inputs
    bits = {"N1": n1, "N2": n2, "N3": n3, "N6": n6, "N7": n7}
    res = simulate_tile(tile, bits)
    return res["N22"], res["N23"]


@pytest.mark.skipif(not IVERILOG, reason="iverilog/vvp not on PATH")
def test_c17_bittrue():
    _require_c17()
    golden = _golden_c17()
    db = build_db(os.path.join(MAPPER, "c17.net"),
                  os.path.join(MAPPER, "c17.place"),
                  os.path.join(MAPPER, "c17.blif"))
    tile = next(iter(db.tiles.values()))

    mismatches = [(k, _eval_tile(tile, k), golden[k]) for k in golden
                  if _eval_tile(tile, k) != golden[k]]
    if not mismatches:
        # Crossbar-derived permutation succeeded with zero brute-forcing.
        return

    # Fallback: brute-force all 4! = 24 permutations per LUT independently.
    # fle[6] drives N22, fle[7] drives N23 (no intra-cluster feedback in c17).
    names, _, _ = parse_blif(os.path.join(MAPPER, "c17.blif"))

    def _solve_perm(fle_idx: int, out_net: str, out_pos: int) -> list[int] | None:
        input_list, cubes = names[out_net]
        logical_tt = blif_names_to_logical_tt(input_list, cubes)
        for perm in itertools.permutations(range(4)):
            cand = copy.deepcopy(tile)
            cand.eluts[fle_idx] = ElutConfig(tt=permute_tt(logical_tt, list(perm)))
            ok = True
            for k in golden:
                bits = {"N1": k[0], "N2": k[1], "N3": k[2], "N6": k[3], "N7": k[4]}
                if simulate_tile(cand, bits)[out_net] != golden[k][out_pos]:
                    ok = False
                    break
            if ok:
                return list(perm)
        return None

    p6 = _solve_perm(6, "N22", 0)
    p7 = _solve_perm(7, "N23", 1)
    assert p6 is not None, "no 4-LUT permutation makes N22 bit-true (parser bug?)"
    assert p7 is not None, "no 4-LUT permutation makes N23 bit-true (parser bug?)"

    final = copy.deepcopy(tile)
    for fle_idx, out_net in ((6, "N22"), (7, "N23")):
        input_list, cubes = names[out_net]
        logical_tt = blif_names_to_logical_tt(input_list, cubes)
        perm = p6 if fle_idx == 6 else p7
        final.eluts[fle_idx] = ElutConfig(tt=permute_tt(logical_tt, perm))

    for k in golden:
        got = _eval_tile(final, k)
        assert got == golden[k], (
            f"bit-true fail at {k}: got {got}, want {golden[k]} "
            f"(perms fle6={p6} fle7={p7})")

    pytest.fail(
        f"crossbar-derived perm failed ({len(mismatches)}/32 mismatch); "
        f"brute-forced perms fle6={p6} fle7={p7} succeeded — investigate "
        f"phys_to_log derivation (see bitgen_db docstring)")
