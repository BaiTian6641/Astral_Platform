# SPDX-License-Identifier: MIT
"""fabric_sim_het — heterogeneous (mem_t / dsp_t) tile models + a netlist-level
heterogeneous evaluator (task E0-MAP3 / C02 Phase-1 heterogeneous extension).

Plan-Ref: ethereal-plan/components/C02-fabric-异构tile.md §1/§2 (mem_t / dsp_t) +
          C-soft-工具与固件组件.md §2 (the fabric_sim capstone, het extension).

==============================================================================
WHAT THIS MODELS (and what it deliberately does NOT)
==============================================================================
This module closes the FUNCTIONAL loop on the Phase-1 heterogeneous tiles by
modelling the **tile semantics** of ``mem_t`` (virtual RAM / ROM) and ``dsp_t``
(virtual signed MAC) faithfully against their RTL ground truth
(``ethereal-fabric/rtl/tile/mem_t.sv`` + ``eth_inf_ram.sv`` and
``rtl/tile/dsp_t.sv`` + ``eth_inf_dsp_mac.sv``), and running the two C02 §2.6
heterogeneous benchmarks — **fir16_dsp** (a 16-deep dsp_t MAC cascade) and
**aes128_round** (16 mem_t S-box ROMs + eLUT MixColumns/AddRoundKey glue) —
**bit-true** against independent iverilog goldens of the SAME Verilog sources.

**The boundary (honest scope statement, G6).** The full *routed* heterogeneous
circuit (synth -> VPR het-arch pack/place -> het bitgen -> tile data flowing
through the Wilton SB/CB interconnect into the CLBs) is NOT built yet: the
Stage-5b het path uses host-constant operands (``bitgen_het`` drives ``va_i`` /
``vb_i`` / the ROM word as vbus-ctrl config, see its module docstring), and the
vbus->routing integration that would carry tile data through the fabric
interconnect is a Stage-6 follow-up. So this module does NOT attempt to route a
heterogeneous grid. Instead it proves the layer that IS the new risk in Phase-1:
**the mem_t / dsp_t tile semantics themselves**. Two provable formulations:

  * :class:`MemTileModel` / :class:`DspTileModel` — cycle/functional models of
    the two tiles, validated by unit tests against the RTL semantics.
  * :class:`HetCircuitSim` — a combinational evaluator over the heterogeneous
    synth netlist (Yosys BLIF ``.names`` eLUT glue + ``$mem_v2`` / ``$macc_v2``
    hard cells), reusing the exact TT convention of ``fabric_sim.clb_eval_bits``
    for the LUT glue and the tile models above for the hard cells. This proves
    the AES S-box-on-mem_t + CLB-glue and the FIR macc-cascade compute the same
    function as the iverilog golden — i.e. the tiles compute correctly when
    driven as the circuit intends.

==============================================================================
TILE SEMANTICS IMPLEMENTED (mirrors the RTL exactly)
==============================================================================

``mem_t`` (``MemTileModel``) — ``eth_inf_ram``:
  * synchronous, **read-first** read: on an enabled clock edge the OLD
    ``mem[addr]`` is registered onto ``vd_o`` before any write to that address.
  * **no reset** on the array (resets block BRAM inference, C13 §2.2).
  * per-byte write-enable ``vwe_i[3:0]`` (only enabled bytes are written).
  * optional ROM preload ``init`` = ``{addr: word}`` (the ``INIT_HEX`` path —
    for the AES S-box the mem is a 256x8 ROM with RD_CLK_ENABLE=0, i.e. a pure
    combinational ROM; :meth:`MemTileModel.read_comb` models that read).

``dsp_t`` (``DspTileModel``) — ``eth_inf_dsp_mac`` (signed 27x18, 48-bit acc):
  * three always-built pipeline stages (input regs / multiply / accumulate),
    synchronous **reset-to-0-only**, ``en`` clock-enable.
  * ``acc_i``: 1 = ``p += a*b`` (MAC), 0 = ``p = a*b + c`` (MULT + cascade add).
  * ``lat_sel_i`` output tap: 0 = combinational bypass ``a*b+c``; 1 = mult-stage
    ``mult+c``; 2/3 = the accumulating out-stage ``p_r``.
  * :meth:`DspTileModel.eval` returns the *functional value* (the registered
    cascade result) — for the bit-true functional check the VALUE is what
    matters (latency is a timing property, exercised separately).
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field

# -- sys.path bootstrap (mirrors fabric_sim.py): bench_golden / bitgen_db live --
# -- in THIS dir.                                                              --
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)


# =============================================================================
# Signed helpers (27x18 -> 48-bit two's-complement, mirrors eth_inf_dsp_mac)
# =============================================================================

def _to_signed(value: int, width: int) -> int:
    """Interpret the low ``width`` bits of ``value`` as a signed integer."""
    value &= (1 << width) - 1
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def _to_unsigned48(value: int) -> int:
    """Wrap an integer to the 48-bit two's-complement output width (mod 2**48)."""
    return value & ((1 << 48) - 1)


# =============================================================================
# mem_t model (eth_inf_ram: sync read-first RAM / ROM preload)
# =============================================================================

@dataclass
class MemTileModel:
    """Functional model of ``mem_t`` / ``eth_inf_ram`` (C02 §1).

    ``depth`` x ``width`` words; ``init`` is a ``{addr: word}`` ROM preload (the
    S-box content for AES). The synchronous-read semantics is read-first: a
    clocked :meth:`tick` registers the OLD addressed word onto ``vd_o`` (and
    applies an enabled write). :meth:`read_comb` is the ROM path (RD_CLK_ENABLE=0
    in the AES synth — the S-box is a pure combinational ROM lookup).
    """

    depth: int = 1 << 11          # AW=11 -> 2^11 x 32 (mem_t default)
    width: int = 32
    init: dict[int, int] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self._mem: list[int] = [0] * self.depth
        self._mask = (1 << self.width) - 1
        for addr, word in self.init.items():
            if not (0 <= addr < self.depth):
                raise ValueError(f"mem init addr {addr} out of range 0..{self.depth - 1}")
            self._mem[addr] = word & self._mask
        self.vd_o: int = 0        # registered read output (sync-read)

    @property
    def _nbytes(self) -> int:
        return self.width // 8

    def read_comb(self, addr: int) -> int:
        """Combinational ROM read (RD_CLK_ENABLE=0 S-box path): mem[addr] now."""
        return self._mem[addr & (self.depth - 1)]

    def tick(self, addr: int, wdata: int = 0, we: int = 0, en: bool = True) -> int:
        """One enabled clock edge of the synchronous RAM.

        Read-first: the OLD ``mem[addr]`` is captured onto ``vd_o`` and returned;
        then the per-byte write applies. ``we`` is the 4-bit (``_nbytes``-bit)
        byte-enable; ``en`` gates the whole edge (power, C02 §1.3).
        """
        addr &= self.depth - 1
        if en:
            old = self._mem[addr]
            self.vd_o = old                       # read-first: OLD value
            if we:
                word = self._mem[addr]
                for b in range(self._nbytes):
                    if (we >> b) & 1:
                        lo = b * 8
                        word = (word & ~(0xFF << lo)) | (((wdata >> lo) & 0xFF) << lo)
                self._mem[addr] = word & self._mask
        return self.vd_o


# =============================================================================
# dsp_t model (eth_inf_dsp_mac: signed 27x18 MAC + accumulate + latency tap)
# =============================================================================

@dataclass
class DspTileModel:
    """Functional model of ``dsp_t`` / ``eth_inf_dsp_mac`` (C02 §2).

    Signed 27x18 operands, 48-bit cascade/accumulate. ``eval`` returns the
    *functional* MAC result (what the registered cascade computes): for
    ``acc=False`` this is ``a*b + c``; for ``acc=True`` it accumulates
    (``p += a*b``) across successive calls. ``tick`` advances the pipeline
    model (used by the latency unit test); ``p_o(lat_sel)`` reads the tapped
    output stage exactly as ``eth_inf_dsp_mac`` does.
    """

    acc: bool = False
    # pipeline state (mirrors eth_inf_dsp_mac stage regs)
    _a_r: int = 0
    _b_r: int = 0
    _c_r: int = 0
    _acc_r: int = 0
    _mult_r: int = 0
    _c_r2: int = 0
    _acc_r2: int = 0
    _p_r: int = 0

    AW: int = 27
    BW: int = 18

    def _product(self, a: int, b: int) -> int:
        return _to_signed(a, self.AW) * _to_signed(b, self.BW)

    def eval(self, a: int, b: int, c: int = 0) -> int:
        """Functional MAC value (mod 2**48).

        ``acc=False`` -> ``a*b + c``; ``acc=True`` -> accumulate into the
        running accumulator (``p = p + a*b``). This is the VALUE the cascade
        settles to (latency-agnostic), which is what a bit-true functional
        check compares.
        """
        prod = self._product(a, b)
        if self.acc:
            self._p_r = _to_unsigned48(_to_signed(self._p_r, 48) + prod)
            return self._p_r
        return _to_unsigned48(prod + _to_signed(c, 48))

    def reset(self) -> None:
        """Synchronous reset-to-0 (the only allowed reset value, C13 §2.1)."""
        self._a_r = self._b_r = self._c_r = 0
        self._acc_r = 0
        self._mult_r = self._c_r2 = self._acc_r2 = 0
        self._p_r = 0

    def tick(self, a: int, b: int, c: int, acc: bool, en: bool = True) -> None:
        """Advance the 3-stage pipeline one enabled clock edge (timing model).

        Mirrors ``eth_inf_dsp_mac``'s always_ff blocks: stage1 input regs,
        stage2 multiply, stage3 accumulate/add (reset-to-0-only, CE-gated).
        """
        if not en:
            return
        # stage 1: input registers
        self._a_r = _to_signed(a, self.AW)
        self._b_r = _to_signed(b, self.BW)
        self._c_r = _to_signed(c, 48)
        self._acc_r = 1 if acc else 0
        # stage 2: multiply (registered)
        self._mult_r = _to_unsigned48(self._a_r * self._b_r)
        self._c_r2 = _to_unsigned48(self._c_r)
        self._acc_r2 = self._acc_r
        # stage 3: accumulate / add (registered, reset-to-0 only)
        if self._acc_r2:
            self._p_r = _to_unsigned48(_to_signed(self._p_r, 48)
                                       + _to_signed(self._mult_r, 48))
        else:
            self._p_r = _to_unsigned48(_to_signed(self._mult_r, 48)
                                       + _to_signed(self._c_r2, 48))

    def p_o(self, lat_sel: int, a: int, b: int, c: int) -> int:
        """Read the tapped output stage (``lat_sel`` 0/1/2/3) — mirrors the RTL.

        0 -> combinational bypass ``a*b + c``; 1 -> mult-stage ``mult + c``;
        2/3 -> the accumulating out-stage register ``p_r``.
        """
        if lat_sel == 0:
            return _to_unsigned48(self._product(a, b) + _to_signed(c, 48))
        if lat_sel == 1:
            return _to_unsigned48(_to_signed(self._mult_r, 48)
                                  + _to_signed(self._c_r2, 48))
        return self._p_r


# =============================================================================
# Heterogeneous netlist evaluator (BLIF .names glue + $mem_v2 / $macc_v2)
# =============================================================================
#
# The evaluator reuses fabric_sim's TT convention for the eLUT glue: a BLIF
# ``.names`` cube list -> a logical TT via ``blif_names_to_logical_tt`` (MSB-
# first), evaluated combinationally. The hard cells are driven through the tile
# models above. Everything is combinational here (the AES S-box is a ROM; the
# CLB glue is LUT logic), so a Gauss-Seidel fixpoint mirrors fabric_sim.

@dataclass
class _MaccInst:
    """A ``$macc_v2`` instance captured from the het BLIF (signed, per params)."""

    a_nets: list[str]
    b_nets: list[str]
    c_nets: list[str]
    y_nets: list[str]
    a_signed: bool = True
    b_signed: bool = True
    c_signed: bool = True


@dataclass
class _MemInst:
    """A ``$mem_v2`` instance captured from the het BLIF (single read port ROM)."""

    rd_addr_nets: list[str]
    rd_data_nets: list[str]
    init: dict[int, int]              # ROM preload {addr: word}
    width: int = 8


def _decode_init_msb(init_str: str, width: int, size: int) -> dict[int, int]:
    """Decode a Yosys ``$mem_v2`` INIT parameter into ``{addr: word}``.

    Yosys emits ``INIT`` as a flat binary string, **most-significant word
    first**: the LAST ``width`` characters are word 0, the preceding ``width``
    are word 1, etc. (verified against the AES S-box: word 0..7 decode to
    ``63 7c 77 7b f2 6b 6f c5``). Within a word the rightmost char is bit 0.
    """
    bits = init_str.strip()
    out: dict[int, int] = {}
    n = len(bits)
    for addr in range(size):
        word = 0
        for b in range(width):
            idx = n - 1 - (addr * width + b)
            if idx >= 0 and bits[idx] == "1":
                word |= 1 << b
        out[addr] = word
    return out


class HetCircuitSim:
    """Combinational evaluator over a heterogeneous synth BLIF netlist.

    Parses the ``.names`` eLUT glue + the ``.subckt $mem_v2`` / ``.subckt
    $macc_v2`` hard cells, then evaluates the whole circuit to a combinational
    fixpoint under a primary-input dict (the same ``{net: bit}`` convention as
    ``FabricSim.evaluate``). Constants ``$false`` / ``$true`` / ``$undef`` are
    pinned to 0 / 1 / 0. Returns the ``{po_net: bit}`` dict.
    """

    def __init__(self, blif_path: str) -> None:
        self.blif_path = blif_path
        # LUT glue: net -> (input_list, cubes)  (from bitgen_db.parse_blif)
        from bitgen_db import blif_names_to_logical_tt, parse_blif
        names, self.primary_inputs, self.primary_outputs = parse_blif(blif_path)
        # precompute each LUT's logical TT (MSB-first convention)
        self._lut_tt: dict[str, int] = {}
        self._lut_inputs: dict[str, list[str]] = {}
        for out_net, (in_list, cubes) in names.items():
            self._lut_inputs[out_net] = in_list
            self._lut_tt[out_net] = blif_names_to_logical_tt(in_list, cubes)
        # hard cells
        self._maccs, self._mems = self._parse_hard_cells(blif_path)

    # ------------------------------------------------------------------
    # BLIF hard-cell parsing
    # ------------------------------------------------------------------
    @staticmethod
    def _parse_hard_cells(blif_path: str) -> tuple[list[_MaccInst], list[_MemInst]]:
        maccs: list[_MaccInst] = []
        mems: list[_MemInst] = []

        def _ports(tok: str) -> tuple[str, int, str]:
            # "A[3]=net" -> ("A", 3, "net")
            lhs, net = tok.split("=", 1)
            port = lhs[: lhs.index("[")] if "[" in lhs else lhs
            idx = int(lhs[lhs.index("[") + 1: lhs.index("]")]) if "[" in lhs else 0
            return port, idx, net

        with open(blif_path, encoding="utf-8") as fh:
            logical = "".join(
                line.rstrip("\n") if not line.rstrip("\n").endswith("\\")
                else line.rstrip("\n")[:-1]
                for line in fh)
        for stmt in logical.split("\n"):
            stmt = stmt.strip()
            if stmt.startswith(".subckt $macc_v2"):
                toks = stmt.split()[2:]
                a: dict[int, str] = {}
                b: dict[int, str] = {}
                c: dict[int, str] = {}
                y: dict[int, str] = {}
                for tok in toks:
                    port, idx, net = _ports(tok)
                    if port == "A":
                        a[idx] = net
                    elif port == "B":
                        b[idx] = net
                    elif port == "C":
                        c[idx] = net
                    elif port == "Y":
                        y[idx] = net
                maccs.append(_MaccInst(
                    a_nets=[a[i] for i in sorted(a)],
                    b_nets=[b[i] for i in sorted(b)],
                    c_nets=[c[i] for i in sorted(c)],
                    y_nets=[y[i] for i in sorted(y)]))
            elif stmt.startswith(".subckt $mem_v2"):
                toks = stmt.split()[2:]
                rd_addr: dict[int, str] = {}
                rd_data: dict[int, str] = {}
                params: dict[str, str] = {}
                for tok in toks:
                    if "=" not in tok:
                        continue
                    key, val = tok.split("=", 1)
                    if key.startswith("RD_ADDR"):
                        idx = int(key[key.index("[") + 1: key.index("]")])
                        rd_addr[idx] = val
                    elif key.startswith("RD_DATA"):
                        idx = int(key[key.index("[") + 1: key.index("]")])
                        rd_data[idx] = val
                    elif key.isupper() and "[" not in key:
                        params[key] = val
                width = len(rd_data)
                size = 1 << len(rd_addr)
                init = _decode_init_msb(params.get("INIT", ""), width, size) \
                    if params.get("INIT") else {}
                mems.append(_MemInst(
                    rd_addr_nets=[rd_addr[i] for i in sorted(rd_addr)],
                    rd_data_nets=[rd_data[i] for i in sorted(rd_data)],
                    init=init, width=width))
        return maccs, mems

    # ------------------------------------------------------------------
    # Combinational evaluation
    # ------------------------------------------------------------------
    def _gather(self, nets: list[str], values: dict[str, int]) -> int:
        word = 0
        for i, net in enumerate(nets):
            word |= (values.get(net, 0) & 1) << i
        return word

    def evaluate(self, pi_values: dict[str, int], max_iters: int = 64) -> dict[str, int]:
        """Evaluate the circuit under ``pi_values`` -> ``{po_net: bit}``.

        Deterministic Gauss-Seidel fixpoint over the LUT glue + hard cells.
        Combinational (the S-box ROM is read combinationally; the MACs here are
        used as combinational MULT+add in the cascade-unrolled netlist).
        """
        values: dict[str, int] = {"$false": 0, "$true": 1, "$undef": 0}
        values.update({net: bit & 1 for net, bit in pi_values.items()})

        lut_outs = list(self._lut_inputs)
        for _ in range(max_iters):
            changed = False
            # eLUT glue (MSB-first TT: input_list[0] = bit n-1)
            for out_net in lut_outs:
                in_list = self._lut_inputs[out_net]
                n = len(in_list)
                idx = 0
                for k, inp in enumerate(in_list):
                    idx |= (values.get(inp, 0) & 1) << (n - 1 - k)
                bit = (self._lut_tt[out_net] >> idx) & 1
                if values.get(out_net, 0) != bit:
                    values[out_net] = bit
                    changed = True
            # mem_t ROMs (combinational S-box read)
            for mem in self._mems:
                addr = self._gather(mem.rd_addr_nets, values)
                word = mem.init.get(addr, 0)
                for i, net in enumerate(mem.rd_data_nets):
                    bit = (word >> i) & 1
                    if values.get(net, 0) != bit:
                        values[net] = bit
                        changed = True
            # dsp_t MACs (combinational MULT + cascade add: acc=False)
            for mc in self._maccs:
                a = self._gather(mc.a_nets, values)
                b = self._gather(mc.b_nets, values)
                c = self._gather(mc.c_nets, values)
                y = _to_unsigned48(
                    (_to_signed(a, len(mc.a_nets)) * _to_signed(b, len(mc.b_nets)))
                    + _to_signed(c, len(mc.c_nets) if mc.c_nets else 48))
                for i, net in enumerate(mc.y_nets):
                    bit = (y >> i) & 1
                    if values.get(net, 0) != bit:
                        values[net] = bit
                        changed = True
            if not changed:
                break
        return {net: values.get(net, 0) & 1 for net in self.primary_outputs}


# =============================================================================
# fir16 dsp-cascade evaluator (16-deep dsp_t MAC chain)
# =============================================================================

def fir16_dsp_eval(taps: list[int], coeffs: list[int]) -> int:
    """Functional model of ``fir16_dsp`` as a 16-deep dsp_t MAC cascade.

    ``taps[k]`` (8-bit signed) x ``coeffs[k]`` (16-bit signed); the cascade is
    ``acc[0] = x[0]*h[0]``, ``acc[k] = acc[k-1] + x[k]*h[k]``; ``y = acc[15]``.
    Each MAC is a dsp_t (signed multiply + cascade-add, ``acc=False`` with the
    previous accumulator on the cascade-in port). Returns the 48-bit result.
    """
    if len(taps) != 16 or len(coeffs) != 16:
        raise ValueError("fir16_dsp_eval expects 16 taps + 16 coeffs")
    acc = 0
    for k in range(16):
        m = DspTileModel(acc=False)
        acc = m.eval(taps[k], coeffs[k], acc)
    return acc
