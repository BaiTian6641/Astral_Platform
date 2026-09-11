# E2-RV1 阶段报告 — eth_rv RV-B 首个垂直切片（真实 RTL 对 Spike 零分歧）

- **任务**: E2-RV1（RV-B 起点；180 人日量级任务的**第一个可验收切片**）
- **日期**: 2026-09-12
- **状态**: **切片达成**（4/4 语料 MATCH vs Spike）；任务本体仍在进行（CSR/trap、缓存、AXI 主口、MMU(RV-C) 等）
- **规范**: `ethereal-plan/components/C14-eth_rv-RV64核心.md`（本次新建）+ `S15 §2.2`
- **验证载体**: `ethereal-shell/verif/eth_rv/`（E2-RV0：Spike 1.1.1-dev + 语料 + 比较器）

---

## 1. 实现内容

| 文件 | 内容 |
|---|---|
| `ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv` | 常量/参数（XLEN、寄存器字段、复位 PC 等） |
| `cor_alu.sv` / `cor_muldiv.sv` / `cor_lsu.sv` / `cor_regfile.sv` / `cor_decoder.sv` | ALU、乘除（65+ 周期 start/valid 握手）、加载存储、寄存器堆（含**同拍 WB→ID 读旁路**）、译码（含压缩 C） |
| `eth_rv_core.sv` | **IF→ID→EX→MEM→WB 五级、单发射、顺序**；组合译码在 IF（静态预测器与 ID 共用一份译码器）；EX/MEM/WB→EX 前递 + 一个 load-use 气泡；重定向由"实际下一 PC ≠ 预测下一 PC 沿流水携带"导出 |
| `ethereal-shell/verif/eth_rv_core/{tb_eth_rv_core.sv, run_difftest.py}` | 集成运行器：Verilator 跑 RTL → 采集 `cycle pc rd value` 轨迹 → `rv_difftest.py` 对 Spike |

- **RVFI 轨迹口是硬约束**（C14 §5）：每退役指令一条、按序；被冲刷指令不得出现在轨迹里（用 `--fault 60:rd=3` 类注入验证过 harness 能抓）。
- 内存接口（C14 的 v0 简化，已标注为 spec gap）：I 口 = 16 bit 对齐 PC + ready + 32 bit rdata；D 口 = **64 bit 对齐拍**、
  lane-for-lane AXI4 W/WSTRB 形状（`rdata` = `addr & ~7` 的 8 字节；写按 wstrb lane 落位），LSU 负责旋转；
  两端口容忍"ready 前撤单"。换 `eth_axi` AXI4 主口时保持端口形状。

## 2. 验证（agent 证据 + 本人复跑运行器）

- ✅ **4/4 语料 MATCH Spike，0 分歧，exit 0**：`cor_alu` 221 提交（88 压缩）/`cor_mem` 169（64）/`cor_muldiv` 105（37）/`cor_model` 116（71）；
  本人复跑 `run_difftest.py` → `[rv-rtl] OK: 4 corpus program(s), MATCH vs Spike`（并另经 `rv_difftest.py --dut dump:…` CLI 逐 ELF 复现）。
- ✅ **负控（harness 抓得住）**：`--fault 12:value` → 第 12 提交值分歧精确报出；`--fault 40:pc`；`--fault 60:rd`（无写提交）→ 均在精确提交位置 FAIL。
- ✅ **差分环在 bring-up 中抓出 2 个真实 RTL 缺陷**：`cor_alu #50` 的陈旧操作数（缺寄存器写优先旁路）、`cor_mem #52`/`cor_model #82` 读到 0（D 口 lane 约定）→ 修复后全绿。
- ✅ **停顿路径**：整套语料在 `--memlat 2`（每次访问两个等待态）下仍 221/169/105/116 MATCH。
- ✅ **错误可见不静默**：`ecall` → `code=1` 且 0 提交；非对齐 `ld` → `code=2` 且故障指令不在轨迹中。
- ✅ lint：RTL 子系统 0 告警（无豁免；包参数按仓库惯例用 `-Wno-UNUSEDPARAM` 豁免，已写入 Makefile）；TB 0 告警；`ruff`/`mypy --strict` 干净。

## 3. 明确边界（本切片非目标）

- ~~⚠️ **无 CSR/异常/中断路径**（SYSTEM/CSR/ecall/ebreak/mret 译码到错误脉冲，不静默）~~ → **增量 2 已补齐**（见 §4；仍无中断/特权级切换）；
  无 I/D 缓存、BTB、多 hart、CLINT/PLIC/UART MMIO；D 口仍为简化拍接口（AXI4 主口替换属增量 3）。
  ✅ 内存访问**已与** Spike 的 `mem` 流比对（增量 2：harness `Commit` 增加 mem 字段 + 6/6 语料 memory-active MATCH）；
  轨迹口的形式化证明由增量 3 落地。
- ⚠️ 与 C14 的偏差已记录：I 口为简化取指（非 AXI 突发读）——下一片切换 `eth_axi` 主口。

## 4. 增量 2（同日完成）：内存流 DiffTest + M 模式 CSR/trap

- **内存流比对（C14 §5.2）**：轨迹格式扩展为 `cycle pc rd value [mem_addr mem_wdata [masks]]`（4 字段 = 无内存信息，
  6 = +地址/写数据，8 = +掩码；`-` 表示无访问/load/未报告）；比较覆盖地址、写数据（Spike 约定：低 `size` 字节、
  不移位）、DUT 掩码的**方向与 lane 连续性**（地址 `[2:0]`）；**无内存字段的流明确打印"memory: not provided"**，
  绝不静默通过。golden 侧从 Spike `--log-commits` 的 mem 行提取。
- **CSR/trap**：10 个 M 模式 CSR（`mstatus/misa/mie/mip/mtvec/mepc/mcause/mtval/mscratch/mhartid`）+
  `ecall`(11/0)、`ebreak`(3/pc)、非法指令(2/insn)、加载/存储非对齐(4/6/addr)、取指非对齐(0/target)；
  陷阱效果（`mepc/mcause/mtval` + `mstatus.MPIE<=MIE, MIE<=0, MPP<=M` + 重定向 `mtvec&~1`）与 `mret` 全部位精确；
  未实现 CSR 号 → 非法指令（不静默）。指令侧故障在 EX、数据侧在 MEM，**MEM 优先（旧指令先报）**；`err_o` 变为携带 `mcause` 的逐陷阱脉冲（不再锁存/停机）。
- **语料**：+`cor_csr`（140 提交，22 项 CSR 检查）、+`cor_trap`（474 提交，15 陷阱 / 33 检查）；构建改
  `-march=rv64imc_zicsr`（binutils 不再隐含 Zicsr），既有 4 程序**机器码逐字节不变**。
- **验证（本人独立复跑）**：`make verif-rv` **147 passed**（was 121）；RTL runner `--all` →
  **`OK: 6 corpus program(s), MATCH vs Spike`**，逐程序 `0 divergence` 且 `memory: active — 3/30/1/13/1/28 accesses compared`；
  `--memlat 2` 仍全绿；**负控**：`--fault 131:mem_wdata=0xdeadbeef` → 精确 commit 分歧（golden vs dut 值并排）、
  `--fault 149:mem_addr`、harness 侧 `mem_rmask/mem_wmask` 注入（方向/连续性）均被捕获；旧 `value` 注入仍生效。
  lint / ruff / mypy --strict 干净（无新增豁免）。
- **C14 待补（agent 如实列出）**：`mip` 读 0 而 Spike 读 0x80（其 CLINT 报 MTIP；`cor_csr` 只查合法访问不比值）；
  Spike 的 mem 日志无 lane 掩码（掩码比对为方向/一致性交叉检查）；无中断/特权级切换；`mtvec MODE=1` 仅存储不向量化
  （Spike 只对中断向量化）；instruction-address-misaligned 在 IALIGN=16+JALR 清 bit0 下架构不可达（作为结构守卫保留）。

## 5. 下一阶段需要做的内容

- **E2-RV1 续（增量 3+）** — `eth_axi` AXI4 主口替换（当前简化取指口）→ 轨迹口形式化（C14 §8 检查点 6）→ 缓存/BTB → 中断与特权级（RV-C 前置）。
  ✅ 增量 2 已完成：CSR/trap 最小集 + `mem` 流比对（见 §4）。
- **E2-RV0 增量** — 内存访问比对（harness `Commit.mem_*` 字段）+ CSR/trap 流 + 实时锁步 stepper。
- **集成** — RV 核 + DMA + DRAM + xbar（`BURST_EN=1`）的 SoC 级多主 TB。

## 6. 增量 3（同日完成）：RVFI 轨迹契约形式化 + D 口 AXI4 主

- **形式化（C14 §8 检查点 6）**：新增 `ethereal-shell/formal/eth_rv_core.sby`（prove depth 16 + cover depth 24，`make formal` 自动纳入）。
  性质族：**P1** `rvfi_valid` 仅对合法离开 MEM 的指令（未停顿、未陷阱、未非法）；**P2** 记录载荷即该 MEM 指令 ⇒ 被冲刷指令不可能入迹；
  **P3** 冲刷清空 ID/EX（非停顿时）与 IF/ID、陷阱清空 MEM、D 口停顿冻结 MEM 槽及其整载荷、MEM 仅由被接受的 EX 槽填充；
  **P3b** 译码互斥（非 load&store 同时，贯穿 id/ex/mem/wb）；**P4** `rvfi_order` 每记录恰好 +1（关系式、无界归纳）；
  **P5** 记录即真实发生的 D 口传输（请求驱动且被接受、地址/写掩码等于总线值、恰一方向、方向掩码为所寻址拍的合法 15 类 lane 连续运行、总线存储字节等于轨迹未移位值）；
  **P6** 写纪律（无零掩码写、掩码是所寻址拍的子集、读不写）；另 11 条 cover 全部命中。
  **本人复跑：`sby -f …` → prove `successful proof by k-induction` DONE (PASS, rc=0)**。
- **D 口 AXI4 主（C14 §4）**：新增 `eth_rv_axi_master.sv`（拍 → AXI4 INCR：单未完成、仅 INCR、`AxSIZE=log2(DW/8)`；
  存储 AW→W(单拍,WLAST)→**仅在 B 之后才应答核心**（无 posted write）；加载 AR→R 单拍或 `LINE_BEATS` 行填充 + **1 行读缓存**（被存储失效）；
  突发前做窗口检查；sticky `axi_err_o`；RLAST 兜底以免读挂死核心）。
- **端到端（本人复跑）**：`run_difftest.py --dram --quiet` → **`OK: 6 corpus program(s), MATCH vs Spike`**（memory active；cor_trap 474 提交 0 分歧）；
  AXI 侧实测流量（cor_mem 13 AR / 13 多拍突发 / 104 R / 12 AW / 12 W / 5 次行缓存命中；全套 29 次多拍突发）；`--axi-line-beats 1` 同样 6/6；
  负控在 AXI 路径上仍精确捕获（`--dram --fault 12:mem_wdata`）。
- **回归**：`make verif-rv` 147 passed；ruff/mypy 干净；lint 干净（主口在 `LINE_BEATS` 1/8/16 三档；两个 TB 构建在 warnings-fatal 下通过）。
- **工具适配（记录）**：yosys 前端不支持通配包 import（`import eth_rv_pkg::*`）与函数体内裸包名 ⇒ 改为显式 typedef/localparam 别名与 `pkg::NAME` 限定（后者与 `emri/emri_regfile.sv` 既有做法一致）。
- **C14 §8 检查点状态**：1 取指/译码 ✅、2 内存路径 ✅（含 AXI/DRAM）、3 M/C ✅、4 异常/CSR ✅、5 UART hello ⏳（需 MMIO/UART）、6 轨迹形式化 ✅（本增量）。
