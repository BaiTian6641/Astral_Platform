#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# E3-SVC1 — NPU-Tiny tile post-route Fmax / resource measurement on GW5AST-138.
#
# Reproduces the numbers in docs/reports/report-E3-SVC1-npu-tiny-20260913.md with
# the E1-PLT4 / E2-FAB2 flow, in two mappings:
#   * LUT-mapped  : yosys `synth_gowin -family gw5a` (it performs NO gw5a DSP
#                   inference — E2-FAB2 finding) -> nextpnr-himbaechel.
#   * DSP-forced  : the E2-FAB2b recipe (techmap mul2dsp + dsp_map_27x18.v) ->
#                   synth_gowin -> nextpnr-himbaechel, so the 64 PE multiplies
#                   land on MULTALU27X18 sites.
#
# Prereqs:  oss-cad-suite on PATH (yosys 0.67+, nextpnr-himbaechel 0.10+).
# Outputs:  generated/npu_fmax/  (gitignored scratch: netlists, P&R logs, reports).
#
# Usage:  bash ethereal-fabric/tests/npu/synth/run_npu_fmax.sh [--dsp-only|--lut-only]
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
KIT="$REPO/ethereal-fabric/tests/npu/synth"
OUT="${OUT:-$REPO/generated/npu_fmax}"
DEV=${DEV:-GW5AST-LV138PG484AC1/I0}
FREQ=${FREQ:-100}

mkdir -p "$OUT"
cp "$KIT/probe_npu.sv" "$KIT/probe.cst" "$KIT"/dsp_map_27x18.v \
   "$KIT"/synth_npu*.ys "$OUT"/

do_lut=1; do_dsp=1
case "${1:-}" in
  --dsp-only) do_lut=0 ;;
  --lut-only) do_dsp=0 ;;
  "") ;;
  *) echo "unknown option $1" >&2; exit 2 ;;
esac

cd "$OUT"
# The .ys scripts read the RTL with paths relative to generated/npu_fmax/, so run
# them from a directory two levels below the repo root.
run_nextpnr() {  # $1 = design base name
  # NOTE: nextpnr exits non-zero when the achieved Fmax misses --freq (the LUT-mapped
  # build does: 61.7 MHz vs a 100 MHz target). The routed JSON/report are still
  # written, so the measurement is captured either way — do not abort on it.
  nextpnr-himbaechel --json "$1-synth.json" --write "$1-pnr.json" \
      --device "$DEV" --vopt cst=probe.cst --freq "$FREQ" --ignore-loops \
      --report "$1-pnr_report.json" > "nextpnr_$1.log" 2>&1 || true
  echo "--- $1 post-route ---"
  grep -E "Max frequency" "nextpnr_$1.log" | tail -1 || true
  python3 - "$1" <<'PYEOF'
import sys
log = open("nextpnr_%s.log" % sys.argv[1]).read()
i = log.find("Info: Device utilisation")
if i >= 0:
    for line in log[i:i+2200].split("\n"):
        for key in ("LUT4:", "ALU:", "DFF:", "MUX2_LUT5:", "MULTALU27X18:", "BSRAM:", "RAM16SDP4:"):
            if key in line:
                print(line.strip())
PYEOF
}

if [ "$do_lut" = 1 ]; then
  yosys -l yosys_npu_lut.log -s synth_npu.ys > /dev/null 2>&1
  run_nextpnr probe_npu
fi

if [ "$do_dsp" = 1 ]; then
  yosys -l yosys_npu_dsp.log -s synth_npu_dsp.ys > /dev/null 2>&1
  yosys -l yosys_npu_dsp_stage2.log -s synth_npu_dsp_stage2.ys > /dev/null 2>&1
  run_nextpnr probe_npu_dsp
fi
