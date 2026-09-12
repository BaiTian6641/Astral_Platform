`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      npu_arr8
// Description: NPU-Tiny 8x8 INT8 weight-stationary systolic GEMM array with its
//              stagger feeder and weight staging (C11 §1.2 §2.1).
// Details:     Dataflow (one K-chunk of 8, M output rows, N = 8 columns):
//                * feeder row k is preloaded with column k of A (i.e. A^T row k),
//                  shifted one byte per enabled cycle with a row skew of k
//                  cycles: the bus of row k carries V_k[x] = A[x-k][k], and 0
//                  outside the M window — the classic diagonal skew.
//                * PE(k,n) holds W[k][n] stationary and computes
//                  acc <= sat_i32(psum_in + a_in * W[k][n]) while it shifts the
//                  activation one column right and the partial sum one row down.
//                * hence column n's chain output during cycle y is C[m][n] with
//                  m = y - 8 - n (timing derivation in the report §1).
//              The tile (npu_t) owns the descriptor, FSM, capture into the C
//              buffer and the service registers; this module is the datapath.
//              Feeder = 8 x 8-byte shift registers with a byte write port (the A
//              staging area), weight staging = 8 x 8-byte register file.
//              Register files (not BSRAM) because the feeder needs 8 parallel
//              read ports; ASSUMPTION 2026-09-13 documented in the report
//              (BSRAM double-buffering arrives with the E3-SVC2 DMA front end).
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S11-Service-Tile.md §2.2 ·
//              ethereal-plan/components/C11-NPU-Tiny组件.md §1 §2.1 §2.2
// Notes:       LEAK_INJECT: verification-only negative control (see pe_int8).
module npu_arr8 #(
    parameter bit LEAK_INJECT = 1'b0
) (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         clr_i,        // session clear (datapath blank)
    // ---- A feeder load (byte write port, driven by the tile's A_WR register) ----
    input  logic [7:0]   a_wr_oh_i,    // one-hot feeder row enable
    input  logic [2:0]   a_pos_i,      // position in the shift register (M index)
    input  logic [31:0]  a_wdata_i,    // 4 bytes; byte (r%4) belongs to row r
    // ---- W staging load (byte write port, driven by the tile's W_WR register) ----
    input  logic [7:0]   w_wr_oh_i,    // one-hot W staging row enable
    input  logic         w_col_hi_i,   // 0 -> columns 0..3, 1 -> columns 4..7
    input  logic [31:0]  w_wdata_i,    // 4 bytes
    // ---- array control ----
    input  logic         shf_en_i,     // shift + MAC enable (RUN + DRAIN)
    input  logic [7:0]   feed_en_oh_i, // one-hot feeder-row shift enable (skew)
    input  logic         w_load_i,     // weight latch enable (LOAD_W)
    input  logic [2:0]   w_ld_col_i,   // weight column being broadcast (LOAD_W)
    // ---- results / status ----
    output logic [255:0] col_o,        // PE(7,n).psum_o, column n at [32*n +: 32]
    output logic         ovf_o,        // sticky saturation flag (OR of all PEs)
    // ---- observability (house convention: wide obs buses, cf. fabric_top) ----
    output logic [511:0]   obs_feed_o, // feeder shift registers: row r at [64*r]
    output logic [511:0]   obs_wstg_o, // weight staging:          row r at [64*r]
    output logic [511:0]   obs_wgt_o,  // PE weight registers: PE(r,n) at [8*(8r+n)]
    output logic [2047:0]  obs_acc_o   // PE accumulators:    PE(r,n) at [32*(8r+n)]
);
    logic [63:0] sr_q   [0:7];         // feeder shift registers (byte 0 = head)
    logic [63:0] wstg_q [0:7];         // weight staging
    logic [63:0] sr_nxt   [0:7];
    logic [63:0] wstg_nxt [0:7];

    logic signed [7:0]  a_wire [0:7][0:8];   // a_wire[r][0]=row input, [c+1]=PE(r,c).a_o
    logic signed [7:0]  a_edge [0:7];        // right-edge activation (unused)
    logic signed [31:0] p_wire [0:8][0:7];   // psum chain, p_wire[0][*] = 0
    logic        [7:0]  pe_w   [0:7][0:7];   // weight registers (observability)
    logic               pe_ovf [0:7][0:7];
    logic        [7:0]  w_bus  [0:7];        // per-row weight bus (LOAD_W)

    // ---- feeder / weight staging / PE grid ----
    generate
        for (genvar r = 0; r < 8; r++) begin : g_row
            localparam int BBYTE = (r % 4) * 8;

            // Byte-replace of the feeder shift register at position a_pos_i.
            logic [63:0] sr_mask_r;
            assign sr_mask_r   = 64'h0000_0000_0000_00FF << {a_pos_i, 3'b000};
            assign sr_nxt[r]   = a_wr_oh_i[r]
                               ? ((sr_q[r] & ~sr_mask_r) |
                                  ({{56{1'b0}}, a_wdata_i[BBYTE +: 8]} << {a_pos_i, 3'b000}))
                               : sr_q[r];

            // W staging byte-replace: 4 bytes land in the low or the high half.
            assign wstg_nxt[r] = w_wr_oh_i[r]
                               ? (w_col_hi_i ? {w_wdata_i, wstg_q[r][31:0]}
                                             : {wstg_q[r][63:32], w_wdata_i})
                               : wstg_q[r];

            always_ff @(posedge clk_i) begin
                if (!rst_ni) begin
                    sr_q[r]   <= 64'h0000_0000_0000_0000;
                    wstg_q[r] <= 64'h0000_0000_0000_0000;
                end else if (clr_i) begin
                    // Session clear blanks the A/W staging buffers. LEAK_INJECT=1
                    // deliberately keeps them (negative control).
                    if (!LEAK_INJECT) begin
                        sr_q[r]   <= 64'h0000_0000_0000_0000;
                        wstg_q[r] <= 64'h0000_0000_0000_0000;
                    end
                end else if (a_wr_oh_i[r] || w_wr_oh_i[r]) begin
                    sr_q[r]   <= sr_nxt[r];
                    wstg_q[r] <= wstg_nxt[r];
                end else if (feed_en_oh_i[r]) begin
                    // shift right (toward byte 0), zero-fill beyond the M window
                    sr_q[r] <= {8'h00, sr_q[r][63:8]};
                end
            end

            // Weight broadcast for LOAD_W: staging column w_ld_col_i, all rows.
            assign w_bus[r] = wstg_q[r][{w_ld_col_i, 3'b000} +: 8];

            assign obs_feed_o[64*r +: 64] = sr_q[r];
            assign obs_wstg_o[64*r +: 64] = wstg_q[r];

            // Row bus: V_r[x] = A[x-r][r] while the row is enabled, else 0.
            assign a_wire[r][0] = feed_en_oh_i[r] ? sr_q[r][7:0] : 8'sd0;

            for (genvar c = 0; c < 8; c++) begin : g_col
                pe_int8 #(.LEAK_INJECT(LEAK_INJECT)) u_pe (
                    .clk_i    (clk_i),
                    .rst_ni   (rst_ni),
                    .clr_i    (clr_i),
                    .en_i     (shf_en_i),
                    .w_load_i (w_load_i && (w_ld_col_i == c[2:0])),
                    .w_i      (w_bus[r]),
                    .a_i      (a_wire[r][c]),
                    .psum_i   (p_wire[r][c]),
                    .a_o      (a_wire[r][c+1]),
                    .psum_o   (p_wire[r+1][c]),
                    .w_o      (pe_w[r][c]),
                    .ovf_o    (pe_ovf[r][c])
                );
                assign obs_wgt_o[8*(8*r + c) +: 8]   = pe_w[r][c];
                assign obs_acc_o[32*(8*r + c) +: 32] = p_wire[r+1][c];
            end
            assign a_edge[r] = a_wire[r][8];
        end
    endgenerate

    // Row-0 partial sums are the array's top injection: always zero.
    generate
        for (genvar c = 0; c < 8; c++) begin : g_psum_top
            assign p_wire[0][c] = 32'sd0;
        end
    endgenerate

    // Column outputs + saturation flag.
    generate
        for (genvar c = 0; c < 8; c++) begin : g_col_out
            assign col_o[32*c +: 32] = p_wire[8][c];
        end
    endgenerate
    logic [63:0] ovf_flat;
    generate
        for (genvar r = 0; r < 8; r++) begin : g_ovf_row
            for (genvar c = 0; c < 8; c++) begin : g_ovf_col
                assign ovf_flat[8*r + c] = pe_ovf[r][c];
            end
        end
    endgenerate
    assign ovf_o = |ovf_flat;

    // The right-most activation of each row is the array edge: sink it.
    logic _unused_ok;
    assign _unused_ok = (^a_edge[0]) ^ (^a_edge[1]) ^ (^a_edge[2]) ^ (^a_edge[3])
                      ^ (^a_edge[4]) ^ (^a_edge[5]) ^ (^a_edge[6]) ^ (^a_edge[7]);
endmodule

`default_nettype wire
