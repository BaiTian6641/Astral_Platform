`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_hotswap_stress (testbench, self-checking)
// Description: E1-DMO2 hot-swap STRESS — ROUNDS rotations between the two
//              regions, each a full run_packed deploy of a SIGNED image
//              (A = TFF, B = const-1), with three integrity layers per round:
//                1) daemon READBACK CRC (EFP_ERR=0 after every deploy,
//                   v0.5 §3.1.1 expected-CRC gate);
//                2) column_cfg_ram SHADOW MODEL — the target region's column
//                   words equal the image just streamed, and the NEIGHBOR
//                   region's words stay byte-identical to its previous state
//                   (zero cross-region corruption);
//                3) on-fabric signatures — the target column's observed output
//                   matches its image (TFF toggles / const-1 held) and the
//                   neighbor's output still matches ITS image (zero
//                   cross-region interference).
//
//              DUT chain (same as tb_bmc_daemon_packed):
//                host BFM --AXI4--> eth_axi_xbar <-- NEORV32 (real daemon FW)
//                                      | 1 slave (512 B EMRI window)
//                          emri_axi_adapter -> emri_regfile -> occ_top
//                                      |               | fbus
//                                      |         frame_decoder -> fabric_top
//                                      |                  (2x2 CLB)
//                                      +--> column_cfg_ram (readback + shadow)
//
//              Rotation schedule: round i deploys image ((i/2)&1) to region
//              (i%2) — each region cycles A -> B -> A, and every round
//              re-verifies the OTHER region end to end.
//
//              Sim scope: one daemon rotation costs an Ed25519 verify
//              (~0.84 s sim) + the packed deploy; the literal 2x10000 count is
//              exercised at the OCC layer (tb_occ_soak.sv) and is silicon
//              scope at the daemon level (report-E1-DMO2).
// Maintainer:  BaiTian6641
// Created:     2026-09-11
// Tags:        TESTBENCH
// Plan-Ref:    docs/ethereal-tasks.yaml E1-DMO2; ethereal-spec/control/emri-v0.md
//              §3.3 (run_packed) + §3.1.1 (expected-CRC gate)
// Notes:       Verilator --binary --timing. Vectors: gen_daemon_vectors.py
//              --svh-packed --frame-hex img_a_col0.hex --frame-hex-b
//              img_b_col0.hex (both signed with the daemon key).
//              UART bit time = 2 clk.
`timescale 1ns/1ps

module tb_hotswap_stress;
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

  // -- EMRI -> OCC -> frame_decoder -> fabric (packed frame format, §3.1/§3.3) ---
  logic [1:0]  occ_cmd;
  logic        occ_cmd_valid, occ_cmd_ready;
  logic [15:0] occ_frame_addr, occ_word_count;
  logic [31:0] occ_wdata;
  logic        occ_wdata_valid, occ_wdata_ready;
  logic [2:0]  occ_status;
  logic        occ_crc_error, occ_region_locked;
  // v0.1 R_OCC_DECODE outputs -> frame_decoder
  logic        dec_start;
  logic [7:0]  dec_col;

  // occ_top frame bus -> frame_decoder AND column_cfg_ram (readback target)
  logic [15:0] fbus_addr;
  logic [31:0] fbus_wdata;
  logic        fbus_we, fbus_re;
  logic [31:0] fbus_rdata;

  // frame_decoder -> fabric_top cfg port
  logic        dec_cfg_we;
  logic [15:0] dec_cfg_addr;
  logic [31:0] dec_cfg_data;
  logic        dec_busy, dec_done, dec_crc_error;

  // fabric observation
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
      .occ_region_locked_o(occ_region_locked),
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
      .fbus_we_o(fbus_we), .fbus_re_o(fbus_re), .fbus_rdata_i(fbus_rdata),
      .status_o(occ_status), .crc_error_o(occ_crc_error),
      .region_locked_i(occ_region_locked),
      .expect_crc_i(occ_expect_crc_w),
      .crc_result_o(occ_crc_result_w)
  );

  // Readback target for the OCC READBACK CRC verify (fabric_top has no cfg read
  // port — C03 §0 sim model; same role as in tb_bmc_daemon).
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
      .frame_base_i(16'h0000),
      .cfg_we_o(dec_cfg_we), .cfg_addr_o(dec_cfg_addr), .cfg_data_o(dec_cfg_data),
      .crc_error_o(dec_crc_error)
  );

  // Fabric user/region reset: pulsed AFTER the WRITE decode completes so the
  // image's FFs take ff_rst_val deterministically (v2c §7.7; same pattern as
  // tb_bmc_axi_fabric — real deployments region-reset after config).
  logic fab_usr_rst_n = 1'b1;
  logic fab_rst_n;
  assign fab_rst_n = rst_n & fab_usr_rst_n;

  fabric_top #(
      .R(R), .C(C), .W(W), .N(N), .K(K), .EXT_IN(EXT_IN),
      .TILE_TYPE({(R * C * 8){1'b0}})   // all CLB
  ) u_fabric (
      .clk_i(clk), .rst_ni(fab_rst_n),   // dedicated region user-reset (pulsed post-config); NOT the shared BMC rst_n
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
      // #1: the netlist's imem_rom has its OWN time-0 initial block filling
      // n7280 with the GHDL-conversion default image; the simulator may run it
      // AFTER a time-0 TB initial and clobber the preload. Defer past time 0
      // (the core is still in reset; reset releases at 200 ns).
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

  // -- Packed-image test vectors (DATA words + digest/sig + tampered sig) --------
  `include "tb_daemon_packed_vectors.svh"

  // ============================================================================
  // Concurrent UART 8N1 receiver (idle-high, start bit low, LSB first)
  // ============================================================================
  localparam int MAXB = 8192;
  bit [7:0] rxq [0:MAXB-1];
  integer   rxn = 0;   // received count

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

  // UART scan cursor: the log is consumed in script order, so a REPEATED
  // string (a per-round stop banner) must be produced FRESH — a scan from 0
  // would match an earlier round's copy and let the script race the daemon
  // (E1-DMO2 round-4 region_full). See wait_uart_contains below.
  integer rx_scan_pos = 0;

  // ============================================================================
  // Check helpers (chk-count style of tb_ethctl_replay)
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

  // Spot-check: block (bounded) until the daemon UART log CONTAINS string s.
  // (Containment, not exact-match, tb_ethctl_replay style.)
  task automatic wait_uart_contains(input string s, input string tag);
      integer to, base, j;
      logic found, m;
      begin
          to = 0;
          found = 1'b0;
          while (!found && to < 4000000) begin
              for (base = rx_scan_pos; base + s.len() <= rxn; base = base + 1) begin
                  m = 1'b1;
                  for (j = 0; j < s.len(); j = j + 1)
                      if (rxq[base + j] !== s[j]) m = 1'b0;
                  if (m) begin
                      found = 1'b1;
                      rx_scan_pos = base + s.len();   // consume the match
                      break;
                  end
              end
              if (!found) begin
                  #(1000);        // 1 µs poll step (verify phases are ~0.9 s)
                  to = to + 1;
              end
          end
          if (!found) begin
              // Diagnostic: the daemon log tail, so a failed expectation is
              // debuggable without re-instrumenting the TB.
              $display("  [uart] wait '%0s' not found; last 160 chars:", tag);
              for (j = (rxn > 160) ? rxn - 160 : 0; j < rxn; j = j + 1)
                  $write("%c", rxq[j][7:0]);
              $display("");
          end
          chk(found, tag);
      end
  endtask

  // ============================================================================
  // Host BFM (AXI master 1) — drive on negedge, sample handshakes on posedge
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

  // EMRI register access (word offset -> AXI address in the window)
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

  // Poll EFP_STATUS until busy=0 (spec §3.2: host MUST wait busy=0 before the
  // next EFP_CMD write).
  task automatic host_wait_idle;
      logic [31:0] s;
      integer to;
      begin
          to = 0;
          host_rd(R_EFP_STATUS, s);
          while (s[4] && to < 100000) begin
              host_rd(R_EFP_STATUS, s);
              to = to + 1;
          end
          chk(!s[4], "EFP_STATUS.busy cleared (host may issue next command)");
      end
  endtask

  // Poll EFP_STATUS until state[3:0]==st. 1 µs poll step (an unpaced AXI poll
  // loop is ~80 ns/iter — a flat iteration bound would expire mid-VERIFY;
  // VERIFY is ~0.84 s sim, so 4M x 1 µs = 4 s of headroom).
  task automatic host_wait_state(input logic [3:0] st, input string tag);
      logic [31:0] s;
      integer to;
      begin
          to = 0;
          host_rd(R_EFP_STATUS, s);
          while (s[3:0] != st && to < 4000000) begin
              #(1000);
              host_rd(R_EFP_STATUS, s);
              to = to + 1;
          end
          chk(s[3:0] == st, tag);
      end
  endtask

  // Poll EFP_STATUS until state==st AND busy==0 (terminal of a command).
  // Same 1 µs pacing as host_wait_state.
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

  // ---- packed image staging (spec §3.3 staged metadata) -----------------------
  task automatic host_stage_packed(input logic tamper, input logic sel_b,
                                   input logic [31:0] region);
      integer k;
      begin
          for (k = 0; k < 8; k = k + 1)
              host_wr(R_IMG_DIGEST + 16'(k),
                      sel_b ? DAEMON_IMGP_B_DIGEST[k] : DAEMON_IMGP_DIGEST[k]);
          for (k = 0; k < 16; k = k + 1)
              host_wr(R_IMG_SIG + 16'(k),
                      tamper          ? DAEMON_IMGP_SIG_TAMPER[k] :
                      (sel_b          ? DAEMON_IMGP_B_SIG[k] : DAEMON_IMGP_SIG[k]));
          host_wr(R_EFP_IMG_WORDS, 32'(DAEMON_IMGP_NWORDS));  // per-column DATA words
          host_wr(R_EFP_IMG_COLS, 32'd1);                      // 1 column
          host_wr(R_EFP_REGION, region);
      end
  endtask

  // Stream the column's DATA words through OCC_WDATA (spec §3.3 step 3).
  task automatic host_stream_packed(input logic sel_b);
      integer k;
      begin
          for (k = 0; k < DAEMON_IMGP_NWORDS; k = k + 1)
              host_wr(R_OCC_WDATA,
                      sel_b ? DAEMON_IMGP_B_WORDS[k] : DAEMON_IMGP_WORDS[k]);
      end
  endtask

  // ---- fabric observation (the REAL fabric outputs) ----------------------------
  task automatic observe_toggle(input int bit_idx, input string tag);
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

  task automatic observe_const(input logic v, input int bit_idx, input string tag);
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

  // Pulse the fabric region user-reset (fab_usr_rst_n, tb_bmc_axi_fabric
  // pattern): the image's FFs take ff_rst_val deterministically post-config.
  task automatic fab_region_reset;
      begin
          fab_usr_rst_n = 1'b0;
          repeat (10) @(posedge clk);
          fab_usr_rst_n = 1'b1;
          repeat (4) @(posedge clk);
      end
  endtask

  // dec_done is a 1-cycle pulse; count them (run_packed col0 = BLANK decode +
  // WRITE decode = 2; the stop blank adds a 3rd).
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
  // Test sequence (spec §3.3 run_packed flow)
  // ============================================================================
  logic [31:0] rd;
  // ---- E1-DMO2 rotation-stress state -----------------------------------------
`ifdef STRESS_ROUNDS
  localparam int ROUNDS = `STRESS_ROUNDS;
`else
  localparam int ROUNDS = 6;
`endif
  localparam int NW = DAEMON_IMGP_NWORDS;   // 34 DATA words/column (2x2)

  logic [31:0] shadow [0:1][0:NW-1];  // expected column_cfg_ram per region
  logic        cur_b  [0:1];          // current image per region (1 = B)
  logic        dep    [0:1];          // region has been deployed once
  int          exp_dec;               // expected frame_decoder decode pulses
  int          corr_total;            // config-word mismatches (must stay 0)
  integer      k;
  integer      round;
  int          region;
  logic        sel_b;

  // region r's per-column frame base (daemon: OCC_FRAME_ADDR v0.6 {region[15:12],col[11:8],word[7:0]}: region<<12 | col<<8, col == r)
  function automatic logic [15:0] reg_base(input int r);
      reg_base = 16'((r << 12) | (r << 8));
  endfunction

  // Compare one region's column_cfg_ram range against its shadow buffer.
  task automatic ram_check(input logic [15:0] base, input int rgn,
                           input string tag);
      integer j;
      integer bad;
      begin
          bad = 0;
          for (j = 0; j < NW; j = j + 1)
              if (u_cfgram.mem[base + j] !== shadow[rgn][j]) bad = bad + 1;
          if (bad != 0) corr_total = corr_total + bad;
          chk(bad == 0, tag);
      end
  endtask

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

      // ---- 0. boot: banner + Ed25519 selftest + EMRI probe + daemon up --------
      $display("[0] boot (selftest = 2 verifies, ~1.7 s sim)");
      wait_uart_contains("bmc-fw v0.2 daemon boot\n", "boot banner");
      wait_uart_contains("ed25519 selftest OK\n", "boot Ed25519 selftest");
      wait_uart_contains("daemon ready\n", "daemon poll loop entered");

      // ---- rotation loop (E1-DMO2) ---------------------------------------------
      for (k = 0; k < NW; k = k + 1) begin
          shadow[0][k] = 32'h0;
          shadow[1][k] = 32'h0;
      end
      cur_b[0] = 1'b0;
      cur_b[1] = 1'b0;
      dep[0] = 1'b0;
      dep[1] = 1'b0;
      exp_dec = 0;

      for (round = 0; round < ROUNDS; round = round + 1) begin
          region = round % 2;
          sel_b  = ((round / 2) % 2) == 1;
          $display("[round %0d] region %0d <- image %0s", round, region,
                   sel_b ? "B (const 1)" : "A (TFF)");
          // ALLOC accepts only FREE regions: a re-deploy of a RUNNING region
          // must STOP it first — and the packed stop blanks it per column, so
          // every rotation is a realistic blank -> deploy -> run hot-swap.
          if (dep[region]) begin
              host_wr(R_EFP_REGION, region);
              host_wr(R_EFP_CMD, {24'h0, EFP_CMD_STOP});
              if (region == 0)
                  wait_uart_contains("cmd stop\nst BLANK c0\nblank c0 ok\nst STOPPED r0\n",
                                     "round: stop region 0 -> STOPPED");
              else
                  wait_uart_contains("cmd stop\nst BLANK c1\nblank c1 ok\nst STOPPED r1\n",
                                     "round: stop region 1 -> STOPPED");
              host_wait_idle();
              exp_dec = exp_dec + 1;
          end
          host_stage_packed(1'b0, sel_b, region);
          host_wr(R_EFP_CMD, {24'h0, EFP_CMD_RUN_PACKED});
          wait_uart_contains("cmd run_packed\n", "round: doorbell accepted");
          host_wait_state(EFP_S_LOAD, "round: state==LOAD (WRITE armed)");
          if (region == 0) wait_uart_contains("st LOAD c0\n", "round: LOAD c0");
          else             wait_uart_contains("st LOAD c1\n", "round: LOAD c1");
          host_stream_packed(sel_b);
          host_wait_terminal(EFP_S_RUNNING, "round: terminal RUNNING");
          host_rd(R_EFP_ERR, rd);
          chk(rd[7:0] == EFP_ERR_NONE, "round: EFP_ERR=none (READBACK CRC ok)");
          exp_dec = exp_dec + 2;
          wait_dec_done(exp_dec, "round: BLANK+WRITE decodes done");
          fab_region_reset();

          // -- layer 2: storage shadow model (zero corruption) ------------------
          for (k = 0; k < NW; k = k + 1)
              shadow[region][k] = sel_b ? DAEMON_IMGP_B_WORDS[k]
                                        : DAEMON_IMGP_WORDS[k];
          ram_check(reg_base(region), region,
                    "target column RAM == streamed image");
          if (round >= 1)
              ram_check(reg_base(1 - region), 1 - region,
                        "neighbor column RAM byte-identical (no cross-region write)");

          // -- layer 3: on-fabric signatures -------------------------------------
          if (region == 0) begin
              if (sel_b) observe_const(1'b1, 0, "r0: image B -> obs[0] const 1");
              else       observe_toggle(0, "r0: image A -> obs[0] toggles");
          end else begin
              if (sel_b) observe_const(1'b1, 8, "r1: image B -> obs[8] const 1");
              else       observe_toggle(8, "r1: image A -> obs[8] toggles");
          end
          if (round >= 1) begin
              if (cur_b[1 - region])
                  observe_const(1'b1, (1 - region) * 8,
                                "neighbor output unchanged (image B held)");
              else
                  observe_toggle((1 - region) * 8,
                                 "neighbor output unchanged (image A toggling)");
          end
          cur_b[region] = sel_b;
          dep[region]   = 1'b1;
      end

      // ---- report ---------------------------------------------------------------
      $display("[stress] %0d rotations, config-word mismatches=%0d", ROUNDS,
               corr_total);
      if (errors == 0)
          $display("TEST PASSED: E1-DMO2 rotation stress — %0d signed packed rotations (2 regions, images A/B), zero config corruption, zero cross-region interference", ROUNDS);
      else
          $display("TEST FAILED: %0d errors", errors);
      $finish;
  end

  // -- Watchdog -------------------------------------------------------------------
  initial begin
      // Total sim ≈ 4 verify-equivalents × ~0.84 s + deploys ≈ ~4 s sim.
      repeat (15) #(1000000000);   // 15 s hard cap
      $display("TEST FAILED: watchdog timeout (rxn=%0d errors=%0d)",
               rxn, errors);
      $finish;
  end

endmodule
`default_nettype wire
