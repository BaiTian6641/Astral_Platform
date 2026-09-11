`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_axi_master
// Description: AXI4 master bridge for the eth_rv D port — the core's 64-bit
//              aligned-beat request/ready contract on one side (C14 §4), a full
//              AXI4 INCR master on the other, driving the `eth_dram_ctrl` DRAM
//              socket directly (eth-axi-v0.md §9; S15 §2.2).
// Details:     THE CONTRACT ON THE TWO SIDES
//
//                * Core side (slave): `dmem_req_i` is held until
//                  `dmem_ready_o`; the transaction is the EIGHT BYTES of the
//                  8-byte-aligned window at `dmem_addr_i & ~7` (the address
//                  itself may be unaligned — the core reports the unaligned
//                  address and expects the aligned beat). A store presents
//                  `dmem_wdata_i`/`dmem_wstrb_i` already lane-shifted into that
//                  window. `dmem_ready_o` is a one-cycle pulse: on the R beat
//                  the core asked for (reads) or on the B response (writes).
//                * AXI side (master): one outstanding transaction, INCR bursts
//                  only, AxSIZE = log2(AXI_DW/8).
//                    - store: AW -> W (one full-width beat, WLAST) -> B. The
//                      core's beat is acknowledged only AFTER the write response,
//                      so a store is never posted: the memory target is up to
//                      date when the instruction retires (what the DiffTest's
//                      memory comparison relies on).
//                    - load: AR -> R beats. A single beat is an INCR burst of
//                      length 1. With LINE_BEATS > 1 the master fills a whole
//                      LINE_BEATS*8-byte line with ONE INCR burst and serves the
//                      requested beat from it, keeping the line for the following
//                      sequential accesses (the "bursts where useful" case: a
//                      straight-line load sequence costs one burst instead of one
//                      transaction per beat). A store invalidates the line
//                      (write-through), so a cached read can never go stale.
//                  A multi-beat burst is only launched when the WHOLE line lies
//                  inside the memory window the socket implements
//                  (MEM_BASE/MEM_BYTES, mirroring eth_dram_ctrl); otherwise the
//                  access degrades to a single-beat transaction, so a burst can
//                  never be answered DECERR just because it ran off the window.
//
//              TOTALITY: the bridge never leaves a beat unacknowledged. A
//              compliant slave always answers a burst with RLAST on the last
//              requested beat; if a slave ends a read early with an error
//              response (allowed for an erroring burst, eth-axi-v0.md §9.4),
//              the master still hands the core a beat on RLAST so the pipeline
//              cannot wedge.
//
//              ERROR RESPONSE (E2-RV1 increment 5): a beat is acknowledged with
//              `dmem_ready_o` and, when the transaction failed, `dmem_err_o` in
//              the SAME cycle — a non-OKAY R/B response (the DRAM socket's DECERR
//              for an address outside its window) or an address the AXI window
//              cannot carry at all (`!addr_reachable`: answered immediately,
//              without a transaction, because a truncated address could land
//              inside the window and quietly succeed). The core turns that pair
//              into the architectural load/store access fault (mcause 5/7,
//              mtval = the address) — an error is never a silent success and
//              never a wedge. An erroring read burst never validates the read
//              line either, so a poisoned line buffer cannot serve wrong bytes to
//              the following sequential loads. `axi_err_o` (sticky) remains the
//              SoC-level observability of non-OKAY responses and ID mismatches.
//
//              The core's D port holds its request until accepted and cannot be
//              abandoned mid-transaction (a younger EX trap implies !ex_stall,
//              while a stalled D port implies ex_stall), so no request is lost;
//              the bridge is nevertheless written to complete whatever AXI
//              transaction it started and to ignore a request that went away.
//              AXI_DW must equal the core's beat width (64).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 5: per-transaction error response (dmem_err_o)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (D port), §6 (eth_axi master) ·
//              ethereal-spec/control/eth-axi-v0.md §2 (VALID/READY rules 1-2), §9 (DRAM socket) ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       iverilog-compatible (flat ports, two-segment FSM, no procedural
//              loops). v0 addresses the DRAM window with the low AXI_AW bits of
//              the core's 64-bit address (the socket window is 0x8000_0000 +
//              1 MiB today).
module eth_rv_axi_master #(
    parameter int AXI_AW  = 32,                       // AXI4 address width
    parameter int AXI_DW  = 64,                       // AXI4 data width (== the core's beat)
    parameter int AXI_IDW = 4,                        // AXI4 transaction ID width
    parameter int LINE_BEATS = 1,                     // read line fill: 1 = single beat
    parameter logic [AXI_AW-1:0] MEM_BASE  = 32'h8000_0000,  // socket window (ASSUMPTION, today's map)
    parameter int MEM_BYTES = 1 << 20,                // socket window size
    parameter logic [AXI_IDW-1:0] AXI_ID = '0         // constant ID (one outstanding transaction)
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // ---- core D port (beat contract; see eth_rv_core) ----
    input  logic                    dmem_req_i,
    input  logic                    dmem_we_i,
    input  logic [63:0]             dmem_addr_i,
    input  logic [63:0]             dmem_wdata_i,
    input  logic [7:0]              dmem_wstrb_i,
    output logic                    dmem_ready_o,
    output logic [63:0]             dmem_rdata_o,
    output logic                    dmem_err_o,     // with dmem_ready_o: access fault

    // ---- AXI4 master (to eth_dram_ctrl / the eth_axi fabric) ----
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
    input  logic [AXI_IDW-1:0]      m_axi_rid,

    // ---- observability ----
    output logic                    axi_err_o       // sticky: non-OKAY response / bad ID
);

    // ------------------------------------------------------------------
    // Parameters and encodings
    // ------------------------------------------------------------------
    localparam int LINE_BYTES = LINE_BEATS * 8;
    localparam logic [63:0] LINE_MASK = ~(64'(LINE_BYTES) - 64'd1);
    localparam int LINE_IDX_W = (LINE_BEATS > 1) ? $clog2(LINE_BEATS) : 1;

    localparam logic [1:0] BURST_INCR = 2'b01;
    localparam logic [2:0] SIZE_C     = 3'($clog2(AXI_DW / 8));

    typedef enum logic [2:0] {
        E_IDLE = 3'd0,
        E_AR   = 3'd1,
        E_R    = 3'd2,
        E_AW   = 3'd3,
        E_W    = 3'd4,
        E_B    = 3'd5
    } axi_state_e;

    // ------------------------------------------------------------------
    // State + datapath registers
    // ------------------------------------------------------------------
    axi_state_e        state_r, state_nxt;
    logic [AXI_AW-1:0] addr_r,  addr_nxt;   // AXI address of the outstanding transaction
    logic [3:0]        word_r,  word_nxt;   // beat the core asked for inside the read burst
    logic [7:0]        len_r,   len_nxt;    // burst length - 1
    logic [3:0]        beat_r,  beat_nxt;   // beat counter of the read burst
    logic              fill_r,  fill_nxt;   // the read fills (and then caches) a whole line
    logic              served_r, served_nxt;// the core's beat has been handed over
    logic              rd_err_r, rd_err_nxt;// this read burst saw a non-OKAY response
    logic [AXI_DW-1:0] wdata_r, wdata_nxt;  // latched store payload (stable while VALID)
    logic [7:0]        wstrb_r, wstrb_nxt;

    logic [AXI_DW-1:0] line_mem [0:LINE_BEATS-1];
    logic [AXI_AW-1:0] line_base_r;
    logic              line_valid_r;

    logic              line_we;             // update the line registers this edge
    logic              line_valid_d;
    logic [AXI_AW-1:0] line_base_d;

    logic              axi_err_r;

    // ------------------------------------------------------------------
    // Request view of the D port (the beat is the window at addr & ~7)
    // ------------------------------------------------------------------
    logic [AXI_AW-1:0] req_line;        // line-aligned address of the pending request
    logic [AXI_AW-1:0] req_beat;        // 8-byte-aligned beat address of the pending request
    logic [3:0]        req_word;        // the request's word index inside its line
    logic [LINE_IDX_W-1:0] req_line_idx;// req_word truncated to the line-buffer index
    logic [LINE_IDX_W-1:0] beat_idx;    // beat_r truncated to the line-buffer index
    logic              addr_reachable;  // the address fits the socket's AXI_AW window
    logic              line_in_window;  // the whole line is inside the socket's window
    logic              use_burst;       // fill a whole line with one INCR burst
    logic              line_hit;        // the pending load is served from the cached line

    assign req_line     = dmem_addr_i[AXI_AW-1:0] & LINE_MASK[AXI_AW-1:0];
    assign req_beat     = {dmem_addr_i[AXI_AW-1:3], 3'b000};
    assign req_word     = dmem_addr_i[6:3] & 4'(LINE_BEATS - 1);
    assign req_line_idx = req_word[LINE_IDX_W-1:0];
    assign beat_idx     = beat_r[LINE_IDX_W-1:0];

    always_comb begin
        // the socket is addressed by the low AXI_AW bits (today's map is
        // 0x8000_0000 + 1 MiB); a 64-bit address above that window is out of
        // reach and is answered by the slave's DECERR (recorded in axi_err_o)
        addr_reachable = ((dmem_addr_i & ~64'({AXI_AW{1'b1}})) == 64'd0);
        line_in_window = (MEM_BYTES >= LINE_BYTES)
                         && addr_reachable
                         && (req_line >= MEM_BASE)
                         && ((64'(req_line - MEM_BASE) + 64'(LINE_BYTES)) <= 64'(MEM_BYTES));
    end

    assign use_burst = (LINE_BEATS > 1) && line_in_window;
    assign line_hit  = line_valid_r && (req_line == line_base_r);

    // ------------------------------------------------------------------
    // AXI outputs (state-driven; VALID is never withdrawn before its READY)
    // ------------------------------------------------------------------
    assign m_axi_awvalid = (state_r == E_AW);
    assign m_axi_awaddr  = addr_r;
    assign m_axi_awlen   = 8'd0;            // a store is one full-width beat
    assign m_axi_awsize  = SIZE_C;
    assign m_axi_awburst = BURST_INCR;
    assign m_axi_awid    = AXI_ID;

    assign m_axi_wvalid  = (state_r == E_W);
    assign m_axi_wdata   = wdata_r;
    assign m_axi_wstrb   = wstrb_r;
    assign m_axi_wlast   = 1'b1;

    assign m_axi_bready  = (state_r == E_B);

    assign m_axi_arvalid = (state_r == E_AR);
    assign m_axi_araddr  = addr_r;
    assign m_axi_arlen   = len_r;
    assign m_axi_arsize  = SIZE_C;
    assign m_axi_arburst = BURST_INCR;
    assign m_axi_arid    = AXI_ID;

    assign m_axi_rready  = (state_r == E_R);

    // ------------------------------------------------------------------
    // Core-side handshake
    // ------------------------------------------------------------------
    // The read beat the core asked for; the RLAST fallback covers a slave that
    // ends an erroring burst early, so the beat is always handed over once.
    logic r_beat_here;
    logic b_beat_here;
    logic unreachable_beat;

    assign r_beat_here = (state_r == E_R) && m_axi_rvalid
                         && ((beat_r == word_r) || (m_axi_rlast && !served_r));
    assign b_beat_here = (state_r == E_B) && m_axi_bvalid;

    // An address the AXI window cannot even carry is answered here and now, with
    // an error response and WITHOUT starting a transaction: the alternative is
    // truncating the address to `AXI_AW` bits, and a 64-bit address whose low
    // bits happen to land inside the socket's window would then quietly succeed —
    // a silent wrong answer, exactly what the error response exists to rule out.
    // The core takes its access fault either way.
    assign unreachable_beat = (state_r == E_IDLE) && dmem_req_i && !addr_reachable;

    assign dmem_ready_o = unreachable_beat || b_beat_here || r_beat_here
                          || ((state_r == E_IDLE) && dmem_req_i && !dmem_we_i && line_hit);
    assign dmem_rdata_o = r_beat_here ? m_axi_rdata
                        : ((state_r == E_IDLE) && line_hit)
                          ? line_mem[req_line_idx]
                          : 64'd0;
    // The error travels WITH the accept, so the core never has to tell "not ready
    // yet" from "failed": a non-OKAY read/write response, or an address outside
    // the AXI window, is an access fault on that beat.
    assign dmem_err_o   = unreachable_beat
                          || (r_beat_here && (m_axi_rresp != 2'b00))
                          || (b_beat_here && (m_axi_bresp != 2'b00));

    // ------------------------------------------------------------------
    // Next-state logic (combinational segment; defaults first)
    // ------------------------------------------------------------------
    always_comb begin
        state_nxt    = state_r;
        addr_nxt     = addr_r;
        word_nxt     = word_r;
        len_nxt      = len_r;
        beat_nxt     = beat_r;
        fill_nxt     = fill_r;
        served_nxt   = served_r;
        wdata_nxt    = wdata_r;
        wstrb_nxt    = wstrb_r;
        rd_err_nxt   = rd_err_r;
        line_we      = 1'b0;
        line_valid_d = line_valid_r;
        line_base_d  = line_base_r;

        case (state_r)
            E_IDLE: begin
                // a cached load is answered combinationally and stays in idle, and
                // so is an address the AXI window cannot carry (answered as an
                // error, see `unreachable_beat`): neither starts a transaction
                if (dmem_req_i && !unreachable_beat && !(!dmem_we_i && line_hit)) begin
                    served_nxt = 1'b0;
                    beat_nxt   = 4'd0;
                    rd_err_nxt = 1'b0;
                    if (dmem_we_i) begin
                        addr_nxt     = req_beat;
                        wdata_nxt    = dmem_wdata_i[AXI_DW-1:0];
                        wstrb_nxt    = dmem_wstrb_i[AXI_DW/8-1:0];
                        len_nxt      = 8'd0;
                        fill_nxt     = 1'b0;
                        // write-through invalidates the cached line
                        line_we      = 1'b1;
                        line_valid_d = 1'b0;
                        state_nxt    = E_AW;
                    end else begin
                        fill_nxt = use_burst;
                        len_nxt  = use_burst ? 8'(LINE_BEATS - 1) : 8'd0;
                        addr_nxt = use_burst ? req_line : req_beat;
                        word_nxt = use_burst ? req_word : 4'd0;
                        // the line buffer is only valid once the fill completed
                        if (use_burst) begin
                            line_we      = 1'b1;
                            line_valid_d = 1'b0;
                        end
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
                if (m_axi_rvalid) begin
                    beat_nxt = beat_r + 4'd1;
                    if (m_axi_rresp != 2'b00) begin
                        rd_err_nxt = 1'b1;
                    end
                    if (beat_r == word_r) begin
                        served_nxt = 1'b1;
                    end
                    if (m_axi_rlast) begin
                        state_nxt = E_IDLE;
                        if (fill_r) begin
                            line_we      = 1'b1;
                            // an erroring burst never validates the line: a
                            // poisoned line buffer would serve wrong bytes
                            // silently to every following sequential load
                            line_valid_d = !rd_err_r && !(m_axi_rresp != 2'b00)
                                           && (m_axi_rid == AXI_ID);
                            line_base_d  = addr_r;
                        end
                    end
                end
            end
            E_AW: begin
                if (m_axi_awready) begin
                    state_nxt = E_W;
                end
            end
            E_W: begin
                if (m_axi_wready) begin
                    state_nxt = E_B;
                end
            end
            E_B: begin
                if (m_axi_bvalid) begin
                    state_nxt = E_IDLE;
                end
            end
            default: begin
                state_nxt = E_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Sequential
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r      <= E_IDLE;
            addr_r       <= {AXI_AW{1'b0}};
            word_r       <= 4'd0;
            len_r        <= 8'd0;
            beat_r       <= 4'd0;
            fill_r       <= 1'b0;
            served_r     <= 1'b0;
            rd_err_r     <= 1'b0;
            wdata_r      <= {AXI_DW{1'b0}};
            wstrb_r      <= 8'd0;
            line_base_r  <= {AXI_AW{1'b0}};
            line_valid_r <= 1'b0;
            axi_err_r    <= 1'b0;
        end else begin
            state_r  <= state_nxt;
            addr_r   <= addr_nxt;
            word_r   <= word_nxt;
            len_r    <= len_nxt;
            beat_r   <= beat_nxt;
            fill_r   <= fill_nxt;
            served_r <= served_nxt;
            rd_err_r <= rd_err_nxt;
            wdata_r  <= wdata_nxt;
            wstrb_r  <= wstrb_nxt;

            if (line_we) begin
                line_valid_r <= line_valid_d;
                line_base_r  <= line_base_d;
            end
            // the arriving beat is parked in the line buffer while it fills
            if ((state_r == E_R) && m_axi_rvalid && fill_r) begin
                line_mem[beat_idx] <= m_axi_rdata;
            end
            // response errors are latched for the testbench / SoC monitor
            if ((state_r == E_R) && m_axi_rvalid
                && ((m_axi_rresp != 2'b00) || (m_axi_rid != AXI_ID))) begin
                axi_err_r <= 1'b1;
            end
            if ((state_r == E_B) && m_axi_bvalid
                && ((m_axi_bresp != 2'b00) || (m_axi_bid != AXI_ID))) begin
                axi_err_r <= 1'b1;
            end
        end
    end

    assign axi_err_o = axi_err_r;

endmodule
`default_nettype wire
