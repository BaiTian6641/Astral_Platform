`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_lsu
// Description: Load/store unit datapath for eth_rv: byte-lane rotation, sub-word
//              extraction and byte-enable generation.
// Details:     Sits between the MEM stage and the v0 data port. The port is a
//              **64-bit aligned-beat** port — the same shape AXI4 hands over on
//              the R/W data channels, which is what the next slice has to feed it
//              from `eth_axi`:
//
//                read : `rdata_i` carries the eight bytes of the 8-byte-aligned
//                       window at `addr_o & ~7`; this unit rotates the window
//                       right by `addr_o[2:0]` and then truncates/sign-extends
//                       per `size_i`.
//                write: `wstrb_o` marks byte lanes inside that same aligned
//                       window and `wdata_o` carries `store_data_i` in those
//                       lanes, so a downstream memory just stores
//                       `wdata_o[8*lane +: 8]` at `(addr_o & ~7) + lane`.
//
//              `misaligned_o` flags a transfer that a single aligned beat cannot
//              serve (a halfword at an odd address, a word crossing the window,
//              …). The core turns that into its error strobe: the RV-B v0 slice
//              has no misaligned-access path, and silently splitting or
//              truncating such an access is exactly the "retired but wrong"
//              failure mode the trace contract exists to prevent.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (MEM stage), §4 (D port)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Pure combinational. `mem_size_e` lives in eth_rv_pkg, so a size/sign
//              mismatch is a type error rather than a silent truncation.
module cor_lsu (
    input  logic                        signed_i,      // sign-extend the loaded value
    input  eth_rv_pkg::mem_size_e       size_i,
    input  logic [2:0]                  byte_off_i,    // addr[2:0]: offset inside the aligned window
    input  logic [eth_rv_pkg::XLEN-1:0] store_data_i,
    input  logic [eth_rv_pkg::XLEN-1:0] rdata_i,       // the aligned 8-byte window at addr & ~7
    output logic [eth_rv_pkg::XLEN-1:0] load_data_o,
    output logic [eth_rv_pkg::XLEN-1:0] wdata_o,
    output logic [7:0]                  wstrb_o,
    output logic                        misaligned_o
);

    logic [7:0]                  lane_mask;
    logic [eth_rv_pkg::XLEN-1:0] rdata_rot;
    logic [eth_rv_pkg::XLEN-1:0] load_ext;

    // byte lanes of the aligned beat that this transfer covers
    always_comb begin
        lane_mask = 8'hFF;
        unique case (size_i)
            eth_rv_pkg::SZ_BYTE: lane_mask = 8'h01;
            eth_rv_pkg::SZ_HALF: lane_mask = 8'h03;
            eth_rv_pkg::SZ_WORD: lane_mask = 8'h0F;
            default:             lane_mask = 8'hFF;
        endcase
    end

    // a single aligned beat serves the transfer only when size <= 8 - addr[2:0]
    // with addr[2:0] a multiple of the size
    always_comb begin
        misaligned_o = 1'b0;
        unique case (size_i)
            eth_rv_pkg::SZ_BYTE: misaligned_o = 1'b0;
            eth_rv_pkg::SZ_HALF: misaligned_o = byte_off_i[0];
            eth_rv_pkg::SZ_WORD: misaligned_o = |byte_off_i[1:0];
            default:             misaligned_o = |byte_off_i;
        endcase
    end

    assign rdata_rot = rdata_i >> {byte_off_i, 3'b000};

    always_comb begin
        load_ext = rdata_rot;
        unique case (size_i)
            eth_rv_pkg::SZ_BYTE: begin
                load_ext = signed_i ? {{56{rdata_rot[7]}},  rdata_rot[7:0]}
                                    : {56'd0,              rdata_rot[7:0]};
            end
            eth_rv_pkg::SZ_HALF: begin
                load_ext = signed_i ? {{48{rdata_rot[15]}}, rdata_rot[15:0]}
                                    : {48'd0,              rdata_rot[15:0]};
            end
            eth_rv_pkg::SZ_WORD: begin
                load_ext = signed_i ? {{32{rdata_rot[31]}}, rdata_rot[31:0]}
                                    : {32'd0,              rdata_rot[31:0]};
            end
            default: begin
                load_ext = rdata_rot;
            end
        endcase
    end

    assign load_data_o = load_ext;
    assign wstrb_o     = lane_mask << byte_off_i;
    assign wdata_o     = store_data_i << {byte_off_i, 3'b000};

endmodule
`default_nettype wire
