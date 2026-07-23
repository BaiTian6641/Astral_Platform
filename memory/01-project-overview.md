# Project Overview — Astral_Platform (Ethereal Logic Platform)

> Workspace-scoped facts for `/home/polar/Astral_Platform/`. Read this first.
> Synced from `/memories/repo/project-overview.md`.

## Repo nature
**Pure planning/spec repository — NO source code, build scripts, tests, or CI exist yet.**
- 30+ Markdown docs + 1 YAML task list (`ethereal-tasks.yaml`).
- All "build/run/test" descriptions are PLANS; first implementation lands in Phase 0 tasks `E0-INF1..3`.

## Document structure (3 tiers + 4 top-level)
```
Astral_Platform/
├── ARCHITECTURE-OVERVIEW.md          ← READ FIRST (read-only synthesis, has web verification §8)
├── Ethereal-Logic与...调研与路线图.md  ← v1.0 research/survey (related work + 3-route comparison)
├── Ethereal-平台实施蓝图-v2.md         ← v2.0 decisions (ADR-001..012, OVERLAYS v1.0 recommendation)
├── Ethereal-蓝图v2.1-BMC与...修订.md   ← v2.1 revision (deprecate AE350 → NEORV32 soft-core BMC)
├── ethereal-tasks.yaml               ← machine-readable task list (all status: todo)
└── ethereal-plan/
    ├── README.md                      ← index + global rules G1-G6 + report template + upstream deps
    ├── phases/      (6)               ← TIME view: phase-0..5 battle maps
    ├── subsystems/  (14)              ← SYSTEM view: S01..S14 engineering files
    └── components/  (12)              ← CODING view: C01..C13 HDL-level (interfaces/FSM/bitfields)
```

## Document evolution (v1.0 → v2.0 → v2.1)
- **v1.0** survey: recommended Route A (native DPR) MVP in Phase 1.
- **v2.0** blueprint: REVERSED → Overlay-first (Route B). ADR-001..012.
- **v2.1** BMC revision: REVERSED again → deprecate GW5 AE350 hard-core (paid toolchain+JTAG+poor SW) → fabric-internal RISC-V soft-core (NEORV32). ADR-013..017.
- Conflicts: v2.1 overrides v2.0 overrides v1.0. `ethereal-tasks.yaml` synced with latest.

## Reading order by goal
| Goal | Read |
|---|---|
| Quick full picture | `ARCHITECTURE-OVERVIEW.md` (esp. §0 TL;DR, §3 arch, §8 web verification, §9 open Qs) |
| "Why this design" | v1.0 survey (调研与路线图) |
| "Current decisions" | v2.0 blueprint + v2.1 revision (ADRs) |
| "What to do now" | `phases/phase-N-*.md` + `ethereal-tasks.yaml` (lowest todo ID) |
| Before writing ANY code | `ethereal-plan/README.md` §2 (rules G1-G6) → matching `subsystems/Sxx.md` → matching `components/Cxx.md` |
| Feasibility | `ARCHITECTURE-OVERVIEW.md` §7 risks + §8 web checks |

## 5-layer architecture (HW → orchestration)
- **L0 Physical FPGA**: GW5AST-138 / Zynq US+ / small+FPGA.
- **L1 HAL**: `eth_inf_*` inference templates + thin `hal_glue` (PLL/OSC/ADC/Flash-MSPI only).
- **L2 Ethereal Fabric**: OCC + Regions (CLB-T/MEM-T/DSP-T/SSM-T/IO-T).
- **L3 Shell (static, burn once)**: BMC + EBI (Mailbox NoC + AXI-Lite) + IO redirect + monitor + Service Tile.
- **L4 Runtime**: ethereal-daemon (in BMC FW) + ethctl CLI (PC, Docker-style commands).
- **L5 Orchestrator** (Phase 4): declarative YAML bundle, multi-board, unified w/ Astral.

## Concurrency model = HARDWARE, not software
No OS threads/async/await/event loop (except BMC FW & Astral side). Multi-region **spatial parallelism** (each own clock domain) + some **time-multiplexing** (Service Tile). Only "synchronization primitives" are HW protocols: mailbox valid/ready handshake, OCC frame ack, Region ABI heartbeat.

## Key data/control flow (`ethctl run` journey)
ethctl(PC) → EFP-SPI → BMC daemon(NEORV32) → [capabilities check + region alloc] → [SHA-256 + Ed25519 verify] → OCC [BLANK_REGION → DMA push frames → READBACK verify] → Region ABI CTRL.run=1 → Region runs → OPC_IRQ → BMC → DEPLOY_OK to ethctl.

## Cross-vendor binary compatibility mechanism
The same `.eth` image file runs on GW5, Zynq US+, (future) Artix-7/ECP5. bitgen depends ONLY on `frame_map.json` (from fabric-gen), NOT on any vendor bitstream format. The virtual arch semantics (eLUT4 interface, frame format, image format) are invariant; only arch params (N/W/I) are re-scaled per host. Promise delivered at M-S01-4 (Phase 2).
