`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_axi_stream
// Description: AXI4-Stream source + sink (the config-frame plane endpoints).
// Details:     Implements the AXI4-Stream plane of ethereal-spec/control/
//              eth-axi-v0.md §4: a single unidirectional channel
//              {tvalid,tready,tdata,tkeep,tlast}. A frame = a beat sequence
//              ending in tlast (used for OCC -> fabric_top config frames).
//
//              * eth_axi_stream_source: a master endpoint. It presents a
//                registered output stream (no comb in->out, §2 rule 1) built on
//                eth_axi_skidbuf, so tvalid never depends combinationally on
//                tready and tdata/tkeep/tlast stay stable while stalled (§7
//                prop 6). The local side is a simple valid/ready/last push port.
//              * eth_axi_stream_sink: a slave endpoint. It registers tready
//                (never a comb function of tvalid) and delivers the received
//                beats on a local valid/ready/last pull port, again through a
//                skid buffer so a stalled local consumer cannot put a comb path
//                on tready.
//
//              Both endpoints are thin wrappers around eth_axi_skidbuf so the
//              backpressure correctness lives in exactly one place.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §4 (AXI4-Stream), §2 (rules)
// Notes:       tkeep is carried but not interpreted in v0 (config frames are
//              full-word; partial-final-beat keep is a v0.1 nicety). iverilog-
//              compatible (flat ports). Formal props under `ifdef FORMAL (sby).
// ============================================================================

// ---------------------------------------------------------------------------
// AXI4-Stream master (source): local push -> AXI4-Stream out.
// ---------------------------------------------------------------------------
module eth_axi_stream_source #(
    parameter int AXI_DW = 32
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // local push port (producer)
    input  logic                  in_valid,
    output logic                  in_ready,
    input  logic [AXI_DW-1:0]     in_data,
    input  logic [(AXI_DW/8)-1:0] in_keep,
    input  logic                  in_last,
    // AXI4-Stream master out
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic [AXI_DW-1:0]     m_axis_tdata,
    output logic [(AXI_DW/8)-1:0] m_axis_tkeep,
    output logic                  m_axis_tlast
);
    localparam int PW = AXI_DW + (AXI_DW/8) + 1;
    logic [PW-1:0] pl_in, pl_out;

    assign pl_in = {in_data, in_keep, in_last};
    eth_axi_skidbuf #(.PW(PW)) u_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(in_valid), .i_ready(in_ready), .i_data(pl_in),
        .o_valid(m_axis_tvalid), .o_ready(m_axis_tready), .o_data(pl_out)
    );
    assign m_axis_tdata = pl_out[PW-1 -: AXI_DW];
    assign m_axis_tkeep = pl_out[1 +: (AXI_DW/8)];
    assign m_axis_tlast = pl_out[0];

`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni)
            if ($past(m_axis_tvalid) && !$past(m_axis_tready)) begin
                assert(m_axis_tvalid && m_axis_tlast == $past(m_axis_tlast));
                assert(m_axis_tdata == $past(m_axis_tdata));
            end
    end
`endif
endmodule

// ---------------------------------------------------------------------------
// AXI4-Stream slave (sink): AXI4-Stream in -> local pull.
// ---------------------------------------------------------------------------
module eth_axi_stream_sink #(
    parameter int AXI_DW = 32
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // AXI4-Stream slave in
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic [AXI_DW-1:0]     s_axis_tdata,
    input  logic [(AXI_DW/8)-1:0] s_axis_tkeep,
    input  logic                  s_axis_tlast,
    // local pull port (consumer)
    output logic                  out_valid,
    input  logic                  out_ready,
    output logic [AXI_DW-1:0]     out_data,
    output logic [(AXI_DW/8)-1:0] out_keep,
    output logic                  out_last
);
    localparam int PW = AXI_DW + (AXI_DW/8) + 1;
    logic [PW-1:0] pl_in, pl_out;

    assign pl_in = {s_axis_tdata, s_axis_tkeep, s_axis_tlast};
    eth_axi_skidbuf #(.PW(PW)) u_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axis_tvalid), .i_ready(s_axis_tready), .i_data(pl_in),
        .o_valid(out_valid), .o_ready(out_ready), .o_data(pl_out)
    );
    assign out_data = pl_out[PW-1 -: AXI_DW];
    assign out_keep = pl_out[1 +: (AXI_DW/8)];
    assign out_last = pl_out[0];

`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni)
            if ($past(out_valid) && !$past(out_ready)) begin
                assert(out_valid && out_last == $past(out_last));
                assert(out_data == $past(out_data));
            end
    end
`endif
endmodule

// ---------------------------------------------------------------------------
// Full-duplex stream endpoint (source + sink). A convenience wrapper so the
// file has a top-level `eth_axi_stream` module (matches the filename + the
// lint loop's --top-module). A node that both sends and receives frames uses
// one of these; single-direction nodes use source/sink directly.
// ---------------------------------------------------------------------------
module eth_axi_stream #(
    parameter int AXI_DW = 32
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // TX (local push -> AXI4-Stream out)
    input  logic                  tx_in_valid,
    output logic                  tx_in_ready,
    input  logic [AXI_DW-1:0]     tx_in_data,
    input  logic [(AXI_DW/8)-1:0] tx_in_keep,
    input  logic                  tx_in_last,
    output logic                  tx_tvalid,
    input  logic                  tx_tready,
    output logic [AXI_DW-1:0]     tx_tdata,
    output logic [(AXI_DW/8)-1:0] tx_tkeep,
    output logic                  tx_tlast,
    // RX (AXI4-Stream in -> local pull)
    input  logic                  rx_tvalid,
    output logic                  rx_tready,
    input  logic [AXI_DW-1:0]     rx_tdata,
    input  logic [(AXI_DW/8)-1:0] rx_tkeep,
    input  logic                  rx_tlast,
    output logic                  rx_out_valid,
    input  logic                  rx_out_ready,
    output logic [AXI_DW-1:0]     rx_out_data,
    output logic [(AXI_DW/8)-1:0] rx_out_keep,
    output logic                  rx_out_last
);
    eth_axi_stream_source #(.AXI_DW(AXI_DW)) u_tx (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .in_valid(tx_in_valid), .in_ready(tx_in_ready), .in_data(tx_in_data),
        .in_keep(tx_in_keep), .in_last(tx_in_last),
        .m_axis_tvalid(tx_tvalid), .m_axis_tready(tx_tready),
        .m_axis_tdata(tx_tdata), .m_axis_tkeep(tx_tkeep), .m_axis_tlast(tx_tlast)
    );
    eth_axi_stream_sink #(.AXI_DW(AXI_DW)) u_rx (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .s_axis_tvalid(rx_tvalid), .s_axis_tready(rx_tready),
        .s_axis_tdata(rx_tdata), .s_axis_tkeep(rx_tkeep), .s_axis_tlast(rx_tlast),
        .out_valid(rx_out_valid), .out_ready(rx_out_ready), .out_data(rx_out_data),
        .out_keep(rx_out_keep), .out_last(rx_out_last)
    );
endmodule
`default_nettype wire
