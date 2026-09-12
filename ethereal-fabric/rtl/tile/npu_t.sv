`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      npu_t
// Description: NPU-Tiny service tile — INT8 8x8 systolic GEMM engine with a
//              service-register ABI, session isolation and observability.
// Details:     Tile-top for the first Service Tile (S11 §2.2, C11). Wraps
//              npu_arr8 (PE grid + stagger feeder + weight staging) with:
//                * a 32-bit little-endian service CSR block (the EBI mailbox
//                  endpoint is added by E3-SVC2; v1 is the register ABI only),
//                * the run FSM  IDLE -> LOAD_W -> RUN -> DRAIN -> DONE -> IDLE
//                  (C11 §2.3) plus a BLANK/session-clear cycle,
//                * the C output buffer (8x8 INT32) with per-column capture,
//                * session isolation: a session boundary (SESSION_ID write,
//                  CTRL.RESET or sess_rst_i) blanks EVERY session element, and
//                  DONE blanks the accumulators/weights/feeders while leaving the
//                  C buffer readable.
//              Arithmetic contract: products are exact INT8xINT8; every
//              accumulate step (each PE, and the C-buffer chunk accumulate when
//              CTRL.ACC_EN=1) saturates to INT32 with a sticky OVF flag. No
//              vendor primitive anywhere (ADR-017) — the multiplier is left for
//              the platform EDA to infer.
//              CSR map (byte offsets): 0x00 CTRL (W: [0]START [1]RESET [2]IRQ_EN
//              [3]ACC_EN [4]OVF_CLR), 0x04 STATUS (R), 0x08 DESC (W/R
//              {N,K,M}), 0x0C SESSION_ID (W/R; a write is a session boundary),
//              0x10 A_WR (W, 4 A bytes), 0x14 W_WR (W, 4 W bytes), 0x18 A_PTR,
//              0x1C W_PTR, 0x20 C_ADDR, 0x24 C_RD (R), 0x28 CYC_CNT (R).
//              A bytes are row-major (m,k) with K=8: byte pointer p -> m=p[5:3],
//              k0=0/4 by p[2]. W bytes are row-major (k,n) with N=8: pointer p ->
//              k=p[5:3], n0=0/4 by p[2]. C words are row-major (m,n).
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S11-Service-Tile.md §2.2 §3 ·
//              ethereal-plan/components/C11-NPU-Tiny组件.md §2 §3.2
// Notes:       LEAK_INJECT is a VERIFICATION-ONLY negative-control parameter
//              (default 0, logic optimises away): it skips the C-buffer blank at
//              a session boundary so tb_npu_isolation can demonstrate that its
//              no-leak assertions are able to fail.
//              ASSUMPTION (2026-09-13): v1 executes ONE K-chunk (K=8) per START;
//              K>8 is host tiled with CTRL.ACC_EN over consecutive STARTs of the
//              same session (C11 §2.4 leaves tiling to the driver).
//              ASSUMPTION (2026-09-13): DRAIN keeps the C11 N=8 cycles for the FSM
//              shape; the last functional capture is at cyc_r = M+14, so the final
//              drain cycle is slack (measured CYC_CNT = M+25).
//              ASSUMPTION (2026-09-13): DESCRIPTOR constraints M in [1,8], K == 8,
//              N == 8 (array height / one chunk / array width); anything else is
//              rejected with STATUS.DESC_ERR instead of being clipped silently.
//              ASSUMPTION (2026-09-13): a RUN CONSUMES both staged buffers — the A
//              feeder bytes are shifted out by the run and DONE blanks the whole
//              datapath including the W staging — so every START must be preceded
//              by re-staging A and W (natural for a K-tiling driver).
//              ASSUMPTION (2026-09-13): writing SESSION_ID is the session boundary
//              (it triggers the full blank); the tag itself survives CTRL.RESET,
//              because it is the authorizing daemon's token, not datapath state.
//              ASSUMPTION (2026-09-13): rst_ni clears the whole tile INCLUDING this
//              CSR block (unlike dsp_t/mem_t whose mode word survives rst) — the
//              CSR here is a service ABI, re-established by the daemon after reset.
//              ASSUMPTION (2026-09-13): START resets the A/W staging write pointers
//              (chunk-load protocol) so every run sees a fully rewritten buffer.
//              All of the above are aggregated in
//              docs/reports/report-E3-SVC1-npu-tiny-20260913.md §6. (TBD, 2026-09-13.)
module npu_t #(
    parameter bit LEAK_INJECT = 1'b0
) (
    input  logic         clk_i,
    input  logic         rst_ni,       // sync reset: full blank of the tile
    input  logic         sess_rst_i,   // fabric/OCC blank (blank-before-write)
    // ---- service register ABI (the EBI endpoint is added by E3-SVC2) ----
    input  logic         csr_we_i,
    input  logic         csr_re_i,
    input  logic [7:0]   csr_addr_i,
    input  logic [31:0]  csr_wdata_i,
    output logic [31:0]  csr_rdata_o,
    output logic         irq_o,        // DONE interrupt (if CTRL.IRQ_EN)
    // ---- observability (house convention: wide obs buses, cf. fabric_top) ----
    output logic [2047:0] obs_acc_o,   // PE accumulators  (session state)
    output logic [511:0]  obs_wgt_o,   // PE weights       (session state)
    output logic [511:0]  obs_wstg_o,  // W staging buffer (session state)
    output logic [511:0]  obs_feed_o,  // A feeder shifters (session state)
    output logic [2047:0] obs_cbuf_o,  // C output buffer  (session state)
    output logic [79:0]   obs_ctl_o    // FSM/counters/flags/session tag (see §4)
);
    // ---------------- service registers ----------------
    localparam logic [7:0] CSR_CTRL   = 8'h00;
    localparam logic [7:0] CSR_STATUS = 8'h04;
    localparam logic [7:0] CSR_DESC   = 8'h08;
    localparam logic [7:0] CSR_SESSID = 8'h0C;
    localparam logic [7:0] CSR_AWR    = 8'h10;
    localparam logic [7:0] CSR_WWR    = 8'h14;
    localparam logic [7:0] CSR_APTR   = 8'h18;
    localparam logic [7:0] CSR_WPTR   = 8'h1C;
    localparam logic [7:0] CSR_CADDR  = 8'h20;
    localparam logic [7:0] CSR_CRD    = 8'h24;
    localparam logic [7:0] CSR_CYC    = 8'h28;

    typedef enum logic [2:0] {
        ST_IDLE  = 3'd0,
        ST_LOADW = 3'd1,
        ST_RUN   = 3'd2,
        ST_DRAIN = 3'd3,
        ST_DONE  = 3'd4,
        ST_CLR   = 3'd5
    } st_e;

    st_e         st_r, st_nxt;
    logic        clr_req_r;
    logic        start_pend_r;
    logic [2:0]  ld_cnt_r;
    logic [5:0]  cyc_r;
    logic [31:0] cyc_cnt_r;
    logic [7:0]  m_r, k_r, n_r;
    logic [15:0] sess_id_r;
    logic [5:0]  a_wr_ptr_r;
    logic [5:0]  w_wr_ptr_r;
    logic [5:0]  c_rd_ptr_r;
    logic        acc_en_r;
    logic        irq_en_r;
    logic        irq_r, done_r, ovf_sticky_r, desc_err_r, cap_ovf_r;

    // C output buffer: 8 rows x 8 columns of INT32; one variable per column so
    // each capture column stays a single driver (no MULTIDRIVEN).
    logic [31:0] cbuf_col [0:7][0:7];

    // ---------------- control decode ----------------
    logic         arr_en, w_load, busy_w, clr_all, clr_dp, start_ok;
    logic [7:0]   feed_en_oh, a_wr_oh, w_wr_oh;
    logic [255:0] col_q;
    logic         arr_ovf;
        logic [7:0]   cap_sat_w;
    logic         cap_ovf_w;
    logic [2:0]   w_ld_col;
    logic         a_wr_hit, w_wr_hit, c_rd_hit, ovf_clr_w, desc_bad_w, cap_sat_any_w;
    logic signed [31:0] cbuf_rd;

    assign arr_en   = (st_r == ST_RUN) || (st_r == ST_DRAIN);
    assign w_load   = (st_r == ST_LOADW);
    assign w_ld_col = ld_cnt_r;
    assign busy_w   = (st_r == ST_LOADW) || (st_r == ST_RUN) || (st_r == ST_DRAIN);
    assign clr_all  = (st_r == ST_CLR);
    assign clr_dp   = (st_r == ST_DONE);
    assign start_ok = (m_r >= 8'd1) && (m_r <= 8'd8) && (k_r == 8'd8) && (n_r == 8'd8);

    assign a_wr_hit = csr_we_i && (csr_addr_i == CSR_AWR) && !busy_w && (st_r != ST_DONE);
    assign w_wr_hit = csr_we_i && (csr_addr_i == CSR_WWR) && !busy_w && (st_r != ST_DONE);
    assign c_rd_hit = csr_re_i && (csr_addr_i == CSR_CRD);
    assign ovf_clr_w = csr_we_i && (csr_addr_i == CSR_CTRL) && csr_wdata_i[4];
    assign desc_bad_w = (st_r == ST_IDLE) && start_pend_r && !start_ok;
    assign cap_ovf_w  = |cap_sat_w;
    assign cap_sat_any_w = ((st_r == ST_RUN) || (st_r == ST_DRAIN)) && cap_ovf_w;

    // Feeder row skew: row r starts shifting at cycle r (V_r[x] = A[x-r][r]).
    assign feed_en_oh[0] = arr_en;
    assign feed_en_oh[1] = arr_en && (cyc_r >= 6'd1);
    assign feed_en_oh[2] = arr_en && (cyc_r >= 6'd2);
    assign feed_en_oh[3] = arr_en && (cyc_r >= 6'd3);
    assign feed_en_oh[4] = arr_en && (cyc_r >= 6'd4);
    assign feed_en_oh[5] = arr_en && (cyc_r >= 6'd5);
    assign feed_en_oh[6] = arr_en && (cyc_r >= 6'd6);
    assign feed_en_oh[7] = arr_en && (cyc_r >= 6'd7);
    assign a_wr_oh = a_wr_hit ? (a_wr_ptr_r[2] ? 8'hF0 : 8'h0F) : 8'h00;

    always_comb begin
        w_wr_oh = 8'h00;
        if (w_wr_hit) begin
            w_wr_oh[w_wr_ptr_r[5:3]] = 1'b1;
        end
    end

    // ---------------- array datapath ----------------
    npu_arr8 #(.LEAK_INJECT(LEAK_INJECT)) u_arr (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .clr_i        (clr_all | clr_dp),
        .a_wr_oh_i    (a_wr_oh),
        .a_pos_i      (a_wr_ptr_r[5:3]),
        .a_wdata_i    (csr_wdata_i),
        .w_wr_oh_i    (w_wr_oh),
        .w_col_hi_i   (w_wr_ptr_r[2]),
        .w_wdata_i    (csr_wdata_i),
        .shf_en_i     (arr_en),
        .feed_en_oh_i (feed_en_oh),
        .w_load_i     (w_load),
        .w_ld_col_i   (w_ld_col),
        .col_o        (col_q),
        .ovf_o        (arr_ovf),
        .obs_feed_o   (obs_feed_o),
        .obs_wstg_o   (obs_wstg_o),
        .obs_wgt_o    (obs_wgt_o),
        .obs_acc_o    (obs_acc_o)
    );

    // ---------------- FSM ----------------
    always_comb begin
        st_nxt = st_r;
        if (clr_req_r && (st_r != ST_CLR)) begin
            st_nxt = ST_CLR;                       // blank has top priority (abort)
        end else begin
            case (st_r)
                ST_IDLE:  if (start_pend_r && start_ok)            st_nxt = ST_LOADW;
                ST_LOADW: if (ld_cnt_r == 3'd7)                    st_nxt = ST_RUN;
                ST_RUN:   if (cyc_r == ({1'b0, m_r[4:0]} + 6'd7))  st_nxt = ST_DRAIN;
                ST_DRAIN: if (cyc_r == ({1'b0, m_r[4:0]} + 6'd15)) st_nxt = ST_DONE;
                ST_DONE:                                           st_nxt = ST_IDLE;
                ST_CLR:                                            st_nxt = ST_IDLE;
                default:                                           st_nxt = ST_IDLE;
            endcase
        end
    end

    // ---------------- C buffer capture ----------------
    // Column n's chain output during cycle y is C[m][n] with m = y - 8 - n, so
    // every column stores its own row at its own cycle (no deskew chain needed).
    // The last column's last row is captured at cyc_r = M+14, i.e. during DRAIN.
    generate
        for (genvar c = 0; c < 8; c++) begin : g_capture
            localparam logic [5:0] CAP_LO = 6'd8 + c[5:0];
            localparam logic [5:0] CAP_C  = c[5:0];
            logic [5:0]          cap_hi;
            logic [2:0]          cap_m;
            logic                cap_en;
            logic                cap_sat;
            logic signed [32:0]  cap_sum;   // signed: the saturation rails are signed
            logic [31:0]         cap_old;
            logic [31:0]         cap_nxt;

            assign cap_hi  = {1'b0, m_r[4:0]} + 6'd8 + CAP_C;
            // m == cyc_r - (8+c); mod 8 the -8 vanishes, so the low 3 bits suffice.
            assign cap_m   = cyc_r[2:0] - CAP_C[2:0];
            assign cap_en  = ((st_r == ST_RUN) || (st_r == ST_DRAIN)) &&
                             (cyc_r >= CAP_LO) && (cyc_r < cap_hi);
            assign cap_old = cbuf_col[c][cap_m];

            // CTRL.ACC_EN: accumulate this chunk into the C buffer (K tiling).
            assign cap_sum = {{1{cap_old[31]}}, cap_old} + {{1{col_q[32*c + 31]}}, col_q[32*c +: 32]};
            assign cap_sat = (cap_sum > 33'sd2147483647) || (cap_sum < -33'sd2147483648);
            assign cap_nxt = cap_sat ? (cap_sum[32] ? 32'h80000000 : 32'h7FFFFFFF)
                                     : cap_sum[31:0];
            assign cap_sat_w[c] = cap_sat;

            always_ff @(posedge clk_i) begin
                if (!rst_ni) begin
                    cbuf_col[c][0] <= 32'h0;
                    cbuf_col[c][1] <= 32'h0;
                    cbuf_col[c][2] <= 32'h0;
                    cbuf_col[c][3] <= 32'h0;
                    cbuf_col[c][4] <= 32'h0;
                    cbuf_col[c][5] <= 32'h0;
                    cbuf_col[c][6] <= 32'h0;
                    cbuf_col[c][7] <= 32'h0;
                end else if (clr_all) begin
                    if (!LEAK_INJECT) begin
                        // Session boundary: the C buffer MUST blank (S11 §2.1 —
                        // a residue here is a cross-container data leak).
                        cbuf_col[c][0] <= 32'h0;
                        cbuf_col[c][1] <= 32'h0;
                        cbuf_col[c][2] <= 32'h0;
                        cbuf_col[c][3] <= 32'h0;
                        cbuf_col[c][4] <= 32'h0;
                        cbuf_col[c][5] <= 32'h0;
                        cbuf_col[c][6] <= 32'h0;
                        cbuf_col[c][7] <= 32'h0;
                    end
                end else if (cap_en) begin
                    cbuf_col[c][cap_m] <= acc_en_r ? cap_nxt : col_q[32*c +: 32];
                end
            end
        end
    endgenerate

    // ---------------- CSR read mux ----------------
    assign cbuf_rd = cbuf_col[c_rd_ptr_r[2:0]][c_rd_ptr_r[5:3]];
    always_comb begin
        csr_rdata_o = 32'h0;
        case (csr_addr_i)
            CSR_CTRL:   csr_rdata_o = {28'h0, acc_en_r, irq_en_r, 2'b00};
            CSR_STATUS: csr_rdata_o = {sess_id_r, 5'b0, st_r, 3'b0,
                                       desc_err_r, irq_r, ovf_sticky_r, done_r, busy_w};
            CSR_DESC:   csr_rdata_o = {8'h00, n_r, k_r, m_r};
            CSR_SESSID: csr_rdata_o = {16'h0000, sess_id_r};
            CSR_APTR:   csr_rdata_o = {26'h0, a_wr_ptr_r};
            CSR_WPTR:   csr_rdata_o = {26'h0, w_wr_ptr_r};
            CSR_CADDR:  csr_rdata_o = {26'h0, c_rd_ptr_r};
            CSR_CRD:    csr_rdata_o = cbuf_rd;
            CSR_CYC:    csr_rdata_o = cyc_cnt_r;
            default:    csr_rdata_o = 32'h0;
        endcase
    end

    // ---------------- sequential control ----------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            st_r         <= ST_IDLE;
            ld_cnt_r     <= 3'd0;
            cyc_r        <= 6'd0;
            cyc_cnt_r    <= 32'd0;
            m_r          <= 8'd0;
            k_r          <= 8'd0;
            n_r          <= 8'd0;
            sess_id_r    <= 16'h0000;
            a_wr_ptr_r   <= 6'd0;
            w_wr_ptr_r   <= 6'd0;
            c_rd_ptr_r   <= 6'd0;
            acc_en_r     <= 1'b0;
            irq_en_r     <= 1'b0;
            irq_r        <= 1'b0;
            done_r       <= 1'b0;
            ovf_sticky_r <= 1'b0;
            desc_err_r   <= 1'b0;
            cap_ovf_r    <= 1'b0;
            clr_req_r    <= 1'b0;
            start_pend_r <= 1'b0;
        end else begin
            clr_req_r    <= 1'b0;
            start_pend_r <= 1'b0;

            // ---- service register writes ----
            if (csr_we_i) begin
                case (csr_addr_i)
                    CSR_CTRL: begin
                        irq_en_r <= csr_wdata_i[2];
                        acc_en_r <= csr_wdata_i[3];
                        if (csr_wdata_i[0]) begin
                            start_pend_r <= 1'b1;
                        end
                        if (csr_wdata_i[1]) begin
                            clr_req_r <= 1'b1;
                        end
                    end
                    CSR_SESSID: begin
                        sess_id_r <= csr_wdata_i[15:0];
                        clr_req_r <= 1'b1;        // a new session blanks the tile
                    end
                    CSR_DESC: begin
                        m_r <= csr_wdata_i[7:0];
                        k_r <= csr_wdata_i[15:8];
                        n_r <= csr_wdata_i[23:16];
                    end
                    CSR_APTR:  a_wr_ptr_r <= csr_wdata_i[5:0];
                    CSR_WPTR:  w_wr_ptr_r <= csr_wdata_i[5:0];
                    CSR_CADDR: c_rd_ptr_r <= csr_wdata_i[5:0];
                    CSR_AWR:   if (a_wr_hit) begin
                                   a_wr_ptr_r <= a_wr_ptr_r + 6'd4;
                               end
                    CSR_WWR:   if (w_wr_hit) begin
                                   w_wr_ptr_r <= w_wr_ptr_r + 6'd4;
                               end
                    CSR_CRD:   c_rd_ptr_r <= c_rd_ptr_r + 6'd1;
                    default: ;
                endcase
            end
            if (c_rd_hit) begin
                c_rd_ptr_r <= c_rd_ptr_r + 6'd1;
            end
            if (csr_re_i && (csr_addr_i == CSR_STATUS)) begin
                irq_r <= 1'b0;                    // STATUS read acknowledges IRQ
            end
            if (sess_rst_i) begin
                clr_req_r <= 1'b1;                // fabric blank
            end

            // ---- FSM advance + counters ----
            st_r <= st_nxt;
            if ((st_nxt == ST_LOADW) && (st_r != ST_LOADW)) begin
                ld_cnt_r  <= 3'd0;
                cyc_cnt_r <= 32'd0;
                done_r    <= 1'b0;
                // Chunk-load protocol: every run consumes a whole 8x8 A/W buffer, so
                // both staging pointers restart at 0 on START. This makes the K>8
                // "load -> START -> load -> START" tiling flow pointer-free for the
                // host and guarantees each run sees a fully rewritten buffer.
                a_wr_ptr_r <= 6'd0;
                w_wr_ptr_r <= 6'd0;
            end
            if (st_r == ST_LOADW) begin
                ld_cnt_r <= ld_cnt_r + 3'd1;
            end
            if ((st_nxt == ST_RUN) && (st_r != ST_RUN)) begin
                cyc_r <= 6'd0;
            end
            if ((st_r == ST_RUN) || (st_r == ST_DRAIN)) begin
                cyc_r <= cyc_r + 6'd1;
            end
            if (busy_w || (st_r == ST_DONE)) begin
                cyc_cnt_r <= cyc_cnt_r + 32'd1;
            end
            if ((st_nxt == ST_DONE) && (st_r != ST_DONE)) begin
                done_r <= 1'b1;
                irq_r  <= irq_en_r;
            end

            // ---- sticky status (OR of datapath flags, clear via CTRL.OVF_CLR) ----
            ovf_sticky_r <= (ovf_sticky_r | arr_ovf | cap_sat_any_w) & ~ovf_clr_w;
            cap_ovf_r    <= (cap_ovf_r | cap_sat_any_w) & ~ovf_clr_w;
            desc_err_r   <= (desc_err_r | desc_bad_w) & ~ovf_clr_w;

            // ---- session blank (blank-before-write, S11 §2.1 / region reconfig) ----
            if (clr_all) begin
                ld_cnt_r     <= 3'd0;
                cyc_r        <= 6'd0;
                cyc_cnt_r    <= 32'd0;
                m_r          <= 8'd0;
                k_r          <= 8'd0;
                n_r          <= 8'd0;
                a_wr_ptr_r   <= 6'd0;
                w_wr_ptr_r   <= 6'd0;
                c_rd_ptr_r   <= 6'd0;
                acc_en_r     <= 1'b0;
                irq_r        <= 1'b0;
                done_r       <= 1'b0;
                ovf_sticky_r <= 1'b0;
                desc_err_r   <= 1'b0;
                cap_ovf_r    <= 1'b0;
            end
        end
    end

    assign irq_o = irq_r;

    // obs_cbuf: row-major flattening of the C buffer (row m, column c).
    generate
        for (genvar m = 0; m < 8; m++) begin : g_obs_row
            for (genvar c = 0; c < 8; c++) begin : g_obs_col
                assign obs_cbuf_o[32*(8*m + c) +: 32] = cbuf_col[c][m];
            end
        end
    endgenerate

    // obs_ctl: FSM/counters/flags/session tag (isolation check surface, report §4).
    assign obs_ctl_o[2:0]   = st_r;
    assign obs_ctl_o[3]     = busy_w;
    assign obs_ctl_o[4]     = done_r;
    assign obs_ctl_o[5]     = ovf_sticky_r;
    assign obs_ctl_o[6]     = irq_r;
    assign obs_ctl_o[7]     = desc_err_r;
    assign obs_ctl_o[8]     = acc_en_r;
    assign obs_ctl_o[13:9]  = cyc_r[4:0];
    assign obs_ctl_o[16:14] = ld_cnt_r;
    assign obs_ctl_o[22:17] = c_rd_ptr_r;
    assign obs_ctl_o[28:23] = a_wr_ptr_r;
    assign obs_ctl_o[34:29] = w_wr_ptr_r;
    assign obs_ctl_o[42:35] = m_r;
    assign obs_ctl_o[50:43] = k_r;
    assign obs_ctl_o[58:51] = n_r;
    assign obs_ctl_o[63:59] = 5'b0;
    assign obs_ctl_o[79:64] = sess_id_r;
endmodule

`default_nettype wire
