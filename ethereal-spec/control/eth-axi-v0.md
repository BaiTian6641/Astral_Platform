# eth_axi — Ethereal AXI Interconnect (v0, draft)

> Repo: `ethereal-spec` (CC-BY-SA-4.0) · Status: **draft v0**
> Plan-Ref: `docs/adr/ADR-018-axi-noc-riscv-cluster.md` §2 (Decision 1), `ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md`
> Date: 2026-07-30 · Implements: ADR-018 (in-house AXI), the load-bearing socket the BMC, app-processor cluster, and DMA hang off.

`eth_axi` is the platform's **in-house, license-clean standard AXI interconnect**
(CERN-OHL-S-2.0, zero third-party IP). It is the frozen **socket** the BMC (XBUS→AXI4),
the application-processor cluster (S15), the DMA subsystem, and the mailbox NoC
(region-data plane) all plug into. This spec is the single source of truth for the
interface contracts; the RTL (`ethereal-shell/rtl/axi/`) and the formal properties are
derived from it.

**Why in-house:** license-cleanliness for tapeout (ADR-018). Structure references used
as *textbooks* (not copied): ZipCPU `wb2axip` (formal AXI properties = the correctness
spec), PULP `axi` (modular crossbar structure).

---

## 1. Three-plane architecture (industry standard / Zynq GP-HP)

| Plane | AXI variant | Carries | v0 scope |
|---|---|---|---|
| Control/status | **AXI4-Lite** | EMRI, OCC control, per-peripheral CSRs, PLIC/CLINT, mailbox doorbells | ✅ v0 |
| Config stream | **AXI4-Stream** | OCC → fabric_top config frames (one-way push) | ✅ v0 |
| Data/memory | **AXI4 (Full)** | DRAM/SRAM, DMA, region↔region, BMC & app memory (bursts + ATOP) | ⏳ v0.1 (crossbar core; bursts first, atomics later) |

The mailbox flit NoC remains the **region-data plane only**, fronted by AXI
Network-Interface (NI) adapters (ADR-007 structural isolation preserved). This spec
covers the AXI fabric; the NI adapter is a separate spec (RFC-002 update).

## 2. Global rules (all variants)

1. **No combinational path between input and output** on any channel (AXI requirement).
   Every module boundary is registered (skid buffers where a `READY` would otherwise
   depend combinationally on a downstream `VALID`). This is the #1 correctness rule.
2. **Handshake:** `VALID`/`READY` per channel. `VALID` must not depend combinationally
   on `READY`; once `VALID` is asserted it stays until the handshake completes.
3. **Data width:** v0 = 32-bit (matches the existing fabric/EMRI/NEORV32 XBUS width).
   64-bit is a parameter (`AXI_DW`) for the app-cluster/DRAM path.
4. **Address width:** `AXI_AW` = 32 (full 4 GiB map for the Linux-capable app-cluster).
5. **iverilog-compatible:** NO SystemVerilog `interface`/`modport` in synthesizable code
   (iverilog can't parse them); use flat ports + a `typedef` struct only where iverilog
   tolerates it (verified in the spike). Parameters kept flat (no packed-2D-array params).

## 3. AXI4-Lite (control plane)

5 channels: `AW` (addr), `W` (wdata), `B` (write resp), `AR` (raddr), `R` (rdata+resp).
Single transaction (no bursts, `AxLEN=0`, no IDs, no narrow transfers in v0).

### 3.1 Signals (per channel, `t` = valid-ready-data bundle)
- AW: `awvalid, awready, awaddr[AW-1:0], awprot[2:0]`
- W:  `wvalid, wready, wdata[DW-1:0], wstrb[(DW/8)-1:0]`
- B:  `bvalid, bready, bresp[1:0]`
- AR: `arvalid, arready, araddr[AW-1:0], arprot[2:0]`
- R:  `rvalid, rready, rdata[DW-1:0], rresp[1:0]`
- Responses (`bresp`/`rresp`): `2'b00=OKAY, 2'b10=SLVERR, 2'b11=DECERR`.

### 3.2 Slave rules
- May wait for both `awvalid` and `wvalid` before asserting `bvalid`.
- `bvalid` only after the write completes. `rvalid` only after the read address is
  accepted and data is ready.
- A slave must never hang on an unmapped access (the interconnect returns DECERR via a
  default error slave, §5).

## 4. AXI4-Stream (config plane)

Single unidirectional channel: `tvalid, tready, tdata[DW-1:0], tkeep[(DW/8)-1:0], tlast, tready`.
- Master may not wait for `tready` before asserting `tvalid`; `tvalid` stays until handshake.
- `tlast` marks the last beat of a frame (a config frame = a beat sequence ending in `tlast`).
- Used for the OCC → fabric_top config-frame stream (replaces the current direct cfg-addr
  wire in production; the cfg-addr path stays for the v0 sim loop).

## 5. AXI4 crossbar (`eth_axi_xbar`, N masters × M slaves)

### 5.1 Function
- **Address decode** per slave from a parameter-driven `ADDR_MAP` (base+mask per slave);
  unmapped addresses route to a built-in **decode-error slave** (returns DECERR, never hangs).
- **Per-channel arbitration** among masters (round-robin v0).
- **Response-ID routing:** R and B responses return to the *originating master*. The
  crossbar prepends the master index into the transaction ID (`xid = {mst_idx, orig_id}`)
  so responses route back correctly; slaves see the widened ID.
- **Deadlock-freedom:** per-channel skid buffers so a stalled response never blocks a channel.

### 5.2 Burst scope (v0.1 — implemented, `BURST_EN`)

- **INCR bursts** are routed (E2-AXI2). WRAP/FIXED and illegal `AxSIZE` are **not
  re-encoded**: they are forwarded and refused by the memory slave with `SLVERR` (§9).
- A burst is `AxLEN+1` beats; **every beat follows the destination decoded from the
  granted AW/AR** — the burst shape (`AxLEN/AxSIZE/AxBURST/WLAST`) travels inside the
  existing per-channel skid payloads.
- **LAST policy (tolerant like the memory slave):** slave-facing `WLAST = captured
  WLAST | (wcnt == AxLEN)`, master-facing `RLAST = slave RLAST | (rcnt == ArLEN)`, with
  the per-master beat counters as the authoritative bound — a missing or early LAST can
  neither hang nor silently truncate a routed burst.
- **Lock-step spans the whole burst:** `wr_busy[d]` is held from the AW grant until that
  burst's `B`; `rd_busy[d]` until the burst's last R beat; the per-destination
  uniqueness/owner invariants (§7 (U)/(C)/(O)) therefore hold *mid-burst*.
  **Multiple outstanding per master remains deferred** (single transaction per master per
  direction; no read-data interleaving — AXI4 removed it).
- The decode-error slave sinks **every** W beat of an errored burst before `B` and returns
  exactly one R beat (`RDATA=0`, `RLAST=1`) (§5.3).
- **Compatibility:** the burst path is gated by the compile-time parameter `BURST_EN`
  (default `0`). At 0 the burst attributes are masked to a legal single-beat encoding
  (`AxLEN=0`, `AxSIZE` = bus width, `AxBURST=INCR`, `WLAST=0`), so existing single-beat
  users keep the v0 contract **bit-identically**; at 1 bursts are routed. The slave-facing
  burst port set exists and is well-formed at either setting.
- ATOP atomics: still deferred. This is the **bus-level** AXI `ATOP` transaction: it is
  needed only for SMP Linux, and the single-core profile does not use it. It does **not**
  excuse the **instruction-level RISC-V `A` extension** (LR/SC/AMO), which single-core
  Linux/OpenSBI firmware *does* require — an AMO instruction is executed as an ordinary
  read-modify-write over the D port, with no `ATOP` on the wire. See
  `docs/reports/report-E2-RV2-linux-gap-20260912.md` G2.

### 5.3 The decode-error slave
A built-in default slave that answers any unmapped access with `DECERR` and consumes the
transaction cleanly (B/R valid). **Mandatory** — a crossbar that hangs on unmapped access
is a correctness bug (this is what the fabric must never do).

## 6. Interrupt + debug integration
- **PLIC + CLINT** are AXI4-Lite MMIO slaves on the control plane (Linux-standard).
- **CLIC** (real-time option) is a separate modular block (draft spec tracked, §S15).
- **Debug (JTAG DTM)** is a separate pin-side block, not on the AXI bus.

## 7. Formal properties (the correctness spec — SymbiYosys, following ZipCPU)

Every `eth_axi` module ships with SVA properties checked by `sby` (and simulated):
1. `VALID && !READY` → `VALID` stays asserted and payload stable until handshake.
2. No `VALID` depends combinationally on `READY` (structural check).
3. Crossbar: every accepted request eventually gets a response (liveness, bounded).
4. Response ID: a response's master-index prefix equals the requesting master's index.
5. Decode-error: any unmapped address yields a DECERR response, never a hang.
6. AXI4-Stream: `tvalid`/`tlast`/`tdata` stable while stalled.

## 8. v0 deliverables (Phase A)
1. `eth_axi_lite_slave.sv` — a full-speed AXI4-Lite register slave (the EMRI/peripheral
   template). ✅
2. `eth_axi_stream.sv` — AXI4-Stream source/sink + a skid buffer. ✅
3. `eth_axi_xbar.sv` — the AXI4 crossbar (N×M, decode, arb, ID routing, decode-error slave). ✅
4. Formal properties + a `sby` config per module + iverilog smoke TBs.
5. The BMC XBUS→AXI4 bridge hangs off this socket (separate task, E1-BMC1 follow-up).

## 9. Data plane — AXI4 memory-slave contract (v0.1 draft, already implemented)

> Status: **implemented** by `ethereal-shell/rtl/dram/eth_dram_ctrl.sv` (+ the behavioral
> `eth_dram_stub.sv`); this section records the contract so implementations and tests stop
> deriving it from code alone. Freeze alongside the `eth_axi_xbar` burst extension (E2-AXI2).

1. **Socket, not a bus.** The SoC reaches DRAM only through the `eth_dram_ctrl` AXI4
   memory-slave socket (S15 §4): one frozen parameter surface
   (`AXI_AW/AXI_DW/AXI_IDW/MEM_BASE/MEM_BYTES/RD_LATENCY/WR_LATENCY`) and the complete AXI4
   slave channel set. Target-specific backends (Zynq PS DDR, Gowin GW5 hard-DDR3) plug into
   the socket's seam at build time and always ship a behavioral stub (ADR-017).
2. **Addressing (INCR only in v0.1).** `Address_1 = AxADDR`; for beat N > 1,
   `Address_N = align_down(AxADDR, 2**AxSIZE) + (N-1) * 2**AxSIZE` (IHI0022G §A3.4.1).
   Narrow/unaligned transfers use `WSTRB` lanes; a read returns the containing bus word.
   `WRAP`/`FIXED` are `SLVERR` in v0.1.
3. **Response policy — one code per burst, uniform across its beats:** `OKAY` when every
   byte lies inside the window; `SLVERR` for protocol/transfer illegality (`AxBURST` not
   INCR, `AxSIZE` > bus width, 4 KiB crossing, `AxLOCK`); `DECERR` for address decode
   failure (outside `[MEM_BASE, MEM_BASE+MEM_BYTES)`).
4. **Error completion (matches the xbar's §5.3 built-in slave):** an erroring write still
   sinks every `W` beat and commits nothing; an erroring read returns exactly one beat
   (`RDATA = 0`, `RLAST = 1`) and consumes the `AR`.
5. **Timing:** `AW` captured → `WREADY` next cycle; last `W` beat → `BVALID` after
   `WR_LATENCY`; `AR` captured → first `RVALID` after `RD_LATENCY`+1, then one beat per cycle
   while `RREADY`. All handshake outputs come from stored state (no combinational
   input→output path), and a stalled `R` beat's payload is stable.
6. **Resolved (E2-AXI2, 2026-09-12):** the `eth_axi_xbar` now carries `AxLEN/AxSIZE/AxBURST/
   WLAST/RLAST` (behind `BURST_EN`, §5.2), so a burst-capable master (the DMA, the RV core)
   can reach the DRAM socket through the crossbar; direct attach remains valid and is what
   the current DMA and DRAM testbenches use.

## 10. Open items (TBD)
1. ~~**AXI4 full bursts vs AXI4-Lite-only in v0:** ... Decision at RTL time.~~
   **Resolved (E2-AXI2, 2026-09-12):** both — burst routing behind `BURST_EN` (default 0
   keeps the Lite/single-beat contract bit-identical, 1 routes INCR bursts); see §5.2.
2. **ATOP atomics timing:** 见 §5.2 的说明 —— v0.1 的 `ATOP` 是**总线级**事务（SMP 才需要）；**指令级 RISC-V A 扩展（LR/SC/AMO）**单核固件/内核就需要，且以普通读写经 D 口完成、不在线上产生 `ATOP`（2026-09-12 澄清，见 `docs/reports/report-E2-RV2-linux-gap-20260912.md` G2）。原文：needed only for SMP Linux (not the single-core GW5
   profile).
3. **64-bit datapath:** `AXI_DW=64` parameter — enable when the app-cluster/DRAM path lands.
4. **NI adapter (AXI↔mailbox NoC):** separate RFC-002 update; not in this spec.
