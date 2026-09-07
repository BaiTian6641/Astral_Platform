# BMC core — vendored NEORV32 (GHDL-converted Verilog) + bmc_core wrapper

> ADR-016 swappable BMC core boundary. NEORV32 (primary, BSD-3) in a `bmc_core`
> SystemVerilog wrapper; VexRiscv fallback is a later core-swap (E2-BMC2).
> G6 resolution: see `/memories/repo/neorv32-sim-path.md` (Option A).

## Contents

| File | What |
|---|---|
| `neorv32_verilog_wrapper.v` | **Vendored, machine-generated** all-Verilog netlist of NEORV32 (NOT hand-written RTL; NOT G1-linted). See its header for full provenance. |
| `LICENSE.neorv32` | NEORV32 BSD-3-Clause license (retained per its terms). |
| `bmc_core.sv` | Hand-written thin SV wrapper (the ADR-016 swappable boundary). **This is the only G1-clean file here.** |
| `README.md` | This file. |

## Vendored snapshot (FROZEN)

- **Upstream:** https://github.com/stnolting/neorv32
- **Version:** v1.13.3.2 (hw_version `0x01130302`), commit `05f9896`, branch `main`
- **Generation:** `cd rtl/verilog && make convert` (GHDL `synth --out=verilog`),
  wrapper `rtl/verilog/neorv32_verilog_wrapper.vhd` (record ports → scalars).
- **Generated on:** 2026-07-30 with GHDL 7.0.0-dev (LLVM backend), OSS-CAD Suite.

### Wrapper generic config (MINIMAL skeleton)
| Generic | Value |
|---|---|
| `RISCV_ISA` | rv32imc |
| `IMEM` | 16 KB, **ROM boot** (`BOOT_MODE_SELECT=2`, IMEM image, no bootloader) |
| `DMEM` | 16 KB |
| Peripherals | **UART0 only** (XBUS/EBI/SPI/I2C/DMA/OCD all OFF) |

**Why minimal:** this is a *sim-path skeleton* to prove the real rv32 core
co-simulates with the SystemVerilog fabric in iverilog/Verilator. The full BMC
services (XBUS/EBI master to EMRI, SPI/I2C monitors, DMA, JTAG OCD, 64 KB
IMEM/DMEM, flash dual-partition boot) are documented deferrals — see
`docs/reports/report-P1-bmc-neorv32-sim-20260730.md`.

## Regenerating (needs GHDL)

```bash
git clone https://github.com/stnolting/neorv32 /tmp/neorv32   # pin to the same commit
cd /tmp/neorv32/rtl/verilog
# edit neorv32_verilog_wrapper.vhd generics to the desired config
make convert            # GHDL -> verilog
# then re-prepend the provenance header and refresh this README + the header's
# commit/date/config. NOTE: the IMEM ROM array name in the netlist changes on
# regeneration — update tb_bmc_hello.sv's $readmemh backdoor path accordingly.
```

**Do NOT hand-edit `neorv32_verilog_wrapper.v`** — regenerate instead.

## Sim

`tb_bmc_hello` (`make test-sv`) preloads a hand-crafted rv32 "HI\n" image
(`ethereal-tools/tools/gen_bmc_hello.py`) into the IMEM ROM via a backdoor and
asserts the UART0 TX waveform decodes to "HI\n". The IMEM preload path is
`dut.u_core.neorv32_top_inst...imem_rom_inst.n6830` — stable while the netlist
is frozen; recompute it if the netlist is regenerated.

## Notes (append-only)

- **2026-09-01 — E1-BMC1 IMEM regen spike** (report:
  `docs/reports/report-E1-BMC1-imem-regen-20260901.md`):
  - ⚠️ The vendored netlist's IMEM ROM is **physically 1 KiB** (`imem_rom` reads
    `addr_i[9:2]`, array `n6964[255:0]`), NOT the 16 KiB the config table above
    implies. Root cause: upstream `neorv32_imem_rom.vhd` sizes the physical ROM
    from `image_size_c` in `neorv32_imem_image.vhd` (default 796 B → 1 KiB);
    `IMEM_SIZE` only sets the address-decode window + an overflow assert.
  - The documented flow above was reproduced **byte-identically** on this machine
    (GHDL 7.0.0-dev in `~/oss-cad-suite`, upstream commit `05f9896`); the exact
    wrapper config was recovered (incl. `RISCV_ISA_U=true`, undocumented).
  - A 16 KiB candidate netlist was generated and validated (lint + tb_bmc_hello
    swap-test + >1 KiB exec probe): `generated/imem_regen/neorv32_verilog_wrapper_imem16k.v`.
    Its ROM array is still named `n6964` (now `[4095:0]`, reads `addr_i[13:2]`),
    so all existing TB backdoor paths stay valid. **Not yet integrated** —
    swap-in is a maintainer decision (see the report's runbook + checklist).
