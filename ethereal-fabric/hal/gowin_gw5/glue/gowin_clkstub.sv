`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      gowin_clkstub
// Description: GW5 clock-glue placeholder (C12 §2 `hal_pll` slot): generates
//              sys_clk from the board crystal and exposes a lock flag. This is
//              one of the C13 §4 non-inferable resources (PLL/OSC/DCS) — the
//              ONLY clock module permitted to name Gowin primitives, and then
//              only inside the `ifdef GOWIN_PRIMITIVE branch (OFF by default).
// Details:     DEFAULT branch = Verilator/iverilog/yosys-safe BEHAVIORAL model
//              (the "clkgen_stub" of C12 §1): a cycle-accurate integer
//              divider/multiplier approximation is NOT attempted — the stub
//              passes the input clock through and asserts lock_o after
//              LOCK_CYCLES cycles, which is all the fabric/Shell RTL needs to
//              verify reset sequencing (C12 §2.2) in simulation. A divided
//              clock output (clkdiv_o) is generated with a plain counter so
//              divider consumers are also exercisable in sim.
//              GOWIN_PRIMITIVE branch: maps to the GW5A rPLL primitive as
//              documentation-in-code for the Gowin-EDA build; the Verilator
//              file list keeps the stub branch (file-list-level switch, C13 §4).
// Maintainer:  BaiTian6641
// Created:     2026-09-01
// Tags:        RTL, SYNTH | HAL-GLUE, SIM-STUB
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §4 ·
//              ethereal-plan/components/C12-平台组件.md §1 §2
// Notes:       ASSUMPTION: Tang Mega 138K Dock main crystal frequency and its
//              clock-capable pin are UNCONFIRMED (C12 §6 open item 1 — Board
//              Manifest blocks on the Dock schematic). The parameters below
//              (CLKIN_HZ, target 100 MHz sys_clk with 75/50 MHz fallback
//              gears per C12 §2.3) are placeholders pending that confirmation
//              (TBD, 2026-09-01).
//              ASSUMPTION: GW5A PLL primitive is rPLL-class (PLLVR naming TBD);
//              FCLKFIN/IDIV/ODIV encodings per the licensed primitive library
//              must be verified before enabling GOWIN_PRIMITIVE (TBD, 2026-09-01).
module gowin_clkstub #(
    parameter longint CLKIN_HZ  = 50_000_000,  // ASSUMPTION (TBD, 2026-09-01): Dock crystal
    parameter longint CLKOUT_HZ = 100_000_000, // C12 §2.1 target sys_clk
    parameter int     DIV       = 2,           // clkdiv_o divider (>=2, even)
    parameter int     LOCK_CYCLES = 16         // stub lock assertion delay
) (
    input  logic clkin_i,     // board crystal input
    input  logic rst_ni,      // asynchronous assert, synchronous release
    output logic clkout_o,    // sys_clk (stub: pass-through of clkin_i)
    output logic clkdiv_o,    // divided clock (stub: clkin_i / DIV)
    output logic lock_o       // PLL lock (stub: LOCK_CYCLES after reset release)
);

`ifdef GOWIN_PRIMITIVE
    // ------------------------------------------------------------------
    // Gowin-EDA build branch (NOT compiled by the default open chain).
    //
    // Reference instantiation shape (GW5A rPLL class — G6: verify the exact
    // primitive name (rPLL vs PLLVR), divider parameter encodings
    // (FCLKFIN/IDIV_SEL/ODIV_SEL/FBDIV_SEL) and the CLKOUTP/CLKOUTD outputs
    // against the licensed GW5A primitive library; ASSUMPTION (TBD, 2026-09-01)):
    //
    //   rPLL #(
    //       .FCLKFIN   ("50"),          // ASSUMPTION: Dock crystal 50 MHz (TBD)
    //       .IDIV_SEL  (/* f_in divisor  — TBD */),
    //       .FBDIV_SEL (/* feedback mult — TBD */),
    //       .ODIV_SEL  (/* output div    — TBD */),
    //       .DYN_SDIV_SEL (DIV)         // CLKOUTD divider for clkdiv_o
    //   ) u_rpll (
    //       .CLKIN   (clkin_i),
    //       .CLKFB   (/* internal feedback */),
    //       .RESET   (!rst_ni),
    //       .CLKOUT  (clkout_o),
    //       .CLKOUTD (clkdiv_o),
    //       .LOCK    (lock_o)
    //   );
    //
    // Commented reference only — enabling the define today fails at elaboration / time-0 on purpose:
    initial begin
        $error("gowin_clkstub: GOWIN_PRIMITIVE branch is documentation-in-code only; "
               + "rPLL bindings + Dock crystal params pending G6 verification "
               + "(2026-09-01). Build without -DGOWIN_PRIMITIVE (stub path).");
    end
    assign clkout_o = 1'b0;
    assign clkdiv_o = 1'b0;
    assign lock_o   = 1'b0;
`else
    // ------------------------------------------------------------------
    // DEFAULT branch — behavioral stub (simulation + open-chain synth).
    // sys_clk pass-through: fabric/Shell timing closure is validated by the
    // vendor STA, not by this module; the stub only models the reset/lock
    // handshake and a divided clock domain for CDC exercises.
    assign clkout_o = clkin_i;

    // Integer divider for clkdiv_o (DIV >= 2, 50% duty).
    logic [$clog2(DIV)-1:0] div_cnt_r;
    logic                   clkdiv_r;
    localparam int CNT_W = $clog2(DIV);
    always_ff @(posedge clkin_i or negedge rst_ni) begin
        if (!rst_ni) begin
            div_cnt_r <= '0;
            clkdiv_r  <= 1'b0;
        end else if (div_cnt_r == CNT_W'(DIV/2 - 1)) begin
            div_cnt_r <= '0;
            clkdiv_r  <= ~clkdiv_r;
        end else begin
            div_cnt_r <= div_cnt_r + 1'b1;
        end
    end
    assign clkdiv_o = clkdiv_r;

    // Lock: asserted LOCK_CYCLES clkin cycles after reset release (models PLL
    // lock latency for the C12 §2.2 reset sequencer; timeout path -> rescue
    // clock switching is exercised in sim by NOT releasing lock).
    logic [$clog2(LOCK_CYCLES+1)-1:0] lock_cnt_r;
    always_ff @(posedge clkin_i or negedge rst_ni) begin
        if (!rst_ni) begin
            lock_cnt_r <= '0;
        end else if (lock_cnt_r != LOCK_CYCLES[$clog2(LOCK_CYCLES+1)-1:0]) begin
            lock_cnt_r <= lock_cnt_r + 1'b1;
        end
    end
    assign lock_o = (lock_cnt_r == LOCK_CYCLES[$clog2(LOCK_CYCLES+1)-1:0]);

    // CLKIN_HZ/CLKOUT_HZ are documentation parameters for the GOWIN_PRIMITIVE
    // branch; sink them in the stub so lint stays clean.
    logic _unused_ok;
    assign _unused_ok = (CLKIN_HZ > 0) & (CLKOUT_HZ > 0);
`endif

endmodule

`default_nettype wire
