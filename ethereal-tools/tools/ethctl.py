# SPDX-License-Identifier: MIT
"""ethctl + daemon — Ethereal host control tool & deploy orchestrator.

Subsystem S08 (tasks E1-RUN2/3). In **mFSM v0 mode** (ADR-014, EMRI v0) the
"daemon" runs in the host process: it drives the EMRI register face to verify,
blank, and load a logic image into a region via the OCC. The transport is the
EFP-SPI frame protocol (EMRI spec sec 7) on real hardware; in simulation a
``RecordTransport`` emits a replayable deploy-plan JSON consumed by the SV
testbench (real EMRI regfile + OCC + fabric_top RTL — single source of truth).

Deploy flow (mFSM, host-driven, EMRI v0):
  1. read CAPABILITIES (confirm mFSM mode) + OCC_STATUS (IDLE);
  2. write OCC_FRAME_ADDR + OCC_WORD_COUNT, then OCC_CMD BLANK -> poll DONE;
  3. write OCC_FRAME_ADDR + OCC_WORD_COUNT, then OCC_CMD WRITE;
  4. stream every 32-bit frame word via OCC_PUSH (EFP-SPI op 0x03);
  5. poll OCC_STATUS until DONE; (optionally READBACK + CRC check).

Plan-Ref: ethereal-plan/subsystems/S08-运行时daemon与ethctl.md sec 2.1/§2.3,
          ethereal-spec/control/emri-v0.md sec 2/3/4/7.
"""
from __future__ import annotations

import argparse
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

import ethimg
from emri_constants import (
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
    R_HEALTH_STATUS,
    R_MAGIC,
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
    op: str          # "rd" | "wr" | "push"
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

    def to_plan(self, name: str, frames_words: list[int], region: int) -> dict:
        return {
            "schema": "ethereal.deploy-plan.v0",
            "name": name,
            "region": region,
            "frames_words": frames_words,
            "txn_log": [
                {"op": t.op, "addr": t.addr, "data": t.data} for t in self.log
            ],
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
            return 1 if self.has_bmc else 0
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


@dataclass
class DeployResult:
    region: int
    words_written: int
    elapsed_s: float
    needs_blank_first: bool = False


@dataclass
class Daemon:
    """mFSM-mode deploy orchestrator. Drives a Transport (real SPI or sim)."""

    transport: Transport
    poll_interval_s: float = 0.0  # 0 = no real delay (sim); set for HW
    poll_timeout: int = 100_000

    # ---- discovery ----
    def is_mfsm_mode(self) -> bool:
        caps = self.transport.read(R_CAPABILITIES)
        return (caps & 0x1) == 0

    def magic_ok(self) -> bool:
        return self.transport.read(R_MAGIC) == 0x45544852

    def inspect(self) -> dict[str, Any]:
        caps = self.transport.read(R_CAPABILITIES)
        info = {
            "magic_ok": self.magic_ok(),
            "has_bmc": bool(caps & 0x1),
            "num_regions": self.transport.read(R_NUM_REGIONS),
            "platform_id": self.transport.read(R_PLATFORM_ID),
            "health": self.transport.read(R_HEALTH_STATUS),
        }
        regions = []
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

    def _write_frames(self, region: int, frame_addr: int, words: list[int]) -> None:
        self.transport.write(R_OCC_FRAME_ADDR, frame_addr)
        self.transport.write(R_OCC_WORD_COUNT, len(words))
        self.transport.write(
            R_OCC_CMD,
            (1 << OCC_CMD_START) | ((region & 0xF) << 2) | OCC_WRITE,
        )
        for w in words:
            self.transport.push(w)
        return self._occ_wait()  # done_code (DONE or NEEDS_BLANK)

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
        if not self.is_mfsm_mode():
            # BMC mode needs a different (high-level) command; v0 is mFSM only.
            raise DaemonError("device is in BMC mode — v0 daemon is mFSM-only")

        t0 = time.perf_counter()
        needs_blank = False
        if blank_first:
            self._blank(region, frame_addr, len(words))
        code = self._write_frames(region, frame_addr, words)
        if code == OCC_DONE_NEEDS_BLANK:
            # FABulous red line: WRITE to a dirty region -> blank then retry
            needs_blank = True
            self._blank(region, frame_addr, len(words))
            self._write_frames(region, frame_addr, words)
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
        return self.deploy(
            frames_bytes, region=region, frame_addr=frame_addr
        )


def _extract_frames(eth_path: Path, target: str) -> bytes:
    import tarfile

    with tarfile.open(Path(eth_path), "r") as tf:
        member = f"targets/{target}.frames"
        try:
            f = tf.extractfile(member)
        except KeyError:
            raise DaemonError(f"{eth_path}: missing {member}")
        if f is None:
            raise DaemonError(f"{eth_path}: empty {member}")
        return f.read()


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _cli(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ethctl", description="Ethereal host control")
    p.add_argument(
        "--mode",
        choices=("sim-model", "plan"),
        default="plan",
        help="sim-model: drive the in-Python EMRI model; plan: emit a replay JSON",
    )
    p.add_argument("--plan-out", default=None, help="deploy-plan JSON path (mode=plan)")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("run", help="verify + deploy a .eth to a region")
    sp.add_argument("eth")
    sp.add_argument("--region", type=int, default=0)
    sp.add_argument("--frame-addr", type=int, default=0)
    sp.add_argument("--allow-unsigned", action="store_true")
    sp.add_argument("--pubkey", action="append", default=[])

    sub.add_parser("inspect", help="read EMRI identity/capabilities")
    sub.add_parser("ps", help="list regions")

    args = p.parse_args(argv)
    # build transport
    if args.mode == "plan":
        transport: Transport = RecordTransport()
    else:
        transport = PythonEmriModel()
    daemon = Daemon(transport)

    try:
        if args.cmd == "inspect":
            print(json.dumps(daemon.inspect(), indent=2))
        elif args.cmd == "ps":
            for r in daemon.ps():
                print(
                    f"region{r['region']:2d} healthy={r['healthy']} "
                    f"{r['geometry']['cols']}x{r['geometry']['rows']} "
                    f"({r['geometry']['tiles']} tiles)"
                )
        elif args.cmd == "run":
            keys = [Path(k).read_bytes() for k in args.pubkey] or None
            r = daemon.deploy_image(
                Path(args.eth),
                region=args.region,
                frame_addr=args.frame_addr,
                trusted_pubkeys=keys,
                allow_unsigned=args.allow_unsigned,
            )
            print(
                f"deployed region{r.region}: {r.words_written} words, "
                f"{r.elapsed_s*1000:.1f} ms"
            )
            if args.mode == "plan" and args.plan_out:
                # recompute frames_words for the plan
                frames_bytes = _extract_frames(Path(args.eth), _target_of(Path(args.eth)))
                words = [
                    struct.unpack_from("<I", frames_bytes, i)[0]
                    for i in range(0, len(frames_bytes), 4)
                ]
                plan = transport.to_plan(_name_of(Path(args.eth)), words, args.region)  # type: ignore[attr-defined]
                Path(args.plan_out).write_text(json.dumps(plan, indent=2))
                print(f"wrote deploy plan -> {args.plan_out}")
        return 0
    except (DaemonError, ethimg.EthimgError) as e:
        print(f"ethctl: error: {e}", file=sys.stderr)
        return 1


def _target_of(eth_path: Path) -> str:
    return ethimg.read_manifest(eth_path).target


def _name_of(eth_path: Path) -> str:
    return ethimg.read_manifest(eth_path).name


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
