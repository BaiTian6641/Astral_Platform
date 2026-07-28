// SPDX-License-Identifier: CERN-OHL-S-2.0
// File:        eth_config.svh
// Description: Inference-first per-target attribute layer (C13 §2.5).
// Details:     The ONLY place vendor-specific synthesis attributes live.
//              RTL writes the `` `ETH_DSPSTYLE `` / `` `ETH_RAMSTYLE `` macros
//              (which must expand to legal SystemVerilog everywhere, including
//              the GENERIC branch used for simulation). Define TARGET_GOWIN /
//              TARGET_XILINX / TARGET_INTEL on the synthesis command line (or
//              leave undefined for GENERIC / simulation).
// Maintainer:  BaiTian6641
// Created:     2026-07-28
// Plan-Ref:    ethereal-plan/components/C13-跨平台推断策略.md §2.5
`ifndef ETH_CONFIG_SVH
`define ETH_CONFIG_SVH

`ifdef TARGET_GOWIN
    // GowinSynthesis: object-level inference control (SUG550E §4.3).
    `define ETH_DSPSTYLE /* synthesis syn_dspstyle="dsp" */
    `define ETH_RAMSTYLE /* synthesis syn_ramstyle="block_ram" */
`elsif TARGET_XILINX
    // Vivado: use_dsp / ram_style object attributes (UG901).
    `define ETH_DSPSTYLE (* use_dsp = "yes" *)
    `define ETH_RAMSTYLE (* ram_style = "block" *)
`elsif TARGET_INTEL
    // Quartus: DSP block / RAM style attributes.
    `define ETH_DSPSTYLE (* use_dsp = "yes" *)
    `define ETH_RAMSTYLE (* ramstyle = "M20K" *)
`else
    // TARGET_GENERIC / VERILATOR: pure behavioral, no attributes.
    `define ETH_DSPSTYLE
    `define ETH_RAMSTYLE
`endif

`endif // ETH_CONFIG_SVH
