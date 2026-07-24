`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_occ
// Description: Self-checking SystemVerilog testbench for occ_top (OCC v0, E0-FAB4).
// Details:     Instantiates occ_top + column_cfg_ram (frame-bus target) and
//              exercises the v0 command set:
//                1. WRITE then READBACK of an 8-word "counter config" pattern ->
//                   status=DONE, CRC matches (crc_error=0).
//                2. CRC tamper: backdoor-flip one RAM word, READBACK ->
//                   status=ERROR, crc_error=1 (sticky).
//                3. BLANK an 8-word frame -> DONE, all target RAM words == 0.
//                4. LOCK blocks WRITE: region_locked_i=1 + WRITE -> status=LOCKED,
//                   cmd_ready=0, RAM unchanged.
//                5. NOP / idle: status=IDLE with no command.
//              Run: iverilog -g2012 -o /tmp/tb_occ tb_occ.sv column_cfg_ram.sv \
//                              ../../rtl/occ/occ_top.sv && vvp /tmp/tb_occ
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C03-OCC组件.md §2
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
//              Drives inputs at negedge, samples combinational outputs after a #1
//              settle. iverilog -g2012 compatible (no SV-2017-only constructs).
module tb_occ;
    localparam int ADDR_W = 16;
    localparam int DATA_W = 32;

    logic                  clk;
    logic                  rst_n;
    logic [1:0]            cmd;
    logic                  cmd_valid;
    logic                  cmd_ready;
    logic [ADDR_W-1:0]     frame_addr;
    logic [15:0]           word_count;
    logic [DATA_W-1:0]     wdata;
    logic                  wdata_valid;
    logic                  wdata_ready;
    logic [ADDR_W-1:0]     fbus_addr;
    logic [DATA_W-1:0]     fbus_wdata;
    logic                  fbus_we;
    logic                  fbus_re;
    logic [DATA_W-1:0]     fbus_rdata;
    logic [2:0]            status;
    logic                  crc_error;
    logic                  region_locked;

    integer errors = 0;

    // status encodings (must match occ_top status_o)
    localparam logic [2:0] S_IDLE   = 3'd0;
    localparam logic [2:0] S_BUSY   = 3'd1;
    localparam logic [2:0] S_DONE   = 3'd2;
    localparam logic [2:0] S_ERROR  = 3'd3;
    localparam logic [2:0] S_LOCKED = 3'd4;
    // command encodings
    localparam logic [1:0] CMD_NOP      = 2'd0;
    localparam logic [1:0] CMD_WRITE    = 2'd1;
    localparam logic [1:0] CMD_READBACK = 2'd2;
    localparam logic [1:0] CMD_BLANK    = 2'd3;

    // ---- clock ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- DUT ----
    occ_top #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .cmd_i         (cmd),
        .cmd_valid_i   (cmd_valid),
        .cmd_ready_o   (cmd_ready),
        .frame_addr_i  (frame_addr),
        .word_count_i  (word_count),
        .wdata_i       (wdata),
        .wdata_valid_i (wdata_valid),
        .wdata_ready_o (wdata_ready),
        .fbus_addr_o   (fbus_addr),
        .fbus_wdata_o  (fbus_wdata),
        .fbus_we_o     (fbus_we),
        .fbus_re_o     (fbus_re),
        .fbus_rdata_i  (fbus_rdata),
        .status_o      (status),
        .crc_error_o   (crc_error),
        .region_locked_i(region_locked)
    );

    // ---- frame-bus target: column config RAM model ----
    column_cfg_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(8192)) u_ram (
        .clk   (clk),
        .we    (fbus_we),
        .re    (fbus_re),
        .addr  (fbus_addr),
        .wdata (fbus_wdata),
        .rdata (fbus_rdata)
    );

    // ---- "counter config" test pattern (8 non-trivial 32-bit words) ----
    localparam integer N = 8;
    logic [DATA_W-1:0] cfg [0:N-1];

    // ====================================================================
    // Tasks
    // ====================================================================
    // Issue a command (1-cycle cmd_valid pulse). Returns with the OCC already
    // in the requested operating state (set at the posedge between the two
    // negedges). For WRITE/BLANK/READBACK the FSM then self-runs.
    task occ_cmd(input logic [1:0] c, input logic [ADDR_W-1:0] a, input logic [15:0] n);
        begin
            @(negedge clk);
            cmd        = c;
            frame_addr = a;
            word_count = n;
            cmd_valid  = 1'b1;
            @(negedge clk);      // command accepted at the intervening posedge
            cmd_valid  = 1'b0;
        end
    endtask

    // Stream N words from cfg[] into the WRITE data path (1 word/cycle; WRITE
    // state asserts wdata_ready continuously while idx < word_count).
    task run_write(input logic [ADDR_W-1:0] a, input logic [15:0] n);
        integer k;
        begin
            occ_cmd(CMD_WRITE, a, n);
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk);
                wdata       = cfg[k];
                wdata_valid = 1'b1;
                @(negedge clk);   // accepted at the intervening posedge
                wdata_valid = 1'b0;
            end
        end
    endtask

    task run_readback(input logic [ADDR_W-1:0] a, input logic [15:0] n);
        begin
            occ_cmd(CMD_READBACK, a, n);
        end
    endtask

    task run_blank(input logic [ADDR_W-1:0] a, input logic [15:0] n);
        begin
            occ_cmd(CMD_BLANK, a, n);
        end
    endtask

    // Wait until status shows a terminal code (DONE or ERROR), with a guard.
    task wait_done;
        integer guard;
        begin
            guard = 0;
            while (!((status === S_DONE) || (status === S_ERROR)) && (guard < 1000)) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (guard >= 1000) begin
                $display("FAIL: timeout waiting for DONE/ERROR, status=%0d", status);
                errors = errors + 1;
            end
        end
    endtask

    // ====================================================================
    // Stimulus
    // ====================================================================
    initial begin
        // defaults
        rst_n         = 1'b0;
        cmd           = CMD_NOP;
        cmd_valid     = 1'b0;
        frame_addr    = '0;
        word_count    = '0;
        wdata         = '0;
        wdata_valid   = 1'b0;
        region_locked = 1'b0;

        // counter-config pattern
        cfg[0] = 32'h0000_0001;
        cfg[1] = 32'h0000_0002;
        cfg[2] = 32'h0000_0004;
        cfg[3] = 32'h0000_0008;
        cfg[4] = 32'h1234_5678;
        cfg[5] = 32'h9ABC_DEF0;
        cfg[6] = 32'h0F0F_0F0F;
        cfg[7] = 32'hFFFF_FFFF;

        // ---- reset ----
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // ================================================================
        $display("== check 5: NOP / idle ==");
        // ================================================================
        if (status !== S_IDLE) begin
            $display("FAIL: idle status=%0d (expected IDLE=0)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: idle status=IDLE");
        end

        // ================================================================
        $display("== check 1: WRITE then READBACK (clean) ==");
        // ================================================================
        run_write(16'h0100, N);
        wait_done;
        // READBACK same frame; expect DONE + crc_error=0
        run_readback(16'h0100, N);
        wait_done;
        if (status !== S_DONE) begin
            $display("FAIL: clean readback status=%0d (expected DONE=2)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: clean readback status=DONE");
        end
        if (crc_error !== 1'b0) begin
            $display("FAIL: clean readback crc_error=1 (expected 0)");
            errors = errors + 1;
        end else begin
            $display("PASS: clean readback CRC match (crc_error=0)");
        end

        // ================================================================
        $display("== check 2: CRC tamper detected ==");
        // ================================================================
        // backdoor-flip word 2 of the written frame (addr 0x0100+2 = 0x0102)
        u_ram.mem[16'h0102] = 32'hDEAD_BEEF;
        run_readback(16'h0100, N);
        // expect ERROR
        wait_done;
        if (status !== S_ERROR) begin
            $display("FAIL: tampered readback status=%0d (expected ERROR=3)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: tampered readback status=ERROR");
        end
        // crc_error_o is a STICKY register: it latches at the posedge that ends
        // the CMP cycle (the same edge where status returns to IDLE). status is
        // combinational (seen during CMP); the sticky bit needs one more cycle.
        @(negedge clk);
        if (crc_error !== 1'b1) begin
            $display("FAIL: tampered readback crc_error=0 (expected sticky 1)");
            errors = errors + 1;
        end else begin
            $display("PASS: tampered readback crc_error=1 (sticky)");
        end
        // restore for cleanliness
        u_ram.mem[16'h0102] = cfg[2];

        // ================================================================
        $display("== check 3: BLANK zeroes the frame ==");
        // ================================================================
        // first seed non-zero data at 0x1200 (region 1, CLEAN -- region 0 is dirty
        // from check 1 and would be rejected by blank-before-write, E0-FAB5).
        // This accepted WRITE also clears the sticky crc_error.
        run_write(16'h1200, N);
        wait_done;
        if (crc_error !== 1'b0) begin
            $display("FAIL: sticky crc_error not cleared by new WRITE");
            errors = errors + 1;
        end
        run_blank(16'h1200, N);
        wait_done;
        if (status !== S_DONE) begin
            $display("FAIL: blank status=%0d (expected DONE=2)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: blank status=DONE");
        end
        // verify all target RAM words are zero
        begin : blank_check
            integer k, nonzero;
            nonzero = 0;
            for (k = 0; k < N; k = k + 1) begin
                if (u_ram.mem[16'h1200 + k] !== 32'h0) nonzero = nonzero + 1;
            end
            if (nonzero !== 0) begin
                $display("FAIL: BLANK left %0d non-zero word(s) at 0x1200", nonzero);
                errors = errors + 1;
            end else begin
                $display("PASS: BLANK zeroed all 8 words");
            end
        end

        // ================================================================
        $display("== check 4: LOCK blocks WRITE ==");
        // ================================================================
        region_locked = 1'b1;
        @(negedge clk);
        @(negedge clk);
        begin : lock_check
            logic [DATA_W-1:0] snap;
            integer k;
            // snapshot the target frame (never written -> X; must stay X)
            snap = u_ram.mem[16'h0300];
            // issue WRITE while locked
            @(negedge clk);
            cmd        = CMD_WRITE;
            frame_addr = 16'h0300;
            word_count = N;
            cmd_valid  = 1'b1;
            #1;   // let combinational outputs settle
            if (status !== S_LOCKED) begin
                $display("FAIL: locked WRITE status=%0d (expected LOCKED=4)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: locked WRITE status=LOCKED");
            end
            if (cmd_ready !== 1'b0) begin
                $display("FAIL: locked WRITE cmd_ready=1 (expected 0, rejected)");
                errors = errors + 1;
            end else begin
                $display("PASS: locked WRITE cmd_ready=0 (rejected)");
            end
            @(negedge clk);
            cmd_valid = 1'b0;
            cmd       = CMD_NOP;
            // RAM must be untouched
            for (k = 0; k < N; k = k + 1) begin
                if (u_ram.mem[16'h0300 + k] !== snap) begin
                    $display("FAIL: locked WRITE modified RAM[0x%04x]", 16'h0300 + k);
                    errors = errors + 1;
                end
            end
            if (errors == 0) $display("PASS: locked WRITE left RAM unchanged");
        end
        @(negedge clk);
        region_locked = 1'b0;
        @(negedge clk);
        // sanity: status returns to IDLE after unlocking + NOP
        if (status !== S_IDLE) begin
            $display("FAIL: post-lock status=%0d (expected IDLE=0)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: post-lock status=IDLE");
        end

        // ================================================================
        // Summary
        // ================================================================
        $display("--------------------------------------------------");
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED (%0d errors)", errors);
        $finish;
    end

endmodule
