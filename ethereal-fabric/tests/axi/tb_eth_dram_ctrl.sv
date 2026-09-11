`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_dram_ctrl (testbench, self-checking)
// Description: The E2-DRAM1 acceptance TB for the packaged DRAM component:
//              drives the SoC-facing `eth_dram_ctrl` AXI4 memory-slave socket
//              and checks every response against a Python-free reference model
//              implemented IN THIS FILE (ref_mem[] + ref_resp() + beat_addr()).
// Details:     Coverage:
//                1. single-beat read/write and WSTRB byte-lane patterns,
//                   including FOUR lane checks computed BY HAND and asserted on
//                   the DUT's own READBACK (rd_buf), independent of the
//                   reference model, so a stub that ignores/mis-applies WSTRB
//                   fails them directly:
//                     . strb=8'h0F + data=0x0000_0000_FFFF_FFFF must leave the
//                       upper 4 bytes of the word untouched
//                     . strb=8'hF0 + data=0xDEAD_BEEF_0000_0000 must leave the
//                       lower 4 bytes untouched
//                     . strb=8'h0C must touch only lanes 2..3
//                     . unaligned size=0 write at byte offset 5 (strb=8'h20)
//                2. multi-beat INCR bursts over len/size combinations
//                   (len 0/1/3/7/15, size 0/1/2/3) plus unaligned starts and
//                   the AXI4 aligned-address rule
//                   (Address_N = align_down(AxADDR,2^AxSIZE)+(N-1)*2^AxSIZE);
//                3. back-to-back mixed read/write traffic, including a read
//                   burst issued in the MIDDLE of a write burst's W stream
//                   (the two engines are independent) with B deliberately left
//                   pending while the read drains;
//                4. backpressure injection on both directions (random RREADY and
//                   BREADY stalls, up to a long 64-cycle stall) with VALID
//                   payload-stability checks;
//                5. the documented error policy: out-of-range -> DECERR (with
//                   the boundary-spanning write committing nothing), illegal
//                   WRAP/FIXED, AxSIZE > bus width, AxLOCK, and a 4 KiB
//                   boundary crossing -> SLVERR (with every W beat still sunk);
//                6. a bounded randomized soak (cycle-budgeted) comparing every
//                   beat read against ref_mem[].
//              DUT is the SOCKET (eth_dram_ctrl), so the TB also covers the
//              seam wiring to the default implementation (eth_dram_stub).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - created (E2-DRAM1)
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §4 ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §4 ·
//              ethereal-spec/control/eth-axi-v0.md §2 §3.1 §5.3
// Notes:       iverilog -g2012. Self-checking; prints "TEST PASSED".
//              Run:
//                iverilog -g2012 -o /tmp/tb_dram \
//                  ethereal-shell/rtl/dram/eth_dram_stub.sv \
//                  ethereal-shell/rtl/dram/eth_dram_ctrl.sv \
//                  ethereal-fabric/tests/axi/tb_eth_dram_ctrl.sv && vvp /tmp/tb_dram
//              The reference model mirrors the stub's documented ERROR CONTRACT
//              and TIMING sections independently (it is not a copy of the RTL:
//              it is a memory array + address/response arithmetic).
`timescale 1ns/1ps
module tb_eth_dram_ctrl;

    // ---------------- DUT configuration ----------------
    localparam int AXI_AW  = 32;
    localparam int AXI_DW  = 64;
    localparam int AXI_IDW = 4;
    localparam int STRB_W  = AXI_DW / 8;
    localparam int LOG_STRB = 3;
    localparam logic [31:0] MEM_BASE  = 32'h8000_0000;
    localparam int MEM_BYTES  = 64 * 1024;
    localparam int MEM_WORDS  = MEM_BYTES / STRB_W;
    localparam int RD_LATENCY = 4;
    localparam int WR_LATENCY = 2;

    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10, DECERR = 2'b11;
    localparam logic [1:0] FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10;

    localparam logic [31:0] SOAK_SPAN   = MEM_BYTES + 512;   // 32-bit unsigned
    localparam int          SOAK_CYCLES = 30000;             // bounded cycle budget
    localparam int          SOAK_MAX_TX = 800;

    // ---------------- clock / reset ----------------
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    integer cyc = 0;
    always_ff @(posedge clk) cyc <= cyc + 1;

    // ---------------- AXI4 slave signals ----------------
    logic         awvalid, awready;
    logic [31:0]  awaddr;
    logic [3:0]   awid;
    logic [7:0]   awlen;
    logic [2:0]   awsize, awprot;
    logic [1:0]   awburst;
    logic [3:0]   awcache, awqos, awregion;
    logic         awlock;
    logic         wvalid, wready, wlast;
    logic [63:0]  wdata;
    logic [7:0]   wstrb;
    logic         bvalid, bready;
    logic [1:0]   bresp;
    logic [3:0]   bid;
    logic         arvalid, arready, arlock;
    logic [31:0]  araddr;
    logic [3:0]   arid;
    logic [7:0]   arlen;
    logic [2:0]   arsize, arprot;
    logic [1:0]   arburst;
    logic [3:0]   arcache, arqos, arregion;
    logic         rvalid, rready, rlast;
    logic [63:0]  rdata;
    logic [1:0]   rresp;
    logic [3:0]   rid;

    // ---------------- DUT: the SoC-facing socket ----------------
    eth_dram_ctrl #(
        .AXI_AW(AXI_AW), .AXI_DW(AXI_DW), .AXI_IDW(AXI_IDW),
        .MEM_BASE(MEM_BASE), .MEM_BYTES(MEM_BYTES),
        .RD_LATENCY(RD_LATENCY), .WR_LATENCY(WR_LATENCY)
    ) dut (
        .clk_i(clk), .rst_ni(rst_n),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_awaddr(awaddr),
        .s_axi_awid(awid), .s_axi_awlen(awlen), .s_axi_awsize(awsize),
        .s_axi_awburst(awburst), .s_axi_awcache(awcache), .s_axi_awprot(awprot),
        .s_axi_awqos(awqos), .s_axi_awregion(awregion), .s_axi_awlock(awlock),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
        .s_axi_bvalid(bvalid), .s_axi_bready(bready), .s_axi_bresp(bresp), .s_axi_bid(bid),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_araddr(araddr),
        .s_axi_arid(arid), .s_axi_arlen(arlen), .s_axi_arsize(arsize),
        .s_axi_arburst(arburst), .s_axi_arcache(arcache), .s_axi_arprot(arprot),
        .s_axi_arqos(arqos), .s_axi_arregion(arregion), .s_axi_arlock(arlock),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready), .s_axi_rdata(rdata),
        .s_axi_rresp(rresp), .s_axi_rlast(rlast), .s_axi_rid(rid)
    );

    // ==================================================================
    // Scoreboard + reference model (Python-free, TB-local)
    // ==================================================================
    integer errors = 0;
    integer checks = 0;

    task automatic chk(input bit cond, input [1023:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("  FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    logic [63:0] ref_mem [0:MEM_WORDS-1];

    function automatic logic [63:0] mem_pattern(input int idx);
        mem_pattern = {32'hD00D_0000 + idx[31:0], idx[31:0]};
    endfunction

    // AXI4 INCR beat address: Address_1 = Start, Address_N =
    // Aligned_Address + (N-1)*Number_Bytes (IHI0022G §A3.4.1).
    function automatic logic [31:0] beat_addr(input [31:0] start, input int n, input [2:0] size);
        logic [31:0] inc, abase;
        begin
            inc   = 32'd1 << size;
            abase = start & ~(inc - 32'd1);
            beat_addr = (n == 0) ? start : (abase + n * inc);
        end
    endfunction

    task automatic ref_write_beat(input [31:0] addr, input [63:0] data, input [7:0] strb);
        integer li;
        begin
            for (li = 0; li < STRB_W; li = li + 1)
                if (strb[li]) ref_mem[(addr - MEM_BASE) >> 3][li*8 +: 8] = data[li*8 +: 8];
        end
    endtask

    function automatic logic [63:0] ref_read_beat(input [31:0] addr);
        ref_read_beat = ref_mem[(addr - MEM_BASE) >> 3];
    endfunction

    // Independent re-derivation of the stub's documented ERROR CONTRACT.
    function automatic logic [1:0] ref_resp(input [31:0] addr, input [7:0] len,
                                            input [2:0] size, input [1:0] burst,
                                            input bit lock);
        logic [63:0] bytes, abase, off_first, off_last, b_last;
        begin
            if (burst != INCR)          ref_resp = SLVERR;
            else if (size > LOG_STRB)   ref_resp = SLVERR;
            else if (lock)              ref_resp = SLVERR;
            else begin
                bytes  = ({56'b0, len} + 64'd1) << size;
                abase  = {32'b0, addr} & ~((64'd1 << size) - 64'd1);
                b_last = {52'b0, abase[11:0]} + bytes - 64'd1;
                if (b_last > 64'h0FFF) begin
                    ref_resp = SLVERR;                       // 4 KiB crossing
                end else begin
                    off_first = {32'b0, addr}  - {32'b0, MEM_BASE};
                    off_last  = abase - {32'b0, MEM_BASE} + bytes - 64'd1;
                    ref_resp  = ((off_first >= MEM_BYTES) || (off_last >= MEM_BYTES))
                                ? DECERR : OKAY;
                end
            end
        end
    endfunction

    // ==================================================================
    // Driver state / helpers
    // ==================================================================
    integer tb_seed = 32'h1234_5678;
    integer bp_max  = 5;      // RREADY stall window (random, 0..bp_max)
    integer b_bp_max = 3;     // BREADY stall window

    logic [7:0]  t_len;
    logic [3:0]  t_id;
    integer      rd_beats = 0;

    // Held-payload probes (VALID-stability checks while READY is low)
    logic        b_seen = 1'b0;
    logic [1:0]  bresp_prev;
    logic [3:0]  bid_prev;
    logic        rv_seen = 1'b0;
    logic [63:0] rd_prev;
    logic [1:0]  rr_prev;
    logic        rl_prev;
    logic [3:0]  ri_prev;

    logic [63:0] wbuf [0:255];
    logic [7:0]  sbuf [0:255];
    logic [63:0] rd_buf [0:255];   // DUT readback, per beat (hand-check source)

    // W payload/strobes for a burst: legal AXI4 byte lanes for the addressed
    // Bytes, optionally restricted to a random subset.
    task automatic wbuf_lanes(input int n, input [31:0] addr, input [2:0] size, input bit rnd);
        integer i;
        logic [2:0] boff;
        logic [15:0] m16, msh;
        logic [7:0] m8;
        logic [31:0] ba;
        begin
            for (i = 0; i < n; i = i + 1) begin
                ba   = beat_addr(addr, i, size);              // iverilog: no part-select on a call
                boff = ba[2:0];
                m16  = (16'd1 << (16'd1 << size)) - 16'd1;    // 2^size byte lanes
                msh  = m16 << boff;
                m8   = msh[7:0];                              // placed at the address offset
                wbuf[i] = {$random(tb_seed), $random(tb_seed)};
                sbuf[i] = rnd ? (m8 & ({$random(tb_seed)})) : m8;
            end
        end
    endtask

    task automatic wbuf_force(input int i, input [63:0] data, input [7:0] strb);
        begin
            wbuf[i] = data;
            sbuf[i] = strb;
        end
    endtask

    // ---------------- AXI4 drivers ----------------
    task automatic aw_issue(input [31:0] addr, input [7:0] len, input [2:0] size,
                            input [1:0] burst, input bit lock, input [3:0] id);
        begin
            @(negedge clk);
            awvalid = 1'b1; awaddr = addr; awid = id; awlen = len; awsize = size;
            awburst = burst; awlock = lock;
            awcache = 4'h0; awprot = 3'h0; awqos = 4'h0; awregion = 4'h0;
            @(posedge clk);
            while (!awready) @(posedge clk);
            @(negedge clk);
            awvalid = 1'b0;
        end
    endtask

    task automatic ar_issue(input [31:0] addr, input [7:0] len, input [2:0] size,
                            input [1:0] burst, input bit lock, input [3:0] id);
        begin
            @(negedge clk);
            arvalid = 1'b1; araddr = addr; arid = id; arlen = len; arsize = size;
            arburst = burst; arlock = lock;
            arcache = 4'h0; arprot = 3'h0; arqos = 4'h0; arregion = 4'h0;
            @(posedge clk);
            while (!arready) @(posedge clk);
            @(negedge clk);
            arvalid = 1'b0;
        end
    endtask

    // Drive W beats i0..i1 of a burst that started at `addr`; the reference
    // model is updated only for a burst that decodes OKAY (the stub commits
    // nothing otherwise).
    task automatic w_beats(input int i0, input int i1, input [31:0] addr,
                           input [2:0] size, input [1:0] exp);
        integer i;
        logic [31:0] ba;
        begin
            for (i = i0; i <= i1; i = i + 1) begin
                ba = beat_addr(addr, i, size);
                @(negedge clk);
                wvalid = 1'b1; wdata = wbuf[i]; wstrb = sbuf[i];
                wlast  = (i == int'(t_len));
                @(posedge clk);
                while (!wready) @(posedge clk);
                @(negedge clk);
                wvalid = 1'b0; wlast = 1'b0;
                if (exp == OKAY) ref_write_beat(ba, wbuf[i], sbuf[i]);
            end
        end
    endtask

    task automatic b_wait(input [1:0] exp, input [3:0] id);
        integer k, stall;
        begin
            bready = 1'b0;
            stall  = ({$random(tb_seed)} % (b_bp_max + 1));
            for (k = 0; k < stall; k = k + 1) begin
                @(posedge clk);
                if (bvalid) begin
                    if (b_seen) begin
                        chk(bresp === bresp_prev, "BRESP stable while BVALID && !BREADY");
                        chk(bid   === bid_prev,   "BID stable while BVALID && !BREADY");
                    end
                    b_seen = 1'b1; bresp_prev = bresp; bid_prev = bid;
                end
            end
            @(negedge clk); bready = 1'b1;
            @(posedge clk);
            while (!bvalid) @(posedge clk);
            chk(bresp === exp, "write response code");
            chk(bid === id,    "BID echoes AWID");
            @(negedge clk); bready = 1'b0; b_seen = 1'b0;
        end
    endtask

    // Collect R beats, injecting random RREADY stalls and checking payload
    // stability while RVALID && !RREADY (a dropped/duplicated beat shows up as
    // a hang -> watchdog, or as a beat-count/RDATA mismatch).
    task automatic rd_collect(input [31:0] addr, input [7:0] len, input [2:0] size,
                              input [1:0] exp, input bit do_bp);
        integer n, k, stall;
        bit done, last_now;
        begin
            n = 0; done = 1'b0; rready = 1'b0; rv_seen = 1'b0;
            while (!done) begin
                stall = do_bp ? ({$random(tb_seed)} % (bp_max + 1)) : 0;
                for (k = 0; k < stall; k = k + 1) begin
                    @(posedge clk);
                    if (rvalid) begin
                        if (rv_seen) begin
                            chk(rdata === rd_prev, "RDATA stable while RVALID && !RREADY");
                            chk(rresp === rr_prev, "RRESP stable while RVALID && !RREADY");
                            chk(rlast === rl_prev, "RLAST stable while RVALID && !RREADY");
                            chk(rid   === ri_prev, "RID stable while RVALID && !RREADY");
                        end
                        rv_seen = 1'b1;
                        rd_prev = rdata; rr_prev = rresp; rl_prev = rlast; ri_prev = rid;
                    end
                end
                @(negedge clk); rready = 1'b1;
                @(posedge clk);
                if (rvalid) begin
                    n = n + 1;
                    // Sample the beat at the clock edge: the DUT returns to
                    // R_IDLE (and drops RLAST) right after the handshake edge.
                    last_now = rlast;
                    rd_buf[n - 1] = rdata;
                    chk(rresp === exp, "read response code");
                    chk(rid === t_id,  "RID echoes ARID");
                    if (exp == OKAY)
                        chk(rdata === ref_read_beat(beat_addr(addr, n - 1, size)),
                            "RDATA matches reference model");
                    else
                        chk(rdata === 64'h0, "error-read RDATA is zero");
                    chk(rlast === ((exp != OKAY) ? 1'b1 : (n == (int'(len) + 1))),
                        "RLAST placement");
                    @(negedge clk); rready = 1'b0;
                    // The next beat legitimately carries a new payload, so the
                    // held-payload probe restarts for each accepted beat.
                    rv_seen = 1'b0;
                    if (last_now) begin
                        rd_beats = n;
                        done = 1'b1;
                    end
                end else begin
                    @(negedge clk); rready = 1'b0;
                end
            end
        end
    endtask

    task automatic wr_burst(input [31:0] addr, input [7:0] len, input [2:0] size,
                            input [1:0] burst, input bit lock, input [3:0] id);
        begin
            t_len = len; t_id = id;
            aw_issue(addr, len, size, burst, lock, id);
            w_beats(0, int'(len), addr, size, ref_resp(addr, len, size, burst, lock));
            b_wait(ref_resp(addr, len, size, burst, lock), id);
        end
    endtask

    task automatic rd_burst(input [31:0] addr, input [7:0] len, input [2:0] size,
                            input [1:0] burst, input bit lock, input [3:0] id, input bit do_bp);
        logic [1:0] exp;
        begin
            t_len = len; t_id = id;
            exp = ref_resp(addr, len, size, burst, lock);
            ar_issue(addr, len, size, burst, lock, id);
            rd_collect(addr, len, size, exp, do_bp);
            chk(rd_beats === ((exp == OKAY) ? (int'(len) + 1) : 1),
                "read burst beat count (no dropped/duplicated beat)");
        end
    endtask

    // ==================================================================
    // Stimulus
    // ==================================================================
    localparam logic [31:0] A0 = MEM_BASE + 32'h0000_0100;   // lane-check word
    localparam logic [31:0] A1 = MEM_BASE + 32'h0000_0200;
    localparam logic [31:0] A2 = MEM_BASE + 32'h0000_0400;
    localparam logic [31:0] A3 = MEM_BASE + 32'h0000_0800;
    localparam logic [31:0] A4 = MEM_BASE + 32'h0000_1000;
    localparam logic [31:0] A5 = MEM_BASE + 32'h0000_1400;
    localparam logic [31:0] CW = MEM_BASE + 32'h0000_1800;
    localparam logic [31:0] CR = MEM_BASE + 32'h0000_1C00;
    localparam int LWORD_IDX = 32;

    integer pi, n_tx, i, rw, sz, ln;
    logic [31:0] off, rad;
    logic [31:0] a0_word;
    logic [63:0] exp_word, tmpw;
    bit use_bp, unaligned;

    initial begin
        // ---- init ----
        awvalid = 0; awaddr = 0; awid = 0; awlen = 0; awsize = 0; awburst = INCR;
        awcache = 0; awprot = 0; awqos = 0; awregion = 0; awlock = 0;
        wvalid = 0; wdata = 0; wstrb = 0; wlast = 0;
        bready = 0; arvalid = 0; araddr = 0; arid = 0; arlen = 0; arsize = 0;
        arburst = INCR; arcache = 0; arprot = 0; arqos = 0; arregion = 0; arlock = 0;
        rready = 0;

        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // ---- preload DUT memory + reference model with the same pattern ----
        for (pi = 0; pi < MEM_WORDS; pi = pi + 1) begin
            // Backdoor preload of the behavioral memory. The hierarchy depth
            // depends on which DRAM seam provider is bound (default: the stub is
            // instantiated directly by the socket; vendor build: the socket binds
            // `eth_dram_glue`, which binds the stub one level deeper).
`ifdef ETH_DRAM_VENDOR_GLUE
            dut.u_impl.u_stub.mem[pi] = mem_pattern(pi);
`else
            dut.u_impl.mem[pi] = mem_pattern(pi);
`endif
            ref_mem[pi]                = mem_pattern(pi);
        end
        $display("tb_eth_dram_ctrl: MEM_BASE=%08h MEM_BYTES=%0d RD_LATENCY=%0d WR_LATENCY=%0d",
                 MEM_BASE, MEM_BYTES, RD_LATENCY, WR_LATENCY);

        // ==============================================================
        // 1. Single beat + WSTRB byte lanes
        // ==============================================================
        a0_word = MEM_BASE + LWORD_IDX * 8;
        // 1a: full-word write/read
        wbuf_force(0, 64'h1122_3344_5566_7788, 8'hFF);
        wr_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h3);
        rd_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h3, 1'b0);
        chk(rd_beats == 1, "single-beat read returns one beat");

        // Hand-checked lane tests below assert on the DUT's READBACK (rd_buf),
        // not on the TB's own reference model: a stub that mis-applies WSTRB
        // fails these directly.
        // 1b: low half only (strb 8'h0F) — upper 4 bytes must stay from 1a
        wbuf_force(0, 64'h0000_0000_FFFF_FFFF, 8'h0F);
        wr_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h4);
        rd_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h4, 1'b0);
        chk(rd_buf[0] === {32'h1122_3344, 32'hFFFF_FFFF},
            "DUT readback: WSTRB 0x0F wrote only the low 4 bytes (hand-checked)");

        // 1c: high half only (strb 8'hF0) — low 4 bytes must stay from 1b
        wbuf_force(0, 64'hDEAD_BEEF_0000_0000, 8'hF0);
        wr_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h5);
        rd_burst(a0_word, 8'd0, 3'd3, INCR, 1'b0, 4'h5, 1'b0);
        chk(rd_buf[0] === {32'hDEAD_BEEF, 32'hFFFF_FFFF},
            "DUT readback: WSTRB 0xF0 wrote only the high 4 bytes (hand-checked)");

        // 1d: partial strobe in the middle of a word (lanes 2,3 only)
        tmpw = mem_pattern(LWORD_IDX + 1);          // pristine preload
        exp_word = {tmpw[63:32], 16'h0000, tmpw[15:0]};   // lanes 2,3 = bits 16..31
        wbuf_force(0, 64'h0000_0000_0000_0000, 8'h0C);
        wr_burst(a0_word + 8, 8'd0, 3'd3, INCR, 1'b0, 4'h6);
        rd_burst(a0_word + 8, 8'd0, 3'd3, INCR, 1'b0, 4'h6, 1'b0);
        chk(rd_buf[0] === exp_word,
            "DUT readback: WSTRB 0x0C hit only lanes 2..3 (hand-checked)");

        // 1e: unaligned single byte write (lane 5 = bits 40..47)
        wbuf_force(0, 64'h0000_A500_0000_0000, 8'h20);
        wr_burst(a0_word + 8 + 5, 8'd0, 3'd0, INCR, 1'b0, 4'h7);
        rd_burst(a0_word + 8, 8'd0, 3'd3, INCR, 1'b0, 4'h7, 1'b0);
        chk(rd_buf[0] === {exp_word[63:48], 8'hA5, exp_word[39:0]},
            "DUT readback: unaligned size=0 write hit lane 5 only (hand-checked)");

        // ==============================================================
        // 2. Multi-beat INCR bursts over len/size combinations
        // ==============================================================
        // 2a: 4 beats x 8 bytes, full strobe
        wbuf_lanes(4, A1, 3'd3, 1'b0);
        wr_burst(A1, 8'd3, 3'd3, INCR, 1'b0, 4'h8);
        rd_burst(A1, 8'd3, 3'd3, INCR, 1'b0, 4'h8, 1'b1);
        chk(rd_beats == 4, "4-beat burst returns 4 beats");

        // 2b: 16 beats x 8 bytes, random strobes (byte lanes matter)
        wbuf_lanes(16, A2, 3'd3, 1'b1);
        wr_burst(A2, 8'd15, 3'd3, INCR, 1'b0, 4'h9);
        rd_burst(A2, 8'd15, 3'd3, INCR, 1'b0, 4'h9, 1'b1);
        chk(rd_beats == 16, "16-beat burst returns 16 beats");

        // 2c: narrow bursts — 4-byte beats (size=2), 8 beats
        wbuf_lanes(8, A3, 3'd2, 1'b0);
        wr_burst(A3, 8'd7, 3'd2, INCR, 1'b0, 4'hA);
        rd_burst(A3, 8'd7, 3'd2, INCR, 1'b0, 4'hA, 1'b1);
        chk(rd_beats == 8, "8 x size=2 beats return 8 beats");

        // 2d: narrow bursts — 2-byte (size=1) and 1-byte (size=0) beats
        wbuf_lanes(4, A3 + 32, 3'd1, 1'b0);
        wr_burst(A3 + 32, 8'd3, 3'd1, INCR, 1'b0, 4'hB);
        rd_burst(A3 + 32, 8'd3, 3'd1, INCR, 1'b0, 4'hB, 1'b0);
        wbuf_lanes(4, A3 + 40, 3'd0, 1'b0);
        wr_burst(A3 + 40, 8'd3, 3'd0, INCR, 1'b0, 4'hC);
        rd_burst(A3 + 40, 8'd3, 3'd0, INCR, 1'b0, 4'hC, 1'b0);

        // 2e: single-beat len=0 with size=0 and size=1
        wbuf_lanes(1, A3 + 48, 3'd0, 1'b0);
        wr_burst(A3 + 48, 8'd0, 3'd0, INCR, 1'b0, 4'hD);
        rd_burst(A3 + 48, 8'd0, 3'd0, INCR, 1'b0, 4'hD, 1'b0);
        wbuf_lanes(1, A3 + 50, 3'd1, 1'b0);
        wr_burst(A3 + 50, 8'd0, 3'd1, INCR, 1'b0, 4'hE);
        rd_burst(A3 + 50, 8'd0, 3'd1, INCR, 1'b0, 4'hE, 1'b0);

        // 2f: UNALIGNED INCR — size=2 start at +2: beats at +2, +4, +8, +12
        //     (the aligned-address rule; a naive start + N*size model fails)
        wbuf_lanes(4, A4 + 2, 3'd2, 1'b0);
        wr_burst(A4 + 2, 8'd3, 3'd2, INCR, 1'b0, 4'h1);
        chk(beat_addr(A4 + 2, 1, 3'd2) === (A4 + 4),   "aligned rule: beat 2 at +4");
        chk(beat_addr(A4 + 2, 2, 3'd2) === (A4 + 8),   "aligned rule: beat 3 at +8");
        rd_burst(A4 + 2, 8'd3, 3'd2, INCR, 1'b0, 4'h1, 1'b0);

        // 2g: unaligned INCR with size=3 (reduced first beat lanes)
        wbuf_lanes(3, A4 + 64 + 4, 3'd3, 1'b1);
        wr_burst(A4 + 64 + 4, 8'd2, 3'd3, INCR, 1'b0, 4'h2);
        rd_burst(A4 + 64 + 4, 8'd2, 3'd3, INCR, 1'b0, 4'h2, 1'b1);

        // 2h: W-before-AW ordering (the slave may wait for AW; W must not be lost)
        wbuf_lanes(2, A5, 3'd3, 1'b0);
        t_len = 8'd1; t_id = 4'hF;
        @(negedge clk); wvalid = 1'b1; wdata = wbuf[0]; wstrb = sbuf[0]; wlast = 1'b0;
        repeat (3) @(negedge clk);                 // W held 3 cycles before AW
        chk(wready === 1'b0, "WREADY low until AW is captured");
        aw_issue(A5, 8'd1, 3'd3, INCR, 1'b0, 4'hF);
        @(posedge clk);
        while (!wready) @(posedge clk);
        @(negedge clk); wvalid = 1'b0;
        ref_write_beat(beat_addr(A5, 0, 3'd3), wbuf[0], sbuf[0]);
        w_beats(1, 1, A5, 3'd3, OKAY);
        b_wait(OKAY, 4'hF);
        rd_burst(A5, 8'd1, 3'd3, INCR, 1'b0, 4'hF, 1'b0);

        // ==============================================================
        // 3. Back-to-back mixed read/write traffic
        // ==============================================================
        for (i = 0; i < 6; i = i + 1) begin
            wbuf_lanes(4, A5 + 64 + i * 64, 3'd3, 1'b1);
            wr_burst(A5 + 64 + i * 64, 8'd3, 3'd3, INCR, 1'b0, 4'h7);
            rd_burst(A5 + 64 + i * 64, 8'd3, 3'd3, INCR, 1'b0, 4'h7, 1'b1);
        end

        // 3b: read burst issued in the MIDDLE of a write burst's W stream, with
        //     B deliberately left pending while the read drains (independent
        //     write/read engines; nothing dropped).
        wbuf_lanes(4, CW, 3'd3, 1'b1);
        t_len = 8'd3; t_id = 4'h9;
        aw_issue(CW, 8'd3, 3'd3, INCR, 1'b0, 4'h9);
        w_beats(0, 1, CW, 3'd3, OKAY);
        ar_issue(CR, 8'd3, 3'd3, INCR, 1'b0, 4'h9);
        w_beats(2, 3, CW, 3'd3, OKAY);
        rd_collect(CR, 8'd3, 3'd3, OKAY, 1'b1);     // R beats drain first
        chk(rd_beats == 4, "overlapped read returned 4 beats");
        b_wait(OKAY, 4'h9);                         // ... then the pending B
        rd_burst(CW, 8'd3, 3'd3, INCR, 1'b0, 4'h9, 1'b0);

        // ==============================================================
        // 4. Long backpressure on both channels
        // ==============================================================
        bp_max = 64;
        wbuf_lanes(4, A1 + 128, 3'd3, 1'b1);
        wr_burst(A1 + 128, 8'd3, 3'd3, INCR, 1'b0, 4'h3);
        rd_burst(A1 + 128, 8'd3, 3'd3, INCR, 1'b0, 4'h3, 1'b1);
        chk(rd_beats == 4, "long-stall burst still returned all 4 beats");
        bp_max = 5;

        // ==============================================================
        // 5. Documented error policy
        // ==============================================================
        // 5a: read past the window -> DECERR, one beat, RLAST=1, RDATA=0
        rd_burst(MEM_BASE + MEM_BYTES, 8'd3, 3'd3, INCR, 1'b0, 4'h1, 1'b0);
        chk(rd_beats == 1, "out-of-range read returns exactly one error beat");
        // 5b: read below the window (unsigned wrap) -> DECERR
        rd_burst(MEM_BASE - 32'h8, 8'd0, 3'd3, INCR, 1'b0, 4'h1, 1'b0);
        // 5c: boundary-spanning write -> DECERR and NOTHING committed
        wbuf_lanes(2, MEM_BASE + MEM_BYTES - 8, 3'd3, 1'b0);
        wr_burst(MEM_BASE + MEM_BYTES - 8, 8'd1, 3'd3, INCR, 1'b0, 4'h2);
        rd_burst(MEM_BASE + MEM_BYTES - 8, 8'd0, 3'd3, INCR, 1'b0, 4'h2, 1'b0);
        chk(rd_buf[0] === mem_pattern((MEM_BYTES - 8) / 8),
            "DUT readback: DECERR write committed nothing (last word pristine)");
        // 5d: long DECERR write — every W beat must still be sunk
        wbuf_lanes(16, MEM_BASE + MEM_BYTES, 3'd3, 1'b1);
        wr_burst(MEM_BASE + MEM_BYTES, 8'd15, 3'd3, INCR, 1'b0, 4'h3);
        // 5e: WRAP / FIXED / oversized / locked -> SLVERR
        rd_burst(A1, 8'd3, 3'd3, WRAP,  1'b0, 4'h4, 1'b0);
        wr_burst(A1, 8'd3, 3'd3, WRAP,  1'b0, 4'h4);
        rd_burst(A1, 8'd3, 3'd3, FIXED, 1'b0, 4'h5, 1'b0);
        wr_burst(A1, 8'd3, 3'd3, FIXED, 1'b0, 4'h5);
        rd_burst(A1, 8'd0, 3'd4, INCR,  1'b0, 4'h6, 1'b0);   // size > bus width
        wr_burst(A1, 8'd0, 3'd4, INCR,  1'b0, 4'h6);
        rd_burst(A1, 8'd0, 3'd3, INCR,  1'b1, 4'h7, 1'b0);   // exclusive/AxLOCK
        wr_burst(A1, 8'd0, 3'd3, INCR,  1'b1, 4'h7);
        // 5f: 4 KiB boundary crossing -> SLVERR (start at 0xFFC, size=2, len=1)
        rd_burst(MEM_BASE + 32'h1000 - 32'h4, 8'd1, 3'd2, INCR, 1'b0, 4'h8, 1'b0);
        wr_burst(MEM_BASE + 32'h1000 - 32'h4, 8'd1, 3'd2, INCR, 1'b0, 4'h8);
        // 5g: an OKAY write immediately after every error case above proves the
        //     engines recovered (no stuck FSM).
        wbuf_lanes(2, A5 + 512, 3'd3, 1'b1);
        wr_burst(A5 + 512, 8'd1, 3'd3, INCR, 1'b0, 4'hA);
        rd_burst(A5 + 512, 8'd1, 3'd3, INCR, 1'b0, 4'hA, 1'b0);
        chk(rd_beats == 2, "engines recovered after the error cases");

        // ==============================================================
        // 6. Randomized soak against the reference model (bounded budget)
        // ==============================================================
        n_tx = 0;
        while ((cyc < SOAK_CYCLES) && (n_tx < SOAK_MAX_TX)) begin
            rw       = {$random(tb_seed)} & 32'h1;
            off      = ({$random(tb_seed)} % SOAK_SPAN) & 32'hFFFF_FFF8;
            rad      = MEM_BASE + off;
            unaligned = (({$random(tb_seed)} % 4) == 0);
            sz       = (n_tx % 8 == 7) ? ({$random(tb_seed)} % 3) : 3;   // mostly full width
            ln       = {$random(tb_seed)} % 8;
            if (unaligned && sz < 3) rad = rad + ({$random(tb_seed)} & 32'h7);
            use_bp   = ((({$random(tb_seed)} % 3) == 0));
            bp_max   = use_bp ? 6 : 0;
            if (rw == 0) begin
                wbuf_lanes(int'(ln) + 1, rad, sz[2:0], 1'b1);
                wr_burst(rad, ln[7:0], sz[2:0], INCR, 1'b0, 4'h1);
            end else begin
                rd_burst(rad, ln[7:0], sz[2:0], INCR, 1'b0, 4'h1, use_bp);
            end
            bp_max = 5;
            n_tx = n_tx + 1;
        end

        // ==============================================================
        // Report
        // ==============================================================
        $display("---- tb_eth_dram_ctrl: %0d checks, %0d errors, %0d soak tx, %0d cycles",
                 checks, errors, n_tx, cyc);
        if (errors == 0)
            $display("TEST PASSED: eth_dram_ctrl (AXI4 INCR bursts, WSTRB lanes, backpressure, DECERR/SLVERR, soak)");
        else
            $display("TEST FAILED: %0d errors", errors);
        $finish;
    end

    // Watchdog: 2 ms = 200k cycles at 100 MHz — generous vs the soak budget.
    initial begin
        #2_000_000;
        $display("TEST FAILED: watchdog (%0d cycles, %0d checks, %0d errors)", cyc, checks, errors);
        $finish;
    end

endmodule

`default_nettype wire
