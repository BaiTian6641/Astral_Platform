# ADR-012 (refinement): Ethereal MAP routing — Option B (custom router on real topology) + v1 routability finding

> Status: **Accepted (routing + bidirectional inject); SB topology (Wilton) = open decision** · Date: 2026-07-26
> Supersedes/extends: ADR-012 (MAP route A=VPR vs B=FABulous) — this refines the *routing mechanism* and records a Phase-0 fabric-routability finding.
> Plan-Ref: `ethereal-plan/components/C-soft-工具与固件组件.md §2` (bitgen), `C01-fabric-核心单元.md §3.3` (SB topology)

## Context
ADR-012 left the MAP route open (A=VPR+XML vs B=FABulous/nextpnr, Phase-0 spike). E0-MAP2 built the VPR arch (route A) and c432 pack/place/route **succeeds at W=12 in VPR's abstract model**. E0-MAP3 then requires translating VPR's result into the *real* fabric's mux configs.

## Decision 1 — Routing mechanism: custom router on the REAL fabric topology (Option B-router)
Translate VPR's **abstract** routing (subset SB + fc-CB) onto the hand-built `switch_box`/`connection_block` via a topology table is mistranslation-prone (VPR's topology ≠ the real fabric). Instead: **VPR does pack/place only; we route on the real fabric graph** (`fabric_model` + a PathFinder). This *guarantees realizability* — a route the router finds is realizable on the actual fabric. Implemented in `bitgen_route.py` (incr 4a). **Accepted.**

## Decision 2 — Output inject: bidirectional (Option B-inject)
v1 inject was **east-only** (`inj_en[j] → out_e[j]`). The router proved this **strands every driver at the eastmost column** (inject emits east; no east neighbor → signal trapped). Verified independently (west-edge driver routable, east-edge stranded). Fix: **bidirectional inject** — `inj_en[j]` + `inj_dir[j]` (0=N,1=S,2=E,3=W); each clb_out[j] injects onto ONE configurable direction. Implemented in `switch_box` + `sb_model` + `frame_map` (tile 532→548 bit). **Accepted; fixes the stranding (Cause 1).**

## 🔴 Finding — v1 (disjoint SB) is unroutable for c432 (Cause 2)
Even with bidirectional inject, the c432 router **does not converge** (29 inter-cluster nets, persistent over-use across 60+ iters × 5 seeds). Root cause: **disjoint-SB track-locking**. The disjoint SB preserves track index (out_D[t] ← in_D'[t]), and inject pins each net to `t = driver_j`, so **every net is locked to a single track index**. VPR packs multiple nets to the same fle-index `j` (= track `j`) across clusters with no awareness of this; track 7 carries 7 nets, track 2 carries 6 → they cannot coexist on the small grid. This is **structural** (not congestion amenable to more iters). It is exactly what Option B-router was built to surface — VPR's abstract rr_graph would have hidden it.

**Scope implication:** v1 (disjoint SB) cannot route c432, nor the larger Phase-0 exit circuits (AES-128, FIR16). The disjoint SB was always documented as a *preliminary, VPR-refinable placeholder* (C01 §3.3; interconnect spec §2), with the v2 target being a track-flexible topology (Landy/Stitt/Wilton).

## Open decision — SB topology: Wilton now (Option A-fabric) vs defer to Phase 1 (Option D)
| | Fixes Cause 2? | Cost | Notes |
|---|---|---|---|
| **A. Wilton SB** (track-index permutation) | **Yes (root)** | Medium — `switch_box` source map + `sb_model` + arch `type="wilton"`; **frame_map SB points unchanged** (still 48×2-bit sel); inject/CB/clb unchanged | The spec's named v2 target. Wilton lets a net change track index at each SB hop → breaks track-locking. Likely routes c432 + bigger circuits. |
| **D. Defer c432/AES/FIR → Phase-1 fabric v2; validate Phase-0 flow on small routable circuits** | (scope) | Low | Phase-0 goal is *flow* validation, not fabric competitiveness. c17 is already bit-true through frames. |

**Maintainer to decide.** The router (Option B-router) and bidirectional inject (Option B-inject) are done + validated regardless; incr 4b (primary-IO injection + fabric sim) is independent and can proceed on whatever circuit routes.

## Consequences
- The v1 fabric is confirmed a **flow-validation vehicle**, not a competitive fabric. Its routability ceiling (small, low-track-contention circuits) is now characterized.
- Wilton SB (when adopted) is a contained, frame_map-compatible change (SB config-point layout invariant) — low rework.
- All Phase-0 tooling (synth, VPR arch, bitgen DB/pack, router, frame_map) is routing-topology-agnostic below the SB source map — swapping disjoint→Wilton is localized.
