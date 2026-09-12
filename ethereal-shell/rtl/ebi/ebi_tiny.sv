`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      ebi_tiny
// Description: EBI-Tiny — ADR-006's small-device profile: a simple 32-bit
//              register bus (single master, valid/ready) plus the address-map
//              decoder for the Shell CSR / OCC / region / Service Tile / IO
//              windows (docs/Ethereal-平台实施蓝图-v2.md §4.2).
// Details:     PROFILE. ADR-006: "EBI-Tiny（简易寄存器总线）"; ADR-018 keeps it as
//              the small-device fallback after the top two profiles were
//              subsumed by the in-house AXI chain. Small devices (Profile-E:
//              external MCU, GW5AT-15/GW2A class) run the Shell with no CPU and
//              no NoC, so their host link terminates in EBI-Tiny: one master
//              (the SPI front-end or the external MCU), a handful of register
//              windows, no arbitration, no bursts, no IDs.
//
//              TRANSACTION CONTRACT (identical to the EMRI host port shape, so
//              an EMRI endpoint can sit behind a window unchanged):
//                * the master drives req_i + payload and HOLDS them stable
//                  until ready_o is observed high;
//                * ready_o is high for exactly ONE cycle per transaction (the
//                  accept/response cycle) and rdata_o is valid in that cycle;
//                * after sampling ready_o the master MUST drop req_i (a bus
//                  that is not a function of req could otherwise look like a
//                  second transaction);
//                * err_o is valid with ready_o: the access was answered as an
//                  ERROR — either the address is inside no window, or it is a
//                  region page >= NUM_REGIONS (a window that does not exist),
//                  or the selected slave reported win_err_i.
//              Every request is answered in the cycle its selected slave can
//              accept it, so no address can wedge the master: a decoded window
//              whose slave is not ready simply HOLDS ready_o low until it is.
//
//              DECODE. One window = one 64 KiB page (ebi_pkg::EBI_WINDOW_BYTES).
//              The decoder publishes the selected window as an encoded index
//              (win_idx_o) rather than a one-hot fan-out, because the index is
//              exactly what indexes the slave response vectors
//              (win_rdata_i[32*win_idx_o +: 32]). Window index order is fixed by
//              ebi_pkg: shell_csr, occ, region0..region{N-1}, service, io.
//              Slaves see the INTRA-window byte offset (win_addr_o = addr[15:0]),
//              the verbatim write data/strobes and win_we_o; a slave that does
//              not implement a strobe/offset answers win_err_i and the error
//              propagates (the bus never silently drops a write).
//
//              TERMINATION: every window port MUST be terminated by the
//              integrator — an unimplemented window is terminated with
//              win_ready_i = 1, win_err_i = 1 (a defined error response), NOT
//              left dangling (which would hold ready_o low forever). This
//              module cannot detect a dangling window: that is a wiring
//              contract, stated here because it is the one way an EBI-Tiny
//              master can hang.
//
//              SLAVE COMMIT RULE: a window takes its side effect on
//              `win_valid_o && win_we_o && (win_idx_o == its_index) &&
//              win_ready_i[its_index] && !win_err_i[its_index]` — the strobes a
//              slave sees are NOT pre-qualified by its own ready, because the
//              request is held across stall cycles by design (that is what
//              hold-until-ready means), so `win_we_o` stays high for every cycle
//              of the hold. A slave that raises win_err_i must have taken NO side
//              effect (the error response reports that the access failed). Both
//              properties are exercised by tb_ebi_tiny's commit accounting.
//
//              No vendor primitives, no clocked state: the decoder is pure
//              combinational (ADR-017 / G1); the clocked elements of a Shell
//              live in the slaves (the EMRI register face, the OCC, ...).
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Modified:    2026-09-13 - created (E0-SHL1 / E2-BMC1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md §2
//              ("EBI-Tiny：小器件回退的简易 32 位寄存器总线（valid/ready，单主）"),
//              §4 phase table ("实现 EBI-Tiny（简易寄存器总线）+ 地址 decoder |
//              BFM 随机读写 10k 次一致"); docs/Ethereal-平台实施蓝图-v2.md §4.2
//              (address map); docs/adr/ADR-006 (profile), docs/adr/ADR-018
// Notes:       Verilator --lint-only -Wall clean; iverilog -g2012. Self-checking
//              BFM test: ethereal-fabric/tests/ebi/tb_ebi_tiny.sv. Golden model:
//              ethereal-fabric/tests/ebi/ebi_tiny_model.py.
module ebi_tiny #(
  // Number of region windows (blueprint: one 64 KiB window per region). Bounded
  // by ebi_pkg::EBI_MAX_REGIONS so the region range cannot collide with the
  // Service Tile base (0x0020_0000).
  parameter int NUM_REGIONS = 2,
  // Derived: the window count and the fan-out index width. These are parameters
  // (not body localparams) only because the slave-port widths need them while
  // elaborating the port list, which iverilog requires to be bound then; they are
  // NOT independent knobs — NUM_WINDOWS must equal 4 + NUM_REGIONS.
  parameter int NUM_WINDOWS = 4 + NUM_REGIONS,
  parameter int WIN_IDXW    = (NUM_WINDOWS > 1) ? $clog2(NUM_WINDOWS) : 1,
  // Window bases (defaults = the blueprint's map; overridable per board).
  parameter logic [31:0] SHELL_CSR_BASE = ebi_pkg::EBI_SHELL_CSR_BASE,
  parameter logic [31:0] OCC_BASE       = ebi_pkg::EBI_OCC_BASE,
  parameter logic [31:0] REGION_BASE    = ebi_pkg::EBI_REGION_BASE,
  parameter logic [31:0] SERVICE_BASE   = ebi_pkg::EBI_SERVICE_BASE,
  parameter logic [31:0] IO_BASE        = ebi_pkg::EBI_IO_BASE
) (
  // ---- single master (host / SPI front-end / external MCU) ----
  input  logic        req_i,        // transaction valid (held until ready_o)
  input  logic        we_i,         // 1 = write, 0 = read
  input  logic [31:0] addr_i,       // byte address
  input  logic [31:0] wdata_i,
  input  logic [3:0]  wstrb_i,      // byte strobes (forwarded verbatim)
  output logic [31:0] rdata_o,      // valid in the accept cycle
  output logic        ready_o,      // 1-cycle accept/response
  output logic        err_o,        // with ready_o: error response

  // ---- decoded window fan-out (index-aligned with the slave response inputs) ----
  output logic                win_valid_o,   // a window is selected this cycle
  output logic [WIN_IDXW-1:0] win_idx_o,     // selected window index
  output logic                win_we_o,      // write; only valid with win_valid_o
  output logic [15:0]         win_addr_o,    // intra-window byte offset
  output logic [31:0]         win_wdata_o,
  output logic [3:0]          win_wstrb_o,
  input  logic [NUM_WINDOWS*32-1:0] win_rdata_i,  // 32 bits per window
  input  logic [NUM_WINDOWS-1:0]    win_ready_i,  // slave can accept/answer now
  input  logic [NUM_WINDOWS-1:0]    win_err_i     // slave answers with an error
);

  // ------------------------------------------------------------------
  // Window layout: shell_csr, occ, region0..region{NUM_REGIONS-1}, service, io
  // ------------------------------------------------------------------
  // One window = one page of ebi_pkg::EBI_WINDOW_BYTES: the page field and the
  // intra-window offset split the address at WIN_ADDR_LSB (16 for 64 KiB, which
  // the [15:0] page/offset fields below require; the golden-model test asserts
  // the map invariant).
  localparam int WIN_ADDR_LSB = $clog2(ebi_pkg::EBI_WINDOW_BYTES);

  localparam logic [WIN_IDXW-1:0] WIN_SHELL_CSR_W = WIN_IDXW'(ebi_pkg::EBI_WIN_SHELL_CSR);
  localparam logic [WIN_IDXW-1:0] WIN_OCC_W       = WIN_IDXW'(ebi_pkg::EBI_WIN_OCC);
  localparam logic [WIN_IDXW-1:0] WIN_REGION0_W   = WIN_IDXW'(ebi_pkg::EBI_WIN_REGION0);
  localparam logic [WIN_IDXW-1:0] WIN_SERVICE_W   =
      WIN_SHELL_CSR_W + WIN_IDXW'(NUM_REGIONS + ebi_pkg::EBI_WIN_REGION0);
  localparam logic [WIN_IDXW-1:0] WIN_IO_W        = WIN_SERVICE_W + WIN_IDXW'(1);

  // Page fields (addr[31:16]) of the fixed windows.
  localparam logic [15:0] SHELL_CSR_PAGE_W = SHELL_CSR_BASE[31:16];
  localparam logic [15:0] OCC_PAGE_W       = OCC_BASE[31:16];
  localparam logic [15:0] REGION_PAGE_W    = REGION_BASE[31:16];
  localparam logic [15:0] SERVICE_PAGE_W   = SERVICE_BASE[31:16];
  localparam logic [15:0] IO_PAGE_W        = IO_BASE[31:16];
  // Region pages occupy [REGION_PAGE_W, REGION_PAGE_W + EBI_MAX_REGIONS).
  localparam logic [15:0] REGION_LIMIT_W   =
      REGION_PAGE_W + 16'(ebi_pkg::EBI_MAX_REGIONS);
  localparam logic [15:0] NUM_REGIONS_W    = 16'(NUM_REGIONS);

  // ------------------------------------------------------------------
  // Address decode (combinational, defaults first)
  //   The fixed windows are matched on their page; the region range is matched
  //   page-wise inside [REGION_BASE, REGION_BASE + EBI_MAX_REGIONS) and a page
  //   beyond NUM_REGIONS is an UNIMPLEMENTED window (error, not a hang).
  // ------------------------------------------------------------------
  logic                  dec_valid_w;   // address hits a window this cycle
  logic [WIN_IDXW-1:0]   dec_idx_w;     // ... and which one
  logic [15:0]           page_w;
  logic [15:0]           region_off_w;  // region page index within the range

  assign page_w       = addr_i[31:WIN_ADDR_LSB];
  assign region_off_w = page_w - REGION_PAGE_W;

  always_comb begin
    dec_valid_w = 1'b1;
    dec_idx_w   = WIN_SHELL_CSR_W;
    unique case (page_w)
      SHELL_CSR_PAGE_W: dec_idx_w = WIN_SHELL_CSR_W;
      OCC_PAGE_W:       dec_idx_w = WIN_OCC_W;
      SERVICE_PAGE_W:   dec_idx_w = WIN_SERVICE_W;
      IO_PAGE_W:        dec_idx_w = WIN_IO_W;
      default: begin
        if ((page_w >= REGION_PAGE_W) && (page_w < REGION_LIMIT_W)) begin
          // Inside the region page range: valid only for an existing region.
          if (region_off_w < NUM_REGIONS_W) begin
            dec_idx_w = WIN_REGION0_W + WIN_IDXW'(region_off_w);
          end else begin
            dec_valid_w = 1'b0;
          end
        end else begin
          dec_valid_w = 1'b0;
        end
      end
    endcase
  end

  // ------------------------------------------------------------------
  // Master-side response
  //   Undecoded addresses answer immediately with err (never a hang); decoded
  //   ones inherit the selected slave's ready/err. rdata is muxed by the
  //   window index (the same index the fan-out publishes).
  // ------------------------------------------------------------------
  logic sel_valid_w;   // a decoded, in-range window is being accessed
  assign sel_valid_w = req_i && dec_valid_w;

  assign ready_o = req_i && (dec_valid_w ? win_ready_i[dec_idx_w] : 1'b1);
  assign err_o   = req_i && ((!dec_valid_w) || win_err_i[dec_idx_w]);
  // An undecoded address reads as 0 with err set, so a master that ignores err
  // cannot mistake another window's word for the answer (dec_idx defaults to the
  // Shell CSR window when nothing matched).
  assign rdata_o = dec_valid_w ? win_rdata_i[dec_idx_w*32 +: 32] : 32'h0;

  // ------------------------------------------------------------------
  // Slave fan-out (only meaningful while a transaction is present)
  // ------------------------------------------------------------------
  assign win_valid_o = sel_valid_w;
  assign win_idx_o   = dec_idx_w;
  assign win_we_o    = sel_valid_w && we_i;
  assign win_addr_o  = addr_i[WIN_ADDR_LSB-1:0];
  assign win_wdata_o = wdata_i;
  assign win_wstrb_o = wstrb_i;

endmodule
`default_nettype wire
