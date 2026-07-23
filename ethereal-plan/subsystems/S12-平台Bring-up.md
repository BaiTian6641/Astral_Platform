# S12 · 平台 Bring-up（GW5 / Zynq US+ / Profile-E）

> | 属性 | 值 |
> |---|---|
> | 仓库 | ethereal-shell（board 支持包）/ ethereal-fabric（HAL） |
> | 许可证 | CERN-OHL-S-2.0 |
> | 重要度 | ★★★★★（一切仿真的终点是硬件） |
> | 关联 | ADR-003/011；任务 E1-PLT1/2/4、E2-PLT1/2、E2-BMC1；上游 Gowin EDA、Apicula、AMD DFX 文档 |

## 1. 是什么 / 做什么 / 重要度

把仿真验证过的平台落到三块物理形态：
- **Profile-G**：Gowin GW5AST-138（Tang Mega 138K，主战场）；
- **Profile-Z**：Zynq UltraScale+（双路线：overlay + 原生 DFX 槽位并存）；
- **Profile-E**：小器件（mFSM）+ 外挂 MCU。

工作内容包括：HAL 原语映射、base image 构建流、板级描述（Board Manifest）、时钟/复位/引脚约束、上板调试。

**为什么重要**：FPGA 项目 80% 的"惊喜"发生在从仿真到硬件的跨越。本子系统把每块板的踩坑沉淀为可复用的 BSP（板级支持包），也是社区第三方板卡适配的模板。

## 2. 大体规划

### 2.1 各 Profile 要点

| | Profile-G（GW5AST-138） | Profile-Z（Zynq US+） | Profile-E（小器件+MCU） |
|---|---|---|---|
| 管理 | BMC 软核 | BMC 软核（PL 内）+ PS 可选上位机 | mFSM，策略在外挂 MCU |
| Base 构建 | Gowin EDA（脚本化）/ Apicula 备选 | Vivado 工程 + DFX 流程（原生槽位） | Gowin EDA / nextpnr |
| 时钟 | 板载晶振→PLL（12 PLL 可用）；fabric/EBI/IO 域分离 | PS 供时钟 + PL MMCM | 同 G |
| 存储 | BSRAM + SSRAM；DDR3 评估（Gowin MIP，P3） | PS DDR + PL BSRAM | MCU Flash |
| 通道 | SPI+I²C 对外 | 同左 + PS 内部通道 | SPI+I²C 直连 MCU |
| 特殊 | SerDes/PCIe 硬核（P3+ IO 服务化） | DFX Controller、SEM、SYSMON | 无 |

### 2.2 Base image 构建流（通用）
`fabric.yaml → fabric-gen → fabric RTL + Shell RTL 合并 → 厂商 P&R（约束模板）→ base bitstream + frame_map.json + Board Manifest 校验`。构建全部脚本化，产出物带版本戳。

## 3. 详细规划与阶段检查点

### Phase 1（Profile-G）
| # | 步骤（任务 ID） | 检查点 |
|---|---|---|
| 1 | `hal/gowin_gw5`（E1-PLT1） | CFU memory 模式/BSRAM/DSP 推断正确（综合报告原语核对）；开销比报告 |
| 2 | Base 构建流（E1-PLT2） | 脚本一键构建；烧写后 SPI 读 Shell magic |
| 3 | 约束模板（引脚/时钟/时序） | 时序收敛报告归档（WNS≥0） |
| 4 | Apicula 备选链评估（E1-PLT4） | 可行性结论（CI 通道） |
| 5 | 上板调试全链路（与 S04/S05 联合） | 三演示镜像运行；10k 热替换（E1-DMO2） |

### Phase 2
| # | 步骤 | 检查点 |
|---|---|---|
| 1 | `hal/xilinx_us`（E2-PLT1） | LUTRAM/BRAM36/DSP48E2 映射；**同一镜像双平台直跑（M-S01-4 联合）** |
| 2 | Zynq PS 上位机通道（Linux UIO/mmap） | PS 经内部通道部署容器 |
| 3 | 原生 DFX 槽位并存（E2-PLT2） | overlay 容器 + DFX 加速核混合运行 demo |
| 4 | mFSM 小器件 bring-up（E2-BMC1 联合，目标板待定） | Profile-E 完整部署 demo |

### Phase 3+
- Tang Mega DDR3 接入（镜像池扩容）；GW5 SerDes/PCIe 服务化评估；Zynq SEM/SYSMON 深度集成（S07）；第三方板卡适配指南（GW2A/Artix-7/ECP5 社区目标）。

## 4. 验证与里程碑验收

**方法**：逐层 bring-up（时钟/复位→CSR→通道→OCC→fabric→IO）每层留测试点 → 上板回归套件（与仿真同一测试向量）→ 环境压力（温度/电压边角，有条件则做）。

| 里程碑 | 验收标准 |
|---|---|
| M-S12-1（P1） | Profile-G 全链路 + v0.1.0 发布（E1-DMO3 联合） |
| M-S12-2（P2） | Profile-Z 双路线并存 demo；二进制兼容联合验收 |
| M-S12-3（P2） | Profile-E demo |
| M-S12-4（P3+） | 第三方板卡适配指南发布 |

## 5. 可能的问题与快速查找关键词

| 问题 | 症状 | 搜索关键词 |
|---|---|---|
| Gowin EDA 脚本化构建 | GUI 依赖 | `Gowin gw_sh tcl command line build`、`Gowin EDA batch mode` |
| Tang Mega 138K DDR3 | 控制器配置复杂 | `Tang Mega 138K DDR3 Gowin MIP example`、`GW5A DDR3 Memory Interface` |
| Apicula GW5 支持缺口 | 某原语不支持 | `project apicula GW5 issue`、`nextpnr himbaechel gowin` |
| Zynq DFX 流程坑 | PR 报错 | `UltraScale DFX Controller PG374`、`Vivado abstract shell tutorial` |
| 时钟域划分 | 跨域亚稳态 | `FPGA clock domain crossing FIFO`；约束模板内置 CDC 约束 |
| 板级供电/散热（大 fabric 满载） | 掉压复位 | `Tang Mega 138K power consumption`；监控联动（S07） |

## 6. 实现守则速查
见 `../README.md` §2。每块板的 BSP 必须含：约束文件、Board Manifest、bring-up 检查清单（按本文件 §3 格式）、已知问题列表。

## 7. 不确定时需向用户确认的问题
1. 你的 Zynq US+ 具体板卡型号（决定约束与 DFX 槽位规划）？
2. Tang Mega 138K 是 Dock 还是 Pro 版本（Board Manifest 引脚表）？
3. Profile-E 首块小器件目标（GW5AT-15？GW2A-18？还是手头的其他板子）？
