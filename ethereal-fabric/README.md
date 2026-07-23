# ethereal-fabric

SystemVerilog RTL for the **virtual reconfigurable overlay fabric** ("an FPGA
inside an FPGA") at the heart of the Ethereal Logic Platform: the atomic
`eLUT4` element, heterogeneous tiles (`CLB-T` / `MEM-T` / `DSP-T` / `SSM-T` /
`IO-T`), switch boxes / virtual routing, the Overlay Configuration Controller
(OCC), and HAL wrappers that confine vendor-specific inference to
`hal/<vendor>/glue/`. User logic is compiled to the fabric's configuration
data (NOT a vendor bitstream), which is what makes the fabric cross-vendor
binary-compatible and fully Verilator-verifiable — including the act of
"reconfiguration" itself (native DPR cannot be simulated, per AMD UG909).

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> This repository currently contains only placeholders. RTL lands starting with
> tasks `E0-FAB1..6` and the OCC (`E0-OCC1..`). See `docs/ethereal-tasks.yaml`.

**License:** CERN Open Hardware Licence Version 2 — Strongly Reciprocal
(**CERN-OHL-S-2.0**). See [LICENSE](LICENSE). Per ADR-017 (Inference-First),
no own RTL instantiates vendor primitives — DSP/RAM are described behaviorally
and left for each platform EDA to infer; non-inferable blocks live only in
`hal/<vendor>/glue/` with a Verilator stub.

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library
(`subsystems/S01-Ethereal-Fabric虚拟逻辑架构.md`,
`components/C01-fabric-核心单元.md`, `components/C02-fabric-异构tile.md`).

## Structure (planned)

```
ethereal-fabric/
├── rtl/                 # fabric RTL (eLUT4, tiles, switch box, OCC) — placeholder
├── hal/<vendor>/glue/   # vendor-specific inference stubs (PLL/SerDes/ADC + Verilator stub)
└── tb/                  # cocotb testbenches
```
