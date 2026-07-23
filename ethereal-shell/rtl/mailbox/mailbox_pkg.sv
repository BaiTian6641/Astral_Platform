`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Provenance: Migrated from github.com/BaiTian6641/TinyGPU-FPGA/ip/mailbox/mailbox_pkg.sv
//             (c) BaiTian6641. Re-licensed to CERN-OHL-S-2.0 per ethereal-plan/README.md §4 (2026-07).
//             Original repo license: not declared (no top-level LICENSE; these files carry no SPDX header).
//             Migration date: 2026-07-24. Task: S04-P0#1.
// Module:      mailbox_pkg (package)
// Plan-Ref:    ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md
// Notes:       Migrated verbatim (body unchanged). Package file (types/helpers); verilator --lint-only -Wall verification is PENDING (Docker-gated; no verilator in authoring env).
`timescale 1ns/1ps
// Package for mailbox interconnect common types and helpers
package mailbox_pkg;

  // ---------------------------------------------------------
  // AXI‑MailboxFabric (stream hybrid) types
  // ---------------------------------------------------------
  localparam int DATA_WIDTH    = 32;
  localparam int NODE_ID_WIDTH = 16; // Cluster[15:8] + Endpoint[7:4] + CSR[3:0]

  typedef struct packed {
    logic [NODE_ID_WIDTH-1:0] src_id; // Source node (for replies)
    logic [3:0]               opcode; // DATA/IRQ/ACK/ERROR
    logic [1:0]               prio;   // 0=low, 3=critical
    logic                     eop;    // End of packet
    logic                     debug;  // Trace hint
  } mailbox_header_t;

  typedef struct packed {
    mailbox_header_t          hdr;
    logic [DATA_WIDTH-1:0]    payload;
  } mailbox_flit_t;

  // Opcode enumeration
  typedef enum logic [3:0] {
    OPC_DATA = 4'h0,
    OPC_IRQ  = 4'h1,
    OPC_ACK  = 4'h2,
    OPC_NACK = 4'h3,
    OPC_RSV  = 4'hF
  } mailbox_opcode_e;

  // ---------------------------------------------------------
  // Legacy AXI4‑Lite mailbox tag (kept for backward compatibility)
  // ---------------------------------------------------------

  typedef struct packed {
    logic [7:0] src_id;    // Return address (Cluster[7:0])
    logic       eop;       // End of packet beat
    logic       prio;      // 1 = latency, 0 = best-effort
    logic [3:0] opcode;    // mailbox_opcode_e
    logic [3:0] hops;      // Saturating hop count (distance/age)
    logic       parity;    // Even parity over data|src_id|eop|prio (optional)
  } mailbox_tag_t;

  // Compute even parity when enabled
  function automatic logic compute_parity(
    input logic [31:0] data,
    input mailbox_tag_t tag_no_parity
  );
    mailbox_tag_t tag_zeroed;

    tag_zeroed = tag_no_parity;
    tag_zeroed.parity = 1'b0;

    compute_parity = ^{data, tag_zeroed};
  endfunction

endpackage : mailbox_pkg
