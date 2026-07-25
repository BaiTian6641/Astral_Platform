# SPDX-License-Identifier: MIT
"""bitgen_db — LEVEL-1 config semantic DB builder (task E0-MAP3 increment 1).

Plan-Ref: ethereal-plan/components/C-soft-工具与固件组件.md §2 (bitgen two-level
          design). This module implements LEVEL 1 only: the fabric-independent
          *config semantic* database (which eLUT4 carries which truth table,
          which IIB mux selects which source). LEVEL 2 (raw frame-bit packing,
          OCC frame layout) is a LATER increment — nothing here emits frames.

Inputs: a VPR pack/place result (``.net`` XML + ``.place``) plus the Yosys BLIF
        (``.blif``) produced by synth_ethereal (E0-MAP1). The DB maps each placed
        cluster tile (x,y) -> TileLogic (per-eLUT4 ElutConfig + IIB mux selects +
        cluster I/O net maps). It is fabric-independent: it holds *semantic*
        config, not raw frame bits.

==============================================================================
THE TRUTH-TABLE PIN PERMUTATION (the key correctness issue) — FINDINGS
==============================================================================
VPR permutes 4-LUT inputs when packing. The eLUT4 hardware evaluates
``vout = tt[vin]`` where ``vin = {pin3,pin2,pin1,pin0}`` (pin0 = LSB) and
``pin_gk`` is the value on physical pin gk. So the stored ``tt`` must be indexed
by *physical* pin value, while Yosys emits the LUT truth table in *logical*
(input-list) order. We must permute.

Convention used (verified bit-true on c17, see test_bitgen.test_c17_bittrue):
  * ``port_rotation_map[i]`` = the LOGICAL input position (0..3, in BLIF
    ``.names`` input-list order, MSB-first: list position 0 = TT bit 3) carried
    by PHYSICAL pin i.  i.e. it is the physical->logical map.
  * The CROSSBAR mapping (``fle.in[gk] = clb.I[idx] / fle[j].out``) is the
    hardware truth and is AUTHORITATIVE. For c17 the crossbar-derived
    physical->logical map EQUALS ``port_rotation_map`` exactly:
        fle[6] (N22): crossbar pin0=N6,pin1=N1,pin2=N3,pin3=N2  -> [3,2,1,0]
                      port_rotation_map                       = "3 2 1 0"  OK
        fle[7] (N23): crossbar pin0=N7,pin1=N2,pin2=N6,pin3=N3  -> [2,3,0,1]
                      port_rotation_map                       = "2 3 0 1"  OK
  * Strategy that worked: derive phys_to_log from the crossbar (net-name match
    against the BLIF ``.names`` input list), CROSS-CHECK against
    port_rotation_map (warn on disagreement, proceed with crossbar), then
    ``permute_tt(logical_tt, phys_to_log)``. No brute-force was needed for c17;
    test_bitgen still ships a 24-perm brute-force fallback per LUT.

==============================================================================
cfg_data BIT LAYOUT — ASSUMPTION (G6, maintainer to confirm)
==============================================================================
The task brief states the 20-bit eLUT cfg word as
``tt[15:0] | ff_en<<16 | ff_rst_en<<17 | ff_rst_val<<18 | out_inv<<19``.
The ACTUAL RTL (ethereal-fabric/rtl/clb/elut4.sv) implements:
    tt_r         <= cfg_data_i[19:4];
    ff_en_r      <= cfg_data_i[3];
    ff_rst_en_r  <= cfg_data_i[2];
    ff_rst_val_r <= cfg_data_i[1];
    out_inv_r    <= cfg_data_i[0];
and clb_t.sv's comment explains the *concatenation* ``{tt[15:0], ff_en,
ff_rst_en, ff_rst_val, out_inv}`` (Verilog concat: leftmost element = MSB)
resolves to ``[19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv``.
These two readings CONFLICT (the brief reads the concat as Python bit-assignment;
the RTL reads it as Verilog concat = leftmost is MSB). ``elut_cfg_word`` below
follows the RTL — it is the executable hardware ground truth, and any future
LEVEL-2 frame packer must match it or the configured fabric computes garbage.
The c17 bit-true validation does NOT depend on this choice (it evaluates the
``ElutConfig`` dataclass directly, not the packed word), so it remains valid
evidence either way. Flagged for maintainer in the acceptance report.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

# ---- frozen fabric constants (mirror clb_t.sv / C01 §2.3) -------------------
N = 8        # eLUT4 count per cluster
K = 4        # eLUT4 input width
EXT_IN = 18  # external cluster inputs (clb_in[0..17])
FB_BASE = EXT_IN   # feedback pool starts at pool sel 18 (eLUT4 j -> 18+j)


# =============================================================================
# Data model (fabric-independent, LEVEL 1)
# =============================================================================

@dataclass
class ElutConfig:
    """Per-eLUT4 semantic config. ``tt`` is in PHYSICAL pin order (tt[vin])."""

    tt: int                       # 16-bit, physical-pin order
    ff_en: bool = False           # 1 = register the LUT output
    ff_rst_en: bool = False       # 1 = user reset affects the virtual FF
    ff_rst_val: bool = False      # value loaded into vff on reset
    out_inv: bool = False         # 1 = invert the output


@dataclass
class TileLogic:
    """Per-cluster-tile semantic config (the LEVEL-1 DB leaf)."""

    eluts: dict[int, ElutConfig] = field(default_factory=dict)
    # (gi, gk) -> pool sel 0..25 (0..17 = clb_in, 18..25 = feedback eLUT4 j)
    iib_mux: dict[tuple[int, int], int] = field(default_factory=dict)
    cluster_inputs: dict[int, str | None] = field(default_factory=dict)   # clb.I[0..17]
    cluster_outputs: dict[int, str | None] = field(default_factory=dict)  # clb_out[0..7] = fle[j] net


@dataclass
class FabricConfigDB:
    """The LEVEL-1 fabric config DB: tiles keyed by VPR grid (x, y)."""

    tiles: dict[tuple[int, int], TileLogic] = field(default_factory=dict)
    primary_inputs: list[str] = field(default_factory=list)
    primary_outputs: list[str] = field(default_factory=list)


# =============================================================================
# Helpers
# =============================================================================

def elut_cfg_word(ec: ElutConfig) -> int:
    """Pack an ElutConfig into the 20-bit cfg_data word.

    Follows the RTL (elut4.sv): ``[19:4]=tt, [3]=ff_en, [2]=ff_rst_en,
    [1]=ff_rst_val, [0]=out_inv``. See module docstring ASSUMPTION.
    """
    word = (ec.tt & 0xFFFF) << 4
    word |= (1 if ec.ff_en else 0) << 3
    word |= (1 if ec.ff_rst_en else 0) << 2
    word |= (1 if ec.ff_rst_val else 0) << 1
    word |= (1 if ec.out_inv else 0) << 0
    return word & 0xFFFFF


def elut_from_word(word: int) -> ElutConfig:
    """Inverse of :func:`elut_cfg_word` — unpack a 20-bit cfg word to ElutConfig.

    Bit layout (matches the RTL, see :func:`elut_cfg_word`):
    ``[19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv``.
    Added in E0-MAP3 increment 3 so the LEVEL-2 frame packer can rebuild the
    semantic DB from unpacked frames.
    """
    w = word & 0xFFFFF
    return ElutConfig(
        tt=(w >> 4) & 0xFFFF,
        ff_en=bool((w >> 3) & 1),
        ff_rst_en=bool((w >> 2) & 1),
        ff_rst_val=bool((w >> 1) & 1),
        out_inv=bool(w & 1),
    )


def iib_sel_for(gi: int, gk: int, source: tuple[str, int]) -> int:
    """Map a crossbar source spec to its IIB pool select.

    ``source`` is ``('clb.I', idx)`` -> pool sel ``idx`` (0..17), or
    ``('fle', j)``    -> pool sel ``18 + j`` (feedback, 18..25).
    ``gi``/``gk`` are accepted for API symmetry (the mux identity) and are not
    needed to compute the sel since the source already encodes the origin.
    """
    kind, idx = source
    if kind == "clb.I":
        return idx
    if kind == "fle":
        return FB_BASE + idx
    raise ValueError(f"unknown crossbar source kind: {kind!r}")


# =============================================================================
# BLIF parsing + truth-table computation
# =============================================================================

def parse_blif(path: str) -> tuple[dict[str, tuple[list[str], list[tuple[str, int]]]],
                                   list[str], list[str]]:
    """Parse a Yosys BLIF.

    Returns ``(names, primary_inputs, primary_outputs)`` where ``names`` maps
    each driven net to ``(input_list, cubes)`` and each cube is ``(spec, value)``
    with ``spec`` a string of ``0``/``1``/``-`` aligned to ``input_list``.
    """
    names: dict[str, tuple[list[str], list[tuple[str, int]]]] = {}
    primary_in: list[str] = []
    primary_out: list[str] = []
    cur_out: str | None = None
    cur_inputs: list[str] = []
    cur_cubes: list[tuple[str, int]] = []

    def _flush() -> None:
        if cur_out is not None:
            names[cur_out] = (list(cur_inputs), list(cur_cubes))

    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith(".names"):
                _flush()
                parts = line.split()
                cur_inputs = parts[1:-1]
                cur_out = parts[-1]
                cur_cubes = []
            elif line.startswith(".inputs"):
                primary_in = line.split()[1:]
            elif line.startswith(".outputs"):
                primary_out = line.split()[1:]
            elif line.startswith("."):
                # .model / .end / .gate / etc. — ignored
                continue
            else:
                # cube line: "<spec> <value>" (or just "<value>" for constants)
                if cur_out is None:
                    continue
                parts = line.split()
                if len(parts) == 2:
                    cur_cubes.append((parts[0], int(parts[1])))
                elif len(parts) == 1:
                    cur_cubes.append(("", int(parts[0])))
    _flush()
    return names, primary_in, primary_out


def blif_names_to_logical_tt(input_list: list[str],
                             cubes: list[tuple[str, int]]) -> int:
    """Compute the (2**n)-bit truth table from BLIF cubes, MSB-first.

    Convention: ``input_list[0]`` is the MOST significant bit (TT bit n-1),
    matching the natural left-to-right read of a cube string as a binary index.
    On-set only (Yosys LUT ``.names`` emit value-1 cubes); output defaults to 0.
    """
    n = len(input_list)
    tt = 0
    for combo in range(1 << n):
        assignment = {inp: (combo >> (n - 1 - k)) & 1 for k, inp in enumerate(input_list)}
        if _cube_onset(input_list, cubes, assignment):
            tt |= 1 << combo
    return tt


def _cube_onset(input_list: list[str], cubes: list[tuple[str, int]],
                assignment: dict[str, int]) -> bool:
    """True if any value-1 cube matches the given net->bit assignment."""
    for spec, val in cubes:
        if val != 1:
            continue
        ok = True
        for k, ch in enumerate(spec):
            if ch == "-":
                continue
            bit = assignment[input_list[k]]
            if ch == "0" and bit != 0:
                ok = False
                break
            if ch == "1" and bit != 1:
                ok = False
                break
        if ok:
            return True
    return False


def permute_tt(logical_tt: int, phys_to_log: list[int] | tuple[int, ...]) -> int:
    """Permute a (16-bit, MSB-first) logical TT into PHYSICAL pin order.

    ``phys_to_log[gk]`` = logical input position (0..3, MSB-first: pos 0 = bit 3)
    carried by physical pin gk. The hardware forms
    ``vin = {pin3,pin2,pin1,pin0}`` and evaluates ``tt[vin]``.
    """
    phys_tt = 0
    for p in range(16):
        logical_bit = [0, 0, 0, 0]
        for gk in range(4):
            logical_bit[phys_to_log[gk]] = (p >> gk) & 1
        log_idx = ((logical_bit[0] << 3) | (logical_bit[1] << 2)
                  | (logical_bit[2] << 1) | logical_bit[3])
        if (logical_tt >> log_idx) & 1:
            phys_tt |= 1 << p
    return phys_tt


# =============================================================================
# .place parsing
# =============================================================================

def parse_place(path: str) -> dict[str, tuple[int, int]]:
    """Parse a VPR ``.place`` -> ``{block_name: (x, y)}`` for logic blocks."""
    pos: dict[str, tuple[int, int]] = {}
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#") or line.startswith("Netlist_File") \
                    or line.startswith("Array size"):
                continue
            parts = line.split()
            # <name> <x> <y> <subblk> <#num>
            if len(parts) >= 3 and parts[0] not in pos:
                try:
                    x, y = int(parts[1]), int(parts[2])
                except ValueError:
                    continue
                pos[parts[0]] = (x, y)
    return pos


# =============================================================================
# .net parsing -> TileLogic
# =============================================================================

_RE_CLBI = re.compile(r"clb\.I\[(\d+)\]->crossbar")
_RE_FLE = re.compile(r"fle\[(\d+)\]\.out")
_RE_FLE_IDX = re.compile(r"fle\[(\d+)\]")


def _fle_index(instance: str) -> int:
    m = _RE_FLE_IDX.search(instance)
    assert m is not None, f"cannot parse fle index from {instance!r}"
    return int(m.group(1))


def _parse_fle_in(text: str | None) -> list[tuple[str, int] | None]:
    """Parse a fle ``<port name="in">`` text -> 4 crossbar sources (None=open)."""
    srcs: list[tuple[str, int] | None] = []
    if not text:
        return [None, None, None, None]
    for tok in text.split():
        if tok == "open":
            srcs.append(None)
            continue
        m = _RE_CLBI.match(tok)
        if m:
            srcs.append(("clb.I", int(m.group(1))))
            continue
        m = _RE_FLE.match(tok)
        if m:
            srcs.append(("fle", int(m.group(1))))
            continue
        srcs.append(None)
    while len(srcs) < 4:
        srcs.append(None)
    return srcs[:4]


def _fle_ff_used(fl: ET.Element) -> bool:
    """True if the fle's ble4[0]/ff[0] carries a real net (not 'open')."""
    ble4 = fl.find("./block[@instance='ble4[0]']")
    if ble4 is None:
        return False
    ff = ble4.find("./block[@instance='ff[0]']")
    if ff is None:
        return False
    return ff.get("name") != "open"


def _derive_phys_to_log(
    sources: list[tuple[str, int] | None],
    cluster_inputs: dict[int, str | None],
    cluster_outputs: dict[int, str | None],
    input_list: list[str],
    rotation_map: list[int | None] | None,
) -> tuple[list[int], list[str]]:
    """Derive the physical->logical pin map from the crossbar (authoritative).

    Returns ``(phys_to_log, warnings)``. Undetermined pins (open / unknown net)
    are backfilled from ``rotation_map`` then identity, so the result is always
    a full 4-int list (best-effort for structural-only designs like c432).
    """
    warnings: list[str] = []
    phys_to_log: list[int | None] = [None, None, None, None]
    for gk, src in enumerate(sources):
        if src is None:
            continue
        kind, idx = src
        net = cluster_inputs.get(idx) if kind == "clb.I" else cluster_outputs.get(idx)
        if net is not None and net in input_list:
            phys_to_log[gk] = input_list.index(net)
        elif net is not None:
            warnings.append(
                f"pin{gk} net {net!r} not in LUT inputs {input_list}")
    # cross-check / backfill from rotation_map (entries may be None for open pins)
    if rotation_map is not None and len(rotation_map) == 4:
        for gk in range(4):
            r = rotation_map[gk]
            if r is None:
                continue
            if phys_to_log[gk] is None:
                phys_to_log[gk] = r
            elif phys_to_log[gk] != r:
                warnings.append(
                    f"pin{gk}: crossbar->{phys_to_log[gk]} != rotation_map->{r}")
    return [gk if v is None else v for gk, v in enumerate(phys_to_log)], warnings


def _build_tile(clb: ET.Element,
                names: dict[str, tuple[list[str], list[tuple[str, int]]]]) -> TileLogic:
    tile = TileLogic()
    tile.cluster_inputs = {k: None for k in range(EXT_IN)}
    tile.cluster_outputs = {k: None for k in range(N)}

    # cluster inputs: <port name="I">
    iport = clb.find("./inputs/port[@name='I']")
    if iport is not None and iport.text:
        for k, tok in enumerate(iport.text.split()):
            if k >= EXT_IN:
                break
            tile.cluster_inputs[k] = None if tok == "open" else tok

    # pass 1: cluster_outputs[gi] from each used fle's lut[0] leaf out-net
    for fl in clb:
        if not (fl.get("instance", "").startswith("fle[") and fl.get("mode") == "n1_lut4"):
            continue
        gi = _fle_index(fl.get("instance", ""))
        lut = fl.find(".//block[@instance='lut[0]']")
        outnet: str | None = None
        if lut is not None:
            outp = lut.find("./outputs/port[@name='out']")
            if outp is not None and outp.text:
                outnet = outp.text.strip()
        tile.cluster_outputs[gi] = outnet

    # pass 2: per-fle IIB mux selects + physical-order TT
    for fl in clb:
        if not (fl.get("instance", "").startswith("fle[") and fl.get("mode") == "n1_lut4"):
            continue
        gi = _fle_index(fl.get("instance", ""))
        inport = fl.find("./inputs/port[@name='in']")
        sources = _parse_fle_in(inport.text if inport is not None else None)

        for gk, src in enumerate(sources):
            tile.iib_mux[(gi, gk)] = iib_sel_for(gi, gk, src) if src is not None else 0

        lut = fl.find(".//block[@instance='lut[0]']")
        rotation_map: list[int | None] | None = None
        if lut is not None:
            rotp = lut.find("./inputs/port_rotation_map")
            if rotp is not None and rotp.text:
                rotation_map = [
                    None if tok == "open" else int(tok)
                    for tok in rotp.text.split()
                ]

        outnet = tile.cluster_outputs.get(gi)
        phys_tt = 0
        if outnet is not None and outnet in names:
            input_list, cubes = names[outnet]
            logical_tt = blif_names_to_logical_tt(input_list, cubes)
            if len(input_list) == 4:
                phys_to_log, _warns = _derive_phys_to_log(
                    sources, tile.cluster_inputs, tile.cluster_outputs,
                    input_list, rotation_map)
                phys_tt = permute_tt(logical_tt, phys_to_log)
            else:
                # not a 4-LUT leaf (constants etc.) — keep logical TT as-is
                phys_tt = logical_tt

        tile.eluts[gi] = ElutConfig(tt=phys_tt, ff_en=_fle_ff_used(fl))
    return tile


def build_db(net_path: str, place_path: str, blif_path: str) -> FabricConfigDB:
    """Parse (.net, .place, .blif) -> FabricConfigDB (LEVEL 1)."""
    names, primary_in, primary_out = parse_blif(blif_path)
    cluster_pos = parse_place(place_path)
    db = FabricConfigDB(primary_inputs=list(primary_in),
                        primary_outputs=list(primary_out))
    root = ET.parse(net_path).getroot()
    for clb in root:
        inst = clb.get("instance", "")
        if not (inst.startswith("clb[") and clb.get("mode") == "default"):
            continue
        cname = clb.get("name")
        pos = cluster_pos.get(cname) if cname is not None else None
        if pos is None:
            continue
        db.tiles[pos] = _build_tile(clb, names)
    return db
