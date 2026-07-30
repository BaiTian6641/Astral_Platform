`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_axi_lite_slave
// Description: Full-speed AXI4-Lite register slave (the EMRI/peripheral template).
// Details:     5-channel AXI4-Lite (AW/W/B/AR/R), single-beat, no bursts/IDs
//              (AxLEN=0), per ethereal-spec/control/eth-axi-v0.md §3. Serves a
//              small word-addressed register window of N_REGS 32-bit registers
//              mapped at byte base REG_BASE; accesses outside the window return
//              SLVERR (§3.1; the xbar's decode-error slave separately returns
//              DECERR for *unmapped* addresses — this slave only handles the
//              region it was decoded for).
//
//              Registered boundaries: every AXI handshake output is produced by
//              an eth_axi_skidbuf (no comb input->output path, §2 rule 1). The
//              AW and W channels are captured independently, so a master may
//              present W before AW (AW/W decoupling, §3.2 "may wait for both").
//              A write completes (B issued, OKAY/SLVERR) only after BOTH the AW
//              and W beats have been accepted; a read completes (R issued) after
//              the AR beat is accepted and the addressed word is registered.
//
//              Write strobe: wstrb honoured per-byte. Read of a write-only/unused
//              window register returns its last stored value (v0 keeps all
//              window registers RW; a CSR map with RO/W1C fields is layered on
//              the reg_we_o/reg_rdata_i ports by the integrating peripheral).
//
//              Integration ports: the register file is exposed as a flat
//              reg_rdata_o bus (N_REGS*32) + a reg_we_o strobe + reg_waddr_o +
//              reg_wdata_o + reg_wstrb_o so a peripheral (e.g. emri_regfile) can
//              either use the internal RW window or overlay its own semantics.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §3 (AXI4-Lite), §2 (rules 1-2)
// Notes:       iverilog-compatible (flat ports; N_REGS flat int; no packed-2D
//              params — REG window exposed as a flat N_REGS*32 bus). v0 window is
//              word-aligned only; unaligned addrs are treated by their word index
//              (low addr bits ignored) — documented v0.1 follow-up for byte-lane
//              decode. Formal props under `ifdef FORMAL (sby).
module eth_axi_lite_slave #(
    parameter int AXI_AW  = 32,            // address width
    parameter int AXI_DW  = 32,            // data width (v0 = 32)
    parameter int N_REGS  = 16,            // window size in 32-bit words
    // byte base address of the window (flat int param; iverilog-friendly)
    parameter logic [AXI_AW-1:0] REG_BASE = {AXI_AW{1'b0}}
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,
    // ---- AXI4-Lite slave ----
    // AW
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    input  logic [AXI_AW-1:0]       s_axi_awaddr,
    input  logic [2:0]              s_axi_awprot,
    // W
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic [AXI_DW-1:0]       s_axi_wdata,
    input  logic [(AXI_DW/8)-1:0]   s_axi_wstrb,
    // B
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    output logic [1:0]              s_axi_bresp,
    // AR
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    input  logic [AXI_AW-1:0]       s_axi_araddr,
    input  logic [2:0]              s_axi_arprot,
    // R
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic [AXI_DW-1:0]       s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    // ---- register-window integration ----
    output logic [N_REGS*32-1:0]    reg_rdata_o,   // whole window, flat
    output logic                    reg_we_o,      // 1-cycle write strobe
    output logic [N_REGS-1:0]       reg_waddr_o,   // one-hot window index
    output logic [31:0]             reg_wdata_o,
    output logic [3:0]              reg_wstrb_o,
    input  logic [N_REGS*32-1:0]    reg_rdata_i    // external overlay (else tie =reg_rdata_o)
);

    localparam int STRB_W   = AXI_DW / 8;
    localparam int IDX_W    = (N_REGS > 1) ? $clog2(N_REGS) : 1;

    // response codes (§3.1)
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // ------------------------------------------------------------------
    // Internal register window (RW). reg_rdata_o reflects it; a peripheral may
    // instead drive reg_rdata_i and ignore the internal store for overlaid regs.
    // ------------------------------------------------------------------
    logic [31:0] regs [0:N_REGS-1];

    genvar gi;
    generate
        for (gi = 0; gi < N_REGS; gi++) begin : g_rdata
            assign reg_rdata_o[gi*32 +: 32] = regs[gi];
        end
    endgenerate

    // ------------------------------------------------------------------
    // Input capture skid buffers (registered boundaries, §2 rule 1).
    // AW and W captured independently => AW/W decoupling (W-before-AW legal).
    // ------------------------------------------------------------------
    // AW
    logic                  aw_in_ready;
    logic                  aw_v;
    logic [AXI_AW-1:0]     aw_addr;
    logic [AXI_AW+2:0]     aw_pl_in, aw_pl_out;
    assign aw_pl_in = {s_axi_awaddr, s_axi_awprot};
    eth_axi_skidbuf #(.PW(AXI_AW+3)) u_aw_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_awvalid), .i_ready(s_axi_awready), .i_data(aw_pl_in),
        .o_valid(aw_v), .o_ready(aw_in_ready), .o_data(aw_pl_out)
    );
    assign aw_addr = aw_pl_out[AXI_AW+2:3];

    // W
    logic                  w_in_ready;
    logic                  w_v;
    logic [AXI_DW-1:0]     w_data;
    logic [STRB_W-1:0]     w_strb;
    logic [AXI_DW+STRB_W-1:0] w_pl_in, w_pl_out;
    assign w_pl_in = {s_axi_wdata, s_axi_wstrb};
    eth_axi_skidbuf #(.PW(AXI_DW+STRB_W)) u_w_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_wvalid), .i_ready(s_axi_wready), .i_data(w_pl_in),
        .o_valid(w_v), .o_ready(w_in_ready), .o_data(w_pl_out)
    );
    assign w_data = w_pl_out[AXI_DW+STRB_W-1:STRB_W];
    assign w_strb = w_pl_out[STRB_W-1:0];

    // AR
    logic                  ar_in_ready;
    logic                  ar_v;
    logic [AXI_AW-1:0]     ar_addr;
    logic [AXI_AW+2:0]     ar_pl_in, ar_pl_out;
    assign ar_pl_in = {s_axi_araddr, s_axi_arprot};
    eth_axi_skidbuf #(.PW(AXI_AW+3)) u_ar_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(s_axi_arvalid), .i_ready(s_axi_arready), .i_data(ar_pl_in),
        .o_valid(ar_v), .o_ready(ar_in_ready), .o_data(ar_pl_out)
    );
    assign ar_addr = ar_pl_out[AXI_AW+2:3];

    // ------------------------------------------------------------------
    // Address decode (window membership + word index). Pure functions of the
    // captured (registered) addresses — these feed always_comb defaults.
    // ------------------------------------------------------------------
    function automatic logic in_window(input logic [AXI_AW-1:0] a);
        logic [AXI_AW-1:0] off;
        begin
            off = a - REG_BASE;
            // in-window iff the byte offset into the window is below the window
            // size (N_REGS words = N_REGS*4 bytes). The wrap case (a < REG_BASE)
            // makes off huge, so the single bounded comparison covers it.
            // verilator lint_off UNSIGNED   // unsigned offset < bound is intended
            in_window = (off < (N_REGS * 4));
            // verilator lint_on UNSIGNED
        end
    endfunction
    function automatic logic [IDX_W-1:0] word_index(input logic [AXI_AW-1:0] a);
        // word index = (a - REG_BASE) / 4 (in-window callers only). The shift
        // result is truncated to IDX_W bits on assignment.
        word_index = IDX_W'((a - REG_BASE) >> 2);
    endfunction

    // ------------------------------------------------------------------
    // Write engine: fire when both AW and W beats are captured; produce B.
    // ------------------------------------------------------------------
    logic        wr_busy;                  // a B response is pending in b skid
    logic        b_v, b_ready;
    logic [1:0]  b_resp;
    logic [1:0]  b_pl_out;

    assign aw_in_ready = !wr_busy && aw_v && w_v;   // consume AW when paired
    assign w_in_ready  = !wr_busy && aw_v && w_v;   // consume W when paired

    logic        wr_fire;
    logic        wr_in_win;
    logic [IDX_W-1:0] wr_idx;
    assign wr_fire   = aw_v && w_v && !wr_busy;
    assign wr_in_win = in_window(aw_addr);
    assign wr_idx    = word_index(aw_addr);

    // register write (internal store + external strobe)
    integer bi;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (bi = 0; bi < N_REGS; bi++) regs[bi] <= 32'h0;
            reg_we_o    <= 1'b0;
            reg_waddr_o <= {N_REGS{1'b0}};
            reg_wdata_o <= 32'h0;
            reg_wstrb_o <= 4'h0;
        end else begin
            reg_we_o    <= 1'b0;
            reg_waddr_o <= {N_REGS{1'b0}};
            if (wr_fire && wr_in_win) begin
                reg_we_o          <= 1'b1;
                reg_waddr_o       <= N_REGS'(1) << wr_idx;
                reg_wdata_o       <= w_data;
                reg_wstrb_o       <= w_strb;
                for (bi = 0; bi < STRB_W; bi++)
                    if (w_strb[bi]) regs[wr_idx][bi*8 +: 8] <= w_data[bi*8 +: 8];
            end
        end
    end

    // B response skid buffer. i_valid is gated by !wr_busy (wr_fire), so the
    // buffer always has room; i_ready is therefore unused (folded into unused_*).
    logic b_skid_iready;
    assign b_resp  = wr_in_win ? RESP_OKAY : RESP_SLVERR;
    eth_axi_skidbuf #(.PW(2)) u_b_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(wr_fire), .i_ready(b_skid_iready), .i_data(b_resp),
        .o_valid(b_v), .o_ready(b_ready), .o_data(b_pl_out)
    );
    assign s_axi_bvalid = b_v;
    assign s_axi_bresp  = b_pl_out;
    assign b_ready      = s_axi_bready;
    // wr_busy blocks a second write until the B channel has drained. The b skid
    // holds 2 beats; we conservatively serialize writes (1 outstanding B) — a
    // full-speed v0.1 may track the skid occupancy to allow 2.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) wr_busy <= 1'b0;
        else begin
            if (wr_fire)                 wr_busy <= 1'b1;
            else if (b_v && b_ready)     wr_busy <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Read engine: fire when an AR beat is captured; produce R.
    // ------------------------------------------------------------------
    logic        rd_busy;
    logic        r_v, r_ready;
    logic [AXI_DW+1:0] r_pl_in, r_pl_out;
    logic        rd_fire;
    logic        rd_in_win;
    logic [IDX_W-1:0] rd_idx;
    logic [31:0] rd_word;

    assign ar_in_ready = !rd_busy && ar_v;
    assign rd_fire     = ar_v && !rd_busy;
    assign rd_in_win   = in_window(ar_addr);
    assign rd_idx      = word_index(ar_addr);
    // external overlay (reg_rdata_i) takes precedence when driven; v0 default
    // connects reg_rdata_i = reg_rdata_o so the internal window is read back.
    assign rd_word     = reg_rdata_i[rd_idx*32 +: 32];
    assign r_pl_in     = {rd_in_win ? RESP_OKAY : RESP_SLVERR,
                          rd_in_win ? rd_word : 32'h0};

    logic r_skid_iready;
    eth_axi_skidbuf #(.PW(AXI_DW+2)) u_r_skid (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .i_valid(rd_fire), .i_ready(r_skid_iready), .i_data(r_pl_in),
        .o_valid(r_v), .o_ready(r_ready), .o_data(r_pl_out)
    );
    assign s_axi_rvalid = r_v;
    assign s_axi_rresp  = r_pl_out[AXI_DW+1:AXI_DW];
    assign s_axi_rdata  = r_pl_out[AXI_DW-1:0];
    assign r_ready      = s_axi_rready;

    // aw/ar carry a prot field we do not interpret in v0; the response-skid
    // i_ready wires are don't-cares (buffers are sized so they never fill).
    // Fold them (and the prot bits) into a single reduction so -Wall stays clean.
    // verilator lint_off UNUSEDSIGNAL
    logic unused_ok;
    assign unused_ok = &{1'b0, aw_pl_out[2:0], ar_pl_out[2:0],
                          b_skid_iready, r_skid_iready};
    // verilator lint_on UNUSEDSIGNAL

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) rd_busy <= 1'b0;
        else begin
            if (rd_fire)             rd_busy <= 1'b1;
            else if (r_v && r_ready) rd_busy <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Formal properties (yosys-smtbmc via sby; hidden from verilator lint).
    // ------------------------------------------------------------------
`ifdef FORMAL
    logic past_valid = 1'b0;
    always_ff @(posedge clk_i) past_valid <= 1'b1;
    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // VALID stability (§7 prop 1) on every response/request channel.
            if ($past(s_axi_bvalid) && !$past(s_axi_bready))
                assert(s_axi_bvalid && s_axi_bresp == $past(s_axi_bresp));
            if ($past(s_axi_rvalid) && !$past(s_axi_rready)) begin
                assert(s_axi_rvalid && s_axi_rresp == $past(s_axi_rresp));
                assert(s_axi_rdata == $past(s_axi_rdata));
            end
            // B only after a write was accepted (no spurious B).
            if (s_axi_bvalid) assert(wr_busy || $past(wr_fire));
        end
        if (past_valid && !$past(rst_ni)) begin
            assert(!s_axi_bvalid && !s_axi_rvalid);
            assert(!wr_busy && !rd_busy);
        end
    end
`endif

endmodule
