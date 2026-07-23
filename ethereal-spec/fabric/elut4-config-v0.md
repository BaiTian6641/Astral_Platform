# eLUT4 Configuration Bitfield — v0 (draft)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0** (frozen in RTL `ethereal-fabric/rtl/clb/elut4.sv` for task E0-FAB1, pending spec sign-off)
> Plan-Ref: `ethereal-plan/components/C01-fabric-核心单元.md §1.3` · Date: 2026-07-24

This is the machine/human spec for the **eLUT4** configuration word — the atomic
virtual-logic element of the Ethereal Fabric. It is the single source of truth
for the frame-map generator (`S02-P0#1`), the OCC frame writer (`E0-FAB4`), and
the RTL (`elut4.sv`).

## 1. Signals (frozen v1, per C01 §1.3)

| Signal | Dir | Width | Meaning |
|---|---|---|---|
| `clk_i` | in | 1 | fabric user clock (drives the virtual FF) |
| `rst_ni` | in | 1 | user reset, active-low (gated by `ff_rst_en`) |
| `vin_i` | in | 4 | virtual 4-bit input |
| `vout_o` | out | 1 | virtual output (combinational or registered) |
| `cfg_we_i` | in | 1 | config write enable (1 cycle when this unit is selected) |
| `cfg_data_i` | in | 20 | `{tt[15:0], ff_en, ff_rst_en, ff_rst_val, out_inv}` |
| `cfg_ce_i` | in | 1 | virtual FF clock-enable (maps the user CE) |

## 2. cfg_data_i bitfield (20 bit) — MSB→LSB per C01 concat order

| Bits | Field | Width | Meaning |
|---|---|---|---|
| `[19:4]` | `tt` | 16 | truth table; `comb_out = tt[vin]` (16:1 mux) |
| `[3]` | `ff_en` | 1 | 1 = register the LUT output through the virtual FF |
| `[2]` | `ff_rst_en` | 1 | 1 = the active-low user reset (`rst_ni`) affects the virtual FF |
| `[1]` | `ff_rst_val` | 1 | value loaded into the virtual FF on reset |
| `[0]` | `out_inv` | 1 | 1 = invert the final output (free inverter, saves a LUT) |

## 3. Behavior

```
comb_out = tt[vin]
if (ff_rst_en && !rst_ni)  vff <= ff_rst_val          // sync reset, priority over CE
else if (cfg_ce_i)         vff <= comb_out
mux  = ff_en ? vff : comb_out
vout = out_inv ? ~mux : mux
```

- **Configuration persistence**: `tt` / `ff_en` / `ff_rst_en` / `ff_rst_val` / `out_inv`
  are written ONLY via `cfg_we_i` and **persist across** `rst_ni` (user reset never
  clears fabric configuration).
- **Output during config**: when `cfg_we_i=1` the output is **undefined by design**;
  the OCC guarantees the region is blank/halted during configuration (C01 §1.4).

## 4. Open items (TBD, G6)

- **Reset polarity/style**: v1 uses **synchronous** active-low reset. Confirm against
  the authoritative SystemVerilog RTL Policy doc (not yet linked, `ethereal-plan/README.md §4`).
- **v2 truth-table storage**: switch `tt` from FF+16:1 mux to `eth_inf_lutram`
  (distributed-RAM inference) — pending C13 §6 inference-verification (Phase 1).
