`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      ebi_pkg (package)
// Description: EBI (Ethereal Bus Interface) constants: the ADR-006 three-profile
//              selector and the EBI-Tiny address map (decoder constants).
// Details:     ADR-006 defines three EBI profiles; ADR-018 subsumes the top two
//              into the in-house AXI chain and keeps Tiny as the small-device
//              fallback ("EBI-Tiny stays as the small-device fallback (unchanged)"):
//                * EBI-Full -> the in-house AXI4 system fabric (eth_axi_*),
//                * EBI-Lite -> the mailbox NoC (mailbox_*), AXI-fronted,
//                * EBI-Tiny -> this package + `ebi_tiny` (simple 32-bit
//                  register bus, valid/ready, single master).
//
//              ADDRESS MAP (docs/Ethereal-平台实施蓝图-v2.md §4.2 "地址空间约定"):
//                0x0000_0000  Shell CSR        (EMRI register face; mFSM/BMC window)
//                0x0001_0000  OCC              (direct OCC CSR window)
//                0x0010_0000+ region windows   (one 64 KiB window per region)
//                0x0020_0000+ Service Tile     (ADR-009 service framing)
//                0x0030_0000+ IO proxies       (L2 protocol proxies, ADR-007)
//
//              The blueprint sketches bases only; it does NOT state window sizes
//              or a window-index encoding. This package fixes the two things a
//              decoder cannot do without: every window is one 64 KiB page (the
//              blueprint's own per-region granularity — "每 region 64KB"), and
//              the window index order is shell/occ/region0../service/io so the
//              slave fan-out index stays stable when NUM_REGIONS is re-parameterised.
//              // ASSUMPTION: 64 KiB window granularity + window index order
//              // (TBD, 2026-09-13) — RFC-002 (S04) will freeze the full map.
//
//              The Shell-CSR window offset is BYTE-addressed and the EMRI map is
//              WORD-addressed, so the EMRI endpoint consumes `offset[15:2]` as the
//              register word offset — the same conversion emri_axi_adapter does
//              over AXI (`host_addr_o = (addr - REG_BASE) >> 2`), which is what
//              makes an EBI-Tiny host and an AXI host see one register map.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Modified:    2026-09-13 - created (E0-SHL1 / E2-BMC1: EBI-Tiny + mFSM)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S04-EBI总线与Mailbox-NoC集成.md §2/§4,
//              docs/Ethereal-平台实施蓝图-v2.md §4.2 (Shell profile table + address map),
//              docs/adr/ADR-006 (3 profiles), docs/adr/ADR-018 ("EBI-Tiny stays
//              as the small-device fallback")
// Notes:       Single source of truth for the EBI-Tiny map; ebi_tiny.sv and the
//              golden model (ethereal-fabric/tests/ebi/ebi_tiny_model.py) are
//              cross-checked against these constants by the pytest suite.
package ebi_pkg;

  // ------------------------------------------------------------------
  // ADR-006 three-profile selector. Build-time: the profile is chosen by which
  // top-level is instantiated (Full/Lite = the AXI/mailbox chain, Tiny = ebi_tiny);
  // the enum exists so integration code and reports can name the choice.
  // ------------------------------------------------------------------
  typedef enum logic [1:0] {
    EBI_PROFILE_FULL = 2'd0,  // AXI4-Lite + own NoC (eth_axi_*)
    EBI_PROFILE_LITE = 2'd1,  // own NoC only (mailbox_*)
    EBI_PROFILE_TINY = 2'd2   // simple 32-bit register bus (ebi_tiny) — small devices
  } ebi_profile_e;

  // ------------------------------------------------------------------
  // Window geometry
  // ------------------------------------------------------------------
  localparam logic [31:0] EBI_WINDOW_BYTES = 32'h0001_0000;  // 64 KiB per window

  localparam logic [31:0] EBI_SHELL_CSR_BASE = 32'h0000_0000;
  localparam logic [31:0] EBI_OCC_BASE       = 32'h0001_0000;
  localparam logic [31:0] EBI_REGION_BASE    = 32'h0010_0000;  // + region * 64 KiB
  localparam logic [31:0] EBI_SERVICE_BASE   = 32'h0020_0000;
  localparam logic [31:0] EBI_IO_BASE        = 32'h0030_0000;

  // The region page field (addr[31:16] - EBI_REGION_BASE[31:16]) must stay below
  // the Service Tile base, i.e. the region window range is 0x0010..0x001F; a
  // larger NUM_REGIONS would collide with SERVICE_BASE, so the decoder treats a
  // region page >= NUM_REGIONS as UNIMPLEMENTED (error response, never a hang)
  // and this is the hard ceiling on NUM_REGIONS.
  localparam int EBI_MAX_REGIONS = 16;

  // ------------------------------------------------------------------
  // Window index order (index-aligned with ebi_tiny's slave fan-out ports:
  // win_ready_i[i] / win_err_i[i] / win_rdata_i[32*i +: 32]).
  //   shell_csr = 0, occ = 1, region0 .. region{NUM_REGIONS-1} = 2 ..,
  //   service = 2+NUM_REGIONS, io = 3+NUM_REGIONS
  //   => NUM_WINDOWS = 4 + NUM_REGIONS
  // ------------------------------------------------------------------
  localparam int EBI_WIN_SHELL_CSR = 0;
  localparam int EBI_WIN_OCC       = 1;
  localparam int EBI_WIN_REGION0   = 2;

  // ------------------------------------------------------------------
  // Shell-CSR window: the EMRI register face lives at WORD offset addr[15:2]
  // (emri_pkg owns the register map itself). That byte->word conversion is the
  // same `(addr - BASE) >> 2` emri_axi_adapter applies, so an EBI-Tiny host and
  // an AXI host reach one register map; it is a property of the endpoint
  // (mfsm_top), not of the window map, so there is no constant for it here.
  // ------------------------------------------------------------------

endpackage : ebi_pkg
`default_nettype wire
