# 验收报告：E2-FAB5 — 互联 v2c 模型 + 映射工具工作流（ModelsTools）

> 日期：2026-09-02 · 执行者：Kimi K3（ModelsTools 子代理）
> Plan-Ref：`ethereal-spec/fabric/interconnect-config-v0.md` **§7 Interconnect v2c（FROZEN,
> v0.2, 2026-09-01）** · `docs/ethereal-tasks.yaml` E2-FAB5
> 输入：`docs/reports/report-E2-FAB5-interconnect-opt-20260901.md`（spike 量化证据）、
> 参考实现 `generated/icopt/route/route_check.py`（cb_div=2 路由剪枝）、
> `generated/icopt/route/iib_check.py`（IIB L1 回溯求解器）
> 范围（ownership）：`ethereal-tools/**` + 黄金 Python 模型
> （`ethereal-fabric/tests/{interconnect,clb}/{cb_model,fabric_model,clb_t_model}.py` 及其 pytest，
> 已与 RTLv2c 书面确认分工：RTL/SV TB 归 RTLv2c，Python 模型归本工作流）+
> `docs/performance-model.md` + 本报告。**未触碰** `ethereal-spec/`、根 `Makefile`、
> `docs/ethereal-tasks.yaml`、`ethereal-fabric/tests/{emri,bmc}/`、`ethereal-runtime/`、`ethereal-shell/`。

## 结论（TL;DR）

- ✅ **c432 全流程 bit-true 在 v2c 编码上达成**（E0-MAP3 4d/4e 验收路径）：
  synth→VPR fixtures→bitgen DB（v2c 类感知引脚分配）→Wilton 路由器（CB 边按 §7.1 剪枝）→
  **直接路由 256/256 向量 bit-true**；**经完整帧打包/解包路径 32/32 bit-true**
  （`test_fabric_sim.py::test_c432_bittrue` / `test_c432_bittrue_via_full_frames`）。
- ✅ **几何与 §7.4 逐数一致**：tile 548→**530 bits**（CB 18×5=90，IIB 32×5=160 计数不变，
  SB 120 不变），4×4 列 2,120 bits = **67 数据字 + 1 CRC = 68 字/帧**，镜像 272 字 = **1,088 B**；
  `frame_map.json` version→**"0.2"**、params 增 `CB_DIV: 2`；2×2_het 每列字重算为 **[26, 27]**
  （CB+SB 在每列，故 CLB/CB 收缩影响异构列）并已重新生成 tracked 产物。
- ✅ **bench flow 状态诚实变化**：pwm / crc32 维持 bit-true PASS；
  **present_round 由 xfail 翻转为 PASS**（v2c 的 don't-care 丢弃消除了 VPR 假布线需求，
  0 条簇间网 + 真空收敛；顺带暴露并修复了一个 v1.1 潜伏的 VPR buffer 吸收别名 bug）；
  **fir16 维持 xfail**（v2c 上 200 迭代仍 23 个超用节点，实测）；aes128_round 维持 xfail（过大）。
- ⚠️ **c432 收敛迭代数上升**：v2c 剪枝图 + 求解器新引脚上 seed 0 需 ~116 迭代（v1.1 ~46），
  5/5 seeds 在 300 迭代预算内全收敛（56–120，与 spike 的 route_check 预算一致），
  相关测试预算已从 100 调整为 300 并注明原因。
- ⚠️ **一处门禁失败与本工作流无关**：`make test-model` 唯一失败为
  `test_ethctl.py::test_efp_digest_sig_byte_packing_kat`（EFP/daemon 未提交工作的 KAT 失配，
  文件不在本工作流 ownership 内，HEAD 上该测试不存在）——已通过 hub 上报 Main 处理。
  本工作流全部交付物：**2,667 passed, 2 xfailed**（fir16/aes 预期 xfail）。

## 1. 本阶段实现内容

| 检查点 | 状态 | 证据 |
|---|---|---|
| 通读 spec §7 全文 + 参考实现（route_check.py / iib_check.py / RTL 原型） | ✅ | 实现逐项对齐 §7.1–§7.7 |
| `cb_model.py`：§7.1 子集-k 语义（`pool[(i%2)+2k]`、`CB_DIV` 参数、5-bit sel、k=24..31 保留值拒绝、`track_index ↔ k` 转换、blank 默认 `out_n[i%2]`） | ✅ | `test_cb_model.py`（48 项，含 Fc=0.5 均衡性 9/18、DIV=1 ≡ v1.1） |
| `clb_t_model.py`：§7.2 池重组（ext[17:0]/pad[23:18]/fb[31:24]）+ 位切片 sel 解码 + R1–R3 不变量 | ✅ | `test_clb_t_model.py`（连通性穷尽：R1 全反馈可达、R2 奇偶类、R3 每类 2 槽、blank sel=0=fb0） |
| `fabric_model.py` `_cb_edges` 奇偶剪枝（经 CB 解码天然实现 + 文档化） | ✅ | `test_fabric_model.py` 全绿（1,021 项 interconnect 套件） |
| `frame_map.py` §7.5：`sel_w = max(1,(4W/CB_DIV−1).bit_length())`=5、tile 530、67+1 字、`to_json` 0.2 + CB_DIV | ✅ | `test_frame_map.py`（328 项，含 2×2_het 810/858 bits → 26/27 字） |
| `fabric_gen.py` + 几何测试（§7.5 期望数字） | ✅ | `test_fabric_gen.py`（2×2: 34+1 字、4×4: 67+1 字、镜像 1,088 B） |
| `bitgen_route.py`：CB 可能性边按 §7.1 剪枝（`(DIR·W+t)%2 == i%2`，参考 route_check.py cb_div=2）；`cb_sel` 改存子集索引 k | ✅ | `test_bitgen_route.py`（c432 收敛 + 逐 driver→sink `route_exists` 实现性证明） |
| `bitgen_db.py`：类感知 `iib_sel_for` + §7.2 R1–R3 引脚分配求解器（移植 iib_check L1 回溯 + 真实 mapper 自由度：LUT 引脚旋转 + 簇引脚置换 + **簇引脚复制** + **don't-care 丢弃**） | ✅ | `test_bitgen.py::test_c432_iib_v2c_invariants`；c432 **9/9 tile 可行**（spike L1 口径为 8/9 —— 多出的两个真实自由度解掉了 (4,3)） |
| `bitgen_pack.py`：5-bit cb_sel + 新 IIB sel 值往返 | ✅ | `test_full_frame_roundtrip_c432`（CLB+路由逐点无损） |
| `fabric_sim.py` / `bitgen_sim.py`：CB+IIB 按新编码求值（`iib_decode` 单点真源） | ✅ | c17/c432/pwm/crc32/present_round bit-true |
| `arch_ethereal.xml` §7.6：clb fc `in_val` 1.0→**0.5**；IIB crossbar 保留为超集（注释说明 §7.2 限制由 bitgen 求解器强制） | ✅ | XML 解析校验通过；MEM_T/DSP_T fc 不动 |
| `perf_model.py` + `docs/performance-model.md` §7.7：全部数字重算，自检断言绿 | ✅ | §2.6 表；`generated/fabric_2x2_het/frame_map.json` 交叉校验 [26, 27] OK |
| 配置语义生成器 `pack_tb_frames.py`：golden 帧改 v2c 编码（cb_sel ≤ 23、k 语义、TFF 反馈 tap sel 18→0）；`gen_bmc_hello.py` occ-fabric 仅透传 hex 字，无语义烘焙，无需改动 | ✅ | 生成器冒烟：2×2 列 34+1 字、het 26/27 字（TB 侧向量由 parent 集成时经 `make test-sv` 重生成） |
| 迁移产物再生成（§7.7）：`generated/fabric_2x2_het/`、`generated/fabric_4x4/`、`frame_map_4x4.json`、`blank_4x4.hex` | ✅ | version 0.2 / CB_DIV=2 / 几何如上 |
| ruff + mypy 于改动文件 | ✅ | ruff 无新增违例（逐文件 vs HEAD 基线）；mypy 改动模块零错误（fabric_gen/bitgen_het 残留错误为 HEAD 既有） |

## 2. 验证结果

### 2.1 v2c 编码语义（模型层）

- CB（§7.1）：`clb_in[i] = pool[(i mod 2) + 2k_i]`，k∈0..23（5-bit）。每输入见 24/48 轨道
  （Fc=0.5），每轨道恰被 9/18 输入可读（均衡性有专项断言）；k=24..31 保留，
  模型 `configure` 直接 raise（MUST-NOT-PROGRAM）；`DIV=1` 与 v1.1 逐比特等价（回归守卫）。
- IIB（§7.2）：sel[4]=1 → ext `{sel[3:0], π(m)}`（π(m)=gk mod 2）；sel[4]=0 → fb `24+j`；
  blank sel=0 = fb j=0（§7.7 新空白语义，专项测试）。R1/R2/R3 在模型测试与
  c432 DB 不变量测试中双重断言。

### 2.2 帧几何（§7.4/§7.5）

| 项 | v1.1 | v2c（实测） | 证据 |
|---|---:|---:|---|
| tile 配置位 | 548 | **530** | `test_frame_map.py::test_bitfield_widths` |
| 4×4 列 / 帧 | 2,192 b / 70 字 | **2,120 b / 68 字** | 同上 |
| 4×4 镜像 | 1,120 B | **1,088 B**（272 字） | `test_fabric_gen.py::test_4x4_geometry` |
| 2×2_het 每列数据字 | [27, 28] | **[26, 27]**（810/858 bits） | `test_het_layout_geometry` + tracked json |
| 配置点/tile | 122 | 122（名不变，CB 值语义变） | `test_to_json_structure` |

### 2.3 bitgen 求解器与路由器

- **IIB 类感知引脚分配**（§7.2，bitgen_db）：每 tile 精确回溯求解 —— 每 LUT 外部网按
  奇偶类分槽（≤2/类，R3）、簇引脚预算 9/类、允许**簇引脚复制**（一网可占每类各 1 引脚，
  路由器按多 sink 自然处理，CB 全连通下合法）与 **don't-care 丢弃**（非逻辑输入引脚
  一律绑 fb0，TT 复制展开，不占类槽）。确定性（排序 + 固定选项序），不可行 tile 抛
  RuntimeError 而非产出错误配置。c432 **9/9 tile 可行**（spike L1 口径 8/9，(4,3) 由新增
  自由度解掉）。求解器预算检查曾有差拍 bug（同选项内 pins 未计入 pending），以合成
  不可行用例（5 LUT × 4 外部网）断言修复。
- **CB 路由剪枝**（§7.1，bitgen_route）：可能性图 CB 边仅保留 `(DIR_IDX[d]*W+t) mod 2 ==
  i mod 2`；`TileRoute.cb_sel` 改存子集索引 k（`k = ⌊p/2⌋`），打包/解包/应用/sim 全链路一致。
- **往返**：`full_to_frames → frames_to_db + frames_to_route` 对 c432 逐点无损
  （TT、iib_mux、sb_sel、inject、cb_sel 全等）。

### 2.4 验收交叉检查：c432 全流程 bit-true（v2c）

| 路径 | 结果 | 说明 |
|---|---|---|
| build_db → route(seed 0, ≤300 it) | **29/29 网收敛，0 超用** | ~116 迭代（v1.1 ~46；预算已对齐 spike 的 300） |
| route 可实现性 | 逐 driver→sink `route_exists` True | Option-B 证明（配置后真实 FabricGrid） |
| FabricSim 直接路由 | **256/256 向量 bit-true** | vs iverilog 黄金（独立 TB） |
| FabricSim 经完整帧（4e） | **32/32 向量 bit-true** | `full_to_frames`→解包→sim，闭环 OCC 可加载镜像 |
| 5-seed 扫描（300 it） | **5/5 收敛**（56–120 迭代） | 复测命令同 route_check 口径 |

### 2.5 bench flow 状态（test_bench_flow.py，实测 2026-09-02）

| bench | eLUT4 | v1.1 | v2c | 结论 |
|---|---:|---|---|---|
| pwm | 11 | PASS | **PASS（64/64）** | 不变 |
| crc32 | 42 | PASS | **PASS（64/64）** | 不变 |
| present_round | 128 | xfail（200it 不收敛） | **PASS（64/64）** | v2c don't-care 丢弃消假需求：0 簇间网，真空收敛；详见 §4 P2 |
| fir16 | 124 | xfail | **维持 xfail** | v2c 实测 200 迭代仍 23 超用节点（加法树拥塞），reason 已更新 |
| aes128_round | 4,779 | xfail | **维持 xfail** | 规模远超预算，未布线 |

（3 个既有 xfail 中 1 个翻转 PASS、2 个维持 —— 按任务要求如实报告。）

### 2.6 perf model 数字（§7.7，perf_model.py 自检绿）

| 项 | v1.1 | v2c |
|---|---:|---:|
| OCC 全镜像 WRITE（4×4，N=68 字/帧） | 288 cyc | **280 cyc**（5.60 µs @50 MHz） |
| 热替换 BLANK+WRITE | 576 cyc | **560 cyc**（11.20 µs） |
| 验证热替换 +READBACK | 868 cyc | **844 cyc**（16.88 µs） |
| SPI 20 MHz 位串 | 448.0 µs | **435.2 µs**（1,088 B） |
| 2×2_het 镜像 | 228 B | **220 B**（55 字） |

### 2.7 门禁

- `make test-model`：**2,667 passed, 2 xfailed（预期）**, 1 failed（外来 ethctl KAT，§4 P4）。
- ruff：改动文件相对 HEAD **零新增违例**（逐文件计数对比）。
- mypy 2.3.1（`--ignore-missing-imports --follow-imports=silent`）：全部改动模块 **0 错误**
  （`fabric_gen.py`/`bitgen_het.py` 残留 3+2 个错误为 HEAD 既有，未触碰语义）。

## 3. 总装数据流（G4，Mermaid）

```mermaid
flowchart LR
    subgraph FIX["fixtures（复用，placement 不受影响 §7.7）"]
        NET["c432.net / .place<br/>(VPR, arch fc=0.5)"] --> DB
        BLIF["c432.blif<br/>(Yosys)"] --> DB
    end
    DB["bitgen_db<br/>v2c 类感知 IIB 引脚分配<br/>R1-R3 回溯求解器<br/>+ buffer 别名规范化"]
    DB -->|iib_mux: sel=16+i/2 或 j<br/>cluster_inputs: 类合法引脚| RT
    RT["bitgen_route<br/>Wilton Fs=3 可能性图<br/>CB 边按 §7.1 剪枝 (t%2==i%2)"]
    RT -->|sb_sel / inject / cb_sel=k| PACK
    PACK["bitgen_pack<br/>full_to_frames<br/>(frame_map v0.2, 530b/tile)"]
    PACK -->|68 字/帧 × 4 列<br/>1,088 B 镜像| SIM
    SIM["fabric_sim<br/>CB 子集解码 + IIB 位切片解码<br/>Gauss-Seidel 定点"]
    GLD["iverilog 黄金<br/>c432.v 256 向量"] -.->|逐比特比对 256/256| SIM
    DB -->|po_aliases<br/>(buffer 吸收)| SIM
```

## 4. 遇到的问题（含检索关键词）

| # | 问题 | 处置 | 检索关键词 |
|---|---|---|---|
| P1 | 求解器预算差拍：选项级 pins 未计入 pending，类预算 9 被突破（合成用例 10>9 漏检） | 修复（`pending[]` 计数）+ 合成不可行用例回归断言 | `python -m pytest ethereal-tools/tools/mapper/bitgen/test_bitgen.py -k invariants` |
| P2 | **潜伏 bug（v1.1 既有）**：VPR buffer 吸收把 PO 驱动 LUT 的输出网改名为下游 buffer 别名（present_round `out[28]→sboxed[49]`），导致 ① LUT 函数被误查成 1 输入恒等 buffer ② PO 永远无法 tap。v1.1 因 present_round 仿真前就 xfail 从未暴露；v2c don't-care 丢弃使其可仿真后立即暴露 | `bitgen_db`：函数按 **atom 名**（lut 叶 block `name=`）查 BLIF；新增 `_buffer_classes`（恒等 .names 并查集）+ 需求网规范化 `canon()` + `db.po_aliases`；`fabric_sim` 经别名 tap PO。回归测试 `test_present_round_buffer_alias_resolution` | "VPR absorb_buffers packed netlist buffer renaming" |
| P3 | spec §7.7 括注 "868 cyc @ 67-word frames" 与重算口径不符：868 是 v1.1（70 字帧）旧值；按 §7.7 "recompute accordingly" 的指令，v2c（68 字帧）验证热替换 = **844 cyc** | 以重算值为准并在 `docs/performance-model.md` 内联注明该括注为陈旧值（非 spec 偏离；若 spec 编辑方希望修订括注请知会） | perf_model.py OCC hot_swap_verified |
| P4 | `test_ethctl.py::test_efp_digest_sig_byte_packing_kat` 失败（ed06… vs 161f…）：ethctl.py/test_ethctl.py 含**他人未提交的 EFP/daemon 工作**（HEAD 无此测试），不在本工作流 ownership | 已通过 hub DM 上报 Main（2026-09-02）；本工作流未触碰这两个文件 | `git diff ethereal-tools/tools/ethctl.py` |
| P5 | c432 seed 0 在 v2c 剪枝图上 100 迭代不收敛（3 超用残留） | 实测 5/5 seeds 于 300 迭代内收敛（56–120）；测试预算 100→300 并注释原因（spike route_check 本就用 300） | `test_c432_routes_conflict_free` |

## 5. ASSUMPTION 待确认清单

- **A1（G6）**：IIB 求解器启用**簇引脚复制**（一网最多占每类各 1 个簇引脚，路由器多
  sink 处理）——spec §7.2 R1–R3 未明文禁止，iib_check L1 注释列举的自由度为其子集；
  若 spec 编辑方认为复制越界，求解器退化为 L1 口径时 c432 有 1/9 tile（(4,3)）不可行，
  需回 spec 讨论（本会话内请以 hub 通知）。
- **A2（G6）**：don't-care 引脚绑 fb j=0（sel=0 = blank 默认，TT 复制展开）——功能与
  硬件均安全（§7.7 已把"空白 LUT 自读 fb0"列为正常类）；若偏好绑 ext0 请告知。
- **A3（G6）**：PO 别名 tap（`po_aliases`）假定 VPR buffer 吸收保值（恒等 buffer），
  已由 present_round 64/64 bit-true 实证；inverter 吸收（若出现）不在此机制覆盖内。
- **A4（G6）**：`make test-model` 唯一失败为外来 ethctl KAT（P4），本报告的"全绿"结论
  以本工作流文件为口径；最终门禁以 Main 集成后重跑为准。

## 6. 下一阶段需要做的内容

- **parent 集成**（E2-FAB5 总装）：RTLv2c 的 RTL/TB + 本工作流合并后重跑 `make lint` /
  `make test-model` / `make test-sv`（bmc/emri TB 由 parent 接）；`make test-sv` 会经
  `pack_tb_frames.py` 自动重生成 v2c golden 帧/BMC 镜像，无需手工干预。
- **ethctl EFP KAT**（属主：EFP/daemon 工作方）：修复 `test_efp_digest_sig_byte_packing_kat`
  或暂缓落地（P4）。
- **spec §7.7 括注修订建议**（属主：spec 编辑方）：868→844 cyc（P3）。
- **v3 候选（远期）**：fir16 的加法树拥塞在 v2c 依旧（23 超用 @200it）——长连线
  （length>1 tracks，C01 §3.4）或 arch 级 I 削减 + 重打包是下一步候选；aes128_round
  走 MEM_T S-box 异构路径（het 套件已覆盖其推断断言）。
