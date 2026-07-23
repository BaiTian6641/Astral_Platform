# ethereal-spec

The **machine-readable + human-readable specification** of the Ethereal Logic
Platform: the **EBI** (Ethereal Bus Interface, 3 profiles), the **logic-image
format** (the `.eth` file: config frames + 5-piece manifest + Ed25519
signature), the **Board Manifest** (per-target fabric map / pin map), and the
**EFP / ACP** control-plane protocols. Per the project's *spec-first* rule
(G6/global rules), a spec change + version bump MUST land here BEFORE any
implementation change in the other repos.

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> Spec documents are authored incrementally as each subsystem is implemented;
> the authoritative plan library currently lives under
> [`ethereal-plan/`](../ethereal-plan/). See `docs/ethereal-tasks.yaml`.

**License:** **Creative Commons Attribution-ShareAlike 4.0 International**
(**CC-BY-SA-4.0**). See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library.
