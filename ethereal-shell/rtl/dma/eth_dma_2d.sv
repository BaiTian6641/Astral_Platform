`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_2d
// Description: 2D graphics DMA of the application-processor subsystem (S15 §3
//              "2D 图形 DMA `eth_dma_2d`"): an ND-strided (N <= 3) rectangle
//              walker (`eth_dma_2d_addr`) that streams whole lines through the
//              shared single-outstanding AXI4 master engine
//              (`eth_dma_axi_engine`, the same one `eth_dma_mc` uses) with a
//              VDMA-style register file and the three pixel operations of the
//              plan: block move, fill and blit (blit = move + ROP over
//              (source, destination)).
//
//  THE THREE OPERATIONS (DMA_MODE):
//      MOVE (0)  dst rectangle  <- src rectangle            (a 2D block move)
//      FILL (1)  dst rectangle  <- DMA_COLOUR (no source read at all)
//      BLIT (2)  dst rectangle  <- rop(src beat, dst beat)  (read-modify-write)
//      RSVD (3)  illegal -> DMA_ERR_CFG, no bus activity
//  ROP is used by BLIT only; MOVE and FILL ignore it.  The colour register is
//  used by FILL only.  Per line, the engine issues, in order:
//      MOVE : read src line-chunk -> FIFO_S, write dst line-chunk from FIFO_S
//      BLIT : read src chunk -> FIFO_S, read dst chunk -> FIFO_D,
//             merge (ROP) -> FIFO_W, write dst chunk from FIFO_W
//      FILL : generate colour beats -> FIFO_W, write dst chunk from FIFO_W
//  A line is split into chunks of
//      min(beats left in the line, FIFO_DEPTH, beats to the next 4 KiB
//          boundary of EITHER operand)
//  beats (AXI4 IHI0022G §A3.4.1 forbids a burst crossing 4 KiB), so the chunk
//  is bounded by one FIFO; the FIFOs are exact-sized, so a chunk never stalls
//  its own read burst (no credit bookkeeping).  This is why the pixel pipeline
//  is *chunked*, not a free-running pipeline: v0 SERIALISES the three AXI
//  phases per chunk (read, write) on a single outstanding transaction, exactly
//  like `eth_dma_channel` — the alternative (read+write pipelining) needs
//  credit-based FIFO accounting and is a v0.1 item (see NON-GOALS).
//
//  ADDRESS MODEL: addr(z, y) = base + z*plane_stride + y*line_stride, x (the
//  byte inside a line) contiguous from 0 to h_bytes-1; traversal x -> y -> z.
//  See `eth_dma_2d_addr` for the walk, the window guard and the N <= 3 limit.
//
//  REGISTER MAP (4 KiB CSR window; address = {block[11:6], offset[5:0]}, the
//  SAME block/offset discipline as `eth_dma_mc`; blocks 5..63 reserved, read 0).
//  Every field is restated in eth_dma_pkg.sv (CSR2D_*), the ABI source.
//
//    BLOCK 0 (0x000) — control, status, pixel operation
//      +0x00 DMA_CTRL    RW/W1P [0] EN (RW, "run"), W1P [1] START (one frame),
//                                [2] ABORT, [3] IRQ_CLR (clears DONE/ERROR/
//                                ERRCODE/ERR_ADDR/IRQ; the W1P bits read 0)
//      +0x04 DMA_STATUS  RO  [0] BUSY, [1] DONE, [2] ERROR, [6:4] ERRCODE,
//                            [15:8] lines done (low byte),
//                            [16] IRQ
//      +0x08 DMA_MODE    RW  [1:0] MODE (see above)
//      +0x0C DMA_ROP     RW  [3:0] ROP code (BLIT)
//      +0x10 DMA_COLOUR  RW  [31:0] fill colour / pattern (FILL)
//      +0x14 DMA_CFG     RW  [0] IRQ_EN (frame-done IRQ), [1] ERR_IRQ_EN
//      +0x18 DMA_VERSION RO  {major[31:16], minor[15:0]} = 0x0001_0000
//    BLOCK 1 (0x040) — source rectangle  (VDMA "MM2S" side; unused by FILL)
//      +0x00 SRC_BASE_LO   RW   +0x04 SRC_BASE_HI   RW   (VDMA START_ADDRESS)
//      +0x08 SRC_LINE_STRIDE  RW [31:0] bytes per line  (VDMA STRIDE)
//      +0x0C SRC_PLANE_STRIDE RW [31:0] bytes per plane
//      +0x10 SRC_CUR_LO / +0x14 SRC_CUR_HI  RO current line address
//    BLOCK 2 (0x080) — destination rectangle (VDMA "S2MM" side), identical
//                     offsets: DST_BASE_LO/HI, DST_LINE_STRIDE,
//                     DST_PLANE_STRIDE, DST_CUR_LO/HI
//    BLOCK 3 (0x0C0) — geometry and window guard (VDMA VSIZE/HSIZE)
//      +0x00 DIM_HSIZE  RW [15:0] bytes per line  (multiple of the beat size)
//      +0x04 DIM_VSIZE  RW [15:0] lines per plane
//      +0x08 DIM_PLANES RW [15:0] planes (z count)
//      +0x0C WIN_LO_LO / +0x10 WIN_LO_HI   RW  window guard lower bound
//      +0x14 WIN_HI_LO / +0x18 WIN_HI_HI   RW  window guard upper bound
//      ASSUMPTION: the window guard is MANDATORY (there is no "guard off" bit):
//      WIN_LO < WIN_HI <= 2**AXI_AW is part of the START contract, because the
//      rectangle's upper address bound cannot be derived from HSIZE/VSIZE/
//      STRIDE without a multiplier.  Fail-closed is the intended default.
//      (TBD, 2026-09-13)
//      ASSUMPTION: rectangle limits are HSIZE <= 65535 bytes (16-bit field,
//      a multiple of the beat size), VSIZE/PLANES <= 65535 (16-bit fields) and
//      src/dst rectangles that do not overlap (each chunk reads both operands
//      before writing it back, so an aliased blit has no defined order); the
//      plan fixes none of these.  (TBD, 2026-09-13)
//    BLOCK 4 (0x100) — counters
//      +0x00 XFER_BYTES  RO 32-bit byte count since START (wraps)
//      +0x04 LINES_DONE  RO [15:0] lines completed in this/current frame
//      +0x08 ERR_ADDR_LO / +0x0C ERR_ADDR_HI  RO faulting address
//      +0x10 FRAMES_DONE RO [15:0] frames completed since reset (wraps)
//
//  ERROR CODES (eth_dma_pkg): 0 none, 1 DECERR, 2 SLVERR, 5 CFG (illegal
//  geometry/stride/window or MODE), 6 RANGE (line outside the declared
//  window).  ERR_ADDR holds the first illegal line address (RANGE), the
//  address of the faulting burst (DECERR/SLVERR), 0 for CFG and ABORT.
//
//  SHADOW (DOUBLE-BUFFERED) FRAME PARAMETERS — VDMA-style: DMA_MODE, DMA_ROP,
//  DMA_COLOUR, every BASE/STRIDE, DIM_* and WIN_* are copied into shadow
//  registers at START, so CSR writes during a frame take effect at the NEXT
//  frame.  This is what makes the walker's "geometry stable during a frame"
//  contract a hardware guarantee rather than a software promise (asserted
//  under `ifdef FORMAL`), and it removes a real race (a mid-frame HSIZE write
//  would otherwise corrupt the line walk).  XFER_BYTES restarts at 0 at START.
//
//  START is honoured only in idle (BUSY=0) with EN=1, or when the same write
//  sets EN=1 (EN takes effect that cycle).  START with EN=0, or START while
//  busy, is IGNORED (no error, no bus activity) — the `eth_dma_mc` rule.
//  A START whose geometry is illegal reports ERROR + ERRCODE=CFG instead of
//  starting, and moves no data.  ABORT (or clearing EN while busy) is DEFERRED
//  to the current AXI burst boundary (the AXI master is never abandoned
//  mid-transaction) and reports ERROR + ERRCODE=ABORT; the frame is abandoned
//  with XFER/LINES_DONE holding the completed part.
//
//  NON-GOALS (v0, deliberately out of this vertical slice): alpha blending,
//  colour-space conversion and rotation (the S11 Service-Tile pixel pipeline,
//  not the DMA slice — the plan lists them as build options of the 2D engine
//  family); ternary/pattern ROPs (the ROP set here is the 16 two-operand
//  Boolean functions, see below); sub-beat rectangle edges (WSTRB is always all
//  ones; HSIZE/base/strides are beat-multiple); overlapping source and
//  destination rectangles (each chunk reads both operands before writing, so
//  an aliased blit has no defined order); read+write pipelining (one
//  outstanding AXI transaction); more than 3 dimensions (see
//  eth_dma_2d_addr); an AXI4-Stream side; and the CSR is a plain valid/ready
//  register bus (an AXI4-Lite shell is a separate adapter, as for
//  `eth_dma_mc`).
//
//  ASSUMPTION: the ROP SET is the 16 two-operand Boolean functions below; the
//  plan names "ROP/blend/rotation build options" without fixing the set, and
//  ternary (pattern) ROPs / blending are deliberately left to the S11 pixel
//  pipeline.  (TBD, 2026-09-13)
//
//  ROP DEFINITION (documented because the plan does not fix the set): ROP[3:0]
//  is the truth table of a two-operand Boolean function evaluated bitwise
//  across the whole beat, with bit k = f(S, D) for S = k>>1, D = k&1
//  (S = source beat, D = destination beat).  Written MSB-first that is
//  f(1,1) f(1,0) f(0,1) f(0,0), i.e. exactly the low nibble of a BitBlt ROP3
//  code whose value is independent of the pattern operand (BitBlt names in
//  parentheses): 0x0 blackness, 0x1 (NOTSRCERASE), 0x2 (D & ~S), 0x3
//  NOTSRCCOPY, 0x4 (SRCERASE), 0x5 DSTINVERT, 0x6 SRCINVERT, 0x7 (NAND),
//  0x8 SRCAND, 0x9 (XNOR), 0xA DSTCOPY, 0xB MERGEPAINT, 0xC SRCCOPY,
//  0xD (S | ~D), 0xE SRCPAINT, 0xF whiteness.
//  ASSUMPTION: the ROP is applied to the WHOLE AXI beat because every Boolean
//  op is bitwise; pixel granularity does not enter the DMA at all (a 16-bit
//  RGB565 pixel is handled correctly for free, a sub-byte pixel is not
//  addressable — that would need a shift/mask stage, which is a pixel-pipeline
//  feature, not an address feature). (TBD, 2026-09-13)
//  ASSUMPTION: DMA_COLOUR is a 32-bit PATTERN, replicated AXI_DW/32 times
//  across the beat (so AXI_DW must be a multiple of 32, checked at elaboration).
//  The DMA never interprets the pixel format: for a pixel narrower than 32 bits
//  software pre-replicates it (RGB565 0xA53C -> 0xA53C_A53C), for a 32-bit
//  pixel it sets the colour directly.  This keeps a colour-format table out of
//  the DMA (the integrating SoC owns formats, as it owns the memory map).
//  (TBD, 2026-09-13)
//  ASSUMPTION: strides are 32-bit fields (VDMA-compatible width); a line or
//  plane stride >= 4 GiB is out of scope.  (TBD, 2026-09-13)
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (2D 图形 DMA:
//              ND-strided 地址引擎 + 自研 SV blit/fill/ROP 级; HSIZE/VSIZE/
//              STRIDE VDMA 兼容; ~3-8K + 1-3K LUT) ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §7 ·
//              ethereal-spec/control/eth-axi-v0.md §2 §7 §9
// Notes:       iverilog -g2012 compatible (two-segment FSM, no procedural loops
//              in always_*, sized literals, `default_nettype none`).  Reuses
//              `eth_dma_axi_engine` (hence AXI_AW >= 12, AXI_DW a multiple of
//              32, FIFO_DEPTH a power of two <= 256).  Formal window property:
//              ethereal-shell/formal/eth_dma_2d.sby.
module eth_dma_2d #(
    parameter int AXI_AW     = 32,      // AXI4 master address width (>= 12)
    parameter int AXI_DW     = 64,      // AXI4 master data width (multiple of 32)
    parameter int AXI_IDW    = 4,       // AXI4 transaction ID width
    parameter int FIFO_DEPTH = 16       // per-FIFO depth in beats (power of two)
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- CSR register bus (same contract as eth_dma_mc) ----
    input  logic                    csr_wr_valid_i,
    output logic                    csr_wr_ready_o,
    input  logic                    csr_rd_valid_i,
    output logic                    csr_rd_ready_o,
    input  logic [11:0]             csr_addr_i,
    input  logic [31:0]             csr_wdata_i,
    output logic [31:0]             csr_rdata_o,
    // ---- interrupt (level; cleared by DMA_CTRL.IRQ_CLR) ----
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

    // ------------------------------------------------------------------
    // Derived sizes / constants
    // ------------------------------------------------------------------
    localparam int BEAT_BYTES    = AXI_DW / 8;
    localparam int LOG_BEAT      = $clog2(BEAT_BYTES);
    localparam int COLOUR_COPIES = AXI_DW / 32;              // >= 1 (checked below)
    localparam logic [15:0] FIFO_BEATS = 16'(FIFO_DEPTH);
    localparam logic [64:0] AXI_LIMIT  = 65'(1) << AXI_AW;   // 2**AXI_AW, 65-bit
    localparam logic [AXI_IDW-1:0] TX_ID = {AXI_IDW{1'b0}};  // one master, one ID
    localparam logic [63:0] ZERO64 = 64'h0;

    typedef enum logic [3:0] {
        ST_IDLE  = 4'd0,
        ST_LINE  = 4'd1,     // start of a line: guard + chunk plan
        ST_RD_S  = 4'd2,     // read the source chunk into FIFO_S
        ST_RD_D  = 4'd3,     // read the destination chunk into FIFO_D (BLIT)
        ST_MERGE = 4'd4,     // FIFO_S/FIFO_D -> ROP -> FIFO_W (BLIT)
        ST_FILL  = 4'd5,     // colour beats -> FIFO_W (FILL)
        ST_WR    = 4'd6,     // write the chunk out of FIFO_W (or FIFO_S, MOVE)
        ST_CHEND = 4'd7,     // chunk done: next chunk, or step the line
        ST_ERR   = 4'd8      // abandon: flush the FIFOs, report, go idle
    } dma2d_state_e;

    // ------------------------------------------------------------------
    // CSR address decode
    // ------------------------------------------------------------------
    logic [5:0] csr_blk;
    logic [5:0] csr_off;

    assign csr_blk = csr_addr_i[11:6];
    assign csr_off = csr_addr_i[5:0];

    // ------------------------------------------------------------------
    // Programmed (software-visible) registers
    // ------------------------------------------------------------------
    logic        en_r,          en_nxt;
    logic [1:0]  mode_r,        mode_nxt;
    logic [3:0]  rop_r,         rop_nxt;
    logic [31:0] colour_r,      colour_nxt;
    logic        irq_en_r,      irq_en_nxt;
    logic        err_irq_en_r,  err_irq_en_nxt;

    logic [63:0] s_base_r,      s_base_nxt;
    logic [31:0] s_lstride_r,   s_lstride_nxt;
    logic [31:0] s_pstride_r,   s_pstride_nxt;
    logic [63:0] d_base_r,      d_base_nxt;
    logic [31:0] d_lstride_r,   d_lstride_nxt;
    logic [31:0] d_pstride_r,   d_pstride_nxt;

    logic [15:0] h_bytes_r,     h_bytes_nxt;
    logic [15:0] v_lines_r,     v_lines_nxt;
    logic [15:0] planes_r,      planes_nxt;
    logic [63:0] win_lo_r,      win_lo_nxt;
    logic [63:0] win_hi_r,      win_hi_nxt;

    // frame shadows (sampled at START — VDMA double buffering)
    logic [63:0] sf_base_r,     sf_base_nxt;
    logic [63:0] sf_ls_r,       sf_ls_nxt;
    logic [63:0] sf_ps_r,       sf_ps_nxt;
    logic [63:0] df_base_r,     df_base_nxt;
    logic [63:0] df_ls_r,       df_ls_nxt;
    logic [63:0] df_ps_r,       df_ps_nxt;
    logic [15:0] hf_bytes_r,    hf_bytes_nxt;
    logic [15:0] vf_lines_r,    vf_lines_nxt;
    logic [15:0] pf_r,          pf_nxt;
    logic [63:0] wlof_r,        wlof_nxt;
    logic [63:0] whif_r,        whif_nxt;
    logic [1:0]  mode_f_r,      mode_f_nxt;
    logic [3:0]  rop_f_r,       rop_f_nxt;
    logic [31:0] colour_f_r,    colour_f_nxt;

    // ------------------------------------------------------------------
    // Status / counters
    // ------------------------------------------------------------------
    logic        done_r,        done_nxt;
    logic        err_r,         err_nxt;
    logic [3:0]  errcode_r,     errcode_nxt;
    logic        irq_flag_r,    irq_flag_nxt;
    logic [63:0] err_addr_r,    err_addr_nxt;
    logic [31:0] total_r,       total_nxt;
    logic [15:0] frames_r,      frames_nxt;
    logic [15:0] lines_r,       lines_nxt;     // lines completed since START

    // ------------------------------------------------------------------
    // Engine working state
    // ------------------------------------------------------------------
    dma2d_state_e  state_r,     state_nxt;
    logic [15:0]   chunk_r,     chunk_nxt;
    logic [15:0]   boff_r,      boff_nxt;      // beats done in the current line
    logic [63:0]   csr_s_r,     csr_s_nxt;     // current chunk address (source)
    logic [63:0]   csr_d_r,     csr_d_nxt;     // current chunk address (dest)
    logic          tx_busy_r,   tx_busy_nxt;   // an AXI transaction is in flight
    logic [63:0]   cta_r,       cta_nxt;       // address of the in-flight burst
    logic [15:0]   mcnt_r,      mcnt_nxt;      // beat counter inside ST_MERGE
    logic [15:0]   fcnt_r,      fcnt_nxt;      // beat counter inside ST_FILL
    logic          abort_r,     abort_nxt;     // deferred abort request

    // ------------------------------------------------------------------
    // CSR write strobes and commands
    // ------------------------------------------------------------------
    logic wr_ctrl_c, wr_cfg_c, wr_mode_c, wr_rop_c, wr_colour_c;
    logic wr_src_c, wr_dst_c, wr_dim_c;

    assign wr_ctrl_c   = csr_wr_valid_i && (csr_blk == eth_dma_pkg::CSR2D_BLK_CTRL);
    assign wr_cfg_c    = wr_ctrl_c && (csr_off == eth_dma_pkg::CSR2D_OFF_CFG);
    assign wr_mode_c   = wr_ctrl_c && (csr_off == eth_dma_pkg::CSR2D_OFF_MODE);
    assign wr_rop_c    = wr_ctrl_c && (csr_off == eth_dma_pkg::CSR2D_OFF_ROP);
    assign wr_colour_c = wr_ctrl_c && (csr_off == eth_dma_pkg::CSR2D_OFF_COLOUR);
    assign wr_src_c    = csr_wr_valid_i && (csr_blk == eth_dma_pkg::CSR2D_BLK_SRC);
    assign wr_dst_c    = csr_wr_valid_i && (csr_blk == eth_dma_pkg::CSR2D_BLK_DST);
    assign wr_dim_c    = csr_wr_valid_i && (csr_blk == eth_dma_pkg::CSR2D_BLK_DIM);

    logic wr_ctrl_reg_c;    // write to DMA_CTRL (the command register itself)
    logic start_req_c, start_c, cfg_bad_c, abort_req_c, irq_clr_c, en_clear_c;
    logic start_d_r, start_d_nxt;   // one cycle after START: the walkers arm

    assign wr_ctrl_reg_c = wr_ctrl_c && (csr_off == eth_dma_pkg::CSR2D_OFF_CTRL);
    assign irq_clr_c     = wr_ctrl_reg_c && csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_IRQCLR_BIT];
    assign abort_req_c   = wr_ctrl_reg_c && csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_ABORT_BIT];
    assign en_clear_c    = wr_ctrl_reg_c && !csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_EN_BIT] &&
                           en_r;

    // START is honoured only when idle and enabled; writing EN and START in one
    // access is legal (EN takes effect that cycle), exactly as in eth_dma_mc.
    assign start_req_c = wr_ctrl_reg_c &&
                         csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_START_BIT] &&
                         (en_r || csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_EN_BIT]) &&
                         (state_r == ST_IDLE) && !start_d_r;

    // ------------------------------------------------------------------
    // START-time configuration check (illegal geometry never reaches the bus)
    // ------------------------------------------------------------------
    logic cfg_ok_c;

    always_comb begin
        cfg_ok_c = 1'b1;
        if (mode_r == eth_dma_pkg::DMA2D_MODE_RSVD)  cfg_ok_c = 1'b0;
        if (h_bytes_r == 16'h0)                      cfg_ok_c = 1'b0;
        if (h_bytes_r[LOG_BEAT-1:0] != {LOG_BEAT{1'b0}}) cfg_ok_c = 1'b0;
        if (v_lines_r == 16'h0)                      cfg_ok_c = 1'b0;
        if (planes_r  == 16'h0)                      cfg_ok_c = 1'b0;
        if (|d_base_r[LOG_BEAT-1:0])                 cfg_ok_c = 1'b0;
        if (|d_lstride_r[LOG_BEAT-1:0])              cfg_ok_c = 1'b0;
        if (d_lstride_r < {16'h0, h_bytes_r})        cfg_ok_c = 1'b0;
        if ((planes_r > 16'd1) && (|d_pstride_r[LOG_BEAT-1:0])) cfg_ok_c = 1'b0;
        if (mode_r != eth_dma_pkg::DMA2D_MODE_FILL) begin
            if (|s_base_r[LOG_BEAT-1:0])             cfg_ok_c = 1'b0;
            if (|s_lstride_r[LOG_BEAT-1:0])          cfg_ok_c = 1'b0;
            if (s_lstride_r < {16'h0, h_bytes_r})    cfg_ok_c = 1'b0;
            if ((planes_r > 16'd1) && (|s_pstride_r[LOG_BEAT-1:0])) cfg_ok_c = 1'b0;
        end
        if ({1'b0, win_lo_r} >= {1'b0, win_hi_r})    cfg_ok_c = 1'b0;
        if ({1'b0, win_hi_r} > AXI_LIMIT)            cfg_ok_c = 1'b0;
    end

    assign start_c   = start_req_c &&  cfg_ok_c;
    assign cfg_bad_c = start_req_c && !cfg_ok_c;

    // ------------------------------------------------------------------
    // Address walkers (one per operand rectangle)
    // ------------------------------------------------------------------
    logic        src_run_c,  src_safe_c, src_done_c, src_fault_c;
    logic [63:0] src_line_addr_c;
    logic        dst_run_c,  dst_safe_c, dst_done_c, dst_fault_c;
    logic [63:0] dst_line_addr_c;
    logic        start_src_c, line_step_c, gen_abort_c;

    // START samples the frame parameters into the shadow registers; the walkers
    // are armed ONE CYCLE LATER, so they always load the shadowed base/window
    // (arming them in the START cycle would sample the previous frame's shadow)
    assign start_src_c = start_d_r && (mode_f_r != eth_dma_pkg::DMA2D_MODE_FILL);

    eth_dma_2d_addr #(
        .AXI_AW (AXI_AW)
    ) u_gen_src (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .base_i         (sf_base_r),
        .line_stride_i  (sf_ls_r),
        .plane_stride_i (sf_ps_r),
        .h_bytes_i      (hf_bytes_r),
        .v_lines_i      (vf_lines_r),
        .planes_i       (pf_r),
        .win_lo_i       (wlof_r),
        .win_hi_i       (whif_r),
        .start_i        (start_src_c),
        .step_i         (line_step_c),
        .abort_i        (gen_abort_c),
        .run_o          (src_run_c),
        .safe_o         (src_safe_c),
        .line_addr_o    (src_line_addr_c),
        .done_o         (src_done_c),
        .fault_o        (src_fault_c)
    );

    eth_dma_2d_addr #(
        .AXI_AW (AXI_AW)
    ) u_gen_dst (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .base_i         (df_base_r),
        .line_stride_i  (df_ls_r),
        .plane_stride_i (df_ps_r),
        .h_bytes_i      (hf_bytes_r),
        .v_lines_i      (vf_lines_r),
        .planes_i       (pf_r),
        .win_lo_i       (wlof_r),
        .win_hi_i       (whif_r),
        .start_i        (start_d_r),
        .step_i         (line_step_c),
        .abort_i        (gen_abort_c),
        .run_o          (dst_run_c),
        .safe_o         (dst_safe_c),
        .line_addr_o    (dst_line_addr_c),
        .done_o         (dst_done_c),
        .fault_o        (dst_fault_c)
    );

    // mode-masked walker views: FILL has no source side at all, and the two
    // walkers of a MOVE/BLIT frame are driven by the same start/step pulses, so
    // they are always in the same state (only a fault can desynchronise them,
    // and it is checked first).
    logic src_used_c, gen_run_c, gen_done_c, gen_safe_c, gen_fault_c;
    logic [63:0] gen_bad_addr_c;

    assign src_used_c    = (mode_f_r != eth_dma_pkg::DMA2D_MODE_FILL);
    assign gen_run_c     = src_used_c ? (src_run_c  && dst_run_c)  : dst_run_c;
    assign gen_done_c    = src_used_c ? (src_done_c && dst_done_c) : dst_done_c;
    assign gen_safe_c    = src_used_c ? (src_safe_c && dst_safe_c) : dst_safe_c;
    assign gen_fault_c   = src_used_c ? (src_fault_c || dst_fault_c) : dst_fault_c;
    assign gen_bad_addr_c = (src_used_c && !src_safe_c) ? src_line_addr_c : dst_line_addr_c;

    // ------------------------------------------------------------------
    // Chunk plan: beats left in the line, FIFO capacity, 4 KiB boundaries
    // ------------------------------------------------------------------
    function automatic logic [15:0] lim_4k(input logic [11:0] a_lo);
        logic [12:0] rem;
        begin
            rem    = 13'd4096 - {1'b0, a_lo};
            lim_4k = {3'b0, rem} >> LOG_BEAT;
        end
    endfunction

    function automatic logic [15:0] min16(input logic [15:0] a, input logic [15:0] b);
        begin
            min16 = (a < b) ? a : b;
        end
    endfunction

    logic [15:0] beats_line_c, beats_left_c, lim_s_c, lim_d_c, chunk_c;
    logic [63:0] boff_bytes_c, src_chunk_addr_c, dst_chunk_addr_c;
    logic        line_end_c;

    assign boff_bytes_c     = {48'h0, boff_r} << LOG_BEAT;
    assign src_chunk_addr_c = src_line_addr_c + boff_bytes_c;
    assign dst_chunk_addr_c = dst_line_addr_c + boff_bytes_c;
    assign beats_line_c     = hf_bytes_r >> LOG_BEAT;
    assign beats_left_c     = beats_line_c - boff_r;
    assign lim_s_c          = src_used_c ? lim_4k(src_chunk_addr_c[11:0]) : FIFO_BEATS;
    assign lim_d_c          = lim_4k(dst_chunk_addr_c[11:0]);
    assign chunk_c          = min16(min16(beats_left_c, FIFO_BEATS),
                                    min16(lim_s_c, lim_d_c));
    assign line_end_c       = ((boff_r + chunk_r) == beats_line_c);

    // ------------------------------------------------------------------
    // ROP: two-operand Boolean function, bitwise across the beat
    // ------------------------------------------------------------------
    function automatic logic [AXI_DW-1:0] rop_apply(input logic [3:0]      code,
                                                    input logic [AXI_DW-1:0] s,
                                                    input logic [AXI_DW-1:0] d);
        begin
            case (code)
                4'h0:    rop_apply = {AXI_DW{1'b0}};    // 0000 zero
                4'h1:    rop_apply = ~(s | d);          // 0001 NOTSRCERASE
                4'h2:    rop_apply = ~s & d;            // 0010 D & NOT S
                4'h3:    rop_apply = ~s;                // 0011 NOTSRCCOPY
                4'h4:    rop_apply = s & ~d;            // 0100 SRCERASE
                4'h5:    rop_apply = ~d;                // 0101 DSTINVERT
                4'h6:    rop_apply = s ^ d;             // 0110 SRCINVERT
                4'h7:    rop_apply = ~(s & d);          // 0111 NAND
                4'h8:    rop_apply = s & d;             // 1000 SRCAND
                4'h9:    rop_apply = ~(s ^ d);          // 1001 XNOR
                4'hA:    rop_apply = d;                 // 1010 DSTCOPY
                4'hB:    rop_apply = ~s | d;            // 1011 MERGEPAINT
                4'hC:    rop_apply = s;                 // 1100 SRCCOPY
                4'hD:    rop_apply = s | ~d;            // 1101 S OR NOT D
                4'hE:    rop_apply = s | d;             // 1110 SRCPAINT
                default: rop_apply = {AXI_DW{1'b1}};    // 1111 one / whiteness
            endcase
        end
    endfunction

    // fill pattern: the 32-bit colour register replicated across the beat
    logic [AXI_DW-1:0] fill_beat_c;

    generate
        for (genvar g = 0; g < COLOUR_COPIES; g++) begin : g_fill
            assign fill_beat_c[32*g +: 32] = colour_f_r;
        end
    endgenerate

    // ------------------------------------------------------------------
    // Data path: three FWFT FIFOs and their handshakes
    // ------------------------------------------------------------------
    logic               fifo_s_wr_valid, fifo_s_wr_ready, fifo_s_rd_valid, fifo_s_rd_ready;
    logic [AXI_DW-1:0]  fifo_s_rd_data;
    logic               fifo_d_wr_valid, fifo_d_wr_ready, fifo_d_rd_valid, fifo_d_rd_ready;
    logic [AXI_DW-1:0]  fifo_d_rd_data;
    logic               fifo_w_wr_valid, fifo_w_wr_ready, fifo_w_rd_valid, fifo_w_rd_ready;
    logic [AXI_DW-1:0]  fifo_w_wr_data,  fifo_w_rd_data;

    logic [1:0] eng_tx_resp;
    logic [AXI_DW-1:0] eng_rd_data, eng_wr_data;
    logic               eng_tx_ready, eng_tx_done, eng_rd_valid, eng_rd_ready;
    logic               eng_wr_valid, eng_wr_ready;

    // flush: at START (idle) and in the abandon state — the FIFOs are empty
    // at both points, so the synchronous clear can never drop a live beat
    logic flush_c;

    assign flush_c = (state_r == ST_ERR) || ((state_r == ST_IDLE) && start_c);

    assign fifo_s_wr_valid = eng_rd_valid && (state_r == ST_RD_S);
    assign fifo_d_wr_valid = eng_rd_valid && (state_r == ST_RD_D);
    assign eng_rd_ready    = (state_r == ST_RD_S) ? fifo_s_wr_ready :
                             (state_r == ST_RD_D) ? fifo_d_wr_ready : 1'b0;

    // a chunk is at most FIFO_DEPTH beats, so the read burst always fits
    logic merge_pop_c, fill_push_c, wr_pop_c;

    assign merge_pop_c = (state_r == ST_MERGE) && (mcnt_r < chunk_r) &&
                         fifo_s_rd_valid && fifo_d_rd_valid && fifo_w_wr_ready;
    assign fill_push_c = (state_r == ST_FILL) && (fcnt_r < chunk_r) && fifo_w_wr_ready;
    assign wr_pop_c    = (state_r == ST_WR) && eng_wr_ready;

    assign fifo_w_wr_valid = (state_r == ST_MERGE) ? merge_pop_c : fill_push_c;
    assign fifo_w_wr_data  = (state_r == ST_MERGE) ?
                             rop_apply(rop_f_r, fifo_s_rd_data, fifo_d_rd_data) :
                             fill_beat_c;
    assign fifo_s_rd_ready = (state_r == ST_MERGE) ? merge_pop_c :
                             ((state_r == ST_WR) && (mode_f_r == eth_dma_pkg::DMA2D_MODE_MOVE)) ?
                             wr_pop_c : 1'b0;
    assign fifo_d_rd_ready = (state_r == ST_MERGE) ? merge_pop_c : 1'b0;
    assign fifo_w_rd_ready = ((state_r == ST_WR) &&
                              (mode_f_r != eth_dma_pkg::DMA2D_MODE_MOVE)) ? wr_pop_c : 1'b0;

    // the write stream comes from FIFO_S for MOVE and from FIFO_W otherwise
    assign eng_wr_valid = (state_r == ST_WR) &&
                          ((mode_f_r == eth_dma_pkg::DMA2D_MODE_MOVE) ?
                           fifo_s_rd_valid : fifo_w_rd_valid);
    assign eng_wr_data  = (mode_f_r == eth_dma_pkg::DMA2D_MODE_MOVE) ?
                          fifo_s_rd_data : fifo_w_rd_data;

    // Three exact-sized FWFT buffers: one per in-flight operand chunk.  A chunk
    // is at most FIFO_DEPTH beats, so a read burst always fits its FIFO and a
    // write burst always finds exactly its beats — no credit accounting.
    eth_dma_fifo #(
        .DW    (AXI_DW),
        .DEPTH (FIFO_DEPTH)
    ) u_fifo_s (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   (flush_c),
        .wr_valid_i(fifo_s_wr_valid),
        .wr_ready_o(fifo_s_wr_ready),
        .wr_data_i (eng_rd_data),
        .rd_valid_o(fifo_s_rd_valid),
        .rd_ready_i(fifo_s_rd_ready),
        .rd_data_o (fifo_s_rd_data)
    );

    eth_dma_fifo #(
        .DW    (AXI_DW),
        .DEPTH (FIFO_DEPTH)
    ) u_fifo_d (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   (flush_c),
        .wr_valid_i(fifo_d_wr_valid),
        .wr_ready_o(fifo_d_wr_ready),
        .wr_data_i (eng_rd_data),
        .rd_valid_o(fifo_d_rd_valid),
        .rd_ready_i(fifo_d_rd_ready),
        .rd_data_o (fifo_d_rd_data)
    );

    eth_dma_fifo #(
        .DW    (AXI_DW),
        .DEPTH (FIFO_DEPTH)
    ) u_fifo_w (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   (flush_c),
        .wr_valid_i(fifo_w_wr_valid),
        .wr_ready_o(fifo_w_wr_ready),
        .wr_data_i (fifo_w_wr_data),
        .rd_valid_o(fifo_w_rd_valid),
        .rd_ready_i(fifo_w_rd_ready),
        .rd_data_o (fifo_w_rd_data)
    );
    // ------------------------------------------------------------------
    // AXI transaction request to the shared engine
    // ------------------------------------------------------------------
    logic        tx_req_c, tx_op_c, tx_accept_c;
    logic        req_valid_r, req_valid_nxt;
    logic [AXI_AW-1:0] tx_addr_c;
    logic [7:0]  tx_len_c;

    // The request is a ONE-SHOT register (the `eth_dma_channel` pattern): armed
    // when the FSM enters a transaction state, disarmed in the cycle the engine
    // accepts it.  A state-derived request would still be asserted in the
    // tx_done cycle, where the engine is idle again -- and would be accepted as
    // a second, spurious burst.
    assign tx_req_c  = req_valid_r;
    assign tx_op_c   = (state_r == ST_WR);
    assign tx_addr_c = ((state_r == ST_RD_D) || (state_r == ST_WR)) ?
                       csr_d_r[AXI_AW-1:0] : csr_s_r[AXI_AW-1:0];
    assign tx_len_c  = 8'(chunk_r - 16'd1);
    assign tx_accept_c = tx_req_c && eng_tx_ready;

    function automatic logic tx_state_f(input dma2d_state_e st);
        begin
            tx_state_f = (st == ST_RD_S) || (st == ST_RD_D) || (st == ST_WR);
        end
    endfunction

    // ------------------------------------------------------------------
    // FSM + CSR next-state (combinational segment; defaults first)
    // ------------------------------------------------------------------
    always_comb begin
        // ---- programmed registers hold unless written ----
        en_nxt         = en_r;
        mode_nxt       = mode_r;
        rop_nxt        = rop_r;
        colour_nxt     = colour_r;
        irq_en_nxt     = irq_en_r;
        err_irq_en_nxt = err_irq_en_r;
        s_base_nxt     = s_base_r;
        s_lstride_nxt  = s_lstride_r;
        s_pstride_nxt  = s_pstride_r;
        d_base_nxt     = d_base_r;
        d_lstride_nxt  = d_lstride_r;
        d_pstride_nxt  = d_pstride_r;
        h_bytes_nxt    = h_bytes_r;
        v_lines_nxt    = v_lines_r;
        planes_nxt     = planes_r;
        win_lo_nxt     = win_lo_r;
        win_hi_nxt     = win_hi_r;

        if (wr_ctrl_reg_c) begin
            en_nxt = csr_wdata_i[eth_dma_pkg::DMA2D_CTRL_EN_BIT];   // W1P bits ignored
        end
        if (wr_mode_c)   mode_nxt   = csr_wdata_i[1:0];
        if (wr_rop_c)    rop_nxt    = csr_wdata_i[3:0];
        if (wr_colour_c) colour_nxt = csr_wdata_i;
        if (wr_cfg_c) begin
            irq_en_nxt     = csr_wdata_i[eth_dma_pkg::DMA2D_CFG_IRQEN_BIT];
            err_irq_en_nxt = csr_wdata_i[eth_dma_pkg::DMA2D_CFG_ERRIRQEN_BIT];
        end
        if (wr_src_c) begin
            case (csr_off)
                eth_dma_pkg::CSR2D_OFF_BASE_LO: s_base_nxt    = {s_base_r[63:32], csr_wdata_i};
                eth_dma_pkg::CSR2D_OFF_BASE_HI: s_base_nxt    = {csr_wdata_i, s_base_r[31:0]};
                eth_dma_pkg::CSR2D_OFF_LSTRIDE: s_lstride_nxt = csr_wdata_i;
                eth_dma_pkg::CSR2D_OFF_PSTRIDE: s_pstride_nxt = csr_wdata_i;
                default: begin end
            endcase
        end
        if (wr_dst_c) begin
            case (csr_off)
                eth_dma_pkg::CSR2D_OFF_BASE_LO: d_base_nxt    = {d_base_r[63:32], csr_wdata_i};
                eth_dma_pkg::CSR2D_OFF_BASE_HI: d_base_nxt    = {csr_wdata_i, d_base_r[31:0]};
                eth_dma_pkg::CSR2D_OFF_LSTRIDE: d_lstride_nxt = csr_wdata_i;
                eth_dma_pkg::CSR2D_OFF_PSTRIDE: d_pstride_nxt = csr_wdata_i;
                default: begin end
            endcase
        end
        if (wr_dim_c) begin
            case (csr_off)
                eth_dma_pkg::CSR2D_OFF_HSIZE:      h_bytes_nxt = csr_wdata_i[15:0];
                eth_dma_pkg::CSR2D_OFF_VSIZE:      v_lines_nxt = csr_wdata_i[15:0];
                eth_dma_pkg::CSR2D_OFF_PLANES:     planes_nxt  = csr_wdata_i[15:0];
                eth_dma_pkg::CSR2D_OFF_WIN_LO_LO:  win_lo_nxt  = {win_lo_r[63:32], csr_wdata_i};
                eth_dma_pkg::CSR2D_OFF_WIN_LO_HI:  win_lo_nxt  = {csr_wdata_i, win_lo_r[31:0]};
                eth_dma_pkg::CSR2D_OFF_WIN_HI_LO:  win_hi_nxt  = {win_hi_r[63:32], csr_wdata_i};
                eth_dma_pkg::CSR2D_OFF_WIN_HI_HI:  win_hi_nxt  = {csr_wdata_i, win_hi_r[31:0]};
                default: begin end
            endcase
        end

        // ---- frame shadows hold; loaded at START ----
        sf_base_nxt = sf_base_r;
        sf_ls_nxt   = sf_ls_r;
        sf_ps_nxt   = sf_ps_r;
        df_base_nxt = df_base_r;
        df_ls_nxt   = df_ls_r;
        df_ps_nxt   = df_ps_r;
        hf_bytes_nxt = hf_bytes_r;
        vf_lines_nxt = vf_lines_r;
        pf_nxt       = pf_r;
        wlof_nxt     = wlof_r;
        whif_nxt     = whif_r;
        mode_f_nxt   = mode_f_r;
        rop_f_nxt    = rop_f_r;
        colour_f_nxt = colour_f_r;

        // ---- status holds ----
        lines_nxt = lines_r;
        done_nxt  = done_r;
        err_nxt   = err_r;
        errcode_nxt = errcode_r;
        irq_flag_nxt = irq_flag_r;
        err_addr_nxt = err_addr_r;
        total_nxt    = total_r;
        frames_nxt   = frames_r;

        // ---- one-cycle START delay (see start_src_c) ----
        start_d_nxt = start_c;
        gen_abort_c = 1'b0;

        // ---- engine working state holds ----
        state_nxt  = state_r;
        chunk_nxt  = chunk_r;
        boff_nxt   = boff_r;
        csr_s_nxt  = csr_s_r;
        csr_d_nxt  = csr_d_r;
        tx_busy_nxt = tx_busy_r;
        cta_nxt    = cta_r;
        mcnt_nxt   = mcnt_r;
        fcnt_nxt   = fcnt_r;
        abort_nxt  = abort_r;
        req_valid_nxt = req_valid_r;

        // ---- deferred abort / EN-while-busy ----
        if ((state_r != ST_IDLE) && (abort_req_c || en_clear_c)) begin
            abort_nxt = 1'b1;
        end

        // ---- START: sample the frame parameters, clear the frame status ----
        if (start_c) begin
            sf_base_nxt  = s_base_r;
            sf_ls_nxt    = {32'h0, s_lstride_r};
            sf_ps_nxt    = {32'h0, s_pstride_r};
            df_base_nxt  = d_base_r;
            df_ls_nxt    = {32'h0, d_lstride_r};
            df_ps_nxt    = {32'h0, d_pstride_r};
            hf_bytes_nxt = h_bytes_r;
            vf_lines_nxt = v_lines_r;
            pf_nxt       = planes_r;
            wlof_nxt     = win_lo_r;
            whif_nxt     = win_hi_r;
            mode_f_nxt   = mode_r;
            rop_f_nxt    = rop_r;
            colour_f_nxt = colour_r;
            done_nxt     = 1'b0;
            err_nxt      = 1'b0;
            errcode_nxt  = 4'd0;
            err_addr_nxt = ZERO64;
            total_nxt    = 32'h0;
            lines_nxt    = 16'd0;
            // per-frame working state: reset here so a frame that faulted or
            // was aborted mid-line can never leak counters into the next frame
            chunk_nxt    = 16'd0;
            boff_nxt     = 16'd0;
            mcnt_nxt     = 16'd0;
            fcnt_nxt     = 16'd0;
        end

        // ---- configuration rejection: report, do not start, touch no bus ----
        // The frame status is cleared exactly as an accepted START would, so
        // software always reads the status of the frame it just programmed
        // (and never a stale DONE / byte count from the previous one).
        if (cfg_bad_c) begin
            done_nxt     = 1'b0;
            err_nxt      = 1'b1;
            errcode_nxt  = eth_dma_pkg::DMA_ERR_CFG;
            err_addr_nxt = ZERO64;
            total_nxt    = 32'h0;
            lines_nxt    = 16'd0;
            if (err_irq_en_r) irq_flag_nxt = 1'b1;
        end

        // ---- IRQ_CLR ----
        if (irq_clr_c) begin
            done_nxt     = 1'b0;
            err_nxt      = 1'b0;
            errcode_nxt  = 4'd0;
            err_addr_nxt = ZERO64;
            irq_flag_nxt = 1'b0;
        end

        // ---- transaction bookkeeping ----
        if (tx_accept_c) begin
            tx_busy_nxt = 1'b1;
            cta_nxt     = {32'h0, tx_addr_c};
        end else if (eng_tx_done) begin
            tx_busy_nxt = 1'b0;
        end

        // ---- main FSM ----
        case (state_r)
            ST_IDLE: begin
                if (start_d_r) begin
                    state_nxt = ST_LINE;
                end
            end

            ST_LINE: begin
                // order matters: a faulted/completed walker also reports
                // safe_o = 0, so fault and completion must be tested first
                if (gen_fault_c) begin
                    state_nxt    = ST_ERR;
                    err_nxt      = 1'b1;
                    errcode_nxt  = eth_dma_pkg::DMA_ERR_RANGE;
                    err_addr_nxt = gen_bad_addr_c;
                    if (err_irq_en_r) irq_flag_nxt = 1'b1;
                end else if (gen_done_c) begin
                    // every line of every plane has been transferred
                    state_nxt  = ST_IDLE;
                    done_nxt   = 1'b1;
                    frames_nxt = frames_r + 16'd1;
                    if (irq_en_r) irq_flag_nxt = 1'b1;
                end else if (!gen_run_c || !gen_safe_c) begin
                    // no walker is offering a transferable line (unreachable in
                    // v0: the walkers of a frame are always in step)
                    state_nxt    = ST_ERR;
                    err_nxt      = 1'b1;
                    errcode_nxt  = eth_dma_pkg::DMA_ERR_RANGE;
                    err_addr_nxt = gen_bad_addr_c;
                    if (err_irq_en_r) irq_flag_nxt = 1'b1;
                end else begin
                    chunk_nxt = chunk_c;
                    csr_s_nxt = src_chunk_addr_c;
                    csr_d_nxt = dst_chunk_addr_c;
                    mcnt_nxt  = 16'd0;
                    fcnt_nxt  = 16'd0;
                    if (mode_f_r == eth_dma_pkg::DMA2D_MODE_FILL) begin
                        state_nxt = ST_FILL;
                    end else begin
                        state_nxt = ST_RD_S;
                    end
                end
            end

            ST_RD_S: begin
                if (eng_tx_done) begin
                    if (eng_tx_resp != eth_dma_pkg::AXI_RESP_OKAY) begin
                        state_nxt    = ST_ERR;
                        err_nxt      = 1'b1;
                        errcode_nxt  = eth_dma_pkg::dma_err_of_resp(eng_tx_resp);
                        err_addr_nxt = cta_r;
                        if (err_irq_en_r) irq_flag_nxt = 1'b1;
                    end else begin
                        if (mode_f_r == eth_dma_pkg::DMA2D_MODE_BLIT) begin
                            state_nxt = ST_RD_D;
                        end else begin
                            state_nxt = ST_WR;
                        end
                    end
                end
            end

            ST_RD_D: begin
                if (eng_tx_done) begin
                    if (eng_tx_resp != eth_dma_pkg::AXI_RESP_OKAY) begin
                        state_nxt    = ST_ERR;
                        err_nxt      = 1'b1;
                        errcode_nxt  = eth_dma_pkg::dma_err_of_resp(eng_tx_resp);
                        err_addr_nxt = cta_r;
                        if (err_irq_en_r) irq_flag_nxt = 1'b1;
                    end else begin
                        state_nxt = ST_MERGE;
                        mcnt_nxt  = 16'd0;
                    end
                end
            end

            ST_MERGE: begin
                if (merge_pop_c) begin
                    mcnt_nxt = mcnt_r + 16'd1;
                    if (mcnt_r == (chunk_r - 16'd1)) begin
                        state_nxt = ST_WR;
                    end
                end
            end

            ST_FILL: begin
                if (fill_push_c) begin
                    fcnt_nxt = fcnt_r + 16'd1;
                    if (fcnt_r == (chunk_r - 16'd1)) begin
                        state_nxt = ST_WR;
                    end
                end
            end

            ST_WR: begin
                if (eng_tx_done) begin
                    if (eng_tx_resp != eth_dma_pkg::AXI_RESP_OKAY) begin
                        state_nxt    = ST_ERR;
                        err_nxt      = 1'b1;
                        errcode_nxt  = eth_dma_pkg::dma_err_of_resp(eng_tx_resp);
                        err_addr_nxt = cta_r;
                        if (err_irq_en_r) irq_flag_nxt = 1'b1;
                    end else begin
                        total_nxt = total_r + (32'(chunk_r) << LOG_BEAT);
                        state_nxt = ST_CHEND;
                    end
                end
            end

            ST_CHEND: begin
                if (line_end_c) begin
                    boff_nxt = 16'd0;
                end else begin
                    boff_nxt = boff_r + chunk_r;
                end
                state_nxt = ST_LINE;
            end

            ST_ERR: begin
                state_nxt = ST_IDLE;
                abort_nxt = 1'b0;
            end

            default: begin
                state_nxt = ST_IDLE;
            end
        endcase

        // ---- deferred abort: honour it at every AXI burst boundary ----
        if ((state_r != ST_IDLE) && (state_r != ST_ERR) && abort_r && !tx_busy_nxt) begin
            state_nxt    = ST_ERR;
            err_nxt      = 1'b1;
            errcode_nxt  = eth_dma_pkg::DMA_ERR_ABORT;
            err_addr_nxt = ZERO64;
            abort_nxt    = 1'b0;
            if (err_irq_en_r) irq_flag_nxt = 1'b1;
        end else if (state_nxt == ST_ERR) begin
            abort_nxt = 1'b0;
        end

        // ---- abandoning a frame parks both walkers ----------------------
        // Every path that ends a frame early (window/carry fault, AXI response
        // error, software ABORT, EN cleared while busy) goes through ST_ERR, so
        // this one pulse is what guarantees no walk survives into the next
        // frame (the walker forbids arming a running walk).
        if (state_nxt == ST_ERR) begin
            gen_abort_c = 1'b1;
        end

        // ---- one line counted per accepted step ----
        if (line_step_c) begin
            lines_nxt = lines_r + 16'd1;
        end

        // ---- transaction request arming (final state_nxt) ----
        if (start_c || (state_nxt == ST_ERR)) begin
            req_valid_nxt = 1'b0;
        end else if (tx_accept_c) begin
            req_valid_nxt = 1'b0;                  // the engine owns the burst
        end else if (!req_valid_r && (state_nxt != state_r) && tx_state_f(state_nxt)) begin
            req_valid_nxt = 1'b1;
        end
    end

    // the walker is stepped exactly when a line's last chunk is written out
    assign line_step_c = (state_r == ST_CHEND) && line_end_c;

    // (the line counter lives in the FSM block above: one line per accepted step
    // -- the walker owns the addresses, the device owns the status counter)
    // `gen_abort_c` is driven from that same block (ST_ERR parks the walkers).

    // ------------------------------------------------------------------
    // State / status update
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            en_r          <= 1'b0;
            mode_r        <= eth_dma_pkg::DMA2D_MODE_MOVE;
            rop_r         <= 4'hC;              // SRCCOPY
            colour_r      <= 32'h0;
            irq_en_r      <= 1'b0;
            err_irq_en_r  <= 1'b0;
            s_base_r      <= ZERO64;
            s_lstride_r   <= 32'h0;
            s_pstride_r   <= 32'h0;
            d_base_r      <= ZERO64;
            d_lstride_r   <= 32'h0;
            d_pstride_r   <= 32'h0;
            h_bytes_r     <= 16'h0;
            v_lines_r     <= 16'h0;
            planes_r      <= 16'h1;
            win_lo_r      <= ZERO64;
            win_hi_r      <= ZERO64;
            sf_base_r     <= ZERO64;
            sf_ls_r       <= ZERO64;
            sf_ps_r       <= ZERO64;
            df_base_r     <= ZERO64;
            df_ls_r       <= ZERO64;
            df_ps_r       <= ZERO64;
            hf_bytes_r    <= 16'h0;
            vf_lines_r    <= 16'h0;
            pf_r          <= 16'h1;
            wlof_r        <= ZERO64;
            whif_r        <= ZERO64;
            mode_f_r      <= eth_dma_pkg::DMA2D_MODE_MOVE;
            rop_f_r       <= 4'hC;
            colour_f_r    <= 32'h0;
            done_r        <= 1'b0;
            err_r         <= 1'b0;
            errcode_r     <= 4'd0;
            irq_flag_r    <= 1'b0;
            err_addr_r    <= ZERO64;
            total_r       <= 32'h0;
            frames_r      <= 16'h0;
            lines_r       <= 16'h0;
            state_r       <= ST_IDLE;
            chunk_r       <= 16'h0;
            boff_r        <= 16'h0;
            csr_s_r       <= ZERO64;
            csr_d_r       <= ZERO64;
            tx_busy_r     <= 1'b0;
            cta_r         <= ZERO64;
            mcnt_r        <= 16'h0;
            fcnt_r        <= 16'h0;
            abort_r       <= 1'b0;
            start_d_r     <= 1'b0;
            req_valid_r   <= 1'b0;
        end else begin
            en_r          <= en_nxt;
            mode_r        <= mode_nxt;
            rop_r         <= rop_nxt;
            colour_r      <= colour_nxt;
            irq_en_r      <= irq_en_nxt;
            err_irq_en_r  <= err_irq_en_nxt;
            s_base_r      <= s_base_nxt;
            s_lstride_r   <= s_lstride_nxt;
            s_pstride_r   <= s_pstride_nxt;
            d_base_r      <= d_base_nxt;
            d_lstride_r   <= d_lstride_nxt;
            d_pstride_r   <= d_pstride_nxt;
            h_bytes_r     <= h_bytes_nxt;
            v_lines_r     <= v_lines_nxt;
            planes_r      <= planes_nxt;
            win_lo_r      <= win_lo_nxt;
            win_hi_r      <= win_hi_nxt;
            sf_base_r     <= sf_base_nxt;
            sf_ls_r       <= sf_ls_nxt;
            sf_ps_r       <= sf_ps_nxt;
            df_base_r     <= df_base_nxt;
            df_ls_r       <= df_ls_nxt;
            df_ps_r       <= df_ps_nxt;
            hf_bytes_r    <= hf_bytes_nxt;
            vf_lines_r    <= vf_lines_nxt;
            pf_r          <= pf_nxt;
            wlof_r        <= wlof_nxt;
            whif_r        <= whif_nxt;
            mode_f_r      <= mode_f_nxt;
            rop_f_r       <= rop_f_nxt;
            colour_f_r    <= colour_f_nxt;
            done_r        <= done_nxt;
            err_r         <= err_nxt;
            errcode_r     <= errcode_nxt;
            irq_flag_r    <= irq_flag_nxt;
            err_addr_r    <= err_addr_nxt;
            total_r       <= total_nxt;
            frames_r      <= frames_nxt;
            lines_r       <= lines_nxt;
            state_r       <= state_nxt;
            chunk_r       <= chunk_nxt;
            boff_r        <= boff_nxt;
            csr_s_r       <= csr_s_nxt;
            csr_d_r       <= csr_d_nxt;
            tx_busy_r     <= tx_busy_nxt;
            cta_r         <= cta_nxt;
            mcnt_r        <= mcnt_nxt;
            fcnt_r        <= fcnt_nxt;
            abort_r       <= abort_nxt;
            start_d_r     <= start_d_nxt;
            req_valid_r   <= req_valid_nxt;
        end
    end

    // ------------------------------------------------------------------
    // CSR read mux
    // ------------------------------------------------------------------
    always_comb begin
        csr_wr_ready_o = 1'b1;
        csr_rd_ready_o = 1'b1;
        csr_rdata_o    = 32'h0;

        if (csr_rd_valid_i) begin
            case (csr_blk)
                eth_dma_pkg::CSR2D_BLK_CTRL: begin
                    case (csr_off)
                        eth_dma_pkg::CSR2D_OFF_CTRL: begin
                            csr_rdata_o[eth_dma_pkg::DMA2D_CTRL_EN_BIT] = en_r;
                        end
                        eth_dma_pkg::CSR2D_OFF_STATUS: begin
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_BUSY_BIT]  = (state_r != ST_IDLE);
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_DONE_BIT]  = done_r;
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_ERROR_BIT] = err_r;
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_ERRCODE_LSB +: 3] = errcode_r[2:0];
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_LINES_LSB +: 8]   = lines_r[7:0];
                            csr_rdata_o[eth_dma_pkg::DMA2D_ST_IRQ_BIT]   = irq_flag_r;
                        end
                        eth_dma_pkg::CSR2D_OFF_MODE:   csr_rdata_o[1:0] = mode_r;
                        eth_dma_pkg::CSR2D_OFF_ROP:    csr_rdata_o[3:0] = rop_r;
                        eth_dma_pkg::CSR2D_OFF_COLOUR: csr_rdata_o     = colour_r;
                        eth_dma_pkg::CSR2D_OFF_CFG: begin
                            csr_rdata_o[eth_dma_pkg::DMA2D_CFG_IRQEN_BIT]    = irq_en_r;
                            csr_rdata_o[eth_dma_pkg::DMA2D_CFG_ERRIRQEN_BIT] = err_irq_en_r;
                        end
                        eth_dma_pkg::CSR2D_OFF_VERSION: csr_rdata_o = eth_dma_pkg::DMA2D_VERSION;
                        default: csr_rdata_o = 32'h0;
                    endcase
                end
                eth_dma_pkg::CSR2D_BLK_SRC: begin
                    case (csr_off)
                        eth_dma_pkg::CSR2D_OFF_BASE_LO: csr_rdata_o = s_base_r[31:0];
                        eth_dma_pkg::CSR2D_OFF_BASE_HI: csr_rdata_o = s_base_r[63:32];
                        eth_dma_pkg::CSR2D_OFF_LSTRIDE: csr_rdata_o = s_lstride_r;
                        eth_dma_pkg::CSR2D_OFF_PSTRIDE: csr_rdata_o = s_pstride_r;
                        eth_dma_pkg::CSR2D_OFF_CUR_LO:  csr_rdata_o = src_line_addr_c[31:0];
                        eth_dma_pkg::CSR2D_OFF_CUR_HI:  csr_rdata_o = src_line_addr_c[63:32];
                        default: csr_rdata_o = 32'h0;
                    endcase
                end
                eth_dma_pkg::CSR2D_BLK_DST: begin
                    case (csr_off)
                        eth_dma_pkg::CSR2D_OFF_BASE_LO: csr_rdata_o = d_base_r[31:0];
                        eth_dma_pkg::CSR2D_OFF_BASE_HI: csr_rdata_o = d_base_r[63:32];
                        eth_dma_pkg::CSR2D_OFF_LSTRIDE: csr_rdata_o = d_lstride_r;
                        eth_dma_pkg::CSR2D_OFF_PSTRIDE: csr_rdata_o = d_pstride_r;
                        eth_dma_pkg::CSR2D_OFF_CUR_LO:  csr_rdata_o = dst_line_addr_c[31:0];
                        eth_dma_pkg::CSR2D_OFF_CUR_HI:  csr_rdata_o = dst_line_addr_c[63:32];
                        default: csr_rdata_o = 32'h0;
                    endcase
                end
                eth_dma_pkg::CSR2D_BLK_DIM: begin
                    case (csr_off)
                        eth_dma_pkg::CSR2D_OFF_HSIZE:     csr_rdata_o = {16'h0, h_bytes_r};
                        eth_dma_pkg::CSR2D_OFF_VSIZE:     csr_rdata_o = {16'h0, v_lines_r};
                        eth_dma_pkg::CSR2D_OFF_PLANES:    csr_rdata_o = {16'h0, planes_r};
                        eth_dma_pkg::CSR2D_OFF_WIN_LO_LO: csr_rdata_o = win_lo_r[31:0];
                        eth_dma_pkg::CSR2D_OFF_WIN_LO_HI: csr_rdata_o = win_lo_r[63:32];
                        eth_dma_pkg::CSR2D_OFF_WIN_HI_LO: csr_rdata_o = win_hi_r[31:0];
                        eth_dma_pkg::CSR2D_OFF_WIN_HI_HI: csr_rdata_o = win_hi_r[63:32];
                        default: csr_rdata_o = 32'h0;
                    endcase
                end
                eth_dma_pkg::CSR2D_BLK_STAT: begin
                    case (csr_off)
                        eth_dma_pkg::CSR2D_OFF_XFER:   csr_rdata_o = total_r;
                        eth_dma_pkg::CSR2D_OFF_LINES:  csr_rdata_o = {16'h0, lines_r};
                        eth_dma_pkg::CSR2D_OFF_ERR_LO: csr_rdata_o = err_addr_r[31:0];
                        eth_dma_pkg::CSR2D_OFF_ERR_HI: csr_rdata_o = err_addr_r[63:32];
                        eth_dma_pkg::CSR2D_OFF_FRAMES: csr_rdata_o = {16'h0, frames_r};
                        default: csr_rdata_o = 32'h0;
                    endcase
                end
                default: csr_rdata_o = 32'h0;
            endcase
        end
    end

    assign irq_o = irq_flag_r;

    // ------------------------------------------------------------------
    // Shared AXI4 master engine (one outstanding transaction)
    // ------------------------------------------------------------------
    eth_dma_axi_engine #(
        .AXI_AW  (AXI_AW),
        .AXI_DW  (AXI_DW),
        .AXI_IDW (AXI_IDW)
    ) u_eng (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .tx_valid_i   (tx_req_c),
        .tx_ready_o   (eng_tx_ready),
        .tx_op_i      (tx_op_c),
        .tx_addr_i    (tx_addr_c),
        .tx_len_i     (tx_len_c),
        .tx_id_i      (TX_ID),
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
    // Parametric sanity (elaboration time; ADR-017: no vendor primitives)
    // ------------------------------------------------------------------
    initial begin : g_param_check
        if ((AXI_DW % 32) != 0) begin
            $error("eth_dma_2d: AXI_DW=%0d must be a multiple of 32 (DMA_COLOUR is 32-bit)",
                   AXI_DW);
        end
        if (AXI_AW < 12) begin
            $error("eth_dma_2d: AXI_AW=%0d must be >= 12 (4 KiB burst limit math)",
                   AXI_AW);
        end
        if (FIFO_DEPTH > 256) begin
            $error("eth_dma_2d: FIFO_DEPTH=%0d exceeds the 256-beat AxLEN cap",
                   FIFO_DEPTH);
        end
    end

    // ------------------------------------------------------------------
    // Formal properties (SymbiYosys / smtbmc; NOT compiled for lint or sim).
    // Proven by ethereal-shell/formal/eth_dma_2d.sby.  The valuable property
    // here is the END-TO-END one: every AXI transaction this device issues lies
    // entirely inside the software-declared window, so a misprogrammed stride or
    // size can never make the 2D DMA touch memory outside its framebuffer
    // region.  The two support properties (shadow stability, walker liveness of
    // the guard) are what make it inductive.
    // ------------------------------------------------------------------
`ifdef FORMAL
    logic past_valid = 1'b0;

    always_ff @(posedge clk_i) past_valid <= 1'b1;
    always_ff @(posedge clk_i) if (!past_valid) assume(!rst_ni);

    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // ---- S1: the frame parameters are frozen while a frame runs -----
            if (state_r != ST_IDLE) begin
                assert(sf_base_r == $past(sf_base_r));
                assert(sf_ls_r   == $past(sf_ls_r));
                assert(sf_ps_r   == $past(sf_ps_r));
                assert(df_base_r == $past(df_base_r));
                assert(df_ls_r   == $past(df_ls_r));
                assert(df_ps_r   == $past(df_ps_r));
                assert(hf_bytes_r == $past(hf_bytes_r));
                assert(vf_lines_r == $past(vf_lines_r));
                assert(pf_r      == $past(pf_r));
                assert(wlof_r    == $past(wlof_r));
                assert(whif_r    == $past(whif_r));
                assert(mode_f_r  == $past(mode_f_r));
                assert(rop_f_r   == $past(rop_f_r));
            end

            // ---- S2a/S2b: the coupling between the request register and the
            //      FSM, and between the FSM and the walker guard.  These are the
            //      invariants that make S2/S3 inductive: a request exists only
            //      inside a transaction state (it is armed on entering one and
            //      dropped when the engine accepts it), and a transaction state
            //      is entered only through ST_LINE's guard, which no pulse can
            //      change before the chunk is issued (the walkers move only on
            //      start/step/abort, none of which occurs inside a chunk) -----
            if (req_valid_r) begin
                assert(state_r == ST_RD_S || state_r == ST_RD_D || state_r == ST_WR);
            end
            if (tx_state_f(state_r)) begin
                assert(gen_run_c);
                assert(gen_safe_c);
            end

            // ---- S4: the geometry the walkers were armed with is a legal one
            //      (HSIZE a whole number of beats, non-empty window), because
            //      START only samples cfg_ok_c-checked registers into the
            //      shadows -- the arithmetic S3 needs, discharged at the source
            if (state_r != ST_IDLE) begin
                assert(hf_bytes_r[LOG_BEAT-1:0] == {LOG_BEAT{1'b0}});
                assert(hf_bytes_r != 16'd0);
                assert({1'b0, wlof_r} < {1'b0, whif_r});
            end

            // ---- S2: a transaction is issued only for a guarded line --------
            if (tx_req_c) begin
                assert(gen_run_c);
                assert(gen_safe_c);
            end

            // ---- S5: the latched chunk address IS the walker's current line
            //      address plus the in-line byte offset, and the chunk length is
            //      bounded by the beats left in that line.  This is what carries
            //      the walker's per-line window guarantee (eth_dma_2d_addr.sby,
            //      property W1) to the individual AXI bursts of S3: a chunk is
            //      never longer than the line it belongs to, so a guaranteed
            //      line implies guaranteed bursts ---------------------------------
            if (tx_state_f(state_r)) begin
                assert(csr_s_r == src_line_addr_c + boff_bytes_c);
                assert(csr_d_r == dst_line_addr_c + boff_bytes_c);
                assert(chunk_r <= beats_left_c);
                assert(chunk_r != 16'd0);
            end

            // ---- S3: every issued burst is inside the declared window -------
            if (tx_req_c) begin
                assert({1'b0, tx_addr_c} >= {1'b0, wlof_r});
                assert(({1'b0, tx_addr_c} + ((65'(tx_len_c) + 65'd1) << LOG_BEAT))
                       <= {1'b0, whif_r});
            end
        end
    end
`endif

endmodule

`default_nettype wire
