// SPDX-License-Identifier: MIT
// Module:      uart_loopback
// Function:    Minimal UART (8N1) RX -> TX loopback. A byte received on `rx`
//              is retransmitted on `tx` at the same baud. 1x sampling: the RX
//              validates the start bit after CLKS_PER_BIT/2 consecutive low
//              cycles (a full half-bit glitch filter), then samples each
//              data/stop bit at full CLKS_PER_BIT intervals. On a clean stop
//              bit (framing check) the completed byte is handed DIRECTLY to
//              the TX (no queue): if the TX is busy the byte is dropped —
//              unreachable at full wire rate, since the TX returns to idle
//              (stop bit folded into IDLE, see below) one stop bit before the
//              next RX can complete (see E1-DMO1 report).
// Params:      CLKS_PER_BIT = round(f_clk / baud). Default 87 = 10.0056 MHz /
//              115200 baud (115385 Bd, +0.16% — inside 8N1 tolerance). The
//              counter width derives from the parameter, so sim builds use a
//              small divider (e.g. 4) and hardware builds the real one.
// Reset:       NONE by design — the v0 fabric eLUT4 FF has no routed reset
//              (arch .latch is D/Q/clk only), so the all-zero power-up state
//              IS the idle state. Every reg therefore carries an explicit
//              `= 1'b0` initializer (the fabric FF pool zero-inits, and the
//              iverilog golden starts in that exact state). A synchronous
//              reset, when needed, must be folded into the LUT data path.
// Size:        76 eLUT4 (synth_ethereal dffunmap flow, CLKS_PER_BIT=87,
//              2026-09-08) -> ships on the 4x4 all-CLB descriptor (4 cols x
//              4 rows = 16 tiles = 128 eLUT, ~59% fill). The original
//              4-state-per-side + 3-bit bit counters measured 89 eLUT; the
//              shrink below lands at ~76 — the two 7-bit timebase counters
//              alone cost ~38 eLUT, so the 2x4 (64-eLUT) descriptor is
//              unreachable at the hardware baud (sizing sweep in the E1-DMO1
//              report).
//              Shrink: the RX folds to a 1-bit state with a MARKER-WALK
//                shift register (10'b1 loaded at start validation, {rx,
//                s[9:1]} shifted right per data boundary: the byte gathers
//                LSB-first in s[9:2]; the marker LEADS the data by exactly
//                one shift, so taps s[2] (8th-bit boundary) and s[1] (stop
//                phase) sit below the data's resting floor and are data-free
//                by construction — proven for every byte value). Both stop
//                phases fold away: the RX stop rides the parked marker, the
//                TX stop IS TX_IDLE's tx=1 output (the next accept is >= 10
//                bit times after the previous one, the TX is busy only 9, so
//                it can never miss a byte). The TX keeps a plain 3-bit bit
//                counter: a TX-side marker would TRAIL the data, and every
//                static tap it can reach also carries data at early
//                boundaries (0xA7 false-fired the 8th-bit detect on bit1) —
//                a trailing marker cannot count 8 send boundaries.
// Golden convention: directed byte streams on `rx` (UART-8N1 wire format,
//              idle high), per-cycle `tx` trace compared against the
//              fabric_sim tick model (E1-DMO1 demo_images flow).
// Tags:        BENCHMARK, SEQUENTIAL, DEMO
// Plan-Ref:    ethereal-plan (E1-DMO1 demo images)
`default_nettype none

module uart_loopback #(
    parameter CLKS_PER_BIT = 87            // 10.0056 MHz / 115200 Bd
) (
    input  wire clk,
    input  wire rx,
    output reg  tx = 1'b0
);

    // Verilog-2005 clog2 (counter width tracks the divider parameter).
    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam CW   = clog2(CLKS_PER_BIT);        // counter width
    localparam [CW-1:0] FULL = CLKS_PER_BIT - 1;  // one bit time
    localparam [CW-1:0] HALF = CLKS_PER_BIT / 2;  // start-bit filter length

    // ---------------- RX: HUNT (idle + start filter) / DATA (+ stop) ----------
    reg            rx_data = 1'b0;  // 0 = HUNT, 1 = DATA (stop phase in-marker)
    reg  [CW-1:0]  rx_cnt  = {CW{1'b0}};
    reg  [9:0]     rxs     = 10'b0; // marker walk + byte (see header)

    wire rx_mid  = (rx_cnt == HALF);          // start-bit validation point
    wire rx_bend = (rx_cnt == FULL);          // bit-time boundary
    wire rx_stop = rxs[1];                    // marker parked: stop phase
    // Byte-accept strobe: last cycle of the stop bit, framing check passed.
    // Consumed combinationally by the TX (direct RX->TX handoff).
    wire rx_accept = rx_data & rx_bend & rx_stop & rx;

    always @(posedge clk) begin
        if (!rx_data) begin                   // HUNT
            if (!rx) begin
                if (rx_mid) begin
                    // HALF consecutive low cycles: real start bit -> DATA
                    rx_data <= 1'b1;
                    rx_cnt  <= {CW{1'b0}};
                    rxs     <= 10'b1000000000;   // marker head at s[9]
                end else begin
                    rx_cnt <= rx_cnt + {{CW-1{1'b0}}, 1'b1};
                end
            end else begin
                rx_cnt <= {CW{1'b0}};         // line high: re-arm the filter
            end
        end else begin                        // DATA (+ folded stop)
            if (rx_bend) begin
                rx_cnt <= {CW{1'b0}};
                if (rx_stop) begin
                    rx_data <= 1'b0;          // frame complete (rx_accept above);
                end else begin                 // framing fail: byte dropped
                    rxs <= {rx, rxs[9:1]};     // byte gathers in s[9:2]
                end
            end else begin
                rx_cnt <= rx_cnt + {{CW-1{1'b0}}, 1'b1};
            end
        end
    end

    // ---------------- TX: IDLE (+ folded stop) / START / SEND -----------------
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_SEND  = 2'd2;

    reg  [1:0]     tx_state = TX_IDLE;
    reg  [CW-1:0]  tx_cnt   = {CW{1'b0}};
    reg  [2:0]     tx_bit   = 3'b000;   // data-bit index (see header: no TX
                                        // marker — a trailing marker's tap
                                        // is never data-free)
    reg  [7:0]     txs      = 8'b0;     // byte, REVERSED (LSB at s[7])

    wire tx_bend = (tx_cnt == FULL);

    always @(posedge clk) begin
        case (tx_state)
            TX_IDLE: begin                    // idle-high; also the stop bit
                tx <= 1'b1;
                if (rx_accept) begin
                    // byte REVERSED into the TX walk (wire permutation, 0 LUT)
                    txs      <= {rxs[2], rxs[3], rxs[4], rxs[5],
                                 rxs[6], rxs[7], rxs[8], rxs[9]};
                    tx_state <= TX_START;
                    tx_cnt   <= {CW{1'b0}};
                end
            end
            TX_START: begin
                tx <= 1'b0;
                if (tx_bend) begin
                    tx_cnt   <= {CW{1'b0}};
                    tx_bit   <= 3'b000;
                    tx_state <= TX_SEND;
                end else begin
                    tx_cnt <= tx_cnt + {{CW-1{1'b0}}, 1'b1};
                end
            end
            default: begin                    // TX_SEND (data; stop is IDLE)
                tx <= txs[7];
                if (tx_bend) begin
                    tx_cnt <= {CW{1'b0}};
                    txs    <= {txs[6:0], 1'b1};
                    if (tx_bit == 3'd7) begin
                        tx_bit   <= 3'b000;
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_bit <= tx_bit + 3'd1;
                    end
                end else begin
                    tx_cnt <= tx_cnt + {{CW-1{1'b0}}, 1'b1};
                end
            end
        endcase
    end


endmodule
`default_nettype wire
