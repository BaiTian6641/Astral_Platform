# astral-os

**Astral** is the embedded **container runtime** that aggregates with the
Ethereal fabric into one orchestration plane (the "Astral OS"). It runs on
embedded MCUs as **Zephyr userspace + WAMR (WebAssembly Micro Runtime)** and
hosts three container classes: **Type-N** (native C app), **Type-W** (WASM
app), and **Type-F** (a WASM/native app whose compute body is an Ethereal FPGA
region — the bridge between Astral and Ethereal). Astral talks to the fabric
through the EFP (Ethereal Fabric Protocol) client library; the two control
planes (EFP / ACP) are unified in Phase 4 (ADR-010).

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> Astral aggregation begins in Phase 2 (mFSM/Type-E) and matures in P3/P4.
> See `docs/ethereal-tasks.yaml`.

**License:** **MIT**. See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library.

## Structure (planned)

```
astral-os/
├── kernel/      # Zephyr userspace + WAMR integration, capability guard
├── containers/  # Type-N / Type-W / Type-F runtime support
├── efp_client/  # EFP (Ethereal Fabric Protocol) client library
└── tests/
```
