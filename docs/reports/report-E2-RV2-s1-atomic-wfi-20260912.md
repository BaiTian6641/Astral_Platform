# E2-RV2 阶段报告 — RV-C 第三个切片：`wfi` + A 扩展（S1）

- **任务**：`E2-RV2`（RV-C），本报告覆盖**增量 3 = 差距清单中的 S1**；背景见 `report-E2-RV2-linux-gap-20260912.md`。
- **日期**：2026-09-12
- **Plan-Ref**：`ethereal-plan/components/C14-eth_rv-RV64核心.md` §里程碑表（RV-C 行）
- **为何是这一步**：差距分析把 `wfi`（当前为非法指令 ⇒ OpenSBI/Linux idle 硬停）与 A 扩展（OpenSBI/内核原子操作、引用计数、自旋锁、libgcc `__atomic_*`）列为启动路径的两个前置硬阻塞。

## 本阶段实现内容

### ✅ 先探针、后 RTL（本轮探针表已入库）

- AMO/LR/SC/`wfi` 的 `--log-commits` 形状；SC 确定性 9 例；非对齐语义（`lr` = cause 4、`amo/sc` = cause 6、`mtval` = 地址）；
- **两个 Spike step-loop 细节**（决定了语料怎么写）：中断只在序列化指令/WFI/chunk 边界采样；`in_wfi` 直接从 `step()` 返回；
- CLINT 复位即挂 MTIP。

### ✅ RTL

| 方面 | 实现 |
|---|---|
| `wfi` | 按 Spike 的精确恢复规则 `(mip & mie) != 0` 停等；U 模式非法；**不**理会 `mstatus.TW`（钉住的 Spike 不理会，勿发明陷阱） |
| A 扩展 | `lr/sc/amo`（`.w`/`.d` 共 22 种形式）；MEM 内 **2 拍读-改-写**；失败的 `sc` **抑制写拍**（新增 `mem_ok` 轨迹位）；保留集按 Spike 的"不因普通访存失效"规则；`rd_late` 冒险/旁路；`misa` A 位 ⇒ `0x8000_0000_0014_112d` |
| 轨迹 | **"报写入"约定**（AMO = 一条写记录，`rd` = 旧值；SC 失败 = 无 mem 字段），**不改格式版本**；`rv_spike.py` 归一化器只接受这一种两字段 AMO 行，其余仍拒绝 |
| ISA 串 | 全仓 `rv64imafdc_zicsr`（`rv_spike.py`/`build_corpus.py`/README/语料注释） |

### ✅ 语料与证据（本人在本机复跑，全部针对最终 RTL）

| 检查 | 结果 |
|---|---|
| 全语料（拍路径） | **`OK: 18 corpus program(s), MATCH vs Spike + console asserted`** |
| 全语料（AXI/DRAM 路径） | **同样 18/18 MATCH** |
| 新程序 | `cor_atomic` 916 commits（6 陷阱）/ `cor_wfi` 130 commits（2 中断），在拍、`--dram`、`--memlat 3` 三档均 MATCH |
| `make verif-rv` | **237 passed** |
| lint | `[lint] OK - all project RTL lint-clean.` |
| `sby … prove` | **`successful proof by k-induction`（rc=0）** |
| `sby … cover` | **PASS（rc=0）**（38 条 cover 语句） |
| 负控（本人复跑） | `--fault 213:mem_wdata=0x1234` ⇒ **`DIVERGENCE (mem_wdata_mismatch)` at #213**（该点是一次 `amoadd.d` ⇒ **AMO 写入值确实被比对**）；`--fault 30:value=0xdeadbeef` ⇒ #30 被抓 |

### 📌 本切片抓到并修复的真实缺陷（4 个）

| # | 缺陷 | 性质 |
|---|---|---|
| 1 | 语料 `cor_atomic` 的陷阱处理程序破坏了 `t0/t3` | 语料自检（已改为保存 `t0-t6`） |
| 2 | 解码：`.d` 形式的 AMO 被判非法（判了 funct3 高位而非 `funct3==011`）；`wfi` 的 bits 24:20 是立即数低bits而非 rs2（首版 `rs2==0` 检查使 wfi 非法） | 新代码 + 新特性 |
| 3 | **EX 操作数在多周期停顿下取陈旧值**：停顿冻结 EX 而 MEM/WB 继续排空 ⇒ 被重新求值的旁路回退到过期的 ID 读数 | **既有缺陷**，在**未改动的 RTL** 上以 `addi sp,sp,-64; sd ..,0(sp); sd ..,8(sp)`（第二笔存拿到减前的 sp）复现；修复 = 冻结首个停顿周期已解析的操作数（`ex_op_hold_r` + `ex_op{1,2,3}_hold_r`） |
| 4 | `sc` 在**首个** MEM_ACC 周期就清保留集（而非完成时）⇒ 在 `memlat>0`/AXI 路径上 `sc` 丢掉自己的保留集、什么都没写（rd=1 而 Spike 为 0） | **既有缺陷**（仅慢路径可见） |

### 📌 形式化：P9 归纳失败的真实根因与修复（未削弱断言）

本切片中途 `prove` 由 PASS 转为 **UNKNOWN(rc=4)**，失败于 P9 `!(mmu_pte_req && mem_phase_r == MEM_ACC)`（`eth_rv_core.sv:2287`）。定位：归纳引擎可选取"MEM_ACC 持有无访问槽位"的**不可达**状态（伪 AMO：`amo_write_r=0` 且 `dmem_ready_i` 自由）并自环，随后在其中发起取指遍历 ⇒ 下一状态违反 P9；**AMO 的第二拍正是让该状态显形的改动**。
- 第一次尝试加"phase==MEM_ACC ⇒ 有活访问"的不变式断言 ⇒ **basecase 在第 8 步失败并证明其为假**：EX 侧陷阱会在访问中途清空 `mem_valid_r`，相位确实会多留一拍死槽位 ⇒ **该状态可达**，断言不成立。
- 最终修复在 **FSM**：AMO 自环与 `dmem_req_o` 都按 `mem_is_access` 门控 ⇒ 死槽位既不能驱动端口也不能多活一拍（顺带修掉一个**既有隐患**：陷阱在访问中途清槽后的伪 D 口拍）。**断言未改**，P9 处注释说明理由。
- 修复后复跑：`prove` **k-induction PASS**、`cover` PASS（本人复跑确认）。

### ✅ 顺带修正的过期物

- `cor_csr.S` 的 `misa` 期望值 `0x…112c` → **`0x…112d`**（A 位）—— 由本人在全量复跑中抓到（Spike 侧自检 13 失败），并同步注释；
- `cor_fp.S` 头注释的 ISA 串 → `rv64imafdc_zicsr`；
- README：wfi 的"从不提交/未实现"错误说法改为真实规则与边界；程序数 16→18；"无 MMU/无 FP/无 CLINT"行修正；CLI/ISA 参考更新；新增"The A extension"与"wfi"两节（含证据/边界/负控）；
- `tests/test_rv_spike.py` 契约更新（`DEFAULT_ISA`、`misa` 值）并新增 3 条测试（AMO 两字段归一化保留写入、非 AMO 的两访问行仍拒绝、wfi 提交无 rd/mem）。

### ❌ 边界（不可比对项，已写入 README）

`wfi` 的等待时长；LR/SC 保留集大小的微架构不确定性（语料内约束）；Spike 的序列化点中断边界（整段 boot 不能作单流逐提交比对，见差距报告 §3）。

## 下一阶段需要做的内容

- `E2-RV2` 增量 4 = **S2**：Zicntr + 计数器使能 + 标识/envcfg CSR 地板（先跑目标 OpenSBI 探针枚举 CSR）。
- 其后 S3（启动路径 + 框架扩展）、S4（OpenSBI→Linux 里程碑，并补 C14 的 RV-C 检查点表）、S5（PLIC + UART RX，可与 S4 并行）。
- `E2-AST1`（WASM 验收，环境门控）、`E1-DMO3`/`E0-INF2`（外部动作）。
