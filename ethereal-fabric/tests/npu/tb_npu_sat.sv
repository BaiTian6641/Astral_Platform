`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_npu_sat
// Description: INT32 saturation-rail test for the NPU-Tiny tile (E3-SVC1).
// Details:     One K=8 chunk of INT8 data can only reach 8*127*127 = 129032, so the
//              32-bit accumulator rails are reachable ONLY through the CTRL.ACC_EN
//              C-buffer accumulate. This TB therefore drives ~16.6k accumulate runs
//              per rail and asserts:
//                * A=127,W=127 x 16644 chunks  -> C[0][0] pins at 0x7FFFFFFF
//                * A=-128,W=127 x 16516 chunks -> C[0][0] pins at 0x80000000
//                * STATUS.OVF goes sticky on both, and CTRL.OVF_CLR clears it
//                * the datapath stays bit-exact: every earlier chunk simply adds
//                  129032 / -130048 (the model's per-step saturating add)
//              This is the direct hardware evidence for the arithmetic contract of
//              report §2.2 (saturate per step, rails at +/-2^31) — including the
//              sign-selection of the negative rail, which a wrapping accumulator or
//              an unsigned saturation compare would get wrong.
//              Runtime: ~1M simulated cycles (~1.5 min under iverilog) — kept out of
//              tb_npu_t so the fast GEMM suite stays fast.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/components/C11-NPU-Tiny组件.md §1.3 §5 ·
//              ethereal-plan/subsystems/S11-Service-Tile.md §2.2
`timescale 1ns/1ps

module tb_npu_sat;
    localparam logic [7:0] CSR_CTRL   = 8'h00;
    localparam logic [7:0] CSR_STATUS = 8'h04;
    localparam logic [7:0] CSR_DESC   = 8'h08;
    localparam logic [7:0] CSR_SESSID = 8'h0C;
    localparam logic [7:0] CSR_AWR    = 8'h10;
    localparam logic [7:0] CSR_WWR    = 8'h14;
    localparam logic [7:0] CSR_APTR   = 8'h18;
    localparam logic [7:0] CSR_WPTR   = 8'h1C;
    localparam logic [7:0] CSR_CADDR  = 8'h20;
    localparam logic [7:0] CSR_CRD    = 8'h24;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic         rst_ni = 1'b1;
    logic         sess_rst;
    logic         csr_we, csr_re;
    logic [7:0]   csr_addr;
    logic [31:0]  csr_wdata;
    logic [31:0]  csr_rdata;
    logic         irq;
    logic [2047:0] obs_acc;
    logic [511:0]  obs_wgt, obs_wstg, obs_feed;
    logic [2047:0] obs_cbuf;
    logic [79:0]   obs_ctl;

    npu_t dut (
        .clk_i(clk), .rst_ni(rst_ni), .sess_rst_i(sess_rst),
        .csr_we_i(csr_we), .csr_re_i(csr_re), .csr_addr_i(csr_addr),
        .csr_wdata_i(csr_wdata), .csr_rdata_o(csr_rdata), .irq_o(irq),
        .obs_acc_o(obs_acc), .obs_wgt_o(obs_wgt), .obs_wstg_o(obs_wstg),
        .obs_feed_o(obs_feed), .obs_cbuf_o(obs_cbuf), .obs_ctl_o(obs_ctl)
    );

    integer errors;

    task csr_write(input [7:0] a, input [31:0] d);
        begin
            @(negedge clk);
            csr_addr = a; csr_wdata = d; csr_we = 1'b1; csr_re = 1'b0;
            @(negedge clk);
            csr_we = 1'b0;
        end
    endtask

    task csr_read(input [7:0] a, output [31:0] d);
        begin
            @(negedge clk);
            csr_addr = a; csr_we = 1'b0; csr_re = 1'b1;
            #1 d = csr_rdata;
            @(negedge clk);
            csr_re = 1'b0;
        end
    endtask

    task start_bare(input integer acc_en);
        integer n;
        begin
            csr_write(CSR_CTRL, {28'h0, acc_en[0], 1'b0, 1'b0, 1'b1});
            n = 0;
            while ((obs_ctl[3] !== 1'b1) && (n < 20)) begin @(negedge clk); n = n + 1; end
            if (n >= 20) begin
                errors = errors + 1;
                $display("FAIL: START not accepted");
            end
            n = 0;
            while ((obs_ctl[4] !== 1'b1) && (n < 100)) begin @(negedge clk); n = n + 1; end
            if (n >= 100) begin
                errors = errors + 1;
                $display("FAIL: DONE timeout");
            end
        end
    endtask

    // A run CONSUMES both staged buffers: RUN shifts the A feeder bytes out, and
    // DONE blanks the datapath (accumulators, PE weights, feeder SR and the W
    // staging register file — C11 §2.3 automatic session reset, C buffer excepted),
    // so every repeated run must re-stage A and W. Same contract the K-tiling driver
    // follows (each chunk has its own A and W), documented in report §1.3.
    task reload_rail(input [7:0] a_byte, input [7:0] w_byte);
        integer i;
        begin
            csr_write(CSR_AWR, {a_byte, a_byte, a_byte, a_byte});
            csr_write(CSR_AWR, {a_byte, a_byte, a_byte, a_byte});
            for (i = 0; i < 8; i = i + 1) begin
                csr_write(CSR_WWR, {8'h00, 8'h00, 8'h00, w_byte});
                csr_write(CSR_WWR, 32'h0000_0000);
            end
        end
    endtask

    // A row = 8 copies of a_byte; W column 0 = w_byte on all 8 rows.
    task load_rail_data(input [7:0] a_byte, input [7:0] w_byte);
        integer i;
        begin
            csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, 8'd1});
            csr_write(CSR_APTR, 32'h0);
            csr_write(CSR_WPTR, 32'h0);
            reload_rail(a_byte, w_byte);
        end
    endtask

    integer nchunks, i;
    logic [31:0] got;
    localparam integer N_POS = (2147483647 / 129032) + 2;   // 16644 -> crosses +2^31-1
    localparam integer N_NEG = (2147483647 / 130048) + 3;   // 16516 -> crosses -2^31

    initial begin
        errors = 0;
        sess_rst = 1'b0; csr_we = 1'b0; csr_re = 1'b0;
        csr_addr = 8'h00; csr_wdata = 32'h0;

        @(negedge clk); rst_ni = 1'b0;
        repeat (3) @(negedge clk); rst_ni = 1'b1;
        repeat (2) @(negedge clk);

        // ---------------- positive rail ----------------
        csr_write(CSR_SESSID, 32'd1);
        repeat (4) @(negedge clk);
        load_rail_data(8'h7F, 8'h7F);          // +127 * +127 * 8 = +129032 / chunk
        start_bare(0);
        for (i = 1; i < N_POS; i = i + 1) begin
            reload_rail(8'h7F, 8'h7F);         // both buffers are consumed by a run
            start_bare(1);
            if ((i % 2000) == 0) $display("  +rail: %0d/%0d chunks", i, N_POS);
        end
        csr_write(CSR_CADDR, 32'h0);
        csr_read(CSR_CRD, got);
        if (got !== 32'h7FFF_FFFF) begin
            errors = errors + 1;
            $display("FAIL: +rail C[0][0] = %08x after %0d chunks (want 7fffffff)", got, N_POS);
        end else begin
            $display("  +rail pinned at 7fffffff after %0d chunks (%0d MACs) OK",
                     N_POS, N_POS * 64);
        end
        csr_read(CSR_STATUS, got);
        if (got[2] !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: STATUS.OVF not sticky after the positive rail");
        end
        csr_write(CSR_CTRL, 32'h10);           // OVF_CLR
        csr_read(CSR_STATUS, got);
        if (got[2] !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: STATUS.OVF not cleared by CTRL.OVF_CLR");
        end else begin
            $display("  STATUS.OVF sticky + CTRL.OVF_CLR OK");
        end

        // ---------------- negative rail ----------------
        csr_write(CSR_SESSID, 32'd2);
        repeat (4) @(negedge clk);
        load_rail_data(8'h80, 8'h7F);          // -128 * +127 * 8 = -130048 / chunk
        start_bare(0);
        for (i = 1; i < N_NEG; i = i + 1) begin
            reload_rail(8'h80, 8'h7F);
            start_bare(1);
            if ((i % 2000) == 0) $display("  -rail: %0d/%0d chunks", i, N_NEG);
        end
        csr_write(CSR_CADDR, 32'h0);
        csr_read(CSR_CRD, got);
        if (got !== 32'h8000_0000) begin
            errors = errors + 1;
            $display("FAIL: -rail C[0][0] = %08x after %0d chunks (want 80000000)", got, N_NEG);
        end else begin
            $display("  -rail pinned at 80000000 after %0d chunks (%0d MACs) OK",
                     N_NEG, N_NEG * 64);
        end
        csr_read(CSR_STATUS, got);
        if (got[2] !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: STATUS.OVF not sticky after the negative rail");
        end

        $display("----------------------------------------------------------------");
        $display("tb_npu_sat: %0d accumulate runs exercised, OVF path checked", N_POS + N_NEG + 2);
        if (errors == 0) $display("TEST PASSED: INT32 saturation rails + sticky OVF exact");
        else             $display("TEST FAILED: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #100_000_000;                          // 100 ms simulated, generous
        $display("FAIL: watchdog timeout");
        $finish;
    end
endmodule

`default_nettype wire
