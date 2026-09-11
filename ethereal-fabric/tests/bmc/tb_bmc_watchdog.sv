`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_watchdog (testbench, self-checking)
// Description: E1-RUN4 region-watchdog CAPSTONE — the OCC op watchdog +
//              region heartbeat (emri-v0.md sec 3.5, v0.4) on the REAL
//              packed-deploy chain (same wiring as tb_bmc_daemon_packed):
//
//                host BFM --AXI4--+
//                                 v
//                NEORV32 --XBUS--> eth_wb2axi --> eth_axi_xbar (2 masters)
//                                                    | 1 slave (512 B window)
//                                           emri_axi_adapter --> emri_regfile
//                                                    | OCC master    | dec_start
//                                              occ_top --fbus--> frame_decoder
//                                                    |               | cfg
//                                                    +--> column_cfg_ram
//                                                    (readback)      v
//                                                              fabric_top (2x2 CLB)
//
//              Scenario (spec sec 3.5):
//                1. CLEAN run_packed to REGION 1 (neighbor, column 1):
//                   the watchdog budget is active on every occ_wait_done of
//                   this deploy and does NOT fire (no false positive);
//                   clb_out_obs[8] (col 1) toggles on the real fabric.
//                2. run_packed to REGION 0: the host streams N-1 words and
//                   goes SILENT mid-LOAD -> the OCC op watchdog fires:
//                   drain-complete (zeros) + region BLANK + EFP_ERR=9
//                   (watchdog_timeout) + state ERROR + an event-ring entry
//                   readable via EVT_LOG_DATA; column 0 output constant 0.
//                3. NEIGHBOR ISOLATION (packed path — the v0 cfg-addr
//                   format would alias regions onto the same tiles): the
//                   region-1 column keeps its config and output through
//                   the whole watchdog event — clb_out_obs[8] keeps
//                   toggling, and the periodic heartbeat READBACK of the
//                   RUNNING region 1 succeeds (CRC intact) after the event.
//
//              The packed-path isolation matters: the starved WRITE, its
//              drain and the recovery BLANK all target {region 0, col 0}
//              (frame_addr 0x0000); region 1 lives at {0x1xxx} in the cfg
//              ram and col_latched=1 in the frame_decoder.
// Maintainer:  BaiTian6641
// Created:     2026-09-08
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md sec 3.4/3.5 (v0.4);
//              ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-RUN4)
// Notes:       Verilator --binary --timing (Makefile test-sv; ~2 Ed25519
//              verifies + one watchdog expiry ~= 4 s sim — same ADR-018
//              §7.5 exemption as the other firmware TBs). Vectors are the
//              tb_bmc_daemon_packed ones (gen_daemon_vectors.py --svh-
//              packed). UART bit time = 2 clk.
`timescale 1ns/1ps

module tb_bmc_watchdog;
  import emri_pkg::*;

  // -- Fabric geometry (2x2 homogeneous CLB; matches the packed golden frames)
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
  localparam int OBS_W = R * C * N;                 // 32
  localparam int MAX_WORDS = (R * 530 + 31) / 32;   // 34 DATA words/column (v2c)

  // -- Timing -------------------------------------------------------------------
  localparam int CLK_PERIOD_NS = 10;                // 100 MHz
  localparam int BIT_NS = 2 * CLK_PERIOD_NS;        // 20 ns/bit

  logic clk;
  logic rst_n;

  // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) = AXI master 0 ----------------
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

  // -- Host BFM = AXI master 1 ----------------------------------------------------
  logic        h_awvalid, h_awready;
  logic [31:0] h_awaddr;
  logic        h_wvalid, h_wready;
  logic [31:0] h_wdata;
  logic        h_bvalid, h_bready;
  logic [1:0]  h_bresp;
  logic        h_arvalid, h_arready;
  logic [31:0] h_araddr;
  logic        h_rvalid, h_rready;
  logic [31:0] h_rdata;
  logic [1:0]  h_rresp;

  // -- eth_axi_xbar: 2 masters x 1 slave (+ decode-error slave) ----------------
  // EMRI window: 512 B (96 words, covers IMG_SIG @ 0x50-0x5F) @ 0x4000_2000.
  localparam int N_MST = 2, N_SLV = 1, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 1;
  localparam int XIDW = AXI_IDW + 1;
  localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP = {32'hFFFF_FE00, 32'h4000_2000};

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
      // master 0 = BMC, master 1 = host BFM (low slice = index 0)
      .s_awvalid({h_awvalid, awvalid}), .s_awready({h_awready, awready}),
      .s_awaddr({h_awaddr, awaddr}),    .s_awid(2'b00),
      .s_wvalid({h_wvalid, wvalid}),    .s_wready({h_wready, wready}),
      .s_wdata({h_wdata, wdata}),       .s_wstrb({4'hF, wstrb}),
      .s_bvalid({h_bvalid, bvalid}),    .s_bready({h_bready, bready}),
      .s_bid(),                         .s_bresp({h_bresp, bresp}),
      .s_arvalid({h_arvalid, arvalid}), .s_arready({h_arready, arready}),
      .s_araddr({h_araddr, araddr}),    .s_arid(2'b00),
      .s_rvalid({h_rvalid, rvalid}),    .s_rready({h_rready, rready}),
      .s_rid(),                         .s_rdata({h_rdata, rdata}),
      .s_rresp({h_rresp, rresp}),
      .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid),
      .m_wvalid(m_wvalid),   .m_wready(m_wready),   .m_wdata(m_wdata),   .m_wstrb(m_wstrb),
      .m_bvalid(m_bvalid),   .m_bready(m_bready),   .m_bid({XIDW{1'b0}}), .m_bresp(m_bresp),
      .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
      .m_rvalid(m_rvalid),   .m_rready(m_rready),   .m_rid({XIDW{1'b0}}), .m_rdata(m_rdata),
      .m_rresp(m_rresp)
  );

  // -- emri_axi_adapter + emri_regfile (BMC mode, HAS_BMC=1) ----------------------
  logic        host_req, host_we, host_ready;
  logic [1:0]  host_op;
  logic [15:0] host_addr;
  logic [31:0] host_wdata, host_rdata;

  emri_axi_adapter #(
      .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .REG_BASE(32'h4000_2000), .WIN_WORDS(96)
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

  // -- EMRI -> OCC -> frame_decoder -> fabric (packed frame format, sec 3.1/3.3) ---
  logic [1:0]  occ_cmd;
  logic        occ_cmd_valid, occ_cmd_ready;
  logic [15:0] occ_frame_addr, occ_word_count;
  logic [31:0] occ_wdata;
  logic        occ_wdata_valid, occ_wdata_ready;
  logic [2:0]  occ_status;
  logic        occ_crc_error;
  logic [7:0]  occ_region_locks;
  logic        occ_global_lock;
  logic        dec_start;
  logic [7:0]  dec_col;

  logic [15:0] fbus_addr;
  logic [31:0] fbus_wdata;
  logic        fbus_we, fbus_re;
  logic [31:0] fbus_rdata;

  logic        dec_cfg_we;
  logic [15:0] dec_cfg_addr;
  logic [31:0] dec_cfg_data;
  logic        dec_busy, dec_done, dec_crc_error;

  logic [OBS_W-1:0]     clb_out_obs;
  logic [R*C*32-1:0]    mem_vd_obs;
  logic [R*C*48-1:0]    dsp_vp_obs;

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
      .fbus_we_o(fbus_we), .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
      .status_o(occ_status), .crc_error_o(occ_crc_error),
      .region_locks_i(occ_region_locks), .global_lock_i(occ_global_lock),
      .expect_crc_i(occ_expect_crc_w),
      .crc_result_o(occ_crc_result_w)
  );

  // Readback target for the OCC READBACK CRC verify (same role as in
  // tb_bmc_daemon_packed).
  column_cfg_ram #(.ADDR_W(16), .DATA_W(32), .DEPTH(8192)) u_cfgram (
      .clk(clk), .we(fbus_we), .re(fbus_re),
      .addr(fbus_addr), .wdata(fbus_wdata), .rdata(fbus_rdata)
  );

  frame_decoder #(
      .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN), .SELW(SELW),
      .TILE_TYPE({(R * C * 8){1'b0}}),  // all CLB (homogeneous, matches img P)
      .MAX_WORDS(MAX_WORDS)
  ) u_dec (
      .clk_i(clk), .rst_ni(rst_n),
      .start_i(dec_start), .col_i(dec_col),
      .busy_o(dec_busy), .done_o(dec_done),
      .fbus_addr_i(fbus_addr), .fbus_wdata_i(fbus_wdata), .fbus_we_i(fbus_we),
      // frame_base_i declares the in-flight op's frame window: the decoder
      // captures in stream order but flags an out-of-window word via cfg_error_o
      // (E1-DMO2c), so a hardwired 0 is only correct for base-0 deploys (region 0
      // / column 0). Region 1's base is 0x1000|(1<<8) = 0x1100 (OCC_FRAME_ADDR
      // v0.6: 256-word column window).
      .frame_base_i(occ_frame_addr),
      .cfg_we_o(dec_cfg_we), .cfg_addr_o(dec_cfg_addr), .cfg_data_o(dec_cfg_data),
      .crc_error_o(dec_crc_error), .cfg_error_o()
  );

  // Fabric user/region reset (tb_bmc_daemon_packed pattern).
  logic fab_usr_rst_n = 1'b1;
  logic fab_rst_n;
  assign fab_rst_n = rst_n & fab_usr_rst_n;

  fabric_top #(
      .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN),
      .TILE_TYPE({(R * C * 8){1'b0}})   // all CLB
  ) u_fabric (
      .clk_i(clk), .rst_ni(fab_rst_n),
      .cfg_we_i(dec_cfg_we), .cfg_addr_i(dec_cfg_addr), .cfg_data_i(dec_cfg_data),
      .clb_out_obs_o(clb_out_obs),
      .mem_vd_obs_o(mem_vd_obs),
      .dsp_vp_obs_o(dsp_vp_obs),
      .scan_en_i(1'b0),
      .scan_in_i(1'b0),
      .scan_out_o()
  );

  // -- Clock ---------------------------------------------------------------------
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  // -- Firmware preload (DMEM-exec bootstrap; same backdoor as tb_bmc_daemon) ----
  initial begin
      #1;
      $readmemh("generated/bmc/bmc_boot.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                .imem_rom_imem_rom_inst.n7280);
      $readmemh("generated/bmc/bmc_dmem_lane0.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[0]_ram_inst .spram);
      $readmemh("generated/bmc/bmc_dmem_lane1.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[1]_ram_inst .spram);
      $readmemh("generated/bmc/bmc_dmem_lane2.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[2]_ram_inst .spram);
      $readmemh("generated/bmc/bmc_dmem_lane3.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[3]_ram_inst .spram);
  end

  // -- Packed-image test vectors (DATA words + digest/sig) ------------------------
  `include "tb_daemon_packed_vectors.svh"

  // ============================================================================
  // Concurrent UART 8N1 receiver (idle-high, start bit low, LSB first)
  // ============================================================================
  localparam int MAXB = 8192;
  bit [7:0] rxq [0:MAXB-1];
  integer   rxn = 0;

  always @(negedge uart0_txd) begin : uart_rx
      integer i;
      logic [7:0] b;
      #(BIT_NS / 2);
      if (uart0_txd === 1'b0) begin
          b = 8'h00;
          for (i = 0; i < 8; i = i + 1) begin
              #(BIT_NS);
              b[i] = uart0_txd;
          end
          #(BIT_NS);
          if (uart0_txd === 1'b1 && rxn < MAXB) begin
              rxq[rxn] = b;
              rxn = rxn + 1;
          end
      end
  end

  // ============================================================================
  // Check helpers
  // ============================================================================
  integer errors = 0;
  task automatic chk(input logic cond, input string msg);
      begin
          if (cond) $display("  ok: %0s", msg);
          else begin
              errors = errors + 1;
              $display("  FAIL: %0s", msg);
          end
      end
  endtask

  task automatic wait_uart_contains(input string s, input string tag);
      integer to, base, j;
      logic found, m;
      begin
          to = 0;
          found = 1'b0;
          while (!found && to < 4000000) begin
              for (base = 0; base + s.len() <= rxn; base = base + 1) begin
                  m = 1'b1;
                  for (j = 0; j < s.len(); j = j + 1)
                      if (rxq[base + j] !== s[j]) m = 1'b0;
                  if (m) begin
                      found = 1'b1;
                      break;
                  end
              end
              if (!found) begin
                  #(1000);        // 1 us poll step (verify phases are ~0.9 s)
                  to = to + 1;
              end
          end
          chk(found, tag);
      end
  endtask

  // ============================================================================
  // Host BFM (AXI master 1)
  // ============================================================================
  localparam logic [31:0] EMRI_BASE = 32'h4000_2000;

  task automatic axi_wr(input logic [31:0] a, input logic [31:0] d);
      logic aw_done, w_done;
      begin
          @(negedge clk);
          h_awaddr = a; h_awvalid = 1'b1;
          h_wdata  = d; h_wvalid  = 1'b1;
          h_bready = 1'b1;
          aw_done = 1'b0; w_done = 1'b0;
          while (!(aw_done && w_done)) begin
              @(posedge clk);
              if (h_awvalid && h_awready) aw_done = 1'b1;
              if (h_wvalid  && h_wready)  w_done  = 1'b1;
          end
          @(negedge clk);
          h_awvalid = 1'b0; h_wvalid = 1'b0;
          while (!h_bvalid) @(posedge clk);
          @(negedge clk);
          h_bready = 1'b0;
      end
  endtask

  task automatic axi_rd(input logic [31:0] a, output logic [31:0] d);
      logic ar_done, r_done;
      begin
          @(negedge clk);
          h_araddr = a; h_arvalid = 1'b1; h_rready = 1'b1;
          ar_done = 1'b0;
          while (!ar_done) begin
              @(posedge clk);
              if (h_arvalid && h_arready) ar_done = 1'b1;
          end
          @(negedge clk);
          h_arvalid = 1'b0;
          d = 32'h0; r_done = 1'b0;
          while (!r_done) begin
              @(posedge clk);
              if (h_rvalid) begin
                  d      = h_rdata;
                  r_done = 1'b1;
              end
          end
          @(negedge clk);
          h_rready = 1'b0;
      end
  endtask

  task automatic host_wr(input logic [15:0] word, input logic [31:0] d);
      begin
          axi_wr(EMRI_BASE + ({16'h0, word} << 2), d);
      end
  endtask

  task automatic host_rd(input logic [15:0] word, output logic [31:0] d);
      begin
          axi_rd(EMRI_BASE + ({16'h0, word} << 2), d);
      end
  endtask

  task automatic host_wait_terminal(input logic [3:0] st, input string tag);
      logic [31:0] s;
      integer to;
      begin
          to = 0;
          host_rd(R_EFP_STATUS, s);
          while ((s[3:0] != st || s[4]) && to < 4000000) begin
              #(1000);
              host_rd(R_EFP_STATUS, s);
              to = to + 1;
          end
          chk(s[3:0] == st && !s[4], tag);
      end
  endtask

  // ---- packed image staging (spec sec 3.3) ------------------------------------
  task automatic host_stage_packed(input logic [31:0] region);
      integer k;
      begin
          for (k = 0; k < 8; k = k + 1)
              host_wr(R_IMG_DIGEST + 16'(k), DAEMON_IMGP_DIGEST[k]);
          for (k = 0; k < 16; k = k + 1)
              host_wr(R_IMG_SIG + 16'(k), DAEMON_IMGP_SIG[k]);
          host_wr(R_EFP_IMG_WORDS, 32'(DAEMON_IMGP_NWORDS));  // per-column DATA words
          host_wr(R_EFP_IMG_COLS, 32'd1);                      // 1 column
          host_wr(R_EFP_REGION, region);
      end
  endtask

  // Stream the column's DATA words through OCC_WDATA — optionally starving
  // after nwords-1 (the watchdog scenario): the host goes SILENT mid-LOAD.
  task automatic host_stream_packed(input integer nwords);
      integer k;
      begin
          for (k = 0; k < nwords; k = k + 1)
              host_wr(R_OCC_WDATA, DAEMON_IMGP_WORDS[k]);
      end
  endtask

  // ---- fabric observation (the REAL fabric outputs) ----------------------------
  task automatic observe_toggle(input integer bit_idx, input string tag);
      integer k;
      logic s0, s1;
      begin
          s0 = 1'b0; s1 = 1'b0;
          for (k = 0; k < 128; k = k + 1) begin
              @(posedge clk);
              if (clb_out_obs[bit_idx] === 1'b0) s0 = 1'b1;
              if (clb_out_obs[bit_idx] === 1'b1) s1 = 1'b1;
          end
          chk(s0 && s1, tag);
      end
  endtask

  task automatic observe_const(input integer bit_idx, input logic v,
                               input string tag);
      integer k;
      logic bad;
      begin
          bad = 1'b0;
          for (k = 0; k < 128; k = k + 1) begin
              @(posedge clk);
              if (clb_out_obs[bit_idx] !== v) bad = 1'b1;
          end
          chk(!bad, tag);
      end
  endtask

  task automatic fab_region_reset;
      begin
          fab_usr_rst_n = 1'b0;
          repeat (10) @(posedge clk);
          fab_usr_rst_n = 1'b1;
          repeat (4) @(posedge clk);
      end
  endtask

  // dec_done is a 1-cycle pulse; count them. Expected total:
  //   region-1 clean deploy: BLANK c1 + WRITE c1              = 2
  //   region-0 starved deploy: BLANK c0 + drained WRITE c0
  //                            + watchdog recovery BLANK c0   = 3  (total 5)
  integer dec_done_count = 0;
  always @(posedge clk) if (dec_done) dec_done_count = dec_done_count + 1;

  task automatic wait_dec_done(input integer n, input string tag);
      integer k;
      begin
          k = 0;
          while (dec_done_count < n && k < 4000000) begin
              @(posedge clk);
              k = k + 1;
          end
          chk(dec_done_count >= n, tag);
      end
  endtask

  // ============================================================================
  // Test sequence (spec sec 3.5)
  // ============================================================================
  logic [31:0] rd;

  initial begin : main_seq
      // idle the host BFM + UART RX
      h_awvalid = 1'b0; h_awaddr = 32'h0;
      h_wvalid  = 1'b0; h_wdata  = 32'h0;
      h_bready  = 1'b0;
      h_arvalid = 1'b0; h_araddr = 32'h0;
      h_rready  = 1'b0;
      uart0_rxd = 1'b1;

      rst_n = 1'b0;
      repeat (20) @(posedge clk);
      rst_n = 1'b1;

      // ---- 0. boot ------------------------------------------------------------
      $display("[0] boot (selftest = 2 verifies worth, ~1.7 s sim)");
      wait_uart_contains("bmc-fw v0.2 daemon boot\n", "boot banner");
      wait_uart_contains("ed25519 selftest OK\n", "boot Ed25519 selftest");
      wait_uart_contains("daemon ready\n", "daemon poll loop entered");

      // ---- 1. CLEAN run_packed -> REGION 1 (neighbor, column 1) ---------------
      // The sec 3.5 watchdog budget is active on every occ_wait_done here
      // (34-word host-paced LOAD): it must NOT fire.
      $display("[1] clean run_packed -> region 1 (col 1): no false positive");
      host_stage_packed(32'h0000_0001);
      host_wr(R_EFP_CMD, {24'h0, EFP_CMD_RUN_PACKED});
      wait_uart_contains("cmd run_packed\n", "r1: doorbell accepted");
      host_rd(R_EFP_STATUS, rd);
      while (rd[3:0] != EFP_S_LOAD) begin
          #(1000);
          host_rd(R_EFP_STATUS, rd);
      end
      wait_uart_contains("st LOAD c1\n", "r1: LOAD c1 armed");
      host_stream_packed(DAEMON_IMGP_NWORDS);
      host_wait_terminal(EFP_S_RUNNING, "r1: terminal RUNNING (no watchdog false positive)");
      host_rd(R_EFP_ERR, rd);
      chk(rd[7:0] == EFP_ERR_NONE, "r1: EFP_ERR = none");
      wait_dec_done(2, "r1: BLANK+WRITE frame_decoder decodes done");
      fab_region_reset();
      observe_toggle(8, "r1: clb_out_obs[8] toggles (TFF on real fabric, col 1)");

      // ---- 2. run_packed -> REGION 0, host streams N-1 words then SILENT -----
      $display("[2] starved LOAD -> watchdog fires (region 0 blanked, EFP_ERR=9)");
      host_stage_packed(32'h0000_0000);
      host_wr(R_EFP_CMD, {24'h0, EFP_CMD_RUN_PACKED});
      wait_uart_contains("cmd run_packed\n", "r0: doorbell accepted");
      host_rd(R_EFP_STATUS, rd);
      while (rd[3:0] != EFP_S_LOAD) begin
          #(1000);
          host_rd(R_EFP_STATUS, rd);
      end
      wait_uart_contains("st LOAD c0\n", "r0: LOAD c0 armed");
      // Stream N-1 words, then GO SILENT: the OCC sits in ST_WRITE with
      // idx=N-1 < N, done_flag never sets, and the sec 3.5 budget expires.
      host_stream_packed(DAEMON_IMGP_NWORDS - 1);
      // (host silent from here)
      wait_uart_contains("wdt: occ op timeout\n", "watchdog fired (budget expired)");
      wait_uart_contains("wdt: drain-complete\n", "abort: drain-complete started");
      wait_uart_contains("wdt: drain ok\n", "abort: starved WRITE drained with zeros");
      wait_uart_contains("blank c0 ok\n", "abort: recovery BLANK c0 done");
      wait_uart_contains("err watchdog_timeout\n", "abort: EFP_ERR=watchdog_timeout");
      wait_uart_contains("st ERROR\n", "abort: state ERROR");
      host_wait_terminal(EFP_S_ERROR, "r0: terminal ERROR (busy=0)");
      host_rd(R_EFP_ERR, rd);
      chk(rd[7:0] == EFP_ERR_WATCHDOG_TIMEOUT, "EFP_ERR = watchdog_timeout (9)");
      // Column 0 fully decoded: BLANK c0 + (33 host + 1 drain-zero) WRITE
      // + recovery BLANK c0 = 3 more decodes (5 total).
      wait_dec_done(5, "starved deploy: BLANK + drained WRITE + recovery BLANK decoded");
      fab_region_reset();
      observe_const(0, 1'b0, "r0: clb_out_obs[0] constant 0 (column blanked)");

      // ---- 3. event ring entry readable (sec 3.4/3.5) ------------------------
      $display("[3] event ring: watchdog_timeout entry");
      host_rd(R_EVT_LOG_CTRL, rd);
      chk(rd[15:0] == 16'd1, "EVT ring count = 1");
      host_rd(R_EVT_LOG_DATA, rd);
      chk(rd[7:0] == EVT_CODE_WATCHDOG_TIMEOUT,
          "event code = watchdog_timeout (1)");
      chk(rd[15:8] == 8'd0, "event region = 0 (starved region)");
      host_rd(R_EVT_LOG_CTRL, rd);
      chk(rd[15:0] == 16'd0, "EVT ring drained");

      // ---- 4. NEIGHBOR ISOLATION: region 1 config + output survive -----------
      $display("[4] neighbor isolation: region 1 still toggling");
      observe_toggle(8, "isolation: clb_out_obs[8] keeps toggling (col 1 intact)");

      // ---- 5. heartbeat: periodic READBACK CRC of the RUNNING region 1 -------
      // (sec 3.5 v0 software heartbeat; fires after ~0.2 s of daemon idle and
      // proves the region-1 config CRC survived the region-0 watchdog event)
      $display("[5] heartbeat probe of region 1 (~0.25 s sim of idle)");
      wait_uart_contains("hb r1\n", "heartbeat: probe started");
      wait_uart_contains("hb r1 ok\n", "heartbeat: region 1 READBACK CRC ok (config intact)");
      observe_toggle(8, "post-heartbeat: clb_out_obs[8] still toggling");

      // ---- report -------------------------------------------------------------
      if (errors == 0)
          $display("TEST PASSED: E1-RUN4 watchdog — clean packed deploy (no false positive), starved LOAD -> drain+blank+EFP_ERR=9+event, neighbor region isolated, heartbeat ok");
      else
          $display("TEST FAILED: %0d errors", errors);
      $finish;
  end

  // -- Watchdog -------------------------------------------------------------------
  initial begin
      // Total sim ~= 2 verifies (~1.7 s) + deploys + watchdog expiry (~1 s)
      // + heartbeat idle (~0.25 s) ~= 4 s.
      repeat (15) #(1000000000);   // 15 s hard cap
      $display("TEST FAILED: watchdog timeout (rxn=%0d errors=%0d dec_done=%0d)",
               rxn, errors, dec_done_count);
      $finish;
  end

endmodule

`default_nettype wire
