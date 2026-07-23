# Ethereal Logic Platform · 实施计划文件集

> 本目录是 Ethereal Logic Platform（含 Astral 聚合线）的**可执行计划库**，供你本人与编码 Agent 直接使用。
> 配套文档：《调研与路线图 v1.0》《实施蓝图 v2.0》《蓝图修订 v2.1（BMC）》、`ethereal-tasks.yaml`（机器可读任务清单）。
> 版本：plan-v1.0 · 2026-07

## 0. 如何使用本计划库

- **按阶段推进**：`phases/phase-N-*.md` 是当前阶段的作战地图（任务、检查点、退出标准、熔断条款）；
- **按子系统执行**：`subsystems/S*.md` 是每个子系统的完整工程档案（是什么/怎么做/怎么验/会踩什么坑）；
- **机器可读任务**：`../ethereal-tasks.yaml` 与阶段文件中的任务 ID 一一对应，可直接喂给任务调度类 Agent；
- **规则先行**：任何 Agent 在任何阶段产出代码前，必须先读完本 README 的"全局实现守则"（§2）与对应子系统文件。

## 1. 文件地图

```
ethereal-plan/
├── README.md                        ← 本文件（索引 + 全局守则 + 模板）
├── phases/
│   ├── phase-0-基础设施与仿真验证.md   (M0-M2)
│   ├── phase-1-GW5最小闭环.md         (M2-M5) ★第一个对外里程碑
│   ├── phase-2-异构与双平台.md         (M5-M9)
│   ├── phase-3-服务调度与学术发布.md    (M9-M15)
│   ├── phase-4-编排与生态.md          (M15-M24)
│   └── phase-5-商业级.md              (M24+)
├── components/                      ← 组件级设计（怎么造：接口/FSM/位域/测试）
│   ├── README.md                       硬件设计三原则 + 已验证平台事实
│   ├── C01-fabric-核心单元.md
│   ├── C02-fabric-异构tile.md
│   ├── C03-OCC组件.md
│   ├── C04-EBI组件.md
│   ├── C05-BMC组件.md
│   ├── C06-IO组件.md
│   ├── C07-监控组件.md
│   ├── C11-NPU-Tiny组件.md
│   ├── C12-平台组件.md
│   ├── C13-跨平台推断策略.md      ← ADR-017（禁厂商 IP / 推断优先 / Verilator 边界）
│   └── C-soft-工具与固件组件.md
└── subsystems/
    ├── S01-Ethereal-Fabric虚拟逻辑架构.md   重要度 ★★★★★
    ├── S02-OCC与配置体系.md                重要度 ★★★★★
    ├── S03-fabric-gen与映射工具链.md        重要度 ★★★★★
    ├── S04-EBI总线与Mailbox-NoC集成.md      重要度 ★★★★★（复用你的 TinyGPU Mailbox）
    ├── S05-BMC与EMRI-mFSM.md               重要度 ★★★★★
    ├── S06-IO重定向.md                     重要度 ★★★★☆
    ├── S07-监控与健康管理.md                重要度 ★★★★☆
    ├── S08-运行时daemon与ethctl.md          重要度 ★★★★☆
    ├── S09-镜像格式与仓库.md                重要度 ★★★★☆
    ├── S10-安全子系统.md                    重要度 ★★★☆☆（v1 防事故，v3+ 防攻击）
    ├── S11-Service-Tile.md                 重要度 ★★★☆☆（Phase 3 起）
    ├── S12-平台Bring-up.md                 重要度 ★★★★★
    ├── S13-Astral聚合.md                   重要度 ★★★★☆
    └── S14-验证与CI基础设施.md              重要度 ★★★★★
```

## 2. 全局实现守则（所有阶段、所有子系统强制适用）

### 2.1 语法与代码正确性（规则 G1）

**RTL（SystemVerilog）**：全面继承 TinyGPU-FPGA 仓库的《SystemVerilog RTL Implementation Policy》，要点：

- 每个文件首行指令必须是 `` `default_nettype none ``；
- 时序逻辑只用 `always_ff` + 非阻塞赋值，且块内只做 `q <= d`；组合逻辑只用 `always_comb`/`assign` + 阻塞赋值，块顶先给默认值（杜绝锁存器）；
- FSM 必须用 `typedef enum logic [N:0]` + 两段式；`always_*` 内禁止过程式循环，结构复制用 `generate/genvar`；
- 命名：寄存器 `_r`、次态 `_nxt`、端口 `_i/_o`；数值字面量必须带位宽与进制（如 `8'hFF`）；
- 提交前必须通过：`verilator --lint-only -Wall`（零警告或逐条文档化豁免）+ Yosys 冒烟综合（`scripts/rtl_lint.sh` / `rtl_smoke_synth.sh` 同款检查纳入 CI）；
- 许可证头（SPDX）：硬件 RTL 文件 `// SPDX-License-Identifier: CERN-OHL-S-2.0`；软件文件 `// SPDX-License-Identifier: MIT`；规范文档 CC-BY-SA-4.0。

**软件（Python/C）**：Python 过 `ruff` + `mypy --strict`（CLI/工具链）；嵌入式 C 过 `-Wall -Wextra -Werror` + `clang-format`；固件禁止动态内存分配（静态池除外，需注释论证）。

### 2.2 模块 Header 标准（规则 G2）

每个 RTL 模块/软件文件都必须以标准 header 开始，**包含创建日期、模块名、模块简述**（模板直接沿用你的策略并扩展）：

```systemverilog
`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      <module_name>            ← 必须与模块名一致
// Description: <一句话简述>
// Details:     <可选：多行详述、综合注意事项、厂商原语依赖>
// Maintainer:  <姓名/ID>
// Created:     YYYY-MM-DD
// Modified:    YYYY-MM-DD - <变更简述>
// Tags:        RTL, SYNTH | TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/Sxx.md §x.y   ← 新增：回溯到计划文件
// Notes:       <lint 豁免理由 / 仿真专用代码段说明>
```

### 2.3 阶段验收报告（规则 G3）

**不论阶段大小，验收必须产出 Markdown 报告**，存放于对应仓库 `docs/reports/`，命名：`report-{任务ID或里程碑}-YYYYMMDD.md`。报告模板见 §3。

### 2.4 报告必须包含示意图（规则 G4）

报告与计划文档中的架构图**必须使用 Markdown 内嵌绘图语言**：默认 **Mermaid**（GitHub 原生渲染）；复杂时序/架构可用 **PlantUML**（与 TinyGPU-FPGA 的 `docs/diagrams/*.puml` 惯例一致）。禁止只放外部图片链接。示意图覆盖：模块结构（`flowchart`/`graph`）、状态机（`stateDiagram-v2`）、时序（`sequenceDiagram`）。

### 2.5 报告必须包含"本阶段实现/下一阶段计划"（规则 G5）

每份验收报告固定包含两节：`## 本阶段实现内容`（对照检查点逐项标记 ✅/⚠️/❌）与 `## 下一阶段需要做的内容`（任务 ID + 一句话）。未完成项必须写明原因与处置（顺延/降级/熔断）。

### 2.6 不确定性处理（规则 G6，最高优先级）

- **Agent 遇到任何不确定性（规格歧义、器件行为不明、工具链报错原因不清、两个方案都可行）时，必须停下来向用户提问，严禁盲目猜测后继续。**
- **若网络搜索工具可用，提问前必须先用搜索工具查证**；提问时附上已查到的信息与仍然不确定的点。
- 提问格式：`【问题】…【已确认的事实】…【候选方案 A/B 及各自依据】…【建议】…`。
- 所有"假设"必须以 `// ASSUMPTION: ... (待确认, YYYY-MM-DD)` 形式写入代码/文档，并在阶段报告中汇总成"待确认清单"。

### 2.7 其他通用规则

- 所有公共接口（总线、寄存器、镜像字段、协议命令）改动必须先改 `ethereal-spec` 中的规范文档并升版本号，再改实现（**规范先行**）；
- 每个任务完成后更新 `ethereal-tasks.yaml` 中对应 `status` 字段；
- 关键设计取舍必须写 ADR（`docs/adr/ADR-NNN-*.md`），不允许只留在聊天记录里。

## 3. 验收报告模板（规则 G3/G4/G5 的落地格式）

```markdown
# 验收报告：{任务ID} {任务名}
> 日期 / 执行者（人或 Agent）/ 关联计划文件 / Commit 范围

## 1. 本阶段实现内容
| 检查点 | 状态(✅/⚠️/❌) | 证据（日志/波形/CI 链接） |
（逐项列出子系统文件 §3 中该阶段的检查点）

## 2. 验证结果
（测试方法、通过数/总数、覆盖率、性能实测值 vs 目标值）

## 3. 示意图
\`\`\`mermaid
flowchart LR
    A[本阶段交付的模块] --> B[已联调的上游]
\`\`\`

## 4. 遇到的问题与解决
| 问题 | 根因 | 解决方案 | 搜索关键词（供后人） |

## 5. 待确认清单（ASSUMPTION 汇总）

## 6. 下一阶段需要做的内容
| 任务 ID | 内容 | 依赖 |
```

## 4. 关键上游依赖（实现前必读）

| 依赖 | 位置 | 用途 |
|---|---|---|
| AXI-MailboxFabric（你的 NoC） | `github.com/BaiTian6641/TinyGPU-FPGA/ip/mailbox` + `docs/docs_mailbox_interconnect_spec.md` | EBI-Lite 骨干，见 S04 |
| SPI/UART fabric 卫星适配器 | 同仓库 `ip/interface/{spi,uart}/` | 对外通道的现成参考，见 S06/S08 |
| SystemVerilog RTL Policy | 同仓库 `docs/SystemVerilog_RTL_Policy.md` | 规则 G1 的来源 |
| NEORV32 | github.com/stnolting/neorv32（BSD-3） | BMC 核，见 S05 |
| ZUMA / FABulous / VPR / OpenFPGA | 见 v2.0 蓝图参考文献 | fabric 方法学，见 S01/S03 |
| 许可证注意 | Mailbox IP 为你本人所有 | **已定稿（2026-07）**：你本人将 NoC 核及部分核心从 TinyGPU-FPGA 迁出，直接以 CERN-OHL-S-2.0 发布于 ethereal-shell，文件头注明出处 |
| HDL 风格规则 | 用户专门 Agent 产出的规则文档（待链接） | 到位前临时遵循 §2.1（TinyGPU RTL Policy）；到位后以其为唯一权威并更新本节 |
| 主验证板卡 | Tang Mega 138K **Dock**（GW5AST-LV138PG484A） | 已确认；Board Manifest 以 Dock 引脚表为准 |
| Astral 完整立项 | 延后 | 待 Ethereal 侧搭建完成后启动（S13 仅保留聚合面规划） |
