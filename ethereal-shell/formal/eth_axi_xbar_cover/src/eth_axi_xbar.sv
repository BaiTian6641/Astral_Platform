`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_axi_xbar
// Description: AXI4 crossbar — N_MST masters x N_SLV slaves (the data/control
//              plane fabric), per ethereal-spec/control/eth-axi-v0.md §5.
// Details:     Routes AXI4 transactions from N masters to M slaves by address.
//
//              * ADDRESS DECODE: per-slave {base,mask} pairs packed into the flat
//                ADDR_MAP param (base_s at [s*AW +: AW], mask_s at
//                [(N_SLV+s)*AW +: AW]). A beat routes to slave s when
//                (addr & mask_s) == (base_s & mask_s). Unmapped -> the built-in
//                DECODE-ERROR slave (§5.3, DECERR, never hangs).
//              * ID ROUTING (§5.1): the crossbar prepends the master index into
//                the transaction ID, xid = {mst_idx, orig_id} (XIDW = IDW+MIW).
//                Slaves see the widened ID; B/R responses route back by the
//                recorded owner (the xid-prefix master), stripped on return.
//              * ARBITRATION: per-destination round-robin among the masters that
//                target it (§5.1); a central arbiter per destination grants one
//                master's whole transaction. Write (AW+W+B) and read (AR+R)
//                arbitrate independently.
//              * DEADLOCK-FREEDOM: every boundary is a registered eth_axi_skidbuf
//                (no comb input->output path, §2 rule 1); a stalled response is
//                buffered, never back-pressuring a channel combinationally.
//
//              v0 MODEL (lock-step, single-outstanding per master per direction):
//              a master may have at most ONE write and ONE read in flight. Its
//              granted transaction runs AW -> W -> B (resp. AR -> R) to
//              completion before the next is accepted. This keeps W and response
//              routing trivially correct while the ID-prepend/route-back and the
//              address decode are written burst-/outstanding-agnostic, so v0.1
//              adds bursts + multiple-outstanding WITHOUT restructuring (Notes).
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §5 (crossbar), §2 (rules),
//              §7 (props 3-5); docs/adr/ADR-018-axi-noc-riscv-cluster.md §2
// Notes:       v0-vs-v0.1 boundary: v0 = single-beat (AxLEN=0) + one outstanding
//              transaction per master per direction (lock-step AW->W->B, AR->R).
//              v0.1 = INCR/WRAP bursts (per-channel beat counters), ATOP atomics,
//              and multiple-outstanding (an outstanding-ID table) — the ID
//              routing + decode already carry the widened xid end-to-end, so only
//              the beat counters and the ID table are added, not a redesign.
//              iverilog-compatible: NO SV interface/modport, flat ports, flat
//              (non-packed-2D) ADDR_MAP, NO `automatic` vars (iverilog 14 rejects
//              them in always_comb — all decode/arb is generate-time or plain
//              wires). Masters/slaves are flattened N_MST*/N_SLV* buses.
//              ASSUMPTION (TBD 2026-07-30): v0 slaves return a granted
//              transaction's response before the next grant on that destination
//              (true for eth_axi_lite_slave / the error slave), so route-back
//              needs no reorder buffer (AXI4 forbids read-data interleave across
//              IDs, §5.2, and single-outstanding per master makes same-ID order
//              trivial).
module eth_axi_xbar #(
    parameter int N_MST = 2,               // number of masters
    parameter int N_SLV = 3,               // number of slaves (excl. error slave)
    parameter int AXI_AW = 32,             // address width
    parameter int AXI_DW = 32,             // data width
    parameter int AXI_IDW = 4,             // master-side (orig) ID width
    // widened slave-side ID width = AXI_IDW + master-index width. A parameter
    // (not a post-ports localparam) because iverilog requires it for port dims.
    parameter int AXI_XIDW = AXI_IDW + ((N_MST > 1) ? $clog2(N_MST) : 1),
    // flat ADDR_MAP: base_s at [s*AW +: AW], mask_s at [(N_SLV+s)*AW +: AW]
    parameter logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {(2*N_SLV*AXI_AW){1'b0}}
) (
    input  logic clk_i,
    input  logic rst_ni,

    // ===================== master-side slave ports (flattened) =============
    input  logic [N_MST-1:0]                 s_awvalid,
    output logic [N_MST-1:0]                 s_awready,
    input  logic [N_MST*AXI_AW-1:0]          s_awaddr,
    input  logic [N_MST*AXI_IDW-1:0]         s_awid,
    input  logic [N_MST-1:0]                 s_wvalid,
    output logic [N_MST-1:0]                 s_wready,
    input  logic [N_MST*AXI_DW-1:0]          s_wdata,
    input  logic [N_MST*(AXI_DW/8)-1:0]      s_wstrb,
    output logic [N_MST-1:0]                 s_bvalid,
    input  logic [N_MST-1:0]                 s_bready,
    output logic [N_MST*AXI_IDW-1:0]         s_bid,
    output logic [N_MST*2-1:0]               s_bresp,
    input  logic [N_MST-1:0]                 s_arvalid,
    output logic [N_MST-1:0]                 s_arready,
    input  logic [N_MST*AXI_AW-1:0]          s_araddr,
    input  logic [N_MST*AXI_IDW-1:0]         s_arid,
    output logic [N_MST-1:0]                 s_rvalid,
    input  logic [N_MST-1:0]                 s_rready,
    output logic [N_MST*AXI_IDW-1:0]         s_rid,
    output logic [N_MST*AXI_DW-1:0]          s_rdata,
    output logic [N_MST*2-1:0]               s_rresp,

    // ===================== slave-side master ports (flattened) =============
    output logic [N_SLV-1:0]                 m_awvalid,
    input  logic [N_SLV-1:0]                 m_awready,
    output logic [N_SLV*AXI_AW-1:0]          m_awaddr,
    output logic [N_SLV*AXI_XIDW-1:0]        m_awid,
    output logic [N_SLV-1:0]                 m_wvalid,
    input  logic [N_SLV-1:0]                 m_wready,
    output logic [N_SLV*AXI_DW-1:0]          m_wdata,
    output logic [N_SLV*(AXI_DW/8)-1:0]      m_wstrb,
    input  logic [N_SLV-1:0]                 m_bvalid,
    output logic [N_SLV-1:0]                 m_bready,
    input  logic [N_SLV*AXI_XIDW-1:0]        m_bid,
    input  logic [N_SLV*2-1:0]               m_bresp,
    output logic [N_SLV-1:0]                 m_arvalid,
    input  logic [N_SLV-1:0]                 m_arready,
    output logic [N_SLV*AXI_AW-1:0]          m_araddr,
    output logic [N_SLV*AXI_XIDW-1:0]        m_arid,
    input  logic [N_SLV-1:0]                 m_rvalid,
    output logic [N_SLV-1:0]                 m_rready,
    input  logic [N_SLV*AXI_XIDW-1:0]        m_rid,
    input  logic [N_SLV*AXI_DW-1:0]          m_rdata,
    input  logic [N_SLV*2-1:0]               m_rresp
);

    localparam int MIW      = (N_MST > 1) ? $clog2(N_MST) : 1;
    localparam int SIW      = (N_SLV > 1) ? $clog2(N_SLV) : 1;
    localparam int STRB_W   = AXI_DW / 8;
    localparam int N_DST    = N_SLV + 1;               // + decode-error slave
    localparam int ERR      = N_SLV;                   // error-slave index
    localparam logic [1:0] RESP_DECERR = 2'b11;

    // ======================================================================
    // Master-port capture skid buffers (registered boundaries, §2 rule 1).
    // ======================================================================
    logic [N_MST-1:0]           aw_v,   aw_pop;
    logic [N_MST*AXI_AW-1:0]    aw_addr;
    logic [N_MST*AXI_IDW-1:0]   aw_id;
    logic [N_MST-1:0]           w_v,    w_pop;
    logic [N_MST*AXI_DW-1:0]    w_data;
    logic [N_MST*STRB_W-1:0]    w_strb;
    logic [N_MST-1:0]           ar_v,   ar_pop;
    logic [N_MST*AXI_AW-1:0]    ar_addr;
    logic [N_MST*AXI_IDW-1:0]   ar_id;

    genvar m;
    generate
    for (m = 0; m < N_MST; m++) begin : g_cap
        localparam int AWPW = AXI_AW + AXI_IDW;
        localparam int WPW  = AXI_DW + STRB_W;
        localparam int ARPW = AXI_AW + AXI_IDW;
        logic [AWPW-1:0] aw_in, aw_out;
        logic [WPW-1:0]  w_in,  w_out;
        logic [ARPW-1:0] ar_in, ar_out;
        assign aw_in = {s_awaddr[m*AXI_AW +: AXI_AW], s_awid[m*AXI_IDW +: AXI_IDW]};
        eth_axi_skidbuf #(.PW(AWPW)) u_aw (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(s_awvalid[m]), .i_ready(s_awready[m]), .i_data(aw_in),
            .o_valid(aw_v[m]), .o_ready(aw_pop[m]), .o_data(aw_out));
        assign aw_addr[m*AXI_AW +: AXI_AW] = aw_out[AWPW-1 -: AXI_AW];
        assign aw_id[m*AXI_IDW +: AXI_IDW] = aw_out[AXI_IDW-1:0];
        assign w_in = {s_wdata[m*AXI_DW +: AXI_DW], s_wstrb[m*STRB_W +: STRB_W]};
        eth_axi_skidbuf #(.PW(WPW)) u_w (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(s_wvalid[m]), .i_ready(s_wready[m]), .i_data(w_in),
            .o_valid(w_v[m]), .o_ready(w_pop[m]), .o_data(w_out));
        assign w_data[m*AXI_DW +: AXI_DW] = w_out[WPW-1 -: AXI_DW];
        assign w_strb[m*STRB_W +: STRB_W] = w_out[STRB_W-1:0];
        assign ar_in = {s_araddr[m*AXI_AW +: AXI_AW], s_arid[m*AXI_IDW +: AXI_IDW]};
        eth_axi_skidbuf #(.PW(ARPW)) u_ar (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(s_arvalid[m]), .i_ready(s_arready[m]), .i_data(ar_in),
            .o_valid(ar_v[m]), .o_ready(ar_pop[m]), .o_data(ar_out));
        assign ar_addr[m*AXI_AW +: AXI_AW] = ar_out[ARPW-1 -: AXI_AW];
        assign ar_id[m*AXI_IDW +: AXI_IDW] = ar_out[AXI_IDW-1:0];
    end
    endgenerate

    // ======================================================================
    // Address decode (iverilog-safe function, no `automatic`).
    // ======================================================================
    function automatic logic [SIW:0] decode(input logic [AXI_AW-1:0] a);
        logic [AXI_AW-1:0] base_s, mask_s;
        logic              found;
        integer s;
        begin
            decode = ERR[SIW:0];
            found  = 1'b0;
            for (s = 0; s < N_SLV; s++) begin
                base_s = ADDR_MAP[s*AXI_AW +: AXI_AW];
                mask_s = ADDR_MAP[(N_SLV+s)*AXI_AW +: AXI_AW];
                if (!found && ((a & mask_s) == (base_s & mask_s))) begin
                    decode = s[SIW:0];
                    found  = 1'b1;
                end
            end
        end
    endfunction

    logic [N_MST*(SIW+1)-1:0] aw_dest, ar_dest;
    generate
    for (m = 0; m < N_MST; m++) begin : g_dec
        assign aw_dest[m*(SIW+1) +: (SIW+1)] = decode(aw_addr[m*AXI_AW +: AXI_AW]);
        assign ar_dest[m*(SIW+1) +: (SIW+1)] = decode(ar_addr[m*AXI_AW +: AXI_AW]);
    end
    endgenerate

    // ======================================================================
    // Per-master transaction state (lock-step, single-outstanding).
    // ======================================================================
    // write: 0=IDLE(need AW) 1=WDATA 2=WAITB ; read: 0=IDLE(need AR) 1=WAITR
    logic [N_MST*2-1:0]        wr_state;
    logic [N_MST-1:0]          rd_state;
    logic [N_MST*(SIW+1)-1:0]  wr_dest, rd_dest;

    // ======================================================================
    // Central per-destination arbiters (round-robin), write + read.
    // ======================================================================
    // Request matrix as a flat vector: wr_req_flat[di*N_MST+mi] = master mi
    // (IDLE, has AW) targets dest di. Built with generate (constant indices).
    logic [N_DST*N_MST-1:0] wr_req_flat, rd_req_flat;
    logic [N_DST*MIW-1:0]   wr_ptr, rd_ptr;
    logic [N_DST-1:0]       wr_gnt_v, rd_gnt_v;
    logic [N_DST*MIW-1:0]   wr_gnt_m, rd_gnt_m;

    // ------------------------------------------------------------------
    // Per-destination lock-step enforcement (v0 model, §5.1: "a granted
    // transaction runs AW->W->B (resp. AR->R) to completion before the next
    // is accepted"). wr_busy/rd_busy[d] are set when a transaction to
    // destination d is ISSUED and cleared when its B (resp. R) beat is
    // captured; while busy, no new request to d is eligible for a grant.
    // This makes the W/B/R owner scans below provably one-hot: without it,
    // two masters with same-destination transactions in the same phase
    // alias in the OR-merge and responses route to the WRONG master
    // (E1-RUN3: host's EFP_STATUS poll received the BMC's IMG_DIGEST read
    // data in tb_ethctl_replay; regression: tb_axi_xbar cross-master test).
    // ------------------------------------------------------------------
    logic [N_DST-1:0] wr_busy, rd_busy;

    genvar gmi, gdi;
    generate
    for (gmi = 0; gmi < N_MST; gmi++) begin : g_req_m
        for (gdi = 0; gdi < N_DST; gdi++) begin : g_req_d
            assign wr_req_flat[gdi*N_MST+gmi] =
                aw_v[gmi] && (wr_state[gmi*2 +: 2] == 2'd0) &&
                !wr_busy[gdi] &&
                (aw_dest[gmi*(SIW+1) +: (SIW+1)] == gdi[SIW:0]);
            assign rd_req_flat[gdi*N_MST+gmi] =
                ar_v[gmi] && (rd_state[gmi] == 1'b0) &&
                !rd_busy[gdi] &&
                (ar_dest[gmi*(SIW+1) +: (SIW+1)] == gdi[SIW:0]);
        end
    end
    endgenerate

    // Round-robin grant helper: returns {valid, grant_idx} = the first set bit of
    // `req` at/after `ptr`, wrapping. A plain function (locals may be automatic;
    // iverilog accepts those) keeps the always blocks free of `automatic` decls.
    function automatic logic [MIW:0] rr_grant(input logic [N_MST-1:0] req,
                                              input logic [MIW-1:0]  ptr);
        logic [MIW-1:0] cand;
        logic           found;
        integer         k;
        begin
            rr_grant = {1'b0, {MIW{1'b0}}};
            found    = 1'b0;
            for (k = 0; k < N_MST; k++) begin
                cand = MIW'((ptr + k) % N_MST);
                if (!found && req[cand]) begin
                    found    = 1'b1;
                    rr_grant = {1'b1, cand};
                end
            end
        end
    endfunction

    generate
    for (gdi = 0; gdi < N_DST; gdi++) begin : g_arb
        logic [MIW:0] wg, rg;
        assign wg = rr_grant(wr_req_flat[gdi*N_MST +: N_MST], wr_ptr[gdi*MIW +: MIW]);
        assign rg = rr_grant(rd_req_flat[gdi*N_MST +: N_MST], rd_ptr[gdi*MIW +: MIW]);
        assign wr_gnt_v[gdi]            = wg[MIW];
        assign wr_gnt_m[gdi*MIW +: MIW] = wg[MIW-1:0];
        assign rd_gnt_v[gdi]            = rg[MIW];
        assign rd_gnt_m[gdi*MIW +: MIW] = rg[MIW-1:0];
    end
    endgenerate

    // ======================================================================
    // Slave-side AW/AR/W input skids + issue signals.
    // ======================================================================
    logic [N_SLV-1:0] aw_skid_iready, ar_skid_iready, w_skid_iready;
    logic             err_aw_ready, err_ar_ready, err_w_ready;
    logic [N_DST-1:0] aw_issue, ar_issue;

    genvar d;
    generate
    for (d = 0; d < N_SLV; d++) begin : g_slv_in
        localparam int AWPW = AXI_AW + AXI_XIDW;
        localparam int ARPW = AXI_AW + AXI_XIDW;
        localparam int WPW  = AXI_DW + STRB_W;
        logic [AWPW-1:0] awpl_in, awpl_out;
        logic [ARPW-1:0] arpl_in, arpl_out;
        logic [WPW-1:0]  wpl_in,  wpl_out;
        logic [MIW-1:0]  gm, rgm;
        // ---- AW ----
        assign gm      = wr_gnt_m[d];
        assign awpl_in = {aw_addr[gm*AXI_AW +: AXI_AW],
                          gm, aw_id[gm*AXI_IDW +: AXI_IDW]};
        assign aw_issue[d] = wr_gnt_v[d] && aw_skid_iready[d];
        eth_axi_skidbuf #(.PW(AWPW)) u_aw (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(wr_gnt_v[d] && (aw_dest[gm*(SIW+1) +: (SIW+1)] == d[SIW:0])),
            .i_ready(aw_skid_iready[d]), .i_data(awpl_in),
            .o_valid(m_awvalid[d]), .o_ready(m_awready[d]), .o_data(awpl_out));
        assign m_awaddr[d*AXI_AW +: AXI_AW]   = awpl_out[AWPW-1 -: AXI_AW];
        assign m_awid[d*AXI_XIDW +: AXI_XIDW] = awpl_out[AXI_XIDW-1:0];
        // ---- AR ----
        assign rgm     = rd_gnt_m[d];
        assign arpl_in = {ar_addr[rgm*AXI_AW +: AXI_AW],
                          rgm, ar_id[rgm*AXI_IDW +: AXI_IDW]};
        assign ar_issue[d] = rd_gnt_v[d] && ar_skid_iready[d];
        eth_axi_skidbuf #(.PW(ARPW)) u_ar (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(rd_gnt_v[d] && (ar_dest[rgm*(SIW+1) +: (SIW+1)] == d[SIW:0])),
            .i_ready(ar_skid_iready[d]), .i_data(arpl_in),
            .o_valid(m_arvalid[d]), .o_ready(m_arready[d]), .o_data(arpl_out));
        assign m_araddr[d*AXI_AW +: AXI_AW]   = arpl_out[ARPW-1 -: AXI_AW];
        assign m_arid[d*AXI_XIDW +: AXI_XIDW] = arpl_out[AXI_XIDW-1:0];
        // ---- W (driven by the master in WDATA whose dest==d) ----
        logic [N_MST-1:0] wsel;
        logic [MIW-1:0]   wsel_m;
        logic             wv;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_wsel
            assign wsel[mm] = (wr_state[mm*2 +: 2] == 2'd1) &&
                              (wr_dest[mm*(SIW+1) +: (SIW+1)] == d[SIW:0]);
        end
        // one-hot -> index by OR of constant-index terms (iverilog-safe reduce;
        // at most one master is in WDATA for a given dest, so no aliasing).
        logic [N_MST*MIW-1:0] wsel_terms;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_wsel_enc
            assign wsel_terms[mm*MIW +: MIW] = wsel[mm] ? mm[MIW-1:0] : {MIW{1'b0}};
        end
        always_comb begin
            wsel_m = {MIW{1'b0}};
            for (int q = 0; q < N_MST; q++) wsel_m = wsel_m | wsel_terms[q*MIW +: MIW];
        end
        assign wv     = (|wsel) && w_v[wsel_m];
        assign wpl_in = {w_data[wsel_m*AXI_DW +: AXI_DW],
                         w_strb[wsel_m*STRB_W +: STRB_W]};
        eth_axi_skidbuf #(.PW(WPW)) u_w (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(wv), .i_ready(w_skid_iready[d]), .i_data(wpl_in),
            .o_valid(m_wvalid[d]), .o_ready(m_wready[d]), .o_data(wpl_out));
        assign m_wdata[d*AXI_DW +: AXI_DW] = wpl_out[WPW-1 -: AXI_DW];
        assign m_wstrb[d*STRB_W +: STRB_W] = wpl_out[STRB_W-1:0];
    end
    endgenerate

    // error-slave AW/AR issue (its FSM ready flags; see the error slave below)
    assign aw_issue[ERR] = wr_gnt_v[ERR] && err_aw_ready;
    assign ar_issue[ERR] = rd_gnt_v[ERR] && err_ar_ready;

    // ======================================================================
    // Pop: a granted master's AW/AR/W capture skid pops when its dest accepts.
    // ======================================================================
    genvar pm2;
    generate
    for (pm2 = 0; pm2 < N_MST; pm2++) begin : g_pop
        logic [SIW:0] awd, ard, wrd;
        assign awd = aw_dest[pm2*(SIW+1) +: (SIW+1)];
        assign ard = ar_dest[pm2*(SIW+1) +: (SIW+1)];
        assign wrd = wr_dest[pm2*(SIW+1) +: (SIW+1)];
        assign aw_pop[pm2] = (wr_state[pm2*2 +: 2] == 2'd0) &&
                             aw_issue[awd] && (wr_gnt_m[awd] == pm2[MIW-1:0]);
        assign ar_pop[pm2] = (rd_state[pm2] == 1'b0) &&
                             ar_issue[ard] && (rd_gnt_m[ard] == pm2[MIW-1:0]);
        assign w_pop[pm2]  = (wr_state[pm2*2 +: 2] == 2'd1) && w_v[pm2] &&
            ((wrd == ERR[SIW:0]) ? err_w_ready : w_skid_iready[wrd]);
    end
    endgenerate

    // ======================================================================
    // B / R route-back. Owner of a destination's in-flight transaction is found
    // by scanning per-master state; responses captured per-master (skid-safe).
    // ======================================================================
    logic [N_MST-1:0]          b_in_rdy, r_in_rdy;
    logic [N_SLV-1:0]          b_slave_push, r_slave_push;
    logic [N_SLV*MIW-1:0]      b_slave_owner, r_slave_owner;
    logic                      err_b_push, err_r_push;
    logic [MIW-1:0]            err_b_owner, err_r_owner;
    logic [AXI_IDW-1:0]        err_b_id, err_r_id;

    genvar bd;
    generate
    for (bd = 0; bd < N_SLV; bd++) begin : g_b_route
        logic [N_MST-1:0] bsel;
        logic [MIW-1:0]   bm;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_bsel
            assign bsel[mm] = (wr_state[mm*2 +: 2] == 2'd2) &&
                              (wr_dest[mm*(SIW+1) +: (SIW+1)] == bd[SIW:0]);
        end
        logic [N_MST*MIW-1:0] bsel_terms;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_bsel_enc
            assign bsel_terms[mm*MIW +: MIW] = bsel[mm] ? mm[MIW-1:0] : {MIW{1'b0}};
        end
        always_comb begin
            bm = {MIW{1'b0}};
            for (int q = 0; q < N_MST; q++) bm = bm | bsel_terms[q*MIW +: MIW];
        end
        assign m_bready[bd]              = (|bsel) && b_in_rdy[bm];
        assign b_slave_push[bd]          = m_bvalid[bd] && (|bsel) && b_in_rdy[bm];
        assign b_slave_owner[bd*MIW +: MIW] = bm;
    end
    endgenerate

    genvar rd2;
    generate
    for (rd2 = 0; rd2 < N_SLV; rd2++) begin : g_r_route
        logic [N_MST-1:0] rsel;
        logic [MIW-1:0]   rm;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_rsel
            assign rsel[mm] = (rd_state[mm] == 1'b1) &&
                              (rd_dest[mm*(SIW+1) +: (SIW+1)] == rd2[SIW:0]);
        end
        logic [N_MST*MIW-1:0] rsel_terms;
        for (genvar mm = 0; mm < N_MST; mm++) begin : g_rsel_enc
            assign rsel_terms[mm*MIW +: MIW] = rsel[mm] ? mm[MIW-1:0] : {MIW{1'b0}};
        end
        always_comb begin
            rm = {MIW{1'b0}};
            for (int q = 0; q < N_MST; q++) rm = rm | rsel_terms[q*MIW +: MIW];
        end
        assign m_rready[rd2]              = (|rsel) && r_in_rdy[rm];
        assign r_slave_push[rd2]          = m_rvalid[rd2] && (|rsel) && r_in_rdy[rm];
        assign r_slave_owner[rd2*MIW +: MIW] = rm;
    end
    endgenerate

    // ------------------------------------------------------------------
    // Lock-step busy tracking: set at issue, cleared when the response beat
    // is captured into the owner's per-master skid (transaction complete as
    // far as the destination is concerned).
    // ------------------------------------------------------------------
    integer bi;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_busy <= {N_DST{1'b0}};
            rd_busy <= {N_DST{1'b0}};
        end else begin
            for (bi = 0; bi < N_SLV; bi++) begin
                if (aw_issue[bi])      wr_busy[bi] <= 1'b1;
                else if (b_slave_push[bi]) wr_busy[bi] <= 1'b0;
                if (ar_issue[bi])      rd_busy[bi] <= 1'b1;
                else if (r_slave_push[bi]) rd_busy[bi] <= 1'b0;
            end
            if (aw_issue[ERR])      wr_busy[ERR] <= 1'b1;
            else if (err_b_push)    wr_busy[ERR] <= 1'b0;
            if (ar_issue[ERR])      rd_busy[ERR] <= 1'b1;
            else if (err_r_push)    rd_busy[ERR] <= 1'b0;
        end
    end

    // per-master B/R input mux + capture skid (single outstanding => one source)
    genvar pm;
    generate
    for (pm = 0; pm < N_MST; pm++) begin : g_resp
        logic               bv, rv;
        logic [AXI_IDW-1:0] bid, rid;
        logic [1:0]         bresp, rresp;
        logic [AXI_DW-1:0]  rdata;
        integer q;
        always_comb begin
            bv    = 1'b0;
            bid   = {AXI_IDW{1'b0}};
            bresp = 2'b00;
            for (q = 0; q < N_SLV; q++)
                if (b_slave_push[q] && b_slave_owner[q*MIW +: MIW] == pm[MIW-1:0]) begin
                    bv    = 1'b1;
                    bid   = m_bid[q*AXI_XIDW +: AXI_IDW];        // strip prefix
                    bresp = m_bresp[q*2 +: 2];
                end
            if (err_b_push && err_b_owner == pm[MIW-1:0]) begin
                bv = 1'b1; bid = err_b_id; bresp = RESP_DECERR;
            end
        end
        eth_axi_skidbuf #(.PW(AXI_IDW+2)) u_b (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(bv), .i_ready(b_in_rdy[pm]), .i_data({bid, bresp}),
            .o_valid(s_bvalid[pm]), .o_ready(s_bready[pm]),
            .o_data({s_bid[pm*AXI_IDW +: AXI_IDW], s_bresp[pm*2 +: 2]}));
        always_comb begin
            rv    = 1'b0;
            rid   = {AXI_IDW{1'b0}};
            rdata = {AXI_DW{1'b0}};
            rresp = 2'b00;
            for (q = 0; q < N_SLV; q++)
                if (r_slave_push[q] && r_slave_owner[q*MIW +: MIW] == pm[MIW-1:0]) begin
                    rv    = 1'b1;
                    rid   = m_rid[q*AXI_XIDW +: AXI_IDW];        // strip prefix
                    rdata = m_rdata[q*AXI_DW +: AXI_DW];
                    rresp = m_rresp[q*2 +: 2];
                end
            if (err_r_push && err_r_owner == pm[MIW-1:0]) begin
                rv = 1'b1; rid = err_r_id; rdata = {AXI_DW{1'b0}}; rresp = RESP_DECERR;
            end
        end
        eth_axi_skidbuf #(.PW(AXI_IDW+AXI_DW+2)) u_r (
            .clk_i(clk_i), .rst_ni(rst_ni),
            .i_valid(rv), .i_ready(r_in_rdy[pm]), .i_data({rid, rdata, rresp}),
            .o_valid(s_rvalid[pm]), .o_ready(s_rready[pm]),
            .o_data({s_rid[pm*AXI_IDW +: AXI_IDW], s_rdata[pm*AXI_DW +: AXI_DW],
                    s_rresp[pm*2 +: 2]}));
    end
    endgenerate

    // ======================================================================
    // Built-in DECODE-ERROR slave (§5.3): unmapped access -> DECERR, never hang.
    // ======================================================================
    typedef enum logic [1:0] {EW_AW, EW_W, EW_B} ew_e;
    typedef enum logic [0:0] {ER_AR, ER_R}       er_e;
    ew_e                 ew_state;
    er_e                 er_state;
    logic [AXI_XIDW-1:0] ew_xid, er_xid;

    assign err_aw_ready = (ew_state == EW_AW);
    assign err_ar_ready = (er_state == ER_AR);
    assign err_w_ready  = (ew_state == EW_W);
    assign err_b_push   = (ew_state == EW_B) && b_in_rdy[ew_xid[AXI_XIDW-1 -: MIW]];
    assign err_b_owner  = ew_xid[AXI_XIDW-1 -: MIW];
    assign err_b_id     = ew_xid[0 +: AXI_IDW];
    assign err_r_push   = (er_state == ER_R) && r_in_rdy[er_xid[AXI_XIDW-1 -: MIW]];
    assign err_r_owner  = er_xid[AXI_XIDW-1 -: MIW];
    assign err_r_id     = er_xid[0 +: AXI_IDW];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ew_state <= EW_AW;
            ew_xid   <= {AXI_XIDW{1'b0}};
        end else begin
            case (ew_state)
                EW_AW: if (wr_gnt_v[ERR] && err_aw_ready) begin
                    ew_xid   <= {wr_gnt_m[ERR],
                                 aw_id[wr_gnt_m[ERR]*AXI_IDW +: AXI_IDW]};
                    ew_state <= EW_W;
                end
                EW_W:  if (w_pop[ew_xid[AXI_XIDW-1 -: MIW]]) ew_state <= EW_B;
                EW_B:  if (err_b_push) ew_state <= EW_AW;
                default: ew_state <= EW_AW;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            er_state <= ER_AR;
            er_xid   <= {AXI_XIDW{1'b0}};
        end else begin
            case (er_state)
                ER_AR: if (rd_gnt_v[ERR] && err_ar_ready) begin
                    er_xid   <= {rd_gnt_m[ERR],
                                 ar_id[rd_gnt_m[ERR]*AXI_IDW +: AXI_IDW]};
                    er_state <= ER_R;
                end
                ER_R:  if (err_r_push) er_state <= ER_AR;
                default: er_state <= ER_AR;
            endcase
        end
    end

    // ======================================================================
    // Per-master transaction state update.
    // ======================================================================
    genvar tm;
    generate
    for (tm = 0; tm < N_MST; tm++) begin : g_state
        logic [SIW:0] awd, ard, wrd, rdd;
        logic         b_done, r_done;
        assign awd = aw_dest[tm*(SIW+1) +: (SIW+1)];
        assign ard = ar_dest[tm*(SIW+1) +: (SIW+1)];
        assign wrd = wr_dest[tm*(SIW+1) +: (SIW+1)];
        assign rdd = rd_dest[tm*(SIW+1) +: (SIW+1)];
        assign b_done = (wrd == ERR[SIW:0])
            ? (err_b_push && err_b_owner == tm[MIW-1:0])
            : (b_slave_push[wrd] && b_slave_owner[wrd*MIW +: MIW] == tm[MIW-1:0]);
        assign r_done = (rdd == ERR[SIW:0])
            ? (err_r_push && err_r_owner == tm[MIW-1:0])
            : (r_slave_push[rdd] && r_slave_owner[rdd*MIW +: MIW] == tm[MIW-1:0]);
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                wr_state[tm*2 +: 2] <= 2'd0;
                rd_state[tm]        <= 1'b0;
                wr_dest[tm*(SIW+1) +: (SIW+1)] <= {(SIW+1){1'b0}};
                rd_dest[tm*(SIW+1) +: (SIW+1)] <= {(SIW+1){1'b0}};
            end else begin
                case (wr_state[tm*2 +: 2])
                    2'd0: if (aw_pop[tm]) begin
                        wr_state[tm*2 +: 2] <= 2'd1;
                        wr_dest[tm*(SIW+1) +: (SIW+1)] <= awd;
                    end
                    2'd1: if (w_pop[tm]) wr_state[tm*2 +: 2] <= 2'd2;
                    2'd2: if (b_done)      wr_state[tm*2 +: 2] <= 2'd0;
                    default:               wr_state[tm*2 +: 2] <= 2'd0;
                endcase
                if (rd_state[tm] == 1'b0) begin
                    if (ar_pop[tm]) begin
                        rd_state[tm] <= 1'b1;
                        rd_dest[tm*(SIW+1) +: (SIW+1)] <= ard;
                    end
                end else if (r_done) begin
                    rd_state[tm] <= 1'b0;
                end
            end
        end
    end
    endgenerate

    // round-robin pointers advance past the granted master on issue
    integer pi;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (pi = 0; pi < N_DST; pi++) begin
                wr_ptr[pi] <= {MIW{1'b0}};
                rd_ptr[pi] <= {MIW{1'b0}};
            end
        end else begin
            for (pi = 0; pi < N_DST; pi++) begin
                if (aw_issue[pi]) wr_ptr[pi] <= (wr_gnt_m[pi] + 1'b1) % N_MST;
                if (ar_issue[pi]) rd_ptr[pi] <= (rd_gnt_m[pi] + 1'b1) % N_MST;
            end
        end
    end

    // ======================================================================
    // Formal properties (yosys-smtbmc via sby; hidden from verilator lint).
    // See ethereal-shell/formal/eth_axi_xbar.sby.
    //
    // REGRESSION GUARD for the 2026-09-01 cross-master same-destination
    // response-aliasing bug (report-E1-RUN3: two masters with in-flight
    // transactions to the SAME destination aliased in the OR-merge owner
    // scans, so the BMC's IMG_DIGEST read data was routed to the host's
    // EFP_STATUS poll). Proves the per-destination lock-step discipline the
    // wr_busy/rd_busy fix enforces:
    //   (U) per-destination in-flight UNIQUENESS: at most one master has an
    //       in-flight write (state WDATA/WAITB) resp. read (state WAITR)
    //       targeting any destination;
    //   (C) busy<->in-flight CONSISTENCY: wr_busy[d]/rd_busy[d] is set IFF
    //       some master has an in-flight write/read to d — the grant mask is
    //       exactly the in-flight set;
    //   (O) OWNER routing: a B (resp. R) beat accepted from a destination is
    //       routed ONLY to the master whose in-flight transaction targets it
    //       — every other master has NO matching in-flight (the exact
    //       counterexample scenario of the bug, now excluded).
    // Plus the pre-existing §7 props (response VALID stability, error-slave
    // owner bounds).
    //
    // LIVENESS (wr_busy/rd_busy eventually clear) is deliberately NOT
    // asserted: prove-mode k-induction is safety-only; progress needs
    // fairness (slaves eventually respond, masters eventually accept B/R),
    // i.e. a liveness engine with fairness constraints that smtbmc prove
    // does not provide. The safety family above already pins the buggy
    // interleaving; non-vacuity is witnessed by the cover() statements
    // (checked by the sby `cover` task).
    //
    // ENVIRONMENT ASSUMPTIONS (AXI contract, same spirit as eth_wb2axi):
    // masters hold AW/W/AR VALID+payload stable while stalled; slaves hold
    // B/R VALID+payload stable while stalled and (A3.4.1 ordering) assert B
    // only for a write they fully accepted (W beat taken, B not yet given)
    // and R only for an outstanding AR — tracked by the formal-only shadow
    // counters b_pending/r_pending below.
    // ======================================================================
`ifdef FORMAL
    logic past_valid = 1'b0;
    integer fi, fa, fp;
    always_ff @(posedge clk_i) past_valid <= 1'b1;

    // Initialize deterministically: hold reset for the first cycle so the
    // engine cannot pick an arbitrary initial state (spurious counterexamples
    // unrelated to real operation).
    always_ff @(posedge clk_i) if (!past_valid) assume(!rst_ni);

    // ---- shadow counters: responses owed by each real slave -----------------
    // b_pending[d] = W beats accepted by slave d minus B beats returned;
    // r_pending[d] = ARs accepted by slave d minus R beats returned.
    logic [N_SLV*2-1:0] b_pending, r_pending;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            b_pending <= {N_SLV*2{1'b0}};
            r_pending <= {N_SLV*2{1'b0}};
        end else begin
            for (fi = 0; fi < N_SLV; fi++) begin
                case ({m_wvalid[fi] && m_wready[fi], m_bvalid[fi] && m_bready[fi]})
                    2'b10:   b_pending[fi*2 +: 2] <= b_pending[fi*2 +: 2] + 2'd1;
                    2'b01:   b_pending[fi*2 +: 2] <= b_pending[fi*2 +: 2] - 2'd1;
                    default: b_pending[fi*2 +: 2] <= b_pending[fi*2 +: 2];
                endcase
                case ({m_arvalid[fi] && m_arready[fi], m_rvalid[fi] && m_rready[fi]})
                    2'b10:   r_pending[fi*2 +: 2] <= r_pending[fi*2 +: 2] + 2'd1;
                    2'b01:   r_pending[fi*2 +: 2] <= r_pending[fi*2 +: 2] - 2'd1;
                    default: r_pending[fi*2 +: 2] <= r_pending[fi*2 +: 2];
                endcase
            end
        end
    end

    // ---- environment assumptions --------------------------------------------
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // masters: a presented AW/W/AR beat is held stable until accepted
            // (AXI A3.1.2 VALID stability); *_ready may toggle freely.
            for (fa = 0; fa < N_MST; fa++) begin
                if ($past(s_awvalid[fa]) && !$past(s_awready[fa])) begin
                    assume(s_awvalid[fa]);
                    assume(s_awaddr[fa*AXI_AW +: AXI_AW] == $past(s_awaddr[fa*AXI_AW +: AXI_AW]));
                    assume(s_awid[fa*AXI_IDW +: AXI_IDW]   == $past(s_awid[fa*AXI_IDW +: AXI_IDW]));
                end
                if ($past(s_wvalid[fa]) && !$past(s_wready[fa])) begin
                    assume(s_wvalid[fa]);
                    assume(s_wdata[fa*AXI_DW +: AXI_DW] == $past(s_wdata[fa*AXI_DW +: AXI_DW]));
                    assume(s_wstrb[fa*STRB_W +: STRB_W] == $past(s_wstrb[fa*STRB_W +: STRB_W]));
                end
                if ($past(s_arvalid[fa]) && !$past(s_arready[fa])) begin
                    assume(s_arvalid[fa]);
                    assume(s_araddr[fa*AXI_AW +: AXI_AW] == $past(s_araddr[fa*AXI_AW +: AXI_AW]));
                    assume(s_arid[fa*AXI_IDW +: AXI_IDW]   == $past(s_arid[fa*AXI_IDW +: AXI_IDW]));
                end
            end
            // slaves: a presented B/R beat is held stable until accepted, and
            // (A3.4.1) a response is only offered for an accepted transaction.
            for (fa = 0; fa < N_SLV; fa++) begin
                if ($past(m_bvalid[fa]) && !$past(m_bready[fa])) begin
                    assume(m_bvalid[fa]);
                    assume(m_bid[fa*AXI_XIDW +: AXI_XIDW] == $past(m_bid[fa*AXI_XIDW +: AXI_XIDW]));
                    assume(m_bresp[fa*2 +: 2]             == $past(m_bresp[fa*2 +: 2]));
                end
                if ($past(m_rvalid[fa]) && !$past(m_rready[fa])) begin
                    assume(m_rvalid[fa]);
                    assume(m_rid[fa*AXI_XIDW +: AXI_XIDW] == $past(m_rid[fa*AXI_XIDW +: AXI_XIDW]));
                    assume(m_rdata[fa*AXI_DW +: AXI_DW]   == $past(m_rdata[fa*AXI_DW +: AXI_DW]));
                    assume(m_rresp[fa*2 +: 2]             == $past(m_rresp[fa*2 +: 2]));
                end
                if (m_bvalid[fa]) assume(b_pending[fa*2 +: 2] != 2'd0);
                if (m_rvalid[fa]) assume(r_pending[fa*2 +: 2] != 2'd0);
            end
        end
    end

    // ---- (U)+(C): per-destination in-flight uniqueness & busy consistency ---
    genvar fd;
    generate
    for (fd = 0; fd < N_DST; fd++) begin : g_fml_dst
        logic [MIW:0] wcnt, rcnt;
        always_comb begin
            wcnt = {(MIW+1){1'b0}};
            rcnt = {(MIW+1){1'b0}};
            for (int q = 0; q < N_MST; q++) begin
                if ((wr_state[q*2 +: 2] != 2'd0) &&
                    (wr_dest[q*(SIW+1) +: (SIW+1)] == fd[SIW:0]))
                    wcnt = wcnt + 1'b1;
                if (rd_state[q] &&
                    (rd_dest[q*(SIW+1) +: (SIW+1)] == fd[SIW:0]))
                    rcnt = rcnt + 1'b1;
            end
        end
        always_ff @(posedge clk_i) begin
            if (past_valid && rst_ni) begin
                // (U) uniqueness — the aliasing precondition is unreachable.
                assert(wcnt <= 1);
                assert(rcnt <= 1);
                // (C) the grant-mask busy bits ARE the in-flight set.
                assert(wr_busy[fd] == (wcnt != 0));
                assert(rd_busy[fd] == (rcnt != 0));
            end
        end
    end
    endgenerate

    // ---- (O): B/R beats route ONLY to the issuing master --------------------
    genvar fs;
    generate
    for (fs = 0; fs < N_SLV; fs++) begin : g_fml_owner
        logic [MIW-1:0] bom, rom;
        assign bom = b_slave_owner[fs*MIW +: MIW];
        assign rom = r_slave_owner[fs*MIW +: MIW];
        always_ff @(posedge clk_i) begin
            if (past_valid && rst_ni) begin
                if (b_slave_push[fs]) begin
                    // the chosen owner really owns the in-flight write ...
                    assert(wr_state[bom*2 +: 2] == 2'd2);
                    assert(wr_dest[bom*(SIW+1) +: (SIW+1)] == fs[SIW:0]);
                    // ... and no OTHER master has a matching in-flight write
                    // (the E1-RUN3 aliasing counterexample, excluded).
                    for (int q = 0; q < N_MST; q++)
                        if (q != bom)
                            assert((wr_state[q*2 +: 2] == 2'd0) ||
                                   (wr_dest[q*(SIW+1) +: (SIW+1)] != fs[SIW:0]));
                end
                if (r_slave_push[fs]) begin
                    assert(rd_state[rom]);
                    assert(rd_dest[rom*(SIW+1) +: (SIW+1)] == fs[SIW:0]);
                    for (int q = 0; q < N_MST; q++)
                        if (q != rom)
                            assert(!rd_state[q] ||
                                   (rd_dest[q*(SIW+1) +: (SIW+1)] != fs[SIW:0]));
                end
            end
        end
    end
    endgenerate

    // ---- auxiliary invariants (strengthen k-induction): the error-slave FSM
    // and its recorded xid stay consistent with the recorded owner's
    // transaction state (entered at grant, advanced by the same events that
    // advance the owner), so the owner checks below are inductive.
    always_ff @(posedge clk_i) begin
        if (past_valid && rst_ni) begin
            if (ew_state == EW_W) begin
                assert(wr_state[err_b_owner*2 +: 2] == 2'd1);
                assert(wr_dest[err_b_owner*(SIW+1) +: (SIW+1)] == ERR[SIW:0]);
            end
            if (ew_state == EW_B) begin
                assert(wr_state[err_b_owner*2 +: 2] == 2'd2);
                assert(wr_dest[err_b_owner*(SIW+1) +: (SIW+1)] == ERR[SIW:0]);
            end
            if (er_state == ER_R) begin
                assert(rd_state[err_r_owner]);
                assert(rd_dest[err_r_owner*(SIW+1) +: (SIW+1)] == ERR[SIW:0]);
            end
        end
    end

    // ---- error-slave owner checks + pre-existing §7 props -------------------
    always_ff @(posedge clk_i) begin
        if (past_valid && rst_ni) begin
            if (err_b_push) begin
                assert(wr_state[err_b_owner*2 +: 2] == 2'd2);
                assert(wr_dest[err_b_owner*(SIW+1) +: (SIW+1)] == ERR[SIW:0]);
            end
            if (err_r_push) begin
                assert(rd_state[err_r_owner]);
                assert(rd_dest[err_r_owner*(SIW+1) +: (SIW+1)] == ERR[SIW:0]);
            end
        end
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // §7 prop 1: master-facing response VALID stability while stalled.
            for (fp = 0; fp < N_MST; fp++) begin
                if ($past(s_bvalid[fp]) && !$past(s_bready[fp])) begin
                    assert(s_bvalid[fp]);
                    assert(s_bid[fp*AXI_IDW +: AXI_IDW] == $past(s_bid[fp*AXI_IDW +: AXI_IDW]));
                end
                if ($past(s_rvalid[fp]) && !$past(s_rready[fp])) begin
                    assert(s_rvalid[fp]);
                    assert(s_rid[fp*AXI_IDW +: AXI_IDW] == $past(s_rid[fp*AXI_IDW +: AXI_IDW]));
                    assert(s_rdata[fp*AXI_DW +: AXI_DW] == $past(s_rdata[fp*AXI_DW +: AXI_DW]));
                end
            end
            // §7 prop 5: an error-slave response always targets a valid master.
            if (ew_state == EW_B) assert(ew_xid[AXI_XIDW-1 -: MIW] < N_MST);
            if (er_state == ER_R) assert(er_xid[AXI_XIDW-1 -: MIW] < N_MST);
        end
        if (past_valid && !$past(rst_ni)) begin
            assert(s_bvalid == {N_MST{1'b0}});
            assert(s_rvalid == {N_MST{1'b0}});
        end
    end

    // ---- witnesses (non-vacuity; exercised by the sby `cover` task) ----------
    always_ff @(posedge clk_i) begin
        if (past_valid && rst_ni) begin
            cover(wr_busy[0] && wr_busy[1]);            // 2 slaves busy at once
            cover(wr_busy[ERR] && rd_busy[ERR]);        // DECERR slave exercised
            cover((|wr_busy) && (|rd_busy));            // both directions live
            cover(wr_ptr[MIW-1:0] != {MIW{1'b0}});      // RR granted master 1
            cover(rd_ptr[MIW-1:0] != {MIW{1'b0}});
            cover(&s_bvalid);                           // every master holds a B
            cover(&s_rvalid);                           // every master holds an R
        end
    end
`endif

endmodule
