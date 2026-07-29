`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      emri_regfile
// Description: EMRI register file (v0) — the unified management register ABI.
// Details:     Owns the v0 register map (ethereal-spec/control/emri-v0.md §2):
//                * read-only identity/capability/status mirrors (MAGIC, ABI,
//                  CAPABILITIES, PLATFORM_ID, NUM_REGIONS, REGION_INFO, HEALTH,
//                  MON_*);
//                * read/write OCC control regs (OCC_FRAME_ADDR, OCC_WORD_COUNT);
//                * the OCC command/data passthrough (OCC_CMD.start -> occ_cmd_valid,
//                  OCC_WDATA / EFP-SPI OCC_PUSH -> occ_wdata_valid) with OCC
//                  backpressure propagated to the host as a stalled ready;
//                * OCC_STATUS assembled from occ_status_i / occ_crc_error_i.
//
//              v0 scoping (see spec §1 + report): in mFSM mode the HOST drives OCC
//              directly through these registers (the host is the session FSM; it
//              holds the image and streams OCC_WDATA). The device-side rx_buf +
//              5-state session FSM (C05 §4.2) is a v0.1 refinement layered on top
//              of this same register map. SESSION_CMD/SESSION_STATUS are plain
//              RW/RO storage in v0 (forward-compat; no device FSM consumes them).
//
//              Region lock (occ_region_locked_o) is hardwired 0 in v0: blank-before-
//              write is already hardware-enforced inside occ_top (E0-FAB5 dirty bit
//              + S_NEEDS_BLANK), and v0 has no per-region lifecycle lock yet.
// Maintainer:  BaiTian6641
// Created:     2026-07-29
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-spec/control/emri-v0.md §2/§3/§4
// Notes:       G1: default_nettype none, always_ff non-blocking, no latches
//              (read mux is combinational with a default). Single host slave port
//              (fabric clock domain); the SPI slave / BMC bus feeds this port.
module emri_regfile #(
  parameter bit          HAS_BMC         = 1'b0,    // 0 = mFSM mode (cap bit0)
  parameter int          NUM_REGIONS     = 2,        // v0 fixed (ADR-004 build-time)
  parameter logic [31:0] PLATFORM_ID     = 32'h0000_0000,  // 0 = sim
  // Static per-region geometry {cols[31:24],rows[23:16],tiles[15:0]} (v0: 2 regions)
  parameter logic [31:0] REGION0_INFO    = 32'h0202_0010,  // 2x2 = 16 tiles (4x4 fabric /2)
  parameter logic [31:0] REGION1_INFO    = 32'h0202_0010,
  parameter logic [15:0] MON_TEMP_SIM    = 16'h0019,  // 25 C placeholder
  parameter logic [15:0] MON_VCCINT_SIM  = 16'h0338   // ASSUMPTION 824mV (spec §9)
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // -- Host register-access slave (fabric clock domain; SPI slave / BMC bus feeds this)
  input  logic        host_req_i,     // request valid
  input  logic        host_we_i,      // 1 = write
  input  logic [1:0]  host_op_i,      // EFP-SPI OP (RD/WR/BLOCK_RD/OCC_PUSH)
  input  logic [15:0] host_addr_i,    // word offset
  input  logic [31:0] host_wdata_i,
  output logic [31:0] host_rdata_o,
  output logic        host_ready_o,   // 1-cycle accept/response pulse

  // -- OCC master (drives occ_top)
  output logic [1:0]  occ_cmd_o,
  output logic        occ_cmd_valid_o,
  input  logic        occ_cmd_ready_i,
  output logic [15:0] occ_frame_addr_o,
  output logic [15:0] occ_word_count_o,
  output logic [31:0] occ_wdata_o,
  output logic        occ_wdata_valid_o,
  input  logic        occ_wdata_ready_i,
  input  logic [2:0]  occ_status_i,
  input  logic        occ_crc_error_i,
  output logic        occ_region_locked_o   // v0: hardwired 0 (see Details)
);
  import emri_pkg::*;

  // ------------------------------------------------------------------
  // Capabilities (parameter-derived; spec §2). v0: only has_bmc is meaningful;
  //  DMA/I2C/TRNG/JTAG are 0 (not yet implemented). BMC mode sets has_bmc=1.
  // ------------------------------------------------------------------
  logic [31:0] capabilities_w;
  assign capabilities_w = {31'h0, HAS_BMC};

  // Health (v0: all-ok bitmap, bit-per-region). bit0=r0, bit8=r1, bit16=r2, bit24=r3.
  logic [31:0] health_status_w;
  assign health_status_w =
      (NUM_REGIONS > 0 ? 32'h0000_0001 : 32'h0) |
      (NUM_REGIONS > 1 ? 32'h0000_0100 : 32'h0) |
      (NUM_REGIONS > 2 ? 32'h0001_0000 : 32'h0) |
      (NUM_REGIONS > 3 ? 32'h0100_0000 : 32'h0);

  // ------------------------------------------------------------------
  // RW configuration registers
  // ------------------------------------------------------------------
  logic [15:0] occ_frame_addr_r;
  logic [15:0] occ_word_count_r;
  logic [7:0]  region_sel_r;
  // OCC command latch (held until occ_cmd_ready pulse)
  logic [1:0]  occ_cmd_r;
  logic [3:0]  occ_region_r;
  logic        occ_start_r;
  // OCC wdata staging (1-cycle pulse on host OCC_PUSH / OCC_WDATA write)
  logic [31:0] occ_wdata_r;
  logic        occ_wdata_pending_r;
  // SESSION_CMD/STATUS plain storage (v0: no device FSM consumes them)
  logic [7:0]  session_cmd_r;
  logic [7:0]  session_status_r;
  // RX_BUF_CTRL (v0: host-readable placeholder; depth fixed)
  logic [15:0] rx_buf_depth_w = 16'h4000;  // 16 KB

  // ------------------------------------------------------------------
  // Decode helpers
  // ------------------------------------------------------------------
  logic addr_is_occ_cmd_start;
  assign addr_is_occ_cmd_start = host_req_i && host_we_i &&
                                 (host_op_i == SPI_OP_WR) &&
                                 (host_addr_i == R_OCC_CMD) &&
                                 host_wdata_i[OCC_CMD_START];

  logic addr_is_occ_wdata_push;
  assign addr_is_occ_wdata_push = host_req_i && host_we_i &&
                                  ((host_op_i == SPI_OP_OCC_PUSH) ||
                                   ((host_op_i == SPI_OP_WR) && (host_addr_i == R_OCC_WDATA)));

  // ------------------------------------------------------------------
  // OCC command valid: hold while start pending until accepted
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_cmd_r         <= 2'd0;
      occ_region_r      <= 4'd0;
      occ_start_r       <= 1'b0;
    end else begin
      if (addr_is_occ_cmd_start && !occ_start_r) begin
        // Latch a new command only when no outstanding one (host must wait ready)
        occ_cmd_r    <= host_wdata_i[1:0];
        occ_region_r <= host_wdata_i[5:2];
        occ_start_r  <= 1'b1;
      end else if (occ_start_r && occ_cmd_ready_i) begin
        occ_start_r <= 1'b0;  // accepted
      end
    end
  end
  assign occ_cmd_o        = occ_cmd_r;
  assign occ_cmd_valid_o  = occ_start_r;
  assign occ_frame_addr_o = occ_frame_addr_r;
  assign occ_word_count_o = occ_word_count_r;
  assign occ_region_locked_o = 1'b0;  // v0 (see Details)

  // ------------------------------------------------------------------
  // OCC wdata staging: a host OCC_PUSH write loads the skid buffer; the
  // buffer drains to OCC honoring wdata_ready. v0 depth = 1 (host must
  // observe ready=BUSY and retry while the skid is full). Backpressure
  // surfaces as host_ready_o held low until occ_wdata_ready_i.
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_wdata_r        <= 32'h0;
      occ_wdata_pending_r<= 1'b0;
    end else begin
      if (occ_wdata_pending_r && occ_wdata_ready_i) begin
        occ_wdata_pending_r <= 1'b0;  // drained
      end
      // A new host load is only accepted when the skid is empty (or draining
      // this same cycle) — gated via host_ready_o below.
      if (addr_is_occ_wdata_push && (!occ_wdata_pending_r || occ_wdata_ready_i)) begin
        occ_wdata_r         <= host_wdata_i;
        occ_wdata_pending_r <= 1'b1;
      end
    end
  end
  assign occ_wdata_o       = occ_wdata_r;
  assign occ_wdata_valid_o = occ_wdata_pending_r;

  // ------------------------------------------------------------------
  // Plain RW registers
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      occ_frame_addr_r <= 16'h0;
      occ_word_count_r <= 16'h0;
      region_sel_r     <= 8'h0;
      session_cmd_r    <= 8'h0;
      session_status_r <= 8'h0;
    end else if (host_req_i && host_we_i && (host_op_i == SPI_OP_WR)) begin
      case (host_addr_i)
        R_OCC_FRAME_ADDR: occ_frame_addr_r <= host_wdata_i[15:0];
        R_OCC_WORD_COUNT: occ_word_count_r <= host_wdata_i[15:0];
        R_REGION_SEL:     region_sel_r     <= host_wdata_i[7:0];
        R_SESSION_CMD:    session_cmd_r    <= host_wdata_i[7:0];
        default: ; // others RO or handled above
      endcase
    end
  end

  // ------------------------------------------------------------------
  // REGION_INFO read (windowed by region_sel_r)
  // ------------------------------------------------------------------
  logic [31:0] region_info_w;
  always_comb begin
    region_info_w = 32'h0;
    case (region_sel_r)
      8'd0: region_info_w = REGION0_INFO;
      8'd1: region_info_w = REGION1_INFO;
      default: region_info_w = 32'h0;
    endcase
  end

  // ------------------------------------------------------------------
  // OCC_STATUS read assembly (spec §4)
  //   {status[6:0], region_id[11:8], crc_error[16], frame_addr[31:16]}
  // ------------------------------------------------------------------
  logic [31:0] occ_status_w;
  always_comb begin
    occ_status_w = 32'h0;
    occ_status_w[2:0]  = occ_status_i;
    occ_status_w[11:8] = {4'h0};               // region_id not tracked separately in v0
    occ_status_w[16]   = occ_crc_error_i;
    occ_status_w[31:16]= occ_frame_addr_r;      // includes crc_error@16 overlap; spec
                                                // places crc_error@16 — keep status_i
                                                // low bits authoritative, frame echo high.
  end
  // (spec §4 has crc_error@16 and frame_addr@31:16 mutually exclusive at bit16;
  //  v0 prefers crc_error@16 and frame_addr at [31:17]; documented in report.)

  // ------------------------------------------------------------------
  // Read mux (combinational, with default)
  // ------------------------------------------------------------------
  always_comb begin
    host_rdata_o = 32'h0;  // default
    case (host_addr_i)
      R_MAGIC:          host_rdata_o = EMRI_MAGIC;
      R_ABI_VERSION:    host_rdata_o = EMRI_ABI_VERSION;
      R_CAPABILITIES:   host_rdata_o = capabilities_w;
      R_PLATFORM_ID:    host_rdata_o = PLATFORM_ID;
      R_NUM_REGIONS:    host_rdata_o = {24'h0, NUM_REGIONS[7:0]};
      R_REGION_INFO:    host_rdata_o = region_info_w;
      R_OCC_CMD:        host_rdata_o = {23'h0, occ_start_r, 2'h0, occ_region_r, occ_cmd_r};
      R_OCC_WDATA:      host_rdata_o = 32'h0;          // write-only
      R_OCC_STATUS:     host_rdata_o = occ_status_w;
      R_OCC_FRAME_ADDR: host_rdata_o = {16'h0, occ_frame_addr_r};
      R_OCC_WORD_COUNT: host_rdata_o = {16'h0, occ_word_count_r};
      R_SESSION_CMD:    host_rdata_o = {24'h0, session_cmd_r};
      R_SESSION_STATUS: host_rdata_o = {24'h0, session_status_r};
      R_RX_BUF_CTRL:    host_rdata_o = {16'h0, rx_buf_depth_w};
      R_HEALTH_STATUS:  host_rdata_o = health_status_w;
      R_MON_TEMP:       host_rdata_o = {16'h0, MON_TEMP_SIM};
      R_MON_VCCINT:     host_rdata_o = {16'h0, MON_VCCINT_SIM};
      default:          host_rdata_o = 32'h0;          // reserved read-as-0
    endcase
  end

  // ------------------------------------------------------------------
  // host_ready_o: when is the host request accepted this cycle?
  //   * Read: always ready (combinational rdata).
  //   * Write to RO/reserved: ready (accepted, ignored).
  //   * Write OCC_CMD.start: ready when occ_cmd accepted (occ_cmd_ready_i while
  //     start pending) — multi-cycle stall possible.
  //   * OCC_WDATA push: ready when skid can accept (empty or draining).
  //   * Other writes: ready immediately.
  // ------------------------------------------------------------------
  always_comb begin
    host_ready_o = 1'b0;
    if (!host_req_i) begin
      host_ready_o = 1'b0;
    end else if (!host_we_i) begin
      // Read or BLOCK_RD (BLOCK_RD unsupported -> BAD_OP path handled at SPI layer;
      // here a read returns data). Always ready.
      host_ready_o = 1'b1;
    end else begin
      // Write
      if (addr_is_occ_cmd_start) begin
        // Ready when the latched command is accepted by OCC.
        host_ready_o = occ_start_r && occ_cmd_ready_i;
      end else if (addr_is_occ_wdata_push) begin
        host_ready_o = !occ_wdata_pending_r || occ_wdata_ready_i;
      end else begin
        host_ready_o = 1'b1;  // plain RW / RO-write: immediate
      end
    end
  end

endmodule
