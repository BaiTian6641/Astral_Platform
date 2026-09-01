`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      gowin_bsram
// Description: GW5 host-mapping glue for the inference-first block RAM template
//              (ADR-017, C13 §2.2). SAME port interface as eth_inf_ram: this is
//              the ONLY module allowed to name Gowin BSRAM primitives, and it
//              does so exclusively inside the `ifdef GOWIN_PRIMITIVE branch,
//              which is OFF by default.
// Details:     Build modes:
//                DEFAULT (open chain + simulation): behavioral fallback that
//                  simply instantiates eth_inf_ram — yosys synth_gowin infers
//                  it to physical BSRAM (C13 §1: Yosys memory_libmap brams),
//                  and Verilator/iverilog simulate it directly. Zero vendor
//                  identifiers are compiled.
//                GOWIN_PRIMITIVE (Gowin-EDA builds ONLY): enable with
//                  `-DGOWIN_PRIMITIVE` in the GowinSynthesis project/file list
//                  (or gw_sh tcl `import_file ... -define GOWIN_PRIMITIVE`).
//                  The branch then maps the interface onto GW5A BSRAM
//                  primitives (SP/SDP family) as documentation-in-code. It is
//                  NOT linted/simulated by the open chain; the Gowin primitive
//                  simulation models are time-step-simulator code that
//                  the open-chain simulator cannot consume (ADR-017 motivation, C13 §1).
// Maintainer:  BaiTian6641
// Created:     2026-09-01
// Tags:        RTL, SYNTH | HAL-GLUE
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.2 §4 ·
//              ethereal-plan/components/C12-平台组件.md §1
// Notes:       GW5A BSRAM primitive mapping (GW5A series, 18 Kb per block;
//              SUG550E / GW5A primitive guide — G6: exact primitive parameter
//              spellings must be verified against the licensed Gowin primitive
//              simulation library before a GOWIN_PRIMITIVE build is enabled):
//                eth_inf_ram (sync read, read-first, per-byte WE, 1W1R)
//                  -> SDPX9B (semi-dual-port, byte-write BSRAM) when
//                     DW % 9 == 0 or the byte granularity maps cleanly;
//                  -> SDP / SP otherwise, width-chopped per byte lane.
//              The open chain NEVER needs this branch: synth_gowin + the
//              `ETH_RAMSTYLE attribute layer (eth_config.svh, TARGET_GOWIN)
//              already steer inference; this file exists so that IF a future
//              Gowin-EDA build loses inference (C13 §6 infer_check failure),
//              the fix lands HERE, not in tracked own-RTL.
module gowin_bsram #(
    parameter int AW    = 11,              // address width (2^AW entries)
    parameter int DW    = 32,              // data width (byte-aligned)
    parameter int NBYTES = DW / 8,         // byte-write-enable width
    parameter INIT_HEX = ""                // optional $readmemh init (ROM preload)
) (
    input  logic                clk_i,
    input  logic                en_i,       // clock-enable / chip-enable
    input  logic                we_i,       // write enable
    input  logic [NBYTES-1:0]   be_i,       // per-byte write enable
    input  logic [AW-1:0]       addr_i,
    input  logic [DW-1:0]       wdata_i,
    output logic [DW-1:0]       rdata_o
);

`ifdef GOWIN_PRIMITIVE
    // ------------------------------------------------------------------
    // Gowin-EDA build branch (NOT compiled by the default open chain).
    //
    // Mapping intent (documentation-in-code, GW5A BSRAM 18 Kb blocks):
    //   - eth_inf_ram is a 1-clock synchronous-read, read-first RAM with a
    //     single address port used for both read and write -> semi-dual-port
    //     (SDP) BSRAM; per-byte write enable -> the byte-enable BSRAM
    //     variant (SDPx9B / SPx9B family, 9-bit lanes).
    //   - Default geometry AW=11, DW=32 (mem_t, C02 §1): 2K x 32b needs
    //     ceil(32/9)=4 byte-lane primitives of the SDPX9B class (2K x 9b
    //     each), address lines split identically to every lane.
    //
    // Reference instantiation shape (parameters/wire names per the licensed
    // Gowin GW5A primitive library — G6: verify against SUG550E + primitive
    // guide before enabling; ASSUMPTION: (TBD, 2026-09-01)):
    //
    //   for (genvar lane = 0; lane < NBYTES; lane++) begin : g_lane
    //       SDPX9B #(
    //           .BIT_WIDTH_0 (9),          // write side: byte lane (8 data + 1 parity)
    //           .BIT_WIDTH_1 (9),          // read  side
    //           .READ_MODE   (1'b0),       // read-first (matches eth_inf_ram)
    //           .BLK_SEL     (3'b000),
    //           .RESET_MODE  ("SYNC"),
    //           .INIT_RAM_00 (72'h0)       // ... INIT_RAM_00..3F; from INIT_HEX
    //       ) u_bsram (
    //           .CLKA  (clk_i),  .CKEA(en_i), .WREA(we_i && be_i[lane]),
    //           .CLKB  (clk_i),  .CKEB(en_i), .WREB(1'b0),
    //           .ADA   ({addr_i, {3{1'b0}}}),          // 14-bit phys addr, per SUG
    //           .ADB   ({addr_i, {3{1'b0}}}),
    //           .DIA   ({1'b0, wdata_i[lane*8 +: 8]}),
    //           .DOB   (/* {parity, rdata_o[lane*8 +: 8]} */),
    //           .OREA  (1'b0), .OREB(1'b1),
    //           .CLKAEN(1'b1), .CLKBEN(1'b1)
    //       );
    //   end
    //
    // This branch deliberately ships as a commented reference until a licensed
    // Gowin primitive simulation library is vendored (CI grep gate, C13 §4);
    // enabling -DGOWIN_PRIMITIVE today fails at elaboration / time-0 on purpose:
    initial begin
        $error("gowin_bsram: GOWIN_PRIMITIVE branch is documentation-in-code only; "
               + "vendor primitive bindings pending G6 verification (2026-09-01). "
               + "Build without -DGOWIN_PRIMITIVE (behavioral inference path).");
    end
    assign rdata_o = '0;
`else
    // ------------------------------------------------------------------
    // DEFAULT branch — pure behavioral inference (open chain + Verilator).
    // Zero vendor identifiers; yosys synth_gowin maps this to BSRAM via
    // memory inference + the `ETH_RAMSTYLE attribute layer.
    eth_inf_ram #(
        .AW       (AW),
        .DW       (DW),
        .INIT_HEX (INIT_HEX)
    ) u_ram (
        .clk_i   (clk_i),
        .en_i    (en_i),
        .we_i    (we_i),
        .be_i    (be_i),
        .addr_i  (addr_i),
        .wdata_i (wdata_i),
        .rdata_o (rdata_o)
    );
`endif

endmodule

`default_nettype wire
