# E2-FAB3b 验收报告 — 上下文保存 v1 编排（EMRI v0.7 CTX_* + BMC 暂停/恢复）

- **任务**: E2-FAB3b（上下文保存 v1 编排；E2-FAB3 的后续）
- **日期**: 2026-09-12
- **状态**: 规范 / RTL / 固件 / 主机工具四面落地并验证（见 §1.5）
- **规范**: `ethereal-spec/control/emri-v0.md` **v0.7** §3.9 + `ethereal-spec/fabric/ctx-scan-v0.md`（管理面交叉引用）
- **Plan-Ref**: `ethereal-plan/subsystems/S02-OCC与配置体系.md`（容器暂停/恢复）、`S05-BMC与EMRI-mFSM.md §2.3`、`components/C05-BMC组件.md §3/§4`
- **上游**: E2-FAB3（扫描链 + ctx_scan 引擎）

---

## 1. 本阶段实现内容

### 1.1 规范（spec-first，v0.7）

- `CTX_CMD` @ `0x26`（W：bit0=start，bit1=mode 0=save/1=restore）、`CTX_WORDS` @ `0x27`（RW 16，0 非法）、
  `CTX_STATUS` @ `0x28`（R：`{done,busy,err}`，done/err 由下一次 CTX_CMD 写清除）。
- `EFP_CMD=8 ctx_save` / `9 ctx_restore`、`EFP_STATUS=9 PAUSED`、`EFP_ERR=13 ctx_error`。
- §3.9 语义（6 条规则）：链为 **fabric-global v0**；context 操作**不触碰配置、不 BLANK**；
  非法生命周期/words=0/引擎错误 → 13 且状态不变；PAUSED 的 stop/abort 先释放冻结再逐列 BLANK；
  PAUSED 的 restart 拒绝（状态在窗口里，不在镜像里）；窗口由引擎独占，v0 不暴露地址寄存器。
- **实现期补强**（本任务发现）：**PAUSED 期间必须保持冻结**（容器不得继续推进）——
  save 完成后 `scan_en` 保持有效直到 restore 完成。

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> VERIFY: EFP_CMD=run (1/5)
    VERIFY --> ALLOC --> BLANK --> LOAD --> READBACK --> RUNNING
    RUNNING --> PAUSED: EFP_CMD=8 ctx_save\n(冻结 + 状态存窗口)
    PAUSED --> RUNNING: EFP_CMD=9 ctx_restore\n(状态回写 + 解冻)
    RUNNING --> STOPPED: EFP_CMD=stop
    PAUSED --> STOPPED: stop (先 restore 解冻, 再逐列 BLANK)
    PAUSED --> ERROR: restart → EFP_ERR=13
```

### 1.2 RTL（`ethereal-shell/rtl/emri/`）

| 文件 | 改动 |
|---|---|
| `emri_pkg.sv` | v0.7 常量：`R_CTX_CMD/WORDS/STATUS`、`CTX_CMD_START/MODE`、`CTX_STATUS_DONE/BUSY/ERR`、`EFP_CMD_CTX_SAVE/RESTORE`、`EFP_S_PAUSED`、`EFP_ERR_CTX_ERROR` |
| `emri_regfile.sv` | 新端口 `ctx_start_o/ctx_mode_o/ctx_words_o` + `ctx_busy_i/ctx_done_i/ctx_err_i`；`CTX_WORDS` 为普通 RW（复位 0）；CTX_CMD 写→清 done/err 锁存并在 `CTX_WORDS!=0` 时脉冲 start+mode；`CTX_STATUS={err,busy,done}`。**不**实例化引擎/织物/窗口 |
| `ctx_engine_wrap.sv`（**新**） | 持有 `ctx_scan` + **PAUSED 冻结**：`scan_en_o = (eng_scan_en | armed | save-bridge) & ~restore-release`（终结周期桥接避免 save 缝隙与 restore 二次移位）；命令/状态面向 regfile，扫描链 + 窗口面向集成层 |
| `ctx_scan.sv`（**必需的最小扩展**） | 多字链 restore 字序：ST_IDLE 预载最高字，ST_SHIFT 递减取字（"element N-1 first"，spec §4）；save 路径与 W=1 行为逐位不变 |
| `tb_ctx_multiword.sv`（**新**） | R=2,C=4 → 64 位（2 字）：EMRI 复位/RW、save→busy→done 锁存、save 地址递减 1→0、窗口内容与探测到的 vff 链镜像逐位一致、**PAUSED 冻结**（scan_en 保持 + 24 周期 0 次 FF 变化）、restore 地址递减、解冻、恢复后与参考孪生织物逐周期位精确、`CTX_WORDS=0` 不启动 |
| `tb_emri_regfile.sv`（扩展） | CTX 复位值/RW/RO、start 脉冲 + mode、busy、done/err 粘滞与写清、words=0 不启动 |

- 缺陷：**多字链 restore 字序原本只对 W=1 正确**（升序取字）→ 由 `tb_ctx_multiword` 抓出并修复
  （变异实验：升序实现 → 字序断言 + 24 条位精确比对同时失败；镜像配置改为**逐 tile 非对称**，
  避免周期性镜像让错误实现因对称而蒙混）。
- 冻结缺口的变异实验：去掉 wrapper 的保持 → 4 条断言失败（含"PAUSED 期间 FF 从不变化"）。

### 1.3 固件（daemon，`ethereal-runtime/bmc-fw/`）

- `daemon.h`：`EFP_CMD_CTX_SAVE/RESTORE`、`EFP_S_PAUSED=9`、`EFP_ERR_CTX_ERROR=13`、`REGION_PAUSED` 区域态。
- `drivers/emri.h`：CTX 偏移与位域宏（0x26/0x27/0x28）。
- `daemon.c`：`ctx_chain_words()`（由 EMRI `REGION_SEL`/`REGION_INFO` 推导 `总 tile×8/32`，不再硬编码，
  并恢复宿主 REGION_SEL）；`ctx_issue()`（写 words → 脉冲 CTX_CMD → 有界轮询，失败 `fail(13)`）；
  `do_ctx_save()`（要求 RUNNING → PAUSED）/`do_ctx_restore()`（要求 PAUSED → RUNNING）；
  分发器 case 8/9；**stop/abort 对 PAUSED 先 restore 解冻再 BLANK**（§3.9 规则 4）；**PAUSED 的 restart 拒绝**（规则 5）。
- 固件 `-Wall -Wextra -Werror` 干净（12,520 B；4×4096 字 dmem 预算内）。

### 1.4 主机（`ethereal-tools/`）

- `emri_constants.py`：v0.7 偏移/位域/命令码常量（Python SoT 补齐）。
- `test_ethctl.py`：ABI 漂移测试的配对表补齐 v0.6/v0.7（`test_emri_constants_match_pkg_sv` **PASS**）。

### 1.5 验证

- ✅ `make lint`（含新模块 `ctx_engine_wrap`，deps=ctx_scan）→ **all project RTL lint-clean**。
- ✅ iverilog TB：`tb_ctx_multiword`（新，2 字链位精确）、`tb_emri_regfile`、`tb_mon_anomaly`、`tb_ctx_scan`（W=1 无回归）→ 全部 `TEST PASSED`。
- ✅ `make formal` → 3 个证明全过（含改动后的 `emri_r_occ_decode`）。
- ✅ `make test-model` → **2724 passed + 2 xfailed**（含 capcheck 27 例；ABI 漂移配对表补齐 v0.6/v0.7 后 `test_emri_constants_match_pkg_sv` 通过）。
- ✅ `ruff` + `mypy --strict` 干净（本任务触及的 Python 文件）。
- ✅ **BMC 驱动端到端**（`tb_bmc_daemon` 新阶段 1c，**83 ok / 0 FAIL / TEST PASSED**，$finish 7 s sim / 1290 s wall）：
  `ctx_save` → `st CTXSAVE r0` + `st PAUSED r0` + `EFP_STATUS=PAUSED(9)` + **512 周期冻结断言**（观测位零变化）；
  `ctx_restore` → `st CTXRESTORE r0` + `st RESUMED r0` + `EFP_STATUS=RUNNING(6)` + 恢复翻转；
  负例（RUNNING 时 restore / FREE 区 save）→ `err ctx_error` + `st ERROR` + `EFP_ERR=13`，且织物状态不变。
  - 调试记录（写进教训）：① 首轮全线 `bad_cmd` —— `generated/bmc/*.hex` 是**旧固件**（改 daemon 后必须重建并复制）；
    ② 负例首轮假失败 —— TB 的 `expect_uart` 是**严格顺序匹配**，`host_wait_idle` 只等 busy 落而不等命令被取走，
    必须有 UART 同步；③ 修复后仍差 2 字节 —— `print_err()` 漏了 13 的字符串（daemon 打 `err unknown`）→ 补齐 `ctx_error`。

### 1.6 未覆盖 / 明确边界

- ⚠️ BMC 驱动的端到端 TB 在 **1 字链**（2×2 sim fabric）上验证编排语义；**≥2 字的位精确性**由 RTL TB
  （`tb_ctx_multiword`，2 字）证明 —— 二者合起来覆盖验收"BMC 驱动 + 多字链"，但**同一测试内**的
  "BMC + 多字链"需要 ≥2 列/区的 fabric 构建（daemon 的 `DAEMON_FAB_COLS` 与区域↔列映射假设），
  已作为 E2-FAB3b 的显式遗留（见 `tasks.yaml` 注记）。
- ⚠️ `CTX_STATUS.err` 在 v0 无引擎错误源（`ctx-scan-v0` 引擎无 err 输出）：regfile 锁存输入，wrapper 恒 0；
  spec 未发明错误码，拒绝语义由 daemon 承担。
- ⚠️ 上下文窗口的**真实 SSRAM/BSRAM 映射**仍是 C02 §3 ASSUMPTION #1（sim 用行为 RAM）。
- ⚠️ 跨时钟域/电源域的真实暂停（时钟门控/隔离）属 hal/glue（ASSUMPTION，未在 sim 范围）。

---

## 2. 下一阶段需要做的内容

- **E2-FAB3b 遗留** — "BMC + ≥2 字链"单测：扩到 ≥2 列/区的构建（含 daemon 区域↔列映射参数化）。
- **E2-FAB2b** — GW5A DSP 原语强制映射（本轮实测 Fmax 为 LUT 映射下界，见 `report-E2-FAB2-fmax-20260912`）。
- **E2-SEC1b** — region 锁矩阵 RTL（S02 §2.3 / C03 §5）。
- **E1-DMO2c** — 多列 packed 端到端回放。
- 队列后续：E2-AST1 / E3-REP1 / E2-DMA1 / E2-DRAM1 / E2-RV1。
