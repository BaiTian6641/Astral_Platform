`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_mmio_mux
// Description: D-port address decoder + MMIO peripheral set for the eth_rv SoC:
//              memory-mapped devices sit IN FRONT of the system memory port, so
//              the core keeps exactly one data port (C14 §4: "CLINT/PLIC — MMIO
//              经 D 端口地址译码") and every downstream path (the behavioral beat
//              memory of the v0 testbench, `eth_rv_axi_master` -> `eth_dram_ctrl`)
//              stays unchanged.
// Details:     SoC DATA MAP (increment 6: CLINT added):
//
//                0x0000_0000_8000_0000  system memory (DRAM socket / eth_dram_ctrl)
//                0x0000_0000_1000_0000  console UART (eth_rv_uart, 4 KiB page)
//                0x0000_0000_0200_0000  CLINT (eth_rv_clint, 0xc000 window)
//                PLIC                   not implemented (no external source: MEIP = 0)
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
//              CLINT (E2-RV1 increment 6): `eth_rv_clint` answers Spike's
//              MSIP/MTIMECMP/MTIME window at `0x0200_0000` (size 0xc000, the
//              same layout and byte-lane behaviour as `riscv/clint.cc`) and
//              drives the hart's `msip_i`/`mtip_i` lines from it. The window is
//              decoded FIRST and kept out of the memory path exactly like the
//              console page; an address past the window (0x0200_c000 ..) is
//              claimed by no region and so becomes an access fault, which is
//              Spike's absent-device behaviour. `step_i` is the hart's
//              executed-instruction strobe, which the CLINT counts to advance
//              `mtime` on Spike's cadence (see eth_rv_clint.sv for why reading
//              MTIME is still a documented DiffTest boundary).
//
//              MEIP has no source: the golden model's default configuration has
//              no PLIC, so `meip_i` on the core is tied low here and stays 0.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 6: CLINT (MSIP/MTIMECMP/MTIME) in front
//              of the D port; interrupt lines exit to the core
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (I/D ports, MMIO via D-port decode),
//              §6 (eth_axi / eth_dram_ctrl socket) · §8 checkpoint 5 ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §5 (SoC map)
// Notes:       Combinational decode and muxing — no arbitration, no clock-domain
//              crossing; the UART and the CLINT own the only state. `mem_*` is a
//              straight pass-through of the core's request (same values, same
//              cycle) when the address is not a device, so inserting this module
//              cannot change the memory path's behavior. Every request is
//              answered in its own cycle: `ready_o` is high with or without
//              `err_o`, so no address in a device window (or outside every
//              region) can wedge the core's D port.
module eth_rv_mmio_mux #(
    parameter logic [63:0] UART_BASE       = 64'h0000_0000_1000_0000,  // console page (Spike NS16550_BASE)
    parameter int unsigned UART_BIT_CYCLES = 16,                       // clk / baud (see eth_rv_uart)
    parameter int unsigned UART_FIFO_DEPTH = 64,                       // transmit queue depth
    parameter logic [63:0] CLINT_BASE      = 64'h0000_0000_0200_0000,  // CLINT window (Spike clint.cc)
    parameter logic [63:0] CLINT_SIZE      = 64'h0000_0000_0000_c000   // msip..mtime, as Spike decodes it
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
    output logic        uart_overflow_o,

    // ---- CLINT: interrupt lines to the hart + the hart's step strobe ----
    output logic        msip_o,     // machine software interrupt pending
    output logic        mtip_o,     // machine timer interrupt pending
    input  logic        step_i      // one pulse per instruction that left EX
);

    logic       page_sel;   // access inside the UART page
    logic       page_byte;  // ... and narrow enough for its byte register file
    logic [2:0] reg_off;
    logic       uart_sel;
    logic       uart_ready;
    logic [7:0] uart_rdata;
    logic       clint_sel;  // access inside the CLINT window
    logic [63:0] clint_rdata;

    // `reg_off = addr_i[2:0]` is the whole of the peripheral's address decode:
    // every offset inside the 4 KiB page aliases onto one of the eight byte
    // registers, exactly like Spike's ns16550 (`addr >>= reg_shift; addr &= 7`).
    assign page_sel  = req_i && (addr_i[63:12] == UART_BASE[63:12]);
    assign page_byte = (size_i == 2'd0);          // eth_rv_pkg::SZ_BYTE
    assign reg_off   = addr_i[2:0];
    assign uart_sel  = page_sel && page_byte;

    // In-page accesses are always accepted — with `err_o` when the width is one
    // the byte register file cannot serve, which is Spike's `reg_io_width != len`
    // rejection turned into the architectural access fault. The CLINT answers
    // combinationally in the same cycle for every access it claims, so it can
    // never wedge either.
    assign ready_o = page_sel ? (page_byte ? uart_ready : 1'b1)
                    : clint_sel ? 1'b1 : mem_ready_i;
    assign rdata_o = uart_sel  ? {8{uart_rdata}}
                    : clint_sel ? clint_rdata : mem_rdata_i;
    assign err_o   = (page_sel && !page_byte) || (mem_req_o && mem_err_i);

    // The memory path sees the core's request verbatim, except that a device
    // access never reaches it (see why in the header).
    assign mem_req_o   = req_i && !page_sel && !clint_sel;
    assign mem_we_o    = we_i;
    assign mem_addr_o  = addr_i;
    assign mem_wdata_o = wdata_i;
    assign mem_wstrb_o = wstrb_i;

    eth_rv_clint #(
        .BASE            (CLINT_BASE),
        .CLINT_SIZE      (CLINT_SIZE)
    ) u_clint (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .req_i        (req_i),
        .we_i         (we_i),
        .addr_i       (addr_i),
        .wdata_i      (wdata_i),
        .size_i       (size_i),
        .sel_o        (clint_sel),
        .rdata_o      (clint_rdata),
        .msip_o       (msip_o),
        .mtip_o       (mtip_o),
        .step_i       (step_i)
    );

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

// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_clint
// Description: Core-local interruptor for eth_rv: the MSIP / MTIMECMP / MTIME
//              registers Spike's `clint_t` exposes, at Spike's addresses.
// Details:     The core's interrupt lines are pushed from here, so the *program*
//              decides when an interrupt becomes pending — which is exactly what
//              makes the interrupt path DiffTest-able against Spike:
//
//                BASE + 0x0000  msip[0]      (32-bit, bit 0 -> mip.MSIP)
//                BASE + 0x4000  mtimecmp[0]  (64-bit; MTIP = mtime >= mtimecmp)
//                BASE + 0xbff8  mtime        (64-bit, read/write)
//
//              The address map, the region size (0xc000) and the byte-lane
//              behaviour of every access are Spike's (riscv/clint.cc): the region
//              is decoded as a straight `BASE <= addr < BASE + SIZE` window, the
//              msip word is reached only at an offset that is a multiple of 4,
//              mtimecmp/mtime only in their own eight bytes, and any other offset
//              inside the window reads as zero and drops writes (Spike's
//              `addr + len <= CLINT_SIZE` hole). An access outside the window is
//              NOT claimed here, so the D-port decoder turns it into the
//              architectural access fault Spike's absent-device path raises.
//
//              PENDING-BIT TIMING (why the write is bypassed): a store reaches
//              the CLINT in the core's MEM stage, and by then the *next*
//              instruction is already in EX. Spike takes an interrupt before it
//              executes the next instruction, so the line has to be high in the
//              very cycle the store is accepted — hence `msip_o`/`mtip_o` are
//              combinational over "the register, or the store in flight this
//              cycle". Without the bypass the interrupt would land one
//              instruction late and the commit stream would diverge.
//
//              MTIME CADENCE: Spike ticks mtime by INTERLEAVE/INSNS_PER_RTC_TICK
//              (50) every INTERLEAVE (5000) *steps*, so the register steps as a
//              staircase of the hart's instruction count, not its cycles. This
//              module reproduces that cadence over the core's `step_i` strobe
//              (one pulse per instruction that leaves EX), with STEP_PRELOAD
//              standing in for the pinned Spike's five-instruction boot ROM so
//              the phase lines up for a trap-free program. Reading MTIME is a
//              documented boundary of the DiffTest all the same: Spike's
//              sim-level step accounting (its early step return on a trap)
//              diverges from any hart-side counter once a program traps, so the
//              corpus only ever arms MTIP with 0 (always pending) or all-ones
//              (never pending) — see verif/eth_rv/README.md.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (privilege/trap path,
//              CLINT-driven interrupts), §4 (MMIO via D-port decode)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2, §5 (SoC map)
// Notes:       Combinational single-cycle slave like the console UART: every
//              request is answered in its own cycle, so nothing can wedge. No
//              vendor primitives, no procedural loops (the byte merge over the
//              beat is a generate loop), literals carry width and base.


//
//              (This second module shares the file deliberately: the project lint
//              rule resolves a module's dependencies by filename, so a separate
//              eth_rv_clint.sv would need a build-file change while this device
//              has no other user. The waiver below covers only the resulting
//              DECLFILENAME — one file cannot be named after two modules — and
//              every other -Wall warning still fails the lint.)
/* verilator lint_off DECLFILENAME */
module eth_rv_clint #(
    parameter logic [63:0] BASE             = 64'h0000_0000_0200_0000,
    parameter logic [63:0] CLINT_SIZE       = 64'h0000_0000_0000_c000,
    parameter int unsigned STEP_PRELOAD     = 5,      // pinned Spike boot ROM (see header)
    parameter int unsigned RTC_TICK_STEPS   = 5000,   // Spike sim_t::INTERLEAVE
    parameter int unsigned RTC_TICK_ADVANCE = 50      // INTERLEAVE / INSNS_PER_RTC_TICK
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // ---- core D-port slave (64-bit aligned beat) ----
    input  logic        req_i,
    input  logic        we_i,
    input  logic [63:0] addr_i,
    input  logic [63:0] wdata_i,
    input  logic [1:0]  size_i,      // eth_rv_pkg::mem_size_e of the access
    output logic        sel_o,       // this access is inside the CLINT window
    output logic [63:0] rdata_o,     // eight bytes at (addr_i & ~7)
    output logic        msip_o,      // machine software interrupt pending
    output logic        mtip_o,      // machine timer interrupt pending

    input  logic        step_i       // one pulse per instruction that left EX
);

    // ------------------------------------------------------------- addresses
    // msip sits at offset 0, mtimecmp at 0x4000 and mtime at 0xbff8 — Spike's
    // clint.cc layout; the region is decoded as one window below.
    localparam logic [63:0] MTIMECMP_BASE = 64'h0000_0000_0000_4000;
    localparam logic [63:0] MTIME_BASE    = 64'h0000_0000_0000_bff8;
    localparam logic [63:0] TICK_ADV      = 64'(RTC_TICK_ADVANCE);  // sized for mtime

    // ---------------------------------------------------------------- decode
    logic [63:0] off;
    logic        in_range;
    logic        msip_hit;
    logic        mtimecmp_hit;
    logic        mtime_hit;
    logic [63:0] rd_window_msip;
    logic [63:0] rd_window_mtimecmp;
    logic [63:0] rd_window_mtime;

    assign in_range     = req_i && (addr_i >= BASE) && (addr_i < (BASE + CLINT_SIZE));
    assign sel_o        = in_range;
    assign off          = addr_i - BASE;
    assign msip_hit     = in_range && (off < MTIMECMP_BASE);
    assign mtimecmp_hit = in_range && (off >= MTIMECMP_BASE) && (off < MTIME_BASE);
    assign mtime_hit    = in_range && (off >= MTIME_BASE) && (off < CLINT_SIZE);

    // ---------------------------------------------------------------- state
    logic        msip_r;
    logic [63:0] mtimecmp_r;
    logic [63:0] mtime_r;
    logic [13:0] steps_mod_r;    // steps into the current RTC tick (< 5000)

    // ------------------------------------------------------------ write side
    // msip: Spike only latches a write at a multiple of 4 (and a dword store
    // reaches it through its low word), taking bit 0 of the written word — which
    // is byte lane 0 of the beat, so `wdata_i[0]` is the written bit.
    logic msip_wr;
    logic mtimecmp_wr;
    logic mtime_wr;
    logic [3:0] size_bytes;      // 1, 2, 4 or 8 (the access width in bytes)
    logic [7:0] size_mask;       // 0x01, 0x03, 0x0f, 0xff
    logic [7:0] byte_en;         // the lanes of the beat this access covers

    assign msip_wr     = sel_o && we_i && msip_hit && (off[1:0] == 2'b00);
    assign mtimecmp_wr = sel_o && we_i && mtimecmp_hit && (off < (MTIMECMP_BASE + 64'd8));
    assign mtime_wr    = sel_o && we_i && mtime_hit && (off < (MTIME_BASE + 64'd8));
    // The lane mask is built rather than compared; an 8-byte access wraps the
    // shift to zero, so `- 1` yields all eight lanes exactly as intended.
    assign size_bytes  = 4'd1 << size_i;
    assign size_mask   = (8'd1 << size_bytes) - 8'd1;
    assign byte_en     = size_mask << off[2:0];

    logic msip_next;
    assign msip_next = msip_wr ? wdata_i[0] : msip_r;

    // mtimecmp/mtime are merged byte by byte exactly like Spike's
    // write_little_endian_reg(): the beat's lane `off[2:0] + j` is byte `j` of the
    // register, and a byte the access does not cover keeps its value.
    logic [63:0] mtimecmp_next;
    logic [63:0] mtime_next;
    logic        rtc_tick;

    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : g_byte_merge
            logic mtimecmp_wr_lane;   // per-lane, so the loop has no shared driver
            logic mtime_wr_lane;
            assign mtimecmp_wr_lane = mtimecmp_wr && byte_en[gi];
            assign mtime_wr_lane    = mtime_wr && byte_en[gi];
            assign mtimecmp_next[8*gi +: 8] = mtimecmp_wr_lane
                                              ? wdata_i[8*gi +: 8]
                                              : mtimecmp_r[8*gi +: 8];
            assign mtime_next[8*gi +: 8]    = mtime_wr_lane
                                              ? wdata_i[8*gi +: 8]
                                              : mtime_r[8*gi +: 8];
        end
    endgenerate

    // ------------------------------------------------- staircase of mtime
    // One advance every RTC_TICK_STEPS steps; the residual counter makes this an
    // increment + compare rather than a 64-bit division.
    assign rtc_tick = (steps_mod_r == RTC_TICK_STEPS[13:0] - 14'd1);

    // ------------------------------------------------------------ read side
    // The beat carries the eight bytes of the aligned window at addr_i & ~7; the
    // core rotates it right by addr_i[2:0], so a byte/half/word read sees the
    // bytes of its own access (the same convention as the console UART).
    // mtime is presented with the -1 step adjustment: the load has already left
    // EX, and the golden model's count is "instructions executed before *this*
    // one" (see the header note on the cadence).
    logic [63:0] mtime_rd;
    assign mtime_rd = (steps_mod_r == 14'd0) ? (mtime_r - TICK_ADV) : mtime_r;

    assign rd_window_msip     = (off < 64'd8) ? {32'd0, 31'd0, msip_r} : 64'd0;
    assign rd_window_mtimecmp = (off[63:3] == MTIMECMP_BASE[63:3])
                                ? mtimecmp_r : 64'd0;
    assign rd_window_mtime    = (off[63:3] == MTIME_BASE[63:3]) ? mtime_rd : 64'd0;

    always_comb begin
        if (msip_hit)          rdata_o = rd_window_msip;
        else if (mtimecmp_hit) rdata_o = rd_window_mtimecmp;
        else if (mtime_hit)    rdata_o = rd_window_mtime;
        else                   rdata_o = 64'd0;
    end

    // ----------------------------------------------------- interrupt lines
    // Combinational over the store in flight (see the header): a pending flag
    // must be visible in the very cycle the store is accepted, because that is
    // the cycle in which the instruction after the store sits in EX.
    logic [63:0] mtimecmp_eff;

    assign mtimecmp_eff = mtimecmp_wr ? mtimecmp_next : mtimecmp_r;
    assign msip_o       = msip_next;
    assign mtip_o       = (mtime_r >= mtimecmp_eff);

    // ---------------------------------------------------------------- state
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            msip_r       <= 1'b0;
            mtimecmp_r   <= 64'd0;
            mtime_r      <= 64'd0;
            steps_mod_r  <= STEP_PRELOAD[13:0];
        end else begin
            msip_r     <= msip_next;
            mtimecmp_r <= mtimecmp_next;
            mtime_r    <= mtime_next;
            if (step_i) begin
                if (rtc_tick) begin
                    steps_mod_r <= 14'd0;
                    mtime_r     <= mtime_next + TICK_ADV;
                end else begin
                    steps_mod_r <= steps_mod_r + 14'd1;
                end
            end
        end
    end

endmodule
/* verilator lint_on DECLFILENAME */
`default_nettype wire
