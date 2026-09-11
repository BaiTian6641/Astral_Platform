`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_axi_fabric (testbench, self-checking)
// Description: THE Phase-1 real-fabric closure TB: the BMC (not a host BFM)
//              configures a REAL fabric region with a packed column image
//              through the in-house AXI management path, and the fabric
//              COMPUTES (a TFF toggles on the fabric observation port).
//
//              Chain: NEORV32 --XBUS(Wishbone)--> eth_wb2axi --AXI4-->
//                     eth_axi_xbar --decode--> emri_axi_adapter --host port-->
//                     emri_regfile --OCC master--> occ_top --fbus-->
//                     frame_decoder --cfg--> fabric_top
//
//              The firmware (gen_bmc_hello.py --mode occ-fabric) writes
//              OCC_FRAME_ADDR=0, OCC_WORD_COUNT=35, writes OCC_DECODE=col0
//              (emri_regfile v0.1: pulses dec_start_o -> frame_decoder.start_i,
//              emri-v0.md §3.1), issues OCC_CMD=START|WRITE (region 0), streams
//              the 35 packed DATA words from a ROM table, polls OCC_STATUS,
//              and prints "OF 00000008\n" over UART0.
//
//              The TB independently checks (a) the UART message and (b) that
//              the TFF image (img_a_col0 from pack_tb_frames.py) actually took:
//              after the deploy + frame_decoder done, clb_out_obs_o[0] TOGGLES.
//              This replaces the TB-sideband dec_start of shell_tb_mgmt_packed
//              with the BMC-driven R_OCC_DECODE trigger — the E1-BMC1 real
//              fabric loop.
// Maintainer:  BaiTian6641
// Created:     2026-08-30
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §3.1 (OCC_DECODE);
//              ethereal-plan/components/C05-BMC组件.md (BMC drives OCC);
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md (BMC = AXI master)
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              IMEM preload backdoor path matches tb_bmc_hello (ROM array
//              n7280, renamed n7280 -> n7280 on the 2026-09-02 SDI regen).
//              UART bit time = 2 clk (NEORV32 reset defaults PRSC=0/BAUD=0).
`timescale 1ns/1ps

module tb_bmc_axi_fabric;

    // -- Fabric geometry (matches the packed golden frames: 2x2 homogeneous CLB)
    localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
    localparam int MAX_WORDS = (R * 548 + 31) / 32;   // = 35 DATA words/column
    localparam int TIW = (R * C > 1) ? $clog2(R * C) : 1;

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
        // SDI tied off (CS high = idle): this TB drives no EFP-SPI traffic.
        .sdi_clk_i     (1'b0),
        .sdi_csn_i     (1'b1),
        .sdi_dat_i     (1'b1),
        .sdi_dat_o     (),
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

    // -- OCC wiring: emri_regfile OCC master -> occ_top -> frame_decoder -> fabric
    logic [1:0]  occ_cmd;
    logic        occ_cmd_valid, occ_cmd_ready;
    logic [15:0] occ_frame_addr, occ_word_count;
    logic [31:0] occ_wdata;
    logic        occ_wdata_valid, occ_wdata_ready;
    logic [2:0]  occ_status;
    logic        occ_crc_error;
    logic [7:0]  occ_region_locks;
    logic        occ_global_lock;
    // v0.1 R_OCC_DECODE outputs -> frame_decoder
    logic        dec_start;
    logic [7:0]  dec_col;

    // occ_top frame bus -> frame_decoder
    logic [15:0] fbus_addr;
    logic [31:0] fbus_wdata;
    logic        fbus_we;

    // frame_decoder -> fabric_top cfg port
    logic        dec_cfg_we;
    logic [15:0] dec_cfg_addr;
    logic [31:0] dec_cfg_data;
    logic        dec_busy, dec_done, dec_crc_error;

    // fabric observation
    logic [R*C*N-1:0]   clb_out_obs;
    logic [R*C*32-1:0]  mem_vd_obs;
    logic [R*C*48-1:0]  dsp_vp_obs;

    logic [31:0] occ_expect_crc_w;   // v0.5 §3.1.1 (OCC expected-CRC gate)
    logic [31:0] occ_crc_result_w;   // v0.5 §3.1.1 (OCC running CRC)
    emri_regfile #(
        .HAS_BMC(1'b1), .NUM_REGIONS(2), .PLATFORM_ID(32'h0)
    ) u_emri (
        .clk_i(clk), .rst_ni(rst_n),
        .host_req_i(host_req), .host_we_i(host_we), .host_op_i(host_op),
        .host_addr_i(host_addr), .host_wdata_i(host_wdata),
        .host_rdata_o(host_rdata), .host_ready_o(host_ready),
        .occ_cmd_o(occ_cmd), .occ_cmd_valid_o(occ_cmd_valid),
        .occ_cmd_ready_i(occ_cmd_ready),
        .occ_frame_addr_o(occ_frame_addr), .occ_word_count_o(occ_word_count),
        .occ_wdata_o(occ_wdata), .occ_wdata_valid_o(occ_wdata_valid),
        .occ_wdata_ready_i(occ_wdata_ready),
        .occ_status_i(occ_status), .occ_crc_error_i(occ_crc_error),
        .occ_region_locks_o(occ_region_locks), .occ_global_lock_o(occ_global_lock),
        // v0.1 R_OCC_DECODE -> frame_decoder start trigger (busy backpressured)
        .dec_start_o(dec_start), .dec_col_o(dec_col), .dec_busy_i(dec_busy),
        .occ_expect_crc_o(occ_expect_crc_w),
        .occ_crc_result_i(occ_crc_result_w)
    );

    occ_top #(.ADDR_W(16), .DATA_W(32)) u_occ (
        .clk_i(clk), .rst_ni(rst_n),
        .cmd_i(occ_cmd), .cmd_valid_i(occ_cmd_valid), .cmd_ready_o(occ_cmd_ready),
        .frame_addr_i(occ_frame_addr), .word_count_i(occ_word_count),
        .wdata_i(occ_wdata), .wdata_valid_i(occ_wdata_valid),
        .wdata_ready_o(occ_wdata_ready),
        .fbus_addr_o(fbus_addr), .fbus_wdata_o(fbus_wdata),
        .fbus_we_o(fbus_we), .fbus_re_o(), .fbus_rdata_i(32'h0),
        .status_o(occ_status), .crc_error_o(occ_crc_error),
        .region_locks_i(occ_region_locks), .global_lock_i(occ_global_lock),
        .expect_crc_i(occ_expect_crc_w),
        .crc_result_o(occ_crc_result_w)
    );

    frame_decoder #(
        .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN), .SELW(SELW),
        .TILE_TYPE({(R * C * 8){1'b0}}),  // all CLB (homogeneous, matches img_a)
        .MAX_WORDS(MAX_WORDS)
    ) u_dec (
        .clk_i(clk), .rst_ni(rst_n),
        .start_i(dec_start), .col_i(dec_col),
        .busy_o(dec_busy), .done_o(dec_done),
        .fbus_addr_i(fbus_addr), .fbus_wdata_i(fbus_wdata), .fbus_we_i(fbus_we),
        // frame_base_i declares the in-flight op's frame window; a hardwired 0
        // is only correct for base-0 deploys (this firmware decodes column 0).
        .frame_base_i(occ_frame_addr),
        .cfg_we_o(dec_cfg_we), .cfg_addr_o(dec_cfg_addr), .cfg_data_o(dec_cfg_data),
        .crc_error_o(dec_crc_error), .cfg_error_o()
    );

    // Fabric user/region reset: pulsed AFTER the WRITE decode completes so the
    // image's FFs take ff_rst_val deterministically (v2c §7.7: blank sel=0 reads
    // fb j=0, so an un-reset FF would self-read X forever; the v1.1 pass here was
    // X-resolution luck). Real deployments do the same (region reset after cfg).
    logic fab_usr_rst_n = 1'b1;
    logic fab_rst_n;
    assign fab_rst_n = rst_n & fab_usr_rst_n;

    fabric_top #(
        .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN),
        .TILE_TYPE({(R * C * 8){1'b0}})   // all CLB
    ) u_fabric (
        .clk_i(clk), .rst_ni(fab_rst_n),   // dedicated region user-reset (pulsed post-config below); NOT the shared BMC rst_n
        .cfg_we_i(dec_cfg_we), .cfg_addr_i(dec_cfg_addr), .cfg_data_i(dec_cfg_data),
        .clb_out_obs_o(clb_out_obs),
        .mem_vd_obs_o(mem_vd_obs),
        .dsp_vp_obs_o(dsp_vp_obs),
        .scan_en_i(1'b0),
        .scan_in_i(1'b0),
        .scan_out_o()
    );

    // -- Clock ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // -- IMEM image preload (backdoor into the generated netlist ROM) -----------
    localparam string IMAGE = "generated/bmc/bmc_occfab.hex";
    // Path matches tb_bmc_hello; ROM array renamed n6830 -> n7280 (2026-08-08 XBUS regen) -> n7280 (2026-09-02 SDI regen).
    initial begin
        $readmemh(IMAGE, dut.u_core.neorv32_top_inst
                  .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                  .imem_rom_imem_rom_inst.n7280);
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
    // Expected message: "OF 00000008\n" (12 bytes). OCC_STATUS after a clean
    // WRITE of frame 0: done_flag(bit3)=1, done_code=0, live=IDLE, crc=0,
    // region=0, frame_echo=0 -> 0x00000008.
    localparam int NEXP = 12;
    byte unsigned expected [0:NEXP-1] = '{
        8'h4F, 8'h46, 8'h20,                                      // 'O','F',' '
        8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h38,   // "00000008"
        8'h0a                                                     // '\n'
    };

    integer errors = 0;

    // dec_done is a 1-cycle pulse; the deploy does TWO decodes (BLANK then
    // WRITE). Count the pulses and gate the fabric check on the SECOND (the
    // WRITE decode that actually loads the image), so the blocking UART
    // receive in check #1 cannot make us miss them.
    integer dec_done_count = 0;
    always @(posedge clk) if (dec_done) dec_done_count = dec_done_count + 1;

    initial begin
        integer k;
        integer t0, t1;
        uart0_rxd = 1'b1;
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;                 // boot from IMEM ROM
        for (k = 0; k < NEXP; k = k + 1)
            uart_recv_byte();
        repeat (10) @(posedge clk);

        // 1. UART message matches "OF 00000008\n" (OCC WRITE completed clean)
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

        // 2. the WRITE decode finished (2nd decode: BLANK #1, WRITE #2)
        k = 0;
        while (dec_done_count < 2 && k < 400000) begin @(posedge clk); k = k + 1; end
        if (dec_done_count < 2) begin
            $display("TEST FAILED: WRITE frame_decoder done_o timeout (saw %0d decodes)",
                     dec_done_count);
            errors++;
        end

        // 3. the fabric COMPUTES: the TFF on clb_out_obs_o[0] toggles. Only
        //    checked AFTER the WRITE decode, i.e. once the image is actually in.
        // Region reset first: FF <- ff_rst_val=0, then the TFF toggles 0,1,0,...
        fab_usr_rst_n = 1'b0;
        repeat (10) @(posedge clk);
        fab_usr_rst_n = 1'b1;
        repeat (4) @(posedge clk);
        t0 = clb_out_obs[0];
        t1 = 0;
        for (k = 0; k < 40; k = k + 1) begin
            @(posedge clk);
            if (clb_out_obs[0] !== t0) t1 = 1;
        end
        if (!t1) begin
            $display("TEST FAILED: clb_out_obs_o[0] did not toggle (TFF not running)");
            errors++;
        end

        if (errors == 0) begin
            $display("TEST PASSED: BMC configured real fabric via R_OCC_DECODE (TFF toggles), printed \"OF 00000008\\n\"");
        end
        $finish;
    end

    // -- Watchdog ------------------------------------------------------------------
    initial begin
        #80000000;   // 80 ms (ample; decode + 35 pushes + poll + 12 UART bytes)
        $display("TEST FAILED: watchdog timeout (got %0d/%0d bytes, dec_done=%0b, errors=%0d)",
                 rxn, NEXP, dec_done, errors);
        $finish;
    end

endmodule
`default_nettype wire
