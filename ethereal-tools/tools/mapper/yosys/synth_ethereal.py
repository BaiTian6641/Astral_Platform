# SPDX-License-Identifier: MIT
"""synth_ethereal — Yosys front-end that maps a design to the eLUT4 netlist (E0-MAP1).

Flow (see synth_ethereal.ys for the documented, editable form):
    read_verilog <design> -> synth (generic, -auto-top or -top) -> abc -lut 4
    -> opt -> clean -> stat -> write_json + write_blif

The resulting `$lut` cells (WIDTH=4) ARE the eLUT4 instances: each carries a
4-input truth table that maps directly onto one virtual eLUT4 (tt field). FFs
remain as `$dff` (mapped to the eLUT4's integrated FF by bitgen, E0-MAP3). A
custom-named eLUT4 cell (cells_ethereal.v techmap) is deferred — the generic
`$lut` is the fabric primitive at this stage.

Run:  python synth_ethereal.py <design.v> [-o out_prefix] [-t top] [--yosys PATH]
      (or: make test-model runs test_synth_ethereal.py with the local Yosys)
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys

YOSYS_ENV = "YOSYS"


def _yosys() -> str:
    y = os.environ.get(YOSYS_ENV)
    if y and os.path.exists(y):
        return y
    found = shutil.which("yosys")
    if found:
        return found
    raise RuntimeError("yosys not found on PATH (set YOSYS or add OSS-CAD's bin)")


def synth_ethereal(design: str, out_prefix: str, top: str | None = None) -> dict:
    """Synthesize `design` to a 4-LUT (eLUT4) netlist. Returns a result dict."""
    if not os.path.exists(design):
        raise FileNotFoundError(design)
    out_dir = os.path.dirname(out_prefix) or "."
    os.makedirs(out_dir, exist_ok=True)
    top_opt = f"-top {top}" if top else "-auto-top"
    script = (
        f"read_verilog {design}\n"
        f"synth {top_opt}\n"
        "abc -lut 4\n"
        "opt -full\n"
        "clean\n"
        "stat\n"
        f"write_json {out_prefix}.json\n"
        f"write_blif {out_prefix}.blif\n"
    )
    y = _yosys()
    res = subprocess.run([y, "-p", script], capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"yosys failed (rc={res.returncode}):\n{res.stderr}\n{res.stdout}")
    log = res.stdout + res.stderr
    # stat prints a cell histogram with "$lut" rows like "<count>   $lut".
    matches = re.findall(r"(\d+)\s+\$lut\b", log)
    lut_count = int(matches[-1]) if matches else 0
    # capture $dff count too (registers -> eLUT4 FFs)
    dff_matches = re.findall(r"(\d+)\s+\$dff\b", log)
    dff_count = int(dff_matches[-1]) if dff_matches else 0
    return {
        "design": design,
        "lut4_count": lut_count,
        "dff_count": dff_count,
        "json": f"{out_prefix}.json",
        "blif": f"{out_prefix}.blif",
        "log": log,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Ethereal Yosys front-end -> eLUT4 netlist (E0-MAP1)")
    ap.add_argument("design", help="input Verilog file")
    ap.add_argument("-o", "--out", default="generated/mapper/out", help="output prefix")
    ap.add_argument("-t", "--top", default=None, help="top module (default: auto)")
    args = ap.parse_args(argv)
    r = synth_ethereal(args.design, args.out, top=args.top)
    print(f"[synth_ethereal] {args.design}: {r['lut4_count']} eLUT4 "
          f"({r['dff_count']} FF) -> {r['json']}, {r['blif']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
