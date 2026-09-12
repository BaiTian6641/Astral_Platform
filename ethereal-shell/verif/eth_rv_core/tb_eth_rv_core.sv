`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_rv_core
// Description: Verilator testbench for eth_rv_core: behavioral memory + RVFI commit-trace dump.
// Details:     The RTL-side half of the DiffTest integration (C14 §5). It
//              instantiates the core, serves its two v0 ports out of a
//              zero-filled word array loaded from a $readmemh image (its size is
//              the SoC memory window, `-DETH_RV_MEM_BYTES`, 1 MiB by default —
//              see the parameters below), and
//              writes one trace line per retired instruction in the harness's
//              canonical format (ethereal-shell/verif/eth_rv/rv_trace.py):
//              `cycle pc rd value` followed by the optional memory suffix
//              `mem_addr mem_wdata mem_rmask mem_wmask` (C14 §5.2), with `-` for
//              "no access" / "load" / "not this direction". `cycle` is
//              `rvfi_order_o`, i.e. the retirement ordinal 1..N — exactly what
//              the Spike golden stream numbers — so the comparator's default
//              cycle check passes without `--no-cycle-check`.
//
//              Port model (matches the core's documented contract):
//                I port: rdata = the four bytes at imem_addr (16-bit aligned).
//                D port: rdata = the eight bytes at dmem_addr; a write stores
//                        dmem_wdata bytes under dmem_wstrb at dmem_addr + lane.
//                Both are served out of a 128-bit {next,current} window so an
//                unaligned access still sees contiguous bytes; `+memlat=N` adds
//                N idle cycles before `ready`, which exercises the core's stall
//                path (the core holds its request until the transfer is accepted).
//
//              ERROR RESPONSES (E2-RV1 increment 5): an address outside the
//              mapped memory window (see `in_mem`) is answered with `ready` AND
//              `err` in the same cycle — this build's image of the address map
//              Spike and `eth_dram_ctrl` agree on, where such an address is
//              claimed by nobody and raises an access fault (mcause 1/5/7,
//              `mtval` = the address). The core turns the pair into that trap;
//              a build where the error never reaches the core as a trap shows up
//              as a trace divergence from Spike (Spike does not commit the
//              faulting instruction, and neither may the DUT) *and* as the
//              trap-count check in `cor_fault.S`. The console UART's own width
//              check (a non-byte access to its page) is inside
//              `eth_rv_mmio_mux.sv`, in front of this memory model.
//              `+no_dmem_err=1` is the negative control for that contract: it
//              drops the error response so the access looks successful, and the
//              DiffTest must then report a divergence at the instruction Spike
//              traps on (see verif/eth_rv/README.md).
//
//              WEDGE GUARD: the D port (and the I port) must be answered on every
//              request — the RV-B D port used to hang forever on an access it
//              could not serve. A request still unanswered after
//              PORT_STARVE_CYCLES is a hard FAIL naming the address, so "the old
//              wedge cannot come back" is asserted inside every run rather than
//              inferred from the cycle budget. `+starve_dmem=1` is the negative
//              control for that guard: it makes the memory model withhold the
//              acknowledge for an out-of-window access, reproducing the old hang,
//              and the run must then FAIL with the wedge message (see
//              verif/eth_rv/README.md).
//
//              Termination mirrors the golden generator: the run ends at the
//              commit whose store covers the HTIF `tohost` mailbox (crt0.S'
//              final `sd`), so both streams stop at the same instruction. The
//              run also ends on a cycle budget, or when the core takes more
//              traps than `+maxtraps` (a trap is a normal, handled event now —
//              the corpus exercises them on purpose — but a trap loop must not
//              run forever).
//
//              `+fault_index=N +fault_field=<pc|rd|value|mem_addr|mem_wdata|fflags|frm>`
//              `+fault_value=<hex>` deliberately corrupts one emitted trace
//              record, where N is a 0-based commit index (the same convention as
//              the harness's own `--inject INDEX:FIELD=VALUE`). That is the
//              negative control for the DiffTest vehicle: it must show up as a
//              divergence at exactly that commit — including for the memory
//              stream, which is how the memory comparison itself is proven to be
//              live rather than decorative.
//
//              TWO D-PORT BUILDS (one source; selected with -DETH_RV_DRAM_AXI):
//                * default — the v0 behavioral beat memory below (fast, no AXI);
//                * ETH_RV_DRAM_AXI — the core's D port drives `eth_rv_axi_master`
//                  into a real `eth_dram_ctrl` + `eth_dram_stub` AXI4 socket. The
//                  DRAM stub's array is then the single memory image (preloaded
//                  from +mem and read by the instruction port hierarchically), so
//                  fetch and data agree; the D port goes through full AXI4.
//                  `ETH_RV_LINE_BEATS` (default 1) selects the master's read line
//                  fill: >1 makes a load miss one INCR burst of that many beats and
//                  serves the following sequential loads out of the line. The PASS
//                  line reports the AXI transaction/beat counts, and the run FAILs
//                  if the socket ever answered with a non-OKAY response.
//
//              The PASS line also reports what the trace carried — committed
//              instructions, how many were compressed, and the load/store
//              counts taken from the RVFI memory fields — so a run is
//              self-describing without reading the trace file.
//
//              THE BOOT PATH (E2-RV2 increment 5, S3): the core no longer starts
//              in DRAM. `eth_rv_pkg::RESET_PC` is the BootROM base (0x1000), so
//              every run begins in the 4 KiB `eth_rv_boot_rom` the MMIO mux
//              decodes: its M-mode stub sets a0 = hart id, a1 = DTB_ADDR, and
//              jumps to the 64-bit payload entry stored at ROM offset 32 (word 8).
//              This testbench preloads that one ROM image (`+rom=<file>`, the
//              checked-in hex from rtl/eth_rv/rom/build_rom.py; a missing file is
//              a hard FAIL, never a silent zero ROM) into the MMIO mux's ROM
//              instance, PATCHES the entry word from `+entry=<addr>` — exactly
//              how a harness points a reset vector at an ELF entry — and serves
//              FETCHES from the same array (the SoC's two routes to one ROM
//              slave). The optional `+dtb=<file>` writes the blob at DTB_ADDR and
//              checks its FDT magic: a1 pointing at something that is not a device
//              tree is a boot failure, and it is caught here rather than showing
//              up as a mystery load value later.
//
//              THE TRACE WINDOW: the golden stream is Spike's commits AFTER its
//              own reset vector (rv_spike's `entry` rule), so the dump here starts
//              at the PC the ROM actually jumps to and renumbers that commit
//              `cycle` 1 — the two streams line up without `--no-cycle-check`.
//              `+trace_from=<addr>` overrides the start: pass the ROM base
//              (0x1000) to diff the reset stub itself, which is what a golden run
//              started with `--disable-dtb --pc=0x1000` over an image carrying the
//              same ROM produces (both streams then cover the seven ROM
//              instructions and the payload, commit for commit). Commits before
//              the window are still watched, never dumped.
//
//              THE HANDSHAKE IS CHECKED IN THE RTL, not left to the trace: the
//              first commit must be inside the ROM, the ROM must write x10 (a0) = 0
//              and x11 (a1) = DTB_ADDR before the payload entry retires, the entry
//              word the ROM holds must equal the `+entry` that was asked for, and
//              the run must reach the entry at all. Those are one-sided facts —
//              the golden model boots through SPIKE's reset vector, whose a1 is
//              Spike's own DTB — so they cannot be DiffTested; they are asserted
//              here (FAILing with what was seen) and the payload's own checks
//              cover what both sides can compare.
//
//              THE `time` CADENCE FOLLOWS THE STUB: the CLINT turns `mtime` into a
//              staircase of the hart's retired instruction count, and the golden
//              model counts a reset vector this SoC does not run. The invariant
//              both sides share is
//                  tick count = CLINT_STEP_PRELOAD + (retires AFTER the stub)
//              where the preload is what the GOLDEN had counted when the program
//              started (5 = Spike's own five-instruction reset vector; compile with
//              `-DETH_RV_CLINT_PRELOAD=<n>` when the golden is started at this ROM,
//              where n is the stub's instruction count) and the stub's own pulses
//              are swallowed using the step-count word the ROM image carries. The
//              check above holds that word against the retires actually seen before
//              the handoff, so a stub whose length changed (or an image that lost
//              the word) FAILs instead of silently shifting the `time` staircase.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 5: port error responses + wedge guard
//              2026-09-12 - E2-RV2 increment 5 (S3): BootROM preload + a0/a1
//              handshake checks, `+entry`/`+trace_from` trace window, `+dtb`
//              load + magic check, parameterized memory window (`+mem_bytes`)
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (I/D/RVFI ports), §5 (DiffTest) ·
//              ethereal-shell/core.yaml (SoC map / boot contract) ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §5 (DDR-less boot) ·
//              ethereal-shell/verif/eth_rv/README.md (trace protocol)
// Notes:       Sim-only (Tags: TESTBENCH): not part of `make lint`'s RTL set,
//              lintable with `verilator --lint-only -Wall --timing` regardless.
module tb_eth_rv_core;

    // ------------------------------------------------------------------ params
    // THE MEMORY WINDOW (S3 contract): ONE number, shared by this testbench's
    // behavioral memory, by the AXI/DRAM socket below and by the golden model's
    // `-m0x80000000:<bytes>`. The runner passes it as `-DETH_RV_MEM_BYTES=<n>`
    // (compile time: it sizes the array) and again as `+mem_bytes=<n>` (run time:
    // checked against the compiled value), so a run cannot silently diff a DUT
    // whose memory window differs from the one Spike was given.
`ifndef ETH_RV_MEM_BYTES
`define ETH_RV_MEM_BYTES 1_048_576     // 1 MiB (S3 contract)
`endif
    localparam int unsigned MEM_BYTES = `ETH_RV_MEM_BYTES;
`ifndef ETH_RV_DRAM_AXI
    // The behavioral build's array is indexed by 8-byte words; the AXI build's
    // memory is the DRAM stub's own, sized by `DRAM_WORDS` below.
    localparam int unsigned MEM_WORDS = MEM_BYTES / 8;
`endif

    // BootROM (rtl/eth_rv/eth_rv_boot_rom.sv): the 4 KiB read-only region at
    // 0x0000_1000 the core executes FIRST (eth_rv_pkg::RESET_PC). Its M-mode stub
    // sets a0 = 0 (hart id) and a1 = DTB_ADDR, then jumps to the 64-bit payload
    // entry stored at ROM_ENTRY_WORD (offset 32) — the harness patches those two
    // words (`+entry=<addr>`) so one ROM boots every corpus program. The region is
    // served here for FETCHES and by the MMIO mux for data accesses: one image.
    localparam logic [63:0] ROM_BASE       = 64'h0000_0000_0000_1000;
    localparam int unsigned ROM_BYTES      = 4096;
    localparam int unsigned ROM_WORDS      = ROM_BYTES / 4;
    // The two ROM words the S3 contract names and the S4 Linux profile moves:
    // the S4 BootROM is Spike's own reset vector (five instructions, the entry at
    // offset 24) with the device tree filling the rest of the 4 KiB page, so its
    // entry word is 6 and its stub step count lives at word 5 — the first word the
    // stub never executes. Compile time, because the ROM module's ports are (see
    // eth_rv_boot_rom.sv); the S4 runner selects the pair with -D.
`ifndef ETH_RV_ROM_ENTRY_WORD
`define ETH_RV_ROM_ENTRY_WORD 8
`endif
`ifndef ETH_RV_ROM_STUB_WORD
`define ETH_RV_ROM_STUB_WORD 7
`endif
    localparam int unsigned ROM_ENTRY_WORD = `ETH_RV_ROM_ENTRY_WORD;  // offset 32 (S3) / 24 (S4)
    localparam int unsigned ROM_STUB_WORD  = `ETH_RV_ROM_STUB_WORD;   // offset 28 (S3) / 20 (S4)
    localparam logic [63:0] DTB_ADDR       = 64'h0000_0000_8000_2000;  // a1 (S3 contract)
    // The FDT header magic is `0xd00dfeed` WRITTEN BIG-ENDIAN in the blob, so the
    // first four bytes read through this model's little-endian lanes are 0xedfe0dd0.
    localparam logic [31:0] DT_MAGIC_LE = 32'hEDFE_0DD0;
    localparam string DEFAULT_ROM_IMAGE = "ethereal-shell/rtl/eth_rv/rom/boot_rom.hex";
    localparam int unsigned ROM_WIW = $clog2(ROM_WORDS);   // ROM 32-bit word index width
    localparam int unsigned ROM_BIW = ROM_WIW - 1;         // ROM 8-byte beat index width

    // The CLINT's mtime phase: what the GOLDEN model has counted when the program
    // starts. 5 (the default) is Spike's own five-instruction reset vector, which
    // its step counter includes while this SoC boots through the BootROM instead —
    // the corpus comparison. A golden started at THIS ROM (`--pc=0x1000
    // --disable-dtb`, the full-ROM comparison) counts the stub itself, so that mode
    // compiles the TB with `-DETH_RV_CLINT_PRELOAD=<stub instructions>` (7 for the
    // checked-in image). The stub's own pulses are swallowed automatically from the
    // ROM image's step-count word, so this is the only mode-dependent number here;
    // the boot check below FAILs if the image's count and the ROM's actual retires
    // ever disagree.
`ifndef ETH_RV_CLINT_PRELOAD
`define ETH_RV_CLINT_PRELOAD 5
`endif
    localparam int unsigned CLINT_STEP_PRELOAD = `ETH_RV_CLINT_PRELOAD;

    // mtime cadence (see eth_rv_mmio_mux's CLINT_RTC_TICK_* parameters). The default is
    // Spike's DiffTest cadence (one tick per 100 retired instructions); the Linux/SoC
    // profile compiles 1/1 so mtime tracks retired instructions 1:1, which is what a
    // kernel's delay loops assume and is what makes a 40-MiB boot finish.
`ifndef ETH_RV_CLINT_TICK_STEPS
`define ETH_RV_CLINT_TICK_STEPS 5000
`endif
`ifndef ETH_RV_CLINT_TICK_ADVANCE
`define ETH_RV_CLINT_TICK_ADVANCE 50
`endif
    localparam int unsigned CLINT_RTC_TICK_STEPS   = `ETH_RV_CLINT_TICK_STEPS;
    localparam int unsigned CLINT_RTC_TICK_ADVANCE = `ETH_RV_CLINT_TICK_ADVANCE;

    // Console UART of the SoC data map (rtl/eth_rv/eth_rv_mmio_mux.sv): the same
    // page Spike's ns16550 answers on, with a 16-cycle bit cell, so a queued
    // burst drains at 160 cycles per byte. The receiver below decodes the line
    // with the SAME divisor, which is what makes the frame timing checkable.
    localparam logic [63:0] UART_BASE = 64'h0000_0000_1000_0000;
    localparam int unsigned UART_DIV  = 16;       // cycles per 8N1 bit cell
    localparam int unsigned UART_FRAME_CYCLES = 10 * UART_DIV;
    // The receiver buffer must hold everything the run logs up to its stop. The
    // corpus strings are a few bytes; a Linux console prints ~12 KiB before the
    // initramfs handoff, so the S4 profile needs headroom (overflow is still a
    // hard FAIL — this is a bound, not a policy).
    localparam int unsigned UART_MAX_BYTES = 131072; // receiver buffer (overflow = FAIL)
    // The transmit queue's depth. Spike's ns16550 model has no queue at all — a THR
    // store is written out immediately and LSR keeps reporting TEMT|THRE — so a
    // program may emit console bytes as fast as it can retire stores, while this
    // model shifts them out at UART_BIT_CYCLES (160 cycles/byte) and, being faithful
    // to that LSR, cannot back-pressure the writer. The corpus bursts are a few
    // bytes; a Linux boot prints ~12 KiB before userspace, so the S4 profile builds
    // this testbench with a much deeper queue (`-DETH_RV_UART_FIFO_DEPTH`). Depth is
    // a model parameter, not an architectural claim: the DUT's LSR semantics are
    // unchanged, which is what keeps the firmware DiffTest aligned with Spike.
`ifndef ETH_RV_UART_FIFO_DEPTH
`define ETH_RV_UART_FIFO_DEPTH 64
`endif
    localparam int unsigned UART_FIFO_DEPTH = `ETH_RV_UART_FIFO_DEPTH;
    // The PLIC of the SoC map (rtl/eth_rv/eth_rv_plic.sv): Spike's window, source
    // count and priority width — mirrored by ethereal-shell/core.yaml and by
    // verif/eth_rv/rv_platform.py, and the address the device tree declares.
    localparam logic [63:0] PLIC_BASE      = 64'h0000_0000_0c00_0000;
    localparam logic [63:0] PLIC_SIZE      = 64'h0000_0000_0100_0000;
    localparam int unsigned PLIC_NDEV      = 31;
    localparam int unsigned PLIC_PRIO_BITS = 4;
    // How long after reset the RX injection starts: the payload must be running,
    // and the frames must not collide with the BootROM's own first commits.
    localparam int unsigned RX_INJ_DELAY   = 256;

`ifndef ETH_RV_LINE_BEATS
`define ETH_RV_LINE_BEATS 1     // eth_rv_axi_master read line fill (1 = single beat)
`endif

`ifdef ETH_RV_DRAM_AXI
    // The DRAM socket's window is the SAME single number as the behavioral memory
    // (S3 contract): the AXI master and `eth_dram_ctrl` are both built with it
    // below, and the runner sizes Spike's `-m` with it.
    localparam logic [31:0] DRAM_BASE  = 32'h8000_0000;
    localparam int unsigned DRAM_BYTES = MEM_BYTES;
    localparam int unsigned DRAM_WORDS = DRAM_BYTES / 8;
`endif

    // ------------------------------------------------------------------ clock
    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 100 MHz
    end

    // ------------------------------------------------------------------ plusargs
    string       mem_path;
    string       trace_path;
    string       fault_field;
    logic [63:0] base_addr;
    logic [63:0] tohost_addr;
    int unsigned mem_lat;
    int unsigned max_cycles;
    int unsigned max_traps;
    int unsigned fault_index;
    logic [63:0] fault_value;
    // Console-UART controls: the received byte string is written to `+uart=<file>`
    // and `+uart_fault_frame=N +uart_fault_bit=M` inverts one bit cell of one
    // received frame — the negative control for the UART assertion (the runner
    // must then see the wrong string; it is a line fault, never a design option).
    string       uart_path;
    int unsigned uart_drain_cycles;
    int          uart_fault_frame;
    int          uart_fault_bit;
    // ---- console UART RECEIVE line: injection + self-check (E2-RV2 increment 6) --
    // The receive *register* interface is DiffTested through MCR loopback (Spike's
    // own byte-injection route — see `cor_uart_rx`), but the serial *receiver* has
    // no golden model to compare against: Spike's ns16550 takes its bytes from a
    // terminal a batch run cannot drive (E2-RV2 §3.8). So the testbench drives a
    // real 8N1 frame onto `uart_rx_i` — `+uart_rx=<hex bytes>`, one 10-cell frame
    // per byte at the same divisor the transmitter uses — and then checks the bytes
    // the DUT queued, which makes the deserialiser and the receive queue a
    // TB-level assertion instead of a DiffTest.
    // `+uart_rx_fault_frame=N +uart_rx_fault_bit=M` inverts one bit cell of one
    // injected frame (0 = start, 1..8 = data LSB first, 9 = stop); the self-check
    // must then FAIL, which is the negative control for the assertion above.
    string       uart_rx_hex;
    int          uart_rx_fault_frame;
    int          uart_rx_fault_bit;
    // Wedge negative control (WEDGE GUARD below): `+starve_dmem=1` makes the
    // memory model answer NOTHING outside the mapped window, which is exactly the
    // old RV-B D-port wedge (the access is never acknowledged). The guard must
    // then FAIL the run, naming the address — the control that shows the guard is
    // live rather than decorative. Only the behavioral (non-AXI) build implements
    // it; the AXI build refuses it loudly instead of silently ignoring it.
    int unsigned starve_dmem;
    // Silent-success negative control: `+no_dmem_err=1` drops the error response,
    // so an access the platform cannot serve looks like an ordinary successful
    // beat. The core then RETIRES the access instead of trapping, and the DiffTest
    // must catch it as a divergence from Spike (which does not commit the faulting
    // instruction) — the control that shows the error response is load-bearing
    // rather than decorative.
    int unsigned no_dmem_err;
    // Sv39 negative control (E2-RV2 increment 1): `+dmem_corrupt_addr=A
    // +dmem_corrupt_xor=X` folds `X` into every D-port beat whose 8-byte-aligned
    // window is at `A`, in both directions. Aimed at a page-table page it is the
    // "fault injected on a walk": the walker reads a PTE that differs from the
    // one the program wrote, so the DUT's translation (or its fault) differs from
    // Spike's, which reads the real memory. Nothing inside the DUT knows about
    // it — what the DiffTest compares is the DUT's committed trace, so the
    // control proves the comparison is live rather than the RTL being able to
    // pass it by construction.
    logic [63:0] dmem_corrupt_addr;
    logic [63:0] dmem_corrupt_xor;
    // Debug aid for the Sv39 slice: `+trace_traps=1` prints every trap the core
    // takes (pc, cause, instruction) — the commit trace deliberately has no
    // record for a trap, so this is how a run's trap sequence is read back.
    int unsigned trace_traps;
    // PLIC negative control (E2-RV2 increment 6): `+plic_swap=1` hands the PLIC's
    // S-context line to the hart's `meip_i` and its M-context line to `seip_i`, so
    // a run with it must diverge from Spike exactly where a context's interrupt is
    // delivered — the control that shows the M/S context split is load-bearing
    // rather than decorative. Nothing inside the DUT knows about the swap: what the
    // DiffTest compares is the DUT's committed trace.
    int unsigned plic_swap;
    // ---- boot-path controls (E2-RV2 increment 5, S3) -----------------------
    // `+rom=<file>`: the BootROM image ($readmemh, 32-bit words — see
    // rtl/eth_rv/rom/boot_rom.hex). It is REQUIRED in practice: without a ROM the
    // core's reset PC has nothing to execute, so a missing file is a hard FAIL,
    // never a silently zero ROM.
    string       rom_path;
    // `+entry=<addr>`: the payload entry. It PATCHES the ROM's entry word (the
    // 64-bit value the stub `ld`s and `jr`s through) before reset, exactly as a
    // harness points Spike's reset vector at an ELF entry, and it is the default
    // trace start (see `+trace_from`).
    logic [63:0] entry_addr;
    // `+trace_from=<addr>`: start dumping the commit trace at the first commit at
    // this PC (and renumber that commit `cycle` 1, which is what the golden stream
    // — Spike's commits after its own reset vector — is numbered from). Default:
    // the ROM's entry word, i.e. the first payload instruction. Pass the ROM base
    // (0x1000) to diff the reset stub itself, which is what a golden run that
    // starts Spike at 0x1000 with `--disable-dtb --pc=0x1000` produces.
    logic [63:0] trace_from;
    // `+dtb=<file>`: a raw device-tree blob, written into RAM at DTB_ADDR before
    // reset (the address the ROM leaves in a1). Optional — a harness may instead
    // weave the same bytes into the `+mem` image at that address — but when given
    // it is checked: the blob must start with the FDT magic, because a1 pointing
    // at a non-FDT is exactly the boot failure this slice exists to catch.
    string       dtb_path;
    // `+mem_bytes=<n>`: the memory window the golden model was started with. It
    // must equal the compiled `ETH_RV_MEM_BYTES` (see the params section); a
    // mismatch is a hard FAIL rather than a quietly incomparable run.
    int unsigned mem_bytes_arg;
    // `+stop_addr=<addr>` `+stop_value=<value>`: the generalized stop event — the
    // harness's `--stop-store ADDR[:VALUE]`, so BOTH sides end at the same
    // architectural store instead of this testbench over-running to the HTIF
    // mailbox while the comparator truncates the dump. Without `+stop_addr` the
    // run ends at the `tohost` store, exactly as before.
    logic [63:0] stop_addr;
    logic [63:0] stop_value;
    bit          stop_addr_en;
    bit          stop_value_en;
    // ---- S4 Linux-boot controls (E2-RV2 increment 7) ------------------------
    // `+a1_addr=<addr>`: the device-tree address the BootROM leaves in a1. It is
    // DTB_ADDR (0x8000_2000) for the S3 corpus; the S4 BootROM mirrors Spike's own
    // reset vector byte for byte, so its a1 is Spike's ROM address (0x1020) and
    // the tree lives in the ROM rather than in RAM.
    logic [63:0] a1_addr;
    // `+rom_dtb=1`: the device tree is resident in the BootROM at `+a1_addr`
    // instead of being loaded into RAM by `+dtb`. The FDT magic is checked at that
    // ROM address, which is what makes "the firmware's a1 points at a device tree"
    // an assertion rather than an assumption.
    int unsigned rom_dtb;
    // `+stop_pc=<addr>`: end the run at the first commit at this PC. It is the S4
    // DiffTest's declared synchronisation point — the firmware portion ends where
    // OpenSBI enters the kernel (its jump target), so the trace covers exactly the
    // firmware and the comparator needs no golden tail beyond it.
    logic [63:0] stop_pc;
    bit          stop_pc_en;
    // `+uart_marker=<hex>`: stop the run once the console line has carried this
    // exact byte string (`+uart_marker=4d494c45` for "MILE"). The S4 milestone is a
    // *console* event (userspace's first line), not a store, so the stop has to be
    // defined on the decoded line — the same receiver that produces `+uart=`.
    // Framing errors are still counted and still fail the run.
    string       uart_marker_hex;
    // `+progress=<cycles>`: print a progress line every N cycles. A Linux boot is
    // hundreds of millions of cycles long and prints nothing until its console is
    // up, so without this a slow run and a hung one look identical from outside.
    int unsigned progress_cycles;
    // `+stop_trap_cause=<n>`: halt at the FIRST trap whose cause IS `n` (with
    // `+trace_traps=1` the listing then ends at the trap that was not declared).
    // A long boot takes an unknown number of expected traps before it dies (SBI
    // ecalls are cause 9); without this, "the kernel panicked somewhere in the
    // last 10^9 cycles" is the most a log can say, because the trap trace is
    // hundreds of thousands of lines long and the interesting one is the last.
    int unsigned stop_trap_cause;
    bit          stop_trap_cause_en;

    // ------------------------------------------------------------------ memory
    // One 8-byte word of the image, indexed from the corpus link base. The
    // instruction port always reads it here; in the v0 build the data port does
    // too, while the ETH_RV_DRAM_AXI build serves the data port through the AXI
    // master and takes every word from the DRAM stub's own array (the single
    // image in that build).
`ifndef ETH_RV_DRAM_AXI
    logic [63:0] mem [MEM_WORDS];
`endif

    function automatic int unsigned word_of(input logic [63:0] addr);
        word_of = int'((addr - base_addr) >> 3);
    endfunction

    function automatic logic [63:0] mem_word(input logic [63:0] addr);
        int unsigned wi;
        wi = word_of(addr);
`ifdef ETH_RV_DRAM_AXI
        mem_word = (wi < DRAM_WORDS) ? u_dram.u_impl.mem[wi] : 64'd0;
`else
        mem_word = (wi < MEM_WORDS) ? mem[wi] : 64'd0;
`endif
    endfunction

    function automatic logic [127:0] window_of(input logic [63:0] addr);
        window_of = {mem_word(addr + 64'd8), mem_word(addr)};
    endfunction

    function automatic logic [63:0] read_bytes64(input logic [63:0] addr);
        read_bytes64 = 64'(window_of(addr) >> {addr[2:0], 3'b000});
    endfunction

    function automatic logic [31:0] read_bytes32(input logic [63:0] addr);
        read_bytes32 = 32'(window_of(addr) >> {addr[2:0], 3'b000});
    endfunction
    // ---- BootROM window -----------------------------------------------------
    // The ROM array lives inside the MMIO mux's `eth_rv_boot_rom` instance (one
    // image serves the fetch path here and the D port there, the way the SoC
    // interconnect would route the core's two ports at one ROM slave). Fetches
    // are served out of it exactly like `read_bytes32` serves the behavioral
    // memory: the 8-byte beat at (addr & ~7), shifted so the addressed byte is
    // at the LSB.
    function automatic logic in_rom(input logic [63:0] addr);
        in_rom = (addr >= ROM_BASE) && (addr < (ROM_BASE + 64'(ROM_BYTES)));
    endfunction

    function automatic logic [63:0] rom_beat(input logic [63:0] addr);
        logic [ROM_BIW-1:0] bi;
        bi = ROM_BIW'((addr - ROM_BASE) >> 3);
        rom_beat = {u_mmio.u_rom.rom[{bi, 1'b1}], u_mmio.u_rom.rom[{bi, 1'b0}]};
    endfunction

    function automatic logic [31:0] rom_read32(input logic [63:0] addr);
        rom_read32 = 32'(rom_beat({addr[63:3], 3'b000}) >> {addr[2:0], 3'b000});
    endfunction

    // Write one byte into the image of whichever build this is (the `+dtb` load).
    task automatic mem_store_byte(input logic [63:0] addr, input logic [7:0] data);
        int unsigned wi;
        wi = word_of(addr);
`ifdef ETH_RV_DRAM_AXI
        if (wi < DRAM_WORDS) u_dram.u_impl.mem[wi][{addr[2:0], 3'b000} +: 8] = data;
`else
        if (wi < MEM_WORDS) mem[wi][{addr[2:0], 3'b000} +: 8] = data;
`endif
    endtask

    // Bit position of byte lane `l` inside the 64-bit port window: the lane
    // offset wraps inside the word, the word index carries (see the store block).
    function automatic logic [5:0] lane_bit(input logic [2:0] off, input logic [2:0] l);
        lane_bit = {(off + l), 3'b000};
    endfunction

    // ------------------------------------------------------------------ DUT ports
    logic        imem_req;
    logic [63:0] imem_addr;
    logic        imem_ready;
    logic [31:0] imem_rdata;
    logic        imem_err;

    // The core's own D port (`core_dmem_*`) goes through the SoC MMIO decode,
    // which re-drives the memory-side `dmem_*` group below — so the behavioral
    // memory and the AXI/DRAM path both keep seeing exactly what they saw
    // before, plus the address filter that keeps device accesses out of them.
    logic        core_dmem_req;
    logic        core_dmem_we;
    logic [63:0] core_dmem_addr;
    logic [63:0] core_dmem_wdata;
    logic [7:0]  core_dmem_wstrb;
    logic        core_dmem_ready;
    logic [63:0] core_dmem_rdata;
    logic [1:0]  core_dmem_size;
    logic        core_dmem_err;

    logic        dmem_req;
    logic        dmem_we;
    logic [63:0] dmem_addr;
    logic [63:0] dmem_wdata;
    logic [7:0]  dmem_wstrb;
    logic        dmem_ready;
    logic [63:0] dmem_rdata;
    logic        dmem_err;
    logic        dmem_err_raw;   // per-access error, before the `+no_dmem_err` control

    logic        uart_tx;
    logic        uart_busy;
    logic        uart_overflow;

    logic        rvfi_valid;
    logic [63:0] rvfi_order;
    logic [63:0] rvfi_pc;
    logic [31:0] rvfi_insn;
    logic        rvfi_rd_we;
    logic [4:0]  rvfi_rd_addr;
    logic [63:0] rvfi_rd_wdata;
    logic        rvfi_rd_fp;
    logic        rvfi_fflags_we;
    logic [4:0]  rvfi_fflags;
    logic        rvfi_frm_we;
    logic [2:0]  rvfi_frm;
    logic        rvfi_mem_valid;
    logic [63:0] rvfi_mem_addr;
    logic [63:0] rvfi_mem_wdata;
    logic [7:0]  rvfi_mem_wmask;
    logic [7:0]  rvfi_mem_rmask;
    logic [63:0] rvfi_mem_paddr;   // the PHYSICAL address of the recorded access

    logic        core_err;
    logic [63:0] core_err_pc;
    logic [31:0] core_err_insn;
    logic [3:0]  core_err_code;
    logic [63:0] core_err_tval;
    logic        core_err_irq;

    // CLINT interrupt lines (MSIP/MTIP), the PLIC's external-interrupt lines
    // (MEIP/SEIP) and the hart's executed-instruction strobe that ticks the
    // CLINT's mtime on Spike's cadence.
    logic        msip;
    logic        mtip;
    logic        meip;
    logic        seip;
    logic        step_strobe;
    // S4/Linux profile: the CLINTs mtime must keep advancing while the hart sits in
    // `wfi` (an idle CPU retires no instructions), so the tick strobe comes from the
    // simulation clock rather than from retirements — mtime then advances once per
    // cycle, which is what a real free-running counter does. The corpus keeps the
    // retirement strobe so its cadence still matches Spike.
    `ifdef ETH_RV_CLINT_CYCLE_STEP
        wire clint_step = 1'b1;
    `else
        wire clint_step = step_strobe;
    `endif
    logic [63:0] clint_mtime;   // the CLINT's mtime register == the `time` CSR
    logic [63:0] rom_entry;     // the payload entry the BootROM will jump to
    logic [13:0] rom_steps;     // the stub's instruction count, from the ROM image

    eth_rv_core u_dut (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .imem_req_o      (imem_req),
        .imem_addr_o     (imem_addr),
        .imem_ready_i    (imem_ready),
        .imem_rdata_i    (imem_rdata),
        .imem_err_i      (imem_err),
        .dmem_req_o      (core_dmem_req),
        .dmem_we_o       (core_dmem_we),
        .dmem_addr_o     (core_dmem_addr),
        .dmem_wdata_o    (core_dmem_wdata),
        .dmem_wstrb_o    (core_dmem_wstrb),
        .dmem_size_o     (core_dmem_size),
        .dmem_ready_i    (core_dmem_ready),
        .dmem_rdata_i    (core_dmem_rdata),
        .dmem_err_i      (core_dmem_err),
        .msip_i          (msip),
        .mtip_i          (mtip),
        // The PLIC's two contexts (E2-RV2 increment 6). `+plic_swap=1` crosses
        // them — the negative control for the context split.
        .meip_i          (plic_swap != 0 ? seip : meip),
        .seip_i          (plic_swap != 0 ? meip : seip),
        .mtime_i         (clint_mtime),   // the `time` CSR's source (E2-RV2 inc. 4)
        .rvfi_valid_o    (rvfi_valid),
        .rvfi_order_o    (rvfi_order),
        .rvfi_pc_o       (rvfi_pc),
        .rvfi_insn_o     (rvfi_insn),
        .rvfi_rd_we_o    (rvfi_rd_we),
        .rvfi_rd_addr_o  (rvfi_rd_addr),
        .rvfi_rd_wdata_o (rvfi_rd_wdata),
        .rvfi_rd_fp_o    (rvfi_rd_fp),
        .rvfi_fflags_we_o(rvfi_fflags_we),
        .rvfi_fflags_o   (rvfi_fflags),
        .rvfi_frm_we_o   (rvfi_frm_we),
        .rvfi_frm_o      (rvfi_frm),
        .rvfi_mem_valid_o(rvfi_mem_valid),
        .rvfi_mem_addr_o (rvfi_mem_addr),
        .rvfi_mem_wdata_o(rvfi_mem_wdata),
        .rvfi_mem_wmask_o(rvfi_mem_wmask),
        .rvfi_mem_rmask_o(rvfi_mem_rmask),
        .rvfi_mem_paddr_o(rvfi_mem_paddr),
        .err_o           (core_err),
        .err_pc_o        (core_err_pc),
        .err_insn_o      (core_err_insn),
        .err_code_o      (core_err_code),
        .err_irq_o       (core_err_irq),
        .err_tval_o      (core_err_tval),
        .step_o          (step_strobe)
    );

    // ------------------------------------------------------------- SoC MMIO decode
    // The core has ONE data port; the console UART is decoded in front of the
    // memory path (rtl/eth_rv/eth_rv_mmio_mux.sv). Everything the memory side
    // sees is unchanged for a non-device address, so both D-port builds below
    // keep their existing behavior bit for bit.
    eth_rv_mmio_mux #(
        .UART_BASE      (UART_BASE),
        .UART_BIT_CYCLES(UART_DIV),
        .UART_FIFO_DEPTH(UART_FIFO_DEPTH),
        .ROM_BASE       (ROM_BASE),
        .ROM_BYTES      (ROM_BYTES),
        .ROM_ENTRY_WORD (ROM_ENTRY_WORD),
        .ROM_STUB_WORD  (ROM_STUB_WORD),
        .CLINT_STEP_PRELOAD (CLINT_STEP_PRELOAD),
        .CLINT_RTC_TICK_STEPS   (CLINT_RTC_TICK_STEPS),
        .CLINT_RTC_TICK_ADVANCE (CLINT_RTC_TICK_ADVANCE),
        .PLIC_BASE      (PLIC_BASE),
        .PLIC_SIZE      (PLIC_SIZE),
        .PLIC_NDEV      (PLIC_NDEV),
        .PLIC_PRIO_BITS (PLIC_PRIO_BITS)
    ) u_mmio (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .req_i          (core_dmem_req),
        .we_i           (core_dmem_we),
        .addr_i         (core_dmem_addr),
        .wdata_i        (core_dmem_wdata),
        .wstrb_i        (core_dmem_wstrb),
        .size_i         (core_dmem_size),
        .ready_o        (core_dmem_ready),
        .rdata_o        (core_dmem_rdata),
        .err_o          (core_dmem_err),
        .mem_req_o      (dmem_req),
        .mem_we_o       (dmem_we),
        .mem_addr_o     (dmem_addr),
        .mem_wdata_o    (dmem_wdata),
        .mem_wstrb_o    (dmem_wstrb),
        .mem_ready_i    (dmem_ready),
        .mem_rdata_i    (dmem_rdata),
        .mem_err_i      (dmem_err),
        .uart_rx_i      (uart_rx_line),
        .uart_tx_o      (uart_tx),
        .uart_busy_o    (uart_busy),
        .uart_overflow_o(uart_overflow),
        .uart_rx_overflow_o (uart_rx_overflow),
        .uart_rx_frame_err_o(uart_rx_frame_err),
        .msip_o         (msip),
        .mtip_o         (mtip),
        .meip_o         (meip),
        .seip_o         (seip),
        .mtime_o        (clint_mtime),
        .step_i         (clint_step),
        .rom_entry_o    (rom_entry),
        .rom_steps_o    (rom_steps)
    );

    // ------------------------------------------------------------------ I port
    // The mapped-memory window of this build. A fetch or data access outside it
    // is answered with an ERROR RESPONSE (ready + err in the same cycle), which
    // is the RTL's image of the address map Spike and `eth_dram_ctrl` agree on:
    // Spike's `bus_t` has no device for such an address (`mmio_load/fetch`
    // returns false) and the DRAM socket answers DECERR outside its window, so
    // both raise an access fault. An in-window address is served as before.
    // The SoC's map on this port is the memory window plus the BootROM window: a
    // fetch from the ROM (0x1000) is the reset path now, and it is served from the
    // same `eth_rv_boot_rom` image the D port reads through the MMIO mux. The
    // console page has no counterpart here, so a FETCH from it faults (exactly what
    // Spike does: its ns16550 rejects the 4-byte fetch by `reg_io_width != len`);
    // no corpus program fetches there.
`ifdef ETH_RV_DRAM_AXI
    function automatic logic in_mem(input logic [63:0] addr);
        in_mem = (addr >= 64'(DRAM_BASE)) && (addr < (64'(DRAM_BASE) + 64'(DRAM_BYTES)));
    endfunction
`else
    function automatic logic in_mem(input logic [63:0] addr);
        in_mem = (addr >= base_addr) && (addr < (base_addr + 64'(MEM_WORDS * 8)));
    endfunction
`endif

    logic        imem_pend;
    logic [63:0] imem_addr_q;
    int unsigned imem_wait;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_pend   <= 1'b0;
            imem_addr_q <= 64'd0;
            imem_wait   <= 0;
        end else if (!imem_req) begin
            imem_pend <= 1'b0;
            imem_wait <= 0;
        end else if (!imem_pend || (imem_addr_q != imem_addr)) begin
            imem_pend   <= 1'b1;
            imem_addr_q <= imem_addr;
            imem_wait   <= 0;
        end else if (imem_wait < mem_lat) begin
            imem_wait <= imem_wait + 1;
        end
    end

    assign imem_ready = imem_req
                        && ((mem_lat == 0)
                            || (imem_pend && (imem_addr_q == imem_addr)
                                && (imem_wait >= mem_lat)));
    assign imem_rdata = imem_req ? (in_rom(imem_addr) ? rom_read32(imem_addr)
                                                      : read_bytes32(imem_addr))
                                 : 32'd0;
    // the error rides the accept, so the core can never mistake "not ready yet"
    // for "this address has no instruction"
    assign imem_err   = imem_ready && !(in_mem(imem_addr) || in_rom(imem_addr));

    // ------------------------------------------------------------------ D port
`ifdef ETH_RV_DRAM_AXI
    // ---- D port through the AXI4 master into the DRAM socket -------------
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [31:0] m_axi_awaddr;
    logic [7:0]  m_axi_awlen;
    logic [2:0]  m_axi_awsize;
    logic [1:0]  m_axi_awburst;
    logic [3:0]  m_axi_awid;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [63:0] m_axi_wdata;
    logic [7:0]  m_axi_wstrb;
    logic        m_axi_wlast;
    logic        m_axi_bvalid;
    logic        m_axi_bready;
    logic [1:0]  m_axi_bresp;
    logic [3:0]  m_axi_bid;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [31:0] m_axi_araddr;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic [3:0]  m_axi_arid;
    logic        m_axi_rvalid;
    logic        m_axi_rready;
    logic [63:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rlast;
    logic [3:0]  m_axi_rid;
    logic        axi_err;

    eth_rv_axi_master #(
        .AXI_AW     (32),
        .AXI_DW     (64),
        .AXI_IDW    (4),
        .LINE_BEATS (`ETH_RV_LINE_BEATS),
        .MEM_BASE   (DRAM_BASE),
        .MEM_BYTES  (DRAM_BYTES)
    ) u_master (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .dmem_req_i    (dmem_req),
        .dmem_we_i     (dmem_we),
        .dmem_addr_i   (dmem_addr),
        .dmem_wdata_i  (dmem_wdata),
        .dmem_wstrb_i  (dmem_wstrb),
        .dmem_ready_o  (dmem_ready),
        .dmem_rdata_o  (dmem_rdata),
        .dmem_err_o    (dmem_err_raw),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_awid    (m_axi_awid),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bid     (m_axi_bid),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arid    (m_axi_arid),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rid     (m_axi_rid),
        .axi_err_o     (axi_err)
    );

    eth_dram_ctrl #(
        .AXI_AW     (32),
        .AXI_DW     (64),
        .AXI_IDW    (4),
        .MEM_BASE   (DRAM_BASE),
        .MEM_BYTES  (DRAM_BYTES),
        .RD_LATENCY (4),
        .WR_LATENCY (2)
    ) u_dram (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .s_axi_awvalid  (m_axi_awvalid),
        .s_axi_awready  (m_axi_awready),
        .s_axi_awaddr   (m_axi_awaddr),
        .s_axi_awid     (m_axi_awid),
        .s_axi_awlen    (m_axi_awlen),
        .s_axi_awsize   (m_axi_awsize),
        .s_axi_awburst  (m_axi_awburst),
        .s_axi_awcache  (4'd0),
        .s_axi_awprot   (3'd0),
        .s_axi_awqos    (4'd0),
        .s_axi_awregion (4'd0),
        .s_axi_awlock   (1'b0),
        .s_axi_wvalid   (m_axi_wvalid),
        .s_axi_wready   (m_axi_wready),
        .s_axi_wdata    (m_axi_wdata),
        .s_axi_wstrb    (m_axi_wstrb),
        .s_axi_wlast    (m_axi_wlast),
        .s_axi_bvalid   (m_axi_bvalid),
        .s_axi_bready   (m_axi_bready),
        .s_axi_bresp    (m_axi_bresp),
        .s_axi_bid      (m_axi_bid),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_araddr   (m_axi_araddr),
        .s_axi_arid     (m_axi_arid),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arcache  (4'd0),
        .s_axi_arprot   (3'd0),
        .s_axi_arqos    (4'd0),
        .s_axi_arregion (4'd0),
        .s_axi_arlock   (1'b0),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .s_axi_rid      (m_axi_rid)
    );

    // AXI traffic counters: proof that the corpus really drove the socket, and
    // how much of it was carried by multi-beat INCR bursts.
    int unsigned n_axi_ar;
    int unsigned n_axi_aw;
    int unsigned n_axi_r_beats;
    int unsigned n_axi_w_beats;
    int unsigned n_axi_r_bursts;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_axi_ar       <= 0;
            n_axi_aw       <= 0;
            n_axi_r_beats  <= 0;
            n_axi_w_beats  <= 0;
            n_axi_r_bursts <= 0;
        end else begin
            if (m_axi_arvalid && m_axi_arready) begin
                n_axi_ar <= n_axi_ar + 1;
                if (m_axi_arlen != 8'd0) begin
                    n_axi_r_bursts <= n_axi_r_bursts + 1;
                end
            end
            if (m_axi_awvalid && m_axi_awready) n_axi_aw <= n_axi_aw + 1;
            if (m_axi_rvalid && m_axi_rready) n_axi_r_beats <= n_axi_r_beats + 1;
            if (m_axi_wvalid && m_axi_wready) n_axi_w_beats <= n_axi_w_beats + 1;
        end
    end
`else
    // v0 build: the behavioral beat memory, served out of `mem`
    logic        dmem_pend;
    logic [63:0] dmem_addr_q;
    int unsigned dmem_wait;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_pend   <= 1'b0;
            dmem_addr_q <= 64'd0;
            dmem_wait   <= 0;
        end else if (!dmem_req) begin
            dmem_pend <= 1'b0;
            dmem_wait <= 0;
        end else if (!dmem_pend || (dmem_addr_q != dmem_addr)) begin
            dmem_pend   <= 1'b1;
            dmem_addr_q <= dmem_addr;
            dmem_wait   <= 0;
        end else if (dmem_wait < mem_lat) begin
            dmem_wait <= dmem_wait + 1;
        end
    end

    // `+starve_dmem=1` (the wedge negative control) withholds the acknowledge
    // for an out-of-window access, i.e. it reproduces the old hang on purpose.
    assign dmem_ready = dmem_req
                        && !((starve_dmem != 0) && !in_mem(dmem_addr))
                        && ((mem_lat == 0)
                            || (dmem_pend && (dmem_addr_q == dmem_addr)
                                && (dmem_wait >= mem_lat)));
    // aligned beat: the eight bytes of the window at (addr & ~7) — read through
    // `mem_word`, which bounds-checks, so an out-of-window beat reads zero rather
    // than an arbitrary array slot (it is an ERROR response anyway).
    assign dmem_rdata = dmem_req ? (mem_word(dmem_addr & ~64'd7)
                                    ^ (dmem_corrupt_hit ? dmem_corrupt_xor : 64'd0))
                                 : 64'd0;
    // Outside the mapped window the access is an error response, in the same
    // cycle it is accepted — the same "ready + err" shape the DRAM socket's
    // DECERR produces through `eth_rv_axi_master` in the other build.
    assign dmem_err_raw = dmem_ready && !in_mem(dmem_addr);

    // The walk-injection control (see `dmem_corrupt_addr`): it corrupts the beat
    // the port returns for one 8-byte-aligned window, so a PTE the walker reads is
    // not the PTE the program wrote.
    wire dmem_corrupt_hit = (dmem_corrupt_xor != 64'd0)
                            && ((dmem_addr & ~64'd7) == dmem_corrupt_addr);

    // byte-lane write, at the cycle the access is accepted
    integer      lane;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // nothing to reset: the array is filled from +mem at time 0
        end else if (dmem_req && dmem_we && dmem_ready && in_mem(dmem_addr)) begin
            for (lane = 0; lane < 8; lane = lane + 1) begin
                if (dmem_wstrb[lane]) begin
                    // lane `lane` of the aligned beat holds the byte for (addr & ~7) + lane
                    mem[word_of(dmem_addr & ~64'd7)][{lane[2:0], 3'b000} +: 8]
                        <= dmem_wdata[{lane[2:0], 3'b000} +: 8];
                end
            end
        end
    end
`endif

    // The `+no_dmem_err` silent-success control: with it set, an unservable access
    // looks like an ordinary successful beat, so the core retires it instead of
    // taking the access fault. Nothing inside the DUT knows about the control —
    // what the DiffTest compares is the DUT's trace against Spike's, which is
    // exactly the "no silent success" property under test.
    assign dmem_err = dmem_err_raw && (no_dmem_err == 0);

    // ------------------------------------------------------- console UART RX line
    // The DUT's receiver input. It idles high; `+uart_rx=` serialises the bytes
    // the self-check below expects to find in the DUT's receive queue.
    logic        uart_rx_line;
    logic        uart_rx_overflow;
    logic        uart_rx_frame_err;

    logic [7:0]  rx_inj_bytes [0:UART_MAX_BYTES-1];
    int unsigned rx_inj_len;
    int unsigned rx_inj_idx;
    logic [3:0]  rx_inj_cell;      // 0 = start, 1..8 = data LSB first, 9 = stop
    logic [15:0] rx_inj_cnt;       // cycles left in the current cell
    logic [15:0] rx_inj_wait;      // cycles left before the burst starts
    logic        rx_inj_start;     // the burst's first cell is being presented
    logic        rx_inj_finished;  // the burst ran to its last stop cell
    logic        rx_inj_done;
    string       rx_self_note;     // the PASS line's RX self-test field

    // `+uart_rx=<hex>`'s two digits per byte. Plain character arithmetic, written
    // against the ASCII codes rather than the characters so nothing depends on
    // string-literal typing.
    function automatic logic [3:0] hex_nib(input byte c);
        if ((c >= 8'h30) && (c <= 8'h39))      hex_nib = 4'(c - 8'h30);
        else if ((c >= 8'h61) && (c <= 8'h66)) hex_nib = 4'(c - 8'h61 + 8'd10);
        else if ((c >= 8'h41) && (c <= 8'h46)) hex_nib = 4'(c - 8'h41 + 8'd10);
        else                                   hex_nib = 4'd0;
    endfunction

    // One 10-cell frame per byte at the transmitter's divisor, back to back.
    // `rx_inj_done` is "there is nothing left to send": no injection at all, or the
    // burst finished. It cannot be a plain register: the plusarg is decoded before
    // reset is released, while the register's reset value is evaluated when it is
    // still 0 — a register would latch "done" for every injection.
    assign rx_inj_done = (rx_inj_len == 0) || rx_inj_finished;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_inj_idx      <= 0;
            rx_inj_cell     <= 4'd0;
            rx_inj_cnt      <= 16'd0;
            rx_inj_wait     <= 16'(RX_INJ_DELAY);
            rx_inj_start    <= 1'b0;
            rx_inj_finished <= 1'b0;
        end else if (rx_inj_finished || (rx_inj_len == 0)) begin
            rx_inj_cnt <= 16'd0;
        end else if (!rx_inj_start) begin
            // The delay elapses first; the last cycle of it PRIMES the first cell's
            // counter, so the start bit is presented for a whole bit cell rather
            // than the single cycle it would get if the FSM advanced straight into
            // cell 1 (that one-cycle start bit is invisible to the receiver).
            if (rx_inj_wait != 16'd0) begin
                rx_inj_wait <= rx_inj_wait - 16'd1;
            end else begin
                rx_inj_start <= 1'b1;
                rx_inj_cnt   <= 16'(UART_DIV - 1);
            end
        end else if (rx_inj_cnt == 16'd0) begin
            // the current cell is over: step to the next one, or end the burst
            if ((rx_inj_cell == 4'd9) && ((rx_inj_idx + 1) == rx_inj_len)) begin
                rx_inj_finished <= 1'b1;
            end else begin
                if (rx_inj_cell == 4'd9) begin
                    rx_inj_idx  <= rx_inj_idx + 1;
                    rx_inj_cell <= 4'd0;
                end else begin
                    rx_inj_cell <= rx_inj_cell + 4'd1;
                end
                rx_inj_cnt <= 16'(UART_DIV - 1);
            end
        end else begin
            rx_inj_cnt <= rx_inj_cnt - 16'd1;
        end
    end

    // The cell's value, with the one-cell fault the negative control injects.
    always_comb begin
        logic bit_val;
        bit_val = 1'b1;                                            // stop / idle
        if (rx_inj_cell == 4'd0) begin
            bit_val = 1'b0;                                        // start
        end else if (rx_inj_cell <= 4'd8) begin
            bit_val = rx_inj_bytes[rx_inj_idx][rx_inj_cell[2:0] - 3'd1];  // data, LSB first
        end
        if ((uart_rx_fault_frame >= 0) && (int'(rx_inj_idx) == uart_rx_fault_frame)
            && (int'(rx_inj_cell) == uart_rx_fault_bit)) begin
            bit_val = ~bit_val;
        end
        uart_rx_line = (!rst_n || rx_inj_done || (rx_inj_len == 0)
                        || (rx_inj_wait != 16'd0)) ? 1'b1 : bit_val;
    end

    // ------------------------------------------------------------------ console
    // Receiver-side model of the SoC UART's serial line (a standard 8N1 mid-bit
    // sampler using the SAME divisor the transmitter was built with), so what
    // the runner asserts is a bit-timing property and not just a byte count:
    //   * every frame is start(0) + eight data bits LSB first + stop(1), and
    //     each of its ten bit cells is sampled at its center;
    //   * consecutive frames inside a burst are exactly UART_FRAME_CYCLES cycles
    //     apart (start edge to start edge) — the transmit queue never runs dry
    //     mid-burst, so the whole string holds one bit rate;
    //   * the bytes that come out are the string the program wrote.
    // A frame error (start not low, stop not high), a FIFO overflow at the
    // transmitter and a receiver-buffer overflow are all counted; the runner
    // requires zero. `+uart_fault_frame=N +uart_fault_bit=M` inverts one bit
    // cell of one received frame on the way in: a verification-only line fault,
    // the negative control for the assertion above.
    localparam logic [15:0] RX_RELOAD_START = 16'(UART_DIV / 2 - 1);
    localparam logic [15:0] RX_RELOAD       = 16'(UART_DIV - 1);

    logic        rx_active;
    logic [15:0] rx_baud_cnt;
    logic [3:0]  rx_cell;
    logic [7:0]  rx_acc;
    // `+uart_marker=<hex>` (S4): a rolling match over the decoded bytes. Instead
    // of a windowed compare (which would need a procedural loop, G1), the position
    // of the match advances one byte at a time — the classic streaming pattern
    // matcher — so the stop costs one comparison per received frame.
    localparam int unsigned MARKER_MAX = 96;
    logic [7:0]  marker_bytes [0:MARKER_MAX-1];
    int unsigned marker_len;
    int unsigned marker_pos;
    bit          marker_hit;
    logic [7:0]  rx_bytes [0:UART_MAX_BYTES-1];
    int unsigned rx_nbytes;
    int unsigned rx_nframes;
    int unsigned rx_errors;
    int unsigned rx_prev_start;
    int unsigned rx_gap_min;
    int unsigned rx_gap_max;
    int unsigned rx_cycles;
    bit          rx_start_seen;
    bit          rx_gap_seen;
    bit          rx_buf_overflow;
    bit          rx_fault_active;

    wire uart_line = uart_tx ^ rx_fault_active;

    assign rx_fault_active = (uart_fault_frame >= 0)
                             && (int'(rx_nframes) == uart_fault_frame)
                             && (int'(rx_cell) == uart_fault_bit)
                             && rx_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_active       <= 1'b0;
            rx_baud_cnt     <= 16'd0;
            rx_cell         <= 4'd0;
            rx_acc          <= 8'h00;
            rx_nbytes       <= 0;
            rx_nframes      <= 0;
            rx_errors       <= 0;
            rx_prev_start   <= 0;
            rx_gap_min      <= 0;
            rx_gap_max      <= 0;
            rx_cycles       <= 0;
            rx_start_seen   <= 1'b0;
            rx_gap_seen     <= 1'b0;
            rx_buf_overflow <= 1'b0;
        end else begin
            rx_cycles <= rx_cycles + 1;
            if (!rx_active) begin
                if (!uart_line) begin          // start-bit falling edge
                    rx_active   <= 1'b1;
                    rx_baud_cnt <= RX_RELOAD_START;
                    rx_cell     <= 4'd0;
                    rx_acc      <= 8'h00;
                    if (rx_start_seen) begin   // gap = start edge to start edge
                        rx_gap_min <= (rx_gap_seen && ((rx_cycles - rx_prev_start) >= rx_gap_min))
                                      ? rx_gap_min : (rx_cycles - rx_prev_start);
                        rx_gap_max <= (rx_gap_seen && ((rx_cycles - rx_prev_start) <= rx_gap_max))
                                      ? rx_gap_max : (rx_cycles - rx_prev_start);
                        rx_gap_seen <= 1'b1;
                    end else begin
                        rx_start_seen <= 1'b1;
                    end
                    rx_prev_start <= rx_cycles;
                end
            end else if (rx_baud_cnt == 16'd0) begin
                rx_baud_cnt <= RX_RELOAD;      // next bit cell, sampled at its center
                rx_cell     <= rx_cell + 4'd1;
                if (rx_cell == 4'd0) begin
                    if (uart_line) rx_errors <= rx_errors + 1;    // start bit must be low
                end else if (rx_cell == 4'd9) begin
                    if (!uart_line) rx_errors <= rx_errors + 1;   // stop bit must be high
                    rx_active <= 1'b0;
                    rx_nframes <= rx_nframes + 1;
                    if (rx_nbytes < UART_MAX_BYTES) begin
                        rx_bytes[rx_nbytes] <= rx_acc;
                        rx_nbytes <= rx_nbytes + 1;
                        // the live copy: written and flushed per byte, so an abort
                        // cannot lose the console (see the +uart= open above)
                        if (uart_fd != 0) begin
                            $fwrite(uart_fd, "%c", rx_acc);
                            $fflush(uart_fd);
                        end
                    end else begin
                        rx_buf_overflow <= 1'b1;
                    end
                    // `+uart_marker`: the milestone is a console string, so the
                    // stop is defined on the decoded line (see the plusarg).
                    if (marker_len != 0) begin
                        if (rx_acc == marker_bytes[marker_pos]) begin
                            if (marker_pos + 1 >= marker_len) begin
                                marker_hit <= 1'b1;   // the whole marker has been seen
                            end else begin
                                marker_pos <= marker_pos + 1;
                            end
                        end else begin
                            // Restart from the first byte when this one could have
                            // started the marker. `marker_len > 1` keeps the position
                            // inside the marker for a one-byte marker (where a match
                            // is a hit, never an advance).
                            marker_pos <= ((marker_len > 1) && (rx_acc == marker_bytes[0]))
                                          ? 1 : 0;
                        end
                    end
                end else begin
                    rx_acc <= {uart_line, rx_acc[7:1]};           // data bits, LSB first
                end
            end else begin
                rx_baud_cnt <= rx_baud_cnt - 16'd1;
            end
        end
    end

    // ------------------------------------------------------------------ trace
    integer      trace_fd;
    integer      uart_fd;
    int unsigned drain_used;
    int unsigned commits;
    int unsigned n_compressed;
    int unsigned n_loads;
    int unsigned n_stores;
    int unsigned traps;
    int unsigned n_access_faults;   // EXCEPTIONS taken with mcause 1/5/7
    int unsigned n_pgfaults;        // ... and with mcause 12/13/15 (Sv39)
    int unsigned n_interrupts;      // traps that were interrupts

    // ---- WEDGE GUARD: a port request must be answered ----------------------
    // The RV-B D port used to hang on an access it could not serve (an
    // unimplemented offset inside the claimed console page): the decoder simply
    // never answered, and only the cycle budget ended the run. The error-response
    // contract (rtl/eth_rv/eth_rv_core.sv, eth_rv_mmio_mux.sv) is that EVERY
    // request is answered in the cycle it is made — with `ready` and, when the
    // access cannot be served, with `err` at the same time. This is the bounded
    // negative control for that: a request that stays unanswered for
    // PORT_STARVE_CYCLES is a hard FAIL naming the address, long before the
    // (much looser) cycle budget. The bound cannot trip on a legitimate wait: the
    // slowest allowed round trip is an AXI read line fill plus the socket's read
    // latency, well under a hundred cycles, and the optional `+memlat` stall
    // counter is `mem_lat` (1..2 in every run the runner makes).
    localparam int unsigned PORT_STARVE_CYCLES = 4096;
    int unsigned progress_cnt;      // +progress: cycles since the last progress line
    int unsigned dport_wait;        // consecutive cycles with an unanswered D-port request
    int unsigned iport_wait;
    int unsigned dport_wait_max;    // ... and the longest such wait in the whole run
    int unsigned iport_wait_max;
    logic [3:0]  last_trap_cause;
    logic [63:0] last_mem_addr;
    logic [63:0] last_mem_paddr;   // ... its physical address (Sv39 runs differ)
    logic [63:0] last_store_data;
    logic [31:0] last_insn;
    int unsigned cycle_cnt;
    bit          stop_now;
    bit          failed;
    // ---- boot handshake + trace window (E2-RV2 increment 5, S3) -------------
    // `entry_addr` is what the harness asked for (`+entry`); `rom_entry` is what
    // the ROM image actually holds; `entry_seen` says the payload entry was
    // retired; `rom_a0_seen`/`rom_a1_seen` say the stub's two architectural
    // writes retired inside the ROM. `trace_on`/`cycle_base` implement the
    // renumbered trace window (`cycle_now` is the ordinal the dump prints).
    logic [63:0] cycle_base;
    logic [63:0] trace_from_pc;
    logic [63:0] cycle_now;
    bit          started_now;
    bit          started_now_rec;
    bit          trace_on;
    bit          trace_on_run;   // `+trace` given: dump commit records (S4 boots without one)
    logic [63:0] a1_check_addr;  // the DTB address the ROM stub must leave in a1
    logic [63:0] rom_a0_val;     // the value the stub left in a0 (its last write)
    logic [63:0] rom_a1_val;     // ... and in a1: the two are checked at the handoff
    bit          rom_a0_seen;
    bit          rom_a1_seen;
    bit          entry_seen;
    // Commits retired BEFORE the payload entry: the BootROM stub's executed
    // instructions. The image states that count (`rom_steps`, the word the CLINT
    // swallows) and the hart's step cadence depends on the two agreeing, so they
    // are held against each other at the handoff — a stub with a branch, a trap or
    // a lost `_rom_steps` word fails here instead of shifting `time` silently.
    int unsigned pre_entry_retires;
    logic        pre_entry_now;
    // The trace window is a pure function of the current commit and the state:
    // `started_now` is true in the very cycle the first in-window commit retires,
    // and `cycle_now` is the ordinal the dump prints for it (1 at the window's
    // first commit — the golden stream's numbering).
    assign started_now = rvfi_valid && (trace_on || (rvfi_pc == trace_from_pc));
    assign cycle_now   = rvfi_order - (trace_on ? cycle_base : (rvfi_order - 64'd1));
    assign pre_entry_now = rvfi_valid && !entry_seen && (rvfi_pc != entry_addr);
    // The S4 DiffTest's declared synchronisation point: the commit at `+stop_pc`
    // (OpenSBI's jump into the kernel) ends the run and is deliberately NOT part
    // of the trace, so the dump is exactly the firmware portion the golden is cut
    // to. Without `+stop_pc` this is never true and nothing changes.
    wire at_stop_pc = rvfi_valid && stop_pc_en && (rvfi_pc == stop_pc);
    assign started_now_rec = started_now && !at_stop_pc;

    // `fault_index` is a 0-based commit index, matching the harness's --inject.
    // Fault injection mirrors rv_difftest's own --inject INDEX:FIELD=VALUE: an `rd`
    // fault invents a write (with value 0) even on a commit that had none, so any
    // commit index can be used as the injection point.
    logic        f_we;
    logic [63:0] f_pc;
    logic [4:0]  f_rd;
    logic [63:0] f_value;
    logic [63:0] f_mem_addr;
    logic [63:0] f_mem_wdata;
    logic        f_mem_valid;
    logic [7:0]  f_mem_rmask;
    logic [7:0]  f_mem_wmask;
    logic        f_rd_fp;
    logic        f_fflags_we;
    logic [4:0]  f_fflags;
    logic        f_frm_we;
    logic [2:0]  f_frm;

    always_comb begin
        f_we        = rvfi_rd_we;
        f_pc        = rvfi_pc;
        f_rd        = rvfi_rd_addr;
        f_value     = rvfi_rd_wdata;
        f_mem_valid = rvfi_mem_valid;
        f_mem_addr  = rvfi_mem_addr;
        f_mem_wdata = rvfi_mem_wdata;
        f_mem_rmask = rvfi_mem_rmask;
        f_mem_wmask = rvfi_mem_wmask;
        f_rd_fp     = rvfi_rd_fp;
        f_fflags_we = rvfi_fflags_we;
        f_fflags    = rvfi_fflags;
        f_frm_we    = rvfi_frm_we;
        f_frm       = rvfi_frm;
        if (commits == fault_index) begin
            if (fault_field == "pc") begin
                f_pc = fault_value;
            end
            if (fault_field == "value") begin
                f_value = fault_value;
            end
            if (fault_field == "rd") begin
                f_we    = 1'b1;
                f_rd    = fault_value[4:0];
                f_value = rvfi_rd_we ? rvfi_rd_wdata : 64'd0;
            end
            // The FP-record negative controls (E2-RV2 increment 2): corrupt the
            // fflags accrual or the frm value of one commit. Both INVENT the update
            // when the commit has none, so any commit index is a valid injection
            // point — the point is that the harness's FP comparison must fire.
            if (fault_field == "fflags") begin
                f_fflags_we = 1'b1;
                f_fflags    = fault_value[4:0];
            end
            if (fault_field == "frm") begin
                f_frm_we = 1'b1;
                f_frm    = fault_value[2:0];
            end
            // The memory-stream negative control: corrupt the address or the store
            // data this commit reports. A fault on a commit without an access
            // invents one, exactly like `rd` invents a register write, so the
            // corruption is always visible.
            if (fault_field == "mem_addr") begin
                f_mem_valid = 1'b1;
                f_mem_addr  = fault_value;
                f_mem_rmask = rvfi_mem_valid ? rvfi_mem_rmask : 8'd0;
                f_mem_wmask = rvfi_mem_valid ? rvfi_mem_wmask : 8'd0;
            end
            if (fault_field == "mem_wdata") begin
                f_mem_valid = 1'b1;
                f_mem_wdata = fault_value;
                // keep a legal mask: report it as a write when the commit has none
                f_mem_wmask = (rvfi_mem_wmask != 8'd0) ? rvfi_mem_wmask
                            : (rvfi_mem_rmask != 8'd0) ? 8'd0 : 8'd1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            commits         <= 0;
            n_compressed    <= 0;
            n_loads         <= 0;
            n_stores        <= 0;
            traps           <= 0;
            n_access_faults <= 0;
            n_pgfaults      <= 0;
            n_interrupts    <= 0;
            dport_wait      <= 0;
            iport_wait      <= 0;
            dport_wait_max  <= 0;
            iport_wait_max  <= 0;
            last_trap_cause <= 4'd0;
            last_mem_addr   <= 64'd0;
            last_mem_paddr  <= 64'd0;
            last_store_data <= 64'd0;
            last_insn       <= 32'd0;
            cycle_cnt       <= 0;
            stop_now        <= 1'b0;
            failed          <= 1'b0;
            cycle_base      <= 64'd0;
            trace_on        <= 1'b0;
            rom_a0_val      <= 64'd0;
            rom_a1_val      <= 64'd0;
            rom_a0_seen     <= 1'b0;
            rom_a1_seen     <= 1'b0;
            entry_seen      <= 1'b0;
            pre_entry_retires <= 0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;

            // ---- console-marker stop (`+uart_marker`, S4) ---------------------
            // Userspace's first line is a console event, not a store, so the S4
            // milestone stops here: one cycle after the receiver decoded the last
            // byte of the marker. The cycle count reported is this cycle's — the
            // marker's own frame has already been accounted for in the UART record.
            if (!stop_now && marker_hit) begin
                stop_now <= 1'b1;
            end

            // ---- progress line (`+progress`, for runs too long to wait blind) --
            progress_cnt <= progress_cnt + 1;
            if ((progress_cycles != 0) && (progress_cnt >= progress_cycles) && !stop_now) begin
                progress_cnt <= 0;
                $display("ETH_RV_TB_INFO: progress cycle=%0d commits=%0d traps=%0d pgfaults=%0d console=%0d pc=0x%016x",
                         cycle_cnt, commits, traps, n_pgfaults, rx_nbytes, imem_addr);
            end

            // ---- wedge guard: every port request is answered (see the comment
            // on PORT_STARVE_CYCLES) ------------------------------------------
            if (core_dmem_req && !core_dmem_ready) begin
                dport_wait <= dport_wait + 1;
                if ((dport_wait + 1) > dport_wait_max) begin
                    dport_wait_max <= dport_wait + 1;
                end
            end else begin
                dport_wait <= 0;
            end
            if (imem_req && !imem_ready) begin
                iport_wait <= iport_wait + 1;
                if ((iport_wait + 1) > iport_wait_max) begin
                    iport_wait_max <= iport_wait + 1;
                end
            end else begin
                iport_wait <= 0;
            end

            if (rvfi_valid && !stop_now) begin
                // ---- BootROM handshake (E2-RV2 increment 5, S3) -----------------
                // The reset stub is the only code that runs before the payload, so
                // its architectural effects are asserted HERE, in the RTL's own
                // terms: it must start at the ROM base, leave the hart id in a0 and
                // the DTB address in a1 before it jumps, and the entry it jumps
                // through must be the `+entry` the harness asked for. A wrong value
                // is a hard FAIL naming what was seen — never a trace divergence to
                // be puzzled over later, and never a silently mis-booted run. The
                // golden model cannot provide this check: it boots through Spike's
                // own reset vector, whose a1 is Spike's DTB, so the ROM's effect is
                // ground truth on the RTL side only (see the notes in
                // verif/eth_rv/README.md and local://s3-rtl-notes.md).
                if (rvfi_order == 64'd1) begin
                    if (!in_rom(rvfi_pc)) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the first commit is at 0x%016x, not inside the BootROM (0x%016x..0x%016x) — check RESET_PC",
                                 rvfi_pc, ROM_BASE, ROM_BASE + 64'(ROM_BYTES));
                    end
                    if (rom_entry != entry_addr) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the BootROM entry word is 0x%016x, expected 0x%016x (+entry did not land)",
                                 rom_entry, entry_addr);
                    end
                    if (rom_steps == 14'd0) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the BootROM image has no stub step count (its step-count word is zero) — wrong image, or boot_rom.S lost _rom_steps?");
                    end
                end
                // The stub's executed instructions, counted from the commit stream:
                // what the CLINT swallows must be exactly this (see pre_entry_retires).
                if (pre_entry_now && !stop_now) begin
                    pre_entry_retires <= pre_entry_retires + 1;
                end
                if (in_rom(rvfi_pc) && !entry_seen) begin
                    // Latch what the stub leaves in the two argument registers —
                    // the last write, not the first: a1 is built by a
                    // LUI/SLLI/SRLI sequence, so the value that matters is the one
                    // it holds when the payload starts.
                    if (rvfi_rd_we && (rvfi_rd_addr == 5'd10)) begin
                        rom_a0_seen <= 1'b1;
                        rom_a0_val  <= rvfi_rd_wdata;
                    end
                    if (rvfi_rd_we && (rvfi_rd_addr == 5'd11)) begin
                        rom_a1_seen <= 1'b1;
                        rom_a1_val  <= rvfi_rd_wdata;
                    end
                end
                if (!entry_seen && (rvfi_pc == entry_addr)) begin
                    entry_seen <= 1'b1;
                    if (!(rom_a0_seen && rom_a1_seen)) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the payload entry 0x%016x was reached without the BootROM handshake (a0 written=%0d, a1 written=%0d)",
                                 entry_addr, rom_a0_seen, rom_a1_seen);
                    end else if (rom_a0_val != 64'd0) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the BootROM left a0 = 0x%016x, expected the hart id 0",
                                 rom_a0_val);
                    end else if (rom_a1_val != a1_check_addr) begin
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the BootROM left a1 = 0x%016x, expected the DTB address 0x%016x",
                                 rom_a1_val, a1_check_addr);
                    end else if (pre_entry_retires != {18'd0, rom_steps}) begin
                        // The image's step count and the stub's actual retires must
                        // agree: the CLINT swallows the former, the `time` cadence
                        // depends on the latter (see the CLINT's MTIME CADENCE note).
                        failed   <= 1'b1;
                        stop_now <= 1'b1;
                        $display("ETH_RV_TB: FAIL the BootROM retired %0d instructions before the payload entry, but its image says %0d — stub and step-count word disagree",
                                 pre_entry_retires, rom_steps);
                    end
                end

                // ---- trace window ---------------------------------------------
                // The golden stream is Spike's commits AFTER its own reset vector
                // (rv_spike's `entry` rule), so the DUT dump starts at the PC the
                // ROM jumps to and renumbers that commit `cycle` 1 — the two
                // streams then line up without `--no-cycle-check`. `+trace_from`
                // overrides the start (pass the ROM base to diff the stub itself,
                // which a golden run started with `--disable-dtb --pc=0x1000`
                // produces). Commits before the window are still watched by the
                // guards above, never dumped.
                // Open the window on the commit that starts it: `started_now` is
                // already true for it (see the assignments above), so this only
                // latches the renumbering base for the commits that follow.
                if (!trace_on && (rvfi_pc == trace_from_pc)) begin
                    trace_on   <= 1'b1;
                    cycle_base <= rvfi_order - 64'd1;
                end
                if (started_now_rec) begin
                    commits <= commits + 1;
                    last_insn <= rvfi_insn;
                    if (rvfi_insn[1:0] != 2'b11) begin
                        n_compressed <= n_compressed + 1;
                    end
                    if (rvfi_mem_valid) begin
                        last_mem_addr  <= rvfi_mem_addr;
                        last_mem_paddr <= rvfi_mem_paddr;
                        if (rvfi_mem_rmask != 8'd0) begin
                            n_loads <= n_loads + 1;
                        end
                        if (rvfi_mem_wmask != 8'd0) begin
                            n_stores        <= n_stores + 1;
                            last_store_data <= rvfi_mem_wdata;
                        end
                    end

                    // The commit record, when this run is dumping one. The S4
                    // Linux boot runs hundreds of millions of commits and compares
                    // nothing commit by commit, so `+trace` is optional: without it
                    // the counters above still run and no file is written.
                    if (trace_on_run) begin
                    // Always the 8-field form: this dump is the memory-aware side of
                    // the DiffTest, so every commit states whether it touched memory
                    // (`-` address) and which bytes it read/wrote (masks `-` is
                    // reserved for "not reported", which this testbench never needs).
                    if (f_we) begin
                        if (f_rd_fp) begin
                            $fwrite(trace_fd, "%0d 0x%016x f%0d 0x%016x ", cycle_now,
                                    f_pc, f_rd, f_value);
                        end else begin
                            $fwrite(trace_fd, "%0d 0x%016x x%0d 0x%016x ", cycle_now,
                                    f_pc, f_rd, f_value);
                        end
                    end else begin
                        $fwrite(trace_fd, "%0d 0x%016x - - ", cycle_now,
                                f_pc);
                    end
                    if (f_mem_valid) begin
                        if (f_mem_wmask != 8'd0) begin
                            $fwrite(trace_fd, "0x%016x 0x%016x - 0x%02x",
                                    f_mem_addr, f_mem_wdata, f_mem_wmask);
                        end else begin
                            $fwrite(trace_fd, "0x%016x - 0x%02x -",
                                    f_mem_addr, f_mem_rmask);
                        end
                    end else begin
                        $fwrite(trace_fd, "- - - -");
                    end
                    // ... and the FP record: the keyed tokens of trace v2, present
                    // only in the commit that wrote the CSR (E2-RV2 increment 2)
                    if (f_fflags_we) begin
                        $fwrite(trace_fd, " fflags=0x%02x", {3'd0, f_fflags});
                    end
                    if (f_frm_we) begin
                        $fwrite(trace_fd, " frm=0x%02x", {5'd0, f_frm});
                    end
                    $fwrite(trace_fd, "\n");
                    end

                    // HTIF exit: the store that covers `tohost` is the last commit
                    if ((rvfi_mem_wmask != 8'd0) && (rvfi_mem_addr[63:3] == tohost_addr[63:3])
                        && rvfi_mem_wmask[tohost_addr[2:0]]) begin
                        stop_now <= 1'b1;
                    end
                    // ... and the generalized stop (`+stop_addr`/`+stop_value`, the
                    // harness's `--stop-store ADDR[:VALUE]`): the run ends at the
                    // store that hits the address, and the value too when one was
                    // given, so a program with no HTIF exit still stops where the
                    // comparator stops it.
                    if (stop_addr_en && (rvfi_mem_wmask != 8'd0)
                        && (rvfi_mem_addr[63:3] == stop_addr[63:3])
                        && rvfi_mem_wmask[stop_addr[2:0]]
                        && (!stop_value_en || (rvfi_mem_wdata == stop_value))) begin
                        stop_now <= 1'b1;
                    end
                    // ... and the S4 synchronisation point: the firmware's own last
                    // commit, the jump OpenSBI takes into the kernel. It ends the
                    // run and is the first commit the golden is not asked about.
                    if (at_stop_pc) begin
                        stop_now <= 1'b1;
                    end
                end
            end

            if (!stop_now && (dport_wait >= PORT_STARVE_CYCLES)) begin
                failed   <= 1'b1;
                stop_now <= 1'b1;
                $display("ETH_RV_TB: FAIL the D port never answered the access at 0x%016x (%0d cycles, we=%0d) — wedge",
                         core_dmem_addr, dport_wait + 1, core_dmem_we);
            end else if (!stop_now && (iport_wait >= PORT_STARVE_CYCLES)) begin
                failed   <= 1'b1;
                stop_now <= 1'b1;
                $display("ETH_RV_TB: FAIL the I port never answered the fetch at 0x%016x (%0d cycles) — wedge",
                         imem_addr, iport_wait + 1);
            end else if (core_err && !stop_now) begin
                if (trace_traps != 0) begin
                    $display("ETH_RV_TB: trap %0d pc=0x%016x cause=%0d tval=0x%016x insn=0x%08x irq=%0d",
                             traps + 1, core_err_pc, core_err_code, core_err_tval,
                             core_err_insn, core_err_irq);
                end
                // `+stop_trap_cause`: the first trap OF the declared kind
                // ends the run and is printed whether or not `+trace_traps` is set.
                // This is the diagnostic that turns a 10^9-cycle boot into a few
                // dozen lines ending at the trap nobody asked for.
                if (stop_trap_cause_en && (core_err_code == stop_trap_cause[3:0])) begin
                    $display("ETH_RV_TB: FAIL halting on cause %0d after %0d commits / %0d cycles: pc=0x%016x tval=0x%016x insn=0x%08x irq=%0d (%0d trap(s) before it)",
                             core_err_code, commits, cycle_cnt, core_err_pc,
                             core_err_tval, core_err_insn, core_err_irq, traps + 1);
                    failed   <= 1'b1;
                    stop_now <= 1'b1;
                end
                traps    <= traps + 1;
                last_trap_cause <= core_err_code;
                if (core_err_irq) begin
                    // Same small cause codes (SSI/MSI/... ), different class: the
                    // interrupt bit is what tells them apart, so count them apart.
                    n_interrupts <= n_interrupts + 1;
                end else if ((core_err_code == 4'd1) || (core_err_code == 4'd5)
                             || (core_err_code == 4'd7)) begin
                    n_access_faults <= n_access_faults + 1;
                end else if ((core_err_code == 4'd12) || (core_err_code == 4'd13)
                             || (core_err_code == 4'd15)) begin
                    n_pgfaults <= n_pgfaults + 1;
                end
                if (traps >= max_traps) begin
                    failed   <= 1'b1;
                    stop_now <= 1'b1;
                    $display("ETH_RV_TB: FAIL trap budget exceeded (%0d traps, last mcause=%0d pc=0x%016x insn=0x%08x)",
                             traps + 1, core_err_code, core_err_pc, core_err_insn);
                end
            end else if ((cycle_cnt > max_cycles) && !stop_now) begin
                failed   <= 1'b1;
                stop_now <= 1'b1;
                $display("ETH_RV_TB: FAIL cycle budget exceeded (%0d cycles, pc=0x%016x)",
                         cycle_cnt, imem_addr);
            end
        end
    end

    // ------------------------------------------------------------------ run
    initial begin
        base_addr    = 64'h0000_0000_8000_0000;
        tohost_addr  = 64'h0000_0000_8000_0000;
        mem_lat      = 0;
        max_cycles   = 200_000;
        max_traps    = 64;
        fault_index  = 0;
        fault_value  = 64'd0;
        fault_field  = "none";
        mem_path     = "";
        trace_path   = "";
        uart_path    = "";
        uart_drain_cycles = 20_000;
        uart_fault_frame  = -1;
        uart_fault_bit    = 0;
        plic_swap         = 0;
        uart_rx_hex       = "";
        rx_inj_len        = 0;
        // -1 disables the injection fault: a 0 here would invert the start cell of
        // the first injected frame (which is a real frame error, not a control).
        uart_rx_fault_frame = -1;
        uart_rx_fault_bit   = 0;
        starve_dmem       = 0;
        no_dmem_err       = 0;
        dmem_corrupt_addr = 64'd0;
        dmem_corrupt_xor  = 64'd0;
        trace_traps       = 0;
        rom_path          = DEFAULT_ROM_IMAGE;
        entry_addr        = 64'h0000_0000_8000_0000;   // the memory window base
        trace_from        = 64'd0;                     // 0: start at the entry (below)
        dtb_path          = "";
        mem_bytes_arg     = 0;                         // 0: the compiled window
        // S4: a1 defaults to the S3 contract value, the tree is expected in RAM via
        // `+dtb`, there is no PC-bound stop and no console marker.
        a1_addr           = 64'd0;                     // 0: the DTB_ADDR contract value
        rom_dtb           = 0;
        stop_pc           = 64'd0;
        stop_pc_en        = 1'b0;
        uart_marker_hex   = "";
        marker_len        = 0;
        progress_cycles   = 0;
        // `marker_pos`/`marker_hit` are the receiver's own state and are cleared
        // by that block's reset branch (see the marker match), like every other
        // register this testbench owns.
        rst_n        = 1'b0;

        void'($value$plusargs("mem=%s", mem_path));
        void'($value$plusargs("trace=%s", trace_path));
        void'($value$plusargs("base=%h", base_addr));
        void'($value$plusargs("tohost=%h", tohost_addr));
        void'($value$plusargs("memlat=%d", mem_lat));
        void'($value$plusargs("max_cycles=%d", max_cycles));
        void'($value$plusargs("max_traps=%d", max_traps));
        void'($value$plusargs("trace_traps=%d", trace_traps));
        void'($value$plusargs("dmem_corrupt_addr=%h", dmem_corrupt_addr));
        void'($value$plusargs("dmem_corrupt_xor=%h", dmem_corrupt_xor));
        void'($value$plusargs("fault_index=%d", fault_index));
        void'($value$plusargs("fault_value=%h", fault_value));
        void'($value$plusargs("fault_field=%s", fault_field));
        void'($value$plusargs("uart=%s", uart_path));
        void'($value$plusargs("uart_drain=%d", uart_drain_cycles));
        void'($value$plusargs("uart_fault_frame=%d", uart_fault_frame));
        void'($value$plusargs("uart_fault_bit=%d", uart_fault_bit));
        void'($value$plusargs("plic_swap=%d", plic_swap));
        void'($value$plusargs("uart_rx=%s", uart_rx_hex));
        void'($value$plusargs("uart_rx_fault_frame=%d", uart_rx_fault_frame));
        void'($value$plusargs("uart_rx_fault_bit=%d", uart_rx_fault_bit));
        void'($value$plusargs("starve_dmem=%d", starve_dmem));
        void'($value$plusargs("no_dmem_err=%d", no_dmem_err));
        void'($value$plusargs("rom=%s", rom_path));
        void'($value$plusargs("entry=%h", entry_addr));
        void'($value$plusargs("trace_from=%h", trace_from));
        void'($value$plusargs("dtb=%s", dtb_path));
        void'($value$plusargs("mem_bytes=%d", mem_bytes_arg));
        void'($value$plusargs("a1_addr=%h", a1_addr));
        void'($value$plusargs("rom_dtb=%d", rom_dtb));
        void'($value$plusargs("uart_marker=%s", uart_marker_hex));
        void'($value$plusargs("progress=%d", progress_cycles));
        stop_trap_cause_en = ($value$plusargs("stop_trap_cause=%d", stop_trap_cause) != 0);
        // `+uart=<file>` is also opened HERE, before anything can abort, and every
        // received byte is written and flushed as it arrives. The structured record
        // at the end of the run reopens the same path and replaces this live copy,
        // so a run that completes is unchanged — but a run that dies (a cycle-budget
        // FAIL, a trap halt, a `$fatal` anywhere) still leaves the console the DUT
        // produced on disk. That text is the fastest diagnosis a long boot has, and
        // losing it because the normal completion path never ran cost one 50-minute
        // run already.
        if (uart_path != "") begin
            uart_fd = $fopen(uart_path, "w");
            if (uart_fd == 0) begin
                $display("ETH_RV_TB: FAIL cannot open uart file '%s'", uart_path);
                $fatal(1);
            end
            $fwrite(uart_fd, "# eth_rv uart rx live v1 (replaced by the record on a clean finish)\n");
            $fflush(uart_fd);
        end
        stop_pc_en = ($value$plusargs("stop_pc=%h", stop_pc) != 0);
        a1_check_addr = (a1_addr != 64'd0) ? a1_addr : DTB_ADDR;
        trace_on_run = (trace_path != "");
        // `+uart_marker=<hex>`: decode two digits per byte, same convention as
        // `+uart_rx`. An odd digit count, an empty string or more bytes than the
        // matcher holds is a hard FAIL — a marker that silently matched nothing
        // would turn a milestone into a timeout.
        if (uart_marker_hex != "") begin : marker_decode
            if (((uart_marker_hex.len() % 2) != 0) || (uart_marker_hex.len() == 0)) begin
                $display("ETH_RV_TB: FAIL +uart_marker wants an even, non-zero number of hex digits, got '%s'",
                         uart_marker_hex);
                $fatal(1);
            end
            marker_len = uart_marker_hex.len() / 2;
            if (marker_len > MARKER_MAX) begin
                $display("ETH_RV_TB: FAIL +uart_marker has %0d bytes, the matcher holds %0d",
                         marker_len, MARKER_MAX);
                $fatal(1);
            end
            for (int unsigned bi = 0; bi < marker_len; bi = bi + 1) begin
                marker_bytes[bi] = {hex_nib(uart_marker_hex.getc(2 * bi)),
                                    hex_nib(uart_marker_hex.getc(2 * bi + 1))};
            end
        end
        // `$value$plusargs` returns 1 when the plusarg was present: `ADDR` and
        // `VALUE` are separately optional (`ADDR` alone stops on the first store
        // to that address, like `--stop-store ADDR`).
        stop_addr_en  = ($value$plusargs("stop_addr=%h", stop_addr) != 0);
        stop_value_en = ($value$plusargs("stop_value=%h", stop_value) != 0);

        if (mem_path == "") begin
            $display("ETH_RV_TB: FAIL no +mem=<file> given");
            $fatal(1);
        end
`ifdef ETH_RV_DRAM_AXI
        if (starve_dmem != 0) begin
            $display("ETH_RV_TB: FAIL +starve_dmem is only implemented by the behavioral build");
            $fatal(1);
        end
        // The Sv39 walk-injection control folds into the beat THIS testbench
        // returns; in the AXI build the beats come from the DRAM stub, so the
        // control would be silently ignored and a "control not caught" would look
        // like a modelling bug. Refuse it loudly instead.
        if ((dmem_corrupt_xor != 64'd0) || (dmem_corrupt_addr != 64'd0)) begin
            $display("ETH_RV_TB: FAIL +dmem_corrupt_addr/+dmem_corrupt_xor are only implemented by the behavioral build");
            $fatal(1);
        end
        // the DRAM stub's array is the one image: preload it so the instruction
        // port (hierarchical read) and the AXI data port see the same memory
        for (int unsigned i = 0; i < DRAM_WORDS; i = i + 1) begin
            u_dram.u_impl.mem[i] = 64'd0;
        end
        $readmemh(mem_path, u_dram.u_impl.mem);
`else
        for (int unsigned i = 0; i < MEM_WORDS; i = i + 1) begin
            mem[i] = 64'd0;
        end
        $readmemh(mem_path, mem);
`endif

        // ---- the memory window the golden model was given ----------------------
        // `-DETH_RV_MEM_BYTES` sizes the arrays above; `+mem_bytes` is what the
        // runner passed to Spike's `-m`. They must be the same number, or the two
        // sides are not running the same machine and a MATCH would mean nothing.
        if ((mem_bytes_arg != 0) && (mem_bytes_arg != MEM_BYTES)) begin
            $display("ETH_RV_TB: FAIL +mem_bytes=%0d but this model was built with a %0d-byte window (-DETH_RV_MEM_BYTES)",
                     mem_bytes_arg, MEM_BYTES);
            $fatal(1);
        end

        // ---- BootROM: one image, preloaded, then pointed at the payload entry ---
        // The ROM lives inside the MMIO mux's `eth_rv_boot_rom` instance, so the
        // fetch path above and the D port read this ONE array — the SoC's two routes
        // to one ROM slave. The entry word is patched in place: 64 bits at
        // ROM_ENTRY_WORD, the shape a harness uses to point a reset vector at an
        // entry. The ROM's own view of it (`rom_entry`) is checked against the
        // request on the first commit, so a patch that did not land fails as itself
        // instead of as a phantom fetch fault.
        begin : rom_load
            integer rom_fd;
            rom_fd = $fopen(rom_path, "r");
            if (rom_fd == 0) begin
                $display("ETH_RV_TB: FAIL cannot open the BootROM image '%s'", rom_path);
                $fatal(1);
            end
            $fclose(rom_fd);
        end
        for (int unsigned i = 0; i < ROM_WORDS; i = i + 1) begin
            u_mmio.u_rom.rom[i] = 32'd0;
        end
        $readmemh(rom_path, u_mmio.u_rom.rom);
        u_mmio.u_rom.rom[ROM_WIW'(ROM_ENTRY_WORD)]     = entry_addr[31:0];
        u_mmio.u_rom.rom[ROM_WIW'(ROM_ENTRY_WORD + 1)] = entry_addr[63:32];
        trace_from_pc = (trace_from != 64'd0) ? trace_from : entry_addr;

        // ---- the device tree blob at the address the stub leaves in a1 ----------
        // Optional: a harness may instead weave the same bytes into the `+mem`
        // image. When the blob IS given, the FDT magic is checked — a1 pointing at
        // something that is not a device tree is the boot failure this slice exists
        // to catch, and it must be caught here, not as a mystery load in the trace.
        if (dtb_path != "") begin : dtb_load
            integer      dtb_fd;
            int unsigned dtb_n;
            logic [7:0]  dtb_byte;
            dtb_fd = $fopen(dtb_path, "rb");
            if (dtb_fd == 0) begin
                $display("ETH_RV_TB: FAIL cannot open the DTB '%s'", dtb_path);
                $fatal(1);
            end
            dtb_n = 0;
            while (($fread(dtb_byte, dtb_fd) == 1)
                   && ((DTB_ADDR + 64'(dtb_n)) < (base_addr + 64'(MEM_BYTES)))) begin
                mem_store_byte(DTB_ADDR + 64'(dtb_n), dtb_byte);
                dtb_n = dtb_n + 1;
            end
            $fclose(dtb_fd);
            if ((dtb_n == 0) || (32'(mem_word(DTB_ADDR)) != DT_MAGIC_LE)) begin
                $display("ETH_RV_TB: FAIL the DTB '%s' (%0d bytes) does not start with the FDT magic 0xd00dfeed at 0x%016x (read 0x%08x)",
                         dtb_path, dtb_n, DTB_ADDR, 32'(mem_word(DTB_ADDR)));
                $fatal(1);
            end
            // NOT the `ETH_RV_TB:` banner: the runner reads the first banner line
            // as the run's verdict, and this is information, not a verdict.
            $display("ETH_RV_TB_INFO: DTB %0d bytes loaded at 0x%016x, FDT magic OK",
                     dtb_n, DTB_ADDR);
        end

        // ---- the device tree inside the BootROM (`+rom_dtb=1`, S4) --------------
        // The S4 BootROM mirrors Spike's own reset vector, so its a1 points into
        // the ROM (0x1020) and the tree is part of the 4 KiB image. Asserting the
        // FDT magic at the address the ROM hands over is the same check `+dtb=`
        // makes for a RAM-resident tree, moved to where the tree now lives.
        if ((rom_dtb != 0) || (a1_check_addr != DTB_ADDR)) begin : rom_dtb_check
            logic [63:0] rom_word_addr;
            logic [ROM_WIW-1:0] rom_word_idx;
            if (!in_rom(a1_check_addr)) begin
                $display("ETH_RV_TB: FAIL +a1_addr=0x%016x is outside the BootROM (0x%016x..0x%016x): the ROM cannot hold the device tree there",
                         a1_check_addr, ROM_BASE, ROM_BASE + 64'(ROM_BYTES));
                $fatal(1);
            end
            rom_word_addr = a1_check_addr - ROM_BASE;
            rom_word_idx = ROM_WIW'(rom_word_addr >> 2);
            if (32'(u_mmio.u_rom.rom[rom_word_idx]) != DT_MAGIC_LE) begin
                $display("ETH_RV_TB: FAIL the BootROM word at a1 = 0x%016x is 0x%08x, not the FDT magic 0x%08x — the firmware would be handed a tree that is not a tree",
                         a1_check_addr, 32'(u_mmio.u_rom.rom[rom_word_idx]), DT_MAGIC_LE);
                $fatal(1);
            end
            $display("ETH_RV_TB_INFO: BootROM-resident DTB at 0x%016x, FDT magic OK",
                     a1_check_addr);
        end

        // ---- UART RX injection: decode `+uart_rx=<hex bytes> -------------------
        // Two hex digits per byte, e.g. `+uart_rx=414243` for "ABC". The driver
        // above serialises them; the self-check after the run holds what the DUT
        // queued against this list.
        if (uart_rx_hex != "") begin : rx_inj_decode
            if ((uart_rx_hex.len() % 2) != 0) begin
                $display("ETH_RV_TB: FAIL +uart_rx wants an even number of hex digits, got '%s'",
                         uart_rx_hex);
                $fatal(1);
            end
            rx_inj_len = uart_rx_hex.len() / 2;
            if (rx_inj_len > UART_MAX_BYTES) begin
                $display("ETH_RV_TB: FAIL +uart_rx has %0d bytes, the receiver holds %0d",
                         rx_inj_len, UART_MAX_BYTES);
                $fatal(1);
            end
            for (int unsigned bi = 0; bi < rx_inj_len; bi = bi + 1) begin
                rx_inj_bytes[bi] = {hex_nib(uart_rx_hex.getc(2 * bi)),
                                    hex_nib(uart_rx_hex.getc(2 * bi + 1))};
            end
        end

        // `+trace` is optional: the S4 Linux boot retires hundreds of millions of
        // commits and compares none of them one by one, so a run that only needs
        // the console, the cycle count and the trap counters omits it.
        if (trace_on_run) begin
            trace_fd = $fopen(trace_path, "w");
            if (trace_fd == 0) begin
                $display("ETH_RV_TB: FAIL cannot open trace file '%s'", trace_path);
                $fatal(1);
            end
            $fwrite(trace_fd, "# rv_difftest trace v2\n");
            $fwrite(trace_fd, "# generator: eth_rv_core rtl (eth_rv_core.sv RV-C)\n");
            $fwrite(trace_fd, "# fields: cycle pc rd value [mem_addr mem_wdata [mem_rmask mem_wmask]] [fflags=.. frm=..]\n");
        end

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        wait (stop_now === 1'b1);
        @(posedge clk);
        if (trace_on_run) begin
            $fclose(trace_fd);
        end

        // The verdict itself is deferred to the very end: a run that failed its
        // cycle/trap budget still has console evidence (the `+uart=` record is
        // written below), and that evidence is exactly what a failed S4 boot needs
        // to be diagnosable. `failed` is still sticky, so the FAIL/`$fatal` cannot
        // be skipped — only its position moves.

        // The run must have gone through the BootROM into the payload: the entry
        // commit is the handshake's landing point, and the trace window has to have
        // opened for the two streams to be comparable at all. Both are structural
        // (a reset PC, ROM image or `+entry` mismatch lands here), so they are hard
        // FAILs with the address in the message.
        if (!entry_seen) begin
            $display("ETH_RV_TB: FAIL the BootROM never reached the payload entry 0x%016x (reset PC, ROM image or +entry mismatch)",
                     entry_addr);
            $fatal(1);
        end
        if (!trace_on) begin
            $display("ETH_RV_TB: FAIL the trace window never opened (no commit at 0x%016x)",
                     trace_from_pc);
            $fatal(1);
        end

        if (marker_len != 0) begin
            if (marker_hit) begin
                $display("ETH_RV_TB_INFO: console marker (%0d bytes) seen on the UART line after %0d console bytes",
                         marker_len, rx_nbytes);
            end else begin
                $display("ETH_RV_TB_INFO: console marker (%0d bytes) NOT seen (%0d console bytes received)",
                         marker_len, rx_nbytes);
            end
        end

        // ---------------------------------------------------------- console UART
        // The commit trace is closed above, so the cycles spent here cannot
        // affect the DiffTest — they exist so the serial line finishes carrying
        // the burst the program queued before its HTIF exit store.
        drain_used = 0;
        while (uart_busy && (drain_used < uart_drain_cycles)) begin
            @(posedge clk);
            drain_used = drain_used + 1;
        end
        if (uart_busy) begin
            $display("ETH_RV_TB: FAIL the console UART did not drain within %0d cycles",
                     uart_drain_cycles);
            $fatal(1);
        end
        if (uart_overflow) begin
            $display("ETH_RV_TB: FAIL a console UART transmit byte was dropped (queue full)");
            $fatal(1);
        end
        if (rx_buf_overflow) begin
            $display("ETH_RV_TB: FAIL the console UART receiver buffer overflowed");
            $fatal(1);
        end

        // ------------------------------------------------------ console UART RX --
        // The DUT's *receiver* has no golden model to compare against (Spike's
        // ns16550 is fed by a terminal a batch run cannot drive), so this half of
        // the receive path is a testbench assertion: the frames above are driven
        // onto `uart_rx_i` and the bytes the DUT queued are held against them.
        // `+uart_rx_fault_frame/bit` breaks one cell, and the check below MUST then
        // fail — that is its negative control.
        if (rx_inj_len != 0) begin : rx_self_check
            int unsigned rx_guard;
            int unsigned rx_queued;
            rx_guard = 0;
            while (!rx_inj_done && (rx_guard < (100 * UART_FRAME_CYCLES * rx_inj_len))) begin
                @(posedge clk);
                rx_guard = rx_guard + 1;
            end
            if (!rx_inj_done) begin
                $display("ETH_RV_TB: FAIL the injected RX burst never finished (%0d of %0d bytes sent)",
                         rx_inj_idx, rx_inj_len);
                $fatal(1);
            end
            rx_queued = 32'(u_mmio.u_uart.rx_count_r);
            if (rx_queued != rx_inj_len) begin
                $display("ETH_RV_TB: FAIL the UART receiver queued %0d byte(s), expected %0d (injected %0d frames)",
                         rx_queued, rx_inj_len, rx_inj_len);
                $fatal(1);
            end
            for (int unsigned bi = 0; bi < rx_inj_len; bi = bi + 1) begin
                if (u_mmio.u_uart.rx_fifo_r[bi] !== rx_inj_bytes[bi]) begin
                    $display("ETH_RV_TB: FAIL the UART received 0x%02x at queue position %0d, injected 0x%02x",
                             u_mmio.u_uart.rx_fifo_r[bi], bi, rx_inj_bytes[bi]);
                    $fatal(1);
                end
            end
            if (uart_rx_overflow) begin
                $display("ETH_RV_TB: FAIL the UART receiver dropped an injected byte (queue full)");
                $fatal(1);
            end
            if (uart_rx_frame_err) begin
                $display("ETH_RV_TB: FAIL the UART receiver saw a framing error on an injected frame");
                $fatal(1);
            end
            $display("ETH_RV_TB_INFO: UART RX self-check: %0d byte(s) injected on uart_rx_i, %0d queued and byte-exact",
                     rx_inj_len, rx_queued);
            rx_self_note = "RX inject "; // (the byte count is appended below)
            rx_self_note = $sformatf("RX inject %0d bytes OK", rx_inj_len);
        end
        if (uart_path != "") begin
            uart_fd = $fopen(uart_path, "w");
            if (uart_fd == 0) begin
                $display("ETH_RV_TB: FAIL cannot open uart file '%s'", uart_path);
                $fatal(1);
            end
            // Header fields are what the runner asserts (plus the hex payload on
            // the `data:` line, so any byte value survives the text format).
            $fwrite(uart_fd, "# eth_rv uart rx v1\n");
            $fwrite(uart_fd, "# bit_cycles: %0d frame_cycles: %0d bytes: %0d frames: %0d errors: %0d overflow: %0d drain_cycles: %0d\n",
                    UART_DIV, UART_FRAME_CYCLES, rx_nbytes, rx_nframes, rx_errors,
                    rx_buf_overflow, drain_used);
            $fwrite(uart_fd, "# gap_min: %0d gap_max: %0d\n", rx_gap_min, rx_gap_max);
            $fwrite(uart_fd, "data: ");
            for (int unsigned i = 0; i < rx_nbytes; i = i + 1) begin
                $fwrite(uart_fd, "%02x", rx_bytes[i]);
            end
            $fwrite(uart_fd, "\n");
            $fclose(uart_fd);
        end
        // The run's verdict, after every report above so a failed run still carries
        // its console evidence (see the note where the old verdict sat).
        if (failed) begin
            $display("ETH_RV_TB: FAIL stopped at %0d commits after %0d cycles",
                     commits, cycle_cnt);
            $fatal(1);
        end
`ifdef ETH_RV_DRAM_AXI
        // A non-OKAY response is a legitimate event now: it is the socket's way of
        // rejecting an out-of-window address, and `eth_rv_axi_master` reports it
        // per transaction as `dmem_err_o`, which the core turns into an access
        // fault. What must never happen is a non-OKAY response that does NOT
        // become an architectural access fault — that would be a silent failure.
        if (axi_err && (n_access_faults == 0)) begin
            $display("ETH_RV_TB: FAIL the DRAM socket answered with a non-OKAY response that never became an access fault");
            $fatal(1);
        end
        $display("ETH_RV_TB: PASS %0d commits (%0d compressed), %0d cycles, %0d loads, %0d stores, %0d traps (%0d interrupts, %0d access faults, %0d page faults, last mcause=%0d), port wait max D %0d / I %0d cycles, last mem 0x%016x (pa 0x%016x) <- 0x%016x, last insn 0x%08x, window %0d KiB, ROM entry 0x%016x, AXI %0d AR (%0d multi-beat) %0d R beats, %0d AW %0d W beats, UART %0d bytes/%0d frames (%0d frame errors, drain %0d cycles), %s",
                 commits, n_compressed, cycle_cnt, n_loads, n_stores, traps,
                 n_interrupts, n_access_faults, n_pgfaults, last_trap_cause, dport_wait_max, iport_wait_max,
                 last_mem_addr, last_mem_paddr, last_store_data, last_insn,
                 MEM_BYTES / 1024, entry_addr,
                 n_axi_ar, n_axi_r_bursts, n_axi_r_beats, n_axi_aw, n_axi_w_beats,
                 rx_nbytes, rx_nframes, rx_errors, drain_used, rx_self_note);
`else
        $display("ETH_RV_TB: PASS %0d commits (%0d compressed), %0d cycles, %0d loads, %0d stores, %0d traps (%0d interrupts, %0d access faults, %0d page faults, last mcause=%0d), port wait max D %0d / I %0d cycles, last mem 0x%016x (pa 0x%016x) <- 0x%016x, last insn 0x%08x, window %0d KiB, ROM entry 0x%016x, UART %0d bytes/%0d frames (%0d frame errors, drain %0d cycles), %s",
                 commits, n_compressed, cycle_cnt, n_loads, n_stores, traps,
                 n_interrupts, n_access_faults, n_pgfaults, last_trap_cause, dport_wait_max, iport_wait_max,
                 last_mem_addr, last_mem_paddr, last_store_data, last_insn,
                 MEM_BYTES / 1024, entry_addr,
                 rx_nbytes, rx_nframes, rx_errors, drain_used, rx_self_note);
`endif
        $finish;
    end

endmodule
`default_nettype wire
