# SPDX-License-Identifier: MIT
"""Golden reference model for ``clb_t`` — the CLB tile (task E0-FAB2).

Mirrors ``ethereal-fabric/rtl/clb/clb_t.sv`` bit-for-bit. N eLUT4 (reusing
``elut4_model.Elut4``) fed by an IIB full-input crossbar: each of the N*K LUT
inputs is a mux selecting any of the I = EXT_IN + N cluster inputs (external +
N feedback). The N LUT outputs feed back into the pool, so the network may
contain combinational feedback (legal virtual logic); :meth:`settle` does a
fixed-point iteration that converges for acyclic configs and raises for a
genuine combinational loop.

cfg addressing (frozen v1, C01 §2.3)::
    addr 0..N-1      -> eLUT4 #(addr): cfg_data[19:0]
    addr N..N+N*K-1  -> IIB mux #(addr-N): cfg_data[SELW-1:0]

Pure Python (no cocotb) -> unit-testable locally with pytest.
"""
from __future__ import annotations

from elut4_model import Elut4

CFG_ADDR_WIDTH = 6
ELUT_WORD_WIDTH = 20


def _next_pow2(n: int) -> int:
    return 1 << max(1, (n - 1).bit_length()) if n > 1 else 1


class ClbT:
    """Cycle-accurate CLB reference model (v1 params N=8, K=4, EXT_IN=18)."""

    def __init__(self, N: int = 8, K: int = 4, EXT_IN: int = 18) -> None:
        self.N, self.K, self.EXT_IN = N, K, EXT_IN
        self.I = EXT_IN + N
        self.NK = N * K
        self.POOL = _next_pow2(self.I)           # 32 for I=26
        self.SELW = self.POOL.bit_length() - 1   # 5
        self.eluts: list[Elut4] = [Elut4() for _ in range(N)]
        self.mux_sel: list[int] = [0] * self.NK  # one pool-index per LUT input
        self.clb_out: list[int] = [0] * N        # current LUT outputs

    # -- bounds -------------------------------------------------------------
    @property
    def lut_end(self) -> int:
        return self.N

    @property
    def mux_end(self) -> int:
        return self.N + self.NK

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> "ClbT":
        addr &= (1 << CFG_ADDR_WIDTH) - 1
        if addr < self.N:
            self.eluts[addr].configure(data & ((1 << ELUT_WORD_WIDTH) - 1))
        elif addr < self.mux_end:
            self.mux_sel[addr - self.N] = data & (self.POOL - 1)
        # addresses >= mux_end are reserved/ignored
        return self

    def configure_elut(self, lut: int, word: int) -> "ClbT":
        self.eluts[lut].configure(word)
        return self

    def route(self, lut: int, pin: int, source: int) -> "ClbT":
        """Route cluster-input `source` to LUT `lut` input `pin` (sets one mux)."""
        self.mux_sel[lut * self.K + pin] = source & (self.POOL - 1)
        return self

    # -- combinational evaluation ------------------------------------------
    def _pool(self, ext_in) -> list[int]:
        if isinstance(ext_in, int):
            ext = [(ext_in >> i) & 1 for i in range(self.EXT_IN)]
        else:
            ext = [int(v) & 1 for v in ext_in]
        pool = ext + [self.clb_out[i] for i in range(self.N)]
        pool += [0] * (self.POOL - self.I)
        return pool

    def _lut_vin(self, i: int, pool: list[int]) -> int:
        vin = 0
        base = i * self.K
        for k in range(self.K):
            sel = self.mux_sel[base + k]
            bit = pool[sel] if 0 <= sel < self.POOL else 0
            vin |= (bit & 1) << k
        return vin

    def settle(self, ext_in, max_iter: int | None = None) -> list[int]:
        """Fixed-point settle of the combinational network (vff held). Returns pool.

        Raises RuntimeError if it does not converge (a genuine combinational
        loop in the configured network)."""
        if max_iter is None:
            max_iter = self.N + 2
        pool = self._pool(ext_in)
        for _ in range(max_iter):
            changed = False
            vins = [self._lut_vin(i, pool) for i in range(self.N)]
            for i in range(self.N):
                comb = self.eluts[i].comb_out(vins[i])
                vout = self.eluts[i].vff if self.eluts[i].config.ff_en else comb
                if vout != self.clb_out[i]:
                    self.clb_out[i] = vout
                    changed = True
            if not changed:
                return self._pool(ext_in)
            pool = self._pool(ext_in)
        raise RuntimeError("CLB combinational loop did not settle (virtual comb loop)")

    def outputs(self, ext_in) -> list[int]:
        """Settled combinational outputs (no clock advance)."""
        self.settle(ext_in)
        return list(self.clb_out)

    def clock(self, ext_in, rst_n: int = 1) -> list[int]:
        """Advance one fabric clock edge; return settled clb_out after the edge."""
        pool = self.settle(ext_in)                       # settle with vff held
        vins = [self._lut_vin(i, pool) for i in range(self.N)]
        for i in range(self.N):                          # latch FFs (CLB-level ce=1)
            self.eluts[i].clock(vins[i], rst_n=rst_n, ce=1)
        self.settle(ext_in)                              # re-settle with new vff
        return list(self.clb_out)

    def clb_out_word(self) -> int:
        w = 0
        for i in range(self.N):
            w |= (self.clb_out[i] & 1) << i
        return w
