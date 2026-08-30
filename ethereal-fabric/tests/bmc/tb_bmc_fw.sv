`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_fw (testbench, self-checking)
// Description: E1-BMC2 checkpoint TB — the REAL C firmware framework
//              (bmc-fw: crt0 boot + .data copy + .bss clear + lifecycle FSM
//              skeleton + UART driver) boots on the vendored NEORV32 inside
//              bmc_core and prints its banner over UART0. This is the first
//              C (not hand-assembled) firmware on the BMC — proving the
//              riscv64-unknown-elf bare-metal flow + link.ld ROM/DMEM map +
//              crt0 startup all work against the real core.
//
//              main.c prints (exact):
//                "bmc-fw v0 skeleton boot OK\n"
//                "EMRI MAGIC=0x45544852 lifecycle: LRS done state=00000000\n"
//                "bmc-fw v0 idle spin\n"
//              The TB exact-matches the full byte stream.
//
//              No XBUS/AXI access in this firmware (only UART0) — the AXI
//              master pins are tied benign (matches tb_bmc_hello).
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§3 (E1-BMC2)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              IMEM preload backdoor path matches tb_bmc_hello (ROM array
//              n6964, renamed on the 2026-08-08 XBUS regen — update on regen).
//              UART bit time = 2 clk (NEORV32 reset defaults PRSC=0/BAUD=0).
`timescale 1ns/1ps

module tb_bmc_fw;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;          // 100 MHz skeleton clock
    localparam int BIT_NS = 2 * CLK_PERIOD_NS;  // 20 ns/bit (PRSC=0, BAUD=0)

    logic clk;
    logic rst_n;

    // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) ---------------------------
    logic        uart0_txd;
    logic        uart0_rxd;

    bmc_core dut (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .uart0_txd_o   (uart0_txd),
        .uart0_rxd_i   (uart0_rxd),
        // AXI master idle (this firmware only touches UART0, no XBUS)
        .m_axi_awvalid (),
        .m_axi_awready (1'b0),
        .m_axi_awaddr  (),
        .m_axi_awprot  (),
        .m_axi_wvalid  (),
        .m_axi_wready  (1'b0),
        .m_axi_wdata   (),
        .m_axi_wstrb   (),
        .m_axi_bvalid  (1'b0),
        .m_axi_bready  (),
        .m_axi_bresp   (2'b00),
        .m_axi_arvalid (),
        .m_axi_arready (1'b0),
        .m_axi_araddr  (),
        .m_axi_arprot  (),
        .m_axi_rvalid  (1'b0),
        .m_axi_rready  (),
        .m_axi_rdata   (32'h0),
        .m_axi_rresp   (2'b00),
        .dbg_en_i      (1'b0),
        .heartbeat_o   ()
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) -----------
    localparam string IMAGE = "generated/bmc/bmc_fw.hex";
    // Path matches tb_bmc_hello; ROM array renamed n6830 -> n6964 on XBUS regen.
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n6964);
    end

    // -- UART 8N1 receive (idle-high, start bit low, LSB first) -----------------
    localparam int MAXB = 160;
    bit [7:0] rxq [0:MAXB-1];
    integer   rxn = 0;

    task automatic uart_recv_byte;
        integer i;
        logic [7:0] b;
        begin
            @(negedge uart0_txd);
            #(BIT_NS / 2);
            if (uart0_txd !== 1'b0) begin
                $display("TEST FAILED: glitch, no valid start bit");
                $finish;
            end
            b = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_NS);
                b[i] = uart0_txd;
            end
            #(BIT_NS);
            if (uart0_txd !== 1'b1) begin
                $display("TEST FAILED: missing stop bit (byte=0x%02x)", b);
                $finish;
            end
            if (rxn < MAXB) begin
                rxq[rxn] = b;
                rxn = rxn + 1;
            end
        end
    endtask

    // -- Stimulus + check ---------------------------------------------------------
    // Expected: "bmc-fw v0 skeleton boot OK\nEMRI MAGIC=0x45544852 lifecycle:
    // LRS done state=00000000\nbmc-fw v0 idle spin\n" (104 bytes). iverilog has
    // limited `string` method support, so the expected bytes are a byte array
    // (generated from the message; matches main.c exactly).
    localparam int NEXP = 104;
    byte unsigned expected [0:NEXP-1] = '{
        8'h62, 8'h6d, 8'h63, 8'h2d, 8'h66, 8'h77, 8'h20, 8'h76,
        8'h30, 8'h20, 8'h73, 8'h6b, 8'h65, 8'h6c, 8'h65, 8'h74,
        8'h6f, 8'h6e, 8'h20, 8'h62, 8'h6f, 8'h6f, 8'h74, 8'h20,
        8'h4f, 8'h4b, 8'h0a, 8'h45, 8'h4d, 8'h52, 8'h49, 8'h20,
        8'h4d, 8'h41, 8'h47, 8'h49, 8'h43, 8'h3d, 8'h30, 8'h78,
        8'h34, 8'h35, 8'h35, 8'h34, 8'h34, 8'h38, 8'h35, 8'h32,
        8'h20, 8'h6c, 8'h69, 8'h66, 8'h65, 8'h63, 8'h79, 8'h63,
        8'h6c, 8'h65, 8'h3a, 8'h20, 8'h4c, 8'h52, 8'h53, 8'h20,
        8'h64, 8'h6f, 8'h6e, 8'h65, 8'h20, 8'h73, 8'h74, 8'h61,
        8'h74, 8'h65, 8'h3d, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30,
        8'h30, 8'h30, 8'h30, 8'h0a, 8'h62, 8'h6d, 8'h63, 8'h2d,
        8'h66, 8'h77, 8'h20, 8'h76, 8'h30, 8'h20, 8'h69, 8'h64,
        8'h6c, 8'h65, 8'h20, 8'h73, 8'h70, 8'h69, 8'h6e, 8'h0a
    };

    integer errors = 0;

    initial begin
        integer k;
        integer c;
        uart0_rxd = 1'b1;
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                 // boot from IMEM ROM
        for (k = 0; k < NEXP; k = k + 1)
            uart_recv_byte();
        repeat (10) @(posedge clk);

        if (rxn != NEXP) begin
            $display("TEST FAILED: got %0d bytes, expected %0d", rxn, NEXP);
            errors++;
        end else begin
            for (k = 0; k < NEXP; k = k + 1) begin
                if (rxq[k] !== expected[k]) begin
                    $display("TEST FAILED: byte %0d = 0x%02x, expected 0x%02x",
                             k, rxq[k], expected[k]);
                    errors++;
                end
            end
        end

        if (errors == 0) begin
            $display("TEST PASSED: C bmc-fw framework booted on NEORV32, lifecycle skeleton ran, printed full banner");
        end
        $finish;
    end

    // -- Watchdog ------------------------------------------------------------------
    initial begin
        #120000000;  // 120 ms (ample; boot + ~90 UART bytes @ 20ns/bit + CPU)
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes)", rxn, NEXP);
        $finish;
    end

endmodule
`default_nettype wire
