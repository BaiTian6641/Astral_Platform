#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# File:        synth_stat.sh
# Description: E1-PLT1 physical-LUT overhead probe for the GW5 host mapping
#              layer. Synthesizes each fabric block standalone plus the
#              homogeneous fabric_top at 1x1 / 2x2 / 4x4 with yosys
#              `synth_gowin -family gw5a` and collects the `stat` cell census
#              into a CSV + Markdown table. Yosys-only (no nextpnr): each run
#              is seconds; the 4x4 run is ~75 s.
# Maintainer:  BaiTian6641
# Created:     2026-09-01
# Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §6 (infer_check)
#              · docs/ethereal-tasks.yaml E1-PLT1 (acceptance: <=45:1)
# Usage:       export PATH=$HOME/oss-cad-suite/bin:$PATH
#              ethereal-fabric/hal/gowin_gw5/probe/synth_stat.sh [scratch_dir]
# Notes:       Tracked RTL is NEVER modified. The two yosys-SV-frontend
#              `return`-in-function sites (fabric_top.sv, occ_top.sv — see
#              report-E1-PLT4) are worked around by scratch-only preprocessed
#              copies under the scratch dir (default generated/hal_probe/).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCRATCH="${1:-$REPO_ROOT/generated/hal_probe}"
RTL="$REPO_ROOT/ethereal-fabric/rtl"
YOSYS="${YOSYS:-yosys}"

mkdir -p "$SCRATCH/src" "$SCRATCH/stat" "$SCRATCH/ys"
cd "$SCRATCH"

# ---------------------------------------------------------------------------
# 1. Scratch-only preprocessing: `return <expr>;` -> `<fname> = <expr>;`
#    (yosys built-in SV frontend lacks `return`; spike-documented workaround).
#    Fail loudly if the tracked source drifts and the sed no longer matches.
# ---------------------------------------------------------------------------
sed 's/return TILE_TYPE\[idx\*8 +: 8\];/tile_type_at = TILE_TYPE[idx*8 +: 8];/' \
    "$RTL/interconnect/fabric_top.sv" > src/fabric_top_yosys.sv
grep -q 'tile_type_at = TILE_TYPE\[idx\*8 +: 8\];' src/fabric_top_yosys.sv \
    || { echo "ERROR: fabric_top.sv return-site drifted; update the sed rule" >&2; exit 1; }
grep -q 'return TILE_TYPE' src/fabric_top_yosys.sv \
    && { echo "ERROR: fabric_top.sv still contains a return site" >&2; exit 1; } || true

sed 's/^\(\s*\)return c;/\1crc32_next = c;/' \
    "$RTL/occ/occ_top.sv" > src/occ_top_yosys.sv
grep -q 'crc32_next = c;' src/occ_top_yosys.sv \
    || { echo "ERROR: occ_top.sv return-site drifted; update the sed rule" >&2; exit 1; }
grep -q 'return c;' src/occ_top_yosys.sv \
    && { echo "ERROR: occ_top.sv still contains a return site" >&2; exit 1; } || true

# ---------------------------------------------------------------------------
# 2. Target list: name|top|read-files|chparam-line
#    (read order: leaf modules first; fabric uses the preprocessed copy).
# ---------------------------------------------------------------------------
ELUT4="$RTL/clb/elut4.sv"
CLB="$RTL/clb/clb_t.sv"
SB="$RTL/interconnect/switch_box.sv"
CB="$RTL/interconnect/connection_block.sv"
MEM="$RTL/tile/mem_t.sv"
DSP="$RTL/tile/dsp_t.sv"
INF="$RTL/inf/eth_inf_ram.sv $RTL/inf/eth_inf_dsp_mac.sv"
FABRIC_DEPS="$ELUT4 $CLB $SB $CB $MEM $DSP $INF src/fabric_top_yosys.sv"

TARGETS=(
    "elut4|elut4|$ELUT4|"
    "clb_t|clb_t|$ELUT4 $CLB|"
    "switch_box|switch_box|$SB|"
    "connection_block|connection_block|$CB|"
    "occ_top|occ_top|src/occ_top_yosys.sv|"
    "fabric_1x1|fabric_top|$FABRIC_DEPS|chparam -set R 1 -set C 1 fabric_top"
    "fabric_2x2|fabric_top|$FABRIC_DEPS|chparam -set R 2 -set C 2 fabric_top"
    "fabric_4x4|fabric_top|$FABRIC_DEPS|"
)

run_synth() {  # name top files chparam
    local name="$1" top="$2" files="$3" chparam="$4"
    {
        echo "read_verilog -sv $files"
        [[ -n "$chparam" ]] && echo "$chparam"
        echo "synth_gowin -top $top -family gw5a -noiopads"
        echo "tee -o stat/${name}.stat stat"
    } > "ys/${name}.ys"
    echo "== synth $name (top=$top) ..."
    # -Q -q: drop the banner + the (voluminous) Wilton-loop warnings; the stat
    # census is captured via tee. Elaboration errors still exit non-zero.
    "$YOSYS" -Q -q -s "ys/${name}.ys" >/dev/null
}

for t in "${TARGETS[@]}"; do
    IFS='|' read -r name top files chparam <<< "$t"
    run_synth "$name" "$top" "$files" "$chparam"
done

# ---------------------------------------------------------------------------
# 3. Parse the stat census -> CSV + Markdown.
# ---------------------------------------------------------------------------
python3 - "$SCRATCH" <<'PYEOF'
import re, sys, pathlib

scratch = pathlib.Path(sys.argv[1])
order = ["elut4", "clb_t", "switch_box", "connection_block", "occ_top",
         "fabric_1x1", "fabric_2x2", "fabric_4x4"]
# virtual eLUT4 count per target (8 per tile; standalone blocks expose N=8)
virt = {"elut4": 1, "clb_t": 8, "switch_box": 0, "connection_block": 0,
        "occ_top": 0, "fabric_1x1": 8, "fabric_2x2": 32, "fabric_4x4": 128}
CELLS = ["LUT1", "LUT2", "LUT3", "LUT4", "MUX2_LUT5", "MUX2_LUT6",
         "MUX2_LUT7", "MUX2_LUT8", "DFF", "DFFRE", "DFFS", "ALU",
         "BSRAM", "DSP", "IOB"]

rows = {}
for name in order:
    text = (scratch / "stat" / f"{name}.stat").read_text()
    counts = {c: 0 for c in CELLS}
    for m in re.finditer(r"^\s+(\d+)\s+(\w[\w$]*)\s*$", text, re.M):
        n, cell = int(m.group(1)), m.group(2)
        if cell in counts:
            counts[cell] = n
    lut = sum(counts[c] for c in ("LUT1", "LUT2", "LUT3", "LUT4"))
    mux = sum(counts[c] for c in ("MUX2_LUT5", "MUX2_LUT6",
                                  "MUX2_LUT7", "MUX2_LUT8"))
    dff = sum(v for k, v in counts.items() if k.startswith("DFF"))
    rows[name] = dict(counts, LUT_TOT=lut, MUX_TOT=mux, DFF_TOT=dff)

hdr = ["target", "virt_eLUT4", "LUT1-4", "MUX2_LUT5-8", "DFF(all)", "ALU",
       "LUT1", "LUT2", "LUT3", "LUT4", "MUX5", "MUX6", "MUX7", "MUX8",
       "DFF", "DFFRE", "LUT:virt_ratio"]
csv = [",".join(hdr)]
md = ["| " + " | ".join(["target", "virt eLUT4", "LUT1-4", "MUX2_LUT5-8",
                          "DFF (all)", "ALU", "LUT:virt"]) + " |",
      "|" + "---|" * 7]
for name in order:
    r = rows[name]
    v = virt[name]
    ratio = f"{r['LUT_TOT'] / v:.1f}:1" if v else "-"
    csv.append(",".join(map(str, [
        name, v, r["LUT_TOT"], r["MUX_TOT"], r["DFF_TOT"], r["ALU"],
        r["LUT1"], r["LUT2"], r["LUT3"], r["LUT4"], r["MUX2_LUT5"],
        r["MUX2_LUT6"], r["MUX2_LUT7"], r["MUX2_LUT8"],
        r["DFF"], r["DFFRE"], ratio])))
    md.append("| {} | {} | {} | {} | {} | {} | {} |".format(
        name, v, r["LUT_TOT"], r["MUX_TOT"], r["DFF_TOT"], r["ALU"], ratio))

(scratch / "synth_stat.csv").write_text("\n".join(csv) + "\n")
(scratch / "synth_stat.md").write_text("\n".join(md) + "\n")
print("\n".join(md))
print("\nwrote:", scratch / "synth_stat.csv", "and synth_stat.md")
PYEOF

echo "DONE. Scratch: $SCRATCH"
