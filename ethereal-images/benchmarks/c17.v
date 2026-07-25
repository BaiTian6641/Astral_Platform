// SPDX-License-Identifier: MIT
// ISCAS85 c17 benchmark (canonical 5-input, 2-output combinational circuit).
// Used as the tiny E0-MAP1 synth_ethereal test target.
// (Original is a gate netlist; this is an equivalent structural Verilog.)
module c17 (
    input  wire N1, N2, N3, N6, N7,
    output wire N22, N23
);
    wire N10, N11, N16, N19;
    assign N10 = ~(N1 & N3);   // NAND
    assign N11 = ~(N3 & N6);
    assign N16 = ~(N2 & N11);
    assign N19 = ~(N11 & N7);
    assign N22 = ~(N10 & N16);
    assign N23 = ~(N16 & N19);
endmodule
