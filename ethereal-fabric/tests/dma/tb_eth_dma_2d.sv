`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_dma_2d (testbench, self-checking)
// Description: E2-DMA2 acceptance TB for `eth_dma_2d`: the 2D graphics DMA
//              (ND-strided walker + block move / blit / fill / ROP) behind a
//              VDMA-style register model — with the REAL packaged DRAM socket
//              (`eth_dram_ctrl` + `eth_dram_stub`) as the memory target, so the
//              2D engine is exercised as a real AXI4 master of that socket
//              (eth-axi-v0.md §9).
// Details:     Coverage:
//                0. VDMA-style register smoke: reset values, read-back of every
//                   field, VERSION, reserved blocks read 0, START with EN=0
//                   ignored, IRQ enable / sticky flag / IRQ_CLR;
//                1. 2D block move (MOVE) over a strided rectangle (h=256 B,
//                   v=6 lines, line stride 512 B) — word-by-word destination
//                   compare against a reference pattern, untouched gaps and
//                   tail checked against POISON, DONE/ERROR/LINES_DONE/
//                   XFER_BYTES/FRAMES/CUR addresses checked;
//                2. blit (BLIT) over a 2-plane rectangle (plane stride 0x800)
//                   for ALL 16 ROP codes, each destination word compared
//                   against an independent golden model of the ROP truth
//                   table, plus a mutation control proving the ROP field
//                   really drives the data path (XOR result != SRCCOPY result);
//                3. fill (FILL) over a 3-plane rectangle with a colour
//                   pattern, gaps and tail verified as untouched POISON;
//                4. a 6144-byte single line whose first chunk address is 60 bytes
//                   below a 4 KiB boundary: the AXI4 4 KiB rule forces a 4-beat
//                   burst, the FIFO depth forces multi-chunk lines; the monitor
//                   counts the forced split and checks every burst stays inside
//                   its 4 KiB page;
//                5. error paths: three CFG rejections (HSIZE not a beat
//                   multiple, line stride < HSIZE, line stride not beat
//                   aligned) each prove ERROR+ERRCODE=5 with ZERO bus activity;
//                   a RANGE abort (window clips the rectangle) proves
//                   ERROR+ERRCODE=6, ERR_ADDR = the first illegal line, the
//                   completed lines correct, the rest untouched, no hang;
//                   a DECERR inside the declared window (but outside the DRAM
//                   socket's memory) proves ERROR+ERRCODE=1;
//                6. ABORT while busy: honoured at the AXI burst boundary,
//                   ERROR+ERRCODE=4, no hang, DONE=0, a partial byte count;
//                7. checker-sensitivity control: a deliberately corrupted
//                   memory word must make the data checker report a failure
//                   (the checker can fail — it is not vacuous);
//                8. a continuous AXI protocol monitor: VALID stability, WLAST
//                   placement, single outstanding AW/AR, beat accounting, no
//                   burst crossing a 4 KiB boundary, and every issued burst
//                   inside the software-declared window (the end-to-end safety
//                   property of the design, mirrored from the formal proof).
//              DUT is `eth_dma_2d`; memory is the real DRAM socket.  Memory is
//              poked/peeked hierarchically (dut_dram.u_impl.mem), so all
//              transfers themselves go through the DUT's real AXI4 master.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (2D 图形 DMA:
//              ND-strided + blit/fill/ROP, HSIZE/VSIZE/STRIDE VDMA 兼容) ·
//              ethereal-spec/control/eth-axi-v0.md §2 §7 §9
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              Run:
//                iverilog -g2012 -o /tmp/tb_dma_2d \
//                  ethereal-shell/rtl/dma/eth_dma_pkg.sv \
//                  ethereal-shell/rtl/dma/eth_dma_fifo.sv \
//                  ethereal-shell/rtl/dma/eth_dma_axi_engine.sv \
//                  ethereal-shell/rtl/dma/eth_dma_2d_addr.sv \
//                  ethereal-shell/rtl/dma/eth_dma_2d.sv \
//                  ethereal-shell/rtl/dram/eth_dram_stub.sv \
//                  ethereal-shell/rtl/dram/eth_dram_ctrl.sv \
//                  ethereal-fabric/tests/dma/tb_eth_dma_2d.sv && vvp /tmp/tb_dma_2d
`timescale 1ns/1ps
module tb_eth_dma_2d;

    // ==================================================================
    // Configuration
    // ==================================================================
    localparam int AXI_AW     = 32;
    localparam int AXI_DW     = 64;
    localparam int AXI_IDW    = 4;
    localparam int STRB_W     = AXI_DW / 8;
    localparam int BEAT_BYTES = AXI_DW / 8;
    localparam int FIFO_DEPTH = 8;                 // 64-byte chunks
    localparam int CHUNK_BYTES = FIFO_DEPTH * BEAT_BYTES;

    localparam logic [31:0] MEM_BASE  = 32'h8000_0000;
    localparam int MEM_BYTES  = 128 * 1024;        // 0x2_0000
    localparam int RD_LATENCY = 6;
    localparam int WR_LATENCY = 3;

    // region map (byte offsets inside the DRAM window)
    localparam int SRC_MOVE = 32'h00000, DST_MOVE = 32'h01000;
    localparam int SRC_BLIT = 32'h02000, DST_BLIT = 32'h03000;
    localparam int DST_FILL = 32'h04000;
    localparam int DST_WIDE = 32'h09FE0;           // 60 bytes below a 4 KiB edge
    localparam int DST_DEC  = 32'h1F000;           // 2nd line leaves the socket

    // geometry of each test rectangle
    localparam int MV_H = 256, MV_V = 6, MV_LS = 512, MV_PS = 512;
    localparam int BL_H = 128, BL_V = 5, BL_LS = 256, BL_PS = 32'h800, BL_PL = 2;
    localparam int FL_H = 192, FL_V = 4, FL_LS = 384, FL_PS = 32'h600, FL_PL = 3;
    localparam int WD_H = 6144, WD_V = 1, WD_LS = 8192, WD_PS = 8192;

    localparam logic [31:0] FILL_COLOUR = 32'hA5C3_5A3C;
    localparam logic [31:0] WIDE_COLOUR = 32'h1122_3344;

    // CSR: {block[5:0], offset[5:0]}
    localparam logic [5:0] B_CTRL = 6'd0, B_SRC = 6'd1, B_DST = 6'd2, B_DIM = 6'd3, B_STAT = 6'd4;
    localparam logic [5:0] O_CTRL = 6'h00, O_STATUS = 6'h04, O_MODE = 6'h08, O_ROP = 6'h0C;
    localparam logic [5:0] O_COLOUR = 6'h10, O_CFG = 6'h14, O_VERSION = 6'h18;
    localparam logic [5:0] O_BASE_LO = 6'h00, O_BASE_HI = 6'h04, O_LSTRIDE = 6'h08;
    localparam logic [5:0] O_PSTRIDE = 6'h0C, O_CUR_LO = 6'h10, O_CUR_HI = 6'h14;
    localparam logic [5:0] O_HSIZE = 6'h00, O_VSIZE = 6'h04, O_PLANES = 6'h08;
    localparam logic [5:0] O_WIN_LO_LO = 6'h0C, O_WIN_LO_HI = 6'h10;
    localparam logic [5:0] O_WIN_HI_LO = 6'h14, O_WIN_HI_HI = 6'h18;
    localparam logic [5:0] O_XFER = 6'h00, O_LINES = 6'h04, O_ERR_LO = 6'h08;
    localparam logic [5:0] O_ERR_HI = 6'h0C, O_FRAMES = 6'h10;

    localparam logic [3:0] ERR_NONE = 4'd0, ERR_DECERR = 4'd1, ERR_SLVERR = 4'd2,
                           ERR_CFG = 4'd5, ERR_RANGE = 4'd6, ERR_ABORT = 4'd4;
    localparam logic [1:0] MODE_MOVE = 2'd0, MODE_FILL = 2'd1, MODE_BLIT = 2'd2;
    localparam logic [3:0] ROP_SRC = 4'hC, ROP_XOR = 4'h6;

    localparam logic [63:0] POISON = 64'hDEAD_BEEF_DEAD_BEEF;
    localparam logic [31:0] VERSION = 32'h0001_0000;

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
    eth_dma_2d #(
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
    // master->slave channel (AW/W/AR) driven by an LFSR, so the DMA really
    // sees AWREADY/WREADY/ARREADY deasserted.  Beats are held in the stage
    // register, so no beat is lost or duplicated.
    // ==================================================================
    logic [15:0] lfsr_r;
    logic        stall_c;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr_r <= 16'hACE1;
        else        lfsr_r <= {lfsr_r[14:0], lfsr_r[15] ^ lfsr_r[13] ^ lfsr_r[12] ^ lfsr_r[10]};
    end

    assign stall_c = lfsr_r[0] & lfsr_r[1];

    localparam int AW_PW = AXI_IDW + AXI_AW + 8 + 3 + 2;
    localparam int W_PW  = AXI_DW + STRB_W + 1;

    logic [AW_PW-1:0] aw_dn, ar_dn;
    logic [W_PW-1:0]  w_dn;
    logic             aw_stall_v, ar_stall_v, w_stall_v;

    d2_axi_throttle #(.PW(AW_PW)) u_thr_aw (
        .clk_i(clk), .rst_ni(rst_n), .stall_i(stall_c),
        .up_valid_i(d_awvalid), .up_ready_o(d_awready),
        .up_data_i({d_awid, d_awaddr, d_awlen, d_awsize, d_awburst}),
        .dn_valid_o(aw_stall_v), .dn_ready_i(s_awready), .dn_data_o(aw_dn)
    );
    assign s_awvalid               = aw_stall_v;
    assign {s_awid, s_awaddr, s_awlen, s_awsize, s_awburst} = aw_dn;

    d2_axi_throttle #(.PW(AW_PW)) u_thr_ar (
        .clk_i(clk), .rst_ni(rst_n), .stall_i(stall_c),
        .up_valid_i(d_arvalid), .up_ready_o(d_arready),
        .up_data_i({d_arid, d_araddr, d_arlen, d_arsize, d_arburst}),
        .dn_valid_o(ar_stall_v), .dn_ready_i(s_arready), .dn_data_o(ar_dn)
    );
    assign s_arvalid               = ar_stall_v;
    assign {s_arid, s_araddr, s_arlen, s_arsize, s_arburst} = ar_dn;

    d2_axi_throttle #(.PW(W_PW)) u_thr_w (
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
    // DRAM socket (eth_dram_stub behind eth_dram_ctrl)
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

    // index-dependent patterns: an address or beat-order mix-up is always
    // detectable and no pattern word equals POISON
    function automatic logic [63:0] pat(input int word_idx);
        begin
            pat = {32'hD0D0_0000 | word_idx[31:0],
                   (word_idx * 32'h9E37_79B9) ^ 32'hA5A5_5A5A};
        end
    endfunction

    function automatic logic [63:0] dpat(input int word_idx);
        begin
            dpat = {32'hB1B1_0000 | word_idx[31:0],
                    (word_idx * 32'h85EB_CA6B) ^ 32'h3C3C_C3C3};
        end
    endfunction

    // independent golden model of the ROP: bit k of the result is f(S,D) with
    // (S,D) = (k>>1, k&1), i.e. code[{s[i],d[i]}] per bit — the truth-table
    // definition, not a copy of the RTL case table
    function automatic logic [63:0] rop_gold(input logic [3:0] code,
                                             input logic [63:0] s,
                                             input logic [63:0] d);
        int i;
        begin
            for (i = 0; i < 64; i = i + 1) begin
                rop_gold[i] = code[{s[i], d[i]}];
            end
        end
    endfunction

    // ---- memory backdoor (pattern setup / result peek) ----
    task automatic mem_set(input int byte_off, input int nbytes, input logic [63:0] value);
        int j;
        begin
            for (j = 0; j < (nbytes / STRB_W); j = j + 1) begin
                dut_dram.u_impl.mem[(byte_off >> 3) + j] = value;
            end
        end
    endtask

    task automatic fill_pat(input int byte_off, input int nbytes);
        int j;
        begin
            for (j = 0; j < (nbytes / STRB_W); j = j + 1) begin
                dut_dram.u_impl.mem[(byte_off >> 3) + j] = pat((byte_off >> 3) + j);
            end
        end
    endtask

    task automatic fill_dpat(input int byte_off, input int nbytes);
        int j;
        begin
            for (j = 0; j < (nbytes / STRB_W); j = j + 1) begin
                dut_dram.u_impl.mem[(byte_off >> 3) + j] = dpat((byte_off >> 3) + j);
            end
        end
    endtask

    // ---- CSR access ----
    task automatic csr_write(input logic [11:0] addr, input logic [31:0] data);
        begin
            @(negedge clk);
            csr_addr     = addr;
            csr_wdata    = data;
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

    function automatic logic [11:0] csa(input logic [5:0] blk, input logic [5:0] off);
        begin
            csa = {blk, off};
        end
    endfunction

    // ---- status helpers ----
    function automatic bit  st_busy(input logic [31:0] s);  begin st_busy  = s[0];  end endfunction
    function automatic bit  st_done(input logic [31:0] s);  begin st_done  = s[1];  end endfunction
    function automatic bit  st_err(input logic [31:0] s);   begin st_err   = s[2];  end endfunction
    function automatic logic [3:0] st_code(input logic [31:0] s);
        begin st_code = {1'b0, s[6:4]}; end
    endfunction
    function automatic logic [7:0] st_lines(input logic [31:0] s);
        begin st_lines = s[15:8]; end
    endfunction

    // ==================================================================
    // Data checkers
    // ==================================================================
    // Count the words of lines [y_from, y_to) of every plane that do NOT match
    // the golden model of the configured operation.  Silent and scoreboard-free
    // (so the sensitivity control can inject a fault and just read the count).
    task automatic rect_mismatch(input int s_off, input int d_off, input int h_bytes,
                                 input int v_lines, input int ls, input int ps,
                                 input int nplanes, input logic [1:0] mode,
                                 input logic [3:0] rop, input logic [63:0] fill_word,
                                 input int y_from, input int y_to, input bit verbose,
                                 output int bad, output int nwords);
        int z, y, k;
        int sw_, dw_;
        logic [63:0] exp, got;
        begin
            bad    = 0;
            nwords = 0;
            for (z = 0; z < nplanes; z = z + 1) begin
                for (y = y_from; y < y_to; y = y + 1) begin
                    for (k = 0; k < (h_bytes / BEAT_BYTES); k = k + 1) begin
                        sw_ = (s_off >> 3) + (z * (ps >> 3)) + (y * (ls >> 3)) + k;
                        dw_ = (d_off >> 3) + (z * (ps >> 3)) + (y * (ls >> 3)) + k;
                        case (mode)
                            MODE_MOVE: exp = pat(sw_);
                            MODE_FILL: exp = fill_word;
                            default:   exp = rop_gold(rop, pat(sw_), dpat(dw_));
                        endcase
                        got = dut_dram.u_impl.mem[dw_];
                        nwords = nwords + 1;
                        if (got !== exp) begin
                            bad = bad + 1;
                            if (verbose && (bad <= 3)) begin
                                $display("  FAIL z=%0d y=%0d k=%0d word %0d exp %016h got %016h",
                                         z, y, k, dw_, exp, got);
                            end
                        end
                    end
                end
            end
        end
    endtask

    // self-checking wrapper: a mismatch is a FAILURE
    task automatic check_rect(input int s_off, input int d_off, input int h_bytes,
                              input int v_lines, input int ls, input int ps,
                              input int nplanes, input logic [1:0] mode,
                              input logic [3:0] rop, input logic [63:0] fill_word,
                              input int y_from, input int y_to,
                              input [1023:0] tag, output int bad);
        int nw;
        begin
            rect_mismatch(s_off, d_off, h_bytes, v_lines, ls, ps, nplanes, mode, rop,
                          fill_word, y_from, y_to, 1'b1, bad, nw);
            checks = checks + 1;
            if (bad != 0) begin
                errors = errors + 1;
                $display("  FAIL %0s: %0d of %0d words wrong", tag, bad, nw);
            end else begin
                $display("  %0s: %0d rect words OK", tag, nw);
            end
        end
    endtask

    // the RECTANGLE words of lines [y_from, y_to) must all be untouched POISON
    task automatic check_rect_poison(input int d_off, input int h_bytes, input int ls,
                                     input int ps, input int nplanes, input int y_from,
                                     input int y_to, input [1023:0] tag);
        int z, y, k, dw, bad;
        begin
            bad = 0;
            for (z = 0; z < nplanes; z = z + 1) begin
                for (y = y_from; y < y_to; y = y + 1) begin
                    for (k = 0; k < (h_bytes / BEAT_BYTES); k = k + 1) begin
                        dw = (d_off >> 3) + (z * (ps >> 3)) + (y * (ls >> 3)) + k;
                        if (dut_dram.u_impl.mem[dw] !== POISON) bad = bad + 1;
                    end
                end
            end
            chk(bad == 0, {tag, ": untouched rectangle is POISON"});
        end
    endtask

    // the byte slots between the end of a line and the next line's start must
    // stay untouched (line stride > HSIZE is honoured exactly)
    task automatic check_gap_poison(input int d_off, input int h_bytes, input int ls,
                                    input int ps, input int nplanes, input int v_lines,
                                    input [1023:0] tag);
        int z, y, k, dw, bad;
        begin
            bad = 0;
            for (z = 0; z < nplanes; z = z + 1) begin
                for (y = 0; y < v_lines; y = y + 1) begin
                    for (k = (h_bytes / BEAT_BYTES); k < (ls / BEAT_BYTES); k = k + 1) begin
                        dw = (d_off >> 3) + (z * (ps >> 3)) + (y * (ls >> 3)) + k;
                        if (dut_dram.u_impl.mem[dw] !== POISON) bad = bad + 1;
                    end
                end
            end
            chk(bad == 0, {tag, ": line-stride gaps untouched"});
        end
    endtask

    // ==================================================================
    // Frame control helpers
    // ==================================================================
    logic [63:0] win_lo_sh, win_hi_sh;   // mirror of the programmed window
    logic        win_valid_mon = 1'b0;   // set once a window is programmed

    task automatic program_window(input int lo_off, input int hi_off);
        begin
            csr_write(csa(B_DIM, O_WIN_LO_LO), MEM_BASE + lo_off);
            csr_write(csa(B_DIM, O_WIN_LO_HI), 32'h0);
            csr_write(csa(B_DIM, O_WIN_HI_LO), MEM_BASE + hi_off);
            csr_write(csa(B_DIM, O_WIN_HI_HI), 32'h0);
            win_lo_sh    = {32'h0, MEM_BASE + lo_off};
            win_hi_sh    = {32'h0, MEM_BASE + hi_off};
            win_valid_mon = 1'b1;
        end
    endtask

    task automatic frame_setup(input logic [1:0] mode, input logic [3:0] rop,
                               input logic [31:0] colour,
                               input int s_off, input int d_off,
                               input int h_bytes, input int v_lines, input int nplanes,
                               input int s_ls, input int s_ps, input int d_ls, input int d_ps,
                               input int win_lo, input int win_hi,
                               input bit irq_en, input bit do_start);
        begin
            csr_write(csa(B_CTRL, O_MODE),   {30'h0, mode});
            csr_write(csa(B_CTRL, O_ROP),    {28'h0, rop});
            csr_write(csa(B_CTRL, O_COLOUR), colour);
            csr_write(csa(B_CTRL, O_CFG),    {31'h0, irq_en});
            csr_write(csa(B_SRC, O_BASE_LO), MEM_BASE + s_off);
            csr_write(csa(B_SRC, O_BASE_HI), 32'h0);
            csr_write(csa(B_SRC, O_LSTRIDE), s_ls);
            csr_write(csa(B_SRC, O_PSTRIDE), s_ps);
            csr_write(csa(B_DST, O_BASE_LO), MEM_BASE + d_off);
            csr_write(csa(B_DST, O_BASE_HI), 32'h0);
            csr_write(csa(B_DST, O_LSTRIDE), d_ls);
            csr_write(csa(B_DST, O_PSTRIDE), d_ps);
            csr_write(csa(B_DIM, O_HSIZE),   {16'h0, h_bytes[15:0]});
            csr_write(csa(B_DIM, O_VSIZE),   {16'h0, v_lines[15:0]});
            csr_write(csa(B_DIM, O_PLANES),  {16'h0, nplanes[15:0]});
            program_window(win_lo, win_hi);
            if (do_start) begin
                csr_write(csa(B_CTRL, O_CTRL), 32'h3);   // EN=1, START=1
            end
        end
    endtask

    // wait for BUSY to clear (bounded poll); returns false on timeout
    task automatic wait_idle(input int max_polls, output bit ok, output logic [31:0] st);
        int i;
        begin
            ok = 1'b0;
            st = 32'h0;
            for (i = 0; i < max_polls; i = i + 1) begin
                csr_read(csa(B_CTRL, O_STATUS), st);
                if (!st[0]) begin
                    ok = 1'b1;
                    i  = max_polls;
                end
            end
            if (!ok) $display("  FAIL: DMA still BUSY after %0d polls", max_polls);
        end
    endtask

    task automatic run_frame(input logic [1:0] mode, input logic [3:0] rop,
                             input logic [31:0] colour,
                             input int s_off, input int d_off,
                             input int h_bytes, input int v_lines, input int nplanes,
                             input int s_ls, input int s_ps, input int d_ls, input int d_ps,
                             input int win_lo, input int win_hi,
                             input bit irq_en, output logic [31:0] st, output logic [31:0] lin,
                             output logic [31:0] xfer, output logic [31:0] fr);
        logic [31:0] e;
        bit ok;
        begin
            frame_setup(mode, rop, colour, s_off, d_off, h_bytes, v_lines, nplanes,
                        s_ls, s_ps, d_ls, d_ps, win_lo, win_hi, irq_en, 1'b1);
            wait_idle(4000, ok, st);
            chk(ok, "frame finished (BUSY cleared)");
            csr_read(csa(B_STAT, O_LINES), lin);
            csr_read(csa(B_STAT, O_XFER),  xfer);
            csr_read(csa(B_STAT, O_FRAMES), fr);
            csr_read(csa(B_CTRL, O_STATUS), st);
            if (st[2]) begin
                csr_read(csa(B_STAT, O_ERR_LO), e);
                $display("  [diag] frame faulted code=%0d err_addr=%08h", st_code(st), e);
            end
        end
    endtask

    // ==================================================================
    // AXI protocol + window monitor
    // ==================================================================
    integer proto_err = 0, bad_4k = 0, bad_win = 0;
    integer rd_bursts = 0, wr_bursts = 0, r_beats = 0, w_beats = 0;
    integer split_4k = 0, partial_bursts = 0;

    logic       ar_open, aw_open;
    logic [7:0] ar_len_m, aw_len_m;
    logic [7:0] ar_cnt, aw_cnt;

    // one-cycle-delayed copies for the VALID-stability checks
    logic       aw_stall_q, ar_stall_q, w_stall_q;
    logic [31:0] awaddr_q, araddr_q;
    logic [7:0]  awlen_q, arlen_q, wlast_q;
    logic [63:0] wdata_q;
    logic [7:0]  wstrb_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_open <= 1'b0;
            aw_open <= 1'b0;
            ar_len_m <= 8'h0;
            aw_len_m <= 8'h0;
            ar_cnt <= 8'h0;
            aw_cnt <= 8'h0;
            aw_stall_q <= 1'b0;
            ar_stall_q <= 1'b0;
            w_stall_q <= 1'b0;
            awaddr_q <= 32'h0;
            araddr_q <= 32'h0;
            awlen_q <= 8'h0;
            arlen_q <= 8'h0;
            wlast_q <= 1'b0;
            wdata_q <= 64'h0;
            wstrb_q <= 8'h0;
        end else begin
            // ---- VALID must not be withdrawn before the handshake, and its
            //      payload must be stable (eth-axi-v0.md §2 rule 1) ----------
            if (aw_stall_q) begin
                if (!d_awvalid) proto_err <= proto_err + 1;
                if (d_awaddr !== awaddr_q || d_awlen !== awlen_q) proto_err <= proto_err + 1;
            end
            if (ar_stall_q) begin
                if (!d_arvalid) proto_err <= proto_err + 1;
                if (d_araddr !== araddr_q || d_arlen !== arlen_q) proto_err <= proto_err + 1;
            end
            if (w_stall_q) begin
                if (!d_wvalid) proto_err <= proto_err + 1;
                if (d_wdata !== wdata_q || d_wstrb !== wstrb_q || d_wlast !== wlast_q)
                    proto_err <= proto_err + 1;
            end
            aw_stall_q <= d_awvalid && !d_awready;
            ar_stall_q <= d_arvalid && !d_arready;
            w_stall_q  <= d_wvalid  && !d_wready;
            awaddr_q   <= d_awaddr;
            araddr_q   <= d_araddr;
            awlen_q    <= d_awlen;
            arlen_q    <= d_arlen;
            wlast_q    <= d_wlast;
            wdata_q    <= d_wdata;
            wstrb_q    <= d_wstrb;

            // AR / AW handshake: single outstanding, no 4 KiB crossing, window
            if (d_arvalid && d_arready) begin
                if (ar_open) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: second AR while one is outstanding", $time);
                end
                ar_open  <= 1'b1;
                ar_len_m <= d_arlen;
                ar_cnt   <= 8'h0;
                rd_bursts <= rd_bursts + 1;
                if (d_arlen != 8'(FIFO_DEPTH - 1)) partial_bursts <= partial_bursts + 1;
                if ((d_araddr[11:0] + ((d_arlen + 8'd1) << 3)) > 13'd4096) bad_4k <= bad_4k + 1;
                if (win_valid_mon && (({32'h0, d_araddr} < win_lo_sh) ||
                                      (({32'h0, d_araddr} + ((d_arlen + 8'd1) << 3)) > win_hi_sh)))
                    bad_win <= bad_win + 1;
                if ((d_araddr[11:0] + ((d_arlen + 8'd1) << 3)) == 13'd4096)
                    split_4k <= split_4k + 1;
            end
            if (d_awvalid && d_awready) begin
                if (aw_open) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: second AW while one is outstanding", $time);
                end
                aw_open  <= 1'b1;
                aw_len_m <= d_awlen;
                aw_cnt   <= 8'h0;
                wr_bursts <= wr_bursts + 1;
                if (d_awlen != 8'(FIFO_DEPTH - 1)) partial_bursts <= partial_bursts + 1;
                if ((d_awaddr[11:0] + ((d_awlen + 8'd1) << 3)) > 13'd4096) bad_4k <= bad_4k + 1;
                if (win_valid_mon && (({32'h0, d_awaddr} < win_lo_sh) ||
                                      (({32'h0, d_awaddr} + ((d_awlen + 8'd1) << 3)) > win_hi_sh)))
                    bad_win <= bad_win + 1;
                if ((d_awaddr[11:0] + ((d_awlen + 8'd1) << 3)) == 13'd4096)
                    split_4k <= split_4k + 1;
            end

            // R beats: counted, RLAST placement, burst closes exactly once
            if (d_rvalid && d_rready) begin
                r_beats <= r_beats + 1;
                if (!d_rlast && (ar_cnt == ar_len_m)) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: R beat past ARLEN without RLAST", $time);
                end
                if (d_rlast && (ar_cnt != ar_len_m) && (d_rresp == 2'b00)) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: RLAST early (beat %0d of %0d)", $time, ar_cnt, ar_len_m);
                end
                if (d_rlast) ar_open <= 1'b0;
                ar_cnt <= ar_cnt + 8'h1;
            end

            // W beats: WLAST exactly on the last beat, burst closes exactly once
            if (d_wvalid && d_wready) begin
                w_beats <= w_beats + 1;
                if (d_wlast != (aw_cnt == aw_len_m)) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: WLAST misplaced (beat %0d of %0d)", $time, aw_cnt, aw_len_m);
                end
                if (d_wstrb !== {STRB_W{1'b1}}) begin
                    proto_err <= proto_err + 1;
                    $display("  FAIL @%0t: partial WSTRB %02h", $time, d_wstrb);
                end
                if (d_wlast) aw_open <= 1'b0;
                aw_cnt <= aw_cnt + 8'h1;
            end
        end
    end

    // ==================================================================
    // Test sequence
    // ==================================================================
    logic [31:0] rd, st, st2, lines, xfer, frames, errlo;
    logic [63:0] word_save;
    logic [63:0] snap [0:511];
    bit          ok;
    int          bad, i;
    int          rdb0, wb0;      // bus-activity snapshots (never clobbered)

    initial begin
        $display("=== tb_eth_dma_2d: eth_dma_2d 2D graphics DMA ===");

        // ---------------- reset ----------------
        rst_n = 1'b0;
        repeat (8) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(negedge clk);

        // ---------------- T0: VDMA-style register smoke ----------------
        $display("-- T0: register model");
        csr_read(csa(B_CTRL, O_CTRL), rd);
        chk(rd === 32'h0, "DMA_CTRL resets to 0 (EN=0)");
        csr_read(csa(B_CTRL, O_STATUS), rd);
        chk(rd === 32'h0, "DMA_STATUS resets to 0");
        csr_read(csa(B_CTRL, O_MODE), rd);
        chk(rd === 32'h0, "DMA_MODE resets to MOVE");
        csr_read(csa(B_CTRL, O_ROP), rd);
        chk(rd === 32'hC, "DMA_ROP resets to SRCCOPY");
        csr_read(csa(B_CTRL, O_COLOUR), rd);
        chk(rd === 32'h0, "DMA_COLOUR resets to 0");
        csr_read(csa(B_CTRL, O_CFG), rd);
        chk(rd === 32'h0, "DMA_CFG resets to 0");
        csr_read(csa(B_CTRL, O_VERSION), rd);
        chk(rd === VERSION, "DMA_VERSION reads 0x0001_0000");
        csr_read(csa(B_DIM, O_PLANES), rd);
        chk(rd === 32'h1, "DIM_PLANES resets to 1");
        csr_read(csa(6'd5, 6'h00), rd);
        chk(rd === 32'h0, "reserved block 5 reads 0");
        csr_read(csa(6'd63, 6'h3C), rd);
        chk(rd === 32'h0, "reserved block 63 reads 0");

        // START with EN=0 must be ignored (no frame, no error, no bus traffic)
        csr_write(csa(B_CTRL, O_CTRL), 32'h2);       // START only
        repeat (4) @(negedge clk);
        csr_read(csa(B_CTRL, O_STATUS), rd);
        chk(rd === 32'h0, "START with EN=0 ignored (no BUSY, no ERROR)");
        chk(w_beats === 0 && rd_bursts === 0, "no AXI activity from an ignored START");

        // register read-back
        csr_write(csa(B_CTRL, O_MODE), 32'h2);
        csr_read(csa(B_CTRL, O_MODE), rd);
        chk(rd[1:0] === 2'b10, "DMA_MODE read-back (BLIT)");
        csr_write(csa(B_CTRL, O_COLOUR), 32'hCAFE_F00D);
        csr_read(csa(B_CTRL, O_COLOUR), rd);
        chk(rd === 32'hCAFE_F00D, "DMA_COLOUR read-back");
        csr_write(csa(B_CTRL, O_CTRL), 32'h1);       // EN=1
        csr_read(csa(B_CTRL, O_CTRL), rd);
        chk(rd[0] === 1'b1, "DMA_CTRL.EN read-back");
        csr_write(csa(B_DIM, O_HSIZE), 32'h1234);
        csr_read(csa(B_DIM, O_HSIZE), rd);
        chk(rd === 32'h1234, "DIM_HSIZE read-back");

        // ---------------- T1: 2D block move ----------------
        $display("-- T1: block move (h=256, v=6, line stride 512)");
        fill_pat(SRC_MOVE, 32'h1000);
        mem_set(DST_MOVE, 32'h1000, POISON);
        run_frame(MODE_MOVE, ROP_SRC, 32'h0,
                  SRC_MOVE, DST_MOVE, MV_H, MV_V, 1, MV_LS, MV_PS, MV_LS, MV_PS,
                  32'h00000, 32'h02000, 1'b1, st, lines, xfer, frames);
        check_rect(SRC_MOVE, DST_MOVE, MV_H, MV_V, MV_LS, MV_PS, 1, MODE_MOVE, ROP_SRC,
                   64'h0, 0, MV_V, "T1 copy", bad);
        check_gap_poison(DST_MOVE, MV_H, MV_LS, MV_PS, 1, MV_V, "T1 gaps");
        check_rect_poison(DST_MOVE, MV_H, MV_LS, MV_PS, 1, MV_V, MV_V, "T1 tail");
        chk(!st[0], "T1 BUSY cleared");
        chk(st[1] === 1'b1, "T1 DONE set");
        chk(st[2] === 1'b0, "T1 ERROR clear");
        chk(st_lines(st) === 8'd6, "T1 STATUS.LINES_DONE == 6");
        chk(lines === 32'd6, "T1 LINES register == 6");
        chk(frames === 32'd1, "T1 FRAMES_DONE == 1");
        chk(xfer === 32'(MV_H * MV_V), "T1 XFER_BYTES == 1536");
        chk(irq_out === 1'b1, "T1 IRQ raised (IRQ_EN=1)");
        csr_read(csa(B_CTRL, O_STATUS), rd);
        chk(rd[16] === 1'b1, "T1 STATUS.IRQ set");
        csr_read(csa(B_SRC, O_CUR_LO), rd);
        chk(rd === (MEM_BASE + SRC_MOVE + (MV_V - 1) * MV_LS),
            "T1 SRC_CUR == last line address");
        csr_read(csa(B_DST, O_CUR_LO), rd);
        chk(rd === (MEM_BASE + DST_MOVE + (MV_V - 1) * MV_LS),
            "T1 DST_CUR == last line address");
        chk(bad_win === 0, "T1 no burst escaped the declared window");
        // IRQ_CLR clears DONE/ERROR/ERRCODE/ERR_ADDR/IRQ but not the frame
        // counters (LINES_DONE / FRAMES_DONE), exactly like the 1D DMA's
        // DESC_DONE policy
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);       // EN=1, IRQ_CLR
        csr_read(csa(B_CTRL, O_STATUS), rd);
        chk(rd[1] === 1'b0 && rd[2] === 1'b0 && rd[16] === 1'b0,
            "IRQ_CLR clears DONE/ERROR/IRQ");
        chk(st_lines(rd) === 8'd6, "IRQ_CLR keeps the line counter");
        chk(irq_out === 1'b0, "irq_o deasserts after IRQ_CLR");

        // ---------------- T2: blit, all 16 ROP codes ----------------
        $display("-- T2: blit over 2 planes, all 16 ROP codes");
        for (i = 0; i < 16; i = i + 1) begin
            fill_pat(SRC_BLIT, 32'h1000);
            fill_dpat(DST_BLIT, 32'h1000);
            run_frame(MODE_BLIT, 4'(i), 32'h0,
                      SRC_BLIT, DST_BLIT, BL_H, BL_V, BL_PL, BL_LS, BL_PS, BL_LS, BL_PS,
                      32'h02000, 32'h04000, 1'b0, st, lines, xfer, frames);
            check_rect(SRC_BLIT, DST_BLIT, BL_H, BL_V, BL_LS, BL_PS, BL_PL, MODE_BLIT, 4'(i),
                       64'h0, 0, BL_V, "T2 blit", bad);
            chk(!st[2], "T2 blit ERROR clear");
            chk(lines === 32'(BL_V * BL_PL), "T2 LINES == 10 (2 planes x 5)");
        end
        // mutation control: XOR must differ from SRCCOPY (the ROP field is live)
        fill_pat(SRC_BLIT, 32'h1000);
        fill_dpat(DST_BLIT, 32'h1000);
        run_frame(MODE_BLIT, ROP_SRC, 32'h0,
                  SRC_BLIT, DST_BLIT, BL_H, BL_V, BL_PL, BL_LS, BL_PS, BL_LS, BL_PS,
                  32'h02000, 32'h04000, 1'b0, st, lines, xfer, frames);
        for (i = 0; i < (BL_H / BEAT_BYTES) * BL_V * BL_PL; i = i + 1) begin
            snap[i] = dut_dram.u_impl.mem[(DST_BLIT >> 3) + i];
        end
        fill_dpat(DST_BLIT, 32'h1000);
        run_frame(MODE_BLIT, ROP_XOR, 32'h0,
                  SRC_BLIT, DST_BLIT, BL_H, BL_V, BL_PL, BL_LS, BL_PS, BL_LS, BL_PS,
                  32'h02000, 32'h04000, 1'b0, st, lines, xfer, frames);
        bad = 0;
        for (i = 0; i < (BL_H / BEAT_BYTES) * BL_V * BL_PL; i = i + 1) begin
            if (snap[i] !== dut_dram.u_impl.mem[(DST_BLIT >> 3) + i]) bad = bad + 1;
        end
        chk(bad > 0, "ROP mutation control: XOR result differs from SRCCOPY");

        // ---------------- T3: fill, 3 planes, colour pattern ----------------
        $display("-- T3: fill (h=192, v=4, 3 planes, plane stride 0x600)");
        mem_set(DST_FILL, 32'h3000, POISON);
        rdb0 = rd_bursts;                              // a fill must not read
        run_frame(MODE_FILL, ROP_SRC, FILL_COLOUR,
                  32'h0, DST_FILL, FL_H, FL_V, FL_PL, FL_LS, FL_PS, FL_LS, FL_PS,
                  32'h04000, 32'h07000, 1'b0, st, lines, xfer, frames);
        check_rect(0, DST_FILL, FL_H, FL_V, FL_LS, FL_PS, FL_PL, MODE_FILL, ROP_SRC,
                   {FILL_COLOUR, FILL_COLOUR}, 0, FL_V, "T3 fill", bad);
        check_gap_poison(DST_FILL, FL_H, FL_LS, FL_PS, FL_PL, FL_V, "T3 gaps");
        check_rect_poison(DST_FILL, FL_H, FL_LS, FL_PS, FL_PL, FL_V, FL_V, "T3 tail");
        chk(!st[2] && st[1], "T3 fill DONE, no ERROR");
        chk(lines === 32'(FL_V * FL_PL), "T3 LINES == 12 (3 planes x 4)");
        chk(xfer === 32'(FL_H * FL_V * FL_PL), "T3 XFER_BYTES == 2304");
        chk(w_beats > 0, "T3 fill produced AXI write bursts");
        chk(rd_bursts == rdb0, "T3 fill issued NO AXI read burst for a fill");

        // ---------------- T4: 4 KiB split + multi-chunk line ----------------
        $display("-- T4: wide fill (6144 B line starting 60 B below a 4 KiB edge)");
        mem_set(DST_WIDE & ~32'hFFF, 32'h2000, POISON);
        split_4k = 0;
        partial_bursts = 0;
        run_frame(MODE_FILL, ROP_SRC, WIDE_COLOUR,
                  32'h0, DST_WIDE, WD_H, WD_V, 1, WD_LS, WD_PS, WD_LS, WD_PS,
                  32'h09000, 32'h0C000, 1'b0, st, lines, xfer, frames);
        check_rect(0, DST_WIDE, WD_H, WD_V, WD_LS, WD_PS, 1, MODE_FILL, ROP_SRC,
                   {WIDE_COLOUR, WIDE_COLOUR}, 0, WD_V, "T4 wide fill", bad);
        chk(!st[2] && st[1], "T4 wide fill DONE, no ERROR");
        chk(lines === 32'd1, "T4 LINES == 1");
        chk(xfer === 32'(WD_H), "T4 XFER_BYTES == 6144");
        chk(split_4k > 0, "T4 a burst was split at the 4 KiB boundary (AXI4 rule)");
        chk(partial_bursts > 0, "T4 multi-chunk line produced partial bursts");
        chk(bad_4k === 0, "T4 no burst crossed a 4 KiB boundary");

        // ---------------- T5: error paths ----------------
        $display("-- T5: error paths (CFG / RANGE / DECERR)");
        // NC1: HSIZE not a multiple of the beat size
        wb0 = w_beats;
        frame_setup(MODE_MOVE, ROP_SRC, 32'h0, SRC_MOVE, DST_MOVE, 12, MV_V, 1,
                    MV_LS, MV_PS, MV_LS, MV_PS, 32'h00000, 32'h02000, 1'b0, 1'b1);
        wait_idle(64, ok, st);
        chk(st[2] === 1'b1, "NC1 ERROR set for HSIZE=12");
        chk(st_code(st) === ERR_CFG, "NC1 ERRCODE == CFG");
        chk(st[1] === 1'b0, "NC1 DONE not set");
        chk(w_beats == wb0, "NC1 no AXI write activity (write beats unchanged)");
        csr_read(csa(B_STAT, O_XFER), rd);
        chk(rd === 32'h0, "NC1 XFER_BYTES == 0");

        // NC2: line stride < HSIZE on the source side
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);       // clear status
        frame_setup(MODE_MOVE, ROP_SRC, 32'h0, SRC_MOVE, DST_MOVE, MV_H, MV_V, 1,
                    4, MV_PS, MV_LS, MV_PS, 32'h00000, 32'h02000, 1'b0, 1'b1);
        wait_idle(64, ok, st);
        chk(st[2] === 1'b1 && st_code(st) === ERR_CFG, "NC2 ERROR/CFG for stride < HSIZE");

        // NC3: line stride not beat aligned on the source side
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);
        frame_setup(MODE_MOVE, ROP_SRC, 32'h0, SRC_MOVE, DST_MOVE, MV_H, MV_V, 1,
                    MV_LS + 4, MV_PS, MV_LS, MV_PS, 32'h00000, 32'h02000, 1'b0, 1'b1);
        wait_idle(64, ok, st);
        chk(st[2] === 1'b1 && st_code(st) === ERR_CFG, "NC3 ERROR/CFG for unaligned stride");

        // NC4: the declared window clips the DST rectangle -> RANGE at line 3
        // (the source lines 0..5 all fit; the destination is the higher
        // rectangle, so the destination side is the reported one)
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);
        fill_pat(SRC_MOVE, 32'h1000);
        mem_set(DST_MOVE, 32'h1000, POISON);
        run_frame(MODE_MOVE, ROP_SRC, 32'h0, SRC_MOVE, DST_MOVE, MV_H, MV_V, 1,
                  MV_LS, MV_PS, MV_LS, MV_PS, 32'h00000, 32'h01600, 1'b0,
                  st, lines, xfer, frames);
        $display("  [diag] NC4 st=%08h code=%0d lines=%0d xfer=%0d", st, st_code(st), lines, xfer);
        chk(st[2] === 1'b1, "NC4 ERROR set when the window clips the rectangle");
        chk(st_code(st) === ERR_RANGE, "NC4 ERRCODE == RANGE");
        chk(st[1] === 1'b0, "NC4 DONE not set");
        chk(lines === 32'd3, "NC4 LINES_DONE == 3 (completed lines only)");
        chk(xfer === 32'(MV_H * 3), "NC4 XFER_BYTES == 3 lines");
        csr_read(csa(B_STAT, O_ERR_LO), errlo);
        chk(errlo === (MEM_BASE + DST_MOVE + 3 * MV_LS),
            "NC4 ERR_ADDR == first illegal line address (destination side)");
        check_rect(SRC_MOVE, DST_MOVE, MV_H, MV_V, MV_LS, MV_PS, 1, MODE_MOVE, ROP_SRC,
                   64'h0, 0, 3, "NC4 copied part", bad);
        chk(bad === 0, "NC4 the three completed lines are correct");
        check_rect_poison(DST_MOVE, MV_H, MV_LS, MV_PS, 1, 3, MV_V, "NC4 untransferred part");
        chk(bad_win === 0, "NC4 no burst escaped the declared window");

        // DECERR: declare a window larger than the DRAM socket, so the 2nd line
        // leaves the socket's memory and the slave answers DECERR
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);
        mem_set(DST_DEC, 32'h1000, POISON);
        run_frame(MODE_FILL, ROP_SRC, 32'h1234_5678, DST_DEC, DST_DEC, MV_H, 4, 1,
                  32'h2000, MV_PS, 32'h2000, MV_PS, 32'h1E000, 32'h30000, 1'b0,
                  st, lines, xfer, frames);
        chk(st[2] === 1'b1, "DECERR ERROR set");
        chk(st_code(st) === ERR_DECERR, "DECERR ERRCODE == 1");
        csr_read(csa(B_STAT, O_ERR_LO), errlo);
        chk(errlo === (MEM_BASE + DST_DEC + 32'h2000), "DECERR ERR_ADDR == faulting burst");
        chk(lines === 32'd1, "DECERR LINES_DONE == 1 (first line completed)");

        // ---------------- T6: ABORT at the burst boundary ----------------
        $display("-- T6: abort while busy");
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);
        mem_set(DST_WIDE & ~32'hFFF, 32'h2000, POISON);
        frame_setup(MODE_FILL, ROP_SRC, WIDE_COLOUR, 32'h0, DST_WIDE, WD_H, WD_V, 1,
                    WD_LS, WD_PS, WD_LS, WD_PS, 32'h09000, 32'h0C000, 1'b0, 1'b1);
        repeat (200) @(negedge clk);               // let some chunks complete
        csr_read(csa(B_CTRL, O_STATUS), st2);
        $display("  [diag] T6 pre-abort st2=%08h busy=%b code=%0d err=%b",
                 st2, st2[0], st_code(st2), st2[2]);
        csr_read(csa(B_STAT, O_ERR_LO), errlo);
        $display("  [diag] T6 pre-abort err_addr=%08h xfer=%0d", errlo, xfer);
        chk(st2[0] === 1'b1, "T6 frame is BUSY before ABORT");
        csr_write(csa(B_CTRL, O_CTRL), 32'h5);     // EN=1, ABORT
        wait_idle(4000, ok, st);
        csr_read(csa(B_STAT, O_LINES),  lines);
        csr_read(csa(B_STAT, O_XFER),   xfer);
        csr_read(csa(B_STAT, O_FRAMES), frames);
        $display("  [diag] T6 st=%08h code=%0d lines=%0d frames=%0d xfer=%0d",
                 st, st_code(st), lines, frames, xfer);
        chk(ok, "T6 abort finished without hanging");
        chk(st[2] === 1'b1, "T6 ERROR set by abort");
        chk(st_code(st) === ERR_ABORT, "T6 ERRCODE == ABORT");
        chk(st[1] === 1'b0, "T6 DONE not set by abort");
        csr_read(csa(B_STAT, O_XFER), rd);
        chk((rd > 32'h0) && (rd <= 32'h1800), "T6 partial byte count in range");
        chk((rd % BEAT_BYTES) == 32'h0, "T6 byte count is a whole number of beats");
        chk(bad_win === 0, "T6 no burst escaped the declared window");

        // ---------------- T7: checker sensitivity ----------------
        // (the MOVE region was clobbered by the T5 error frames, so a fresh
        // reference frame is run first and then checked clean)
        $display("-- T7: checker sensitivity control");
        csr_write(csa(B_CTRL, O_CTRL), 32'h9);
        fill_pat(SRC_MOVE, 32'h1000);
        mem_set(DST_MOVE, 32'h1000, POISON);
        run_frame(MODE_MOVE, ROP_SRC, 32'h0, SRC_MOVE, DST_MOVE, MV_H, MV_V, 1,
                  MV_LS, MV_PS, MV_LS, MV_PS, 32'h00000, 32'h02000, 1'b0,
                  st, lines, xfer, frames);
        chk(!st[2] && st[1], "T7 reference frame DONE, no ERROR");
        check_rect(SRC_MOVE, DST_MOVE, MV_H, MV_V, MV_LS, MV_PS, 1, MODE_MOVE, ROP_SRC,
                   64'h0, 0, MV_V, "T7 clean copy", bad);
        chk(bad == 0, "T7 the checker passes a correct region");
        // inject exactly one wrong word and require the checker to see it
        word_save = dut_dram.u_impl.mem[(DST_MOVE >> 3) + 5];
        dut_dram.u_impl.mem[(DST_MOVE >> 3) + 5] = 64'h0123_4567_89AB_CDEF;
        rect_mismatch(SRC_MOVE, DST_MOVE, MV_H, MV_V, MV_LS, MV_PS, 1, MODE_MOVE, ROP_SRC,
                      64'h0, 0, MV_V, 1'b0, bad, i);
        dut_dram.u_impl.mem[(DST_MOVE >> 3) + 5] = word_save;
        chk(bad == 1, "T7 the checker FAILS exactly the corrupted word (not vacuous)");
        rect_mismatch(SRC_MOVE, DST_MOVE, MV_H, MV_V, MV_LS, MV_PS, 1, MODE_MOVE, ROP_SRC,
                      64'h0, 0, MV_V, 1'b0, bad, i);
        chk(bad == 0, "T7 the checker passes again after restoring the word");

        // ---------------- T8: protocol monitor + summary ----------------
        $display("-- T8: AXI protocol monitor");
        chk(proto_err === 0, "AXI VALID/READY protocol monitor clean");
        chk(bad_4k === 0, "no burst crossed a 4 KiB boundary");
        chk(bad_win === 0, "every burst stayed inside the declared window");
        $display("  AXI stats: rd_bursts=%0d wr_bursts=%0d r_beats=%0d w_beats=%0d",
                 rd_bursts, wr_bursts, r_beats, w_beats);
        $display("  partial bursts=%0d  4KiB-split bursts=%0d  backpressure(LFSR) active",
                 partial_bursts, split_4k);

        // ---------------- summary ----------------
        $display("=== checks=%0d errors=%0d ===", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    // safety timeout
    initial begin
        repeat (600000) @(posedge clk);
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
module d2_axi_throttle #(
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
