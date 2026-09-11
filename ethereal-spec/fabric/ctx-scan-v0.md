# Ethereal Fabric — Context Scan (`ctx_scan`) v0

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0.1** · Date: 2026-09-11
> Plan-Ref: `ethereal-plan/components/C03-OCC组件.md §7` (ctx_scan), `C02-fabric-异构tile.md §3` (SSM-T window), `subsystems/S02-OCC与配置体系.md §2/§3` (CTX_* rows 12-15, 上下文保存 v1)
> Implements: E2-FAB3 (SSM-T + 上下文保存 v1). Scope: fabric-side mechanism + the save/restore engine (sim v0).

---

## 1. Purpose

Save the virtual FF state of a fabric region to a context buffer and restore it later —
the hardware basis for container **pause / resume / preemption / migration** (S02 §1).
The golden acceptance: **暂停→恢复后输出序列与不间断运行一致** (S02 §3 item 1).

## 2. Chain structure (deterministic, config-independent)

Every eLUT4's virtual FF (`vff_r`) participates, **regardless of `ff_en`** — the chain
length/order must not depend on configuration, so a saved image is positionally stable
across re-配置 of the same region shape.

- **Element index** `e = tile_rm * 8 + gi`, where `tile_rm` = the tile's row-major index
  (`r*C + c`) and `gi` = the eLUT index within the CLB-T cluster.
- `N = R*C*8` bits total for an `R×C` fabric.
- Chain wiring: `fabric.scan_in_i → tile[0].gi[0].scan_in`; inside a tile,
  `gi[k].scan_in ← gi[k-1].scan_out`; across tiles, `tile[t].scan_in ← tile[t-1].scan_out`
  completed to `fabric.scan_out_o = tile[N/8-1].gi[7].scan_out`.
- **Heterogeneous tiles** (MEM-T / DSP-T) carry no `vff`: they are **pass-through** (their
  `scan_in` feeds the next tile's `scan_out` unchanged). The element indexing keeps its
  full positional stride (every tile occupies 8 slots; het tiles contribute nothing).

## 3. Scan semantics (vff update priority)

With `scan_en_i = 1` the virtual FF captures the scan input instead of the LUT cone:

```
posedge clk:
  if (ff_rst_en_r && !rst_ni)  vff_r <= ff_rst_val_r;   // reset wins
  else if (scan_en_i)          vff_r <= scan_in_i;      // scan capture (2nd)
  else if (cfg_ce_i)           vff_r <= comb_out;       // normal capture
```

`scan_out_o = vff_r` (the raw Q, pre-`out_inv` — same convention as the tick model's
captured-D and the readback CRC). **There is no separate halt signal**: asserting
`scan_en_i` freezes the computed state by construction (no LUT capture), which is the v0
"pause". Real silicon additionally takes over the region clock (BUFG-level switch, C03 §7
constraint) — that lives in `hal/<vendor>/glue/` and is an ASSUMPTION for the v0 sim flow.

## 4. Save / restore (the `ctx_scan` engine)

Shift protocol (one clock per shift, `scan_en_i` held 1 throughout):

- **Save:** after shift *t* (t = 1..N) the bit at `scan_out` is element `N - t`. The engine
  packs element `e` into **bit `e mod 32` of word `e div 32`** (LSB-first) of the context
  buffer. Total: `ceil(N/32)` words.
- **Restore:** each shift pushes its input one element up the chain (element 0 captures
  the newest bit), so the engine drives **element N-1 first** (descending order —
  word MSB-first). After N shifts every element holds its saved value; deasserting
  `scan_en_i` resumes normal computation with the restored state.

Context buffer = **the SSM-T window** (C02 §3): a word-addressed RAM window. v0 sim uses a
behavioral word RAM (the real SSRAM/BSRAM mapping is C02 §3 ASSUMPTION #1 — if SSRAM is
not written frequently enough, the window degrades to a reserved BSRAM pool).
**Management (v0.7):** the engine is driven through EMRI — `CTX_CMD`/`CTX_WORDS`/
`CTX_STATUS` @ `0x26`-`0x28` and the daemon's `EFP_CMD=8 ctx_save` / `9 ctx_restore`
lifecycle (frozen fabric = `EFP_STATUS=9 PAUSED`, refusals = `EFP_ERR=13`); see
`ethereal-spec/control/emri-v0.md` §3.9. The chain is fabric-global in v0, so one
context operation covers the whole fabric.

Engine interface (v0):

| Port | Dir | Meaning |
| --- | --- | --- |
| `start_i`, `mode_i` (0=save, 1=restore), `words_i` | in | one-shot command (`ceil(N/32)`) |
| `busy_o`, `done_o` | out | lifecycle (done = 1-cycle pulse) |
| `scan_en_o`, `scan_in_o`, `scan_out_i` | out/in | to the fabric chain |
| `ram_we_o`, `ram_addr_o`, `ram_wdata_o`, `ram_rdata_i` | out/in | the context window |

## 5. Cost & phasing

- +1 mux per eLUT on the FF data path (C03 §7: ~0.5 CFU/eLUT), enabled **always** in v0;
  the `checkpointable`-region gating (mixed-cluster strategy, C01 §7) is a later
  optimization.
- EMRI-side orchestration (`CTX_*` rows 12-15 of the S02 register map) and BMC daemon
  integration are the **E2-FAB3b** increment; v0 proves the mechanism + pause/resume
  equivalence at the fabric level (this spec's acceptance test).

## 6. Acceptance (v0)

A container (TFF + counter image) paused, saved to the context window, kept frozen while
the reference twin keeps running, then restored and resumed must produce **exactly the
reference twin's ongoing output sequence** — verified cycle-by-cycle on `clb_out_obs`.
