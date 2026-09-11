# SPDX-License-Identifier: MIT
"""Tests for oci_registry (S09 / E3-REP1).

Covers the OCI artifact mapping of ``.eth`` logic images:

  * push -> local ``oci-layout`` structure + media types (S09 sec 2.3);
  * push -> pull round trip with digest verification, signed + unsigned;
  * tag versioning and digest references;
  * tamper detection: blob byte flip, re-digested artifact tamper, grafted
    config/artifact pair;
  * error taxonomy: malformed layout/index, missing blob, missing ref, bad ref;
  * the HTTP transport against an in-process fake registry (no real registry
    process needed) including a 404 and a tampered-blob case.
"""
from __future__ import annotations

import io
import json
import subprocess
import sys
import tarfile
import threading
import urllib.parse
from collections.abc import Iterator
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import pytest

# oci_registry.py + ethimg.py live in this dir; importable regardless of the
# pytest invocation CWD (same convention as test_ethimg.py).
_TOOLS_DIR = str(Path(__file__).resolve().parent)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

import ethimg
import oci_registry
from oci_registry import (
    ET_ARTIFACT_MEDIA_TYPE,
    ET_CONFIG_MEDIA_TYPE,
    OCI_IMAGE_LAYOUT_FILENAME,
    OCI_INDEX_FILENAME,
    OCI_MANIFEST_MEDIA_TYPE,
    DigestError,
    LayoutError,
    LayoutStore,
    MappingError,
    NotFoundError,
    RefError,
    RegistryClient,
    inspect,
    parse_ref,
    pull,
    push,
)

# The media type reserved by S09 sec 2.3 — asserted as a literal so a silent rename
# of the constant cannot slip through.
S09_ARTIFACT_MEDIA_TYPE = "application/vnd.ethereal.image.v1+tar"


# --------------------------------------------------------------------------- #
# helpers / fixtures
# --------------------------------------------------------------------------- #
def _pack_image(
    work: Path,
    *,
    name: str,
    version: str = "0.1.0",
    seed: int = 0xA0,
    privkey_pem: bytes | None = None,
    frames: bytes | None = None,
) -> Path:
    """Build a minimal valid ``.eth`` (optionally signed) under ``work``."""
    src = work / f"src-{name}-{version}"
    (src / "targets").mkdir(parents=True, exist_ok=True)
    if frames is None:
        frames = b"".join(int.to_bytes(seed + i, 4, "little") for i in range(4))
    (src / "targets" / "efab-1.0.frames").write_bytes(frames)
    (src / "targets" / "efab-1.0.meta.json").write_text(
        '{"frames": 1, "words_per_frame": 4}', encoding="utf-8"
    )
    out = work / f"{name}-{version}.eth"
    ethimg.pack(
        src,
        out,
        name=name,
        version=version,
        target="efab-1.0",
        privkey_pem=privkey_pem,
    )
    return out


@pytest.fixture
def keypair(tmp_path: Path) -> tuple[bytes, bytes]:
    if not ethimg.ed25519_available():
        pytest.skip("cryptography not installed")
    priv, pub = ethimg.keygen(tmp_path / "id_ed25519", tmp_path / "id_ed25519.pub")
    return priv, pub


@pytest.fixture
def layout(tmp_path: Path) -> LayoutStore:
    return LayoutStore(tmp_path / "layout")


def _retar(eth_path: Path, member: str, replacement: bytes) -> bytes:
    """Return the tar bytes of ``eth_path`` with ``member`` replaced."""
    out = io.BytesIO()
    with tarfile.open(eth_path, "r") as src, tarfile.open(fileobj=out, mode="w") as dst:
        for info in src.getmembers():
            handle = src.extractfile(info)
            payload = handle.read() if handle is not None else b""
            if info.name == member:
                payload = replacement
            new_info = tarfile.TarInfo(info.name)
            new_info.size = len(payload)
            new_info.mtime = 0
            dst.addfile(new_info, io.BytesIO(payload))
    return out.getvalue()


def _canonical(doc: dict[str, Any]) -> bytes:
    return json.dumps(doc, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _store_manifest(
    store: LayoutStore, ref: str, config: dict[str, Any], layer: dict[str, Any]
) -> None:
    """Write a hand-built (possibly grafted) manifest document into a layout."""
    doc = {
        "schemaVersion": 2,
        "mediaType": OCI_MANIFEST_MEDIA_TYPE,
        "artifactType": ET_ARTIFACT_MEDIA_TYPE,
        "config": config,
        "layers": [layer],
    }
    store.put_manifest(parse_ref(ref), _canonical(doc), OCI_MANIFEST_MEDIA_TYPE)

def _run_ethctl(args: list[str]) -> subprocess.CompletedProcess[str]:
    """Run the real ``ethctl`` CLI (S08) in a subprocess for the push/pull hook."""
    return subprocess.run(
        [sys.executable, "-m", "ethctl", *args],
        cwd=_TOOLS_DIR,
        capture_output=True,
        check=False,
        text=True,
    )


# --------------------------------------------------------------------------- #
# reference parsing
# --------------------------------------------------------------------------- #
def test_parse_ref_forms() -> None:
    assert parse_ref("aes128") == oci_registry.Reference(name="aes128", tag=None)
    assert parse_ref("aes128:1.0.0").tag == "1.0.0"
    assert parse_ref("ns/sub/img:latest").name == "ns/sub/img"
    # host:port must not be mistaken for a tag
    host_port = parse_ref("localhost:5000/ns/img:v2")
    assert (host_port.name, host_port.tag) == ("localhost:5000/ns/img", "v2")
    digest_ref = parse_ref("img@sha256:" + "ab" * 32)
    assert digest_ref.digest == "sha256:" + "ab" * 32
    assert digest_ref.tag is None


@pytest.mark.parametrize(
    "bad",
    ["", "   ", "/img", "img/", "img//x", "img@", "img@sha256:xyz", "img@md5:" + "ab" * 32],
)
def test_parse_ref_rejects_malformed(bad: str) -> None:
    with pytest.raises(RefError):
        parse_ref(bad)


def test_push_requires_tag_reference(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha")
    with pytest.raises(RefError, match="tag reference"):
        push(layout, "alpha@sha256:" + "ab" * 32, eth)


# --------------------------------------------------------------------------- #
# layout structure + media-type mapping (S09 sec 2.3)
# --------------------------------------------------------------------------- #
def test_push_creates_oci_layout_structure(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="1.2.3")
    result = push(layout, "alpha:1.2.3", eth)

    marker = json.loads((layout.root / OCI_IMAGE_LAYOUT_FILENAME).read_text("utf-8"))
    assert marker == {"imageLayoutVersion": "1.0.0"}

    index = json.loads((layout.root / OCI_INDEX_FILENAME).read_text("utf-8"))
    assert index["schemaVersion"] == 2
    assert len(index["manifests"]) == 1
    entry = index["manifests"][0]
    assert entry["mediaType"] == OCI_MANIFEST_MEDIA_TYPE
    assert entry["digest"] == result.descriptor.digest
    assert entry["annotations"]["org.opencontainers.image.ref.name"] == "1.2.3"
    assert entry["annotations"]["io.ethereal.image.name"] == "alpha"

    # manifest + config + layer blobs all landed content-addressed under sha256/
    for digest in (result.descriptor.digest, result.config.digest, result.layer.digest):
        assert layout.blob_path(digest).is_file()
        assert layout.blob_path(digest).parent.name == "sha256"

    assert result.layer.media_type == S09_ARTIFACT_MEDIA_TYPE == ET_ARTIFACT_MEDIA_TYPE
    assert result.config.media_type == ET_CONFIG_MEDIA_TYPE
    assert result.signed is False
    assert result.manifest_digest == ethimg.read_manifest(eth).manifest_digest


def test_manifest_document_maps_eth_metadata(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.4.0")
    pushed = push(layout, "alpha:0.4.0", eth)
    raw, media_type = layout.get_manifest(parse_ref("alpha:0.4.0"))
    doc = json.loads(raw)

    assert media_type == OCI_MANIFEST_MEDIA_TYPE
    assert doc["mediaType"] == OCI_MANIFEST_MEDIA_TYPE
    assert doc["artifactType"] == ET_ARTIFACT_MEDIA_TYPE
    assert doc["config"]["digest"] == pushed.config.digest
    assert len(doc["layers"]) == 1
    assert doc["layers"][0] == {
        "mediaType": S09_ARTIFACT_MEDIA_TYPE,
        "digest": pushed.layer.digest,
        "size": pushed.layer.size,
    }
    assert doc["annotations"]["org.opencontainers.image.title"] == "alpha"
    assert doc["annotations"]["org.opencontainers.image.version"] == "0.4.0"
    assert doc["annotations"]["io.ethereal.image.target"] == "efab-1.0"
    assert (
        doc["annotations"]["io.ethereal.image.manifest-digest"] == pushed.manifest_digest
    )

    config = json.loads(layout.get_blob("alpha", pushed.config.digest))
    assert config["schema"] == oci_registry.ET_CONFIG_SCHEMA
    assert config["image"]["name"] == "alpha"
    assert config["image"]["schema"] == ethimg.SCHEMA
    assert config["manifest_digest"] == pushed.manifest_digest
    assert config["artifact"]["digest"] == pushed.layer.digest
    assert config["artifact"]["size"] == pushed.layer.size
    assert config["signature"] is None
    # the authoritative signature value never leaves the .eth artifact
    assert "value" not in json.dumps(config)


# --------------------------------------------------------------------------- #
# round trip
# --------------------------------------------------------------------------- #
def test_roundtrip_signed_with_trusted_key(
    layout: LayoutStore, tmp_path: Path, keypair: tuple[bytes, bytes]
) -> None:
    priv, pub = keypair
    eth = _pack_image(tmp_path, name="aes128", version="1.0.0", privkey_pem=priv)
    pushed = push(layout, "aes128:1.0.0", eth, trusted_pubkeys=[pub])
    assert pushed.signed is True

    dest = tmp_path / "out" / "aes128.eth"
    pulled = pull(layout, "aes128:1.0.0", dest, trusted_pubkeys=[pub])

    assert dest.read_bytes() == eth.read_bytes()  # byte-identical artifact
    assert pulled.path == dest
    assert (pulled.name, pulled.version, pulled.target) == ("aes128", "1.0.0", "efab-1.0")
    assert pulled.manifest_digest == pushed.manifest_digest
    assert pulled.signed is True
    ethimg.verify(dest, trusted_pubkeys=[pub])  # the standard S09 verifier agrees


def test_roundtrip_unsigned_requires_allow_unsigned(
    layout: LayoutStore, tmp_path: Path
) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    push(layout, "alpha:0.1.0", eth)

    # default policy (S09 sec 2.2): unsigned images are rejected
    with pytest.raises(ethimg.SignatureError):
        pull(layout, "alpha:0.1.0", tmp_path / "rejected.eth")
    assert not (tmp_path / "rejected.eth").exists()

    pulled = pull(layout, "alpha:0.1.0", tmp_path / "ok.eth", allow_unsigned=True)
    assert pulled.signed is False
    assert (tmp_path / "ok.eth").read_bytes() == eth.read_bytes()


def test_untrusted_key_is_rejected(
    layout: LayoutStore, tmp_path: Path, keypair: tuple[bytes, bytes]
) -> None:
    priv, pub = keypair
    eth = _pack_image(tmp_path, name="signed", version="1.0.0", privkey_pem=priv)
    push(layout, "signed:1.0.0", eth, trusted_pubkeys=[pub])

    _, other_pub = ethimg.keygen(tmp_path / "other", tmp_path / "other.pub")
    with pytest.raises(ethimg.SignatureError, match="did not verify"):
        pull(layout, "signed:1.0.0", tmp_path / "nope.eth", trusted_pubkeys=[other_pub])


def test_push_signed_image_requires_key(
    layout: LayoutStore, tmp_path: Path, keypair: tuple[bytes, bytes]
) -> None:
    priv, _ = keypair
    eth = _pack_image(tmp_path, name="signed", version="1.0.0", privkey_pem=priv)

    with pytest.raises(oci_registry.OciError, match="signed image"):
        push(layout, "signed:1.0.0", eth)
    assert not (layout.root / OCI_INDEX_FILENAME).exists()


def test_pull_into_directory_uses_name_and_version(
    layout: LayoutStore, tmp_path: Path
) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="2.3.4")
    push(layout, "alpha:2.3.4", eth)
    out_dir = tmp_path / "images"
    out_dir.mkdir()

    pulled = pull(layout, "alpha:2.3.4", out_dir, allow_unsigned=True)
    assert pulled.path == out_dir / "alpha-2.3.4.eth"
    assert pulled.path.read_bytes() == eth.read_bytes()


def test_tags_keep_versions_apart(layout: LayoutStore, tmp_path: Path) -> None:
    v1 = _pack_image(tmp_path, name="alpha", version="0.1.0", seed=0x10)
    v2 = _pack_image(tmp_path, name="alpha", version="0.2.0", seed=0x20)
    push(layout, "alpha:0.1.0", v1)
    push(layout, "alpha:0.2.0", v2)

    index = json.loads((layout.root / OCI_INDEX_FILENAME).read_text("utf-8"))
    assert len(index["manifests"]) == 2

    one = pull(layout, "alpha:0.1.0", tmp_path / "o1.eth", allow_unsigned=True)
    two = pull(layout, "alpha:0.2.0", tmp_path / "o2.eth", allow_unsigned=True)
    assert (one.version, two.version) == ("0.1.0", "0.2.0")
    assert one.path.read_bytes() == v1.read_bytes()
    assert two.path.read_bytes() == v2.read_bytes()

    # re-pushing the same tag replaces the index entry instead of duplicating it
    push(layout, "alpha:0.1.0", v2)
    index = json.loads((layout.root / OCI_INDEX_FILENAME).read_text("utf-8"))
    assert len(index["manifests"]) == 2


def test_pull_by_digest_reference(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)

    pulled = pull(
        layout, f"alpha@{pushed.descriptor.digest}", tmp_path / "d.eth", allow_unsigned=True
    )
    assert pulled.path.read_bytes() == eth.read_bytes()
    assert pulled.descriptor.digest == pushed.descriptor.digest


def test_inspect_reports_descriptor_graph(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.5.0")
    pushed = push(layout, "alpha:0.5.0", eth)
    facts = inspect(layout, "alpha:0.5.0")

    assert facts["name"] == "alpha"
    assert facts["version"] == "0.5.0"
    assert facts["digest"] == pushed.descriptor.digest
    assert facts["layer"]["digest"] == pushed.layer.digest
    assert facts["manifest_digest"] == pushed.manifest_digest
    assert facts["signed"] is False
    assert facts["annotations"]["org.opencontainers.image.title"] == "alpha"
    assert "targets/efab-1.0.frames" in facts["members"]
    assert facts["config"]["mediaType"] == ET_CONFIG_MEDIA_TYPE


# --------------------------------------------------------------------------- #
# tamper detection
# --------------------------------------------------------------------------- #
def test_tampered_layer_blob_is_detected(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)

    blob = layout.blob_path(pushed.layer.digest)
    data = bytearray(blob.read_bytes())
    data[-1] ^= 0xFF
    blob.write_bytes(bytes(data))

    with pytest.raises(DigestError, match="digest mismatch"):
        pull(layout, "alpha:0.1.0", tmp_path / "out.eth", allow_unsigned=True)


def test_tampered_manifest_blob_is_detected(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)

    blob = layout.blob_path(pushed.descriptor.digest)
    blob.write_bytes(blob.read_bytes().replace(b'"config"', b'"Confiq"'))

    with pytest.raises(DigestError, match="digest mismatch"):
        pull(layout, "alpha:0.1.0", tmp_path / "out.eth", allow_unsigned=True)


def test_tampered_artifact_survives_redigested_oci_graph(
    layout: LayoutStore, tmp_path: Path
) -> None:
    """An attacker who re-digests the whole OCI graph still fails the .eth check."""
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)
    original_config = json.loads(layout.get_blob("alpha", pushed.config.digest))

    tampered = _retar(eth, "targets/efab-1.0.frames", b"\x00" * 16)
    new_layer_digest = layout.put_blob("alpha", tampered)
    config_doc = json.loads(json.dumps(original_config))
    config_doc["artifact"]["digest"] = new_layer_digest
    config_doc["artifact"]["size"] = len(tampered)
    config_bytes = _canonical(config_doc)
    config_digest = layout.put_blob("alpha", config_bytes)
    _store_manifest(
        layout,
        "alpha:1.0.0-evil",
        {
            "mediaType": ET_CONFIG_MEDIA_TYPE,
            "digest": config_digest,
            "size": len(config_bytes),
        },
        {
            "mediaType": ET_ARTIFACT_MEDIA_TYPE,
            "digest": new_layer_digest,
            "size": len(tampered),
        },
    )

    dest = tmp_path / "evil.eth"
    with pytest.raises(ethimg.IntegrityError):
        pull(layout, "alpha:1.0.0-evil", dest, allow_unsigned=True)
    assert not dest.exists()
    assert not dest.with_name(dest.name + ".part").exists()  # no partial artifact


def test_grafted_config_artifact_pair_is_rejected(
    layout: LayoutStore, tmp_path: Path
) -> None:
    alpha = _pack_image(tmp_path, name="alpha", version="1.0.0", seed=0x11)
    beta = _pack_image(tmp_path, name="beta", version="2.0.0", seed=0x22)
    push(layout, "alpha:1.0.0", alpha)
    push(layout, "beta:2.0.0", beta)
    a_facts = inspect(layout, "alpha:1.0.0")
    b_facts = inspect(layout, "beta:2.0.0")

    # beta's config descriptor next to alpha's layer -> descriptor graph mismatch
    _store_manifest(layout, "graft:1.0.0", b_facts["config"], a_facts["layer"])
    with pytest.raises(MappingError, match="config describes artifact"):
        pull(layout, "graft:1.0.0", tmp_path / "g.eth", allow_unsigned=True)


def test_config_identity_mismatch_is_rejected(layout: LayoutStore, tmp_path: Path) -> None:
    """Consistent digests but a lying config name must still fail the pull."""
    eth = _pack_image(tmp_path, name="alpha", version="1.0.0")
    pushed = push(layout, "alpha:1.0.0", eth)
    config_doc = json.loads(layout.get_blob("alpha", pushed.config.digest))
    config_doc["image"]["name"] = "beta"
    config_bytes = _canonical(config_doc)
    config_digest = layout.put_blob("alpha", config_bytes)
    _store_manifest(
        layout,
        "lying:1.0.0",
        {
            "mediaType": ET_CONFIG_MEDIA_TYPE,
            "digest": config_digest,
            "size": len(config_bytes),
        },
        pushed.layer.to_dict(),
    )

    with pytest.raises(MappingError, match="identity"):
        pull(layout, "lying:1.0.0", tmp_path / "l.eth", allow_unsigned=True)


# --------------------------------------------------------------------------- #
# error taxonomy: malformed layouts, missing content
# --------------------------------------------------------------------------- #
def test_missing_layout_marker(tmp_path: Path) -> None:
    empty = tmp_path / "not-a-layout"
    empty.mkdir()
    store = LayoutStore(empty)
    with pytest.raises(LayoutError, match=OCI_IMAGE_LAYOUT_FILENAME):
        pull(store, "alpha:1.0.0", tmp_path / "out.eth", allow_unsigned=True)


@pytest.mark.parametrize(
    "layout_doc",
    [
        "{not json",
        '{"imageLayoutVersion": "0.9.0"}',
        '["nope"]',
    ],
)
def test_malformed_layout_marker(tmp_path: Path, layout_doc: str) -> None:
    root = tmp_path / "layout"
    root.mkdir()
    (root / OCI_IMAGE_LAYOUT_FILENAME).write_text(layout_doc, encoding="utf-8")
    (root / OCI_INDEX_FILENAME).write_text('{"schemaVersion": 2, "manifests": []}')
    with pytest.raises(LayoutError):
        LayoutStore(root).get_manifest(parse_ref("alpha:1.0.0"))


@pytest.mark.parametrize(
    "index_doc",
    [
        "{not json",
        '{"schemaVersion": 3, "manifests": []}',
        '{"schemaVersion": 2, "manifests": {}}',
        '{"schemaVersion": 2, "manifests": [{"mediaType": "x"}]}',
        (
            '{"schemaVersion": 2, "manifests": [{"mediaType": "x", '
            '"digest": "sha256:zz", "size": 1}]}'
        ),
    ],
)
def test_malformed_index(tmp_path: Path, index_doc: str) -> None:
    root = tmp_path / "layout"
    root.mkdir()
    (root / OCI_IMAGE_LAYOUT_FILENAME).write_text('{"imageLayoutVersion": "1.0.0"}')
    (root / OCI_INDEX_FILENAME).write_text(index_doc, encoding="utf-8")
    with pytest.raises(LayoutError):
        LayoutStore(root).get_manifest(parse_ref("alpha:1.0.0"))


def test_missing_index_file(tmp_path: Path) -> None:
    root = tmp_path / "layout"
    root.mkdir()
    (root / OCI_IMAGE_LAYOUT_FILENAME).write_text('{"imageLayoutVersion": "1.0.0"}')
    with pytest.raises(LayoutError, match=OCI_INDEX_FILENAME):
        LayoutStore(root).get_manifest(parse_ref("alpha:1.0.0"))


def test_missing_blob_is_not_found(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)
    layout.blob_path(pushed.layer.digest).unlink()

    with pytest.raises(NotFoundError, match="blob not found"):
        pull(layout, "alpha:0.1.0", tmp_path / "out.eth", allow_unsigned=True)


def test_missing_blob_byte_flip_on_index_target(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(layout, "alpha:0.1.0", eth)
    layout.blob_path(pushed.config.digest).unlink()

    with pytest.raises(NotFoundError, match="blob not found"):
        inspect(layout, "alpha:0.1.0")


def test_unknown_reference_is_not_found(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    push(layout, "alpha:0.1.0", eth)

    with pytest.raises(NotFoundError, match="not found"):
        pull(layout, "other:1.0.0", tmp_path / "out.eth", allow_unsigned=True)
    with pytest.raises(NotFoundError, match="not found"):
        pull(layout, "alpha:9.9.9", tmp_path / "out.eth", allow_unsigned=True)
    with pytest.raises(NotFoundError, match="no manifest"):
        pull(
            layout,
            "alpha@sha256:" + "cd" * 32,
            tmp_path / "out.eth",
            allow_unsigned=True,
        )


def test_push_refuses_corrupt_image(layout: LayoutStore, tmp_path: Path) -> None:
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    eth.write_bytes(_retar(eth, "targets/efab-1.0.frames", b"\x00" * 16))

    with pytest.raises(ethimg.IntegrityError):
        push(layout, "alpha:0.1.0", eth)
    assert not (layout.root / OCI_INDEX_FILENAME).exists()  # nothing published


def test_push_missing_file(layout: LayoutStore, tmp_path: Path) -> None:
    with pytest.raises(oci_registry.OciError, match="no such"):
        push(layout, "alpha:0.1.0", tmp_path / "nope.eth")


# --------------------------------------------------------------------------- #
# HTTP registry transport (against an in-process fake registry)
# --------------------------------------------------------------------------- #
@dataclass
class _RegistryState:
    blobs: dict[str, bytes] = field(default_factory=dict)
    manifests: dict[tuple[str, str], tuple[bytes, str]] = field(default_factory=dict)


def _make_handler(state: _RegistryState) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt: str, *args: Any) -> None:
            del fmt, args  # keep the test output clean

        def _reply(
            self,
            status: int,
            body: bytes = b"",
            content_type: str = "application/octet-stream",
        ) -> None:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body:
                self.wfile.write(body)

        def _route(self) -> tuple[str, str, str] | None:
            path = urllib.parse.urlsplit(self.path).path
            if not path.startswith("/v2/"):
                return None
            rest = path[len("/v2/") :]
            for kind in ("blobs", "manifests"):
                marker = f"/{kind}/"
                idx = rest.find(marker)
                if idx >= 0:
                    return kind, rest[:idx], rest[idx + len(marker) :]
            return None

        def _read_body(self) -> bytes:
            length = int(self.headers.get("Content-Length", "0"))
            return self.rfile.read(length)

        def do_HEAD(self) -> None:
            route = self._route()
            if route is not None and route[0] == "blobs" and route[2] in state.blobs:
                self._reply(200)
                return
            self._reply(404)

        def do_GET(self) -> None:
            route = self._route()
            if route is None:
                self._reply(404)
                return
            kind, name, target = route
            if kind == "blobs" and target in state.blobs:
                self._reply(200, state.blobs[target])
                return
            hit = state.manifests.get((name, target))
            if kind == "manifests" and hit is not None:
                body, media_type = hit
                self._reply(200, body, media_type)
                return
            self._reply(404)

        def do_POST(self) -> None:
            route = self._route()
            if route is None or route[0] != "blobs":
                self._reply(404)
                return
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
            digest = (query.get("digest") or [""])[0]
            if not digest:
                self._reply(400)
                return
            state.blobs[digest] = self._read_body()
            self._reply(201)

        def do_PUT(self) -> None:
            route = self._route()
            if route is None or route[0] != "manifests":
                self._reply(404)
                return
            _, name, tag = route
            media_type = self.headers.get("Content-Type", OCI_MANIFEST_MEDIA_TYPE)
            state.manifests[(name, tag)] = (self._read_body(), media_type)
            self._reply(201)

    return Handler


@pytest.fixture
def fake_registry() -> Iterator[tuple[str, _RegistryState]]:
    state = _RegistryState()
    server = ThreadingHTTPServer(("127.0.0.1", 0), _make_handler(state))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        port = int(server.server_address[1])
        yield f"http://127.0.0.1:{port}", state
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def test_registry_roundtrip(
    fake_registry: tuple[str, _RegistryState], tmp_path: Path
) -> None:
    base_url, state = fake_registry
    client = RegistryClient(base_url)
    eth = _pack_image(tmp_path, name="aes128", version="1.0.0")

    pushed = push(client, "ns/aes128:1.0.0", eth)
    assert pushed.layer.digest in state.blobs
    assert ("ns/aes128", "1.0.0") in state.manifests

    dest = tmp_path / "pulled.eth"
    pulled = pull(client, "ns/aes128:1.0.0", dest, allow_unsigned=True)
    assert dest.read_bytes() == eth.read_bytes()
    assert pulled.version == "1.0.0"

    # re-push is idempotent (HEAD hit short-circuits the blob upload)
    again = push(client, "ns/aes128:1.0.0", eth)
    assert again.descriptor.digest == pushed.descriptor.digest
    assert inspect(client, "ns/aes128:1.0.0")["digest"] == pushed.descriptor.digest


def test_registry_missing_reference(
    fake_registry: tuple[str, _RegistryState], tmp_path: Path
) -> None:
    base_url, _ = fake_registry
    client = RegistryClient(base_url)
    with pytest.raises(NotFoundError, match="not found in registry"):
        pull(client, "ghost:1.0.0", tmp_path / "out.eth", allow_unsigned=True)


def test_registry_tampered_blob_is_detected(
    fake_registry: tuple[str, _RegistryState], tmp_path: Path
) -> None:
    base_url, state = fake_registry
    client = RegistryClient(base_url)
    eth = _pack_image(tmp_path, name="alpha", version="0.1.0")
    pushed = push(client, "alpha:0.1.0", eth)

    blob = bytearray(state.blobs[pushed.layer.digest])
    blob[-1] ^= 0xFF
    state.blobs[pushed.layer.digest] = bytes(blob)

    with pytest.raises(DigestError, match="digest mismatch"):
        pull(client, "alpha:0.1.0", tmp_path / "out.eth", allow_unsigned=True)


def test_registry_transport_error() -> None:
    # nothing listening on this port -> network-level TransportError
    client = RegistryClient("http://127.0.0.1:1")
    with pytest.raises(oci_registry.TransportError):
        inspect(client, "alpha:1.0.0")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def test_cli_push_pull_inspect(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    layout_dir = tmp_path / "layout"
    eth = _pack_image(tmp_path, name="alpha", version="0.3.0")

    assert (
        oci_registry.main(
            ["push", str(eth), "alpha:0.3.0", "--layout", str(layout_dir)]
        )
        == 0
    )
    assert "pushed alpha:0.3.0" in capsys.readouterr().out

    dest = tmp_path / "cli.eth"
    assert (
        oci_registry.main(
            [
                "pull",
                "alpha:0.3.0",
                str(dest),
                "--layout",
                str(layout_dir),
                "--allow-unsigned",
            ]
        )
        == 0
    )
    assert dest.read_bytes() == eth.read_bytes()

    assert oci_registry.main(["inspect", "alpha:0.3.0", "--layout", str(layout_dir)]) == 0
    assert "manifest_digest:" in capsys.readouterr().out


def test_cli_signed_push_pull(
    tmp_path: Path, keypair: tuple[bytes, bytes], capsys: pytest.CaptureFixture[str]
) -> None:
    priv, pub = keypair
    pub_path = tmp_path / "id_ed25519.pub"
    layout_dir = tmp_path / "layout"
    eth = _pack_image(tmp_path, name="signed", version="1.0.0", privkey_pem=priv)

    assert (
        oci_registry.main(
            [
                "push",
                str(eth),
                "signed:1.0.0",
                "--layout",
                str(layout_dir),
                "--pubkey",
                str(pub_path),
            ]
        )
        == 0
    )
    assert "signed=True" in capsys.readouterr().out

    dest = tmp_path / "cli-signed.eth"
    assert (
        oci_registry.main(
            [
                "pull",
                "signed:1.0.0",
                str(dest),
                "--layout",
                str(layout_dir),
                "--pubkey",
                str(pub_path),
            ]
        )
        == 0
    )
    assert dest.read_bytes() == eth.read_bytes()
    ethimg.verify(dest, trusted_pubkeys=[pub])


def test_ethctl_push_pull_hook(tmp_path: Path) -> None:
    """S08/S09 sec 2.3 promises ``ethctl push/pull``; drive the real CLI process."""
    eth = _pack_image(tmp_path, name="alpha", version="0.9.0")
    layout_dir = tmp_path / "layout"
    dest = tmp_path / "via-ethctl.eth"

    pushed = _run_ethctl(["push", str(eth), "alpha:0.9.0", "--layout", str(layout_dir)])
    assert pushed.returncode == 0, pushed.stderr
    assert "pushed alpha:0.9.0" in pushed.stdout

    pulled = _run_ethctl(
        [
            "pull",
            "alpha:0.9.0",
            str(dest),
            "--layout",
            str(layout_dir),
            "--allow-unsigned",
        ]
    )
    assert pulled.returncode == 0, pulled.stderr
    assert dest.read_bytes() == eth.read_bytes()

    # error path: no transport selected -> clear message, exit 1
    broken = _run_ethctl(["pull", "alpha:0.9.0", str(dest)])
    assert broken.returncode == 1
    assert "select a transport" in broken.stderr


def test_cli_reports_errors(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    layout_dir = tmp_path / "layout"
    eth = _pack_image(tmp_path, name="alpha", version="0.3.0")
    oci_registry.main(["push", str(eth), "alpha:0.3.0", "--layout", str(layout_dir)])

    # no transport selected
    assert oci_registry.main(["inspect", "alpha:0.3.0"]) == 1
    assert "select a transport" in capsys.readouterr().err

    # unsigned pull without --allow-unsigned
    rc = oci_registry.main(
        ["pull", "alpha:0.3.0", str(tmp_path / "x.eth"), "--layout", str(layout_dir)]
    )
    assert rc == 1
    assert "unsigned" in capsys.readouterr().err

    # bad reference
    assert (
        oci_registry.main(["inspect", "img@sha256:nope", "--layout", str(layout_dir)])
        == 1
    )
