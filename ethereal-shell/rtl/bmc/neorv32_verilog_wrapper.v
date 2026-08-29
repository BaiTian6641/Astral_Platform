// =============================================================================
// NEORV32 RISC-V Processor - GHDL-converted all-Verilog netlist (VENDORED SNAPSHOT)
// -----------------------------------------------------------------------------
// Source:            https://github.com/stnolting/neorv32
// Upstream version:  v1.13.3.2  (hw_version = 0x01130302)
// Upstream commit:   05f9896  ([sw] update CFS example program), branch main
// License:           BSD-3-Clause (retained) - see LICENSE.neorv32 in this dir.
//                    SPDX-License-Identifier: BSD-3-Clause
// Provenance:        This file is NOT hand-written Ethereal RTL. It is the
//                    machine-generated output of the upstream NEORV32
//                    VHDL-to-Verilog conversion flow. It is vendored here as a
//                    FROZEN snapshot so the repo builds/sims WITHOUT GHDL.
// Generation method: cd rtl/verilog && make convert   (GHDL 'synth --out=verilog')
//                    wrapper = rtl/verilog/neorv32_verilog_wrapper.vhd
// Generated on:      2026-08-08  (regenerated to enable XBUS)
// Tool:              GHDL 7.0.0-dev (LLVM backend), OSS-CAD Suite
// Wrapper config:    rv32imc + IMEM(16KB, ROM boot) + DMEM(16KB) + UART0 +
//                    **XBUS_EN=true** (external bus / Wishbone master);
//                    BOOT_MODE_SELECT=2 (IMEM image, no bootloader).
//                    Top-level ports: clk_i, rstn_i, uart0_txd_o, uart0_rxd_i,
//                    + XBUS master: xbus_adr_o/xbus_dat_o/xbus_cti_o/xbus_tag_o/
//                    xbus_we_o/xbus_sel_o/xbus_stb_o/xbus_cyc_o (out),
//                    xbus_dat_i/xbus_ack_i/xbus_err_i (in).
//                    See README.md in this directory for the exact generic set and
//                    how to regenerate. Do NOT hand-edit; regenerate instead.
// Plan-Ref:          ethereal-plan/components/C05-BMC组件.md (ADR-016 bmc_core)
// =============================================================================
module neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0
  (input  clk_i,
   input  en_i,
   input  rw_i,
   input  [11:0] addr_i,
   input  [7:0] data_i,
   output [7:0] data_o);
  wire [7:0] rdata;
  wire n8198;
  reg [7:0] n8207; // mem_rd
  assign data_o = rdata; //(module output)
  /*# ../../rtl/core/neorv32_prim.vhd:190:10 */
  assign rdata = n8207; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:201:9 */
  assign n8198 = rw_i & en_i;
  reg [7:0] spram[4095:0] ; // memory
  always @(posedge clk_i)
    if (en_i)
      n8207 <= spram[addr_i];
  always @(posedge clk_i)
    if (n8198)
      spram[addr_i] <= data_i;
  /*# ../../rtl/core/neorv32_prim.vhd:200:7 */
  /*# ../../rtl/core/neorv32_prim.vhd:203:19 */
endmodule

module neorv32_cpu_alu_muldiv_Bneorv32_cpu_alu_muldiv_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   input  [31:0] rs1_i,
   input  [31:0] rs2_i,
   output [31:0] res_o,
   output valid_o);
  wire [261:0] n7813;
  wire valid_cmd;
  wire [7:0] ctrl;
  wire rs1_signed;
  wire rs2_signed;
  wire div_start;
  wire [31:0] div_divi;
  wire [31:0] div_quot;
  wire [31:0] div_rema;
  wire div_sign;
  wire [32:0] div_sub;
  wire [31:0] div_res_u;
  wire [31:0] div_res;
  wire mul_start;
  wire [63:0] mul_res;
  wire [32:0] mul_add;
  wire n7817;
  wire n7818;
  wire n7819;
  wire [6:0] n7820;
  wire n7822;
  wire n7823;
  wire n7824;
  wire n7825;
  wire n7826;
  wire n7828;
  wire n7829;
  wire n7830;
  wire n7831;
  wire n7834;
  wire [1:0] n7841;
  wire [1:0] n7845;
  wire [1:0] n7846;
  wire n7848;
  wire [4:0] n7849;
  wire [4:0] n7851;
  wire n7852;
  wire n7861;
  wire n7863;
  wire n7865;
  wire n7866;
  wire n7867;
  wire n7868;
  wire n7869;
  wire n7870;
  wire n7871;
  wire n7872;
  wire n7873;
  wire [1:0] n7875;
  wire [1:0] n7876;
  wire [1:0] n7877;
  wire n7879;
  wire n7880;
  wire [1:0] n7883;
  wire n7885;
  wire n7889;
  wire [3:0] n7890;
  reg [1:0] n7892;
  reg [4:0] n7894;
  reg n7896;
  wire [7:0] n7897;
  wire [7:0] n7899;
  wire [1:0] n7903;
  wire n7905;
  wire n7906;
  wire [2:0] n7909;
  wire n7911;
  wire [2:0] n7912;
  wire n7914;
  wire n7915;
  wire [2:0] n7916;
  wire n7918;
  wire n7919;
  wire [2:0] n7920;
  wire n7922;
  wire n7923;
  wire n7924;
  wire [2:0] n7927;
  wire n7929;
  wire [2:0] n7930;
  wire n7932;
  wire n7933;
  wire [2:0] n7934;
  wire n7936;
  wire n7937;
  wire n7938;
  wire n7941;
  wire n7942;
  wire n7943;
  wire n7944;
  wire n7947;
  wire n7948;
  wire n7949;
  wire n7952;
  wire [1:0] n7955;
  wire n7957;
  wire n7958;
  wire n7959;
  wire n7960;
  wire [30:0] n7961;
  wire [63:0] n7962;
  wire [63:0] n7963;
  wire [63:0] n7964;
  wire [63:0] n7965;
  wire n7973;
  wire n7974;
  wire n7975;
  wire n7976;
  wire [32:0] n7977;
  wire n7978;
  wire [1:0] n7979;
  wire n7981;
  wire n7982;
  wire [31:0] n7983;
  wire [32:0] n7984;
  wire [32:0] n7985;
  wire [31:0] n7986;
  wire [32:0] n7987;
  wire [32:0] n7988;
  wire [32:0] n7989;
  wire [31:0] n7990;
  wire [32:0] n7991;
  wire [32:0] n7992;
  wire n7995;
  wire n8003;
  wire n8004;
  wire [31:0] n8006;
  wire [31:0] n8007;
  wire n8015;
  wire n8016;
  wire [31:0] n8018;
  wire [31:0] n8019;
  wire [1:0] n8021;
  wire n8028;
  wire n8030;
  wire n8032;
  wire n8033;
  wire n8034;
  wire n8035;
  wire n8036;
  wire n8037;
  wire n8038;
  wire n8039;
  wire n8040;
  wire n8041;
  wire n8042;
  wire n8043;
  wire n8044;
  wire n8045;
  wire n8046;
  wire n8047;
  wire n8048;
  wire n8049;
  wire n8050;
  wire n8051;
  wire n8052;
  wire n8053;
  wire n8054;
  wire n8055;
  wire n8056;
  wire n8057;
  wire n8058;
  wire n8059;
  wire n8060;
  wire n8061;
  wire n8062;
  wire n8063;
  wire n8064;
  wire n8065;
  wire n8066;
  wire n8067;
  wire n8068;
  wire n8069;
  wire n8070;
  wire n8071;
  wire n8072;
  wire n8073;
  wire n8074;
  wire n8075;
  wire n8076;
  wire n8077;
  wire n8078;
  wire n8079;
  wire n8080;
  wire n8081;
  wire n8082;
  wire n8083;
  wire n8084;
  wire n8085;
  wire n8086;
  wire n8087;
  wire n8088;
  wire n8089;
  wire n8090;
  wire n8091;
  wire n8092;
  wire n8093;
  wire n8094;
  wire n8095;
  wire n8096;
  wire n8097;
  wire n8099;
  wire n8100;
  wire n8102;
  wire [1:0] n8103;
  reg n8105;
  wire [1:0] n8106;
  wire n8108;
  wire [1:0] n8109;
  wire n8111;
  wire n8112;
  wire [30:0] n8113;
  wire n8114;
  wire n8115;
  wire [31:0] n8116;
  wire n8117;
  wire n8118;
  wire [31:0] n8119;
  wire [30:0] n8120;
  wire n8121;
  wire [31:0] n8122;
  wire [31:0] n8123;
  wire [31:0] n8124;
  wire [31:0] n8125;
  wire [31:0] n8127;
  wire [31:0] n8129;
  wire [30:0] n8144;
  wire [31:0] n8146;
  wire n8147;
  wire [32:0] n8148;
  wire [32:0] n8150;
  wire [32:0] n8151;
  wire [1:0] n8152;
  wire n8154;
  wire [31:0] n8155;
  wire [31:0] n8157;
  wire [31:0] n8158;
  wire n8160;
  wire [2:0] n8161;
  wire [31:0] n8162;
  wire n8164;
  wire [31:0] n8165;
  wire n8167;
  wire n8169;
  wire n8170;
  wire n8172;
  wire n8173;
  wire [1:0] n8174;
  reg [31:0] n8175;
  wire [31:0] n8177;
  reg [7:0] n8180;
  wire [31:0] n8181;
  reg [31:0] n8182;
  reg [31:0] n8183;
  reg [31:0] n8184;
  wire n8185;
  reg n8186;
  reg [63:0] n8187;
  assign res_o = n8177; //(module output)
  assign valid_o = n7906; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:23:8 */
  assign n7813 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:68:10 */
  assign valid_cmd = n7831; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign ctrl = n8180; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:78:10 */
  assign rs1_signed = n7924; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:78:22 */
  assign rs2_signed = n7938; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:81:10 */
  assign div_start = n7949; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:82:10 */
  assign div_divi = n8182; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:83:10 */
  assign div_quot = n8183; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:84:10 */
  assign div_rema = n8184; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:85:10 */
  assign div_sign = n8186; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:86:10 */
  assign div_sub = n8151; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:87:10 */
  assign div_res_u = n8155; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:88:10 */
  assign div_res = n8158; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:91:10 */
  assign mul_start = n7944; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:92:10 */
  assign mul_res = n8187; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:93:10 */
  assign mul_add = n7992; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:33 */
  assign n7817 = n7813[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:22 */
  assign n7818 = n7813[240]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:51 */
  assign n7819 = n7818 & n7817;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:55 */
  assign n7820 = n7813[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:69 */
  assign n7822 = n7820 == 7'b0000001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:33 */
  assign n7823 = n7822 & n7819;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:23 */
  assign n7824 = n7813[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:27 */
  assign n7825 = ~n7824;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:55 */
  assign n7826 = n7813[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:66 */
  assign n7828 = 1'b1 & n7826;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:34 */
  assign n7829 = n7825 | n7828;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:82 */
  assign n7830 = n7829 & n7823;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:20 */
  assign n7831 = n7830 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:108:16 */
  assign n7834 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:17 */
  assign n7841 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign n7845 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:122:11 */
  assign n7846 = valid_cmd ? 2'b01 : n7845;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:120:9 */
  assign n7848 = n7841 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:136:55 */
  assign n7849 = ctrl[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:136:60 */
  assign n7851 = n7849 - 5'b00001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:137:22 */
  assign n7852 = n7813[259]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7861 = ctrl[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7863 = 1'b0 | n7861;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7865 = ctrl[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7866 = n7863 | n7865;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7867 = ctrl[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7868 = n7866 | n7867;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7869 = ctrl[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7870 = n7868 | n7869;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7871 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7872 = n7870 | n7871;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:139:40 */
  assign n7873 = ~n7872;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign n7875 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:139:11 */
  assign n7876 = n7873 ? 2'b11 : n7875;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:137:11 */
  assign n7877 = n7852 ? 2'b00 : n7876;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:134:9 */
  assign n7879 = n7841 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:145:22 */
  assign n7880 = n7813[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:145:11 */
  assign n7883 = n7880 ? 2'b00 : 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:143:9 */
  assign n7885 = n7841 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:151:9 */
  assign n7889 = n7841 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  assign n7890 = {n7889, n7885, n7879, n7848};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7890)
      4'b1000: n7892 = 2'b00;
      4'b0100: n7892 = n7883;
      4'b0010: n7892 = n7877;
      4'b0001: n7892 = n7846;
      default: n7892 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7890)
      4'b1000: n7894 = 5'b11110;
      4'b0100: n7894 = 5'b11110;
      4'b0010: n7894 = n7851;
      4'b0001: n7894 = 5'b11110;
      default: n7894 = 5'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7890)
      4'b1000: n7896 = 1'b1;
      4'b0100: n7896 = 1'b0;
      4'b0010: n7896 = 1'b0;
      4'b0001: n7896 = 1'b0;
      default: n7896 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:112:5 */
  assign n7897 = {n7896, n7894, n7892};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:108:5 */
  assign n7899 = {1'b0, 5'b00000, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:29 */
  assign n7903 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:35 */
  assign n7905 = n7903 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:18 */
  assign n7906 = n7905 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:34 */
  assign n7909 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:44 */
  assign n7911 = n7909 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:68 */
  assign n7912 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:78 */
  assign n7914 = n7912 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:57 */
  assign n7915 = n7911 | n7914;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:34 */
  assign n7916 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:44 */
  assign n7918 = n7916 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:93 */
  assign n7919 = n7915 | n7918;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:68 */
  assign n7920 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:78 */
  assign n7922 = n7920 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:57 */
  assign n7923 = n7919 | n7922;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:21 */
  assign n7924 = n7923 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:34 */
  assign n7927 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:44 */
  assign n7929 = n7927 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:34 */
  assign n7930 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:44 */
  assign n7932 = n7930 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:57 */
  assign n7933 = n7929 | n7932;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:68 */
  assign n7934 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:78 */
  assign n7936 = n7934 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:57 */
  assign n7937 = n7933 | n7936;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:21 */
  assign n7938 = n7937 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:64 */
  assign n7941 = n7813[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:68 */
  assign n7942 = ~n7941;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:43 */
  assign n7943 = n7942 & valid_cmd;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:20 */
  assign n7944 = n7943 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:64 */
  assign n7947 = n7813[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:43 */
  assign n7948 = n7947 & valid_cmd;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:20 */
  assign n7949 = n7948 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:205:18 */
  assign n7952 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:21 */
  assign n7955 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:27 */
  assign n7957 = n7955 != 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:59 */
  assign n7958 = n7813[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:63 */
  assign n7959 = ~n7958;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:38 */
  assign n7960 = n7959 & n7957;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:213:43 */
  assign n7961 = mul_res[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:9 */
  assign n7962 = {mul_add, n7961};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:9 */
  assign n7963 = n7960 ? n7962 : mul_res;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:208:9 */
  assign n7964 = {32'b00000000000000000000000000000000, rs1_i};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:208:9 */
  assign n7965 = mul_start ? n7964 : n7963;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:223:24 */
  assign n7973 = mul_res[63]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:223:39 */
  assign n7974 = n7973 & rs2_signed;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:32 */
  assign n7975 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:45 */
  assign n7976 = n7975 & rs2_signed;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:61 */
  assign n7977 = {n7976, rs2_i};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:225:18 */
  assign n7978 = mul_res[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:18 */
  assign n7979 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:24 */
  assign n7981 = n7979 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:34 */
  assign n7982 = rs1_signed & n7981;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:65 */
  assign n7983 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:56 */
  assign n7984 = {n7974, n7983};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:81 */
  assign n7985 = n7984 - n7977;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:65 */
  assign n7986 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:56 */
  assign n7987 = {n7974, n7986};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:81 */
  assign n7988 = n7987 + n7977;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:9 */
  assign n7989 = n7982 ? n7985 : n7988;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:232:36 */
  assign n7990 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:232:27 */
  assign n7991 = {n7974, n7990};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:225:7 */
  assign n7992 = n7978 ? n7989 : n7991;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:247:18 */
  assign n7995 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:14 */
  assign n8003 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:34 */
  assign n8004 = rs2_signed & n8003;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:50:36 */
  assign n8006 = 32'b00000000000000000000000000000000 - rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:5 */
  assign n8007 = n8004 ? n8006 : rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:14 */
  assign n8015 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:34 */
  assign n8016 = rs1_signed & n8015;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:50:36 */
  assign n8018 = 32'b00000000000000000000000000000000 - rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:5 */
  assign n8019 = n8016 ? n8018 : rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:32 */
  assign n8021 = n7813[221:220]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8028 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8030 = 1'b0 | n8028;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8032 = rs2_i[30]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8033 = n8030 | n8032;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8034 = rs2_i[29]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8035 = n8033 | n8034;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8036 = rs2_i[28]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8037 = n8035 | n8036;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8038 = rs2_i[27]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8039 = n8037 | n8038;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8040 = rs2_i[26]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8041 = n8039 | n8040;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8042 = rs2_i[25]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8043 = n8041 | n8042;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8044 = rs2_i[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8045 = n8043 | n8044;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8046 = rs2_i[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8047 = n8045 | n8046;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8048 = rs2_i[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8049 = n8047 | n8048;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8050 = rs2_i[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8051 = n8049 | n8050;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8052 = rs2_i[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8053 = n8051 | n8052;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8054 = rs2_i[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8055 = n8053 | n8054;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8056 = rs2_i[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8057 = n8055 | n8056;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8058 = rs2_i[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8059 = n8057 | n8058;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8060 = rs2_i[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8061 = n8059 | n8060;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8062 = rs2_i[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8063 = n8061 | n8062;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8064 = rs2_i[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8065 = n8063 | n8064;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8066 = rs2_i[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8067 = n8065 | n8066;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8068 = rs2_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8069 = n8067 | n8068;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8070 = rs2_i[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8071 = n8069 | n8070;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8072 = rs2_i[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8073 = n8071 | n8072;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8074 = rs2_i[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8075 = n8073 | n8074;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8076 = rs2_i[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8077 = n8075 | n8076;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8078 = rs2_i[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8079 = n8077 | n8078;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8080 = rs2_i[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8081 = n8079 | n8080;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8082 = rs2_i[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8083 = n8081 | n8082;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8084 = rs2_i[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8085 = n8083 | n8084;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8086 = rs2_i[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8087 = n8085 | n8086;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8088 = rs2_i[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8089 = n8087 | n8088;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8090 = rs2_i[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8091 = n8089 | n8090;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n8092 = rs2_i[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n8093 = n8091 | n8092;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:69 */
  assign n8094 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:91 */
  assign n8095 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:82 */
  assign n8096 = n8094 ^ n8095;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:59 */
  assign n8097 = n8093 & n8096;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:13 */
  assign n8099 = n8021 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:259:45 */
  assign n8100 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:259:13 */
  assign n8102 = n8021 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:11 */
  assign n8103 = {n8102, n8099};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:11 */
  always @*
    case (n8103)
      2'b10: n8105 = n8100;
      2'b01: n8105 = n8097;
      default: n8105 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:21 */
  assign n8106 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:27 */
  assign n8108 = n8106 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:46 */
  assign n8109 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:52 */
  assign n8111 = n8109 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:37 */
  assign n8112 = n8108 | n8111;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:31 */
  assign n8113 = div_quot[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:59 */
  assign n8114 = div_sub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:48 */
  assign n8115 = ~n8114;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:45 */
  assign n8116 = {n8113, n8115};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:22 */
  assign n8117 = div_sub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:27 */
  assign n8118 = ~n8117;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:265:32 */
  assign n8119 = div_sub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:33 */
  assign n8120 = div_rema[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:57 */
  assign n8121 = div_quot[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:47 */
  assign n8122 = {n8120, n8121};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:11 */
  assign n8123 = n8118 ? n8119 : n8122;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:9 */
  assign n8124 = n8112 ? n8116 : div_quot;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:9 */
  assign n8125 = n8112 ? n8123 : div_rema;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:253:9 */
  assign n8127 = div_start ? n8019 : n8124;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:253:9 */
  assign n8129 = div_start ? 32'b00000000000000000000000000000000 : n8125;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:57 */
  assign n8144 = div_rema[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:47 */
  assign n8146 = {1'b0, n8144};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:81 */
  assign n8147 = div_quot[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:71 */
  assign n8148 = {n8146, n8147};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:102 */
  assign n8150 = {1'b0, div_divi};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:87 */
  assign n8151 = n8148 - n8150;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:49 */
  assign n8152 = n7813[222:221]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:62 */
  assign n8154 = n8152 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:27 */
  assign n8155 = n8154 ? div_quot : div_rema;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:278:38 */
  assign n8157 = 32'b00000000000000000000000000000000 - div_res_u;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:278:61 */
  assign n8158 = div_sign ? n8157 : div_res_u;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:300:14 */
  assign n8160 = ctrl[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:19 */
  assign n8161 = n7813[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:303:27 */
  assign n8162 = mul_res[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:302:9 */
  assign n8164 = n8161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:305:27 */
  assign n8165 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:9 */
  assign n8167 = n8161 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:24 */
  assign n8169 = n8161 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:24 */
  assign n8170 = n8167 | n8169;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:38 */
  assign n8172 = n8161 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:38 */
  assign n8173 = n8170 | n8172;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:7 */
  assign n8174 = {n8173, n8164};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:7 */
  always @*
    case (n8174)
      2'b10: n8175 = n8165;
      2'b01: n8175 = n8162;
      default: n8175 = div_res;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:300:5 */
  assign n8177 = n8160 ? n8175 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:112:5 */
  always @(posedge clk_i or posedge n7834)
    if (n7834)
      n8180 <= n7899;
    else
      n8180 <= n7897;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  assign n8181 = div_start ? n8007 : div_divi;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7995)
    if (n7995)
      n8182 <= 32'b00000000000000000000000000000000;
    else
      n8182 <= n8181;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7995)
    if (n7995)
      n8183 <= 32'b00000000000000000000000000000000;
    else
      n8183 <= n8127;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7995)
    if (n7995)
      n8184 <= 32'b00000000000000000000000000000000;
    else
      n8184 <= n8129;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  assign n8185 = div_start ? n8105 : div_sign;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7995)
    if (n7995)
      n8186 <= 1'b0;
    else
      n8186 <= n8185;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:207:7 */
  always @(posedge clk_i or posedge n7952)
    if (n7952)
      n8187 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    else
      n8187 <= n7965;
endmodule

module neorv32_cpu_alu_shifter_Bneorv32_cpu_alu_shifter_rtl_Lneorv32_5ba93c9db0cff93f52b521d7420e43f6eda2784f
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   input  [31:0] rs1_i,
   input  [4:0] shamt_i,
   output [31:0] res_o,
   output valid_o);
  wire [261:0] n7697;
  wire valid_cmd;
  wire busy;
  wire done;
  wire oe;
  wire [4:0] cnt;
  wire [31:0] sreg;
  wire n7701;
  wire [2:0] n7702;
  wire n7704;
  wire [6:0] n7705;
  wire n7707;
  wire n7708;
  wire [2:0] n7709;
  wire n7711;
  wire [6:0] n7712;
  wire n7714;
  wire n7715;
  wire n7716;
  wire [2:0] n7717;
  wire n7719;
  wire [6:0] n7720;
  wire n7722;
  wire n7723;
  wire n7724;
  wire n7725;
  wire n7726;
  wire n7729;
  wire n7731;
  wire n7732;
  wire n7734;
  wire n7736;
  wire n7737;
  wire n7744;
  wire n7746;
  wire n7748;
  wire n7749;
  wire n7750;
  wire n7751;
  wire n7752;
  wire n7753;
  wire n7754;
  wire n7755;
  wire [4:0] n7757;
  wire n7758;
  wire n7759;
  wire [30:0] n7760;
  wire [31:0] n7762;
  wire n7763;
  wire n7764;
  wire n7765;
  wire [30:0] n7766;
  wire [31:0] n7767;
  wire [31:0] n7768;
  wire [4:0] n7769;
  wire [31:0] n7770;
  wire [4:0] n7771;
  wire [31:0] n7772;
  wire n7793;
  wire n7795;
  wire n7797;
  wire n7798;
  wire n7799;
  wire n7800;
  wire n7801;
  wire n7802;
  wire n7803;
  wire n7804;
  wire [31:0] n7805;
  reg n7809;
  reg n7810;
  reg [4:0] n7811;
  reg [31:0] n7812;
  assign res_o = n7805; //(module output)
  assign valid_o = n7804; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:21:8 */
  assign n7697 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:42:10 */
  assign valid_cmd = n7726; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:10 */
  assign busy = n7809; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:21 */
  assign done = n7803; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:27 */
  assign oe = n7810; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:46:10 */
  assign cnt = n7811; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:47:10 */
  assign sreg = n7812; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:33 */
  assign n7701 = n7697[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:14 */
  assign n7702 = n7697[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:24 */
  assign n7704 = n7702 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:62 */
  assign n7705 = n7697[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:76 */
  assign n7707 = n7705 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:40 */
  assign n7708 = n7707 & n7704;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:14 */
  assign n7709 = n7697[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:24 */
  assign n7711 = n7709 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:62 */
  assign n7712 = n7697[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:76 */
  assign n7714 = n7712 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:40 */
  assign n7715 = n7714 & n7711;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:90 */
  assign n7716 = n7708 | n7715;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:14 */
  assign n7717 = n7697[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:24 */
  assign n7719 = n7717 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:62 */
  assign n7720 = n7697[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:76 */
  assign n7722 = n7720 == 7'b0100000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:40 */
  assign n7723 = n7722 & n7719;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:90 */
  assign n7724 = n7716 | n7723;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:51 */
  assign n7725 = n7724 & n7701;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:20 */
  assign n7726 = n7725 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:69:18 */
  assign n7729 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:39 */
  assign n7731 = n7697[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:28 */
  assign n7732 = done | n7731;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:9 */
  assign n7734 = n7732 ? 1'b0 : busy;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:76:9 */
  assign n7736 = valid_cmd ? 1'b1 : n7734;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:81:20 */
  assign n7737 = busy & done;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7744 = cnt[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7746 = 1'b0 | n7744;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7748 = cnt[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7749 = n7746 | n7748;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7750 = cnt[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7751 = n7749 | n7750;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7752 = cnt[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7753 = n7751 | n7752;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7754 = cnt[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7755 = n7753 | n7754;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:87:50 */
  assign n7757 = cnt - 5'b00001;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:31 */
  assign n7758 = n7697[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:35 */
  assign n7759 = ~n7758;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:89:25 */
  assign n7760 = sreg[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:89:48 */
  assign n7762 = {n7760, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:26 */
  assign n7763 = sreg[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:59 */
  assign n7764 = n7697[233]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:38 */
  assign n7765 = n7763 & n7764;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:71 */
  assign n7766 = sreg[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:65 */
  assign n7767 = {n7765, n7766};
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:11 */
  assign n7768 = n7759 ? n7762 : n7767;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:86:9 */
  assign n7769 = n7755 ? n7757 : cnt;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:86:9 */
  assign n7770 = n7755 ? n7768 : sreg;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:83:9 */
  assign n7771 = valid_cmd ? shamt_i : n7769;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:83:9 */
  assign n7772 = valid_cmd ? rs1_i : n7770;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7793 = cnt[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7795 = 1'b0 | n7793;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7797 = cnt[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7798 = n7795 | n7797;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7799 = cnt[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7800 = n7798 | n7799;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7801 = cnt[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7802 = n7800 | n7801;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:98:16 */
  assign n7803 = ~n7802;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:99:21 */
  assign n7804 = busy & done;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:100:21 */
  assign n7805 = oe ? sreg : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7729)
    if (n7729)
      n7809 <= 1'b0;
    else
      n7809 <= n7736;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7729)
    if (n7729)
      n7810 <= 1'b0;
    else
      n7810 <= n7737;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7729)
    if (n7729)
      n7811 <= 5'b00000;
    else
      n7811 <= n7771;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7729)
    if (n7729)
      n7812 <= 32'b00000000000000000000000000000000;
    else
      n7812 <= n7772;
endmodule

module neorv32_cpu_decompressor_Bneorv32_cpu_decompressor_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29
  (input  [15:0] instr_i,
   output [31:0] instr_o);
  wire illegal;
  wire [31:0] decoded;
  wire [1:0] n7164;
  wire [2:0] n7165;
  wire [2:0] n7168;
  wire [4:0] n7170;
  wire [3:0] n7172;
  wire [5:0] n7174;
  wire [1:0] n7175;
  wire [7:0] n7176;
  wire n7177;
  wire [8:0] n7178;
  wire n7179;
  wire [9:0] n7180;
  wire [11:0] n7182;
  wire [7:0] n7183;
  wire n7185;
  wire n7188;
  wire n7190;
  wire n7192;
  wire [5:0] n7194;
  wire [2:0] n7195;
  wire [8:0] n7196;
  wire n7197;
  wire [9:0] n7198;
  wire [11:0] n7200;
  wire [2:0] n7202;
  wire [4:0] n7204;
  wire [2:0] n7205;
  wire [4:0] n7207;
  wire n7209;
  wire n7211;
  wire [5:0] n7213;
  wire n7214;
  wire [6:0] n7215;
  wire [1:0] n7216;
  wire n7217;
  wire [2:0] n7218;
  wire [4:0] n7220;
  wire [2:0] n7222;
  wire [4:0] n7224;
  wire [2:0] n7225;
  wire [4:0] n7227;
  wire n7229;
  wire n7231;
  wire [3:0] n7232;
  reg n7236;
  reg [6:0] n7238;
  reg [4:0] n7240;
  reg [2:0] n7242;
  reg [4:0] n7244;
  wire [4:0] n7245;
  wire [4:0] n7246;
  reg [4:0] n7248;
  wire [6:0] n7249;
  wire [6:0] n7250;
  reg [6:0] n7252;
  wire n7254;
  wire [2:0] n7255;
  wire n7256;
  wire n7257;
  wire [4:0] n7259;
  wire n7261;
  wire n7262;
  wire [1:0] n7263;
  wire [1:0] n7264;
  wire [3:0] n7265;
  wire n7266;
  wire [4:0] n7267;
  wire n7268;
  wire [5:0] n7269;
  wire n7270;
  wire [6:0] n7271;
  wire n7272;
  wire [7:0] n7273;
  wire [2:0] n7274;
  wire [10:0] n7275;
  wire n7276;
  wire [11:0] n7277;
  wire n7279;
  wire [7:0] n7285;
  wire [19:0] n7287;
  wire n7289;
  wire n7291;
  wire n7292;
  wire n7293;
  wire [2:0] n7295;
  wire [2:0] n7297;
  wire [4:0] n7299;
  wire n7302;
  wire [3:0] n7308;
  wire [1:0] n7310;
  wire [5:0] n7311;
  wire n7312;
  wire [6:0] n7313;
  wire [1:0] n7314;
  wire [1:0] n7315;
  wire [3:0] n7316;
  wire n7317;
  wire [4:0] n7318;
  wire n7320;
  wire n7322;
  wire n7323;
  wire [4:0] n7325;
  wire n7327;
  wire [6:0] n7333;
  wire [4:0] n7335;
  wire [11:0] n7336;
  wire n7338;
  wire [4:0] n7339;
  wire n7341;
  wire n7345;
  wire [2:0] n7351;
  wire [1:0] n7353;
  wire [4:0] n7354;
  wire n7355;
  wire [5:0] n7356;
  wire n7357;
  wire [6:0] n7358;
  wire n7359;
  wire [7:0] n7360;
  wire [11:0] n7362;
  wire [4:0] n7364;
  wire n7366;
  wire [14:0] n7372;
  wire [4:0] n7374;
  wire [19:0] n7375;
  wire [31:0] n7376;
  wire [31:0] n7377;
  wire [31:0] n7378;
  wire [4:0] n7379;
  wire n7381;
  wire n7382;
  wire n7383;
  wire n7384;
  wire n7386;
  wire n7389;
  wire n7391;
  wire [4:0] n7392;
  wire [4:0] n7393;
  wire n7395;
  wire [6:0] n7401;
  wire [4:0] n7403;
  wire [11:0] n7404;
  wire n7406;
  wire [2:0] n7407;
  wire [4:0] n7409;
  wire [2:0] n7410;
  wire [4:0] n7412;
  wire [2:0] n7413;
  wire [4:0] n7415;
  wire [1:0] n7416;
  wire n7417;
  wire [1:0] n7419;
  wire [6:0] n7421;
  wire [4:0] n7423;
  wire n7425;
  wire n7427;
  wire n7428;
  wire n7431;
  wire [6:0] n7437;
  wire [4:0] n7439;
  wire [11:0] n7440;
  wire n7442;
  wire [1:0] n7444;
  wire n7446;
  wire n7448;
  wire n7451;
  wire n7453;
  wire n7454;
  wire n7455;
  wire n7460;
  wire [2:0] n7462;
  wire [6:0] n7464;
  wire n7466;
  wire n7467;
  wire n7468;
  wire n7472;
  wire [2:0] n7474;
  wire [6:0] n7476;
  wire [2:0] n7477;
  reg n7478;
  reg [2:0] n7479;
  reg [6:0] n7480;
  wire [1:0] n7481;
  reg n7483;
  reg [6:0] n7484;
  reg [2:0] n7485;
  wire [4:0] n7486;
  reg [4:0] n7487;
  wire [6:0] n7488;
  reg [6:0] n7489;
  wire [4:0] n7490;
  reg n7492;
  wire [6:0] n7493;
  reg [6:0] n7494;
  wire [4:0] n7495;
  reg [4:0] n7496;
  wire [2:0] n7497;
  wire [2:0] n7498;
  reg [2:0] n7499;
  wire [4:0] n7500;
  wire [4:0] n7501;
  reg [4:0] n7502;
  wire [4:0] n7503;
  wire [4:0] n7504;
  wire [4:0] n7505;
  wire [4:0] n7506;
  reg [4:0] n7507;
  wire [6:0] n7508;
  wire [6:0] n7509;
  wire [6:0] n7510;
  wire [6:0] n7511;
  reg [6:0] n7512;
  wire n7514;
  wire [2:0] n7515;
  wire [4:0] n7516;
  wire [4:0] n7517;
  wire [4:0] n7520;
  wire n7521;
  wire n7524;
  wire n7526;
  wire [1:0] n7527;
  wire [5:0] n7529;
  wire n7530;
  wire [6:0] n7531;
  wire [2:0] n7532;
  wire [9:0] n7533;
  wire [11:0] n7535;
  wire [4:0] n7537;
  wire n7538;
  wire [4:0] n7539;
  wire n7541;
  wire n7542;
  wire n7545;
  wire n7547;
  wire n7549;
  wire n7550;
  wire [1:0] n7551;
  wire [5:0] n7553;
  wire n7554;
  wire [6:0] n7555;
  wire [2:0] n7556;
  wire [4:0] n7558;
  wire [4:0] n7560;
  wire n7561;
  wire n7564;
  wire n7566;
  wire n7568;
  wire n7569;
  wire n7570;
  wire n7571;
  wire [4:0] n7572;
  wire n7574;
  wire [4:0] n7576;
  wire [4:0] n7578;
  wire n7580;
  wire n7583;
  wire [4:0] n7585;
  wire [4:0] n7587;
  wire n7589;
  wire [24:0] n7590;
  wire [11:0] n7591;
  wire [11:0] n7592;
  wire [11:0] n7593;
  wire [2:0] n7594;
  wire [2:0] n7596;
  wire [4:0] n7597;
  wire [4:0] n7598;
  wire [4:0] n7599;
  wire [4:0] n7601;
  wire [4:0] n7602;
  wire n7604;
  wire [4:0] n7605;
  wire n7607;
  wire [4:0] n7610;
  wire [11:0] n7612;
  wire [6:0] n7613;
  wire [6:0] n7614;
  wire [4:0] n7615;
  wire [4:0] n7617;
  wire [4:0] n7619;
  wire [11:0] n7621;
  wire [4:0] n7623;
  wire [4:0] n7624;
  wire [4:0] n7625;
  wire [24:0] n7626;
  wire [11:0] n7627;
  wire [16:0] n7628;
  wire [11:0] n7629;
  wire [11:0] n7630;
  wire [2:0] n7631;
  wire [2:0] n7633;
  wire [9:0] n7634;
  wire [9:0] n7635;
  wire [9:0] n7636;
  wire [6:0] n7637;
  wire [6:0] n7639;
  wire n7641;
  wire [31:0] n7642;
  wire [24:0] n7643;
  wire [24:0] n7644;
  wire [24:0] n7645;
  wire [6:0] n7646;
  wire [6:0] n7648;
  wire n7650;
  wire [3:0] n7651;
  reg n7653;
  wire [6:0] n7654;
  reg [6:0] n7656;
  wire [4:0] n7657;
  reg [4:0] n7659;
  wire [2:0] n7660;
  reg [2:0] n7662;
  wire [4:0] n7663;
  reg [4:0] n7665;
  wire [4:0] n7666;
  wire [4:0] n7667;
  reg [4:0] n7669;
  wire [6:0] n7670;
  reg [6:0] n7672;
  wire [1:0] n7673;
  reg n7674;
  reg [6:0] n7676;
  reg [4:0] n7677;
  reg [2:0] n7678;
  reg [4:0] n7679;
  reg [4:0] n7680;
  reg [6:0] n7681;
  wire [29:0] n7689;
  wire n7690;
  wire n7691;
  wire n7692;
  wire [30:0] n7693;
  wire n7694;
  wire [31:0] n7695;
  wire [31:0] n7696;
  assign instr_o = n7695; //(module output)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:54:10 */
  assign illegal = n7674; // (signal)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:55:10 */
  assign decoded = n7696; // (signal)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:17 */
  assign n7164 = instr_i[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:21 */
  assign n7165 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:77:84 */
  assign n7168 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:77:75 */
  assign n7170 = {2'b01, n7168};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:84 */
  assign n7172 = instr_i[10:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:75 */
  assign n7174 = {2'b00, n7172};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:107 */
  assign n7175 = instr_i[12:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:98 */
  assign n7176 = {n7174, n7175};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:131 */
  assign n7177 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:122 */
  assign n7178 = {n7176, n7177};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:144 */
  assign n7179 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:135 */
  assign n7180 = {n7178, n7179};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7182 = {n7180, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:24 */
  assign n7183 = instr_i[12:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:38 */
  assign n7185 = n7183 == 8'b00000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:13 */
  assign n7188 = n7185 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:73:11 */
  assign n7190 = n7165 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:87 */
  assign n7192 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:78 */
  assign n7194 = {5'b00000, n7192};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:100 */
  assign n7195 = instr_i[12:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:91 */
  assign n7196 = {n7194, n7195};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:124 */
  assign n7197 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:115 */
  assign n7198 = {n7196, n7197};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7200 = {n7198, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:89:84 */
  assign n7202 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:89:75 */
  assign n7204 = {2'b01, n7202};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:90:84 */
  assign n7205 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:90:75 */
  assign n7207 = {2'b01, n7205};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:84:11 */
  assign n7209 = n7165 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:87 */
  assign n7211 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:78 */
  assign n7213 = {5'b00000, n7211};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:100 */
  assign n7214 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:91 */
  assign n7215 = {n7213, n7214};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:77 */
  assign n7216 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:101 */
  assign n7217 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:92 */
  assign n7218 = {n7216, n7217};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:105 */
  assign n7220 = {n7218, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:98:84 */
  assign n7222 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:98:75 */
  assign n7224 = {2'b01, n7222};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:99:84 */
  assign n7225 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:99:75 */
  assign n7227 = {2'b01, n7225};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:92:11 */
  assign n7229 = n7165 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:101:11 */
  assign n7231 = n7165 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  assign n7232 = {n7231, n7229, n7209, n7190};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7236 = 1'b1;
      4'b0100: n7236 = 1'b0;
      4'b0010: n7236 = 1'b0;
      4'b0001: n7236 = n7188;
      default: n7236 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7238 = 7'b0000011;
      4'b0100: n7238 = 7'b0100011;
      4'b0010: n7238 = 7'b0000011;
      4'b0001: n7238 = 7'b0010011;
      default: n7238 = 7'b0000011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7240 = 5'b00000;
      4'b0100: n7240 = n7220;
      4'b0010: n7240 = n7207;
      4'b0001: n7240 = n7170;
      default: n7240 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7242 = 3'b000;
      4'b0100: n7242 = 3'b010;
      4'b0010: n7242 = 3'b010;
      4'b0001: n7242 = 3'b000;
      default: n7242 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7244 = 5'b00000;
      4'b0100: n7244 = n7224;
      4'b0010: n7244 = n7204;
      4'b0001: n7244 = 5'b00010;
      default: n7244 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7245 = n7182[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7246 = n7200[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7248 = 5'b00000;
      4'b0100: n7248 = n7227;
      4'b0010: n7248 = n7246;
      4'b0001: n7248 = n7245;
      default: n7248 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7249 = n7182[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7250 = n7200[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7232)
      4'b1000: n7252 = 7'b0000000;
      4'b0100: n7252 = n7215;
      4'b0010: n7252 = n7250;
      4'b0001: n7252 = n7249;
      default: n7252 = 7'b0000000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:70:7 */
  assign n7254 = n7164 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:21 */
  assign n7255 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:91 */
  assign n7256 = instr_i[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:80 */
  assign n7257 = ~n7256;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:77 */
  assign n7259 = {4'b0000, n7257};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:77 */
  assign n7261 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:91 */
  assign n7262 = instr_i[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:82 */
  assign n7263 = {n7261, n7262};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:104 */
  assign n7264 = instr_i[10:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:95 */
  assign n7265 = {n7263, n7264};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:127 */
  assign n7266 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:118 */
  assign n7267 = {n7265, n7266};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:140 */
  assign n7268 = instr_i[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:131 */
  assign n7269 = {n7267, n7268};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:77 */
  assign n7270 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:144 */
  assign n7271 = {n7269, n7270};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:90 */
  assign n7272 = instr_i[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:81 */
  assign n7273 = {n7271, n7272};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:104 */
  assign n7274 = instr_i[5:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:95 */
  assign n7275 = {n7273, n7274};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:126 */
  assign n7276 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:117 */
  assign n7277 = {n7275, n7276};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:152 */
  assign n7279 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7285 = {n7279, n7279, n7279, n7279, n7279, n7279, n7279, n7279};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7287 = {n7277, n7285};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:11 */
  assign n7289 = n7255 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:22 */
  assign n7291 = n7255 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:22 */
  assign n7292 = n7289 | n7291;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:153:84 */
  assign n7293 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:153:75 */
  assign n7295 = {2'b00, n7293};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:155:84 */
  assign n7297 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:155:75 */
  assign n7299 = {2'b01, n7297};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:89 */
  assign n7302 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7308 = {n7302, n7302, n7302, n7302};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:107 */
  assign n7310 = instr_i[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:98 */
  assign n7311 = {n7308, n7310};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:129 */
  assign n7312 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:120 */
  assign n7313 = {n7311, n7312};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:77 */
  assign n7314 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:101 */
  assign n7315 = instr_i[4:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:92 */
  assign n7316 = {n7314, n7315};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:123 */
  assign n7317 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:114 */
  assign n7318 = {n7316, n7317};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:11 */
  assign n7320 = n7255 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:22 */
  assign n7322 = n7255 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:22 */
  assign n7323 = n7320 | n7322;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:165:77 */
  assign n7325 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:89 */
  assign n7327 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7333 = {n7327, n7327, n7327, n7327, n7327, n7327, n7327};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:106 */
  assign n7335 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7336 = {n7333, n7335};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:160:11 */
  assign n7338 = n7255 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:24 */
  assign n7339 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:61 */
  assign n7341 = n7339 == 5'b00010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:91 */
  assign n7345 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7351 = {n7345, n7345, n7345};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:108 */
  assign n7353 = instr_i[4:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:99 */
  assign n7354 = {n7351, n7353};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:130 */
  assign n7355 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:121 */
  assign n7356 = {n7354, n7355};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:143 */
  assign n7357 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:134 */
  assign n7358 = {n7356, n7357};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:156 */
  assign n7359 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:147 */
  assign n7360 = {n7358, n7359};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:160 */
  assign n7362 = {n7360, 4'b0000};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:184:79 */
  assign n7364 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:91 */
  assign n7366 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7372 = {n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366, n7366};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:109 */
  assign n7374 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:100 */
  assign n7375 = {n7372, n7374};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7376 = {n7375, n7364, 7'b0110111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7377 = {n7362, 5'b00010, 3'b000, 5'b00010, 7'b0010011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7378 = n7341 ? n7377 : n7376;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:24 */
  assign n7379 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:37 */
  assign n7381 = n7379 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:60 */
  assign n7382 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:65 */
  assign n7383 = ~n7382;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:48 */
  assign n7384 = n7383 & n7381;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:72 */
  assign n7386 = 1'b1 & n7384;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:13 */
  assign n7389 = n7386 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:168:11 */
  assign n7391 = n7255 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:195:77 */
  assign n7392 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:196:77 */
  assign n7393 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:89 */
  assign n7395 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7401 = {n7395, n7395, n7395, n7395, n7395, n7395, n7395};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:106 */
  assign n7403 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7404 = {n7401, n7403};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:191:11 */
  assign n7406 = n7255 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:201:78 */
  assign n7407 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:201:69 */
  assign n7409 = {2'b01, n7407};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:202:78 */
  assign n7410 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:202:69 */
  assign n7412 = {2'b01, n7410};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:203:78 */
  assign n7413 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:203:69 */
  assign n7415 = {2'b01, n7413};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:25 */
  assign n7416 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:87 */
  assign n7417 = instr_i[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:78 */
  assign n7419 = {1'b0, n7417};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:92 */
  assign n7421 = {n7419, 5'b00000};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:209:81 */
  assign n7423 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:15 */
  assign n7425 = n7416 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:25 */
  assign n7427 = n7416 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:25 */
  assign n7428 = n7425 | n7427;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:93 */
  assign n7431 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7437 = {n7431, n7431, n7431, n7431, n7431, n7431, n7431};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:110 */
  assign n7439 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7440 = {n7437, n7439};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:210:15 */
  assign n7442 = n7416 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:29 */
  assign n7444 = instr_i[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:220:39 */
  assign n7446 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:217:19 */
  assign n7448 = n7444 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:224:39 */
  assign n7451 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:221:19 */
  assign n7453 = n7444 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:32 */
  assign n7454 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:37 */
  assign n7455 = ~n7454;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7460 = n7455 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7462 = n7455 ? 3'b110 : 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7464 = n7455 ? 7'b0000000 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:225:19 */
  assign n7466 = n7444 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:32 */
  assign n7467 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:37 */
  assign n7468 = ~n7467;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7472 = n7468 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7474 = n7468 ? 3'b111 : 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7476 = n7468 ? 7'b0000000 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  assign n7477 = {n7466, n7453, n7448};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7477)
      3'b100: n7478 = n7460;
      3'b010: n7478 = n7451;
      3'b001: n7478 = n7446;
      default: n7478 = n7472;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7477)
      3'b100: n7479 = n7462;
      3'b010: n7479 = 3'b100;
      3'b001: n7479 = 3'b000;
      default: n7479 = n7474;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7477)
      3'b100: n7480 = n7464;
      3'b010: n7480 = 7'b0000000;
      3'b001: n7480 = 7'b0100000;
      default: n7480 = n7476;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  assign n7481 = {n7442, n7428};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7481)
      2'b10: n7483 = 1'b0;
      2'b01: n7483 = 1'b0;
      default: n7483 = n7478;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7481)
      2'b10: n7484 = 7'b0010011;
      2'b01: n7484 = 7'b0010011;
      default: n7484 = 7'b0110011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7481)
      2'b10: n7485 = 3'b111;
      2'b01: n7485 = 3'b101;
      default: n7485 = n7479;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7486 = n7440[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7481)
      2'b10: n7487 = n7486;
      2'b01: n7487 = n7423;
      default: n7487 = n7415;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7488 = n7440[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7481)
      2'b10: n7489 = n7488;
      2'b01: n7489 = n7421;
      default: n7489 = n7480;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  assign n7490 = {n7406, n7391, n7338, n7323, n7292};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7492 = 1'b0;
      5'b01000: n7492 = n7389;
      5'b00100: n7492 = 1'b0;
      5'b00010: n7492 = 1'b0;
      5'b00001: n7492 = 1'b0;
      default: n7492 = n7483;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7493 = n7378[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7494 = 7'b0010011;
      5'b01000: n7494 = n7493;
      5'b00100: n7494 = 7'b0010011;
      5'b00010: n7494 = 7'b1100011;
      5'b00001: n7494 = 7'b1101111;
      default: n7494 = n7484;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7495 = n7378[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7496 = n7393;
      5'b01000: n7496 = n7495;
      5'b00100: n7496 = n7325;
      5'b00010: n7496 = n7318;
      5'b00001: n7496 = n7259;
      default: n7496 = n7409;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7497 = n7287[2:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7498 = n7378[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7499 = 3'b000;
      5'b01000: n7499 = n7498;
      5'b00100: n7499 = 3'b000;
      5'b00010: n7499 = n7295;
      5'b00001: n7499 = n7497;
      default: n7499 = n7485;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7500 = n7287[7:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7501 = n7378[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7502 = n7392;
      5'b01000: n7502 = n7501;
      5'b00100: n7502 = 5'b00000;
      5'b00010: n7502 = n7299;
      5'b00001: n7502 = n7500;
      default: n7502 = n7412;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7503 = n7287[12:8]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7504 = n7336[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7505 = n7378[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7506 = n7404[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7507 = n7506;
      5'b01000: n7507 = n7505;
      5'b00100: n7507 = n7504;
      5'b00010: n7507 = 5'b00000;
      5'b00001: n7507 = n7503;
      default: n7507 = n7487;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7508 = n7287[19:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7509 = n7336[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7510 = n7378[31:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7511 = n7404[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7490)
      5'b10000: n7512 = n7511;
      5'b01000: n7512 = n7510;
      5'b00100: n7512 = n7509;
      5'b00010: n7512 = n7313;
      5'b00001: n7512 = n7508;
      default: n7512 = n7489;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:140:7 */
  assign n7514 = n7164 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:21 */
  assign n7515 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:278:77 */
  assign n7516 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:279:77 */
  assign n7517 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:282:77 */
  assign n7520 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:283:24 */
  assign n7521 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:283:13 */
  assign n7524 = n7521 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:275:11 */
  assign n7526 = n7515 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:86 */
  assign n7527 = instr_i[3:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:77 */
  assign n7529 = {4'b0000, n7527};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:108 */
  assign n7530 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:99 */
  assign n7531 = {n7529, n7530};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:122 */
  assign n7532 = instr_i[6:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:113 */
  assign n7533 = {n7531, n7532};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7535 = {n7533, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:293:77 */
  assign n7537 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:24 */
  assign n7538 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:295:24 */
  assign n7539 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:295:61 */
  assign n7541 = n7539 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:49 */
  assign n7542 = n7538 | n7541;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:13 */
  assign n7545 = n7542 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:11 */
  assign n7547 = n7515 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:22 */
  assign n7549 = n7515 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:22 */
  assign n7550 = n7547 | n7549;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:86 */
  assign n7551 = instr_i[8:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:77 */
  assign n7553 = {4'b0000, n7551};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:108 */
  assign n7554 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:99 */
  assign n7555 = {n7553, n7554};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:303:77 */
  assign n7556 = instr_i[11:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:303:91 */
  assign n7558 = {n7556, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:306:77 */
  assign n7560 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:307:24 */
  assign n7561 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:307:13 */
  assign n7564 = n7561 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:11 */
  assign n7566 = n7515 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:22 */
  assign n7568 = n7515 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:22 */
  assign n7569 = n7566 | n7568;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:24 */
  assign n7570 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:29 */
  assign n7571 = ~n7570;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:26 */
  assign n7572 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:65 */
  assign n7574 = n7572 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:316:81 */
  assign n7576 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:28 */
  assign n7578 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:67 */
  assign n7580 = n7578 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:17 */
  assign n7583 = n7580 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:324:81 */
  assign n7585 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:326:81 */
  assign n7587 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7589 = n7574 ? n7583 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7590 = {n7587, 5'b00000, 3'b000, n7585, 7'b0110011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7591 = {5'b00000, 7'b1100111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7592 = n7590[11:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7593 = n7574 ? n7591 : n7592;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7594 = n7590[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7596 = n7574 ? 3'b000 : n7594;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7597 = n7590[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7598 = n7574 ? n7576 : n7597;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7599 = n7590[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7601 = n7574 ? 5'b00000 : n7599;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:26 */
  assign n7602 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:65 */
  assign n7604 = n7602 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:28 */
  assign n7605 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:42 */
  assign n7607 = n7605 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:335:83 */
  assign n7610 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7612 = {5'b00001, 7'b1100111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7613 = n7612[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7614 = n7607 ? 7'b1110011 : n7613;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7615 = n7612[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7617 = n7607 ? 5'b00000 : n7615;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7619 = n7607 ? 5'b00000 : n7610;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7621 = n7607 ? 12'b000000000001 : 12'b000000000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:341:81 */
  assign n7623 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:342:81 */
  assign n7624 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:343:81 */
  assign n7625 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7626 = {n7625, n7624, 3'b000, n7623, 7'b0110011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7627 = {n7617, n7614};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7628 = {n7621, n7619};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7629 = n7626[11:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7630 = n7604 ? n7627 : n7629;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7631 = n7626[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7633 = n7604 ? 3'b000 : n7631;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7634 = n7626[24:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7635 = n7628[9:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7636 = n7604 ? n7635 : n7634;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7637 = n7628[16:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7639 = n7604 ? n7637 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7641 = n7571 ? n7589 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7642 = {n7639, n7636, n7633, n7630};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7643 = {n7601, n7598, n7596, n7593};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7644 = n7642[24:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7645 = n7571 ? n7643 : n7644;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7646 = n7642[31:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7648 = n7571 ? 7'b0000000 : n7646;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:311:11 */
  assign n7650 = n7515 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  assign n7651 = {n7650, n7569, n7550, n7526};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7653 = n7641;
      4'b0100: n7653 = n7564;
      4'b0010: n7653 = n7545;
      4'b0001: n7653 = n7524;
      default: n7653 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7654 = n7645[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7656 = n7654;
      4'b0100: n7656 = 7'b0100011;
      4'b0010: n7656 = 7'b0000011;
      4'b0001: n7656 = 7'b0010011;
      default: n7656 = 7'b0000011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7657 = n7645[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7659 = n7657;
      4'b0100: n7659 = n7558;
      4'b0010: n7659 = n7537;
      4'b0001: n7659 = n7517;
      default: n7659 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7660 = n7645[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7662 = n7660;
      4'b0100: n7662 = 3'b010;
      4'b0010: n7662 = 3'b010;
      4'b0001: n7662 = 3'b001;
      default: n7662 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7663 = n7645[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7665 = n7663;
      4'b0100: n7665 = 5'b00010;
      4'b0010: n7665 = 5'b00010;
      4'b0001: n7665 = n7516;
      default: n7665 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7666 = n7535[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7667 = n7645[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7669 = n7667;
      4'b0100: n7669 = n7560;
      4'b0010: n7669 = n7666;
      4'b0001: n7669 = n7520;
      default: n7669 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7670 = n7535[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7651)
      4'b1000: n7672 = n7648;
      4'b0100: n7672 = n7555;
      4'b0010: n7672 = n7670;
      4'b0001: n7672 = 7'b0000000;
      default: n7672 = 7'b0000000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  assign n7673 = {n7514, n7254};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7674 = n7492;
      2'b01: n7674 = n7236;
      default: n7674 = n7653;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7676 = n7494;
      2'b01: n7676 = n7238;
      default: n7676 = n7656;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7677 = n7496;
      2'b01: n7677 = n7240;
      default: n7677 = n7659;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7678 = n7499;
      2'b01: n7678 = n7242;
      default: n7678 = n7662;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7679 = n7502;
      2'b01: n7679 = n7244;
      default: n7679 = n7665;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7680 = n7507;
      2'b01: n7680 = n7248;
      default: n7680 = n7669;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7673)
      2'b10: n7681 = n7512;
      2'b01: n7681 = n7252;
      default: n7681 = n7672;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:21 */
  assign n7689 = decoded[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:45 */
  assign n7690 = decoded[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:54 */
  assign n7691 = ~illegal;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:49 */
  assign n7692 = n7690 & n7691;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:35 */
  assign n7693 = {n7689, n7692};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:77 */
  assign n7694 = decoded[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:68 */
  assign n7695 = {n7693, n7694};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:55:10 */
  assign n7696 = {n7681, n7680, n7679, n7678, n7677, n7676};
endmodule

module neorv32_cpu_frontend_ipb_Bneorv32_cpu_frontend_ipb_rtl_Lneorv32_1_17
  (input  clk_i,
   input  rstn_i,
   input  clear_i,
   input  [16:0] wdata_i,
   input  we_i,
   output free_o,
   input  re_i,
   output [16:0] rdata_o,
   output avail_o);
  wire [1:0] w_pnt;
  wire [1:0] r_pnt;
  wire match;
  wire n7100;
  wire [1:0] n7103;
  wire [1:0] n7104;
  wire [1:0] n7106;
  wire [1:0] n7108;
  wire [1:0] n7109;
  wire [1:0] n7111;
  wire n7120;
  wire n7121;
  wire n7122;
  wire n7123;
  wire n7126;
  wire n7127;
  wire n7128;
  wire n7129;
  wire n7130;
  wire n7133;
  wire n7134;
  wire n7135;
  wire n7136;
  wire n7137;
  wire n7141;
  wire n7150;
  reg [1:0] n7156;
  reg [1:0] n7157;
  wire [16:0] n7160; // mem_rd
  assign free_o = n7130; //(module output)
  assign rdata_o = n7160; //(module output)
  assign avail_o = n7137; //(module output)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:346:10 */
  assign w_pnt = n7156; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:346:17 */
  assign r_pnt = n7157; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:347:10 */
  assign match = n7123; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:359:16 */
  assign n7100 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:366:52 */
  assign n7103 = w_pnt + 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:365:7 */
  assign n7104 = we_i ? n7103 : w_pnt;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:363:7 */
  assign n7106 = clear_i ? 2'b00 : n7104;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:371:52 */
  assign n7108 = r_pnt + 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:370:7 */
  assign n7109 = re_i ? n7108 : r_pnt;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:368:7 */
  assign n7111 = clear_i ? 2'b00 : n7109;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:29 */
  assign n7120 = r_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:56 */
  assign n7121 = w_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:49 */
  assign n7122 = n7120 == n7121;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:18 */
  assign n7123 = n7122 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:29 */
  assign n7126 = r_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:46 */
  assign n7127 = w_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:38 */
  assign n7128 = n7126 != n7127;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:56 */
  assign n7129 = match & n7128;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:18 */
  assign n7130 = n7129 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:29 */
  assign n7133 = r_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:46 */
  assign n7134 = w_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:39 */
  assign n7135 = n7133 == n7134;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:56 */
  assign n7136 = match & n7135;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:18 */
  assign n7137 = n7136 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:387:38 */
  assign n7141 = w_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:393:43 */
  assign n7150 = r_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:362:5 */
  always @(posedge clk_i or posedge n7100)
    if (n7100)
      n7156 <= 2'b00;
    else
      n7156 <= n7106;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:362:5 */
  always @(posedge clk_i or posedge n7100)
    if (n7100)
      n7157 <= 2'b00;
    else
      n7157 <= n7111;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:393:18 */
  reg [16:0] ipb[1:0] ; // memory
  assign n7160 = ipb[n7150];
  always @(posedge clk_i)
    if (we_i)
      ipb[n7141] <= wdata_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:393:18 */
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:387:13 */
endmodule

module neorv32_prim_fifo_Bneorv32_prim_fifo_rtl_Lneorv32_0_8_5ba93c9db0cff93f52b521d7420e43f6eda2784f
  (input  clk_i,
   input  rstn_i,
   input  clear_i,
   input  [7:0] wdata_i,
   input  we_i,
   output free_o,
   input  re_i,
   output [7:0] rdata_o,
   output avail_o);
  wire [7:0] fifo;
  wire [7:0] rdata;
  wire we;
  wire re;
  wire match;
  wire full;
  wire empty;
  wire avail;
  wire w_pnt;
  wire w_nxt;
  wire r_pnt;
  wire r_nxt;
  wire n7049;
  wire n7058;
  wire n7059;
  wire n7060;
  wire n7061;
  wire n7063;
  wire n7065;
  wire n7066;
  wire n7068;
  wire n7070;
  wire n7071;
  wire n7073;
  wire n7074;
  wire n7076;
  wire n7077;
  wire n7078;
  wire n7080;
  wire n7082;
  wire n7083;
  wire [7:0] n7091;
  wire [7:0] n7092;
  reg [7:0] n7093;
  reg n7094;
  reg n7095;
  assign free_o = n7078; //(module output)
  assign rdata_o = n7091; //(module output)
  assign avail_o = avail; //(module output)
  /*# ../../rtl/core/neorv32_prim.vhd:50:10 */
  assign fifo = n7093; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:53:10 */
  assign rdata = fifo; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:10 */
  assign we = n7061; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:14 */
  assign re = n7059; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:18 */
  assign match = n7074; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:25 */
  assign full = n7076; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:31 */
  assign empty = match; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:38 */
  assign avail = n7077; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:10 */
  assign w_pnt = n7094; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:17 */
  assign w_nxt = n7063; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:24 */
  assign r_pnt = n7095; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:31 */
  assign r_nxt = n7068; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:63:16 */
  assign n7049 = ~rstn_i;
  /*# ../../rtl/core/neorv32_prim.vhd:73:19 */
  assign n7058 = ~empty;
  /*# ../../rtl/core/neorv32_prim.vhd:73:14 */
  assign n7059 = re_i & n7058;
  /*# ../../rtl/core/neorv32_prim.vhd:74:19 */
  assign n7060 = ~full;
  /*# ../../rtl/core/neorv32_prim.vhd:74:14 */
  assign n7061 = we_i & n7060;
  /*# ../../rtl/core/neorv32_prim.vhd:77:28 */
  assign n7063 = clear_i ? 1'b0 : n7066;
  /*# ../../rtl/core/neorv32_prim.vhd:77:88 */
  assign n7065 = w_pnt + 1'b1;
  /*# ../../rtl/core/neorv32_prim.vhd:77:49 */
  assign n7066 = we ? n7065 : w_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:78:28 */
  assign n7068 = clear_i ? 1'b0 : n7071;
  /*# ../../rtl/core/neorv32_prim.vhd:78:88 */
  assign n7070 = r_pnt + 1'b1;
  /*# ../../rtl/core/neorv32_prim.vhd:78:49 */
  assign n7071 = re ? n7070 : r_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:102:33 */
  assign n7073 = r_pnt == w_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:102:18 */
  assign n7074 = n7073 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_prim.vhd:103:14 */
  assign n7076 = ~match;
  /*# ../../rtl/core/neorv32_prim.vhd:105:14 */
  assign n7077 = ~empty;
  /*# ../../rtl/core/neorv32_prim.vhd:109:14 */
  assign n7078 = ~full;
  /*# ../../rtl/core/neorv32_prim.vhd:134:18 */
  assign n7080 = ~rstn_i;
  /*# ../../rtl/core/neorv32_prim.vhd:137:36 */
  assign n7082 = ~clear_i;
  /*# ../../rtl/core/neorv32_prim.vhd:137:23 */
  assign n7083 = n7082 & we;
  /*# ../../rtl/core/neorv32_prim.vhd:146:30 */
  assign n7091 = 1'b0 ? 8'b00000000 : rdata;
  /*# ../../rtl/core/neorv32_prim.vhd:136:7 */
  assign n7092 = n7083 ? wdata_i : fifo;
  /*# ../../rtl/core/neorv32_prim.vhd:136:7 */
  always @(posedge clk_i or posedge n7080)
    if (n7080)
      n7093 <= 8'b00000000;
    else
      n7093 <= n7092;
  /*# ../../rtl/core/neorv32_prim.vhd:66:5 */
  always @(posedge clk_i or posedge n7049)
    if (n7049)
      n7094 <= 1'b0;
    else
      n7094 <= w_nxt;
  /*# ../../rtl/core/neorv32_prim.vhd:66:5 */
  always @(posedge clk_i or posedge n7049)
    if (n7049)
      n7095 <= 1'b0;
    else
      n7095 <= r_nxt;
endmodule

module neorv32_bus_reg_Bneorv32_bus_reg_rtl_Lneorv32_9159cb8bcee7fcb95582f140960cdae72788d326
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \host_req_i[meta] ,
   input  [31:0] \host_req_i[addr] ,
   input  [31:0] \host_req_i[data] ,
   input  [3:0] \host_req_i[ben] ,
   input  \host_req_i[stb] ,
   input  \host_req_i[rw] ,
   input  \host_req_i[amo] ,
   input  [3:0] \host_req_i[amoop] ,
   input  \host_req_i[burst] ,
   input  \host_req_i[lock] ,
   output \host_rsp_o[ack] ,
   output \host_rsp_o[err] ,
   output [31:0] \host_rsp_o[data] ,
   output [4:0] \device_req_o[meta] ,
   output [31:0] \device_req_o[addr] ,
   output [31:0] \device_req_o[data] ,
   output [3:0] \device_req_o[ben] ,
   output \device_req_o[stb] ,
   output \device_req_o[rw] ,
   output \device_req_o[amo] ,
   output [3:0] \device_req_o[amoop] ,
   output \device_req_o[burst] ,
   output \device_req_o[lock] ,
   input  \device_rsp_i[ack] ,
   input  \device_rsp_i[err] ,
   input  [31:0] \device_rsp_i[data] );
  wire [81:0] n7002;
  wire n7004;
  wire n7005;
  wire [31:0] n7006;
  wire [4:0] n7008;
  wire [31:0] n7009;
  wire [31:0] n7010;
  wire [3:0] n7011;
  wire n7012;
  wire n7013;
  wire n7014;
  wire [3:0] n7015;
  wire n7016;
  wire n7017;
  wire [33:0] n7018;
  wire n7020;
  wire n7022;
  wire [81:0] n7023;
  wire n7024;
  wire [72:0] n7026;
  wire n7027;
  wire [5:0] n7029;
  wire n7030;
  wire [81:0] n7031;
  wire n7037;
  reg [33:0] n7043;
  reg [81:0] n7044;
  assign \host_rsp_o[ack]  = n7004; //(module output)
  assign \host_rsp_o[err]  = n7005; //(module output)
  assign \host_rsp_o[data]  = n7006; //(module output)
  assign \device_req_o[meta]  = n7008; //(module output)
  assign \device_req_o[addr]  = n7009; //(module output)
  assign \device_req_o[data]  = n7010; //(module output)
  assign \device_req_o[ben]  = n7011; //(module output)
  assign \device_req_o[stb]  = n7012; //(module output)
  assign \device_req_o[rw]  = n7013; //(module output)
  assign \device_req_o[amo]  = n7014; //(module output)
  assign \device_req_o[amoop]  = n7015; //(module output)
  assign \device_req_o[burst]  = n7016; //(module output)
  assign \device_req_o[lock]  = n7017; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7002 = {\host_req_i[lock] , \host_req_i[burst] , \host_req_i[amoop] , \host_req_i[amo] , \host_req_i[rw] , \host_req_i[stb] , \host_req_i[ben] , \host_req_i[data] , \host_req_i[addr] , \host_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7004 = n7043[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7005 = n7043[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7006 = n7043[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7008 = n7044[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7009 = n7044[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7010 = n7044[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7011 = n7044[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7012 = n7044[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7013 = n7044[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7014 = n7044[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7015 = n7044[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7016 = n7044[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7017 = n7044[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7018 = {\device_rsp_i[data] , \device_rsp_i[err] , \device_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:199:18 */
  assign n7020 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:202:24 */
  assign n7022 = n7002[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:202:9 */
  assign n7023 = n7022 ? n7002 : n7044;
  /*# ../../rtl/core/neorv32_bus.vhd:206:42 */
  assign n7024 = n7002[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:184:5 */
  assign n7026 = n7023[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:207:42 */
  assign n7027 = n7002[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:184:5 */
  assign n7029 = n7023[79:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:208:42 */
  assign n7030 = n7002[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:201:7 */
  assign n7031 = {n7030, n7027, n7029, n7024, n7026};
  /*# ../../rtl/core/neorv32_bus.vhd:224:18 */
  assign n7037 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:226:7 */
  always @(posedge clk_i or posedge n7037)
    if (n7037)
      n7043 <= 34'b0000000000000000000000000000000000;
    else
      n7043 <= n7018;
  /*# ../../rtl/core/neorv32_bus.vhd:201:7 */
  always @(posedge clk_i or posedge n7020)
    if (n7020)
      n7044 <= 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7044 <= n7031;
endmodule

module neorv32_bus_reg_Bneorv32_bus_reg_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \host_req_i[meta] ,
   input  [31:0] \host_req_i[addr] ,
   input  [31:0] \host_req_i[data] ,
   input  [3:0] \host_req_i[ben] ,
   input  \host_req_i[stb] ,
   input  \host_req_i[rw] ,
   input  \host_req_i[amo] ,
   input  [3:0] \host_req_i[amoop] ,
   input  \host_req_i[burst] ,
   input  \host_req_i[lock] ,
   output \host_rsp_o[ack] ,
   output \host_rsp_o[err] ,
   output [31:0] \host_rsp_o[data] ,
   output [4:0] \device_req_o[meta] ,
   output [31:0] \device_req_o[addr] ,
   output [31:0] \device_req_o[data] ,
   output [3:0] \device_req_o[ben] ,
   output \device_req_o[stb] ,
   output \device_req_o[rw] ,
   output \device_req_o[amo] ,
   output [3:0] \device_req_o[amoop] ,
   output \device_req_o[burst] ,
   output \device_req_o[lock] ,
   input  \device_rsp_i[ack] ,
   input  \device_rsp_i[err] ,
   input  [31:0] \device_rsp_i[data] );
  wire [81:0] n6985;
  wire n6987;
  wire n6988;
  wire [31:0] n6989;
  wire [4:0] n6991;
  wire [31:0] n6992;
  wire [31:0] n6993;
  wire [3:0] n6994;
  wire n6995;
  wire n6996;
  wire n6997;
  wire [3:0] n6998;
  wire n6999;
  wire n7000;
  wire [33:0] n7001;
  assign \host_rsp_o[ack]  = n6987; //(module output)
  assign \host_rsp_o[err]  = n6988; //(module output)
  assign \host_rsp_o[data]  = n6989; //(module output)
  assign \device_req_o[meta]  = n6991; //(module output)
  assign \device_req_o[addr]  = n6992; //(module output)
  assign \device_req_o[data]  = n6993; //(module output)
  assign \device_req_o[ben]  = n6994; //(module output)
  assign \device_req_o[stb]  = n6995; //(module output)
  assign \device_req_o[rw]  = n6996; //(module output)
  assign \device_req_o[amo]  = n6997; //(module output)
  assign \device_req_o[amoop]  = n6998; //(module output)
  assign \device_req_o[burst]  = n6999; //(module output)
  assign \device_req_o[lock]  = n7000; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6985 = {\host_req_i[lock] , \host_req_i[burst] , \host_req_i[amoop] , \host_req_i[amo] , \host_req_i[rw] , \host_req_i[stb] , \host_req_i[ben] , \host_req_i[data] , \host_req_i[addr] , \host_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6987 = n7001[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6988 = n7001[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6989 = n7001[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6991 = n6985[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6992 = n6985[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6993 = n6985[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6994 = n6985[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6995 = n6985[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6996 = n6985[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6997 = n6985[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6998 = n6985[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6999 = n6985[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7000 = n6985[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n7001 = {\device_rsp_i[data] , \device_rsp_i[err] , \device_rsp_i[ack] };
endmodule

module neorv32_dmem_ram_Bneorv32_dmem_ram_rtl_Lneorv32_14_0
  (input  clk_i,
   input  [3:0] en_i,
   input  rw_i,
   input  [31:0] addr_i,
   input  [31:0] data_i,
   output [31:0] data_o);
  wire [7:0] \ram_gen[0]_ram_inst.data_o ;
  wire n6968;
  wire [11:0] n6969;
  wire [7:0] n6970;
  wire [7:0] \ram_gen[1]_ram_inst.data_o ;
  wire n6972;
  wire [11:0] n6973;
  wire [7:0] n6974;
  wire [7:0] \ram_gen[2]_ram_inst.data_o ;
  wire n6976;
  wire [11:0] n6977;
  wire [7:0] n6978;
  wire [7:0] \ram_gen[3]_ram_inst.data_o ;
  wire n6980;
  wire [11:0] n6981;
  wire [7:0] n6982;
  wire [31:0] n6984;
  assign data_o = n6984; //(module output)
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[0]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6968),
    .rw_i(rw_i),
    .addr_i(n6969),
    .data_i(n6970),
    .data_o(\ram_gen[0]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6968 = en_i[0]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6969 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6970 = data_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[1]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6972),
    .rw_i(rw_i),
    .addr_i(n6973),
    .data_i(n6974),
    .data_o(\ram_gen[1]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6972 = en_i[1]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6973 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6974 = data_i[15:8]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[2]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6976),
    .rw_i(rw_i),
    .addr_i(n6977),
    .data_i(n6978),
    .data_o(\ram_gen[2]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6976 = en_i[2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6977 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6978 = data_i[23:16]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[3]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6980),
    .rw_i(rw_i),
    .addr_i(n6981),
    .data_i(n6982),
    .data_o(\ram_gen[3]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6980 = en_i[3]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6981 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6982 = data_i[31:24]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:31:5 */
  assign n6984 = {\ram_gen[3]_ram_inst.data_o , \ram_gen[2]_ram_inst.data_o , \ram_gen[1]_ram_inst.data_o , \ram_gen[0]_ram_inst.data_o };
endmodule

module neorv32_imem_rom_Bneorv32_imem_rom_rtl_Lneorv32_14_0
  (input  clk_i,
   input  en_i,
   input  [31:0] addr_i,
   output [31:0] data_o);
  wire [31:0] rdata;
  wire [7:0] n6952;
  reg [31:0] n6966; // mem_rd
  assign data_o = rdata; //(module output)
  /*# ../../rtl/core/neorv32_imem_rom.vhd:37:10 */
  assign rdata = n6966; // (signal)
  /*# ../../rtl/core/neorv32_imem_rom.vhd:56:57 */
  assign n6952 = addr_i[9:2]; // extract
  /*# ../../rtl/core/neorv32_imem_rom.vhd:56:31 */
  reg [31:0] n6964[255:0] ; // memory
  initial begin
    n6964[255] = 32'b00000000000000000000000000000000;
    n6964[254] = 32'b00000000000000000000000000000000;
    n6964[253] = 32'b00000000000000000000000000000000;
    n6964[252] = 32'b00000000000000000000000000000000;
    n6964[251] = 32'b00000000000000000000000000000000;
    n6964[250] = 32'b00000000000000000000000000000000;
    n6964[249] = 32'b00000000000000000000000000000000;
    n6964[248] = 32'b00000000000000000000000000000000;
    n6964[247] = 32'b00000000000000000000000000000000;
    n6964[246] = 32'b00000000000000000000000000000000;
    n6964[245] = 32'b00000000000000000000000000000000;
    n6964[244] = 32'b00000000000000000000000000000000;
    n6964[243] = 32'b00000000000000000000000000000000;
    n6964[242] = 32'b00000000000000000000000000000000;
    n6964[241] = 32'b00000000000000000000000000000000;
    n6964[240] = 32'b00000000000000000000000000000000;
    n6964[239] = 32'b00000000000000000000000000000000;
    n6964[238] = 32'b00000000000000000000000000000000;
    n6964[237] = 32'b00000000000000000000000000000000;
    n6964[236] = 32'b00000000000000000000000000000000;
    n6964[235] = 32'b00000000000000000000000000000000;
    n6964[234] = 32'b00000000000000000000000000000000;
    n6964[233] = 32'b00000000000000000000000000000000;
    n6964[232] = 32'b00000000000000000000000000000000;
    n6964[231] = 32'b00000000000000000000000000000000;
    n6964[230] = 32'b00000000000000000000000000000000;
    n6964[229] = 32'b00000000000000000000000000000000;
    n6964[228] = 32'b00000000000000000000000000000000;
    n6964[227] = 32'b00000000000000000000000000000000;
    n6964[226] = 32'b00000000000000000000000000000000;
    n6964[225] = 32'b00000000000000000000000000000000;
    n6964[224] = 32'b00000000000000000000000000000000;
    n6964[223] = 32'b00000000000000000000000000000000;
    n6964[222] = 32'b00000000000000000000000000000000;
    n6964[221] = 32'b00000000000000000000000000000000;
    n6964[220] = 32'b00000000000000000000000000000000;
    n6964[219] = 32'b00000000000000000000000000000000;
    n6964[218] = 32'b00000000000000000000000000000000;
    n6964[217] = 32'b00000000000000000000000000000000;
    n6964[216] = 32'b00000000000000000000000000000000;
    n6964[215] = 32'b00000000000000000000000000000000;
    n6964[214] = 32'b00000000000000000000000000000000;
    n6964[213] = 32'b00000000000000000000000000000000;
    n6964[212] = 32'b00000000000000000000000000000000;
    n6964[211] = 32'b00000000000000000000000000000000;
    n6964[210] = 32'b00000000000000000000000000000000;
    n6964[209] = 32'b00000000000000000000000000000000;
    n6964[208] = 32'b00000000000000000000000000000000;
    n6964[207] = 32'b00000000000000000000000000000000;
    n6964[206] = 32'b00000000000000000000000000000000;
    n6964[205] = 32'b00000000000000000000000000000000;
    n6964[204] = 32'b00000000000000000000000000000000;
    n6964[203] = 32'b00000000000000000000000000000000;
    n6964[202] = 32'b00000000000000000000000000000000;
    n6964[201] = 32'b00000000000000000000000000000000;
    n6964[200] = 32'b00000000000000000000000000000000;
    n6964[199] = 32'b00000000000000000000000000000000;
    n6964[198] = 32'b00000000000000001000000001100111;
    n6964[197] = 32'b00000001000000010000000100010011;
    n6964[196] = 32'b00000000000000110000010110010011;
    n6964[195] = 32'b00000000000010000000010100010011;
    n6964[194] = 32'b00000000110000010010000010000011;
    n6964[193] = 32'b00000000011001010000001100110011;
    n6964[192] = 32'b11110110100111111111000011101111;
    n6964[191] = 32'b00000000000000101000010110010011;
    n6964[190] = 32'b00000000000000111000010100010011;
    n6964[189] = 32'b00000000000000101000101001100011;
    n6964[188] = 32'b00000000011001010000001100110011;
    n6964[187] = 32'b11110111110111111111000011101111;
    n6964[186] = 32'b00000000000001100000010100010011;
    n6964[185] = 32'b00000000000001011000100001100011;
    n6964[184] = 32'b11111100000001110001100011100011;
    n6964[183] = 32'b00000001110001111110011110110011;
    n6964[182] = 32'b00000000000101101001011010010011;
    n6964[181] = 32'b00000001111011111000001100110011;
    n6964[180] = 32'b00000000000010001000100000010011;
    n6964[179] = 32'b00000000000011101000011001100011;
    n6964[178] = 32'b00000000000101111001011110010011;
    n6964[177] = 32'b00000001000010001011111110110011;
    n6964[176] = 32'b00000000000101110101011100010011;
    n6964[175] = 32'b00000001111101101101111000010011;
    n6964[174] = 32'b00000000111100110000111100110011;
    n6964[173] = 32'b00000000000101110111111010010011;
    n6964[172] = 32'b00000000110110000000100010110011;
    n6964[171] = 32'b00000000000000000000100000010011;
    n6964[170] = 32'b00000000000000000000001100010011;
    n6964[169] = 32'b00000000000000000000011110010011;
    n6964[168] = 32'b00000000000001100000011100010011;
    n6964[167] = 32'b00000000000001010000011010010011;
    n6964[166] = 32'b00000000000001010000001110010011;
    n6964[165] = 32'b00000000000100010010011000100011;
    n6964[164] = 32'b00000000000001101000001010010011;
    n6964[163] = 32'b11111111000000010000000100010011;
    n6964[162] = 32'b00000000000000001000000001100111;
    n6964[161] = 32'b11111110000001011001011011100011;
    n6964[160] = 32'b00000000000101100001011000010011;
    n6964[159] = 32'b00000000000101011101010110010011;
    n6964[158] = 32'b00000000110001010000010100110011;
    n6964[157] = 32'b00000000000001101000010001100011;
    n6964[156] = 32'b00000000000101011111011010010011;
    n6964[155] = 32'b00000000000000000000010100010011;
    n6964[154] = 32'b00000000000001010000011000010011;
    n6964[153] = 32'b00000000000000001000000001100111;
    n6964[152] = 32'b00000000101001111010010000100011;
    n6964[151] = 32'b11111111111111000000011110110111;
    n6964[150] = 32'b00000000000000001000000001100111;
    n6964[149] = 32'b00000000101001111010001000100011;
    n6964[148] = 32'b11111111111111000000011110110111;
    n6964[147] = 32'b00000000000000001000000001100111;
    n6964[146] = 32'b00000001000000010000000100010011;
    n6964[145] = 32'b00000000110000010010000010000011;
    n6964[144] = 32'b11111111000111111111000001101111;
    n6964[143] = 32'b00000000000000000000000000010011;
    n6964[142] = 32'b11111111111101010000010100010011;
    n6964[141] = 32'b00000000000000000001100001100011;
    n6964[140] = 32'b00000000000001010000101001100011;
    n6964[139] = 32'b00000000101001011000010100110011;
    n6964[138] = 32'b00000000010001010101010100010011;
    n6964[137] = 32'b00000001110001011001010110010011;
    n6964[136] = 32'b00000110110000000000000011101111;
    n6964[135] = 32'b00000000000100010010011000100011;
    n6964[134] = 32'b00000000000000000000010110010011;
    n6964[133] = 32'b00000000101001010101010100010011;
    n6964[132] = 32'b00000000000000000000011010010011;
    n6964[131] = 32'b00000000000001011000011000010011;
    n6964[130] = 32'b11111111000000010000000100010011;
    n6964[129] = 32'b11111110110111111111000001101111;
    n6964[128] = 32'b00000000000101000000010000010011;
    n6964[127] = 32'b11111100010111111111000011101111;
    n6964[126] = 32'b00001111101000000000010100010011;
    n6964[125] = 32'b00000101110000000000000011101111;
    n6964[124] = 32'b00001111111101000111010100010011;
    n6964[123] = 32'b00000000000000000000010000010011;
    n6964[122] = 32'b00000111010000000000000011101111;
    n6964[121] = 32'b00001111111100000000010100010011;
    n6964[120] = 32'b00000111000000000000000011101111;
    n6964[119] = 32'b00000000100000010010010000100011;
    n6964[118] = 32'b00000000000100010010011000100011;
    n6964[117] = 32'b00000000000000000000010100010011;
    n6964[116] = 32'b11111111000000010000000100010011;
    n6964[115] = 32'b00000011110000000000000001101111;
    n6964[114] = 32'b00000000000001111010010100000011;
    n6964[113] = 32'b00000000000001010000010110010011;
    n6964[112] = 32'b11111111111111100000011110110111;
    n6964[111] = 32'b11111111110111111111000001101111;
    n6964[110] = 32'b00010000010100000000000001110011;
    n6964[109] = 32'b11111111110111111111000001101111;
    n6964[108] = 32'b00010000010100000000000001110011;
    n6964[107] = 32'b00000000000100000000000001110011;
    n6964[106] = 32'b00000000000001000001010001100011;
    n6964[105] = 32'b11110001010000000010010001110011;
    n6964[104] = 32'b11111110100101000100101011100011;
    n6964[103] = 32'b00000000010001000000010000010011;
    n6964[102] = 32'b00000000000000001000000011100111;
    n6964[101] = 32'b00000000000001000010000010000011;
    n6964[100] = 32'b00000000100101000101101001100011;
    n6964[99] = 32'b00011001010001001000010010010011;
    n6964[98] = 32'b00000000000000000000010010010111;
    n6964[97] = 32'b00011001110001000000010000010011;
    n6964[96] = 32'b00000000000000000000010000010111;
    n6964[95] = 32'b00000010000001000001010001100011;
    n6964[94] = 32'b11110001010000000010010001110011;
    n6964[93] = 32'b00110100000001010001000001110011;
    n6964[92] = 32'b00110000010101011001000001110011;
    n6964[91] = 32'b00000101000001011000010110010011;
    n6964[90] = 32'b00000000000000000000010110010111;
    n6964[89] = 32'b00110000010000000001000001110011;
    n6964[88] = 32'b00110000000001000111000001110011;
    n6964[87] = 32'b00000000000001100000000011100111;
    n6964[86] = 32'b00000000000000000000010110010011;
    n6964[85] = 32'b00000000000000000000010100010011;
    n6964[84] = 32'b00000000000000000001000000001111;
    n6964[83] = 32'b00001111111100000000000000001111;
    n6964[82] = 32'b00001000110001100000011000010011;
    n6964[81] = 32'b00000000000000000000011000010111;
    n6964[80] = 32'b11111110100101000100101011100011;
    n6964[79] = 32'b00000000010001000000010000010011;
    n6964[78] = 32'b00000000000000001000000011100111;
    n6964[77] = 32'b00000000000001000010000010000011;
    n6964[76] = 32'b00000000100101000101101001100011;
    n6964[75] = 32'b00011111010001001000010010010011;
    n6964[74] = 32'b00000000000000000000010010010111;
    n6964[73] = 32'b00011111110001000000010000010011;
    n6964[72] = 32'b00000000000000000000010000010111;
    n6964[71] = 32'b11111110101101010100110011100011;
    n6964[70] = 32'b00000000010001010000010100010011;
    n6964[69] = 32'b00000000000001010010000000100011;
    n6964[68] = 32'b00000000101101010101100001100011;
    n6964[67] = 32'b11111110100101000100100011100011;
    n6964[66] = 32'b00000000010001000000010000010011;
    n6964[65] = 32'b00000000010000111000001110010011;
    n6964[64] = 32'b00000000111101000010000000100011;
    n6964[63] = 32'b00000000000000111010011110000011;
    n6964[62] = 32'b00000000100101000101110001100011;
    n6964[61] = 32'b00000000100000111000111001100011;
    n6964[60] = 32'b00000101110000000000000001101111;
    n6964[59] = 32'b00000000000001110010001000100011;
    n6964[58] = 32'b11111111111101000000011100110111;
    n6964[57] = 32'b00000000110001110010011000000011;
    n6964[56] = 32'b00000000100001110010000100000011;
    n6964[55] = 32'b11111111111101000100011100110111;
    n6964[54] = 32'b00110000010000000101000001110011;
    n6964[53] = 32'b00110000010101111001000001110011;
    n6964[52] = 32'b00001110110001111000011110010011;
    n6964[51] = 32'b00000000000000000000011110010111;
    n6964[50] = 32'b11111111110111111111000001101111;
    n6964[49] = 32'b00010000010100000000000001110011;
    n6964[48] = 32'b00110000000001000110000001110011;
    n6964[47] = 32'b00110000010001000101000001110011;
    n6964[46] = 32'b00110000010101111001000001110011;
    n6964[45] = 32'b00000001110001111000011110010011;
    n6964[44] = 32'b00000000000000000000011110010111;
    n6964[43] = 32'b00000100000000001000010001100011;
    n6964[42] = 32'b00000000000000000000111110010011;
    n6964[41] = 32'b00000000000000000000111100010011;
    n6964[40] = 32'b00000000000000000000111010010011;
    n6964[39] = 32'b00000000000000000000111000010011;
    n6964[38] = 32'b00000000000000000000110110010011;
    n6964[37] = 32'b00000000000000000000110100010011;
    n6964[36] = 32'b00000000000000000000110010010011;
    n6964[35] = 32'b00000000000000000000110000010011;
    n6964[34] = 32'b00000000000000000000101110010011;
    n6964[33] = 32'b00000000000000000000101100010011;
    n6964[32] = 32'b00000000000000000000101010010011;
    n6964[31] = 32'b00000000000000000000101000010011;
    n6964[30] = 32'b00000000000000000000100110010011;
    n6964[29] = 32'b00000000000000000000100100010011;
    n6964[28] = 32'b00000000000000000000100010010011;
    n6964[27] = 32'b00000000000000000000100000010011;
    n6964[26] = 32'b00000000000000000000011110010011;
    n6964[25] = 32'b00000000000000000000011100010011;
    n6964[24] = 32'b00000000000000000000011010010011;
    n6964[23] = 32'b00000000000000000000011000010011;
    n6964[22] = 32'b11111010110001011000010110010011;
    n6964[21] = 32'b10000000000000000000010110010111;
    n6964[20] = 32'b11111011010001010000010100010011;
    n6964[19] = 32'b10000000000000000000010100010111;
    n6964[18] = 32'b11111011110001001000010010010011;
    n6964[17] = 32'b10000000000000000000010010010111;
    n6964[16] = 32'b11111100010001000000010000010011;
    n6964[15] = 32'b10000000000000000000010000010111;
    n6964[14] = 32'b00101110100000111000001110010011;
    n6964[13] = 32'b00000000000000000000001110010111;
    n6964[12] = 32'b00110000010000000001000001110011;
    n6964[11] = 32'b00110000010100110001000001110011;
    n6964[10] = 32'b00011001010000110000001100010011;
    n6964[9] = 32'b00000000000000000000001100010111;
    n6964[8] = 32'b00110000000000101001000001110011;
    n6964[7] = 32'b10000000000000101000001010010011;
    n6964[6] = 32'b00000000000000000010001010110111;
    n6964[5] = 32'b01111111000000011000000110010011;
    n6964[4] = 32'b10000000000000000000000110010111;
    n6964[3] = 32'b11111111000000100111000100010011;
    n6964[2] = 32'b11111111110000100000001000010011;
    n6964[1] = 32'b10000000000000000010001000010111;
    n6964[0] = 32'b11110001010000000010000011110011;
    end
  always @(posedge clk_i)
    if (en_i)
      n6966 <= n6964[n6952];
  /*# ../../rtl/core/neorv32_imem_rom.vhd:54:5 */
endmodule

module neorv32_cpu_lsu_Bneorv32_cpu_lsu_rtl_Lneorv32_0_5ba93c9db0cff93f52b521d7420e43f6eda2784f
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   input  [31:0] addr_i,
   input  [31:0] wdata_i,
   output [31:0] rdata_o,
   output [31:0] mar_o,
   output wait_o,
   output [3:0] err_o,
   input  pmp_fault_i,
   output [4:0] \dbus_req_o[meta] ,
   output [31:0] \dbus_req_o[addr] ,
   output [31:0] \dbus_req_o[data] ,
   output [3:0] \dbus_req_o[ben] ,
   output \dbus_req_o[stb] ,
   output \dbus_req_o[rw] ,
   output \dbus_req_o[amo] ,
   output [3:0] \dbus_req_o[amoop] ,
   output \dbus_req_o[burst] ,
   output \dbus_req_o[lock] ,
   input  \dbus_rsp_i[ack] ,
   input  \dbus_rsp_i[err] ,
   input  [31:0] \dbus_rsp_i[data] );
  wire [261:0] n6676;
  wire [4:0] n6682;
  wire [31:0] n6683;
  wire [31:0] n6684;
  wire [3:0] n6685;
  wire n6686;
  wire n6687;
  wire n6688;
  wire [3:0] n6689;
  wire n6690;
  wire n6691;
  wire [33:0] n6692;
  wire [81:0] req;
  wire misalign;
  wire n6697;
  wire n6704;
  wire n6705;
  wire [2:0] n6707;
  wire n6708;
  wire [3:0] n6709;
  wire [4:0] n6711;
  wire [1:0] n6712;
  wire [7:0] n6713;
  wire [7:0] n6714;
  wire [15:0] n6715;
  wire [7:0] n6716;
  wire [23:0] n6717;
  wire [7:0] n6718;
  wire [31:0] n6719;
  wire n6720;
  wire n6721;
  wire n6722;
  wire n6723;
  wire n6724;
  wire n6725;
  wire n6726;
  wire n6727;
  wire n6728;
  wire n6729;
  wire n6730;
  wire n6731;
  wire n6732;
  wire n6733;
  wire n6734;
  wire n6735;
  wire n6737;
  wire [15:0] n6738;
  wire [15:0] n6739;
  wire [31:0] n6740;
  wire n6741;
  wire n6742;
  wire [1:0] n6743;
  wire n6744;
  wire n6745;
  wire [2:0] n6746;
  wire n6747;
  wire n6748;
  wire [3:0] n6749;
  wire n6750;
  wire n6752;
  localparam [3:0] n6753 = 4'b1111;
  wire n6754;
  wire n6755;
  wire n6756;
  wire [1:0] n6757;
  reg [31:0] n6758;
  wire n6759;
  wire n6760;
  reg n6761;
  wire n6762;
  wire n6763;
  reg n6764;
  wire n6765;
  wire n6766;
  reg n6767;
  wire n6768;
  wire n6769;
  reg n6770;
  reg n6772;
  wire n6773;
  wire [72:0] n6774;
  wire [72:0] n6785;
  wire n6792;
  wire n6793;
  wire n6794;
  wire n6795;
  wire n6796;
  wire [31:0] n6797;
  wire n6799;
  wire n6801;
  wire [1:0] n6802;
  wire [1:0] n6803;
  wire n6805;
  wire n6806;
  wire n6807;
  wire n6808;
  wire [23:0] n6814;
  wire [7:0] n6816;
  wire [31:0] n6817;
  wire n6819;
  wire n6821;
  wire n6822;
  wire n6823;
  wire n6824;
  wire [23:0] n6830;
  wire [7:0] n6832;
  wire [31:0] n6833;
  wire n6835;
  wire n6837;
  wire n6838;
  wire n6839;
  wire n6840;
  wire [23:0] n6846;
  wire [7:0] n6848;
  wire [31:0] n6849;
  wire n6851;
  wire n6853;
  wire n6854;
  wire n6855;
  wire n6856;
  wire [23:0] n6862;
  wire [7:0] n6864;
  wire [31:0] n6865;
  wire n6867;
  wire [3:0] n6868;
  reg [31:0] n6870;
  wire n6872;
  wire n6873;
  wire n6874;
  wire n6876;
  wire n6877;
  wire n6878;
  wire n6879;
  wire [15:0] n6885;
  wire [15:0] n6887;
  wire [31:0] n6888;
  wire n6890;
  wire n6891;
  wire n6892;
  wire n6893;
  wire [15:0] n6899;
  wire [15:0] n6901;
  wire [31:0] n6902;
  wire [31:0] n6903;
  wire n6905;
  wire [31:0] n6906;
  wire [1:0] n6907;
  reg [31:0] n6908;
  wire [31:0] n6910;
  wire n6916;
  wire n6917;
  wire n6918;
  wire n6919;
  wire n6920;
  wire n6921;
  wire n6922;
  wire n6923;
  wire n6924;
  wire n6925;
  wire n6926;
  wire n6927;
  wire n6928;
  wire n6929;
  wire n6930;
  wire n6931;
  wire n6932;
  wire n6933;
  wire n6934;
  wire n6935;
  wire n6936;
  wire n6937;
  wire [81:0] n6938;
  wire [3:0] n6939;
  reg [31:0] n6940;
  wire n6941;
  wire n6942;
  reg n6943;
  wire [72:0] n6944;
  wire [72:0] n6945;
  reg [72:0] n6946;
  wire n6947;
  reg n6948;
  assign rdata_o = n6940; //(module output)
  assign mar_o = n6797; //(module output)
  assign wait_o = n6917; //(module output)
  assign err_o = n6939; //(module output)
  assign \dbus_req_o[meta]  = n6682; //(module output)
  assign \dbus_req_o[addr]  = n6683; //(module output)
  assign \dbus_req_o[data]  = n6684; //(module output)
  assign \dbus_req_o[ben]  = n6685; //(module output)
  assign \dbus_req_o[stb]  = n6686; //(module output)
  assign \dbus_req_o[rw]  = n6687; //(module output)
  assign \dbus_req_o[amo]  = n6688; //(module output)
  assign \dbus_req_o[amoop]  = n6689; //(module output)
  assign \dbus_req_o[burst]  = n6690; //(module output)
  assign \dbus_req_o[lock]  = n6691; //(module output)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6676 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6682 = req[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6683 = req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6684 = req[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6685 = req[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6686 = req[73]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6687 = req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6688 = req[75]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6689 = req[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6690 = req[80]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6691 = req[81]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6692 = {\dbus_rsp_i[data] , \dbus_rsp_i[err] , \dbus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:44:10 */
  assign req = n6938; // (signal)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:45:10 */
  assign misalign = n6948; // (signal)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:100:16 */
  assign n6697 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:108:18 */
  assign n6704 = n6676[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:73 */
  assign n6705 = n6676[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:64 */
  assign n6707 = {2'b00, n6705};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:92 */
  assign n6708 = n6676[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:83 */
  assign n6709 = {n6707, n6708};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:101 */
  assign n6711 = {n6709, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:30 */
  assign n6712 = n6676[221:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:34 */
  assign n6713 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:56 */
  assign n6714 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:47 */
  assign n6715 = {n6713, n6714};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:78 */
  assign n6716 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:69 */
  assign n6717 = {n6715, n6716};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:100 */
  assign n6718 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:91 */
  assign n6719 = {n6717, n6718};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:38 */
  assign n6720 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:28 */
  assign n6721 = ~n6720;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:58 */
  assign n6722 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:48 */
  assign n6723 = ~n6722;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:43 */
  assign n6724 = n6721 & n6723;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:38 */
  assign n6725 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:28 */
  assign n6726 = ~n6725;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:58 */
  assign n6727 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:43 */
  assign n6728 = n6726 & n6727;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:38 */
  assign n6729 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:58 */
  assign n6730 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:48 */
  assign n6731 = ~n6730;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:43 */
  assign n6732 = n6729 & n6731;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:38 */
  assign n6733 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:58 */
  assign n6734 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:43 */
  assign n6735 = n6733 & n6734;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:112:11 */
  assign n6737 = n6712 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:32 */
  assign n6738 = wdata_i[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:55 */
  assign n6739 = wdata_i[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:46 */
  assign n6740 = {n6738, n6739};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:31 */
  assign n6741 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:43 */
  assign n6742 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:35 */
  assign n6743 = {n6741, n6742};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:60 */
  assign n6744 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:50 */
  assign n6745 = ~n6744;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:47 */
  assign n6746 = {n6743, n6745};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:78 */
  assign n6747 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:68 */
  assign n6748 = ~n6747;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6749 = {n6746, n6748};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:122:31 */
  assign n6750 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:119:11 */
  assign n6752 = n6712 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:31 */
  assign n6754 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:44 */
  assign n6755 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:35 */
  assign n6756 = n6754 | n6755;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  assign n6757 = {n6752, n6737};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6758 = n6740;
      2'b01: n6758 = n6719;
      default: n6758 = wdata_i;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6759 = n6749[0]; // extract
  assign n6760 = n6753[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6761 = n6759;
      2'b01: n6761 = n6724;
      default: n6761 = n6760;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6762 = n6749[1]; // extract
  assign n6763 = n6753[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6764 = n6762;
      2'b01: n6764 = n6728;
      default: n6764 = n6763;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6765 = n6749[2]; // extract
  assign n6766 = n6753[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6767 = n6765;
      2'b01: n6767 = n6732;
      default: n6767 = n6766;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6768 = n6749[3]; // extract
  assign n6769 = n6753[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6770 = n6768;
      2'b01: n6770 = n6735;
      default: n6770 = n6769;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6757)
      2'b10: n6772 = n6750;
      2'b01: n6772 = 1'b0;
      default: n6772 = n6756;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:131:28 */
  assign n6773 = n6676[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:108:7 */
  assign n6774 = {n6770, n6767, n6764, n6761, n6758, addr_i, n6711};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:100:5 */
  assign n6785 = {4'b0000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 5'b00000};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:24 */
  assign n6792 = n6676[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:37 */
  assign n6793 = ~misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:32 */
  assign n6794 = n6792 & n6793;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:56 */
  assign n6795 = ~pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:51 */
  assign n6796 = n6794 & n6795;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:140:21 */
  assign n6797 = req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:147:16 */
  assign n6799 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:151:18 */
  assign n6801 = n6676[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:30 */
  assign n6802 = n6676[221:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:26 */
  assign n6803 = req[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:74 */
  assign n6805 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:54 */
  assign n6806 = ~n6805;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:98 */
  assign n6807 = n6692[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:79 */
  assign n6808 = n6806 & n6807;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6814 = {n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808, n6808};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:125 */
  assign n6816 = n6692[9:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:108 */
  assign n6817 = {n6814, n6816};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:15 */
  assign n6819 = n6803 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:74 */
  assign n6821 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:54 */
  assign n6822 = ~n6821;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:98 */
  assign n6823 = n6692[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:79 */
  assign n6824 = n6822 & n6823;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6830 = {n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824, n6824};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:125 */
  assign n6832 = n6692[17:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:108 */
  assign n6833 = {n6830, n6832};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:15 */
  assign n6835 = n6803 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:74 */
  assign n6837 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:54 */
  assign n6838 = ~n6837;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:98 */
  assign n6839 = n6692[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:79 */
  assign n6840 = n6838 & n6839;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6846 = {n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840, n6840};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:125 */
  assign n6848 = n6692[25:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:108 */
  assign n6849 = {n6846, n6848};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:15 */
  assign n6851 = n6803 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:74 */
  assign n6853 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:54 */
  assign n6854 = ~n6853;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:98 */
  assign n6855 = n6692[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:79 */
  assign n6856 = n6854 & n6855;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6862 = {n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856, n6856};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:125 */
  assign n6864 = n6692[33:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:108 */
  assign n6865 = {n6862, n6864};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:15 */
  assign n6867 = n6803 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:13 */
  assign n6868 = {n6867, n6851, n6835, n6819};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:13 */
  always @*
    case (n6868)
      4'b1000: n6870 = n6865;
      4'b0100: n6870 = n6849;
      4'b0010: n6870 = n6833;
      4'b0001: n6870 = n6817;
      default: n6870 = 32'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:153:11 */
  assign n6872 = n6802 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:25 */
  assign n6873 = req[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:29 */
  assign n6874 = ~n6873;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:59 */
  assign n6876 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:39 */
  assign n6877 = ~n6876;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:83 */
  assign n6878 = n6692[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:64 */
  assign n6879 = n6877 & n6878;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6885 = {n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879, n6879};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:110 */
  assign n6887 = n6692[17:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:93 */
  assign n6888 = {n6885, n6887};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:59 */
  assign n6890 = n6676[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:39 */
  assign n6891 = ~n6890;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:83 */
  assign n6892 = n6692[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:64 */
  assign n6893 = n6891 & n6892;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6899 = {n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893, n6893};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:110 */
  assign n6901 = n6692[33:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:93 */
  assign n6902 = {n6899, n6901};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:13 */
  assign n6903 = n6874 ? n6888 : n6902;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:161:11 */
  assign n6905 = n6802 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:168:35 */
  assign n6906 = n6692[33:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:9 */
  assign n6907 = {n6905, n6872};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:9 */
  always @*
    case (n6907)
      2'b10: n6908 = n6903;
      2'b01: n6908 = n6870;
      default: n6908 = n6906;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:151:7 */
  assign n6910 = n6801 ? n6908 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:175:28 */
  assign n6916 = n6692[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:175:13 */
  assign n6917 = ~n6916;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:22 */
  assign n6918 = n6676[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:43 */
  assign n6919 = n6676[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:32 */
  assign n6920 = n6918 & n6919;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:50 */
  assign n6921 = n6920 & misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:22 */
  assign n6922 = n6676[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:43 */
  assign n6923 = n6676[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:32 */
  assign n6924 = n6922 & n6923;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:66 */
  assign n6925 = n6692[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:70 */
  assign n6926 = n6925 | pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:50 */
  assign n6927 = n6924 & n6926;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:22 */
  assign n6928 = n6676[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:43 */
  assign n6929 = n6676[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:32 */
  assign n6930 = n6928 & n6929;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:50 */
  assign n6931 = n6930 & misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:22 */
  assign n6932 = n6676[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:43 */
  assign n6933 = n6676[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:32 */
  assign n6934 = n6932 & n6933;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:66 */
  assign n6935 = n6692[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:70 */
  assign n6936 = n6935 | pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:50 */
  assign n6937 = n6934 & n6936;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:44:10 */
  assign n6938 = {1'b0, 1'b0, 4'b0000, 1'b0, n6943, n6796, n6946};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:34:5 */
  assign n6939 = {n6937, n6931, n6927, n6921};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:149:5 */
  always @(posedge clk_i or posedge n6799)
    if (n6799)
      n6940 <= 32'b00000000000000000000000000000000;
    else
      n6940 <= n6910;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6941 = req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6942 = n6704 ? n6773 : n6941;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6697)
    if (n6697)
      n6943 <= 1'b0;
    else
      n6943 <= n6942;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6944 = req[72:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6945 = n6704 ? n6774 : n6944;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6697)
    if (n6697)
      n6946 <= n6785;
    else
      n6946 <= n6945;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6947 = n6704 ? n6772 : misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6697)
    if (n6697)
      n6948 <= 1'b0;
    else
      n6948 <= n6947;
endmodule

module neorv32_cpu_alu_Bneorv32_cpu_alu_rtl_Lneorv32_f76e51fa32cd911aa74f5a7b915d61ba4b7734d9
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   input  [31:0] rs1_i,
   input  [31:0] rs2_i,
   output [1:0] cmp_o,
   output [31:0] res_o,
   output [31:0] add_o,
   output [31:0] csr_o,
   output done_o);
  wire [261:0] n6452;
  wire [31:0] opa;
  wire [31:0] opb;
  wire [31:0] cp_res;
  wire [32:0] cmp_rs1;
  wire [32:0] cmp_rs2;
  wire [32:0] opa_x;
  wire [32:0] opb_x;
  wire [32:0] addsub;
  wire [1:0] cmp;
  wire [223:0] cp_result;
  wire [6:0] cp_valid;
  wire n6458;
  wire n6459;
  wire n6460;
  wire n6461;
  wire [32:0] n6462;
  wire n6463;
  wire n6464;
  wire n6465;
  wire n6466;
  wire [32:0] n6467;
  wire n6469;
  wire n6470;
  wire n6473;
  wire n6474;
  wire [2:0] n6477;
  wire n6479;
  wire [31:0] n6480;
  wire n6482;
  wire n6484;
  wire n6485;
  wire n6487;
  wire n6489;
  wire [31:0] n6490;
  wire n6492;
  wire [31:0] n6493;
  wire n6495;
  wire [31:0] n6496;
  wire n6498;
  wire [7:0] n6499;
  wire n6501;
  wire n6502;
  wire n6503;
  wire n6504;
  wire n6505;
  wire n6506;
  reg n6508;
  wire [30:0] n6510;
  wire [30:0] n6511;
  wire [30:0] n6512;
  wire [30:0] n6513;
  wire [30:0] n6514;
  wire [30:0] n6515;
  reg [30:0] n6518;
  wire [31:0] n6522;
  wire n6523;
  wire [31:0] n6524;
  wire [31:0] n6525;
  wire n6526;
  wire [31:0] n6527;
  wire n6528;
  wire n6529;
  wire n6530;
  wire n6531;
  wire [32:0] n6532;
  wire n6533;
  wire n6534;
  wire n6535;
  wire n6536;
  wire [32:0] n6537;
  wire [31:0] n6538;
  wire [32:0] n6539;
  wire n6540;
  wire [32:0] n6541;
  wire [32:0] n6542;
  wire n6543;
  wire n6544;
  wire n6545;
  wire n6546;
  wire n6547;
  wire n6548;
  wire n6549;
  wire n6550;
  wire n6551;
  wire n6552;
  wire n6553;
  wire n6554;
  wire n6555;
  wire [31:0] n6556;
  wire [31:0] n6557;
  wire [31:0] n6558;
  wire [31:0] n6559;
  wire [31:0] n6560;
  wire [31:0] n6561;
  wire [31:0] n6562;
  wire [31:0] n6563;
  wire [31:0] n6564;
  wire [31:0] n6565;
  wire [31:0] n6566;
  wire [31:0] n6567;
  wire [31:0] n6568;
  wire [31:0] \neorv32_cpu_alu_shifter_inst.res_o ;
  wire \neorv32_cpu_alu_shifter_inst.valid_o ;
  wire n6569;
  wire n6570;
  wire n6571;
  wire [31:0] n6572;
  wire [31:0] n6573;
  wire [31:0] n6574;
  wire n6575;
  wire [4:0] n6576;
  wire [4:0] n6577;
  wire [4:0] n6578;
  wire n6579;
  wire [2:0] n6580;
  wire n6581;
  wire n6582;
  wire n6583;
  wire n6584;
  wire [31:0] n6585;
  wire n6586;
  wire n6587;
  wire n6588;
  wire n6589;
  wire n6590;
  wire n6591;
  wire n6592;
  wire n6593;
  wire n6594;
  wire n6595;
  wire n6596;
  wire n6597;
  wire [11:0] n6598;
  wire [31:0] n6599;
  wire [8:0] n6600;
  wire [2:0] n6601;
  wire [11:0] n6602;
  wire [6:0] n6603;
  wire [15:0] n6604;
  wire n6605;
  wire n6606;
  wire n6607;
  wire n6608;
  wire [4:0] n6609;
  wire [31:0] \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o ;
  wire \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o ;
  wire n6612;
  wire n6613;
  wire n6614;
  wire [31:0] n6615;
  wire [31:0] n6616;
  wire [31:0] n6617;
  wire n6618;
  wire [4:0] n6619;
  wire [4:0] n6620;
  wire [4:0] n6621;
  wire n6622;
  wire [2:0] n6623;
  wire n6624;
  wire n6625;
  wire n6626;
  wire n6627;
  wire [31:0] n6628;
  wire n6629;
  wire n6630;
  wire n6631;
  wire n6632;
  wire n6633;
  wire n6634;
  wire n6635;
  wire n6636;
  wire n6637;
  wire n6638;
  wire n6639;
  wire n6640;
  wire [11:0] n6641;
  wire [31:0] n6642;
  wire [8:0] n6643;
  wire [2:0] n6644;
  wire [11:0] n6645;
  wire [6:0] n6646;
  wire [15:0] n6647;
  wire n6648;
  wire n6649;
  wire n6650;
  wire n6651;
  localparam [31:0] n6659 = 32'b00000000000000000000000000000000;
  wire [1:0] n6672;
  wire [223:0] n6673;
  wire [6:0] n6674;
  wire [31:0] n6675;
  assign cmp_o = cmp; //(module output)
  assign res_o = n6675; //(module output)
  assign add_o = n6538; //(module output)
  assign csr_o = n6659; //(module output)
  assign done_o = n6555; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:18:8 */
  assign n6452 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:10 */
  assign opa = n6524; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign opb = n6527; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign cp_res = n6568; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:10 */
  assign cmp_rs1 = n6462; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:19 */
  assign cmp_rs2 = n6467; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:28 */
  assign opa_x = n6532; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:35 */
  assign opb_x = n6537; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:42 */
  assign addsub = n6541; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:79:10 */
  assign cmp = n6672; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:83:10 */
  assign cp_result = n6673; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:84:10 */
  assign cp_valid = n6674; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:20 */
  assign n6458 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:49 */
  assign n6459 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:38 */
  assign n6460 = ~n6459;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:33 */
  assign n6461 = n6458 & n6460;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:64 */
  assign n6462 = {n6461, rs1_i};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:20 */
  assign n6463 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:49 */
  assign n6464 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:38 */
  assign n6465 = ~n6464;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:33 */
  assign n6466 = n6463 & n6465;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:64 */
  assign n6467 = {n6466, rs2_i};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:95:29 */
  assign n6469 = rs1_i == rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:95:17 */
  assign n6470 = n6469 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:96:39 */
  assign n6473 = $signed(cmp_rs1) < $signed(cmp_rs2);
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:96:17 */
  assign n6474 = n6473 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:17 */
  assign n6477 = n6452[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:115:7 */
  assign n6479 = n6477 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6480 = addsub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:7 */
  assign n6482 = n6477 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:117:7 */
  assign n6484 = n6477 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:118:47 */
  assign n6485 = addsub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:118:7 */
  assign n6487 = n6477 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:119:7 */
  assign n6489 = n6477 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6490 = opb ^ rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:7 */
  assign n6492 = n6477 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6493 = opb | rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:7 */
  assign n6495 = n6477 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6496 = opb & rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:7 */
  assign n6498 = n6477 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  assign n6499 = {n6498, n6495, n6492, n6489, n6487, n6484, n6482, n6479};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6501 = n6480[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign n6502 = cp_res[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign n6503 = opb[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6504 = n6490[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6505 = n6493[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6506 = n6496[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  always @*
    case (n6499)
      8'b10000000: n6508 = n6506;
      8'b01000000: n6508 = n6505;
      8'b00100000: n6508 = n6504;
      8'b00010000: n6508 = n6503;
      8'b00001000: n6508 = n6485;
      8'b00000100: n6508 = n6502;
      8'b00000010: n6508 = n6501;
      8'b00000001: n6508 = 1'b0;
      default: n6508 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6510 = n6480[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign n6511 = cp_res[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign n6512 = opb[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6513 = n6490[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6514 = n6493[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6515 = n6496[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  always @*
    case (n6499)
      8'b10000000: n6518 = n6515;
      8'b01000000: n6518 = n6514;
      8'b00100000: n6518 = n6513;
      8'b00010000: n6518 = n6512;
      8'b00001000: n6518 = 31'b0000000000000000000000000000000;
      8'b00000100: n6518 = n6511;
      8'b00000010: n6518 = n6510;
      8'b00000001: n6518 = 31'b0000000000000000000000000000000;
      default: n6518 = 31'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:19 */
  assign n6522 = n6452[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:40 */
  assign n6523 = n6452[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:27 */
  assign n6524 = n6523 ? n6522 : rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:19 */
  assign n6525 = n6452[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:40 */
  assign n6526 = n6452[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:27 */
  assign n6527 = n6526 ? n6525 : rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:16 */
  assign n6528 = opa[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:43 */
  assign n6529 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:32 */
  assign n6530 = ~n6529;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:27 */
  assign n6531 = n6528 & n6530;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:58 */
  assign n6532 = {n6531, opa};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:16 */
  assign n6533 = opb[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:43 */
  assign n6534 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:32 */
  assign n6535 = ~n6534;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:27 */
  assign n6536 = n6533 & n6535;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:58 */
  assign n6537 = {n6536, opb};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:134:19 */
  assign n6538 = addsub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:47 */
  assign n6539 = opa_x - opb_x;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:79 */
  assign n6540 = n6452[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:66 */
  assign n6541 = n6540 ? n6539 : n6542;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:136:47 */
  assign n6542 = opa_x + opb_x;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:21 */
  assign n6543 = cp_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:36 */
  assign n6544 = cp_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:25 */
  assign n6545 = n6543 | n6544;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:51 */
  assign n6546 = cp_valid[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:40 */
  assign n6547 = n6545 | n6546;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:66 */
  assign n6548 = cp_valid[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:55 */
  assign n6549 = n6547 | n6548;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:81 */
  assign n6550 = cp_valid[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:70 */
  assign n6551 = n6549 | n6550;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:96 */
  assign n6552 = cp_valid[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:85 */
  assign n6553 = n6551 | n6552;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:111 */
  assign n6554 = cp_valid[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:100 */
  assign n6555 = n6553 | n6554;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:22 */
  assign n6556 = cp_result[223:192]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:38 */
  assign n6557 = cp_result[191:160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:26 */
  assign n6558 = n6556 | n6557;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:54 */
  assign n6559 = cp_result[159:128]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:42 */
  assign n6560 = n6558 | n6559;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:70 */
  assign n6561 = cp_result[127:96]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:58 */
  assign n6562 = n6560 | n6561;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:86 */
  assign n6563 = cp_result[95:64]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:74 */
  assign n6564 = n6562 | n6563;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:102 */
  assign n6565 = cp_result[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:90 */
  assign n6566 = n6564 | n6565;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:118 */
  assign n6567 = cp_result[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:106 */
  assign n6568 = n6566 | n6567;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  neorv32_cpu_alu_shifter_Bneorv32_cpu_alu_shifter_rtl_Lneorv32_5ba93c9db0cff93f52b521d7420e43f6eda2784f neorv32_cpu_alu_shifter_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n6569),
    .\ctrl_i[if_ready] (n6570),
    .\ctrl_i[if_fence] (n6571),
    .\ctrl_i[pc_cur] (n6572),
    .\ctrl_i[pc_nxt] (n6573),
    .\ctrl_i[pc_ret] (n6574),
    .\ctrl_i[rf_wb_en] (n6575),
    .\ctrl_i[rf_rs1] (n6576),
    .\ctrl_i[rf_rs2] (n6577),
    .\ctrl_i[rf_rd] (n6578),
    .\ctrl_i[rf_zero] (n6579),
    .\ctrl_i[alu_op] (n6580),
    .\ctrl_i[alu_sub] (n6581),
    .\ctrl_i[alu_opa_mux] (n6582),
    .\ctrl_i[alu_opb_mux] (n6583),
    .\ctrl_i[alu_unsigned] (n6584),
    .\ctrl_i[alu_imm] (n6585),
    .\ctrl_i[alu_cp_alu] (n6586),
    .\ctrl_i[alu_cp_cfu] (n6587),
    .\ctrl_i[alu_cp_fpu] (n6588),
    .\ctrl_i[lsu_req] (n6589),
    .\ctrl_i[lsu_rd] (n6590),
    .\ctrl_i[lsu_wr] (n6591),
    .\ctrl_i[lsu_mo_en] (n6592),
    .\ctrl_i[lsu_mi_en] (n6593),
    .\ctrl_i[lsu_priv] (n6594),
    .\ctrl_i[lsu_fence] (n6595),
    .\ctrl_i[csr_we] (n6596),
    .\ctrl_i[csr_re] (n6597),
    .\ctrl_i[csr_addr] (n6598),
    .\ctrl_i[csr_wdata] (n6599),
    .\ctrl_i[cnt_event] (n6600),
    .\ctrl_i[ir_funct3] (n6601),
    .\ctrl_i[ir_funct12] (n6602),
    .\ctrl_i[ir_opcode] (n6603),
    .\ctrl_i[ir_rvc] (n6604),
    .\ctrl_i[cpu_priv] (n6605),
    .\ctrl_i[cpu_trap] (n6606),
    .\ctrl_i[cpu_sync_exc] (n6607),
    .\ctrl_i[cpu_debug] (n6608),
    .rs1_i(rs1_i),
    .shamt_i(n6609),
    .res_o(\neorv32_cpu_alu_shifter_inst.res_o ),
    .valid_o(\neorv32_cpu_alu_shifter_inst.valid_o ));
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6569 = n6452[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6570 = n6452[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6571 = n6452[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6572 = n6452[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6573 = n6452[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6574 = n6452[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6575 = n6452[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6576 = n6452[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6577 = n6452[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6578 = n6452[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6579 = n6452[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6580 = n6452[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6581 = n6452[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6582 = n6452[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6583 = n6452[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6584 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6585 = n6452[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6586 = n6452[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6587 = n6452[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6588 = n6452[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6589 = n6452[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6590 = n6452[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6591 = n6452[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6592 = n6452[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6593 = n6452[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6594 = n6452[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6595 = n6452[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6596 = n6452[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6597 = n6452[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6598 = n6452[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6599 = n6452[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6600 = n6452[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6601 = n6452[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6602 = n6452[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6603 = n6452[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6604 = n6452[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6605 = n6452[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6606 = n6452[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6607 = n6452[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6608 = n6452[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:159:19 */
  assign n6609 = opb[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  neorv32_cpu_alu_muldiv_Bneorv32_cpu_alu_muldiv_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264 neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n6612),
    .\ctrl_i[if_ready] (n6613),
    .\ctrl_i[if_fence] (n6614),
    .\ctrl_i[pc_cur] (n6615),
    .\ctrl_i[pc_nxt] (n6616),
    .\ctrl_i[pc_ret] (n6617),
    .\ctrl_i[rf_wb_en] (n6618),
    .\ctrl_i[rf_rs1] (n6619),
    .\ctrl_i[rf_rs2] (n6620),
    .\ctrl_i[rf_rd] (n6621),
    .\ctrl_i[rf_zero] (n6622),
    .\ctrl_i[alu_op] (n6623),
    .\ctrl_i[alu_sub] (n6624),
    .\ctrl_i[alu_opa_mux] (n6625),
    .\ctrl_i[alu_opb_mux] (n6626),
    .\ctrl_i[alu_unsigned] (n6627),
    .\ctrl_i[alu_imm] (n6628),
    .\ctrl_i[alu_cp_alu] (n6629),
    .\ctrl_i[alu_cp_cfu] (n6630),
    .\ctrl_i[alu_cp_fpu] (n6631),
    .\ctrl_i[lsu_req] (n6632),
    .\ctrl_i[lsu_rd] (n6633),
    .\ctrl_i[lsu_wr] (n6634),
    .\ctrl_i[lsu_mo_en] (n6635),
    .\ctrl_i[lsu_mi_en] (n6636),
    .\ctrl_i[lsu_priv] (n6637),
    .\ctrl_i[lsu_fence] (n6638),
    .\ctrl_i[csr_we] (n6639),
    .\ctrl_i[csr_re] (n6640),
    .\ctrl_i[csr_addr] (n6641),
    .\ctrl_i[csr_wdata] (n6642),
    .\ctrl_i[cnt_event] (n6643),
    .\ctrl_i[ir_funct3] (n6644),
    .\ctrl_i[ir_funct12] (n6645),
    .\ctrl_i[ir_opcode] (n6646),
    .\ctrl_i[ir_rvc] (n6647),
    .\ctrl_i[cpu_priv] (n6648),
    .\ctrl_i[cpu_trap] (n6649),
    .\ctrl_i[cpu_sync_exc] (n6650),
    .\ctrl_i[cpu_debug] (n6651),
    .rs1_i(rs1_i),
    .rs2_i(rs2_i),
    .res_o(\neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o ),
    .valid_o(\neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o ));
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6612 = n6452[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6613 = n6452[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6614 = n6452[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6615 = n6452[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6616 = n6452[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6617 = n6452[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6618 = n6452[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6619 = n6452[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6620 = n6452[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6621 = n6452[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6622 = n6452[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6623 = n6452[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6624 = n6452[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6625 = n6452[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6626 = n6452[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6627 = n6452[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6628 = n6452[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6629 = n6452[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6630 = n6452[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6631 = n6452[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6632 = n6452[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6633 = n6452[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6634 = n6452[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6635 = n6452[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6636 = n6452[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6637 = n6452[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6638 = n6452[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6639 = n6452[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6640 = n6452[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6641 = n6452[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6642 = n6452[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6643 = n6452[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6644 = n6452[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6645 = n6452[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6646 = n6452[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6647 = n6452[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6648 = n6452[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6649 = n6452[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6650 = n6452[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6651 = n6452[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:79:10 */
  assign n6672 = {n6474, n6470};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:83:10 */
  assign n6673 = {\neorv32_cpu_alu_shifter_inst.res_o , \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o , 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:84:10 */
  assign n6674 = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o , \neorv32_cpu_alu_shifter_inst.valid_o };
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:54:5 */
  assign n6675 = {n6518, n6508};
endmodule

module neorv32_cpu_regfile_Bneorv32_cpu_regfile_rtl_Lneorv32_32_5_0
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   input  [31:0] rd_i,
   output [31:0] rs1_o,
   output [31:0] rs2_o);
  wire [261:0] n6391;
  wire rf_we;
  wire [4:0] addr;
  wire n6394;
  wire n6402;
  wire n6404;
  wire n6406;
  wire n6407;
  wire n6408;
  wire n6409;
  wire n6410;
  wire n6411;
  wire n6412;
  wire n6413;
  wire n6414;
  wire n6415;
  wire n6416;
  wire n6418;
  wire [4:0] n6419;
  wire [4:0] n6420;
  wire n6421;
  wire [4:0] n6422;
  wire [4:0] n6423;
  wire [4:0] n6433;
  reg [31:0] n6448; // mem_rd
  reg [31:0] n6450; // mem_rd
  assign rs1_o = n6450; //(module output)
  assign rs2_o = n6448; //(module output)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:28:8 */
  assign n6391 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:49:10 */
  assign rf_we = n6416; // (signal)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:50:10 */
  assign addr = n6419; // (signal)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:22 */
  assign n6394 = n6391[99]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6402 = n6391[114]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6404 = 1'b0 | n6402;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6406 = n6391[113]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6407 = n6404 | n6406;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6408 = n6391[112]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6409 = n6407 | n6408;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6410 = n6391[111]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6411 = n6409 | n6410;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6412 = n6391[110]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6413 = n6411 | n6412;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:31 */
  assign n6414 = n6394 & n6413;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:91 */
  assign n6415 = n6391[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:81 */
  assign n6416 = n6414 | n6415;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:43 */
  assign n6418 = n6391[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:30 */
  assign n6419 = n6418 ? 5'b00000 : n6422;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:21 */
  assign n6420 = n6391[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:43 */
  assign n6421 = n6391[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:59 */
  assign n6422 = n6421 ? n6420 : n6423;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:71 */
  assign n6423 = n6391[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:79:59 */
  assign n6433 = n6391[109:105]; // extract
  reg [31:0] regfile[31:0] ; // memory
  always @(posedge clk_i)
    if (1'b1)
      n6448 <= regfile[n6433];
  always @(posedge clk_i)
    if (1'b1)
      n6450 <= regfile[addr];
  always @(posedge clk_i)
    if (rf_we)
      regfile[addr] <= rd_i;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:79:25 */
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:76:19 */
endmodule

module neorv32_cpu_control_Bneorv32_cpu_control_rtl_Lneorv32_0_4276033fa0415472228fc3f7d7c8a0a76b50f4af
  (input  clk_i,
   input  rstn_i,
   output \ctrl_o[if_reset] ,
   output \ctrl_o[if_ready] ,
   output \ctrl_o[if_fence] ,
   output [31:0] \ctrl_o[pc_cur] ,
   output [31:0] \ctrl_o[pc_nxt] ,
   output [31:0] \ctrl_o[pc_ret] ,
   output \ctrl_o[rf_wb_en] ,
   output [4:0] \ctrl_o[rf_rs1] ,
   output [4:0] \ctrl_o[rf_rs2] ,
   output [4:0] \ctrl_o[rf_rd] ,
   output \ctrl_o[rf_zero] ,
   output [2:0] \ctrl_o[alu_op] ,
   output \ctrl_o[alu_sub] ,
   output \ctrl_o[alu_opa_mux] ,
   output \ctrl_o[alu_opb_mux] ,
   output \ctrl_o[alu_unsigned] ,
   output [31:0] \ctrl_o[alu_imm] ,
   output \ctrl_o[alu_cp_alu] ,
   output \ctrl_o[alu_cp_cfu] ,
   output \ctrl_o[alu_cp_fpu] ,
   output \ctrl_o[lsu_req] ,
   output \ctrl_o[lsu_rd] ,
   output \ctrl_o[lsu_wr] ,
   output \ctrl_o[lsu_mo_en] ,
   output \ctrl_o[lsu_mi_en] ,
   output \ctrl_o[lsu_priv] ,
   output \ctrl_o[lsu_fence] ,
   output \ctrl_o[csr_we] ,
   output \ctrl_o[csr_re] ,
   output [11:0] \ctrl_o[csr_addr] ,
   output [31:0] \ctrl_o[csr_wdata] ,
   output [8:0] \ctrl_o[cnt_event] ,
   output [2:0] \ctrl_o[ir_funct3] ,
   output [11:0] \ctrl_o[ir_funct12] ,
   output [6:0] \ctrl_o[ir_opcode] ,
   output [15:0] \ctrl_o[ir_rvc] ,
   output \ctrl_o[cpu_priv] ,
   output \ctrl_o[cpu_trap] ,
   output \ctrl_o[cpu_sync_exc] ,
   output \ctrl_o[cpu_debug] ,
   input  \frontend_i[valid] ,
   input  [31:0] \frontend_i[i32] ,
   input  [15:0] \frontend_i[i16] ,
   input  \frontend_i[compr] ,
   input  \frontend_i[fault] ,
   input  hwtrig_i,
   input  alu_cp_done_i,
   input  [1:0] alu_cmp_i,
   input  [31:0] alu_add_i,
   input  [31:0] rf_rs1_i,
   output [31:0] csr_rdata_o,
   input  [31:0] xcsr_rdata_i,
   input  irq_dbg_i,
   input  [2:0] irq_machine_i,
   input  [15:0] irq_fast_i,
   input  lsu_wait_i,
   input  [31:0] lsu_mar_i,
   input  [3:0] lsu_err_i);
  wire n3214;
  wire n3215;
  wire n3216;
  wire [31:0] n3217;
  wire [31:0] n3218;
  wire [31:0] n3219;
  wire n3220;
  wire [4:0] n3221;
  wire [4:0] n3222;
  wire [4:0] n3223;
  wire n3224;
  wire [2:0] n3225;
  wire n3226;
  wire n3227;
  wire n3228;
  wire n3229;
  wire [31:0] n3230;
  wire n3231;
  wire n3232;
  wire n3233;
  wire n3234;
  wire n3235;
  wire n3236;
  wire n3237;
  wire n3238;
  wire n3239;
  wire n3240;
  wire n3241;
  wire n3242;
  wire [11:0] n3243;
  wire [31:0] n3244;
  wire [8:0] n3245;
  wire [2:0] n3246;
  wire [11:0] n3247;
  wire [6:0] n3248;
  wire [15:0] n3249;
  wire n3250;
  wire n3251;
  wire n3252;
  wire n3253;
  wire [50:0] n3254;
  wire [116:0] exec;
  wire [116:0] exec_nxt;
  wire [261:0] ctrl;
  wire [261:0] ctrl_nxt;
  wire [11:0] exc_buf;
  wire exc_fire;
  wire [19:0] irq_pnd;
  wire [19:0] irq_buf;
  wire [1:0] irq_fire;
  wire env_pend;
  wire env_enter;
  wire env_exit;
  wire instr_be;
  wire instr_ma;
  wire instr_il;
  wire ecall;
  wire ebreak;
  wire [31:0] epc;
  wire [6:0] ecause;
  wire [261:0] csr;
  wire [31:0] csr_wdata;
  wire [31:0] csr_rdata;
  wire [4:0] debug_ctrl;
  wire branch_taken;
  wire [9:0] monitor_cnt;
  wire [2:0] csr_valid;
  wire illegal_cmd;
  wire [8:0] cnt_event;
  wire ebreak_trig;
  wire [6:0] trap_env;
  wire n3257;
  wire n3258;
  wire n3259;
  wire n3260;
  wire n3261;
  wire n3262;
  wire n3263;
  wire n3264;
  wire n3265;
  wire n3266;
  wire n3267;
  wire n3269;
  wire n3272;
  wire [116:0] n3282;
  wire [4:0] n3291;
  wire [6:0] n3293;
  wire [6:0] n3294;
  wire [2:0] n3295;
  wire [11:0] n3296;
  localparam [261:0] n3297 = 262'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [82:0] n3298;
  wire n3300;
  wire n3303;
  wire n3306;
  wire [20:0] n3312;
  wire [5:0] n3314;
  wire [26:0] n3315;
  wire [4:0] n3316;
  wire [31:0] n3317;
  wire n3319;
  wire n3321;
  wire [19:0] n3327;
  wire n3329;
  wire [20:0] n3330;
  wire [5:0] n3331;
  wire [26:0] n3332;
  wire [3:0] n3333;
  wire [30:0] n3334;
  wire [31:0] n3336;
  wire n3338;
  wire [19:0] n3339;
  wire [31:0] n3341;
  wire n3343;
  wire n3345;
  wire n3346;
  wire n3348;
  wire [11:0] n3354;
  wire [7:0] n3356;
  wire [19:0] n3357;
  wire n3358;
  wire [20:0] n3359;
  wire [9:0] n3360;
  wire [30:0] n3361;
  wire [31:0] n3363;
  wire n3365;
  wire n3368;
  wire n3370;
  wire [20:0] n3376;
  wire [9:0] n3378;
  wire [30:0] n3379;
  wire n3380;
  wire [31:0] n3381;
  wire [4:0] n3382;
  reg [31:0] n3383;
  wire n3386;
  wire n3387;
  wire n3388;
  wire n3389;
  wire n3392;
  wire n3394;
  wire n3395;
  wire n3397;
  wire n3398;
  wire n3400;
  wire n3401;
  wire n3402;
  wire n3405;
  wire n3407;
  wire [3:0] n3408;
  wire n3413;
  wire n3416;
  wire n3418;
  wire [31:0] n3421;
  wire n3422;
  wire n3424;
  wire n3425;
  wire n3426;
  wire n3427;
  wire n3428;
  wire [31:0] n3429;
  wire [15:0] n3430;
  wire [30:0] n3431;
  wire [31:0] n3433;
  wire [4:0] n3435;
  wire n3437;
  wire [11:0] n3438;
  wire [11:0] n3439;
  wire [84:0] n3440;
  wire [84:0] n3441;
  wire [84:0] n3442;
  wire n3443;
  wire n3445;
  wire [3:0] n3446;
  wire [3:0] n3447;
  wire [80:0] n3448;
  wire [80:0] n3449;
  wire [80:0] n3450;
  wire [11:0] n3451;
  wire n3453;
  wire n3455;
  wire n3458;
  wire n3459;
  wire n3460;
  wire [24:0] n3461;
  wire [4:0] n3462;
  wire [29:0] n3463;
  wire [31:0] n3465;
  wire [29:0] n3466;
  wire [31:0] n3468;
  wire [31:0] n3469;
  wire n3472;
  wire [30:0] n3474;
  wire [31:0] n3476;
  wire n3479;
  wire [30:0] n3480;
  wire [31:0] n3482;
  wire n3485;
  wire n3488;
  wire n3490;
  wire n3493;
  wire n3496;
  wire n3499;
  wire [5:0] n3501;
  reg [2:0] n3502;
  wire [1:0] n3503;
  wire n3505;
  wire n3507;
  wire n3508;
  wire n3509;
  wire n3510;
  wire n3511;
  wire n3512;
  wire n3514;
  wire n3515;
  wire n3516;
  wire n3517;
  wire n3519;
  wire n3520;
  wire n3522;
  wire n3523;
  wire n3524;
  wire n3526;
  wire n3528;
  wire n3529;
  wire n3531;
  wire n3533;
  wire n3534;
  wire n3535;
  wire n3537;
  wire n3539;
  wire n3540;
  wire n3541;
  wire n3543;
  wire n3545;
  wire n3546;
  wire n3547;
  wire n3549;
  wire n3551;
  wire n3552;
  wire n3553;
  wire n3555;
  wire n3557;
  wire n3558;
  wire n3559;
  wire n3561;
  wire n3563;
  wire n3564;
  wire n3565;
  wire n3566;
  wire n3567;
  wire [3:0] n3572;
  wire n3573;
  wire n3574;
  wire n3575;
  wire n3576;
  wire n3578;
  wire n3580;
  wire n3581;
  wire n3586;
  wire n3590;
  wire n3591;
  wire n3592;
  wire n3593;
  wire n3596;
  wire n3598;
  wire n3599;
  wire n3601;
  wire n3602;
  wire n3605;
  wire n3607;
  wire n3608;
  wire n3610;
  wire n3611;
  wire n3612;
  wire n3622;
  wire n3624;
  wire n3626;
  wire n3627;
  wire n3628;
  wire n3629;
  wire n3630;
  wire n3631;
  wire n3632;
  wire n3633;
  wire n3634;
  wire n3635;
  wire n3636;
  wire n3637;
  wire n3638;
  wire n3639;
  wire [3:0] n3641;
  wire n3642;
  wire n3643;
  wire n3644;
  wire n3645;
  wire n3647;
  wire n3651;
  wire n3655;
  wire n3657;
  wire n3658;
  wire n3660;
  wire n3661;
  wire n3663;
  wire n3664;
  wire n3666;
  wire n3668;
  wire n3669;
  wire n3671;
  wire n3672;
  wire [7:0] n3674;
  reg [3:0] n3675;
  wire n3676;
  reg n3677;
  wire n3678;
  reg n3679;
  wire [2:0] n3680;
  reg [2:0] n3681;
  wire n3682;
  reg n3683;
  wire n3684;
  reg n3685;
  wire n3686;
  reg n3687;
  wire n3688;
  reg n3689;
  reg n3690;
  reg n3691;
  wire n3692;
  reg n3693;
  wire n3694;
  reg n3695;
  wire n3697;
  wire n3706;
  wire n3708;
  wire n3710;
  wire n3711;
  wire n3712;
  wire n3713;
  wire n3714;
  wire [3:0] n3716;
  wire [3:0] n3717;
  wire n3719;
  wire n3721;
  wire n3723;
  wire n3724;
  wire n3725;
  wire n3728;
  wire [30:0] n3729;
  wire [31:0] n3731;
  wire [31:0] n3732;
  wire [31:0] n3733;
  wire n3735;
  wire [30:0] n3736;
  wire [31:0] n3738;
  wire n3739;
  wire n3742;
  wire n3750;
  wire n3752;
  wire n3754;
  wire n3755;
  wire n3756;
  wire n3757;
  wire n3758;
  wire [3:0] n3762;
  wire n3763;
  wire n3764;
  wire n3766;
  wire n3767;
  wire n3775;
  wire n3777;
  wire n3779;
  wire n3780;
  wire n3781;
  wire n3782;
  wire n3783;
  wire n3784;
  wire n3785;
  wire n3786;
  wire [3:0] n3788;
  wire [3:0] n3789;
  wire n3790;
  wire n3791;
  wire n3793;
  wire n3802;
  wire n3804;
  wire n3806;
  wire n3807;
  wire n3808;
  wire n3809;
  wire n3810;
  wire n3812;
  wire [2:0] n3813;
  wire n3815;
  wire n3817;
  wire n3820;
  wire n3823;
  wire [3:0] n3825;
  reg [3:0] n3826;
  reg n3829;
  reg n3832;
  wire n3834;
  wire n3836;
  wire n3838;
  wire n3839;
  wire [4:0] n3840;
  wire n3842;
  wire n3843;
  wire n3844;
  wire n3846;
  wire n3847;
  wire [3:0] n3848;
  wire n3849;
  wire n3850;
  wire n3852;
  wire n3854;
  wire n3855;
  wire n3856;
  wire n3857;
  wire n3859;
  wire n3861;
  wire n3864;
  wire n3871;
  wire n3873;
  wire n3875;
  wire n3876;
  wire n3877;
  wire n3878;
  wire n3879;
  wire n3880;
  wire n3881;
  wire n3882;
  wire n3883;
  wire n3884;
  wire n3885;
  wire n3886;
  wire n3887;
  wire n3888;
  wire n3889;
  wire n3890;
  wire n3891;
  wire n3892;
  wire n3893;
  wire n3894;
  wire n3895;
  wire n3896;
  wire n3897;
  wire n3898;
  wire n3899;
  wire n3900;
  wire n3901;
  wire n3902;
  wire n3903;
  wire n3904;
  wire n3905;
  wire n3906;
  wire n3907;
  wire n3908;
  wire n3909;
  wire n3910;
  wire n3911;
  wire n3912;
  wire n3913;
  wire [3:0] n3915;
  wire [3:0] n3916;
  wire [9:0] n3917;
  reg [3:0] n3918;
  wire [80:0] n3919;
  reg [80:0] n3920;
  wire [31:0] n3921;
  reg [31:0] n3922;
  wire n3925;
  reg n3926;
  wire n3927;
  reg n3928;
  wire [31:0] n3929;
  reg [31:0] n3930;
  wire n3931;
  reg n3932;
  wire n3933;
  reg n3934;
  wire [2:0] n3935;
  reg [2:0] n3936;
  wire n3937;
  reg n3938;
  reg n3939;
  reg n3940;
  reg [31:0] n3941;
  wire n3942;
  reg n3943;
  wire n3944;
  reg n3945;
  wire n3946;
  reg n3947;
  wire n3948;
  reg n3949;
  reg n3950;
  reg n3951;
  wire n3952;
  reg n3953;
  wire n3954;
  reg n3955;
  wire n3956;
  reg n3957;
  reg [11:0] n3958;
  wire n3961;
  wire [63:0] n3963;
  wire [14:0] n3966;
  wire [2:0] n3972;
  reg n3976;
  reg n3980;
  reg n3983;
  reg n3986;
  reg n3989;
  reg n3992;
  wire n3995;
  wire [3:0] n3997;
  wire n3999;
  wire n4000;
  wire n4002;
  wire [30:0] n4003;
  wire [31:0] n4005;
  wire [30:0] n4006;
  wire [31:0] n4008;
  wire [30:0] n4009;
  wire [31:0] n4011;
  wire n4012;
  wire n4020;
  wire n4022;
  wire n4024;
  wire n4025;
  wire n4026;
  wire n4027;
  wire n4028;
  wire n4029;
  wire n4030;
  wire n4031;
  wire n4032;
  wire n4033;
  wire n4034;
  wire n4035;
  wire n4036;
  wire n4037;
  wire n4038;
  wire n4039;
  wire n4040;
  wire n4041;
  wire [4:0] n4042;
  wire [4:0] n4043;
  wire [4:0] n4044;
  wire n4045;
  wire [2:0] n4046;
  wire n4047;
  wire n4048;
  wire n4049;
  wire n4050;
  wire [31:0] n4051;
  wire n4052;
  wire n4060;
  wire n4062;
  wire n4064;
  wire n4065;
  wire n4066;
  wire n4067;
  wire n4068;
  wire n4069;
  wire n4070;
  wire n4078;
  wire n4080;
  wire n4082;
  wire n4083;
  wire n4084;
  wire n4085;
  wire n4086;
  wire n4087;
  wire n4088;
  wire n4096;
  wire n4098;
  wire n4100;
  wire n4101;
  wire n4102;
  wire n4103;
  wire n4104;
  wire n4105;
  wire n4106;
  wire n4107;
  wire n4108;
  wire [3:0] n4110;
  wire n4112;
  wire n4113;
  wire [3:0] n4116;
  wire n4118;
  wire n4119;
  wire n4121;
  wire n4122;
  wire n4123;
  wire n4124;
  wire n4125;
  wire n4126;
  wire n4127;
  wire [11:0] n4128;
  wire [2:0] n4129;
  wire [11:0] n4130;
  wire [6:0] n4131;
  wire [15:0] n4132;
  wire n4133;
  wire n4134;
  wire [3:0] n4136;
  wire n4138;
  wire n4139;
  wire [3:0] n4142;
  wire n4144;
  wire n4145;
  wire [3:0] n4148;
  wire n4150;
  wire n4151;
  wire n4152;
  wire n4153;
  wire [3:0] n4156;
  wire n4158;
  wire n4159;
  wire n4160;
  wire n4161;
  wire n4162;
  wire [3:0] n4165;
  wire n4167;
  wire n4168;
  wire n4171;
  wire n4172;
  wire [3:0] n4173;
  wire n4175;
  wire n4176;
  wire n4177;
  wire n4180;
  wire [4:0] n4181;
  wire n4183;
  wire n4184;
  wire n4185;
  wire n4188;
  wire n4189;
  wire n4190;
  wire n4191;
  wire n4194;
  wire n4195;
  wire n4196;
  wire n4197;
  wire [11:0] n4200;
  wire n4204;
  wire n4206;
  wire n4207;
  wire n4209;
  wire n4210;
  wire n4213;
  wire n4215;
  wire n4216;
  wire n4218;
  wire n4219;
  wire n4221;
  wire n4222;
  wire n4224;
  wire n4225;
  wire n4227;
  wire n4228;
  wire n4230;
  wire n4231;
  wire n4233;
  wire n4234;
  wire n4236;
  wire n4237;
  wire n4239;
  wire n4240;
  wire n4242;
  wire n4243;
  wire n4245;
  wire n4246;
  wire n4248;
  wire n4249;
  wire n4251;
  wire n4252;
  wire n4254;
  wire n4255;
  wire n4257;
  wire n4258;
  wire n4260;
  wire n4261;
  wire n4263;
  wire n4264;
  wire n4268;
  wire n4270;
  wire n4271;
  wire n4273;
  wire n4274;
  wire n4278;
  wire n4280;
  wire n4281;
  wire n4283;
  wire n4284;
  wire n4286;
  wire n4287;
  wire n4289;
  wire n4290;
  wire n4292;
  wire n4293;
  wire n4295;
  wire n4296;
  wire n4298;
  wire n4299;
  wire n4301;
  wire n4302;
  wire n4304;
  wire n4305;
  wire n4307;
  wire n4308;
  wire n4310;
  wire n4311;
  wire n4313;
  wire n4314;
  wire n4316;
  wire n4317;
  wire n4319;
  wire n4320;
  wire n4322;
  wire n4323;
  wire n4325;
  wire n4326;
  wire n4328;
  wire n4329;
  wire n4331;
  wire n4332;
  wire n4334;
  wire n4335;
  wire n4339;
  wire n4341;
  wire n4342;
  wire n4344;
  wire n4345;
  wire n4347;
  wire n4348;
  wire n4350;
  wire n4351;
  wire n4353;
  wire n4354;
  wire n4356;
  wire n4357;
  wire n4359;
  wire n4360;
  wire n4362;
  wire n4363;
  wire n4365;
  wire n4366;
  wire n4368;
  wire n4369;
  wire n4371;
  wire n4372;
  wire n4374;
  wire n4375;
  wire n4377;
  wire n4378;
  wire n4380;
  wire n4381;
  wire n4383;
  wire n4384;
  wire n4386;
  wire n4387;
  wire n4389;
  wire n4390;
  wire n4392;
  wire n4393;
  wire n4395;
  wire n4396;
  wire n4398;
  wire n4399;
  wire n4401;
  wire n4402;
  wire n4404;
  wire n4405;
  wire n4407;
  wire n4408;
  wire n4410;
  wire n4411;
  wire n4413;
  wire n4414;
  wire n4416;
  wire n4417;
  wire n4419;
  wire n4420;
  wire n4422;
  wire n4423;
  wire n4425;
  wire n4426;
  wire n4428;
  wire n4429;
  wire n4431;
  wire n4432;
  wire n4434;
  wire n4435;
  wire n4437;
  wire n4438;
  wire n4440;
  wire n4441;
  wire n4443;
  wire n4444;
  wire n4446;
  wire n4447;
  wire n4449;
  wire n4450;
  wire n4452;
  wire n4453;
  wire n4455;
  wire n4456;
  wire n4458;
  wire n4459;
  wire n4461;
  wire n4462;
  wire n4464;
  wire n4465;
  wire n4467;
  wire n4468;
  wire n4470;
  wire n4471;
  wire n4473;
  wire n4474;
  wire n4476;
  wire n4477;
  wire n4479;
  wire n4480;
  wire n4482;
  wire n4483;
  wire n4485;
  wire n4486;
  wire n4488;
  wire n4489;
  wire n4491;
  wire n4492;
  wire n4494;
  wire n4495;
  wire n4497;
  wire n4498;
  wire n4500;
  wire n4501;
  wire n4503;
  wire n4504;
  wire n4506;
  wire n4507;
  wire n4509;
  wire n4510;
  wire n4512;
  wire n4513;
  wire n4515;
  wire n4516;
  wire n4518;
  wire n4519;
  wire n4521;
  wire n4522;
  wire n4524;
  wire n4525;
  wire n4527;
  wire n4528;
  wire n4530;
  wire n4531;
  wire n4533;
  wire n4534;
  wire n4536;
  wire n4537;
  wire n4539;
  wire n4540;
  wire n4542;
  wire n4543;
  wire n4545;
  wire n4546;
  wire n4548;
  wire n4549;
  wire n4551;
  wire n4552;
  wire n4554;
  wire n4555;
  wire n4557;
  wire n4558;
  wire n4560;
  wire n4561;
  wire n4563;
  wire n4564;
  wire n4566;
  wire n4567;
  wire n4569;
  wire n4570;
  wire n4572;
  wire n4573;
  wire n4575;
  wire n4576;
  wire n4578;
  wire n4579;
  wire n4581;
  wire n4582;
  wire n4584;
  wire n4585;
  wire n4587;
  wire n4588;
  wire n4590;
  wire n4591;
  wire n4593;
  wire n4594;
  wire n4596;
  wire n4597;
  wire n4599;
  wire n4600;
  wire n4602;
  wire n4603;
  wire n4605;
  wire n4606;
  wire n4608;
  wire n4609;
  wire n4611;
  wire n4612;
  wire n4614;
  wire n4615;
  wire n4617;
  wire n4618;
  wire n4620;
  wire n4621;
  wire n4623;
  wire n4624;
  wire n4626;
  wire n4627;
  wire n4629;
  wire n4630;
  wire n4632;
  wire n4633;
  wire n4635;
  wire n4636;
  wire n4638;
  wire n4639;
  wire n4641;
  wire n4642;
  wire n4644;
  wire n4645;
  wire n4647;
  wire n4648;
  wire n4650;
  wire n4651;
  wire n4653;
  wire n4654;
  wire n4656;
  wire n4657;
  wire n4659;
  wire n4660;
  wire n4662;
  wire n4663;
  wire n4665;
  wire n4666;
  wire n4668;
  wire n4669;
  wire n4671;
  wire n4672;
  wire n4674;
  wire n4675;
  wire n4677;
  wire n4678;
  wire n4680;
  wire n4681;
  wire n4683;
  wire n4684;
  wire n4686;
  wire n4687;
  wire n4689;
  wire n4690;
  wire n4692;
  wire n4693;
  wire n4695;
  wire n4696;
  wire n4698;
  wire n4699;
  wire n4701;
  wire n4702;
  wire n4704;
  wire n4705;
  wire n4707;
  wire n4708;
  wire n4710;
  wire n4711;
  wire n4713;
  wire n4714;
  wire n4716;
  wire n4717;
  wire n4719;
  wire n4720;
  wire n4722;
  wire n4723;
  wire n4725;
  wire n4726;
  wire n4728;
  wire n4729;
  wire n4731;
  wire n4732;
  wire n4734;
  wire n4735;
  wire n4737;
  wire n4738;
  wire n4740;
  wire n4741;
  wire n4743;
  wire n4744;
  wire n4746;
  wire n4747;
  wire n4749;
  wire n4750;
  wire n4752;
  wire n4753;
  wire n4755;
  wire n4756;
  wire n4758;
  wire n4759;
  wire n4761;
  wire n4762;
  wire n4764;
  wire n4765;
  wire n4767;
  wire n4768;
  wire n4770;
  wire n4771;
  wire n4775;
  wire n4777;
  wire n4778;
  wire n4780;
  wire n4781;
  wire n4783;
  wire n4784;
  wire n4786;
  wire n4787;
  wire n4789;
  wire n4790;
  wire n4792;
  wire n4793;
  wire n4795;
  wire n4796;
  wire n4798;
  wire n4799;
  wire n4801;
  wire n4802;
  wire n4806;
  wire n4808;
  wire n4809;
  wire n4811;
  wire n4812;
  wire n4814;
  wire n4815;
  wire n4819;
  wire n4821;
  wire n4822;
  wire n4824;
  wire n4825;
  wire n4829;
  wire n4831;
  wire n4832;
  wire n4834;
  wire n4835;
  wire n4837;
  wire n4838;
  wire n4840;
  wire n4841;
  wire [8:0] n4843;
  reg n4844;
  wire [1:0] n4845;
  wire n4847;
  wire [2:0] n4848;
  wire n4850;
  wire [2:0] n4851;
  wire n4853;
  wire n4854;
  wire [4:0] n4855;
  wire n4857;
  wire n4858;
  wire n4859;
  wire n4862;
  wire [1:0] n4866;
  wire n4868;
  wire n4869;
  wire n4870;
  wire n4871;
  wire n4874;
  wire [6:0] n4877;
  wire n4879;
  wire n4881;
  wire n4882;
  wire n4884;
  wire n4885;
  wire [2:0] n4886;
  wire n4888;
  wire n4891;
  wire n4893;
  wire [1:0] n4894;
  wire n4896;
  wire n4898;
  wire n4901;
  wire n4903;
  wire [2:0] n4904;
  wire n4906;
  wire n4908;
  wire n4909;
  wire n4911;
  wire n4912;
  wire n4914;
  wire n4915;
  wire n4917;
  wire n4918;
  reg n4921;
  wire n4923;
  wire [2:0] n4924;
  wire n4926;
  wire n4928;
  wire n4929;
  wire n4931;
  wire n4932;
  reg n4935;
  wire n4937;
  wire n4977;
  wire n4979;
  wire n4981;
  wire n4982;
  wire n4984;
  wire n4985;
  wire n4987;
  wire n4988;
  wire n4990;
  wire n4991;
  wire n4993;
  wire n4994;
  wire n4996;
  wire n4997;
  wire [1:0] n4998;
  wire n5000;
  wire n5003;
  wire n5005;
  wire [2:0] n5006;
  wire n5008;
  wire [4:0] n5009;
  wire n5011;
  wire [4:0] n5012;
  wire n5014;
  wire n5015;
  wire [11:0] n5016;
  wire n5018;
  wire n5020;
  wire n5021;
  wire n5022;
  wire n5023;
  wire n5024;
  wire n5026;
  wire n5027;
  wire n5028;
  wire n5030;
  wire n5031;
  wire n5032;
  wire n5033;
  wire n5034;
  wire n5036;
  wire [4:0] n5037;
  reg n5041;
  wire n5043;
  wire [2:0] n5044;
  wire n5046;
  wire n5048;
  wire n5051;
  wire n5053;
  wire n5054;
  wire n5056;
  wire [8:0] n5057;
  reg n5062;
  wire n5066;
  wire [3:0] n5068;
  wire n5070;
  wire [9:0] n5072;
  wire [9:0] n5074;
  wire [3:0] n5080;
  wire n5082;
  wire [3:0] n5083;
  wire n5085;
  wire n5086;
  wire n5087;
  wire n5088;
  wire n5089;
  wire n5090;
  wire n5093;
  wire n5095;
  wire [16:0] n5096;
  wire [19:0] n5097;
  wire n5098;
  wire n5099;
  wire n5100;
  wire n5101;
  wire n5102;
  wire n5103;
  wire n5104;
  wire n5105;
  wire n5106;
  wire n5107;
  wire n5108;
  wire n5109;
  wire n5110;
  wire n5111;
  wire n5112;
  wire n5113;
  wire n5114;
  wire n5115;
  wire n5116;
  wire n5117;
  wire n5118;
  wire n5119;
  wire n5120;
  wire n5121;
  wire n5122;
  wire n5123;
  wire n5124;
  wire n5125;
  wire n5126;
  wire n5127;
  wire n5128;
  wire n5129;
  wire n5130;
  wire n5131;
  wire n5132;
  wire n5133;
  wire n5134;
  wire n5135;
  wire n5136;
  wire n5137;
  wire n5138;
  wire n5139;
  wire n5140;
  wire n5141;
  wire n5142;
  wire n5143;
  wire n5144;
  wire n5145;
  wire n5146;
  wire n5147;
  wire n5148;
  wire n5149;
  wire n5150;
  wire n5151;
  wire n5152;
  wire n5153;
  wire n5154;
  wire n5155;
  wire n5156;
  wire n5157;
  wire n5158;
  wire n5159;
  wire n5160;
  wire n5161;
  wire n5162;
  wire n5163;
  wire n5164;
  wire n5165;
  wire n5166;
  wire n5167;
  wire n5168;
  wire n5169;
  wire n5170;
  wire n5171;
  wire n5172;
  wire n5173;
  wire n5174;
  wire n5175;
  wire n5176;
  wire n5177;
  wire n5178;
  wire n5179;
  wire n5180;
  wire n5181;
  wire n5182;
  wire n5183;
  wire n5184;
  wire n5185;
  wire n5186;
  wire n5187;
  wire n5188;
  wire n5189;
  wire n5190;
  wire n5191;
  wire n5192;
  wire n5193;
  wire n5194;
  wire n5195;
  wire n5196;
  wire n5197;
  wire n5198;
  wire n5199;
  wire n5200;
  wire n5201;
  wire n5202;
  wire n5203;
  wire n5204;
  wire n5205;
  wire n5206;
  wire n5207;
  wire n5208;
  wire n5209;
  wire n5210;
  wire n5211;
  wire n5212;
  wire n5213;
  wire n5214;
  wire n5215;
  wire n5216;
  wire n5217;
  wire n5218;
  wire n5219;
  wire n5220;
  wire n5221;
  wire n5222;
  wire n5223;
  wire n5224;
  wire n5225;
  wire n5226;
  wire n5227;
  wire n5228;
  wire n5229;
  wire n5230;
  wire n5231;
  wire n5232;
  wire n5233;
  wire n5234;
  wire n5235;
  wire n5236;
  wire n5237;
  wire n5238;
  wire n5239;
  wire n5240;
  wire n5241;
  wire n5242;
  wire n5243;
  wire n5244;
  wire n5245;
  wire n5246;
  wire n5247;
  wire n5248;
  wire n5249;
  wire n5250;
  wire n5251;
  wire n5252;
  wire n5253;
  wire n5254;
  wire n5255;
  wire n5256;
  wire n5257;
  wire n5258;
  wire n5259;
  wire n5260;
  wire n5261;
  wire n5262;
  wire n5263;
  wire n5264;
  wire n5265;
  wire n5266;
  wire n5267;
  wire n5268;
  wire n5269;
  wire n5270;
  wire [11:0] n5271;
  wire [19:0] n5274;
  wire n5283;
  wire n5284;
  wire n5285;
  wire n5286;
  wire n5287;
  wire n5288;
  wire n5289;
  wire n5290;
  wire n5291;
  wire n5292;
  wire n5293;
  wire n5294;
  wire n5295;
  wire n5296;
  wire n5297;
  wire n5298;
  wire n5299;
  wire n5300;
  wire n5302;
  wire n5310;
  wire n5312;
  wire n5314;
  wire n5315;
  wire n5316;
  wire n5318;
  wire n5320;
  wire n5331;
  wire n5333;
  wire n5335;
  wire n5336;
  wire n5337;
  wire n5338;
  wire n5339;
  wire n5340;
  wire n5341;
  wire n5342;
  wire n5343;
  wire n5344;
  wire n5345;
  wire n5346;
  wire n5347;
  wire n5348;
  wire n5349;
  wire n5350;
  wire n5351;
  wire n5352;
  wire n5353;
  wire n5354;
  wire n5355;
  wire n5356;
  wire [3:0] n5358;
  wire n5360;
  wire [3:0] n5361;
  wire n5363;
  wire n5364;
  wire n5372;
  wire n5374;
  wire n5376;
  wire n5377;
  wire n5378;
  wire n5379;
  wire n5380;
  wire n5381;
  wire n5382;
  wire n5383;
  wire n5384;
  wire n5385;
  wire n5386;
  wire n5387;
  wire n5388;
  wire n5389;
  wire n5390;
  wire n5391;
  wire n5392;
  wire n5393;
  wire n5394;
  wire n5395;
  wire n5396;
  wire n5397;
  wire n5398;
  wire n5399;
  wire n5400;
  wire n5401;
  wire n5402;
  wire n5403;
  wire n5404;
  wire n5405;
  wire n5406;
  wire n5407;
  wire n5408;
  wire n5409;
  wire n5410;
  wire n5411;
  wire n5412;
  wire n5413;
  wire n5414;
  wire n5415;
  wire n5416;
  wire n5417;
  wire n5418;
  wire n5419;
  wire n5420;
  wire n5421;
  wire n5422;
  wire n5423;
  wire n5424;
  wire n5426;
  wire n5428;
  wire [6:0] n5429;
  wire n5431;
  wire [6:0] n5432;
  wire n5434;
  wire [6:0] n5435;
  wire n5436;
  wire [6:0] n5437;
  wire n5439;
  wire [6:0] n5440;
  wire n5442;
  wire [6:0] n5443;
  wire n5445;
  wire [6:0] n5446;
  wire n5448;
  wire [6:0] n5449;
  wire n5451;
  wire [6:0] n5452;
  wire n5454;
  wire [6:0] n5455;
  wire n5457;
  wire [6:0] n5458;
  wire n5460;
  wire [6:0] n5461;
  wire n5463;
  wire [6:0] n5464;
  wire n5466;
  wire [6:0] n5467;
  wire n5469;
  wire [6:0] n5470;
  wire n5472;
  wire [6:0] n5473;
  wire n5475;
  wire [6:0] n5476;
  wire n5478;
  wire [6:0] n5479;
  wire n5481;
  wire [6:0] n5482;
  wire n5484;
  wire [6:0] n5485;
  wire n5487;
  wire [6:0] n5488;
  wire n5490;
  wire [6:0] n5491;
  wire n5493;
  wire [6:0] n5494;
  wire n5496;
  wire [6:0] n5497;
  wire n5499;
  wire [6:0] n5500;
  wire n5502;
  wire [6:0] n5503;
  wire n5505;
  wire [6:0] n5506;
  wire n5508;
  wire [6:0] n5509;
  wire n5511;
  wire [6:0] n5512;
  wire n5514;
  wire [6:0] n5515;
  wire n5517;
  wire [6:0] n5518;
  wire n5520;
  wire [5:0] n5522;
  wire n5523;
  wire [6:0] n5524;
  wire [31:0] n5525;
  wire n5526;
  wire [31:0] n5527;
  wire [31:0] n5528;
  wire n5556;
  wire n5557;
  wire [4:0] n5559;
  wire [31:0] n5561;
  wire [31:0] n5562;
  wire [1:0] n5563;
  wire [31:0] n5564;
  wire n5566;
  wire [31:0] n5567;
  wire [31:0] n5568;
  wire n5570;
  wire [1:0] n5571;
  reg [31:0] n5572;
  wire n5575;
  wire n5600;
  wire [11:0] n5601;
  wire n5602;
  wire n5603;
  wire n5611;
  wire n5613;
  wire n5615;
  wire n5616;
  wire n5617;
  wire n5618;
  wire n5620;
  wire n5621;
  wire n5622;
  wire n5623;
  wire [15:0] n5624;
  wire n5626;
  wire [29:0] n5627;
  wire [30:0] n5629;
  wire n5630;
  wire [31:0] n5631;
  wire n5633;
  wire n5635;
  wire n5637;
  wire [30:0] n5638;
  wire [31:0] n5640;
  wire n5642;
  wire n5643;
  wire [4:0] n5644;
  wire [5:0] n5645;
  wire n5647;
  wire n5649;
  wire n5650;
  wire n5651;
  wire n5652;
  wire n5660;
  wire n5662;
  wire n5664;
  wire n5665;
  wire n5667;
  wire n5672;
  wire n5674;
  wire [10:0] n5675;
  wire n5676;
  reg n5677;
  wire n5678;
  reg n5679;
  wire n5680;
  reg n5681;
  wire n5682;
  reg n5683;
  wire n5684;
  reg n5685;
  wire n5686;
  reg n5687;
  wire n5688;
  reg n5689;
  wire n5690;
  reg n5691;
  wire [15:0] n5692;
  reg [15:0] n5693;
  wire [31:0] n5694;
  reg [31:0] n5695;
  wire [5:0] n5696;
  reg [5:0] n5697;
  wire [31:0] n5698;
  reg [31:0] n5699;
  wire [31:0] n5700;
  reg [31:0] n5701;
  wire [31:0] n5702;
  reg [31:0] n5703;
  wire [31:0] n5704;
  reg [31:0] n5705;
  wire n5706;
  reg n5707;
  wire n5708;
  reg n5709;
  wire n5710;
  reg n5711;
  wire n5712;
  reg n5713;
  wire n5718;
  wire n5719;
  wire n5721;
  wire n5723;
  wire n5724;
  wire [4:0] n5725;
  wire [5:0] n5726;
  wire [30:0] n5727;
  wire [31:0] n5729;
  wire n5730;
  wire n5731;
  wire n5732;
  wire [1:0] n5733;
  wire n5735;
  wire n5736;
  wire n5738;
  wire [15:0] n5739;
  wire [31:0] n5741;
  wire [31:0] n5742;
  wire [31:0] n5743;
  wire [31:0] n5745;
  wire [31:0] n5746;
  wire [31:0] n5748;
  wire [3:0] n5749;
  wire [37:0] n5750;
  wire [3:0] n5751;
  wire [3:0] n5752;
  wire [37:0] n5753;
  wire [37:0] n5754;
  wire [31:0] n5755;
  wire [31:0] n5756;
  wire n5757;
  wire n5758;
  wire n5760;
  wire n5762;
  wire n5763;
  wire n5765;
  wire [4:0] n5767;
  wire [4:0] n5768;
  wire [4:0] n5769;
  wire [3:0] n5770;
  wire [3:0] n5771;
  wire n5772;
  wire n5773;
  wire n5774;
  wire n5776;
  wire n5778;
  wire [4:0] n5779;
  wire [193:0] n5780;
  wire n5782;
  wire n5783;
  wire n5784;
  wire [3:0] n5785;
  wire [3:0] n5786;
  wire [3:0] n5787;
  wire [19:0] n5788;
  wire [19:0] n5789;
  wire [19:0] n5790;
  wire [37:0] n5791;
  wire [37:0] n5792;
  wire [31:0] n5793;
  wire [31:0] n5794;
  wire [31:0] n5795;
  wire [31:0] n5796;
  wire [31:0] n5797;
  wire [67:0] n5798;
  wire [67:0] n5799;
  wire [67:0] n5800;
  wire [31:0] n5805;
  wire [261:0] n5819;
  wire [261:0] n5821;
  wire n5825;
  wire n5827;
  wire [11:0] n5828;
  wire n5829;
  wire n5830;
  wire n5831;
  wire n5832;
  wire n5833;
  wire n5834;
  wire n5837;
  wire n5839;
  localparam [1:0] n5855 = 2'b01;
  wire n5857;
  wire n5858;
  wire n5859;
  wire n5860;
  wire [15:0] n5861;
  wire n5863;
  wire [31:0] n5864;
  wire n5866;
  wire n5868;
  wire [31:0] n5869;
  wire n5871;
  wire [30:0] n5872;
  wire [31:0] n5874;
  wire n5876;
  wire n5877;
  wire [4:0] n5878;
  wire n5880;
  wire [31:0] n5881;
  wire n5883;
  wire n5884;
  wire n5885;
  wire n5886;
  wire [15:0] n5887;
  wire n5889;
  wire n5891;
  wire n5893;
  wire n5895;
  wire n5897;
  wire n5899;
  wire n5901;
  wire n5903;
  wire n5967;
  wire n5973;
  wire [18:0] n5974;
  wire n5975;
  wire n5976;
  wire n5977;
  wire n5978;
  wire n5979;
  wire n5984;
  reg n5986;
  wire n5987;
  wire n5988;
  wire n5989;
  wire n5990;
  wire n5991;
  wire n5996;
  reg n5998;
  wire n5999;
  wire n6000;
  wire n6001;
  wire n6002;
  wire n6003;
  wire n6008;
  reg n6010;
  wire n6011;
  wire n6012;
  wire n6013;
  wire n6014;
  wire n6015;
  wire n6020;
  reg n6022;
  wire n6023;
  wire n6024;
  wire n6025;
  wire n6026;
  wire n6027;
  wire n6032;
  reg n6034;
  wire n6035;
  wire n6036;
  wire n6037;
  wire n6038;
  wire n6043;
  reg n6045;
  wire n6046;
  wire n6047;
  wire n6048;
  wire n6049;
  wire n6054;
  reg n6056;
  wire n6057;
  wire n6058;
  wire n6059;
  wire n6060;
  wire n6065;
  reg n6067;
  wire n6068;
  wire n6069;
  wire n6070;
  wire n6071;
  wire n6076;
  reg n6078;
  wire n6079;
  wire n6080;
  wire n6081;
  wire n6082;
  wire n6087;
  reg n6089;
  wire n6090;
  wire n6091;
  wire n6092;
  wire n6093;
  wire n6098;
  reg n6100;
  wire n6101;
  wire n6102;
  wire n6103;
  wire n6104;
  wire n6109;
  reg n6111;
  wire n6112;
  wire n6113;
  wire n6114;
  wire n6115;
  wire n6120;
  reg n6122;
  wire n6123;
  wire n6124;
  wire n6125;
  wire n6126;
  wire n6131;
  reg n6133;
  wire n6134;
  wire n6135;
  wire n6136;
  wire n6137;
  wire n6142;
  reg n6144;
  wire n6145;
  wire n6146;
  wire n6147;
  wire n6148;
  wire n6153;
  reg n6155;
  wire n6156;
  wire n6157;
  wire n6158;
  wire n6159;
  wire n6160;
  wire n6161;
  wire n6166;
  reg n6168;
  wire n6169;
  wire n6170;
  wire n6171;
  wire n6172;
  wire n6173;
  wire n6174;
  wire n6179;
  reg n6181;
  wire n6182;
  wire n6183;
  wire n6184;
  wire n6185;
  wire n6186;
  wire n6187;
  wire n6192;
  reg n6194;
  wire n6195;
  wire n6196;
  wire n6197;
  wire n6198;
  wire n6199;
  wire n6200;
  wire n6205;
  reg n6207;
  wire n6208;
  wire n6209;
  wire n6210;
  wire n6211;
  wire n6212;
  wire n6213;
  wire n6218;
  reg n6220;
  wire n6221;
  wire n6222;
  wire n6223;
  wire n6224;
  wire n6225;
  wire n6226;
  wire n6231;
  reg n6233;
  wire n6234;
  wire n6235;
  wire n6236;
  wire n6237;
  wire n6238;
  wire n6239;
  wire n6244;
  reg n6246;
  wire n6247;
  wire n6248;
  wire n6249;
  wire n6250;
  wire n6251;
  wire n6252;
  wire n6257;
  reg n6259;
  wire n6260;
  wire n6261;
  wire n6262;
  wire n6263;
  wire n6264;
  wire n6265;
  wire n6270;
  reg n6272;
  wire n6273;
  wire n6274;
  wire n6275;
  wire n6276;
  wire n6277;
  wire n6278;
  wire n6283;
  reg n6285;
  wire n6286;
  wire n6287;
  wire n6288;
  wire n6289;
  wire n6290;
  wire n6291;
  wire n6296;
  reg n6298;
  wire n6299;
  wire n6300;
  wire n6301;
  wire n6302;
  wire n6303;
  wire n6304;
  wire n6309;
  reg n6311;
  wire n6312;
  wire n6313;
  wire n6314;
  wire n6315;
  wire n6316;
  wire n6317;
  wire n6322;
  reg n6324;
  wire n6325;
  wire n6326;
  wire n6327;
  wire n6328;
  wire n6329;
  wire n6330;
  wire n6335;
  reg n6337;
  wire n6338;
  wire n6339;
  wire n6340;
  wire n6341;
  wire n6342;
  wire n6343;
  wire n6344;
  wire n6349;
  reg n6351;
  wire n6352;
  wire n6353;
  wire n6354;
  wire n6355;
  wire n6356;
  wire n6357;
  wire n6358;
  wire n6363;
  reg n6365;
  wire [31:0] n6366;
  wire [31:0] n6368;
  wire [116:0] n6374;
  wire [261:0] n6375;
  wire [1:0] n6376;
  wire [4:0] n6378;
  wire [2:0] n6379;
  wire [8:0] n6380;
  wire [261:0] n6381;
  reg [116:0] n6382;
  reg [261:0] n6383;
  reg [11:0] n6384;
  reg [19:0] n6385;
  reg [19:0] n6386;
  reg n6387;
  reg [261:0] n6388;
  reg [31:0] n6389;
  reg [9:0] n6390;
  assign \ctrl_o[if_reset]  = n3214; //(module output)
  assign \ctrl_o[if_ready]  = n3215; //(module output)
  assign \ctrl_o[if_fence]  = n3216; //(module output)
  assign \ctrl_o[pc_cur]  = n3217; //(module output)
  assign \ctrl_o[pc_nxt]  = n3218; //(module output)
  assign \ctrl_o[pc_ret]  = n3219; //(module output)
  assign \ctrl_o[rf_wb_en]  = n3220; //(module output)
  assign \ctrl_o[rf_rs1]  = n3221; //(module output)
  assign \ctrl_o[rf_rs2]  = n3222; //(module output)
  assign \ctrl_o[rf_rd]  = n3223; //(module output)
  assign \ctrl_o[rf_zero]  = n3224; //(module output)
  assign \ctrl_o[alu_op]  = n3225; //(module output)
  assign \ctrl_o[alu_sub]  = n3226; //(module output)
  assign \ctrl_o[alu_opa_mux]  = n3227; //(module output)
  assign \ctrl_o[alu_opb_mux]  = n3228; //(module output)
  assign \ctrl_o[alu_unsigned]  = n3229; //(module output)
  assign \ctrl_o[alu_imm]  = n3230; //(module output)
  assign \ctrl_o[alu_cp_alu]  = n3231; //(module output)
  assign \ctrl_o[alu_cp_cfu]  = n3232; //(module output)
  assign \ctrl_o[alu_cp_fpu]  = n3233; //(module output)
  assign \ctrl_o[lsu_req]  = n3234; //(module output)
  assign \ctrl_o[lsu_rd]  = n3235; //(module output)
  assign \ctrl_o[lsu_wr]  = n3236; //(module output)
  assign \ctrl_o[lsu_mo_en]  = n3237; //(module output)
  assign \ctrl_o[lsu_mi_en]  = n3238; //(module output)
  assign \ctrl_o[lsu_priv]  = n3239; //(module output)
  assign \ctrl_o[lsu_fence]  = n3240; //(module output)
  assign \ctrl_o[csr_we]  = n3241; //(module output)
  assign \ctrl_o[csr_re]  = n3242; //(module output)
  assign \ctrl_o[csr_addr]  = n3243; //(module output)
  assign \ctrl_o[csr_wdata]  = n3244; //(module output)
  assign \ctrl_o[cnt_event]  = n3245; //(module output)
  assign \ctrl_o[ir_funct3]  = n3246; //(module output)
  assign \ctrl_o[ir_funct12]  = n3247; //(module output)
  assign \ctrl_o[ir_opcode]  = n3248; //(module output)
  assign \ctrl_o[ir_rvc]  = n3249; //(module output)
  assign \ctrl_o[cpu_priv]  = n3250; //(module output)
  assign \ctrl_o[cpu_trap]  = n3251; //(module output)
  assign \ctrl_o[cpu_sync_exc]  = n3252; //(module output)
  assign \ctrl_o[cpu_debug]  = n3253; //(module output)
  assign csr_rdata_o = csr_rdata; //(module output)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3214 = n6381[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3215 = n6381[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3216 = n6381[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3217 = n6381[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3218 = n6381[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3219 = n6381[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3220 = n6381[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3221 = n6381[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3222 = n6381[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3223 = n6381[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3224 = n6381[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3225 = n6381[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3226 = n6381[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3227 = n6381[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3228 = n6381[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3229 = n6381[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3230 = n6381[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3231 = n6381[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3232 = n6381[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3233 = n6381[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3234 = n6381[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3235 = n6381[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3236 = n6381[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3237 = n6381[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3238 = n6381[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3239 = n6381[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3240 = n6381[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3241 = n6381[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3242 = n6381[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3243 = n6381[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3244 = n6381[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3245 = n6381[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3246 = n6381[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3247 = n6381[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3248 = n6381[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3249 = n6381[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3250 = n6381[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3251 = n6381[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3252 = n6381[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3253 = n6381[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3254 = {\frontend_i[fault] , \frontend_i[compr] , \frontend_i[i16] , \frontend_i[i32] , \frontend_i[valid] };
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:10 */
  assign exec = n6382; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign exec_nxt = n6374; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:10 */
  assign ctrl = n6383; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign ctrl_nxt = n6375; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:110:10 */
  assign exc_buf = n6384; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:111:10 */
  assign exc_fire = n5356; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:112:10 */
  assign irq_pnd = n6385; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:113:10 */
  assign irq_buf = n6386; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:114:10 */
  assign irq_fire = n6376; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:115:10 */
  assign env_pend = n6387; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:116:10 */
  assign env_enter = n3976; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:117:10 */
  assign env_exit = n3980; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:118:10 */
  assign instr_be = n3983; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:119:10 */
  assign instr_ma = n3986; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:120:10 */
  assign instr_il = n5090; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:121:10 */
  assign ecall = n3989; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:122:10 */
  assign ebreak = n3992; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:123:10 */
  assign epc = n5527; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:124:10 */
  assign ecause = n5429; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign csr = n6388; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:153:10 */
  assign csr_wdata = n5572; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:153:21 */
  assign csr_rdata = n6389; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:159:10 */
  assign debug_ctrl = n6378; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:162:10 */
  assign branch_taken = n3269; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:163:10 */
  assign monitor_cnt = n6390; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:164:10 */
  assign csr_valid = n6379; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:165:10 */
  assign illegal_cmd = n5062; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:166:10 */
  assign cnt_event = n6380; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:167:10 */
  assign ebreak_trig = n5300; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:168:10 */
  assign trap_env = n5524; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:16 */
  assign n3257 = exec[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:39 */
  assign n3258 = ~n3257;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:18 */
  assign n3259 = exec[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:39 */
  assign n3260 = ~n3259;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:34 */
  assign n3261 = alu_cmp_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:49 */
  assign n3262 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:38 */
  assign n3263 = n3261 ^ n3262;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:34 */
  assign n3264 = alu_cmp_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:49 */
  assign n3265 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:38 */
  assign n3266 = n3264 ^ n3265;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:7 */
  assign n3267 = n3260 ? n3263 : n3266;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:5 */
  assign n3269 = n3258 ? n3267 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:196:16 */
  assign n3272 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:196:5 */
  assign n3282 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 1'b0, 16'b0000000000000000, 32'b00000000000000000000000000000000, 4'b0000};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:220:24 */
  assign n3291 = exec[10:6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:220:73 */
  assign n3293 = {n3291, 2'b11};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:221:24 */
  assign n3294 = exec[35:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:222:24 */
  assign n3295 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:233:31 */
  assign n3296 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3298 = n3297[261:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:234:31 */
  assign n3300 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:235:31 */
  assign n3303 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:70 */
  assign n3306 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3312 = {n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306, n3306};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:89 */
  assign n3314 = exec[34:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:80 */
  assign n3315 = {n3312, n3314};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:113 */
  assign n3316 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:104 */
  assign n3317 = {n3315, n3316};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:7 */
  assign n3319 = n3293 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:70 */
  assign n3321 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3327 = {n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321, n3321};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:89 */
  assign n3329 = exec[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:80 */
  assign n3330 = {n3327, n3329};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:102 */
  assign n3331 = exec[34:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:93 */
  assign n3332 = {n3330, n3331};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:126 */
  assign n3333 = exec[15:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:117 */
  assign n3334 = {n3332, n3333};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:140 */
  assign n3336 = {n3334, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:7 */
  assign n3338 = n3293 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:72 */
  assign n3339 = exec[35:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:87 */
  assign n3341 = {n3339, 12'b000000000000};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:7 */
  assign n3343 = n3293 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:25 */
  assign n3345 = n3293 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:25 */
  assign n3346 = n3343 | n3345;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:70 */
  assign n3348 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3354 = {n3348, n3348, n3348, n3348, n3348, n3348, n3348, n3348, n3348, n3348, n3348, n3348};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:89 */
  assign n3356 = exec[23:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:80 */
  assign n3357 = {n3354, n3356};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:113 */
  assign n3358 = exec[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:104 */
  assign n3359 = {n3357, n3358};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:127 */
  assign n3360 = exec[34:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:118 */
  assign n3361 = {n3359, n3360};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:142 */
  assign n3363 = {n3361, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:7 */
  assign n3365 = n3293 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:243:7 */
  assign n3368 = n3293 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:70 */
  assign n3370 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3376 = {n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370, n3370};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:89 */
  assign n3378 = exec[34:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:80 */
  assign n3379 = {n3376, n3378};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:113 */
  assign n3380 = exec[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:104 */
  assign n3381 = {n3379, n3380};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:238:5 */
  assign n3382 = {n3368, n3365, n3346, n3338, n3319};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:238:5 */
  always @*
    case (n3382)
      5'b10000: n3383 = 32'b00000000000000000000000000000000;
      5'b01000: n3383 = n3363;
      5'b00100: n3383 = n3341;
      5'b00010: n3383 = n3336;
      5'b00001: n3383 = n3317;
      default: n3383 = n3381;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:248:17 */
  assign n3386 = n3293[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:249:40 */
  assign n3387 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:251:40 */
  assign n3388 = exec[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:248:5 */
  assign n3389 = n3386 ? n3387 : n3388;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:18 */
  assign n3392 = n3293 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:49 */
  assign n3394 = n3293 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:36 */
  assign n3395 = n3392 | n3394;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:78 */
  assign n3397 = n3293 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:65 */
  assign n3398 = n3395 | n3397;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3400 = n3297[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:5 */
  assign n3401 = n3398 ? 1'b1 : n3400;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3402 = n3297[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:258:18 */
  assign n3405 = n3293 != 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:258:5 */
  assign n3407 = n3405 ? 1'b1 : n3402;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:15 */
  assign n3408 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:265:7 */
  assign n3413 = n3408 == 4'b0000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:40 */
  assign n3416 = n3254[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:24 */
  assign n3418 = n3416 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:9 */
  assign n3421 = n3418 ? 32'b00000000000000000000000000000010 : 32'b00000000000000000000000000000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:29 */
  assign n3422 = env_pend | exc_fire;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:27 */
  assign n3424 = n3254[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:54 */
  assign n3425 = ~hwtrig_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:40 */
  assign n3426 = n3425 & n3424;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:285:35 */
  assign n3427 = n3254[50]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:286:40 */
  assign n3428 = n3254[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:287:40 */
  assign n3429 = n3254[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:288:40 */
  assign n3430 = n3254[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:289:37 */
  assign n3431 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:289:51 */
  assign n3433 = {n3431, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:291:29 */
  assign n3435 = n3254[7:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:291:78 */
  assign n3437 = n3435 == 5'b11100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:292:48 */
  assign n3438 = n3254[32:21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3439 = n3443 ? n3438 : n3296;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3440 = {n3433, n3428, n3430, n3429, 4'b0100};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3441 = exec[84:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3442 = n3426 ? n3440 : n3441;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3443 = n3437 & n3426;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3445 = n3426 ? n3427 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3446 = n3442[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3447 = n3422 ? 4'b0010 : n3446;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3448 = n3442[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3449 = exec[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3450 = n3422 ? n3449 : n3448;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3451 = n3422 ? n3296 : n3439;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3453 = n3422 ? 1'b0 : n3445;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:271:7 */
  assign n3455 = n3408 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:25 */
  assign n3458 = csr[63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:47 */
  assign n3459 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:36 */
  assign n3460 = n3459 & n3458;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:36 */
  assign n3461 = csr[94:70]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:58 */
  assign n3462 = ecause[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:50 */
  assign n3463 = {n3461, n3462};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:71 */
  assign n3465 = {n3463, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:305:36 */
  assign n3466 = csr[94:65]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:305:50 */
  assign n3468 = {n3466, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:9 */
  assign n3469 = n3460 ? n3465 : n3468;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:296:7 */
  assign n3472 = n3408 == 4'b0010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:315:35 */
  assign n3474 = csr[56:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:315:49 */
  assign n3476 = {n3474, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:310:7 */
  assign n3479 = n3408 == 4'b0011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:322:34 */
  assign n3480 = alu_add_i[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:322:48 */
  assign n3482 = {n3480, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:330:15 */
  assign n3485 = n3295 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:331:15 */
  assign n3488 = n3295 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:332:15 */
  assign n3490 = n3295 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:333:15 */
  assign n3493 = n3295 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:334:15 */
  assign n3496 = n3295 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:335:15 */
  assign n3499 = n3295 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:329:13 */
  assign n3501 = {n3499, n3496, n3493, n3490, n3488, n3485};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:329:13 */
  always @*
    case (n3501)
      6'b100000: n3502 = 3'b111;
      6'b010000: n3502 = 3'b110;
      6'b001000: n3502 = 3'b101;
      6'b000100: n3502 = 3'b011;
      6'b000010: n3502 = 3'b011;
      6'b000001: n3502 = 3'b001;
      default: n3502 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:25 */
  assign n3503 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:38 */
  assign n3505 = n3503 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:27 */
  assign n3507 = n3295 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:57 */
  assign n3508 = n3293[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:44 */
  assign n3509 = n3508 & n3507;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:80 */
  assign n3510 = exec[34]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:68 */
  assign n3511 = n3510 & n3509;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:66 */
  assign n3512 = n3505 | n3511;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3514 = n3297[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:13 */
  assign n3515 = n3512 ? 1'b1 : n3514;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:26 */
  assign n3516 = n3293[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:30 */
  assign n3517 = ~n3516;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:51 */
  assign n3519 = n3295 != 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:37 */
  assign n3520 = n3519 & n3517;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:82 */
  assign n3522 = n3295 != 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:68 */
  assign n3523 = n3522 & n3520;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:26 */
  assign n3524 = n3293[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:53 */
  assign n3526 = n3295 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:84 */
  assign n3528 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:70 */
  assign n3529 = n3528 & n3526;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:112 */
  assign n3531 = n3295 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:143 */
  assign n3533 = n3294 == 7'b0100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:129 */
  assign n3534 = n3533 & n3531;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:98 */
  assign n3535 = n3529 | n3534;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:53 */
  assign n3537 = n3295 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:84 */
  assign n3539 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:70 */
  assign n3540 = n3539 & n3537;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:157 */
  assign n3541 = n3535 | n3540;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:112 */
  assign n3543 = n3295 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:143 */
  assign n3545 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:129 */
  assign n3546 = n3545 & n3543;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:98 */
  assign n3547 = n3541 | n3546;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:53 */
  assign n3549 = n3295 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:84 */
  assign n3551 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:70 */
  assign n3552 = n3551 & n3549;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:157 */
  assign n3553 = n3547 | n3552;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:112 */
  assign n3555 = n3295 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:143 */
  assign n3557 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:129 */
  assign n3558 = n3557 & n3555;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:98 */
  assign n3559 = n3553 | n3558;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:53 */
  assign n3561 = n3295 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:84 */
  assign n3563 = n3294 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:70 */
  assign n3564 = n3563 & n3561;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:157 */
  assign n3565 = n3559 | n3564;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:37 */
  assign n3566 = n3565 & n3524;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:99 */
  assign n3567 = n3523 | n3566;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3572 = n3567 ? 4'b0001 : 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3573 = n3297[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3574 = n3567 ? 1'b1 : n3573;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3575 = n3297[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3576 = n3567 ? n3575 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:11 */
  assign n3578 = n3293 == 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:29 */
  assign n3580 = n3293 == 7'b0010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:29 */
  assign n3581 = n3578 | n3580;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:359:11 */
  assign n3586 = n3293 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:365:11 */
  assign n3590 = n3293 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:379:45 */
  assign n3591 = exec[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:379:34 */
  assign n3592 = ~n3591;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:380:41 */
  assign n3593 = exec[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:11 */
  assign n3596 = n3293 == 7'b0000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:30 */
  assign n3598 = n3293 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:30 */
  assign n3599 = n3596 | n3598;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:47 */
  assign n3601 = n3293 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:47 */
  assign n3602 = n3599 | n3601;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:11 */
  assign n3605 = n3293 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:32 */
  assign n3607 = n3293 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:32 */
  assign n3608 = n3605 | n3607;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:47 */
  assign n3610 = n3293 == 7'b1100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:47 */
  assign n3611 = n3608 | n3610;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:24 */
  assign n3612 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3622 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3624 = 1'b0 | n3622;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3626 = exec[34]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3627 = n3624 | n3626;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3628 = exec[33]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3629 = n3627 | n3628;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3630 = exec[32]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3631 = n3629 | n3630;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3632 = exec[31]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3633 = n3631 | n3632;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3634 = exec[30]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3635 = n3633 | n3634;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3636 = exec[29]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3637 = n3635 | n3636;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3638 = exec[28]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3639 = n3637 | n3638;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3641 = n3612 ? 4'b0000 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3642 = n3297[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3643 = n3612 ? 1'b1 : n3642;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3644 = n3297[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3645 = n3612 ? n3644 : n3639;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:389:11 */
  assign n3647 = n3293 == 7'b0001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:399:11 */
  assign n3651 = n3293 == 7'b1010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:11 */
  assign n3655 = n3293 == 7'b0001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:31 */
  assign n3657 = n3293 == 7'b0101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:31 */
  assign n3658 = n3655 | n3657;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:48 */
  assign n3660 = n3293 == 7'b0111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:48 */
  assign n3661 = n3658 | n3660;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:64 */
  assign n3663 = n3293 == 7'b0011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:64 */
  assign n3664 = n3661 | n3663;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:26 */
  assign n3666 = n3295 != 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:57 */
  assign n3668 = n3295 != 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:43 */
  assign n3669 = n3668 & n3666;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3671 = n3297[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:13 */
  assign n3672 = n3669 ? 1'b1 : n3671;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  assign n3674 = {n3664, n3651, n3647, n3611, n3602, n3590, n3586, n3581};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3675 = 4'b0101;
      8'b01000000: n3675 = 4'b0101;
      8'b00100000: n3675 = n3641;
      8'b00010000: n3675 = 4'b0110;
      8'b00001000: n3675 = 4'b0111;
      8'b00000100: n3675 = 4'b0001;
      8'b00000010: n3675 = 4'b0001;
      8'b00000001: n3675 = n3572;
      default: n3675 = 4'b1001;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3676 = n3297[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3677 = n3676;
      8'b01000000: n3677 = n3676;
      8'b00100000: n3677 = n3643;
      8'b00010000: n3677 = n3676;
      8'b00001000: n3677 = n3676;
      8'b00000100: n3677 = n3676;
      8'b00000010: n3677 = n3676;
      8'b00000001: n3677 = n3676;
      default: n3677 = n3676;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3678 = n3297[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3679 = n3678;
      8'b01000000: n3679 = n3678;
      8'b00100000: n3679 = n3678;
      8'b00010000: n3679 = n3678;
      8'b00001000: n3679 = n3678;
      8'b00000100: n3679 = 1'b1;
      8'b00000010: n3679 = 1'b1;
      8'b00000001: n3679 = n3574;
      default: n3679 = n3678;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3680 = n3297[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3681 = n3680;
      8'b01000000: n3681 = n3680;
      8'b00100000: n3681 = n3680;
      8'b00010000: n3681 = n3680;
      8'b00001000: n3681 = n3680;
      8'b00000100: n3681 = 3'b001;
      8'b00000010: n3681 = 3'b100;
      8'b00000001: n3681 = n3502;
      default: n3681 = n3680;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3682 = n3297[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3683 = n3682;
      8'b01000000: n3683 = n3682;
      8'b00100000: n3683 = n3682;
      8'b00010000: n3683 = n3682;
      8'b00001000: n3683 = n3682;
      8'b00000100: n3683 = n3682;
      8'b00000010: n3683 = n3682;
      8'b00000001: n3683 = n3515;
      default: n3683 = n3682;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3684 = n3297[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3685 = n3684;
      8'b01000000: n3685 = n3684;
      8'b00100000: n3685 = n3684;
      8'b00010000: n3685 = n3684;
      8'b00001000: n3685 = n3684;
      8'b00000100: n3685 = n3684;
      8'b00000010: n3685 = n3684;
      8'b00000001: n3685 = n3576;
      default: n3685 = n3684;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3686 = n3297[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3687 = 1'b1;
      8'b01000000: n3687 = n3686;
      8'b00100000: n3687 = n3686;
      8'b00010000: n3687 = n3686;
      8'b00001000: n3687 = n3686;
      8'b00000100: n3687 = n3686;
      8'b00000010: n3687 = n3686;
      8'b00000001: n3687 = n3686;
      default: n3687 = n3686;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3688 = n3297[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3689 = n3688;
      8'b01000000: n3689 = 1'b1;
      8'b00100000: n3689 = n3688;
      8'b00010000: n3689 = n3688;
      8'b00001000: n3689 = n3688;
      8'b00000100: n3689 = n3688;
      8'b00000010: n3689 = n3688;
      8'b00000001: n3689 = n3688;
      default: n3689 = n3688;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3690 = n3300;
      8'b01000000: n3690 = n3300;
      8'b00100000: n3690 = n3300;
      8'b00010000: n3690 = n3300;
      8'b00001000: n3690 = n3592;
      8'b00000100: n3690 = n3300;
      8'b00000010: n3690 = n3300;
      8'b00000001: n3690 = n3300;
      default: n3690 = n3300;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3691 = n3303;
      8'b01000000: n3691 = n3303;
      8'b00100000: n3691 = n3303;
      8'b00010000: n3691 = n3303;
      8'b00001000: n3691 = n3593;
      8'b00000100: n3691 = n3303;
      8'b00000010: n3691 = n3303;
      8'b00000001: n3691 = n3303;
      default: n3691 = n3303;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3692 = n3297[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3693 = n3692;
      8'b01000000: n3693 = n3692;
      8'b00100000: n3693 = n3645;
      8'b00010000: n3693 = n3692;
      8'b00001000: n3693 = n3692;
      8'b00000100: n3693 = n3692;
      8'b00000010: n3693 = n3692;
      8'b00000001: n3693 = n3692;
      default: n3693 = n3692;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3694 = n3297[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3674)
      8'b10000000: n3695 = n3694;
      8'b01000000: n3695 = n3694;
      8'b00100000: n3695 = n3694;
      8'b00010000: n3695 = n3694;
      8'b00001000: n3695 = n3694;
      8'b00000100: n3695 = n3694;
      8'b00000010: n3695 = n3694;
      8'b00000001: n3695 = n3694;
      default: n3695 = n3672;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:320:7 */
  assign n3697 = n3408 == 4'b0100;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3706 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3708 = 1'b0 | n3706;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3710 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3711 = n3708 | n3710;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3712 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3713 = n3711 | n3712;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:421:34 */
  assign n3714 = alu_cp_done_i | n3713;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3716 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:421:9 */
  assign n3717 = n3714 ? 4'b0001 : n3716;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:417:7 */
  assign n3719 = n3408 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:427:29 */
  assign n3721 = 1'b0 | branch_taken;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3723 = n3297[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:427:9 */
  assign n3724 = n3721 ? 1'b1 : n3723;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:431:36 */
  assign n3725 = alu_add_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:431:40 */
  assign n3728 = n3725 & 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:432:36 */
  assign n3729 = alu_add_i[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:432:50 */
  assign n3731 = {n3729, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3732 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:430:9 */
  assign n3733 = branch_taken ? n3731 : n3732;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:430:9 */
  assign n3735 = branch_taken ? n3728 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:434:38 */
  assign n3736 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:434:52 */
  assign n3738 = {n3736, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:435:37 */
  assign n3739 = exec[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:425:7 */
  assign n3742 = n3408 == 4'b0110;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3750 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3752 = 1'b0 | n3750;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3754 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3755 = n3752 | n3754;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3756 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3757 = n3755 | n3756;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:69 */
  assign n3758 = ~n3757;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:9 */
  assign n3762 = n3758 ? 4'b1000 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3763 = n3297[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:9 */
  assign n3764 = n3758 ? 1'b1 : n3763;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:438:7 */
  assign n3766 = n3408 == 4'b0111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:24 */
  assign n3767 = ~lsu_wait_i;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3775 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3777 = 1'b0 | n3775;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3779 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3780 = n3777 | n3779;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3781 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3782 = n3780 | n3781;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3783 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3784 = n3782 | n3783;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:31 */
  assign n3785 = n3767 | n3784;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:450:37 */
  assign n3786 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3788 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:9 */
  assign n3789 = n3785 ? 4'b0001 : n3788;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3790 = n3297[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:9 */
  assign n3791 = n3785 ? n3786 : n3790;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:447:7 */
  assign n3793 = n3408 == 4'b1000;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3802 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3804 = 1'b0 | n3802;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3806 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3807 = n3804 | n3806;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3808 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3809 = n3807 | n3808;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:69 */
  assign n3810 = ~n3809;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:24 */
  assign n3812 = n3295 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:25 */
  assign n3813 = exec[26:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:460:15 */
  assign n3815 = n3813 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:461:15 */
  assign n3817 = n3813 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:462:15 */
  assign n3820 = n3813 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:463:15 */
  assign n3823 = n3813 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  assign n3825 = {n3823, n3820, n3817, n3815};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3825)
      4'b1000: n3826 = 4'b1010;
      4'b0100: n3826 = 4'b0011;
      4'b0010: n3826 = 4'b0001;
      4'b0001: n3826 = 4'b0001;
      default: n3826 = 4'b0001;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3825)
      4'b1000: n3829 = 1'b0;
      4'b0100: n3829 = 1'b0;
      4'b0010: n3829 = 1'b0;
      4'b0001: n3829 = 1'b1;
      default: n3829 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3825)
      4'b1000: n3832 = 1'b0;
      4'b0100: n3832 = 1'b0;
      4'b0010: n3832 = 1'b1;
      4'b0001: n3832 = 1'b0;
      default: n3832 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:27 */
  assign n3834 = n3295 != 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:28 */
  assign n3836 = n3295 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:59 */
  assign n3838 = n3295 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:46 */
  assign n3839 = n3836 | n3838;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:89 */
  assign n3840 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:130 */
  assign n3842 = n3840 != 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:78 */
  assign n3843 = n3839 | n3842;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:46 */
  assign n3844 = n3843 & n3834;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3846 = n3297[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:11 */
  assign n3847 = n3844 ? 1'b1 : n3846;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3848 = n3855 ? n3826 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3849 = n3297[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3850 = n3812 ? n3849 : n3847;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3852 = n3812 ? n3829 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3854 = n3812 ? n3832 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3855 = n3812 & n3810;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3856 = n3297[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3857 = n3810 ? n3850 : n3856;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3859 = n3810 ? n3852 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3861 = n3810 ? n3854 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:454:7 */
  assign n3864 = n3408 == 4'b1001;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3871 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3873 = 1'b0 | n3871;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3875 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3876 = n3873 | n3875;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3877 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3878 = n3876 | n3877;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3879 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3880 = n3878 | n3879;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3881 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3882 = n3880 | n3881;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3883 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3884 = n3882 | n3883;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3885 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3886 = n3884 | n3885;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3887 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3888 = n3886 | n3887;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3889 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3890 = n3888 | n3889;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3891 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3892 = n3890 | n3891;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3893 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3894 = n3892 | n3893;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3895 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3896 = n3894 | n3895;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3897 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3898 = n3896 | n3897;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3899 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3900 = n3898 | n3899;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3901 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3902 = n3900 | n3901;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3903 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3904 = n3902 | n3903;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3905 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3906 = n3904 | n3905;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3907 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3908 = n3906 | n3907;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3909 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3910 = n3908 | n3909;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3911 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3912 = n3910 | n3911;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:476:41 */
  assign n3913 = n3912 | exc_fire;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3915 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:476:9 */
  assign n3916 = n3913 ? 4'b0001 : n3915;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  assign n3917 = {n3864, n3793, n3766, n3742, n3719, n3697, n3479, n3472, n3455, n3413};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3918 = n3848;
      10'b0100000000: n3918 = n3789;
      10'b0010000000: n3918 = n3762;
      10'b0001000000: n3918 = 4'b0001;
      10'b0000100000: n3918 = n3717;
      10'b0000010000: n3918 = n3675;
      10'b0000001000: n3918 = 4'b0000;
      10'b0000000100: n3918 = 4'b0000;
      10'b0000000010: n3918 = n3447;
      10'b0000000001: n3918 = 4'b0001;
      default: n3918 = n3916;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3919 = exec[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3920 = n3919;
      10'b0100000000: n3920 = n3919;
      10'b0010000000: n3920 = n3919;
      10'b0001000000: n3920 = n3919;
      10'b0000100000: n3920 = n3919;
      10'b0000010000: n3920 = n3919;
      10'b0000001000: n3920 = n3919;
      10'b0000000100: n3920 = n3919;
      10'b0000000010: n3920 = n3450;
      10'b0000000001: n3920 = n3919;
      default: n3920 = n3919;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3921 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3922 = n3921;
      10'b0100000000: n3922 = n3921;
      10'b0010000000: n3922 = n3921;
      10'b0001000000: n3922 = n3733;
      10'b0000100000: n3922 = n3921;
      10'b0000010000: n3922 = n3482;
      10'b0000001000: n3922 = n3476;
      10'b0000000100: n3922 = n3469;
      10'b0000000010: n3922 = n3921;
      10'b0000000001: n3922 = n3921;
      default: n3922 = n3921;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3925 = n3297[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3926 = n3925;
      10'b0100000000: n3926 = n3925;
      10'b0010000000: n3926 = n3925;
      10'b0001000000: n3926 = n3724;
      10'b0000100000: n3926 = n3925;
      10'b0000010000: n3926 = n3925;
      10'b0000001000: n3926 = n3925;
      10'b0000000100: n3926 = n3925;
      10'b0000000010: n3926 = n3925;
      10'b0000000001: n3926 = 1'b1;
      default: n3926 = n3925;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3927 = n3297[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3928 = n3927;
      10'b0100000000: n3928 = n3927;
      10'b0010000000: n3928 = n3927;
      10'b0001000000: n3928 = n3927;
      10'b0000100000: n3928 = n3927;
      10'b0000010000: n3928 = n3677;
      10'b0000001000: n3928 = n3927;
      10'b0000000100: n3928 = n3927;
      10'b0000000010: n3928 = n3927;
      10'b0000000001: n3928 = n3927;
      default: n3928 = n3927;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3929 = n3297[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3930 = n3929;
      10'b0100000000: n3930 = n3929;
      10'b0010000000: n3930 = n3929;
      10'b0001000000: n3930 = n3738;
      10'b0000100000: n3930 = n3929;
      10'b0000010000: n3930 = n3929;
      10'b0000001000: n3930 = n3929;
      10'b0000000100: n3930 = n3929;
      10'b0000000010: n3930 = n3929;
      10'b0000000001: n3930 = n3929;
      default: n3930 = n3929;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3931 = n3297[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3932 = 1'b1;
      10'b0100000000: n3932 = n3791;
      10'b0010000000: n3932 = n3931;
      10'b0001000000: n3932 = n3739;
      10'b0000100000: n3932 = alu_cp_done_i;
      10'b0000010000: n3932 = n3679;
      10'b0000001000: n3932 = n3931;
      10'b0000000100: n3932 = n3931;
      10'b0000000010: n3932 = n3931;
      10'b0000000001: n3932 = n3931;
      default: n3932 = n3931;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3933 = n3297[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3934 = n3933;
      10'b0100000000: n3934 = n3933;
      10'b0010000000: n3934 = n3933;
      10'b0001000000: n3934 = n3933;
      10'b0000100000: n3934 = n3933;
      10'b0000010000: n3934 = n3933;
      10'b0000001000: n3934 = n3933;
      10'b0000000100: n3934 = n3933;
      10'b0000000010: n3934 = n3933;
      10'b0000000001: n3934 = 1'b1;
      default: n3934 = n3933;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3935 = n3297[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3936 = n3935;
      10'b0100000000: n3936 = n3935;
      10'b0010000000: n3936 = n3935;
      10'b0001000000: n3936 = n3935;
      10'b0000100000: n3936 = 3'b010;
      10'b0000010000: n3936 = n3681;
      10'b0000001000: n3936 = n3935;
      10'b0000000100: n3936 = n3935;
      10'b0000000010: n3936 = n3935;
      10'b0000000001: n3936 = n3935;
      default: n3936 = n3935;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3937 = n3297[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3938 = n3937;
      10'b0100000000: n3938 = n3937;
      10'b0010000000: n3938 = n3937;
      10'b0001000000: n3938 = n3937;
      10'b0000100000: n3938 = n3937;
      10'b0000010000: n3938 = n3683;
      10'b0000001000: n3938 = n3937;
      10'b0000000100: n3938 = n3937;
      10'b0000000010: n3938 = n3937;
      10'b0000000001: n3938 = n3937;
      default: n3938 = n3937;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3939 = n3401;
      10'b0100000000: n3939 = n3401;
      10'b0010000000: n3939 = n3401;
      10'b0001000000: n3939 = n3401;
      10'b0000100000: n3939 = n3401;
      10'b0000010000: n3939 = n3401;
      10'b0000001000: n3939 = n3401;
      10'b0000000100: n3939 = n3401;
      10'b0000000010: n3939 = 1'b1;
      10'b0000000001: n3939 = n3401;
      default: n3939 = n3401;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3940 = n3407;
      10'b0100000000: n3940 = n3407;
      10'b0010000000: n3940 = n3407;
      10'b0001000000: n3940 = n3407;
      10'b0000100000: n3940 = n3407;
      10'b0000010000: n3940 = n3407;
      10'b0000001000: n3940 = n3407;
      10'b0000000100: n3940 = n3407;
      10'b0000000010: n3940 = 1'b1;
      10'b0000000001: n3940 = n3407;
      default: n3940 = n3407;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3941 = n3383;
      10'b0100000000: n3941 = n3383;
      10'b0010000000: n3941 = n3383;
      10'b0001000000: n3941 = n3383;
      10'b0000100000: n3941 = n3383;
      10'b0000010000: n3941 = n3383;
      10'b0000001000: n3941 = n3383;
      10'b0000000100: n3941 = n3383;
      10'b0000000010: n3941 = n3421;
      10'b0000000001: n3941 = n3383;
      default: n3941 = n3383;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3942 = n3297[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3943 = n3942;
      10'b0100000000: n3943 = n3942;
      10'b0010000000: n3943 = n3942;
      10'b0001000000: n3943 = n3942;
      10'b0000100000: n3943 = n3942;
      10'b0000010000: n3943 = n3685;
      10'b0000001000: n3943 = n3942;
      10'b0000000100: n3943 = n3942;
      10'b0000000010: n3943 = n3942;
      10'b0000000001: n3943 = n3942;
      default: n3943 = n3942;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3944 = n3297[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3945 = n3944;
      10'b0100000000: n3945 = n3944;
      10'b0010000000: n3945 = n3944;
      10'b0001000000: n3945 = n3944;
      10'b0000100000: n3945 = n3944;
      10'b0000010000: n3945 = n3687;
      10'b0000001000: n3945 = n3944;
      10'b0000000100: n3945 = n3944;
      10'b0000000010: n3945 = n3944;
      10'b0000000001: n3945 = n3944;
      default: n3945 = n3944;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3946 = n3297[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3947 = n3946;
      10'b0100000000: n3947 = n3946;
      10'b0010000000: n3947 = n3946;
      10'b0001000000: n3947 = n3946;
      10'b0000100000: n3947 = n3946;
      10'b0000010000: n3947 = n3689;
      10'b0000001000: n3947 = n3946;
      10'b0000000100: n3947 = n3946;
      10'b0000000010: n3947 = n3946;
      10'b0000000001: n3947 = n3946;
      default: n3947 = n3946;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3948 = n3297[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3949 = n3948;
      10'b0100000000: n3949 = n3948;
      10'b0010000000: n3949 = n3764;
      10'b0001000000: n3949 = n3948;
      10'b0000100000: n3949 = n3948;
      10'b0000010000: n3949 = n3948;
      10'b0000001000: n3949 = n3948;
      10'b0000000100: n3949 = n3948;
      10'b0000000010: n3949 = n3948;
      10'b0000000001: n3949 = n3948;
      default: n3949 = n3948;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3950 = n3300;
      10'b0100000000: n3950 = n3300;
      10'b0010000000: n3950 = n3300;
      10'b0001000000: n3950 = n3300;
      10'b0000100000: n3950 = n3300;
      10'b0000010000: n3950 = n3690;
      10'b0000001000: n3950 = n3300;
      10'b0000000100: n3950 = n3300;
      10'b0000000010: n3950 = n3300;
      10'b0000000001: n3950 = n3300;
      default: n3950 = n3300;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3951 = n3303;
      10'b0100000000: n3951 = n3303;
      10'b0010000000: n3951 = n3303;
      10'b0001000000: n3951 = n3303;
      10'b0000100000: n3951 = n3303;
      10'b0000010000: n3951 = n3691;
      10'b0000001000: n3951 = n3303;
      10'b0000000100: n3951 = n3303;
      10'b0000000010: n3951 = n3303;
      10'b0000000001: n3951 = n3303;
      default: n3951 = n3303;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3952 = n3297[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3953 = n3952;
      10'b0100000000: n3953 = n3952;
      10'b0010000000: n3953 = n3952;
      10'b0001000000: n3953 = n3952;
      10'b0000100000: n3953 = n3952;
      10'b0000010000: n3953 = n3693;
      10'b0000001000: n3953 = n3952;
      10'b0000000100: n3953 = n3952;
      10'b0000000010: n3953 = n3952;
      10'b0000000001: n3953 = n3952;
      default: n3953 = n3952;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3954 = n3297[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3955 = n3857;
      10'b0100000000: n3955 = n3954;
      10'b0010000000: n3955 = n3954;
      10'b0001000000: n3955 = n3954;
      10'b0000100000: n3955 = n3954;
      10'b0000010000: n3955 = n3954;
      10'b0000001000: n3955 = n3954;
      10'b0000000100: n3955 = n3954;
      10'b0000000010: n3955 = n3954;
      10'b0000000001: n3955 = n3954;
      default: n3955 = n3954;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3956 = n3297[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3957 = n3956;
      10'b0100000000: n3957 = n3956;
      10'b0010000000: n3957 = n3956;
      10'b0001000000: n3957 = n3956;
      10'b0000100000: n3957 = n3956;
      10'b0000010000: n3957 = n3695;
      10'b0000001000: n3957 = n3956;
      10'b0000000100: n3957 = n3956;
      10'b0000000010: n3957 = n3956;
      10'b0000000001: n3957 = n3956;
      default: n3957 = n3956;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3958 = n3296;
      10'b0100000000: n3958 = n3296;
      10'b0010000000: n3958 = n3296;
      10'b0001000000: n3958 = n3296;
      10'b0000100000: n3958 = n3296;
      10'b0000010000: n3958 = n3296;
      10'b0000001000: n3958 = n3296;
      10'b0000000100: n3958 = n3296;
      10'b0000000010: n3958 = n3451;
      10'b0000000001: n3958 = n3296;
      default: n3958 = n3296;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3961 = n3297[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3963 = n3297[66:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3966 = n3297[114:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3972 = n3297[163:161]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3976 = 1'b0;
      10'b0100000000: n3976 = 1'b0;
      10'b0010000000: n3976 = 1'b0;
      10'b0001000000: n3976 = 1'b0;
      10'b0000100000: n3976 = 1'b0;
      10'b0000010000: n3976 = 1'b0;
      10'b0000001000: n3976 = 1'b0;
      10'b0000000100: n3976 = 1'b1;
      10'b0000000010: n3976 = 1'b0;
      10'b0000000001: n3976 = 1'b0;
      default: n3976 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3980 = 1'b0;
      10'b0100000000: n3980 = 1'b0;
      10'b0010000000: n3980 = 1'b0;
      10'b0001000000: n3980 = 1'b0;
      10'b0000100000: n3980 = 1'b0;
      10'b0000010000: n3980 = 1'b0;
      10'b0000001000: n3980 = 1'b1;
      10'b0000000100: n3980 = 1'b0;
      10'b0000000010: n3980 = 1'b0;
      10'b0000000001: n3980 = 1'b0;
      default: n3980 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3983 = 1'b0;
      10'b0100000000: n3983 = 1'b0;
      10'b0010000000: n3983 = 1'b0;
      10'b0001000000: n3983 = 1'b0;
      10'b0000100000: n3983 = 1'b0;
      10'b0000010000: n3983 = 1'b0;
      10'b0000001000: n3983 = 1'b0;
      10'b0000000100: n3983 = 1'b0;
      10'b0000000010: n3983 = n3453;
      10'b0000000001: n3983 = 1'b0;
      default: n3983 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3986 = 1'b0;
      10'b0100000000: n3986 = 1'b0;
      10'b0010000000: n3986 = 1'b0;
      10'b0001000000: n3986 = n3735;
      10'b0000100000: n3986 = 1'b0;
      10'b0000010000: n3986 = 1'b0;
      10'b0000001000: n3986 = 1'b0;
      10'b0000000100: n3986 = 1'b0;
      10'b0000000010: n3986 = 1'b0;
      10'b0000000001: n3986 = 1'b0;
      default: n3986 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3989 = n3859;
      10'b0100000000: n3989 = 1'b0;
      10'b0010000000: n3989 = 1'b0;
      10'b0001000000: n3989 = 1'b0;
      10'b0000100000: n3989 = 1'b0;
      10'b0000010000: n3989 = 1'b0;
      10'b0000001000: n3989 = 1'b0;
      10'b0000000100: n3989 = 1'b0;
      10'b0000000010: n3989 = 1'b0;
      10'b0000000001: n3989 = 1'b0;
      default: n3989 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3917)
      10'b1000000000: n3992 = n3861;
      10'b0100000000: n3992 = 1'b0;
      10'b0010000000: n3992 = 1'b0;
      10'b0001000000: n3992 = 1'b0;
      10'b0000100000: n3992 = 1'b0;
      10'b0000010000: n3992 = 1'b0;
      10'b0000001000: n3992 = 1'b0;
      10'b0000000100: n3992 = 1'b0;
      10'b0000000010: n3992 = 1'b0;
      10'b0000000001: n3992 = 1'b0;
      default: n3992 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:487:35 */
  assign n3995 = ctrl_nxt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:41 */
  assign n3997 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:47 */
  assign n3999 = n3997 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:30 */
  assign n4000 = n3999 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:489:31 */
  assign n4002 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:491:33 */
  assign n4003 = exec[84:54]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:491:47 */
  assign n4005 = {n4003, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:492:34 */
  assign n4006 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:492:48 */
  assign n4008 = {n4006, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:493:37 */
  assign n4009 = ctrl[98:68]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:493:51 */
  assign n4011 = {n4009, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:31 */
  assign n4012 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4020 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4022 = 1'b0 | n4020;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4024 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4025 = n4022 | n4024;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4026 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4027 = n4025 | n4026;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4028 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4029 = n4027 | n4028;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4030 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4031 = n4029 | n4030;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4032 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4033 = n4031 | n4032;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4034 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4035 = n4033 | n4034;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4036 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4037 = n4035 | n4036;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4038 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4039 = n4037 | n4038;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:45 */
  assign n4040 = ~n4039;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:40 */
  assign n4041 = n4012 & n4040;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:496:33 */
  assign n4042 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:497:33 */
  assign n4043 = exec[28:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:498:33 */
  assign n4044 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:499:31 */
  assign n4045 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:501:31 */
  assign n4046 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:502:31 */
  assign n4047 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:503:31 */
  assign n4048 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:504:31 */
  assign n4049 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:505:31 */
  assign n4050 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:506:31 */
  assign n4051 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:31 */
  assign n4052 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4060 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4062 = 1'b0 | n4060;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4064 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4065 = n4062 | n4064;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4066 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4067 = n4065 | n4066;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:47 */
  assign n4068 = ~n4067;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:42 */
  assign n4069 = n4052 & n4068;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:31 */
  assign n4070 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4078 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4080 = 1'b0 | n4078;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4082 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4083 = n4080 | n4082;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4084 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4085 = n4083 | n4084;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:47 */
  assign n4086 = ~n4085;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:42 */
  assign n4087 = n4070 & n4086;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:31 */
  assign n4088 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4096 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4098 = 1'b0 | n4096;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4100 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4101 = n4098 | n4100;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n4102 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n4103 = n4101 | n4102;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:47 */
  assign n4104 = ~n4103;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:42 */
  assign n4105 = n4088 & n4104;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:511:31 */
  assign n4106 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:512:31 */
  assign n4107 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:513:31 */
  assign n4108 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:41 */
  assign n4110 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:47 */
  assign n4112 = n4110 == 4'b0111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:30 */
  assign n4113 = n4112 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:41 */
  assign n4116 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:47 */
  assign n4118 = n4116 == 4'b1000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:30 */
  assign n4119 = n4118 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:30 */
  assign n4121 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:52 */
  assign n4122 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:42 */
  assign n4123 = n4122 ? n4121 : n4124;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:81 */
  assign n4124 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:517:31 */
  assign n4125 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:519:31 */
  assign n4126 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:520:31 */
  assign n4127 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:521:31 */
  assign n4128 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:526:33 */
  assign n4129 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:527:33 */
  assign n4130 = exec[35:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:528:33 */
  assign n4131 = exec[10:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:529:31 */
  assign n4132 = exec[51:36]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:531:30 */
  assign n4133 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:534:37 */
  assign n4134 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:53 */
  assign n4136 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:59 */
  assign n4138 = n4136 == 4'b1010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:42 */
  assign n4139 = n4138 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:53 */
  assign n4142 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:59 */
  assign n4144 = n4142 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:42 */
  assign n4145 = n4144 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:53 */
  assign n4148 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:59 */
  assign n4150 = n4148 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:82 */
  assign n4151 = exec[52]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:72 */
  assign n4152 = n4151 & n4150;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:42 */
  assign n4153 = n4152 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:53 */
  assign n4156 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:59 */
  assign n4158 = n4156 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:89 */
  assign n4159 = n3254[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:95 */
  assign n4160 = ~n4159;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:73 */
  assign n4161 = n4160 & n4158;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:42 */
  assign n4162 = n4161 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:53 */
  assign n4165 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:59 */
  assign n4167 = n4165 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:42 */
  assign n4168 = n4167 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:53 */
  assign n4171 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:61 */
  assign n4172 = ~n4171;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:78 */
  assign n4173 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:84 */
  assign n4175 = n4173 == 4'b1000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:68 */
  assign n4176 = n4175 & n4172;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:42 */
  assign n4177 = n4176 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:53 */
  assign n4180 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:81 */
  assign n4181 = exec[10:6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:94 */
  assign n4183 = n4181 != 5'b00011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:69 */
  assign n4184 = n4183 & n4180;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:42 */
  assign n4185 = n4184 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:53 */
  assign n4188 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:78 */
  assign n4189 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:68 */
  assign n4190 = n4189 & n4188;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:42 */
  assign n4191 = n4190 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:53 */
  assign n4194 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:78 */
  assign n4195 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:68 */
  assign n4196 = n4195 & n4194;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:42 */
  assign n4197 = n4196 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:15 */
  assign n4200 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:7 */
  assign n4204 = n4200 == 12'b000000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:25 */
  assign n4206 = n4200 == 12'b000000000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:25 */
  assign n4207 = n4204 | n4206;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:37 */
  assign n4209 = n4200 == 12'b000000000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:37 */
  assign n4210 = n4207 | n4209;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:7 */
  assign n4213 = n4200 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:32 */
  assign n4215 = n4200 == 12'b001100010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:32 */
  assign n4216 = n4213 | n4215;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:50 */
  assign n4218 = n4200 == 12'b001100000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:50 */
  assign n4219 = n4216 | n4218;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:66 */
  assign n4221 = n4200 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:66 */
  assign n4222 = n4219 | n4221;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:81 */
  assign n4224 = n4200 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:81 */
  assign n4225 = n4222 | n4224;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:96 */
  assign n4227 = n4200 == 12'b111100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:96 */
  assign n4228 = n4225 | n4227;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:115 */
  assign n4230 = n4200 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:115 */
  assign n4231 = n4228 | n4230;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:32 */
  assign n4233 = n4200 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:32 */
  assign n4234 = n4231 | n4233;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:50 */
  assign n4236 = n4200 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:50 */
  assign n4237 = n4234 | n4236;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:66 */
  assign n4239 = n4200 == 12'b001101000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:66 */
  assign n4240 = n4237 | n4239;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:81 */
  assign n4242 = n4200 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:81 */
  assign n4243 = n4240 | n4242;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:96 */
  assign n4245 = n4200 == 12'b111100010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:96 */
  assign n4246 = n4243 | n4245;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:115 */
  assign n4248 = n4200 == 12'b001100100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:115 */
  assign n4249 = n4246 | n4248;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:32 */
  assign n4251 = n4200 == 12'b111100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:32 */
  assign n4252 = n4249 | n4251;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:50 */
  assign n4254 = n4200 == 12'b111100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:50 */
  assign n4255 = n4252 | n4254;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:66 */
  assign n4257 = n4200 == 12'b111100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:66 */
  assign n4258 = n4255 | n4257;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:81 */
  assign n4260 = n4200 == 12'b111111000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:81 */
  assign n4261 = n4258 | n4260;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:96 */
  assign n4263 = n4200 == 12'b111111000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:96 */
  assign n4264 = n4261 | n4263;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:7 */
  assign n4268 = n4200 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:29 */
  assign n4270 = n4200 == 12'b001100001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:29 */
  assign n4271 = n4268 | n4270;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:45 */
  assign n4273 = n4200 == 12'b001100011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:45 */
  assign n4274 = n4271 | n4273;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:7 */
  assign n4278 = n4200 == 12'b001110100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:28 */
  assign n4280 = n4200 == 12'b001110100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:28 */
  assign n4281 = n4278 | n4280;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:46 */
  assign n4283 = n4200 == 12'b001110100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:46 */
  assign n4284 = n4281 | n4283;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:64 */
  assign n4286 = n4200 == 12'b001110100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:64 */
  assign n4287 = n4284 | n4286;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:82 */
  assign n4289 = n4200 == 12'b001110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:82 */
  assign n4290 = n4287 | n4289;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:28 */
  assign n4292 = n4200 == 12'b001110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:28 */
  assign n4293 = n4290 | n4292;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:46 */
  assign n4295 = n4200 == 12'b001110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:46 */
  assign n4296 = n4293 | n4295;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:64 */
  assign n4298 = n4200 == 12'b001110110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:64 */
  assign n4299 = n4296 | n4298;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:82 */
  assign n4301 = n4200 == 12'b001110110100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:82 */
  assign n4302 = n4299 | n4301;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:28 */
  assign n4304 = n4200 == 12'b001110110101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:28 */
  assign n4305 = n4302 | n4304;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:46 */
  assign n4307 = n4200 == 12'b001110110110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:46 */
  assign n4308 = n4305 | n4307;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:64 */
  assign n4310 = n4200 == 12'b001110110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:64 */
  assign n4311 = n4308 | n4310;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:82 */
  assign n4313 = n4200 == 12'b001110111000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:82 */
  assign n4314 = n4311 | n4313;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:28 */
  assign n4316 = n4200 == 12'b001110111001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:28 */
  assign n4317 = n4314 | n4316;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:46 */
  assign n4319 = n4200 == 12'b001110111010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:46 */
  assign n4320 = n4317 | n4319;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:64 */
  assign n4322 = n4200 == 12'b001110111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:64 */
  assign n4323 = n4320 | n4322;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:82 */
  assign n4325 = n4200 == 12'b001110111100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:82 */
  assign n4326 = n4323 | n4325;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:28 */
  assign n4328 = n4200 == 12'b001110111101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:28 */
  assign n4329 = n4326 | n4328;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:46 */
  assign n4331 = n4200 == 12'b001110111110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:46 */
  assign n4332 = n4329 | n4331;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:64 */
  assign n4334 = n4200 == 12'b001110111111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:64 */
  assign n4335 = n4332 | n4334;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:7 */
  assign n4339 = n4200 == 12'b110000000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:33 */
  assign n4341 = n4200 == 12'b110000000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:33 */
  assign n4342 = n4339 | n4341;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:56 */
  assign n4344 = n4200 == 12'b110000000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:56 */
  assign n4345 = n4342 | n4344;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:79 */
  assign n4347 = n4200 == 12'b110000000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:79 */
  assign n4348 = n4345 | n4347;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:102 */
  assign n4350 = n4200 == 12'b110000000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:102 */
  assign n4351 = n4348 | n4350;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:33 */
  assign n4353 = n4200 == 12'b110000001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:33 */
  assign n4354 = n4351 | n4353;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:56 */
  assign n4356 = n4200 == 12'b110000001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:56 */
  assign n4357 = n4354 | n4356;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:79 */
  assign n4359 = n4200 == 12'b110000001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:79 */
  assign n4360 = n4357 | n4359;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:102 */
  assign n4362 = n4200 == 12'b110000001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:102 */
  assign n4363 = n4360 | n4362;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:33 */
  assign n4365 = n4200 == 12'b110000001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:33 */
  assign n4366 = n4363 | n4365;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:56 */
  assign n4368 = n4200 == 12'b110000001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:56 */
  assign n4369 = n4366 | n4368;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:79 */
  assign n4371 = n4200 == 12'b110000001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:79 */
  assign n4372 = n4369 | n4371;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:102 */
  assign n4374 = n4200 == 12'b110000001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:102 */
  assign n4375 = n4372 | n4374;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:33 */
  assign n4377 = n4200 == 12'b110000010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:33 */
  assign n4378 = n4375 | n4377;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:56 */
  assign n4380 = n4200 == 12'b110000010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:56 */
  assign n4381 = n4378 | n4380;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:79 */
  assign n4383 = n4200 == 12'b110000010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:79 */
  assign n4384 = n4381 | n4383;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:102 */
  assign n4386 = n4200 == 12'b110000010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:102 */
  assign n4387 = n4384 | n4386;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:33 */
  assign n4389 = n4200 == 12'b110000010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:33 */
  assign n4390 = n4387 | n4389;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:56 */
  assign n4392 = n4200 == 12'b110000010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:56 */
  assign n4393 = n4390 | n4392;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:79 */
  assign n4395 = n4200 == 12'b110000010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:79 */
  assign n4396 = n4393 | n4395;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:102 */
  assign n4398 = n4200 == 12'b110000010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:102 */
  assign n4399 = n4396 | n4398;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:33 */
  assign n4401 = n4200 == 12'b110000011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:33 */
  assign n4402 = n4399 | n4401;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:56 */
  assign n4404 = n4200 == 12'b110000011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:56 */
  assign n4405 = n4402 | n4404;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:79 */
  assign n4407 = n4200 == 12'b110000011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:79 */
  assign n4408 = n4405 | n4407;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:102 */
  assign n4410 = n4200 == 12'b110000011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:102 */
  assign n4411 = n4408 | n4410;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:33 */
  assign n4413 = n4200 == 12'b110000011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:33 */
  assign n4414 = n4411 | n4413;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:56 */
  assign n4416 = n4200 == 12'b110000011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:56 */
  assign n4417 = n4414 | n4416;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:79 */
  assign n4419 = n4200 == 12'b110000011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:79 */
  assign n4420 = n4417 | n4419;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:102 */
  assign n4422 = n4200 == 12'b110000011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:102 */
  assign n4423 = n4420 | n4422;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:592:33 */
  assign n4425 = n4200 == 12'b110010000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:592:33 */
  assign n4426 = n4423 | n4425;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:33 */
  assign n4428 = n4200 == 12'b110010000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:33 */
  assign n4429 = n4426 | n4428;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:56 */
  assign n4431 = n4200 == 12'b110010000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:56 */
  assign n4432 = n4429 | n4431;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:79 */
  assign n4434 = n4200 == 12'b110010000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:79 */
  assign n4435 = n4432 | n4434;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:102 */
  assign n4437 = n4200 == 12'b110010000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:102 */
  assign n4438 = n4435 | n4437;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:33 */
  assign n4440 = n4200 == 12'b110010001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:33 */
  assign n4441 = n4438 | n4440;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:56 */
  assign n4443 = n4200 == 12'b110010001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:56 */
  assign n4444 = n4441 | n4443;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:79 */
  assign n4446 = n4200 == 12'b110010001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:79 */
  assign n4447 = n4444 | n4446;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:102 */
  assign n4449 = n4200 == 12'b110010001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:102 */
  assign n4450 = n4447 | n4449;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:33 */
  assign n4452 = n4200 == 12'b110010001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:33 */
  assign n4453 = n4450 | n4452;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:56 */
  assign n4455 = n4200 == 12'b110010001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:56 */
  assign n4456 = n4453 | n4455;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:79 */
  assign n4458 = n4200 == 12'b110010001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:79 */
  assign n4459 = n4456 | n4458;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:102 */
  assign n4461 = n4200 == 12'b110010001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:102 */
  assign n4462 = n4459 | n4461;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:33 */
  assign n4464 = n4200 == 12'b110010010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:33 */
  assign n4465 = n4462 | n4464;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:56 */
  assign n4467 = n4200 == 12'b110010010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:56 */
  assign n4468 = n4465 | n4467;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:79 */
  assign n4470 = n4200 == 12'b110010010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:79 */
  assign n4471 = n4468 | n4470;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:102 */
  assign n4473 = n4200 == 12'b110010010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:102 */
  assign n4474 = n4471 | n4473;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:33 */
  assign n4476 = n4200 == 12'b110010010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:33 */
  assign n4477 = n4474 | n4476;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:56 */
  assign n4479 = n4200 == 12'b110010010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:56 */
  assign n4480 = n4477 | n4479;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:79 */
  assign n4482 = n4200 == 12'b110010010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:79 */
  assign n4483 = n4480 | n4482;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:102 */
  assign n4485 = n4200 == 12'b110010010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:102 */
  assign n4486 = n4483 | n4485;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:33 */
  assign n4488 = n4200 == 12'b110010011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:33 */
  assign n4489 = n4486 | n4488;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:56 */
  assign n4491 = n4200 == 12'b110010011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:56 */
  assign n4492 = n4489 | n4491;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:79 */
  assign n4494 = n4200 == 12'b110010011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:79 */
  assign n4495 = n4492 | n4494;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:102 */
  assign n4497 = n4200 == 12'b110010011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:102 */
  assign n4498 = n4495 | n4497;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:33 */
  assign n4500 = n4200 == 12'b110010011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:33 */
  assign n4501 = n4498 | n4500;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:56 */
  assign n4503 = n4200 == 12'b110010011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:56 */
  assign n4504 = n4501 | n4503;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:79 */
  assign n4506 = n4200 == 12'b110010011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:79 */
  assign n4507 = n4504 | n4506;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:102 */
  assign n4509 = n4200 == 12'b110010011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:102 */
  assign n4510 = n4507 | n4509;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:600:33 */
  assign n4512 = n4200 == 12'b101100000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:600:33 */
  assign n4513 = n4510 | n4512;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:33 */
  assign n4515 = n4200 == 12'b101100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:33 */
  assign n4516 = n4513 | n4515;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:56 */
  assign n4518 = n4200 == 12'b101100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:56 */
  assign n4519 = n4516 | n4518;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:79 */
  assign n4521 = n4200 == 12'b101100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:79 */
  assign n4522 = n4519 | n4521;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:102 */
  assign n4524 = n4200 == 12'b101100000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:102 */
  assign n4525 = n4522 | n4524;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:33 */
  assign n4527 = n4200 == 12'b101100001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:33 */
  assign n4528 = n4525 | n4527;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:56 */
  assign n4530 = n4200 == 12'b101100001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:56 */
  assign n4531 = n4528 | n4530;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:79 */
  assign n4533 = n4200 == 12'b101100001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:79 */
  assign n4534 = n4531 | n4533;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:102 */
  assign n4536 = n4200 == 12'b101100001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:102 */
  assign n4537 = n4534 | n4536;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:33 */
  assign n4539 = n4200 == 12'b101100001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:33 */
  assign n4540 = n4537 | n4539;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:56 */
  assign n4542 = n4200 == 12'b101100001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:56 */
  assign n4543 = n4540 | n4542;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:79 */
  assign n4545 = n4200 == 12'b101100001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:79 */
  assign n4546 = n4543 | n4545;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:102 */
  assign n4548 = n4200 == 12'b101100001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:102 */
  assign n4549 = n4546 | n4548;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:33 */
  assign n4551 = n4200 == 12'b101100010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:33 */
  assign n4552 = n4549 | n4551;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:56 */
  assign n4554 = n4200 == 12'b101100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:56 */
  assign n4555 = n4552 | n4554;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:79 */
  assign n4557 = n4200 == 12'b101100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:79 */
  assign n4558 = n4555 | n4557;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:102 */
  assign n4560 = n4200 == 12'b101100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:102 */
  assign n4561 = n4558 | n4560;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:33 */
  assign n4563 = n4200 == 12'b101100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:33 */
  assign n4564 = n4561 | n4563;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:56 */
  assign n4566 = n4200 == 12'b101100010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:56 */
  assign n4567 = n4564 | n4566;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:79 */
  assign n4569 = n4200 == 12'b101100010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:79 */
  assign n4570 = n4567 | n4569;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:102 */
  assign n4572 = n4200 == 12'b101100010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:102 */
  assign n4573 = n4570 | n4572;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:33 */
  assign n4575 = n4200 == 12'b101100011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:33 */
  assign n4576 = n4573 | n4575;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:56 */
  assign n4578 = n4200 == 12'b101100011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:56 */
  assign n4579 = n4576 | n4578;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:79 */
  assign n4581 = n4200 == 12'b101100011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:79 */
  assign n4582 = n4579 | n4581;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:102 */
  assign n4584 = n4200 == 12'b101100011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:102 */
  assign n4585 = n4582 | n4584;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:33 */
  assign n4587 = n4200 == 12'b101100011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:33 */
  assign n4588 = n4585 | n4587;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:56 */
  assign n4590 = n4200 == 12'b101100011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:56 */
  assign n4591 = n4588 | n4590;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:79 */
  assign n4593 = n4200 == 12'b101100011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:79 */
  assign n4594 = n4591 | n4593;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:102 */
  assign n4596 = n4200 == 12'b101100011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:102 */
  assign n4597 = n4594 | n4596;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:608:33 */
  assign n4599 = n4200 == 12'b101110000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:608:33 */
  assign n4600 = n4597 | n4599;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:33 */
  assign n4602 = n4200 == 12'b101110000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:33 */
  assign n4603 = n4600 | n4602;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:56 */
  assign n4605 = n4200 == 12'b101110000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:56 */
  assign n4606 = n4603 | n4605;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:79 */
  assign n4608 = n4200 == 12'b101110000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:79 */
  assign n4609 = n4606 | n4608;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:102 */
  assign n4611 = n4200 == 12'b101110000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:102 */
  assign n4612 = n4609 | n4611;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:33 */
  assign n4614 = n4200 == 12'b101110001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:33 */
  assign n4615 = n4612 | n4614;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:56 */
  assign n4617 = n4200 == 12'b101110001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:56 */
  assign n4618 = n4615 | n4617;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:79 */
  assign n4620 = n4200 == 12'b101110001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:79 */
  assign n4621 = n4618 | n4620;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:102 */
  assign n4623 = n4200 == 12'b101110001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:102 */
  assign n4624 = n4621 | n4623;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:33 */
  assign n4626 = n4200 == 12'b101110001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:33 */
  assign n4627 = n4624 | n4626;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:56 */
  assign n4629 = n4200 == 12'b101110001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:56 */
  assign n4630 = n4627 | n4629;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:79 */
  assign n4632 = n4200 == 12'b101110001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:79 */
  assign n4633 = n4630 | n4632;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:102 */
  assign n4635 = n4200 == 12'b101110001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:102 */
  assign n4636 = n4633 | n4635;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:33 */
  assign n4638 = n4200 == 12'b101110010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:33 */
  assign n4639 = n4636 | n4638;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:56 */
  assign n4641 = n4200 == 12'b101110010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:56 */
  assign n4642 = n4639 | n4641;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:79 */
  assign n4644 = n4200 == 12'b101110010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:79 */
  assign n4645 = n4642 | n4644;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:102 */
  assign n4647 = n4200 == 12'b101110010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:102 */
  assign n4648 = n4645 | n4647;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:33 */
  assign n4650 = n4200 == 12'b101110010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:33 */
  assign n4651 = n4648 | n4650;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:56 */
  assign n4653 = n4200 == 12'b101110010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:56 */
  assign n4654 = n4651 | n4653;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:79 */
  assign n4656 = n4200 == 12'b101110010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:79 */
  assign n4657 = n4654 | n4656;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:102 */
  assign n4659 = n4200 == 12'b101110010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:102 */
  assign n4660 = n4657 | n4659;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:33 */
  assign n4662 = n4200 == 12'b101110011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:33 */
  assign n4663 = n4660 | n4662;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:56 */
  assign n4665 = n4200 == 12'b101110011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:56 */
  assign n4666 = n4663 | n4665;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:79 */
  assign n4668 = n4200 == 12'b101110011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:79 */
  assign n4669 = n4666 | n4668;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:102 */
  assign n4671 = n4200 == 12'b101110011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:102 */
  assign n4672 = n4669 | n4671;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:33 */
  assign n4674 = n4200 == 12'b101110011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:33 */
  assign n4675 = n4672 | n4674;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:56 */
  assign n4677 = n4200 == 12'b101110011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:56 */
  assign n4678 = n4675 | n4677;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:79 */
  assign n4680 = n4200 == 12'b101110011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:79 */
  assign n4681 = n4678 | n4680;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:102 */
  assign n4683 = n4200 == 12'b101110011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:102 */
  assign n4684 = n4681 | n4683;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:616:33 */
  assign n4686 = n4200 == 12'b001100100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:616:33 */
  assign n4687 = n4684 | n4686;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:33 */
  assign n4689 = n4200 == 12'b001100100100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:33 */
  assign n4690 = n4687 | n4689;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:56 */
  assign n4692 = n4200 == 12'b001100100101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:56 */
  assign n4693 = n4690 | n4692;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:79 */
  assign n4695 = n4200 == 12'b001100100110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:79 */
  assign n4696 = n4693 | n4695;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:102 */
  assign n4698 = n4200 == 12'b001100100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:102 */
  assign n4699 = n4696 | n4698;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:33 */
  assign n4701 = n4200 == 12'b001100101000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:33 */
  assign n4702 = n4699 | n4701;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:56 */
  assign n4704 = n4200 == 12'b001100101001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:56 */
  assign n4705 = n4702 | n4704;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:79 */
  assign n4707 = n4200 == 12'b001100101010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:79 */
  assign n4708 = n4705 | n4707;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:102 */
  assign n4710 = n4200 == 12'b001100101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:102 */
  assign n4711 = n4708 | n4710;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:33 */
  assign n4713 = n4200 == 12'b001100101100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:33 */
  assign n4714 = n4711 | n4713;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:56 */
  assign n4716 = n4200 == 12'b001100101101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:56 */
  assign n4717 = n4714 | n4716;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:79 */
  assign n4719 = n4200 == 12'b001100101110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:79 */
  assign n4720 = n4717 | n4719;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:102 */
  assign n4722 = n4200 == 12'b001100101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:102 */
  assign n4723 = n4720 | n4722;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:33 */
  assign n4725 = n4200 == 12'b001100110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:33 */
  assign n4726 = n4723 | n4725;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:56 */
  assign n4728 = n4200 == 12'b001100110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:56 */
  assign n4729 = n4726 | n4728;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:79 */
  assign n4731 = n4200 == 12'b001100110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:79 */
  assign n4732 = n4729 | n4731;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:102 */
  assign n4734 = n4200 == 12'b001100110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:102 */
  assign n4735 = n4732 | n4734;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:33 */
  assign n4737 = n4200 == 12'b001100110100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:33 */
  assign n4738 = n4735 | n4737;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:56 */
  assign n4740 = n4200 == 12'b001100110101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:56 */
  assign n4741 = n4738 | n4740;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:79 */
  assign n4743 = n4200 == 12'b001100110110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:79 */
  assign n4744 = n4741 | n4743;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:102 */
  assign n4746 = n4200 == 12'b001100110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:102 */
  assign n4747 = n4744 | n4746;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:33 */
  assign n4749 = n4200 == 12'b001100111000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:33 */
  assign n4750 = n4747 | n4749;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:56 */
  assign n4752 = n4200 == 12'b001100111001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:56 */
  assign n4753 = n4750 | n4752;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:79 */
  assign n4755 = n4200 == 12'b001100111010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:79 */
  assign n4756 = n4753 | n4755;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:102 */
  assign n4758 = n4200 == 12'b001100111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:102 */
  assign n4759 = n4756 | n4758;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:33 */
  assign n4761 = n4200 == 12'b001100111100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:33 */
  assign n4762 = n4759 | n4761;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:56 */
  assign n4764 = n4200 == 12'b001100111101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:56 */
  assign n4765 = n4762 | n4764;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:79 */
  assign n4767 = n4200 == 12'b001100111110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:79 */
  assign n4768 = n4765 | n4767;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:102 */
  assign n4770 = n4200 == 12'b001100111111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:102 */
  assign n4771 = n4768 | n4770;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:7 */
  assign n4775 = n4200 == 12'b110000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:25 */
  assign n4777 = n4200 == 12'b110000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:25 */
  assign n4778 = n4775 | n4777;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:39 */
  assign n4780 = n4200 == 12'b110000000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:39 */
  assign n4781 = n4778 | n4780;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:56 */
  assign n4783 = n4200 == 12'b101100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:56 */
  assign n4784 = n4781 | n4783;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:72 */
  assign n4786 = n4200 == 12'b101100000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:72 */
  assign n4787 = n4784 | n4786;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:89 */
  assign n4789 = n4200 == 12'b110010000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:89 */
  assign n4790 = n4787 | n4789;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:25 */
  assign n4792 = n4200 == 12'b110010000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:25 */
  assign n4793 = n4790 | n4792;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:39 */
  assign n4795 = n4200 == 12'b110010000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:39 */
  assign n4796 = n4793 | n4795;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:56 */
  assign n4798 = n4200 == 12'b101110000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:56 */
  assign n4799 = n4796 | n4798;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:72 */
  assign n4801 = n4200 == 12'b101110000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:72 */
  assign n4802 = n4799 | n4801;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:7 */
  assign n4806 = n4200 == 12'b001100100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:28 */
  assign n4808 = n4200 == 12'b001100100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:28 */
  assign n4809 = n4806 | n4808;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:48 */
  assign n4811 = n4200 == 12'b011100100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:48 */
  assign n4812 = n4809 | n4811;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:67 */
  assign n4814 = n4200 == 12'b011100100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:67 */
  assign n4815 = n4812 | n4814;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:7 */
  assign n4819 = n4200 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:23 */
  assign n4821 = n4200 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:23 */
  assign n4822 = n4819 | n4821;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:35 */
  assign n4824 = n4200 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:35 */
  assign n4825 = n4822 | n4824;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:7 */
  assign n4829 = n4200 == 12'b011110100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:26 */
  assign n4831 = n4200 == 12'b011110100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:26 */
  assign n4832 = n4829 | n4831;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:41 */
  assign n4834 = n4200 == 12'b011110100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:41 */
  assign n4835 = n4832 | n4834;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:56 */
  assign n4837 = n4200 == 12'b011110100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:56 */
  assign n4838 = n4835 | n4837;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:71 */
  assign n4840 = n4200 == 12'b011110100100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:71 */
  assign n4841 = n4838 | n4840;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:5 */
  assign n4843 = {n4841, n4825, n4815, n4802, n4771, n4335, n4274, n4264, n4210};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:5 */
  always @*
    case (n4843)
      9'b100000000: n4844 = 1'b0;
      9'b010000000: n4844 = 1'b0;
      9'b001000000: n4844 = 1'b0;
      9'b000100000: n4844 = 1'b0;
      9'b000010000: n4844 = 1'b0;
      9'b000001000: n4844 = 1'b0;
      9'b000000100: n4844 = 1'b1;
      9'b000000010: n4844 = 1'b1;
      9'b000000001: n4844 = 1'b0;
      default: n4844 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:22 */
  assign n4845 = ctrl[178:177]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:37 */
  assign n4847 = n4845 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:17 */
  assign n4848 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:64 */
  assign n4850 = n4848 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:17 */
  assign n4851 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:64 */
  assign n4853 = n4851 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:83 */
  assign n4854 = n4850 | n4853;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:656:17 */
  assign n4855 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:656:58 */
  assign n4857 = n4855 != 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:83 */
  assign n4858 = n4854 | n4857;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:45 */
  assign n4859 = n4858 & n4847;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:5 */
  assign n4862 = n4859 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:25 */
  assign n4866 = ctrl[176:175]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:38 */
  assign n4868 = n4866 != 2'b00;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:56 */
  assign n4869 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:66 */
  assign n4870 = ~n4869;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:47 */
  assign n4871 = n4870 & n4868;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:5 */
  assign n4874 = n4871 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:17 */
  assign n4877 = exec[10:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:7 */
  assign n4879 = n4877 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:25 */
  assign n4881 = n4877 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:25 */
  assign n4882 = n4879 | n4881;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:42 */
  assign n4884 = n4877 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:42 */
  assign n4885 = n4882 | n4884;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:20 */
  assign n4886 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:67 */
  assign n4888 = n4886 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:9 */
  assign n4891 = n4888 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:692:7 */
  assign n4893 = n4877 == 7'b1100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:20 */
  assign n4894 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:69 */
  assign n4896 = n4894 != 2'b01;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:78 */
  assign n4898 = n4896 | 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:9 */
  assign n4901 = n4898 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:698:7 */
  assign n4903 = n4877 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:705:21 */
  assign n4904 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:11 */
  assign n4906 = n4904 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:28 */
  assign n4908 = n4904 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:28 */
  assign n4909 = n4906 | n4908;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:42 */
  assign n4911 = n4904 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:42 */
  assign n4912 = n4909 | n4911;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:56 */
  assign n4914 = n4904 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:56 */
  assign n4915 = n4912 | n4914;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:71 */
  assign n4917 = n4904 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:71 */
  assign n4918 = n4915 | n4917;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:705:9 */
  always @*
    case (n4918)
      1'b1: n4921 = 1'b0;
      default: n4921 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:704:7 */
  assign n4923 = n4877 == 7'b0000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:712:21 */
  assign n4924 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:11 */
  assign n4926 = n4924 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:28 */
  assign n4928 = n4924 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:28 */
  assign n4929 = n4926 | n4928;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:42 */
  assign n4931 = n4924 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:42 */
  assign n4932 = n4929 | n4931;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:712:9 */
  always @*
    case (n4932)
      1'b1: n4935 = 1'b0;
      default: n4935 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:711:7 */
  assign n4937 = n4877 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:718:7 */
  assign n4977 = n4877 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:7 */
  assign n4979 = n4877 == 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:25 */
  assign n4981 = n4877 == 7'b0010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:25 */
  assign n4982 = n4979 | n4981;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:41 */
  assign n4984 = n4877 == 7'b1010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:41 */
  assign n4985 = n4982 | n4984;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:56 */
  assign n4987 = n4877 == 7'b0111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:56 */
  assign n4988 = n4985 | n4987;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:72 */
  assign n4990 = n4877 == 7'b0011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:72 */
  assign n4991 = n4988 | n4990;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:89 */
  assign n4993 = n4877 == 7'b0001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:89 */
  assign n4994 = n4991 | n4993;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:106 */
  assign n4996 = n4877 == 7'b0101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:106 */
  assign n4997 = n4994 | n4996;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:20 */
  assign n4998 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:69 */
  assign n5000 = n4998 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:9 */
  assign n5003 = n5000 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:732:7 */
  assign n5005 = n4877 == 7'b0001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:20 */
  assign n5006 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:67 */
  assign n5008 = n5006 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:22 */
  assign n5009 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:63 */
  assign n5011 = n5009 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:86 */
  assign n5012 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:125 */
  assign n5014 = n5012 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:74 */
  assign n5015 = n5014 & n5011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:25 */
  assign n5016 = exec[35:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:742:15 */
  assign n5018 = n5016 == 12'b000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:743:15 */
  assign n5020 = n5016 == 12'b000000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:64 */
  assign n5021 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:56 */
  assign n5022 = ~n5021;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:89 */
  assign n5023 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:75 */
  assign n5024 = n5022 | n5023;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:15 */
  assign n5026 = n5016 == 12'b001100000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:70 */
  assign n5027 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:55 */
  assign n5028 = ~n5027;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:15 */
  assign n5030 = n5016 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:64 */
  assign n5031 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:56 */
  assign n5032 = ~n5031;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:83 */
  assign n5033 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:75 */
  assign n5034 = n5032 & n5033;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:15 */
  assign n5036 = n5016 == 12'b000100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:13 */
  assign n5037 = {n5036, n5030, n5026, n5020, n5018};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:13 */
  always @*
    case (n5037)
      5'b10000: n5041 = n5034;
      5'b01000: n5041 = n5028;
      5'b00100: n5041 = n5024;
      5'b00010: n5041 = 1'b0;
      5'b00001: n5041 = 1'b0;
      default: n5041 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:11 */
  assign n5043 = n5015 ? n5041 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:23 */
  assign n5044 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:70 */
  assign n5046 = n5044 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:756:26 */
  assign n5048 = csr_valid == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:756:9 */
  assign n5051 = n5048 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:9 */
  assign n5053 = n5046 ? 1'b1 : n5051;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:9 */
  assign n5054 = n5008 ? n5043 : n5053;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:738:7 */
  assign n5056 = n4877 == 7'b1110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:5 */
  assign n5057 = {n5056, n5005, n4997, n4977, n4937, n4923, n4903, n4893, n4885};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:5 */
  always @*
    case (n5057)
      9'b100000000: n5062 = n5054;
      9'b010000000: n5062 = n5003;
      9'b001000000: n5062 = 1'b0;
      9'b000100000: n5062 = 1'b1;
      9'b000010000: n5062 = n4935;
      9'b000001000: n5062 = n4921;
      9'b000000100: n5062 = n4901;
      9'b000000010: n5062 = n4891;
      9'b000000001: n5062 = 1'b0;
      default: n5062 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:772:16 */
  assign n5066 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:16 */
  assign n5068 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:22 */
  assign n5070 = n5068 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:776:64 */
  assign n5072 = monitor_cnt + 10'b0000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:7 */
  assign n5074 = n5070 ? n5072 : 10'b0000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:31 */
  assign n5080 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:37 */
  assign n5082 = n5080 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:59 */
  assign n5083 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:65 */
  assign n5085 = n5083 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:50 */
  assign n5086 = n5082 | n5085;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:787:37 */
  assign n5087 = monitor_cnt[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:787:59 */
  assign n5088 = n5087 | illegal_cmd;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:80 */
  assign n5089 = n5088 & n5086;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:19 */
  assign n5090 = n5089 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:798:16 */
  assign n5093 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:29 */
  assign n5095 = debug_ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:39 */
  assign n5096 = {n5095, irq_fast_i};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:52 */
  assign n5097 = {n5096, irq_machine_i};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:41 */
  assign n5098 = irq_pnd[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:98 */
  assign n5099 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:87 */
  assign n5100 = env_pend & n5099;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:74 */
  assign n5101 = n5098 | n5100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:41 */
  assign n5102 = irq_pnd[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:65 */
  assign n5103 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:57 */
  assign n5104 = n5102 & n5103;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:98 */
  assign n5105 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:87 */
  assign n5106 = env_pend & n5105;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:74 */
  assign n5107 = n5104 | n5106;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:41 */
  assign n5108 = irq_pnd[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:65 */
  assign n5109 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:57 */
  assign n5110 = n5108 & n5109;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:98 */
  assign n5111 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:87 */
  assign n5112 = env_pend & n5111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:74 */
  assign n5113 = n5110 | n5112;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:41 */
  assign n5114 = irq_pnd[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:65 */
  assign n5115 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:57 */
  assign n5116 = n5114 & n5115;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:98 */
  assign n5117 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:87 */
  assign n5118 = env_pend & n5117;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:74 */
  assign n5119 = n5116 | n5118;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5120 = irq_pnd[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5121 = csr[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5122 = n5120 & n5121;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5123 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5124 = env_pend & n5123;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5125 = n5122 | n5124;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5126 = irq_pnd[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5127 = csr[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5128 = n5126 & n5127;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5129 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5130 = env_pend & n5129;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5131 = n5128 | n5130;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5132 = irq_pnd[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5133 = csr[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5134 = n5132 & n5133;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5135 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5136 = env_pend & n5135;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5137 = n5134 | n5136;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5138 = irq_pnd[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5139 = csr[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5140 = n5138 & n5139;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5141 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5142 = env_pend & n5141;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5143 = n5140 | n5142;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5144 = irq_pnd[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5145 = csr[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5146 = n5144 & n5145;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5147 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5148 = env_pend & n5147;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5149 = n5146 | n5148;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5150 = irq_pnd[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5151 = csr[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5152 = n5150 & n5151;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5153 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5154 = env_pend & n5153;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5155 = n5152 | n5154;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5156 = irq_pnd[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5157 = csr[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5158 = n5156 & n5157;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5159 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5160 = env_pend & n5159;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5161 = n5158 | n5160;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5162 = irq_pnd[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5163 = csr[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5164 = n5162 & n5163;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5165 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5166 = env_pend & n5165;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5167 = n5164 | n5166;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5168 = irq_pnd[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5169 = csr[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5170 = n5168 & n5169;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5171 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5172 = env_pend & n5171;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5173 = n5170 | n5172;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5174 = irq_pnd[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5175 = csr[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5176 = n5174 & n5175;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5177 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5178 = env_pend & n5177;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5179 = n5176 | n5178;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5180 = irq_pnd[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5181 = csr[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5182 = n5180 & n5181;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5183 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5184 = env_pend & n5183;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5185 = n5182 | n5184;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5186 = irq_pnd[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5187 = csr[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5188 = n5186 & n5187;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5189 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5190 = env_pend & n5189;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5191 = n5188 | n5190;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5192 = irq_pnd[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5193 = csr[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5194 = n5192 & n5193;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5195 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5196 = env_pend & n5195;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5197 = n5194 | n5196;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5198 = irq_pnd[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5199 = csr[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5200 = n5198 & n5199;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5201 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5202 = env_pend & n5201;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5203 = n5200 | n5202;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5204 = irq_pnd[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5205 = csr[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5206 = n5204 & n5205;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5207 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5208 = env_pend & n5207;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5209 = n5206 | n5208;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5210 = irq_pnd[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5211 = csr[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5212 = n5210 & n5211;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5213 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5214 = env_pend & n5213;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5215 = n5212 | n5214;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:41 */
  assign n5216 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:57 */
  assign n5217 = n5216 | instr_be;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:88 */
  assign n5218 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:83 */
  assign n5219 = n5217 & n5218;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:41 */
  assign n5220 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:57 */
  assign n5221 = n5220 | instr_il;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:88 */
  assign n5222 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:83 */
  assign n5223 = n5221 & n5222;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:41 */
  assign n5224 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:57 */
  assign n5225 = n5224 | instr_ma;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:88 */
  assign n5226 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:83 */
  assign n5227 = n5225 & n5226;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:41 */
  assign n5228 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:57 */
  assign n5229 = n5228 | ecall;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:88 */
  assign n5230 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:83 */
  assign n5231 = n5229 & n5230;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:41 */
  assign n5232 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:57 */
  assign n5233 = n5232 | ebreak_trig;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:88 */
  assign n5234 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:83 */
  assign n5235 = n5233 & n5234;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:41 */
  assign n5236 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:69 */
  assign n5237 = lsu_err_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:57 */
  assign n5238 = n5236 | n5237;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:88 */
  assign n5239 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:83 */
  assign n5240 = n5238 & n5239;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:41 */
  assign n5241 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:69 */
  assign n5242 = lsu_err_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:57 */
  assign n5243 = n5241 | n5242;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:88 */
  assign n5244 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:83 */
  assign n5245 = n5243 & n5244;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:41 */
  assign n5246 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:69 */
  assign n5247 = lsu_err_i[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:57 */
  assign n5248 = n5246 | n5247;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:88 */
  assign n5249 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:83 */
  assign n5250 = n5248 & n5249;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:41 */
  assign n5251 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:69 */
  assign n5252 = lsu_err_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:57 */
  assign n5253 = n5251 | n5252;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:88 */
  assign n5254 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:83 */
  assign n5255 = n5253 & n5254;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:41 */
  assign n5256 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:71 */
  assign n5257 = debug_ctrl[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:57 */
  assign n5258 = n5256 | n5257;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:88 */
  assign n5259 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:83 */
  assign n5260 = n5258 & n5259;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:41 */
  assign n5261 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:71 */
  assign n5262 = debug_ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:57 */
  assign n5263 = n5261 | n5262;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:88 */
  assign n5264 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:83 */
  assign n5265 = n5263 & n5264;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:41 */
  assign n5266 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:71 */
  assign n5267 = debug_ctrl[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:57 */
  assign n5268 = n5266 | n5267;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:88 */
  assign n5269 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:83 */
  assign n5270 = n5268 & n5269;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  assign n5271 = {n5270, n5265, n5260, n5255, n5250, n5245, n5240, n5235, n5231, n5227, n5223, n5219};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  assign n5274 = {n5101, n5215, n5209, n5203, n5197, n5191, n5185, n5179, n5173, n5167, n5161, n5155, n5149, n5143, n5137, n5131, n5125, n5113, n5119, n5107};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:39 */
  assign n5283 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:26 */
  assign n5284 = ebreak & n5283;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:63 */
  assign n5285 = csr[191]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:55 */
  assign n5286 = ~n5285;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:50 */
  assign n5287 = n5284 & n5286;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:97 */
  assign n5288 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:82 */
  assign n5289 = ~n5288;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:77 */
  assign n5290 = n5287 & n5289;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:39 */
  assign n5291 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:31 */
  assign n5292 = ~n5291;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:26 */
  assign n5293 = ebreak & n5292;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:63 */
  assign n5294 = csr[192]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:55 */
  assign n5295 = ~n5294;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:50 */
  assign n5296 = n5293 & n5295;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:97 */
  assign n5297 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:82 */
  assign n5298 = ~n5297;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:77 */
  assign n5299 = n5296 & n5298;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:103 */
  assign n5300 = n5290 | n5299;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:838:16 */
  assign n5302 = ~rstn_i;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5310 = irq_fire[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5312 = 1'b0 | n5310;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5314 = irq_fire[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5315 = n5312 | n5314;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:843:30 */
  assign n5316 = exc_fire | n5315;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:843:7 */
  assign n5318 = n5316 ? 1'b1 : env_pend;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:841:7 */
  assign n5320 = env_enter ? 1'b0 : n5318;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5331 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5333 = 1'b0 | n5331;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5335 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5336 = n5333 | n5335;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5337 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5338 = n5336 | n5337;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5339 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5340 = n5338 | n5339;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5341 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5342 = n5340 | n5341;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5343 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5344 = n5342 | n5343;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5345 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5346 = n5344 | n5345;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5347 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5348 = n5346 | n5347;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5349 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5350 = n5348 | n5349;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5351 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5352 = n5350 | n5351;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5353 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5354 = n5352 | n5353;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5355 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5356 = n5354 | n5355;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:12 */
  assign n5358 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:18 */
  assign n5360 = n5358 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:40 */
  assign n5361 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:46 */
  assign n5363 = n5361 == 4'b1010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:31 */
  assign n5364 = n5360 | n5363;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5372 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5374 = 1'b0 | n5372;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5376 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5377 = n5374 | n5376;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5378 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5379 = n5377 | n5378;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5380 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5381 = n5379 | n5380;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5382 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5383 = n5381 | n5382;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5384 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5385 = n5383 | n5384;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5386 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5387 = n5385 | n5386;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5388 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5389 = n5387 | n5388;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5390 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5391 = n5389 | n5390;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5392 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5393 = n5391 | n5392;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5394 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5395 = n5393 | n5394;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5396 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5397 = n5395 | n5396;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5398 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5399 = n5397 | n5398;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5400 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5401 = n5399 | n5400;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5402 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5403 = n5401 | n5402;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5404 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5405 = n5403 | n5404;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5406 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5407 = n5405 | n5406;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5408 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5409 = n5407 | n5408;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5410 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5411 = n5409 | n5410;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:58 */
  assign n5412 = n5411 & n5364;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:11 */
  assign n5413 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:38 */
  assign n5414 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:48 */
  assign n5415 = ~n5414;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:30 */
  assign n5416 = n5413 | n5415;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:855:70 */
  assign n5417 = n5416 & n5412;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:17 */
  assign n5418 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:21 */
  assign n5419 = ~n5418;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:66 */
  assign n5420 = n5419 & n5417;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:37 */
  assign n5421 = csr[193]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:47 */
  assign n5422 = ~n5421;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:28 */
  assign n5423 = n5422 & n5420;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:853:22 */
  assign n5424 = n5423 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:860:25 */
  assign n5426 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:33 */
  assign n5428 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:20 */
  assign n5429 = n5428 ? 7'b0000001 : n5432;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:868:33 */
  assign n5431 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:56 */
  assign n5432 = n5431 ? 7'b0000010 : n5435;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:869:33 */
  assign n5434 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:868:56 */
  assign n5435 = n5434 ? 7'b0000000 : n5437;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:870:33 */
  assign n5436 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:869:56 */
  assign n5437 = n5436 ? trap_env : n5440;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:871:33 */
  assign n5439 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:870:56 */
  assign n5440 = n5439 ? 7'b0000011 : n5443;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:872:33 */
  assign n5442 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:871:56 */
  assign n5443 = n5442 ? 7'b0000110 : n5446;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:873:33 */
  assign n5445 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:872:56 */
  assign n5446 = n5445 ? 7'b0000100 : n5449;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:874:33 */
  assign n5448 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:873:56 */
  assign n5449 = n5448 ? 7'b0000111 : n5452;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:875:33 */
  assign n5451 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:874:56 */
  assign n5452 = n5451 ? 7'b0000101 : n5455;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:877:33 */
  assign n5454 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:875:56 */
  assign n5455 = n5454 ? 7'b1100011 : n5458;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:878:33 */
  assign n5457 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:877:56 */
  assign n5458 = n5457 ? 7'b1100010 : n5461;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:879:33 */
  assign n5460 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:878:56 */
  assign n5461 = n5460 ? 7'b0100001 : n5464;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:880:33 */
  assign n5463 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:879:56 */
  assign n5464 = n5463 ? 7'b1100100 : n5467;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:882:33 */
  assign n5466 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:880:56 */
  assign n5467 = n5466 ? 7'b1010000 : n5470;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:883:33 */
  assign n5469 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:882:56 */
  assign n5470 = n5469 ? 7'b1010001 : n5473;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:884:33 */
  assign n5472 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:883:56 */
  assign n5473 = n5472 ? 7'b1010010 : n5476;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:885:33 */
  assign n5475 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:884:56 */
  assign n5476 = n5475 ? 7'b1010011 : n5479;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:886:33 */
  assign n5478 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:885:56 */
  assign n5479 = n5478 ? 7'b1010100 : n5482;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:887:33 */
  assign n5481 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:886:56 */
  assign n5482 = n5481 ? 7'b1010101 : n5485;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:888:33 */
  assign n5484 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:887:56 */
  assign n5485 = n5484 ? 7'b1010110 : n5488;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:889:33 */
  assign n5487 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:888:56 */
  assign n5488 = n5487 ? 7'b1010111 : n5491;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:890:33 */
  assign n5490 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:889:56 */
  assign n5491 = n5490 ? 7'b1011000 : n5494;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:891:33 */
  assign n5493 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:890:56 */
  assign n5494 = n5493 ? 7'b1011001 : n5497;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:892:33 */
  assign n5496 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:891:56 */
  assign n5497 = n5496 ? 7'b1011010 : n5500;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:893:33 */
  assign n5499 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:892:56 */
  assign n5500 = n5499 ? 7'b1011011 : n5503;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:894:33 */
  assign n5502 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:893:56 */
  assign n5503 = n5502 ? 7'b1011100 : n5506;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:895:33 */
  assign n5505 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:894:56 */
  assign n5506 = n5505 ? 7'b1011101 : n5509;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:896:33 */
  assign n5508 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:895:56 */
  assign n5509 = n5508 ? 7'b1011110 : n5512;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:897:33 */
  assign n5511 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:896:56 */
  assign n5512 = n5511 ? 7'b1011111 : n5515;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:899:33 */
  assign n5514 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:897:56 */
  assign n5515 = n5514 ? 7'b1001011 : n5518;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:900:33 */
  assign n5517 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:899:56 */
  assign n5518 = n5517 ? 7'b1000011 : 7'b1000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:44 */
  assign n5520 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:38 */
  assign n5522 = {5'b00010, n5520};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:60 */
  assign n5523 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:54 */
  assign n5524 = {n5522, n5523};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:15 */
  assign n5525 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:31 */
  assign n5526 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:19 */
  assign n5527 = n5526 ? n5525 : n5528;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:52 */
  assign n5528 = exec[84:53]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:16 */
  assign n5556 = exec[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:37 */
  assign n5557 = ~n5556;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:980:48 */
  assign n5559 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:980:39 */
  assign n5561 = {27'b000000000000000000000000000, n5559};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:5 */
  assign n5562 = n5557 ? rf_rs1_i : n5561;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:17 */
  assign n5563 = exec[17:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:983:45 */
  assign n5564 = csr_rdata | n5562;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:983:7 */
  assign n5566 = n5563 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:50 */
  assign n5567 = ~n5562;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:45 */
  assign n5568 = csr_rdata & n5567;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:7 */
  assign n5570 = n5563 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:5 */
  assign n5571 = {n5570, n5566};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:5 */
  always @*
    case (n5571)
      2'b10: n5572 = n5568;
      2'b01: n5572 = n5564;
      default: n5572 = n5562;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:994:16 */
  assign n5575 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:16 */
  assign n5600 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:19 */
  assign n5601 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1027:42 */
  assign n5602 = csr_wdata[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1028:42 */
  assign n5603 = csr_wdata[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5611 = csr_wdata[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5613 = 1'b1 & n5611;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5615 = csr_wdata[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5616 = n5613 & n5615;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1030:42 */
  assign n5617 = csr_wdata[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1031:42 */
  assign n5618 = csr_wdata[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1026:11 */
  assign n5620 = n5601 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1034:38 */
  assign n5621 = csr_wdata[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1035:38 */
  assign n5622 = csr_wdata[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1036:38 */
  assign n5623 = csr_wdata[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1037:38 */
  assign n5624 = csr_wdata[31:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1033:11 */
  assign n5626 = n5601 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:35 */
  assign n5627 = csr_wdata[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:49 */
  assign n5629 = {n5627, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:66 */
  assign n5630 = csr_wdata[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:55 */
  assign n5631 = {n5629, n5630};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1039:11 */
  assign n5633 = n5601 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1042:11 */
  assign n5635 = n5601 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1045:11 */
  assign n5637 = n5601 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1049:34 */
  assign n5638 = csr_wdata[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1049:48 */
  assign n5640 = {n5638, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1048:11 */
  assign n5642 = n5601 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:36 */
  assign n5643 = csr_wdata[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:52 */
  assign n5644 = csr_wdata[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:41 */
  assign n5645 = {n5643, n5644};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1051:11 */
  assign n5647 = n5601 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1054:11 */
  assign n5649 = n5601 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1058:42 */
  assign n5650 = csr_wdata[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1059:42 */
  assign n5651 = csr_wdata[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1060:42 */
  assign n5652 = csr_wdata[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5660 = csr_wdata[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5662 = 1'b1 & n5660;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5664 = csr_wdata[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5665 = n5662 & n5664;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1057:11 */
  assign n5667 = n5601 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1063:11 */
  assign n5672 = n5601 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1066:11 */
  assign n5674 = n5601 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  assign n5675 = {n5674, n5672, n5667, n5649, n5647, n5642, n5637, n5635, n5633, n5626, n5620};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5676 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5677 = n5676;
      11'b01000000000: n5677 = n5676;
      11'b00100000000: n5677 = n5676;
      11'b00010000000: n5677 = n5676;
      11'b00001000000: n5677 = n5676;
      11'b00000100000: n5677 = n5676;
      11'b00000010000: n5677 = n5676;
      11'b00000001000: n5677 = n5676;
      11'b00000000100: n5677 = n5676;
      11'b00000000010: n5677 = n5676;
      11'b00000000001: n5677 = n5602;
      default: n5677 = n5676;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5678 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5679 = n5678;
      11'b01000000000: n5679 = n5678;
      11'b00100000000: n5679 = n5678;
      11'b00010000000: n5679 = n5678;
      11'b00001000000: n5679 = n5678;
      11'b00000100000: n5679 = n5678;
      11'b00000010000: n5679 = n5678;
      11'b00000001000: n5679 = n5678;
      11'b00000000100: n5679 = n5678;
      11'b00000000010: n5679 = n5678;
      11'b00000000001: n5679 = n5603;
      default: n5679 = n5678;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5680 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5681 = n5680;
      11'b01000000000: n5681 = n5680;
      11'b00100000000: n5681 = n5680;
      11'b00010000000: n5681 = n5680;
      11'b00001000000: n5681 = n5680;
      11'b00000100000: n5681 = n5680;
      11'b00000010000: n5681 = n5680;
      11'b00000001000: n5681 = n5680;
      11'b00000000100: n5681 = n5680;
      11'b00000000010: n5681 = n5680;
      11'b00000000001: n5681 = n5616;
      default: n5681 = n5680;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5682 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5683 = n5682;
      11'b01000000000: n5683 = n5682;
      11'b00100000000: n5683 = n5682;
      11'b00010000000: n5683 = n5682;
      11'b00001000000: n5683 = n5682;
      11'b00000100000: n5683 = n5682;
      11'b00000010000: n5683 = n5682;
      11'b00000001000: n5683 = n5682;
      11'b00000000100: n5683 = n5682;
      11'b00000000010: n5683 = n5682;
      11'b00000000001: n5683 = n5617;
      default: n5683 = n5682;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5684 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5685 = n5684;
      11'b01000000000: n5685 = n5684;
      11'b00100000000: n5685 = n5684;
      11'b00010000000: n5685 = n5684;
      11'b00001000000: n5685 = n5684;
      11'b00000100000: n5685 = n5684;
      11'b00000010000: n5685 = n5684;
      11'b00000001000: n5685 = n5684;
      11'b00000000100: n5685 = n5684;
      11'b00000000010: n5685 = n5684;
      11'b00000000001: n5685 = n5618;
      default: n5685 = n5684;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5686 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5687 = n5686;
      11'b01000000000: n5687 = n5686;
      11'b00100000000: n5687 = n5686;
      11'b00010000000: n5687 = n5686;
      11'b00001000000: n5687 = n5686;
      11'b00000100000: n5687 = n5686;
      11'b00000010000: n5687 = n5686;
      11'b00000001000: n5687 = n5686;
      11'b00000000100: n5687 = n5686;
      11'b00000000010: n5687 = n5621;
      11'b00000000001: n5687 = n5686;
      default: n5687 = n5686;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5688 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5689 = n5688;
      11'b01000000000: n5689 = n5688;
      11'b00100000000: n5689 = n5688;
      11'b00010000000: n5689 = n5688;
      11'b00001000000: n5689 = n5688;
      11'b00000100000: n5689 = n5688;
      11'b00000010000: n5689 = n5688;
      11'b00000001000: n5689 = n5688;
      11'b00000000100: n5689 = n5688;
      11'b00000000010: n5689 = n5623;
      11'b00000000001: n5689 = n5688;
      default: n5689 = n5688;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5690 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5691 = n5690;
      11'b01000000000: n5691 = n5690;
      11'b00100000000: n5691 = n5690;
      11'b00010000000: n5691 = n5690;
      11'b00001000000: n5691 = n5690;
      11'b00000100000: n5691 = n5690;
      11'b00000010000: n5691 = n5690;
      11'b00000001000: n5691 = n5690;
      11'b00000000100: n5691 = n5690;
      11'b00000000010: n5691 = n5622;
      11'b00000000001: n5691 = n5690;
      default: n5691 = n5690;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5692 = csr[24:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5693 = n5692;
      11'b01000000000: n5693 = n5692;
      11'b00100000000: n5693 = n5692;
      11'b00010000000: n5693 = n5692;
      11'b00001000000: n5693 = n5692;
      11'b00000100000: n5693 = n5692;
      11'b00000010000: n5693 = n5692;
      11'b00000001000: n5693 = n5692;
      11'b00000000100: n5693 = n5692;
      11'b00000000010: n5693 = n5624;
      11'b00000000001: n5693 = n5692;
      default: n5693 = n5692;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5694 = csr[56:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5695 = n5694;
      11'b01000000000: n5695 = n5694;
      11'b00100000000: n5695 = n5694;
      11'b00010000000: n5695 = n5694;
      11'b00001000000: n5695 = n5694;
      11'b00000100000: n5695 = n5640;
      11'b00000010000: n5695 = n5694;
      11'b00000001000: n5695 = n5694;
      11'b00000000100: n5695 = n5694;
      11'b00000000010: n5695 = n5694;
      11'b00000000001: n5695 = n5694;
      default: n5695 = n5694;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5696 = csr[62:57]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5697 = n5696;
      11'b01000000000: n5697 = n5696;
      11'b00100000000: n5697 = n5696;
      11'b00010000000: n5697 = n5696;
      11'b00001000000: n5697 = n5645;
      11'b00000100000: n5697 = n5696;
      11'b00000010000: n5697 = n5696;
      11'b00000001000: n5697 = n5696;
      11'b00000000100: n5697 = n5696;
      11'b00000000010: n5697 = n5696;
      11'b00000000001: n5697 = n5696;
      default: n5697 = n5696;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5698 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5699 = n5698;
      11'b01000000000: n5699 = n5698;
      11'b00100000000: n5699 = n5698;
      11'b00010000000: n5699 = n5698;
      11'b00001000000: n5699 = n5698;
      11'b00000100000: n5699 = n5698;
      11'b00000010000: n5699 = n5698;
      11'b00000001000: n5699 = n5698;
      11'b00000000100: n5699 = n5631;
      11'b00000000010: n5699 = n5698;
      11'b00000000001: n5699 = n5698;
      default: n5699 = n5698;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5700 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5701 = n5700;
      11'b01000000000: n5701 = n5700;
      11'b00100000000: n5701 = n5700;
      11'b00010000000: n5701 = csr_wdata;
      11'b00001000000: n5701 = n5700;
      11'b00000100000: n5701 = n5700;
      11'b00000010000: n5701 = n5700;
      11'b00000001000: n5701 = n5700;
      11'b00000000100: n5701 = n5700;
      11'b00000000010: n5701 = n5700;
      11'b00000000001: n5701 = n5700;
      default: n5701 = n5700;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5702 = csr[158:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5703 = n5702;
      11'b01000000000: n5703 = n5702;
      11'b00100000000: n5703 = n5702;
      11'b00010000000: n5703 = n5702;
      11'b00001000000: n5703 = n5702;
      11'b00000100000: n5703 = n5702;
      11'b00000010000: n5703 = csr_wdata;
      11'b00000001000: n5703 = n5702;
      11'b00000000100: n5703 = n5702;
      11'b00000000010: n5703 = n5702;
      11'b00000000001: n5703 = n5702;
      default: n5703 = n5702;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5704 = csr[190:159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5705 = n5704;
      11'b01000000000: n5705 = n5704;
      11'b00100000000: n5705 = n5704;
      11'b00010000000: n5705 = n5704;
      11'b00001000000: n5705 = n5704;
      11'b00000100000: n5705 = n5704;
      11'b00000010000: n5705 = n5704;
      11'b00000001000: n5705 = csr_wdata;
      11'b00000000100: n5705 = n5704;
      11'b00000000010: n5705 = n5704;
      11'b00000000001: n5705 = n5704;
      default: n5705 = n5704;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5706 = csr[191]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5707 = n5706;
      11'b01000000000: n5707 = n5706;
      11'b00100000000: n5707 = n5652;
      11'b00010000000: n5707 = n5706;
      11'b00001000000: n5707 = n5706;
      11'b00000100000: n5707 = n5706;
      11'b00000010000: n5707 = n5706;
      11'b00000001000: n5707 = n5706;
      11'b00000000100: n5707 = n5706;
      11'b00000000010: n5707 = n5706;
      11'b00000000001: n5707 = n5706;
      default: n5707 = n5706;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5708 = csr[192]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5709 = n5708;
      11'b01000000000: n5709 = n5708;
      11'b00100000000: n5709 = n5651;
      11'b00010000000: n5709 = n5708;
      11'b00001000000: n5709 = n5708;
      11'b00000100000: n5709 = n5708;
      11'b00000010000: n5709 = n5708;
      11'b00000001000: n5709 = n5708;
      11'b00000000100: n5709 = n5708;
      11'b00000000010: n5709 = n5708;
      11'b00000000001: n5709 = n5708;
      default: n5709 = n5708;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5710 = csr[193]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5711 = n5710;
      11'b01000000000: n5711 = n5710;
      11'b00100000000: n5711 = n5650;
      11'b00010000000: n5711 = n5710;
      11'b00001000000: n5711 = n5710;
      11'b00000100000: n5711 = n5710;
      11'b00000010000: n5711 = n5710;
      11'b00000001000: n5711 = n5710;
      11'b00000000100: n5711 = n5710;
      11'b00000000010: n5711 = n5710;
      11'b00000000001: n5711 = n5710;
      default: n5711 = n5710;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5712 = csr[194]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5675)
      11'b10000000000: n5713 = n5712;
      11'b01000000000: n5713 = n5712;
      11'b00100000000: n5713 = n5665;
      11'b00010000000: n5713 = n5712;
      11'b00001000000: n5713 = n5712;
      11'b00000100000: n5713 = n5712;
      11'b00000010000: n5713 = n5712;
      11'b00000001000: n5713 = n5712;
      11'b00000000100: n5713 = n5712;
      11'b00000000010: n5713 = n5712;
      11'b00000000001: n5713 = n5712;
      default: n5713 = n5712;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:24 */
  assign n5718 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:28 */
  assign n5719 = ~n5718;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1086:37 */
  assign n5721 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1088:37 */
  assign n5723 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:39 */
  assign n5724 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:51 */
  assign n5725 = ecause[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:43 */
  assign n5726 = {n5724, n5725};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1090:36 */
  assign n5727 = epc[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1090:50 */
  assign n5729 = {n5727, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:23 */
  assign n5730 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:27 */
  assign n5731 = ~n5730;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1092:25 */
  assign n5732 = ecause[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:28 */
  assign n5733 = ecause[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:41 */
  assign n5735 = n5733 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:42 */
  assign n5736 = exec[52]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:32 */
  assign n5738 = n5736 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1096:47 */
  assign n5739 = exec[51:36]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1096:40 */
  assign n5741 = {16'b0000000000000000, n5739};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1098:37 */
  assign n5742 = exec[35:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:17 */
  assign n5743 = n5738 ? n5741 : n5742;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:15 */
  assign n5745 = n5735 ? n5743 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1092:15 */
  assign n5746 = n5732 ? lsu_mar_i : n5745;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:13 */
  assign n5748 = n5731 ? n5746 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5749 = {n5721, n5723, 1'b0, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5750 = {n5726, n5729};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5751 = csr[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5752 = n5719 ? n5749 : n5751;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5753 = csr[62:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5754 = n5776 ? n5750 : n5753;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5755 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5756 = n5778 ? n5748 : n5755;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1121:32 */
  assign n5757 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:19 */
  assign n5758 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:31 */
  assign n5760 = n5758 != 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5762 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:11 */
  assign n5763 = n5760 ? 1'b0 : n5762;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1126:35 */
  assign n5765 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5767 = {n5763, 1'b0, 1'b1, n5765, n5757};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5768 = csr[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5769 = env_exit ? n5767 : n5768;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5770 = n5769[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5771 = env_enter ? n5752 : n5770;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5772 = n5769[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5773 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5774 = env_enter ? n5773 : n5772;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5776 = n5719 & env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5778 = n5719 & env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5779 = {n5774, n5771};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5780 = {n5713, n5711, n5709, n5707, n5705, n5703, n5701, n5699, n5697, n5695, n5693, n5691, n5689, n5687, n5685, n5683, n5681, n5679, n5677};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5782 = n5779[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5783 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5784 = n5600 ? n5783 : n5782;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5785 = n5779[4:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5786 = n5780[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5787 = n5600 ? n5786 : n5785;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5788 = n5780[23:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5789 = csr[24:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5790 = n5600 ? n5788 : n5789;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5791 = n5780[61:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5792 = n5600 ? n5791 : n5754;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5793 = n5780[93:62]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5794 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5795 = n5600 ? n5793 : n5794;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5796 = n5780[125:94]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5797 = n5600 ? n5796 : n5756;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5798 = n5780[193:126]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5799 = csr[194:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5800 = n5600 ? n5798 : n5799;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5805 = n5800[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1018:5 */
  assign n5819 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 29'b00000000000000000000000000000, 3'b000, n5805, n5797, n5795, n5792, n5790, n5787, n5784};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:994:5 */
  assign n5821 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 6'b000000, 32'b00000000000000000000000000000000, 16'b0000000000000000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1176:16 */
  assign n5825 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:16 */
  assign n5827 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:19 */
  assign n5828 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1187:34 */
  assign n5829 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1188:34 */
  assign n5830 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1189:34 */
  assign n5831 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1190:34 */
  assign n5832 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1191:34 */
  assign n5833 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1192:34 */
  assign n5834 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1192:45 */
  assign n5837 = n5834 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1186:11 */
  assign n5839 = n5828 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1194:11 */
  assign n5857 = n5828 == 12'b001100000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1206:34 */
  assign n5858 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1207:34 */
  assign n5859 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1208:34 */
  assign n5860 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n5861 = csr[24:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1205:11 */
  assign n5863 = n5828 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5864 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1211:11 */
  assign n5866 = n5828 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1214:11 */
  assign n5868 = n5828 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5869 = csr[158:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1222:11 */
  assign n5871 = n5828 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:34 */
  assign n5872 = csr[56:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5874 = {n5872, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1225:11 */
  assign n5876 = n5828 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1229:40 */
  assign n5877 = csr[62]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5878 = csr[61:57]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1228:11 */
  assign n5880 = n5828 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5881 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1232:11 */
  assign n5883 = n5828 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1236:37 */
  assign n5884 = irq_pnd[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1237:37 */
  assign n5885 = irq_pnd[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1238:37 */
  assign n5886 = irq_pnd[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n5887 = irq_pnd[18:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1235:11 */
  assign n5889 = n5828 == 12'b001101000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1244:11 */
  assign n5891 = n5828 == 12'b111100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1245:11 */
  assign n5893 = n5828 == 12'b111100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1246:11 */
  assign n5895 = n5828 == 12'b111100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1247:11 */
  assign n5897 = n5828 == 12'b111100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1252:11 */
  assign n5899 = n5828 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1253:11 */
  assign n5901 = n5828 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1254:11 */
  assign n5903 = n5828 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1259:11 */
  assign n5967 = n5828 == 12'b111111000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1293:11 */
  assign n5973 = n5828 == 12'b111111000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  assign n5974 = {n5973, n5967, n5903, n5901, n5899, n5897, n5895, n5893, n5891, n5889, n5883, n5880, n5876, n5871, n5868, n5866, n5863, n5857, n5839};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5975 = n5864[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5976 = n5869[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5977 = n5874[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5978 = n5878[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5979 = n5881[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5984 = xcsr_rdata_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n5986 = 1'b0;
      19'b0100000000000000000: n5986 = 1'b1;
      19'b0010000000000000000: n5986 = 1'b0;
      19'b0001000000000000000: n5986 = 1'b0;
      19'b0000100000000000000: n5986 = 1'b0;
      19'b0000010000000000000: n5986 = 1'b0;
      19'b0000001000000000000: n5986 = 1'b0;
      19'b0000000100000000000: n5986 = 1'b1;
      19'b0000000010000000000: n5986 = 1'b0;
      19'b0000000001000000000: n5986 = 1'b0;
      19'b0000000000100000000: n5986 = n5979;
      19'b0000000000010000000: n5986 = n5978;
      19'b0000000000001000000: n5986 = n5977;
      19'b0000000000000100000: n5986 = n5976;
      19'b0000000000000010000: n5986 = 1'b0;
      19'b0000000000000001000: n5986 = n5975;
      19'b0000000000000000100: n5986 = 1'b0;
      19'b0000000000000000010: n5986 = 1'b0;
      19'b0000000000000000001: n5986 = 1'b0;
      default: n5986 = n5984;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5987 = n5864[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5988 = n5869[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5989 = n5874[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5990 = n5878[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5991 = n5881[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5996 = xcsr_rdata_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n5998 = 1'b0;
      19'b0100000000000000000: n5998 = 1'b1;
      19'b0010000000000000000: n5998 = 1'b0;
      19'b0001000000000000000: n5998 = 1'b0;
      19'b0000100000000000000: n5998 = 1'b0;
      19'b0000010000000000000: n5998 = 1'b0;
      19'b0000001000000000000: n5998 = 1'b1;
      19'b0000000100000000000: n5998 = 1'b1;
      19'b0000000010000000000: n5998 = 1'b0;
      19'b0000000001000000000: n5998 = 1'b0;
      19'b0000000000100000000: n5998 = n5991;
      19'b0000000000010000000: n5998 = n5990;
      19'b0000000000001000000: n5998 = n5989;
      19'b0000000000000100000: n5998 = n5988;
      19'b0000000000000010000: n5998 = 1'b0;
      19'b0000000000000001000: n5998 = n5987;
      19'b0000000000000000100: n5998 = 1'b0;
      19'b0000000000000000010: n5998 = 1'b0;
      19'b0000000000000000001: n5998 = 1'b0;
      default: n5998 = n5996;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5999 = n5864[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6000 = n5869[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6001 = n5874[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n6002 = n5878[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6003 = n5881[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6008 = xcsr_rdata_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6010 = 1'b0;
      19'b0100000000000000000: n6010 = 1'b0;
      19'b0010000000000000000: n6010 = 1'b0;
      19'b0001000000000000000: n6010 = 1'b0;
      19'b0000100000000000000: n6010 = 1'b0;
      19'b0000010000000000000: n6010 = 1'b0;
      19'b0000001000000000000: n6010 = 1'b0;
      19'b0000000100000000000: n6010 = 1'b0;
      19'b0000000010000000000: n6010 = 1'b0;
      19'b0000000001000000000: n6010 = 1'b0;
      19'b0000000000100000000: n6010 = n6003;
      19'b0000000000010000000: n6010 = n6002;
      19'b0000000000001000000: n6010 = n6001;
      19'b0000000000000100000: n6010 = n6000;
      19'b0000000000000010000: n6010 = 1'b0;
      19'b0000000000000001000: n6010 = n5999;
      19'b0000000000000000100: n6010 = 1'b0;
      19'b0000000000000000010: n6010 = 1'b1;
      19'b0000000000000000001: n6010 = 1'b0;
      default: n6010 = n6008;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6011 = n5864[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6012 = n5869[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6013 = n5874[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n6014 = n5878[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6015 = n5881[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6020 = xcsr_rdata_i[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6022 = 1'b0;
      19'b0100000000000000000: n6022 = 1'b0;
      19'b0010000000000000000: n6022 = 1'b0;
      19'b0001000000000000000: n6022 = 1'b0;
      19'b0000100000000000000: n6022 = 1'b0;
      19'b0000010000000000000: n6022 = 1'b0;
      19'b0000001000000000000: n6022 = 1'b0;
      19'b0000000100000000000: n6022 = 1'b0;
      19'b0000000010000000000: n6022 = 1'b0;
      19'b0000000001000000000: n6022 = n5884;
      19'b0000000000100000000: n6022 = n6015;
      19'b0000000000010000000: n6022 = n6014;
      19'b0000000000001000000: n6022 = n6013;
      19'b0000000000000100000: n6022 = n6012;
      19'b0000000000000010000: n6022 = 1'b0;
      19'b0000000000000001000: n6022 = n6011;
      19'b0000000000000000100: n6022 = n5858;
      19'b0000000000000000010: n6022 = 1'b0;
      19'b0000000000000000001: n6022 = n5829;
      default: n6022 = n6020;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6023 = n5864[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6024 = n5869[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6025 = n5874[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n6026 = n5878[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6027 = n5881[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6032 = xcsr_rdata_i[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6034 = 1'b0;
      19'b0100000000000000000: n6034 = 1'b0;
      19'b0010000000000000000: n6034 = 1'b0;
      19'b0001000000000000000: n6034 = 1'b0;
      19'b0000100000000000000: n6034 = 1'b0;
      19'b0000010000000000000: n6034 = 1'b0;
      19'b0000001000000000000: n6034 = 1'b0;
      19'b0000000100000000000: n6034 = 1'b1;
      19'b0000000010000000000: n6034 = 1'b0;
      19'b0000000001000000000: n6034 = 1'b0;
      19'b0000000000100000000: n6034 = n6027;
      19'b0000000000010000000: n6034 = n6026;
      19'b0000000000001000000: n6034 = n6025;
      19'b0000000000000100000: n6034 = n6024;
      19'b0000000000000010000: n6034 = 1'b0;
      19'b0000000000000001000: n6034 = n6023;
      19'b0000000000000000100: n6034 = 1'b0;
      19'b0000000000000000010: n6034 = 1'b0;
      19'b0000000000000000001: n6034 = 1'b0;
      default: n6034 = n6032;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6035 = n5864[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6036 = n5869[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6037 = n5874[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6038 = n5881[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6043 = xcsr_rdata_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6045 = 1'b0;
      19'b0100000000000000000: n6045 = 1'b0;
      19'b0010000000000000000: n6045 = 1'b0;
      19'b0001000000000000000: n6045 = 1'b0;
      19'b0000100000000000000: n6045 = 1'b0;
      19'b0000010000000000000: n6045 = 1'b0;
      19'b0000001000000000000: n6045 = 1'b0;
      19'b0000000100000000000: n6045 = 1'b0;
      19'b0000000010000000000: n6045 = 1'b0;
      19'b0000000001000000000: n6045 = 1'b0;
      19'b0000000000100000000: n6045 = n6038;
      19'b0000000000010000000: n6045 = 1'b0;
      19'b0000000000001000000: n6045 = n6037;
      19'b0000000000000100000: n6045 = n6036;
      19'b0000000000000010000: n6045 = 1'b0;
      19'b0000000000000001000: n6045 = n6035;
      19'b0000000000000000100: n6045 = 1'b0;
      19'b0000000000000000010: n6045 = 1'b0;
      19'b0000000000000000001: n6045 = 1'b0;
      default: n6045 = n6043;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6046 = n5864[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6047 = n5869[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6048 = n5874[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6049 = n5881[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6054 = xcsr_rdata_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6056 = 1'b0;
      19'b0100000000000000000: n6056 = 1'b0;
      19'b0010000000000000000: n6056 = 1'b0;
      19'b0001000000000000000: n6056 = 1'b0;
      19'b0000100000000000000: n6056 = 1'b0;
      19'b0000010000000000000: n6056 = 1'b0;
      19'b0000001000000000000: n6056 = 1'b0;
      19'b0000000100000000000: n6056 = 1'b0;
      19'b0000000010000000000: n6056 = 1'b0;
      19'b0000000001000000000: n6056 = 1'b0;
      19'b0000000000100000000: n6056 = n6049;
      19'b0000000000010000000: n6056 = 1'b0;
      19'b0000000000001000000: n6056 = n6048;
      19'b0000000000000100000: n6056 = n6047;
      19'b0000000000000010000: n6056 = 1'b0;
      19'b0000000000000001000: n6056 = n6046;
      19'b0000000000000000100: n6056 = 1'b0;
      19'b0000000000000000010: n6056 = 1'b0;
      19'b0000000000000000001: n6056 = 1'b0;
      default: n6056 = n6054;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6057 = n5864[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6058 = n5869[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6059 = n5874[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6060 = n5881[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6065 = xcsr_rdata_i[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6067 = 1'b0;
      19'b0100000000000000000: n6067 = 1'b0;
      19'b0010000000000000000: n6067 = 1'b0;
      19'b0001000000000000000: n6067 = 1'b0;
      19'b0000100000000000000: n6067 = 1'b0;
      19'b0000010000000000000: n6067 = 1'b0;
      19'b0000001000000000000: n6067 = 1'b0;
      19'b0000000100000000000: n6067 = 1'b0;
      19'b0000000010000000000: n6067 = 1'b0;
      19'b0000000001000000000: n6067 = n5885;
      19'b0000000000100000000: n6067 = n6060;
      19'b0000000000010000000: n6067 = 1'b0;
      19'b0000000000001000000: n6067 = n6059;
      19'b0000000000000100000: n6067 = n6058;
      19'b0000000000000010000: n6067 = 1'b0;
      19'b0000000000000001000: n6067 = n6057;
      19'b0000000000000000100: n6067 = n5859;
      19'b0000000000000000010: n6067 = 1'b0;
      19'b0000000000000000001: n6067 = n5830;
      default: n6067 = n6065;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6068 = n5864[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6069 = n5869[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6070 = n5874[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6071 = n5881[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6076 = xcsr_rdata_i[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6078 = 1'b0;
      19'b0100000000000000000: n6078 = 1'b0;
      19'b0010000000000000000: n6078 = 1'b0;
      19'b0001000000000000000: n6078 = 1'b0;
      19'b0000100000000000000: n6078 = 1'b0;
      19'b0000010000000000000: n6078 = 1'b0;
      19'b0000001000000000000: n6078 = 1'b1;
      19'b0000000100000000000: n6078 = 1'b0;
      19'b0000000010000000000: n6078 = 1'b0;
      19'b0000000001000000000: n6078 = 1'b0;
      19'b0000000000100000000: n6078 = n6071;
      19'b0000000000010000000: n6078 = 1'b0;
      19'b0000000000001000000: n6078 = n6070;
      19'b0000000000000100000: n6078 = n6069;
      19'b0000000000000010000: n6078 = 1'b0;
      19'b0000000000000001000: n6078 = n6068;
      19'b0000000000000000100: n6078 = 1'b0;
      19'b0000000000000000010: n6078 = 1'b1;
      19'b0000000000000000001: n6078 = 1'b0;
      default: n6078 = n6076;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6079 = n5864[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6080 = n5869[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6081 = n5874[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6082 = n5881[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6087 = xcsr_rdata_i[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6089 = 1'b0;
      19'b0100000000000000000: n6089 = 1'b0;
      19'b0010000000000000000: n6089 = 1'b0;
      19'b0001000000000000000: n6089 = 1'b0;
      19'b0000100000000000000: n6089 = 1'b0;
      19'b0000010000000000000: n6089 = 1'b0;
      19'b0000001000000000000: n6089 = 1'b1;
      19'b0000000100000000000: n6089 = 1'b0;
      19'b0000000010000000000: n6089 = 1'b0;
      19'b0000000001000000000: n6089 = 1'b0;
      19'b0000000000100000000: n6089 = n6082;
      19'b0000000000010000000: n6089 = 1'b0;
      19'b0000000000001000000: n6089 = n6081;
      19'b0000000000000100000: n6089 = n6080;
      19'b0000000000000010000: n6089 = 1'b0;
      19'b0000000000000001000: n6089 = n6079;
      19'b0000000000000000100: n6089 = 1'b0;
      19'b0000000000000000010: n6089 = 1'b0;
      19'b0000000000000000001: n6089 = 1'b0;
      default: n6089 = n6087;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6090 = n5864[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6091 = n5869[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6092 = n5874[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6093 = n5881[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6098 = xcsr_rdata_i[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6100 = 1'b0;
      19'b0100000000000000000: n6100 = 1'b0;
      19'b0010000000000000000: n6100 = 1'b0;
      19'b0001000000000000000: n6100 = 1'b0;
      19'b0000100000000000000: n6100 = 1'b0;
      19'b0000010000000000000: n6100 = 1'b0;
      19'b0000001000000000000: n6100 = 1'b0;
      19'b0000000100000000000: n6100 = 1'b0;
      19'b0000000010000000000: n6100 = 1'b0;
      19'b0000000001000000000: n6100 = 1'b0;
      19'b0000000000100000000: n6100 = n6093;
      19'b0000000000010000000: n6100 = 1'b0;
      19'b0000000000001000000: n6100 = n6092;
      19'b0000000000000100000: n6100 = n6091;
      19'b0000000000000010000: n6100 = 1'b0;
      19'b0000000000000001000: n6100 = n6090;
      19'b0000000000000000100: n6100 = 1'b0;
      19'b0000000000000000010: n6100 = 1'b0;
      19'b0000000000000000001: n6100 = 1'b0;
      default: n6100 = n6098;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6101 = n5864[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6102 = n5869[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6103 = n5874[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6104 = n5881[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6109 = xcsr_rdata_i[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6111 = 1'b0;
      19'b0100000000000000000: n6111 = 1'b0;
      19'b0010000000000000000: n6111 = 1'b0;
      19'b0001000000000000000: n6111 = 1'b0;
      19'b0000100000000000000: n6111 = 1'b0;
      19'b0000010000000000000: n6111 = 1'b0;
      19'b0000001000000000000: n6111 = 1'b0;
      19'b0000000100000000000: n6111 = 1'b0;
      19'b0000000010000000000: n6111 = 1'b0;
      19'b0000000001000000000: n6111 = n5886;
      19'b0000000000100000000: n6111 = n6104;
      19'b0000000000010000000: n6111 = 1'b0;
      19'b0000000000001000000: n6111 = n6103;
      19'b0000000000000100000: n6111 = n6102;
      19'b0000000000000010000: n6111 = 1'b0;
      19'b0000000000000001000: n6111 = n6101;
      19'b0000000000000000100: n6111 = n5860;
      19'b0000000000000000010: n6111 = 1'b0;
      19'b0000000000000000001: n6111 = n5831;
      default: n6111 = n6109;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6112 = n5864[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6113 = n5869[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6114 = n5874[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6115 = n5881[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6120 = xcsr_rdata_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6122 = 1'b0;
      19'b0100000000000000000: n6122 = 1'b0;
      19'b0010000000000000000: n6122 = 1'b0;
      19'b0001000000000000000: n6122 = 1'b0;
      19'b0000100000000000000: n6122 = 1'b0;
      19'b0000010000000000000: n6122 = 1'b0;
      19'b0000001000000000000: n6122 = 1'b0;
      19'b0000000100000000000: n6122 = 1'b0;
      19'b0000000010000000000: n6122 = 1'b0;
      19'b0000000001000000000: n6122 = 1'b0;
      19'b0000000000100000000: n6122 = n6115;
      19'b0000000000010000000: n6122 = 1'b0;
      19'b0000000000001000000: n6122 = n6114;
      19'b0000000000000100000: n6122 = n6113;
      19'b0000000000000010000: n6122 = 1'b0;
      19'b0000000000000001000: n6122 = n6112;
      19'b0000000000000000100: n6122 = 1'b0;
      19'b0000000000000000010: n6122 = 1'b1;
      19'b0000000000000000001: n6122 = n5832;
      default: n6122 = n6120;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6123 = n5864[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6124 = n5869[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6125 = n5874[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6126 = n5881[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6131 = xcsr_rdata_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6133 = 1'b0;
      19'b0100000000000000000: n6133 = 1'b0;
      19'b0010000000000000000: n6133 = 1'b0;
      19'b0001000000000000000: n6133 = 1'b0;
      19'b0000100000000000000: n6133 = 1'b0;
      19'b0000010000000000000: n6133 = 1'b0;
      19'b0000001000000000000: n6133 = 1'b0;
      19'b0000000100000000000: n6133 = 1'b0;
      19'b0000000010000000000: n6133 = 1'b0;
      19'b0000000001000000000: n6133 = 1'b0;
      19'b0000000000100000000: n6133 = n6126;
      19'b0000000000010000000: n6133 = 1'b0;
      19'b0000000000001000000: n6133 = n6125;
      19'b0000000000000100000: n6133 = n6124;
      19'b0000000000000010000: n6133 = 1'b0;
      19'b0000000000000001000: n6133 = n6123;
      19'b0000000000000000100: n6133 = 1'b0;
      19'b0000000000000000010: n6133 = 1'b0;
      19'b0000000000000000001: n6133 = 1'b0;
      default: n6133 = n6131;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6134 = n5864[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6135 = n5869[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6136 = n5874[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6137 = n5881[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6142 = xcsr_rdata_i[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6144 = 1'b0;
      19'b0100000000000000000: n6144 = 1'b0;
      19'b0010000000000000000: n6144 = 1'b0;
      19'b0001000000000000000: n6144 = 1'b0;
      19'b0000100000000000000: n6144 = 1'b0;
      19'b0000010000000000000: n6144 = 1'b0;
      19'b0000001000000000000: n6144 = 1'b0;
      19'b0000000100000000000: n6144 = 1'b0;
      19'b0000000010000000000: n6144 = 1'b0;
      19'b0000000001000000000: n6144 = 1'b0;
      19'b0000000000100000000: n6144 = n6137;
      19'b0000000000010000000: n6144 = 1'b0;
      19'b0000000000001000000: n6144 = n6136;
      19'b0000000000000100000: n6144 = n6135;
      19'b0000000000000010000: n6144 = 1'b0;
      19'b0000000000000001000: n6144 = n6134;
      19'b0000000000000000100: n6144 = 1'b0;
      19'b0000000000000000010: n6144 = 1'b0;
      19'b0000000000000000001: n6144 = 1'b0;
      default: n6144 = n6142;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6145 = n5864[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6146 = n5869[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6147 = n5874[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6148 = n5881[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6153 = xcsr_rdata_i[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6155 = 1'b0;
      19'b0100000000000000000: n6155 = 1'b0;
      19'b0010000000000000000: n6155 = 1'b0;
      19'b0001000000000000000: n6155 = 1'b0;
      19'b0000100000000000000: n6155 = 1'b0;
      19'b0000010000000000000: n6155 = 1'b0;
      19'b0000001000000000000: n6155 = 1'b0;
      19'b0000000100000000000: n6155 = 1'b0;
      19'b0000000010000000000: n6155 = 1'b0;
      19'b0000000001000000000: n6155 = 1'b0;
      19'b0000000000100000000: n6155 = n6148;
      19'b0000000000010000000: n6155 = 1'b0;
      19'b0000000000001000000: n6155 = n6147;
      19'b0000000000000100000: n6155 = n6146;
      19'b0000000000000010000: n6155 = 1'b0;
      19'b0000000000000001000: n6155 = n6145;
      19'b0000000000000000100: n6155 = 1'b0;
      19'b0000000000000000010: n6155 = 1'b0;
      19'b0000000000000000001: n6155 = 1'b0;
      default: n6155 = n6153;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6156 = n5861[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6157 = n5864[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6158 = n5869[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6159 = n5874[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6160 = n5881[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6161 = n5887[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6166 = xcsr_rdata_i[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6168 = 1'b0;
      19'b0100000000000000000: n6168 = 1'b0;
      19'b0010000000000000000: n6168 = 1'b0;
      19'b0001000000000000000: n6168 = 1'b0;
      19'b0000100000000000000: n6168 = 1'b0;
      19'b0000010000000000000: n6168 = 1'b0;
      19'b0000001000000000000: n6168 = 1'b1;
      19'b0000000100000000000: n6168 = 1'b0;
      19'b0000000010000000000: n6168 = 1'b0;
      19'b0000000001000000000: n6168 = n6161;
      19'b0000000000100000000: n6168 = n6160;
      19'b0000000000010000000: n6168 = 1'b0;
      19'b0000000000001000000: n6168 = n6159;
      19'b0000000000000100000: n6168 = n6158;
      19'b0000000000000010000: n6168 = 1'b0;
      19'b0000000000000001000: n6168 = n6157;
      19'b0000000000000000100: n6168 = n6156;
      19'b0000000000000000010: n6168 = 1'b0;
      19'b0000000000000000001: n6168 = 1'b0;
      default: n6168 = n6166;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6169 = n5861[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6170 = n5864[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6171 = n5869[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6172 = n5874[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6173 = n5881[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6174 = n5887[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6179 = xcsr_rdata_i[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6181 = 1'b0;
      19'b0100000000000000000: n6181 = 1'b0;
      19'b0010000000000000000: n6181 = 1'b0;
      19'b0001000000000000000: n6181 = 1'b0;
      19'b0000100000000000000: n6181 = 1'b0;
      19'b0000010000000000000: n6181 = 1'b0;
      19'b0000001000000000000: n6181 = 1'b1;
      19'b0000000100000000000: n6181 = 1'b0;
      19'b0000000010000000000: n6181 = 1'b0;
      19'b0000000001000000000: n6181 = n6174;
      19'b0000000000100000000: n6181 = n6173;
      19'b0000000000010000000: n6181 = 1'b0;
      19'b0000000000001000000: n6181 = n6172;
      19'b0000000000000100000: n6181 = n6171;
      19'b0000000000000010000: n6181 = 1'b0;
      19'b0000000000000001000: n6181 = n6170;
      19'b0000000000000000100: n6181 = n6169;
      19'b0000000000000000010: n6181 = 1'b0;
      19'b0000000000000000001: n6181 = n5833;
      default: n6181 = n6179;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6182 = n5861[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6183 = n5864[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6184 = n5869[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6185 = n5874[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6186 = n5881[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6187 = n5887[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6192 = xcsr_rdata_i[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6194 = 1'b0;
      19'b0100000000000000000: n6194 = 1'b0;
      19'b0010000000000000000: n6194 = 1'b0;
      19'b0001000000000000000: n6194 = 1'b0;
      19'b0000100000000000000: n6194 = 1'b0;
      19'b0000010000000000000: n6194 = 1'b0;
      19'b0000001000000000000: n6194 = 1'b0;
      19'b0000000100000000000: n6194 = 1'b0;
      19'b0000000010000000000: n6194 = 1'b0;
      19'b0000000001000000000: n6194 = n6187;
      19'b0000000000100000000: n6194 = n6186;
      19'b0000000000010000000: n6194 = 1'b0;
      19'b0000000000001000000: n6194 = n6185;
      19'b0000000000000100000: n6194 = n6184;
      19'b0000000000000010000: n6194 = 1'b0;
      19'b0000000000000001000: n6194 = n6183;
      19'b0000000000000000100: n6194 = n6182;
      19'b0000000000000000010: n6194 = 1'b0;
      19'b0000000000000000001: n6194 = 1'b0;
      default: n6194 = n6192;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6195 = n5861[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6196 = n5864[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6197 = n5869[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6198 = n5874[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6199 = n5881[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6200 = n5887[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6205 = xcsr_rdata_i[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6207 = 1'b0;
      19'b0100000000000000000: n6207 = 1'b0;
      19'b0010000000000000000: n6207 = 1'b0;
      19'b0001000000000000000: n6207 = 1'b0;
      19'b0000100000000000000: n6207 = 1'b0;
      19'b0000010000000000000: n6207 = 1'b0;
      19'b0000001000000000000: n6207 = 1'b0;
      19'b0000000100000000000: n6207 = 1'b0;
      19'b0000000010000000000: n6207 = 1'b0;
      19'b0000000001000000000: n6207 = n6200;
      19'b0000000000100000000: n6207 = n6199;
      19'b0000000000010000000: n6207 = 1'b0;
      19'b0000000000001000000: n6207 = n6198;
      19'b0000000000000100000: n6207 = n6197;
      19'b0000000000000010000: n6207 = 1'b0;
      19'b0000000000000001000: n6207 = n6196;
      19'b0000000000000000100: n6207 = n6195;
      19'b0000000000000000010: n6207 = 1'b0;
      19'b0000000000000000001: n6207 = 1'b0;
      default: n6207 = n6205;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6208 = n5861[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6209 = n5864[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6210 = n5869[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6211 = n5874[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6212 = n5881[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6213 = n5887[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6218 = xcsr_rdata_i[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6220 = 1'b0;
      19'b0100000000000000000: n6220 = 1'b0;
      19'b0010000000000000000: n6220 = 1'b0;
      19'b0001000000000000000: n6220 = 1'b0;
      19'b0000100000000000000: n6220 = 1'b0;
      19'b0000010000000000000: n6220 = 1'b0;
      19'b0000001000000000000: n6220 = 1'b1;
      19'b0000000100000000000: n6220 = 1'b0;
      19'b0000000010000000000: n6220 = 1'b0;
      19'b0000000001000000000: n6220 = n6213;
      19'b0000000000100000000: n6220 = n6212;
      19'b0000000000010000000: n6220 = 1'b0;
      19'b0000000000001000000: n6220 = n6211;
      19'b0000000000000100000: n6220 = n6210;
      19'b0000000000000010000: n6220 = 1'b0;
      19'b0000000000000001000: n6220 = n6209;
      19'b0000000000000000100: n6220 = n6208;
      19'b0000000000000000010: n6220 = 1'b1;
      19'b0000000000000000001: n6220 = 1'b0;
      default: n6220 = n6218;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6221 = n5861[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6222 = n5864[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6223 = n5869[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6224 = n5874[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6225 = n5881[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6226 = n5887[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6231 = xcsr_rdata_i[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6233 = 1'b0;
      19'b0100000000000000000: n6233 = 1'b0;
      19'b0010000000000000000: n6233 = 1'b0;
      19'b0001000000000000000: n6233 = 1'b0;
      19'b0000100000000000000: n6233 = 1'b0;
      19'b0000010000000000000: n6233 = 1'b0;
      19'b0000001000000000000: n6233 = 1'b0;
      19'b0000000100000000000: n6233 = 1'b0;
      19'b0000000010000000000: n6233 = 1'b0;
      19'b0000000001000000000: n6233 = n6226;
      19'b0000000000100000000: n6233 = n6225;
      19'b0000000000010000000: n6233 = 1'b0;
      19'b0000000000001000000: n6233 = n6224;
      19'b0000000000000100000: n6233 = n6223;
      19'b0000000000000010000: n6233 = 1'b0;
      19'b0000000000000001000: n6233 = n6222;
      19'b0000000000000000100: n6233 = n6221;
      19'b0000000000000000010: n6233 = 1'b0;
      19'b0000000000000000001: n6233 = n5837;
      default: n6233 = n6231;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6234 = n5861[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6235 = n5864[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6236 = n5869[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6237 = n5874[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6238 = n5881[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6239 = n5887[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6244 = xcsr_rdata_i[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6246 = 1'b0;
      19'b0100000000000000000: n6246 = 1'b0;
      19'b0010000000000000000: n6246 = 1'b0;
      19'b0001000000000000000: n6246 = 1'b0;
      19'b0000100000000000000: n6246 = 1'b0;
      19'b0000010000000000000: n6246 = 1'b0;
      19'b0000001000000000000: n6246 = 1'b0;
      19'b0000000100000000000: n6246 = 1'b0;
      19'b0000000010000000000: n6246 = 1'b0;
      19'b0000000001000000000: n6246 = n6239;
      19'b0000000000100000000: n6246 = n6238;
      19'b0000000000010000000: n6246 = 1'b0;
      19'b0000000000001000000: n6246 = n6237;
      19'b0000000000000100000: n6246 = n6236;
      19'b0000000000000010000: n6246 = 1'b0;
      19'b0000000000000001000: n6246 = n6235;
      19'b0000000000000000100: n6246 = n6234;
      19'b0000000000000000010: n6246 = 1'b0;
      19'b0000000000000000001: n6246 = 1'b0;
      default: n6246 = n6244;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6247 = n5861[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6248 = n5864[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6249 = n5869[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6250 = n5874[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6251 = n5881[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6252 = n5887[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6257 = xcsr_rdata_i[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6259 = 1'b0;
      19'b0100000000000000000: n6259 = 1'b0;
      19'b0010000000000000000: n6259 = 1'b0;
      19'b0001000000000000000: n6259 = 1'b0;
      19'b0000100000000000000: n6259 = 1'b0;
      19'b0000010000000000000: n6259 = 1'b0;
      19'b0000001000000000000: n6259 = 1'b0;
      19'b0000000100000000000: n6259 = 1'b0;
      19'b0000000010000000000: n6259 = 1'b0;
      19'b0000000001000000000: n6259 = n6252;
      19'b0000000000100000000: n6259 = n6251;
      19'b0000000000010000000: n6259 = 1'b0;
      19'b0000000000001000000: n6259 = n6250;
      19'b0000000000000100000: n6259 = n6249;
      19'b0000000000000010000: n6259 = 1'b0;
      19'b0000000000000001000: n6259 = n6248;
      19'b0000000000000000100: n6259 = n6247;
      19'b0000000000000000010: n6259 = 1'b1;
      19'b0000000000000000001: n6259 = 1'b0;
      default: n6259 = n6257;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6260 = n5861[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6261 = n5864[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6262 = n5869[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6263 = n5874[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6264 = n5881[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6265 = n5887[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6270 = xcsr_rdata_i[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6272 = 1'b0;
      19'b0100000000000000000: n6272 = 1'b0;
      19'b0010000000000000000: n6272 = 1'b0;
      19'b0001000000000000000: n6272 = 1'b0;
      19'b0000100000000000000: n6272 = 1'b0;
      19'b0000010000000000000: n6272 = 1'b0;
      19'b0000001000000000000: n6272 = 1'b1;
      19'b0000000100000000000: n6272 = 1'b0;
      19'b0000000010000000000: n6272 = 1'b0;
      19'b0000000001000000000: n6272 = n6265;
      19'b0000000000100000000: n6272 = n6264;
      19'b0000000000010000000: n6272 = 1'b0;
      19'b0000000000001000000: n6272 = n6263;
      19'b0000000000000100000: n6272 = n6262;
      19'b0000000000000010000: n6272 = 1'b0;
      19'b0000000000000001000: n6272 = n6261;
      19'b0000000000000000100: n6272 = n6260;
      19'b0000000000000000010: n6272 = 1'b0;
      19'b0000000000000000001: n6272 = 1'b0;
      default: n6272 = n6270;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6273 = n5861[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6274 = n5864[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6275 = n5869[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6276 = n5874[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6277 = n5881[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6278 = n5887[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6283 = xcsr_rdata_i[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6285 = 1'b0;
      19'b0100000000000000000: n6285 = 1'b0;
      19'b0010000000000000000: n6285 = 1'b0;
      19'b0001000000000000000: n6285 = 1'b0;
      19'b0000100000000000000: n6285 = 1'b0;
      19'b0000010000000000000: n6285 = 1'b0;
      19'b0000001000000000000: n6285 = 1'b0;
      19'b0000000100000000000: n6285 = 1'b0;
      19'b0000000010000000000: n6285 = 1'b0;
      19'b0000000001000000000: n6285 = n6278;
      19'b0000000000100000000: n6285 = n6277;
      19'b0000000000010000000: n6285 = 1'b0;
      19'b0000000000001000000: n6285 = n6276;
      19'b0000000000000100000: n6285 = n6275;
      19'b0000000000000010000: n6285 = 1'b0;
      19'b0000000000000001000: n6285 = n6274;
      19'b0000000000000000100: n6285 = n6273;
      19'b0000000000000000010: n6285 = 1'b0;
      19'b0000000000000000001: n6285 = 1'b0;
      default: n6285 = n6283;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6286 = n5861[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6287 = n5864[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6288 = n5869[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6289 = n5874[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6290 = n5881[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6291 = n5887[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6296 = xcsr_rdata_i[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6298 = 1'b0;
      19'b0100000000000000000: n6298 = 1'b0;
      19'b0010000000000000000: n6298 = 1'b0;
      19'b0001000000000000000: n6298 = 1'b0;
      19'b0000100000000000000: n6298 = 1'b0;
      19'b0000010000000000000: n6298 = 1'b0;
      19'b0000001000000000000: n6298 = 1'b0;
      19'b0000000100000000000: n6298 = 1'b0;
      19'b0000000010000000000: n6298 = 1'b0;
      19'b0000000001000000000: n6298 = n6291;
      19'b0000000000100000000: n6298 = n6290;
      19'b0000000000010000000: n6298 = 1'b0;
      19'b0000000000001000000: n6298 = n6289;
      19'b0000000000000100000: n6298 = n6288;
      19'b0000000000000010000: n6298 = 1'b0;
      19'b0000000000000001000: n6298 = n6287;
      19'b0000000000000000100: n6298 = n6286;
      19'b0000000000000000010: n6298 = 1'b0;
      19'b0000000000000000001: n6298 = 1'b0;
      default: n6298 = n6296;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6299 = n5861[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6300 = n5864[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6301 = n5869[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6302 = n5874[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6303 = n5881[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6304 = n5887[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6309 = xcsr_rdata_i[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6311 = 1'b0;
      19'b0100000000000000000: n6311 = 1'b0;
      19'b0010000000000000000: n6311 = 1'b0;
      19'b0001000000000000000: n6311 = 1'b0;
      19'b0000100000000000000: n6311 = 1'b0;
      19'b0000010000000000000: n6311 = 1'b0;
      19'b0000001000000000000: n6311 = 1'b0;
      19'b0000000100000000000: n6311 = 1'b0;
      19'b0000000010000000000: n6311 = 1'b0;
      19'b0000000001000000000: n6311 = n6304;
      19'b0000000000100000000: n6311 = n6303;
      19'b0000000000010000000: n6311 = 1'b0;
      19'b0000000000001000000: n6311 = n6302;
      19'b0000000000000100000: n6311 = n6301;
      19'b0000000000000010000: n6311 = 1'b0;
      19'b0000000000000001000: n6311 = n6300;
      19'b0000000000000000100: n6311 = n6299;
      19'b0000000000000000010: n6311 = 1'b0;
      19'b0000000000000000001: n6311 = 1'b0;
      default: n6311 = n6309;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6312 = n5861[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6313 = n5864[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6314 = n5869[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6315 = n5874[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6316 = n5881[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6317 = n5887[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6322 = xcsr_rdata_i[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6324 = 1'b0;
      19'b0100000000000000000: n6324 = 1'b1;
      19'b0010000000000000000: n6324 = 1'b0;
      19'b0001000000000000000: n6324 = 1'b0;
      19'b0000100000000000000: n6324 = 1'b0;
      19'b0000010000000000000: n6324 = 1'b0;
      19'b0000001000000000000: n6324 = 1'b0;
      19'b0000000100000000000: n6324 = 1'b0;
      19'b0000000010000000000: n6324 = 1'b0;
      19'b0000000001000000000: n6324 = n6317;
      19'b0000000000100000000: n6324 = n6316;
      19'b0000000000010000000: n6324 = 1'b0;
      19'b0000000000001000000: n6324 = n6315;
      19'b0000000000000100000: n6324 = n6314;
      19'b0000000000000010000: n6324 = 1'b0;
      19'b0000000000000001000: n6324 = n6313;
      19'b0000000000000000100: n6324 = n6312;
      19'b0000000000000000010: n6324 = 1'b0;
      19'b0000000000000000001: n6324 = 1'b0;
      default: n6324 = n6322;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6325 = n5861[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6326 = n5864[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6327 = n5869[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6328 = n5874[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6329 = n5881[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6330 = n5887[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6335 = xcsr_rdata_i[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6337 = 1'b0;
      19'b0100000000000000000: n6337 = 1'b0;
      19'b0010000000000000000: n6337 = 1'b0;
      19'b0001000000000000000: n6337 = 1'b0;
      19'b0000100000000000000: n6337 = 1'b0;
      19'b0000010000000000000: n6337 = 1'b0;
      19'b0000001000000000000: n6337 = 1'b0;
      19'b0000000100000000000: n6337 = 1'b0;
      19'b0000000010000000000: n6337 = 1'b0;
      19'b0000000001000000000: n6337 = n6330;
      19'b0000000000100000000: n6337 = n6329;
      19'b0000000000010000000: n6337 = 1'b0;
      19'b0000000000001000000: n6337 = n6328;
      19'b0000000000000100000: n6337 = n6327;
      19'b0000000000000010000: n6337 = 1'b0;
      19'b0000000000000001000: n6337 = n6326;
      19'b0000000000000000100: n6337 = n6325;
      19'b0000000000000000010: n6337 = 1'b0;
      19'b0000000000000000001: n6337 = 1'b0;
      default: n6337 = n6335;
    endcase
  assign n6338 = n5855[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6339 = n5861[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6340 = n5864[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6341 = n5869[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6342 = n5874[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6343 = n5881[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6344 = n5887[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6349 = xcsr_rdata_i[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6351 = 1'b0;
      19'b0100000000000000000: n6351 = 1'b0;
      19'b0010000000000000000: n6351 = 1'b0;
      19'b0001000000000000000: n6351 = 1'b0;
      19'b0000100000000000000: n6351 = 1'b0;
      19'b0000010000000000000: n6351 = 1'b0;
      19'b0000001000000000000: n6351 = 1'b0;
      19'b0000000100000000000: n6351 = 1'b0;
      19'b0000000010000000000: n6351 = 1'b0;
      19'b0000000001000000000: n6351 = n6344;
      19'b0000000000100000000: n6351 = n6343;
      19'b0000000000010000000: n6351 = 1'b0;
      19'b0000000000001000000: n6351 = n6342;
      19'b0000000000000100000: n6351 = n6341;
      19'b0000000000000010000: n6351 = 1'b0;
      19'b0000000000000001000: n6351 = n6340;
      19'b0000000000000000100: n6351 = n6339;
      19'b0000000000000000010: n6351 = n6338;
      19'b0000000000000000001: n6351 = 1'b0;
      default: n6351 = n6349;
    endcase
  assign n6352 = n5855[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6353 = n5861[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6354 = n5864[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6355 = n5869[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6356 = n5874[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6357 = n5881[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6358 = n5887[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6363 = xcsr_rdata_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5974)
      19'b1000000000000000000: n6365 = 1'b0;
      19'b0100000000000000000: n6365 = 1'b0;
      19'b0010000000000000000: n6365 = 1'b0;
      19'b0001000000000000000: n6365 = 1'b0;
      19'b0000100000000000000: n6365 = 1'b0;
      19'b0000010000000000000: n6365 = 1'b0;
      19'b0000001000000000000: n6365 = 1'b0;
      19'b0000000100000000000: n6365 = 1'b0;
      19'b0000000010000000000: n6365 = 1'b0;
      19'b0000000001000000000: n6365 = n6358;
      19'b0000000000100000000: n6365 = n6357;
      19'b0000000000010000000: n6365 = n5877;
      19'b0000000000001000000: n6365 = n6356;
      19'b0000000000000100000: n6365 = n6355;
      19'b0000000000000010000: n6365 = 1'b0;
      19'b0000000000000001000: n6365 = n6354;
      19'b0000000000000000100: n6365 = n6353;
      19'b0000000000000000010: n6365 = n6352;
      19'b0000000000000000001: n6365 = 1'b0;
      default: n6365 = n6363;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:7 */
  assign n6366 = {n6365, n6351, n6337, n6324, n6311, n6298, n6285, n6272, n6259, n6246, n6233, n6220, n6207, n6194, n6181, n6168, n6155, n6144, n6133, n6122, n6111, n6100, n6089, n6078, n6067, n6056, n6045, n6034, n6022, n6010, n5998, n5986};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:7 */
  assign n6368 = n5827 ? n6366 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n6374 = {n3922, n3920, n3918};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n6375 = {n3298, n3958, n3957, n3955, n3953, n3972, n3951, n3950, n3949, n3947, n3945, n3943, n3941, n3389, n3940, n3939, n3938, n3936, n3934, n3966, n3932, n3930, n3963, n3928, n3961, n3926};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:114:10 */
  assign n6376 = {n5426, n5424};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:159:10 */
  assign n6378 = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:164:10 */
  assign n6379 = {n4844, n4862, n4874};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:166:10 */
  assign n6380 = {n4197, n4191, n4185, n4177, n4168, n4162, n4153, n4145, n4139};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:71:5 */
  assign n6381 = {n4134, exc_fire, env_enter, n4133, n4132, n4131, n4130, n4129, cnt_event, csr_wdata, n4128, n4127, n4126, n4125, n4123, n4119, n4113, n4108, n4107, n4106, n4105, n4087, n4069, n4051, n4050, n4049, n4048, n4047, n4046, n4045, n4044, n4043, n4042, n4041, n4011, n4008, n4005, n4002, n4000, n3995};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:204:5 */
  always @(posedge clk_i or posedge n3272)
    if (n3272)
      n6382 <= n3282;
    else
      n6382 <= exec_nxt;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:204:5 */
  always @(posedge clk_i or posedge n3272)
    if (n3272)
      n6383 <= 262'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n6383 <= ctrl_nxt;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n5093)
    if (n5093)
      n6384 <= 12'b000000000000;
    else
      n6384 <= n5271;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n5093)
    if (n5093)
      n6385 <= 20'b00000000000000000000;
    else
      n6385 <= n5097;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n5093)
    if (n5093)
      n6386 <= 20'b00000000000000000000;
    else
      n6386 <= n5274;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:840:5 */
  always @(posedge clk_i or posedge n5302)
    if (n5302)
      n6387 <= 1'b0;
    else
      n6387 <= n5320;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1018:5 */
  always @(posedge clk_i or posedge n5575)
    if (n5575)
      n6388 <= n5821;
    else
      n6388 <= n5819;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1178:5 */
  always @(posedge clk_i or posedge n5825)
    if (n5825)
      n6389 <= 32'b00000000000000000000000000000000;
    else
      n6389 <= n6368;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:774:5 */
  always @(posedge clk_i or posedge n5066)
    if (n5066)
      n6390 <= 10'b0000000000;
    else
      n6390 <= n5074;
endmodule

module neorv32_cpu_frontend_Bneorv32_cpu_frontend_rtl_Lneorv32_0_9508e90548b0440a4a61e5743b76c1e309b23b7f
  (input  clk_i,
   input  rstn_i,
   input  \ctrl_i[if_reset] ,
   input  \ctrl_i[if_ready] ,
   input  \ctrl_i[if_fence] ,
   input  [31:0] \ctrl_i[pc_cur] ,
   input  [31:0] \ctrl_i[pc_nxt] ,
   input  [31:0] \ctrl_i[pc_ret] ,
   input  \ctrl_i[rf_wb_en] ,
   input  [4:0] \ctrl_i[rf_rs1] ,
   input  [4:0] \ctrl_i[rf_rs2] ,
   input  [4:0] \ctrl_i[rf_rd] ,
   input  \ctrl_i[rf_zero] ,
   input  [2:0] \ctrl_i[alu_op] ,
   input  \ctrl_i[alu_sub] ,
   input  \ctrl_i[alu_opa_mux] ,
   input  \ctrl_i[alu_opb_mux] ,
   input  \ctrl_i[alu_unsigned] ,
   input  [31:0] \ctrl_i[alu_imm] ,
   input  \ctrl_i[alu_cp_alu] ,
   input  \ctrl_i[alu_cp_cfu] ,
   input  \ctrl_i[alu_cp_fpu] ,
   input  \ctrl_i[lsu_req] ,
   input  \ctrl_i[lsu_rd] ,
   input  \ctrl_i[lsu_wr] ,
   input  \ctrl_i[lsu_mo_en] ,
   input  \ctrl_i[lsu_mi_en] ,
   input  \ctrl_i[lsu_priv] ,
   input  \ctrl_i[lsu_fence] ,
   input  \ctrl_i[csr_we] ,
   input  \ctrl_i[csr_re] ,
   input  [11:0] \ctrl_i[csr_addr] ,
   input  [31:0] \ctrl_i[csr_wdata] ,
   input  [8:0] \ctrl_i[cnt_event] ,
   input  [2:0] \ctrl_i[ir_funct3] ,
   input  [11:0] \ctrl_i[ir_funct12] ,
   input  [6:0] \ctrl_i[ir_opcode] ,
   input  [15:0] \ctrl_i[ir_rvc] ,
   input  \ctrl_i[cpu_priv] ,
   input  \ctrl_i[cpu_trap] ,
   input  \ctrl_i[cpu_sync_exc] ,
   input  \ctrl_i[cpu_debug] ,
   output [4:0] \ibus_req_o[meta] ,
   output [31:0] \ibus_req_o[addr] ,
   output [31:0] \ibus_req_o[data] ,
   output [3:0] \ibus_req_o[ben] ,
   output \ibus_req_o[stb] ,
   output \ibus_req_o[rw] ,
   output \ibus_req_o[amo] ,
   output [3:0] \ibus_req_o[amoop] ,
   output \ibus_req_o[burst] ,
   output \ibus_req_o[lock] ,
   input  \ibus_rsp_i[ack] ,
   input  \ibus_rsp_i[err] ,
   input  [31:0] \ibus_rsp_i[data] ,
   output [31:0] pmp_addr_o,
   output pmp_priv_o,
   input  pmp_err_i,
   output \frontend_o[valid] ,
   output [31:0] \frontend_o[i32] ,
   output [15:0] \frontend_o[i16] ,
   output \frontend_o[compr] ,
   output \frontend_o[fault] );
  wire [261:0] n2932;
  wire [4:0] n2934;
  wire [31:0] n2935;
  wire [31:0] n2936;
  wire [3:0] n2937;
  wire n2938;
  wire n2939;
  wire n2940;
  wire [3:0] n2941;
  wire n2942;
  wire n2943;
  wire [33:0] n2944;
  wire n2948;
  wire [31:0] n2949;
  wire [15:0] n2950;
  wire n2951;
  wire n2952;
  wire [36:0] fetch;
  wire restart;
  wire [33:0] ipb_wdata;
  wire [33:0] ipb_rdata;
  wire [1:0] ipb_we;
  wire [1:0] ipb_re;
  wire [1:0] ipb_free;
  wire [1:0] ipb_avail;
  wire align_q;
  wire align_set;
  wire align_clr;
  wire [1:0] issue_valid;
  wire [15:0] cmd16;
  wire [31:0] cmd32;
  wire n2954;
  wire [1:0] n2961;
  wire [31:0] n2963;
  wire n2964;
  wire n2965;
  wire n2968;
  wire n2970;
  wire [1:0] n2973;
  wire [1:0] n2974;
  wire [1:0] n2975;
  wire n2977;
  wire n2978;
  wire [31:0] n2979;
  wire [31:0] n2981;
  wire [29:0] n2983;
  wire n2984;
  wire [1:0] n2987;
  wire [31:0] n2988;
  wire [1:0] n2989;
  wire [1:0] n2990;
  wire [31:0] n2991;
  wire [31:0] n2992;
  wire n2994;
  wire [2:0] n2995;
  reg [1:0] n2997;
  reg n2999;
  wire [31:0] n3000;
  reg [31:0] n3002;
  wire n3003;
  reg n3005;
  wire n3006;
  reg n3008;
  wire [36:0] n3009;
  wire [36:0] n3011;
  wire n3014;
  wire n3015;
  wire n3016;
  wire [29:0] n3017;
  wire [31:0] n3019;
  wire n3020;
  wire n3021;
  wire [2:0] n3023;
  wire n3024;
  wire [3:0] n3025;
  wire [4:0] n3027;
  wire [29:0] n3028;
  wire [31:0] n3030;
  wire [1:0] n3032;
  wire n3034;
  wire n3036;
  wire n3037;
  wire n3038;
  wire n3047;
  wire n3048;
  wire [15:0] n3049;
  wire [16:0] n3050;
  wire n3051;
  wire n3052;
  wire [15:0] n3053;
  wire [16:0] n3054;
  wire [1:0] n3056;
  wire n3058;
  wire n3059;
  wire n3060;
  wire n3061;
  wire n3062;
  wire n3064;
  wire n3065;
  wire n3066;
  wire [1:0] n3069;
  wire n3071;
  wire n3072;
  wire n3073;
  wire n3074;
  wire [16:0] n3076;
  wire n3077;
  wire \prefetch_buffer[0]_ipb_inst_n3078 ;
  wire n3079;
  wire [16:0] \prefetch_buffer[0]_ipb_inst_n3080 ;
  wire \prefetch_buffer[0]_ipb_inst_n3081 ;
  wire [16:0] n3088;
  wire n3089;
  wire \prefetch_buffer[1]_ipb_inst_n3090 ;
  wire n3091;
  wire [16:0] \prefetch_buffer[1]_ipb_inst_n3092 ;
  wire \prefetch_buffer[1]_ipb_inst_n3093 ;
  wire [15:0] n3101;
  wire n3102;
  wire [15:0] n3103;
  wire [15:0] n3104;
  wire n3106;
  wire n3108;
  wire n3109;
  wire n3110;
  wire n3111;
  wire n3112;
  wire n3113;
  wire n3114;
  wire n3115;
  wire n3116;
  wire n3117;
  wire n3123;
  wire [1:0] n3124;
  wire n3126;
  wire n3127;
  wire n3128;
  wire n3130;
  wire n3132;
  wire n3133;
  wire n3134;
  wire n3135;
  wire n3136;
  wire n3137;
  wire n3138;
  wire n3139;
  wire n3140;
  wire [15:0] n3141;
  wire [15:0] n3142;
  wire [31:0] n3143;
  wire [1:0] n3145;
  wire [1:0] n3146;
  wire [31:0] n3147;
  wire [1:0] n3148;
  wire n3150;
  wire [1:0] n3151;
  wire [1:0] n3152;
  wire [1:0] n3153;
  wire [1:0] n3154;
  wire n3156;
  wire n3157;
  wire n3159;
  wire n3160;
  wire n3162;
  wire n3163;
  wire n3164;
  wire n3165;
  wire n3166;
  wire n3167;
  wire n3168;
  wire n3169;
  wire n3170;
  wire [15:0] n3171;
  wire [15:0] n3172;
  wire [31:0] n3173;
  wire [1:0] n3175;
  wire [1:0] n3176;
  wire [31:0] n3177;
  wire [1:0] n3178;
  wire n3180;
  wire [1:0] n3181;
  wire [1:0] n3182;
  wire [1:0] n3183;
  wire [31:0] n3184;
  wire [1:0] n3185;
  wire n3187;
  wire n3190;
  wire [1:0] n3192;
  wire n3194;
  wire n3195;
  wire n3196;
  wire n3197;
  wire n3198;
  wire n3199;
  wire n3200;
  wire n3201;
  wire n3202;
  wire [33:0] n3203;
  wire [33:0] n3204;
  wire [1:0] n3205;
  wire [1:0] n3206;
  wire [1:0] n3207;
  wire [1:0] n3208;
  wire [81:0] n3209;
  wire [50:0] n3210;
  reg [36:0] n3211;
  reg n3212;
  assign \ibus_req_o[meta]  = n2934; //(module output)
  assign \ibus_req_o[addr]  = n2935; //(module output)
  assign \ibus_req_o[data]  = n2936; //(module output)
  assign \ibus_req_o[ben]  = n2937; //(module output)
  assign \ibus_req_o[stb]  = n2938; //(module output)
  assign \ibus_req_o[rw]  = n2939; //(module output)
  assign \ibus_req_o[amo]  = n2940; //(module output)
  assign \ibus_req_o[amoop]  = n2941; //(module output)
  assign \ibus_req_o[burst]  = n2942; //(module output)
  assign \ibus_req_o[lock]  = n2943; //(module output)
  assign pmp_addr_o = n3019; //(module output)
  assign pmp_priv_o = n3020; //(module output)
  assign \frontend_o[valid]  = n2948; //(module output)
  assign \frontend_o[i32]  = n2949; //(module output)
  assign \frontend_o[i16]  = n2950; //(module output)
  assign \frontend_o[compr]  = n2951; //(module output)
  assign \frontend_o[fault]  = n2952; //(module output)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2932 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2934 = n3209[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2935 = n3209[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2936 = n3209[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2937 = n3209[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2938 = n3209[73]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2939 = n3209[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2940 = n3209[75]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2941 = n3209[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2942 = n3209[80]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2943 = n3209[81]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2944 = {\ibus_rsp_i[data] , \ibus_rsp_i[err] , \ibus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2948 = n3210[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2949 = n3210[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2950 = n3210[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2951 = n3210[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2952 = n3210[50]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign fetch = n3211; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:79:10 */
  assign restart = n3016; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:10 */
  assign ipb_wdata = n3203; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:21 */
  assign ipb_rdata = n3204; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:10 */
  assign ipb_we = n3205; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:21 */
  assign ipb_re = n3206; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:10 */
  assign ipb_free = n3207; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:21 */
  assign ipb_avail = n3208; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:10 */
  assign align_q = n3212; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:19 */
  assign align_set = n3187; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:30 */
  assign align_clr = n3190; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:89:10 */
  assign issue_valid = n3192; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:90:10 */
  assign cmd16 = n3103; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:103:16 */
  assign n2954 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:18 */
  assign n2961 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:115:33 */
  assign n2963 = n2932[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:116:33 */
  assign n2964 = n2932[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:117:33 */
  assign n2965 = n2932[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:112:9 */
  assign n2968 = n2961 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:123:24 */
  assign n2970 = ipb_free == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2973 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:125:11 */
  assign n2974 = restart ? 2'b00 : n2973;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:123:11 */
  assign n2975 = n2970 ? 2'b10 : n2974;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:120:9 */
  assign n2977 = n2961 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:26 */
  assign n2978 = n2944[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:133:63 */
  assign n2979 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:133:69 */
  assign n2981 = n2979 + 32'b00000000000000000000000000000100;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2983 = n2981[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2984 = n2981[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:135:13 */
  assign n2987 = restart ? 2'b00 : 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2988 = {n2983, 1'b0, n2984};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2989 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2990 = n2978 ? n2987 : n2989;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2991 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2992 = n2978 ? n2988 : n2991;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:129:9 */
  assign n2994 = n2961 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  assign n2995 = {n2994, n2977, n2968};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2995)
      3'b100: n2997 = n2990;
      3'b010: n2997 = n2975;
      3'b001: n2997 = 2'b01;
      default: n2997 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2995)
      3'b100: n2999 = restart;
      3'b010: n2999 = restart;
      3'b001: n2999 = 1'b0;
      default: n2999 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n3000 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2995)
      3'b100: n3002 = n2992;
      3'b010: n3002 = n3000;
      3'b001: n3002 = n2963;
      default: n3002 = 32'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n3003 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2995)
      3'b100: n3005 = n3003;
      3'b010: n3005 = n3003;
      3'b001: n3005 = n2964;
      default: n3005 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n3006 = fetch[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2995)
      3'b100: n3008 = n3006;
      3'b010: n3008 = n3006;
      3'b001: n3008 = n2965;
      default: n3008 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:109:5 */
  assign n3009 = {n3008, n3005, n3002, n2999, n2997};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:103:5 */
  assign n3011 = {1'b0, 1'b1, 32'b00000000000000000000000000000000, 1'b1, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:20 */
  assign n3014 = fetch[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:36 */
  assign n3015 = n2932[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:26 */
  assign n3016 = n3014 | n3015;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:150:27 */
  assign n3017 = fetch[34:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:150:41 */
  assign n3019 = {n3017, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:151:23 */
  assign n3020 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:74 */
  assign n3021 = fetch[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:66 */
  assign n3023 = {2'b00, n3021};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:88 */
  assign n3024 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:80 */
  assign n3025 = {n3023, n3024};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:93 */
  assign n3027 = {n3025, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:155:33 */
  assign n3028 = fetch[34:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:155:47 */
  assign n3030 = {n3028, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:39 */
  assign n3032 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:45 */
  assign n3034 = n3032 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:72 */
  assign n3036 = ipb_free == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:58 */
  assign n3037 = n3036 & n3034;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:27 */
  assign n3038 = n3037 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:31 */
  assign n3047 = n2944[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:35 */
  assign n3048 = n3047 | pmp_err_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:66 */
  assign n3049 = n2944[17:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:49 */
  assign n3050 = {n3048, n3049};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:31 */
  assign n3051 = n2944[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:35 */
  assign n3052 = n3051 | pmp_err_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:66 */
  assign n3053 = n2944[33:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:49 */
  assign n3054 = {n3052, n3053};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:32 */
  assign n3056 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:38 */
  assign n3058 = n3056 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:67 */
  assign n3059 = n2944[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:51 */
  assign n3060 = n3059 & n3058;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:94 */
  assign n3061 = fetch[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:98 */
  assign n3062 = ~n3061;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:105 */
  assign n3064 = n3062 | 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:78 */
  assign n3065 = n3064 & n3060;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:20 */
  assign n3066 = n3065 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:32 */
  assign n3069 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:38 */
  assign n3071 = n3069 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:67 */
  assign n3072 = n2944[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:51 */
  assign n3073 = n3072 & n3071;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:20 */
  assign n3074 = n3073 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:188:27 */
  assign n3076 = ipb_wdata[33:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:189:24 */
  assign n3077 = ipb_we[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:192:24 */
  assign n3079 = ipb_re[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:177:5 */
  neorv32_cpu_frontend_ipb_Bneorv32_cpu_frontend_ipb_rtl_Lneorv32_1_17 \prefetch_buffer[0]_ipb_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(restart),
    .wdata_i(n3076),
    .we_i(n3077),
    .re_i(n3079),
    .free_o(\prefetch_buffer[0]_ipb_inst_n3078 ),
    .rdata_o(\prefetch_buffer[0]_ipb_inst_n3080 ),
    .avail_o(\prefetch_buffer[0]_ipb_inst_n3081 ));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:188:27 */
  assign n3088 = ipb_wdata[16:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:189:24 */
  assign n3089 = ipb_we[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:192:24 */
  assign n3091 = ipb_re[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:177:5 */
  neorv32_cpu_frontend_ipb_Bneorv32_cpu_frontend_ipb_rtl_Lneorv32_1_17 \prefetch_buffer[1]_ipb_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(restart),
    .wdata_i(n3088),
    .we_i(n3089),
    .re_i(n3091),
    .free_o(\prefetch_buffer[1]_ipb_inst_n3090 ),
    .rdata_o(\prefetch_buffer[1]_ipb_inst_n3092 ),
    .avail_o(\prefetch_buffer[1]_ipb_inst_n3093 ));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:207:5 */
  neorv32_cpu_decompressor_Bneorv32_cpu_decompressor_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29 issue_enabled_neorv32_cpu_decompressor_inst (
    .instr_i(cmd16),
    .instr_o(cmd32));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:26 */
  assign n3101 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:54 */
  assign n3102 = ~align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:40 */
  assign n3103 = n3102 ? n3101 : n3104;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:78 */
  assign n3104 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:225:18 */
  assign n3106 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:228:19 */
  assign n3108 = fetch[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:229:35 */
  assign n3109 = n2932[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:22 */
  assign n3110 = ipb_re[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:43 */
  assign n3111 = ipb_re[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:33 */
  assign n3112 = n3110 | n3111;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:36 */
  assign n3113 = ~align_clr;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:31 */
  assign n3114 = align_q & n3113;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:52 */
  assign n3115 = n3114 | align_set;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:9 */
  assign n3116 = n3112 ? n3115 : align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:228:9 */
  assign n3117 = n3108 ? n3109 : n3116;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:19 */
  assign n3123 = ~align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:25 */
  assign n3124 = ipb_rdata[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:38 */
  assign n3126 = n3124 != 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:244:40 */
  assign n3127 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:245:40 */
  assign n3128 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:247:43 */
  assign n3130 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:40 */
  assign n3132 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:57 */
  assign n3133 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:44 */
  assign n3134 = n3132 & n3133;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:40 */
  assign n3135 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:57 */
  assign n3136 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:44 */
  assign n3137 = n3135 & n3136;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:43 */
  assign n3138 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:63 */
  assign n3139 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:48 */
  assign n3140 = n3138 | n3139;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:43 */
  assign n3141 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:71 */
  assign n3142 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:57 */
  assign n3143 = {n3141, n3142};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3145 = {n3140, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3146 = {n3130, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3147 = n3126 ? cmd32 : n3143;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3148 = n3126 ? n3146 : n3145;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3150 = n3126 ? n3127 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3151 = {n3137, n3134};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3152 = {1'b0, n3128};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3153 = n3126 ? n3152 : n3151;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:25 */
  assign n3154 = ipb_rdata[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:38 */
  assign n3156 = n3154 != 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:260:40 */
  assign n3157 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:262:40 */
  assign n3159 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:263:43 */
  assign n3160 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:40 */
  assign n3162 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:57 */
  assign n3163 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:44 */
  assign n3164 = n3162 & n3163;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:40 */
  assign n3165 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:57 */
  assign n3166 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:44 */
  assign n3167 = n3165 & n3166;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:43 */
  assign n3168 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:63 */
  assign n3169 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:48 */
  assign n3170 = n3168 | n3169;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:43 */
  assign n3171 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:71 */
  assign n3172 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:57 */
  assign n3173 = {n3171, n3172};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3175 = {n3170, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3176 = {n3160, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3177 = n3156 ? cmd32 : n3173;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3178 = n3156 ? n3176 : n3175;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3180 = n3156 ? n3157 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3181 = {n3167, n3164};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3182 = {n3159, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3183 = n3156 ? n3182 : n3181;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3184 = n3123 ? n3147 : n3177;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3185 = n3123 ? n3148 : n3178;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3187 = n3123 ? n3150 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3190 = n3123 ? 1'b0 : n3180;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3192 = n3123 ? n3153 : n3183;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:36 */
  assign n3194 = issue_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:54 */
  assign n3195 = issue_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:40 */
  assign n3196 = n3194 | n3195;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:29 */
  assign n3197 = issue_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:44 */
  assign n3198 = n2932[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:33 */
  assign n3199 = n3197 & n3198;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:29 */
  assign n3200 = issue_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:44 */
  assign n3201 = n2932[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:33 */
  assign n3202 = n3200 & n3201;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:10 */
  assign n3203 = {n3050, n3054};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:21 */
  assign n3204 = {\prefetch_buffer[0]_ipb_inst_n3080 , \prefetch_buffer[1]_ipb_inst_n3092 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:10 */
  assign n3205 = {n3074, n3066};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:21 */
  assign n3206 = {n3202, n3199};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:10 */
  assign n3207 = {\prefetch_buffer[1]_ipb_inst_n3090 , \prefetch_buffer[0]_ipb_inst_n3078 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:21 */
  assign n3208 = {\prefetch_buffer[1]_ipb_inst_n3093 , \prefetch_buffer[0]_ipb_inst_n3081 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:35:5 */
  assign n3209 = {1'b0, 1'b0, 4'b0000, 1'b0, 1'b0, n3038, 4'b1111, 32'b00000000000000000000000000000000, n3030, n3027};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:42:5 */
  assign n3210 = {n3185, cmd16, n3184, n3196};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:109:5 */
  always @(posedge clk_i or posedge n2954)
    if (n2954)
      n3211 <= n3011;
    else
      n3211 <= n3009;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:227:7 */
  always @(posedge clk_i or posedge n3106)
    if (n3106)
      n3212 <= 1'b0;
    else
      n3212 <= n3117;
endmodule

module neorv32_sysinfo_Bneorv32_sysinfo_rtl_Lneorv32_16_2048_1_100000000_2_16384_16384_4_4_64_ced63791903ad0e2711f1008bce20abcabf7e534
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \bus_req_i[meta] ,
   input  [31:0] \bus_req_i[addr] ,
   input  [31:0] \bus_req_i[data] ,
   input  [3:0] \bus_req_i[ben] ,
   input  \bus_req_i[stb] ,
   input  \bus_req_i[rw] ,
   input  \bus_req_i[amo] ,
   input  [3:0] \bus_req_i[amoop] ,
   input  \bus_req_i[burst] ,
   input  \bus_req_i[lock] ,
   output \bus_rsp_o[ack] ,
   output \bus_rsp_o[err] ,
   output [31:0] \bus_rsp_o[data] );
  wire [81:0] n2726;
  wire n2728;
  wire n2729;
  wire [31:0] n2730;
  wire [127:0] sysinfo;
  wire n2732;
  wire n2735;
  wire n2736;
  wire n2737;
  wire [1:0] n2738;
  wire n2740;
  wire n2741;
  wire [31:0] n2742;
  wire [7:0] n2751;
  wire [7:0] n2755;
  wire n2763;
  wire n2767;
  wire n2770;
  wire n2773;
  wire n2777;
  wire n2781;
  wire n2785;
  wire n2789;
  wire n2796;
  wire n2800;
  wire n2804;
  wire n2808;
  wire n2812;
  wire n2816;
  wire n2820;
  wire n2824;
  wire n2828;
  wire n2832;
  wire n2836;
  wire n2840;
  wire n2844;
  wire n2848;
  wire n2852;
  wire n2856;
  wire n2860;
  wire n2864;
  wire n2868;
  wire n2872;
  wire n2876;
  wire [3:0] n2880;
  wire [3:0] n2884;
  wire [3:0] n2888;
  wire [3:0] n2892;
  wire n2896;
  wire n2900;
  wire n2902;
  wire [1:0] n2903;
  wire [1:0] n2906;
  wire n2910;
  wire [1:0] n2911;
  wire n2913;
  wire n2914;
  wire n2917;
  wire [33:0] n2918;
  wire [33:0] n2920;
  wire [127:0] n2926;
  reg [33:0] n2927;
  wire [31:0] n2928;
  wire [31:0] n2929;
  reg [31:0] n2930;
  wire [31:0] n2931;
  assign \bus_rsp_o[ack]  = n2728; //(module output)
  assign \bus_rsp_o[err]  = n2729; //(module output)
  assign \bus_rsp_o[data]  = n2730; //(module output)
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2726 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2728 = n2927[0]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2729 = n2927[1]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2730 = n2927[33:2]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:85:10 */
  assign sysinfo = n2926; // (signal)
  /*# ../../rtl/core/neorv32_sysinfo.vhd:93:16 */
  assign n2732 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:21 */
  assign n2735 = n2726[73]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:47 */
  assign n2736 = n2726[74]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:32 */
  assign n2737 = n2736 & n2735;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:76 */
  assign n2738 = n2726[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:89 */
  assign n2740 = n2738 == 2'b00;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:57 */
  assign n2741 = n2740 & n2737;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:97:33 */
  assign n2742 = n2726[68:37]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:104:83 */
  assign n2751 = 1'b1 ? 8'b00001110 : 8'b00000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:105:83 */
  assign n2755 = 1'b1 ? 8'b00001110 : 8'b00000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:113:25 */
  assign n2763 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:114:25 */
  assign n2767 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:115:25 */
  assign n2770 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:116:25 */
  assign n2773 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:117:25 */
  assign n2777 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:118:25 */
  assign n2781 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:119:25 */
  assign n2785 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:120:25 */
  assign n2789 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:124:25 */
  assign n2796 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:125:25 */
  assign n2800 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:126:25 */
  assign n2804 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:127:25 */
  assign n2808 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:128:25 */
  assign n2812 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:129:25 */
  assign n2816 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:130:25 */
  assign n2820 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:131:25 */
  assign n2824 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:132:25 */
  assign n2828 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:133:25 */
  assign n2832 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:134:25 */
  assign n2836 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:135:25 */
  assign n2840 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:136:25 */
  assign n2844 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:137:25 */
  assign n2848 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:138:25 */
  assign n2852 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:139:25 */
  assign n2856 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:140:25 */
  assign n2860 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:141:25 */
  assign n2864 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:142:25 */
  assign n2868 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:143:25 */
  assign n2872 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:144:25 */
  assign n2876 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:148:81 */
  assign n2880 = 1'b0 ? 4'b0110 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:149:81 */
  assign n2884 = 1'b0 ? 4'b0010 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:150:81 */
  assign n2888 = 1'b0 ? 4'b0010 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:151:45 */
  assign n2892 = 1'b0 ? 4'b1111 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:152:35 */
  assign n2896 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:159:16 */
  assign n2900 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:21 */
  assign n2902 = n2726[73]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:69 */
  assign n2903 = n2726[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:35 */
  assign n2906 = 2'b11 - n2903;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:23 */
  assign n2910 = n2726[74]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:52 */
  assign n2911 = n2726[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:65 */
  assign n2913 = n2911 != 2'b00;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:33 */
  assign n2914 = n2913 & n2910;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:9 */
  assign n2917 = n2914 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:7 */
  assign n2918 = {n2931, n2917, 1'b1};
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:7 */
  assign n2920 = n2902 ? n2918 : 34'b0000000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:85:10 */
  assign n2926 = {n2930, 5'b01011, 5'b00100, 2'b10, 4'b0001, n2755, n2751, n2876, n2872, n2868, n2864, n2860, n2856, n2852, n2848, n2844, n2840, n2836, n2832, n2828, n2824, n2820, n2816, n2812, n2808, n2804, n2800, n2796, 1'b0, 1'b0, 1'b0, n2789, n2785, n2781, n2777, n2773, n2770, n2767, n2763, 15'b000000000000000, n2896, n2892, n2888, n2884, n2880};
  /*# ../../rtl/core/neorv32_sysinfo.vhd:161:5 */
  always @(posedge clk_i or posedge n2900)
    if (n2900)
      n2927 <= 34'b0000000000000000000000000000000000;
    else
      n2927 <= n2920;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  assign n2928 = sysinfo[127:96]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  assign n2929 = n2741 ? n2742 : n2928;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  always @(posedge clk_i or posedge n2732)
    if (n2732)
      n2930 <= 32'b00000101111101011110000100000000;
    else
      n2930 <= n2929;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:35 */
  assign n2931 = sysinfo[n2906 * 32 +: 32]; //(Bmux)
endmodule

module neorv32_uart_Bneorv32_uart_rtl_Lneorv32_1_1
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \bus_req_i[meta] ,
   input  [31:0] \bus_req_i[addr] ,
   input  [31:0] \bus_req_i[data] ,
   input  [3:0] \bus_req_i[ben] ,
   input  \bus_req_i[stb] ,
   input  \bus_req_i[rw] ,
   input  \bus_req_i[amo] ,
   input  [3:0] \bus_req_i[amoop] ,
   input  \bus_req_i[burst] ,
   input  \bus_req_i[lock] ,
   output \bus_rsp_o[ack] ,
   output \bus_rsp_o[err] ,
   output [31:0] \bus_rsp_o[data] ,
   input  [7:0] clkgen_i,
   output uart_txd_o,
   input  uart_rxd_i,
   output uart_rtsn_o,
   input  uart_ctsn_i,
   output irq_o);
  wire [81:0] n2270;
  wire n2272;
  wire n2273;
  wire [31:0] n2274;
  wire uart_clk;
  wire [19:0] ctrl;
  wire [28:0] tx;
  wire [28:0] rx;
  wire rx_overrun;
  wire [20:0] rx_fifo;
  wire [20:0] tx_fifo;
  wire n2279;
  wire n2290;
  localparam [31:0] n2292 = 32'b00000000000000000000000000000000;
  wire n2293;
  wire n2294;
  wire n2295;
  wire n2296;
  wire n2297;
  wire n2298;
  wire n2301;
  wire n2302;
  wire [2:0] n2303;
  wire [9:0] n2304;
  wire n2305;
  wire n2306;
  wire n2307;
  wire n2308;
  wire [19:0] n2309;
  wire n2311;
  wire n2312;
  wire n2313;
  wire n2314;
  wire n2317;
  wire n2318;
  wire [2:0] n2319;
  wire [9:0] n2320;
  wire n2321;
  wire n2322;
  wire n2323;
  wire n2324;
  wire n2325;
  wire n2326;
  wire n2327;
  wire n2328;
  wire n2329;
  wire n2330;
  wire n2331;
  wire n2332;
  wire n2333;
  wire [7:0] n2334;
  wire [15:0] n2337;
  wire [23:0] n2338;
  wire [1:0] n2339;
  wire [15:0] n2340;
  wire [15:0] n2341;
  wire [7:0] n2342;
  wire [7:0] n2343;
  wire [7:0] n2344;
  wire [1:0] n2345;
  wire [1:0] n2346;
  wire [23:0] n2347;
  wire [23:0] n2348;
  wire [23:0] n2349;
  wire [1:0] n2350;
  wire [1:0] n2351;
  wire n2352;
  wire [23:0] n2353;
  wire [23:0] n2354;
  wire [1:0] n2355;
  wire [1:0] n2356;
  wire [5:0] n2358;
  wire n2359;
  wire [33:0] n2360;
  wire [19:0] n2365;
  wire [2:0] n2368;
  wire \tx_fifo_inst.free_o ;
  wire [7:0] \tx_fifo_inst.rdata_o ;
  wire \tx_fifo_inst.avail_o ;
  wire n2372;
  wire [7:0] n2373;
  wire n2374;
  wire n2376;
  wire n2380;
  wire n2381;
  wire n2382;
  wire n2383;
  wire n2384;
  wire [7:0] n2386;
  wire n2388;
  wire n2389;
  wire n2390;
  wire n2391;
  wire n2392;
  wire n2393;
  wire n2395;
  wire \rx_fifo_inst.free_o ;
  wire [7:0] \rx_fifo_inst.rdata_o ;
  wire \rx_fifo_inst.avail_o ;
  wire n2396;
  wire [7:0] n2397;
  wire n2398;
  wire n2400;
  wire n2404;
  wire n2405;
  wire n2406;
  wire n2407;
  wire n2408;
  wire [7:0] n2410;
  wire n2411;
  wire n2413;
  wire n2414;
  wire n2415;
  wire n2416;
  wire n2417;
  wire n2418;
  wire n2419;
  wire n2422;
  wire n2424;
  wire n2425;
  wire n2426;
  wire n2427;
  wire n2428;
  wire n2429;
  wire n2430;
  wire n2431;
  wire n2432;
  wire n2433;
  wire n2434;
  wire n2435;
  wire n2436;
  wire n2437;
  wire n2438;
  wire n2439;
  wire n2440;
  wire n2441;
  wire n2442;
  wire n2448;
  wire [1:0] n2456;
  wire [2:0] n2457;
  wire [2:0] n2458;
  wire [2:0] n2459;
  wire n2461;
  wire [1:0] n2462;
  wire [9:0] n2463;
  wire [7:0] n2465;
  wire [8:0] n2467;
  wire n2468;
  wire n2469;
  wire n2470;
  wire n2471;
  wire n2472;
  wire n2473;
  wire n2474;
  wire n2475;
  wire n2476;
  wire n2477;
  wire n2479;
  wire n2480;
  wire n2482;
  wire n2484;
  wire n2485;
  wire n2493;
  wire n2495;
  wire n2497;
  wire n2498;
  wire n2499;
  wire n2500;
  wire n2501;
  wire n2502;
  wire n2503;
  wire n2504;
  wire n2505;
  wire n2506;
  wire n2507;
  wire n2508;
  wire n2509;
  wire n2510;
  wire n2511;
  wire n2512;
  wire n2513;
  wire n2514;
  wire n2515;
  wire [9:0] n2516;
  wire [3:0] n2517;
  wire [3:0] n2519;
  wire [7:0] n2520;
  wire [8:0] n2522;
  wire [9:0] n2523;
  wire [9:0] n2525;
  wire [22:0] n2526;
  wire [12:0] n2527;
  wire [12:0] n2528;
  wire [12:0] n2529;
  wire [9:0] n2530;
  wire [9:0] n2531;
  wire [22:0] n2532;
  wire [22:0] n2533;
  wire [22:0] n2534;
  wire [3:0] n2535;
  wire n2537;
  wire n2540;
  wire n2541;
  wire n2542;
  wire n2544;
  wire [1:0] n2546;
  reg n2548;
  reg n2550;
  wire [8:0] n2551;
  wire [8:0] n2552;
  reg [8:0] n2553;
  wire [3:0] n2554;
  wire [3:0] n2555;
  reg [3:0] n2556;
  wire [9:0] n2557;
  wire [9:0] n2558;
  reg [9:0] n2559;
  reg n2560;
  wire [28:0] n2562;
  wire [28:0] n2566;
  wire n2570;
  wire [1:0] n2578;
  wire [2:0] n2579;
  wire [2:0] n2580;
  wire [2:0] n2581;
  wire n2583;
  wire [1:0] n2584;
  wire [8:0] n2585;
  wire [9:0] n2587;
  wire [1:0] n2589;
  wire n2591;
  wire n2593;
  wire n2594;
  wire n2596;
  wire n2598;
  wire n2606;
  wire n2608;
  wire n2610;
  wire n2611;
  wire n2612;
  wire n2613;
  wire n2614;
  wire n2615;
  wire n2616;
  wire n2617;
  wire n2618;
  wire n2619;
  wire n2620;
  wire n2621;
  wire n2622;
  wire n2623;
  wire n2624;
  wire n2625;
  wire n2626;
  wire n2627;
  wire n2628;
  wire [9:0] n2629;
  wire [3:0] n2630;
  wire [3:0] n2632;
  wire n2633;
  wire n2634;
  wire n2635;
  wire [7:0] n2636;
  wire [8:0] n2637;
  wire [9:0] n2638;
  wire [9:0] n2640;
  wire [22:0] n2641;
  wire [12:0] n2642;
  wire [12:0] n2643;
  wire [12:0] n2644;
  wire [9:0] n2645;
  wire [9:0] n2646;
  wire [22:0] n2647;
  wire [22:0] n2648;
  wire [22:0] n2649;
  wire [3:0] n2650;
  wire n2652;
  wire n2655;
  wire n2656;
  wire n2657;
  wire n2659;
  wire [1:0] n2661;
  reg n2662;
  wire [8:0] n2663;
  wire [8:0] n2664;
  reg [8:0] n2665;
  wire [3:0] n2666;
  wire [3:0] n2667;
  reg [3:0] n2668;
  wire [9:0] n2669;
  wire [9:0] n2670;
  reg [9:0] n2671;
  reg n2672;
  wire [28:0] n2673;
  wire [28:0] n2675;
  wire n2679;
  wire n2681;
  wire n2682;
  wire n2683;
  wire n2684;
  wire n2685;
  wire n2686;
  wire n2687;
  wire n2688;
  wire n2689;
  wire n2690;
  wire n2691;
  wire n2692;
  wire n2693;
  wire n2694;
  wire n2695;
  wire n2696;
  wire n2697;
  wire n2698;
  wire n2699;
  wire n2700;
  wire n2702;
  wire n2704;
  wire n2706;
  wire [20:0] n2714;
  wire [20:0] n2715;
  reg [33:0] n2716;
  reg n2717;
  reg n2718;
  reg n2719;
  wire [19:0] n2720;
  reg [19:0] n2721;
  reg [28:0] n2722;
  reg [28:0] n2723;
  reg n2724;
  wire n2725;
  assign \bus_rsp_o[ack]  = n2272; //(module output)
  assign \bus_rsp_o[err]  = n2273; //(module output)
  assign \bus_rsp_o[data]  = n2274; //(module output)
  assign uart_txd_o = n2717; //(module output)
  assign uart_rtsn_o = n2718; //(module output)
  assign irq_o = n2719; //(module output)
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2270 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2272 = n2716[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2273 = n2716[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2274 = n2716[33:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:78:10 */
  assign uart_clk = n2725; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:92:10 */
  assign ctrl = n2721; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign tx = n2722; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign rx = n2723; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:104:10 */
  assign rx_overrun = n2724; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:112:10 */
  assign rx_fifo = n2714; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:112:19 */
  assign tx_fifo = n2715; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:120:16 */
  assign n2279 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:133:35 */
  assign n2290 = n2270[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:21 */
  assign n2293 = n2270[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:23 */
  assign n2294 = n2270[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:29 */
  assign n2295 = n2270[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:33 */
  assign n2296 = ~n2295;
  /*# ../../rtl/core/neorv32_uart.vhd:140:49 */
  assign n2297 = n2270[37]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:141:49 */
  assign n2298 = n2270[38]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:141:65 */
  assign n2301 = n2298 & 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:142:49 */
  assign n2302 = n2270[39]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:143:49 */
  assign n2303 = n2270[42:40]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:144:49 */
  assign n2304 = n2270[52:43]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:145:49 */
  assign n2305 = n2270[57]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:146:49 */
  assign n2306 = n2270[58]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:147:49 */
  assign n2307 = n2270[59]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:148:49 */
  assign n2308 = n2270[60]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:11 */
  assign n2309 = {n2308, n2307, n2306, n2305, n2304, n2303, n2302, n2301, n2297};
  /*# ../../rtl/core/neorv32_uart.vhd:151:29 */
  assign n2311 = n2270[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:33 */
  assign n2312 = ~n2311;
  /*# ../../rtl/core/neorv32_uart.vhd:152:70 */
  assign n2313 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:153:70 */
  assign n2314 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:153:79 */
  assign n2317 = n2314 & 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:154:70 */
  assign n2318 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:155:70 */
  assign n2319 = ctrl[5:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:156:70 */
  assign n2320 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:157:73 */
  assign n2321 = rx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:158:77 */
  assign n2322 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:158:65 */
  assign n2323 = ~n2322;
  /*# ../../rtl/core/neorv32_uart.vhd:159:77 */
  assign n2324 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:159:65 */
  assign n2325 = ~n2324;
  /*# ../../rtl/core/neorv32_uart.vhd:160:73 */
  assign n2326 = tx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:161:70 */
  assign n2327 = ctrl[16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:162:70 */
  assign n2328 = ctrl[17]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:163:70 */
  assign n2329 = ctrl[18]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:164:70 */
  assign n2330 = ctrl[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:73 */
  assign n2331 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:88 */
  assign n2332 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:77 */
  assign n2333 = n2331 | n2332;
  /*# ../../rtl/core/neorv32_uart.vhd:168:85 */
  assign n2334 = rx_fifo[18:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2337 = {4'b0000, 4'b0000, n2334};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2338 = {n2330, n2329, n2328, n2327, n2326, n2325, n2323, n2321, n2320, n2319, n2318, n2317, n2313};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2339 = {n2333, rx_overrun};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2340 = n2338[15:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2341 = n2312 ? n2340 : n2337;
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2342 = n2338[23:16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2343 = n2292[23:16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2344 = n2312 ? n2342 : n2343;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2345 = n2292[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2346 = n2312 ? n2339 : n2345;
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2347 = {n2344, n2341};
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2348 = n2292[23:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2349 = n2294 ? n2348 : n2347;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2350 = n2292[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2351 = n2294 ? n2350 : n2346;
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2352 = n2296 & n2294;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2353 = n2292[23:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2354 = n2293 ? n2349 : n2353;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2355 = n2292[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2356 = n2293 ? n2351 : n2355;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2358 = n2292[29:24]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2359 = n2352 & n2293;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  assign n2360 = {n2356, n2358, n2354, 1'b0, n2290};
  /*# ../../rtl/core/neorv32_uart.vhd:120:5 */
  assign n2365 = {1'b0, 1'b0, 1'b0, 1'b0, 10'b0000000000, 3'b000, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_uart.vhd:178:49 */
  assign n2368 = ctrl[5:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:183:3 */
  neorv32_prim_fifo_Bneorv32_prim_fifo_rtl_Lneorv32_0_8_5ba93c9db0cff93f52b521d7420e43f6eda2784f tx_fifo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(n2372),
    .wdata_i(n2373),
    .we_i(n2374),
    .re_i(n2376),
    .free_o(\tx_fifo_inst.free_o ),
    .rdata_o(\tx_fifo_inst.rdata_o ),
    .avail_o(\tx_fifo_inst.avail_o ));
  /*# ../../rtl/core/neorv32_uart.vhd:193:24 */
  assign n2372 = tx_fifo[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:195:24 */
  assign n2373 = tx_fifo[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:196:24 */
  assign n2374 = tx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:199:24 */
  assign n2376 = tx_fifo[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:35 */
  assign n2380 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:42 */
  assign n2381 = ~n2380;
  /*# ../../rtl/core/neorv32_uart.vhd:204:58 */
  assign n2382 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:49 */
  assign n2383 = n2381 | n2382;
  /*# ../../rtl/core/neorv32_uart.vhd:204:24 */
  assign n2384 = n2383 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:205:34 */
  assign n2386 = n2270[44:37]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:40 */
  assign n2388 = n2270[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:66 */
  assign n2389 = n2270[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:51 */
  assign n2390 = n2389 & n2388;
  /*# ../../rtl/core/neorv32_uart.vhd:206:95 */
  assign n2391 = n2270[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:76 */
  assign n2392 = n2391 & n2390;
  /*# ../../rtl/core/neorv32_uart.vhd:206:24 */
  assign n2393 = n2392 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:207:23 */
  assign n2395 = tx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:212:3 */
  neorv32_prim_fifo_Bneorv32_prim_fifo_rtl_Lneorv32_0_8_5ba93c9db0cff93f52b521d7420e43f6eda2784f rx_fifo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(n2396),
    .wdata_i(n2397),
    .we_i(n2398),
    .re_i(n2400),
    .free_o(\rx_fifo_inst.free_o ),
    .rdata_o(\rx_fifo_inst.rdata_o ),
    .avail_o(\rx_fifo_inst.avail_o ));
  /*# ../../rtl/core/neorv32_uart.vhd:222:24 */
  assign n2396 = rx_fifo[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:224:24 */
  assign n2397 = rx_fifo[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:225:24 */
  assign n2398 = rx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:228:24 */
  assign n2400 = rx_fifo[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:35 */
  assign n2404 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:42 */
  assign n2405 = ~n2404;
  /*# ../../rtl/core/neorv32_uart.vhd:233:58 */
  assign n2406 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:49 */
  assign n2407 = n2405 | n2406;
  /*# ../../rtl/core/neorv32_uart.vhd:233:24 */
  assign n2408 = n2407 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:234:27 */
  assign n2410 = rx[9:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:235:23 */
  assign n2411 = rx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:40 */
  assign n2413 = n2270[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:66 */
  assign n2414 = n2270[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:69 */
  assign n2415 = ~n2414;
  /*# ../../rtl/core/neorv32_uart.vhd:236:51 */
  assign n2416 = n2415 & n2413;
  /*# ../../rtl/core/neorv32_uart.vhd:236:95 */
  assign n2417 = n2270[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:76 */
  assign n2418 = n2417 & n2416;
  /*# ../../rtl/core/neorv32_uart.vhd:236:24 */
  assign n2419 = n2418 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:243:16 */
  assign n2422 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:246:21 */
  assign n2424 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:22 */
  assign n2425 = ctrl[18]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:53 */
  assign n2426 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:41 */
  assign n2427 = ~n2426;
  /*# ../../rtl/core/neorv32_uart.vhd:247:36 */
  assign n2428 = n2425 & n2427;
  /*# ../../rtl/core/neorv32_uart.vhd:248:22 */
  assign n2429 = ctrl[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:248:48 */
  assign n2430 = tx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:248:36 */
  assign n2431 = n2429 & n2430;
  /*# ../../rtl/core/neorv32_uart.vhd:247:61 */
  assign n2432 = n2428 | n2431;
  /*# ../../rtl/core/neorv32_uart.vhd:249:22 */
  assign n2433 = ctrl[16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:249:48 */
  assign n2434 = rx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:249:36 */
  assign n2435 = n2433 & n2434;
  /*# ../../rtl/core/neorv32_uart.vhd:248:61 */
  assign n2436 = n2432 | n2435;
  /*# ../../rtl/core/neorv32_uart.vhd:250:22 */
  assign n2437 = ctrl[17]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:250:53 */
  assign n2438 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:250:41 */
  assign n2439 = ~n2438;
  /*# ../../rtl/core/neorv32_uart.vhd:250:36 */
  assign n2440 = n2437 & n2439;
  /*# ../../rtl/core/neorv32_uart.vhd:249:61 */
  assign n2441 = n2436 | n2440;
  /*# ../../rtl/core/neorv32_uart.vhd:246:28 */
  assign n2442 = n2424 & n2441;
  /*# ../../rtl/core/neorv32_uart.vhd:259:16 */
  assign n2448 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:269:27 */
  assign n2456 = tx[26:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:269:40 */
  assign n2457 = {n2456, uart_ctsn_i};
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2458 = tx[27:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:268:7 */
  assign n2459 = uart_clk ? n2457 : n2458;
  /*# ../../rtl/core/neorv32_uart.vhd:273:27 */
  assign n2461 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:15 */
  assign n2462 = tx[1:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:278:30 */
  assign n2463 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:280:33 */
  assign n2465 = tx_fifo[18:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:280:39 */
  assign n2467 = {n2465, 1'b0};
  /*# ../../rtl/core/neorv32_uart.vhd:281:23 */
  assign n2468 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:44 */
  assign n2469 = tx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:49 */
  assign n2470 = ~n2469;
  /*# ../../rtl/core/neorv32_uart.vhd:281:36 */
  assign n2471 = n2470 & n2468;
  /*# ../../rtl/core/neorv32_uart.vhd:283:25 */
  assign n2472 = tx[26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:283:29 */
  assign n2473 = ~n2472;
  /*# ../../rtl/core/neorv32_uart.vhd:283:45 */
  assign n2474 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:283:53 */
  assign n2475 = ~n2474;
  /*# ../../rtl/core/neorv32_uart.vhd:283:36 */
  assign n2476 = n2473 | n2475;
  /*# ../../rtl/core/neorv32_uart.vhd:282:33 */
  assign n2477 = n2476 & uart_clk;
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2479 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:11 */
  assign n2480 = n2482 ? 1'b1 : n2479;
  /*# ../../rtl/core/neorv32_uart.vhd:281:11 */
  assign n2482 = n2477 & n2471;
  /*# ../../rtl/core/neorv32_uart.vhd:276:9 */
  assign n2484 = n2462 == 2'b10;
  /*# ../../rtl/core/neorv32_uart.vhd:290:32 */
  assign n2485 = tx[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2493 = tx[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2495 = 1'b0 | n2493;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2497 = tx[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2498 = n2495 | n2497;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2499 = tx[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2500 = n2498 | n2499;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2501 = tx[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2502 = n2500 | n2501;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2503 = tx[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2504 = n2502 | n2503;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2505 = tx[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2506 = n2504 | n2505;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2507 = tx[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2508 = n2506 | n2507;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2509 = tx[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2510 = n2508 | n2509;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2511 = tx[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2512 = n2510 | n2511;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2513 = tx[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2514 = n2512 | n2513;
  /*# ../../rtl/core/neorv32_uart.vhd:292:41 */
  assign n2515 = ~n2514;
  /*# ../../rtl/core/neorv32_uart.vhd:293:34 */
  assign n2516 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:294:59 */
  assign n2517 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:294:67 */
  assign n2519 = n2517 - 4'b0001;
  /*# ../../rtl/core/neorv32_uart.vhd:295:42 */
  assign n2520 = tx[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:295:33 */
  assign n2522 = {1'b1, n2520};
  /*# ../../rtl/core/neorv32_uart.vhd:297:59 */
  assign n2523 = tx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:297:68 */
  assign n2525 = n2523 - 10'b0000000001;
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2526 = {n2516, n2519, n2522};
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2527 = n2526[12:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2528 = tx[14:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2529 = n2515 ? n2527 : n2528;
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2530 = n2526[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2531 = n2515 ? n2530 : n2525;
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2532 = {n2531, n2529};
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2533 = tx[24:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2534 = uart_clk ? n2532 : n2533;
  /*# ../../rtl/core/neorv32_uart.vhd:300:18 */
  assign n2535 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:300:25 */
  assign n2537 = n2535 == 4'b0000;
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2540 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:300:11 */
  assign n2541 = n2537 ? 1'b0 : n2540;
  /*# ../../rtl/core/neorv32_uart.vhd:300:11 */
  assign n2542 = n2537 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:288:9 */
  assign n2544 = n2462 == 2'b11;
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  assign n2546 = {n2544, n2484};
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2548 = n2485;
      2'b01: n2548 = 1'b1;
      default: n2548 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2550 = n2541;
      2'b01: n2550 = n2480;
      default: n2550 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2551 = n2534[8:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2552 = tx[10:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2553 = n2551;
      2'b01: n2553 = n2467;
      default: n2553 = n2552;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2554 = n2534[12:9]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2555 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2556 = n2554;
      2'b01: n2556 = 4'b1011;
      default: n2556 = n2555;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2557 = n2534[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2558 = tx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2559 = n2557;
      2'b01: n2559 = n2463;
      default: n2559 = n2558;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2546)
      2'b10: n2560 = n2542;
      2'b01: n2560 = 1'b0;
      default: n2560 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  assign n2562 = {n2560, n2459, n2559, n2556, n2553, n2461, n2550};
  /*# ../../rtl/core/neorv32_uart.vhd:259:5 */
  assign n2566 = {1'b0, 3'b000, 10'b0000000000, 4'b0000, 9'b000000000, 2'b00};
  /*# ../../rtl/core/neorv32_uart.vhd:318:16 */
  assign n2570 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:327:27 */
  assign n2578 = rx[26:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:327:40 */
  assign n2579 = {n2578, uart_rxd_i};
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2580 = rx[27:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:326:7 */
  assign n2581 = uart_clk ? n2579 : n2580;
  /*# ../../rtl/core/neorv32_uart.vhd:330:27 */
  assign n2583 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:15 */
  assign n2584 = rx[1:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:335:40 */
  assign n2585 = ctrl[15:7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:335:29 */
  assign n2587 = {1'b0, n2585};
  /*# ../../rtl/core/neorv32_uart.vhd:337:22 */
  assign n2589 = rx[27:26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:337:35 */
  assign n2591 = n2589 == 2'b10;
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2593 = rx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:337:11 */
  assign n2594 = n2596 ? 1'b1 : n2593;
  /*# ../../rtl/core/neorv32_uart.vhd:337:11 */
  assign n2596 = uart_clk & n2591;
  /*# ../../rtl/core/neorv32_uart.vhd:333:9 */
  assign n2598 = n2584 == 2'b10;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2606 = rx[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2608 = 1'b0 | n2606;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2610 = rx[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2611 = n2608 | n2610;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2612 = rx[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2613 = n2611 | n2612;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2614 = rx[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2615 = n2613 | n2614;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2616 = rx[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2617 = n2615 | n2616;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2618 = rx[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2619 = n2617 | n2618;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2620 = rx[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2621 = n2619 | n2620;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2622 = rx[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2623 = n2621 | n2622;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2624 = rx[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2625 = n2623 | n2624;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2626 = rx[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2627 = n2625 | n2626;
  /*# ../../rtl/core/neorv32_uart.vhd:346:41 */
  assign n2628 = ~n2627;
  /*# ../../rtl/core/neorv32_uart.vhd:347:34 */
  assign n2629 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:348:59 */
  assign n2630 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:348:67 */
  assign n2632 = n2630 - 4'b0001;
  /*# ../../rtl/core/neorv32_uart.vhd:349:37 */
  assign n2633 = rx[27]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:52 */
  assign n2634 = rx[26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:41 */
  assign n2635 = n2633 & n2634;
  /*# ../../rtl/core/neorv32_uart.vhd:349:66 */
  assign n2636 = rx[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:57 */
  assign n2637 = {n2635, n2636};
  /*# ../../rtl/core/neorv32_uart.vhd:351:59 */
  assign n2638 = rx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:351:68 */
  assign n2640 = n2638 - 10'b0000000001;
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2641 = {n2629, n2632, n2637};
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2642 = n2641[12:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2643 = rx[14:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2644 = n2628 ? n2642 : n2643;
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2645 = n2641[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2646 = n2628 ? n2645 : n2640;
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2647 = {n2646, n2644};
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2648 = rx[24:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2649 = uart_clk ? n2647 : n2648;
  /*# ../../rtl/core/neorv32_uart.vhd:354:18 */
  assign n2650 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:354:25 */
  assign n2652 = n2650 == 4'b0000;
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2655 = rx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:354:11 */
  assign n2656 = n2652 ? 1'b0 : n2655;
  /*# ../../rtl/core/neorv32_uart.vhd:354:11 */
  assign n2657 = n2652 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:343:9 */
  assign n2659 = n2584 == 2'b11;
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  assign n2661 = {n2659, n2598};
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2661)
      2'b10: n2662 = n2656;
      2'b01: n2662 = n2594;
      default: n2662 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2663 = n2649[8:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2664 = rx[10:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2661)
      2'b10: n2665 = n2663;
      2'b01: n2665 = n2664;
      default: n2665 = n2664;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2666 = n2649[12:9]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2667 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2661)
      2'b10: n2668 = n2666;
      2'b01: n2668 = 4'b1010;
      default: n2668 = n2667;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2669 = n2649[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2670 = rx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2661)
      2'b10: n2671 = n2669;
      2'b01: n2671 = n2587;
      default: n2671 = n2670;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2661)
      2'b10: n2672 = n2657;
      2'b01: n2672 = 1'b0;
      default: n2672 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:325:5 */
  assign n2673 = {n2672, n2581, n2671, n2668, n2665, n2583, n2662};
  /*# ../../rtl/core/neorv32_uart.vhd:318:5 */
  assign n2675 = {1'b0, 3'b000, 10'b0000000000, 4'b0000, 9'b000000000, 2'b00};
  /*# ../../rtl/core/neorv32_uart.vhd:370:16 */
  assign n2679 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:374:27 */
  assign n2681 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:50 */
  assign n2682 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:41 */
  assign n2683 = ~n2682;
  /*# ../../rtl/core/neorv32_uart.vhd:374:74 */
  assign n2684 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:62 */
  assign n2685 = ~n2684;
  /*# ../../rtl/core/neorv32_uart.vhd:374:58 */
  assign n2686 = n2683 | n2685;
  /*# ../../rtl/core/neorv32_uart.vhd:374:35 */
  assign n2687 = n2681 & n2686;
  /*# ../../rtl/core/neorv32_uart.vhd:375:16 */
  assign n2688 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:375:23 */
  assign n2689 = ~n2688;
  /*# ../../rtl/core/neorv32_uart.vhd:377:22 */
  assign n2690 = rx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:377:45 */
  assign n2691 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:377:50 */
  assign n2692 = ~n2691;
  /*# ../../rtl/core/neorv32_uart.vhd:377:32 */
  assign n2693 = n2692 & n2690;
  /*# ../../rtl/core/neorv32_uart.vhd:379:24 */
  assign n2694 = n2270[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:50 */
  assign n2695 = n2270[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:53 */
  assign n2696 = ~n2695;
  /*# ../../rtl/core/neorv32_uart.vhd:379:35 */
  assign n2697 = n2696 & n2694;
  /*# ../../rtl/core/neorv32_uart.vhd:379:79 */
  assign n2698 = n2270[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:83 */
  assign n2699 = ~n2698;
  /*# ../../rtl/core/neorv32_uart.vhd:379:60 */
  assign n2700 = n2699 & n2697;
  /*# ../../rtl/core/neorv32_uart.vhd:379:7 */
  assign n2702 = n2700 ? 1'b0 : rx_overrun;
  /*# ../../rtl/core/neorv32_uart.vhd:377:7 */
  assign n2704 = n2693 ? 1'b1 : n2702;
  /*# ../../rtl/core/neorv32_uart.vhd:375:7 */
  assign n2706 = n2689 ? 1'b0 : n2704;
  /*# ../../rtl/core/neorv32_uart.vhd:112:10 */
  assign n2714 = {\rx_fifo_inst.avail_o , \rx_fifo_inst.free_o , \rx_fifo_inst.rdata_o , n2410, n2419, n2411, n2408};
  /*# ../../rtl/core/neorv32_uart.vhd:112:19 */
  assign n2715 = {\tx_fifo_inst.avail_o , \tx_fifo_inst.free_o , \tx_fifo_inst.rdata_o , n2386, n2395, n2393, n2384};
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  always @(posedge clk_i or posedge n2279)
    if (n2279)
      n2716 <= 34'b0000000000000000000000000000000000;
    else
      n2716 <= n2360;
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  always @(posedge clk_i or posedge n2448)
    if (n2448)
      n2717 <= 1'b1;
    else
      n2717 <= n2548;
  /*# ../../rtl/core/neorv32_uart.vhd:373:5 */
  always @(posedge clk_i or posedge n2679)
    if (n2679)
      n2718 <= 1'b0;
    else
      n2718 <= n2687;
  /*# ../../rtl/core/neorv32_uart.vhd:245:5 */
  always @(posedge clk_i or posedge n2422)
    if (n2422)
      n2719 <= 1'b0;
    else
      n2719 <= n2442;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  assign n2720 = n2359 ? n2309 : ctrl;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  always @(posedge clk_i or posedge n2279)
    if (n2279)
      n2721 <= n2365;
    else
      n2721 <= n2720;
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  always @(posedge clk_i or posedge n2448)
    if (n2448)
      n2722 <= n2566;
    else
      n2722 <= n2562;
  /*# ../../rtl/core/neorv32_uart.vhd:325:5 */
  always @(posedge clk_i or posedge n2570)
    if (n2570)
      n2723 <= n2675;
    else
      n2723 <= n2673;
  /*# ../../rtl/core/neorv32_uart.vhd:373:5 */
  always @(posedge clk_i or posedge n2679)
    if (n2679)
      n2724 <= 1'b0;
    else
      n2724 <= n2706;
  /*# ../../rtl/core/neorv32_uart.vhd:178:24 */
  assign n2725 = clkgen_i[n2368 * 1 +: 1]; //(Bmux)
endmodule

module neorv32_bus_io_switch_Bneorv32_bus_io_switch_rtl_Lneorv32_65536_1b53c2fe5410ef4bb6e1726f52befa7beb54e9a8
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \main_req_i[meta] ,
   input  [31:0] \main_req_i[addr] ,
   input  [31:0] \main_req_i[data] ,
   input  [3:0] \main_req_i[ben] ,
   input  \main_req_i[stb] ,
   input  \main_req_i[rw] ,
   input  \main_req_i[amo] ,
   input  [3:0] \main_req_i[amoop] ,
   input  \main_req_i[burst] ,
   input  \main_req_i[lock] ,
   output \main_rsp_o[ack] ,
   output \main_rsp_o[err] ,
   output [31:0] \main_rsp_o[data] ,
   output [4:0] \dev_00_req_o[meta] ,
   output [31:0] \dev_00_req_o[addr] ,
   output [31:0] \dev_00_req_o[data] ,
   output [3:0] \dev_00_req_o[ben] ,
   output \dev_00_req_o[stb] ,
   output \dev_00_req_o[rw] ,
   output \dev_00_req_o[amo] ,
   output [3:0] \dev_00_req_o[amoop] ,
   output \dev_00_req_o[burst] ,
   output \dev_00_req_o[lock] ,
   input  \dev_00_rsp_i[ack] ,
   input  \dev_00_rsp_i[err] ,
   input  [31:0] \dev_00_rsp_i[data] ,
   output [4:0] \dev_01_req_o[meta] ,
   output [31:0] \dev_01_req_o[addr] ,
   output [31:0] \dev_01_req_o[data] ,
   output [3:0] \dev_01_req_o[ben] ,
   output \dev_01_req_o[stb] ,
   output \dev_01_req_o[rw] ,
   output \dev_01_req_o[amo] ,
   output [3:0] \dev_01_req_o[amoop] ,
   output \dev_01_req_o[burst] ,
   output \dev_01_req_o[lock] ,
   input  \dev_01_rsp_i[ack] ,
   input  \dev_01_rsp_i[err] ,
   input  [31:0] \dev_01_rsp_i[data] ,
   output [4:0] \dev_02_req_o[meta] ,
   output [31:0] \dev_02_req_o[addr] ,
   output [31:0] \dev_02_req_o[data] ,
   output [3:0] \dev_02_req_o[ben] ,
   output \dev_02_req_o[stb] ,
   output \dev_02_req_o[rw] ,
   output \dev_02_req_o[amo] ,
   output [3:0] \dev_02_req_o[amoop] ,
   output \dev_02_req_o[burst] ,
   output \dev_02_req_o[lock] ,
   input  \dev_02_rsp_i[ack] ,
   input  \dev_02_rsp_i[err] ,
   input  [31:0] \dev_02_rsp_i[data] ,
   output [4:0] \dev_03_req_o[meta] ,
   output [31:0] \dev_03_req_o[addr] ,
   output [31:0] \dev_03_req_o[data] ,
   output [3:0] \dev_03_req_o[ben] ,
   output \dev_03_req_o[stb] ,
   output \dev_03_req_o[rw] ,
   output \dev_03_req_o[amo] ,
   output [3:0] \dev_03_req_o[amoop] ,
   output \dev_03_req_o[burst] ,
   output \dev_03_req_o[lock] ,
   input  \dev_03_rsp_i[ack] ,
   input  \dev_03_rsp_i[err] ,
   input  [31:0] \dev_03_rsp_i[data] ,
   output [4:0] \dev_04_req_o[meta] ,
   output [31:0] \dev_04_req_o[addr] ,
   output [31:0] \dev_04_req_o[data] ,
   output [3:0] \dev_04_req_o[ben] ,
   output \dev_04_req_o[stb] ,
   output \dev_04_req_o[rw] ,
   output \dev_04_req_o[amo] ,
   output [3:0] \dev_04_req_o[amoop] ,
   output \dev_04_req_o[burst] ,
   output \dev_04_req_o[lock] ,
   input  \dev_04_rsp_i[ack] ,
   input  \dev_04_rsp_i[err] ,
   input  [31:0] \dev_04_rsp_i[data] ,
   output [4:0] \dev_05_req_o[meta] ,
   output [31:0] \dev_05_req_o[addr] ,
   output [31:0] \dev_05_req_o[data] ,
   output [3:0] \dev_05_req_o[ben] ,
   output \dev_05_req_o[stb] ,
   output \dev_05_req_o[rw] ,
   output \dev_05_req_o[amo] ,
   output [3:0] \dev_05_req_o[amoop] ,
   output \dev_05_req_o[burst] ,
   output \dev_05_req_o[lock] ,
   input  \dev_05_rsp_i[ack] ,
   input  \dev_05_rsp_i[err] ,
   input  [31:0] \dev_05_rsp_i[data] ,
   output [4:0] \dev_06_req_o[meta] ,
   output [31:0] \dev_06_req_o[addr] ,
   output [31:0] \dev_06_req_o[data] ,
   output [3:0] \dev_06_req_o[ben] ,
   output \dev_06_req_o[stb] ,
   output \dev_06_req_o[rw] ,
   output \dev_06_req_o[amo] ,
   output [3:0] \dev_06_req_o[amoop] ,
   output \dev_06_req_o[burst] ,
   output \dev_06_req_o[lock] ,
   input  \dev_06_rsp_i[ack] ,
   input  \dev_06_rsp_i[err] ,
   input  [31:0] \dev_06_rsp_i[data] ,
   output [4:0] \dev_07_req_o[meta] ,
   output [31:0] \dev_07_req_o[addr] ,
   output [31:0] \dev_07_req_o[data] ,
   output [3:0] \dev_07_req_o[ben] ,
   output \dev_07_req_o[stb] ,
   output \dev_07_req_o[rw] ,
   output \dev_07_req_o[amo] ,
   output [3:0] \dev_07_req_o[amoop] ,
   output \dev_07_req_o[burst] ,
   output \dev_07_req_o[lock] ,
   input  \dev_07_rsp_i[ack] ,
   input  \dev_07_rsp_i[err] ,
   input  [31:0] \dev_07_rsp_i[data] ,
   output [4:0] \dev_08_req_o[meta] ,
   output [31:0] \dev_08_req_o[addr] ,
   output [31:0] \dev_08_req_o[data] ,
   output [3:0] \dev_08_req_o[ben] ,
   output \dev_08_req_o[stb] ,
   output \dev_08_req_o[rw] ,
   output \dev_08_req_o[amo] ,
   output [3:0] \dev_08_req_o[amoop] ,
   output \dev_08_req_o[burst] ,
   output \dev_08_req_o[lock] ,
   input  \dev_08_rsp_i[ack] ,
   input  \dev_08_rsp_i[err] ,
   input  [31:0] \dev_08_rsp_i[data] ,
   output [4:0] \dev_09_req_o[meta] ,
   output [31:0] \dev_09_req_o[addr] ,
   output [31:0] \dev_09_req_o[data] ,
   output [3:0] \dev_09_req_o[ben] ,
   output \dev_09_req_o[stb] ,
   output \dev_09_req_o[rw] ,
   output \dev_09_req_o[amo] ,
   output [3:0] \dev_09_req_o[amoop] ,
   output \dev_09_req_o[burst] ,
   output \dev_09_req_o[lock] ,
   input  \dev_09_rsp_i[ack] ,
   input  \dev_09_rsp_i[err] ,
   input  [31:0] \dev_09_rsp_i[data] ,
   output [4:0] \dev_10_req_o[meta] ,
   output [31:0] \dev_10_req_o[addr] ,
   output [31:0] \dev_10_req_o[data] ,
   output [3:0] \dev_10_req_o[ben] ,
   output \dev_10_req_o[stb] ,
   output \dev_10_req_o[rw] ,
   output \dev_10_req_o[amo] ,
   output [3:0] \dev_10_req_o[amoop] ,
   output \dev_10_req_o[burst] ,
   output \dev_10_req_o[lock] ,
   input  \dev_10_rsp_i[ack] ,
   input  \dev_10_rsp_i[err] ,
   input  [31:0] \dev_10_rsp_i[data] ,
   output [4:0] \dev_11_req_o[meta] ,
   output [31:0] \dev_11_req_o[addr] ,
   output [31:0] \dev_11_req_o[data] ,
   output [3:0] \dev_11_req_o[ben] ,
   output \dev_11_req_o[stb] ,
   output \dev_11_req_o[rw] ,
   output \dev_11_req_o[amo] ,
   output [3:0] \dev_11_req_o[amoop] ,
   output \dev_11_req_o[burst] ,
   output \dev_11_req_o[lock] ,
   input  \dev_11_rsp_i[ack] ,
   input  \dev_11_rsp_i[err] ,
   input  [31:0] \dev_11_rsp_i[data] ,
   output [4:0] \dev_12_req_o[meta] ,
   output [31:0] \dev_12_req_o[addr] ,
   output [31:0] \dev_12_req_o[data] ,
   output [3:0] \dev_12_req_o[ben] ,
   output \dev_12_req_o[stb] ,
   output \dev_12_req_o[rw] ,
   output \dev_12_req_o[amo] ,
   output [3:0] \dev_12_req_o[amoop] ,
   output \dev_12_req_o[burst] ,
   output \dev_12_req_o[lock] ,
   input  \dev_12_rsp_i[ack] ,
   input  \dev_12_rsp_i[err] ,
   input  [31:0] \dev_12_rsp_i[data] ,
   output [4:0] \dev_13_req_o[meta] ,
   output [31:0] \dev_13_req_o[addr] ,
   output [31:0] \dev_13_req_o[data] ,
   output [3:0] \dev_13_req_o[ben] ,
   output \dev_13_req_o[stb] ,
   output \dev_13_req_o[rw] ,
   output \dev_13_req_o[amo] ,
   output [3:0] \dev_13_req_o[amoop] ,
   output \dev_13_req_o[burst] ,
   output \dev_13_req_o[lock] ,
   input  \dev_13_rsp_i[ack] ,
   input  \dev_13_rsp_i[err] ,
   input  [31:0] \dev_13_rsp_i[data] ,
   output [4:0] \dev_14_req_o[meta] ,
   output [31:0] \dev_14_req_o[addr] ,
   output [31:0] \dev_14_req_o[data] ,
   output [3:0] \dev_14_req_o[ben] ,
   output \dev_14_req_o[stb] ,
   output \dev_14_req_o[rw] ,
   output \dev_14_req_o[amo] ,
   output [3:0] \dev_14_req_o[amoop] ,
   output \dev_14_req_o[burst] ,
   output \dev_14_req_o[lock] ,
   input  \dev_14_rsp_i[ack] ,
   input  \dev_14_rsp_i[err] ,
   input  [31:0] \dev_14_rsp_i[data] ,
   output [4:0] \dev_15_req_o[meta] ,
   output [31:0] \dev_15_req_o[addr] ,
   output [31:0] \dev_15_req_o[data] ,
   output [3:0] \dev_15_req_o[ben] ,
   output \dev_15_req_o[stb] ,
   output \dev_15_req_o[rw] ,
   output \dev_15_req_o[amo] ,
   output [3:0] \dev_15_req_o[amoop] ,
   output \dev_15_req_o[burst] ,
   output \dev_15_req_o[lock] ,
   input  \dev_15_rsp_i[ack] ,
   input  \dev_15_rsp_i[err] ,
   input  [31:0] \dev_15_rsp_i[data] ,
   output [4:0] \dev_16_req_o[meta] ,
   output [31:0] \dev_16_req_o[addr] ,
   output [31:0] \dev_16_req_o[data] ,
   output [3:0] \dev_16_req_o[ben] ,
   output \dev_16_req_o[stb] ,
   output \dev_16_req_o[rw] ,
   output \dev_16_req_o[amo] ,
   output [3:0] \dev_16_req_o[amoop] ,
   output \dev_16_req_o[burst] ,
   output \dev_16_req_o[lock] ,
   input  \dev_16_rsp_i[ack] ,
   input  \dev_16_rsp_i[err] ,
   input  [31:0] \dev_16_rsp_i[data] ,
   output [4:0] \dev_17_req_o[meta] ,
   output [31:0] \dev_17_req_o[addr] ,
   output [31:0] \dev_17_req_o[data] ,
   output [3:0] \dev_17_req_o[ben] ,
   output \dev_17_req_o[stb] ,
   output \dev_17_req_o[rw] ,
   output \dev_17_req_o[amo] ,
   output [3:0] \dev_17_req_o[amoop] ,
   output \dev_17_req_o[burst] ,
   output \dev_17_req_o[lock] ,
   input  \dev_17_rsp_i[ack] ,
   input  \dev_17_rsp_i[err] ,
   input  [31:0] \dev_17_rsp_i[data] ,
   output [4:0] \dev_18_req_o[meta] ,
   output [31:0] \dev_18_req_o[addr] ,
   output [31:0] \dev_18_req_o[data] ,
   output [3:0] \dev_18_req_o[ben] ,
   output \dev_18_req_o[stb] ,
   output \dev_18_req_o[rw] ,
   output \dev_18_req_o[amo] ,
   output [3:0] \dev_18_req_o[amoop] ,
   output \dev_18_req_o[burst] ,
   output \dev_18_req_o[lock] ,
   input  \dev_18_rsp_i[ack] ,
   input  \dev_18_rsp_i[err] ,
   input  [31:0] \dev_18_rsp_i[data] ,
   output [4:0] \dev_19_req_o[meta] ,
   output [31:0] \dev_19_req_o[addr] ,
   output [31:0] \dev_19_req_o[data] ,
   output [3:0] \dev_19_req_o[ben] ,
   output \dev_19_req_o[stb] ,
   output \dev_19_req_o[rw] ,
   output \dev_19_req_o[amo] ,
   output [3:0] \dev_19_req_o[amoop] ,
   output \dev_19_req_o[burst] ,
   output \dev_19_req_o[lock] ,
   input  \dev_19_rsp_i[ack] ,
   input  \dev_19_rsp_i[err] ,
   input  [31:0] \dev_19_rsp_i[data] ,
   output [4:0] \dev_20_req_o[meta] ,
   output [31:0] \dev_20_req_o[addr] ,
   output [31:0] \dev_20_req_o[data] ,
   output [3:0] \dev_20_req_o[ben] ,
   output \dev_20_req_o[stb] ,
   output \dev_20_req_o[rw] ,
   output \dev_20_req_o[amo] ,
   output [3:0] \dev_20_req_o[amoop] ,
   output \dev_20_req_o[burst] ,
   output \dev_20_req_o[lock] ,
   input  \dev_20_rsp_i[ack] ,
   input  \dev_20_rsp_i[err] ,
   input  [31:0] \dev_20_rsp_i[data] ,
   output [4:0] \dev_21_req_o[meta] ,
   output [31:0] \dev_21_req_o[addr] ,
   output [31:0] \dev_21_req_o[data] ,
   output [3:0] \dev_21_req_o[ben] ,
   output \dev_21_req_o[stb] ,
   output \dev_21_req_o[rw] ,
   output \dev_21_req_o[amo] ,
   output [3:0] \dev_21_req_o[amoop] ,
   output \dev_21_req_o[burst] ,
   output \dev_21_req_o[lock] ,
   input  \dev_21_rsp_i[ack] ,
   input  \dev_21_rsp_i[err] ,
   input  [31:0] \dev_21_rsp_i[data] ,
   output [4:0] \dev_22_req_o[meta] ,
   output [31:0] \dev_22_req_o[addr] ,
   output [31:0] \dev_22_req_o[data] ,
   output [3:0] \dev_22_req_o[ben] ,
   output \dev_22_req_o[stb] ,
   output \dev_22_req_o[rw] ,
   output \dev_22_req_o[amo] ,
   output [3:0] \dev_22_req_o[amoop] ,
   output \dev_22_req_o[burst] ,
   output \dev_22_req_o[lock] ,
   input  \dev_22_rsp_i[ack] ,
   input  \dev_22_rsp_i[err] ,
   input  [31:0] \dev_22_rsp_i[data] ,
   output [4:0] \dev_23_req_o[meta] ,
   output [31:0] \dev_23_req_o[addr] ,
   output [31:0] \dev_23_req_o[data] ,
   output [3:0] \dev_23_req_o[ben] ,
   output \dev_23_req_o[stb] ,
   output \dev_23_req_o[rw] ,
   output \dev_23_req_o[amo] ,
   output [3:0] \dev_23_req_o[amoop] ,
   output \dev_23_req_o[burst] ,
   output \dev_23_req_o[lock] ,
   input  \dev_23_rsp_i[ack] ,
   input  \dev_23_rsp_i[err] ,
   input  [31:0] \dev_23_rsp_i[data] ,
   output [4:0] \dev_24_req_o[meta] ,
   output [31:0] \dev_24_req_o[addr] ,
   output [31:0] \dev_24_req_o[data] ,
   output [3:0] \dev_24_req_o[ben] ,
   output \dev_24_req_o[stb] ,
   output \dev_24_req_o[rw] ,
   output \dev_24_req_o[amo] ,
   output [3:0] \dev_24_req_o[amoop] ,
   output \dev_24_req_o[burst] ,
   output \dev_24_req_o[lock] ,
   input  \dev_24_rsp_i[ack] ,
   input  \dev_24_rsp_i[err] ,
   input  [31:0] \dev_24_rsp_i[data] ,
   output [4:0] \dev_25_req_o[meta] ,
   output [31:0] \dev_25_req_o[addr] ,
   output [31:0] \dev_25_req_o[data] ,
   output [3:0] \dev_25_req_o[ben] ,
   output \dev_25_req_o[stb] ,
   output \dev_25_req_o[rw] ,
   output \dev_25_req_o[amo] ,
   output [3:0] \dev_25_req_o[amoop] ,
   output \dev_25_req_o[burst] ,
   output \dev_25_req_o[lock] ,
   input  \dev_25_rsp_i[ack] ,
   input  \dev_25_rsp_i[err] ,
   input  [31:0] \dev_25_rsp_i[data] ,
   output [4:0] \dev_26_req_o[meta] ,
   output [31:0] \dev_26_req_o[addr] ,
   output [31:0] \dev_26_req_o[data] ,
   output [3:0] \dev_26_req_o[ben] ,
   output \dev_26_req_o[stb] ,
   output \dev_26_req_o[rw] ,
   output \dev_26_req_o[amo] ,
   output [3:0] \dev_26_req_o[amoop] ,
   output \dev_26_req_o[burst] ,
   output \dev_26_req_o[lock] ,
   input  \dev_26_rsp_i[ack] ,
   input  \dev_26_rsp_i[err] ,
   input  [31:0] \dev_26_rsp_i[data] ,
   output [4:0] \dev_27_req_o[meta] ,
   output [31:0] \dev_27_req_o[addr] ,
   output [31:0] \dev_27_req_o[data] ,
   output [3:0] \dev_27_req_o[ben] ,
   output \dev_27_req_o[stb] ,
   output \dev_27_req_o[rw] ,
   output \dev_27_req_o[amo] ,
   output [3:0] \dev_27_req_o[amoop] ,
   output \dev_27_req_o[burst] ,
   output \dev_27_req_o[lock] ,
   input  \dev_27_rsp_i[ack] ,
   input  \dev_27_rsp_i[err] ,
   input  [31:0] \dev_27_rsp_i[data] ,
   output [4:0] \dev_28_req_o[meta] ,
   output [31:0] \dev_28_req_o[addr] ,
   output [31:0] \dev_28_req_o[data] ,
   output [3:0] \dev_28_req_o[ben] ,
   output \dev_28_req_o[stb] ,
   output \dev_28_req_o[rw] ,
   output \dev_28_req_o[amo] ,
   output [3:0] \dev_28_req_o[amoop] ,
   output \dev_28_req_o[burst] ,
   output \dev_28_req_o[lock] ,
   input  \dev_28_rsp_i[ack] ,
   input  \dev_28_rsp_i[err] ,
   input  [31:0] \dev_28_rsp_i[data] ,
   output [4:0] \dev_29_req_o[meta] ,
   output [31:0] \dev_29_req_o[addr] ,
   output [31:0] \dev_29_req_o[data] ,
   output [3:0] \dev_29_req_o[ben] ,
   output \dev_29_req_o[stb] ,
   output \dev_29_req_o[rw] ,
   output \dev_29_req_o[amo] ,
   output [3:0] \dev_29_req_o[amoop] ,
   output \dev_29_req_o[burst] ,
   output \dev_29_req_o[lock] ,
   input  \dev_29_rsp_i[ack] ,
   input  \dev_29_rsp_i[err] ,
   input  [31:0] \dev_29_rsp_i[data] ,
   output [4:0] \dev_30_req_o[meta] ,
   output [31:0] \dev_30_req_o[addr] ,
   output [31:0] \dev_30_req_o[data] ,
   output [3:0] \dev_30_req_o[ben] ,
   output \dev_30_req_o[stb] ,
   output \dev_30_req_o[rw] ,
   output \dev_30_req_o[amo] ,
   output [3:0] \dev_30_req_o[amoop] ,
   output \dev_30_req_o[burst] ,
   output \dev_30_req_o[lock] ,
   input  \dev_30_rsp_i[ack] ,
   input  \dev_30_rsp_i[err] ,
   input  [31:0] \dev_30_rsp_i[data] ,
   output [4:0] \dev_31_req_o[meta] ,
   output [31:0] \dev_31_req_o[addr] ,
   output [31:0] \dev_31_req_o[data] ,
   output [3:0] \dev_31_req_o[ben] ,
   output \dev_31_req_o[stb] ,
   output \dev_31_req_o[rw] ,
   output \dev_31_req_o[amo] ,
   output [3:0] \dev_31_req_o[amoop] ,
   output \dev_31_req_o[burst] ,
   output \dev_31_req_o[lock] ,
   input  \dev_31_rsp_i[ack] ,
   input  \dev_31_rsp_i[err] ,
   input  [31:0] \dev_31_rsp_i[data] );
  wire [81:0] n1777;
  wire n1779;
  wire n1780;
  wire [31:0] n1781;
  wire [4:0] n1783;
  wire [31:0] n1784;
  wire [31:0] n1785;
  wire [3:0] n1786;
  wire n1787;
  wire n1788;
  wire n1789;
  wire [3:0] n1790;
  wire n1791;
  wire n1792;
  wire [33:0] n1793;
  wire [4:0] n1795;
  wire [31:0] n1796;
  wire [31:0] n1797;
  wire [3:0] n1798;
  wire n1799;
  wire n1800;
  wire n1801;
  wire [3:0] n1802;
  wire n1803;
  wire n1804;
  wire [33:0] n1805;
  wire [4:0] n1807;
  wire [31:0] n1808;
  wire [31:0] n1809;
  wire [3:0] n1810;
  wire n1811;
  wire n1812;
  wire n1813;
  wire [3:0] n1814;
  wire n1815;
  wire n1816;
  wire [33:0] n1817;
  wire [4:0] n1819;
  wire [31:0] n1820;
  wire [31:0] n1821;
  wire [3:0] n1822;
  wire n1823;
  wire n1824;
  wire n1825;
  wire [3:0] n1826;
  wire n1827;
  wire n1828;
  wire [33:0] n1829;
  wire [4:0] n1831;
  wire [31:0] n1832;
  wire [31:0] n1833;
  wire [3:0] n1834;
  wire n1835;
  wire n1836;
  wire n1837;
  wire [3:0] n1838;
  wire n1839;
  wire n1840;
  wire [33:0] n1841;
  wire [4:0] n1843;
  wire [31:0] n1844;
  wire [31:0] n1845;
  wire [3:0] n1846;
  wire n1847;
  wire n1848;
  wire n1849;
  wire [3:0] n1850;
  wire n1851;
  wire n1852;
  wire [33:0] n1853;
  wire [4:0] n1855;
  wire [31:0] n1856;
  wire [31:0] n1857;
  wire [3:0] n1858;
  wire n1859;
  wire n1860;
  wire n1861;
  wire [3:0] n1862;
  wire n1863;
  wire n1864;
  wire [33:0] n1865;
  wire [4:0] n1867;
  wire [31:0] n1868;
  wire [31:0] n1869;
  wire [3:0] n1870;
  wire n1871;
  wire n1872;
  wire n1873;
  wire [3:0] n1874;
  wire n1875;
  wire n1876;
  wire [33:0] n1877;
  wire [4:0] n1879;
  wire [31:0] n1880;
  wire [31:0] n1881;
  wire [3:0] n1882;
  wire n1883;
  wire n1884;
  wire n1885;
  wire [3:0] n1886;
  wire n1887;
  wire n1888;
  wire [33:0] n1889;
  wire [4:0] n1891;
  wire [31:0] n1892;
  wire [31:0] n1893;
  wire [3:0] n1894;
  wire n1895;
  wire n1896;
  wire n1897;
  wire [3:0] n1898;
  wire n1899;
  wire n1900;
  wire [33:0] n1901;
  wire [4:0] n1903;
  wire [31:0] n1904;
  wire [31:0] n1905;
  wire [3:0] n1906;
  wire n1907;
  wire n1908;
  wire n1909;
  wire [3:0] n1910;
  wire n1911;
  wire n1912;
  wire [33:0] n1913;
  wire [4:0] n1915;
  wire [31:0] n1916;
  wire [31:0] n1917;
  wire [3:0] n1918;
  wire n1919;
  wire n1920;
  wire n1921;
  wire [3:0] n1922;
  wire n1923;
  wire n1924;
  wire [33:0] n1925;
  wire [4:0] n1927;
  wire [31:0] n1928;
  wire [31:0] n1929;
  wire [3:0] n1930;
  wire n1931;
  wire n1932;
  wire n1933;
  wire [3:0] n1934;
  wire n1935;
  wire n1936;
  wire [33:0] n1937;
  wire [4:0] n1939;
  wire [31:0] n1940;
  wire [31:0] n1941;
  wire [3:0] n1942;
  wire n1943;
  wire n1944;
  wire n1945;
  wire [3:0] n1946;
  wire n1947;
  wire n1948;
  wire [33:0] n1949;
  wire [4:0] n1951;
  wire [31:0] n1952;
  wire [31:0] n1953;
  wire [3:0] n1954;
  wire n1955;
  wire n1956;
  wire n1957;
  wire [3:0] n1958;
  wire n1959;
  wire n1960;
  wire [33:0] n1961;
  wire [4:0] n1963;
  wire [31:0] n1964;
  wire [31:0] n1965;
  wire [3:0] n1966;
  wire n1967;
  wire n1968;
  wire n1969;
  wire [3:0] n1970;
  wire n1971;
  wire n1972;
  wire [33:0] n1973;
  wire [4:0] n1975;
  wire [31:0] n1976;
  wire [31:0] n1977;
  wire [3:0] n1978;
  wire n1979;
  wire n1980;
  wire n1981;
  wire [3:0] n1982;
  wire n1983;
  wire n1984;
  wire [33:0] n1985;
  wire [4:0] n1987;
  wire [31:0] n1988;
  wire [31:0] n1989;
  wire [3:0] n1990;
  wire n1991;
  wire n1992;
  wire n1993;
  wire [3:0] n1994;
  wire n1995;
  wire n1996;
  wire [33:0] n1997;
  wire [4:0] n1999;
  wire [31:0] n2000;
  wire [31:0] n2001;
  wire [3:0] n2002;
  wire n2003;
  wire n2004;
  wire n2005;
  wire [3:0] n2006;
  wire n2007;
  wire n2008;
  wire [33:0] n2009;
  wire [4:0] n2011;
  wire [31:0] n2012;
  wire [31:0] n2013;
  wire [3:0] n2014;
  wire n2015;
  wire n2016;
  wire n2017;
  wire [3:0] n2018;
  wire n2019;
  wire n2020;
  wire [33:0] n2021;
  wire [4:0] n2023;
  wire [31:0] n2024;
  wire [31:0] n2025;
  wire [3:0] n2026;
  wire n2027;
  wire n2028;
  wire n2029;
  wire [3:0] n2030;
  wire n2031;
  wire n2032;
  wire [33:0] n2033;
  wire [4:0] n2035;
  wire [31:0] n2036;
  wire [31:0] n2037;
  wire [3:0] n2038;
  wire n2039;
  wire n2040;
  wire n2041;
  wire [3:0] n2042;
  wire n2043;
  wire n2044;
  wire [33:0] n2045;
  wire [4:0] n2047;
  wire [31:0] n2048;
  wire [31:0] n2049;
  wire [3:0] n2050;
  wire n2051;
  wire n2052;
  wire n2053;
  wire [3:0] n2054;
  wire n2055;
  wire n2056;
  wire [33:0] n2057;
  wire [4:0] n2059;
  wire [31:0] n2060;
  wire [31:0] n2061;
  wire [3:0] n2062;
  wire n2063;
  wire n2064;
  wire n2065;
  wire [3:0] n2066;
  wire n2067;
  wire n2068;
  wire [33:0] n2069;
  wire [4:0] n2071;
  wire [31:0] n2072;
  wire [31:0] n2073;
  wire [3:0] n2074;
  wire n2075;
  wire n2076;
  wire n2077;
  wire [3:0] n2078;
  wire n2079;
  wire n2080;
  wire [33:0] n2081;
  wire [4:0] n2083;
  wire [31:0] n2084;
  wire [31:0] n2085;
  wire [3:0] n2086;
  wire n2087;
  wire n2088;
  wire n2089;
  wire [3:0] n2090;
  wire n2091;
  wire n2092;
  wire [33:0] n2093;
  wire [4:0] n2095;
  wire [31:0] n2096;
  wire [31:0] n2097;
  wire [3:0] n2098;
  wire n2099;
  wire n2100;
  wire n2101;
  wire [3:0] n2102;
  wire n2103;
  wire n2104;
  wire [33:0] n2105;
  wire [4:0] n2107;
  wire [31:0] n2108;
  wire [31:0] n2109;
  wire [3:0] n2110;
  wire n2111;
  wire n2112;
  wire n2113;
  wire [3:0] n2114;
  wire n2115;
  wire n2116;
  wire [33:0] n2117;
  wire [4:0] n2119;
  wire [31:0] n2120;
  wire [31:0] n2121;
  wire [3:0] n2122;
  wire n2123;
  wire n2124;
  wire n2125;
  wire [3:0] n2126;
  wire n2127;
  wire n2128;
  wire [33:0] n2129;
  wire [4:0] n2131;
  wire [31:0] n2132;
  wire [31:0] n2133;
  wire [3:0] n2134;
  wire n2135;
  wire n2136;
  wire n2137;
  wire [3:0] n2138;
  wire n2139;
  wire n2140;
  wire [33:0] n2141;
  wire [4:0] n2143;
  wire [31:0] n2144;
  wire [31:0] n2145;
  wire [3:0] n2146;
  wire n2147;
  wire n2148;
  wire n2149;
  wire [3:0] n2150;
  wire n2151;
  wire n2152;
  wire [33:0] n2153;
  wire [4:0] n2155;
  wire [31:0] n2156;
  wire [31:0] n2157;
  wire [3:0] n2158;
  wire n2159;
  wire n2160;
  wire n2161;
  wire [3:0] n2162;
  wire n2163;
  wire n2164;
  wire [33:0] n2165;
  wire [2623:0] dev_req;
  wire [1087:0] dev_rsp;
  wire [81:0] main_req;
  wire [33:0] main_rsp;
  wire \neorv32_bus_reg_inst.host_rsp_o[ack] ;
  wire \neorv32_bus_reg_inst.host_rsp_o[err] ;
  wire [31:0] \neorv32_bus_reg_inst.host_rsp_o[data] ;
  wire [4:0] \neorv32_bus_reg_inst.device_req_o[meta] ;
  wire [31:0] \neorv32_bus_reg_inst.device_req_o[addr] ;
  wire [31:0] \neorv32_bus_reg_inst.device_req_o[data] ;
  wire [3:0] \neorv32_bus_reg_inst.device_req_o[ben] ;
  wire \neorv32_bus_reg_inst.device_req_o[stb] ;
  wire \neorv32_bus_reg_inst.device_req_o[rw] ;
  wire \neorv32_bus_reg_inst.device_req_o[amo] ;
  wire [3:0] \neorv32_bus_reg_inst.device_req_o[amoop] ;
  wire \neorv32_bus_reg_inst.device_req_o[burst] ;
  wire \neorv32_bus_reg_inst.device_req_o[lock] ;
  wire [4:0] n2166;
  wire [31:0] n2167;
  wire [31:0] n2168;
  wire [3:0] n2169;
  wire n2170;
  wire n2171;
  wire n2172;
  wire [3:0] n2173;
  wire n2174;
  wire n2175;
  wire [33:0] n2176;
  wire [81:0] n2178;
  wire n2180;
  wire n2181;
  wire [31:0] n2182;
  wire [81:0] n2183;
  wire [81:0] n2184;
  wire [81:0] n2185;
  wire [81:0] n2186;
  wire [81:0] n2187;
  wire [81:0] n2188;
  wire [81:0] n2189;
  wire [81:0] n2190;
  wire [81:0] n2191;
  wire [81:0] n2192;
  wire [81:0] n2193;
  wire [81:0] n2194;
  wire [81:0] n2195;
  wire [81:0] n2196;
  wire [81:0] n2197;
  wire [81:0] n2198;
  wire [81:0] n2199;
  wire [81:0] n2200;
  wire [81:0] n2201;
  wire [81:0] n2202;
  wire [81:0] n2203;
  wire [81:0] n2204;
  wire [81:0] n2205;
  wire [81:0] n2206;
  wire [81:0] n2207;
  wire [81:0] n2208;
  wire [81:0] n2209;
  wire [81:0] n2210;
  wire [81:0] n2211;
  wire [81:0] n2212;
  wire [81:0] n2213;
  wire [81:0] n2214;
  wire [4:0] n2217;
  wire n2219;
  wire n2220;
  wire n2222;
  wire [7:0] n2223;
  wire [72:0] n2224;
  wire [4:0] n2227;
  wire n2229;
  wire n2230;
  wire n2232;
  wire [7:0] n2233;
  wire [72:0] n2234;
  localparam [33:0] n2238 = 34'b0000000000000000000000000000000000;
  wire [31:0] n2239;
  wire [31:0] n2240;
  wire [31:0] n2241;
  localparam [33:0] n2242 = 34'b0000000000000000000000000000000000;
  wire [1:0] n2243;
  wire [33:0] n2244;
  wire n2245;
  wire n2246;
  wire n2247;
  wire n2248;
  wire [33:0] n2249;
  wire n2250;
  wire n2251;
  wire n2252;
  wire [33:0] n2253;
  wire [31:0] n2254;
  wire [31:0] n2255;
  wire [31:0] n2256;
  wire [33:0] n2257;
  wire n2258;
  wire n2259;
  wire n2260;
  wire [33:0] n2261;
  wire n2262;
  wire n2263;
  wire n2264;
  wire [33:0] n2265;
  wire [2623:0] n2268;
  wire [1087:0] n2269;
  assign \main_rsp_o[ack]  = n1779; //(module output)
  assign \main_rsp_o[err]  = n1780; //(module output)
  assign \main_rsp_o[data]  = n1781; //(module output)
  assign \dev_00_req_o[meta]  = n1783; //(module output)
  assign \dev_00_req_o[addr]  = n1784; //(module output)
  assign \dev_00_req_o[data]  = n1785; //(module output)
  assign \dev_00_req_o[ben]  = n1786; //(module output)
  assign \dev_00_req_o[stb]  = n1787; //(module output)
  assign \dev_00_req_o[rw]  = n1788; //(module output)
  assign \dev_00_req_o[amo]  = n1789; //(module output)
  assign \dev_00_req_o[amoop]  = n1790; //(module output)
  assign \dev_00_req_o[burst]  = n1791; //(module output)
  assign \dev_00_req_o[lock]  = n1792; //(module output)
  assign \dev_01_req_o[meta]  = n1795; //(module output)
  assign \dev_01_req_o[addr]  = n1796; //(module output)
  assign \dev_01_req_o[data]  = n1797; //(module output)
  assign \dev_01_req_o[ben]  = n1798; //(module output)
  assign \dev_01_req_o[stb]  = n1799; //(module output)
  assign \dev_01_req_o[rw]  = n1800; //(module output)
  assign \dev_01_req_o[amo]  = n1801; //(module output)
  assign \dev_01_req_o[amoop]  = n1802; //(module output)
  assign \dev_01_req_o[burst]  = n1803; //(module output)
  assign \dev_01_req_o[lock]  = n1804; //(module output)
  assign \dev_02_req_o[meta]  = n1807; //(module output)
  assign \dev_02_req_o[addr]  = n1808; //(module output)
  assign \dev_02_req_o[data]  = n1809; //(module output)
  assign \dev_02_req_o[ben]  = n1810; //(module output)
  assign \dev_02_req_o[stb]  = n1811; //(module output)
  assign \dev_02_req_o[rw]  = n1812; //(module output)
  assign \dev_02_req_o[amo]  = n1813; //(module output)
  assign \dev_02_req_o[amoop]  = n1814; //(module output)
  assign \dev_02_req_o[burst]  = n1815; //(module output)
  assign \dev_02_req_o[lock]  = n1816; //(module output)
  assign \dev_03_req_o[meta]  = n1819; //(module output)
  assign \dev_03_req_o[addr]  = n1820; //(module output)
  assign \dev_03_req_o[data]  = n1821; //(module output)
  assign \dev_03_req_o[ben]  = n1822; //(module output)
  assign \dev_03_req_o[stb]  = n1823; //(module output)
  assign \dev_03_req_o[rw]  = n1824; //(module output)
  assign \dev_03_req_o[amo]  = n1825; //(module output)
  assign \dev_03_req_o[amoop]  = n1826; //(module output)
  assign \dev_03_req_o[burst]  = n1827; //(module output)
  assign \dev_03_req_o[lock]  = n1828; //(module output)
  assign \dev_04_req_o[meta]  = n1831; //(module output)
  assign \dev_04_req_o[addr]  = n1832; //(module output)
  assign \dev_04_req_o[data]  = n1833; //(module output)
  assign \dev_04_req_o[ben]  = n1834; //(module output)
  assign \dev_04_req_o[stb]  = n1835; //(module output)
  assign \dev_04_req_o[rw]  = n1836; //(module output)
  assign \dev_04_req_o[amo]  = n1837; //(module output)
  assign \dev_04_req_o[amoop]  = n1838; //(module output)
  assign \dev_04_req_o[burst]  = n1839; //(module output)
  assign \dev_04_req_o[lock]  = n1840; //(module output)
  assign \dev_05_req_o[meta]  = n1843; //(module output)
  assign \dev_05_req_o[addr]  = n1844; //(module output)
  assign \dev_05_req_o[data]  = n1845; //(module output)
  assign \dev_05_req_o[ben]  = n1846; //(module output)
  assign \dev_05_req_o[stb]  = n1847; //(module output)
  assign \dev_05_req_o[rw]  = n1848; //(module output)
  assign \dev_05_req_o[amo]  = n1849; //(module output)
  assign \dev_05_req_o[amoop]  = n1850; //(module output)
  assign \dev_05_req_o[burst]  = n1851; //(module output)
  assign \dev_05_req_o[lock]  = n1852; //(module output)
  assign \dev_06_req_o[meta]  = n1855; //(module output)
  assign \dev_06_req_o[addr]  = n1856; //(module output)
  assign \dev_06_req_o[data]  = n1857; //(module output)
  assign \dev_06_req_o[ben]  = n1858; //(module output)
  assign \dev_06_req_o[stb]  = n1859; //(module output)
  assign \dev_06_req_o[rw]  = n1860; //(module output)
  assign \dev_06_req_o[amo]  = n1861; //(module output)
  assign \dev_06_req_o[amoop]  = n1862; //(module output)
  assign \dev_06_req_o[burst]  = n1863; //(module output)
  assign \dev_06_req_o[lock]  = n1864; //(module output)
  assign \dev_07_req_o[meta]  = n1867; //(module output)
  assign \dev_07_req_o[addr]  = n1868; //(module output)
  assign \dev_07_req_o[data]  = n1869; //(module output)
  assign \dev_07_req_o[ben]  = n1870; //(module output)
  assign \dev_07_req_o[stb]  = n1871; //(module output)
  assign \dev_07_req_o[rw]  = n1872; //(module output)
  assign \dev_07_req_o[amo]  = n1873; //(module output)
  assign \dev_07_req_o[amoop]  = n1874; //(module output)
  assign \dev_07_req_o[burst]  = n1875; //(module output)
  assign \dev_07_req_o[lock]  = n1876; //(module output)
  assign \dev_08_req_o[meta]  = n1879; //(module output)
  assign \dev_08_req_o[addr]  = n1880; //(module output)
  assign \dev_08_req_o[data]  = n1881; //(module output)
  assign \dev_08_req_o[ben]  = n1882; //(module output)
  assign \dev_08_req_o[stb]  = n1883; //(module output)
  assign \dev_08_req_o[rw]  = n1884; //(module output)
  assign \dev_08_req_o[amo]  = n1885; //(module output)
  assign \dev_08_req_o[amoop]  = n1886; //(module output)
  assign \dev_08_req_o[burst]  = n1887; //(module output)
  assign \dev_08_req_o[lock]  = n1888; //(module output)
  assign \dev_09_req_o[meta]  = n1891; //(module output)
  assign \dev_09_req_o[addr]  = n1892; //(module output)
  assign \dev_09_req_o[data]  = n1893; //(module output)
  assign \dev_09_req_o[ben]  = n1894; //(module output)
  assign \dev_09_req_o[stb]  = n1895; //(module output)
  assign \dev_09_req_o[rw]  = n1896; //(module output)
  assign \dev_09_req_o[amo]  = n1897; //(module output)
  assign \dev_09_req_o[amoop]  = n1898; //(module output)
  assign \dev_09_req_o[burst]  = n1899; //(module output)
  assign \dev_09_req_o[lock]  = n1900; //(module output)
  assign \dev_10_req_o[meta]  = n1903; //(module output)
  assign \dev_10_req_o[addr]  = n1904; //(module output)
  assign \dev_10_req_o[data]  = n1905; //(module output)
  assign \dev_10_req_o[ben]  = n1906; //(module output)
  assign \dev_10_req_o[stb]  = n1907; //(module output)
  assign \dev_10_req_o[rw]  = n1908; //(module output)
  assign \dev_10_req_o[amo]  = n1909; //(module output)
  assign \dev_10_req_o[amoop]  = n1910; //(module output)
  assign \dev_10_req_o[burst]  = n1911; //(module output)
  assign \dev_10_req_o[lock]  = n1912; //(module output)
  assign \dev_11_req_o[meta]  = n1915; //(module output)
  assign \dev_11_req_o[addr]  = n1916; //(module output)
  assign \dev_11_req_o[data]  = n1917; //(module output)
  assign \dev_11_req_o[ben]  = n1918; //(module output)
  assign \dev_11_req_o[stb]  = n1919; //(module output)
  assign \dev_11_req_o[rw]  = n1920; //(module output)
  assign \dev_11_req_o[amo]  = n1921; //(module output)
  assign \dev_11_req_o[amoop]  = n1922; //(module output)
  assign \dev_11_req_o[burst]  = n1923; //(module output)
  assign \dev_11_req_o[lock]  = n1924; //(module output)
  assign \dev_12_req_o[meta]  = n1927; //(module output)
  assign \dev_12_req_o[addr]  = n1928; //(module output)
  assign \dev_12_req_o[data]  = n1929; //(module output)
  assign \dev_12_req_o[ben]  = n1930; //(module output)
  assign \dev_12_req_o[stb]  = n1931; //(module output)
  assign \dev_12_req_o[rw]  = n1932; //(module output)
  assign \dev_12_req_o[amo]  = n1933; //(module output)
  assign \dev_12_req_o[amoop]  = n1934; //(module output)
  assign \dev_12_req_o[burst]  = n1935; //(module output)
  assign \dev_12_req_o[lock]  = n1936; //(module output)
  assign \dev_13_req_o[meta]  = n1939; //(module output)
  assign \dev_13_req_o[addr]  = n1940; //(module output)
  assign \dev_13_req_o[data]  = n1941; //(module output)
  assign \dev_13_req_o[ben]  = n1942; //(module output)
  assign \dev_13_req_o[stb]  = n1943; //(module output)
  assign \dev_13_req_o[rw]  = n1944; //(module output)
  assign \dev_13_req_o[amo]  = n1945; //(module output)
  assign \dev_13_req_o[amoop]  = n1946; //(module output)
  assign \dev_13_req_o[burst]  = n1947; //(module output)
  assign \dev_13_req_o[lock]  = n1948; //(module output)
  assign \dev_14_req_o[meta]  = n1951; //(module output)
  assign \dev_14_req_o[addr]  = n1952; //(module output)
  assign \dev_14_req_o[data]  = n1953; //(module output)
  assign \dev_14_req_o[ben]  = n1954; //(module output)
  assign \dev_14_req_o[stb]  = n1955; //(module output)
  assign \dev_14_req_o[rw]  = n1956; //(module output)
  assign \dev_14_req_o[amo]  = n1957; //(module output)
  assign \dev_14_req_o[amoop]  = n1958; //(module output)
  assign \dev_14_req_o[burst]  = n1959; //(module output)
  assign \dev_14_req_o[lock]  = n1960; //(module output)
  assign \dev_15_req_o[meta]  = n1963; //(module output)
  assign \dev_15_req_o[addr]  = n1964; //(module output)
  assign \dev_15_req_o[data]  = n1965; //(module output)
  assign \dev_15_req_o[ben]  = n1966; //(module output)
  assign \dev_15_req_o[stb]  = n1967; //(module output)
  assign \dev_15_req_o[rw]  = n1968; //(module output)
  assign \dev_15_req_o[amo]  = n1969; //(module output)
  assign \dev_15_req_o[amoop]  = n1970; //(module output)
  assign \dev_15_req_o[burst]  = n1971; //(module output)
  assign \dev_15_req_o[lock]  = n1972; //(module output)
  assign \dev_16_req_o[meta]  = n1975; //(module output)
  assign \dev_16_req_o[addr]  = n1976; //(module output)
  assign \dev_16_req_o[data]  = n1977; //(module output)
  assign \dev_16_req_o[ben]  = n1978; //(module output)
  assign \dev_16_req_o[stb]  = n1979; //(module output)
  assign \dev_16_req_o[rw]  = n1980; //(module output)
  assign \dev_16_req_o[amo]  = n1981; //(module output)
  assign \dev_16_req_o[amoop]  = n1982; //(module output)
  assign \dev_16_req_o[burst]  = n1983; //(module output)
  assign \dev_16_req_o[lock]  = n1984; //(module output)
  assign \dev_17_req_o[meta]  = n1987; //(module output)
  assign \dev_17_req_o[addr]  = n1988; //(module output)
  assign \dev_17_req_o[data]  = n1989; //(module output)
  assign \dev_17_req_o[ben]  = n1990; //(module output)
  assign \dev_17_req_o[stb]  = n1991; //(module output)
  assign \dev_17_req_o[rw]  = n1992; //(module output)
  assign \dev_17_req_o[amo]  = n1993; //(module output)
  assign \dev_17_req_o[amoop]  = n1994; //(module output)
  assign \dev_17_req_o[burst]  = n1995; //(module output)
  assign \dev_17_req_o[lock]  = n1996; //(module output)
  assign \dev_18_req_o[meta]  = n1999; //(module output)
  assign \dev_18_req_o[addr]  = n2000; //(module output)
  assign \dev_18_req_o[data]  = n2001; //(module output)
  assign \dev_18_req_o[ben]  = n2002; //(module output)
  assign \dev_18_req_o[stb]  = n2003; //(module output)
  assign \dev_18_req_o[rw]  = n2004; //(module output)
  assign \dev_18_req_o[amo]  = n2005; //(module output)
  assign \dev_18_req_o[amoop]  = n2006; //(module output)
  assign \dev_18_req_o[burst]  = n2007; //(module output)
  assign \dev_18_req_o[lock]  = n2008; //(module output)
  assign \dev_19_req_o[meta]  = n2011; //(module output)
  assign \dev_19_req_o[addr]  = n2012; //(module output)
  assign \dev_19_req_o[data]  = n2013; //(module output)
  assign \dev_19_req_o[ben]  = n2014; //(module output)
  assign \dev_19_req_o[stb]  = n2015; //(module output)
  assign \dev_19_req_o[rw]  = n2016; //(module output)
  assign \dev_19_req_o[amo]  = n2017; //(module output)
  assign \dev_19_req_o[amoop]  = n2018; //(module output)
  assign \dev_19_req_o[burst]  = n2019; //(module output)
  assign \dev_19_req_o[lock]  = n2020; //(module output)
  assign \dev_20_req_o[meta]  = n2023; //(module output)
  assign \dev_20_req_o[addr]  = n2024; //(module output)
  assign \dev_20_req_o[data]  = n2025; //(module output)
  assign \dev_20_req_o[ben]  = n2026; //(module output)
  assign \dev_20_req_o[stb]  = n2027; //(module output)
  assign \dev_20_req_o[rw]  = n2028; //(module output)
  assign \dev_20_req_o[amo]  = n2029; //(module output)
  assign \dev_20_req_o[amoop]  = n2030; //(module output)
  assign \dev_20_req_o[burst]  = n2031; //(module output)
  assign \dev_20_req_o[lock]  = n2032; //(module output)
  assign \dev_21_req_o[meta]  = n2035; //(module output)
  assign \dev_21_req_o[addr]  = n2036; //(module output)
  assign \dev_21_req_o[data]  = n2037; //(module output)
  assign \dev_21_req_o[ben]  = n2038; //(module output)
  assign \dev_21_req_o[stb]  = n2039; //(module output)
  assign \dev_21_req_o[rw]  = n2040; //(module output)
  assign \dev_21_req_o[amo]  = n2041; //(module output)
  assign \dev_21_req_o[amoop]  = n2042; //(module output)
  assign \dev_21_req_o[burst]  = n2043; //(module output)
  assign \dev_21_req_o[lock]  = n2044; //(module output)
  assign \dev_22_req_o[meta]  = n2047; //(module output)
  assign \dev_22_req_o[addr]  = n2048; //(module output)
  assign \dev_22_req_o[data]  = n2049; //(module output)
  assign \dev_22_req_o[ben]  = n2050; //(module output)
  assign \dev_22_req_o[stb]  = n2051; //(module output)
  assign \dev_22_req_o[rw]  = n2052; //(module output)
  assign \dev_22_req_o[amo]  = n2053; //(module output)
  assign \dev_22_req_o[amoop]  = n2054; //(module output)
  assign \dev_22_req_o[burst]  = n2055; //(module output)
  assign \dev_22_req_o[lock]  = n2056; //(module output)
  assign \dev_23_req_o[meta]  = n2059; //(module output)
  assign \dev_23_req_o[addr]  = n2060; //(module output)
  assign \dev_23_req_o[data]  = n2061; //(module output)
  assign \dev_23_req_o[ben]  = n2062; //(module output)
  assign \dev_23_req_o[stb]  = n2063; //(module output)
  assign \dev_23_req_o[rw]  = n2064; //(module output)
  assign \dev_23_req_o[amo]  = n2065; //(module output)
  assign \dev_23_req_o[amoop]  = n2066; //(module output)
  assign \dev_23_req_o[burst]  = n2067; //(module output)
  assign \dev_23_req_o[lock]  = n2068; //(module output)
  assign \dev_24_req_o[meta]  = n2071; //(module output)
  assign \dev_24_req_o[addr]  = n2072; //(module output)
  assign \dev_24_req_o[data]  = n2073; //(module output)
  assign \dev_24_req_o[ben]  = n2074; //(module output)
  assign \dev_24_req_o[stb]  = n2075; //(module output)
  assign \dev_24_req_o[rw]  = n2076; //(module output)
  assign \dev_24_req_o[amo]  = n2077; //(module output)
  assign \dev_24_req_o[amoop]  = n2078; //(module output)
  assign \dev_24_req_o[burst]  = n2079; //(module output)
  assign \dev_24_req_o[lock]  = n2080; //(module output)
  assign \dev_25_req_o[meta]  = n2083; //(module output)
  assign \dev_25_req_o[addr]  = n2084; //(module output)
  assign \dev_25_req_o[data]  = n2085; //(module output)
  assign \dev_25_req_o[ben]  = n2086; //(module output)
  assign \dev_25_req_o[stb]  = n2087; //(module output)
  assign \dev_25_req_o[rw]  = n2088; //(module output)
  assign \dev_25_req_o[amo]  = n2089; //(module output)
  assign \dev_25_req_o[amoop]  = n2090; //(module output)
  assign \dev_25_req_o[burst]  = n2091; //(module output)
  assign \dev_25_req_o[lock]  = n2092; //(module output)
  assign \dev_26_req_o[meta]  = n2095; //(module output)
  assign \dev_26_req_o[addr]  = n2096; //(module output)
  assign \dev_26_req_o[data]  = n2097; //(module output)
  assign \dev_26_req_o[ben]  = n2098; //(module output)
  assign \dev_26_req_o[stb]  = n2099; //(module output)
  assign \dev_26_req_o[rw]  = n2100; //(module output)
  assign \dev_26_req_o[amo]  = n2101; //(module output)
  assign \dev_26_req_o[amoop]  = n2102; //(module output)
  assign \dev_26_req_o[burst]  = n2103; //(module output)
  assign \dev_26_req_o[lock]  = n2104; //(module output)
  assign \dev_27_req_o[meta]  = n2107; //(module output)
  assign \dev_27_req_o[addr]  = n2108; //(module output)
  assign \dev_27_req_o[data]  = n2109; //(module output)
  assign \dev_27_req_o[ben]  = n2110; //(module output)
  assign \dev_27_req_o[stb]  = n2111; //(module output)
  assign \dev_27_req_o[rw]  = n2112; //(module output)
  assign \dev_27_req_o[amo]  = n2113; //(module output)
  assign \dev_27_req_o[amoop]  = n2114; //(module output)
  assign \dev_27_req_o[burst]  = n2115; //(module output)
  assign \dev_27_req_o[lock]  = n2116; //(module output)
  assign \dev_28_req_o[meta]  = n2119; //(module output)
  assign \dev_28_req_o[addr]  = n2120; //(module output)
  assign \dev_28_req_o[data]  = n2121; //(module output)
  assign \dev_28_req_o[ben]  = n2122; //(module output)
  assign \dev_28_req_o[stb]  = n2123; //(module output)
  assign \dev_28_req_o[rw]  = n2124; //(module output)
  assign \dev_28_req_o[amo]  = n2125; //(module output)
  assign \dev_28_req_o[amoop]  = n2126; //(module output)
  assign \dev_28_req_o[burst]  = n2127; //(module output)
  assign \dev_28_req_o[lock]  = n2128; //(module output)
  assign \dev_29_req_o[meta]  = n2131; //(module output)
  assign \dev_29_req_o[addr]  = n2132; //(module output)
  assign \dev_29_req_o[data]  = n2133; //(module output)
  assign \dev_29_req_o[ben]  = n2134; //(module output)
  assign \dev_29_req_o[stb]  = n2135; //(module output)
  assign \dev_29_req_o[rw]  = n2136; //(module output)
  assign \dev_29_req_o[amo]  = n2137; //(module output)
  assign \dev_29_req_o[amoop]  = n2138; //(module output)
  assign \dev_29_req_o[burst]  = n2139; //(module output)
  assign \dev_29_req_o[lock]  = n2140; //(module output)
  assign \dev_30_req_o[meta]  = n2143; //(module output)
  assign \dev_30_req_o[addr]  = n2144; //(module output)
  assign \dev_30_req_o[data]  = n2145; //(module output)
  assign \dev_30_req_o[ben]  = n2146; //(module output)
  assign \dev_30_req_o[stb]  = n2147; //(module output)
  assign \dev_30_req_o[rw]  = n2148; //(module output)
  assign \dev_30_req_o[amo]  = n2149; //(module output)
  assign \dev_30_req_o[amoop]  = n2150; //(module output)
  assign \dev_30_req_o[burst]  = n2151; //(module output)
  assign \dev_30_req_o[lock]  = n2152; //(module output)
  assign \dev_31_req_o[meta]  = n2155; //(module output)
  assign \dev_31_req_o[addr]  = n2156; //(module output)
  assign \dev_31_req_o[data]  = n2157; //(module output)
  assign \dev_31_req_o[ben]  = n2158; //(module output)
  assign \dev_31_req_o[stb]  = n2159; //(module output)
  assign \dev_31_req_o[rw]  = n2160; //(module output)
  assign \dev_31_req_o[amo]  = n2161; //(module output)
  assign \dev_31_req_o[amoop]  = n2162; //(module output)
  assign \dev_31_req_o[burst]  = n2163; //(module output)
  assign \dev_31_req_o[lock]  = n2164; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1777 = {\main_req_i[lock] , \main_req_i[burst] , \main_req_i[amoop] , \main_req_i[amo] , \main_req_i[rw] , \main_req_i[stb] , \main_req_i[ben] , \main_req_i[data] , \main_req_i[addr] , \main_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1779 = n2176[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1780 = n2176[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1781 = n2176[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1783 = n2183[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1784 = n2183[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1785 = n2183[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1786 = n2183[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1787 = n2183[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1788 = n2183[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1789 = n2183[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1790 = n2183[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1791 = n2183[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1792 = n2183[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1793 = {\dev_00_rsp_i[data] , \dev_00_rsp_i[err] , \dev_00_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1795 = n2184[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1796 = n2184[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1797 = n2184[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1798 = n2184[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1799 = n2184[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1800 = n2184[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1801 = n2184[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1802 = n2184[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1803 = n2184[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1804 = n2184[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1805 = {\dev_01_rsp_i[data] , \dev_01_rsp_i[err] , \dev_01_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1807 = n2185[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1808 = n2185[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1809 = n2185[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1810 = n2185[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1811 = n2185[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1812 = n2185[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1813 = n2185[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1814 = n2185[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1815 = n2185[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1816 = n2185[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1817 = {\dev_02_rsp_i[data] , \dev_02_rsp_i[err] , \dev_02_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1819 = n2186[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1820 = n2186[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1821 = n2186[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1822 = n2186[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1823 = n2186[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1824 = n2186[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1825 = n2186[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1826 = n2186[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1827 = n2186[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1828 = n2186[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1829 = {\dev_03_rsp_i[data] , \dev_03_rsp_i[err] , \dev_03_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1831 = n2187[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1832 = n2187[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1833 = n2187[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1834 = n2187[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1835 = n2187[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1836 = n2187[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1837 = n2187[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1838 = n2187[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1839 = n2187[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1840 = n2187[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1841 = {\dev_04_rsp_i[data] , \dev_04_rsp_i[err] , \dev_04_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1843 = n2188[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1844 = n2188[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1845 = n2188[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1846 = n2188[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1847 = n2188[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1848 = n2188[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1849 = n2188[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1850 = n2188[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1851 = n2188[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1852 = n2188[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1853 = {\dev_05_rsp_i[data] , \dev_05_rsp_i[err] , \dev_05_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1855 = n2189[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1856 = n2189[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1857 = n2189[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1858 = n2189[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1859 = n2189[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1860 = n2189[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1861 = n2189[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1862 = n2189[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1863 = n2189[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1864 = n2189[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1865 = {\dev_06_rsp_i[data] , \dev_06_rsp_i[err] , \dev_06_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1867 = n2190[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1868 = n2190[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1869 = n2190[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1870 = n2190[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1871 = n2190[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1872 = n2190[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1873 = n2190[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1874 = n2190[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1875 = n2190[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1876 = n2190[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1877 = {\dev_07_rsp_i[data] , \dev_07_rsp_i[err] , \dev_07_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1879 = n2191[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1880 = n2191[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1881 = n2191[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1882 = n2191[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1883 = n2191[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1884 = n2191[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1885 = n2191[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1886 = n2191[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1887 = n2191[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1888 = n2191[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1889 = {\dev_08_rsp_i[data] , \dev_08_rsp_i[err] , \dev_08_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1891 = n2192[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1892 = n2192[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1893 = n2192[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1894 = n2192[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1895 = n2192[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1896 = n2192[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1897 = n2192[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1898 = n2192[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1899 = n2192[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1900 = n2192[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1901 = {\dev_09_rsp_i[data] , \dev_09_rsp_i[err] , \dev_09_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1903 = n2193[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1904 = n2193[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1905 = n2193[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1906 = n2193[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1907 = n2193[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1908 = n2193[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1909 = n2193[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1910 = n2193[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1911 = n2193[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1912 = n2193[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1913 = {\dev_10_rsp_i[data] , \dev_10_rsp_i[err] , \dev_10_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1915 = n2194[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1916 = n2194[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1917 = n2194[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1918 = n2194[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1919 = n2194[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1920 = n2194[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1921 = n2194[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1922 = n2194[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1923 = n2194[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1924 = n2194[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1925 = {\dev_11_rsp_i[data] , \dev_11_rsp_i[err] , \dev_11_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1927 = n2195[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1928 = n2195[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1929 = n2195[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1930 = n2195[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1931 = n2195[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1932 = n2195[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1933 = n2195[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1934 = n2195[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1935 = n2195[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1936 = n2195[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1937 = {\dev_12_rsp_i[data] , \dev_12_rsp_i[err] , \dev_12_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1939 = n2196[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1940 = n2196[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1941 = n2196[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1942 = n2196[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1943 = n2196[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1944 = n2196[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1945 = n2196[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1946 = n2196[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1947 = n2196[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1948 = n2196[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1949 = {\dev_13_rsp_i[data] , \dev_13_rsp_i[err] , \dev_13_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1951 = n2197[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1952 = n2197[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1953 = n2197[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1954 = n2197[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1955 = n2197[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1956 = n2197[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1957 = n2197[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1958 = n2197[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1959 = n2197[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1960 = n2197[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1961 = {\dev_14_rsp_i[data] , \dev_14_rsp_i[err] , \dev_14_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1963 = n2198[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1964 = n2198[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1965 = n2198[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1966 = n2198[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1967 = n2198[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1968 = n2198[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1969 = n2198[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1970 = n2198[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1971 = n2198[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1972 = n2198[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1973 = {\dev_15_rsp_i[data] , \dev_15_rsp_i[err] , \dev_15_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1975 = n2199[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1976 = n2199[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1977 = n2199[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1978 = n2199[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1979 = n2199[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1980 = n2199[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1981 = n2199[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1982 = n2199[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1983 = n2199[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1984 = n2199[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1985 = {\dev_16_rsp_i[data] , \dev_16_rsp_i[err] , \dev_16_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1987 = n2200[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1988 = n2200[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1989 = n2200[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1990 = n2200[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1991 = n2200[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1992 = n2200[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1993 = n2200[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1994 = n2200[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1995 = n2200[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1996 = n2200[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1997 = {\dev_17_rsp_i[data] , \dev_17_rsp_i[err] , \dev_17_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1999 = n2201[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2000 = n2201[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2001 = n2201[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2002 = n2201[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2003 = n2201[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2004 = n2201[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2005 = n2201[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2006 = n2201[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2007 = n2201[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2008 = n2201[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2009 = {\dev_18_rsp_i[data] , \dev_18_rsp_i[err] , \dev_18_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2011 = n2202[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2012 = n2202[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2013 = n2202[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2014 = n2202[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2015 = n2202[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2016 = n2202[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2017 = n2202[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2018 = n2202[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2019 = n2202[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2020 = n2202[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2021 = {\dev_19_rsp_i[data] , \dev_19_rsp_i[err] , \dev_19_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2023 = n2203[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2024 = n2203[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2025 = n2203[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2026 = n2203[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2027 = n2203[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2028 = n2203[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2029 = n2203[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2030 = n2203[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2031 = n2203[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2032 = n2203[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2033 = {\dev_20_rsp_i[data] , \dev_20_rsp_i[err] , \dev_20_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2035 = n2204[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2036 = n2204[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2037 = n2204[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2038 = n2204[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2039 = n2204[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2040 = n2204[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2041 = n2204[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2042 = n2204[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2043 = n2204[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2044 = n2204[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2045 = {\dev_21_rsp_i[data] , \dev_21_rsp_i[err] , \dev_21_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2047 = n2205[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2048 = n2205[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2049 = n2205[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2050 = n2205[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2051 = n2205[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2052 = n2205[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2053 = n2205[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2054 = n2205[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2055 = n2205[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2056 = n2205[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2057 = {\dev_22_rsp_i[data] , \dev_22_rsp_i[err] , \dev_22_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2059 = n2206[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2060 = n2206[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2061 = n2206[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2062 = n2206[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2063 = n2206[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2064 = n2206[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2065 = n2206[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2066 = n2206[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2067 = n2206[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2068 = n2206[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2069 = {\dev_23_rsp_i[data] , \dev_23_rsp_i[err] , \dev_23_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2071 = n2207[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2072 = n2207[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2073 = n2207[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2074 = n2207[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2075 = n2207[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2076 = n2207[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2077 = n2207[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2078 = n2207[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2079 = n2207[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2080 = n2207[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2081 = {\dev_24_rsp_i[data] , \dev_24_rsp_i[err] , \dev_24_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2083 = n2208[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2084 = n2208[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2085 = n2208[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2086 = n2208[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2087 = n2208[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2088 = n2208[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2089 = n2208[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2090 = n2208[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2091 = n2208[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2092 = n2208[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2093 = {\dev_25_rsp_i[data] , \dev_25_rsp_i[err] , \dev_25_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2095 = n2209[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2096 = n2209[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2097 = n2209[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2098 = n2209[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2099 = n2209[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2100 = n2209[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2101 = n2209[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2102 = n2209[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2103 = n2209[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2104 = n2209[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2105 = {\dev_26_rsp_i[data] , \dev_26_rsp_i[err] , \dev_26_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2107 = n2210[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2108 = n2210[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2109 = n2210[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2110 = n2210[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2111 = n2210[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2112 = n2210[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2113 = n2210[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2114 = n2210[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2115 = n2210[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2116 = n2210[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2117 = {\dev_27_rsp_i[data] , \dev_27_rsp_i[err] , \dev_27_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2119 = n2211[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2120 = n2211[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2121 = n2211[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2122 = n2211[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2123 = n2211[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2124 = n2211[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2125 = n2211[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2126 = n2211[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2127 = n2211[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2128 = n2211[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2129 = {\dev_28_rsp_i[data] , \dev_28_rsp_i[err] , \dev_28_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2131 = n2212[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2132 = n2212[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2133 = n2212[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2134 = n2212[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2135 = n2212[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2136 = n2212[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2137 = n2212[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2138 = n2212[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2139 = n2212[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2140 = n2212[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2141 = {\dev_29_rsp_i[data] , \dev_29_rsp_i[err] , \dev_29_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2143 = n2213[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2144 = n2213[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2145 = n2213[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2146 = n2213[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2147 = n2213[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2148 = n2213[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2149 = n2213[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2150 = n2213[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2151 = n2213[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2152 = n2213[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2153 = {\dev_30_rsp_i[data] , \dev_30_rsp_i[err] , \dev_30_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2155 = n2214[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2156 = n2214[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2157 = n2214[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2158 = n2214[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2159 = n2214[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2160 = n2214[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2161 = n2214[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2162 = n2214[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2163 = n2214[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2164 = n2214[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2165 = {\dev_31_rsp_i[data] , \dev_31_rsp_i[err] , \dev_31_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign dev_req = n2268; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:634:10 */
  assign dev_rsp = n2269; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:637:10 */
  assign main_req = n2178; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:638:10 */
  assign main_rsp = n2265; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  neorv32_bus_reg_Bneorv32_bus_reg_rtl_Lneorv32_9159cb8bcee7fcb95582f140960cdae72788d326 neorv32_bus_reg_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\host_req_i[meta] (n2166),
    .\host_req_i[addr] (n2167),
    .\host_req_i[data] (n2168),
    .\host_req_i[ben] (n2169),
    .\host_req_i[stb] (n2170),
    .\host_req_i[rw] (n2171),
    .\host_req_i[amo] (n2172),
    .\host_req_i[amoop] (n2173),
    .\host_req_i[burst] (n2174),
    .\host_req_i[lock] (n2175),
    .\device_rsp_i[ack] (n2180),
    .\device_rsp_i[err] (n2181),
    .\device_rsp_i[data] (n2182),
    .\host_rsp_o[ack] (\neorv32_bus_reg_inst.host_rsp_o[ack] ),
    .\host_rsp_o[err] (\neorv32_bus_reg_inst.host_rsp_o[err] ),
    .\host_rsp_o[data] (\neorv32_bus_reg_inst.host_rsp_o[data] ),
    .\device_req_o[meta] (\neorv32_bus_reg_inst.device_req_o[meta] ),
    .\device_req_o[addr] (\neorv32_bus_reg_inst.device_req_o[addr] ),
    .\device_req_o[data] (\neorv32_bus_reg_inst.device_req_o[data] ),
    .\device_req_o[ben] (\neorv32_bus_reg_inst.device_req_o[ben] ),
    .\device_req_o[stb] (\neorv32_bus_reg_inst.device_req_o[stb] ),
    .\device_req_o[rw] (\neorv32_bus_reg_inst.device_req_o[rw] ),
    .\device_req_o[amo] (\neorv32_bus_reg_inst.device_req_o[amo] ),
    .\device_req_o[amoop] (\neorv32_bus_reg_inst.device_req_o[amoop] ),
    .\device_req_o[burst] (\neorv32_bus_reg_inst.device_req_o[burst] ),
    .\device_req_o[lock] (\neorv32_bus_reg_inst.device_req_o[lock] ));
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2166 = n1777[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2167 = n1777[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2168 = n1777[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2169 = n1777[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2170 = n1777[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2171 = n1777[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2172 = n1777[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2173 = n1777[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2174 = n1777[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2175 = n1777[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2176 = {\neorv32_bus_reg_inst.host_rsp_o[data] , \neorv32_bus_reg_inst.host_rsp_o[err] , \neorv32_bus_reg_inst.host_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2178 = {\neorv32_bus_reg_inst.device_req_o[lock] , \neorv32_bus_reg_inst.device_req_o[burst] , \neorv32_bus_reg_inst.device_req_o[amoop] , \neorv32_bus_reg_inst.device_req_o[amo] , \neorv32_bus_reg_inst.device_req_o[rw] , \neorv32_bus_reg_inst.device_req_o[stb] , \neorv32_bus_reg_inst.device_req_o[ben] , \neorv32_bus_reg_inst.device_req_o[data] , \neorv32_bus_reg_inst.device_req_o[addr] , \neorv32_bus_reg_inst.device_req_o[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2180 = main_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2181 = main_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2182 = main_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:662:26 */
  assign n2183 = dev_req[2623:2542]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:663:26 */
  assign n2184 = dev_req[2541:2460]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:664:26 */
  assign n2185 = dev_req[2459:2378]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:665:26 */
  assign n2186 = dev_req[2377:2296]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:666:26 */
  assign n2187 = dev_req[2295:2214]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:667:26 */
  assign n2188 = dev_req[2213:2132]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:668:26 */
  assign n2189 = dev_req[2131:2050]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:669:26 */
  assign n2190 = dev_req[2049:1968]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:670:26 */
  assign n2191 = dev_req[1967:1886]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:671:26 */
  assign n2192 = dev_req[1885:1804]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:672:26 */
  assign n2193 = dev_req[1803:1722]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:673:26 */
  assign n2194 = dev_req[1721:1640]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:674:26 */
  assign n2195 = dev_req[1639:1558]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:675:26 */
  assign n2196 = dev_req[1557:1476]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:676:26 */
  assign n2197 = dev_req[1475:1394]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:677:26 */
  assign n2198 = dev_req[1393:1312]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:678:26 */
  assign n2199 = dev_req[1311:1230]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:679:26 */
  assign n2200 = dev_req[1229:1148]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:680:26 */
  assign n2201 = dev_req[1147:1066]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:681:26 */
  assign n2202 = dev_req[1065:984]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:682:26 */
  assign n2203 = dev_req[983:902]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:683:26 */
  assign n2204 = dev_req[901:820]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:684:26 */
  assign n2205 = dev_req[819:738]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:685:26 */
  assign n2206 = dev_req[737:656]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:686:26 */
  assign n2207 = dev_req[655:574]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:687:26 */
  assign n2208 = dev_req[573:492]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:688:26 */
  assign n2209 = dev_req[491:410]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:689:26 */
  assign n2210 = dev_req[409:328]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:690:26 */
  assign n2211 = dev_req[327:246]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:691:26 */
  assign n2212 = dev_req[245:164]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:692:26 */
  assign n2213 = dev_req[163:82]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:693:26 */
  assign n2214 = dev_req[81:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:26 */
  assign n2217 = main_req[25:21]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:55 */
  assign n2219 = n2217 == 5'b10101;
  /*# ../../rtl/core/neorv32_bus.vhd:706:38 */
  assign n2220 = main_req[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:9 */
  assign n2222 = n2219 ? n2220 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2223 = main_req[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2224 = main_req[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:26 */
  assign n2227 = main_req[25:21]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:55 */
  assign n2229 = n2227 == 5'b11110;
  /*# ../../rtl/core/neorv32_bus.vhd:706:38 */
  assign n2230 = main_req[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:9 */
  assign n2232 = n2229 ? n2230 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2233 = main_req[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2234 = main_req[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:29 */
  assign n2239 = n2238[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:48 */
  assign n2240 = dev_rsp[373:342]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:34 */
  assign n2241 = n2239 | n2240;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2243 = n2242[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2244 = {n2241, n2243};
  /*# ../../rtl/core/neorv32_bus.vhd:729:29 */
  assign n2245 = n2244[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:48 */
  assign n2246 = dev_rsp[340]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:34 */
  assign n2247 = n2245 | n2246;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2248 = n2242[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2249 = {n2241, n2248, n2247};
  /*# ../../rtl/core/neorv32_bus.vhd:730:29 */
  assign n2250 = n2249[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:48 */
  assign n2251 = dev_rsp[341]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:34 */
  assign n2252 = n2250 | n2251;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2253 = {n2241, n2252, n2247};
  /*# ../../rtl/core/neorv32_bus.vhd:728:29 */
  assign n2254 = n2253[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:48 */
  assign n2255 = dev_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:34 */
  assign n2256 = n2254 | n2255;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2257 = {n2256, n2252, n2247};
  /*# ../../rtl/core/neorv32_bus.vhd:729:29 */
  assign n2258 = n2257[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:48 */
  assign n2259 = dev_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:34 */
  assign n2260 = n2258 | n2259;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2261 = {n2256, n2252, n2260};
  /*# ../../rtl/core/neorv32_bus.vhd:730:29 */
  assign n2262 = n2261[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:48 */
  assign n2263 = dev_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:34 */
  assign n2264 = n2262 | n2263;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2265 = {n2256, n2264, n2260};
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2268 = {82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n2223, n2222, n2224, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n2233, n2232, n2234, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_bus.vhd:634:10 */
  assign n2269 = {n1793, n1805, n1817, n1829, n1841, n1853, n1865, n1877, n1889, n1901, n1913, n1925, n1937, n1949, n1961, n1973, n1985, n1997, n2009, n2021, n2033, n2045, n2057, n2069, n2081, n2093, n2105, n2117, n2129, n2141, n2153, n2165};
endmodule

module neorv32_xbus_Bneorv32_xbus_rtl_Lneorv32_5ba93c9db0cff93f52b521d7420e43f6eda2784f
  (input  clk_i,
   input  rstn_i,
   input  bus_term_i,
   input  [4:0] \bus_req_i[meta] ,
   input  [31:0] \bus_req_i[addr] ,
   input  [31:0] \bus_req_i[data] ,
   input  [3:0] \bus_req_i[ben] ,
   input  \bus_req_i[stb] ,
   input  \bus_req_i[rw] ,
   input  \bus_req_i[amo] ,
   input  [3:0] \bus_req_i[amoop] ,
   input  \bus_req_i[burst] ,
   input  \bus_req_i[lock] ,
   output \bus_rsp_o[ack] ,
   output \bus_rsp_o[err] ,
   output [31:0] \bus_rsp_o[data] ,
   output [31:0] xbus_adr_o,
   input  [31:0] xbus_dat_i,
   output [31:0] xbus_dat_o,
   output [2:0] xbus_cti_o,
   output [2:0] xbus_tag_o,
   output xbus_we_o,
   output [3:0] xbus_sel_o,
   output xbus_stb_o,
   output xbus_cyc_o,
   input  xbus_ack_i,
   input  xbus_err_i);
  wire [81:0] n1688;
  wire n1690;
  wire n1691;
  wire [31:0] n1692;
  wire [81:0] bus_req;
  wire [33:0] bus_rsp;
  wire pending;
  wire locked;
  wire \reg_stage_inst.host_rsp_o[ack] ;
  wire \reg_stage_inst.host_rsp_o[err] ;
  wire [31:0] \reg_stage_inst.host_rsp_o[data] ;
  wire [4:0] \reg_stage_inst.device_req_o[meta] ;
  wire [31:0] \reg_stage_inst.device_req_o[addr] ;
  wire [31:0] \reg_stage_inst.device_req_o[data] ;
  wire [3:0] \reg_stage_inst.device_req_o[ben] ;
  wire \reg_stage_inst.device_req_o[stb] ;
  wire \reg_stage_inst.device_req_o[rw] ;
  wire \reg_stage_inst.device_req_o[amo] ;
  wire [3:0] \reg_stage_inst.device_req_o[amoop] ;
  wire \reg_stage_inst.device_req_o[burst] ;
  wire \reg_stage_inst.device_req_o[lock] ;
  wire [4:0] n1701;
  wire [31:0] n1702;
  wire [31:0] n1703;
  wire [3:0] n1704;
  wire n1705;
  wire n1706;
  wire n1707;
  wire [3:0] n1708;
  wire n1709;
  wire n1710;
  wire [33:0] n1711;
  wire [81:0] n1713;
  wire n1715;
  wire n1716;
  wire [31:0] n1717;
  wire n1719;
  wire n1721;
  wire n1722;
  wire n1723;
  wire n1724;
  wire n1725;
  wire n1726;
  wire n1727;
  wire n1728;
  wire n1730;
  wire n1731;
  wire n1732;
  wire n1733;
  wire n1735;
  wire n1736;
  wire n1737;
  wire [31:0] n1746;
  wire [31:0] n1747;
  wire n1748;
  wire [3:0] n1749;
  wire n1750;
  wire n1751;
  wire n1752;
  wire n1754;
  wire n1755;
  wire n1756;
  wire [2:0] n1757;
  wire n1759;
  wire n1760;
  wire n1761;
  wire [2:0] n1762;
  wire n1764;
  wire n1766;
  wire [31:0] n1767;
  wire n1769;
  wire n1770;
  wire n1771;
  wire [33:0] n1772;
  wire [2:0] n1773;
  reg n1774;
  wire n1775;
  reg n1776;
  assign \bus_rsp_o[ack]  = n1690; //(module output)
  assign \bus_rsp_o[err]  = n1691; //(module output)
  assign \bus_rsp_o[data]  = n1692; //(module output)
  assign xbus_adr_o = n1746; //(module output)
  assign xbus_dat_o = n1747; //(module output)
  assign xbus_cti_o = n1757; //(module output)
  assign xbus_tag_o = n1773; //(module output)
  assign xbus_we_o = n1748; //(module output)
  assign xbus_sel_o = n1749; //(module output)
  assign xbus_stb_o = n1750; //(module output)
  assign xbus_cyc_o = n1752; //(module output)
  /*# ../../rtl/core/neorv32_xbus.vhd:20:8 */
  assign n1688 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_xbus.vhd:20:8 */
  assign n1690 = n1711[0]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:20:8 */
  assign n1691 = n1711[1]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:20:8 */
  assign n1692 = n1711[33:2]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:46:10 */
  assign bus_req = n1713; // (signal)
  /*# ../../rtl/core/neorv32_xbus.vhd:47:10 */
  assign bus_rsp = n1772; // (signal)
  /*# ../../rtl/core/neorv32_xbus.vhd:48:10 */
  assign pending = n1774; // (signal)
  /*# ../../rtl/core/neorv32_xbus.vhd:48:19 */
  assign locked = n1776; // (signal)
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  neorv32_bus_reg_Bneorv32_bus_reg_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29 reg_stage_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\host_req_i[meta] (n1701),
    .\host_req_i[addr] (n1702),
    .\host_req_i[data] (n1703),
    .\host_req_i[ben] (n1704),
    .\host_req_i[stb] (n1705),
    .\host_req_i[rw] (n1706),
    .\host_req_i[amo] (n1707),
    .\host_req_i[amoop] (n1708),
    .\host_req_i[burst] (n1709),
    .\host_req_i[lock] (n1710),
    .\device_rsp_i[ack] (n1715),
    .\device_rsp_i[err] (n1716),
    .\device_rsp_i[data] (n1717),
    .\host_rsp_o[ack] (\reg_stage_inst.host_rsp_o[ack] ),
    .\host_rsp_o[err] (\reg_stage_inst.host_rsp_o[err] ),
    .\host_rsp_o[data] (\reg_stage_inst.host_rsp_o[data] ),
    .\device_req_o[meta] (\reg_stage_inst.device_req_o[meta] ),
    .\device_req_o[addr] (\reg_stage_inst.device_req_o[addr] ),
    .\device_req_o[data] (\reg_stage_inst.device_req_o[data] ),
    .\device_req_o[ben] (\reg_stage_inst.device_req_o[ben] ),
    .\device_req_o[stb] (\reg_stage_inst.device_req_o[stb] ),
    .\device_req_o[rw] (\reg_stage_inst.device_req_o[rw] ),
    .\device_req_o[amo] (\reg_stage_inst.device_req_o[amo] ),
    .\device_req_o[amoop] (\reg_stage_inst.device_req_o[amoop] ),
    .\device_req_o[burst] (\reg_stage_inst.device_req_o[burst] ),
    .\device_req_o[lock] (\reg_stage_inst.device_req_o[lock] ));
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1701 = n1688[4:0]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1702 = n1688[36:5]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1703 = n1688[68:37]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1704 = n1688[72:69]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1705 = n1688[73]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1706 = n1688[74]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1707 = n1688[75]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1708 = n1688[79:76]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1709 = n1688[80]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1710 = n1688[81]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1711 = {\reg_stage_inst.host_rsp_o[data] , \reg_stage_inst.host_rsp_o[err] , \reg_stage_inst.host_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1713 = {\reg_stage_inst.device_req_o[lock] , \reg_stage_inst.device_req_o[burst] , \reg_stage_inst.device_req_o[amoop] , \reg_stage_inst.device_req_o[amo] , \reg_stage_inst.device_req_o[rw] , \reg_stage_inst.device_req_o[stb] , \reg_stage_inst.device_req_o[ben] , \reg_stage_inst.device_req_o[data] , \reg_stage_inst.device_req_o[addr] , \reg_stage_inst.device_req_o[meta] };
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1715 = bus_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1716 = bus_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:54:3 */
  assign n1717 = bus_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:72:16 */
  assign n1719 = ~rstn_i;
  /*# ../../rtl/core/neorv32_xbus.vhd:76:19 */
  assign n1721 = ~pending;
  /*# ../../rtl/core/neorv32_xbus.vhd:77:28 */
  assign n1722 = bus_req[73]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:78:28 */
  assign n1723 = bus_req[73]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:78:44 */
  assign n1724 = bus_req[81]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:78:32 */
  assign n1725 = n1723 & n1724;
  /*# ../../rtl/core/neorv32_xbus.vhd:80:20 */
  assign n1726 = ~locked;
  /*# ../../rtl/core/neorv32_xbus.vhd:81:33 */
  assign n1727 = bus_term_i | xbus_err_i;
  /*# ../../rtl/core/neorv32_xbus.vhd:81:55 */
  assign n1728 = n1727 | xbus_ack_i;
  /*# ../../rtl/core/neorv32_xbus.vhd:81:11 */
  assign n1730 = n1728 ? 1'b0 : pending;
  /*# ../../rtl/core/neorv32_xbus.vhd:85:45 */
  assign n1731 = bus_req[81]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:85:50 */
  assign n1732 = ~n1731;
  /*# ../../rtl/core/neorv32_xbus.vhd:85:33 */
  assign n1733 = bus_term_i | n1732;
  /*# ../../rtl/core/neorv32_xbus.vhd:85:11 */
  assign n1735 = n1733 ? 1'b0 : pending;
  /*# ../../rtl/core/neorv32_xbus.vhd:80:9 */
  assign n1736 = n1726 ? n1730 : n1735;
  /*# ../../rtl/core/neorv32_xbus.vhd:76:7 */
  assign n1737 = n1721 ? n1722 : n1736;
  /*# ../../rtl/core/neorv32_xbus.vhd:95:25 */
  assign n1746 = bus_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:96:25 */
  assign n1747 = bus_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:97:25 */
  assign n1748 = bus_req[74]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:98:25 */
  assign n1749 = bus_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:99:25 */
  assign n1750 = bus_req[73]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:100:25 */
  assign n1751 = bus_req[73]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:100:29 */
  assign n1752 = n1751 | pending;
  /*# ../../rtl/core/neorv32_xbus.vhd:103:37 */
  assign n1754 = bus_req[81]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:103:62 */
  assign n1755 = bus_req[75]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:103:49 */
  assign n1756 = n1755 & n1754;
  /*# ../../rtl/core/neorv32_xbus.vhd:103:23 */
  assign n1757 = n1756 ? 3'b001 : n1762;
  /*# ../../rtl/core/neorv32_xbus.vhd:104:37 */
  assign n1759 = bus_req[81]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:104:62 */
  assign n1760 = bus_req[80]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:104:49 */
  assign n1761 = n1760 & n1759;
  /*# ../../rtl/core/neorv32_xbus.vhd:103:75 */
  assign n1762 = n1761 ? 3'b010 : 3'b000;
  /*# ../../rtl/core/neorv32_xbus.vhd:108:32 */
  assign n1764 = bus_req[0]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:110:32 */
  assign n1766 = bus_req[1]; // extract
  /*# ../../rtl/core/neorv32_xbus.vhd:113:30 */
  assign n1767 = pending ? xbus_dat_i : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_xbus.vhd:114:43 */
  assign n1769 = xbus_err_i | xbus_ack_i;
  /*# ../../rtl/core/neorv32_xbus.vhd:114:27 */
  assign n1770 = pending & n1769;
  /*# ../../rtl/core/neorv32_xbus.vhd:115:27 */
  assign n1771 = pending & xbus_err_i;
  /*# ../../rtl/core/neorv32_xbus.vhd:47:10 */
  assign n1772 = {n1767, n1771, n1770};
  /*# ../../rtl/core/neorv32_xbus.vhd:34:5 */
  assign n1773 = {n1764, 1'b0, n1766};
  /*# ../../rtl/core/neorv32_xbus.vhd:75:5 */
  always @(posedge clk_i or posedge n1719)
    if (n1719)
      n1774 <= 1'b0;
    else
      n1774 <= n1737;
  /*# ../../rtl/core/neorv32_xbus.vhd:75:5 */
  assign n1775 = n1721 ? n1725 : locked;
  /*# ../../rtl/core/neorv32_xbus.vhd:75:5 */
  always @(posedge clk_i or posedge n1719)
    if (n1719)
      n1776 <= 1'b0;
    else
      n1776 <= n1775;
endmodule

module neorv32_dmem_Bneorv32_dmem_rtl_Lneorv32_16384_5ba93c9db0cff93f52b521d7420e43f6eda2784f
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \bus_req_i[meta] ,
   input  [31:0] \bus_req_i[addr] ,
   input  [31:0] \bus_req_i[data] ,
   input  [3:0] \bus_req_i[ben] ,
   input  \bus_req_i[stb] ,
   input  \bus_req_i[rw] ,
   input  \bus_req_i[amo] ,
   input  [3:0] \bus_req_i[amoop] ,
   input  \bus_req_i[burst] ,
   input  \bus_req_i[lock] ,
   output \bus_rsp_o[ack] ,
   output \bus_rsp_o[err] ,
   output [31:0] \bus_rsp_o[data] );
  wire [81:0] n1645;
  wire n1647;
  wire n1648;
  wire [31:0] n1649;
  wire [31:0] rdata;
  wire wren;
  wire [1:0] rden;
  wire [3:0] ben;
  wire n1650;
  wire [31:0] n1651;
  wire [31:0] n1652;
  wire [31:0] dmem_ram_inst_n1653;
  wire [3:0] n1656;
  wire n1657;
  wire [3:0] n1658;
  wire n1661;
  wire n1663;
  wire n1664;
  wire n1665;
  wire n1666;
  wire n1667;
  wire n1668;
  wire n1669;
  wire n1670;
  wire [1:0] n1671;
  wire n1679;
  wire [31:0] n1680;
  wire n1683;
  wire n1684;
  wire [33:0] n1685;
  reg n1686;
  reg [1:0] n1687;
  assign \bus_rsp_o[ack]  = n1647; //(module output)
  assign \bus_rsp_o[err]  = n1648; //(module output)
  assign \bus_rsp_o[data]  = n1649; //(module output)
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1645 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1647 = n1685[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1648 = n1685[1]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1649 = n1685[33:2]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:55:10 */
  assign rdata = dmem_ram_inst_n1653; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:56:10 */
  assign wren = n1686; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:57:10 */
  assign rden = n1687; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:58:10 */
  assign ben = n1658; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:72:25 */
  assign n1650 = n1645[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:73:25 */
  assign n1651 = n1645[36:5]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:74:25 */
  assign n1652 = n1645[68:37]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:64:3 */
  neorv32_dmem_ram_Bneorv32_dmem_ram_rtl_Lneorv32_14_0 dmem_ram_inst (
    .clk_i(clk_i),
    .en_i(ben),
    .rw_i(n1650),
    .addr_i(n1651),
    .data_i(n1652),
    .data_o(dmem_ram_inst_n1653));
  /*# ../../rtl/core/neorv32_dmem.vhd:79:20 */
  assign n1656 = n1645[72:69]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:79:40 */
  assign n1657 = n1645[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:79:24 */
  assign n1658 = n1657 ? n1656 : 4'b0000;
  /*# ../../rtl/core/neorv32_dmem.vhd:85:16 */
  assign n1661 = ~rstn_i;
  /*# ../../rtl/core/neorv32_dmem.vhd:89:25 */
  assign n1663 = n1645[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:89:43 */
  assign n1664 = n1645[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:89:29 */
  assign n1665 = n1663 & n1664;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:19 */
  assign n1666 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:36 */
  assign n1667 = n1645[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:59 */
  assign n1668 = n1645[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:45 */
  assign n1669 = ~n1668;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:40 */
  assign n1670 = n1667 & n1669;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:23 */
  assign n1671 = {n1666, n1670};
  /*# ../../rtl/core/neorv32_dmem.vhd:94:37 */
  assign n1679 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:94:27 */
  assign n1680 = n1679 ? rdata : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_dmem.vhd:96:25 */
  assign n1683 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:96:36 */
  assign n1684 = n1683 | wren;
  /*# ../../rtl/core/neorv32_dmem.vhd:26:5 */
  assign n1685 = {n1680, 1'b0, n1684};
  /*# ../../rtl/core/neorv32_dmem.vhd:88:5 */
  always @(posedge clk_i or posedge n1661)
    if (n1661)
      n1686 <= 1'b0;
    else
      n1686 <= n1665;
  /*# ../../rtl/core/neorv32_dmem.vhd:88:5 */
  always @(posedge clk_i or posedge n1661)
    if (n1661)
      n1687 <= 2'b00;
    else
      n1687 <= n1671;
endmodule

module neorv32_imem_Bneorv32_imem_rtl_Lneorv32_16384_0e356ba505631fbf715758bed27d503f8b260e3a
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \bus_req_i[meta] ,
   input  [31:0] \bus_req_i[addr] ,
   input  [31:0] \bus_req_i[data] ,
   input  [3:0] \bus_req_i[ben] ,
   input  \bus_req_i[stb] ,
   input  \bus_req_i[rw] ,
   input  \bus_req_i[amo] ,
   input  [3:0] \bus_req_i[amoop] ,
   input  \bus_req_i[burst] ,
   input  \bus_req_i[lock] ,
   output \bus_rsp_o[ack] ,
   output \bus_rsp_o[err] ,
   output [31:0] \bus_rsp_o[data] );
  wire [81:0] n1600;
  wire n1602;
  wire n1603;
  wire [31:0] n1604;
  wire [31:0] rdata;
  wire wren;
  wire [1:0] rden;
  wire n1605;
  wire [31:0] n1606;
  wire [31:0] imem_rom_imem_rom_inst_n1607;
  wire n1615;
  wire n1617;
  wire n1618;
  wire n1619;
  wire n1620;
  wire n1621;
  wire n1622;
  wire n1623;
  wire n1624;
  wire [1:0] n1625;
  wire n1633;
  wire [31:0] n1634;
  wire n1637;
  wire n1639;
  wire n1640;
  wire n1641;
  wire [33:0] n1642;
  reg n1643;
  reg [1:0] n1644;
  assign \bus_rsp_o[ack]  = n1602; //(module output)
  assign \bus_rsp_o[err]  = n1603; //(module output)
  assign \bus_rsp_o[data]  = n1604; //(module output)
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1600 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1602 = n1642[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1603 = n1642[1]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1604 = n1642[33:2]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:72:10 */
  assign rdata = imem_rom_imem_rom_inst_n1607; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:73:10 */
  assign wren = n1643; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:74:10 */
  assign rden = n1644; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:90:27 */
  assign n1605 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:91:27 */
  assign n1606 = n1600[36:5]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:83:5 */
  neorv32_imem_rom_Bneorv32_imem_rom_rtl_Lneorv32_14_0 imem_rom_imem_rom_inst (
    .clk_i(clk_i),
    .en_i(n1605),
    .addr_i(n1606),
    .data_o(imem_rom_imem_rom_inst_n1607));
  /*# ../../rtl/core/neorv32_imem.vhd:122:16 */
  assign n1615 = ~rstn_i;
  /*# ../../rtl/core/neorv32_imem.vhd:126:25 */
  assign n1617 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:126:43 */
  assign n1618 = n1600[74]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:126:29 */
  assign n1619 = n1617 & n1618;
  /*# ../../rtl/core/neorv32_imem.vhd:127:19 */
  assign n1620 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:36 */
  assign n1621 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:59 */
  assign n1622 = n1600[74]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:45 */
  assign n1623 = ~n1622;
  /*# ../../rtl/core/neorv32_imem.vhd:127:40 */
  assign n1624 = n1621 & n1623;
  /*# ../../rtl/core/neorv32_imem.vhd:127:23 */
  assign n1625 = {n1620, n1624};
  /*# ../../rtl/core/neorv32_imem.vhd:132:37 */
  assign n1633 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:132:27 */
  assign n1634 = n1633 ? rdata : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_imem.vhd:134:25 */
  assign n1637 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:134:36 */
  assign n1639 = 1'b1 ? n1637 : n1641;
  /*# ../../rtl/core/neorv32_imem.vhd:134:60 */
  assign n1640 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:134:71 */
  assign n1641 = n1640 | wren;
  /*# ../../rtl/core/neorv32_imem.vhd:27:5 */
  assign n1642 = {n1634, 1'b0, n1639};
  /*# ../../rtl/core/neorv32_imem.vhd:125:5 */
  always @(posedge clk_i or posedge n1615)
    if (n1615)
      n1643 <= 1'b0;
    else
      n1643 <= n1619;
  /*# ../../rtl/core/neorv32_imem.vhd:125:5 */
  always @(posedge clk_i or posedge n1615)
    if (n1615)
      n1644 <= 2'b00;
    else
      n1644 <= n1625;
endmodule

module neorv32_bus_gateway_Bneorv32_bus_gateway_rtl_Lneorv32_16384_16_16384_16_268435456_2048_2097152_16_2048_bd50bc0f8960043decfaeea03012348ae010fe69
  (input  clk_i,
   input  rstn_i,
   output term_o,
   input  [4:0] \req_i[meta] ,
   input  [31:0] \req_i[addr] ,
   input  [31:0] \req_i[data] ,
   input  [3:0] \req_i[ben] ,
   input  \req_i[stb] ,
   input  \req_i[rw] ,
   input  \req_i[amo] ,
   input  [3:0] \req_i[amoop] ,
   input  \req_i[burst] ,
   input  \req_i[lock] ,
   output \rsp_o[ack] ,
   output \rsp_o[err] ,
   output [31:0] \rsp_o[data] ,
   output [4:0] \a_req_o[meta] ,
   output [31:0] \a_req_o[addr] ,
   output [31:0] \a_req_o[data] ,
   output [3:0] \a_req_o[ben] ,
   output \a_req_o[stb] ,
   output \a_req_o[rw] ,
   output \a_req_o[amo] ,
   output [3:0] \a_req_o[amoop] ,
   output \a_req_o[burst] ,
   output \a_req_o[lock] ,
   input  \a_rsp_i[ack] ,
   input  \a_rsp_i[err] ,
   input  [31:0] \a_rsp_i[data] ,
   output [4:0] \b_req_o[meta] ,
   output [31:0] \b_req_o[addr] ,
   output [31:0] \b_req_o[data] ,
   output [3:0] \b_req_o[ben] ,
   output \b_req_o[stb] ,
   output \b_req_o[rw] ,
   output \b_req_o[amo] ,
   output [3:0] \b_req_o[amoop] ,
   output \b_req_o[burst] ,
   output \b_req_o[lock] ,
   input  \b_rsp_i[ack] ,
   input  \b_rsp_i[err] ,
   input  [31:0] \b_rsp_i[data] ,
   output [4:0] \c_req_o[meta] ,
   output [31:0] \c_req_o[addr] ,
   output [31:0] \c_req_o[data] ,
   output [3:0] \c_req_o[ben] ,
   output \c_req_o[stb] ,
   output \c_req_o[rw] ,
   output \c_req_o[amo] ,
   output [3:0] \c_req_o[amoop] ,
   output \c_req_o[burst] ,
   output \c_req_o[lock] ,
   input  \c_rsp_i[ack] ,
   input  \c_rsp_i[err] ,
   input  [31:0] \c_rsp_i[data] ,
   output [4:0] \d_req_o[meta] ,
   output [31:0] \d_req_o[addr] ,
   output [31:0] \d_req_o[data] ,
   output [3:0] \d_req_o[ben] ,
   output \d_req_o[stb] ,
   output \d_req_o[rw] ,
   output \d_req_o[amo] ,
   output [3:0] \d_req_o[amoop] ,
   output \d_req_o[burst] ,
   output \d_req_o[lock] ,
   input  \d_rsp_i[ack] ,
   input  \d_rsp_i[err] ,
   input  [31:0] \d_rsp_i[data] ,
   output [4:0] \x_req_o[meta] ,
   output [31:0] \x_req_o[addr] ,
   output [31:0] \x_req_o[data] ,
   output [3:0] \x_req_o[ben] ,
   output \x_req_o[stb] ,
   output \x_req_o[rw] ,
   output \x_req_o[amo] ,
   output [3:0] \x_req_o[amoop] ,
   output \x_req_o[burst] ,
   output \x_req_o[lock] ,
   input  \x_rsp_i[ack] ,
   input  \x_rsp_i[err] ,
   input  [31:0] \x_rsp_i[data] );
  wire [81:0] n1304;
  wire n1306;
  wire n1307;
  wire [31:0] n1308;
  wire [4:0] n1310;
  wire [31:0] n1311;
  wire [31:0] n1312;
  wire [3:0] n1313;
  wire n1314;
  wire n1315;
  wire n1316;
  wire [3:0] n1317;
  wire n1318;
  wire n1319;
  wire [33:0] n1320;
  wire [4:0] n1322;
  wire [31:0] n1323;
  wire [31:0] n1324;
  wire [3:0] n1325;
  wire n1326;
  wire n1327;
  wire n1328;
  wire [3:0] n1329;
  wire n1330;
  wire n1331;
  wire [33:0] n1332;
  wire [4:0] n1334;
  wire [31:0] n1335;
  wire [31:0] n1336;
  wire [3:0] n1337;
  wire n1338;
  wire n1339;
  wire n1340;
  wire [3:0] n1341;
  wire n1342;
  wire n1343;
  wire [33:0] n1344;
  wire [4:0] n1346;
  wire [31:0] n1347;
  wire [31:0] n1348;
  wire [3:0] n1349;
  wire n1350;
  wire n1351;
  wire n1352;
  wire [3:0] n1353;
  wire n1354;
  wire n1355;
  wire [33:0] n1356;
  wire [4:0] n1358;
  wire [31:0] n1359;
  wire [31:0] n1360;
  wire [3:0] n1361;
  wire n1362;
  wire n1363;
  wire n1364;
  wire [3:0] n1365;
  wire n1366;
  wire n1367;
  wire [33:0] n1368;
  wire [4:0] port_sel;
  wire [4:0] tmo_bits;
  wire tmo_fire;
  wire [409:0] port_req;
  wire [169:0] port_rsp;
  wire [33:0] int_rsp;
  wire [19:0] keeper;
  wire bus_err;
  wire [17:0] n1370;
  wire n1372;
  wire n1374;
  wire n1375;
  wire [17:0] n1378;
  wire n1380;
  wire n1382;
  wire n1383;
  wire n1387;
  wire [10:0] n1390;
  wire n1392;
  wire n1394;
  wire n1395;
  wire [3:0] n1398;
  wire n1400;
  wire n1402;
  wire n1403;
  wire [81:0] n1405;
  wire [81:0] n1406;
  wire [81:0] n1407;
  wire [81:0] n1408;
  wire [81:0] n1409;
  wire n1412;
  wire n1413;
  wire n1414;
  wire [7:0] n1415;
  wire [72:0] n1416;
  wire n1417;
  wire n1418;
  wire n1419;
  wire [7:0] n1420;
  wire [72:0] n1421;
  wire n1422;
  wire n1423;
  wire n1424;
  wire [7:0] n1425;
  wire [72:0] n1426;
  wire n1427;
  wire n1428;
  wire n1429;
  wire [7:0] n1430;
  wire [72:0] n1431;
  localparam [33:0] n1435 = 34'b0000000000000000000000000000000000;
  wire [31:0] n1436;
  wire [31:0] n1437;
  wire [31:0] n1438;
  localparam [33:0] n1439 = 34'b0000000000000000000000000000000000;
  wire [1:0] n1440;
  wire [33:0] n1441;
  wire n1442;
  wire n1443;
  wire n1444;
  wire n1445;
  wire [33:0] n1446;
  wire n1447;
  wire n1448;
  wire n1449;
  wire [33:0] n1450;
  wire [31:0] n1451;
  wire [31:0] n1452;
  wire [31:0] n1453;
  wire [33:0] n1454;
  wire n1455;
  wire n1456;
  wire n1457;
  wire [33:0] n1458;
  wire n1459;
  wire n1460;
  wire n1461;
  wire [33:0] n1462;
  wire [31:0] n1463;
  wire [31:0] n1464;
  wire [31:0] n1465;
  wire [33:0] n1466;
  wire n1467;
  wire n1468;
  wire n1469;
  wire [33:0] n1470;
  wire n1471;
  wire n1472;
  wire n1473;
  wire [33:0] n1474;
  wire [31:0] n1475;
  wire [31:0] n1476;
  wire [31:0] n1477;
  wire [33:0] n1478;
  wire n1479;
  wire n1480;
  wire n1481;
  wire [33:0] n1482;
  wire n1483;
  wire n1484;
  wire n1485;
  wire [33:0] n1486;
  wire [31:0] n1489;
  wire n1490;
  wire n1491;
  wire n1492;
  wire n1493;
  wire n1495;
  wire [1:0] n1501;
  wire n1502;
  wire n1504;
  wire [1:0] n1506;
  wire [1:0] n1507;
  wire n1509;
  wire n1510;
  wire [11:0] n1512;
  wire [11:0] n1514;
  wire [11:0] n1515;
  wire n1517;
  wire n1518;
  wire n1519;
  wire [1:0] n1521;
  wire [1:0] n1522;
  wire n1523;
  wire [1:0] n1525;
  wire [1:0] n1526;
  wire [1:0] n1527;
  wire [1:0] n1528;
  wire n1530;
  wire n1531;
  wire n1532;
  wire n1533;
  wire n1534;
  wire n1535;
  wire [1:0] n1537;
  wire [1:0] n1538;
  wire [1:0] n1539;
  reg [1:0] n1540;
  wire n1541;
  reg n1542;
  wire [4:0] n1543;
  reg [4:0] n1544;
  wire [11:0] n1545;
  reg [11:0] n1546;
  wire [19:0] n1547;
  wire [19:0] n1549;
  wire n1552;
  wire n1554;
  wire n1556;
  wire n1558;
  wire n1560;
  wire n1562;
  wire n1564;
  wire n1566;
  wire n1568;
  wire n1570;
  wire [4:0] n1573;
  wire [4:0] n1574;
  wire n1580;
  wire n1582;
  wire n1584;
  wire n1585;
  wire n1586;
  wire n1587;
  wire n1588;
  wire n1589;
  wire n1590;
  wire n1591;
  wire n1592;
  wire n1593;
  wire [4:0] n1594;
  wire [4:0] n1595;
  wire [409:0] n1596;
  wire [169:0] n1597;
  wire [33:0] n1598;
  reg [19:0] n1599;
  assign term_o = n1593; //(module output)
  assign \rsp_o[ack]  = n1306; //(module output)
  assign \rsp_o[err]  = n1307; //(module output)
  assign \rsp_o[data]  = n1308; //(module output)
  assign \a_req_o[meta]  = n1310; //(module output)
  assign \a_req_o[addr]  = n1311; //(module output)
  assign \a_req_o[data]  = n1312; //(module output)
  assign \a_req_o[ben]  = n1313; //(module output)
  assign \a_req_o[stb]  = n1314; //(module output)
  assign \a_req_o[rw]  = n1315; //(module output)
  assign \a_req_o[amo]  = n1316; //(module output)
  assign \a_req_o[amoop]  = n1317; //(module output)
  assign \a_req_o[burst]  = n1318; //(module output)
  assign \a_req_o[lock]  = n1319; //(module output)
  assign \b_req_o[meta]  = n1322; //(module output)
  assign \b_req_o[addr]  = n1323; //(module output)
  assign \b_req_o[data]  = n1324; //(module output)
  assign \b_req_o[ben]  = n1325; //(module output)
  assign \b_req_o[stb]  = n1326; //(module output)
  assign \b_req_o[rw]  = n1327; //(module output)
  assign \b_req_o[amo]  = n1328; //(module output)
  assign \b_req_o[amoop]  = n1329; //(module output)
  assign \b_req_o[burst]  = n1330; //(module output)
  assign \b_req_o[lock]  = n1331; //(module output)
  assign \c_req_o[meta]  = n1334; //(module output)
  assign \c_req_o[addr]  = n1335; //(module output)
  assign \c_req_o[data]  = n1336; //(module output)
  assign \c_req_o[ben]  = n1337; //(module output)
  assign \c_req_o[stb]  = n1338; //(module output)
  assign \c_req_o[rw]  = n1339; //(module output)
  assign \c_req_o[amo]  = n1340; //(module output)
  assign \c_req_o[amoop]  = n1341; //(module output)
  assign \c_req_o[burst]  = n1342; //(module output)
  assign \c_req_o[lock]  = n1343; //(module output)
  assign \d_req_o[meta]  = n1346; //(module output)
  assign \d_req_o[addr]  = n1347; //(module output)
  assign \d_req_o[data]  = n1348; //(module output)
  assign \d_req_o[ben]  = n1349; //(module output)
  assign \d_req_o[stb]  = n1350; //(module output)
  assign \d_req_o[rw]  = n1351; //(module output)
  assign \d_req_o[amo]  = n1352; //(module output)
  assign \d_req_o[amoop]  = n1353; //(module output)
  assign \d_req_o[burst]  = n1354; //(module output)
  assign \d_req_o[lock]  = n1355; //(module output)
  assign \x_req_o[meta]  = n1358; //(module output)
  assign \x_req_o[addr]  = n1359; //(module output)
  assign \x_req_o[data]  = n1360; //(module output)
  assign \x_req_o[ben]  = n1361; //(module output)
  assign \x_req_o[stb]  = n1362; //(module output)
  assign \x_req_o[rw]  = n1363; //(module output)
  assign \x_req_o[amo]  = n1364; //(module output)
  assign \x_req_o[amoop]  = n1365; //(module output)
  assign \x_req_o[burst]  = n1366; //(module output)
  assign \x_req_o[lock]  = n1367; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1304 = {\req_i[lock] , \req_i[burst] , \req_i[amoop] , \req_i[amo] , \req_i[rw] , \req_i[stb] , \req_i[ben] , \req_i[data] , \req_i[addr] , \req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1306 = n1598[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1307 = n1598[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1308 = n1598[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1310 = n1405[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1311 = n1405[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1312 = n1405[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1313 = n1405[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1314 = n1405[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1315 = n1405[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1316 = n1405[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1317 = n1405[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1318 = n1405[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1319 = n1405[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1320 = {\a_rsp_i[data] , \a_rsp_i[err] , \a_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1322 = n1406[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1323 = n1406[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1324 = n1406[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1325 = n1406[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1326 = n1406[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1327 = n1406[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1328 = n1406[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1329 = n1406[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1330 = n1406[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1331 = n1406[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1332 = {\b_rsp_i[data] , \b_rsp_i[err] , \b_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1334 = n1407[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1335 = n1407[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1336 = n1407[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1337 = n1407[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1338 = n1407[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1339 = n1407[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1340 = n1407[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1341 = n1407[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1342 = n1407[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1343 = n1407[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1344 = {\c_rsp_i[data] , \c_rsp_i[err] , \c_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1346 = n1408[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1347 = n1408[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1348 = n1408[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1349 = n1408[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1350 = n1408[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1351 = n1408[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1352 = n1408[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1353 = n1408[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1354 = n1408[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1355 = n1408[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1356 = {\d_rsp_i[data] , \d_rsp_i[err] , \d_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1358 = n1409[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1359 = n1409[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1360 = n1409[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1361 = n1409[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1362 = n1409[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1363 = n1409[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1364 = n1409[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1365 = n1409[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1366 = n1409[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1367 = n1409[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1368 = {\x_rsp_i[data] , \x_rsp_i[err] , \x_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:319:10 */
  assign port_sel = n1594; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:350:10 */
  assign tmo_bits = n1595; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:351:10 */
  assign tmo_fire = n1591; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign port_req = n1596; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:371:10 */
  assign port_rsp = n1597; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:374:10 */
  assign int_rsp = n1486; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign keeper = n1599; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:384:10 */
  assign bus_err = n1592; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:390:47 */
  assign n1370 = n1304[36:19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:390:66 */
  assign n1372 = n1370 == 18'b000000000000000000;
  /*# ../../rtl/core/neorv32_bus.vhd:390:32 */
  assign n1374 = n1372 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:390:22 */
  assign n1375 = n1374 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:391:47 */
  assign n1378 = n1304[36:19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:391:66 */
  assign n1380 = n1378 == 18'b100000000000000000;
  /*# ../../rtl/core/neorv32_bus.vhd:391:32 */
  assign n1382 = n1380 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:391:22 */
  assign n1383 = n1382 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:392:22 */
  assign n1387 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:393:47 */
  assign n1390 = n1304[36:26]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:393:66 */
  assign n1392 = n1390 == 11'b11111111111;
  /*# ../../rtl/core/neorv32_bus.vhd:393:32 */
  assign n1394 = n1392 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:393:22 */
  assign n1395 = n1394 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:394:45 */
  assign n1398 = port_sel[3:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:394:58 */
  assign n1400 = n1398 == 4'b0000;
  /*# ../../rtl/core/neorv32_bus.vhd:394:32 */
  assign n1402 = n1400 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:394:22 */
  assign n1403 = n1402 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:398:22 */
  assign n1405 = port_req[409:328]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:399:22 */
  assign n1406 = port_req[327:246]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:400:22 */
  assign n1407 = port_req[245:164]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:401:22 */
  assign n1408 = port_req[163:82]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:402:22 */
  assign n1409 = port_req[81:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1412 = n1304[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1413 = port_sel[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1414 = n1412 & n1413;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1415 = n1304[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1416 = n1304[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1417 = n1304[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1418 = port_sel[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1419 = n1417 & n1418;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1420 = n1304[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1421 = n1304[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1422 = n1304[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1423 = port_sel[3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1424 = n1422 & n1423;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1425 = n1304[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1426 = n1304[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1427 = n1304[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1428 = port_sel[4]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1429 = n1427 & n1428;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1430 = n1304[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1431 = n1304[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1436 = n1435[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1437 = port_rsp[169:138]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1438 = n1436 | n1437;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1440 = n1439[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1441 = {n1438, n1440};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1442 = n1441[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1443 = port_rsp[136]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1444 = n1442 | n1443;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1445 = n1439[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1446 = {n1438, n1445, n1444};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1447 = n1446[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1448 = port_rsp[137]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1449 = n1447 | n1448;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1450 = {n1438, n1449, n1444};
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1451 = n1450[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1452 = port_rsp[135:104]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1453 = n1451 | n1452;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1454 = {n1453, n1449, n1444};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1455 = n1454[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1456 = port_rsp[102]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1457 = n1455 | n1456;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1458 = {n1453, n1449, n1457};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1459 = n1458[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1460 = port_rsp[103]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1461 = n1459 | n1460;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1462 = {n1453, n1461, n1457};
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1463 = n1462[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1464 = port_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1465 = n1463 | n1464;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1466 = {n1465, n1461, n1457};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1467 = n1466[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1468 = port_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1469 = n1467 | n1468;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1470 = {n1465, n1461, n1469};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1471 = n1470[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1472 = port_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1473 = n1471 | n1472;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1474 = {n1465, n1473, n1469};
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1475 = n1474[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1476 = port_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1477 = n1475 | n1476;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1478 = {n1477, n1473, n1469};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1479 = n1478[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1480 = port_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1481 = n1479 | n1480;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1482 = {n1477, n1473, n1481};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1483 = n1482[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1484 = port_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1485 = n1483 | n1484;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1486 = {n1477, n1485, n1481};
  /*# ../../rtl/core/neorv32_bus.vhd:432:25 */
  assign n1489 = int_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:433:25 */
  assign n1490 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:433:29 */
  assign n1491 = n1490 | bus_err;
  /*# ../../rtl/core/neorv32_bus.vhd:434:25 */
  assign n1492 = int_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:434:29 */
  assign n1493 = n1492 | bus_err;
  /*# ../../rtl/core/neorv32_bus.vhd:440:16 */
  assign n1495 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:446:19 */
  assign n1501 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:450:32 */
  assign n1502 = n1304[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:453:21 */
  assign n1504 = n1304[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1506 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:453:11 */
  assign n1507 = n1504 ? 2'b01 : n1506;
  /*# ../../rtl/core/neorv32_bus.vhd:448:9 */
  assign n1509 = n1501 == 2'b00;
  /*# ../../rtl/core/neorv32_bus.vhd:460:23 */
  assign n1510 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:463:61 */
  assign n1512 = keeper[19:8]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:463:66 */
  assign n1514 = n1512 + 12'b000000000001;
  /*# ../../rtl/core/neorv32_bus.vhd:460:11 */
  assign n1515 = n1510 ? 12'b000000000000 : n1514;
  /*# ../../rtl/core/neorv32_bus.vhd:468:25 */
  assign n1517 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:23 */
  assign n1518 = n1304[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:28 */
  assign n1519 = ~n1518;
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1521 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:13 */
  assign n1522 = n1519 ? 2'b00 : n1521;
  /*# ../../rtl/core/neorv32_bus.vhd:472:26 */
  assign n1523 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1525 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:472:11 */
  assign n1526 = n1523 ? 2'b00 : n1525;
  /*# ../../rtl/core/neorv32_bus.vhd:468:11 */
  assign n1527 = n1517 ? n1522 : n1526;
  /*# ../../rtl/core/neorv32_bus.vhd:466:11 */
  assign n1528 = tmo_fire ? 2'b11 : n1527;
  /*# ../../rtl/core/neorv32_bus.vhd:457:9 */
  assign n1530 = n1501 == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:478:22 */
  assign n1531 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:27 */
  assign n1532 = ~n1531;
  /*# ../../rtl/core/neorv32_bus.vhd:478:44 */
  assign n1533 = n1304[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:49 */
  assign n1534 = ~n1533;
  /*# ../../rtl/core/neorv32_bus.vhd:478:34 */
  assign n1535 = n1532 | n1534;
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1537 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:11 */
  assign n1538 = n1535 ? 2'b00 : n1537;
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  assign n1539 = {n1530, n1509};
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1539)
      2'b10: n1540 = n1528;
      2'b01: n1540 = n1507;
      default: n1540 = n1538;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1541 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1539)
      2'b10: n1542 = n1541;
      2'b01: n1542 = n1502;
      default: n1542 = n1541;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1543 = keeper[7:3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1539)
      2'b10: n1544 = n1543;
      2'b01: n1544 = port_sel;
      default: n1544 = n1543;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1545 = keeper[19:8]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1539)
      2'b10: n1546 = n1515;
      2'b01: n1546 = 12'b000000000000;
      default: n1546 = n1545;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:445:5 */
  assign n1547 = {n1546, n1544, n1542, n1540};
  /*# ../../rtl/core/neorv32_bus.vhd:440:5 */
  assign n1549 = {12'b000000000000, 5'b00000, 1'b0, 2'b00};
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1552 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1554 = 1'b1 ? n1552 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1556 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1558 = 1'b1 ? n1556 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1560 = keeper[19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1562 = 1'b1 ? n1560 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1564 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1566 = 1'b1 ? n1564 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1568 = keeper[19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1570 = 1'b1 ? n1568 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:491:47 */
  assign n1573 = keeper[7:3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:491:36 */
  assign n1574 = tmo_bits & n1573;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1580 = n1574[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1582 = 1'b0 | n1580;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1584 = n1574[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1585 = n1582 | n1584;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1586 = n1574[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1587 = n1585 | n1586;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1588 = n1574[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1589 = n1587 | n1588;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1590 = n1574[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1591 = n1589 | n1590;
  /*# ../../rtl/core/neorv32_bus.vhd:494:26 */
  assign n1592 = keeper[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:495:26 */
  assign n1593 = keeper[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:319:10 */
  assign n1594 = {n1403, n1395, n1387, n1383, n1375};
  /*# ../../rtl/core/neorv32_bus.vhd:350:10 */
  assign n1595 = {n1570, n1566, n1562, n1558, n1554};
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1596 = {n1415, n1414, n1416, n1420, n1419, n1421, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n1425, n1424, n1426, n1430, n1429, n1431};
  /*# ../../rtl/core/neorv32_bus.vhd:371:10 */
  assign n1597 = {n1320, n1332, n1344, n1356, n1368};
  /*# ../../rtl/core/neorv32_bus.vhd:297:5 */
  assign n1598 = {n1489, n1493, n1491};
  /*# ../../rtl/core/neorv32_bus.vhd:445:5 */
  always @(posedge clk_i or posedge n1495)
    if (n1495)
      n1599 <= n1549;
    else
      n1599 <= n1547;
endmodule

module neorv32_bus_switch_Bneorv32_bus_switch_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264
  (input  clk_i,
   input  rstn_i,
   input  [4:0] \a_req_i[meta] ,
   input  [31:0] \a_req_i[addr] ,
   input  [31:0] \a_req_i[data] ,
   input  [3:0] \a_req_i[ben] ,
   input  \a_req_i[stb] ,
   input  \a_req_i[rw] ,
   input  \a_req_i[amo] ,
   input  [3:0] \a_req_i[amoop] ,
   input  \a_req_i[burst] ,
   input  \a_req_i[lock] ,
   output \a_rsp_o[ack] ,
   output \a_rsp_o[err] ,
   output [31:0] \a_rsp_o[data] ,
   input  [4:0] \b_req_i[meta] ,
   input  [31:0] \b_req_i[addr] ,
   input  [31:0] \b_req_i[data] ,
   input  [3:0] \b_req_i[ben] ,
   input  \b_req_i[stb] ,
   input  \b_req_i[rw] ,
   input  \b_req_i[amo] ,
   input  [3:0] \b_req_i[amoop] ,
   input  \b_req_i[burst] ,
   input  \b_req_i[lock] ,
   output \b_rsp_o[ack] ,
   output \b_rsp_o[err] ,
   output [31:0] \b_rsp_o[data] ,
   output [4:0] \x_req_o[meta] ,
   output [31:0] \x_req_o[addr] ,
   output [31:0] \x_req_o[data] ,
   output [3:0] \x_req_o[ben] ,
   output \x_req_o[stb] ,
   output \x_req_o[rw] ,
   output \x_req_o[amo] ,
   output [3:0] \x_req_o[amoop] ,
   output \x_req_o[burst] ,
   output \x_req_o[lock] ,
   input  \x_rsp_i[ack] ,
   input  \x_rsp_i[err] ,
   input  [31:0] \x_rsp_i[data] );
  wire [81:0] n1116;
  wire n1118;
  wire n1119;
  wire [31:0] n1120;
  wire [81:0] n1121;
  wire n1123;
  wire n1124;
  wire [31:0] n1125;
  wire [4:0] n1127;
  wire [31:0] n1128;
  wire [31:0] n1129;
  wire [3:0] n1130;
  wire n1131;
  wire n1132;
  wire n1133;
  wire [3:0] n1134;
  wire n1135;
  wire n1136;
  wire [33:0] n1137;
  wire [1:0] state;
  wire [1:0] state_nxt;
  wire a_req;
  wire b_req;
  wire sel;
  wire sel_q;
  wire stb;
  wire [1:0] lock;
  wire [1:0] lock_nxt;
  wire n1139;
  wire n1142;
  wire n1143;
  wire n1145;
  wire n1147;
  wire n1149;
  wire n1150;
  wire n1152;
  wire n1154;
  wire n1172;
  wire n1173;
  wire n1174;
  wire n1175;
  wire n1176;
  wire n1177;
  wire n1178;
  wire n1179;
  wire n1180;
  wire n1181;
  wire [1:0] n1183;
  wire n1185;
  wire n1186;
  wire n1187;
  wire n1188;
  wire n1189;
  wire n1190;
  wire n1191;
  wire n1192;
  wire n1193;
  wire n1194;
  wire n1195;
  wire [1:0] n1197;
  wire n1199;
  wire n1200;
  wire n1201;
  wire [1:0] n1202;
  wire n1203;
  wire n1204;
  wire n1205;
  wire n1206;
  wire [1:0] n1208;
  wire n1211;
  wire n1214;
  wire [1:0] n1216;
  wire n1218;
  wire n1220;
  wire n1222;
  wire [2:0] n1223;
  reg [1:0] n1225;
  reg n1229;
  reg n1232;
  reg [1:0] n1235;
  wire [4:0] n1237;
  wire n1238;
  wire [4:0] n1239;
  wire [4:0] n1240;
  wire [31:0] n1241;
  wire n1242;
  wire [31:0] n1243;
  wire [31:0] n1244;
  wire [31:0] n1245;
  wire [31:0] n1247;
  wire [31:0] n1248;
  wire [31:0] n1250;
  wire [31:0] n1251;
  wire n1252;
  wire [31:0] n1253;
  wire [31:0] n1254;
  wire [3:0] n1255;
  wire n1256;
  wire [3:0] n1257;
  wire [3:0] n1258;
  wire n1259;
  wire n1260;
  wire n1261;
  wire n1262;
  wire n1263;
  wire n1264;
  wire n1265;
  wire n1266;
  wire [3:0] n1267;
  wire n1268;
  wire [3:0] n1269;
  wire [3:0] n1270;
  wire n1271;
  wire n1272;
  wire n1273;
  wire n1274;
  wire n1275;
  wire n1276;
  wire n1277;
  wire n1278;
  wire n1279;
  wire n1280;
  wire n1281;
  wire n1283;
  wire n1284;
  wire n1285;
  wire [31:0] n1287;
  wire n1288;
  wire n1289;
  wire n1291;
  wire n1292;
  wire [31:0] n1294;
  wire [33:0] n1295;
  wire [33:0] n1296;
  wire [81:0] n1297;
  reg [1:0] n1298;
  reg n1299;
  reg n1300;
  reg n1301;
  reg [1:0] n1302;
  assign \a_rsp_o[ack]  = n1118; //(module output)
  assign \a_rsp_o[err]  = n1119; //(module output)
  assign \a_rsp_o[data]  = n1120; //(module output)
  assign \b_rsp_o[ack]  = n1123; //(module output)
  assign \b_rsp_o[err]  = n1124; //(module output)
  assign \b_rsp_o[data]  = n1125; //(module output)
  assign \x_req_o[meta]  = n1127; //(module output)
  assign \x_req_o[addr]  = n1128; //(module output)
  assign \x_req_o[data]  = n1129; //(module output)
  assign \x_req_o[ben]  = n1130; //(module output)
  assign \x_req_o[stb]  = n1131; //(module output)
  assign \x_req_o[rw]  = n1132; //(module output)
  assign \x_req_o[amo]  = n1133; //(module output)
  assign \x_req_o[amoop]  = n1134; //(module output)
  assign \x_req_o[burst]  = n1135; //(module output)
  assign \x_req_o[lock]  = n1136; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1116 = {\a_req_i[lock] , \a_req_i[burst] , \a_req_i[amoop] , \a_req_i[amo] , \a_req_i[rw] , \a_req_i[stb] , \a_req_i[ben] , \a_req_i[data] , \a_req_i[addr] , \a_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1118 = n1295[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1119 = n1295[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1120 = n1295[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1121 = {\b_req_i[lock] , \b_req_i[burst] , \b_req_i[amoop] , \b_req_i[amo] , \b_req_i[rw] , \b_req_i[stb] , \b_req_i[ben] , \b_req_i[data] , \b_req_i[addr] , \b_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1123 = n1296[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1124 = n1296[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1125 = n1296[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1127 = n1297[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1128 = n1297[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1129 = n1297[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1130 = n1297[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1131 = n1297[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1132 = n1297[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1133 = n1297[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1134 = n1297[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1135 = n1297[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1136 = n1297[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1137 = {\x_rsp_i[data] , \x_rsp_i[err] , \x_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:38:10 */
  assign state = n1298; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:38:17 */
  assign state_nxt = n1225; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:10 */
  assign a_req = n1299; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:17 */
  assign b_req = n1300; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:24 */
  assign sel = n1229; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:29 */
  assign sel_q = n1301; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:36 */
  assign stb = n1232; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:40:10 */
  assign lock = n1302; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:40:16 */
  assign lock_nxt = n1235; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:48:16 */
  assign n1139 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:58:17 */
  assign n1142 = state == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:60:22 */
  assign n1143 = n1116[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:60:7 */
  assign n1145 = n1143 ? 1'b1 : a_req;
  /*# ../../rtl/core/neorv32_bus.vhd:58:7 */
  assign n1147 = n1142 ? 1'b0 : n1145;
  /*# ../../rtl/core/neorv32_bus.vhd:63:17 */
  assign n1149 = state == 2'b10;
  /*# ../../rtl/core/neorv32_bus.vhd:65:22 */
  assign n1150 = n1121[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:65:7 */
  assign n1152 = n1150 ? 1'b1 : b_req;
  /*# ../../rtl/core/neorv32_bus.vhd:63:7 */
  assign n1154 = n1149 ? 1'b0 : n1152;
  /*# ../../rtl/core/neorv32_bus.vhd:87:24 */
  assign n1172 = n1116[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:18 */
  assign n1173 = lock[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:42 */
  assign n1174 = n1116[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:47 */
  assign n1175 = ~n1174;
  /*# ../../rtl/core/neorv32_bus.vhd:88:29 */
  assign n1176 = n1175 & n1173;
  /*# ../../rtl/core/neorv32_bus.vhd:88:64 */
  assign n1177 = lock[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:68 */
  assign n1178 = ~n1177;
  /*# ../../rtl/core/neorv32_bus.vhd:88:88 */
  assign n1179 = n1137[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:75 */
  assign n1180 = n1179 & n1178;
  /*# ../../rtl/core/neorv32_bus.vhd:88:55 */
  assign n1181 = n1176 | n1180;
  /*# ../../rtl/core/neorv32_bus.vhd:88:9 */
  assign n1183 = n1181 ? 2'b00 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:84:7 */
  assign n1185 = state == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:95:24 */
  assign n1186 = n1121[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:18 */
  assign n1187 = lock[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:42 */
  assign n1188 = n1121[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:47 */
  assign n1189 = ~n1188;
  /*# ../../rtl/core/neorv32_bus.vhd:96:29 */
  assign n1190 = n1189 & n1187;
  /*# ../../rtl/core/neorv32_bus.vhd:96:64 */
  assign n1191 = lock[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:68 */
  assign n1192 = ~n1191;
  /*# ../../rtl/core/neorv32_bus.vhd:96:88 */
  assign n1193 = n1137[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:75 */
  assign n1194 = n1193 & n1192;
  /*# ../../rtl/core/neorv32_bus.vhd:96:55 */
  assign n1195 = n1190 | n1194;
  /*# ../../rtl/core/neorv32_bus.vhd:96:9 */
  assign n1197 = n1195 ? 2'b00 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:92:7 */
  assign n1199 = state == 2'b10;
  /*# ../../rtl/core/neorv32_bus.vhd:102:29 */
  assign n1200 = n1121[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:102:44 */
  assign n1201 = n1116[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:102:34 */
  assign n1202 = {n1200, n1201};
  /*# ../../rtl/core/neorv32_bus.vhd:104:23 */
  assign n1203 = n1116[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:104:34 */
  assign n1204 = n1203 | a_req;
  /*# ../../rtl/core/neorv32_bus.vhd:108:26 */
  assign n1205 = n1121[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:108:37 */
  assign n1206 = n1205 | b_req;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1208 = n1206 ? 2'b10 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1211 = n1206 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1214 = n1206 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1216 = n1204 ? 2'b01 : n1208;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1218 = n1204 ? 1'b0 : n1211;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1220 = n1204 ? 1'b1 : n1214;
  /*# ../../rtl/core/neorv32_bus.vhd:100:7 */
  assign n1222 = state == 2'b00;
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  assign n1223 = {n1222, n1199, n1185};
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1223)
      3'b100: n1225 = n1216;
      3'b010: n1225 = n1197;
      3'b001: n1225 = n1183;
      default: n1225 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1223)
      3'b100: n1229 = n1218;
      3'b010: n1229 = 1'b1;
      3'b001: n1229 = 1'b0;
      default: n1229 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1223)
      3'b100: n1232 = n1220;
      3'b010: n1232 = n1186;
      3'b001: n1232 = n1172;
      default: n1232 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1223)
      3'b100: n1235 = n1202;
      3'b010: n1235 = lock;
      3'b001: n1235 = lock;
      default: n1235 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:130:28 */
  assign n1237 = n1116[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:130:44 */
  assign n1238 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:130:34 */
  assign n1239 = n1238 ? n1237 : n1240;
  /*# ../../rtl/core/neorv32_bus.vhd:130:64 */
  assign n1240 = n1121[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:131:28 */
  assign n1241 = n1116[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:131:44 */
  assign n1242 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:131:34 */
  assign n1243 = n1242 ? n1241 : n1244;
  /*# ../../rtl/core/neorv32_bus.vhd:131:64 */
  assign n1244 = n1121[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:28 */
  assign n1245 = n1121[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:34 */
  assign n1247 = 1'b0 ? n1245 : n1250;
  /*# ../../rtl/core/neorv32_bus.vhd:133:28 */
  assign n1248 = n1116[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:51 */
  assign n1250 = 1'b1 ? n1248 : n1253;
  /*# ../../rtl/core/neorv32_bus.vhd:134:28 */
  assign n1251 = n1116[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:134:44 */
  assign n1252 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:133:51 */
  assign n1253 = n1252 ? n1251 : n1254;
  /*# ../../rtl/core/neorv32_bus.vhd:134:64 */
  assign n1254 = n1121[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:135:28 */
  assign n1255 = n1116[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:135:44 */
  assign n1256 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:135:34 */
  assign n1257 = n1256 ? n1255 : n1258;
  /*# ../../rtl/core/neorv32_bus.vhd:135:64 */
  assign n1258 = n1121[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:136:28 */
  assign n1259 = n1116[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:136:44 */
  assign n1260 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:136:34 */
  assign n1261 = n1260 ? n1259 : n1262;
  /*# ../../rtl/core/neorv32_bus.vhd:136:64 */
  assign n1262 = n1121[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:137:28 */
  assign n1263 = n1116[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:137:44 */
  assign n1264 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:137:34 */
  assign n1265 = n1264 ? n1263 : n1266;
  /*# ../../rtl/core/neorv32_bus.vhd:137:64 */
  assign n1266 = n1121[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:138:28 */
  assign n1267 = n1116[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:138:44 */
  assign n1268 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:138:34 */
  assign n1269 = n1268 ? n1267 : n1270;
  /*# ../../rtl/core/neorv32_bus.vhd:138:64 */
  assign n1270 = n1121[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:139:28 */
  assign n1271 = n1116[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:139:44 */
  assign n1272 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:139:34 */
  assign n1273 = n1272 ? n1271 : n1274;
  /*# ../../rtl/core/neorv32_bus.vhd:139:64 */
  assign n1274 = n1121[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:140:28 */
  assign n1275 = n1116[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:140:44 */
  assign n1276 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:140:34 */
  assign n1277 = n1276 ? n1275 : n1278;
  /*# ../../rtl/core/neorv32_bus.vhd:140:64 */
  assign n1278 = n1121[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:145:27 */
  assign n1279 = n1137[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:145:43 */
  assign n1280 = ~sel_q;
  /*# ../../rtl/core/neorv32_bus.vhd:145:31 */
  assign n1281 = n1280 ? n1279 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:146:27 */
  assign n1283 = n1137[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:146:43 */
  assign n1284 = ~sel_q;
  /*# ../../rtl/core/neorv32_bus.vhd:146:31 */
  assign n1285 = n1284 ? n1283 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:147:27 */
  assign n1287 = n1137[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:149:27 */
  assign n1288 = n1137[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:149:31 */
  assign n1289 = sel_q ? n1288 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:150:27 */
  assign n1291 = n1137[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:150:31 */
  assign n1292 = sel_q ? n1291 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:151:27 */
  assign n1294 = n1137[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:27:5 */
  assign n1295 = {n1287, n1285, n1281};
  /*# ../../rtl/core/neorv32_bus.vhd:29:5 */
  assign n1296 = {n1294, n1292, n1289};
  /*# ../../rtl/core/neorv32_bus.vhd:30:5 */
  assign n1297 = {n1277, n1273, n1269, n1265, n1261, stb, n1257, n1247, n1243, n1239};
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1139)
    if (n1139)
      n1298 <= 2'b00;
    else
      n1298 <= state_nxt;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1139)
    if (n1139)
      n1299 <= 1'b0;
    else
      n1299 <= n1147;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1139)
    if (n1139)
      n1300 <= 1'b0;
    else
      n1300 <= n1154;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1139)
    if (n1139)
      n1301 <= 1'b0;
    else
      n1301 <= sel;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1139)
    if (n1139)
      n1302 <= 2'b00;
    else
      n1302 <= lock_nxt;
endmodule

module neorv32_cpu_Bneorv32_cpu_rtl_Lneorv32_0_0_0_4_0_40_0_e5735315961a7ae0119503075b3425320cc9d860
  (input  clk_i,
   input  rstn_i,
   input  [63:0] mtime_i,
   output \trace_o[valid] ,
   output [31:0] \trace_o[order] ,
   output [31:0] \trace_o[insn] ,
   output \trace_o[trap] ,
   output \trace_o[halt] ,
   output \trace_o[intr] ,
   output [1:0] \trace_o[mode] ,
   output [1:0] \trace_o[ixl] ,
   output \trace_o[debug] ,
   output \trace_o[compr] ,
   output \trace_o[delta] ,
   output [31:0] \trace_o[cmd32] ,
   output [4:0] \trace_o[rs1_addr] ,
   output [4:0] \trace_o[rs2_addr] ,
   output [31:0] \trace_o[rs1_rdata] ,
   output [31:0] \trace_o[rs2_rdata] ,
   output [4:0] \trace_o[rd_addr] ,
   output [31:0] \trace_o[rd_rdata] ,
   output [31:0] \trace_o[pc_rdata] ,
   output [31:0] \trace_o[pc_wdata] ,
   output [11:0] \trace_o[csr_addr] ,
   output [31:0] \trace_o[csr_rdata] ,
   output [31:0] \trace_o[csr_wdata] ,
   output [31:0] \trace_o[mem_addr] ,
   output [3:0] \trace_o[mem_rmask] ,
   output [3:0] \trace_o[mem_wmask] ,
   output [31:0] \trace_o[mem_rdata] ,
   output [31:0] \trace_o[mem_wdata] ,
   output sleep_o,
   input  msi_i,
   input  mei_i,
   input  mti_i,
   input  [15:0] firq_i,
   input  dbi_i,
   output ifence_o,
   output [4:0] \ibus_req_o[meta] ,
   output [31:0] \ibus_req_o[addr] ,
   output [31:0] \ibus_req_o[data] ,
   output [3:0] \ibus_req_o[ben] ,
   output \ibus_req_o[stb] ,
   output \ibus_req_o[rw] ,
   output \ibus_req_o[amo] ,
   output [3:0] \ibus_req_o[amoop] ,
   output \ibus_req_o[burst] ,
   output \ibus_req_o[lock] ,
   input  \ibus_rsp_i[ack] ,
   input  \ibus_rsp_i[err] ,
   input  [31:0] \ibus_rsp_i[data] ,
   output dfence_o,
   output [4:0] \dbus_req_o[meta] ,
   output [31:0] \dbus_req_o[addr] ,
   output [31:0] \dbus_req_o[data] ,
   output [3:0] \dbus_req_o[ben] ,
   output \dbus_req_o[stb] ,
   output \dbus_req_o[rw] ,
   output \dbus_req_o[amo] ,
   output [3:0] \dbus_req_o[amoop] ,
   output \dbus_req_o[burst] ,
   output \dbus_req_o[lock] ,
   input  \dbus_rsp_i[ack] ,
   input  \dbus_rsp_i[err] ,
   input  [31:0] \dbus_rsp_i[data] );
  wire n798;
  wire [31:0] n799;
  wire [31:0] n800;
  wire n801;
  wire n802;
  wire n803;
  wire [1:0] n804;
  wire [1:0] n805;
  wire n806;
  wire n807;
  wire n808;
  wire [31:0] n809;
  wire [4:0] n810;
  wire [4:0] n811;
  wire [31:0] n812;
  wire [31:0] n813;
  wire [4:0] n814;
  wire [31:0] n815;
  wire [31:0] n816;
  wire [31:0] n817;
  wire [11:0] n818;
  wire [31:0] n819;
  wire [31:0] n820;
  wire [31:0] n821;
  wire [3:0] n822;
  wire [3:0] n823;
  wire [31:0] n824;
  wire [31:0] n825;
  wire [4:0] n829;
  wire [31:0] n830;
  wire [31:0] n831;
  wire [3:0] n832;
  wire n833;
  wire n834;
  wire n835;
  wire [3:0] n836;
  wire n837;
  wire n838;
  wire [33:0] n839;
  wire [4:0] n842;
  wire [31:0] n843;
  wire [31:0] n844;
  wire [3:0] n845;
  wire n846;
  wire n847;
  wire n848;
  wire [3:0] n849;
  wire n850;
  wire n851;
  wire [33:0] n852;
  wire [261:0] ctrl;
  wire [50:0] frontend;
  wire [81:0] dbus_req;
  wire if_pmp_err;
  wire rw_pmp_err;
  wire hwtrig;
  wire [31:0] rf_wdata;
  wire [31:0] rs1;
  wire [31:0] rs2;
  wire [31:0] alu_res;
  wire [31:0] alu_add;
  wire [1:0] alu_cmp;
  wire alu_cp_done;
  wire [31:0] lsu_rdata;
  wire [31:0] lsu_mar;
  wire [3:0] lsu_err;
  wire lsu_wait;
  wire [31:0] csr_rdata;
  wire [2:0] irq_machine;
  wire [31:0] xcsr_tm;
  wire [31:0] xcsr_cnt;
  wire [31:0] xcsr_pmp;
  wire [31:0] xcsr_alu;
  wire [31:0] xcsr_res;
  wire [4:0] \neorv32_cpu_frontend_inst.ibus_req_o[meta] ;
  wire [31:0] \neorv32_cpu_frontend_inst.ibus_req_o[addr] ;
  wire [31:0] \neorv32_cpu_frontend_inst.ibus_req_o[data] ;
  wire [3:0] \neorv32_cpu_frontend_inst.ibus_req_o[ben] ;
  wire \neorv32_cpu_frontend_inst.ibus_req_o[stb] ;
  wire \neorv32_cpu_frontend_inst.ibus_req_o[rw] ;
  wire \neorv32_cpu_frontend_inst.ibus_req_o[amo] ;
  wire [3:0] \neorv32_cpu_frontend_inst.ibus_req_o[amoop] ;
  wire \neorv32_cpu_frontend_inst.ibus_req_o[burst] ;
  wire \neorv32_cpu_frontend_inst.ibus_req_o[lock] ;
  wire [31:0] \neorv32_cpu_frontend_inst.pmp_addr_o ;
  wire \neorv32_cpu_frontend_inst.pmp_priv_o ;
  wire \neorv32_cpu_frontend_inst.frontend_o[valid] ;
  wire [31:0] \neorv32_cpu_frontend_inst.frontend_o[i32] ;
  wire [15:0] \neorv32_cpu_frontend_inst.frontend_o[i16] ;
  wire \neorv32_cpu_frontend_inst.frontend_o[compr] ;
  wire \neorv32_cpu_frontend_inst.frontend_o[fault] ;
  wire n903;
  wire n904;
  wire n905;
  wire [31:0] n906;
  wire [31:0] n907;
  wire [31:0] n908;
  wire n909;
  wire [4:0] n910;
  wire [4:0] n911;
  wire [4:0] n912;
  wire n913;
  wire [2:0] n914;
  wire n915;
  wire n916;
  wire n917;
  wire n918;
  wire [31:0] n919;
  wire n920;
  wire n921;
  wire n922;
  wire n923;
  wire n924;
  wire n925;
  wire n926;
  wire n927;
  wire n928;
  wire n929;
  wire n930;
  wire n931;
  wire [11:0] n932;
  wire [31:0] n933;
  wire [8:0] n934;
  wire [2:0] n935;
  wire [11:0] n936;
  wire [6:0] n937;
  wire [15:0] n938;
  wire n939;
  wire n940;
  wire n941;
  wire n942;
  wire [81:0] n943;
  wire n945;
  wire n946;
  wire [31:0] n947;
  wire [50:0] n950;
  wire \neorv32_cpu_control_inst.ctrl_o[if_reset] ;
  wire \neorv32_cpu_control_inst.ctrl_o[if_ready] ;
  wire \neorv32_cpu_control_inst.ctrl_o[if_fence] ;
  wire [31:0] \neorv32_cpu_control_inst.ctrl_o[pc_cur] ;
  wire [31:0] \neorv32_cpu_control_inst.ctrl_o[pc_nxt] ;
  wire [31:0] \neorv32_cpu_control_inst.ctrl_o[pc_ret] ;
  wire \neorv32_cpu_control_inst.ctrl_o[rf_wb_en] ;
  wire [4:0] \neorv32_cpu_control_inst.ctrl_o[rf_rs1] ;
  wire [4:0] \neorv32_cpu_control_inst.ctrl_o[rf_rs2] ;
  wire [4:0] \neorv32_cpu_control_inst.ctrl_o[rf_rd] ;
  wire \neorv32_cpu_control_inst.ctrl_o[rf_zero] ;
  wire [2:0] \neorv32_cpu_control_inst.ctrl_o[alu_op] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_sub] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_opa_mux] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_opb_mux] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_unsigned] ;
  wire [31:0] \neorv32_cpu_control_inst.ctrl_o[alu_imm] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_cp_alu] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_cp_cfu] ;
  wire \neorv32_cpu_control_inst.ctrl_o[alu_cp_fpu] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_req] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_rd] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_wr] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_mo_en] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_mi_en] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_priv] ;
  wire \neorv32_cpu_control_inst.ctrl_o[lsu_fence] ;
  wire \neorv32_cpu_control_inst.ctrl_o[csr_we] ;
  wire \neorv32_cpu_control_inst.ctrl_o[csr_re] ;
  wire [11:0] \neorv32_cpu_control_inst.ctrl_o[csr_addr] ;
  wire [31:0] \neorv32_cpu_control_inst.ctrl_o[csr_wdata] ;
  wire [8:0] \neorv32_cpu_control_inst.ctrl_o[cnt_event] ;
  wire [2:0] \neorv32_cpu_control_inst.ctrl_o[ir_funct3] ;
  wire [11:0] \neorv32_cpu_control_inst.ctrl_o[ir_funct12] ;
  wire [6:0] \neorv32_cpu_control_inst.ctrl_o[ir_opcode] ;
  wire [15:0] \neorv32_cpu_control_inst.ctrl_o[ir_rvc] ;
  wire \neorv32_cpu_control_inst.ctrl_o[cpu_priv] ;
  wire \neorv32_cpu_control_inst.ctrl_o[cpu_trap] ;
  wire \neorv32_cpu_control_inst.ctrl_o[cpu_sync_exc] ;
  wire \neorv32_cpu_control_inst.ctrl_o[cpu_debug] ;
  wire [261:0] n952;
  wire n954;
  wire [31:0] n955;
  wire [15:0] n956;
  wire n957;
  wire n958;
  wire [1:0] n960;
  wire [2:0] n961;
  wire [31:0] n962;
  wire [31:0] n963;
  wire [31:0] n964;
  wire n965;
  wire n966;
  wire n967;
  wire n968;
  wire n972;
  wire n973;
  wire n974;
  wire [31:0] n975;
  wire [31:0] n976;
  wire [31:0] n977;
  wire n978;
  wire [4:0] n979;
  wire [4:0] n980;
  wire [4:0] n981;
  wire n982;
  wire [2:0] n983;
  wire n984;
  wire n985;
  wire n986;
  wire n987;
  wire [31:0] n988;
  wire n989;
  wire n990;
  wire n991;
  wire n992;
  wire n993;
  wire n994;
  wire n995;
  wire n996;
  wire n997;
  wire n998;
  wire n999;
  wire n1000;
  wire [11:0] n1001;
  wire [31:0] n1002;
  wire [8:0] n1003;
  wire [2:0] n1004;
  wire [11:0] n1005;
  wire [6:0] n1006;
  wire [15:0] n1007;
  wire n1008;
  wire n1009;
  wire n1010;
  wire n1011;
  wire [31:0] n1014;
  wire [31:0] n1015;
  wire [31:0] n1016;
  wire [31:0] n1017;
  wire n1018;
  wire n1019;
  wire n1020;
  wire [31:0] n1021;
  wire [31:0] n1022;
  wire [31:0] n1023;
  wire n1024;
  wire [4:0] n1025;
  wire [4:0] n1026;
  wire [4:0] n1027;
  wire n1028;
  wire [2:0] n1029;
  wire n1030;
  wire n1031;
  wire n1032;
  wire n1033;
  wire [31:0] n1034;
  wire n1035;
  wire n1036;
  wire n1037;
  wire n1038;
  wire n1039;
  wire n1040;
  wire n1041;
  wire n1042;
  wire n1043;
  wire n1044;
  wire n1045;
  wire n1046;
  wire [11:0] n1047;
  wire [31:0] n1048;
  wire [8:0] n1049;
  wire [2:0] n1050;
  wire [11:0] n1051;
  wire [6:0] n1052;
  wire [15:0] n1053;
  wire n1054;
  wire n1055;
  wire n1056;
  wire n1057;
  wire [4:0] \neorv32_cpu_lsu_inst.dbus_req_o[meta] ;
  wire [31:0] \neorv32_cpu_lsu_inst.dbus_req_o[addr] ;
  wire [31:0] \neorv32_cpu_lsu_inst.dbus_req_o[data] ;
  wire [3:0] \neorv32_cpu_lsu_inst.dbus_req_o[ben] ;
  wire \neorv32_cpu_lsu_inst.dbus_req_o[stb] ;
  wire \neorv32_cpu_lsu_inst.dbus_req_o[rw] ;
  wire \neorv32_cpu_lsu_inst.dbus_req_o[amo] ;
  wire [3:0] \neorv32_cpu_lsu_inst.dbus_req_o[amoop] ;
  wire \neorv32_cpu_lsu_inst.dbus_req_o[burst] ;
  wire \neorv32_cpu_lsu_inst.dbus_req_o[lock] ;
  wire n1063;
  wire n1064;
  wire n1065;
  wire [31:0] n1066;
  wire [31:0] n1067;
  wire [31:0] n1068;
  wire n1069;
  wire [4:0] n1070;
  wire [4:0] n1071;
  wire [4:0] n1072;
  wire n1073;
  wire [2:0] n1074;
  wire n1075;
  wire n1076;
  wire n1077;
  wire n1078;
  wire [31:0] n1079;
  wire n1080;
  wire n1081;
  wire n1082;
  wire n1083;
  wire n1084;
  wire n1085;
  wire n1086;
  wire n1087;
  wire n1088;
  wire n1089;
  wire n1090;
  wire n1091;
  wire [11:0] n1092;
  wire [31:0] n1093;
  wire [8:0] n1094;
  wire [2:0] n1095;
  wire [11:0] n1096;
  wire [6:0] n1097;
  wire [15:0] n1098;
  wire n1099;
  wire n1100;
  wire n1101;
  wire n1102;
  wire [81:0] n1107;
  wire n1109;
  wire n1110;
  wire [31:0] n1111;
  localparam [461:0] n1115 = 462'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000;
  assign \trace_o[valid]  = n798; //(module output)
  assign \trace_o[order]  = n799; //(module output)
  assign \trace_o[insn]  = n800; //(module output)
  assign \trace_o[trap]  = n801; //(module output)
  assign \trace_o[halt]  = n802; //(module output)
  assign \trace_o[intr]  = n803; //(module output)
  assign \trace_o[mode]  = n804; //(module output)
  assign \trace_o[ixl]  = n805; //(module output)
  assign \trace_o[debug]  = n806; //(module output)
  assign \trace_o[compr]  = n807; //(module output)
  assign \trace_o[delta]  = n808; //(module output)
  assign \trace_o[cmd32]  = n809; //(module output)
  assign \trace_o[rs1_addr]  = n810; //(module output)
  assign \trace_o[rs2_addr]  = n811; //(module output)
  assign \trace_o[rs1_rdata]  = n812; //(module output)
  assign \trace_o[rs2_rdata]  = n813; //(module output)
  assign \trace_o[rd_addr]  = n814; //(module output)
  assign \trace_o[rd_rdata]  = n815; //(module output)
  assign \trace_o[pc_rdata]  = n816; //(module output)
  assign \trace_o[pc_wdata]  = n817; //(module output)
  assign \trace_o[csr_addr]  = n818; //(module output)
  assign \trace_o[csr_rdata]  = n819; //(module output)
  assign \trace_o[csr_wdata]  = n820; //(module output)
  assign \trace_o[mem_addr]  = n821; //(module output)
  assign \trace_o[mem_rmask]  = n822; //(module output)
  assign \trace_o[mem_wmask]  = n823; //(module output)
  assign \trace_o[mem_rdata]  = n824; //(module output)
  assign \trace_o[mem_wdata]  = n825; //(module output)
  assign sleep_o = n966; //(module output)
  assign ifence_o = n967; //(module output)
  assign \ibus_req_o[meta]  = n829; //(module output)
  assign \ibus_req_o[addr]  = n830; //(module output)
  assign \ibus_req_o[data]  = n831; //(module output)
  assign \ibus_req_o[ben]  = n832; //(module output)
  assign \ibus_req_o[stb]  = n833; //(module output)
  assign \ibus_req_o[rw]  = n834; //(module output)
  assign \ibus_req_o[amo]  = n835; //(module output)
  assign \ibus_req_o[amoop]  = n836; //(module output)
  assign \ibus_req_o[burst]  = n837; //(module output)
  assign \ibus_req_o[lock]  = n838; //(module output)
  assign dfence_o = n968; //(module output)
  assign \dbus_req_o[meta]  = n842; //(module output)
  assign \dbus_req_o[addr]  = n843; //(module output)
  assign \dbus_req_o[data]  = n844; //(module output)
  assign \dbus_req_o[ben]  = n845; //(module output)
  assign \dbus_req_o[stb]  = n846; //(module output)
  assign \dbus_req_o[rw]  = n847; //(module output)
  assign \dbus_req_o[amo]  = n848; //(module output)
  assign \dbus_req_o[amoop]  = n849; //(module output)
  assign \dbus_req_o[burst]  = n850; //(module output)
  assign \dbus_req_o[lock]  = n851; //(module output)
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n798 = n1115[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n799 = n1115[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n800 = n1115[64:33]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n801 = n1115[65]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n802 = n1115[66]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n803 = n1115[67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n804 = n1115[69:68]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n805 = n1115[71:70]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n806 = n1115[72]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n807 = n1115[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n808 = n1115[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n809 = n1115[106:75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n810 = n1115[111:107]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n811 = n1115[116:112]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n812 = n1115[148:117]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n813 = n1115[180:149]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n814 = n1115[185:181]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n815 = n1115[217:186]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n816 = n1115[249:218]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n817 = n1115[281:250]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n818 = n1115[293:282]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n819 = n1115[325:294]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n820 = n1115[357:326]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n821 = n1115[389:358]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n822 = n1115[393:390]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n823 = n1115[397:394]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n824 = n1115[429:398]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n825 = n1115[461:430]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n829 = n943[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n830 = n943[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n831 = n943[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n832 = n943[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n833 = n943[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n834 = n943[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n835 = n943[75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n836 = n943[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n837 = n943[80]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n838 = n943[81]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n839 = {\ibus_rsp_i[data] , \ibus_rsp_i[err] , \ibus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n842 = dbus_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n843 = dbus_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n844 = dbus_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n845 = dbus_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n846 = dbus_req[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n847 = dbus_req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n848 = dbus_req[75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n849 = dbus_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n850 = dbus_req[80]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n851 = dbus_req[81]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n852 = {\dbus_rsp_i[data] , \dbus_rsp_i[err] , \dbus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu.vhd:121:10 */
  assign ctrl = n952; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:122:10 */
  assign frontend = n950; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:123:10 */
  assign dbus_req = n1107; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:128:10 */
  assign if_pmp_err = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:129:10 */
  assign rw_pmp_err = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:130:10 */
  assign hwtrig = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:131:10 */
  assign rf_wdata = n1017; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:143:10 */
  assign irq_machine = n961; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:10 */
  assign xcsr_tm = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:19 */
  assign xcsr_cnt = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:29 */
  assign xcsr_pmp = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:49 */
  assign xcsr_res = n964; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  neorv32_cpu_frontend_Bneorv32_cpu_frontend_rtl_Lneorv32_0_9508e90548b0440a4a61e5743b76c1e309b23b7f neorv32_cpu_frontend_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n903),
    .\ctrl_i[if_ready] (n904),
    .\ctrl_i[if_fence] (n905),
    .\ctrl_i[pc_cur] (n906),
    .\ctrl_i[pc_nxt] (n907),
    .\ctrl_i[pc_ret] (n908),
    .\ctrl_i[rf_wb_en] (n909),
    .\ctrl_i[rf_rs1] (n910),
    .\ctrl_i[rf_rs2] (n911),
    .\ctrl_i[rf_rd] (n912),
    .\ctrl_i[rf_zero] (n913),
    .\ctrl_i[alu_op] (n914),
    .\ctrl_i[alu_sub] (n915),
    .\ctrl_i[alu_opa_mux] (n916),
    .\ctrl_i[alu_opb_mux] (n917),
    .\ctrl_i[alu_unsigned] (n918),
    .\ctrl_i[alu_imm] (n919),
    .\ctrl_i[alu_cp_alu] (n920),
    .\ctrl_i[alu_cp_cfu] (n921),
    .\ctrl_i[alu_cp_fpu] (n922),
    .\ctrl_i[lsu_req] (n923),
    .\ctrl_i[lsu_rd] (n924),
    .\ctrl_i[lsu_wr] (n925),
    .\ctrl_i[lsu_mo_en] (n926),
    .\ctrl_i[lsu_mi_en] (n927),
    .\ctrl_i[lsu_priv] (n928),
    .\ctrl_i[lsu_fence] (n929),
    .\ctrl_i[csr_we] (n930),
    .\ctrl_i[csr_re] (n931),
    .\ctrl_i[csr_addr] (n932),
    .\ctrl_i[csr_wdata] (n933),
    .\ctrl_i[cnt_event] (n934),
    .\ctrl_i[ir_funct3] (n935),
    .\ctrl_i[ir_funct12] (n936),
    .\ctrl_i[ir_opcode] (n937),
    .\ctrl_i[ir_rvc] (n938),
    .\ctrl_i[cpu_priv] (n939),
    .\ctrl_i[cpu_trap] (n940),
    .\ctrl_i[cpu_sync_exc] (n941),
    .\ctrl_i[cpu_debug] (n942),
    .\ibus_rsp_i[ack] (n945),
    .\ibus_rsp_i[err] (n946),
    .\ibus_rsp_i[data] (n947),
    .pmp_err_i(if_pmp_err),
    .\ibus_req_o[meta] (\neorv32_cpu_frontend_inst.ibus_req_o[meta] ),
    .\ibus_req_o[addr] (\neorv32_cpu_frontend_inst.ibus_req_o[addr] ),
    .\ibus_req_o[data] (\neorv32_cpu_frontend_inst.ibus_req_o[data] ),
    .\ibus_req_o[ben] (\neorv32_cpu_frontend_inst.ibus_req_o[ben] ),
    .\ibus_req_o[stb] (\neorv32_cpu_frontend_inst.ibus_req_o[stb] ),
    .\ibus_req_o[rw] (\neorv32_cpu_frontend_inst.ibus_req_o[rw] ),
    .\ibus_req_o[amo] (\neorv32_cpu_frontend_inst.ibus_req_o[amo] ),
    .\ibus_req_o[amoop] (\neorv32_cpu_frontend_inst.ibus_req_o[amoop] ),
    .\ibus_req_o[burst] (\neorv32_cpu_frontend_inst.ibus_req_o[burst] ),
    .\ibus_req_o[lock] (\neorv32_cpu_frontend_inst.ibus_req_o[lock] ),
    .pmp_addr_o(),
    .pmp_priv_o(),
    .\frontend_o[valid] (\neorv32_cpu_frontend_inst.frontend_o[valid] ),
    .\frontend_o[i32] (\neorv32_cpu_frontend_inst.frontend_o[i32] ),
    .\frontend_o[i16] (\neorv32_cpu_frontend_inst.frontend_o[i16] ),
    .\frontend_o[compr] (\neorv32_cpu_frontend_inst.frontend_o[compr] ),
    .\frontend_o[fault] (\neorv32_cpu_frontend_inst.frontend_o[fault] ));
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n903 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n904 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n905 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n906 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n907 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n908 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n909 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n910 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n911 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n912 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n913 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n914 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n915 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n916 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n917 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n918 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n919 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n920 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n921 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n922 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n923 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n924 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n925 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n926 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n927 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n928 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n929 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n930 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n931 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n932 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n933 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n934 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n935 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n936 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n937 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n938 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n939 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n940 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n941 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n942 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n943 = {\neorv32_cpu_frontend_inst.ibus_req_o[lock] , \neorv32_cpu_frontend_inst.ibus_req_o[burst] , \neorv32_cpu_frontend_inst.ibus_req_o[amoop] , \neorv32_cpu_frontend_inst.ibus_req_o[amo] , \neorv32_cpu_frontend_inst.ibus_req_o[rw] , \neorv32_cpu_frontend_inst.ibus_req_o[stb] , \neorv32_cpu_frontend_inst.ibus_req_o[ben] , \neorv32_cpu_frontend_inst.ibus_req_o[data] , \neorv32_cpu_frontend_inst.ibus_req_o[addr] , \neorv32_cpu_frontend_inst.ibus_req_o[meta] };
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n945 = n839[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n946 = n839[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n947 = n839[33:2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n950 = {\neorv32_cpu_frontend_inst.frontend_o[fault] , \neorv32_cpu_frontend_inst.frontend_o[compr] , \neorv32_cpu_frontend_inst.frontend_o[i16] , \neorv32_cpu_frontend_inst.frontend_o[i32] , \neorv32_cpu_frontend_inst.frontend_o[valid] };
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  neorv32_cpu_control_Bneorv32_cpu_control_rtl_Lneorv32_0_4276033fa0415472228fc3f7d7c8a0a76b50f4af neorv32_cpu_control_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\frontend_i[valid] (n954),
    .\frontend_i[i32] (n955),
    .\frontend_i[i16] (n956),
    .\frontend_i[compr] (n957),
    .\frontend_i[fault] (n958),
    .hwtrig_i(hwtrig),
    .alu_cp_done_i(alu_cp_done),
    .alu_cmp_i(alu_cmp),
    .alu_add_i(alu_add),
    .rf_rs1_i(rs1),
    .xcsr_rdata_i(xcsr_res),
    .irq_dbg_i(dbi_i),
    .irq_machine_i(irq_machine),
    .irq_fast_i(firq_i),
    .lsu_wait_i(lsu_wait),
    .lsu_mar_i(lsu_mar),
    .lsu_err_i(lsu_err),
    .\ctrl_o[if_reset] (\neorv32_cpu_control_inst.ctrl_o[if_reset] ),
    .\ctrl_o[if_ready] (\neorv32_cpu_control_inst.ctrl_o[if_ready] ),
    .\ctrl_o[if_fence] (\neorv32_cpu_control_inst.ctrl_o[if_fence] ),
    .\ctrl_o[pc_cur] (\neorv32_cpu_control_inst.ctrl_o[pc_cur] ),
    .\ctrl_o[pc_nxt] (\neorv32_cpu_control_inst.ctrl_o[pc_nxt] ),
    .\ctrl_o[pc_ret] (\neorv32_cpu_control_inst.ctrl_o[pc_ret] ),
    .\ctrl_o[rf_wb_en] (\neorv32_cpu_control_inst.ctrl_o[rf_wb_en] ),
    .\ctrl_o[rf_rs1] (\neorv32_cpu_control_inst.ctrl_o[rf_rs1] ),
    .\ctrl_o[rf_rs2] (\neorv32_cpu_control_inst.ctrl_o[rf_rs2] ),
    .\ctrl_o[rf_rd] (\neorv32_cpu_control_inst.ctrl_o[rf_rd] ),
    .\ctrl_o[rf_zero] (\neorv32_cpu_control_inst.ctrl_o[rf_zero] ),
    .\ctrl_o[alu_op] (\neorv32_cpu_control_inst.ctrl_o[alu_op] ),
    .\ctrl_o[alu_sub] (\neorv32_cpu_control_inst.ctrl_o[alu_sub] ),
    .\ctrl_o[alu_opa_mux] (\neorv32_cpu_control_inst.ctrl_o[alu_opa_mux] ),
    .\ctrl_o[alu_opb_mux] (\neorv32_cpu_control_inst.ctrl_o[alu_opb_mux] ),
    .\ctrl_o[alu_unsigned] (\neorv32_cpu_control_inst.ctrl_o[alu_unsigned] ),
    .\ctrl_o[alu_imm] (\neorv32_cpu_control_inst.ctrl_o[alu_imm] ),
    .\ctrl_o[alu_cp_alu] (\neorv32_cpu_control_inst.ctrl_o[alu_cp_alu] ),
    .\ctrl_o[alu_cp_cfu] (\neorv32_cpu_control_inst.ctrl_o[alu_cp_cfu] ),
    .\ctrl_o[alu_cp_fpu] (\neorv32_cpu_control_inst.ctrl_o[alu_cp_fpu] ),
    .\ctrl_o[lsu_req] (\neorv32_cpu_control_inst.ctrl_o[lsu_req] ),
    .\ctrl_o[lsu_rd] (\neorv32_cpu_control_inst.ctrl_o[lsu_rd] ),
    .\ctrl_o[lsu_wr] (\neorv32_cpu_control_inst.ctrl_o[lsu_wr] ),
    .\ctrl_o[lsu_mo_en] (\neorv32_cpu_control_inst.ctrl_o[lsu_mo_en] ),
    .\ctrl_o[lsu_mi_en] (\neorv32_cpu_control_inst.ctrl_o[lsu_mi_en] ),
    .\ctrl_o[lsu_priv] (\neorv32_cpu_control_inst.ctrl_o[lsu_priv] ),
    .\ctrl_o[lsu_fence] (\neorv32_cpu_control_inst.ctrl_o[lsu_fence] ),
    .\ctrl_o[csr_we] (\neorv32_cpu_control_inst.ctrl_o[csr_we] ),
    .\ctrl_o[csr_re] (\neorv32_cpu_control_inst.ctrl_o[csr_re] ),
    .\ctrl_o[csr_addr] (\neorv32_cpu_control_inst.ctrl_o[csr_addr] ),
    .\ctrl_o[csr_wdata] (\neorv32_cpu_control_inst.ctrl_o[csr_wdata] ),
    .\ctrl_o[cnt_event] (\neorv32_cpu_control_inst.ctrl_o[cnt_event] ),
    .\ctrl_o[ir_funct3] (\neorv32_cpu_control_inst.ctrl_o[ir_funct3] ),
    .\ctrl_o[ir_funct12] (\neorv32_cpu_control_inst.ctrl_o[ir_funct12] ),
    .\ctrl_o[ir_opcode] (\neorv32_cpu_control_inst.ctrl_o[ir_opcode] ),
    .\ctrl_o[ir_rvc] (\neorv32_cpu_control_inst.ctrl_o[ir_rvc] ),
    .\ctrl_o[cpu_priv] (\neorv32_cpu_control_inst.ctrl_o[cpu_priv] ),
    .\ctrl_o[cpu_trap] (\neorv32_cpu_control_inst.ctrl_o[cpu_trap] ),
    .\ctrl_o[cpu_sync_exc] (\neorv32_cpu_control_inst.ctrl_o[cpu_sync_exc] ),
    .\ctrl_o[cpu_debug] (\neorv32_cpu_control_inst.ctrl_o[cpu_debug] ),
    .csr_rdata_o(csr_rdata));
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n952 = {\neorv32_cpu_control_inst.ctrl_o[cpu_debug] , \neorv32_cpu_control_inst.ctrl_o[cpu_sync_exc] , \neorv32_cpu_control_inst.ctrl_o[cpu_trap] , \neorv32_cpu_control_inst.ctrl_o[cpu_priv] , \neorv32_cpu_control_inst.ctrl_o[ir_rvc] , \neorv32_cpu_control_inst.ctrl_o[ir_opcode] , \neorv32_cpu_control_inst.ctrl_o[ir_funct12] , \neorv32_cpu_control_inst.ctrl_o[ir_funct3] , \neorv32_cpu_control_inst.ctrl_o[cnt_event] , \neorv32_cpu_control_inst.ctrl_o[csr_wdata] , \neorv32_cpu_control_inst.ctrl_o[csr_addr] , \neorv32_cpu_control_inst.ctrl_o[csr_re] , \neorv32_cpu_control_inst.ctrl_o[csr_we] , \neorv32_cpu_control_inst.ctrl_o[lsu_fence] , \neorv32_cpu_control_inst.ctrl_o[lsu_priv] , \neorv32_cpu_control_inst.ctrl_o[lsu_mi_en] , \neorv32_cpu_control_inst.ctrl_o[lsu_mo_en] , \neorv32_cpu_control_inst.ctrl_o[lsu_wr] , \neorv32_cpu_control_inst.ctrl_o[lsu_rd] , \neorv32_cpu_control_inst.ctrl_o[lsu_req] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_fpu] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_cfu] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_alu] , \neorv32_cpu_control_inst.ctrl_o[alu_imm] , \neorv32_cpu_control_inst.ctrl_o[alu_unsigned] , \neorv32_cpu_control_inst.ctrl_o[alu_opb_mux] , \neorv32_cpu_control_inst.ctrl_o[alu_opa_mux] , \neorv32_cpu_control_inst.ctrl_o[alu_sub] , \neorv32_cpu_control_inst.ctrl_o[alu_op] , \neorv32_cpu_control_inst.ctrl_o[rf_zero] , \neorv32_cpu_control_inst.ctrl_o[rf_rd] , \neorv32_cpu_control_inst.ctrl_o[rf_rs2] , \neorv32_cpu_control_inst.ctrl_o[rf_rs1] , \neorv32_cpu_control_inst.ctrl_o[rf_wb_en] , \neorv32_cpu_control_inst.ctrl_o[pc_ret] , \neorv32_cpu_control_inst.ctrl_o[pc_nxt] , \neorv32_cpu_control_inst.ctrl_o[pc_cur] , \neorv32_cpu_control_inst.ctrl_o[if_fence] , \neorv32_cpu_control_inst.ctrl_o[if_ready] , \neorv32_cpu_control_inst.ctrl_o[if_reset] };
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n954 = frontend[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n955 = frontend[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n956 = frontend[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n957 = frontend[49]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n958 = frontend[50]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:325:24 */
  assign n960 = {mei_i, mti_i};
  /*# ../../rtl/core/neorv32_cpu.vhd:325:32 */
  assign n961 = {n960, msi_i};
  /*# ../../rtl/core/neorv32_cpu.vhd:328:23 */
  assign n962 = xcsr_tm | xcsr_cnt;
  /*# ../../rtl/core/neorv32_cpu.vhd:328:35 */
  assign n963 = n962 | xcsr_alu;
  /*# ../../rtl/core/neorv32_cpu.vhd:328:47 */
  assign n964 = n963 | xcsr_pmp;
  /*# ../../rtl/core/neorv32_cpu.vhd:331:32 */
  assign n965 = ctrl[211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:331:14 */
  assign n966 = ~n965;
  /*# ../../rtl/core/neorv32_cpu.vhd:334:20 */
  assign n967 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:335:20 */
  assign n968 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  neorv32_cpu_regfile_Bneorv32_cpu_regfile_rtl_Lneorv32_32_5_0 neorv32_cpu_regfile_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n972),
    .\ctrl_i[if_ready] (n973),
    .\ctrl_i[if_fence] (n974),
    .\ctrl_i[pc_cur] (n975),
    .\ctrl_i[pc_nxt] (n976),
    .\ctrl_i[pc_ret] (n977),
    .\ctrl_i[rf_wb_en] (n978),
    .\ctrl_i[rf_rs1] (n979),
    .\ctrl_i[rf_rs2] (n980),
    .\ctrl_i[rf_rd] (n981),
    .\ctrl_i[rf_zero] (n982),
    .\ctrl_i[alu_op] (n983),
    .\ctrl_i[alu_sub] (n984),
    .\ctrl_i[alu_opa_mux] (n985),
    .\ctrl_i[alu_opb_mux] (n986),
    .\ctrl_i[alu_unsigned] (n987),
    .\ctrl_i[alu_imm] (n988),
    .\ctrl_i[alu_cp_alu] (n989),
    .\ctrl_i[alu_cp_cfu] (n990),
    .\ctrl_i[alu_cp_fpu] (n991),
    .\ctrl_i[lsu_req] (n992),
    .\ctrl_i[lsu_rd] (n993),
    .\ctrl_i[lsu_wr] (n994),
    .\ctrl_i[lsu_mo_en] (n995),
    .\ctrl_i[lsu_mi_en] (n996),
    .\ctrl_i[lsu_priv] (n997),
    .\ctrl_i[lsu_fence] (n998),
    .\ctrl_i[csr_we] (n999),
    .\ctrl_i[csr_re] (n1000),
    .\ctrl_i[csr_addr] (n1001),
    .\ctrl_i[csr_wdata] (n1002),
    .\ctrl_i[cnt_event] (n1003),
    .\ctrl_i[ir_funct3] (n1004),
    .\ctrl_i[ir_funct12] (n1005),
    .\ctrl_i[ir_opcode] (n1006),
    .\ctrl_i[ir_rvc] (n1007),
    .\ctrl_i[cpu_priv] (n1008),
    .\ctrl_i[cpu_trap] (n1009),
    .\ctrl_i[cpu_sync_exc] (n1010),
    .\ctrl_i[cpu_debug] (n1011),
    .rd_i(rf_wdata),
    .rs1_o(rs1),
    .rs2_o(rs2));
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n972 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n973 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n974 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n975 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n976 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n977 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n978 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n979 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n980 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n981 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n982 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n983 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n984 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n985 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n986 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n987 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n988 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n989 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n990 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n991 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n992 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n993 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n994 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n995 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n996 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n997 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n998 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n999 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1000 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1001 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1002 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1003 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1004 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1005 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1006 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1007 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1008 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1009 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1010 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n1011 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:418:23 */
  assign n1014 = alu_res | lsu_rdata;
  /*# ../../rtl/core/neorv32_cpu.vhd:418:36 */
  assign n1015 = n1014 | csr_rdata;
  /*# ../../rtl/core/neorv32_cpu.vhd:418:57 */
  assign n1016 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:418:49 */
  assign n1017 = n1015 | n1016;
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  neorv32_cpu_alu_Bneorv32_cpu_alu_rtl_Lneorv32_f76e51fa32cd911aa74f5a7b915d61ba4b7734d9 neorv32_cpu_alu_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n1018),
    .\ctrl_i[if_ready] (n1019),
    .\ctrl_i[if_fence] (n1020),
    .\ctrl_i[pc_cur] (n1021),
    .\ctrl_i[pc_nxt] (n1022),
    .\ctrl_i[pc_ret] (n1023),
    .\ctrl_i[rf_wb_en] (n1024),
    .\ctrl_i[rf_rs1] (n1025),
    .\ctrl_i[rf_rs2] (n1026),
    .\ctrl_i[rf_rd] (n1027),
    .\ctrl_i[rf_zero] (n1028),
    .\ctrl_i[alu_op] (n1029),
    .\ctrl_i[alu_sub] (n1030),
    .\ctrl_i[alu_opa_mux] (n1031),
    .\ctrl_i[alu_opb_mux] (n1032),
    .\ctrl_i[alu_unsigned] (n1033),
    .\ctrl_i[alu_imm] (n1034),
    .\ctrl_i[alu_cp_alu] (n1035),
    .\ctrl_i[alu_cp_cfu] (n1036),
    .\ctrl_i[alu_cp_fpu] (n1037),
    .\ctrl_i[lsu_req] (n1038),
    .\ctrl_i[lsu_rd] (n1039),
    .\ctrl_i[lsu_wr] (n1040),
    .\ctrl_i[lsu_mo_en] (n1041),
    .\ctrl_i[lsu_mi_en] (n1042),
    .\ctrl_i[lsu_priv] (n1043),
    .\ctrl_i[lsu_fence] (n1044),
    .\ctrl_i[csr_we] (n1045),
    .\ctrl_i[csr_re] (n1046),
    .\ctrl_i[csr_addr] (n1047),
    .\ctrl_i[csr_wdata] (n1048),
    .\ctrl_i[cnt_event] (n1049),
    .\ctrl_i[ir_funct3] (n1050),
    .\ctrl_i[ir_funct12] (n1051),
    .\ctrl_i[ir_opcode] (n1052),
    .\ctrl_i[ir_rvc] (n1053),
    .\ctrl_i[cpu_priv] (n1054),
    .\ctrl_i[cpu_trap] (n1055),
    .\ctrl_i[cpu_sync_exc] (n1056),
    .\ctrl_i[cpu_debug] (n1057),
    .rs1_i(rs1),
    .rs2_i(rs2),
    .cmp_o(alu_cmp),
    .res_o(alu_res),
    .add_o(alu_add),
    .csr_o(xcsr_alu),
    .done_o(alu_cp_done));
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1018 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1019 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1020 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1021 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1022 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1023 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1024 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1025 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1026 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1027 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1028 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1029 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1030 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1031 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1032 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1033 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1034 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1035 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1036 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1037 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1038 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1039 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1040 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1041 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1042 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1043 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1044 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1045 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1046 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1047 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1048 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1049 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1050 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1051 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1052 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1053 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1054 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1055 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1056 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1057 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  neorv32_cpu_lsu_Bneorv32_cpu_lsu_rtl_Lneorv32_0_5ba93c9db0cff93f52b521d7420e43f6eda2784f neorv32_cpu_lsu_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n1063),
    .\ctrl_i[if_ready] (n1064),
    .\ctrl_i[if_fence] (n1065),
    .\ctrl_i[pc_cur] (n1066),
    .\ctrl_i[pc_nxt] (n1067),
    .\ctrl_i[pc_ret] (n1068),
    .\ctrl_i[rf_wb_en] (n1069),
    .\ctrl_i[rf_rs1] (n1070),
    .\ctrl_i[rf_rs2] (n1071),
    .\ctrl_i[rf_rd] (n1072),
    .\ctrl_i[rf_zero] (n1073),
    .\ctrl_i[alu_op] (n1074),
    .\ctrl_i[alu_sub] (n1075),
    .\ctrl_i[alu_opa_mux] (n1076),
    .\ctrl_i[alu_opb_mux] (n1077),
    .\ctrl_i[alu_unsigned] (n1078),
    .\ctrl_i[alu_imm] (n1079),
    .\ctrl_i[alu_cp_alu] (n1080),
    .\ctrl_i[alu_cp_cfu] (n1081),
    .\ctrl_i[alu_cp_fpu] (n1082),
    .\ctrl_i[lsu_req] (n1083),
    .\ctrl_i[lsu_rd] (n1084),
    .\ctrl_i[lsu_wr] (n1085),
    .\ctrl_i[lsu_mo_en] (n1086),
    .\ctrl_i[lsu_mi_en] (n1087),
    .\ctrl_i[lsu_priv] (n1088),
    .\ctrl_i[lsu_fence] (n1089),
    .\ctrl_i[csr_we] (n1090),
    .\ctrl_i[csr_re] (n1091),
    .\ctrl_i[csr_addr] (n1092),
    .\ctrl_i[csr_wdata] (n1093),
    .\ctrl_i[cnt_event] (n1094),
    .\ctrl_i[ir_funct3] (n1095),
    .\ctrl_i[ir_funct12] (n1096),
    .\ctrl_i[ir_opcode] (n1097),
    .\ctrl_i[ir_rvc] (n1098),
    .\ctrl_i[cpu_priv] (n1099),
    .\ctrl_i[cpu_trap] (n1100),
    .\ctrl_i[cpu_sync_exc] (n1101),
    .\ctrl_i[cpu_debug] (n1102),
    .addr_i(alu_add),
    .wdata_i(rs2),
    .pmp_fault_i(rw_pmp_err),
    .\dbus_rsp_i[ack] (n1109),
    .\dbus_rsp_i[err] (n1110),
    .\dbus_rsp_i[data] (n1111),
    .rdata_o(lsu_rdata),
    .mar_o(lsu_mar),
    .wait_o(lsu_wait),
    .err_o(lsu_err),
    .\dbus_req_o[meta] (\neorv32_cpu_lsu_inst.dbus_req_o[meta] ),
    .\dbus_req_o[addr] (\neorv32_cpu_lsu_inst.dbus_req_o[addr] ),
    .\dbus_req_o[data] (\neorv32_cpu_lsu_inst.dbus_req_o[data] ),
    .\dbus_req_o[ben] (\neorv32_cpu_lsu_inst.dbus_req_o[ben] ),
    .\dbus_req_o[stb] (\neorv32_cpu_lsu_inst.dbus_req_o[stb] ),
    .\dbus_req_o[rw] (\neorv32_cpu_lsu_inst.dbus_req_o[rw] ),
    .\dbus_req_o[amo] (\neorv32_cpu_lsu_inst.dbus_req_o[amo] ),
    .\dbus_req_o[amoop] (\neorv32_cpu_lsu_inst.dbus_req_o[amoop] ),
    .\dbus_req_o[burst] (\neorv32_cpu_lsu_inst.dbus_req_o[burst] ),
    .\dbus_req_o[lock] (\neorv32_cpu_lsu_inst.dbus_req_o[lock] ));
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1063 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1064 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1065 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1066 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1067 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1068 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1069 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1070 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1071 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1072 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1073 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1074 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1075 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1076 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1077 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1078 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1079 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1080 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1081 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1082 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1083 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1084 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1085 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1086 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1087 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1088 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1089 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1090 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1091 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1092 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1093 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1094 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1095 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1096 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1097 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1098 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1099 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1100 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1101 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1102 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1107 = {\neorv32_cpu_lsu_inst.dbus_req_o[lock] , \neorv32_cpu_lsu_inst.dbus_req_o[burst] , \neorv32_cpu_lsu_inst.dbus_req_o[amoop] , \neorv32_cpu_lsu_inst.dbus_req_o[amo] , \neorv32_cpu_lsu_inst.dbus_req_o[rw] , \neorv32_cpu_lsu_inst.dbus_req_o[stb] , \neorv32_cpu_lsu_inst.dbus_req_o[ben] , \neorv32_cpu_lsu_inst.dbus_req_o[data] , \neorv32_cpu_lsu_inst.dbus_req_o[addr] , \neorv32_cpu_lsu_inst.dbus_req_o[meta] };
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1109 = n852[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1110 = n852[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1111 = n852[33:2]; // extract
endmodule

module neorv32_sys_clock_Bneorv32_sys_clock_rtl_Lneorv32
  (input  clk_i,
   input  rstn_i,
   input  enable_i,
   output [7:0] clk_en_o);
  wire [11:0] cnt;
  wire [11:0] cnt2;
  wire [11:0] en;
  wire n771;
  wire [11:0] n774;
  wire [11:0] n776;
  wire [11:0] n784;
  wire [11:0] n785;
  wire n786;
  wire n787;
  wire n788;
  wire n789;
  wire n790;
  wire n791;
  wire n792;
  wire n793;
  wire [7:0] n794;
  reg [11:0] n795;
  reg [11:0] n796;
  assign clk_en_o = n794; //(module output)
  /*# ../../rtl/core/neorv32_sys.vhd:108:10 */
  assign cnt = n795; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:108:15 */
  assign cnt2 = n796; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:108:21 */
  assign en = n785; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:115:16 */
  assign n771 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sys.vhd:120:48 */
  assign n774 = cnt + 12'b000000000001;
  /*# ../../rtl/core/neorv32_sys.vhd:119:7 */
  assign n776 = enable_i ? n774 : 12'b000000000000;
  /*# ../../rtl/core/neorv32_sys.vhd:129:18 */
  assign n784 = ~cnt2;
  /*# ../../rtl/core/neorv32_sys.vhd:129:13 */
  assign n785 = cnt & n784;
  /*# ../../rtl/core/neorv32_sys.vhd:132:32 */
  assign n786 = en[0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:133:32 */
  assign n787 = en[1]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:134:32 */
  assign n788 = en[2]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:135:32 */
  assign n789 = en[5]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:136:32 */
  assign n790 = en[6]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:137:32 */
  assign n791 = en[9]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:138:32 */
  assign n792 = en[10]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:139:32 */
  assign n793 = en[11]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:102:5 */
  assign n794 = {n793, n792, n791, n790, n789, n788, n787, n786};
  /*# ../../rtl/core/neorv32_sys.vhd:118:5 */
  always @(posedge clk_i or posedge n771)
    if (n771)
      n795 <= 12'b000000000000;
    else
      n795 <= n776;
  /*# ../../rtl/core/neorv32_sys.vhd:118:5 */
  always @(posedge clk_i or posedge n771)
    if (n771)
      n796 <= 12'b000000000000;
    else
      n796 <= cnt;
endmodule

module neorv32_sys_reset_Bneorv32_sys_reset_rtl_Lneorv32
  (input  clk_i,
   input  rstn_ext_i,
   input  rstn_wdt_i,
   input  rstn_dbg_i,
   output rstn_ext_o,
   output rstn_sys_o,
   output xrstn_wdt_o,
   output xrstn_ocd_o);
  wire [3:0] sreg_ext;
  wire [3:0] sreg_sys;
  wire n695;
  wire [2:0] n697;
  wire [3:0] n699;
  wire n706;
  wire n708;
  wire n710;
  wire n711;
  wire n712;
  wire n713;
  wire n714;
  wire n715;
  wire n716;
  wire n717;
  wire n718;
  wire [2:0] n719;
  wire [3:0] n721;
  wire [3:0] n723;
  wire n730;
  wire n732;
  wire n734;
  wire n735;
  wire n736;
  wire n737;
  wire n738;
  wire n739;
  wire n754;
  reg n763;
  reg n764;
  reg n765;
  reg n766;
  reg [3:0] n767;
  reg [3:0] n768;
  assign rstn_ext_o = n763; //(module output)
  assign rstn_sys_o = n764; //(module output)
  assign xrstn_wdt_o = n765; //(module output)
  assign xrstn_ocd_o = n766; //(module output)
  /*# ../../rtl/core/neorv32_sys.vhd:36:10 */
  assign sreg_ext = n767; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:36:20 */
  assign sreg_sys = n768; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:43:20 */
  assign n695 = ~rstn_ext_i;
  /*# ../../rtl/core/neorv32_sys.vhd:50:29 */
  assign n697 = sreg_ext[2:0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:50:56 */
  assign n699 = {n697, 1'b1};
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n706 = sreg_ext[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n708 = 1'b1 & n706;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n710 = sreg_ext[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n711 = n708 & n710;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n712 = sreg_ext[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n713 = n711 & n712;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n714 = sreg_ext[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n715 = n713 & n714;
  /*# ../../rtl/core/neorv32_sys.vhd:53:22 */
  assign n716 = ~rstn_wdt_i;
  /*# ../../rtl/core/neorv32_sys.vhd:53:44 */
  assign n717 = ~rstn_dbg_i;
  /*# ../../rtl/core/neorv32_sys.vhd:53:29 */
  assign n718 = n716 | n717;
  /*# ../../rtl/core/neorv32_sys.vhd:56:29 */
  assign n719 = sreg_sys[2:0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:56:56 */
  assign n721 = {n719, 1'b1};
  /*# ../../rtl/core/neorv32_sys.vhd:53:7 */
  assign n723 = n718 ? 4'b0000 : n721;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n730 = sreg_sys[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n732 = 1'b1 & n730;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n734 = sreg_sys[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n735 = n732 & n734;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n736 = sreg_sys[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n737 = n735 & n736;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n738 = sreg_sys[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n739 = n737 & n738;
  /*# ../../rtl/core/neorv32_sys.vhd:65:20 */
  assign n754 = ~rstn_ext_i;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n695)
    if (n695)
      n763 <= 1'b0;
    else
      n763 <= n715;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n695)
    if (n695)
      n764 <= 1'b0;
    else
      n764 <= n739;
  /*# ../../rtl/core/neorv32_sys.vhd:68:5 */
  always @(posedge clk_i or posedge n754)
    if (n754)
      n765 <= 1'b0;
    else
      n765 <= rstn_wdt_i;
  /*# ../../rtl/core/neorv32_sys.vhd:68:5 */
  always @(posedge clk_i or posedge n754)
    if (n754)
      n766 <= 1'b0;
    else
      n766 <= rstn_dbg_i;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n695)
    if (n695)
      n767 <= 4'b0000;
    else
      n767 <= n699;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n695)
    if (n695)
      n768 <= 4'b0000;
    else
      n768 <= n723;
endmodule

module neorv32_top_Bneorv32_top_rtl_Lneorv32_100000000_2_0_0_0_4_0_40_16384_16384_4_4_64_2048_0_1_1_1_1_1_1_1_1_1_0_1_3_5_64_1_0_1_4_1_1_1_8ed346acfd2c324525d0386b02501a8d171c513b
  (input  clk_i,
   input  rstn_i,
   output rstn_ocd_o,
   output rstn_wdt_o,
   output \trace_cpu0_o[valid] ,
   output [31:0] \trace_cpu0_o[order] ,
   output [31:0] \trace_cpu0_o[insn] ,
   output \trace_cpu0_o[trap] ,
   output \trace_cpu0_o[halt] ,
   output \trace_cpu0_o[intr] ,
   output [1:0] \trace_cpu0_o[mode] ,
   output [1:0] \trace_cpu0_o[ixl] ,
   output \trace_cpu0_o[debug] ,
   output \trace_cpu0_o[compr] ,
   output \trace_cpu0_o[delta] ,
   output [31:0] \trace_cpu0_o[cmd32] ,
   output [4:0] \trace_cpu0_o[rs1_addr] ,
   output [4:0] \trace_cpu0_o[rs2_addr] ,
   output [31:0] \trace_cpu0_o[rs1_rdata] ,
   output [31:0] \trace_cpu0_o[rs2_rdata] ,
   output [4:0] \trace_cpu0_o[rd_addr] ,
   output [31:0] \trace_cpu0_o[rd_rdata] ,
   output [31:0] \trace_cpu0_o[pc_rdata] ,
   output [31:0] \trace_cpu0_o[pc_wdata] ,
   output [11:0] \trace_cpu0_o[csr_addr] ,
   output [31:0] \trace_cpu0_o[csr_rdata] ,
   output [31:0] \trace_cpu0_o[csr_wdata] ,
   output [31:0] \trace_cpu0_o[mem_addr] ,
   output [3:0] \trace_cpu0_o[mem_rmask] ,
   output [3:0] \trace_cpu0_o[mem_wmask] ,
   output [31:0] \trace_cpu0_o[mem_rdata] ,
   output [31:0] \trace_cpu0_o[mem_wdata] ,
   output \trace_cpu1_o[valid] ,
   output [31:0] \trace_cpu1_o[order] ,
   output [31:0] \trace_cpu1_o[insn] ,
   output \trace_cpu1_o[trap] ,
   output \trace_cpu1_o[halt] ,
   output \trace_cpu1_o[intr] ,
   output [1:0] \trace_cpu1_o[mode] ,
   output [1:0] \trace_cpu1_o[ixl] ,
   output \trace_cpu1_o[debug] ,
   output \trace_cpu1_o[compr] ,
   output \trace_cpu1_o[delta] ,
   output [31:0] \trace_cpu1_o[cmd32] ,
   output [4:0] \trace_cpu1_o[rs1_addr] ,
   output [4:0] \trace_cpu1_o[rs2_addr] ,
   output [31:0] \trace_cpu1_o[rs1_rdata] ,
   output [31:0] \trace_cpu1_o[rs2_rdata] ,
   output [4:0] \trace_cpu1_o[rd_addr] ,
   output [31:0] \trace_cpu1_o[rd_rdata] ,
   output [31:0] \trace_cpu1_o[pc_rdata] ,
   output [31:0] \trace_cpu1_o[pc_wdata] ,
   output [11:0] \trace_cpu1_o[csr_addr] ,
   output [31:0] \trace_cpu1_o[csr_rdata] ,
   output [31:0] \trace_cpu1_o[csr_wdata] ,
   output [31:0] \trace_cpu1_o[mem_addr] ,
   output [3:0] \trace_cpu1_o[mem_rmask] ,
   output [3:0] \trace_cpu1_o[mem_wmask] ,
   output [31:0] \trace_cpu1_o[mem_rdata] ,
   output [31:0] \trace_cpu1_o[mem_wdata] ,
   input  jtag_tck_i,
   input  jtag_tdi_i,
   output jtag_tdo_o,
   input  jtag_tms_i,
   output smc_ioen_o,
   output smc_sck_o,
   output [1:0] smc_csn_o,
   output smc_sdo_o,
   input  smc_sdi_i,
   output [31:0] xbus_adr_o,
   output [31:0] xbus_dat_o,
   output [2:0] xbus_cti_o,
   output [2:0] xbus_tag_o,
   output xbus_we_o,
   output [3:0] xbus_sel_o,
   output xbus_stb_o,
   output xbus_cyc_o,
   input  [31:0] xbus_dat_i,
   input  xbus_ack_i,
   input  xbus_err_i,
   input  [31:0] slink_rx_dat_i,
   input  [3:0] slink_rx_src_i,
   input  slink_rx_val_i,
   input  slink_rx_lst_i,
   output slink_rx_rdy_o,
   output [31:0] slink_tx_dat_o,
   output [3:0] slink_tx_dst_o,
   output slink_tx_val_o,
   output slink_tx_lst_o,
   input  slink_tx_rdy_i,
   output [31:0] gpio_dir_o,
   output [31:0] gpio_o,
   input  [31:0] gpio_i,
   output uart0_txd_o,
   input  uart0_rxd_i,
   output uart0_rtsn_o,
   input  uart0_ctsn_i,
   output uart1_txd_o,
   input  uart1_rxd_i,
   output uart1_rtsn_o,
   input  uart1_ctsn_i,
   output spi_clk_o,
   output spi_dat_o,
   input  spi_dat_i,
   output [7:0] spi_csn_o,
   input  sdi_clk_i,
   output sdi_dat_o,
   input  sdi_dat_i,
   input  sdi_csn_i,
   input  twi_sda_i,
   output twi_sda_o,
   input  twi_scl_i,
   output twi_scl_o,
   input  twd_sda_i,
   output twd_sda_o,
   input  twd_scl_i,
   input  onewire_i,
   output onewire_o,
   output [31:0] pwm_o,
   input  [255:0] cfs_in_i,
   output [255:0] cfs_out_o,
   output neoled_o,
   output [63:0] mtime_time_o,
   input  irq_msi_i,
   input  irq_mti_i,
   input  irq_mei_i);
  wire n129;
  wire [31:0] n130;
  wire [31:0] n131;
  wire n132;
  wire n133;
  wire n134;
  wire [1:0] n135;
  wire [1:0] n136;
  wire n137;
  wire n138;
  wire n139;
  wire [31:0] n140;
  wire [4:0] n141;
  wire [4:0] n142;
  wire [31:0] n143;
  wire [31:0] n144;
  wire [4:0] n145;
  wire [31:0] n146;
  wire [31:0] n147;
  wire [31:0] n148;
  wire [11:0] n149;
  wire [31:0] n150;
  wire [31:0] n151;
  wire [31:0] n152;
  wire [3:0] n153;
  wire [3:0] n154;
  wire [31:0] n155;
  wire [31:0] n156;
  wire n158;
  wire [31:0] n159;
  wire [31:0] n160;
  wire n161;
  wire n162;
  wire n163;
  wire [1:0] n164;
  wire [1:0] n165;
  wire n166;
  wire n167;
  wire n168;
  wire [31:0] n169;
  wire [4:0] n170;
  wire [4:0] n171;
  wire [31:0] n172;
  wire [31:0] n173;
  wire [4:0] n174;
  wire [31:0] n175;
  wire [31:0] n176;
  wire [31:0] n177;
  wire [11:0] n178;
  wire [31:0] n179;
  wire [31:0] n180;
  wire [31:0] n181;
  wire [3:0] n182;
  wire [3:0] n183;
  wire [31:0] n184;
  wire [31:0] n185;
  wire rstn_wdt;
  wire rstn_sys;
  wire [7:0] clk_gen;
  wire dci_ndmrstn;
  wire dci_haltreq;
  wire [461:0] cpu_trace;
  wire [81:0] cpu_i_req;
  wire [81:0] cpu_d_req;
  wire [81:0] icache_req;
  wire [81:0] dcache_req;
  wire [81:0] core_req;
  wire [33:0] cpu_i_rsp;
  wire [33:0] cpu_d_rsp;
  wire [33:0] icache_rsp;
  wire [33:0] dcache_rsp;
  wire [33:0] core_rsp;
  wire [81:0] sys1_req;
  wire [81:0] sys2_req;
  wire [81:0] amo_req;
  wire [81:0] sys3_req;
  wire [81:0] imem_req;
  wire [81:0] dmem_req;
  wire [81:0] io_req;
  wire [81:0] xbus_req;
  wire [33:0] sys1_rsp;
  wire [33:0] sys2_rsp;
  wire [33:0] amo_rsp;
  wire [33:0] sys3_rsp;
  wire [33:0] imem_rsp;
  wire [33:0] dmem_rsp;
  wire [33:0] smc_rsp;
  wire [33:0] io_rsp;
  wire [33:0] xbus_rsp;
  wire xbus_terminate;
  wire [1803:0] iodev_req;
  wire [747:0] iodev_rsp;
  wire [14:0] firq;
  wire [15:0] cpu_firq;
  wire mti;
  wire msi;
  wire [63:0] mtime;
  wire \soc_generators_neorv32_sys_reset_inst.rstn_ext_o ;
  localparam n275 = 1'b1;
  wire n278;
  wire n279;
  wire n280;
  wire n281;
  wire n282;
  wire n283;
  wire n284;
  wire n285;
  wire n286;
  wire n287;
  wire n288;
  wire n289;
  wire n290;
  wire n291;
  wire n292;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[valid] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[order] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[insn] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[trap] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[halt] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[intr] ;
  wire [1:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mode] ;
  wire [1:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[ixl] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[debug] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[compr] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.trace_o[delta] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[cmd32] ;
  wire [4:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_addr] ;
  wire [4:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_rdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_rdata] ;
  wire [4:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_rdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_rdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_wdata] ;
  wire [11:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_rdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_wdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_addr] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rmask] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wmask] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rdata] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wdata] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.sleep_o ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ifence_o ;
  wire [4:0] \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[meta] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[data] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[ben] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[stb] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[rw] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amo] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amoop] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[burst] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[lock] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dfence_o ;
  wire [4:0] \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[meta] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[data] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[ben] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[stb] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[rw] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amo] ;
  wire [3:0] \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amoop] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[burst] ;
  wire \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[lock] ;
  wire [461:0] n293;
  wire [81:0] n296;
  wire n298;
  wire n299;
  wire [31:0] n300;
  wire [81:0] n302;
  wire n304;
  wire n305;
  wire [31:0] n306;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[ack] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[err] ;
  wire [31:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[data] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[ack] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[err] ;
  wire [31:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[data] ;
  wire [4:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[meta] ;
  wire [31:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[addr] ;
  wire [31:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[data] ;
  wire [3:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[ben] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[stb] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[rw] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amo] ;
  wire [3:0] \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amoop] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[burst] ;
  wire \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[lock] ;
  wire [4:0] n309;
  wire [31:0] n310;
  wire [31:0] n311;
  wire [3:0] n312;
  wire n313;
  wire n314;
  wire n315;
  wire [3:0] n316;
  wire n317;
  wire n318;
  wire [33:0] n319;
  wire [4:0] n321;
  wire [31:0] n322;
  wire [31:0] n323;
  wire [3:0] n324;
  wire n325;
  wire n326;
  wire n327;
  wire [3:0] n328;
  wire n329;
  wire n330;
  wire [33:0] n331;
  wire [81:0] n333;
  wire n335;
  wire n336;
  wire [31:0] n337;
  wire [461:0] n339;
  localparam [33:0] n341 = 34'b0000000000000000000000000000000000;
  wire \neorv32_bus_gateway_inst.rsp_o[ack] ;
  wire \neorv32_bus_gateway_inst.rsp_o[err] ;
  wire [31:0] \neorv32_bus_gateway_inst.rsp_o[data] ;
  wire [4:0] \neorv32_bus_gateway_inst.a_req_o[meta] ;
  wire [31:0] \neorv32_bus_gateway_inst.a_req_o[addr] ;
  wire [31:0] \neorv32_bus_gateway_inst.a_req_o[data] ;
  wire [3:0] \neorv32_bus_gateway_inst.a_req_o[ben] ;
  wire \neorv32_bus_gateway_inst.a_req_o[stb] ;
  wire \neorv32_bus_gateway_inst.a_req_o[rw] ;
  wire \neorv32_bus_gateway_inst.a_req_o[amo] ;
  wire [3:0] \neorv32_bus_gateway_inst.a_req_o[amoop] ;
  wire \neorv32_bus_gateway_inst.a_req_o[burst] ;
  wire \neorv32_bus_gateway_inst.a_req_o[lock] ;
  wire [4:0] \neorv32_bus_gateway_inst.b_req_o[meta] ;
  wire [31:0] \neorv32_bus_gateway_inst.b_req_o[addr] ;
  wire [31:0] \neorv32_bus_gateway_inst.b_req_o[data] ;
  wire [3:0] \neorv32_bus_gateway_inst.b_req_o[ben] ;
  wire \neorv32_bus_gateway_inst.b_req_o[stb] ;
  wire \neorv32_bus_gateway_inst.b_req_o[rw] ;
  wire \neorv32_bus_gateway_inst.b_req_o[amo] ;
  wire [3:0] \neorv32_bus_gateway_inst.b_req_o[amoop] ;
  wire \neorv32_bus_gateway_inst.b_req_o[burst] ;
  wire \neorv32_bus_gateway_inst.b_req_o[lock] ;
  wire [4:0] \neorv32_bus_gateway_inst.c_req_o[meta] ;
  wire [31:0] \neorv32_bus_gateway_inst.c_req_o[addr] ;
  wire [31:0] \neorv32_bus_gateway_inst.c_req_o[data] ;
  wire [3:0] \neorv32_bus_gateway_inst.c_req_o[ben] ;
  wire \neorv32_bus_gateway_inst.c_req_o[stb] ;
  wire \neorv32_bus_gateway_inst.c_req_o[rw] ;
  wire \neorv32_bus_gateway_inst.c_req_o[amo] ;
  wire [3:0] \neorv32_bus_gateway_inst.c_req_o[amoop] ;
  wire \neorv32_bus_gateway_inst.c_req_o[burst] ;
  wire \neorv32_bus_gateway_inst.c_req_o[lock] ;
  wire [4:0] \neorv32_bus_gateway_inst.d_req_o[meta] ;
  wire [31:0] \neorv32_bus_gateway_inst.d_req_o[addr] ;
  wire [31:0] \neorv32_bus_gateway_inst.d_req_o[data] ;
  wire [3:0] \neorv32_bus_gateway_inst.d_req_o[ben] ;
  wire \neorv32_bus_gateway_inst.d_req_o[stb] ;
  wire \neorv32_bus_gateway_inst.d_req_o[rw] ;
  wire \neorv32_bus_gateway_inst.d_req_o[amo] ;
  wire [3:0] \neorv32_bus_gateway_inst.d_req_o[amoop] ;
  wire \neorv32_bus_gateway_inst.d_req_o[burst] ;
  wire \neorv32_bus_gateway_inst.d_req_o[lock] ;
  wire [4:0] \neorv32_bus_gateway_inst.x_req_o[meta] ;
  wire [31:0] \neorv32_bus_gateway_inst.x_req_o[addr] ;
  wire [31:0] \neorv32_bus_gateway_inst.x_req_o[data] ;
  wire [3:0] \neorv32_bus_gateway_inst.x_req_o[ben] ;
  wire \neorv32_bus_gateway_inst.x_req_o[stb] ;
  wire \neorv32_bus_gateway_inst.x_req_o[rw] ;
  wire \neorv32_bus_gateway_inst.x_req_o[amo] ;
  wire [3:0] \neorv32_bus_gateway_inst.x_req_o[amoop] ;
  wire \neorv32_bus_gateway_inst.x_req_o[burst] ;
  wire \neorv32_bus_gateway_inst.x_req_o[lock] ;
  wire [4:0] n346;
  wire [31:0] n347;
  wire [31:0] n348;
  wire [3:0] n349;
  wire n350;
  wire n351;
  wire n352;
  wire [3:0] n353;
  wire n354;
  wire n355;
  wire [33:0] n356;
  wire [81:0] n358;
  wire n360;
  wire n361;
  wire [31:0] n362;
  wire [81:0] n363;
  wire n365;
  wire n366;
  wire [31:0] n367;
  wire n370;
  wire n371;
  wire [31:0] n372;
  wire [81:0] n373;
  wire n375;
  wire n376;
  wire [31:0] n377;
  wire [81:0] n378;
  wire n380;
  wire n381;
  wire [31:0] n382;
  wire \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] ;
  wire \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] ;
  wire [31:0] \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] ;
  wire [4:0] n383;
  wire [31:0] n384;
  wire [31:0] n385;
  wire [3:0] n386;
  wire n387;
  wire n388;
  wire n389;
  wire [3:0] n390;
  wire n391;
  wire n392;
  wire [33:0] n393;
  wire \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] ;
  wire \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] ;
  wire [31:0] \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] ;
  wire [4:0] n395;
  wire [31:0] n396;
  wire [31:0] n397;
  wire [3:0] n398;
  wire n399;
  wire n400;
  wire n401;
  wire [3:0] n402;
  wire n403;
  wire n404;
  wire [33:0] n405;
  localparam n408 = 1'b0;
  localparam n409 = 1'b0;
  localparam [1:0] n410 = 2'b11;
  localparam n411 = 1'b0;
  wire \memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[ack] ;
  wire \memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[err] ;
  wire [31:0] \memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[data] ;
  wire [4:0] n412;
  wire [31:0] n413;
  wire [31:0] n414;
  wire [3:0] n415;
  wire n416;
  wire n417;
  wire n418;
  wire [3:0] n419;
  wire n420;
  wire n421;
  wire [33:0] n422;
  wire \io_system_neorv32_bus_io_switch_inst.main_rsp_o[ack] ;
  wire \io_system_neorv32_bus_io_switch_inst.main_rsp_o[err] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.main_rsp_o[data] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_01_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_02_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_03_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_04_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_05_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_06_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_07_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_08_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_09_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_14_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[lock] ;
  wire [4:0] \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[meta] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[addr] ;
  wire [31:0] \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[data] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[ben] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[stb] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[rw] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amo] ;
  wire [3:0] \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amoop] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[burst] ;
  wire \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[lock] ;
  wire [4:0] n432;
  wire [31:0] n433;
  wire [31:0] n434;
  wire [3:0] n435;
  wire n436;
  wire n437;
  wire n438;
  wire [3:0] n439;
  wire n440;
  wire n441;
  wire [33:0] n442;
  wire [81:0] n444;
  wire n447;
  wire n448;
  wire [31:0] n449;
  wire n451;
  wire n452;
  wire [31:0] n453;
  wire n455;
  wire n456;
  wire [31:0] n457;
  wire n459;
  wire n460;
  wire [31:0] n461;
  wire n463;
  wire n464;
  wire [31:0] n465;
  wire n467;
  wire n468;
  wire [31:0] n469;
  wire n471;
  wire n472;
  wire [31:0] n473;
  wire n475;
  wire n476;
  wire [31:0] n477;
  wire n479;
  wire n480;
  wire [31:0] n481;
  wire n483;
  wire n484;
  wire [31:0] n485;
  wire [81:0] n486;
  wire n489;
  wire n490;
  wire [31:0] n491;
  wire [81:0] n492;
  wire n495;
  wire n496;
  wire [31:0] n497;
  wire [81:0] n498;
  wire n501;
  wire n502;
  wire [31:0] n503;
  wire [81:0] n504;
  wire n507;
  wire n508;
  wire [31:0] n509;
  wire n511;
  wire n512;
  wire [31:0] n513;
  wire [81:0] n514;
  wire n517;
  wire n518;
  wire [31:0] n519;
  wire [81:0] n520;
  wire n523;
  wire n524;
  wire [31:0] n525;
  wire [81:0] n526;
  wire n529;
  wire n530;
  wire [31:0] n531;
  wire [81:0] n532;
  wire n535;
  wire n536;
  wire [31:0] n537;
  wire [81:0] n538;
  wire n541;
  wire n542;
  wire [31:0] n543;
  wire [81:0] n544;
  wire n547;
  wire n548;
  wire [31:0] n549;
  wire [81:0] n550;
  wire n553;
  wire n554;
  wire [31:0] n555;
  wire [81:0] n556;
  wire n559;
  wire n560;
  wire [31:0] n561;
  wire [81:0] n562;
  wire n565;
  wire n566;
  wire [31:0] n567;
  wire [81:0] n568;
  wire n571;
  wire n572;
  wire [31:0] n573;
  wire [81:0] n574;
  wire n577;
  wire n578;
  wire [31:0] n579;
  wire [81:0] n580;
  wire n583;
  wire n584;
  wire [31:0] n585;
  wire [81:0] n586;
  wire n589;
  wire n590;
  wire [31:0] n591;
  wire [81:0] n592;
  wire n595;
  wire n596;
  wire [31:0] n597;
  wire [81:0] n598;
  wire n601;
  wire n602;
  wire [31:0] n603;
  wire [81:0] n604;
  wire n607;
  wire n608;
  wire [31:0] n609;
  wire [81:0] n610;
  wire n613;
  wire n614;
  wire [31:0] n615;
  localparam [255:0] n617 = 256'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  localparam n618 = 1'b0;
  localparam [31:0] n620 = 32'b00000000000000000000000000000000;
  localparam [31:0] n621 = 32'b00000000000000000000000000000000;
  localparam [63:0] n626 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[ack] ;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[err] ;
  wire [31:0] \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[data] ;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.irq_o ;
  wire [4:0] n628;
  wire [31:0] n629;
  wire [31:0] n630;
  wire [3:0] n631;
  wire n632;
  wire n633;
  wire n634;
  wire [3:0] n635;
  wire n636;
  wire n637;
  wire [33:0] n638;
  localparam n643 = 1'b0;
  localparam n644 = 1'b1;
  localparam n646 = 1'b0;
  localparam n647 = 1'b0;
  localparam [7:0] n648 = 8'b11111111;
  localparam n650 = 1'b1;
  localparam n651 = 1'b1;
  localparam n653 = 1'b1;
  localparam [31:0] n655 = 32'b00000000000000000000000000000000;
  localparam n658 = 1'b0;
  localparam n660 = 1'b1;
  localparam n663 = 1'b0;
  localparam [31:0] n664 = 32'b00000000000000000000000000000000;
  localparam [3:0] n665 = 4'b0000;
  localparam n666 = 1'b0;
  localparam n667 = 1'b0;
  wire \io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] ;
  wire \io_system_neorv32_sysinfo_inst.bus_rsp_o[err] ;
  wire [31:0] \io_system_neorv32_sysinfo_inst.bus_rsp_o[data] ;
  wire [4:0] n670;
  wire [31:0] n671;
  wire [31:0] n672;
  wire [3:0] n673;
  wire n674;
  wire n675;
  wire n676;
  wire [3:0] n677;
  wire n678;
  wire n679;
  wire [33:0] n680;
  wire [1803:0] n686;
  wire [747:0] n687;
  wire [14:0] n688;
  wire [15:0] n689;
  assign \trace_cpu0_o[valid]  = n129; //(module output)
  assign \trace_cpu0_o[order]  = n130; //(module output)
  assign \trace_cpu0_o[insn]  = n131; //(module output)
  assign \trace_cpu0_o[trap]  = n132; //(module output)
  assign \trace_cpu0_o[halt]  = n133; //(module output)
  assign \trace_cpu0_o[intr]  = n134; //(module output)
  assign \trace_cpu0_o[mode]  = n135; //(module output)
  assign \trace_cpu0_o[ixl]  = n136; //(module output)
  assign \trace_cpu0_o[debug]  = n137; //(module output)
  assign \trace_cpu0_o[compr]  = n138; //(module output)
  assign \trace_cpu0_o[delta]  = n139; //(module output)
  assign \trace_cpu0_o[cmd32]  = n140; //(module output)
  assign \trace_cpu0_o[rs1_addr]  = n141; //(module output)
  assign \trace_cpu0_o[rs2_addr]  = n142; //(module output)
  assign \trace_cpu0_o[rs1_rdata]  = n143; //(module output)
  assign \trace_cpu0_o[rs2_rdata]  = n144; //(module output)
  assign \trace_cpu0_o[rd_addr]  = n145; //(module output)
  assign \trace_cpu0_o[rd_rdata]  = n146; //(module output)
  assign \trace_cpu0_o[pc_rdata]  = n147; //(module output)
  assign \trace_cpu0_o[pc_wdata]  = n148; //(module output)
  assign \trace_cpu0_o[csr_addr]  = n149; //(module output)
  assign \trace_cpu0_o[csr_rdata]  = n150; //(module output)
  assign \trace_cpu0_o[csr_wdata]  = n151; //(module output)
  assign \trace_cpu0_o[mem_addr]  = n152; //(module output)
  assign \trace_cpu0_o[mem_rmask]  = n153; //(module output)
  assign \trace_cpu0_o[mem_wmask]  = n154; //(module output)
  assign \trace_cpu0_o[mem_rdata]  = n155; //(module output)
  assign \trace_cpu0_o[mem_wdata]  = n156; //(module output)
  assign \trace_cpu1_o[valid]  = n158; //(module output)
  assign \trace_cpu1_o[order]  = n159; //(module output)
  assign \trace_cpu1_o[insn]  = n160; //(module output)
  assign \trace_cpu1_o[trap]  = n161; //(module output)
  assign \trace_cpu1_o[halt]  = n162; //(module output)
  assign \trace_cpu1_o[intr]  = n163; //(module output)
  assign \trace_cpu1_o[mode]  = n164; //(module output)
  assign \trace_cpu1_o[ixl]  = n165; //(module output)
  assign \trace_cpu1_o[debug]  = n166; //(module output)
  assign \trace_cpu1_o[compr]  = n167; //(module output)
  assign \trace_cpu1_o[delta]  = n168; //(module output)
  assign \trace_cpu1_o[cmd32]  = n169; //(module output)
  assign \trace_cpu1_o[rs1_addr]  = n170; //(module output)
  assign \trace_cpu1_o[rs2_addr]  = n171; //(module output)
  assign \trace_cpu1_o[rs1_rdata]  = n172; //(module output)
  assign \trace_cpu1_o[rs2_rdata]  = n173; //(module output)
  assign \trace_cpu1_o[rd_addr]  = n174; //(module output)
  assign \trace_cpu1_o[rd_rdata]  = n175; //(module output)
  assign \trace_cpu1_o[pc_rdata]  = n176; //(module output)
  assign \trace_cpu1_o[pc_wdata]  = n177; //(module output)
  assign \trace_cpu1_o[csr_addr]  = n178; //(module output)
  assign \trace_cpu1_o[csr_rdata]  = n179; //(module output)
  assign \trace_cpu1_o[csr_wdata]  = n180; //(module output)
  assign \trace_cpu1_o[mem_addr]  = n181; //(module output)
  assign \trace_cpu1_o[mem_rmask]  = n182; //(module output)
  assign \trace_cpu1_o[mem_wmask]  = n183; //(module output)
  assign \trace_cpu1_o[mem_rdata]  = n184; //(module output)
  assign \trace_cpu1_o[mem_wdata]  = n185; //(module output)
  assign jtag_tdo_o = jtag_tdi_i; //(module output)
  assign smc_ioen_o = n408; //(module output)
  assign smc_sck_o = n409; //(module output)
  assign smc_csn_o = n410; //(module output)
  assign smc_sdo_o = n411; //(module output)
  assign slink_rx_rdy_o = n663; //(module output)
  assign slink_tx_dat_o = n664; //(module output)
  assign slink_tx_dst_o = n665; //(module output)
  assign slink_tx_val_o = n666; //(module output)
  assign slink_tx_lst_o = n667; //(module output)
  assign gpio_dir_o = n620; //(module output)
  assign gpio_o = n621; //(module output)
  assign uart1_txd_o = n643; //(module output)
  assign uart1_rtsn_o = n644; //(module output)
  assign spi_clk_o = n646; //(module output)
  assign spi_dat_o = n647; //(module output)
  assign spi_csn_o = n648; //(module output)
  assign sdi_dat_o = n618; //(module output)
  assign twi_sda_o = n650; //(module output)
  assign twi_scl_o = n651; //(module output)
  assign twd_sda_o = n653; //(module output)
  assign onewire_o = n660; //(module output)
  assign pwm_o = n655; //(module output)
  assign cfs_out_o = n617; //(module output)
  assign neoled_o = n658; //(module output)
  assign mtime_time_o = n626; //(module output)
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n129 = cpu_trace[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n130 = cpu_trace[32:1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n131 = cpu_trace[64:33]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n132 = cpu_trace[65]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n133 = cpu_trace[66]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n134 = cpu_trace[67]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n135 = cpu_trace[69:68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n136 = cpu_trace[71:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n137 = cpu_trace[72]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n138 = cpu_trace[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n139 = cpu_trace[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n140 = cpu_trace[106:75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n141 = cpu_trace[111:107]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n142 = cpu_trace[116:112]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n143 = cpu_trace[148:117]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n144 = cpu_trace[180:149]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n145 = cpu_trace[185:181]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n146 = cpu_trace[217:186]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n147 = cpu_trace[249:218]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n148 = cpu_trace[281:250]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n149 = cpu_trace[293:282]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n150 = cpu_trace[325:294]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n151 = cpu_trace[357:326]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n152 = cpu_trace[389:358]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n153 = cpu_trace[393:390]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n154 = cpu_trace[397:394]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n155 = cpu_trace[429:398]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n156 = cpu_trace[461:430]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n158 = n339[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n159 = n339[32:1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n160 = n339[64:33]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n161 = n339[65]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n162 = n339[66]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n163 = n339[67]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n164 = n339[69:68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n165 = n339[71:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n166 = n339[72]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n167 = n339[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n168 = n339[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n169 = n339[106:75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n170 = n339[111:107]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n171 = n339[116:112]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n172 = n339[148:117]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n173 = n339[180:149]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n174 = n339[185:181]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n175 = n339[217:186]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n176 = n339[249:218]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n177 = n339[281:250]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n178 = n339[293:282]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n179 = n339[325:294]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n180 = n339[357:326]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n181 = n339[389:358]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n182 = n339[393:390]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n183 = n339[397:394]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n184 = n339[429:398]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n185 = n339[461:430]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:331:10 */
  assign rstn_wdt = 1'b1; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:341:10 */
  assign dci_ndmrstn = 1'b1; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:342:10 */
  assign dci_haltreq = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:346:10 */
  assign cpu_trace = n293; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:10 */
  assign cpu_i_req = n296; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:21 */
  assign cpu_d_req = n302; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:32 */
  assign icache_req = cpu_i_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:44 */
  assign dcache_req = cpu_d_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:56 */
  assign core_req = n333; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:10 */
  assign cpu_i_rsp = icache_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:21 */
  assign cpu_d_rsp = dcache_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:32 */
  assign icache_rsp = n331; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:44 */
  assign dcache_rsp = n319; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:56 */
  assign core_rsp = sys1_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:10 */
  assign sys1_req = core_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:20 */
  assign sys2_req = sys1_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:39 */
  assign amo_req = sys2_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:48 */
  assign sys3_req = amo_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:58 */
  assign imem_req = n358; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:68 */
  assign dmem_req = n363; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:87 */
  assign io_req = n373; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:95 */
  assign xbus_req = n378; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:10 */
  assign sys1_rsp = sys2_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:20 */
  assign sys2_rsp = amo_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:39 */
  assign amo_rsp = sys3_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:48 */
  assign sys3_rsp = n356; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:58 */
  assign imem_rsp = n393; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:68 */
  assign dmem_rsp = n405; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:78 */
  assign smc_rsp = 34'b0000000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:87 */
  assign io_rsp = n442; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:95 */
  assign xbus_rsp = n422; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:370:10 */
  assign iodev_req = n686; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:371:10 */
  assign iodev_rsp = n687; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:379:10 */
  assign firq = n688; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:380:10 */
  assign cpu_firq = n689; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:381:10 */
  assign mti = irq_mti_i; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:381:15 */
  assign msi = irq_msi_i; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:384:10 */
  assign mtime = 64'b0000000000000000000000000000000000000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:496:5 */
  neorv32_sys_reset_Bneorv32_sys_reset_rtl_Lneorv32 soc_generators_neorv32_sys_reset_inst (
    .clk_i(clk_i),
    .rstn_ext_i(rstn_i),
    .rstn_wdt_i(rstn_wdt),
    .rstn_dbg_i(dci_ndmrstn),
    .rstn_ext_o(),
    .rstn_sys_o(rstn_sys),
    .xrstn_wdt_o(rstn_wdt_o),
    .xrstn_ocd_o(rstn_ocd_o));
  /*# ../../rtl/core/neorv32_top.vhd:509:5 */
  neorv32_sys_clock_Bneorv32_sys_clock_rtl_Lneorv32 soc_generators_neorv32_sys_clock_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .enable_i(1'b1),
    .clk_en_o(clk_gen));
  /*# ../../rtl/core/neorv32_top.vhd:525:23 */
  assign n278 = firq[8]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:526:23 */
  assign n279 = firq[13]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:527:23 */
  assign n280 = firq[12]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:528:23 */
  assign n281 = firq[14]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:529:23 */
  assign n282 = firq[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:530:23 */
  assign n283 = firq[11]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:531:23 */
  assign n284 = firq[9]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:532:23 */
  assign n285 = firq[6]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:533:23 */
  assign n286 = firq[7]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:534:23 */
  assign n287 = firq[3]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:535:23 */
  assign n288 = firq[10]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:536:23 */
  assign n289 = firq[5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:537:23 */
  assign n290 = firq[4]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:538:23 */
  assign n291 = firq[2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:539:23 */
  assign n292 = firq[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  neorv32_cpu_Bneorv32_cpu_rtl_Lneorv32_0_0_0_4_0_40_0_e5735315961a7ae0119503075b3425320cc9d860 \core_complex_gen[0]_neorv32_cpu_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .mtime_i(mtime),
    .msi_i(msi),
    .mei_i(irq_mei_i),
    .mti_i(mti),
    .firq_i(cpu_firq),
    .dbi_i(dci_haltreq),
    .\ibus_rsp_i[ack] (n298),
    .\ibus_rsp_i[err] (n299),
    .\ibus_rsp_i[data] (n300),
    .\dbus_rsp_i[ack] (n304),
    .\dbus_rsp_i[err] (n305),
    .\dbus_rsp_i[data] (n306),
    .\trace_o[valid] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[valid] ),
    .\trace_o[order] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[order] ),
    .\trace_o[insn] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[insn] ),
    .\trace_o[trap] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[trap] ),
    .\trace_o[halt] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[halt] ),
    .\trace_o[intr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[intr] ),
    .\trace_o[mode] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mode] ),
    .\trace_o[ixl] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[ixl] ),
    .\trace_o[debug] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[debug] ),
    .\trace_o[compr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[compr] ),
    .\trace_o[delta] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[delta] ),
    .\trace_o[cmd32] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[cmd32] ),
    .\trace_o[rs1_addr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_addr] ),
    .\trace_o[rs2_addr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_addr] ),
    .\trace_o[rs1_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_rdata] ),
    .\trace_o[rs2_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_rdata] ),
    .\trace_o[rd_addr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_addr] ),
    .\trace_o[rd_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_rdata] ),
    .\trace_o[pc_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_rdata] ),
    .\trace_o[pc_wdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_wdata] ),
    .\trace_o[csr_addr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_addr] ),
    .\trace_o[csr_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_rdata] ),
    .\trace_o[csr_wdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_wdata] ),
    .\trace_o[mem_addr] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_addr] ),
    .\trace_o[mem_rmask] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rmask] ),
    .\trace_o[mem_wmask] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wmask] ),
    .\trace_o[mem_rdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rdata] ),
    .\trace_o[mem_wdata] (\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wdata] ),
    .sleep_o(),
    .ifence_o(),
    .\ibus_req_o[meta] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[meta] ),
    .\ibus_req_o[addr] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[addr] ),
    .\ibus_req_o[data] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[data] ),
    .\ibus_req_o[ben] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[ben] ),
    .\ibus_req_o[stb] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[stb] ),
    .\ibus_req_o[rw] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[rw] ),
    .\ibus_req_o[amo] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amo] ),
    .\ibus_req_o[amoop] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amoop] ),
    .\ibus_req_o[burst] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[burst] ),
    .\ibus_req_o[lock] (\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[lock] ),
    .dfence_o(),
    .\dbus_req_o[meta] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[meta] ),
    .\dbus_req_o[addr] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[addr] ),
    .\dbus_req_o[data] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[data] ),
    .\dbus_req_o[ben] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[ben] ),
    .\dbus_req_o[stb] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[stb] ),
    .\dbus_req_o[rw] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[rw] ),
    .\dbus_req_o[amo] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amo] ),
    .\dbus_req_o[amoop] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amoop] ),
    .\dbus_req_o[burst] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[burst] ),
    .\dbus_req_o[lock] (\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[lock] ));
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n293 = {\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wmask] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rmask] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[cmd32] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[delta] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[compr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[debug] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[ixl] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mode] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[intr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[halt] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[trap] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[insn] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[order] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[valid] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n296 = {\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[lock] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[burst] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amoop] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amo] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[rw] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[stb] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[ben] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[data] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[addr] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n298 = cpu_i_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n299 = cpu_i_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n300 = cpu_i_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n302 = {\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[lock] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[burst] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amoop] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amo] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[rw] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[stb] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[ben] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[data] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[addr] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n304 = cpu_d_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n305 = cpu_d_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n306 = cpu_d_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  neorv32_bus_switch_Bneorv32_bus_switch_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264 \core_complex_gen[0]_neorv32_core_bus_switch_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\a_req_i[meta] (n309),
    .\a_req_i[addr] (n310),
    .\a_req_i[data] (n311),
    .\a_req_i[ben] (n312),
    .\a_req_i[stb] (n313),
    .\a_req_i[rw] (n314),
    .\a_req_i[amo] (n315),
    .\a_req_i[amoop] (n316),
    .\a_req_i[burst] (n317),
    .\a_req_i[lock] (n318),
    .\b_req_i[meta] (n321),
    .\b_req_i[addr] (n322),
    .\b_req_i[data] (n323),
    .\b_req_i[ben] (n324),
    .\b_req_i[stb] (n325),
    .\b_req_i[rw] (n326),
    .\b_req_i[amo] (n327),
    .\b_req_i[amoop] (n328),
    .\b_req_i[burst] (n329),
    .\b_req_i[lock] (n330),
    .\x_rsp_i[ack] (n335),
    .\x_rsp_i[err] (n336),
    .\x_rsp_i[data] (n337),
    .\a_rsp_o[ack] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[ack] ),
    .\a_rsp_o[err] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[err] ),
    .\a_rsp_o[data] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[data] ),
    .\b_rsp_o[ack] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[ack] ),
    .\b_rsp_o[err] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[err] ),
    .\b_rsp_o[data] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[data] ),
    .\x_req_o[meta] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[meta] ),
    .\x_req_o[addr] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[addr] ),
    .\x_req_o[data] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[data] ),
    .\x_req_o[ben] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[ben] ),
    .\x_req_o[stb] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[stb] ),
    .\x_req_o[rw] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[rw] ),
    .\x_req_o[amo] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amo] ),
    .\x_req_o[amoop] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amoop] ),
    .\x_req_o[burst] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[burst] ),
    .\x_req_o[lock] (\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[lock] ));
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n309 = dcache_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n310 = dcache_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n311 = dcache_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n312 = dcache_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n313 = dcache_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n314 = dcache_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n315 = dcache_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n316 = dcache_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n317 = dcache_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n318 = dcache_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n319 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[err] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n321 = icache_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n322 = icache_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n323 = icache_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n324 = icache_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n325 = icache_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n326 = icache_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n327 = icache_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n328 = icache_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n329 = icache_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n330 = icache_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n331 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[err] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n333 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[lock] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[burst] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amoop] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amo] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[rw] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[stb] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[ben] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[addr] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n335 = core_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n336 = core_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n337 = core_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:718:45 */
  assign n339 = 1'b0 ? cpu_trace : 462'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  neorv32_bus_gateway_Bneorv32_bus_gateway_rtl_Lneorv32_16384_16_16384_16_268435456_2048_2097152_16_2048_bd50bc0f8960043decfaeea03012348ae010fe69 neorv32_bus_gateway_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\req_i[meta] (n346),
    .\req_i[addr] (n347),
    .\req_i[data] (n348),
    .\req_i[ben] (n349),
    .\req_i[stb] (n350),
    .\req_i[rw] (n351),
    .\req_i[amo] (n352),
    .\req_i[amoop] (n353),
    .\req_i[burst] (n354),
    .\req_i[lock] (n355),
    .\a_rsp_i[ack] (n360),
    .\a_rsp_i[err] (n361),
    .\a_rsp_i[data] (n362),
    .\b_rsp_i[ack] (n365),
    .\b_rsp_i[err] (n366),
    .\b_rsp_i[data] (n367),
    .\c_rsp_i[ack] (n370),
    .\c_rsp_i[err] (n371),
    .\c_rsp_i[data] (n372),
    .\d_rsp_i[ack] (n375),
    .\d_rsp_i[err] (n376),
    .\d_rsp_i[data] (n377),
    .\x_rsp_i[ack] (n380),
    .\x_rsp_i[err] (n381),
    .\x_rsp_i[data] (n382),
    .term_o(xbus_terminate),
    .\rsp_o[ack] (\neorv32_bus_gateway_inst.rsp_o[ack] ),
    .\rsp_o[err] (\neorv32_bus_gateway_inst.rsp_o[err] ),
    .\rsp_o[data] (\neorv32_bus_gateway_inst.rsp_o[data] ),
    .\a_req_o[meta] (\neorv32_bus_gateway_inst.a_req_o[meta] ),
    .\a_req_o[addr] (\neorv32_bus_gateway_inst.a_req_o[addr] ),
    .\a_req_o[data] (\neorv32_bus_gateway_inst.a_req_o[data] ),
    .\a_req_o[ben] (\neorv32_bus_gateway_inst.a_req_o[ben] ),
    .\a_req_o[stb] (\neorv32_bus_gateway_inst.a_req_o[stb] ),
    .\a_req_o[rw] (\neorv32_bus_gateway_inst.a_req_o[rw] ),
    .\a_req_o[amo] (\neorv32_bus_gateway_inst.a_req_o[amo] ),
    .\a_req_o[amoop] (\neorv32_bus_gateway_inst.a_req_o[amoop] ),
    .\a_req_o[burst] (\neorv32_bus_gateway_inst.a_req_o[burst] ),
    .\a_req_o[lock] (\neorv32_bus_gateway_inst.a_req_o[lock] ),
    .\b_req_o[meta] (\neorv32_bus_gateway_inst.b_req_o[meta] ),
    .\b_req_o[addr] (\neorv32_bus_gateway_inst.b_req_o[addr] ),
    .\b_req_o[data] (\neorv32_bus_gateway_inst.b_req_o[data] ),
    .\b_req_o[ben] (\neorv32_bus_gateway_inst.b_req_o[ben] ),
    .\b_req_o[stb] (\neorv32_bus_gateway_inst.b_req_o[stb] ),
    .\b_req_o[rw] (\neorv32_bus_gateway_inst.b_req_o[rw] ),
    .\b_req_o[amo] (\neorv32_bus_gateway_inst.b_req_o[amo] ),
    .\b_req_o[amoop] (\neorv32_bus_gateway_inst.b_req_o[amoop] ),
    .\b_req_o[burst] (\neorv32_bus_gateway_inst.b_req_o[burst] ),
    .\b_req_o[lock] (\neorv32_bus_gateway_inst.b_req_o[lock] ),
    .\c_req_o[meta] (),
    .\c_req_o[addr] (),
    .\c_req_o[data] (),
    .\c_req_o[ben] (),
    .\c_req_o[stb] (),
    .\c_req_o[rw] (),
    .\c_req_o[amo] (),
    .\c_req_o[amoop] (),
    .\c_req_o[burst] (),
    .\c_req_o[lock] (),
    .\d_req_o[meta] (\neorv32_bus_gateway_inst.d_req_o[meta] ),
    .\d_req_o[addr] (\neorv32_bus_gateway_inst.d_req_o[addr] ),
    .\d_req_o[data] (\neorv32_bus_gateway_inst.d_req_o[data] ),
    .\d_req_o[ben] (\neorv32_bus_gateway_inst.d_req_o[ben] ),
    .\d_req_o[stb] (\neorv32_bus_gateway_inst.d_req_o[stb] ),
    .\d_req_o[rw] (\neorv32_bus_gateway_inst.d_req_o[rw] ),
    .\d_req_o[amo] (\neorv32_bus_gateway_inst.d_req_o[amo] ),
    .\d_req_o[amoop] (\neorv32_bus_gateway_inst.d_req_o[amoop] ),
    .\d_req_o[burst] (\neorv32_bus_gateway_inst.d_req_o[burst] ),
    .\d_req_o[lock] (\neorv32_bus_gateway_inst.d_req_o[lock] ),
    .\x_req_o[meta] (\neorv32_bus_gateway_inst.x_req_o[meta] ),
    .\x_req_o[addr] (\neorv32_bus_gateway_inst.x_req_o[addr] ),
    .\x_req_o[data] (\neorv32_bus_gateway_inst.x_req_o[data] ),
    .\x_req_o[ben] (\neorv32_bus_gateway_inst.x_req_o[ben] ),
    .\x_req_o[stb] (\neorv32_bus_gateway_inst.x_req_o[stb] ),
    .\x_req_o[rw] (\neorv32_bus_gateway_inst.x_req_o[rw] ),
    .\x_req_o[amo] (\neorv32_bus_gateway_inst.x_req_o[amo] ),
    .\x_req_o[amoop] (\neorv32_bus_gateway_inst.x_req_o[amoop] ),
    .\x_req_o[burst] (\neorv32_bus_gateway_inst.x_req_o[burst] ),
    .\x_req_o[lock] (\neorv32_bus_gateway_inst.x_req_o[lock] ));
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n346 = sys3_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n347 = sys3_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n348 = sys3_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n349 = sys3_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n350 = sys3_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n351 = sys3_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n352 = sys3_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n353 = sys3_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n354 = sys3_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n355 = sys3_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n356 = {\neorv32_bus_gateway_inst.rsp_o[data] , \neorv32_bus_gateway_inst.rsp_o[err] , \neorv32_bus_gateway_inst.rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n358 = {\neorv32_bus_gateway_inst.a_req_o[lock] , \neorv32_bus_gateway_inst.a_req_o[burst] , \neorv32_bus_gateway_inst.a_req_o[amoop] , \neorv32_bus_gateway_inst.a_req_o[amo] , \neorv32_bus_gateway_inst.a_req_o[rw] , \neorv32_bus_gateway_inst.a_req_o[stb] , \neorv32_bus_gateway_inst.a_req_o[ben] , \neorv32_bus_gateway_inst.a_req_o[data] , \neorv32_bus_gateway_inst.a_req_o[addr] , \neorv32_bus_gateway_inst.a_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n360 = imem_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n361 = imem_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n362 = imem_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n363 = {\neorv32_bus_gateway_inst.b_req_o[lock] , \neorv32_bus_gateway_inst.b_req_o[burst] , \neorv32_bus_gateway_inst.b_req_o[amoop] , \neorv32_bus_gateway_inst.b_req_o[amo] , \neorv32_bus_gateway_inst.b_req_o[rw] , \neorv32_bus_gateway_inst.b_req_o[stb] , \neorv32_bus_gateway_inst.b_req_o[ben] , \neorv32_bus_gateway_inst.b_req_o[data] , \neorv32_bus_gateway_inst.b_req_o[addr] , \neorv32_bus_gateway_inst.b_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n365 = dmem_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n366 = dmem_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n367 = dmem_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n370 = smc_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n371 = smc_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n372 = smc_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n373 = {\neorv32_bus_gateway_inst.d_req_o[lock] , \neorv32_bus_gateway_inst.d_req_o[burst] , \neorv32_bus_gateway_inst.d_req_o[amoop] , \neorv32_bus_gateway_inst.d_req_o[amo] , \neorv32_bus_gateway_inst.d_req_o[rw] , \neorv32_bus_gateway_inst.d_req_o[stb] , \neorv32_bus_gateway_inst.d_req_o[ben] , \neorv32_bus_gateway_inst.d_req_o[data] , \neorv32_bus_gateway_inst.d_req_o[addr] , \neorv32_bus_gateway_inst.d_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n375 = io_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n376 = io_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n377 = io_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n378 = {\neorv32_bus_gateway_inst.x_req_o[lock] , \neorv32_bus_gateway_inst.x_req_o[burst] , \neorv32_bus_gateway_inst.x_req_o[amoop] , \neorv32_bus_gateway_inst.x_req_o[amo] , \neorv32_bus_gateway_inst.x_req_o[rw] , \neorv32_bus_gateway_inst.x_req_o[stb] , \neorv32_bus_gateway_inst.x_req_o[ben] , \neorv32_bus_gateway_inst.x_req_o[data] , \neorv32_bus_gateway_inst.x_req_o[addr] , \neorv32_bus_gateway_inst.x_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n380 = xbus_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n381 = xbus_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n382 = xbus_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  neorv32_imem_Bneorv32_imem_rtl_Lneorv32_16384_0e356ba505631fbf715758bed27d503f8b260e3a memory_system_neorv32_imem_enabled_neorv32_imem_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n383),
    .\bus_req_i[addr] (n384),
    .\bus_req_i[data] (n385),
    .\bus_req_i[ben] (n386),
    .\bus_req_i[stb] (n387),
    .\bus_req_i[rw] (n388),
    .\bus_req_i[amo] (n389),
    .\bus_req_i[amoop] (n390),
    .\bus_req_i[burst] (n391),
    .\bus_req_i[lock] (n392),
    .\bus_rsp_o[ack] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n383 = imem_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n384 = imem_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n385 = imem_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n386 = imem_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n387 = imem_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n388 = imem_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n389 = imem_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n390 = imem_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n391 = imem_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n392 = imem_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n393 = {\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] , \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] , \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  neorv32_dmem_Bneorv32_dmem_rtl_Lneorv32_16384_5ba93c9db0cff93f52b521d7420e43f6eda2784f memory_system_neorv32_dmem_enabled_neorv32_dmem_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n395),
    .\bus_req_i[addr] (n396),
    .\bus_req_i[data] (n397),
    .\bus_req_i[ben] (n398),
    .\bus_req_i[stb] (n399),
    .\bus_req_i[rw] (n400),
    .\bus_req_i[amo] (n401),
    .\bus_req_i[amoop] (n402),
    .\bus_req_i[burst] (n403),
    .\bus_req_i[lock] (n404),
    .\bus_rsp_o[ack] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n395 = dmem_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n396 = dmem_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n397 = dmem_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n398 = dmem_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n399 = dmem_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n400 = dmem_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n401 = dmem_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n402 = dmem_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n403 = dmem_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n404 = dmem_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n405 = {\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] , \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] , \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  neorv32_xbus_Bneorv32_xbus_rtl_Lneorv32_5ba93c9db0cff93f52b521d7420e43f6eda2784f memory_system_neorv32_xbus_enabled_neorv32_xbus_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .bus_term_i(xbus_terminate),
    .\bus_req_i[meta] (n412),
    .\bus_req_i[addr] (n413),
    .\bus_req_i[data] (n414),
    .\bus_req_i[ben] (n415),
    .\bus_req_i[stb] (n416),
    .\bus_req_i[rw] (n417),
    .\bus_req_i[amo] (n418),
    .\bus_req_i[amoop] (n419),
    .\bus_req_i[burst] (n420),
    .\bus_req_i[lock] (n421),
    .xbus_dat_i(xbus_dat_i),
    .xbus_ack_i(xbus_ack_i),
    .xbus_err_i(xbus_err_i),
    .\bus_rsp_o[ack] (\memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[data] ),
    .xbus_adr_o(xbus_adr_o),
    .xbus_dat_o(xbus_dat_o),
    .xbus_cti_o(xbus_cti_o),
    .xbus_tag_o(xbus_tag_o),
    .xbus_we_o(xbus_we_o),
    .xbus_sel_o(xbus_sel_o),
    .xbus_stb_o(xbus_stb_o),
    .xbus_cyc_o(xbus_cyc_o));
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n412 = xbus_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n413 = xbus_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n414 = xbus_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n415 = xbus_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n416 = xbus_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n417 = xbus_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n418 = xbus_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n419 = xbus_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n420 = xbus_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n421 = xbus_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:996:7 */
  assign n422 = {\memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[data] , \memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[err] , \memory_system_neorv32_xbus_enabled_neorv32_xbus_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  neorv32_bus_io_switch_Bneorv32_bus_io_switch_rtl_Lneorv32_65536_1b53c2fe5410ef4bb6e1726f52befa7beb54e9a8 io_system_neorv32_bus_io_switch_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\main_req_i[meta] (n432),
    .\main_req_i[addr] (n433),
    .\main_req_i[data] (n434),
    .\main_req_i[ben] (n435),
    .\main_req_i[stb] (n436),
    .\main_req_i[rw] (n437),
    .\main_req_i[amo] (n438),
    .\main_req_i[amoop] (n439),
    .\main_req_i[burst] (n440),
    .\main_req_i[lock] (n441),
    .\dev_00_rsp_i[ack] (n447),
    .\dev_00_rsp_i[err] (n448),
    .\dev_00_rsp_i[data] (n449),
    .\dev_01_rsp_i[ack] (n451),
    .\dev_01_rsp_i[err] (n452),
    .\dev_01_rsp_i[data] (n453),
    .\dev_02_rsp_i[ack] (n455),
    .\dev_02_rsp_i[err] (n456),
    .\dev_02_rsp_i[data] (n457),
    .\dev_03_rsp_i[ack] (n459),
    .\dev_03_rsp_i[err] (n460),
    .\dev_03_rsp_i[data] (n461),
    .\dev_04_rsp_i[ack] (n463),
    .\dev_04_rsp_i[err] (n464),
    .\dev_04_rsp_i[data] (n465),
    .\dev_05_rsp_i[ack] (n467),
    .\dev_05_rsp_i[err] (n468),
    .\dev_05_rsp_i[data] (n469),
    .\dev_06_rsp_i[ack] (n471),
    .\dev_06_rsp_i[err] (n472),
    .\dev_06_rsp_i[data] (n473),
    .\dev_07_rsp_i[ack] (n475),
    .\dev_07_rsp_i[err] (n476),
    .\dev_07_rsp_i[data] (n477),
    .\dev_08_rsp_i[ack] (n479),
    .\dev_08_rsp_i[err] (n480),
    .\dev_08_rsp_i[data] (n481),
    .\dev_09_rsp_i[ack] (n483),
    .\dev_09_rsp_i[err] (n484),
    .\dev_09_rsp_i[data] (n485),
    .\dev_10_rsp_i[ack] (n489),
    .\dev_10_rsp_i[err] (n490),
    .\dev_10_rsp_i[data] (n491),
    .\dev_11_rsp_i[ack] (n495),
    .\dev_11_rsp_i[err] (n496),
    .\dev_11_rsp_i[data] (n497),
    .\dev_12_rsp_i[ack] (n501),
    .\dev_12_rsp_i[err] (n502),
    .\dev_12_rsp_i[data] (n503),
    .\dev_13_rsp_i[ack] (n507),
    .\dev_13_rsp_i[err] (n508),
    .\dev_13_rsp_i[data] (n509),
    .\dev_14_rsp_i[ack] (n511),
    .\dev_14_rsp_i[err] (n512),
    .\dev_14_rsp_i[data] (n513),
    .\dev_15_rsp_i[ack] (n517),
    .\dev_15_rsp_i[err] (n518),
    .\dev_15_rsp_i[data] (n519),
    .\dev_16_rsp_i[ack] (n523),
    .\dev_16_rsp_i[err] (n524),
    .\dev_16_rsp_i[data] (n525),
    .\dev_17_rsp_i[ack] (n529),
    .\dev_17_rsp_i[err] (n530),
    .\dev_17_rsp_i[data] (n531),
    .\dev_18_rsp_i[ack] (n535),
    .\dev_18_rsp_i[err] (n536),
    .\dev_18_rsp_i[data] (n537),
    .\dev_19_rsp_i[ack] (n541),
    .\dev_19_rsp_i[err] (n542),
    .\dev_19_rsp_i[data] (n543),
    .\dev_20_rsp_i[ack] (n547),
    .\dev_20_rsp_i[err] (n548),
    .\dev_20_rsp_i[data] (n549),
    .\dev_21_rsp_i[ack] (n553),
    .\dev_21_rsp_i[err] (n554),
    .\dev_21_rsp_i[data] (n555),
    .\dev_22_rsp_i[ack] (n559),
    .\dev_22_rsp_i[err] (n560),
    .\dev_22_rsp_i[data] (n561),
    .\dev_23_rsp_i[ack] (n565),
    .\dev_23_rsp_i[err] (n566),
    .\dev_23_rsp_i[data] (n567),
    .\dev_24_rsp_i[ack] (n571),
    .\dev_24_rsp_i[err] (n572),
    .\dev_24_rsp_i[data] (n573),
    .\dev_25_rsp_i[ack] (n577),
    .\dev_25_rsp_i[err] (n578),
    .\dev_25_rsp_i[data] (n579),
    .\dev_26_rsp_i[ack] (n583),
    .\dev_26_rsp_i[err] (n584),
    .\dev_26_rsp_i[data] (n585),
    .\dev_27_rsp_i[ack] (n589),
    .\dev_27_rsp_i[err] (n590),
    .\dev_27_rsp_i[data] (n591),
    .\dev_28_rsp_i[ack] (n595),
    .\dev_28_rsp_i[err] (n596),
    .\dev_28_rsp_i[data] (n597),
    .\dev_29_rsp_i[ack] (n601),
    .\dev_29_rsp_i[err] (n602),
    .\dev_29_rsp_i[data] (n603),
    .\dev_30_rsp_i[ack] (n607),
    .\dev_30_rsp_i[err] (n608),
    .\dev_30_rsp_i[data] (n609),
    .\dev_31_rsp_i[ack] (n613),
    .\dev_31_rsp_i[err] (n614),
    .\dev_31_rsp_i[data] (n615),
    .\main_rsp_o[ack] (\io_system_neorv32_bus_io_switch_inst.main_rsp_o[ack] ),
    .\main_rsp_o[err] (\io_system_neorv32_bus_io_switch_inst.main_rsp_o[err] ),
    .\main_rsp_o[data] (\io_system_neorv32_bus_io_switch_inst.main_rsp_o[data] ),
    .\dev_00_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[meta] ),
    .\dev_00_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[addr] ),
    .\dev_00_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[data] ),
    .\dev_00_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[ben] ),
    .\dev_00_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[stb] ),
    .\dev_00_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[rw] ),
    .\dev_00_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amo] ),
    .\dev_00_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amoop] ),
    .\dev_00_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[burst] ),
    .\dev_00_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[lock] ),
    .\dev_01_req_o[meta] (),
    .\dev_01_req_o[addr] (),
    .\dev_01_req_o[data] (),
    .\dev_01_req_o[ben] (),
    .\dev_01_req_o[stb] (),
    .\dev_01_req_o[rw] (),
    .\dev_01_req_o[amo] (),
    .\dev_01_req_o[amoop] (),
    .\dev_01_req_o[burst] (),
    .\dev_01_req_o[lock] (),
    .\dev_02_req_o[meta] (),
    .\dev_02_req_o[addr] (),
    .\dev_02_req_o[data] (),
    .\dev_02_req_o[ben] (),
    .\dev_02_req_o[stb] (),
    .\dev_02_req_o[rw] (),
    .\dev_02_req_o[amo] (),
    .\dev_02_req_o[amoop] (),
    .\dev_02_req_o[burst] (),
    .\dev_02_req_o[lock] (),
    .\dev_03_req_o[meta] (),
    .\dev_03_req_o[addr] (),
    .\dev_03_req_o[data] (),
    .\dev_03_req_o[ben] (),
    .\dev_03_req_o[stb] (),
    .\dev_03_req_o[rw] (),
    .\dev_03_req_o[amo] (),
    .\dev_03_req_o[amoop] (),
    .\dev_03_req_o[burst] (),
    .\dev_03_req_o[lock] (),
    .\dev_04_req_o[meta] (),
    .\dev_04_req_o[addr] (),
    .\dev_04_req_o[data] (),
    .\dev_04_req_o[ben] (),
    .\dev_04_req_o[stb] (),
    .\dev_04_req_o[rw] (),
    .\dev_04_req_o[amo] (),
    .\dev_04_req_o[amoop] (),
    .\dev_04_req_o[burst] (),
    .\dev_04_req_o[lock] (),
    .\dev_05_req_o[meta] (),
    .\dev_05_req_o[addr] (),
    .\dev_05_req_o[data] (),
    .\dev_05_req_o[ben] (),
    .\dev_05_req_o[stb] (),
    .\dev_05_req_o[rw] (),
    .\dev_05_req_o[amo] (),
    .\dev_05_req_o[amoop] (),
    .\dev_05_req_o[burst] (),
    .\dev_05_req_o[lock] (),
    .\dev_06_req_o[meta] (),
    .\dev_06_req_o[addr] (),
    .\dev_06_req_o[data] (),
    .\dev_06_req_o[ben] (),
    .\dev_06_req_o[stb] (),
    .\dev_06_req_o[rw] (),
    .\dev_06_req_o[amo] (),
    .\dev_06_req_o[amoop] (),
    .\dev_06_req_o[burst] (),
    .\dev_06_req_o[lock] (),
    .\dev_07_req_o[meta] (),
    .\dev_07_req_o[addr] (),
    .\dev_07_req_o[data] (),
    .\dev_07_req_o[ben] (),
    .\dev_07_req_o[stb] (),
    .\dev_07_req_o[rw] (),
    .\dev_07_req_o[amo] (),
    .\dev_07_req_o[amoop] (),
    .\dev_07_req_o[burst] (),
    .\dev_07_req_o[lock] (),
    .\dev_08_req_o[meta] (),
    .\dev_08_req_o[addr] (),
    .\dev_08_req_o[data] (),
    .\dev_08_req_o[ben] (),
    .\dev_08_req_o[stb] (),
    .\dev_08_req_o[rw] (),
    .\dev_08_req_o[amo] (),
    .\dev_08_req_o[amoop] (),
    .\dev_08_req_o[burst] (),
    .\dev_08_req_o[lock] (),
    .\dev_09_req_o[meta] (),
    .\dev_09_req_o[addr] (),
    .\dev_09_req_o[data] (),
    .\dev_09_req_o[ben] (),
    .\dev_09_req_o[stb] (),
    .\dev_09_req_o[rw] (),
    .\dev_09_req_o[amo] (),
    .\dev_09_req_o[amoop] (),
    .\dev_09_req_o[burst] (),
    .\dev_09_req_o[lock] (),
    .\dev_10_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[meta] ),
    .\dev_10_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[addr] ),
    .\dev_10_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[data] ),
    .\dev_10_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[ben] ),
    .\dev_10_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[stb] ),
    .\dev_10_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[rw] ),
    .\dev_10_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amo] ),
    .\dev_10_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amoop] ),
    .\dev_10_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[burst] ),
    .\dev_10_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[lock] ),
    .\dev_11_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[meta] ),
    .\dev_11_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[addr] ),
    .\dev_11_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[data] ),
    .\dev_11_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[ben] ),
    .\dev_11_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[stb] ),
    .\dev_11_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[rw] ),
    .\dev_11_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amo] ),
    .\dev_11_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amoop] ),
    .\dev_11_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[burst] ),
    .\dev_11_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[lock] ),
    .\dev_12_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[meta] ),
    .\dev_12_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[addr] ),
    .\dev_12_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[data] ),
    .\dev_12_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[ben] ),
    .\dev_12_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[stb] ),
    .\dev_12_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[rw] ),
    .\dev_12_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amo] ),
    .\dev_12_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amoop] ),
    .\dev_12_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[burst] ),
    .\dev_12_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[lock] ),
    .\dev_13_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[meta] ),
    .\dev_13_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[addr] ),
    .\dev_13_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[data] ),
    .\dev_13_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[ben] ),
    .\dev_13_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[stb] ),
    .\dev_13_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[rw] ),
    .\dev_13_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amo] ),
    .\dev_13_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amoop] ),
    .\dev_13_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[burst] ),
    .\dev_13_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[lock] ),
    .\dev_14_req_o[meta] (),
    .\dev_14_req_o[addr] (),
    .\dev_14_req_o[data] (),
    .\dev_14_req_o[ben] (),
    .\dev_14_req_o[stb] (),
    .\dev_14_req_o[rw] (),
    .\dev_14_req_o[amo] (),
    .\dev_14_req_o[amoop] (),
    .\dev_14_req_o[burst] (),
    .\dev_14_req_o[lock] (),
    .\dev_15_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[meta] ),
    .\dev_15_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[addr] ),
    .\dev_15_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[data] ),
    .\dev_15_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[ben] ),
    .\dev_15_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[stb] ),
    .\dev_15_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[rw] ),
    .\dev_15_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amo] ),
    .\dev_15_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amoop] ),
    .\dev_15_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[burst] ),
    .\dev_15_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[lock] ),
    .\dev_16_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[meta] ),
    .\dev_16_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[addr] ),
    .\dev_16_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[data] ),
    .\dev_16_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[ben] ),
    .\dev_16_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[stb] ),
    .\dev_16_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[rw] ),
    .\dev_16_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amo] ),
    .\dev_16_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amoop] ),
    .\dev_16_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[burst] ),
    .\dev_16_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[lock] ),
    .\dev_17_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[meta] ),
    .\dev_17_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[addr] ),
    .\dev_17_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[data] ),
    .\dev_17_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[ben] ),
    .\dev_17_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[stb] ),
    .\dev_17_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[rw] ),
    .\dev_17_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amo] ),
    .\dev_17_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amoop] ),
    .\dev_17_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[burst] ),
    .\dev_17_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[lock] ),
    .\dev_18_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[meta] ),
    .\dev_18_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[addr] ),
    .\dev_18_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[data] ),
    .\dev_18_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[ben] ),
    .\dev_18_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[stb] ),
    .\dev_18_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[rw] ),
    .\dev_18_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amo] ),
    .\dev_18_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amoop] ),
    .\dev_18_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[burst] ),
    .\dev_18_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[lock] ),
    .\dev_19_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[meta] ),
    .\dev_19_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[addr] ),
    .\dev_19_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[data] ),
    .\dev_19_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[ben] ),
    .\dev_19_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[stb] ),
    .\dev_19_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[rw] ),
    .\dev_19_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amo] ),
    .\dev_19_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amoop] ),
    .\dev_19_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[burst] ),
    .\dev_19_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[lock] ),
    .\dev_20_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[meta] ),
    .\dev_20_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[addr] ),
    .\dev_20_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[data] ),
    .\dev_20_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[ben] ),
    .\dev_20_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[stb] ),
    .\dev_20_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[rw] ),
    .\dev_20_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amo] ),
    .\dev_20_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amoop] ),
    .\dev_20_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[burst] ),
    .\dev_20_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[lock] ),
    .\dev_21_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[meta] ),
    .\dev_21_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[addr] ),
    .\dev_21_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[data] ),
    .\dev_21_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[ben] ),
    .\dev_21_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[stb] ),
    .\dev_21_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[rw] ),
    .\dev_21_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amo] ),
    .\dev_21_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amoop] ),
    .\dev_21_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[burst] ),
    .\dev_21_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[lock] ),
    .\dev_22_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[meta] ),
    .\dev_22_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[addr] ),
    .\dev_22_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[data] ),
    .\dev_22_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[ben] ),
    .\dev_22_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[stb] ),
    .\dev_22_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[rw] ),
    .\dev_22_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amo] ),
    .\dev_22_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amoop] ),
    .\dev_22_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[burst] ),
    .\dev_22_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[lock] ),
    .\dev_23_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[meta] ),
    .\dev_23_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[addr] ),
    .\dev_23_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[data] ),
    .\dev_23_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[ben] ),
    .\dev_23_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[stb] ),
    .\dev_23_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[rw] ),
    .\dev_23_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amo] ),
    .\dev_23_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amoop] ),
    .\dev_23_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[burst] ),
    .\dev_23_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[lock] ),
    .\dev_24_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[meta] ),
    .\dev_24_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[addr] ),
    .\dev_24_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[data] ),
    .\dev_24_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[ben] ),
    .\dev_24_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[stb] ),
    .\dev_24_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[rw] ),
    .\dev_24_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amo] ),
    .\dev_24_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amoop] ),
    .\dev_24_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[burst] ),
    .\dev_24_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[lock] ),
    .\dev_25_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[meta] ),
    .\dev_25_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[addr] ),
    .\dev_25_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[data] ),
    .\dev_25_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[ben] ),
    .\dev_25_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[stb] ),
    .\dev_25_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[rw] ),
    .\dev_25_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amo] ),
    .\dev_25_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amoop] ),
    .\dev_25_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[burst] ),
    .\dev_25_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[lock] ),
    .\dev_26_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[meta] ),
    .\dev_26_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[addr] ),
    .\dev_26_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[data] ),
    .\dev_26_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[ben] ),
    .\dev_26_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[stb] ),
    .\dev_26_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[rw] ),
    .\dev_26_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amo] ),
    .\dev_26_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amoop] ),
    .\dev_26_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[burst] ),
    .\dev_26_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[lock] ),
    .\dev_27_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[meta] ),
    .\dev_27_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[addr] ),
    .\dev_27_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[data] ),
    .\dev_27_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[ben] ),
    .\dev_27_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[stb] ),
    .\dev_27_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[rw] ),
    .\dev_27_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amo] ),
    .\dev_27_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amoop] ),
    .\dev_27_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[burst] ),
    .\dev_27_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[lock] ),
    .\dev_28_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[meta] ),
    .\dev_28_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[addr] ),
    .\dev_28_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[data] ),
    .\dev_28_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[ben] ),
    .\dev_28_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[stb] ),
    .\dev_28_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[rw] ),
    .\dev_28_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amo] ),
    .\dev_28_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amoop] ),
    .\dev_28_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[burst] ),
    .\dev_28_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[lock] ),
    .\dev_29_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[meta] ),
    .\dev_29_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[addr] ),
    .\dev_29_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[data] ),
    .\dev_29_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[ben] ),
    .\dev_29_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[stb] ),
    .\dev_29_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[rw] ),
    .\dev_29_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amo] ),
    .\dev_29_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amoop] ),
    .\dev_29_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[burst] ),
    .\dev_29_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[lock] ),
    .\dev_30_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[meta] ),
    .\dev_30_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[addr] ),
    .\dev_30_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[data] ),
    .\dev_30_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[ben] ),
    .\dev_30_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[stb] ),
    .\dev_30_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[rw] ),
    .\dev_30_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amo] ),
    .\dev_30_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amoop] ),
    .\dev_30_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[burst] ),
    .\dev_30_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[lock] ),
    .\dev_31_req_o[meta] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[meta] ),
    .\dev_31_req_o[addr] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[addr] ),
    .\dev_31_req_o[data] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[data] ),
    .\dev_31_req_o[ben] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[ben] ),
    .\dev_31_req_o[stb] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[stb] ),
    .\dev_31_req_o[rw] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[rw] ),
    .\dev_31_req_o[amo] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amo] ),
    .\dev_31_req_o[amoop] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amoop] ),
    .\dev_31_req_o[burst] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[burst] ),
    .\dev_31_req_o[lock] (\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[lock] ));
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n432 = io_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n433 = io_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n434 = io_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n435 = io_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n436 = io_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n437 = io_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n438 = io_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n439 = io_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n440 = io_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n441 = io_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n442 = {\io_system_neorv32_bus_io_switch_inst.main_rsp_o[data] , \io_system_neorv32_bus_io_switch_inst.main_rsp_o[err] , \io_system_neorv32_bus_io_switch_inst.main_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n444 = {\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n447 = iodev_rsp[714]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n448 = iodev_rsp[715]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n449 = iodev_rsp[747:716]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n451 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n452 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n453 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n455 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n456 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n457 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n459 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n460 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n461 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n463 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n464 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n465 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n467 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n468 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n469 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n471 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n472 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n473 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n475 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n476 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n477 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n479 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n480 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n481 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n483 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n484 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n485 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n486 = {\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n489 = iodev_rsp[68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n490 = iodev_rsp[69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n491 = iodev_rsp[101:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n492 = {\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n495 = iodev_rsp[102]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n496 = iodev_rsp[103]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n497 = iodev_rsp[135:104]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n498 = {\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n501 = iodev_rsp[136]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n502 = iodev_rsp[137]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n503 = iodev_rsp[169:138]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n504 = {\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n507 = iodev_rsp[170]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n508 = iodev_rsp[171]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n509 = iodev_rsp[203:172]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n511 = n341[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n512 = n341[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n513 = n341[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n514 = {\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n517 = iodev_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n518 = iodev_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n519 = iodev_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n520 = {\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n523 = iodev_rsp[204]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n524 = iodev_rsp[205]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n525 = iodev_rsp[237:206]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n526 = {\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n529 = iodev_rsp[238]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n530 = iodev_rsp[239]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n531 = iodev_rsp[271:240]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n532 = {\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n535 = iodev_rsp[272]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n536 = iodev_rsp[273]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n537 = iodev_rsp[305:274]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n538 = {\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n541 = iodev_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n542 = iodev_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n543 = iodev_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n544 = {\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n547 = iodev_rsp[306]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n548 = iodev_rsp[307]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n549 = iodev_rsp[339:308]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n550 = {\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n553 = iodev_rsp[340]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n554 = iodev_rsp[341]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n555 = iodev_rsp[373:342]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n556 = {\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n559 = iodev_rsp[374]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n560 = iodev_rsp[375]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n561 = iodev_rsp[407:376]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n562 = {\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n565 = iodev_rsp[408]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n566 = iodev_rsp[409]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n567 = iodev_rsp[441:410]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n568 = {\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n571 = iodev_rsp[442]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n572 = iodev_rsp[443]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n573 = iodev_rsp[475:444]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n574 = {\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n577 = iodev_rsp[476]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n578 = iodev_rsp[477]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n579 = iodev_rsp[509:478]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n580 = {\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n583 = iodev_rsp[510]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n584 = iodev_rsp[511]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n585 = iodev_rsp[543:512]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n586 = {\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n589 = iodev_rsp[544]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n590 = iodev_rsp[545]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n591 = iodev_rsp[577:546]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n592 = {\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n595 = iodev_rsp[578]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n596 = iodev_rsp[579]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n597 = iodev_rsp[611:580]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n598 = {\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n601 = iodev_rsp[612]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n602 = iodev_rsp[613]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n603 = iodev_rsp[645:614]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n604 = {\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n607 = iodev_rsp[646]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n608 = iodev_rsp[647]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n609 = iodev_rsp[679:648]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n610 = {\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n613 = iodev_rsp[680]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n614 = iodev_rsp[681]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n615 = iodev_rsp[713:682]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  neorv32_uart_Bneorv32_uart_rtl_Lneorv32_1_1 io_system_neorv32_uart0_enabled_neorv32_uart0_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n628),
    .\bus_req_i[addr] (n629),
    .\bus_req_i[data] (n630),
    .\bus_req_i[ben] (n631),
    .\bus_req_i[stb] (n632),
    .\bus_req_i[rw] (n633),
    .\bus_req_i[amo] (n634),
    .\bus_req_i[amoop] (n635),
    .\bus_req_i[burst] (n636),
    .\bus_req_i[lock] (n637),
    .clkgen_i(clk_gen),
    .uart_rxd_i(uart0_rxd_i),
    .uart_ctsn_i(uart0_ctsn_i),
    .\bus_rsp_o[ack] (\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[data] ),
    .uart_txd_o(uart0_txd_o),
    .uart_rtsn_o(uart0_rtsn_o),
    .irq_o(\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.irq_o ));
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n628 = iodev_req[824:820]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n629 = iodev_req[856:825]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n630 = iodev_req[888:857]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n631 = iodev_req[892:889]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n632 = iodev_req[893]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n633 = iodev_req[894]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n634 = iodev_req[895]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n635 = iodev_req[899:896]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n636 = iodev_req[900]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n637 = iodev_req[901]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n638 = {\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[data] , \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[err] , \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  neorv32_sysinfo_Bneorv32_sysinfo_rtl_Lneorv32_16_2048_1_100000000_2_16384_16384_4_4_64_ced63791903ad0e2711f1008bce20abcabf7e534 io_system_neorv32_sysinfo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n670),
    .\bus_req_i[addr] (n671),
    .\bus_req_i[data] (n672),
    .\bus_req_i[ben] (n673),
    .\bus_req_i[stb] (n674),
    .\bus_req_i[rw] (n675),
    .\bus_req_i[amo] (n676),
    .\bus_req_i[amoop] (n677),
    .\bus_req_i[burst] (n678),
    .\bus_req_i[lock] (n679),
    .\bus_rsp_o[ack] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n670 = iodev_req[1562:1558]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n671 = iodev_req[1594:1563]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n672 = iodev_req[1626:1595]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n673 = iodev_req[1630:1627]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n674 = iodev_req[1631]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n675 = iodev_req[1632]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n676 = iodev_req[1633]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n677 = iodev_req[1637:1634]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n678 = iodev_req[1638]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n679 = iodev_req[1639]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n680 = {\io_system_neorv32_sysinfo_inst.bus_rsp_o[data] , \io_system_neorv32_sysinfo_inst.bus_rsp_o[err] , \io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:370:10 */
  assign n686 = {n444, n610, n604, n598, n592, n586, n580, n574, n568, n562, n556, n550, n544, n532, n526, n520, n504, n498, n492, n486, n538, n514};
  /*# ../../rtl/core/neorv32_top.vhd:371:10 */
  assign n687 = {34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, n680, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, n638, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_top.vhd:379:10 */
  assign n688 = {1'b0, \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.irq_o , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_top.vhd:380:10 */
  assign n689 = {n292, n291, n290, n289, n288, n287, n286, n285, n284, n283, n282, n281, n280, n279, n278, 1'b0};
endmodule

module neorv32_verilog_wrapper
  (input  clk_i,
   input  rstn_i,
   output uart0_txd_o,
   input  uart0_rxd_i,
   output [31:0] xbus_adr_o,
   output [31:0] xbus_dat_o,
   output [2:0] xbus_cti_o,
   output [2:0] xbus_tag_o,
   output xbus_we_o,
   output [3:0] xbus_sel_o,
   output xbus_stb_o,
   output xbus_cyc_o,
   input  [31:0] xbus_dat_i,
   input  xbus_ack_i,
   input  xbus_err_i);
  localparam n13 = 1'b0;
  localparam n14 = 1'b0;
  localparam n16 = 1'b0;
  localparam n21 = 1'b0;
  wire [31:0] neorv32_top_inst_n22;
  wire [31:0] neorv32_top_inst_n23;
  wire [2:0] neorv32_top_inst_n24;
  wire [2:0] neorv32_top_inst_n25;
  wire neorv32_top_inst_n26;
  wire [3:0] neorv32_top_inst_n27;
  wire neorv32_top_inst_n28;
  wire neorv32_top_inst_n29;
  localparam [31:0] n30 = 32'b00000000000000000000000000000000;
  localparam [3:0] n31 = 4'b0000;
  localparam n32 = 1'b0;
  localparam n33 = 1'b0;
  localparam n39 = 1'b0;
  localparam [31:0] n42 = 32'b00000000000000000000000000000000;
  wire neorv32_top_inst_n43;
  localparam n45 = 1'b0;
  localparam n47 = 1'b0;
  localparam n49 = 1'b0;
  localparam n52 = 1'b0;
  localparam n54 = 1'b0;
  localparam n56 = 1'b0;
  localparam n57 = 1'b1;
  localparam n58 = 1'b1;
  localparam n60 = 1'b1;
  localparam n62 = 1'b1;
  localparam n64 = 1'b1;
  localparam n65 = 1'b1;
  localparam [255:0] n68 = 256'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  localparam n72 = 1'b0;
  localparam n73 = 1'b0;
  localparam n74 = 1'b0;
  wire \neorv32_top_inst.rstn_ocd_o ;
  wire \neorv32_top_inst.rstn_wdt_o ;
  wire \neorv32_top_inst.trace_cpu0_o[valid] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[order] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[insn] ;
  wire \neorv32_top_inst.trace_cpu0_o[trap] ;
  wire \neorv32_top_inst.trace_cpu0_o[halt] ;
  wire \neorv32_top_inst.trace_cpu0_o[intr] ;
  wire [1:0] \neorv32_top_inst.trace_cpu0_o[mode] ;
  wire [1:0] \neorv32_top_inst.trace_cpu0_o[ixl] ;
  wire \neorv32_top_inst.trace_cpu0_o[debug] ;
  wire \neorv32_top_inst.trace_cpu0_o[compr] ;
  wire \neorv32_top_inst.trace_cpu0_o[delta] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[cmd32] ;
  wire [4:0] \neorv32_top_inst.trace_cpu0_o[rs1_addr] ;
  wire [4:0] \neorv32_top_inst.trace_cpu0_o[rs2_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[rs1_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[rs2_rdata] ;
  wire [4:0] \neorv32_top_inst.trace_cpu0_o[rd_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[rd_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[pc_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[pc_wdata] ;
  wire [11:0] \neorv32_top_inst.trace_cpu0_o[csr_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[csr_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[csr_wdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[mem_addr] ;
  wire [3:0] \neorv32_top_inst.trace_cpu0_o[mem_rmask] ;
  wire [3:0] \neorv32_top_inst.trace_cpu0_o[mem_wmask] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[mem_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu0_o[mem_wdata] ;
  wire \neorv32_top_inst.trace_cpu1_o[valid] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[order] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[insn] ;
  wire \neorv32_top_inst.trace_cpu1_o[trap] ;
  wire \neorv32_top_inst.trace_cpu1_o[halt] ;
  wire \neorv32_top_inst.trace_cpu1_o[intr] ;
  wire [1:0] \neorv32_top_inst.trace_cpu1_o[mode] ;
  wire [1:0] \neorv32_top_inst.trace_cpu1_o[ixl] ;
  wire \neorv32_top_inst.trace_cpu1_o[debug] ;
  wire \neorv32_top_inst.trace_cpu1_o[compr] ;
  wire \neorv32_top_inst.trace_cpu1_o[delta] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[cmd32] ;
  wire [4:0] \neorv32_top_inst.trace_cpu1_o[rs1_addr] ;
  wire [4:0] \neorv32_top_inst.trace_cpu1_o[rs2_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[rs1_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[rs2_rdata] ;
  wire [4:0] \neorv32_top_inst.trace_cpu1_o[rd_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[rd_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[pc_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[pc_wdata] ;
  wire [11:0] \neorv32_top_inst.trace_cpu1_o[csr_addr] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[csr_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[csr_wdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[mem_addr] ;
  wire [3:0] \neorv32_top_inst.trace_cpu1_o[mem_rmask] ;
  wire [3:0] \neorv32_top_inst.trace_cpu1_o[mem_wmask] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[mem_rdata] ;
  wire [31:0] \neorv32_top_inst.trace_cpu1_o[mem_wdata] ;
  wire \neorv32_top_inst.jtag_tdo_o ;
  wire \neorv32_top_inst.smc_ioen_o ;
  wire \neorv32_top_inst.smc_sck_o ;
  wire [1:0] \neorv32_top_inst.smc_csn_o ;
  wire \neorv32_top_inst.smc_sdo_o ;
  wire \neorv32_top_inst.slink_rx_rdy_o ;
  wire [31:0] \neorv32_top_inst.slink_tx_dat_o ;
  wire [3:0] \neorv32_top_inst.slink_tx_dst_o ;
  wire \neorv32_top_inst.slink_tx_val_o ;
  wire \neorv32_top_inst.slink_tx_lst_o ;
  wire [31:0] \neorv32_top_inst.gpio_dir_o ;
  wire [31:0] \neorv32_top_inst.gpio_o ;
  wire \neorv32_top_inst.uart0_rtsn_o ;
  wire \neorv32_top_inst.uart1_txd_o ;
  wire \neorv32_top_inst.uart1_rtsn_o ;
  wire \neorv32_top_inst.spi_clk_o ;
  wire \neorv32_top_inst.spi_dat_o ;
  wire [7:0] \neorv32_top_inst.spi_csn_o ;
  wire \neorv32_top_inst.sdi_dat_o ;
  wire \neorv32_top_inst.twi_sda_o ;
  wire \neorv32_top_inst.twi_scl_o ;
  wire \neorv32_top_inst.twd_sda_o ;
  wire \neorv32_top_inst.onewire_o ;
  wire [31:0] \neorv32_top_inst.pwm_o ;
  wire [255:0] \neorv32_top_inst.cfs_out_o ;
  wire \neorv32_top_inst.neoled_o ;
  wire [63:0] \neorv32_top_inst.mtime_time_o ;
  assign uart0_txd_o = neorv32_top_inst_n43; //(module output)
  assign xbus_adr_o = neorv32_top_inst_n22; //(module output)
  assign xbus_dat_o = neorv32_top_inst_n23; //(module output)
  assign xbus_cti_o = neorv32_top_inst_n24; //(module output)
  assign xbus_tag_o = neorv32_top_inst_n25; //(module output)
  assign xbus_we_o = neorv32_top_inst_n26; //(module output)
  assign xbus_sel_o = neorv32_top_inst_n27; //(module output)
  assign xbus_stb_o = neorv32_top_inst_n28; //(module output)
  assign xbus_cyc_o = neorv32_top_inst_n29; //(module output)
  /*# neorv32_verilog_wrapper.vhd:46:3 */
  neorv32_top_Bneorv32_top_rtl_Lneorv32_100000000_2_0_0_0_4_0_40_16384_16384_4_4_64_2048_0_1_1_1_1_1_1_1_1_1_0_1_3_5_64_1_0_1_4_1_1_1_8ed346acfd2c324525d0386b02501a8d171c513b neorv32_top_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .jtag_tck_i(1'b0),
    .jtag_tdi_i(1'b0),
    .jtag_tms_i(1'b0),
    .smc_sdi_i(1'b0),
    .xbus_dat_i(xbus_dat_i),
    .xbus_ack_i(xbus_ack_i),
    .xbus_err_i(xbus_err_i),
    .slink_rx_dat_i(32'b00000000000000000000000000000000),
    .slink_rx_src_i(4'b0000),
    .slink_rx_val_i(1'b0),
    .slink_rx_lst_i(1'b0),
    .slink_tx_rdy_i(1'b0),
    .gpio_i(32'b00000000000000000000000000000000),
    .uart0_rxd_i(uart0_rxd_i),
    .uart0_ctsn_i(1'b0),
    .uart1_rxd_i(1'b0),
    .uart1_ctsn_i(1'b0),
    .spi_dat_i(1'b0),
    .sdi_clk_i(1'b0),
    .sdi_dat_i(1'b0),
    .sdi_csn_i(1'b1),
    .twi_sda_i(1'b1),
    .twi_scl_i(1'b1),
    .twd_sda_i(1'b1),
    .twd_scl_i(1'b1),
    .onewire_i(1'b1),
    .cfs_in_i(256'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000),
    .irq_msi_i(1'b0),
    .irq_mti_i(1'b0),
    .irq_mei_i(1'b0),
    .rstn_ocd_o(),
    .rstn_wdt_o(),
    .\trace_cpu0_o[valid] (),
    .\trace_cpu0_o[order] (),
    .\trace_cpu0_o[insn] (),
    .\trace_cpu0_o[trap] (),
    .\trace_cpu0_o[halt] (),
    .\trace_cpu0_o[intr] (),
    .\trace_cpu0_o[mode] (),
    .\trace_cpu0_o[ixl] (),
    .\trace_cpu0_o[debug] (),
    .\trace_cpu0_o[compr] (),
    .\trace_cpu0_o[delta] (),
    .\trace_cpu0_o[cmd32] (),
    .\trace_cpu0_o[rs1_addr] (),
    .\trace_cpu0_o[rs2_addr] (),
    .\trace_cpu0_o[rs1_rdata] (),
    .\trace_cpu0_o[rs2_rdata] (),
    .\trace_cpu0_o[rd_addr] (),
    .\trace_cpu0_o[rd_rdata] (),
    .\trace_cpu0_o[pc_rdata] (),
    .\trace_cpu0_o[pc_wdata] (),
    .\trace_cpu0_o[csr_addr] (),
    .\trace_cpu0_o[csr_rdata] (),
    .\trace_cpu0_o[csr_wdata] (),
    .\trace_cpu0_o[mem_addr] (),
    .\trace_cpu0_o[mem_rmask] (),
    .\trace_cpu0_o[mem_wmask] (),
    .\trace_cpu0_o[mem_rdata] (),
    .\trace_cpu0_o[mem_wdata] (),
    .\trace_cpu1_o[valid] (),
    .\trace_cpu1_o[order] (),
    .\trace_cpu1_o[insn] (),
    .\trace_cpu1_o[trap] (),
    .\trace_cpu1_o[halt] (),
    .\trace_cpu1_o[intr] (),
    .\trace_cpu1_o[mode] (),
    .\trace_cpu1_o[ixl] (),
    .\trace_cpu1_o[debug] (),
    .\trace_cpu1_o[compr] (),
    .\trace_cpu1_o[delta] (),
    .\trace_cpu1_o[cmd32] (),
    .\trace_cpu1_o[rs1_addr] (),
    .\trace_cpu1_o[rs2_addr] (),
    .\trace_cpu1_o[rs1_rdata] (),
    .\trace_cpu1_o[rs2_rdata] (),
    .\trace_cpu1_o[rd_addr] (),
    .\trace_cpu1_o[rd_rdata] (),
    .\trace_cpu1_o[pc_rdata] (),
    .\trace_cpu1_o[pc_wdata] (),
    .\trace_cpu1_o[csr_addr] (),
    .\trace_cpu1_o[csr_rdata] (),
    .\trace_cpu1_o[csr_wdata] (),
    .\trace_cpu1_o[mem_addr] (),
    .\trace_cpu1_o[mem_rmask] (),
    .\trace_cpu1_o[mem_wmask] (),
    .\trace_cpu1_o[mem_rdata] (),
    .\trace_cpu1_o[mem_wdata] (),
    .jtag_tdo_o(),
    .smc_ioen_o(),
    .smc_sck_o(),
    .smc_csn_o(),
    .smc_sdo_o(),
    .xbus_adr_o(neorv32_top_inst_n22),
    .xbus_dat_o(neorv32_top_inst_n23),
    .xbus_cti_o(neorv32_top_inst_n24),
    .xbus_tag_o(neorv32_top_inst_n25),
    .xbus_we_o(neorv32_top_inst_n26),
    .xbus_sel_o(neorv32_top_inst_n27),
    .xbus_stb_o(neorv32_top_inst_n28),
    .xbus_cyc_o(neorv32_top_inst_n29),
    .slink_rx_rdy_o(),
    .slink_tx_dat_o(),
    .slink_tx_dst_o(),
    .slink_tx_val_o(),
    .slink_tx_lst_o(),
    .gpio_dir_o(),
    .gpio_o(),
    .uart0_txd_o(neorv32_top_inst_n43),
    .uart0_rtsn_o(),
    .uart1_txd_o(),
    .uart1_rtsn_o(),
    .spi_clk_o(),
    .spi_dat_o(),
    .spi_csn_o(),
    .sdi_dat_o(),
    .twi_sda_o(),
    .twi_scl_o(),
    .twd_sda_o(),
    .onewire_o(),
    .pwm_o(),
    .cfs_out_o(),
    .neoled_o(),
    .mtime_time_o());
endmodule

