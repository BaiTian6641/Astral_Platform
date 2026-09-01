# hal/gowin_gw5 — GW5 host mapping layer (E1-PLT1)

> Plan-Ref: `ethereal-plan/components/C13-跨平台推断策略.md` (ADR-017, inference-first) ·
> `ethereal-plan/components/C12-平台组件.md` §1 (HAL restructure: inference templates + thin glue) ·
> Report: `docs/reports/report-E1-PLT1-hal-gowin-20260901.md`

## Purpose

This directory is the **only** place in the repository where Gowin GW5A vendor
primitives may be named (ADR-017 / C13 §4 exception list). All fabric/Shell
own-RTL stays behavioral; the platform EDA infers DSP/BSRAM from the
`eth_inf_*` templates. The glue here exists for two reasons:

1. **Non-inferable resources** (PLL/OSC, later ADC/Flash-MSPI) need a vendor
   primitive somewhere — that somewhere is `glue/`, paired with a
   Verilator-safe behavioral stub selected at the file-list level.
2. **Inference escape hatch**: if a Gowin-EDA build ever loses inference for a
   template (detected by the C13 §6 infer_check suite), the fix is a
   `GOWIN_PRIMITIVE`-guarded primitive mapping inside `glue/` — never an edit
   to tracked own-RTL under `ethereal-fabric/rtl/`.

## Layout

```
hal/gowin_gw5/
├── README.md                  ← this file
├── glue/                      ← vendor-glue modules (C13 §4 exception zone)
│   ├── gowin_bsram.sv         ← BSRAM host mapping for eth_inf_ram
│   ├── gowin_dsp.sv           ← DSP host mapping for eth_inf_dsp_mac (27x18 MAC)
│   └── gowin_clkstub.sv       ← clock/PLL glue placeholder (C12 §2 hal_pll slot)
├── probe/                     ← synthesis measurement scripts (open chain)
│   └── synth_stat.sh          ← yosys synth_gowin per-module LUT/DFF census
└── boards/
    └── tangmega138k.md        ← Tang Mega 138K Dock board notes (pins TBD)
```

## How builds consume the glue

Every glue module has two branches selected by one define:

| Define | Who uses it | What happens |
|---|---|---|
| *(none)* — DEFAULT | Verilator lint/sim, iverilog TBs, yosys/nextpnr open chain, CI | Behavioral branch: instantiates the `eth_inf_*` template (or a pure-behavioral clock stub). **Zero vendor identifiers compiled.** |
| `GOWIN_PRIMITIVE` | Gowin-EDA builds only (GowinSynthesis project, e.g. gw_sh tcl `-define GOWIN_PRIMITIVE`) | Vendor-primitive branch. Today this is **documentation-in-code** (commented reference instantiation + a deliberate elaboration-time `$error`): the exact GW5A primitive parameter spellings are a G6 open item pending verification against the licensed primitive library. |

- **Open chain (yosys `synth_gowin -family gw5a` + nextpnr-himbaechel):**
  never define `GOWIN_PRIMITIVE`. Inference is the supported path
  (E1-PLT4 spike proved the full chain on the real 4×4 fabric).
- **Gowin-EDA chain (E1-PLT2 base-image builds):** start with the default
  branch as well — GowinSynthesis officially supports DSP/memory inference
  (SUG550E §4.3/§2). Only if the C13 §6 infer_check suite flags a
  silent-degradation (RAM/DSP silently synthesized as LUT fabric) do we
  complete the `GOWIN_PRIMITIVE` branch bindings.
- **Attribute steering** (per-target `syn_ramstyle` / `syn_dspstyle` /
  `use_dsp` / …) lives in the single attribute layer
  `ethereal-fabric/rtl/inf/eth_config.svh` (C13 §2.5), NOT in this directory.

## Stub philosophy (ADR-017)

The behavioral stub is not a second implementation of the vendor hard block —
it models only what the surrounding own-RTL can observe: port-level handshake
(e.g. PLL `lock_o` timing for the C12 §2.2 reset sequencer), not analog/physical
behavior. Contract: the default branch must elaborate under
`verilator --lint-only -Wall` (clean), `iverilog -g2012`, and
`yosys read_verilog -sv` without any vendor library on the file list.

## Lint / build integration status

`make lint` in the root Makefile uses an **explicit file list** (`RTL_CLEAN`);
`hal/` is not globbed and this task deliberately does NOT edit the Makefile.
The glue is nonetheless verified standalone:

```bash
verilator --lint-only -Wall -Iethereal-fabric/rtl/inf \
    ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv \
    ethereal-fabric/hal/gowin_gw5/glue/*.sv --top-module <gowin_bsram|gowin_dsp|gowin_clkstub>
iverilog -g2012 -I ethereal-fabric/rtl/inf \
    ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv \
    ethereal-fabric/hal/gowin_gw5/glue/*.sv -o /tmp/glue_smoke.vvp
```

Adding `hal/**/glue/*.sv` to the main lint gate is a maintainer decision
(root Makefile edit), to be taken together with the C13 §4 CI grep gate
(no vendor primitive names outside `hal/<vendor>/glue/`).

## Overhead probe

`probe/synth_stat.sh` reproduces the physical-LUT overhead census behind the
E1-PLT1 acceptance metric (yosys-only, no nextpnr; ~2–3 min total):

```bash
export PATH=$HOME/oss-cad-suite/bin:$PATH
ethereal-fabric/hal/gowin_gw5/probe/synth_stat.sh   # writes generated/hal_probe/
```

## Open items (G6)

1. Tang Mega 138K Dock main crystal frequency + clock-capable pin —
   unconfirmed (C12 §6 #1); `gowin_clkstub` parameters are ASSUMPTION
   placeholders (TBD, 2026-09-01).
2. GW5A primitive spellings (`SDPX9B` / `MULT27X18` / `ALU54D` / `rPLL`
   parameter encodings) — to be verified against the licensed Gowin primitive
   library before any `GOWIN_PRIMITIVE` build is enabled.
3. `lat_sel_i` runtime latency tap has no in-DSP primitive equivalent; a
   primitive DSP build must freeze LAT at build time or add fabric muxes.
4. E1-PLT1 acceptance target (≤45:1 physical:virtual LUT @ 4×4) is **not met**
   by the v1.1 fabric (measured ≈308:1); see the report for the per-block
   breakdown and the E2-FAB5 recommendation.
