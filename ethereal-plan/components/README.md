# Ethereal 组件级设计文档（components/）

> 本目录把 `subsystems/` 中每个子系统拆解为**可直接指导 HDL 编码的组件设计**：概念、框图、集成图、核心设计（接口/FSM/位域/时钟复位）、问题预案、迭代方向、测试评估。
> 阅读顺序：`subsystems/Sxx.md`（为什么做）→ `components/Cxx-*.md`（具体怎么造）。
> 版本：components-v1.0 · 2026-07

## 硬件设计三原则（本目录所有文档共同遵守）

1. **Think hardware, not software**：HDL 描述的是硬件。写任何一行 RTL 前先回答三个问题——这个信号对应什么物理结构（寄存器/mux/RAM/走线）？它在哪个时钟域？复位后是什么值？每个组件文档都包含"物理映射"小节说明该组件落到什么硬件资源上。
2. **Prepare everything, EVERYTHING IN DETAIL**：组件的接口信号表、参数、位域、状态机在编码前冻结；冻结后改动必须走 ADR。模糊点全部标注 `ASSUMPTION` 并汇总到待确认清单。
3. **Draw diagram for your logic, always**：每个组件至少两张图——自身框图 + 与相邻组件的集成图；数据通路和 FSM 分开画。图即评审对象：先评图，后写码。

> **补充原则 4（ADR-017，2026-07）**：**Inference-First**——自有核心禁止实例化厂商 IP/原语，DSP/RAM 一律行为级描述交各平台 EDA 推断（详见 C13）；不可推断资源（PLL/ADC/SerDes 等）只允许出现在 `hal/<vendor>/glue/` 并配 Verilator stub。这保证了**全部自有逻辑在 Verilator 中可验证**（含"重构"行为本身——原生 DPR 做不到的对照见 C13 §3）。

## 编码风格说明

HDL 语法与风格规则以**用户另行提供的专门规则文档**为准（由专门的 Agent 训练产出，届时链接替换本段）。在其到位前，临时遵循 `../README.md` §2.1（继承 TinyGPU-FPGA SystemVerilog RTL Policy）。

## 组件索引

| 文件 | 覆盖子系统 | 组件 |
|---|---|---|
| C01-fabric-核心单元.md | S01 | eLUT4、CLB-T、SB/CB、IO-T |
| C02-fabric-异构tile.md | S01 | MEM-T、DSP-T、SSM-T、Supertile、Region 边界 |
| C03-OCC组件.md | S02 | 帧组织、写引擎、Blank 引擎、校验、锁矩阵、CRC32、上下文扫描、DMA |
| C04-EBI组件.md | S04 | mailbox 移植、region_endpoint、host_bridge、axi_lite_bridge、irq_concentrator |
| C05-BMC组件.md | S05 | bmc_core、boot/存储、EMRI 块、mFSM、调试、时钟复位 |
| C06-IO组件.md | S06 | 引脚 mux 组、UART/GPIO/SPI/I²C 代理、硬核包装、CDC |
| C07-监控组件.md | S07 | I²C 命令解码器、遥测接口、看门狗阵列、事件日志 |
| C11-NPU-Tiny组件.md | S11 | PE、systolic 阵列、stagger 馈送、权重双缓冲、DMA、服务寄存器 |
| C12-平台组件.md | S12 | HAL（推断模板+薄胶合）、时钟复位策略、约束模板、base 构建 |
| **C13-跨平台推断策略.md** | **横切（全部）** | **ADR-017：禁厂商 IP、行为级推断、Verilator 边界、推断验证套件** |
| C-soft-工具与固件组件.md | S03/S08/S09/S10/S14 | fabric-gen、bitgen、EFP-SPI 引擎、daemon FSM、静态检查器、CI |

## 平台关键已验证事实（2026-07 搜索交叉验证，后续设计以此为基线）

| 事实 | 来源 | 影响 |
|---|---|---|
| GW5 CFU 支持 LUT4/ALU/**memory 模式**；每 CLS 含 2 个带 CE/SR/GSR 的寄存器 | Gowin DS1103E、CFU 文档 | eLUT4 真值表可用分布式 RAM；v1 仍先用 FF 存储（见 C01 §2 决策） |
| GW5 支持 SEU 检测纠错、背景升级、goConfig I²C/JTAG IP | DS1113E §2.10 | S07 擦洗在 Gowin 侧也可行（待深挖）；base image 可经 I²C 后台升级 |
| GW5 有片内振荡器（1.67~105MHz 可编程）、12 PLL、16 全局时钟、mDRP | DS1103E | BMC/Shell 时钟方案（C12） |
| Tang Mega 138K Dock：GW5AST-LV138PG484A、1GB DDR3、128Mbit Flash、USB-JTAG/UART、ADC×2 | Sipeed wiki | C05/C12 板级参数 |
| gw_sh Tcl 批处理（`run all/syn/pnr`）官方文档 SUG1220E | Gowin | C12 base 构建自动化 |
| NEORV32 上游 Zephyr 支持（v1.11.6）；JTAG 调试官方建议引排针+FTDI | NEORV32 UG / Zephyr 文档 | C05 调试与 E4-BMC1 |
| **GowinSynthesis 官方支持 DSP 推断（含预加/累加/链加/寄存器吸收，`syn_dspstyle` 微调）与 memory 推断映射** | SUG550E §4.3/§2 | ADR-017（C13）的 Gowin 侧依据 |
| Yosys `synth_gowin` 经 memory_libmap 推断 lutrams/brams | Yosys 文档 | 开源链路的推断保障（C13） |
| Vivado/Quartus 行为级 DSP/RAM 推断规则（signed/流水/禁 set/禁异步复位） | UG901/UG949、Quartus Handbook | `eth_inf_*` 编码红线来源（C13 §2） |
| **原生 DPR 不可仿真**（"Partial reconfiguration itself cannot be simulated"） | AMD UG909 | **overlay 路线全 Verilator 可验证的对照铁证**（C13 §3） |
| Verilator 为周期级二值仿真：模拟毛刺/时序不可验 | Verilator 文档/社区共识 | 验证表述拆分（功能级 vs 物理级，C13 §3） |
