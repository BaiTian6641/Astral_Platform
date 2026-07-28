# SPDX-License-Identifier: MIT
"""bitgen_het — heterogeneous (hard-cell) -> tile vbus-ctrl config mapper
(Stage 5b, task E0-MAP3 heterogeneous extension).

Plan-Ref: ethereal-plan/components/C02-fabric-异构tile.md §1.3/§2.3 (the frozen
          mem_t / dsp_t vbus-ctrl interfaces) + C-soft-工具与固件组件.md §2.

This module maps the placed hard cells captured by :mod:`bitgen_db`
(``MaccCell`` / ``MemCell``) into the per-tile **vbus-ctrl config points**
defined by :mod:`frame_map` (``dsp_tile_type`` / ``mem_tile_type``). The result
is a ``dict[config-point-name -> int]`` per placed hard-cell tile, ready for the
heterogeneous frame packer (Stage 4 layout).

==============================================================================
THE VBUS-CTRL OPERAND MODEL (Stage 5b — DOCUMENTED, G6)
==============================================================================
The ``dsp_t`` / ``mem_t`` tiles hold their operands in **vbus-ctrl config
registers** (``va_i`` / ``vb_i`` / ``vcasc_i`` for DSP; ``va_i`` / ``vd_i`` /
``vwe_i`` for MEM). Those registers carry **operand VALUES**, but the VPR
netlist carries operand **NETS** (signals). Bridging the two requires a model:

  * **Stage 5b (this stage): host-driven constant operands.** The operands are
    primary inputs driven by the host with a constant value (the MAC smoke/demo
    pattern: the host writes A=7, B=6, the tile computes 42). The bitgen maps
    the operand VALUE supplied alongside the cell (``aval`` / ``bval`` / the ROM
    ``init`` content) directly into the vbus-ctrl register. This matches the
    Stage-3 integration pattern (``tb_het_fabric`` drives dsp va=7, vb=6 via cfg
    unit 11). The net names are captured for traceability / future routed-operand
    resolution but are NOT decoded into values here.
  * **Stage 6 (future): routed operands.** For a real FIR the operands come from
    the fabric routing (a CLB output drives the DSP operand). The vbus-ctrl then
    holds the ROUTED value at apply time, resolved by the OCC/runtime from the
    routed netlist. That is OUT OF SCOPE for Stage 5b.

ASSUMPTION (G6, maintainer to confirm): for the Stage-5b acceptance the DSP
operands are host-driven constants supplied to ``macc_to_dsp_config`` as
``aval`` / ``bval``. This is the documented, clean acceptance: 7*6 -> 42 via the
bitgen-produced config. If the operands must instead be derived from routed net
activity (netlist simulation), that is a Stage-6 follow-up.
"""
from __future__ import annotations

from bitgen_db import FabricConfigDB, MaccCell, MemCell

# frame_map dsp_tile_type / mem_tile_type point names (the SoT layout):
#   dsp: dsp_mode(24) dsp_va(27) dsp_vb(18) dsp_ven(1) dsp_vcasc(48)
#   mem: mem_mode(16) mem_vbus_ctrl(22) mem_vd_i(32)

# dsp mode-word bitfield (frozen v1, dsp_t.sv): [0]=acc, [2:1]=lat_sel.
_DSP_MODE_ACC = 0
_DSP_MODE_LAT_LSB = 1


def macc_to_dsp_config(cell: MaccCell, acc: bool = False, lat_sel: int = 3,
                       aval: int = 0, bval: int = 0, cval: int = 0) -> dict[str, int]:
    """Map a placed MaccCell to its dsp_tile_type vbus-ctrl config points.

    ``aval`` / ``bval`` / ``cval`` are the OPERAND VALUES (host-driven constants
    in the Stage-5b model — see the module docstring). ``acc`` selects
    MAC-accumulate vs MULT; ``lat_sel`` is the runtime pipeline latency tap
    (mode[2:1], C02 §2.3). ``cell`` is used for traceability (its ``tile`` and
    net lists) — the values come from the explicit arguments, not the nets.
    """
    _ = cell  # operand values come from aval/bval/cval in the Stage-5b model
    if not (0 <= lat_sel <= 3):
        raise ValueError(f"lat_sel must be 0..3, got {lat_sel}")
    dsp_mode = ((1 if acc else 0) << _DSP_MODE_ACC) | (lat_sel << _DSP_MODE_LAT_LSB)
    return {
        "dsp_mode": dsp_mode & 0xFFFFFF,                 # 24-bit mode word
        "dsp_va": aval & 0x7FFFFFF,                      # 27-bit operand A
        "dsp_vb": bval & 0x3FFFF,                        # 18-bit operand B
        "dsp_ven": 1,                                    # enable the tile
        "dsp_vcasc": cval & 0xFFFFFFFFFFFF,              # 48-bit cascade-in
    }


def mem_to_mem_config(cell: MemCell, init: dict[int, int] | None = None,
                      mode: int = 0) -> dict[str, int]:
    """Map a placed MemCell to its mem_tile_type vbus-ctrl config points.

    ``init`` is an optional ``{addr: word}`` ROM-preload map (e.g. an S-box).
    For a single-word preload the FIRST entry is emitted as ``mem_vd_i`` with
    ``mem_vbus_ctrl`` carrying the address + write-enable + enable, matching the
    OCC ROM-init path (the vd_i write port is the ROM preload, C02 §1.3).
    ``mode`` is the 16-bit mode word (0 = RAM, default).
    """
    _ = cell
    addr = 0
    word = 0
    write = 0
    if init:
        addr, word = next(iter(sorted(init.items())))
        write = 1
    # mem vbus-ctrl word A (mem_t.sv / tb_het_fabric): va_i[13:0]@[13:0],
    # ven_i@[16], vwe_i[3:0]@[21:18].
    vbus_ctrl = ((addr & 0x3FFF)
                 | (1 << 16)                       # ven = 1
                 | ((0xF if write else 0x0) << 18))  # vwe = 1111 when writing
    return {
        "mem_mode": mode & 0xFFFF,
        "mem_vbus_ctrl": vbus_ctrl & 0x3FFFFF,     # 22-bit
        "mem_vd_i": word & 0xFFFFFFFF,             # 32-bit write data / ROM word
    }


def het_tiles_to_config(db: FabricConfigDB,
                        dsp_operands: dict[tuple[int, int], tuple[int, int, int]]
                        | None = None,
                        dsp_mode: dict[tuple[int, int], tuple[bool, int]]
                        | None = None,
                        mem_init: dict[tuple[int, int], dict[int, int]]
                        | None = None) -> dict[tuple[int, int], dict[str, int]]:
    """Per placed hard-cell tile -> its vbus-ctrl config points.

    ``dsp_operands[tile] = (aval, bval, cval)`` (host constants, default 0);
    ``dsp_mode[tile] = (acc, lat_sel)`` (default MULT, lat 3);
    ``mem_init[tile] = {addr: word}`` (ROM preload, default RAM/empty).
    Returns ``{tile: {point_name: int}}`` keyed by VPR (x, y).
    """
    out: dict[tuple[int, int], dict[str, int]] = {}
    dsp_operands = dsp_operands or {}
    dsp_mode = dsp_mode or {}
    mem_init = mem_init or {}
    for tile, cell in db.macc_cells.items():
        aval, bval, cval = dsp_operands.get(tile, (0, 0, 0))
        acc, lat_sel = dsp_mode.get(tile, (False, 3))
        out[tile] = macc_to_dsp_config(cell, acc=acc, lat_sel=lat_sel,
                                       aval=aval, bval=bval, cval=cval)
    for tile, cell in db.mem_cells.items():
        out[tile] = mem_to_mem_config(cell, init=mem_init.get(tile))
    return out
