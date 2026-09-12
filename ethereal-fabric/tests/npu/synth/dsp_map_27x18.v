// VERBATIM COPY of the E2-FAB2b scratch template, checked in here (E3-SVC1) so the
// NPU-Tiny DSP-mapped Fmax measurement is reproducible from tracked files alone.
// Provenance: generated/fab2b_dsp/dsp_map_27x18.v (gitignored scratch) as produced
// for report-E2-FAB2b-dsp-mapping-20260912.md §2; the owner of this template is the
// platform mapping flow (E2-FAB2c candidate) — this copy is measurement input only.
//
// SCRATCH (E2-FAB2b forced-DSP spike) — NOT tracked RTL.
// Minimal techmap template for the GW5A 27x18 DSP, mirroring the structure of
// +/gowin/dsp_map.v (gw1n/gw2a templates).  Used as
//   techmap -map dsp_map_27x18.v
// after  techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=27 -D DSP_B_MAXWIDTH=18
//        -D DSP_NAME=$__MUL27X18
//
// Port names/widths follow the yosys GW5A techlib blackbox
// share/yosys/gowin/cells_xtra_gw5a.v :: MULTALU27X18 and the nextpnr-himbaechel
// GW5A DSP bel (DSP/MULTALU27X1800: A0-26 B0-17 C0-47 D0-25 CE0/1 CLK0/1
// RESET0/1 ADDSUB0/1 ACCSEL0/1 CASISEL ASEL CSEL PSEL PADDSUB DOUT0-47).
// Register params stay at their techlib defaults (AREG_*="BYPASS" etc.), so the
// pipeline registers are bypassed and the CLK/CE/RESET pins are tied off.
// C_SEL=1 / ACC_SEL=0 defaults mean DOUT = A*B + C  -> tie C=0 for a plain multiply.
module \$__MUL27X18 (input [26:0] A, input [17:0] B, output [47:0] Y);

    parameter A_WIDTH = 27;
    parameter B_WIDTH = 18;
    parameter Y_WIDTH = 45;
    parameter A_SIGNED = 0;
    parameter B_SIGNED = 0;

	MULTALU27X18 __TECHMAP_REPLACE__ (
		.A(A),
		.SIA(27'b0),
		.B(B),
		.C(48'b0),
		.D(26'b0),
		.CASI(48'b0),
		.ACCSEL(1'b0),
		.PSEL(1'b0),
		.ASEL(1'b0),
		.PADDSUB(1'b0),
		.CSEL(1'b0),
		.CASISEL(1'b0),
		.ADDSUB(2'b0),
		.CLK(2'b0),
		.CE(2'b0),
		.RESET(2'b0),
		.DOUT(Y)
	);

endmodule
