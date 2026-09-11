# capabilities.yaml — Logic-Image Capability Declaration (v0, draft)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0** · Date: 2026-09-11
> Plan-Ref: `ethereal-plan/subsystems/S06-IO重定向.md §2` (引脚分配规则),
> `ethereal-plan/subsystems/S09-镜像格式与仓库.md:24` (五件套清单),
> `ethereal-plan/subsystems/S10-安全子系统.md §3 Phase-2 #2` (能力清单校验, E2-SEC1),
> `ethereal-plan/subsystems/S13-Astral聚合.md:36` (Astral 共用同一 schema)
> Implements: ADR-006 (EBI profiles), ADR-007 (two-level IO redirect)
> Decision record: 2026-09-11 maintainer chose **typed entries** (option A) over flat
> identifier lists (B) and enforce-empty-only (C).

`capabilities.yaml` is one of the five logic-image manifest members (S09:24). It
declares what the container **needs**; the platform **grants** from its own
inventory (Board Manifest pin table + EBI proxy instances, S06:37). The check is
a **subset relation**: *declared ⊆ grantable*, and after allocation
*declared ⊆ granted*. Over-declaration is rejected, never silently trimmed.

---

## 1. Schema (v0)

```yaml
# capabilities.yaml
io:
  - group: 0            # L1 pin-group index (one group = 8 physical pins, S06:24/46)
    dir: out            # in | out | inout
services:
  - name: spi0          # L2 proxy / virtual-device instance (RFC-004 unit, S06:39)
    access: rw          # r | w | rw
```

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `io[].group` | int ≥ 0 | yes | L1 pin-group id. Groups are defined by the Board Manifest; group `g` owns pins `8g..8g+7`. |
| `io[].dir` | enum | yes | `in`, `out`, `inout`. `inout` requires a tri-state-capable group; the L2 proxy arbitrates direction. |
| `services[].name` | string | yes | L2 proxy or virtual-device instance name (`spi0`, `i2c0`, `uart0`, `pwm0`, `qei0` — RFC-004 device classes). |
| `services[].access` | enum | yes | `r`, `w`, `rw` — the container's access to the proxy's virtual registers. |

Rules:

1. Both top-level keys are **required** (the packer auto-fills empty lists for
   images that need nothing — `ethimg.py` default body).
2. Unknown top-level keys, unknown per-entry keys, missing required per-entry
   keys, wrong types, or duplicate `(group)` / `(name)` entries are **schema
   violations** and are rejected at pack/verify time.
3. Absent file = empty capability set (`io: []`, `services: []`).
4. Empty declaration (`io: []`, `services: []`) is always valid and grants
   nothing beyond the container's region — the common case for pure-logic
   images.

## 2. Validation semantics

Three stages, in order; each is a hard refusal (no auto-narrowing):

1. **Schema** (host, at pack/verify): §1 rules.
2. **Grantability** (host pre-flight, before the deploy command): every declared
   group exists in the Board Manifest pin table with a level standard/bank that
   can serve `dir`; every declared service name exists in the platform's EBI
   proxy inventory. Failure → `CapabilityDenied` (tooling) / no deploy issued.
3. **Allocation binding** (device, post-ALLOC / pre-BLANK): the daemon compares
   the staged declaration (`CAP_DECL_IO`/`CAP_DECL_SVC`, EMRI v0.6) against what
   the region can actually expose; a mismatch → refuse with
   `EFP_ERR=11 capability_denied`, event-log `code=4` (`policy_denied`), no
   BLANK, no fabric mutation.

**v0 sim scope:** the fabric has no physical IO, so the sim platform inventory is
a daemon-side allowed mask (`DAEMON_IO_GROUPS`, `DAEMON_SERVICES`) instead of a
Board Manifest. // ASSUMPTION: sim allowed-mask stands in for the Board Manifest
pin table until E1-IO3/E2-IO1 land (TBD, 2026-09-11).

## 3. Relationship to other members

| Member | Role |
| --- | --- |
| `interface.yaml` | EBI ABI version, interrupts, clock needs (S09:23) — **not** a permission list. |
| `capabilities.yaml` | Permission declaration (this spec). |
| `resources.yaml` | eLUT/MEM-T/DSP-T counts — region *matching*, not permissions (S09:25). |
| `health.yaml` | Watchdog period / restart policy (S09:26). |

`interface.yaml:io_needs` stays an informational list; enforcement happens on
`capabilities.yaml` only (S10:44).

## 4. Host tool surface (v0)

- `ethereal-tools/tools/ethimg.py`: pack-time schema check + `verify()` extension
  (`--allow-unsigned` does **not** relax capability checks).
- `ethereal-runtime/security/capcheck.py`: parser + validator + typed errors
  (`CapabilitySchemaError`, `CapabilityDenied`), importable by `ethctl` and the
  EFP host path.
- `ethctl deploy` / `EfpClient.run_image`: pre-flight stage 2; refusal prints the
  exact offending entry.

## 5. Open items

- Board Manifest pin table schema (E1-IO3) — replaces the sim allowed mask.
- Astral side reuse: `astral-os` capability manifest maps 1:1 onto this file
  (S13:36); field names freeze when Astral v1 lands (E2-AST1).
- Finer granularity (per-pin rather than per-8-pin-group, per-proxy-register
  rather than per-proxy) is a v1+ question (S10:73).
