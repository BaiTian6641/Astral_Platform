`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_axi_xbar (testbench, self-checking)
// Description: End-to-end BMC -> AXI CROSSBAR integration TB (ADR-018 BMC
//              integration, follow-up of tb_bmc_axi_master). Boots the
//              vendored NEORV32 (XBUS enabled) inside `bmc_core`, drives the
//              in-house `eth_wb2axi` bridge into `eth_axi_xbar` (1 master x
//              2 slaves), which routes by address decode to TWO
//              `eth_axi_lite_slave` register windows:
//                window0 @ 0x4000_0000 (slave0), window1 @ 0x4000_1000 (slave1)
//              The firmware (gen_bmc_hello.py --mode xbar) writes 0x5AA5C33C
//              to window0 and 0xC33C5AA5 to window1, reads both back, and
//              prints "XB 5AA5C33C C33C5AA5\n" over UART0. Correct readbacks
//              prove end-to-end routing (a decode/misroute fault mismatches).
//
//              Chain: NEORV32 --XBUS(Wishbone)--> eth_wb2axi --AXI4-->
//                     eth_axi_xbar --decode--> lite_slave0 / lite_slave1
//              Master-side IDs are tied 0 (bmc_core drives no AXI IDs; the
//              xbar prepends the master index internally). Slave-side ID pins:
//              eth_axi_lite_slave is ID-less (AXI4-Lite), so xbar m_awid/m_arid
//              are left open and m_bid/m_rid are tied 0 — route-back uses the
//              xbar's RECORDED OWNER, not the returned ID (xbar §5.1), and the
//              stripped bid/rid (=0) is not consumed by the ID-less bridge.
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/eth-axi-v0.md §5 (xbar);
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md (BMC=AXI master)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              IMEM preload backdoor path matches tb_bmc_hello (ROM array
//              n7280, renamed n7280 -> n7280 on the 2026-09-02 SDI regen).
`timescale 1ns/1ps

module tb_bmc_axi_xbar;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;          // 100 MHz skeleton clock
    // NEORV32 UART0 at reset defaults (PRSC=0, BAUD=0): clk/2 clock enable and
    // baud reload 0 -> one bit = 2 clk = 20 ns (matches tb_bmc_hello/axi_master).
    localparam int BIT_NS = 2 * CLK_PERIOD_NS;  // 20 ns/bit

    logic clk;
    logic rst_n;

    // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) ---------------------------
    logic        uart0_txd;
    logic        uart0_rxd;

    // BMC AXI master channels (drive the xbar master port 0)
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

    // -- eth_axi_xbar: 1 master x 2 slaves + decode-error slave ----------------
    localparam int N_MST = 1, N_SLV = 2, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 1;
    localparam int XIDW = AXI_IDW + 1;      // N_MST=1 -> MIW=1 per xbar formula
    localparam int N_REGS = 16;

    // flat ADDR_MAP: base_s at [s*AW +: AW], mask_s at [(N_SLV+s)*AW +: AW]
    // 4 KiB windows: slave0 0x4000_0000, slave1 0x4000_1000
    localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {
        32'hFFFF_F000,                      // mask1  @[96+:32]
        32'hFFFF_F000,                      // mask0  @[64+:32]
        32'h4000_1000,                      // base1  @[32+:32]
        32'h4000_0000                       // base0  @[ 0+:32]
    };

    // slave-side flattened buses (xbar -> 2 lite slaves)
    logic [N_SLV-1:0]            m_awvalid, m_awready;
    logic [N_SLV*AXI_AW-1:0]     m_awaddr;
    logic [N_SLV*XIDW-1:0]       m_awid;
    logic [N_SLV-1:0]            m_wvalid, m_wready;
    logic [N_SLV*AXI_DW-1:0]     m_wdata;
    logic [N_SLV*(AXI_DW/8)-1:0] m_wstrb;
    logic [N_SLV-1:0]            m_bvalid, m_bready;
    logic [N_SLV*2-1:0]          m_bresp;
    logic [N_SLV-1:0]            m_arvalid, m_arready;
    logic [N_SLV*AXI_AW-1:0]     m_araddr;
    logic [N_SLV*XIDW-1:0]       m_arid;
    logic [N_SLV-1:0]            m_rvalid, m_rready;
    logic [N_SLV*AXI_DW-1:0]     m_rdata;
    logic [N_SLV*2-1:0]          m_rresp;

    eth_axi_xbar #(
        .N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
        .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .ADDR_MAP(ADDR_MAP)
    ) u_xbar (
        .clk_i(clk), .rst_ni(rst_n),
        // master port 0 <- bmc_core (no IDs on the bridge: tie 0, leave open).
        // N_MST=1 => the s_* buses are 1-bit/1-word vectors -> connect directly.
        .s_awvalid(awvalid), .s_awready(awready), .s_awaddr(awaddr), .s_awid(1'b0),
        .s_wvalid(wvalid),   .s_wready(wready),   .s_wdata(wdata),   .s_wstrb(wstrb),
        .s_bvalid(bvalid),   .s_bready(bready),   .s_bid(),          .s_bresp(bresp),
        .s_arvalid(arvalid), .s_arready(arready), .s_araddr(araddr), .s_arid(1'b0),
        .s_rvalid(rvalid),   .s_rready(rready),   .s_rid(),          .s_rdata(rdata),
        .s_rresp(rresp),
        // slave ports
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
        .m_wvalid(m_wvalid),   .m_wready(m_wready),   .m_wdata(m_wdata),   .m_wstrb(m_wstrb),
        .m_bvalid(m_bvalid),   .m_bready(m_bready),   .m_bid({N_SLV*XIDW{1'b0}}), .m_bresp(m_bresp),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
        .m_rvalid(m_rvalid),   .m_rready(m_rready),   .m_rid({N_SLV*XIDW{1'b0}}), .m_rdata(m_rdata),
        .m_rresp(m_rresp)
    );

    // -- Two AXI4-Lite slave windows -------------------------------------------
    logic [N_REGS*32-1:0] reg_rdata0, reg_rdata1;
    logic                 reg_we0, reg_we1;
    logic [N_REGS-1:0]    reg_waddr0, reg_waddr1;
    logic [31:0]          reg_wdata0, reg_wdata1;
    logic [3:0]           reg_wstrb0, reg_wstrb1;

    eth_axi_lite_slave #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .N_REGS(N_REGS), .REG_BASE(32'h4000_0000)
    ) u_slave0 (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(m_awvalid[0]), .s_axi_awready(m_awready[0]),
        .s_axi_awaddr(m_awaddr[0*AXI_AW +: AXI_AW]), .s_axi_awprot(3'b000),
        .s_axi_wvalid(m_wvalid[0]), .s_axi_wready(m_wready[0]),
        .s_axi_wdata(m_wdata[0*AXI_DW +: AXI_DW]), .s_axi_wstrb(m_wstrb[0*4 +: 4]),
        .s_axi_bvalid(m_bvalid[0]), .s_axi_bready(m_bready[0]),
        .s_axi_bresp(m_bresp[0*2 +: 2]),
        .s_axi_arvalid(m_arvalid[0]), .s_axi_arready(m_arready[0]),
        .s_axi_araddr(m_araddr[0*AXI_AW +: AXI_AW]), .s_axi_arprot(3'b000),
        .s_axi_rvalid(m_rvalid[0]), .s_axi_rready(m_rready[0]),
        .s_axi_rdata(m_rdata[0*AXI_DW +: AXI_DW]), .s_axi_rresp(m_rresp[0*2 +: 2]),
        .reg_rdata_o(reg_rdata0), .reg_we_o(reg_we0), .reg_waddr_o(reg_waddr0),
        .reg_wdata_o(reg_wdata0), .reg_wstrb_o(reg_wstrb0), .reg_rdata_i(reg_rdata0)
    );

    eth_axi_lite_slave #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .N_REGS(N_REGS), .REG_BASE(32'h4000_1000)
    ) u_slave1 (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(m_awvalid[1]), .s_axi_awready(m_awready[1]),
        .s_axi_awaddr(m_awaddr[1*AXI_AW +: AXI_AW]), .s_axi_awprot(3'b000),
        .s_axi_wvalid(m_wvalid[1]), .s_axi_wready(m_wready[1]),
        .s_axi_wdata(m_wdata[1*AXI_DW +: AXI_DW]), .s_axi_wstrb(m_wstrb[1*4 +: 4]),
        .s_axi_bvalid(m_bvalid[1]), .s_axi_bready(m_bready[1]),
        .s_axi_bresp(m_bresp[1*2 +: 2]),
        .s_axi_arvalid(m_arvalid[1]), .s_axi_arready(m_arready[1]),
        .s_axi_araddr(m_araddr[1*AXI_AW +: AXI_AW]), .s_axi_arprot(3'b000),
        .s_axi_rvalid(m_rvalid[1]), .s_axi_rready(m_rready[1]),
        .s_axi_rdata(m_rdata[1*AXI_DW +: AXI_DW]), .s_axi_rresp(m_rresp[1*2 +: 2]),
        .reg_rdata_o(reg_rdata1), .reg_we_o(reg_we1), .reg_waddr_o(reg_waddr1),
        .reg_wdata_o(reg_wdata1), .reg_wstrb_o(reg_wstrb1), .reg_rdata_i(reg_rdata1)
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) -----------
    localparam string IMAGE = "generated/bmc/bmc_xbar.hex";
    // Path matches tb_bmc_hello; ROM array renamed n6830 -> n7280 (2026-08-08 XBUS regen) -> n7280 (2026-09-02 SDI regen).
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n7280);
    end

    // -- Observe each write landing in the CORRECT slave window ----------------
    // reg_waddr_o is ONE-HOT (1 << word_index): bit0 set == word 0 written.
    logic saw_write0, saw_write1;
    initial begin
        saw_write0 = 1'b0;
        saw_write1 = 1'b0;
    end
    always @(posedge clk) begin
        if (reg_we0 && reg_waddr0[0]) saw_write0 <= 1'b1;
        if (reg_we1 && reg_waddr1[0]) saw_write1 <= 1'b1;
    end

    // -- UART 8N1 receive (idle-high, start bit low, LSB first) -----------------
    localparam int MAXB = 40;
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
    // Expected message: "XB 5AA5C33C C33C5AA5\n" (21 bytes).
    localparam int NEXP = 21;
    byte unsigned expected [0:NEXP-1] = '{
        8'h58, 8'h42, 8'h20,                                      // 'X','B',' '
        8'h35, 8'h41, 8'h41, 8'h35, 8'h43, 8'h33, 8'h33, 8'h43,   // "5AA5C33C"
        8'h20,                                                    // ' '
        8'h43, 8'h33, 8'h33, 8'h43, 8'h35, 8'h41, 8'h41, 8'h35,   // "C33C5AA5"
        8'h0a                                                     // '\n'
    };

    initial begin
        integer k;
        uart0_rxd = 1'b1;
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                 // boot from IMEM ROM
        for (k = 0; k < NEXP; k = k + 1)
            uart_recv_byte();
        repeat (10) @(posedge clk);

        // 1. both writes landed in their own slave windows
        if (!saw_write0)
            $display("TEST FAILED: no AXI write observed in slave0 window (0x40000000)");
        if (!saw_write1)
            $display("TEST FAILED: no AXI write observed in slave1 window (0x40001000)");
        // 2. the UART message matches "XB 5AA5C33C C33C5AA5\n" (readbacks)
        if (rxn != NEXP) begin
            $display("TEST FAILED: got %0d bytes, expected %0d", rxn, NEXP);
        end else begin
            for (k = 0; k < NEXP; k = k + 1)
                if (rxq[k] !== expected[k])
                    $display("TEST FAILED: byte %0d = 0x%02x, expected 0x%02x",
                             k, rxq[k], expected[k]);
        end
        if (saw_write0 && saw_write1 && rxn == NEXP) begin
            $display("TEST PASSED: BMC drove xbar-routed writes to 2 slaves + readbacks, printed \"XB 5AA5C33C C33C5AA5\\n\"");
        end
        $finish;
    end

    // -- Watchdog ----------------------------------------------------------------
    initial begin
        #40000000;   // 40 ms watchdog (ample; 21 bytes x 10 bits x 20 ns + CPU)
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes, saw_write0=%0b saw_write1=%0b)",
                 rxn, NEXP, saw_write0, saw_write1);
        $finish;
    end

endmodule
`default_nettype wire
