# hal/zynq — Zynq UltraScale+ host mapping layer

> Plan-Ref: `ethereal-plan/subsystems/S15-应用处理器子系统.md` §4 (wrapped DRAM component) ·
> `docs/adr/ADR-018-axi-noc-riscv-cluster.md` §4 (DRAM = per-target wrapped component) ·
> ADR-017 (inference-first: vendor specifics only in `hal/<vendor>/glue/`, always with a
> Verilator-safe stub) · E2-DRAM1.

## Purpose

This is the **only** place where Zynq UltraScale+ specifics for the platform's DRAM path
may live. The SoC never talks to DDR directly: it talks to the standard
`eth_dram_ctrl` AXI4 memory-slave socket (`ethereal-shell/rtl/dram/eth_dram_ctrl.sv`), and
this directory supplies the per-target implementation of that socket's seam.

Note on the spec wording: `S15` §4 / `ADR-018` §4 name the per-target pattern as
`hal/<vendor>/glue/`. For Gowin that concrete directory is
`ethereal-fabric/hal/gowin_gw5/glue/` (the naming introduced by E1-PLT1); for Zynq it is
this directory (`ethereal-fabric/hal/zynq/glue/`) — both live under the repository's
existing `ethereal-fabric/hal/` HAL root, not a new top-level `hal/`.

## Layout

```
hal/zynq/
├── README.md                  ← this file
└── glue/
    └── eth_dram_glue.sv       ← `module eth_dram_glue` (seam provider; E2-DRAM1)
```

## The DRAM seam (E2-DRAM1)

`eth_dram_ctrl` is a pure AXI4 memory-slave socket. Its implementation module is chosen at
build time; `-DETH_DRAM_VENDOR_GLUE` makes it instantiate `eth_dram_glue`, which exactly
one file on the file list must provide — for a Zynq build that is
`glue/eth_dram_glue.sv`. The seam contract (parameters + the complete AXI4 slave channel
set) is written out in full in the `eth_dram_ctrl` header.

| Define | Who uses it | What happens |
|---|---|---|
| *(none)* — DEFAULT | Verilator lint/sim, iverilog TBs, yosys/nextpnr open chain, CI | Behavioral branch: binds `eth_dram_stub` (the behavioral AXI4 memory). The file list must also carry `ethereal-shell/rtl/dram/eth_dram_stub.sv`. |
| `ETH_DRAM_VENDOR_GLUE` | per-target build | `eth_dram_ctrl` binds `eth_dram_glue` from this directory instead of the stub. |
| `XILINX_PS_DDR` | **nothing today** | Documentation-in-code branch: deliberate elaboration-time `$error` — see below. |

### Why the Zynq branch is documentation only

On Zynq US+ the PL reaches DDR through a **PS AXI slave port** (`S_AXI_HP*_FPD` / `HPC`):
the vendor memory is already an AXI4 memory slave from our side of the boundary. The Zynq
DRAM implementation is therefore a **Vivado block-design binding**, not an RTL block, and
the remaining real work is hardware bring-up:

1. confirm the exact Zynq US+ board model (still open — `memory/04-roadmap-phases.md`);
2. enable the PS DDR MC + a PS AXI slave port in the block design (data/ID widths);
3. place `MEM_BASE` / `MEM_BYTES` of the socket inside the PS DDR window;
4. add any needed AXI ID-width adaptation **in `glue/`**, never in the socket or the stub;
5. PS DDR pinout comes from the board preset (no PL DDR LOC constraints).

Until that bring-up happens, the Zynq target runs the same no-DDR-capable simulation path
every other target uses: the behavioral stub bound by `eth_dram_glue`'s default branch.

`XILINX_PS_DDR` exists so a build that believes it selected a real PS DDR binding fails
loudly instead of silently simulating.

## Stub philosophy (ADR-017)

Every DRAM implementation ships a Verilator-safe stub. Here the stub is the default branch
of `eth_dram_glue`: it models exactly what the surrounding own-RTL can observe — the AXI4
handshakes, the `AxLEN/AxSIZE/AxBURST` transfer semantics, WSTRB byte lanes, response codes
and latency — nothing physical. Contract: the default branch elaborates under
`verilator --lint-only -Wall` (clean), `iverilog -g2012` and `yosys read_verilog -sv` with
no vendor library on the file list.

## Standalone verification (this task did not edit the root Makefile)

```bash
export PATH=$HOME/oss-cad-suite/bin:$PATH

# 1. glue standalone, default (stub) branch — Verilator lint, strict:
verilator --lint-only -Wall --top-module eth_dram_glue -Mdir obj_dir/lint_eth_dram_glue_zynq \
    ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-fabric/hal/zynq/glue/eth_dram_glue.sv

# 2. the socket bound to this glue (the per-target path):
verilator --lint-only -Wall -DETH_DRAM_VENDOR_GLUE --top-module eth_dram_ctrl \
    -Mdir obj_dir/lint_eth_dram_ctrl_zynq \
    ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-fabric/hal/zynq/glue/eth_dram_glue.sv \
    ethereal-shell/rtl/dram/eth_dram_ctrl.sv

# 3. the whole DRAM TB through the Zynq seam (same TB, same result):
iverilog -g2012 -DETH_DRAM_VENDOR_GLUE -o /tmp/tb_dram_zynq \
    ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-fabric/hal/zynq/glue/eth_dram_glue.sv \
    ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/axi/tb_eth_dram_ctrl.sv \
  && vvp /tmp/tb_dram_zynq | grep -q "TEST PASSED" && echo PASS
```

## Open items (G6)

1. **Zynq US+ board model unconfirmed** — blocks the PS DDR configuration, the DDR window
   address and the PS port's AXI ID width.
2. `XILINX_PS_DDR` bindings (PS preset name, port widths, ID adaptation) must be written
   against the confirmed board model before any real Zynq DDR build exists.
3. `MEM_BASE = 0x8000_0000` (socket default) is an ASSUMPTION until the SoC memory map is
   frozen; it must match the block design's PS address map.
