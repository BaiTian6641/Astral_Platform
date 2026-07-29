# SPDX-License-Identifier: MIT
"""Tests for ethimg (S09 / E1-RUN1). M-S09-1: tamper any byte -> verify fails."""
from __future__ import annotations

import io
import sys
import tarfile
from pathlib import Path

import pytest
import yaml

# ethimg.py lives in this dir (ethereal-tools/tools/ethimg/); ensure importable
# regardless of pytest invocation CWD.
_TOOLS_DIR = str(Path(__file__).resolve().parent)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from ethimg import (
    EthimgError,
    IntegrityError,
    SignatureError,
    ed25519_available,
    info,
    keygen,
    pack,
    unpack,
    verify,
)


# --------------------------------------------------------------------------- #
# fixtures
# --------------------------------------------------------------------------- #
@pytest.fixture
def src_dir(tmp_path: Path) -> Path:
    """A minimal valid image source dir: targets/efab-1.0.frames + meta.json."""
    d = tmp_path / "img"
    (d / "targets").mkdir(parents=True)
    # 2 frames x 4 words (synthetic config frames, like bitgen output)
    frames = b"".join(
        # frame i: 4 little-endian 32-bit words
        int.to_bytes(0xA0 + i, 4, "little")
        + int.to_bytes(0xB0 + i, 4, "little")
        + int.to_bytes(0xC0 + i, 4, "little")
        + int.to_bytes(0xD0 + i, 4, "little")
        for i in range(2)
    )
    (d / "targets" / "efab-1.0.frames").write_bytes(frames)
    (d / "targets" / "efab-1.0.meta.json").write_text(
        '{"frames": 2, "words_per_frame": 4, "elut_used": 4}'
    )
    return d


@pytest.fixture
def keypair(tmp_path: Path):
    if not ed25519_available():
        pytest.skip("cryptography not installed")
    priv, pub = keygen(tmp_path / "k.pem", tmp_path / "k.pub")
    return priv, pub


# --------------------------------------------------------------------------- #
# round-trip
# --------------------------------------------------------------------------- #
def test_pack_unpack_roundtrip(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    r = pack(src_dir, out, name="t", version="0.1.0", author="me")
    assert out.is_file()
    assert r.signed is False
    # unpack and check members
    dest = tmp_path / "out"
    unpack(out, dest)
    assert (dest / "manifest.yaml").is_file()
    assert (dest / "targets" / "efab-1.0.frames").is_file()
    # optional YAMLs auto-filled
    for m in ("interface.yaml", "capabilities.yaml", "resources.yaml", "health.yaml"):
        assert (dest / m).is_file()
        # valid YAML
        yaml.safe_load((dest / m).read_text())


def test_verify_unsigned_allowed(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    man = verify(out, allow_unsigned=True)
    assert man.name == "t"
    assert man.signature is None


def test_verify_unsigned_rejected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    with pytest.raises(SignatureError):
        verify(out, allow_unsigned=False)


# --------------------------------------------------------------------------- #
# M-S09-1: tamper detection
# --------------------------------------------------------------------------- #
def test_tamper_member_byte_detected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    # rewrite the frames member with one byte flipped, keeping tar structure
    _tamper_member(out, "targets/efab-1.0.frames", byte_index=0, xor=0xFF)
    with pytest.raises(IntegrityError):
        verify(out, allow_unsigned=True)


def test_tamper_manifest_member_map_detected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    # corrupt a declared digest in the manifest -> member digest mismatch
    _tamper_manifest_field(
        out, member_field="targets/efab-1.0.frames", new_digest="00" * 32
    )
    with pytest.raises(IntegrityError):
        verify(out, allow_unsigned=True)


def test_undeclared_member_rejected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    _inject_member(out, "evil.txt", b"pwned")
    with pytest.raises(IntegrityError):
        verify(out, allow_unsigned=True)


def test_missing_member_rejected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    _remove_member(out, "targets/efab-1.0.frames")
    with pytest.raises(IntegrityError):
        verify(out, allow_unsigned=True)


# --------------------------------------------------------------------------- #
# Ed25519 signing path
# --------------------------------------------------------------------------- #
def test_signed_roundtrip_and_verify(src_dir: Path, tmp_path: Path, keypair):
    priv, pub = keypair
    out = tmp_path / "x.eth"
    r = pack(src_dir, out, name="t", privkey_pem=priv)
    assert r.signed is True
    man = verify(out, trusted_pubkeys=[pub])
    assert man.signature is not None
    assert man.signature["algo"] == "ed25519"


def test_signed_reject_untrusted_key(src_dir: Path, tmp_path: Path, keypair):
    priv, _pub = keypair
    # generate a second, different keypair (only its public key is used as the
    # untrusted verification key)
    _, pub2 = keygen(tmp_path / "k2.pem", tmp_path / "k2.pub")
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t", privkey_pem=priv)
    # signed with `priv`, verified with `pub2` -> must fail
    with pytest.raises(SignatureError):
        verify(out, trusted_pubkeys=[pub2])


def test_signed_tamper_breaks_signature(src_dir: Path, tmp_path: Path, keypair):
    priv, pub = keypair
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t", privkey_pem=priv)
    # tamper the frames -> manifest_digest recomputed differs -> even though
    # the manifest still carries the OLD signature, the member-digest check
    # fires first (IntegrityError). Either way verify must fail.
    _tamper_member(out, "targets/efab-1.0.frames", byte_index=2, xor=0x01)
    with pytest.raises((IntegrityError, SignatureError)):
        verify(out, trusted_pubkeys=[pub])


def test_signed_no_keys_supplied(src_dir: Path, tmp_path: Path, keypair):
    priv, _pub = keypair
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t", privkey_pem=priv)
    with pytest.raises(SignatureError):
        verify(out, trusted_pubkeys=None, allow_unsigned=False)


# --------------------------------------------------------------------------- #
# info / errors
# --------------------------------------------------------------------------- #
def test_info(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="myname", version="1.2.3", target="efab-1.0")
    i = info(out)
    assert i["name"] == "myname"
    assert i["version"] == "1.2.3"
    assert i["signed"] is False
    assert "targets/efab-1.0.frames" in i["frames"]


def test_pack_missing_targets(tmp_path: Path):
    d = tmp_path / "empty"
    d.mkdir()
    with pytest.raises(EthimgError):
        pack(d, tmp_path / "x.eth", name="t")


def test_bad_schema_rejected(src_dir: Path, tmp_path: Path):
    out = tmp_path / "x.eth"
    pack(src_dir, out, name="t")
    _tamper_manifest_field(out, top_scalar="schema", new_value="evil.v9")
    with pytest.raises(EthimgError):
        verify(out, allow_unsigned=True)


def test_cli_pack_verify(src_dir: Path, tmp_path: Path, monkeypatch):
    from ethimg import _cli
    out = tmp_path / "x.eth"
    assert _cli(["pack", str(src_dir), str(out)]) == 0
    assert out.is_file()
    assert _cli(["verify", str(out), "--allow-unsigned"]) == 0
    assert _cli(["info", str(out)]) == 0


# --------------------------------------------------------------------------- #
# tar-tampering helpers
# --------------------------------------------------------------------------- #
def _read_tar(path: Path) -> dict:
    with tarfile.open(path, "r") as tf:
        return {n: (tf.extractfile(n).read() if tf.extractfile(n) else b"") for n in tf.getnames()}


def _write_tar(path: Path, members: dict) -> None:
    with tarfile.open(path, "w") as tf:
        for n, data in members.items():
            info = tarfile.TarInfo(name=n)
            info.size = len(data)
            info.mtime = 0
            tf.addfile(info, io.BytesIO(data))


def _tamper_member(path: Path, member: str, byte_index: int, xor: int) -> None:
    m = _read_tar(path)
    b = bytearray(m[member])
    b[byte_index] ^= xor
    m[member] = bytes(b)
    _write_tar(path, m)


def _inject_member(path: Path, member: str, data: bytes) -> None:
    m = _read_tar(path)
    m[member] = data
    _write_tar(path, m)


def _remove_member(path: Path, member: str) -> None:
    m = _read_tar(path)
    m.pop(member, None)
    _write_tar(path, m)


def _tamper_manifest_field(
    eth_path: Path,
    *,
    member_field: str = "",
    new_digest: str = "",
    top_scalar: str = "",
    new_value: str = "",
) -> None:
    """Edit a field in the manifest. Supports:
    - member_field+new_digest: rewrite members[member_field] digest;
    - top_scalar+new_value: rewrite a top-level scalar (e.g. schema)."""
    m = _read_tar(eth_path)
    man = yaml.safe_load(m["manifest.yaml"]) or {}
    if member_field:
        man.setdefault("members", {})[member_field] = new_digest
    if top_scalar:
        man[top_scalar] = new_value
    m["manifest.yaml"] = yaml.safe_dump(man, sort_keys=True).encode("utf-8")
    _write_tar(eth_path, m)
