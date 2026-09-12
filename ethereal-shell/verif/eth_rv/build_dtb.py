#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compile the checked-in ``eth_rv.dts`` into the harness's DTB build output.

The device tree is checked in as source (``verif/eth_rv/eth_rv.dts``); this step
turns it into the blob the harness loads:

* ``run_difftest.py --dtb eth_rv.dts`` compiles it on demand (so a run always
  uses the current source), and
* this script writes the same blob to the stable build path so a person or the
  testbench can point at it directly:

      python3 ethereal-shell/verif/eth_rv/build_dtb.py
      # -> generated/rv_difftest/eth_rv.dtb

It uses the same ``dtc`` resolution as the rest of the harness: an explicit
``--dtc``, ``$RV_DIFFTEST_DTC``, the build under ``generated/rv_difftest/dtc``,
then ``$PATH``.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from rv_platform import dtb_path, dts_path
from rv_spike import SpikeError, compile_dts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dts", type=Path, default=None, help="device tree source (default: the checked-in one)")
    parser.add_argument("--out", type=Path, default=None, help="blob to write (default: the build output)")
    parser.add_argument("--dtc", type=Path, default=None, help="dtc binary to use")
    args = parser.parse_args(argv)
    source = args.dts if args.dts is not None else dts_path()
    if source is None or not source.is_file():
        sys.stderr.write(f"[eth_rv dt] error: device tree source not found: {source}\n")
        return 2
    out = args.out if args.out is not None else dtb_path()
    if out is None:
        sys.stderr.write("[eth_rv dt] error: cannot locate the repository root\n")
        return 2
    try:
        blob = compile_dts(source, out, dtc=args.dtc)
    except SpikeError as exc:
        sys.stderr.write(f"[eth_rv dt] error: {exc}\n")
        return 2
    print(f"[eth_rv dt] {source.name} -> {blob} ({blob.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
