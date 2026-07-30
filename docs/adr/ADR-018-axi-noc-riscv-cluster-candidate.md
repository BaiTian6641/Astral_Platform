# ADR-018 (candidate): standard AXI + custom NoC interconnect + Linux-capable RISC-V application cluster

> Status: **CANDIDATE — pending maintainer ratification** · Date: 2026-07-30
> Amends: **ADR-006** (EBI 3-profile) · **ADR-016** (BMC swappable core). Adds: a NEW application-processor domain (a new ADR slot).
> Supersedes: nothing (the BMC/NEORV32 decision in ADR-016 stands; the mailbox NoC investment is retained, not discarded).
> Plan-Ref: `ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md`, `S05-BMC与EMRI-mFSM.md`; research: `/memories/repo/axi-noc-riscv-cluster-research.md`

> ⚠️ **This is a plan correction requested by the maintainer (2026-07-30):** move the
> interconnect to **standard AXI + own custom NoC**, and add a **highly-configurable
> RISC-V application processor (cluster, up to 4-core) capable of booting Linux and
> giving the end-user full system access** — the RISC-V analog of the ARM PS on a
> Zynq. The BMC keeps its own UART/SPI/I2C but becomes a first-class citizen on the
> system bus. **No code is written against this until ratified.**

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

## 3. Decision 2 — NEW application-processor domain: VexRiscv-SMP cluster (up to 4-core, Linux-capable)

Add a **separate SoC domain**: a **VexRiscv-SMP** cluster (RV32IMAC + Sv32 MMU, **MIT**),
1→4 cores, on the AXI system fabric, with PLIC+CLINT as MMIO slaves and OpenSBI/U-Boot/Linux
boot. **Rationale:** VexRiscv-SMP is the **only permissively-licensed, FPGA-proven,
drop-in coherent SMP cluster** that boots SMP Linux (~13-20K LUT for a quad).
Pre-generated Verilog is available (`pythondata-cpu-vexriscv_smp`) → no SpinalHDL/sbt
needed for standard configs (same vendored-frozen pattern as NEORV32).

- This is a **new ADR slot** (the app processor is NOT the BMC). ADR-016's swappable
  `bmc_core` boundary is unaffected — NEORV32 stays the BMC.
- **Why not CVA6:** better single core (RV64, higher IPC) but mainline has **no SMP**;
  a coherent quad needs research-grade Culsans/OpenPiton (TRL-4) — custom work + risk.
  CVA6 is the documented **Option B** (single strong core) and the **Zynq US+ fallback**
  for 64-bit/higher-IPC needs.
- **Why not NEORV32 for the app cluster:** no MMU/S-mode → not Linux-capable (correct
  for the BMC, wrong for the app processor).

### ⚠️ Decision-2 gating dependency (honest): DRAM
Linux needs tens of MB of DRAM. GW5 BSRAM/SSRAM (~1 MB) is far too small → **DDR3 is
mandatory for a full Linux cluster on GW5**, but GW5 DDR3 is a **hard PHY+controller IP**
(the blocks Phase-1 avoids) with **no mature open soft controller** (LiteDRAM has no
GW5A PHY). **This is the single biggest risk.** Mitigations (choose at ratification):
- (a) Zynq US+ as the Linux-cluster primary target (it has PS DDR) — GW5 keeps BMC+fabric only;
- (b) GW5 DDR3 hard-IP wrapper in `hal/gowin/glue/` (per ADR-017, non-inferable block + Verilator stub) — a hardware bring-up task (maintainer);
- (c) reduced DDR-less Linux app processor (1-core, rootfs on SD/SPI-flash, ~8-16 MB external PSRAM/SRAM) — proves the Linux path without DDR.

### Cluster phasing (effort est.)
| Phase | Scope | Effort |
|---|---|---|
| A0 | 1-core VexRiscv-SMP, vendor pre-generated Verilog, Verilator/iverilog sim, OpenSBI+Linux boot in sim | ~1-2 wk |
| A1 | Wire cluster to AXI/NoC + EMRI-visible mgmt; fabric/region access | ~1-2 wk |
| A2 | Scale 1→2→4 cores (config knob), shared L2, coherent DMA | ~1 wk |
| A3 ⚠️ | **DDR3 path** (hard-IP wrapper / Zynq PS DDR / DDR-less fallback) | HIGH RISK / HW |
| A4 | Linux distro (Buildroot), user firmware flow, ethctl integration | ongoing |

## 4. Consequences

- **Interconnect (S04/C04) rewritten** around PULP `axi` + the three-plane split; the
  mailbox NoC is repositioned as the AXI-fronted region-data plane (investment retained).
- **BMC (S05/C05)** gains XBUS→AXI4 master capability (full system access); private
  peripherals unchanged.
- **NEW subsystem** (app-cluster SoC) added: VexRiscv-SMP + PLIC/CLINT + OpenSBI/Linux +
  DDR3 dependency. This is the platform's user-facing "PS".
- The `axi_lite_mailbox` PULP module aligns naturally with the existing mailbox
  doorbell concept (BMC↔app interrupts).
- **Verilator-verifiability preserved:** all chosen IP (PULP axi, VexRiscv-SMP
  pre-generated Verilog, NEORV32-converted) is plain SV/Verilog → simulatable in
  Verilator/iverilog. ⚠️ PULP `axi` uses SV interfaces (`AXI_BUS` macros) — Verilator 5
  OK, **iverilog weak** → the interconnect is likely Verilator-only, or needs a
  ports-only wrapper (1-day spike to confirm before committing — a G6 spike).
- **Zynq US+** becomes the Linux-cluster-capable target (PS DDR + can also host CVA6
  later); **GW5** remains the overlay-fabric + BMC battleground (with DDR3 bring-up as
  the app-cluster enabler).

## 5. Open items for the maintainer (G6 — ratify before code)

1. **Ratify the three-plane AXI + PULP `axi` library** (and the SHL-0.51 license-mix note).
2. **App-processor core = VexRiscv-SMP (Option A)** vs CVA6 single-core (Option B) vs defer.
3. **DRAM strategy for the Linux cluster on GW5:** (a) Zynq-primary, (b) GW5 DDR3 hard-IP wrapper, or (c) DDR-less reduced config — pick one (or stage c→b).
4. **SV-interface/iverilog spike:** budget 1 day to confirm PULP `axi` sim path (Verilator-only vs ports-wrapper) before vendoring.
5. **Core-count target:** confirm 4-core is the goal (vs 1-core-then-scale), given the overlay LUT budget on GW5.
