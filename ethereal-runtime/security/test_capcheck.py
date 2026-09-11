# SPDX-License-Identifier: MIT
"""Tests for the capabilities.yaml guard (E2-SEC1).

Covers the frozen schema (``ethereal-spec/security/capabilities-v0.md`` sec 1),
the stage-2 grantability pre-flight against the sim inventory (sec 2), and the
EMRI v0.6 ``CAP_DECL_*``/``CAP_STATUS`` encodings (emri-v0.md sec 3.7).
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# The package lives in ethereal-runtime/security/; make `security` importable
# regardless of pytest's invocation CWD.
_RUNTIME_DIR = str(Path(__file__).resolve().parents[1])
if _RUNTIME_DIR not in sys.path:
    sys.path.insert(0, _RUNTIME_DIR)

# pi-lens-ignore: E402
from security import capcheck


def _caps(**kw: object) -> capcheck.Capabilities:
    return capcheck.Capabilities(**kw)  # type: ignore[arg-type]


# --------------------------------------------------------------------------- #
# stage 1: schema
# --------------------------------------------------------------------------- #
def test_empty_declaration_is_valid() -> None:
    caps = capcheck.load_capabilities("io: []\nservices: []\n")
    assert caps == capcheck.Capabilities()
    assert caps.io == () and caps.services == ()


def test_absent_file_is_empty_set(tmp_path: Path) -> None:
    caps = capcheck.load_capabilities(tmp_path / "capabilities.yaml")
    assert caps == capcheck.Capabilities()


def test_typed_entries_parse() -> None:
    caps = capcheck.load_capabilities(
        "io:\n"
        "  - {group: 3, dir: inout}\n"
        "  - group: 5\n"
        "    dir: out\n"
        "services:\n"
        "  - {name: spi0, access: rw}\n"
        "  - {name: uart0, access: r}\n"
    )
    assert caps.io == (capcheck.IoDecl(3, "inout"), capcheck.IoDecl(5, "out"))
    assert caps.services == (
        capcheck.SvcDecl("spi0", "rw"),
        capcheck.SvcDecl("uart0", "r"),
    )


def test_reject_unknown_top_level_key() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="unknown key"):
        capcheck.load_capabilities("io: []\nservices: []\nregions: [1]\n")


def test_reject_missing_top_level_key() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="missing required"):
        capcheck.load_capabilities("io: []\n")


def test_reject_unknown_entry_key() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="io\\[0\\]: unknown key"):
        capcheck.load_capabilities("io:\n  - {group: 0, dir: out, pin: 4}\nservices: []\n")


def test_reject_missing_entry_key() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="missing required"):
        capcheck.load_capabilities("io:\n  - {group: 0}\nservices: []\n")


def test_reject_bad_dir_enum() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="io\\[0\\].dir"):
        capcheck.load_capabilities("io:\n  - {group: 0, dir: sideways}\nservices: []\n")


def test_reject_bad_access_enum() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="services\\[0\\].access"):
        capcheck.load_capabilities(
            "io: []\nservices:\n  - {name: spi0, access: x}\n"
        )


def test_reject_wrong_types() -> None:
    for bad in (
        "io:\n  - {group: '0', dir: out}\nservices: []\n",  # group str
        "io:\n  - {group: true, dir: out}\nservices: []\n",  # group bool
        "io:\n  - {group: -1, dir: out}\nservices: []\n",  # group negative
        "io: {group: 0}\nservices: []\n",  # io not a list
        "io: []\nservices:\n  - {name: 7, access: r}\n",  # name not a str
        "io: []\nservices:\n  - {name: '', access: r}\n",  # empty name
    ):
        with pytest.raises(capcheck.CapabilitySchemaError):
            capcheck.load_capabilities(bad)


def test_reject_duplicate_group() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="duplicate group 2"):
        capcheck.load_capabilities(
            "io:\n  - {group: 2, dir: in}\n  - {group: 2, dir: out}\nservices: []\n"
        )


def test_reject_duplicate_service_name() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="duplicate name"):
        capcheck.load_capabilities(
            "io: []\nservices:\n"
            "  - {name: spi0, access: r}\n  - {name: spi0, access: w}\n"
        )


def test_reject_invalid_yaml_and_non_mapping() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError, match="invalid YAML"):
        capcheck.load_capabilities("io: [\n")
    with pytest.raises(capcheck.CapabilitySchemaError, match="must be a mapping"):
        capcheck.load_capabilities("- io\n- services\n")


def test_validate_schema_catches_handbuilt_duplicate() -> None:
    caps = _caps(io=(capcheck.IoDecl(1, "in"), capcheck.IoDecl(1, "out")))
    with pytest.raises(capcheck.CapabilitySchemaError, match="duplicate group 1"):
        capcheck.validate_schema(caps)


def test_schema_error_carries_offending_entry() -> None:
    with pytest.raises(capcheck.CapabilitySchemaError) as ei:
        capcheck.load_capabilities("io:\n  - {group: 0, dir: up}\nservices: []\n")
    assert ei.value.entry == {"group": 0, "dir": "up"}
    assert "up" in str(ei.value)


# --------------------------------------------------------------------------- #
# stage 2: grantability
# --------------------------------------------------------------------------- #
def test_grantable_sim_ok() -> None:
    caps = capcheck.load_capabilities(
        "io:\n  - {group: 0, dir: out}\n  - {group: 7, dir: inout}\n"
        "services:\n  - {name: spi0, access: rw}\n  - {name: qei0, access: r}\n"
    )
    capcheck.validate_grantable_sim(caps)  # must not raise


def test_grantable_denies_over_declared_group_200() -> None:
    caps = capcheck.load_capabilities(
        "io:\n  - {group: 200, dir: out}\nservices: []\n"
    )
    with pytest.raises(capcheck.CapabilityDenied) as ei:
        capcheck.validate_grantable_sim(caps)
    assert ei.value.entry == capcheck.IoDecl(200, "out")
    assert "200" in str(ei.value)


def test_grantable_denies_group_outside_sim_mask() -> None:
    caps = capcheck.load_capabilities("io:\n  - {group: 8, dir: in}\nservices: []\n")
    with pytest.raises(capcheck.CapabilityDenied, match="group 8"):
        capcheck.validate_grantable_sim(caps)


def test_grantable_denies_unknown_service() -> None:
    caps = capcheck.load_capabilities(
        "io: []\nservices:\n  - {name: can0, access: r}\n"
    )
    with pytest.raises(capcheck.CapabilityDenied) as ei:
        capcheck.validate_grantable_sim(caps)
    assert ei.value.entry == capcheck.SvcDecl("can0", "r")
    assert "can0" in str(ei.value)


def test_grantable_denies_service_outside_mask() -> None:
    caps = _caps(services=(capcheck.SvcDecl("spi0", "rw"),))
    with pytest.raises(capcheck.CapabilityDenied, match="index 0"):
        capcheck.validate_grantable(caps, capcheck.SIM_ALLOWED_IO_MASK, 0x00)


def test_load_and_check_returns_validated_caps() -> None:
    caps = capcheck.load_and_check("io:\n  - {group: 4, dir: out}\nservices: []\n")
    assert caps.io == (capcheck.IoDecl(4, "out"),)


# --------------------------------------------------------------------------- #
# EMRI v0.6 encodings
# --------------------------------------------------------------------------- #
def test_to_emri_bitmaps_roundtrip() -> None:
    caps = capcheck.load_capabilities(
        "io:\n  - {group: 0, dir: in}\n  - {group: 7, dir: out}\n"
        "services:\n  - {name: spi0, access: r}\n  - {name: qei0, access: rw}\n"
    )
    decl_io, decl_svc = capcheck.to_emri_bitmaps(caps)
    assert decl_io == 0b1000_0001  # groups 0 and 7
    assert decl_svc == 0b0001_0001  # proxy indices 0 (spi0) and 4 (qei0)


def test_to_emri_bitmaps_empty_is_zero() -> None:
    assert capcheck.to_emri_bitmaps(capcheck.Capabilities()) == (0, 0)


def test_to_emri_bitmaps_rejects_unencodable_group_and_unknown_service() -> None:
    with pytest.raises(capcheck.CapabilityDenied, match="CAP_DECL_IO"):
        capcheck.to_emri_bitmaps(_caps(io=(capcheck.IoDecl(32, "out"),)))
    with pytest.raises(capcheck.CapabilityDenied, match="CAP_DECL_SVC"):
        capcheck.to_emri_bitmaps(_caps(services=(capcheck.SvcDecl("can0", "r"),)))


def test_cap_status_encode_decode_roundtrip() -> None:
    for status in (
        capcheck.CapStatus(checked=False, denied=False, throttled=False, denied_io=0),
        capcheck.CapStatus(checked=True, denied=False, throttled=False, denied_io=0),
        capcheck.CapStatus(checked=True, denied=True, throttled=False, denied_io=0x81),
        capcheck.CapStatus(checked=True, denied=False, throttled=True, denied_io=0xFF),
    ):
        assert capcheck.cap_status_decode(capcheck.cap_status_encode(status)) == status


def test_cap_status_decode_bit_layout() -> None:
    word = (1 << 0) | (1 << 1) | (1 << 2) | (0x5A << 8)
    status = capcheck.cap_status_decode(word)
    assert (status.checked, status.denied, status.throttled) == (True, True, True)
    assert status.denied_io == 0x5A
    # reserved bits must not leak into any field
    assert capcheck.cap_status_decode(0xFFFF_0000) == capcheck.CapStatus(
        checked=False, denied=False, throttled=False, denied_io=0
    )


def test_sim_inventory_masks_are_single_source() -> None:
    """The sim inventory is introspectable and matches the frozen masks."""
    assert capcheck.SIM_ALLOWED_IO_MASK == 0xFF
    assert capcheck.SIM_ALLOWED_SVC_MASK == 0xFF
    assert set(capcheck.SIM_SERVICE_INDEX) == {"spi0", "i2c0", "uart0", "pwm0", "qei0"}
