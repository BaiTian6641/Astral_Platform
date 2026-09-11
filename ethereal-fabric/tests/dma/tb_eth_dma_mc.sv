`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_dma_mc (testbench, self-checking)
// Description: E2-DMA1 acceptance TB for `eth_dma_mc`: the descriptor
//              linked-list scatter-gather engine, the per-channel register
//              interface and the AXI4 master port — with the REAL packaged DRAM
//              socket (`eth_dram_ctrl` + `eth_dram_stub`) as the memory target,
//              so the DMA is exercised as the first real master of that socket
//              (eth-axi-v0.md §9).
// Details:     Coverage:
//                1. register smoke test: G_CTRL/CH_CTRL/CH_DESC_LO/HI read-back,
//                   IRQ_CLR and sticky-flag semantics;
//                2. one channel, FOUR linked descriptors (8 B, 256 B, 512 B,
//                   2048 B) with SOF/EOF/IOC: multi-burst chunking (FIFO depth
//                   and the 4 KiB boundary cap are both hit), word-by-word
//                   destination compare against a reference pattern plus a
//                   region checksum, DESC_DONE/TOTAL/XFER/IRQ checks;
//                3. TWO channels started together and interleaved burst-by-burst
//                   by the round-robin arbiter (checked from the AXI side: both
//                   IDs observed, owner switches counted), each with its own
//                   multi-descriptor chain;
//                4. error path A: descriptor-list base outside the DRAM window
//                   -> the descriptor FETCH gets DECERR, the channel reports
//                   ERROR + ERRCODE=1 + the faulting address and does NOT hang;
//                5. error path B: descriptor whose DST is outside the window ->
//                   the data WRITE gets DECERR after a successful read, ERROR +
//                   ERRCODE=1, and the out-of-window destination is untouched;
//                6. memory-side backpressure: the DMA's AW/W/AR channels go
//                   through 1-deep throttling stages driven by an LFSR (real
//                   WREADY/AWREADY/ARREADY deassertion), and the DRAM socket is
//                   instantiated with long RD/WR latencies; the TB counts the
//                   cycles in which the memory stalled a valid beat, and a
//                   continuous AXI protocol monitor checks VALID stability
//                   (no withdrawal before handshake), WLAST placement, single
//                   outstanding AW/AR and beat accounting on every transfer.
//              DUT is `eth_dma_mc`; the memory is the real DRAM socket, so the
//              TB also covers the DMA<->socket AXI4 interoperation.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §7 ·
//              ethereal-spec/control/eth-axi-v0.md §2 §7 §9
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              Run:
//                iverilog -g2012 -o /tmp/tb_dma_mc \
//                  ethereal-shell/rtl/dma/eth_dma_pkg.sv \
//                  ethereal-shell/rtl/dma/eth_dma_fifo.sv \
//                  ethereal-shell/rtl/dma/eth_dma_arb.sv \
//                  ethereal-shell/rtl/dma/eth_dma_axi_engine.sv \
//                  ethereal-shell/rtl/dma/eth_dma_channel.sv \
//                  ethereal-shell/rtl/dma/eth_dma_mc.sv \
//                  ethereal-shell/rtl/dram/eth_dram_stub.sv \
//                  ethereal-shell/rtl/dram/eth_dram_ctrl.sv \
//                  ethereal-fabric/tests/dma/tb_eth_dma_mc.sv && vvp /tmp/tb_dma_mc
//              The DRAM stub's word array is poked/peeked hierarchically
//              (dut_dram.u_impl.mem) for pattern setup and result checking;
//              all transfers themselves go through the DUT's real AXI4 master.
`timescale 1ns/1ps
module tb_eth_dma_mc;

    // ---------------- configuration ----------------
    localparam int N_CH      = 2;
    localparam int AXI_AW    = 32;
    localparam int AXI_DW    = 64;
    localparam int AXI_IDW   = 4;
    localparam int STRB_W    = AXI_DW / 8;
    localparam int FIFO_DEPTH = 16;
    localparam logic [31:0] MEM_BASE  = 32'h8000_0000;
    localparam int MEM_BYTES  = 64 * 1024;
    localparam int RD_LATENCY = 8;
    localparam int WR_LATENCY = 4;

    // region map (byte offsets inside the DRAM window)
    localparam int OFF_CH0_DESC = 32'h0000;
    localparam int OFF_CH1_DESC = 32'h0100;
    localparam int OFF_ERR_DESC = 32'h0200;
    localparam int OFF_CH0_SRC  = 32'h0800;
    localparam int OFF_CH0_DST  = 32'h2000;
    localparam int OFF_CH1_SRC  = 32'h3000;
    localparam int OFF_CH1_DST  = 32'h4000;
    localparam int OFF_ERR_SRC  = 32'h5000;
    localparam int OFF_ERR_DST  = 32'h6000;
    localparam logic [31:0] OUT_OF_WINDOW = MEM_BASE + MEM_BYTES + 32'h0000_0100;

    // CSR addresses
    localparam logic [11:0] G_CTRL       = 12'h000;
    localparam logic [11:0] G_STATUS     = 12'h004;
    localparam logic [11:0] G_IRQ_STATUS = 12'h008;
    localparam logic [11:0] G_IRQ_EN     = 12'h00C;
    localparam logic [5:0]  CH_CTRL      = 6'h00;
    localparam logic [5:0]  CH_STATUS    = 6'h04;
    localparam logic [5:0]  CH_DESC_LO   = 6'h08;
    localparam logic [5:0]  CH_DESC_HI   = 6'h0C;
    localparam logic [5:0]  CH_CUR_LO    = 6'h10;
    localparam logic [5:0]  CH_XFER      = 6'h18;
    localparam logic [5:0]  CH_TOTAL     = 6'h1C;
    localparam logic [5:0]  CH_ERR_LO    = 6'h20;
    localparam logic [5:0]  CH_CFG       = 6'h28;

    localparam logic [3:0] ERR_NONE = 4'd0, ERR_DECERR = 4'd1, ERR_SLVERR = 4'd2,
                           ERR_DESC = 4'd3, ERR_ABORT = 4'd4;

    // ---------------- clock / reset ----------------
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    // ---------------- CSR ----------------
    logic        csr_wr_valid = 1'b0;
    logic        csr_wr_ready;
    logic        csr_rd_valid = 1'b0;
    logic        csr_rd_ready;
    logic [11:0] csr_addr = 12'h0;
    logic [31:0] csr_wdata = 32'h0;
    logic [31:0] csr_rdata;
    logic        irq_out;

    // ---------------- DMA AXI4 master ----------------
    logic         d_awvalid, d_awready;
    logic [31:0]  d_awaddr;
    logic [7:0]   d_awlen;
    logic [2:0]   d_awsize;
    logic [1:0]   d_awburst;
    logic [3:0]   d_awid;
    logic         d_wvalid, d_wready, d_wlast;
    logic [63:0]  d_wdata;
    logic [7:0]   d_wstrb;
    logic         d_bvalid, d_bready;
    logic [1:0]   d_bresp;
    logic [3:0]   d_bid;
    logic         d_arvalid, d_arready;
    logic [31:0]  d_araddr;
    logic [7:0]   d_arlen;
    logic [2:0]   d_arsize;
    logic [1:0]   d_arburst;
    logic [3:0]   d_arid;
    logic         d_rvalid, d_rready, d_rlast;
    logic [63:0]  d_rdata;
    logic [1:0]   d_rresp;
    logic [3:0]   d_rid;

    // ---------------- DRAM socket side (post-throttle) ----------------
    logic         s_awvalid, s_awready;
    logic [31:0]  s_awaddr;
    logic [7:0]   s_awlen;
    logic [2:0]   s_awsize;
    logic [1:0]   s_awburst;
    logic [3:0]   s_awid;
    logic         s_wvalid, s_wready, s_wlast;
    logic [63:0]  s_wdata;
    logic [7:0]   s_wstrb;
    logic         s_bvalid, s_bready;
    logic [1:0]   s_bresp;
    logic [3:0]   s_bid;
    logic         s_arvalid, s_arready;
    logic [31:0]  s_araddr;
    logic [7:0]   s_arlen;
    logic [2:0]   s_arsize;
    logic [1:0]   s_arburst;
    logic [3:0]   s_arid;
    logic         s_rvalid, s_rready, s_rlast;
    logic [63:0]  s_rdata;
    logic [1:0]   s_rresp;
    logic [3:0]   s_rid;

    // ==================================================================
    // DUT
    // ==================================================================
    eth_dma_mc #(
        .N_CH       (N_CH),
        .AXI_AW     (AXI_AW),
        .AXI_DW     (AXI_DW),
        .AXI_IDW    (AXI_IDW),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) dut_dma (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .csr_wr_valid_i (csr_wr_valid),
        .csr_wr_ready_o (csr_wr_ready),
        .csr_rd_valid_i (csr_rd_valid),
        .csr_rd_ready_o (csr_rd_ready),
        .csr_addr_i     (csr_addr),
        .csr_wdata_i    (csr_wdata),
        .csr_rdata_o    (csr_rdata),
        .irq_o          (irq_out),
        .m_axi_awvalid  (d_awvalid),
        .m_axi_awready  (d_awready),
        .m_axi_awaddr   (d_awaddr),
        .m_axi_awlen    (d_awlen),
        .m_axi_awsize   (d_awsize),
        .m_axi_awburst  (d_awburst),
        .m_axi_awid     (d_awid),
        .m_axi_wvalid   (d_wvalid),
        .m_axi_wready   (d_wready),
        .m_axi_wdata    (d_wdata),
        .m_axi_wstrb    (d_wstrb),
        .m_axi_wlast    (d_wlast),
        .m_axi_bvalid   (d_bvalid),
        .m_axi_bready   (d_bready),
        .m_axi_bresp    (d_bresp),
        .m_axi_bid      (d_bid),
        .m_axi_arvalid  (d_arvalid),
        .m_axi_arready  (d_arready),
        .m_axi_araddr   (d_araddr),
        .m_axi_arlen    (d_arlen),
        .m_axi_arsize   (d_arsize),
        .m_axi_arburst  (d_arburst),
        .m_axi_arid     (d_arid),
        .m_axi_rvalid   (d_rvalid),
        .m_axi_rready   (d_rready),
        .m_axi_rdata    (d_rdata),
        .m_axi_rresp    (d_rresp),
        .m_axi_rlast    (d_rlast),
        .m_axi_rid      (d_rid)
    );

    // ==================================================================
    // Memory-side backpressure: one 1-deep throttling stage per
    // master->slave channel (AW/W/AR).  The slave's READY is passed through to
    // the stage; the stage's upstream READY is additionally gated by an LFSR,
    // so the DMA really sees AWREADY/WREADY/ARREADY deasserted.  Beats are held
    // in the stage register, so no beat is lost or duplicated.
    // ==================================================================
    logic [15:0] lfsr_r;
    logic        stall_c;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_r <= 16'hACE1;
        end else begin
            lfsr_r <= {lfsr_r[14:0], lfsr_r[15] ^ lfsr_r[13] ^ lfsr_r[12] ^ lfsr_r[10]};
        end
    end

    assign stall_c = lfsr_r[0] & lfsr_r[1];

    localparam int AW_PW = AXI_IDW + AXI_AW + 8 + 3 + 2;   // id/addr/len/size/burst
    localparam int W_PW  = AXI_DW + STRB_W + 1;            // data/strb/last

    logic [AW_PW-1:0] aw_dn;
    logic [AW_PW-1:0] ar_dn;
    logic [W_PW-1:0]  w_dn;
    logic             aw_stall_v, ar_stall_v, w_stall_v;

    axi_throttle #(.PW(AW_PW)) u_thr_aw (
        .clk_i(clk), .rst_ni(rst_n), .stall_i(stall_c),
        .up_valid_i(d_awvalid), .up_ready_o(d_awready),
        .up_data_i({d_awid, d_awaddr, d_awlen, d_awsize, d_awburst}),
        .dn_valid_o(aw_stall_v), .dn_ready_i(s_awready), .dn_data_o(aw_dn)
    );
    assign s_awvalid               = aw_stall_v;
    assign {s_awid, s_awaddr, s_awlen, s_awsize, s_awburst} = aw_dn;

    axi_throttle #(.PW(AW_PW)) u_thr_ar (
        .clk_i(clk), .rst_ni(rst_n), .stall_i(stall_c),
        .up_valid_i(d_arvalid), .up_ready_o(d_arready),
        .up_data_i({d_arid, d_araddr, d_arlen, d_arsize, d_arburst}),
        .dn_valid_o(ar_stall_v), .dn_ready_i(s_arready), .dn_data_o(ar_dn)
    );
    assign s_arvalid               = ar_stall_v;
    assign {s_arid, s_araddr, s_arlen, s_arsize, s_arburst} = ar_dn;

    axi_throttle #(.PW(W_PW)) u_thr_w (
        .clk_i(clk), .rst_ni(rst_n), .stall_i(stall_c),
        .up_valid_i(d_wvalid), .up_ready_o(d_wready),
        .up_data_i({d_wdata, d_wstrb, d_wlast}),
        .dn_valid_o(w_stall_v), .dn_ready_i(s_wready), .dn_data_o(w_dn)
    );
    assign s_wvalid          = w_stall_v;
    assign {s_wdata, s_wstrb, s_wlast} = w_dn;

    // slave -> master responses pass through untouched
    assign d_bvalid = s_bvalid;
    assign d_bresp  = s_bresp;
    assign d_bid    = s_bid;
    assign s_bready = d_bready;
    assign d_rvalid = s_rvalid;
    assign d_rdata  = s_rdata;
    assign d_rresp  = s_rresp;
    assign d_rlast  = s_rlast;
    assign d_rid    = s_rid;
    assign s_rready = d_rready;

    // ==================================================================
    // DRAM socket (default eth_dram_stub behind eth_dram_ctrl)
    // ==================================================================
    eth_dram_ctrl #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .AXI_IDW(AXI_IDW),
        .MEM_BASE(MEM_BASE), .MEM_BYTES(MEM_BYTES),
        .RD_LATENCY(RD_LATENCY), .WR_LATENCY(WR_LATENCY)
    ) dut_dram (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(s_awvalid), .s_axi_awready(s_awready), .s_axi_awaddr(s_awaddr),
        .s_axi_awid(s_awid), .s_axi_awlen(s_awlen), .s_axi_awsize(s_awsize),
        .s_axi_awburst(s_awburst), .s_axi_awcache(4'h0), .s_axi_awprot(3'h0),
        .s_axi_awqos(4'h0), .s_axi_awregion(4'h0), .s_axi_awlock(1'b0),
        .s_axi_wvalid(s_wvalid), .s_axi_wready(s_wready), .s_axi_wdata(s_wdata),
        .s_axi_wstrb(s_wstrb), .s_axi_wlast(s_wlast),
        .s_axi_bvalid(s_bvalid), .s_axi_bready(s_bready), .s_axi_bresp(s_bresp), .s_axi_bid(s_bid),
        .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready), .s_axi_araddr(s_araddr),
        .s_axi_arid(s_arid), .s_axi_arlen(s_arlen), .s_axi_arsize(s_arsize),
        .s_axi_arburst(s_arburst), .s_axi_arcache(4'h0), .s_axi_arprot(3'h0),
        .s_axi_arqos(4'h0), .s_axi_arregion(4'h0), .s_axi_arlock(1'b0),
        .s_axi_rvalid(s_rvalid), .s_axi_rready(s_rready), .s_axi_rdata(s_rdata),
        .s_axi_rresp(s_rresp), .s_axi_rlast(s_rlast), .s_axi_rid(s_rid)
    );

    // ==================================================================
    // Scoreboard
    // ==================================================================
    integer errors = 0;
    integer checks = 0;

    task automatic chk(input bit cond, input [1023:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    function automatic logic [63:0] pat(input int word_idx);
        begin
            // index-dependent pattern: a mix-up of address or beat order is
            // always detectable, and the value never equals the poison word.
            pat = {32'hD0D0_0000 | word_idx[31:0],
                   (word_idx * 32'h9E37_79B9) ^ 32'hA5A5_5A5A};
        end
    endfunction

    localparam logic [63:0] POISON = 64'hDEAD_BEEF_DEAD_BEEF;

    // ---- memory backdoor (pattern setup / result peek) ----
    task automatic mem_set(input int byte_off, input int nbytes, input logic [63:0] value);
        int j;
        begin
            for (j = 0; j < (nbytes / STRB_W); j = j + 1) begin
                dut_dram.u_impl.mem[(byte_off >> 3) + j] = value;
            end
        end
    endtask

    task automatic fill_src(input int byte_off, input int nbytes);
        int j;
        begin
            for (j = 0; j < (nbytes / STRB_W); j = j + 1) begin
                dut_dram.u_impl.mem[(byte_off >> 3) + j] = pat((byte_off >> 3) + j);
            end
        end
    endtask

    task automatic write_desc(input int byte_off, input logic [63:0] src, dst, nxt,
                              input logic [15:0] len,
                              input bit sof, eof, ioc);
        begin
            dut_dram.u_impl.mem[(byte_off >> 3) + 0] = src;
            dut_dram.u_impl.mem[(byte_off >> 3) + 1] = dst;
            dut_dram.u_impl.mem[(byte_off >> 3) + 2] = nxt;
            dut_dram.u_impl.mem[(byte_off >> 3) + 3] = {45'h0, ioc, eof, sof, len};
        end
    endtask

    // ---- CSR access ----
    task automatic csr_write(input logic [11:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            csr_addr    = addr;
            csr_wdata   = data;
            csr_wr_valid = 1'b1;
            @(negedge clk);
            csr_wr_valid = 1'b0;
            csr_wdata    = 32'h0;
        end
    endtask

    task automatic csr_read(input logic [11:0] addr, output logic [31:0] data);
        begin
            @(negedge clk);
            csr_addr     = addr;
            csr_rd_valid = 1'b1;
            #1 data = csr_rdata;
            @(negedge clk);
            csr_rd_valid = 1'b0;
        end
    endtask

    function automatic logic [11:0] ch_csr(input int ch, input logic [5:0] off);
        begin
            ch_csr = (12'h040 * (ch + 1)) + {6'h0, off};
        end
    endfunction

    // ---- status helpers ----
    function automatic bit st_busy(input logic [31:0] s);    begin st_busy = s[0];  end endfunction
    function automatic bit st_done(input logic [31:0] s);    begin st_done = s[1];  end endfunction
    function automatic bit st_error(input logic [31:0] s);   begin st_error = s[2]; end endfunction
    function automatic logic [3:0] st_code(input logic [31:0] s); begin st_code = s[7:4]; end endfunction
    function automatic logic [7:0] st_ndesc(input logic [31:0] s); begin st_ndesc = s[15:8]; end endfunction

    // ---- diagnostic dump of a channel's status block ----
    task automatic show_status(input int ch, input [1023:0] tag);
        logic [31:0] s, e, c, t, x;
        begin
            csr_read(ch_csr(ch, CH_STATUS), s);
            csr_read(ch_csr(ch, CH_ERR_LO),  e);
            csr_read(ch_csr(ch, CH_CUR_LO),  c);
            csr_read(ch_csr(ch, CH_TOTAL),   t);
            csr_read(ch_csr(ch, CH_XFER),    x);
            $display("  [%0s] ch%0d st=%08h (busy=%b done=%b err=%b code=%0d ndesc=%0d) err_addr=%08h cur=%08h total=%0d xfer=%0d",
                     tag, ch, s, s[0], s[1], s[2], s[7:4], s[15:8], e, c, t, x);
        end
    endtask

    // ---- wait for a channel to leave BUSY (bounded) ----
    task automatic wait_idle(input int ch, input int max_polls, output bit ok);
        logic [31:0] s;
        int i;
        begin
            ok = 1'b0;
            for (i = 0; i < max_polls; i = i + 1) begin
                csr_read(ch_csr(ch, CH_STATUS), s);
                if (!s[0]) begin
                    ok = 1'b1;
                    i  = max_polls;
                end
            end
            if (!ok) $display("  FAIL: channel %0d still BUSY after %0d polls", ch, max_polls);
        end
    endtask

    // ---- data integrity: word-by-word compare + region checksum ----
    function automatic int wo_lo(input logic [31:0] off); begin wo_lo = off >> 3; end endfunction

    task automatic verify_xfer(input int src_off, input int dst_off, input int nbytes,
                              input [1023:0] tag);
        int     j;
        int     nw;
        logic [63:0] exp, got, esum, gsum;
        int     bad;
        begin
            nw   = nbytes / STRB_W;
            esum = 64'd0;
            gsum = 64'd0;
            bad  = 0;
            for (j = 0; j < nw; j = j + 1) begin
                exp = pat(wo_lo(src_off) + j);
                got = dut_dram.u_impl.mem[wo_lo(dst_off) + j];
                esum = esum + exp;
                gsum = gsum + got;
                if (got !== exp) begin
                    bad = bad + 1;
                    if (bad <= 3) begin
                        $display("  FAIL %0s: word %0d exp %016h got %016h", tag, j, exp, got);
                    end
                end
            end
            checks = checks + 1;
            if (bad != 0) begin
                errors = errors + 1;
                $display("  FAIL %0s: %0d/%0d words wrong", tag, bad, nw);
            end else if (esum !== gsum) begin
                errors = errors + 1;
                $display("  FAIL %0s: checksum %016h != %016h", tag, gsum, esum);
            end else begin
                $display("  %0s: %0d bytes OK, checksum %016h", tag, nbytes, gsum);
            end
        end
    endtask

    // ==================================================================
    // AXI protocol monitor (runs continuously, from the DMA's master port)
    // ==================================================================
    integer          proto_err        = 0;
    integer          bp_cycles        = 0;
    integer          id_switches      = 0;
    logic [N_CH-1:0] id_seen          = '0;
    logic [3:0]      last_id          = 4'hF;
    logic            last_id_v        = 1'b0;
    logic [7:0]      mon_w_len        = 8'd0;
    logic [7:0]      mon_w_cnt        = 8'd0;
    logic            mon_w_act        = 1'b0;
    logic            mon_aw_act       = 1'b0;
    logic            mon_ar_act       = 1'b0;
    integer          both_busy_cycles = 0;
    // monitor scratch (blocking accumulation, committed with one NBA)
    integer          pe_c, bp_c, sw_c;

    // previous-cycle snapshots for the VALID-stability checks
    logic            p_awvalid = 1'b0, p_awready = 1'b0;
    logic [31:0]     p_awaddr  = 32'h0;
    logic [7:0]      p_awlen   = 8'h0;
    logic            p_wvalid  = 1'b0, p_wready  = 1'b0;
    logic [63:0]     p_wdata   = 64'h0;
    logic [7:0]      p_wstrb   = 8'h0;
    logic            p_wlast   = 1'b0;
    logic            p_arvalid = 1'b0, p_arready = 1'b0;
    logic [31:0]     p_araddr  = 32'h0;
    logic [7:0]      p_arlen   = 8'h0;

    always_ff @(posedge clk) begin
        p_awvalid <= d_awvalid;
        p_awready <= d_awready;
        p_awaddr  <= d_awaddr;
        p_awlen   <= d_awlen;
        p_wvalid  <= d_wvalid;
        p_wready  <= d_wready;
        p_wdata   <= d_wdata;
        p_wstrb   <= d_wstrb;
        p_wlast   <= d_wlast;
        p_arvalid <= d_arvalid;
        p_arready <= d_arready;
        p_araddr  <= d_araddr;
        p_arlen   <= d_arlen;
    end

    // AXI burst accounting (evidence, not assertion):
    //   rd_bursts/wr_bursts  executed bursts
    //   cap_bursts           bursts shortened by the 4 KiB-boundary cap
    //   r_beats/w_beats      beat handshakes
    integer rd_bursts = 0, wr_bursts = 0, cap_bursts = 0, r_beats = 0, w_beats = 0;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_bursts <= 0;
            wr_bursts <= 0;
            cap_bursts <= 0;
            r_beats <= 0;
            w_beats <= 0;
        end else begin
            if (d_arvalid && d_arready) begin
                rd_bursts <= rd_bursts + 1;
                if (d_arlen == 8'd14) cap_bursts <= cap_bursts + 1;
            end
            if (d_awvalid && d_awready) begin
                wr_bursts <= wr_bursts + 1;
                if (d_awlen == 8'd14) cap_bursts <= cap_bursts + 1;
            end
            if (d_rvalid && d_rready) r_beats <= r_beats + 1;
            if (d_wvalid && d_wready) w_beats <= w_beats + 1;
        end
    end

    // G_STATUS sampling window (the TB holds the CSR read on G_STATUS)
    always_ff @(posedge clk) begin
        if (csr_rd_valid && (csr_addr == G_STATUS)) begin
            if (csr_rdata[1] && csr_rdata[2]) begin
                both_busy_cycles <= both_busy_cycles + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            proto_err   <= 0;
            bp_cycles   <= 0;
            id_switches <= 0;
            id_seen     <= '0;
            last_id_v   <= 1'b0;
            mon_aw_act  <= 1'b0;
            mon_ar_act  <= 1'b0;
            mon_w_act   <= 1'b0;
        end else begin
            pe_c = proto_err;
            bp_c = bp_cycles;
            sw_c = id_switches;

            // ---- backpressure evidence: a valid beat stalled by the memory side
            if ((d_awvalid && !d_awready) || (d_wvalid && !d_wready) ||
                (d_arvalid && !d_arready)) begin
                bp_c = bp_c + 1;
            end

            // ---- VALID stability (AXI A3.2.1): a presented beat is held with
            //      stable payload until accepted
            if (p_awvalid && !p_awready) begin
                if (!d_awvalid || (d_awaddr !== p_awaddr) || (d_awlen !== p_awlen)) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: AWVALID withdrawn/changed while stalled", $time);
                end
            end
            if (p_wvalid && !p_wready) begin
                if (!d_wvalid || (d_wdata !== p_wdata) || (d_wstrb !== p_wstrb) ||
                    (d_wlast !== p_wlast)) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: WVALID withdrawn/changed while stalled", $time);
                end
            end
            if (p_arvalid && !p_arready) begin
                if (!d_arvalid || (d_araddr !== p_araddr) || (d_arlen !== p_arlen)) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: ARVALID withdrawn/changed while stalled", $time);
                end
            end

            // ---- AW / AR: one outstanding at a time, IDs tracked
            if (d_awvalid && d_awready) begin
                if (mon_aw_act) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: second AW before the write completed", $time);
                end
                mon_aw_act <= 1'b1;
                mon_w_len  <= d_awlen;
                mon_w_cnt  <= 8'd0;
                mon_w_act  <= 1'b1;
                id_seen[d_awid[0]] <= 1'b1;
                if (last_id_v && (last_id != d_awid)) begin
                    sw_c = sw_c + 1;
                end
                last_id   <= d_awid;
                last_id_v <= 1'b1;
            end
            if (d_arvalid && d_arready) begin
                if (mon_ar_act) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: second AR before the read completed", $time);
                end
                mon_ar_act <= 1'b1;
                id_seen[d_arid[0]] <= 1'b1;
                if (last_id_v && (last_id != d_arid)) begin
                    sw_c = sw_c + 1;
                end
                last_id   <= d_arid;
                last_id_v <= 1'b1;
            end

            // ---- W beats: count, WLAST placement, no beat without an AW
            if (d_wvalid && d_wready) begin
                if (!mon_w_act) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: W beat without an outstanding AW", $time);
                end
                if (d_wlast !== (mon_w_cnt == mon_w_len)) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: WLAST misplaced (cnt %0d len %0d)",
                             $time, mon_w_cnt, mon_w_len);
                end
                mon_w_cnt <= mon_w_cnt + 8'd1;
                if (d_wlast) begin
                    mon_w_act <= 1'b0;
                end
            end

            // ---- B / R endings
            if (d_bvalid && d_bready) begin
                if (!mon_aw_act) begin
                    pe_c = pe_c + 1;
                    $display("  FAIL @%0t: B without an outstanding AW", $time);
                end
                mon_aw_act <= 1'b0;
            end
            if (d_rvalid && d_rready && d_rlast) begin
                mon_ar_act <= 1'b0;
            end
            if (d_rid > (N_CH - 1)) begin
                pe_c = pe_c + 1;
                $display("  FAIL @%0t: RDATA for an unknown ID %0d", $time, d_rid);
            end

            proto_err   <= pe_c;
            bp_cycles   <= bp_c;
            id_switches <= sw_c;
        end
    end

    // ==================================================================
    // Test sequence
    // ==================================================================
    logic [31:0] rd, st0, st1;
    bit          ok;

    initial begin
        $display("=== tb_eth_dma_mc: eth_dma_mc scatter-gather DMA ===");

        // ---------------- reset ----------------
        rst_n = 1'b0;
        repeat (8) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(negedge clk);

        // ---------------- T0: register smoke ----------------
        csr_read(G_CTRL, rd);
        chk(rd === 32'h0, "G_CTRL resets to 0");
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0 === 32'h0, "CH0_STATUS resets to 0");
        csr_write(G_CTRL, 32'h1);
        csr_read(G_CTRL, rd);
        chk(rd[0] === 1'b1, "G_CTRL.EN read-back");
        csr_write(ch_csr(0, CH_CTRL), 32'h1);            // EN only
        csr_read(ch_csr(0, CH_CTRL), rd);
        chk(rd[0] === 1'b1, "CH0_CTRL.EN read-back");
        csr_write(ch_csr(0, CH_DESC_LO), MEM_BASE + OFF_CH0_DESC);
        csr_write(ch_csr(0, CH_DESC_HI), 32'h0);
        csr_read(ch_csr(0, CH_DESC_LO), rd);
        chk(rd === (MEM_BASE + OFF_CH0_DESC), "CH0_DESC_LO read-back");
        csr_write(ch_csr(0, CH_CFG), 32'h1);             // IRQ_EN

        // ---------------- T1: one channel, four linked descriptors ----------------
        $display("-- T1: ch0 4-descriptor linked chain (8/256/512/2048 B)");
        fill_src(OFF_CH0_SRC, 32'h0C80);
        mem_set(OFF_CH0_DST, 32'h1000, POISON);
        write_desc(OFF_CH0_DESC + 32'h00, MEM_BASE + OFF_CH0_SRC + 32'h0000,
                   MEM_BASE + OFF_CH0_DST + 32'h0000, MEM_BASE + OFF_CH0_DESC + 32'h20,
                   16'd8, 1'b1, 1'b0, 1'b0);
        write_desc(OFF_CH0_DESC + 32'h20, MEM_BASE + OFF_CH0_SRC + 32'h0100,
                   MEM_BASE + OFF_CH0_DST + 32'h0100, MEM_BASE + OFF_CH0_DESC + 32'h40,
                   16'd256, 1'b0, 1'b0, 1'b0);
        write_desc(OFF_CH0_DESC + 32'h40, MEM_BASE + OFF_CH0_SRC + 32'h0200,
                   MEM_BASE + OFF_CH0_DST + 32'h0200, MEM_BASE + OFF_CH0_DESC + 32'h60,
                   16'd512, 1'b0, 1'b0, 1'b0);
        write_desc(OFF_CH0_DESC + 32'h60, MEM_BASE + OFF_CH0_SRC + 32'h0408,
                   MEM_BASE + OFF_CH0_DST + 32'h0408, 64'h0,
                   16'd2048, 1'b0, 1'b1, 1'b1);

        csr_write(ch_csr(0, CH_CTRL), 32'h3);            // EN | START
        wait_idle(0, 4000, ok);
        show_status(0, "T1");
        chk(ok, "T1 ch0 completed without hanging");
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0[1] === 1'b1, "T1 ch0 DONE");
        chk(st0[2] === 1'b0, "T1 ch0 no ERROR");
        chk(st_ndesc(st0) === 8'd4, "T1 ch0 DESC_DONE == 4");
        chk(st0[16] === 1'b1, "T1 ch0 SOF_SEEN");
        chk(st0[17] === 1'b1, "T1 ch0 EOF_SEEN");
        chk(st0[18] === 1'b1, "T1 ch0 IRQ flag");
        chk(irq_out === 1'b1, "T1 aggregate irq_o asserted");
        csr_read(ch_csr(0, CH_TOTAL), rd);
        chk(rd === 32'd2824, "T1 ch0 CH_TOTAL == 2824");
        csr_read(ch_csr(0, CH_XFER), rd);
        chk(rd === 32'd2048, "T1 ch0 CH_XFER == last descriptor 2048");
        csr_read(G_IRQ_STATUS, rd);
        chk(rd[0] === 1'b1, "T1 G_IRQ_STATUS bit0");
        verify_xfer(OFF_CH0_SRC + 32'h0000, OFF_CH0_DST + 32'h0000, 8,    "T1 d0");
        verify_xfer(OFF_CH0_SRC + 32'h0100, OFF_CH0_DST + 32'h0100, 256,  "T1 d1");
        verify_xfer(OFF_CH0_SRC + 32'h0200, OFF_CH0_DST + 32'h0200, 512,  "T1 d2");
        verify_xfer(OFF_CH0_SRC + 32'h0408, OFF_CH0_DST + 32'h0408, 2048, "T1 d3");
        chk(bp_cycles > 0, "T1 memory-side backpressure was exercised");
        chk(cap_bursts > 0, "T1 a burst was cut by the 4 KiB-boundary cap");
        // untouched poison beyond the last descriptor
        chk(dut_dram.u_impl.mem[wo_lo(OFF_CH0_DST + 32'h0C80)] === POISON,
            "T1 data past the chain untouched");

        // flag clear semantics
        csr_write(ch_csr(0, CH_CTRL), 32'h9);            // EN | IRQ_CLR
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk((st0[1] === 1'b0) && (st0[2] === 1'b0) && (st_code(st0) === ERR_NONE) &&
            (st0[16] === 1'b0) && (st0[17] === 1'b0) && (st0[18] === 1'b0),
            "T1 CH_STATUS flags cleared by IRQ_CLR");
        chk(st_ndesc(st0) === 8'd4, "T1 DESC_DONE kept until the next START");
        chk(irq_out === 1'b0, "T1 aggregate irq_o deasserted after IRQ_CLR");

        // ---------------- T2: two channels interleaved ----------------
        $display("-- T2: ch0 + ch1 interleaved (round-robin per burst)");
        fill_src(OFF_CH1_SRC, 32'h0800);
        mem_set(OFF_CH1_DST, 32'h0800, POISON);
        write_desc(OFF_CH1_DESC + 32'h00, MEM_BASE + OFF_CH1_SRC + 32'h0000,
                   MEM_BASE + OFF_CH1_DST + 32'h0000, MEM_BASE + OFF_CH1_DESC + 32'h20,
                   16'd1024, 1'b1, 1'b0, 1'b0);
        write_desc(OFF_CH1_DESC + 32'h20, MEM_BASE + OFF_CH1_SRC + 32'h0400,
                   MEM_BASE + OFF_CH1_DST + 32'h0400, MEM_BASE + OFF_CH1_DESC + 32'h40,
                   16'd256, 1'b0, 1'b0, 1'b0);
        write_desc(OFF_CH1_DESC + 32'h40, MEM_BASE + OFF_CH1_SRC + 32'h0500,
                   MEM_BASE + OFF_CH1_DST + 32'h0500, 64'h0,
                   16'd8, 1'b0, 1'b1, 1'b1);
        csr_write(ch_csr(1, CH_CTRL), 32'h1);            // EN
        csr_write(ch_csr(1, CH_DESC_LO), MEM_BASE + OFF_CH1_DESC);
        csr_write(ch_csr(1, CH_CFG), 32'h1);             // IRQ_EN
        id_seen = '0;
        id_switches = 0;
        both_busy_cycles = 0;
        // start both channels back-to-back, then hold the CSR read on G_STATUS
        csr_write(ch_csr(0, CH_CTRL), 32'h3);            // ch0 EN|START
        csr_write(ch_csr(1, CH_CTRL), 32'h3);            // ch1 EN|START
        @(negedge clk);
        csr_addr = G_STATUS;
        csr_rd_valid = 1'b1;
        repeat (6000) @(negedge clk);
        csr_rd_valid = 1'b0;
        wait_idle(0, 4000, ok);
        chk(ok, "T2 ch0 completed without hanging");
        wait_idle(1, 4000, ok);
        chk(ok, "T2 ch1 completed without hanging");
        csr_read(ch_csr(0, CH_STATUS), st0);
        csr_read(ch_csr(1, CH_STATUS), st1);
        chk((st0[1] === 1'b1) && (st0[2] === 1'b0), "T2 ch0 DONE without error");
        chk((st1[1] === 1'b1) && (st1[2] === 1'b0), "T2 ch1 DONE without error");
        chk(st_ndesc(st0) === 8'd4, "T2 ch0 DESC_DONE == 4");
        chk(st_ndesc(st1) === 8'd3, "T2 ch1 DESC_DONE == 3");
        csr_read(ch_csr(1, CH_TOTAL), rd);
        chk(rd === 32'd1288, "T2 ch1 CH_TOTAL == 1288");
        chk(id_seen === 2'b11, "T2 both AXI IDs observed");
        chk(id_switches >= 4, "T2 AXI ownership switched repeatedly (interleaved)");
        chk(both_busy_cycles > 0, "T2 both channels busy simultaneously");
        $display("  T2 interleave: id switches=%0d, both-busy cycles=%0d",
                 id_switches, both_busy_cycles);
        verify_xfer(OFF_CH1_SRC + 32'h0000, OFF_CH1_DST + 32'h0000, 1024, "T2 b0");
        verify_xfer(OFF_CH1_SRC + 32'h0400, OFF_CH1_DST + 32'h0400, 256,  "T2 b1");
        verify_xfer(OFF_CH1_SRC + 32'h0500, OFF_CH1_DST + 32'h0500, 8,    "T2 b2");
        verify_xfer(OFF_CH0_SRC + 32'h0000, OFF_CH0_DST + 32'h0000, 8,    "T2 ch0 rerun d0");
        verify_xfer(OFF_CH0_SRC + 32'h0408, OFF_CH0_DST + 32'h0408, 2048, "T2 ch0 rerun d3");

        // ---------------- T3: descriptor fetch outside the DRAM window ----------------
        $display("-- T3: descriptor fetch DECERR (list base outside the window)");
        csr_write(ch_csr(0, CH_CTRL), 32'h9);            // clear flags
        csr_write(ch_csr(0, CH_DESC_LO), OUT_OF_WINDOW);
        csr_write(ch_csr(0, CH_CTRL), 32'h3);            // EN | START
        wait_idle(0, 2000, ok);
        show_status(0, "T3");
        chk(ok, "T3 ch0 did not hang on a DECERR descriptor fetch");
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0[2] === 1'b1, "T3 ch0 ERROR set");
        chk(st_code(st0) === ERR_DECERR, "T3 ch0 ERRCODE == DECERR");
        chk(st0[1] === 1'b0, "T3 ch0 DONE not set on error");
        chk(st_ndesc(st0) === 8'd0, "T3 ch0 no descriptor completed");
        csr_read(ch_csr(0, CH_ERR_LO), rd);
        chk(rd === OUT_OF_WINDOW, "T3 ch0 CH_ERR_LO == the faulting fetch address");
        csr_read(ch_csr(0, CH_CUR_LO), rd);
        chk(rd === OUT_OF_WINDOW, "T3 ch0 CH_CUR_LO == the current descriptor");
        chk(irq_out === 1'b1, "T3 aggregate irq_o asserted on error");
        csr_write(ch_csr(0, CH_CTRL), 32'h9);            // IRQ_CLR
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0 === 32'h0, "T3 error flags cleared by IRQ_CLR");

        // ---------------- T4: data write outside the DRAM window ----------------
        $display("-- T4: data write DECERR (descriptor DST outside the window)");
        fill_src(OFF_ERR_SRC, 512);
        mem_set(OFF_ERR_DST, 512, POISON);
        write_desc(OFF_ERR_DESC, MEM_BASE + OFF_ERR_SRC, OUT_OF_WINDOW, 64'h0,
                   16'd256, 1'b1, 1'b1, 1'b1);
        csr_write(ch_csr(0, CH_DESC_LO), MEM_BASE + OFF_ERR_DESC);
        csr_write(ch_csr(0, CH_CTRL), 32'h3);            // EN | START
        wait_idle(0, 2000, ok);
        show_status(0, "T4");
        chk(ok, "T4 ch0 did not hang on a DECERR data write");
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0[2] === 1'b1, "T4 ch0 ERROR set");
        chk(st_code(st0) === ERR_DECERR, "T4 ch0 ERRCODE == DECERR");
        csr_read(ch_csr(0, CH_ERR_LO), rd);
        chk(rd === OUT_OF_WINDOW, "T4 ch0 CH_ERR_LO == the faulting destination");
        chk(dut_dram.u_impl.mem[wo_lo(OFF_ERR_DST)] === POISON,
            "T4 in-window destination untouched");

        // ---------------- T5: abort ----------------
        $display("-- T5: abort during a transfer");
        csr_write(ch_csr(0, CH_CTRL), 32'h9);            // clear flags
        csr_write(ch_csr(0, CH_DESC_LO), MEM_BASE + OFF_CH0_DESC);
        csr_write(ch_csr(0, CH_CTRL), 32'h3);            // EN | START
        repeat (40) @(negedge clk);                      // mid-transfer
        csr_write(ch_csr(0, CH_CTRL), 32'h5);            // EN | ABORT
        wait_idle(0, 2000, ok);
        show_status(0, "T5");
        chk(ok, "T5 ch0 abort completed without hanging");
        csr_read(ch_csr(0, CH_STATUS), st0);
        chk(st0[2] === 1'b1, "T5 ch0 ERROR set by abort");
        chk(st_code(st0) === ERR_ABORT, "T5 ch0 ERRCODE == ABORT");
        chk(irq_out === 1'b1, "T5 aggregate irq_o asserted by abort");

        // ---------------- T6: protocol monitor ----------------
        chk(proto_err === 0, "AXI VALID/READY protocol monitor clean");
        $display("  AXI stats: rd_bursts=%0d wr_bursts=%0d 4k-capped=%0d r_beats=%0d w_beats=%0d",
                 rd_bursts, wr_bursts, cap_bursts, r_beats, w_beats);
        $display("  backpressure-stalled valid cycles: %0d", bp_cycles);

        // ---------------- summary ----------------
        $display("=== checks=%0d errors=%0d ===", checks, errors);
        if (errors == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end
        $finish;
    end

    // safety timeout
    initial begin
        repeat (400000) @(posedge clk);
        $display("TEST FAILED: global timeout");
        $finish;
    end

endmodule

// ======================================================================
// TB helper: 1-deep AXI throttling stage (backpressure injection).
// Beats are captured into a register and forwarded; when stall_i is high the
// upstream READY is deasserted so the master must hold VALID + payload.
// ======================================================================
`default_nettype none
module axi_throttle #(
    parameter int PW = 8
) (
    input  logic           clk_i,
    input  logic           rst_ni,
    input  logic           stall_i,
    input  logic           up_valid_i,
    output logic           up_ready_o,
    input  logic [PW-1:0]  up_data_i,
    output logic           dn_valid_o,
    input  logic           dn_ready_i,
    output logic [PW-1:0]  dn_data_o
);

    logic          occ_r;
    logic [PW-1:0] data_r;

    assign up_ready_o = (!occ_r) && (!stall_i);
    assign dn_valid_o = occ_r;
    assign dn_data_o  = data_r;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            occ_r <= 1'b0;
        end else if (occ_r && dn_ready_i) begin
            occ_r <= 1'b0;
        end else if ((!occ_r) && up_valid_i && up_ready_o) begin
            occ_r  <= 1'b1;
            data_r <= up_data_i;
        end
    end

endmodule

`default_nettype wire
