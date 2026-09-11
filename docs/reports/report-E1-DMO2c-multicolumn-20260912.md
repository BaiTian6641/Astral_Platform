# E1-DMO2c 验收报告 — 多列 packed 部署端到端（2 列）

- **任务**: E1-DMO2c（E1-DMO2b 的验收遗留：真实 daemon 路径上的 ≥2 列 packed 部署）
- **日期**: 2026-09-12
- **状态**: **完成**（`tb_bmc_daemon_packed` 56 ok / 0 fail，基线 25；本人独立复跑通过）
- **Plan-Ref**: `ethereal-plan/subsystems/S02-OCC与配置体系.md §2.3/§3`、`S05 §2.3`、`S09`（镜像五件套）
- **规范**: `ethereal-spec/control/emri-v0.md` v0.6 §2/§3.3（+ 本次修正的 §3.1 脏位措辞）

---

## 1. 实现内容

| 文件 | 内容 |
|---|---|
| `ethereal-tools/tools/pack_tb_frames.py` | 镜像 C：`img_c_col0`（tile(row0,col0) eLUT0 的 TFF）+ `img_c_col1`（tile(row0,col1) eLUT0 的 const-1）+ 清单块（逐列字数、期望列基址 `0x0000/0x0100`、译码检查）。既有帧与单列向量**逐字节不变** |
| `ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py` | `--frame-hex-cols`（≥2，需 `--svh-packed`）→ 产出 `DAEMON_IMGCOL_NCOLS/_NWORDS/_WORDS/_DIGEST/_SIG/_SIG_TAMPER`；<2 列 / >FAB_COLS / 字数不齐 / 缺 `--svh-packed` 四类守卫（均已实测） |
| `ethereal-fabric/tests/bmc/tb_bmc_daemon_packed.sv` | **阶段 4**：2 列 `run_packed`（逐列 LOAD arm 握手 → `EFP_ERR=none` → 两列 READBACK CRC 均过；**WRITE 接受时的 `OCC_FRAME_ADDR` 轨迹必须等于 `region<<12|col<<8`**；逐列 cfg 窗口 backdoor 校验；col0 翻转 + col1 恒 1）；**阶段 5**：签名篡改 → 不 WRITE、两列仍活；**阶段 6**：stop 逐列 BLANK；另加诊断助手（`wait_uart_new`/`uart_mark`/`dump_uart_tail` 等） |

## 2. 暴露并修复的两个真实产品缺陷

1. **blank-before-write 粒度** ❌→✅：`occ_top` 的脏位原为 per-REGION（`frame_addr[15:12]`），而 v0.6 列映射把 packed 镜像的各列放在同一 region ⇒ 阶段 2 的"逐列 BLANK → 逐列 LOAD"顺序在 cols>1 时**不可能**成立（col1 的 WRITE 被拒 `S_NEEDS_BLANK`），且允许对**从未 BLANK 的窗口**写入 —— §3.1 与 §3.3 自相矛盾。**裁决方案 (a)**：脏位改 per-frame-window 位图 `dirty_r[255:0]`（索引 `frame_addr[15:8]`），规范 §3.1 措辞同步；落地于 `f17721f`，含 `tb_blank` 新增 packed 双列用例与负控。
2. **frame_decoder 捕获缓冲按 `fbus_addr - frame_base_i` 索引** ❌→✅：当 `frame_base_i=0`（**所有既有 TB** 都是），列 ≥1 的字 `widx ≥ MAX_WORDS(34)` 被**静默丢弃**，而 `cap_count_r` 仍计满 ⇒ 译码器把**上一列的陈旧缓冲**重新译码到新列的 tile 上，**无任何错误信号**（流 CRC 只管流，织物照单全收）。本 TB 将 `frame_base_i` 接到 daemon 编程的逐列基址（已验证 tile1 拿到自己的配置）；**RTL 侧加固（按捕获序索引 / 越界显式置位）已派给 RTL 属主**。

## 3. 验证

- ✅ **`tb_bmc_daemon_packed`：本人独立复跑通过**（exit 0 + 制作规则 `TEST PASSED`；agent 侧计数 **56 ok / 0 fail**，基线 25 ok）。
- ✅ `pytest`（ethimg/ethctl/capcheck）**92 passed**；`ruff` 干净；`mypy --strict` 干净（`pack_tb_frames.py` 仅余既有 `frame_map.py` 类型告警，独立复现）。
- ✅ `verilator --lint-only` 0 错误、无 TB 归属告警；固件重建（`-Werror` 干净）＋ hex 同步复制。
- ✅ **变异声明**（防过度声称）：v0.6 之前的 `col<<4` 步长会同时打爆本 TB 的①编程地址检查（0x0010≠0x0100）②两处 cfg 窗口检查（col1 的字会覆盖 col0 的 16..33 字）③col0 的逐列 READBACK CRC；而**织物侧逐列断言对地址不敏感**（译码器按 `dec_col` 映射），故混列检测靠地址与 CRC 断言 —— 已如实标注。

## 4. 下一阶段需要做的内容

- ✅ **frame_decoder 加固已完成（commit `5113f6e`）**：捕获缓冲改为**按捕获序**索引（`fbuf[cap_count_r]`，与地址偏移无关 ⇒ 陈旧缓冲不可能被重新译码）+
  新增 sticky `cfg_error_o`（捕获字偏移越出 `[0,MAX_WORDS)` 时置位，供 OCC 上报调用方错接线，不阻断译码）；
  `tb_frame_decoder` 负例（0x100 流 + `frame_base_i=0` + cb_sel 变异）证明**解出新流值而非陈旧值**且标志置位，回退变异恰好令该两点失败；
  tb_bmc_daemon_packed（2 列）在加固后仍 PASS。
- **E3-REP2 / E2-DOC1** — 把"多列镜像 ≥2 列的部署契约"写进 S09 冻结文本（含 `EFP_IMG_COLS` 与逐列 CRC 的配套要求）。
