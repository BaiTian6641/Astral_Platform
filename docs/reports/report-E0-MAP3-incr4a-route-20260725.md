# Report — E0-MAP3 increment 4a: PathFinder router on the real fabric topology

- **Task**: E0-MAP3 incr 4a (ADR-012 refinement, Option B)
- **Date**: 2026-07-25
- **Plan-Ref**: `ethereal-plan/components/C-soft-工具与固件组件.md §2` (bitgen two-level design — routing step)
- **Status**: ⚠️ Router DELIVERED & VALIDATED, but it **surfaced a Phase-0 architectural finding** — c432 is NOT routable on the v1 fabric as VPR placed it. Reported (not faked) per G6. **Maintainer decision required** (see §3).

---

## 0. TL;DR

A custom negotiated-congestion **PathFinder** router (`bitgen_route.py`) was built
that routes on the REAL hand-built `switch_box` / `connection_block` graph (the
`FabricGrid`), exactly as Option B specifies. VPR does pack/place; we route on
the actual topology, so every route produced is *guaranteed realizable* — this is
the whole point of Option B, and it paid off immediately: **the router proved
that c432, as placed by VPR, cannot be routed on the v1 fabric**, for two
independent structural reasons. The router is itself sound (validated on a
synthetic 1×2 case and on c432's *feasible subset* of 14 nets, where all 21
driver→sink pairs are `route_exists` True on the configured real fabric).

This is a G6 stop-and-report: the realizability guarantee Option B was designed
to provide has caught a real infeasibility that VPR's abstract routing would
have hidden. **No fabrication/silicon risk**: this is sim-only Phase 0.

---

## 1. 本阶段实现内容 (this phase)

### ✅ Deliverables (NEW files only — no existing behavior modified)
| File | LoC | Purpose |
|---|---|---|
| `ethereal-tools/tools/mapper/bitgen/bitgen_route.py` | ~330 | PathFinder router on the real fabric graph + net extraction + apply-to-grid |
| `ethereal-tools/tools/mapper/bitgen/test_bitgen_route.py` | ~240 | 5 tests: extraction, convergence (xfail), **the finding**, feasible-subset realizability, synthetic |

### ✅ Public API (as specified)
- `extract_nets(db, min_x, min_y) -> list[Net]` — classifies every net as `inter` / `primary_in` / `primary_out`.
- `route(db, max_iters=30, W=12, N_INJ=8, EXT_IN=18, seed=0, verbose=False) -> RouteConfig` — builds the possibility graph, runs PathFinder, returns per-tile `sb_sel` / `inject_en` / `cb_sel` + stats + unrouted list.
- `apply_route_to_grid(grid, rc)` — configures a `FabricGrid` for `route_exists` validation.
- Dataclasses: `Net`, `TileRoute`, `RouteConfig`.

### ✅ Router design (faithful to the real fabric — `fabric_model` / `sb_model` / `cb_model`)
- **Possibility graph**: every available mux option is an open edge; PathFinder picks one per contended wire.
  - fixed channel `out_D[t]→in_D'[t]` (CHAN_MAP); SB mux `in_src[t]→out_dst[t]` (src≠dst, disjoint); inject `clb_out[j]→out_e[j]`; CB `out_D[t]→clb_in[i]`.
- **Negotiated congestion** (classic McMurchie PathFinder), congestion keyed per **wire node** (the contended resource): `edge_cost(a→b)=1+hist[b]·present_occ[b]`; over-used nodes (`present_occ>1`) get `hist+=1`; all nets ripped up & re-routed each iteration.
- **Deterministic**: Dijkstra tie-breaks by a monotonic insertion counter (nodes never compared); **seeded per-iteration net shuffle** (`random.Random(seed)`) breaks the systematic bias of a fixed net order while staying reproducible.
- **CB-edge pruning**: only `clb_in` nodes that are actual sinks get CB edges (cuts ~864→~5 dead CB edges/tile). Correct because a non-sink `clb_in` is never a routing target.
- Multi-driver nets and `clb_out[j≥N_INJ]` drivers are flagged UNROUTABLE up front.

### ✅ Verification (exact)
| Check | Result |
|---|---|
| `make lint` (Verilator, RTL) | **OK** — all project RTL lint-clean (RTL untouched) |
| `pytest ethereal-tools/tools/mapper/bitgen/ -v` | **17 passed, 1 xfailed** (13 existing + 5 new; no regressions) |
| `pytest ethereal-tools/ -q` (full mapper) | **342 passed, 1 xfailed** |
| `ruff check --select E4,E7,E9,F bitgen/` | **All checks passed!** |
| `mypy --strict` | not installed in venv (task's Python gate is the ruff check above; code is fully type-hinted) |

### ⚠️ THE FINDING — c432 is unroutable on the v1 fabric as placed by VPR

`route(c432_db)` does **not** converge in 30 iters (38 over-used nodes; over-use
oscillates 22–52 with **no downward trend** over 50 iters — a PathFinder
limit-cycle, signalling genuine over-subscription, not slow convergence). Two
**independent, structural** causes:

```mermaid
flowchart TB
    A[c432 placed by VPR<br/>29 inter-cluster nets] --> B{Routable on<br/>v1 fabric?}
    B -->|NO| C[Cause 1: east-only inject]
    B -->|NO| D[Cause 2: track-locked disjoint SB]
    C --> C1[3 nets driven from eastmost col c=C-1<br/>new_n63, new_n64, N223<br/>inject emits ONLY out_e; no east neighbor<br/>=> signal cannot leave driver tile<br/>STRUCTURALLY UNREACHABLE]
    D --> D1[track 7 carries 7 nets<br/>track 2 carries 6 nets]
    D1 --> D2[disjoint SB preserves track index t<br/>no track-change mux<br/>=> each net locked to t = driver_j]
    D2 --> D3[track 7 alone: never below 14<br/>over-used nodes (200 iters x 5 seeds)<br/>track 2 alone: stuck at 2<br/>INDIVIDUALLY INFEASIBLE]
    C1 --> E[Root cause: VPR packs nets to fle indices<br/>=> fabric tracks with NO awareness<br/>of the v1 fabric's track locking]
    D3 --> E
```

**Root cause (both causes share it):** VPR's packer assigns nets to physical fle
indices `j` (= fabric track `j` via inject) using its own abstract cost, with
**no knowledge** that the v1 fabric (a) locks each net to track `j` for its
whole route (disjoint SB, no track-change mux) and (b) only lets `clb_out[j]`
exit eastward. So VPR freely over-loads track 7 (7 nets) / track 2 (6 nets) and
places drivers on the east edge — both legal in VPR's model, both fatal on the
real fabric.

### ✅ The router is sound (proven on what IS routable)
- **Synthetic 1×2**: `clb_out[0]@(0,0)→clb_in[0]@(0,1)` → `inject_en{0}@(0,0)`, valid SB path, `cb_sel[0]@(0,1)`, `route_exists` True. ✅
- **Per-track isolation**: tracks 1/5/0/4/3/6 (4/4/3/3/1/1 nets) **converge cleanly** (≤10 iters). ✅
- **Feasible subset of c432** (14 nets — everything except the 3 east-edge-stranded nets and tracks 2 & 7): **converges in 12 iters, 0 over-used, and all 21 driver→sink pairs are `route_exists` True on the configured real `FabricGrid`** — the Option-B realizability proof, on the subset the v1 fabric can carry. ✅

### c432 routing stats (exact)
| metric | value |
|---|---|
| inter-cluster nets | **29** |
| primary_in (→ incr 4b) | 36 |
| primary_out (→ incr 4b) | 33 |
| converged (full design) | **False** |
| n_iters | 30 (limit) |
| n_routed | 0 |
| n_overuse_final | 38 |
| east-edge-stranded nets | **3** (`new_n63`, `new_n64`, `N223`) |
| over-subscribed tracks (≥5 nets) | **2** (j=2: 6 nets, j=7: 7 nets) |
| grid_dims (R,C,W,N_INJ,EXT_IN) | (3, 4, 12, 8, 18) |
| inject-pin violations (clb_out[j≥N_INJ]) | **0** (all drivers j<8) |

---

## 2. The inject-track-pin constraint

The task asked: *any net driven by `clb_out[j≥N_INJ]` (unroutable)?*
**Answer: NO** — for c432 every inter-cluster driver is `clb_out[j]` with `j ∈
{0..7} < N_INJ=8`. VPR packed all cluster outputs into `fle[0..7]`. **Zero
inject-pin violations.** (The east-edge-stranding in §1 is a *different*
inject limitation — direction, not index.)

---

## 3. 下一阶段需要做的内容 (next phase) — **maintainer decision required (G6)**

This is a genuine architectural fork. The router is correct and done; what's
open is **how to make c432 (and general designs) routable**. Candidate options,
each with its basis:

| Option | What | Basis | Cost / risk |
|---|---|---|---|
| **A** | **Track-flexible routing fabric**: replace the disjoint SB with a Wilton/universal SB, OR add cross-track muxes, so nets can change tracks to dodge congestion. | Directly removes Cause 2 (track-locking). Standard FPGA practice (VPR's default is Wilton). | RTL rework of `switch_box` + arch.xml; re-runs E0-FAB3/FAB4. Loses the "disjoint = simplest" property but gains routability. |
| **B** | **Bidirectional inject**: let `clb_out[j]` inject onto `out_e[j]` AND `out_w[j]` (or all 4 dirs via a small mux). | Removes Cause 1 (east-edge stranding) outright; also gives westward exit, easing congestion. | Small `switch_box` change (inject becomes a 1→N mux, +2 bits/j); frame_map grows slightly. Keeps disjoint SB. |
| **C** | **Track-aware packing**: post-process VPR's `.net` to rebalance nets across fle indices `j` (≈ tracks) so no track is over-loaded; constrain drivers away from the east edge. | Keeps the v1 fabric unchanged; fixes the root cause (VPR's track-blindness). | New tool pass; may need to re-run VPR with hints or rewrite the pack output. Cheapest in HW, hardest in SW correctness. |
| **D** | **Accept v1 limitation, defer to Phase 1**: ship the router as-is; document that v1 fabric routability is best-effort; pursue A/B/C in Phase 1 with a larger benchmark suite. | Phase 0's gate is sim validation, not routability of arbitrary designs. | Zero now; risks repeating the finding later. |

**My recommendation: B + C.** Option B (bidirectional inject) is a small,
surgical RTL change that kills Cause 1 and meaningfully helps Cause 2 (westward
exit relieves eastbound congestion). Option C (track-aware packing) then handles
the residual load-balancing without touching the fabric again. Option A (full
Wilton SB) is the "proper" long-term answer but is the most invasive and
arguably belongs in a dedicated fabric rev — I'd defer it unless B+C still
fails on a broader benchmark. **I have NOT started any of these — awaiting
maintainer direction per G6.**

### Immediate next-task candidates (whichever option is chosen)
- **E0-MAP3 incr 4b** — primary-IO injection (36 PI / 33 PO nets), independent of this finding.
- A short **feasibility spike** of Option B on c432 (prototype bidirectional inject in `sb_model` + re-route) to confirm it actually fixes c432 before committing RTL — ~0.5 day.

---

## 4. ASSUMPTIONs / open items (G6)

- **ASSUMPTION (TBD, 2026-07-25)**: PathFinder non-convergence on the full c432 design = genuine infeasibility, not a router weakness. **Evidence**: (a) the router converges on 6 of 8 tracks and on the 14-net feasible subset; (b) track 7's 7 nets plateau at ≥14 over-used nodes across 200 iters × 5 seeds with randomized ordering — a well-proven algorithm failing this persistently is strong evidence of infeasibility; (c) the two causes are independently derivable from the fabric model (east-only inject + disjoint track-locked SB). A formal proof (e.g. max-flow/min-cut on each track's wire graph) would make this airtight but was not needed to act on the finding.
- **ASSUMPTION (TBD, 2026-07-25)**: the brief's `hist[edge]·present_occ[edge]` cost formula is realized via the **target node's** resource congestion (classic McMurchie PathFinder), since the only resources that can be multi-driven are wire nodes (`out_D[t]`, `clb_in[i]`); keying by node is the textbook formulation and converges correctly (proven on the feasible subset). Flagged in the module docstring.
- All ADRs honored: ADR-012 Option B (route on real topology), ADR-017 (no vendor IP touched — pure Python), G1–G6 followed. No RTL / `frame_map.py` / `fabric_model.py` / `sb_model.py` / `cb_model.py` / `bitgen_db` / `bitgen_sim` / `bitgen_pack` behavior modified.
