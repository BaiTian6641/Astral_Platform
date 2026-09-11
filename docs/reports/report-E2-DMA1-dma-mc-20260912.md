# E2-DMA1 验收报告 — eth_dma_mc 多通道 SG DMA

- **任务**: E2-DMA1（多通道 scatter-gather DMA，AXI4 主）
- **日期**: 2026-09-12
- **状态**: **完成**（垂直切片；非目标见 §3）
- **Plan-Ref**: `ethereal-plan/subsystems/S15-应用处理器子系统.md §3`（结构参考 PULP iDMA / Xilinx AXI DMA / ZipCPU AXI DMA；~2-8K LUT）、`docs/adr/ADR-018-axi-noc-riscv-cluster.md`
- **上游**: `eth_dram_ctrl`+`eth_dram_stub`（E2-DRAM1，本 TB 的真实内存目标）、`eth_axi`（E2-AXI1）

---

## 1. 本阶段实现内容

| 文件 | 内容 |
|---|---|
| `ethereal-shell/rtl/dma/eth_dma_pkg.sv` | 描述符布局常量、`AXI_RESP_*`、`DMA_ERR_*`、CSR 映射、`dma_err_of_resp()` |
| `eth_dma_fifo.sv` | FWFT 拍缓冲（含 flush，全寄存） |
| `eth_dma_arb.sv` | 轮询仲裁器（one-hot 指针 + 最低位置 1 编码） |
| `eth_dma_axi_engine.sv` | **单未完成 AXI4 INCR 主引擎**（6 态两段式 FSM + `ifdef FORMAL` 性质块） |
| `eth_dma_channel.sv` | 描述符取/译/校验、突发分块、逐通道 CSR、错误/状态/IRQ、`CH_INDEX` 参数化 |
| `eth_dma_mc.sv` | CSR 文件 + N 通道 + FIFO + 仲裁 + 引擎 + AXI 事务归属路由 + 聚合 `irq_o` + AXI4 主口 |
| `ethereal-fabric/tests/dma/tb_eth_dma_mc.sv` | 自检 TB（DUT = 顶层，内存 = 真实 DRAM 插座；LFSR 节流背压 + 连续 AXI 协议监视器） |
| `ethereal-shell/formal/eth_dma_mc.sby` | SymbiYosys（prove + cover，top = `eth_dma_axi_engine`） |

**描述符**（32 B = 4×64 bit，32 B 对齐，一次 INCR 读突发取回）：`SRC[63:0]`、`DST[63:0]`、`NXT[63:0]`（0 = 链尾）、
`LEN[15:0]` + `SOF[16]/EOF[17]/IOC[18]`（+保留）。**v0 规则**：`LEN != 0` 且为总线字节宽的整数倍；SRC/DST 拍对齐；
NXT/链基址 32 B 对齐；违反 → `ERROR=1, ERRCODE=3`，不搬数据。突发按
`min(beats_left, FIFO_DEPTH, 256, 到 4 KiB 边界的拍数)` 分块（各自满足 SRC/DST）。

**寄存器**（4 KiB 窗口，`{block[11:6], offset[5:0]}`；block 0 = 全局，block `ch+1` = 通道 ch，64 B/通道）：
`G_CTRL.EN`、`G_STATUS{BUSY_ANY, CH_BUSY}`、`G_IRQ_STATUS`（粘滞逐通道）、`G_IRQ_EN`；
通道：`CH_CTRL{EN,START,ABORT,IRQ_CLR}`（后三者 W1P）、`CH_STATUS{BUSY,DONE,ERROR,ERRCODE,DESC_DONE,SOF,EOF,IRQ}`、
`CH_DESC_LO/HI`（链基址）、`CH_CUR_LO/HI`、`CH_XFER`、`CH_TOTAL`、`CH_ERR_LO/HI`、`CH_CFG.IRQ_EN`。
错误码：`0` 无 / `1` DECERR / `2` SLVERR（含响应 ID 不匹配）/ `3` 描述符非法 / `4` 已中止。
`ABORT`/掉 EN 在**当前 AXI 突发边界**生效（ERRCODE=4）；`IRQ_CLR` 清 DONE/ERROR/ERRCODE/SOF/EOF/IRQ 但**不清** `DESC_DONE`。

## 2. 验证（本人独立复跑）

- ✅ **TB**（文档化命令，本人复跑）：`=== checks=60 errors=0 ===  TEST PASSED`，覆盖
  ① 单通道多描述符链（逐描述符校验和比对）；② 双通道并发轮询交织（从 AXI 侧观测到两个 ID、owner 切换计数）；
  ③ 错误路径 A（链基址越界 → 描述符取回 DECERR → `ERROR/ERRCODE=1` + 故障地址，且**不挂死**）；
  ④ 错误路径 B（DST 越界 → 读成功、写 DECERR → 目标未被触碰）；⑤ 内存侧背压（LFSR 节流 + 长 RD/WR 延迟，
  统计被停顿的 beat 数）；⑥ **连续 AXI 协议监视器**（VALID 不撤回、WLAST 位置、AW/AR 单未完成、beat 计数）。
- ✅ **形式化**（本人复跑）：`sby -f ethereal-shell/formal/eth_dma_mc.sby` → `eth_dma_mc_prove DONE (PASS, rc=0)`
  （k-induction 成功）+ cover 任务。
- ✅ **lint**：`make lint` OK（6 个 DMA 模块已入 `RTL_CLEAN`，并带依赖映射）；agent 侧另在 `N_CH∈{1,3,4,8}`、`AXI_DW=32` 下 lint 干净。
- ✅ `make test-sv` 新行 `tb_eth_dma_mc` 已加入（本人按该命令行验证通过）。

## 3. 明确边界（非目标）

- ⚠️ 每通道**单未完成** AXI 事务（v0）；多未完成/重排留后续。
- ⚠️ 无 AXI4-Stream 侧、无 2D/ND-strided（属 `eth_dma_2d`，E2-DMA2）、无描述符状态回写、无循环链、`LEN > 65535` 不允许。
- ⚠️ CSR 接口为通用 valid/ready（**不含** AXI4-Lite 外壳；加壳是集成层的小任务，DMA 本身不绑定总线风味）。
- ⚠️ 与 **E2-AXI2** 的关系：DMA 的 AXI4 主口可**直连** `eth_dram_ctrl`（本 TB 即如此）；挂到 v0 xbar 之后需等突发扩展（进行中）。

## 4. 下一阶段需要做的内容

- **E2-DMA2** — `eth_dma_2d`（ND-strided + blit/fill/ROP，S15 §3）与 Service-Tile 加速器（S11）衔接。
- **E2-AXI2** — xbar 突发扩展（已在进行）→ DMA 与 DRAM 同时挂 xbar 的多主拓扑。
- **E2-RV1（RV-B）** — 前置（E2-RV0 载体 + C14 组件规范）已就绪；应用核将是 DMA 的第一个真实软件驱动方。
