# E2-RV0 验收报告 — eth_rv DiffTest 锁步验证载体

- **任务**: E2-RV0（新立：`eth_rv` 的 DiffTest 载体；S15 §2.2「**验证 >> RTL** —— 第一天就上 DiffTest 锁步 co-sim vs Spike」）
- **日期**: 2026-09-12
- **状态**: **完成**（载体可用；不含 `eth_rv` RTL）
- **Plan-Ref**: `ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2`、`docs/adr/ADR-018-axi-noc-riscv-cluster.md`
- **上游**: 网络可达（github clone 有效）→ Spike 可构建 ✔

---

## 1. 本阶段实现内容

| 交付 | 内容 |
|---|---|
| `ethereal-shell/verif/eth_rv/rv_trace.py` | 提交轨迹（commit trace）规范与严格解析：`cycle pc rd value`（无架构写时 `rd=-`，x0 写丢弃；亦接受宽松 3 字段） |
| `rv_image.py` | ELF64 载入（含符号表）+ 自描述 hex 镜像 |
| `rv_spike.py` | Spike 发现/构建元数据/运行 + `--log-commits` 归一化（跳过 boot ROM、HTIF 存储截断） |
| `rv_dut.py` | DUT 侧适配器协议（`dump:`/`model:`/`callback:`）+ `--inject` 故障注入 |
| `rv_model.py` | 示例 DUT：**位精确 RV64IMC 解释器**（I+M+整数 C），越界指令显式报错 |
| `rv_difftest.py` | CLI + 比较器：按 cycle→pc→rd→value 顺序报告**首个分歧**，退出码 0/1/2 |
| `corpus/` | 4 个自检 bare-metal **RV64IMC ELF**（`-nostdlib -mcmodel=medany`，链接于 `0x80000000`，HTIF tohost 退出）+ 构建脚本 |
| `tests/` | 121 个 pytest（含"模型 vs Spike 逐提交"谐波 capstone、CLI 退出码契约、4 个 ELF 的 Spike 端到端） |
| Spike 构建 | `1.1.1-dev` @ `1e05ddac`（generated/，gitignored）+ **dtc 1.8.1**（Spike 运行时 shell-out，缺则无法启动 ELF——环境坑已记录并自动注入 PATH） |

## 2. 验证（本人独立复跑）

- ✅ `make verif-rv`（新增目标）→ corpus 构建 + **121 passed**。
- ✅ `rv_difftest.py --elf cor_alu.elf --dut model:…` → `MATCH: 221 commits compared, 0 divergence`，**exit 0**；
  agent 侧另有 cor_mem 169 / cor_muldiv 105 / cor_model 116 commits 全 MATCH。
- ✅ 故障注入：`--inject 12:value=0xdeadbeef` → `DIVERGENCE (value_mismatch) at commit #12 (cycle 13): pc=0x…3e rd=x12`
  + golden/dut 明细，**exit 1**（本人复跑确认退出码）；`--inject 7:rd=x9` 同类；畸形轨迹 exit 2。
- ✅ `ruff` + `mypy --strict` 干净（13 个源文件）。
- ✅ **工具有效性证据**：差分环自身抓出并修复 5 个真实缺陷（C.J 立即数 bit5 缺失 → 压缩跳转短 32 字节；
  mulh/mulhsu/mulhu 返回低半字；c.addi16sp 位映射错；hex 字节序/字序不符；两处语料自检 bug）。

## 3. 明确边界（下一增量）

- ⚠️ **内存访问尚未比对**（Spike `mem` 日志已在 `Commit` 预留字段）—— 最高价值的下一个增量。
- ⚠️ 无 CSR/trap 流（RV-C 的 Sv39/中断需要）。
- ⚠️ 当前为**事后提交差分**，非实时锁步 stepper（`rv_dut`/比较器可原样复用）。
- ⚠️ 示例 DUT 是文档化子集解释器（超出即显式报错）—— 真实 DUT 是未来的 `eth_rv` RTL。

## 4. 下一阶段需要做的内容

- **E2-RV1（RV-B 核）** — 前置已就绪；RTL 前需补 `ethereal-plan/components/` 的 `eth_rv` 组件级规范（当前不存在），
  按 S15 §2.2 从 RV-B（RV64IMC 顺序 5-6 级）起步；工具链缺口已探明（无 rv64imc multilib，`-nostdlib` 下不影响）。
- **E2-RV0 增量** — 内存访问比对 + CSR/trap 流 + 实时锁步（RTL 就位后）。
