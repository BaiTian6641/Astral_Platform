# Phase 2 · 异构 Fabric v2 + IO 完整版 + Zynq 移植 + Astral 聚合 v1（M5-M9）

> 目标：fabric 长出"硬块肌肉"（MEM/DSP/SSRAM tile + 可变 region 组合），兑现跨厂商二进制兼容（GW5+Zynq 同一镜像直跑），原生 DFX 槽位并存的混合虚拟化，以及"固件容器+逻辑容器同屏"的聚合演示。四份核心规范冻结 v1.0。
> 预算：约 250~350 人时。涉及子系统：全部。

## 1. 五条工作线

### 线 A：异构 fabric（S01/S02/S03）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| A1 | MEM-T（BSRAM 包装全模式） | E2-FAB1 | AES S-box MEM 版 eLUT 降 ≥5× |
| A2 | DSP-T（27×18 MAC） | E2-FAB2 | FIR16 吞吐 ≥10× |
| A3 | SSM-T + 上下文保存 v1 | E2-FAB3 | 暂停/恢复结果一致 |
| A4 | fabric.yaml v2（异构 region+supertile） | E2-FAB4 | 混合 region 全链路 |
| A5 | 互联优化 v2（两源轨道+平台期） | E2-FAB5 | 物理 LUT -20% |
| A6 | 异构映射链 | E2-MAP1 | 含 RAM/DSP 基准 bit-true |

### 线 B：Zynq US+（S12/S05）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| B1 | `hal/xilinx_us` + BMC 同款软核移植 | E2-PLT1 | **同一 image 双平台直跑（M-S01-4）** |
| B2 | PS Linux 上位机通道 | E2-PLT1 | PS 内部通道部署 |
| B3 | 原生 DFX 槽位并存 | E2-PLT2 | overlay 容器+DFX 加速核混合 demo |

### 线 C：IO 与安全（S06/S10/S04）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| C1 | L2 代理库扩展（SPI/I²C/PWM/QEI）+ RFC-004 | E2-IO1 | 5 类代理上板；规范冻结 |
| C2 | L1 mux v2 + 时序表征 | E2-IO2 | 8 组池；频率表入 manifest |
| C3 | AXI4-Lite 桥（RD_REQ/RD_RESP） | S04-P2#1 | 随机读写+超时用例 |
| C4 | 安全 v1（强制验签+锁矩阵+能力校验） | E2-SEC1 | 未签名拒绝；越权拒绝 |

### 线 D：Profile-E 与 mFSM（S05/S12）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| D1 | mFSM（无 CPU 寄存器面） | E2-BMC1 | 上位机脚本完整部署；ethctl 无感 |
| D2 | 小器件 bring-up（目标板待定） | S12-P2#4 | Profile-E demo |
| D3 | VexRiscv 备选核（可选） | E2-BMC2 | 换核验证 |

### 线 E：聚合与规范（S13/S09/S07）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| E1 | Zephyr+WAMR + EFP 客户端库 | E2-AST1 | MCU 经 SPI 全流程 |
| E2 | Type-F 聚合演示 | E2-AST1 | **演示视频** |
| E3 | 四规范冻结（EBI/镜像/BoardManifest/EFP） | E2-DOC1 | v1.0 发布 |
| E4 | 遥测 v1 + restartPolicy + RFC-003 | S07-P2 | i2cget 温度；策略用例全过 |

## 2. 关键依赖与排序建议
A1/A2 → A4 → A6 → B1（双平台联合验收需要异构映射稳定）；C3 与 C1 并行；E1 依赖 Phase 1 的 EFP 稳定版；D 线可与 C 线并行（若有第二人）。

## 3. 退出标准与熔断

**退出**：同一 `.eth` 在 GW5 与 US+ 直接运行；异构基准达标（5×/10×）；聚合演示视频；四规范 v1.0；至少 1 名外部贡献者 PR。

**熔断**：异构映射（A6）超支 → 砍掉 DSP-T 推断（手写映射保留），MEM-T 必须保；Zynq DFX（B3）卡壳 → 原生槽位顺延 Phase 3，双平台 overlay 演示不受影响；聚合线 E 受阻 → 先出"MCU 脚本部署"降级演示，WASM 顺延。

## 4. 里程碑汇总（本阶段应达成）
M-S01-3/4、M-S02-3、M-S03-3/4、M-S04-3、M-S05-3、M-S06-2/3、M-S07-2、M-S09-2、M-S10-1、M-S12-2/3、M-S13-1、M-S14-3。

## 5. 高风险与关键词
- 异构 VPR 架构 → `VPR heterogeneous blocks architecture file`
- DFX 流程 → `Vivado DFX Controller PG374 abstract shell`
- WAMR 集成 → `wasm-micro-runtime zephyr product-mini`
- 双平台时序差异 → 虚拟 Fmax 取两平台最小公约数写入镜像元数据
