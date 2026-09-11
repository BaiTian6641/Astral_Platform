`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_arb
// Description: Round-robin arbiter over N_CH single-cycle request lines — the
//              channel arbiter of `eth_dma_mc` (S15 §3 "通道仲裁").
// Details:     Rotating priority with a ONE-HOT pointer (`rr_oh_r`): the pointer
//              bit marks the channel with the highest priority this round, so
//              the priority rotates without any index arithmetic:
//
//                mask_hi = ~(rr_oh_r - 1)   // channels numerically >= rr
//                req_hi  = req & mask_hi    // served first (lowest index wins)
//                req_lo  = req & ~mask_hi   // served only if req_hi is empty
//                gnt     = lowest_set(req_hi) | (req_hi==0 ? lowest_set(req_lo) : 0)
//
//              `lowest_set` is the fixed-priority encoder instantiated per bit in
//              a generate loop; the winner's binary index is the OR of the
//              per-channel constant selected by the one-hot grant (no
//              one-hot-to-binary case table).  On `gnt_ack_i` the pointer
//              rotates by one position: `{gnt[N-2:0], gnt[N-1]}` — the winner's
//              bit becomes the new lowest-priority position.
//
//              Contract: `gnt_o` is one-hot or zero and stable while the request
//              set and the pointer are stable; a requester keeps `req_i` high
//              until its grant is acknowledged (`gnt_ack_i`), and only the
//              acknowledged grant advances the pointer — so a late-arriving
//              request cannot steal an already-presented grant (the grant is
//              recomputed combinationally, but nothing is committed until the
//              handshake, which the consumer side registers).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (多通道 DMA:
//              通道仲裁) · 结构参考 PULP iDMA / Xilinx AXI DMA (引用非抄袭)
// Notes:       N_CH >= 1. iverilog -g2012 compatible (generate loops, sized
//              literals, no procedural loops in always blocks).
module eth_dma_arb #(
    parameter int N_CH  = 2,
    parameter int IDX_W = (N_CH > 1) ? $clog2(N_CH) : 1
) (
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic [N_CH-1:0]     req_i,
    output logic [N_CH-1:0]     gnt_o,
    output logic [IDX_W-1:0]    gnt_idx_o,
    output logic                gnt_valid_o,
    input  logic                gnt_ack_i
);

    localparam logic [N_CH-1:0] RR_ONE = {{(N_CH-1){1'b0}}, 1'b1};

    logic [N_CH-1:0]    rr_oh_r;
    logic [N_CH-1:0]    rr_oh_nxt;
    logic [N_CH-1:0]    mask_hi;
    logic [N_CH-1:0]    req_hi;
    logic [N_CH-1:0]    req_lo;
    logic [N_CH-1:0]    gnt_hi;
    logic [N_CH-1:0]    gnt_lo;
    logic [N_CH-1:0]    gnt;
    logic               any_hi;
    logic [IDX_W-1:0]   idx_chain [0:N_CH-1];
    logic [N_CH-1:0]    rr_oh_rot;

    // channels numerically >= rr have priority this round; mask_hi is all-ones
    // when the pointer sits on channel 0 (nothing is below it).
    assign mask_hi    = ~(rr_oh_r - RR_ONE);
    assign req_hi     = req_i & mask_hi;
    assign req_lo     = req_i & ~mask_hi;
    assign any_hi     = |req_hi;
    assign gnt        = gnt_hi | gnt_lo;
    assign gnt_o      = gnt;
    assign gnt_valid_o = |req_i;
    assign gnt_idx_o  = idx_chain[N_CH-1];

    // the grant becomes the new lowest-priority position: rotate the winner's
    // one-hot bit up by one (the MSB wraps into bit 0).
    generate
        if (N_CH == 1) begin : g_rot1
            assign rr_oh_rot = gnt;
        end else begin : g_rotn
            assign rr_oh_rot = {gnt[N_CH-2:0], gnt[N_CH-1]};
        end
    endgenerate

    generate
        for (genvar g = 0; g < N_CH; g++) begin : g_prio
            localparam logic [IDX_W-1:0] C_ID = IDX_W'(g);
            if (g == 0) begin : g_first
                assign gnt_hi[0]    = req_hi[0];
                assign gnt_lo[0]    = req_lo[0] && (!any_hi);
                assign idx_chain[0] = gnt[0] ? C_ID : {IDX_W{1'b0}};
            end else begin : g_rest
                assign gnt_hi[g]    = req_hi[g] && (!(|req_hi[g-1:0]));
                assign gnt_lo[g]    = req_lo[g] && (!(|req_lo[g-1:0])) && (!any_hi);
                assign idx_chain[g] = idx_chain[g-1] | (gnt[g] ? C_ID : {IDX_W{1'b0}});
            end
        end
    endgenerate

    always_comb begin
        rr_oh_nxt = rr_oh_r;
        if (gnt_ack_i && (|req_i)) begin
            rr_oh_nxt = rr_oh_rot;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rr_oh_r <= RR_ONE;
        end else begin
            rr_oh_r <= rr_oh_nxt;
        end
    end

endmodule

`default_nettype wire
