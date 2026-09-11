# SPDX-License-Identifier: MIT
"""Tests for ethctl + daemon (S08 / E1-RUN2/3) and the EMRI constant cross-check."""
from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

import pytest

_THIS_DIR = str(Path(__file__).resolve().parent)
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

import efp_client
import ethimg
from emri_constants import (
    EFP_CMD_RUN,
    EFP_CMD_RUN_PACKED,
    EFP_ERR_BAD_CMD,
    EFP_ERR_BAD_SIG,
    EFP_ERR_IMG_LEN_MISMATCH,
    EFP_ERR_NONE,
    EFP_ERR_OCC_CRC,
    EFP_ERR_OCC_REJECT,
    EFP_ERR_REGION_FULL,
    EFP_ERR_REGION_LOCKED,
    EFP_REGION_AUTO,
    EFP_S_ERROR,
    EFP_S_IDLE,
    EFP_S_LOAD,
    EFP_S_RUNNING,
    EFP_S_STOPPED,
    IMG_SIG_WORDS,
    OCC_BLANK,
    OCC_CMD_START,
    OCC_S_DONE,
    OCC_WRITE,
    R_EFP_CMD,
    R_EFP_ERR,
    R_EFP_IMG_COLS,
    R_EFP_IMG_WORDS,
    R_EFP_REGION,
    R_EFP_STATUS,
    R_IMG_DIGEST,
    R_IMG_SIG,
    R_OCC_CMD,
    R_OCC_STATUS,
    R_OCC_WDATA,
)
from ethctl import (
    Daemon,
    DaemonError,
    PythonEmriModel,
    RecordTransport,
)

# --------------------------------------------------------------------------- #
# EMRI constant cross-check: Python mirror must match emri_pkg.sv
# --------------------------------------------------------------------------- #
_PKG_PATH = (
    Path(__file__).resolve().parents[2]
    / "ethereal-shell" / "rtl" / "emri" / "emri_pkg.sv"
)


def _pkg_localparams() -> dict[str, str]:
    """Parse `localparam ... = <value>;` lines from emri_pkg.sv -> {name: value_str}."""
    txt = _PKG_PATH.read_text()
    out: dict[str, str] = {}
    # matches: localparam logic [N:0] NAME = <expr>;   OR   localparam int NAME = <expr>;
    for m in re.finditer(
        r"localparam\s+(?:logic\s*\[[^\]]+\]|int)\s+(\w+)\s*=\s*([^;]+);", txt
    ):
        out[m.group(1)] = m.group(2).strip()
    return out


def test_emri_constants_match_pkg_sv():
    """Drift between emri_constants.py and emri_pkg.sv is a silent ABI break."""
    import emri_constants as ec

    pkg = _pkg_localparams()
    pairs = [
        ("EMRI_MAGIC", "EMRI_MAGIC"),
        ("R_MAGIC", "R_MAGIC"),
        ("R_CAPABILITIES", "R_CAPABILITIES"),
        ("R_OCC_CMD", "R_OCC_CMD"),
        ("R_OCC_WDATA", "R_OCC_WDATA"),
        ("R_OCC_STATUS", "R_OCC_STATUS"),
        ("R_OCC_FRAME_ADDR", "R_OCC_FRAME_ADDR"),
        ("R_OCC_WORD_COUNT", "R_OCC_WORD_COUNT"),
        ("R_HEALTH_STATUS", "R_HEALTH_STATUS"),
        ("OCC_WRITE", "OCC_WRITE"),
        ("OCC_BLANK", "OCC_BLANK"),
        ("OCC_S_DONE", "OCC_S_DONE"),
        ("OCC_S_NEEDS_BLANK", "OCC_S_NEEDS_BLANK"),
        ("OCC_CMD_START", "OCC_CMD_START"),
        ("SPI_OP_WR", "SPI_OP_WR"),
        ("SPI_OP_OCC_PUSH", "SPI_OP_OCC_PUSH"),
        # EFP command block (emri-v0.md sec 3.2, v0.2)
        ("R_EFP_CMD", "R_EFP_CMD"),
        ("R_EFP_REGION", "R_EFP_REGION"),
        ("R_EFP_IMG_WORDS", "R_EFP_IMG_WORDS"),
        ("R_EFP_STATUS", "R_EFP_STATUS"),
        ("R_EFP_ERR", "R_EFP_ERR"),
        ("R_EFP_IMG_COLS", "R_EFP_IMG_COLS"),
        ("R_IMG_DIGEST", "R_IMG_DIGEST"),
        ("R_IMG_SIG", "R_IMG_SIG"),
        ("IMG_DIGEST_WORDS", "IMG_DIGEST_WORDS"),
        ("IMG_SIG_WORDS", "IMG_SIG_WORDS"),
        ("EFP_CMD_NOP", "EFP_CMD_NOP"),
        ("EFP_CMD_RUN", "EFP_CMD_RUN"),
        ("EFP_CMD_STOP", "EFP_CMD_STOP"),
        ("EFP_CMD_RESTART", "EFP_CMD_RESTART"),
        ("EFP_CMD_ABORT", "EFP_CMD_ABORT"),
        ("EFP_CMD_RUN_PACKED", "EFP_CMD_RUN_PACKED"),
        ("EFP_REGION_AUTO", "EFP_REGION_AUTO"),
        ("EFP_S_IDLE", "EFP_S_IDLE"),
        ("EFP_S_VERIFY", "EFP_S_VERIFY"),
        ("EFP_S_ALLOC", "EFP_S_ALLOC"),
        ("EFP_S_BLANK", "EFP_S_BLANK"),
        ("EFP_S_LOAD", "EFP_S_LOAD"),
        ("EFP_S_READBACK", "EFP_S_READBACK"),
        ("EFP_S_RUNNING", "EFP_S_RUNNING"),
        ("EFP_S_ERROR", "EFP_S_ERROR"),
        ("EFP_S_STOPPED", "EFP_S_STOPPED"),
        ("EFP_ERR_NONE", "EFP_ERR_NONE"),
        ("EFP_ERR_BAD_SIG", "EFP_ERR_BAD_SIG"),
        ("EFP_ERR_REGION_FULL", "EFP_ERR_REGION_FULL"),
        ("EFP_ERR_REGION_LOCKED", "EFP_ERR_REGION_LOCKED"),
        ("EFP_ERR_OCC_CRC", "EFP_ERR_OCC_CRC"),
        ("EFP_ERR_OCC_REJECT", "EFP_ERR_OCC_REJECT"),
        ("EFP_ERR_BAD_CMD", "EFP_ERR_BAD_CMD"),
        ("EFP_ERR_IMG_LEN_MISMATCH", "EFP_ERR_IMG_LEN_MISMATCH"),
        # EFP-SPI CRC16 addendum (emri-v0.md sec 7.1, v0.3)
        ("EFP_ERR_CRC_TRANSPORT", "EFP_ERR_CRC_TRANSPORT"),
        ("SPI_STAT_CRC_ERR", "SPI_STAT_CRC_ERR"),
        ("SPI_STAT_NOT_READY", "SPI_STAT_NOT_READY"),
        ("R_SPI_CRC", "R_SPI_CRC"),
        # Event-log ring + watchdog/fwupdate (emri-v0.md sec 3.4-3.6, v0.4)
        ("R_EVT_LOG_CTRL", "R_EVT_LOG_CTRL"),
        ("R_EVT_LOG_DATA", "R_EVT_LOG_DATA"),
        # OCC expected-CRC gate (emri-v0.md sec 3.1.1, v0.5)
        ("R_OCC_EXPECT_CRC", "R_OCC_EXPECT_CRC"),
        ("R_OCC_CRC_RESULT", "R_OCC_CRC_RESULT"),
        ("EVT_LOG_DEPTH", "EVT_LOG_DEPTH"),
        ("EVT_LOG_CLEAR", "EVT_LOG_CLEAR"),
        ("EVT_CODE_WATCHDOG_TIMEOUT", "EVT_CODE_WATCHDOG_TIMEOUT"),
        ("EVT_CODE_HB_MISMATCH", "EVT_CODE_HB_MISMATCH"),
        ("EVT_CODE_SLOT_CHANGE", "EVT_CODE_SLOT_CHANGE"),
        ("EFP_ERR_WATCHDOG_TIMEOUT", "EFP_ERR_WATCHDOG_TIMEOUT"),
        ("EFP_ERR_FWUPDATE", "EFP_ERR_FWUPDATE"),
        ("EFP_CMD_FWUPDATE", "EFP_CMD_FWUPDATE"),
        ("EFP_CMD_REBOOT", "EFP_CMD_REBOOT"),
    ]
    assert pkg, "failed to parse any localparams from emri_pkg.sv"
    for py_name, sv_name in pairs:
        assert sv_name in pkg, f"{sv_name} missing from emri_pkg.sv"
        py_val = getattr(ec, py_name)
        sv_val = _eval_sv_value(pkg[sv_name])
        assert py_val == sv_val, (
            f"{py_name}: Python={py_val:#x} vs SV({sv_name})={sv_val:#x} ({pkg[sv_name]})"
        )


def _eval_sv_value(expr: str) -> int:
    """Evaluate a SystemVerilog localparam value expr to an int."""
    e = expr.strip()
    e = e.replace(";", "").strip()
    # strip trailing comments
    e = re.sub(r"//.*$", "", e).strip()
    # common SV forms: 32'hXXXX_XXXX, 2'dN, 1<<N, 1'b0
    m = re.fullmatch(r"\d+'h([0-9a-fA-F_]+)", e)
    if m:
        return int(m.group(1).replace("_", ""), 16)
    m = re.fullmatch(r"\d+'d(\d+)", e)
    if m:
        return int(m.group(1))
    m = re.fullmatch(r"\d+'b([01_]+)", e)
    if m:
        return int(m.group(1).replace("_", ""), 2)
    # decimal or expression like (1 << 8)
    e2 = e.replace("_", "")
    if re.fullmatch(r"\d+", e2):
        return int(e2)
    # evaluate simple integer expressions (1 << 8, etc.)
    if re.fullmatch(r"[\d \t\+\-\*\/\(\)<<]+", e2):
        return int(eval(e2, {"__builtins__": {}}, {}))
    raise AssertionError(f"cannot evaluate SV value: {expr!r}")


# --------------------------------------------------------------------------- #
# Daemon sequencing against the Python model
# --------------------------------------------------------------------------- #
@pytest.fixture
def daemon_model() -> tuple[Daemon, PythonEmriModel]:
    model = PythonEmriModel()
    return Daemon(model), model


def test_inspect(daemon_model):
    daemon, _ = daemon_model
    info = daemon.inspect()
    assert info["magic_ok"] is True
    assert info["has_bmc"] is False
    assert info["num_regions"] == 2
    assert len(info["regions"]) == 2


def test_ps(daemon_model):
    daemon, _ = daemon_model
    rows = daemon.ps()
    assert len(rows) == 2
    assert rows[0]["healthy"] is True
    assert rows[0]["region"] == 0


def test_deploy_writes_all_words(daemon_model):
    daemon, model = daemon_model
    frames = b"".join(struct.pack("<I", 0x1000 + i) for i in range(8))
    r = daemon.deploy(frames, region=1, frame_addr=0x2000)
    assert r.words_written == 8
    assert r.region == 1
    # the WRITE should have streamed all 8 words into the OCC store
    assert len(model._occ.store) == 8
    assert model._occ.store[0] == 0x1000
    assert model._occ.store[7] == 0x1007


def test_deploy_blank_first_default(daemon_model):
    daemon, model = daemon_model
    frames = struct.pack("<I", 0xABCDEF01)
    daemon.deploy(frames, region=0, frame_addr=0x100)
    # the model issued a BLANK (status went DONE) before WRITE
    assert model._occ.status == OCC_S_DONE


def test_deploy_rejects_non_word_aligned(daemon_model):
    daemon, _ = daemon_model
    with pytest.raises(DaemonError):
        daemon.deploy(b"\x01\x02\x03", region=0)  # 3 bytes


def test_deploy_rejects_empty(daemon_model):
    daemon, _ = daemon_model
    with pytest.raises(DaemonError):
        daemon.deploy(b"", region=0)


# --------------------------------------------------------------------------- #
# Record transport -> deploy plan (the SV TB input)
# --------------------------------------------------------------------------- #
def test_record_transport_produces_plan(tmp_path):
    model = PythonEmriModel()
    daemon = Daemon(model)  # drive the model to produce side effects
    frames = b"".join(struct.pack("<I", i) for i in range(4))
    r = daemon.deploy(frames, region=0, frame_addr=0x100)
    assert r.words_written == 4

    # Now drive a RecordTransport with the SAME frames and check the plan shape
    rec = RecordTransport()
    rec_daemon = Daemon(rec)
    rec_daemon.deploy(frames, region=0, frame_addr=0x100)
    plan = rec.to_plan("unit", [0, 1, 2, 3], 0)
    assert plan["schema"] == "ethereal.deploy-plan.v0"
    assert plan["region"] == 0
    assert plan["frames_words"] == [0, 1, 2, 3]
    ops = [t["op"] for t in plan["txn_log"]]
    # expect: reads (magic/caps), blank (frame addr + wc + cmd), write (frame addr+wc+cmd), pushes
    assert ops.count("push") == 4
    assert "wr" in ops  # register writes present
    # the plan JSON is serializable & valid
    json.loads(json.dumps(plan))


def test_plan_has_blank_then_write_order(tmp_path):
    """The deploy plan MUST blank before write (FABulous red line)."""
    rec = RecordTransport()
    daemon = Daemon(rec)
    frames = struct.pack("<I", 0x12345678)
    daemon.deploy(frames, region=0, frame_addr=0x100)
    plan = rec.to_plan("x", [0x12345678], 0)
    cmds = [t["data"] for t in plan["txn_log"] if t["addr"] == R_OCC_CMD]
    # exactly 2 OCC_CMD writes: BLANK then WRITE (each with START bit set)
    assert len(cmds) == 2
    assert (cmds[0] & 0x3) == OCC_BLANK
    assert (cmds[1] & 0x3) == OCC_WRITE
    assert all(c & (1 << OCC_CMD_START) for c in cmds)


# --------------------------------------------------------------------------- #
# end-to-end: ethimg pack -> ethctl deploy_image -> model
# --------------------------------------------------------------------------- #
def test_deploy_image_end_to_end(tmp_path):
    # build a tiny .eth
    src = tmp_path / "img"
    (src / "targets").mkdir(parents=True)
    frames = b"".join(struct.pack("<I", 0xDEAD0000 + i) for i in range(4))
    (src / "targets" / "efab-1.0.frames").write_bytes(frames)
    (src / "targets" / "efab-1.0.meta.json").write_text('{"frames":1,"words":4}')
    out = tmp_path / "img.eth"
    ethimg.pack(src, out, name="e2e", allow_unsigned=True) if False else ethimg.pack(
        src, out, name="e2e"
    )
    # deploy to the model (allow_unsigned since no key)
    model = PythonEmriModel()
    daemon = Daemon(model)
    r = daemon.deploy_image(out, region=0, allow_unsigned=True)
    assert r.words_written == 4
    assert model._occ.store[0] == 0xDEAD0000
    assert model._occ.store[3] == 0xDEAD0003


# --------------------------------------------------------------------------- #
# CLI smoke
# --------------------------------------------------------------------------- #
def test_cli_inspect_plan_mode(capsys):
    from ethctl import _cli

    rc = _cli(["inspect"])
    out = capsys.readouterr().out
    assert rc == 0
    assert '"has_bmc": false' in out


# --------------------------------------------------------------------------- #
# EFP client (emri-v0.md sec 3.2, v0.2 / E1-RUN3)
# --------------------------------------------------------------------------- #
_DAEMON_DIR = (
    Path(__file__).resolve().parents[2] / "ethereal-runtime" / "bmc-fw" / "daemon"
)
if str(_DAEMON_DIR) not in sys.path:
    sys.path.insert(0, str(_DAEMON_DIR))

# Known-answer vectors from the E1-RUN2 deterministic fixed-seed key
# (gen_daemon_vectors.KEY_SEED; identical to the committed
# generated/daemon/tb_daemon_vectors.svh DAEMON_IMG_A_DIGEST/SIG words and the
# bmc-fw keyring.h trusted public key).
# v2c note (2026-09-02): IMG_A_WORDS IIB sel 18→0 (spec §7.2) changed the digest;
# constants below regenerated via gen_daemon_vectors + efp_client.words_from_bytes.
KAT_DIGEST_A = "ed06aeb606cd156a4ca3d9053541e6849c9cc0e169d072c770e197a04e2c5936"
KAT_DIGEST_WORDS = [
    0xB6AE06ED, 0x6A15CD06, 0x05D9A34C, 0x84E64135,
    0xE1C09C9C, 0xC772D069, 0xA097E170, 0x36592C4E,
]
KAT_SIG_WORDS = [
    0x5CCED21D, 0x4C3E69A4, 0x5E732E6F, 0xE58677D7,
    0xC1D0C2BC, 0xB1B9FC03, 0x610E3686, 0xB69EE5F0,
    0xE6359FFE, 0xE29C7BDA, 0x9775A13E, 0x9B8CDE71,
    0x8A36B494, 0x0E13752D, 0xAA207530, 0x06F15961,
]


def _fixed_keypair():
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from gen_daemon_vectors import KEY_SEED

    sk = Ed25519PrivateKey.from_private_bytes(KEY_SEED)
    pem = sk.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return pem, sk.public_key().public_bytes_raw()


def _signed_eth(tmp_path: Path, name: str = "efp-img"):
    """Pack+sign image A (TFF, 12 words, v0 cfg-addr) with the daemon test key."""
    from gen_daemon_vectors import IMG_A_WORDS

    priv_pem, pk_raw = _fixed_keypair()
    src = tmp_path / "src"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(
        b"".join(w.to_bytes(4, "little") for w in IMG_A_WORDS)
    )
    out = tmp_path / f"{name}.eth"
    ethimg.pack(src, out, name=name, target="efab-1.0", privkey_pem=priv_pem)
    return out, pk_raw, list(IMG_A_WORDS)


def test_efp_digest_sig_byte_packing_kat():
    """Word i = bytes[4i+3:4i] (LE in-word) — pinned to the E1-RUN2 vectors."""
    import hashlib

    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from gen_daemon_vectors import IMG_A_WORDS, KEY_SEED, _words_to_bytes

    dig = hashlib.sha256(_words_to_bytes(IMG_A_WORDS)).digest()
    assert dig.hex() == KAT_DIGEST_A
    sig = Ed25519PrivateKey.from_private_bytes(KEY_SEED).sign(
        dig.hex().encode("utf-8")
    )
    assert efp_client.words_from_bytes(dig) == KAT_DIGEST_WORDS
    assert efp_client.words_from_bytes(sig) == KAT_SIG_WORDS


def test_efp_err_decode_all_codes():
    """All 8 v0.2 EFP_ERR codes decode to their spec names."""
    expected = {
        EFP_ERR_NONE: "none",
        EFP_ERR_BAD_SIG: "bad_sig",
        EFP_ERR_REGION_FULL: "region_full",
        EFP_ERR_REGION_LOCKED: "region_locked",
        EFP_ERR_OCC_CRC: "occ_crc",
        EFP_ERR_OCC_REJECT: "occ_reject",
        EFP_ERR_BAD_CMD: "bad_cmd",
        EFP_ERR_IMG_LEN_MISMATCH: "img_len_mismatch",
    }
    assert len(expected) == 8
    for code, name in expected.items():
        assert efp_client.decode_err(code) == name
    assert efp_client.decode_err(9).startswith("unknown")


def test_efp_state_decode_all():
    for code, name in [
        (EFP_S_IDLE, "IDLE"), (EFP_S_LOAD, "LOAD"), (EFP_S_RUNNING, "RUNNING"),
        (EFP_S_ERROR, "ERROR"), (EFP_S_STOPPED, "STOPPED"),
    ]:
        assert efp_client.decode_state(code) == name
    assert efp_client.decode_state(15).startswith("unknown")


def test_efp_run_session_op_order(tmp_path):
    """The run session must mirror spec sec 3.2 steps 1-6 exactly."""
    eth, _, img_words = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    ops, img = client.run_image(eth, EFP_REGION_AUTO)
    assert img.frame_words == img_words

    dw = efp_client.words_from_bytes(img.digest32)
    sw = efp_client.words_from_bytes(img.sig64)
    # step 1: stage IMG_DIGEST[0..7] + IMG_SIG[0..15] + IMG_WORDS + REGION
    for i in range(8):
        assert ops[i].op == "write" and ops[i].addr == R_IMG_DIGEST + i
        assert ops[i].data == dw[i]
    for i in range(IMG_SIG_WORDS):
        assert ops[8 + i].op == "write" and ops[8 + i].addr == R_IMG_SIG + i
        assert ops[8 + i].data == sw[i]
    assert ops[24].addr == R_EFP_IMG_WORDS and ops[24].data == len(img_words)
    assert ops[25].addr == R_EFP_REGION and ops[25].data == EFP_REGION_AUTO
    # busy=0 BEFORE the doorbell (single-outstanding-command rule)
    assert ops[26].op == "poll" and ops[26].addr == R_EFP_STATUS
    assert ops[26].mask == 0x10 and ops[26].value == 0
    assert ops[27].op == "write" and ops[27].addr == R_EFP_CMD
    assert ops[27].data == EFP_CMD_RUN
    # step 5: wait for LOAD (OCC WRITE already armed), then stream
    assert ops[28].op == "poll" and ops[28].mask == 0x0F
    assert ops[28].value == EFP_S_LOAD
    assert ops[29].op == "stream" and ops[29].addr == R_OCC_WDATA
    assert ops[29].words == img_words
    # step 6: terminal-state completion poll (busy=0 AND state==RUNNING; a
    # bare busy=0 poll would race the daemon's accept latency) + self-checks
    assert ops[30].op == "poll" and ops[30].mask == 0x1F
    assert ops[30].value == EFP_S_RUNNING
    assert ops[31].op == "read" and ops[31].addr == R_EFP_STATUS
    assert ops[31].mask == 0x3F and ops[31].value == EFP_S_RUNNING | 0x20
    assert ops[32].op == "read" and ops[32].addr == R_EFP_ERR
    assert ops[32].mask == 0xFF and ops[32].value == EFP_ERR_NONE
    assert len(ops) == 33


def test_efp_run_happy_path_model(tmp_path):
    eth, pk, img_words = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    ops, _ = client.run_image(eth, EFP_REGION_AUTO)
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    efp_client.execute_ops(ops, model)
    assert model.read(R_EFP_STATUS) == EFP_S_RUNNING | 0x20
    assert model.read(R_EFP_ERR) == EFP_ERR_NONE
    assert model.region_state(0) == 1  # RUNNING (auto-alloc picked region 0)
    assert model._streamed == len(img_words)


# --------------------------------------------------------------------------- #
# run_packed (emri-v0.md sec 3.3, v0.3): bit-packed per-column deploy
# --------------------------------------------------------------------------- #
_PACKED_COLUMNS = [
    [0x1111_0000, 0x1111_0001, 0x1111_0002, 0x1111_0003],
    [0x2222_0000, 0x2222_0001, 0x2222_0002, 0x2222_0003],
]


def _signed_packed_eth(tmp_path: Path, columns, name: str = "efp-packed"):
    """Pack+sign a PACKED image (per-column DATA words concatenated, CRC16
    tails excluded — the .eth packed-frames convention, spec sec 3.3)."""
    priv_pem, pk_raw = _fixed_keypair()
    src = tmp_path / "src_packed"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(
        b"".join(w.to_bytes(4, "little") for col in columns for w in col)
    )
    out = tmp_path / f"{name}.eth"
    ethimg.pack(src, out, name=name, target="efab-1.0", privkey_pem=priv_pem)
    return out, pk_raw


def test_efp_run_packed_session_op_order(tmp_path):
    """The run_packed session must mirror spec sec 3.3: stage (+IMG_COLS),
    doorbell run_packed, per-column handshake + stream, terminal checks."""
    eth, _ = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    client = efp_client.EfpClient()
    ops, img = client.run_packed(eth, EFP_REGION_AUTO, column_words=4)
    streams = [o for o in ops if o.op == "stream"]
    # one stream per column, each carrying exactly that column's DATA words
    assert len(streams) == len(_PACKED_COLUMNS)
    for c, s in enumerate(streams):
        assert s.addr == R_OCC_WDATA
        assert s.words == _PACKED_COLUMNS[c]
    # staging includes EFP_IMG_COLS = number of columns and per-column words
    cols_wr = [o for o in ops if o.op == "write" and o.addr == R_EFP_IMG_COLS]
    assert len(cols_wr) == 1 and cols_wr[0].data == len(_PACKED_COLUMNS)
    words_wr = [o for o in ops if o.op == "write" and o.addr == R_EFP_IMG_WORDS]
    assert len(words_wr) == 1 and words_wr[0].data == 4
    # exactly one doorbell write, code run_packed
    doorbell = [o for o in ops if o.op == "write" and o.addr == R_EFP_CMD]
    assert [o.data for o in doorbell] == [EFP_CMD_RUN_PACKED]
    # per-column handshake: column c>0 polls OCC_STATUS done_flag 1 -> 0
    # before its stream; column 0 polls state==LOAD directly
    first_stream = ops.index(streams[0])
    second_stream = ops.index(streams[1])
    between = ops[first_stream + 1 : second_stream]
    flag_polls = [o for o in between if o.op == "poll" and o.addr == R_OCC_STATUS]
    assert [(o.mask, o.value) for o in flag_polls] == [(0x08, 0x08), (0x08, 0x00)]
    before_first = ops[:first_stream]
    assert any(
        o.op == "poll" and o.addr == R_EFP_STATUS and o.value == EFP_S_LOAD
        for o in before_first
    ), "column 0 must poll state==LOAD before streaming"
    # terminal: RUNNING+busy=0 poll, RUNNING+done read, EFP_ERR=none read
    assert ops[-2].op == "read" and ops[-2].addr == R_EFP_STATUS
    assert ops[-2].value == EFP_S_RUNNING | 0x20
    assert ops[-1].op == "read" and ops[-1].addr == R_EFP_ERR
    assert ops[-1].value == EFP_ERR_NONE
    # session JSON stays transport-ready (one op per line, self-describing)
    text = efp_client.session_to_json(ops, name="packed", image=img,
                                      region=EFP_REGION_AUTO)
    doc = json.loads(text)
    assert doc["schema"] == "ethereal.efp-session.v0"
    assert doc["nops"] == len(ops)


def test_efp_run_packed_happy_path_model(tmp_path):
    """run_packed drives the model daemon to RUNNING over 2 columns."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    client = efp_client.EfpClient()
    ops, _ = client.run_packed(eth, EFP_REGION_AUTO, column_words=4)
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    efp_client.execute_ops(ops, model)
    assert model.read(R_EFP_STATUS) == EFP_S_RUNNING | 0x20
    assert model.read(R_EFP_ERR) == EFP_ERR_NONE
    assert model.region_state(0) == 1  # RUNNING
    assert model._streamed == sum(len(c) for c in _PACKED_COLUMNS)


def test_efp_run_packed_bad_sig_rejected(tmp_path):
    """Tampered signature -> EFP_ERR=bad_sig, state ERROR (same as run)."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    img = efp_client.load_image(eth)
    bad_sig = bytes([img.sig64[0] ^ 0x01]) + img.sig64[1:]
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    s = efp_client.EfpSession()
    s.run_packed(img.digest32, bad_sig, _PACKED_COLUMNS, EFP_REGION_AUTO)
    with pytest.raises(efp_client.EfpError, match="poll timeout"):
        efp_client.execute_ops(s.ops, model)
    assert model.read(R_EFP_ERR) & 0xFF == EFP_ERR_BAD_SIG
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_ERROR
    assert model.region_state(0) == 0  # fabric untouched


def test_efp_run_packed_geometry_validation(tmp_path):
    """Client-side geometry checks (v0 homogeneous, region->column mapping)."""
    eth, _ = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    client = efp_client.EfpClient()
    # ragged columns (not homogeneous)
    with pytest.raises(efp_client.EfpError, match="homogeneous"):
        efp_client.EfpSession().run_packed(
            bytes(32), bytes(64), [[1, 2], [3]], EFP_REGION_AUTO
        )
    # no columns
    with pytest.raises(efp_client.EfpError, match="no columns"):
        efp_client.EfpSession().run_packed(bytes(32), bytes(64), [], 0)
    # .eth without column_words
    with pytest.raises(efp_client.EfpError, match="column_words"):
        client.run_packed(eth, EFP_REGION_AUTO)
    # more columns than fit from an explicit region (2 regions, region 1)
    with pytest.raises(efp_client.EfpError, match="do not fit"):
        client.run_packed(eth, 1, column_words=4)
    # flat word list not a multiple of column_words
    with pytest.raises(efp_client.EfpError, match="multiple"):
        client.run_packed([0] * 6, EFP_REGION_AUTO, column_words=4)


def test_efp_busy_before_cmd_rejected(tmp_path):
    """A doorbell write while busy is ignored + flagged bad_cmd (spec 3.2)."""
    eth, pk, img_words = _signed_eth(tmp_path)
    img = efp_client.load_image(eth)
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    s = efp_client.EfpSession()
    s.stage_image(img.digest32, img.sig64, len(img.frame_words), EFP_REGION_AUTO)
    s.cmd(EFP_CMD_RUN)
    efp_client.execute_ops(s.ops, model)
    assert model.read(R_EFP_STATUS) & 0x10  # busy
    # non-compliant host: write EFP_CMD=stop while the run is in flight
    model.write(R_EFP_CMD, 2)
    # drive the run to completion (stream during LOAD)
    for _ in range(100):
        if not (model.read(R_EFP_STATUS) & 0x10):
            break
        if (model.read(R_EFP_STATUS) & 0xF) == EFP_S_LOAD:
            for w in img_words:
                model.write(R_OCC_WDATA, w)
        model.tick()
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_RUNNING  # squelched cmd
    assert model.read(R_EFP_ERR) & 0xFF == EFP_ERR_BAD_CMD


def test_efp_bad_sig_rejected(tmp_path):
    """Tampered signature -> EFP_ERR=bad_sig, state ERROR, region untouched."""
    eth, pk, _ = _signed_eth(tmp_path)
    img = efp_client.load_image(eth)
    bad_sig = bytes([img.sig64[0] ^ 0x01]) + img.sig64[1:]
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    s = efp_client.EfpSession()
    s.stage_image(img.digest32, bad_sig, len(img.frame_words), EFP_REGION_AUTO)
    s.cmd(EFP_CMD_RUN)
    s.poll_status(0x10, 0)
    s.read(R_EFP_ERR, 0xFF, EFP_ERR_BAD_SIG)  # self-checking read
    efp_client.execute_ops(s.ops, model)
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_ERROR
    assert model.region_state(0) == 0  # still FREE: fabric untouched


def test_efp_stop_restart_semantics(tmp_path):
    eth, pk, _ = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    model = efp_client.EfpDaemonModel(trusted_pk=pk)

    run_ops, _ = client.run_image(eth, EFP_REGION_AUTO)
    efp_client.execute_ops(run_ops, model)
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_RUNNING

    stop_ops = client.stop(0)
    efp_client.execute_ops(stop_ops, model)
    st = model.read(R_EFP_STATUS)
    assert st & 0xF == EFP_S_STOPPED and not (st & 0x20)  # STOPPED, done=0
    assert model.region_state(0) == 0  # FREE again

    # re-run, then restart (re-verify + re-stream of the last staged image)
    efp_client.execute_ops(client.run_image(eth, EFP_REGION_AUTO)[0], model)
    rst_ops, _ = client.restart(eth)
    efp_client.execute_ops(rst_ops, model)
    st = model.read(R_EFP_STATUS)
    assert st & 0xF == EFP_S_RUNNING and st & 0x20
    assert model.read(R_EFP_ERR) == EFP_ERR_NONE

    # abort -> IDLE, region blanked
    efp_client.execute_ops(client.abort(), model)
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_IDLE
    assert model.region_state(0) == 0


def test_efp_ps_pure_read():
    ops = efp_client.EfpClient().ps()
    assert not any(o.addr == R_EFP_CMD for o in ops)  # ps never rings the bell
    assert ops[0].op == "read" and ops[0].addr == R_EFP_STATUS
    assert ops[1].op == "read" and ops[1].addr == R_EFP_ERR
    model = efp_client.EfpDaemonModel()
    reads = efp_client.execute_ops(ops, model)
    assert reads[0] == EFP_S_IDLE  # fresh daemon: IDLE, not busy, not done


def test_efp_session_json_self_describing(tmp_path):
    eth, _, img_words = _signed_eth(tmp_path)
    ops, img = efp_client.EfpClient().run_image(eth, EFP_REGION_AUTO)
    text = efp_client.session_to_json(ops, name="run", image=img, region=0xFF)
    doc = json.loads(text)
    assert doc["schema"] == "ethereal.efp-session.v0"
    assert doc["nops"] == len(ops)
    assert doc["image"]["manifest_digest"] == img.manifest_digest_hex
    assert doc["image"]["words"] == len(img_words)
    op_lines = [ln for ln in text.splitlines() if ln.strip().startswith('{"op":"')]
    assert len(op_lines) == len(ops)  # one op per line (SV-parseable)
    for o in doc["ops"]:
        assert o["op"] in ("write", "read", "poll", "stream")
        assert int(o["addr"], 16) >= 0
        if o["op"] == "write":
            assert 0 <= int(o["data"], 16) <= 0xFFFFFFFF
        if o["op"] in ("read", "poll"):
            assert "mask" in o and "value" in o
        if o["op"] == "stream":
            assert o["count"] == len(o["words"]) == len(img_words)


def test_efp_build_demo_sessions(tmp_path):
    """The Makefile regen step: pack+sign .eth + ethctl-emitted session JSONs."""
    info = efp_client.build_demo_sessions(tmp_path / "gen")
    run = json.loads(Path(info["run"]).read_text())
    stop = json.loads(Path(info["stop"]).read_text())
    assert run["schema"] == stop["schema"] == "ethereal.efp-session.v0"
    streams = [o for o in run["ops"] if o["op"] == "stream"]
    assert len(streams) == 1 and streams[0]["count"] == 12
    assert ethimg.read_manifest(info["eth"]).manifest_digest == info["digest"]
    assert any(o.get("data") == "0x00000001" for o in run["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")  # EFP_CMD=run
    assert any(o.get("data") == "0x00000002" for o in stop["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")  # EFP_CMD=stop


# --------------------------------------------------------------------------- #
# EFP CLI integration
# --------------------------------------------------------------------------- #
def test_cli_efp_run_emit_session(tmp_path, capsys):
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    sess = tmp_path / "session.json"
    rc = _cli(["--transport", "efp", "run", str(eth), "--region", "auto",
               "--emit-session", str(sess)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "RUNNING" in out
    doc = json.loads(sess.read_text())
    assert doc["schema"] == "ethereal.efp-session.v0"


def test_cli_efp_stop_ps(tmp_path, capsys):
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    assert _cli(["--transport", "efp", "run", str(eth), "--region", "auto"]) == 0
    capsys.readouterr()
    assert _cli(["--transport", "efp", "ps"]) == 0
    assert "state=" in capsys.readouterr().out
    assert _cli(["--transport", "efp", "stop", "--region", "0"]) == 0
    assert "STOPPED" in capsys.readouterr().out


def test_cli_efp_restart_without_staged_image(tmp_path, capsys):
    """restart on a device with no staged image -> bad_cmd (spec sec 3.2).

    (The sim model is per-process; a real BMC retains the staged metadata
    across ethctl invocations. In-process restart semantics are covered by
    test_efp_stop_restart_semantics.)"""
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    sess = tmp_path / "restart.json"
    rc = _cli(["--transport", "efp", "restart", str(eth),
               "--emit-session", str(sess)])
    # session JSON is still emitted (the op list is valid); the fresh model
    # honestly reports the device-side bad_cmd.
    assert rc == 1
    assert "bad_cmd" in capsys.readouterr().err
    doc = json.loads(sess.read_text())
    assert any(o.get("data") == "0x00000003" for o in doc["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")


def test_cli_efp_unsigned_run_rejected(tmp_path):
    from ethctl import _cli

    src = tmp_path / "img"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(struct.pack("<I", 1))
    out = tmp_path / "u.eth"
    ethimg.pack(src, out, name="u")  # unsigned: daemon VERIFY must reject
    rc = _cli(["--transport", "efp", "run", str(out), "--region", "auto"])
    assert rc == 1


def test_cli_stop_needs_efp_transport(capsys):
    from ethctl import _cli

    rc = _cli(["stop", "--region", "0"])
    assert rc == 1
    assert "--transport efp" in capsys.readouterr().err


# --------------------------------------------------------------------------- #
# EFP-SPI framing (spec sec 7 request frames + sec 7.1 CRC16 tail op)
# --------------------------------------------------------------------------- #
def test_spi_frame_encoding_kat():
    """Exact wire bytes: OP | ADDR (BE16) | DATA (BE32), 7 bytes."""
    import emri_constants as ec

    s = efp_client.EfpSession()
    s.read(ec.R_MAGIC, comment="RD MAGIC")
    s.write(ec.R_EFP_REGION, 0, "WR EFP_REGION=0")
    s.write(ec.R_OCC_WDATA, 0xDEADBEEF, "WR -> OCC_PUSH")
    s.stream([0x11223344], "stream 1 word")
    frames = efp_client.to_spi_frames(s.ops)
    assert all(len(f) == efp_client.SPI_FRAME_LEN for f in frames)
    assert frames[0] == bytes([0x00, 0x00, 0x00, 0, 0, 0, 0])          # RD MAGIC
    assert frames[1] == bytes([0x01, 0x00, 0x14, 0, 0, 0, 0])          # WR 0x14
    # OCC_WDATA targets (write or stream) map to OCC_PUSH, addr 0x09, BE data
    assert frames[2] == bytes([0x03, 0x00, 0x09, 0xDE, 0xAD, 0xBE, 0xEF])
    assert frames[3] == bytes([0x03, 0x00, 0x09, 0x11, 0x22, 0x33, 0x44])


def test_spi_crc16_known_vector():
    """CRC-16/CCITT-FALSE check vector + frame_map algorithm identity."""
    import frame_map

    assert efp_client.crc16_bytes(b"123456789") == 0x29B1  # CCITT-FALSE check
    words = [0x00000000, 0x55700000, 0x00000015, 0xDEADBEEF]
    assert efp_client.crc16_words(words) == frame_map.crc16(words)
    # word orientation: big-endian bytes per word
    assert efp_client.crc16_words([0x31323334, 0x35363738]) == \
        efp_client.crc16_bytes(b"12345678")


def test_spi_crc_tail_op_placement():
    """run_packed: WR SPI_CRC(crc16 of ALL stream words) immediately precedes
    the EFP_CMD doorbell frame (spec sec 7.1 step 3 ordering)."""
    import emri_constants as ec

    s = efp_client.EfpSession()
    s.write(ec.R_EFP_IMG_WORDS, 2, "EFP_IMG_WORDS")
    s.write(ec.R_EFP_IMG_COLS, 1, "EFP_IMG_COLS")
    s.write(ec.R_EFP_REGION, 0, "EFP_REGION")
    s.cmd(ec.EFP_CMD_RUN_PACKED)  # emits busy-poll RD + doorbell WR
    s.poll(ec.R_EFP_STATUS, 0x0F, ec.EFP_S_LOAD, "wait LOAD")
    s.stream([0x11223344, 0x55667788], "col 0 DATA words")
    frames = efp_client.to_spi_frames(s.ops)

    want_crc = efp_client.crc16_words([0x11223344, 0x55667788])
    crc_frame = bytes([0x01, 0x00, ec.R_SPI_CRC]) + want_crc.to_bytes(4, "big")
    cmd_frame = bytes([0x01, 0x00, ec.R_EFP_CMD, 0, 0, 0, 5])
    assert crc_frame in frames and cmd_frame in frames
    # CRC latch immediately before the doorbell
    assert frames.index(cmd_frame) == frames.index(crc_frame) + 1
    # stream words follow the doorbell as OCC_PUSH frames
    pushes = [f for f in frames if f[0] == 0x03]
    assert pushes == [
        bytes([0x03, 0x00, 0x09]) + w.to_bytes(4, "big")
        for w in (0x11223344, 0x55667788)
    ]


def test_spi_no_crc_frame_without_run():
    """stop/ps sessions carry no SPI_CRC latch (no stream follows)."""
    s = efp_client.EfpSession()
    s.stop(0)
    frames = efp_client.to_spi_frames(s.ops)
    assert not any(f[:3] == bytes([0x01, 0x00, 0x3F]) for f in frames)
    assert any(f == bytes([0x01, 0x00, 0x13, 0, 0, 0, 2]) for f in frames)  # stop


def test_spi_status_and_err_decode():
    import emri_constants as ec

    assert efp_client.decode_spi_status(ec.SPI_STAT_OK) == "OK"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BAD_OP) == "BAD_OP"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BAD_ADDR) == "BAD_ADDR"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BUSY) == "BUSY"
    assert efp_client.decode_spi_status(ec.SPI_STAT_CRC_ERR) == "CRC_ERR"
    assert efp_client.decode_spi_status(ec.SPI_STAT_NOT_READY) == "NOT_READY"
    assert efp_client.decode_err(ec.EFP_ERR_CRC_TRANSPORT) == "crc_transport"
