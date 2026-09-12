# SPDX-License-Identifier: MIT
"""Bit-exact golden reference model for the NPU-Tiny INT8 systolic tile (E3-SVC1).

This model is the *numeric contract* of ``ethereal-fabric/rtl/tile/npu_t.sv``:
the self-checking SystemVerilog testbenches compare every C-buffer word against
it, so every rule stated here is a rule the RTL must implement.

Arithmetic contract (frozen v1, 2026-09-13)
-------------------------------------------
* operands: ``a`` (activations) and ``w`` (weights) are signed INT8 in [-128,127].
* product: exact signed 16-bit ``a*w`` (no rounding anywhere in the datapath).
* accumulation: every accumulate step is a **saturating** 32-bit signed add:

      sat_add_i32(x, y) ->  +2^31-1  if x+y > +2^31-1
                          -2^31     if x+y < -2^31
                          x+y       otherwise

  Saturation is applied *per step*, not once at the end. Within one K-chunk the
  depth-8 PE column chain adds k = 0,1,...,7 in ascending order (each PE does one
  saturating add). Across K-chunks (host tiling with CTRL.ACC_EN=1) the C-buffer
  accumulate is a further saturating add. The RTL mirrors both.
* overflow: the model reports an ``ovf`` flag whenever any saturating add
  saturated; the RTL raises the sticky STATUS.OVF bit for the same events.
* array geometry v1: M <= 8 output rows, K multiple of 8 (host tiled), N = 8
  columns.
* host-side activation quantization (used by the TinyML demo only, i.e. not by
  the tile): ``requant_i8(v) = clamp((v + 128) >> 8, -128, 127)`` with an
  arithmetic right shift (floor), matching the testbench's ``>>>``.

Nothing here imports numpy: ``make test-model`` runs on a bare venv.
"""
from __future__ import annotations

from dataclasses import dataclass, field

I8_MIN = -128
I8_MAX = 127
I32_MIN = -(1 << 31)
I32_MAX = (1 << 31) - 1
K_DIM = 8  # PE column-chain depth == INT8 K-chunk
N_DIM = 8  # array width in PE columns


def sat_add_i32(x: int, y: int) -> tuple[int, bool]:
    """Saturating 32-bit signed add; returns (value, saturated?)."""
    s = x + y
    if s > I32_MAX:
        return I32_MAX, True
    if s < I32_MIN:
        return I32_MIN, True
    return s, False


def as_i8(v: int) -> int:
    """Assert/return v as a signed INT8 (fail loudly on out-of-range inputs)."""
    if not I8_MIN <= v <= I8_MAX:
        raise ValueError(f"{v} is not a signed INT8")
    return v


def requant_i8(v: int) -> int:
    """Host-side INT8 requantization: arithmetic (floor) shift, then clamp."""
    q = (v + 128) >> 8
    return max(I8_MIN, min(I8_MAX, q))


@dataclass
class Gemm:
    """One GEMM invocation's result + status."""

    c: list[list[int]] = field(default_factory=lambda: [[0] * N_DIM for _ in range(8)])
    ovf: bool = False


def _chain_dot(a_row: list[int], w_col: list[int]) -> tuple[int, bool]:
    """One output element: the depth-8 PE column chain, ascending k, saturating."""
    acc = 0
    ovf = False
    for k in range(K_DIM):
        prod = as_i8(a_row[k]) * as_i8(w_col[k])
        acc, sat = sat_add_i32(acc, prod)
        ovf = ovf or sat
    return acc, ovf


def chunk_gemm(a: list[list[int]], w: list[list[int]], m: int) -> Gemm:
    """One K=8 chunk: C[m][n] = sum_k a[m][k]*w[k][n], saturating per PE step."""
    res = Gemm()
    for mi in range(m):
        for n in range(N_DIM):
            col = [w[k][n] for k in range(K_DIM)]
            res.c[mi][n], sat = _chain_dot(a[mi], col)
            res.ovf = res.ovf or sat
    for mi in range(m, 8):  # rows beyond M hold no data in the model
        res.c[mi] = [0] * N_DIM
    return res


def gemm(
    a: list[list[int]],
    w: list[list[int]],
    m: int,
    k: int,
    c_prev: list[list[int]] | None = None,
    acc_en: bool = False,
) -> Gemm:
    """K-multiple-of-8 GEMM with ACC_EN chunk accumulation (host tiling)."""
    if k % K_DIM != 0 or k == 0:
        raise ValueError("K must be a positive multiple of 8 (v1)")
    if not 1 <= m <= 8:
        raise ValueError("M must be 1..8 (v1)")
    c_cur = [list(row) for row in (c_prev if c_prev is not None else [[0] * N_DIM] * 8)]
    ovf = False
    for chunk in range(k // K_DIM):
        a_chunk = [[a[mi][chunk * K_DIM + kk] for kk in range(K_DIM)] for mi in range(m)]
        w_chunk = [[w[chunk * K_DIM + kk][n] for n in range(N_DIM)] for kk in range(K_DIM)]
        step = chunk_gemm(a_chunk, w_chunk, m)
        ovf = ovf or step.ovf
        # Chunk 0 overwrites the C buffer; every later chunk of the same K loop
        # accumulates (exactly what the host does with CTRL.ACC_EN on the tile).
        do_acc = acc_en or (chunk > 0)
        for mi in range(m):
            for n in range(N_DIM):
                if do_acc:
                    c_cur[mi][n], sat = sat_add_i32(c_cur[mi][n], step.c[mi][n])
                    ovf = ovf or sat
                else:
                    c_cur[mi][n] = step.c[mi][n]
    return Gemm(c=c_cur, ovf=ovf)


def pack_a_bytes(a: list[list[int]], m: int, k: int) -> list[int]:
    """Row-major (m,k) A byte stream, as the driver writes it to CSR_A_WR."""
    return [a[mi][kk] & 0xFF for mi in range(m) for kk in range(k)]


def pack_w_bytes(w: list[list[int]], k: int) -> list[int]:
    """Row-major (k,n) W byte stream, as the driver writes it to CSR_W_WR."""
    return [w[kk][n] & 0xFF for kk in range(k) for n in range(N_DIM)]


def pack_c_words(c: list[list[int]]) -> list[int]:
    """Row-major (m,n) C word stream, as CSR_C_RD reads it out."""
    return [c[mi][n] & 0xFFFFFFFF for mi in range(8) for n in range(N_DIM)]


# ---------------------------------------------------------------------------
# TinyML demo: 2-layer INT8 MLP with a bias folded into the K dimension.
# ---------------------------------------------------------------------------
@dataclass
class MlpResult:
    y1: list[list[int]]        # layer-1 accumulator (M=1 x 8, INT32, saturating)
    y1_q: list[int]            # requantized INT8 activation (ReLU then requant)
    y2: list[list[int]]        # layer-2 accumulator (M=1 x 8)
    cls: int                   # argmax over the first `n_classes` columns
    ovf: bool = False


def _relu_requant(v: int) -> int:
    return requant_i8(v if v > 0 else 0)


def mlp_infer(
    x: list[int],
    w1: list[list[int]],
    b1: list[int],
    w2: list[list[int]],
    n_classes: int = 4,
) -> MlpResult:
    """Two-layer INT8 MLP exactly as the E3-SVC1 demo testbench runs it.

    Layer 1 is a single session with K=16: chunk 0 is x*W1, chunk 1 folds the
    bias (a = [1,0,...,0], W rows 8..15 = [b1, 0, ...]); the C buffer accumulates
    with CTRL.ACC_EN=1, so the tile, not the host, adds the bias.
    Layer 2 is a K=8 session on the requantized layer-1 activation, with W2
    zero-padded to 8 columns; the class is argmax(y2[0][:n_classes]).
    """
    # --- layer 1, chunk 0 (K = 8) ---
    c1 = gemm([x], w1, m=1, k=K_DIM)
    # --- layer 1, chunk 1 (K = 8): the folded bias row ---
    # a = [1, 0, ..., 0] so only W_chunk[0][n] contributes; that row carries the
    # bias, which the demo keeps inside INT8 (the W stream is a byte stream).
    a_b = [[1] + [0] * (K_DIM - 1)]
    w_b = [[as_i8(b1[n]) for n in range(N_DIM)]] + [[0] * N_DIM for _ in range(K_DIM - 1)]
    step = gemm(a_b, w_b, m=1, k=K_DIM, c_prev=c1.c, acc_en=True)
    y1 = step.c
    ovf = c1.ovf or step.ovf
    # --- host-side activation: ReLU + requantization to INT8 ---
    y1_q = [_relu_requant(y1[0][n]) for n in range(N_DIM)]
    # --- layer 2 (K = 8) ---
    step2 = gemm([y1_q], w2, m=1, k=K_DIM)
    y2 = step2.c
    ovf = ovf or step2.ovf
    cls = max(range(n_classes), key=lambda n: y2[0][n])
    return MlpResult(y1=y1, y1_q=y1_q, y2=y2, cls=cls, ovf=ovf)


# ---------------------------------------------------------------------------
# Session-isolation model: what "state" means and what a boundary must blank.
# ---------------------------------------------------------------------------
@dataclass
class SessionState:
    """The tile's session state, as enumerated in the E3-SVC1 report §4.

    acc/wgt/feed/wstg/cbuf are flattened to plain ints here: the model only has
    to be able to say "non-zero residue survived the boundary".
    """

    acc: int = 0
    wgt: int = 0
    feed: int = 0
    wstg: int = 0
    cbuf: int = 0
    cyc: int = 0
    cnt: int = 0
    fsm: int = 0
    flags: int = 0

    def blank(self, leak: bool = False) -> "SessionState":
        """Session boundary. ``leak=True`` models the negative control
        (LEAK_INJECT): the datapath arrays keep their residue, exactly like the
        RTL parameter does, while control state still resets."""
        if leak:
            return SessionState(acc=self.acc, wgt=self.wgt, feed=self.feed,
                                wstg=self.wstg, cbuf=self.cbuf)
        return SessionState()

    def loaded(self, tag: int) -> "SessionState":
        """A session with work in it: every element is non-zero."""
        return SessionState(acc=tag, wgt=tag, feed=tag, wstg=tag, cbuf=tag,
                            cyc=tag, cnt=tag, fsm=1, flags=tag)

    @property
    def datapath_residue(self) -> int:
        return abs(self.acc) + abs(self.wgt) + abs(self.feed) + abs(self.wstg) + abs(self.cbuf)

    @property
    def control_residue(self) -> int:
        return abs(self.cyc) + abs(self.cnt) + abs(self.fsm) + abs(self.flags)
