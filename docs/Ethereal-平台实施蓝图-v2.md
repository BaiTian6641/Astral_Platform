# Ethereal Logic Platform 实施蓝图 v2.0
## （Overlay 优先路线 · 决策定稿版）

> 本文档是 v1.0《调研与路线图》的继承与重构。基于已确认的决策：以细粒度 Overlay（虚拟可重构架构）为第一优先级；目标平台为 Zynq UltraScale+ 与 Gowin GW5AST-138（Tang Mega 138K 级）；软件 MIT / 硬件 CERN-OHL-S v2 / 文档 CC-BY-SA；EBI = AXI4-Lite + 自研 NoC + 简易总线回退；控制面先独立后统一。
>
> 文档组织：第 1 章决策定稿（ADR）→ 第 2 章平台档案 → 第 3 章 Ethereal Fabric 架构详设 → 第 4 章 Shell 与子系统规格 → 第 5 章镜像与工具链 → 第 6 章路线图与逐任务分解（Agent 可执行粒度）→ 第 7 章评估指标与风险 → 第 8 章参考文献。配套机器可读任务清单见 `ethereal-tasks.yaml`。

---

## 1. 决策定稿（ADR 汇总）

| ADR | 决策 | 依据与备注 |
|---|---|---|
| ADR-001 | **Overlay（虚拟可重构架构）为第一优先级路线**，细粒度（LUT 级）起步，面向自定义加密、自定义信号处理等场景 | 跨厂商二进制兼容（JVM 式）；不依赖厂商 PR 流程；Gowin 无用户级 PR 的唯一可行解；重构是写 SRAM 配置（微秒~毫秒级），天然规避比特流逆向法律风险 |
| ADR-002 | **ZUMA 不做直接使用，做"现代化重构"**——产出 Ethereal Fabric 架构 | ZUMA 是 2012 年工作（VPR6 流程、Verilog 生成器老化）；但其核心技术仍是最优公开基线：LUTRAM 存配置、Clos 型输入互联、40 物理 LUT/虚拟 LUT [^19^][^24^]。现代化方向：异构 tile（BRAM/SSRAM/DSP）、帧式部分配置、互联开销优化（Landy/Stitt 方法可再降 ~50% 互联面积 [^25^]）、VPR8+/nextpnr 现代流程 |
| ADR-003 | **目标平台**：(a) Gowin GW5AST-138（Tang Mega 138K 级，overlay 主战场）；(b) Zynq UltraScale+（overlay + 原生 DFX 双路线并存） | GW5AST-138：138,240 LUT4、340× BSRAM（6,120 Kb）、SSRAM 1,080 Kb、298× DSP（27×18）、**片内硬核 RISC-V AE350 @ 800MHz**、1GB DDR3 [^1^][^2^]。Zynq US+：DFX 工具链成熟，ICAP DMA 实测可达 757 MiB/s [^18^] |
| ADR-004 | **Fabric 采用"异构 tile + 初始化可配置 region 组成"**（用户提案正式采纳） | Base image 构建时由 fabric 描述文件定义 region 数量/大小/组成（LUT tile、BSRAM tile、SSRAM tile、DSP tile 的组合）；方法学直接借鉴 FABulous 的 CSV fabric 定义与 supertile 融合机制 [^4^][^7^] |
| ADR-005 | **许可证**：软件 MIT；硬件设计与 RTL 采用 CERN-OHL-S v2；规范/wiki/文档 CC-BY-SA | 用户定稿。注意：MIT 无专利授权条款（Apache-2.0 有），缓解措施：仓库启用 DCO（Developer Certificate of Origin）`Signed-off-by` 机制，贡献者声明其贡献不含已知侵权专利 |
| ADR-006 | **EBI 总线三档 profile**：EBI-Full（AXI4-Lite + 自研 NoC）/ EBI-Lite（仅自研 NoC）/ EBI-Tiny（简易寄存器总线） | 复用你现有的自研轻量 NoC（Mailbox + 外设控制）作为骨干，AXI4-Lite 做生态兼容层；容量受限器件回退 EBI-Tiny。NoC 能力扩展路线见 §4.2 |
| ADR-007 | **IO 重定向两级**：L1 引脚 Mux（分组 Crossbar）+ L2 协议代理（硬核资源包装接入总线 + 软核协议引擎） | 用户确认。GW5 的硬核资源（SerDes、PCIe 3.0、MIPI D-PHY、ADC [^1^]）以"硬核包装代理"形式接入 EBI |
| ADR-008 | **FPGA ↔ MCU/主机链路双通道**：SPI 为数据/配置主通道，I2C 为平台监控通道（PMBus 风格命令集） | 用户定稿。I2C 监控通道同时服务 Astral 侧的健康管理 |
| ADR-009 | **Service Tile 概念正式引入**：固定功能模块（NPU 等）以专用 region 形式编程进 FPGA，与 vFPGA region 共存 | 用户提案采纳。对应 Coyote v2 的"服务"层 [^2-v1^]；Service Tile 通过 EBI 服务接口暴露，镜像类型为 `service`（见 §5.1） |
| ADR-010 | **控制面先独立、标准接口互通、后期统一** | Ethereal 与 Astral 各自定义控制 API（EFP：Ethereal Fabric Protocol / ACP：Astral Control Protocol），Phase 2 起通过 Type-F 容器互通，Phase 4 出统一编排器 |
| ADR-011 | **Fabric 用厂商工具链构建 base image 不构成合规风险** | Overlay 的"逻辑镜像"是自研格式的配置数据（非厂商比特流），由自研 mapper 生成——彻底规避 Gowin/AMD 比特流格式依赖。Base image 构建可用 Gowin EDA 或 Apicula/nextpnr（Aurora V 已获支持，experimental [^30^]） |

---

## 2. 平台档案

### 2.1 Gowin GW5AST-138（Tang Mega 138K）—— 主战场

| 资源 | 数量 | 对 Ethereal 的意义 |
|---|---|---|
| LUT4 / FF | 138,240 | 物理宿主资源；按 40:1 开销、60% 预算，可容纳 ~2,000 eLUT 的虚拟逻辑（v1 目标）；异构 tile 主要靠硬块，不占此预算 |
| BSRAM | 340 块 / 6,120 Kb，支持双口/ECC/字节使能 [^1^] | **MEM-T tile 的载体**：虚拟逻辑中的 RAM/ROM/S-box/FIFO 全部走硬块，是密度故事的关键 |
| SSRAM（Shadow SRAM） | 1,080 Kb [^1^][^2^] | **SSM-T tile 载体**；可用作配置缓存、镜像暂存、上下文保存区 |
| DSP（27×18，支持 12×12/27×36、48-bit 累加、级联、预加、桶形移位）[^1^] | 298 | **DSP-T tile 载体**：信号处理/加密（大数乘法）的虚拟 MAC |
| **硬核 RISC-V AE350 @ 800MHz**（Andes 核） | 1 | **ethereal-runtime 的片上宿主**：无需外挂 MCU 即可跑配置管理守护、镜像缓存（DDR3 1GB）、ethctl 服务端 |
| SerDes 270Mbps~12.5Gbps ×8、PCIe 3.0 硬核、MIPI D-PHY 硬核、X 通道 ADC [^1^] | 若干 | 后期 IO 代理（高速串行服务）与监控（片内 ADC 电压/温度）的硬核资源 |
| GPIO | 最多 312，10 bank [^1^] | L1 引脚 Mux 池 |
| 配置 | MSPI/SSPI/JTAG；全片重载毫秒级（小比特流） | Base image 更新通道；RECFG 多镜像切换可作为 A/B 更新机制 |
| 工具链 | Gowin EDA（教育版支持 138K [^2^]；商业用途需商业 license）；Apicula + nextpnr-himbaechel 已支持 Aurora V（GW5）[^30^] | Base image 双通道构建；逻辑镜像完全不依赖任何一方 |

### 2.2 Zynq UltraScale+ —— 双路线平台

- **原生 DFX 路线**：DFX Controller IP（PG374）提供 AXI-Lite 软件可控的部分重构状态机（Empty→Shutdown→Clearing BS→Loading→SW Startup→Reset RM→Loaded [^11^]），其状态语义可直接映射为 Ethereal 的"槽位生命周期"；ZyPR 在 US+ 上把 ICAPE3 跑到 200MHz、DMA 吞吐 757 MiB/s [^18^]——原生槽位的"逻辑容器"冷启动可做到 10ms 级。
- **Overlay 路线**：与 GW5 完全相同的 Ethereal Fabric RTL 可直接移植（LUT6 宿主，需做宿主映射层适配，见 §3.5）。
- PS（Cortex-A53 + R5）跑 Linux 版 ethereal-daemon；R5 或 PMU 可跑健康监控。

### 2.3 第三种部署 profile：外挂 MCU + 任意 FPGA（Profile-E）

FPGA 内只放裁剪 Shell（EBI-Tiny + OCC + fabric）+ SPI/I2C 从机接口；配置管理、镜像存储、调度全部在外部 MCU（正是 **Astral 的 Type-F 容器宿主场**景）。这让 Ethereal 可以覆盖无硬核 CPU 的小器件（GW5AT-15、GW2A、Artix-7 等）。

---

## 3. Ethereal Fabric v1：架构详设

### 3.1 总体结构

```
                 ┌───────────── EBI 互联（Shell 侧） ─────────────┐
                 │              │                   │            │
            ┌────┴─────┐   ┌────┴─────┐       ┌─────┴────┐  ┌────┴─────┐
            │   OCC    │   │ IO-Tile  │       │ Service  │  │ 监控/ADC  │
            │ 配置控制器 │   │ 阵列(边缘)│       │ Tile 区  │  │  桥       │
            └────┬─────┘   └────┬─────┘       └──────────┘  └──────────┘
                 │ 配置帧总线     │ 虚拟IO引脚
        ┌────────┴──────────────┴───────────────────────────────┐
        │                  Ethereal Fabric                       │
        │  ┌─Region 0─────────┐ ┌─Region 1─────────┐            │
        │  │ CLB-T CLB-T MEM-T│ │ CLB-T CLB-T CLB-T│ ┌Region 2─┐│
        │  │ CLB-T DSP-T MEM-T│ │ CLB-T CLB-T SSM-T│ │ DSP-T×2 ││
        │  │ （容器 A 的领地）  │ │ （容器 B 的领地）  │ │ MEM-T×2 ││
        │  └──────────────────┘ └──────────────────┘ └─────────┘│
        │   region 划分 = fabric 描述文件在 base image 构建时定义  │
        └────────────────────────────────────────────────────────┘
```

**Region 与 Supertile**（ADR-004 落地）：fabric 描述文件（YAML，语法借鉴 FABulous fabric.csv [^7^]）在 base image 构建时定义：tile 阵列布局、region 边界、region 内 tile 组成。用户可按需求选择不同 size 的 region 组合——例如"加密容器"申请 CLB×6 + MEM-T×2 的 region，"滤波器容器"申请 DSP-T×2 + MEM-T×1。Supertile（FABulous 概念 [^4^]）允许把相邻 tile 融合为复合块（如 DSP+MEM 紧耦合对），减少虚拟互联开销。

### 3.2 虚拟逻辑单元（CLB-T）设计

- **eLUT4**：虚拟 LUT4 + 1 FF。选择 LUT4 而非 ZUMA 的 LUT6 的理由：(a) GW5 物理 CFU 原生 LUT4 [^1^]，虚拟 LUT4 可直接用**物理 CFU 的 memory 模式**（16×1 分布式 RAM）实现——配置位即 RAM 内容，与 ZUMA 的 LUTRAM 技巧同源 [^24^]；(b) LUT4 粒度对加密（S-box/布尔函数）与控制逻辑友好；(c) 映射工具链简单。
- **Cluster**：N=8 个 eLUT4 + 两级本地互联（Clos 式 IIB，继承 ZUMA [^24^]）。输入数 I ≈ (N+1)·K/2 + N 反馈 = 9×4/2+8 = 26 路，本地 crossbar 26×(4×8+8)。
- **进位链**：v1 不做（算术用 DSP-T 或 LUT 拼）；v2 评估利用 GW5 CFU 的 ALU 模式实现快速虚拟加法器（这是相对 ZUMA 的现代化增量之一）。

### 3.3 互联架构（开销主战场）

文献共识：**互联占 overlay 面积开销 50% 以上** [^25^]。Ethereal Fabric 的互联设计继承并组合以下已验证技术：

1. **配置存于 LUTRAM**（ZUMA 核心 [^24^]）：路由 mux 的选择位不放 FF，放物理 LUT 的 RAM 模式——GW5 CFU memory 模式直接支持；
2. **两源虚拟轨道退化为导线**（Landy/Stitt [^25^]）：每个虚拟 track 只允许 2 个驱动源时，n:1 mux 退化为两根单向线，直接消除 mux——以此原则设计 switch box 拓扑，预计互联面积降 48~54%、频率升 24% [^25^]；
3. **LUT 输入平台期利用**（Landy/Stitt [^25^]）：物理 LUT4 的 mux 实现存在"平台期"（3~4 输入与 2 输入同价），switch box 设计对齐平台期；
4. **路由通道宽度 W**：ZUMA 取 W=12（VPR 对 MCNC benchmark 实验所得最小可布通值 [^24^]）；Ethereal Fabric v1 从 W=12 起步，用 VPR 扫描 {8,10,12,16} 针对加密/DSP benchmark 集重新定标；
5. **region 边界约束**：虚拟路由不允许穿越 region 边界（容器隔离的物理基础）；region 间通信只能走 EBI 侧通道。

### 3.4 配置架构与 OCC（Overlay Configuration Controller）

**帧式配置**（FABulous 经验 [^4^]）：

- 配置存储按**帧（frame）**组织：一帧 = 一列 tile 的全部配置位；帧内用 latch/分布式 RAM 而非移位寄存器——FABulous 明确警告移位寄存器方案的三大缺陷：配置期间高功耗、未移完前配置无效（瞬态短路/环振）、无法实现真部分重构 [^4^]；
- **blank-before-write**：重写一个 region 前先写入空白配置（全零/安全态），再写新配置——避免 one-hot 路由 mux 多源同时驱动的瞬态短路 [^4^]；
- **OCC**：EBI 挂载的 32 位寄存器接口，命令语义：`REGION_SELECT / FRAME_ADDR / WRITE_FRAME / BLANK_REGION / READBACK_FRAME / LOCK_REGION / UNLOCK_REGION`。LOCK 后该区域配置口写使能关闭——**容器间配置隔离的硬件根**；
- **配置时延预算**：4×4 cluster（128 eLUT）的虚拟比特流约 200 KB 级（ZUMA 同规模实测 206 KB [^19^]）；经 AE350 内存映射 32 位写 @ 100MHz 量级 ≈ 0.5 ms；经 SPI 20MHz 桥 ≈ 80 ms。目标指标：**region 热替换 < 10 ms（片内通道）**；
- **上下文保存/恢复**（v2）：CLB-T 的 FF 状态经扫描链读出到 SSM-T 区，配合 overlay 天然具备的"配置预加载"能力 [^22^]，实现容器抢占/迁移——这是原生 DPR 极难做到、overlay 免费获得的能力。

### 3.5 异构 Tile 规格

| Tile | 物理载体 | 虚拟化语义 | 配置内容 |
|---|---|---|---|
| CLB-T | 8×CFU（LUT4+FF）+ 互联 LUT | 8 eLUT4 + 本地 crossbar | LUT 真值表 + mux 选择位 |
| MEM-T | 1× BSRAM（18Kb，双口/ECC [^1^]） | 可配位宽/深度的 RAM/ROM（1K×18 … 16K×1）、FIFO、双口 | 模式字 + 可选 ROM 初始化内容（随镜像下发） |
| SSM-T | SSRAM 区（1080Kb 池） | 大块暂存/表/上下文保存区 | 地址窗口分配 |
| DSP-T | 1× DSP（27×18 [^1^]） | 可配 MAC：乘/乘加/累加/预加滤波/桶形移位/旁路 | 模式字 + 流水线级数 |
| IO-T | 边缘 8 引脚 + L1 Mux | 8 路虚拟 IO，接 EBI IO 重定向层 | 引脚映射表 |

**这是 Ethereal Fabric 区别于 ZUMA 的本质升级**：ZUMA 只有均质 CLB；异构 tile 让加密（MEM-T 做 S-box/轮密钥表）、信号处理（DSP-T 做 MAC 阵列）的实际可用密度提升一个数量级，同时 LUT 开销大头由硬块承担。

### 3.6 宿主移植层（HAL）

Fabric RTL 中对物理原语（CFU memory 模式、BSRAM、DSP、PLL）的引用全部隔离在 `hal/gowin_gw5/`、`hal/xilinx_us/` 目录；语义等价物用统一 wrapper。Zynq US+ 移植时 CFU memory 模式 → LUTRAM（SLICEM），BSRAM → BRAM36，DSP → DSP48E2。**fabric 架构参数（N、W、I）按宿主重新定标但虚拟架构（eLUT4 接口、帧格式、镜像格式）不变**——这就是二进制兼容承诺。

---

## 4. Shell 与子系统规格

### 4.1 Shell 组成（按部署 profile 裁剪）

| 模块 | Profile-G（GW5AST） | Profile-Z（Zynq US+） | Profile-E（外挂 MCU） |
|---|---|---|---|
| EBI 互联 | Full/Lite | Full | Tiny |
| OCC | ✅ | ✅ | ✅ |
| Fabric + Regions | ✅ | ✅ | ✅（可裁剪） |
| IO 重定向 L1/L2 | ✅ | ✅ | L1 |
| SPI 数据通道 | 可选（对外扩展口） | PS SPI | ✅ 主通道 |
| I2C 监控通道 | ✅ | ✅ | ✅ |
| 原生 DFX 槽位 | ❌ | ✅（DFX Controller [^11^][^12^]） | ❌ |
| Service Tile 框架 | ✅ | ✅ | 可选 |
| SEU 擦洗 | 后期（读回需 Gowin 支持评估） | ✅（SEM + 自研调度） | ❌ |

### 4.2 EBI 规范要点（RFC-002 将完整定义）

- **地址空间约定**：`0x0000_0000` Shell CSR；`0x0001_xxxx` OCC；`0x0010_0000+` region 窗口（每 region 64KB：虚拟 IO 寄存器 + 容器 CSR）；`0x0020_0000+` Service Tile 窗口；`0x0030_0000+` IO 代理外设；
- **自研 NoC 扩展路线**（你现有 Mailbox + 外设控制总线）：v1 保持现状作为 EBI-Lite 骨干 → v2 增加 DMA 描述符通道（镜像加载/大块数据）→ v3 评估虚通道（容器间 QoS）；
- **中断模型**：每 region 2 条虚拟中断线 + Service Tile 各 1 条，汇聚到中断聚合器，经 Mailbox 上报宿主。

### 4.3 IO 重定向详设（ADR-007 落地）

- **L1 引脚 Mux**：引脚池分组（8 引脚/组），组级 Crossbar 到 region 的 IO-T；每引脚电气能力（电平标准、驱动强度、上下拉 [^1^]）记录在 Board Manifest；时序预算标注（经一级 mux 后上限 ~100 MHz 级，实测后写入 manifest）；
- **L2 协议代理**：Shell 内建外设库——软核：UART/SPI/I2C/PWM/QEI/CAN（FD 视资源）；**硬核包装**：GW5 的 SerDes/PCIe/MIPI/ADC、Zynq 的 PS 侧外设，以寄存器 façade 形式接入 EBI（ADR-007 的"硬核资源包装接入总线"）；
- **隔离语义**：region 逻辑**永不直接触碰物理引脚**——要么经 L1 mux（引脚被独占分配给它），要么经 L2 代理（共享外设被仲裁复用）。电气冲突在结构上不可能发生；
- **虚拟设备寄存器规范**：每类协议代理定义标准寄存器布局（TX/RX FIFO、状态、配置、中断），与 Astral 侧虚拟 IO 规范同源——一份规范，两侧驱动。

### 4.4 Service Tile 框架（ADR-009 落地）

- **定义**：随 base image（或原生 DFX 槽位）部署的固定功能模块，占用专用 region，通过 EBI 服务接口（寄存器 + DMA + 中断）向所有容器/宿主提供加速服务；
- **与 vFPGA 的共存规则**：Service Tile region 在 fabric 描述中标记 `type: service`，不参与容器分配；容器经标准服务调用接口使用它；
- **首发候选**：`NPU-Tiny`——INT8 systolic 阵列（8×8 起步，Gemmini 架构启发 [^29^]，BSRAM 喂数据），跑关键词唤醒/TinyML 级负载；后续候选：加密硬加速核（SM4/AES）、软件定义无线电前端；
- **镜像类型**：`service` 类镜像 = Service Tile 的比特流（原生路线）或 fabric 配置（若 Service Tile 本身实现于 overlay 内——套娃但可行，v1 不做）。

### 4.5 监控子系统（ADR-008 落地）

- **I2C 监控通道**：Shell 内 I2C target（支持 clock stretching），实现 PMBus 风格命令集（RFC-003）：`PAGE`(0x00，选 slot)/`STATUS_WORD`(0x79)/`READ_TEMPERATURE`(0x8D，GW5 经 X 通道 ADC [^1^]，Zynq 经 SYSMON)/`READ_VCCINT`(0x8B)/厂商自定义区（0xD0+：slot 状态字、重构计数、错误日志、OCC 状态）；
- **看门狗**：每 region 虚拟看门狗（容器需周期写心跳寄存器，超时 → OCC blank 该区域 + 上报）；
- **健康策略**：`restartPolicy`（always/on-failure/never）存于镜像 manifest，daemon 执行。

---

## 5. 镜像与工具链

### 5.1 镜像体系（RFC-001 v2）

```
镜像类型                    内容                                     部署目标
─────────────────────────────────────────────────────────────────
base image      厂商比特流（Shell + Fabric + Service Tiles）   JTAG/MSPI 烧写（低频）
logic image     fabric 配置帧 + manifest + interface + caps    OCC 加载到 region（高频）
service image   Service Tile 比特流/配置 + 服务描述             base image 构建期或 DFX 槽位
bundle          多 logic image + 布局约束（docker-compose 式）  编排器
```

logic image 的 manifest.yaml 关键字段：`image/name|version|digest|signature(ed25519)`、`targets[]`（fabric 架构版本 + region 需求：tile 类型与数量）、`interface`（EBI 版本、虚拟 IO 需求、中断）、`capabilities`（请求的 IO/服务权限）、`resources`（eLUT/MEM/DSP 上限）、`health`（看门狗周期、restartPolicy）。

### 5.2 逻辑镜像构建工具链（Ethereal Tools）

```
用户 Verilog（RTL 子集）
  → Yosys 综合（定制 techlib：eLUT4 + 虚拟 FF/MEM/DSP 原语）
  → 打包/布局布线：路线 A：VPR 8 + 自定义架构 XML（ZUMA 路线现代化 [^23^][^24^]）
                   路线 B：FABulous 流程改造（nextpnr 通道 [^7^]）
                   （Phase 0 双路 spike，M2 决策）
  → bitgen：VPR/nextpnr 结果 → fabric 配置帧（参考 FPGA-Bitstream 的两级比特流设计：generic 数据库 + fabric-dependent 排序 [^14^]）
  → ethimg pack：+ manifest + 签名 → logic image
```

时序：v1 用预表征 tile 延迟库做 STA 估算（诚实标注精度）；v2 反标实测延迟。

### 5.3 Base image 构建工具链

`fabric.yaml`（tile 阵列 + region 划分 + Service Tile 声明）→ **fabric-gen**（参数化 RTL 生成器，FABulous 方法学 [^7^]）→ 与 Shell RTL 合并 → Gowin EDA 或 Apicula/nextpnr（Aurora V [^30^]）/ Vivado → base bitstream + **fabric 数据库**（帧地址映射表，bitgen 与 OCC 的共同依据）。

---


## 6. 路线图与逐任务分解

节奏假设：单人，每周 8~15 小时。任务粒度：Phase 0/1 拆到 0.5~3 人日级（可直接交给编码 Agent 执行）；Phase 2 为 3~5 人日级；Phase 3+ 为里程碑级。每个任务给出：**目标 / 依赖 / 产出 / 验收标准 / 预估**。任务 ID 规则：`E{阶段}-{工作流}{序号}`；工作流代码：INF=基础设施，FAB=Fabric RTL，GEN=生成器，MAP=映射工具链，SHL=Shell，RUN=运行时，PLT=平台 bring-up，IO=IO 子系统，MON=监控，DMO=演示镜像，DOC=文档。

### 6.0 阶段总览（Overlay 优先重排）

```
Phase 0 (M0-M2)   基础设施 + Fabric v0 仿真验证 + 映射工具链 spike
Phase 1 (M2-M5)   GW5 bring-up："Gowin 上跑逻辑容器"最小闭环  ★第一个对外里程碑
Phase 2 (M5-M9)   Fabric v2 异构 tile + IO 重定向 + Zynq US+ 移植 + Astral 聚合 v1
Phase 3 (M9-M15)  Service Tile (NPU) + 调度/抢占 + 安全 v1 + 镜像仓库 + 论文
Phase 4 (M15-M24) 编排器 + 开发者体验 + 生态
Phase 5 (M24+)    商业级（企业编排/认证/厂商合作）
```

---

### Phase 0：基础设施与仿真验证（M0-M2，约 100~150 人时）

**阶段目标：不写一行厂商工具链相关代码，在 Verilator 中跑通"生成 fabric → 映射电路 → 配置 → 运行 → 热替换"全链路。**

#### 工作流 INF（基础设施）

| ID | 任务 | 目标 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E0-INF1 | GitHub 组织与仓库骨架 | 产出：§6.6 定义的 8 仓库结构，含 README、LICENSE（MIT / CERN-OHL-S v2 / CC-BY-SA 按 ADR-005 分仓）、DCO 启用、CONTRIBUTING、行为准则。验收：`git clone` 后文档链接全部有效 | 1 人日 |
| E0-INF2 | CI 骨架 | 产出：GitHub Actions——Verilator lint + cocotb 回归 + 文档构建（mdBook 或 mkdocs）。验收：一个 dummy RTL 测试在 CI 变绿 | 1 人日 |
| E0-INF3 | 仿真环境 | 产出：Dockerfile（Verilator 5.x + cocotb + Yosys + VPR 8 + Python 3.12）；`make sim` 一键起。验收：干净机器 30 分钟内复现 | 2 人日 |
| E0-INF4 | 商标/名称可用性检查 | 产出：Ethereal/Astral 在 GitHub org、域名、开源商标冲突的检查记录与结论 | 0.5 人日 |

#### 工作流 FAB（Fabric RTL v0）

| ID | 任务 | 目标 / 依赖 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E0-FAB1 | eLUT4 + FF 单元 RTL | 依赖：INF3。产出：`rtl/clb/elut4.sv`——4 输入查找表（配置存 16 位移存/RAM 语义寄存器组）+ 可旁路 FF + 配置写口。验收：cocotb 随机真值表 1000 组比对通过 | 1 人日 |
| E0-FAB2 | CLB-T cluster RTL | 依赖：FAB1。产出：N=8 eLUT4 + 26 输入 Clos 两级本地 crossbar（§3.2），参数化（N、I、K）。验收：cluster 内任意 LUT→LUT 连通性穷举通过 | 3 人日 |
| E0-FAB3 | Switch box + 通道互联 | 依赖：FAB2。产出：W=12 通道、两源轨道优先的 SB（§3.3 技术 2/3），参数化拓扑表驱动生成。验收：4×4 cluster 网格在 Verilator 中例化成功，无组合环 | 4 人日 |
| E0-FAB4 | 配置帧组织与 OCC v0 | 依赖：FAB3。产出：帧地址映射生成脚本 + OCC RTL（REGION_SELECT/FRAME_ADDR/WRITE_FRAME/BLANK_REGION/READBACK，§3.4）。验收：经 OCC 写入配置后 fabric 行为 = 配置数据指定的电路（用加法器/计数器样例） | 4 人日 |
| E0-FAB5 | blank-before-write 与 region 锁 | 依赖：FAB4。产出：BLANK 流程 + LOCK_REGION 写保护。验收：改写运行中的相邻 region 不影响本 region 输出（毛刺监测断言）；LOCK 后写被丢弃且状态位报告 | 2 人日 |
| E0-FAB6 | Fabric 顶层生成器 v0 | 依赖：FAB3。产出：`fabric-gen` Python 脚本——读 fabric.yaml（阵列、region 划分）生成参数化顶层 Verilog + 帧地址映射 JSON。验收：同一份 RTL 源生成 2×2 与 4×4 两种 fabric 均通过 FAB4 验收用例 | 3 人日 |

#### 工作流 MAP（映射工具链 spike）

| ID | 任务 | 目标 / 依赖 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E0-MAP1 | Yosys 定制综合 | 依赖：无。产出：eLUT4 techlib + `synth_ethereal` 脚本：Verilog→eLUT4/DFF 网表（JSON/BLIF）。验收：ISCAS85 小样例（c17、c432）映射后 LUT 数合理 | 2 人日 |
| E0-MAP2 | VPR 架构文件 | 依赖：FAB2/3 参数。产出：Ethereal Fabric 的 VPR arch XML（eLUT4 cluster、W=12、heterogeneous 块预留）。验收：VPR 对 c432 完成 pack/place/route 且时序报告可读 | 4 人日 |
| E0-MAP3 | bitgen v0 | 依赖：MAP2、FAB4 帧映射 JSON。产出：VPR 结果（.net/.place/.route）→ 配置帧比特流。验收：端到端——c432 经完整流程载入仿真 fabric，输出与 Verilog 参考模型 bit-true | 5 人日 |
| E0-MAP4 | FABulous 流程评估 spike | 依赖：无。产出：跑通 FABulous 示例 fabric 生成与其仿真流，记录可复用点（帧组织、supertile、bitstream 生成 [^4^][^7^]）与许可兼容性（Apache-2.0 → 可借鉴不可直接并入 CERN-OHL-S 仓，需评估）。验收：评估笔记 + MAP 路线 A/B 决策记录（ADR-012） | 3 人日 |
| E0-MAP5 | 基准电路集 | 产出：benchmark 目录——AES-128 核（S-box 用 LUT 实现）、PRESENT、FIR16、CRC32、PWM 发生器、RISC-V 迷你核（可选），全部提供 Verilog 源 + 黄金测试向量。验收：全部经 MAP1-3 流程在仿真 fabric 运行正确 | 4 人日 |

#### 工作流 SHL（Shell v0，仿真内）

| ID | 任务 | 目标 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E0-SHL1 | EBI-Tiny 总线 RTL | 产出：32 位寄存器读写总线（valid/ready）+ §4.2 地址映射 decoder。验收：总线功能模型 BFM 随机读写一致性 | 1 人日 |
| E0-SHL2 | Shell v0 集成 | 依赖：FAB4、SHL1。产出：EBI-Tiny + OCC + fabric 的仿真顶层 + cocotb 宿主驱动（模拟"daemon 写配置"）。验收：**仿真内完成一次完整"容器部署"**：宿主经总线写配置 → 启动 → 读结果 → blank → 换第二个镜像 → 再运行 | 3 人日 |
| E0-SHL3 | 性能建模 | 产出：配置帧数/字节数统计 + 配置时延模型（§3.4 预算表）；fabric 关键路径报告（Verilator --timing 或 STA 估算）。验收：给出 4×4 fabric 的配置字节数与虚拟 Fmax 初值 | 2 人日 |

**Phase 0 退出标准**：仿真内双镜像热替换演示通过；AES-128 与 FIR16 两个基准在虚拟 fabric 上 bit-true；MAP 路线决策（ADR-012）完成；全部 CI 绿。**熔断**：若 VPR 架构文件两周内无法收敛 → 降级路线 B（FABulous/nextpnr）或自研贪心 placer + PathFinder router（各 5 人日上限，超时即砍功能保 W=8 固定拓扑）。

---

### Phase 1：GW5 bring-up —— "Gowin 上跑逻辑容器"（M2-M5，约 150~220 人时）

**阶段目标：在 Tang Mega 138K 上完成最小闭环：AE350 硬核（或外挂 MCU）经 ethctl 把 logic image 部署进 region 并运行，可热替换；SPI+I2C 双通道对外。**

#### 工作流 PLT-G（GW5 平台）

| ID | 任务 | 目标 / 依赖 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E1-PLT1 | GW5 宿主映射层 | 依赖：E0-FAB 全部。产出：`hal/gowin_gw5/`——CFU memory 模式（LUTRAM 语义）、BSRAM、DSP 原语 wrapper；用 Gowin EDA 综合验证 LUTRAM 推断正确（检查综合报告原语）。验收：4×4 fabric 综合后物理 LUT 占用 ≤ 45×128（开销比 ≤ 45:1，首版容忍）；报告实际值 | 4 人日 |
| E1-PLT2 | Base image 构建流 | 依赖：PLT1。产出：Gowin EDA 工程模板 + 脚本化构建（gw_sh 批处理）；输出 base bitstream + 帧映射 JSON。验收：Tang Mega 138K 烧写后 Shell CSR 可经 SPI 读出 magic number | 3 人日 |
| E1-PLT3 | AE350 硬核启动 | 依赖：无。产出：AE350 裸机工程（启动代码、DDR3 初始化、UART 控制台）；确认 AE350 与 PL 的总线接口（Gowin 文档）并把 EBI 桥接进去。验收：AE350 程序读写 Shell CSR 成功。**风险备选**：若 AE350↔PL 接口文档/流程受阻（>1 周），降级 Profile-E：外挂 MCU 经 SPI 管理 | 4 人日 |
| E1-PLT4 | Apicula/nextpnr 备选链 | 依赖：PLT1。产出：用 nextpnr-himbaechel（Aurora V [^30^]）构建同一 base image 的实验记录；评估其作为 CI 构建通道的可行性（Gowin EDA 无 Linux CLI 授权问题时的替代）。验收：实验笔记 + 可行性结论 | 3 人日 |

#### 工作流 IO（通道与外设 v1）

| ID | 任务 | 目标 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E1-IO1 | SPI 数据通道 | 产出：SPI slave（模式 0，≤ 25 MHz）+ 帧协议（EFP-SPI：addr/len/data/CRC16）+ EBI 桥。验收：外挂 MCU 经 SPI 完成一次完整 logic image 部署；CRC 错误注入测试通过 | 3 人日 |
| E1-IO2 | I2C 监控通道 v1 | 产出：I2C target（支持 clock stretching）+ PMBus 风格命令子集（§4.5：PAGE/STATUS_WORD/READ_VCCINT/slot 状态/OCC 状态）。验收：Raspberry Pi 经 `i2cget` 读出 slot 状态；热插拔轮询 24h 无锁死 | 3 人日 |
| E1-IO3 | L1 引脚 Mux v1 | 产出：8 引脚组 × 4 组的组级 mux + Board Manifest（tang-mega-138k.yaml：引脚能力表）。验收：PWM 镜像经 mux 输出到任意两个不同组引脚，示波器验证 | 3 人日 |
| E1-IO4 | L2 协议代理 v1 | 产出：UART 代理（标准寄存器布局 §4.3）+ GPIO 代理（方向/读写/中断）。验收：region 内虚拟逻辑经 UART 代理收发 115200 无丢字节 | 3 人日 |

#### 工作流 RUN（运行时 v1）

| ID | 任务 | 目标 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E1-RUN1 | 镜像格式 v1 实现 | 依赖：E0-MAP3。产出：`ethimg` Python 包——pack/unpack/verify（manifest schema 校验 + SHA-256 + Ed25519 签名）。验收：篡改任意字节即验签失败 | 2 人日 |
| E1-RUN2 | ethereal-daemon（AE350 裸机版） | 依赖：PLT3、IO1。产出：镜像接收（SPI/UART/XMODEM 或 DDR3 预载）→ 验签 → region 分配表 → OCC 加载 → 生命周期状态机（映射 §2.2 DFX 状态语义）。验收：`ethctl run/stop/ps/restart` 全通；异常路径（坏签名/满 region/写冲突）全部优雅报错 | 5 人日 |
| E1-RUN3 | ethctl CLI（PC 端） | 依赖：RUN2。产出：Python CLI，经 UART/USB 或 SPI 桥与 daemon 会话；命令集刻意对齐 Docker（run/ps/stop/rm/images/logs/inspect）。验收：`ethctl run aes128.eth --region 0` 30 秒内完成部署并打印运行状态 | 3 人日 |
| E1-RUN4 | 看门狗 v1 | 依赖：RUN2。产出：region 心跳寄存器 + 超时 blank + 事件日志。验收：故意死锁的镜像在超时后被自动 blank 且相邻 region 无损 | 2 人日 |

#### 工作流 DMO（演示镜像与里程碑）

| ID | 任务 | 目标 / 产出 / 验收 | 预估 |
|---|---|---|---|
| E1-DMO1 | 三个演示镜像 | 依赖：E0-MAP5 移植。产出：(a) PWM/LED 控制（用 L1 mux 出脚）；(b) UART 回显桥（用 L2 代理）；(c) AES-128 ECB 加密服务（LUT S-box 版）。验收：三镜像在 2 个 region 上轮换运行，热替换 < 100 ms（SPI 通道）/ < 10 ms（AE350 通道目标） | 4 人日 |
| E1-DMO2 | 热替换稳定性 | 产出：自动化脚本——两 region 各 10,000 次随机镜像轮换 + 相邻干扰监测。验收：零配置损坏、零跨区干扰 | 2 人日 |
| E1-DMO3 | 里程碑发布 | 产出：v0.1.0 tag + 演示视频 + 博客《在 Gowin 上运行 FPGA 逻辑容器》+ 文档站上线。验收：仓库公开 | 2 人日 |

**Phase 1 退出标准**：上表全部验收通过；fabric 实测开销比与虚拟 Fmax 公开（诚实报告，哪怕 45:1 / 30 MHz）；**熔断**：若 AE350 通道卡死，Profile-E（外挂 MCU）保底，里程碑目标不变。

---

### Phase 2：异构 Fabric v2 + IO 完整版 + Zynq 移植 + Astral 聚合（M5-M9，约 250~350 人时）

| ID | 任务 | 要点 / 验收 | 预估 |
|---|---|---|---|
| E2-FAB1 | MEM-T tile（BSRAM 包装） | 位宽/深度/双口/FIFO/ROM 预载（§3.5）；AES S-box 用 MEM-T 重实现，对比 LUT 版密度提升（预期 5× 以上） | 5 人日 |
| E2-FAB2 | DSP-T tile | 27×18 模式封装（乘/MAC/预加/流水 [^1^]）；FIR16 用 DSP-T 链实现，实测虚拟 Fmax 与吞吐 | 5 人日 |
| E2-FAB3 | SSM-T tile + 上下文保存 v1 | SSRAM 地址窗口分配；CLB FF 状态扫描读出/恢复——容器暂停/恢复演示 | 5 人日 |
| E2-FAB4 | fabric.yaml v2（异构 region 组合） | region 描述支持 tile 混合组成与 supertile（ADR-004 完整落地）；生成器+帧映射+bitgen 全链更新 | 5 人日 |
| E2-FAB5 | 互联优化 v2 | 落地 §3.3 技术 2/3（两源轨道、平台期对齐），目标：同规模 fabric 物理 LUT 降 ≥ 20% | 5 人日 |
| E2-MAP1 | 异构映射 | Yosys 记忆体/DSP 推断 → 虚拟原语；VPR arch 异构块；bitgen 异构帧 | 8 人日 |
| E2-IO1 | L2 代理库扩展 | SPI master / I2C master / PWM 多路 / QEI；统一虚拟设备寄存器规范 RFC-004 冻结 | 6 人日 |
| E2-IO2 | L1 mux v2 + 时序表征 | 引脚池扩到 8 组；实测各路 max 频率写回 Board Manifest | 3 人日 |
| E2-PLT1 | Zynq US+ 移植 | hal/xilinx_us（LUTRAM/BRAM36/DSP48E2）；PS Linux daemon（mmap UIO + 同一代码库）；fabric 在 US+ 上跑通 Phase 1 全部演示 | 8 人日 |
| E2-PLT2 | 原生 DFX 槽位并存 | DFX Controller（PG374 [^11^]）接入 daemon 同一生命周期状态机；一个 region 跑 overlay 容器、一个原生 DFX slot 跑高性能加速——**混合虚拟化演示** | 6 人日 |
| E2-SEC1 | 安全 v1 | 验签强制化；OCC region 锁矩阵；镜像能力清单与 IO 分配校验 | 4 人日 |
| E2-AST1 | Astral 聚合 v1 | Zephyr + WAMR 最小运行时（外挂 MCU 或 Zynq R5）；Type-F 容器：WASM 应用经 EFP 协议部署/调用 vFPGA 逻辑；**"固件容器 + 逻辑容器同屏"演示** | 8 人日 |
| E2-DOC1 | 规范冻结 | EBI v1.0、镜像格式 v1.0、Board Manifest v1.0、EFP 协议 v1.0 全部语义化版本发布 | 3 人日 |

**Phase 2 退出标准**：同一 logic image 在 GW5 与 Zynq US+ 上不经修改运行（二进制兼容承诺首次兑现）；异构 tile 基准（AES-MEM、FIR-DSP）密度/性能报告；Astral 聚合演示视频；至少 1 名外部贡献者。

---

### Phase 3：Service Tile、调度、安全与学术发布（M9-M15，里程碑级）

- **E3-SVC1 NPU-Tiny Service Tile**：INT8 8×8 systolic（Gemmini 启发 [^29^]），BSRAM 喂数，EBI 服务接口；跑通一个 TinyML 推理 demo（如关键词唤醒）；容器经服务调用接口共享使用。验收：推理吞吐/能效报告；多容器分时复用无状态泄漏
- **E3-SVC2 Service Tile 注册与发现**：manifest `type: service` + 服务描述符（功能 ID、版本、寄存器 ABI）；daemon 服务目录查询 API
- **E3-SCH1 配置调度器**：任务队列按镜像分组 + 预取 + DDR3 镜像缓存（借鉴 Coyote 分组调度 [^3-v1^] 与 ZyPR 缓存 [^18-v1^]）；冷启动 P50 < 100 ms
- **E3-SCH2 抢占与迁移**：基于 E2-FAB3 上下文保存，实现容器在 region 间迁移与抢占恢复；碎片整理策略 v1（小 region 合并）
- **E3-SEC2 安全 v2**：镜像静态检查钩子（对虚拟配置做结构扫描：环振/短路径检测——overlay 上做"比特流杀毒"比原生比特流容易得多，这是 overlay 路线的安全红利）； region 间时序/功耗异常监控
- **E3-REP1 镜像仓库 v1**：OCI artifact 兼容仓库 + `ethctl push/pull`
- **E3-PUB1 论文**：题目建议《Ethereal Fabric: Containerized Virtual FPGAs for Commodity Low-Cost Devices》，投 FPL / FCCM / ACM TRETS；素材：异构 tile、region 组合、容器生命周期、实测数据
- **E3-MON1 监控 v2**：I2C 命令集扩展（重构计数、错误日志环形缓冲、温度历史）；Zynq 侧 SEM 擦洗集成（US+）

### Phase 4：编排与生态（M15-M24，里程碑级）

- 统一编排器（bundle 部署、多板管理、声明式 YAML）；ethereal + Astral 统一控制面（ADR-010 终态）
- 开发者体验：VS Code 扩展、TUI 仪表盘（region 占用/IO 映射/健康）、波形调试钩子
- Astral 完整运行时：Type-N/Type-W/Type-F 齐备；代理 IO 完整规范
- 参考设计套件 ×4：电机控制、SDR 前端、工业协议网关、NPU 协处理——每个都是聚合范例
- 社区治理：RFC 流程、双周会、第三方板卡适配指南（GW2A、Artix-7、ECP5 作为社区目标）

### Phase 5：商业级（M24+，方向性）

企业版集群编排与 RBAC；IEC 61508 / ISO 26262 预评估材料（监控+擦洗+看门狗是卖点）；镜像仓库 SaaS；厂商合作（Gowin 官方适配洽谈——你的平台是其生态补充）；LTS 与支持服务。判断点：社区规模不足则继续深耕开源。

---

### 6.6 仓库结构（ADR 相关，供 E0-INF1 执行）

```
github.com/ethereal-fpga/  （组织名待定，E0-INF4 检查后定）
├── ethereal-fabric     RTL：fabric、OCC、tile 库、HAL        CERN-OHL-S v2
├── ethereal-shell      RTL：EBI、IO 重定向、Service Tile 框架  CERN-OHL-S v2
├── ethereal-tools      fabric-gen、mapper、ethimg、ethctl      MIT
├── ethereal-runtime    daemon（AE350/Linux/MCU 三 profile）    MIT
├── ethereal-spec       EBI、镜像格式、Board Manifest、EFP/ACP  CC-BY-SA
├── ethereal-images     官方 logic/service 镜像与基准电路        MIT（镜像）/ CERN-OHL-S（RTL 源）
├── astral-os           Astral 运行时与容器规范                 MIT
└── docs                文档站与 wiki                            CC-BY-SA
```

---

## 7. 评估指标体系与风险登记册（v2 更新）

### 7.1 核心指标（每阶段实测并公开）

| 指标 | Phase 1 目标 | Phase 2 目标 | 测量方法 |
|---|---|---|---|
| Fabric 开销比（物理 LUT / eLUT） | ≤ 45:1（诚实报告实际值） | ≤ 35:1（互联优化后） | 综合报告 |
| 虚拟 Fmax（控制类基准） | ≥ 25 MHz | ≥ 40 MHz | 实测 + STA 估算 |
| Region 热替换时延 | < 100 ms（SPI）/ < 10 ms（AE350 内存映射） | 同左 + 预取后 < 20 ms（SPI） | 示波器 GPIO 打点 |
| 异构密度收益 | — | AES：MEM-T 版 vs LUT 版 eLUT 占用降 ≥ 5×；FIR：DSP-T 版吞吐 ≥ 10× | 基准报告 |
| 二进制兼容 | — | 同一 image 文件在 GW5 与 US+ 直接运行 | CI 双平台回归 |
| 稳定性 | 2 region × 10k 次热替换零故障 | 同左 + 相邻干扰注入测试 | 自动化脚本 |

### 7.2 风险登记册（v2 更新，替代 v1 表）

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | Fabric 开销/性能不达标（>60:1 或 < 15 MHz），实用价值受质疑 | 中 | 高 | 异构 tile 是主对冲（密度靠硬块）；诚实标注适用域（控制/桥接/协处理而非大计算）；Landy/Stitt 互联优化 [^25^] 与 Koch 的直连开关矩阵思路 [^26^] 作为 v3 储备 |
| R2 | AE350↔PL 接口文档不充分，卡死 Profile-G | 中 | 中 | Profile-E（外挂 MCU）保底；Sipeed/Gowin 社区求助；先 SPI 后内存映射分步推进 |
| R3 | VPR 架构文件与 bitgen 工作量爆炸 | 中 | 高 | Phase 0 熔断机制（见 §6.0 退出标准）；FABulous 流程备选 [^7^]；bitgen 两级设计（generic 数据库先行 [^14^]）降低耦合 |
| R4 | Gowin EDA 商业 license 成本/限制 | 低 | 中 | Apicula/nextpnr Aurora V 通道 [^30^] 做 CI 构建；与 Gowin 官方建立联系争取支持 |
| R5 | MIT 许可证专利敞口 | 低 | 中 | DCO `Signed-off-by`；核心专利敏感模块（OCC、fabric 架构）保留你个人主导的提交记录 |
| R6 | 单人精力耗尽 | 中 | 高 | 每 Phase 产出独立可用工件；Phase 1 里程碑后积极招募（Hackaday、Reddit r/FPGA、Gowin 社区、FPGA 相关会议 demo Track） |
| R7 | ZUMA/FABulous 等上游学术项目许可证冲突 | 低 | 中 | ZUMA 论文方法不受版权保护（重新实现）；FABulous 为 Apache-2.0，借鉴架构思想 + 自研 RTL 无冲突；不直接并入其代码 |
| R8 | "容器"语义被质疑名不副实（无真正的多租户安全） | 中 | 低 | 文档明确定义：v1 面向单业主可信环境的"部署与隔离便利"，多租户防攻击是 v3+ 目标；overlay 的结构扫描能力作为安全故事储备 |

---

## 8. 参考文献（v2 新增）

[^1^]: Gowin GW5AT series FPGA Products Data Sheet, DS981E — https://cdn.gowinsemi.com.cn/DS981E.pdf
[^2^]: Sipeed Tang Mega 138K Dock Wiki（GW5AST-LV138：138K LUT4、SSRAM/BSRAM、DSP、AE350 硬核 RISC-V、1GB DDR3） — https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k.html
[^4^]: Koch et al., "Customized eFPGAs with FABulous"（异构 tile、supertile、帧式部分重构、移位寄存器缺陷分析、blank-before-write）, CERN 2025 — https://indico.cern.ch/event/1467417/contributions/6393971/attachments/3073076/5437116/CERN_2025_FABulous.pdf
[^7^]: FABulous 官方文档（CSV fabric 定义、帧式部分重构、Apache-2.0、12+ 次流片） — https://fabulous.readthedocs.io/
[^10^]: OpenFPGA Documentation（FPGA-Verilog/SDC/Bitstream/SPICE） — https://media.readthedocs.org/pdf/openfpga/latest/openfpga.pdf
[^11^]: "Dynamic Function eXchange with ICAP Driven by Software"（DFX Controller IP 寄存器/状态机/错误码实战） — https://blog.abbey1.org.uk/index.php/technology/dynamic-function-exchange-with-icap-driven-by-software
[^12^]: AMD UG909, "Dynamic Function eXchange through ICAP for Zynq Devices" — https://docs.amd.com/r/en-US/ug909-vivado-partial-reconfiguration/Dynamic-Function-eXchange-through-ICAP-for-Zynq-Devices
[^13^]: Tang et al., "OpenFPGA: Towards Automated Prototyping for Versatile FPGAs" — https://woset-workshop.github.io/PDFs/2020/a19.pdf
[^14^]: OpenFPGA Fabric-dependent Bitstream 文档（两级比特流：generic 数据库 + fabric-dependent 排序） — https://openfpga.readthedocs.io/en/master/manual/fpga_bitstream/fabric_dependent_bitstream/
[^18^]: "ZyPR: End-to-end Build Tool and Runtime Manager for Partial Reconfiguration of FPGA SoCs at the Edge"（Zynq US+ ICAPE3 @200MHz、757 MiB/s DMA）, ACM TRETS 2023 — https://dl.acm.org/doi/full/10.1145/3585521
[^19^]: Wiersema et al., "Embedding FPGA Overlays into Configurable Systems-on-Chip"（ZUMA 开销实测、各尺寸 overlay 比特流大小与重构时间、ReconOS 集成） — https://groups.uni-paderborn.de/agce/publications/pdfs/WiersemaBP2014.pdf
[^21^]: Myint et al., "A SLM-based Overlay Architecture for Fine-grained Virtual FPGA", IEICE ELEX 2019 — https://www.jstage.jst.go.jp/article/elex/advpub/0/advpub_16.20190610/_pdf
[^22^]: Bollengier et al., "Overlay Architectures For FPGA Resource Virtualization"（overlay 可附加宿主不具备的能力：上下文保存/配置预加载；DSP 硬块粗粒度 overlay 达 300MHz） — https://hal.science/hal-01405912v1/document
[^23^]: Brant & Lemieux, "ZUMA: An Open FPGA Overlay Architecture"（40:1 开销、LUTRAM 技巧、Clos IIB、N=8/W=12 定标）, FCCM 2012 — https://www.cs.wustl.edu/~roger/565M.f12/4699a093.pdf
[^24^]: 同上，UBC 官方版 — https://people.ece.ubc.ca/lemieux/publications/brant-fccm2012.pdf
[^25^]: Landy & Stitt, "A Low-Overhead Interconnect Architecture for Virtual Reconfigurable Architectures"（互联占开销 50%+；两源轨道退化导线；LUT 平台期；面积降 48~54%、频率升 24%）, CASES 2012 — https://space.pitt.edu/sites/default/files/2024-10/Landy_CASES12.pdf
[^26^]: Koch et al., "An Efficient FPGA Overlay for Portable Custom Instruction Set Extensions"（overlay 开关矩阵直连物理开关矩阵的思路与代价）, FPL 2013 — https://www.ece.ubc.ca/~lemieux/publications/koch-fpl2013.pdf
[^29^]: Gemmini: Berkeley's Spatial Array Generator（systolic 阵列生成器，Service Tile 参考）, GitHub — https://github.com/ucb-bar/gemmini
[^30^]: nextpnr README（支持列表含 Gowin LittleBee 与 Aurora V/GW5 via Project Apicula）, GitHub — https://github.com/YosysHQ/nextpnr

（v1 文档的参考文献 [^2-v1^][^3-v1^][^18-v1^] 分别指 Coyote v2、Coyote OSDI'20、ZyPR，见《Ethereal-Logic与Astral-OS容器化平台调研与路线图.md》第 8 章。）

---

*v2.0 · 2026-07 · 与 v1.0 调研文档及 ethereal-tasks.yaml 配套使用*
