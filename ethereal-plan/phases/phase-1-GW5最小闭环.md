# Phase 1 · GW5 最小闭环（M2-M5）★第一个对外里程碑

> 目标：Tang Mega 138K 上完成"Gowin 上跑逻辑容器"最小闭环——BMC 软核运行 daemon，ethctl 一键部署，双 region 热替换，SPI+I²C 双通道对外，v0.1.0 公开发布。
> 预算：约 150~220 人时。涉及子系统：S12/S05/S04/S02/S06/S07/S08/S09/S01/S14。

## 1. 作战序列

### 第 1-3 周：硬件地基（BSP）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 1 | `hal/gowin_gw5` 原语映射 | E1-PLT1 | CFU memory 模式/BSRAM/DSP 推断核对；开销比 ≤45:1 并记录实际值 |
| 2 | Base 构建流 + 约束模板 | E1-PLT2 | 一键构建；SPI 读出 Shell magic |
| 3 | Apicula 备选链评估 | E1-PLT4 | 可行性结论 |

### 第 2-5 周：BMC（与 BSP 并行）
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 4 | BMC SoC 集成（NEORV32+ROM/RAM+UART+EBI 桥） | E1-BMC1 | 仿真+GW5 hello-world；开销报告 |
| 5 | 固件框架（boot 双分区+驱动+lifecycle 骨架） | E1-BMC2 | UART 启动；FW 自更新 |
| 6 | 调试通道（UART+JTAG 排针+OpenOCD） | E1-BMC3 | **GDB 断点成功，零付费工具** |
| 7 | EMRI 寄存器面 + 模式探测 | E1-BMC4 | ethctl 自动识别 BMC/mFSM |

### 第 4-6 周：通道与代理
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 8 | SPI 数据通道（SDI+EFP-SPI 固件栈） | E1-IO1 | 上位机经 SPI 完整部署；CRC 注入通过 |
| 9 | I²C 监控通道 v1（TWD+PMBus 命令） | E1-IO2 | 树莓派 i2cget 读 slot；24h 轮询无锁死 |
| 10 | L1 引脚 mux v1 + Board Manifest | E1-IO3 | PWM 任意两组引脚，示波器验证 |
| 11 | UART/GPIO 代理 v1 | E1-IO4 | 115200 无丢字节 |

### 第 5-7 周：运行时
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 12 | ethimg（pack/verify/Ed25519） | E1-RUN1 | 篡改任意字节即失败 |
| 13 | daemon v1（验签→分配→OCC(DMA)→生命周期） | E1-RUN2 | 四命令全通；异常优雅报错 |
| 14 | ethctl v1 | E1-RUN3 | 30s 部署；--help 自文档 |
| 15 | region 看门狗 | E1-RUN4 | 死锁镜像超时 blank，邻区无损 |

### 第 7-10 周：演示与发布
| 序 | 任务 | ID | 检查点 |
|---|---|---|---|
| 16 | 三演示镜像（PWM/UART 回显/AES-128） | E1-DMO1 | 热替换 <10ms(BMC+DMA) / <100ms(SPI) |
| 17 | 10k×2 热替换稳定性 | E1-DMO2 | 零损坏零干扰 |
| 18 | 上板 CI（self-hosted runner） | S14-P1#1 | nightly 上板全过 |
| 19 | v0.1.0 发布（视频+博客+文档站） | E1-DMO3 | 仓库公开 |

## 2. 并行度说明（团队化扩展点）
若 2 人：A 线（1-3、10-11，硬件/IO）+ B 线（4-7、8-9、12-15，BMC/运行时），第 7 周汇合做 16-19，可压缩至 M2-M3.5。

## 3. 退出标准与熔断

**退出**：§1 全部检查点通过；开销比/Fmax 实测公开（哪怕不理想）；v0.1.0 发布；P1 验收报告（README §3 模板 + mermaid 图）。

**熔断**：BMC 固件通道受阻 → 临时以上位机直驱 EMRI/OCC 保底（mFSM 语义先行，E2-BMC1 提前）；fabric 开销比 >60:1 → 缩小演示 fabric（3×3）保里程碑，优化顺延 Phase 2。

## 4. 发布清单（E1-DMO3 明细）
- [ ] GitHub 仓库公开（8 仓库 + README 导航）
- [ ] 3 分钟演示视频（ethctl run→热替换→I²C 监控一镜到底）
- [ ] 博客《在 Gowin 上运行 FPGA 逻辑容器》（含实测数据表）
- [ ] 文档站（快速开始/镜像作者指南/架构总览/常见问题）
- [ ] 社区发布：Reddit r/FPGA、Hackaday、Gowin/Sipeed 社区、中文渠道（电子森林/硬禾/知乎）

## 5. 本阶段高风险与关键词
- Gowin EDA 脚本化 → `Gowin gw_sh tcl batch`
- LUTRAM 推断 → `Gowin distributed RAM inference`
- I²C stretching 兼容 → `Raspberry Pi I2C clock stretching bug`
- NEORV32 综合 → `neorv32-setups osflow gowin`
