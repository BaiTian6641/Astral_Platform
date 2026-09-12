`default_nettype none
// SCRATCH (E3-SVC1 Fmax measurement) — NOT tracked RTL (tracked copy:
// ethereal-fabric/tests/npu/synth/probe_npu.sv).
// Probe wrapper around the real npu_t service tile (tracked RTL, unmodified).
// A self-starting stimulus FSM cycles the service register ABI:
//   ph=0 SESSION_ID (session blank) -> ph=1 DESC -> ph=2 START
//   ph>=3 alternate A_WR / W_WR with LFSR data (accepted while the tile is IDLE)
// so every run exercises the feeder, the 8x8 PE array, the capture adders and the
// CSR block. The ENTIRE observability bus is XOR-reduced into 4 registered LEDs
// (nothing is trimmed); the reduction tree is on the probe side and is therefore
// part of the measured critical path — the usual probe-limited lower bound, exactly
// as in the E2-FAB2/FAB2b measurements.
module probe_npu (
    input  logic clk,
    input  logic reset,          // active-low
    output logic led0, led1, led2, led3
);
    logic [7:0]  ph;
    logic [31:0] lfsr;
    logic        csr_we;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;
    logic        irq;
    logic [2047:0] obs_acc, obs_cbuf;
    logic [511:0]  obs_wgt, obs_wstg, obs_feed;
    logic [79:0]   obs_ctl;

    always_ff @(posedge clk) begin
        if (!reset) begin
            ph   <= 8'd0;
            lfsr <= 32'h1F3A_2B7C;
        end else begin
            ph   <= ph + 8'd1;
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1]};
        end
    end

    always_comb begin
        csr_we    = 1'b1;
        csr_addr  = 8'h10;                      // A_WR (default)
        csr_wdata = lfsr;
        case (ph)
            8'd0:  begin csr_addr = 8'h0C; csr_wdata = 32'h0000_0001; end            // SESSION_ID
            8'd1:  begin csr_addr = 8'h08; csr_wdata = {8'h00, 8'd8, 8'd8, 8'd8}; end // DESC M=K=N=8
            8'd2:  begin csr_addr = 8'h00; csr_wdata = 32'h0000_0005; end            // START + IRQ_EN
            8'd3, 8'd5, 8'd7, 8'd9, 8'd11, 8'd13, 8'd15:
                   begin csr_addr = 8'h14; csr_wdata = lfsr; end                     // W_WR
            default: begin csr_addr = 8'h10; csr_wdata = lfsr; end                   // A_WR
        endcase
    end

    npu_t u_npu (
        .clk_i        (clk),
        .rst_ni       (reset),
        .sess_rst_i   (1'b0),
        .csr_we_i     (csr_we),
        .csr_re_i     (1'b0),
        .csr_addr_i   (csr_addr),
        .csr_wdata_i  (csr_wdata),
        .csr_rdata_o  (csr_rdata),
        .irq_o        (irq),
        .obs_acc_o    (obs_acc),
        .obs_wgt_o    (obs_wgt),
        .obs_wstg_o   (obs_wstg),
        .obs_feed_o   (obs_feed),
        .obs_cbuf_o   (obs_cbuf),
        .obs_ctl_o    (obs_ctl)
    );

    // 5712 observability bits in four buckets of 1428 (full coverage, no trimming).
    logic [5711:0] obs_all;
    logic [3:0]    obs_r;
    assign obs_all = {obs_acc, obs_cbuf, obs_wgt, obs_wstg, obs_feed, obs_ctl};
    always_ff @(posedge clk) begin
        obs_r[0] <= ^obs_all[1427:0];
        obs_r[1] <= ^obs_all[2855:1428];
        obs_r[2] <= ^obs_all[4283:2856];
        obs_r[3] <= ^obs_all[5711:4284];
    end

    assign led0 = obs_r[0];
    assign led1 = obs_r[1];
    assign led2 = obs_r[2];
    assign led3 = obs_r[3];
    logic _unused_ok;
    assign _unused_ok = csr_rdata[0] ^ irq;
endmodule

`default_nettype wire
