# ADR-019: OCC READBACK expected-CRC gate (software-supplied compare value)

> Status: **RATIFIED — rev 1** · Date: 2026-09-11 · Maintainer decision (option B of 3)
> Amends: the EMRI spec's READBACK semantics (emri-v0.md v0.2–v0.4 §2/§3.1) → **spec v0.5 §3.1.1**
> Relates to: E1-RUN4 (region watchdog + heartbeat), E1-DMO2 (multi-column deploy replay), E2-BMC1 (mFSM host flow)
> Plan-Ref: `ethereal-plan/components/C03-OCC组件.md §2`, `ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3`, `ethereal-spec/control/emri-v0.md §3.1.1`

---

## 1. Context

`occ_top` (v0, E0-FAB4/E0-FAB5) streams a frame's words through a CRC32 chain and keeps a
**single** `write_crc_r` latch: set at every WRITE/BLANK completion, and READBACK's
`ST_CMP` compares the readback stream's CRC against it. This "compare against the last
write anywhere" model was adequate while every verified deploy used **one column in one
region** — and that is exactly what every earlier capstone did
(`tb_bmc_daemon_packed` stages `EFP_IMG_COLS=1`; `tb_bmc_axi_occ`/`tb_occ` single-frame).

Two consequences were never exercised until the E1-RUN4 capstone (2026-09-11) deployed to
**region 1** and probed it with the v0.4 region heartbeat:

1. **Multi-column packed deploys cannot pass their own READBACK step.** emri-v0 §3.3
   steps 2–4 prescribe BLANK-all-columns → LOAD-all-columns → READBACK-all-columns. With
   a single compare latch, column `c`'s READBACK compares against column
   `region+cols-1`'s write CRC → guaranteed mismatch for `cols>1`. (The shipped demo
   images — pwm 2 columns, uart_loopback 4 columns — are therefore not deployable
   end-to-end today.)
2. **The v0.4 region heartbeat false-quarantines healthy regions.** §3.5 probes every
   RUNNING region in turn; only the most recently written region's CRC matches, so any
   other region false-mismatches → the daemon BLANKs it, marks it FREE, pushes event
   code 2 and sets `EFP_ERR=occ_crc`. Observed on the E1-RUN4 capstone ("hb r1 crc err"
   after region 0's recovery BLANK — region 1's config was intact). This violates the
   watchdog acceptance "相邻 region 无损".

## 2. Decision (maintainer, 2026-09-11: option B)

**The READBACK compare value becomes software-supplied.** Two EMRI words (spec v0.5
§3.1.1):

- `OCC_EXPECT_CRC` (`0x0E`, RW) — regfile storage, driven into `occ_top`
  (`expect_crc_i`) and **latched at command accept**; `ST_CMP` compares
  `crc_r == expect_crc_latched_r`.
- `OCC_CRC_RESULT` (`0x0F`, R) — exposes `occ_top.crc_r` (the running/streaming CRC;
  after a completed WRITE/BLANK it is that stream's final CRC; reseeded at accept).

**Caller flow** (daemon, both `run` and `run_packed`): after the WRITE's `done_flag`
sets, read `OCC_CRC_RESULT`; write it to `OCC_EXPECT_CRC`; issue READBACK. The daemon
also stores the per-(region, column) CRC and re-supplies it before every heartbeat probe
READBACK, so a probe of **any** region/column is a true integrity check. A caller that
forgets to set `OCC_EXPECT_CRC` fails the compare (stale/seed) → fail-safe.

## 3. Alternatives considered

- **A — per-region expected-CRC slots in `occ_top` + interleave §3.3 per column.**
  Smallest RTL change, but the heartbeat of a multi-column region still compares column
  `c` against the region's last write → unsound; also adds `region_count × 32` FFs and
  reorders the (verified) §3.3 loop, with a full OCC-TB re-run.
- **C — rescope v0: probe only the last-written region, require `cols==1`.**
  Cheapest, but weakens the neighbor-liveness guarantee (the whole point of the
  heartbeat), leaves multi-column images undeployable, and defers the real fix to E2.
- **B — chosen.** Explicit, per-column, per-region-sound; no data-path duplication (the
  daemon *reads* the CRC the OCC already computed); keeps §3.3's loop order; fail-safe.

## 4. Consequences

- `occ_top`: `write_crc_r`/`c_write_last` removed; `expect_crc_i` latched at accept;
  `crc_result_o` added.
- `emri_regfile`: two new words (plain storage + read passthrough); all system TBs wire
  the new ports (16 TB files updated; `tb_occ`/`tb_emri_occ_loop` arm the gate before
  READBACK; `tb_blank` issues no READBACK and ties it off).
- Firmware (daemon): +1 read + 1 write per deploy READBACK; per-(region,column) CRC
  table (static RAM, no malloc); heartbeat now supplies the stored CRC per probe.
- **mFSM host flow (E2-BMC1) must set `OCC_EXPECT_CRC` before every READBACK** — an
  explicit contract item for that task. `ethctl`'s daemon (EFP) sessions are unaffected
  (the daemon owns the registers).
- Spec bumped to **emri-v0.md v0.5** (§2 table, §3.1.1, §3.2 step 6, §3.3 step 3/4,
  §3.5 heartbeat).
