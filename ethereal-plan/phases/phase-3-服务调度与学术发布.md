# Phase 3 · Service Tile + 调度 + 安全 v2 + 镜像仓库 + 学术发布（M9-M15）

> 目标：平台从"能用"到"好用到有深度"：NPU-Tiny 上线、配置调度（预取/缓存）、容器迁移与抢占、L3 静态安全检查、OCI 镜像仓库、SEU 擦洗（Zynq）、论文投稿。
> 预算：约 300~400 人时。涉及子系统：S11/S02/S05/S08/S09/S10/S07/S03。

## 1. 工作线（里程碑级）

### 线 A：Service Tile（S11）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| A1 | NPU-Tiny RTL（8×8 INT8 systolic） | E3-SVC1 | GEMM bit-true；≥0.5 GOPS |
| A2 | 服务注册/发现 + 多容器复用 | E3-SVC2 | `ethctl services`；无状态泄漏 |
| A3 | KWS demo | E3-SVC1 | 实时关键词唤醒 |

### 线 B：调度与迁移（S02/S05/S08）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| B1 | 配置调度器（分组/预取/DDR 缓存） | E3-SCH1 | 冷启动 P50 < 100 ms |
| B2 | 容器迁移/抢占 + 碎片整理 v1 | E3-SCH2 | region 间迁移演示 |
| B3 | 配置压缩（RLE/空帧跳过，若未提前） | S02-P3 | SPI 通道时间再降 50%+ |

### 线 C：安全与可靠性（S10/S07）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| C1 | L3 静态检查器（环振/短路扫描） | E3-SEC2 | 恶意样本检出率/误报率报告 |
| C2 | Zynq SEM 擦洗 | E3-MON1 | SEU 注入自动修复演示 |
| C3 | 监控 v2（历史/统计/CSV 导出） | S07-P3#2 | 报告发布 |

### 线 D：生态与学术（S09/S03/S14）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| D1 | OCI 仓库 + 索引服务 | E3-REP1 | push/pull GitHub Packages 实测 |
| D2 | 论文《Ethereal Fabric…》投 FPL/FCCM/TRETS | E3-PUB1 | 投稿完成 |
| D3 | 形式化验证试点（SymbiYosys：OCC/mailbox 属性） | S14-P3 | 试点报告 |
| D4 | 时序反标 + 增量映射 | S03-P3 | STA 精度改善报告 |

## 2. 论文素材清单（D2 的弹药）
- 异构 tile + 可变 region 组成（vs ZUMA 均质）；
- 容器生命周期硬件状态机（vs Coyote 数据中心定位）；
- 二进制兼容实测（同一镜像 Gowin+Zynq）；
- 开销比/Fmax/部署时间全数据表（诚实是卖点）；
- Mailbox NoC 作为控制面的工程实践。

## 3. 退出标准与熔断

**退出**：NPU demo + 迁移演示 + OCI 仓库 + 论文投稿 + 安全报告，四项全达。
**熔断**：NPU 时序不达标 → 4×4 阵列降级发布；论文 deadline 冲突 → 保 demo，论文顺延一个会议周期；L3 误报率失控 → 默认关闭改为 opt-in。

## 4. 高风险与关键词
- systolic 时序 → `systolic array FPGA pipelining timing`
- SEM 流程 → `Xilinx SEM IP UltraScale PG187`
- 形式化 → `SymbiYosys AXI stream formal verification`
- OCI artifact → `oras custom media type`
