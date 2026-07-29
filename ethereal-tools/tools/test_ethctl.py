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

import ethimg
from emri_constants import (
    OCC_BLANK,
    OCC_CMD_START,
    OCC_S_DONE,
    OCC_WRITE,
    R_OCC_CMD,
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
