`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      emri_axi_adapter
// Description: AXI4-Lite slave -> EMRI host-port adapter. Puts the EMRI
//              register file (emri_regfile) on the in-house eth_axi fabric as
//              a control-plane peripheral, so the BMC (AXI master via
//              eth_wb2axi) drives EMRI/OCC through the xbar instead of the
//              host directly (ADR-018 BMC integration; emri-v0.md §3 "the SPI
//              slave / BMC bus feeds this port" — this module IS the BMC bus
//              front-end for the AXI path).
// Details:     * Registered boundaries: AW/W/AR are captured by eth_axi_skidbuf
//                (no comb input->output path, eth-axi-v0.md §2 rule 1); AW and
//                W are captured INDEPENDENTLY (AW/W decoupling legal, §3.2).
//              * The EMRI host port is a single shared req/ready channel, so
//                writes and reads SERIALIZE through one engine (write-first
//                when both pend). The BMC bridge is single-outstanding, so no
//                throughput is lost; the input skidbufs make this safe for any
//                AXI master (AR/AW/W simply wait in their skid buffers).
//              * host_req_o is HELD until host_ready_i (the emri host
//                protocol); emri write side effects are idempotent under a
//                stalled request by design (occ_cmd start gated by
//                !occ_start_r, OCC_WDATA push gated by skid state), matching
//                the SPI host's hold-until-ready behavior.
//              * Address map: window of WIN_WORDS 32-bit words at REG_BASE;
//                host_addr_o = word index = (addr - REG_BASE) >> 2. Access
//                outside the window -> SLVERR without touching EMRI.
//              * v0 write strobes: EMRI registers are word registers; only
//                full-word writes (wstrb == all-ones) are accepted, partial
//                strobes -> SLVERR (documented; byte-lane writes to EMRI have
//                no meaning in emri-v0.md §2).
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3 (register map, host port);
//              ethereal-spec/control/eth-axi-v0.md §3 (AXI4-Lite slave side)
// Notes:       iverilog-compatible (flat ports, no SV interfaces). emri_pkg
//              provides the SPI_OP_* op encodings shared with the SPI host
//              front-end.
module emri_axi_adapter #(
    parameter int AXI_AW = 32,             // address width
    parameter int AXI_DW = 32,             // data width (v0 = 32)
    parameter logic [AXI_AW-1:0] REG_BASE = {AXI_AW{1'b0}},  // window base (byte)
    parameter int WIN_WORDS = 64           // window size in words (EMRI v0: 0x31 used)
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,

    // ---- AXI4-Lite slave (from the eth_axi xbar) ----
    // AW
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,
    input  logic [AXI_AW-1:0]     s_axi_awaddr,
    input  logic [2:0]            s_axi_awprot,
    // W
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,
    input  logic [AXI_DW-1:0]     s_axi_wdata,
    input  logic [(AXI_DW/8)-1:0] s_axi_wstrb,
    // B
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,
    output logic [1:0]            s_axi_bresp,
    // AR
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,
    input  logic [AXI_AW-1:0]     s_axi_araddr,
    input  logic [2:0]            s_axi_arprot,
    // R
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,
    output logic [AXI_DW-1:0]     s_axi_rdata,
    output logic [1:0]            s_axi_rresp,

    // ---- EMRI host-port master (to emri_regfile) ----
    output logic                  host_req_o,
    output logic                  host_we_o,
    output logic [1:0]            host_op_o,
    output logic [15:0]           host_addr_o,   // word offset within the EMRI map
    output logic [31:0]           host_wdata_o,
    input  logic [31:0]           host_rdata_i,
    input  logic                  host_ready_i
);
    import emri_pkg::*;

    localparam int STRB_W = AXI_DW / 8;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // ------------------------------------------------------------------
    // Input capture skid buffers (registered boundaries, spec §2 rule 1).
    // ------------------------------------------------------------------
    // AW
    logic              aw_in_ready, aw_v;
    logic [AXI_AW-1:0] aw_addr;
    logic [AXI_AW+2:0] aw_pl_in, aw_pl_out;
    assign aw_pl_in = {s_axi_awaddr, s_axi_awprot};
    eth_axi_skidbuf #(.PW(AXI_AW+3)) u_aw_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_awvalid), .i_ready(s_axi_awready), .i_data(aw_pl_in),
        .o_valid(aw_v), .o_ready(aw_in_ready), .o_data(aw_pl_out)
    );
    assign aw_addr = aw_pl_out[AXI_AW+2:3];

    // W
    logic              w_in_ready, w_v;
    logic [AXI_DW-1:0] w_data;
    logic [STRB_W-1:0] w_strb;
    logic [AXI_DW+STRB_W-1:0] w_pl_in, w_pl_out;
    assign w_pl_in = {s_axi_wdata, s_axi_wstrb};
    eth_axi_skidbuf #(.PW(AXI_DW+STRB_W)) u_w_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_wvalid), .i_ready(s_axi_wready), .i_data(w_pl_in),
        .o_valid(w_v), .o_ready(w_in_ready), .o_data(w_pl_out)
    );
    assign w_data = w_pl_out[AXI_DW+STRB_W-1:STRB_W];
    assign w_strb = w_pl_out[STRB_W-1:0];

    // AR
    logic              ar_in_ready, ar_v;
    logic [AXI_AW-1:0] ar_addr;
    logic [AXI_AW+2:0] ar_pl_in, ar_pl_out;
    assign ar_pl_in = {s_axi_araddr, s_axi_arprot};
    eth_axi_skidbuf #(.PW(AXI_AW+3)) u_ar_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_arvalid), .i_ready(s_axi_arready), .i_data(ar_pl_in),
        .o_valid(ar_v), .o_ready(ar_in_ready), .o_data(ar_pl_out)
    );
    assign ar_addr = ar_pl_out[AXI_AW+2:3];

    // ------------------------------------------------------------------
    // Window decode (functions of the captured, registered addresses).
    // ------------------------------------------------------------------
    function automatic logic in_window(input logic [AXI_AW-1:0] a);
        logic [AXI_AW-1:0] off;
        begin
            off = a - REG_BASE;
            // in-window iff the byte offset into the window is below the
            // window size; the wrap case (a < REG_BASE) makes off huge, so a
            // single bounded comparison covers it (same idiom as lite_slave).
            // verilator lint_off UNSIGNED
            in_window = (off < AXI_AW'(WIN_WORDS * 4));
            // verilator lint_on UNSIGNED
        end
    endfunction
    function automatic logic [15:0] word_index(input logic [AXI_AW-1:0] a);
        // word index = (a - REG_BASE) / 4 (in-window callers only); truncated
        // to 16 bits on assignment (EMRI host_addr_i width).
        word_index = 16'((a - REG_BASE) >> 2);
    endfunction

    // ------------------------------------------------------------------
    // Serialized host engine (write-first). One EMRI host transaction in
    // flight; input skidbufs hold any AXI beats that arrive while busy.
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,    // no host transaction; accept write pair or read
        S_WR_HOST, // host write in flight (host_req held until host_ready)
        S_WR_B,    // push B response
        S_RD_HOST, // host read in flight (host_req held until host_ready)
        S_RD_R     // push R response
    } state_e;

    state_e      state_r, state_nxt;

    // latched request payload
    logic [15:0]      req_addr_r;    // EMRI word offset
    logic [AXI_DW-1:0] req_wdata_r;
    logic [1:0]       req_resp_r;    // response to return (OKAY/SLVERR)
    logic [AXI_DW-1:0] rd_data_r;    // captured read data

    // engine start conditions
    logic wr_pend, rd_pend;
    assign wr_pend = aw_v && w_v;             // write pair captured
    assign rd_pend = ar_v;                    // read captured

    // SLVERR shortcut: a failed window/strb check never reaches the EMRI host
    // port — host_req stays low AND the host phase is skipped in the
    // next-state logic below (emri only asserts host_ready while host_req is
    // high, so waiting for host_ready with host_req low would deadlock).
    // Declared before the FSM: iverilog requires declaration before use.
    logic host_run;
    assign host_run = (req_resp_r == RESP_OKAY);

    // consume the input skidbufs exactly when the engine takes the request
    assign aw_in_ready = (state_r == S_IDLE) && wr_pend;
    assign w_in_ready  = (state_r == S_IDLE) && wr_pend;
    assign ar_in_ready = (state_r == S_IDLE) && !wr_pend && rd_pend;

    // ------------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------------
    logic b_fire, r_fire;
    assign b_fire = s_axi_bvalid && s_axi_bready;
    assign r_fire = s_axi_rvalid && s_axi_rready;

    always_comb begin
        state_nxt = state_r;
        case (state_r)
            S_IDLE: begin
                if (wr_pend)      state_nxt = S_WR_HOST;
                else if (rd_pend) state_nxt = S_RD_HOST;
            end
            S_WR_HOST: if (!host_run || host_ready_i) state_nxt = S_WR_B;
            S_WR_B:    if (b_fire)       state_nxt = S_IDLE;
            S_RD_HOST: if (!host_run || host_ready_i) state_nxt = S_RD_R;
            S_RD_R:    if (r_fire)       state_nxt = S_IDLE;
            default:   state_nxt = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // Sequential: state + request/response latches.
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r     <= S_IDLE;
            req_addr_r  <= 16'h0;
            req_wdata_r <= {AXI_DW{1'b0}};
            req_resp_r  <= RESP_OKAY;
            rd_data_r   <= {AXI_DW{1'b0}};
        end else begin
            state_r <= state_nxt;
            case (state_r)
                S_IDLE: begin
                    if (wr_pend) begin
                        req_addr_r  <= word_index(aw_addr);
                        req_wdata_r <= w_data;
                        // SLVERR (no EMRI access) when out-of-window or a
                        // partial-strobe write; else OKAY and the host runs.
                        req_resp_r  <= (in_window(aw_addr) && (w_strb == {STRB_W{1'b1}}))
                                       ? RESP_OKAY : RESP_SLVERR;
                    end else if (rd_pend) begin
                        req_addr_r  <= word_index(ar_addr);
                        req_resp_r  <= in_window(ar_addr) ? RESP_OKAY : RESP_SLVERR;
                    end
                end
                S_RD_HOST: begin
                    if (host_run && host_ready_i) rd_data_r <= host_rdata_i;
                end
                default: ;  // S_WR_HOST / S_WR_B / S_RD_R: hold latches
            endcase
        end
    end

    // ------------------------------------------------------------------
    // EMRI host-port drive (held until host_ready_i).
    // ------------------------------------------------------------------
    always_comb begin
        host_req_o   = 1'b0;
        host_we_o    = 1'b0;
        host_op_o    = SPI_OP_RD;
        host_addr_o  = req_addr_r;
        host_wdata_o = req_wdata_r;
        case (state_r)
            S_WR_HOST: begin
                host_req_o = host_run;
                host_we_o  = 1'b1;
                host_op_o  = SPI_OP_WR;
            end
            S_RD_HOST: begin
                host_req_o = host_run;
                host_we_o  = 1'b0;
                host_op_o  = SPI_OP_RD;
            end
            default: ;
        endcase
    end

    // ------------------------------------------------------------------
    // Response channels (registered via output-side hold; responses are
    // single-outstanding so a direct register stage suffices — the engine
    // cannot start a new transaction until the response handshakes).
    // ------------------------------------------------------------------
    assign s_axi_bvalid = (state_r == S_WR_B);
    assign s_axi_bresp  = req_resp_r;
    assign s_axi_rvalid = (state_r == S_RD_R);
    assign s_axi_rdata  = rd_data_r;
    assign s_axi_rresp  = req_resp_r;

    // aw/ar skidbufs carry a prot field we do not interpret in v0 (the EMRI
    // host port has no protection concept). Fold the unused bits into a single
    // reduction sink so -Wall stays clean (same idiom as eth_axi_lite_slave).
    // verilator lint_off UNUSEDSIGNAL
    logic unused_ok;
    assign unused_ok = &{1'b0, aw_pl_out[2:0], ar_pl_out[2:0]};
    // verilator lint_on UNUSEDSIGNAL

endmodule
`default_nettype wire
