`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_axi_engine
// Description: Single-outstanding AXI4 INCR-burst master engine — the ONE AXI4
//              master port of `eth_dma_mc` (S15 §3: "AXI4 主").
// Details:     Executes exactly one transaction at a time.  A transaction is
//              requested by a DMA channel through the arbitrated request port
//              (tx_*) and is one of:
//                * read  (tx_op_i=0): AR -> R beats pushed out on rd_* until the
//                  consumer accepts them (rd_ready_i is the backpressure), the
//                  burst ends on RLAST (an erroring slave may legally return a
//                  single beat with RLAST=1, eth-axi-v0.md §9.4);
//                * write (tx_op_i=1): AW -> W beats pulled from the producer on
//                  wr_* -> B.  WLAST is asserted exactly on the last beat of the
//                  requested length (tx_len_i+1 beats).
//              tx_done_o is a one-cycle pulse carrying tx_resp_o, the response
//              of the burst (first non-OKAY R response latched; B response for a
//              write).  A response whose ID does not match the outstanding
//              transaction is reported as SLVERR.
//
//              AXI discipline (eth-axi-v0.md §2 rules 1-2, §7):
//                * every VALID (AW/W/AR) is a registered or state-driven output
//                  with a stable payload; it is never withdrawn before the
//                  matching READY, and no output waits combinationally on a
//                  slave READY to become valid (BREADY/RREADY are the only
//                  READY outputs and may deassert freely);
//                * AW/W/AR/RREADY are only asserted inside their phase, so a
//                  stalled transfer cannot leak into the next phase;
//                * RREADY is gated by the consumer's rd_ready_i, so a full FIFO
//                  simply stalls the read burst (no data lost or duplicated).
//              Formal properties (VALID stability, WLAST placement, beat
//              accounting, single-outstanding) live under `ifdef FORMAL and are
//              proven by ethereal-shell/formal/eth_dma_mc.sby (SymbiYosys).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (多通道 DMA:
//              AXI4 主) · ethereal-spec/control/eth-axi-v0.md §2 (rules 1-2),
//              §7 (props 1-2), §9 (DRAM socket contract)
// Notes:       iverilog -g2012 compatible (flat ports, two-segment FSM, no
//              procedural loops).  v0 handles full-width beats only
//              (WSTRB all ones): narrow/unaligned transfers are a v0.1 item.
module eth_dma_axi_engine #(
    parameter int AXI_AW  = 32,
    parameter int AXI_DW  = 64,
    parameter int AXI_IDW = 4
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- transaction request (arbitrated; accepted while idle only) ----
    input  logic                    tx_valid_i,
    output logic                    tx_ready_o,
    input  logic                    tx_op_i,          // 0 = read, 1 = write
    input  logic [AXI_AW-1:0]       tx_addr_i,
    input  logic [7:0]              tx_len_i,         // beats - 1
    input  logic [AXI_IDW-1:0]      tx_id_i,
    output logic                    tx_done_o,        // 1-cycle completion pulse
    output logic [1:0]              tx_resp_o,        // resp of the completed burst
    // ---- read data push (to the owning channel) ----
    output logic                    rd_valid_o,
    input  logic                    rd_ready_i,
    output logic [AXI_DW-1:0]       rd_data_o,
    // ---- write data pull (from the owning channel) ----
    input  logic                    wr_valid_i,
    output logic                    wr_ready_o,
    input  logic [AXI_DW-1:0]       wr_data_i,
    // ---- AXI4 master port ----
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [AXI_AW-1:0]       m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    output logic [AXI_IDW-1:0]      m_axi_awid,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic [AXI_DW-1:0]       m_axi_wdata,
    output logic [AXI_DW/8-1:0]     m_axi_wstrb,
    output logic                    m_axi_wlast,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    input  logic [1:0]              m_axi_bresp,
    input  logic [AXI_IDW-1:0]      m_axi_bid,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    output logic [AXI_AW-1:0]       m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,
    output logic [AXI_IDW-1:0]      m_axi_arid,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic [AXI_DW-1:0]       m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,
    input  logic [AXI_IDW-1:0]      m_axi_rid
);

    // ------------------------------------------------------------------
    // Encodings
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        E_IDLE = 3'd0,
        E_AR   = 3'd1,
        E_R    = 3'd2,
        E_AW   = 3'd3,
        E_W    = 3'd4,
        E_B    = 3'd5
    } eng_state_e;

    localparam logic [1:0] AXI_BURST_INCR = 2'b01;
    localparam logic [2:0] AXI_SIZE_C     = 3'($clog2(AXI_DW / 8));

    // ------------------------------------------------------------------
    // State + datapath registers
    // ------------------------------------------------------------------
    eng_state_e             state_r, state_nxt;
    logic                   tx_op_r,   tx_op_nxt;
    logic [AXI_AW-1:0]      tx_addr_r, tx_addr_nxt;
    logic [7:0]             tx_len_r,  tx_len_nxt;
    logic [AXI_IDW-1:0]     tx_id_r,   tx_id_nxt;
    logic [7:0]             beat_cnt_r, beat_cnt_nxt;
    logic [1:0]             resp_r,    resp_nxt;
    logic                   tx_done_r, tx_done_nxt;

    logic                   r_err_first;
    logic                   r_id_bad;
    logic                   b_id_bad;

    assign tx_ready_o = (state_r == E_IDLE);

    // AW / AR: registered payload, asserted only in their address phase.
    assign m_axi_awvalid = (state_r == E_AW);
    assign m_axi_awaddr  = tx_addr_r;
    assign m_axi_awlen   = tx_len_r;
    assign m_axi_awsize  = AXI_SIZE_C;
    assign m_axi_awburst = AXI_BURST_INCR;
    assign m_axi_awid    = tx_id_r;

    assign m_axi_arvalid = (state_r == E_AR);
    assign m_axi_araddr  = tx_addr_r;
    assign m_axi_arlen   = tx_len_r;
    assign m_axi_arsize  = AXI_SIZE_C;
    assign m_axi_arburst = AXI_BURST_INCR;
    assign m_axi_arid    = tx_id_r;

    // W: payload straight from the producer (which holds it until accepted);
    // WLAST is a pure function of the beat counter vs the requested length.
    assign m_axi_wvalid = (state_r == E_W) && wr_valid_i;
    assign m_axi_wdata  = wr_data_i;
    assign m_axi_wstrb  = {(AXI_DW/8){1'b1}};
    assign m_axi_wlast  = (beat_cnt_r == tx_len_r);
    assign wr_ready_o   = (state_r == E_W) && m_axi_wready;

    // R: accept beats only in the read phase, gated by consumer backpressure.
    assign m_axi_bready = (state_r == E_B);
    assign m_axi_rready = (state_r == E_R) && rd_ready_i;
    assign rd_valid_o   = (state_r == E_R) && m_axi_rvalid;
    assign rd_data_o    = m_axi_rdata;

    assign tx_done_o = tx_done_r;
    assign tx_resp_o = resp_r;

    assign r_err_first = (m_axi_rresp != 2'b00) && (resp_r == 2'b00);
    assign r_id_bad    = (m_axi_rid != tx_id_r) && (resp_r == 2'b00);
    assign b_id_bad    = (m_axi_bid != tx_id_r);

    // ------------------------------------------------------------------
    // Next-state logic (combinational segment; defaults first)
    // ------------------------------------------------------------------
    always_comb begin
        state_nxt    = state_r;
        tx_op_nxt    = tx_op_r;
        tx_addr_nxt  = tx_addr_r;
        tx_len_nxt   = tx_len_r;
        tx_id_nxt    = tx_id_r;
        beat_cnt_nxt = beat_cnt_r;
        resp_nxt     = resp_r;
        tx_done_nxt  = 1'b0;

        case (state_r)
            E_IDLE: begin
                if (tx_valid_i) begin
                    tx_op_nxt    = tx_op_i;
                    tx_addr_nxt  = tx_addr_i;
                    tx_len_nxt   = tx_len_i;
                    tx_id_nxt    = tx_id_i;
                    beat_cnt_nxt = 8'd0;
                    resp_nxt     = 2'b00;
                    if (tx_op_i) begin
                        state_nxt = E_AW;
                    end else begin
                        state_nxt = E_AR;
                    end
                end
            end
            E_AR: begin
                if (m_axi_arready) begin
                    state_nxt = E_R;
                end
            end
            E_R: begin
                if (m_axi_rvalid && rd_ready_i) begin
                    beat_cnt_nxt = beat_cnt_r + 8'd1;
                    if (r_err_first) begin
                        resp_nxt = m_axi_rresp;
                    end else if (r_id_bad) begin
                        resp_nxt = 2'b10;               // SLVERR: wrong response ID
                    end
                    if (m_axi_rlast) begin
                        state_nxt   = E_IDLE;
                        tx_done_nxt = 1'b1;
                    end
                end
            end
            E_AW: begin
                if (m_axi_awready) begin
                    state_nxt = E_W;
                end
            end
            E_W: begin
                if (wr_valid_i && m_axi_wready) begin
                    beat_cnt_nxt = beat_cnt_r + 8'd1;
                    if (beat_cnt_r == tx_len_r) begin
                        state_nxt = E_B;
                    end
                end
            end
            E_B: begin
                if (m_axi_bvalid) begin
                    resp_nxt    = b_id_bad ? 2'b10 : m_axi_bresp;
                    state_nxt   = E_IDLE;
                    tx_done_nxt = 1'b1;
                end
            end
            default: begin
                state_nxt = E_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // State update
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r    <= E_IDLE;
            tx_op_r    <= 1'b0;
            tx_addr_r  <= {AXI_AW{1'b0}};
            tx_len_r   <= 8'd0;
            tx_id_r    <= {AXI_IDW{1'b0}};
            beat_cnt_r <= 8'd0;
            resp_r     <= 2'b00;
            tx_done_r  <= 1'b0;
        end else begin
            state_r    <= state_nxt;
            tx_op_r    <= tx_op_nxt;
            tx_addr_r  <= tx_addr_nxt;
            tx_len_r   <= tx_len_nxt;
            tx_id_r    <= tx_id_nxt;
            beat_cnt_r <= beat_cnt_nxt;
            resp_r     <= resp_nxt;
            tx_done_r  <= tx_done_nxt;
        end
    end

    // ------------------------------------------------------------------
    // Formal properties (SymbiYosys / smtbmc; NOT compiled for lint or sim).
    // Proven by ethereal-shell/formal/eth_dma_mc.sby.
    // ------------------------------------------------------------------
`ifdef FORMAL
    // Properties are stated as inductive relations over (current state, inputs,
    // next state): every assertion is a pure function of the FSM registers and
    // the current inputs, except the VALID-stability pair which looks one cycle
    // back at a register output.  That form is what makes the proof hold by
    // k-induction at unbounded depth (no harness length bound, no property-only
    // counting state), and it is exactly the AXI obligation: the master may not
    // withdraw a presented beat, must place WLAST on the last beat, must count
    // one beat per handshake, must leave a phase only on the protocol-defined
    // event, and must never run two transactions at once.
    logic past_valid = 1'b0;

    always_ff @(posedge clk_i) past_valid <= 1'b1;

    // Initialize deterministically: hold reset in the first cycle so the engine
    // cannot start from an arbitrary state (spurious counterexamples).
    always_ff @(posedge clk_i) if (!past_valid) assume(!rst_ni);

    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // ---- environment contract --------------------------------------
            // The write-data producer holds a presented beat until accepted.
            if ($past(wr_valid_i) && !$past(wr_ready_o)) begin
                assume(wr_valid_i);
                assume(wr_data_i == $past(wr_data_i));
            end
            // Slave contract (eth-axi-v0.md §9): a burst ends with RLAST on the
            // last requested beat — a compliant slave never streams more than
            // AxLEN+1 beats — and only an erroring read ends early.
            if (m_axi_rvalid && m_axi_rready && (beat_cnt_r == tx_len_r)) begin
                assume(m_axi_rlast);
            end
            if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                assume((beat_cnt_r == tx_len_r) || (m_axi_rresp != 2'b00));
            end

            // ---- F1: no VALID withdrawal before handshake, payload stable ---
            if ($past(m_axi_awvalid) && !$past(m_axi_awready)) begin
                assert(m_axi_awvalid);
                assert(m_axi_awaddr == $past(m_axi_awaddr));
                assert(m_axi_awlen  == $past(m_axi_awlen));
                assert(m_axi_awid   == $past(m_axi_awid));
            end
            if ($past(m_axi_arvalid) && !$past(m_axi_arready)) begin
                assert(m_axi_arvalid);
                assert(m_axi_araddr == $past(m_axi_araddr));
                assert(m_axi_arlen  == $past(m_axi_arlen));
                assert(m_axi_arid   == $past(m_axi_arid));
            end
            // F2: W held stable while stalled (payload, strobes and WLAST)
            if ($past(m_axi_wvalid) && !$past(m_axi_wready)) begin
                assert(m_axi_wvalid);
                assert(m_axi_wdata == $past(m_axi_wdata));
                assert(m_axi_wstrb == $past(m_axi_wstrb));
                assert(m_axi_wlast == $past(m_axi_wlast));
            end

            // ---- output phase gating ----------------------------------------
            if (m_axi_awvalid) assert(state_r == E_AW);
            if (m_axi_arvalid) assert(state_r == E_AR);
            if (m_axi_wvalid)  assert(state_r == E_W);
            if (m_axi_rready)  assert(state_r == E_R);
            if (m_axi_bready)  assert(state_r == E_B);

            // ---- F3 + F4 (write stream): WLAST exactly on the last beat, and
            //      exactly one beat counted per accepted W beat, so exactly
            //      tx_len+1 beats are offered and the stream cannot be extended
            if (m_axi_wvalid) begin
                assert(m_axi_wlast == (beat_cnt_r == tx_len_r));
            end
            if (state_r == E_W && m_axi_wvalid && m_axi_wready) begin
                assert(beat_cnt_nxt == beat_cnt_r + 8'd1);
                assert((state_nxt == E_B) == (beat_cnt_r == tx_len_r));
            end

            // ---- F4 (read stream): R beats are accepted only while the read
            //      burst is open, and the burst closes exactly on RLAST (so no
            //      beat is dropped or counted twice)
            if (state_r == E_R && m_axi_rvalid && rd_ready_i) begin
                assert((state_nxt == E_IDLE) == m_axi_rlast);
            end

            // ---- F4 (single AW / single AR / single completion per grant):
            //      the address phases have no path back out of a data phase, and
            //      the data phases exit only to their response phase or to idle
            case (state_r)
                E_IDLE:  assert((state_nxt == E_IDLE) || (state_nxt == E_AW) ||
                                (state_nxt == E_AR));
                E_AR:    assert((state_nxt == E_AR) || (state_nxt == E_R));
                E_R:     assert((state_nxt == E_R)  || (state_nxt == E_IDLE));
                E_AW:    assert((state_nxt == E_AW) || (state_nxt == E_W));
                E_W:     assert((state_nxt == E_W)  || (state_nxt == E_B));
                E_B:     assert((state_nxt == E_B)  || (state_nxt == E_IDLE));
                default: assert(state_nxt == E_IDLE);
            endcase

            // ---- F5: single outstanding transaction --------------------------
            if (state_r != E_IDLE) begin
                assert(!tx_ready_o);
            end
            if (state_r == E_IDLE && tx_valid_i) begin
                assert((state_nxt == E_AW) || (state_nxt == E_AR));
            end
            // a response phase is only reachable from its own data phase
            if (state_r == E_B) assert($past(state_r != E_AW));

            // ---- F6: BREADY only after the write data stream finished --------
            if (state_r == E_B && m_axi_bvalid) begin
                assert(state_nxt == E_IDLE);
            end

            // ---- covers (witness non-vacuity of the safety proof) ------------
            cover(tx_done_o && tx_op_r);
            cover(tx_done_o && !tx_op_r);
            cover(tx_done_o && tx_op_r && (resp_r != 2'b00));
            cover(tx_done_o && !tx_op_r && (resp_r != 2'b00));
        end
    end

`endif

endmodule

`default_nettype wire
