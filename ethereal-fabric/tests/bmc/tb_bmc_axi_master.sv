`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_axi_master (testbench, self-checking)
// Description: End-to-end BMC -> AXI integration TB (ADR-018 BMC integration).
//              Boots the vendored NEORV32 (XBUS enabled) inside `bmc_core`, which
//              drives the in-house `eth_wb2axi` bridge (Wishbone -> AXI4 master)
//              into an `eth_axi_lite_slave` register window. The BMC firmware
//              (gen_bmc_hello.py --mode xbus) writes 0x5AA5C33C to the XBUS
//              window (0x40000000), reads it back, and prints "AX 5AA5C33C\n"
//              over UART0. This proves the BMC is a first-class AXI master on
//              the in-house eth_axi fabric.
//
//              Chain: NEORV32 --XBUS(Wishbone)--> eth_wb2axi --AXI4--> lite_slave
//              Address map: the slave window REG_BASE = 0x40000000 (word 0 at
//              0x40000000) matches the firmware's XBUS target address. (The xbar
//              / address decode is exercised separately in tb_axi_xbar; here we
//              connect the BMC directly to one slave for a focused datapath test.)
// Maintainer:  BaiTian6641
// Created:     2026-08-08
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §3; docs/adr/ADR-018 (BMC=AXI master)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              IMEM preload backdoor path matches tb_bmc_hello (ROM array n7280,
//              renamed n7280 -> n7280 on the 2026-09-02 SDI regen — update on any regen).
`timescale 1ns/1ps

module tb_bmc_axi_master;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;          // 100 MHz skeleton clock
    localparam int BIT_NS = 2 * CLK_PERIOD_NS;  // 20 ns/bit (PRSC=0, BAUD=0)

    // -- Address map ----------------------------------------------------------
    localparam logic [31:0] SLV_BASE = 32'h4000_0000;  // XBUS window = slave base
    localparam int          N_REGS   = 16;

    // -- DUT signals ----------------------------------------------------------
    logic clk;
    logic rst_n;
    logic uart0_txd;
    logic uart0_rxd;

    // BMC AXI master <-> slave channels
    logic        awvalid, awready;
    logic [31:0] awaddr;
    logic [2:0]  awprot;
    logic        wvalid, wready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        bvalid, bready;
    logic [1:0]  bresp;
    logic        arvalid, arready;
    logic [31:0] araddr;
    logic [2:0]  arprot;
    logic        rvalid, rready;
    logic [31:0] rdata;
    logic [1:0]  rresp;

    // slave register window
    logic [N_REGS*32-1:0] reg_rdata;
    logic                 reg_we;
    logic [N_REGS-1:0]    reg_waddr;
    logic [31:0]          reg_wdata;
    logic [3:0]           reg_wstrb;

    // -- DUT: bmc_core (NEORV32 + eth_wb2axi AXI master) ----------------------
    bmc_core dut (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .uart0_txd_o   (uart0_txd),
        .uart0_rxd_i   (uart0_rxd),
        .m_axi_awvalid (awvalid),
        .m_axi_awready (awready),
        .m_axi_awaddr  (awaddr),
        .m_axi_awprot  (awprot),
        .m_axi_wvalid  (wvalid),
        .m_axi_wready  (wready),
        .m_axi_wdata   (wdata),
        .m_axi_wstrb   (wstrb),
        .m_axi_bvalid  (bvalid),
        .m_axi_bready  (bready),
        .m_axi_bresp   (bresp),
        .m_axi_arvalid (arvalid),
        .m_axi_arready (arready),
        .m_axi_araddr  (araddr),
        .m_axi_arprot  (arprot),
        .m_axi_rvalid  (rvalid),
        .m_axi_rready  (rready),
        .m_axi_rdata   (rdata),
        .m_axi_rresp   (rresp),
        .dbg_en_i      (1'b0),
        // SDI tied off (CS high = idle): this TB drives no EFP-SPI traffic.
        .sdi_clk_i     (1'b0),
        .sdi_csn_i     (1'b1),
        .sdi_dat_i     (1'b1),
        .sdi_dat_o     (),
        .heartbeat_o   ()
    );

    // -- AXI4-Lite slave (the BMC's target register window) -------------------
    eth_axi_lite_slave #(
        .AXI_AW(32), .AXI_DW(32), .N_REGS(N_REGS), .REG_BASE(SLV_BASE)
    ) u_slave (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
        .s_axi_wvalid(wvalid),   .s_axi_wready(wready),   .s_axi_wdata(wdata),   .s_axi_wstrb(wstrb),
        .s_axi_bvalid(bvalid),   .s_axi_bready(bready),   .s_axi_bresp(bresp),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_araddr(araddr), .s_axi_arprot(arprot),
        .s_axi_rvalid(rvalid),   .s_axi_rready(rready),   .s_axi_rdata(rdata),   .s_axi_rresp(rresp),
        .reg_rdata_o(reg_rdata), .reg_we_o(reg_we), .reg_waddr_o(reg_waddr),
        .reg_wdata_o(reg_wdata), .reg_wstrb_o(reg_wstrb), .reg_rdata_i(reg_rdata)
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) ----------
    localparam string IMAGE = "generated/bmc/bmc_axi.hex";
    // Path matches tb_bmc_hello; ROM array renamed n6830 -> n7280 (2026-08-08 XBUS regen) -> n7280 (2026-09-02 SDI regen).
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n7280);
    end

    // -- Observe the AXI write landing in the slave window ---------------------
    logic saw_write;
    initial saw_write = 1'b0;
    always @(posedge clk) begin
        if (reg_we && reg_waddr[0])
            saw_write <= 1'b1;   // word 0 (0x40000000) written
    end

    // -- UART 8N1 receive -------------------------------------------------------
    localparam int MAXB = 32;
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
            $display("[uart] rx byte 0x%02x (%s)", b,
                     (b >= 8'h20 && b < 8'h7f) ? "printable" : "ctrl");
        end
    endtask

    // -- Stimulus + check -------------------------------------------------------
    // Expected message: "AX 5AA5C33C\n" = A,X,space,5,A,A,5,C,3,3,C,\n (12 bytes).
    localparam int NEXP = 12;
    byte unsigned expected [0:NEXP-1] = '{
        8'h41, 8'h58, 8'h20,                          // 'A','X',' '
        8'h35, 8'h41, 8'h41, 8'h35,                   // '5','A','A','5'
        8'h43, 8'h33, 8'h33, 8'h43,                   // 'C','3','3','C'
        8'h0a                                          // '\n'
    };

    initial begin
        integer k;
        uart0_rxd = 1'b1;
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                 // boot from IMEM ROM

        for (k = 0; k < NEXP; k = k + 1) uart_recv_byte();

        // 1. the AXI write actually landed in the slave register window
        if (!saw_write) begin
            $display("TEST FAILED: no AXI write observed in the slave window");
            $finish;
        end

        // 2. the UART message matches "AX 5AA5C33C\n" (the readback value)
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

        $display("TEST PASSED: BMC booted, drove AXI write+read via XBUS/eth_wb2axi, printed \"AX 5AA5C33C\\n\"");
        $finish;
    end

    // -- Global watchdog ----------------------------------------------------------
    initial begin
        #4_000_000;                 // 4 ms cap (XBUS write+read+12 chars)
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes, saw_write=%0b)",
                 rxn, NEXP, saw_write);
        $finish;
    end

endmodule
`default_nettype wire
