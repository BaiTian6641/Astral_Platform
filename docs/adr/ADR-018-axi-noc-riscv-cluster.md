# ADR-018: standard AXI + custom NoC + in-house RVA23-direction RV64 app-processor subsystem (configurable core, wrapped DRAM, in-house DMA)

> Status: **RATIFIED (in-house direction) — rev 3** · Date: 2026-07-30
> Amends: **ADR-006** (EBI 3-profile) · **ADR-016** (BMC swappable core). Adds: NEW application-processor subsystem (S15) + in-house AXI/NoC + in-house DMA + wrapped-DRAM component (new ADR slots).
> Supersedes: the PULP-`axi` / CVA6 / PULP-`iDMA` vendoring options considered in rev 1-2 (rejected by the maintainer for a fully in-house, license-clean stack). The mailbox NoC investment is retained, not discarded.
> Plan-Ref: `ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md`, `S05-BMC与EMRI-mFSM.md`, `S15-应用处理器子系统.md`; research: `/memories/repo/axi-noc-riscv-cluster-research.md`, `/memories/repo/rva23-cluster-dma-research.md`, `/memories/repo/inhouse-silicon-stack-research.md`

> ✅ **Maintainer decision (2026-07-30) — go fully in-house (no third-party IP):**
> 1. **Interconnect → our OWN standard AXI implementation** (own AXI4/AXI4-Lite/AXI4-Stream
>    + own NoC), industry-standard three-plane. Avoids all third-party IP license issues.
> 2. **App processor = separate major task** — our OWN highly-configurable **RV64 core
>    targeting the RVA23 profile** (cluster ≤4-core, real-time embedding optimizations),
>    behind a standard interface. GW5 validation profile = **single-core RV64 RVA23**.
> 3. **DRAM = a per-target wrapped component** (Zynq-PS / GW5-hard-DDR3 / future own controller for tapeout).
> 4. **DMA = our OWN DMA** on the AXI bus (multi-channel + 2D graphics), in the
>    processor subsystem.
> The BMC keeps its own UART/SPI/I2C but becomes a first-class citizen on the system bus.

---

## 1. Context

The current EBI plan (ADR-006 / S04) uses a custom 3-profile interconnect whose NoC
backbone is the maintainer's own AXI-MailboxFabric (flit NoC), with an AXI4-Lite bridge
as "EBI-Full" (Phase 2). The BMC is a NEORV32 MCU (ADR-016) with a private peripheral
set, reached by the host but **not itself a full system master**. Two gaps motivate this
correction:

1. **Interconnect maturity.** A bespoke EBI + a Phase-2 AXI-Lite bridge is a niche
   design. The maintainer wants **standard AXI at the edges + a custom NoC core** as the
   mature, ecosystem-compatible interconnect — the same pattern as Zynq PS–PL
   (AXI-Lite GP + AXI4 HP) and PULP/Chipyard ("AXI at the top, specialized transport at
   the leaves").
2. **No user-facing application processor.** Today there is only the BMC (management,
   not for user workloads). The platform's whole point is "the user runs things on the
   FPGA." A **Linux-capable RISC-V application cluster** (like the Zynq ARM PS) lets the
   end-user run real firmware/Linux with full access to the system — a major capability
   step that the current plan does not provide.

Research (two web reports, 2026-07-30, cited in `/memories/repo/axi-noc-riscv-cluster-research.md`)
establishes the concrete options and their licenses/costs/risks.

## 2. Decision 1 — Interconnect: **our OWN standard AXI implementation** (in-house, license-clean) + custom NoC

**Adopt a three-plane AXI architecture (matches industry standard / Zynq GP-HP), implemented in-house:**

| Plane | AXI variant | Carries |
|---|---|---|
| Control/status | **AXI4-Lite** | EMRI, OCC control, per-peripheral CSRs, PLIC/CLINT, mailbox doorbells |
| Config stream | **AXI4-Stream** | OCC → fabric_top configuration frames (one-way push, VALID/READY/TLAST) |
| Data/memory | **AXI4 (Full)** | DRAM/SRAM, DMA, region↔region, BMC & app-cluster memory access (bursts + ATOP atomics for SMP Linux) |

**In-house implementation (`eth_axi`, CERN-OHL-S-2.0), NOT a vendored library.** The
maintainer chose to build the AXI fabric in-house to keep the whole stack license-clean
for tapeout. The de-risking spike (`/memories/repo/pulp-axi-idma-spike.md`) confirmed the
*architecture* (three-plane AXI, struct-typed cores, Verilator-clean) and, importantly,
established that an in-house AXI is **tractable** (`/memories/repo/inhouse-silicon-stack-research.md`):

- **Scope:** AXI4-Lite + AXI4-Stream + a small **AXI4 crossbar** (N masters × M slaves,
  address decode + decode-error slave + per-channel arbitration + response-ID routing).
  AXI4-Lite/Stream = simple (VALID/READY handshake, registered boundaries). The crossbar's
  hard part is **response-ID routing + same-ID ordering + deadlock-free buffering** —
  addressed with **per-channel skid buffers**.
- **Correctness method:** **formal verification** (SymbiYosys property sets), following
  the ZipCPU `wb2axip` didactic model (study its formal properties as the *correctness
  spec* — do not copy RTL). This is the highest-leverage way to get an AXI fabric right.
- **Size/effort:** AXI-Lite slave ≈ 600 LUT; AXI-Lite xbar ≈ 1-2K LUT; full AXI4 xbar
  (4M×32S) ≈ 10K LUT. **~1.5-3 person-months** including formal verification.
- **DV references (study, not copy):** ZipCPU `wb2axip` (formal AXI properties), PULP
  `axi` (modular crossbar structure). Our RTL is 100% original (CERN-OHL-S-2.0).

**Keep the custom mailbox flit NoC as the *region-data plane only***, fronted by
AXI Network-Interface (NI) adapters. This preserves the structural region isolation of
ADR-007 (virtual routing never crosses a region boundary) and the existing migrated
mailbox RTL investment — the NoC becomes a transparent AXI-attached fabric, not a
bespoke control bus. **ADR-006's 3-profile EBI is thereby subsumed:** "EBI-Full" ≈ the
AXI4 system fabric, "EBI-Lite" ≈ the mailbox NoC (now AXI-fronted), "EBI-Tiny" stays
as the small-device fallback (unchanged).

**BMC becomes a first-class AXI master:** bridge NEORV32's XBUS→AXI4 (`xbus2axi4`,
shipped with NEORV32) so the BMC has full system access (it can drive OCC/EMRI/regions
over AXI). Its private UART/SPI/I2C remain internal per ADR-016 (the BMC's own
management console), but the BMC is no longer *behind* the host — it is *on* the bus.

## 3. Decision 2 — NEW application-processor subsystem: configurable RV64 (RVA23-direction) core cluster behind a standard AXI socket

> Maintainer directive (2026-07-30): the app processor is a **separate major task**;
> goal is an **RV64 core following the latest RVA23 profile, up to 4-core**, but
> **user-configurable** (RV32 or RV64, single or multi-core), behind a **standard
> interface so users can plug in any core they want**.

### 3.1 The RVA23 reality check (research, 2026-07-30 — honest constraint)

RVA23 (ratified 2024-10-21; the Ubuntu-25.10+/Android RISC-V baseline) mandates
**Vector (V) + Hypervisor (Sha) + Sv39 + ~a dozen Z\* extensions** (Zicond, Zimop,
Zcmop, Zcb, Zfa, Zawrs, Supm, Svnapot, Sstc, Sscofpmf, …). Consequences:

- **No permissively-licensed open RV64 core is fully RVA23-compliant today.** The only
  open RVA23-complete core (XiangShan Kunminghu) is server-class, Chisel, MulanPSL, and
  far too large for any target FPGA. (CVA6 cv64a6 has RV64GC + **Hypervisor** + Sv39
  but **no Vector, no Sv48** → it is *RVA23-aligned*, not RVA23.)
- **Therefore "RV64-following-RVA23 + ≤4-core + fits GW5AST-138 (~138K LUT)" is mutually
  exclusive today.** A true RVA23 cluster is a **tapeout / big-FPGA (Zynq US+ PL) target**.

**Resolution (honor the directive's intent within the constraint):** build the subsystem
around a **core-agnostic standard AXI4 cluster socket** so the *interface* is frozen and
the *core* is swappable/configurable. **Our own in-house core (`eth_rv`) plugs in here**
(§3.3), phased RV64GC+Sv39 → SMP → RVA23-complete; the same socket also accepts any other
socket-compliant core a user prefers (a future permissive RVA23 core, or XiangShan on
tapeout) **unchanged**. This satisfies "configurable RV32/RV64, single/multi, standard
plug-in interface" directly, and tracks RVA23 as our core (and the ecosystem) matures.

### 3.2 The standard cluster socket (the load-bearing interface — unchanged)

A **fixed AXI4 cluster socket** (built on the Decision-1 in-house AXI fabric) is the
*only* contract a core must meet:

- **Master port(s):** AXI4 (+ATOP atomics for SMP) into the system crossbar.
- **Interrupts:** PLIC + CLINT as MMIO slaves on the AXI bus (Linux-standard); a **CLIC**
  option for the real-time skew (§3.4).
- **Debug:** JTAG/cJTAG DTM pin (swappable, like the BMC).
- **Config descriptor:** a machine-readable `core.yaml` (XLEN, core count, MMU/H/V,
  cache/TCM sizes, bus width) that drives the generated wrapper + the device tree.

**Core-swappability is structural** (the ADR-016 `bmc_core` pattern, extended to the app
domain): the SoC glue depends only on the socket. **Our in-house core plugs in here; a
user can also plug any other socket-compliant core** (CVA6 / a future RVA23 core) —
the interface is the contract, not the core.

### 3.3 The in-house RISC-V core (`eth_rv`, CERN-OHL-S-2.0) — RVA23-direction, phased

The maintainer chose to design the processor **in-house** (license-clean for tapeout).
This is the long pole of the program — the phasing below is the honest path
(`/memories/repo/inhouse-silicon-stack-research.md`, effort anchors: OSOC 5-students/4-months
for a Linux-boot RV64; CVA6 = 6-stage in-order template; Vector = the schedule-killer).

**Microarchitecture (first core):** **in-order, single-issue, 5-6 stage pipeline** (the
CVA6-proven template). **No OoO.** Boot Linux early (forces Sv39 + interrupts + exceptions
to be right). Verification >> RTL — plan a **DiffTest-style lockstep co-sim against Spike**
from day one.

**Phasing (RVA23-direction — defer the two schedule-killers, Vector + Hypervisor):**

| Stage | Core | Boots | Effort (1-2 eng) |
|---|---|---|---|
| **RV-B** | RV64IMC (no MMU) | bare-metal / FreeRTOS over UART | 6-12 PM |
| **RV-C** | RV64GC + **Sv39 MMU** (+ TCM/CLIC option) | **Linux** | +6-12 PM (~1.5-2 PY cum.) |
| **RV-E** | RV64GC cluster 2-4 core, shared L2 + coherence | SMP Linux | +4-8 PM |
| **RV-F** | + **Hypervisor (Sha)**, then **+ Vector (V as coprocessor via CV-X-IF-style std iface)** + Z\* sweep | RVA23-complete | +1-3 PY (Vector dominates) |

- **GW5 validation profile (per maintainer):** **single-core RV64 RVA23-direction** =
  **RV64GC + Sv39** (Stage RV-C), the bring-up vehicle. Vector/Hypervisor are deferred —
  a true RVA23-complete core is a Phase-2/tapeout goal, **not** a Phase-1 blocker. This
  is the standard staged-adoption path (RVA22 had V optional; CVA6 ships non-V/H base
  configs and bolts V on as the Ara coprocessor).
- **Vector strategy:** add Vector **as a coprocessor** behind a standard extension
  interface (the Ara/Vicuna model), not in-pipeline — it's the only tractable way to
  reach RVA23 on a small team.
- **DV references (study, not copy):** CVA6 (RV64GC+Sv39+H structure, >50 params),
  Rocket (pipeline), Ara/Vicuna (Vector coprocessor + CV-X-IF). Our RTL is original.

### 3.4 Real-time embedding optimizations

No ratified RISC-V real-time profile exists yet; the key real-time blocks are:

- **CLIC (Core-Local Interrupt Controller):** vectored, priority-based, **nested
  preemption + tail-chaining** → low, deterministic interrupt latency (vs PLIC's flat
  model). CLIC is a **draft** (unratified) — we design to its *concepts* and keep it a
  modular, replaceable block (PLIC stays the Linux default).
- **TCM (ILM/DLM tightly-coupled memory):** single-cycle deterministic access (no
  cache-miss variance) + the in-order pipeline = predictable WCET — the Cortex-M/R recipe.
- These make the core dual-personality: **Linux-capable (Sv39, PLIC)** and
  **real-time-embeddable (TCM, CLIC, no-MMU option)** — same socket, config-selected.

### 3.5 Feasibility on GW5AST-138 (honest)

- **Single-core RV64GC + Sv39 (in-order, ~30-50K LUT est.)** fits on the 138K (leaving
  overlay budget) — this is the validation profile.
- A **4-core RV64 cluster** and **Vector** do NOT fit the 138K — they are Zynq-US+ /
  tapeout targets. The DMA subsystem (§5) fits on the 138K.

## 4. Decision 3 — DRAM as a wrapped, swappable component

> Maintainer directive (2026-07-30): treat DRAM as a **separate wrapped component** —
> the user wraps the Zynq-PS DDR or the GW5 hard-DDR3; leave space for a **future own
> DDR controller** (the ultimate tapeout goal).

**DRAM is a HAL component, not a fixed choice.** The SoC talks to DRAM only through a
standard **`eth_dram_ctrl` AXI4 slave interface**; the implementation is per-target:

| Target | Implementation | Status |
|---|---|---|
| Zynq US+ | Zynq PS DDR (AXI HP port) | wrapped in `hal/zynq/glue/` |
| Gowin GW5 | GW5 hard-DDR3 PHY+controller IP | wrapped in `hal/gowin/glue/` (per ADR-017: non-inferable block, ships with a **Verilator stub**) |
| Tapeout (future) | **own open DDR controller** (e.g. a LiteDRAM-derived or custom PHY+controller) | **reserved socket** — the AXI4 slave interface is the contract |

- This removes the "which DDR" blocking question from the processor path: the
  app-cluster always sees the same AXI4 memory slave; the target's HAL provides it.
- The GW5 hard-DDR3 wrapper is a **hardware bring-up task** (maintainer); until it
  exists, the GW5 app-cluster runs DDR-less (BootROM + on-chip SRAM + optional external
  SPI-flash/PSRAM rootfs) — proving the Linux path without DDR.
- **Verilator-verifiability preserved:** every DRAM implementation ships a behavioral
  AXI4 memory stub (per ADR-017), so the full SoC simulates without the hard IP.

## 5. Decision 4 — **in-house DMA subsystem** (multi-channel + 2D graphics), in the processor subsystem

> Maintainer directive (2026-07-30): a **system-wide highly-configurable DMA controller** —
> one **multi-channel DMA** and one **2D-DMA (with graphics-processing ability)** — both
> part of the processor subsystem. **Build it in-house along the AXI bus** (no third-party IP).

Two engines, both in-house on the Decision-1 AXI fabric, both configurable
(`/memories/repo/inhouse-silicon-stack-research.md` — both tractable, ~1-2 person-months each):

### 5.1 Multi-channel DMA (`eth_dma_mc`, CERN-OHL-S-2.0)
- **Feature set:** descriptor-list / **scatter-gather** (linked-list of buffer descriptors:
  src/dst/len/control, SOF/EOF, IOC interrupt), **channel arbitration**, register-direct +
  SG modes, optional data-realignment, 64-bit addressing, AXI4 master (+ optional AXI4-Stream).
- **Configurability:** channel count, bus width, per-channel buffer depth = build-time
  parameters (generated-wrapper convention). Serves the app-cluster (Linux `dmaengine`),
  the BMC (<10 ms hot-swap frame DMA), and region data movement.
- **Size:** ~2-8K LUT (direction set). **DV references (study, not copy):** PULP `iDMA`
  (ND engine + channel arbitration), Xilinx AXI DMA/CDMA (descriptor model), ZipCPU AXI DMA.

### 5.2 2D graphics DMA (`eth_dma_2d`, CERN-OHL-S-2.0)
- **What it is:** 2D block/strided/tiled moves **plus** pixel ops — blit (block copy),
  solid fill, ROP (raster-ops), alpha-blend, color-space convert, rotation. (Reference:
  Xilinx AXI VDMA HSIZE/VSIZE/STRIDE; Digital Blocks BitBLT.)
- **Design:** an **ND-strided** address engine (2D = N2, the PULP `tensor_ND` model) for the
  *move*, plus a **custom SV blit/fill/ROP stage** on the write path for the *pixel ops*
  (no permissive open BitBLT exists — genuinely in-house).
- **Configurability:** HSIZE/VSIZE/STRIDE register model (VDMA-compatible), optional
  ROP/blend/rotation stages as build-time enables. ~3-8K LUT + 1-3K for the blit stage.

### 5.3 Why both
The multi-channel DMA is the general data mover; the 2D DMA is a **Service-Tile-class
accelerator** (S11) for graphics/display/imaging workloads — and a self-hosting example
of a hardware Service Tile driven by the app-cluster over AXI.

## 6. Consequences

- **Interconnect (S04/C04) rewritten** around the in-house three-plane AXI fabric (`eth_axi`)
  + the mailbox NoC repositioned as the AXI-fronted region-data plane (investment retained).
- **BMC (S05/C05)** gains XBUS→AXI4 master capability (full system access); private
  peripherals unchanged.
- **NEW subsystem — application-processor SoC (S15, new):** the configurable core
  cluster behind the AXI4 socket + PLIC/CLINT + OpenSBI/Linux + the wrapped-DRAM
  component + the DMA subsystem. This is the platform's user-facing "PS".
- **NEW component — in-house DMA subsystem:** `eth_dma_mc` multi-channel + `eth_dma_2d`
  2D graphics DMA (ND-strided + custom blit/ROP), configurable, in the processor subsystem.
- **DRAM becomes a HAL component** (`eth_dram_ctrl` AXI4 slave + per-target glue +
  future own-controller socket) — unblocks the processor path from the DDR question.
- **Verilator-verifiability preserved:** everything is now in-house plain SV/Verilog
  (`eth_axi`, `eth_rv`, `eth_dma_*`, NEORV32-converted BMC, the fabric). No third-party
  SV-interface dependency (that was a PULP-`axi` concern — now moot). The fabric TBs
  stay on iverilog; the new AXI/core RTL can use either simulator.
- **Zynq US+** hosts the larger configs (PS DDR + 4-core RV64 / Vector); **GW5** hosts
  the overlay-fabric + BMC + the **single-core RV64GC+Sv39 validation profile**, with the
  DDR3-hard-IP wrapper as its full-Linux enabler.

## 7. Decisions RATIFIED by the maintainer (2026-07-30)

1. **Interconnect → our OWN standard AXI implementation** (`eth_axi`, in-house,
   CERN-OHL-S-2.0). ~~PULP `axi`~~ rejected (license-cleanliness). ✅
2. **Processor → our OWN highly-configurable RV64 core targeting RVA23** (`eth_rv`),
   behind the standard AXI4 socket; cluster ≤4-core + real-time optimizations. **GW5
   validation profile = single-core RV64 RVA23** (i.e. RV64GC + Sv39, Vector/Hypervisor
   deferred per §3.3). ✅
3. **DRAM → per-target wrapped component** (`eth_dram_ctrl` + Zynq-PS / GW5-hard-DDR3
   glue + future own-controller socket for tapeout). ✅
4. **DMA → our OWN DMA on the AXI bus** (`eth_dma_mc` multi-channel + `eth_dma_2d` 2D
   graphics). ~~PULP `iDMA`~~ rejected. ✅
5. ~~SV-interface/iverilog spike~~ — **RESOLVED 2026-07-30.** The PULP-`axi`/`iDMA` sim
   probe is now **moot** (in-house stack chosen), but its finding stands as design
   guidance: struct-typed AXI cores Verilate cleanly; SV interfaces + packed-2D params
   break iverilog. Our in-house AXI/DMA will be written **iverilog-compatible** (no SV
   interfaces in synthesizable code; parameters kept flat) so both simulators work.
   (`/memories/repo/pulp-axi-idma-spike.md`.)
6. **Core-count on GW5 = ONE core (RV64, RVA23-direction).** 4-core / Vector = Zynq-US+ /
   tapeout. ✅

## 8. Execution roadmap (in-house)

The first build phase is well-defined and de-risked. Honest magnitude: **AXI + DMA =
person-months; the RV64 core = person-years; RVA23-complete (V+H) = multi-year.**

| Phase | Deliverable | Effort (1-2 eng) | Status |
|---|---|---|---|
| **A — `eth_axi`** | In-house AXI4-Lite + AXI4-Stream + small AXI4 crossbar, **formally verified** (skid buffers, ID routing, decode-error slave). iverilog-compatible. | 1.5-3 PM | **NEXT** |
| **B — `eth_rv` RV64IMC** | In-order 5-6 stage RV64IMC (no MMU), bare-metal/FreeRTOS over UART, on `eth_axi`. DiffTest co-sim vs Spike. | 6-12 PM | planned |
| **C — `eth_rv` RV64GC + Sv39** | +FPU(D)+C+Sv39 → **boots Linux** (the GW5 validation profile). | +6-12 PM | planned |
| **D — `eth_dma_mc` + `eth_dma_2d`** | Multi-ch SG DMA + 2D blit/fill/ROP (parallel with B/C). | 2-4 PM | planned |
| **E — SMP cluster** | 2-4 core, shared L2 + coherence, per-core CLIC. | +4-8 PM | Zynq-US+ |
| **F — RVA23 completion** | +Hypervisor (Sha), +Vector (CV-X-IF-style coprocessor), Z\* sweep. | +1-3 PY | tapeout goal |
| **G — Tapeout** | Own DRAM controller (or controller + licensed PHY). | program | tapeout goal |

**Recommended first milestone (bring-up vehicle):** Phase A (`eth_axi`, formally
verified) + Phase B (`eth_rv` RV64IMC bare-metal hello on GW5AST-138), in the existing
Verilator/iverilog flow. Achievable in ~9-15 months part-time; proves the whole
in-house toolchain end-to-end and produces the configurable-generator skeleton reused
for RV64GC → SMP → RVA23.

### Open design questions (to resolve during execution, not blocking)
1. **DiffTest co-sim infrastructure** (Spike lockstep) — set up in Phase B (found 151
   bugs in XiangShan; worth it).
2. **CLIC spec tracking** — CLIC is unratified; design to its concepts, keep modular.
3. **Configurable-generator parameter model** (`eth_core_config_pkg`) — freeze in
   Phase B (XLEN/CORE_COUNT/HAS_MMU/H/V/FPU/CLIC/cache/TCM); bless 2-3 configs for full
   verification (CVA6 discipline).

