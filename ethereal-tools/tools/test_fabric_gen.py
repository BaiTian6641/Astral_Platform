# SPDX-License-Identifier: MIT
"""pytest for fabric_gen (task E0-FAB6). Pure Python; runs via `make test-model`."""
from __future__ import annotations

import json
import os

import pytest

from fabric_gen import FabricGen, DEFAULTS

HERE = os.path.dirname(os.path.abspath(__file__))


# ---- geometry (the E0-FAB6 acceptance: 2x2 and 4x4 fabrics) ----------------

def test_2x2_geometry():
    fg = FabricGen.from_descriptor({"R": 2, "C": 2})
    assert fg.n_tiles == 4
    assert fg.tile_config_bits == 416                       # CLB 320 + SB 96
    assert fg.total_config_bits == 4 * 416
    assert fg.frames_per_region == 2                        # one frame per column
    assert fg.total_frames == 2
    assert fg.fm.data_words_per_frame == 26                 # ceil(2*416/32)
    assert fg.fm.words_per_frame == 27                      # + CRC tail
    assert fg.total_words == 2 * 27
    assert fg.total_bytes == 2 * 27 * 4


def test_4x4_geometry():
    fg = FabricGen.from_descriptor({"R": 4, "C": 4})
    assert fg.n_tiles == 16
    assert fg.total_config_bits == 16 * 416
    assert fg.frames_per_region == 4
    assert fg.total_frames == 4
    assert fg.fm.data_words_per_frame == 52
    assert fg.fm.words_per_frame == 53
    assert fg.total_words == 4 * 53
    assert fg.total_bytes == 4 * 53 * 4


def test_defaults_are_4x4():
    fg = FabricGen.from_descriptor({})
    assert (fg.R, fg.C, fg.W, fg.N, fg.K, fg.EXT_IN) == (
        DEFAULTS["R"], DEFAULTS["C"], DEFAULTS["W"], DEFAULTS["N"], DEFAULTS["K"], DEFAULTS["EXT_IN"]
    )


# ---- the acceptance: generated frame_map round-trips (=> usable by OCC) ----

@pytest.mark.parametrize("R,C", [(2, 2), (4, 4), (2, 3), (3, 5)])
def test_self_check_roundtrip(R, C):
    """Both 2x2 and 4x4 (and others) produce a valid, round-tripping frame_map
    -> the generated fabrics satisfy the E0-FAB4/OCC config-path acceptance."""
    fg = FabricGen.from_descriptor({"R": R, "C": C})
    fg.self_check(n_trials=4)          # pack/unpack round-trip; raises on failure


# ---- descriptor loading (JSON always; YAML if pyyaml present) --------------

def test_from_file_json(tmp_path):
    p = tmp_path / "fabric.json"
    p.write_text(json.dumps({"R": 2, "C": 2}))
    fg = FabricGen.from_file(str(p))
    assert (fg.R, fg.C) == (2, 2)


def test_from_file_yaml(tmp_path):
    yaml = pytest.importorskip("yaml")  # skip if pyyaml absent
    p = tmp_path / "fabric.yaml"
    p.write_text("R: 3\nC: 5\nW: 12\n")
    fg = FabricGen.from_file(str(p))
    assert (fg.R, fg.C, fg.W) == (3, 5, 12)


def test_reference_descriptors_load():
    """The committed reference descriptors (ethereal-spec/fabric/) are valid."""
    for name, RC in [("fabric_2x2.yaml", (2, 2)), ("fabric_4x4.yaml", (4, 4))]:
        path = os.path.join(HERE, "..", "..", "ethereal-spec", "fabric", name)
        fg = FabricGen.from_file(path)
        assert (fg.R, fg.C) == RC
        fg.self_check(n_trials=2)


# ---- artifact emission -----------------------------------------------------

def test_manifest_and_outputs(tmp_path):
    fg = FabricGen.from_descriptor({"R": 4, "C": 4})
    m = fg.manifest()
    assert m["instantiation"]["module"] == "fabric_top"
    assert m["instantiation"]["params"]["R"] == 4
    paths = fg.write_outputs(str(tmp_path))
    for k in ("frame_map", "manifest", "blank"):
        assert os.path.exists(paths[k])
    # frame_map.json is valid JSON and matches FrameMap.to_json
    jm = json.load(open(paths["frame_map"]))
    assert jm["words_per_frame"] == 53
    # blank.hex has words_per_frame lines
    nlines = sum(1 for _ in open(paths["blank"]))
    assert nlines == fg.fm.words_per_frame


def test_invalid_descriptor_rejected():
    with pytest.raises(ValueError):
        FabricGen.from_descriptor({"R": 0})
    with pytest.raises(ValueError):
        FabricGen.from_descriptor({"sel_w": 16})
