# Phase 0 · 基础设施与仿真验证（M0-M2）

> 目标：不碰任何厂商工具链，在 Verilator 中跑通"生成 fabric → 映射电路 → 配置 → 运行 → 热替换"全链路。
> 预算：约 100~150 人时（单人 2~3 个月 @ 8~15h/周）。
> 涉及子系统：S01/S02/S03/S04/S14。退出标准与熔断见 §4。

## 1. 阶段作战序列（按依赖排序，每步对应检查点）

### 第 1 周：地基
| 序 | 任务 | ID | 子系统 | 检查点 |
|---|---|---|---|---|
| 1 | GitHub 组织 + 8 仓库骨架（许可证/DCO/CONTRIBUTING） | E0-INF1 | S14 | clone 后链接全有效 |
| 2 | 商标/名称可用性检查 | E0-INF4 | — | 结论文档 |
| 3 | CI 骨架（lint+cocotb+docs） | E0-INF2 | S14 | dummy 测试绿 |
| 4 | 仿真 Docker（Verilator5+cocotb+Yosys+VPR8） | E0-INF3 | S14 | 30 分钟复现 |
| 5 | Mailbox RTL 导出与移植注记 | S04-P0#1 | S04 | lint 全过；移植注记含授权说明（**需你先完成 README §4 行动项**） |

### 第 2-3 周：fabric 内核
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 6 | eLUT4+FF | E0-FAB1 | 随机真值表 1000 组 |
| 7 | CLB-T cluster | E0-FAB2 | 连通性穷举；UNOPTFLAT 零报告 |
| 8 | SB+通道互联 | E0-FAB3 | 4×4 网格例化无组合环 |
| 9 | 帧映射生成脚本 | S02-P0#1 | 抽检回读一致 |
| 10 | OCC v0（WRITE/BLANK/READBACK） | E0-FAB4 | 加法器/计数器样例配置成功 |
| 11 | blank-before-write + LOCK | E0-FAB5 | **邻区无毛刺断言**；LOCK 写被拒 |

### 第 3-4 周：工具链
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 12 | Yosys techlib | E0-MAP1 | c17/c432 映射网表 |
| 13 | VPR arch XML | E0-MAP2 | c432 完整 P&R |
| 14 | bitgen v0 | E0-MAP3 | **c432 端到端 bit-true** |
| 15 | FABulous spike → ADR-012 | E0-MAP4 | 路线决策归档 |
| 16 | 基准电路集 | E0-MAP5 | AES/PRESENT/FIR16/CRC32/PWM 全过 |

### 第 5-8 周：Shell 与总装
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 17 | EBI-Tiny + decoder | E0-SHL1 | BFM 随机读写一致 |
| 18 | Region endpoint + ABI 草案 | S04-P0#4 | CSR/DATA/DEADBEEF 语义 |
| 19 | Shell v0 总装（BMC-BFM→Center→Switch→OCC→fabric） | E0-SHL2 | **完整容器部署周期演练** |
| 20 | 性能建模 | E0-SHL3 | 配置字节数/Fmax 估算归档 |
| 21 | 双镜像热替换演示 + 报告 | — | 按 README §3 模板出 P0 验收报告（含 mermaid 图） |

## 2. 本阶段验收报告要求

按全局规则 G3-G5：报告含全部检查点状态表、验证数据、**总装架构 mermaid 图**、遇到的问题表（带搜索关键词）、ASSUMPTION 待确认清单、下阶段内容。命名 `report-phase0-YYYYMMDD.md`。

## 3. 本阶段结束时应能回答的问题（自检）
- 4×4 fabric 的配置共多少字节？热替换理论下界是多少？
- 开销比仿真估算 vs ZUMA 40:1 文献值，差距在哪？
- ADR-012 选了哪条映射路线，依据是什么？

## 4. 退出标准与熔断

**退出标准**（全满足才进 Phase 1）：仿真双镜像热替换通过；AES-128/FIR16 bit-true；ADR-012 归档；CI 全绿；P0 验收报告发布。

**熔断条款**：VPR 架构文件 2 周不收敛 → 转路线 B（FABulous/nextpnr）或自研 placer+PathFinder（各 5 人日上限），仍不行 → 固定 W=8 手工拓扑保进度，互联优化顺延。

## 5. 本阶段高风险与关键词
- 组合环（虚拟路由）→ `overlay switch box loop avoidance`
- VPR arch 合法性 → `VPR pb_type crossbar complete`
- Gowin 相关本阶段为零（纯仿真）——但 Phase 1 预备：提前装好 Gowin EDA 并跑通官方 blink 例程（不计入本阶段任务的"准备动作"）。
