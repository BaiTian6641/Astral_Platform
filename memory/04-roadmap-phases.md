# Roadmap & Phases — Ethereal Platform

> Solo maintainer, ~8-15h/week. Each phase has circuit-breaker (防烂尾 key design). All tasks `status: todo`.
> Synced from `/memories/repo/roadmap-phases.md`.

## Phase 0 progress log (2026-07-24)
- **Wk1 infrastructure ✅ (committed `78ab251`):** E0-INF1 (8-repo skeleton) + E0-INF2 (CI) + E0-INF3 (Docker+Makefile+smoke) + E0-INF4 (trademark) + S04-P0#1 (mailbox migrated to ethereal-shell, CERN-OHL-S, lint cleanup pending `S04-P0#2`). Docker-gated validations pending.
- **E0-FAB1 ✅ (elut4+FF):** `ethereal-fabric/rtl/clb/elut4.sv` G1-clean (in lint glob); golden model `elut4_model.py` validated by **1211 local pytest**; cocotb DUT-vs-model Docker-gated. Bitfield frozen in `ethereal-spec/fabric/elut4-config-v0.md`. Report: `docs/reports/report-E0-FAB1-elut4-20260724.md`.
- **Convention established:** `make test-model` = local pure-Python golden-model pytest (no simulator); cocotb tests `test_<unit>.py` (Docker-gated), model tests `test_<unit>_model.py` (local).
- **OSS-CAD local validation ✅ (2026-07-24):** OSS-CAD Suite (`~/oss-cad-suite`: Verilator 5.051/Yosys 0.67/iverilog 14) located. `make lint` now **clean** (lint caught+fixed 2 real syntax bugs `(x)[range]`→`WIDTH'(x)`, WIDTHEXPAND, 2× UNUSEDSIGNAL; documented `-Wno-UNOPTFLAT` for intended CLB/routing loops). 3 self-checking **SystemVerilog testbenches** (tb_elut4/clb_t/switch_box) **PASS** via new `make test-sv` (iverilog). Golden-model **1876 pytest pass**. cocotb has py3.11/3.12 + v1/v2-makefile mismatch → SV TBs are the local DUT validation. Docker now OPTIONAL (only VPR/CI). New Makefile: `test-sv`, IVERILOG detect, lint scoped to `rtl/` + per-call `-Mdir`. Report `report-validation-oss-cad-20260724.md`.
- **S02-P0#1 ✅ (frame-map gen):** `ethereal-tools/tools/frame_map.py` — pack/unpack/blank/json + CRC-16/CCITT tail word; frame = one column's config bits, addr={region[3:0],col[7:0]}, blank=safe-zero. **309 pytest pass** (300 round-trip + CRC-tamper + blank + geometry); `make test-model` now **2185 total** (extends find to ethereal-tools). Artifacts (frame_map.json/blank.hex) → gitignored `generated/`. Report `report-S02-P0#1-framemap-20260724.md`.
- **E0-FAB4 ✅ (OCC v0):** `ethereal-fabric/rtl/occ/occ_top.sv` — cmd FSM (IDLE→WRITE/BLANK/READBACK→CMP), write_engine, frame bus, streaming CRC32, per-region LOCK. **lint-clean strict -Wall (zero warnings)**; `tb_occ` (iverilog) **PASS**: WRITE→READBACK CRC ok, tamper detected, BLANK zeroes frame, LOCK blocks WRITE. `make lint` clean-loop refactored to cover occ_top (was hardcoded per-module — fixed); `make test-sv` now 4 TBs. v0 = **config-path verified**; running a real circuit needs the routable CB (deferred). Report `report-E0-FAB4-occ-20260724.md`.
- **E0-FAB5 ✅ (blank-before-write + LOCK):** occ_top extended — per-region `dirty` bitmap + `S_NEEDS_BLANK` status: WRITE to a dirty region is rejected (C03 §3 red-line, now HARDWARE-enforced, not just BMC-protocol); BLANK clears dirty, WRITE sets it, reset=clean; LOCK has priority over dirty. **lint-clean**; `tb_blank` **PASS** (6 checks incl. **region isolation** — writing region 0 doesn't touch region 1's config storage; R0 dirty doesn't block clean R1); tb_occ regression PASS after adapting check 3 to a fresh region (DEPTH bumped to 8192 for region-1 addrs). `make test-sv` now **5 TBs**. v0 = config-storage-level isolation; fabric-output glitch prevention deferred (needs region gates + routable CB). Report `report-E0-FAB5-blank-20260724.md`.
- **E0-FAB6 ✅ (fabric-gen v0):** `ethereal-tools/tools/fabric_gen.py` — fabric.yaml/json descriptor → frame_map.json + manifest.json + blank.hex (calls FrameMap; `fabric_top` is parameterized so it emits params + frame_map, not bespoke RTL). 2×2/4×4/2×3/3×5 frame_map round-trip valid (→ OCC/bitgen-usable); geometry verified (4×4 = 16 tiles, 6656 bits, 4 frames, 212 words). Reference descriptors `ethereal-spec/fabric/fabric_{2x2,4x4}.yaml`. `make test-model` now **2197**. **Fabric core (E0-FAB1..6) COMPLETE.** Report `report-E0-FAB6-fabric-gen-20260725.md`.
- **E0-MAP1 ✅ (synth_ethereal):** `ethereal-tools/tools/mapper/yosys/synth_ethereal.py` — Yosys front-end (`synth -auto-top; abc -lut 4` → eLUT4 netlist; `$lut WIDTH=4` ≡ eLUT4 truth table). **c17 → 2 eLUT4, c432 → 62 eLUT4** (real ISCAS85, both in the reasonable band; c432 0 FF combinational). 4 pytest PASS (skip if no yosys); `make test-model` now **2201**. Flow documented in `synth_ethereal.ys`. Benchmarks c17.v (MIT) + c432.v (ISCAS85 public-domain, provenance header). Report `report-E0-MAP1-synth-20260725.md`.
- **Routable CB Step 1 ✅ (switch_box injection + input CB ready):** `switch_box.sv` v2 — `clb_out_i[N_INJ]` + inject_en (out_e[j<N_INJ] = inj? clb_out[j] : disjoint, **override not merge**, SB stays single driver); `connection_block.sv` (new, lint-clean) — clb_in = mux of 4*W tracks (input CB, **ready, not yet instantiated**); `fabric_top.sv` wired clb_out_i (tap still in place for clb_in — Step 2 will replace). Sub-agent updated sb_model/fabric_model/tb_switch_box (668 model tests; tb_switch_box PASS; default acyclic). **make lint OK / make test-sv 5 PASS / make test-model 2211** (personal re-verify). Caught: `inj_en_r` reset-less → X propagation → TB zero-inits all 56 cfg regs (same lesson as clb_t). cfg_addr 6-bit (48 sel + 8 inject). Report `report-routable-cb-step1-20260725.md`.
- **Routable CB Step 2 ✅ (input CB integrated + end-to-end routability PROVEN):** `connection_block` now instantiated in `fabric_top` (one/tile, replaces minimal tap) — cfg `unit` field widened to 2 bits (00=CLB/01=SB/10=CB), `tile_idx` shifted to [7+TIW:8]. New `cb_model.py` (ConnectionBlock golden model, pool {n=0,s=W,e=2W,w=3W}, sel default 0=post-zero-init HW-accurate). `fabric_model` extended: `_cb_edges` + `route_exists` BFS. NEW `tb_connection_block.sv` (zero-inits 18 sel_r, 4-dir bit-true + negative checks) → `make test-sv` now **6 TBs**. **`make lint OK / make test-sv 6 PASS / make test-model 2483`** (personal re-verify). **Routability PROVEN**: `route_exists(tile0.clb_out[0]→tile1.clb_in[0])`=True via inject→channel→SB→CB; negative control False. Default-acyclic holds (CB edges end at clb_in sinks). Report `report-routable-cb-step2-20260725.md`.
- **Routable CB COMPLETE (Step 1+2).** The fabric is now **end-to-end routable** — unlocks E0-MAP2 (VPR arch) + the Phase-0 circuit-run / hot-swap demo.
- **E0-MAP3 increment 1 ✅ (bitgen LEVEL-1 config DB):** `ethereal-tools/tools/mapper/bitgen/{bitgen_db,bitgen_sim,test_bitgen}.py` — parses VPR `.net`/`.place`/`.blif` → fabric-independent per-tile config semantic DB (eLUT4 TT + FF + IIB mux sel + placement). **c17 bit-true PROVEN: 32/32 input combos vs independent iverilog golden on the original `c17.v`** (crossbar-derived pin permutation; port_rotation_map[i]=logical pos carried by physical pin i; identity=[3,2,1,0] MSB-first). c432 structural: 9 tiles / 62 eLUT4. 8 bitgen tests + 2491 total model pass; lint OK / 6 SV TB / ruff clean. **FIXED RECORD:** `cfg_data[19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val, [0]=out_inv` (RTL+spec ground truth — my earlier brace-notation summary was ambiguous; bitgen follows RTL, enforced by test). Report `report-E0-MAP3-bitgen-level1-20260725.md`.
- **E0-MAP3 NEXT increments:** (2) `frame_map.py` is STALE — missing `connection_block` (18 sel×6) + SB `inject_en` (8) added during routable CB; must extend frame_map + spec + fabric_gen tests before LEVEL-2 frame packing. (3) LEVEL-2: DB → frames via frame_map. (4) routing bitgen (SB/CB/inject from VPR `.route` OR custom router on real fabric topology — ADR-012 refinement TBD) + IO path (primary I/O entry/exit, RTL not built) + sim harness → c432 bit-true in sim fabric (E0-MAP3 acceptance).
- **E0-MAP2 ✅ (VPR arch + native VPR v8.0.0):** `ethereal-tools/tools/mapper/vpr/arch_ethereal.xml` — adapted from VTR's k4_N4_90nm.xml to Ethereal (clb N=8/I=18/O=8, BLE=LUT4+FF+outmux, switch_block `subset`≡classic disjoint, L1 unidir, **fc_in=1.0 faithful** to the implemented full-mux connection_block). VPR v8.0.0 built **natively** (gcc-12; build script `ethereal-tools/tools/mapper/vpr/build_vpr.sh`; runner `run_vpr.sh`). **c432 pack/place/route SUCCESS @ W=12** (real fabric width): 9 CLB / 69 net / 274 wire-seg, **CPD 5.11 ns, Fmax 195.66 MHz**; c17 smoke 0.69 ns/1449 MHz. Acceptance met. Suite no-regression (lint OK / 6 SV TB / 325 mapper test). v8.0.0 build gotchas (force-include limits/algorithm, argparse limits patch, switch_block token=subset not disjoint, explicit `--pack --place --route`) documented. KEY FINDING: c432 needs W=13 at fc=0.25 but routes at W=12 once fc_in=1.0 (faithful to full-mux CB) → validates fabric W=12 suffices for c432. Timing=90nm PTM (not real). Report `report-E0-MAP2-vpr-arch-20260725.md`.
- **E0-FAB3 ✅ (interconnect):** `switch_box.sv` (disjoint unidir W=12, VPR-pending topology) + `fabric_top.sv` (param R×C grid, default 4×4 of clb_t+switch_box+channels); `fabric_model.py` does Kahn cycle-detection on the routing graph → validates **no comb loop** in default config (1×1..4×4..3×5) + detects/breaks a 4-tile ring. Full golden-model suite **1876 pass** locally. v1 CLB↔channel = minimal tap; full CB deferred (S02-P0#1/OCC/VPR). Spec `ethereal-spec/fabric/interconnect-config-v0.md`. Report `report-E0-FAB3-interconnect-20260724.md`.
- **E0-FAB2 ✅ (clb_t):** `ethereal-fabric/rtl/clb/clb_t.sv` (N=8 eLUT4 + flat full-input crossbar IIB, I=26; scoped UNOPTFLAT waiver for the feedback loop); golden model `clb_t_model.py` validated locally (**1218 total pytest** incl. 832-route connectivity exhaustion + toggle-FF + comb-loop detect); cocotb Docker-gated. v1 IIB = **flat crossbar** (frozen + ASSUMPTION — two-level Clos is the v2 optimization). Spec `ethereal-spec/fabric/clb-t-config-v0.md`. Report `docs/reports/report-E0-FAB2-clb-t-20260724.md`.

## Phase summary
| Phase | Window | Core goal | Key exit criteria | Budget |
|---|---|---|---|---|
| **P0** | M0-M2 | Verilator runs full chain (gen fabric→map→config→run→hot-swap), NO vendor tools | dual-image hot-swap pass; AES-128/FIR16 bit-true; ADR-012 archived; CI green | 100-150 p-h |
| **P1** ★1st ext milestone | M2-M5 | GW5 minimal loop: BMC daemon + ethctl + 2-region hot-swap + SPI/I2C dual channel + v0.1.0 | ethctl run/stop/ps/restart all pass; 2×10000 hot-swaps zero-fail; overhead/Fmax published | 150-220 p-h |
| **P2** | M5-M9 | heterogeneous fabric v2 + Zynq port + mFSM + Astral aggregation v1 | **SAME image runs on GW5 & US+ directly**; AES-MEM ≥5×, FIR-DSP ≥10×; aggregation demo; 4 specs v1.0 frozen | 250-350 p-h |
| **P3** | M9-M15 | Service Tile (NPU-Tiny) + scheduling + security v2 + image registry + academic publish | NPU inference demo + container migration; OCI push/pull; paper to FPL/FCCM/TRETS | 300-400 p-h |
| **P4** | M15-M24 | orchestrator + dev experience + Astral full runtime + community gov | unified orchestrator; BMC→Zephyr→Astral node; 4 ref designs; ≥2 core external contributors | milestone |
| **P5** | M24+ | commercial evolution (always complete open core + increments) | enterprise orchestration/RBAC/remote ops; security cert pre-eval; registry SaaS; vendor collab | directional |

## Circuit-breakers (each phase)
- **P0**: VPR arch doesn't converge in 2 weeks → switch to FABulous/nextpnr or self-research placer+router (5 person-day cap each); still fail → fixed W=8 manual topology to protect progress.
- **P1**: BMC FW channel blocked → host direct-drive EMRI/OCC fallback (mFSM semantics first).

## Phase 0 battle sequence (week-by-week)
- **Wk1 foundation**: E0-INF1 (org+8 repos), E0-INF4 (trademark check), E0-INF2 (CI skeleton), E0-INF3 (sim Docker), S04-P0#1 (mailbox RTL migration note)
- **Wk2-3 fabric core**: E0-FAB1 (eLUT4+FF), E0-FAB2 (CLB-T cluster N=8), E0-FAB3 (SB+channel W=12), S02-P0#1 (frame-map gen), E0-FAB4 (OCC v0 WRITE/BLANK/READBACK), E0-FAB5 (blank-before-write + LOCK)
- **Wk3-4 toolchain**: E0-MAP1 (Yosys techlib synth_ethereal), E0-MAP2 (VPR arch XML), E0-MAP3 (bitgen v0), E0-MAP4 (FABulous spike→ADR-012), E0-MAP5 (benchmarks AES/PRESENT/FIR16/CRC32/PWM)
- **Wk5-8 Shell + assembly**: E0-SHL1 (EBI-Tiny), S04-P0#4 (region endpoint + ABI draft), E0-SHL2 (Shell v0 integration), E0-SHL3 (perf model), dual-image hot-swap demo + report

## Key milestones (cross-phase)
- **M-S01-4 (P2)**: SAME image file runs directly on GW5 & Zynq US+ (binary compat first verification)
- **M-S01-2 (P1)**: GW5 runs 3 demo images; overhead/Fmax measured & published
- **M-S03-1 (P0)**: c432 + 5 benchmarks end-to-end bit-true; ADR-012 archived

## Risk register (web-verified)
| # | Risk | P | I | Status/Verification |
|---|---|---|---|---|
| R1 | Fabric overhead/perf fails (>60:1 or <15MHz) | M | H | ZUMA 40:1 is best public baseline (verified); heterogeneous tiles + Landy/Stitt interconnect opt (48-54% reduction) hedge |
| R2 | ~~AE350↔PL interface docs insufficient~~ | — | — | **ELIMINATED** (v2.1 deprecates AE350 → NEORV32 soft-core) |
| R3 | VPR arch file + bitgen workload explodes | M | H | VPR/VTR MIT, XML arch mature (verified); OpenFPGA two-level bitstream ref; circuit-breaker sensible |
| R4 | Gowin EDA commercial license cost/limits | L | M | Apicula+nextpnr-himbaechel Aurora V supports GW5 (verified, experimental) |
| R5 | MIT license patent exposure | L | M | DCO Signed-off-by mitigates; ADR-005 decided |
| R6 | Solo maintainer burnout | M | H | Each phase produces independently usable artifact + strict exit criteria hedge |
| R7 | ZUMA/FABulous license conflict | L | M | ZUMA paper method not copyrighted (reimplemented); FABulous Apache-2.0 borrow arch ideas no conflict (not direct code merge) |
| R8 | "Container" semantics questioned (no real multi-tenant security) | M | L | Docs clear: v1 prevents accidents, v3+ prevents attacks; overlay structural scan capability (L3) is security bonus reserve |
| R9 (new v2.1) | NEORV32 timing/primitive-inference quirks in Gowin synth | M | L | Community Gowin ports exist (neorv32-setups osflow); fallback core VexRiscv (E2-BMC2) |

## ⚠️ ZUMA routing-width citation discrepancy
Original v2.0 §3.3 cites "ZUMA W=12" but ZUMA paper actually says "routing width fixed at **112**" (total routing tracks). Phase 0 VPR experiment (E0-MAP2) should clarify whether "per-direction W" or "total tracks" to avoid scaling error. Citation precision issue, doesn't affect methodology.

## AE350 deprecation side-effect
v2.1 deprecates → GW5's DDR3 1GB + PCIe 3.0 hard-core NOT directly used in Phase 1 (BMC uses BSRAM/SSRAM); DDR3 access pushed to Phase 3 (image pool expansion); risk table dependency needs update.

## Open questions for user (from subsystem §7, by priority)
| Priority | Question | Blocks |
|---|---|---|
| 🔴 high | **"Astral" naming conflict** — `github.com/AstralPlatform` (no hyphen) is an active FPGA/RISC-V org; `astral-os` already taken; astral.sh (Ruff/uv) dominates software mindshare. Use `Astral-OS`+tagline or rename? | `astral-os/` repo, branding (E0-INF4 report) |
| 🟡 mid | Mailbox RTL G1-cleanup backlog (~22 procedural loops, plain-logic FSMs, no nettype restore) — add task `S04-P0#2`? Cleaned RTL only then enters main `make lint` gate. | `S04-P0#2` |
| ✅ resolved | ~~Mailbox re-license + migrate out of TinyGPU-FPGA~~ → **DONE 2026-07-24** (S04-P0#1) | — |
| 🔴 high | Exact Zynq US+ board model (constraints + DFX slot planning)? | E2-PLT1 |
| 🔴 high | Tang Mega 138K = Dock (confirmed) or Pro? (Board Manifest pin table) | E1-IO3, E1-PLT2 |
| 🟡 mid | Final virtual LUT granularity = LUT4? (affects all downstream; sim can parametrize LUT6 compare) | E0-FAB1 |
| 🟡 mid | ADR-012 MAP route A(VPR) vs B(FABulous); accept dual-track? | E0-MAP4 |
| 🟡 mid | Profile-E first small-device target (GW5AT-15? GW2A-18?) | E2-BMC1 |
| 🟡 mid | BMC FW v1 bare-metal vs Zephyr directly? (recommend bare-metal start) | E1-BMC2 |
| 🟡 mid | ethctl compose YAML syntax = docker-compose subset? | E2-AST1 |
| 🟢 low | L2 proxy v1 third protocol (SPI master or I2C master)? | E2-IO1 |
| 🟢 low | Astral full runtime: separate project (S15-S18) now or after Phase 2? | E2-AST1 |
| 🟢 low | Paper vs product priority? (overlay paper costs 2-3 months but academic backing) | E3-PUB1 |
