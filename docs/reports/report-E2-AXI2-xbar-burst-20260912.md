# E2-AXI2 验收报告 — eth_axi_xbar v0.1 突发扩展

- **任务**: E2-AXI2（由 E2-DRAM1 暴露：v0 xbar 无突发端口，DRAM 插座接不到 xbar 之后）
- **日期**: 2026-09-12
- **状态**: **完成**（`BURST_EN` 编译期参数：默认 0 = v0 单拍契约逐位不变；1 = 突发路由）
- **规范**: `ethereal-spec/control/eth-axi-v0.md` §5.2 修订文本见 `local://axi2-notes.md §4`（父侧并入）
- **Plan-Ref**: `docs/adr/ADR-018-axi-noc-riscv-cluster.md §2`、`S15 §3/§4`

---

## 1. 实现内容（`ethereal-shell/rtl/axi/eth_axi_xbar.sv`）

- 新参数 **`BURST_EN`**（默认 0 → 既有用户**逐位不变**）；新端口：主侧 `s_awlen/awsize/awburst/wlast/arlen/arsize/arburst` + `s_rlast`，
  从侧 `m_awlen/awsize/awburst/wlast/arlen/arsize/arburst` + `m_rlast`。
- **突发形状随 skid 载荷**（捕获侧 + 从侧）：W 载荷 `{data,strb,last}`、R 载荷 `{rid,rdata,rresp,rlast}`。
- 每主 beat 计数 `wr_len/wr_cnt/rd_len/rd_cnt`；末拍 = `captured_LAST | (cnt == captured AxLEN)`，
  与 `eth_dram_stub` 的容错一致 ⇒ 缺失/提前 LAST 既不会挂死也不会截断。
- **锁步语义跨整突发**：`wr_busy[d]` 保持到 B、`rd_busy[d]` 保持到该突发的 LAST R 拍 ⇒ (U)/(C)/(O) 不变式在突发中途仍成立。
- DECERR 错误从机吞掉整突发 W 拍并仍只回 1 个 R 拍（`RDATA=0, RLAST=1`）；不做重编码（WRAP/FIXED/非法 SIZE 转发，由内存从机回 SLVERR）。

## 2. 验证（本人独立复跑）

- ✅ **新 TB `tb_axi_xbar_burst.sv`**：`TEST PASSED … (2813 checks, 0 errors)` ✔ —— 256 拍全窗口 sweep 经 xbar 回读 == 参考内存；
  INCR len{0,1,3,7,15,63}×size{0..3} + 非对齐起始；逐拍 RDATA/RRESP/RLAST/RID + BRESP/BID 与**直连** DRAM 插座基线一致；
  双向背压；DECERR 写/读、WRAP SLVERR、4 KiB 跨界 SLVERR 与基线一致；**双主并发突发**写同一 DRAM 窗口。
- ✅ **非空洞性**（TB 变异）：`m_awlen` 置 0 → 看门狗 FAIL；`m_wstrb` 全 1 → 28 errors；`m_arlen` 置 0 → 29 errors。
- ✅ **既有回归**：`tb_axi_xbar`（v0，未改动）PASS；`tb_bmc_axi_xbar`（真 NEORV32 → XBUS → wb2axi → xbar → 2 个 lite 从机）PASS。
- ✅ **形式化** `sby -f ethereal-shell/formal/eth_axi_xbar.sby`：**prove PASS**（basecase 40 步 + k-induction，6m29）+
  **cover PASS**（11/11 见证）—— 套件升级：`chparam BURST_EN=1`、新增 (B) 族 `wr_cnt<=wr_len`/`rd_cnt<=rd_len`、
  影子计数 2→10 bit（256 拍会回绕并破坏 m_valid 顺序假设）、环境假设扩展、4 个新突发见证。
- ✅ lint：0 告警（含 `-GBURST_EN=1`）。

## 3. 发现与边界

- ⚠️ 原 cover 任务有两个见证写成 `wr_cnt[0]`/`rd_cnt[0]`（扁平 `N_MST*8` 向量的第 0 位，而非 master 0 的字节字段）→
  不可达导致 cover FAIL；已改为 `wr_cnt[0*8 +: 8] != 0` 形式（agent 主动报告并修复）。
- ⚠️ `tb_bmc_axi_fabric.sv` **不是** xbar 的 TB（它是 BMC→EMRI→OCC→fabric 链路）；xbar 的 TB 是 `tests/axi/tb_axi_xbar.sv`（v0）与新 `tb_axi_xbar_burst.sv`。
- ⚠️ 非目标：多未完成/重排（v0 单未完成模型保持）、QoS/ID 扩展。

## 4. 下一阶段需要做的内容

- **集成收尾** — 把 `eth_axi_xbar`（`BURST_EN=1`）+ `eth_dram_ctrl` + `eth_dma_mc` 组成多主拓扑的 SoC 级 TB（当前 DMA 与 DRAM 各自直连）。
- **E2-RV1** — RV-B 核的 AXI4 主口接入该拓扑（当前核用简化端口，见 C14/E2-RV1 报告）。
