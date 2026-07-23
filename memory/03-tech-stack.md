# Tech Stack & Dependencies — Ethereal Platform

> All tools' install scripts/Dockerfiles/CI are PLANNED, not yet built (tasks E0-INF1..3, Phase 0 week 1).
> Synced from `/memories/repo/tech-stack.md`.

## Languages & runtimes (G1 quality gates)
| Layer | Lang | Use | Quality gate |
|---|---|---|---|
| HW RTL | **SystemVerilog** (inherits TinyGPU-FPGA RTL Policy) | fabric/Shell/BMC periphery/proxy/Service Tile | `default_nettype none`; `always_ff` non-blocking `always_comb` default-first; FSM `typedef enum` two-seg; `verilator --lint-only -Wall` zero warns |
| Toolchain | **Python 3.12** | fabric-gen/mapper/bitgen/ethimg/ethctl/CI | `ruff` + `mypy --strict` |
| Embedded FW | **C** (NEORV32 libs → Zephyr in Phase 4) | bmc-fw (boot/efp/monitor/lifecycle/verify/watchdog/log) | `-Wall -Wextra -Werror` + `clang-format`; no dynamic alloc (static heaps need comment justification) |
| Sim | **Python** (cocotb) + Verilator C++ | BFM/testbench/protocol models | — |

## Toolchain deps (by purpose, web-verified licenses)
| Category | Tool | Role | License |
|---|---|---|---|
| **Sim** | Verilator 5.x | RTL cycle-level sim (main vehicle for own-logic verification) | LGPL/Artistic |
| | cocotb | Python-driven testbench + BFM lib | MIT/BSD |
| **Synth/P&R** | Yosys | synth (custom techlib `synth_ethereal`) | ISC |
| | VPR 8 (VTR) | pack/place/route, custom arch XML | **MIT** (confirmed verilogtorouting.org) |
| | nextpnr-himbaechel | alt P&R (Gowin Aurora V channel) | MIT |
| **Vendor** | Gowin EDA (gw_sh Tcl) | GW5 base image build | commercial (edu supports 138K) |
| | Vivado | Zynq US+ base image + DFX | commercial |
| **Bitstream** | Apicula | Gowin bitstream documentation | ISC |
| | OpenFPGA FPGA-Bitstream | two-level bitstream methodology ref | MIT |
| **Flash/CI** | OpenFPGALoader | flashing + CI automation | GPLv2 |
| | GitHub Actions | 3-tier CI (gate/unit/integration/nightly/HIL) | — |
| **Soft-core** | NEORV32 | BMC core (rv32imc, ~2.3K LUT) | **BSD-3** |
| | VexRiscv (fallback) | core-swap verification | MIT |
| **Method ref** | FABulous | eFPGA generator (CSV + frame-based PR, v2.1.1) | Apache-2.0 |
| | ZUMA / Landy-Stitt | overlay arch baseline + interconnect opt | paper (reimplemented) |
| | Coyote v2 | datacenter FPGA OS abstraction (ASPLOS25) | open source |

## Planned build/run/test flows
**Sim env (Phase 0, 30-min reproduce):** `make sim` / `make test` / `make lint`
**Base image build (Phase 1, low-freq, once/board):** `fabric-gen fabric.yaml` → `gw_sh build.tcl` → `openFPGALoader`
**Logic image build (user daily, high-freq):**
```bash
yosys -p "synth_ethereal -top aes128 demo.v"   # → eLUT4 netlist
vpr arch_ethereal.xml aes128.net --pack --place --route
bitgen --frame-map frame_map.json aes128.route  # → frames.bin
ethimg pack aes128/ -o aes128.eth                # → +manifest +Ed25519 sig
ethctl run aes128.eth --region 0                 # deploy to GW5 (<30s)
```
**Test tiers (S14):** gate (sec: lint/format/license) → unit (min: cocotb) → integration (10min: Verilator full-system + bit-true benchmarks) → regression (nightly: random/fuzz/long-soak) → HIL (self-hosted runner + GW5/Zynq nightly).

## Planned repo layout (E0-INF1)
```
github.com/ethereal-fpga/   (org name TBD via E0-INF4)
├── ethereal-fabric     RTL: fabric, OCC, tile lib, HAL        CERN-OHL-S v2
├── ethereal-shell      RTL: EBI, IO redirect, Service Tile    CERN-OHL-S v2
├── ethereal-tools      fabric-gen, mapper, ethimg, ethctl      MIT
├── ethereal-runtime    daemon (BMC/Linux/MCU profiles)         MIT
├── ethereal-spec       EBI, image fmt, Board Manifest, EFP/ACP CC-BY-SA
├── ethereal-images     official logic/service images+benchmarks MIT(image)/CERN-OHL-S(RTL)
├── astral-os           Astral runtime + container spec         MIT
└── docs                docs site + wiki                          CC-BY-SA
```

## Critical upstream deps (MUST read before impl, README §4)
| Dep | Location | Use | Status |
|---|---|---|---|
| **AXI-MailboxFabric** (user's own NoC) | `github.com/BaiTian6641/TinyGPU-FPGA/ip/mailbox` | EBI-Lite backbone (S04) | ✅ **Migrated 2026-07-24** (S04-P0#1) → `ethereal-shell/rtl/{mailbox,interface}/` + `docs/mailbox_interconnect_spec.md` under CERN-OHL-S-2.0 + provenance headers; G1-cleanup pending → advisory `make lint-mailbox` |
| SPI/UART fabric satellite adapters | same repo `ip/interface/{spi,uart}/` | L2 proxy reuse starting point (C06 §2.3) | pending migration |
| SystemVerilog RTL Policy | same repo `docs/SystemVerilog_RTL_Policy.md` | G1 rules source | pending link |
| NEORV32 | github.com/stnolting/neorv32 | BMC core | BSD-3, ready to use |
| **Main verify board** | Tang Mega 138K **Dock** (GW5AST-LV138PG484A) | Profile-G main battlefield | confirmed |

## ✅ BLOCKER RESOLVED (2026-07-24)
Mailbox RTL licensing + migration **DONE** (S04-P0#1): 14 RTL + 1 spec migrated to `ethereal-shell/` under CERN-OHL-S-2.0 with provenance headers; see `ethereal-shell/docs/MIGRATION-mailbox.md`. Remaining: G1-cleanup backlog (procedural loops, FSM typedef, nettype restore) — linted separately via advisory `make lint-mailbox`, target new task `S04-P0#2`. Real `verilator --lint-only -Wall` + cocotb are Docker-gated (no verilator/docker in authoring env).

## Verified platform facts (2026-07 web cross-check, baseline for design)
- GW5 CFU supports LUT4/ALU/**memory mode**; each CLS has 2 regs w/ CE/SR/GSR (Gowin DS1103E) → eLUT4 truth-table as distributed RAM; v1 still uses FF (C01 §2)
- GW5 supports SEU detect/correct, background upgrade, goConfig I2C/JTAG IP (DS1113E §2.10) → scrubbing feasible on Gowin (S07)
- GW5 has internal oscillator (1.67-105MHz prog), 12 PLL, 16 global clocks, mDRP (DS1103E) → clock scheme (C12)
- Tang Mega 138K Dock: GW5AST-LV138PG484A, 1GB DDR3, 128Mbit Flash, USB-JTAG/UART, ADC×2
- gw_sh Tcl batch (`run all/syn/pnr`) — Gowin SUG1220E → C12 base build automation
- NEORV32 upstream Zephyr support (v1.11.6); JTAG debug: official suggests header pins + FTDI → C05/E4-BMC1
- GowinSynthesis supports DSP inference (pre-add/accumulate/chain-add/reg absorption, `syn_dspstyle` tune) + memory inference (SUG550E §4.3/§2) → ADR-017 (C13) Gowin basis
- Yosys `synth_gowin` infers lutrams/brams via memory_libmap
- Vivado/Quartus behavioral DSP/RAM inference rules (signed/pipelined/no-set/no-async-reset) UG901/UG949 → `eth_inf_*` coding red-lines (C13 §2)
- **Native DPR not simulatable** (UG909) → overlay route full-Verilator-verifiable contrast proof
