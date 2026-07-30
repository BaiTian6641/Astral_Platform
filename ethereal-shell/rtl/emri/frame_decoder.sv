`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      frame_decoder
// Description: Bit-packed frame decoder / column configuration controller.
// Details:     Bridges the OCC frame bus (bit-PACKED production format, the
//              frame_map.py / heterogeneous-config-v0.md SoT) and the fabric_top
//              cfg port (cfg-addr-addressed). For ONE column: the OCC streams the
//              column's packed 32-bit DATA words over the frame bus; the decoder
//              buffers them, then walks the per-tile bit-fields in frame order
//              **CB -> SB -> logic(CLB/MEM/DSP)** (frame_map.tile_points_at) and
//              issues ONE fabric cfg write per config point (cfg_we pulse,
//              cfg_addr={tile,unit,intra}, cfg_data=value zero-extended).
//
//              This closes the gap between the management plane (which v0 loaded
//              via the cfg-addr-addressed v0 format — one 32-bit word per config
//              reg, direct-wired OCC.fbus -> fabric_top.cfg) and the REAL bitgen
//              output (a column of tiles' config bits packed into 32-bit words +
//              a CRC16 tail). The decoder is the "column controller" of C01 §5 /
//              C03 §0: it owns no config storage — it only re-formatss the packed
//              bits into the fabric's per-register cfg writes.
//
//              FRAME FORMAT (frame_map.py, LSB-first within/across words):
//                per tile(row): CB(108=18x6) -> SB(120=48x2 + 8x1 en + 8x2 dir)
//                               -> logic(CLB 320=8x20+32x5 | MEM 70 | DSP 118)
//                column = R tiles concatenated, padded to whole words, + CRC16 tail.
//              The CRC16 tail word is streamed too but NOT decoded to the fabric
//              (and not verified in v0 — the OCC does its own streaming CRC32;
//              see Notes). Decoder consumes column_data_words(col) DATA words and
//              ignores the tail.
//
//              CFG ADDRESS (fabric_top.sv): cfg_addr = {tile_idx[TIW-1:0]@[7+TIW:8],
//              unit[1:0]@[7:6], intra[5:0]@[5:0]}; TIW=$clog2(R*C); tile_idx=r*C+c.
//              unit: 00=CLB, 01=SB, 10=CB, 11=TILE-MODE(het).
//
//              DEMUX specials (packed point -> fabric intra map):
//                * SB inject: frame packs inj_en_0..7 (8 x 1b) THEN inj_dir_0..7
//                  (8 x 2b) as SEPARATE groups; the RTL wants per-j 3b {dir@2:1,
//                  en@0} at intra 48+j. The decoder gathers en_j + dir_j -> 1 write.
//                * MEM mem_vbus_ctrl (22b, ONE packed point) -> ONE write to intra1
//                  (fabric_top decodes va/ven/vwe fields from the single word).
//                * DSP dsp_vcasc (48b) -> intra4 (hi 32 of [47:16]) + intra5 (lo 16).
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §5 ·
//              ethereal-plan/components/C03-OCC组件.md §0 ·
//              ethereal-spec/fabric/heterogeneous-config-v0.md §3
// Notes:       v0 SKIPS CRC16 verification (crc_error_o tied 0): the OCC already
//              accumulates a streaming CRC32 over the same words (occ_top), and
//              bitgen-side integrity is frame_map.crc16-verified at pack/unpack
//              time. Frame-level CRC16 check in the decoder is a documented v1
//              follow-up. Config-path module (NOT the user critical path): 1 cfg
//              write/cycle. ASSUMPTION (TBD 2026-07-30): the OCC streams exactly
//              column_data_words(col) DATA words before the CRC tail; the decoder
//              counts DATA words and leaves the tail unread (the OCC's word_count
//              for a packed deploy = column_data_words, tail excluded — matching
//              how bitgen/OCC treat the CRC as a transport trailer, not config).
module frame_decoder #(
    parameter int R = 2,
    parameter int C = 2,
    parameter int W = 12,
    parameter int N = 8,
    parameter int K = 4,
    parameter int EXT_IN = 18,
    parameter int SELW = 5,               // IIB mux select width ($clog2(EXT_IN+N) pow2)
    // TILE layout: R*C-entry build-time map (matches fabric_top TILE_TYPE).
    //   0=CLB, 1=MEM, 2=DSP. Index r*C+c, 8-bit entries, entry 0 at the LSB end.
    parameter logic [R*C*8-1:0] TILE_TYPE = {(R*C*8){1'b0}},
    // Max DATA words the buffer holds = ceil(R * max_tile_bits / 32). The widest
    // tile is CLB (548 bits); MEM=298, DSP=346. Use CLB as the (conservative) max.
    parameter int MAX_WORDS = (R * 548 + 31) / 32
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    // ---- control handshake ----
    input  logic        start_i,          // pulse: begin a decode for column col_i
    input  logic [7:0]  col_i,            // which fabric column (0..C-1)
    output logic        busy_o,           // 1 while streaming/decoding
    output logic        done_o,           // 1-cycle pulse when the column is decoded
    // ---- OCC frame bus in (word stream for ONE column) ----
    input  logic [15:0] fbus_addr_i,      // frame_base + word_idx (OCC increments)
    input  logic [31:0] fbus_wdata_i,
    input  logic        fbus_we_i,
    input  logic [15:0] frame_base_i,     // base addr of this column's frame
    // ---- fabric cfg out (one write per config point) ----
    output logic        cfg_we_o,
    output logic [15:0] cfg_addr_o,
    output logic [31:0] cfg_data_o,
    // ---- status ----
    output logic        crc_error_o       // v0: tied 0 (CRC16 verify deferred, Notes)
);

    // ------------------------------------------------------------------
    // Derived parameters
    // ------------------------------------------------------------------
    localparam int NTILES = R * C;
    localparam int TIW    = (NTILES > 1) ? $clog2(NTILES) : 1;
    localparam int N_CB   = EXT_IN;              // 18 clb_in muxes
    localparam int CB_SELW = (4*W > 1) ? $clog2(4*W) : 1;  // 6 for W=12
    localparam int N_INJ  = N;                   // inject count (= clb_out count)

    // per-block bit widths (must match frame_map.py)
    localparam int CB_BITS  = N_CB * CB_SELW;                 // 108
    localparam int SB_BITS  = 4*W*2 + N_INJ*1 + N_INJ*2;      // 120
    localparam int CLB_BITS = N*20 + N*K*SELW;                // 320
    localparam int MEM_BITS = 16 + 22 + 32;                   // 70
    localparam int DSP_BITS = 24 + 27 + 18 + 1 + 48;          // 118

    // unit codes (fabric_top)
    localparam logic [1:0] U_CLB = 2'b00;
    localparam logic [1:0] U_SB  = 2'b01;
    localparam logic [1:0] U_CB  = 2'b10;
    localparam logic [1:0] U_TM  = 2'b11;

    // TILE_TYPE codes (frame_map TT_*)
    localparam logic [7:0] TT_CLB = 8'd0;
    localparam logic [7:0] TT_MEM = 8'd1;
    localparam logic [7:0] TT_DSP = 8'd2;

    // ------------------------------------------------------------------
    // Word buffer (the packed column's DATA words)
    // ------------------------------------------------------------------
    logic [31:0] fbuf [0:MAX_WORDS-1];
    logic [15:0] col_latched;       // latched column index
    logic [15:0] nwords_r;          // DATA words expected for this column

    // per-tile logic-bit width by type (combinational lookup)
    function automatic int logic_bits(input logic [7:0] tt);
        case (tt)
            TT_MEM:  return MEM_BITS;
            TT_DSP:  return DSP_BITS;
            default: return CLB_BITS;   // TT_CLB and any unknown -> CLB
        endcase
    endfunction

    function automatic logic [7:0] tile_type_at(input int idx);
        return TILE_TYPE[idx*8 +: 8];
    endfunction

    // DATA words for the latched column = ceil(sum_r bits(tile(col,r)) / 32).
    // Combinational walk over the R rows of the latched column.
    function automatic int column_data_words(input int col);
        int total;
        int rr;
        logic [7:0] tt;
        begin
            total = 0;
            for (rr = 0; rr < R; rr = rr + 1) begin
                tt = tile_type_at(rr*C + col);
                total = total + CB_BITS + SB_BITS + logic_bits(tt);
            end
            return (total + 31) / 32;
        end
    endfunction

    // ------------------------------------------------------------------
    // Bit extraction: read `wid` bits LSB-first starting at absolute bit
    // offset `off` from the word buffer. Combinational (the fields are narrow,
    // <= 48 bits, so this is a small shifter network).
    // ------------------------------------------------------------------
    function automatic logic [47:0] get_bits(input int off, input int wid);
        int w0, i;
        logic [4:0] b0;
        logic [47:0] v;
        begin
            v = 48'b0;
            for (i = 0; i < 48; i = i + 1) begin
                if (i < wid) begin
                    w0 = (off + i) / 32;
                    b0 = 5'((off + i) % 32);
                    if (w0 < MAX_WORDS) v[i] = fbuf[w0][b0];
                end
            end
            return v;
        end
    endfunction

    // ------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_STREAM,
        ST_SETUP,   // compute per-tile base offsets, reset point walker
        ST_DECODE,  // walk config points, issue 1 cfg write/cycle
        ST_DONE
    } state_e;

    state_e state_r, state_nxt;

    // stream bookkeeping
    logic [15:0] cap_count_r;      // DATA words captured so far

    // decode bookkeeping
    int  tile_r;                    // current row (0..R-1)
    int  bit_base_r;                // absolute bit offset of current tile's CB start
    int  phase_r;                   // 0=CB 1=SB-mux 2=SB-inj 3=logic
    int  idx_r;                     // index within the current phase
    logic [7:0] cur_tt_r;           // current tile type

    // combinational per-phase point count + emission
    // We emit one cfg write per state in ST_DECODE and advance idx/phase/tile.
    logic        c_start;           // IDLE: start accepted
    logic        c_capture;         // STREAM: a DATA word captured
    logic        c_emit;            // DECODE: emit one cfg write this cycle
    logic        c_adv;             // DECODE: advance the walker
    logic        c_done;            // DECODE: all points walked

    // current tile's logic-bit width (for phase-3 point count)
    int cur_logic_bits;
    always_comb begin
        cur_logic_bits = logic_bits(cur_tt_r);
    end

    // ------------------------------------------------------------------
    // Decode walker — computes the cfg write for the CURRENT (tile,phase,idx).
    // Combinational next-state + output. Defaults first (no latches).
    // ------------------------------------------------------------------
    // per-phase counts
    function automatic int phase_count(input int phase, input logic [7:0] tt);
        case (phase)
            0: return N_CB;                 // CB: 18 sel
            1: return 4*W;                  // SB Wilton mux: 48
            2: return N_INJ;                // SB inject: 8 (en+dir combined)
            default: begin                  // logic points (CLB/MEM/DSP)
                case (tt)
                    TT_MEM:  return 3;      // mem_mode, mem_vbus_ctrl, mem_vd_i
                    TT_DSP:  return 6;      // mode, va, vb, ven, vcasc_hi, vcasc_lo
                    default: return N + N*K;// CLB: 8 eLUT + 32 iib
                endcase
            end
        endcase
    endfunction

    // bit offset of a phase's start within the current tile (relative to bit_base_r)
    function automatic int phase_bit_off(input int phase);
        case (phase)
            0: return 0;                    // CB at tile start
            1: return CB_BITS;              // SB mux after CB
            2: return CB_BITS + 4*W*2;      // SB inj-en group after mux
            default: return CB_BITS + SB_BITS;  // logic after CB+SB
        endcase
    endfunction

    // Compute the cfg write (unit, intra, data) for the current walker position.
    // Combinational. Uses get_bits on absolute offsets.
    logic [1:0]  emit_unit;
    logic [5:0]  emit_intra;
    logic [31:0] emit_data;
    logic        emit_valid;

    // scratch for inject demux
    int  en_off, dir_off;
    // get_bits returns a 48-bit vector; iverilog cannot slice a function return
    // inline (func(...)[x:y]), so route every get_bits call through an
    // intermediate wire SIZED to the actual field width (also keeps verilator
    // -Wall UNUSEDSIGNAL-clean: the upper bits of a shared 48-bit reg would be
    // flagged unused). Assign the low field bits; the function's upper bits are
    // zero (get_bits zero-pads), so this is exact.
    logic [CB_SELW-1:0] gb_cb;
    logic [1:0]         gb_mux;
    logic [1:0]         gb_inj_dir;
    logic               gb_inj_en;
    logic [15:0]        gb_mem0;
    logic [21:0]        gb_mem1;
    logic [31:0]        gb_mem2;
    logic [23:0]        gb_dsp0;
    logic [26:0]        gb_dsp1;
    logic [17:0]        gb_dsp2;
    logic               gb_dsp3;
    logic [31:0]        gb_dsp4;
    logic [15:0]        gb_dsp5;
    logic [19:0]        gb_clb_lut;
    logic [SELW-1:0]    gb_clb_iib;

    always_comb begin
        // compute all get_bits reads (harmless when not selected: combinational).
        gb_cb      = CB_SELW'(get_bits(bit_base_r + phase_bit_off(0) + idx_r*CB_SELW, CB_SELW));
        gb_mux     = 2'(get_bits(bit_base_r + phase_bit_off(1) + idx_r*2, 2));
        en_off     = bit_base_r + phase_bit_off(2) + idx_r;            // 1 bit
        dir_off    = bit_base_r + phase_bit_off(2) + N_INJ + idx_r*2;  // 2 bits
        gb_inj_dir = 2'(get_bits(dir_off, 2));
        gb_inj_en  = 1'(get_bits(en_off, 1));
        gb_mem0    = 16'(get_bits(bit_base_r + phase_bit_off(3) + 0, 16));
        gb_mem1    = 22'(get_bits(bit_base_r + phase_bit_off(3) + 16, 22));
        gb_mem2    = 32'(get_bits(bit_base_r + phase_bit_off(3) + 16 + 22, 32));
        gb_dsp0    = 24'(get_bits(bit_base_r + phase_bit_off(3) + 0, 24));
        gb_dsp1    = 27'(get_bits(bit_base_r + phase_bit_off(3) + 24, 27));
        gb_dsp2    = 18'(get_bits(bit_base_r + phase_bit_off(3) + 24 + 27, 18));
        gb_dsp3    = 1'(get_bits(bit_base_r + phase_bit_off(3) + 24 + 27 + 18, 1));
        gb_dsp4    = 32'(get_bits(bit_base_r + phase_bit_off(3) + 24 + 27 + 18 + 1 + 16, 32));
        gb_dsp5    = 16'(get_bits(bit_base_r + phase_bit_off(3) + 24 + 27 + 18 + 1, 16));
        gb_clb_lut = 20'(get_bits(bit_base_r + phase_bit_off(3) + idx_r*20, 20));
        gb_clb_iib = SELW'(get_bits(bit_base_r + phase_bit_off(3) + N*20 + (idx_r-N)*SELW, SELW));

        emit_unit  = U_CLB;
        emit_intra = 6'd0;
        emit_data  = 32'b0;
        emit_valid = 1'b1;
        case (phase_r)
            0: begin  // CB: idx -> cb_sel_#idx (6b) at intra=idx
                emit_unit  = U_CB;
                emit_intra = 6'(idx_r);
                emit_data  = {26'b0, gb_cb[CB_SELW-1:0]};
            end
            1: begin  // SB Wilton mux: idx -> mux (2b) at intra=idx (0..47)
                emit_unit  = U_SB;
                emit_intra = 6'(idx_r);
                emit_data  = {30'b0, gb_mux[1:0]};
            end
            2: begin  // SB inject: idx=j -> {dir@2:1, en@0} (3b) at intra=48+j
                // en_j is bit j of the inj-en group (at phase_bit_off(2));
                // dir_j is 2 bits at (inj-dir group start = en group start + N_INJ).
                emit_unit  = U_SB;
                emit_intra = 6'(4*W + idx_r);
                emit_data  = {29'b0, gb_inj_dir[1:0], gb_inj_en};
            end
            default: begin  // logic block by tile type
                case (cur_tt_r)
                    TT_MEM: begin
                        emit_unit = U_TM;
                        case (idx_r)
                            0: begin  // mem_mode (16b) -> intra0
                                emit_intra = 6'd0;
                                emit_data  = {16'b0, gb_mem0[15:0]};
                            end
                            1: begin  // mem_vbus_ctrl (22b) -> intra1 (fabric decodes fields)
                                emit_intra = 6'd1;
                                emit_data  = {10'b0, gb_mem1[21:0]};
                            end
                            default: begin  // mem_vd_i (32b) -> intra2
                                emit_intra = 6'd2;
                                emit_data  = gb_mem2[31:0];
                            end
                        endcase
                    end
                    TT_DSP: begin
                        emit_unit = U_TM;
                        case (idx_r)
                            0: begin  // dsp_mode (24b) -> intra0
                                emit_intra = 6'd0;
                                emit_data  = {8'b0, gb_dsp0[23:0]};
                            end
                            1: begin  // dsp_va (27b) -> intra1
                                emit_intra = 6'd1;
                                emit_data  = {5'b0, gb_dsp1[26:0]};
                            end
                            2: begin  // dsp_vb (18b) -> intra2
                                emit_intra = 6'd2;
                                emit_data  = {14'b0, gb_dsp2[17:0]};
                            end
                            3: begin  // dsp_ven (1b) -> intra3
                                emit_intra = 6'd3;
                                emit_data  = {31'b0, gb_dsp3};
                            end
                            4: begin  // dsp_vcasc hi [47:16] (32b) -> intra4
                                emit_intra = 6'd4;
                                emit_data  = gb_dsp4[31:0];
                            end
                            default: begin  // dsp_vcasc lo [15:0] (16b) -> intra5
                                emit_intra = 6'd5;
                                emit_data  = {16'b0, gb_dsp5[15:0]};
                            end
                        endcase
                    end
                    default: begin  // CLB: idx 0..7 = eLUT# (20b) at intra=idx;
                        //            idx 8..39 = iib mux#(idx-8) (5b) at intra=idx
                        emit_unit = U_CLB;
                        if (idx_r < N) begin
                            emit_intra = 6'(idx_r);
                            emit_data  = {12'b0, gb_clb_lut[19:0]};
                        end else begin
                            emit_intra = 6'(idx_r);   // intra = idx (8..39)
                            emit_data  = {27'b0, gb_clb_iib[SELW-1:0]};
                        end
                    end
                endcase
            end
        endcase
    end

    // cfg_addr = {tile_idx[TIW-1:0]@[7+TIW:8], unit[1:0]@[7:6], intra[5:0]@[5:0]}
    // tile_idx = row*C + col_latched.
    logic [TIW-1:0] cur_tile_idx;
    assign cur_tile_idx = TIW'(tile_r * C + int'(col_latched));

    // ------------------------------------------------------------------
    // FSM combinational (segment 1) — defaults first.
    // ------------------------------------------------------------------
    int cur_phase_count;
    always_comb begin
        state_nxt      = state_r;
        c_start        = 1'b0;
        c_capture      = 1'b0;
        c_emit         = 1'b0;
        c_adv          = 1'b0;
        c_done         = 1'b0;
        cur_phase_count = phase_count(phase_r, cur_tt_r);

        case (state_r)
            ST_IDLE: begin
                if (start_i) begin
                    c_start   = 1'b1;
                    state_nxt = ST_STREAM;
                end
            end
            ST_STREAM: begin
                // capture DATA words as the OCC streams them. frame_base_i + idx.
                if (fbus_we_i) begin
                    c_capture = 1'b1;
                    if (cap_count_r == (nwords_r - 16'd1)) begin
                        state_nxt = ST_SETUP;
                    end
                end
            end
            ST_SETUP: begin
                state_nxt = ST_DECODE;
            end
            ST_DECODE: begin
                c_emit = 1'b1;
                c_adv  = 1'b1;
                // done when the last tile's last phase's last point is emitted
                if ((tile_r == R-1) && (phase_r == 3) && (idx_r == cur_phase_count-1)) begin
                    c_done    = 1'b1;
                    state_nxt = ST_DONE;
                end
            end
            ST_DONE: begin
                state_nxt = ST_IDLE;
            end
            default: state_nxt = ST_IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // FSM state register (segment 2)
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) state_r <= ST_IDLE;
        else         state_r <= state_nxt;
    end

    // ------------------------------------------------------------------
    // Datapath registers
    // ------------------------------------------------------------------
    // word-index within the frame (fbus_addr - frame_base)
    logic [15:0] widx;
    assign widx = fbus_addr_i - frame_base_i;

    // DATA-word count for the requested column (combinational helper for c_start).
    logic [15:0] nw_comb;
    always_comb begin
        nw_comb = 16'(column_data_words(int'(col_i)));
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            col_latched <= '0;
            nwords_r    <= '0;
            cap_count_r <= '0;
            tile_r      <= 0;
            bit_base_r  <= 0;
            phase_r     <= 0;
            idx_r       <= 0;
            cur_tt_r    <= TT_CLB;
        end else begin
            if (c_start) begin
                col_latched <= {8'b0, col_i};
                nwords_r    <= nw_comb;
                cap_count_r <= '0;
            end else if (c_capture) begin
                if (widx < 16'(MAX_WORDS)) fbuf[int'(widx)] <= fbus_wdata_i;
                cap_count_r <= cap_count_r + 16'd1;
            end

            if (state_r == ST_SETUP) begin
                // initialise the walker at tile(row 0), its CB phase.
                tile_r     <= 0;
                bit_base_r <= 0;
                phase_r    <= 0;
                idx_r      <= 0;
                cur_tt_r   <= tile_type_at(0*C + int'(col_latched));
            end else if (c_adv && !c_done) begin
                // advance idx -> phase -> tile
                if (idx_r == cur_phase_count-1) begin
                    idx_r <= 0;
                    if (phase_r == 3) begin
                        // next tile: advance bit base by this tile's total bits
                        phase_r    <= 0;
                        tile_r     <= tile_r + 1;
                        bit_base_r <= bit_base_r + CB_BITS + SB_BITS + cur_logic_bits;
                        cur_tt_r   <= tile_type_at((tile_r+1)*C + int'(col_latched));
                    end else begin
                        phase_r <= phase_r + 1;
                    end
                end else begin
                    idx_r <= idx_r + 1;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------------
    // cfg_addr = {tile_idx[TIW-1:0]@[7+TIW:8], unit[1:0]@[7:6], intra[5:0]@[5:0]};
    // upper [15:8+TIW] bits are reserved/unused by fabric_top -> drive 0.
    logic [15:0] cfg_addr_full;
    always_comb begin
        cfg_addr_full         = 16'b0;
        cfg_addr_full[7+TIW:8] = cur_tile_idx;
        cfg_addr_full[7:6]     = emit_unit;
        cfg_addr_full[5:0]     = emit_intra;
    end
    assign cfg_we_o   = c_emit && emit_valid;
    assign cfg_addr_o = cfg_addr_full;
    assign cfg_data_o = emit_data;
    assign busy_o     = (state_r != ST_IDLE);
    assign done_o     = (state_r == ST_DONE);
    assign crc_error_o = 1'b0;   // v0: CRC16 verify deferred (OCC does CRC32; Notes)

endmodule

`default_nettype wire
