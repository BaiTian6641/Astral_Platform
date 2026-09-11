# E2-SEC1b 验收报告 — region 锁矩阵（EMRI v0.8 §3.10，C03 §5）

- **任务**: E2-SEC1b（region 锁矩阵；E2-SEC1 的后续）
- **日期**: 2026-09-12
- **状态**: 规范 + daemon 生命周期面落地；RTL 面与 TB 由本批实现（见 §1.2/§1.4）
- **规范**: `ethereal-spec/control/emri-v0.md` **v0.8** §3.10（LKM_STATUS @ `0x29` / LKM_CMD @ `0x2A`）
- **Plan-Ref**: `ethereal-plan/components/C03-OCC组件.md §5`（锁矩阵设计）、`subsystems/S02-OCC与配置体系.md §2.1/§2.3`、`S10-安全子系统.md §3 Phase-1 #1`
- **验收**: 越权 region 写被拒且事件上报

---

## 1. 本阶段实现内容

### 1.1 规范（spec-first，v0.8 §3.10）

- 寄存器面：`LKM_STATUS`（R，`[7:0]` 逐区锁位 + `[8]` 全局锁）、`LKM_CMD`（W，`[3:0]` opcode
  1=lock / 2=unlock / 3=lock all / 4=unlock all，`[7:4]` = region 索引）。
- 语义（6 条规则）：锁状态**只在硬件**（OCC 列译码处的写使能门，C03 §5.1"不是软件检查，是硬件门控"）；
  锁定区的 WRITE/BLANK 被拒并报 `done_code=LOCKED(3)`（→ daemon `EFP_ERR=3 region_locked`，事件上报）；
  READBACK/心跳（只读）不受限；全局锁对每个区 OR 生效；`run/restart` 对非 FREE 区仍由分配器拒
  （`EFP_ERR=2`）——锁保护的是**任何总线主设备的裸 OCC 写**（威胁模型）；复位/abort 后全清。
- ASSUMPTION（已写入规范）：v0 EMRI 信任总线主设备；C03 §5.2 的"仅 BMC 可置/清"是 OCC 端点/HP 通道属性
  （S02 §2.3），sim 织物未建模。

### 1.2 RTL

| 文件 | 改动 |
|---|---|
| `emri_pkg.sv` | v0.8 常量：`R_LKM_STATUS` 0x29、`R_LKM_CMD` 0x2A、opcode/位域 |
| `emri_regfile.sv` | 锁寄存器（复位 0）+ LKM_CMD 译码（置/清逐区位、全局锁）+ LKM_STATUS 回读；锁位驱动 `occ_top`；LKM_CMD 读为 0 |
| `occ_top.sv` | 逐区/全局写使能门（C03 §5.1）：WRITE 与 BLANK 在锁定区被拒（`done_code=LOCKED`），READBACK 不受影响 |

### 1.3 daemon（生命周期联动，C03 §5.2"RUNNING 自动锁 / LOADING-BLANKING 解锁"）

- `lkm_lock()/lkm_unlock()` 封装（写 `LKM_CMD`），前置声明随 ctx 一起。
- `do_run` / `do_run_packed` 到达 RUNNING 时 **lock region r**；
- `do_stop` / `do_restart`（stop 半程）/ `do_abort` 在逐列 BLANK 前 **unlock**——
  否则硬件门会拒绝 BLANK（这是本次改动的关键回归面，已有 TB 全程覆盖）。
- `EFP_ERR=3 region_locked` 的映射路径（`occ_check` 读 `done_code`）沿用 E1 既有实现。

### 1.4 验证

- ✅ `make lint` → **all project RTL lint-clean**（含改动后的 `occ_top` / `emri_regfile`）。
- ✅ iverilog TB：**`tb_lock_matrix`（新）**、`tb_occ`、`tb_blank`、`tb_emri_regfile`、`tb_emri_occ_loop`、
  `tb_ctx_multiword`（FAB3b 回归）→ 全部 `TEST PASSED`（本人独立复跑）。
- ✅ `tb_lock_matrix` 覆盖：LKM_CMD lock → LKM_STATUS 逐区位；锁定区 WRITE/BLANK 被拒（`done_code=LOCKED`）
  且配置 RAM 逐字节不变；READBACK 在锁定下仍可用；unlock → 写恢复；全局锁对全区生效、opcode 4 清除。
- ✅ **BMC daemon 端到端最终判定：`exit=0`、91 ok / 0 FAIL、`TEST PASSED`**（$finish 7 s sim / 1375 s wall）——
  在锁修复 + per-frame-window 脏位修复后的**已提交状态**上跑（含全部既有阶段）。
- 📋 历史（首轮）：BMC daemon 端到端（`tb_bmc_daemon` 阶段 1d + 既有 stop/restart/abort 的"BLANK 前解锁"回归）：首轮跑出
  **真实语义缺陷**（`LKM_CMD=4` 连逐区锁一起清）→ 规范澄清为"仅清全局位"、RTL 修复（`LKM_OP_GLOBAL_CLEAR` 只动
  `global_lock_r`），失败断言即本 TB 的 `lock: global unlock leaves region 0 locked (§3.10)`；同轮其余断言全过 ——
  RUNNING 自动锁、**裸 WRITE 被硬件门拒（done_code=LOCKED(3)）且配置 RAM 逐字节不变**、全局锁置位/清位、
  锁定下 READBACK 仍可用。RTL 侧另有独立负控（把 op4 改回清全区 → `tb_lock_matrix` 在镜像位置失败）。
- ✅ RTL 回归（agent + 本人）：`tb_lock_matrix`/`tb_emri_*`/`tb_occ`/`tb_blank`/`tb_ctx_multiword`/`tb_mgmt_hotswap`/
  `shell_tb_*_packed`/`tb_bmc_axi_*` 全 PASS；`tb_occ_soak` 20000 交换零损坏；`tb_bmc_fw`、`tb_ethctl_replay`（真固件）PASS；
  `make formal` 全过（含 `emri_r_occ_decode_prove`）。
- ⚠️ 修复过程中另发现并修掉一个**既有握手死锁**：`occ_top` 在拒绝（LOCKED/NEEDS_BLANK）时从不给出 `cmd_ready`，
  单宿主端口会永久挂住 → regfile 改为在该状态释放挂起事务（`host_ready_o`/`occ_start_r` 清零），
  同时让既有的 NEEDS_BLANK→`occ_reject` 路径在寄存器 ABI 上重新可达。
- ✅ `make formal` 重跑 → **全部证明 PASS**（含受 regfile 改动影响的 `emri_r_occ_decode_prove`，
  以及 `eth_axi_xbar_prove/cover`、`eth_axi_skidbuf_prove`、`eth_wb2axi_prove`；sby 日志 `DONE (PASS, rc=0)`）。

### 1.5 未覆盖 / 明确边界

- ⚠️ "仅 BMC 可置/清"的通道仲裁未在 sim 建模（ASSUMPTION，见 §1.1 末）。
- ⚠️ 全局锁的运维流程（镜像池维护期批量锁）属 Phase-3 镜像池（E2-DRAM1/E3-REP1）联动项。

---

## 2. 下一阶段需要做的内容

- **E2-FAB2b** — DSP 原语强制映射 spike（本批并行进行）。
- **E1-DMO2c** — 多列 packed 端到端回放。
- **E2-AST1 / E3-REP1 / E2-DMA1 / E2-DRAM1 / E2-RV1** — 队列后续。
