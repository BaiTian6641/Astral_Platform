# E2-RV2 阶段报告 — RV-C 第四个切片：Zicntr + 计数器使能 + CSR 地板（S2）

- **任务**：`E2-RV2`（RV-C）**增量 4 = 差距清单 S2**；背景见 `report-E2-RV2-linux-gap-20260912.md`（G3/G4）。
- **日期**：2026-09-12
- **Plan-Ref**：`ethereal-plan/components/C14-eth_rv-RV64核心.md` §里程碑表（RV-C 行）
- **为何是这一步**：固件在交接内核前必须能读计数器、设置计数器使能，并访问标识/envcfg 类 CSR；此前这些 CSR 全部陷阱（27 个 CSR 白名单之外一律非法）。

## 本阶段实现内容

### ✅ 探针表（全部在钉住的 Spike `1e05ddac` 上**实测**，非猜测）

| 项 | 实测值 |
|---|---|
| 标识 CSR | `mvendorid=0`、`marchid=5`、`mimpid=0`、`mconfigptr=0`、`mhartid=0`（只读） |
| `menvcfg/senvcfg` | 复位 0，写掩码 **0x1**（仅 FIOM） |
| `mcounteren/scounteren` | 复位 0，掩码 **0x7**（CY\|TM\|IR）；`mcountinhibit` 复位 0、掩码 **0x5**（无 TM 位） |
| `mcycle/minstret` | **= 退休指令数（CPI=1）**；**陷阱指令不计**（非法/取指错/取数错实测均为 0）；显式写入会存值并**抑制写入者自身**的递增；inhibit CY 只冻结 cycle、IR 只冻结 instret |
| 预载 | 计数器包含 Spike 的 **5 条 boot ROM 指令** ⇒ RTL 预载 5（与 `eth_rv_clint` 的 `STEP_PRELOAD` 同法） |
| `time` | **就是 CLINT 的 mtime 寄存器**（`clint.cc:116` 同步影子）；probe5 在 1300 次迭代中 `rdtime` 与 `0x200bff8` 读值 **1299/1300 相同**（唯一不同发生在节拍落点那条指令上） |
| 权限 | M 自由；S 需 `mcounteren[bit]`；U 需 `mcounteren[bit]` **且** `scounteren[bit]`；写 `cycle/time/instret` 在**任何**模式非法（读形式合法）；S/U 访问 `mcounteren` 非法 |
| 必须保持陷阱 | `mcycleh/minstreth/mstatush/menvcfgh/senvcfgh/pmpcfg1/pmpcfg3/hpmcounter3/hpmcounter3h`（RV64 下非法） |
| `mhpm*` | `mhpmcounter3..31` 读 0、写丢弃；`mhpmevent3..31` 同 |
| PMP | `pmpcfg0` 复位 `0x1F` + `pmpaddr0` 复位 `0x003fffffffffffff`（全放行）且 **L 位锁定真实存在**（`pmpcfg0=-1` 后写 0 被丢弃、随后 `pmpaddr1` 写也被丢弃）⇒ **本切片刻意不做 PMP**（决定与理由记录在 notes §1.6） |

### ✅ RTL

- `eth_rv_pkg.sv`：新 CSR 地址与实测掩码/复位值、`COUNTER_PRELOAD=5`、`counter_wr_e`、`csr_is_mhpmcounter()/csr_is_mhpmevent()/csr_is_counter_proxy()/csr_counter_bit()` 助手、`csr_implemented()` 扩展、`mem_ctrl_t.counter_wr`。
- `eth_rv_core.sv`：新增 `mtime_i` 端口；`csr_mcycle_r/csr_minstret_r` 在**提交沿**递增、在 **EX 沿**写入（精确对齐 Spike：写后再读回写入值；陷阱指令永不计数）；读侧对待决 MEM 的调整；权限门 `ex_counter_denied` 并入 `ex_csr_illegal`；使能/抑制/envcfg 的 WARL 存储；标识与 envcfg 读；`mhpm*` 读 0/写丢弃。
- `eth_rv_mmio_mux.sv` + `eth_rv_clint`：导出 `mtime_o`（同一指令的读路径取值一致）；TB 接到 `mtime_i`。
- **ISA 串**：golden 与语料同为 `rv64imafdc_zicsr_zicntr`。

### ✅ 语料与验证（本人在本机复跑，针对最终 RTL）

| 检查 | 结果 |
|---|---|
| 全语料（拍路径） | **`OK: 20 corpus program(s), MATCH vs Spike + console asserted`** |
| 全语料（AXI/DRAM 路径） | **同样 20/20 MATCH** |
| 新程序 | `cor_counters` 10928 commits / 24 陷阱（拍 15647 cycles；DRAM 30239 cycles，AXI 8 AR/64 R、2901 AW/W）；`cor_csrid` 437 commits / 16 陷阱；两者**先在 Spike 下 rc=0** |
| `make verif-rv` / lint | 237 passed / `[lint] OK - all project RTL lint-clean.` |
| `sby … prove` / `cover` | **k-induction PASS（rc=0）** / **PASS（rc=0）**（本人复跑） |
| 负控（agent） | `--fault 43:value`（mcycle 读）、`--fault 109:value`（`time` 读）、`--fault 18:value`（`cor_csrid` 标识读）均在确切 commit 被抓；另有一条权限门变异对照 |

### 📌 新语料抓到的两个真实 RTL 缺陷

1. **`mcounteren` 被错误地用于 M 模式**（Spike 只在 `prv<M` 时门控）—— 表现为 `1 traps` + `pc_mismatch #48`；
2. **抑制位在退休沿才采样** ⇒ `csrw mcountinhibit,1` 这条使能指令**自己**未被计数 —— 表现为 `value_mismatch #84`（golden 3 vs dut 2）；改为在 EX 判定并经 `mem_ctrl_t.counter_inc` 携带。

### 📌 `_zicntr` 带来的 ISA 可见连锁（同一改动内修好）

- `mcounteren/scounteren` 掩码 `0x0 → 0x7`（`cor_priv` 检查 18/19）；
- **`medeleg` `0xb3fe → 0x8b3fe`**（Zicntr 新增 bit 19 —— 由 Spike 实测得出）⇒ `cor_priv` 13、`cor_deleg` 2、`cor_pgfault` 1 三处期望值 + RTL 的 `MEDELEG_WMASK` 同步；
- `misa` 不变。

### ⚠️ 边界（写入 README）

- `cycle/mcycle` **数值不可比对**（Spike 自己的 step 计数）—— 只有差值与权限语义可比；
- **`time` 只在无陷阱时可比**：Spike 遇陷阱提前结束 step（n=instret）⇒ `cor_counters` 的阶梯段放在首次陷阱之前，陷阱之后的合法读一律用 `rd=x0` 规避；
- golden 配置（ISA `rv64imafdc_zicsr_zicntr`、`-m`、`--pmpregions`）必须逐次钉住并记录，否则 `menvcfg` 类掩码的"分歧"无意义；
- PMP 本切片不做（理由与实测的 L 位行为见 notes §1.6）；`menvcfg` 仅实现实测到的 FIOM 位。

## 下一阶段需要做的内容

- **S3**：启动路径（BootROM/复位向量、a0/a1、DT、内存窗口）+ 测试框架扩展（H2-H6）。
- **S4**：OpenSBI → Linux 里程碑（窗口比对 + 控制台断言），并补 C14 的 **RV-C 检查点表**。
- **S5**：PLIC + `seip_i` + UART RX/THRE（可与 S4 并行）。
- `E2-AST1`（WASM 验收，环境门控）、`E1-DMO3`/`E0-INF2`（外部动作）。
