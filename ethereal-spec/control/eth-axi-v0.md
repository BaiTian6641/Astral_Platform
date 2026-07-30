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

### 5.2 v0 scope
- Bursts: INCR + WRAP (FIXED optional/skipped initially). No read-data interleaving
  across IDs (AXI4 removed it — simpler). Same-ID transactions complete in order;
  different-ID may complete out of order (multiple outstanding).
- ATOP atomics: **deferred to v0.1** (needed only for SMP Linux; the v0 fabric + single-core
  bring-up don't require them).

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

## 9. Open items (TBD)
1. **AXI4 full bursts vs AXI4-Lite-only in v0:** the crossbar is designed for full AXI4
   but v0 bring-up may run it AXI4-Lite-first (simpler). Decision at RTL time.
2. **ATOP atomics timing:** v0.1, needed only for SMP Linux (not the single-core GW5
   profile).
3. **64-bit datapath:** `AXI_DW=64` parameter — enable when the app-cluster/DRAM path lands.
4. **NI adapter (AXI↔mailbox NoC):** separate RFC-002 update; not in this spec.
