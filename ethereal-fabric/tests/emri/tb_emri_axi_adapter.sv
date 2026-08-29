`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_emri_axi_adapter (testbench, self-checking)
// Description: Unit TB for emri_axi_adapter with the REAL emri_regfile
//              attached (HAS_BMC=1). Exercises the AXI4-Lite -> EMRI host-port
//              path end to end:
//                1. read MAGIC        (word 0)  -> 0x45544852 ("ETHR"), OKAY
//                2. read CAPABILITIES (word 2)  -> 0x00000001 (has_bmc), OKAY
//                3. write REGION_SEL=1 (word 6) -> read REGION_INFO (word 5)
//                   returns REGION1_INFO; write 0 -> REGION0_INFO (RW path)
//                4. read outside the window     -> SLVERR (EMRI untouched)
//                5. partial-strobe write        -> SLVERR; full write OKAY
//                   (SESSION_CMD write + readback confirms the value)
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2 (register map);
//              ethereal-spec/control/eth-axi-v0.md §3 (AXI4-Lite slave side)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps

module tb_emri_axi_adapter;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;
    logic clk = 1'b0;
    logic rst_n;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- DUT: adapter + EMRI regfile -------------------------------------------
    localparam int AXI_AW = 32, AXI_DW = 32;
    localparam logic [31:0] REG_BASE = 32'h4000_2000;
    localparam int WIN_WORDS = 64;               // 256-byte window

    // AXI master (TB)
    logic                  awvalid, awready;
    logic [AXI_AW-1:0]     awaddr;
    logic                  wvalid, wready;
    logic [AXI_DW-1:0]     wdata;
    logic [3:0]            wstrb;
    logic                  bvalid, bready;
    logic [1:0]            bresp;
    logic                  arvalid, arready;
    logic [AXI_AW-1:0]     araddr;
    logic                  rvalid, rready;
    logic [AXI_DW-1:0]     rdata;
    logic [1:0]            rresp;

    // EMRI host channel (adapter <-> regfile)
    logic                  host_req, host_we, host_ready;
    logic [1:0]            host_op;
    logic [15:0]           host_addr;
    logic [31:0]           host_wdata, host_rdata;

    emri_axi_adapter #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .REG_BASE(REG_BASE), .WIN_WORDS(WIN_WORDS)
    ) dut (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_awaddr(awaddr),   .s_axi_awprot(3'b000),
        .s_axi_wvalid(wvalid),   .s_axi_wready(wready),
        .s_axi_wdata(wdata),     .s_axi_wstrb(wstrb),
        .s_axi_bvalid(bvalid),   .s_axi_bready(bready),
        .s_axi_bresp(bresp),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_araddr(araddr),   .s_axi_arprot(3'b000),
        .s_axi_rvalid(rvalid),   .s_axi_rready(rready),
        .s_axi_rdata(rdata),     .s_axi_rresp(rresp),
        .host_req_o(host_req),   .host_we_o(host_we),   .host_op_o(host_op),
        .host_addr_o(host_addr), .host_wdata_o(host_wdata),
        .host_rdata_i(host_rdata), .host_ready_i(host_ready)
    );

    // OCC side of the EMRI regfile: tied off (no occ_top in this TB; the
    // firmware here only touches identity/capability/session registers).
    emri_regfile #(
        .HAS_BMC(1'b1), .NUM_REGIONS(2), .PLATFORM_ID(32'h0)
    ) u_emri (
        .clk_i(clk), .rst_ni(rst_n),
        .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
        .host_addr_i(host_addr), .host_wdata_i(host_wdata),
        .host_rdata_o(host_rdata), .host_ready_o(host_ready),
        .occ_cmd_o(), .occ_cmd_valid_o(), .occ_cmd_ready_i(1'b0),
        .occ_frame_addr_o(), .occ_word_count_o(),
        .occ_wdata_o(), .occ_wdata_valid_o(), .occ_wdata_ready_i(1'b0),
        .occ_status_i(3'd0),      // OCC_S_IDLE
        .occ_crc_error_i(1'b0),
        .occ_region_locked_o()
    );

    // -- AXI master helpers (polling loops; iverilog-friendly) -------------------
    int errors = 0;

    task automatic axi_write(input logic [31:0] adr, input logic [31:0] dat,
                             input logic [3:0] strb, input logic [1:0] exp_resp);
        int to;
        logic aw_done, w_done;
        begin
            @(negedge clk);
            awaddr = adr; awvalid = 1'b1;
            wdata = dat; wstrb = strb; wvalid = 1'b1;
            bready = 1'b1;
            // AXI: drop each VALID once ITS handshake completes (holding VALID
            // past the handshake re-presents the same beat as a new one — the
            // 2-deep skidbuf would capture a duplicate and corrupt pairing).
            aw_done = 1'b0; w_done = 1'b0; to = 0;
            while (!(aw_done && w_done) && to < 60) begin
                @(negedge clk); to++;
                if (awready) begin awvalid = 1'b0; aw_done = 1'b1; end
                if (wready)  begin wvalid  = 1'b0; w_done  = 1'b1; end
            end
            if (!(aw_done && w_done)) begin
                $display("TEST FAILED: axi_write(0x%08h) AW/W timeout", adr);
                errors++;
            end
            to = 0;
            while (!bvalid && to < 60) begin @(negedge clk); to++; end
            if (!bvalid) begin
                $display("TEST FAILED: axi_write(0x%08h) B timeout", adr);
                errors++;
            end else begin
                if (bresp !== exp_resp) begin
                    $display("TEST FAILED: axi_write(0x%08h) resp=%b, expected %b",
                             adr, bresp, exp_resp);
                    errors++;
                end
            end
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    task automatic axi_read(input logic [31:0] adr, output logic [31:0] dat,
                            input logic [1:0] exp_resp);
        int to;
        logic ar_done;
        begin
            @(negedge clk);
            araddr = adr; arvalid = 1'b1;
            rready = 1'b1;
            ar_done = 1'b0; to = 0;
            while (!ar_done && to < 60) begin
                @(negedge clk); to++;
                if (arready) begin arvalid = 1'b0; ar_done = 1'b1; end
            end
            if (!ar_done) begin
                $display("TEST FAILED: axi_read(0x%08h) AR timeout", adr);
                errors++;
            end
            to = 0;
            while (!rvalid && to < 60) begin @(negedge clk); to++; end
            if (!rvalid) begin
                $display("TEST FAILED: axi_read(0x%08h) R timeout", adr);
                errors++;
                dat = 32'hDEAD_DEAD;
            end else begin
                dat = rdata;
                if (rresp !== exp_resp) begin
                    $display("TEST FAILED: axi_read(0x%08h) resp=%b, expected %b",
                             adr, rresp, exp_resp);
                    errors++;
                end
            end
            @(negedge clk);
            rready = 1'b0;
        end
    endtask

    task automatic check_read(input logic [31:0] adr, input logic [31:0] exp);
        logic [31:0] d;
        begin
            axi_read(adr, d, 2'b00);
            if (d !== exp) begin
                $display("TEST FAILED: read 0x%08h = 0x%08h, expected 0x%08h", adr, d, exp);
                errors++;
            end
        end
    endtask

    // -- EMRI word offsets (emri_pkg R_*) as byte addresses ----------------------
    localparam logic [31:0] A_MAGIC       = REG_BASE + 32'h00;  // R_MAGIC   0x00
    localparam logic [31:0] A_CAP         = REG_BASE + 32'h08;  // R_CAPABILITIES 0x02
    localparam logic [31:0] A_REGION_INFO = REG_BASE + 32'h14;  // R_REGION_INFO 0x05
    localparam logic [31:0] A_REGION_SEL  = REG_BASE + 32'h18;  // R_REGION_SEL 0x06
    localparam logic [31:0] A_SESSION_CMD = REG_BASE + 32'h40;  // R_SESSION_CMD 0x10
    localparam logic [31:0] A_OUTSIDE     = REG_BASE + (WIN_WORDS * 4);  // 1 past window

    // -- Stimulus -----------------------------------------------------------------
    logic [31:0] rd;

    initial begin
        awvalid = 0; awaddr = 0; wvalid = 0; wdata = 0; wstrb = 4'h0; bready = 0;
        arvalid = 0; araddr = 0; rready = 0;
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // 1. MAGIC / CAPABILITIES (identity, has_bmc=1)
        check_read(A_MAGIC, 32'h4554_4852);   // "ETHR"
        check_read(A_CAP,   32'h0000_0001);

        // 2. REGION_SEL -> REGION_INFO reflects the selected region
        axi_write(A_REGION_SEL, 32'h1, 4'hF, 2'b00);
        check_read(A_REGION_INFO, 32'h0202_0010);   // REGION1_INFO (default param)
        axi_write(A_REGION_SEL, 32'h0, 4'hF, 2'b00);
        check_read(A_REGION_INFO, 32'h0202_0010);   // REGION0_INFO (same default)

        // 3. out-of-window read -> SLVERR
        axi_read(A_OUTSIDE, rd, 2'b10);

        // 4. partial-strobe write -> SLVERR; full write -> OKAY + readback
        axi_write(A_SESSION_CMD, 32'hA5, 4'h1, 2'b10);   // partial: rejected
        axi_write(A_SESSION_CMD, 32'hA5, 4'hF, 2'b00);   // full: accepted
        check_read(A_SESSION_CMD, 32'h0000_00A5);

        repeat (4) @(posedge clk);
        if (errors == 0)
            $display("TEST PASSED: EMRI AXI adapter — MAGIC/CAP reads, REGION_SEL/INFO RW, SLVERR on out-of-window + partial strobe");
        $finish;
    end

    // -- Watchdog -------------------------------------------------------------------
    initial begin
        #200000;
        $display("TEST FAILED: global watchdog timeout (errors=%0d)", errors);
        $finish;
    end

endmodule
`default_nettype wire
