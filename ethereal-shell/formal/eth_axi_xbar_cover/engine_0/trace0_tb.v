`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [63:0] PI_s_araddr;
  reg [0:0] PI_rst_ni;
  reg [1:0] PI_s_bready;
  reg [63:0] PI_s_awaddr;
  reg [7:0] PI_s_arid;
  reg [1:0] PI_s_awvalid;
  reg [1:0] PI_s_rready;
  reg [63:0] PI_s_wdata;
  reg [63:0] PI_m_rdata;
  reg [3:0] PI_m_rresp;
  reg [1:0] PI_s_arvalid;
  reg [1:0] PI_m_awready;
  reg [1:0] PI_m_arready;
  reg [1:0] PI_m_bvalid;
  reg [9:0] PI_m_rid;
  reg [3:0] PI_m_bresp;
  reg [1:0] PI_m_wready;
  reg [0:0] PI_clk_i;
  reg [1:0] PI_m_rvalid;
  reg [1:0] PI_s_wvalid;
  reg [7:0] PI_s_wstrb;
  reg [9:0] PI_m_bid;
  reg [7:0] PI_s_awid;
  eth_axi_xbar UUT (
    .s_araddr(PI_s_araddr),
    .rst_ni(PI_rst_ni),
    .s_bready(PI_s_bready),
    .s_awaddr(PI_s_awaddr),
    .s_arid(PI_s_arid),
    .s_awvalid(PI_s_awvalid),
    .s_rready(PI_s_rready),
    .s_wdata(PI_s_wdata),
    .m_rdata(PI_m_rdata),
    .m_rresp(PI_m_rresp),
    .s_arvalid(PI_s_arvalid),
    .m_awready(PI_m_awready),
    .m_arready(PI_m_arready),
    .m_bvalid(PI_m_bvalid),
    .m_rid(PI_m_rid),
    .m_bresp(PI_m_bresp),
    .m_wready(PI_m_wready),
    .clk_i(PI_clk_i),
    .m_rvalid(PI_m_rvalid),
    .s_wvalid(PI_s_wvalid),
    .s_wstrb(PI_s_wstrb),
    .m_bid(PI_m_bid),
    .s_awid(PI_s_awid)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$4665  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$4639  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4645  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4651  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4657  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4663  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4669  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$4675  = 1'b1;
    UUT._witness_.anyinit_procdff_3610 = 2'b00;
    UUT._witness_.anyinit_procdff_3615 = 1'b0;
    UUT._witness_.anyinit_procdff_3620 = 2'b00;
    UUT._witness_.anyinit_procdff_3625 = 2'b00;
    UUT._witness_.anyinit_procdff_3630 = 2'b00;
    UUT._witness_.anyinit_procdff_3635 = 1'b0;
    UUT._witness_.anyinit_procdff_3640 = 2'b00;
    UUT._witness_.anyinit_procdff_3645 = 2'b00;
    UUT._witness_.anyinit_procdff_3664 = 1'b0;
    UUT._witness_.anyinit_procdff_3665 = 1'b0;
    UUT._witness_.anyinit_procdff_3666 = 1'b0;
    UUT._witness_.anyinit_procdff_3667 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3668 = 4'b1000;
    UUT._witness_.anyinit_procdff_3669 = 1'b0;
    UUT._witness_.anyinit_procdff_3670 = 1'b0;
    UUT._witness_.anyinit_procdff_3671 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3672 = 4'b1000;
    UUT._witness_.anyinit_procdff_3673 = 1'b0;
    UUT._witness_.anyinit_procdff_3674 = 1'b0;
    UUT._witness_.anyinit_procdff_3675 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3676 = 4'b1000;
    UUT._witness_.anyinit_procdff_3677 = 1'b0;
    UUT._witness_.anyinit_procdff_3678 = 1'b0;
    UUT._witness_.anyinit_procdff_3679 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3680 = 4'b1000;
    UUT._witness_.anyinit_procdff_3681 = 1'b0;
    UUT._witness_.anyinit_procdff_3682 = 1'b0;
    UUT._witness_.anyinit_procdff_3683 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3684 = 4'b1000;
    UUT._witness_.anyinit_procdff_3685 = 1'b0;
    UUT._witness_.anyinit_procdff_3686 = 1'b0;
    UUT._witness_.anyinit_procdff_3687 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3688 = 4'b1000;
    UUT._witness_.anyinit_procdff_3689 = 1'b0;
    UUT._witness_.anyinit_procdff_3690 = 1'b0;
    UUT._witness_.anyinit_procdff_3691 = 5'b10000;
    UUT._witness_.anyinit_procdff_3692 = 2'b10;
    UUT._witness_.anyinit_procdff_3693 = 1'b0;
    UUT._witness_.anyinit_procdff_3694 = 1'b0;
    UUT._witness_.anyinit_procdff_3695 = 5'b10000;
    UUT._witness_.anyinit_procdff_3696 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3697 = 2'b10;
    UUT._witness_.anyinit_procdff_3698 = 1'b0;
    UUT._witness_.anyinit_procdff_3699 = 1'b0;
    UUT._witness_.anyinit_procdff_3700 = 5'b10000;
    UUT._witness_.anyinit_procdff_3701 = 2'b10;
    UUT._witness_.anyinit_procdff_3702 = 1'b0;
    UUT._witness_.anyinit_procdff_3703 = 1'b0;
    UUT._witness_.anyinit_procdff_3704 = 5'b10000;
    UUT._witness_.anyinit_procdff_3705 = 32'b10000000000000000000000000000000;
    UUT._witness_.anyinit_procdff_3706 = 2'b10;
    UUT._witness_.anyinit_procdff_3718 = 4'b0000;
    UUT._witness_.anyinit_procdff_3723 = 4'b0000;
    UUT._witness_.anyinit_procdff_3729 = 3'b000;
    UUT._witness_.anyinit_procdff_3734 = 3'b000;
    UUT._witness_.anyinit_procdff_3744 = 1'b0;
    UUT._witness_.anyinit_procdff_3749 = 5'b00000;
    UUT._witness_.anyinit_procdff_3754 = 2'b00;
    UUT._witness_.anyinit_procdff_3759 = 5'b00000;
    UUT._witness_.anyinit_procdff_3764 = 3'b000;
    UUT._witness_.anyinit_procdff_3769 = 3'b000;
    UUT.\g_cap[0] .u_ar._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[0] .u_ar._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[0] .u_ar._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[0] .u_ar._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[0] .u_aw._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[0] .u_aw._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[0] .u_aw._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[0] .u_aw._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[0] .u_w._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[0] .u_w._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[0] .u_w._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[0] .u_w._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_ar._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[1] .u_ar._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_ar._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[1] .u_ar._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_aw._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[1] .u_aw._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_aw._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[1] .u_aw._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_w._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_cap[1] .u_w._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_cap[1] .u_w._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_cap[1] .u_w._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_resp[0] .u_b._witness_.anyinit_procdff_3558 = 1'b0;
    UUT.\g_resp[0] .u_b._witness_.anyinit_procdff_3563 = 6'b000000;
    UUT.\g_resp[0] .u_b._witness_.anyinit_procdff_3568 = 1'b0;
    UUT.\g_resp[0] .u_b._witness_.anyinit_procdff_3573 = 6'b000000;
    UUT.\g_resp[0] .u_r._witness_.anyinit_procdff_3586 = 1'b0;
    UUT.\g_resp[0] .u_r._witness_.anyinit_procdff_3591 = 38'b00000000000000000000000000000000000000;
    UUT.\g_resp[0] .u_r._witness_.anyinit_procdff_3596 = 1'b0;
    UUT.\g_resp[0] .u_r._witness_.anyinit_procdff_3601 = 38'b00000000000000000000000000000000000000;
    UUT.\g_resp[1] .u_b._witness_.anyinit_procdff_3558 = 1'b0;
    UUT.\g_resp[1] .u_b._witness_.anyinit_procdff_3563 = 6'b000000;
    UUT.\g_resp[1] .u_b._witness_.anyinit_procdff_3568 = 1'b0;
    UUT.\g_resp[1] .u_b._witness_.anyinit_procdff_3573 = 6'b000000;
    UUT.\g_resp[1] .u_r._witness_.anyinit_procdff_3586 = 1'b0;
    UUT.\g_resp[1] .u_r._witness_.anyinit_procdff_3591 = 38'b00000000000000000000000000000000000000;
    UUT.\g_resp[1] .u_r._witness_.anyinit_procdff_3596 = 1'b0;
    UUT.\g_resp[1] .u_r._witness_.anyinit_procdff_3601 = 38'b00000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_ar._witness_.anyinit_procdff_3789 = 1'b0;
    UUT.\g_slv_in[0] .u_ar._witness_.anyinit_procdff_3794 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_ar._witness_.anyinit_procdff_3799 = 1'b0;
    UUT.\g_slv_in[0] .u_ar._witness_.anyinit_procdff_3804 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_aw._witness_.anyinit_procdff_3789 = 1'b0;
    UUT.\g_slv_in[0] .u_aw._witness_.anyinit_procdff_3794 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_aw._witness_.anyinit_procdff_3799 = 1'b0;
    UUT.\g_slv_in[0] .u_aw._witness_.anyinit_procdff_3804 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_w._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_slv_in[0] .u_w._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_slv_in[0] .u_w._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_slv_in[0] .u_w._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_ar._witness_.anyinit_procdff_3789 = 1'b0;
    UUT.\g_slv_in[1] .u_ar._witness_.anyinit_procdff_3794 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_ar._witness_.anyinit_procdff_3799 = 1'b0;
    UUT.\g_slv_in[1] .u_ar._witness_.anyinit_procdff_3804 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_aw._witness_.anyinit_procdff_3789 = 1'b0;
    UUT.\g_slv_in[1] .u_aw._witness_.anyinit_procdff_3794 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_aw._witness_.anyinit_procdff_3799 = 1'b0;
    UUT.\g_slv_in[1] .u_aw._witness_.anyinit_procdff_3804 = 37'b0000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_w._witness_.anyinit_procdff_3817 = 1'b0;
    UUT.\g_slv_in[1] .u_w._witness_.anyinit_procdff_3822 = 36'b000000000000000000000000000000000000;
    UUT.\g_slv_in[1] .u_w._witness_.anyinit_procdff_3827 = 1'b0;
    UUT.\g_slv_in[1] .u_w._witness_.anyinit_procdff_3832 = 36'b000000000000000000000000000000000000;
    UUT.past_valid = 1'b0;

    // state 0
    PI_s_araddr = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_rst_ni = 1'b0;
    PI_s_bready = 2'b00;
    PI_s_awaddr = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_s_arid = 8'b00000000;
    PI_s_awvalid = 2'b00;
    PI_s_rready = 2'b00;
    PI_s_wdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_m_rdata = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_m_rresp = 4'b0000;
    PI_s_arvalid = 2'b00;
    PI_m_awready = 2'b00;
    PI_m_arready = 2'b00;
    PI_m_bvalid = 2'b00;
    PI_m_rid = 10'b0000000000;
    PI_m_bresp = 4'b0000;
    PI_m_wready = 2'b00;
    PI_clk_i = 1'b0;
    PI_m_rvalid = 2'b00;
    PI_s_wvalid = 2'b00;
    PI_s_wstrb = 8'b00000000;
    PI_m_bid = 10'b0000000000;
    PI_s_awid = 8'b00000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_s_araddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_rst_ni <= 1'b1;
      PI_s_bready <= 2'b00;
      PI_s_awaddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_s_arid <= 8'b00000000;
      PI_s_awvalid <= 2'b00;
      PI_s_rready <= 2'b00;
      PI_s_wdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rdata <= 64'b1000000000000000000000000000000010000000000000000000000000000000;
      PI_m_rresp <= 4'b1010;
      PI_s_arvalid <= 2'b01;
      PI_m_awready <= 2'b00;
      PI_m_arready <= 2'b00;
      PI_m_bvalid <= 2'b00;
      PI_m_rid <= 10'b0000000000;
      PI_m_bresp <= 4'b1010;
      PI_m_wready <= 2'b00;
      PI_clk_i <= 1'b0;
      PI_m_rvalid <= 2'b00;
      PI_s_wvalid <= 2'b00;
      PI_s_wstrb <= 8'b00000000;
      PI_m_bid <= 10'b0000000000;
      PI_s_awid <= 8'b00000000;
    end

    // state 2
    if (cycle == 1) begin
      PI_s_araddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_rst_ni <= 1'b1;
      PI_s_bready <= 2'b00;
      PI_s_awaddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_s_arid <= 8'b00000000;
      PI_s_awvalid <= 2'b00;
      PI_s_rready <= 2'b00;
      PI_s_wdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rresp <= 4'b0000;
      PI_s_arvalid <= 2'b00;
      PI_m_awready <= 2'b00;
      PI_m_arready <= 2'b00;
      PI_m_bvalid <= 2'b00;
      PI_m_rid <= 10'b0000000000;
      PI_m_bresp <= 4'b0000;
      PI_m_wready <= 2'b00;
      PI_clk_i <= 1'b0;
      PI_m_rvalid <= 2'b00;
      PI_s_wvalid <= 2'b00;
      PI_s_wstrb <= 8'b00000000;
      PI_m_bid <= 10'b0000000000;
      PI_s_awid <= 8'b00000000;
    end

    // state 3
    if (cycle == 2) begin
      PI_s_araddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_rst_ni <= 1'b1;
      PI_s_bready <= 2'b00;
      PI_s_awaddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_s_arid <= 8'b00000000;
      PI_s_awvalid <= 2'b00;
      PI_s_rready <= 2'b00;
      PI_s_wdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rdata <= 64'b1000000000000000000000000000000010000000000000000000000000000000;
      PI_m_rresp <= 4'b1010;
      PI_s_arvalid <= 2'b00;
      PI_m_awready <= 2'b00;
      PI_m_arready <= 2'b00;
      PI_m_bvalid <= 2'b00;
      PI_m_rid <= 10'b0000000000;
      PI_m_bresp <= 4'b1010;
      PI_m_wready <= 2'b00;
      PI_clk_i <= 1'b0;
      PI_m_rvalid <= 2'b00;
      PI_s_wvalid <= 2'b00;
      PI_s_wstrb <= 8'b00000000;
      PI_m_bid <= 10'b0000000000;
      PI_s_awid <= 8'b00000000;
    end

    // state 4
    if (cycle == 3) begin
      PI_s_araddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_rst_ni <= 1'b0;
      PI_s_bready <= 2'b00;
      PI_s_awaddr <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_s_arid <= 8'b00000000;
      PI_s_awvalid <= 2'b00;
      PI_s_rready <= 2'b00;
      PI_s_wdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rdata <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_m_rresp <= 4'b0000;
      PI_s_arvalid <= 2'b00;
      PI_m_awready <= 2'b00;
      PI_m_arready <= 2'b00;
      PI_m_bvalid <= 2'b00;
      PI_m_rid <= 10'b0000000000;
      PI_m_bresp <= 4'b0000;
      PI_m_wready <= 2'b00;
      PI_clk_i <= 1'b0;
      PI_m_rvalid <= 2'b00;
      PI_s_wvalid <= 2'b00;
      PI_s_wstrb <= 8'b00000000;
      PI_m_bid <= 10'b0000000000;
      PI_s_awid <= 8'b00000000;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
