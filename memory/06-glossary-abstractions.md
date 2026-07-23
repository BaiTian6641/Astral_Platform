# Glossary & Core Abstractions — Ethereal Platform

> Terminology, acronyms, and core abstractions. Use this to decode the Chinese docs + technical jargon.
> Synced from `/memories/repo/glossary-abstractions.md`.

## Acronyms
| Term | Meaning |
|---|---|
| **EBI** | Ethereal Bus Interface (AXI4-Lite + own NoC + simple bus, 3 profiles) |
| **OCC** | Overlay Configuration Controller (frame/blank/lock/CRC32/scan/DMA) |
| **BMC** | Baseboard Management Controller (here = fabric-internal RISC-V soft-core, NEORV32) |
| **mFSM** | management FSM (small-device register-based fallback for BMC) |
| **EMRI** | Ethereal Management Register Interface (BMC & mFSM unified ABI) |
| **EFP** | Ethereal Fabric Protocol (Ethereal control-plane API; EFP-SPI = data channel) |
| **ACP** | Astral Control Protocol (Astral control-plane API) |
| **DPR/PR** | Dynamic Partial Reconfiguration (native vendor flow; NOT for Gowin) |
| **DFX** | Dynamic Function eXchange (AMD term for PR; DFX Controller IP = PG374) |
| **HAL** | Hardware Abstraction Layer (`hal/<vendor>/`) |
| **SEU** | Single Event Upset (config memory soft error → needs scrubbing) |
| **vFPGA** | virtual FPGA (a region = one vFPGA instance) |
| **SoC** | System on Chip |
| **BFM** | Bus Functional Model (testbench) |
| **HIL** | Hardware-In-the-Loop (test tier) |

## Core fabric abstractions (L2)
| Abstraction | Definition |
|---|---|
| **eLUT4** | virtual LUT4 + 1 bypassable FF; config stored in physical CFU memory mode (GW5) / LUTRAM (Xilinx). v1 may use FF (C01 §2) |
| **CLB-T** | N=8 eLUT4 + Clos 2-level local interconnect (I≈26 inputs). Tile = container of eLUT4 |
| **SB/CB** | Switch Box / Connection Box; W=12 channels, two-source-track priority, mux sized to LUT4 input plateau |
| **MEM-T** | tile wrapping 1 BSRAM (18Kb dual-port/ECC): RAM/ROM/FIFO/dual-port, 1K×18…16K×1 |
| **DSP-T** | tile wrapping 1 DSP (27×18): MAC modes (mul/mac/accumulate/pre-add filter/barrel-shift/bypass) |
| **SSM-T** | SSRAM-window tile (1080Kb pool): bulk temp/table/context-save area |
| **IO-T** | edge 8-pin + L1 Mux: 8 virtual IO to EBI IO redirect |
| **Supertile** | adjacent tile fusion (e.g., DSP+MEM pair) bypassing virtual interconnect direct connect (FABulous concept) |
| **Region** | rectangular tile group, container allocation unit; **composition defined in fabric.yaml, fixed at base-image build** (ADR-004); virtual routing does NOT cross region boundary (isolation physical root) |

## Core shell/runtime abstractions (L3/L4)
| Abstraction | Definition |
|---|---|
| **OCC** | EBI-mounted 32-bit reg interface; cmds: REGION_SELECT/FRAME_ADDR/WRITE_FRAME/BLANK_REGION/READBACK_FRAME/LOCK_REGION/UNLOCK_REGION. LOCK = config-isolation hardware root |
| **Mailbox Center/Switch/Endpoint** | ported from TinyGPU-FPGA, AXI-NoC backbone |
| **region_endpoint** | per-vFPGA bus gateway + Region ABI 16-word window |
| **bmc_core** | NEORV32 wrapper (core swappable to VexRiscv) |
| **EMRI register face** | BMC/mFSM unified ABI (see 02-decisions-adrs.md) |
| **daemon lifecycle FSM** | EMPTY→BLANKING→LOADING→VERIFYING→LOADED→RUNNING→STOPPING (aligns AMD DFX Controller) |
| **logic image (`.eth`)** | tar package = fabric config frames + 5-piece manifest + Ed25519 signature |

## Image types (5-tier, OCI-inspired)
| Type | Content | Deploy target | Freq |
|---|---|---|---|
| base image | vendor bitstream (Shell + Fabric + Service Tiles) | JTAG/MSPI burn | low (per board) |
| logic image | fabric config frames + manifest + interface + caps | OCC loads to region | high (user daily) |
| service image | Service Tile bitstream/config + service desc | base-image build or DFX slot | mid |
| bundle | multi logic image + layout constraints (docker-compose style) | orchestrator | — |

## logic image manifest.yaml key fields
`image/{name,version,digest,signature(ed25519)}`, `targets[]` (fabric arch version + region req: tile type+count), `interface` (EBI version, virtual IO req, interrupts), `capabilities` (IO/service perms requested), `resources` (eLUT/MEM/DSP caps), `health` (watchdog period, restartPolicy).

## Docker ↔ Ethereal concept mapping
| Docker | Ethereal (FPGA) | Astral (firmware) |
|---|---|---|
| Image | logic image (fabric config frames + manifest) | WASM module / native binary + manifest |
| Container | vFPGA (region instance running logic) | sandboxed WASM process / MPU-isolated user task |
| Registry | bitstream image repo (versioned, signed, indexed by device/slot) | firmware image repo (indexed by MCU/RTOS) |
| Orchestration | region alloc, reconfig scheduling, IO redirect, health monitor | app scheduling, quota, proxy IO, crash recovery |
| Docker Engine | Shell (static layer) + OCC (config controller) + runtime daemon | RTOS kernel ext + container runtime + mem-safety subsystem |
| Namespace/Cgroup | slot quota (LUT/BRAM/DSP cap), addr space isolation | MPU mem domain, kernel obj perms, stack guard |
| UnionFS/layered | "static Shell image" + "logic image layer" combo | base FW layer + app layer |

## Astral container types (3-tier model)
| Type | Description | Isolation |
|---|---|---|
| **Type-N** (Native) | Zephyr userspace thread/mem-domain + perm list, runs PIC code (Zephyr llext or own loader). Highest perf | MPU |
| **Type-W** (WASM) | WAMR runtime (interp+AoT), cross-arch portable image. **Recommended default Astral image format** | WASM sandbox + Capability list |
| **Type-F** (FPGA linkage) | special container whose "compute body" = an Ethereal vFPGA logic image; control plane = MCU proxy task. **The aggregation point of 2 platforms** | combined |

## Working rules G1-G6 (ALL agents MUST follow, from ethereal-plan/README.md §2)
- **G1** syntax/code correctness: RTL SV policy lint-clean; Python ruff+mypy strict; C -Wall -Werror; SPDX headers (HW=CERN-OHL-S-2.0, SW=MIT, docs=CC-BY-SA).
- **G2** standard module header w/ Plan-Ref back-trace to plan file.
- **G3** phase acceptance = markdown report in `docs/reports/`.
- **G4** diagrams mandatory (Mermaid default, PlantUML for complex); no external image links only.
- **G5** reports have fixed sections: "this phase implemented" (✅/⚠️/❌ per checkpoint) + "next phase needed".
- **G6** (HIGHEST PRIORITY) STOP & ASK on ANY uncertainty (spec ambiguity/device behavior/toolchain error unclear/2 options both viable). **Web-search FIRST**, then ask with findings + candidate options + recommendation. All "assumptions" written as `// ASSUMPTION: ... (TBD, YYYY-MM-DD)` and summarized in report.
- Spec-first: change `ethereal-spec` doc + bump version BEFORE changing impl. Each task done → update `ethereal-tasks.yaml` status. Key design tradeoffs → write ADR.
