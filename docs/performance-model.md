# Ethereal Fabric Performance Model

> Plan-Ref: ethereal-plan/subsystems/S02-OCC与配置体系.md (OCC) · task E0-SHL3 (`docs/ethereal-tasks.yaml`)
> Status: v0.2 · 2026-09-02 · **interconnect v2c** (frozen spec `interconnect-config-v0.md` §7, E2-FAB5)
> · All numbers below are produced by `ethereal-tools/tools/perf_model.py`
> (run: `python3 ethereal-tools/tools/perf_model.py`) or cited from an archived acceptance report.

---

## 1. Configuration size model

### 1.1 Bitfield budget per tile (v2c fabric)

The single source of truth is `frame_map.FrameMap` (`ethereal-tools/tools/frame_map.py`), which also generates
`frame_map.json` consumed by bitgen / OCC / readback. Per-tile config point widths are the frozen v2c
bitfields (spec §7.4) matching the RTL and specs:

| Block | Points | Width (bits) | Arithmetic |
|---|---|---:|---|
| CLB-T logic | 8 eLUT4 × 20 + 32 IIB-mux × 5 | 320 | 8×20 + 32×5 (count unchanged; IIB sel semantics = §7.2) |
| Switch box (Wilton + bidir-inject) | 48 × 2-bit sel + 8 inj_en + 8 inj_dir × 2 | 120 | 4×12×2 + 8×1 + 8×2 (unchanged, §7.3) |
| Connection block | 18 × 5-bit sel | 90 | 18×⌈log₂(4·12/2)⌉ = 18×5 (v2c §7.1, was 108) |
| **Tile total** | | **530** | 320 + 120 + 90 (was 548, −18) |

A **frame = one column** of tiles' config bits, 32-bit-word packed, plus a **CRC16 tail word** (CRC-16/CCITT-FALSE)
appended as one extra 32-bit word (field [15:0]).

### 1.2 Frame geometry (homogeneous, R rows)

```
bits_per_col = R × 530
data_words   = ⌈bits_per_col / 32⌉
frame words  = data_words + 1            (CRC tail word)
image        = C frames × frame words × 4 bytes
```

### 1.3 Computed sizes (perf_model.py output)

| Fabric | bits/col | data words | words/frame (+CRC) | frames | Image words | Image bytes |
|---|---:|---:|---:|---:|---:|---:|
| 2×2 homogeneous | 2×530 = 1060 | 34 | 35 | 2 | 70 | **280 B** |
| 4×4 homogeneous | 4×530 = 2120 | 67 | 68 | 4 | 272 | **1088 B** |
| 2×2 hetero (col0: MEM+CLB, col1: DSP+CLB) | 810 / 858 | 26 / 27 | 27 / 28 | 2 | 55 | **220 B** |

Heterogeneous note: per C03 §1 each frame (column) carries its own length — `column_data_words(col)`; the 2×2-het reference
layout (`fabric_2x2_het.yaml` layout col0=[MEM,CLB], col1=[DSP,CLB]) gives 810-bit / 858-bit columns
(MEM tile = 90+120+70 = 280, DSP tile = 90+120+118 = 328, CLB tile = 530 — CB+SB are in every column, so
the 548→530 shrink moves the het columns too), 26/27 data words + CRC tail. Matches
`generated/fabric_2x2_het/frame_map.json` (`per_column_data_words=[26, 27]`), verified by perf_model.py
against the tracked artifact.

## 2. OCC latency model

### 2.1 Cycle counts from the FSM (occ_top.sv, two-segment FSM, 1 word/clock streaming)

From `occ_top.sv`: after the command-accept cycle, ST_WRITE streams one word per clock while
`wdata_valid_i & wdata_ready_o`; plus 1 accept + 1 DONE cycle:

| Command | Cycles |
|---|---|
| WRITE frame (N words) | N + 2 |
| BLANK frame (N words) | N + 2 |
| READBACK frame (N words) | N + 3 (extra CMP cycle) |

Whole-image time (one OCC command per frame, sequential, no backpressure, 1 word/cycle streaming):

```
T_write(f_occ)          = Σ_cols (N_col + 2) / f_occ
T_blank(f_occ)          = Σ_cols (N_col + 2) / f_occ
T_hot_swap(f_occ)       = T_blank + T_write
T_verified(f_occ)       = T_blank + T_write + T_readback   (+1 per frame for CMP)
```

For the 4×4 homogeneous fabric (N = 68 words/frame):

| Operation | Cycles | @ 50 MHz | @ 100 MHz |
|---|---:|---:|---:|
| Full-image WRITE | 4×(68+2) = 280 | 5.60 µs | 2.80 µs |
| Hot-swap (BLANK+WRITE) | 560 | 11.20 µs | 5.60 µs |
| Verified hot-swap (+READBACK) | 844 | 16.88 µs | 8.44 µs |

(v2c §7.7 migration note: the v1.1 figure was 868 cycles at 70-word frames; the spec §7.7 parenthetical
"868 cyc" is that stale v1.1 number — the recomputed v2c value at 68-word frames is **844**.)

## 3. Config-path latency budget vs Phase-1 targets

```mermaid
flowchart LR
    H["Host image bytes<br/>4x4 = 1088 B"] --> SPI["SPI link<br/>20 MHz bit-serial<br/>435.2 µs"]
    SPI --> BMC["BMC staging<br/>(word buffering)"]
    BMC --> OCC["OCC write engine<br/>1 word/cycle"]
    OCC --> FB["Frame bus<br/>fbus_we 1/cycle"]
    FB --> COL["Column config storage"]
```

| Path | Budget term | Value |
|---|---|---|
| Host → SPI @ 20 MHz | 1088 B × 8 / 20 MHz | 435.2 µs |
| Host → SPI @ 10 MHz | | 870.4 µs |
| Host → SPI @ 50 MHz | | 174.1 µs |
| OCC write @ 50 MHz | 280 cyc | 5.60 µs |
| OCC hot-swap (blank+write) @ 50 MHz | 560 cyc | 11.20 µs |
| OCC verified hot-swap (+readback) @ 50 MHz | 844 cyc | 16.88 µs |

**Conclusion:** the 4×4 image (1088 B, was 1120 B) is dominated by the transport link, not the write engine. Even
the pessimistic host path (SPI 10 MHz → 0.870 ms) beats the < 100 ms host-SPI target by > 100×;
the BMC+DMA path (~17 µs) beats the < 10 ms target by ~500×. Per-frame command
overhead (2–3 cycles/frame) is negligible until frames per image ≫ 100.

## 4. Virtual Fmax (v0 estimate)

| Circuit | CPD | Fmax | Source |
|---|---:|---:|---|
| c432 (62 eLUT4, W=12, v1.0 VPR arch) | 5.111 ns | **195.66 MHz** | report-E0-MAP2-20260725 |
| c17 (smoke) | 0.690 ns | 1449 MHz | report-E0-MAP2-20260725 |

Caveats (ASSUMPTIONs, TBD 2026-09-01):
1. **90 nm PTM delays** inherited from the VPR k4_N4 template — not silicon
   characterised; Phase-1+ must re-time against GW5 route delays.
2. **VPR arch models v1.0** (subset/disjoint SB). The production fabric is now **v1.1 Wilton + bidir-inject**
   (incr4c); Wilton mux delays are **not re-characterised in VPR** — Fmax delta unknown, expected
   small (Fs stays 3, one mux level) but unproven. Open item: re-characterise arch_ethereal.xml
   with `switch_block type=wilton` + re-run c432.
3. Het tiles: `dsp_t` MAC pipeline latency is image-selectable via mode word
   `lat_sel[1:0]` = 0–3 cycles (eth_inf_dsp_mac); cascade chains shift Fmax
   pressure to the 27×18 behavioural MAC inference (ADR-017).

## 5. Open items

- 🟡 Re-run VPR with Wilton arch; report Fmax delta (E0-MAP follow-up).
- 🟡 Post-P&R virtual Fmax on GW5 hal path (E1-PLT1 outcome).
