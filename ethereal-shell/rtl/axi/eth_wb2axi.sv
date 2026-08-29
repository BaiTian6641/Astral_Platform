`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_wb2axi
// Description: Wishbone -> AXI4(-Lite) master bridge (BMC XBUS front-end).
// Details:     Converts a classic single-transfer Wishbone master (cyc/stb/ack,
//              the NEORV32 XBUS port) into an AXI4-Lite-style master so the BMC
//              is a first-class master on the in-house `eth_axi` fabric
//              (ADR-018 BMC integration). This is OUR OWN bridge (in-house,
//              CERN-OHL-S-2.0): the upstream NEORV32 `xbus2axi4_bridge.vhd` is
//              third-party and is intentionally NOT used (ADR-018 in-house rule).
//
//              MODEL = single-outstanding, single-beat (the BMC is a management
//              core, not a bandwidth engine; NEORV32 XBUS issues one classic
//              transfer at a time):
//                * WRITE: capture {adr,dat,sel} on (cyc&stb&we), drive AW + W
//                  together, complete on B -> ack (Bresp OKAY=ack, else err).
//                * READ : capture {adr,sel} on (cyc&stb&!we), drive AR, complete
//                  on R -> ack + rdata (Rresp OKAY=ack, else err).
//                * Only ONE direction is ever in flight (the core holds cyc/stb
//                  stable until ack/err, so a new transfer never starts while
//                  one is pending).
//
//              ERROR MAPPING: AXI OKAY -> Wishbone ack; SLVERR/DECERR -> Wishbone
//              err. The Wishbone `err` terminates the cycle (the core retries /
//              traps per its own policy).
//
//              cti/tag: PASS-THROUGH-IGNORED. NEORV32 XBUS drives cti=000
//              (classic single transfer) for all loads/stores in v0; bursts are
//              never generated, so the bridge is single-beat (AxLEN=0 implied by
//              the AXI4-Lite subset it drives). Documented as an ASSUMPTION.
// Maintainer:  BaiTian6641
// Created:     2026-08-08
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §3 (AXI4-Lite master side);
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md (BMC = AXI master)
// Notes:       iverilog-compatible (flat ports, no SV interfaces, no packed-2D
//              params). AXI ID is unused (the BMC issues one outstanding
//              transaction); the xbar prepends the master index, so the bridge
//              drives no ID pins. Registered FSM (typedef enum, two-segment) per
//              G1; no comb input->output path to AXI VALID (spec §2 rule 1) —
//              AW/W/AR valids are registered on transfer capture.
module eth_wb2axi #(
    parameter int AXI_AW = 32,             // address width
    parameter int AXI_DW = 32              // data width (v0 = 32)
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,

    // ---- Wishbone slave (from the BMC XBUS master) ----
    input  logic [AXI_AW-1:0]     wb_adr_i,
    input  logic [AXI_DW-1:0]     wb_dat_i,   // write data (from master)
    output logic [AXI_DW-1:0]     wb_dat_o,   // read data (to master)
    input  logic                  wb_we_i,    // 1 = write, 0 = read
    input  logic [(AXI_DW/8)-1:0] wb_sel_i,   // byte enable
    input  logic                  wb_stb_i,   // strobe
    input  logic                  wb_cyc_i,   // valid cycle
    output logic                  wb_ack_o,   // transfer acknowledge
    output logic                  wb_err_o,   // transfer error

    // ---- AXI4 master (to the eth_axi fabric / xbar) ----
    // AW
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,
    output logic [AXI_AW-1:0]     m_axi_awaddr,
    output logic [2:0]            m_axi_awprot,
    // W
    output logic                  m_axi_wvalid,
    input  logic                  m_axi_wready,
    output logic [AXI_DW-1:0]     m_axi_wdata,
    output logic [(AXI_DW/8)-1:0] m_axi_wstrb,
    // B
    input  logic                  m_axi_bvalid,
    output logic                  m_axi_bready,
    input  logic [1:0]            m_axi_bresp,
    // AR
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,
    output logic [AXI_AW-1:0]     m_axi_araddr,
    output logic [2:0]            m_axi_arprot,
    // R
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready,
    input  logic [AXI_DW-1:0]     m_axi_rdata,
    input  logic [1:0]            m_axi_rresp
);

    // AXI response codes
    localparam logic [1:0] RESP_OKAY = 2'b00;

    // FSM: IDLE -> (W_DATA | R_DATA) -> RESP -> IDLE
    typedef enum logic [1:0] {
        S_IDLE,                            // no transfer in flight
        S_WDATA,                           // write: AW+W issued, awaiting handshake
        S_RDATA,                           // read:  AR issued, awaiting handshake
        S_RESP                             // response received: drive ack/err 1 cycle
    } state_e;

    state_e              state_r, state_nxt;

    // captured transfer payload
    logic [AXI_AW-1:0]     adr_r;
    logic [AXI_DW-1:0]     wdat_r;
    logic [(AXI_DW/8)-1:0] sel_r;
    logic [AXI_DW-1:0]     rdat_r;
    logic                  err_r;

    // start of a new Wishbone transfer (single-outstanding: only from IDLE)
    logic wb_req;
    assign wb_req = wb_cyc_i & wb_stb_i;

    // ------------------------------------------------------------------
    // Next-state logic. A write completes ONLY on the B response (AXI rule:
    // the slave asserts B after both AW and W are accepted; B may lag the
    // AW/W handshakes by any number of cycles), a read completes ONLY on R.
    // Transitioning on the AW/W handshakes would ack the Wishbone master
    // early and leave B unconsumed (bready is low outside S_WDATA), wedging
    // the slave's write channel for the NEXT write — do not do that.
    // ------------------------------------------------------------------
    always_comb begin
        state_nxt = state_r;
        case (state_r)
            S_IDLE: begin
                if (wb_req) begin
                    // explicit if/else (not ?:) so iverilog accepts the enum assign
                    if (wb_we_i) state_nxt = S_WDATA;
                    else         state_nxt = S_RDATA;
                end
            end
            S_WDATA: begin
                if (m_axi_bvalid) state_nxt = S_RESP;   // B received -> done
            end
            S_RDATA: begin
                if (m_axi_rvalid) state_nxt = S_RESP;
            end
            S_RESP: begin
                state_nxt = S_IDLE;          // ack/err is a single-cycle pulse
            end
            default: state_nxt = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // Sequential: state, captured payload, AXI valids, response latch.
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r       <= S_IDLE;
            adr_r         <= {AXI_AW{1'b0}};
            wdat_r        <= {AXI_DW{1'b0}};
            sel_r         <= {(AXI_DW/8){1'b0}};
            rdat_r        <= {AXI_DW{1'b0}};
            err_r         <= 1'b0;
            m_axi_awvalid <= 1'b0;
            m_axi_wvalid  <= 1'b0;
            m_axi_arvalid <= 1'b0;
        end else begin
            state_r <= state_nxt;
            case (state_r)
                S_IDLE: begin
                    if (wb_req) begin
                        // capture the transfer and raise the request channel(s)
                        adr_r  <= wb_adr_i;
                        sel_r  <= wb_sel_i;
                        err_r  <= 1'b0;
                        if (wb_we_i) begin
                            wdat_r        <= wb_dat_i;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                        end else begin
                            m_axi_arvalid <= 1'b1;
                        end
                    end
                end
                S_WDATA: begin
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;  // AW accepted -> drop valid
                    if (m_axi_wready)  m_axi_wvalid  <= 1'b0;  // W accepted  -> drop valid
                    if (m_axi_bvalid) begin
                        err_r <= (m_axi_bresp != RESP_OKAY);
                    end
                end
                S_RDATA: begin
                    if (m_axi_arready) m_axi_arvalid <= 1'b0;  // AR accepted -> drop valid
                    if (m_axi_rvalid) begin
                        rdat_r <= m_axi_rdata;
                        err_r  <= (m_axi_rresp != RESP_OKAY);
                    end
                end
                default: begin
                    // S_RESP: clear any residual valids (should already be low)
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // AXI request channels (registered payload, spec §2 rule 1: no comb path
    // from a Wishbone input to an AXI VALID — the valids are FSM registers).
    // ------------------------------------------------------------------
    assign m_axi_awaddr = adr_r;
    assign m_axi_awprot = 3'b000;             // data, secure, unprivileged (mgmt core)
    assign m_axi_wdata  = wdat_r;
    assign m_axi_wstrb  = sel_r;
    assign m_axi_araddr = adr_r;
    assign m_axi_arprot = 3'b000;

    // Response readiness: single-outstanding => always ready to take the
    // response as soon as it is offered.
    assign m_axi_bready = (state_r == S_WDATA);
    assign m_axi_rready = (state_r == S_RDATA);

    // ------------------------------------------------------------------
    // Wishbone completion: ack/err asserted for one cycle in S_RESP.
    // ------------------------------------------------------------------
    assign wb_ack_o = (state_r == S_RESP) & ~err_r;
    assign wb_err_o = (state_r == S_RESP) &  err_r;
    assign wb_dat_o = rdat_r;

`ifdef FORMAL
    // ==================================================================
    // Formal properties (SymbiYosys, see ethereal-shell/formal/eth_wb2axi.sby).
    // Prove: AXI VALID stability, write-completes-only-on-B (regression guard
    // for the 2026-08-30 premature-ack bug), read-completes-only-on-R, and the
    // OKAY->ack / SLVERR|DECERR->err response mapping. Assumptions constrain
    // the AXI slave and the Wishbone master to their protocol contracts.
    // ==================================================================
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;

    // Initialize deterministically: hold reset for the first cycle so the FSM
    // starts in S_IDLE (otherwise the engine picks an arbitrary initial state
    // and produces spurious counterexamples unrelated to real operation).
    always_ff @(posedge clk_i) begin
        if (!past_valid) assume(!rst_ni);
    end

    // ---- Assumptions on the environment (AXI slave + Wishbone master) -------
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // AXI slave: a response is held stable until accepted.
            if ($past(m_axi_bvalid) && !$past(m_axi_bready))
                assume(m_axi_bvalid && (m_axi_bresp == $past(m_axi_bresp)));
            if ($past(m_axi_rvalid) && !$past(m_axi_rready))
                assume(m_axi_rvalid && (m_axi_rdata == $past(m_axi_rdata))
                       && (m_axi_rresp == $past(m_axi_rresp)));
            // AW/W/AR *_ready are free (the slave may accept or stall).

            // AXI ordering (spec A3.4.1): the slave asserts B only after BOTH
            // the AW and W handshakes complete, and R only after the AR
            // handshake completes. So while a request channel is presented and
            // not yet accepted, the matching response must NOT be offered.
            // (Without this the engine could violate AXI by answering early,
            // e.g. B while AW is stalled, which is not a DUT bug.)
            if (m_axi_awvalid && !m_axi_awready) assume(!m_axi_bvalid);
            if (m_axi_wvalid  && !m_axi_wready)  assume(!m_axi_bvalid);
            if (m_axi_arvalid && !m_axi_arready) assume(!m_axi_rvalid);

            // Wishbone master (NEORV32 XBUS): a presented classic transfer is
            // held stable until it completes (ack/err).
            if ($past(wb_cyc_i) && $past(wb_stb_i) && !$past(wb_ack_o) && !$past(wb_err_o)) begin
                assume(wb_cyc_i && wb_stb_i);
                assume(wb_adr_i == $past(wb_adr_i));
                assume(wb_dat_i == $past(wb_dat_i));
                assume(wb_sel_i == $past(wb_sel_i));
                assume(wb_we_i  == $past(wb_we_i));
            end
            // After a completion the master drops stb (single classic transfers).
            if ($past(wb_ack_o) || $past(wb_err_o))
                assume(!wb_stb_i);
        end
    end

    // ---- Assertions on the DUT (eth_wb2axi) ----------------------------------
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // prop 1: AXI request VALIDs + payloads are stable while stalled
            // (registered; spec §2 rule 1 — no comb input->VALID path).
            if ($past(m_axi_awvalid) && !$past(m_axi_awready)) begin
                assert(m_axi_awvalid);
                assert(m_axi_awaddr == $past(m_axi_awaddr));
            end
            if ($past(m_axi_wvalid) && !$past(m_axi_wready)) begin
                assert(m_axi_wvalid);
                assert(m_axi_wdata == $past(m_axi_wdata));
                assert(m_axi_wstrb == $past(m_axi_wstrb));
            end
            if ($past(m_axi_arvalid) && !$past(m_axi_arready)) begin
                assert(m_axi_arvalid);
                assert(m_axi_araddr == $past(m_axi_araddr));
            end

            // prop 2 (REGRESSION GUARD): a WRITE completes ONLY on the B
            // response — the FSM never leaves S_WDATA without bvalid. (The
            // 2026-08-30 bug transitioned on the AW&W handshake, acking early
            // and leaving B unconsumed.)
            if ($past(state_r) == S_WDATA && !$past(m_axi_bvalid))
                assert(state_r == S_WDATA);
            // a READ completes ONLY on the R response.
            if ($past(state_r) == S_RDATA && !$past(m_axi_rvalid))
                assert(state_r == S_RDATA);

            // Auxiliary invariants (strengthen k-induction): an AXI request
            // VALID only exists in its data state (raised on entry, dropped on
            // accept or on the transition to S_RESP). These constrain the
            // induction state space to reachable configurations.
            if (m_axi_awvalid) assert(state_r == S_WDATA);
            if (m_axi_wvalid)  assert(state_r == S_WDATA);
            if (m_axi_arvalid) assert(state_r == S_RDATA);

            // prop 3: Wishbone completion only in S_RESP; the response maps
            // OKAY->ack, SLVERR/DECERR->err (never ack on an error response).
            if (wb_ack_o) assert(state_r == S_RESP && !err_r);
            if (wb_err_o) assert(state_r == S_RESP &&  err_r);
            if ($past(state_r) == S_WDATA && $past(m_axi_bvalid) && ($past(m_axi_bresp) != 2'b00))
                assert(state_r == S_RESP && err_r);
            if ($past(state_r) == S_RDATA && $past(m_axi_rvalid) && ($past(m_axi_rresp) != 2'b00))
                assert(state_r == S_RESP && err_r);
        end
    end
`endif

endmodule
`default_nettype wire
