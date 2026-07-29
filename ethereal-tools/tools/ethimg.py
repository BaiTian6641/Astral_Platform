# SPDX-License-Identifier: MIT
"""ethimg — Ethereal logic-image tool (task E1-RUN1, subsystem S09).

Packs / unpacks / verifies ``.eth`` logic images (tar archives of manifest +
interface/capabilities/resources/health YAML + ``targets/<arch>.frames`` config
frames), with SHA-256 per-member integrity and OPTIONAL Ed25519 manifest
signing (PyCA ``cryptography``). Mirrors S09 §2.1.

v0.1 format (single target, cross-vendor overlay frames)::

    aes128.eth (tar)
      manifest.yaml          # schema/name/version/digests/optional Ed25519 sig
      interface.yaml         # EBI ABI / IO / interrupt / clock needs
      capabilities.yaml      # IO/service permission declarations
      resources.yaml         # eLUT/MEM-T/DSP-T counts (region-match)
      health.yaml            # watchdog period / restartPolicy
      targets/efab-1.0.frames     # raw config frames (bitgen output)
      targets/efab-1.0.meta.json  # frame stats / occupancy

Integrity model:
  * every member -> SHA-256 (recorded in ``manifest.members``);
  * ``manifest_digest`` = SHA-256 over the manifest serialization WITH the
    ``signature`` field removed (so signing is stable);
  * OPTIONAL ``signature`` = Ed25519 over ``manifest_digest`` (hex, UTF-8).

The signature is OPTIONAL for v0.1 to keep the local sim loop dependency-light
for unsigned dev images, but ``verify`` rejects unsigned images UNLESS
``allow_unsigned=True`` (the host/mFSM path decides; S05 §4.2 has the host
verify, so the host tool chooses). M-S09-1 acceptance: tamper any byte ->
``verify`` raises.

Plan-Ref: ethereal-plan/subsystems/S09-镜像格式与仓库.md §2.1/§2.2.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import os
import sys
import tarfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

SCHEMA = "ethereal.logic.v0.1"
DIGEST_ALGO = "sha256"
MANIFEST_NAME = "manifest.yaml"
TARGETS_DIR = "targets"

# Canonical non-manifest member names (all OPTIONAL except frames).
OPTIONAL_MEMBERS = (
    "interface.yaml",
    "capabilities.yaml",
    "resources.yaml",
    "health.yaml",
)


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class EthimgError(Exception):
    """Base error for ethimg operations."""


class IntegrityError(EthimgError):
    """A member digest mismatch or manifest_digest mismatch."""


class SignatureError(EthimgError):
    """Signature missing/invalid/untrusted."""


# --------------------------------------------------------------------------- #
# Ed25519 (optional; graceful if cryptography absent)
# --------------------------------------------------------------------------- #
_ED25519: Any | None = None
try:  # pragma: no cover - import guard
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import (
        Ed25519PrivateKey,
    )
    _ED25519 = True
except ImportError:  # pragma: no cover
    _ED25519 = None


def ed25519_available() -> bool:
    return _ED25519 is not None


def keygen(priv_path: Path, pub_path: Path) -> tuple[bytes, bytes]:
    """Generate an Ed25519 keypair; write PEM files; return (priv_pem, pub_pem)."""
    if not ed25519_available():
        raise EthimgError(
            "Ed25519 needs PyCA 'cryptography'. Install: pip install cryptography"
        )
    priv = Ed25519PrivateKey.generate()
    pub = priv.public_key()
    priv_pem = priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    pub_pem = pub.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    priv_path.write_bytes(priv_pem)
    pub_path.write_bytes(pub_pem)
    # restrict private key perms where possible (POSIX)
    try:
        os.chmod(priv_path, 0o600)
    except OSError:
        pass
    return priv_pem, pub_pem


def _load_priv(priv_pem: bytes) -> Any:
    return serialization.load_pem_private_key(priv_pem, password=None)


def _load_pub(pub_pem: bytes) -> Any:
    return serialization.load_pem_public_key(pub_pem)


def pubkey_fingerprint(pub_pem: bytes) -> str:
    """SHA-256 of the DER subject public key info -> hex (trust-store key)."""
    pub = _load_pub(pub_pem)
    der = pub.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return hashlib.sha256(der).hexdigest()


def _sign_digest(priv_pem: bytes, digest_hex: str) -> str:
    priv = _load_priv(priv_pem)
    sig = priv.sign(digest_hex.encode("utf-8"))
    return sig.hex()


def _verify_sig(pub_pem: bytes, digest_hex: str, sig_hex: str) -> bool:
    pub = _load_pub(pub_pem)
    try:
        pub.verify(bytes.fromhex(sig_hex), digest_hex.encode("utf-8"))
        return True
    except Exception:  # noqa: BLE001 - sig verify may raise many error types
        return False


# --------------------------------------------------------------------------- #
# Manifest
# --------------------------------------------------------------------------- #
@dataclass
class Manifest:
    name: str
    version: str
    target: str
    author: str = ""
    created: str = ""
    members: dict[str, str] = field(default_factory=dict)
    manifest_digest: str = ""
    signature: dict[str, str] | None = None

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "schema": SCHEMA,
            "name": self.name,
            "version": self.version,
            "target": self.target,
            "author": self.author,
            "created": self.created,
            "digest_algo": DIGEST_ALGO,
            "members": dict(self.members),
        }
        # manifest_digest computed over everything EXCEPT signature
        d["manifest_digest"] = self.manifest_digest
        if self.signature is not None:
            d["signature"] = dict(self.signature)
        return d

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> Manifest:
        schema = d.get("schema", "")
        if not schema.startswith("ethereal.logic."):
            raise EthimgError(f"unsupported manifest schema: {schema!r}")
        return cls(
            name=str(d["name"]),
            version=str(d["version"]),
            target=str(d["target"]),
            author=str(d.get("author", "")),
            created=str(d.get("created", "")),
            members={str(k): str(v) for k, v in d.get("members", {}).items()},
            manifest_digest=str(d.get("manifest_digest", "")),
            signature=d.get("signature"),  # type: ignore[arg-type]
        )


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _manifest_digest(manifest_dict: dict[str, Any]) -> str:
    """SHA-256 over the canonical YAML serialization.

    Strips BOTH ``signature`` and ``manifest_digest`` so the digest never
    includes itself (self-reference) nor the signature over itself.
    """
    d = {
        k: v
        for k, v in manifest_dict.items()
        if k not in ("signature", "manifest_digest")
    }
    blob = yaml.safe_dump(d, sort_keys=True, default_flow_style=False).encode("utf-8")
    return _sha256(blob)


# --------------------------------------------------------------------------- #
# Pack / unpack / verify / info
# --------------------------------------------------------------------------- #
@dataclass
class PackResult:
    path: Path
    manifest_digest: str
    signed: bool


def pack(
    src_dir: Path,
    out_path: Path,
    *,
    name: str | None = None,
    version: str = "0.1.0",
    author: str = "",
    target: str | None = None,
    privkey_pem: bytes | None = None,
) -> PackResult:
    """Assemble ``src_dir`` into a signed ``.eth`` tar at ``out_path``.

    ``src_dir`` must contain at least one ``targets/<arch>.frames`` file; the
    optional YAML members are auto-filled with minimal defaults if absent.
    """
    src_dir = Path(src_dir)
    out_path = Path(out_path)
    if not src_dir.is_dir():
        raise EthimgError(f"source dir not found: {src_dir}")

    # discover target frames
    targets_dir = src_dir / TARGETS_DIR
    if not targets_dir.is_dir():
        raise EthimgError(f"missing {TARGETS_DIR}/ dir (no frames to ship)")
    frames_files = sorted(targets_dir.glob("*.frames"))
    if not frames_files:
        raise EthimgError(f"no *.frames under {TARGETS_DIR}/")
    if target is None:
        target = frames_files[0].stem
    # also pick up *.meta.json for the same target
    members: dict[str, bytes] = {}
    for ff in frames_files:
        members[f"{TARGETS_DIR}/{ff.name}"] = ff.read_bytes()
    for mj in sorted(targets_dir.glob("*.meta.json")):
        members[f"{TARGETS_DIR}/{mj.name}"] = mj.read_bytes()

    # optional YAML members (use existing or minimal default)
    defaults = _default_optional_yaml(name or src_dir.name, target)
    for m in OPTIONAL_MEMBERS:
        p = src_dir / m
        if p.is_file():
            members[m] = p.read_bytes()
        else:
            members[m] = defaults[m].encode("utf-8")

    # build manifest
    name = name or src_dir.name
    man = Manifest(
        name=name,
        version=version,
        target=target,
        author=author,
        created=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        members={k: _sha256(v) for k, v in members.items()},
    )
    md = man.to_dict()
    man.manifest_digest = _manifest_digest(md)

    signed = False
    if privkey_pem is not None:
        if not ed25519_available():
            raise EthimgError(" signing requested but 'cryptography' not installed")
        pub_pem = _load_priv(privkey_pem).public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        man.signature = {
            "algo": "ed25519",
            "key_fingerprint": pubkey_fingerprint(pub_pem),
            "value": _sign_digest(privkey_pem, man.manifest_digest),
        }
        signed = True

    # write tar (deterministic order: manifest first, then sorted members)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(out_path, "w") as tf:
        man_bytes = yaml.safe_dump(
            man.to_dict(), sort_keys=True, default_flow_style=False
        ).encode("utf-8")
        _tar_add(tf, MANIFEST_NAME, man_bytes)
        for k in sorted(members):
            _tar_add(tf, k, members[k])

    return PackResult(path=out_path, manifest_digest=man.manifest_digest, signed=signed)


def _tar_add(tf: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name=name)
    info.size = len(data)
    info.mtime = 0  # deterministic
    tf.addfile(info, io.BytesIO(data))


def _default_optional_yaml(name: str, target: str) -> dict[str, str]:
    return {
        "interface.yaml": (
            yaml.safe_dump(
                {"ebi_abi": "v0", "io_needs": [], "interrupts": [], "clock_mhz": 100},
                sort_keys=True,
            )
        ),
        "capabilities.yaml": (
            yaml.safe_dump({"io": [], "services": []}, sort_keys=True)
        ),
        "resources.yaml": (
            yaml.safe_dump(
                {"elut": 0, "mem_t": 0, "dsp_t": 0, "target": target}, sort_keys=True
            )
        ),
        "health.yaml": (
            yaml.safe_dump(
                {"watchdog_ms": 0, "restart_policy": "never"}, sort_keys=True
            )
        ),
    }


def read_manifest(eth_path: Path) -> Manifest:
    """Read & parse the manifest from a ``.eth`` tar (no verification)."""
    with tarfile.open(Path(eth_path), "r") as tf:
        try:
            f = tf.extractfile(MANIFEST_NAME)
        except KeyError:
            raise EthimgError(f"{eth_path}: missing {MANIFEST_NAME}")
        if f is None:
            raise EthimgError(f"{eth_path}: empty {MANIFEST_NAME}")
        data = f.read()
    d = yaml.safe_load(data) or {}
    return Manifest.from_dict(d)


def _read_members(eth_path: Path) -> tuple[Manifest, dict[str, bytes]]:
    with tarfile.open(Path(eth_path), "r") as tf:
        names = tf.getnames()
        if MANIFEST_NAME not in names:
            raise EthimgError(f"{eth_path}: missing {MANIFEST_NAME}")
        man = Manifest.from_dict(
            yaml.safe_load(tf.extractfile(MANIFEST_NAME).read()) or {}  # type: ignore[union-attr]
        )
        members: dict[str, bytes] = {}
        for n in names:
            if n == MANIFEST_NAME:
                continue
            ef = tf.extractfile(n)
            if ef is not None:
                members[n] = ef.read()
    return man, members


def verify(
    eth_path: Path,
    *,
    trusted_pubkeys: list[bytes] | None = None,
    allow_unsigned: bool = False,
) -> Manifest:
    """Verify integrity (per-member SHA-256 + manifest_digest) and signature.

    * ``trusted_pubkeys``: if provided AND the image is signed, the signature
      must verify against ONE of them (else ``SignatureError``).
    * ``allow_unsigned``: if True, unsigned images pass (integrity still
      checked). Else unsigned images raise ``SignatureError``.

    Returns the verified ``Manifest``. Raises ``IntegrityError``/``SignatureError``.
    """
    man, members = _read_members(eth_path)

    # 1. every declared member present + digest matches
    for mname, dig in man.members.items():
        if mname not in members:
            raise IntegrityError(f"missing member: {mname}")
        if _sha256(members[mname]) != dig:
            raise IntegrityError(f"member digest mismatch: {mname}")

    # 2. no undeclared members (anti-smuggle)
    for mname in members:
        if mname not in man.members:
            raise IntegrityError(f"undeclared member (smuggle?): {mname}")

    # 3. manifest_digest matches
    md = _manifest_digest(man.to_dict())
    if md != man.manifest_digest:
        raise IntegrityError(
            f"manifest_digest mismatch: expected {man.manifest_digest}, got {md}"
        )

    # 4. signature
    if man.signature is None:
        if not allow_unsigned:
            raise SignatureError(
                f"{eth_path}: unsigned image (pass allow_unsigned=True for dev)"
            )
        return man
    if man.signature.get("algo") != "ed25519":
        raise SignatureError(f"unsupported sig algo: {man.signature.get('algo')}")
    sig_val = man.signature.get("value", "")
    if trusted_pubkeys is None:
        # signature present + structurally valid, but no trusted keys to check
        # against -> caller must supply keys; treat as "signature unverified".
        raise SignatureError(
            f"{eth_path}: signed but no trusted_pubkeys supplied to verify against"
        )
    for pub_pem in trusted_pubkeys:
        if _verify_sig(pub_pem, man.manifest_digest, sig_val):
            return man
    raise SignatureError(f"{eth_path}: signature did not verify against any trusted key")


def unpack(eth_path: Path, dest_dir: Path) -> Path:
    """Extract all members of a ``.eth`` tar into ``dest_dir``. Returns dest_dir."""
    dest_dir = Path(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(Path(eth_path), "r") as tf:
        tf.extractall(dest_dir)
    return dest_dir


def info(eth_path: Path) -> dict[str, Any]:
    """Return a human-readable info dict (manifest + structure summary)."""
    man, members = _read_members(eth_path)
    frames = [n for n in members if n.endswith(".frames")]
    return {
        "path": str(eth_path),
        "name": man.name,
        "version": man.version,
        "target": man.target,
        "author": man.author,
        "created": man.created,
        "manifest_digest": man.manifest_digest,
        "signed": man.signature is not None,
        "key_fingerprint": (man.signature or {}).get("key_fingerprint", ""),
        "members": sorted(members),
        "frames": frames,
    }


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _cli(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ethimg", description="Ethereal logic-image tool")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("keygen", help="generate an Ed25519 keypair")
    sp.add_argument("--priv", required=True)
    sp.add_argument("--pub", required=True)

    sp = sub.add_parser("pack", help="pack a dir into a .eth")
    sp.add_argument("src")
    sp.add_argument("out")
    sp.add_argument("--name")
    sp.add_argument("--version", default="0.1.0")
    sp.add_argument("--author", default="")
    sp.add_argument("--target")
    sp.add_argument("--privkey", help="PEM private key for signing")

    sp = sub.add_parser("unpack", help="extract a .eth")
    sp.add_argument("eth")
    sp.add_argument("dest")

    sp = sub.add_parser("verify", help="verify a .eth integrity + signature")
    sp.add_argument("eth")
    sp.add_argument("--pubkey", action="append", default=[], help="trusted PEM pubkey")
    sp.add_argument("--allow-unsigned", action="store_true")

    sub.add_parser("info", help="show .eth manifest").add_argument("eth")

    args = p.parse_args(argv)

    try:
        if args.cmd == "keygen":
            _, pub = keygen(Path(args.priv), Path(args.pub))
            print(f"wrote {args.priv} + {args.pub} (fingerprint {pubkey_fingerprint(pub)})")
        elif args.cmd == "pack":
            priv_pem: bytes | None = None
            if args.privkey:
                priv_pem = Path(args.privkey).read_bytes()
            r = pack(
                Path(args.src), Path(args.out),
                name=args.name, version=args.version, author=args.author,
                target=args.target, privkey_pem=priv_pem,
            )
            print(f"packed {r.path} (digest {r.manifest_digest[:16]}, signed={r.signed})")
        elif args.cmd == "unpack":
            d = unpack(Path(args.eth), Path(args.dest))
            print(f"extracted to {d}")
        elif args.cmd == "verify":
            keys = [Path(k).read_bytes() for k in args.pubkey] or None
            man = verify(
                Path(args.eth), trusted_pubkeys=keys,
                allow_unsigned=args.allow_unsigned,
            )
            print(f"OK {args.eth}: {man.name} v{man.version} (target {man.target})")
        elif args.cmd == "info":
            i = info(Path(args.eth))
            for k, v in i.items():
                print(f"{k}: {v}")
        return 0
    except EthimgError as e:
        print(f"ethimg: error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
