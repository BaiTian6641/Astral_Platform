`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_mmio_mux
// Description: D-port address decoder + MMIO peripheral set for the eth_rv SoC:
//              memory-mapped devices sit IN FRONT of the system memory port, so
//              the core keeps exactly one data port (C14 §4: "CLINT/PLIC — MMIO
//              经 D 端口地址译码") and every downstream path (the behavioral beat
//              memory of the v0 testbench, `eth_rv_axi_master` -> `eth_dram_ctrl`)
//              stays unchanged.
// Details:     SoC DATA MAP (RV-B bring-up, the ASSUMPTION of this slice):
//
//                0x0000_0000_8000_0000  system memory (DRAM socket / eth_dram_ctrl)
//                0x0000_0000_1000_0000  console UART (eth_rv_uart, 4 KiB page)
//                CLINT/PLIC             NOT IMPLEMENTED — deferred, see below
//
//              DECODE: an access is inside the console page when
//              `addr[63:12] == UART_BASE[63:12]` — the same 4 KiB granularity as
//              `ns16550_t::load/store` in Spike (`addr + len > PGSIZE`), so the
//              page boundary the golden model uses is the boundary here. Inside
//              the page the 16550 register file is the eight byte offsets
//              `addr[11:3] == 0` (`reg-shift = 0`, `reg-io-width = 1`), which is
//              what the peripheral decodes as `off_i = addr[2:0]`.
//
//              BEAT <-> BYTE ADAPTATION lives here, because that is the D port's
//              shape rather than the peripheral's: the core presents the 64-bit
//              aligned beat with the access address, and C14 §4 says the store
//              data sits at `dmem_wdata_o[8*lane +: 8]` for `lane = addr[2:0]`.
//              So a store hands the peripheral lane `addr[2:0]` of `wdata_i`, and
//              a load replicates the register byte across all eight lanes (the
//              core rotates the beat right by `addr[2:0]` and truncates, so the
//              addressed byte is what it sees).
//
//              WHY A MUX AND NOT A SECOND BUS: the core has one D port and its
//              request/ready contract is "held until accepted", which needs no
//              arbitration when the peripherals answer combinationally in a
//              single cycle. Gating `mem_req_o` with `!sel` also keeps device
//              addresses OUT of the memory path — under `ETH_RV_DRAM_AXI` an AXI
//              transaction to 0x1000_0000 would leave the DRAM socket's window
//              and be answered DECERR, so filtering at the decoder is what makes
//              the MMIO map work in both D-port builds.
//
//              Unimplemented register offsets inside the claimed page
//              (0x1000_0008..0x1000_0FFF) are deliberately NOT acknowledged: the
//              RV-B D port has no error response yet (`eth_rv_axi_master` records
//              a bus error on `axi_err_o` rather than raising an exception), so
//              the alternatives are a silent success the golden model would not
//              produce or a wedge. The wedge is chosen because the testbench's
//              cycle budget turns it into a hard FAIL with the faulting pc, and
//              because it can never turn into a trace that diverges from Spike
//              quietly. Same reasoning for a non-byte access to the register
//              file: Spike's ns16550 rejects `len != reg_io_width`, and until the
//              core can take an access fault the corpus is what keeps the two
//              sides equal — it uses byte accesses only (see verif/eth_rv/README.md).
//
//              CLINT (mtime/mtimecmp) IS DEFERRED, deliberately: Spike's CLINT
//              ticks `mtime` from its own instruction counter
//              (`INSNS_PER_RTC_TICK`), so any value a program reads back is a
//              function of the golden model's own progress and cannot be matched
//              by RTL that runs at a different cycle-per-retirement rate. A
//              CLINT therefore only becomes verifiable together with the
//              interrupt path it exists for (RV-C, per verif/eth_rv/README.md
//              "an interrupt stream is still ahead"), where a program either
//              masks the timer or arms `mtimecmp` from a fixed constant. Nothing
//              in RV-B's checkpoint 5 needs it.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 4: C14 §8 checkpoint 5 (UART hello)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (I/D ports, MMIO via D-port decode),
//              §6 (eth_axi / eth_dram_ctrl socket) · §8 checkpoint 5 ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §5 (SoC map)
// Notes:       Pure combinational decode and muxing — no state, no arbitration,
//              no clock-domain crossing; the peripheral inside it owns the only
//              state. `mem_*` is a straight pass-through of the core's request
//              (same values, same cycle) when the address is not a device, so
//              inserting this module cannot change the memory path's behavior.
module eth_rv_mmio_mux #(
    parameter logic [63:0] UART_BASE       = 64'h0000_0000_1000_0000,  // console page (Spike NS16550_BASE)
    parameter int unsigned UART_BIT_CYCLES = 16,                       // clk / baud (see eth_rv_uart)
    parameter int unsigned UART_FIFO_DEPTH = 64                        // transmit queue depth
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // ---- core D-port slave (64-bit aligned beat, held until ready) ----
    input  logic        req_i,
    input  logic        we_i,
    input  logic [63:0] addr_i,
    input  logic [63:0] wdata_i,
    input  logic [7:0]  wstrb_i,
    output logic        ready_o,
    output logic [63:0] rdata_o,

    // ---- system memory master (DRAM socket / behavioral memory) ----
    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [63:0] mem_addr_o,
    output logic [63:0] mem_wdata_o,
    output logic [7:0]  mem_wstrb_o,
    input  logic        mem_ready_i,
    input  logic [63:0] mem_rdata_i,

    // ---- console UART line + verification status ----
    output logic        uart_tx_o,
    output logic        uart_busy_o,
    output logic        uart_overflow_o
);

    logic       page_sel;   // access inside the UART page
    logic       reg_hit;    // ... and inside its byte register file
    logic [2:0] reg_off;
    logic       uart_sel;
    logic       uart_ready;
    logic [7:0] uart_rdata;

    assign page_sel = req_i && (addr_i[63:12] == UART_BASE[63:12]);
    assign reg_off  = addr_i[2:0];
    assign reg_hit  = (addr_i[11:3] == 9'd0);
    assign uart_sel = page_sel && reg_hit;

    assign ready_o = uart_sel ? uart_ready : mem_ready_i;
    assign rdata_o = uart_sel ? {8{uart_rdata}} : mem_rdata_i;

    // The memory path sees the core's request verbatim, except that a device
    // access never reaches it (see why in the header).
    assign mem_req_o   = req_i && !page_sel;
    assign mem_we_o    = we_i;
    assign mem_addr_o  = addr_i;
    assign mem_wdata_o = wdata_i;
    assign mem_wstrb_o = wstrb_i;

    eth_rv_uart #(
        .BIT_CYCLES (UART_BIT_CYCLES),
        .FIFO_DEPTH (UART_FIFO_DEPTH)
    ) u_uart (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .req_i        (uart_sel),
        .we_i         (we_i),
        .off_i        (reg_off),
        .wdata_i      (wdata_i[{reg_off, 3'b000} +: 8]),
        .ready_o      (uart_ready),
        .rdata_o      (uart_rdata),
        .uart_tx_o    (uart_tx_o),
        .tx_busy_o    (uart_busy_o),
        .tx_overflow_o(uart_overflow_o)
    );

endmodule
`default_nettype wire
