# 验收报告：Phase-1 异构 Fabric — Stage 5a（异构映射基础设施）

> 日期：2026-07-28 · 执行者：agent（Yosys flow 自调自验；VPR arch 经 sub-agent，本人核验 + 补 synth 测试）· 关联：Stage 5a（P1 异构 fabric）；前置 Stage 4（frame_map/fabric_gen）；C02 §1.6/§2.6（异构 tile 测试/评估）
> 交付物：`synth_ethereal.py`（heterogeneous flow）+ `arch_ethereal.xml`（+mult/mem tiles）+ `test_synth_ethereal.py`（+4 异构测试）

---

## 1. 本阶段实现内容

| 检查点 | 状态 | 证据 |
|---|---|---|
| Yosys **DSP/RAM 推断**（heterogeneous flow） | ✅ | RAM→1 `$mem_v2`；multiply→1 `$macc_v2`；c432→63 $lut+0 hard |
| VPR **异构 arch**（+mult_27x18 + mem_2Kx32 tiles） | ✅ | interleaved columns（mult 每 4th，mem 每 5th） |
| 既有基准在异构 arch 上仍路由 | ✅ | **c432 CPD 5.30ns, Fmax 188.7MHz** |
| 异构 synth 测试（RAM/MAC/c432-no-hard/homogeneous） | ✅ | 8 synth 测试全过 |
| 既有套件无回归 | ✅ | lint OK / 9 SV TB / **2602 passed** |

## 2. 关键设计

### 2.1 Yosys 异构 flow（VALIDATED）

```
proc → opt → memory -nomap → opt → alumacc → opt → simplemap → abc -lut 4
```

- `memory`：把 RAM 数组收集成 `$mem_v2`（→ mem_t，EDA 推断 BSRAM）。
- `alumacc`：把乘法收集成 `$macc_v2`（→ dsp_t，EDA 推断 DSP）。
- `simplemap`：把剩余通用逻辑映射为门级（**不用 `techmap`/`maccmap`**——maccmap extmapper 会把 `$macc_v2` 分解掉）。
- `abc -lut 4`：只 LUT 化通用逻辑；`$mem_v2`/`$macc_v2` 不受影响。

**踩坑（本人逐一验证）：** (a) `synth`/first-`abc` 在 `memory`/`alumacc` 之前就把 `$mem`/`$mul` 映射成门 → 收集不到；(b) `techmap`/`maccmap` 分解 `$macc_v2`（"Using extmapper maccmap"）→ 用 `simplemap`；(c) `proc`-only 不映射通用逻辑（c432 的 `$and/$not` 保留）→ `simplemap` 补上。

### 2.2 VPR 异构 arch

- **`mult_27x18`（dsp_t）**：`blif_model=".subckt $macc_v2"`，ports A[26:0]/B[17:0]/Y[47:0]。
- **`mem_2Kx32`（mem_t）**：`blif_model=".subckt $mem_v2"` + 自定义 `<model name="$mem_v2">`（Yosys 的 `$mem_v2` 是**双口** RD_*/WR_*，与 VPR 内建 `single_port_ram` 单口模型不匹配 → 自定义 model），`class="memory"` 让 VPR 打包。
- **布局**：interleaved columns（mult 每 4th，mem 每 5th）—— Xilinx ASMBL / Intel sector 的 column-per-N 风格（研究确认）。
- `<models>` 声明 `$macc_v2`/`$mem_v2`（VPR 对未声明的 .subckt 报 "Failed to find matching architecture model"）。

## 3. 验证（本人）

- **Yosys**：RAM→`$mem_v2`（43 LUT，非 56453！），multiply→`$macc_v2`，c432→63 `$lut`（≈62）+ 0 hard。homogeneous 路径回归 62。
- **VPR**：c432 在新 arch 路由（CPD 5.30ns, Fmax 188.7MHz，≈原 195.66 略降因 tile 混合）。
- **测试**：8 synth 测试全过（含 4 新异构）；full suite lint OK / 9 SV TB / 2602 passed。

## 4. 待确认（ASSUMPTION）

1. **🟡 VPR 打包 $macc_v2/$mem_v2 到 tiles**：arch 已声明 tile + model；**VPR 能否实际把一个 MAC/RAM 电路打包放置到新 tile** 需在 Stage 5b（异构 bitgen + 一个真实 MAC/RAM 电路走 VPR）验证—— 本阶段证明 arch 可加载 + 既有基准路由。
2. **🟡 $mem_v2 双口 vs mem_t 单口**：Yosys `$mem_v2` 是双口（RD+WR），mem_t 是单口（va/vd/vwe）—— 映射时取 WR 口写 + RD 口读（或声明单口几何）；arch model 需对齐（Stage 5b bitgen 处理）。
3. **🟡 新 tile 的 fc**：宽 tile 的 fc 取值（接入路由的引脚比例）暂用启发值；Stage 5b 路由真实 MAC/RAM 电路时调优。

## 5. 下一阶段

| 任务 | 内容 | 依赖 |
|---|---|---|
| **Stage 5b** | **vbus→虚拟路由集成**（tile 数据经 SB/CB 到 CLB，宽 vbus-mux 层）+ 异构 bitgen（$mem_v2/$macc_v2 打包到 tile + 路由）+ 一个真实 MAC/RAM 电路走 VPR 验证 | 本（infra 就绪） |
| Stage 6 | **fir16 on DSP-T 链**（C02 §2.6 ≥10×）+ **aes on MEM-T**（S-box ROM）→ 接受基准 | Stage 5b |

> 本阶段打通异构映射基础设施：Yosys 现在把 RAM/乘法推断为 `$mem_v2`/`$macc_v2`（EDA 硬块），VPR arch 有了对应 tile（既有基准不受影响）。下一步 vbus→路由 + 异构 bitgen，让真实电路用上这些 tile。
