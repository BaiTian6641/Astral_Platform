# AGENTS.md

> **Who this is for**: AI coding agents (Kimi K3 and others) operating in this repository.
> Read this file fully before any task. It encodes the project's identity, locked decisions,
> mandatory engineering rules, and the operating protocol you must follow.
> Last updated: 2026-07-24 · Plan version: v2.1

---

## 0. Start here — project state (read before doing anything)

- This is the **Ethereal Logic Platform** (+ **Astral OS** aggregation) project.
- **It is currently a PURE PLANNING / SPEC repository.** There is **NO source code, build scripts, tests, or CI yet.** Every "build/run/test" description you find in the docs is a PLAN, not something that exists.
- All tasks in `docs/ethereal-tasks.yaml` are `status: todo`. **Phase 0 (simulation validation) has not started.**
- The first code lands in tasks `E0-INF1`, `E0-INF2`, `E0-INF3` (GitHub org, CI skeleton, sim Dockerfile).
- The documentation is written in **Chinese** (Simplified). Code, identifiers, comments, and reports should be in **English** unless the maintainer asks otherwise.
- Deep, maintained knowledge base: read `memory/README.md` → `memory/01..06-*.md` for the distilled project understanding. Authoritative sources remain under `docs/` and `ethereal-plan/`.

---

## 1. What the project is (30-second mental model)

We are mapping **Docker's image → container → orchestration** mental model onto two domains and unifying them in one control plane:

- **Ethereal (FPGA side):** a **virtual reconfigurable overlay fabric** — an "FPGA inside an FPGA." User logic is compiled to the fabric's **configuration data** (NOT a vendor bitstream). This yields cross-vendor binary compatibility, microsecond–millisecond hot-swap, and — critically — the reconfiguration behavior itself is fully **Verilator-verifiable** (native DPR cannot be simulated, per AMD UG909).
- **Astral (firmware/app side):** a container runtime for embedded MCUs (Zephyr userspace + WAMR WASM). The two meet via **Type-F containers** (a WASM/native app whose compute body is an Ethereal FPGA region).

**Target hardware:** Gowin **GW5AST-138 (Tang Mega 138K Dock)** = overlay main battlefield; **Zynq UltraScale+** = overlay + native DFX dual-route; small FPGAs (GW5AT-15/GW2A) → Profile-E with external MCU.

**Management core:** a **NEORV32** RISC-V soft core in the fabric acts as a **BMC** (like a server's baseboard management controller). Small devices degrade to a register-based **mFSM**. Both expose the identical **EMRI** register ABI, so `ethctl` doesn't care which side it talks to.

---

## 2. How to navigate the docs (don't read everything every time)

```
docs/
├── ARCHITECTURE-OVERVIEW.md         ← READ FIRST: read-only synthesis, has web-verification §8, risks §7, open Qs §9
├── Ethereal-Logic与...调研与路线图.md ← v1.0 survey (related work, the 3-route comparison) — the "why"
├── Ethereal-平台实施蓝图-v2.md        ← v2.0 decisions, ADR-001..012 (Overlay-first)
├── Ethereal-蓝图v2.1-BMC与...修订.md  ← v2.1 revision, ADR-013..017 (NEORV32 BMC) — LATEST, overrides v2.0
└── ethereal-tasks.yaml               ← machine-readable task list (your work queue)
ethereal-plan/
├── README.md                          ← index + GLOBAL RULES G1–G6 + report template + upstream deps
├── phases/phase-N-*.md (6)            ← TIME view: what to do, in what order, per phase, with exit criteria + circuit-breakers
├── subsystems/S01..S14 (14)           ← SYSTEM view: what each subsystem is, why, how, pitfalls
└── components/C01..C13 (12)           ← CODING view: HDL-level (interface tables / FSMs / bitfields / pin mapping)
```

**Reading rules (from `ethereal-plan/README.md`):**
- **Precedence:** `v2.1` overrides `v2.0` overrides `v1.0`. `ethereal-tasks.yaml` is synced to the latest.
- **Before writing ANY code:** read `ethereal-plan/README.md` §2 (rules G1–G6) → the matching `subsystems/Sxx.md` → the matching `components/Cxx.md`.
- **"What do I do now?":** open `ethereal-tasks.yaml`, find the lowest-ID task that is `status: todo` and whose `deps` are satisfied, then read its matching `phases/phase-N-*.md` section.
- **Want the quick full picture?** `docs/ARCHITECTURE-OVERVIEW.md` §0 (TL;DR), §3 (architecture), §8 (web verification), §9 (open questions).

---

## 3. MANDATORY engineering rules — G1–G6 (never skip)

These are global rules from `ethereal-plan/README.md` §2. They apply to every task, every subsystem, every phase.

- **G1 — Correctness & lint.** SystemVerilog follows the TinyGPU-FPGA RTL Policy: every file starts with `` `default_nettype none ``; sequential logic only `always_ff` + non-blocking; combinational only `always_comb`/`assign` with defaults assigned first (no latches); FSMs use `typedef enum` + two-segment style; no procedural loops inside `always_*` (use `generate/genvar`); registers `_r`/next `_nxt`/ports `_i`/`_o`; literals carry width+base (e.g. `8'hFF`). **Must pass `verilator --lint-only -Wall` with zero warnings** (or documented, justified exemptions). Python passes `ruff` + `mypy --strict`. Embedded C passes `-Wall -Wextra -Werror` + `clang-format`; **no dynamic memory allocation** (static heaps allowed only with a comment justifying why).
- **G2 — Standard module header.** Every RTL/software file starts with the header block (see §6 below), which must include `Plan-Ref:` back-tracing to the exact `ethereal-plan/subsystems/Sxx.md §x.y` section being implemented.
- **G3 — Acceptance report.** Every task, no matter how small, produces a Markdown report in the repo's `docs/reports/`, named `report-{taskId-or-milestone}-YYYYMMDD.md`, following the template in `ethereal-plan/README.md` §3.
- **G4 — Diagrams mandatory.** Architecture/FSM/timing diagrams in reports and docs must use inline **Mermaid** (default) or **PlantUML**. No external-image-link-only diagrams.
- **G5 — Report sections.** Reports always have two fixed sections: `## 本阶段实现内容` (this phase: ✅/⚠️/❌ per checkpoint) and `## 下一阶段需要做的内容` (next-phase task IDs + one line each).
- **G6 — Uncertainty handling (HIGHEST PRIORITY).** On ANY uncertainty — spec ambiguity, unknown device behavior, unclear toolchain error, two viable approaches — **STOP and ASK the maintainer. Do not guess and continue.** If web search is available, **search and verify first**, then ask with: your findings + candidate options A/B + each option's basis + your recommendation. Every "assumption" must be written in code/docs as `// ASSUMPTION: ... (TBD, YYYY-MM-DD)` and aggregated into the report's "pending confirmation" list.
- **Spec-first:** change `ethereal-spec` doc + bump version BEFORE changing any implementation. When a task is done, update `status` in `ethereal-tasks.yaml`. Significant trade-offs must be written as an ADR (`docs/adr/ADR-NNN-*.md`).

---

## 4. Locked decisions — ADRs you MUST NOT violate

If you find yourself proposing something contrary to these, STOP. These are settled.

| ADR | Decision | What it forbids |
|---|---|---|
| **001** | **Overlay-first** (fine-grained LUT-level virtual fabric) | Don't propose native DPR for the Gowin path (it has no user-level PR). |
| **002** | ZUMA is **re-implemented / modernized** into "Ethereal Fabric", NOT used directly | Don't vendor the 2012 ZUMA code; borrow its methodology (LUTRAM config, Clos interconnect, ~40 LUT/vLUT). |
| **003** | Targets: **Gowin GW5AST-138** + **Zynq UltraScale+** | Don't assume other targets without an ADR. |
| **004** | Fabric = **heterogeneous tiles + regions whose composition is fixed at base-image build** (defined in `fabric.yaml`) | Regions are build-time, not runtime-reconfigurable (runtime re-partition is a Phase 4+ feature). |
| **005** | Licenses: **SW=MIT, HW RTL=CERN-OHL-S-2.0, docs/specs=CC-BY-SA-4.0** | Use the correct SPDX header per file. DCO `Signed-off-by` required. |
| **006** | **EBI** has 3 profiles: Full (AXI4-Lite + own NoC) / Lite (own NoC) / Tiny (simple reg bus) | Pick the right profile per device class. |
| **007** | IO redirect is **two-level**: L1 pin Mux + L2 protocol proxy | Region logic **never touches physical pins directly** (structural electrical safety). |
| **008** | Host link = **SPI (data/config)** + **I2C (PMBus-style monitor)** | Don't invent other channels. |
| **010** | Control planes independent first (**EFP** for Ethereal, **ACP** for Astral), unify in Phase 4 | Don't prematurely merge the protocols. |
| **011** | Logic images are **self-own format** (config frames), not vendor bitstreams | No dependency on Gowin/AMD bitstream formats in the logic-image path. |
| **012** | MAP route **A (VPR + custom XML)** vs **B (FABulous/nextpnr)** — decided by Phase-0 spike | Circuit-breaker: VPR doesn't converge in 2 weeks → switch to B or self-research placer+PathFinder (5 person-day cap each). |
| **013** ⚠️ | **Platform management = fabric-internal RISC-V soft core (Ethereal BMC)**; **GW5 AE350 hard core is DEPRECATED** | **Never** propose the AE350/Andes hard core or its paid toolchain. |
| **014** | Small devices → **mFSM** (register-based, host-driven) | Don't put a CPU on tiny FPGAs. |
| **015** | **EMRI** = unified ABI between BMC and mFSM | Both expose the same register map; `ethctl` is transparent to which one. |
| **016** | BMC core: **primary NEORV32**, fallback VexRiscv, in a swappable `bmc_core` wrapper | Core is replaceable; keep SoC glue core-agnostic. |
| **017** ⚠️ | **Inference-First**: own cores **MUST NOT instantiate vendor IP/primitives**. DSP/RAM = behavioral, let each platform EDA infer. Non-inferable blocks (PLL/ADC/SerDes) live ONLY in `hal/<vendor>/glue/` and ship with a Verilator stub. | **Never** instantiate vendor DSP/BRAM/IO primitives in own RTL — it breaks cross-vendor portability AND Verilator verifiability of the fabric. |

> Note on ADR-013: the AE350 deprecation means GW5's DDR3 (1 GB) and PCIe 3.0 hard cores are NOT used in Phase 1 (the BMC uses BSRAM/SSRAM); DDR3 access is deferred to Phase 3.

---

## 5. Tech stack & tooling (all PLANNED — you build it in Phase 0)

| Layer | Language | Notes |
|---|---|---|
| HW RTL | **SystemVerilog** | Lint-clean per G1. License header `// SPDX-License-Identifier: CERN-OHL-S-2.0` |
| Tools (fabric-gen, mapper, bitgen, ethimg, ethctl, CI) | **Python 3.12** | `ruff` + `mypy --strict`. SPDX `MIT` |
| Embedded FW (bmc-fw) | **C** (NEORV32 libs → Zephyr in Phase 4) | `-Wall -Wextra -Werror`; no malloc. SPDX `MIT` |
| Simulation | Verilator 5 + cocotb (+ Yosys + VPR 8) in Docker, `make sim` / `make test` / `make lint` | main verification vehicle |

**Upstream deps (licenses web-verified 2026-07):** Verilator (LGPL/Artistic), cocotb (MIT/BSD), Yosys (ISC), **VPR/VTR (MIT)**, nextpnr-himbaechel (MIT), Apicula (ISC), OpenFPGALoader (GPLv2), **NEORV32 (BSD-3)**, VexRiscv (MIT), FABulous (Apache-2.0), ZUMA (paper, re-implemented), Coyote v2 (open source).

**Repo layout** (8 logical repos — **scaffolded 2026-07-24** as monorepo top-level dirs; monorepo-first, split later; each dir has its own LICENSE):
`ethereal-fabric`(CERN-OHL-S), `ethereal-shell`(CERN-OHL-S), `ethereal-tools`(MIT), `ethereal-runtime`(MIT), `ethereal-spec`(CC-BY-SA), `ethereal-images`(MIT), `astral-os`(MIT), `docs`(CC-BY-SA). Root `LICENSES.md` maps each dir → its license.

**Sim/build environment (E0-INF3, scaffolded 2026-07-24):** root `Makefile` targets `make help/lint/test/sim/lint-mailbox/docker-build/docker-shell/clean` run inside the `ethereal-sim` Docker image (`docker/Dockerfile`: Verilator v5.028 + Yosys 0.59 + VPR v8.0.0 + cocotb 1.9 + Python 3.12). `make lint` lints project RTL (excludes the not-yet-clean mailbox import). Local authoring env has **no** docker/verilator → all real lint/sim are **Docker-gated** (maintainer runs `make docker-build && make lint && make test`). CI (`.github/workflows/`) drives the same targets via Docker.

**Generated-output convention:** put ALL regenerable artifacts under `build/`, `out/`, `obj_dir/`, `sim_build/`, `_build/`, or `generated/` — these are git-ignored (see `.gitignore`). Hand-authored `fabric.yaml`, board manifests, and `*.tcl`/`*.xdc` are tracked. **`.eth` logic images are deliverables — never ignore them.**

---

## 6. Module header standard (G2 — copy this template)

```systemverilog
`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      <module_name>            // must match the module name
// Description: <one-line summary>
// Details:     <optional: multi-line, synthesis notes, vendor-primitive deps>
// Maintainer:  <name/ID>
// Created:     YYYY-MM-DD
// Modified:    YYYY-MM-DD - <change summary>
// Tags:        RTL, SYNTH | TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/Sxx.md §x.y   // back-trace to the plan (REQUIRED)
// Notes:       <lint-exemption rationale / sim-only code note>
```

---

## 7. Current work & your operating loop

**We are at the very start of Phase 0 (M0–M2): simulation validation, no vendor tools.** Phase-0 exit: dual-image hot-swap passes in sim; AES-128 & FIR16 bit-true; ADR-012 archived; CI green.

**Phase 0 week-by-week:** Wk1 infra (`E0-INF1/2/3/4`) → Wk2–3 fabric core (`E0-FAB1..6`, OCC) → Wk3–4 toolchain (`E0-MAP1..5`) → Wk5–8 Shell assembly + dual-image hot-swap demo.

**For any task, follow this loop:**
1. Read this `AGENTS.md`, then the relevant `phases/phase-N-*.md` + `subsystems/Sxx.md` + `components/Cxx.md`.
2. Implement per G1–G6; honor every relevant ADR; keep `Plan-Ref:` accurate.
3. Run the verification defined in that task's `acceptance:` criteria (cocotb / lint / bit-true compare).
4. Write the acceptance report (G3/G4/G5) in `docs/reports/`.
5. Update the task's `status` in `docs/ethereal-tasks.yaml`.

### ✅ Mailbox NoC — licensing resolved, RTL migrated into ethereal-shell (2026-07-24)
The **AXI-MailboxFabric NoC** (EBI backbone, S04) licensing is **FINALIZED** (`ethereal-plan/README.md §4`, 2026-07): migrate the NoC core + selected cores out of `github.com/BaiTian6641/TinyGPU-FPGA` and release under **CERN-OHL-S-2.0** in `ethereal-shell`, with file headers noting provenance. **Status (2026-07-24): DONE** — 14 RTL files + 1 spec migrated under `ethereal-shell/rtl/{mailbox,interface}/` + `ethereal-shell/docs/`, all with CERN-OHL-S-2.0 + provenance headers; see `ethereal-shell/docs/MIGRATION-mailbox.md`. The mailbox RTL has a **G1-cleanup backlog** (procedural loops / plain-logic FSMs) and is therefore linted separately via the **advisory** `make lint-mailbox` — NOT in the main `make lint` gate until cleaned (track as `S04-P0#2`). `verilator --lint-only -Wall` + cocotb on the mailbox are Docker-gated (pending).

### 🔧 Current execution context (2026-07-24)
- **Monorepo-first, split-later:** the 8 logical repos live as top-level dirs (`ethereal-fabric/`, `ethereal-shell/`, `ethereal-tools/`, `ethereal-runtime/`, `ethereal-spec/`, `ethereal-images/`, `astral-os/`, `docs/`). Each carries its **own** LICENSE so a future split is mechanical.
- **Remote:** `origin = https://github.com/BaiTian6641/Astral_Platform.git` (personal account; an `ethereal-fpga` org split is a later decision gated by `E0-INF4`).
- **Local tooling gap:** `gh`, `docker`, `yosys`, `verilator`, `vpr`, `nextpnr` are NOT installed in this environment. Files (CI, Dockerfile, RTL) can be authored; `verilator --lint-only -Wall`, cocotb runs, and `docker build` are **Docker-gated** validations — the agent authors them, the maintainer runs them and pastes results.

### ⚠️ Open questions pending maintainer confirmation (raise if your task touches them)
🔴 exact Zynq US+ board model · 🔴 Tang Mega 138K Dock vs Pro (Board Manifest) · 🟡 virtual LUT granularity final = LUT4? · 🟡 ADR-012 dual-track acceptable? · 🟡 Profile-E first small device · 🟡 BMC FW v1 bare-metal vs Zephyr. Full list in `memory/04-roadmap-phases.md`.

---

## 8. Domain cheat-sheet (decode the docs)

| Term | Meaning |
|---|---|
| **EBI** | Ethereal Bus Interface (3 profiles) |
| **OCC** | Overlay Configuration Controller — writes frames, blanks regions, locks, CRC32, scan, DMA |
| **BMC / mFSM** | fabric-internal management core (NEORV32) / register-based small-device fallback — same EMRI ABI |
| **EMRI** | unified register ABI for BMC & mFSM (magic `0x45544852` = "ETHR") |
| **EFP / ACP** | Ethereal Fabric Protocol / Astral Control Protocol (the two control planes) |
| **DPR / DFX** | Dynamic Partial Reconfiguration / Dynamic Function eXchange — native vendor flows (NOT for Gowin) |
| **eLUT4** | virtual LUT4 + 1 FF (the atomic fabric element) |
| **CLB-T / MEM-T / DSP-T / SSM-T / IO-T** | heterogeneous tile types (CLB cluster / BSRAM / DSP / SSRAM / edge IO) |
| **Region** | container allocation unit; tile composition fixed at build; virtual routing does NOT cross its boundary (isolation root) |
| **`.eth`** | logic image = tar(fabric config frames + 5-piece manifest + Ed25519 signature) |

**Docker analogy:** image↔logic image, container↔vFPGA region, registry↔image repo, docker engine↔Shell+OCC+daemon, namespace/cgroup↔region quota + virtual-routing boundary.

---

## 9. Gotchas — common mistakes to avoid

- **Don't instantiate vendor DSP/BRAM/IO primitives in own RTL** (ADR-017). Describe behaviorally; confine vendor specifics to `hal/<vendor>/glue/` with Verilator stubs.
- **Don't propose the AE350 hard core** (ADR-013) or any paid/vendor-locked management core. Use NEORV32 (swappable to VexRiscv).
- **Don't put native DPR on the Gowin path** — it has no user-level PR; that's the whole reason overlay exists.
- **Don't ignore `G6`.** If a register offset, FSM state name, pin assignment, or toolchain behavior isn't documented, ask — don't invent.
- **Blank-before-write is mandatory** when (re)configuring a region (FABulous lesson): write a safe/zero frame before the new config to avoid one-hot mux multi-drive transients.
- **Honor region isolation:** virtual routing must not cross region boundaries; region ↔ region communication goes only via EBI.
- **Reports need Mermaid diagrams** (G4) and the two fixed sections (G5). A code change without a report is incomplete.
- **`:Zone.Identifier` files are Windows junk** — they're git-ignored; never commit or reference them.

---

## 10. Where to look for deeper context

- **`memory/`** — distilled, always-current project knowledge base (`README.md` + `01..06`).
- **`docs/ARCHITECTURE-OVERVIEW.md`** — the canonical synthesis (risks, web verification, open questions).
- **`ethereal-plan/subsystems/Sxx.md`** — each subsystem's "what / how / how-to-verify / pitfalls".
- **`ethereal-plan/components/Cxx.md`** — HDL-level detail you can code directly from.
- **`docs/ethereal-tasks.yaml`** — the live work queue.
