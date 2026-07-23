# Key Decisions & ADRs — Ethereal Platform

> Architecture Decision Records. v2.1 (latest) overrides v2.0 overrides v1.0.
> Synced from `/memories/repo/decisions-adrs.md`.

## v2.0 Blueprint ADRs (ADR-001..012)
| ADR | Decision | Rationale |
|---|---|---|
| **001** | **Overlay (virtual reconfigurable fabric) = first priority**, fine-grained (LUT-level) start | Cross-vendor binary compat (JVM-style); no vendor PR flow dependency; ONLY viable path for Gowin (no user-level PR); reconfig = writing SRAM (µs-ms), avoids bitstream-reverse-engineering legal risk |
| **002** | **ZUMA: modernized reimplementation → "Ethereal Fabric"** (NOT direct use) | ZUMA is 2012 work (VPR6, aged Verilog gen) BUT still best public baseline: LUTRAM config, Clos input interconnect, 40 phys-LUT/virtual-LUT. Modernize: heterogeneous tiles, frame-based PR, Landy/Stitt interconnect opt (~50% reduction), VPR8/nextpnr |
| **003** | **Target platforms**: (a) Gowin GW5AST-138 (Tang Mega 138K) overlay main; (b) Zynq UltraScale+ (overlay + native DFX dual) | GW5: 138,240 LUT4, 340 BSRAM, 298 DSP. Zynq: mature DFX, ICAP DMA 757MiB/s |
| **004** | **Fabric = heterogeneous tiles + init-configurable regions** (user proposal adopted) | Region count/size/composition defined in fabric.yaml at base-image build. Methodology from FABulous CSV + supertile fusion |
| **005** | **Licenses**: SW=MIT, HW RTL=CERN-OHL-S-2.0, docs/specs=CC-BY-SA | User final. MIT has no patent grant → mitigate with DCO Signed-off-by |
| **006** | **EBI bus 3 profiles**: EBI-Full (AXI4-Lite + own NoC) / EBI-Lite (own NoC only) / EBI-Tiny (simple reg bus) | Reuse own Mailbox NoC as backbone; AXI4-Lite for ecosystem; constrained devices fall back to EBI-Tiny |
| **007** | **IO redirect 2 levels**: L1 pin Mux (grouped Crossbar) + L2 protocol proxy (hard-core resource wrap-in + soft-core protocol engine) | GW5 hard resources (SerDes/PCIe/MIPI/ADC) wrapped as proxies into EBI |
| **008** | **FPGA↔MCU/host link dual channel**: SPI=data/config main, I2C=platform monitor (PMBus-style) | User final. I2C monitor also serves Astral health mgmt |
| **009** | **Service Tile concept formal**: fixed-function modules (NPU etc) as dedicated region, coexist w/ vFPGA regions | Like Coyote v2 "services". First candidate: NPU-Tiny (INT8 8×8 systolic, Gemmini-inspired) |
| **010** | **Control plane: independent first, std-interface interop, unify later** | Ethereal=EFP protocol / Astral=ACP protocol; Phase 2 interop via Type-F container; Phase 4 unified orchestrator |
| **011** | **Building base image w/ vendor tools ≠ compliance risk** | Overlay logic-image is self-own format config data (NOT vendor bitstream) → no Gowin/AMD bitstream-format dependency |
| **012** | **MAP route decision (Phase 0 spike)**: A=VPR+custom XML / B=FABulous+nextpnr — decide after spike | Circuit-breaker: if VPR arch doesn't converge in 2 weeks → switch to B or self-research placer+PathFinder router (5 person-day cap each) |

## v2.1 Revision ADRs (ADR-013..017)
| ADR | Decision | Rationale |
|---|---|---|
| **013** | **Platform mgmt unit = fabric-internal RISC-V soft-core ("Ethereal BMC")**; deprecate GW5 AE350 hard-core | BMC model proven by server industry decades: independent of business load, resident, handles health/config/power policy. Soft-core route → mgmt subsystem 100% cross-vendor portable (same RTL+FW on Gowin/AMD/Intel); no vendor hard-core paywall |
| **014** | **Small devices degrade to mFSM (mgmt FSM)**: hardwired register-based unit, policy runs on host | Don't waste LUT on CPU when resources scarce; host drives via SPI/I2C read/write of same registers |
| **015** | **BMC & mFSM unified ABI = EMRI (Ethereal Management Register Interface)** | Same register mapping → consistency across device scales; ethctl doesn't care which side |
| **016** | **BMC core choice: primary NEORV32, fallback VexRiscv**, wrapped in swappable `bmc_core` wrapper | NEORV32 peripheral match perfect (TWD=I2C slave monitor, SDI=SPI data endpoint, DMA, TRNG, WDT, JTAG OCD). VexRiscv higher perf (SpinalHDL adds maintenance cost) |
| **017** | **Inference-First**: own cores MUST NOT instantiate vendor IP/primitives; DSP/RAM = behavioral, let each platform EDA infer. Non-inferable (PLL/ADC/SerDes) only in `hal/<vendor>/glue/` w/ Verilator stub | Ensures ALL own logic is Verilator-verifiable INCLUDING the "reconfiguration" behavior itself (native DPR can't — AMD UG909: "Partial reconfiguration itself cannot be simulated") |

## EMRI register map (BMC/mFSM unified ABI, ADR-015)
| Offset | Register | Semantics |
|---|---|---|
| 0x00 | MAGIC/ABI_VERSION | `0x45544852` ("ETHR") |
| 0x04 | CAPABILITIES | bit0 has_bmc / bit1 has_dma / bit2 has_i2c_mon … |
| 0x08 | PLATFORM_ID | device/board ID |
| 0x10-0x1F | REGION_TABLE | region desc (count/size) |
| 0x20 | OCC_CMD/STATUS | OCC passthrough (BMC=notify, mFSM=direct-drive) |
| 0x30 | HEALTH_STATUS | per-region health bitmap |
| 0x38 | EVENT_LOG_PTR | event ring buffer head/tail |
| 0x40+ | MON_TEMP/VCC/... | telemetry (mFSM may be read-only direct ADC) |
