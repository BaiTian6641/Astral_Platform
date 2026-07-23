# ethereal-runtime

The **device-side runtime** of the Ethereal Logic Platform: the
**ethereal-daemon** and the **bmc-fw** firmware. `bmc-fw` is written in C
(NEORV32 libs → Zephyr in Phase 4, per ADR-016/roadmap) with
`-Wall -Wextra -Werror` and no dynamic allocation, and runs on the fabric-
internal BMC soft core. Together they implement image verification (Ed25519),
region lifecycle (the `blank-before-write` rule — see ADR/gotchas), watchdog,
and health/monitor aggregation, exposing the unified **EMRI** register ABI so
`ethctl` cannot tell whether it is talking to a full BMC or a small-device
mFSM (ADR-014/015).

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> Runtime lands in Phase 0/1 (task groups `E0-BMC*`/`E0-DAEMON*` →
> `E1-*`). See `docs/ethereal-tasks.yaml`.

**License:** **MIT**. See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library
(`subsystems/S02-OCC与配置体系.md`,
`subsystems/S05-BMC与EMRI-mFSM.md`,
`subsystems/S08-运行时daemon与ethctl.md`,
`components/C-soft-工具与固件组件.md`,
`components/C05-BMC组件.md`).

## Structure (planned)

```
ethereal-runtime/
├── bmc-fw/            # C firmware for the NEORV32 BMC (bare-metal -> Zephyr P4)
├── daemon/            # ethereal-daemon: image verify, region lifecycle, watchdog
└── tests/
```
