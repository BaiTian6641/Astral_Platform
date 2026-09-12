# E2-RV2 阶段报告 — RV-C 第二个切片：F/D（浮点）与轨迹扩展

- **任务**：`E2-RV2`（RV-C），本报告覆盖**增量 2（F/D + FP 轨迹扩展）**；增量 1（Sv39）见 `report-E2-RV2-sv39-20260912.md`。
- **日期**：2026-09-12
- **Plan-Ref**：`ethereal-plan/components/C14-eth_rv-RV64核心.md` §里程碑表（RV-C 行）
- **前置**：RV-B 全绿；增量 1（Sv39）14/14 语料 MATCH。

## 本阶段实现内容

### ✅ 轨迹扩展设计（先设计、先探针、后动 RTL）

- **决策（Option A）**：在既有轨迹格式上扩展 **FP 记录** —— `rd` 增加 FP 类别（`f0`..`f31`，`f0` 是真寄存器），并在位置字段后追加**带键 token** `fflags=0x..` / `frm=0x..`；解析器先剥离含 `=` 的 token，因此 **v1 轨迹仍可解析**，内存后缀不受影响；**无 FP 状态的流会报 `fp: not provided`，而不是静默通过**。
- **探针证据（写 RTL 之前，Spike 1e05ddac）**：FP 寄存器写入为 NaN-boxed（`f1 0x3ff0…`、`fmv.w.x f14` 记 `ffffffff3f800000`、`flw` 零记 `ffffffff00000000`）；`c1_fflags 0x…0010`（新 fflags 值，仅在写时记录）；`frm` 来自 `csrw fcsr`（fcsr 是两个子 CSR 的视图）；`mstatus` 在 fs-dirty 时记录；**FP 存取不弄脏 FS —— 只有 FP 寄存器写会**（探针与 Spike 源码 `dirty_fp_state`/`WRITE_FRD` 一致）。
- **取舍（诚实记录）**：`mstatus`(FS/SD) **不**作为轨迹字段 —— Spike 在每次 mstatus 写（CSR、mret/sret、隐式 FS→Dirty）都记录它，只报一部分是不诚实的，全报则要为 14 个已绿程序新开一条比对路径；改为**经语料 `csrr mstatus` 读回值**比对（现有 rd/value 比对已能捕获其差异，且语料钉住 7 处，含"FSD 不弄脏 FS"）。

### ✅ RTL

| 文件 | 内容 |
|---|---|
| `cor_fp_regfile.sv`（新） | 32×64 FP 寄存器堆，3 读端口（rs1/rs2/rs3），write-first 旁路，`f0` 普通寄存器 |
| `cor_fpu.sv`（新，~1230 行） | 精确定点 add/sub/mul/fma（106 位乘积、192 位对齐窗口、**单次舍入**）、58 步恢复除法、60 步逐位平方根、按目标精度参数化的共享 round-and-pack（**任何 S 结果都不来自对 D 结果再舍入**）、全部 cvt/cmp/minmax/sgnj/class/move、规范 NaN 装箱、SoftFloat 零符号规则、舍入后判定 tiny、fflags 累积 |
| `eth_rv_pkg.sv` | `fp_op_e`/`fp_rm_e` + 分类助手、fflags/frm/fcsr CSR、FP 控制位、`misa += F|D` |
| `cor_decoder.sv` | OP-FP、OP-FMA（rs3 经新端口）、FP 取存与 C.FLD/C.FSD/C.FLDSP/C.FSDSP；half/quad 保持 illegal |
| `eth_rv_core.sv` | FP 寄存器堆 + FPU 接入、类感知 EX 旁路与 load-use 冒险（FP 值绝不旁路进整数操作数）、FPU 停顿握手、**仅 FP 寄存器写**弄脏 FS、FS=Off 对 FP 指令与 fcsr/fflags/frm 均 illegal、FLW 装箱、FP CSR、新轨迹端口 |

### ✅ 验证（本人在本机复跑，全部针对最终 RTL）

| 检查 | 结果 |
|---|---|
| 全语料（拍路径） | **`OK: 16 corpus program(s), MATCH vs Spike + console asserted`** |
| 全语料（AXI/DRAM 路径） | **同样 16/16 MATCH** |
| `make verif-rv` | **234 passed**（181 → 234） |
| lint | `[lint] OK - all project RTL lint-clean.`（`cor_fpu.sv`/`cor_fp_regfile.sv` 已入 `RTL_CLEAN` + deps + 同侪豁免） |
| `sby … prove` | **`successful proof by k-induction`（rc=0）** |
| `sby … cover` | **PASS（rc=0）** |
| 负控（本人复跑） | `--fault {20,60,200}:fflags=0x1f` ⇒ 三次均 **`DIVERGENCE (fflags_mismatch)`**（FP 标志比对确实"活着"）；`--fault 30:value=0xdeadbeef` ⇒ 程序自检失败（退出非零） |
| 语料自检 | `cor_fp`（322 checks）/`cor_fptrap`（67 checks）在 Spike 下 rc=0，且**逐条常量破坏会让 rc 变成该 check 的编号**（自检确实有效） |

### 📌 本切片抓到的真实缺陷与定位方法

1. **`fsqrt` 恒返回 0**（`cor_fp` 在第 94 commit 分歧：golden `0x3ff8…`(1.5) vs dut `0`）。
   定位过程（**无猜测**）：先关掉轨迹过滤（运行器只回显 `ETH_RV_TB:` 前缀行）→ 在 FPU 的 sqrt 初始化/收尾打临时探针 → 得到 `rad=0x24…0 e=-58`、`root=0x600000000000000 rem=0 cr=0x0`，并证明 `ua` 正好解包出语料真实输入 2.25 ⇒ **算术与解包都对，错误在 round-and-pack**。
   根因：**rounder 的零判定用了 `nmag`（由加法器通路 `wmag` 推出），而 SQRT/DIV 通路只驱动 `rf_mant`** ⇒ `nmag==0` ⇒ 走"±0"分支。同一段里真正基于 `rf_mant` 的 `rnm`/`msb_e`/`sh` 算出的答案是对的（rnm=59、msb_e=0、sh=4 ⇒ 1.5）。
   修复：零判定改用 `rnm`，删除已死的 `nmag`。
2. **div 同源风险**：同一处缺陷对除法同样暴露（语料早期用例未命中）——已要求实现者用能走同一判定的操作数对复查。

> 教训入库：**"值正确"与"打包正确"是两件事**；比对新字段（fflags/frm）而不是只比 rd/value 是这次能抓到的前提。

### ❌ 未做（边界）

- Sv39 → Linux 启动的其余前置（设备树/时钟/中断控制器细化等）。
- 缓存/BTB：性能项，且与逐访问比对契约冲突（仍不做）。
- `mstatus` 作为轨迹字段：见上文取舍，改用读回比对。

## 下一阶段需要做的内容

- `E2-RV2` 增量 3：向"boot Linux"推进（先出差距清单 + 探针，再动 RTL）。
- 形式化：保持 `prove`+`cover` 双绿（本切片已复跑）。
- `E2-AST1`：WASM 组件验收（环境门控）；`E1-DMO3` / `E0-INF2`：外部动作。
