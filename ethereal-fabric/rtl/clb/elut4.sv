`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      elut4
// Description: Virtual LUT4 + 1 virtual FF — the atomic Ethereal fabric element.
// Details:     A 4-input truth table (16 bit) selected by vin; the output is
//              optionally registered by a virtual FF (clock-enable + configurable
//              synchronous reset) and optionally inverted. Configuration
//              (tt / ff_en / ff_rst_en / ff_rst_val / out_inv) is loaded via
//              cfg_we_i / cfg_data_i and PERSISTS across the user reset (rst_ni
//              only affects the virtual logic FF, never the fabric config).
//              v1 stores the truth table in FFs + a 16:1 mux (explicit, readable,
//              readback-trivial); v2 will switch to eth_inf_lutram (C01 §0,
//              ADR-017). No vendor primitives instantiated (ADR-017).
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Modified:    2026-07-24 - initial implementation (task E0-FAB1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C01-fabric-核心单元.md §1
// Notes:       Frozen v1 interface per C01 §1.3. cfg_data_i bitfield follows the
//              C01 concatenation order {tt[15:0], ff_en, ff_rst_en, ff_rst_val,
//              out_inv}:  [19:4]=tt, [3]=ff_en, [2]=ff_rst_en, [1]=ff_rst_val,
//              [0]=out_inv.
//              ASSUMPTION (TBD 2026-07-24): the virtual FF uses a SYNCHRONOUS
//              active-low reset (rst_ni), applied only when ff_rst_en=1, with
//              reset priority over clock-enable. To be confirmed against the
//              authoritative SystemVerilog RTL Policy doc (not yet linked,
//              ethereal-plan/README.md §4); meanwhile this is the
//              inference-friendly default per ADR-017.
//              During a config write (cfg_we_i=1) the output is UNDEFINED by
//              design — the OCC guarantees the region is blank/halted during
//              configuration (C01 §1.4), so the unit needs no self-protection.

module elut4 (
    input  logic        clk_i,       // fabric user clock (drives the virtual FF)
    input  logic        rst_ni,      // user reset, active-low (gated by ff_rst_en)
    input  logic [3:0]  vin_i,       // virtual 4-bit input (from CLB local interconnect)
    output logic        vout_o,      // virtual output (combinational or registered)
    input  logic        cfg_we_i,    // config write enable (1 cycle when this unit is selected)
    input  logic [19:0] cfg_data_i,  // {tt[15:0], ff_en, ff_rst_en, ff_rst_val, out_inv}
    input  logic        cfg_ce_i     // virtual FF clock-enable (maps the user CE)
);

    // ---- Configuration registers (written only via cfg_we_i; persist across rst_ni) ----
    logic [15:0] tt_r;          // truth table
    logic        ff_en_r;       // 1 = register the LUT output
    logic        ff_rst_en_r;   // 1 = user reset affects the virtual FF
    logic        ff_rst_val_r;  // value loaded into vff_r on reset
    logic        out_inv_r;     // 1 = invert the output

    // ---- Virtual logic FF ----
    logic        vff_r;         // registered LUT output

    // ---- Combinational LUT4 output (16:1 mux = tt_r indexed by vin_i) ----
    logic        comb_out;
    assign comb_out = tt_r[vin_i];

    // ---- Configuration write ----
    always_ff @(posedge clk_i) begin
        if (cfg_we_i) begin
            tt_r         <= cfg_data_i[19:4];
            ff_en_r      <= cfg_data_i[3];
            ff_rst_en_r  <= cfg_data_i[2];
            ff_rst_val_r <= cfg_data_i[1];
            out_inv_r    <= cfg_data_i[0];
        end
    end

    // ---- Virtual FF: synchronous reset (gated by ff_rst_en_r, priority over CE) + CE ----
    always_ff @(posedge clk_i) begin
        if (ff_rst_en_r && !rst_ni) begin
            vff_r <= ff_rst_val_r;
        end else if (cfg_ce_i) begin
            vff_r <= comb_out;
        end
    end

    // ---- Output mux: registered vs combinational, then optional invert ----
    logic muxed;
    assign muxed  = ff_en_r ? vff_r : comb_out;
    assign vout_o = out_inv_r ? ~muxed : muxed;

endmodule

`default_nettype wire
