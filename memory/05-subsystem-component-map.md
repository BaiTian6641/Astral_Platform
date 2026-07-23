# Subsystem & Component Map — Ethereal Platform

> S-series = subsystem engineering files (system view, cross-phase). C-series = component HDL-level (coding view).
> Synced from `/memories/repo/subsystem-component-map.md`.

## Subsystems (S01-S14)
| ID | Name | Repo | Importance | Key role |
|---|---|---|---|---|
| **S01** | Ethereal Fabric virtual logic arch | ethereal-fabric | ★★★★★ | Core innovation: virtual reconfigurable overlay fabric. eLUT4/CLB-T/SB/hetero tiles/region |
| **S02** | OCC & config system | ethereal-fabric | ★★★★★ | Overlay Configuration Controller: frame/blank/lock/CRC32/scan/DMA |
| **S03** | fabric-gen & mapping toolchain | ethereal-tools | ★★★★★ | fabric.yaml→RTL+framemap; Yosys/VPR/bitgen/ethimg. Docker experience half = `docker build` |
| **S04** | EBI bus & Mailbox-NoC integration | ethereal-shell | ★★★★★ | Reuse your TinyGPU Mailbox. region_endpoint + Region ABI 16-word window |
| **S05** | BMC & EMRI-mFSM | shell/runtime | ★★★★★ | Resident brain: NEORV32 + bmc-fw. Unified EMRI ABI w/ mFSM |
| S06 | IO redirect | ethereal-shell | ★★★★☆ | L1 pin Mux + L2 protocol proxy. Region logic NEVER touches physical pins |
| S07 | Monitor & health mgmt | ethereal-shell | ★★★★☆ | I2C PMBus-style + watchdog + event log + SEU scrubbing |
| S08 | runtime daemon & ethctl | ethereal-runtime/tools | ★★★★☆ | daemon lifecycle FSM + Docker-style CLI |
| S09 | Image format & registry | ethereal-spec/tools | ★★★★☆ | `.eth` tar = fabric config frames + 5-piece manifest + Ed25519 |
| S10 | Security subsystem | ethereal-runtime | ★★★☆☆ | v1 prevent accidents, v3+ prevent attacks. Image sig + region lock matrix + capability list |
| S11 | Service Tile | ethereal-shell | ★★★☆☆ | Phase 3+. NPU-Tiny fixed-function module as dedicated region |
| **S12** | Platform Bring-up | (cross) | ★★★★★ | GW5/Zynq/Profile-E bring-up. hal/gowin_gw5 + base build |
| **S13** | Astral aggregation | astral-os | ★★★★☆ | Type-F container: WASM/native app deploys/calls vFPGA via EFP client lib |
| **S14** | Verification & CI infra | (cross) | ★★★★★ | 5-tier test: gate/unit/integration/regression/HIL. GitHub Actions |

## Components (C01-C13)
| File | Covers | Key components |
|---|---|---|
| **C01** | S01 | eLUT4, CLB-T, SB/CB, IO-T |
| **C02** | S01 | MEM-T, DSP-T, SSM-T, Supertile, Region boundary |
| **C03** | S02 | frame org, write engine, Blank engine, verify, lock matrix, CRC32, context scan, DMA |
| **C04** | S04 | mailbox migration, region_endpoint, host_bridge, axi_lite_bridge, irq_concentrator |
| **C05** | S05 | bmc_core, boot/storage, EMRI block, mFSM, debug, clock-reset |
| **C06** | S06 | pin mux group, UART/GPIO/SPI/I2C proxy, hard-core wrap, CDC |
| **C07** | S07 | I2C cmd decoder, telemetry iface, watchdog array, event log |
| **C11** | S11 | PE, systolic array, stagger feed, weight double-buffer, DMA, service regs |
| **C12** | S12 | HAL (inference template + thin glue), clock-reset strategy, constraint template, base build |
| **C13** | ALL (cross-cutting) | **ADR-017: Inference-First** — no vendor IP, behavioral inference, Verilator boundary, inference verification suite |
| C-soft | S03/S08/S09/S10/S14 | fabric-gen, bitgen, EFP-SPI engine, daemon FSM, static checker, CI |

## Subsystem dependency graph
```
S01 Fabric logic → S02 OCC
S03 fabric-gen + mapper → S01, S02
S04 EBI + Mailbox NoC → S02, S06, S07, S11
S05 BMC + EMRI + mFSM → S04, S02, S07
S06 IO redirect → S10
S07 Monitor → S05
S08 daemon + ethctl + EFP → S05, S09
S09 Image format + registry → S10
S10 Security → S02, S06
S11 Service Tile → S04
S12 Platform Bring-up → S01, S05
S13 Astral aggregation → S08
S14 Verification & CI → (cross-cuts) S01, S03, S12
```

## Hardware design 3 principles (components/ all comply)
1. **Think hardware, not software** — before each RTL line: what physical structure (reg/mux/RAM/wire)? which clock domain? reset value? Each component has "physical mapping" section.
2. **Prepare everything IN DETAIL** — interface signal table, params, bitfields, FSM frozen before coding; changes go through ADR. Ambiguities marked `ASSUMPTION`.
3. **Draw diagram for your logic, always** — each component ≥2 diagrams (self block + integration w/ neighbors); data path & FSM separate. Diagrams ARE review objects: review diagram first, then write code.

## Module header standard (G2)
```systemverilog
`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      <module_name>
// Description: <one-line>
// Maintainer:  <name/ID>
// Created:     YYYY-MM-DD
// Modified:    YYYY-MM-DD - <change>
// Tags:        RTL, SYNTH | TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/Sxx.md §x.y   ← trace to plan file
// Notes:       <lint exemption reason / sim-only code note>
```
