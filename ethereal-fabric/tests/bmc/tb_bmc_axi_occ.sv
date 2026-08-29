`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_axi_occ (testbench, self-checking)
// Description: THE Phase-1 minimal-loop closure TB: the BMC (not a host BFM)
//              streams a real OCC config frame into the fabric through the
//              in-house AXI management path.
//
//              Chain: NEORV32 --XBUS(Wishbone)--> eth_wb2axi --AXI4-->
//                     eth_axi_xbar --decode--> emri_axi_adapter --host port-->
//                     emri_regfile --OCC master--> occ_top --fbus-->
//                     column_cfg_ram
//
//              The firmware (gen_bmc_hello.py --mode occ) writes
//              OCC_FRAME_ADDR=0, OCC_WORD_COUNT=4, issues OCC_CMD=START|WRITE
//              (region 0), streams 4 config words (0xC0DE0000..3) via
//              OCC_WDATA, polls OCC_STATUS until the sticky done_flag, then
//              prints "OC 00000008\n" over UART0 (OCC_STATUS = done_flag|IDLE,
//              no CRC error, frame echo 0). The TB ALSO backdoor-checks that
//              column_cfg_ram.mem[0..3] received exactly the streamed words.
//
//              This replaces the host-direct EMRI/OCC drive (the mFSM fallback
//              path) with the BMC-as-master path — the E1-BMC1 sim closure.
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3/§4 (OCC command/status);
//              ethereal-plan/components/C05-BMC组件.md (BMC drives OCC);
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md (BMC = AXI master)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              IMEM preload backdoor path matches tb_bmc_hello (ROM array
//              n6964, renamed on the 2026-08-08 XBUS regen — update on regen).
//              UART bit time = 2 clk (NEORV32 reset defaults PRSC=0/BAUD=0).
//              column_cfg_ram is a SIM model (not synthesizable) standing in
//              for the fabric config store; occ_top/frame decode is real RTL.
`timescale 1ns/1ps

module tb_bmc_axi_occ;

    // -- Timing ---------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10;          // 100 MHz skeleton clock
    localparam int BIT_NS = 2 * CLK_PERIOD_NS;  // 20 ns/bit (PRSC=0, BAUD=0)

    logic clk;
    logic rst_n;

    // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) ---------------------------
    logic        uart0_txd;
    logic        uart0_rxd;

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

    // -- eth_axi_xbar: 1 master x 1 slave (+ decode-error slave) ---------------
    localparam int N_MST = 1, N_SLV = 1, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 1;
    localparam int XIDW = AXI_IDW + 1;      // N_MST=1 -> MIW=1 per xbar formula

    // EMRI window: 256 B (64 words) at 0x4000_2000 -> mask 0xFFFF_FF00
    localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {
        32'hFFFF_FF00,                      // mask0  @[32+:32]
        32'h4000_2000                       // base0  @[ 0+:32]
    };

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
        // master port 0 <- bmc_core (N_MST=1: 1-bit/1-word vectors, direct)
        .s_awvalid(awvalid), .s_awready(awready), .s_awaddr(awaddr), .s_awid(1'b0),
        .s_wvalid(wvalid),   .s_wready(wready),   .s_wdata(wdata),   .s_wstrb(wstrb),
        .s_bvalid(bvalid),   .s_bready(bready),   .s_bid(),          .s_bresp(bresp),
        .s_arvalid(arvalid), .s_arready(arready), .s_araddr(araddr), .s_arid(1'b0),
        .s_rvalid(rvalid),   .s_rready(rready),   .s_rid(),          .s_rdata(rdata),
        .s_rresp(rresp),
        // slave port 0 -> emri_axi_adapter (ID-less: IDs open/tied 0; route-back
        // uses the xbar's recorded owner, xbar §5.1)
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
        .m_wvalid(m_wvalid),   .m_wready(m_wready),   .m_wdata(m_wdata),   .m_wstrb(m_wstrb),
        .m_bvalid(m_bvalid),   .m_bready(m_bready),   .m_bid({XIDW{1'b0}}), .m_bresp(m_bresp),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
        .m_rvalid(m_rvalid),   .m_rready(m_rready),   .m_rid({XIDW{1'b0}}), .m_rdata(m_rdata),
        .m_rresp(m_rresp)
    );

    // -- emri_axi_adapter + emri_regfile (the EMRI peripheral) -------------------
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

    // -- OCC wiring: emri_regfile OCC master -> occ_top -> column_cfg_ram --------
    logic [1:0]  occ_cmd;
    logic        occ_cmd_valid, occ_cmd_ready;
    logic [15:0] occ_frame_addr, occ_word_count;
    logic [31:0] occ_wdata;
    logic        occ_wdata_valid, occ_wdata_ready;
    logic [2:0]  occ_status;
    logic        occ_crc_error, occ_region_locked;

    // occ_top frame bus -> column_cfg_ram
    logic [15:0] fbus_addr;
    logic [31:0] fbus_wdata, fbus_rdata;
    logic        fbus_we, fbus_re;

    emri_regfile #(
        .HAS_BMC(1'b1), .NUM_REGIONS(2), .PLATFORM_ID(32'h0)
    ) u_emri (
        .clk_i(clk), .rst_ni(rst_n),
        .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
        .host_addr_i(host_addr), .host_wdata_i(host_wdata),
        .host_rdata_o(host_rdata), .host_ready_o(host_ready),
        // OCC master port -> occ_top (REAL, not tied off — this is Phase D)
        .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid),
        .occ_cmd_ready_i(occ_cmd_ready),
        .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
        .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
        .occ_wdata_ready_i(occ_wdata_ready),
        .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
        .occ_region_locked_o(occ_region_locked)
    );

    occ_top u_occ (
        .clk_i(clk), .rst_ni(rst_n),
        .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
        .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
        .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid),
        .wdata_ready_o(occ_wdata_ready),
        .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata),
        .fbus_we_o(fbus_we), .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
        .status_o(occ_status), .crc_error_o(occ_crc_error),
        .region_locked_i(occ_region_locked)
    );

    column_cfg_ram #(.ADDR_W(16), .DATA_W(32), .DEPTH(8192)) u_ram (
        .clk(clk), .we(fbus_we), .re(fbus_re),
        .addr(fbus_addr), .wdata(fbus_wdata), .rdata(fbus_rdata)
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) -----------
    localparam string IMAGE = "generated/bmc/bmc_occ.hex";
    // Path matches tb_bmc_hello; ROM array renamed n6830 -> n6964 on XBUS regen.
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n6964);
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

    // -- Stimulus + check ---------------------------------------------------------
    // Expected message: "OC 00000008\n" (12 bytes). OCC_STATUS after a clean
    // WRITE of frame 0: done_flag(bit3)=1, done_code[5:4]=0(DONE), live[2:0]=
    // IDLE(0), crc_error(16)=0, region[11:8]=0, frame_echo[31:17]=0 -> 0x08.
    localparam int NEXP = 12;
    byte unsigned expected [0:NEXP-1] = '{
        8'h4F, 8'h43, 8'h20,                                      // 'O','C',' '
        8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h38,   // "00000008"
        8'h0a                                                     // '\n'
    };

    // expected config words streamed to frame 0
    localparam int NW = 4;
    logic [31:0] exp_word [0:NW-1] = '{
        32'hC0DE_0000, 32'hC0DE_0001, 32'hC0DE_0002, 32'hC0DE_0003
    };

    integer errors = 0;

    initial begin
        integer k;
        uart0_rxd = 1'b1;
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                 // boot from IMEM ROM
        for (k = 0; k < NEXP; k = k + 1)
            uart_recv_byte();
        repeat (10) @(posedge clk);

        // 1. UART message matches "OC 00000008\n" (OCC WRITE completed clean)
        if (rxn != NEXP) begin
            $display("TEST FAILED: got %0d bytes, expected %0d", rxn, NEXP);
            errors++;
        end else begin
            for (k = 0; k < NEXP; k = k + 1)
                if (rxq[k] !== expected[k]) begin
                    $display("TEST FAILED: byte %0d = 0x%02x, expected 0x%02x",
                             k, rxq[k], expected[k]);
                    errors++;
                end
        end

        // 2. Backdoor: the 4 config words actually landed in column_cfg_ram
        for (k = 0; k < NW; k = k + 1) begin
            if (u_ram.mem[k] !== exp_word[k]) begin
                $display("TEST FAILED: cfg_ram[%0d] = 0x%08h, expected 0x%08h",
                         k, u_ram.mem[k], exp_word[k]);
                errors++;
            end
        end

        if (errors == 0) begin
            $display("TEST PASSED: BMC streamed OCC config frame via XBUS/wb2axi/xbar/EMRI/OCC into column_cfg_ram, printed \"OC 00000008\\n\"");
        end
        $finish;
    end

    // -- Watchdog ------------------------------------------------------------------
    initial begin
        #60000000;   // 60 ms (ample; cmd accept + 4 pushes + poll + 12 UART bytes)
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes, errors=%0d)",
                 rxn, NEXP, errors);
        $finish;
    end

endmodule
`default_nettype wire
