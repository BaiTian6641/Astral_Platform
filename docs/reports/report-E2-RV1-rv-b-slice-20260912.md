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

- ⚠️ **无 CSR/异常/中断路径**（SYSTEM/CSR/ecall/ebreak/mret 译码到错误脉冲，不静默）；无 FPU/A/MMU/Vector；
  非对齐数据访问 → 错误脉冲；无 I/D 缓存、BTB、多 hart、CLINT/PLIC/UART MMIO；尚无轨迹口的形式化证明；
  内存访问尚未与 Spike 的 `mem` 流比对（RTL 已吐 `rvfi_mem_*`，harness 的 `Commit` 需加字段）。
- ⚠️ 与 C14 的偏差已记录：I 口为简化取指（非 AXI 突发读）——下一片切换 `eth_axi` 主口。

## 4. 下一阶段需要做的内容

- **E2-RV1 续** — CSR/trap 最小集（`mcause/mepc/mtval` + 非法指令/ecall）→ `mem` 流比对 → `eth_axi` AXI4 主口替换 → 轨迹口形式化。
- **E2-RV0 增量** — 内存访问比对（harness `Commit.mem_*` 字段）+ CSR/trap 流 + 实时锁步 stepper。
- **集成** — RV 核 + DMA + DRAM + xbar（`BURST_EN=1`）的 SoC 级多主 TB。
