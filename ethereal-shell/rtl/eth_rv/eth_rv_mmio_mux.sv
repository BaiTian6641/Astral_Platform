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
//              the page the register is `addr[2:0]`: `reg_shift = 0` and
//              `reg_io_width = 1`, and Spike's device then does `addr >>= 0;
//              addr &= 7`, so EVERY page offset aliases onto one of the eight
//              byte registers (0x1000_0010 is the RX/THR register, 0x1000_0FFF
//              the scratch register). This implementation aliases identically —
//              not because aliasing is desirable but because the golden model is
//              what the DiffTest compares against, and a program that read or
//              wrote an "unimplemented" page offset has to behave the same on
//              both sides.
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
//              ERROR RESPONSE (E2-RV1 increment 5): the ONE thing Spike's
//              ns16550 rejects inside its page is a width it does not serve —
//              `load`/`store` return false when `reg_io_width != len`, i.e. for
//              any access larger than one byte, and `bus_t::find_device` +
//              `mmu_t` then raise `trap_{load,store}_access_fault` with `mtval` =
//              the access address. This decoder mirrors exactly that: a
//              non-byte access to the page (the core reports the width on
//              `size_i`) is answered with `ready_o = err_o = 1` — the access
//              completes AS AN ERROR — and the core turns it into the
//              architectural access fault. The page-crossing case Spike also
//              rejects (`addr + len > PGSIZE`) cannot be reached with a width of
//              1, so the width check subsumes it.
//
//              The same contract applies to the memory path: `mem_err_i` from
//              whatever answers the system memory (the v0 testbench's window
//              check, or the DRAM socket's DECERR through `eth_rv_axi_master`) is
//              forwarded as this port's `err_o`, so an address no region claims
//              surfaces as an access fault rather than as zeros. Nothing here
//              wedges: every request is accepted in the cycle it is made, with or
//              without an error.
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
// Modified:    2026-09-12 - E2-RV1 increment 5: D-port error response (access faults)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (I/D ports, MMIO via D-port decode),
//              §6 (eth_axi / eth_dram_ctrl socket) · §8 checkpoint 5 ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §5 (SoC map)
// Notes:       Pure combinational decode and muxing — no state, no arbitration,
//              no clock-domain crossing; the peripheral inside it owns the only
//              state. `mem_*` is a straight pass-through of the core's request
//              (same values, same cycle) when the address is not a device, so
//              inserting this module cannot change the memory path's behavior.
//              Every request is answered in its own cycle: `ready_o` is high with
//              or without `err_o`, so no address inside the page (or outside
//              every region) can wedge the core's D port.
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
    input  logic [1:0]  size_i,     // eth_rv_pkg::mem_size_e of the access
    output logic        ready_o,
    output logic [63:0] rdata_o,
    output logic        err_o,      // with ready_o: the access is an ERROR response

    // ---- system memory master (DRAM socket / behavioral memory) ----
    output logic        mem_req_o,
    output logic        mem_we_o,
    output logic [63:0] mem_addr_o,
    output logic [63:0] mem_wdata_o,
    output logic [7:0]  mem_wstrb_o,
    input  logic        mem_ready_i,
    input  logic [63:0] mem_rdata_i,
    input  logic        mem_err_i,  // with mem_ready_i: the memory side faulted

    // ---- console UART line + verification status ----
    output logic        uart_tx_o,
    output logic        uart_busy_o,
    output logic        uart_overflow_o
);

    logic       page_sel;   // access inside the UART page
    logic       page_byte;  // ... and narrow enough for its byte register file
    logic [2:0] reg_off;
    logic       uart_sel;
    logic       uart_ready;
    logic [7:0] uart_rdata;

    // `reg_off = addr_i[2:0]` is the whole of the peripheral's address decode:
    // every offset inside the 4 KiB page aliases onto one of the eight byte
    // registers, exactly like Spike's ns16550 (`addr >>= reg_shift; addr &= 7`).
    assign page_sel  = req_i && (addr_i[63:12] == UART_BASE[63:12]);
    assign page_byte = (size_i == 2'd0);          // eth_rv_pkg::SZ_BYTE
    assign reg_off   = addr_i[2:0];
    assign uart_sel  = page_sel && page_byte;

    // In-page accesses are always accepted — with `err_o` when the width is one
    // the byte register file cannot serve, which is Spike's `reg_io_width != len`
    // rejection turned into the architectural access fault.
    assign ready_o = page_sel ? (page_byte ? uart_ready : 1'b1) : mem_ready_i;
    assign rdata_o = uart_sel ? {8{uart_rdata}} : mem_rdata_i;
    assign err_o   = (page_sel && !page_byte) || (mem_req_o && mem_err_i);

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
