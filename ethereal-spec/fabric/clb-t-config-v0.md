# CLB-T Configuration & IIB — v0 (draft)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0**
> Plan-Ref: `ethereal-plan/components/C01-fabric-核心单元.md §2` · Date: 2026-07-24

Spec for the **CLB-T** tile (N eLUT4 + IIB input crossbar) — the v1 fabric
placement unit. Single source of truth for the frame-map generator (`S02-P0#1`),
OCC (`E0-FAB4`), and the RTL (`ethereal-fabric/rtl/clb/clb_t.sv`).

## 1. v1 parameters (frozen, VPR-refined later in E0-MAP2)

| Param | v1 | Meaning |
|---|---|---|
| `N` | 8 | eLUT4 count per cluster |
| `K` | 4 | eLUT4 input width |
| `EXT_IN` | 18 | external cluster inputs (from CB) |
| `I` | 26 | total cluster inputs = EXT_IN + N (18 external + 8 feedback) |
| `POOL` | 32 | next-pow2 ≥ I (mux index space, zero-padded) |
| `SELW` | 5 | mux select width = $clog2(POOL) |

## 2. Interface (frozen v1, C01 §2.3)

| Signal | Dir | Width | Meaning |
|---|---|---|---|
| `clk_i / rst_ni` | in | 1/1 | user clock / reset |
| `clb_in_i` | in | 18 | external inputs (from CB) |
| `clb_out_o` | out | 8 | cluster outputs (to SB & adjacent CB) = the N eLUT outputs |
| `cfg_we_i` | in | 1 | cluster config write enable |
| `cfg_addr_i` | in | 6 | intra-cluster address |
| `cfg_data_i` | in | 32 | config word |

## 3. cfg addressing

| `cfg_addr_i` | Target | `cfg_data_i` bits used |
|---|---|---|
| `0 .. N-1` (0..7) | eLUT4 #(addr) | `[19:0]` (see `elut4-config-v0.md`) |
| `N .. N+N·K-1` (8..39) | IIB mux #(addr-N) | `[SELW-1:0]` (= `[4:0]` for v1) |
| `≥ 40` | reserved | — |

Config-bit total: `N·20 + N·K·SELW = 160 + 160 = 320 bit` (C01 §2.3 estimates
~352 incl. a 6-bit-per-mux budget; v1 uses 5 used bits + 1 reserved per mux).

## 4. IIB — v1 = flat full-input crossbar

**Decision (ASSUMPTION, TBD 2026-07-24):** v1 IIB is a **flat full-input
crossbar** — each of the `N·K = 32` LUT inputs is an `I:1` mux (`I=26`) selecting
any cluster input. This is the only reading consistent with the frozen cfg
interface (32 mux points, no stage-1 config) and is a **superset** of Clos
connectivity (guarantees "any input → any LUT input"). The two-level Clos
(26→16→4) described in C01 §2.2/§2.4 is the **v2 area optimization** (§2.5
Landy/Stitt); the cfg interface is invariant under that swap, so the change is
localized to mux-array internals.

**Cluster input pool:** `{clb_out_o, clb_in_i}` → pool index `0..EXT_IN-1` =
external, `EXT_IN..I-1` = feedback from eLUT #(idx−EXT_IN). Index space is
zero-padded to `POOL=32`.

## 5. Feedback & UNOPTFLAT (C01 §2.4 problem 2)

The N feedback paths form a **structural combinational loop** (pool → LUT inputs
→ eLUTs → clb_out_o → pool). This is *intended* — virtual combinational loops
(latches) are legal user logic. The RTL carries a scoped
`/* verilator lint_off UNOPTFLAT */` waiver around the pool/IIB/eLUT region, so
`verilator --lint-only -Wall` reports **zero** UNOPTFLAT (the expected feedback
loop is waived; any *other* UNOPTFLAT would still surface). The mapper (S10)
will additionally warn on user configs that create real comb loops.

## 6. Open items (TBD, G6)

- Confirm v1 = flat crossbar vs. true two-level Clos (low-rework-reversible).
- CLB-level FF clock-enable (`cfg_ce_i` per eLUT) is tied to `1'b1` in v1 (no
  CLB-level CE in the frozen §2.3 interface); per-bit CE routing deferred.
- IIB delay target ≤ 2 eLUT4 stages (C01 §2.4) — verify post-synth (Phase 1).
