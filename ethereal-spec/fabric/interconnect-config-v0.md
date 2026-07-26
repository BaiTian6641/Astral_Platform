# Switch Box + Channel Interconnect — v0 (draft)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0** (preliminary topology, VPR-refinable)
> Plan-Ref: `ethereal-plan/components/C01-fabric-核心单元.md §3 §5` · Date: 2026-07-24

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
(`bitgen_route.py`) both consume it. v2 target: Landy/Stitt two-source-track
ratio up (interconnect area −20%).

## 3. Channels (unidirectional, single-tile length)

`out_D[t]@(r,c) → in_D'[t]@(neighbor)`:
- `out_n → in_s@(r-1,c)` · `out_s → in_n@(r+1,c)`
- `out_e → in_w@(r,c+1)` · `out_w → in_e@(r,c-1)`
Edge tiles' off-grid ports are tied to 0.

## 4. connection_block (input CB) — routable (Step 2) + fabric_top grid

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
