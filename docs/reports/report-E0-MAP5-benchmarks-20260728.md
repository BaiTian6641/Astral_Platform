# 验收报告：E0-MAP5 — 基准电路集 + v1.1 可布性表征

> 日期：2026-07-28 · 执行者：agent（基准 RTL + golden + harness 经 sub-agent；可布性诊断 + 核验本人）· 关联：E0-MAP5（deps E0-MAP3 done）；Phase-0 出口判据 "AES-128/FIR16 bit-true" 的对应任务
> 交付物：`ethereal-images/benchmarks/{pwm,crc32,fir16,present_round,aes128_round}.v` + `bitgen/bench_golden.py` + `bitgen/test_bench_flow.py`
> 结果：**pwm + crc32 bit-true PASS；fir16/present_round/aes128_round 超出 v1.1 可布性（XFAIL，已量化）** ⚠️

---

## 1. 本阶段实现内容

| 检查点 | 状态 | 证据 |
|---|---|---|
| 5 个基准 RTL（combinational-friendly） | ✅ | pwm / crc32 / fir16 / present_round / aes128_round |
| golden 生成基础设施（iverilog golden，多比特端口） | ✅ | `bench_golden.py::golden_comb` |
| 全流程 bit-true harness（mirror c432 acceptance） | ✅ | `test_bench_flow.py`（synth→VPR→DB→Wilton route→FabricSim→golden） |
| **pwm(11 eLUT) + crc32(42) bit-true** | ✅ | 全链路过仿真 fabric 正确 |
| fir16(124)/present_round(128)/aes128_round(4779) 可布性 | ⚠️ | XFAIL，原因已量化（§3） |
| 既有套件无回归 | ✅ | lint OK / 7 SV TB / **2591 passed, 3 xfailed** / ruff clean |

## 2. 基准集（全部 combinational，便于 bit-true）

| 基准 | eLUT4 | 电路 | 状态 |
|---|---|---|---|
| pwm | 11 | `out = count < duty`（8-bit） | ✅ bit-true |
| crc32 | 42 | CRC-32 Ethernet 多项式（8 data + 32 crc） | ✅ bit-true |
| fir16 | 124 | 8-tap 对称 FIR（combinational-over-taps） | ⚠️ 不收敛（拥堵） |
| present_round | 128 | PRESENT 单轮（sBox+pLayer+AddRoundKey） | ⚠️ 不可布（IO 局部性） |
| aes128_round | **4779** | AES-128 单轮（S-box 即 16×256-entry ROM） | ⚠️ 太大（技术映射） |

## 3. 可布性诊断（本人核验）—— v1.1 Wilton 的表征

```mermaid
flowchart LR
  subgraph routes["v1.1 可布（bit-true）"]
    PWM["pwm 11"] & CRC32["crc32 42"] & C432["c432 62"]
  end
  subgraph noroutes["超出 v1.1 可布性"]
    FIR["fir16 124<br/>adder-tree 拥堵<br/>7-node over-subscribe"] 
    PRES["present 128<br/>0 inter-net + 128 PI<br/>input-CB 轨道局部性"]
    AES["aes128 4779<br/>S-box ROM 未映射<br/>abc -lut 4 膨胀"]
  end
  routes -.v1.1 Wilton 天花板.-> noroutes
```

- **fir16**：对称加法树 → 7-node 过订阅，`route(max_iters=300)` 不收敛（`converged=False, overuse=7`）。纯拥堵（不是结构性不可布），但 v1.1（W=12，无 long-wire）消化不掉。
- **present_round**：**0 inter-cluster net**（pLayer 置换 = 纯 PI→cluster 连接）+ VPR 把 16 tile 打散在 16×16 网格 → 128 个 PI 需注入分散 tile 的任意 `clb_in[k]`，但 **input-CB 只读本 tile 4·W 局部轨道**（input-CB 轨道局部性）→ 无 IO-routing 模型 → 硬不可布（`overuse=0, iters=0`）。
- **aes128_round**：256-entry S-box（ROM）未映射 → `abc -lut 4` 把 S-box 展开成 4779 eLUT4（规模爆炸）。需 ROM 映射 S-box / LUT 共享 / abc 选项，或接受为 Phase-1 大电路测试。

**结论：** v1.1 Wilton fabric（config-contained 的 v1 改进）路由 + bit-true **小/中型 combinational 电路（c432/pwm/crc32）**；FIR/PRESENT/AES 属 **Phase-1 fabric**（IO-routing 模型 + 更大/long-wire 路由 + AES 技术映射）。这不是 fabric 缺陷，而是 v1.1 作为 **流程验证载体** 的可布性天花板的实测表征。

## 4. 待确认（ASSUMPTION / G6）

1. **🔴 E0-MAP5 acceptance 是否满足**：任务验收 = "全部基准经完整流程在仿真 fabric 运行正确"。**未完全满足**（2 过 / 3 不可布）。这是 v1.1 的已表征限制。**maintainer 需定夺**：Phase-0 出口是否要求 5 个全过，还是接受 **pwm + crc32 + c432** 作为流程验证（v1.1 = flow-validation vehicle），3 个大电路留 Phase-1。
2. **🟡 AES 技术映射**：如需 AES bit-true（Phase-0 判据点名 AES-128），需先解 S-box 技术映射（ROM 映射 / LUT 共享）—— 独立工作量，建议 Phase-1。
3. **🟡 IO-routing 模型**：present 暴露 input-CB 轨道局部性 + 无 IO-T → PI 注入受限。Phase-1 需 IO-T + IO→通道的路由模型。

## 5. 下一阶段

| 任务 | 内容 | 依赖 |
|---|---|---|
| **Phase-0 出口定夺（G6）** | maintainer：E0-MAP5 接受部分（pwm+crc32+c432）或要求全 5 | 本报告 |
| E0-SHL1 + E0-SHL2 | EBI-Tiny + 完整 Shell（EBI+OCC+帧总线→fabric 桥） | — |
| Phase-1 fabric v2 | IO-routing 模型 + long-wire + AES techmap → 大电路可布 | P0 出口 |
| CI | Docker ethereal-sim 镜像 parity | — |

> 本阶段交付 5 个基准 + golden 基础设施 + 全流程 harness，并 **实测表征了 v1.1 Wilton fabric 的可布性天花板**（pwm/crc32/c432 bit-true；fir/present/aes 超出）。这是 Phase-0 的关键量化数据，供 maintainer 定夺 Phase-0 出口与 Phase-1 fabric 范围。
