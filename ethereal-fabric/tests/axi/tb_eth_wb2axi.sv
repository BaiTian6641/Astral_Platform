`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_wb2axi (testbench, self-checking)
// Description: Directed unit TB for the eth_wb2axi Wishbone->AXI4 bridge.
//              Uses an AXI slave model with PROGRAMMABLE response delay to
//              cover the case the in-repo eth_axi_lite_slave does not create:
//              B (or R) arriving SEVERAL CYCLES after the AW/W (AR) handshake.
//
//              Checks:
//                1. WRITE with B delayed B_DELAY cycles: the Wishbone ack must
//                   NOT pulse before B is consumed (regression guard for the
//                   2026-08-30 premature-ack bug: transition on aw&w handshake
//                   left B unconsumed and wedged the next write).
//                2. A SECOND back-to-back write completes (no pending-B wedge).
//                3. READ with R delayed R_DELAY cycles: correct data + ack.
//                4. SLVERR write maps to wb_err_o (no ack).
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §3; docs/adr/ADR-018 (BMC=AXI master)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
`timescale 1ns/1ps

module tb_eth_wb2axi;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;
    logic clk = 1'b0;
    logic rst_n;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- Delay knobs (slave model) --------------------------------------------
    localparam int B_DELAY = 3;   // cycles B lags the AW&W acceptance
    localparam int R_DELAY = 2;   // cycles R lags the AR acceptance

    // -- DUT: eth_wb2axi ------------------------------------------------------
    localparam int AXI_AW = 32;
    localparam int AXI_DW = 32;

    // Wishbone side (TB = master)
    logic                  wb_cyc, wb_stb, wb_we;
    logic [AXI_AW-1:0]     wb_adr;
    logic [AXI_DW-1:0]     wb_dat_i;
    logic [(AXI_DW/8)-1:0] wb_sel;
    logic [AXI_DW-1:0]     wb_dat_o;
    logic                  wb_ack, wb_err;

    // AXI side (TB = delaying slave model)
    logic                  m_axi_awvalid, m_axi_awready;
    logic [AXI_AW-1:0]     m_axi_awaddr;
    logic [2:0]            m_axi_awprot;
    logic                  m_axi_wvalid, m_axi_wready;
    logic [AXI_DW-1:0]     m_axi_wdata;
    logic [(AXI_DW/8)-1:0] m_axi_wstrb;
    logic                  m_axi_bvalid, m_axi_bready;
    logic [1:0]            m_axi_bresp;
    logic                  m_axi_arvalid, m_axi_arready;
    logic [AXI_AW-1:0]     m_axi_araddr;
    logic [2:0]            m_axi_arprot;
    logic                  m_axi_rvalid, m_axi_rready;
    logic [AXI_DW-1:0]     m_axi_rdata;
    logic [1:0]            m_axi_rresp;

    eth_wb2axi #(.AXI_AW(AXI_AW), .AXI_DW(AXI_DW)) dut (
        .clk_i(clk), .rst_ni(rst_n),
        .wb_adr_i(wb_adr), .wb_dat_i(wb_dat_i), .wb_dat_o(wb_dat_o),
        .wb_we_i(wb_we), .wb_sel_i(wb_sel), .wb_stb_i(wb_stb), .wb_cyc_i(wb_cyc),
        .wb_ack_o(wb_ack), .wb_err_o(wb_err),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awprot(m_axi_awprot),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr), .m_axi_arprot(m_axi_arprot),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp)
    );

    // -- Delaying AXI slave model ---------------------------------------------
    // 16-word memory. AW/W accepted immediately; B asserted B_DELAY cycles
    // after the write completes, held until bready. AR accepted immediately;
    // R asserted R_DELAY cycles later, held until rready. A write to ERR_ADDR
    // produces SLVERR.
    localparam logic [31:0] ERR_ADDR = 32'hDEAD_BEEF;

    logic [31:0] mem [0:15];
    logic        wr_pend;          // write accepted, B pending
    logic [1:0]  wr_resp;
    int          b_cnt;
    logic        rd_pend;
    int          r_cnt;
    logic [31:0] rd_data;

    assign m_axi_awready = ~wr_pend;               // one write in flight
    assign m_axi_wready  = ~wr_pend;
    assign m_axi_arready = ~rd_pend;

    wire wr_fire = m_axi_awvalid & m_axi_awready & m_axi_wvalid & m_axi_wready;
    wire b_fire  = m_axi_bvalid & m_axi_bready;
    wire ar_fire = m_axi_arvalid & m_axi_arready;
    wire r_fire  = m_axi_rvalid & m_axi_rready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_pend <= 1'b0; wr_resp <= 2'b00; b_cnt <= 0;
            m_axi_bvalid <= 1'b0; m_axi_bresp <= 2'b00;
            rd_pend <= 1'b0; r_cnt <= 0;
            m_axi_rvalid <= 1'b0; m_axi_rdata <= 32'h0; m_axi_rresp <= 2'b00;
            rd_data <= 32'h0;
        end else begin
            // write channel
            if (wr_fire) begin
                if (m_axi_awaddr != ERR_ADDR)
                    mem[m_axi_awaddr[5:2]] <= m_axi_wdata;   // full-word store
                wr_pend <= 1'b1;
                wr_resp <= (m_axi_awaddr == ERR_ADDR) ? 2'b10 : 2'b00;  // SLVERR/OKAY
                b_cnt   <= 0;
            end else if (wr_pend && !m_axi_bvalid) begin
                if (b_cnt == B_DELAY) begin
                    m_axi_bvalid <= 1'b1;
                    m_axi_bresp  <= wr_resp;
                end else b_cnt <= b_cnt + 1;
            end
            if (b_fire) begin
                m_axi_bvalid <= 1'b0;
                wr_pend      <= 1'b0;
            end
            // read channel
            if (ar_fire) begin
                rd_data <= mem[m_axi_araddr[5:2]];
                rd_pend <= 1'b1;
                r_cnt   <= 0;
            end else if (rd_pend && !m_axi_rvalid) begin
                if (r_cnt == R_DELAY) begin
                    m_axi_rvalid <= 1'b1;
                    m_axi_rdata  <= rd_data;
                    m_axi_rresp  <= 2'b00;
                end else r_cnt <= r_cnt + 1;
            end
            if (r_fire) begin
                m_axi_rvalid <= 1'b0;
                rd_pend      <= 1'b0;
            end
        end
    end

    // -- Observability: cycle counter + B/ack ordering -------------------------
    int cyc;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) cyc <= 0; else cyc <= cyc + 1;

    int b_seen_cyc  = -1;   // last cycle B was consumed (updated at the b_fire edge)
    always_ff @(posedge clk) begin
        if (b_fire)  b_seen_cyc <= cyc;
    end

    // -- Wishbone master helpers (polling loops; iverilog-friendly, no fork) ---
    int errors = 0;

    task automatic wb_write(input logic [31:0] adr, input logic [31:0] dat,
                            output logic err_seen);
        int start_b_cyc;
        int to;
        begin
            @(negedge clk);
            start_b_cyc = b_seen_cyc;
            wb_adr = adr; wb_dat_i = dat; wb_sel = 4'hF;
            wb_we  = 1'b1; wb_cyc = 1'b1; wb_stb = 1'b1;
            err_seen = 1'b0;
            to = 0;
            while (!wb_ack && !wb_err && to < 50) begin
                @(negedge clk);
                to++;
            end
            if (!wb_ack && !wb_err) begin
                $display("TEST FAILED: wb_write(0x%08h) timeout", adr);
                errors++;
            end else begin
                err_seen = wb_err;
            end
            wb_cyc = 1'b0; wb_stb = 1'b0; wb_we = 1'b0;
            // Regression guard: at the moment we observe wb_ack (negedge, in-loop),
            // a B belonging to THIS write must already have been consumed
            // (b_seen_cyc was updated at an earlier posedge). With the
            // 2026-08-30 premature-ack bug, ack fired one cycle after the AW/W
            // handshake and B was never consumed -> b_seen_cyc == start_b_cyc.
            if (!err_seen && !(b_seen_cyc > start_b_cyc)) begin
                $display("TEST FAILED: ack before B (write 0x%08h): b@%0d (start_b@%0d)",
                         adr, b_seen_cyc, start_b_cyc);
                errors++;
            end
        end
    endtask

    task automatic wb_read(input logic [31:0] adr, output logic [31:0] dat);
        int to;
        begin
            @(negedge clk);
            wb_adr = adr; wb_sel = 4'hF;
            wb_we  = 1'b0; wb_cyc = 1'b1; wb_stb = 1'b1;
            to = 0;
            while (!wb_ack && !wb_err && to < 50) begin
                @(negedge clk);
                to++;
            end
            if (!wb_ack) begin
                $display("TEST FAILED: wb_read(0x%08h) timeout/err", adr);
                errors++;
            end
            dat = wb_dat_o;
            wb_cyc = 1'b0; wb_stb = 1'b0;
        end
    endtask

    // -- Stimulus --------------------------------------------------------------
    logic [31:0] rdata;
    logic        err_seen;

    initial begin
        wb_cyc = 0; wb_stb = 0; wb_we = 0; wb_adr = 0; wb_dat_i = 0; wb_sel = 4'h0;
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // 1. write with delayed B (word index 1 = addr 0x04)
        wb_write(32'h0000_0004, 32'h5AA5_C33C, err_seen);
        if (err_seen) begin
            $display("TEST FAILED: unexpected err on write #1");
            errors++;
        end

        // 2. SECOND back-to-back write must complete (no pending-B wedge)
        wb_write(32'h0000_0008, 32'hA5A5_5A5A, err_seen);
        if (err_seen) begin
            $display("TEST FAILED: unexpected err on write #2");
            errors++;
        end

        // 3. read back word 1 with delayed R
        wb_read(32'h0000_0004, rdata);
        if (rdata !== 32'h5AA5_C33C) begin
            $display("TEST FAILED: readback 0x%08h, expected 0x5AA5C33C", rdata);
            errors++;
        end

        // 4. SLVERR write -> wb_err_o pulse, no ack
        wb_write(ERR_ADDR, 32'h0000_0001, err_seen);
        if (!err_seen) begin
            $display("TEST FAILED: SLVERR write did not raise wb_err_o");
            errors++;
        end

        repeat (4) @(posedge clk);
        if (errors == 0)
            $display("TEST PASSED: delayed-B write + back-to-back write + delayed-R read + SLVERR->err all correct");
        $finish;
    end

    // -- Watchdog ---------------------------------------------------------------
    initial begin
        #100000;
        $display("TEST FAILED: global watchdog timeout");
        $finish;
    end

endmodule
`default_nettype wire
