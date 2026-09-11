# SPDX-License-Identifier: MIT
"""oci_registry — OCI artifact transport for ``.eth`` logic images (E3-REP1).

Pushes / pulls a ``.eth`` logic image (S09 sec 2.1) to / from an **OCI artifact**
store, so the cloud-native registry ecosystem (GitHub Packages, Harbor, ...) can
host Ethereal images — S09 sec 2.3 (v2): the ``.eth`` becomes an OCI artifact with
the custom media type ``application/vnd.ethereal.image.v1+tar``.

OCI mapping (v1: one single-target image -> one single-layer artifact)::

    .eth tar                     -> layer blob   (.../ethereal.image.v1+tar)
    ethimg manifest summary      -> config blob  (.../ethereal.image.config.v1+json)
    OCI image manifest (v1+json) -> artifact manifest, artifactType = layer media type
    <repository>:<tag>           -> index entry (local layout) / manifest tag (registry)

Integrity model:
  * every blob is content-addressed by ``sha256:<hex>``; the digest is re-checked
    on EVERY read (:class:`DigestError`) and the descriptor ``size`` against the
    actual byte count;
  * the config blob pins the exact artifact blob it describes
    (``artifact.digest`` / ``artifact.size``) and the ethimg-internal
    ``manifest_digest``, so a swapped config/artifact pair is rejected on pull
    (:class:`MappingError`);
  * once the blobs verify, the pulled ``.eth`` goes through
    :func:`ethimg.verify` — the S09 sec 2.2 Ed25519 trust policy is the SAME as for a
    local file, there is no OCI-specific trust path. The authoritative signature
    stays INSIDE the ``.eth`` manifest; the OCI config only records the key
    fingerprint (for indexing/discovery, never for trust).

Transports (both satisfy :class:`Store`):
  * :class:`LayoutStore` — a local OCI image layout directory
    (``oci-layout`` + ``index.json`` + ``blobs/sha256/...``); no registry
    process involved. This is the fully tested path (E3-REP1 scope).
  * :class:`RegistryClient` — OCI distribution-spec v2 over HTTP
    (``/v2/<name>/manifests/<ref>`` + ``/v2/<name>/blobs/<digest>``): monolithic
    blob upload, explicit ``Authorization`` passthrough, NO token negotiation
    (a real registry needs a token handshake for private repos — see the E3-REP1
    report notes).

Plan-Ref: ethereal-plan/subsystems/S09-镜像格式与仓库.md sec 2.3 (OCI registry v2),
          sec 2.1 (logic-image structure), sec 2.2 (signature / trust model).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

# ethimg lives alongside (ethereal-tools/tools/); ensure importable regardless of
# the CWD pytest / the CLI is invoked from.
_THIS_DIR = str(Path(__file__).resolve().parent)
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# pi-lens-ignore: E402
import ethimg

# --------------------------------------------------------------------------- #
# OCI constants (S09 sec 2.3)
# --------------------------------------------------------------------------- #
OCI_IMAGE_LAYOUT_FILENAME = "oci-layout"
OCI_INDEX_FILENAME = "index.json"
OCI_BLOBS_DIR = "blobs"
OCI_LAYOUT_VERSION = "1.0.0"

OCI_INDEX_MEDIA_TYPE = "application/vnd.oci.image.index.v1+json"
OCI_MANIFEST_MEDIA_TYPE = "application/vnd.oci.image.manifest.v1+json"

#: Custom artifact media type reserved by S09 sec 2.3 for the ``.eth`` tar.
ET_ARTIFACT_MEDIA_TYPE = "application/vnd.ethereal.image.v1+tar"
#: Config blob media type: the OCI-side summary of the ethimg manifest.
ET_CONFIG_MEDIA_TYPE = "application/vnd.ethereal.image.config.v1+json"
#: Schema tag of the config document (mirrors ethimg's ``SCHEMA`` style).
ET_CONFIG_SCHEMA = "ethereal.oci.config.v1"

#: OCI annotation carrying the tag in a layout index entry (OCI image-layout spec).
REF_NAME_ANNOTATION = "org.opencontainers.image.ref.name"
#: Annotation carrying the repository name this tool pushed the entry under.
ET_NAME_ANNOTATION = "io.ethereal.image.name"
ET_TARGET_ANNOTATION = "io.ethereal.image.target"
ET_MANIFEST_DIGEST_ANNOTATION = "io.ethereal.image.manifest-digest"

DEFAULT_TAG = "latest"
#: Content-address algorithm of the OCI mapping (matches ethimg's DIGEST_ALGO).
DIGEST_ALGO: str = ethimg.DIGEST_ALGO
_DIGEST_RE = re.compile(r"^" + DIGEST_ALGO + r":[0-9a-f]{64}$")
_TAG_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$")


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class OciError(Exception):
    """Base error for OCI push/pull operations."""


class RefError(OciError):
    """Malformed image reference (repository / tag / digest)."""


class LayoutError(OciError):
    """Malformed OCI layout: layout marker, index or manifest document."""


class NotFoundError(OciError):
    """The referenced image or blob does not exist in the store."""


class DigestError(OciError):
    """Content does not hash / size-match its descriptor (tamper or bit-rot)."""


class MappingError(OciError):
    """OCI descriptor graph is self-inconsistent (config vs artifact mismatch)."""


class RegistryError(OciError):
    """Registry answered with an unexpected HTTP status."""

    def __init__(self, message: str, *, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class TransportError(OciError):
    """Network-level failure while talking to a registry."""


# --------------------------------------------------------------------------- #
# Digest / descriptor primitives
# --------------------------------------------------------------------------- #
def sha256_digest(data: bytes) -> str:
    """Return the OCI content digest of ``data`` (``sha256:<64 hex>``)."""
    return f"{DIGEST_ALGO}:{hashlib.sha256(data).hexdigest()}"


def _digest_hex(digest: str, *, where: str) -> str:
    """Validate an OCI digest string and return its hex part (blob path segment)."""
    if not _DIGEST_RE.match(digest):
        raise LayoutError(f"{where}: unsupported/malformed digest {digest!r}")
    return digest.split(":", 1)[1]


def verify_digest(
    data: bytes, digest: str, *, where: str, size: int | None = None
) -> None:
    """Check ``data`` against ``digest`` (and ``size`` when given).

    Raises :class:`DigestError` on any mismatch. This is the single choke point
    for pull-side integrity (S09 sec 2.1 tamper requirement).
    """
    if size is not None and len(data) != size:
        raise DigestError(
            f"{where}: size mismatch: descriptor {size}, content {len(data)}"
        )
    actual = sha256_digest(data)
    if actual != digest:
        raise DigestError(f"{where}: digest mismatch: descriptor {digest}, got {actual}")


def _canonical_json(doc: Mapping[str, Any]) -> bytes:
    """Deterministic JSON serialization (sorted keys, compact separators).

    Determinism matters: the config digest is content-addressed, so the same
    image must always produce the same config blob (dedup + reproducibility).
    """
    return json.dumps(
        doc, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")


def _parse_json_object(data: bytes, *, where: str) -> dict[str, Any]:
    try:
        raw = json.loads(data)
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        raise LayoutError(f"{where}: not valid JSON: {e}") from e
    if not isinstance(raw, dict):
        raise LayoutError(f"{where}: expected a JSON object")
    return {str(k): v for k, v in raw.items()}


def _require_str(obj: Mapping[str, Any], key: str, *, where: str) -> str:
    val = obj.get(key)
    if not isinstance(val, str) or not val:
        raise LayoutError(f"{where}.{key}: expected a non-empty string")
    return val


def _require_int(obj: Mapping[str, Any], key: str, *, where: str) -> int:
    val = obj.get(key)
    if isinstance(val, bool) or not isinstance(val, int) or val < 0:
        raise LayoutError(f"{where}.{key}: expected a non-negative integer")
    return val


def _require_object(obj: Mapping[str, Any], key: str, *, where: str) -> dict[str, Any]:
    val = obj.get(key)
    if not isinstance(val, dict):
        raise LayoutError(f"{where}.{key}: expected a JSON object")
    return {str(k): v for k, v in val.items()}


@dataclass(frozen=True)
class Descriptor:
    """An OCI content descriptor (``mediaType`` / ``digest`` / ``size``)."""

    media_type: str
    digest: str
    size: int
    annotations: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        doc: dict[str, Any] = {
            "mediaType": self.media_type,
            "digest": self.digest,
            "size": self.size,
        }
        if self.annotations:
            doc["annotations"] = dict(self.annotations)
        return doc

    @classmethod
    def from_dict(cls, raw: Any, *, where: str) -> Descriptor:
        if not isinstance(raw, dict):
            raise LayoutError(f"{where}: descriptor is not a JSON object")
        obj = {str(k): v for k, v in raw.items()}
        media_type = _require_str(obj, "mediaType", where=where)
        digest = _require_str(obj, "digest", where=where)
        _digest_hex(digest, where=f"{where}.digest")
        size = _require_int(obj, "size", where=where)
        annotations_raw = obj.get("annotations", {})
        if not isinstance(annotations_raw, dict):
            raise LayoutError(f"{where}.annotations: expected an object")
        annotations: dict[str, str] = {}
        for key, val in annotations_raw.items():
            if not isinstance(val, str):
                raise LayoutError(f"{where}.annotations[{key!r}]: expected a string")
            annotations[str(key)] = val
        return cls(media_type=media_type, digest=digest, size=size, annotations=annotations)


@dataclass(frozen=True)
class Reference:
    """A labeled image reference: ``<name>:<tag>`` or ``<name>@<digest>``."""

    name: str
    tag: str | None = None
    digest: str | None = None

    def __str__(self) -> str:
        if self.digest is not None:
            return f"{self.name}@{self.digest}"
        return f"{self.name}:{self.tag or DEFAULT_TAG}"


def parse_ref(ref: str) -> Reference:
    """Parse ``name[:tag][@sha256:...]``; ``tag`` defaults to ``latest`` on use.

    The tag is only recognised when the text after the LAST ``:`` matches the OCI
    tag grammar, so a ``host:port/repo`` name is not mistaken for ``host`` +
    tag ``port/repo``.
    """
    text = ref.strip()
    if not text:
        raise RefError("empty image reference")
    name = text
    digest: str | None = None
    if "@" in text:
        name, _, digest_part = text.partition("@")
        if not digest_part:
            raise RefError(f"{ref!r}: empty digest after '@'")
        try:
            _digest_hex(digest_part, where=f"reference {ref!r}")
        except LayoutError as e:
            raise RefError(str(e)) from e
        digest = digest_part
    tag: str | None = None
    if ":" in name:
        head, _, tail = name.rpartition(":")
        if _TAG_RE.match(tail):
            name, tag = head, tail
    if not name or name.startswith("/") or name.endswith("/") or "//" in name:
        raise RefError(f"{ref!r}: malformed repository name")
    return Reference(name=name, tag=tag, digest=digest)


# --------------------------------------------------------------------------- #
# Transport interface
# --------------------------------------------------------------------------- #
class Store(Protocol):
    """A content-addressed artifact store (local layout or HTTP registry).

    ``name`` scopes blobs to a repository: OCI registries upload blobs per
    repository, while a local layout stores them content-addressed once and
    shares them across repositories (the parameter is then advisory).
    """

    def put_blob(self, name: str, data: bytes) -> str:
        """Store ``data``; return its ``sha256:<hex>`` digest."""
        ...

    def get_blob(self, name: str, digest: str) -> bytes:
        """Return the blob for ``digest`` (verified); raise on absence/mismatch."""
        ...

    def put_manifest(self, ref: Reference, data: bytes, media_type: str) -> str:
        """Store + index a manifest under ``ref``; return its digest."""
        ...

    def get_manifest(self, ref: Reference) -> tuple[bytes, str]:
        """Resolve ``ref`` to ``(manifest bytes, media type)``."""
        ...


class LayoutStore:
    """Local OCI image layout: ``oci-layout`` + ``index.json`` + ``blobs/sha256/``.

    Writes are atomic (temp file + ``os.replace``) so an interrupted push never
    leaves a half-written blob or index behind. The ``index.json`` entries carry
    ``org.opencontainers.image.ref.name`` (tag) + ``io.ethereal.image.name``
    (repository), which is how several images coexist in one layout directory.
    """

    def __init__(self, root: Path | str) -> None:
        self.root = Path(root)

    # -- paths ------------------------------------------------------------- #
    @property
    def layout_path(self) -> Path:
        return self.root / OCI_IMAGE_LAYOUT_FILENAME

    @property
    def index_path(self) -> Path:
        return self.root / OCI_INDEX_FILENAME

    def blob_path(self, digest: str) -> Path:
        hexpart = _digest_hex(digest, where=f"digest {digest!r}")
        return self.root / OCI_BLOBS_DIR / DIGEST_ALGO / hexpart

    # -- convenience ------------------------------------------------------- #
    def has_blob(self, digest: str) -> bool:
        return self.blob_path(digest).is_file()

    # -- Store ------------------------------------------------------------- #
    def put_blob(self, name: str, data: bytes) -> str:
        del name  # content-addressed: blobs are shared across repositories
        digest = sha256_digest(data)
        path = self.blob_path(digest)
        if path.is_file():
            return digest  # already stored (dedup)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        tmp.write_bytes(data)
        os.replace(tmp, path)
        return digest

    def get_blob(self, name: str, digest: str) -> bytes:
        del name
        path = self.blob_path(digest)
        if not path.is_file():
            raise NotFoundError(f"blob not found in layout: {digest}")
        data = path.read_bytes()
        verify_digest(data, digest, where=f"layout blob {digest}")
        return data

    def put_manifest(self, ref: Reference, data: bytes, media_type: str) -> str:
        if ref.digest is not None:
            raise RefError(f"cannot store a manifest under digest reference {ref}")
        digest = self.put_blob(ref.name, data)
        entry = Descriptor(
            media_type=media_type,
            digest=digest,
            size=len(data),
            annotations={
                REF_NAME_ANNOTATION: ref.tag or DEFAULT_TAG,
                ET_NAME_ANNOTATION: ref.name,
            },
        )
        index = self._load_index() if self.layout_path.is_file() else _empty_index()
        entries = [
            e
            for e in _validated_entries(index, where=str(self.root))
            if not _same_label(e, entry)
        ]
        entries.append(entry)
        # deterministic index order -> stable diffs for a git-tracked layout
        entries.sort(key=lambda e: (
            e.annotations.get(ET_NAME_ANNOTATION, ""),
            e.annotations.get(REF_NAME_ANNOTATION, ""),
            e.digest,
        ))
        self._write_index(entries)
        return digest

    def get_manifest(self, ref: Reference) -> tuple[bytes, str]:
        index = self._load_index()
        entries = _validated_entries(index, where=str(self.root))
        if ref.digest is not None:
            for entry in entries:
                if entry.digest == ref.digest:
                    return self.get_blob(ref.name, entry.digest), entry.media_type
            if not self.has_blob(ref.digest):
                raise NotFoundError(f"{ref}: no manifest with this digest in {self.root}")
            data = self.get_blob(ref.name, ref.digest)
            return data, _sniff_media_type(data)
        tag = ref.tag or DEFAULT_TAG
        for entry in entries:
            if entry.annotations.get(REF_NAME_ANNOTATION) != tag:
                continue
            owner = entry.annotations.get(ET_NAME_ANNOTATION)
            # A layout written by another tool may only carry the ref-name
            # annotation; accept it for any repository name in that case.
            if owner is None or owner == ref.name:
                return self.get_blob(ref.name, entry.digest), entry.media_type
        raise NotFoundError(f"{ref}: not found in {self.root}")

    # -- layout plumbing --------------------------------------------------- #
    def _load_index(self) -> dict[str, Any]:
        if not self.layout_path.is_file():
            raise LayoutError(
                f"{self.root}: missing {OCI_IMAGE_LAYOUT_FILENAME} (not an OCI layout)"
            )
        try:
            layout_doc = json.loads(self.layout_path.read_text("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            raise LayoutError(f"{self.layout_path}: not valid JSON: {e}") from e
        if not isinstance(layout_doc, dict):
            raise LayoutError(f"{self.layout_path}: expected a JSON object")
        version = layout_doc.get("imageLayoutVersion")
        if version != OCI_LAYOUT_VERSION:
            raise LayoutError(
                f"{self.layout_path}: unsupported imageLayoutVersion {version!r} "
                f"(expected {OCI_LAYOUT_VERSION!r})"
            )
        if not self.index_path.is_file():
            raise LayoutError(f"{self.root}: missing {OCI_INDEX_FILENAME}")
        try:
            index = json.loads(self.index_path.read_text("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            raise LayoutError(f"{self.index_path}: not valid JSON: {e}") from e
        if not isinstance(index, dict):
            raise LayoutError(f"{self.index_path}: expected a JSON object")
        if index.get("schemaVersion") != 2:
            raise LayoutError(f"{self.index_path}: schemaVersion must be 2")
        if not isinstance(index.get("manifests"), list):
            raise LayoutError(f"{self.index_path}: 'manifests' must be an array")
        return {str(k): v for k, v in index.items()}

    def _write_index(self, entries: list[Descriptor]) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        if not self.layout_path.is_file():
            self._atomic_write(
                self.layout_path,
                _canonical_json({"imageLayoutVersion": OCI_LAYOUT_VERSION}),
            )
        doc: dict[str, Any] = {
            "schemaVersion": 2,
            "mediaType": OCI_INDEX_MEDIA_TYPE,
            "manifests": [e.to_dict() for e in entries],
        }
        self._atomic_write(self.index_path, _canonical_json(doc))

    @staticmethod
    def _atomic_write(path: Path, data: bytes) -> None:
        tmp = path.with_name(path.name + ".tmp")
        tmp.write_bytes(data)
        os.replace(tmp, path)


def _empty_index() -> dict[str, Any]:
    return {"schemaVersion": 2, "mediaType": OCI_INDEX_MEDIA_TYPE, "manifests": []}


def _validated_entries(index: Mapping[str, Any], *, where: str) -> list[Descriptor]:
    raw = index.get("manifests")
    if not isinstance(raw, list):
        raise LayoutError(f"{where}: index 'manifests' must be an array")
    return [
        Descriptor.from_dict(item, where=f"{where} index.manifests[{i}]")
        for i, item in enumerate(raw)
    ]


def _same_label(entry: Descriptor, want: Descriptor) -> bool:
    return (
        entry.annotations.get(REF_NAME_ANNOTATION)
        == want.annotations.get(REF_NAME_ANNOTATION)
        and entry.annotations.get(ET_NAME_ANNOTATION)
        == want.annotations.get(ET_NAME_ANNOTATION)
    )


def _sniff_media_type(data: bytes) -> str:
    """Best-effort media type from a JSON manifest document (layout fallback)."""
    try:
        doc = json.loads(data)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return ""
    if isinstance(doc, dict):
        media_type = doc.get("mediaType")
        if isinstance(media_type, str):
            return media_type
    return ""


class RegistryClient:
    """Minimal OCI distribution-spec v2 client (HTTP, no token negotiation).

    Endpoints used::

        HEAD /v2/<name>/blobs/<digest>          blob existence
        POST /v2/<name>/blobs/uploads/?digest=  monolithic blob upload
        GET  /v2/<name>/blobs/<digest>          blob download
        PUT  /v2/<name>/manifests/<tag>         manifest upload (tagged)
        GET  /v2/<name>/manifests/<tag|digest>  manifest download

    Auth: pass a ready ``Authorization`` header (e.g. ``Bearer <token>`` or a
    ``Basic ...`` value) — the OAuth2/token dance of the distribution spec is
    deliberately out of scope (see the E3-REP1 report notes).
    """

    def __init__(
        self,
        base_url: str,
        *,
        authorization: str | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.authorization = authorization
        self.timeout = timeout

    # -- low level --------------------------------------------------------- #
    def _repo_url(self, name: str, suffix: str) -> str:
        return f"{self.base_url}/v2/{urllib.parse.quote(name, safe='/')}/{suffix}"

    def _request(
        self,
        method: str,
        url: str,
        *,
        data: bytes | None = None,
        headers: Mapping[str, str] | None = None,
        ok: tuple[int, ...] = (200,),
    ) -> tuple[int, bytes, dict[str, str]]:
        request = urllib.request.Request(url, data=data, method=method)
        for key, value in (headers or {}).items():
            request.add_header(key, value)
        if self.authorization is not None:
            request.add_header("Authorization", self.authorization)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                body = response.read()
                status = int(response.status)
                resp_headers = {
                    key.lower(): value for key, value in response.headers.items()
                }
        except urllib.error.HTTPError as e:
            detail = e.read()[:200]
            raise RegistryError(
                f"{method} {url}: HTTP {e.code} {detail!r}", status=e.code
            ) from e
        except OSError as e:  # URLError is an OSError subclass
            raise TransportError(f"{method} {url}: {e}") from e
        if status not in ok:
            raise RegistryError(f"{method} {url}: unexpected HTTP {status}", status=status)
        return status, body, resp_headers

    def _head_ok(self, url: str) -> bool:
        try:
            self._request("HEAD", url, ok=(200,))
        except RegistryError as e:
            if e.status == 404:
                return False
            raise
        return True

    # -- Store ------------------------------------------------------------- #
    def put_blob(self, name: str, data: bytes) -> str:
        digest = sha256_digest(data)
        if self._head_ok(self._repo_url(name, f"blobs/{digest}")):
            return digest  # already present (registry-side dedup)
        self._request(
            "POST",
            self._repo_url(name, f"blobs/uploads/?digest={digest}"),
            data=data,
            headers={
                "Content-Type": "application/octet-stream",
                "Content-Length": str(len(data)),
            },
            ok=(201, 202),
        )
        return digest

    def get_blob(self, name: str, digest: str) -> bytes:
        try:
            _, body, _ = self._request("GET", self._repo_url(name, f"blobs/{digest}"))
        except RegistryError as e:
            if e.status == 404:
                raise NotFoundError(f"blob not found in registry: {digest}") from e
            raise
        verify_digest(body, digest, where=f"registry blob {digest}")
        return body

    def put_manifest(self, ref: Reference, data: bytes, media_type: str) -> str:
        if ref.digest is not None:
            raise RefError(f"cannot push a manifest under digest reference {ref}")
        tag = ref.tag or DEFAULT_TAG
        self._request(
            "PUT",
            self._repo_url(ref.name, f"manifests/{tag}"),
            data=data,
            headers={"Content-Type": media_type, "Content-Length": str(len(data))},
            ok=(200, 201, 202),
        )
        return sha256_digest(data)

    def get_manifest(self, ref: Reference) -> tuple[bytes, str]:
        target = ref.digest if ref.digest is not None else (ref.tag or DEFAULT_TAG)
        accept = f"{OCI_MANIFEST_MEDIA_TYPE}, {OCI_INDEX_MEDIA_TYPE}"
        try:
            _, body, headers = self._request(
                "GET",
                self._repo_url(ref.name, f"manifests/{target}"),
                headers={"Accept": accept},
            )
        except RegistryError as e:
            if e.status == 404:
                raise NotFoundError(f"{ref}: not found in registry") from e
            raise
        if ref.digest is not None:
            verify_digest(body, ref.digest, where=f"registry manifest {ref}")
        media_type = headers.get("content-type", "").split(";", 1)[0].strip()
        return body, media_type or _sniff_media_type(body)


# --------------------------------------------------------------------------- #
# OCI mapping: ethimg manifest <-> config document
# --------------------------------------------------------------------------- #
def _image_annotations(man: ethimg.Manifest) -> dict[str, str]:
    annotations = {
        "org.opencontainers.image.title": man.name,
        "org.opencontainers.image.version": man.version,
        ET_TARGET_ANNOTATION: man.target,
        ET_MANIFEST_DIGEST_ANNOTATION: man.manifest_digest,
    }
    if man.created:
        annotations["org.opencontainers.image.created"] = man.created
    if man.author:
        annotations["org.opencontainers.image.authors"] = man.author
    return annotations


def _config_document(man: ethimg.Manifest, layer: Descriptor) -> bytes:
    """Build the config blob: the OCI-side view of the ethimg manifest (S09 sec 2.1).

    The Ed25519 signature VALUE is intentionally NOT copied here — the
    authoritative signature travels inside the ``.eth`` (S09 sec 2.2) and is
    re-verified from the artifact itself on pull; the config only records the
    key fingerprint so an index/registry listing can show who signed an image.
    """
    signature: dict[str, str] | None = None
    if man.signature is not None:
        signature = {
            "algo": str(man.signature.get("algo", "")),
            "key_fingerprint": str(man.signature.get("key_fingerprint", "")),
        }
    doc: dict[str, Any] = {
        "schema": ET_CONFIG_SCHEMA,
        "image": {
            "schema": ethimg.SCHEMA,
            "name": man.name,
            "version": man.version,
            "target": man.target,
            "author": man.author,
            "created": man.created,
        },
        "manifest_digest": man.manifest_digest,
        "digest_algo": ethimg.DIGEST_ALGO,
        "signature": signature,
        "artifact": {
            "media_type": ET_ARTIFACT_MEDIA_TYPE,
            "digest": layer.digest,
            "size": layer.size,
        },
        "members": dict(man.members),
    }
    return _canonical_json(doc)


def _manifest_document(
    config: Descriptor, layer: Descriptor, annotations: Mapping[str, str]
) -> bytes:
    """Build the OCI artifact manifest (single layer = the ``.eth`` tar)."""
    doc: dict[str, Any] = {
        "schemaVersion": 2,
        "mediaType": OCI_MANIFEST_MEDIA_TYPE,
        "artifactType": ET_ARTIFACT_MEDIA_TYPE,
        "config": config.to_dict(),
        "layers": [layer.to_dict()],
        "annotations": dict(annotations),
    }
    return _canonical_json(doc)


@dataclass(frozen=True)
class PushResult:
    ref: str
    descriptor: Descriptor
    config: Descriptor
    layer: Descriptor
    manifest_digest: str
    signed: bool


@dataclass(frozen=True)
class PullResult:
    ref: str
    path: Path
    descriptor: Descriptor
    manifest_digest: str
    signed: bool
    name: str
    version: str
    target: str


def _as_store(store: Store | Path) -> Store:
    """Accept either a :class:`Store` or a layout directory path."""
    if isinstance(store, Path):
        return LayoutStore(store)
    return store


# --------------------------------------------------------------------------- #
# push / pull / inspect
# --------------------------------------------------------------------------- #
def push(
    store: Store | Path,
    ref: str | Reference,
    eth_path: Path,
    *,
    annotations: Mapping[str, str] | None = None,
    trusted_pubkeys: list[bytes] | None = None,
) -> PushResult:
    """Publish ``eth_path`` as an OCI artifact under ``ref``.

    ``store`` is a :class:`LayoutStore`, a :class:`RegistryClient` or a layout
    directory path. ``ref`` must be tagged (``name:version``); a missing tag
    means ``latest``.

    The image's own integrity (member digests + ``manifest_digest``) is checked
    BEFORE uploading, so a corrupt ``.eth`` never reaches a store; the signature
    POLICY is not applied here (an unsigned dev image may be pushed) — it is
    enforced by :func:`pull` / :func:`ethimg.verify` at deploy time (S09 sec 2.2).
    A SIGNED image needs ``trusted_pubkeys`` at push time too: ``ethimg.verify``
    cannot check a signed image's integrity without a key to verify against.
    """
    st = _as_store(store)
    reference = parse_ref(ref) if isinstance(ref, str) else ref
    if reference.digest is not None:
        raise RefError(f"push requires a tag reference, got {reference}")
    if reference.tag is None:
        reference = Reference(name=reference.name, tag=DEFAULT_TAG)
    eth_path = Path(eth_path)
    if not eth_path.is_file():
        raise OciError(f"no such .eth image: {eth_path}")

    # Integrity first (unsigned allowed): never publish a broken artifact. A
    # signed image can only be integrity-checked against a key, so require one.
    probe = ethimg.read_manifest(eth_path)
    if probe.signature is not None and trusted_pubkeys is None:
        raise OciError(
            f"{eth_path}: signed image — pass trusted_pubkeys to verify it before "
            "publishing (ethimg.verify needs a key for a signed image)"
        )
    man = ethimg.verify(eth_path, trusted_pubkeys=trusted_pubkeys, allow_unsigned=True)
    data = eth_path.read_bytes()
    layer = Descriptor(
        media_type=ET_ARTIFACT_MEDIA_TYPE,
        digest=sha256_digest(data),
        size=len(data),
    )
    config_bytes = _config_document(man, layer)
    config = Descriptor(
        media_type=ET_CONFIG_MEDIA_TYPE,
        digest=sha256_digest(config_bytes),
        size=len(config_bytes),
    )

    st.put_blob(reference.name, config_bytes)
    st.put_blob(reference.name, data)

    manifest_annotations = _image_annotations(man)
    manifest_annotations.update(annotations or {})
    manifest_bytes = _manifest_document(config, layer, manifest_annotations)
    digest = st.put_manifest(reference, manifest_bytes, OCI_MANIFEST_MEDIA_TYPE)
    descriptor = Descriptor(
        media_type=OCI_MANIFEST_MEDIA_TYPE,
        digest=digest,
        size=len(manifest_bytes),
        annotations={
            REF_NAME_ANNOTATION: reference.tag or DEFAULT_TAG,
            ET_NAME_ANNOTATION: reference.name,
        },
    )
    return PushResult(
        ref=str(reference),
        descriptor=descriptor,
        config=config,
        layer=layer,
        manifest_digest=man.manifest_digest,
        signed=man.signature is not None,
    )


@dataclass(frozen=True)
class _Resolved:
    reference: Reference
    manifest_bytes: bytes
    descriptor: Descriptor
    config: Descriptor
    layer: Descriptor
    annotations: dict[str, str]
    members: dict[str, str]
    manifest_digest: str
    name: str
    version: str
    target: str
    signed: bool
    signature_fingerprint: str


def _resolve(st: Store, reference: Reference) -> _Resolved:
    """Resolve ``ref`` to a fully validated descriptor graph (no layer download)."""
    where = str(reference)
    manifest_bytes, media_type = st.get_manifest(reference)
    if reference.digest is not None:
        verify_digest(manifest_bytes, reference.digest, where=f"manifest {where}")
    doc = _parse_json_object(manifest_bytes, where=f"manifest {where}")
    if doc.get("schemaVersion") != 2:
        raise LayoutError(f"manifest {where}: schemaVersion must be 2")
    doc_type = doc.get("mediaType")
    for candidate in (media_type, doc_type if isinstance(doc_type, str) else ""):
        if candidate and candidate != OCI_MANIFEST_MEDIA_TYPE:
            raise LayoutError(
                f"manifest {where}: media type {candidate!r} is not "
                f"{OCI_MANIFEST_MEDIA_TYPE!r} (not an OCI image manifest)"
            )
    artifact_type = doc.get("artifactType")
    if isinstance(artifact_type, str) and artifact_type != ET_ARTIFACT_MEDIA_TYPE:
        raise LayoutError(
            f"manifest {where}: artifactType {artifact_type!r} is not "
            f"{ET_ARTIFACT_MEDIA_TYPE!r}"
        )
    annotations: dict[str, str] = {}
    raw_annotations = doc.get("annotations", {})
    if not isinstance(raw_annotations, dict):
        raise LayoutError(f"manifest {where}.annotations: expected an object")
    for key, val in raw_annotations.items():
        if not isinstance(val, str):
            raise LayoutError(f"manifest {where}.annotations[{key!r}]: not a string")
        annotations[str(key)] = val
    config = Descriptor.from_dict(doc.get("config"), where=f"manifest {where}.config")
    if config.media_type != ET_CONFIG_MEDIA_TYPE:
        raise LayoutError(
            f"manifest {where}.config: media type {config.media_type!r} is not "
            f"{ET_CONFIG_MEDIA_TYPE!r}"
        )
    layers_raw = doc.get("layers")
    if not isinstance(layers_raw, list) or len(layers_raw) != 1:
        raise LayoutError(
            f"manifest {where}: expected exactly 1 layer (one .eth per image), "
            f"got {len(layers_raw) if isinstance(layers_raw, list) else 'non-array'}"
        )
    layer = Descriptor.from_dict(layers_raw[0], where=f"manifest {where}.layers[0]")
    if layer.media_type != ET_ARTIFACT_MEDIA_TYPE:
        raise LayoutError(
            f"manifest {where}.layers[0]: media type {layer.media_type!r} is not "
            f"{ET_ARTIFACT_MEDIA_TYPE!r}"
        )

    config_bytes = st.get_blob(reference.name, config.digest)
    verify_digest(
        config_bytes, config.digest, where=f"config {config.digest}", size=config.size
    )
    config_doc = _parse_json_object(config_bytes, where=f"config {config.digest}")
    if config_doc.get("schema") != ET_CONFIG_SCHEMA:
        raise LayoutError(
            f"config {config.digest}: schema {config_doc.get('schema')!r} is not "
            f"{ET_CONFIG_SCHEMA!r}"
        )
    image = _require_object(config_doc, "image", where=f"config {config.digest}")
    name = _require_str(image, "name", where=f"config {config.digest}.image")
    version = _require_str(image, "version", where=f"config {config.digest}.image")
    target = _require_str(image, "target", where=f"config {config.digest}.image")
    image_schema = _require_str(image, "schema", where=f"config {config.digest}.image")
    if not image_schema.startswith("ethereal.logic."):
        raise LayoutError(
            f"config {config.digest}.image.schema: unsupported {image_schema!r}"
        )
    manifest_digest = _require_str(
        config_doc, "manifest_digest", where=f"config {config.digest}"
    )
    artifact = _require_object(config_doc, "artifact", where=f"config {config.digest}")
    art_media_type = _require_str(
        artifact, "media_type", where=f"config {config.digest}.artifact"
    )
    art_digest = _require_str(
        artifact, "digest", where=f"config {config.digest}.artifact"
    )
    art_size = _require_int(artifact, "size", where=f"config {config.digest}.artifact")
    if (art_media_type, art_digest, art_size) != (
        layer.media_type,
        layer.digest,
        layer.size,
    ):
        raise MappingError(
            f"{where}: config describes artifact "
            f"({art_media_type}, {art_digest}, {art_size}) but the manifest layer is "
            f"({layer.media_type}, {layer.digest}, {layer.size})"
        )
    signature_raw = config_doc.get("signature")
    signed = signature_raw is not None
    fingerprint = ""
    if isinstance(signature_raw, dict):
        fingerprint = str(signature_raw.get("key_fingerprint", ""))
    members: dict[str, str] = {}
    raw_members = config_doc.get("members", {})
    if isinstance(raw_members, dict):
        for key, val in raw_members.items():
            if isinstance(val, str):
                members[str(key)] = val
    return _Resolved(
        reference=reference,
        manifest_bytes=manifest_bytes,
        descriptor=Descriptor(
            media_type=OCI_MANIFEST_MEDIA_TYPE,
            digest=sha256_digest(manifest_bytes),
            size=len(manifest_bytes),
        ),
        config=config,
        layer=layer,
        annotations=annotations,
        members=members,
        manifest_digest=manifest_digest,
        name=name,
        version=version,
        target=target,
        signed=signed,
        signature_fingerprint=fingerprint,
    )


def _check_config_matches(man: ethimg.Manifest, resolved: _Resolved) -> None:
    """Cross-check the pulled artifact's own manifest against the OCI config."""
    where = str(resolved.reference)
    if man.manifest_digest != resolved.manifest_digest:
        raise MappingError(
            f"{where}: artifact manifest_digest {man.manifest_digest} does not match "
            f"the OCI config {resolved.manifest_digest}"
        )
    actual = (man.name, man.version, man.target)
    expected = (resolved.name, resolved.version, resolved.target)
    if actual != expected:
        raise MappingError(
            f"{where}: artifact identity {actual} does not match the OCI config "
            f"{expected}"
        )
    if man.signature is None:
        if resolved.signed:
            raise MappingError(
                f"{where}: config advertises a signature but the artifact is unsigned"
            )
        return
    if not resolved.signed:
        raise MappingError(
            f"{where}: artifact is signed but the OCI config has no signature block"
        )
    fingerprint = str(man.signature.get("key_fingerprint", ""))
    if fingerprint != resolved.signature_fingerprint:
        raise MappingError(
            f"{where}: signature key fingerprint {fingerprint} does not match the OCI "
            f"config {resolved.signature_fingerprint}"
        )


def pull(
    store: Store | Path,
    ref: str | Reference,
    dest: Path,
    *,
    trusted_pubkeys: list[bytes] | None = None,
    allow_unsigned: bool = False,
) -> PullResult:
    """Fetch the OCI artifact at ``ref`` and write it as a verified ``.eth``.

    Every blob is digest-verified on read, the descriptor graph is cross-checked,
    and the resulting tar is then verified with :func:`ethimg.verify` under the
    caller's trust policy (``trusted_pubkeys`` / ``allow_unsigned``). ``dest``
    must be a file path; an existing directory means
    ``<dest>/<name>-<version>.eth``. Nothing is left at ``dest`` if any check
    fails (the write is staged in ``<dest>.part`` and renamed only after the
    artifact verifies).
    """
    st = _as_store(store)
    reference = parse_ref(ref) if isinstance(ref, str) else ref
    resolved = _resolve(st, reference)

    layer_bytes = st.get_blob(reference.name, resolved.layer.digest)
    verify_digest(
        layer_bytes,
        resolved.layer.digest,
        where=f"layer {resolved.layer.digest}",
        size=resolved.layer.size,
    )

    dest_path = Path(dest)
    if dest_path.is_dir():
        dest_path = dest_path / f"{resolved.name}-{resolved.version}.eth"
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    staged = dest_path.with_name(dest_path.name + ".part")
    staged.write_bytes(layer_bytes)
    try:
        man = ethimg.verify(
            staged, trusted_pubkeys=trusted_pubkeys, allow_unsigned=allow_unsigned
        )
        _check_config_matches(man, resolved)
    except Exception:
        staged.unlink(missing_ok=True)
        raise
    os.replace(staged, dest_path)
    return PullResult(
        ref=str(reference),
        path=dest_path,
        descriptor=resolved.descriptor,
        manifest_digest=man.manifest_digest,
        signed=man.signature is not None,
        name=man.name,
        version=man.version,
        target=man.target,
    )


def inspect(store: Store | Path, ref: str | Reference) -> dict[str, Any]:
    """Return the OCI-level facts for ``ref`` WITHOUT downloading the artifact."""
    st = _as_store(store)
    reference = parse_ref(ref) if isinstance(ref, str) else ref
    resolved = _resolve(st, reference)
    return {
        "ref": str(reference),
        "media_type": resolved.descriptor.media_type,
        "digest": resolved.descriptor.digest,
        "size": resolved.descriptor.size,
        "layer": resolved.layer.to_dict(),
        "config": resolved.config.to_dict(),
        "name": resolved.name,
        "version": resolved.version,
        "target": resolved.target,
        "manifest_digest": resolved.manifest_digest,
        "signed": resolved.signed,
        "key_fingerprint": resolved.signature_fingerprint,
        "annotations": dict(resolved.annotations),
        "members": dict(resolved.members),
    }


# --------------------------------------------------------------------------- #
# CLI (``python -m oci_registry <push|pull|inspect>``; also used by ethctl)
# --------------------------------------------------------------------------- #
def _parse_annotations(pairs: list[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for pair in pairs:
        key, sep, value = pair.partition("=")
        if not sep or not key:
            raise OciError(f"--annotation expects KEY=VALUE, got {pair!r}")
        out[key] = value
    return out


def store_for(
    *,
    layout: str | Path | None = None,
    registry: str | None = None,
    authorization: str | None = None,
) -> Store:
    """Build a transport from CLI-style flags (``--registry`` wins over ``--layout``).

    Shared by this module's CLI and by ``ethctl push`` / ``ethctl pull``
    (S08: ``ethctl pull/push`` -> OCI registry) so the two front-ends cannot
    drift apart.
    """
    if registry:
        return RegistryClient(registry, authorization=authorization)
    if layout:
        return LayoutStore(Path(layout))
    raise OciError(
        "select a transport: --layout DIR (local OCI layout) or --registry URL"
    )


def _select_store(args: argparse.Namespace) -> Store:
    return store_for(
        layout=args.layout, registry=args.registry, authorization=args.authorization
    )


def _add_transport_flags(sp: argparse.ArgumentParser) -> None:
    sp.add_argument("--layout", help="local OCI layout directory (default transport)")
    sp.add_argument("--registry", help="OCI registry base URL (http(s)://host[:port])")
    sp.add_argument("--authorization", help="raw Authorization header for --registry")


def _cli(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="oci_registry",
        description="Ethereal .eth <-> OCI artifact transport (S09 sec 2.3, E3-REP1)",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    sp_push = sub.add_parser("push", help="upload a .eth as an OCI artifact")
    sp_push.add_argument("eth", help=".eth logic image")
    sp_push.add_argument("ref", help="<repository>:<tag> (default tag 'latest')")
    sp_push.add_argument(
        "--annotation", action="append", default=[], help="extra manifest annotation K=V"
    )
    sp_push.add_argument(
        "--pubkey", action="append", default=[], help="trusted PEM pubkey (signed image)"
    )
    _add_transport_flags(sp_push)

    sp_pull = sub.add_parser("pull", help="download + verify an OCI artifact as .eth")
    sp_pull.add_argument("ref", help="<repository>:<tag> or <repository>@<digest>")
    sp_pull.add_argument("dest", help="output .eth path (or a directory)")
    sp_pull.add_argument("--pubkey", action="append", default=[], help="trusted PEM pubkey")
    sp_pull.add_argument("--allow-unsigned", action="store_true")
    _add_transport_flags(sp_pull)

    sp_inspect = sub.add_parser("inspect", help="show the OCI descriptor graph")
    sp_inspect.add_argument("ref")
    _add_transport_flags(sp_inspect)

    args = p.parse_args(argv)
    try:
        if args.cmd == "push":
            result = push(
                _select_store(args),
                args.ref,
                Path(args.eth),
                annotations=_parse_annotations(args.annotation),
                trusted_pubkeys=[Path(k).read_bytes() for k in args.pubkey] or None,
            )
            print(
                f"pushed {result.ref} (manifest {result.descriptor.digest}, "
                f"artifact {result.layer.digest}, signed={result.signed})"
            )
        elif args.cmd == "pull":
            keys = [Path(k).read_bytes() for k in args.pubkey] or None
            pulled = pull(
                _select_store(args),
                args.ref,
                Path(args.dest),
                trusted_pubkeys=keys,
                allow_unsigned=args.allow_unsigned,
            )
            print(
                f"pulled {pulled.ref} -> {pulled.path} "
                f"({pulled.name} v{pulled.version}, target {pulled.target})"
            )
        elif args.cmd == "inspect":
            for key, value in inspect(_select_store(args), args.ref).items():
                print(f"{key}: {value}")
        return 0
    except (
        OciError,
        ethimg.EthimgError,
        OSError,
    ) as e:
        print(f"oci_registry: error: {e}", file=sys.stderr)
        return 1


def main(argv: list[str] | None = None) -> int:
    """Console entry point (``ethctl push`` / ``ethctl pull`` delegate here)."""
    return _cli(argv)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
