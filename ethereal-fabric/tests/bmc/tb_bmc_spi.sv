`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_spi (testbench, self-checking)
// Description: E1-IO1 EFP-SPI CAPSTONE — a complete packed image deployment
//              driven over the NEORV32 SDI (SPI device) with §7 7-byte frames
//              + §7.1 CRC16 transport integrity:
//
//                SPI host BFM (bit-banged, mode 0, MSB-first)
//                    | sdi_clk/csn/dat_i/dat_o
//                NEORV32 SDI --CSR--> efp-spi firmware (efp_spi.c: frame
//                    decode -> EMRI window access via drivers/emri.h, SAME
//                    AXI path as the daemon: XBUS -> eth_wb2axi)
//                    |
//                eth_axi_xbar (2 masters: BMC, idle spare)
//                    | 1 slave (512 B window)
//                emri_axi_adapter -> emri_regfile (EFP_CMD doorbell picked up
//                    by the daemon = shared-regfile design, spec §3.2/§7.1)
//                    | OCC master    | dec_start
//                occ_top --fbus--> frame_decoder -> fabric_top (2x2 CLB)
//
//              Scenario (spec §7/§7.1/§3.3):
//                1. RD MAGIC over SPI (expect 0x45544852, STATUS=OK).
//                2. Stage img P (packed TFF col0: digest/sig/IMG_WORDS=34/
//                   IMG_COLS=1/REGION=0) via WR frames; WR SPI_CRC(0x3F) =
//                   crc16(34 DATA words); EFP_CMD=run_packed; poll
//                   EFP_STATUS==LOAD over SPI (0xFF-retry through VERIFY);
//                   OCC_PUSH the 34 DATA words; poll RUNNING+done, EFP_ERR=0.
//                   Region-reset -> clb_out_obs[0] TOGGLES on the real fabric.
//                3. EFP_CMD=stop -> STOPPED, column blanked (const 0).
//                4. NEGATIVE: re-run with word[5] bit0 flipped in the OCC_PUSH
//                   stream but the ORIGINAL (correct) SPI_CRC -> the §7.1
//                   gate fires: responses carry STATUS=0x04 (CRC_ERR), daemon
//                   EFP_ERR=8 (crc_transport), state=ERROR (never RUNNING),
//                   region re-blanked (fabric stays const 0); a following
//                   EFP_CMD=nop write clears the CRC_ERR status (§7.1 step 6).
//
//              UART daemon log is SPOT-CHECKED (containment), chk() counted.
// Maintainer:  BaiTian6641
// Created:     2026-09-02
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §7 (EFP-SPI transport) +
//              §7.1 (CRC16) + §3.3 (run_packed);
//              ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.3
// Notes:       Verilator --binary --timing (Makefile test-sv), same exemption
//              as tb_bmc_daemon_packed (Ed25519 verify ~0.84 s sim each).
//              SDI link: byte-pulsed CS (one CS-low pulse per byte — the
//              depth-1 SDI TX FIFO reloads 3 fabric clocks after each byte,
//              far faster than a polled CPU can refill); SCK half-period
//              200 ns (3.2 µs/byte), inter-byte gap 8 µs (covers worst-case
//              firmware service latency incl. UART print bursts — a late
//              TX re-arm would lose a response byte), inter-frame gap 50 µs
//              (the §7.1 assembler-resync delimiter). SPI_CRC expected
//              value computed in-TB (crc16_words_sv) from DAEMON_IMGP_WORDS;
//              the same value equals the packed frame's own CRC16 tail word
//              (generated/tb_frames/img_a_col0.hex word 34). UART bit time
//              = 2 clk.
`timescale 1ns/1ps

module tb_bmc_spi;
  import emri_pkg::*;

  // -- Fabric geometry (2x2 homogeneous CLB; matches the packed golden frames)
  localparam int R = 2, C = 2, W = 12, N = 8, K = 4, EXT_IN = 18, SELW = 5;
  localparam int OBS_W = R * C * N;                 // 32
  localparam int MAX_WORDS = (R * 530 + 31) / 32;   // 34 DATA words/column (v2c)

  // -- Timing -------------------------------------------------------------------
  localparam int CLK_PERIOD_NS = 10;                // 100 MHz
  localparam int BIT_NS = 2 * CLK_PERIOD_NS;        // 20 ns/bit (UART)
  localparam int SCK_HALF_NS = 200;                 // SPI mode 0, 3.2 µs/byte
  // Inter-byte CS-high gap: must exceed the worst firmware service latency
  // (daemon poll iteration ~1 µs; a UART line print can block the loop for
  // several µs — a pop->re-arm later than the next CS fall loses a response
  // byte: the shifter loads 0x00 and the late byte is popped unshown).
  localparam int BYTE_GAP_NS = 8000;                // inter-byte CS-high gap
  // Long inter-frame gap: the §7.1 Modbus-style frame delimiter — the fw
  // resets its assembler after ~25 serviced CS-high idle gaps (~25 µs at the
  // ~1 µs daemon poll cadence), so 50 µs here.
  localparam int FRAME_GAP_NS = 50000;              // inter-frame gap (50 µs)

  logic clk;
  logic rst_n;

  // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) = AXI master 0 ----------------
  logic        uart0_txd;
  logic        uart0_rxd;
  // SDI (SPI device) pins, driven by the host BFM
  logic        sdi_clk;
  logic        sdi_csn;
  logic        sdi_mosi;
  logic        sdi_miso;

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
      .sdi_clk_i     (sdi_clk),
      .sdi_csn_i     (sdi_csn),
      .sdi_dat_i     (sdi_mosi),
      .sdi_dat_o     (sdi_miso),
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

  // -- Spare AXI master 1 (idle: this TB's host is the SPI link) -----------------
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
  logic [XIDW-1:0]    m_rid;
  logic [1:0]         m_rresp;

  eth_axi_xbar #(
      .N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
      .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .ADDR_MAP(ADDR_MAP)
  ) u_xbar (
      .clk_i(clk), .rst_ni(rst_n),
      // master 0 = BMC, master 1 = idle spare (low slice = index 0)
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
      .dec_start_o(dec_start), .dec_col_o(dec_col), .dec_busy_i(dec_busy)
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
      .region_locked_i(occ_region_locked)
  );

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

  // Fabric user/region reset: pulsed AFTER the WRITE decode completes (same
  // pattern as tb_bmc_axi_fabric / tb_bmc_daemon_packed).
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
      .dsp_vp_obs_o(dsp_vp_obs)
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

  // -- Packed-image test vectors (DATA words + digest/sig) -----------------------
  `include "tb_daemon_packed_vectors.svh"

  // CRC-16/CCITT-FALSE over the 34 DATA words (byte-wise, BE bytes per word) —
  // identical to frame_map.crc16 and the efp-spi firmware accumulator (§7.1).
  function automatic logic [15:0] crc16_words_sv;
      integer k, s, b;
      logic [15:0] crc;
      logic [7:0]  by;
      begin
          crc = 16'hFFFF;
          for (k = 0; k < DAEMON_IMGP_NWORDS; k = k + 1) begin
              for (s = 24; s >= 0; s = s - 8) begin
                  by = DAEMON_IMGP_WORDS[k][s +: 8];
                  crc = crc ^ {8'h00, by} << 8;
                  for (b = 0; b < 8; b = b + 1)
                      crc = crc[15] ? (crc << 1) ^ 16'h1021 : (crc << 1);
              end
          end
          return crc;
      end
  endfunction

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
                  #(1000);        // 1 µs poll step (verify phases are ~0.9 s)
                  to = to + 1;
              end
          end
          chk(found, tag);
      end
  endtask

  // ============================================================================
  // SPI host BFM (mode 0, MSB-first, 8-bit frames, CS-low delimited)
  // Device samples MOSI on the rising edge; MISO changes on the falling edge.
  // ============================================================================
  task automatic spi_bit(input logic tx, output logic rx);
      begin
          sdi_clk  = 1'b0;          // falling edge: device shifts next MISO bit
          sdi_mosi = tx;
          #(SCK_HALF_NS);
          sdi_clk  = 1'b1;          // rising edge: device samples MOSI
          #(SCK_HALF_NS);
          rx       = sdi_miso;      // sample MISO at end of the high phase
          sdi_clk  = 1'b0;
      end
  endtask

  // One CS-delimited BYTE pulse (§7.1 byte-pulsed link: the depth-1 SDI FIFO
  // cannot sustain back-to-back bytes in one CS pulse, so CS frames a byte).
  task automatic spi_byte(input bit [7:0] txb, output bit [7:0] rxb);
      integer i;
      logic rb;
      begin
          rxb = 8'h00;
          sdi_csn = 1'b0;
          #(SCK_HALF_NS);
          for (i = 7; i >= 0; i = i - 1) begin
              spi_bit(txb[i], rb);
              rxb[i] = rb;
          end
          #(SCK_HALF_NS);
          sdi_csn = 1'b1;
          #(BYTE_GAP_NS);
      end
  endtask

  // One §7 7-byte frame = 7 byte-pulses, then the long inter-frame gap (the
  // §7.1 assembler-resync delimiter + fw processing window).
  bit [7:0] miso_b [0:6];

  task automatic spi_frame_raw(input bit [7:0] txb [0:6]);
      integer k;
      begin
          for (k = 0; k < 7; k = k + 1)
              spi_byte(txb[k], miso_b[k]);
          #(FRAME_GAP_NS);
      end
  endtask

  // ---- §7 request/response with the §7.1 pipelined-retry convention ----------
  // spi_call: send the request frame, then poll with benign RD-MAGIC frames
  // until the response (non-0xFF STATUS, matching ADDR echo) comes back.
  // Responses arrive in process order: if a POLL response (echo 0x0000) shows
  // up while waiting for addr != 0x0000, the request frame was dropped by the
  // device (CPU away, e.g. VERIFY) -> safe to re-issue (it never executed).
  bit [7:0] req_b [0:6];

  task automatic spi_send(input logic [7:0] op, input logic [15:0] addr,
                          input logic [31:0] data);
      begin
          req_b[0] = op;
          req_b[1] = addr[15:8];
          req_b[2] = addr[7:0];
          req_b[3] = data[31:24];
          req_b[4] = data[23:16];
          req_b[5] = data[15:8];
          req_b[6] = data[7:0];
          spi_frame_raw(req_b);
      end
  endtask

  task automatic spi_call(input logic [7:0] op, input logic [15:0] addr,
                          input logic [31:0] data,
                          output logic [7:0] status, output logic [31:0] rdata);
      integer attempt;
      logic   got;
      begin
          status = 8'hFF;
          rdata  = 32'h0;
          spi_send(op, addr, data);
          got = 1'b0;
          for (attempt = 0; attempt < 200000 && !got; attempt = attempt + 1) begin
              spi_send(8'h00, 16'h0000, 32'h0000_0000);  // RD MAGIC poll
              if (miso_b[0] === 8'hFF) begin
                  // no response ready yet — retry (§7.1)
              end else if ({miso_b[1], miso_b[2]} == addr) begin
                  status = miso_b[0];
                  rdata  = {miso_b[3], miso_b[4], miso_b[5], miso_b[6]};
                  got    = 1'b1;
              end else if (addr != 16'h0000) begin
                  // A stale/poll response arrived before ours -> the request
                  // was dropped (responses are ordered); re-issue it.
                  nresend = nresend + 1;
                  if (op != 8'h00 || (nresend % 500) == 0)
                      $display("  [dbg %0t] resend op=%02x addr=%04x #%0d (miso %02x %02x%02x)",
                               $time, op, addr, nresend, miso_b[0], miso_b[1], miso_b[2]);
                  spi_send(op, addr, data);
              end
          end
          if (!got) begin
              errors = errors + 1;
              $display("  FAIL: spi_call op=%02x addr=%04x never converged (last miso %02x %02x%02x %02x%02x%02x%02x)",
                       op, addr, miso_b[0], miso_b[1], miso_b[2],
                       miso_b[3], miso_b[4], miso_b[5], miso_b[6]);
          end
      end
  endtask

  // Poll EFP_STATUS over SPI until state[3:0]==st AND busy==0 (terminal).
  task automatic spi_wait_terminal(input logic [3:0] st, input string tag);
      logic [7:0]  st8;
      logic [31:0] d;
      integer to;
      begin
          to = 0;
          spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, d);
          while ((d[3:0] != st || d[4]) && to < 4000) begin
              #(20000);            // 20 µs pacing between SPI polls
              spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, d);
              to = to + 1;
          end
          chk(d[3:0] == st && !d[4], tag);
      end
  endtask

  // Poll EFP_STATUS over SPI until state[3:0]==st (busy ignored).
  task automatic spi_wait_state(input logic [3:0] st, input string tag);
      logic [7:0]  st8;
      logic [31:0] d;
      integer to;
      begin
          to = 0;
          spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, d);
          while (d[3:0] != st && to < 4000) begin
              #(20000);
              spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, d);
              to = to + 1;
          end
          chk(d[3:0] == st, tag);
      end
  endtask

  // ---- packed image staging (spec §3.3 staged metadata, §7 WR frames) --------
  task automatic spi_stage_packed;
      integer k;
      logic [7:0]  st8;
      logic [31:0] d;
      begin
          for (k = 0; k < 8; k = k + 1)
              spi_call(8'h01, R_IMG_DIGEST + 16'(k), DAEMON_IMGP_DIGEST[k], st8, d);
          for (k = 0; k < 16; k = k + 1)
              spi_call(8'h01, R_IMG_SIG + 16'(k), DAEMON_IMGP_SIG[k], st8, d);
          spi_call(8'h01, R_EFP_IMG_WORDS, 32'(DAEMON_IMGP_NWORDS), st8, d);
          spi_call(8'h01, R_EFP_IMG_COLS, 32'd1, st8, d);
          spi_call(8'h01, R_EFP_REGION, 32'h0000_0000, st8, d);
      end
  endtask

  // Stream the column's DATA words as OCC_PUSH frames (§7.1), with an
  // optional single-bit corruption at (flip_word, flip_bit).
  task automatic spi_stream_packed(input integer flip_word, input integer flip_bit);
      integer k;
      logic [31:0] w;
      logic [7:0]  st8;
      logic [31:0] d;
      begin
          for (k = 0; k < DAEMON_IMGP_NWORDS; k = k + 1) begin
              w = DAEMON_IMGP_WORDS[k];
              if (k == flip_word) w = w ^ (32'h1 << flip_bit);
              spi_call(8'h03, R_OCC_WDATA, w, st8, d);
          end
      end
  endtask

  // ---- fabric observation (the REAL fabric outputs) ----------------------------
  task automatic observe_toggle(input string tag);
      integer k;
      logic s0, s1;
      begin
          s0 = 1'b0; s1 = 1'b0;
          for (k = 0; k < 128; k = k + 1) begin
              @(posedge clk);
              if (clb_out_obs[0] === 1'b0) s0 = 1'b1;
              if (clb_out_obs[0] === 1'b1) s1 = 1'b1;
          end
          chk(s0 && s1, tag);
      end
  endtask

  task automatic observe_const(input logic v, input string tag);
      integer k;
      logic bad;
      begin
          bad = 1'b0;
          for (k = 0; k < 128; k = k + 1) begin
              @(posedge clk);
              if (clb_out_obs[0] !== v) bad = 1'b1;
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

  // dec_done is a 1-cycle pulse; count them (positive run = 2; stop = +1;
  // negative run = BLANK + LOAD + gate re-blank = +3).
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

  // Same, but searching from a remembered buffer offset (the negative phase
  // re-prints lines the positive run already emitted).
  task automatic wait_uart_contains_from(input integer start, input string s,
                                         input string tag);
      integer to, base, j;
      logic found, m;
      begin
          to = 0;
          found = 1'b0;
          while (!found && to < 4000000) begin
              for (base = start; base + s.len() <= rxn; base = base + 1) begin
                  m = 1'b1;
                  for (j = 0; j < s.len(); j = j + 1)
                      if (rxq[base + j] !== s[j]) m = 1'b0;
                  if (m) begin
                      found = 1'b1;
                      break;
                  end
              end
              if (!found) begin
                  #(1000);
                  to = to + 1;
              end
          end
          chk(found, tag);
      end
  endtask

  // ============================================================================
  // Test sequence (spec §7/§7.1 over the §3.3 run_packed flow)
  // ============================================================================
  logic [7:0]  st8;
  logic [31:0] rd;
  logic [15:0] crc_exp;
  integer      uart_mark;
  integer      nresend = 0;

  initial begin : main_seq
      // idle the SPI host + spare AXI master + UART RX
      sdi_clk  = 1'b0;
      sdi_csn  = 1'b1;
      sdi_mosi = 1'b1;
      h_awvalid = 1'b0; h_awaddr = 32'h0;
      h_wvalid  = 1'b0; h_wdata  = 32'h0;
      h_bready  = 1'b0;
      h_arvalid = 1'b0; h_araddr = 32'h0;
      h_rready  = 1'b0;
      uart0_rxd = 1'b1;

      rst_n = 1'b0;
      repeat (20) @(posedge clk);
      rst_n = 1'b1;

      // ---- 0. boot: banner + Ed25519 selftest + EMRI probe + SPI front-end ----
      $display("[0] boot (selftest = 2 verifies, ~1.7 s sim)");
      wait_uart_contains("bmc-fw v0.2 daemon boot\n", "boot banner");
      wait_uart_contains("ed25519 selftest OK\n", "boot Ed25519 selftest");
      wait_uart_contains("efp-spi ready\n", "EFP-SPI front-end initialized");
      wait_uart_contains("daemon ready\n", "daemon poll loop entered");

      // ---- 1. RD MAGIC over SPI -------------------------------------------------
      $display("[1] RD MAGIC over SPI");
      spi_call(8'h00, R_MAGIC, 32'h0, st8, rd);
      chk(st8 == 8'h00, "RD MAGIC: STATUS=OK");
      chk(rd == 32'h4554_4852, "RD MAGIC: DATA=0x45544852 (ETHR)");

      // ---- 2. run_packed image P over SPI (with §7.1 CRC16) ---------------------
      $display("[2] run_packed image P over SPI — stage, CRC latch, doorbell, stream");
      crc_exp = crc16_words_sv();
      spi_stage_packed();
      spi_call(8'h01, R_SPI_CRC, {16'h0, crc_exp}, st8, rd);   // latch expected CRC16
      chk(st8 == 8'h00, "WR SPI_CRC: STATUS=OK (expected CRC16 latched)");
      spi_call(8'h01, R_EFP_CMD, {24'h0, EFP_CMD_RUN_PACKED}, st8, rd);
      chk(st8 == 8'h00, "WR EFP_CMD=run_packed: STATUS=OK");
      wait_uart_contains("cmd run_packed\n", "run_packed: doorbell accepted");
      // §3.3 step 3: poll state==LOAD (0xFF retries through VERIFY), then stream.
      spi_wait_state(EFP_S_LOAD, "run_packed: state==LOAD over SPI (col 0 armed)");
      wait_uart_contains("st LOAD c0\n", "run_packed: UART st LOAD c0");
      spi_stream_packed(-1, 0);
      spi_wait_terminal(EFP_S_RUNNING, "run_packed: terminal RUNNING over SPI");
      spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, rd);
      if (!(rd[3:0] == EFP_S_RUNNING && rd[5] == 1'b1))
          $display("  [dbg] RUNNING+done readback: status=%02x raw=%08x (resends=%0d)",
                   st8, rd, nresend);
      chk(rd[3:0] == EFP_S_RUNNING && rd[5] == 1'b1,
          "EFP_STATUS = RUNNING + done (over SPI)");
      spi_call(8'h00, R_EFP_ERR, 32'h0, st8, rd);
      chk(st8 == 8'h00 && rd[7:0] == EFP_ERR_NONE,
          "EFP_ERR = none (transport CRC16 ok, READBACK ok)");
      wait_uart_contains("st RUNNING r0 done\n", "run_packed: UART RUNNING");
      wait_dec_done(2, "run_packed: BLANK+WRITE frame_decoder decodes done");
      fab_region_reset();
      observe_toggle("run_packed: clb_out_obs[0] toggles (TFF deployed over SPI)");

      // ---- 3. stop region 0 over SPI --------------------------------------------
      $display("[3] stop region 0 over SPI (packed per-column BLANK)");
      spi_call(8'h01, R_EFP_REGION, 32'h0000_0000, st8, rd);
      spi_call(8'h01, R_EFP_CMD, {24'h0, EFP_CMD_STOP}, st8, rd);
      wait_uart_contains("cmd stop\nst BLANK c0\nblank c0 ok\nst STOPPED r0\n",
                         "stop: per-column BLANK -> STOPPED");
      spi_wait_terminal(EFP_S_STOPPED, "stop: terminal STOPPED over SPI");
      wait_dec_done(3, "stop: blank frame_decoder decode done");
      fab_region_reset();
      observe_const(1'b0, "stopped: clb_out_obs[0] constant 0 (column blanked)");

      // ---- 4. NEGATIVE: bit-flipped OCC_PUSH word + ORIGINAL CRC ----------------
      $display("[4] negative: corrupted OCC_PUSH stream vs original SPI_CRC");
      uart_mark = rxn;   // search negative-phase UART lines from here
      spi_stage_packed();
      spi_call(8'h01, R_SPI_CRC, {16'h0, crc_exp}, st8, rd);   // CORRECT crc
      spi_call(8'h01, R_EFP_CMD, {24'h0, EFP_CMD_RUN_PACKED}, st8, rd);
      wait_uart_contains_from(uart_mark, "cmd run_packed\nst VERIFY\nverify ok\n",
                              "negative: VERIFY passes (signature is for the image)");
      spi_wait_state(EFP_S_LOAD, "negative: state==LOAD over SPI");
      spi_stream_packed(5, 0);   // flip bit0 of DATA word 5 on the wire
      // The comparison fires at the last push; the daemon gate (LOAD->READBACK)
      // re-blanks and fails crc_transport before RUNNING.
      wait_uart_contains("err crc_transport\nst ERROR\n",
                         "negative: daemon EFP_ERR=crc_transport, state ERROR");
      spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, rd);
      chk(st8 == 8'h04, "negative: SPI STATUS=CRC_ERR (0x04) until next EFP_CMD");
      if (!(rd[3:0] == EFP_S_ERROR && !rd[4]))
          $display("  [dbg] negative ERROR readback: raw=%08x", rd);
      chk(rd[3:0] == EFP_S_ERROR && !rd[4],
          "negative: EFP_STATUS=ERROR (never RUNNING; RD data still returned)");
      spi_call(8'h00, R_EFP_ERR, 32'h0, st8, rd);
      chk(st8 == 8'h04 && rd[7:0] == 8'd8,
          "negative: EFP_ERR=8 (crc_transport)");
      wait_dec_done(6, "negative: BLANK+LOAD+gate re-blank decodes done");
      fab_region_reset();
      observe_const(1'b0, "negative: fabric blank (re-blanked by the CRC gate)");
      // §7.1 step 6: the next EFP_CMD write (nop) clears the CRC_ERR status.
      spi_call(8'h01, R_EFP_CMD, {24'h0, EFP_CMD_NOP}, st8, rd);
      chk(st8 == 8'h04, "negative: clearing EFP_CMD write itself still flags CRC_ERR");
      spi_call(8'h00, R_EFP_STATUS, 32'h0, st8, rd);
      chk(st8 == 8'h00, "negative: STATUS=OK again after the EFP_CMD write");

      // ---- report ---------------------------------------------------------------
      begin : dump_uart
          integer i;
          $write("--- UART log (%0d B, resends=%0d, dec_done=%0d) ---\n",
                 rxn, nresend, dec_done_count);
          for (i = 0; i < rxn; i = i + 1) $write("%c", rxq[i]);
          $write("\n--- UART log end ---\n");
      end
      if (errors == 0)
          $display("TEST PASSED: E1-IO1 EFP-SPI — packed TFF deployed over SDI 7-byte frames (MAGIC/stage/CRC16/run_packed/OCC_PUSH stream), toggles on real fabric, stop over SPI; CRC16 error injection -> CRC_ERR + crc_transport(8) + ERROR (never RUNNING) + fabric re-blanked");
      else
          $display("TEST FAILED: %0d errors", errors);
      $finish;
  end

  // -- Watchdog -------------------------------------------------------------------
  initial begin : watchdog
      integer i;
      // Total sim ≈ 3 verify-equivalents × ~0.84 s + SPI traffic (~50 ms) ≈ ~4 s.
      repeat (15) #(1000000000);   // 15 s hard cap
      $display("TEST FAILED: watchdog timeout (rxn=%0d errors=%0d resends=%0d dec_done=%0d)",
               rxn, errors, nresend, dec_done_count);
      // Debug dump: the daemon UART log (the ground truth of where it went).
      $write("--- UART log begin ---\n");
      for (i = 0; i < rxn; i = i + 1) $write("%c", rxq[i]);
      $write("\n--- UART log end ---\n");
      $finish;
  end

endmodule
`default_nettype wire
