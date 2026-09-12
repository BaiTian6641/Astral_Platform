# E2-RV2 阶段报告 — RV-C 第五个切片：启动路径（BootROM/复位握手/DT/内存窗口/框架扩展，S3）

- **任务**：`E2-RV2`（RV-C）**增量 5 = 差距清单 S3**（G5/G6 + 框架扩展 H2-H6）；背景见 `report-E2-RV2-linux-gap-20260912.md`。
- **日期**：2026-09-12
- **Plan-Ref**：`ethereal-plan/components/C14-eth_rv-RV64核心.md` §里程碑表（RV-C 行）；SoC 约定见 `ethereal-shell/core.yaml`
- **为何是这一步**：在此之前核复位在 DRAM 插座基址、寄存器堆全零、无 ROM、无设备树、无处可放"设置 a0/a1 再跳转"的桩 —— 固件根本没有被装载与交接的路径。

## 本阶段实现内容

### ✅ 固定接口契约（两半并行实现，逐项核对）

| 项 | 值 |
|---|---|
| BootROM | 基址 **`0x0000_1000`**、4 KiB（镜像 Spike 的 `DEFAULT_RSTVEC` 形状）；载荷入口 = **偏移 32 的 64 位数据字**（每次运行由框架打补丁） |
| ROM 桩 | `auipc / lui / slli / srli`（构造 `a1`）/ `csrr a0, mhartid` / `ld t0,32(t0)` / `jr t0` |
| 交接 ABI | **`a0 = 0`（hartid）、`a1 = 0x8000_2000`（DTB）** |
| RAM | 基址 `0x8000_0000`，窗口 **1 MiB —— 全链路同一个数**：TB `-DETH_RV_MEM_BYTES`、DRAM bytes、AXI 主口、`eth_dram_ctrl`、runner、Spike `-m0x80000000:1048576` |
| `core.yaml` | `ethereal-shell/core.yaml`（hart 数、ISA `rv64imafdc_zicsr_zicntr`、窗口、ROM/DTB 地址、时钟占位）+ `verif/eth_rv/rv_platform.py` 单一来源，**并有测试在两者与 `.dts` 不一致时失败** |

### ✅ RTL 侧

- `eth_rv_boot_rom.sv`（4 KiB，`BASE/BYTES/ENTRY_WORD`、`entry_o`/`stub_steps_o`）+ `rom/boot_rom.S`/`.ld`/`build_rom.py`/`boot_rom.hex`（确定性、随仓库提交）。
- `eth_rv_mmio_mux.sv`：解码顺序 **ROM → UART → CLINT → 内存**；对 ROM 的写按 Spike 的 `rom_device_t::store == false` 回**错误**；`rom_entry_o`/`rom_steps_o` 输出。
- `eth_rv_pkg.sv`：`RESET_PC = 0x1000`（RV-B 的过期注释一并替换）。
- TB：`-DETH_RV_MEM_BYTES` 窗口、`+rom/+entry/+trace_from/+dtb/+mem_bytes/+stop_addr/+stop_value`、ROM 取指与预载 + 入口字补丁、DTB 装载 + **FDT magic 校验**、**RTL 侧 a0/a1/entry 握手检查**、AXI 构建下 `+dmem_corrupt_*` 改为**大声拒绝**。
- **`time` 节拍不变量（本切片最微妙的耦合，见下）**：`eth_rv_clint` 新增 `step_skip_i`，预载常数**由桩自身推导**而非调参。

### ✅ 框架侧

- golden 标志：`-m0x80000000:<size>`、`--dtb`、`--bootargs`、`--pc/--pcs`、`--disable-dtb` —— **并在 PASS 行打印 `golden config:`**（每次运行的 golden 配置可审计）。
- 装载：base/entry ≠ RAM 基址（`write_window_image`/`RomImage`）、独立 ROM 镜像与 DTB blob。
- **`--stop-store ADDR[:VALUE]`** 取代 tohost 专有规则（无该标志时保持旧行为）；实测：地址写错时**报错而非静默放行整条流**。
- `eth_rv.dts`（与 core.yaml 一致：`memory@80000000`、`serial@10000000`、`clint@2000000`、`mmu-type riscv,sv39`、`timebase-frequency` 注明为 DiffTest 节拍并写明边界）+ `build_dtb.py`（dtc 用已构建的 `generated/rv_difftest/dtc`）。
- README 新增"The boot path and the harness flags"。

### ✅ 验证（本人在本机复跑，针对最终 RTL）

| 检查 | 结果 |
|---|---|
| 全语料（拍路径） | **`OK: 21 corpus program(s), MATCH vs Spike + console asserted`** |
| 全语料（AXI/DRAM 路径） | **同样 21/21 MATCH** |
| 新程序 | `cor_boot`（载荷链接在 `0x80001000`，检查 `a0==0`、`a1` 非零且 8 字节对齐、`.data` 往返；退出码 1..4）21 commits |
| `make verif-rv` | **264 passed**（+19 平台/框架测试） |
| lint | `[lint] OK - all project RTL lint-clean.`（含新 `eth_rv_boot_rom.sv`） |
| `sby … prove` / `cover` | **k-induction PASS（rc=0）** / 见文末（本人在最终 RTL 上复跑） |
| **Spike 从 ROM 本身启动** | `spike … --pc=0x1000 --disable-dtb` + TB `+trace_from=0x1000` ⇒ **MATCH 28 commits = 7 条 ROM 指令 + 21 条载荷**（含 `a0=0`、`a1=0x80002000` 由 LUI/SLLI/SRLI 构造、`0x1020` 的入口加载与 `jr`）—— **握手被 oracle 端到端证明** |
| 负控（agent） | 错误 `a1` 的 ROM ⇒ FAIL 并打印实际值；缺 ROM ⇒ FAIL；窗口不匹配 ⇒ FAIL；非 FDT blob ⇒ FAIL（magic）；`--fault 5:pc=…` ⇒ 在 #5 被抓 |

### 📌 本切片抓到并修复的真实缺陷：`time` 节拍相位

全量复跑时 **`cor_time`（#4990）与 `cor_counters`（#4988）分歧**，而两者的定向回归都没覆盖"读时间"的程序 ⇒ 定位：**DUT 现在先执行本 SoC 的 7 条 ROM 指令**，而 golden 仍执行 Spike 自带的 **5** 条 boot ROM，`eth_rv_clint` 的 `mtime` 公式只补偿了 5 ⇒ 首次读时间的台阶处相位偏移 2 条指令。

修复方式（**不是把常数调到能过**）：
- 不变量写进模块头的 MTIME CADENCE 注释：`tick = CLINT_STEP_PRELOAD + （桩交接之后退休的指令）`；
- 新增 `step_skip_i`：SoC 自身桩的脉冲被**吞掉**，不会重复计数；
- 预载**由桩推出**：`boot_rom.S` 用 `.option norvc`（指令==字节/4）把 `(_rom_stub_end-_rom_start)/4` 作为**链接期常量写入镜像第 7 个字**，`.org` 保证更长的桩会让构建失败；RTL 导出 `stub_steps_o`、TB 若发现"镜像里的数与实际观察到的退休数不一致"则 **FAIL**（漂移护栏）；全 ROM 比对模式（Spike 从我们的 ROM 启动）改用 `-DETH_RV_CLINT_PRELOAD=7`。
- 对照：把镜像步数改成 9 ⇒ **FAIL**（护栏生效）；`-DETH_RV_CLINT_PRELOAD=4995` ⇒ #10 即分歧（相位确实 load-bearing）。实现者同时**如实指出** ±1 的对照不可靠（只有当某次 `time` 读正好落在移动后的边界才可见），这比给出一个假绿更有价值。

### ⚠️ 边界

- 一条 ELF 作的 ROM（`--rom <elf>`）没有步数字 ⇒ TB **大声拒绝**（须用提交的 hex 或先烘焙该字）。
- `timebase-frequency` 在 DT 里是**仿真节拍**（Spike 的指令步），不是真实频率 —— DT 内已注明；真实时基属 S4/S5 的 SoC 档。
- 整段 boot 仍**不能**作为单流逐提交比对（Spike 只在序列化点取中断）⇒ 窗口比对 + 声明同步点（S4）。

## 下一阶段需要做的内容

- **S4**：OpenSBI → Linux 里程碑（窗口比对 + 控制台断言 + 墙钟预算），并补 C14 的 **RV-C 检查点表**；需要外部 RISC-V Linux 工具链/OpenSBI 源码（环境门控，需维护者确认获取方式）。
- **S5**：PLIC + `seip_i` + UART RX/THRE（可与 S4 并行）。
- `E2-AST1`（WASM 验收，环境门控）、`E1-DMO3`/`E0-INF2`（外部动作）。
