`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_hello (testbench, self-checking)
// Description: Integration TB for the Phase-1 BMC sim-path skeleton. Boots the
//              vendored NEORV32 (GHDL-converted `neorv32_verilog_wrapper`,
//              BOOT_MODE_SELECT=2 / IMEM-as-ROM) inside the ADR-016 `bmc_core`
//              wrapper and proves the real rv32 core runs an IMEM image and
//              prints over UART0.
//
//              Mechanism: a hand-crafted rv32 image (ethereal-tools/tools/
//              gen_bmc_hello.py) is $readmemh-preloaded into the IMEM ROM
//              (hierarchical backdoor into the generated netlist's ROM array,
//              overriding its default init). The program enables UART0
//              (PRSC=0, BAUD=0 -> one bit = CLK_DIV*2 clocks = 4 clk @ 10ns) and
//              stores "HI\n" to the TX DATA register. This TB decodes the 8N1
//              UART waveform on uart0_txd_o and asserts the received bytes match.
// Maintainer:  BaiTian6641
// Created:     2026-07-30
// Modified:    2026-07-30 - initial
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C05-BMC组件.md §1 (ADR-016 bmc_core)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              The backdoor path is stable while the vendored netlist is frozen;
//              regenerating the netlist renames the ROM array (see README.md).
`timescale 1ns/1ps

module tb_bmc_hello;

    // -- Timing (match the vendored core's UART serializer) ------------------
    localparam int CLK_PERIOD_NS = 10;         // 100 MHz skeleton clock
    // NEORV32 UART advances one bit per `uart_clk` tick; with PRSC=0 the tick is
    // clk/2 (clkgen en(0)) and the baud counter reloads 0 -> one bit = 2 clk.
    localparam int BIT_NS = 2 * CLK_PERIOD_NS; // 20 ns per bit

    // -- DUT signals ----------------------------------------------------------
    logic clk;
    logic rst_n;
    logic uart0_txd;
    logic uart0_rxd;

    // -- DUT: bmc_core (NEORV32 inside) --------------------------------------
    bmc_core dut (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .uart0_txd_o (uart0_txd),
        .uart0_rxd_i (uart0_rxd),
        .dbg_en_i    (1'b0),
        .bus_req_o   (),
        .heartbeat_o ()
    );

    // -- Clock ----------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) --------
    // Hierarchical path: bmc_core.u_core -> neorv32_top -> imem -> imem_rom ROM.
    localparam string IMAGE = "generated/bmc/bmc_hello.hex";
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n6830);
    end

    // -- UART 8N1 receive (idle-high, start bit low, LSB first) --------------
    localparam int MAXB = 16;
    bit [7:0] rxq   [0:MAXB-1];             // captured bytes (module-scope for iverilog)
    integer   rxn = 0;                      // number of bytes captured

    task automatic uart_recv_byte;
        integer i;
        logic [7:0] b;
        begin
            @(negedge uart0_txd);            // start bit (falling edge)
            #(BIT_NS / 2);                   // to centre of the start bit
            if (uart0_txd !== 1'b0) begin
                $display("TEST FAILED: glitch, no valid start bit");
                $finish;
            end
            b = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_NS);                   // advance one bit-time to data-bit i's centre
                b[i] = uart0_txd;            // LSB first
            end
            #(BIT_NS);                        // advance to the stop bit's centre
            if (uart0_txd !== 1'b1) begin
                $display("TEST FAILED: missing stop bit (byte=0x%02x)", b);
                $finish;
            end
            if (rxn < MAXB) begin
                rxq[rxn] = b;
                rxn = rxn + 1;
            end
            $display("[uart] rx byte 0x%02x (%s)", b,
                     (b >= 8'h20 && b < 8'h7f) ? "printable" : "ctrl");
        end
    endtask

    // -- Stimulus + check ------------------------------------------------------
    // Expected message (must match gen_bmc_hello.py --message).
    localparam int NEXP = 3;
    byte unsigned expected [0:NEXP-1] = '{8'h48, 8'h49, 8'h0a};  // 'H','I','\n'

    initial begin
        integer k;
        uart0_rxd = 1'b1;                    // idle RX line
        rst_n = 1'b0;                        // hold core in reset
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                        // release reset -> boot from IMEM ROM

        // Collect NEXP bytes (each recv task blocks until a full frame arrives).
        for (k = 0; k < NEXP; k = k + 1) uart_recv_byte();

        // Byte-compare against the expected message.
        if (rxn != NEXP) begin
            $display("TEST FAILED: got %0d bytes, expected %0d", rxn, NEXP);
            $finish;
        end
        for (k = 0; k < NEXP; k = k + 1) begin
            if (rxq[k] !== expected[k]) begin
                $display("TEST FAILED: byte %0d = 0x%02x, expected 0x%02x",
                         k, rxq[k], expected[k]);
                $finish;
            end
        end

        $display("TEST PASSED: bmc_core (NEORV32) booted IMEM image and printed \"HI\\n\" over UART0");
        $finish;
    end

    // -- Global watchdog --------------------------------------------------------
    initial begin
        #2_000_000;                          // 2 ms sim-time cap
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes)", rxn, NEXP);
        $finish;
    end

endmodule
`default_nettype wire
