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
- **Next:** E0-FAB5 (blank-before-write region-level + neighbor no-glitch SVA) / full CB to unlock end-to-end circuit run.
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
