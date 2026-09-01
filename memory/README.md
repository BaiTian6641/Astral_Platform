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
- **Implementation is well underway (2026-09-01).** Phase 0 functionally complete: v1.1 fabric (Wilton SB + bidir inject) routes+runs c432 bit-true; dual-image hot-swap on real RTL; heterogeneous mem_t/dsp_t bit-true (AES 16.5×, FIR16 16-DSP); in-house AXI stack (ADR-018) formally verified; BMC (NEORV32) boots real C firmware and reads EMRI over AXI; EMRI v0.2 EFP command block frozen (daemon contract); Ed25519 fw verify done (144 host vectors).
- **Mission**: map Docker's image→container→orchestration model onto **FPGA logic (Ethereal)** + **embedded firmware (Astral)**, unified in one orchestration plane.
- **Core innovation**: virtual reconfigurable **overlay fabric** on physical FPGAs. User logic = fabric config data (NOT vendor bitstreams) → cross-vendor binary compat, µs-ms hot-swap, fully Verilator-verifiable (native DPR cannot be simulated — AMD UG909).
- **Target HW**: Gowin GW5AST-138 (Tang Mega 138K Dock, overlay main) + Zynq UltraScale+ (overlay + native DFX). **Open build chain PROVEN (E1-PLT4, 2026-09-01): yosys synth_gowin → nextpnr-himbaechel (GW5AST-138C chipdb in oss-cad-suite) → gowin_pack → .fs; 4×4 fabric Fmax 115.61 MHz; LUT overhead ~308:1 (vs 45:1 target → E2-FAB5).**
- **BMC**: NEORV32 RISC-V soft core (BSD-3) in fabric, unified **EMRI** ABI with **mFSM** for small devices. AE350 hard-core DEPRECATED (v2.1). **ADR-018 (2026-07-30): fully in-house stack — own AXI (eth_axi, done+formal), own RV64/RVA23-direction core (eth_rv, planned E2-RV1/RV2), own DMA (eth_dma_mc/2d), wrapped DRAM (eth_dram_ctrl).**
- **Status**: Phase 0 closed (D1/D2/D5 decisions in report-phase0-closeout-20260901); active = E1-RUN2 daemon, E1-PLT1 hal/gowin_gw5. Local gates all green: `make lint` / `test-sv` 28 TB / `test-model` 2639+3xfail / `formal` 4 proofs.
- **Rule G6 (highest)**: STOP & ASK on any uncertainty — web-search first, then ask with findings + options + recommendation.
