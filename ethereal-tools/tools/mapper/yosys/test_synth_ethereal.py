# SPDX-License-Identifier: MIT
"""pytest for synth_ethereal (task E0-MAP1). Pure Python + calls the local Yosys.
Skipped if `yosys` is not on PATH (set YOSYS or add OSS-CAD's bin)."""
from __future__ import annotations

import os
import shutil

import pytest

from synth_ethereal import synth_ethereal

YOSYS_AVAILABLE = bool(shutil.which("yosys")) or bool(os.environ.get("YOSYS"))
pytestmark = pytest.mark.skipif(not YOSYS_AVAILABLE, reason="yosys not on PATH")

HERE = os.path.dirname(os.path.abspath(__file__))
BENCH = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "ethereal-images", "benchmarks"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "generated", "mapper"))


def _run(name: str, top: str | None = None) -> dict:
    return synth_ethereal(os.path.join(BENCH, name), os.path.join(OUT, name[:-2]), top=top)


# ---- c17 (canonical tiny ISCAS85) -----------------------------------------

def test_c17_maps_to_elut4():
    r = _run("c17.v")
    assert r["lut4_count"] > 0, "c17 must map to >=1 eLUT4"
    assert r["dff_count"] == 0          # c17 is combinational
    # c17 has 5 inputs / 2 outputs; collapses to a small number of 4-LUTs (typically 2-3).
    assert r["lut4_count"] <= 4, f"c17 LUT4 count unexpectedly high: {r['lut4_count']}"
    assert os.path.exists(r["json"]) and os.path.exists(r["blif"])


# ---- c432 (real ISCAS85, ~160 gates) --------------------------------------

def test_c432_maps_to_elut4_reasonable():
    r = _run("c432.v")
    assert r["lut4_count"] > 0
    assert r["dff_count"] == 0          # c432 is combinational
    # literature: c432 maps to ~50-70 4-LUTs; accept a generous, sane band.
    assert 30 <= r["lut4_count"] <= 120, f"c432 LUT4 count out of band: {r['lut4_count']}"


# ---- netlist artifacts -----------------------------------------------------

def test_netlist_has_lut_cells():
    import json
    r = _run("c17.v")
    d = json.load(open(r["json"]))
    nlut = sum(1 for mod in d["modules"].values() for c in mod["cells"].values()
               if c["type"] == "$lut")
    assert nlut == r["lut4_count"]      # parsed count matches the actual netlist


def test_missing_design_raises():
    with pytest.raises(FileNotFoundError):
        synth_ethereal(os.path.join(BENCH, "does_not_exist.v"), os.path.join(OUT, "nope"))
