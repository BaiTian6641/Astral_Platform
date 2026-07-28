# SPDX-License-Identifier: MIT
"""fabric-gen v0 — fabric descriptor -> frame_map.json + manifest + blank.hex.

Task E0-FAB6. Reads a fabric descriptor (fabric.yaml or fabric.json) describing
the tile array + regions, and emits the artifacts the rest of the toolchain
consumes:
  * frame_map.json  — the configuration frame layout (single source of truth for
                      bitgen / OCC / readback), produced by ``frame_map.FrameMap``.
  * manifest.json   — fabric parameters + derived geometry (tile count, total
                      config bits, frame count, total words) — i.e. the
                      instantiation parameters for the parameterized ``fabric_top``.
  * blank.hex       — the explicit safe/zero frame (electrical-quiescent).

Because ``fabric_top`` is already **parameterized** (R, C, W, N, K, EXT_IN),
fabric-gen v0 emits the *parameters* + frame_map rather than bespoke generated
RTL (a deliberate v1 simplification — C01/S03 allow either; the parameterized
top makes a per-fabric Verilog emit unnecessary for v0).

Descriptor schema (YAML or JSON), all keys optional with v1 defaults:
  R, C       : grid rows/cols           (default 4, 4)
  W          : tracks per direction     (default 12)
  N, K       : eLUT4 count / inputs     (default 8, 4)
  EXT_IN     : external cluster inputs  (default 18)
  sel_w      : IIB mux select width     (default 5)
  n_regions  : region count             (default 1)

Run:  python fabric_gen.py fabric.yaml -o generated/fabricA/
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass

# allow `from frame_map import FrameMap` when run from this dir or via make test-model
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frame_map import FrameMap, TT_CLB, TT_MEM, TT_DSP  # noqa: E402

DEFAULTS = dict(R=4, C=4, W=12, N=8, K=4, EXT_IN=18, sel_w=5, n_regions=1)
INT_KEYS = ("R", "C", "W", "N", "K", "EXT_IN", "sel_w", "n_regions")


@dataclass
class FabricGen:
    """Build the per-fabric artifacts from a descriptor."""

    R: int
    C: int
    W: int
    N: int
    K: int
    EXT_IN: int
    sel_w: int
    n_regions: int
    MEM_AW: int = 11
    # tile_types[col][row] -> "clb_t"|"mem_t"|"dsp_t" (heterogeneous, Phase-1).
    # None = homogeneous all-CLB (v1). Per-column list of per-row type names.
    tile_types: list[list[str]] | None = None
    fm: FrameMap = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        for k in INT_KEYS:
            v = int(getattr(self, k))
            if v <= 0:
                raise ValueError(f"descriptor field {k} must be > 0, got {v}")
            setattr(self, k, v)
        if self.sel_w <= 0 or self.sel_w > 8:
            raise ValueError(f"sel_w out of range (1..8): {self.sel_w}")
        # heterogeneous: tile_types -> TILE_LAYOUT (per-column type codes)
        layout = None
        if self.tile_types is not None:
            name_to_code = {"clb_t": TT_CLB, "mem_t": TT_MEM, "dsp_t": TT_DSP}
            if len(self.tile_types) != self.C:
                raise ValueError(f"tile_types must have C={self.C} columns")
            layout = []
            for col_types in self.tile_types:
                if len(col_types) != self.R:
                    raise ValueError(f"each tile_types column must have R={self.R} rows")
                layout.append([name_to_code[t] for t in col_types])
        self.fm = FrameMap(R=self.R, C=self.C, W=self.W, N=self.N, K=self.K,
                           EXT_IN=self.EXT_IN, sel_w=self.sel_w,
                           n_regions=self.n_regions, MEM_AW=self.MEM_AW,
                           TILE_LAYOUT=layout)

    # -- factories ----------------------------------------------------------
    @classmethod
    def from_descriptor(cls, d: dict) -> "FabricGen":
        kw = {k: int(d.get(k, DEFAULTS[k])) for k in INT_KEYS}
        if "MEM_AW" in d:
            kw["MEM_AW"] = int(d["MEM_AW"])
        if "tile_types" in d:
            kw["tile_types"] = d["tile_types"]   # [col][row] -> type name
        return cls(**kw)

    @classmethod
    def from_file(cls, path: str) -> "FabricGen":
        text = open(path, "r", encoding="utf-8").read()
        if path.lower().endswith((".yaml", ".yml")):
            try:
                import yaml  # type: ignore
            except ImportError as e:  # pragma: no cover
                raise RuntimeError(
                    "pyyaml not installed; use a .json descriptor or `pip install pyyaml`"
                ) from e
            data = yaml.safe_load(text) or {}
        else:
            data = json.loads(text)
        if not isinstance(data, dict):
            raise ValueError(f"descriptor must be a mapping, got {type(data).__name__}")
        return cls.from_descriptor(data)

    # -- derived geometry ---------------------------------------------------
    @property
    def n_tiles(self) -> int:
        return self.R * self.C

    @property
    def tile_config_bits(self) -> int:
        return self.fm.tile_width  # CLB + SB + CB

    @property
    def total_config_bits(self) -> int:
        return self.n_tiles * self.tile_config_bits

    @property
    def frames_per_region(self) -> int:
        return self.C  # one frame per column

    @property
    def total_frames(self) -> int:
        return self.frames_per_region * self.n_regions

    @property
    def total_words(self) -> int:
        return self.total_frames * self.fm.words_per_frame

    @property
    def total_bytes(self) -> int:
        return self.total_words * 4

    def manifest(self) -> dict:
        """Fabric instantiation parameters + geometry (for fabric_top + reports)."""
        m = {
            "name": f"fabric_{self.R}x{self.C}_W{self.W}",
            "params": {k: int(getattr(self, k)) for k in INT_KEYS},
            "geometry": {
                "n_tiles": self.n_tiles,
                "tile_config_bits": self.tile_config_bits,
                "total_config_bits": self.total_config_bits,
                "frames_per_region": self.frames_per_region,
                "total_frames": self.total_frames,
                "words_per_frame": self.fm.words_per_frame,
                "data_words_per_frame": self.fm.data_words_per_frame,
                "total_words": self.total_words,
                "total_bytes": self.total_bytes,
            },
            "instantiation": {
                "module": "fabric_top",
                "params": {k: int(getattr(self, k)) for k in ("R", "C", "W", "N", "K", "EXT_IN")},
                "note": "fabric_top is parameterized; pass these params (no bespoke RTL gen needed in v0).",
            },
        }
        if self.tile_types is not None:
            # TILE_TYPE flattened: idx = col*R + row? No — fabric_top uses idx=r*C+c
            # (row-major). Emit the fabric_top TILE_TYPE packed value (8-bit entries,
            # LSB-first, entry r*C+c) + per-column frame words + the type map.
            code_of = {"clb_t": TT_CLB, "mem_t": TT_MEM, "dsp_t": TT_DSP}
            tile_type_packed = 0
            for r in range(self.R):
                for c in range(self.C):
                    tile_type_packed |= code_of[self.tile_types[c][r]] << ((r*self.C + c)*8)
            m["heterogeneous"] = {
                "tile_types": self.tile_types,            # [col][row] -> type name
                "tile_type_packed": tile_type_packed,     # fabric_top TILE_TYPE param
                "per_column_data_words": [self.fm.column_data_words(c) for c in range(self.C)],
                "per_column_bits": [self.fm.column_bits_at(c) for c in range(self.C)],
                "note": "heterogeneous tiles (C02): MEM_T/DSP_T config via cfg unit 2'b11.",
            }
            m["instantiation"]["params"]["TILE_TYPE"] = tile_type_packed
        return m

    # -- artifact emission --------------------------------------------------
    def write_outputs(self, out_dir: str) -> dict:
        os.makedirs(out_dir, exist_ok=True)
        paths = {}
        # frame_map.json
        p = os.path.join(out_dir, "frame_map.json")
        open(p, "w", encoding="utf-8").write(self.fm.to_json_str())
        paths["frame_map"] = p
        # manifest.json
        p = os.path.join(out_dir, "manifest.json")
        open(p, "w", encoding="utf-8").write(json.dumps(self.manifest(), indent=2))
        paths["manifest"] = p
        # blank.hex (one representative blank frame; per-column blanks are identical in v0)
        p = os.path.join(out_dir, "blank.hex")
        blank = self.fm.blank_frame()
        open(p, "w", encoding="utf-8").write("\n".join(f"{w:08x}" for w in blank) + "\n")
        paths["blank"] = p
        return paths

    # -- self-check: frame_map round-trips for this fabric ------------------
    def self_check(self, n_trials: int = 8) -> None:
        """Pack/unpack round-trip on random column configs (validates the frame_map)."""
        import random
        pts = self.fm._tile_points()
        for _ in range(n_trials):
            for _col in range(self.C):
                cfg = [{p.name: random.getrandbits(p.width) for p in pts} for _ in range(self.R)]
                assert self.fm.unpack(self.fm.pack(cfg)) == cfg, "frame_map round-trip failed"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Ethereal fabric-gen v0 (E0-FAB6)")
    ap.add_argument("descriptor", help="fabric.yaml / fabric.json descriptor file")
    ap.add_argument("-o", "--out", default="generated/fabric", help="output directory")
    args = ap.parse_args(argv)
    fg = FabricGen.from_file(args.descriptor)
    fg.self_check()
    paths = fg.write_outputs(args.out)
    m = fg.manifest()
    print(f"[fabric-gen] {m['name']}: {m['geometry']['n_tiles']} tiles, "
          f"{m['geometry']['total_config_bits']} config bits, "
          f"{m['geometry']['total_frames']} frames, "
          f"{m['geometry']['total_words']} words ({m['geometry']['total_bytes']} B)")
    for k, p in paths.items():
        print(f"[fabric-gen]   wrote {k}: {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
