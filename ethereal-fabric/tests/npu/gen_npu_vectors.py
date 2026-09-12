# SPDX-License-Identifier: MIT
"""Deterministic test-vector generator for the NPU-Tiny tile (E3-SVC1).

Everything is derived from fixed LCG seeds, so regenerating is byte-identical and
the checked-in files under ``vectors/`` can be diffed against this generator
(``test_npu_model.py::test_vectors_up_to_date`` is exactly that drift guard).

Run:  .venv/bin/python ethereal-fabric/tests/npu/gen_npu_vectors.py [--out DIR]

File formats (whitespace-separated tokens, no comment lines):

* generic case stream (tb_npu_t, tb_npu_isolation)
      ``m n acc tag`` then ``m*8`` A bytes, then 64 W bytes, then 64 C words,
      all as hex tokens.  ``acc``=1 means "accumulate into the C buffer left by
      the previous case" (a K>8 continuation inside the same session); ``tag``
      is the session/container identity, and a change of tag is a session
      boundary in the testbench.
* TinyML stream (tb_npu_tinyml), one whole inference:
      ``M1`` , 8 L1A bytes, 64 L1W bytes, 64 L1C words, 8 Q1 bytes,
      8 L2A bytes, 64 L2W bytes, 64 L2C words, ``CLASS``.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:  # importable both as a module (pytest) and as a script
    from npu_model import K_DIM, N_DIM, gemm, mlp_infer, pack_a_bytes, pack_c_words, pack_w_bytes
except ImportError:  # pragma: no cover - script mode
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from npu_model import K_DIM, N_DIM, gemm, mlp_infer, pack_a_bytes, pack_c_words, pack_w_bytes

VECTOR_DIR = Path(__file__).resolve().parent / "vectors"


def lcg(seed: int, n: int, lo: int, hi: int) -> list[int]:
    """Deterministic 32-bit LCG in [lo, hi] (do not change: file drift)."""
    s = seed & 0xFFFFFFFF
    out: list[int] = []
    for _ in range(n):
        s = (s * 1103515245 + 12345) & 0xFFFFFFFF
        out.append(lo + ((s >> 16) % (hi - lo + 1)))
    return out


def _mat(vals: list[int], rows: int, cols: int) -> list[list[int]]:
    return [vals[r * cols:(r + 1) * cols] for r in range(rows)]


def _case(m: int, acc: int, tag: int, a_words: list[list[int]], w_words: list[list[int]],
          c_words: list[list[int]]) -> str:
    toks = [f"{m} {N_DIM} {acc} {tag}"]
    toks += [f"{b:02x}" for b in pack_a_bytes(a_words, m, K_DIM)]
    toks += [f"{b:02x}" for b in pack_w_bytes(w_words, K_DIM)]
    toks += [f"{w:08x}" for w in pack_c_words(c_words)]
    return " ".join(toks) + "\n"


def build_gemm_vectors() -> str:
    """tb_npu_t case stream: plain GEMM, extremes, saturation, odd M, K tiling."""
    out = ""
    # case 0 — M=8 random (new session, tag 1)
    a = _mat(lcg(0x1001, 64, -128, 127), 8, K_DIM)
    w = _mat(lcg(0x2001, 64, -128, 127), K_DIM, N_DIM)
    out += _case(8, 0, 1, a, w, gemm(a, w, m=8, k=K_DIM).c)
    # case 1 — M=1 operand extremes
    a = _mat([-128 if i % 2 == 0 else 127 for i in range(K_DIM)], 1, K_DIM)
    w = _mat([127 if i % 3 else -128 for i in range(64)], K_DIM, N_DIM)
    out += _case(1, 0, 2, a, w, gemm(a, w, m=1, k=K_DIM).c)
    # case 2 — saturation-heavy: every accumulator step pins at +2^31-1
    a = _mat([127] * 64, 8, K_DIM)
    w = _mat([127] * 64, K_DIM, N_DIM)
    out += _case(8, 0, 3, a, w, gemm(a, w, m=8, k=K_DIM).c)
    # case 3 — odd M=3
    a = _mat(lcg(0x3001, 24, -128, 127), 3, K_DIM)
    w = _mat(lcg(0x4001, 64, -128, 127), K_DIM, N_DIM)
    out += _case(3, 0, 4, a, w, gemm(a, w, m=3, k=K_DIM).c)
    # case 4/5 — K=16 as two chunks inside one session (tag 5): ACC_EN continuation
    a16 = _mat(lcg(0x5001, 128, -128, 127), 4, 16)
    w16 = _mat(lcg(0x6001, 128, -128, 127), 16, N_DIM)
    chunk0 = [[a16[mi][kk] for kk in range(K_DIM)] for mi in range(4)]
    w0 = [[w16[kk][n] for n in range(N_DIM)] for kk in range(K_DIM)]
    c0 = gemm(chunk0, w0, m=4, k=K_DIM)
    out += _case(4, 0, 5, chunk0, w0, c0.c)
    chunk1 = [[a16[mi][K_DIM + kk] for kk in range(K_DIM)] for mi in range(4)]
    w1 = [[w16[K_DIM + kk][n] for n in range(N_DIM)] for kk in range(K_DIM)]
    c1 = gemm(chunk1, w1, m=4, k=K_DIM, c_prev=c0.c, acc_en=True)
    out += _case(4, 1, 5, chunk1, w1, c1.c)
    # case 6 — a fresh session after the tiled one (boundary blank + M=8)
    a = _mat(lcg(0x7001, 64, -128, 127), 8, K_DIM)
    w = _mat(lcg(0x8001, 64, -128, 127), K_DIM, N_DIM)
    out += _case(8, 0, 6, a, w, gemm(a, w, m=8, k=K_DIM).c)
    return out


def build_iso_vectors() -> str:
    """tb_npu_isolation case stream: container A (M=8), container B (M=2), A again,
    and a zero probe after B — the state-leak scenario of S11 §2.1/§3."""
    out = ""
    # container 1 (tag 1): a big workload that leaves the most residue
    a1 = _mat(lcg(0xA001, 64, -128, 127), 8, K_DIM)
    w1 = _mat(lcg(0xB001, 64, -128, 127), K_DIM, N_DIM)
    out += _case(8, 0, 1, a1, w1, gemm(a1, w1, m=8, k=K_DIM).c)
    # container 2 (tag 2): M=2 — rows 2..7 of the C buffer must stay blank
    a2 = _mat(lcg(0xC001, 16, -128, 127), 2, K_DIM)
    w2 = _mat(lcg(0xD001, 64, -128, 127), K_DIM, N_DIM)
    out += _case(2, 0, 2, a2, w2, gemm(a2, w2, m=2, k=K_DIM).c)
    # container 3 (tag 3): re-runs container 1's workload — must be bit-identical
    out += _case(8, 0, 3, a1, w1, gemm(a1, w1, m=8, k=K_DIM).c)
    # container 4 (tag 4): zero probe, M=1 — every C word must be exactly 0
    az = _mat([0] * K_DIM, 1, K_DIM)
    wz = _mat([127] * 64, K_DIM, N_DIM)
    out += _case(1, 0, 4, az, wz, gemm(az, wz, m=1, k=K_DIM).c)
    return out


def build_tinyml_vectors() -> tuple[str, dict[str, int]]:
    """Two-layer INT8 MLP (KWS-shaped): layer 1 K=16 with a folded bias, layer 2
    K=8/n_classes=4. Returns (file text, summary dict).

    Token order: L1c0 A(8) | L1c0 W(64) | L1c1 A(8) | L1c1 W(64) | L1 C(64, the
    accumulated result) | Q1(8) | L2 W(64) | L2 C(64) | CLASS(1). The demo is a
    fixed M=1 inference, so no per-case header is emitted."""
    x = lcg(0xF001, K_DIM, -128, 127)
    w1 = _mat(lcg(0xF101, 64, -128, 127), K_DIM, N_DIM)
    b1 = lcg(0xF201, N_DIM, -100, 100)
    w2_vals = lcg(0xF301, 64, -128, 127)
    w2 = _mat(w2_vals, K_DIM, N_DIM)
    for kk in range(K_DIM):          # keep the last 4 outputs unused (4 classes)
        for n in range(4, N_DIM):
            w2[kk][n] = 0
    res = mlp_infer(x, w1, b1, w2, n_classes=4)
    l1c = gemm([x], w1, m=1, k=K_DIM).c
    a_b = [[1] + [0] * (K_DIM - 1)]
    w_b = [[b1[n] for n in range(N_DIM)]] + [[0] * N_DIM for _ in range(K_DIM - 1)]
    l1c_final = gemm(a_b, w_b, m=1, k=K_DIM, c_prev=l1c, acc_en=True).c
    if l1c_final != res.y1:
        raise AssertionError("bias-fold model disagrees with mlp_infer")
    toks = [f"{b:02x}" for b in pack_a_bytes([x], 1, K_DIM)]        # L1 chunk 0 A
    toks += [f"{b:02x}" for b in pack_w_bytes(w1, K_DIM)]          # L1 chunk 0 W
    toks += [f"{b:02x}" for b in pack_a_bytes(a_b, 1, K_DIM)]      # L1 chunk 1 A
    toks += [f"{b:02x}" for b in pack_w_bytes(w_b, K_DIM)]         # L1 chunk 1 W
    toks += [f"{w:08x}" for w in pack_c_words(l1c_final)]          # L1 C (accumulated)
    toks += [f"{b & 0xFF:02x}" for b in res.y1_q]                  # Q1 (host requant)
    toks += [f"{b:02x}" for b in pack_w_bytes(w2, K_DIM)]          # L2 W
    toks += [f"{w:08x}" for w in pack_c_words(res.y2)]             # L2 C
    toks += [f"{res.cls}"]                                         # argmax class
    summary = {"class": res.cls, "y1_q": res.y1_q, "y2": res.y2[0], "ovf": int(res.ovf)}
    return " ".join(toks) + "\n", summary


def build_all() -> dict[str, str]:
    """filename -> content for every generated vector file."""
    tiny, _ = build_tinyml_vectors()
    return {
        "npu_gemm_cases.txt": build_gemm_vectors(),
        "npu_iso_cases.txt": build_iso_vectors(),
        "npu_tinyml.txt": tiny,
    }


def main(argv: list[str]) -> int:
    out_dir = VECTOR_DIR
    if "--out" in argv:
        out_dir = Path(argv[argv.index("--out") + 1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, content in build_all().items():
        (out_dir / name).write_text(content, encoding="ascii")
        print(f"[gen_npu_vectors] wrote {out_dir / name} ({len(content)} bytes)")
    _, summary = build_tinyml_vectors()
    print(f"[gen_npu_vectors] tinyml: class={summary['class']} y1_q={summary['y1_q']} "
          f"y2={summary['y2']} ovf={summary['ovf']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
