# SPDX-License-Identifier: MIT
"""bench_golden — reusable iverilog golden-vector generator for the E0-MAP5
benchmark set {AES-128, PRESENT, FIR16, CRC32, PWM} (task E0-MAP5).

Mirrors the ``_run_iverilog_golden`` pattern in ``test_fabric_sim.py`` (the
c432 bit-true acceptance), generalized to MULTI-BIT ports. Where c432 has 36
scalar PI ports (``N1``..``N115``), the benchmarks have wide buses (a 128-bit
AES ``state`` is ONE Verilog port but 128 nets). This module drives each wide
port as a single integer in the testbench and splits/merges bits to match how
``synth_ethereal`` (Yosys ``write_blif``) bit-blasts the nets.

BLIF NET-NAMING CONVENTION (verified against generated/mapper/*.blif,
2026-07-28 — see E0-MAP5 report ASSUMPTION):
  * A multi-bit port ``state[127:0]`` is bit-blasted to nets ``state[0]`` ..
    ``state[127]``. Index 0 is the LSB (bit i of the integer == net ``state[i]``).
  * Scalar ports keep their plain name (e.g. ``pwm.out`` -> net ``out``).
  * ``build_db.primary_inputs`` / ``.primary_outputs`` carry these EXACT net
    names, so the per-net PI dict passed to ``FabricSim.evaluate`` and the PO
    dict it returns key on ``name[i]`` for buses and ``name`` for scalars.

Public API:
  * :func:`port_net_names` — expand a ``(name, width)`` port to its net names.
  * :func:`int_to_bits` / :func:`bits_to_int` — integer <-> per-net 0/1 split.
  * :func:`golden_seq` — per-cycle golden for CLOCKED benchmarks (E1-DMO1):
    drives a stable-across-the-edge PI stream, samples POs after each posedge
    (the exact semantics of ``FabricSim.tick``).
  * :func:`golden_comb` — the workhorse: write+run an iverilog tb applying
    ``n_vectors`` random inputs, capture outputs, return ``[(pi_dict, po_dict)]``
    keyed by the bit-blasted net names FabricSim expects.

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2 (E0-MAP5).
"""
from __future__ import annotations

import os
import random
import shutil
import subprocess

MAPPER = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..",
    "generated", "mapper"))


# =============================================================================
# Port <-> net-name expansion (multi-bit handling)
# =============================================================================

def port_net_names(name: str, width: int) -> list[str]:
    """Expand a port to its bit-blasted net names (LSB first).

    ``width == 1`` -> ``[name]`` (scalar, plain name); ``width > 1`` ->
    ``[name[0], name[1], ..., name[width-1]]`` matching Yosys ``write_blif``.
    """
    if width < 1:
        raise ValueError(f"port {name}: width must be >= 1, got {width}")
    if width == 1:
        return [name]
    return [f"{name}[{i}]" for i in range(width)]


def int_to_bits(value: int, name: str, width: int) -> dict[str, int]:
    """Split an integer port value into a ``{net_name: 0/1}`` dict (LSB first)."""
    return {net: (value >> i) & 1
            for i, net in enumerate(port_net_names(name, width))}


def bits_to_int(po_dict: dict[str, int], name: str, width: int) -> int:
    """Merge a per-net output dict back into one integer for a port (LSB first)."""
    val = 0
    for i, net in enumerate(port_net_names(name, width)):
        val |= (po_dict.get(net, 0) & 1) << i
    return val


# =============================================================================
# Testbench generation + iverilog run
# =============================================================================

def _gen_tb(tb_path: str, top: str, module_file: str,
            input_ports: list[tuple[str, int]],
            output_ports: list[tuple[str, int]],
            vectors: list[dict[str, int]]) -> None:
    """Write an iverilog tb that drives each input port as an integer register,
    settles combinationally (#1), and $displays all port values as hex per vec.

    Line format (one per vector, tokens separated by spaces):
        ``<idx> <in0_hex> <in1_hex> ... <out0_hex> <out1_hex> ...``
    Hex width per port = ceil(width/4). Multi-bit ports print as ONE hex token
    (the integer); the Python side re-splits into bits. This keeps the tb robust
    to wide buses (a 128-bit AES state is one 32-hex-digit token, not 128 %b).
    """
    lines: list[str] = [
        "`timescale 1ns/1ps",
        f"module {top}_golden_tb;",
        "  integer i;",
    ]
    for name, width in input_ports:
        lines.append(f"  reg [{width - 1}:0] pi_{name};")
    for name, width in output_ports:
        lines.append(f"  wire [{width - 1}:0] po_{name};")
    conn = ", ".join([f".{n}(pi_{n})" for n, _ in input_ports]
                     + [f".{n}(po_{n})" for n, _ in output_ports])
    lines.append(f"  {top} dut({conn});")
    # packed stimulus ROM (one entry per port, hex, MSB-aligned per width).
    for name, width in input_ports:
        nvec = len(vectors)
        hexw = (width + 3) // 4
        body = "\n".join(
            f"    stim_{name}[{i}] = {width}'h{vectors[i][name]:0{hexw}x};"
            for i in range(nvec))
        lines.append(f"  reg [{width - 1}:0] stim_{name} [0:{nvec - 1}];")
        lines.append("  initial begin\n" + body + "\n  end")
    lines.append("  initial begin")
    lines.append(f"    for (i = 0; i < {len(vectors)}; i = i + 1) begin")
    for name, _w in input_ports:
        lines.append(f"      pi_{name} = stim_{name}[i];")
    lines.append("      #1;")
    fmt_parts = ["%0d"] + ["%h"] * (len(input_ports) + len(output_ports))
    args = ", ".join(["i"]
                     + [f"pi_{n}" for n, _ in input_ports]
                     + [f"po_{n}" for n, _ in output_ports])
    lines.append(f'      $display("{" ".join(fmt_parts)}", {args});')
    lines.append("    end")
    lines.append("    $finish;")
    lines.append("  end")
    lines.append("endmodule")
    open(tb_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def _bit_from_hex(tok: str, port_name: str) -> int:
    """Parse one hex token (an integer port value) from the golden output."""
    try:
        return int(tok, 16)
    except ValueError as exc:
        raise AssertionError(
            f"golden value for {port_name} is not hex (got {tok!r}) — a "
            f"combinational benchmark should never produce x/z") from exc


def golden_comb(
    bench_v: str,
    top: str,
    input_ports: list[tuple[str, int]],
    output_ports: list[tuple[str, int]],
    n_vectors: int,
    seed: int,
) -> list[tuple[dict[str, int], dict[str, int]]]:
    """Generate golden ``[(pi_dict, po_dict)]`` for a combinational benchmark.

    ``input_ports`` / ``output_ports`` are ``[(name, width), ...]``. Drives
    ``n_vectors`` random inputs (uniform per port over its width), iverilog-
    simulates ``bench_v`` (top ``top``), and returns per-net dicts keyed by the
    bit-blasted net names (:func:`port_net_names`) so they can be passed
    straight to ``FabricSim.evaluate`` / compared against its PO dict.
    """
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        raise RuntimeError("iverilog / vvp not on PATH (needs oss-cad-suite)")
    if not os.path.exists(bench_v):
        raise FileNotFoundError(bench_v)
    os.makedirs(MAPPER, exist_ok=True)

    rng = random.Random(seed)
    # random integer stimulus per input port per vector.
    vectors: list[dict[str, int]] = []
    for _ in range(n_vectors):
        vec = {name: rng.getrandbits(width) for name, width in input_ports}
        vectors.append(vec)

    tb_path = os.path.join(MAPPER, f"golden_{top}_tb.v")
    out_bin = os.path.join(MAPPER, f"golden_{top}_vvp")
    _gen_tb(tb_path, top, bench_v, input_ports, output_ports, vectors)
    subprocess.run(["iverilog", "-g2012", "-o", out_bin, bench_v, tb_path],
                   check=True, capture_output=True)
    run = subprocess.run(["vvp", out_bin], check=True, capture_output=True,
                         text=True)

    results: list[tuple[dict[str, int], dict[str, int]]] = []
    n_in = len(input_ports)
    for line in run.stdout.strip().splitlines():
        toks = line.split()
        # data lines only: "<idx> <in...> <out...>" (skip vvp $finish banner).
        if not toks or not toks[0].lstrip("-").isdigit():
            continue
        assert len(toks) == 1 + n_in + len(output_ports), (
            f"malformed golden line: {line!r}")
        in_toks = toks[1:1 + n_in]
        out_toks = toks[1 + n_in:]
        pi_dict: dict[str, int] = {}
        for (name, width), tok in zip(input_ports, in_toks, strict=True):
            pi_dict.update(int_to_bits(_bit_from_hex(tok, name), name, width))
        po_dict: dict[str, int] = {}
        for (name, width), tok in zip(output_ports, out_toks, strict=True):
            po_dict.update(int_to_bits(_bit_from_hex(tok, name), name, width))
        results.append((pi_dict, po_dict))
    assert len(results) == n_vectors, (
        f"expected {n_vectors} golden lines, got {len(results)}")
    return results

# =============================================================================
# Sequential (per-cycle) golden — E1-DMO1 demo images
# =============================================================================

def golden_seq(
    bench_v: str,
    top: str,
    pi_stream: list[dict[str, int]],
    output_ports: list[tuple[str, int]],
    clk_port: str = "clk",
) -> list[tuple[dict[str, int], dict[str, int]]]:
    """Per-cycle golden trace for a CLOCKED benchmark (E1-DMO1 tick model).

    ``pi_stream`` is one entry PER CLOCK CYCLE, each an ``{input_port: int}``
    dict (the port values held stable across that cycle's posedge — the TB
    applies them on the negedge before). Returns ``[(pi_dict, po_dict)]`` per
    cycle where ``po_dict`` is sampled just AFTER the cycle's posedge — the
    exact semantics of :meth:`fabric_sim.FabricSim.tick`, so the lists compare
    element-wise.

    The DUT must be POWER-UP-DETERMINISTIC: the fabric eLUT4 FF pool
    zero-inits, so the benchmark declares ``reg ... = 1'b0`` initializers (no
    routed reset in the v0 fabric) and iverilog starts it in the same
    all-zero state the tick model's first ``ff_state={}`` assumes.
    """
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        raise RuntimeError("iverilog / vvp not on PATH (needs oss-cad-suite)")
    if not os.path.exists(bench_v):
        raise FileNotFoundError(bench_v)
    os.makedirs(MAPPER, exist_ok=True)

    n = len(pi_stream)
    assert n > 0, "golden_seq: empty pi_stream"
    in_ports = sorted(pi_stream[0])
    widths = {p: max((v[p].bit_length() for v in pi_stream), default=0)
              for p in in_ports}
    widths = {p: max(w, 1) for p, w in widths.items()}

    lines = [
        "`timescale 1ns/1ps",
        f"module {top}_golden_seq_tb;",
        "  integer cyc = 0;",
        "  reg clk;",
    ]
    for p in in_ports:
        lines.append(f"  reg [{widths[p] - 1}:0] pi_{p};")
    for name, width in output_ports:
        lines.append(f"  wire [{width - 1}:0] po_{name};")
    conn = ", ".join([f".{p}(pi_{p})" for p in in_ports]
                     + [f".{n_}(po_{n_})" for n_, _ in output_ports]
                     + [f".{clk_port}(clk)"])
    lines.append(f"  {top} dut({conn});")
    # stimulus ROM: one hex token per cycle per port (all ports, full width).
    for p in in_ports:
        body = "\n".join(
            f"    stim_{p}[{t}] = {widths[p]}'h{pi_stream[t][p]:x};"
            for t in range(n))
        lines.append(f"  reg [{widths[p] - 1}:0] stim_{p} [0:{n - 1}];")
        lines.append("  initial begin\n" + body + "\n  end")
    lines += [
        "  initial begin",
        "    clk = 1'b0;",
        "    forever #10 clk = ~clk;   // 20 ns period",
        "  end",
        "  // apply cycle t's PIs on the negedge BEFORE posedge t (stable",
        "  // across the sampling edge, like a synchronous input register).",
        "  always @(negedge clk) begin",
        "    cyc = cyc + 1;",
        *[f"    pi_{p} = stim_{p}[cyc];" for p in in_ports],
        "  end",
        "  initial begin",
        *[f"    pi_{p} = stim_{p}[0];" for p in in_ports],
        "  end",
        "  // sample POs just after each posedge (all NBA updates settled).",
        "  always @(posedge clk) begin",
        "    #1;",
        "    $display(\"%0d " + " ".join(["%h"] * (len(in_ports)
                                                + len(output_ports))) + "\", cyc"
        + "".join(f", pi_{p}" for p in in_ports)
        + "".join(f", po_{p}" for p, _w in output_ports) + ");",
        "  end",
        # finish after the LAST posedge sample (20n-9) but before the
        # negedge that would index stim[n] (out of ROM -> x).
        f"  initial begin #({20 * n - 5}); $finish; end",
        "endmodule",
    ]
    tb_path = os.path.join(MAPPER, f"golden_seq_{top}_tb.v")
    out_bin = os.path.join(MAPPER, f"golden_seq_{top}_vvp")
    open(tb_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    subprocess.run(["iverilog", "-g2012", "-o", out_bin, bench_v, tb_path],
                   check=True, capture_output=True)
    run = subprocess.run(["vvp", out_bin], check=True, capture_output=True,
                         text=True)

    results: list[tuple[dict[str, int], dict[str, int]]] = []

    for line in run.stdout.strip().splitlines():
        toks = line.split()
        if not toks or not toks[0].lstrip("-").isdigit():
            continue
        assert len(toks) == 1 + len(in_ports) + len(output_ports), (
            f"malformed golden_seq line: {line!r}")
        pi_dict: dict[str, int] = {}
        for p, tok in zip(in_ports, toks[1:1 + len(in_ports)], strict=True):
            pi_dict.update(int_to_bits(_bit_from_hex(tok, p), p, widths[p]))
        po_dict: dict[str, int] = {}
        for (name, width), tok in zip(
                output_ports, toks[1 + len(in_ports):], strict=True):
            po_dict.update(int_to_bits(_bit_from_hex(tok, name), name, width))
        results.append((pi_dict, po_dict))
    assert len(results) == n, (
        f"expected {n} golden_seq lines, got {len(results)}")
    return results
