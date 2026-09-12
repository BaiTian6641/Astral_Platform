# E2-RV2 阶段报告 — RV-C 第六个切片：PLIC + S 模式外部中断 + UART 接收（S5）

- **任务**：`E2-RV2`（RV-C）**增量 6 = 差距清单 S5**（G7/G8）；背景见 `report-E2-RV2-linux-gap-20260912.md`。
- **日期**：2026-09-12
- **Plan-Ref**：`ethereal-plan/components/C14-eth_rv-RV64核心.md` §里程碑表（RV-C 行）
- **为何是这一步**：没有 PLIC 任何设备中断都到不了 hart，且 S 模式外部中断需要**硬件驱动**的 `mip.SEIP`（此前只能软件写）；UART 只有发送路径 ⇒ 用户态 `write(2)` 会因无 TX 中断而挂、控制台无法输入。

## 本阶段实现内容

### ✅ PLIC（`eth_rv_plic.sv`，新增）

- 标准地址图 `0x0C00_0000`（priority / pending / enable / threshold / claim / complete），唯一设备 = 控制台 UART（源 1，电平触发），DT 声明 `riscv,ndev = 31`。
- **hart 新增 `seip_i` 输入** ⇒ 标准 S 模式 context 输出可以真正驱动 `mip.SEIP`（此前 DT 的 PLIC 节点标着"仅 golden 侧"、且 `0xC000_0000` 的未解码访问会把 D 口**卡死**）。
- 同周期写透传（阈值写之后的**下一条**指令读 `mip` 必须可见）；pending 优先级闩锁；同优先级按 id 决胜。

### ✅ UART 接收路径

- 接收移位器 + 队列、`LSR.DR`、`RBR`、Spike 建模的 FCR 位、RX 中断（IIR）接至 PLIC；**TX 行为与既有 Spike 镜像常量原样不动**（DiffTest 依赖它们）。

### ✅ 验证（本人在本机复跑，针对最终 RTL）

| 检查 | 结果 |
|---|---|
| 全语料（拍路径） | **`OK: 23 corpus program(s), MATCH vs Spike + console asserted`** |
| 全语料（AXI/DRAM 路径） | **同样 23/23 MATCH** |
| 新程序 | `cor_plic` 446 commits / 7 陷阱（2 个中断 = M 模式 MEI + S 模式 SEI，4 次 access fault）；`cor_uart_rx` 746 commits / 1 陷阱，UART 1 字节 `'Z'` |
| `make verif-rv` | **266 passed**（含新增的 PLIC↔DT↔yaml 一致性、contexts 11/9、UART 源/电平触发、控制台载荷映射测试） |
| lint | `[lint] OK - all project RTL lint-clean.`（PLIC 已入 `RTL_CLEAN` 与 mux deps —— 实现者交接的两行由本人接线） |
| `sby … prove` / `cover` | **k-induction PASS** / **PASS**（41 条 cover 含两条新 PLIC cover；**未改动/削弱任何断言**） |
| 负控 | 损坏 RX 字节（`+uart_rx_fault_frame/_bit`，起始位/停止位两种）⇒ FAIL 并打印实际与注入字节；`--fault 100:value=0xdead`（claim 记录）⇒ 在 #100 被抓；`+uart_rx=41424344` 正对照 PASS 且仍 MATCH |

### 📌 本切片抓到并修复的真实缺陷（6 + 1）

| # | 缺陷 | 说明 |
|---|---|---|
| 1 | pending 优先级用**半字节**掩码而非位掩码 | 结果：中断**从未**被投递 |
| 2 | context 内的字索引未掩码 | S context 的写入被译成保留偏移并报错 |
| 3 | 阈值写缺同周期旁路（甚至把阈值**读**当成写） | 写后下一条指令读 `mip` 看不到效果 |
| 4 | UART `FCR` 清 RX 时只清计数、未重同步读指针 | 下一次读回**陈旧字节** |
| 5 | 接收器起始沿检测比较式取反 | 一个字节都收不到 |
| 6 | TB 注入驱动首格只有 1 周期 + 故障对照缺省值缺失 | 正对照破坏了第 0 帧的起始位 |
| **7** | **核的 S 资格判定缺少 M 模式子句**（**范围外发现**）：待决且使能的 **S 委托**中断被在 M 模式下经 `mtvec` 以错误 cause 取走 | 修正为 Spike 的 `hs_enabled` 规则；本切片是第一个能触达它的（SEIP 终于有硬件源） |

### ⚠️ 边界（写入 README 新节）

- Spike 的 UART 是**终端驱动**的 ⇒ **串行线本身只能 TB 自检**（`+uart_rx=` 逐字节注入 + `+uart_rx_fault_frame/_bit` 负控）；物理位率/时序仍是 TB 断言（`LCR/DLL/DLM` 存而回读、不驱动位率，与 Spike 一致）。
- `FCR.ENABLE_FIFO` 不门控线路接收器（Spike 只门控它无法驱动的终端轮询）。
- 帧错/溢出是**验证状态端口**（`rx_frame_err_o/rx_overflow_o`），不是 LSR 位（Spike 模型无此位）。
- 跨 id 的 PLIC 优先级次序**未**被 Spike 对照（只有源 1 有设备）；阈值规则、待决优先级闩锁、同优先级 id 决胜链形状有对照。
- 面向内核仍缺：无 `sstc`/无 S 模式定时源（用 SBI 定时路径 —— `mip.STIP` 写与 `mideleg` 确实可用，正是 OpenSBI 的 non-`sstc` 路线）；仅源 1、`riscv,ndev=31`；无 IMSIC/APLIC；无硬件 A/D 更新；无 PBMTE/Svadu/Zicclsm；DT 的 `timebase-frequency` 仍是仿真占位。

## 下一阶段需要做的内容

- **S4（最后一片）**：OpenSBI → Linux 里程碑。可行性已由独立 spike 定论（见 `local://s4-feasibility.md`）：OpenSBI **v1.3 + `FW_PIC=n`** 可在本机**原生构建**（`fw_jump.bin` 131.8 KiB、入口 `0x8000_0000`）；Alpine 内核（20.9 MiB，PE 包装内含 RISC-V image header ⇒ 可**剥离出 raw `Image`**）+ 静态 busybox initramfs（1.01 MiB）可达；RAM 窗口需 **≥34.01 MiB**（kernel 到 0x817D6000 + 原版 `FW_JUMP_FDT_OFFSET=0x2200000`）、DTB 必须搬离 `0x80002000`（该地址在 OpenSBI 镜像内）；RTL 侧成本 = 同小时级（实测 5.4-5.5×10⁵ cycles/s，32-40 MiB TB 19 s 构建）。**PLIC 节点现已有 RTL 支撑**（本切片），不再卡死。
- 其余外部门控：`E2-AST1`（WASM 运行时）、`E1-DMO3`（发布动作）、`E0-INF2`（首次真实 CI）。
