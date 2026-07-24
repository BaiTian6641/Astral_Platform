`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// Module:      tb_blank
// Description: Self-checking SV testbench for occ_top blank-before-write enforcement (E0-FAB5).
// Details:     Validates the per-region dirty-bit / S_NEEDS_BLANK mechanism added in
//              E0-FAB5 (C03 sec3):
//                1. First WRITE to a clean region is accepted (DONE).
//                2. Re-WRITE to a now-dirty region is REJECTED: status=NEEDS_BLANK(5),
//                   cmd_ready never pulses, target RAM unchanged.
//                3. BLANK cleans the region (DONE, RAM zeroed, dirty cleared).
//                4. WRITE works again after BLANK (no longer NEEDS_BLANK).
//                5. Region isolation: writing region 0 does not touch region 1 storage;
//                   region 0 being dirty does NOT block a clean region 1 WRITE.
//                6. LOCK still blocks WRITE (priority over the dirty check).
//              Frame-bus target = column_cfg_ram DEPTH=8192 (regions 0..1 in range).
//              Run: iverilog -g2012 -o /tmp/tb_blank tb_blank.sv column_cfg_ram.sv \
//                              ../../rtl/occ/occ_top.sv && vvp /tmp/tb_blank
// Maintainer:  BaiTian6641
// Created:     2026-07-24
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C03-OCC组件.md §3 / task E0-FAB5
// Notes:       Self-checking: maintains `errors`, prints TEST PASSED / TEST FAILED.
//              Drives inputs at negedge, samples combinational outputs after a #1
//              settle. iverilog -g2012 compatible (no SV-2017-only constructs).
//              Region id = frame_addr[ADDR_W-1 -: 4]; for ADDR_W=16 that is
//              frame_addr[15:12], so 0x0100->region 0, 0x1100->region 1.
module tb_blank;
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
    localparam logic [2:0] S_IDLE        = 3'd0;
    localparam logic [2:0] S_BUSY        = 3'd1;
    localparam logic [2:0] S_DONE        = 3'd2;
    localparam logic [2:0] S_ERROR       = 3'd3;
    localparam logic [2:0] S_LOCKED      = 3'd4;
    localparam logic [2:0] S_NEEDS_BLANK = 3'd5;   // E0-FAB5
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
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .cmd_i          (cmd),
        .cmd_valid_i    (cmd_valid),
        .cmd_ready_o    (cmd_ready),
        .frame_addr_i   (frame_addr),
        .word_count_i   (word_count),
        .wdata_i        (wdata),
        .wdata_valid_i  (wdata_valid),
        .wdata_ready_o  (wdata_ready),
        .fbus_addr_o    (fbus_addr),
        .fbus_wdata_o   (fbus_wdata),
        .fbus_we_o      (fbus_we),
        .fbus_re_o      (fbus_re),
        .fbus_rdata_i   (fbus_rdata),
        .status_o       (status),
        .crc_error_o    (crc_error),
        .region_locked_i(region_locked)
    );

    // ---- frame-bus target: column config RAM model ----
    // DEPTH=8192 -> 0x0000..0x1FFF (regions 0 & 1 in range; avoids the
    // 4096-deep out-of-bounds gotcha for 0x1xxx addresses).
    column_cfg_ram #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .DEPTH(8192)) u_ram (
        .clk   (clk),
        .we    (fbus_we),
        .re    (fbus_re),
        .addr  (fbus_addr),
        .wdata (fbus_wdata),
        .rdata (fbus_rdata)
    );

    // ---- 8-word "counter config" test pattern ----
    localparam integer N = 8;
    logic [DATA_W-1:0] cfg [0:N-1];

    // ====================================================================
    // Tasks (mirror tb_occ style)
    // ====================================================================
    // Issue a command (1-cycle cmd_valid pulse). For accepted WRITE/BLANK/
    // READBACK the FSM then self-runs from the requested operating state.
    task occ_cmd(input logic [1:0] c, input logic [ADDR_W-1:0] a, input logic [15:0] n);
        begin
            @(negedge clk);
            cmd        = c;
            frame_addr = a;
            word_count = n;
            cmd_valid  = 1'b1;
            @(negedge clk);      // accepted at the intervening posedge
            cmd_valid  = 1'b0;
        end
    endtask

    // Stream N words from cfg[] into the WRITE data path (1 word/cycle).
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
        $display("== check 1: first WRITE to clean region 0 -> DONE ==");
        // ================================================================
        run_write(16'h0100, N);
        wait_done;
        if (status !== S_DONE) begin
            $display("FAIL: first WRITE status=%0d (expected DONE=2)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: first WRITE region 0 status=DONE");
        end
        begin : c1_ram
            integer k, bad;
            bad = 0;
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h0100 + k] !== cfg[k]) bad = bad + 1;
            if (bad !== 0) begin
                $display("FAIL: first WRITE RAM mismatch (%0d words)", bad);
                errors = errors + 1;
            end else begin
                $display("PASS: first WRITE RAM[0x0100..0x0107] = cfg pattern");
            end
        end

        // ================================================================
        $display("== check 2: re-WRITE dirty region 0 -> NEEDS_BLANK, RAM unchanged ==");
        // ================================================================
        begin : c2
            logic [DATA_W-1:0] snap [0:N-1];
            integer k;
            for (k = 0; k < N; k = k + 1) snap[k] = u_ram.mem[16'h0100 + k];
            // issue WRITE to the now-dirty region 0; expect rejection
            @(negedge clk);
            cmd        = CMD_WRITE;
            frame_addr = 16'h0100;
            word_count = N;
            cmd_valid  = 1'b1;
            #1;   // pre-posedge combinational sample (IDLE evaluates the reject)
            if (status !== S_NEEDS_BLANK) begin
                $display("FAIL: dirty re-WRITE status=%0d (expected NEEDS_BLANK=5)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: dirty re-WRITE status=NEEDS_BLANK (pre-posedge)");
            end
            if (cmd_ready !== 1'b0) begin
                $display("FAIL: dirty re-WRITE cmd_ready=1 (expected 0, rejected)");
                errors = errors + 1;
            end else begin
                $display("PASS: dirty re-WRITE cmd_ready=0 (no accept pulse)");
            end
            @(posedge clk);   // the edge where acceptance would occur
            #1;   // post-posedge: state must STILL be IDLE (no transition)
            if (status !== S_NEEDS_BLANK) begin
                $display("FAIL: dirty re-WRITE post-posedge status=%0d (expected NEEDS_BLANK=5, not accepted)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: dirty re-WRITE still NEEDS_BLANK post-posedge (not accepted)");
            end
            @(negedge clk);
            cmd_valid = 1'b0;
            cmd       = CMD_NOP;
            #1;
            if (status !== S_IDLE) begin
                $display("FAIL: post-reject status=%0d (expected IDLE=0)", status);
                errors = errors + 1;
            end
            // RAM must be unchanged (still the check-1 WRITE data)
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h0100 + k] !== snap[k]) begin
                    $display("FAIL: dirty reject clobbered RAM[0x%h] (got %h, exp %h)",
                             16'h0100 + k, u_ram.mem[16'h0100 + k], snap[k]);
                    errors = errors + 1;
                end
            if (errors == 0) $display("PASS: dirty re-WRITE left RAM[0x0100..0x0107] unchanged");
        end

        // ================================================================
        $display("== check 3: BLANK cleans region 0 (DONE, RAM zeroed) ==");
        // ================================================================
        run_blank(16'h0100, N);
        wait_done;
        if (status !== S_DONE) begin
            $display("FAIL: blank status=%0d (expected DONE=2)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: BLANK region 0 status=DONE");
        end
        begin : c3_ram
            integer k, nonzero;
            nonzero = 0;
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h0100 + k] !== 32'h0) nonzero = nonzero + 1;
            if (nonzero !== 0) begin
                $display("FAIL: BLANK left %0d non-zero word(s) at 0x0100", nonzero);
                errors = errors + 1;
            end else begin
                $display("PASS: BLANK zeroed RAM[0x0100..0x0107]");
            end
        end

        // ================================================================
        $display("== check 4: WRITE works again after BLANK (no NEEDS_BLANK) ==");
        // ================================================================
        run_write(16'h0100, N);
        wait_done;
        if (status !== S_DONE) begin
            $display("FAIL: post-blank WRITE status=%0d (expected DONE=2)", status);
            errors = errors + 1;
        end else begin
            $display("PASS: post-blank WRITE region 0 status=DONE");
        end
        begin : c4_ram
            integer k, bad;
            bad = 0;
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h0100 + k] !== cfg[k]) bad = bad + 1;
            if (bad !== 0) begin
                $display("FAIL: post-blank WRITE RAM mismatch (%0d words)", bad);
                errors = errors + 1;
            end else begin
                $display("PASS: post-blank WRITE RAM = cfg pattern");
            end
        end

        // ================================================================
        $display("== check 5: region isolation (R0 write does not touch R1) ==");
        // ================================================================
        // region 0 is dirty from check 4 -> BLANK it first so we can re-WRITE it.
        run_blank(16'h0100, N);
        wait_done;
        begin : c5
            logic [DATA_W-1:0] snap1 [0:N-1];
            integer k, changed, bad;
            // snapshot region 1 storage (0x1100..0x1107) BEFORE writing region 0.
            // It is X (never written by the OCC). `!==` treats X===X as equal, so
            // any corruption (X->0/1) introduced by the region-0 write is caught.
            for (k = 0; k < N; k = k + 1) snap1[k] = u_ram.mem[16'h1100 + k];
            // WRITE region 0 with the known cfg pattern
            run_write(16'h0100, N);
            wait_done;
            if (status !== S_DONE) begin
                $display("FAIL: isolation WRITE region 0 status=%0d (expected DONE=2)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: isolation WRITE region 0 status=DONE");
            end
            // region 1 must be UNCHANGED
            changed = 0;
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h1100 + k] !== snap1[k]) changed = changed + 1;
            if (changed !== 0) begin
                $display("FAIL: region 0 WRITE disturbed region 1 (%0d words changed)", changed);
                errors = errors + 1;
            end else begin
                $display("PASS: region 1 RAM UNCHANGED while writing region 0 (isolated)");
            end
            // WRITE region 1 (clean region): region 0 being dirty must NOT block it
            run_write(16'h1100, N);
            wait_done;
            if (status !== S_DONE) begin
                $display("FAIL: region 1 WRITE status=%0d (expected DONE=2; region 0 dirty must not block)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: region 1 WRITE status=DONE (region 0 dirty did not block)");
            end
            // region 1 now holds cfg
            bad = 0;
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h1100 + k] !== cfg[k]) bad = bad + 1;
            if (bad !== 0) begin
                $display("FAIL: region 1 WRITE RAM mismatch (%0d words)", bad);
                errors = errors + 1;
            end else begin
                $display("PASS: region 1 RAM = cfg pattern");
            end
        end

        // ================================================================
        $display("== check 6: LOCK still blocks WRITE (priority over dirty) ==");
        // ================================================================
        // region 0 is dirty (from check 5). Lock must take priority -> LOCKED,
        // NOT NEEDS_BLANK.
        region_locked = 1'b1;
        @(negedge clk);
        @(negedge clk);
        begin : c6
            logic [DATA_W-1:0] snap0 [0:N-1];
            integer k;
            for (k = 0; k < N; k = k + 1) snap0[k] = u_ram.mem[16'h0100 + k];
            @(negedge clk);
            cmd        = CMD_WRITE;
            frame_addr = 16'h0100;
            word_count = N;
            cmd_valid  = 1'b1;
            #1;   // pre-posedge combo sample
            if (status !== S_LOCKED) begin
                $display("FAIL: locked WRITE status=%0d (expected LOCKED=4; lock must dominate dirty)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: locked WRITE status=LOCKED (priority over dirty)");
            end
            if (cmd_ready !== 1'b0) begin
                $display("FAIL: locked WRITE cmd_ready=1 (expected 0, rejected)");
                errors = errors + 1;
            end else begin
                $display("PASS: locked WRITE cmd_ready=0 (rejected)");
            end
            @(posedge clk);
            #1;
            if (status !== S_LOCKED) begin
                $display("FAIL: locked WRITE post-posedge status=%0d (expected LOCKED=4)", status);
                errors = errors + 1;
            end else begin
                $display("PASS: locked WRITE still LOCKED post-posedge (not accepted)");
            end
            @(negedge clk);
            cmd_valid = 1'b0;
            cmd       = CMD_NOP;
            // RAM must be untouched
            for (k = 0; k < N; k = k + 1)
                if (u_ram.mem[16'h0100 + k] !== snap0[k]) begin
                    $display("FAIL: locked WRITE modified RAM[0x%h]", 16'h0100 + k);
                    errors = errors + 1;
                end
            if (errors == 0) $display("PASS: locked WRITE left RAM unchanged");
        end
        @(negedge clk);
        region_locked = 1'b0;
        @(negedge clk);
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
