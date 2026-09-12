# SPDX-License-Identifier: MIT
"""pytest suite for the EBI-Tiny / mFSM golden model (tasks E0-SHL1 + E2-BMC1).

Validates the SPEC locally (no simulator, no Verilator) and — the part that
catches real ABI drift — cross-checks the model's constants against the ones
actually declared in the SystemVerilog packages and used by the RTL:

    ethereal-shell/rtl/ebi/ebi_pkg.sv      window map
    ethereal-shell/rtl/emri/emri_pkg.sv    EMRI register offsets
    ethereal-shell/rtl/mfsm/mfsm_pkg.sv    session encodings / status layout

Run: ``pytest ethereal-fabric/tests/ebi/test_ebi_tiny_model.py -v``
(or ``make test-model``).
"""
from __future__ import annotations

import itertools
from pathlib import Path

import pytest
from ebi_tiny_model import (
    CAPB_HAS_BMC,
    EBI_PKG_SV,
    EBI_TINY_SV,
    EMRI_MAP,
    EMRI_PKG_SV,
    EMRI_REGFILE_SV,
    IO_BASE,
    MAX_REGIONS,
    MFSM_PKG_SV,
    MODE_DEPENDENT_FIELDS,
    OCC_BASE,
    REGION_BASE,
    RESERVED_OFFSETS,
    RX_BUF_MAX_DEPTH,
    SERVICE_BASE,
    SESSION_CMD_ABORT,
    SESSION_CMD_BEGIN_RX,
    SESSION_CMD_NOP,
    SESSION_CMD_OCC_GO,
    SESSION_CMD_VERIFY,
    SESSION_ERR_BAD_CRC,
    SESSION_ERR_NONE,
    SESSION_ERR_OCC_ERROR,
    SESSION_ERR_OCC_LOCKED,
    SESSION_S_ERROR,
    SESSION_S_IDLE,
    SESSION_S_OCC_GO,
    SESSION_S_RX,
    SESSION_S_VERIFY,
    SESSION_STATES,
    SESSION_STATUS_ERR_LSB,
    SESSION_STATUS_STATE_LSB,
    SESSION_TERM_DONE,
    SESSION_TERM_ERROR,
    SESSION_TERM_LOCKED,
    SESSION_TERM_NEEDS_BLANK,
    SHELL_CSR_BASE,
    WINDOW_BYTES,
    SessionFSM,
    decode,
    naive_windows,
    num_windows,
    random_addresses,
    registers_read_zero,
    session_status_word,
    sv_int,
    sv_localparams,
    win_io,
    win_region,
    win_service,
    window_base,
)

NUM_REGIONS = 2


# ---------------------------------------------------------------------------
# 1. Window map invariants (the blueprint's bases + the 64 KiB page granularity)
# ---------------------------------------------------------------------------
def test_windows_are_page_aligned_and_never_overlap() -> None:
    spans = []
    for w in range(num_windows(NUM_REGIONS)):
        base = window_base(NUM_REGIONS, w)
        assert base % WINDOW_BYTES == 0, f"window {w} is not page-aligned"
        spans.append((base, base + WINDOW_BYTES))
    spans.sort()
    for (lo_a, hi_a), (lo_b, _) in itertools.pairwise(spans):
        assert hi_a <= lo_b, "EBI windows must never overlap"
    # the blueprint's adjacency: shell then occ, regions contiguous from the region
    # base, then the Service Tile range and the IO range (each one 16-page span)
    assert window_base(NUM_REGIONS, 1) - window_base(NUM_REGIONS, 0) == WINDOW_BYTES
    for r in range(NUM_REGIONS - 1):
        assert window_base(NUM_REGIONS, 2 + r + 1) - window_base(NUM_REGIONS, 2 + r) == WINDOW_BYTES


def test_region_and_service_ranges_are_max_regions_pages_wide() -> None:
    # MAX_REGIONS is exactly the number of 64 KiB pages between the region base and
    # the Service Tile base — the ceiling the RTL decoder documents — and the
    # blueprint's "0x0020_0000+ / 0x0030_0000+" ranges are likewise 16-page spans.
    assert SERVICE_BASE - REGION_BASE == MAX_REGIONS * WINDOW_BYTES
    assert IO_BASE - SERVICE_BASE == MAX_REGIONS * WINDOW_BYTES


def test_window_indices_match_ebi_pkg_order() -> None:
    assert win_region(NUM_REGIONS, 0) == 2
    assert win_service(NUM_REGIONS) == 2 + NUM_REGIONS
    assert win_io(NUM_REGIONS) == 3 + NUM_REGIONS
    assert num_windows(NUM_REGIONS) == 6


# ---------------------------------------------------------------------------
# 2. Decode table + boundaries
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("region", [0, 1])
def test_every_window_decodes_to_itself(region: int) -> None:
    for w in range(num_windows(NUM_REGIONS)):
        base = window_base(NUM_REGIONS, w)
        for off in (0x0, 0x4, 0x100, WINDOW_BYTES - 4):
            d = decode(base + off, NUM_REGIONS)
            assert d.valid and d.window == w and d.offset == off


def test_first_and_last_word_of_each_window() -> None:
    for w in range(num_windows(NUM_REGIONS)):
        base = window_base(NUM_REGIONS, w)
        assert decode(base, NUM_REGIONS).window == w
        assert decode(base + WINDOW_BYTES - 1, NUM_REGIONS).window == w
        # one byte past the window is no longer that window
        assert decode(base + WINDOW_BYTES, NUM_REGIONS).window != w


@pytest.mark.parametrize(
    "addr",
    [
        0x0002_0000,  # between shell and occ
        0x000F_0000,  # between occ and the region range
        0x0012_0000,  # region page >= NUM_REGIONS (a window that does not exist)
        0x001F_0000,  # last page of the region range, still >= NUM_REGIONS
        0x0021_0000,  # inside the service range but past its page
        0x0040_0000,
        0xFFFF_FFFF,
    ],
)
def test_unimplemented_addresses_error(addr: int) -> None:
    d = decode(addr, NUM_REGIONS)
    assert not d.valid and d.window == -1


def test_offset_is_always_the_low_16_bits() -> None:
    for addr in random_addresses(500):
        d = decode(addr, NUM_REGIONS)
        assert d.offset == addr & 0xFFFF


# ---------------------------------------------------------------------------
# 3. Random decode consistency vs an independent range oracle
# ---------------------------------------------------------------------------
def test_random_decode_matches_range_oracle() -> None:
    for addr in random_addresses(5000):
        hits = naive_windows(addr, NUM_REGIONS)
        d = decode(addr, NUM_REGIONS)
        assert len(hits) <= 1, "windows must not overlap"
        if hits:
            assert d.valid and d.window == hits[0]
        else:
            # either undecoded, OR a region page that exists as a range but is
            # beyond NUM_REGIONS (the one case the oracle and the decoder differ
            # by construction: the former is a range, the latter knows the count)
            page = addr >> 16
            in_region_range = (REGION_BASE >> 16) <= page < (REGION_BASE >> 16) + MAX_REGIONS
            assert not d.valid
            assert in_region_range or d.window == -1


def test_region_page_beyond_num_regions_is_an_error_not_a_window() -> None:
    addr = REGION_BASE + (MAX_REGIONS - 1) * WINDOW_BYTES  # last page of the range
    assert not decode(addr, NUM_REGIONS).valid
    assert decode(addr, MAX_REGIONS).valid  # with MAX_REGIONS regions it exists


# ---------------------------------------------------------------------------
# 4. EMRI map: reserved offsets, the mode-dependent contract
# ---------------------------------------------------------------------------
def test_reserved_offsets_read_zero_and_are_not_allocated() -> None:
    for off in RESERVED_OFFSETS:
        assert registers_read_zero(off)
        assert all(r.offset != off for r in EMRI_MAP)


def test_map_offsets_are_unique_and_word_sized() -> None:
    offsets = [r.offset for r in EMRI_MAP]
    assert len(offsets) == len(set(offsets))
    for r in EMRI_MAP:
        assert 0x00 <= r.offset <= 0xFF, f"{r.name} outside the 8-bit word map"


def test_only_capabilities_is_mode_dependent() -> None:
    """emri-v0.md §1 principle 1: the ONLY field that differs is has_bmc."""
    assert MODE_DEPENDENT_FIELDS == {"CAPABILITIES"}
    caps = next(r for r in EMRI_MAP if r.name == "CAPABILITIES")
    assert caps.offset == 0x02 and caps.access == "ro"
    assert CAPB_HAS_BMC == 0


# ---------------------------------------------------------------------------
# 5. Session FSM edges (spec §5) + status word layout
# ---------------------------------------------------------------------------
def step(fsm: SessionFSM, cmd: int = SESSION_CMD_NOP, term: int | None = None) -> None:
    fsm.step(cmd, term)


def test_session_starts_idle_and_begin_rx_enters_rx() -> None:
    fsm = SessionFSM(rx_depth=4)
    assert fsm.status == session_status_word(SESSION_S_IDLE, SESSION_ERR_NONE)
    step(fsm, SESSION_CMD_BEGIN_RX)
    assert fsm.state == SESSION_S_RX


def test_rx_full_advances_to_verify_req() -> None:
    fsm = SessionFSM(rx_depth=2)
    step(fsm, SESSION_CMD_BEGIN_RX)
    fsm.rx_push()
    step(fsm)
    assert fsm.state == SESSION_S_RX, "one push below depth must NOT advance"
    fsm.rx_push()
    step(fsm)
    assert fsm.state == SESSION_S_VERIFY and fsm.rx_full


def test_depth_zero_disables_the_full_trigger() -> None:
    fsm = SessionFSM(rx_depth=0)
    step(fsm, SESSION_CMD_BEGIN_RX)
    for _ in range(10):
        fsm.rx_push()
        step(fsm)
    assert fsm.state == SESSION_S_RX
    step(fsm, SESSION_CMD_VERIFY)
    assert fsm.state == SESSION_S_VERIFY


def test_explicit_verify_advances_from_rx() -> None:
    fsm = SessionFSM(rx_depth=0)
    step(fsm, SESSION_CMD_BEGIN_RX)
    step(fsm, SESSION_CMD_VERIFY)
    assert fsm.state == SESSION_S_VERIFY


@pytest.mark.parametrize("path", [SESSION_S_RX, SESSION_S_VERIFY, SESSION_S_ERROR])
def test_abort_returns_to_idle(path: int) -> None:
    fsm = SessionFSM(rx_depth=4)
    step(fsm, SESSION_CMD_BEGIN_RX)
    if path == SESSION_S_VERIFY:
        step(fsm, SESSION_CMD_VERIFY)
    elif path == SESSION_S_ERROR:
        step(fsm, SESSION_CMD_VERIFY)
        step(fsm, SESSION_CMD_OCC_GO)
        step(fsm, term=SESSION_TERM_ERROR)
        assert fsm.state == SESSION_S_ERROR
    assert fsm.state == path
    step(fsm, SESSION_CMD_ABORT)
    assert fsm.state == SESSION_S_IDLE and fsm.err == SESSION_ERR_NONE


def test_abort_is_not_a_spec_edge_from_occ_go_or_idle() -> None:
    fsm = SessionFSM(rx_depth=4)
    step(fsm, SESSION_CMD_ABORT)
    assert fsm.state == SESSION_S_IDLE
    step(fsm, SESSION_CMD_BEGIN_RX)
    step(fsm, SESSION_CMD_VERIFY)
    step(fsm, SESSION_CMD_OCC_GO)
    assert fsm.state == SESSION_S_OCC_GO
    step(fsm, SESSION_CMD_ABORT)
    assert fsm.state == SESSION_S_OCC_GO, "the §5 diagram has no abort edge from OCC_GO"


@pytest.mark.parametrize(
    "cmd,start_state,expect_state",
    [
        # occ_go only acts in VERIFY_REQ (the one documented edge)
        (SESSION_CMD_OCC_GO, SESSION_S_IDLE, SESSION_S_IDLE),
        (SESSION_CMD_OCC_GO, SESSION_S_RX, SESSION_S_RX),
        # verify only acts in RX
        (SESSION_CMD_VERIFY, SESSION_S_IDLE, SESSION_S_IDLE),
    ],
)
def test_wrong_state_commands_are_noops(cmd: int, start_state: int, expect_state: int) -> None:
    fsm = SessionFSM(rx_depth=0)
    if start_state == SESSION_S_RX:
        step(fsm, SESSION_CMD_BEGIN_RX)
    assert fsm.state == start_state
    step(fsm, cmd)
    assert fsm.state == expect_state


def test_occ_go_completes_on_a_terminal_that_arrived_beforehand() -> None:
    """The latch: the OCC op may finish BEFORE the host writes occ_go (spec §4
    explains why the terminal cannot be polled as a pulse)."""
    fsm = SessionFSM(rx_depth=2)
    step(fsm, SESSION_CMD_BEGIN_RX)
    fsm.rx_push()
    fsm.rx_push()
    step(fsm, term=SESSION_TERM_DONE)  # WRITE completes while still in VERIFY_REQ
    assert fsm.state == SESSION_S_VERIFY and fsm.term_latched == SESSION_TERM_DONE
    step(fsm, SESSION_CMD_OCC_GO)
    assert fsm.state == SESSION_S_OCC_GO
    step(fsm)  # consume the latched terminal
    assert fsm.state == SESSION_S_IDLE and fsm.err == SESSION_ERR_NONE


def test_occ_go_completes_on_a_live_terminal() -> None:
    fsm = SessionFSM(rx_depth=0)
    step(fsm, SESSION_CMD_BEGIN_RX)
    step(fsm, SESSION_CMD_VERIFY)
    step(fsm, SESSION_CMD_OCC_GO)
    assert fsm.state == SESSION_S_OCC_GO
    step(fsm, term=SESSION_TERM_DONE)
    assert fsm.state == SESSION_S_IDLE


@pytest.mark.parametrize(
    "term,expect_err",
    [
        (SESSION_TERM_ERROR, SESSION_ERR_OCC_ERROR),
        (SESSION_TERM_NEEDS_BLANK, SESSION_ERR_OCC_ERROR),  # reported ASSUMPTION
        (SESSION_TERM_LOCKED, SESSION_ERR_OCC_LOCKED),
    ],
)
def test_terminal_class_map(term: int, expect_err: int) -> None:
    fsm = SessionFSM(rx_depth=0)
    step(fsm, SESSION_CMD_BEGIN_RX)
    step(fsm, SESSION_CMD_VERIFY)
    step(fsm, SESSION_CMD_OCC_GO)
    step(fsm, term=term)
    assert fsm.state == SESSION_S_ERROR and fsm.err == expect_err


def test_bad_crc_has_no_producer() -> None:
    """err=1 bad_crc stays reserved: the host verifies (§5 G6), the mFSM cannot."""
    produced = set()
    for cmd in range(5):
        for term in [None, SESSION_TERM_DONE, SESSION_TERM_ERROR,
                     SESSION_TERM_NEEDS_BLANK, SESSION_TERM_LOCKED]:
            f2 = SessionFSM(rx_depth=1)
            step(f2, SESSION_CMD_BEGIN_RX)
            step(f2, cmd, term)
            produced.add(f2.err)
    assert SESSION_ERR_BAD_CRC not in produced


def test_status_word_layout_and_the_reported_done_overlap() -> None:
    """SESSION_STATUS = {err[7:4], state[3:0]} — §5's two fields.

    The §2 table also lists `done[4]`, which overlaps err[7:4]; that discrepancy
    is reported by E2-BMC1 rather than invented here. Assert the implemented
    layout, including the fact that err codes 1 and 3 set bit 4 (so a `done` bit
    there could never be independent).
    """
    assert (SESSION_STATUS_STATE_LSB, SESSION_STATUS_ERR_LSB) == (0, 4)
    assert session_status_word(SESSION_S_ERROR, SESSION_ERR_OCC_ERROR) == 0x34
    assert session_status_word(SESSION_S_IDLE, SESSION_ERR_NONE) == 0x00
    # err[7:4]: codes 1 (bad_crc) and 3 (occ_error) carry bit 4 by definition
    assert session_status_word(0, SESSION_ERR_BAD_CRC) & 0x10
    assert session_status_word(0, SESSION_ERR_OCC_ERROR) & 0x10


def test_state_and_err_encodings_are_the_spec_values() -> None:
    assert (SESSION_S_IDLE, SESSION_S_RX, SESSION_S_VERIFY, SESSION_S_OCC_GO,
            SESSION_S_ERROR) == (0, 1, 2, 3, 4)
    assert SESSION_STATES == 5
    assert (SESSION_CMD_NOP, SESSION_CMD_BEGIN_RX, SESSION_CMD_VERIFY,
            SESSION_CMD_OCC_GO, SESSION_CMD_ABORT) == (0, 1, 2, 3, 4)
    assert (SESSION_ERR_NONE, SESSION_ERR_BAD_CRC, SESSION_ERR_OCC_LOCKED,
            SESSION_ERR_OCC_ERROR) == (0, 1, 2, 3)


def test_rx_buf_ctrl_boundary_semantics() -> None:
    # 16 KiB is the v0 bound (spec §2 offset 0x12)
    assert RX_BUF_MAX_DEPTH == 0x4000
    fsm = SessionFSM(rx_depth=RX_BUF_MAX_DEPTH)
    fsm.rx_rebase(depth=3, wr_ptr=5)      # host rebase above the depth reads as full
    assert fsm.rx_full
    fsm.rx_rebase(depth=3, wr_ptr=2)
    assert not fsm.rx_full
    fsm.rx_push()
    assert fsm.rx_full                  # `>=` not `==`: 3 >= 3 is full


# ---------------------------------------------------------------------------
# 6. Cross-checks against the SystemVerilog packages (drift guard)
# ---------------------------------------------------------------------------
def test_ebi_pkg_constants_match_the_model() -> None:
    params = sv_localparams(EBI_PKG_SV)
    assert sv_int(params["EBI_WINDOW_BYTES"]) == WINDOW_BYTES
    assert sv_int(params["EBI_SHELL_CSR_BASE"]) == SHELL_CSR_BASE
    assert sv_int(params["EBI_OCC_BASE"]) == OCC_BASE
    assert sv_int(params["EBI_REGION_BASE"]) == REGION_BASE
    assert sv_int(params["EBI_SERVICE_BASE"]) == SERVICE_BASE
    assert sv_int(params["EBI_IO_BASE"]) == IO_BASE
    assert sv_int(params["EBI_MAX_REGIONS"]) == MAX_REGIONS
    assert sv_int(params["EBI_WIN_SHELL_CSR"]) == 0
    assert sv_int(params["EBI_WIN_OCC"]) == 1
    assert sv_int(params["EBI_WIN_REGION0"]) == 2


def test_emri_pkg_offsets_match_the_model() -> None:
    params = sv_localparams(EMRI_PKG_SV)
    for reg in EMRI_MAP:
        key = f"R_{reg.name}"
        if key not in params:  # IMG_DIGEST/IMG_SIG/SPI_CRC are handled below
            continue
        assert sv_int(params[key]) == reg.offset, f"offset drift for {reg.name}"
    # the array/alias-prefixed entries
    assert sv_int(params["R_IMG_DIGEST"]) == 0x18
    assert sv_int(params["R_IMG_SIG"]) == 0x50
    assert sv_int(params["R_SPI_CRC"]) == 0x3F
    assert sv_int(params["EMRI_MAGIC"]) == 0x4554_4852
    assert sv_int(params["EMRI_ABI_VERSION"]) == 0x0000_0000
    assert sv_int(params["CAPB_HAS_BMC"]) == CAPB_HAS_BMC


def test_mfsm_pkg_encodings_match_the_model() -> None:
    params = sv_localparams(MFSM_PKG_SV)
    assert sv_int(params["SESSION_CMD_BEGIN_RX"]) == SESSION_CMD_BEGIN_RX
    assert sv_int(params["SESSION_CMD_VERIFY"]) == SESSION_CMD_VERIFY
    assert sv_int(params["SESSION_CMD_OCC_GO"]) == SESSION_CMD_OCC_GO
    assert sv_int(params["SESSION_CMD_ABORT"]) == SESSION_CMD_ABORT
    assert sv_int(params["SESSION_CMD_NOP"]) == SESSION_CMD_NOP
    assert sv_int(params["SESSION_S_IDLE"]) == SESSION_S_IDLE
    assert sv_int(params["SESSION_S_RX"]) == SESSION_S_RX
    assert sv_int(params["SESSION_S_VERIFY"]) == SESSION_S_VERIFY
    assert sv_int(params["SESSION_S_OCC_GO"]) == SESSION_S_OCC_GO
    assert sv_int(params["SESSION_S_ERROR"]) == SESSION_S_ERROR
    assert sv_int(params["SESSION_STATES"]) == SESSION_STATES
    assert sv_int(params["SESSION_ERR_NONE"]) == SESSION_ERR_NONE
    assert sv_int(params["SESSION_ERR_BAD_CRC"]) == SESSION_ERR_BAD_CRC
    assert sv_int(params["SESSION_ERR_OCC_LOCKED"]) == SESSION_ERR_OCC_LOCKED
    assert sv_int(params["SESSION_ERR_OCC_ERROR"]) == SESSION_ERR_OCC_ERROR
    assert sv_int(params["SESSION_TERM_DONE"]) == SESSION_TERM_DONE
    assert sv_int(params["SESSION_TERM_ERROR"]) == SESSION_TERM_ERROR
    assert sv_int(params["SESSION_TERM_NEEDS_BLANK"]) == SESSION_TERM_NEEDS_BLANK
    assert sv_int(params["SESSION_TERM_LOCKED"]) == SESSION_TERM_LOCKED
    assert sv_int(params["SESSION_STATUS_STATE_LSB"]) == SESSION_STATUS_STATE_LSB
    assert sv_int(params["SESSION_STATUS_ERR_LSB"]) == SESSION_STATUS_ERR_LSB
    assert sv_int(params["RX_BUF_MAX_DEPTH"]) == RX_BUF_MAX_DEPTH


def test_ebi_tiny_uses_the_package_window_size() -> None:
    """The RTL must derive its page split from ebi_pkg (not a second copy)."""
    text = EBI_TINY_SV.read_text(encoding="utf-8")
    assert "WIN_ADDR_LSB = $clog2(ebi_pkg::EBI_WINDOW_BYTES)" in text
    assert "4 + NUM_REGIONS" in text  # NUM_WINDOWS definition


def test_reported_rx_buf_ctrl_discrepancy_is_still_where_we_reported_it() -> None:
    """Drift guard for the reported spec-vs-implementation discrepancy.

    The register face hardwires ``wr_ptr`` to 0 (it has no rx_buf — spec §1 defers
    the device-side buffer to v0.1), while the mFSM face returns the live
    ``{wr_ptr, depth}`` the spec's RW offset implies. If the register face ever
    grows an rx_buf, this test fails so the shadowing in mfsm_top gets revisited
    instead of silently drifting.
    """
    text = EMRI_REGFILE_SV.read_text(encoding="utf-8")
    assert "R_RX_BUF_CTRL:    host_rdata_o = {16'h0, rx_buf_depth_w};" in text


def test_emri_regfile_exists_at_the_expected_path() -> None:
    assert EMRI_PKG_SV.exists() and EMRI_REGFILE_SV.exists()
    assert EBI_PKG_SV.exists() and EBI_TINY_SV.exists() and MFSM_PKG_SV.exists()
    assert isinstance(Path(EBI_TINY_SV), Path)
