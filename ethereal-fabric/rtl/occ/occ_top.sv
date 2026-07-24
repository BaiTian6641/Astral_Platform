`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      occ_top
// Description: Overlay Configuration Controller (OCC) v0 — frame-bus write/read/blank engine.
// Details:     Drives the per-column configuration frame bus. v0 commands:
//                 NOP(0) / WRITE(1) / READBACK(2) / BLANK(3)
//               * WRITE    : streams DATA words to the frame bus, 1 word/cycle,
//                            computing a streaming CRC32; on completion stores the
//                            final CRC into write_crc_r.
//               * BLANK    : self-driven zero-word writes (no wdata stream), same
//                            CRC accumulation as WRITE.
//               * READBACK : reads the frame back via fbus_re (combinational-read
//                            target in v0), recomputes CRC32, then CMP compares
//                            against write_crc_r.
//               WRITE/BLANK are gated by region_locked_i (reject -> LOCKED);
//               READBACK is NOT lock-checked in v0 (read is non-destructive).
//               crc_error_o is sticky: set on a READBACK CRC mismatch, cleared on
//               the next accepted command.
//
//               This is CONTROL LOGIC ONLY (FF+mux). It owns no config storage —
//               the frame bus target is the column controller / column_cfg_ram
//               model (C03 sec0). There is no combinational loop in this module
//               (the only feedback is via registered idx_r/crc_r), so it is
//               strict -Wall clean with no UNOPTFLAT waiver.
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB4)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C03-OCC组件.md §2
// Notes:       v0 scope per C03 §2.2 (simplified): no mailbox/DMA, no col_ack
//              frame-level handshake (1 word/cycle backpressure via wdata_ready),
//              no blank.hex ROM (blank = hardwired zero frame), no lock MATRIX
//              (single region_locked_i gate). FABulous blank-before-write red
//              line (C03 §0) is respected at the protocol level: a region must be
//              blanked before its first config WRITE — enforced by the BMC, not
//              by occ_top v0.
//              ASSUMPTION (TBD 2026-07-24): DATA_W must equal 32 — crc32_next is
//              a fixed 32-bit/4-byte tableless function (matches the frozen
//              DATA_W=32 frame word width, C03 §1.1). Parameterized for interface
//              parity only.
//              ASSUMPTION (TBD 2026-07-24): word_count_i >= 1. word_count_i = 0
//              is handled gracefully (immediate DONE, no words moved) but is not
//              a supported v0 case.
//              ASSUMPTION (TBD 2026-07-24): the readback target returns data
//              combinationally in the same cycle fbus_re/fbus_addr are asserted
//              (column_cfg_ram model). A registered (1-cycle) readback RAM would
//              require a 1-cycle pipeline stage here — deferred to v1 (C03 §4.2).
module occ_top #(
    parameter int ADDR_W = 16,    // frame-bus address width (region+col+word offset)
    parameter int DATA_W = 32
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    // command interface (driven by TB / BMC)
    input  logic [1:0]            cmd_i,           // 0=NOP 1=WRITE 2=READBACK 3=BLANK
    input  logic                  cmd_valid_i,
    output logic                  cmd_ready_o,     // 1-cycle accept pulse
    input  logic [ADDR_W-1:0]     frame_addr_i,    // base address of this frame
    input  logic [15:0]           word_count_i,    // number of DATA words in the frame
    // write-data stream (for WRITE)
    input  logic [DATA_W-1:0]     wdata_i,
    input  logic                  wdata_valid_i,
    output logic                  wdata_ready_o,
    // frame bus -> column config storage
    output logic [ADDR_W-1:0]     fbus_addr_o,
    output logic [DATA_W-1:0]     fbus_wdata_o,
    output logic                  fbus_we_o,
    output logic                  fbus_re_o,       // readback read strobe
    input  logic [DATA_W-1:0]     fbus_rdata_i,    // readback data (combinational in v0)
    // status + lock
    output logic [2:0]            status_o,        // 0=IDLE 1=BUSY 2=DONE 3=ERROR 4=LOCKED
    output logic                  crc_error_o,     // sticky; set on readback CRC mismatch
    input  logic                  region_locked_i  // 1 = current region locked (blocks WRITE/BLANK)
);

    // --------------------------------------------------------------------
    // Enumerations (frozen encodings — exposed via status_o / cmd_i)
    // --------------------------------------------------------------------
    // command opcode encoding (matches cmd_i comment)
    localparam logic [1:0] CMD_NOP      = 2'd0;
    localparam logic [1:0] CMD_WRITE    = 2'd1;
    localparam logic [1:0] CMD_READBACK = 2'd2;
    localparam logic [1:0] CMD_BLANK    = 2'd3;

    // FSM state (C03 §2.2, v0-simplified)
    typedef enum logic [2:0] {
        ST_IDLE     = 3'd0,
        ST_WRITE    = 3'd1,
        ST_BLANK    = 3'd2,
        ST_READBACK = 3'd3,
        ST_CMP      = 3'd4
    } state_e;

    // status encoding (exposed on status_o)
    localparam logic [2:0] S_IDLE   = 3'd0;
    localparam logic [2:0] S_BUSY   = 3'd1;
    localparam logic [2:0] S_DONE   = 3'd2;
    localparam logic [2:0] S_ERROR  = 3'd3;
    localparam logic [2:0] S_LOCKED = 3'd4;

    // --------------------------------------------------------------------
    // Streaming CRC32 (Ethernet poly 0x04C11DB7, init 0xFFFFFFFF, no final xor,
    // MSB-byte-first, non-reflected = CRC-32/MPEG-2). 1 DATA word per call.
    // Byte-wise tableless (matches frame_map.py crc16 style). Both the WRITE and
    // READBACK paths call this identical function, so the exact standard is not
    // load-bearing for v0 correctness — only self-consistency is.
    // --------------------------------------------------------------------
    function automatic logic [31:0] crc32_next(input logic [31:0] crc_in,
                                               input logic [31:0] data_in);
        logic [31:0] c, dw;
        logic  [7:0] b;
        integer      by, bit_i;
        begin
            c  = crc_in;
            dw = data_in;
            for (by = 0; by < 4; by = by + 1) begin
                b  = dw[31:24];                 // MSB byte first (big-endian word)
                c  = c ^ {b, 24'h0};
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    if (c[31]) c = (c << 1) ^ 32'h04C1_1DB7;
                    else       c = (c << 1);
                end
                dw = dw << 8;                   // advance next byte into [31:24]
            end
            return c;
        end
    endfunction

    // --------------------------------------------------------------------
    // State + datapath registers
    // --------------------------------------------------------------------
    state_e          state_r;
    state_e          state_nxt;

    logic [ADDR_W-1:0] frame_addr_r;   // latched frame base address
    logic [15:0]       word_count_r;   // latched word count
    logic [15:0]       idx_r;          // intra-frame word index
    logic [31:0]       crc_r;          // running streaming CRC (write + readback)
    logic [31:0]       write_crc_r;    // CRC captured at WRITE/BLANK completion
    logic              crc_error_r;    // sticky readback-mismatch flag

    // --------------------------------------------------------------------
    // Combinational control outputs (segment 1 of the two-segment FSM) +
    // control hints consumed by the datapath register block. Defaults first so
    // no latch is inferred (G1).
    // --------------------------------------------------------------------
    logic [ADDR_W-1:0] fbus_addr;
    logic [DATA_W-1:0] fbus_wdata;
    logic              fbus_we;
    logic              fbus_re;
    logic              cmd_ready;
    logic              wdata_ready;
    logic [2:0]        status_c;

    // datapath control hints
    logic              c_accept;        // IDLE: a command is accepted this cycle
    logic              c_write_word;    // WRITE: a data word is being written
    logic              c_write_last;    // WRITE: this word is the final one
    logic              c_blank_word;    // BLANK: a zero word is being written
    logic              c_read_word;     // READBACK: a word is being read
    logic              c_cmp_mismatch;  // CMP: crc_r != write_crc_r

    always_comb begin
        // ---- defaults (no latches) ----
        state_nxt      = state_r;
        status_c       = S_IDLE;
        cmd_ready      = 1'b0;
        wdata_ready    = 1'b0;
        fbus_we        = 1'b0;
        fbus_re        = 1'b0;
        fbus_addr      = '0;
        fbus_wdata     = '0;
        c_accept       = 1'b0;
        c_write_word   = 1'b0;
        c_write_last   = 1'b0;
        c_blank_word   = 1'b0;
        c_read_word    = 1'b0;
        c_cmp_mismatch = 1'b0;

        case (state_r)
            ST_IDLE: begin
                status_c = S_IDLE;
                if (cmd_valid_i) begin
                    case (cmd_i)
                        CMD_WRITE, CMD_BLANK: begin
                            if (region_locked_i) begin
                                // reject: stay IDLE, signal LOCKED this cycle
                                status_c = S_LOCKED;
                            end else begin
                                cmd_ready = 1'b1;
                                c_accept  = 1'b1;
                                state_nxt = state_e'((cmd_i == CMD_WRITE) ? ST_WRITE : ST_BLANK);
                            end
                        end
                        CMD_READBACK: begin
                            // no lock check for READBACK in v0 (non-destructive)
                            cmd_ready = 1'b1;
                            c_accept  = 1'b1;
                            state_nxt = ST_READBACK;
                        end
                        CMD_NOP: ; // stay IDLE
                        default: ; // stay IDLE
                    endcase
                end
            end

            ST_WRITE: begin
                if (idx_r == word_count_r) begin
                    // completion cycle: all words streamed
                    status_c  = S_DONE;
                    state_nxt = ST_IDLE;
                end else begin
                    status_c   = S_BUSY;
                    wdata_ready = 1'b1;
                    if (wdata_valid_i) begin
                        fbus_we      = 1'b1;
                        fbus_addr    = frame_addr_r + idx_r;
                        fbus_wdata   = wdata_i;
                        c_write_word = 1'b1;
                        if (idx_r == (word_count_r - 16'd1)) c_write_last = 1'b1;
                    end
                    state_nxt = ST_WRITE;
                end
            end

            ST_BLANK: begin
                if (idx_r == word_count_r) begin
                    status_c  = S_DONE;
                    state_nxt = ST_IDLE;
                end else begin
                    status_c     = S_BUSY;
                    fbus_we      = 1'b1;
                    fbus_addr    = frame_addr_r + idx_r;
                    fbus_wdata   = '0;
                    c_blank_word = 1'b1;
                    state_nxt    = ST_BLANK;
                end
            end

            ST_READBACK: begin
                status_c = S_BUSY;
                if (idx_r == word_count_r) begin
                    state_nxt = ST_CMP;          // all words read -> compare
                end else begin
                    fbus_re    = 1'b1;
                    fbus_addr  = frame_addr_r + idx_r;
                    c_read_word = 1'b1;
                    state_nxt  = ST_READBACK;
                end
            end

            ST_CMP: begin
                // crc_r and write_crc_r both hold their final values
                if (crc_r == write_crc_r) begin
                    status_c = S_DONE;
                end else begin
                    status_c       = S_ERROR;
                    c_cmp_mismatch = 1'b1;
                end
                state_nxt = ST_IDLE;
            end

            default: begin
                state_nxt = ST_IDLE;
                status_c  = S_IDLE;
            end
        endcase
    end

    // --------------------------------------------------------------------
    // FSM state register (segment 2)
    // --------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) state_r <= ST_IDLE;
        else         state_r <= state_nxt;
    end

    // --------------------------------------------------------------------
    // Datapath registers
    // --------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            frame_addr_r <= '0;
            word_count_r <= '0;
            idx_r        <= '0;
            crc_r        <= 32'hFFFF_FFFF;
            write_crc_r  <= 32'hFFFF_FFFF;
            crc_error_r  <= 1'b0;
        end else begin
            if (c_accept) begin
                // latch command context, (re)seed CRC, clear sticky error
                frame_addr_r <= frame_addr_i;
                word_count_r <= word_count_i;
                idx_r        <= '0;
                crc_r        <= 32'hFFFF_FFFF;
                crc_error_r  <= 1'b0;
            end else if (c_write_word) begin
                idx_r   <= idx_r + 16'd1;
                crc_r   <= crc32_next(crc_r, wdata_i);
                if (c_write_last) write_crc_r <= crc32_next(crc_r, wdata_i);
            end else if (c_blank_word) begin
                idx_r   <= idx_r + 16'd1;
                crc_r   <= crc32_next(crc_r, 32'h0);
                if (idx_r == (word_count_r - 16'd1)) begin
                    write_crc_r <= crc32_next(crc_r, 32'h0);
                end
            end else if (c_read_word) begin
                idx_r <= idx_r + 16'd1;
                crc_r <= crc32_next(crc_r, fbus_rdata_i);
            end else if (c_cmp_mismatch) begin
                crc_error_r <= 1'b1;            // sticky until next accepted cmd
            end
        end
    end

    // --------------------------------------------------------------------
    // Output assignments
    // --------------------------------------------------------------------
    assign cmd_ready_o  = cmd_ready;
    assign wdata_ready_o = wdata_ready;
    assign fbus_addr_o  = fbus_addr;
    assign fbus_wdata_o = fbus_wdata;
    assign fbus_we_o    = fbus_we;
    assign fbus_re_o    = fbus_re;
    assign status_o     = status_c;
    assign crc_error_o  = crc_error_r;

endmodule

`default_nettype wire
