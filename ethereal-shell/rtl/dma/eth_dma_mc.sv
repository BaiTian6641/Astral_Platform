`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_mc
// Description: Multi-channel scatter-gather DMA with ONE AXI4 master port —
//              `eth_dma_mc` of S15 §3 (通用数据搬运: app-cluster dmaengine / BMC
//              热替换帧 DMA / region 数据).  N_CH channels, each with a
//              descriptor-list engine (fetch → validate → move → next) and its
//              own data FIFO, arbitrated round-robin onto a single AXI4 master.
//
//  DESCRIPTOR (32 bytes = 4 x 64-bit words, 32-byte aligned, fetched by ONE
//  4-beat INCR read burst).  Fields, MSB-first in the fetched word order:
//    byte 0x00  bits [63:0]   SRC   source byte address (64-bit)
//    byte 0x08  bits [63:0]   DST   destination byte address (64-bit)
//    byte 0x10  bits [63:0]   NXT   next descriptor address (64-bit, 0 = END)
//    byte 0x18  bits [15:0]   LEN   transfer length in bytes
//    byte 0x18  bit  [16]     SOF   start-of-frame (latched: CH_STATUS.SOF_SEEN)
//    byte 0x18  bit  [17]     EOF   end-of-frame -> the chain ends after THIS
//                                   descriptor even when NXT != 0
//    byte 0x18  bit  [18]     IOC   interrupt-on-completion of this descriptor
//    byte 0x18  bits [19], [23:20], [31:24] RSVD
//    byte 0x1C  bits [63:0]   RSVD
//  A chain walks NXT until NXT == 0 or a descriptor sets EOF.  v0 rules (a
//  violation raises CH_STATUS.ERROR with ERRCODE = DMA_ERR_DESC and moves no
//  data): LEN != 0, LEN % (AXI_DW/8) == 0, SRC and DST aligned to AXI_DW/8 bytes,
//  NXT and the list base 32-byte aligned.  Addresses wider than AXI_AW are
//  truncated onto the master port.
//
//  REGISTER MAP (4 KiB CSR window; address = {block[11:6], offset[5:0]};
//  block 0 = global, block (ch+1) = channel ch, so channel ch sits at
//  0x040*(ch+1) and owns 64 bytes):
//    GLOBAL
//      +0x00 G_CTRL       RW  [0] EN          global enable
//      +0x04 G_STATUS     RO  [0] BUSY_ANY, [N_CH:1] CH_BUSY (bit ch+1)
//      +0x08 G_IRQ_STATUS RO  [N_CH-1:0] sticky per-channel irq flags
//      +0x0C G_IRQ_EN     RO  [N_CH-1:0] per-channel irq enable mirror
//    CHANNEL (offset inside the channel block)
//      +0x00 CH_CTRL      RW  [0] EN (RW); W1P: [1] START, [2] ABORT,
//                             [3] IRQ_CLR (clears DONE/ERROR/ERRCODE/SOF/EOF/IRQ)
//      +0x04 CH_STATUS    RO  [0] BUSY, [1] DONE, [2] ERROR, [7:4] ERRCODE,
//                             [15:8] DESC_DONE, [16] SOF_SEEN, [17] EOF_SEEN,
//                             [18] IRQ
//      +0x08 CH_DESC_LO   RW  descriptor-list base [31:0]
//      +0x0C CH_DESC_HI   RW  descriptor-list base [63:32]
//      +0x10 CH_CUR_LO    RO  current descriptor address [31:0]
//      +0x14 CH_CUR_HI    RO  current descriptor address [63:32]
//      +0x18 CH_XFER      RO  bytes moved for the current descriptor
//      +0x1C CH_TOTAL     RO  bytes moved since START (32-bit wrap)
//      +0x20 CH_ERR_LO    RO  faulting address [31:0]
//      +0x24 CH_ERR_HI    RO  faulting address [63:32]
//      +0x28 CH_CFG       RW  [0] IRQ_EN
//    ERRCODE: 0 = none, 1 = DECERR, 2 = SLVERR/protocol, 3 = malformed
//    descriptor, 4 = aborted.
//  START is accepted only in the idle/error state with EN=1 and G_CTRL.EN=1
//  (writing EN and START in one access is legal — EN takes effect that cycle);
//  ABORT and clearing EN while busy are deferred to the current AXI burst
//  boundary and report ERRCODE=4.  This is NOT the interrupt output: `irq_o` is
//  the OR of (sticky flag & CH_CFG.IRQ_EN) over the channels.
//
//  BUS: the CSR port is a plain synchronous register bus — writes complete in
//  the cycle csr_wr_valid_i is high (csr_wr_ready_o is constant high), reads
//  are combinational on csr_addr_i while csr_rd_valid_i is high.  Attaching an
//  AXI4-Lite slave (or the BMC register bus) is a separate adapter so this DMA
//  owns no bus flavor.
//
//  CHANNEL ARBITRATION: eth_dma_arb grants one channel at a time round-robin at
//  BURST granularity (each descriptor-length chunk is split into bursts of at
//  most min(FIFO_DEPTH, 256, 4 KiB boundary) beats), and eth_dma_axi_engine
//  keeps exactly one AXI transaction outstanding, so two active channels
//  interleave bursts (verified by tb_eth_dma_mc) while never sharing a
//  response.  AXI IDs are the channel indices, so a response can always be
//  attributed (N_CH <= 2**AXI_IDW).
//
//  NON-GOALS (v0, deliberately out of this vertical slice): AXI4-Stream side;
//  2D/ND-strided addressing and blit/ROP (that is `eth_dma_2d`, S15 §3); more
//  than one outstanding transaction per channel (and therefore concurrent
//  read+write pipelining inside one channel); data realignment / narrow or
//  unaligned transfers (whole AXI_DW/8-byte beats only, WSTRB all ones);
//  descriptor write-back of per-descriptor status; per-descriptor length >
//  65535 bytes; cyclic chains.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §7 ·
//              ethereal-spec/control/eth-axi-v0.md §2 §7 §9
// Notes:       Formal VALID/READY + beat-accounting properties live in
//              eth_dma_axi_engine (ifdef FORMAL), proven by
//              ethereal-shell/formal/eth_dma_mc.sby (`make formal`).
//              iverilog -g2012 compatible.  ASSUMPTION (TBD, 2026-09-12): the
//              DMA has no memory map of its own — it is address-agnostic and
//              surfaces whatever DECERR/SLVERR the attached slave returns; the
//              integrating SoC owns the memory map.
module eth_dma_mc #(
    parameter int N_CH       = 2,       // channel count (1..2**AXI_IDW)
    parameter int AXI_AW     = 32,      // AXI4 master address width (>= 12)
    parameter int AXI_DW     = 64,      // AXI4 master data width
    parameter int AXI_IDW    = 4,       // AXI4 transaction ID width
    parameter int FIFO_DEPTH = 16       // per-channel data FIFO depth (beats)
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- CSR register bus ----
    input  logic                    csr_wr_valid_i,
    output logic                    csr_wr_ready_o,
    input  logic                    csr_rd_valid_i,
    output logic                    csr_rd_ready_o,
    input  logic [11:0]             csr_addr_i,
    input  logic [31:0]             csr_wdata_i,
    output logic [31:0]             csr_rdata_o,
    // ---- aggregate interrupt (level; clear per channel via CH_CTRL.IRQ_CLR) --
    output logic                    irq_o,
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

    localparam int ARB_IDX_W = (N_CH > 1) ? $clog2(N_CH) : 1;

    // ------------------------------------------------------------------
    // Global CSR registers
    // ------------------------------------------------------------------
    logic g_en_r, g_en_nxt;

    logic [5:0] csr_blk;
    logic [5:0] csr_off;
    assign csr_blk = csr_addr_i[11:6];
    assign csr_off = csr_addr_i[5:0];

    // ------------------------------------------------------------------
    // Interconnect wires
    // ------------------------------------------------------------------
    logic [N_CH-1:0]        arb_req;
    logic [N_CH-1:0]        arb_gnt;
    logic [ARB_IDX_W-1:0]   arb_idx;
    logic                   arb_valid;

    logic                   eng_tx_valid;
    logic                   eng_tx_ready;
    logic                   eng_tx_op;
    logic [AXI_AW-1:0]      eng_tx_addr;
    logic [7:0]             eng_tx_len;
    logic [AXI_IDW-1:0]     eng_tx_id;
    logic                   eng_tx_done;
    logic [1:0]             eng_tx_resp;
    logic                   eng_rd_valid;
    logic                   eng_rd_ready;
    logic [AXI_DW-1:0]      eng_rd_data;
    logic                   eng_wr_valid;
    logic                   eng_wr_ready;
    logic [AXI_DW-1:0]      eng_wr_data;

    logic                   owner_valid_r, owner_valid_nxt;
    logic [ARB_IDX_W-1:0]   owner_r, owner_nxt;

    // per-channel buses
    logic                   ch_tx_op    [0:N_CH-1];
    logic [AXI_AW-1:0]      ch_tx_addr  [0:N_CH-1];
    logic [7:0]             ch_tx_len   [0:N_CH-1];
    logic [AXI_IDW-1:0]     ch_tx_id    [0:N_CH-1];
    logic                   ch_rd_ready [0:N_CH-1];
    logic                   ch_wr_valid [0:N_CH-1];
    logic [AXI_DW-1:0]      ch_wr_data  [0:N_CH-1];
    logic [31:0]            ch_rd_chain [0:N_CH-1];
    logic [3*N_CH-1:0]      gstat_chain [0:N_CH-1];
    logic [31:0]            ch_rd_mux;
    logic [N_CH-1:0]        g_busy_w;
    logic [N_CH-1:0]        g_irq_flag_w;
    logic [N_CH-1:0]        g_irq_en_w;
    localparam logic [N_CH-1:0] CH_BIT_N = N_CH'(1);

    assign ch_rd_mux = ch_rd_chain[N_CH-1];
    // G_STATUS / G_IRQ_STATUS / G_IRQ_EN words, assembled per channel without a
    // dynamic index or an unpacked-array reduction (bit ch+1 = channel ch).
    assign {g_irq_en_w, g_irq_flag_w, g_busy_w} = gstat_chain[N_CH-1];
    assign irq_o = |(g_irq_flag_w & g_irq_en_w);

    // ------------------------------------------------------------------
    // Channels (each owns its CSR block, FIFO and descriptor engine)
    // ------------------------------------------------------------------
    generate
        for (genvar g = 0; g < N_CH; g++) begin : g_ch
            localparam logic [ARB_IDX_W-1:0] CH_ID = ARB_IDX_W'(g);
            localparam logic [11:0] BLK_BASE = 12'(12'h040 * (g + 1));

            logic               blk_hit;
            logic               wr_strobe;
            logic               tx_valid_g;
            logic               tx_op_g;
            logic [AXI_AW-1:0]  tx_addr_g;
            logic [7:0]         tx_len_g;
            logic               tx_ready_g;
            logic               tx_done_g;
            logic [AXI_IDW-1:0] tx_id_g;
            logic               rd_valid_g;
            logic               rd_ready_g;
            logic               wr_valid_g;
            logic               wr_ready_g;
            logic [AXI_DW-1:0]  wr_data_g;
            logic               busy_g;
            logic               irq_flag_g;
            logic               irq_en_g;
            logic [N_CH-1:0]    busy_word_g;
            logic [N_CH-1:0]    irq_flag_word_g;
            logic [N_CH-1:0]    irq_en_word_g;
            logic [31:0]        rdata_g;
            logic [31:0]        rdata_mux_g;

            assign blk_hit     = (csr_blk == BLK_BASE[11:6]);
            assign wr_strobe   = csr_wr_valid_i && blk_hit;
            assign rdata_mux_g = blk_hit ? rdata_g : 32'h0;

            // arbitration / ownership routing for this channel
            assign arb_req[g] = tx_valid_g;
            assign tx_ready_g = arb_gnt[g] && eng_tx_ready;
            assign tx_done_g  = eng_tx_done && owner_valid_r && (owner_r == CH_ID);
            assign rd_valid_g = owner_valid_r && (owner_r == CH_ID) && eng_rd_valid;
            assign wr_ready_g = owner_valid_r && (owner_r == CH_ID) && eng_wr_ready;

            // status collection
            assign ch_tx_op[g]    = tx_op_g;
            assign ch_tx_addr[g]  = tx_addr_g;
            assign ch_tx_len[g]   = tx_len_g;
            assign ch_tx_id[g]    = tx_id_g;
            assign ch_rd_ready[g] = rd_ready_g;
            assign ch_wr_valid[g] = wr_valid_g;
            assign ch_wr_data[g]  = wr_data_g;
            assign busy_word_g     = busy_g     ? (CH_BIT_N << g) : {N_CH{1'b0}};
            assign irq_flag_word_g = irq_flag_g ? (CH_BIT_N << g) : {N_CH{1'b0}};
            assign irq_en_word_g   = irq_en_g   ? (CH_BIT_N << g) : {N_CH{1'b0}};

            // CSR read-data chain (one-hot block hit -> no dynamic array index)
            if (g == 0) begin : g_chain0
                assign ch_rd_chain[0]  = rdata_mux_g;
                assign gstat_chain[0]  = {irq_en_word_g, irq_flag_word_g, busy_word_g};
            end else begin : g_chainn
                assign ch_rd_chain[g]  = ch_rd_chain[g-1] | rdata_mux_g;
                assign gstat_chain[g]  = gstat_chain[g-1] |
                                         {irq_en_word_g, irq_flag_word_g, busy_word_g};
            end

            eth_dma_channel #(
                .CH_INDEX   (g),
                .AXI_AW     (AXI_AW),
                .AXI_DW     (AXI_DW),
                .AXI_IDW    (AXI_IDW),
                .FIFO_DEPTH (FIFO_DEPTH)
            ) u_ch (
                .clk_i       (clk_i),
                .rst_ni      (rst_ni),
                .csr_wr_i    (wr_strobe),
                .csr_off_i   (csr_off),
                .csr_wdata_i (csr_wdata_i),
                .csr_rdata_o (rdata_g),
                .g_en_i      (g_en_r),
                .busy_o      (busy_g),
                .irq_flag_o  (irq_flag_g),
                .irq_en_o    (irq_en_g),
                .tx_valid_o  (tx_valid_g),
                .tx_ready_i  (tx_ready_g),
                .tx_op_o     (tx_op_g),
                .tx_addr_o   (tx_addr_g),
                .tx_len_o    (tx_len_g),
                .tx_id_o     (tx_id_g),
                .tx_done_i   (tx_done_g),
                .tx_resp_i   (eng_tx_resp),
                .rd_valid_i  (rd_valid_g),
                .rd_ready_o  (rd_ready_g),
                .rd_data_i   (eng_rd_data),
                .wr_valid_o  (wr_valid_g),
                .wr_ready_i  (wr_ready_g),
                .wr_data_o   (wr_data_g)
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // Round-robin arbiter + single-outstanding AXI engine
    // ------------------------------------------------------------------
    eth_dma_arb #(
        .N_CH (N_CH)
    ) u_arb (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .req_i       (arb_req),
        .gnt_o       (arb_gnt),
        .gnt_idx_o   (arb_idx),
        .gnt_valid_o (arb_valid),
        .gnt_ack_i   (eng_tx_valid && eng_tx_ready)
    );

    // the granted channel's request drives the engine
    assign eng_tx_valid = arb_valid;
    assign eng_tx_op    = ch_tx_op[arb_idx];
    assign eng_tx_addr  = ch_tx_addr[arb_idx];
    assign eng_tx_len   = ch_tx_len[arb_idx];
    assign eng_tx_id    = ch_tx_id[arb_idx];

    eth_dma_axi_engine #(
        .AXI_AW  (AXI_AW),
        .AXI_DW  (AXI_DW),
        .AXI_IDW (AXI_IDW)
    ) u_eng (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .tx_valid_i   (eng_tx_valid),
        .tx_ready_o   (eng_tx_ready),
        .tx_op_i      (eng_tx_op),
        .tx_addr_i    (eng_tx_addr),
        .tx_len_i     (eng_tx_len),
        .tx_id_i      (eng_tx_id),
        .tx_done_o    (eng_tx_done),
        .tx_resp_o    (eng_tx_resp),
        .rd_valid_o   (eng_rd_valid),
        .rd_ready_i   (eng_rd_ready),
        .rd_data_o    (eng_rd_data),
        .wr_valid_i   (eng_wr_valid),
        .wr_ready_o   (eng_wr_ready),
        .wr_data_i    (eng_wr_data),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr (m_axi_awaddr),
        .m_axi_awlen  (m_axi_awlen),
        .m_axi_awsize (m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awid   (m_axi_awid),
        .m_axi_wvalid (m_axi_wvalid),
        .m_axi_wready (m_axi_wready),
        .m_axi_wdata  (m_axi_wdata),
        .m_axi_wstrb  (m_axi_wstrb),
        .m_axi_wlast  (m_axi_wlast),
        .m_axi_bvalid (m_axi_bvalid),
        .m_axi_bready (m_axi_bready),
        .m_axi_bresp  (m_axi_bresp),
        .m_axi_bid    (m_axi_bid),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr (m_axi_araddr),
        .m_axi_arlen  (m_axi_arlen),
        .m_axi_arsize (m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arid   (m_axi_arid),
        .m_axi_rvalid (m_axi_rvalid),
        .m_axi_rready (m_axi_rready),
        .m_axi_rdata  (m_axi_rdata),
        .m_axi_rresp  (m_axi_rresp),
        .m_axi_rlast  (m_axi_rlast),
        .m_axi_rid    (m_axi_rid)
    );

    // ------------------------------------------------------------------
    // Transaction owner tracking: the engine's data ports are routed to the
    // channel whose request it accepted, until that transaction completes.
    // ------------------------------------------------------------------
    always_comb begin
        owner_valid_nxt = owner_valid_r;
        owner_nxt       = owner_r;
        if (eng_tx_valid && eng_tx_ready) begin
            owner_valid_nxt = 1'b1;
            owner_nxt       = arb_idx;
        end else if (eng_tx_done) begin
            owner_valid_nxt = 1'b0;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            owner_valid_r <= 1'b0;
            owner_r       <= {ARB_IDX_W{1'b0}};
        end else begin
            owner_valid_r <= owner_valid_nxt;
            owner_r       <= owner_nxt;
        end
    end

    assign eng_rd_ready = owner_valid_r ? ch_rd_ready[owner_r] : 1'b0;
    assign eng_wr_valid = owner_valid_r ? ch_wr_valid[owner_r] : 1'b0;
    assign eng_wr_data  = ch_wr_data[owner_r];

    // ------------------------------------------------------------------
    // Global registers + CSR read mux
    // ------------------------------------------------------------------
    always_comb begin
        g_en_nxt = g_en_r;
        if (csr_wr_valid_i && (csr_blk == eth_dma_pkg::CSR_BLK_GLOBAL) &&
            (csr_off == eth_dma_pkg::CSR_OFF_G_CTRL)) begin
            g_en_nxt = csr_wdata_i[0];
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            g_en_r <= 1'b0;
        end else begin
            g_en_r <= g_en_nxt;
        end
    end

    always_comb begin
        csr_wr_ready_o = 1'b1;
        csr_rd_ready_o = 1'b1;
        csr_rdata_o    = 32'h0;
        if (csr_rd_valid_i) begin
            if (csr_blk == eth_dma_pkg::CSR_BLK_GLOBAL) begin
                case (csr_off)
                    eth_dma_pkg::CSR_OFF_G_CTRL: begin
                        csr_rdata_o[0] = g_en_r;
                    end
                    eth_dma_pkg::CSR_OFF_G_STATUS: begin
                        csr_rdata_o[0]      = |g_busy_w;
                        csr_rdata_o[N_CH:1] = g_busy_w;
                    end
                    eth_dma_pkg::CSR_OFF_G_IRQ_STATUS: begin
                        csr_rdata_o[N_CH-1:0] = g_irq_flag_w;
                    end
                    eth_dma_pkg::CSR_OFF_G_IRQ_EN: begin
                        csr_rdata_o[N_CH-1:0] = g_irq_en_w;
                    end
                    default: begin
                        csr_rdata_o = 32'h0;
                    end
                endcase
            end else begin
                csr_rdata_o = ch_rd_mux;
            end
        end
    end

    // ------------------------------------------------------------------
    // Parameter sanity (elaboration-time)
    // ------------------------------------------------------------------
    initial begin : g_param_check
        if (N_CH > (1 << AXI_IDW)) begin
            $error("eth_dma_mc: N_CH=%0d exceeds the AXI ID space (AXI_IDW=%0d)",
                   N_CH, AXI_IDW);
        end
        if (FIFO_DEPTH > 256) begin
            $error("eth_dma_mc: FIFO_DEPTH=%0d exceeds the 256-beat AxLEN cap",
                   FIFO_DEPTH);
        end
    end

endmodule

`default_nettype wire
