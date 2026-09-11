`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_fifo
// Description: First-word-fall-through synchronous FIFO — the per-channel data
//              buffer of `eth_dma_mc` between the AXI read burst that fills it
//              and the AXI write burst that drains it (S15 §3).
// Details:     Classic pointer-with-extra-bit ring buffer (no arithmetic
//              compare): EMPTY = equal pointers, FULL = equal low bits with
//              different wrap bits, so no counter width guessing is needed.
//              DEPTH is a power of two and every parameter is expressed as a
//              sized constant, so the module is width-clean under
//              `verilator --lint-only -Wall`.
//
//              Contract:
//                * rd_valid_o is a pure function of stored state (never of
//                  wr_valid_i / rd_ready_i) and rd_data_o is the current head —
//                  the caller may treat it as a 0-latency read when rd_ready_i
//                  is asserted in the same cycle (FWFT).
//                * a beat is written only on wr_valid_i && wr_ready_o, read
//                  only on rd_valid_o && rd_ready_i; wr_ready_o is high when a
//                  slot is free OR the read frees a slot this cycle.
//                * flush_i is a synchronous clear that takes priority (a write
//                  in the same cycle is dropped) — used by the channel when a
//                  descriptor starts, faults or is aborted.
//              A read that lands on the entry written in the same cycle returns
//              the OLD value (non-blocking array write) — the standard FWFT
//              bubble-free ordering.
//
//              Inference-first (ADR-017): the storage is a plain array, so each
//              target infers LUTRAM/BRAM/registers as it sees fit.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (多通道 DMA
//              可配置项: 缓冲深度) · docs/adr/ADR-017 (inference-first)
// Notes:       iverilog -g2012 compatible (flat ports, no SV interface/modport).
module eth_dma_fifo #(
    parameter int DW    = 64,   // beat width in bits
    parameter int DEPTH = 16    // entries (power of two)
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               flush_i,
    // write side (producer)
    input  logic               wr_valid_i,
    output logic               wr_ready_o,
    input  logic [DW-1:0]      wr_data_i,
    // read side (consumer)
    output logic               rd_valid_o,
    input  logic               rd_ready_i,
    output logic [DW-1:0]      rd_data_o
);

    localparam int AW = $clog2(DEPTH);
    localparam logic [AW:0] PTR_ONE = {{AW{1'b0}}, 1'b1};

    logic [DW-1:0] mem [0:DEPTH-1];
    logic [AW:0]   wr_ptr_r;
    logic [AW:0]   rd_ptr_r;
    logic          full;
    logic          do_rd;
    logic          do_wr;

    assign full       = (wr_ptr_r[AW] != rd_ptr_r[AW]) &&
                        (wr_ptr_r[AW-1:0] == rd_ptr_r[AW-1:0]);
    assign rd_valid_o = (wr_ptr_r != rd_ptr_r);
    assign rd_data_o  = mem[rd_ptr_r[AW-1:0]];
    assign do_rd      = rd_valid_o && rd_ready_i;
    assign wr_ready_o = (!flush_i) && ((!full) || do_rd);
    assign do_wr      = wr_valid_i && wr_ready_o;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_r <= {AW+1{1'b0}};
            rd_ptr_r <= {AW+1{1'b0}};
        end else if (flush_i) begin
            wr_ptr_r <= {AW+1{1'b0}};
            rd_ptr_r <= {AW+1{1'b0}};
        end else begin
            if (do_wr) begin
                mem[wr_ptr_r[AW-1:0]] <= wr_data_i;
                wr_ptr_r              <= wr_ptr_r + PTR_ONE;
            end
            if (do_rd) begin
                rd_ptr_r <= rd_ptr_r + PTR_ONE;
            end
        end
    end

endmodule

`default_nettype wire
