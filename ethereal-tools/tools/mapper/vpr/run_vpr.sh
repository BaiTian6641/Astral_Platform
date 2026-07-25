#!/usr/bin/env bash
# run_vpr.sh — pack / place / route a netlist on arch_ethereal.xml (E0-MAP2).
#
# Runs VPR's full flow (pack -> place -> route -> timing analysis) on a
# synth_ethereal-produced BLIF, printing the critical-path / timing report.
# Outputs (.net/.place/.route/.log) land in generated/mapper/ for E0-MAP3 bitgen.
#
# Usage:  bash run_vpr.sh <netlist_basename> [route_chan_width]
#   e.g.   bash run_vpr.sh c17 12        # smoke
#          bash run_vpr.sh c432 12       # E0-MAP2 acceptance
set -uo pipefail
NET="${1:?usage: run_vpr.sh <netlist_basename> [W]}"
W="${2:-12}"
# REPO root = 4 levels up from this script (.../ethereal-tools/tools/mapper/vpr/)
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VPR="${VPR:-$HOME/vtr/build/vpr/vpr}"
ARCH="$REPO/ethereal-tools/tools/mapper/vpr/arch_ethereal.xml"
WORK="$REPO/generated/mapper"

if [[ ! -x "$VPR" ]]; then echo "vpr not built at $VPR"; exit 1; fi
if [[ ! -f "$WORK/$NET.blif" ]]; then echo "missing $WORK/$NET.blif (run synth_ethereal first)"; exit 1; fi

cd "$WORK"
echo "=== VPR $NET on arch_ethereal.xml (W=$W) ==="
"$VPR" "$ARCH" "$NET.blif" \
  --pack --place --route \
  --route_chan_width "$W" \
  --analysis \
  --disp off \
  --outfile_prefix "${NET}_w${W}_" \
  2>&1 | tee "${NET}_w${W}.log"
rc=${PIPESTATUS[0]}
echo "=== [rc $rc] — outputs: ${NET}_w${W}_*.{{net,place,route,log}} ==="
exit $rc
