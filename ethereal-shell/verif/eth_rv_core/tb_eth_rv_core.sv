`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      tb_eth_rv_core
// Description: Verilator testbench for eth_rv_core: behavioral memory + RVFI commit-trace dump.
// Details:     The RTL-side half of the DiffTest integration (C14 §5). It
//              instantiates the core, serves its two v0 ports out of a
//              zero-filled 256 KiB word array loaded from a $readmemh image, and
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
//              Termination mirrors the golden generator: the run ends at the
//              commit whose store covers the HTIF `tohost` mailbox (crt0.S'
//              final `sd`), so both streams stop at the same instruction. The
//              run also ends on a cycle budget, or when the core takes more
//              traps than `+maxtraps` (a trap is a normal, handled event now —
//              the corpus exercises them on purpose — but a trap loop must not
//              run forever).
//
//              `+fault_index=N +fault_field=<pc|rd|value|mem_addr|mem_wdata>`
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
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        TESTBENCH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (I/D/RVFI ports), §5 (DiffTest)
//              ethereal-shell/verif/eth_rv/README.md (trace protocol)
// Notes:       Sim-only (Tags: TESTBENCH): not part of `make lint`'s RTL set,
//              lintable with `verilator --lint-only -Wall --timing` regardless.
module tb_eth_rv_core;

    // ------------------------------------------------------------------ params
    localparam int unsigned MEM_WORDS = 32_768;   // 256 KiB @ 8 B/word

`ifndef ETH_RV_LINE_BEATS
`define ETH_RV_LINE_BEATS 1     // eth_rv_axi_master read line fill (1 = single beat)
`endif

`ifdef ETH_RV_DRAM_AXI
    // eth_dram_ctrl window (the ASSUMPTION of the DRAM slice: 0x8000_0000 + 1 MiB)
    localparam logic [31:0] DRAM_BASE  = 32'h8000_0000;
    localparam int unsigned DRAM_BYTES = 1 << 20;
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

    logic        dmem_req;
    logic        dmem_we;
    logic [63:0] dmem_addr;
    logic [63:0] dmem_wdata;
    logic [7:0]  dmem_wstrb;
    logic        dmem_ready;
    logic [63:0] dmem_rdata;

    logic        rvfi_valid;
    logic [63:0] rvfi_order;
    logic [63:0] rvfi_pc;
    logic [31:0] rvfi_insn;
    logic        rvfi_rd_we;
    logic [4:0]  rvfi_rd_addr;
    logic [63:0] rvfi_rd_wdata;
    logic        rvfi_mem_valid;
    logic [63:0] rvfi_mem_addr;
    logic [63:0] rvfi_mem_wdata;
    logic [7:0]  rvfi_mem_wmask;
    logic [7:0]  rvfi_mem_rmask;

    logic        core_err;
    logic [63:0] core_err_pc;
    logic [31:0] core_err_insn;
    logic [3:0]  core_err_code;

    eth_rv_core u_dut (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .imem_req_o      (imem_req),
        .imem_addr_o     (imem_addr),
        .imem_ready_i    (imem_ready),
        .imem_rdata_i    (imem_rdata),
        .dmem_req_o      (dmem_req),
        .dmem_we_o       (dmem_we),
        .dmem_addr_o     (dmem_addr),
        .dmem_wdata_o    (dmem_wdata),
        .dmem_wstrb_o    (dmem_wstrb),
        .dmem_ready_i    (dmem_ready),
        .dmem_rdata_i    (dmem_rdata),
        .rvfi_valid_o    (rvfi_valid),
        .rvfi_order_o    (rvfi_order),
        .rvfi_pc_o       (rvfi_pc),
        .rvfi_insn_o     (rvfi_insn),
        .rvfi_rd_we_o    (rvfi_rd_we),
        .rvfi_rd_addr_o  (rvfi_rd_addr),
        .rvfi_rd_wdata_o (rvfi_rd_wdata),
        .rvfi_mem_valid_o(rvfi_mem_valid),
        .rvfi_mem_addr_o (rvfi_mem_addr),
        .rvfi_mem_wdata_o(rvfi_mem_wdata),
        .rvfi_mem_wmask_o(rvfi_mem_wmask),
        .rvfi_mem_rmask_o(rvfi_mem_rmask),
        .err_o           (core_err),
        .err_pc_o        (core_err_pc),
        .err_insn_o      (core_err_insn),
        .err_code_o      (core_err_code)
    );

    // ------------------------------------------------------------------ I port
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
    assign imem_rdata = imem_req ? read_bytes32(imem_addr) : 32'd0;

    // ------------------------------------------------------------------ D port
    logic        dmem_pend;
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

    assign dmem_ready = dmem_req
                        && ((mem_lat == 0)
                            || (dmem_pend && (dmem_addr_q == dmem_addr)
                                && (dmem_wait >= mem_lat)));
    // aligned beat: the eight bytes of the window at (addr & ~7)
    assign dmem_rdata = dmem_req ? mem[word_of(dmem_addr & ~64'd7)] : 64'd0;

    // byte-lane write, at the cycle the access is accepted
    integer      lane;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // nothing to reset: the array is filled from +mem at time 0
        end else if (dmem_req && dmem_we && dmem_ready) begin
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

    // ------------------------------------------------------------------ trace
    integer      trace_fd;
    int unsigned commits;
    int unsigned n_compressed;
    int unsigned n_loads;
    int unsigned n_stores;
    int unsigned traps;
    logic [3:0]  last_trap_cause;
    logic [63:0] last_mem_addr;
    logic [63:0] last_store_data;
    logic [31:0] last_insn;
    int unsigned cycle_cnt;
    bit          stop_now;
    bit          failed;

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
            last_trap_cause <= 4'd0;
            last_mem_addr   <= 64'd0;
            last_store_data <= 64'd0;
            last_insn       <= 32'd0;
            cycle_cnt       <= 0;
            stop_now        <= 1'b0;
            failed          <= 1'b0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;

            if (rvfi_valid && !stop_now) begin
                commits <= commits + 1;
                last_insn <= rvfi_insn;
                if (rvfi_insn[1:0] != 2'b11) begin
                    n_compressed <= n_compressed + 1;
                end
                if (rvfi_mem_valid) begin
                    last_mem_addr <= rvfi_mem_addr;
                    if (rvfi_mem_rmask != 8'd0) begin
                        n_loads <= n_loads + 1;
                    end
                    if (rvfi_mem_wmask != 8'd0) begin
                        n_stores        <= n_stores + 1;
                        last_store_data <= rvfi_mem_wdata;
                    end
                end

                // Always the 8-field form: this dump is the memory-aware side of
                // the DiffTest, so every commit states whether it touched memory
                // (`-` address) and which bytes it read/wrote (masks `-` is
                // reserved for "not reported", which this testbench never needs).
                if (f_we) begin
                    $fwrite(trace_fd, "%0d 0x%016x x%0d 0x%016x ", rvfi_order,
                            f_pc, f_rd, f_value);
                end else begin
                    $fwrite(trace_fd, "%0d 0x%016x - - ", rvfi_order,
                            f_pc);
                end
                if (f_mem_valid) begin
                    if (f_mem_wmask != 8'd0) begin
                        $fwrite(trace_fd, "0x%016x 0x%016x - 0x%02x\n",
                                f_mem_addr, f_mem_wdata, f_mem_wmask);
                    end else begin
                        $fwrite(trace_fd, "0x%016x - 0x%02x -\n",
                                f_mem_addr, f_mem_rmask);
                    end
                end else begin
                    $fwrite(trace_fd, "- - - -\n");
                end

                // HTIF exit: the store that covers `tohost` is the last commit
                if ((rvfi_mem_wmask != 8'd0) && (rvfi_mem_addr[63:3] == tohost_addr[63:3])
                    && rvfi_mem_wmask[tohost_addr[2:0]]) begin
                    stop_now <= 1'b1;
                end
            end

            if (core_err && !stop_now) begin
                traps    <= traps + 1;
                last_trap_cause <= core_err_code;
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
        rst_n        = 1'b0;

        void'($value$plusargs("mem=%s", mem_path));
        void'($value$plusargs("trace=%s", trace_path));
        void'($value$plusargs("base=%h", base_addr));
        void'($value$plusargs("tohost=%h", tohost_addr));
        void'($value$plusargs("memlat=%d", mem_lat));
        void'($value$plusargs("max_cycles=%d", max_cycles));
        void'($value$plusargs("max_traps=%d", max_traps));
        void'($value$plusargs("fault_index=%d", fault_index));
        void'($value$plusargs("fault_value=%h", fault_value));
        void'($value$plusargs("fault_field=%s", fault_field));

        if (mem_path == "") begin
            $display("ETH_RV_TB: FAIL no +mem=<file> given");
            $fatal(1);
        end
`ifdef ETH_RV_DRAM_AXI
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
        if (trace_path == "") begin
            $display("ETH_RV_TB: FAIL no +trace=<file> given");
            $fatal(1);
        end
        trace_fd = $fopen(trace_path, "w");
        if (trace_fd == 0) begin
            $display("ETH_RV_TB: FAIL cannot open trace file '%s'", trace_path);
            $fatal(1);
        end
        $fwrite(trace_fd, "# rv_difftest trace v1\n");
        $fwrite(trace_fd, "# generator: eth_rv_core rtl (eth_rv_core.sv RV-B v0)\n");
        $fwrite(trace_fd, "# fields: cycle pc rd value [mem_addr mem_wdata [mem_rmask mem_wmask]]\n");

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        wait (stop_now === 1'b1);
        @(posedge clk);
        $fclose(trace_fd);

        if (failed) begin
            $display("ETH_RV_TB: FAIL stopped at %0d commits after %0d cycles",
                     commits, cycle_cnt);
            $fatal(1);
        end
`ifdef ETH_RV_DRAM_AXI
        if (axi_err) begin
            $display("ETH_RV_TB: FAIL the DRAM socket answered with a non-OKAY response");
            $fatal(1);
        end
        $display("ETH_RV_TB: PASS %0d commits (%0d compressed), %0d cycles, %0d loads, %0d stores, %0d traps (last mcause=%0d), last mem 0x%016x <- 0x%016x, last insn 0x%08x, AXI %0d AR (%0d multi-beat) %0d R beats, %0d AW %0d W beats",
                 commits, n_compressed, cycle_cnt, n_loads, n_stores, traps,
                 last_trap_cause, last_mem_addr, last_store_data, last_insn,
                 n_axi_ar, n_axi_r_bursts, n_axi_r_beats, n_axi_aw, n_axi_w_beats);
`else
        $display("ETH_RV_TB: PASS %0d commits (%0d compressed), %0d cycles, %0d loads, %0d stores, %0d traps (last mcause=%0d), last mem 0x%016x <- 0x%016x, last insn 0x%08x",
                 commits, n_compressed, cycle_cnt, n_loads, n_stores, traps,
                 last_trap_cause, last_mem_addr, last_store_data, last_insn);
`endif
        $finish;
    end

endmodule
`default_nettype wire
