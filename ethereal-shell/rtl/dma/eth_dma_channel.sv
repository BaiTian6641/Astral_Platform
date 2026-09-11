`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_channel
// Description: One scatter-gather DMA channel of `eth_dma_mc`: descriptor fetch
//              → validate → data move (read burst to the data FIFO, write burst
//              out of it) → next descriptor, with per-channel error/status/IRQ
//              and its own CSR block (S15 §3: 描述符链表, SOF/EOF, IOC).
// Details:     DESCRIPTOR (32 B = 4 x 64-bit words, fetched by ONE 4-beat INCR
//              read burst; full layout in eth_dma_pkg.sv / the eth_dma_mc
//              header): {SRC[63:0], DST[63:0], NXT[63:0], LEN[15:0]+SOF+EOF+IOC}.
//              A chain ends when NXT == 0 OR the descriptor has EOF set.
//
//              FSM (5 states, two-segment):
//                ST_IDLE  : idle / done / error resting state; START begins a
//                           chain at CH_DESC_LO/HI (must be 32-byte aligned);
//                ST_FETCH : issue the descriptor read burst, shift the 4 beats
//                           into desc_r, decode + validate on completion;
//                ST_RD    : issue a data read burst of up to FIFO_DEPTH beats
//                           (also capped at 256 beats and at the next 4 KiB
//                           boundary, AXI4 IHI0022G §A3.4.1) and push the beats
//                           into the channel FIFO (rd_ready_o is the storage
//                           backpressure into the AXI R channel);
//                ST_WR    : issue the matching write burst of the same beat
//                           count and stream it out of the FIFO;
//                ST_NDESC : descriptor done — count it, raise IRQ on IOC, then
//                           follow NXT or finish (DONE) or fault.
//              Exactly ONE AXI transaction is outstanding (tx_valid_o is held
//              until tx_ready_i, and tx_active_r tracks the accepted one), so a
//              channel never overlaps its own read and write bursts; the bus is
//              released between bursts for the arbiter.  ABORT (and clearing EN
//              while busy) is DEFERRED to the current AXI burst boundary so the
//              AXI master is never abandoned mid-transaction; it reports
//              DMA_ERR_ABORT.
//
//              Serialization is deliberate v0 scope (see the eth_dma_mc header
//              "NON-GOALS"): the channel does not run a read burst and a write
//              burst concurrently, so it needs no credit-based FIFO accounting.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (多通道 DMA:
//              描述符链表/散射聚集 src/dst/len/ctrl, SOF/EOF, IOC, 寄存器直驱 +
//              SG 模式, 64 位地址) · ethereal-spec/control/eth-axi-v0.md §9
// Notes:       iverilog -g2012 compatible.  AXI_AW >= 12 (4 KiB limit math);
//              AXI_DW in {8,16,32,64,...}; LEN must be a non-zero multiple of
//              AXI_DW/8 and SRC/DST aligned to AXI_DW/8 bytes (v0 has no data
//              realignment, see NON-GOALS).
module eth_dma_channel #(
    parameter int CH_INDEX    = 0,      // channel index (AXI transaction ID)
    parameter int AXI_AW      = 32,
    parameter int AXI_DW      = 64,
    parameter int AXI_IDW     = 4,
    parameter int FIFO_DEPTH  = 16      // data FIFO depth in beats (power of two)
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- CSR block (64-byte block; the top has already decoded the block) ----
    input  logic                    csr_wr_i,
    input  logic [5:0]              csr_off_i,
    input  logic [31:0]             csr_wdata_i,
    output logic [31:0]             csr_rdata_o,
    // ---- top-level control / status ----
    input  logic                    g_en_i,       // G_CTRL.EN
    output logic                    busy_o,
    output logic                    irq_flag_o,   // sticky flag (ungated)
    output logic                    irq_en_o,     // CH_CFG.IRQ_EN
    // ---- arbitrated AXI transaction port ----
    output logic                    tx_valid_o,
    input  logic                    tx_ready_i,
    output logic                    tx_op_o,      // 0 = read, 1 = write
    output logic [AXI_AW-1:0]       tx_addr_o,
    output logic [7:0]              tx_len_o,     // beats - 1
    output logic [AXI_IDW-1:0]      tx_id_o,
    input  logic                    tx_done_i,
    input  logic [1:0]              tx_resp_i,
    // ---- read beats pushed by the engine (only while this channel owns it) ---
    input  logic                    rd_valid_i,
    output logic                    rd_ready_o,
    input  logic [AXI_DW-1:0]       rd_data_i,
    // ---- write beats pulled by the engine ----
    output logic                    wr_valid_o,
    input  logic                    wr_ready_i,
    output logic [AXI_DW-1:0]       wr_data_o
);

    // ------------------------------------------------------------------
    // Derived sizes
    // ------------------------------------------------------------------
    localparam int DESC_BYTES_C   = eth_dma_pkg::DESC_BYTES;      // 32
    localparam int DESC_W_C       = eth_dma_pkg::DESC_W;          // 256
    localparam int BEAT_BYTES     = AXI_DW / 8;
    localparam int LOG_BEAT_BYTES = $clog2(BEAT_BYTES);
    localparam int DESC_BEATS_C   = DESC_BYTES_C / BEAT_BYTES;    // 4 for DW=64
    localparam logic [15:0] DESC_BEATS   = 16'(DESC_BEATS_C);
    localparam logic [7:0]  DESC_LEN8    = 8'(DESC_BEATS_C - 1);
    localparam logic [15:0] FIFO_BEATS   = 16'(FIFO_DEPTH);
    localparam logic [15:0] MAX_BURST    = 16'd256;   // AXI4: AxLEN is 8 bits
    localparam logic [63:0] ZERO64       = 64'h0;

    typedef enum logic [2:0] {
        ST_IDLE  = 3'd0,
        ST_FETCH = 3'd1,
        ST_RD    = 3'd2,
        ST_WR    = 3'd3,
        ST_NDESC = 3'd4
    } ch_state_e;

    // ------------------------------------------------------------------
    // State + datapath + CSR registers
    // ------------------------------------------------------------------
    ch_state_e          state_r,           state_nxt;
    logic               req_valid_r,       req_valid_nxt;
    logic               req_op_r,          req_op_nxt;
    logic [AXI_AW-1:0]  req_addr_r,        req_addr_nxt;
    logic [7:0]         req_len_r,         req_len_nxt;
    logic               tx_active_r,       tx_active_nxt;
    logic [DESC_W_C-1:0] desc_r,           desc_nxt;
    logic [15:0]        fetch_cnt_r,       fetch_cnt_nxt;
    logic [63:0]        nxt_r,             nxt_nxt;
    logic               eof_r,             eof_nxt;
    logic               ioc_r,             ioc_nxt;
    logic [15:0]        beats_left_r,      beats_left_nxt;
    logic [15:0]        burst_beats_r,     burst_beats_nxt;
    logic [15:0]        beat_cnt_r,        beat_cnt_nxt;
    logic [63:0]        src_cur_r,         src_cur_nxt;
    logic [63:0]        dst_cur_r,         dst_cur_nxt;
    logic [31:0]        xfer_r,            xfer_nxt;
    logic [31:0]        total_r,           total_nxt;
    logic [7:0]         desc_done_r,       desc_done_nxt;
    logic               busy_r,            busy_nxt;
    logic               done_r,            done_nxt;
    logic               err_r,             err_nxt;
    logic [3:0]         errcode_r,         errcode_nxt;
    logic [63:0]        err_addr_r,        err_addr_nxt;
    logic               irq_flag_r,        irq_flag_nxt;
    logic               sof_seen_r,        sof_seen_nxt;
    logic               eof_seen_r,        eof_seen_nxt;
    logic               abort_r,           abort_nxt;
    logic               en_r,              en_nxt;
    logic               irq_en_r,          irq_en_nxt;
    logic [63:0]        desc_base_r,       desc_base_nxt;
    logic [63:0]        cur_desc_r,        cur_desc_nxt;

    // fault funnel (set inside the FSM, applied once at the end of the comb)
    logic               fault_c;
    logic [3:0]         fault_code_c;
    logic [63:0]        fault_addr_c;

    // CSR write decode (combinational)
    logic               start_req_c;
    logic               abort_req_c;
    logic               irq_clr_c;

    // descriptor decode (combinational, valid in the ST_FETCH completion cycle)
    logic [63:0]        d_src_c, d_dst_c, d_nxt_c;
    logic [15:0]        d_len_c;
    logic               d_sof_c, d_eof_c, d_ioc_c;
    logic [15:0]        d_beats_c, d_burst_c;

    // datapath / FIFO handshake (combinational)
    logic               fifo_flush_c;
    logic               fifo_wr_v_c;
    logic               fifo_wr_ready_c;
    logic               fifo_rd_r_c;
    logic               fifo_rd_valid_c;
    logic [AXI_DW-1:0]  fifo_rd_data_c;

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    // Beats of AXI_DW width that fit before the next 4 KiB boundary.  AXI4
    // forbids a burst crossing it; addresses are beat-aligned, so the result
    // is at least 1 (IHI0022G §A3.4.1).
    function automatic logic [15:0] lim_4k(input logic [11:0] a_lo);
        logic [12:0] rem;
        begin
            rem    = 13'd4096 - {1'b0, a_lo};
            lim_4k = {3'b0, rem} >> LOG_BEAT_BYTES;
        end
    endfunction

    // per-burst beat count: remaining beats, FIFO capacity, 256-beat AxLEN cap
    // and both 4 KiB limits.
    function automatic logic [15:0] burst_min(
        input logic [15:0] beats,
        input logic [15:0] lim_s,
        input logic [15:0] lim_d
    );
        logic [15:0] b;
        begin
            b = beats;
            if (FIFO_BEATS < b) b = FIFO_BEATS;
            if (MAX_BURST  < b) b = MAX_BURST;
            if (lim_s      < b) b = lim_s;
            if (lim_d      < b) b = lim_d;
            burst_min = b;
        end
    endfunction

    // ------------------------------------------------------------------
    // Data FIFO (owned by the channel; the engine reaches it only while this
    // channel is the granted owner — enforced by eth_dma_mc)
    // ------------------------------------------------------------------
    eth_dma_fifo #(
        .DW    (AXI_DW),
        .DEPTH (FIFO_DEPTH)
    ) u_fifo (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .flush_i    (fifo_flush_c),
        .wr_valid_i (fifo_wr_v_c),
        .wr_ready_o (fifo_wr_ready_c),
        .wr_data_i  (rd_data_i),
        .rd_valid_o (fifo_rd_valid_c),
        .rd_ready_i (fifo_rd_r_c),
        .rd_data_o  (fifo_rd_data_c)
    );

    // ------------------------------------------------------------------
    // Constant outputs
    // ------------------------------------------------------------------
    assign busy_o     = busy_r;
    assign irq_flag_o = irq_flag_r;
    assign irq_en_o   = irq_en_r;
    assign tx_valid_o = req_valid_r && (!abort_r);
    assign tx_op_o    = req_op_r;
    assign tx_addr_o  = req_addr_r;
    assign tx_len_o   = req_len_r;
    assign tx_id_o    = CH_INDEX[AXI_IDW-1:0];
    assign wr_data_o  = fifo_rd_data_c;

    // ------------------------------------------------------------------
    // CSR read mux (combinational; see the register map in eth_dma_pkg.sv)
    // ------------------------------------------------------------------
    always_comb begin
        csr_rdata_o = 32'h0;
        case (csr_off_i)
            eth_dma_pkg::CSR_OFF_CH_CTRL: begin
                csr_rdata_o[eth_dma_pkg::CH_CTRL_EN_LSB] = en_r;
            end
            eth_dma_pkg::CSR_OFF_CH_STATUS: begin
                csr_rdata_o[eth_dma_pkg::CH_ST_BUSY_BIT]  = busy_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_DONE_BIT]  = done_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_ERROR_BIT] = err_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_ERRCODE_LSB +: 4] = errcode_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_DESCNT_LSB +: 8]  = desc_done_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_SOF_BIT]   = sof_seen_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_EOF_BIT]   = eof_seen_r;
                csr_rdata_o[eth_dma_pkg::CH_ST_IRQ_BIT]   = irq_flag_r;
            end
            eth_dma_pkg::CSR_OFF_CH_DESC_LO: csr_rdata_o = desc_base_r[31:0];
            eth_dma_pkg::CSR_OFF_CH_DESC_HI: csr_rdata_o = desc_base_r[63:32];
            eth_dma_pkg::CSR_OFF_CH_CUR_LO:  csr_rdata_o = cur_desc_r[31:0];
            eth_dma_pkg::CSR_OFF_CH_CUR_HI:  csr_rdata_o = cur_desc_r[63:32];
            eth_dma_pkg::CSR_OFF_CH_XFER:    csr_rdata_o = xfer_r;
            eth_dma_pkg::CSR_OFF_CH_TOTAL:   csr_rdata_o = total_r;
            eth_dma_pkg::CSR_OFF_CH_ERR_LO:  csr_rdata_o = err_addr_r[31:0];
            eth_dma_pkg::CSR_OFF_CH_ERR_HI:  csr_rdata_o = err_addr_r[63:32];
            eth_dma_pkg::CSR_OFF_CH_CFG: begin
                csr_rdata_o[eth_dma_pkg::CH_CFG_IRQEN_BIT] = irq_en_r;
            end
            default: csr_rdata_o = 32'h0;
        endcase
    end

    // ------------------------------------------------------------------
    // Next-state logic (combinational segment; defaults first)
    // ------------------------------------------------------------------
    always_comb begin
        state_nxt       = state_r;
        req_valid_nxt   = req_valid_r;
        req_op_nxt      = req_op_r;
        req_addr_nxt    = req_addr_r;
        req_len_nxt     = req_len_r;
        tx_active_nxt   = tx_active_r;
        desc_nxt        = desc_r;
        fetch_cnt_nxt   = fetch_cnt_r;
        nxt_nxt         = nxt_r;
        eof_nxt         = eof_r;
        ioc_nxt         = ioc_r;
        beats_left_nxt  = beats_left_r;
        burst_beats_nxt = burst_beats_r;
        beat_cnt_nxt    = beat_cnt_r;
        src_cur_nxt     = src_cur_r;
        dst_cur_nxt     = dst_cur_r;
        xfer_nxt        = xfer_r;
        total_nxt       = total_r;
        desc_done_nxt   = desc_done_r;
        busy_nxt        = busy_r;
        done_nxt        = done_r;
        err_nxt         = err_r;
        errcode_nxt     = errcode_r;
        err_addr_nxt    = err_addr_r;
        irq_flag_nxt    = irq_flag_r;
        sof_seen_nxt    = sof_seen_r;
        eof_seen_nxt    = eof_seen_r;
        abort_nxt       = abort_r;
        en_nxt          = en_r;
        irq_en_nxt      = irq_en_r;
        desc_base_nxt   = desc_base_r;
        cur_desc_nxt    = cur_desc_r;

        fault_c      = 1'b0;
        fault_code_c = eth_dma_pkg::DMA_ERR_NONE;
        fault_addr_c = ZERO64;

        start_req_c = 1'b0;
        abort_req_c = 1'b0;
        irq_clr_c   = 1'b0;

        fifo_flush_c = 1'b0;
        fifo_wr_v_c  = 1'b0;
        fifo_rd_r_c  = 1'b0;

        d_src_c   = ZERO64;
        d_dst_c   = ZERO64;
        d_nxt_c   = ZERO64;
        d_len_c   = 16'd0;
        d_sof_c   = 1'b0;
        d_eof_c   = 1'b0;
        d_ioc_c   = 1'b0;
        d_beats_c = 16'd0;
        d_burst_c = 16'd0;

        rd_ready_o = 1'b0;
        wr_valid_o = 1'b0;

        // ---- CSR writes (register file + command decode) -----------------
        if (csr_wr_i) begin
            case (csr_off_i)
                eth_dma_pkg::CSR_OFF_CH_CTRL: begin
                    en_nxt = csr_wdata_i[eth_dma_pkg::CH_CTRL_EN_LSB];
                    if (csr_wdata_i[eth_dma_pkg::CH_CTRL_START_BIT]) begin
                        start_req_c = 1'b1;
                    end
                    if (csr_wdata_i[eth_dma_pkg::CH_CTRL_ABORT_BIT]) begin
                        abort_req_c = 1'b1;
                    end
                    if (csr_wdata_i[eth_dma_pkg::CH_CTRL_IRQ_CLR_BIT]) begin
                        irq_clr_c = 1'b1;
                    end
                end
                eth_dma_pkg::CSR_OFF_CH_DESC_LO: begin
                    desc_base_nxt[31:0] = csr_wdata_i;
                end
                eth_dma_pkg::CSR_OFF_CH_DESC_HI: begin
                    desc_base_nxt[63:32] = csr_wdata_i;
                end
                eth_dma_pkg::CSR_OFF_CH_CFG: begin
                    irq_en_nxt = csr_wdata_i[eth_dma_pkg::CH_CFG_IRQEN_BIT];
                end
                default: begin
                    // read-only / reserved: no effect
                end
            endcase
        end

        // ---- sticky-flag clear (takes effect immediately, see defaults) ---
        if (irq_clr_c) begin
            done_nxt     = 1'b0;
            err_nxt      = 1'b0;
            errcode_nxt  = eth_dma_pkg::DMA_ERR_NONE;
            sof_seen_nxt = 1'b0;
            eof_seen_nxt = 1'b0;
            irq_flag_nxt = 1'b0;
        end

        // ---- ABORT / EN-drop latch (deferred to the burst boundary) -------
        if (abort_req_c || (busy_r && (!en_nxt))) begin
            abort_nxt = 1'b1;
        end

        // ---- main FSM ----------------------------------------------------
        case (state_r)
            ST_IDLE: begin
                if (start_req_c && en_nxt && g_en_i && (!busy_r)) begin
                    busy_nxt       = 1'b1;
                    done_nxt       = 1'b0;
                    err_nxt        = 1'b0;
                    errcode_nxt    = eth_dma_pkg::DMA_ERR_NONE;
                    sof_seen_nxt   = 1'b0;
                    eof_seen_nxt   = 1'b0;
                    irq_flag_nxt   = 1'b0;
                    desc_done_nxt  = 8'd0;
                    xfer_nxt       = 32'd0;
                    total_nxt      = 32'd0;
                    cur_desc_nxt   = desc_base_nxt;
                    fifo_flush_c   = 1'b1;
                    if (desc_base_nxt[eth_dma_pkg::DESC_ALIGN_LOG-1:0] != 0) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::DMA_ERR_DESC;
                        fault_addr_c = desc_base_nxt;
                    end else begin
                        state_nxt     = ST_FETCH;
                        req_valid_nxt = 1'b1;
                        req_op_nxt    = 1'b0;
                        req_addr_nxt  = desc_base_nxt[AXI_AW-1:0];
                        req_len_nxt   = DESC_LEN8;
                        fetch_cnt_nxt = 16'd0;
                        desc_nxt      = {DESC_W_C{1'b0}};
                    end
                end
            end

            ST_FETCH: begin
                // collect the descriptor words (4 beats for AXI_DW=64)
                rd_ready_o = 1'b1;
                if (rd_valid_i) begin
                    // shift in from the TOP: after DESC_BEATS beats the first
                    // word sits in [AXI_DW-1:0], i.e. at its descriptor offset.
                    desc_nxt      = {rd_data_i, desc_r[DESC_W_C-1:AXI_DW]};
                    fetch_cnt_nxt = fetch_cnt_r + 16'd1;
                end
                if (req_valid_r && tx_ready_i) begin
                    req_valid_nxt = 1'b0;
                    tx_active_nxt = 1'b1;
                end
                if (tx_done_i) begin
                    tx_active_nxt = 1'b0;
                    if (tx_resp_i != eth_dma_pkg::AXI_RESP_OKAY) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::dma_err_of_resp(tx_resp_i);
                        fault_addr_c = cur_desc_r;
                    end else if (fetch_cnt_r != DESC_BEATS) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::DMA_ERR_SLVERR;
                        fault_addr_c = cur_desc_r;
                    end else begin
                        d_src_c = desc_r[eth_dma_pkg::DESC_SRC_LSB +: 64];
                        d_dst_c = desc_r[eth_dma_pkg::DESC_DST_LSB +: 64];
                        d_nxt_c = desc_r[eth_dma_pkg::DESC_NXT_LSB +: 64];
                        d_len_c = desc_r[eth_dma_pkg::DESC_LEN_LSB +: 16];
                        d_sof_c = desc_r[eth_dma_pkg::DESC_SOF_BIT];
                        d_eof_c = desc_r[eth_dma_pkg::DESC_EOF_BIT];
                        d_ioc_c = desc_r[eth_dma_pkg::DESC_IOC_BIT];
                        if ((d_len_c == 16'd0) ||
                            (d_len_c[LOG_BEAT_BYTES-1:0] != {LOG_BEAT_BYTES{1'b0}})) begin
                            fault_c      = 1'b1;
                            fault_code_c = eth_dma_pkg::DMA_ERR_DESC;
                            fault_addr_c = cur_desc_r;
                        end else if ((d_src_c[LOG_BEAT_BYTES-1:0] != {LOG_BEAT_BYTES{1'b0}}) ||
                                     (d_dst_c[LOG_BEAT_BYTES-1:0] != {LOG_BEAT_BYTES{1'b0}})) begin
                            fault_c      = 1'b1;
                            fault_code_c = eth_dma_pkg::DMA_ERR_DESC;
                            fault_addr_c = cur_desc_r;
                        end else begin
                            d_beats_c       = d_len_c >> LOG_BEAT_BYTES;
                            d_burst_c       = burst_min(d_beats_c,
                                                        lim_4k(d_src_c[11:0]),
                                                        lim_4k(d_dst_c[11:0]));
                            nxt_nxt         = d_nxt_c;
                            eof_nxt         = d_eof_c;
                            ioc_nxt         = d_ioc_c;
                            sof_seen_nxt    = sof_seen_r | d_sof_c;
                            eof_seen_nxt    = eof_seen_r | d_eof_c;
                            beats_left_nxt  = d_beats_c;
                            burst_beats_nxt = d_burst_c;
                            beat_cnt_nxt    = 16'd0;
                            src_cur_nxt     = d_src_c;
                            dst_cur_nxt     = d_dst_c;
                            xfer_nxt        = 32'd0;
                            state_nxt       = ST_RD;
                            req_valid_nxt   = 1'b1;
                            req_op_nxt      = 1'b0;
                            req_addr_nxt    = d_src_c[AXI_AW-1:0];
                            req_len_nxt     = d_burst_c[7:0] - 8'd1;
                            fifo_flush_c    = 1'b1;
                        end
                    end
                end
            end

            ST_RD: begin
                // read burst in flight: fill the FIFO, backpressure on RREADY
                rd_ready_o  = fifo_wr_ready_c;
                fifo_wr_v_c = rd_valid_i;
                if (rd_valid_i && fifo_wr_ready_c) begin
                    beat_cnt_nxt = beat_cnt_r + 16'd1;
                end
                if (req_valid_r && tx_ready_i) begin
                    req_valid_nxt = 1'b0;
                    tx_active_nxt = 1'b1;
                end
                if (tx_done_i) begin
                    tx_active_nxt = 1'b0;
                    if (tx_resp_i != eth_dma_pkg::AXI_RESP_OKAY) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::dma_err_of_resp(tx_resp_i);
                        fault_addr_c = src_cur_r;
                    end else if (beat_cnt_r != burst_beats_r) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::DMA_ERR_SLVERR;
                        fault_addr_c = src_cur_r;
                    end else begin
                        state_nxt     = ST_WR;
                        beat_cnt_nxt  = 16'd0;
                        req_valid_nxt = 1'b1;
                        req_op_nxt    = 1'b1;
                        req_addr_nxt  = dst_cur_r[AXI_AW-1:0];
                        req_len_nxt   = burst_beats_r[7:0] - 8'd1;
                    end
                end
            end

            ST_WR: begin
                // write burst: stream exactly burst_beats_r beats out of the FIFO
                wr_valid_o = fifo_rd_valid_c && (beat_cnt_r < burst_beats_r);
                fifo_rd_r_c = fifo_rd_valid_c && (beat_cnt_r < burst_beats_r) && wr_ready_i;
                if (wr_valid_o && wr_ready_i) begin
                    beat_cnt_nxt = beat_cnt_r + 16'd1;
                end
                if (req_valid_r && tx_ready_i) begin
                    req_valid_nxt = 1'b0;
                    tx_active_nxt = 1'b1;
                end
                if (tx_done_i) begin
                    tx_active_nxt = 1'b0;
                    if (tx_resp_i != eth_dma_pkg::AXI_RESP_OKAY) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::dma_err_of_resp(tx_resp_i);
                        fault_addr_c = dst_cur_r;
                    end else if (beat_cnt_r != burst_beats_r) begin
                        fault_c      = 1'b1;
                        fault_code_c = eth_dma_pkg::DMA_ERR_SLVERR;
                        fault_addr_c = dst_cur_r;
                    end else if (beats_left_r == burst_beats_r) begin
                        // last burst of this descriptor
                        xfer_nxt       = xfer_r + ({16'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        total_nxt      = total_r + ({16'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        src_cur_nxt    = src_cur_r + ({48'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        dst_cur_nxt    = dst_cur_r + ({48'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        beats_left_nxt = 16'd0;
                        state_nxt      = ST_NDESC;
                    end else begin
                        // more bursts: same descriptor, next chunk
                        beats_left_nxt  = beats_left_r - burst_beats_r;
                        src_cur_nxt     = src_cur_r + ({48'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        dst_cur_nxt     = dst_cur_r + ({48'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        xfer_nxt        = xfer_r + ({16'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        total_nxt       = total_r + ({16'h0, burst_beats_r} << LOG_BEAT_BYTES);
                        burst_beats_nxt = burst_min(beats_left_r - burst_beats_r,
                                                    lim_4k(src_cur_nxt[11:0]),
                                                    lim_4k(dst_cur_nxt[11:0]));
                        beat_cnt_nxt    = 16'd0;
                        state_nxt       = ST_RD;
                        req_valid_nxt   = 1'b1;
                        req_op_nxt      = 1'b0;
                        req_addr_nxt    = src_cur_nxt[AXI_AW-1:0];
                        req_len_nxt     = burst_beats_nxt[7:0] - 8'd1;
                    end
                end
            end

            ST_NDESC: begin
                desc_done_nxt = desc_done_r + 8'd1;
                if (ioc_r) begin
                    irq_flag_nxt = 1'b1;
                end
                if (eof_r || (nxt_r == ZERO64)) begin
                    // end of the chain
                    state_nxt     = ST_IDLE;
                    busy_nxt      = 1'b0;
                    done_nxt      = 1'b1;
                    irq_flag_nxt  = 1'b1;
                    req_valid_nxt = 1'b0;
                    fifo_flush_c  = 1'b1;
                end else if (nxt_r[eth_dma_pkg::DESC_ALIGN_LOG-1:0] != 0) begin
                    fault_c      = 1'b1;
                    fault_code_c = eth_dma_pkg::DMA_ERR_DESC;
                    fault_addr_c = nxt_r;
                end else begin
                    cur_desc_nxt  = nxt_r;
                    state_nxt     = ST_FETCH;
                    req_valid_nxt = 1'b1;
                    req_op_nxt    = 1'b0;
                    req_addr_nxt  = nxt_r[AXI_AW-1:0];
                    req_len_nxt   = DESC_LEN8;
                    fetch_cnt_nxt = 16'd0;
                    desc_nxt      = {DESC_W_C{1'b0}};
                end
            end

            default: begin
                state_nxt = ST_IDLE;
            end
        endcase

        // ---- ABORT override (deferred to the current burst boundary) ------
        if (abort_r && (!tx_active_r) && (!fault_c)) begin
            state_nxt     = ST_IDLE;
            busy_nxt      = 1'b0;
            err_nxt       = 1'b1;
            errcode_nxt   = eth_dma_pkg::DMA_ERR_ABORT;
            err_addr_nxt  = err_addr_r;
            irq_flag_nxt  = 1'b1;
            req_valid_nxt = 1'b0;
            abort_nxt     = 1'b0;
            fifo_flush_c  = 1'b1;
        end

        // ---- fault override (highest priority) ----------------------------
        if (fault_c) begin
            state_nxt     = ST_IDLE;
            busy_nxt      = 1'b0;
            err_nxt       = 1'b1;
            errcode_nxt   = fault_code_c;
            err_addr_nxt  = fault_addr_c;
            irq_flag_nxt  = 1'b1;
            req_valid_nxt = 1'b0;
            tx_active_nxt = 1'b0;
            fifo_flush_c  = 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // State update
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r        <= ST_IDLE;
            req_valid_r    <= 1'b0;
            req_op_r       <= 1'b0;
            req_addr_r     <= {AXI_AW{1'b0}};
            req_len_r      <= 8'd0;
            tx_active_r    <= 1'b0;
            desc_r         <= {DESC_W_C{1'b0}};
            fetch_cnt_r    <= 16'd0;
            nxt_r          <= ZERO64;
            eof_r          <= 1'b0;
            ioc_r          <= 1'b0;
            beats_left_r   <= 16'd0;
            burst_beats_r  <= 16'd0;
            beat_cnt_r     <= 16'd0;
            src_cur_r      <= ZERO64;
            dst_cur_r      <= ZERO64;
            xfer_r         <= 32'd0;
            total_r        <= 32'd0;
            desc_done_r    <= 8'd0;
            busy_r         <= 1'b0;
            done_r         <= 1'b0;
            err_r          <= 1'b0;
            errcode_r      <= eth_dma_pkg::DMA_ERR_NONE;
            err_addr_r     <= ZERO64;
            irq_flag_r     <= 1'b0;
            sof_seen_r     <= 1'b0;
            eof_seen_r     <= 1'b0;
            abort_r        <= 1'b0;
            en_r           <= 1'b0;
            irq_en_r       <= 1'b0;
            desc_base_r    <= ZERO64;
            cur_desc_r     <= ZERO64;
        end else begin
            state_r        <= state_nxt;
            req_valid_r    <= req_valid_nxt;
            req_op_r       <= req_op_nxt;
            req_addr_r     <= req_addr_nxt;
            req_len_r      <= req_len_nxt;
            tx_active_r    <= tx_active_nxt;
            desc_r         <= desc_nxt;
            fetch_cnt_r    <= fetch_cnt_nxt;
            nxt_r          <= nxt_nxt;
            eof_r          <= eof_nxt;
            ioc_r          <= ioc_nxt;
            beats_left_r   <= beats_left_nxt;
            burst_beats_r  <= burst_beats_nxt;
            beat_cnt_r     <= beat_cnt_nxt;
            src_cur_r      <= src_cur_nxt;
            dst_cur_r      <= dst_cur_nxt;
            xfer_r         <= xfer_nxt;
            total_r        <= total_nxt;
            desc_done_r    <= desc_done_nxt;
            busy_r         <= busy_nxt;
            done_r         <= done_nxt;
            err_r          <= err_nxt;
            errcode_r      <= errcode_nxt;
            err_addr_r     <= err_addr_nxt;
            irq_flag_r     <= irq_flag_nxt;
            sof_seen_r     <= sof_seen_nxt;
            eof_seen_r     <= eof_seen_nxt;
            abort_r        <= abort_nxt;
            en_r           <= en_nxt;
            irq_en_r       <= irq_en_nxt;
            desc_base_r    <= desc_base_nxt;
            cur_desc_r     <= cur_desc_nxt;
        end
    end

endmodule

`default_nettype wire
