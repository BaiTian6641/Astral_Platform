# Ethereal Logic Platform 与 Astral Universal OS Platform
# 调研、可行性分析与路线图（v1.0）

> 面向低内存设备、嵌入式设备与 FPGA 平台的"聚合化"容器技术
> 定位：个人起步、开源社区演进；首个验证路径以开源 EDA 工具链（Verilator/Yosys/nextpnr）仿真建模起步，随后迁移至 AMD / Gowin / Intel 平台

---

## 目录

1. 愿景与概念映射
2. 相关工作全景调研
3. Ethereal Logic Platform：可行性分析与待解决问题
4. Astral Universal OS Platform：可行性分析与待解决问题
5. 路线图与 TODOs（原型 → 商业级）
6. 开源策略与许可证建议
7. 关键开放问题（需要与你进一步对齐）
8. 参考文献

---

## 1. 愿景与概念映射

你的构思本质上是把 Docker 的"镜像（Image）— 容器（Container）— 编排（Orchestration）"三层心智模型，分别映射到两个此前很少有人系统打通的领域：

| Docker 概念 | Ethereal Logic Platform（FPGA 侧） | Astral Universal OS Platform（固件/应用侧） |
|---|---|---|
| 镜像（Image） | 预编译的部分比特流包（Partial Bitstream + 元数据清单） | 固件包（WASM 模块 / 原生二进制 + 元数据清单） |
| 容器（Container） | 虚拟 FPGA 单元（vFPGA / PR Slot 中运行的逻辑实例） | 沙箱化应用进程（WASM 实例 / MPU 隔离的用户态任务） |
| Registry | Bitstream 镜像仓库（版本化、签名、按器件/槽位索引） | 固件镜像仓库（版本化、签名、按 MCU/RTOS 索引） |
| 编排（Orchestration） | Slot 分配、重构调度、IO 重定向、健康监控 | 应用调度、资源配额、代理 IO 策略、崩溃恢复 |
| Docker Engine | Shell（静态层）+ 配置管理器（ICAP 控制器）+ 运行时守护 | RTOS 内核扩展 + 容器运行时 + 内存安全子系统 |
| Namespace / Cgroup | Slot 资源配额（LUT/BRAM/DSP 上限）、地址空间隔离 | MPU 内存域、内核对象权限、栈保护 |
| UnionFS / 分层镜像 | "静态 Shell 镜像" + "逻辑镜像层"的组合 | 基础固件层 + 应用层 |

这个映射在学术与工业界已经分别存在大量先例（见第 2 章），但**把它们统一成一个面向嵌入式/低资源场景的开源聚合平台，目前尚属空白**——这正是你的机会窗口。

与现有工作的差异化定位（初步判断，后文展开论证）：

- **Coyote / Coyote v2**（ETH Zurich & Microsoft，目前最接近"FPGA 操作系统"的开源项目）面向**数据中心 PCIe FPGA**（Alveo 级别），依赖主机 CPU 上的 Linux 驱动与运行时，不适合低内存嵌入式场景 [^3^][^10^]。
- **AmorphOS / OPTIMUS**（OSDI'18 / ATC'20）同样面向云场景，且均未开源 [^3^][^4^]。
- **TaPaSCo**（开源、支持多板卡）聚焦自动化硬件组合与可移植性，但**不支持运行时重构**，无网络服务与共享虚拟内存 [^2^]。
- **Zephyr userspace / Tock OS** 在嵌入式侧提供了 MPU 隔离模型，但它们不是"容器平台"——没有镜像格式、仓库、编排概念 [^32^][^35^]。
- **TinyContainer / AkiraOS / Atym / MicroEJ** 证明了 MCU 级容器化（基于 WASM）正在成为一个新兴方向，但均不涉及 FPGA 逻辑层 [^42^][^43^]。

**结论：把 FPGA 逻辑容器与固件容器放入同一个编排平面、同一套镜像规范、同一条 IO 虚拟化通道，是没有人做过的组合创新。**

---

## 2. 相关工作全景调研

### 2.1 FPGA 虚拟化与"FPGA 操作系统"学术脉络

#### 2.1.1 AmorphOS（OSDI 2018，Microsoft Research）

最接近你"FPGA 逻辑容器"设想的早期工作。核心概念直接对应容器术语 [^7^]：

- **Zone**：芯片分区（全局区 + 子区），类比容器宿主机的资源分区；
- **Morphlet**：用户比特流实例，"像容器一样可伸缩"，可在运行时改变资源需求（morph）；
- **Hull**：保护机制，隔离不受信的应用逻辑；
- **Registry**：部署混合应用的注册机制；
- 两种调度模式：**低延迟模式**（固定 Zone + 部分重构 PR，快速切换）与**高吞吐模式**（多个 Morphlet 联合综合成单一比特流，面积利用最大化） [^3^][^7^]。

局限：内存保护仅限 FPGA 本地 DRAM（段式地址转换），无主机内存集成，无网络栈支持；**未开源** [^3^]。

#### 2.1.2 OPTIMUS（USENIX ATC 2020）

面向共享内存 FPGA 平台（Intel HARP 类）的 hypervisor：将物理 FPGA 划分为多个应用"容器"，提供每应用虚拟地址空间、加速器抢占（preemption）与时分复用。最多支持 8 个物理加速器实例和任意数量虚拟加速器 [^4^]。局限：依赖 UPI/PCIe 共享内存平台，不适用于独立嵌入式 FPGA；**未开源**。

#### 2.1.3 Coyote（OSDI 2020）与 Coyote v2（2025，开源）—— 最重要的对标

Coyote 系统性提出了"FPGA 上的 OS 抽象"：虚拟 FPGA（vFPGA）作为执行单元、共享虚拟内存（CPU 进程与用户逻辑统一地址空间）、虚拟化网络栈、基于任务队列的空间+时间调度（按比特流镜像分组任务以减少重构次数）、主机侧 Linux 内核驱动 + 运行时管理器 [^3^]。

Coyote v2 进一步提升抽象层次，引入 **Thread**（应用线程绑定 vFPGA 执行）与服务（RoCE v2 网络、内存服务）可重构能力；静态层（Static Layer）只负责主机交互，通过 ICAP + XDMA 由主机驱动 ioctl 加载部分比特流；提供 POSIX 风格 C API，**完全开源** [^2^][^10^]。

**对你的启示与差距分析：**

- Coyote 证明了"vFPGA + 统一互联 + 服务虚拟化"架构可行，且开源社区（ETH systems-group）愿意维护此类项目；
- 但其资源开销（静态层 + PCIe XDMA + Linux 主机栈）面向 Alveo U55C/U280 级数据中心卡 [^17^]，**没有覆盖嵌入式 SoC FPGA（Zynq 级）、更没有覆盖无硬核 CPU 的低端器件（Gowin/Lattice）**；
- Coyote 的 IO 虚拟化聚焦网络/内存服务，**不提供 GPIO 级的引脚重定向**——这是嵌入式场景的核心需求；
- Coyote 假设用户逻辑用 Vitis HLS/P4 编写并依赖 Vivado 流程，**没有跨厂商镜像格式**。

**Ethereal Logic Platform 的差异化空间：面向嵌入式与低端器件的轻量化 vFPGA 运行时 + GPIO 级 IO 重定向 + 跨厂商镜像规范 + 与固件容器（Astral）的统一编排。**

#### 2.1.4 其他相关工作速览

| 项目 | 要点 | 与 Ethereal 的关系 |
|---|---|---|
| ViTAL / HETERO-ViTAL | 将 FPGA 集群抽象为单一虚拟 FPGA，编译器把应用切分为小块动态分布到集群 [^2^][^9^] | 集群编排的参考，后期 Phase 5 可借鉴 |
| FOS（FPGA OS） | 标准化应用接口 + 软件运行时部署多个可重构应用，但无网络/内存虚拟化 [^2^] | 接口标准化的参考 |
| Nimblock | 用 overlay 架构把 fabric 划分为多个槽位，任务级动态/抢占式调度 [^2^] | Overlay 路线参考 |
| vFPIO | 扩展 Coyote 实现 **FPGA IO 端口虚拟化 + 抢占式调度**，使用户逻辑平台无关 [^2^] | IO 重定向子系统的直接对标 |
| FSRF | 虚拟化 FPGA IO，文件直接映射到 FPGA 虚拟内存，按应用优化 MMU [^2^] | 内存虚拟化参考 |
| TaPaSCo | 开源自动化工具流，支持多种嵌入式与数据中心 FPGA 的硬件组合与运行时使用，但无运行时重构 [^2^] | 多板卡移植性参考 |
| Intel OFS（Open FPGA Stack） | FIM（Shell，静态区）+ AFU（可含 PR 区）架构，标准 AXI4 接口，PIM 提供协议转换 shim，支持 PR 与虚拟化 [^14^] | Intel 平台的工业级 Shell 范本 |
| SmartNIC Shells（Corundum、OpenNIC、RecoNIC、FpgaNIC、ClickNP） | 开源 100G 网卡 Shell 生态；对比数据显示 PR 的工程现实：全量构建 2~4 小时，部分比特流 6~12 MB，卡上 PR 时延 200~350 ms [^17^] | 重构时延/构建成本的现实基准 |
| ZyPR | 面向边缘 FPGA SoC（Zynq）的端到端 PR 构建工具 + 运行时管理器，JSON 描述配置与模式、C++ API、DMA/AXI 数据流管理 [^12^] | **边缘侧最贴近的参考实现** |
| 面向多租户的 Intra-FPGA 虚拟化框架（TRETS 2024） | 静态区 = 硬件 Shell + 中间硬件层（NoC 互联 vFPGA、Memory Node、Gatekeeper、TMMU 虚拟化外部存储、HBICAP 重构），实现租户间隔离与接口共享 [^15^] | 片上 NoC + TMMU 隔离设计的直接参考 |

### 2.2 Overlay（中间架构/软虚拟化）路线 —— 跨厂商与低端器件的关键

FPGA overlay 又称"中间架构（intermediate fabric）"：在物理 FPGA 之上实现一个虚拟可重构架构，充当用户应用与物理器件之间的中间层 [^1^]。

- **核心价值**：物理 FPGA 架构随厂商/系列差异巨大，overlay 在其上提供**统一架构**——同一份"应用比特流"可运行在任何实现了该 overlay 的器件上，概念类比 JVM 字节码 [^1^]；同时可给 overlay 添加宿主不具备的能力，如动态上下文保存/恢复、配置预加载 [^6^]。
- **代价**：资源与性能损失。ZUMA（开源细粒度 overlay）做到约 **40 个物理 LUT 实现 1 个虚拟 LUT** [^6^]；粗粒度 overlay（用 DSP 块实现虚拟功能单元）可把开销降到可接受水平并跑到 300 MHz 以上 [^6^]。
- **分类**：空间配置型（SC，功能单元任务固定）与时间复用型（TM，逐周期改变功能）；互联可为固定或运行时可重构的 NoC [^1^]。

**对你的战略意义（重要）：**

1. **Gowin / Lattice 低端器件没有原生部分重构能力**（详见 2.4），overlay 是在这些器件上实现"可热替换虚拟逻辑"的**唯一可行路线**；
2. overlay 天然提供**跨厂商二进制兼容性**——这是 Docker 体验的灵魂（`docker run` 不关心底层 CPU 型号），而原生 PR 比特流永远与具体器件型号绑定；
3. 合理的架构很可能是**双层混合**：高端器件（AMD/Intel）走原生 DPR 路线保证性能，低端器件走 overlay 路线保证可用性，两者共享同一套镜像清单、控制接口与编排协议。这与 Docker 的多架构 manifest（amd64/arm64）异曲同工。

### 2.3 部分重构（DPR/PR）的工程现实

这一节是 Ethereal 必须面对的"物理学"约束，数据均来自实测文献：

**重构通道与带宽**

- 配置时延模型：T_reconf = S_bitstream / B_config（比特流大小 ÷ 配置带宽）[^5^]。
- 配置控制器实测吞吐：Xilinx 官方 HWICAP（AXI）仅约 9 MB/s，带 DMA 的 Zynq ICAP 约 67 MB/s，学术优化实现 **ZyCAP 约 382 MB/s、DyRACT 约 400 MB/s**；PCAP 约 128 MB/s [^8^]。
- UltraScale+ 上 HBICAP 实测约 85~88 MB/s（4 MB 分区），HWICAP 经 AXI C2C 可慢至两个数量级之差 [^19^]。
- 小型分区（约 100 KB 比特流）经优化 ICAP DMA 的重构时间约 **250~400 µs** [^5^]；数据中心 SmartNIC 场景 6~12 MB 部分比特流的卡上 PR 时延为 **200~350 ms** [^17^]。

**结论：对小分区（嵌入式场景的典型情况），重构可以做到亚毫秒级——"快速替换虚拟逻辑"在物理上成立；但官方 IP 默认配置很慢，自研/采用学术优化 ICAP 控制器（ZyCAP 等开源实现）是必修课。**

**布局布线与槽位约束**

- PR 区域必须按时钟区域边界（Xilinx 7 系列/UltraScale：一个时钟区域高度）做二维 floorplanning；**模块重定位（relocation）只在尺寸与资源排列完全相同的 PRR 之间可能** [^8^]。
- 静态逻辑可能占用 PR 区域内的布线资源，导致 PR 区内 DSP/BRAM 等稀缺资源被阻塞；OpenPR 的"布线阻塞宏"方案依赖已停产的 ISE/XDL 流程，Vivado 时代主要靠 Abstract Shell 技术部分缓解 [^20^]。
- PR 编译的可伸缩性难控制：每个 PR 区的实现必须在上下文中完成，上下文与静态逻辑及 PR 区数量相关 [^20^]。
- PRflow/HiPR 等工作用预编译 overlay + 增量编译把函数级重构的编译时间压缩 3.5~10.9 倍 [^20^]，说明"镜像仓库 + 预编译槽位镜像"是标准做法——**运行时绝不能做全量布局布线**。

**解耦（decoupling）与接口稳定性**

- 重构期间必须用解耦逻辑（decoupler）把 PR 区接口拉到安全状态，防止半成品逻辑产生毛刺/非法总线事务；总线宏/代理 LUT 分区引脚用于保证重构周期内接口路径稳定 [^5^][^19^]。

### 2.4 开源 FPGA 工具链现状（决定你的 Verilator 优先路线与 Gowin 迁移路径）

- **Project X-Ray**（Xilinx 7 系列比特流文档化）、**Project Trellis**（Lattice ECP5）、**Project Icestorm**（iCE40）、**Project Apicula**（Gowin 比特流文档化，含 GW1N/GW2A 系列，社区活跃）[^13^][^22^][^30^]。
- **f4pga**（原 SymbiFlow）：Yosys（综合）+ VTR/nextpnr（布局布线）+ OpenFPGALoader（烧录）的端到端开源流程，覆盖 Xilinx 7 系列、Lattice iCE40/ECP5、QuickLogic 等 [^13^]。
- **Gowin 开源支持现状**：Yosys `synth_gowin` + nextpnr-himbaechel + Apicula `gowin_pack` + OpenFPGALoader 全链路可用，但官方标注 **experimental**；社区反馈 iCE40/ECP5 稳定性最好，Gowin 次之 [^23^][^24^][^30^]。
- **关键限制**：Gowin 器件**不支持 Xilinx 意义上的部分重构**（无 ICAP 等价物开放给用户逻辑；其 MCU 硬核产品支持软核擦写，但用户逻辑级 PR 无文档支持）。**这意味着 Gowin 平台的"容器热替换"只能走：(a) overlay 软虚拟化；(b) 整片快速重配置（小器件比特流小，SPI/JTAG 重载在毫秒级）+ 时分复用；(c) 多片并联空间复用。**
- **RapidWright**（AMD 官方开源 Java 框架）可操作器件数据库做局部实现，但生成部分比特流能力有限 [^20^]。
- **Verilator/Yosys/nextpnr 优先路线的评估**：用 Verilator + cocotb 建模整个 Shell + Slot + 互联架构，可以在不碰任何厂商工具链的情况下完成架构验证、接口协议冻结、重构调度算法仿真；但**仿真无法验证 PR 特有物理行为**（解耦毛刺、帧边界、ICAP 时序），这些只能在真实器件上做确认性验证。建议：仿真做"架构正确性"，硬件做"物理正确性"，两者通过同一套测试向量驱动。

### 2.5 多租户 FPGA 安全（你的平台要直面"不受信逻辑"）

ACM 2025 年多租户云 FPGA 安全综述将威胁分为四类 [^9^]：

1. **远程物理攻击**：功耗/电磁侧信道（SCA）、故障注入（FIA）、相邻布线串扰攻击、隐蔽信道——恶意租户逻辑可以在电气层面攻击同片其他租户；
2. **IP 威胁**：比特流窃取与篡改、IP 盗用；
3. **可信加速**：信任根（RoT）、比特流验证、安全飞地（enclave）；
4. **虚拟化风险**：虚拟化层自身被攻破导致跨租户访问。

可用的防御手段 [^9^]：

- **比特流检查器 / "FPGA 杀毒软件"**：装载前扫描恶意电路结构（LUT 环形振荡器、组合逻辑环等），但可被骗过（时序型振荡器），需配合 DRC 规则与零时序违例约束检查；
- **比特流加密**：现代 FPGA 均支持 AES-GCM 256（BBRAM/eFuse 存钥）[^9^]；
- **TPM + 远程证明**、多租户密钥聚合管理；
- 综述同时指出：**现有手段均非完备，多攻击面仅部分缓解** [^9^]。

**对 Ethereal 的设计约束：**

- 第一阶段（可信环境，嵌入式单机）可以把安全目标设为"防事故"而非"防攻击"；
- 但架构必须预留：镜像签名/哈希校验、装载前静态检查钩子、slot 间电气隔离的 floorplan 规则（保护环带/隔离带）、运行监控（各 slot 电流/温度异常检测）。

### 2.6 可靠性：配置存储器 SEU 与擦除（Scrubbing）

你的愿景中提到"避免灾难性崩溃"——在 FPGA 侧这对应 SRAM 型 FPGA 的软错误问题：

- SRAM 配置存储器对单粒子翻转（SEU）敏感，翻转累积会提高功能失效概率 [^25^][^29^]。
- 标准缓解：**配置存储器擦洗（scrubbing）**——后台周期读回 + ECC/CRC 校验 + 部分重构修复，Xilinx SEM IP 即此类实现；盲擦洗、错误触发擦洗、移位擦洗、散布擦洗等变体各有 MTTR 与开销权衡 [^25^][^27^][^29^]。
- **Ethereal 的机会**：你的平台天然拥有配置管理器（ICAP 控制器）与镜像仓库——把 scrubbing 做成平台内建的"健康监控子系统"（类比 Docker 的 liveness probe + 自动重启），对航天/汽车/工业客户是强卖点，而现有开源 FPGA 运行时（Coyote/TaPaSCo）均未内建此能力。

### 2.7 嵌入式/固件侧（Astral OS 的技术土壤）

- **WASM 微运行时**：WAMR（WebAssembly Micro Runtime，解释器 + AoT 双模式，AoT 接近原生性能且保留隔离保证）、Wasm3 等已在 MCU 上成熟 [^37^][^42^]。2025-2026 年出现商业（MicroEJ、Atym）与开源（AkiraOS：Zephyr + WAMR + Capability Guard，~60ns 权限检查开销）的 MCU 容器化方案 [^42^][^43^]；学术侧有 TinyContainer（多租户 MCU 容器运行时中间件，内建安全）[^42^]。
- **Zephyr userspace**：主流嵌入式 RTOS 中唯一把 MPU 隔离做成一等公民配置项的——非特权线程 + 内存分区/内存域 + 系统调用门（逐参数校验指针越界）+ 栈哨兵；fatal error handler 可重写为**只中止出错线程、系统继续运行**——这直接实现了你"避免灾难性崩溃"的目标 [^32^][^33^][^40^]。
- **Tock OS**（Rust 内核）：三层信任模型（核心内核 / Capsule 驱动 / MPU 隔离进程），进程可运行时加载更新，grant 机制解决内核动态内存安全，64 KB RAM 即可运行多租户互不信任应用 [^31^][^35^][^39^]；SOSP'25 的 TickTock 已开始对其隔离性做形式化验证 [^34^]。
- **FreeRTOS**：有 MPU 包装版本（FreeRTOS-MPU，特权/非特权任务），但无完整用户态模型与系统调用校验，能力远弱于 Zephyr/Tock [^32^]。

**对 Astral 的选型的启示（详见第 4 章）：Zephyr（MPU 用户态 + 生态最大）或 Tock 思路（Rust 内核 + MPU 进程）作为容器运行时的内核底座，WAMR 作为跨架构应用镜像格式，加上自研的代理 IO 与镜像/编排层。**

### 2.8 小结：竞争定位图

| 维度 | Coyote v2 | AmorphOS/OPTIMUS | TaPaSCo | Intel OFS | AkiraOS/TinyContainer | **Ethereal + Astral（你）** |
|---|---|---|---|---|---|---|
| 目标场景 | 数据中心 | 云 | 多板卡研究 | 数据中心 | MCU 应用容器 | **嵌入式 + 低端 FPGA + 聚合** |
| 运行时重构 | ✅ | ✅ | ❌ | ✅ | N/A | ✅ |
| 低端/无 PR 器件支持 | ❌ | ❌ | 部分 | ❌ | N/A | ✅（overlay 路线） |
| GPIO 级 IO 重定向 | ❌ | ❌ | ❌ | ❌ | 部分 | ✅ |
| 跨厂商镜像格式 | ❌ | 目标但未实现 | ❌ | ❌ | ✅（WASM） | ✅（双层镜像规范） |
| 逻辑+固件统一编排 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **（独有）** |
| 开源 | ✅ | ❌ | ✅ | ✅ | 部分 | ✅ |
| 内建 SEU 擦洗/健康管理 | ❌ | ❌ | ❌ | 部分 | ❌ | ✅（规划） |

---

## 3. Ethereal Logic Platform：可行性分析与待解决问题

### 3.1 三条技术路线对比（核心架构决策）

| | 路线 A：原生 DPR（部分重构） | 路线 B：Overlay 软虚拟化 | 路线 C：混合分层（推荐） |
|---|---|---|---|
| 原理 | 厂商 PR 流程，ICAP/PCAP 加载部分比特流到预划分槽位 | 在 fabric 上实现虚拟可重构架构，"逻辑镜像"是 overlay 配置数据 | 高端器件走 A，低端器件走 B，共享统一镜像清单与编排协议 |
| 性能/密度 | 原生性能，无损耗 | ZUMA 级细粒度 overlay 约 40:1 LUT 开销；粗粒度可大幅降低 [^6^] | 各取所长 |
| 跨厂商移植 | 比特流与器件型号强绑定，**不可移植** | 同一逻辑镜像可跑在任何实现该 overlay 的器件上（JVM 式）[^1^] | 镜像清单按"器件目标"索引，类比 Docker 多架构 manifest |
| 重构速度 | 小分区亚毫秒级可达，但依赖自研优化 ICAP 控制器 [^5^][^8^] | 配置数据极小，写 SRAM 寄存器即可完成，微秒级 | — |
| 低端器件（Gowin/Lattice） | **不可用**（无用户级 PR） | **唯一可行** | — |
| 工具链依赖 | Vivado/Quartus PR 流程（闭源，部分需许可） | 完全自主可控，Yosys/nextpnr 即可构建 overlay 配置 | — |
| 时序收敛 | 每个槽位镜像需离线收敛 | overlay 本身一次收敛，逻辑镜像只需满足 overlay 时序模型 | — |
| 工程难度 | 高（floorplan、解耦、帧边界） | 高（overlay 架构设计 + 映射工具） | 最高，但可分期 |
| 适用器件 | AMD 7 系列/US+，Intel Arria/Cyclone 10+ | 全部（包括 Gowin、Lattice、甚至 ASIC eFPGA） | — |

**推荐架构决策：路线 C，但分阶段实施——Phase 1 先在 AMD（Zynq/7 系列）上做路线 A 的 MVP（工程先例最多，ZyPR/Coyote 可参考 [^12^][^2^]），Phase 3 引入路线 B 覆盖 Gowin；镜像规范从第一天就按"双层"设计（逻辑描述层 + 器件绑定层），避免后期返工。**

### 3.2 提议的总体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    编排层（Orchestrator）                     │
│  镜像仓库客户端 · 部署策略 · 健康监控 · 与 Astral 的统一控制面    │
├─────────────────────────────────────────────────────────────┤
│              运行时守护（Ethereal Runtime Daemon）             │
│  Slot 分配器 · 重构调度器 · IO 重定向管理 · 镜像校验 · 事件日志  │
├────────────────────────── FPGA ─────────────────────────────┤
│  ┌───────────────── 静态 Shell（一次性烧写） ────────────────┐ │
│  │ 配置管理器（优化 ICAP 控制器） · 管理软核（可选）           │ │
│  │ 标准片上互联（AXI4/AXI-Stream 或自研轻量总线）             │ │
│  │ IO 重定向层（引脚 Mux/Crossbar + IO 代理）                │ │
│  │ 健康监控（温度/电压/看门狗 · SEU 擦洗引擎）                │ │
│  ├─────────┬─────────┬─────────┬───────────────────────────┤ │
│  │ vFPGA-0 │ vFPGA-1 │ vFPGA-2 │  …（PR Slot / Overlay 区） │ │
│  │(解耦器+ │(解耦器+ │(解耦器+ │                            │ │
│  │ 控制CSR)│ 控制CSR)│ 控制CSR)│                            │ │
│  └─────────┴─────────┴─────────┴───────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 子系统逐项分析：可能性与待解决问题

#### 3.3.1 虚拟 FPGA 单元（vFPGA Slot）与静态 Shell

**可行性：高。** Shell + 动态区的划分是 Coyote、Intel OFS（FIM/AFU）、SDAccel、AmorphOS 的共同范式，工程先例充分 [^2^][^14^]。

待解决问题：

1. **槽位划分与资源碎片**：固定槽位简单但内部碎片严重（逻辑大小不均）；可变槽位灵活但需要运行时 floorplan，学术界（VersaSlot、Knodel 的匀质分区抽象、bundling 细粒度分区可提升 LUT/FF 利用率 29~35%、降低碎片 15 个百分点）仍在探索 [^5^][^9^]。**建议：v1 固定 2~4 种槽位规格（S/M/L，类比云服务实例规格），v2 引入相邻同构槽位合并，v3 研究在线碎片整理（需逻辑迁移能力，见 3.3.6）。**
2. **静态逻辑占用 PR 区布线资源**导致的稀缺资源阻塞问题 [^20^]：floorplan 时必须为每个槽位保留独立布线走廊，Vivado Abstract Shell 流程可部分缓解，但需要在构建系统中固化约束模板。
3. **Shell 自身资源开销**：管理软核 + ICAP 控制器 + 互联 + IO 重定向层在 20K LUT 级器件上可能占去可观比例——需要给 Shell 做"瘦身配置"（裁剪版 Shell：无软核，由片外 MCU 通过 AXI/SPI 代理管理）。这是嵌入式场景与 Coyote（假设 x86 主机）的本质区别，也是你的差异化点。

#### 3.3.2 配置管理器（重构引擎）

**可行性：高，但必须自研或移植优化实现。** 官方 HWICAP（AXI 版）仅约 9 MB/s，直接用作"容器运行时"不可接受；学术开源实现 ZyCAP（约 382 MB/s）、DyRACT（约 400 MB/s）证明可提升 40 倍以上 [^8^]。

待解决问题：

1. **重构调度算法**：重构是"慢操作"（相对逻辑运行），调度器需要：(a) 镜像预取（预测下一任务，提前加载）；(b) 按镜像分组任务队列（Coyote 的启发式已证明有效，减少重构次数的效果可能压倒调度算法的其他方面）[^3^]；(c) 重构与计算重叠（双缓冲槽位：一个运行、一个预载）。
2. **比特流压缩与缓存**：部分比特流可压缩（空闲帧多）；常用镜像缓存于 DRAM/Flash（ZyPR 的链表缓存模式可参考 [^18^]）。
3. **重构期间的安全性**：必须先拉起槽位解耦器（decoupler）再启动 ICAP 写，完成后做接口握手校验再释放——这套状态机是"容器启动/停止生命周期"的硬件等价物，需要在 Verilator 阶段就建模验证。
4. **Gowin 平台**：无 ICAP 等价物 → overlay 配置口（自拟 SRAM 映射寄存器写接口）或整片 JTAG/SPI 重载（作为"冷替换"降级方案）。

#### 3.3.3 标准片上互联总线与控制接口

**可行性：高。** 每个 vFPGA 暴露统一接口（控制 CSR + 数据流口）是 Coyote v2（POSIX 风格 API）、Intel OFS（AXI4 + PIM shim）、RecoNIC 等的一致做法 [^10^][^14^][^17^]。

待解决问题：

1. **总线选型**：AXI4-MM（控制）+ AXI4-Stream（数据）是事实标准，但在 20K LUT 器件上偏重——建议定义**协议子集规范**（Ethereal Bus Interface, EBI），提供 AXI4 与轻量 Wishbone/自研流口两种实现，逻辑镜像针对 EBI 编程而非具体总线。
2. **跨槽位通信**：容器间通信（容器编排里的 service mesh 类比）需要片内 NoC 或交换结构；TRETS 2024 的框架用紧凑 NoC + Gatekeeper 实现 vFPGA 间互联与监管 [^15^]。**建议 v1 用集中式 AXI Crossbar（够用），v3 评估 NoC。**
3. **时钟与复位域**：每个槽位独立复位；多时钟域时互联需 CDC 处理——Shell 需提供时钟生成（MMCM/PLL 动态重配置）与标准 CDC 桥。

#### 3.3.4 IO 重定向（你构想中最具差异化、也最难的部分）

**可行性：中等偏高，需分层实现。** vFPIO 已证明"IO 端口虚拟化 + 平台无关用户逻辑"可行 [^2^]；但其面向数据流口，而嵌入式场景要处理的是**物理引脚**。

待解决问题：

1. **物理约束的硬边界**：引脚位置、电平标准（LVCMOS33/LVDS 等）、bank 供电、专用引脚（时钟输入、JTAG、配置复用脚）都是物理绑定的——**IO 重定向不是任意到任意**。现实模型是：Shell 引出一组"可路由 IO 池"（经 Crossbar/Mux 连接槽位），每个引脚的电气能力在板级描述文件（Board Manifest）中声明，编排器做约束感知分配。
2. **Crossbar 的代价**：全连接 Crossbar 在引脚多时是 O(n×m) 的 LUT 开销。替代方案：(a) 分组交换（按 8/16 引脚分组）；(b) 利用 FPGA IOB 的可编程性（部分器件支持运行时改 IO 标准/驱动强度）；(c) 低速信号走 Crossbar，高速信号在 Shell 里做协议代理（见下）。
3. **协议代理 IO（Proxy IO）**：对 UART/SPI/I2C/CAN 等标准外设，更优雅的做法是 Shell 内实现协议引擎，槽位逻辑只看到寄存器/流接口——这正是 Astral 侧"代理 IO"在 FPGA 侧的镜像，也天然提供了隔离（恶意/出错逻辑无法直接驱动物理引脚造成电气冲突）。**建议把 IO 重定向做成两级：L1 引脚 Mux（简单、通用）、L2 协议代理（安全、省心）。**
4. **时序问题**：经过 Mux/代理后引脚时序恶化，高速接口（>50 MHz 的并行总线）可能不可行——需要在板级描述中标注每条 IO 路径的最大频率，编排器拒绝超频部署。

#### 3.3.5 逻辑镜像格式与镜像仓库（"Bitstream 版 OCI Image"）

**可行性：高，纯软件工程，但设计决策影响深远。** 无人做过标准化，是 Ethereal 可以定义事实规范的机会。

建议的镜像结构（OCI Image 启发）：

```
eth-logic-image/
├── manifest.yaml        # 镜像清单：名称/版本/作者/签名
├── targets/             # 多架构目标（类比 Docker manifest list）
│   ├── xc7z020-slot-s.bit      # 器件+槽位规格绑定的部分比特流
│   ├── gw2a-overlay.bin        # overlay 配置数据
│   └── ...
├── interface.yaml       # 接口契约：EBI 版本、所需 IO 能力、时钟需求、资源需求
├── capabilities.yaml    # 声明所需的 IO/服务权限（类比 Astral 的能力清单）
└── docs/
```

待解决问题：

1. **接口契约的版本化**：EBI 演进必须向后兼容，否则镜像生态碎片化——建议第一年就冻结 EBI v1 的最小集。
2. **签名与信任链**：镜像签名（Ed25519）+ 装载前校验 + 可选比特流静态检查钩子（对接 2.5 节的"比特流杀毒"研究 [^9^]）。Phase 1 做签名，检查器留接口。
3. **仓库实现**：早期直接用 Git 仓库 + 静态文件服务器即可，规范先行；后期可兼容 OCI Registry（比特流作为 OCI artifact 存储，云原生生态可直接复用）。

#### 3.3.6 高级能力（商业级才需要，但架构要预留）

1. **状态保存/恢复与逻辑迁移**：overlay 路线可通过添加动态上下文保存机制实现硬件任务抢占与在线迁移 [^6^]；原生 DPR 路线极难（需 readback 用户寄存器状态，且目标槽位必须同构 [^8^]）。**这是 overlay 路线的隐藏优势，建议在 overlay 架构设计时就内建 context save/restore。**
2. **SEU 擦洗与健康监控**：配置管理器已具备读回能力，实现周期性读回 + CRC/ECC 校验 + 局部修复是可工程化的（Xilinx SEM IP 为厂商范本 [^29^]；盲擦洗/移位擦洗/错误触发擦洗的权衡已有系统研究 [^25^][^27^]）。包装成"slot 健康探针 + 自动重载"，对应 Docker 的 livenessProbe + restartPolicy。
3. **多租户安全**：见 2.5。嵌入式单业主场景可先"防事故"（解耦 + 配额 + 看门狗），防攻击（侧信道/故障注入/比特流检查器）作为商业版特性 [^9^]。
4. **调试可观测性**：slot 内嵌轻量 ILA（集成逻辑分析仪）核、通过 Shell 的调试总线读出 trace；镜像清单声明调试接口。这是"容器日志"的硬件对应物，对开发者体验至关重要。

### 3.4 风险登记册（Ethereal 侧 Top 风险）

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | Vivado PR 流程的工程坑（Abstract Shell、帧边界、许可）远超预期 | 高 | 高 | Phase 0 用 ZyPR/Coyote 先例做 spike；社区（f4pga、openXC7）求助 |
| R2 | Shell + 槽位开销在小器件上占比过高，商业价值受质疑 | 中 | 高 | 裁剪版 Shell；overlay 路线定位低端；文档明确器件分级 |
| R3 | IO 重定向的 Crossbar 开销与频率损失 | 中 | 中 | 两级设计（Mux + 协议代理）；板级描述约束分配 |
| R4 | 跨厂商镜像规范无人跟随，沦为自娱 | 中 | 高 | 早期就规范先行、文档先行；争取 TaPaSCo/Coyote 社区对话 |
| R5 | 单人维护者精力耗尽（开源项目最常见死因） | 中 | 高 | 严格的阶段退出标准；每个 Phase 产出可独立使用的工件 |
| R6 | Gowin overlay 性能/密度不被接受 | 中 | 中 | 粗粒度 overlay（面向特定应用域，如电机控制/协议桥）；诚实标注性能包线 |
| R7 | 厂商法律风险（逆向比特流格式） | 低 | 高 | 只用已公开文档与社区项目（X-Ray/Apicula）；不自行逆向；必要时咨询法务 |

---

## 4. Astral Universal OS Platform：可行性分析与待解决问题

（篇幅上 Ethereal 是重点，Astral 给出同等结构的精简版；其技术土壤比 Ethereal 成熟得多。）

### 4.1 定位与内核选型矩阵

| 底座 | 隔离能力 | 容器化适配度 | 生态 | 评估 |
|---|---|---|---|---|
| **Zephyr + userspace** | MPU 内存域 + 系统调用门 + 内核对象 ACL，出错可只杀线程 [^32^][^33^] | 高（llext 可加载扩展、设备模型成熟） | 最大（Linux 基金会） | **推荐主底座** |
| Tock OS | MPU 进程 + Rust 内核 + grant，形式化验证进行中 [^35^][^34^] | 中（进程模型即容器雏形，但生态小） | 小 | 学术参考，可借鉴设计 |
| FreeRTOS(-MPU) | 仅特权级隔离，无完整用户态 [^32^] | 低 | 大 | 作为兼容目标而非底座 |
| NuttX | 有内核构建模式与 MPU 支持 | 中 | 中 | 兼容目标 |
| RT-Linux | 完整 MMU 隔离（容器即 OCI） | 高但偏重 | 大 | "高规格目标"，复用 Pantavisor/balena 思路 |

**推荐架构：三层容器模型**

1. **Type-N（Native 容器）**：Zephyr userspace 线程/内存域 + 权限清单，跑原生编译的 PIC 代码（Zephyr llext 或自研加载器）——性能最高，隔离靠 MPU；
2. **Type-W（WASM 容器）**：WAMR 运行时（解释器 + AoT）[^42^]，跨架构可移植镜像，隔离靠 WASM 沙箱 + Capability 清单（AkiraOS 的 ~60ns 检查证明开销可接受 [^43^]）——**推荐作为 Astral 的默认镜像格式**；
3. **Type-F（FPGA 联动容器）**：特殊容器，其"计算体"是 Ethereal 的一个 vFPGA 逻辑镜像，控制面是 MCU 上的代理任务——**这就是两个平台的聚合点**：Astral 编排器把 FPGA 槽位当作一种可调度资源，通过 Ethereal Runtime 部署逻辑镜像，再把其寄存器/流口映射为该容器的虚拟 IO。

### 4.2 待解决问题（Astral 侧）

1. **代理 IO / 虚拟 IO**：定义统一的虚拟外设接口（虚拟 GPIO/UART/I2C/SPI/CAN/网络），容器只看到虚拟口；代理层做权限仲裁、多路复用与冲突检测。Zephyr 的设备模型 + 系统调用门提供了现成的挂接点 [^32^]。与 Ethereal 的 L2 协议代理共享同一套"外设能力清单"规范——**一份清单，两侧通用**。
2. **内存问题处理（你的核心诉求）**：
   - 越界访问：MPU 内存域硬隔离（硬件兜底）[^32^] + WASM 线性内存边界检查（软件兜底）[^42^]；
   - 冲突访问：代理 IO 的互斥仲裁 + 共享内存区的显式授权（参考 Zephyr 内核对象 ACL [^33^]）；
   - 灾难性崩溃防护：fatal handler 重写为"杀容器、保系统"（Zephyr 已证明模式可行 [^33^]）+ 容器级看门狗 + 崩溃现场快照（寄存器/栈/MPU 故障地址打包上报，类比容器退出日志）；
   - 栈溢出：MPU 栈哨兵（Zephyr CONFIG_MPU_STACK_GUARD）[^32^]。
3. **镜像格式与运行时**：WASM 模块 + manifest（能力、资源配额、虚拟 IO 需求）；原生容器用 PIC 二进制 + 同一 manifest。仓库与 Ethereal 共用（同一 OCI artifact 体系）。
4. **跨 RTOS 抽象**：你提到 FreeRTOS/NuttX/RT-Linux 都要支持——建议**定义 Astral API 规范（POSIX 子集 + 容器控制面），先只在 Zephyr 上实现参考运行时**，其余平台作为社区适配目标。不要一开始就做三底座并行。
5. **资源配额与实时性**：容器的 CPU 配额（EDF/速率单调之外加带宽服务器）、内存配额（静态分区为主，堆为辅）；WASM 解释器对硬实时任务不可用，需 AoT 或 Native 容器——文档要明确实时等级与容器类型的对应关系。

---

## 5. 路线图与 TODOs（原型 → 商业级）

节奏假设：单人业余/半职投入（每周 8~15 小时），标注每个阶段的**退出标准（Exit Criteria）**——达到即进入下一阶段，达不到则收缩范围而不是硬撑。每阶段都产出**可独立使用的工件**（防止烂尾归零）。团队化后，FPGA 侧与 Astral 侧可从 Phase 2 起并行。

### Phase 0 —— 调研验证与仿真建模（预计 2~3 个月）

**目标：不写任何厂商工具链代码，用 Verilator/cocotb 把架构跑通，同时用最小成本验证 PR 物理可行性。**

TODOs：

- [ ] ELP-0.1 搭建仿真仓库：Verilator + cocotb 环境，CI（GitHub Actions）跑 RTL 回归
- [ ] ELP-0.2 建模最小 Shell：4 个虚拟槽位 + 集中式互联（Crossbar）+ 每槽位解耦器 + 模拟配置口（用寄存器写模拟 ICAP 行为）
- [ ] ELP-0.3 定义 EBI（Ethereal Bus Interface）v0.1 草案：控制 CSR 布局、数据流口、中断模型
- [ ] ELP-0.4 在仿真中实现"重构"：把槽位逻辑做成可运行时替换的仿真模型（Verilator 下用可重加载的 Verilator 模型或功能桩模拟重构时延与解耦过程），验证槽位生命周期状态机（停止→解耦→加载→校验→释放→运行）
- [ ] ELP-0.5 硬件 spike（验证物理可行性，借用现成流程）：在一块 AMD Zynq 板上用 Vivado PR 流程 + ZyPR/ZyCAP 思路跑通"2 槽位、命令行换比特流"，实测重构时延并记录踩坑（此步不产出平台代码，只产出工程笔记）
- [ ] ELP-0.6 撰写《架构决策记录 ADR-001：路线 C（原生 DPR + Overlay 双层）》与《镜像格式 RFC-001 草案》

**评估与退出标准：**

| 评估项 | 指标 |
|---|---|
| 仿真验证 | 槽位生命周期状态机通过全部 cocotb 测试（含异常路径：加载失败、校验失败、运行中强制停止） |
| 物理验证 | Zynq 上单槽位重构时延实测 < 5 ms（小比特流，优化 ICAP 控制器）或 < 50 ms（官方 HWICAP） |
| 文档 | ADR-001、EBI v0.1、RFC-001 公开 |
| 风险熔断 | 若 PR spike 证明 Vivado 流程阻塞超过 4 周 → 降级为"仿真 + overlay 先行"，原生 DPR 延后 |

**资源估计：** 约 120~180 人时。**团队化扩展点：** 一人做仿真建模，一人做 PR spike，可压缩到 1~1.5 个月。

---

### Phase 1 —— MVP：单平台可演示原型（预计 3~5 个月）

**目标：在 AMD Zynq 平台上做出"FPGA 版 docker run"的最小闭环：一条命令把一个逻辑镜像装载进虚拟槽位并运行，可热替换。**

TODOs：

- [ ] ELP-1.1 实现静态 Shell v1（Zynq-7000/7 系列）：2 个 PR 槽位 + AXI4-Lite 控制口 + AXI4-Stream 数据口 + 槽位解耦器 + 中断聚合
- [ ] ELP-1.2 移植/实现优化 ICAP 配置管理器（DMA 模式，目标 >100 MB/s；参考 ZyCAP 设计 [^8^]）
- [ ] ELP-1.3 实现配置管理守护（PS 侧 Linux 用户态或裸机）：镜像加载、签名校验（先 SHA-256，Ed25519 后置）、槽位分配表、生命周期控制
- [ ] ELP-1.4 镜像格式 v1 落地：manifest.yaml + interface.yaml + targets/ 结构；配套 `ethctl` CLI（load / run / stop / ps / logs / rm，刻意对齐 Docker 命令习惯）
- [ ] ELP-1.5 构建系统：Vivado 工程模板 + Tcl 脚本，从用户 RTL 一键产出"槽位镜像"（含 floorplan 约束模板、Abstract Shell 流程封装）
- [ ] ELP-1.6 三个演示镜像：LED/PWM 控制、UART 桥、简单加速器（如 CRC/AES）——验证热替换不干扰相邻槽位
- [ ] ELP-1.7 基础 IO 重定向 v1：静态引脚池 + 槽位 Mux（每槽位 8~16 路 GPIO 可路由），板级描述文件（Board Manifest）v1
- [ ] ELP-1.8 文档站（快速开始 + 镜像作者指南 + 架构总览）；仓库公开

**评估与退出标准：**

| 评估项 | 指标 |
|---|---|
| 核心闭环 | `ethctl run <image>` 到逻辑运行 < 1 s（含加载）；热替换期间相邻槽位零干扰（示波器/计数器验证） |
| 稳定性 | 连续 10,000 次重构循环无挂死、无配置损坏 |
| 开销 | Shell 占 Zynq-7020 LUT < 20% |
| 社区信号 | 仓库公开，README + 演示视频；目标 50+ star 即视为有外部兴趣 |
| 风险熔断 | 若 10k 次循环稳定性不达标 → 优先解决解耦/时钟问题，不进入 Phase 2 |

**资源估计：** 约 300~450 人时。**此阶段结束即拥有"能发朋友圈/黑客新闻的 demo"——是争取早期社区关注的关键节点。**

---

### Phase 2 —— 平台化：规范、互联与编排雏形（预计 4~6 个月）

**目标：从 demo 变成"平台"：规范冻结、多槽位编排、IO 重定向完整版、与 Astral 的第一个聚合演示。**

TODOs：

- [ ] ELP-2.1 EBI v1.0 冻结（向后兼容承诺开始）；镜像格式 RFC-001 → v1.0（含 Ed25519 签名）
- [ ] ELP-2.2 重构调度器：任务队列按镜像分组 + 镜像预取 + 常用镜像 DRAM/Flash 缓存（参考 Coyote 调度启发式 [^3^] 与 ZyPR 缓存模式 [^18^]）
- [ ] ELP-2.3 IO 重定向 v2：两级设计落地——L1 分组引脚 Mux（Crossbar 开销控制）+ L2 协议代理（UART/SPI/I2C 引擎内建于 Shell，槽位只见寄存器接口）
- [ ] ELP-2.4 跨槽位通信通道（共享内存邮箱 + 流直连），容器间通信规范 v1
- [ ] ELP-2.5 健康监控 v1：槽位看门狗 + 崩溃自动重载策略（restartPolicy）；调试通道（slot 级 ILA 核 + `ethctl logs`）
- [ ] ELP-2.6 槽位规格体系：S/M/L 三档 + 相邻同构槽位合并（缓解碎片 [^5^]）
- [ ] ELP-2.7 **聚合演示 v1**：Astral 最小运行时（Zephyr + WAMR，一个 WASM 容器）通过统一控制面调用 Ethereal 部署一个 vFPGA 逻辑镜像并收发数据——"固件容器 + 逻辑容器同屏运行"
- [ ] ELP-2.8 镜像仓库 v1：基于 OCI Registry 的 artifact 存储（比特流作为 OCI layer）或静态仓库 + 索引服务

**评估与退出标准：**

| 评估项 | 指标 |
|---|---|
| 规范 | EBI v1.0、镜像格式 v1.0、Board Manifest v1.0 全部公开并语义化版本管理 |
| 调度 | 预取命中时容器冷启动 < 100 ms；重构次数比分组调度前减少 ≥ 50%（复现 Coyote 结论量级） |
| IO | 协议代理支持 UART/SPI/I2C；引脚 Mux 路径实测最大频率标注进 Board Manifest |
| 聚合 | WASM 容器 ↔ vFPGA 逻辑双向数据通路演示成功，延迟/吞吐有实测数据 |
| 社区 | 至少 1 名外部贡献者提交 PR；镜像仓库有 ≥ 10 个第三方镜像 |

**资源估计：** 约 400~600 人时。**团队化扩展点：** 从本阶段起 Astral 线可独立一人推进（见 5.A）。

---

### Phase 3 —— 跨厂商与 Overlay 路线（预计 6~9 个月，可与 Phase 2 部分重叠）

**目标：兑现"跨厂商"承诺：Intel 平台适配 + Gowin 平台通过 overlay 路线接入；镜像多目标清单落地。**

TODOs：

- [ ] ELP-3.1 Shell 移植层抽象：把配置管理器/互联/解耦做成可移植 RTL 组件（厂商原语隔离在 `hal/` 目录）
- [ ] ELP-3.2 Intel（Cyclone 10 GX / Arria 10 或 MAX 10 视资源）适配：PR 流程或整片重构降级方案，验证 Shell 可移植性
- [ ] ELP-3.3 **Overlay 架构设计与实现（Ethereal Fabric v1）**：面向低端器件的粗粒度 overlay（可配置功能单元阵列 + 可编程互联），内建上下文保存/恢复机制 [^6^]
- [ ] ELP-3.4 Overlay 映射工具链：用户 RTL/描述 → overlay 配置数据（Yosys 前端 + 自研映射器）；镜像的 `targets/` 增加 overlay 目标
- [ ] ELP-3.5 Gowin 接入：在 GW2A（Tang Primer 20K 级）上跑 Ethereal Fabric v1 + 裁剪版 Shell（无软核，片外 MCU 经 SPI 代理管理）——**实现"低端 FPGA 也能跑逻辑容器"的差异化演示**
- [ ] ELP-3.6 镜像多架构清单（manifest list）：同一镜像名按器件目标解析，对齐 Docker 多架构体验
- [ ] ELP-3.7 安全强化 v1：镜像签名校验强制化、装载前静态检查钩子（接口预留）、槽位 floorplan 隔离带规则、各 slot 功耗/温度异常监控
- [ ] ELP-3.8 SEU 擦洗引擎 v1（AMD 平台）：周期读回 + CRC + 局部修复，包装成 slot 健康探针 [^25^][^29^]

**评估与退出标准：**

| 评估项 | 指标 |
|---|---|
| 跨厂商 | 同一控制面在 AMD + Intel + Gowin 三平台部署同一应用语义（不要求同一比特流） |
| Overlay 性能 | Ethereal Fabric v1 上跑出 ≥ 20 MHz 的实用逻辑（如电机控制 PWM + 编码器接口），LUT 开销实测并公开 |
| 可移植性 | Shell 移植到第二厂商的增量工作量 < 初版的 30% |
| 安全 | 未签名镜像被拒绝；异常功耗槽位被自动隔离 |
| 风险熔断 | 若 overlay LUT 开销 > 10:1（粗粒度目标）且无可行优化 → Gowin 路线降级为"整片快速重载 + 时分复用"并诚实文档化 |

**资源估计：** 约 600~900 人时（这是整个项目最重的阶段，也是学术新颖性最高的阶段——**建议把 overlay + 低端器件容器化写成论文投稿 FPL/FCCM，为项目建立学术声誉**）。

---

### Phase 4 —— 开源生态与"聚合化"完整版（预计 6~12 个月）

**目标：平台成熟化：完整编排、开发者体验、Astral 完整运行时、社区治理成型。**

TODOs：

- [ ] ELP-4.1 编排器（Ethereal Orchestrator）：声明式部署文件（YAML，类比 docker-compose）、多板卡管理、资源配额与调度策略插件化
- [ ] ELP-4.2 开发者体验：GUI/TUI 仪表盘（slot 占用、IO 映射、健康状态可视化）、VS Code 扩展（镜像构建/部署/调试）
- [ ] ELP-4.3 HLS 接入：Vitis HLS / 开源 HLS（如 XLS、CIRCT 生态）到槽位镜像的模板，降低镜像创作门槛（Coyote v2 的 HLS 体验是标杆 [^17^]）
- [ ] ELP-4.4 Astral 完整运行时（见 5.A）：Type-N/Type-W/Type-F 三类容器齐备，统一镜像仓库
- [ ] ELP-4.5 安全强化 v2（面向多租户场景）：比特流静态检查器原型（恶意结构扫描 [^9^]）、槽位间侧信道缓解指南、可选 TPM 锚定
- [ ] ELP-4.6 参考设计套件：3~5 个完整行业 demo（电机控制、软件定义无线电前端、工业协议网关、AI 预处理协处理），每个都是"Astral 容器 + Ethereal 逻辑"的聚合范例
- [ ] ELP-4.7 社区治理：CONTRIBUTING、行为准则、RFC 流程、双周公开例会；注册商标与域名

**评估：** 社区指标（star/contributor/镜像数）、生态指标（第三方板卡适配数）、质量指标（CI 覆盖率、文档完整度）。**退出标准：项目进入"你不参与也能转"的状态（至少 2 名核心贡献者）。**

---

### Phase 5 —— 商业级演进（12 个月以上）

**目标：在开源核心之上构建商业能力。注意：以下全部为"可选扩展"，开源核心保持完整可用。**

TODOs：

- [ ] ELP-5.1 企业版编排：集群管理（多板卡池化调度，借鉴 ViTAL 的集群抽象 [^9^]）、RBAC、审计日志、SLA 监控
- [ ] ELP-5.2 安全认证路径：工业（IEC 61508 预评估）、汽车（ISO 26262 工具链鉴定材料）——SEU 擦洗 + 健康监控子系统是差异化卖点 [^27^][^29^]
- [ ] ELP-5.3 云端集成：镜像仓库 SaaS、CI/CD 模板（GitHub Actions 一键构建比特流镜像）、远程调试隧道
- [ ] ELP-5.4 商业支持：LTS 版本、厂商适配服务、培训
- [ ] ELP-5.5 生态合作：与 Gowin/国产 FPGA 厂商洽谈官方适配（你的平台对他们是有价值的软件生态补充）；与 RISC-V 软核生态（VexRiscv 等 [^28^]）集成预置镜像

**评估：** 商业指标（付费 PoC 数、适配服务合同）、认证里程碑、生态合作备忘录。**关键判断点：Phase 4 结束时若社区规模不足，宁可继续深耕开源而不是强行商业化。**

---

### 5.A Astral OS 支线 TODOs（自 Phase 2 起可与主线并行）

- [ ] AST-2.1 Zephyr 底座：userspace 内存域 + 自定义 fatal handler（杀容器保系统）[^32^][^33^]
- [ ] AST-2.2 WAMR 集成 + Capability 清单机制（~60ns 级内联检查为参照 [^43^]）
- [ ] AST-2.3 代理 IO v1：虚拟 GPIO/UART/I2C，权限清单仲裁
- [ ] AST-2.4 镜像格式（与 Ethereal 同构 manifest）+ `astctl` CLI + OTA 部署
- [ ] AST-3.1 Type-N 原生容器（PIC 加载器 + MPU 域）
- [ ] AST-3.2 Type-F 容器（FPGA 联动）产品化：统一编排演示
- [ ] AST-4.1 崩溃现场快照与远程诊断；内存问题检测套件（栈哨兵、堆守卫、越界报告）
- [ ] AST-4.2 兼容层：FreeRTOS/NuttX 的 Astral API 适配指南（社区任务）

---

### 5.B 全程贯穿的非技术 TODOs

- [ ] 品牌与命名：Ethereal/Astral 名称的商标与 GitHub 组织名可用性检查（**务必尽早**，避免后期改名成本）
- [ ] 每阶段一篇公开技术博客（架构决策、踩坑、数据）——个人项目的可信度靠持续公开写作建立
- [ ] 会议纪要/RFC 全部公开（吸引协作者的关键信号）
- [ ] 年度路线图评审：本文件每 6 个月根据实际进度修订一次

---

## 6. 开源策略与许可证建议

**推荐组合（双轨制）：**

| 资产类型 | 推荐许可证 | 理由 |
|---|---|---|
| 软件（运行时、CLI、编排器、Astral 组件） | **Apache-2.0** | 对标 Zephyr、Apache NuttX、f4pga；专利授权条款对工业用户友好；嵌入式行业对 GPL 敏感（厂商不愿开源固件衍生作品） |
| RTL/硬件设计（Shell、互联、overlay fabric） | **CERN-OHL-S v2**（强互惠）或 Apache-2.0（若想最大化采用） | 硬件领域的 Apache/GPL 类比长期混乱，CERN-OHL 是少数为 HDL 设计的许可证；若你的首要目标是生态扩张，可退一步用 Apache-2.0 统一 |
| 规范文档（EBI、镜像格式、Board Manifest） | **CC BY 4.0** + 明确声明"实现规范不需要许可" | 规范必须零门槛被实现，包括被商业闭源实现 |
| 官方镜像仓库中的基础镜像 | 各镜像自带许可证，仓库服务条款明确免责 | 类比 Docker Hub |

**商业模型建议（Phase 5）：** 核心平台永远 Apache-2.0 开源（对标 Coyote/TaPaSCo 的学术开源与 Zephyr 的基金会模式）；商业收入来自：企业版编排与集群管理、安全认证服务、厂商适配服务、镜像仓库 SaaS、LTS 支持。**不建议双许可证**（如 GPL+商业）：你是单人起步，双许可证需要 CLA 和法务基础设施，且会吓退第一批贡献者。

**治理建议：** 早期 BDFL（你）+ RFC 流程；Phase 4 后考虑加入中立基金会（Linux Foundation / CHIPS Alliance——后者专注开源硬件，与 f4pga 同门）以提升工业界信任。

---

## 7. 关键开放问题（需要你决策）

1. **EBI（总线接口）要不要基于 AXI？** 基于 AXI 生态兼容最好，但在小器件上偏重；自研轻量协议则镜像生态完全锁定在你的平台。我倾向于"AXI4-Lite 兼容子集 + 可选轻量前端"，但希望你确认。
2. **Overlay 的目标应用域**：通用细粒度 overlay（ZUMA 式，40:1 开销 [^6^]）还是面向特定域（电机控制/协议处理/DSP）的粗粒度 overlay（约 10:1 以内）？后者实用但"通用容器"的故事会变弱。
3. **Astral 的默认镜像格式**：WASM（跨架构、沙箱成熟 [^42^]）还是原生 PIC（性能、但每架构一个 target）？我的建议是 WASM 默认 + 原生可选。
4. **第一块目标板**：你手上的 AMD 平台具体是哪块（Zynq-7000？UltraScale+？纯 FPGA Artix/Kintex？）——影响 Phase 1 Shell 是否含 PS 侧软件栈。Gowin 是 GW2A 还是 GW5A 系列？影响 overlay 规模预算。
5. **"聚合化"的统一控制面形态**：是做一个统一的 `ethereal` CLI/API 同时管理逻辑容器与固件容器（强耦合、体验统一），还是两个平台各自独立、通过标准接口互操作（松耦合、各自可单独成功）？我建议**后者起步、前者作为 Phase 4 的编排器形态**。
6. **论文 vs 产品的优先级**：overlay + 低端器件容器化有可发表性（FPL/FCCM/TRETS 级别）；写论文会占用 2~3 个月，但能为项目带来学术背书与协作者。是否纳入计划？

---

## 8. 参考文献

[^1^]: A Survey of System Architectures and Techniques for FPGA Virtualization（overlay/intermediate fabric 综述）, arXiv:2011.09073 — https://arxiv.org/pdf/2011.09073
[^2^]: Coyote v2: Raising the Level of Abstraction for Data Center FPGAs, arXiv:2504.21538 — https://arxiv.org/html/2504.21538v1
[^3^]: Korolija et al., "Do OS Abstractions Make Sense on FPGAs?" (Coyote), OSDI 2020 — https://www.usenix.org/system/files/osdi20-korolija.pdf
[^4^]: Ma et al., "OPTIMUS: A Hypervisor for Shared-Memory FPGA Platforms", USENIX ATC 2020 — https://web.eecs.umich.edu/~barisk/public/optimus.pdf
[^5^]: Dynamic Partial Reconfiguration in FPGAs — Emergent Mind 综述（重构时延模型、分区技术、开销数据） — https://www.emergentmind.com/topics/dynamic-partial-reconfiguration-dpr
[^6^]: Bollengier et al., "Overlay Architectures For FPGA Resource Virtualization"（含 ZUMA 40 LUT/虚拟 LUT 数据） — https://hal.science/hal-01405912v1/document
[^7^]: FPGA Virtualization 课程讲义（AmorphOS：Zone/Morphlet/Hull/Registry）, UCSD CSE291J — https://cseweb.ucsd.edu/~yiying/cse291j-winter20/reading/FPGA-Virtualization.pdf
[^8^]: "FPGA Dynamic and Partial Reconfiguration: A Survey of Architectures, Methods, and Applications"（配置控制器吞吐对比表、PR 约束）, ACM Computing Surveys — https://www.cse.wustl.edu/~roger/565M.s23/3193827.pdf
[^9^]: "Multi-Tenant Cloud FPGA: A Survey on Security, Trust, and Privacy", ACM TRETS 2025 — https://dl.acm.org/doi/10.1145/3713078
[^10^]: Ramhorst, Heer, Alonso, "Coyote v2: Towards Open-Source, Reusable Infrastructure for Data Center FPGAs", LATTE 2025 — https://capra.cs.cornell.edu/latte25/paper/3.pdf
[^11^]: "Deploying Multi-tenant FPGAs within Linux-based Cloud Infrastructure", ACM TRETS 2021 — https://par.nsf.gov/servlets/purl/10366092
[^12^]: "ZyPR: End-to-end Build Tool and Runtime Manager for Partial Reconfiguration of FPGA SoCs at the Edge", ACM TRETS 2023 — https://dl.acm.org/doi/full/10.1145/3585521
[^13^]: "F4PGA and Project XRAY"（开源工具链组成与流程）, Controlpaths — https://www.controlpaths.com/2022/08/29/f4pga-and-project-xray/
[^14^]: Intel Open FPGA Stack（OFS）Shell Technical Reference Manual（FIM/AFU/PR 架构） — https://ofs.github.io/ofs-2024.2-1/hw/d5005/reference_manuals/ofs_fim/mnl_fim_ofs_d5005/
[^15^]: "Architectural Support for Sharing, Isolating and Virtualizing FPGA Resources"（NoC + Gatekeeper + TMMU 的 intra-FPGA 虚拟化框架）, ACM TRETS 2024 — https://dl.acm.org/doi/full/10.1145/3648475
[^16^]: Gowin Arora II FPGA 产品页（GW2A 系列资源与封装） — https://www.gowinsemi.com/en/product/arora-ii-fpga/
[^17^]: "Reconfigurable SmartNICs: A Comprehensive Review of FPGA Shells"（Coyote v2/Corundum/OpenNIC/RecoNIC 等对比，PR 时延与构建时间数据）, MDPI Applied Sciences 2026 — https://www.mdpi.com/2076-3417/16/3/1476
[^18^]: Bucknall, "Build Framework and Runtime Abstraction for Partial Reconfiguration"（远程重构、镜像缓存链表）, PhD thesis, University of Warwick 2022 — https://warwick.ac.uk/fac/sci/eng/people/suhaib_fahmy/publications/bucknall-phdthesis2022.pdf
[^19^]: "Cross-Chip Partial Reconfiguration for the Initialisation of FPGAs"（HWICAP vs HBICAP 吞吐实测）, arXiv:2408.08626 — https://arxiv.org/pdf/2408.08626
[^20^]: Xiao, "Accelerating FPGA Developments from C to Bitstreams"（PRflow/HiPR、PR 布线占用与 Abstract Shell 问题）, PhD thesis — https://vagrantxiao.github.io/files/PhdThesis.pdf
[^21^]: Soni, "Open-Source FPGA Bitstream Generation"（JBits/比特流生成历史）, Virginia Tech — https://vtechworks.lib.vt.edu/bitstream/handle/10919/51836/Soni_RK_T_2013.pdf
[^22^]: Project X-Ray（Xilinx 7 系列比特流文档化）, GitHub — https://github.com/f4pga/prjxray
[^23^]: YoWASP nextpnr 套件（含 Gowin via Project Apicula，标注 experimental）, PyPI — https://pypi.org/project/yowasp-nextpnr-gowin/
[^24^]: "Programming an FPGA with a FOSS toolchain"（Gowin Tang Nano 9K 开源流程实录）, pera's blog — https://blog.peramid.es/posts/2024-10-19-fpga.html
[^25^]: "An analysis of FPGA configuration memory SEU accumulation"（擦洗策略、frame criticality）, UC3M — https://e-archivo.uc3m.es/bitstreams/66eaff39-bf5f-4e4e-b88c-a6d56aa28fa8/download
[^26^]: Lushay Labs：开源工具链手工安装指南（Yosys/nextpnr/Apicula/OpenFPGALoader） — https://learn.lushaylabs.com/os-toolchain-manual-installation/
[^27^]: "SEU Mitigation Techniques for Advanced FPGAs"（盲擦洗/内部 vs 外部擦洗器等）, Chalmers — https://publications.lib.chalmers.se/records/fulltext/202966/202966.pdf
[^28^]: EEVBlog 论坛：Gowin 与 Yosys 实际使用反馈（iCE40/ECP5 最稳，Gowin 次之） — https://www.eevblog.com/forum/fpga/gowin-vs-yosys/
[^29^]: Bedi, "Scrubbing SRAM-based FPGAs to prevent the accumulation of SEUs"（SEM IP、essential bits、擦洗模式）, EDN Asia — https://www.ednasia.com/scrubbing-sram-based-fpgas-to-prevent-the-accumulation-of-seus/
[^30^]: Project Apicula（Gowin FPGA 比特流文档化，支持板卡列表）, GitHub — https://github.com/yosyshq/apicula
[^31^]: Tock RTOS 特性总览（MPU 进程隔离、64KB RAM 多租户） — https://osrtos.com/rtos/tock/
[^32^]: "Mastering Zephyr RTOS Userspace: Hardware-Enforced Memory Protection on Cortex-M"（MPU/内存域/系统调用门） — https://www.wadixtech.com/blog/zephyr-rtos-userspace-cortex-m-mpu-isolation
[^33^]: "Zephyr User Mode"（fatal handler 只杀出错线程的模式）, emlogic — https://emlogic.no/2026/05/zephyr-user-mode/
[^34^]: "TickTock: Verified Isolation in a Production Embedded OS", SOSP 2025 — https://ranjitjhala.github.io/static/sosp25-ticktock.pdf
[^35^]: Tock OS 设计文档（Capsule/Process/Grant 架构） — https://www.tockos.org/documentation/design/
[^37^]: "WebAssembly for Embedded Systems: A New Era of Cross-Platform Firmware", Promwad 2025 — https://promwad.com/news/webassembly-for-embedded-systems-cross-platform-firmware
[^38^]: Levy et al., Tock 演讲幻灯（进程开销、grant 机制数据）, Stanford — https://iot.stanford.edu/retreat18/slides/sitp18-levy.pdf
[^39^]: Tock (operating system), Wikipedia — https://en.wikipedia.org/wiki/Tock_(operating_system)
[^40^]: "Robust Design Patterns - Part 2 - Userspace Isolation"（Zephyr 内存域实践 codelab）, HEIA-FR — https://embreal.isc.heia-fr.ch/codelabs/robust-patterns-part2/
[^41^]: Levy, Tock 早期设计演讲（事件驱动内核、capsule 隔离） — https://www.amitlevy.com/talks/tock-june16.pdf
[^42^]: "TinyContainer: Container Runtime Middleware Enabling Multi-tenant Microcontrollers with Built-in Security", arXiv:2606.09225 — https://arxiv.org/html/2606.09225v1
[^43^]: "AkiraOS — WASM Runtime for Microcontrollers"（Zephyr + WAMR + Capability Guard）, Hackster 2026 — https://www.hackster.io/Artur_R0K3R/akiraos-wasm-runtime-for-microcontrollers-dcc59e

---

*本文档为 v1.0，基于 2026-07 的公开文献与生态状态撰写；建议每 6 个月随路线图评审修订。*
