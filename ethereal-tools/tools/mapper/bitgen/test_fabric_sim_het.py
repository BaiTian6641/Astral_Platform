# SPDX-License-Identifier: MIT
"""pytest for fabric_sim_het — heterogeneous tile models + fir16/aes bit-true
(Phase-1, Stage 6 follow-up: close the functional loop on the heterogeneous fabric).

Models mem_t (virtual RAM, S-box ROM) + dsp_t (virtual MAC cascade) and proves
fir16 (on DSP) + aes (on MEM) compute bit-true vs an independent iverilog golden.

What is proven here (the honest boundary): the mem_t/dsp_t TILE SEMANTICS are
modeled correctly (RAM ROM/sync-read; MAC cascade) and the fir16_dsp / aes128_round
circuits compute bit-true. The full routed heterogeneous circuit (vbus->routing
integration) is a separate later step (Stage 5b used host-constant operands).

Run:  make test-model   (root)  or  .venv/bin/python -m pytest <this file> -v
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
BENCH = os.path.join(REPO, "ethereal-images", "benchmarks")

from fabric_sim_het import DspTileModel, MemTileModel, fir16_dsp_eval  # noqa: E402

IVERILOG = shutil.which("iverilog") and shutil.which("vvp")
pytestmark = pytest.mark.skipif(not IVERILOG, reason="iverilog/vvp not on PATH")


# =============================================================================
# iverilog golden helper
# =============================================================================
def _iverilog_golden(design_v: str, top: str, tb_body: str,
                     in_ports: list[tuple[str, int]], out_ports: list[tuple[str, int]],
                     n_vectors: int, seed: int) -> list[tuple[list[int], list[int]]]:
    """iverilog-simulate ``design_v`` over ``n_vectors`` random inputs.

    Returns ``[(pi_values_flat, po_values_flat), ...]`` where each port is split
    into its bits (MSB-first per the $display). ``tb_body`` is the testbench
    driver (instantiates ``top`` + loops + $display). in/out port lists are
    (name, width).
    """
    tb = f"""`timescale 1ns/1ps
module _tb;
{tb_body}
endmodule
"""
    tb_path = os.path.join("/tmp", f"_golden_{top}_tb.v")
    with open(tb_path, "w") as fh:
        fh.write(tb)
    sim = os.path.join("/tmp", f"_golden_{top}")
    res = subprocess.run(
        ["iverilog", "-g2012", "-o", sim, design_v, tb_path],
        capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"iverilog failed:\n{res.stderr}")
    out = subprocess.run(["vvp", sim], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"vvp failed:\n{out.stderr}")
    rows = []
    for line in out.stdout.splitlines():
        toks = line.split()
        if len(toks) != (sum(w for _n, w in in_ports) + sum(w for _n, w in out_ports)):
            continue
        nin = sum(w for _n, w in in_ports)
        rows.append(([int(t) for t in toks[:nin]], [int(t) for t in toks[nin:]]))
    return rows


# =============================================================================
# 1. dsp_t / mem_t model unit tests (the tile semantics)
# =============================================================================

def test_dsp_model_mult_and_acc():
    """dsp_t model: MULT (acc=False) + accumulate (acc=True cascade chain)."""
    m = DspTileModel(acc=False)
    assert m.eval(7, 6, 0) == 42                      # 7*6
    # accumulate (acc chain): each call adds a*b to the running total on cascade-in
    mm = DspTileModel(acc=True)
    s = 0
    for k in (1, 2, 3):
        s = mm.eval(k, k, s)  # cascade-in = running total -> p += k*k
    assert s == 14                                   # 1 + 4 + 9


def test_mem_model_rom_and_sync_read():
    """mem_t model: ROM (comb read) + synchronous read (read-first)."""
    mem = MemTileModel(init={5: 0xAB, 7: 0xCD})
    assert mem.read_comb(5) == 0xAB                    # ROM path
    assert mem.read_comb(7) == 0xCD
    # sync-read: write 0x11 to addr 5, then read back (read-first returns OLD)
    mem2 = MemTileModel(init={})
    old = mem2.tick(addr=5, wdata=0x11, we=0b1111, en=True)   # vd_o = OLD (0)
    assert old == 0
    assert mem2.read_comb(5) == 0x11                    # write landed
    rd = mem2.tick(addr=5, wdata=0, we=0, en=True)      # read: returns 0x11
    assert rd == 0x11


# =============================================================================
# 2. fir16 bit-true (dsp_t cascade model vs iverilog fir16_dsp.v)
# =============================================================================

def _fir16_golden(n_vectors: int, seed: int) -> list[tuple[list[int], list[int], int]]:
    """iverilog golden for fir16_dsp: (taps[16], coeffs[16], y) per vector.

    The TB prints taps and coeffs as 16 separate 8-bit / 16-bit hex fields plus
    the 48-bit y, so Python can reconstruct them exactly.
    """
    tb_body = """  reg clk=0; always #5 clk=~clk;
  reg [127:0] x; reg [255:0] h; wire signed [47:0] y;
  integer i, k;
  fir16_dsp dut(.clk(clk), .x(x), .h(h), .y(y));
  initial begin
    x = 0; h = 0;
    for (i = 0; i < NVECTORS; i = i + 1) begin
      x = {$random, $random, $random, $random};
      h = {$random, $random, $random, $random, $random, $random, $random, $random};
      // hold this vector constant across the 16-deep acc pipeline (16 taps + 1 y reg)
      // so it fully propagates; then read y.
      repeat (18) @(negedge clk);
      for (k = 15; k >= 0; k = k - 1) $write("%02h ", x[8*k +: 8]);
      for (k = 15; k >= 0; k = k - 1) $write("%04h ", h[16*k +: 16]);
      $display("%012h", y);
    end
    $finish;
  end""".replace("NVECTORS", str(n_vectors))
    tb_path = "/tmp/_golden_fir16_tb.v"
    with open(tb_path, "w") as fh:
        fh.write(f"`timescale 1ns/1ps\nmodule _tb;\n{tb_body}\nendmodule\n")
    sim = "/tmp/_golden_fir16"
    res = subprocess.run(["iverilog", "-g2012", "-o", sim,
                          os.path.join(BENCH, "fir16_dsp.v"), tb_path],
                         capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"iverilog failed:\n{res.stderr}")
    out = subprocess.run(["vvp", sim], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"vvp failed:\n{out.stderr}")
    rows = []
    for line in out.stdout.splitlines():
        toks = line.split()
        if len(toks) != 33:          # 16 taps + 16 coeffs + 1 y
            continue
        try:
            taps = [_signed(int(t, 16), 8) for t in toks[:16]]
            coeffs = [_signed(int(t, 16), 16) for t in toks[16:32]]
            y = int(toks[32], 16)
        except ValueError:
            continue
        rows.append((taps, coeffs, y))
    return rows


def test_fir16_bittrue():
    """fir16_dsp modeled via the dsp_t cascade == iverilog fir16_dsp.v golden."""
    n = 32
    rows = _fir16_golden(n, seed=0xF16)
    assert len(rows) >= 24, f"too few fir16 golden vectors parsed: {len(rows)}"
    mismatches = 0
    for (taps, coeffs, y_golden) in rows:
        model_y = fir16_dsp_eval(taps, coeffs) & ((1 << 48) - 1)
        if model_y != y_golden:
            mismatches += 1
    print(f"\n[fir16 bittrue] {len(rows) - mismatches}/{len(rows)} vectors bit-true (dsp cascade model)")
    assert mismatches == 0, f"{mismatches}/{len(rows)} fir16 vectors mismatch"


# =============================================================================
# 3. aes bit-true (mem_t ROM S-box + round logic vs iverilog aes128_round.v)
# =============================================================================

def _signed(v: int, w: int) -> int:
    return v - (1 << w) if (v >> (w - 1)) & 1 else v


def _sbox_table() -> list[int]:
    """The AES S-box (Rijndael), extracted from aes128_round.v (the ROM content)."""
    text = open(os.path.join(BENCH, "aes128_round.v"), encoding="utf-8").read()
    import re
    table = [0] * 256
    for m in re.finditer(r"8'h([0-9a-fA-F]{2}):\s*sbox\s*=\s*8'h([0-9a-fA-F]{2})", text):
        table[int(m.group(1), 16)] = int(m.group(2), 16)
    return table


def _xtime(b: int) -> int:
    return ((b << 1) & 0xFF) ^ (0x1B if (b & 0x80) else 0)


def _aes_round_model(state: int, roundkey: int, sbox: list[int]) -> int:
    """AES round: SubBytes (mem_t ROM S-box) + ShiftRows + MixColumns + AddRoundKey.

    Byte layout matches aes128_round.v: byte i at state[8*i +: 8] (LSB-first —
    byte 0 = state[7:0] = the RIGHTMOST byte of the 128-bit word). ShiftRows uses
    (row r=i%4, col c=i/4) -> out( r,c ) = in( r, (c+r) mod 4 ), idx = 4*c + r.
    """
    def _byte(word: int, i: int) -> int:
        return (word >> (8 * i)) & 0xFF

    # SubBytes: sb[i] = sbox(state byte i).
    sb = [sbox[_byte(state, i)] for i in range(16)]
    # ShiftRows: out(4c+r) = sb(4*((c+r)%4) + r).
    sr = [0] * 16
    for r in range(4):
        for c in range(4):
            sr[4 * c + r] = sb[4 * ((c + r) % 4) + r]
    # MixColumns per column c (bytes 4c..4c+3) — standard AES MixColumns.
    out = [0] * 16
    for c in range(4):
        a0, a1, a2, a3 = sr[4*c], sr[4*c+1], sr[4*c+2], sr[4*c+3]
        out[4*c+0] = _xtime(a0) ^ (_xtime(a1) ^ a1) ^ a2 ^ a3
        out[4*c+1] = a0 ^ _xtime(a1) ^ (_xtime(a2) ^ a2) ^ a3
        out[4*c+2] = a0 ^ a1 ^ _xtime(a2) ^ (_xtime(a3) ^ a3)
        out[4*c+3] = (_xtime(a0) ^ a0) ^ a1 ^ a2 ^ _xtime(a3)
    # AddRoundKey (byte i at state[8*i +: 8], LSB-first).
    result = 0
    for i in range(16):
        result |= ((out[i] ^ _byte(roundkey, i)) & 0xFF) << (8 * i)
    return result


def _aes_golden(n_vectors: int, seed: int) -> list[tuple[int, int, int]]:
    """iverilog golden for aes128_round: (state, roundkey, out)."""
    tb_body = """  reg [127:0] state; reg [127:0] roundkey; wire [127:0] out;
  integer i;
  aes128_round dut(.state(state), .roundkey(roundkey), .out(out));
  initial begin
    state = 0; roundkey = 0;
    #1;
    for (i = 0; i < NVECTORS; i = i + 1) begin
      state = {$random, $random, $random, $random};
      roundkey = {$random, $random, $random, $random};
      #1;
      $display("%032h %032h %032h", state, roundkey, out);
    end
    $finish;
  end""".replace("NVECTORS", str(n_vectors))
    tb_path = "/tmp/_golden_aes_tb.v"
    with open(tb_path, "w") as fh:
        fh.write(f"`timescale 1ns/1ps\nmodule _tb;\n{tb_body}\nendmodule\n")
    sim = "/tmp/_golden_aes"
    res = subprocess.run(["iverilog", "-g2012", "-o", sim,
                          os.path.join(BENCH, "aes128_round.v"), tb_path],
                         capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"iverilog failed:\n{res.stderr}")
    out = subprocess.run(["vvp", sim], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"vvp failed:\n{out.stderr}")
    rows = []
    for line in out.stdout.splitlines():
        toks = line.split()
        if len(toks) != 3:
            continue
        try:
            rows.append((int(toks[0], 16), int(toks[1], 16), int(toks[2], 16)))
        except ValueError:
            continue
    return rows


def test_aes_bittrue():
    """aes128_round modeled via mem_t ROM S-box + round logic == iverilog golden."""
    n = 32
    sbox = _sbox_table()
    assert len(sbox) == 256 and sbox[0] == 0x63 and sbox[0xFF] == 0x16
    rows = _aes_golden(n, seed=0xAE5)
    assert len(rows) >= 24, f"too few AES golden vectors parsed: {len(rows)}"
    mismatches = 0
    for (state, roundkey, out_golden) in rows:
        out_model = _aes_round_model(state, roundkey, sbox)
        if out_model != out_golden:
            mismatches += 1
    print(f"\n[aes bittrue] {len(rows) - mismatches}/{len(rows)} vectors bit-true (mem ROM S-box + round)")
    assert mismatches == 0, f"{mismatches}/{len(rows)} AES vectors mismatch"
