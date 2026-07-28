# Heterogeneous Fabric Frame Layout — v0 (Phase-1, Stage 4)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0** (frozen per-tile-type config points)
> Plan-Ref: `ethereal-plan/components/C02-fabric-异构tile.md §1.3 §2.3 §5` · Date: 2026-07-28
> Source of truth for: frame-map generator, bitgen, OCC, readback (heterogeneous tiles).

Spec for the **heterogeneous** fabric frame layout (MEM_T / DSP_T alongside CLB_T).
Homogeneous layout (all-CLB) is in `interconnect-config-v0.md` and is UNCHANGED.

## 1. Tile composition (C02 §5)

Every tile = **base interconnect (CB + SB)** + a **logic tile** by `TILE_TYPE`:

| `TILE_TYPE` | logic tile | config via cfg unit |
|---|---|---|
| `0` | CLB-T (8 eLUT4 + IIB) | unit `2'b00` (clb_t) |
| `1` | MEM-T (virtual block RAM) | unit `2'b11` (TILE-MODE) |
| `2` | DSP-T (virtual 27×18 MAC) | unit `2'b11` (TILE-MODE) |

The CB (`connection_block`) + SB (`switch_box`) config points are **identical across
all tile types** (units `2'b01` SB, `2'b10` CB) — only the logic-tile config differs.

## 2. Per-tile-type LOGIC config points (frozen v0)

### 2.1 CLB-T (`TILE_TYPE=0`) — unchanged from `interconnect-config-v0.md`
`elut{0..7}` (20 bit) + `iib_mux{0..31}` (5 bit) = 320 bit.

### 2.2 MEM-T (`TILE_TYPE=1`) — C02 §1.3 frozen interface
| point | width | cfg (unit 11) | meaning |
|---|---|---|---|
| `mem_mode` | 16 | intra=0 | mode word (`mode_r`, reset-less/persists) |
| `mem_vbus_ctrl` | 22 | intra=1 | `va_i[13:0]`@[13:0], `ven_i`@[16], `vwe_i[3:0]`@[21:18] |
| `mem_vd_i` | 32 | intra=2 | write data / ROM-init (OCC `rom.hex`, C02 §1.4) |
| **total** | **70** | | |

### 2.3 DSP-T (`TILE_TYPE=2`) — C02 §2.3 frozen interface
| point | width | cfg (unit 11) | meaning |
|---|---|---|---|
| `dsp_mode` | 24 | intra=0 | mode word (`acc`=mode[0], `lat_sel`=mode[2:1]) |
| `dsp_va` | 27 | intra=1 | operand A (27-bit) |
| `dsp_vb` | 18 | intra=2 | operand B (18-bit) |
| `dsp_ven` | 1 | intra=3 | virtual enable |
| `dsp_vcasc` | 48 | intra=4/5 | cascade-in (hi[47:16] / lo[15:0]) |
| **total** | **118** | | |

## 3. Frame geometry (C03 §1 — PER-COLUMN variable length)

A frame = one column of tiles' config bits + a CRC16 tail. With heterogeneous
tiles, **column width varies by that column's tile mix**; the OCC frame-write
engine uses the per-column length (`column_data_words(col)`), matching the C03 §1
"frame header carries a length field" note.

- tile(col,row) bits = `CB(108) + SB(120) + logic(col,row)`.
- Example 2×2 (tile_types = `[["mem_t","clb_t"],["dsp_t","clb_t"]]`, matches
  `fabric_2x2_het.yaml`): col0 = 298+548 = **846 bit** (27 data words),
  col1 = 548+346 = **894 bit** (28 data words).

## 4. fabric.yaml declaration

```yaml
tile_types:                # [col][row] -> "clb_t"|"mem_t"|"dsp_t"
  - ["mem_t", "clb_t"]     # column 0
  - ["dsp_t", "clb_t"]     # column 1
```
`fabric_gen` maps this to the `fabric_top` `TILE_TYPE` parameter (8-bit entries,
LSB-first, entry `r*C+c` row-major) + emits the heterogeneous frame_map.json
(`heterogeneous.tile_layout` + `logic_points` + `per_column_data_words`).

## 5. Layout guidance (C02 §5, research-confirmed)

Interleaved columns (Xilinx ASMBL / Intel sector style): a DSP or BRAM column
every 2-4 CLB columns. Small v2 example (C02 §5 region L): 4×8 CLB + 2 DSP-T +
2 MEM-T. The TILE_TYPE vbus width is fixed by the block's widest pin group
(research: real FPGAs do NOT shrink the hard-block datapath to CLB width).

## 6. Open items (TBD)

- vbus → virtual-routing integration (tile data through SB/CB to CLBs) — Stage 5.
- MEM-T full geometry modes (RAM/ROM/FIFO/dual-port) — v0 implements basic RAM;
  `mem_mode`[2:0] geometry is reserved (C02 §1.3).
- DSP-T cascade-chain (FIR16 = 16 DSP-T in cascade) — Stage 5/6.
- SSM-T (shadow-SRAM window) — C02 §3, deferred.
