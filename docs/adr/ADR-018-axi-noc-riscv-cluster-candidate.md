# ADR-018 (candidate): standard AXI + custom NoC + RVA23-direction RISC-V app-processor subsystem (configurable core, wrapped DRAM, DMA subsystem)

> Status: **CANDIDATE — pending maintainer ratification** · Date: 2026-07-30 (rev 2, same day — maintainer refinement)
> Amends: **ADR-006** (EBI 3-profile) · **ADR-016** (BMC swappable core). Adds: NEW application-processor subsystem (S15) + DMA subsystem + wrapped-DRAM component (new ADR slots).
> Supersedes: nothing (the BMC/NEORV32 decision in ADR-016 stands; the mailbox NoC investment is retained, not discarded).
> Plan-Ref: `ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md`, `S05-BMC与EMRI-mFSM.md`; research: `/memories/repo/axi-noc-riscv-cluster-research.md`, `/memories/repo/rva23-cluster-dma-research.md`

> ⚠️ **Plan correction requested by the maintainer (2026-07-30), refined same day:**
> 1. **Interconnect → standard AXI + own custom NoC** (industry-standard three-plane).
> 2. **App processor = separate major task** — RV64 following the **RVA23 profile**, up to
>    4-core, **user-configurable** (RV32/RV64, single/multi-core), behind a **standard
>    interface** so users can plug in any core. (See §3.1 for the honest RVA23 constraint.)
> 3. **DRAM = a separate wrapped component** (Zynq-PS / GW5-hard-DDR3 / future own controller).
> 4. **DMA subsystem** — a configurable multi-channel DMA + a 2D graphics DMA, in the
>    processor subsystem.
> The BMC keeps its own UART/SPI/I2C but becomes a first-class citizen on the system bus.
> **No code is written against this until ratified.**

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

## 2. Decision 1 — Interconnect: standard AXI edges + custom NoC, built on the PULP `axi` library

**Adopt a three-plane AXI architecture (matches industry standard / Zynq GP-HP):**

| Plane | AXI variant | Carries |
|---|---|---|
| Control/status | **AXI4-Lite** | EMRI, OCC control, per-peripheral CSRs, PLIC/CLINT, mailbox doorbells |
| Config stream | **AXI4-Stream** | OCC → fabric_top configuration frames (one-way push, VALID/READY/TLAST) |
| Data/memory | **AXI4 (Full)** | DRAM/SRAM, DMA, region↔region, BMC & app-cluster memory access (bursts + ATOP atomics for SMP Linux) |

**Build it on the PULP `axi` library (SHL-0.51, permissive)** — `axi_xbar` (system
AXI4+ATOP crossbar), `axi_lite_xbar` (CSR subtree), `axi_to_axi_lite`, `axi_cdc`,
`axi_dw_converter`, `axi_lite_mailbox` (BMC↔app doorbell). **Rationale:** the only
permissively-licensed, hand-written-SV, FPGA+Verilator-friendly building-block library
that composes a *custom* NoC without adopting Chisel (Constellation/OpenSoC) or a whole
SoC-builder (LiteX). (License-mix with CERN-OHL-S-2.0 is routine — see §5.)

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
the *core* is swappable/configurable, then ship a **configurable core generator** that
today produces an **RVA23-aligned RV64 core** (CVA6) and/or an **RV32 SMP cluster**
(VexRiscv-SMP), with the socket ready to accept a future **RVA23-complete core** (or
XiangShan on tapeout) **unchanged**. This satisfies "configurable RV32/RV64, single/multi,
standard plug-in interface" directly, and tracks RVA23 as cores mature.

### 3.2 The standard cluster socket (the load-bearing interface)

A **fixed AXI4 cluster socket** (built on the Decision-1 PULP `axi` fabric) is the
*only* contract a core must meet:

- **Master port(s):** AXI4 (+ATOP atomics for SMP) into the system `axi_xbar`.
- **Interrupts:** PLIC + CLINT as MMIO slaves on the AXI bus (Linux-standard).
- **Debug:** JTAG/cJTAG DTM pin (swappable, like the BMC).
- **Config descriptor:** a machine-readable `core.yaml` (XLEN, core count, MMU/H/V,
  cache sizes, bus width) that drives the generated wrapper + the device tree.

**Core-swappability is structural** (the ADR-016 `bmc_core` pattern, extended to the app
domain): the SoC glue depends only on the socket, never on the specific core. A user
drops in CVA6 / VexRiscv-SMP / Rocket / a future RVA23 core by meeting the socket.

### 3.3 The configurable core generator

A generated `app_cluster.sv` wrapper (same `fabric_gen` convention) with build-time
parameters, so the *user* configures the processor:

| Param | Values | Notes |
|---|---|---|
| `CORE` | `cva6_cv64a6` / `vexriscv_smp` / `external` | swappable core selection |
| `XLEN` | `32` / `64` | RV32 (VexRiscv) or RV64 (CVA6) |
| `CORE_COUNT` | `1` / `2` / `4` | single / dual / quad |
| `H_EXT` | `0` / `1` | hypervisor (CVA6 v5.1.0+) |
| `MMU` | `sv32` / `sv39` | per core |
| `ICACHE/DCACHE` | sizes | per core |

- **RV64 / RVA23-direction (recommended default):** **CVA6 cv64a6** (SHL, plain SV,
  `XLEN=64`, `MMUEn`, `CVA6ConfigHExtEn`) — RV64GC + Hypervisor + Sv39, ~47-70K LUT/core,
  best open 64-bit SV core. Honest label: **"RVA23-aligned, not RVA23"** (no Vector/Sv48).
- **RV32 / SMP-Linux-now (alternative):** **VexRiscv-SMP** (MIT, pre-generated Verilog) —
  RV32IMAC + Sv32, coherent 2-8 core, ~13-20K LUT for a quad, boots Linux today.
- **RVA23-complete (future):** XiangShan on tapeout, or a future permissive RVA23 core,
  dropped behind the same socket.

### 3.4 Feasibility on GW5AST-138 (honest)

- **1× CVA6 cv64a6 (~47-70K LUT)** or **4× VexRiscv-SMP (~13-20K LUT)** both fit; a
  **4-core CVA6 cluster does not** (would need coherence IP + ~200K+ LUT) and a true
  RVA23 core doesn't exist. **On the 138K, the app-cluster is single-core-CVA6 or
  quad-VexRiscv-SMP.** 4-core RV64 is a Zynq-US+/tapeout target.
- The DMA subsystem (§5) fits on the 138K.

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

## 5. Decision 4 — configurable DMA subsystem (multi-channel + 2D graphics), in the processor subsystem

> Maintainer directive (2026-07-30): a **system-wide highly-configurable DMA controller** —
> one **multi-channel DMA** and one **2D-DMA (with graphics-processing ability)** — both
> part of the processor subsystem.

Two engines, both built on the Decision-1 PULP `axi` fabric, both configurable:

### 5.1 Multi-channel DMA → PULP `iDMA` (SHL-0.51)
- **Basis: PULP `iDMA`** — AXI4+ATOP-native, **ND-strided (2D/3D)** transfers, multi-channel
  front/mid/back-end, scatter-gather, silicon-proven (Snitch/MemPool), Verilator-friendly.
- **Configurability:** channel count, bus width, and per-channel buffer depth are
  build-time parameters (same generated-wrapper convention). Serves the app-cluster
  (Linux `dmaengine`), the BMC (<10 ms hot-swap frame DMA), and region data movement.

### 5.2 2D graphics DMA → iDMA ND backend + custom blit/fill/ROP pipeline
- **What it is:** 2D block/strided/tiled moves **plus** pixel ops — blit (block copy),
  solid fill, ROP (raster-ops), alpha-blend, color-space convert, rotation. (Reference:
  Xilinx AXI VDMA HSIZE/VSIZE/STRIDE; Digital Blocks BitBLT.)
- **Basis:** iDMA's `tensor_ND` backend gives the 2D/ND strided **move**; **no permissive
  open BitBLT engine exists** (DB9100 is proprietary), so we add a **small custom SV
  blit/fill/ROP stage** to iDMA's stream backend (the project already hand-writes SV).
- **Configurability:** HSIZE/VSIZE/STRIDE register model (VDMA-compatible), optional
  ROP/blend/rotation stages as build-time enables.

### 5.3 Why both
The multi-channel DMA is the general data mover; the 2D DMA is a **Service-Tile-class
accelerator** (S11) for graphics/display/imaging workloads — and a self-hosting example
of a hardware Service Tile driven by the app-cluster over AXI.

## 6. Consequences

- **Interconnect (S04/C04) rewritten** around PULP `axi` + the three-plane split; the
  mailbox NoC is repositioned as the AXI-fronted region-data plane (investment retained).
- **BMC (S05/C05)** gains XBUS→AXI4 master capability (full system access); private
  peripherals unchanged.
- **NEW subsystem — application-processor SoC (S15, new):** the configurable core
  cluster behind the AXI4 socket + PLIC/CLINT + OpenSBI/Linux + the wrapped-DRAM
  component + the DMA subsystem. This is the platform's user-facing "PS".
- **NEW component — DMA subsystem:** `iDMA` multi-channel + 2D graphics DMA (iDMA+blit),
  configurable, in the processor subsystem.
- **DRAM becomes a HAL component** (`eth_dram_ctrl` AXI4 slave + per-target glue +
  future own-controller socket) — unblocks the processor path from the DDR question.
- The `axi_lite_mailbox` PULP module aligns naturally with the existing mailbox
  doorbell concept (BMC↔app interrupts).
- **Verilator-verifiability preserved:** PULP `axi`/`iDMA`, CVA6, VexRiscv-SMP
  pre-generated Verilog, NEORV32-converted are all plain SV/Verilog. ⚠️ PULP libs use
  SV interfaces (`AXI_BUS` macros) — Verilator 5 OK, **iverilog weak** → the
  interconnect is likely Verilator-only, or needs a ports-only wrapper (1-day spike).
- **Zynq US+** hosts the larger Linux-cluster configs (PS DDR + CVA6/quad); **GW5**
  hosts the overlay-fabric + BMC + the smaller app-cluster configs (single-CVA6 or
  quad-VexRiscv-SMP), with the DDR3-hard-IP wrapper as its full-Linux enabler.

## 7. Open items for the maintainer (G6 — ratify before code)

1. **Ratify the three-plane AXI + PULP `axi` library** (and the SHL-0.51 license-mix note).
2. **Processor subsystem (§3):** confirm the **core-agnostic AXI4 socket + configurable
   generator**, with **CVA6 (RVA23-aligned RV64) as the RV64 default** and **VexRiscv-SMP
   as the RV32 SMP alternative**, RVA23-complete deferred to a future core/tapeout.
   (This is the honest reading of "RV64 following RVA23" given no open RVA23 core fits.)
3. **DRAM (§4):** ratify the wrapped `eth_dram_ctrl` component + per-target glue + the
   reserved own-controller socket (tapeout).
4. **DMA (§5):** ratify **PULP iDMA (multi-channel)** + **iDMA-ND + custom blit/ROP (2D
   graphics)** as the DMA subsystem basis.
5. ~~**SV-interface/iverilog spike**~~ — **RESOLVED 2026-07-30 (de-risking spike done):**
   Verilator 5.051 compiles both PULP `axi` (v0.39.10) and `iDMA` (v0.6.5) clean
   (struct-typed cores via `AXI_TYPEDEF_*`); iverilog 14 is blocked by SV interfaces
   (in `*_intf` wrappers) **and** iDMA's packed-2D-array parameters (no workaround) →
   **sim strategy settled: Verilator-only for the interconnect/DMA; iverilog stays for
   the fabric TBs** (new `make lint-interconnect`/`test-interconnect` target; `make
   test-sv` untouched). Vendoring plan (~2-3 person-days) + SHL-0.51 license handling
   recorded in `/memories/repo/pulp-axi-idma-spike.md`. **No maintainer decision needed
   on this item.**
6. **Core-count target on GW5:** confirm single-CVA6 vs quad-VexRiscv-SMP for the 138K
   (4-core RV64 = Zynq-US+/tapeout).

### Ready to execute on ratification
Once items 1-4 + 6 are answered, the first build step (P-A0) is well-defined: vendor the
PULP `axi`/`iDMA` subset (per the spike plan), add the `make lint-interconnect` Verilator
target, instantiate `axi_lite_xbar` + `idma_nd_midend` in a smoke TB, and bridge the
BMC's XBUS→AXI4. All IP is Verilator-verified; the only open choices are architectural
(items 2/6) and the DRAM/DMA ratification (items 3/4).

