# SPDX-License-Identifier: MIT
"""Scratch debug: per-tick FF-state compare vs a Python model of uart_loopback.v."""
from __future__ import annotations

import os
import sys
import pickle

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from demo_images import ensure_flow  # noqa: E402
from bitgen_db import build_db  # noqa: E402
from bitgen_pack import db_grid_bounds  # noqa: E402
import fabric_sim  # noqa: E402

CACHE = os.path.join(_HERE, "_debug_uart_cache.pkl")


def get_db_rc():
    if os.path.exists(CACHE):
        with open(CACHE, "rb") as f:
            return pickle.load(f)
    net, place, blif = ensure_flow("uart_loopback")
    db = build_db(net, place, blif)
    from bitgen_route import route
    rc = route(db, max_iters=200, seed=0)
    with open(CACHE, "wb") as f:
        pickle.dump((db, rc), f)
    return db, rc


# ---------------- Python reference of uart_loopback.v (CPB=87) --------------
CPB = 87
FULL = CPB - 1   # 86
HALF = CPB // 2  # 43


class Ref:
    def __init__(self):
        self.rx_data = 0
        self.rx_cnt = 0
        self.rxs = 0
        self.tx_state = 0
        self.tx_cnt = 0
        self.tx_bit = 0
        self.txs = 0
        self.tx = 0

    def state(self):
        return {
            "rx_data": self.rx_data, "rx_cnt": self.rx_cnt, "rxs": self.rxs,
            "tx_state": self.tx_state, "tx_cnt": self.tx_cnt,
            "tx_bit": self.tx_bit, "txs": self.txs, "tx": self.tx,
        }

    def step(self, rx) -> int:
        rx_mid = 1 if self.rx_cnt == HALF else 0
        rx_bend = 1 if self.rx_cnt == FULL else 0
        rx_stop = (self.rxs >> 1) & 1
        rx_accept = self.rx_data & rx_bend & rx_stop & rx
        tx_bend = 1 if self.tx_cnt == FULL else 0

        n = dict(rx_data=self.rx_data, rx_cnt=self.rx_cnt, rxs=self.rxs,
                 tx_state=self.tx_state, tx_cnt=self.tx_cnt,
                 tx_bit=self.tx_bit, txs=self.txs, tx=self.tx)
        if not self.rx_data:
            if not rx:
                if rx_mid:
                    n["rx_data"], n["rx_cnt"], n["rxs"] = 1, 0, 0b1000000000
                else:
                    n["rx_cnt"] = (self.rx_cnt + 1) & 0x7F
            else:
                n["rx_cnt"] = 0
        else:
            if rx_bend:
                n["rx_cnt"] = 0
                if rx_stop:
                    n["rx_data"] = 0
                else:
                    n["rxs"] = ((rx << 9) | (self.rxs >> 1)) & 0x3FF
            else:
                n["rx_cnt"] = (self.rx_cnt + 1) & 0x7F
        if self.tx_state == 0:
            n["tx"] = 1
            if rx_accept:
                n["txs"] = sum(((self.rxs >> (9 - i)) & 1) << i
                               for i in range(8))
                n["tx_state"], n["tx_cnt"] = 1, 0
        elif self.tx_state == 1:
            n["tx"] = 0
            if tx_bend:
                n["tx_cnt"], n["tx_bit"], n["tx_state"] = 0, 0, 2
            else:
                n["tx_cnt"] = (self.tx_cnt + 1) & 0x7F
        else:
            n["tx"] = (self.txs >> 7) & 1
            if tx_bend:
                n["tx_cnt"] = 0
                n["txs"] = ((self.txs << 1) | 1) & 0xFF
                if self.tx_bit == 7:
                    n["tx_bit"], n["tx_state"] = 0, 0
                else:
                    n["tx_bit"] = self.tx_bit + 1
            else:
                n["tx_cnt"] = (self.tx_cnt + 1) & 0x7F
        for k, v in n.items():
            setattr(self, k, v)
        return rx_accept


# ---------------- stimulus (same shape as _uart_streams, one frame) ----------
def uart_frame(byte, stop=1):
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [stop]
    return [b for b in bits for _ in range(CPB)]


def stream():
    s = [1] * (2 * CPB)
    s += uart_frame(0x55) + [1] * (2 * CPB)
    return s


def main():
    db, rc = get_db_rc()
    min_x, min_y, _mx, _my = db_grid_bounds(db)
    sim = fabric_sim.FabricSim(db, rc, min_x, min_y)
    print(f"grid R={sim.R} C={sim.C} min=({min_x},{min_y})")

    # name map: (r,c,gi) -> net, and the FF eLUT set
    nm: dict[tuple[int, int, int], str] = {}
    ff_keys: set[tuple[int, int, int]] = set()
    for (x, y), tl in db.tiles.items():
        r, c = y - min_y, x - min_x
        for gi, net in tl.cluster_outputs.items():
            if net:
                nm[(r, c, gi)] = net
        for gi, ec in tl.eluts.items():
            if ec.ff_en:
                ff_keys.add((r, c, gi))
    named = sorted(nm[k] for k in ff_keys if k in nm)
    print(f"{len(ff_keys)} FF eLUTs across {len({(r, c) for r, c, _g in ff_keys})} tiles")
    unnamed = [k for k in ff_keys if not nm.get(k)]
    if unnamed:
        print(f"UNNAMED FF keys: {unnamed}")
    if len(named) != len(set(named)):
        dupes = [x for x in named if named.count(x) > 1]
        print(f"DUPLICATE FF names: {sorted(set(dupes))}")

    def sim_fields(st):
        f: dict[str, int] = {}
        for (r, c, gi), v in st.items():
            net = nm.get((r, c, gi))
            if net is None:
                continue
            if net == "rx_data":
                f["rx_data"] = v
            elif net == "tx":
                f["tx"] = v
            elif net.startswith("rx_cnt["):
                f["rx_cnt"] = f.get("rx_cnt", 0) | (v << int(net[7:-1]))
            elif net.startswith("tx_cnt["):
                f["tx_cnt"] = f.get("tx_cnt", 0) | (v << int(net[7:-1]))
            elif net.startswith("rxs["):
                f["rxs"] = f.get("rxs", 0) | (v << int(net[4:-1]))
            elif net == "rx_stop":
                f["rxs"] = f.get("rxs", 0) | (v << 1)
            elif net.startswith("txs["):
                f["txs"] = f.get("txs", 0) | (v << int(net[4:-1]))
            elif net.startswith("tx_bit["):
                f["tx_bit"] = f.get("tx_bit", 0) | (v << int(net[7:-1]))
            elif net.startswith("tx_state["):
                f["tx_state"] = f.get("tx_state", 0) | (v << int(net[9:-1]))
        return f

    ref = Ref()
    state: dict = {}
    stim = stream()
    first_div = None
    for t, rx in enumerate(stim):
        accept = ref.step(rx)
        po, nxt = sim.tick({"rx": rx}, state)
        state = nxt
        got = sim_fields(state)
        want = ref.state()
        diff = {k for k in want if got.get(k) != want[k]}
        if diff and first_div is None:
            first_div = t
            print(f"\n=== FIRST STATE DIVERGENCE at tick {t} (rx={rx}) ===")
            for k in sorted(want):
                print(f"  {k:9s} sim={got.get(k)} ref={want[k]}"
                      f"{'   <-- DIFF' if k in diff else ''}")
            break
        if t in (215, 216, 217, 218, 302, 303, 304, 305, 999, 1000, 1001):
            print(f"tick {t:5d} rx={rx} acc={accept} "
                  f"rx_cnt={got.get('rx_cnt')}/{want['rx_cnt']} "
                  f"rx_data={got.get('rx_data')}/{want['rx_data']} "
                  f"rxs={got.get('rxs', 0):03x}/{want['rxs']:03x} "
                  f"tx_state={got.get('tx_state')}/{want['tx_state']} "
                  f"tx_po={po.get('tx')} tx_ff={got.get('tx')}/{want['tx']}")
    if first_div is None:
        print("no state divergence through the whole stream")


if __name__ == "__main__":
    main()
