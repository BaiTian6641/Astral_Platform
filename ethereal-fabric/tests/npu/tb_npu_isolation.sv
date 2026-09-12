`default_nettype none
// SPDX-License-Identifier: MIT
// Module:      tb_npu_isolation
// Description: Multi-container time-sharing / no-state-leak testbench for the
//              NPU-Tiny tile (E3-SVC1, S11 §2.1 "禁止跨会话状态泄漏").
// Details:     Two logical containers alternate on the tile (container 1 = M=8,
//              container 2 = M=2), each entering through a session boundary (a
//              SESSION_ID write) exactly as the EBI service daemon will do.
//              The state that must not leak is enumerated and each element is
//              checked (report §4):
//                1. accumulator state   -> obs_acc_o   (64 x 32b)
//                2. weight registers    -> obs_wgt_o   (64 x 8b)
//                3. A feeder shift regs -> obs_feed_o  (8 x 8B)
//                4. W staging buffer    -> obs_wstg_o  (8 x 8B)
//                5. C output buffer     -> obs_cbuf_o AND a CSR readback sweep of
//                                          all 64 words (the security-relevant one:
//                                          a container that reads C before running
//                                          would see the previous container's
//                                          results)
//                6. control/FSM/flags   -> obs_ctl_o[63:0]
//                7. pending counts      -> cyc/ld counters + staging pointers,
//                                          inside obs_ctl_o
//              Additional checks: order independence (container 1 re-run after
//              container 2 gives bit-identical results), unwritten C rows of the
//              M=2 container stay exactly 0, a mid-run RESET aborts and blanks,
//              and the fabric blank port sess_rst_i blanks a configured tile.
//              NEGATIVE CONTROL: -DNPU_LEAK_NEGCTL builds the tile with
//              LEAK_INJECT=1, whose session blank deliberately keeps the datapath
//              arrays. The same checks then MUST fail — that is the evidence that
//              these assertions are not vacuous.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S11-Service-Tile.md §2.1 §3 §4 ·
//              ethereal-plan/components/C11-NPU-Tiny组件.md §2.3 §5
`timescale 1ns/1ps

module tb_npu_isolation;
    localparam logic [7:0] CSR_CTRL   = 8'h00;
    localparam logic [7:0] CSR_STATUS = 8'h04;
    localparam logic [7:0] CSR_DESC   = 8'h08;
    localparam logic [7:0] CSR_SESSID = 8'h0C;
    localparam logic [7:0] CSR_AWR    = 8'h10;
    localparam logic [7:0] CSR_WWR    = 8'h14;
    localparam logic [7:0] CSR_CADDR  = 8'h20;
    localparam logic [7:0] CSR_CRD    = 8'h24;

    localparam string VEC = "ethereal-fabric/tests/npu/vectors/npu_iso_cases.txt";
    localparam integer CYC_M = 25;   // LOAD_W(8) + RUN(M+8) + DRAIN(8) + DONE(1)

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
    integer ncheck;                    // number of isolation assertions exercised
    logic [31:0] c_first [0:63];       // container 1's first readback
    integer fd;

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

    // ------------------------------------------------------------------
    // The no-leak assertion: every element of the session state is blank.
    // ------------------------------------------------------------------
    task check_blank(input integer tag);
        begin
            ncheck = ncheck + 1;
            if (obs_acc !== 2048'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): PE accumulator residue (obs_acc[63:0]=%h)", tag, obs_acc[63:0]);
            end
            if (obs_wgt !== 512'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): PE weight register residue (obs_wgt[63:0]=%h)", tag, obs_wgt[63:0]);
            end
            if (obs_feed !== 512'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): A feeder shift-register residue (obs_feed[63:0]=%h)", tag, obs_feed[63:0]);
            end
            if (obs_wstg !== 512'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): W staging residue (obs_wstg[63:0]=%h)", tag, obs_wstg[63:0]);
            end
            if (obs_cbuf !== 2048'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): C buffer residue (obs_cbuf[31:0]=%08x)", tag, obs_cbuf[31:0]);
            end
            if (obs_ctl[63:0] !== 64'h0) begin
                errors = errors + 1;
                $display("LEAK(tag %0d): control/counter residue (obs_ctl[63:0]=%h)", tag, obs_ctl[63:0]);
            end
            if (obs_ctl[79:64] !== tag[15:0]) begin
                errors = errors + 1;
                $display("FAIL(tag %0d): SESSION_ID echo is %0d", tag, obs_ctl[79:64]);
            end
        end
    endtask

    // A container that peeks at the C buffer before its own run must see zeros.
    task check_c_zero(input integer tag);
        integer i;
        logic [31:0] got;
        begin
            ncheck = ncheck + 1;
            csr_write(CSR_CADDR, 32'h0);
            for (i = 0; i < 64; i = i + 1) begin
                csr_read(CSR_CRD, got);
                if (got !== 32'h0) begin
                    errors = errors + 1;
                    $display("LEAK(tag %0d): C[%0d] readable before the run = %08x (cross-container data)",
                             tag, i, got);
                end
            end
        end
    endtask

    task session_begin(input integer tag);
        begin
            csr_write(CSR_SESSID, tag[31:0]);
            repeat (4) @(negedge clk);
            check_blank(tag);
            check_c_zero(tag);
        end
    endtask

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
                $display("FAIL: START not accepted");
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
                $display("FAIL: DONE timeout (state=%0d)", obs_ctl[2:0]);
            end
        end
    endtask

    task load_a(input integer m, input integer f);
        integer i, b0, b1, b2, b3;
        begin
            for (i = 0; i < m * 2; i = i + 1) begin
                b0 = rd_hex(f); b1 = rd_hex(f); b2 = rd_hex(f); b3 = rd_hex(f);
                csr_write(CSR_AWR, {b3[7:0], b2[7:0], b1[7:0], b0[7:0]});
            end
        end
    endtask

    task load_w(input integer f);
        integer i, b0, b1, b2, b3;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                b0 = rd_hex(f); b1 = rd_hex(f); b2 = rd_hex(f); b3 = rd_hex(f);
                csr_write(CSR_WWR, {b3[7:0], b2[7:0], b1[7:0], b0[7:0]});
            end
        end
    endtask

    task run_case(input integer m, input integer f, input integer tag,
                  input integer save_first);
        integer i;
        logic [31:0] got, exp;
        begin
            csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, m[7:0]});
            load_a(m, f);
            load_w(f);
            csr_write(CSR_CTRL, 32'h1);        // START (ACC_EN=0, fresh chunk)
            wait_busy(20);
            wait_done(400);
            csr_write(CSR_CADDR, 32'h0);
            for (i = 0; i < 64; i = i + 1) begin
                exp = rd_hex32(f);
                csr_read(CSR_CRD, got);
                if (got !== exp) begin
                    errors = errors + 1;
                    $display("LEAK/FAIL(tag %0d): C[%0d] = %08x, golden %08x", tag, i, got, exp);
                end
                if (save_first) c_first[i] = got;
                if (!save_first && ((i / 8) >= m) && (got !== 32'h0)) begin
                    errors = errors + 1;
                    $display("LEAK(tag %0d): C[%0d] (row %0d >= M=%0d) = %08x, must be blank",
                             tag, i, i / 8, m, got);
                end
                if (!save_first && ((i / 8) < m) && (got !== c_first[i]) && (tag == 3)) begin
                    errors = errors + 1;
                    $display("FAIL(tag %0d): container 1 re-run differs at C[%0d]: %08x vs %08x",
                             tag, i, got, c_first[i]);
                end
            end
        end
    endtask

    // Mid-run abort (CTRL.RESET) and the fabric blank port must both leave the
    // tile in the blank state — the region-reconfiguration requirement.
    task abort_and_blank_check(input integer tag);
        integer i;
        logic [31:0] got;
        begin
            ncheck = ncheck + 1;
            session_begin(tag);                // own session; RESET keeps the tag
            // configure and start a real run, then abort it mid-flight
            csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, 8'd8});
            for (i = 0; i < 16; i = i + 1) begin
                csr_write(CSR_AWR, 32'h7f7f7f7f);
                csr_write(CSR_WWR, 32'h7f7f7f7f);
            end
            csr_write(CSR_CTRL, 32'h1);        // START
            wait_busy(20);
            repeat (5) @(negedge clk);         // abort in the middle of RUN
            csr_write(CSR_CTRL, 32'h2);        // CTRL.RESET (session blank)
            repeat (6) @(negedge clk);
            check_blank(tag);
            csr_write(CSR_CADDR, 32'h0);
            for (i = 0; i < 64; i = i + 1) begin
                csr_read(CSR_CRD, got);
                if (got !== 32'h0) begin
                    errors = errors + 1;
                    $display("LEAK(tag %0d): aborted run left C[%0d] = %08x", tag, i, got);
                end
            end
            // the hardware blank path (OCC blank-before-write) must behave the same
            csr_write(CSR_DESC, {8'h00, 8'd8, 8'd8, 8'd8});
            for (i = 0; i < 16; i = i + 1) begin
                csr_write(CSR_AWR, 32'h7f7f7f7f);
                csr_write(CSR_WWR, 32'h7f7f7f7f);
            end
            csr_write(CSR_CTRL, 32'h1);
            wait_busy(20);
            repeat (5) @(negedge clk);
            @(negedge clk); sess_rst = 1'b1;
            @(negedge clk); sess_rst = 1'b0;
            repeat (6) @(negedge clk);
            check_blank(tag);
        end
    endtask

    integer fm, fn, facc, ftag, prev_tag;
    initial begin
        errors   = 0;
        ncheck   = 0;
        prev_tag = -1;
        sess_rst = 1'b0;
        csr_we   = 1'b0;
        csr_re   = 1'b0;
        csr_addr = 8'h00;
        csr_wdata = 32'h0;

        @(negedge clk); rst_ni = 1'b0;
        repeat (3) @(negedge clk); rst_ni = 1'b1;
        repeat (2) @(negedge clk);

        fd = $fopen(VEC, "r");
        if (fd == 0) begin
            $display("FAIL: cannot open %s", VEC);
            errors = errors + 1;
        end else begin
            while ($fscanf(fd, "%d %d %d %d", fm, fn, facc, ftag) == 4) begin
                if (ftag !== prev_tag) begin
                    session_begin(ftag);                 // container switch
                    $display("  container %0d session opened (M=%0d)", ftag, fm);
                end
                prev_tag = ftag;
                run_case(fm, fd, ftag, (ftag == 1));
            end
            $fclose(fd);
        end

        abort_and_blank_check(99);

        $display("----------------------------------------------------------------");
        $display("tb_npu_isolation: %0d isolation assertions over 4 container sessions", ncheck);
        if (LEAK) begin
            if (errors > 0) begin
                $display("NEGATIVE CONTROL OK: %0d violation(s) detected with LEAK_INJECT=1", errors);
            end else begin
                $display("NEGATIVE CONTROL BROKEN: leak injected but no violation detected");
            end
            $display("TEST FAILED: %0d error(s) (negative control — leaks must be detected)", errors);
        end else begin
            if (errors == 0) $display("TEST PASSED: no cross-container state leak over 4 sessions");
            else             $display("TEST FAILED: %0d error(s)", errors);
        end
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL: watchdog timeout");
        $finish;
    end
endmodule

`default_nettype wire
