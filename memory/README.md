# Project Memory — Astral_Platform (Ethereal Logic Platform)

> Workspace-local mirror of the agent's memory, synced with the `/memories/` system.
> Generated: 2026-07-23 after full document review + web verification.
> These notes summarize understanding; the authoritative sources remain the documents under `/ethereal-plan/` and the top-level `*.md` files.

## Purpose
A distilled, navigable knowledge base of the whole project so any future coding session starts with full context without re-reading 30+ docs. Keep in sync with `/memories/repo/` when the plan evolves.

## File index
| File | Content |
|---|---|
| `01-project-overview.md` | Repo nature, document structure, reading order, 5-layer architecture, concurrency model, control flow |
| `02-decisions-adrs.md` | ADR-001..017 (v2.0 + v2.1), EMRI register map |
| `03-tech-stack.md` | Languages/quality gates, toolchain deps + licenses, build/test flows, repo layout, upstream deps, blockers, verified platform facts |
| `04-roadmap-phases.md` | Phase 0-5 summary, circuit-breakers, P0 battle sequence, milestones, risk register, ZUMA width discrepancy |
| `05-subsystem-component-map.md` | S01-S14 subsystems, C01-C13 components, HW design 3 principles, module header standard |
| `06-glossary-abstractions.md` | Acronyms, core fabric/shell/runtime abstractions, image types, Docker↔Ethereal mapping, Astral container types, working rules G1-G6 |

## TL;DR (read first)
- **Pure planning repo — NO source code yet.** 30+ Markdown + 1 YAML. First implementation = Phase 0 `E0-INF1..3`.
- **Mission**: map Docker's image→container→orchestration model onto **FPGA logic (Ethereal)** + **embedded firmware (Astral)**, unified in one orchestration plane.
- **Core innovation**: virtual reconfigurable **overlay fabric** on physical FPGAs. User logic = fabric config data (NOT vendor bitstreams) → cross-vendor binary compat, µs-ms hot-swap, fully Verilator-verifiable (native DPR cannot be simulated — AMD UG909).
- **Target HW**: Gowin GW5AST-138 (Tang Mega 138K Dock, overlay main) + Zynq UltraScale+ (overlay + native DFX).
- **BMC**: NEORV32 RISC-V soft core (BSD-3) in fabric, unified **EMRI** ABI with **mFSM** for small devices. AE350 hard-core DEPRECATED (v2.1).
- **Status**: plan v2.1 final; all tasks `status: todo`; Phase 0 (sim validation) not yet started.
- **🔴 Critical blocker**: Mailbox RTL must be re-licensed CERN-OHL-S-2.0 & migrated out of TinyGPU-FPGA (user action) before `E0-INF1`/`S04-P0#1`.
- **Rule G6 (highest)**: STOP & ASK on any uncertainty — web-search first, then ask with findings + options + recommendation.
