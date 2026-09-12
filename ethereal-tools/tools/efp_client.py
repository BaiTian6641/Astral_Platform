# SPDX-License-Identifier: MIT
"""efp_client — transport-agnostic EFP session builder for ethctl (E1-RUN3).

Implements the host side of the EMRI v0.2 **EFP command block**
(``ethereal-spec/control/emri-v0.md`` sec 3.2): the host stages image metadata
(``IMG_DIGEST``/``IMG_SIG``/``EFP_IMG_WORDS``/``EFP_REGION``), rings the
``EFP_CMD`` doorbell, streams the frame words through ``OCC_WDATA`` while the
BMC daemon is in ``LOAD``, and polls ``EFP_STATUS``/``EFP_ERR``.

The client is **transport-agnostic**: instead of touching a bus directly it
emits an ordered op list (``write`` / ``read`` / ``poll`` / ``stream`` of 32-bit
EMRI word registers). The same op list can be

  * executed against :class:`EfpDaemonModel` (functional model of the regfile
    EFP block + daemon FSM + a stub OCC, with REAL Ed25519 verify) — the
    ``ethctl --transport efp`` sim path;
  * serialized to a self-describing session JSON (``ethereal.efp-session.v0``)
    via :func:`session_to_json` for SV testbench replay
    (``tb_ethctl_replay.sv`` drives the real BMC daemon RTL chain with it);
  * later, executed over a real EFP-SPI transport unchanged.

Spec rules mirrored here (sec 3.2):
  * busy-before-cmd: the host MUST read ``EFP_STATUS.busy=0`` before writing a
    new ``EFP_CMD`` — :meth:`EfpSession.cmd` always emits that poll first;
  * LOAD streaming: the host polls ``EFP_STATUS.state==LOAD`` (the daemon arms
    the OCC WRITE *before* LOAD becomes visible, so streaming may start the
    moment LOAD is observed) and then streams every frame word;
  * byte order: word ``i`` of ``IMG_DIGEST``/``IMG_SIG`` holds bytes
    ``[4i+3:4i]`` (little-endian in-word) — see :func:`words_from_bytes`;
  * ``EFP_ERR`` decoding (:func:`decode_err`);
  * E2-SEC1: HOST-SIDE Ed25519 enforcement (fail-closed) plus the
    ``capabilities.yaml`` schema + grantability pre-flight in
    :func:`load_image`, and ``CAP_DECL_IO``/``CAP_DECL_SVC`` staging before the
    doorbell (emri-v0.md sec 3.7, capabilities-v0.md sec 2);
  * OCC_FRAME_ADDR v0.6 per-column addressing (emri-v0.md sec 2):
    :func:`region_frame_base`/:func:`column_frame_base`.

Plan-Ref: ethereal-spec/control/emri-v0.md sec 3.2;
          ethereal-plan/subsystems/S08-运行时daemon与ethctl.md (E1-RUN3).
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ethimg + EMRI offsets live alongside (ethereal-tools/tools/)
_THIS_DIR = str(Path(__file__).resolve().parent)
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# pi-lens-ignore: E402
import ethimg
from emri_constants import (
    CAPB_HAS_BMC,
    EFP_CMD_ABORT,
    EFP_CMD_NOP,
    EFP_CMD_RESTART,
    EFP_CMD_RUN,
    EFP_CMD_RUN_PACKED,
    EFP_CMD_STOP,
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
    EFP_S_ALLOC,
    EFP_S_BLANK,
    EFP_S_ERROR,
    EFP_S_IDLE,
    EFP_S_LOAD,
    EFP_S_READBACK,
    EFP_S_RUNNING,
    EFP_S_STOPPED,
    EFP_S_VERIFY,
    EMRI_MAGIC,
    IMG_DIGEST_WORDS,
    IMG_SIG_WORDS,
    R_CAP_DECL_IO,
    R_CAP_DECL_SVC,
    R_CAPABILITIES,
    R_EFP_CMD,
    R_EFP_ERR,
    R_EFP_IMG_COLS,
    R_EFP_IMG_WORDS,
    R_EFP_REGION,
    R_EFP_STATUS,
    R_HEALTH_STATUS,
    R_IMG_DIGEST,
    R_IMG_SIG,
    R_MAGIC,
    R_NUM_REGIONS,
    R_OCC_FRAME_ADDR,
    R_OCC_STATUS,
    R_OCC_WDATA,
    R_OCC_WORD_COUNT,
    R_PLATFORM_ID,
    R_REGION_INFO,
    R_REGION_SEL,
    R_SPI_CRC,
    SPI_OP_OCC_PUSH,
    SPI_OP_RD,
    SPI_OP_WR,
    SPI_STAT_BAD_ADDR,
    SPI_STAT_BAD_OP,
    SPI_STAT_BUSY,
    SPI_STAT_CRC_ERR,
    SPI_STAT_NOT_READY,
    SPI_STAT_OK,
)

# capcheck (E2-SEC1) lives in the sibling ethereal-runtime/security/ package.
_SECURITY_DIR = str(Path(__file__).resolve().parents[2] / "ethereal-runtime")
if _SECURITY_DIR not in sys.path:
    sys.path.insert(0, _SECURITY_DIR)

# pi-lens-ignore: E402
from security import capcheck

SESSION_SCHEMA = "ethereal.efp-session.v0"

# EFP_STATUS bit layout (spec sec 2): {state[3:0], busy[4], done[5]}
EFP_STATUS_STATE_MASK = 0x0F
EFP_STATUS_BUSY = 0x10
EFP_STATUS_DONE = 0x20
EFP_STATUS_ALL = 0x3F
# OCC_STATUS sticky completion flag (spec sec 4 bit [3]) — the per-column
# handshake of a run_packed deploy (spec sec 3.3 step 3).
OCC_STATUS_DONE_FLAG_MASK = 0x08

EFP_STATE_NAMES = {
    EFP_S_IDLE: "IDLE",
    EFP_S_VERIFY: "VERIFY",
    EFP_S_ALLOC: "ALLOC",
    EFP_S_BLANK: "BLANK",
    EFP_S_LOAD: "LOAD",
    EFP_S_READBACK: "READBACK",
    EFP_S_RUNNING: "RUNNING",
    EFP_S_ERROR: "ERROR",
    EFP_S_STOPPED: "STOPPED",
}

EFP_ERR_NAMES = {
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

SPI_STATUS_NAMES = {
    SPI_STAT_OK: "OK",
    SPI_STAT_BAD_OP: "BAD_OP",
    SPI_STAT_BAD_ADDR: "BAD_ADDR",
    SPI_STAT_BUSY: "BUSY",
    SPI_STAT_CRC_ERR: "CRC_ERR",
    SPI_STAT_NOT_READY: "NOT_READY",  # 0xFF wire fill, spec sec 7.1
}


class EfpError(Exception):
    """EFP session build/execution failure (poll timeout, bad status, ...)."""


def decode_state(state: int) -> str:
    """Decode an ``EFP_STATUS.state`` nibble to its spec name."""
    return EFP_STATE_NAMES.get(state & 0xF, f"unknown({state & 0xF})")


def decode_err(code: int) -> str:
    """Decode a sticky ``EFP_ERR`` code (spec sec 3.2 + v0.6 codes 9-12)."""
    return EFP_ERR_NAMES.get(code & 0xFF, f"unknown({code & 0xFF})")


def decode_spi_status(code: int) -> str:
    """Decode an EFP-SPI response STATUS byte (spec sec 7 + sec 7.1)."""
    return SPI_STATUS_NAMES.get(code & 0xFF, f"unknown({code & 0xFF})")


def verify_raw_ed25519(raw_pk: bytes, digest32: bytes, sig64: bytes) -> bool:
    """Verify an Ed25519 signature over the hex-UTF-8 digest (ethimg convention).

    ``raw_pk`` is the 32-byte raw public key (the sim daemon keyring form). The
    signed message is the lowercase-hex UTF-8 of ``digest32``, identical to
    ``ethimg._sign_digest`` and the C daemon's ``eth_ed25519_verify`` (spec
    sec 3.2 step 3). Returns False for any verification failure.
    """
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import (
            Ed25519PublicKey,
        )

        Ed25519PublicKey.from_public_bytes(raw_pk).verify(
            sig64, digest32.hex().encode("utf-8")
        )
        return True
    except Exception:  # noqa: BLE001 - verify raises many error types
        return False


# --------------------------------------------------------------------------- #
# OCC frame addressing (emri-v0.md sec 2, OCC_FRAME_ADDR 0x0B v0.6)
# --------------------------------------------------------------------------- #
OCC_FRAME_WINDOW_WORDS = 0x100  # word field [7:0]: 256-word (8 KB) per column


def region_frame_base(region: int) -> int:
    """OCC_FRAME_ADDR region base: ``{region_id[15:12]}`` (v0.6)."""
    return (region & 0xF) << 12


def column_frame_base(region: int, col: int) -> int:
    """OCC_FRAME_ADDR for column ``col`` of ``region`` (v0.6).

    Layout ``{region_id[15:12], col_id[11:8], word[7:0]}``: every column owns a
    256-word (8 KB) window, so adjacent columns of a packed image never alias.
    v0.5's 16-word stride (``col << 4``) overlapped 34-68-word v2c column
    frames (E1-DMO2b). Mirrors ``column_frame_base`` in bmc-fw/daemon/daemon.c.
    """
    return region_frame_base(region) | ((col & 0xF) << 8)


def column_frame_range(region: int, col: int, words: int) -> range:
    """Word addresses ``[base, base+words)`` a column frame occupies (v0.6).

    Refuses a frame longer than the 256-word per-column window: it would spill
    into the next column's window and alias it in the OCC readback store.
    """
    if not 0 <= words <= OCC_FRAME_WINDOW_WORDS:
        raise EfpError(
            f"column frame of {words} words exceeds the "
            f"{OCC_FRAME_WINDOW_WORDS}-word OCC window (spec sec 2, v0.6)"
        )
    base = column_frame_base(region, col)
    return range(base, base + words)


# --------------------------------------------------------------------------- #
# EFP-SPI framing (spec sec 7 + sec 7.1): op list -> 7-byte wire frames
# --------------------------------------------------------------------------- #
SPI_FRAME_LEN = 7


def _spi_frame(op: int, addr: int, data: int) -> bytes:
    """One 7-byte request frame: OP | ADDR (BE16) | DATA (BE32)."""
    if not 0 <= addr <= 0xFFFF:
        raise EfpError(f"SPI frame addr {addr:#x} out of range")
    return bytes([op & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF]) + (
        data & 0xFFFFFFFF).to_bytes(4, "big")


def crc16_bytes(blob: bytes, crc: int = 0xFFFF) -> int:
    """CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, no final xor)."""
    for b in blob:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc & 0xFFFF


def crc16_words(words: list[int]) -> int:
    """CRC16 over 32-bit payload words, big-endian bytes per word — identical
    to ``frame_map.crc16`` (== the packed frame's own CRC16 tail word) and to
    the bmc-fw efp-spi front-end accumulator (spec sec 7.1 step 1)."""
    return crc16_bytes(b"".join((w & 0xFFFFFFFF).to_bytes(4, "big") for w in words))


def to_spi_frames(ops: list[Op]) -> list[bytes]:
    """Map an EFP op list to §7 7-byte SPI request frames (pure).

    * ``write`` → ``WR`` frame (``OCC_WDATA`` writes become ``OCC_PUSH``);
    * ``stream`` → one ``OCC_PUSH`` frame per word;
    * ``read``/``poll`` → ``RD`` frame (a poll re-sends its RD frame until the
      masked value matches; the frame list carries one instance, repetition is
      a link-level concern — see the sec 7.1 0xFF retry convention);
    * ``write EFP_CMD=run|run_packed`` → a ``WR SPI_CRC`` frame carrying
      ``crc16_words`` of ALL following ``stream`` words (up to the next
      ``EFP_CMD`` write or end of list) is emitted IMMEDIATELY BEFORE the
      doorbell frame (sec 7.1 step 3 ordering: latch → doorbell → stream).

    Responses are pipelined on the wire (sec 7.1): the response to frame N is
    shifted out during frame N+1; ``STATUS=0xFF`` means "not ready — retry".
    """
    frames: list[bytes] = []
    for i, op in enumerate(ops):
        if op.op == "write" and op.addr == R_EFP_CMD and op.data in (
                EFP_CMD_RUN, EFP_CMD_RUN_PACKED):
            # Lookahead: gather every stream word of this deploy session.
            stream_words: list[int] = []
            for rest in ops[i + 1:]:
                if rest.op == "write" and rest.addr == R_EFP_CMD:
                    break
                if rest.op == "stream":
                    stream_words.extend(rest.words or [])
            if stream_words:
                frames.append(_spi_frame(SPI_OP_WR, R_SPI_CRC,
                                         crc16_words(stream_words)))
        if op.op == "write":
            wire_op = (SPI_OP_OCC_PUSH if op.addr == R_OCC_WDATA else SPI_OP_WR)
            frames.append(_spi_frame(wire_op, op.addr, op.data or 0))
        elif op.op == "stream":
            for w in op.words or []:
                frames.append(_spi_frame(SPI_OP_OCC_PUSH, R_OCC_WDATA, w))
        elif op.op in ("read", "poll"):
            frames.append(_spi_frame(SPI_OP_RD, op.addr, 0))
        else:
            raise EfpError(f"to_spi_frames: unknown op {op.op!r}")
    return frames


def words_from_bytes(blob: bytes) -> list[int]:
    """Pack a byte blob into 32-bit EMRI window words (spec sec 3.2 byte order).

    Little-endian in-word, ascending word order: word ``i`` = bytes
    ``[4i+3:4i]`` — identical to a C ``memcpy`` of the byte array into the
    window on a little-endian host (what the daemon's ``verify_staged_image``
    unpacks).
    """
    if len(blob) % 4 != 0:
        raise EfpError(f"blob length {len(blob)} not a multiple of 4 bytes")
    return [int.from_bytes(blob[4 * i : 4 * i + 4], "little") for i in range(len(blob) // 4)]


# --------------------------------------------------------------------------- #
# Ops + session builder
# --------------------------------------------------------------------------- #
@dataclass
class Op:
    """One EMRI word-register operation (self-describing, JSON-serializable).

    * ``write``:  write ``data`` to word ``addr``;
    * ``read``:   read word ``addr``; if ``mask != 0`` the consumer SHOULD
      check ``(value_read & mask) == value``;
    * ``poll``:   re-read word ``addr`` until ``(value_read & mask) == value``;
    * ``stream``: write each of ``words`` to word ``addr`` in order
      (``OCC_WDATA`` frame-word stream).
    """

    op: str  # "write" | "read" | "poll" | "stream"
    addr: int  # EMRI word offset
    data: int | None = None
    mask: int | None = None
    value: int | None = None
    words: list[int] | None = None
    comment: str = ""

    def to_json(self) -> dict[str, Any]:
        # Hex strings: unambiguous word width, and trivially parseable from SV.
        d: dict[str, Any] = {"op": self.op, "addr": f"0x{self.addr:02x}"}
        if self.op == "write":
            d["data"] = f"0x{self.data or 0:08x}"
        elif self.op in ("read", "poll"):
            d["mask"] = f"0x{self.mask or 0:08x}"
            d["value"] = f"0x{self.value or 0:08x}"
        elif self.op == "stream":
            ws = self.words or []
            d["count"] = len(ws)
            d["words"] = [f"0x{w:08x}" for w in ws]
        if self.comment:
            d["comment"] = self.comment
        return d


@dataclass
class EfpSession:
    """Ordered EFP op-list builder (emri-v0.md sec 3.2 + the sec 3.7 gate)."""

    ops: list[Op] = field(default_factory=list)

    # ---- low-level op emitters ----
    def write(self, addr: int, data: int, comment: str = "") -> None:
        self.ops.append(Op("write", addr, data=data, comment=comment))

    def read(self, addr: int, mask: int = 0, value: int = 0, comment: str = "") -> None:
        self.ops.append(Op("read", addr, mask=mask, value=value, comment=comment))

    def poll(self, addr: int, mask: int, value: int, comment: str = "") -> None:
        self.ops.append(Op("poll", addr, mask=mask, value=value, comment=comment))

    # ---- spec sec 3.2 primitives ----
    def stage_image(self, digest32: bytes, sig64: bytes, words: int, region: int) -> None:
        """Stage IMG_DIGEST + IMG_SIG + EFP_IMG_WORDS + EFP_REGION (step 1)."""
        if len(digest32) != 4 * IMG_DIGEST_WORDS:
            raise EfpError(f"digest must be {4 * IMG_DIGEST_WORDS} bytes")
        if len(sig64) != 4 * IMG_SIG_WORDS:
            raise EfpError(f"signature must be {4 * IMG_SIG_WORDS} bytes")
        if not 0 < words <= 0xFFFF:
            raise EfpError(f"image word count {words} out of range")
        if not 0 <= region <= 0xFF:
            raise EfpError(f"region {region} out of range")
        for i, w in enumerate(words_from_bytes(digest32)):
            self.write(R_IMG_DIGEST + i, w, f"IMG_DIGEST[{i}]")
        for i, w in enumerate(words_from_bytes(sig64)):
            self.write(R_IMG_SIG + i, w, f"IMG_SIG[{i}]")
        self.write(R_EFP_IMG_WORDS, words, "EFP_IMG_WORDS")
        self.write(R_EFP_REGION, region, "EFP_REGION")

    def poll_status(self, mask: int = EFP_STATUS_BUSY, value: int = 0, comment: str = "") -> None:
        self.poll(R_EFP_STATUS, mask, value, comment or "poll EFP_STATUS")

    def stage_capabilities(self, decl_io: int, decl_svc: int) -> None:
        """Stage the declared capability bitmaps (EMRI v0.6 sec 3.7).

        ``CAP_DECL_IO``/``CAP_DECL_SVC`` are the host's declaration; the daemon
        binds them against what the allocated region can expose (post-ALLOC /
        pre-BLANK). Written before the ``EFP_CMD`` doorbell.
        """
        if not 0 <= decl_io <= 0xFFFF_FFFF or not 0 <= decl_svc <= 0xFFFF_FFFF:
            raise EfpError("capability bitmaps must be 32-bit")
        self.write(R_CAP_DECL_IO, decl_io, "CAP_DECL_IO")
        self.write(R_CAP_DECL_SVC, decl_svc, "CAP_DECL_SVC")

    def cmd(self, code: int, comment: str = "") -> None:
        """Ring the doorbell — ALWAYS after a busy=0 poll (spec sec 3.2: the
        host MUST wait for busy=0 before writing a new EFP_CMD)."""
        if not 0 <= code <= EFP_CMD_RUN_PACKED:
            raise EfpError(f"bad EFP command code {code}")
        self.poll_status(EFP_STATUS_BUSY, 0, "wait busy=0 (single outstanding command)")
        self.write(R_EFP_CMD, code, comment or f"EFP_CMD={code}")

    def stream(self, words: list[int], comment: str = "") -> None:
        """Stream the frame words through OCC_WDATA (spec step 5: the host
        streams while the daemon is in LOAD supervising OCC_STATUS)."""
        if not words:
            raise EfpError("no frame words to stream")
        self.ops.append(Op("stream", R_OCC_WDATA, words=list(words),
                           comment=comment or f"stream {len(words)} frame words"))

    # ---- composite helpers ----
    def cmd_and_wait(self, code: int, *, expect_state: int, expect_done: bool,
                     comment: str = "") -> None:
        """cmd + wait for the TERMINAL state + status/error self-checks.

        Waits for ``state==expect_state AND busy=0`` in one poll (mask 0x1F).
        A bare busy=0 poll would race: between the doorbell write and the
        daemon's accept, busy is still 0 from the PREVIOUS command, so the
        poll can match the stale idle window (observed on RTL: stop's busy=0
        poll matched before the daemon accepted, and the status read then
        returned the pre-stop RUNNING value)."""
        self.cmd(code, comment)
        self.poll_status(EFP_STATUS_STATE_MASK | EFP_STATUS_BUSY, expect_state,
                         f"wait state={decode_state(expect_state)} (busy=0)")
        want = expect_state | (EFP_STATUS_DONE if expect_done else 0)
        self.read(R_EFP_STATUS, EFP_STATUS_ALL, want,
                  f"expect state={decode_state(expect_state)}"
                  f"{' done' if expect_done else ''}")
        self.read(R_EFP_ERR, 0xFF, EFP_ERR_NONE, "expect EFP_ERR=none")

    def run(self, digest32: bytes, sig64: bytes, frame_words: list[int],
            region: int, *, decl_io: int = 0, decl_svc: int = 0) -> None:
        """Full run sequence (spec sec 3.2 run steps 1-6)."""
        self.stage_image(digest32, sig64, len(frame_words), region)
        self.stage_capabilities(decl_io, decl_svc)
        self.cmd(EFP_CMD_RUN, "EFP_CMD=run")
        self.poll_status(EFP_STATUS_STATE_MASK, EFP_S_LOAD,
                         "wait state=LOAD (OCC WRITE armed)")
        self.stream(frame_words)
        # Post-stream the daemon is continuously busy (LOAD->READBACK->
        # RUNNING), so a terminal-state poll cannot match a stale window.
        self.poll_status(EFP_STATUS_STATE_MASK | EFP_STATUS_BUSY, EFP_S_RUNNING,
                         "wait state=RUNNING (busy=0, READBACK done)")
        self.read(R_EFP_STATUS, EFP_STATUS_ALL,
                  EFP_S_RUNNING | EFP_STATUS_DONE, "expect RUNNING + done")
        self.read(R_EFP_ERR, 0xFF, EFP_ERR_NONE, "expect EFP_ERR=none")

    def run_packed(self, digest32: bytes, sig64: bytes,
                   columns: list[list[int]], region: int, *,
                   decl_io: int = 0, decl_svc: int = 0) -> None:
        """Full run_packed sequence (spec sec 3.3, v0.3).

        ``columns`` is the image as a list of per-column DATA word lists
        (frame_map packed format, CRC16 tail excluded; v0 homogeneous: every
        column the same length — staged as ``EFP_IMG_WORDS``). Per column the
        daemon BLANKs (up front), then pulses OCC_DECODE + arms WRITE; the
        host streams that column's DATA words gated on the done_flag
        handshake (sec 3.3 step 3):

        * column 0: poll ``state==LOAD`` (the daemon arms WRITE *before* LOAD
          becomes visible, so streaming may start the moment LOAD shows);
        * column c>0: poll ``done_flag==1`` (column c-1 WRITE complete), then
          ``done_flag==0`` (column c armed — arming clears the sticky flag),
          then confirm ``state==LOAD``;
        * after the last column: poll the terminal ``RUNNING + busy=0``.
        """
        if not columns:
            raise EfpError("run_packed: no columns")
        words = len(columns[0])
        for c, col in enumerate(columns):
            if len(col) != words:
                raise EfpError(
                    f"run_packed: column {c} has {len(col)} words, expected "
                    f"{words} (v0 homogeneous)"
                )
        if not 0 < len(columns) <= 0xFF:
            raise EfpError(f"run_packed: column count {len(columns)} out of range")
        self.stage_image(digest32, sig64, words, region)
        self.write(R_EFP_IMG_COLS, len(columns), "EFP_IMG_COLS")
        self.stage_capabilities(decl_io, decl_svc)
        self.cmd(EFP_CMD_RUN_PACKED, "EFP_CMD=run_packed")
        for c, col_words in enumerate(columns):
            if c > 0:
                self.poll(R_OCC_STATUS, OCC_STATUS_DONE_FLAG_MASK,
                          OCC_STATUS_DONE_FLAG_MASK,
                          f"wait WRITE col {c - 1} done (sticky done_flag)")
                self.poll(R_OCC_STATUS, OCC_STATUS_DONE_FLAG_MASK, 0,
                          f"wait WRITE col {c} armed (done_flag cleared)")
            self.poll_status(EFP_STATUS_STATE_MASK, EFP_S_LOAD,
                             f"wait state=LOAD (col {c} WRITE armed)")
            self.stream(list(col_words), f"stream col {c} DATA words")
        # Post-stream the daemon is continuously busy (LOAD->READBACK->
        # RUNNING), so a terminal-state poll cannot match a stale window.
        self.poll_status(EFP_STATUS_STATE_MASK | EFP_STATUS_BUSY, EFP_S_RUNNING,
                         "wait state=RUNNING (busy=0, READBACK done)")
        self.read(R_EFP_STATUS, EFP_STATUS_ALL,
                  EFP_S_RUNNING | EFP_STATUS_DONE, "expect RUNNING + done")
        self.read(R_EFP_ERR, 0xFF, EFP_ERR_NONE, "expect EFP_ERR=none")

    def stop(self, region: int) -> None:
        """stop: BLANK the region -> STOPPED, region FREE (spec sec 3.2)."""
        if not 0 <= region < EFP_REGION_AUTO:
            raise EfpError(f"region {region} out of range")
        self.write(R_EFP_REGION, region, "EFP_REGION (stop target)")
        self.cmd_and_wait(EFP_CMD_STOP, expect_state=EFP_S_STOPPED,
                          expect_done=False, comment="EFP_CMD=stop")

    def restart(self, frame_words: list[int]) -> None:
        """restart: stop + re-run with the last staged metadata (spec sec 3.2).

        The digest/sig/words are retained in the window registers; the host
        only re-streams the frame words during the new LOAD phase.
        """
        self.cmd(EFP_CMD_RESTART, "EFP_CMD=restart")
        self.poll_status(EFP_STATUS_STATE_MASK, EFP_S_LOAD,
                         "wait state=LOAD (re-run)")
        self.stream(frame_words, "re-stream frame words")
        self.poll_status(EFP_STATUS_STATE_MASK | EFP_STATUS_BUSY, EFP_S_RUNNING,
                         "wait state=RUNNING (busy=0, READBACK done)")
        self.read(R_EFP_STATUS, EFP_STATUS_ALL,
                  EFP_S_RUNNING | EFP_STATUS_DONE, "expect RUNNING + done")
        self.read(R_EFP_ERR, 0xFF, EFP_ERR_NONE, "expect EFP_ERR=none")

    def abort(self) -> None:
        """abort: best-effort BLANK -> IDLE (spec sec 3.2)."""
        self.cmd_and_wait(EFP_CMD_ABORT, expect_state=EFP_S_IDLE,
                          expect_done=False, comment="EFP_CMD=abort")

    def ps(self, num_regions: int = 2) -> None:
        """ps is a pure read (spec sec 3.2): no EFP_CMD needed."""
        self.read(R_EFP_STATUS, comment="daemon state/busy/done")
        self.read(R_EFP_ERR, comment="sticky last-error")
        for i in range(num_regions):
            self.write(R_REGION_SEL, i, f"REGION_SEL={i}")
            self.read(R_REGION_INFO, comment=f"REGION_INFO[{i}]")


# --------------------------------------------------------------------------- #
# .eth image extraction (ethimg v0.1 tar format)
# --------------------------------------------------------------------------- #
@dataclass
class StagedImage:
    """Everything the EFP mailbox needs from a .eth image."""

    name: str
    digest32: bytes  # 32-byte manifest digest
    sig64: bytes  # 64-byte Ed25519 signature (zeros if unsigned)
    frame_words: list[int]
    manifest_digest_hex: str
    signed: bool
    caps: capcheck.Capabilities  # parsed+schema-checked capabilities.yaml
    decl_io: int  # CAP_DECL_IO bitmap (EMRI v0.6 sec 3.7)
    decl_svc: int  # CAP_DECL_SVC bitmap


def load_image(
    eth_path: Path,
    *,
    trusted_pk: bytes | None = None,
    allow_unsigned: bool = False,
    allowed_io_mask: int = capcheck.SIM_ALLOWED_IO_MASK,
    allowed_svc_mask: int = capcheck.SIM_ALLOWED_SVC_MASK,
) -> StagedImage:
    """Unpack a .eth: integrity, host-side signature, then EFP staging data.

    E2-SEC1 makes this path **fail-closed**: the manifest Ed25519 signature is
    verified host-side by default. ``trusted_pk`` is the raw 32-byte Ed25519
    public key and is REQUIRED for a signed image unless the caller explicitly
    opts out with ``allow_unsigned=True``; unsigned images are likewise
    rejected without that flag. The BMC daemon still re-verifies in VERIFY
    (spec sec 3.2 step 3) — this is defence in depth, not a replacement.

    The ``capabilities.yaml`` member is parsed + schema-checked
    (capabilities-v0.md sec 1) and pre-flighted for grantability (sec 2
    stage 2) against the platform inventory masks, so an over-declared image
    never reaches a deploy command.

    Raises ``ethimg.IntegrityError``/``ethimg.SignatureError``,
    ``capcheck.CapabilitySchemaError``/``CapabilityDenied``, or ``EfpError``.
    """
    eth_path = Path(eth_path)
    man, members = ethimg._read_members(eth_path)
    # integrity: every declared member present + digest matches, no smuggled
    # members, manifest_digest self-consistent (same checks as ethimg.verify
    # steps 1-3).
    for mname, dig in man.members.items():
        if mname not in members:
            raise ethimg.IntegrityError(f"missing member: {mname}")
        if ethimg._sha256(members[mname]) != dig:
            raise ethimg.IntegrityError(f"member digest mismatch: {mname}")
    for mname in members:
        if mname not in man.members:
            raise ethimg.IntegrityError(f"undeclared member (smuggle?): {mname}")
    if ethimg._manifest_digest(man.to_dict()) != man.manifest_digest:
        raise ethimg.IntegrityError(f"{eth_path}: manifest_digest mismatch")

    frames_member = f"targets/{man.target}.frames"
    if frames_member not in members:
        raise EfpError(f"{eth_path}: missing {frames_member}")
    frames_bytes = members[frames_member]
    if len(frames_bytes) % 4 != 0 or not frames_bytes:
        raise EfpError(f"{eth_path}: frames length {len(frames_bytes)} not a "
                       "positive multiple of 4 bytes")
    frame_words = [
        struct.unpack_from("<I", frames_bytes, i)[0]
        for i in range(0, len(frames_bytes), 4)
    ]

    digest32 = bytes.fromhex(man.manifest_digest)

    # capabilities.yaml stage-1 schema: a CONTENT check, run before the trust
    # gate (identical to ethimg.verify). An absent member is the empty set
    # (capabilities-v0.md sec 1 rule 3); `allow_unsigned` never relaxes it.
    caps_blob = members.get("capabilities.yaml")
    try:
        caps = (
            capcheck.Capabilities()
            if caps_blob is None
            else capcheck.load_capabilities(caps_blob.decode("utf-8"))
        )
    except UnicodeDecodeError as e:
        raise capcheck.CapabilitySchemaError(
            f"{eth_path}: capabilities.yaml is not UTF-8: {e}"
        ) from e

    # signature: HOST-SIDE Ed25519 enforcement (E2-SEC1), fail-closed. The
    # daemon re-verifies in VERIFY (spec sec 3.2 step 3); this is defence in
    # depth so an unverified image never reaches a deploy command.
    if man.signature is None:
        if not allow_unsigned:
            raise ethimg.SignatureError(
                f"{eth_path}: unsigned image (pass allow_unsigned=True for dev)"
            )
        # unsigned dev image: stage zeros; the daemon will reject (bad_sig).
        sig64 = bytes(4 * IMG_SIG_WORDS)
        signed = False
    else:
        if man.signature.get("algo") != "ed25519":
            raise EfpError(f"unsupported sig algo: {man.signature.get('algo')}")
        try:
            sig64 = bytes.fromhex(man.signature.get("value", ""))
        except ValueError as e:
            raise EfpError(f"{eth_path}: malformed signature hex: {e}") from e
        if len(sig64) != 4 * IMG_SIG_WORDS:
            raise EfpError(f"signature must be {4 * IMG_SIG_WORDS} bytes")
        signed = True
        if trusted_pk is None:
            if not allow_unsigned:
                raise ethimg.SignatureError(
                    f"{eth_path}: signed but no trusted_pk supplied (pass "
                    "trusted_pk=<raw 32-byte Ed25519 key> or allow_unsigned=True)"
                )
        elif not verify_raw_ed25519(trusted_pk, digest32, sig64):
            raise ethimg.SignatureError(
                f"{eth_path}: signature did not verify against the supplied trusted_pk"
            )

    # stage-2 grantability pre-flight (after the trust gate) + EMRI v0.6
    # CAP_DECL bitmaps for staging (emri-v0.md sec 3.7).
    capcheck.validate_grantable(caps, allowed_io_mask, allowed_svc_mask)
    decl_io, decl_svc = capcheck.to_emri_bitmaps(caps)

    return StagedImage(
        name=man.name,
        digest32=digest32,
        sig64=sig64,
        frame_words=frame_words,
        manifest_digest_hex=man.manifest_digest,
        signed=signed,
        caps=caps,
        decl_io=decl_io,
        decl_svc=decl_svc,
    )


# --------------------------------------------------------------------------- #
# High-level client: .eth -> full sessions
# --------------------------------------------------------------------------- #
@dataclass
class EfpClient:
    """Builds complete EFP sessions for ethctl run/stop/ps/restart/abort."""

    num_regions: int = 2

    def run_image(
        self,
        eth_path: Path,
        region: int = EFP_REGION_AUTO,
        *,
        trusted_pk: bytes | None = None,
        allow_unsigned: bool = False,
    ) -> tuple[list[Op], StagedImage]:
        img = load_image(eth_path, trusted_pk=trusted_pk, allow_unsigned=allow_unsigned)
        s = EfpSession()
        s.run(img.digest32, img.sig64, img.frame_words, region,
              decl_io=img.decl_io, decl_svc=img.decl_svc)
        return s.ops, img

    def stop(self, region: int) -> list[Op]:
        s = EfpSession()
        s.stop(region)
        return s.ops

    def restart(
        self,
        eth_path: Path,
        *,
        trusted_pk: bytes | None = None,
        allow_unsigned: bool = False,
    ) -> tuple[list[Op], StagedImage]:
        img = load_image(eth_path, trusted_pk=trusted_pk, allow_unsigned=allow_unsigned)
        s = EfpSession()
        s.restart(img.frame_words)
        return s.ops, img

    def abort(self) -> list[Op]:
        s = EfpSession()
        s.abort()
        return s.ops

    def ps(self) -> list[Op]:
        s = EfpSession()
        s.ps(self.num_regions)
        return s.ops

    def run_packed(self, eth_path_or_frames: Path | str | list[Any],
                   region: int = EFP_REGION_AUTO, *,
                   column_words: int | None = None,
                   trusted_pk: bytes | None = None,
                   allow_unsigned: bool = False) -> tuple[list[Op], StagedImage | None]:
        """run_packed session (spec sec 3.3) from a .eth or raw frames.

        ``eth_path_or_frames``:

        * a ``.eth`` path — the frames blob holds the per-column DATA words
          concatenated (CRC16 tails excluded; the tail is a transport trailer
          the OCC never consumes). ``column_words`` (per-column DATA word
          count) is REQUIRED for this form (v0 homogeneous);
        * a list of per-column word lists — used as-is;
        * a flat list of words + ``column_words`` — split into columns.
        """
        img: StagedImage | None = None
        if isinstance(eth_path_or_frames, (str, Path)):
            img = load_image(
                Path(eth_path_or_frames), trusted_pk=trusted_pk,
                allow_unsigned=allow_unsigned,
            )
            digest32, sig64 = img.digest32, img.sig64
            flat: list[Any] = img.frame_words
        else:
            # raw frames: stage a zeroed digest/sig (unsigned dev image — the
            # daemon rejects it with bad_sig, like an unsigned .eth). Useful
            # for op-list inspection / negative tests; use a signed .eth for
            # a real deploy.
            digest32 = bytes(4 * IMG_DIGEST_WORDS)
            sig64 = bytes(4 * IMG_SIG_WORDS)
            flat = eth_path_or_frames
        if flat and isinstance(flat[0], list):
            columns = [list(c) for c in flat]
        else:
            if column_words is None or column_words <= 0:
                raise EfpError("run_packed: column_words required for flat frames")
            if len(flat) % column_words != 0:
                raise EfpError(
                    f"run_packed: {len(flat)} words not a multiple of "
                    f"column_words={column_words}"
                )
            columns = [list(flat[i:i + column_words])
                       for i in range(0, len(flat), column_words)]
        if img is not None and column_words is None:
            raise EfpError("run_packed: column_words required for a .eth image")
        if region != EFP_REGION_AUTO and not 0 <= region < self.num_regions:
            raise EfpError(f"region {region} out of range")
        if len(columns) > self.num_regions or (
            region != EFP_REGION_AUTO and region + len(columns) > self.num_regions
        ):
            raise EfpError(
                f"run_packed: {len(columns)} columns do not fit from region "
                f"{region} (v0 region->column mapping, spec sec 3.3)"
            )
        s = EfpSession()
        if img is not None:
            s.run_packed(img.digest32, img.sig64, columns, region,
                         decl_io=img.decl_io, decl_svc=img.decl_svc)
            return s.ops, img
        s.run_packed(digest32, sig64, columns, region)
        return s.ops, None


# --------------------------------------------------------------------------- #
# Session JSON (ethereal.efp-session.v0) — the SV testbench replay artifact.
# One op per line, compact separators, hex-strings for all 32-bit values: the
# TB parser keys on the literal `{"op":"` marker and scans `"0x........"`
# tokens (see tb_ethctl_replay.sv).
# --------------------------------------------------------------------------- #
def session_to_json(ops: list[Op], *, name: str, image: StagedImage | None,
                    region: int | None) -> str:
    head: dict[str, Any] = {"schema": SESSION_SCHEMA, "tool": "ethctl --transport efp",
                            "name": name}
    if image is not None:
        head["image"] = {
            "name": image.name,
            "manifest_digest": image.manifest_digest_hex,
            "words": len(image.frame_words),
            "signed": image.signed,
        }
    if region is not None:
        head["region"] = f"0x{region:02x}"
    lines = ["{"]
    items = list(head.items())
    for i, (k, v) in enumerate(items):
        lines.append(f"  {json.dumps(k)}: {json.dumps(v)},")
    lines.append(f"  \"nops\": {len(ops)},")
    lines.append('  "ops": [')
    for i, op in enumerate(ops):
        tail = "," if i < len(ops) - 1 else ""
        lines.append("    " + json.dumps(op.to_json(), separators=(",", ":")) + tail)
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


def write_session(ops: list[Op], path: Path, *, name: str,
                  image: StagedImage | None = None, region: int | None = None) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(session_to_json(ops, name=name, image=image, region=region))


# --------------------------------------------------------------------------- #
# EfpDaemonModel — functional model of the daemon-side EFP block.
# Authoritative behavior is the RTL + C daemon (tb_ethctl_replay); this model
# makes the client sequencing unit-testable without a simulator. It mirrors
# bmc-fw/daemon/daemon.c: doorbell accept/clear, busy-before-cmd squelch
# (bad_cmd), VERIFY (REAL Ed25519 against the trusted key, over the
# lowercase-hex UTF-8 of the staged digest), ALLOC (region table), mandatory
# BLANK, LOAD (host streams), READBACK, RUNNING/STOPPED/IDLE.
# --------------------------------------------------------------------------- #
class _Region:
    FREE = 0
    RUNNING = 1


@dataclass
class EfpDaemonModel:
    """In-Python model of the EMRI EFP block + BMC daemon FSM + stub OCC.

    This is the **BMC** side of the EMRI ABI: the daemon FSM lives here, so the
    identity/capability face reports ``CAPABILITIES.has_bmc=1`` (spec sec 1.1)
    -- the field ethctl auto-detects on (E1-BMC4). ``has_bmc=False`` models a
    device that answers the EFP block but is really an mFSM (no daemon), which
    the host must refuse (spec sec 3.2).
    """

    trusted_pk: bytes | None = None  # raw 32-byte Ed25519 public key
    num_regions: int = 2
    has_bmc: bool = True  # CAPABILITIES.has_bmc (spec sec 1.1/2)
    platform_id: int = 0x0000_0000
    region_infos: dict[int, int] = field(
        default_factory=lambda: {0: 0x0202_0010, 1: 0x0202_0010}
    )
    _regs: dict[int, int] = field(default_factory=dict)
    _state: int = EFP_S_IDLE
    _busy: int = 0
    _done: int = 0
    _err: int = EFP_ERR_NONE
    _regions: list[int] = field(default_factory=list)
    _region_words: list[int] = field(default_factory=list)
    _last_region: int = 0
    _last_words: int = 0
    _staged: int = 0
    _streamed: int = 0
    _squelch: bool = False  # doorbell write seen while busy
    _occ_done_flag: int = 0  # OCC_STATUS[3] sticky completion (spec sec 4)
    _cols: int = 0  # run_packed: staged EFP_IMG_COLS
    _col: int = 0  # run_packed: current column of the per-column loop
    _occ_frame_addr: int = 0  # OCC_FRAME_ADDR programmed for the current column
    _col_addrs: list[int] = field(default_factory=list)  # per-column arming trace

    def __post_init__(self) -> None:
        self._regions = [_Region.FREE] * self.num_regions
        self._region_words = [0] * self.num_regions

    # ---- register face ----
    def read(self, addr: int) -> int:
        # Identity/capability face: the SAME register map as the mFSM model
        # (emri-v0.md sec 1.1) -- only CAPABILITIES.has_bmc differs, which is
        # exactly what ethctl's session auto-detection probes (E1-BMC4).
        if addr == R_MAGIC:
            return EMRI_MAGIC
        if addr == R_CAPABILITIES:
            return (1 << CAPB_HAS_BMC) if self.has_bmc else 0
        if addr == R_PLATFORM_ID:
            return self.platform_id
        if addr == R_HEALTH_STATUS:
            return sum(1 << (8 * i) for i in range(self.num_regions))
        if addr == R_REGION_INFO:
            return self.region_infos.get(self._regs.get(R_REGION_SEL, 0) & 0xFF, 0)
        if addr == R_EFP_STATUS:
            return self._state | (self._busy << 4) | (self._done << 5)
        if addr == R_EFP_ERR:
            return self._err
        if addr == R_OCC_STATUS:
            return self._occ_done_flag << 3
        if addr == R_NUM_REGIONS:
            return self.num_regions
        return self._regs.get(addr, 0)

    # ---- raw EMRI transport surface (ethctl's Transport protocol) ---------
    def push(self, data: int) -> None:
        """OCC_WDATA push (EFP-SPI op OCC_PUSH) -- same as writing 0x09."""
        self.write(R_OCC_WDATA, data)

    def read_status(self) -> int:
        """OCC_STATUS convenience read (spec sec 4), as on the raw transport."""
        return self.read(R_OCC_STATUS)

    def write(self, addr: int, data: int) -> None:
        if addr == R_EFP_CMD:
            code = data & 0xFF
            if code == EFP_CMD_NOP:
                return
            if self._busy:
                # spec sec 3.2: a doorbell write while busy sets
                # EFP_ERR=bad_cmd and is otherwise ignored (flagged at the
                # end of the current command, like the C daemon).
                self._squelch = True
                return
            self._accept(code)
            return
        if addr == R_OCC_WDATA:
            self._push(data)
            return
        self._regs[addr] = data & 0xFFFF_FFFF

    def _push(self, data: int) -> None:
        if self._state != EFP_S_LOAD or not self._busy:
            raise EfpError("OCC_WDATA stream while daemon not in LOAD")
        self._streamed += 1  # stub OCC consumes one word per write

    # ---- doorbell ----
    def _accept(self, code: int) -> None:
        self._busy = 1
        self._done = 0
        self._err = EFP_ERR_NONE
        self._squelch = False
        self._cmd = code
        self._phase = 0
        if code == EFP_CMD_RUN or code == EFP_CMD_RUN_PACKED:
            self._state = EFP_S_VERIFY
        elif code == EFP_CMD_STOP:
            self._state = EFP_S_IDLE  # resolved on first tick
        elif code == EFP_CMD_RESTART or code == EFP_CMD_ABORT:
            self._state = EFP_S_IDLE
        else:
            self._fail(EFP_ERR_BAD_CMD)

    def _finish(self, state: int, done: int) -> None:
        self._state = state
        self._done = done
        if self._squelch and self._err == EFP_ERR_NONE:
            self._err = EFP_ERR_BAD_CMD
        self._busy = 0

    def _fail(self, err: int) -> None:
        self._err = err
        self._state = EFP_S_ERROR
        self._finish(EFP_S_ERROR, self._done)

    # ---- staged metadata helpers ----
    def _staged_blob(self, base: int, nwords: int) -> bytes:
        blob = bytearray()
        for i in range(nwords):
            blob += self._regs.get(base + i, 0).to_bytes(4, "little")
        return bytes(blob)

    def _arm_column_frame(self, region: int, col: int, words: int) -> None:
        """Program OCC_FRAME_ADDR/OCC_WORD_COUNT for one column (spec sec 2).

        Mirrors ``column_frame_base`` in bmc-fw/daemon/daemon.c: the v0.6
        layout ``{region_id[15:12], col_id[11:8], word[7:0]}`` gives every
        column its own 256-word window, so adjacent columns of a packed image
        never alias in the OCC readback store (v0.5's 16-word stride did,
        E1-DMO2b).
        """
        addr = column_frame_base(region, col)
        self._occ_frame_addr = addr
        self._col_addrs.append(addr)
        self._regs[R_OCC_FRAME_ADDR] = addr
        self._regs[R_OCC_WORD_COUNT] = words & 0xFFFF

    def _verify_staged(self) -> bool:
        digest = self._staged_blob(R_IMG_DIGEST, IMG_DIGEST_WORDS)
        sig = self._staged_blob(R_IMG_SIG, IMG_SIG_WORDS)
        if sig == bytes(4 * IMG_SIG_WORDS):
            return False  # unsigned staging: no real daemon would accept
        if self.trusted_pk is None:
            # device keyring unmodelled (no --pubkey): assume the daemon
            # trusts the signer; only zero signatures are rejected above.
            return True
        return verify_raw_ed25519(self.trusted_pk, digest, sig)

    def _alloc(self, sel: int) -> int:
        if sel == EFP_REGION_AUTO:
            for i in range(self.num_regions):
                if self._regions[i] == _Region.FREE:
                    return i
            return -1
        if sel >= self.num_regions or self._regions[sel] != _Region.FREE:
            return -1
        return sel

    # ---- FSM (one phase per tick; LOAD waits for the host stream) ----
    def tick(self) -> None:
        if not self._busy:
            return
        cmd = getattr(self, "_cmd", EFP_CMD_NOP)
        if cmd == EFP_CMD_RUN:
            self._tick_run(self._regs.get(R_EFP_REGION, 0) & 0xFF)
        elif cmd == EFP_CMD_RUN_PACKED:
            self._tick_run_packed(self._regs.get(R_EFP_REGION, 0) & 0xFF)
        elif cmd == EFP_CMD_STOP:
            self._tick_stop()
        elif cmd == EFP_CMD_RESTART:
            self._tick_restart()
        elif cmd == EFP_CMD_ABORT:
            for i in range(self.num_regions):
                self._regions[i] = _Region.FREE
                self._region_words[i] = 0
            self._finish(EFP_S_IDLE, 0)

    def _tick_run(self, region_sel: int) -> None:
        words = self._regs.get(R_EFP_IMG_WORDS, 0) & 0xFFFF
        if self._state == EFP_S_VERIFY:
            if words == 0:
                self._fail(EFP_ERR_IMG_LEN_MISMATCH)
            elif not self._verify_staged():
                self._fail(EFP_ERR_BAD_SIG)
            else:
                self._state = EFP_S_ALLOC
        elif self._state == EFP_S_ALLOC:
            region = self._alloc(region_sel)
            if region < 0:
                self._fail(EFP_ERR_REGION_FULL)
            else:
                self._run_region = region
                self._state = EFP_S_BLANK
        elif self._state == EFP_S_BLANK:
            self._streamed = 0
            self._state = EFP_S_LOAD  # OCC WRITE armed (stub consumes writes)
        elif self._state == EFP_S_LOAD:
            if self._streamed >= words:
                self._state = EFP_S_READBACK
        elif self._state == EFP_S_READBACK:
            region = self._run_region
            self._regions[region] = _Region.RUNNING
            self._region_words[region] = words
            self._last_region = region
            self._last_words = words
            self._staged = 1
            self._finish(EFP_S_RUNNING, 1)

    def _tick_run_packed(self, region_sel: int) -> None:
        """run_packed FSM (spec sec 3.3): VERIFY/ALLOC as run, then BLANK all
        covered columns (one per tick), then per column LOAD (WRITE armed,
        host streams), then READBACK per column, then RUNNING. The OCC sticky
        done_flag models the host handshake: set on each OCC completion,
        cleared when the next WRITE is armed."""
        words = self._regs.get(R_EFP_IMG_WORDS, 0) & 0xFFFF
        cols = self._regs.get(R_EFP_IMG_COLS, 0) & 0xFF
        if self._state == EFP_S_VERIFY:
            if words == 0 or cols == 0:
                self._fail(EFP_ERR_IMG_LEN_MISMATCH)
            elif not self._verify_staged():
                self._fail(EFP_ERR_BAD_SIG)
            else:
                self._state = EFP_S_ALLOC
        elif self._state == EFP_S_ALLOC:
            region = self._alloc(region_sel)
            if region < 0:
                self._fail(EFP_ERR_REGION_FULL)
            elif region + cols > self.num_regions:
                # v0 region->column mapping ASSUMPTION (sec 3.3): region r
                # covers columns starting at column r; must fit the fabric.
                self._fail(EFP_ERR_IMG_LEN_MISMATCH)
            else:
                self._run_region = region
                self._cols = cols
                self._col = 0
                self._col_addrs = []
                self._state = EFP_S_BLANK
        elif self._state == EFP_S_BLANK:
            # BLANK every covered column up front (spec sec 3.3 step 2).
            self._arm_column_frame(self._run_region, self._col, words)
            self._occ_done_flag = 1  # BLANK col complete (sticky, spec sec 4)
            self._col += 1
            if self._col >= self._cols:
                self._col = 0
                self._streamed = 0
                self._occ_done_flag = 0  # WRITE col 0 armed (clears flag)
                self._arm_column_frame(self._run_region, self._col, words)
                self._state = EFP_S_LOAD
        elif self._state == EFP_S_LOAD:
            if self._occ_done_flag:
                # column WRITE completion latched -> arm the next column
                self._col += 1
                if self._col >= self._cols:
                    self._col = 0
                    self._state = EFP_S_READBACK
                else:
                    self._occ_done_flag = 0  # WRITE col armed (clears flag)
                    self._arm_column_frame(self._run_region, self._col, words)
            elif self._streamed >= (self._col + 1) * words:
                self._occ_done_flag = 1  # WRITE col complete (sticky)
        elif self._state == EFP_S_READBACK:
            self._arm_column_frame(self._run_region, self._col, words)
            self._occ_done_flag = 1
            self._col += 1
            if self._col >= self._cols:
                region = self._run_region
                self._regions[region] = _Region.RUNNING
                self._region_words[region] = words
                self._last_region = region
                self._last_words = words
                self._staged = 1
                self._finish(EFP_S_RUNNING, 1)

    def _tick_stop(self) -> None:
        sel = self._regs.get(R_EFP_REGION, 0) & 0xFF
        if sel >= self.num_regions:
            self._fail(EFP_ERR_BAD_CMD)
            return
        if self._state == EFP_S_IDLE:  # first tick: enter BLANK
            self._state = EFP_S_BLANK
            return
        # BLANK done
        self._regions[sel] = _Region.FREE
        self._region_words[sel] = 0
        self._finish(EFP_S_STOPPED, 0)

    def _tick_restart(self) -> None:
        if not self._staged:
            self._fail(EFP_ERR_BAD_CMD)
            return
        region = self._last_region
        if self._state == EFP_S_IDLE:  # stop part
            self._regions[region] = _Region.FREE
            self._region_words[region] = 0
            self._state = EFP_S_BLANK
            return
        if self._state == EFP_S_BLANK:
            if (self._regs.get(R_EFP_IMG_WORDS, 0) & 0xFFFF) != self._last_words:
                self._fail(EFP_ERR_IMG_LEN_MISMATCH)
                return
            self._state = EFP_S_VERIFY
            self._cmd = EFP_CMD_RUN  # continue as a run on the last region
            self._regs[R_EFP_REGION] = region
            return

    # ---- convenience ----
    def region_state(self, region: int) -> int:
        return self._regions[region]

    def column_addrs(self) -> list[int]:
        """OCC_FRAME_ADDR values armed during the current command (v0.6 trace)."""
        return list(self._col_addrs)


def execute_ops(ops: list[Op], model: EfpDaemonModel, *,
                poll_limit: int = 10_000) -> list[int]:
    """Execute an EFP op list against a model (or any object with
    ``read(addr)``/``write(addr, data)`` + ``tick()``). Returns read values.

    ``poll`` re-reads until ``(v & mask) == value``, ticking the model once
    per retry so its FSM advances (a real transport would just re-read).
    """
    reads: list[int] = []
    for op in ops:
        if op.op == "write":
            model.write(op.addr, op.data or 0)
        elif op.op == "stream":
            for w in op.words or []:
                model.write(op.addr, w)
        elif op.op == "read":
            v = model.read(op.addr)
            if op.mask and (v & op.mask) != (op.value or 0):
                raise EfpError(
                    f"read check failed @0x{op.addr:02x}: "
                    f"got 0x{v:08x}, want (v & 0x{op.mask:08x}) == 0x{op.value or 0:08x}"
                )
            reads.append(v)
        elif op.op == "poll":
            matched = False
            for _ in range(poll_limit):
                v = model.read(op.addr)
                if (v & (op.mask or 0)) == (op.value or 0):
                    matched = True
                    break
                model.tick()
            if not matched:
                raise EfpError(
                    f"poll timeout @0x{op.addr:02x}: "
                    f"(v & 0x{op.mask or 0:08x}) never == 0x{op.value or 0:08x}"
                )
        else:
            raise EfpError(f"unknown op {op.op!r}")
    return reads


# --------------------------------------------------------------------------- #
# Demo-session generator (Makefile test-sv regen step + tb_ethctl_replay).
# Builds a test .eth (image A = TFF, v0 cfg-addr format, 12 words) with
# ethimg pack+sign using the SAME fixed-seed key as the daemon keyring.h
# (gen_daemon_vectors.KEY_SEED), then produces the run/stop session JSONs via
# the real ethctl CLI path (ethctl run/stop --transport efp --emit-session).
# --------------------------------------------------------------------------- #
def build_demo_sessions(out_dir: Path) -> dict[str, str]:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

    daemon_dir = str(
        Path(__file__).resolve().parents[2]
        / "ethereal-runtime" / "bmc-fw" / "daemon"
    )
    if daemon_dir not in sys.path:
        sys.path.insert(0, daemon_dir)
    from gen_daemon_vectors import IMG_A_WORDS, KEY_SEED

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # PEM private key from the deterministic seed (matches daemon keyring.h).
    sk = Ed25519PrivateKey.from_private_bytes(KEY_SEED)
    priv_pem = sk.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )

    # image A src tree (v0 cfg-addr frames — the format the daemon consumes).
    src = out_dir / "img_a_src"
    (src / "targets").mkdir(parents=True, exist_ok=True)
    (src / "targets" / "efab-1.0.frames").write_bytes(
        b"".join(w.to_bytes(4, "little") for w in IMG_A_WORDS)
    )
    eth_path = out_dir / "img_a.eth"
    ethimg.pack(src, eth_path, name="ethctl-replay-a", target="efab-1.0",
                privkey_pem=priv_pem)

    # E2-SEC1: the EFP path verifies the manifest signature host-side by
    # default, so the demo CLI run needs the matching public key on disk.
    pub_path = out_dir / "daemon_pub.pem"
    pub_path.write_bytes(sk.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ))

    import ethctl

    run_json = out_dir / "session_run_a.json"
    stop_json = out_dir / "session_stop_a.json"
    rc = ethctl._cli([
        "--transport", "efp", "run", str(eth_path),
        "--region", "auto",
        "--pubkey", str(pub_path),
        "--emit-session", str(run_json),
    ])
    if rc != 0:
        raise EfpError("ethctl run --transport efp failed")
    rc = ethctl._cli([
        "--transport", "efp", "stop", "--region", "0",
        "--emit-session", str(stop_json),
    ])
    if rc != 0:
        raise EfpError("ethctl stop --transport efp failed")
    return {
        "eth": str(eth_path),
        "run": str(run_json),
        "stop": str(stop_json),
        "digest": ethimg.read_manifest(eth_path).manifest_digest,
    }


def _cli(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="efp_client", description="EFP client helpers (demo session gen)"
    )
    p.add_argument("--emit-demo", metavar="DIR",
                   help="build the demo .eth + run/stop session JSONs into DIR")
    args = p.parse_args(argv)
    if args.emit_demo:
        info = build_demo_sessions(Path(args.emit_demo))
        print(f"[efp_client] demo .eth: {info['eth']} (digest {info['digest'][:16]}…)")
        print(f"[efp_client] session: {info['run']}")
        print(f"[efp_client] session: {info['stop']}")
        return 0
    p.error("nothing to do: pass --emit-demo DIR")
    return 2


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
