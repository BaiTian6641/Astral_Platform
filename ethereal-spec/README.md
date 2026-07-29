# ethereal-spec

The **machine-readable + human-readable specification** of the Ethereal Logic
Platform: the **EBI** (Ethereal Bus Interface, 3 profiles), the **logic-image
format** (the `.eth` file: config frames + 5-piece manifest + Ed25519
signature), the **Board Manifest** (per-target fabric map / pin map), and the
**EFP / ACP** control-plane protocols. Per the project's *spec-first* rule
(G6/global rules), a spec change + version bump MUST land here BEFORE any
implementation change in the other repos.

> **Status: Phase-0 fabric specs frozen; Phase-1 management specs in progress.**
> Spec documents are authored incrementally as each subsystem is implemented;
> the authoritative plan library lives under
> [`ethereal-plan/`](../ethereal-plan/). See `docs/ethereal-tasks.yaml`.

## Spec documents

### Fabric (Phase-0, frozen v0)
- [`fabric/clb-t-config-v0.md`](fabric/clb-t-config-v0.md) — CLB-T tile (8 eLUT4 + IIB crossbar).
- [`fabric/elut4-config-v0.md`](fabric/elut4-config-v0.md) — eLUT4 atomic element (LUT4 + FF).
- [`fabric/interconnect-config-v0.md`](fabric/interconnect-config-v0.md) — SB (Wilton) + CB.
- [`fabric/heterogeneous-config-v0.md`](fabric/heterogeneous-config-v0.md) — mem_t / dsp_t tiles.
- [`fabric/fabric_*.yaml`](fabric/) — machine-readable fabric descriptors.

### Control plane (Phase-1, in progress)
- [`control/emri-v0.md`](control/emri-v0.md) — **EMRI**: unified management register ABI
  (BMC + mFSM), EFP-SPI transport, OCC passthrough. ADR-013/014/015/016.

**License:** **Creative Commons Attribution-ShareAlike 4.0 International**
(**CC-BY-SA-4.0**). See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library.
