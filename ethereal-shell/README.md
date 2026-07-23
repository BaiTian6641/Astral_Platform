# ethereal-shell

SystemVerilog RTL for the **static Shell** — the non-reconfigurable "baseboard"
of every Ethereal device that hosts the reconfigurable fabric regions. It
contains the **EBI bus** (the AXI-MailboxFabric NoC + AXI4-Lite backbone), the
two-level **IO redirect** (L1 pin Mux + L2 protocol proxy; region logic never
touches physical pins directly), the **BMC SoC glue** around the NEORV32
management core (ADR-013/016), and the **Service Tile** framework
(Phase 2+, e.g. NPU-Tiny). The Mailbox NoC is migrated out of the
`TinyGPU-FPGA` project and re-released here under CERN-OHL-S-2.0 with a
provenance note (see `ethereal-plan/README.md §4`).

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> Shell assembly lands in Phase 0/1 (task group `E0-SHELL1..` → `E1-SHELL*`).
> See `docs/ethereal-tasks.yaml`.

**License:** CERN Open Hardware Licence Version 2 — Strongly Reciprocal
(**CERN-OHL-S-2.0**). See [LICENSE](LICENSE). Per ADR-017, no own RTL
instantiates vendor primitives.

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library
(`subsystems/S04-EBI总线与Mailbox-NoC集成.md`,
`subsystems/S06-IO重定向.md`, `components/C04-EBI组件.md`,
`components/C06-IO组件.md`).

## Structure (planned)

```
ethereal-shell/
├── rtl/
│   ├── ebi/             # EBI bus: AXI-MailboxFabric NoC + AXI4-Lite
│   ├── io_redirect/     # L1 pin Mux + L2 protocol proxy
│   ├── bmc_soc/         # NEORV32 SoC glue (core-agnostic wrapper)
│   └── service_tile/    # Service Tile framework (Phase 2+)
└── tb/                  # cocotb testbenches
```
