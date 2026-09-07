# SPDX-License-Identifier: MIT
"""Golden reference model for ``clb_t`` — the CLB tile (task E0-FAB2).

Mirrors ``ethereal-fabric/rtl/clb/clb_t.sv`` bit-for-bit (interconnect **v2c**,
frozen spec ``interconnect-config-v0.md`` §7.2, E2-FAB5). N eLUT4 (reusing
``elut4_model.Elut4``) fed by the v2c IIB — a **feedback-first depopulated
crossbar**: every LUT-input mux keeps ALL N=8 feedback entries; only the
EXT_IN=18 external inputs are depopulated **by parity**. The N LUT outputs
feed back into the pool, so the network may contain combinational feedback
(legal virtual logic); :meth:`settle` does a fixed-point iteration that
converges for acyclic configs and raises for a genuine combinational loop.

Pool reorganization (v2c §7.2 — slice-only select encoding, no adders)::

    pool[17:0]  = clb_in_i          (external inputs)
    pool[23:18] = 0                 (padding)
    pool[31:24] = clb_out_o         (feedback j at pool[24+j])

Mux classes: LUT-input mux ``m = gi*K + gk`` (gi = 0..7 LUT, gk = 0..3 pin;
m = 0..31) has ext parity class ``pi(m) = m mod 2 = gk mod 2`` (K=4 even).
Even-gk pins see even external inputs {0,2,..,16}; odd-gk pins see
{1,3,..,17}. All 8 feedback entries are visible to every mux.

Select encoding (5 bits, pure bit-slicing)::

    sel[4]=1 -> external input pool[{sel[3:0], pi(m)}] = 2*sel[3:0] + pi(m)
                (legal sel[3:0] = 0..8; 9..15 read padding/fb = reserved,
                MUST NOT be programmed — this model reads the pool, where the
                padding is 0)
    sel[4]=0 -> feedback pool[{2'b11, sel[2:0]}] = 24 + j   (sel[3] don't-care)
    sel = 0 (blank/zero-init) = feedback j=0 (v2c §7.7; was clb_in[0] in v1.1)

Reachability invariants (§7.2, the mapper's pin-assignment contract):
**R1** every feedback j reaches every LUT input; **R2** ext pin i reaches LUT
gi only through its two pins gk in {0,2} (i even) or {1,3} (i odd); **R3**
within one LUT, each parity class has exactly 2 pin slots.

cfg addressing (frozen v1, C01 §2.3; count + addressing unchanged in v2c)::
    addr 0..N-1      -> eLUT4 #(addr): cfg_data[19:0]
    addr N..N+N*K-1  -> IIB mux #(addr-N): cfg_data[SELW-1:0] (v2c encoding)

Pure Python (no cocotb) -> unit-testable locally with pytest.
"""
from __future__ import annotations

from elut4_model import Elut4

CFG_ADDR_WIDTH = 6
ELUT_WORD_WIDTH = 20


class ClbT:
    """Cycle-accurate CLB reference model (v1 params N=8, K=4, EXT_IN=18; v2c IIB)."""

    def __init__(self, N: int = 8, K: int = 4, EXT_IN: int = 18) -> None:
        self.N, self.K, self.EXT_IN = N, K, EXT_IN
        self.I = EXT_IN + N
        self.NK = N * K
        self.POOL = 32                         # v2c: ext[0..17] pad[18..23] fb[24..31]
        self.FB_BASE = 24                      # feedback j at pool[24+j] (v2c §7.2)
        self.SELW = 5
        self.eluts: list[Elut4] = [Elut4() for _ in range(N)]
        self.mux_sel: list[int] = [0] * self.NK  # one v2c sel per LUT input
        self.clb_out: list[int] = [0] * N        # current LUT outputs

    # -- bounds -------------------------------------------------------------
    @property
    def lut_end(self) -> int:
        return self.N

    @property
    def mux_end(self) -> int:
        return self.N + self.NK

    # -- v2c IIB select helpers (§7.2) --------------------------------------
    @staticmethod
    def parity(gk: int) -> int:
        """Ext parity class of LUT pin ``gk`` (pi(m) = m mod 2 = gk mod 2)."""
        return gk & 1

    def sel_ext(self, gk: int, i: int) -> int:
        """v2c sel reading external input ``i`` (0..EXT_IN-1) from pin ``gk``.

        Raises ValueError on a parity violation (R2: pin ``gk`` only sees
        external inputs with ``i mod 2 == gk mod 2``).
        """
        if not 0 <= i < self.EXT_IN:
            raise ValueError(f"external input {i} out of range 0..{self.EXT_IN - 1}")
        if i % 2 != self.parity(gk):
            raise ValueError(
                f"R2 parity: clb_in[{i}] unreachable from pin gk={gk} "
                f"(class {i % 2} != {self.parity(gk)})")
        return 0b10000 | (i // 2)

    def sel_fb(self, j: int) -> int:
        """v2c sel reading feedback ``j`` (0..N-1) — legal from every pin (R1)."""
        if not 0 <= j < self.N:
            raise ValueError(f"feedback index {j} out of range 0..{self.N - 1}")
        return j

    def pool_index_of(self, gk: int, sel: int) -> int:
        """Decode a v2c sel at pin ``gk`` to its pool index (bit-slicing, §7.2).

        ``sel[4]=1`` -> ``{sel[3:0], pi(gk)}`` (external; sel[3:0]>=9 is the
        reserved padding/fb region — MUST NOT be programmed, decoded anyway);
        ``sel[4]=0`` -> ``{2'b11, sel[2:0]}`` (feedback 24+j).
        """
        sel &= 0b11111
        if sel & 0b10000:
            return ((sel & 0xF) << 1) | self.parity(gk)
        return self.FB_BASE + (sel & 0b111)

    # -- configuration ------------------------------------------------------
    def configure(self, addr: int, data: int) -> "ClbT":
        addr &= (1 << CFG_ADDR_WIDTH) - 1
        if addr < self.N:
            self.eluts[addr].configure(data & ((1 << ELUT_WORD_WIDTH) - 1))
        elif addr < self.mux_end:
            self.mux_sel[addr - self.N] = data & 0b11111
        # addresses >= mux_end are reserved/ignored
        return self

    def configure_elut(self, lut: int, word: int) -> "ClbT":
        self.eluts[lut].configure(word)
        return self

    def route(self, lut: int, pin: int, source: int) -> "ClbT":
        """Route v2c ``source`` sel to LUT ``lut`` input ``pin`` (sets one mux).

        ``source`` is the 5-bit v2c select (see :meth:`sel_ext` /
        :meth:`sel_fb` / :meth:`pool_index_of`).
        """
        self.mux_sel[lut * self.K + pin] = source & 0b11111
        return self

    # -- combinational evaluation ------------------------------------------
    def _pool(self, ext_in) -> list[int]:
        if isinstance(ext_in, int):
            ext = [(ext_in >> i) & 1 for i in range(self.EXT_IN)]
        else:
            ext = [int(v) & 1 for v in ext_in]
        # v2c pool: ext[0..17], padding 0 [18..23], feedback j at [24..31]
        pool = ext + [0] * (self.FB_BASE - self.EXT_IN)
        pool += [self.clb_out[i] & 1 for i in range(self.N)]
        pool += [0] * (self.POOL - len(pool))
        return pool

    def _lut_vin(self, i: int, pool: list[int]) -> int:
        vin = 0
        base = i * self.K
        for k in range(self.K):
            idx = self.pool_index_of(k, self.mux_sel[base + k])
            bit = pool[idx] if 0 <= idx < self.POOL else 0
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
