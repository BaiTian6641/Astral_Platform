// SPDX-License-Identifier: MIT
// Module:      present_round
// Function:    ONE PRESENT-80/128 block-cipher round: AddRoundKey -> sBoxLayer
//              -> pLayer. Pure combinational over a 64-bit state + 64-bit round
//              key. (PRESENT runs 31 such rounds plus a final AddRoundKey; the
//              full cipher is a SEQUENTIAL controller and is out of scope.)
//                  out = pLayer(sBoxLayer(state XOR roundkey))
// State bit ordering (PRESENT spec): the 64-bit state bit i = state[i]. The
//              16 S-boxes each take a 4-bit nibble; nibble j = state[4*j +: 4]
//              (j=0 is the least-significant nibble). The pLayer moves bit i of
//              the S-box output to position P(i) = (16*i) mod 63 for i in
//              0..62, and bit 63 -> 63.
// Size est.:   ~50-80 eLUT4 (16 tiny 4-bit S-boxes + a fixed bit permutation,
//              which is free in routing). The small 4-bit S-box keeps this far
//              cheaper than AES.
// Why combinational: one round has no register; the state is an input.
//              (fabric_sim's eLUT4-FF path has no clock-step interface — see
//              E0-MAP5 report.)
// Golden convention: drive `state` and `roundkey` as 64-bit integers (bit i =
//              net state[i]); read `out` (64-bit). make_golden_tb: random
//              vectors, #1 settle, $display state/roundkey/out as hex.
// Tags:        BENCHMARK, COMBINATIONAL
// Plan-Ref:    ethereal-plan (E0-MAP5 benchmark set)
`default_nettype none

module present_round (
    input  wire [63:0] state,
    input  wire [63:0] roundkey,
    output wire [63:0] out
);

    // AddRoundKey.
    wire [63:0] keyed = state ^ roundkey;

    // PRESENT 4-bit S-box.
    function [3:0] sbox(input [3:0] n);
        case (n)
            4'h0: sbox = 4'hc; 4'h1: sbox = 4'h5; 4'h2: sbox = 4'h6; 4'h3: sbox = 4'hb;
            4'h4: sbox = 4'h9; 4'h5: sbox = 4'h0; 4'h6: sbox = 4'ha; 4'h7: sbox = 4'hd;
            4'h8: sbox = 4'h3; 4'h9: sbox = 4'he; 4'ha: sbox = 4'hf; 4'hb: sbox = 4'h8;
            4'hc: sbox = 4'h4; 4'hd: sbox = 4'h7; 4'he: sbox = 4'h1; 4'hf: sbox = 4'h2;
            default: sbox = 4'h0;
        endcase
    endfunction

    // sBoxLayer: 16 nibbles.
    wire [63:0] sboxed;
    genvar gj;
    generate
        for (gj = 0; gj < 16; gj = gj + 1) begin : g_sbox
            assign sboxed[4*gj +: 4] = sbox(keyed[4*gj +: 4]);
        end
    endgenerate

    // pLayer: bit i of input -> bit P(i) of output.
    //   P(i) = (16*i) mod 63 for i in 0..62;  P(63) = 63.
    wire [63:0] permuted;
    genvar gi;
    generate
        for (gi = 0; gi < 64; gi = gi + 1) begin : g_player
            if (gi == 63) begin : g_last
                assign permuted[63] = sboxed[63];
            end else begin : g_rest
                assign permuted[(16*gi) % 63] = sboxed[gi];
            end
        end
    endgenerate

    assign out = permuted;

endmodule
`default_nettype wire
