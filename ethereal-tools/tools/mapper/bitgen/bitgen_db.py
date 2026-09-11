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
THE TRUTH-TABLE PIN PERMUTATION + v2c PIN ASSIGNMENT (the key correctness
issue) — FINDINGS
==============================================================================
VPR permutes 4-LUT inputs when packing. The eLUT4 hardware evaluates
``vout = tt[vin]`` where ``vin = {pin3,pin2,pin1,pin0}`` (pin0 = LSB) and
``pin_gk`` is the value on physical pin gk. So the stored ``tt`` must be indexed
by *physical* pin value, while Yosys emits the LUT truth table in *logical*
(input-list) order. We must permute.

Under interconnect **v1.1** (full IIB crossbar) the pin assignment came straight
from VPR's crossbar (``port_rotation_map`` cross-checked). Under interconnect
**v2c** (frozen spec interconnect-config-v0.md section 7.2) the IIB is
depopulated by parity — LUT-input mux ``m = gi*K + gk`` sees external input
``i`` only when ``i mod 2 == gk mod 2`` (invariant R2; feedback is always full,
R1; each LUT has exactly 2 pin slots per parity class, R3) — so VPR's
class-unaware pin assignment is no longer realizable in general. Instead
``_build_tile`` runs the **class-aware pin-assignment solver** (ported from the
E2-FAB5 spike reference ``generated/icopt/route/iib_check.py`` L1 backtracking,
extended with the remaining real mapper freedoms):

  * **LUT pin rotation** — the per-LUT phys<->logical pin map is OURS (the
    stored TT is permuted to match, same ``permute_tt`` convention as v1.1);
  * **cluster input-pin permutation** — an external net may land on ANY
    ``clb.I[i]`` (the CB/router reaches every pin; pin class = i mod 2);
  * **cluster pin duplication** — an external net may ALSO land on one pin of
    EACH parity class (the router simply gets two sinks; the CB can deliver
    the same track to both), which decouples per-LUT class pressure;
  * **don't-care drop** — a physical pin whose VPR-tied net is NOT a logical
    input of the LUT is tied to feedback j=0 (sel 0, always legal) and the TT
    is replicated over it (``_expand_logical_tt``); it consumes NO class slot.

The solver is EXACT (backtracking over per-LUT parity-class assignments with a
per-class pin budget of EXT_IN/2 = 9), deterministic (sorted nets/options), and
raises RuntimeError on an infeasible tile rather than emitting a wrong config.

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

# ---- frozen fabric constants (mirror clb_t.sv / interconnect v2c section 7.2)
N = 8        # eLUT4 count per cluster
K = 4        # eLUT4 input width
EXT_IN = 18  # external cluster inputs (clb_in[0..17])
# v2c IIB select encoding (5 bits, pure bit-slicing):
#   sel[4]=1 -> external input pool[{sel[3:0], pi(m)}] = 2*sel[3:0] + gk mod 2
#   sel[4]=0 -> feedback j = sel[2:0]              (sel[3] don't-care)
IIB_EXT_FLAG = 0b10000          # sel[4]: external-input selects are >= 16
IIB_SEL_MAX = IIB_EXT_FLAG | 8  # largest LEGAL sel (ext k=8 -> pool pin 16/17)


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
    # (gi, gk) -> v2c IIB sel (section 7.2): 0..7 = feedback eLUT4 j,
    # 16..24 = external input 2*(sel&0xF)+(gk mod 2). Decode via iib_decode.
    iib_mux: dict[tuple[int, int], int] = field(default_factory=dict)
    cluster_inputs: dict[int, str | None] = field(default_factory=dict)   # clb.I[0..17]
    cluster_outputs: dict[int, str | None] = field(default_factory=dict)  # clb_out[0..7] = fle[j] net


@dataclass
class MaccCell:
    """A placed DSP hard cell (``$macc_v2`` -> VPR ``mult_27x18`` tile).

    Stage 5b (heterogeneous bitgen). The net lists are BIT-BLASTED (Yosys
    expands wide buses into per-bit nets) and order-preserved: ``a_nets[i]`` is
    operand-A bit ``i``. ``tile`` is the VPR grid (x, y) of the ``mult_27x18``
    block from ``.place``.
    """

    a_nets: list[str] = field(default_factory=list)      # 27, bit0 first
    b_nets: list[str] = field(default_factory=list)      # 18, bit0 first
    y_nets: list[str] = field(default_factory=list)      # 48, bit0 first (leaf Y)
    tile: tuple[int, int] = (0, 0)


@dataclass
class MemCell:
    """A placed MEM hard cell (``$mem_v2`` -> VPR ``mem_2Kx32`` tile).

    Stage 5b. Bit-blasted, order-preserved nets; ``tile`` = VPR (x, y) of the
    ``mem_2Kx32`` block.
    """

    addr_nets: list[str] = field(default_factory=list)     # 11, bit0 first
    data_in_nets: list[str] = field(default_factory=list)  # 32, bit0 first
    we_net: str = ""                                       # 1 (write enable)
    data_out_nets: list[str] = field(default_factory=list)  # 32, bit0 first
    tile: tuple[int, int] = (0, 0)


@dataclass
class FabricConfigDB:
    """The LEVEL-1 fabric config DB: tiles keyed by VPR grid (x, y)."""

    tiles: dict[tuple[int, int], TileLogic] = field(default_factory=dict)
    primary_inputs: list[str] = field(default_factory=list)
    primary_outputs: list[str] = field(default_factory=list)
    # PO net -> the routed net that actually carries its value. Non-empty only
    # when VPR buffer absorption renamed a PO-driving LUT's output net to a
    # downstream buffer alias (e.g. present_round out[i] -> sboxed[j]); see
    # ``_buffer_classes`` / ``build_db``. fabric_sim taps POs through this.
    po_aliases: dict[str, str] = field(default_factory=dict)
    # Stage 5b: placed heterogeneous hard cells (DSP / MEM), keyed by tile coord.
    macc_cells: dict[tuple[int, int], MaccCell] = field(default_factory=dict)
    mem_cells: dict[tuple[int, int], MemCell] = field(default_factory=dict)


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
    """Map a crossbar source spec to its v2c IIB select (spec section 7.2).

    ``source`` is ``('clb.I', idx)`` -> sel ``16 + idx//2`` (external input;
    LEGAL only when ``idx mod 2 == gk mod 2`` — invariant R2: pin ``gk`` of
    LUT ``gi`` sees external inputs of its own parity class only), or
    ``('fle', j)`` -> sel ``j`` (feedback; always legal — invariant R1: every
    feedback entry reaches every LUT input). ``gi`` is accepted for the mux
    identity (the parity class ``pi(m) = m mod 2 = gk mod 2`` since K=4).
    Raises ValueError on an R2 parity violation or out-of-range index — the
    class-aware pin-assignment solver in ``_build_tile`` never produces one.
    """
    kind, idx = source
    if kind == "clb.I":
        if not 0 <= idx < EXT_IN:
            raise ValueError(f"clb.I index {idx} out of range 0..{EXT_IN - 1}")
        if idx % 2 != gk % 2:
            raise ValueError(
                f"R2 parity: clb.I[{idx}] unreachable from LUT{gi} pin{gk} "
                f"(class {idx % 2} != {gk % 2})")
        return IIB_EXT_FLAG | (idx // 2)
    if kind == "fle":
        if not 0 <= idx < N:
            raise ValueError(f"fle index {idx} out of range 0..{N - 1}")
        return idx
    raise ValueError(f"unknown crossbar source kind: {kind!r}")


def iib_decode(sel: int, gk: int) -> tuple[str, int]:
    """Decode a v2c IIB select at pin ``gk`` -> ``('clb.I', pin) | ('fle', j)``.

    Inverse of :func:`iib_sel_for` (spec section 7.2 bit-slicing): ``sel[4]=1``
    -> external pin ``{sel[3:0], gk mod 2}``; ``sel[4]=0`` -> feedback
    ``j = sel[2:0]``. Reserved values (``sel[4]=1`` with ``sel[3:0] >= 9``)
    decode to pins >= EXT_IN — MUST NOT be programmed (the hardware reads the
    pool padding/feedback region = undefined); callers guard ``pin < EXT_IN``.
    """
    sel &= 0b11111
    if sel & IIB_EXT_FLAG:
        return ("clb.I", ((sel & 0xF) << 1) | (gk & 1))
    return ("fle", sel & 0b111)


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


def _expand_logical_tt(logical_tt: int, n: int,
                       pin_logpos: list[int | None]) -> int:
    """Expand an n-input (n<=4) logical TT into the 4-input PHYSICAL TT.

    ``pin_logpos[gk]`` = the logical input position (MSB-first, 0..n-1) carried
    by physical pin gk, or ``None`` for a DON'T-CARE pin (a pin VPR tied to a net
    that is NOT a logical input of this LUT). The function is REPLICATED over
    the don't-care pins (they do not affect the output) — this is the correct
    sub-4-input expansion (abc emits many <4-input LUTs). Equivalent to
    :func:`permute_tt` when n==4 and every pin carries a logical input.

    Bug fix 2026-07-26 (caught by c432 bit-true, E0-MAP3 incr 4d): the previous
    code stored the raw un-expanded ``logical_tt`` for n<4, so VPR's tied
    don't-care pins perturbed the output.
    """
    tt = 0
    for p in range(16):                                  # physical combo (pin0 LSB)
        log_bits = [0] * n
        for gk in range(4):
            pos = pin_logpos[gk]
            if pos is not None:
                log_bits[pos] = (p >> gk) & 1            # DC pins: replicated
        log_idx = 0
        for pos in range(n):                             # MSB-first (BLIF conv.)
            log_idx |= log_bits[pos] << (n - 1 - pos)
        if (logical_tt >> log_idx) & 1:
            tt |= 1 << p
    return tt


# =============================================================================
# .place parsing
# =============================================================================

def parse_place(path: str) -> dict[str, tuple[int, int]]:
    """Parse a VPR ``.place`` -> ``{block_name: (x, y)}`` for logic blocks."""
    pos: dict[str, tuple[int, int]] = {}
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith(("#", "Netlist_File", "Array size")):
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

_RE_FLE_IDX = re.compile(r"fle\[(\d+)\]")


def _fle_index(instance: str) -> int:
    m = _RE_FLE_IDX.search(instance)
    assert m is not None, f"cannot parse fle index from {instance!r}"
    return int(m.group(1))


def _fle_ff_used(fl: ET.Element) -> bool:
    """True if the fle's ble4[0]/ff[0] carries a real net (not 'open')."""
    ble4 = fl.find("./block[@instance='ble4[0]']")
    if ble4 is None:
        return False
    ff = ble4.find("./block[@instance='ff[0]']")
    if ff is None:
        return False
    return ff.get("name") != "open"


# =============================================================================
# v2c class-aware IIB pin assignment (frozen spec section 7.2, invariants R1-R3)
# =============================================================================
# The v2c IIB keeps ALL N=8 feedback entries on every mux (R1) but depopulates
# the external inputs BY PARITY: LUT-input mux m = gi*K + gk sees clb_in[i] only
# when i mod 2 == gk mod 2 (R2); each LUT has exactly K/2 = 2 pin slots per
# parity class (R3). VPR packs against the full-crossbar superset arch
# (section 7.6), so bitgen owns the class-aware pin assignment. The mapper's
# real freedoms (no re-pack, no re-route):
#   * LUT pin rotation        (the TT is re-permuted to match — permute_tt);
#   * cluster-pin permutation (any ext net may land on any clb.I[i] of a class);
#   * cluster-pin duplication (an ext net may land on ONE pin of EACH class —
#                              the router then just routes two sinks);
#   * don't-care drop         (a pin whose tied net is not a logical input is
#                              tied to feedback j=0 = sel 0 and the TT is
#                              replicated over it; it consumes no class slot).
# Reference: generated/icopt/route/iib_check.py (L1 backtracking), extended
# here with the duplication + don't-care-drop freedoms.

def _iib_class_options(nets: list[str], slots: int) -> list[tuple[tuple[str, int], ...]]:
    """All parity-class assignments of one LUT's ext nets, <= ``slots`` per class.

    Deterministic: class 0 is tried first for every net (sorted ``nets``).
    """
    opts: list[tuple[tuple[str, int], ...]] = []

    def rec(i: int, cur: list[tuple[str, int]], n0: int, n1: int) -> None:
        if i == len(nets):
            opts.append(tuple(cur))
            return
        net = nets[i]
        if n0 < slots:
            cur.append((net, 0))
            rec(i + 1, cur, n0 + 1, n1)
            cur.pop()
        if n1 < slots:
            cur.append((net, 1))
            rec(i + 1, cur, n0, n1 + 1)
            cur.pop()

    rec(0, [], 0, 0)
    return opts


def _solve_iib_classes(
    lut_ext: dict[int, list[str]],
    pin_budget: int = EXT_IN // 2,
    slots: int = K // 2,
) -> tuple[dict[tuple[int, str], int], dict[str, set[int]]] | None:
    """Exact parity-class assignment for one tile's external-input nets (R2/R3).

    Per LUT gi: its ext nets split across the two classes with at most
    ``slots`` (=2) per class. A net used by several LUTs may take DIFFERENT
    classes in different LUTs (pin duplication); each distinct (net, class)
    pair consumes one cluster pin of that parity (budget ``pin_budget`` = 9).
    Exact backtracking, most-constrained-LUT-first, fully deterministic.
    Returns ``({(gi, net): class}, {net: {classes}})`` or None if infeasible.
    """
    luts = sorted(lut_ext.items(), key=lambda kv: (len(kv[1]), kv[0]))
    net_classes: dict[str, set[int]] = {}
    budget = [pin_budget, pin_budget]
    assign: dict[tuple[int, str], int] = {}

    def bt(li: int) -> bool:
        if li == len(luts):
            return True
        gi, nets = luts[li]
        for opt in _iib_class_options(nets, slots):
            deltas: list[tuple[str, int]] = []
            pending = [0, 0]                     # pins this option would consume
            ok = True
            for net, c in opt:
                cs = net_classes.get(net)
                if cs is not None and c in cs:
                    continue                     # pin of this class already held
                if budget[c] - pending[c] < 1 or (cs is not None and len(cs) >= 2):
                    ok = False                   # no pin left / already duplicated
                    break
                pending[c] += 1
                deltas.append((net, c))
            if not ok:
                continue
            for net, c in deltas:
                net_classes.setdefault(net, set()).add(c)
                budget[c] -= 1
            for net, c in opt:
                assign[(gi, net)] = c
            if bt(li + 1):
                return True
            for net, _c in opt:
                del assign[(gi, net)]
            for net, c in reversed(deltas):
                budget[c] += 1
                s = net_classes[net]
                s.discard(c)
                if not s:
                    del net_classes[net]
        return False

    if bt(0):
        return assign, net_classes
    return None


def _iib_pins_of(net_classes: dict[str, set[int]]) -> dict[tuple[str, int], int]:
    """Assign concrete cluster pins: class c nets -> parity-c pins (sorted).

    Class 0 -> pins {0,2,..,16}; class 1 -> {1,3,..,17} (pin index = class, so
    ``pin mod 2 == class`` — the R2 reachability requirement).
    """
    pins: dict[tuple[str, int], int] = {}
    for c in (0, 1):
        nets_c = sorted(net for net, cs in net_classes.items() if c in cs)
        for n_pin, net in enumerate(nets_c):
            pins[(net, c)] = c + 2 * n_pin
    return pins


def _assign_lut_gk(
    gi: int,
    ext_nets: dict[str, int],
    fb_nets: dict[str, tuple[int, int]],
    classes: dict[tuple[int, str], int],
    pins: dict[tuple[str, int], int],
) -> list[tuple[str, int, str] | None]:
    """Physical pin map for one LUT: gk -> (kind, idx, net) | None (don't-care).

    Ext nets take the two pin slots of their assigned parity class (R3); the
    feedback nets fill the remaining slots (R1 — always legal); leftover slots
    are don't-care (tied to feedback j=0 = sel 0 by the caller, TT replicated).
    Deterministic (sorted nets; slots ascending).
    """
    gk_map: list[tuple[str, int, str] | None] = [None] * K
    for c, slot_pair in ((0, (0, 2)), (1, (1, 3))):
        nets_c = sorted(n for n in ext_nets if classes[(gi, n)] == c)
        assert len(nets_c) <= len(slot_pair), "solver produced an over-full class"
        for gk, net in zip(slot_pair, nets_c):
            gk_map[gk] = ("clb.I", pins[(net, c)], net)
    free = [gk for gk in range(K) if gk_map[gk] is None]
    fb_sorted = sorted(fb_nets.items(), key=lambda kv: (kv[1][0], kv[0]))
    assert len(fb_sorted) <= len(free), "feedback sources do not fit the free pins"
    for gk, (net, (j, _pos)) in zip(free, fb_sorted):
        gk_map[gk] = ("fle", j, net)
    return gk_map


def _fle_out_net(fl: ET.Element) -> str | None:
    """The net a fle's physical output drives (the name downstream sees).

    Combinational fle: the ``lut[0]`` leaf out-port net. FF-carrying fle:
    the FF's Q net — the ble4 out mux selects ff.Q, and VPR may rename the
    Q net to a buffer-absorbed alias (uart_loopback: BLIF latch ``rxs[1]``
    drives the identity buffer ``rx_stop``; VPR absorbs the buffer and
    names the Q port ``rx_stop``). This rule MUST stay identical to
    :func:`_build_tile` pass 1: ``build_db``'s ``driven`` set (and thus
    buffer-alias ``canon``) is built from it, and a name mismatch leaves
    the FF's sinks unrouted (E1-DMO1: 5 silently-unrouted uart_loopback
    cluster inputs read default tracks -> wrong sequential logic).
    """
    outnet: str | None = None
    lut = fl.find(".//block[@instance='lut[0]']")
    if lut is not None:
        outp = lut.find("./outputs/port[@name='out']")
        if outp is not None and outp.text:
            outnet = outp.text.strip()
    if _fle_ff_used(fl):
        ff = fl.find(".//block[@instance='ff[0]']")
        if ff is not None:
            qp = ff.find("./outputs/port[@name='Q']")
            if qp is not None and qp.text:
                outnet = qp.text.strip()
    return outnet


def _tile_output_nets(clb: ET.Element) -> set[str]:
    """The routed net names this clb block drives (mirrors _build_tile pass 1)."""
    out: set[str] = set()
    for fl in clb:
        if not (fl.get("instance", "").startswith("fle[") and fl.get("mode") == "n1_lut4"):
            continue
        name = _fle_out_net(fl)
        if name is not None:
            out.add(name)
    return out


def _buffer_classes(
    names: dict[str, tuple[list[str], list[tuple[str, int]]]],
) -> dict[str, list[str]]:
    """Equivalence classes of nets joined by identity (buffer) ``.names``.

    Yosys/abc emits single-input identity LUTs (cubes ``[("1", 1)]``) as
    net-name-preserving buffers (e.g. present_round's ``.names out[28]
    sboxed[49]``). VPR's packer ABSORBS them into the driving LUT and renames
    the LUT's output net to the buffer's downstream name — so the packed
    ``.net`` never mentions the pre-buffer net, while the BLIF truth tables
    still reference it. Every net in one class is guaranteed the same value;
    the class maps each member to the sorted member list (for deterministic
    representative choice in :func:`build_db`).
    """
    parent: dict[str, str] = {}

    def find(x: str) -> str:
        parent.setdefault(x, x)
        root = x
        while parent[root] != root:
            root = parent[root]
        while parent[x] != root:
            parent[x], x = root, parent[x]
        return root

    for out, (il, cubes) in names.items():
        if len(il) == 1 and cubes == [("1", 1)]:
            ra, rb = find(out), find(il[0])
            if ra != rb:
                parent[max(ra, rb)] = min(ra, rb)
    classes: dict[str, list[str]] = {}
    for net in parent:
        classes.setdefault(find(net), []).append(net)
    return {net: sorted(members) for members in classes.values() for net in members}


def _build_tile(clb: ET.Element,
                names: dict[str, tuple[list[str], list[tuple[str, int]]]],
                canon=lambda n: n) -> TileLogic:
    tile = TileLogic()
    tile.cluster_outputs = {k: None for k in range(N)}

    # pass 1: cluster_outputs[gi] from each used fle's lut[0] leaf out-net
    fles: list[tuple[int, ET.Element]] = []
    for fl in clb:
        if not (fl.get("instance", "").startswith("fle[") and fl.get("mode") == "n1_lut4"):
            continue
        gi = _fle_index(fl.get("instance", ""))
        fles.append((gi, fl))
        # The fle's physical output is the REGISTERED value when the ble4 out
        # mux selects ff.Q — the cluster output carries the FF's Q net (what
        # feedback, routing and PO taps must see), never the lut leaf's
        # PRE-edge D net. _fle_out_net owns that rule; _tile_output_nets
        # mirrors it so the driven-name set and the tile outputs agree
        # (E1-DMO1: VPR renames FF Q nets after absorbed buffers, e.g.
        # uart_loopback latch rxs[1] -> Q rx_stop).
        tile.cluster_outputs[gi] = _fle_out_net(fl)

    # this tile's own feedback producers: net -> fle j (a logical input driven
    # by one of THIS tile's LUTs is a feedback source; anything else is an
    # external cluster input).
    fb_of_net = {net: j for j, net in tile.cluster_outputs.items() if net is not None}

    # pass 2: per-LUT demands from the BLIF (the LOGICAL view). VPR's physical
    # pin choices are DISCARDED — the v2c solver below re-derives a class-legal
    # assignment per spec section 7.2 (R1-R3); the TTs are re-permuted to match.
    #
    # The LUT's FUNCTION (truth table + logical input list) is looked up by the
    # lut leaf's ATOM NAME (the block ``name=`` — the BLIF .names output), NOT
    # by the leaf out-port net: VPR buffer absorption renames the out-port to a
    # downstream buffer alias, so the out-port net's own .names entry can be a
    # 1-input identity buffer (wrong function). Demand nets are canonicalized
    # through the buffer-alias classes so producers renamed by absorption and
    # consumers referencing the pre-buffer name meet on the same net.
    demands: dict[int, dict] = {}
    for gi, fl in fles:
        dem: dict = {"ext": {}, "fb": {}, "input_list": [], "logical_tt": None}
        lut = fl.find(".//block[@instance='lut[0]']")
        func_net = lut.get("name") if lut is not None else None
        key = (func_net if func_net in names else tile.cluster_outputs.get(gi))
        if key is not None and key in names:
            input_list, cubes = names[key]
            dem["input_list"] = input_list
            dem["logical_tt"] = blif_names_to_logical_tt(input_list, cubes)
            for pos, net in enumerate(input_list):
                net = canon(net)
                j = fb_of_net.get(net)
                if j is not None:
                    dem["fb"][net] = (j, pos)
                else:
                    dem["ext"][net] = pos
        demands[gi] = dem

    # tile-level parity-class solve (exact; raises on an infeasible tile)
    lut_ext = {gi: sorted(d["ext"]) for gi, d in demands.items() if d["ext"]}
    solved = _solve_iib_classes(lut_ext)
    if solved is None:
        cname = clb.get("name", "?")
        raise RuntimeError(
            f"v2c IIB pin assignment INFEASIBLE for tile {cname}: "
            f"{sum(len(v) for v in lut_ext.values())} ext demands over "
            f"{len(lut_ext)} LUTs cannot be class-assigned "
            f"(slots/LUT/class={K // 2}, pin budget/class={EXT_IN // 2}) — "
            f"see spec section 7.2 R1-R3")
    classes, net_classes = solved
    pins = _iib_pins_of(net_classes)

    # rebuild cluster_inputs from the solver's pin assignment (net names are
    # design context, re-attached onto the class-legal pins).
    tile.cluster_inputs = {k: None for k in range(EXT_IN)}
    for (net, _c), pin in sorted(pins.items(), key=lambda kv: kv[1]):
        tile.cluster_inputs[pin] = net

    # per-LUT: physical pin map + v2c IIB sels + physically-permuted TT
    for gi, fl in fles:
        dem = demands[gi]
        gk_map = _assign_lut_gk(gi, dem["ext"], dem["fb"], classes, pins)
        pin_logpos: list[int | None] = [None] * K
        for gk, entry in enumerate(gk_map):
            if entry is None:
                tile.iib_mux[(gi, gk)] = 0            # don't-care: feedback j=0
                continue
            kind, idx, net = entry
            tile.iib_mux[(gi, gk)] = iib_sel_for(gi, gk, (kind, idx))
            # Logical position of this net in its .names block: the position
            # recorded at demand build — net names are canonicalized through
            # the buffer classes, so .index() on the raw input_list misses
            # (E1-DMO1: rxs[1] -> rx_stop).
            if net in dem["ext"]:
                pin_logpos[gk] = dem["ext"][net]
            else:
                pin_logpos[gk] = dem["fb"][net][1]

        phys_tt = 0
        logical_tt = dem["logical_tt"]
        if logical_tt is not None:
            n_in = len(dem["input_list"])
            if n_in == K:
                # full 4-input LUT: every pin carries a logical input
                assert all(p is not None for p in pin_logpos)
                phys_tt = permute_tt(logical_tt, [p for p in pin_logpos if p is not None])
            else:
                # sub-4-input LUT: EXPAND the logical TT into the 4-input
                # physical TT, REPLICATING over the don't-care pins (sel 0).
                phys_tt = _expand_logical_tt(logical_tt, n_in, pin_logpos)
        tile.eluts[gi] = ElutConfig(tt=phys_tt, ff_en=_fle_ff_used(fl))
    return tile


# =============================================================================
# Hard-cell (.net) parsing -> MaccCell / MemCell (Stage 5b, heterogeneous)
# =============================================================================

_RE_MULT = re.compile(r"mult_27x18\[\d+\]")
_RE_MEM = re.compile(r"mem_2Kx32\[\d+\]")


def _port_nets(block: ET.Element, port: str, direction: str) -> list[str]:
    """Return the ordered net names of a ``<port name=port>`` in ``direction``.

    ``direction`` is ``"inputs"`` or ``"outputs"``. Order is preserved
    (``A[0]`` first -> bit 0). ``open`` tokens are dropped (a hard cell's
    operand ports are always fully driven in the Stage-5b flows).
    """
    el = block.find(f"./{direction}/port[@name='{port}']")
    if el is None or not el.text:
        return []
    return [tok for tok in el.text.split() if tok != "open"]


def _parse_macc(block: ET.Element, tile: tuple[int, int]) -> MaccCell:
    """Capture a ``mult_27x18`` block into a MaccCell.

    The operand nets come from the nested ``mult_27x18_slice`` LEAF
    (``<port name="A/B">`` inputs, ``<port name="Y">`` outputs) — the leaf lists
    the actual routed nets (``A``/``B`` are the post-crossbar operands; ``Y``
    lists the output nets ``m[0..47]``). Falls back to the top-level block ports
    (``a``/``b``/``out``) if the slice is absent.
    """
    leaf = block.find(".//block[@instance='mult_27x18_slice[0]']")
    # Operand nets: the TOP-LEVEL block ports (``a``/``b``) carry the true routed
    # operand nets (a[0..26]/b[0..17]); the nested slice's ``A``/``B`` are VPR
    # crossbar-internal names (``mult_27x18.a[0]->a2a``). The OUTPUT nets come
    # from the slice leaf ``Y`` (the m[0..47] nets); the top-level ``out`` is the
    # post-crossbar form. Prefer top-level a/b, leaf Y, with mutual fallbacks.
    a = (_port_nets(block, "a", "inputs")
         or (_port_nets(leaf, "A", "inputs") if leaf is not None else []))
    b = (_port_nets(block, "b", "inputs")
         or (_port_nets(leaf, "B", "inputs") if leaf is not None else []))
    y = ((_port_nets(leaf, "Y", "outputs") if leaf is not None else [])
         or _port_nets(block, "out", "outputs"))
    return MaccCell(a_nets=a, b_nets=b, y_nets=y, tile=tile)


def _parse_mem(block: ET.Element, tile: tuple[int, int]) -> MemCell:
    """Capture a ``mem_2Kx32`` block into a MemCell (leaf slice preferred)."""
    leaf = block.find(".//block[contains(@instance,'mem_2Kx32') and @instance!='"
                    + block.get("instance", "") + "']")
    src = leaf if leaf is not None else block
    addr = (_port_nets(src, "addr", "inputs") or _port_nets(src, "ADDR", "inputs")
            or _port_nets(src, "A", "inputs"))
    din = (_port_nets(src, "data_in", "inputs") or _port_nets(src, "DIN", "inputs")
           or _port_nets(src, "D", "inputs"))
    we_l = (_port_nets(src, "we", "inputs") or _port_nets(src, "WE", "inputs")
            or _port_nets(src, "we_i", "inputs"))
    dout = (_port_nets(src, "data_out", "outputs")
            or _port_nets(src, "DOUT", "outputs") or _port_nets(src, "Q", "outputs"))
    return MemCell(addr_nets=addr, data_in_nets=din,
                   we_net=(we_l[0] if we_l else ""), data_out_nets=dout, tile=tile)


def build_db(net_path: str, place_path: str, blif_path: str) -> FabricConfigDB:
    """Parse (.net, .place, .blif) -> FabricConfigDB (LEVEL 1).

    Two passes over the clb blocks: (A) collect every routed net the packed
    design drives, so the buffer-alias classes (see :func:`_buffer_classes`)
    can canonicalize pre-buffer names to the name VPR actually routed;
    (B) build each tile's TileLogic with canonicalized demand nets. PO nets
    renamed by buffer absorption are recorded in ``db.po_aliases``.
    """
    names, primary_in, primary_out = parse_blif(blif_path)
    cluster_pos = parse_place(place_path)
    db = FabricConfigDB(primary_inputs=list(primary_in),
                        primary_outputs=list(primary_out))
    root = ET.parse(net_path).getroot()
    clb_blocks = [clb for clb in root
                  if clb.get("instance", "").startswith("clb[")
                  and clb.get("mode") == "default"]

    # pass A: driven routed nets (for buffer-alias canonicalization)
    driven: set[str] = set()
    for clb in clb_blocks:
        driven |= _tile_output_nets(clb)
    classes = _buffer_classes(names)
    pi_set = set(primary_in)

    def canon(net: str) -> str:
        """Map a net to the name the packed design actually uses for its value.

        Preference: the net itself when driven (or a primary input); else a
        class member that is a PI; else a driven class member; else the net.
        """
        if net in driven or net in pi_set:
            return net
        members = classes.get(net)
        if not members:
            return net
        for m in members:
            if m in pi_set:
                return m
        for m in members:
            if m in driven:
                return m
        return net

    # PO aliases: a PO net that no tile drives under its own name (buffer
    # absorption renamed it) is tapped through its driven class member.
    for p in primary_out:
        if p in driven:
            continue
        for m in classes.get(p, []):
            if m in driven:
                db.po_aliases[p] = m
                break

    for clb in root:
        inst = clb.get("instance", "")
        cname = clb.get("name")
        pos = cluster_pos.get(cname) if cname is not None else None
        if inst.startswith("clb[") and clb.get("mode") == "default":
            if pos is None:
                continue
            db.tiles[pos] = _build_tile(clb, names, canon)
        elif _RE_MULT.fullmatch(inst):
            # DSP hard cell ($macc_v2 -> mult_27x18). .place key = block name.
            if pos is not None:
                db.macc_cells[pos] = _parse_macc(clb, pos)
        elif _RE_MEM.fullmatch(inst):
            # MEM hard cell ($mem_v2 -> mem_2Kx32).
            if pos is not None:
                db.mem_cells[pos] = _parse_mem(clb, pos)
    return db
