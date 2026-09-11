`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_pkg
// Description: Frozen layout constants for the self-developed multi-channel
//              scatter-gather DMA `eth_dma_mc` (S15 §3 "多通道 DMA"): the
//              descriptor bit layout, the CSR register map and the error codes.
// Details:     This package is the SINGLE SOURCE OF TRUTH for the two wire
//              formats the DMA exposes to software; the module headers of
//              `eth_dma_mc` / `eth_dma_channel` restate them for the reader.
//
//              (1) DESCRIPTOR — 32 bytes = 4 x 64-bit words, 32-byte aligned,
//                  fetched by ONE INCR read burst of 4 beats (AXI_DW=64):
//
//                  byte  bits    field
//                  0x00  63:0    SRC   source byte address (64-bit)      [63:0]
//                  0x08  63:0    DST   destination byte address (64-bit) [63:0]
//                  0x10  63:0    NXT   next descriptor address, 0 = END   [63:0]
//                  0x18  15:0    LEN   transfer length in bytes
//                  0x18  16      SOF   start-of-frame marker (latched in status)
//                  0x18  17      EOF   end-of-frame => chain ends after this desc
//                  0x18  18      IOC   interrupt-on-completion of this desc
//                  0x18  19      RSVD  (must be 0)
//                  0x1A  23:20   RSVD
//                  0x1C  31:24   RSVD
//                  0x1C  63:32   RSVD
//
//                  v0 rules (each violation => DMA_ERR_DESC, no partial transfer
//                  of that descriptor): LEN != 0, LEN % (AXI_DW/8) == 0, SRC and
//                  DST aligned to AXI_DW/8 bytes, NXT 32-byte aligned.
//                  Addresses wider than the AXI_AW master port are truncated.
//
//              (2) CSR REGISTER MAP — 4 KiB window.  Address = {block[11:6],
//                  offset[5:0]}.  Block 0 is global; block (ch+1) is channel ch
//                  (so channel 0 sits at 0x040 and each channel owns 64 bytes).
//
//                  GLOBAL (block 0)
//                    +0x00 G_CTRL       RW  [0]   EN       global enable
//                    +0x04 G_STATUS     RO  [0]   BUSY_ANY
//                                            [N_CH:1] CH_BUSY (bit ch+1 = ch busy)
//                    +0x08 G_IRQ_STATUS RO  [N_CH-1:0] sticky ch irq flags
//                    +0x0C G_IRQ_EN     RO  [N_CH-1:0] per-ch irq enable mirror
//
//                  CHANNEL (block ch+1, base = 0x040*(ch+1))
//                    +0x00 CH_CTRL      RW/W1P [0] EN (RW), [1] START (W1P),
//                                             [2] ABORT (W1P), [3] IRQ_CLR (W1P)
//                    +0x04 CH_STATUS    RO  [0] BUSY, [1] DONE, [2] ERROR,
//                                             [7:4] ERRCODE, [15:8] DESC_DONE,
//                                             [16] SOF_SEEN, [17] EOF_SEEN,
//                                             [18] IRQ
//                    +0x08 CH_DESC_LO   RW  descriptor-list base [31:0]
//                    +0x0C CH_DESC_HI   RW  descriptor-list base [63:32]
//                    +0x10 CH_CUR_LO    RO  current descriptor address [31:0]
//                    +0x14 CH_CUR_HI    RO  current descriptor address [63:32]
//                    +0x18 CH_XFER      RO  bytes moved in the current descriptor
//                    +0x1C CH_TOTAL     RO  bytes moved since START (32-bit wrap)
//                    +0x20 CH_ERR_LO    RO  faulting address [31:0]
//                    +0x24 CH_ERR_HI    RO  faulting address [63:32]
//                    +0x28 CH_CFG       RW  [0] IRQ_EN per-channel irq enable
//                    +0x2C..0x3C reserved (read 0)
//
//                  START is honoured only while idle/idle-error and only when
//                  EN=1 and G_CTRL.EN=1 (writing EN and START together is
//                  allowed: EN takes effect the same cycle).  ABORT is deferred
//                  to the current AXI burst boundary.  IRQ_CLR clears DONE,
//                  ERROR, ERRCODE, SOF_SEEN, EOF_SEEN, IRQ.
//
//              The CSR port itself is a plain synchronous register bus
//              (wr_valid/addr/wdata + rd_valid/addr/rdata, ready always high on
//              this DMA) — an AXI4-Lite slave wrapper is a separate adapter, so
//              the DMA never owns a bus flavor.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, PKG
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (多通道 DMA:
//              描述符链表/散射聚集 src/dst/len/ctrl, SOF/EOF, IOC, 通道仲裁,
//              寄存器直驱 + SG 模式, 64 位地址, AXI4 主) ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §7 (全自研 DMA)
// Notes:       Layout frozen here so `ethereal-spec/control/` can cite it
//              verbatim; the parent task (E2-DMA1) reports the same tables.
package eth_dma_pkg;

    // The tables below are the ABI source of truth (reported verbatim to the
    // parent task for the `ethereal-spec/control/` freeze).  A given consumer
    // module reads only the subset it implements — e.g. `eth_dma_fifo` reads
    // none of them — so the whole table set sits under one documented
    // UNUSEDPARAM waiver rather than being duplicated per module (same
    // convention as ethereal-shell/rtl/emri/emri_pkg.sv).
    /* verilator lint_off UNUSEDPARAM */
    // ------------------------------------------------------------------
    // Descriptor layout (32 bytes = 4 x 64-bit words)
    // ------------------------------------------------------------------
    localparam int DESC_BYTES    = 32;          // power-of-two word count
    localparam int DESC_W        = DESC_BYTES * 8;   // 256 bits
    localparam int DESC_ALIGN    = 32;               // byte alignment
    localparam int DESC_ALIGN_LOG = 5;               // log2(DESC_ALIGN)
    localparam int DESC_SRC_LSB  = 0;                // word 0
    localparam int DESC_DST_LSB  = 64;               // word 1
    localparam int DESC_NXT_LSB  = 128;              // word 2
    localparam int DESC_LEN_LSB  = 192;              // word 3 bits [15:0]
    localparam int DESC_SOF_BIT  = 208;              // word 3 bit 16
    localparam int DESC_EOF_BIT  = 209;              // word 3 bit 17
    localparam int DESC_IOC_BIT  = 210;              // word 3 bit 18

    // ------------------------------------------------------------------
    // AXI response codes (IHI0022G §A3.4.3) as seen by the data mover
    // ------------------------------------------------------------------
    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

    // ------------------------------------------------------------------
    // Channel error codes (CH_STATUS.ERRCODE) — 0 means "no error"
    // ------------------------------------------------------------------
    localparam logic [3:0] DMA_ERR_NONE   = 4'd0;  // OK
    localparam logic [3:0] DMA_ERR_DECERR = 4'd1;  // AXI DECERR (address window)
    localparam logic [3:0] DMA_ERR_SLVERR = 4'd2;  // AXI SLVERR / protocol
    localparam logic [3:0] DMA_ERR_DESC   = 4'd3;  // malformed descriptor
    localparam logic [3:0] DMA_ERR_ABORT  = 4'd4;  // aborted by software

    // ------------------------------------------------------------------
    // CSR map
    // ------------------------------------------------------------------
    localparam int CSR_AW  = 12;                 // 4 KiB register window
    localparam int CSR_BLK_W = 6;                // 64-byte blocks
    localparam int CSR_OFF_W = 6;                // register offset in block

    localparam logic [CSR_BLK_W-1:0] CSR_BLK_GLOBAL = 6'd0;
    localparam logic [CSR_BLK_W-1:0] CSR_BLK_CH0    = 6'd1;

    // global block offsets
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_G_CTRL       = 6'h00;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_G_STATUS     = 6'h04;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_G_IRQ_STATUS = 6'h08;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_G_IRQ_EN     = 6'h0C;

    // per-channel block offsets
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_CTRL     = 6'h00;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_STATUS   = 6'h04;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_DESC_LO  = 6'h08;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_DESC_HI  = 6'h0C;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_CUR_LO   = 6'h10;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_CUR_HI   = 6'h14;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_XFER     = 6'h18;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_TOTAL    = 6'h1C;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_ERR_LO   = 6'h20;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_ERR_HI   = 6'h24;
    localparam logic [CSR_OFF_W-1:0] CSR_OFF_CH_CFG      = 6'h28;

    // CH_CTRL bit positions
    localparam int CH_CTRL_EN_LSB      = 0;
    localparam int CH_CTRL_START_BIT   = 1;
    localparam int CH_CTRL_ABORT_BIT   = 2;
    localparam int CH_CTRL_IRQ_CLR_BIT = 3;

    // CH_STATUS bit positions
    localparam int CH_ST_BUSY_BIT    = 0;
    localparam int CH_ST_DONE_BIT    = 1;
    localparam int CH_ST_ERROR_BIT   = 2;
    localparam int CH_ST_ERRCODE_LSB = 4;   // [6:4]
    localparam int CH_ST_DESCNT_LSB  = 8;   // [15:8]
    localparam int CH_ST_SOF_BIT     = 16;
    localparam int CH_ST_EOF_BIT     = 17;
    localparam int CH_ST_IRQ_BIT     = 18;

    // CH_CFG bit positions
    localparam int CH_CFG_IRQEN_BIT = 0;

    // ------------------------------------------------------------------
    // Response code -> channel error code
    // ------------------------------------------------------------------
    function automatic logic [3:0] dma_err_of_resp(input logic [1:0] resp);
        begin
            case (resp)
                AXI_RESP_OKAY:   dma_err_of_resp = DMA_ERR_NONE;
                AXI_RESP_SLVERR: dma_err_of_resp = DMA_ERR_SLVERR;
                AXI_RESP_DECERR: dma_err_of_resp = DMA_ERR_DECERR;
                default:         dma_err_of_resp = DMA_ERR_SLVERR;  // EXOKAY: illegal for this master
            endcase
        end
    endfunction

endpackage

`default_nettype wire
