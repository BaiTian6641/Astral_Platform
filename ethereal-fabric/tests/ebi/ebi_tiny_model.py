# SPDX-License-Identifier: MIT
"""Golden reference model for EBI-Tiny (``ethereal-shell/rtl/ebi/ebi_tiny.sv``)
and the mFSM register/session surface (tasks E0-SHL1 + E2-BMC1).

This model mirrors, bit-for-bit, three things a small-device (Profile-E) Shell
turns into hardware:

1. **The EBI-Tiny address map decoder** (``ebi_pkg`` + ``ebi_tiny.sv``): one
   64 KiB page per window, in the order the decoder publishes
   (``shell_csr, occ, region0..region{N-1}, service, io``), with the blueprint's
   bases (``docs/Ethereal-平台实施蓝图-v2.md`` §4.2). An address inside no window —
   including a region page ``>= NUM_REGIONS``, a window that does not exist — is
   an ERROR response, never a hang.

2. **The EMRI register map** as the mFSM exposes it (``emri-v0.md`` §2): offsets,
   access classes and which entries are mode-dependent. The one contract the
   whole BMC/mFSM split rests on is asserted here: **exactly one field differs
   between the two implementations** — ``CAPABILITIES.has_bmc`` (spec §1
   principle 1).

3. **The §5 mFSM session FSM**: the 5 states, the host command edges, the OCC
   terminal class map and the ``SESSION_STATUS`` word layout. The terminal latch
   is modelled too, because it is what makes the spec's edges race-free: an OCC
   terminal that arrives *before* ``occ_go`` must still complete the session.

The pytest suite (``test_ebi_tiny_model.py``) validates this model against an
INDEPENDENT range-based oracle and — the part that catches real drift — against
the constants actually declared in the SystemVerilog packages, so an offset that
changes on one side and not the other fails here instead of in silicon.

Deliberate divergences from the prose (all reported by E2-BMC1, see the task
report; none invented):

* ``SESSION_STATUS`` is ``{err[7:4], state[3:0]}``. The §2 table writes
  ``{state[3:0], done[4], err[7:4]}``, which overlaps: ``done`` at bit 4 is
  inside ``err[7:4]`` (4+1+4 = 9 bits in an 8-bit register) and §5 defines no
  ``done`` semantics. §5's prose (state + err[7:4]) is implemented, so err codes
  1/3 set bit 4 by definition.
* ``err=1 bad_crc`` has no v0 producer: §5's own G6 resolution puts Ed25519+CRC32
  on the host, so the mFSM never computes a CRC to fail. The code stays reserved.
* ``NEEDS_BLANK`` (the E0-FAB5 dirty gate) maps to ``err=3 occ_error``: §5 defines
  no code for it and leaving the FSM in ``OCC_GO`` forever would be a hang, so the
  refusal is reported through the generic OCC error rather than inventing a code.
* ``RX_BUF_CTRL`` exists as specified (``{wr_ptr[31:16], depth[15:0]}``, §2), but
  v0 has no device-side rx_buf (§1 defers it to v0.1), so the buffer is the
  host-served push stream: ``wr_ptr`` is host-rebased and hardware-advanced per
  accepted push, and "full" is ``depth != 0 and wr_ptr >= depth``.
"""
from __future__ import annotations

import random
import re
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Repo locations (resolved from this file: <root>/ethereal-fabric/tests/ebi/…)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[3]
EBI_PKG_SV = REPO_ROOT / "ethereal-shell/rtl/ebi/ebi_pkg.sv"
EBI_TINY_SV = REPO_ROOT / "ethereal-shell/rtl/ebi/ebi_tiny.sv"
EMRI_PKG_SV = REPO_ROOT / "ethereal-shell/rtl/emri/emri_pkg.sv"
EMRI_REGFILE_SV = REPO_ROOT / "ethereal-shell/rtl/emri/emri_regfile.sv"
MFSM_PKG_SV = REPO_ROOT / "ethereal-shell/rtl/mfsm/mfsm_pkg.sv"

# ---------------------------------------------------------------------------
# EBI-Tiny window map (ebi_pkg + blueprint §4.2)
# ---------------------------------------------------------------------------
WINDOW_BYTES = 0x0001_0000  # one 64 KiB page per window

SHELL_CSR_BASE = 0x0000_0000
OCC_BASE = 0x0001_0000
REGION_BASE = 0x0010_0000
SERVICE_BASE = 0x0020_0000
IO_BASE = 0x0030_0000

# The region page range is [REGION_BASE, REGION_BASE + MAX_REGIONS); a page in it
# that is >= NUM_REGIONS is an unimplemented window (error). The ceiling keeps the
# region range clear of SERVICE_BASE.
MAX_REGIONS = 16

WIN_SHELL_CSR = 0
WIN_OCC = 1
WIN_REGION0 = 2

EMRI_MAGIC = 0x4554_4852  # "ETHR"
EMRI_ABI_VERSION = 0x0000_0000
CAPB_HAS_BMC = 0  # CAPABILITIES bit 0


def num_windows(num_regions: int = 2) -> int:
    """Window count: shell, occ, NUM_REGIONS regions, service, io."""
    return 4 + num_regions


def win_region(num_regions: int, region: int) -> int:
    del num_regions  # index order is region-major from WIN_REGION0
    return WIN_REGION0 + region


def win_service(num_regions: int = 2) -> int:
    return WIN_REGION0 + num_regions


def win_io(num_regions: int = 2) -> int:
    return win_service(num_regions) + 1


def window_base(num_regions: int, window: int) -> int:
    """Byte base of a window index (matches the decode order in ebi_tiny.sv)."""
    if window == WIN_SHELL_CSR:
        return SHELL_CSR_BASE
    if window == WIN_OCC:
        return OCC_BASE
    if WIN_REGION0 <= window < WIN_REGION0 + num_regions:
        return REGION_BASE + (window - WIN_REGION0) * WINDOW_BYTES
    if window == win_service(num_regions):
        return SERVICE_BASE
    if window == win_io(num_regions):
        return IO_BASE
    raise ValueError(f"window index {window} outside 0..{num_windows(num_regions) - 1}")


@dataclass(frozen=True)
class Decode:
    """Decoder result: ``valid`` false means the bus answers ready + err."""

    valid: bool
    window: int  # selected window index; -1 when invalid
    offset: int  # intra-window byte offset (low 16 address bits)


def decode(addr: int, num_regions: int = 2) -> Decode:
    """Mirror of ``ebi_tiny``'s combinational decode.

    The fixed windows (shell/occ/service/io) are matched on their page FIRST, then
    the region range — the same precedence as the RTL ``case``, so a hypothetical
    NUM_REGIONS > MAX_REGIONS could not shadow the Service Tile page.
    """
    page = (addr >> 16) & 0xFFFF
    offset = addr & 0xFFFF

    if page == (SHELL_CSR_BASE >> 16):
        return Decode(True, WIN_SHELL_CSR, offset)
    if page == (OCC_BASE >> 16):
        return Decode(True, WIN_OCC, offset)
    if page == (SERVICE_BASE >> 16):
        return Decode(True, win_service(num_regions), offset)
    if page == (IO_BASE >> 16):
        return Decode(True, win_io(num_regions), offset)

    region_page = REGION_BASE >> 16
    if region_page <= page < region_page + MAX_REGIONS:
        if (page - region_page) < num_regions:
            return Decode(True, WIN_REGION0 + (page - region_page), offset)
        # Inside the region page range but no such region exists.
        return Decode(False, -1, offset)

    return Decode(False, -1, offset)


def naive_windows(addr: int, num_regions: int = 2) -> list[int]:
    """Independent oracle: every window whose byte range contains ``addr``.

    Built from window ranges only (no page math), so it cross-checks
    :func:`decode` from the other direction. Length 0 => unmapped, 1 => the
    selected window.
    """
    hits = []
    for w in range(num_windows(num_regions)):
        base = window_base(num_regions, w)
        if base <= addr < base + WINDOW_BYTES:
            hits.append(w)
    return hits


# ---------------------------------------------------------------------------
# EMRI register map (emri-v0.md §2, v0.8) — the mFSM/BMC face
# ---------------------------------------------------------------------------
# access classes: 'ro' read-only, 'rw' read/write, 'w' write-only (reads 0),
# 'rwv' = read/write with a W1C/command flavour documented in the spec.
@dataclass(frozen=True)
class Reg:
    name: str
    offset: int
    access: str
    mode_dependent: bool = False  # value differs between BMC and mFSM modes


EMRI_MAP: tuple[Reg, ...] = (
    Reg("MAGIC", 0x00, "ro"),
    Reg("ABI_VERSION", 0x01, "ro"),
    Reg("CAPABILITIES", 0x02, "ro", mode_dependent=True),
    Reg("PLATFORM_ID", 0x03, "ro"),
    Reg("NUM_REGIONS", 0x04, "ro"),
    Reg("REGION_INFO", 0x05, "ro"),
    Reg("REGION_SEL", 0x06, "rw"),
    Reg("OCC_CMD", 0x08, "rw"),
    Reg("OCC_WDATA", 0x09, "w"),
    Reg("OCC_STATUS", 0x0A, "ro"),
    Reg("OCC_FRAME_ADDR", 0x0B, "rw"),
    Reg("OCC_WORD_COUNT", 0x0C, "rw"),
    Reg("OCC_DECODE", 0x0D, "w"),
    Reg("OCC_EXPECT_CRC", 0x0E, "rw"),
    Reg("OCC_CRC_RESULT", 0x0F, "ro"),
    Reg("SESSION_CMD", 0x10, "rw"),
    Reg("SESSION_STATUS", 0x11, "ro"),
    Reg("RX_BUF_CTRL", 0x12, "rw"),
    Reg("EFP_CMD", 0x13, "w"),
    Reg("EFP_REGION", 0x14, "rw"),
    Reg("EFP_IMG_WORDS", 0x15, "rw"),
    Reg("EFP_STATUS", 0x16, "rw"),
    Reg("EFP_ERR", 0x17, "rw"),
    Reg("IMG_DIGEST", 0x18, "rw"),  # 0x18..0x1F (8 words)
    Reg("HEALTH_STATUS", 0x20, "ro"),
    Reg("EFP_IMG_COLS", 0x21, "rw"),
    Reg("CAP_DECL_IO", 0x22, "rw"),
    Reg("CAP_DECL_SVC", 0x23, "rw"),
    Reg("CAP_STATUS", 0x24, "ro"),
    Reg("CTX_CMD", 0x26, "w"),
    Reg("CTX_WORDS", 0x27, "rw"),
    Reg("CTX_STATUS", 0x28, "ro"),
    Reg("LKM_STATUS", 0x29, "ro"),
    Reg("LKM_CMD", 0x2A, "w"),
    Reg("MON_TEMP", 0x30, "ro"),
    Reg("MON_VCCINT", 0x31, "ro"),
    Reg("MON_RECFG_COUNT", 0x32, "ro"),
    Reg("MON_WDT_COUNT", 0x33, "ro"),
    Reg("MON_ANOM_STATUS", 0x34, "rwv"),
    Reg("MON_ANOM_WINDOW", 0x35, "rw"),
    Reg("MON_ANOM_THRESH", 0x36, "rw"),
    Reg("MON_NOTIFY", 0x37, "w"),
    Reg("EVT_LOG_CTRL", 0x38, "rwv"),
    Reg("EVT_LOG_DATA", 0x39, "rw"),
    Reg("SPI_CRC", 0x3F, "w"),
    Reg("IMG_SIG", 0x50, "rw"),  # 0x50..0x5F (16 words)
)

# Reserved offsets after the v0.8 allocations (spec §2 "Reserved ranges").
RESERVED_OFFSETS: frozenset[int] = frozenset(
    [0x07] + list(range(0x2B, 0x30)) + list(range(0x3A, 0x3F)) + list(range(0x60, 0x100))
)

# The ABI-parity contract: which map entries may differ between the two modes.
MODE_DEPENDENT_FIELDS: frozenset[str] = frozenset(
    r.name for r in EMRI_MAP if r.mode_dependent
)


def registers_read_zero(offset: int) -> bool:
    """Reserved/unallocated word offsets read as 0 and ignore writes (spec §2)."""
    return offset in RESERVED_OFFSETS or all(r.offset != offset for r in EMRI_MAP)


# ---------------------------------------------------------------------------
# mFSM session FSM (emri-v0.md §2 offsets 0x10/0x11 + §5)
# ---------------------------------------------------------------------------
SESSION_CMD_NOP = 0
SESSION_CMD_BEGIN_RX = 1
SESSION_CMD_VERIFY = 2
SESSION_CMD_OCC_GO = 3
SESSION_CMD_ABORT = 4

SESSION_S_IDLE = 0
SESSION_S_RX = 1
SESSION_S_VERIFY = 2
SESSION_S_OCC_GO = 3
SESSION_S_ERROR = 4
SESSION_STATES = 5

SESSION_ERR_NONE = 0
SESSION_ERR_BAD_CRC = 1  # reserved: no v0 producer
SESSION_ERR_OCC_LOCKED = 2
SESSION_ERR_OCC_ERROR = 3

SESSION_TERM_DONE = 0
SESSION_TERM_ERROR = 1
SESSION_TERM_NEEDS_BLANK = 2
SESSION_TERM_LOCKED = 3

SESSION_STATUS_STATE_LSB = 0
SESSION_STATUS_ERR_LSB = 4

RX_BUF_MAX_DEPTH = 0x4000  # 16 KiB (spec §2 offset 0x12, "v0: depth ≤ 16KB")


def session_status_word(state: int, err: int) -> int:
    """``{err[7:4], state[3:0]}`` — see the module docstring's first divergence."""
    return ((err & 0xF) << SESSION_STATUS_ERR_LSB) | ((state & 0xF) << SESSION_STATUS_STATE_LSB)


class SessionFSM:
    """Golden model of ``mfsm_session`` (spec §5 edges + the terminal latch)."""

    def __init__(self, rx_depth: int = RX_BUF_MAX_DEPTH) -> None:
        self.state = SESSION_S_IDLE
        self.err = SESSION_ERR_NONE
        self.rx_depth = rx_depth
        self.rx_wr_ptr = 0
        self.term_latched: int | None = None  # first terminal of a live session

    # -- observable ---------------------------------------------------------
    @property
    def status(self) -> int:
        return session_status_word(self.state, self.err)

    @property
    def rx_full(self) -> bool:
        return self.rx_depth != 0 and self.rx_wr_ptr >= self.rx_depth

    # -- stimulus -----------------------------------------------------------
    def rx_push(self) -> None:
        """An accepted image-word push (a write to OCC_WDATA)."""
        self.rx_wr_ptr = (self.rx_wr_ptr + 1) & 0xFFFF

    def rx_rebase(self, *, depth: int, wr_ptr: int) -> None:
        """A host RX_BUF_CTRL write (both fields are RW per spec §2)."""
        self.rx_depth = depth & 0xFFFF
        self.rx_wr_ptr = wr_ptr & 0xFFFF

    def step(
        self,
        cmd: int = SESSION_CMD_NOP,
        occ_terminal: int | None = None,
    ) -> None:
        """One clock of the FSM (``occ_terminal`` = a terminal class this cycle)."""
        consume = self.state == SESSION_S_OCC_GO and (
            self.term_latched is not None or occ_terminal is not None
        )
        code = self.term_latched if self.term_latched is not None else occ_terminal

        if cmd == SESSION_CMD_BEGIN_RX and self.state == SESSION_S_IDLE:
            self.state = SESSION_S_RX
        elif self.state == SESSION_S_RX:
            if cmd == SESSION_CMD_ABORT:
                self.state = SESSION_S_IDLE
            elif cmd == SESSION_CMD_VERIFY or self.rx_full:
                self.state = SESSION_S_VERIFY
        elif self.state == SESSION_S_VERIFY:
            if cmd == SESSION_CMD_ABORT:
                self.state = SESSION_S_IDLE
            elif cmd == SESSION_CMD_OCC_GO:
                self.state = SESSION_S_OCC_GO
        elif self.state == SESSION_S_OCC_GO and consume:
            if code == SESSION_TERM_DONE:
                self.state = SESSION_S_IDLE
                self.err = SESSION_ERR_NONE
            else:
                self.state = SESSION_S_ERROR
                self.err = (
                    SESSION_ERR_OCC_LOCKED if code == SESSION_TERM_LOCKED else SESSION_ERR_OCC_ERROR
                )
        elif self.state == SESSION_S_ERROR and cmd == SESSION_CMD_ABORT:
            self.state = SESSION_S_IDLE

        if cmd in (SESSION_CMD_BEGIN_RX, SESSION_CMD_ABORT):
            self.err = SESSION_ERR_NONE

        # terminal latch: begin_rx and consumption clear it; otherwise first wins
        if cmd == SESSION_CMD_BEGIN_RX or consume:
            self.term_latched = None
        elif occ_terminal is not None:
            self.term_latched = occ_terminal

        # rx accounting
        if cmd == SESSION_CMD_BEGIN_RX:
            self.rx_wr_ptr = 0


# ---------------------------------------------------------------------------
# SystemVerilog constant cross-check (the drift guard)
# ---------------------------------------------------------------------------
def sv_localparams(path: Path) -> dict[str, str]:
    """Extract ``localparam <type> NAME = <value>;`` from a SystemVerilog package.

    Returns the raw right-hand side text per name, so the caller can decide how to
    interpret it (integer, sized literal like ``16'h10``, or an expression).
    """
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"localparam\s+(?:logic\s*\[[^\]]*\]\s*|int\s+(?:unsigned\s+)?|bit\s+)?"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;,]+?)\s*;"
    )
    return {m.group(1): m.group(2) for m in pattern.finditer(text)}


def sv_int(value: str) -> int:
    """Interpret a SystemVerilog integer literal (``32'h0000_0000``, ``8'd3``, ``4096``)."""
    text = value.strip().replace("_", "")
    m = re.fullmatch(r"(?:(\d+)'([hdbo]))?([0-9A-Fa-f]+)", text)
    if not m:
        raise ValueError(f"not a plain integer literal: {value!r}")
    base = {"h": 16, "d": 10, "b": 2, "o": 8}[(m.group(2) or "d")]
    return int(m.group(3), base)


def random_addresses(count: int, seed: int = 0xE1B7) -> list[int]:
    """Deterministic address sample: 32-bit, seeded (a failure is re-playable)."""
    rng = random.Random(seed)
    return [rng.getrandbits(32) for _ in range(count)]
