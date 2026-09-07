# Switch Box + Channel Interconnect — v0.2

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0.2** (v1.1 = current RTL;
> **v2c FROZEN in §7** for E2-FAB5 implementation)
> Plan-Ref: `ethereal-plan/components/C01-fabric-核心单元.md §3 §5` · Date: 2026-07-24
>
> **Changelog**
> * v0.2 (2026-09-01): added **§7 Interconnect v2c (FROZEN)** — CB Fc=0.5
>   stratified depopulation + feedback-first IIB + SB unchanged (Wilton Fs=3).
>   Tile config width 548 → **530 bits**. Evidence:
>   `docs/reports/report-E2-FAB5-interconnect-opt-20260901.md` (4×4 physical
>   LUT 39,474 → 27,190, −31.1%, c432 routes 5/5 seeds). v1.1 content kept as
>   historical reference; superseded paragraphs are marked inline.
> * v0.1 (2026-07-26): WILTON SB (v1.1) + bidirectional inject.
> * v0 (2026-07-24): initial draft (disjoint SB).

Spec for the fabric interconnect — switch box (SB), channels, and the
`fabric_top` grid. Source of truth for the frame-map generator (`S02-P0#1`),
OCC (`E0-FAB4`), VPR arch (`E0-MAP2`), and the RTL.

## 1. v1 parameters

| Param | v1 | Meaning |
|---|---|---|
| `W` | 12 | tracks per directional channel bundle |
| `R`, `C` | 4, 4 | default fabric grid (parameterized) |
| channel dirs | N, S, E, W | unidirectional (v1; C01 §3.3 problem 2) |

## 2. switch_box (SB) — WILTON track-permuting Fs=3 (v1.1, 2026-07-26)

> **v2c status: UNCHANGED.** §2 remains the current SB spec under v2c (§7.3).

Interface: `in_n/in_s/in_e/in_w`, `out_n/out_s/out_e/out_w` (each `[W-1:0]`);
config `cfg_we_i`, `cfg_data_i`. **mux selects**: `cfg_addr_i[$clog2(4*W)-1:0]`
(= `DIR*W + t`, DIR 0=N,1=S,2=E,3=W), `cfg_data_i[1:0]` (sel). **bidirectional
inject** (Option B, 2026-07-26): `cfg_addr_i = 4*W + j` (j=0..N_INJ-1, N_INJ=N=8),
`cfg_data_i[0]` = `inj_en[j]`, `cfg_data_i[2:1]` = `inj_dir[j]` (0=N,1=S,2=E,3=W);
when `inj_en[j]`, `out_D[j] = clb_out[j]` where `D = inj_dir[j]` (ONE configurable
direction per j) **overriding** the SB sel for that (D, j) pair — the SB
stays the single driver of every track (no multi-drive).

Topology (v1.1, **Wilton**): each output track `t` in direction `D` mux-selects
one of the 3 OTHER directions' input tracks at a **PERMUTED** index (S. Wilton
PhD thesis / VPR `WILTON` formula; Fs=3). A signal therefore **changes track
index at each SB hop**, which breaks the **track-locking** of the prior disjoint
SB (where every net was stuck on track `t = driver_j` for its whole route and
≥2 same-`j` crossing nets were structurally unresolvable — E0-MAP3 incr 4a
Cause 2). The cfg interface (`DIR*W+t`, 2-bit sel) and `frame_map` SB config
points (48×2-bit sel) are **UNCHANGED** — only the per-mux source-track map
moved; `bitgen_pack` / `frame_map` are unaffected.

Per-output source map (sel 1/2/3 → the 3 other dirs in ascending index order;
the **input track index** is the Wilton permutation of `t`):

| output | sel1 | sel2 | sel3 | (sel0 = disconnect/0) |
|---|---|---|---|---|
| `out_n[t]` | `in_s[t]` | `in_e[(t+1)%W]` | `in_w[(W-t)%W]` | |
| `out_s[t]` | `in_n[t]` | `in_e[(2W-2-t)%W]` | `in_w[(t+W-1)%W]` | |
| `out_e[t]` | `in_n[(t+W-1)%W]` | `in_s[(2W-2-t)%W]` | `in_w[t]` | |
| `out_w[t]` | `in_n[(W-t)%W]` | `in_s[(t+W-1)%W]` | `in_e[t]` | |

The single source of truth for this permutation is
`ethereal-fabric/tests/interconnect/sb_model.py::_wilton_track(out_dir, src_dir,
t, W)`; the RTL (`switch_box.sv`) and the Option-B router
(`bitgen_route.py`) both consume it. ~~v2 target: Landy/Stitt two-source-track
ratio up (interconnect area −20%)~~ — **resolved by §7 (v2c): the −20% is
achieved via CB+IIB depopulation; the SB stays Wilton Fs=3.**

## 3. Channels (unidirectional, single-tile length)

`out_D[t]@(r,c) → in_D'[t]@(neighbor)`:
- `out_n → in_s@(r-1,c)` · `out_s → in_n@(r+1,c)`
- `out_e → in_w@(r,c+1)` · `out_w → in_e@(r,c-1)`
Edge tiles' off-grid ports are tied to 0.

## 4. connection_block (input CB) — routable (Step 2) + fabric_top grid

> **v2c status: the CB paragraphs of this section are SUPERSEDED by §7.1**
> (Fc=0.5 stratified depopulation, sel 6→5 bits, subset-index semantics).
> Kept below as the v1.1 historical reference. The `fabric_top` grid wiring
> and cfg_addr `{tile_idx, unit[1:0], intra[5:0]}` layout remain current.

Input-side CB: each `clb_in[i]` (i=0..N_CB-1, N_CB=EXT_IN=18) mux-selects one of
the 4*W local SB output tracks. Config: `cfg_addr_i[$clog2(N_CB)-1:0]` (= i),
`cfg_data_i[$clog2(4*W)-1:0]` (= track index 0..4*W-1). Pool layout
`pool = {out_w, out_e, out_s, out_n}`: index 0..W-1=out_n, W..2W-1=out_s,
2W..3W-1=out_e, 3W..4W-1=out_w. No comb loop (clb_in reads SB outputs). sel_r is
reset-less → OCC zero-inits before run (default sel=0 reads out_n[0], a real track
— NOT a disconnect).

`fabric_top #(R,C,W,N,K,EXT_IN)` instantiates an R×C grid of
`{clb_t, switch_box, connection_block}` per tile wired by the channels above. The
routable CB is COMPLETE: (a) **output** — `clb_out[j]` injects onto `out_e[j]`
via SB inject_en; (b) **input** — each `clb_in[i]` muxes over the 4*W local
tracks via connection_block. cfg_addr layout `{tile_idx, unit[1:0], intra[5:0]}`
with unit 2'b00=CLB / 2'b01=SB / 2'b10=CB. End-to-end routability (CLB→track→CLB)
is proven by `tests/interconnect/fabric_model.py::route_exists`.

## 5. Combinational-loop handling ("4×4 grid, no comb loop")

Any routable fabric's muxes *permit* cycles structurally → Verilator `UNOPTFLAT`
(same family as the CLB feedback, C01 §2.4). Scoped `lint_off UNOPTFLAT` waivers
cover the SB and the `fabric_top` routing region. The **acceptance** ("no comb
loop") = **no functional comb loop in the default/unconfigured grid**, verified
at the graph level by `tests/interconnect/fabric_model.py` (Kahn cycle detection
on the SB-internal + channel edge graph): default config (all sel=0 → no SB
edges) is acyclic for all grid sizes; an acyclic routing stays acyclic; a
4-tile ring is detected; breaking one mux removes the cycle. CB edges (`out_*` →
`clb_in`) end at clb_in sinks and so cannot form a routing cycle. User configs that
create loops are the mapper's responsibility (S10).

## 6. Open items (TBD)

- SB topology finalization (VPR, E0-MAP2 — DONE). v1 was disjoint `subset`;
  **v1.1 (2026-07-26) = WILTON track-permuting Fs=3**, chosen because the
  disjoint SB's track-locking made c432 unroutable (E0-MAP3 incr 4a Cause 2 —
  ≥2 nets sharing driver index `j` were structurally unresolvable). Wilton
  breaks the locking (a net changes track at each hop); see §2. The VPR arch
  token is now `wilton` for parity (the Option-B bitgen router on the hand-built
  fabric is authoritative).
- ~~Cause 2 (disjoint track-locking)~~ RESOLVED by the Wilton SB (v1.1).
- ~~Full CB design (`clb_out → track` injection)~~ DONE — routable CB Step 1+2 (clb_out injection via SB inject_en + input connection_block; single-driver via SB mux override).
- rr_graph → SB/CB/inject_en mux-config mapping (bitgen routing half, E0-MAP3 incr 4).
- Long wires (length>1 tracks) for larger fabrics (v3, C01 §3.4).
- Verilator `UNOPTFLAT` zero-report confirmation (Docker-gated).

## 7. Interconnect v2c — FROZEN (2026-09-01, E2-FAB5)

Frozen target for the interconnect-v2 implementation. Basis: measured evidence
in `docs/reports/report-E2-FAB5-interconnect-opt-20260901.md` (E2-FAB5 spike,
scratch `generated/icopt/`): 4×4 physical LUT 39,474 → 27,190 (−31.1%,
212.4:1 vs v1.1's 308.4:1) with c432 routing 29/29 nets on 5/5 PathFinder
seeds. v2c = **(a) CB Fc=0.5 stratified depopulation × (b) feedback-first
IIB × (c) SB unchanged**.

> **Clarification (scope guard):** v2c does **NOT** reduce the cluster input
> count. All N_CB = EXT_IN = 18 `clb_in` survive; what halves is the *track
> fan-in of each input mux* (48 → 24 tracks). The N_CB-reduction alternative
> (18→9/6) was measured in the spike and **rejected** (18/29 resp. 27/29 of
> c432's inter-cluster nets have sinks on removed pins under the current VPR
> I=18 packing; revisiting it requires an arch-level I reduction + re-pack,
> deferred to v3).

### 7.1 CB v2c — Fc=0.5 stratified depopulation (supersedes §4 CB paragraphs)

Parameters: `W=12`, `N_CB=18`, `CB_DIV=2`. Ports identical to v1.1 except
`cfg_data_i` narrows from 6 to **5 bits** (`[4:0]`).

* **Track pool** (unchanged layout): `pool = {out_w, out_e, out_s, out_n}`;
  `pool[d*W + t] = out_d[t]`, `d ∈ {n=0, s=1, e=2, w=3}` (matches the
  channel/SB dir encoding), `t ∈ 0..W-1`.
* **Mux semantics** (replaces "sel = absolute track index"): each `clb_in[i]`
  (`i = 0..17`) sees the stratified 24-track subset

  ```
  clb_in_o[i] = pool[(i mod 2) + 2*k_i]        k_i ∈ 0..(4*W/CB_DIV)-1 = 0..23
  ```

  Since `W=12` is even, `(d*W+t) ≡ t (mod 2)`, so the subset is simply:
  **clb_in[i] can read `out_d[t]` for every direction d and every track t
  with `t mod 2 = i mod 2`** (6 tracks/direction × 4 dirs = 24, Fc = 24/48
  = 0.5). Every track remains readable by 9 of the 18 inputs (balanced).
* **Config write** (addressing unchanged): `cfg_addr_i[4:0] = i` (0..17);
  `cfg_data_i[4:0] = k_i` (subset index, 0..23). `sel_r` reset-less; OCC
  zero-inits before run (unchanged convention).
* **v1.1 → v2c value translation**: v1.1 absolute track `p` is representable
  for input `i` iff `p mod 2 = i mod 2`; then `k = (p − (i mod 2)) / 2 =
  floor(p/2)`. The router's CB possibility edges are pruned to exactly these
  pairs (reference implementation:
  `generated/icopt/route/route_check.py`, knob `cb_div=2`).
* **Reserved values**: `k_i = 24..31` (5-bit encodable) index `pool[≥48]` →
  **undefined; MUST NOT be programmed** (simulation reads X). `k_i = 0`
  (blank/zero-init) is legal: `clb_in[i]` reads `out_n[i mod 2]` — a real
  track, not a disconnect (same convention as v1.1's default `out_n[0]`).
* **Config storage**: 18 points × 5 bits = **90 bits/tile** (was 108).

### 7.2 IIB v2c — feedback-first depopulated crossbar (supersedes the IIB
    portion of `clb-t-config-v0.md`)

Motivation (measured in the spike): class-depopulating *all* pool entries
class-locks the feedback pool entries and fails intra-cluster assignment on
2–5 of 9 c432 tiles; keeping feedback full and depopulating only external
inputs passes 8/9 tiles with mapper pin-rotation alone. Every mux therefore
keeps **all N=8 feedback entries**; only the EXT_IN=18 external inputs are depopulated
**by parity**.

* **Pool reorganization** (slice-only select encoding — no index arithmetic):
  `pool[17:0] = clb_in_i` (external inputs), `pool[23:18] = 0` (padding),
  `pool[31:24] = clb_out_o` (feedback `j` at `pool[24+j]`).
* **Mux classes**: LUT-input mux `m = gi*K + gk` (`gi = 0..7` LUT, `gk = 0..3`
  pin; `m = 0..31`) has ext parity class `π(m) = m mod 2 = gk mod 2`.
  Even-`gk` pins see even external inputs `{0,2,…,16}`; odd-`gk` pins see
  `{1,3,…,17}` (9 pins each). All 8 feedback entries are visible to every mux.
* **Select encoding** (5 bits, pure bit-slicing — no adders):

  | `sel[4]` | meaning | pool index |
  |---|---|---|
  | 1 | external input | `{sel[3:0], π(m)}` = `2*sel[3:0] + π(m)` (legal `sel[3:0]` = 0..8) |
  | 0 | feedback `j` | `{2'b11, sel[2:0]}` = `24 + j` (`sel[3]` don't-care) |

  Reserved: `sel[4]=1` with `sel[3:0] = 9..15` (reads padding/fb — MUST NOT
  be programmed). `sel = 0` (blank/zero-init) = feedback `j=0`.
* **Config write** (addressing + count unchanged): `cfg_addr = N + m`
  (8..39), `cfg_data_i[4:0] = sel`. 32 points × 5 bits = **160 bits/tile**
  (count unchanged from v1.1; semantics + pool layout changed).
* **v1.1 → v2c sel translation**: v1.1 pool index `p` — feedback `p = 18+j`
  → `sel = j`; external `p ∈ 0..17` → legal iff `p mod 2 = π(m)`, then
  `sel = 16 + floor(p/2)`.
* **Reachability invariants** (contract for the mapper's pin-assignment
  solver): **R1** every feedback `j` reaches every LUT input; **R2** ext pin
  `i` reaches LUT `gi` only through its two pins `gk ∈ {0,2}` (i even) or
  `{1,3}` (i odd); **R3** within one LUT, each parity class has exactly 2
  pin slots. Reference solver (net-level backtracking, exact):
  `generated/icopt/route/iib_check.py` (L1 check).

### 7.3 SB v2c — UNCHANGED

Wilton track-permuting Fs=3 per §2, with bidirectional inject (Option B).
Config: 48 sel × 2 bits + 8 × (inj_en 1 bit + inj_dir 2 bits) = **120
bits/tile**; addr map `0..47` sel / `48..55` inject unchanged; `cfg_data_i`
3-bit unchanged. Rationale (measured): SB is only ~10% of per-tile cost;
rotating-drop Fs=2 kills c432 routability (0/5 seeds + 2 structurally
unreachable nets), and the routable Fs=2.5 variant saves only ~2% — no SB
change is net-positive at W=12.

### 7.4 Tile config geometry (replaces 548)

| block | points | bits/point | bits | vs v1.1 |
|---|---|---|---|---|
| CLB logic (8 eLUT4 × 20) | 8 | 20 | 160 | unchanged |
| IIB (§7.2) | 32 | 5 | 160 | count same, semantics new |
| SB (§2, unchanged) | 48+8+8 | 2/1/2 | 120 | unchanged |
| CB (§7.1) | 18 | 5 | **90** | was 108 (6-bit) |
| **tile total** | 122 | — | **530** | was 548 (−18) |

Bitstream order per tile (pack order, unchanged): `[CB points] → [SB points]
→ [logic points]`, points in the order listed, LSB-first within a point;
column = rows `0..R-1` concatenated, zero-padded to 32-bit words, + CRC16
tail word (per `frame_map.pack_column`).

Derived geometry (4×4, all-CLB): column = 2,120 bits = **67 data words** +
1 CRC word = **68 words/frame** (was 70); full image = 4 frames × 68 words
= 272 words = **1,088 B** (was 1,120 B). cfg bus addressing
`{tile_idx, unit[1:0], intra[5:0]}` and unit codes (00=CLB/01=SB/10=CB/11=
TILE-MODE) are unchanged; only the CB unit's data payload narrows to 5 bits
(`fabric_top` passes `cfg_data_i[4:0]` to the CB, was `[5:0]`).

### 7.5 frame_map.py impact (tools implementer)

* `cb_tile_type`: `sel_w = max(1, (4*W//CB_DIV − 1).bit_length())` = 5 for
  W=12/CB_DIV=2; points `cb_sel_0..17` (5 bits). Point NAMES unchanged;
  value semantics = subset index k (§7.1).
* `clb_tile_type`: point list unchanged (`iib_mux0..31`, 5 bits); values now
  use the §7.2 encoding (frame_map is semantics-agnostic — no code change
  beyond comments).
* `sb_tile_type`: unchanged.
* `tile_width` = 530; `column_data_words` (4×4) = 67; frame = 68 words.
* `to_json` `version` → `"0.2"`, params gain `CB_DIV: 2`.
* `test_frame_map` / `test_fabric_gen` geometry expectations: tile 530 bits,
  122 points, 4×4 = 67 data words/frame, 68 with CRC.

### 7.6 VPR arch delta (`arch_ethereal.xml`)

* clb `fc`: `in_type="frac" in_val="1.0"` → **`in_val="0.5"`**
  (`out_val="0.25"` unchanged). VPR applies its own Fc pattern; the exact
  parity mapping of §7.1 is bitgen's job (same convention as the existing
  "Exact rr_graph→mux mapping is bitgen's job" note).
* IIB: **keep** `<complete name="crossbar" input="clb.I fle[7:0].out"
  output="fle[7:0].in">` as a connectivity *superset* — pack/place remains
  valid and unchanged; the §7.2 parity restriction is enforced at bitgen by
  the class-aware pin-assignment solver (§7.2 R1–R3; reference
  `generated/icopt/route/iib_check.py`). Optional exact arch modeling
  (split `clb.I` into `I_EVEN`/`I_ODD` ports + parity `<complete>` blocks) is
  a future refinement and would require bitgen_db port-remap changes —
  **not part of v2c**.
* MEM_T/DSP_T tile fc (1.0/1.0) and all other tiles: unchanged.

### 7.7 Migration notes (what breaks)

* **All v1.1 images/bitstreams are incompatible**: CB + IIB sel encodings
  changed and the tile width shrank 548→530, shifting every frame boundary.
  Regenerate `frame_map.json`, `blank.hex`, fabric manifests, and every OCC
  image. VPR `.net`/`.place` fixtures remain reusable (placement is
  unaffected); frames must be repacked through the updated bitgen.
* **Blank/zero-init semantics change**: CB `k=0` reads `out_n[i mod 2]` (was
  `out_n[0]`); IIB `sel=0` reads feedback `j=0` (was `clb_in[0]`). Blanked
  LUTs therefore self-read `fb[0]` through an X truth table (same X-containment
  class as v1.1; the `tb_hotswap` self-contained-image pattern becomes the
  hardware default).
* **Perf model / image-size constants** (E0-SHL3): tile 548→530 bits;
  4×4 frame 70→68 words; image 1,120→1,088 B; hot-swap/OCC cycle counts
  (868 cyc @ 67-word frames) and SPI times recompute accordingly.
* **SV testbenches with image/config literals**: `tb_connection_block`
  (6-bit → 5-bit sel, subset semantics), `tb_clb_t` (IIB encoding),
  `tb_hotswap` (image words), `tb_switch_box` (unchanged). Python suites:
  `test_frame_map` / `test_fabric_gen` (geometry), `test_cb_model`,
  `test_fabric_model`, bitgen + fabric_sim suites (encoding).
* Combinational-loop analysis (§5) carries over: §7.1/§7.2 only *remove*
  mux edges; they add none, and CB edges still terminate at clb_in sinks.

### 7.8 Implementation contract (two independent workstreams)

**RTL workstream** (reference prototypes, functionally validated by
`generated/icopt/rtl/tb_icopt_variants.sv`, 930 checks):
`generated/icopt/rtl/connection_block_dep.sv` (= §7.1 with `DIV=2`;
`DIV=1` is bit-identical to v1.1) and `generated/icopt/rtl/clb_t_fbfull.sv`
(= §7.2). Tracked changes: `connection_block.sv` gains `CB_DIV` + 5-bit
`cfg_data_i`; `clb_t.sv` gains the §7.2 pool + sel decode;
`fabric_top.sv` narrows the CB data slice to `cfg_data_i[4:0]`. SB RTL
untouched.

**Models + tools workstream** (reference implementations:
`generated/icopt/route/route_check.py` for the router/CB-edge pruning,
`generated/icopt/route/iib_check.py` for the IIB class solver):
`cb_model.py` (k-subset semantics + `track_index` ↔ k conversion),
`fabric_model.py` `_cb_edges` (parity pruning), `fabric_sim.py` CB eval,
`bitgen_route.py` CB possibility edges, `bitgen_pack.py` (5-bit cb_sel +
IIB encoding round-trip), `bitgen_db.py` (class-aware `iib_sel_for` + pin
repair per §7.2 R1–R3), `frame_map.py` (§7.5), `arch_ethereal.xml` (§7.6),
`perf_model.py` + `docs/performance-model.md` (§7.7 numbers). SB model
untouched.

Both workstreams build against §7.1/§7.2/§7.4 tables alone; the acceptance
cross-check is the c432 full-flow bit-true regression (E0-MAP3 4d/4e path)
on the new encoding.
