# 验收报告：E1-PLT1 — GW5 宿主映射层 hal/gowin_gw5 + overlay 物理 LUT 开销量化

> 日期：2026-09-01 · 执行者：Kimi K3（HalGowin 子代理）
> Plan-Ref：`ethereal-plan/components/C13-跨平台推断策略.md`（ADR-017）·
> `ethereal-plan/components/C12-平台组件.md` §1/§2/§3 ·
> `docs/ethereal-tasks.yaml` E1-PLT1
> 关联：`docs/reports/report-E1-PLT4-nextpnr-spike-20260901.md`（开源链 spike，本报告开销数据的 4×4 基准与之逐数吻合）

## 结论（TL;DR）

- ✅ `ethereal-fabric/hal/gowin_gw5/` 宿主映射层落地：`glue/`（gowin_bsram / gowin_dsp / gowin_clkstub，
  全部 `ifdef GOWIN_PRIMITIVE` 双分支、默认行为级、Verilator/iverilog/yosys 三链可吃）+ `probe/` +
  `boards/tangmega138k.md` + README。**未修改任何 tracked RTL / Makefile / tasks.yaml**（hal/ 为纯增量）。
- ⚠️ **验收指标未达标（如实申报）**：acceptance 要求 4×4 fabric 综合后物理 LUT 开销 ≤45:1；
  实测 **308.4:1**（39,474 LUT 细胞 / 128 虚拟 LUT，与 E1-PLT4 spike 逐数一致）。
  逐块分解证明开销 ≈91% 来自 v1.1 互联（CB 全填充交叉开关 + Wilton SB + IIB 平铺交叉开关），
  且**不随 fabric 规模摊薄**（1×1→4×4 每 tile 成本 ~1970→2544→2802→2467，渐近 ≈310–350:1）。
  45:1 目标按 ZUMA 方法学（W≈4、subset SB、LUTRAM 配置）校准，v1.1 架构在不改互联的前提下不可达；
  处置建议见 §2.4（E2-FAB5 重定标 + 偏差签核），需维护者拍板（G6）。

## 1. 本阶段实现内容

| 检查点 | 状态 | 证据 |
|---|---|---|
| hal/gowin_gw5/glue/gowin_bsram.sv（与 eth_inf_ram 同接口，ifdef 双分支） | ✅ | 文件落地；`iverilog -g2012` 三模块联编 elab 通过；`verilator --lint-only -Wall` 零告警 |
| hal/gowin_gw5/glue/gowin_dsp.sv（与 eth_inf_dsp_mac 同接口，27×18→DSP 映射注释） | ✅ | 同上；MULT27X18+ALU54D 映射以 documentation-in-code 注释承载，lat_sel_i 无原语等价物已写明 |
| hal/gowin_gw5/glue/gowin_clkstub.sv（PLL/时钟胶合桩，Verilator 安全） | ✅ | 同上；Tang Mega 138K 晶振参数以 `// ASSUMPTION: ... (TBD, 2026-09-01)` 标注 |
| G2 文件头 + Plan-Ref（C13/C12） | ✅ | 三个 glue 文件头齐全；README/board notes 均带 Plan-Ref |
| probe/synth_stat.sh 逐模块开销普查（yosys-only） | ✅ | 实跑 3m12s；输出 `generated/hal_probe/synth_stat.{csv,md}`；4×4 与 E1-PLT4 逐数吻合 |
| 开销量化表 + 摊薄趋势 + 渐近分析 | ✅ | 见 §2.2/§2.3 |
| 验收 ≤45:1 | ❌ | 实测 308.4:1；分解 + 重定标建议见 §2.4（需维护者签核） |
| make lint 不受影响 / 不改 Makefile | ✅ | `make lint` 用显式文件清单（RTL_CLEAN），hal/ 未被 glob；glue 已按 G1 独立 lint 干净 |
| 不动 tracked RTL / tasks.yaml | ✅ | `git status` 确认 `ethereal-fabric/rtl/` 零改动；`return` 变通仅在 scratch 副本 |

## 2. 验证结果

### 2.1 glue 可仿真性（ADR-017 纪律验证）

```bash
export PATH=$HOME/oss-cad-suite/bin:$PATH
iverilog -g2012 -I ethereal-fabric/rtl/inf \
    ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv \
    ethereal-fabric/hal/gowin_gw5/glue/*.sv -o /tmp/glue_smoke.vvp     # → ELAB OK
verilator --lint-only -Wall -Iethereal-fabric/rtl/inf \
    ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv \
    ethereal-fabric/hal/gowin_gw5/glue/*.sv --top-module gowin_{bsram,dsp,clkstub}
    # → 三个 top 分别 lint，exit 0，零告警（修过 1 处 BADVLTPRAGMA 误命中 + 1 处 WIDTHEXPAND）
```

`GOWIN_PRIMITIVE` 分支按设计在 elaboration/time-0 以 `$error` 主动失败——原语参数拼写属
G6 待确认项（§5），在取得授权的 Gowin 原语仿真库核对前不允许被意外启用。

### 2.2 逐块开销普查（probe 实跑输出）

复现命令（yosys-only，无 nextpnr，总计 ~3 分钟；scratch 在 `generated/hal_probe/`）：

```bash
export PATH=$HOME/oss-cad-suite/bin:$PATH
ethereal-fabric/hal/gowin_gw5/probe/synth_stat.sh
```

`yosys synth_gowin -top <m> -family gw5a -noiopads` 的 `stat` 细胞普查
（默认参数 W=12, N=8, K=4, EXT_IN=18；fabric 为全 CLB 同质）：

| target | 虚拟 eLUT4 | LUT1-4 | MUX2_LUT5-8 | DFF（全部） | ALU | 物理:虚拟 |
|---|---|---|---|---|---|---|
| elut4（独立） | 1 | 35 | 24 | 21 | 0 | 35.0:1 |
| clb_t（独立，含 IIB） | 8 | 1,437 | 395 | 328 | 29 | 179.6:1 |
| switch_box（独立） | 0 | 346 | 80 | 120 | 19 | — |
| connection_block（独立） | 0 | 1,601 | 1,090 | 108 | 0 | — |
| occ_top（独立） | 0 | 1,567 | 868 | 70 | 53 | — |
| fabric_top 1×1 | 8 | 1,970 | 311 | 460 | 35 | 246.2:1 |
| fabric_top 2×2 | 32 | 10,177 | 1,855 | 2,224 | 75 | 318.0:1 |
| fabric_top 3×3（补充点） | 72 | 25,222 | 6,719 | 5,004 | 72 | 350.3:1 |
| fabric_top 4×4 | 128 | **39,474** | 5,020 | 8,896 | 76 | **308.4:1** |

4×4 行与 E1-PLT4 spike 报告逐数吻合（LUT1/2/3/4 = 2,932/2,648/23,597/10,297；
MUX2_LUT5/6/7/8 = 4,641/297/82/0；DFF/DFFRE = 128/8,768）——两套独立脚本互证。

**逐块成本归属**（独立综合之和，每 tile 一份 SB+CB+CLB）：

| 构成 | LUT1-4 | 占每 tile 独立和 | 说明 |
|---|---|---|---|
| eLUT4 数据通路 ×8 | 280 | 8% | 35 LUT/虚拟 LUT：真值表读 mux + FF 旁路 mux |
| CLB-T IIB 平铺交叉开关 | ≈1,157 | 34% | 1437−280；32 个 LUT 输入各接 18:1 mux |
| connection_block | 1,601 | **47%** | 18 输入 × 48 轨全填充 mux（Fc=1.0） |
| switch_box（Wilton） | 346 | 10% | 每输出 3-bit 选择 + 复用树 |
| **每 tile 独立和** | **3,384** | 100% | fabric 内跨模块优化后实测 2,467（4×4 均值） |

**每 tile 配置存储 DFF = 556**（4×4 实测 8,896/16 = 556，与独立和精确一致）：
eLUT 真值表 16×8=128 + eLUT FF 8 + CLB 输入 mux 选择 192 + SB 选择 120 + CB 选择 108。
DFF 不计入 LUT 比，但占用 GW5 CFU 的 DFF 位，是 E2-FAB5/LUTRAM 化（C13 §2.3 eth_inf_lutram）的回收对象。

### 2.3 摊薄趋势与渐近分析

| grid | tiles | 虚拟 LUT | LUT1-4 | 每 tile LUT | 物理:虚拟 |
|---|---|---|---|---|---|
| 1×1 | 1 | 8 | 1,970 | 1,970 | 246:1 |
| 2×2 | 4 | 32 | 10,177 | 2,544 | 318:1 |
| 3×3 | 9 | 72 | 25,222 | 2,802 | 350:1 |
| 4×4 | 16 | 128 | 39,474 | 2,467 | 308:1 |

结论（对"308:1 是固定开销还是随规模增长"的直接回答）：

1. **开销不是常数项，也不存在可摊薄的固定成本**：互联（SB+CB+IIB）是**每 tile 一份**的线性项，
   随 tile 数线性增长；虚拟逻辑本体（8×35=280 LUT/tile）只占零头。
2. 每 tile 成本随规模**不降**：1970→2544→2802→2467（非单调，±15% 为 abc/跨边界综合优化噪声；
   1×1 四边全接 0 使 mux 树大面积塌缩，故最小网格反而最便宜——tile 类别线性模型不成立，
   相邻 tile 间存在跨边界共享优化，4 点拟合出负的 interior 成本，已弃用该模型，仅报实测点）。
3. **渐近每 tile 比 ≈ 310–350:1**（W=12 全填充 v1.1 互联下）。4×4 的 308:1 即为代表性渐近值，
   扩大网格不会接近 45:1。

### 2.4 与验收目标的差距及处置建议（G6，需维护者决策）

- 45:1 预算核算：4×4 × ≤45:1 ⇒ 全 fabric ≤5,760 LUT（每 tile ≤360）。当前每 tile 2,467，
  需 **−85%**。这不是工程微调量级，而是**互联架构变更**量级。
- E2-FAB5 既定目标（物理 LUT −20%）若达成 ⇒ 39,474→≈31,579 ⇒ **≈247:1**——仍远高于 45:1。
  E2-FAB5 需要砍的位置（按杠杆大小排序）：
  1. **CB 稀疏化**（47% 杠杆）：Fc=1.0 全填充 → 经典 Fc≈0.2–0.3，CB 可砍 ~3–4×（VPR 文献标准做法）；
  2. **IIB 平铺交叉开关 → 部分填充/分级**（34% 杠杆）：18:1 全填充 × 32 输入是 CLB 内部第一大项；
  3. **SB Wilton 全连通 → subset/disjoint**（10% 杠杆）；
  4. 配置存储 DFF → LUTRAM（eth_inf_lutram，C13 §2.3）：不直接降 LUT 比，但回收 8,896 个 DFF 位
     并为 v2 eLUT 铺路。
- **建议（候选 A/B，G6 格式）**：
  - **A（推荐）**：v1.1 接受 308:1 为已量化基线（本报告即为"报告实际值"），E1-PLT1 验收条款
    由维护者签核偏差；≤45:1 重定标为 E2-FAB5 之后的互联 v2 验收（同时吸收 C13 §2.3 LUTRAM 化 +
    CB/SB 稀疏化），中期里程碑设为 E2-FAB5 的 −20%（≈247:1）。
  - **B**：拒绝偏差，E1-PLT1 不关闭，立即把互联 v2 提前进 Phase 1——与 phase-1 计划顺序冲突，
    且阻塞 E1-PLT2 base-image 流，不建议。
  - 依据：ZUMA ~40 LUT/vLUT 的前提（W≈4、subset SB、LUTRAM 配置存储）与 v1.1 的刻意取舍
    （W=12 Wilton 保可布线性、全填充 CB/IIB 保映射简单、DFF 配置保读回直白，C01/C13 §5）
    不同；45:1 对 v1.1 架构是校准错误而非实现缺陷。

## 3. 示意图

```mermaid
flowchart TB
    subgraph OWN["自有 RTL（ethereal-fabric/rtl，永远无厂商原语 — ADR-017）"]
        FAB["fabric_top / clb_t / mem_t / dsp_t / occ_top"]
        INF["eth_inf_* 推断模板<br/>eth_inf_ram · eth_inf_dsp_mac<br/>（行为级 + eth_config.svh 属性层）"]
        FAB --> INF
    end
    subgraph HAL["hal/gowin_gw5/（本任务交付 — 唯一允许出现厂商名的目录）"]
        direction TB
        GLUE_B["glue/gowin_bsram.sv<br/>同 eth_inf_ram 接口"]
        GLUE_D["glue/gowin_dsp.sv<br/>同 eth_inf_dsp_mac 接口"]
        GLUE_C["glue/gowin_clkstub.sv<br/>PLL/时钟桩（C12 §2 hal_pll 槽位）"]
        PRIM["`ifdef GOWIN_PRIMITIVE 分支<br/>SDPX9B / MULT27X18+ALU54D / rPLL<br/>（documentation-in-code，默认 OFF，启用即 $error）"]
        STUB["默认分支 = 行为级回退<br/>（实例化 eth_inf_* / 纯行为时钟桩）"]
        GLUE_B & GLUE_D & GLUE_C --> PRIM
        GLUE_B & GLUE_D & GLUE_C --> STUB
    end
    subgraph EDA["两条构建链"]
        OPEN["开源链：yosys synth_gowin -family gw5a<br/>→ nextpnr-himbaechel → gowin_pack（E1-PLT4 已验证）<br/>永远走默认分支（推断）"]
        GEDA["Gowin EDA 链（E1-PLT2）：GowinSynthesis<br/>默认也走推断；-DGOWIN_PRIMITIVE 仅在<br/>infer_check 报警后启用（C13 §6）"]
    end
    OWN --> HAL
    STUB --> OPEN
    STUB --> GEDA
    PRIM -.->|"G6 待确认：原语参数拼写<br/>（授权原语库核对）"| GEDA
    subgraph PROBE["probe/（测量）"]
        SS["synth_stat.sh<br/>逐模块 yosys stat 普查<br/>→ generated/hal_probe/synth_stat.csv"]
    end
    OWN -.-> SS
```

## 4. 遇到的问题与解决

| 问题 | 根因 | 解决方案 | 搜索关键词（供后人） |
|---|---|---|---|
| yosys 解析 fabric_top.sv / occ_top.sv 报 syntax error | yosys 内建 SV 前端不支持函数内 `return`（E1-PLT4 已记录，全库 2 处） | probe 脚本内 sed 生成 scratch 副本（`generated/hal_probe/src/`），并对替换命中数做断言，tracked RTL 漂移即报错退出；tracked RTL 零改动 | yosys "unexpected TOK_ID" return function |
| 逐模块 stat 日志被 9,320 条逻辑环告警淹没（spike 时 853 MB） | Wilton SB 跨 tile 组合环（v1.1 已知特性，同 verilator UNOPTFLAT） | `yosys -Q -q` + `tee -o stat/<name>.stat stat`：普查文件仅 ~500 B/模块，告警不入盘 | yosys tee -o stat found logic loop |
| 1×1 fabric 的 `chparam` 参数注入 | fabric_top 默认 R=C=4，需网格扫描 | yosys 脚本内 `chparam -set R n -set C n fabric_top` 后再 `synth_gowin -top`（1×1 零宽 TIW 实际可综合） | yosys chparam synth_gowin |
| verilator 报 BADVLTPRAGMA | glue 注释行以 "Verilator" 开头被当作 metacomment | 注释改写避开行首关键词；另修 1 处 WIDTHEXPAND（除法器计数器比较加宽度转换） | verilator BADVLTPRAGMA comment |
| tile 类别线性模型（corner/edge/interior）拟合出负 interior 成本 | 相邻 tile 跨边界共享优化破坏可加性 | 弃用该模型，报告仅列实测点 + 渐近区间，不伪造解析式 | — |

## 5. 待确认清单（ASSUMPTION 汇总，G6）

1. **E1-PLT1 验收偏差签核**：308:1 实测 vs ≤45:1 目标 —— 建议按 §2.4 方案 A 处置（维护者决策）。
2. **Tang Mega 138K Dock 主晶振频率与时钟引脚**（C12 §6 #1 同源）：`gowin_clkstub` 的
   `CLKIN_HZ=50 MHz` / `CLKOUT_HZ=100 MHz` 为占位 ASSUMPTION（TBD, 2026-09-01），阻塞
   Board Manifest 与 rPLL 分频参数。
3. **GW5A 原语拼写**：SDPX9B / MULT27X18 / ALU54D / rPLL 的参数名与编码需对照授权的
   Gowin 原语仿真库核对后方可启用 `GOWIN_PRIMITIVE` 分支（TBD, 2026-09-01）。
4. **lat_sel_i 运行时延迟抽头无原语等价物**：原语化 DSP 构建须固化 LAT 或在 fabric 侧补 mux
   （已在 gowin_dsp.sv Notes 写明）。
5. **GW5A 片内 OSC 确切频率**（救援钟，C12 §2.1）：TBD；OSC/DCS glue 模块随复位序列器任务补齐。
6. hal/ 是否纳入 `make lint` 主门禁（RTL_CLEAN 显式清单）+ C13 §4 厂商名 grep 门禁脚本：
   建议与 E0-INF2 CI 一并由维护者决定（本任务按要求未改 Makefile）。

## 6. 下一阶段需要做的内容

| 任务 ID | 内容 | 依赖 |
|---|---|---|
| E1-PLT2 | Base image 构建流（Gowin EDA 工程模板）；双链对照镜像复用 spike_top 探针 | E1-PLT1（本报告） |
| E2-FAB5 | 互联 v2：CB 稀疏化 + IIB 分级 + SB subset 化，物理 LUT −20%（本报告 §2.2 逐块分解为输入）；目标由 45:1 重定标为 ~247:1 起步 | E1-PLT1（本报告数据）+ 维护者对 §2.4 的决策 |
| C13 §6 infer_check 套件 | 把 probe/synth_stat.sh 扩展为三家工具链推断核对（BSRAM/DSP 原语计数进性能看板 S14） | E1-PLT2 |
| （新）hal glue → lint 门禁 | 维护者决策后将 hal/**/glue/*.sv 加入 RTL_CLEAN + 厂商名 grep 门禁 | E0-INF2 |
| E1-SHL*（复位序列器落地时） | 补 hal_osc / DCS 救援钟 glue（同 gowin_clkstub 模式） | 本任务 clkstub + C12 §2 |
| E1-PLT1 收尾 | tasks.yaml 状态更新 + 验收条款签核（由主 Agent / 维护者执行） | 本报告 |
