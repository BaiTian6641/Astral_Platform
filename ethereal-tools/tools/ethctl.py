# SPDX-License-Identifier: MIT
"""ethctl + daemon — Ethereal host control tool & deploy orchestrator.

Subsystem S08 (tasks E1-RUN2/3). In **mFSM v0 mode** (ADR-014, EMRI v0) the
"daemon" runs in the host process: it drives the EMRI register face to verify,
blank, and load a logic image into a region via the OCC. The transport is the
EFP-SPI frame protocol (EMRI spec sec 7) on real hardware; in simulation a
``RecordTransport`` emits a replayable deploy-plan JSON consumed by the SV
testbench (real EMRI regfile + OCC + fabric_top RTL — single source of truth).

**Session mode (E1-BMC4).** ethctl does NOT need the user to say which side it
talks to: it probes ``CAPABILITIES.has_bmc`` — the only field that differs
between the two EMRI implementations (spec sec 1.1) — and derives the session
semantics from it (spec sec 8). mFSM = the host-driven flow above (there is no
device-side daemon); BMC = the high-level EFP command block (``EFP_CMD`` /
``EFP_STATUS``, sec 3.2) whose firmware daemon owns the OCC lifecycle.
``--transport mfsm|efp`` pins the path instead (override); a pinned path that
contradicts the probe fails closed rather than driving the wrong protocol.
Commands only a BMC can answer (``stop``/``restart``/``abort``, ``run_packed``,
ctx save/restore) are refused with an actionable error on an mFSM. The full
mFSM-vs-BMC difference table lives on :class:`EmriMode`.

Plan-Ref: ethereal-plan/subsystems/S08-运行时daemon与ethctl.md sec 2.1/§2.3,
          ethereal-spec/control/emri-v0.md sec 1.1/2/3/4/7/8.
"""

from __future__ import annotations

import argparse
import enum
import json
import struct
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

# ethimg + EMRI offsets live alongside (ethereal-tools/tools/)
_THIS_DIR = str(Path(__file__).resolve().parent)
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

# capcheck (E2-SEC1) lives in the sibling ethereal-runtime/security/ package.
_SECURITY_DIR = str(Path(__file__).resolve().parents[2] / "ethereal-runtime")
if _SECURITY_DIR not in sys.path:
    sys.path.insert(0, _SECURITY_DIR)

# pi-lens-ignore: E402
import efp_client
import ethimg
import oci_registry
from emri_constants import (
    CAPB_HAS_BMC,
    EFP_REGION_AUTO,
    OCC_BLANK,
    OCC_CMD_START,
    OCC_DONE_DONE,
    OCC_DONE_ERROR,
    OCC_DONE_LOCKED,
    OCC_DONE_NEEDS_BLANK,
    OCC_READBACK,
    OCC_S_BUSY,
    OCC_S_DONE,
    OCC_S_ERROR,
    OCC_S_IDLE,
    OCC_S_NEEDS_BLANK,
    OCC_STATUS_DONE_CODE_LO,
    OCC_STATUS_DONE_FLAG,
    OCC_WRITE,
    R_CAPABILITIES,
    R_EFP_ERR,
    R_EFP_STATUS,
    R_HEALTH_STATUS,
    R_MAGIC,
    R_MON_NOTIFY,
    R_NUM_REGIONS,
    R_OCC_CMD,
    R_OCC_FRAME_ADDR,
    R_OCC_STATUS,
    R_OCC_WDATA,
    R_OCC_WORD_COUNT,
    R_PLATFORM_ID,
    R_REGION_INFO,
    R_REGION_SEL,
)

# pi-lens-ignore: E402
from security import capcheck

# --------------------------------------------------------------------------- #
# Session mode (E1-BMC4): BMC vs mFSM
# --------------------------------------------------------------------------- #
# MON_NOTIFY bit layout (spec sec 2/3.8): bit r = "deploy completed in region r"
# for r in 0..7 (bit 8+r = watchdog event on region r). Bits above the fabric's
# region count are ignored by the regfile.
MON_NOTIFY_REGIONS = 8


class EmriMode(enum.Enum):
    """Which EMRI implementation ethctl drives (emri-v0.md sec 1.1 + sec 8).

    Both expose the *same* register map, transport and commands; the only probe
    field that differs is ``CAPABILITIES.has_bmc`` (sec 1.1/2). What changes is
    where the session intelligence lives (sec 8, "protocol identical,
    intelligence location differs"):

    * ``MFSM`` (has_bmc=0) -- no CPU and no daemon on the device, so the HOST
      owns the session:
      - it verifies the image (``ethimg``/Ed25519; the mFSM trusts the host),
      - it writes ``OCC_CMD.start`` itself and polls ``OCC_STATUS``,
      - it streams the frame words (sec 1 v0 scope: the device-side 5-state
        session FSM + ``rx_buf`` are v0.1, so v0 does NOT pulse ``SESSION_CMD``;
        the ``SESSION_*``/``RX_BUF_CTRL`` registers are plain storage for
        forward-compat),
      - it notifies the anomaly monitor (sec 3.8: "the daemon (or the host in
        mFSM mode) writes bit r on a completed deploy").
      The EFP command block is inert here (sec 3.2: "In mFSM mode these
      registers are plain host-visible storage (the mFSM has no daemon;
      ``EFP_CMD`` writes are ignored)").
    * ``BMC`` (has_bmc=1) -- the firmware daemon owns the session: the host
      stages metadata and rings ``EFP_CMD``, then polls ``EFP_STATUS`` /
      ``EFP_ERR``; the daemon issues ``OCC_CMD``, verifies Ed25519 in firmware
      and applies the region-lock lifecycle (sec 3.2/3.10). The host must NOT
      write ``OCC_CMD`` or ``MON_NOTIFY`` behind it.

    Daemon-only (BMC) flows with no mFSM equivalent: ``run_packed`` (sec 3.3),
    stop/restart/abort lifecycle (sec 3.2), context save/restore (sec 3.9),
    fw-update/reboot (sec 3.6, sim-demo).
    """

    MFSM = "mfsm"
    BMC = "bmc"


class RegisterReadable(Protocol):
    """Read-only EMRI register face -- the capability-probe seam."""

    def read(self, addr: int) -> int: ...


def probe_mode(device: RegisterReadable) -> EmriMode:
    """Derive the session mode from the capability probe (spec sec 1.1/2).

    ``CAPABILITIES`` bit0 ``has_bmc`` is the ONLY field that differs between
    the BMC and the mFSM, so auto-detection is a single register read.
    """
    caps = device.read(R_CAPABILITIES)
    return EmriMode.BMC if caps & (1 << CAPB_HAS_BMC) else EmriMode.MFSM


def resolve_mode(device: RegisterReadable, override: EmriMode | None) -> EmriMode:
    """Session mode: the caller's pinned override, else the capability probe."""
    return override if override is not None else probe_mode(device)


# --------------------------------------------------------------------------- #
# Transport abstraction (EFP-SPI in HW; record/replay in sim)
# --------------------------------------------------------------------------- #
class Transport(Protocol):
    """Minimal EMRI register-access transport (EFP-SPI sec 7)."""

    def read(self, addr: int) -> int: ...
    def write(self, addr: int, data: int) -> None: ...
    def push(self, data: int) -> None: ...  # optimized OCC_WDATA (op OCC_PUSH)
    def read_status(self) -> int: ...  # convenience: read OCC_STATUS


@dataclass
class RecordedTxn:
    op: str  # "rd" | "wr" | "push"
    addr: int
    data: int


@dataclass
class RecordTransport:
    """Records every EMRI transaction to a replay log (deploy plan).

    Delegates READS (and mirrors side effects of writes/pushes) to an embedded
    :class:`PythonEmriModel` so the Daemon sequencing completes; records every
    transaction. Used by the SV testbench to drive the REAL EMRI regfile + OCC +
    fabric. The recorded log is the single artifact tying ethctl (Python) to RTL.
    """

    model: PythonEmriModel = field(default_factory=lambda: PythonEmriModel())
    log: list[RecordedTxn] = field(default_factory=list)

    def read(self, addr: int) -> int:
        self.log.append(RecordedTxn("rd", addr, 0))
        return self.model.read(addr)

    def write(self, addr: int, data: int) -> None:
        self.log.append(RecordedTxn("wr", addr, data))
        self.model.write(addr, data)

    def push(self, data: int) -> None:
        self.log.append(RecordedTxn("push", R_OCC_WDATA, data))
        self.model.push(data)

    def read_status(self) -> int:
        return self.read(R_OCC_STATUS)

    def to_plan(self, name: str, frames_words: list[int], region: int) -> dict[str, Any]:
        return {
            "schema": "ethereal.deploy-plan.v0",
            "name": name,
            "region": region,
            "frames_words": frames_words,
            "txn_log": [{"op": t.op, "addr": t.addr, "data": t.data} for t in self.log],
        }


# --------------------------------------------------------------------------- #
# PythonEmriModel — thin functional model for Daemon unit-testing.
# Authoritative behavior is the SV RTL (tb_emri_regfile + step-6 loop TB); this
# model just makes the Daemon sequencing testable without a simulator.
# --------------------------------------------------------------------------- #
class _OccStub:
    """Minimal OCC: BLANK completes in wc cycles; WRITE consumes wc words."""

    def __init__(self) -> None:
        self.status = OCC_S_IDLE
        self.cmd = 0
        self.wc = 0
        self.beats = 0
        self.store: list[int] = []  # written config words (for inspection)

    def issue(self, cmd: int, frame_addr: int, wc: int) -> None:
        self.cmd = cmd
        self.wc = wc
        self.beats = 0
        # Functional model has no clock: BLANK/READBACK self-complete on issue
        # (a real OCC finishes after `wc` cycles; the model elides that). WRITE
        # stays BUSY until the right number of pushes arrive.
        if cmd in (OCC_BLANK, OCC_READBACK):
            self.status = OCC_S_DONE
        else:
            self.status = OCC_S_BUSY

    def push(self, data: int) -> None:
        if self.cmd != OCC_WRITE or self.status != OCC_S_BUSY:
            raise RuntimeError("push while OCC not consuming WRITE")
        self.store.append(data)
        self.beats += 1
        if self.beats >= self.wc:
            self.status = OCC_S_DONE

    def tick(self) -> None:
        # BLANK/READBACK self-complete one beat per tick
        if self.status == OCC_S_BUSY and self.cmd in (OCC_BLANK, OCC_READBACK):
            self.beats += 1
            if self.beats >= self.wc:
                self.status = OCC_S_DONE
        # WRITE completes via push(); IDLE/DONE are sticky until next issue.


@dataclass
class PythonEmriModel:
    """In-Python model of the EMRI regfile + a stub OCC (mFSM mode)."""

    has_bmc: bool = False
    num_regions: int = 2
    platform_id: int = 0x0000_0000
    region_infos: dict[int, int] = field(
        default_factory=lambda: {0: 0x0202_0010, 1: 0x0202_0010}
    )
    _region_sel: int = 0
    _occ_frame_addr: int = 0
    _occ_word_count: int = 0
    _occ: _OccStub = field(default_factory=_OccStub)

    # --- Transport interface ---
    def read(self, addr: int) -> int:
        if addr == R_MAGIC:
            return 0x45544852
        if addr == R_CAPABILITIES:
            return (1 << CAPB_HAS_BMC) if self.has_bmc else 0
        if addr == R_PLATFORM_ID:
            return self.platform_id
        if addr == R_NUM_REGIONS:
            return self.num_regions
        if addr == R_REGION_INFO:
            return self.region_infos.get(self._region_sel, 0)
        if addr == R_OCC_STATUS:
            s = self._occ.status
            val = s & 0x7  # [2:0] live status
            # sticky done_flag [3] + done_code [5:4] (RTL latches on terminal
            # state; model's _occ.status holds the terminal value until next
            # cmd, so the live status IS effectively the sticky result here)
            if s in (OCC_S_DONE, OCC_S_ERROR, OCC_S_NEEDS_BLANK):
                val |= 1 << OCC_STATUS_DONE_FLAG
                code = {
                    OCC_S_DONE: OCC_DONE_DONE,
                    OCC_S_ERROR: OCC_DONE_ERROR,
                    OCC_S_NEEDS_BLANK: OCC_DONE_NEEDS_BLANK,
                }[s]
                val |= code << OCC_STATUS_DONE_CODE_LO
            return val
        if addr == R_OCC_FRAME_ADDR:
            return self._occ_frame_addr
        if addr == R_OCC_WORD_COUNT:
            return self._occ_word_count
        if addr == R_HEALTH_STATUS:
            h = 0
            for i in range(self.num_regions):
                h |= 1 << (8 * i)
            return h
        return 0

    def write(self, addr: int, data: int) -> None:
        if addr == R_REGION_SEL:
            self._region_sel = data & 0xFF
        elif addr == R_OCC_FRAME_ADDR:
            self._occ_frame_addr = data & 0xFFFF
        elif addr == R_OCC_WORD_COUNT:
            self._occ_word_count = data & 0xFFFF
        elif addr == R_OCC_CMD and (data & (1 << OCC_CMD_START)):
            cmd = data & 0x3
            self._occ.issue(cmd, self._occ_frame_addr, self._occ_word_count)
            # (BLANK/READBACK already self-completed in issue(); WRITE waits
            # for the subsequent push() stream.)

    def push(self, data: int) -> None:
        self._occ.push(data)

    def read_status(self) -> int:
        return self.read(R_OCC_STATUS)


# --------------------------------------------------------------------------- #
# Daemon (deploy orchestrator)
# --------------------------------------------------------------------------- #
class DaemonError(Exception):
    pass


def require_bmc(mode: EmriMode, feature: str) -> None:
    """Refuse a BMC-only feature on an mFSM (emri-v0.md sec 3.2/8).

    The mFSM has no daemon and no CPU: the EFP command block is plain storage
    there ("EFP_CMD writes are ignored", sec 3.2), so a daemon lifecycle
    command would silently do nothing.
    """
    if mode is EmriMode.MFSM:
        raise DaemonError(
            f"{feature} needs a BMC daemon: this device reports mFSM "
            "(CAPABILITIES.has_bmc=0), which has no device-side daemon -- "
            "EFP_CMD writes are ignored (emri-v0.md sec 3.2/8). Use "
            "--transport efp against a BMC, or --device bmc in sim."
        )


def require_mfsm(mode: EmriMode, feature: str) -> None:
    """Refuse the host-driven OCC flow on a BMC (emri-v0.md sec 8).

    On a BMC the firmware daemon owns the OCC lifecycle; a host writing
    ``OCC_CMD`` behind it would race the daemon (and bypass the sec 3.10 lock
    policy), so the two must not be driven at once.
    """
    if mode is EmriMode.BMC:
        raise DaemonError(
            f"{feature} is mFSM-only: this device reports a BMC "
            "(CAPABILITIES.has_bmc=1), whose daemon owns the OCC lifecycle "
            "(emri-v0.md sec 8/3.2). Use the EFP command block "
            "(--transport efp) instead."
        )


@dataclass
class DeployResult:
    region: int
    words_written: int
    elapsed_s: float
    needs_blank_first: bool = False


@dataclass
class Daemon:
    """mFSM-mode deploy orchestrator. Drives a Transport (real SPI or sim).

    The session mode is auto-detected from ``CAPABILITIES.has_bmc`` (E1-BMC4);
    ``mode_override`` pins it instead (the CLI ``--transport`` override). A
    device that reports a BMC is refused by :meth:`deploy` unless the override
    pinned mFSM: the BMC daemon owns the OCC lifecycle there (spec sec 8).
    """

    transport: Transport
    poll_interval_s: float = 0.0  # 0 = no real delay (sim); set for HW
    poll_timeout: int = 100_000
    mode_override: EmriMode | None = None  # None = probe CAPABILITIES.has_bmc

    # ---- discovery ----
    def probe_mode(self) -> EmriMode:
        """Capability-probe result, ignoring any override (spec sec 1.1)."""
        return probe_mode(self.transport)

    def mode(self) -> EmriMode:
        """Effective session mode: pinned override, else the capability probe."""
        return resolve_mode(self.transport, self.mode_override)

    def is_mfsm_mode(self) -> bool:
        """True when the effective session is the host-driven mFSM flow."""
        return self.mode() is EmriMode.MFSM

    def magic_ok(self) -> bool:
        return self.transport.read(R_MAGIC) == 0x45544852

    def inspect(self) -> dict[str, Any]:
        """Read the identity/capability face -- identical on both modes.

        ``mode`` is the effective session mode (the probe, or the override);
        ``has_bmc`` is the raw capability bit, so an override that disagrees
        with the device stays visible. Every other field comes from the shared
        register map (spec sec 1.1), which is what makes ``ethctl inspect``
        byte-identical across a BMC and an mFSM (spec sec 8 acceptance).
        """
        caps = self.transport.read(R_CAPABILITIES)
        info: dict[str, Any] = {
            "mode": self.mode().value,
            "magic_ok": self.magic_ok(),
            "has_bmc": bool(caps & (1 << CAPB_HAS_BMC)),
            "num_regions": self.transport.read(R_NUM_REGIONS),
            "platform_id": self.transport.read(R_PLATFORM_ID),
            "health": self.transport.read(R_HEALTH_STATUS),
        }
        regions: list[int] = []
        for i in range(info["num_regions"]):
            self.transport.write(R_REGION_SEL, i)
            regions.append(self.transport.read(R_REGION_INFO))
        info["regions"] = regions
        return info

    def ps(self) -> list[dict[str, Any]]:
        n = self.transport.read(R_NUM_REGIONS)
        health = self.transport.read(R_HEALTH_STATUS)
        out = []
        for i in range(n):
            self.transport.write(R_REGION_SEL, i)
            geom = self.transport.read(R_REGION_INFO)
            out.append(
                {
                    "region": i,
                    "healthy": bool(health & (1 << (8 * i))),
                    "geometry": {
                        "cols": (geom >> 24) & 0xFF,
                        "rows": (geom >> 16) & 0xFF,
                        "tiles": geom & 0xFFFF,
                    },
                }
            )
        return out

    # ---- lifecycle helpers ----
    def _occ_wait(self) -> int:
        """Poll OCC_STATUS sticky done_flag until set; return the done_code.

        done_code: 0=DONE 1=ERROR 2=NEEDS_BLANK 3=LOCKED. Raises on ERROR/LOCKED;
        NEEDS_BLANK is surfaced to the caller (deploy retries with a blank).
        """
        for _ in range(self.poll_timeout):
            s = self.transport.read_status()
            if s & (1 << OCC_STATUS_DONE_FLAG):
                code = (s >> OCC_STATUS_DONE_CODE_LO) & 0x3
                if code == OCC_DONE_ERROR:
                    raise DaemonError("OCC ERROR during command")
                if code == OCC_DONE_LOCKED:
                    raise DaemonError("OCC region locked")
                return code  # DONE or NEEDS_BLANK
            if self.poll_interval_s:
                time.sleep(self.poll_interval_s)
        raise DaemonError("OCC poll timeout (done_flag never set)")

    def _blank(self, region: int, frame_addr: int, word_count: int) -> None:
        # OCC_FRAME_ADDR layout is v0.6 {region_id[15:12], col_id[11:8],
        # word[7:0]} (emri-v0.md sec 2); callers pass it fully formed.
        self.transport.write(R_OCC_FRAME_ADDR, frame_addr)
        self.transport.write(R_OCC_WORD_COUNT, word_count)
        # OCC_CMD = {start@8, region@[5:2], cmd=BLANK@[1:0]}
        self.transport.write(
            R_OCC_CMD,
            (1 << OCC_CMD_START) | ((region & 0xF) << 2) | OCC_BLANK,
        )
        code = self._occ_wait()
        if code == OCC_DONE_NEEDS_BLANK:
            # shouldn't happen for BLANK itself, but handle defensively
            self._blank(region, frame_addr, word_count)

    def _write_frames(self, region: int, frame_addr: int, words: list[int]) -> int:
        self.transport.write(R_OCC_FRAME_ADDR, frame_addr)
        self.transport.write(R_OCC_WORD_COUNT, len(words))
        self.transport.write(
            R_OCC_CMD,
            (1 << OCC_CMD_START) | ((region & 0xF) << 2) | OCC_WRITE,
        )
        for w in words:
            self.transport.push(w)
        return self._occ_wait()  # done_code (DONE or NEEDS_BLANK)

    def _notify_deploy(self, region: int) -> None:
        """Post the completed-deploy pulse to the hardware anomaly monitor.

        emri-v0.md sec 3.8: "the daemon (or the host in mFSM mode) writes bit
        ``r`` on a completed deploy". With no device-side daemon in mFSM mode
        the HOST is the only writer, so without this the MON_RECFG_COUNT /
        spike-detector surfaces stay dark. In BMC mode the daemon owns the
        word, which is why this sits on the host-driven path only.
        """
        if 0 <= region < MON_NOTIFY_REGIONS:
            self.transport.write(R_MON_NOTIFY, 1 << region)

    # ---- top-level deploy ----
    def deploy(
        self,
        frames_bytes: bytes,
        *,
        region: int,
        frame_addr: int = 0,
        blank_first: bool = True,
    ) -> DeployResult:
        """Blank (if requested) then WRITE the config frames into ``region``."""
        if len(frames_bytes) % 4 != 0:
            raise DaemonError(
                f"frames length {len(frames_bytes)} not a multiple of 4 bytes"
            )
        words = [
            struct.unpack_from("<I", frames_bytes, i)[0]
            for i in range(0, len(frames_bytes), 4)
        ]
        if not words:
            raise DaemonError("no frames to deploy")

        if not self.magic_ok():
            raise DaemonError("EMRI MAGIC mismatch — wrong device?")
        # Mode gate: the flow below drives OCC_CMD / MON_NOTIFY itself, which is
        # the host's job only in mFSM mode (spec sec 8) — on a BMC the firmware
        # daemon owns both words.
        require_mfsm(self.mode(), "the host-driven OCC deploy")

        t0 = time.perf_counter()
        needs_blank = False
        if blank_first:
            self._blank(region, frame_addr, len(words))
        code = self._write_frames(region, frame_addr, words)
        if code == OCC_DONE_NEEDS_BLANK:
            # FABulous red line: WRITE to a dirty region -> blank then retry
            needs_blank = True
            self._blank(region, frame_addr, len(words))
            code = self._write_frames(region, frame_addr, words)
        if code == OCC_DONE_DONE:
            self._notify_deploy(region)
        return DeployResult(
            region=region,
            words_written=len(words),
            elapsed_s=time.perf_counter() - t0,
            needs_blank_first=needs_blank,
        )

    def deploy_image(
        self,
        eth_path: Path,
        *,
        region: int,
        frame_addr: int = 0,
        trusted_pubkeys: list[bytes] | None = None,
        allow_unsigned: bool = False,
    ) -> DeployResult:
        """Verify a ``.eth`` then deploy its frames (host verifies in mFSM)."""
        man = ethimg.verify(
            eth_path, trusted_pubkeys=trusted_pubkeys, allow_unsigned=allow_unsigned
        )

        # extract frames from the tar (frames not on disk as a file)
        frames_bytes = _extract_frames(eth_path, man.target)
        return self.deploy(frames_bytes, region=region, frame_addr=frame_addr)


def _extract_frames(eth_path: Path, target: str) -> bytes:
    import tarfile

    with tarfile.open(Path(eth_path), "r") as tf:
        member = f"targets/{target}.frames"
        try:
            f = tf.extractfile(member)
        except KeyError:
            raise DaemonError(f"{eth_path}: missing {member}") from None
        if f is None:
            raise DaemonError(f"{eth_path}: empty {member}")
        return f.read()


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _parse_region(s: str) -> int:
    """Parse a --region argument: an integer index or 'auto' (0xFF, run only)."""
    if s == "auto":
        return EFP_REGION_AUTO
    try:
        return int(s, 0)
    except ValueError:
        raise DaemonError(f"bad --region {s!r} (integer or 'auto')") from None


def _cli_efp(args: Any, model: efp_client.EfpDaemonModel) -> int:
    """BMC daemon session (emri-v0.md sec 3.2, the BMC-mode EFP mailbox).

    Builds the session with efp_client, executes it against the functional
    daemon model (sim scope), and optionally dumps the op list as a session
    JSON (``--emit-session``) for SV testbench replay (tb_ethctl_replay).
    """
    client = efp_client.EfpClient()
    # The model carries the trusted key (raw 32-byte Ed25519): it enforces the
    # HOST-SIDE signature check in efp_client.load_image (E2-SEC1) and its own
    # VERIFY. Without it a signed image is refused unless --allow-unsigned is
    # passed explicitly.
    trusted_pk = model.trusted_pk
    allow_unsigned = bool(getattr(args, "allow_unsigned", False))

    ops: list[efp_client.Op]
    image: efp_client.StagedImage | None = None
    region: int | None = None
    name = args.cmd
    if args.cmd == "run":
        region = _parse_region(args.region)
        ops, image = client.run_image(
            Path(args.eth), region, trusted_pk=trusted_pk,
            allow_unsigned=allow_unsigned,
        )
        name = f"run {args.eth} region={'auto' if region == EFP_REGION_AUTO else region}"
    elif args.cmd == "restart":
        ops, image = client.restart(
            Path(args.eth), trusted_pk=trusted_pk, allow_unsigned=allow_unsigned
        )
        name = f"restart {args.eth}"
    elif args.cmd == "stop":
        region = _parse_region(args.region)
        if region == EFP_REGION_AUTO:
            raise DaemonError("stop needs an explicit --region (not 'auto')")
        ops = client.stop(region)
        name = f"stop region={region}"
    elif args.cmd == "abort":
        ops = client.abort()
    elif args.cmd == "ps":
        ops = client.ps()
    else:
        raise DaemonError(f"--transport efp does not support '{args.cmd}'")

    if args.emit_session:
        efp_client.write_session(ops, Path(args.emit_session), name=name,
                                 image=image, region=region)
        print(f"wrote EFP session -> {args.emit_session} ({len(ops)} ops)")

    try:
        reads = efp_client.execute_ops(ops, model)
    except efp_client.EfpError as e:
        # surface the device-side status/error alongside the host-side failure
        st = model.read(R_EFP_STATUS)
        er = model.read(R_EFP_ERR) & 0xFF
        raise DaemonError(
            f"{e} (daemon state={efp_client.decode_state(st & 0xF)} "
            f"err={efp_client.decode_err(er)})"
        ) from e
    status = model.read(R_EFP_STATUS)
    err = model.read(R_EFP_ERR)
    state = efp_client.decode_state(status & 0xF)
    if args.cmd == "ps":
        print(
            f"daemon: state={state} busy={(status >> 4) & 1} done={(status >> 5) & 1} "
            f"err={efp_client.decode_err(err)}"
        )
        for i in range(model.num_regions):
            geom = reads[2 + i]
            print(
                f"region{i:2d} geometry "
                f"{(geom >> 24) & 0xFF}x{(geom >> 16) & 0xFF} ({geom & 0xFFFF} tiles)"
            )
    elif args.cmd in ("run", "restart"):
        print(
            f"efp {args.cmd}: {image.name if image else '?'} "
            f"({len(image.frame_words) if image else 0} words, {len(ops)} ops) -> "
            f"{state} r{model._last_region}"
            f"{' done' if status & 0x20 else ''} err={efp_client.decode_err(err)}"
        )
    else:
        print(f"efp {args.cmd}: -> {state} err={efp_client.decode_err(err)}")
    if err != 0 or state == "ERROR":
        raise DaemonError(
            f"daemon reported {efp_client.decode_err(err)} (state {state})"
        )
    return 0


def _transport_override(s: str) -> EmriMode | None:
    """Map ``--transport`` to a pinned session mode (None = auto-probe)."""
    return {"auto": None, "mfsm": EmriMode.MFSM, "efp": EmriMode.BMC}[s]


def _trusted_pk(args: Any) -> bytes | None:
    """Raw 32-byte Ed25519 public key from the first ``--pubkey`` PEM, if any."""
    if not getattr(args, "pubkey", None):
        return None
    from cryptography.hazmat.primitives import serialization

    pub = serialization.load_pem_public_key(Path(args.pubkey[0]).read_bytes())
    return pub.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )


def _run_session(args: Any) -> int:
    """Auto-detect the EMRI session mode and run the requested command.

    E1-BMC4: the device (``--device``) is probed via ``CAPABILITIES.has_bmc``
    and the session semantics follow the result -- mFSM = the host-driven OCC
    flow (:class:`Daemon`), BMC = the EFP daemon mailbox (:func:`_cli_efp`).
    An explicit ``--transport mfsm|efp`` pins the path instead and is checked
    against the probe: a contradiction fails closed rather than driving the
    wrong protocol (spec sec 3.2/8).
    """
    device = args.device
    if device == "auto":
        # Compat: an explicit --transport efp has always meant the BMC daemon
        # path in sim, so it also selects the BMC device model.
        device = "bmc" if args.transport == "efp" else "emri"
    # In hardware there is ONE EMRI register map and only the probe differs
    # (spec sec 1.1); the sim needs one device model per implementation.
    model: PythonEmriModel | RecordTransport | efp_client.EfpDaemonModel
    if device == "bmc":
        model = efp_client.EfpDaemonModel(trusted_pk=_trusted_pk(args))
    elif args.mode == "plan":
        model = RecordTransport()
    else:
        model = PythonEmriModel()

    detected = probe_mode(model)
    override = _transport_override(args.transport)
    if override is not None and override is not detected:
        # Fail closed (spec sec 3.2/8): EFP commands at a daemonless mFSM are
        # ignored, and the host-driven OCC flow at a BMC races the daemon and
        # bypasses its lock policy.
        if override is EmriMode.BMC:
            require_bmc(detected, "the EFP session (--transport efp)")
        else:
            require_mfsm(detected, "the host-driven OCC session (--transport mfsm)")
    session = override if override is not None else detected

    if args.cmd == "inspect":
        # Mode-agnostic: the identity/capability face is the same register map
        # on both implementations, so the output is byte-identical for the
        # fields both expose (spec sec 1.1/8 acceptance).
        print(json.dumps(Daemon(model, mode_override=session).inspect(), indent=2))
        return 0

    if session is EmriMode.BMC:
        if not isinstance(model, efp_client.EfpDaemonModel):
            raise DaemonError(
                "auto-detected a BMC but no daemon device model is selected "
                "(--device bmc in sim)"
            )
        return _cli_efp(args, model)

    # ---- mFSM mode: host-driven session, no device-side daemon ------------
    if args.cmd in ("stop", "restart", "abort"):
        require_bmc(session, f"'{args.cmd}' (device lifecycle)")
    if args.emit_session:
        raise DaemonError(
            "--emit-session needs a BMC daemon (--transport efp): the session "
            "JSON replays EFP commands, which an mFSM ignores (emri-v0.md "
            "sec 3.2)"
        )
    if args.cmd == "run":
        args.region = _parse_region(args.region)
        if args.region == EFP_REGION_AUTO:
            raise DaemonError(
                "--region auto needs a BMC daemon allocator (--transport efp): "
                "the mFSM host deploys to an explicit region"
            )
    daemon = Daemon(model, mode_override=session)
    if args.cmd == "ps":
        for row in daemon.ps():
            print(
                f"region{row['region']:2d} healthy={row['healthy']} "
                f"{row['geometry']['cols']}x{row['geometry']['rows']} "
                f"({row['geometry']['tiles']} tiles)"
            )
    elif args.cmd == "run":
        keys = [Path(k).read_bytes() for k in args.pubkey] or None
        res = daemon.deploy_image(
            Path(args.eth),
            region=args.region,
            frame_addr=args.frame_addr,
            trusted_pubkeys=keys,
            allow_unsigned=args.allow_unsigned,
        )
        print(
            f"deployed region{res.region}: {res.words_written} words, "
            f"{res.elapsed_s * 1000:.1f} ms (mode={session.value})"
        )
        if args.mode == "plan" and args.plan_out:
            # recompute frames_words for the plan
            frames_bytes = _extract_frames(Path(args.eth), _target_of(Path(args.eth)))
            words = [
                struct.unpack_from("<I", frames_bytes, i)[0]
                for i in range(0, len(frames_bytes), 4)
            ]
            if isinstance(model, RecordTransport):
                plan = model.to_plan(_name_of(Path(args.eth)), words, args.region)
                Path(args.plan_out).write_text(json.dumps(plan, indent=2))
                print(f"wrote deploy plan -> {args.plan_out}")
    return 0


def _cli(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ethctl", description="Ethereal host control")
    p.add_argument(
        "--mode",
        choices=("sim-model", "plan"),
        default="plan",
        help="sim-model: drive the in-Python EMRI model; plan: emit a replay JSON",
    )
    p.add_argument("--plan-out", default=None, help="deploy-plan JSON path (mode=plan)")
    p.add_argument(
        "--device",
        choices=("auto", "emri", "bmc"),
        default="auto",
        help="sim device model: emri = EMRI regfile (record/Python model); "
        "bmc = in-Python BMC daemon (EFP command block); auto follows "
        "--transport (efp => bmc, else emri)",
    )
    p.add_argument(
        "--transport",
        choices=("auto", "mfsm", "efp"),
        default="auto",
        help="session semantics: auto (default) probes CAPABILITIES.has_bmc "
        "and picks the mFSM host-driven OCC flow or the BMC EFP mailbox; "
        "mfsm/efp pin the path explicitly (checked against the probe)",
    )
    p.add_argument(
        "--emit-session",
        default=None,
        help="EFP session JSON output path (transport=efp; TB replay artifact)",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    sp_run = sub.add_parser("run", help="verify + deploy a .eth to a region")
    sp_run.add_argument("eth")
    sp_run.add_argument("--region", default="0", help="region index or 'auto' (efp)")
    sp_run.add_argument("--frame-addr", type=int, default=0)
    sp_run.add_argument("--allow-unsigned", action="store_true")
    sp_run.add_argument("--pubkey", action="append", default=[])

    sub.add_parser("inspect", help="read EMRI identity/capabilities")
    sp_ps = sub.add_parser("ps", help="list regions / daemon status")
    sp_stop = sub.add_parser("stop", help="stop a region (efp: BLANK -> STOPPED)")
    sp_stop.add_argument("--region", default="0")
    sp_restart = sub.add_parser("restart", help="re-run last staged image (efp)")
    sp_restart.add_argument("eth", help=".eth supplying the frame words to re-stream")
    sp_restart.add_argument("--allow-unsigned", action="store_true")
    sp_restart.add_argument("--pubkey", action="append", default=[])
    sp_abort = sub.add_parser("abort", help="best-effort BLANK -> IDLE (efp)")
    # OCI artifact transport (S09 sec 2.3, E3-REP1): push/pull a .eth image to an
    # OCI layout or registry. No EMRI transport involved (pure host-side I/O).
    sp_push = sub.add_parser("push", help="upload a .eth image to an OCI store")
    sp_push.add_argument("eth", help=".eth logic image")
    sp_push.add_argument("ref", help="<repository>:<tag> (default tag 'latest')")
    sp_push.add_argument("--pubkey", action="append", default=[],
                         help="trusted PEM pubkey (required for a signed image)")
    sp_pull = sub.add_parser("pull", help="download + verify an image from an OCI store")
    sp_pull.add_argument("ref", help="<repository>:<tag> or <repository>@<digest>")
    sp_pull.add_argument("dest", help="output .eth path (or a directory)")
    sp_pull.add_argument("--pubkey", action="append", default=[])
    sp_pull.add_argument("--allow-unsigned", action="store_true")
    for spx in (sp_push, sp_pull):
        spx.add_argument("--layout", help="local OCI layout directory")
        spx.add_argument("--registry", help="OCI registry base URL (overrides --layout)")
        spx.add_argument("--authorization", help="raw Authorization header for --registry")

    # allow the transport flags AFTER the subcommand too
    # (`ethctl run img.eth --transport efp --emit-session s.json`)
    for spx in (sp_run, sp_ps, sp_stop, sp_restart, sp_abort):
        spx.add_argument("--device", choices=("auto", "emri", "bmc"),
                         default=argparse.SUPPRESS)
        spx.add_argument("--transport", choices=("auto", "mfsm", "efp"),
                         default=argparse.SUPPRESS)
        spx.add_argument("--emit-session", default=argparse.SUPPRESS)

    args = p.parse_args(argv)
    if args.cmd in ("push", "pull"):
        # OCI artifact transport (S09 sec 2.3, E3-REP1) — host-side I/O only, so
        # it short-circuits before any EMRI transport/daemon is built.
        try:
            store = oci_registry.store_for(
                layout=args.layout,
                registry=args.registry,
                authorization=args.authorization,
            )
            keys = [Path(k).read_bytes() for k in args.pubkey] or None
            if args.cmd == "push":
                pushed = oci_registry.push(
                    store, args.ref, Path(args.eth), trusted_pubkeys=keys
                )
                print(
                    f"pushed {pushed.ref} (manifest {pushed.descriptor.digest}, "
                    f"signed={pushed.signed})"
                )
            else:
                pulled = oci_registry.pull(
                    store,
                    args.ref,
                    Path(args.dest),
                    trusted_pubkeys=keys,
                    allow_unsigned=args.allow_unsigned,
                )
                print(
                    f"pulled {pulled.ref} -> {pulled.path} "
                    f"({pulled.name} v{pulled.version}, target {pulled.target})"
                )
            return 0
        except (oci_registry.OciError, ethimg.EthimgError) as e:
            print(f"ethctl: error: {e}", file=sys.stderr)
            return 1
    try:
        return _run_session(args)
    except (
        DaemonError,
        efp_client.EfpError,
        ethimg.EthimgError,
        capcheck.CapabilityError,
    ) as e:
        # A capability refusal names the offending entry in `e` (E2-SEC1).
        print(f"ethctl: error: {e}", file=sys.stderr)
        return 1


def _target_of(eth_path: Path) -> str:
    return ethimg.read_manifest(eth_path).target


def _name_of(eth_path: Path) -> str:
    return ethimg.read_manifest(eth_path).name


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
