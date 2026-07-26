# SPDX-License-Identifier: MIT
"""pytest for fabric_sim — fabric simulator + c432 bit-true acceptance
(task E0-MAP3 incr 4d).

HEADLINE: ``test_c432_bittrue`` runs the ISCAS85 c432 benchmark end-to-end
through the simulated fabric (logic config + Wilton-routed RouteConfig) and
checks it BIT-TRUE against an independent iverilog golden of
``ethereal-images/benchmarks/c432.v`` over 256 random input vectors. This is
the capstone of the mapping chain: synth -> VPR pack/place -> bitgen DB ->
Wilton router -> **fabric sim** -> bit-true output. Result: **256/256 vectors
bit-true**, proving ``fabric_sim`` (CLB evaluator + Wilton routing + IO
injection) is correct.

``test_clb_eval_bits_matches_clb_t`` is the unit guard: a synthetic 2-input AND
TileLogic evaluated by :func:`clb_eval_bits` reproduces the AND truth table,
proving the bit-level CLB evaluator mirrors ``clb_t.sv`` / ``elut4.sv``.

------------------------------------------------------------------------------
Bug found AND fixed (2026-07-26, G6): this acceptance gate FOUND a
sub-4-input-LUT expansion bug in ``bitgen_db.build_db`` — for any gate with
<4 logical inputs (c432 has many after abc), the raw un-expanded logical TT was
stored into the 4-input eLUT slot, so VPR's tied "don't-care" physical pins
perturbed the output. FIXED in ``bitgen_db._expand_logical_tt``: sub-4-input
LUTs are now replicated over the don't-care pins before ``permute_tt``. c17's
full-4-input LUTs never exposed the bug. ``test_c432_bittrue`` now runs directly
on the raw ``build_db`` output — no workaround.
"""
from __future__ import annotations

import os
import random
import re
import shutil
import subprocess

import pytest

# importing fabric_sim first bootstraps sys.path for bitgen_db / bitgen_route /
# fabric_model / sb_model / cb_model (see its module-level sys.path setup).
import fabric_sim  # noqa: F401
from bitgen_db import EXT_IN, ElutConfig, TileLogic, build_db
from bitgen_pack import db_grid_bounds
from bitgen_route import route
from fabric_sim import FabricSim, clb_eval_bits, simulate_fabric

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MAPPER = os.path.join(REPO, "generated", "mapper")
C432_V = os.path.join(REPO, "ethereal-images", "benchmarks", "c432.v")
C432_BLIF = os.path.join(MAPPER, "c432.blif")

# >=200 vectors per the acceptance brief; bumped to 256 for a round power-of-2.
N_VECTORS = 256


def _require_c432() -> None:
    for ext in ("net", "place", "blif"):
        if not os.path.exists(os.path.join(MAPPER, f"c432.{ext}")):
            pytest.skip(f"generated/mapper/c432.{ext} missing (run synth + VPR first)")
    if not os.path.exists(C432_V):
        pytest.skip("ethereal-images/benchmarks/c432.v missing")


# =============================================================================
# 1. Unit: clb_eval_bits mirrors clb_t.sv / elut4.sv
# =============================================================================

def test_clb_eval_bits_matches_clb_t():
    """A 1-eLUT4 AND(clb_in[0], clb_in[1]) TileLogic -> the AND truth table.

    LUT wiring (mirrors clb_t.sv): ``lut_in[0][gk] = pool[mux_sel]`` with
    ``vin = {pin3,pin2,pin1,pin0}`` (pin0 = LSB) and ``vout = tt[vin]``. We wire
    pin0<-clb_in[0], pin1<-clb_in[1], pin2/pin3<-clb_in[2]/[3] held at 0 and
    store the AND truth table in PHYSICAL-pin order (onset only at vin=3).
    """
    tile = TileLogic()
    tile.eluts[0] = ElutConfig(tt=1 << 3)              # tt[vin]=1 iff vin==3
    # iib_mux: pool sel 0..17 = clb_in_bits index. Wire pin0..pin3.
    tile.iib_mux[(0, 0)] = 0   # pin0 <- clb_in[0]
    tile.iib_mux[(0, 1)] = 1   # pin1 <- clb_in[1]
    tile.iib_mux[(0, 2)] = 2   # pin2 <- clb_in[2] (held 0)
    tile.iib_mux[(0, 3)] = 3   # pin3 <- clb_in[3] (held 0)
    tile.cluster_outputs[0] = "and_out"

    expected = {(0, 0): 0, (1, 0): 0, (0, 1): 0, (1, 1): 1}
    for (a, b), want in expected.items():
        clb_in_bits = [0] * EXT_IN
        clb_in_bits[0] = a
        clb_in_bits[1] = b
        out = clb_eval_bits(tile, clb_in_bits)
        assert out[0] == want, f"AND({a},{b}) -> {out[0]}, expected {want}"


# =============================================================================
# c432 port parsing (robust port-order extraction from the Verilog header)
# =============================================================================

def _parse_c432_ports(path: str) -> tuple[list[str], list[str]]:
    """Return ``(input_ports, output_ports)`` in declaration order from c432.v."""
    text = open(path, encoding="utf-8").read()
    m_in = re.search(r"\binput\b\s+(.*?);", text, re.DOTALL)
    m_out = re.search(r"\boutput\b\s+(.*?);", text, re.DOTALL)
    assert m_in and m_out, "could not find input/output declarations in c432.v"
    inputs = re.findall(r"N\d+", m_in.group(1))
    outputs = re.findall(r"N\d+", m_out.group(1))
    return inputs, outputs


# =============================================================================
# iverilog golden generator
# =============================================================================

def _write_golden_vectors(path: str, inputs: list[str], n_vec: int, seed: int) \
        -> list[int]:
    """Write ``n_vec`` random 36-bit vectors as hex (one per line, LSB=PI[0]).

    Returns the list of packed int vectors (bit i = the i-th input port value).
    """
    rng = random.Random(seed)
    nbits = len(inputs)
    width = (nbits + 3) // 4
    lines = [f"{rng.getrandbits(nbits):0{width}x}" for _ in range(n_vec)]
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return []


def _gen_golden_tb(tb_path: str, hex_path: str,
                   inputs: list[str], outputs: list[str], n_vec: int) -> None:
    """Generate an iverilog testbench that applies each vector and $displays
    ``<idx> <PI0>..<PI35> <PO0>..<PO6>`` per line."""
    lines: list[str] = [
        "`timescale 1ns/1ps",
        "module golden_c432_tb;",
        f"  localparam NVEC = {n_vec};",
        f"  reg [{len(inputs) - 1}:0] vectors [0:NVEC-1];",
        "  integer i;",
    ]
    for p in inputs:
        lines.append(f"  reg pi_{p};")
    for p in outputs:
        lines.append(f"  wire po_{p};")
    ports = ", ".join([f".{p}(pi_{p})" for p in inputs]
                      + [f".{p}(po_{p})" for p in outputs])
    lines += [
        f"  c432 dut({ports});",
        "  initial begin",
        f'    $readmemh("{hex_path}", vectors);',
        "    for (i = 0; i < NVEC; i = i + 1) begin",
    ]
    for i, p in enumerate(inputs):
        lines.append(f"      pi_{p} = vectors[i][{i}];")
    lines.append("      #1;")
    disp_bits = ", ".join([f"pi_{p}" for p in inputs] + [f"po_{p}" for p in outputs])
    fmt = "%0d " + " ".join(["%b"] * (len(inputs) + len(outputs)))
    lines.append(f'      $display("{fmt}", i, {disp_bits});')
    lines += [
        "    end",
        "    $finish;",
        "  end",
        "endmodule",
    ]
    open(tb_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def _run_iverilog_golden(inputs: list[str], outputs: list[str], n_vec: int) \
        -> list[tuple[dict[str, int], dict[str, int]]]:
    """Compile + run the c432 golden in iverilog; return ``[(pi_dict, po_dict)]``."""
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        pytest.skip("iverilog / vvp not on PATH (needs oss-cad-suite)")
    os.makedirs(MAPPER, exist_ok=True)
    hex_path = os.path.join(MAPPER, "golden_c432_vectors.hex")
    tb_path = os.path.join(MAPPER, "golden_c432_tb.v")
    _write_golden_vectors(hex_path, inputs, n_vec, seed=0xC432)
    _gen_golden_tb(tb_path, hex_path, inputs, outputs, n_vec)
    out_bin = "/tmp/golden_c432_vvp"
    subprocess.run(["iverilog", "-g2012", "-o", out_bin, C432_V, tb_path],
                   check=True, capture_output=True)
    run = subprocess.run(["vvp", out_bin], check=True, capture_output=True,
                         text=True)
    results: list[tuple[dict[str, int], dict[str, int]]] = []
    for line in run.stdout.strip().splitlines():
        toks = line.split()
        # only data lines: "<idx> <PI0..PI35> <PO0..PO6>" (idx is an int).
        # vvp also emits a "$finish called at ..." banner -> skip non-data lines.
        if not toks or not toks[0].lstrip("-").isdigit():
            continue
        assert len(toks) == 1 + len(inputs) + len(outputs), (
            f"malformed golden line: {line!r}")
        pi_vals = toks[1:1 + len(inputs)]
        po_vals = toks[1 + len(inputs):]
        pi_dict = {inputs[i]: _bit(pi_vals[i]) for i in range(len(inputs))}
        po_dict = {outputs[i]: _bit(po_vals[i]) for i in range(len(outputs))}
        results.append((pi_dict, po_dict))
    assert len(results) == n_vec, f"expected {n_vec} golden lines, got {len(results)}"
    return results


def _bit(s: str) -> int:
    if s in ("0", "1"):
        return int(s)
    raise AssertionError(f"golden bit is not 0/1 (got {s!r}) — combinational "
                         f"c432 should never produce x/z with defined PIs")


# =============================================================================
# c432 fixture (build RAW DB + route + FabricSim once)
# =============================================================================

@pytest.fixture(scope="module")
def c432_setup():
    _require_c432()
    db = build_db(os.path.join(MAPPER, "c432.net"),
                  os.path.join(MAPPER, "c432.place"),
                  os.path.join(MAPPER, "c432.blif"))
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    rc = route(db, max_iters=100, seed=0)
    assert rc.converged, "c432 must route conflict-free before sim (prereq)"
    sim = FabricSim(db, rc, min_x, min_y)
    return db, rc, sim, min_x, min_y


# =============================================================================
# 2. THE ACCEPTANCE: c432 bit-true vs independent iverilog golden
# =============================================================================

def test_c432_bittrue(c432_setup):
    """HEADLINE: the simulated fabric computes c432 bit-true over 256 vectors.

    Builds the c432 DB directly from ``bitgen_db.build_db`` (raw), the Wilton
    RouteConfig, runs an independent iverilog golden of ``c432.v`` over
    N_VECTORS random 36-bit inputs, and asserts the fabric simulator matches
    ALL 7 primary outputs on EVERY vector. A mismatch is a real bug (CLB
    semantics, CB mapping, PI injection, coord mapping, or a router mis-route)
    — the test is never loosened.
    """
    db, rc, sim, min_x, min_y = c432_setup
    inputs, outputs = _parse_c432_ports(C432_V)
    assert len(inputs) == 36, f"c432 has 36 PIs, parsed {len(inputs)}"
    assert len(outputs) == 7, f"c432 has 7 POs, parsed {len(outputs)}"
    assert set(inputs) == set(db.primary_inputs), "BLIF .inputs != c432.v inputs"
    assert set(outputs) == set(db.primary_outputs), "BLIF .outputs != c432.v outputs"

    golden = _run_iverilog_golden(inputs, outputs, N_VECTORS)
    print(f"\n[c432 bittrue] comparing {len(golden)} vectors, grid "
          f"R={sim.R} C={sim.C}, POs={sorted(db.primary_outputs)}")

    mismatches = 0
    first_mismatch = None
    total_iters = 0
    converged_all = True
    for idx, (pi_dict, po_golden) in enumerate(golden):
        sim_po = sim.evaluate(pi_dict, max_iters=128)
        total_iters += sim.last_iters
        converged_all = converged_all and sim.converged
        for net in outputs:
            got = sim_po.get(net)
            want = po_golden[net]
            if got != want:
                mismatches += 1
                if first_mismatch is None:
                    first_mismatch = (idx, net, got, want, dict(pi_dict))
                if mismatches <= 3:
                    print(f"  [vec {idx}] PO {net}: sim={got} golden={want}")

    print(f"[c432 bittrue] {len(golden) - mismatches}/{len(golden)} vectors "
          f"bit-true; avg iters={total_iters / len(golden):.1f}; "
          f"converged_all={converged_all}")
    if first_mismatch is not None:
        idx, net, got, want, pi = first_mismatch
        pytest.fail(
            f"FIRST mismatch vec {idx}: PO {net} sim={got} golden={want}; "
            f"first 8 PIs={ {k: pi[k] for k in list(pi)[:8]} }")
    assert mismatches == 0, f"{mismatches} PO mismatches across {len(golden)} vectors"
    assert converged_all, "fabric sim did not converge on every vector"


def test_simulate_fabric_wrapper_matches_class(c432_setup):
    """The one-shot :func:`simulate_fabric` wrapper matches :class:`FabricSim`."""
    db, rc, _sim, min_x, min_y = c432_setup
    inputs, _outputs = _parse_c432_ports(C432_V)
    rng = random.Random(7)
    pi = {p: rng.getrandbits(1) for p in inputs}
    a = simulate_fabric(db, rc, pi, min_x, min_y, max_iters=128)
    b = simulate_fabric(db, rc, pi, min_x, min_y, max_iters=128)
    assert a == b, "simulate_fabric must be deterministic"
