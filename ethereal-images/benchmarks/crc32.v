// SPDX-License-Identifier: MIT
// Module:      crc32_step
// Function:    One parallel CRC-32 step (Ethernet / zlib polynomial 0xEDB88320,
//              reflected input/output). Combines the current 32-bit CRC state
//              `crc_in` with 8 fresh data bits `data` and produces the next CRC
//              state `crc_out`. This is the classic LFSR-shift-by-8 network:
//              for each data bit i:  fb = crc_in[0] ^ data[i];  crc = (crc>>1)
//              ^ (fb ? 0xEDB88320 : 0).  Here expanded to an 8-bit parallel XOR
//              network (pure combinational).
// Size est.:   ~50-80 eLUT4 (8x 32-wide XOR-of-shift taps).
// Why combinational: the running CRC state is an INPUT (`crc_in`), so the DUT
//              is pure combinational and bit-true-testable without a clock.
//              (A real CRC engine registers crc_out back into crc_in; that
//              sequential loop is out of scope — fabric_sim has no FF clock-step
//              interface, see E0-MAP5 report.)
// Golden convention: drive `crc_in` (32-bit) and `data` (8-bit) as integers;
//              read `crc_out` (32-bit). make_golden_tb: random vectors, #1
//              settle, $display crc_in/data/crc_out.
// Tags:        BENCHMARK, COMBINATIONAL
// Plan-Ref:    ethereal-plan (E0-MAP5 benchmark set — the classic Phase-0 CRC)
`default_nettype none

module crc32_step (
    input  wire [31:0] crc_in,
    input  wire [7:0]  data,
    output wire [31:0] crc_out
);

    // Reflected Ethernet CRC-32 polynomial.
    localparam [31:0] POLY = 32'hEDB8_8320;

    // One reflected CRC shift: fb = c[0] ^ din; advance the LFSR by one bit.
    function [31:0] crc_shift(input [31:0] c, input din);
        crc_shift = (c >> 1) ^ ((c[0] ^ din) ? POLY : 32'h0);
    endfunction

    // 8-bit parallel CRC step. The function-local variable is inlined by the
    // synthesizer, so NO module-level temp net is created (avoids the
    // `reg c` -> VPR buffer-alias artifact that broke PO extraction: see
    // E0-MAP5 report). crc_out is driven DIRECTLY by the final XOR network.
    function [31:0] crc8(input [31:0] crc, input [7:0] d);
        integer i;
        reg [31:0] c;
        begin
            c = crc;
            for (i = 0; i < 8; i = i + 1)
                c = crc_shift(c, d[i]);
            crc8 = c;
        end
    endfunction

    assign crc_out = crc8(crc_in, data);

endmodule
`default_nettype wire
