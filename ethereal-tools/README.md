# ethereal-tools

The **Python toolchain** for the Ethereal Logic Platform (Python 3.12,
`ruff` + `mypy --strict`). It turns a user's RTL/logic description into a
portable logic image and operates the device: **fabric-gen** (tile
generator from `fabric.yaml`), the **mapper** (Yosys tech-map → VPR/FABulous
placement+routing, ADR-012 route decided by a Phase-0 spike), **bitgen**
(routed result → fabric config frames), **ethimg** (5-piece manifest + Ed25519
signature → signed `.eth` image), and **ethctl** (the `docker`-like CLI:
`ethctl run/stop/ps/images/...`, transparent to BMC vs mFSM via the EMRI ABI).

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> The toolchain lands in Phase 0 (tasks `E0-MAP1..5`) once the fabric core
> sim is in place. See `docs/ethereal-tasks.yaml`.

**License:** **MIT**. See [LICENSE](LICENSE).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library
(`subsystems/S03-fabric-gen与映射工具链.md`,
`components/C-soft-工具与固件组件.md`).

## Structure (planned)

```
ethereal-tools/
├── tools/
│   ├── fabric_gen/    # tile + region generator from fabric.yaml
│   ├── mapper/        # Yosys + VPR/FABulous flow, ADR-012 spike
│   ├── bitgen/        # routed design -> fabric config frames
│   ├── ethimg/        # manifest + Ed25519 signing -> .eth image
│   └── ethctl/        # CLI: run/stop/ps/images/inspect/...
├── tests/
└── pyproject.toml     # ruff + mypy --strict config
```
