# SPDX-License-Identifier: MIT
"""Tests for ethctl + daemon (S08 / E1-RUN2/3) and the EMRI constant cross-check."""
from __future__ import annotations

import io
import json
import re
import struct
import sys
import tarfile
from pathlib import Path

import pytest
import yaml

_THIS_DIR = str(Path(__file__).resolve().parent)
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# capcheck (E2-SEC1) lives in the sibling ethereal-runtime/security/ package.
_SECURITY_DIR = str(Path(__file__).resolve().parents[2] / "ethereal-runtime")
if _SECURITY_DIR not in sys.path:
    sys.path.insert(0, _SECURITY_DIR)

# pi-lens-ignore: E402
import efp_client
import ethimg
from emri_constants import (
    CAPB_HAS_BMC,
    EFP_CMD_RUN,
    EFP_CMD_RUN_PACKED,
    EFP_ERR_BAD_CMD,
    EFP_ERR_BAD_SIG,
    EFP_ERR_CAPABILITY_DENIED,
    EFP_ERR_CRC_TRANSPORT,
    EFP_ERR_FWUPDATE,
    EFP_ERR_IMG_LEN_MISMATCH,
    EFP_ERR_NONE,
    EFP_ERR_OCC_CRC,
    EFP_ERR_OCC_REJECT,
    EFP_ERR_RATE_LIMITED,
    EFP_ERR_REGION_FULL,
    EFP_ERR_REGION_LOCKED,
    EFP_ERR_WATCHDOG_TIMEOUT,
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
    R_CAP_DECL_IO,
    R_CAP_DECL_SVC,
    R_CAPABILITIES,
    R_EFP_CMD,
    R_EFP_ERR,
    R_EFP_IMG_COLS,
    R_EFP_IMG_WORDS,
    R_EFP_REGION,
    R_EFP_STATUS,
    R_IMG_DIGEST,
    R_IMG_SIG,
    R_MON_NOTIFY,
    R_OCC_CMD,
    R_OCC_FRAME_ADDR,
    R_OCC_STATUS,
    R_OCC_WDATA,
)
from ethctl import (
    Daemon,
    DaemonError,
    EmriMode,
    PythonEmriModel,
    RecordTransport,
    probe_mode,
    require_bmc,
    require_mfsm,
    resolve_mode,
)

# pi-lens-ignore: E402
from security import capcheck

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


def test_emri_constants_match_pkg_sv() -> None:
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
        # v0.6 sec 3.7/3.8: capability gate + anomaly monitor (E2-SEC1)
        ("R_CAP_DECL_IO", "R_CAP_DECL_IO"),
        ("R_CAP_DECL_SVC", "R_CAP_DECL_SVC"),
        ("R_CAP_STATUS", "R_CAP_STATUS"),
        ("R_MON_RECFG_COUNT", "R_MON_RECFG_COUNT"),
        ("R_MON_WDT_COUNT", "R_MON_WDT_COUNT"),
        ("R_MON_ANOM_STATUS", "R_MON_ANOM_STATUS"),
        ("R_MON_ANOM_WINDOW", "R_MON_ANOM_WINDOW"),
        ("R_MON_ANOM_THRESH", "R_MON_ANOM_THRESH"),
        ("R_MON_NOTIFY", "R_MON_NOTIFY"),
        ("EFP_ERR_CAPABILITY_DENIED", "EFP_ERR_CAPABILITY_DENIED"),
        ("EFP_ERR_RATE_LIMITED", "EFP_ERR_RATE_LIMITED"),
        # v0.7 sec 3.9: context save/restore orchestration (E2-FAB3b)
        ("R_CTX_CMD", "R_CTX_CMD"),
        ("R_CTX_WORDS", "R_CTX_WORDS"),
        ("R_CTX_STATUS", "R_CTX_STATUS"),
        ("EFP_CMD_CTX_SAVE", "EFP_CMD_CTX_SAVE"),
        ("EFP_CMD_CTX_RESTORE", "EFP_CMD_CTX_RESTORE"),
        ("EFP_S_PAUSED", "EFP_S_PAUSED"),
        ("EFP_ERR_CTX_ERROR", "EFP_ERR_CTX_ERROR"),
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


def test_inspect(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, _ = daemon_model
    info = daemon.inspect()
    assert info["magic_ok"] is True
    assert info["has_bmc"] is False
    assert info["num_regions"] == 2
    assert len(info["regions"]) == 2


def test_ps(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, _ = daemon_model
    rows = daemon.ps()
    assert len(rows) == 2
    assert rows[0]["healthy"] is True
    assert rows[0]["region"] == 0


def test_deploy_writes_all_words(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, model = daemon_model
    frames = b"".join(struct.pack("<I", 0x1000 + i) for i in range(8))
    r = daemon.deploy(frames, region=1, frame_addr=0x2000)
    assert r.words_written == 8
    assert r.region == 1
    # the WRITE should have streamed all 8 words into the OCC store
    assert len(model._occ.store) == 8
    assert model._occ.store[0] == 0x1000
    assert model._occ.store[7] == 0x1007


def test_deploy_blank_first_default(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, model = daemon_model
    frames = struct.pack("<I", 0xABCDEF01)
    daemon.deploy(frames, region=0, frame_addr=0x100)
    # the model issued a BLANK (status went DONE) before WRITE
    assert model._occ.status == OCC_S_DONE


def test_deploy_rejects_non_word_aligned(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, _ = daemon_model
    with pytest.raises(DaemonError):
        daemon.deploy(b"\x01\x02\x03", region=0)  # 3 bytes


def test_deploy_rejects_empty(daemon_model: tuple[Daemon, PythonEmriModel]) -> None:
    daemon, _ = daemon_model
    with pytest.raises(DaemonError):
        daemon.deploy(b"", region=0)


# --------------------------------------------------------------------------- #
# Record transport -> deploy plan (the SV TB input)
# --------------------------------------------------------------------------- #
def test_record_transport_produces_plan(tmp_path: Path) -> None:
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


def test_plan_has_blank_then_write_order(tmp_path: Path) -> None:
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
def test_deploy_image_end_to_end(tmp_path: Path) -> None:
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
def test_cli_inspect_plan_mode(capsys: pytest.CaptureFixture[str]) -> None:
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


def _fixed_keypair() -> tuple[bytes, bytes]:
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


def _signed_eth(tmp_path: Path, name: str = "efp-img") -> tuple[Path, bytes, list[int]]:
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


def _daemon_pub_pem(tmp_path: Path) -> Path:
    """Write the daemon test public key as PEM (for ethctl --pubkey)."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from gen_daemon_vectors import KEY_SEED

    pub = Ed25519PrivateKey.from_private_bytes(KEY_SEED).public_key()
    path = tmp_path / "daemon_pub.pem"
    path.write_bytes(pub.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ))
    return path


def _signed_eth_with_caps(tmp_path: Path, caps_yaml: str, name: str) -> tuple[Path, bytes]:
    """Pack+sign image A with an explicit capabilities.yaml body."""
    from gen_daemon_vectors import IMG_A_WORDS

    priv_pem, pk_raw = _fixed_keypair()
    src = tmp_path / f"src_{name}"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(
        b"".join(w.to_bytes(4, "little") for w in IMG_A_WORDS)
    )
    (src / "capabilities.yaml").write_text(caps_yaml)
    out = tmp_path / f"{name}.eth"
    ethimg.pack(src, out, name=name, target="efab-1.0", privkey_pem=priv_pem)
    return out, pk_raw


def _read_member(tf: tarfile.TarFile, name: str) -> bytes:
    """Read a tar member's bytes (``extractfile`` is Optional in the stubs)."""
    f = tf.extractfile(name)
    return f.read() if f is not None else b""


def _tamper_manifest_signature(eth_path: Path) -> None:
    """Flip the first hex nibble of the manifest signature (digest unchanged:
    ethimg's manifest_digest excludes the signature field)."""
    with tarfile.open(eth_path, "r") as tf:
        members = {
            n: _read_member(tf, n)
            for n in tf.getnames()
        }
    man = yaml.safe_load(members["manifest.yaml"])
    val = man["signature"]["value"]
    man["signature"]["value"] = ("1" if val[0] == "0" else "0") + val[1:]
    members["manifest.yaml"] = yaml.safe_dump(man, sort_keys=True).encode("utf-8")
    with tarfile.open(eth_path, "w") as tf:
        for member, data in members.items():
            info = tarfile.TarInfo(name=member)
            info.size = len(data)
            info.mtime = 0
            tf.addfile(info, io.BytesIO(data))


def _set_eth_capabilities(eth_path: Path, caps_yaml: str) -> None:
    """Swap the capabilities.yaml member + re-sync its digest/manifest_digest.

    This invalidates the manifest signature (manifest_digest changes); the
    stage-1 schema check runs before the trust gate, so callers see the
    capabilities error, not a signature error."""
    import hashlib

    with tarfile.open(eth_path, "r") as tf:
        members = {
            n: _read_member(tf, n)
            for n in tf.getnames()
        }
    members["capabilities.yaml"] = caps_yaml.encode("utf-8")
    man = yaml.safe_load(members["manifest.yaml"])
    man["members"]["capabilities.yaml"] = hashlib.sha256(
        members["capabilities.yaml"]
    ).hexdigest()
    man["manifest_digest"] = ethimg._manifest_digest(man)
    members["manifest.yaml"] = yaml.safe_dump(man, sort_keys=True).encode("utf-8")
    with tarfile.open(eth_path, "w") as tf:
        for member, data in members.items():
            info = tarfile.TarInfo(name=member)
            info.size = len(data)
            info.mtime = 0
            tf.addfile(info, io.BytesIO(data))


def test_efp_digest_sig_byte_packing_kat() -> None:
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


def test_efp_err_decode_all_codes() -> None:
    """EFP_ERR codes decode: v0.2 0-8, v0.4 9-10, v0.6 11-12."""
    expected = {
        EFP_ERR_NONE: "none",
        EFP_ERR_BAD_SIG: "bad_sig",
        EFP_ERR_REGION_FULL: "region_full",
        EFP_ERR_REGION_LOCKED: "region_locked",
        EFP_ERR_OCC_CRC: "occ_crc",
        EFP_ERR_OCC_REJECT: "occ_reject",
        EFP_ERR_BAD_CMD: "bad_cmd",
        EFP_ERR_IMG_LEN_MISMATCH: "img_len_mismatch",
        EFP_ERR_CRC_TRANSPORT: "crc_transport",
        EFP_ERR_WATCHDOG_TIMEOUT: "watchdog_timeout",
        EFP_ERR_FWUPDATE: "fwupdate",
        EFP_ERR_CAPABILITY_DENIED: "capability_denied",
        EFP_ERR_RATE_LIMITED: "rate_limited",
    }
    assert len(expected) == 13
    for code, name in expected.items():
        assert efp_client.decode_err(code) == name
    assert efp_client.decode_err(13).startswith("unknown")


def test_efp_state_decode_all() -> None:
    for code, name in [
        (EFP_S_IDLE, "IDLE"), (EFP_S_LOAD, "LOAD"), (EFP_S_RUNNING, "RUNNING"),
        (EFP_S_ERROR, "ERROR"), (EFP_S_STOPPED, "STOPPED"),
    ]:
        assert efp_client.decode_state(code) == name
    assert efp_client.decode_state(15).startswith("unknown")


def test_efp_run_session_op_order(tmp_path: Path) -> None:
    """The run session must mirror spec sec 3.2 steps 1-6 exactly."""
    eth, pk, img_words = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    ops, img = client.run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
    assert img.frame_words == img_words
    assert img.caps == capcheck.Capabilities()  # auto-filled empty declaration

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
    # E2-SEC1 staging: CAP_DECL_IO + CAP_DECL_SVC precede the doorbell (empty
    # declaration -> zero bitmaps)
    assert ops[26].op == "write" and ops[26].addr == R_CAP_DECL_IO
    assert ops[26].data == 0
    assert ops[27].op == "write" and ops[27].addr == R_CAP_DECL_SVC
    assert ops[27].data == 0
    # busy=0 BEFORE the doorbell (single-outstanding-command rule)
    assert ops[28].op == "poll" and ops[28].addr == R_EFP_STATUS
    assert ops[28].mask == 0x10 and ops[28].value == 0
    assert ops[29].op == "write" and ops[29].addr == R_EFP_CMD
    assert ops[29].data == EFP_CMD_RUN
    # step 5: wait for LOAD (OCC WRITE already armed), then stream
    assert ops[30].op == "poll" and ops[30].mask == 0x0F
    assert ops[30].value == EFP_S_LOAD
    assert ops[31].op == "stream" and ops[31].addr == R_OCC_WDATA
    assert ops[31].words == img_words
    # step 6: terminal-state completion poll (busy=0 AND state==RUNNING; a
    # bare busy=0 poll would race the daemon's accept latency) + self-checks
    assert ops[32].op == "poll" and ops[32].mask == 0x1F
    assert ops[32].value == EFP_S_RUNNING
    assert ops[33].op == "read" and ops[33].addr == R_EFP_STATUS
    assert ops[33].mask == 0x3F and ops[33].value == EFP_S_RUNNING | 0x20
    assert ops[34].op == "read" and ops[34].addr == R_EFP_ERR
    assert ops[34].mask == 0xFF and ops[34].value == EFP_ERR_NONE
    assert len(ops) == 35


def test_efp_run_happy_path_model(tmp_path: Path) -> None:
    eth, pk, img_words = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    ops, _ = client.run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
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


def _signed_packed_eth(tmp_path: Path, columns: list[list[int]], name: str = "efp-packed") -> tuple[Path, bytes]:
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


def test_efp_run_packed_session_op_order(tmp_path: Path) -> None:
    """The run_packed session must mirror spec sec 3.3: stage (+IMG_COLS),
    doorbell run_packed, per-column handshake + stream, terminal checks."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    client = efp_client.EfpClient()
    ops, img = client.run_packed(
        eth, EFP_REGION_AUTO, column_words=4, trusted_pk=pk
    )
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


def test_efp_run_packed_happy_path_model(tmp_path: Path) -> None:
    """run_packed drives the model daemon to RUNNING over 2 columns."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    client = efp_client.EfpClient()
    ops, _ = client.run_packed(
        eth, EFP_REGION_AUTO, column_words=4, trusted_pk=pk
    )
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    efp_client.execute_ops(ops, model)
    assert model.read(R_EFP_STATUS) == EFP_S_RUNNING | 0x20
    assert model.read(R_EFP_ERR) == EFP_ERR_NONE
    assert model.region_state(0) == 1  # RUNNING
    assert model._streamed == sum(len(c) for c in _PACKED_COLUMNS)


def test_efp_run_packed_bad_sig_rejected(tmp_path: Path) -> None:
    """Tampered signature -> EFP_ERR=bad_sig, state ERROR (same as run)."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    img = efp_client.load_image(eth, trusted_pk=pk)
    bad_sig = bytes([img.sig64[0] ^ 0x01]) + img.sig64[1:]
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    s = efp_client.EfpSession()
    s.run_packed(img.digest32, bad_sig, _PACKED_COLUMNS, EFP_REGION_AUTO)
    with pytest.raises(efp_client.EfpError, match="poll timeout"):
        efp_client.execute_ops(s.ops, model)
    assert model.read(R_EFP_ERR) & 0xFF == EFP_ERR_BAD_SIG
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_ERROR
    assert model.region_state(0) == 0  # fabric untouched


def test_efp_run_packed_geometry_validation(tmp_path: Path) -> None:
    """Client-side geometry checks (v0 homogeneous, region->column mapping)."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
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
        client.run_packed(eth, EFP_REGION_AUTO, trusted_pk=pk)
    # more columns than fit from an explicit region (2 regions, region 1)
    with pytest.raises(efp_client.EfpError, match="do not fit"):
        client.run_packed(eth, 1, column_words=4, trusted_pk=pk)
    # flat word list not a multiple of column_words
    with pytest.raises(efp_client.EfpError, match="multiple"):
        client.run_packed([0] * 6, EFP_REGION_AUTO, column_words=4)


def test_efp_busy_before_cmd_rejected(tmp_path: Path) -> None:
    """A doorbell write while busy is ignored + flagged bad_cmd (spec 3.2)."""
    eth, pk, img_words = _signed_eth(tmp_path)
    img = efp_client.load_image(eth, trusted_pk=pk)
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


def test_efp_bad_sig_rejected(tmp_path: Path) -> None:
    """Tampered signature -> EFP_ERR=bad_sig, state ERROR, region untouched."""
    eth, pk, _ = _signed_eth(tmp_path)
    img = efp_client.load_image(eth, trusted_pk=pk)
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


def test_efp_stop_restart_semantics(tmp_path: Path) -> None:
    eth, pk, _ = _signed_eth(tmp_path)
    client = efp_client.EfpClient()
    model = efp_client.EfpDaemonModel(trusted_pk=pk)

    run_ops, _ = client.run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
    efp_client.execute_ops(run_ops, model)
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_RUNNING

    stop_ops = client.stop(0)
    efp_client.execute_ops(stop_ops, model)
    st = model.read(R_EFP_STATUS)
    assert st & 0xF == EFP_S_STOPPED and not (st & 0x20)  # STOPPED, done=0
    assert model.region_state(0) == 0  # FREE again

    # re-run, then restart (re-verify + re-stream of the last staged image)
    efp_client.execute_ops(
        client.run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)[0], model
    )
    rst_ops, _ = client.restart(eth, trusted_pk=pk)
    efp_client.execute_ops(rst_ops, model)
    st = model.read(R_EFP_STATUS)
    assert st & 0xF == EFP_S_RUNNING and st & 0x20
    assert model.read(R_EFP_ERR) == EFP_ERR_NONE

    # abort -> IDLE, region blanked
    efp_client.execute_ops(client.abort(), model)
    assert model.read(R_EFP_STATUS) & 0xF == EFP_S_IDLE
    assert model.region_state(0) == 0


def test_efp_ps_pure_read() -> None:
    ops = efp_client.EfpClient().ps()
    assert not any(o.addr == R_EFP_CMD for o in ops)  # ps never rings the bell
    assert ops[0].op == "read" and ops[0].addr == R_EFP_STATUS
    assert ops[1].op == "read" and ops[1].addr == R_EFP_ERR
    model = efp_client.EfpDaemonModel()
    reads = efp_client.execute_ops(ops, model)
    assert reads[0] == EFP_S_IDLE  # fresh daemon: IDLE, not busy, not done


def test_efp_session_json_self_describing(tmp_path: Path) -> None:
    eth, pk, img_words = _signed_eth(tmp_path)
    ops, img = efp_client.EfpClient().run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
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


def test_efp_build_demo_sessions(tmp_path: Path) -> None:
    """The Makefile regen step: pack+sign .eth + ethctl-emitted session JSONs."""
    info = efp_client.build_demo_sessions(tmp_path / "gen")
    run = json.loads(Path(info["run"]).read_text())
    stop = json.loads(Path(info["stop"]).read_text())
    assert run["schema"] == stop["schema"] == "ethereal.efp-session.v0"
    streams = [o for o in run["ops"] if o["op"] == "stream"]
    assert len(streams) == 1 and streams[0]["count"] == 12
    assert ethimg.read_manifest(Path(info["eth"])).manifest_digest == info["digest"]
    assert any(o.get("data") == "0x00000001" for o in run["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")  # EFP_CMD=run
    assert any(o.get("data") == "0x00000002" for o in stop["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")  # EFP_CMD=stop


# --------------------------------------------------------------------------- #
# EFP CLI integration
# --------------------------------------------------------------------------- #
def test_cli_efp_run_emit_session(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    pub = _daemon_pub_pem(tmp_path)
    sess = tmp_path / "session.json"
    rc = _cli(["--transport", "efp", "run", str(eth), "--region", "auto",
               "--pubkey", str(pub), "--emit-session", str(sess)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "RUNNING" in out
    doc = json.loads(sess.read_text())
    assert doc["schema"] == "ethereal.efp-session.v0"


def test_cli_efp_stop_ps(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    pub = _daemon_pub_pem(tmp_path)
    assert _cli(["--transport", "efp", "run", str(eth), "--region", "auto",
                 "--pubkey", str(pub)]) == 0
    capsys.readouterr()
    assert _cli(["--transport", "efp", "ps"]) == 0
    assert "state=" in capsys.readouterr().out
    assert _cli(["--transport", "efp", "stop", "--region", "0"]) == 0
    assert "STOPPED" in capsys.readouterr().out


def test_cli_efp_restart_without_staged_image(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """restart on a device with no staged image -> bad_cmd (spec sec 3.2).

    (The sim model is per-process; a real BMC retains the staged metadata
    across ethctl invocations. In-process restart semantics are covered by
    test_efp_stop_restart_semantics.)"""
    from ethctl import _cli

    eth, _, _ = _signed_eth(tmp_path)
    pub = _daemon_pub_pem(tmp_path)
    sess = tmp_path / "restart.json"
    rc = _cli(["--transport", "efp", "restart", str(eth),
               "--pubkey", str(pub), "--emit-session", str(sess)])
    # session JSON is still emitted (the op list is valid); the fresh model
    # honestly reports the device-side bad_cmd.
    assert rc == 1
    assert "bad_cmd" in capsys.readouterr().err
    doc = json.loads(sess.read_text())
    assert any(o.get("data") == "0x00000003" for o in doc["ops"]
               if o["op"] == "write" and o["addr"] == "0x13")


def test_cli_efp_unsigned_run_rejected(tmp_path: Path) -> None:
    from ethctl import _cli

    src = tmp_path / "img"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(struct.pack("<I", 1))
    out = tmp_path / "u.eth"
    ethimg.pack(src, out, name="u")  # unsigned: daemon VERIFY must reject
    rc = _cli(["--transport", "efp", "run", str(out), "--region", "auto"])
    assert rc == 1


def test_cli_stop_needs_efp_transport(capsys: pytest.CaptureFixture[str]) -> None:
    from ethctl import _cli

    rc = _cli(["stop", "--region", "0"])
    assert rc == 1
    assert "--transport efp" in capsys.readouterr().err


# --------------------------------------------------------------------------- #
# E2-SEC1: host-side signature enforcement + capability pre-flight
# --------------------------------------------------------------------------- #
def test_efp_signed_image_matrices(tmp_path: Path) -> None:
    """Signed images: trusted key ok, missing/wrong key refused, opt-out ok."""
    eth, pk, _ = _signed_eth(tmp_path)
    assert efp_client.load_image(eth, trusted_pk=pk).signed is True
    with pytest.raises(ethimg.SignatureError, match="trusted_pk"):
        efp_client.load_image(eth)
    with pytest.raises(ethimg.SignatureError, match="did not verify"):
        efp_client.load_image(eth, trusted_pk=bytes(32))
    # explicit dev opt-out still allowed (and still stages the real signature)
    opted = efp_client.load_image(eth, allow_unsigned=True)
    assert opted.signed is True and opted.sig64 != bytes(64)


def test_efp_unsigned_image_rejected_by_default(tmp_path: Path) -> None:
    src = tmp_path / "img"
    (src / "targets").mkdir(parents=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(struct.pack("<I", 1))
    out = tmp_path / "u.eth"
    ethimg.pack(src, out, name="u")
    with pytest.raises(ethimg.SignatureError, match="unsigned"):
        efp_client.load_image(out)
    img = efp_client.load_image(out, allow_unsigned=True)
    assert img.signed is False and img.sig64 == bytes(64)


def test_efp_tampered_signature_rejected(tmp_path: Path) -> None:
    eth, pk, _ = _signed_eth(tmp_path)
    _tamper_manifest_signature(eth)
    with pytest.raises(ethimg.SignatureError, match="did not verify"):
        efp_client.load_image(eth, trusted_pk=pk)


def test_efp_capabilities_staged_and_ordered(tmp_path: Path) -> None:
    eth, pk = _signed_eth_with_caps(
        tmp_path,
        "io:\n  - {group: 1, dir: out}\n  - {group: 7, dir: inout}\n"
        "services:\n  - {name: spi0, access: rw}\n",
        name="efp-caps-ok",
    )
    ops, img = efp_client.EfpClient().run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
    assert img.decl_io == (1 << 1) | (1 << 7)
    assert img.decl_svc == 1  # spi0 -> proxy index 0
    cap_writes = [
        o for o in ops
        if o.op == "write" and o.addr in (R_CAP_DECL_IO, R_CAP_DECL_SVC)
    ]
    assert [o.addr for o in cap_writes] == [R_CAP_DECL_IO, R_CAP_DECL_SVC]
    assert [o.data for o in cap_writes] == [img.decl_io, img.decl_svc]
    doorbell = next(
        i for i, o in enumerate(ops) if o.op == "write" and o.addr == R_EFP_CMD
    )
    assert ops.index(cap_writes[0]) < doorbell
    assert ops.index(cap_writes[1]) < doorbell


def test_efp_over_declared_io_group_denied(tmp_path: Path) -> None:
    eth, pk = _signed_eth_with_caps(
        tmp_path, "io:\n  - {group: 200, dir: out}\nservices: []\n",
        name="efp-caps-big",
    )
    with pytest.raises(capcheck.CapabilityDenied) as ei:
        efp_client.load_image(eth, trusted_pk=pk)
    assert ei.value.entry == capcheck.IoDecl(200, "out")
    assert "200" in str(ei.value)


def test_efp_unknown_service_denied(tmp_path: Path) -> None:
    eth, pk = _signed_eth_with_caps(
        tmp_path, "io: []\nservices:\n  - {name: can0, access: r}\n",
        name="efp-caps-svc",
    )
    with pytest.raises(capcheck.CapabilityDenied, match="can0"):
        efp_client.load_image(eth, trusted_pk=pk)


def test_efp_malformed_capabilities_rejected(tmp_path: Path) -> None:
    """A malformed member fails stage-1 schema even before the trust gate."""
    bad_dir, pk = _signed_eth_with_caps(
        tmp_path, "io:\n  - {group: 0, dir: in}\nservices: []\n",
        name="efp-caps-bad",
    )
    _set_eth_capabilities(bad_dir, "io:\n  - {group: 0, dir: up}\nservices: []\n")
    with pytest.raises(capcheck.CapabilitySchemaError, match="io\\[0\\].dir"):
        efp_client.load_image(bad_dir, trusted_pk=pk)
    dup, pk2 = _signed_eth_with_caps(
        tmp_path, "io:\n  - {group: 0, dir: in}\nservices: []\n",
        name="efp-caps-dup",
    )
    _set_eth_capabilities(
        dup, "io:\n  - {group: 1, dir: in}\n  - {group: 1, dir: out}\nservices: []\n"
    )
    with pytest.raises(capcheck.CapabilitySchemaError, match="duplicate group 1"):
        efp_client.load_image(dup, trusted_pk=pk2)


def test_cli_efp_capability_denied_is_actionable(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    from ethctl import _cli

    eth, _ = _signed_eth_with_caps(
        tmp_path, "io:\n  - {group: 9, dir: out}\nservices: []\n",
        name="efp-caps-cli",
    )
    pub = _daemon_pub_pem(tmp_path)
    rc = _cli(["--transport", "efp", "run", str(eth), "--region", "auto",
               "--pubkey", str(pub)])
    err = capsys.readouterr().err
    assert rc == 1
    assert "group 9" in err  # offending entry named
    assert "CapabilityDenied" not in err  # message, not a class dump


# --------------------------------------------------------------------------- #
# OCC_FRAME_ADDR v0.6 (E1-DMO2b): per-column addressing must not alias
# --------------------------------------------------------------------------- #
def test_occ_frame_addr_v06_column_addressing() -> None:
    assert efp_client.region_frame_base(0) == 0x0000
    assert efp_client.region_frame_base(3) == 0x3000
    assert efp_client.column_frame_base(0, 0) == 0x0000
    assert efp_client.column_frame_base(0, 1) == 0x0100
    assert efp_client.column_frame_base(1, 2) == 0x1200


def test_occ_frame_addr_column_windows_do_not_overlap() -> None:
    """A 68-word frame at col 0 and col 1 land in disjoint ranges (v0.6)."""
    c0 = efp_client.column_frame_range(0, 0, 68)
    c1 = efp_client.column_frame_range(0, 1, 68)
    assert set(c0) & set(c1) == set()
    assert max(c0) < min(c1)
    # v0.5's 16-word stride (col << 4) WOULD have overlapped such frames
    assert set(range(68)) & set(range(16, 84))
    with pytest.raises(efp_client.EfpError, match="window"):
        efp_client.column_frame_range(0, 0, 257)


def test_efp_run_packed_two_columns_address_each_column(tmp_path: Path) -> None:
    """The daemon mirror arms OCC_FRAME_ADDR = region_base | (col << 8)."""
    eth, pk = _signed_packed_eth(tmp_path, _PACKED_COLUMNS)
    ops, _ = efp_client.EfpClient().run_packed(
        eth, EFP_REGION_AUTO, column_words=4, trusted_pk=pk
    )
    model = efp_client.EfpDaemonModel(trusted_pk=pk)
    efp_client.execute_ops(ops, model)
    addrs = model.column_addrs()
    expected = {efp_client.column_frame_base(0, c) for c in range(len(_PACKED_COLUMNS))}
    assert expected <= set(addrs)
    assert set(addrs) <= {0x0000, 0x0100}  # no 16-word-stride aliasing
    assert model.read(R_OCC_FRAME_ADDR) == efp_client.column_frame_base(0, 1)


# --------------------------------------------------------------------------- #
# EFP-SPI framing (spec sec 7 request frames + sec 7.1 CRC16 tail op)
# --------------------------------------------------------------------------- #
def test_spi_frame_encoding_kat() -> None:
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


def test_spi_crc16_known_vector() -> None:
    """CRC-16/CCITT-FALSE check vector + frame_map algorithm identity."""
    import frame_map

    assert efp_client.crc16_bytes(b"123456789") == 0x29B1  # CCITT-FALSE check
    words = [0x00000000, 0x55700000, 0x00000015, 0xDEADBEEF]
    assert efp_client.crc16_words(words) == frame_map.crc16(words)
    # word orientation: big-endian bytes per word
    assert efp_client.crc16_words([0x31323334, 0x35363738]) == \
        efp_client.crc16_bytes(b"12345678")


def test_spi_crc_tail_op_placement() -> None:
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


def test_spi_no_crc_frame_without_run() -> None:
    """stop/ps sessions carry no SPI_CRC latch (no stream follows)."""
    s = efp_client.EfpSession()
    s.stop(0)
    frames = efp_client.to_spi_frames(s.ops)
    assert not any(f[:3] == bytes([0x01, 0x00, 0x3F]) for f in frames)
    assert any(f == bytes([0x01, 0x00, 0x13, 0, 0, 0, 2]) for f in frames)  # stop


def test_spi_status_and_err_decode() -> None:
    import emri_constants as ec

    assert efp_client.decode_spi_status(ec.SPI_STAT_OK) == "OK"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BAD_OP) == "BAD_OP"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BAD_ADDR) == "BAD_ADDR"
    assert efp_client.decode_spi_status(ec.SPI_STAT_BUSY) == "BUSY"
    assert efp_client.decode_spi_status(ec.SPI_STAT_CRC_ERR) == "CRC_ERR"
    assert efp_client.decode_spi_status(ec.SPI_STAT_NOT_READY) == "NOT_READY"
    assert efp_client.decode_err(ec.EFP_ERR_CRC_TRANSPORT) == "crc_transport"


# --------------------------------------------------------------------------- #
# E1-BMC4: session-mode auto-detection (BMC vs mFSM) + mode-dependent semantics
#
# emri-v0.md: both implementations share one register map and one transport;
# the ONLY probe field that differs is CAPABILITIES.has_bmc (sec 1.1). What
# differs is where the session intelligence lives (sec 8) — so the tests below
# flip that single bit and assert ethctl's flow follows it, plus the refusal
# paths for asking the wrong side for a command it cannot serve.
# --------------------------------------------------------------------------- #
class _CapsTransport:
    """EMRI transport whose CAPABILITIES word is settable — the probe seam.

    Everything else is the ordinary :class:`PythonEmriModel`, so a test can
    flip the detected mode without changing any other register: exactly the
    spec sec 1.1 property that makes auto-detection a single read.
    """

    def __init__(self, caps: int) -> None:
        self.caps = caps
        self.inner = PythonEmriModel()
        self.writes: list[tuple[int, int]] = []

    def read(self, addr: int) -> int:
        if addr == R_CAPABILITIES:
            return self.caps
        return self.inner.read(addr)

    def write(self, addr: int, data: int) -> None:
        self.writes.append((addr, data))
        self.inner.write(addr, data)

    def push(self, data: int) -> None:
        self.inner.push(data)

    def read_status(self) -> int:
        return self.inner.read_status()


def test_mode_probe_is_capabilities_has_bmc() -> None:
    """Auto-detection reads CAPABILITIES.has_bmc (bit0) and no other bit."""
    assert probe_mode(_CapsTransport(0x00)) is EmriMode.MFSM
    assert probe_mode(_CapsTransport(1 << CAPB_HAS_BMC)) is EmriMode.BMC
    # has_dma/has_i2c_mon/has_trng/has_jtag_dbg are capabilities, not the mode
    assert probe_mode(_CapsTransport(0b1_1110)) is EmriMode.MFSM


def test_mode_override_pins_semantics() -> None:
    """The documented --transport override wins; auto follows the probe."""
    bmc = _CapsTransport(1 << CAPB_HAS_BMC)
    assert resolve_mode(bmc, None) is EmriMode.BMC
    assert resolve_mode(bmc, EmriMode.MFSM) is EmriMode.MFSM
    assert Daemon(bmc, mode_override=EmriMode.MFSM).mode() is EmriMode.MFSM
    assert Daemon(_CapsTransport(0)).mode() is EmriMode.MFSM


def test_require_bmc_and_require_mfsm_guards() -> None:
    """The two mode guards fire only on the mode that cannot serve the call."""
    require_bmc(EmriMode.BMC, "x")  # no-op on a BMC
    with pytest.raises(DaemonError, match="--transport efp"):
        require_bmc(EmriMode.MFSM, "'stop'")
    require_mfsm(EmriMode.MFSM, "x")  # no-op on an mFSM
    with pytest.raises(DaemonError, match="mFSM-only"):
        require_mfsm(EmriMode.BMC, "the host-driven OCC deploy")


def test_deploy_auto_refuses_bmc_device() -> None:
    """An auto-detected BMC is refused before any OCC write (spec sec 8)."""
    dev = _CapsTransport(1 << CAPB_HAS_BMC)
    daemon = Daemon(dev)
    assert daemon.mode() is EmriMode.BMC
    assert daemon.is_mfsm_mode() is False
    with pytest.raises(DaemonError, match="mFSM-only"):
        daemon.deploy(struct.pack("<I", 0xDEADBEEF), region=0)
    assert dev.writes == []  # fail-closed: no OCC_CMD / WDATA behind the daemon


def test_mfsm_deploy_notifies_anomaly_monitor() -> None:
    """mFSM: the HOST posts MON_NOTIFY bit r on a completed deploy (sec 3.8)."""
    rec = RecordTransport()
    res = Daemon(rec).deploy(struct.pack("<I", 0xCAFEF00D), region=1)
    assert res.words_written == 1
    notes = [t.data for t in rec.log if t.op == "wr" and t.addr == R_MON_NOTIFY]
    assert notes == [1 << 1]
    # ... and it is the host that arms the OCC in mFSM mode (sec 8)
    assert len([t for t in rec.log if t.addr == R_OCC_CMD]) == 2  # BLANK + WRITE


def test_bmc_session_leaves_occ_and_monitor_to_the_daemon(tmp_path: Path) -> None:
    """BMC: the host neither arms OCC_CMD nor notifies — the daemon does."""
    eth, pk, _ = _signed_eth(tmp_path)
    ops, _img = efp_client.EfpClient().run_image(eth, EFP_REGION_AUTO, trusted_pk=pk)
    wrote = {op.addr for op in ops if op.op == "write"}
    assert R_OCC_CMD not in wrote
    assert R_MON_NOTIFY not in wrote
    # the host's only OCC involvement is the LOAD word stream (sec 3.2 step 5)
    assert any(op.op == "stream" and op.addr == R_OCC_WDATA for op in ops)


def test_inspect_is_identical_across_modes() -> None:
    """spec sec 8 acceptance: inspect matches on the fields both modes expose."""
    mfsm = Daemon(PythonEmriModel()).inspect()
    bmc = Daemon(efp_client.EfpDaemonModel()).inspect()
    assert mfsm["mode"] == "mfsm" and bmc["mode"] == "bmc"
    assert mfsm["has_bmc"] is False and bmc["has_bmc"] is True
    drop = ("mode", "has_bmc")
    shared = {k: v for k, v in mfsm.items() if k not in drop}
    assert shared == {k: v for k, v in bmc.items() if k not in drop}
    assert shared["magic_ok"] is True
    assert shared["regions"] == [0x0202_0010, 0x0202_0010]


def test_cli_inspect_reports_detected_mode(capsys: pytest.CaptureFixture[str]) -> None:
    from ethctl import _cli

    assert _cli(["inspect"]) == 0
    out = capsys.readouterr().out
    assert '"mode": "mfsm"' in out and '"has_bmc": false' in out
    assert _cli(["--device", "bmc", "inspect"]) == 0
    out = capsys.readouterr().out
    assert '"mode": "bmc"' in out and '"has_bmc": true' in out


def test_cli_auto_detects_bmc_device_and_runs_efp_session(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """--device bmc + auto (default): the probe picks the EFP mailbox."""
    from ethctl import _cli

    eth, _pk, img_words = _signed_eth(tmp_path)
    pub = _daemon_pub_pem(tmp_path)
    rc = _cli(["--device", "bmc", "run", str(eth), "--region", "auto",
               "--pubkey", str(pub)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "RUNNING" in out and "err=none" in out
    assert f"({len(img_words)} words" in out


def test_cli_auto_keeps_mfsm_device_host_driven(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """--device emri + auto (default): the host drives the OCC itself."""
    from ethctl import _cli

    eth, _pk, _words = _signed_eth(tmp_path)
    pub = _daemon_pub_pem(tmp_path)
    out_path = tmp_path / "plan.json"
    rc = _cli(["--plan-out", str(out_path), "run", str(eth), "--region", "0",
               "--pubkey", str(pub)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "(mode=mfsm)" in out
    txn = json.loads(out_path.read_text())["txn_log"]
    assert [t["data"] for t in txn if t["addr"] == R_MON_NOTIFY] == [1]
    assert any(t["addr"] == R_OCC_CMD for t in txn)


def test_cli_bmc_only_commands_refused_on_mfsm(capsys: pytest.CaptureFixture[str]) -> None:
    """Auto-detected mFSM: daemon lifecycle commands are refused with the fix."""
    from ethctl import _cli

    for argv in (["stop", "--region", "0"], ["restart", "no-such.eth"], ["abort"]):
        assert _cli(argv) == 1, argv
        err = capsys.readouterr().err
        assert "--transport efp" in err
        assert "CAPABILITIES.has_bmc=0" in err and "mFSM" in err


def test_cli_daemon_only_flags_refused_on_mfsm(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    """--region auto / --emit-session are daemon features (spec sec 3.2)."""
    from ethctl import _cli

    eth, _pk, _words = _signed_eth(tmp_path)
    sess = tmp_path / "s.json"
    assert _cli(["run", str(eth), "--region", "auto"]) == 1
    assert "--transport efp" in capsys.readouterr().err
    assert _cli(["run", str(eth), "--region", "0", "--emit-session", str(sess)]) == 1
    assert "--transport efp" in capsys.readouterr().err
    assert not sess.exists()


def test_cli_forced_path_contradicting_the_device_fails_closed(capsys: pytest.CaptureFixture[str]) -> None:
    """A pinned --transport that contradicts the probe must not silently run."""
    from ethctl import _cli

    assert _cli(["--device", "emri", "--transport", "efp", "ps"]) == 1
    err = capsys.readouterr().err
    assert "CAPABILITIES.has_bmc=0" in err and "--transport efp" in err
    assert _cli(["--device", "bmc", "--transport", "mfsm", "ps"]) == 1
    assert "mFSM-only" in capsys.readouterr().err


def test_cli_legacy_transport_efp_still_selects_the_bmc_device(capsys: pytest.CaptureFixture[str]) -> None:
    """Compat: `--transport efp` alone runs the BMC session exactly as before."""
    from ethctl import _cli

    assert _cli(["--transport", "efp", "ps"]) == 0
    assert "daemon: state=IDLE" in capsys.readouterr().out
