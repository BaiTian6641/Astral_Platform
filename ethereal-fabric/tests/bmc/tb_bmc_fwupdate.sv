`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_bmc_fwupdate (testbench, self-checking)
// Description: E1-BMC2 dual-partition FW self-update demo (SIM-SCOPED,
//              emri-v0.md sec 3.6, v0.4) on the REAL BMC chain:
//
//                host BFM --AXI4--+
//                                 v
//                NEORV32 --XBUS--> eth_wb2axi --> eth_axi_xbar (2 masters)
//                                                    | 2 slaves
//                       +----------------------------+--------------------+
//                       v                                                 v
//             emri_axi_adapter -> emri_regfile          tb_fwflash (model)
//             (EFP staging + event ring)                "external SPI flash"
//                                                       2 slots, XIP target
//
//              The fwupdate firmware (bmc-fw/fwupdate/, real C) boots slot
//              A (XIP jump through XBUS), receives a v2 image over the
//              REUSED EFP staging registers, CRC32-verifies, writes slot
//              B, marks it active and re-boots into it; a corrupted active
//              slot falls back to the last-known-good slot A. The event
//              ring (sec 3.4) records every slot change. The slot payloads
//              are REAL RV32IMC images built by `make slots` (fwupdate/
//              slot_payload.S, linked at each slot's XIP entry).
//
//              Scenario (spec sec 3.6):
//                1. boot: slot A (v1) selected by active flag, CRC ok,
//                   payload prints its compiled-in digit ("payload: 1").
//                2. fw_update to slot B (v2): staged via IMG_SIG/IMG_DIGEST
//                   trailer/EFP_IMG_WORDS/EFP_IMG_COLS(version)/EFP_REGION;
//                   CRC ok -> slot B active -> re-boot -> "payload: 2".
//                3. negative: tampered CRC trailer -> EFP_ERR=10 (fwupdate),
//                   NO flash write, no reboot.
//                4. corrupt slot B payload word in the flash model;
//                   EFP_CMD=7 (reboot) -> B CRC FAIL -> fallback to A
//                   ("payload: 1" again).
//                5. event ring: 4 slot_change entries (A,B,B,A) with
//                   ascending stamps; W1C clear works.
//
//              ASSUMPTION (documented, spec sec 3.6): "reboot" is EMULATED
//              by re-entering the boot stub (no in-core soft reset in the
//              vendored netlist); the flash model is non-volatile across
//              the TB reset pulse (its storage has no reset clear).
// Maintainer:  BaiTian6641
// Created:     2026-09-08
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-spec/control/emri-v0.md sec 3.4/3.6 (v0.4);
//              ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md (E1-BMC2)
// Notes:       Verilator --binary --timing (Makefile test-sv; same reason
//              as the other bmc TBs — real C firmware on the netlist).
//              UART bit time = 2 clk. No Ed25519 in this firmware -> the
//              whole scenario is fast (~ms sim).
`timescale 1ns/1ps

module tb_bmc_fwupdate;
  import emri_pkg::*;

  // -- Flash stand-in geometry (fwupdate.h FW_*) --------------------------
  localparam int    SLOT_WORDS   = 64;             // per slot
  localparam int    HDR_WORDS    = 5;
  localparam int    PAYLOAD_WORD = 16;             // padded payload words
  localparam logic [31:0] FW_MAGIC = 32'h46445731; // "FDW1"

  // -- Timing -------------------------------------------------------------
  localparam int CLK_PERIOD_NS = 10;                // 100 MHz
  localparam int BIT_NS = 2 * CLK_PERIOD_NS;        // 20 ns/bit

  logic clk;
  logic rst_n;

  // -- DUT: bmc_core (NEORV32 + eth_wb2axi inside) = AXI master 0 ---------
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
      .sdi_clk_i     (1'b0),
      .sdi_csn_i     (1'b1),
      .sdi_dat_i     (1'b1),
      .sdi_dat_o     (),
      .heartbeat_o   ()
  );

  // -- Host BFM = AXI master 1 --------------------------------------------
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

  // -- eth_axi_xbar: 2 masters x 2 slaves (+ decode-error slave) ----------
  // slave 0: EMRI window 512 B @ 0x4000_2000 (mask 0xFFFF_FE00)
  // slave 1: flash window 512 B @ 0x4001_0000 (mask 0xFFFF_FE00)
  localparam int N_MST = 2, N_SLV = 2, AXI_AW = 32, AXI_DW = 32, AXI_IDW = 1;
  localparam int XIDW = AXI_IDW + 1;
  localparam logic [2*N_SLV*AXI_AW-1:0] ADDR_MAP =
      {32'hFFFF_FE00, 32'hFFFF_FE00, 32'h4001_0000, 32'h4000_2000};

  logic [N_SLV-1:0]        m_awvalid, m_awready;
  logic [N_SLV*AXI_AW-1:0] m_awaddr;
  logic [N_SLV*XIDW-1:0]   m_awid;
  logic [N_SLV-1:0]        m_wvalid, m_wready;
  logic [N_SLV*AXI_DW-1:0] m_wdata;
  logic [N_SLV*4-1:0]      m_wstrb;
  logic [N_SLV-1:0]        m_bvalid, m_bready;
  logic [N_SLV*2-1:0]      m_bresp;
  logic [N_SLV-1:0]        m_arvalid, m_arready;
  logic [N_SLV*AXI_AW-1:0] m_araddr;
  logic [N_SLV*XIDW-1:0]   m_arid;
  logic [N_SLV-1:0]        m_rvalid, m_rready;
  logic [N_SLV*AXI_DW-1:0] m_rdata;
  logic [N_SLV*2-1:0]      m_rresp;

  eth_axi_xbar #(
      .N_MST(N_MST), .N_SLV(N_SLV), .AXI_AW(AXI_AW), .AXI_DW(AXI_DW),
      .AXI_IDW(AXI_IDW), .AXI_XIDW(XIDW), .ADDR_MAP(ADDR_MAP)
  ) u_xbar (
      .clk_i(clk), .rst_ni(rst_n),
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
      .m_bvalid(m_bvalid),   .m_bready(m_bready),   .m_bid({2*XIDW{1'b0}}), .m_bresp(m_bresp),
      .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid),
      .m_rvalid(m_rvalid),   .m_rready(m_rready),   .m_rid({2*XIDW{1'b0}}), .m_rdata(m_rdata),
      .m_rresp(m_rresp)
  );

  // -- slave 0: emri_axi_adapter + emri_regfile (BMC mode) ----------------
  logic        host_req, host_we, host_ready;
  logic [1:0]  host_op;
  logic [15:0] host_addr;
  logic [31:0] host_wdata, host_rdata;

  emri_axi_adapter #(
      .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .REG_BASE(32'h4000_2000), .WIN_WORDS(96)
  ) u_emri_adapter (
      .clk_i(clk), .rst_ni(rst_n),
      .s_axi_awvalid(m_awvalid[0]), .s_axi_awready(m_awready[0]),
      .s_axi_awaddr(m_awaddr[0*AXI_AW +: AXI_AW]), .s_axi_awprot(3'b000),
      .s_axi_wvalid(m_wvalid[0]),   .s_axi_wready(m_wready[0]),
      .s_axi_wdata(m_wdata[0*AXI_DW +: AXI_DW]),  .s_axi_wstrb(m_wstrb[0*4 +: 4]),
      .s_axi_bvalid(m_bvalid[0]),   .s_axi_bready(m_bready[0]),
      .s_axi_bresp(m_bresp[0*2 +: 2]),
      .s_axi_arvalid(m_arvalid[0]), .s_axi_arready(m_arready[0]),
      .s_axi_araddr(m_araddr[0*AXI_AW +: AXI_AW]), .s_axi_arprot(3'b000),
      .s_axi_rvalid(m_rvalid[0]),   .s_axi_rready(m_rready[0]),
      .s_axi_rdata(m_rdata[0*AXI_DW +: AXI_DW]),  .s_axi_rresp(m_rresp[0*2 +: 2]),
      .host_req_o(host_req),     .host_we_o(host_we),   .host_op_o(host_op),
      .host_addr_o(host_addr),   .host_wdata_o(host_wdata),
      .host_rdata_i(host_rdata), .host_ready_i(host_ready)
  );

  // OCC side tied off: this demo never touches the OCC (the adapter window
  // only carries EFP staging + event-ring traffic; same tie-off as tb_bmc_fw).
  logic [31:0] occ_expect_crc_w;   // v0.5 §3.1.1 (OCC expected-CRC gate)
  logic [31:0] occ_crc_result_w;   // v0.5 §3.1.1 (OCC running CRC)
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
      .occ_status_i(3'd0), .occ_crc_error_i(1'b0), .occ_region_locks_o(), .occ_global_lock_o(),
      .dec_start_o(), .dec_col_o(), .dec_busy_i(1'b0),
      .occ_expect_crc_o(),
      .occ_crc_result_i(32'h0)
  );

  // -- slave 1: tb_fwflash — non-volatile "external SPI flash" stand-in ---
  tb_fwflash #(.BASE(32'h4001_0000), .WORDS(128)) u_fwflash (
      .clk_i(clk), .rst_ni(rst_n),
      .s_axi_awvalid(m_awvalid[1]), .s_axi_awready(m_awready[1]),
      .s_axi_awaddr(m_awaddr[1*AXI_AW +: AXI_AW]),
      .s_axi_wvalid(m_wvalid[1]),   .s_axi_wready(m_wready[1]),
      .s_axi_wdata(m_wdata[1*AXI_DW +: AXI_DW]), .s_axi_wstrb(m_wstrb[1*4 +: 4]),
      .s_axi_bvalid(m_bvalid[1]),   .s_axi_bready(m_bready[1]),
      .s_axi_bresp(m_bresp[1*2 +: 2]),
      .s_axi_arvalid(m_arvalid[1]), .s_axi_arready(m_arready[1]),
      .s_axi_araddr(m_araddr[1*AXI_AW +: AXI_AW]),
      .s_axi_rvalid(m_rvalid[1]),   .s_axi_rready(m_rready[1]),
      .s_axi_rdata(m_rdata[1*AXI_DW +: AXI_DW]), .s_axi_rresp(m_rresp[1*2 +: 2])
  );

  // -- Clock -----------------------------------------------------------------
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS / 2) clk = ~clk;

  // -- Firmware preload (DMEM-exec bootstrap; same backdoor as tb_bmc_fw) --
  initial begin
      // #1: defer past the netlist's own time-0 IMEM ROM fill (it would
      // otherwise clobber the preload; the core is still in reset).
      #1;
      $readmemh("generated/bmc/fwupdate_boot.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_imem_enabled_neorv32_imem_inst
                .imem_rom_imem_rom_inst.n7280);
      $readmemh("generated/bmc/fwupdate_dmem_lane0.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[0]_ram_inst .spram);
      $readmemh("generated/bmc/fwupdate_dmem_lane1.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[1]_ram_inst .spram);
      $readmemh("generated/bmc/fwupdate_dmem_lane2.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[2]_ram_inst .spram);
      $readmemh("generated/bmc/fwupdate_dmem_lane3.hex", dut.u_core.neorv32_top_inst
                .memory_system_neorv32_dmem_enabled_neorv32_dmem_inst
                .dmem_ram_inst.\ram_gen[3]_ram_inst .spram);
  end

  // ============================================================================
  // Slot payload images (built by `make -C ethereal-runtime/bmc-fw slots`)
  // ============================================================================
  logic [31:0] slot_v1 [0:PAYLOAD_WORD-1];
  logic [31:0] slot_v2 [0:PAYLOAD_WORD-1];
  initial begin
      $readmemh("generated/bmc/slot_v1.hex", slot_v1);
      $readmemh("generated/bmc/slot_v2.hex", slot_v2);
  end

  // CRC32 (identical to occ_top / fwupdate.c: poly 0x04C11DB7, init
  // 0xFFFFFFFF, MSB-byte-first per word, no final xor).
  function automatic logic [31:0] crc32_word(input logic [31:0] crc,
                                             input logic [31:0] w);
      logic [31:0] c;
      logic [7:0]  b;
      begin
          c = crc;
          for (int by = 0; by < 4; by++) begin
              b = w[31:24];
              c = c ^ {b, 24'h0};
              for (int bit_i = 0; bit_i < 8; bit_i++) begin
                  if (c[31]) c = (c << 1) ^ 32'h04C1_1DB7;
                  else       c = (c << 1);
              end
              w = w << 8;
          end
          return c;
      end
  endfunction

  function automatic logic [31:0] crc32_payload(input logic [31:0] p [0:PAYLOAD_WORD-1]);
      logic [31:0] c;
      begin
          c = 32'hFFFF_FFFF;
          for (int i = 0; i < PAYLOAD_WORD; i++) c = crc32_word(c, p[i]);
          return c;
      end
  endfunction

  // ============================================================================
  // Concurrent UART 8N1 receiver (idle-high, start bit low, LSB first)
  // ============================================================================
  localparam int MAXB = 4096;
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

  task automatic wait_uart_contains(input string s, input string tag);
      integer to, base, j;
      logic found, m;
      begin
          to = 0;
          found = 1'b0;
          while (!found && to < 2000000) begin
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
                  #(1000);
                  to = to + 1;
              end
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

  // Stage a fw_update image (spec sec 3.6 step 1): payload words into
  // IMG_SIG[0..15], CRC32 trailer into IMG_DIGEST[0], count into
  // EFP_IMG_WORDS, version into EFP_IMG_COLS, target slot into EFP_REGION.
  task automatic host_stage_update(input logic [31:0] p [0:PAYLOAD_WORD-1],
                                   input logic [31:0] trailer,
                                   input logic [31:0] ver,
                                   input logic [31:0] slot);
      integer k;
      begin
          for (k = 0; k < PAYLOAD_WORD; k = k + 1)
              host_wr(R_IMG_SIG + 16'(k), p[k]);
          host_wr(R_IMG_DIGEST, trailer);
          host_wr(R_EFP_IMG_WORDS, 32'(PAYLOAD_WORD));
          host_wr(R_EFP_IMG_COLS, ver);
          host_wr(R_EFP_REGION, slot);
      end
  endtask

  // ============================================================================
  // Test sequence (spec sec 3.6)
  // ============================================================================
  logic [31:0] rd;
  logic [31:0] crc1, crc2;

  initial begin : main_seq
      // idle the host BFM + UART RX
      h_awvalid = 1'b0; h_awaddr = 32'h0;
      h_wvalid  = 1'b0; h_wdata  = 32'h0;
      h_bready  = 1'b0;
      h_arvalid = 1'b0; h_araddr = 32'h0;
      h_rready  = 1'b0;
      uart0_rxd = 1'b1;

      // ---- flash image: slot A active (v1), slot B empty -----------------
      crc1 = crc32_payload(slot_v1);
      crc2 = crc32_payload(slot_v2);
      for (int i = 0; i < PAYLOAD_WORD; i++)
          u_fwflash.mem[0*SLOT_WORDS + HDR_WORDS + i] = slot_v1[i];
      u_fwflash.mem[0*SLOT_WORDS + 0] = FW_MAGIC;
      u_fwflash.mem[0*SLOT_WORDS + 1] = 32'd1;              // version
      u_fwflash.mem[0*SLOT_WORDS + 2] = 32'(PAYLOAD_WORD);  // len
      u_fwflash.mem[0*SLOT_WORDS + 3] = crc1;
      u_fwflash.mem[0*SLOT_WORDS + 4] = 32'd1;              // ACTIVE
      for (int i = 0; i < SLOT_WORDS; i++)
          u_fwflash.mem[1*SLOT_WORDS + i] = 32'h0;          // no image

      rst_n = 1'b0;
      repeat (20) @(posedge clk);
      rst_n = 1'b1;

      // ---- 1. boot: slot A v1 (active flag), CRC ok, payload runs --------
      $display("[1] boot slot A (v1) — XIP payload prints its digit");
      wait_uart_contains("bmc-fw fwupdate demo boot\n", "boot banner");
      wait_uart_contains("boot: slot A v1 crc ok\n", "slot A selected + CRC ok");
      wait_uart_contains("payload: 1\n", "slot A payload ran (compiled-in v1 digit)");

      // ---- 2. fw_update to slot B (v2) over the EFP staging regs --------
      $display("[2] fw_update -> slot B (v2)");
      host_stage_update(slot_v2, crc2, 32'd2, 32'd1);
      host_wr(R_EFP_CMD, {24'h0, EFP_CMD_FWUPDATE});
      wait_uart_contains("fw: update slot B v2\n", "fwupdate accepted (staging echoed)");
      wait_uart_contains("fw: crc ok\n", "staged image CRC32 verified");
      wait_uart_contains("fw: slot B active, reboot\n", "slot B written + marked active");
      wait_uart_contains("boot: slot B v2 crc ok\n", "re-boot selected slot B");
      wait_uart_contains("payload: 2\n", "slot B payload ran (v2 digit — new code)");
      host_rd(R_EFP_ERR, rd);
      chk(rd[7:0] == EFP_ERR_NONE, "EFP_ERR = none after update+reboot");
      chk(u_fwflash.mem[1*SLOT_WORDS + 4] == 32'd1, "flash: slot B flags.active=1");
      chk(u_fwflash.mem[0*SLOT_WORDS + 4] == 32'd0, "flash: slot A flags.active=0");
      chk(u_fwflash.mem[1*SLOT_WORDS + 3] == crc2, "flash: slot B header CRC matches");

      // ---- 3. negative: tampered CRC trailer -> EFP_ERR=10, no write ----
      $display("[3] fw_update with TAMPERED CRC trailer");
      host_stage_update(slot_v1, crc1 ^ 32'h0000_0001, 32'd1, 32'd0);
      host_wr(R_EFP_CMD, {24'h0, EFP_CMD_FWUPDATE});
      wait_uart_contains("fw: update slot A v1\n", "tampered update accepted for staging");
      wait_uart_contains("fw: crc BAD (no flash write)\n", "CRC mismatch detected");
      host_rd(R_EFP_ERR, rd);
      chk(rd[7:0] == EFP_ERR_FWUPDATE, "EFP_ERR = fwupdate (10)");
      chk(u_fwflash.mem[0*SLOT_WORDS + 3] == crc1, "flash: slot A header untouched");
      chk(u_fwflash.mem[0*SLOT_WORDS + 4] == 32'd0, "flash: slot A stays inactive");
      // (B still active + running)
      chk(u_fwflash.mem[1*SLOT_WORDS + 4] == 32'd1, "flash: slot B still active");

      // ---- 4. corrupt slot B payload; reboot -> CRC FAIL -> fallback A ---
      $display("[4] corrupt slot B payload, reboot -> fallback to slot A");
      u_fwflash.mem[1*SLOT_WORDS + HDR_WORDS + 2] ^= 32'h55AA_0000;
      host_wr(R_EFP_CMD, {24'h0, EFP_CMD_REBOOT});
      wait_uart_contains("fw: reboot\n", "reboot doorbell accepted");
      wait_uart_contains("boot: slot B v2 crc FAIL\n", "corrupted active slot detected");
      wait_uart_contains("boot: fallback to last-known-good\n", "fallback path taken");
      wait_uart_contains("payload: 1\n", "slot A payload runs again (fallback)");
      // SYNC on the 4th event push (the fallback boot's CRC takes ~50 us of
      // sim after the fallback print; the UART lines above are ambiguous
      // under containment matching, the ring count is not).
      begin
          integer to2;
          to2 = 0;
          host_rd(R_EVT_LOG_CTRL, rd);
          while (rd[15:0] < 16'd4 && to2 < 200000) begin
              #(1000);
              host_rd(R_EVT_LOG_CTRL, rd);
              to2 = to2 + 1;
          end
          chk(rd[15:0] == 16'd4, "fallback boot completed (event #4 pushed)");
      end

      // ---- 5. event ring (sec 3.4): 4 slot_change entries, stamps ascend -
      $display("[5] event ring drain");
      host_rd(R_EVT_LOG_CTRL, rd);
      chk(rd[15:0] == 16'd4, "EVT ring count = 4 (A, B-update, B-boot, A-fallback)");
      host_rd(R_EVT_LOG_DATA, rd);
      chk(rd[7:0] == EVT_CODE_SLOT_CHANGE && rd[15:8] == 8'd0 && rd[31:16] == 16'd1,
          "event[0] = slot_change slot A stamp 1");
      host_rd(R_EVT_LOG_DATA, rd);
      chk(rd[7:0] == EVT_CODE_SLOT_CHANGE && rd[15:8] == 8'd1 && rd[31:16] == 16'd2,
          "event[1] = slot_change slot B stamp 2");
      host_rd(R_EVT_LOG_DATA, rd);
      chk(rd[15:8] == 8'd1 && rd[31:16] == 16'd3, "event[2] = slot B stamp 3");
      host_rd(R_EVT_LOG_DATA, rd);
      chk(rd[15:8] == 8'd0 && rd[31:16] == 16'd4, "event[3] = slot A stamp 4");
      host_rd(R_EVT_LOG_CTRL, rd);
      chk(rd[15:0] == 16'd0, "EVT ring drained (count=0)");
      host_wr(R_EVT_LOG_CTRL, 32'h0001_0000);
      host_rd(R_EVT_LOG_CTRL, rd);
      chk(rd == 32'h0, "EVT W1C clear (write-1-to-bit16)");

      // ---- report ---------------------------------------------------------
      if (errors == 0)
          $display("TEST PASSED: E1-BMC2 fwupdate — boot A(v1) -> update B(v2) -> reboot into B -> corrupt B -> fallback A; CRC gate; event ring");
      else
          $display("TEST FAILED: %0d errors", errors);
      $finish;
  end

  // -- Watchdog -------------------------------------------------------------------
  initial begin
      repeat (10) #(1000000000);   // 10 s hard cap (no Ed25519 here)
      $display("TEST FAILED: watchdog timeout (rxn=%0d errors=%0d)", rxn, errors);
      $finish;
  end

endmodule

// ============================================================================
// tb_fwflash — TB-local "external SPI flash" stand-in (SIM MODEL, not RTL):
// an AXI4-Lite slave serving a 128-word word array. The storage has NO
// reset clear (non-volatile across the TB reset pulse — the whole point of
// a flash stand-in); the TB preloads/corrupts it hierarchically
// (u_fwflash.mem[...]) while the CPU is quiescent. Single-outstanding
// transactions, classic single transfers (matches wb2axi + the host BFM).
// ============================================================================
module tb_fwflash #(
    parameter logic [31:0] BASE = 32'h4001_0000,
    parameter int          WORDS = 128
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    output logic [1:0]  s_axi_bresp,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    input  logic [31:0] s_axi_araddr,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp
);
    // Non-volatile storage (deliberately NO reset clear).
    logic [31:0] mem [0:WORDS-1];

    typedef enum logic [1:0] { S_IDLE = 2'd0, S_WRB = 2'd1, S_RD = 2'd2 } st_e;
    st_e st;
    logic [31:0] raddr_q;

    assign s_axi_awready = (st == S_IDLE) && s_axi_awvalid && s_axi_wvalid;
    assign s_axi_wready  = s_axi_awready;
    assign s_axi_arready = (st == S_IDLE) && s_axi_arvalid &&
                           !(s_axi_awvalid && s_axi_wvalid);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            st           <= S_IDLE;
            raddr_q      <= 32'h0;
            s_axi_bvalid <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 32'h0;
        end else begin
            s_axi_bvalid <= 1'b0;   // default: pulse unless held below
            s_axi_rvalid <= 1'b0;
            case (st)
                S_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // apply the (masked) write ONCE, at accept time
                        for (int b = 0; b < 4; b++) begin
                            if (s_axi_wstrb[b]) begin
                                mem[(s_axi_awaddr - BASE) >> 2][b*8 +: 8] <=
                                    s_axi_wdata[b*8 +: 8];
                            end
                        end
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00;  // OKAY
                        st <= S_WRB;
                    end else if (s_axi_arvalid) begin
                        raddr_q <= s_axi_araddr;
                        st      <= S_RD;
                    end
                end
                S_WRB: begin
                    s_axi_bvalid <= 1'b1;  // hold B until bready
                    if (s_axi_bready) st <= S_IDLE;
                end
                S_RD: begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rdata  <= mem[(raddr_q - BASE) >> 2];
                    s_axi_rresp  <= 2'b00;  // OKAY
                    if (s_axi_rready) st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
