# E2-RV2 分析报告 — 从 RV64GC+Sv39 到 "boot Linux" 的差距清单与切片计划

- **任务**：`E2-RV2`（RV-C）分析与规划；**只读调查**（无代码改动）。
- **日期**：2026-09-12
- **方法**：读 RTL/测试框架/语料源码，再读**钉住的 Spike 源码**（`generated/rv_difftest/spike`，commit `1e05ddac`）作为判据 —— 与语料同一条纪律：**先探针，后写 RTL**。
- **"boot Linux" 的定义**（取自 E2-RV2 acceptance / C14 §1 / S15 §4-5）：在 GW5 验证档（单 hart、无 DDR：BootROM + 片上存储）跑起 OpenSBI `fw_*` + `CONFIG_SMP=n` 内核，直到内核宣告 initramfs/init 并存活；仿真里程碑 = Verilated SoC 上该二进制运行且**控制台被断言**；实板里程碑再加频率/时序收敛。交互控制台、设备中断与用户态排在里程碑之后并标注。

## 1. 差距清单（按依赖排序）

| # | 差距 | 规模 | 证据（现状） |
|---|---|---|---|
| **G1** | **`wfi` 当前是非法指令** —— OpenSBI/Linux idle 的硬停 | S | `cor_decoder.sv:16-23,570-582`；README increment-6 段。**判据**：钉住的 Spike **会提交** `wfi`（`insns/wfi.h:11`、`execute.cc:274`）⇒ README 的"wfi 从不提交"说法是**错的**；用 `cor_intr.S` 的"预置 MTIP"法（`mtimecmp=0`）即可逐提交比对。钉住的 Spike 不理会 `mstatus.TW`（勿发明 TW 陷阱） |
| **G2** | **无 A 扩展（LR/SC/AMO）** —— OpenSBI/内核原子操作、引用计数、自旋锁、libgcc `__atomic_*` 都要它 | M | `cor_decoder.sv:63-64` 无 `OP_AMO 0x2f`；`MISA_VALUE` 无 bit 0；ISA 串 `rv64imfdc_zicsr`。**注意** `eth-axi-v0.md:108` 的 ATOP 是**总线级**（SMP 才需要），不是指令级 A 扩展 |
| **G3** | **无 Zicntr**（`cycle/time/instret`），`mcounteren/scounteren` 读 0 | M | `eth_rv_core.sv:950,1518-1522`；Spike 侧 `csr_init.cc:48-53` 按 `EXT_ZICNTR` 门控。**判据**：Spike 里 `time` 代理 CLINT 的 mtime（`clint.cc:115-118`）⇒ 有精确定义可 diff；`cycle/mcycle` 完全不可 diff；`instret` 只可对差 |
| **G4** | **M 模式/标识 CSR 地板**（`mvendorid/marchid/mimpid`、`menvcfg/senvcfg`、`mcycle/minstret`、`mhpm*`、`pmp*`） | M | `eth_rv_pkg.sv:280-288` 只实现 27 个 CSR，其余全陷阱。**做法**：先用 `--log-commits` 枚举目标 OpenSBI 交接前触碰的 CSR 地址，再按钉住配置镜像掩码（Spike 默认 16 个 PMP 区域、复位全放行 ⇒ 与"没有 PMP"行为等价，故语料从未发现） |
| **G5** | **无 BootROM / 复位向量 / a0-a1 / DTB / `core.yaml`** | L | `RESET_PC=0x8000_0000`（DRAM 插座基址）；`eth_rv_mmio_mux.sv:8-14` 只有 RAM/UART/CLINT；S15 §5 要求 BootROM→OpenSBI→Linux 且 a0=hartid、a1=DTB；`core.yaml` 不存在；运行器拒绝 entry≠MEM_BASE |
| **G6** | **内存窗口装不下内核** | S+M | TB `MEM_WORDS=32_768`（256 KiB，`tb_eth_rv_core.sv:100`）；AXI 窗口 1 MiB 且标 ASSUMPTION（`eth_rv_axi_master.sv:82-83`）。判据：Spike 用 `-m0x80000000:<size>` 与 DUT **同尺寸** ⇒ 顺带消掉 README 里"RTL 内存小于 Spike DRAM"的历史偏差 |
| **G7** | **无 PLIC，也无 SEIP 输入** | L | 端口只有 `msip_i/mtip_i/meip_i`（`eth_rv_core.sv:180-181`）；mux 头注明未实现；**架构缺口**：S 模式外部中断需要硬件驱动的 `mip.SEIP`，当前 SEIP 只能软件写（`:1447-1450`）⇒ 接线前必须新增 `seip_i` 端口。判据：Spike 的 `plic.cc`（按 DT 实例化） |
| **G8** | **控制台只发送**（无 RX、无 THRE 中断、分频被忽略） | M | `eth_rv_uart.sv` 头注明；`LSR=0x60` 常量；`dll/dlm/lcr` 存而不驱动位率。**为何不是第一阻塞**：boot 里程碑的 console 是**轮询**路径（serial8250 console_write 轮询 LSR）；但用户态 `write(2)` 靠 TX 中断排空 ⇒ 无 IRQ 会挂 |
| **G9** | **`mtime` 是 Spike 仿真节拍，不是时基** | S/M | `eth_rv_clint` 用指令触发 + `STEP_PRELOAD=5` + `RTC_TICK 5000/50`；DT 若宣告 `timebase-frequency` 就是假的（频率取决于 IPC）。**方案**：双模式 CLINT —— (a) DiffTest 模式保持现状，(b) SoC 模式由显式 RTC tick 输入驱动 |
| **G10** | **Sv39 遗留**：A/D 不置位、无 TLB/PTE 缓存、ASID 形同虚设、MPRV 只存不生效 | S(文档)/L(性能) | `cor_mmu.sv:50-52`（ADUE 假定 0 ⇒ 典型软件 A/D，内核能处理；DT 勿宣告 Svadu/PBMTE）；每次翻译取指 3 次 PTE 读 + 取指（约 4-5 周期）⇒ **性能而非正确性**才是 Verilator 跑 boot 的真成本 |
| **G11** | 非对齐访问陷阱（合法，内核模拟） | 无 | **保持 DT 不含 `Zicclsm`**，记录为性能边界 |
| **G12** | `fence/fence.i` 为 no-op | 无（现） | 无缓存单 hart 下正确；缓存落地的**前置条件**，届时失效 |

## 2. 切片计划（下一批 3-5 个增量）

依赖：**S1 → S2 → S3 → S4**，**S5 与 S4 并行**（S5 依赖 S3 的地址图，不依赖 S4 的里程碑）。每片都守同一条底线：**先探针、语料自检、两条 D 口路径、sby prove+cover 双绿、lint/ruff/mypy 干净、负控使新检查"活着"**。

| 片 | 内容 | 规模 | 关键验收 |
|---|---|---|---|
| **S1** | `wfi` + A 扩展（本片 = E2-RV2 增量 3） | S+M | 18/18 程序两路径 MATCH；`cor_atomic` 至少一次 LR/SC 成功、一次 SC 失败、每宽度类一次 AMO；`misa` 含 A；负控在注入 commit 处被抓；sby 新增 wfi/AMO 的 cover |
| **S2** | Zicntr + 计数器使能 + 标识/envcfg CSR 地板（增量 4） | M | `cor_counters.S`：`time` 阶梯（无陷阱）MATCH；`instret` 差等于提交差；`mcounteren.TM` 0/1 决定 U 模式 `rdtime` 是否非法；目标 OpenSBI 探针固件在 RTL 上**零陷阱**跑完交接 |
| **S3** | 启动路径：ROM/复位握手、a0/a1、DT、内存窗口、测试框架扩展（增量 5） | L | ROM→OpenSBI→(桩 payload) 在两条 D 口路径逐提交 MATCH 至停止点；`--stop-store ADDR[:VALUE]` 两侧在同一架构事件停止；RTL 窗口与 Spike `-m` 相等且删除历史偏差；`spike --dtb=<ours>` 与 RTL 达到同一首个控制台字节 |
| **S4** | OpenSBI → Linux 里程碑（增量 6） | L | 控制台里程碑逐字节断言（沿用 UART 帧检查）；固件段在同一镜像上逐提交 MATCH 至声明的同步点；页面错误计数 > 0（证明内核 A/D 路径被走）；记录墙钟预算；两条路径都能启动；**C14 §8 增补 RV-C 检查点表** |
| **S5** | 可用 Linux 的设备：PLIC + `seip_i`、UART RX/THRE（增量 7，可与 S4 并行） | L | `cor_plic.S` MATCH（enable→claim→complete、阈值/优先级、经 `mideleg.SEI` 的 S 模式 SEI，scause=9\|(1<<63)）；RX 注入字节按 Spike 语义读回；用户态 console `write(2)` 完成（无 TX 中断挂死） |

## 3. 明确"无法与 Spike 比对"清单

1. **`wfi` 的等待时长**（指令本身可比，等待不可观测）—— 语料规则：只在中断已挂起时执行。
2. **任何陷阱之后的 `time/mtime`**：Spike 遇陷阱提前结束 step（n=instret），节拍相位无 hart 侧计数器可复现 —— 语料规则：只用 `mtimecmp=0/-1`。
3. **取中断的边界**：RTL 在下一条指令边界取；Spike 只在序列化点重新入循环 ⇒ **整段 Linux boot 不可能作为单流逐提交比对**，只能**窗口比对 + 声明同步点 + 里程碑断言**。
4. **`cycle/mcycle` 数值**（Spike 自己的 step 计数）—— 只有差值与权限语义可比。
5. **LR/SC 保留集不确定性**（保留集大小是微架构）—— 语料内约束并记录。
6. **板级档的时基与 UART 位率**（启用 RTC/LCR 分频后脱离 DiffTest 契约，改由 TB 时序断言）。
7. **不同配置 golden 下的 `menvcfg` 类掩码**（可写集依赖扩展集）⇒ 必须**每次运行钉住并记录** golden 配置（ISA 串、`-m`、`--pmpregions`、`--dtb`），否则"分歧"无意义。
8. **Spike 模型没有的设备特性**（超出其 PLIC/ns16550 模型的部分）—— 用 TB 自检（先例：UART 帧时序/间隔/溢出断言）。
9. **缓存落地后的 `fence.i`/一致性效应**（Spike 无数据缓存）。
10. **AXI ATOP 与多 hart 行为**（总线协议/SMP 无提交级对应物；RV-E 再说）。

## 4. 计划文档（C14 / S15 / tasks.yaml）与代码的**明确矛盾**

1. `docs/ethereal-tasks.yaml` 的 `E2-RV2` 曾出现**两个 `status:` 键**（后者胜出 ⇒ 机器读者看到 `todo`）—— **已修**（2026-09-12）。
2. **C14 §1 把 `verif/eth_rv/README.md` 当作 F/D 证据，但 README 没有 F/D 段**，且至少 6 处过期：程序数（八/十二 → 16）、"无 MMU"、"CLINT 延后"、"`satp`/`sfence.vma` 未实现"、"无 CLINT/PLIC"、CLI 参考的默认 ISA。
3. **C14 §2 / S15 §2.3 承诺的参数包不存在**：`eth_core_config_pkg`（XLEN/CORE_COUNT/HAS_* 旋钮）与"只祝福 2-3 种配置"的纪律 —— 代码是**一份硬写配置**；`core.yaml` 全仓不存在。
4. **C14 §6 / S15 §4-5 的 DDR-less 档（BootROM+SRAM+SPI、PLIC+CLINT 作 AXI 从设备）代码无法表达**：`RESET_PC` 在 DRAM 插座基址、无 ROM/SRAM/SPI 区域、无 PLIC、CLINT 挂在核的 D 口 mux 而非 AXI 控制面。要么改档，要么改计划文本。
5. **README 的 wfi 理由与钉住的 Spike 矛盾**（见 G1）—— 且启动中的内核**会**执行 wfi，故"不实现"是启动失败，不是范围选择。
6. `ethereal-spec/control/eth-axi-v0.md:108` 读起来像"单核 Linux 不需要原子操作"（总线级 ATOP ≠ 指令级 A）—— 建议改写或加交叉引用。
7. **S15 §5 的 U-Boot 步骤**无任何支撑且 E2-RV2 验收不要求 ⇒ 建议把 RV-C 里程碑记为 BootROM→OpenSBI→Linux，U-Boot 显式延后。
8. **C14 没有 RV-C 检查点表**（§8 只有 RV-B 六条；§7 仍写"5 级 + 无 MMU/FPU 是低风险起点"）⇒ 在 S4 补齐。
9. **过期的模块头**：`eth_rv_core.sv:6-7` 仍写 "no MMU / FPU"（该文件两者都有）；`eth_rv_pkg.sv` Notes 仍写 "RV-B v0 范围：RV64I+M+C"。
10. README 的 CLI 参考过期（默认 `--isa rv64imc` vs 实际 `rv64imfdc_zicsr`）。

## 5. 测试框架扩展清单

H1 每片 golden ISA 串（zicntr/a）；H2 golden `-m0x80000000:<bytes>`；H3 `--dtb/--bootargs/--kernel/--pc/--pcs/--disable-dtb`；H4 泛化停止规则 `--stop-store ADDR[:VALUE]`（取代 tohost 符号规则）；H5 base/entry ≠ MEM_BASE 的镜像装载 + 分段大镜像；H6 两侧参数化内存窗口（TB/AXI/runner）；H7 长运行的窗口比对（窗口起点 + 预算，并在 PASS 行记录钉住的 golden 配置）；H8 控制台标记停止与断言（泛化 `EXPECTED_UART`）；H9 设备级 TB 断言（PLIC/RX）。

## 6. 一句话关键路径

`wfi`(S) → A 扩展(M) → 计数器 + CSR 地板（按 OpenSBI 探针）(M) → ROM/复位向量/DT/内存窗口 + 框架扩展(L) → OpenSBI→Linux 里程碑（窗口比对 + 控制台断言）(L)，同时并行 PLIC + UART RX(L) 以得到"可用 Linux"与真实时基。

**Sv39 / F/D / DiffTest 契约都不在这条路径的阻塞点上**；阻塞的是核从未被要求做过的四件事（A、wfi、Zicntr/envcfg、BootROM）加上内存图与框架的"单镜像、单 tohost"假设。

## 7. 复现基线

```bash
make verif-rv
PATH="$HOME/oss-cad-suite/bin:$PATH" make verif-rv-rtl
python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --all --dram
sby -f ethereal-shell/formal/eth_rv_core.sby
make lint
.venv/bin/ruff check ethereal-shell/verif/eth_rv ethereal-shell/verif/eth_rv_core
.venv/bin/mypy --strict ethereal-shell/verif/eth_rv ethereal-shell/verif/eth_rv_core
```
