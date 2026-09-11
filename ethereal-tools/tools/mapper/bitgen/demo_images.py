# SPDX-License-Identifier: MIT
"""demo_images — E1-DMO1 signed demo .eth image builder (the production path).

Builds the two demo images end-to-end through the REAL toolchain and ships
them as signed ``.eth`` tars under ``ethereal-images/demos/``:

    synth_ethereal (dffunmap flow) -> VPR pack/place (run_vpr.sh)
    -> bitgen_db.build_db -> bitgen_route.route (PathFinder, v2c pruned CB)
    -> frame pack onto the TARGET fabric descriptor (fabric_gen FrameMap;
       bbox-normalized tiles + blank padding to the descriptor geometry)
    -> ethimg pack + Ed25519 sign (gen_daemon_vectors.KEY_SEED — the daemon
       keyring.h key) -> efp_client run_packed session JSONs under
       generated/ethctl/ (schema ethereal.efp-session.v0, replayable by
       tb_ethctl_replay's replayer).

Images (smallest fitting all-CLB descriptor per image, E1-DMO1 sizing):

  * ``pwm``            11 eLUT  -> fabric_2x2 (2 cols x 2 rows, 32 eLUT)
  * ``uart_loopback``  76 eLUT  -> fabric_4x4 (4 cols x 4 rows, 128 eLUT;
    the 2x4/64 target is unreachable at the hardware CLKS_PER_BIT=87 — see
    the E1-DMO1 report sizing table)

Frame geometry (v2c, frozen frame_map): a frame = one COLUMN of tiles packed
into 32-bit DATA words + a CRC16 tail word; the 2x2 column is 34 DATA words,
the 4-row column (fabric_2x4 AND fabric_4x4) is 67. The ``.eth`` frames
member carries the per-column DATA words concatenated (CRC tails excluded —
a transport trailer the OCC never consumes; efp_client.load_image /
emri-v0.md §3.3 convention).

The bit-true ACCEPTANCE (test_demo_images.py) replays the SHIPPED frames
through ``frames_to_db`` + ``frames_to_route`` (CRC-checked unpack) and runs
FabricSim against the iverilog golden — combinational ``evaluate`` for pwm
(64 random vectors), the E1-DMO1 tick model for uart_loopback (directed byte
streams on ``rx``, per-cycle ``tx`` trace).

Run:  python demo_images.py [--out-dir DIR] [--ethctl-dir DIR] [--force]
"""
from __future__ import annotations

import base64
import re
import os
import subprocess
import sys
from pathlib import Path

# importing fabric_sim first bootstraps sys.path for bitgen_db / bitgen_route /
# the interconnect golden models (same bootstrap as test_bench_flow).
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import fabric_sim  # noqa: F401,E402  (sys.path bootstrap side effect)

_REPO = os.path.normpath(os.path.join(_HERE, "..", "..", "..", ".."))
_TOOLS = os.path.join(_REPO, "ethereal-tools", "tools")
for _p in (_TOOLS, os.path.join(_REPO, "ethereal-runtime", "bmc-fw", "daemon")):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from bitgen_db import FabricConfigDB, build_db  # noqa: E402
from bitgen_pack import (db_grid_bounds, frames_to_db, frames_to_route,  # noqa: E402
                         tile_to_full_points)
from bitgen_route import RouteConfig, route  # noqa: E402
from fabric_gen import FabricGen  # noqa: E402

import ethimg  # noqa: E402
from efp_client import EfpClient, write_session  # noqa: E402
from gen_daemon_vectors import KEY_SEED  # noqa: E402

MAPPER = os.path.join(_REPO, "generated", "mapper")
BENCH_DIR = os.path.join(_REPO, "ethereal-images", "benchmarks")
FABRIC_DIR = os.path.join(_REPO, "ethereal-spec", "fabric")
SYNTH = os.path.join(_REPO, "ethereal-tools", "tools", "mapper", "yosys",
                     "synth_ethereal.py")
RUN_VPR = os.path.join(_REPO, "ethereal-tools", "tools", "mapper", "vpr",
                       "run_vpr.sh")
KEYRING_H = os.path.join(_REPO, "ethereal-runtime", "bmc-fw", "daemon",
                         "keyring.h")
ROUTE_CHAN_W = "12"

# image registry: fabric descriptor (committed yaml), golden kind, ports.
IMAGES: dict[str, dict] = {
    "pwm": {
        "bench": "pwm.v", "top": "pwm",
        "fabric": "fabric_2x2", "num_regions": 2, "vpr_seed": 1,
        "kind": "comb",
        "inputs": [("duty", 8), ("count", 8)],
        "outputs": [("out", 1)],
        "n_vectors": 64, "seed": 0xE1D0,
    },
    "uart_loopback": {
        "bench": "uart_loopback.v", "top": "uart_loopback",
        "fabric": "fabric_4x4", "num_regions": 4, "vpr_seed": 3,
        "kind": "seq",
        "inputs": [("rx", 1)],
        "outputs": [("tx", 1)],
    },
}


# =============================================================================
# Toolchain flow (mirror test_bench_flow's self-contained artifact handling)
# =============================================================================

def _run(cmd: list[str], what: str, cwd: str | None = None) -> None:
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd,
                         check=False)
    if res.returncode != 0:
        raise RuntimeError(f"{what} failed (rc={res.returncode}):\n"
                           f"{res.stdout}\n{res.stderr}")


def ensure_flow(name: str) -> tuple[str, str, str]:
    """(.net, .place, .blif) for ``name`` — synth + VPR when missing/forced."""
    cfg = IMAGES[name]
    blif = os.path.join(MAPPER, f"{name}.blif")
    net = os.path.join(MAPPER, f"{name}_w{ROUTE_CHAN_W}_{name}.net")
    place = os.path.join(MAPPER, f"{name}_w{ROUTE_CHAN_W}_{name}.place")
    src = os.path.join(BENCH_DIR, cfg["bench"])
    if _FORCE or not os.path.exists(blif):
        _run(["python3", SYNTH, src, "-o", os.path.join(MAPPER, name),
              "-t", cfg["top"]], f"synth {name}")
    if _FORCE or not (os.path.exists(net) and os.path.exists(place)):
        # run_vpr.sh pattern + a PINNED placement seed: VPR's default seed-1
        # placement of uart_loopback congests the v2c pruned-CB fabric
        # (PathFinder overuse 7 at 200 iters); seeds {3,5,6,8} all converge
        # (measured 2026-09-08, E1-DMO1 report) — 3 is pinned for
        # reproducibility (pwm is placement-insensitive; 1 = VPR default).
        arch = os.path.join(os.path.dirname(RUN_VPR), "arch_ethereal.xml")
        _run([os.environ.get("VPR", os.path.expanduser("~/vtr/build/vpr/vpr")),
              arch, os.path.join(MAPPER, f"{name}.blif"),
              "--pack", "--place", "--route", "--route_chan_width", ROUTE_CHAN_W,
              "--analysis", "--disp", "off", "--outfile_prefix",
              f"{name}_w{ROUTE_CHAN_W}_", "--seed", str(cfg["vpr_seed"])],
             f"vpr {name} (seed {cfg['vpr_seed']})", cwd=MAPPER)
    return net, place, blif


# =============================================================================
# Target-geometry frame packing (bbox-normalized + blank padding)
# =============================================================================

def pack_target_frames(
    db: FabricConfigDB, rc: RouteConfig, fg: FabricGen,
) -> tuple[list[list[int]], tuple[int, int]]:
    """Pack CLB+routing onto the DESCRIPTOR grid (fg.fm geometry).

    Tiles normalize to ``(col, row) = (x - min_x, y - min_y)`` of the placed
    bbox and must fit the descriptor; rows/columns beyond the bbox pack BLANK
    (all-zero config — a legal unconfigured tile). Returns
    ``(frames_with_crc_tails, (min_x, min_y))``.
    """
    fm = fg.fm
    min_x, min_y, max_x, max_y = db_grid_bounds(db)
    if max_x - min_x + 1 > fm.C or max_y - min_y + 1 > fm.R:
        raise RuntimeError(
            f"placed bbox {max_x - min_x + 1}x{max_y - min_y + 1} does not fit "
            f"the {fg.R}x{fg.C} descriptor {fg.name}")
    frames: list[list[int]] = []
    for c in range(fm.C):
        col_config: list[dict[str, int]] = []
        for r in range(fm.R):
            tile = db.tiles.get((c + min_x, r + min_y))
            rt = rc.tiles.get((r, c))
            if tile is not None or rt is not None:
                from bitgen_db import TileLogic
                col_config.append(tile_to_full_points(
                    tile if tile is not None else TileLogic(), rt))
            else:
                col_config.append({})
        frames.append(fm.pack(col_config))
    return frames, (min_x, min_y)


def unpack_attached(
    frames: list[list[int]], fg: FabricGen, db: FabricConfigDB,
    rc: RouteConfig, offset: tuple[int, int],
) -> tuple[FabricConfigDB, RouteConfig]:
    """Inverse of :func:`pack_target_frames` + net-name re-attachment.

    Frames -> (db2, rc2) over the descriptor grid (origin 0,0), then the
    LEVEL-1 netlist context (cluster_inputs/outputs, primary I/O, po_aliases)
    is re-attached by TRANSLATED tile coord — the documented apply-time step
    (bitgen_pack module docstring: frames carry config bits, not net names).
    """
    fm = fg.fm
    min_x, min_y = offset
    db2 = frames_to_db(frames, fm, 0, 0)
    rc2 = frames_to_route(frames, fm)
    db2.primary_inputs = list(db.primary_inputs)
    db2.primary_outputs = list(db.primary_outputs)
    db2.po_aliases = dict(db.po_aliases)
    for (x, y), tl in db.tiles.items():
        dst = db2.tiles.get((x - min_x, y - min_y))
        if dst is not None:
            dst.cluster_inputs = dict(tl.cluster_inputs)
            dst.cluster_outputs = dict(tl.cluster_outputs)
    return db2, rc2


# =============================================================================
# Ed25519 keyring (daemon trust anchor) — sign with KEY_SEED, verify with the
# RAW 32 bytes compiled into keyring.h (proves the daemon-side verify passes)
# =============================================================================

def signer_pem() -> bytes:
    """PKCS8 PEM of the deterministic KEY_SEED key (= daemon keyring.h key)."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    sk = Ed25519PrivateKey.from_private_bytes(KEY_SEED)
    return sk.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption())


def keyring_pub_pem() -> bytes:
    """SPKI PEM built from the RAW 32 bytes in daemon keyring.h.

    The daemon firmware verifies against these raw bytes; rebuilding the SPKI
    wrapper here lets ethimg.verify prove the SAME key trusts our images.
    """
    txt = Path(KEYRING_H).read_text(encoding="utf-8")
    body = re.search(r"ETH_TRUSTED_PK\[32\]\s*=\s*\{(.*?)\}", txt, re.DOTALL)
    if body is None:
        raise RuntimeError(f"cannot parse ETH_TRUSTED_PK from {KEYRING_H}")
    raw = bytes(int(tok, 0) for tok in re.findall(r"0x[0-9a-fA-F]+", body.group(1)))
    if len(raw) != 32:
        raise RuntimeError(f"keyring pubkey is {len(raw)} bytes, expected 32")
    der = bytes.fromhex("302a300506032b6570032100") + raw   # Ed25519 SPKI prefix
    b64 = base64.b64encode(der).decode()
    lines = [b64[i:i + 64] for i in range(0, len(b64), 64)]
    return ("-----BEGIN PUBLIC KEY-----\n"
            + "\n".join(lines) + "\n-----END PUBLIC KEY-----\n").encode()


# =============================================================================
# Image build: flow -> route -> frames -> .eth -> session JSON
# =============================================================================

def build_image(name: str, out_dir: str, ethctl_dir: str) -> dict:
    cfg = IMAGES[name]
    fg = FabricGen.from_file(os.path.join(FABRIC_DIR, f"{cfg['fabric']}.yaml"))
    net, place, blif = ensure_flow(name)
    db = build_db(net, place, blif)
    rc = route(db, max_iters=200, seed=0)
    if not rc.converged:
        raise RuntimeError(f"{name}: PathFinder did not converge on the "
                           f"{fg.R}x{fg.C} grid")
    n_elut = sum(len(tl.eluts) for tl in db.tiles.values())
    n_ff = sum(1 for tl in db.tiles.values() for ec in tl.eluts.values()
               if ec.ff_en)
    frames, offset = pack_target_frames(db, rc, fg)

    # staging tree -> ethimg pack
    src = Path(out_dir) / f"{name}_src"
    tdir = src / "targets"
    tdir.mkdir(parents=True, exist_ok=True)
    data_words = [w for col in frames for w in col[:-1]]   # CRC tails excluded
    (tdir / f"{cfg['fabric']}.frames").write_bytes(
        b"".join(w.to_bytes(4, "little") for w in data_words))
    (tdir / f"{cfg['fabric']}.meta.json").write_text(__import__("json").dumps({
        "fabric": cfg["fabric"], "R": fg.R, "C": fg.C,
        "columns": fg.C, "column_data_words": fg.fm.data_words_per_frame,
        "total_data_words": len(data_words),
        "elut": n_elut, "ff": n_ff,
        "top": cfg["top"], "source": f"ethereal-images/benchmarks/{cfg['bench']}",
    }, indent=2) + "\n")
    eth_path = Path(out_dir) / f"{name}.eth"
    ethimg.pack(src, eth_path, name=f"demo-{name}", version="0.1.0",
                author="E1-DMO1 demo_images", target=cfg["fabric"],
                privkey_pem=signer_pem())

    # daemon-keyring verify (integrity + signature vs the RAW keyring bytes)
    man = ethimg.verify(eth_path, trusted_pubkeys=[keyring_pub_pem()])

    # run_packed session JSON (ethereal.efp-session.v0, tb_ethctl_replay schema)
    client = EfpClient(num_regions=cfg["num_regions"])
    ops, img = client.run_packed(eth_path, region=0,
                                 column_words=fg.fm.data_words_per_frame)
    sess = Path(ethctl_dir) / f"session_run_packed_{name}.json"
    write_session(ops, sess, name=f"run_packed {name}", image=img, region=0)

    return {
        "name": name, "eth": str(eth_path), "manifest_digest": man.manifest_digest,
        "session": str(sess), "elut": n_elut, "ff": n_ff,
        "fabric": cfg["fabric"], "R": fg.R, "C": fg.C,
        "column_data_words": fg.fm.data_words_per_frame,
        "frames": frames, "db": db, "rc": rc, "fg": fg, "offset": offset,
    }


_FORCE = False


def main(argv: list[str] | None = None) -> int:
    global _FORCE
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--out-dir", default=os.path.normpath(os.path.join(
        here, "..", "..", "..", "..", "ethereal-images", "demos")))
    ap.add_argument("--ethctl-dir", default=os.path.join(_REPO, "generated",
                                                         "ethctl"))
    ap.add_argument("--force", action="store_true",
                    help="re-run synth/VPR even if artifacts exist")
    args = ap.parse_args(argv)
    _FORCE = args.force
    os.makedirs(args.out_dir, exist_ok=True)
    os.makedirs(args.ethctl_dir, exist_ok=True)
    for name in IMAGES:
        info = build_image(name, args.out_dir, args.ethctl_dir)
        print(f"[demo_images] {name}: {info['elut']} eLUT ({info['ff']} FF) on "
              f"{info['fabric']} ({info['R']}x{info['C']}, "
              f"{info['column_data_words']} DATA words/col) -> "
              f"{info['eth']} (digest {info['manifest_digest'][:16]})")
        print(f"[demo_images]   session: {info['session']}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
