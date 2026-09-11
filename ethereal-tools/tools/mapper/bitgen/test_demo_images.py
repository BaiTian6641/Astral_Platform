# SPDX-License-Identifier: MIT
"""test_demo_images — E1-DMO1 signed demo .eth image acceptance.

The two shipped images (``ethereal-images/demos/{pwm,uart_loopback}.eth``)
are validated end-to-end through the FULL frame path:

  * ethimg integrity + Ed25519 signature vs the daemon ``keyring.h`` raw key
    (the exact trust anchor the BMC firmware verifies against);
  * the frames member inside the SHIPPED .eth equals the deterministic
    toolchain output (synth -> VPR -> build_db -> PathFinder route ->
    target-geometry frame pack) — the tar carries a wall-clock ``created``,
    so only the frames bytes (the deployable payload) are compared;
  * the frames are CRC-unpacked (``frames_to_db`` + ``frames_to_route``,
    net names re-attached at apply time) and simulated on a FabricSim of the
    DESCRIPTOR geometry:
      - pwm: 64 random golden vectors, combinational ``evaluate``;
      - uart_loopback: 3 directed byte streams (incl. back-to-back traffic
        at full wire rate and a framing-error frame that must be dropped),
        per-cycle ``tx`` trace vs the iverilog golden via the tick model
        (``FabricSim.tick``, E1-DMO1);
  * the emitted ``run_packed`` session JSONs conform to the
    tb_ethctl_replay replayer contract (op lines, "0x........" tokens,
    stream totals = columns x DATA words).
"""
from __future__ import annotations

import json
import os
import re

import pytest

import fabric_sim  # noqa: F401  (sys.path bootstrap, mirrors test_bench_flow)
from bench_golden import golden_comb, golden_seq
from bitgen_db import build_db
from bitgen_route import route
from demo_images import (BENCH_DIR, IMAGES, ensure_flow,
                         keyring_pub_pem, pack_target_frames, unpack_attached)

import ethimg
from fabric_gen import FabricGen

_HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(_HERE, "..", "..", "..", ".."))
DEMOS = os.path.join(REPO, "ethereal-images", "demos")
FABRIC_DIR = os.path.join(REPO, "ethereal-spec", "fabric")
ETHCTL = os.path.join(REPO, "generated", "ethctl")
UART_CPB = 87


# =============================================================================
# Shared flow (deterministic: same netlist + pinned seeds -> same frames)
# =============================================================================

def _flow_frames(name: str):
    """Re-run the deterministic tail of the flow -> (frames, db, rc, fg, off)."""
    cfg = IMAGES[name]
    fg = FabricGen.from_file(os.path.join(FABRIC_DIR, f"{cfg['fabric']}.yaml"))
    net, place, blif = ensure_flow(name)
    db = build_db(net, place, blif)
    rc = route(db, max_iters=200, seed=0)
    assert rc.converged, f"{name}: PathFinder did not converge"
    frames, offset = pack_target_frames(db, rc, fg)
    return frames, db, rc, fg, offset


def _shipped_frames(name: str) -> tuple[list[int], bytes]:
    """(DATA words, raw member bytes) of targets/<fabric>.frames in the .eth."""
    cfg = IMAGES[name]
    eth = os.path.join(DEMOS, f"{name}.eth")
    if not os.path.exists(eth):
        pytest.skip(f"{eth} missing (run demo_images.py to build)")
    _man, members = ethimg._read_members(ethimg.Path(eth))
    key = f"targets/{cfg['fabric']}.frames"
    raw = members[key]
    return [int.from_bytes(raw[i:i + 4], "little")
            for i in range(0, len(raw), 4)], raw


# =============================================================================
# pwm — combinational bit-true via the full frame path on fabric_2x2
# =============================================================================

def test_pwm_bittrue_fullframe():
    cfg = IMAGES["pwm"]
    frames, db, rc, fg, offset = _flow_frames("pwm")

    # the SHIPPED .eth carries exactly these frames (DATA words, no CRC tails)
    shipped, _raw = _shipped_frames("pwm")
    flat = [w for col in frames for w in col[:-1]]
    assert shipped == flat, "shipped pwm.eth frames != toolchain output"

    # CRC-checked unpack + net re-attach -> simulate on the descriptor grid
    db2, rc2 = unpack_attached(frames, fg, db, rc, offset)
    sim = fabric_sim.FabricSim(db2, rc2, 0, 0)
    assert (sim.R, sim.C) == (fg.R, fg.C), "descriptor geometry mismatch"

    golden = golden_comb(os.path.join(BENCH_DIR, cfg["bench"]), cfg["top"],
                         cfg["inputs"], cfg["outputs"], cfg["n_vectors"],
                         seed=cfg["seed"])
    out_nets = sorted(db2.primary_outputs)
    assert out_nets == ["out"]
    for idx, (pi_dict, po_golden) in enumerate(golden):
        po = sim.evaluate(pi_dict, max_iters=128)
        for net in out_nets:
            assert po.get(net) == po_golden[net], (
                f"pwm vector {idx}: PO {net} sim={po.get(net)} "
                f"golden={po_golden[net]}")


# =============================================================================
# uart_loopback — sequential bit-true via the tick model on fabric_4x4
# =============================================================================

def _uart_frame(byte: int, stop: int = 1) -> list[int]:
    """One UART-8N1 frame on the wire (start + LSB-first data + stop)."""
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [stop]
    return [b for b in bits for _ in range(UART_CPB)]


def _uart_streams() -> list[dict[str, int]]:
    """3 directed byte streams: single, back-to-back max-rate, framing error."""
    cpb = UART_CPB
    stim = [1] * (2 * cpb)
    # stream 1: one byte, then idle
    stim += _uart_frame(0x55) + [1] * (2 * cpb)
    # stream 2: three bytes back-to-back (full wire rate — exercises the
    # folded-stop timing: the TX must free up exactly one bit early)
    stim += _uart_frame(0x00) + _uart_frame(0xFF) + _uart_frame(0xA7)
    stim += [1] * (2 * cpb)
    # stream 3: clean byte, then a FRAMING-ERROR frame (stop driven low —
    # must be dropped), then a clean byte (recovery)
    stim += _uart_frame(0x3C) + _uart_frame(0x5A, stop=0) + _uart_frame(0xC3)
    # The trailing idle MUST cover the last echo: the final byte is accepted at
    # its stop-bit boundary and the TX still needs a full 10-bit frame (870
    # cycles) to shift it out. 3*cpb truncated that echo mid-frame, so the
    # semantic decode check could never see 0xC3 (E1-DMO1).
    stim += [1] * (10 * cpb)
    return [{"rx": b} for b in stim]



def test_uart_loopback_bittrue_tick():
    cfg = IMAGES["uart_loopback"]
    frames, db, rc, fg, offset = _flow_frames("uart_loopback")

    shipped, _raw = _shipped_frames("uart_loopback")
    flat = [w for col in frames for w in col[:-1]]
    assert shipped == flat, "shipped uart_loopback.eth frames != toolchain output"

    db2, rc2 = unpack_attached(frames, fg, db, rc, offset)
    sim = fabric_sim.FabricSim(db2, rc2, 0, 0)
    assert (sim.R, sim.C) == (fg.R, fg.C), "descriptor geometry mismatch"

    stream = _uart_streams()
    golden = golden_seq(os.path.join(BENCH_DIR, cfg["bench"]), cfg["top"],
                        stream, cfg["outputs"])
    state: dict = {}
    tx_trace: list[int] = []
    for idx, (pi_dict, po_golden) in enumerate(golden):
        po, state = sim.tick(pi_dict, state)
        assert po.get("tx") == po_golden["tx"], (
            f"uart tick {idx}: tx sim={po.get('tx')} golden={po_golden['tx']}"
            f" (rx={pi_dict['rx']})")
        tx_trace.append(po["tx"])

    # semantic check on top of the bit-true trace: the echoed frames are
    # exactly the sent bytes, and the framing-error byte is dropped.
    got = _decode_uart(tx_trace)
    assert got == [0x55, 0x00, 0xFF, 0xA7, 0x3C, 0xC3], (
        f"fabric echo mismatch: got {[hex(b) for b in got]}")


def _decode_uart(trace: list[int]) -> list[int]:
    """Decode UART frames (byte values) from a per-cycle tx trace."""
    cpb = UART_CPB
    out: list[int] = []
    i = 1
    while i < len(trace):
        if (trace[i] == 0 and trace[i - 1] == 1          # start-bit edge
                and i + 9 * cpb + cpb // 2 < len(trace)):
            base = i + cpb + cpb // 2                    # data bit 0 centre
            bits = [trace[base + k * cpb] for k in range(8)]
            stop = trace[base + 8 * cpb]
            if stop == 1:                     # framing-error frames dropped
                out.append(sum(b << k for k, b in enumerate(bits)))
            i += 10 * cpb
        else:
            i += 1
    return out


# =============================================================================
# Signature vs the daemon keyring + session-JSON replay contract
# =============================================================================

@pytest.mark.parametrize("name", list(IMAGES))
def test_ethimg_verify_vs_daemon_keyring(name):
    eth = ethimg.Path(DEMOS) / f"{name}.eth"
    if not eth.exists():
        pytest.skip(f"{eth} missing (run demo_images.py to build)")
    man = ethimg.verify(eth, trusted_pubkeys=[keyring_pub_pem()])
    cfg = IMAGES[name]
    assert man.target == cfg["fabric"]
    assert man.signature is not None and man.signature["algo"] == "ed25519"
    assert f"targets/{cfg['fabric']}.frames" in man.members
    assert f"targets/{cfg['fabric']}.meta.json" in man.members


@pytest.mark.parametrize("name", list(IMAGES))
def test_run_packed_session_json_contract(name):
    """The session JSONs replay under tb_ethctl_replay's line parser."""
    cfg = IMAGES[name]
    sess = os.path.join(ETHCTL, f"session_run_packed_{name}.json")
    if not os.path.exists(sess):
        pytest.skip(f"{sess} missing (run demo_images.py to build)")

    ops: list[dict] = []
    for line in open(sess, encoding="utf-8"):
        s = line.strip()
        if s.startswith('{"op":"'):
            ops.append(json.loads(s.rstrip(",")))
    doc = json.load(open(sess, encoding="utf-8"))
    assert doc["schema"] == "ethereal.efp-session.v0"
    assert len(ops) == doc["nops"]
    assert ops, "no ops in session"

    hexcount = 0
    for op in ops:
        assert op["op"] in ("write", "read", "poll", "stream")
        # addresses are short hex ("0x18"); 32-bit values are "0x%08x" —
        # the TB replayer scans "0x" + up to 8 hex digits for both.
        assert re.fullmatch(r"0x[0-9a-f]{1,8}", op["addr"])
        toks = [op.get("data"), op.get("mask"), op.get("value")]
        if op["op"] == "stream":
            assert re.fullmatch(r"0x[0-9a-f]{1,8}", op["addr"])
            toks = op.get("words") or []
        for tok in toks:
            if tok is not None:
                assert re.fullmatch(r"0x[0-9a-f]{8}", tok), f"bad token {tok}"
                hexcount += 1

    # stream ops carry exactly one column of DATA words each
    fg = FabricGen.from_file(os.path.join(FABRIC_DIR, f"{cfg['fabric']}.yaml"))
    streams = [op for op in ops if op["op"] == "stream"]
    assert len(streams) == fg.C
    for s in streams:
        assert len(s["words"]) == fg.fm.data_words_per_frame
    # total streamed words == the .eth frames member length
    shipped, _ = _shipped_frames(name)
    assert sum(len(s["words"]) for s in streams) == len(shipped)
    # EFP_IMG_WORDS staged = per-column DATA count (emri-v0 §3.3)
    w_ops = [op for op in ops if op["op"] == "write"]
    img_words = [op for op in w_ops if op.get("comment") == "EFP_IMG_WORDS"]
    assert img_words and int(img_words[0]["data"], 16) == \
        fg.fm.data_words_per_frame
    assert hexcount > 0
