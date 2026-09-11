# SPDX-License-Identifier: MIT
"""capcheck — capabilities.yaml parser/validator + host-side capability gate.

Implements the frozen v0 schema in ``ethereal-spec/security/capabilities-v0.md``
(typed entries: ``io: [{group, dir}]`` / ``services: [{name, access}]``) and the
EMRI v0.6 capability-declaration encoding
(``ethereal-spec/control/emri-v0.md`` sec 3.7: ``CAP_DECL_IO`` @ ``0x22``,
``CAP_DECL_SVC`` @ ``0x23``, ``CAP_STATUS`` @ ``0x24``).

Spec sec 2 defines three validation stages, each a hard refusal (no
auto-narrowing):

  1. **schema** -- :func:`load_capabilities` / :func:`validate_schema` (host, at
     pack/verify): unknown keys, missing keys, bad types/enums, duplicates.
  2. **grantability** -- :func:`validate_grantable` (host pre-flight, before the
     deploy command): declared subset of the platform inventory.
  3. **allocation binding** -- device-side, post-ALLOC/pre-BLANK (the C daemon
     compares the staged ``CAP_DECL_*`` bitmaps); out of scope for this module.

The sim platform inventory is single-sourced here (the C daemon mirrors it):
pin groups 0..7 (:data:`SIM_ALLOWED_IO_MASK`) and service indices 0..7
(:data:`SIM_ALLOWED_SVC_MASK`).

Plan-Ref: ethereal-spec/security/capabilities-v0.md sec 1-2/4;
          ethereal-plan/subsystems/S10-安全子系统.md (E2-SEC1).
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal, cast

import yaml  # type: ignore[import-untyped]

# ---- schema vocabulary (capabilities-v0.md sec 1) ------------------------- #
IO_DIRS: tuple[str, ...] = ("in", "out", "inout")
SVC_ACCESS: tuple[str, ...] = ("r", "w", "rw")
IoDir = Literal["in", "out", "inout"]
SvcAccess = Literal["r", "w", "rw"]

TOP_LEVEL_KEYS = frozenset({"io", "services"})
IO_ENTRY_KEYS = frozenset({"group", "dir"})
SVC_ENTRY_KEYS = frozenset({"name", "access"})

# ---- sim platform inventory (the C daemon mirrors these masks) ------------ #
SIM_ALLOWED_IO_MASK = 0x0000_00FF  # pin groups 0..7 (S06:24, one group = 8 pins)
SIM_ALLOWED_SVC_MASK = 0x0000_00FF  # EBI proxy index 0..7 (S06:39)
# ASSUMPTION: the RFC-004 device classes named in capabilities-v0.md sec 1 map
# to EBI proxy indices in this order; slots 5..7 are reserved. E1-IO3's Board
# Manifest proxy table replaces this table (TBD, 2026-09-11).
SIM_SERVICE_INDEX: dict[str, int] = {
    "spi0": 0,
    "i2c0": 1,
    "uart0": 2,
    "pwm0": 3,
    "qei0": 4,
}
CAP_DECL_BITS = 32  # EMRI v0.6 CAP_DECL_IO/CAP_DECL_SVC are 32-bit bitmaps

# ---- CAP_STATUS bit layout (emri-v0.md sec 3.7, offset 0x24) -------------- #
CAP_STATUS_CHECKED = 0  # bit [0]
CAP_STATUS_DENIED = 1  # bit [1]
CAP_STATUS_THROTTLED = 2  # bit [2]
CAP_STATUS_DENIED_IO_SHIFT = 8  # bits [15:8] = low 8 bits of the offending mask
CAP_STATUS_DENIED_IO_MASK = 0xFF


# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #
class CapabilityError(Exception):
    """Base class for capability-declaration failures.

    ``entry`` carries the offending declaration (raw YAML entry or typed
    :class:`IoDecl`/:class:`SvcDecl`) so a CLI refusal can name it exactly.
    """

    def __init__(self, message: str, entry: object = None) -> None:
        super().__init__(message)
        self.entry = entry


class CapabilitySchemaError(CapabilityError):
    """A capabilities.yaml schema violation (capabilities-v0.md sec 1 rule 2)."""


class CapabilityDenied(CapabilityError):
    """Declared capability exceeds the platform inventory (spec sec 2 stage 2)."""


# --------------------------------------------------------------------------- #
# Typed declaration model
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class IoDecl:
    """One declared L1 pin group (spec sec 1)."""

    group: int
    dir: IoDir


@dataclass(frozen=True)
class SvcDecl:
    """One declared L2 proxy/virtual-device instance (spec sec 1)."""

    name: str
    access: SvcAccess


@dataclass(frozen=True)
class Capabilities:
    """A parsed capability declaration; ``Capabilities()`` is the empty set."""

    io: tuple[IoDecl, ...] = ()
    services: tuple[SvcDecl, ...] = ()


@dataclass(frozen=True)
class CapStatus:
    """Decoded EMRI ``CAP_STATUS`` word (emri-v0.md sec 3.7)."""

    checked: bool
    denied: bool
    throttled: bool
    denied_io: int


# --------------------------------------------------------------------------- #
# Stage 1: schema
# --------------------------------------------------------------------------- #
def _schema_error(message: str, entry: object) -> CapabilitySchemaError:
    where = "" if entry is None else f" (entry: {entry!r})"
    return CapabilitySchemaError(f"capabilities.yaml: {message}{where}", entry)


def _mapping(value: object, where: str) -> dict[object, object]:
    if not isinstance(value, dict):
        raise _schema_error(f"{where} must be a mapping, not {type(value).__name__}", value)
    return cast("dict[object, object]", value)


def _list(value: object, where: str) -> list[object]:
    if not isinstance(value, list):
        raise _schema_error(f"{where} must be a list, not {type(value).__name__}", value)
    return cast("list[object]", value)


def _reject_unknown(mapping: dict[object, object], allowed: frozenset[str], where: str) -> None:
    unknown = sorted(str(k) for k in mapping if str(k) not in allowed)
    if unknown:
        raise _schema_error(f"{where}: unknown key(s): {', '.join(unknown)}", mapping)


def _require_keys(mapping: dict[object, object], required: tuple[str, ...], where: str) -> None:
    missing = [k for k in required if k not in mapping]
    if missing:
        raise _schema_error(f"{where}: missing required key(s): {', '.join(missing)}", mapping)


def _parse_io_entry(entry: object, idx: int) -> IoDecl:
    where = f"io[{idx}]"
    mapping = _mapping(entry, where)
    _reject_unknown(mapping, IO_ENTRY_KEYS, where)
    _require_keys(mapping, ("group", "dir"), where)
    group = mapping["group"]
    if isinstance(group, bool) or not isinstance(group, int):
        raise _schema_error(f"{where}.group must be an integer, not {type(group).__name__}", entry)
    if group < 0:
        raise _schema_error(f"{where}.group must be >= 0, got {group}", entry)
    direction = mapping["dir"]
    if not isinstance(direction, str) or direction not in IO_DIRS:
        raise _schema_error(f"{where}.dir must be one of {', '.join(IO_DIRS)}, got {direction!r}", entry)
    return IoDecl(group=group, dir=cast(IoDir, direction))


def _parse_svc_entry(entry: object, idx: int) -> SvcDecl:
    where = f"services[{idx}]"
    mapping = _mapping(entry, where)
    _reject_unknown(mapping, SVC_ENTRY_KEYS, where)
    _require_keys(mapping, ("name", "access"), where)
    name = mapping["name"]
    if not isinstance(name, str) or not name:
        raise _schema_error(f"{where}.name must be a non-empty string, got {name!r}", entry)
    access = mapping["access"]
    if not isinstance(access, str) or access not in SVC_ACCESS:
        raise _schema_error(
            f"{where}.access must be one of {', '.join(SVC_ACCESS)}, got {access!r}", entry
        )
    return SvcDecl(name=name, access=cast(SvcAccess, access))


def validate_schema(caps: Capabilities) -> None:
    """Re-check the stage-1 schema rules on a typed declaration (spec sec 1).

    :func:`load_capabilities` already applies this; calling it again guards
    programmatically-built declarations (hand-built entries, mixed types).
    Raises :class:`CapabilitySchemaError` naming the offending entry.
    """
    seen_groups: set[int] = set()
    for idx, decl in enumerate(caps.io):
        if isinstance(decl.group, bool) or not isinstance(decl.group, int) or decl.group < 0:
            raise _schema_error(f"io[{idx}].group must be an integer >= 0, got {decl.group!r}", decl)
        if decl.dir not in IO_DIRS:
            raise _schema_error(f"io[{idx}].dir must be one of {', '.join(IO_DIRS)}, got {decl.dir!r}", decl)
        if decl.group in seen_groups:
            raise _schema_error(f"io[{idx}]: duplicate group {decl.group}", decl)
        seen_groups.add(decl.group)
    seen_names: set[str] = set()
    for idx, sdecl in enumerate(caps.services):
        if not isinstance(sdecl.name, str) or not sdecl.name:
            raise _schema_error(f"services[{idx}].name must be a non-empty string, got {sdecl.name!r}", sdecl)
        if sdecl.access not in SVC_ACCESS:
            raise _schema_error(
                f"services[{idx}].access must be one of {', '.join(SVC_ACCESS)}, got {sdecl.access!r}",
                sdecl,
            )
        if sdecl.name in seen_names:
            raise _schema_error(f"services[{idx}]: duplicate name {sdecl.name!r}", sdecl)
        seen_names.add(sdecl.name)


def load_capabilities(path_or_text: Path | str) -> Capabilities:
    """Parse and schema-validate a ``capabilities.yaml`` (spec sec 1).

    ``path_or_text`` is a :class:`~pathlib.Path` -> file mode (an ABSENT file is
    the empty capability set, spec sec 1 rule 3) or a ``str`` -> raw YAML text.
    Strict: both top-level keys are required, unknown keys/enums/duplicates are
    rejected. Raises :class:`CapabilitySchemaError`.
    """
    if isinstance(path_or_text, Path):
        if not path_or_text.exists():
            return Capabilities()
        text = path_or_text.read_text(encoding="utf-8")
    else:
        text = path_or_text
    try:
        doc: object = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise CapabilitySchemaError(f"capabilities.yaml: invalid YAML: {e}", None) from e
    caps = _parse_document(doc)
    validate_schema(caps)
    return caps


def _parse_document(doc: object) -> Capabilities:
    mapping = _mapping(doc, "top level")
    _reject_unknown(mapping, TOP_LEVEL_KEYS, "top level")
    _require_keys(mapping, ("io", "services"), "top level")
    io = tuple(
        _parse_io_entry(entry, idx)
        for idx, entry in enumerate(_list(mapping["io"], "io"))
    )
    services = tuple(
        _parse_svc_entry(entry, idx)
        for idx, entry in enumerate(_list(mapping["services"], "services"))
    )
    return Capabilities(io=io, services=services)


# --------------------------------------------------------------------------- #
# Stage 2: grantability (host pre-flight)
# --------------------------------------------------------------------------- #
def validate_grantable(
    caps: Capabilities,
    allowed_io_mask: int,
    allowed_svc_mask: int,
) -> None:
    """Check ``declared subset of grantable`` (spec sec 2 stage 2).

    ``allowed_io_mask``/``allowed_svc_mask`` are the platform inventory bitmaps
    (bit ``g`` = pin group ``g`` / proxy index ``k``). Any declaration outside
    them raises :class:`CapabilityDenied` naming the offending entry; a group
    that does not even fit ``CAP_DECL_IO`` is denied for the same reason.
    """
    for idx, decl in enumerate(caps.io):
        in_range = 0 <= decl.group < CAP_DECL_BITS
        if not in_range or not allowed_io_mask & (1 << decl.group):
            raise CapabilityDenied(
                f"io[{idx}]: pin group {decl.group} (dir={decl.dir}) is not "
                f"grantable by this platform (allowed mask 0x{allowed_io_mask:08x})",
                decl,
            )
    for idx, sdecl in enumerate(caps.services):
        proxy = SIM_SERVICE_INDEX.get(sdecl.name)
        if proxy is None:
            raise CapabilityDenied(
                f"services[{idx}]: unknown service {sdecl.name!r} "
                f"(known: {', '.join(sorted(SIM_SERVICE_INDEX))})",
                sdecl,
            )
        if not allowed_svc_mask & (1 << proxy):
            raise CapabilityDenied(
                f"services[{idx}]: service {sdecl.name!r} (index {proxy}) is not "
                f"grantable by this platform (allowed mask 0x{allowed_svc_mask:08x})",
                sdecl,
            )


def validate_grantable_sim(caps: Capabilities) -> None:
    """Stage-2 pre-flight against the v0 sim inventory (spec sec 2)."""
    validate_grantable(caps, SIM_ALLOWED_IO_MASK, SIM_ALLOWED_SVC_MASK)


def load_and_check(
    path_or_text: Path | str,
    *,
    allowed_io_mask: int = SIM_ALLOWED_IO_MASK,
    allowed_svc_mask: int = SIM_ALLOWED_SVC_MASK,
) -> Capabilities:
    """``load_capabilities`` + stage-2 grantability in one pre-flight call."""
    caps = load_capabilities(path_or_text)
    validate_grantable(caps, allowed_io_mask, allowed_svc_mask)
    return caps


# --------------------------------------------------------------------------- #
# EMRI v0.6 encoding
# --------------------------------------------------------------------------- #
def to_emri_bitmaps(caps: Capabilities) -> tuple[int, int]:
    """Encode a declaration as ``(CAP_DECL_IO, CAP_DECL_SVC)`` (sec 3.7).

    Bit ``g`` of ``CAP_DECL_IO`` = declared pin group ``g``; bit ``k`` of
    ``CAP_DECL_SVC`` = declared RFC-004 proxy index ``k``. A group that does not
    fit the 32-bit word raises :class:`CapabilityDenied` (it can never be
    granted, so it is refused rather than silently widened).
    """
    decl_io = 0
    for decl in caps.io:
        if not 0 <= decl.group < CAP_DECL_BITS:
            raise CapabilityDenied(
                f"pin group {decl.group} does not fit the {CAP_DECL_BITS}-bit "
                "CAP_DECL_IO bitmap",
                decl,
            )
        decl_io |= 1 << decl.group
    decl_svc = 0
    for sdecl in caps.services:
        proxy = SIM_SERVICE_INDEX.get(sdecl.name)
        if proxy is None:
            raise CapabilityDenied(
                f"service {sdecl.name!r} has no CAP_DECL_SVC bit "
                f"(known: {', '.join(sorted(SIM_SERVICE_INDEX))})",
                sdecl,
            )
        decl_svc |= 1 << proxy
    return decl_io & 0xFFFF_FFFF, decl_svc & 0xFFFF_FFFF


def cap_status_decode(word: int) -> CapStatus:
    """Decode an EMRI ``CAP_STATUS`` word (spec sec 3.7)."""
    return CapStatus(
        checked=bool(word & (1 << CAP_STATUS_CHECKED)),
        denied=bool(word & (1 << CAP_STATUS_DENIED)),
        throttled=bool(word & (1 << CAP_STATUS_THROTTLED)),
        denied_io=(word >> CAP_STATUS_DENIED_IO_SHIFT) & CAP_STATUS_DENIED_IO_MASK,
    )


def cap_status_encode(status: CapStatus) -> int:
    """Encode a :class:`CapStatus` back into an EMRI ``CAP_STATUS`` word."""
    word = 0
    if status.checked:
        word |= 1 << CAP_STATUS_CHECKED
    if status.denied:
        word |= 1 << CAP_STATUS_DENIED
    if status.throttled:
        word |= 1 << CAP_STATUS_THROTTLED
    word |= (status.denied_io & CAP_STATUS_DENIED_IO_MASK) << CAP_STATUS_DENIED_IO_SHIFT
    return word
