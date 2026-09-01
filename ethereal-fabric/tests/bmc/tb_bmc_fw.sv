`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_fw (testbench, self-checking)
// Description: E1-RUN2 smoke TB — the REAL C daemon firmware (bmc-fw v0.2:
//              crt0 DMEM-exec boot stub + Ed25519 boot selftest + EMRI
//              MAGIC/CAP probe + EFP daemon poll loop) boots on the vendored
//              NEORV32 inside bmc_core and prints its banner over UART0.
//              The full daemon command flow is the tb_bmc_daemon capstone;
//              THIS TB is the firmware/harness smoke: exact-match the boot
//              byte stream and prove the EMRI probe works over the real AXI
//              chain (XBUS -> wb2axi -> xbar -> adapter -> regfile).
//
//              main.c prints (exact):
//                "bmc-fw v0.2 daemon boot\n"
//                "ed25519 selftest OK\n"
//                "EMRI MAGIC=45544852 CAP=00000001\n"
//                "daemon ready\n"
//              The TB exact-matches the full byte stream (90 bytes).
//
//              BOOTSTRAP: the vendored netlist IMEM ROM is physically 1 KiB
//              (imem_rom reads addr_i[9:2]), so the firmware DMEM-execs: the
//              TB preloads bmc_boot.hex into the ROM array (n6964) and
//              bmc_dmem_lane{0..3}.hex into the 4 dmem_ram byte-lane sprams
//              (see bmc-fw/boot/crt0.S BOOTSTRAP NOTE).
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Modified:    2026-09-01 - E1-RUN2: daemon firmware, DMEM-exec preload,
//              runs under Verilator --timing (iverilog is too slow for the
//              ~166M-cycle boot Ed25519 selftest on the iterative-mul NEORV32
//              netlist; sim-only slowness — ~1.6 s @50 MHz real silicon)
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2/§2.3 (E1-RUN2)
// Notes:       simulated via Verilator --binary --timing (see Makefile
//              test-sv; ADR-018 §7.5 iverilog constraint exempted here for
//              cycle count, not language). Self-checking; prints "TEST PASSED".
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

    // BMC AXI master channels -> EMRI chain (this firmware reads EMRI MAGIC+CAP
    // over XBUS, so the chain is REAL, not tied off — matches tb_bmc_axi_emri).
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
        .heartbeat_o   ()
    );

    // -- eth_axi_xbar: 1 master x 1 slave (+ decode-error slave) ----------------
    localparam int N_MST = 1, N_SLV = 1, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 1;
    localparam int XIDW = AXI_IDW + 1;
    // EMRI window: 256 B (64 words) at 0x4000_2000 -> mask 0xFFFF_FF00
    localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {32'hFFFF_FF00, 32'h4000_2000};

    logic               m_awvalid, m_awready;
    logic [AXI_AW-1:0]  m_awaddr;
    logic [XIDW-1:0]    m_awid;
    logic               m_wvalid, m_wready;
    logic [AXI_DW-1:0]  m_wdata;
    logic [AXI_DW/8-1:0] m_wstrb;
    logic               m_bvalid, m_bready;
    logic [1:0]         m_bresp;
    logic               m_arvalid, m_arready;
    logic [AXI_AW-1:0]  m_araddr;
    logic [XIDW-1:0]    m_arid;
    logic               m_rvalid, m_rready;
    logic [AXI_DW-1:0]  m_rdata;
    logic [1:0]         m_rresp;

    eth_axi_xbar #(
        .N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
        .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .ADDR_MAP(ADDR_MAP)
    ) u_xbar (
        .clk_i(clk), .rst_ni(rst_n),
        .s_awvalid(awvalid), .s_awready(awready), .s_awaddr(awaddr), .s_awid(1'b0),
        .s_wvalid(wvalid),   .s_wready(wready),   .s_wdata(wdata),   .s_wstrb(wstrb),
        .s_bvalid(bvalid),   .s_bready(bready),   .s_bid(),          .s_bresp(bresp),
        .s_arvalid(arvalid), .s_arready(arready), .s_araddr(araddr), .s_arid(1'b0),
        .s_rvalid(rvalid),   .s_rready(rready),   .s_rid(),          .s_rdata(rdata),
        .s_rresp(rresp),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
        .m_wvalid(m_wvalid),   .m_wready(m_wready),   .m_wdata(m_wdata),   .m_wstrb(m_wstrb),
        .m_bvalid(m_bvalid),   .m_bready(m_bready),   .m_bid({XIDW{1'b0}}), .m_bresp(m_bresp),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
        .m_rvalid(m_rvalid),   .m_rready(m_rready),   .m_rid({XIDW{1'b0}}), .m_rdata(m_rdata),
        .m_rresp(m_rresp)
    );

    // -- emri_axi_adapter + emri_regfile (EMRI peripheral, HAS_BMC=1) ------------
    logic        host_req, host_we, host_ready;
    logic [1:0]  host_op;
    logic [15:0] host_addr;
    logic [31:0] host_wdata, host_rdata;

    emri_axi_adapter #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .REG_BASE(32'h4000_2000), .WIN_WORDS(64)
    ) u_emri_adapter (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_awaddr(m_awaddr),   .s_axi_awprot(3'b000),
        .s_axi_wvalid(m_wvalid),   .s_axi_wready(m_wready),
        .s_axi_wdata(m_wdata),     .s_axi_wstrb(m_wstrb),
        .s_axi_bvalid(m_bvalid),   .s_axi_bready(m_bready),
        .s_axi_bresp(m_bresp),
        .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_araddr(m_araddr),   .s_axi_arprot(3'b000),
        .s_axi_rvalid(m_rvalid),   .s_axi_rready(m_rready),
        .s_axi_rdata(m_rdata),     .s_axi_rresp(m_rresp),
        .host_req_o(host_req),     .host_we_o(host_we),   .host_op_o(host_op),
        .host_addr_o(host_addr),   .host_wdata_o(host_wdata),
        .host_rdata_i(host_rdata), .host_ready_i(host_ready)
    );

    // OCC side tied off (this smoke TB only reads EMRI identity registers;
    // the daemon's OCC path is exercised by tb_bmc_daemon).
    emri_regfile #(
        .HAS_BMC(1'b1), .NUM_REGIONS(2), .PLATFORM_ID(32'h0)
    ) u_emri (
        .clk_i(clk), .rst_ni(rst_n),
        .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
        .host_addr_i(host_addr), .host_wdata_i(host_wdata),
        .host_rdata_o(host_rdata), .host_ready_o(host_ready),
        .occ_cmd_o(), .occ_cmd_valid_o(), .occ_cmd_ready_i(1'b0),
        .occ_frame_addr_o(), .occ_word_count_o(),
        .occ_wdata_o(), .occ_wdata_valid_o(), .occ_wdata_ready_i(1'b0),
        .occ_status_i(3'd0), .occ_crc_error_i(1'b0), .occ_region_locked_o(),
        .dec_start_o(), .dec_col_o(), .dec_busy_i(1'b0)
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- Firmware preload (DMEM-exec bootstrap, see header BOOTSTRAP note) ------
    // ROM: 1 KiB boot stub. DMEM: full firmware, 4 byte-lane sprams.
    localparam string BOOT_IMAGE = "generated/bmc/bmc_boot.hex";
    localparam string DMEM_LANE0 = "generated/bmc/bmc_dmem_lane0.hex";
    localparam string DMEM_LANE1 = "generated/bmc/bmc_dmem_lane1.hex";
    localparam string DMEM_LANE2 = "generated/bmc/bmc_dmem_lane2.hex";
    localparam string DMEM_LANE3 = "generated/bmc/bmc_dmem_lane3.hex";
    initial begin
        // #1: the netlist's imem_rom has its OWN time-0 initial block that
        // fills n6964 with the (9-word) GHDL-conversion default image; the
        // simulator may run it AFTER a time-0 TB initial and clobber the
        // preload. Deferring past time 0 makes the preload win determinically
        // (the core is still in reset; reset releases at 200 ns).
        #1;
        $readmemh(BOOT_IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n6964);
        $readmemh(DMEM_LANE0, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                  .dmem_ram_inst.\ram_gen[0]_ram_inst .spram);
        $readmemh(DMEM_LANE1, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                  .dmem_ram_inst.\ram_gen[1]_ram_inst .spram);
        $readmemh(DMEM_LANE2, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                  .dmem_ram_inst.\ram_gen[2]_ram_inst .spram);
        $readmemh(DMEM_LANE3, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                  .dmem_ram_inst.\ram_gen[3]_ram_inst .spram);
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
    // Expected: "bmc-fw v0.2 daemon boot\ned25519 selftest OK\nEMRI
    // MAGIC=45544852 CAP=00000001\ndaemon ready\n" (90 bytes). The expected
    // bytes are a byte array (generated from the message; matches main.c
    // exactly).
    localparam int NEXP = 90;
    byte unsigned expected [0:NEXP-1] = '{
        8'h62, 8'h6d, 8'h63, 8'h2d, 8'h66, 8'h77, 8'h20, 8'h76,
        8'h30, 8'h2e, 8'h32, 8'h20, 8'h64, 8'h61, 8'h65, 8'h6d,
        8'h6f, 8'h6e, 8'h20, 8'h62, 8'h6f, 8'h6f, 8'h74, 8'h0a,
        8'h65, 8'h64, 8'h32, 8'h35, 8'h35, 8'h31, 8'h39, 8'h20,
        8'h73, 8'h65, 8'h6c, 8'h66, 8'h74, 8'h65, 8'h73, 8'h74,
        8'h20, 8'h4f, 8'h4b, 8'h0a, 8'h45, 8'h4d, 8'h52, 8'h49,
        8'h20, 8'h4d, 8'h41, 8'h47, 8'h49, 8'h43, 8'h3d, 8'h34,
        8'h35, 8'h35, 8'h34, 8'h34, 8'h38, 8'h35, 8'h32, 8'h20,
        8'h43, 8'h41, 8'h50, 8'h3d, 8'h30, 8'h30, 8'h30, 8'h30,
        8'h30, 8'h30, 8'h30, 8'h31, 8'h0a, 8'h64, 8'h61, 8'h65,
        8'h6d, 8'h6f, 8'h6e, 8'h20, 8'h72, 8'h65, 8'h61, 8'h64,
        8'h79, 8'h0a
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
            $display("TEST PASSED: bmc-fw v0.2 daemon firmware booted on NEORV32 (DMEM-exec), Ed25519 selftest OK, EMRI probe OK, daemon polling");
        end
        $finish;
    end

    // -- Watchdog ------------------------------------------------------------------
    initial begin
        // The boot Ed25519 selftest is ~166M cycles (~1.7 s sim) on the
        // iterative-mul NEORV32 netlist (sim-only slowness; ~3.3 s @50 MHz
        // real silicon for 2 verifies). Ample margin + banner UART time.
        #4000000000;  // 4 s
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes)", rxn, NEXP);
        $finish;
    end

endmodule
`default_nettype wire
