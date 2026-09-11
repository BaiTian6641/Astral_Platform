# E1-DMO1 — Signed demo .eth images through the production toolchain (sim v0)

- **Date**: 2026-09-02 (work executed 2026-09-08; **closed 2026-09-11** — the open defect was a `bitgen_db` FF-view name drift, fixed and re-verified below) · **Status**: ✅ closed (sim v0)
- **Plan-Ref**: ethereal-plan (E1-DMO1 demo images); emri-v0.md §3.3 (run_packed)
- **Scope**: `ethereal-images/**`, `ethereal-tools/tools/mapper/**` (bitgen_db / fabric_sim / bench_golden / demo_images 新增), no RTL/firmware/daemon changes.

## 交付物（在树中）

| 文件 | 说明 |
|---|---|
| `ethereal-images/demos/pwm.eth` | 签名镜像：pwm，11 eLUT，target `fabric_2x2` |
| `ethereal-images/demos/uart_loopback.eth` | 签名镜像：uart_loopback，77 eLUT，target `fabric_4x4` |
| `ethereal-images/benchmarks/uart_loopback.v` | 重构后的顺序 benchmark（marker-walk RX + 折叠停止位，见下） |
| `ethereal-tools/tools/mapper/bitgen/demo_images.py` | 全流程构建器（synth→VPR→DB→PathFinder→帧打包→ethimg 签名→run_packed session） |
| `ethereal-tools/tools/mapper/bitgen/test_demo_images.py` | 验收测试（6 项全过：tick 位真 + 语义解码 + 签名 + session 契约） |
| `generated/ethctl/session_run_packed_{pwm,uart_loopback}.json` | EFP session（ethereal.efp-session.v0，tb_ethctl_replay 行解析器契约已测） |

## 尺寸表（实测，synth_ethereal dffunmap 流程 + VPR pack）

| 镜像 | eLUT4 | FF | 原始形态 | 收缩后 | 最小可容纳描述符（2 的幂行数） |
|---|---|---|---|---|---|
| pwm | 11 | 0 | — | — | **fabric_2x2**（2×2=32 eLUT，2 列×34 DATA 词/列） |
| uart_loopback | **77** | 38 | 89 eLUT（4 状态/侧 + 3 位 bit 计数器） | 77（marker-walk RX、RX 折叠为 1 位状态、双侧停止位折叠；TX 保留 3 位计数器，见下） | **fabric_4x4**（4×4=128 eLUT，4 行列=67 DATA 词/列；占 60%） |

**2×4（64 eLUT）在硬件波特率下不可达**：CLKS_PER_BIT=87（10.0056 MHz/115200，header 契约"hardware builds the real one"）要求两个 7 位时基计数器 ≈38 eLUT + 移位数据通路 ≈24 + FSM/胶合 ≈10，结构性下限 ~74。参数扫描实测（marker 变体）：CPB=87→77、CPB=64→68、CPB=43→71、CPB=16→64（恰好压线且 100% 填充必堵死 v2c 剪枝布线）。故按"最小可容纳"规则上浮到 4×4（4 行列几何与 2×4 相同，均为 67 DATA 词/列）；未新建 fabric_2x4.yaml（无消费者）。降低 CPB 会破坏 header 的硬件参数契约，未采纳。

## TX marker 不可行性（设计发现，写入 benchmark header）

RX marker（领先数据一个移位、停靠在数据静止层之下的 s[1]/s[2]）对全部字节值可证无碰撞；TX marker 必然**尾随**数据，任何静态抽头在早期边界都可能与数据位碰撞（实测 0xA7 的 bit1 假触发第 8 位检测）——尾随 marker 无法无歧义地计数 8 个发送边界，TX 保留 3 位 bit 计数器（+~4 eLUT）。

## 布线（PathFinder，v2c 剪枝 CB）

uart 的 VPR 默认（seed=1）布局在标准参数（max_iters=200, seed=0）下过用 7 节点不收敛；**VPR 放置种子扫描**：seed∈{3,5,6,8} 全部收敛（15–17 s），seed 3 已固化进 `demo_images.ensure_flow`。pwm 不敏感（默认 seed 1）。

## 位真验证证据

- **pwm ✅**：完整帧路径（`full frames → frames_to_db/frames_to_route`（CRC 校验）→ 网名重挂 → fabric_2x2 网格 FabricSim）× 64 随机向量 vs iverilog golden，0 不匹配；且已发布 `.eth` 内 frames 成员与流程输出逐词相同（`test_pwm_bittrue_fullframe`）。
- **uart_loopback ✅（2026-09-11 修复闭合）**：golden 与 tick 模型全程 **6873 周期零分歧**（tick 1001 TX 起始位沿正确），语义解码 = [0x55, 0x00, 0xFF, 0xA7, 0x3C, 0xC3]（帧错误 0x5A 正确丢弃）。**根因（并非 tick 模型）**：`bitgen_db._tile_output_nets()`（构造 `driven` 集供 buffer-alias `canon` 使用）仍取 LUT 叶输出网（D 侧），而 `_build_tile` pass 1 已切换为 FF Q 侧 → 命名漂移。uart 的 `.latch rxs[1]` 在 BLIF 中驱动 identity buffer `rx_stop`，VPR 吸收该 buffer 后把 FF 的 Q 端口命名为 `rx_stop`，而 5 个消费者 LUT 仍引用 `rxs[1]` → `canon` 无法归一 → 这 5 个 cluster input 被误分类为 primary_in 并**静默不布线**（读默认轨道）→ 顺序逻辑错误（首个状态分歧 tick 914 = 标记位 rxs[1] 丢失）。修复后 unrouted=0（was 5）。
- **签名 ✅**：两镜像 `ethimg.verify` 通过 **daemon keyring.h 原始 32 字节公钥**（SPKI 重建；与固件验证的信任锚一致）。manifest digest：pwm `e8cf0ccd10c72080…`、uart `e355fb359f6fe26e…`（ethimg `created` 时间戳使 digest 逐次构建可变——测试只比对确定性的 frames 成员）。
- **session JSON ✅**：op 行 `{"op":"` 标记 + `0x` 词法（短地址/8 位十六进制值）符合 tb_ethctl_replay 扫描器；stream op 数=列数、每列 67/34 词、EFP_IMG_WORDS=每列 DATA 词数（emri-v0 §3.3）均断言通过。

## 工具链修复（本阶段落地）

1. **bitgen_db 顺序设计潜在 bug（重大）**：`cluster_outputs[gi]` 原取 LUT 叶输出网（D 侧），FF 承载 fle 的物理输出是 **Q 侧**（如 `.latch $0\tx[0:0] tx`）——Q 网在反馈/布线/PO 抽头中全部错位（被误分类为 primary_in）。已改为 ff_used 时取 `ff[0]/Q` 网名。此前全组合 benchmark 集不可见此 bug。
2. **fabric_sim tick 模型（新增）**：`evaluate(ff_state=…)`、`clb_ff_next`（镜像 elut4.sv `vff_r <= comb_out`，cfg_ce 恒 1）、`FabricSim.tick()`（先取 D、推进状态、再以后沿状态读 PO——与逐周期 golden TB 采样对齐）。
3. **bench_golden.golden_seq（新增）**：逐周期 golden（negedge 施加、posedge 后 #1 采样、20 ns 时钟、ROM 不越界）。
4. synth_ethereal dffunmap 修复（前一代理已落树，本阶段复验：uart 89 eLUT 含 45 $_DFF_P_）。
5. **`_tile_output_nets` ↔ `_build_tile` 漂移（2026-09-11，上条 1 的完成件、本缺陷根因）**：抽出单一事实源 `_fle_out_net()`（组合 fle = LUT 叶输出；FF fle = Q 侧）供两处共用，`driven` 集与 tile 输出从此同名；`pin_logpos` 改用 demand 记录的位次（不再对原始 `input_list` 用 `.index()`，对 canonical 化后的网名会失配）。
6. **测试侧（2026-09-11）**：`_decode_uart` 改为起始位下降沿锚定 + 数据位中心采样（原实现早采样 1 位、帧步进多 0.5 位，从未被执行到）；`_uart_streams` 尾空闲 3*cpb→10*cpb（末字节回显需要完整 10 位帧，原流在回显中途截断）。

## AES-128 递延（既有结论，维持）

aes128_round 同构实现 4779 eLUT（256 项 S-box 在 `abc -lut 4` 下爆炸为随机逻辑），远超 sim 可行规模；异构 MEM-T 路径缺少已布线的操作数端口。两条解锁路径：**(a)** C02 异构流（$mem_v2 S-box → MEM-T，实测 eLUT ≥5× 下降）打通 mem_t 操作数布线；**(b)** LUT-ROM 识别进 abc 映射（Yosys `memory -rom` + LUT 打包专门化）。

## 本阶段实现内容

- ✅ uart_loopback 实测尺寸（89→77 eLUT）与 2×4 不可达论证（参数扫描入报告）
- ✅ 描述符选型：pwm→fabric_2x2（既有）、uart→fabric_4x4（既有）；未新增无消费者的 fabric_2x4.yaml
- ✅ 全流程：synth→VPR(种子固化)→build_db→PathFinder(标准参数收敛)→目标几何帧打包（bbox 归一 + 空白填充）
- ✅ 两枚 .eth 经 ethimg pack + KEY_SEED 签名，**daemon keyring 原始公钥 verify OK**
- ✅ pwm ≥64 随机向量**完整帧路径**位真（fabric_2x2 描述符几何）
- ✅ run_packed session JSON（×2）符合 tb_ethctl_replay 契约
- ✅ uart_loopback ≥3 字节流 tick 位真（2026-09-11 修复后）：6873 周期零分歧 + 全 6 字节语义解码；根因 = bitgen_db FF-Q 视图漂移（5 输入静默未布线），见"工具链修复" #5/#6
- ✅ 回归（2026-09-11）：test_demo_images 6/6、test_bitgen 16/16、test_bench_flow 10 pass + 2 xfail、ruff clean、make lint OK（RTL 未改动）

## 下一阶段需要做的内容

- ✅ E1-DMO1b 已闭合（2026-09-11）：根因与修复见"工具链修复" #5/#6，回归全绿；本报告修订后进入提交
- E1-DMO2：轮换 TB 在 4×4 fabric 实例上回放 `session_run_packed_uart_loopback.json`（4 列 ≥ daemon 2 列区域表，需 NUM_REGIONS=4 实例）
- C02/E2：AES-128 解锁路径（见递延节）

## 待确认（G6 汇总）

- ✅ 已确认：帧不载网名（既有约定）不是本缺陷根因；真实根因是 bitgen_db 的 FF-Q 视图漂移（已修复并回归）。
- fabric_4x4.yaml 的 `n_regions: 1` 与 v0 region↔column（4 列=4 区域）不一致，本切片按 daemon 侧 num_regions=4 发 session；描述符元数据是否补齐待维护者定夺。
