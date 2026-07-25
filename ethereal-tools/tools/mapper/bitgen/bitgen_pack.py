# SPDX-License-Identifier: MIT
"""bitgen_pack — LEVEL-2 frame packing for the Ethereal Fabric
(task E0-MAP3 increment 3).

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2 (bitgen two-level
          design — this module is LEVEL 2: DB -> physical config frames).

LEVEL 1 (bitgen_db) produces a fabric-independent *config semantic* DB
(per-eLUT4 truth tables, IIB mux selects, cluster I/O net maps) keyed by VPR
grid (x, y). LEVEL 2 maps that DB into the physical **config frames** defined by
:mod:`frame_map` (the SoT), and back. A frame = one COLUMN of tiles' config
bits packed into 32-bit words + a CRC16 tail word (see frame_map.FrameMap).

Scope of THIS increment (incr 3): CLB-Tile points only.
  * Per-tile CLB config points: ``elut0..elut7`` (20-bit each) +
    ``iib_mux0..iib_mux31`` (5-bit each, ``m = gi*K + gk``).
  * SB (mux_{n,s,e,w}_*, inj_en_*) and CB (cb_sel_*) are left BLANK (default 0)
    — routable-CB / switch-box config bits land in increment 4 (routing). The
    frame_map *reserves* their bits (so the frame width is unchanged); they
    simply read back as 0 here, which is the deliberate quiescent/safe pattern.

==============================================================================
NET-NAME RE-ATTACHMENT (by design — DO NOT pack net names into frames)
==============================================================================
Config frames carry only **bit-level** fabric configuration (TT words, mux
selects). They do NOT carry net names: ``TileLogic.cluster_inputs`` and
``cluster_outputs`` (and the DB's ``primary_inputs``/``primary_outputs``) are
netlist-level *design* context, not fabric-config bits. Consequently, a
``TileLogic`` reconstructed from unpacked frames has EMPTY cluster_inputs /
cluster_outputs.

This is intentional and matches the hardware model: the OCC writes raw config
bits; the design's I/O mapping is reapplied at *apply time* by the OCC / sim
harness from the LEVEL-1 DB. The functional-after-pack validation
(``test_c17_functional_after_pack``) re-attaches the original tile's
``cluster_inputs`` / ``cluster_outputs`` onto the reconstructed tile before
calling :func:`bitgen_sim.simulate_tile`, mirroring exactly what the apply-time
harness must do. The frame round-trip itself is checked separately on the
config points (``elut*`` / ``iib_mux*``), which ARE frame-carried.
"""
from __future__ import annotations

import os
import sys

# frame_map.py lives two dirs up (ethereal-tools/tools/); allow `from frame_map
# import FrameMap` regardless of CWD when run via pytest / make test-model.
_TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from bitgen_db import (EXT_IN, K, N, FabricConfigDB, TileLogic,  # noqa: E402
                       elut_cfg_word, elut_from_word)
from frame_map import FrameMap  # noqa: E402


# =============================================================================
# Geometry
# =============================================================================

def db_grid_bounds(db: FabricConfigDB) -> tuple[int, int, int, int]:
    """Return ``(min_x, min_y, max_x, max_y)`` over ``db.tiles`` keys.

    Tiles are keyed by VPR grid coords (x, y). The frame packer normalizes these
    to 0-based (col, row) = (x - min_x, y - min_y). A single-tile design (c17)
    yields ``(1, 1, 1, 1)``.
    """
    if not db.tiles:
        raise ValueError("FabricConfigDB has no tiles — cannot derive grid bounds")
    xs = [x for (x, _y) in db.tiles]
    ys = [y for (_x, y) in db.tiles]
    return min(xs), min(ys), max(xs), max(ys)


# =============================================================================
# CLB-Tile config points <-> TileLogic
# =============================================================================

def tile_to_config_points(tile: TileLogic, n: int = N, k: int = K) -> dict[str, int]:
    """Project a TileLogic's CLB config into frame_map config points.

    Only CLB points are emitted (SB / CB stay at frame_map's default 0 = blank).
    For ``i`` in ``0..n-1``: ``elut{i}`` = ``elut_cfg_word(tile.eluts[i])`` if
    present else 0. For ``m`` in ``0..n*k-1``: ``iib_mux{m}`` =
    ``tile.iib_mux.get((m // k, m % k), 0)`` (``m = gi*k + gk``).

    ``cluster_inputs`` / ``cluster_outputs`` are netlist context and are NOT
    emitted (see module docstring).
    """
    cfg: dict[str, int] = {}
    for i in range(n):
        ec = tile.eluts.get(i)
        cfg[f"elut{i}"] = elut_cfg_word(ec) if ec is not None else 0
    for m in range(n * k):
        gi, gk = m // k, m % k
        cfg[f"iib_mux{m}"] = tile.iib_mux.get((gi, gk), 0)
    return cfg


def config_points_to_tile(cfg: dict[str, int], n: int = N, k: int = K) -> TileLogic:
    """Inverse of :func:`tile_to_config_points` (CLB points only).

    Rebuilds a :class:`TileLogic` from unpacked config points. For each
    ``elut{i}`` present AND nonzero, the eLUT is reconstructed via
    :func:`elut_from_word`; zero ``elut{i}`` means the slot is unused and is
    omitted from ``tile.eluts`` (matches the DB semantics: absent = unused).
    Each present ``iib_mux{m}`` (nonzero) is stored at ``((m // k, m % k))``.

    The reconstructed tile has EMPTY ``cluster_inputs`` / ``cluster_outputs``
    (net names are not frame-carried — see module docstring).
    """
    tile = TileLogic()
    for i in range(n):
        w = int(cfg.get(f"elut{i}", 0))
        if w != 0:
            tile.eluts[i] = elut_from_word(w)
    for m in range(n * k):
        sel = int(cfg.get(f"iib_mux{m}", 0))
        if sel != 0:
            gi, gk = m // k, m % k
            tile.iib_mux[(gi, gk)] = sel
    return tile


# =============================================================================
# FabricConfigDB <-> frames
# =============================================================================

def db_to_frames(db: FabricConfigDB) -> tuple[list[list[int]], FrameMap]:
    """Pack a :class:`FabricConfigDB` into per-column config frames.

    Normalizes tile coords to 0-based (col, row). Constructs a
    :class:`FrameMap` with ``R = (max_y - min_y + 1)``,
    ``C = (max_x - min_x + 1)``, ``W = 12``, ``N = 8``, ``K = 4``,
    ``EXT_IN = 18`` (matching the frozen fabric constants). For each column
    ``c`` in ``0..C-1`` builds ``col_config`` of length R (missing tiles -> blank
    ``{}``), then ``fm.pack(col_config)`` -> one frame. Returns
    ``(list_of_C_frames, fm)``.
    """
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    rows = max_y - min_y + 1
    cols = max_x - min_x + 1
    fm = FrameMap(R=rows, C=cols, W=12, N=N, K=K, EXT_IN=EXT_IN)
    frames: list[list[int]] = []
    for c in range(cols):
        col_config: list[dict[str, int]] = []
        for r in range(rows):
            tile = db.tiles.get((c + min_x, r + min_y))
            col_config.append(tile_to_config_points(tile) if tile is not None else {})
        frames.append(fm.pack(col_config))
    return frames, fm


def frames_to_db(frames: list[list[int]], fm: FrameMap,
                 min_x: int, min_y: int) -> FabricConfigDB:
    """Inverse of :func:`db_to_frames`.

    Unpacks each frame via ``fm.unpack`` (verifies CRC), rebuilds each tile via
    :func:`config_points_to_tile`, and places it at ``(col + min_x, r + min_y)``.
    The reconstructed DB has EMPTY ``primary_inputs`` / ``primary_outputs`` and
    per-tile empty ``cluster_inputs`` / ``cluster_outputs`` (net names are not
    frame-carried — re-attach from the LEVEL-1 DB at apply time).
    """
    if len(frames) != fm.C:
        raise ValueError(f"expected {fm.C} frames (one per column), got {len(frames)}")
    db = FabricConfigDB()
    for c, frame in enumerate(frames):
        col_config = fm.unpack(frame)   # raises on CRC mismatch
        for r, cfg in enumerate(col_config):
            db.tiles[(c + min_x, r + min_y)] = config_points_to_tile(cfg, fm.N, fm.K)
    return db
