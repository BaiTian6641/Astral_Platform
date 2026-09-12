`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_npu_t
// Description: Self-checking testbench for the NPU-Tiny tile (E3-SVC1): every C
//              buffer word is compared against the Python golden model.
// Details:     Reads ethereal-fabric/tests/npu/vectors/npu_gemm_cases.txt, which
//              gen_npu_vectors.py derives from npu_model.py (the bit-exact
//              reference: exact INT8xINT8 products, saturating INT32 accumulate
//              at every step, K tiling via CTRL.ACC_EN). Cases cover M=8/M=3/M=1,
//              operand extremes, saturation-heavy data and a two-chunk K=16
//              session. At every session boundary the whole session state
//              (accumulators, weights, A feeder, W staging, C buffer, control and
//              counters) must read back blank; DONE blanks the datapath while the
//              C buffer stays readable. Also re-checks the CSR ABI: STATUS, DESC,
//              CYC_CNT (cycles per inference) and C_RD readback.
//              Negative control: -DNPU_LEAK_NEGCTL instantiates the tile with
//              LEAK_INJECT=1 (the session blank skips the datapath arrays) to
//              prove these assertions can fail.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S11-Service-Tile.md §3 §4 ·
//              ethereal-plan/components/C11-NPU-Tiny组件.md §5
`timescale 1ns/1ps

module tb_npu_t;
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
    localparam logic [7:0] CSR_CYC    = 8'h28;

    localparam string VEC = "ethereal-fabric/tests/npu/vectors/npu_gemm_cases.txt";

`ifdef NPU_LEAK_NEGCTL
    localparam bit LEAK = 1'b1;
`else
    localparam bit LEAK = 1'b0;
`endif

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

    npu_t #(.LEAK_INJECT(LEAK)) dut (
        .clk_i(clk), .rst_ni(rst_ni), .sess_rst_i(sess_rst),
        .csr_we_i(csr_we), .csr_re_i(csr_re), .csr_addr_i(csr_addr),
        .csr_wdata_i(csr_wdata), .csr_rdata_o(csr_rdata), .irq_o(irq),
        .obs_acc_o(obs_acc), .obs_wgt_o(obs_wgt), .obs_wstg_o(obs_wstg),
        .obs_feed_o(obs_feed), .obs_cbuf_o(obs_cbuf), .obs_ctl_o(obs_ctl)
    );

    integer errors;
    integer ncase;
    integer total_cycles;
    integer total_macs;
    integer fd;
    logic [31:0] cyc_expected_rtl;

    // ------------------------------------------------------------------ helpers
    task csr_write(input [7:0] a, input [31:0] d);
        begin
            @(negedge clk);
            csr_addr  = a;
            csr_wdata = d;
            csr_we    = 1'b1;
            csr_re    = 1'b0;
            @(negedge clk);
            csr_we    = 1'b0;
        end
    endtask

    // CSR reads are combinational and the strobe auto-increments C_RD's pointer at
    // the end of the strobe cycle, so the data MUST be sampled in the strobe cycle.
    task csr_read(input [7:0] a, output [31:0] d);
        begin
            @(negedge clk);
            csr_addr = a;
            csr_we   = 1'b0;
            csr_re   = 1'b1;
            #1 d = csr_rdata;
            @(negedge clk);
            csr_re = 1'b0;
        end
    endtask

    function integer rd_hex;
        input integer f;
        integer v;
        begin
            v = 0;
            if ($fscanf(f, "%h", v) != 1) begin
                $display("FAIL: vector file ended early");
                errors = errors + 1;
            end
            rd_hex = v & 32'h000000FF;
        end
    endfunction

    // C words are single 8-hex-digit tokens in the vector file.
    function integer rd_hex32;
        input integer f;
        integer v;
        begin
            v = 0;
            if ($fscanf(f, "%h", v) != 1) begin
                $display("FAIL: vector file ended early");
                errors = errors + 1;
            end
            rd_hex32 = v;
        end
    endfunction

    // Session state must read back blank at a session boundary (see report §4).
    task check_blank(input integer tag);
        begin
            if (obs_acc !== 2048'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): accumulator residue acc[63:0]=%h", tag, obs_acc[63:0]);
            end
            if (obs_wgt !== 512'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): weight register residue wgt[63:0]=%h", tag, obs_wgt[63:0]);
            end
            if (obs_wstg !== 512'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): W staging residue", tag);
            end
            if (obs_feed !== 512'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): A feeder residue", tag);
            end
            if (obs_cbuf !== 2048'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): C buffer residue c[0]=%08x", tag, obs_cbuf[31:0]);
            end
            if (obs_ctl[63:0] !== 64'h0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): control residue ctl[63:0]=%h", tag, obs_ctl[63:0]);
            end
            if (obs_ctl[2:0] !== 3'd0) begin
                errors = errors + 1;
                $display("FAIL boundary(tag %0d): FSM not IDLE", tag);
            end
        end
    endtask

    task session_begin(input integer tag);
        begin
            csr_write(CSR_SESSID, tag[31:0]);
            repeat (4) @(negedge clk);          // write -> CLR -> IDLE
            check_blank(tag);
        end
    endtask

    // A run is latched on START, so wait for BUSY first: done_r from the previous
    // chunk (ACC_EN continuation) is still set until LOAD_W begins.
    task wait_busy(input integer maxc);
        integer n;
        begin
            n = 0;
            while ((obs_ctl[3] !== 1'b1) && (n < maxc)) begin
                @(negedge clk);
                n = n + 1;
            end
            if (n >= maxc) begin
                errors = errors + 1;
                $display("FAIL: START not accepted (desc_err=%b m=%0d k=%0d n=%0d)",
                         obs_ctl[7], obs_ctl[42:35], obs_ctl[50:43], obs_ctl[58:51]);
            end
        end
    endtask

    task wait_done(input integer maxc);
        integer n;
        begin
            n = 0;
            while ((obs_ctl[4] !== 1'b1) && (n < maxc)) begin
                @(negedge clk);
                n = n + 1;
            end
            if (n >= maxc) begin
                errors = errors + 1;
                $display("FAIL: DONE timeout state=%0d busy=%b ld=%0d cyc=%0d m=%0d k=%0d n=%0d",
                         obs_ctl[2:0], obs_ctl[3], obs_ctl[16:14], obs_ctl[13:9],
                         obs_ctl[42:35], obs_ctl[50:43], obs_ctl[58:51]);
            end
        end
    endtask

    // Load A (M*8 bytes, row-major little-endian words) through CSR_A_WR.
    task load_a(input integer m, input integer f);
        integer i, b0, b1, b2, b3;
        begin
            for (i = 0; i < m * 2; i = i + 1) begin
                b0 = rd_hex(f); b1 = rd_hex(f); b2 = rd_hex(f); b3 = rd_hex(f);
                csr_write(CSR_AWR, {b3[7:0], b2[7:0], b1[7:0], b0[7:0]});
            end
        end
    endtask

    // Load W (64 bytes = 16 words) through CSR_W_WR.
    task load_w(input integer f);
        integer i, b0, b1, b2, b3;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                b0 = rd_hex(f); b1 = rd_hex(f); b2 = rd_hex(f); b3 = rd_hex(f);
                csr_write(CSR_WWR, {b3[7:0], b2[7:0], b1[7:0], b0[7:0]});
            end
        end
    endtask

    task start_run(input integer acc_en, input integer cyc_expected);
        begin
            // CTRL: [3]=ACC_EN, [2]=IRQ_EN, [1]=RESET, [0]=START
            csr_write(CSR_CTRL, {28'h0, acc_en[0], 1'b0, 1'b0, 1'b1});
            wait_busy(20);
            wait_done(400);
            csr_read(CSR_CYC, cyc_expected_rtl);
            if (cyc_expected_rtl !== cyc_expected) begin
                errors = errors + 1;
                $display("FAIL: CYC_CNT=%0d expected %0d", cyc_expected_rtl, cyc_expected);
            end
            if (obs_ctl[4] !== 1'b1) begin  // DONE
                errors = errors + 1;
                $display("FAIL: DONE not set (ctl=%h)", obs_ctl);
            end
        end
    endtask

    // Bare run (no CYC_CNT assertion): used by the long rep-loops below.
    task start_run_bare(input integer acc_en);
        begin
            csr_write(CSR_CTRL, {28'h0, acc_en[0], 1'b0, 1'b0, 1'b1});
            wait_busy(20);
            wait_done(400);
        end
    endtask

    // Write one 8-byte A row (two CSR words) and one weight row (W[k][0] = wb).
    task load_row_ones(input [31:0] a_byte, input [31:0] w_b0);
        integer i;
        begin
            csr_write(CSR_APTR, 32'h0);
            csr_write(CSR_AWR, {a_byte, a_byte, a_byte, a_byte});
            csr_write(CSR_AWR, {a_byte, a_byte, a_byte, a_byte});
            csr_write(CSR_WPTR, 32'h0);
            for (i = 0; i < 8; i = i + 1) begin
                csr_write(CSR_WWR, {8'h00, 8'h00, 8'h00, w_b0[7:0]});
                csr_write(CSR_WWR, 32'h0000_0000);
            end
        end
    endtask

    // IRQ contract (C11 §3.1 "OPC_IRQ 完成中断"): IRQ_EN=1 -> IRQ rises at DONE and is
    // acknowledged by a STATUS read.
    task irq_test;
        logic [31:0] got;
        begin
            csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, 8'd2});        // M=2
            // START with IRQ_EN=1 (a START write carries the whole control word)
            csr_write(CSR_CTRL, {28'h0, 1'b0, 1'b1, 1'b0, 1'b1});
            wait_busy(20);
            wait_done(400);
            if (obs_ctl[6] !== 1'b1 || irq !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: IRQ not asserted at DONE (irq=%b ctl=%h)", irq, obs_ctl);
            end
            csr_read(CSR_STATUS, got);
            if (got[3] !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: STATUS.IRQ not set at DONE");
            end
            csr_read(CSR_STATUS, got);
            if (irq !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: STATUS read did not acknowledge IRQ");
            end else begin
                $display("  IRQ: asserted at DONE, acked by STATUS read OK");
            end
            csr_write(CSR_CTRL, 32'h00);                           // IRQ_EN=0
        end
    endtask

    // Compare the whole C buffer (64 words) against the expected vector.
    task check_c(input integer f, input integer m, input integer tag);
        integer i;
        logic [31:0] got, exp;
        begin
            csr_write(CSR_CADDR, 32'h0);
            for (i = 0; i < 64; i = i + 1) begin
                exp = rd_hex32(f);
                csr_read(CSR_CRD, got);
                if (got !== exp) begin
                    errors = errors + 1;
                    $display("FAIL C[%0d] (tag %0d, M=%0d) got %08x want %08x",
                             i, tag, m, got, exp);
                end
            end
        end
    endtask

    // ------------------------------------------------------------------ main
    integer fm, fn, facc, ftag;
    integer prev_tag;
    localparam integer CYC_M = 25;    // LOAD_W(8)+RUN(M+8)+DRAIN(8)+DONE(1) = M+25

    initial begin
        errors        = 0;
        ncase         = 0;
        total_cycles  = 0;
        total_macs    = 0;
        prev_tag      = -1;
        rst_ni        = 1'b1;
        sess_rst      = 1'b0;
        csr_we        = 1'b0;
        csr_re        = 1'b0;
        csr_addr      = 8'h00;
        csr_wdata     = 32'h0;

        @(negedge clk); rst_ni = 1'b0;
        repeat (3) @(negedge clk); rst_ni = 1'b1;
        repeat (2) @(negedge clk);

        fd = $fopen(VEC, "r");
        if (fd == 0) begin
            $display("FAIL: cannot open %s", VEC);
            errors = errors + 1;
        end else begin
            while ($fscanf(fd, "%d %d %d %d", fm, fn, facc, ftag) == 4) begin
                if (facc == 0) begin
                    session_begin(ftag);              // boundary + blank assertion
                end else if (ftag !== prev_tag) begin
                    errors = errors + 1;
                    $display("FAIL: ACC=1 across a tag change (%0d -> %0d)", prev_tag, ftag);
                end
                prev_tag = ftag;
                csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, fm[7:0]});
                load_a(fm, fd);
                load_w(fd);
                start_run(facc, fm + CYC_M);
                check_c(fd, fm, ftag);
                // After DONE the datapath must be blank; the C buffer stays readable.
                if (obs_acc !== 2048'h0 || obs_wgt !== 512'h0 ||
                    obs_feed !== 512'h0 || obs_wstg !== 512'h0) begin
                    errors = errors + 1;
                    $display("FAIL: datapath not blank after DONE (tag %0d)", ftag);
                end
                if (obs_cbuf === 2048'h0 && fm == 8) begin
                    // sanity: an M=8 inference with non-zero data must not read 0
                    $display("NOTE: C buffer read back all-zero for tag %0d", ftag);
                end
                ncase        = ncase + 1;
                total_cycles = total_cycles + (fm + CYC_M);
                total_macs   = total_macs + fm * 64;
            end
            $fclose(fd);
        end

        // ---- IRQ contract (the INT32 saturation rails live in tb_npu_sat.sv) ----
        irq_test;

        $display("----------------------------------------------------------------");
        $display("tb_npu_t: %0d GEMM cases, %0d MACs, %0d cycles (%0d.%02d MAC/cycle avg)",
                 ncase, total_macs, total_cycles, total_macs / total_cycles,
                 ((total_macs * 100) / total_cycles) % 100);
        $display("tb_npu_t: peak array occupancy = 64 MAC/cycle (8x8 PEs)");
        if (errors == 0) $display("TEST PASSED: NPU-Tiny GEMM bit-exact vs golden model");
        else             $display("TEST FAILED: %0d error(s)", errors);
        $finish;
    end

    // Watchdog
    initial begin
        #2000000;
        $display("FAIL: watchdog timeout");
        $finish;
    end
endmodule

`default_nettype wire
