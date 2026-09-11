`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dram_stub
// Description: Behavioral AXI4 memory slave — the default (sim) DRAM
//              implementation behind the `eth_dram_ctrl` socket (ADR-017).
// Details:     A standalone full AXI4 memory slave: INCR bursts (AxLEN 0..255),
//              AxSIZE decoding, per-byte WSTRB lanes, WLAST/RLAST, per-beat
//              response codes, and registered (never dropped) handshakes.
//              INCR addressing follows IHI0022G §A3.4.1 exactly:
//              Address_1 = AxADDR (may be unaligned) and
//              Address_N = align_down(AxADDR, 2^AxSIZE) + (N-1)*2^AxSIZE for
//              N > 1, so only the first beat of a burst can be unaligned and
//              every later beat is size-aligned (the address increment between
//              beat 1 and beat 2 is therefore < 2^AxSIZE for an unaligned
//              start). Narrow/unaligned accesses use WSTRB lane enables within
//              the addressed bus word and return the containing bus word on
//              reads (the AXI rule that the slave may ignore the LS address
//              bits and let the master extract from the addressed lanes).
//
//              STRUCTURE
//                * one write engine (AW capture -> W beats -> B) and one read
//                  engine (AR capture -> RD_LATENCY -> R beats), independent,
//                  single-outstanding per direction (matches the v0
//                  `eth_axi_xbar` model, eth-axi-v0.md §5.2).
//                * every AXI output is driven by a register or by the state
//                  register (no combinational input->output path,
//                  eth-axi-v0.md §2 rule 1). WREADY/AWREADY/ARREADY depend only
//                  on stored state, never on the matching VALID/RESP READY.
//                * R payload (RDATA/RRESP/RID/RLAST) is captured into registers
//                  when a beat starts, so it stays stable while RREADY is low —
//                  a concurrent write to the same word cannot corrupt a stalled
//                  read beat.
//
//              ERROR CONTRACT (shared with the socket; the TB mirrors it)
//                OKAY   — the whole burst lies inside [MEM_BASE, MEM_BASE+MEM_BYTES).
//                SLVERR — protocol/transfer illegality: burst != INCR
//                         (WRAP/FIXED unsupported in v0), AxSIZE wider than the
//                         bus (AxSIZE > log2(AXI_DW/8)), a 4 KiB boundary
//                         crossing (AXI4 forbids it), or AxLOCK exclusive/ATOP
//                         (deferred per eth-axi-v0.md §5.2).
//                DECERR — address decode failure: any byte of the burst falls
//                         outside the wrapped memory window. A DECERR write
//                         still SINKS all W beats (AXI4 requires it) and
//                         commits nothing; a DECERR read returns ONE beat
//                         (RDATA=0, RRESP=DECERR, RLAST=1) and consumes the AR,
//                         matching the repo's built-in decode-error slave
//                         (`eth_axi_xbar` §5.3: one response per transaction).
//
//              TIMING
//                * AW handshake -> WREADY: 1 cycle (W is accepted only after the
//                  AW beat is captured; a master may legally drive W first and
//                  will simply not handshake until it presents AW too).
//                * last W beat -> BVALID: WR_LATENCY cycles.
//                * AR handshake -> first RVALID: RD_LATENCY + 1 cycles, then one
//                  R beat per cycle while RREADY is high.
//              Latency parameters are clamped to >= 1 (the FSM stage cannot be
//              zero cycles).
//
//              SIM-ONLY: this is the ADR-017 Verilator stub, not a synthesis
//              target — the memory is a plain behavioral array. Gate-level /
//              vendor builds substitute the per-target backend at the
//              `eth_dram_ctrl` seam (see hal/<vendor>/glue/).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - created (E2-DRAM1)
// Tags:        RTL, SIM-STUB
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §4 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §4 (DRAM = wrapped component) ·
//              ethereal-spec/control/eth-axi-v0.md §2 (rules 1-2), §3.1 (responses), §5.3 (DECERR)
// Notes:       iverilog-compatible (flat ports, no SV interface/modport, sized
//              literals, no `automatic` block-local vars — `function automatic`
//              only). ASSUMPTION (TBD, 2026-09-12): the DRAM window base is
//              0x8000_0000 (no SoC memory map is frozen yet; the xbar TB uses
//              0x4000_2000 for the EMRI window). MEM_BASE/MEM_BYTES are
//              parameters so the integrating SoC top sets the real map.
//              AxCACHE/AxPROT/AxQOS/AxREGION are accepted and ignored (no
//              cacheable/non-secure semantics modelled in v0).
module eth_dram_stub #(
    parameter int AXI_AW     = 32,                 // AXI4 address width
    parameter int AXI_DW     = 64,                 // AXI4 data width (32/64)
    parameter int AXI_IDW    = 4,                  // AXI4 transaction ID width
    parameter logic [AXI_AW-1:0] MEM_BASE = 32'h8000_0000,  // window base (ASSUMPTION)
    parameter int MEM_BYTES  = 1 << 20,            // window size in bytes (1 MiB sim default)
    parameter int RD_LATENCY = 4,                  // AR -> first R beat latency
    parameter int WR_LATENCY = 2                   // last W beat -> B latency
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- AXI4 write address channel (AW) ----
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    input  logic [AXI_AW-1:0]       s_axi_awaddr,
    input  logic [AXI_IDW-1:0]      s_axi_awid,
    input  logic [7:0]              s_axi_awlen,
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,
    input  logic [3:0]              s_axi_awcache,
    input  logic [2:0]              s_axi_awprot,
    input  logic [3:0]              s_axi_awqos,
    input  logic [3:0]              s_axi_awregion,
    input  logic                    s_axi_awlock,
    // ---- AXI4 write data channel (W) ----
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic [AXI_DW-1:0]       s_axi_wdata,
    input  logic [AXI_DW/8-1:0]     s_axi_wstrb,
    input  logic                    s_axi_wlast,
    // ---- AXI4 write response channel (B) ----
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    output logic [1:0]              s_axi_bresp,
    output logic [AXI_IDW-1:0]      s_axi_bid,
    // ---- AXI4 read address channel (AR) ----
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    input  logic [AXI_AW-1:0]       s_axi_araddr,
    input  logic [AXI_IDW-1:0]      s_axi_arid,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,
    input  logic [3:0]              s_axi_arcache,
    input  logic [2:0]              s_axi_arprot,
    input  logic [3:0]              s_axi_arqos,
    input  logic [3:0]              s_axi_arregion,
    input  logic                    s_axi_arlock,
    // ---- AXI4 read data channel (R) ----
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic [AXI_DW-1:0]       s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic [AXI_IDW-1:0]      s_axi_rid
);

    // ------------------------------------------------------------------
    // Derived sizes / response + burst encodings
    // ------------------------------------------------------------------
    localparam int STRB_W    = AXI_DW / 8;
    localparam int LOG_STRB  = $clog2(STRB_W);
    localparam int MEM_WORDS = MEM_BYTES / STRB_W;
    localparam int IDX_W     = (MEM_WORDS > 1) ? $clog2(MEM_WORDS) : 1;
    // byte-address arithmetic headroom: AxLEN+1 (<=256) << AxSIZE (<=7) + base offset
    localparam int BEAT_W    = AXI_AW + 11;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [1:0] BURST_INCR   = 2'b01;

    localparam logic [2:0] LOG_STRB3 = LOG_STRB[2:0];

    localparam int RD_LAT_CY = (RD_LATENCY < 1) ? 1 : RD_LATENCY;
    localparam int WR_LAT_CY = (WR_LATENCY < 1) ? 1 : WR_LATENCY;

    // Sized so the latency counters compare without a width/unsigned warning.
    localparam logic [31:0] RD_LAT_CY32 = RD_LAT_CY;
    localparam logic [31:0] WR_LAT_CY32 = WR_LAT_CY;

    // ------------------------------------------------------------------
    // Behavioral memory (ADR-017 sim stub; the vendor backend replaces the
    // whole socket implementation, not this array — see eth_dram_ctrl seam)
    // ------------------------------------------------------------------
    logic [AXI_DW-1:0] mem [0:MEM_WORDS-1];

    // ------------------------------------------------------------------
    // Burst legality + address decode (pure function of the captured AxADDR/
    // AxLEN/AxSIZE/AxBURST/AxLOCK). Response is uniform across the burst.
    // ------------------------------------------------------------------
    function automatic logic [1:0] burst_resp(
        input logic [AXI_AW-1:0] addr,
        input logic [7:0]        len,
        input logic [2:0]        size,
        input logic [1:0]        burst,
        input logic              lock
    );
        logic [BEAT_W-1:0] off_first;
        logic [BEAT_W-1:0] off_last;
        logic [BEAT_W-1:0] bytes;
        logic [BEAT_W-1:0] abase;         // AXI4 Aligned_Address = align_down(AxADDR, 2^AxSIZE)
        logic [12:0]       b_last;
        begin
            if (burst != BURST_INCR) begin
                burst_resp = RESP_SLVERR;              // WRAP/FIXED unsupported (v0)
            end else if (size > LOG_STRB3) begin
                burst_resp = RESP_SLVERR;              // wider than the data bus
            end else if (lock) begin
                burst_resp = RESP_SLVERR;              // exclusive/ATOP deferred
            end else begin
                // INCR: Address_1 = AxADDR, Address_N = Aligned_Address +
                // (N-1)*2^AxSIZE (IHI0022G §A3.4.1), so the burst spans
                // [Aligned_Address, Aligned_Address + (AxLEN+1)*2^AxSIZE).
                bytes     = BEAT_W'({1'b0, len} + 9'd1) << size;
                abase     = BEAT_W'({1'b0, addr}) & ~((BEAT_W'(1) << size) - BEAT_W'(1));
                // 4 KiB boundary crossing is illegal AXI4. Aligned_Address is in
                // the same 4 KiB page as AxADDR (2^AxSIZE <= 8), so the last
                // byte bounds the whole burst.
                b_last    = {1'b0, abase[11:0]} + bytes[12:0] - 13'd1;
                if (b_last > 13'h0FFF) begin
                    burst_resp = RESP_SLVERR;          // crosses a 4 KiB boundary
                end else begin
                    off_first = BEAT_W'({1'b0, addr}) - BEAT_W'({1'b0, MEM_BASE});
                    off_last  = abase - BEAT_W'({1'b0, MEM_BASE})
                              + bytes - {{(BEAT_W-1){1'b0}}, 1'b1};
                    if ((off_first >= BEAT_W'(MEM_BYTES)) || (off_last >= BEAT_W'(MEM_BYTES)))
                        burst_resp = RESP_DECERR;      // outside the wrapped window
                    else
                        burst_resp = RESP_OKAY;
                end
            end
        end
    endfunction

    // ==================================================================
    // WRITE ENGINE: AW capture -> W beats (WSTRB lanes) -> B
    // ==================================================================
    typedef enum logic [1:0] {
        W_IDLE = 2'd0,
        W_DATA = 2'd1,
        W_WAIT = 2'd2,
        W_RESP = 2'd3
    } wstate_e;

    wstate_e            wst_r, wst_nxt;
    logic [AXI_AW-1:0]  waddr_r, waddr_nxt;
    logic [AXI_AW-1:0]  wabase_r, wabase_nxt;   // AXI4 Aligned_Address
    logic [AXI_AW-1:0]  waddr_fol;              // address of the beat after the current one
    logic [7:0]         wlen_r, wlen_nxt;
    logic [2:0]         wsize_r, wsize_nxt;
    logic [AXI_IDW-1:0] wid_r, wid_nxt;
    logic [1:0]         wresp_r, wresp_nxt;
    logic [8:0]         wbeat_r, wbeat_nxt;
    logic [31:0]        wlat_r, wlat_nxt;

    logic               wr_fire;      // a W beat handshakes this cycle
    logic               wr_last;      // ... and it is the burst's final beat
    logic               wr_mem_en;    // OKAY burst -> commit this beat
    logic [IDX_W-1:0]   wr_wid;       // memory word index of the current W beat
    logic [AXI_AW-1:0]  winc;         // INCR byte step = 1 << AxSIZE

    assign winc      = AXI_AW'(1) << wsize_r;
    // Beat 1 is the first size-aligned beat; an unaligned Start is beat 0 only.
    assign waddr_fol = (wbeat_r == 9'd0) ? (wabase_r + winc) : (waddr_r + winc);
    assign wr_fire   = (wst_r == W_DATA) && s_axi_wvalid;
    assign wr_last   = s_axi_wlast || (wbeat_r == {1'b0, wlen_r});
    assign wr_mem_en = wr_fire && (wresp_r == RESP_OKAY);
    assign wr_wid    = IDX_W'((waddr_r - MEM_BASE) >> LOG_STRB);

    // Handshake outputs come from stored state only (no comb input->output).
    assign s_axi_awready = (wst_r == W_IDLE);
    assign s_axi_wready  = (wst_r == W_DATA);
    assign s_axi_bvalid  = (wst_r == W_RESP);
    assign s_axi_bresp   = wresp_r;
    assign s_axi_bid     = wid_r;

    always_comb begin
        wst_nxt    = wst_r;
        waddr_nxt  = waddr_r;
        wabase_nxt = wabase_r;
        wlen_nxt  = wlen_r;
        wsize_nxt = wsize_r;
        wid_nxt   = wid_r;
        wresp_nxt = wresp_r;
        wbeat_nxt = wbeat_r;
        wlat_nxt  = (wlat_r > 32'd0) ? (wlat_r - 32'd1) : 32'd0;
        case (wst_r)
            W_IDLE: begin
                if (s_axi_awvalid) begin
                    waddr_nxt  = s_axi_awaddr;
                    // Aligned_Address = AxADDR with the low AxSIZE bits cleared.
                    wabase_nxt = s_axi_awaddr
                               & ~((AXI_AW'(1) << s_axi_awsize) - AXI_AW'(1));
                    wlen_nxt  = s_axi_awlen;
                    wsize_nxt = s_axi_awsize;
                    wid_nxt   = s_axi_awid;
                    wresp_nxt = burst_resp(s_axi_awaddr, s_axi_awlen, s_axi_awsize,
                                           s_axi_awburst, s_axi_awlock);
                    wbeat_nxt = 9'd0;
                    wst_nxt   = W_DATA;
                end
            end
            W_DATA: begin
                if (wr_fire) begin
                    waddr_nxt = waddr_fol;
                    wbeat_nxt = wbeat_r + 9'd1;
                    if (wr_last) begin
                        // DECERR/SLVERR bursts sink every W beat too (AXI4), so
                        // the response is emitted only after the last beat.
                        wlat_nxt = WR_LAT_CY32;
                        wst_nxt  = W_WAIT;
                    end
                end
            end
            W_WAIT: begin
                if (wlat_r <= 32'd1) wst_nxt = W_RESP;
            end
            default: begin                      // W_RESP
                if (s_axi_bready) wst_nxt = W_IDLE;
            end
        endcase
    end

    integer li;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wst_r    <= W_IDLE;
            waddr_r  <= {AXI_AW{1'b0}};
            wabase_r <= {AXI_AW{1'b0}};
            wlen_r   <= 8'h00;
            wsize_r  <= 3'd0;
            wid_r    <= {AXI_IDW{1'b0}};
            wresp_r  <= RESP_OKAY;
            wbeat_r  <= 9'd0;
            wlat_r   <= 32'd0;
        end else begin
            wst_r    <= wst_nxt;
            waddr_r  <= waddr_nxt;
            wabase_r <= wabase_nxt;
            wlen_r   <= wlen_nxt;
            wsize_r  <= wsize_nxt;
            wid_r    <= wid_nxt;
            wresp_r  <= wresp_nxt;
            wbeat_r  <= wbeat_nxt;
            wlat_r   <= wlat_nxt;
            if (wr_mem_en) begin
                for (li = 0; li < STRB_W; li = li + 1)
                    if (s_axi_wstrb[li]) mem[wr_wid][li*8 +: 8] <= s_axi_wdata[li*8 +: 8];
            end
        end
    end

    // ==================================================================
    // READ ENGINE: AR capture -> RD_LATENCY -> R beats
    // ==================================================================
    typedef enum logic [1:0] {
        R_IDLE = 2'd0,
        R_LAT  = 2'd1,
        R_BEAT = 2'd2
    } rstate_e;

    rstate_e            rst_r, rst_nxt;
    logic [AXI_AW-1:0]  raddr_r, raddr_nxt;
    logic [AXI_AW-1:0]  rabase_r, rabase_nxt;   // AXI4 Aligned_Address
    logic [7:0]         rlen_r, rlen_nxt;
    logic [2:0]         rsize_r, rsize_nxt;
    logic [AXI_IDW-1:0] rid_r, rid_nxt;
    logic [1:0]         rresp_r, rresp_nxt;
    logic [8:0]         rbeat_r, rbeat_nxt;
    logic [31:0]        rlat_r, rlat_nxt;
    logic [AXI_DW-1:0]  rdata_r;
    logic               rdata_en;     // a fetched beat is committed this cycle
    logic [AXI_AW-1:0]  raddr_fol;    // byte address of the following INCR beat
    logic               rburst_last;  // the presented beat is the burst's last
    logic [IDX_W-1:0]   rd_wid;       // word index of the beat being presented
    logic [IDX_W-1:0]   rd_wid_fol;   // word index of the following INCR beat
    logic [AXI_AW-1:0]  rinc;         // INCR byte step = 1 << AxSIZE

    assign rinc       = AXI_AW'(1) << rsize_r;
    // Beat 1 is the first size-aligned beat; an unaligned Start is beat 0 only.
    assign raddr_fol  = (rbeat_r == 9'd0) ? (rabase_r + rinc) : (raddr_r + rinc);
    assign rd_wid     = IDX_W'((raddr_r - MEM_BASE) >> LOG_STRB);
    assign rd_wid_fol = IDX_W'((raddr_fol - MEM_BASE) >> LOG_STRB);
    // A non-OKAY read burst returns exactly ONE beat (RDATA=0, DECERR/SLVERR,
    // RLAST=1) and consumes the AR — matches the repo's decode-error slave
    // (eth_axi_xbar §5.3: one response per transaction, no dwell).
    assign rburst_last = (rresp_r != RESP_OKAY) || (rbeat_r == {1'b0, rlen_r});
    assign rdata_en    = ((rst_r == R_LAT) && (rlat_r <= 32'd1))
                      || ((rst_r == R_BEAT) && s_axi_rready && !rburst_last);

    assign s_axi_arready = (rst_r == R_IDLE);
    assign s_axi_rvalid  = (rst_r == R_BEAT);
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = rresp_r;
    assign s_axi_rid     = rid_r;
    assign s_axi_rlast   = (rst_r == R_BEAT) && rburst_last;

    always_comb begin
        rst_nxt    = rst_r;
        raddr_nxt  = raddr_r;
        rabase_nxt = rabase_r;
        rlen_nxt  = rlen_r;
        rsize_nxt = rsize_r;
        rid_nxt   = rid_r;
        rresp_nxt = rresp_r;
        rbeat_nxt = rbeat_r;
        rlat_nxt  = (rlat_r > 32'd0) ? (rlat_r - 32'd1) : 32'd0;
        case (rst_r)
            R_IDLE: begin
                if (s_axi_arvalid) begin
                    raddr_nxt  = s_axi_araddr;
                    // Aligned_Address = AxADDR with the low AxSIZE bits cleared.
                    rabase_nxt = s_axi_araddr
                               & ~((AXI_AW'(1) << s_axi_arsize) - AXI_AW'(1));
                    rlen_nxt  = s_axi_arlen;
                    rsize_nxt = s_axi_arsize;
                    rid_nxt   = s_axi_arid;
                    rresp_nxt = burst_resp(s_axi_araddr, s_axi_arlen, s_axi_arsize,
                                           s_axi_arburst, s_axi_arlock);
                    rbeat_nxt = 9'd0;
                    rlat_nxt  = RD_LAT_CY32;
                    rst_nxt   = R_LAT;
                end
            end
            R_LAT: begin
                if (rlat_r <= 32'd1) rst_nxt = R_BEAT;
            end
            default: begin                      // R_BEAT
                if (s_axi_rready) begin
                    if (rburst_last) begin
                        // OKAY burst: ends on its (AxLEN+1)-th beat.
                        // Non-OKAY burst: ends on its single error beat.
                        rst_nxt = R_IDLE;
                    end else begin
                        raddr_nxt = raddr_fol;
                        rbeat_nxt = rbeat_r + 9'd1;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rst_r    <= R_IDLE;
            raddr_r  <= {AXI_AW{1'b0}};
            rabase_r <= {AXI_AW{1'b0}};
            rlen_r  <= 8'h00;
            rsize_r <= 3'd0;
            rid_r   <= {AXI_IDW{1'b0}};
            rresp_r <= RESP_OKAY;
            rbeat_r <= 9'd0;
            rlat_r  <= 32'd0;
            rdata_r <= {AXI_DW{1'b0}};
        end else begin
            rst_r    <= rst_nxt;
            raddr_r  <= raddr_nxt;
            rabase_r <= rabase_nxt;
            rlen_r  <= rlen_nxt;
            rsize_r <= rsize_nxt;
            rid_r   <= rid_nxt;
            rresp_r <= rresp_nxt;
            rbeat_r <= rbeat_nxt;
            rlat_r  <= rlat_nxt;
            // Payload captured at beat start -> stable while RREADY is low
            // (a concurrent W to the same word cannot disturb a stalled beat).
            if (rdata_en) begin
                if (rresp_r == RESP_OKAY)
                    rdata_r <= ((rst_r == R_LAT)) ? mem[rd_wid] : mem[rd_wid_fol];
                else
                    rdata_r <= {AXI_DW{1'b0}};
            end
        end
    end

    // ------------------------------------------------------------------
    // AXI4 sideband accepted and ignored in v0 (no cacheable/exclusive/QoS
    // semantics). Folded into one used signal so -Wall stays clean.
    // ------------------------------------------------------------------
    // verilator lint_off UNUSEDSIGNAL
    logic unused_ok;
    assign unused_ok = &{1'b0, s_axi_awcache, s_axi_awprot, s_axi_awqos, s_axi_awregion,
                         s_axi_arcache, s_axi_arprot, s_axi_arqos, s_axi_arregion};
    // verilator lint_on UNUSEDSIGNAL

endmodule

`default_nettype wire
