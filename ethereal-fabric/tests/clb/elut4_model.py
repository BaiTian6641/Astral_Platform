# SPDX-License-Identifier: MIT
"""Golden reference model for the ``elut4`` virtual LUT4 + FF (task E0-FAB1).

Mirrors ``ethereal-fabric/rtl/clb/elut4.sv`` bit-for-bit so cocotb tests can
compare the DUT against this model. Configuration bitfield (20-bit) follows
``C01 §1.3`` concatenation order ``{tt[15:0], ff_en, ff_rst_en, ff_rst_val,
out_inv}``::

    [19:4] = tt[15:0]   truth table
    [3]    = ff_en      register the LUT output
    [2]    = ff_rst_en  user reset affects the virtual FF
    [1]    = ff_rst_val value loaded on reset
    [0]    = out_inv    invert the output

Semantics (identical to the RTL)::

    comb_out = tt[vin]                                 # 16:1 mux
    if ff_rst_en and not rst_n:  vff = ff_rst_val      # sync reset, priority over CE
    elif ce:                     vff = comb_out
    mux  = vff if ff_en else comb_out
    vout = out_inv ^ mux                              # optional invert

This module is pure Python (no cocotb dependency) so it can be unit-tested with
pytest *locally* — independently of the Docker/Verilator toolchain.
"""
from __future__ import annotations

from dataclasses import dataclass

TT_WIDTH = 16
CFG_WIDTH = 20
VIN_MASK = (1 << 4) - 1  # 0xF


@dataclass
class Elut4Config:
    """Frozen v1 eLUT4 configuration (see C01 §1.3)."""

    tt: int = 0          # 16-bit truth table
    ff_en: int = 0       # 1-bit
    ff_rst_en: int = 0   # 1-bit
    ff_rst_val: int = 0  # 1-bit
    out_inv: int = 0     # 1-bit

    def __post_init__(self) -> None:
        self.tt = self.tt & 0xFFFF
        self.ff_en = self.ff_en & 1
        self.ff_rst_en = self.ff_rst_en & 1
        self.ff_rst_val = self.ff_rst_val & 1
        self.out_inv = self.out_inv & 1

    def to_word(self) -> int:
        """Pack into the 20-bit cfg_data_i word (RTL bitfield order)."""
        w = (self.tt & 0xFFFF) << 4
        w |= (self.ff_en & 1) << 3
        w |= (self.ff_rst_en & 1) << 2
        w |= (self.ff_rst_val & 1) << 1
        w |= self.out_inv & 1
        return w

    @classmethod
    def from_word(cls, word: int) -> "Elut4Config":
        word &= (1 << CFG_WIDTH) - 1
        return cls(
            tt=(word >> 4) & 0xFFFF,
            ff_en=(word >> 3) & 1,
            ff_rst_en=(word >> 2) & 1,
            ff_rst_val=(word >> 1) & 1,
            out_inv=word & 1,
        )


class Elut4:
    """Cycle-accurate reference model.

    State = configuration (persists across user reset) + ``vff`` (the virtual FF).
    Call :meth:`configure` to load a config word, then :meth:`clock` per fabric
    clock edge; :meth:`clock` returns ``vout_o`` *after* the edge.
    """

    def __init__(self, config: Elut4Config | None = None) -> None:
        self.config: Elut4Config = config if config is not None else Elut4Config()
        self.vff: int = 0

    def configure(self, word: int) -> None:
        self.config = Elut4Config.from_word(word)

    def comb_out(self, vin: int) -> int:
        """Combinational LUT4 output = truth-table bit addressed by vin."""
        return (self.config.tt >> (vin & VIN_MASK)) & 1

    def clock(self, vin: int, rst_n: int = 1, ce: int = 1) -> int:
        """Advance one clock edge and return vout_o after the edge."""
        comb = self.comb_out(vin)
        if self.config.ff_rst_en and not rst_n:
            self.vff = self.config.ff_rst_val
        elif ce:
            self.vff = comb
        mux = self.vff if self.config.ff_en else comb
        return (self.config.out_inv ^ mux) & 1
