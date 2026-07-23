# Ethereal Logic Platform 蓝图修订 v2.1
## BMC 软核管理子系统与运行时架构修订

> 本修订基于两条新的决策输入：(1) 资源充足的 FPGA（不论 Gowin/AMD/Intel）一律在 fabric 内集成**自研管理的 RISC-V 软核**作为平台监控与资源管理单元——角色对标服务器的 **BMC**（Baseboard Management Controller）；(2) 过小的 FPGA 不提供该选项，缩减为**简单管理 FSM**，由上位机控制。
>
> 同时记录一项重要的实地经验：**GW5 片内硬核 RISC-V（AE350）弃用**——其工具链与 JTAG 调试均需付费且软件质量差，继续投入不如自放软核。原蓝图 E1-PLT3（AE350 启动）任务取消，风险 R2 消除。
>
> 本文件与 v2.0 蓝图配套，冲突处以本文件为准。任务清单 `ethereal-tasks.yaml` 已同步更新。

---

## 1. 新增/修订决策（ADR）

| ADR | 决策 | 依据 |
|---|---|---|
| ADR-013（新增） | **平台管理单元 = fabric 内 RISC-V 软核（Ethereal BMC）**，资源充足器件一律集成；弃用 GW5 AE350 硬核 | BMC 模式经服务器行业几十年验证：独立于业务负载、常驻、负责健康/配置/电源策略。软核路线使管理子系统**跨厂商 100% 可移植**（同一份 RTL + 同一份固件跑在 Gowin/AMD/Intel）；不受厂商硬核工具链付费墙限制 |
| ADR-014（新增） | **小器件降级为 mFSM（management FSM）**：硬连线的寄存器式管理单元，策略执行在上位机 | 资源不足时不浪费 LUT 养 CPU；上位机（Astral MCU/主机）经 SPI/I2C 读写寄存器执行相同的管理语义——**BMC 与 mFSM 暴露同一套寄存器 ABI**，对上位机透明 |
| ADR-015（新增） | **BMC 与 mFSM 统一 ABI**（Ethereal Management Register Interface, EMRI） | 见 §4；这是"同一个平台，不同规模器件"体验一致性的关键 |
| ADR-002（修订） | 平台档案中 GW5AST-138 的 AE350 条目改为"**弃用，保留为电阻丝**"；管理职能移交 BMC 软核 | 用户实地经验：AE350 工具链/JTAG 付费、软件难用 |

---

## 2. BMC 软核选型矩阵

| 候选核 | 资源（典型配置） | 频率参考 | 外设/生态 | 许可证 | 评估 |
|---|---|---|---|---|---|
| **NEORV32**（推荐主选） | ~2,300 LUTs（rv32imc RTOS 就绪配置）[^1^] | 100~130 MHz（Cyclone IV）；现代器件更高 | **原生带齐 BMC 所需一切**：2×UART、SPI host、**SDI（SPI device）**、**TWI（I²C host）+ TWD（I²C device）**、32×GPIO、32×PWM、DMA、TRNG、看门狗、XBUS（Wishbone/AXI 桥）、SLINK 流口、**标准 JTAG OCD（OpenOCD/GDB）**[^1^] | BSD-3-Clause | **外设匹配度满分**：TWD 直接就是监控通道 I²C 从机；纯 VHDL（官方提供 Verilog 转换），Gowin EDA/Vivado/Quartus/nextpnr 全兼容；文档质量开源界顶级 |
| VexRiscv（备选/高性能档） | small ~500 LUTs；full（RV32IM+调试）~1,418 LUTs @216MHz（Artix-7）[^2^] | 200~340 MHz 级 | Murax SoC 模板、JTAG OpenOCD、LiteX 生态（Etherbone 调试）；DMIPS/MHz 最高（1.21~1.38）[^2^] | MIT | 性能/面积比最优；但 SpinalHDL 工具链引入额外学习/维护成本，外设需自行拼装；可用官方预生成 Verilog 规避 SpinalHDL 依赖 |
| PicoRV32 | ~760~2,020 LUTs [^3^] | 高（非流水，IPC 低） | picosoc 模板；Gowin 社区验证最充分（Tang 系例程多） | ISC | 稳妥备胎；无流水线、性能低，BMC 场景性能不敏感故可接受 |
| SERV | ~125~250 LUTs [^4^] | — | 位串行，世界最小 RISC-V | ISC | 只适合"想要 CPU 但 LUT 极紧张"的边角场景；性能过低，不建议用于主 BMC |

**选型结论：主选 NEORV32，VexRiscv 作为可替换备选。** 两者统一封装在 `bmc_core` wrapper 内（指令无关的 SoC 顶层只对接标准总线），换核不动系统。决策记录为 ADR-016。

> 注：NEORV32/VexRiscv/PicoRV32/SERV 均为宽松许可证，与我们的 CERN-OHL-S v2（硬件仓）和 MIT（软件仓）兼容，实例化无合规障碍。

---

## 3. Ethereal BMC 架构

```
┌──────────────────────── Ethereal BMC（Shell 内，常驻） ───────────────────────┐
│  NEORV32 (rv32imc, ~2.3K LUT)                                                │
│    │ XBUS/Wishbone                                                           │
│    ├─ Boot ROM (BSRAM, 4~8KB) ─ 安全启动 + 固件加载                           │
│    ├─ FW SRAM (BSRAM, 64~128KB) ─ 固件 + 镜像暂存缓冲                          │
│    ├─ UART0 ─ 控制台/调试            UART1 ─ 预留（上位机命令通道备选）          │
│    ├─ SDI (SPI device) ◄── 上位机数据通道（EFP-SPI 帧协议端点）                 │
│    ├─ TWD (I²C device) ◄── 上位机监控通道（PMBus 风格命令，RFC-003）            │
│    ├─ TWI (I²C host) ──► 板级传感器/电源管理（可选扩展）                        │
│    ├─ DMA ──► OCC 配置帧高速搬运（镜像加载加速）                                │
│    ├─ TRNG ──► 验签 nonce / 安全用途                                          │
│    ├─ WDT ──► BMC 自身看门狗（业务逻辑恢复 BMC 的最后手段：触发全 region blank）│
│    └─ EBI 桥 ──► Shell 地址空间（OCC / region 窗口 / Service Tile / IO 代理）   │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 固件模块分解（`ethereal-runtime/bmc-fw/`）

| 模块 | 职责 | 对应 v2.0 任务 |
|---|---|---|
| boot | 安全启动：FW 完整性校验（SHA-256，后期 Ed25519 在 boot ROM）、失效回退到黄金 FW（双分区） | E1-BMC2 |
| efp-endpoint | EFP-SPI 帧协议端点：镜像接收（DMA 到 SRAM 缓冲）、命令会话 | E1-IO1 + E1-RUN2 |
| monitor | I²C 监控通道服务端（RFC-003 命令集）；遥测采集（温度/电压：Gowin X 通道 ADC、Zynq SYSMON）；事件环形日志 | E1-IO2 |
| lifecycle | region 生命周期状态机（Empty→Loading→Verifying→Running→Stopping→Blank，语义对齐 AMD DFX Controller [^5^]）；region 分配表 | E1-RUN2 |
| verify | 镜像验签（Ed25519；软件实现先用，性能不足时加硬件加速 Service Tile——自举的好例子） | E1-RUN1/RUN2 |
| watchdog | region 心跳监督、超时 blank、restartPolicy 执行 | E1-RUN4 |
| health | 健康策略引擎（脚本化规则，后期）；context save/restore 编排（Phase 2） | E2-FAB3 |
| scrub | （Zynq）SEU 擦洗调度（Phase 3） | E3-MON1 |

固件底座：v1 裸机（NEORV32 自带库足够）；v2 评估 Zephyr（NEORV32 有上游 Zephyr 支持）——**这与 Astral 天然会师：BMC 可以直接成为 Astral 的一个节点**，Type-F 容器的宿主。

### 3.2 存储预算（GW5AST-138 实例）

| 用途 | 大小 | 载体 | 占比 |
|---|---|---|---|
| Boot ROM | 8 KB | BSRAM ×4 | 1.2% |
| FW + 堆栈 | 128 KB | BSRAM ×58 | 17% |
| 镜像暂存（双缓冲） | 256 KB | SSRAM（1080Kb 池）或 BSRAM | — |
| BMC 逻辑 | ~2.5K LUT（核+SoC 胶合） | fabric | < 2% |

**结论：BMC 全部开销（逻辑 + 固件存储）占 GW5AST-138 不足 20% 的 BSRAM 和不到 2% 的 LUT——相比 AE350 的付费墙与难用，这是一笔非常划算的交易。** 小器件（如 GW5AT-15/GW2A-18）则走 mFSM，存储预算归零。

### 3.3 调试策略（替代 AE350 付费 JTAG 的关键问题）

1. **首选：UART 控制台 + 日志**（零成本，永远可用）；
2. **JTAG 调试**：NEORV32 的 OCD 是标准 RISC-V Debug Spec JTAG——将 BMC 的 JTAG 引到板级排针（2 根线 TCK/TMS + TDI/TDO 共 4 根，与 FPGA 自身 JTAG 链独立），用任意 JTAG 适配器 + OpenOCD + GDB 调试，**完全免费**；
3. **进阶（后期）**：经 EFP 通道的远程 gdbstub（上位机隧道），实现"容器平台自己的远程调试网口"——对标 BMC 的 SOL（Serial over LAN）。

---

## 4. EMRI：BMC / mFSM 统一管理 ABI（ADR-015）

小器件的 mFSM 与 BMC 对上位机暴露**同一寄存器映射**（SPI/I2C 可寻址）：

| 偏移 | 寄存器 | 说明 |
|---|---|---|
| 0x00 | MAGIC / ABI_VERSION | 0x45544852 ("ETHR") + ABI 版本 |
| 0x04 | CAPABILITIES | bit0: has_bmc; bit1: has_dma; bit2: has_i2c_mon; … |
| 0x08 | PLATFORM_ID | 器件/板卡 ID |
| 0x10 | REGION_COUNT / 0x14 REGION_TABLE… | region 描述 |
| 0x20 | OCC_CMD / OCC_STATUS | 透传 OCC 命令（上位机直控或委托 BMC） |
| 0x30 | HEALTH_STATUS | 各 region 健康字 |
| 0x38 | EVENT_LOG_HEAD/TAIL | 事件日志环形缓冲 |
| 0x40 | MON_TEMP / MON_VCC… | 遥测（mFSM 时可为只读直连 ADC） |

- **BMC 模式**：上位机发高级命令（"部署镜像 X 到 region 1"），BMC 固件执行全流程；
- **mFSM 模式**：同一寄存器面，但镜像接收、验签、状态机转移由上位机逐步驱动——协议相同，智能的位置不同；
- 对 `ethctl` 完全透明：CLI 不知道也不关心对面是 BMC 还是 mFSM。

---

## 5. 部署 Profile 表（修订 v2.0 §4.1）

| 模块 | Profile-G（GW5AST-138） | Profile-Z（Zynq US+） | Profile-E（小器件 + 外挂 MCU） |
|---|---|---|---|
| 管理单元 | **BMC（NEORV32 软核）** | **BMC（同一软核，PL 内）**；PS 为可选上位机 | **mFSM**（寄存器面），策略在外挂 MCU |
| EBI | Full/Lite | Full | Tiny |
| 上位机链路 | SPI（数据）+ I²C（监控） | 同左（对外）+ 可选 PS 内部通道 | 同左（直连 mFSM） |
| 镜像存储 | SRAM 缓冲 + 可选板载 Flash/DDR3 | 同左 + PS 侧文件系统 | 外挂 MCU 的 Flash |
| SEU 擦洗 | 评估中（Gowin 读回能力待确认） | ✅（SEM，BMC 调度） | ❌ |

---

## 6. 任务变更（同步至 ethereal-tasks.yaml）

**取消**：E1-PLT3（AE350 启动）——连同其 4 人日预算与"受阻熔断"条款一并移除；风险 R2 标记为已消除。

**新增（Phase 1）**：

| ID | 任务 | 产出 / 验收 | 预估 |
|---|---|---|---|
| E1-BMC1 | BMC SoC 集成（`bmc_core` wrapper：NEORV32 + Boot ROM + 128KB FW SRAM + UART + EBI 桥） | 仿真（Verilator）+ GW5 双平台跑通 hello-world 与 CSR 读写；BMC 总开销报告（LUT + BSRAM）| 4 人日 |
| E1-BMC2 | BMC 固件框架（boot 双分区、驱动层、lifecycle 状态机骨架） | 固件经 UART 启动，region 状态机空转演示；OTA 式 FW 自更新演示 | 4 人日 |
| E1-BMC3 | 调试通道（UART 控制台 v1 + JTAG 排针引出 + OpenOCD 配置） | GDB 断点/单步调试 BMC 固件成功；文档化调试指南 | 2 人日 |
| E1-BMC4 | EMRI 寄存器面实现（ADR-015 表）+ 上位机探测逻辑 | `ethctl` 经 EMRI 自动识别 BMC/mFSM 模式 | 2 人日 |
| E2-BMC1 | mFSM 精简管理单元（无 CPU 寄存器式，用于 Profile-E） | 在仿真中以上位机脚本驱动完整部署流程 | 4 人日 |
| E2-BMC2 | （可选）VexRiscv 备选核 wrapper 验证 | 同一份固件 ABI 在备选核上跑通（验证核可替换性） | 3 人日 |

**修订**：
- E1-RUN2（daemon）改为运行于 BMC 固件之上（est. 5→4 人日，因 NEORV32 生态自带 UART/SPI/I2C/DMA 驱动，省去外设驱动开发）；
- E1-DMO1 热替换目标改为 **< 10 ms（BMC + DMA 内存映射通道）** / < 100 ms（上位机经 SPI 推流）——目标反而提高了，因为 DMA 直连 OCC；
- E1-IO1/E1-IO2 的实现主体改为"NEORV32 SDI/TWD 外设 + 固件协议栈"，RTL 工作量下降（各 3→2 人日）；
- 风险 R2 移除；新增 R9：NEORV32 在 Gowin EDA 综合的时序/原语推断小问题（概率中、影响低——社区已有 Gowin 移植先例，备选核预案为 E2-BMC2）。

**Phase 1 人日净变化**：约 **-1 人日**（取消 4 + 新增 12 - 既有任务减负 ~5），但**移除了一整条付费工具链依赖和最大的 bring-up 不确定性**。

---

## 7. 战略层面的意外收获

这次修订不只是规避了一个难用的硬核，还带来三个结构性优势：

1. **跨厂商管理面统一**：同一颗 BMC（RTL + 固件）跑在 Gowin/AMD/Intel 上，运维体验完全一致——这在 FPGA 行业是稀缺品（MicroBlaze/Nios V 锁厂商，硬核各有工具链）；
2. **BMC 是 Astral 的天然桥头堡**：BMC 固件 v2 迁移到 Zephyr 后，BMC 即成为一个 Astral 节点——"管理平面"与"业务平面"用同一套容器技术，这正是你"聚合化"愿景在系统内部的就先实现；
3. **可讲的故事更完整了**："每个接入 Ethereal 的 FPGA 都有一颗 BMC"——对工业客户（远程运维、健康审计、预测性维护）是极易理解的卖点，对标服务器行业的 BMC/IPMI 心智。

---

## 参考文献（v2.1）

[^1^]: NEORV32 RISC-V Processor（外设清单：SDI/TWD/TWI/DMA/TRNG/看门狗/JTAG OCD；~2300 LUTs RTOS 配置；BSD-3）, GitHub — https://github.com/stnolting/neorv32
[^2^]: VexRiscv（配置-面积-频率表：small 504LUT@243MHz、full 1418LUT@216MHz，Artix-7；Murax SoC；MIT）, GitHub — https://github.com/SpinalHDL/VexRiscv
[^3^]: Rodrigues, "Configurable RISC-V softcore processor for FPGA"（PicoRV32 760~2020 LUTs、VexRiscv 496~1758 LUTs 等横评）, IST 2019 — https://hpcas.inesc-id.pt/~handle/papers/MSc_JoaoRodrigues_2019.pdf
[^4^]: SERV — the SErial RISC-V CPU（125~239 LUTs；ISC）, GitHub — https://github.com/olofk/serv
[^5^]: "Dynamic Function eXchange with ICAP Driven by Software"（DFX Controller 状态机，BMC lifecycle 语义参照） — https://blog.abbey1.org.uk/index.php/technology/dynamic-function-exchange-with-icap-driven-by-software

*v2.1 · 2026-07 · 与 v2.0 蓝图、v1.0 调研文档配套；ethereal-tasks.yaml 已同步*
