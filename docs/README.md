# docs

The **documentation repository** of the Ethereal Logic Platform + Astral OS.
It holds the high-level specs, the `ethereal-plan/` plan library (the
authoritative subsystem/component breakdown), and `reports/` (the per-task
acceptance reports mandated by global rule G3).

## Contents

| Path | What it is |
|---|---|
| `ARCHITECTURE-OVERVIEW.md` | Canonical read-only synthesis (TL;DR, architecture, web verification §8, risks §7, open questions §9). **Read this first.** |
| `Ethereal-Logic与Astral-OS容器化平台调研与路线图.md` | v1.0 survey & roadmap (related work, the 3-route comparison) — the "why". |
| `Ethereal-平台实施蓝图-v2.md` | v2.0 implementation blueprint + ADR-001..012 (Overlay-first). |
| `Ethereal-蓝图v2.1-BMC与运行时修订.md` | v2.1 revision + ADR-013..017 (NEORV32 BMC). **Latest; overrides v2.0.** |
| `ethereal-tasks.yaml` | Machine-readable task list (the live work queue). |
| `reports/` | Per-task acceptance reports (`report-<taskId>-YYYYMMDD.md`, rules G3/G4/G5). |

> **Precedence:** v2.1 overrides v2.0 overrides v1.0. `ethereal-tasks.yaml` is
> synced to the latest. The detailed `phases/`, `subsystems/`, and
> `components/` plan files live in the sibling [`ethereal-plan/`](../ethereal-plan/)
> directory (one level up).

**License:** **Creative Commons Attribution-ShareAlike 4.0 International**
(**CC-BY-SA-4.0**). See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)).
