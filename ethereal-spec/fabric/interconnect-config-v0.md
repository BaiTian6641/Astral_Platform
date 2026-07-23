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

## 2. switch_box (SB) — disjoint unidirectional (PRELIMINARY, VPR-pending)

Interface: `in_n/in_s/in_e/in_w`, `out_n/out_s/out_e/out_w` (each `[W-1:0]`);
config `cfg_we_i`, `cfg_addr_i[$clog2(4*W)-1:0]` (= `DIR*W + t`, DIR 0=N,1=S,2=E,3=W),
`cfg_data_i[1:0]` (sel).

Topology (v1 reference): each output track `t` in direction `D` mux-selects among
the **same-index** input tracks of the **3 other directions** + disconnect:

| output | sel1 | sel2 | sel3 | (sel0 = disconnect/0) |
|---|---|---|---|---|
| `out_n[t]` | `in_s[t]` | `in_e[t]` | `in_w[t]` | |
| `out_s[t]` | `in_n[t]` | `in_e[t]` | `in_w[t]` | |
| `out_e[t]` | `in_n[t]` | `in_s[t]` | `in_w[t]` | |
| `out_w[t]` | `in_n[t]` | `in_s[t]` | `in_e[t]` | |

> **ASSUMPTION (TBD 2026-07-24, G6 / C01 §3.3 problem 1 + §6 #4):** this disjoint
> topology is the v1 reference. The **final SB topology table must be
> VPR-routability-validated (S03 / E0-MAP2) before freezing.** The cfg interface
> (`DIR*W+t`, 2-bit sel) and the model's `dependency_edges()` are
> topology-agnostic, so swapping to Wilton/custom later only changes the per-mux
> source map — low rework. v2 target: Landy/Stitt two-source-track ratio up
> (interconnect area −20%).

## 3. Channels (unidirectional, single-tile length)

`out_D[t]@(r,c) → in_D'[t]@(neighbor)`:
- `out_n → in_s@(r-1,c)` · `out_s → in_n@(r+1,c)`
- `out_e → in_w@(r,c+1)` · `out_w → in_e@(r,c-1)`
Edge tiles' off-grid ports are tied to 0.

## 4. fabric_top grid (E0-FAB3 acceptance scope)

`fabric_top #(R,C,W,N,K,EXT_IN)` instantiates an R×C grid of `{clb_t, switch_box}`
per tile wired by the channels above. **CLB↔channel connection is a minimal v1
tap** (`clb_in` reads this tile's `out_e` tracks; `clb_out` observable) — the
**full routable CB** (`clb_out → track` injection) is a LATER design step with the
frame-map (`S02-P0#1`), OCC (`E0-FAB4`), and VPR (`E0-MAP2`); routability is a VPR
test (C01 §3.5), not part of E0-FAB3.

## 5. Combinational-loop handling ("4×4 grid, no comb loop")

Any routable fabric's muxes *permit* cycles structurally → Verilator `UNOPTFLAT`
(same family as the CLB feedback, C01 §2.4). Scoped `lint_off UNOPTFLAT` waivers
cover the SB and the `fabric_top` routing region. The **acceptance** ("no comb
loop") = **no functional comb loop in the default/unconfigured grid**, verified
at the graph level by `tests/interconnect/fabric_model.py` (Kahn cycle detection
on the SB-internal + channel edge graph): default config (all sel=0 → no SB
edges) is acyclic for all grid sizes; an acyclic routing stays acyclic; a
4-tile ring is detected; breaking one mux removes the cycle. User configs that
create loops are the mapper's responsibility (S10).

## 6. Open items (TBD)

- SB topology finalization (VPR, E0-MAP2).
- Full CB design (`clb_out → track` injection; track partitioning to avoid multi-drive).
- Long wires (length>1 tracks) for larger fabrics (v3, C01 §3.4).
- Verilator `UNOPTFLAT` zero-report confirmation (Docker-gated).
