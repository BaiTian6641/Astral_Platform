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
// Generated on:      2026-07-30
// Tool:              GHDL 7.0.0-dev (LLVM backend), OSS-CAD Suite
// Wrapper config:    MINIMAL skeleton = rv32imc + IMEM(16KB, ROM boot) + DMEM(16KB)
//                    + UART0 only; BOOT_MODE_SELECT=2 (IMEM image, no bootloader).
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
  wire n8047;
  reg [7:0] n8056; // mem_rd
  assign data_o = rdata; //(module output)
  /*# ../../rtl/core/neorv32_prim.vhd:190:10 */
  assign rdata = n8056; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:201:9 */
  assign n8047 = rw_i & en_i;
  reg [7:0] spram[4095:0] ; // memory
  always @(posedge clk_i)
    if (en_i)
      n8056 <= spram[addr_i];
  always @(posedge clk_i)
    if (n8047)
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
  wire [261:0] n7662;
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
  wire n7666;
  wire n7667;
  wire n7668;
  wire [6:0] n7669;
  wire n7671;
  wire n7672;
  wire n7673;
  wire n7674;
  wire n7675;
  wire n7677;
  wire n7678;
  wire n7679;
  wire n7680;
  wire n7683;
  wire [1:0] n7690;
  wire [1:0] n7694;
  wire [1:0] n7695;
  wire n7697;
  wire [4:0] n7698;
  wire [4:0] n7700;
  wire n7701;
  wire n7710;
  wire n7712;
  wire n7714;
  wire n7715;
  wire n7716;
  wire n7717;
  wire n7718;
  wire n7719;
  wire n7720;
  wire n7721;
  wire n7722;
  wire [1:0] n7724;
  wire [1:0] n7725;
  wire [1:0] n7726;
  wire n7728;
  wire n7729;
  wire [1:0] n7732;
  wire n7734;
  wire n7738;
  wire [3:0] n7739;
  reg [1:0] n7741;
  reg [4:0] n7743;
  reg n7745;
  wire [7:0] n7746;
  wire [7:0] n7748;
  wire [1:0] n7752;
  wire n7754;
  wire n7755;
  wire [2:0] n7758;
  wire n7760;
  wire [2:0] n7761;
  wire n7763;
  wire n7764;
  wire [2:0] n7765;
  wire n7767;
  wire n7768;
  wire [2:0] n7769;
  wire n7771;
  wire n7772;
  wire n7773;
  wire [2:0] n7776;
  wire n7778;
  wire [2:0] n7779;
  wire n7781;
  wire n7782;
  wire [2:0] n7783;
  wire n7785;
  wire n7786;
  wire n7787;
  wire n7790;
  wire n7791;
  wire n7792;
  wire n7793;
  wire n7796;
  wire n7797;
  wire n7798;
  wire n7801;
  wire [1:0] n7804;
  wire n7806;
  wire n7807;
  wire n7808;
  wire n7809;
  wire [30:0] n7810;
  wire [63:0] n7811;
  wire [63:0] n7812;
  wire [63:0] n7813;
  wire [63:0] n7814;
  wire n7822;
  wire n7823;
  wire n7824;
  wire n7825;
  wire [32:0] n7826;
  wire n7827;
  wire [1:0] n7828;
  wire n7830;
  wire n7831;
  wire [31:0] n7832;
  wire [32:0] n7833;
  wire [32:0] n7834;
  wire [31:0] n7835;
  wire [32:0] n7836;
  wire [32:0] n7837;
  wire [32:0] n7838;
  wire [31:0] n7839;
  wire [32:0] n7840;
  wire [32:0] n7841;
  wire n7844;
  wire n7852;
  wire n7853;
  wire [31:0] n7855;
  wire [31:0] n7856;
  wire n7864;
  wire n7865;
  wire [31:0] n7867;
  wire [31:0] n7868;
  wire [1:0] n7870;
  wire n7877;
  wire n7879;
  wire n7881;
  wire n7882;
  wire n7883;
  wire n7884;
  wire n7885;
  wire n7886;
  wire n7887;
  wire n7888;
  wire n7889;
  wire n7890;
  wire n7891;
  wire n7892;
  wire n7893;
  wire n7894;
  wire n7895;
  wire n7896;
  wire n7897;
  wire n7898;
  wire n7899;
  wire n7900;
  wire n7901;
  wire n7902;
  wire n7903;
  wire n7904;
  wire n7905;
  wire n7906;
  wire n7907;
  wire n7908;
  wire n7909;
  wire n7910;
  wire n7911;
  wire n7912;
  wire n7913;
  wire n7914;
  wire n7915;
  wire n7916;
  wire n7917;
  wire n7918;
  wire n7919;
  wire n7920;
  wire n7921;
  wire n7922;
  wire n7923;
  wire n7924;
  wire n7925;
  wire n7926;
  wire n7927;
  wire n7928;
  wire n7929;
  wire n7930;
  wire n7931;
  wire n7932;
  wire n7933;
  wire n7934;
  wire n7935;
  wire n7936;
  wire n7937;
  wire n7938;
  wire n7939;
  wire n7940;
  wire n7941;
  wire n7942;
  wire n7943;
  wire n7944;
  wire n7945;
  wire n7946;
  wire n7948;
  wire n7949;
  wire n7951;
  wire [1:0] n7952;
  reg n7954;
  wire [1:0] n7955;
  wire n7957;
  wire [1:0] n7958;
  wire n7960;
  wire n7961;
  wire [30:0] n7962;
  wire n7963;
  wire n7964;
  wire [31:0] n7965;
  wire n7966;
  wire n7967;
  wire [31:0] n7968;
  wire [30:0] n7969;
  wire n7970;
  wire [31:0] n7971;
  wire [31:0] n7972;
  wire [31:0] n7973;
  wire [31:0] n7974;
  wire [31:0] n7976;
  wire [31:0] n7978;
  wire [30:0] n7993;
  wire [31:0] n7995;
  wire n7996;
  wire [32:0] n7997;
  wire [32:0] n7999;
  wire [32:0] n8000;
  wire [1:0] n8001;
  wire n8003;
  wire [31:0] n8004;
  wire [31:0] n8006;
  wire [31:0] n8007;
  wire n8009;
  wire [2:0] n8010;
  wire [31:0] n8011;
  wire n8013;
  wire [31:0] n8014;
  wire n8016;
  wire n8018;
  wire n8019;
  wire n8021;
  wire n8022;
  wire [1:0] n8023;
  reg [31:0] n8024;
  wire [31:0] n8026;
  reg [7:0] n8029;
  wire [31:0] n8030;
  reg [31:0] n8031;
  reg [31:0] n8032;
  reg [31:0] n8033;
  wire n8034;
  reg n8035;
  reg [63:0] n8036;
  assign res_o = n8026; //(module output)
  assign valid_o = n7755; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:23:8 */
  assign n7662 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:68:10 */
  assign valid_cmd = n7680; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign ctrl = n8029; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:78:10 */
  assign rs1_signed = n7773; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:78:22 */
  assign rs2_signed = n7787; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:81:10 */
  assign div_start = n7798; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:82:10 */
  assign div_divi = n8031; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:83:10 */
  assign div_quot = n8032; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:84:10 */
  assign div_rema = n8033; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:85:10 */
  assign div_sign = n8035; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:86:10 */
  assign div_sub = n8000; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:87:10 */
  assign div_res_u = n8004; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:88:10 */
  assign div_res = n8007; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:91:10 */
  assign mul_start = n7793; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:92:10 */
  assign mul_res = n8036; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:93:10 */
  assign mul_add = n7841; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:33 */
  assign n7666 = n7662[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:22 */
  assign n7667 = n7662[240]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:51 */
  assign n7668 = n7667 & n7666;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:55 */
  assign n7669 = n7662[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:69 */
  assign n7671 = n7669 == 7'b0000001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:33 */
  assign n7672 = n7671 & n7668;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:23 */
  assign n7673 = n7662[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:27 */
  assign n7674 = ~n7673;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:55 */
  assign n7675 = n7662[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:66 */
  assign n7677 = 1'b1 & n7675;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:101:34 */
  assign n7678 = n7674 | n7677;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:100:82 */
  assign n7679 = n7678 & n7672;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:99:20 */
  assign n7680 = n7679 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:108:16 */
  assign n7683 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:17 */
  assign n7690 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign n7694 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:122:11 */
  assign n7695 = valid_cmd ? 2'b01 : n7694;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:120:9 */
  assign n7697 = n7690 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:136:55 */
  assign n7698 = ctrl[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:136:60 */
  assign n7700 = n7698 - 5'b00001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:137:22 */
  assign n7701 = n7662[259]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7710 = ctrl[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7712 = 1'b0 | n7710;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7714 = ctrl[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7715 = n7712 | n7714;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7716 = ctrl[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7717 = n7715 | n7716;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7718 = ctrl[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7719 = n7717 | n7718;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7720 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7721 = n7719 | n7720;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:139:40 */
  assign n7722 = ~n7721;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:77:10 */
  assign n7724 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:139:11 */
  assign n7725 = n7722 ? 2'b11 : n7724;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:137:11 */
  assign n7726 = n7701 ? 2'b00 : n7725;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:134:9 */
  assign n7728 = n7690 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:145:22 */
  assign n7729 = n7662[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:145:11 */
  assign n7732 = n7729 ? 2'b00 : 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:143:9 */
  assign n7734 = n7690 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:151:9 */
  assign n7738 = n7690 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  assign n7739 = {n7738, n7734, n7728, n7697};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7739)
      4'b1000: n7741 = 2'b00;
      4'b0100: n7741 = n7732;
      4'b0010: n7741 = n7726;
      4'b0001: n7741 = n7695;
      default: n7741 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7739)
      4'b1000: n7743 = 5'b11110;
      4'b0100: n7743 = 5'b11110;
      4'b0010: n7743 = n7700;
      4'b0001: n7743 = 5'b11110;
      default: n7743 = 5'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:118:7 */
  always @*
    case (n7739)
      4'b1000: n7745 = 1'b1;
      4'b0100: n7745 = 1'b0;
      4'b0010: n7745 = 1'b0;
      4'b0001: n7745 = 1'b0;
      default: n7745 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:112:5 */
  assign n7746 = {n7745, n7743, n7741};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:108:5 */
  assign n7748 = {1'b0, 5'b00000, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:29 */
  assign n7752 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:35 */
  assign n7754 = n7752 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:161:18 */
  assign n7755 = n7754 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:34 */
  assign n7758 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:44 */
  assign n7760 = n7758 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:68 */
  assign n7761 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:78 */
  assign n7763 = n7761 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:57 */
  assign n7764 = n7760 | n7763;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:34 */
  assign n7765 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:44 */
  assign n7767 = n7765 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:93 */
  assign n7768 = n7764 | n7767;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:68 */
  assign n7769 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:78 */
  assign n7771 = n7769 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:165:57 */
  assign n7772 = n7768 | n7771;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:164:21 */
  assign n7773 = n7772 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:34 */
  assign n7776 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:44 */
  assign n7778 = n7776 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:34 */
  assign n7779 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:44 */
  assign n7781 = n7779 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:57 */
  assign n7782 = n7778 | n7781;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:68 */
  assign n7783 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:78 */
  assign n7785 = n7783 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:167:57 */
  assign n7786 = n7782 | n7785;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:166:21 */
  assign n7787 = n7786 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:64 */
  assign n7790 = n7662[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:68 */
  assign n7791 = ~n7790;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:43 */
  assign n7792 = n7791 & valid_cmd;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:170:20 */
  assign n7793 = n7792 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:64 */
  assign n7796 = n7662[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:43 */
  assign n7797 = n7796 & valid_cmd;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:171:20 */
  assign n7798 = n7797 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:205:18 */
  assign n7801 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:21 */
  assign n7804 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:27 */
  assign n7806 = n7804 != 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:59 */
  assign n7807 = n7662[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:63 */
  assign n7808 = ~n7807;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:38 */
  assign n7809 = n7808 & n7806;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:213:43 */
  assign n7810 = mul_res[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:9 */
  assign n7811 = {mul_add, n7810};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:211:9 */
  assign n7812 = n7809 ? n7811 : mul_res;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:208:9 */
  assign n7813 = {32'b00000000000000000000000000000000, rs1_i};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:208:9 */
  assign n7814 = mul_start ? n7813 : n7812;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:223:24 */
  assign n7822 = mul_res[63]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:223:39 */
  assign n7823 = n7822 & rs2_signed;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:32 */
  assign n7824 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:45 */
  assign n7825 = n7824 & rs2_signed;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:224:61 */
  assign n7826 = {n7825, rs2_i};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:225:18 */
  assign n7827 = mul_res[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:18 */
  assign n7828 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:24 */
  assign n7830 = n7828 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:34 */
  assign n7831 = rs1_signed & n7830;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:65 */
  assign n7832 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:56 */
  assign n7833 = {n7823, n7832};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:227:81 */
  assign n7834 = n7833 - n7826;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:65 */
  assign n7835 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:56 */
  assign n7836 = {n7823, n7835};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:229:81 */
  assign n7837 = n7836 + n7826;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:226:9 */
  assign n7838 = n7831 ? n7834 : n7837;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:232:36 */
  assign n7839 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:232:27 */
  assign n7840 = {n7823, n7839};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:225:7 */
  assign n7841 = n7827 ? n7838 : n7840;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:247:18 */
  assign n7844 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:14 */
  assign n7852 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:34 */
  assign n7853 = rs2_signed & n7852;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:50:36 */
  assign n7855 = 32'b00000000000000000000000000000000 - rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:5 */
  assign n7856 = n7853 ? n7855 : rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:14 */
  assign n7864 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:34 */
  assign n7865 = rs1_signed & n7864;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:50:36 */
  assign n7867 = 32'b00000000000000000000000000000000 - rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:49:5 */
  assign n7868 = n7865 ? n7867 : rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:32 */
  assign n7870 = n7662[221:220]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7877 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7879 = 1'b0 | n7877;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7881 = rs2_i[30]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7882 = n7879 | n7881;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7883 = rs2_i[29]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7884 = n7882 | n7883;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7885 = rs2_i[28]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7886 = n7884 | n7885;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7887 = rs2_i[27]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7888 = n7886 | n7887;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7889 = rs2_i[26]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7890 = n7888 | n7889;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7891 = rs2_i[25]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7892 = n7890 | n7891;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7893 = rs2_i[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7894 = n7892 | n7893;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7895 = rs2_i[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7896 = n7894 | n7895;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7897 = rs2_i[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7898 = n7896 | n7897;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7899 = rs2_i[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7900 = n7898 | n7899;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7901 = rs2_i[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7902 = n7900 | n7901;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7903 = rs2_i[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7904 = n7902 | n7903;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7905 = rs2_i[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7906 = n7904 | n7905;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7907 = rs2_i[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7908 = n7906 | n7907;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7909 = rs2_i[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7910 = n7908 | n7909;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7911 = rs2_i[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7912 = n7910 | n7911;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7913 = rs2_i[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7914 = n7912 | n7913;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7915 = rs2_i[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7916 = n7914 | n7915;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7917 = rs2_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7918 = n7916 | n7917;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7919 = rs2_i[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7920 = n7918 | n7919;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7921 = rs2_i[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7922 = n7920 | n7921;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7923 = rs2_i[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7924 = n7922 | n7923;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7925 = rs2_i[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7926 = n7924 | n7925;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7927 = rs2_i[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7928 = n7926 | n7927;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7929 = rs2_i[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7930 = n7928 | n7929;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7931 = rs2_i[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7932 = n7930 | n7931;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7933 = rs2_i[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7934 = n7932 | n7933;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7935 = rs2_i[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7936 = n7934 | n7935;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7937 = rs2_i[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7938 = n7936 | n7937;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7939 = rs2_i[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7940 = n7938 | n7939;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7941 = rs2_i[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7942 = n7940 | n7941;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:69 */
  assign n7943 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:91 */
  assign n7944 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:82 */
  assign n7945 = n7943 ^ n7944;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:59 */
  assign n7946 = n7942 & n7945;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:258:13 */
  assign n7948 = n7870 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:259:45 */
  assign n7949 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:259:13 */
  assign n7951 = n7870 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:11 */
  assign n7952 = {n7951, n7948};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:257:11 */
  always @*
    case (n7952)
      2'b10: n7954 = n7949;
      2'b01: n7954 = n7946;
      default: n7954 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:21 */
  assign n7955 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:27 */
  assign n7957 = n7955 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:46 */
  assign n7958 = ctrl[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:52 */
  assign n7960 = n7958 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:37 */
  assign n7961 = n7957 | n7960;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:31 */
  assign n7962 = div_quot[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:59 */
  assign n7963 = div_sub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:48 */
  assign n7964 = ~n7963;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:263:45 */
  assign n7965 = {n7962, n7964};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:22 */
  assign n7966 = div_sub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:27 */
  assign n7967 = ~n7966;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:265:32 */
  assign n7968 = div_sub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:33 */
  assign n7969 = div_rema[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:57 */
  assign n7970 = div_quot[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:267:47 */
  assign n7971 = {n7969, n7970};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:264:11 */
  assign n7972 = n7967 ? n7968 : n7971;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:9 */
  assign n7973 = n7961 ? n7965 : div_quot;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:262:9 */
  assign n7974 = n7961 ? n7972 : div_rema;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:253:9 */
  assign n7976 = div_start ? n7868 : n7973;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:253:9 */
  assign n7978 = div_start ? 32'b00000000000000000000000000000000 : n7974;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:57 */
  assign n7993 = div_rema[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:47 */
  assign n7995 = {1'b0, n7993};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:81 */
  assign n7996 = div_quot[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:71 */
  assign n7997 = {n7995, n7996};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:102 */
  assign n7999 = {1'b0, div_divi};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:274:87 */
  assign n8000 = n7997 - n7999;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:49 */
  assign n8001 = n7662[222:221]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:62 */
  assign n8003 = n8001 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:277:27 */
  assign n8004 = n8003 ? div_quot : div_rema;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:278:38 */
  assign n8006 = 32'b00000000000000000000000000000000 - div_res_u;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:278:61 */
  assign n8007 = div_sign ? n8006 : div_res_u;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:300:14 */
  assign n8009 = ctrl[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:19 */
  assign n8010 = n7662[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:303:27 */
  assign n8011 = mul_res[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:302:9 */
  assign n8013 = n8010 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:305:27 */
  assign n8014 = mul_res[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:9 */
  assign n8016 = n8010 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:24 */
  assign n8018 = n8010 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:24 */
  assign n8019 = n8016 | n8018;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:38 */
  assign n8021 = n8010 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:304:38 */
  assign n8022 = n8019 | n8021;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:7 */
  assign n8023 = {n8022, n8013};
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:301:7 */
  always @*
    case (n8023)
      2'b10: n8024 = n8014;
      2'b01: n8024 = n8011;
      default: n8024 = div_res;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:300:5 */
  assign n8026 = n8009 ? n8024 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:112:5 */
  always @(posedge clk_i or posedge n7683)
    if (n7683)
      n8029 <= n7748;
    else
      n8029 <= n7746;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  assign n8030 = div_start ? n7856 : div_divi;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7844)
    if (n7844)
      n8031 <= 32'b00000000000000000000000000000000;
    else
      n8031 <= n8030;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7844)
    if (n7844)
      n8032 <= 32'b00000000000000000000000000000000;
    else
      n8032 <= n7976;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7844)
    if (n7844)
      n8033 <= 32'b00000000000000000000000000000000;
    else
      n8033 <= n7978;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  assign n8034 = div_start ? n7954 : div_sign;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:252:7 */
  always @(posedge clk_i or posedge n7844)
    if (n7844)
      n8035 <= 1'b0;
    else
      n8035 <= n8034;
  /*# ../../rtl/core/neorv32_cpu_alu_muldiv.vhd:207:7 */
  always @(posedge clk_i or posedge n7801)
    if (n7801)
      n8036 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    else
      n8036 <= n7814;
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
  wire [261:0] n7546;
  wire valid_cmd;
  wire busy;
  wire done;
  wire oe;
  wire [4:0] cnt;
  wire [31:0] sreg;
  wire n7550;
  wire [2:0] n7551;
  wire n7553;
  wire [6:0] n7554;
  wire n7556;
  wire n7557;
  wire [2:0] n7558;
  wire n7560;
  wire [6:0] n7561;
  wire n7563;
  wire n7564;
  wire n7565;
  wire [2:0] n7566;
  wire n7568;
  wire [6:0] n7569;
  wire n7571;
  wire n7572;
  wire n7573;
  wire n7574;
  wire n7575;
  wire n7578;
  wire n7580;
  wire n7581;
  wire n7583;
  wire n7585;
  wire n7586;
  wire n7593;
  wire n7595;
  wire n7597;
  wire n7598;
  wire n7599;
  wire n7600;
  wire n7601;
  wire n7602;
  wire n7603;
  wire n7604;
  wire [4:0] n7606;
  wire n7607;
  wire n7608;
  wire [30:0] n7609;
  wire [31:0] n7611;
  wire n7612;
  wire n7613;
  wire n7614;
  wire [30:0] n7615;
  wire [31:0] n7616;
  wire [31:0] n7617;
  wire [4:0] n7618;
  wire [31:0] n7619;
  wire [4:0] n7620;
  wire [31:0] n7621;
  wire n7642;
  wire n7644;
  wire n7646;
  wire n7647;
  wire n7648;
  wire n7649;
  wire n7650;
  wire n7651;
  wire n7652;
  wire n7653;
  wire [31:0] n7654;
  reg n7658;
  reg n7659;
  reg [4:0] n7660;
  reg [31:0] n7661;
  assign res_o = n7654; //(module output)
  assign valid_o = n7653; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:21:8 */
  assign n7546 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:42:10 */
  assign valid_cmd = n7575; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:10 */
  assign busy = n7658; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:21 */
  assign done = n7652; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:45:27 */
  assign oe = n7659; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:46:10 */
  assign cnt = n7660; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:47:10 */
  assign sreg = n7661; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:33 */
  assign n7550 = n7546[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:14 */
  assign n7551 = n7546[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:24 */
  assign n7553 = n7551 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:62 */
  assign n7554 = n7546[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:76 */
  assign n7556 = n7554 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:40 */
  assign n7557 = n7556 & n7553;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:14 */
  assign n7558 = n7546[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:24 */
  assign n7560 = n7558 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:62 */
  assign n7561 = n7546[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:76 */
  assign n7563 = n7561 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:40 */
  assign n7564 = n7563 & n7560;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:58:90 */
  assign n7565 = n7557 | n7564;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:14 */
  assign n7566 = n7546[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:24 */
  assign n7568 = n7566 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:62 */
  assign n7569 = n7546[234:228]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:76 */
  assign n7571 = n7569 == 7'b0100000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:60:40 */
  assign n7572 = n7571 & n7568;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:59:90 */
  assign n7573 = n7565 | n7572;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:51 */
  assign n7574 = n7573 & n7550;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:57:20 */
  assign n7575 = n7574 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:69:18 */
  assign n7578 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:39 */
  assign n7580 = n7546[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:28 */
  assign n7581 = done | n7580;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:78:9 */
  assign n7583 = n7581 ? 1'b0 : busy;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:76:9 */
  assign n7585 = valid_cmd ? 1'b1 : n7583;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:81:20 */
  assign n7586 = busy & done;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7593 = cnt[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7595 = 1'b0 | n7593;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7597 = cnt[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7598 = n7595 | n7597;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7599 = cnt[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7600 = n7598 | n7599;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7601 = cnt[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7602 = n7600 | n7601;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7603 = cnt[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7604 = n7602 | n7603;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:87:50 */
  assign n7606 = cnt - 5'b00001;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:31 */
  assign n7607 = n7546[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:35 */
  assign n7608 = ~n7607;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:89:25 */
  assign n7609 = sreg[30:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:89:48 */
  assign n7611 = {n7609, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:26 */
  assign n7612 = sreg[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:59 */
  assign n7613 = n7546[233]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:38 */
  assign n7614 = n7612 & n7613;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:71 */
  assign n7615 = sreg[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:91:65 */
  assign n7616 = {n7614, n7615};
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:88:11 */
  assign n7617 = n7608 ? n7611 : n7616;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:86:9 */
  assign n7618 = n7604 ? n7606 : cnt;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:86:9 */
  assign n7619 = n7604 ? n7617 : sreg;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:83:9 */
  assign n7620 = valid_cmd ? shamt_i : n7618;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:83:9 */
  assign n7621 = valid_cmd ? rs1_i : n7619;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7642 = cnt[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7644 = 1'b0 | n7642;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7646 = cnt[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7647 = n7644 | n7646;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7648 = cnt[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7649 = n7647 | n7648;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n7650 = cnt[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n7651 = n7649 | n7650;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:98:16 */
  assign n7652 = ~n7651;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:99:21 */
  assign n7653 = busy & done;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:100:21 */
  assign n7654 = oe ? sreg : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7578)
    if (n7578)
      n7658 <= 1'b0;
    else
      n7658 <= n7585;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7578)
    if (n7578)
      n7659 <= 1'b0;
    else
      n7659 <= n7586;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7578)
    if (n7578)
      n7660 <= 5'b00000;
    else
      n7660 <= n7620;
  /*# ../../rtl/core/neorv32_cpu_alu_shifter.vhd:74:7 */
  always @(posedge clk_i or posedge n7578)
    if (n7578)
      n7661 <= 32'b00000000000000000000000000000000;
    else
      n7661 <= n7621;
endmodule

module neorv32_cpu_decompressor_Bneorv32_cpu_decompressor_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29
  (input  [15:0] instr_i,
   output [31:0] instr_o);
  wire illegal;
  wire [31:0] decoded;
  wire [1:0] n7013;
  wire [2:0] n7014;
  wire [2:0] n7017;
  wire [4:0] n7019;
  wire [3:0] n7021;
  wire [5:0] n7023;
  wire [1:0] n7024;
  wire [7:0] n7025;
  wire n7026;
  wire [8:0] n7027;
  wire n7028;
  wire [9:0] n7029;
  wire [11:0] n7031;
  wire [7:0] n7032;
  wire n7034;
  wire n7037;
  wire n7039;
  wire n7041;
  wire [5:0] n7043;
  wire [2:0] n7044;
  wire [8:0] n7045;
  wire n7046;
  wire [9:0] n7047;
  wire [11:0] n7049;
  wire [2:0] n7051;
  wire [4:0] n7053;
  wire [2:0] n7054;
  wire [4:0] n7056;
  wire n7058;
  wire n7060;
  wire [5:0] n7062;
  wire n7063;
  wire [6:0] n7064;
  wire [1:0] n7065;
  wire n7066;
  wire [2:0] n7067;
  wire [4:0] n7069;
  wire [2:0] n7071;
  wire [4:0] n7073;
  wire [2:0] n7074;
  wire [4:0] n7076;
  wire n7078;
  wire n7080;
  wire [3:0] n7081;
  reg n7085;
  reg [6:0] n7087;
  reg [4:0] n7089;
  reg [2:0] n7091;
  reg [4:0] n7093;
  wire [4:0] n7094;
  wire [4:0] n7095;
  reg [4:0] n7097;
  wire [6:0] n7098;
  wire [6:0] n7099;
  reg [6:0] n7101;
  wire n7103;
  wire [2:0] n7104;
  wire n7105;
  wire n7106;
  wire [4:0] n7108;
  wire n7110;
  wire n7111;
  wire [1:0] n7112;
  wire [1:0] n7113;
  wire [3:0] n7114;
  wire n7115;
  wire [4:0] n7116;
  wire n7117;
  wire [5:0] n7118;
  wire n7119;
  wire [6:0] n7120;
  wire n7121;
  wire [7:0] n7122;
  wire [2:0] n7123;
  wire [10:0] n7124;
  wire n7125;
  wire [11:0] n7126;
  wire n7128;
  wire [7:0] n7134;
  wire [19:0] n7136;
  wire n7138;
  wire n7140;
  wire n7141;
  wire n7142;
  wire [2:0] n7144;
  wire [2:0] n7146;
  wire [4:0] n7148;
  wire n7151;
  wire [3:0] n7157;
  wire [1:0] n7159;
  wire [5:0] n7160;
  wire n7161;
  wire [6:0] n7162;
  wire [1:0] n7163;
  wire [1:0] n7164;
  wire [3:0] n7165;
  wire n7166;
  wire [4:0] n7167;
  wire n7169;
  wire n7171;
  wire n7172;
  wire [4:0] n7174;
  wire n7176;
  wire [6:0] n7182;
  wire [4:0] n7184;
  wire [11:0] n7185;
  wire n7187;
  wire [4:0] n7188;
  wire n7190;
  wire n7194;
  wire [2:0] n7200;
  wire [1:0] n7202;
  wire [4:0] n7203;
  wire n7204;
  wire [5:0] n7205;
  wire n7206;
  wire [6:0] n7207;
  wire n7208;
  wire [7:0] n7209;
  wire [11:0] n7211;
  wire [4:0] n7213;
  wire n7215;
  wire [14:0] n7221;
  wire [4:0] n7223;
  wire [19:0] n7224;
  wire [31:0] n7225;
  wire [31:0] n7226;
  wire [31:0] n7227;
  wire [4:0] n7228;
  wire n7230;
  wire n7231;
  wire n7232;
  wire n7233;
  wire n7235;
  wire n7238;
  wire n7240;
  wire [4:0] n7241;
  wire [4:0] n7242;
  wire n7244;
  wire [6:0] n7250;
  wire [4:0] n7252;
  wire [11:0] n7253;
  wire n7255;
  wire [2:0] n7256;
  wire [4:0] n7258;
  wire [2:0] n7259;
  wire [4:0] n7261;
  wire [2:0] n7262;
  wire [4:0] n7264;
  wire [1:0] n7265;
  wire n7266;
  wire [1:0] n7268;
  wire [6:0] n7270;
  wire [4:0] n7272;
  wire n7274;
  wire n7276;
  wire n7277;
  wire n7280;
  wire [6:0] n7286;
  wire [4:0] n7288;
  wire [11:0] n7289;
  wire n7291;
  wire [1:0] n7293;
  wire n7295;
  wire n7297;
  wire n7300;
  wire n7302;
  wire n7303;
  wire n7304;
  wire n7309;
  wire [2:0] n7311;
  wire [6:0] n7313;
  wire n7315;
  wire n7316;
  wire n7317;
  wire n7321;
  wire [2:0] n7323;
  wire [6:0] n7325;
  wire [2:0] n7326;
  reg n7327;
  reg [2:0] n7328;
  reg [6:0] n7329;
  wire [1:0] n7330;
  reg n7332;
  reg [6:0] n7333;
  reg [2:0] n7334;
  wire [4:0] n7335;
  reg [4:0] n7336;
  wire [6:0] n7337;
  reg [6:0] n7338;
  wire [4:0] n7339;
  reg n7341;
  wire [6:0] n7342;
  reg [6:0] n7343;
  wire [4:0] n7344;
  reg [4:0] n7345;
  wire [2:0] n7346;
  wire [2:0] n7347;
  reg [2:0] n7348;
  wire [4:0] n7349;
  wire [4:0] n7350;
  reg [4:0] n7351;
  wire [4:0] n7352;
  wire [4:0] n7353;
  wire [4:0] n7354;
  wire [4:0] n7355;
  reg [4:0] n7356;
  wire [6:0] n7357;
  wire [6:0] n7358;
  wire [6:0] n7359;
  wire [6:0] n7360;
  reg [6:0] n7361;
  wire n7363;
  wire [2:0] n7364;
  wire [4:0] n7365;
  wire [4:0] n7366;
  wire [4:0] n7369;
  wire n7370;
  wire n7373;
  wire n7375;
  wire [1:0] n7376;
  wire [5:0] n7378;
  wire n7379;
  wire [6:0] n7380;
  wire [2:0] n7381;
  wire [9:0] n7382;
  wire [11:0] n7384;
  wire [4:0] n7386;
  wire n7387;
  wire [4:0] n7388;
  wire n7390;
  wire n7391;
  wire n7394;
  wire n7396;
  wire n7398;
  wire n7399;
  wire [1:0] n7400;
  wire [5:0] n7402;
  wire n7403;
  wire [6:0] n7404;
  wire [2:0] n7405;
  wire [4:0] n7407;
  wire [4:0] n7409;
  wire n7410;
  wire n7413;
  wire n7415;
  wire n7417;
  wire n7418;
  wire n7419;
  wire n7420;
  wire [4:0] n7421;
  wire n7423;
  wire [4:0] n7425;
  wire [4:0] n7427;
  wire n7429;
  wire n7432;
  wire [4:0] n7434;
  wire [4:0] n7436;
  wire n7438;
  wire [24:0] n7439;
  wire [11:0] n7440;
  wire [11:0] n7441;
  wire [11:0] n7442;
  wire [2:0] n7443;
  wire [2:0] n7445;
  wire [4:0] n7446;
  wire [4:0] n7447;
  wire [4:0] n7448;
  wire [4:0] n7450;
  wire [4:0] n7451;
  wire n7453;
  wire [4:0] n7454;
  wire n7456;
  wire [4:0] n7459;
  wire [11:0] n7461;
  wire [6:0] n7462;
  wire [6:0] n7463;
  wire [4:0] n7464;
  wire [4:0] n7466;
  wire [4:0] n7468;
  wire [11:0] n7470;
  wire [4:0] n7472;
  wire [4:0] n7473;
  wire [4:0] n7474;
  wire [24:0] n7475;
  wire [11:0] n7476;
  wire [16:0] n7477;
  wire [11:0] n7478;
  wire [11:0] n7479;
  wire [2:0] n7480;
  wire [2:0] n7482;
  wire [9:0] n7483;
  wire [9:0] n7484;
  wire [9:0] n7485;
  wire [6:0] n7486;
  wire [6:0] n7488;
  wire n7490;
  wire [31:0] n7491;
  wire [24:0] n7492;
  wire [24:0] n7493;
  wire [24:0] n7494;
  wire [6:0] n7495;
  wire [6:0] n7497;
  wire n7499;
  wire [3:0] n7500;
  reg n7502;
  wire [6:0] n7503;
  reg [6:0] n7505;
  wire [4:0] n7506;
  reg [4:0] n7508;
  wire [2:0] n7509;
  reg [2:0] n7511;
  wire [4:0] n7512;
  reg [4:0] n7514;
  wire [4:0] n7515;
  wire [4:0] n7516;
  reg [4:0] n7518;
  wire [6:0] n7519;
  reg [6:0] n7521;
  wire [1:0] n7522;
  reg n7523;
  reg [6:0] n7525;
  reg [4:0] n7526;
  reg [2:0] n7527;
  reg [4:0] n7528;
  reg [4:0] n7529;
  reg [6:0] n7530;
  wire [29:0] n7538;
  wire n7539;
  wire n7540;
  wire n7541;
  wire [30:0] n7542;
  wire n7543;
  wire [31:0] n7544;
  wire [31:0] n7545;
  assign instr_o = n7544; //(module output)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:54:10 */
  assign illegal = n7523; // (signal)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:55:10 */
  assign decoded = n7545; // (signal)
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:17 */
  assign n7013 = instr_i[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:21 */
  assign n7014 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:77:84 */
  assign n7017 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:77:75 */
  assign n7019 = {2'b01, n7017};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:84 */
  assign n7021 = instr_i[10:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:75 */
  assign n7023 = {2'b00, n7021};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:107 */
  assign n7024 = instr_i[12:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:98 */
  assign n7025 = {n7023, n7024};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:131 */
  assign n7026 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:122 */
  assign n7027 = {n7025, n7026};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:144 */
  assign n7028 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:135 */
  assign n7029 = {n7027, n7028};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7031 = {n7029, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:24 */
  assign n7032 = instr_i[12:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:38 */
  assign n7034 = n7032 == 8'b00000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:80:13 */
  assign n7037 = n7034 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:73:11 */
  assign n7039 = n7014 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:87 */
  assign n7041 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:78 */
  assign n7043 = {5'b00000, n7041};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:100 */
  assign n7044 = instr_i[12:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:91 */
  assign n7045 = {n7043, n7044};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:124 */
  assign n7046 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:115 */
  assign n7047 = {n7045, n7046};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7049 = {n7047, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:89:84 */
  assign n7051 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:89:75 */
  assign n7053 = {2'b01, n7051};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:90:84 */
  assign n7054 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:90:75 */
  assign n7056 = {2'b01, n7054};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:84:11 */
  assign n7058 = n7014 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:87 */
  assign n7060 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:78 */
  assign n7062 = {5'b00000, n7060};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:100 */
  assign n7063 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:95:91 */
  assign n7064 = {n7062, n7063};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:77 */
  assign n7065 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:101 */
  assign n7066 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:92 */
  assign n7067 = {n7065, n7066};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:96:105 */
  assign n7069 = {n7067, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:98:84 */
  assign n7071 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:98:75 */
  assign n7073 = {2'b01, n7071};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:99:84 */
  assign n7074 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:99:75 */
  assign n7076 = {2'b01, n7074};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:92:11 */
  assign n7078 = n7014 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:101:11 */
  assign n7080 = n7014 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  assign n7081 = {n7080, n7078, n7058, n7039};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7085 = 1'b1;
      4'b0100: n7085 = 1'b0;
      4'b0010: n7085 = 1'b0;
      4'b0001: n7085 = n7037;
      default: n7085 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7087 = 7'b0000011;
      4'b0100: n7087 = 7'b0100011;
      4'b0010: n7087 = 7'b0000011;
      4'b0001: n7087 = 7'b0010011;
      default: n7087 = 7'b0000011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7089 = 5'b00000;
      4'b0100: n7089 = n7069;
      4'b0010: n7089 = n7056;
      4'b0001: n7089 = n7019;
      default: n7089 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7091 = 3'b000;
      4'b0100: n7091 = 3'b010;
      4'b0010: n7091 = 3'b010;
      4'b0001: n7091 = 3'b000;
      default: n7091 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7093 = 5'b00000;
      4'b0100: n7093 = n7073;
      4'b0010: n7093 = n7053;
      4'b0001: n7093 = 5'b00010;
      default: n7093 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7094 = n7031[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7095 = n7049[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7097 = 5'b00000;
      4'b0100: n7097 = n7076;
      4'b0010: n7097 = n7095;
      4'b0001: n7097 = n7094;
      default: n7097 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:79:148 */
  assign n7098 = n7031[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:87:128 */
  assign n7099 = n7049[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:71:9 */
  always @*
    case (n7081)
      4'b1000: n7101 = 7'b0000000;
      4'b0100: n7101 = n7064;
      4'b0010: n7101 = n7099;
      4'b0001: n7101 = n7098;
      default: n7101 = 7'b0000000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:70:7 */
  assign n7103 = n7013 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:21 */
  assign n7104 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:91 */
  assign n7105 = instr_i[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:80 */
  assign n7106 = ~n7105;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:146:77 */
  assign n7108 = {4'b0000, n7106};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:77 */
  assign n7110 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:91 */
  assign n7111 = instr_i[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:82 */
  assign n7112 = {n7110, n7111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:104 */
  assign n7113 = instr_i[10:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:95 */
  assign n7114 = {n7112, n7113};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:127 */
  assign n7115 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:118 */
  assign n7116 = {n7114, n7115};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:140 */
  assign n7117 = instr_i[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:131 */
  assign n7118 = {n7116, n7117};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:77 */
  assign n7119 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:148:144 */
  assign n7120 = {n7118, n7119};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:90 */
  assign n7121 = instr_i[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:81 */
  assign n7122 = {n7120, n7121};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:104 */
  assign n7123 = instr_i[5:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:95 */
  assign n7124 = {n7122, n7123};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:126 */
  assign n7125 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:117 */
  assign n7126 = {n7124, n7125};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:152 */
  assign n7128 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7134 = {n7128, n7128, n7128, n7128, n7128, n7128, n7128, n7128};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7136 = {n7126, n7134};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:11 */
  assign n7138 = n7104 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:22 */
  assign n7140 = n7104 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:144:22 */
  assign n7141 = n7138 | n7140;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:153:84 */
  assign n7142 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:153:75 */
  assign n7144 = {2'b00, n7142};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:155:84 */
  assign n7146 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:155:75 */
  assign n7148 = {2'b01, n7146};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:89 */
  assign n7151 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7157 = {n7151, n7151, n7151, n7151};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:107 */
  assign n7159 = instr_i[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:98 */
  assign n7160 = {n7157, n7159};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:129 */
  assign n7161 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:157:120 */
  assign n7162 = {n7160, n7161};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:77 */
  assign n7163 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:101 */
  assign n7164 = instr_i[4:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:92 */
  assign n7165 = {n7163, n7164};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:123 */
  assign n7166 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:158:114 */
  assign n7167 = {n7165, n7166};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:11 */
  assign n7169 = n7104 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:22 */
  assign n7171 = n7104 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:151:22 */
  assign n7172 = n7169 | n7171;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:165:77 */
  assign n7174 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:89 */
  assign n7176 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7182 = {n7176, n7176, n7176, n7176, n7176, n7176, n7176};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:106 */
  assign n7184 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7185 = {n7182, n7184};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:160:11 */
  assign n7187 = n7104 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:24 */
  assign n7188 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:61 */
  assign n7190 = n7188 == 5'b00010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:91 */
  assign n7194 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7200 = {n7194, n7194, n7194};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:108 */
  assign n7202 = instr_i[4:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:99 */
  assign n7203 = {n7200, n7202};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:130 */
  assign n7204 = instr_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:121 */
  assign n7205 = {n7203, n7204};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:143 */
  assign n7206 = instr_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:134 */
  assign n7207 = {n7205, n7206};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:156 */
  assign n7208 = instr_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:147 */
  assign n7209 = {n7207, n7208};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:175:160 */
  assign n7211 = {n7209, 4'b0000};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:184:79 */
  assign n7213 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:91 */
  assign n7215 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7221 = {n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215, n7215};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:109 */
  assign n7223 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:185:100 */
  assign n7224 = {n7221, n7223};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7225 = {n7224, n7213, 7'b0110111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7226 = {n7211, 5'b00010, 3'b000, 5'b00010, 7'b0010011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7227 = n7190 ? n7226 : n7225;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:24 */
  assign n7228 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:37 */
  assign n7230 = n7228 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:60 */
  assign n7231 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:65 */
  assign n7232 = ~n7231;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:48 */
  assign n7233 = n7232 & n7230;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:72 */
  assign n7235 = 1'b1 & n7233;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:187:13 */
  assign n7238 = n7235 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:168:11 */
  assign n7240 = n7104 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:195:77 */
  assign n7241 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:196:77 */
  assign n7242 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:89 */
  assign n7244 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7250 = {n7244, n7244, n7244, n7244, n7244, n7244, n7244};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:106 */
  assign n7252 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7253 = {n7250, n7252};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:191:11 */
  assign n7255 = n7104 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:201:78 */
  assign n7256 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:201:69 */
  assign n7258 = {2'b01, n7256};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:202:78 */
  assign n7259 = instr_i[9:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:202:69 */
  assign n7261 = {2'b01, n7259};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:203:78 */
  assign n7262 = instr_i[4:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:203:69 */
  assign n7264 = {2'b01, n7262};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:25 */
  assign n7265 = instr_i[11:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:87 */
  assign n7266 = instr_i[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:78 */
  assign n7268 = {1'b0, n7266};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:206:92 */
  assign n7270 = {n7268, 5'b00000};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:209:81 */
  assign n7272 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:15 */
  assign n7274 = n7265 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:25 */
  assign n7276 = n7265 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:205:25 */
  assign n7277 = n7274 | n7276;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:93 */
  assign n7280 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n7286 = {n7280, n7280, n7280, n7280, n7280, n7280, n7280};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:110 */
  assign n7288 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7289 = {n7286, n7288};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:210:15 */
  assign n7291 = n7265 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:29 */
  assign n7293 = instr_i[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:220:39 */
  assign n7295 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:217:19 */
  assign n7297 = n7293 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:224:39 */
  assign n7300 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:221:19 */
  assign n7302 = n7293 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:32 */
  assign n7303 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:37 */
  assign n7304 = ~n7303;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7309 = n7304 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7311 = n7304 ? 3'b110 : 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:226:21 */
  assign n7313 = n7304 ? 7'b0000000 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:225:19 */
  assign n7315 = n7293 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:32 */
  assign n7316 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:37 */
  assign n7317 = ~n7316;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7321 = n7317 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7323 = n7317 ? 3'b111 : 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:236:21 */
  assign n7325 = n7317 ? 7'b0000000 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  assign n7326 = {n7315, n7302, n7297};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7326)
      3'b100: n7327 = n7309;
      3'b010: n7327 = n7300;
      3'b001: n7327 = n7295;
      default: n7327 = n7321;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7326)
      3'b100: n7328 = n7311;
      3'b010: n7328 = 3'b100;
      3'b001: n7328 = 3'b000;
      default: n7328 = n7323;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:216:17 */
  always @*
    case (n7326)
      3'b100: n7329 = n7313;
      3'b010: n7329 = 7'b0000000;
      3'b001: n7329 = 7'b0100000;
      default: n7329 = n7325;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  assign n7330 = {n7291, n7277};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7330)
      2'b10: n7332 = 1'b0;
      2'b01: n7332 = 1'b0;
      default: n7332 = n7327;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7330)
      2'b10: n7333 = 7'b0010011;
      2'b01: n7333 = 7'b0010011;
      default: n7333 = 7'b0110011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7330)
      2'b10: n7334 = 3'b111;
      2'b01: n7334 = 3'b101;
      default: n7334 = n7328;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7335 = n7289[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7330)
      2'b10: n7336 = n7335;
      2'b01: n7336 = n7272;
      default: n7336 = n7264;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:213:101 */
  assign n7337 = n7289[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:204:13 */
  always @*
    case (n7330)
      2'b10: n7338 = n7337;
      2'b01: n7338 = n7270;
      default: n7338 = n7329;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  assign n7339 = {n7255, n7240, n7187, n7172, n7141};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7341 = 1'b0;
      5'b01000: n7341 = n7238;
      5'b00100: n7341 = 1'b0;
      5'b00010: n7341 = 1'b0;
      5'b00001: n7341 = 1'b0;
      default: n7341 = n7332;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7342 = n7227[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7343 = 7'b0010011;
      5'b01000: n7343 = n7342;
      5'b00100: n7343 = 7'b0010011;
      5'b00010: n7343 = 7'b1100011;
      5'b00001: n7343 = 7'b1101111;
      default: n7343 = n7333;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7344 = n7227[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7345 = n7242;
      5'b01000: n7345 = n7344;
      5'b00100: n7345 = n7174;
      5'b00010: n7345 = n7167;
      5'b00001: n7345 = n7108;
      default: n7345 = n7258;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7346 = n7136[2:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7347 = n7227[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7348 = 3'b000;
      5'b01000: n7348 = n7347;
      5'b00100: n7348 = 3'b000;
      5'b00010: n7348 = n7144;
      5'b00001: n7348 = n7346;
      default: n7348 = n7334;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7349 = n7136[7:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7350 = n7227[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7351 = n7241;
      5'b01000: n7351 = n7350;
      5'b00100: n7351 = 5'b00000;
      5'b00010: n7351 = n7148;
      5'b00001: n7351 = n7349;
      default: n7351 = n7261;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7352 = n7136[12:8]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7353 = n7185[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7354 = n7227[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7355 = n7253[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7356 = n7355;
      5'b01000: n7356 = n7354;
      5'b00100: n7356 = n7353;
      5'b00010: n7356 = 5'b00000;
      5'b00001: n7356 = n7352;
      default: n7356 = n7336;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:149:131 */
  assign n7357 = n7136[19:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:166:97 */
  assign n7358 = n7185[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:170:13 */
  assign n7359 = n7227[31:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:197:97 */
  assign n7360 = n7253[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:142:9 */
  always @*
    case (n7339)
      5'b10000: n7361 = n7360;
      5'b01000: n7361 = n7359;
      5'b00100: n7361 = n7358;
      5'b00010: n7361 = n7162;
      5'b00001: n7361 = n7357;
      default: n7361 = n7338;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:140:7 */
  assign n7363 = n7013 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:21 */
  assign n7364 = instr_i[15:13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:278:77 */
  assign n7365 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:279:77 */
  assign n7366 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:282:77 */
  assign n7369 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:283:24 */
  assign n7370 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:283:13 */
  assign n7373 = n7370 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:275:11 */
  assign n7375 = n7364 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:86 */
  assign n7376 = instr_i[3:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:77 */
  assign n7378 = {4'b0000, n7376};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:108 */
  assign n7379 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:99 */
  assign n7380 = {n7378, n7379};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:122 */
  assign n7381 = instr_i[6:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:113 */
  assign n7382 = {n7380, n7381};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7384 = {n7382, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:293:77 */
  assign n7386 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:24 */
  assign n7387 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:295:24 */
  assign n7388 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:295:61 */
  assign n7390 = n7388 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:49 */
  assign n7391 = n7387 | n7390;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:294:13 */
  assign n7394 = n7391 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:11 */
  assign n7396 = n7364 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:22 */
  assign n7398 = n7364 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:287:22 */
  assign n7399 = n7396 | n7398;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:86 */
  assign n7400 = instr_i[8:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:77 */
  assign n7402 = {4'b0000, n7400};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:108 */
  assign n7403 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:302:99 */
  assign n7404 = {n7402, n7403};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:303:77 */
  assign n7405 = instr_i[11:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:303:91 */
  assign n7407 = {n7405, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:306:77 */
  assign n7409 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:307:24 */
  assign n7410 = instr_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:307:13 */
  assign n7413 = n7410 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:11 */
  assign n7415 = n7364 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:22 */
  assign n7417 = n7364 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:299:22 */
  assign n7418 = n7415 | n7417;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:24 */
  assign n7419 = instr_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:29 */
  assign n7420 = ~n7419;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:26 */
  assign n7421 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:65 */
  assign n7423 = n7421 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:316:81 */
  assign n7425 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:28 */
  assign n7427 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:67 */
  assign n7429 = n7427 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:318:17 */
  assign n7432 = n7429 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:324:81 */
  assign n7434 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:326:81 */
  assign n7436 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7438 = n7423 ? n7432 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7439 = {n7436, 5'b00000, 3'b000, n7434, 7'b0110011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7440 = {5'b00000, 7'b1100111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7441 = n7439[11:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7442 = n7423 ? n7440 : n7441;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7443 = n7439[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7445 = n7423 ? 3'b000 : n7443;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7446 = n7439[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7447 = n7423 ? n7425 : n7446;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7448 = n7439[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:314:15 */
  assign n7450 = n7423 ? 5'b00000 : n7448;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:26 */
  assign n7451 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:65 */
  assign n7453 = n7451 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:28 */
  assign n7454 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:42 */
  assign n7456 = n7454 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:335:83 */
  assign n7459 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7461 = {5'b00001, 7'b1100111};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7462 = n7461[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7463 = n7456 ? 7'b1110011 : n7462;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7464 = n7461[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7466 = n7456 ? 5'b00000 : n7464;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7468 = n7456 ? 5'b00000 : n7459;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:330:17 */
  assign n7470 = n7456 ? 12'b000000000001 : 12'b000000000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:341:81 */
  assign n7472 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:342:81 */
  assign n7473 = instr_i[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:343:81 */
  assign n7474 = instr_i[6:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7475 = {n7474, n7473, 3'b000, n7472, 7'b0110011};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7476 = {n7466, n7463};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7477 = {n7470, n7468};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7478 = n7475[11:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7479 = n7453 ? n7476 : n7478;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7480 = n7475[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7482 = n7453 ? 3'b000 : n7480;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7483 = n7475[24:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7484 = n7477[9:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7485 = n7453 ? n7484 : n7483;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7486 = n7477[16:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:329:15 */
  assign n7488 = n7453 ? n7486 : 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7490 = n7420 ? n7438 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7491 = {n7488, n7485, n7482, n7479};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7492 = {n7450, n7447, n7445, n7442};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7493 = n7491[24:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7494 = n7420 ? n7492 : n7493;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7495 = n7491[31:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7497 = n7420 ? 7'b0000000 : n7495;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:311:11 */
  assign n7499 = n7364 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  assign n7500 = {n7499, n7418, n7399, n7375};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7502 = n7490;
      4'b0100: n7502 = n7413;
      4'b0010: n7502 = n7394;
      4'b0001: n7502 = n7373;
      default: n7502 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7503 = n7494[6:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7505 = n7503;
      4'b0100: n7505 = 7'b0100011;
      4'b0010: n7505 = 7'b0000011;
      4'b0001: n7505 = 7'b0010011;
      default: n7505 = 7'b0000011;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7506 = n7494[11:7]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7508 = n7506;
      4'b0100: n7508 = n7407;
      4'b0010: n7508 = n7386;
      4'b0001: n7508 = n7366;
      default: n7508 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7509 = n7494[14:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7511 = n7509;
      4'b0100: n7511 = 3'b010;
      4'b0010: n7511 = 3'b010;
      4'b0001: n7511 = 3'b001;
      default: n7511 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7512 = n7494[19:15]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7514 = n7512;
      4'b0100: n7514 = 5'b00010;
      4'b0010: n7514 = 5'b00010;
      4'b0001: n7514 = n7365;
      default: n7514 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7515 = n7384[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:313:13 */
  assign n7516 = n7494[24:20]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7518 = n7516;
      4'b0100: n7518 = n7409;
      4'b0010: n7518 = n7515;
      4'b0001: n7518 = n7369;
      default: n7518 = 5'b00000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:290:135 */
  assign n7519 = n7384[11:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:273:9 */
  always @*
    case (n7500)
      4'b1000: n7521 = n7497;
      4'b0100: n7521 = n7404;
      4'b0010: n7521 = n7519;
      4'b0001: n7521 = 7'b0000000;
      default: n7521 = 7'b0000000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  assign n7522 = {n7363, n7103};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7523 = n7341;
      2'b01: n7523 = n7085;
      default: n7523 = n7502;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7525 = n7343;
      2'b01: n7525 = n7087;
      default: n7525 = n7505;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7526 = n7345;
      2'b01: n7526 = n7089;
      default: n7526 = n7508;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7527 = n7348;
      2'b01: n7527 = n7091;
      default: n7527 = n7511;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7528 = n7351;
      2'b01: n7528 = n7093;
      default: n7528 = n7514;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7529 = n7356;
      2'b01: n7529 = n7097;
      default: n7529 = n7518;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:68:5 */
  always @*
    case (n7522)
      2'b10: n7530 = n7361;
      2'b01: n7530 = n7101;
      default: n7530 = n7521;
    endcase
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:21 */
  assign n7538 = decoded[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:45 */
  assign n7539 = decoded[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:54 */
  assign n7540 = ~illegal;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:49 */
  assign n7541 = n7539 & n7540;
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:35 */
  assign n7542 = {n7538, n7541};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:77 */
  assign n7543 = decoded[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:357:68 */
  assign n7544 = {n7542, n7543};
  /*# ../../rtl/core/neorv32_cpu_decompressor.vhd:55:10 */
  assign n7545 = {n7530, n7529, n7528, n7527, n7526, n7525};
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
  wire n6949;
  wire [1:0] n6952;
  wire [1:0] n6953;
  wire [1:0] n6955;
  wire [1:0] n6957;
  wire [1:0] n6958;
  wire [1:0] n6960;
  wire n6969;
  wire n6970;
  wire n6971;
  wire n6972;
  wire n6975;
  wire n6976;
  wire n6977;
  wire n6978;
  wire n6979;
  wire n6982;
  wire n6983;
  wire n6984;
  wire n6985;
  wire n6986;
  wire n6990;
  wire n6999;
  reg [1:0] n7005;
  reg [1:0] n7006;
  wire [16:0] n7009; // mem_rd
  assign free_o = n6979; //(module output)
  assign rdata_o = n7009; //(module output)
  assign avail_o = n6986; //(module output)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:346:10 */
  assign w_pnt = n7005; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:346:17 */
  assign r_pnt = n7006; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:347:10 */
  assign match = n6972; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:359:16 */
  assign n6949 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:366:52 */
  assign n6952 = w_pnt + 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:365:7 */
  assign n6953 = we_i ? n6952 : w_pnt;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:363:7 */
  assign n6955 = clear_i ? 2'b00 : n6953;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:371:52 */
  assign n6957 = r_pnt + 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:370:7 */
  assign n6958 = re_i ? n6957 : r_pnt;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:368:7 */
  assign n6960 = clear_i ? 2'b00 : n6958;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:29 */
  assign n6969 = r_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:56 */
  assign n6970 = w_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:49 */
  assign n6971 = n6969 == n6970;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:377:18 */
  assign n6972 = n6971 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:29 */
  assign n6975 = r_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:46 */
  assign n6976 = w_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:38 */
  assign n6977 = n6975 != n6976;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:56 */
  assign n6978 = match & n6977;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:378:18 */
  assign n6979 = n6978 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:29 */
  assign n6982 = r_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:46 */
  assign n6983 = w_pnt[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:39 */
  assign n6984 = n6982 == n6983;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:56 */
  assign n6985 = match & n6984;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:379:18 */
  assign n6986 = n6985 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:387:38 */
  assign n6990 = w_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:393:43 */
  assign n6999 = r_pnt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:362:5 */
  always @(posedge clk_i or posedge n6949)
    if (n6949)
      n7005 <= 2'b00;
    else
      n7005 <= n6955;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:362:5 */
  always @(posedge clk_i or posedge n6949)
    if (n6949)
      n7006 <= 2'b00;
    else
      n7006 <= n6960;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:393:18 */
  reg [16:0] ipb[1:0] ; // memory
  assign n7009 = ipb[n6999];
  always @(posedge clk_i)
    if (we_i)
      ipb[n6990] <= wdata_i;
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
  wire n6898;
  wire n6907;
  wire n6908;
  wire n6909;
  wire n6910;
  wire n6912;
  wire n6914;
  wire n6915;
  wire n6917;
  wire n6919;
  wire n6920;
  wire n6922;
  wire n6923;
  wire n6925;
  wire n6926;
  wire n6927;
  wire n6929;
  wire n6931;
  wire n6932;
  wire [7:0] n6940;
  wire [7:0] n6941;
  reg [7:0] n6942;
  reg n6943;
  reg n6944;
  assign free_o = n6927; //(module output)
  assign rdata_o = n6940; //(module output)
  assign avail_o = avail; //(module output)
  /*# ../../rtl/core/neorv32_prim.vhd:50:10 */
  assign fifo = n6942; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:53:10 */
  assign rdata = fifo; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:10 */
  assign we = n6910; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:14 */
  assign re = n6908; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:18 */
  assign match = n6923; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:25 */
  assign full = n6925; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:31 */
  assign empty = match; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:54:38 */
  assign avail = n6926; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:10 */
  assign w_pnt = n6943; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:17 */
  assign w_nxt = n6912; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:24 */
  assign r_pnt = n6944; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:55:31 */
  assign r_nxt = n6917; // (signal)
  /*# ../../rtl/core/neorv32_prim.vhd:63:16 */
  assign n6898 = ~rstn_i;
  /*# ../../rtl/core/neorv32_prim.vhd:73:19 */
  assign n6907 = ~empty;
  /*# ../../rtl/core/neorv32_prim.vhd:73:14 */
  assign n6908 = re_i & n6907;
  /*# ../../rtl/core/neorv32_prim.vhd:74:19 */
  assign n6909 = ~full;
  /*# ../../rtl/core/neorv32_prim.vhd:74:14 */
  assign n6910 = we_i & n6909;
  /*# ../../rtl/core/neorv32_prim.vhd:77:28 */
  assign n6912 = clear_i ? 1'b0 : n6915;
  /*# ../../rtl/core/neorv32_prim.vhd:77:88 */
  assign n6914 = w_pnt + 1'b1;
  /*# ../../rtl/core/neorv32_prim.vhd:77:49 */
  assign n6915 = we ? n6914 : w_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:78:28 */
  assign n6917 = clear_i ? 1'b0 : n6920;
  /*# ../../rtl/core/neorv32_prim.vhd:78:88 */
  assign n6919 = r_pnt + 1'b1;
  /*# ../../rtl/core/neorv32_prim.vhd:78:49 */
  assign n6920 = re ? n6919 : r_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:102:33 */
  assign n6922 = r_pnt == w_pnt;
  /*# ../../rtl/core/neorv32_prim.vhd:102:18 */
  assign n6923 = n6922 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_prim.vhd:103:14 */
  assign n6925 = ~match;
  /*# ../../rtl/core/neorv32_prim.vhd:105:14 */
  assign n6926 = ~empty;
  /*# ../../rtl/core/neorv32_prim.vhd:109:14 */
  assign n6927 = ~full;
  /*# ../../rtl/core/neorv32_prim.vhd:134:18 */
  assign n6929 = ~rstn_i;
  /*# ../../rtl/core/neorv32_prim.vhd:137:36 */
  assign n6931 = ~clear_i;
  /*# ../../rtl/core/neorv32_prim.vhd:137:23 */
  assign n6932 = n6931 & we;
  /*# ../../rtl/core/neorv32_prim.vhd:146:30 */
  assign n6940 = 1'b0 ? 8'b00000000 : rdata;
  /*# ../../rtl/core/neorv32_prim.vhd:136:7 */
  assign n6941 = n6932 ? wdata_i : fifo;
  /*# ../../rtl/core/neorv32_prim.vhd:136:7 */
  always @(posedge clk_i or posedge n6929)
    if (n6929)
      n6942 <= 8'b00000000;
    else
      n6942 <= n6941;
  /*# ../../rtl/core/neorv32_prim.vhd:66:5 */
  always @(posedge clk_i or posedge n6898)
    if (n6898)
      n6943 <= 1'b0;
    else
      n6943 <= w_nxt;
  /*# ../../rtl/core/neorv32_prim.vhd:66:5 */
  always @(posedge clk_i or posedge n6898)
    if (n6898)
      n6944 <= 1'b0;
    else
      n6944 <= r_nxt;
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
  wire [81:0] n6851;
  wire n6853;
  wire n6854;
  wire [31:0] n6855;
  wire [4:0] n6857;
  wire [31:0] n6858;
  wire [31:0] n6859;
  wire [3:0] n6860;
  wire n6861;
  wire n6862;
  wire n6863;
  wire [3:0] n6864;
  wire n6865;
  wire n6866;
  wire [33:0] n6867;
  wire n6869;
  wire n6871;
  wire [81:0] n6872;
  wire n6873;
  wire [72:0] n6875;
  wire n6876;
  wire [5:0] n6878;
  wire n6879;
  wire [81:0] n6880;
  wire n6886;
  reg [33:0] n6892;
  reg [81:0] n6893;
  assign \host_rsp_o[ack]  = n6853; //(module output)
  assign \host_rsp_o[err]  = n6854; //(module output)
  assign \host_rsp_o[data]  = n6855; //(module output)
  assign \device_req_o[meta]  = n6857; //(module output)
  assign \device_req_o[addr]  = n6858; //(module output)
  assign \device_req_o[data]  = n6859; //(module output)
  assign \device_req_o[ben]  = n6860; //(module output)
  assign \device_req_o[stb]  = n6861; //(module output)
  assign \device_req_o[rw]  = n6862; //(module output)
  assign \device_req_o[amo]  = n6863; //(module output)
  assign \device_req_o[amoop]  = n6864; //(module output)
  assign \device_req_o[burst]  = n6865; //(module output)
  assign \device_req_o[lock]  = n6866; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6851 = {\host_req_i[lock] , \host_req_i[burst] , \host_req_i[amoop] , \host_req_i[amo] , \host_req_i[rw] , \host_req_i[stb] , \host_req_i[ben] , \host_req_i[data] , \host_req_i[addr] , \host_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6853 = n6892[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6854 = n6892[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6855 = n6892[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6857 = n6893[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6858 = n6893[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6859 = n6893[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6860 = n6893[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6861 = n6893[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6862 = n6893[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6863 = n6893[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6864 = n6893[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6865 = n6893[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6866 = n6893[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:172:8 */
  assign n6867 = {\device_rsp_i[data] , \device_rsp_i[err] , \device_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:199:18 */
  assign n6869 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:202:24 */
  assign n6871 = n6851[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:202:9 */
  assign n6872 = n6871 ? n6851 : n6893;
  /*# ../../rtl/core/neorv32_bus.vhd:206:42 */
  assign n6873 = n6851[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:184:5 */
  assign n6875 = n6872[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:207:42 */
  assign n6876 = n6851[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:184:5 */
  assign n6878 = n6872[79:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:208:42 */
  assign n6879 = n6851[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:201:7 */
  assign n6880 = {n6879, n6876, n6878, n6873, n6875};
  /*# ../../rtl/core/neorv32_bus.vhd:224:18 */
  assign n6886 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:226:7 */
  always @(posedge clk_i or posedge n6886)
    if (n6886)
      n6892 <= 34'b0000000000000000000000000000000000;
    else
      n6892 <= n6867;
  /*# ../../rtl/core/neorv32_bus.vhd:201:7 */
  always @(posedge clk_i or posedge n6869)
    if (n6869)
      n6893 <= 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n6893 <= n6880;
endmodule

module neorv32_dmem_ram_Bneorv32_dmem_ram_rtl_Lneorv32_14_0
  (input  clk_i,
   input  [3:0] en_i,
   input  rw_i,
   input  [31:0] addr_i,
   input  [31:0] data_i,
   output [31:0] data_o);
  wire [7:0] \ram_gen[0]_ram_inst.data_o ;
  wire n6834;
  wire [11:0] n6835;
  wire [7:0] n6836;
  wire [7:0] \ram_gen[1]_ram_inst.data_o ;
  wire n6838;
  wire [11:0] n6839;
  wire [7:0] n6840;
  wire [7:0] \ram_gen[2]_ram_inst.data_o ;
  wire n6842;
  wire [11:0] n6843;
  wire [7:0] n6844;
  wire [7:0] \ram_gen[3]_ram_inst.data_o ;
  wire n6846;
  wire [11:0] n6847;
  wire [7:0] n6848;
  wire [31:0] n6850;
  assign data_o = n6850; //(module output)
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[0]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6834),
    .rw_i(rw_i),
    .addr_i(n6835),
    .data_i(n6836),
    .data_o(\ram_gen[0]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6834 = en_i[0]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6835 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6836 = data_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[1]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6838),
    .rw_i(rw_i),
    .addr_i(n6839),
    .data_i(n6840),
    .data_o(\ram_gen[1]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6838 = en_i[1]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6839 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6840 = data_i[15:8]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[2]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6842),
    .rw_i(rw_i),
    .addr_i(n6843),
    .data_i(n6844),
    .data_o(\ram_gen[2]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6842 = en_i[2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6843 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6844 = data_i[23:16]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:47:5 */
  neorv32_prim_spram_Bneorv32_prim_spram_rtl_Lneorv32_12_8_0 \ram_gen[3]_ram_inst  (
    .clk_i(clk_i),
    .en_i(n6846),
    .rw_i(rw_i),
    .addr_i(n6847),
    .data_i(n6848),
    .data_o(\ram_gen[3]_ram_inst.data_o ));
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:55:21 */
  assign n6846 = en_i[3]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:57:23 */
  assign n6847 = addr_i[13:2]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:58:23 */
  assign n6848 = data_i[31:24]; // extract
  /*# ../../rtl/core/neorv32_dmem_ram.vhd:31:5 */
  assign n6850 = {\ram_gen[3]_ram_inst.data_o , \ram_gen[2]_ram_inst.data_o , \ram_gen[1]_ram_inst.data_o , \ram_gen[0]_ram_inst.data_o };
endmodule

module neorv32_imem_rom_Bneorv32_imem_rom_rtl_Lneorv32_14_0
  (input  clk_i,
   input  en_i,
   input  [31:0] addr_i,
   output [31:0] data_o);
  wire [31:0] rdata;
  wire [7:0] n6818;
  reg [31:0] n6832; // mem_rd
  assign data_o = rdata; //(module output)
  /*# ../../rtl/core/neorv32_imem_rom.vhd:37:10 */
  assign rdata = n6832; // (signal)
  /*# ../../rtl/core/neorv32_imem_rom.vhd:56:57 */
  assign n6818 = addr_i[9:2]; // extract
  /*# ../../rtl/core/neorv32_imem_rom.vhd:56:31 */
  reg [31:0] n6830[255:0] ; // memory
  initial begin
    n6830[255] = 32'b00000000000000000000000000000000;
    n6830[254] = 32'b00000000000000000000000000000000;
    n6830[253] = 32'b00000000000000000000000000000000;
    n6830[252] = 32'b00000000000000000000000000000000;
    n6830[251] = 32'b00000000000000000000000000000000;
    n6830[250] = 32'b00000000000000000000000000000000;
    n6830[249] = 32'b00000000000000000000000000000000;
    n6830[248] = 32'b00000000000000000000000000000000;
    n6830[247] = 32'b00000000000000000000000000000000;
    n6830[246] = 32'b00000000000000000000000000000000;
    n6830[245] = 32'b00000000000000000000000000000000;
    n6830[244] = 32'b00000000000000000000000000000000;
    n6830[243] = 32'b00000000000000000000000000000000;
    n6830[242] = 32'b00000000000000000000000000000000;
    n6830[241] = 32'b00000000000000000000000000000000;
    n6830[240] = 32'b00000000000000000000000000000000;
    n6830[239] = 32'b00000000000000000000000000000000;
    n6830[238] = 32'b00000000000000000000000000000000;
    n6830[237] = 32'b00000000000000000000000000000000;
    n6830[236] = 32'b00000000000000000000000000000000;
    n6830[235] = 32'b00000000000000000000000000000000;
    n6830[234] = 32'b00000000000000000000000000000000;
    n6830[233] = 32'b00000000000000000000000000000000;
    n6830[232] = 32'b00000000000000000000000000000000;
    n6830[231] = 32'b00000000000000000000000000000000;
    n6830[230] = 32'b00000000000000000000000000000000;
    n6830[229] = 32'b00000000000000000000000000000000;
    n6830[228] = 32'b00000000000000000000000000000000;
    n6830[227] = 32'b00000000000000000000000000000000;
    n6830[226] = 32'b00000000000000000000000000000000;
    n6830[225] = 32'b00000000000000000000000000000000;
    n6830[224] = 32'b00000000000000000000000000000000;
    n6830[223] = 32'b00000000000000000000000000000000;
    n6830[222] = 32'b00000000000000000000000000000000;
    n6830[221] = 32'b00000000000000000000000000000000;
    n6830[220] = 32'b00000000000000000000000000000000;
    n6830[219] = 32'b00000000000000000000000000000000;
    n6830[218] = 32'b00000000000000000000000000000000;
    n6830[217] = 32'b00000000000000000000000000000000;
    n6830[216] = 32'b00000000000000000000000000000000;
    n6830[215] = 32'b00000000000000000000000000000000;
    n6830[214] = 32'b00000000000000000000000000000000;
    n6830[213] = 32'b00000000000000000000000000000000;
    n6830[212] = 32'b00000000000000000000000000000000;
    n6830[211] = 32'b00000000000000000000000000000000;
    n6830[210] = 32'b00000000000000000000000000000000;
    n6830[209] = 32'b00000000000000000000000000000000;
    n6830[208] = 32'b00000000000000000000000000000000;
    n6830[207] = 32'b00000000000000000000000000000000;
    n6830[206] = 32'b00000000000000000000000000000000;
    n6830[205] = 32'b00000000000000000000000000000000;
    n6830[204] = 32'b00000000000000000000000000000000;
    n6830[203] = 32'b00000000000000000000000000000000;
    n6830[202] = 32'b00000000000000000000000000000000;
    n6830[201] = 32'b00000000000000000000000000000000;
    n6830[200] = 32'b00000000000000000000000000000000;
    n6830[199] = 32'b00000000000000000000000000000000;
    n6830[198] = 32'b00000000000000001000000001100111;
    n6830[197] = 32'b00000001000000010000000100010011;
    n6830[196] = 32'b00000000000000110000010110010011;
    n6830[195] = 32'b00000000000010000000010100010011;
    n6830[194] = 32'b00000000110000010010000010000011;
    n6830[193] = 32'b00000000011001010000001100110011;
    n6830[192] = 32'b11110110100111111111000011101111;
    n6830[191] = 32'b00000000000000101000010110010011;
    n6830[190] = 32'b00000000000000111000010100010011;
    n6830[189] = 32'b00000000000000101000101001100011;
    n6830[188] = 32'b00000000011001010000001100110011;
    n6830[187] = 32'b11110111110111111111000011101111;
    n6830[186] = 32'b00000000000001100000010100010011;
    n6830[185] = 32'b00000000000001011000100001100011;
    n6830[184] = 32'b11111100000001110001100011100011;
    n6830[183] = 32'b00000001110001111110011110110011;
    n6830[182] = 32'b00000000000101101001011010010011;
    n6830[181] = 32'b00000001111011111000001100110011;
    n6830[180] = 32'b00000000000010001000100000010011;
    n6830[179] = 32'b00000000000011101000011001100011;
    n6830[178] = 32'b00000000000101111001011110010011;
    n6830[177] = 32'b00000001000010001011111110110011;
    n6830[176] = 32'b00000000000101110101011100010011;
    n6830[175] = 32'b00000001111101101101111000010011;
    n6830[174] = 32'b00000000111100110000111100110011;
    n6830[173] = 32'b00000000000101110111111010010011;
    n6830[172] = 32'b00000000110110000000100010110011;
    n6830[171] = 32'b00000000000000000000100000010011;
    n6830[170] = 32'b00000000000000000000001100010011;
    n6830[169] = 32'b00000000000000000000011110010011;
    n6830[168] = 32'b00000000000001100000011100010011;
    n6830[167] = 32'b00000000000001010000011010010011;
    n6830[166] = 32'b00000000000001010000001110010011;
    n6830[165] = 32'b00000000000100010010011000100011;
    n6830[164] = 32'b00000000000001101000001010010011;
    n6830[163] = 32'b11111111000000010000000100010011;
    n6830[162] = 32'b00000000000000001000000001100111;
    n6830[161] = 32'b11111110000001011001011011100011;
    n6830[160] = 32'b00000000000101100001011000010011;
    n6830[159] = 32'b00000000000101011101010110010011;
    n6830[158] = 32'b00000000110001010000010100110011;
    n6830[157] = 32'b00000000000001101000010001100011;
    n6830[156] = 32'b00000000000101011111011010010011;
    n6830[155] = 32'b00000000000000000000010100010011;
    n6830[154] = 32'b00000000000001010000011000010011;
    n6830[153] = 32'b00000000000000001000000001100111;
    n6830[152] = 32'b00000000101001111010010000100011;
    n6830[151] = 32'b11111111111111000000011110110111;
    n6830[150] = 32'b00000000000000001000000001100111;
    n6830[149] = 32'b00000000101001111010001000100011;
    n6830[148] = 32'b11111111111111000000011110110111;
    n6830[147] = 32'b00000000000000001000000001100111;
    n6830[146] = 32'b00000001000000010000000100010011;
    n6830[145] = 32'b00000000110000010010000010000011;
    n6830[144] = 32'b11111111000111111111000001101111;
    n6830[143] = 32'b00000000000000000000000000010011;
    n6830[142] = 32'b11111111111101010000010100010011;
    n6830[141] = 32'b00000000000000000001100001100011;
    n6830[140] = 32'b00000000000001010000101001100011;
    n6830[139] = 32'b00000000101001011000010100110011;
    n6830[138] = 32'b00000000010001010101010100010011;
    n6830[137] = 32'b00000001110001011001010110010011;
    n6830[136] = 32'b00000110110000000000000011101111;
    n6830[135] = 32'b00000000000100010010011000100011;
    n6830[134] = 32'b00000000000000000000010110010011;
    n6830[133] = 32'b00000000101001010101010100010011;
    n6830[132] = 32'b00000000000000000000011010010011;
    n6830[131] = 32'b00000000000001011000011000010011;
    n6830[130] = 32'b11111111000000010000000100010011;
    n6830[129] = 32'b11111110110111111111000001101111;
    n6830[128] = 32'b00000000000101000000010000010011;
    n6830[127] = 32'b11111100010111111111000011101111;
    n6830[126] = 32'b00001111101000000000010100010011;
    n6830[125] = 32'b00000101110000000000000011101111;
    n6830[124] = 32'b00001111111101000111010100010011;
    n6830[123] = 32'b00000000000000000000010000010011;
    n6830[122] = 32'b00000111010000000000000011101111;
    n6830[121] = 32'b00001111111100000000010100010011;
    n6830[120] = 32'b00000111000000000000000011101111;
    n6830[119] = 32'b00000000100000010010010000100011;
    n6830[118] = 32'b00000000000100010010011000100011;
    n6830[117] = 32'b00000000000000000000010100010011;
    n6830[116] = 32'b11111111000000010000000100010011;
    n6830[115] = 32'b00000011110000000000000001101111;
    n6830[114] = 32'b00000000000001111010010100000011;
    n6830[113] = 32'b00000000000001010000010110010011;
    n6830[112] = 32'b11111111111111100000011110110111;
    n6830[111] = 32'b11111111110111111111000001101111;
    n6830[110] = 32'b00010000010100000000000001110011;
    n6830[109] = 32'b11111111110111111111000001101111;
    n6830[108] = 32'b00010000010100000000000001110011;
    n6830[107] = 32'b00000000000100000000000001110011;
    n6830[106] = 32'b00000000000001000001010001100011;
    n6830[105] = 32'b11110001010000000010010001110011;
    n6830[104] = 32'b11111110100101000100101011100011;
    n6830[103] = 32'b00000000010001000000010000010011;
    n6830[102] = 32'b00000000000000001000000011100111;
    n6830[101] = 32'b00000000000001000010000010000011;
    n6830[100] = 32'b00000000100101000101101001100011;
    n6830[99] = 32'b00011001010001001000010010010011;
    n6830[98] = 32'b00000000000000000000010010010111;
    n6830[97] = 32'b00011001110001000000010000010011;
    n6830[96] = 32'b00000000000000000000010000010111;
    n6830[95] = 32'b00000010000001000001010001100011;
    n6830[94] = 32'b11110001010000000010010001110011;
    n6830[93] = 32'b00110100000001010001000001110011;
    n6830[92] = 32'b00110000010101011001000001110011;
    n6830[91] = 32'b00000101000001011000010110010011;
    n6830[90] = 32'b00000000000000000000010110010111;
    n6830[89] = 32'b00110000010000000001000001110011;
    n6830[88] = 32'b00110000000001000111000001110011;
    n6830[87] = 32'b00000000000001100000000011100111;
    n6830[86] = 32'b00000000000000000000010110010011;
    n6830[85] = 32'b00000000000000000000010100010011;
    n6830[84] = 32'b00000000000000000001000000001111;
    n6830[83] = 32'b00001111111100000000000000001111;
    n6830[82] = 32'b00001000110001100000011000010011;
    n6830[81] = 32'b00000000000000000000011000010111;
    n6830[80] = 32'b11111110100101000100101011100011;
    n6830[79] = 32'b00000000010001000000010000010011;
    n6830[78] = 32'b00000000000000001000000011100111;
    n6830[77] = 32'b00000000000001000010000010000011;
    n6830[76] = 32'b00000000100101000101101001100011;
    n6830[75] = 32'b00011111010001001000010010010011;
    n6830[74] = 32'b00000000000000000000010010010111;
    n6830[73] = 32'b00011111110001000000010000010011;
    n6830[72] = 32'b00000000000000000000010000010111;
    n6830[71] = 32'b11111110101101010100110011100011;
    n6830[70] = 32'b00000000010001010000010100010011;
    n6830[69] = 32'b00000000000001010010000000100011;
    n6830[68] = 32'b00000000101101010101100001100011;
    n6830[67] = 32'b11111110100101000100100011100011;
    n6830[66] = 32'b00000000010001000000010000010011;
    n6830[65] = 32'b00000000010000111000001110010011;
    n6830[64] = 32'b00000000111101000010000000100011;
    n6830[63] = 32'b00000000000000111010011110000011;
    n6830[62] = 32'b00000000100101000101110001100011;
    n6830[61] = 32'b00000000100000111000111001100011;
    n6830[60] = 32'b00000101110000000000000001101111;
    n6830[59] = 32'b00000000000001110010001000100011;
    n6830[58] = 32'b11111111111101000000011100110111;
    n6830[57] = 32'b00000000110001110010011000000011;
    n6830[56] = 32'b00000000100001110010000100000011;
    n6830[55] = 32'b11111111111101000100011100110111;
    n6830[54] = 32'b00110000010000000101000001110011;
    n6830[53] = 32'b00110000010101111001000001110011;
    n6830[52] = 32'b00001110110001111000011110010011;
    n6830[51] = 32'b00000000000000000000011110010111;
    n6830[50] = 32'b11111111110111111111000001101111;
    n6830[49] = 32'b00010000010100000000000001110011;
    n6830[48] = 32'b00110000000001000110000001110011;
    n6830[47] = 32'b00110000010001000101000001110011;
    n6830[46] = 32'b00110000010101111001000001110011;
    n6830[45] = 32'b00000001110001111000011110010011;
    n6830[44] = 32'b00000000000000000000011110010111;
    n6830[43] = 32'b00000100000000001000010001100011;
    n6830[42] = 32'b00000000000000000000111110010011;
    n6830[41] = 32'b00000000000000000000111100010011;
    n6830[40] = 32'b00000000000000000000111010010011;
    n6830[39] = 32'b00000000000000000000111000010011;
    n6830[38] = 32'b00000000000000000000110110010011;
    n6830[37] = 32'b00000000000000000000110100010011;
    n6830[36] = 32'b00000000000000000000110010010011;
    n6830[35] = 32'b00000000000000000000110000010011;
    n6830[34] = 32'b00000000000000000000101110010011;
    n6830[33] = 32'b00000000000000000000101100010011;
    n6830[32] = 32'b00000000000000000000101010010011;
    n6830[31] = 32'b00000000000000000000101000010011;
    n6830[30] = 32'b00000000000000000000100110010011;
    n6830[29] = 32'b00000000000000000000100100010011;
    n6830[28] = 32'b00000000000000000000100010010011;
    n6830[27] = 32'b00000000000000000000100000010011;
    n6830[26] = 32'b00000000000000000000011110010011;
    n6830[25] = 32'b00000000000000000000011100010011;
    n6830[24] = 32'b00000000000000000000011010010011;
    n6830[23] = 32'b00000000000000000000011000010011;
    n6830[22] = 32'b11111010110001011000010110010011;
    n6830[21] = 32'b10000000000000000000010110010111;
    n6830[20] = 32'b11111011010001010000010100010011;
    n6830[19] = 32'b10000000000000000000010100010111;
    n6830[18] = 32'b11111011110001001000010010010011;
    n6830[17] = 32'b10000000000000000000010010010111;
    n6830[16] = 32'b11111100010001000000010000010011;
    n6830[15] = 32'b10000000000000000000010000010111;
    n6830[14] = 32'b00101110100000111000001110010011;
    n6830[13] = 32'b00000000000000000000001110010111;
    n6830[12] = 32'b00110000010000000001000001110011;
    n6830[11] = 32'b00110000010100110001000001110011;
    n6830[10] = 32'b00011001010000110000001100010011;
    n6830[9] = 32'b00000000000000000000001100010111;
    n6830[8] = 32'b00110000000000101001000001110011;
    n6830[7] = 32'b10000000000000101000001010010011;
    n6830[6] = 32'b00000000000000000010001010110111;
    n6830[5] = 32'b01111111000000011000000110010011;
    n6830[4] = 32'b10000000000000000000000110010111;
    n6830[3] = 32'b11111111000000100111000100010011;
    n6830[2] = 32'b11111111110000100000001000010011;
    n6830[1] = 32'b10000000000000000010001000010111;
    n6830[0] = 32'b11110001010000000010000011110011;
    end
  always @(posedge clk_i)
    if (en_i)
      n6832 <= n6830[n6818];
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
  wire [261:0] n6542;
  wire [4:0] n6548;
  wire [31:0] n6549;
  wire [31:0] n6550;
  wire [3:0] n6551;
  wire n6552;
  wire n6553;
  wire n6554;
  wire [3:0] n6555;
  wire n6556;
  wire n6557;
  wire [33:0] n6558;
  wire [81:0] req;
  wire misalign;
  wire n6563;
  wire n6570;
  wire n6571;
  wire [2:0] n6573;
  wire n6574;
  wire [3:0] n6575;
  wire [4:0] n6577;
  wire [1:0] n6578;
  wire [7:0] n6579;
  wire [7:0] n6580;
  wire [15:0] n6581;
  wire [7:0] n6582;
  wire [23:0] n6583;
  wire [7:0] n6584;
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
  wire n6598;
  wire n6599;
  wire n6600;
  wire n6601;
  wire n6603;
  wire [15:0] n6604;
  wire [15:0] n6605;
  wire [31:0] n6606;
  wire n6607;
  wire n6608;
  wire [1:0] n6609;
  wire n6610;
  wire n6611;
  wire [2:0] n6612;
  wire n6613;
  wire n6614;
  wire [3:0] n6615;
  wire n6616;
  wire n6618;
  localparam [3:0] n6619 = 4'b1111;
  wire n6620;
  wire n6621;
  wire n6622;
  wire [1:0] n6623;
  reg [31:0] n6624;
  wire n6625;
  wire n6626;
  reg n6627;
  wire n6628;
  wire n6629;
  reg n6630;
  wire n6631;
  wire n6632;
  reg n6633;
  wire n6634;
  wire n6635;
  reg n6636;
  reg n6638;
  wire n6639;
  wire [72:0] n6640;
  wire [72:0] n6651;
  wire n6658;
  wire n6659;
  wire n6660;
  wire n6661;
  wire n6662;
  wire [31:0] n6663;
  wire n6665;
  wire n6667;
  wire [1:0] n6668;
  wire [1:0] n6669;
  wire n6671;
  wire n6672;
  wire n6673;
  wire n6674;
  wire [23:0] n6680;
  wire [7:0] n6682;
  wire [31:0] n6683;
  wire n6685;
  wire n6687;
  wire n6688;
  wire n6689;
  wire n6690;
  wire [23:0] n6696;
  wire [7:0] n6698;
  wire [31:0] n6699;
  wire n6701;
  wire n6703;
  wire n6704;
  wire n6705;
  wire n6706;
  wire [23:0] n6712;
  wire [7:0] n6714;
  wire [31:0] n6715;
  wire n6717;
  wire n6719;
  wire n6720;
  wire n6721;
  wire n6722;
  wire [23:0] n6728;
  wire [7:0] n6730;
  wire [31:0] n6731;
  wire n6733;
  wire [3:0] n6734;
  reg [31:0] n6736;
  wire n6738;
  wire n6739;
  wire n6740;
  wire n6742;
  wire n6743;
  wire n6744;
  wire n6745;
  wire [15:0] n6751;
  wire [15:0] n6753;
  wire [31:0] n6754;
  wire n6756;
  wire n6757;
  wire n6758;
  wire n6759;
  wire [15:0] n6765;
  wire [15:0] n6767;
  wire [31:0] n6768;
  wire [31:0] n6769;
  wire n6771;
  wire [31:0] n6772;
  wire [1:0] n6773;
  reg [31:0] n6774;
  wire [31:0] n6776;
  wire n6782;
  wire n6783;
  wire n6784;
  wire n6785;
  wire n6786;
  wire n6787;
  wire n6788;
  wire n6789;
  wire n6790;
  wire n6791;
  wire n6792;
  wire n6793;
  wire n6794;
  wire n6795;
  wire n6796;
  wire n6797;
  wire n6798;
  wire n6799;
  wire n6800;
  wire n6801;
  wire n6802;
  wire n6803;
  wire [81:0] n6804;
  wire [3:0] n6805;
  reg [31:0] n6806;
  wire n6807;
  wire n6808;
  reg n6809;
  wire [72:0] n6810;
  wire [72:0] n6811;
  reg [72:0] n6812;
  wire n6813;
  reg n6814;
  assign rdata_o = n6806; //(module output)
  assign mar_o = n6663; //(module output)
  assign wait_o = n6783; //(module output)
  assign err_o = n6805; //(module output)
  assign \dbus_req_o[meta]  = n6548; //(module output)
  assign \dbus_req_o[addr]  = n6549; //(module output)
  assign \dbus_req_o[data]  = n6550; //(module output)
  assign \dbus_req_o[ben]  = n6551; //(module output)
  assign \dbus_req_o[stb]  = n6552; //(module output)
  assign \dbus_req_o[rw]  = n6553; //(module output)
  assign \dbus_req_o[amo]  = n6554; //(module output)
  assign \dbus_req_o[amoop]  = n6555; //(module output)
  assign \dbus_req_o[burst]  = n6556; //(module output)
  assign \dbus_req_o[lock]  = n6557; //(module output)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6542 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6548 = req[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6549 = req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6550 = req[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6551 = req[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6552 = req[73]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6553 = req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6554 = req[75]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6555 = req[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6556 = req[80]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6557 = req[81]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:18:8 */
  assign n6558 = {\dbus_rsp_i[data] , \dbus_rsp_i[err] , \dbus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:44:10 */
  assign req = n6804; // (signal)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:45:10 */
  assign misalign = n6814; // (signal)
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:100:16 */
  assign n6563 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:108:18 */
  assign n6570 = n6542[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:73 */
  assign n6571 = n6542[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:64 */
  assign n6573 = {2'b00, n6571};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:92 */
  assign n6574 = n6542[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:83 */
  assign n6575 = {n6573, n6574};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:109:101 */
  assign n6577 = {n6575, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:30 */
  assign n6578 = n6542[221:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:34 */
  assign n6579 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:56 */
  assign n6580 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:47 */
  assign n6581 = {n6579, n6580};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:78 */
  assign n6582 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:69 */
  assign n6583 = {n6581, n6582};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:100 */
  assign n6584 = wdata_i[7:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:113:91 */
  assign n6585 = {n6583, n6584};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:38 */
  assign n6586 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:28 */
  assign n6587 = ~n6586;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:58 */
  assign n6588 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:48 */
  assign n6589 = ~n6588;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:114:43 */
  assign n6590 = n6587 & n6589;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:38 */
  assign n6591 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:28 */
  assign n6592 = ~n6591;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:58 */
  assign n6593 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:115:43 */
  assign n6594 = n6592 & n6593;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:38 */
  assign n6595 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:58 */
  assign n6596 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:48 */
  assign n6597 = ~n6596;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:116:43 */
  assign n6598 = n6595 & n6597;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:38 */
  assign n6599 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:58 */
  assign n6600 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:117:43 */
  assign n6601 = n6599 & n6600;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:112:11 */
  assign n6603 = n6578 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:32 */
  assign n6604 = wdata_i[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:55 */
  assign n6605 = wdata_i[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:120:46 */
  assign n6606 = {n6604, n6605};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:31 */
  assign n6607 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:43 */
  assign n6608 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:35 */
  assign n6609 = {n6607, n6608};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:60 */
  assign n6610 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:50 */
  assign n6611 = ~n6610;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:47 */
  assign n6612 = {n6609, n6611};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:78 */
  assign n6613 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:68 */
  assign n6614 = ~n6613;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6615 = {n6612, n6614};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:122:31 */
  assign n6616 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:119:11 */
  assign n6618 = n6578 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:31 */
  assign n6620 = addr_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:44 */
  assign n6621 = addr_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:126:35 */
  assign n6622 = n6620 | n6621;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  assign n6623 = {n6618, n6603};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6624 = n6606;
      2'b01: n6624 = n6585;
      default: n6624 = wdata_i;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6625 = n6615[0]; // extract
  assign n6626 = n6619[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6627 = n6625;
      2'b01: n6627 = n6590;
      default: n6627 = n6626;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6628 = n6615[1]; // extract
  assign n6629 = n6619[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6630 = n6628;
      2'b01: n6630 = n6594;
      default: n6630 = n6629;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6631 = n6615[2]; // extract
  assign n6632 = n6619[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6633 = n6631;
      2'b01: n6633 = n6598;
      default: n6633 = n6632;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:121:65 */
  assign n6634 = n6615[3]; // extract
  assign n6635 = n6619[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6636 = n6634;
      2'b01: n6636 = n6601;
      default: n6636 = n6635;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:111:9 */
  always @*
    case (n6623)
      2'b10: n6638 = n6616;
      2'b01: n6638 = 1'b0;
      default: n6638 = n6622;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:131:28 */
  assign n6639 = n6542[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:108:7 */
  assign n6640 = {n6636, n6633, n6630, n6627, n6624, addr_i, n6577};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:100:5 */
  assign n6651 = {4'b0000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 5'b00000};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:24 */
  assign n6658 = n6542[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:37 */
  assign n6659 = ~misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:32 */
  assign n6660 = n6658 & n6659;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:56 */
  assign n6661 = ~pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:138:51 */
  assign n6662 = n6660 & n6661;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:140:21 */
  assign n6663 = req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:147:16 */
  assign n6665 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:151:18 */
  assign n6667 = n6542[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:30 */
  assign n6668 = n6542[221:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:26 */
  assign n6669 = req[6:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:74 */
  assign n6671 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:54 */
  assign n6672 = ~n6671;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:98 */
  assign n6673 = n6558[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:79 */
  assign n6674 = n6672 & n6673;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6680 = {n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674, n6674};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:125 */
  assign n6682 = n6558[9:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:108 */
  assign n6683 = {n6680, n6682};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:155:15 */
  assign n6685 = n6669 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:74 */
  assign n6687 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:54 */
  assign n6688 = ~n6687;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:98 */
  assign n6689 = n6558[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:79 */
  assign n6690 = n6688 & n6689;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6696 = {n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690, n6690};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:125 */
  assign n6698 = n6558[17:10]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:108 */
  assign n6699 = {n6696, n6698};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:156:15 */
  assign n6701 = n6669 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:74 */
  assign n6703 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:54 */
  assign n6704 = ~n6703;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:98 */
  assign n6705 = n6558[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:79 */
  assign n6706 = n6704 & n6705;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6712 = {n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706, n6706};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:125 */
  assign n6714 = n6558[25:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:108 */
  assign n6715 = {n6712, n6714};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:157:15 */
  assign n6717 = n6669 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:74 */
  assign n6719 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:54 */
  assign n6720 = ~n6719;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:98 */
  assign n6721 = n6558[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:79 */
  assign n6722 = n6720 & n6721;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6728 = {n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722, n6722};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:125 */
  assign n6730 = n6558[33:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:108 */
  assign n6731 = {n6728, n6730};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:158:15 */
  assign n6733 = n6669 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:13 */
  assign n6734 = {n6733, n6717, n6701, n6685};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:154:13 */
  always @*
    case (n6734)
      4'b1000: n6736 = n6731;
      4'b0100: n6736 = n6715;
      4'b0010: n6736 = n6699;
      4'b0001: n6736 = n6683;
      default: n6736 = 32'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:153:11 */
  assign n6738 = n6668 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:25 */
  assign n6739 = req[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:29 */
  assign n6740 = ~n6739;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:59 */
  assign n6742 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:39 */
  assign n6743 = ~n6742;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:83 */
  assign n6744 = n6558[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:64 */
  assign n6745 = n6743 & n6744;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6751 = {n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745, n6745};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:110 */
  assign n6753 = n6558[17:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:163:93 */
  assign n6754 = {n6751, n6753};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:59 */
  assign n6756 = n6542[222]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:39 */
  assign n6757 = ~n6756;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:83 */
  assign n6758 = n6558[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:64 */
  assign n6759 = n6757 & n6758;
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n6765 = {n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759, n6759};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:110 */
  assign n6767 = n6558[33:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:165:93 */
  assign n6768 = {n6765, n6767};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:162:13 */
  assign n6769 = n6740 ? n6754 : n6768;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:161:11 */
  assign n6771 = n6668 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:168:35 */
  assign n6772 = n6558[33:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:9 */
  assign n6773 = {n6771, n6738};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:152:9 */
  always @*
    case (n6773)
      2'b10: n6774 = n6769;
      2'b01: n6774 = n6736;
      default: n6774 = n6772;
    endcase
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:151:7 */
  assign n6776 = n6667 ? n6774 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:175:28 */
  assign n6782 = n6558[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:175:13 */
  assign n6783 = ~n6782;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:22 */
  assign n6784 = n6542[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:43 */
  assign n6785 = n6542[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:32 */
  assign n6786 = n6784 & n6785;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:180:50 */
  assign n6787 = n6786 & misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:22 */
  assign n6788 = n6542[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:43 */
  assign n6789 = n6542[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:32 */
  assign n6790 = n6788 & n6789;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:66 */
  assign n6791 = n6558[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:70 */
  assign n6792 = n6791 | pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:181:50 */
  assign n6793 = n6790 & n6792;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:22 */
  assign n6794 = n6542[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:43 */
  assign n6795 = n6542[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:32 */
  assign n6796 = n6794 & n6795;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:182:50 */
  assign n6797 = n6796 & misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:22 */
  assign n6798 = n6542[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:43 */
  assign n6799 = n6542[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:32 */
  assign n6800 = n6798 & n6799;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:66 */
  assign n6801 = n6558[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:70 */
  assign n6802 = n6801 | pmp_fault_i;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:183:50 */
  assign n6803 = n6800 & n6802;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:44:10 */
  assign n6804 = {1'b0, 1'b0, 4'b0000, 1'b0, n6809, n6662, n6812};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:34:5 */
  assign n6805 = {n6803, n6797, n6793, n6787};
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:149:5 */
  always @(posedge clk_i or posedge n6665)
    if (n6665)
      n6806 <= 32'b00000000000000000000000000000000;
    else
      n6806 <= n6776;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6807 = req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6808 = n6570 ? n6639 : n6807;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6563)
    if (n6563)
      n6809 <= 1'b0;
    else
      n6809 <= n6808;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6810 = req[72:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6811 = n6570 ? n6640 : n6810;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6563)
    if (n6563)
      n6812 <= n6651;
    else
      n6812 <= n6811;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  assign n6813 = n6570 ? n6638 : misalign;
  /*# ../../rtl/core/neorv32_cpu_lsu.vhd:107:5 */
  always @(posedge clk_i or posedge n6563)
    if (n6563)
      n6814 <= 1'b0;
    else
      n6814 <= n6813;
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
  wire [261:0] n6318;
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
  wire n6324;
  wire n6325;
  wire n6326;
  wire n6327;
  wire [32:0] n6328;
  wire n6329;
  wire n6330;
  wire n6331;
  wire n6332;
  wire [32:0] n6333;
  wire n6335;
  wire n6336;
  wire n6339;
  wire n6340;
  wire [2:0] n6343;
  wire n6345;
  wire [31:0] n6346;
  wire n6348;
  wire n6350;
  wire n6351;
  wire n6353;
  wire n6355;
  wire [31:0] n6356;
  wire n6358;
  wire [31:0] n6359;
  wire n6361;
  wire [31:0] n6362;
  wire n6364;
  wire [7:0] n6365;
  wire n6367;
  wire n6368;
  wire n6369;
  wire n6370;
  wire n6371;
  wire n6372;
  reg n6374;
  wire [30:0] n6376;
  wire [30:0] n6377;
  wire [30:0] n6378;
  wire [30:0] n6379;
  wire [30:0] n6380;
  wire [30:0] n6381;
  reg [30:0] n6384;
  wire [31:0] n6388;
  wire n6389;
  wire [31:0] n6390;
  wire [31:0] n6391;
  wire n6392;
  wire [31:0] n6393;
  wire n6394;
  wire n6395;
  wire n6396;
  wire n6397;
  wire [32:0] n6398;
  wire n6399;
  wire n6400;
  wire n6401;
  wire n6402;
  wire [32:0] n6403;
  wire [31:0] n6404;
  wire [32:0] n6405;
  wire n6406;
  wire [32:0] n6407;
  wire [32:0] n6408;
  wire n6409;
  wire n6410;
  wire n6411;
  wire n6412;
  wire n6413;
  wire n6414;
  wire n6415;
  wire n6416;
  wire n6417;
  wire n6418;
  wire n6419;
  wire n6420;
  wire n6421;
  wire [31:0] n6422;
  wire [31:0] n6423;
  wire [31:0] n6424;
  wire [31:0] n6425;
  wire [31:0] n6426;
  wire [31:0] n6427;
  wire [31:0] n6428;
  wire [31:0] n6429;
  wire [31:0] n6430;
  wire [31:0] n6431;
  wire [31:0] n6432;
  wire [31:0] n6433;
  wire [31:0] n6434;
  wire [31:0] \neorv32_cpu_alu_shifter_inst.res_o ;
  wire \neorv32_cpu_alu_shifter_inst.valid_o ;
  wire n6435;
  wire n6436;
  wire n6437;
  wire [31:0] n6438;
  wire [31:0] n6439;
  wire [31:0] n6440;
  wire n6441;
  wire [4:0] n6442;
  wire [4:0] n6443;
  wire [4:0] n6444;
  wire n6445;
  wire [2:0] n6446;
  wire n6447;
  wire n6448;
  wire n6449;
  wire n6450;
  wire [31:0] n6451;
  wire n6452;
  wire n6453;
  wire n6454;
  wire n6455;
  wire n6456;
  wire n6457;
  wire n6458;
  wire n6459;
  wire n6460;
  wire n6461;
  wire n6462;
  wire n6463;
  wire [11:0] n6464;
  wire [31:0] n6465;
  wire [8:0] n6466;
  wire [2:0] n6467;
  wire [11:0] n6468;
  wire [6:0] n6469;
  wire [15:0] n6470;
  wire n6471;
  wire n6472;
  wire n6473;
  wire n6474;
  wire [4:0] n6475;
  wire [31:0] \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o ;
  wire \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o ;
  wire n6478;
  wire n6479;
  wire n6480;
  wire [31:0] n6481;
  wire [31:0] n6482;
  wire [31:0] n6483;
  wire n6484;
  wire [4:0] n6485;
  wire [4:0] n6486;
  wire [4:0] n6487;
  wire n6488;
  wire [2:0] n6489;
  wire n6490;
  wire n6491;
  wire n6492;
  wire n6493;
  wire [31:0] n6494;
  wire n6495;
  wire n6496;
  wire n6497;
  wire n6498;
  wire n6499;
  wire n6500;
  wire n6501;
  wire n6502;
  wire n6503;
  wire n6504;
  wire n6505;
  wire n6506;
  wire [11:0] n6507;
  wire [31:0] n6508;
  wire [8:0] n6509;
  wire [2:0] n6510;
  wire [11:0] n6511;
  wire [6:0] n6512;
  wire [15:0] n6513;
  wire n6514;
  wire n6515;
  wire n6516;
  wire n6517;
  localparam [31:0] n6525 = 32'b00000000000000000000000000000000;
  wire [1:0] n6538;
  wire [223:0] n6539;
  wire [6:0] n6540;
  wire [31:0] n6541;
  assign cmp_o = cmp; //(module output)
  assign res_o = n6541; //(module output)
  assign add_o = n6404; //(module output)
  assign csr_o = n6525; //(module output)
  assign done_o = n6421; //(module output)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:18:8 */
  assign n6318 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:10 */
  assign opa = n6390; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign opb = n6393; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign cp_res = n6434; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:10 */
  assign cmp_rs1 = n6328; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:19 */
  assign cmp_rs2 = n6333; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:28 */
  assign opa_x = n6398; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:35 */
  assign opb_x = n6403; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:78:42 */
  assign addsub = n6407; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:79:10 */
  assign cmp = n6538; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:83:10 */
  assign cp_result = n6539; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:84:10 */
  assign cp_valid = n6540; // (signal)
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:20 */
  assign n6324 = rs1_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:49 */
  assign n6325 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:38 */
  assign n6326 = ~n6325;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:33 */
  assign n6327 = n6324 & n6326;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:93:64 */
  assign n6328 = {n6327, rs1_i};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:20 */
  assign n6329 = rs2_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:49 */
  assign n6330 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:38 */
  assign n6331 = ~n6330;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:33 */
  assign n6332 = n6329 & n6331;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:94:64 */
  assign n6333 = {n6332, rs2_i};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:95:29 */
  assign n6335 = rs1_i == rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:95:17 */
  assign n6336 = n6335 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:96:39 */
  assign n6339 = $signed(cmp_rs1) < $signed(cmp_rs2);
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:96:17 */
  assign n6340 = n6339 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:17 */
  assign n6343 = n6318[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:115:7 */
  assign n6345 = n6343 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6346 = addsub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:7 */
  assign n6348 = n6343 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:117:7 */
  assign n6350 = n6343 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:118:47 */
  assign n6351 = addsub[32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:118:7 */
  assign n6353 = n6343 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:119:7 */
  assign n6355 = n6343 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6356 = opb ^ rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:7 */
  assign n6358 = n6343 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6359 = opb | rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:7 */
  assign n6361 = n6343 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6362 = opb & rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:7 */
  assign n6364 = n6343 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  assign n6365 = {n6364, n6361, n6358, n6355, n6353, n6350, n6348, n6345};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6367 = n6346[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign n6368 = cp_res[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign n6369 = opb[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6370 = n6356[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6371 = n6359[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6372 = n6362[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  always @*
    case (n6365)
      8'b10000000: n6374 = n6372;
      8'b01000000: n6374 = n6371;
      8'b00100000: n6374 = n6370;
      8'b00010000: n6374 = n6369;
      8'b00001000: n6374 = n6351;
      8'b00000100: n6374 = n6368;
      8'b00000010: n6374 = n6367;
      8'b00000001: n6374 = 1'b0;
      default: n6374 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:116:44 */
  assign n6376 = n6346[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:20 */
  assign n6377 = cp_res[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:77:15 */
  assign n6378 = opb[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:120:42 */
  assign n6379 = n6356[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:121:42 */
  assign n6380 = n6359[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:122:42 */
  assign n6381 = n6362[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:114:5 */
  always @*
    case (n6365)
      8'b10000000: n6384 = n6381;
      8'b01000000: n6384 = n6380;
      8'b00100000: n6384 = n6379;
      8'b00010000: n6384 = n6378;
      8'b00001000: n6384 = 31'b0000000000000000000000000000000;
      8'b00000100: n6384 = n6377;
      8'b00000010: n6384 = n6376;
      8'b00000001: n6384 = 31'b0000000000000000000000000000000;
      default: n6384 = 31'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:19 */
  assign n6388 = n6318[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:40 */
  assign n6389 = n6318[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:128:27 */
  assign n6390 = n6389 ? n6388 : rs1_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:19 */
  assign n6391 = n6318[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:40 */
  assign n6392 = n6318[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:129:27 */
  assign n6393 = n6392 ? n6391 : rs2_i;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:16 */
  assign n6394 = opa[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:43 */
  assign n6395 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:32 */
  assign n6396 = ~n6395;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:27 */
  assign n6397 = n6394 & n6396;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:130:58 */
  assign n6398 = {n6397, opa};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:16 */
  assign n6399 = opb[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:43 */
  assign n6400 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:32 */
  assign n6401 = ~n6400;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:27 */
  assign n6402 = n6399 & n6401;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:131:58 */
  assign n6403 = {n6402, opb};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:134:19 */
  assign n6404 = addsub[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:47 */
  assign n6405 = opa_x - opb_x;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:79 */
  assign n6406 = n6318[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:135:66 */
  assign n6407 = n6406 ? n6405 : n6408;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:136:47 */
  assign n6408 = opa_x + opb_x;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:21 */
  assign n6409 = cp_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:36 */
  assign n6410 = cp_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:25 */
  assign n6411 = n6409 | n6410;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:51 */
  assign n6412 = cp_valid[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:40 */
  assign n6413 = n6411 | n6412;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:66 */
  assign n6414 = cp_valid[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:55 */
  assign n6415 = n6413 | n6414;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:81 */
  assign n6416 = cp_valid[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:70 */
  assign n6417 = n6415 | n6416;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:96 */
  assign n6418 = cp_valid[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:85 */
  assign n6419 = n6417 | n6418;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:111 */
  assign n6420 = cp_valid[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:143:100 */
  assign n6421 = n6419 | n6420;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:22 */
  assign n6422 = cp_result[223:192]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:38 */
  assign n6423 = cp_result[191:160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:26 */
  assign n6424 = n6422 | n6423;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:54 */
  assign n6425 = cp_result[159:128]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:42 */
  assign n6426 = n6424 | n6425;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:70 */
  assign n6427 = cp_result[127:96]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:58 */
  assign n6428 = n6426 | n6427;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:86 */
  assign n6429 = cp_result[95:64]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:74 */
  assign n6430 = n6428 | n6429;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:102 */
  assign n6431 = cp_result[63:32]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:90 */
  assign n6432 = n6430 | n6431;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:118 */
  assign n6433 = cp_result[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:144:106 */
  assign n6434 = n6432 | n6433;
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  neorv32_cpu_alu_shifter_Bneorv32_cpu_alu_shifter_rtl_Lneorv32_5ba93c9db0cff93f52b521d7420e43f6eda2784f neorv32_cpu_alu_shifter_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n6435),
    .\ctrl_i[if_ready] (n6436),
    .\ctrl_i[if_fence] (n6437),
    .\ctrl_i[pc_cur] (n6438),
    .\ctrl_i[pc_nxt] (n6439),
    .\ctrl_i[pc_ret] (n6440),
    .\ctrl_i[rf_wb_en] (n6441),
    .\ctrl_i[rf_rs1] (n6442),
    .\ctrl_i[rf_rs2] (n6443),
    .\ctrl_i[rf_rd] (n6444),
    .\ctrl_i[rf_zero] (n6445),
    .\ctrl_i[alu_op] (n6446),
    .\ctrl_i[alu_sub] (n6447),
    .\ctrl_i[alu_opa_mux] (n6448),
    .\ctrl_i[alu_opb_mux] (n6449),
    .\ctrl_i[alu_unsigned] (n6450),
    .\ctrl_i[alu_imm] (n6451),
    .\ctrl_i[alu_cp_alu] (n6452),
    .\ctrl_i[alu_cp_cfu] (n6453),
    .\ctrl_i[alu_cp_fpu] (n6454),
    .\ctrl_i[lsu_req] (n6455),
    .\ctrl_i[lsu_rd] (n6456),
    .\ctrl_i[lsu_wr] (n6457),
    .\ctrl_i[lsu_mo_en] (n6458),
    .\ctrl_i[lsu_mi_en] (n6459),
    .\ctrl_i[lsu_priv] (n6460),
    .\ctrl_i[lsu_fence] (n6461),
    .\ctrl_i[csr_we] (n6462),
    .\ctrl_i[csr_re] (n6463),
    .\ctrl_i[csr_addr] (n6464),
    .\ctrl_i[csr_wdata] (n6465),
    .\ctrl_i[cnt_event] (n6466),
    .\ctrl_i[ir_funct3] (n6467),
    .\ctrl_i[ir_funct12] (n6468),
    .\ctrl_i[ir_opcode] (n6469),
    .\ctrl_i[ir_rvc] (n6470),
    .\ctrl_i[cpu_priv] (n6471),
    .\ctrl_i[cpu_trap] (n6472),
    .\ctrl_i[cpu_sync_exc] (n6473),
    .\ctrl_i[cpu_debug] (n6474),
    .rs1_i(rs1_i),
    .shamt_i(n6475),
    .res_o(\neorv32_cpu_alu_shifter_inst.res_o ),
    .valid_o(\neorv32_cpu_alu_shifter_inst.valid_o ));
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6435 = n6318[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6436 = n6318[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6437 = n6318[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6438 = n6318[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6439 = n6318[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6440 = n6318[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6441 = n6318[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6442 = n6318[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6443 = n6318[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6444 = n6318[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6445 = n6318[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6446 = n6318[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6447 = n6318[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6448 = n6318[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6449 = n6318[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6450 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6451 = n6318[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6452 = n6318[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6453 = n6318[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6454 = n6318[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6455 = n6318[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6456 = n6318[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6457 = n6318[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6458 = n6318[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6459 = n6318[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6460 = n6318[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6461 = n6318[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6462 = n6318[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6463 = n6318[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6464 = n6318[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6465 = n6318[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6466 = n6318[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6467 = n6318[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6468 = n6318[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6469 = n6318[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6470 = n6318[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6471 = n6318[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6472 = n6318[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6473 = n6318[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:148:3 */
  assign n6474 = n6318[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:159:19 */
  assign n6475 = opb[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  neorv32_cpu_alu_muldiv_Bneorv32_cpu_alu_muldiv_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264 neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n6478),
    .\ctrl_i[if_ready] (n6479),
    .\ctrl_i[if_fence] (n6480),
    .\ctrl_i[pc_cur] (n6481),
    .\ctrl_i[pc_nxt] (n6482),
    .\ctrl_i[pc_ret] (n6483),
    .\ctrl_i[rf_wb_en] (n6484),
    .\ctrl_i[rf_rs1] (n6485),
    .\ctrl_i[rf_rs2] (n6486),
    .\ctrl_i[rf_rd] (n6487),
    .\ctrl_i[rf_zero] (n6488),
    .\ctrl_i[alu_op] (n6489),
    .\ctrl_i[alu_sub] (n6490),
    .\ctrl_i[alu_opa_mux] (n6491),
    .\ctrl_i[alu_opb_mux] (n6492),
    .\ctrl_i[alu_unsigned] (n6493),
    .\ctrl_i[alu_imm] (n6494),
    .\ctrl_i[alu_cp_alu] (n6495),
    .\ctrl_i[alu_cp_cfu] (n6496),
    .\ctrl_i[alu_cp_fpu] (n6497),
    .\ctrl_i[lsu_req] (n6498),
    .\ctrl_i[lsu_rd] (n6499),
    .\ctrl_i[lsu_wr] (n6500),
    .\ctrl_i[lsu_mo_en] (n6501),
    .\ctrl_i[lsu_mi_en] (n6502),
    .\ctrl_i[lsu_priv] (n6503),
    .\ctrl_i[lsu_fence] (n6504),
    .\ctrl_i[csr_we] (n6505),
    .\ctrl_i[csr_re] (n6506),
    .\ctrl_i[csr_addr] (n6507),
    .\ctrl_i[csr_wdata] (n6508),
    .\ctrl_i[cnt_event] (n6509),
    .\ctrl_i[ir_funct3] (n6510),
    .\ctrl_i[ir_funct12] (n6511),
    .\ctrl_i[ir_opcode] (n6512),
    .\ctrl_i[ir_rvc] (n6513),
    .\ctrl_i[cpu_priv] (n6514),
    .\ctrl_i[cpu_trap] (n6515),
    .\ctrl_i[cpu_sync_exc] (n6516),
    .\ctrl_i[cpu_debug] (n6517),
    .rs1_i(rs1_i),
    .rs2_i(rs2_i),
    .res_o(\neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o ),
    .valid_o(\neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o ));
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6478 = n6318[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6479 = n6318[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6480 = n6318[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6481 = n6318[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6482 = n6318[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6483 = n6318[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6484 = n6318[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6485 = n6318[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6486 = n6318[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6487 = n6318[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6488 = n6318[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6489 = n6318[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6490 = n6318[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6491 = n6318[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6492 = n6318[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6493 = n6318[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6494 = n6318[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6495 = n6318[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6496 = n6318[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6497 = n6318[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6498 = n6318[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6499 = n6318[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6500 = n6318[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6501 = n6318[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6502 = n6318[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6503 = n6318[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6504 = n6318[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6505 = n6318[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6506 = n6318[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6507 = n6318[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6508 = n6318[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6509 = n6318[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6510 = n6318[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6511 = n6318[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6512 = n6318[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6513 = n6318[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6514 = n6318[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6515 = n6318[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6516 = n6318[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:169:5 */
  assign n6517 = n6318[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:79:10 */
  assign n6538 = {n6340, n6336};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:83:10 */
  assign n6539 = {\neorv32_cpu_alu_shifter_inst.res_o , \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.res_o , 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:84:10 */
  assign n6540 = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, \neorv32_cpu_alu_muldiv_enabled_neorv32_cpu_alu_muldiv_inst.valid_o , \neorv32_cpu_alu_shifter_inst.valid_o };
  /*# ../../rtl/core/neorv32_cpu_alu.vhd:54:5 */
  assign n6541 = {n6384, n6374};
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
  wire [261:0] n6257;
  wire rf_we;
  wire [4:0] addr;
  wire n6260;
  wire n6268;
  wire n6270;
  wire n6272;
  wire n6273;
  wire n6274;
  wire n6275;
  wire n6276;
  wire n6277;
  wire n6278;
  wire n6279;
  wire n6280;
  wire n6281;
  wire n6282;
  wire n6284;
  wire [4:0] n6285;
  wire [4:0] n6286;
  wire n6287;
  wire [4:0] n6288;
  wire [4:0] n6289;
  wire [4:0] n6299;
  reg [31:0] n6314; // mem_rd
  reg [31:0] n6316; // mem_rd
  assign rs1_o = n6316; //(module output)
  assign rs2_o = n6314; //(module output)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:28:8 */
  assign n6257 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:49:10 */
  assign rf_we = n6282; // (signal)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:50:10 */
  assign addr = n6285; // (signal)
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:22 */
  assign n6260 = n6257[99]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6268 = n6257[114]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6270 = 1'b0 | n6268;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6272 = n6257[113]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6273 = n6270 | n6272;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6274 = n6257[112]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6275 = n6273 | n6274;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6276 = n6257[111]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6277 = n6275 | n6276;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n6278 = n6257[110]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n6279 = n6277 | n6278;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:31 */
  assign n6280 = n6260 & n6279;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:91 */
  assign n6281 = n6257[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:67:81 */
  assign n6282 = n6280 | n6281;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:43 */
  assign n6284 = n6257[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:30 */
  assign n6285 = n6284 ? 5'b00000 : n6288;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:21 */
  assign n6286 = n6257[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:43 */
  assign n6287 = n6257[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:68:59 */
  assign n6288 = n6287 ? n6286 : n6289;
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:69:71 */
  assign n6289 = n6257[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_regfile.vhd:79:59 */
  assign n6299 = n6257[109:105]; // extract
  reg [31:0] regfile[31:0] ; // memory
  always @(posedge clk_i)
    if (1'b1)
      n6314 <= regfile[n6299];
  always @(posedge clk_i)
    if (1'b1)
      n6316 <= regfile[addr];
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
  wire n3080;
  wire n3081;
  wire n3082;
  wire [31:0] n3083;
  wire [31:0] n3084;
  wire [31:0] n3085;
  wire n3086;
  wire [4:0] n3087;
  wire [4:0] n3088;
  wire [4:0] n3089;
  wire n3090;
  wire [2:0] n3091;
  wire n3092;
  wire n3093;
  wire n3094;
  wire n3095;
  wire [31:0] n3096;
  wire n3097;
  wire n3098;
  wire n3099;
  wire n3100;
  wire n3101;
  wire n3102;
  wire n3103;
  wire n3104;
  wire n3105;
  wire n3106;
  wire n3107;
  wire n3108;
  wire [11:0] n3109;
  wire [31:0] n3110;
  wire [8:0] n3111;
  wire [2:0] n3112;
  wire [11:0] n3113;
  wire [6:0] n3114;
  wire [15:0] n3115;
  wire n3116;
  wire n3117;
  wire n3118;
  wire n3119;
  wire [50:0] n3120;
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
  wire n3123;
  wire n3124;
  wire n3125;
  wire n3126;
  wire n3127;
  wire n3128;
  wire n3129;
  wire n3130;
  wire n3131;
  wire n3132;
  wire n3133;
  wire n3135;
  wire n3138;
  wire [116:0] n3148;
  wire [4:0] n3157;
  wire [6:0] n3159;
  wire [6:0] n3160;
  wire [2:0] n3161;
  wire [11:0] n3162;
  localparam [261:0] n3163 = 262'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [82:0] n3164;
  wire n3166;
  wire n3169;
  wire n3172;
  wire [20:0] n3178;
  wire [5:0] n3180;
  wire [26:0] n3181;
  wire [4:0] n3182;
  wire [31:0] n3183;
  wire n3185;
  wire n3187;
  wire [19:0] n3193;
  wire n3195;
  wire [20:0] n3196;
  wire [5:0] n3197;
  wire [26:0] n3198;
  wire [3:0] n3199;
  wire [30:0] n3200;
  wire [31:0] n3202;
  wire n3204;
  wire [19:0] n3205;
  wire [31:0] n3207;
  wire n3209;
  wire n3211;
  wire n3212;
  wire n3214;
  wire [11:0] n3220;
  wire [7:0] n3222;
  wire [19:0] n3223;
  wire n3224;
  wire [20:0] n3225;
  wire [9:0] n3226;
  wire [30:0] n3227;
  wire [31:0] n3229;
  wire n3231;
  wire n3234;
  wire n3236;
  wire [20:0] n3242;
  wire [9:0] n3244;
  wire [30:0] n3245;
  wire n3246;
  wire [31:0] n3247;
  wire [4:0] n3248;
  reg [31:0] n3249;
  wire n3252;
  wire n3253;
  wire n3254;
  wire n3255;
  wire n3258;
  wire n3260;
  wire n3261;
  wire n3263;
  wire n3264;
  wire n3266;
  wire n3267;
  wire n3268;
  wire n3271;
  wire n3273;
  wire [3:0] n3274;
  wire n3279;
  wire n3282;
  wire n3284;
  wire [31:0] n3287;
  wire n3288;
  wire n3290;
  wire n3291;
  wire n3292;
  wire n3293;
  wire n3294;
  wire [31:0] n3295;
  wire [15:0] n3296;
  wire [30:0] n3297;
  wire [31:0] n3299;
  wire [4:0] n3301;
  wire n3303;
  wire [11:0] n3304;
  wire [11:0] n3305;
  wire [84:0] n3306;
  wire [84:0] n3307;
  wire [84:0] n3308;
  wire n3309;
  wire n3311;
  wire [3:0] n3312;
  wire [3:0] n3313;
  wire [80:0] n3314;
  wire [80:0] n3315;
  wire [80:0] n3316;
  wire [11:0] n3317;
  wire n3319;
  wire n3321;
  wire n3324;
  wire n3325;
  wire n3326;
  wire [24:0] n3327;
  wire [4:0] n3328;
  wire [29:0] n3329;
  wire [31:0] n3331;
  wire [29:0] n3332;
  wire [31:0] n3334;
  wire [31:0] n3335;
  wire n3338;
  wire [30:0] n3340;
  wire [31:0] n3342;
  wire n3345;
  wire [30:0] n3346;
  wire [31:0] n3348;
  wire n3351;
  wire n3354;
  wire n3356;
  wire n3359;
  wire n3362;
  wire n3365;
  wire [5:0] n3367;
  reg [2:0] n3368;
  wire [1:0] n3369;
  wire n3371;
  wire n3373;
  wire n3374;
  wire n3375;
  wire n3376;
  wire n3377;
  wire n3378;
  wire n3380;
  wire n3381;
  wire n3382;
  wire n3383;
  wire n3385;
  wire n3386;
  wire n3388;
  wire n3389;
  wire n3390;
  wire n3392;
  wire n3394;
  wire n3395;
  wire n3397;
  wire n3399;
  wire n3400;
  wire n3401;
  wire n3403;
  wire n3405;
  wire n3406;
  wire n3407;
  wire n3409;
  wire n3411;
  wire n3412;
  wire n3413;
  wire n3415;
  wire n3417;
  wire n3418;
  wire n3419;
  wire n3421;
  wire n3423;
  wire n3424;
  wire n3425;
  wire n3427;
  wire n3429;
  wire n3430;
  wire n3431;
  wire n3432;
  wire n3433;
  wire [3:0] n3438;
  wire n3439;
  wire n3440;
  wire n3441;
  wire n3442;
  wire n3444;
  wire n3446;
  wire n3447;
  wire n3452;
  wire n3456;
  wire n3457;
  wire n3458;
  wire n3459;
  wire n3462;
  wire n3464;
  wire n3465;
  wire n3467;
  wire n3468;
  wire n3471;
  wire n3473;
  wire n3474;
  wire n3476;
  wire n3477;
  wire n3478;
  wire n3488;
  wire n3490;
  wire n3492;
  wire n3493;
  wire n3494;
  wire n3495;
  wire n3496;
  wire n3497;
  wire n3498;
  wire n3499;
  wire n3500;
  wire n3501;
  wire n3502;
  wire n3503;
  wire n3504;
  wire n3505;
  wire [3:0] n3507;
  wire n3508;
  wire n3509;
  wire n3510;
  wire n3511;
  wire n3513;
  wire n3517;
  wire n3521;
  wire n3523;
  wire n3524;
  wire n3526;
  wire n3527;
  wire n3529;
  wire n3530;
  wire n3532;
  wire n3534;
  wire n3535;
  wire n3537;
  wire n3538;
  wire [7:0] n3540;
  reg [3:0] n3541;
  wire n3542;
  reg n3543;
  wire n3544;
  reg n3545;
  wire [2:0] n3546;
  reg [2:0] n3547;
  wire n3548;
  reg n3549;
  wire n3550;
  reg n3551;
  wire n3552;
  reg n3553;
  wire n3554;
  reg n3555;
  reg n3556;
  reg n3557;
  wire n3558;
  reg n3559;
  wire n3560;
  reg n3561;
  wire n3563;
  wire n3572;
  wire n3574;
  wire n3576;
  wire n3577;
  wire n3578;
  wire n3579;
  wire n3580;
  wire [3:0] n3582;
  wire [3:0] n3583;
  wire n3585;
  wire n3587;
  wire n3589;
  wire n3590;
  wire n3591;
  wire n3594;
  wire [30:0] n3595;
  wire [31:0] n3597;
  wire [31:0] n3598;
  wire [31:0] n3599;
  wire n3601;
  wire [30:0] n3602;
  wire [31:0] n3604;
  wire n3605;
  wire n3608;
  wire n3616;
  wire n3618;
  wire n3620;
  wire n3621;
  wire n3622;
  wire n3623;
  wire n3624;
  wire [3:0] n3628;
  wire n3629;
  wire n3630;
  wire n3632;
  wire n3633;
  wire n3641;
  wire n3643;
  wire n3645;
  wire n3646;
  wire n3647;
  wire n3648;
  wire n3649;
  wire n3650;
  wire n3651;
  wire n3652;
  wire [3:0] n3654;
  wire [3:0] n3655;
  wire n3656;
  wire n3657;
  wire n3659;
  wire n3668;
  wire n3670;
  wire n3672;
  wire n3673;
  wire n3674;
  wire n3675;
  wire n3676;
  wire n3678;
  wire [2:0] n3679;
  wire n3681;
  wire n3683;
  wire n3686;
  wire n3689;
  wire [3:0] n3691;
  reg [3:0] n3692;
  reg n3695;
  reg n3698;
  wire n3700;
  wire n3702;
  wire n3704;
  wire n3705;
  wire [4:0] n3706;
  wire n3708;
  wire n3709;
  wire n3710;
  wire n3712;
  wire n3713;
  wire [3:0] n3714;
  wire n3715;
  wire n3716;
  wire n3718;
  wire n3720;
  wire n3721;
  wire n3722;
  wire n3723;
  wire n3725;
  wire n3727;
  wire n3730;
  wire n3737;
  wire n3739;
  wire n3741;
  wire n3742;
  wire n3743;
  wire n3744;
  wire n3745;
  wire n3746;
  wire n3747;
  wire n3748;
  wire n3749;
  wire n3750;
  wire n3751;
  wire n3752;
  wire n3753;
  wire n3754;
  wire n3755;
  wire n3756;
  wire n3757;
  wire n3758;
  wire n3759;
  wire n3760;
  wire n3761;
  wire n3762;
  wire n3763;
  wire n3764;
  wire n3765;
  wire n3766;
  wire n3767;
  wire n3768;
  wire n3769;
  wire n3770;
  wire n3771;
  wire n3772;
  wire n3773;
  wire n3774;
  wire n3775;
  wire n3776;
  wire n3777;
  wire n3778;
  wire n3779;
  wire [3:0] n3781;
  wire [3:0] n3782;
  wire [9:0] n3783;
  reg [3:0] n3784;
  wire [80:0] n3785;
  reg [80:0] n3786;
  wire [31:0] n3787;
  reg [31:0] n3788;
  wire n3791;
  reg n3792;
  wire n3793;
  reg n3794;
  wire [31:0] n3795;
  reg [31:0] n3796;
  wire n3797;
  reg n3798;
  wire n3799;
  reg n3800;
  wire [2:0] n3801;
  reg [2:0] n3802;
  wire n3803;
  reg n3804;
  reg n3805;
  reg n3806;
  reg [31:0] n3807;
  wire n3808;
  reg n3809;
  wire n3810;
  reg n3811;
  wire n3812;
  reg n3813;
  wire n3814;
  reg n3815;
  reg n3816;
  reg n3817;
  wire n3818;
  reg n3819;
  wire n3820;
  reg n3821;
  wire n3822;
  reg n3823;
  reg [11:0] n3824;
  wire n3827;
  wire [63:0] n3829;
  wire [14:0] n3832;
  wire [2:0] n3838;
  reg n3842;
  reg n3846;
  reg n3849;
  reg n3852;
  reg n3855;
  reg n3858;
  wire n3861;
  wire [3:0] n3863;
  wire n3865;
  wire n3866;
  wire n3868;
  wire [30:0] n3869;
  wire [31:0] n3871;
  wire [30:0] n3872;
  wire [31:0] n3874;
  wire [30:0] n3875;
  wire [31:0] n3877;
  wire n3878;
  wire n3886;
  wire n3888;
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
  wire [4:0] n3908;
  wire [4:0] n3909;
  wire [4:0] n3910;
  wire n3911;
  wire [2:0] n3912;
  wire n3913;
  wire n3914;
  wire n3915;
  wire n3916;
  wire [31:0] n3917;
  wire n3918;
  wire n3926;
  wire n3928;
  wire n3930;
  wire n3931;
  wire n3932;
  wire n3933;
  wire n3934;
  wire n3935;
  wire n3936;
  wire n3944;
  wire n3946;
  wire n3948;
  wire n3949;
  wire n3950;
  wire n3951;
  wire n3952;
  wire n3953;
  wire n3954;
  wire n3962;
  wire n3964;
  wire n3966;
  wire n3967;
  wire n3968;
  wire n3969;
  wire n3970;
  wire n3971;
  wire n3972;
  wire n3973;
  wire n3974;
  wire [3:0] n3976;
  wire n3978;
  wire n3979;
  wire [3:0] n3982;
  wire n3984;
  wire n3985;
  wire n3987;
  wire n3988;
  wire n3989;
  wire n3990;
  wire n3991;
  wire n3992;
  wire n3993;
  wire [11:0] n3994;
  wire [2:0] n3995;
  wire [11:0] n3996;
  wire [6:0] n3997;
  wire [15:0] n3998;
  wire n3999;
  wire n4000;
  wire [3:0] n4002;
  wire n4004;
  wire n4005;
  wire [3:0] n4008;
  wire n4010;
  wire n4011;
  wire [3:0] n4014;
  wire n4016;
  wire n4017;
  wire n4018;
  wire n4019;
  wire [3:0] n4022;
  wire n4024;
  wire n4025;
  wire n4026;
  wire n4027;
  wire n4028;
  wire [3:0] n4031;
  wire n4033;
  wire n4034;
  wire n4037;
  wire n4038;
  wire [3:0] n4039;
  wire n4041;
  wire n4042;
  wire n4043;
  wire n4046;
  wire [4:0] n4047;
  wire n4049;
  wire n4050;
  wire n4051;
  wire n4054;
  wire n4055;
  wire n4056;
  wire n4057;
  wire n4060;
  wire n4061;
  wire n4062;
  wire n4063;
  wire [11:0] n4066;
  wire n4070;
  wire n4072;
  wire n4073;
  wire n4075;
  wire n4076;
  wire n4079;
  wire n4081;
  wire n4082;
  wire n4084;
  wire n4085;
  wire n4087;
  wire n4088;
  wire n4090;
  wire n4091;
  wire n4093;
  wire n4094;
  wire n4096;
  wire n4097;
  wire n4099;
  wire n4100;
  wire n4102;
  wire n4103;
  wire n4105;
  wire n4106;
  wire n4108;
  wire n4109;
  wire n4111;
  wire n4112;
  wire n4114;
  wire n4115;
  wire n4117;
  wire n4118;
  wire n4120;
  wire n4121;
  wire n4123;
  wire n4124;
  wire n4126;
  wire n4127;
  wire n4129;
  wire n4130;
  wire n4134;
  wire n4136;
  wire n4137;
  wire n4139;
  wire n4140;
  wire n4144;
  wire n4146;
  wire n4147;
  wire n4149;
  wire n4150;
  wire n4152;
  wire n4153;
  wire n4155;
  wire n4156;
  wire n4158;
  wire n4159;
  wire n4161;
  wire n4162;
  wire n4164;
  wire n4165;
  wire n4167;
  wire n4168;
  wire n4170;
  wire n4171;
  wire n4173;
  wire n4174;
  wire n4176;
  wire n4177;
  wire n4179;
  wire n4180;
  wire n4182;
  wire n4183;
  wire n4185;
  wire n4186;
  wire n4188;
  wire n4189;
  wire n4191;
  wire n4192;
  wire n4194;
  wire n4195;
  wire n4197;
  wire n4198;
  wire n4200;
  wire n4201;
  wire n4205;
  wire n4207;
  wire n4208;
  wire n4210;
  wire n4211;
  wire n4213;
  wire n4214;
  wire n4216;
  wire n4217;
  wire n4219;
  wire n4220;
  wire n4222;
  wire n4223;
  wire n4225;
  wire n4226;
  wire n4228;
  wire n4229;
  wire n4231;
  wire n4232;
  wire n4234;
  wire n4235;
  wire n4237;
  wire n4238;
  wire n4240;
  wire n4241;
  wire n4243;
  wire n4244;
  wire n4246;
  wire n4247;
  wire n4249;
  wire n4250;
  wire n4252;
  wire n4253;
  wire n4255;
  wire n4256;
  wire n4258;
  wire n4259;
  wire n4261;
  wire n4262;
  wire n4264;
  wire n4265;
  wire n4267;
  wire n4268;
  wire n4270;
  wire n4271;
  wire n4273;
  wire n4274;
  wire n4276;
  wire n4277;
  wire n4279;
  wire n4280;
  wire n4282;
  wire n4283;
  wire n4285;
  wire n4286;
  wire n4288;
  wire n4289;
  wire n4291;
  wire n4292;
  wire n4294;
  wire n4295;
  wire n4297;
  wire n4298;
  wire n4300;
  wire n4301;
  wire n4303;
  wire n4304;
  wire n4306;
  wire n4307;
  wire n4309;
  wire n4310;
  wire n4312;
  wire n4313;
  wire n4315;
  wire n4316;
  wire n4318;
  wire n4319;
  wire n4321;
  wire n4322;
  wire n4324;
  wire n4325;
  wire n4327;
  wire n4328;
  wire n4330;
  wire n4331;
  wire n4333;
  wire n4334;
  wire n4336;
  wire n4337;
  wire n4339;
  wire n4340;
  wire n4342;
  wire n4343;
  wire n4345;
  wire n4346;
  wire n4348;
  wire n4349;
  wire n4351;
  wire n4352;
  wire n4354;
  wire n4355;
  wire n4357;
  wire n4358;
  wire n4360;
  wire n4361;
  wire n4363;
  wire n4364;
  wire n4366;
  wire n4367;
  wire n4369;
  wire n4370;
  wire n4372;
  wire n4373;
  wire n4375;
  wire n4376;
  wire n4378;
  wire n4379;
  wire n4381;
  wire n4382;
  wire n4384;
  wire n4385;
  wire n4387;
  wire n4388;
  wire n4390;
  wire n4391;
  wire n4393;
  wire n4394;
  wire n4396;
  wire n4397;
  wire n4399;
  wire n4400;
  wire n4402;
  wire n4403;
  wire n4405;
  wire n4406;
  wire n4408;
  wire n4409;
  wire n4411;
  wire n4412;
  wire n4414;
  wire n4415;
  wire n4417;
  wire n4418;
  wire n4420;
  wire n4421;
  wire n4423;
  wire n4424;
  wire n4426;
  wire n4427;
  wire n4429;
  wire n4430;
  wire n4432;
  wire n4433;
  wire n4435;
  wire n4436;
  wire n4438;
  wire n4439;
  wire n4441;
  wire n4442;
  wire n4444;
  wire n4445;
  wire n4447;
  wire n4448;
  wire n4450;
  wire n4451;
  wire n4453;
  wire n4454;
  wire n4456;
  wire n4457;
  wire n4459;
  wire n4460;
  wire n4462;
  wire n4463;
  wire n4465;
  wire n4466;
  wire n4468;
  wire n4469;
  wire n4471;
  wire n4472;
  wire n4474;
  wire n4475;
  wire n4477;
  wire n4478;
  wire n4480;
  wire n4481;
  wire n4483;
  wire n4484;
  wire n4486;
  wire n4487;
  wire n4489;
  wire n4490;
  wire n4492;
  wire n4493;
  wire n4495;
  wire n4496;
  wire n4498;
  wire n4499;
  wire n4501;
  wire n4502;
  wire n4504;
  wire n4505;
  wire n4507;
  wire n4508;
  wire n4510;
  wire n4511;
  wire n4513;
  wire n4514;
  wire n4516;
  wire n4517;
  wire n4519;
  wire n4520;
  wire n4522;
  wire n4523;
  wire n4525;
  wire n4526;
  wire n4528;
  wire n4529;
  wire n4531;
  wire n4532;
  wire n4534;
  wire n4535;
  wire n4537;
  wire n4538;
  wire n4540;
  wire n4541;
  wire n4543;
  wire n4544;
  wire n4546;
  wire n4547;
  wire n4549;
  wire n4550;
  wire n4552;
  wire n4553;
  wire n4555;
  wire n4556;
  wire n4558;
  wire n4559;
  wire n4561;
  wire n4562;
  wire n4564;
  wire n4565;
  wire n4567;
  wire n4568;
  wire n4570;
  wire n4571;
  wire n4573;
  wire n4574;
  wire n4576;
  wire n4577;
  wire n4579;
  wire n4580;
  wire n4582;
  wire n4583;
  wire n4585;
  wire n4586;
  wire n4588;
  wire n4589;
  wire n4591;
  wire n4592;
  wire n4594;
  wire n4595;
  wire n4597;
  wire n4598;
  wire n4600;
  wire n4601;
  wire n4603;
  wire n4604;
  wire n4606;
  wire n4607;
  wire n4609;
  wire n4610;
  wire n4612;
  wire n4613;
  wire n4615;
  wire n4616;
  wire n4618;
  wire n4619;
  wire n4621;
  wire n4622;
  wire n4624;
  wire n4625;
  wire n4627;
  wire n4628;
  wire n4630;
  wire n4631;
  wire n4633;
  wire n4634;
  wire n4636;
  wire n4637;
  wire n4641;
  wire n4643;
  wire n4644;
  wire n4646;
  wire n4647;
  wire n4649;
  wire n4650;
  wire n4652;
  wire n4653;
  wire n4655;
  wire n4656;
  wire n4658;
  wire n4659;
  wire n4661;
  wire n4662;
  wire n4664;
  wire n4665;
  wire n4667;
  wire n4668;
  wire n4672;
  wire n4674;
  wire n4675;
  wire n4677;
  wire n4678;
  wire n4680;
  wire n4681;
  wire n4685;
  wire n4687;
  wire n4688;
  wire n4690;
  wire n4691;
  wire n4695;
  wire n4697;
  wire n4698;
  wire n4700;
  wire n4701;
  wire n4703;
  wire n4704;
  wire n4706;
  wire n4707;
  wire [8:0] n4709;
  reg n4710;
  wire [1:0] n4711;
  wire n4713;
  wire [2:0] n4714;
  wire n4716;
  wire [2:0] n4717;
  wire n4719;
  wire n4720;
  wire [4:0] n4721;
  wire n4723;
  wire n4724;
  wire n4725;
  wire n4728;
  wire [1:0] n4732;
  wire n4734;
  wire n4735;
  wire n4736;
  wire n4737;
  wire n4740;
  wire [6:0] n4743;
  wire n4745;
  wire n4747;
  wire n4748;
  wire n4750;
  wire n4751;
  wire [2:0] n4752;
  wire n4754;
  wire n4757;
  wire n4759;
  wire [1:0] n4760;
  wire n4762;
  wire n4764;
  wire n4767;
  wire n4769;
  wire [2:0] n4770;
  wire n4772;
  wire n4774;
  wire n4775;
  wire n4777;
  wire n4778;
  wire n4780;
  wire n4781;
  wire n4783;
  wire n4784;
  reg n4787;
  wire n4789;
  wire [2:0] n4790;
  wire n4792;
  wire n4794;
  wire n4795;
  wire n4797;
  wire n4798;
  reg n4801;
  wire n4803;
  wire n4843;
  wire n4845;
  wire n4847;
  wire n4848;
  wire n4850;
  wire n4851;
  wire n4853;
  wire n4854;
  wire n4856;
  wire n4857;
  wire n4859;
  wire n4860;
  wire n4862;
  wire n4863;
  wire [1:0] n4864;
  wire n4866;
  wire n4869;
  wire n4871;
  wire [2:0] n4872;
  wire n4874;
  wire [4:0] n4875;
  wire n4877;
  wire [4:0] n4878;
  wire n4880;
  wire n4881;
  wire [11:0] n4882;
  wire n4884;
  wire n4886;
  wire n4887;
  wire n4888;
  wire n4889;
  wire n4890;
  wire n4892;
  wire n4893;
  wire n4894;
  wire n4896;
  wire n4897;
  wire n4898;
  wire n4899;
  wire n4900;
  wire n4902;
  wire [4:0] n4903;
  reg n4907;
  wire n4909;
  wire [2:0] n4910;
  wire n4912;
  wire n4914;
  wire n4917;
  wire n4919;
  wire n4920;
  wire n4922;
  wire [8:0] n4923;
  reg n4928;
  wire n4932;
  wire [3:0] n4934;
  wire n4936;
  wire [9:0] n4938;
  wire [9:0] n4940;
  wire [3:0] n4946;
  wire n4948;
  wire [3:0] n4949;
  wire n4951;
  wire n4952;
  wire n4953;
  wire n4954;
  wire n4955;
  wire n4956;
  wire n4959;
  wire n4961;
  wire [16:0] n4962;
  wire [19:0] n4963;
  wire n4964;
  wire n4965;
  wire n4966;
  wire n4967;
  wire n4968;
  wire n4969;
  wire n4970;
  wire n4971;
  wire n4972;
  wire n4973;
  wire n4974;
  wire n4975;
  wire n4976;
  wire n4977;
  wire n4978;
  wire n4979;
  wire n4980;
  wire n4981;
  wire n4982;
  wire n4983;
  wire n4984;
  wire n4985;
  wire n4986;
  wire n4987;
  wire n4988;
  wire n4989;
  wire n4990;
  wire n4991;
  wire n4992;
  wire n4993;
  wire n4994;
  wire n4995;
  wire n4996;
  wire n4997;
  wire n4998;
  wire n4999;
  wire n5000;
  wire n5001;
  wire n5002;
  wire n5003;
  wire n5004;
  wire n5005;
  wire n5006;
  wire n5007;
  wire n5008;
  wire n5009;
  wire n5010;
  wire n5011;
  wire n5012;
  wire n5013;
  wire n5014;
  wire n5015;
  wire n5016;
  wire n5017;
  wire n5018;
  wire n5019;
  wire n5020;
  wire n5021;
  wire n5022;
  wire n5023;
  wire n5024;
  wire n5025;
  wire n5026;
  wire n5027;
  wire n5028;
  wire n5029;
  wire n5030;
  wire n5031;
  wire n5032;
  wire n5033;
  wire n5034;
  wire n5035;
  wire n5036;
  wire n5037;
  wire n5038;
  wire n5039;
  wire n5040;
  wire n5041;
  wire n5042;
  wire n5043;
  wire n5044;
  wire n5045;
  wire n5046;
  wire n5047;
  wire n5048;
  wire n5049;
  wire n5050;
  wire n5051;
  wire n5052;
  wire n5053;
  wire n5054;
  wire n5055;
  wire n5056;
  wire n5057;
  wire n5058;
  wire n5059;
  wire n5060;
  wire n5061;
  wire n5062;
  wire n5063;
  wire n5064;
  wire n5065;
  wire n5066;
  wire n5067;
  wire n5068;
  wire n5069;
  wire n5070;
  wire n5071;
  wire n5072;
  wire n5073;
  wire n5074;
  wire n5075;
  wire n5076;
  wire n5077;
  wire n5078;
  wire n5079;
  wire n5080;
  wire n5081;
  wire n5082;
  wire n5083;
  wire n5084;
  wire n5085;
  wire n5086;
  wire n5087;
  wire n5088;
  wire n5089;
  wire n5090;
  wire n5091;
  wire n5092;
  wire n5093;
  wire n5094;
  wire n5095;
  wire n5096;
  wire n5097;
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
  wire [11:0] n5137;
  wire [19:0] n5140;
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
  wire n5168;
  wire n5176;
  wire n5178;
  wire n5180;
  wire n5181;
  wire n5182;
  wire n5184;
  wire n5186;
  wire n5197;
  wire n5199;
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
  wire [3:0] n5224;
  wire n5226;
  wire [3:0] n5227;
  wire n5229;
  wire n5230;
  wire n5238;
  wire n5240;
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
  wire n5271;
  wire n5272;
  wire n5273;
  wire n5274;
  wire n5275;
  wire n5276;
  wire n5277;
  wire n5278;
  wire n5279;
  wire n5280;
  wire n5281;
  wire n5282;
  wire n5283;
  wire n5284;
  wire n5285;
  wire n5286;
  wire n5287;
  wire n5288;
  wire n5289;
  wire n5290;
  wire n5292;
  wire n5294;
  wire [6:0] n5295;
  wire n5297;
  wire [6:0] n5298;
  wire n5300;
  wire [6:0] n5301;
  wire n5302;
  wire [6:0] n5303;
  wire n5305;
  wire [6:0] n5306;
  wire n5308;
  wire [6:0] n5309;
  wire n5311;
  wire [6:0] n5312;
  wire n5314;
  wire [6:0] n5315;
  wire n5317;
  wire [6:0] n5318;
  wire n5320;
  wire [6:0] n5321;
  wire n5323;
  wire [6:0] n5324;
  wire n5326;
  wire [6:0] n5327;
  wire n5329;
  wire [6:0] n5330;
  wire n5332;
  wire [6:0] n5333;
  wire n5335;
  wire [6:0] n5336;
  wire n5338;
  wire [6:0] n5339;
  wire n5341;
  wire [6:0] n5342;
  wire n5344;
  wire [6:0] n5345;
  wire n5347;
  wire [6:0] n5348;
  wire n5350;
  wire [6:0] n5351;
  wire n5353;
  wire [6:0] n5354;
  wire n5356;
  wire [6:0] n5357;
  wire n5359;
  wire [6:0] n5360;
  wire n5362;
  wire [6:0] n5363;
  wire n5365;
  wire [6:0] n5366;
  wire n5368;
  wire [6:0] n5369;
  wire n5371;
  wire [6:0] n5372;
  wire n5374;
  wire [6:0] n5375;
  wire n5377;
  wire [6:0] n5378;
  wire n5380;
  wire [6:0] n5381;
  wire n5383;
  wire [6:0] n5384;
  wire n5386;
  wire [5:0] n5388;
  wire n5389;
  wire [6:0] n5390;
  wire [31:0] n5391;
  wire n5392;
  wire [31:0] n5393;
  wire [31:0] n5394;
  wire n5422;
  wire n5423;
  wire [4:0] n5425;
  wire [31:0] n5427;
  wire [31:0] n5428;
  wire [1:0] n5429;
  wire [31:0] n5430;
  wire n5432;
  wire [31:0] n5433;
  wire [31:0] n5434;
  wire n5436;
  wire [1:0] n5437;
  reg [31:0] n5438;
  wire n5441;
  wire n5466;
  wire [11:0] n5467;
  wire n5468;
  wire n5469;
  wire n5477;
  wire n5479;
  wire n5481;
  wire n5482;
  wire n5483;
  wire n5484;
  wire n5486;
  wire n5487;
  wire n5488;
  wire n5489;
  wire [15:0] n5490;
  wire n5492;
  wire [29:0] n5493;
  wire [30:0] n5495;
  wire n5496;
  wire [31:0] n5497;
  wire n5499;
  wire n5501;
  wire n5503;
  wire [30:0] n5504;
  wire [31:0] n5506;
  wire n5508;
  wire n5509;
  wire [4:0] n5510;
  wire [5:0] n5511;
  wire n5513;
  wire n5515;
  wire n5516;
  wire n5517;
  wire n5518;
  wire n5526;
  wire n5528;
  wire n5530;
  wire n5531;
  wire n5533;
  wire n5538;
  wire n5540;
  wire [10:0] n5541;
  wire n5542;
  reg n5543;
  wire n5544;
  reg n5545;
  wire n5546;
  reg n5547;
  wire n5548;
  reg n5549;
  wire n5550;
  reg n5551;
  wire n5552;
  reg n5553;
  wire n5554;
  reg n5555;
  wire n5556;
  reg n5557;
  wire [15:0] n5558;
  reg [15:0] n5559;
  wire [31:0] n5560;
  reg [31:0] n5561;
  wire [5:0] n5562;
  reg [5:0] n5563;
  wire [31:0] n5564;
  reg [31:0] n5565;
  wire [31:0] n5566;
  reg [31:0] n5567;
  wire [31:0] n5568;
  reg [31:0] n5569;
  wire [31:0] n5570;
  reg [31:0] n5571;
  wire n5572;
  reg n5573;
  wire n5574;
  reg n5575;
  wire n5576;
  reg n5577;
  wire n5578;
  reg n5579;
  wire n5584;
  wire n5585;
  wire n5587;
  wire n5589;
  wire n5590;
  wire [4:0] n5591;
  wire [5:0] n5592;
  wire [30:0] n5593;
  wire [31:0] n5595;
  wire n5596;
  wire n5597;
  wire n5598;
  wire [1:0] n5599;
  wire n5601;
  wire n5602;
  wire n5604;
  wire [15:0] n5605;
  wire [31:0] n5607;
  wire [31:0] n5608;
  wire [31:0] n5609;
  wire [31:0] n5611;
  wire [31:0] n5612;
  wire [31:0] n5614;
  wire [3:0] n5615;
  wire [37:0] n5616;
  wire [3:0] n5617;
  wire [3:0] n5618;
  wire [37:0] n5619;
  wire [37:0] n5620;
  wire [31:0] n5621;
  wire [31:0] n5622;
  wire n5623;
  wire n5624;
  wire n5626;
  wire n5628;
  wire n5629;
  wire n5631;
  wire [4:0] n5633;
  wire [4:0] n5634;
  wire [4:0] n5635;
  wire [3:0] n5636;
  wire [3:0] n5637;
  wire n5638;
  wire n5639;
  wire n5640;
  wire n5642;
  wire n5644;
  wire [4:0] n5645;
  wire [193:0] n5646;
  wire n5648;
  wire n5649;
  wire n5650;
  wire [3:0] n5651;
  wire [3:0] n5652;
  wire [3:0] n5653;
  wire [19:0] n5654;
  wire [19:0] n5655;
  wire [19:0] n5656;
  wire [37:0] n5657;
  wire [37:0] n5658;
  wire [31:0] n5659;
  wire [31:0] n5660;
  wire [31:0] n5661;
  wire [31:0] n5662;
  wire [31:0] n5663;
  wire [67:0] n5664;
  wire [67:0] n5665;
  wire [67:0] n5666;
  wire [31:0] n5671;
  wire [261:0] n5685;
  wire [261:0] n5687;
  wire n5691;
  wire n5693;
  wire [11:0] n5694;
  wire n5695;
  wire n5696;
  wire n5697;
  wire n5698;
  wire n5699;
  wire n5700;
  wire n5703;
  wire n5705;
  localparam [1:0] n5721 = 2'b01;
  wire n5723;
  wire n5724;
  wire n5725;
  wire n5726;
  wire [15:0] n5727;
  wire n5729;
  wire [31:0] n5730;
  wire n5732;
  wire n5734;
  wire [31:0] n5735;
  wire n5737;
  wire [30:0] n5738;
  wire [31:0] n5740;
  wire n5742;
  wire n5743;
  wire [4:0] n5744;
  wire n5746;
  wire [31:0] n5747;
  wire n5749;
  wire n5750;
  wire n5751;
  wire n5752;
  wire [15:0] n5753;
  wire n5755;
  wire n5757;
  wire n5759;
  wire n5761;
  wire n5763;
  wire n5765;
  wire n5767;
  wire n5769;
  wire n5833;
  wire n5839;
  wire [18:0] n5840;
  wire n5841;
  wire n5842;
  wire n5843;
  wire n5844;
  wire n5845;
  wire n5850;
  reg n5852;
  wire n5853;
  wire n5854;
  wire n5855;
  wire n5856;
  wire n5857;
  wire n5862;
  reg n5864;
  wire n5865;
  wire n5866;
  wire n5867;
  wire n5868;
  wire n5869;
  wire n5874;
  reg n5876;
  wire n5877;
  wire n5878;
  wire n5879;
  wire n5880;
  wire n5881;
  wire n5886;
  reg n5888;
  wire n5889;
  wire n5890;
  wire n5891;
  wire n5892;
  wire n5893;
  wire n5898;
  reg n5900;
  wire n5901;
  wire n5902;
  wire n5903;
  wire n5904;
  wire n5909;
  reg n5911;
  wire n5912;
  wire n5913;
  wire n5914;
  wire n5915;
  wire n5920;
  reg n5922;
  wire n5923;
  wire n5924;
  wire n5925;
  wire n5926;
  wire n5931;
  reg n5933;
  wire n5934;
  wire n5935;
  wire n5936;
  wire n5937;
  wire n5942;
  reg n5944;
  wire n5945;
  wire n5946;
  wire n5947;
  wire n5948;
  wire n5953;
  reg n5955;
  wire n5956;
  wire n5957;
  wire n5958;
  wire n5959;
  wire n5964;
  reg n5966;
  wire n5967;
  wire n5968;
  wire n5969;
  wire n5970;
  wire n5975;
  reg n5977;
  wire n5978;
  wire n5979;
  wire n5980;
  wire n5981;
  wire n5986;
  reg n5988;
  wire n5989;
  wire n5990;
  wire n5991;
  wire n5992;
  wire n5997;
  reg n5999;
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
  wire n6019;
  reg n6021;
  wire n6022;
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
  wire n6039;
  wire n6040;
  wire n6045;
  reg n6047;
  wire n6048;
  wire n6049;
  wire n6050;
  wire n6051;
  wire n6052;
  wire n6053;
  wire n6058;
  reg n6060;
  wire n6061;
  wire n6062;
  wire n6063;
  wire n6064;
  wire n6065;
  wire n6066;
  wire n6071;
  reg n6073;
  wire n6074;
  wire n6075;
  wire n6076;
  wire n6077;
  wire n6078;
  wire n6079;
  wire n6084;
  reg n6086;
  wire n6087;
  wire n6088;
  wire n6089;
  wire n6090;
  wire n6091;
  wire n6092;
  wire n6097;
  reg n6099;
  wire n6100;
  wire n6101;
  wire n6102;
  wire n6103;
  wire n6104;
  wire n6105;
  wire n6110;
  reg n6112;
  wire n6113;
  wire n6114;
  wire n6115;
  wire n6116;
  wire n6117;
  wire n6118;
  wire n6123;
  reg n6125;
  wire n6126;
  wire n6127;
  wire n6128;
  wire n6129;
  wire n6130;
  wire n6131;
  wire n6136;
  reg n6138;
  wire n6139;
  wire n6140;
  wire n6141;
  wire n6142;
  wire n6143;
  wire n6144;
  wire n6149;
  reg n6151;
  wire n6152;
  wire n6153;
  wire n6154;
  wire n6155;
  wire n6156;
  wire n6157;
  wire n6162;
  reg n6164;
  wire n6165;
  wire n6166;
  wire n6167;
  wire n6168;
  wire n6169;
  wire n6170;
  wire n6175;
  reg n6177;
  wire n6178;
  wire n6179;
  wire n6180;
  wire n6181;
  wire n6182;
  wire n6183;
  wire n6188;
  reg n6190;
  wire n6191;
  wire n6192;
  wire n6193;
  wire n6194;
  wire n6195;
  wire n6196;
  wire n6201;
  reg n6203;
  wire n6204;
  wire n6205;
  wire n6206;
  wire n6207;
  wire n6208;
  wire n6209;
  wire n6210;
  wire n6215;
  reg n6217;
  wire n6218;
  wire n6219;
  wire n6220;
  wire n6221;
  wire n6222;
  wire n6223;
  wire n6224;
  wire n6229;
  reg n6231;
  wire [31:0] n6232;
  wire [31:0] n6234;
  wire [116:0] n6240;
  wire [261:0] n6241;
  wire [1:0] n6242;
  wire [4:0] n6244;
  wire [2:0] n6245;
  wire [8:0] n6246;
  wire [261:0] n6247;
  reg [116:0] n6248;
  reg [261:0] n6249;
  reg [11:0] n6250;
  reg [19:0] n6251;
  reg [19:0] n6252;
  reg n6253;
  reg [261:0] n6254;
  reg [31:0] n6255;
  reg [9:0] n6256;
  assign \ctrl_o[if_reset]  = n3080; //(module output)
  assign \ctrl_o[if_ready]  = n3081; //(module output)
  assign \ctrl_o[if_fence]  = n3082; //(module output)
  assign \ctrl_o[pc_cur]  = n3083; //(module output)
  assign \ctrl_o[pc_nxt]  = n3084; //(module output)
  assign \ctrl_o[pc_ret]  = n3085; //(module output)
  assign \ctrl_o[rf_wb_en]  = n3086; //(module output)
  assign \ctrl_o[rf_rs1]  = n3087; //(module output)
  assign \ctrl_o[rf_rs2]  = n3088; //(module output)
  assign \ctrl_o[rf_rd]  = n3089; //(module output)
  assign \ctrl_o[rf_zero]  = n3090; //(module output)
  assign \ctrl_o[alu_op]  = n3091; //(module output)
  assign \ctrl_o[alu_sub]  = n3092; //(module output)
  assign \ctrl_o[alu_opa_mux]  = n3093; //(module output)
  assign \ctrl_o[alu_opb_mux]  = n3094; //(module output)
  assign \ctrl_o[alu_unsigned]  = n3095; //(module output)
  assign \ctrl_o[alu_imm]  = n3096; //(module output)
  assign \ctrl_o[alu_cp_alu]  = n3097; //(module output)
  assign \ctrl_o[alu_cp_cfu]  = n3098; //(module output)
  assign \ctrl_o[alu_cp_fpu]  = n3099; //(module output)
  assign \ctrl_o[lsu_req]  = n3100; //(module output)
  assign \ctrl_o[lsu_rd]  = n3101; //(module output)
  assign \ctrl_o[lsu_wr]  = n3102; //(module output)
  assign \ctrl_o[lsu_mo_en]  = n3103; //(module output)
  assign \ctrl_o[lsu_mi_en]  = n3104; //(module output)
  assign \ctrl_o[lsu_priv]  = n3105; //(module output)
  assign \ctrl_o[lsu_fence]  = n3106; //(module output)
  assign \ctrl_o[csr_we]  = n3107; //(module output)
  assign \ctrl_o[csr_re]  = n3108; //(module output)
  assign \ctrl_o[csr_addr]  = n3109; //(module output)
  assign \ctrl_o[csr_wdata]  = n3110; //(module output)
  assign \ctrl_o[cnt_event]  = n3111; //(module output)
  assign \ctrl_o[ir_funct3]  = n3112; //(module output)
  assign \ctrl_o[ir_funct12]  = n3113; //(module output)
  assign \ctrl_o[ir_opcode]  = n3114; //(module output)
  assign \ctrl_o[ir_rvc]  = n3115; //(module output)
  assign \ctrl_o[cpu_priv]  = n3116; //(module output)
  assign \ctrl_o[cpu_trap]  = n3117; //(module output)
  assign \ctrl_o[cpu_sync_exc]  = n3118; //(module output)
  assign \ctrl_o[cpu_debug]  = n3119; //(module output)
  assign csr_rdata_o = csr_rdata; //(module output)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3080 = n6247[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3081 = n6247[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3082 = n6247[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3083 = n6247[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3084 = n6247[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3085 = n6247[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3086 = n6247[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3087 = n6247[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3088 = n6247[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3089 = n6247[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3090 = n6247[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3091 = n6247[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3092 = n6247[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3093 = n6247[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3094 = n6247[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3095 = n6247[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3096 = n6247[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3097 = n6247[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3098 = n6247[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3099 = n6247[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3100 = n6247[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3101 = n6247[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3102 = n6247[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3103 = n6247[161]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3104 = n6247[162]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3105 = n6247[163]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3106 = n6247[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3107 = n6247[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3108 = n6247[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3109 = n6247[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3110 = n6247[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3111 = n6247[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3112 = n6247[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3113 = n6247[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3114 = n6247[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3115 = n6247[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3116 = n6247[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3117 = n6247[259]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3118 = n6247[260]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3119 = n6247[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n3120 = {\frontend_i[fault] , \frontend_i[compr] , \frontend_i[i16] , \frontend_i[i32] , \frontend_i[valid] };
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:10 */
  assign exec = n6248; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign exec_nxt = n6240; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:10 */
  assign ctrl = n6249; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign ctrl_nxt = n6241; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:110:10 */
  assign exc_buf = n6250; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:111:10 */
  assign exc_fire = n5222; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:112:10 */
  assign irq_pnd = n6251; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:113:10 */
  assign irq_buf = n6252; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:114:10 */
  assign irq_fire = n6242; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:115:10 */
  assign env_pend = n6253; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:116:10 */
  assign env_enter = n3842; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:117:10 */
  assign env_exit = n3846; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:118:10 */
  assign instr_be = n3849; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:119:10 */
  assign instr_ma = n3852; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:120:10 */
  assign instr_il = n4956; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:121:10 */
  assign ecall = n3855; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:122:10 */
  assign ebreak = n3858; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:123:10 */
  assign epc = n5393; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:124:10 */
  assign ecause = n5295; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign csr = n6254; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:153:10 */
  assign csr_wdata = n5438; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:153:21 */
  assign csr_rdata = n6255; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:159:10 */
  assign debug_ctrl = n6244; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:162:10 */
  assign branch_taken = n3135; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:163:10 */
  assign monitor_cnt = n6256; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:164:10 */
  assign csr_valid = n6245; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:165:10 */
  assign illegal_cmd = n4928; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:166:10 */
  assign cnt_event = n6246; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:167:10 */
  assign ebreak_trig = n5166; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:168:10 */
  assign trap_env = n5390; // (signal)
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:16 */
  assign n3123 = exec[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:39 */
  assign n3124 = ~n3123;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:18 */
  assign n3125 = exec[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:39 */
  assign n3126 = ~n3125;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:34 */
  assign n3127 = alu_cmp_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:49 */
  assign n3128 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:182:38 */
  assign n3129 = n3127 ^ n3128;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:34 */
  assign n3130 = alu_cmp_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:49 */
  assign n3131 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:184:38 */
  assign n3132 = n3130 ^ n3131;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:181:7 */
  assign n3133 = n3126 ? n3129 : n3132;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:180:5 */
  assign n3135 = n3124 ? n3133 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:196:16 */
  assign n3138 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:196:5 */
  assign n3148 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 1'b0, 16'b0000000000000000, 32'b00000000000000000000000000000000, 4'b0000};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:220:24 */
  assign n3157 = exec[10:6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:220:73 */
  assign n3159 = {n3157, 2'b11};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:221:24 */
  assign n3160 = exec[35:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:222:24 */
  assign n3161 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:233:31 */
  assign n3162 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3164 = n3163[261:179]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:234:31 */
  assign n3166 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:235:31 */
  assign n3169 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:70 */
  assign n3172 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3178 = {n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172, n3172};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:89 */
  assign n3180 = exec[34:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:80 */
  assign n3181 = {n3178, n3180};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:113 */
  assign n3182 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:104 */
  assign n3183 = {n3181, n3182};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:239:7 */
  assign n3185 = n3159 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:70 */
  assign n3187 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3193 = {n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187, n3187};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:89 */
  assign n3195 = exec[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:80 */
  assign n3196 = {n3193, n3195};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:102 */
  assign n3197 = exec[34:29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:93 */
  assign n3198 = {n3196, n3197};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:126 */
  assign n3199 = exec[15:12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:117 */
  assign n3200 = {n3198, n3199};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:140 */
  assign n3202 = {n3200, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:240:7 */
  assign n3204 = n3159 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:72 */
  assign n3205 = exec[35:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:87 */
  assign n3207 = {n3205, 12'b000000000000};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:7 */
  assign n3209 = n3159 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:25 */
  assign n3211 = n3159 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:241:25 */
  assign n3212 = n3209 | n3211;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:70 */
  assign n3214 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3220 = {n3214, n3214, n3214, n3214, n3214, n3214, n3214, n3214, n3214, n3214, n3214, n3214};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:89 */
  assign n3222 = exec[23:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:80 */
  assign n3223 = {n3220, n3222};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:113 */
  assign n3224 = exec[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:104 */
  assign n3225 = {n3223, n3224};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:127 */
  assign n3226 = exec[34:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:118 */
  assign n3227 = {n3225, n3226};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:142 */
  assign n3229 = {n3227, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:242:7 */
  assign n3231 = n3159 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:243:7 */
  assign n3234 = n3159 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:70 */
  assign n3236 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1262:10 */
  assign n3242 = {n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236, n3236};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:89 */
  assign n3244 = exec[34:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:80 */
  assign n3245 = {n3242, n3244};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:113 */
  assign n3246 = exec[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:244:104 */
  assign n3247 = {n3245, n3246};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:238:5 */
  assign n3248 = {n3234, n3231, n3212, n3204, n3185};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:238:5 */
  always @*
    case (n3248)
      5'b10000: n3249 = 32'b00000000000000000000000000000000;
      5'b01000: n3249 = n3229;
      5'b00100: n3249 = n3207;
      5'b00010: n3249 = n3202;
      5'b00001: n3249 = n3183;
      default: n3249 = n3247;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:248:17 */
  assign n3252 = n3159[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:249:40 */
  assign n3253 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:251:40 */
  assign n3254 = exec[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:248:5 */
  assign n3255 = n3252 ? n3253 : n3254;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:18 */
  assign n3258 = n3159 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:49 */
  assign n3260 = n3159 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:36 */
  assign n3261 = n3258 | n3260;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:78 */
  assign n3263 = n3159 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:65 */
  assign n3264 = n3261 | n3263;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3266 = n3163[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:255:5 */
  assign n3267 = n3264 ? 1'b1 : n3266;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3268 = n3163[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:258:18 */
  assign n3271 = n3159 != 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:258:5 */
  assign n3273 = n3271 ? 1'b1 : n3268;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:15 */
  assign n3274 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:265:7 */
  assign n3279 = n3274 == 4'b0000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:40 */
  assign n3282 = n3120[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:24 */
  assign n3284 = n3282 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:276:9 */
  assign n3287 = n3284 ? 32'b00000000000000000000000000000010 : 32'b00000000000000000000000000000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:29 */
  assign n3288 = env_pend | exc_fire;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:27 */
  assign n3290 = n3120[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:54 */
  assign n3291 = ~hwtrig_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:40 */
  assign n3292 = n3291 & n3290;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:285:35 */
  assign n3293 = n3120[50]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:286:40 */
  assign n3294 = n3120[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:287:40 */
  assign n3295 = n3120[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:288:40 */
  assign n3296 = n3120[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:289:37 */
  assign n3297 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:289:51 */
  assign n3299 = {n3297, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:291:29 */
  assign n3301 = n3120[7:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:291:78 */
  assign n3303 = n3301 == 5'b11100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:292:48 */
  assign n3304 = n3120[32:21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3305 = n3309 ? n3304 : n3162;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3306 = {n3299, n3294, n3296, n3295, 4'b0100};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3307 = exec[84:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3308 = n3292 ? n3306 : n3307;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3309 = n3303 & n3292;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3311 = n3292 ? n3293 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3312 = n3308[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3313 = n3288 ? 4'b0010 : n3312;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:284:9 */
  assign n3314 = n3308[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3315 = exec[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3316 = n3288 ? n3315 : n3314;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3317 = n3288 ? n3162 : n3305;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:282:9 */
  assign n3319 = n3288 ? 1'b0 : n3311;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:271:7 */
  assign n3321 = n3274 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:25 */
  assign n3324 = csr[63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:47 */
  assign n3325 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:36 */
  assign n3326 = n3325 & n3324;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:36 */
  assign n3327 = csr[94:70]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:58 */
  assign n3328 = ecause[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:50 */
  assign n3329 = {n3327, n3328};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:303:71 */
  assign n3331 = {n3329, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:305:36 */
  assign n3332 = csr[94:65]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:305:50 */
  assign n3334 = {n3332, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:302:9 */
  assign n3335 = n3326 ? n3331 : n3334;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:296:7 */
  assign n3338 = n3274 == 4'b0010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:315:35 */
  assign n3340 = csr[56:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:315:49 */
  assign n3342 = {n3340, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:310:7 */
  assign n3345 = n3274 == 4'b0011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:322:34 */
  assign n3346 = alu_add_i[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:322:48 */
  assign n3348 = {n3346, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:330:15 */
  assign n3351 = n3161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:331:15 */
  assign n3354 = n3161 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:332:15 */
  assign n3356 = n3161 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:333:15 */
  assign n3359 = n3161 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:334:15 */
  assign n3362 = n3161 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:335:15 */
  assign n3365 = n3161 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:329:13 */
  assign n3367 = {n3365, n3362, n3359, n3356, n3354, n3351};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:329:13 */
  always @*
    case (n3367)
      6'b100000: n3368 = 3'b111;
      6'b010000: n3368 = 3'b110;
      6'b001000: n3368 = 3'b101;
      6'b000100: n3368 = 3'b011;
      6'b000010: n3368 = 3'b011;
      6'b000001: n3368 = 3'b001;
      default: n3368 = 3'b000;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:25 */
  assign n3369 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:38 */
  assign n3371 = n3369 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:27 */
  assign n3373 = n3161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:57 */
  assign n3374 = n3159[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:44 */
  assign n3375 = n3374 & n3373;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:80 */
  assign n3376 = exec[34]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:341:68 */
  assign n3377 = n3376 & n3375;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:66 */
  assign n3378 = n3371 | n3377;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3380 = n3163[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:340:13 */
  assign n3381 = n3378 ? 1'b1 : n3380;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:26 */
  assign n3382 = n3159[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:30 */
  assign n3383 = ~n3382;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:51 */
  assign n3385 = n3161 != 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:37 */
  assign n3386 = n3385 & n3383;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:82 */
  assign n3388 = n3161 != 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:68 */
  assign n3389 = n3388 & n3386;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:26 */
  assign n3390 = n3159[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:53 */
  assign n3392 = n3161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:84 */
  assign n3394 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:70 */
  assign n3395 = n3394 & n3392;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:112 */
  assign n3397 = n3161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:143 */
  assign n3399 = n3160 == 7'b0100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:129 */
  assign n3400 = n3399 & n3397;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:98 */
  assign n3401 = n3395 | n3400;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:53 */
  assign n3403 = n3161 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:84 */
  assign n3405 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:70 */
  assign n3406 = n3405 & n3403;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:157 */
  assign n3407 = n3401 | n3406;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:112 */
  assign n3409 = n3161 == 3'b011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:143 */
  assign n3411 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:129 */
  assign n3412 = n3411 & n3409;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:98 */
  assign n3413 = n3407 | n3412;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:53 */
  assign n3415 = n3161 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:84 */
  assign n3417 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:70 */
  assign n3418 = n3417 & n3415;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:348:157 */
  assign n3419 = n3413 | n3418;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:112 */
  assign n3421 = n3161 == 3'b110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:143 */
  assign n3423 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:129 */
  assign n3424 = n3423 & n3421;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:98 */
  assign n3425 = n3419 | n3424;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:53 */
  assign n3427 = n3161 == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:84 */
  assign n3429 = n3160 == 7'b0000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:350:70 */
  assign n3430 = n3429 & n3427;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:349:157 */
  assign n3431 = n3425 | n3430;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:347:37 */
  assign n3432 = n3431 & n3390;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:99 */
  assign n3433 = n3389 | n3432;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3438 = n3433 ? 4'b0001 : 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3439 = n3163[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3440 = n3433 ? 1'b1 : n3439;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3441 = n3163[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:346:13 */
  assign n3442 = n3433 ? n3441 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:11 */
  assign n3444 = n3159 == 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:29 */
  assign n3446 = n3159 == 7'b0010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:326:29 */
  assign n3447 = n3444 | n3446;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:359:11 */
  assign n3452 = n3159 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:365:11 */
  assign n3456 = n3159 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:379:45 */
  assign n3457 = exec[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:379:34 */
  assign n3458 = ~n3457;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:380:41 */
  assign n3459 = exec[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:11 */
  assign n3462 = n3159 == 7'b0000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:30 */
  assign n3464 = n3159 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:30 */
  assign n3465 = n3462 | n3464;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:47 */
  assign n3467 = n3159 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:371:47 */
  assign n3468 = n3465 | n3467;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:11 */
  assign n3471 = n3159 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:32 */
  assign n3473 = n3159 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:32 */
  assign n3474 = n3471 | n3473;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:47 */
  assign n3476 = n3159 == 7'b1100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:385:47 */
  assign n3477 = n3474 | n3476;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:24 */
  assign n3478 = exec[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3488 = exec[35]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3490 = 1'b0 | n3488;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3492 = exec[34]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3493 = n3490 | n3492;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3494 = exec[33]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3495 = n3493 | n3494;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3496 = exec[32]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3497 = n3495 | n3496;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3498 = exec[31]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3499 = n3497 | n3498;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3500 = exec[30]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3501 = n3499 | n3500;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3502 = exec[29]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3503 = n3501 | n3502;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3504 = exec[28]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3505 = n3503 | n3504;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3507 = n3478 ? 4'b0000 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3508 = n3163[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3509 = n3478 ? 1'b1 : n3508;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3510 = n3163[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:390:13 */
  assign n3511 = n3478 ? n3510 : n3505;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:389:11 */
  assign n3513 = n3159 == 7'b0001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:399:11 */
  assign n3517 = n3159 == 7'b1010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:11 */
  assign n3521 = n3159 == 7'b0001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:31 */
  assign n3523 = n3159 == 7'b0101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:31 */
  assign n3524 = n3521 | n3523;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:48 */
  assign n3526 = n3159 == 7'b0111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:48 */
  assign n3527 = n3524 | n3526;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:64 */
  assign n3529 = n3159 == 7'b0011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:404:64 */
  assign n3530 = n3527 | n3529;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:26 */
  assign n3532 = n3161 != 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:57 */
  assign n3534 = n3161 != 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:43 */
  assign n3535 = n3534 & n3532;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3537 = n3163[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:410:13 */
  assign n3538 = n3535 ? 1'b1 : n3537;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  assign n3540 = {n3530, n3517, n3513, n3477, n3468, n3456, n3452, n3447};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3541 = 4'b0101;
      8'b01000000: n3541 = 4'b0101;
      8'b00100000: n3541 = n3507;
      8'b00010000: n3541 = 4'b0110;
      8'b00001000: n3541 = 4'b0111;
      8'b00000100: n3541 = 4'b0001;
      8'b00000010: n3541 = 4'b0001;
      8'b00000001: n3541 = n3438;
      default: n3541 = 4'b1001;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3542 = n3163[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3543 = n3542;
      8'b01000000: n3543 = n3542;
      8'b00100000: n3543 = n3509;
      8'b00010000: n3543 = n3542;
      8'b00001000: n3543 = n3542;
      8'b00000100: n3543 = n3542;
      8'b00000010: n3543 = n3542;
      8'b00000001: n3543 = n3542;
      default: n3543 = n3542;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3544 = n3163[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3545 = n3544;
      8'b01000000: n3545 = n3544;
      8'b00100000: n3545 = n3544;
      8'b00010000: n3545 = n3544;
      8'b00001000: n3545 = n3544;
      8'b00000100: n3545 = 1'b1;
      8'b00000010: n3545 = 1'b1;
      8'b00000001: n3545 = n3440;
      default: n3545 = n3544;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3546 = n3163[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3547 = n3546;
      8'b01000000: n3547 = n3546;
      8'b00100000: n3547 = n3546;
      8'b00010000: n3547 = n3546;
      8'b00001000: n3547 = n3546;
      8'b00000100: n3547 = 3'b001;
      8'b00000010: n3547 = 3'b100;
      8'b00000001: n3547 = n3368;
      default: n3547 = n3546;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3548 = n3163[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3549 = n3548;
      8'b01000000: n3549 = n3548;
      8'b00100000: n3549 = n3548;
      8'b00010000: n3549 = n3548;
      8'b00001000: n3549 = n3548;
      8'b00000100: n3549 = n3548;
      8'b00000010: n3549 = n3548;
      8'b00000001: n3549 = n3381;
      default: n3549 = n3548;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3550 = n3163[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3551 = n3550;
      8'b01000000: n3551 = n3550;
      8'b00100000: n3551 = n3550;
      8'b00010000: n3551 = n3550;
      8'b00001000: n3551 = n3550;
      8'b00000100: n3551 = n3550;
      8'b00000010: n3551 = n3550;
      8'b00000001: n3551 = n3442;
      default: n3551 = n3550;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3552 = n3163[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3553 = 1'b1;
      8'b01000000: n3553 = n3552;
      8'b00100000: n3553 = n3552;
      8'b00010000: n3553 = n3552;
      8'b00001000: n3553 = n3552;
      8'b00000100: n3553 = n3552;
      8'b00000010: n3553 = n3552;
      8'b00000001: n3553 = n3552;
      default: n3553 = n3552;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3554 = n3163[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3555 = n3554;
      8'b01000000: n3555 = 1'b1;
      8'b00100000: n3555 = n3554;
      8'b00010000: n3555 = n3554;
      8'b00001000: n3555 = n3554;
      8'b00000100: n3555 = n3554;
      8'b00000010: n3555 = n3554;
      8'b00000001: n3555 = n3554;
      default: n3555 = n3554;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3556 = n3166;
      8'b01000000: n3556 = n3166;
      8'b00100000: n3556 = n3166;
      8'b00010000: n3556 = n3166;
      8'b00001000: n3556 = n3458;
      8'b00000100: n3556 = n3166;
      8'b00000010: n3556 = n3166;
      8'b00000001: n3556 = n3166;
      default: n3556 = n3166;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3557 = n3169;
      8'b01000000: n3557 = n3169;
      8'b00100000: n3557 = n3169;
      8'b00010000: n3557 = n3169;
      8'b00001000: n3557 = n3459;
      8'b00000100: n3557 = n3169;
      8'b00000010: n3557 = n3169;
      8'b00000001: n3557 = n3169;
      default: n3557 = n3169;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3558 = n3163[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3559 = n3558;
      8'b01000000: n3559 = n3558;
      8'b00100000: n3559 = n3511;
      8'b00010000: n3559 = n3558;
      8'b00001000: n3559 = n3558;
      8'b00000100: n3559 = n3558;
      8'b00000010: n3559 = n3558;
      8'b00000001: n3559 = n3558;
      default: n3559 = n3558;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3560 = n3163[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:323:9 */
  always @*
    case (n3540)
      8'b10000000: n3561 = n3560;
      8'b01000000: n3561 = n3560;
      8'b00100000: n3561 = n3560;
      8'b00010000: n3561 = n3560;
      8'b00001000: n3561 = n3560;
      8'b00000100: n3561 = n3560;
      8'b00000010: n3561 = n3560;
      8'b00000001: n3561 = n3560;
      default: n3561 = n3538;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:320:7 */
  assign n3563 = n3274 == 4'b0100;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3572 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3574 = 1'b0 | n3572;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3576 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3577 = n3574 | n3576;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3578 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3579 = n3577 | n3578;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:421:34 */
  assign n3580 = alu_cp_done_i | n3579;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3582 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:421:9 */
  assign n3583 = n3580 ? 4'b0001 : n3582;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:417:7 */
  assign n3585 = n3274 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:427:29 */
  assign n3587 = 1'b0 | branch_taken;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3589 = n3163[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:427:9 */
  assign n3590 = n3587 ? 1'b1 : n3589;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:431:36 */
  assign n3591 = alu_add_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:431:40 */
  assign n3594 = n3591 & 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:432:36 */
  assign n3595 = alu_add_i[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:432:50 */
  assign n3597 = {n3595, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3598 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:430:9 */
  assign n3599 = branch_taken ? n3597 : n3598;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:430:9 */
  assign n3601 = branch_taken ? n3594 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:434:38 */
  assign n3602 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:434:52 */
  assign n3604 = {n3602, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:435:37 */
  assign n3605 = exec[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:425:7 */
  assign n3608 = n3274 == 4'b0110;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3616 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3618 = 1'b0 | n3616;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3620 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3621 = n3618 | n3620;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3622 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3623 = n3621 | n3622;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:69 */
  assign n3624 = ~n3623;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:9 */
  assign n3628 = n3624 ? 4'b1000 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3629 = n3163[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:440:9 */
  assign n3630 = n3624 ? 1'b1 : n3629;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:438:7 */
  assign n3632 = n3274 == 4'b0111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:24 */
  assign n3633 = ~lsu_wait_i;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3641 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3643 = 1'b0 | n3641;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3645 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3646 = n3643 | n3645;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3647 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3648 = n3646 | n3647;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3649 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3650 = n3648 | n3649;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:31 */
  assign n3651 = n3633 | n3650;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:450:37 */
  assign n3652 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3654 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:9 */
  assign n3655 = n3651 ? 4'b0001 : n3654;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3656 = n3163[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:449:9 */
  assign n3657 = n3651 ? n3652 : n3656;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:447:7 */
  assign n3659 = n3274 == 4'b1000;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3668 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3670 = 1'b0 | n3668;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3672 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3673 = n3670 | n3672;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3674 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3675 = n3673 | n3674;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:69 */
  assign n3676 = ~n3675;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:24 */
  assign n3678 = n3161 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:25 */
  assign n3679 = exec[26:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:460:15 */
  assign n3681 = n3679 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:461:15 */
  assign n3683 = n3679 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:462:15 */
  assign n3686 = n3679 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:463:15 */
  assign n3689 = n3679 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  assign n3691 = {n3689, n3686, n3683, n3681};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3691)
      4'b1000: n3692 = 4'b1010;
      4'b0100: n3692 = 4'b0011;
      4'b0010: n3692 = 4'b0001;
      4'b0001: n3692 = 4'b0001;
      default: n3692 = 4'b0001;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3691)
      4'b1000: n3695 = 1'b0;
      4'b0100: n3695 = 1'b0;
      4'b0010: n3695 = 1'b0;
      4'b0001: n3695 = 1'b1;
      default: n3695 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:459:13 */
  always @*
    case (n3691)
      4'b1000: n3698 = 1'b0;
      4'b0100: n3698 = 1'b0;
      4'b0010: n3698 = 1'b1;
      4'b0001: n3698 = 1'b0;
      default: n3698 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:27 */
  assign n3700 = n3161 != 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:28 */
  assign n3702 = n3161 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:59 */
  assign n3704 = n3161 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:46 */
  assign n3705 = n3702 | n3704;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:89 */
  assign n3706 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:130 */
  assign n3708 = n3706 != 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:467:78 */
  assign n3709 = n3705 | n3708;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:46 */
  assign n3710 = n3709 & n3700;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3712 = n3163[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:466:11 */
  assign n3713 = n3710 ? 1'b1 : n3712;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3714 = n3721 ? n3692 : 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3715 = n3163[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3716 = n3678 ? n3715 : n3713;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3718 = n3678 ? n3695 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:458:11 */
  assign n3720 = n3678 ? n3698 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3721 = n3678 & n3676;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3722 = n3163[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3723 = n3676 ? n3716 : n3722;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3725 = n3676 ? n3718 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:457:9 */
  assign n3727 = n3676 ? n3720 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:454:7 */
  assign n3730 = n3274 == 4'b1001;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3737 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3739 = 1'b0 | n3737;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3741 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3742 = n3739 | n3741;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3743 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3744 = n3742 | n3743;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3745 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3746 = n3744 | n3745;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3747 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3748 = n3746 | n3747;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3749 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3750 = n3748 | n3749;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3751 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3752 = n3750 | n3751;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3753 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3754 = n3752 | n3753;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3755 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3756 = n3754 | n3755;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3757 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3758 = n3756 | n3757;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3759 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3760 = n3758 | n3759;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3761 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3762 = n3760 | n3761;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3763 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3764 = n3762 | n3763;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3765 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3766 = n3764 | n3765;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3767 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3768 = n3766 | n3767;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3769 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3770 = n3768 | n3769;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3771 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3772 = n3770 | n3771;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3773 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3774 = n3772 | n3773;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3775 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3776 = n3774 | n3775;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3777 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3778 = n3776 | n3777;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:476:41 */
  assign n3779 = n3778 | exc_fire;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3781 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:476:9 */
  assign n3782 = n3779 ? 4'b0001 : n3781;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  assign n3783 = {n3730, n3659, n3632, n3608, n3585, n3563, n3345, n3338, n3321, n3279};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3784 = n3714;
      10'b0100000000: n3784 = n3655;
      10'b0010000000: n3784 = n3628;
      10'b0001000000: n3784 = 4'b0001;
      10'b0000100000: n3784 = n3583;
      10'b0000010000: n3784 = n3541;
      10'b0000001000: n3784 = 4'b0000;
      10'b0000000100: n3784 = 4'b0000;
      10'b0000000010: n3784 = n3313;
      10'b0000000001: n3784 = 4'b0001;
      default: n3784 = n3782;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3785 = exec[84:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3786 = n3785;
      10'b0100000000: n3786 = n3785;
      10'b0010000000: n3786 = n3785;
      10'b0001000000: n3786 = n3785;
      10'b0000100000: n3786 = n3785;
      10'b0000010000: n3786 = n3785;
      10'b0000001000: n3786 = n3785;
      10'b0000000100: n3786 = n3785;
      10'b0000000010: n3786 = n3316;
      10'b0000000001: n3786 = n3785;
      default: n3786 = n3785;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n3787 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3788 = n3787;
      10'b0100000000: n3788 = n3787;
      10'b0010000000: n3788 = n3787;
      10'b0001000000: n3788 = n3599;
      10'b0000100000: n3788 = n3787;
      10'b0000010000: n3788 = n3348;
      10'b0000001000: n3788 = n3342;
      10'b0000000100: n3788 = n3335;
      10'b0000000010: n3788 = n3787;
      10'b0000000001: n3788 = n3787;
      default: n3788 = n3787;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3791 = n3163[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3792 = n3791;
      10'b0100000000: n3792 = n3791;
      10'b0010000000: n3792 = n3791;
      10'b0001000000: n3792 = n3590;
      10'b0000100000: n3792 = n3791;
      10'b0000010000: n3792 = n3791;
      10'b0000001000: n3792 = n3791;
      10'b0000000100: n3792 = n3791;
      10'b0000000010: n3792 = n3791;
      10'b0000000001: n3792 = 1'b1;
      default: n3792 = n3791;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3793 = n3163[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3794 = n3793;
      10'b0100000000: n3794 = n3793;
      10'b0010000000: n3794 = n3793;
      10'b0001000000: n3794 = n3793;
      10'b0000100000: n3794 = n3793;
      10'b0000010000: n3794 = n3543;
      10'b0000001000: n3794 = n3793;
      10'b0000000100: n3794 = n3793;
      10'b0000000010: n3794 = n3793;
      10'b0000000001: n3794 = n3793;
      default: n3794 = n3793;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3795 = n3163[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3796 = n3795;
      10'b0100000000: n3796 = n3795;
      10'b0010000000: n3796 = n3795;
      10'b0001000000: n3796 = n3604;
      10'b0000100000: n3796 = n3795;
      10'b0000010000: n3796 = n3795;
      10'b0000001000: n3796 = n3795;
      10'b0000000100: n3796 = n3795;
      10'b0000000010: n3796 = n3795;
      10'b0000000001: n3796 = n3795;
      default: n3796 = n3795;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3797 = n3163[99]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3798 = 1'b1;
      10'b0100000000: n3798 = n3657;
      10'b0010000000: n3798 = n3797;
      10'b0001000000: n3798 = n3605;
      10'b0000100000: n3798 = alu_cp_done_i;
      10'b0000010000: n3798 = n3545;
      10'b0000001000: n3798 = n3797;
      10'b0000000100: n3798 = n3797;
      10'b0000000010: n3798 = n3797;
      10'b0000000001: n3798 = n3797;
      default: n3798 = n3797;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3799 = n3163[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3800 = n3799;
      10'b0100000000: n3800 = n3799;
      10'b0010000000: n3800 = n3799;
      10'b0001000000: n3800 = n3799;
      10'b0000100000: n3800 = n3799;
      10'b0000010000: n3800 = n3799;
      10'b0000001000: n3800 = n3799;
      10'b0000000100: n3800 = n3799;
      10'b0000000010: n3800 = n3799;
      10'b0000000001: n3800 = 1'b1;
      default: n3800 = n3799;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3801 = n3163[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3802 = n3801;
      10'b0100000000: n3802 = n3801;
      10'b0010000000: n3802 = n3801;
      10'b0001000000: n3802 = n3801;
      10'b0000100000: n3802 = 3'b010;
      10'b0000010000: n3802 = n3547;
      10'b0000001000: n3802 = n3801;
      10'b0000000100: n3802 = n3801;
      10'b0000000010: n3802 = n3801;
      10'b0000000001: n3802 = n3801;
      default: n3802 = n3801;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3803 = n3163[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3804 = n3803;
      10'b0100000000: n3804 = n3803;
      10'b0010000000: n3804 = n3803;
      10'b0001000000: n3804 = n3803;
      10'b0000100000: n3804 = n3803;
      10'b0000010000: n3804 = n3549;
      10'b0000001000: n3804 = n3803;
      10'b0000000100: n3804 = n3803;
      10'b0000000010: n3804 = n3803;
      10'b0000000001: n3804 = n3803;
      default: n3804 = n3803;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3805 = n3267;
      10'b0100000000: n3805 = n3267;
      10'b0010000000: n3805 = n3267;
      10'b0001000000: n3805 = n3267;
      10'b0000100000: n3805 = n3267;
      10'b0000010000: n3805 = n3267;
      10'b0000001000: n3805 = n3267;
      10'b0000000100: n3805 = n3267;
      10'b0000000010: n3805 = 1'b1;
      10'b0000000001: n3805 = n3267;
      default: n3805 = n3267;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3806 = n3273;
      10'b0100000000: n3806 = n3273;
      10'b0010000000: n3806 = n3273;
      10'b0001000000: n3806 = n3273;
      10'b0000100000: n3806 = n3273;
      10'b0000010000: n3806 = n3273;
      10'b0000001000: n3806 = n3273;
      10'b0000000100: n3806 = n3273;
      10'b0000000010: n3806 = 1'b1;
      10'b0000000001: n3806 = n3273;
      default: n3806 = n3273;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3807 = n3249;
      10'b0100000000: n3807 = n3249;
      10'b0010000000: n3807 = n3249;
      10'b0001000000: n3807 = n3249;
      10'b0000100000: n3807 = n3249;
      10'b0000010000: n3807 = n3249;
      10'b0000001000: n3807 = n3249;
      10'b0000000100: n3807 = n3249;
      10'b0000000010: n3807 = n3287;
      10'b0000000001: n3807 = n3249;
      default: n3807 = n3249;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3808 = n3163[155]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3809 = n3808;
      10'b0100000000: n3809 = n3808;
      10'b0010000000: n3809 = n3808;
      10'b0001000000: n3809 = n3808;
      10'b0000100000: n3809 = n3808;
      10'b0000010000: n3809 = n3551;
      10'b0000001000: n3809 = n3808;
      10'b0000000100: n3809 = n3808;
      10'b0000000010: n3809 = n3808;
      10'b0000000001: n3809 = n3808;
      default: n3809 = n3808;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3810 = n3163[156]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3811 = n3810;
      10'b0100000000: n3811 = n3810;
      10'b0010000000: n3811 = n3810;
      10'b0001000000: n3811 = n3810;
      10'b0000100000: n3811 = n3810;
      10'b0000010000: n3811 = n3553;
      10'b0000001000: n3811 = n3810;
      10'b0000000100: n3811 = n3810;
      10'b0000000010: n3811 = n3810;
      10'b0000000001: n3811 = n3810;
      default: n3811 = n3810;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3812 = n3163[157]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3813 = n3812;
      10'b0100000000: n3813 = n3812;
      10'b0010000000: n3813 = n3812;
      10'b0001000000: n3813 = n3812;
      10'b0000100000: n3813 = n3812;
      10'b0000010000: n3813 = n3555;
      10'b0000001000: n3813 = n3812;
      10'b0000000100: n3813 = n3812;
      10'b0000000010: n3813 = n3812;
      10'b0000000001: n3813 = n3812;
      default: n3813 = n3812;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3814 = n3163[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3815 = n3814;
      10'b0100000000: n3815 = n3814;
      10'b0010000000: n3815 = n3630;
      10'b0001000000: n3815 = n3814;
      10'b0000100000: n3815 = n3814;
      10'b0000010000: n3815 = n3814;
      10'b0000001000: n3815 = n3814;
      10'b0000000100: n3815 = n3814;
      10'b0000000010: n3815 = n3814;
      10'b0000000001: n3815 = n3814;
      default: n3815 = n3814;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3816 = n3166;
      10'b0100000000: n3816 = n3166;
      10'b0010000000: n3816 = n3166;
      10'b0001000000: n3816 = n3166;
      10'b0000100000: n3816 = n3166;
      10'b0000010000: n3816 = n3556;
      10'b0000001000: n3816 = n3166;
      10'b0000000100: n3816 = n3166;
      10'b0000000010: n3816 = n3166;
      10'b0000000001: n3816 = n3166;
      default: n3816 = n3166;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3817 = n3169;
      10'b0100000000: n3817 = n3169;
      10'b0010000000: n3817 = n3169;
      10'b0001000000: n3817 = n3169;
      10'b0000100000: n3817 = n3169;
      10'b0000010000: n3817 = n3557;
      10'b0000001000: n3817 = n3169;
      10'b0000000100: n3817 = n3169;
      10'b0000000010: n3817 = n3169;
      10'b0000000001: n3817 = n3169;
      default: n3817 = n3169;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3818 = n3163[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3819 = n3818;
      10'b0100000000: n3819 = n3818;
      10'b0010000000: n3819 = n3818;
      10'b0001000000: n3819 = n3818;
      10'b0000100000: n3819 = n3818;
      10'b0000010000: n3819 = n3559;
      10'b0000001000: n3819 = n3818;
      10'b0000000100: n3819 = n3818;
      10'b0000000010: n3819 = n3818;
      10'b0000000001: n3819 = n3818;
      default: n3819 = n3818;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3820 = n3163[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3821 = n3723;
      10'b0100000000: n3821 = n3820;
      10'b0010000000: n3821 = n3820;
      10'b0001000000: n3821 = n3820;
      10'b0000100000: n3821 = n3820;
      10'b0000010000: n3821 = n3820;
      10'b0000001000: n3821 = n3820;
      10'b0000000100: n3821 = n3820;
      10'b0000000010: n3821 = n3820;
      10'b0000000001: n3821 = n3820;
      default: n3821 = n3820;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3822 = n3163[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3823 = n3822;
      10'b0100000000: n3823 = n3822;
      10'b0010000000: n3823 = n3822;
      10'b0001000000: n3823 = n3822;
      10'b0000100000: n3823 = n3822;
      10'b0000010000: n3823 = n3561;
      10'b0000001000: n3823 = n3822;
      10'b0000000100: n3823 = n3822;
      10'b0000000010: n3823 = n3822;
      10'b0000000001: n3823 = n3822;
      default: n3823 = n3822;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3824 = n3162;
      10'b0100000000: n3824 = n3162;
      10'b0010000000: n3824 = n3162;
      10'b0001000000: n3824 = n3162;
      10'b0000100000: n3824 = n3162;
      10'b0000010000: n3824 = n3162;
      10'b0000001000: n3824 = n3162;
      10'b0000000100: n3824 = n3162;
      10'b0000000010: n3824 = n3317;
      10'b0000000001: n3824 = n3162;
      default: n3824 = n3162;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3827 = n3163[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3829 = n3163[66:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3832 = n3163[114:100]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n3838 = n3163[163:161]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3842 = 1'b0;
      10'b0100000000: n3842 = 1'b0;
      10'b0010000000: n3842 = 1'b0;
      10'b0001000000: n3842 = 1'b0;
      10'b0000100000: n3842 = 1'b0;
      10'b0000010000: n3842 = 1'b0;
      10'b0000001000: n3842 = 1'b0;
      10'b0000000100: n3842 = 1'b1;
      10'b0000000010: n3842 = 1'b0;
      10'b0000000001: n3842 = 1'b0;
      default: n3842 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3846 = 1'b0;
      10'b0100000000: n3846 = 1'b0;
      10'b0010000000: n3846 = 1'b0;
      10'b0001000000: n3846 = 1'b0;
      10'b0000100000: n3846 = 1'b0;
      10'b0000010000: n3846 = 1'b0;
      10'b0000001000: n3846 = 1'b1;
      10'b0000000100: n3846 = 1'b0;
      10'b0000000010: n3846 = 1'b0;
      10'b0000000001: n3846 = 1'b0;
      default: n3846 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3849 = 1'b0;
      10'b0100000000: n3849 = 1'b0;
      10'b0010000000: n3849 = 1'b0;
      10'b0001000000: n3849 = 1'b0;
      10'b0000100000: n3849 = 1'b0;
      10'b0000010000: n3849 = 1'b0;
      10'b0000001000: n3849 = 1'b0;
      10'b0000000100: n3849 = 1'b0;
      10'b0000000010: n3849 = n3319;
      10'b0000000001: n3849 = 1'b0;
      default: n3849 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3852 = 1'b0;
      10'b0100000000: n3852 = 1'b0;
      10'b0010000000: n3852 = 1'b0;
      10'b0001000000: n3852 = n3601;
      10'b0000100000: n3852 = 1'b0;
      10'b0000010000: n3852 = 1'b0;
      10'b0000001000: n3852 = 1'b0;
      10'b0000000100: n3852 = 1'b0;
      10'b0000000010: n3852 = 1'b0;
      10'b0000000001: n3852 = 1'b0;
      default: n3852 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3855 = n3725;
      10'b0100000000: n3855 = 1'b0;
      10'b0010000000: n3855 = 1'b0;
      10'b0001000000: n3855 = 1'b0;
      10'b0000100000: n3855 = 1'b0;
      10'b0000010000: n3855 = 1'b0;
      10'b0000001000: n3855 = 1'b0;
      10'b0000000100: n3855 = 1'b0;
      10'b0000000010: n3855 = 1'b0;
      10'b0000000001: n3855 = 1'b0;
      default: n3855 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:263:5 */
  always @*
    case (n3783)
      10'b1000000000: n3858 = n3727;
      10'b0100000000: n3858 = 1'b0;
      10'b0010000000: n3858 = 1'b0;
      10'b0001000000: n3858 = 1'b0;
      10'b0000100000: n3858 = 1'b0;
      10'b0000010000: n3858 = 1'b0;
      10'b0000001000: n3858 = 1'b0;
      10'b0000000100: n3858 = 1'b0;
      10'b0000000010: n3858 = 1'b0;
      10'b0000000001: n3858 = 1'b0;
      default: n3858 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:487:35 */
  assign n3861 = ctrl_nxt[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:41 */
  assign n3863 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:47 */
  assign n3865 = n3863 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:488:30 */
  assign n3866 = n3865 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:489:31 */
  assign n3868 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:491:33 */
  assign n3869 = exec[84:54]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:491:47 */
  assign n3871 = {n3869, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:492:34 */
  assign n3872 = exec[116:86]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:492:48 */
  assign n3874 = {n3872, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:493:37 */
  assign n3875 = ctrl[98:68]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:493:51 */
  assign n3877 = {n3875, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:31 */
  assign n3878 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3886 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3888 = 1'b0 | n3886;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3890 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3891 = n3888 | n3890;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3892 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3893 = n3891 | n3892;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3894 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3895 = n3893 | n3894;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3896 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3897 = n3895 | n3896;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3898 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3899 = n3897 | n3898;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3900 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3901 = n3899 | n3900;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3902 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3903 = n3901 | n3902;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3904 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3905 = n3903 | n3904;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:45 */
  assign n3906 = ~n3905;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:495:40 */
  assign n3907 = n3878 & n3906;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:496:33 */
  assign n3908 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:497:33 */
  assign n3909 = exec[28:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:498:33 */
  assign n3910 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:499:31 */
  assign n3911 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:501:31 */
  assign n3912 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:502:31 */
  assign n3913 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:503:31 */
  assign n3914 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:504:31 */
  assign n3915 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:505:31 */
  assign n3916 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:506:31 */
  assign n3917 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:31 */
  assign n3918 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3926 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3928 = 1'b0 | n3926;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3930 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3931 = n3928 | n3930;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3932 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3933 = n3931 | n3932;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:47 */
  assign n3934 = ~n3933;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:507:42 */
  assign n3935 = n3918 & n3934;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:31 */
  assign n3936 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3944 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3946 = 1'b0 | n3944;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3948 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3949 = n3946 | n3948;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3950 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3951 = n3949 | n3950;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:47 */
  assign n3952 = ~n3951;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:508:42 */
  assign n3953 = n3936 & n3952;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:31 */
  assign n3954 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3962 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3964 = 1'b0 | n3962;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3966 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3967 = n3964 | n3966;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n3968 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n3969 = n3967 | n3968;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:47 */
  assign n3970 = ~n3969;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:509:42 */
  assign n3971 = n3954 & n3970;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:511:31 */
  assign n3972 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:512:31 */
  assign n3973 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:513:31 */
  assign n3974 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:41 */
  assign n3976 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:47 */
  assign n3978 = n3976 == 4'b0111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:514:30 */
  assign n3979 = n3978 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:41 */
  assign n3982 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:47 */
  assign n3984 = n3982 == 4'b1000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:515:30 */
  assign n3985 = n3984 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:30 */
  assign n3987 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:52 */
  assign n3988 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:42 */
  assign n3989 = n3988 ? n3987 : n3990;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:516:81 */
  assign n3990 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:517:31 */
  assign n3991 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:519:31 */
  assign n3992 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:520:31 */
  assign n3993 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:521:31 */
  assign n3994 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:526:33 */
  assign n3995 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:527:33 */
  assign n3996 = exec[35:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:528:33 */
  assign n3997 = exec[10:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:529:31 */
  assign n3998 = exec[51:36]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:531:30 */
  assign n3999 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:534:37 */
  assign n4000 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:53 */
  assign n4002 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:59 */
  assign n4004 = n4002 == 4'b1010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:539:42 */
  assign n4005 = n4004 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:53 */
  assign n4008 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:59 */
  assign n4010 = n4008 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:540:42 */
  assign n4011 = n4010 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:53 */
  assign n4014 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:59 */
  assign n4016 = n4014 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:82 */
  assign n4017 = exec[52]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:72 */
  assign n4018 = n4017 & n4016;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:541:42 */
  assign n4019 = n4018 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:53 */
  assign n4022 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:59 */
  assign n4024 = n4022 == 4'b0001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:89 */
  assign n4025 = n3120[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:95 */
  assign n4026 = ~n4025;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:73 */
  assign n4027 = n4026 & n4024;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:542:42 */
  assign n4028 = n4027 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:53 */
  assign n4031 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:59 */
  assign n4033 = n4031 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:543:42 */
  assign n4034 = n4033 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:53 */
  assign n4037 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:61 */
  assign n4038 = ~n4037;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:78 */
  assign n4039 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:84 */
  assign n4041 = n4039 == 4'b1000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:68 */
  assign n4042 = n4041 & n4038;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:544:42 */
  assign n4043 = n4042 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:53 */
  assign n4046 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:81 */
  assign n4047 = exec[10:6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:94 */
  assign n4049 = n4047 != 5'b00011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:69 */
  assign n4050 = n4049 & n4046;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:545:42 */
  assign n4051 = n4050 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:53 */
  assign n4054 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:78 */
  assign n4055 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:68 */
  assign n4056 = n4055 & n4054;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:546:42 */
  assign n4057 = n4056 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:53 */
  assign n4060 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:78 */
  assign n4061 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:68 */
  assign n4062 = n4061 & n4060;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:547:42 */
  assign n4063 = n4062 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:15 */
  assign n4066 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:7 */
  assign n4070 = n4066 == 12'b000000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:25 */
  assign n4072 = n4066 == 12'b000000000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:25 */
  assign n4073 = n4070 | n4072;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:37 */
  assign n4075 = n4066 == 12'b000000000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:564:37 */
  assign n4076 = n4073 | n4075;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:7 */
  assign n4079 = n4066 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:32 */
  assign n4081 = n4066 == 12'b001100010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:32 */
  assign n4082 = n4079 | n4081;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:50 */
  assign n4084 = n4066 == 12'b001100000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:50 */
  assign n4085 = n4082 | n4084;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:66 */
  assign n4087 = n4066 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:66 */
  assign n4088 = n4085 | n4087;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:81 */
  assign n4090 = n4066 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:81 */
  assign n4091 = n4088 | n4090;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:96 */
  assign n4093 = n4066 == 12'b111100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:96 */
  assign n4094 = n4091 | n4093;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:115 */
  assign n4096 = n4066 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:568:115 */
  assign n4097 = n4094 | n4096;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:32 */
  assign n4099 = n4066 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:32 */
  assign n4100 = n4097 | n4099;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:50 */
  assign n4102 = n4066 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:50 */
  assign n4103 = n4100 | n4102;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:66 */
  assign n4105 = n4066 == 12'b001101000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:66 */
  assign n4106 = n4103 | n4105;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:81 */
  assign n4108 = n4066 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:81 */
  assign n4109 = n4106 | n4108;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:96 */
  assign n4111 = n4066 == 12'b111100010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:96 */
  assign n4112 = n4109 | n4111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:115 */
  assign n4114 = n4066 == 12'b001100100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:569:115 */
  assign n4115 = n4112 | n4114;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:32 */
  assign n4117 = n4066 == 12'b111100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:32 */
  assign n4118 = n4115 | n4117;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:50 */
  assign n4120 = n4066 == 12'b111100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:50 */
  assign n4121 = n4118 | n4120;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:66 */
  assign n4123 = n4066 == 12'b111100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:66 */
  assign n4124 = n4121 | n4123;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:81 */
  assign n4126 = n4066 == 12'b111111000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:81 */
  assign n4127 = n4124 | n4126;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:96 */
  assign n4129 = n4066 == 12'b111111000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:570:96 */
  assign n4130 = n4127 | n4129;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:7 */
  assign n4134 = n4066 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:29 */
  assign n4136 = n4066 == 12'b001100001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:29 */
  assign n4137 = n4134 | n4136;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:45 */
  assign n4139 = n4066 == 12'b001100011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:574:45 */
  assign n4140 = n4137 | n4139;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:7 */
  assign n4144 = n4066 == 12'b001110100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:28 */
  assign n4146 = n4066 == 12'b001110100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:28 */
  assign n4147 = n4144 | n4146;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:46 */
  assign n4149 = n4066 == 12'b001110100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:46 */
  assign n4150 = n4147 | n4149;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:64 */
  assign n4152 = n4066 == 12'b001110100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:64 */
  assign n4153 = n4150 | n4152;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:82 */
  assign n4155 = n4066 == 12'b001110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:578:82 */
  assign n4156 = n4153 | n4155;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:28 */
  assign n4158 = n4066 == 12'b001110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:28 */
  assign n4159 = n4156 | n4158;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:46 */
  assign n4161 = n4066 == 12'b001110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:46 */
  assign n4162 = n4159 | n4161;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:64 */
  assign n4164 = n4066 == 12'b001110110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:64 */
  assign n4165 = n4162 | n4164;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:82 */
  assign n4167 = n4066 == 12'b001110110100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:579:82 */
  assign n4168 = n4165 | n4167;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:28 */
  assign n4170 = n4066 == 12'b001110110101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:28 */
  assign n4171 = n4168 | n4170;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:46 */
  assign n4173 = n4066 == 12'b001110110110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:46 */
  assign n4174 = n4171 | n4173;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:64 */
  assign n4176 = n4066 == 12'b001110110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:64 */
  assign n4177 = n4174 | n4176;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:82 */
  assign n4179 = n4066 == 12'b001110111000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:580:82 */
  assign n4180 = n4177 | n4179;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:28 */
  assign n4182 = n4066 == 12'b001110111001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:28 */
  assign n4183 = n4180 | n4182;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:46 */
  assign n4185 = n4066 == 12'b001110111010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:46 */
  assign n4186 = n4183 | n4185;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:64 */
  assign n4188 = n4066 == 12'b001110111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:64 */
  assign n4189 = n4186 | n4188;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:82 */
  assign n4191 = n4066 == 12'b001110111100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:581:82 */
  assign n4192 = n4189 | n4191;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:28 */
  assign n4194 = n4066 == 12'b001110111101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:28 */
  assign n4195 = n4192 | n4194;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:46 */
  assign n4197 = n4066 == 12'b001110111110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:46 */
  assign n4198 = n4195 | n4197;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:64 */
  assign n4200 = n4066 == 12'b001110111111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:582:64 */
  assign n4201 = n4198 | n4200;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:7 */
  assign n4205 = n4066 == 12'b110000000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:33 */
  assign n4207 = n4066 == 12'b110000000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:33 */
  assign n4208 = n4205 | n4207;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:56 */
  assign n4210 = n4066 == 12'b110000000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:56 */
  assign n4211 = n4208 | n4210;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:79 */
  assign n4213 = n4066 == 12'b110000000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:79 */
  assign n4214 = n4211 | n4213;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:102 */
  assign n4216 = n4066 == 12'b110000000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:585:102 */
  assign n4217 = n4214 | n4216;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:33 */
  assign n4219 = n4066 == 12'b110000001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:33 */
  assign n4220 = n4217 | n4219;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:56 */
  assign n4222 = n4066 == 12'b110000001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:56 */
  assign n4223 = n4220 | n4222;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:79 */
  assign n4225 = n4066 == 12'b110000001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:79 */
  assign n4226 = n4223 | n4225;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:102 */
  assign n4228 = n4066 == 12'b110000001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:586:102 */
  assign n4229 = n4226 | n4228;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:33 */
  assign n4231 = n4066 == 12'b110000001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:33 */
  assign n4232 = n4229 | n4231;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:56 */
  assign n4234 = n4066 == 12'b110000001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:56 */
  assign n4235 = n4232 | n4234;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:79 */
  assign n4237 = n4066 == 12'b110000001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:79 */
  assign n4238 = n4235 | n4237;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:102 */
  assign n4240 = n4066 == 12'b110000001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:587:102 */
  assign n4241 = n4238 | n4240;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:33 */
  assign n4243 = n4066 == 12'b110000010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:33 */
  assign n4244 = n4241 | n4243;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:56 */
  assign n4246 = n4066 == 12'b110000010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:56 */
  assign n4247 = n4244 | n4246;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:79 */
  assign n4249 = n4066 == 12'b110000010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:79 */
  assign n4250 = n4247 | n4249;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:102 */
  assign n4252 = n4066 == 12'b110000010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:588:102 */
  assign n4253 = n4250 | n4252;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:33 */
  assign n4255 = n4066 == 12'b110000010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:33 */
  assign n4256 = n4253 | n4255;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:56 */
  assign n4258 = n4066 == 12'b110000010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:56 */
  assign n4259 = n4256 | n4258;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:79 */
  assign n4261 = n4066 == 12'b110000010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:79 */
  assign n4262 = n4259 | n4261;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:102 */
  assign n4264 = n4066 == 12'b110000010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:589:102 */
  assign n4265 = n4262 | n4264;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:33 */
  assign n4267 = n4066 == 12'b110000011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:33 */
  assign n4268 = n4265 | n4267;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:56 */
  assign n4270 = n4066 == 12'b110000011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:56 */
  assign n4271 = n4268 | n4270;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:79 */
  assign n4273 = n4066 == 12'b110000011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:79 */
  assign n4274 = n4271 | n4273;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:102 */
  assign n4276 = n4066 == 12'b110000011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:590:102 */
  assign n4277 = n4274 | n4276;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:33 */
  assign n4279 = n4066 == 12'b110000011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:33 */
  assign n4280 = n4277 | n4279;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:56 */
  assign n4282 = n4066 == 12'b110000011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:56 */
  assign n4283 = n4280 | n4282;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:79 */
  assign n4285 = n4066 == 12'b110000011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:79 */
  assign n4286 = n4283 | n4285;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:102 */
  assign n4288 = n4066 == 12'b110000011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:591:102 */
  assign n4289 = n4286 | n4288;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:592:33 */
  assign n4291 = n4066 == 12'b110010000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:592:33 */
  assign n4292 = n4289 | n4291;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:33 */
  assign n4294 = n4066 == 12'b110010000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:33 */
  assign n4295 = n4292 | n4294;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:56 */
  assign n4297 = n4066 == 12'b110010000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:56 */
  assign n4298 = n4295 | n4297;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:79 */
  assign n4300 = n4066 == 12'b110010000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:79 */
  assign n4301 = n4298 | n4300;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:102 */
  assign n4303 = n4066 == 12'b110010000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:593:102 */
  assign n4304 = n4301 | n4303;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:33 */
  assign n4306 = n4066 == 12'b110010001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:33 */
  assign n4307 = n4304 | n4306;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:56 */
  assign n4309 = n4066 == 12'b110010001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:56 */
  assign n4310 = n4307 | n4309;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:79 */
  assign n4312 = n4066 == 12'b110010001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:79 */
  assign n4313 = n4310 | n4312;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:102 */
  assign n4315 = n4066 == 12'b110010001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:594:102 */
  assign n4316 = n4313 | n4315;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:33 */
  assign n4318 = n4066 == 12'b110010001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:33 */
  assign n4319 = n4316 | n4318;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:56 */
  assign n4321 = n4066 == 12'b110010001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:56 */
  assign n4322 = n4319 | n4321;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:79 */
  assign n4324 = n4066 == 12'b110010001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:79 */
  assign n4325 = n4322 | n4324;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:102 */
  assign n4327 = n4066 == 12'b110010001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:595:102 */
  assign n4328 = n4325 | n4327;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:33 */
  assign n4330 = n4066 == 12'b110010010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:33 */
  assign n4331 = n4328 | n4330;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:56 */
  assign n4333 = n4066 == 12'b110010010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:56 */
  assign n4334 = n4331 | n4333;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:79 */
  assign n4336 = n4066 == 12'b110010010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:79 */
  assign n4337 = n4334 | n4336;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:102 */
  assign n4339 = n4066 == 12'b110010010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:596:102 */
  assign n4340 = n4337 | n4339;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:33 */
  assign n4342 = n4066 == 12'b110010010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:33 */
  assign n4343 = n4340 | n4342;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:56 */
  assign n4345 = n4066 == 12'b110010010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:56 */
  assign n4346 = n4343 | n4345;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:79 */
  assign n4348 = n4066 == 12'b110010010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:79 */
  assign n4349 = n4346 | n4348;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:102 */
  assign n4351 = n4066 == 12'b110010010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:597:102 */
  assign n4352 = n4349 | n4351;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:33 */
  assign n4354 = n4066 == 12'b110010011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:33 */
  assign n4355 = n4352 | n4354;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:56 */
  assign n4357 = n4066 == 12'b110010011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:56 */
  assign n4358 = n4355 | n4357;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:79 */
  assign n4360 = n4066 == 12'b110010011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:79 */
  assign n4361 = n4358 | n4360;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:102 */
  assign n4363 = n4066 == 12'b110010011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:598:102 */
  assign n4364 = n4361 | n4363;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:33 */
  assign n4366 = n4066 == 12'b110010011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:33 */
  assign n4367 = n4364 | n4366;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:56 */
  assign n4369 = n4066 == 12'b110010011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:56 */
  assign n4370 = n4367 | n4369;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:79 */
  assign n4372 = n4066 == 12'b110010011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:79 */
  assign n4373 = n4370 | n4372;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:102 */
  assign n4375 = n4066 == 12'b110010011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:599:102 */
  assign n4376 = n4373 | n4375;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:600:33 */
  assign n4378 = n4066 == 12'b101100000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:600:33 */
  assign n4379 = n4376 | n4378;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:33 */
  assign n4381 = n4066 == 12'b101100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:33 */
  assign n4382 = n4379 | n4381;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:56 */
  assign n4384 = n4066 == 12'b101100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:56 */
  assign n4385 = n4382 | n4384;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:79 */
  assign n4387 = n4066 == 12'b101100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:79 */
  assign n4388 = n4385 | n4387;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:102 */
  assign n4390 = n4066 == 12'b101100000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:601:102 */
  assign n4391 = n4388 | n4390;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:33 */
  assign n4393 = n4066 == 12'b101100001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:33 */
  assign n4394 = n4391 | n4393;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:56 */
  assign n4396 = n4066 == 12'b101100001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:56 */
  assign n4397 = n4394 | n4396;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:79 */
  assign n4399 = n4066 == 12'b101100001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:79 */
  assign n4400 = n4397 | n4399;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:102 */
  assign n4402 = n4066 == 12'b101100001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:602:102 */
  assign n4403 = n4400 | n4402;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:33 */
  assign n4405 = n4066 == 12'b101100001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:33 */
  assign n4406 = n4403 | n4405;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:56 */
  assign n4408 = n4066 == 12'b101100001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:56 */
  assign n4409 = n4406 | n4408;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:79 */
  assign n4411 = n4066 == 12'b101100001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:79 */
  assign n4412 = n4409 | n4411;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:102 */
  assign n4414 = n4066 == 12'b101100001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:603:102 */
  assign n4415 = n4412 | n4414;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:33 */
  assign n4417 = n4066 == 12'b101100010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:33 */
  assign n4418 = n4415 | n4417;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:56 */
  assign n4420 = n4066 == 12'b101100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:56 */
  assign n4421 = n4418 | n4420;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:79 */
  assign n4423 = n4066 == 12'b101100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:79 */
  assign n4424 = n4421 | n4423;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:102 */
  assign n4426 = n4066 == 12'b101100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:604:102 */
  assign n4427 = n4424 | n4426;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:33 */
  assign n4429 = n4066 == 12'b101100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:33 */
  assign n4430 = n4427 | n4429;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:56 */
  assign n4432 = n4066 == 12'b101100010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:56 */
  assign n4433 = n4430 | n4432;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:79 */
  assign n4435 = n4066 == 12'b101100010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:79 */
  assign n4436 = n4433 | n4435;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:102 */
  assign n4438 = n4066 == 12'b101100010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:605:102 */
  assign n4439 = n4436 | n4438;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:33 */
  assign n4441 = n4066 == 12'b101100011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:33 */
  assign n4442 = n4439 | n4441;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:56 */
  assign n4444 = n4066 == 12'b101100011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:56 */
  assign n4445 = n4442 | n4444;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:79 */
  assign n4447 = n4066 == 12'b101100011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:79 */
  assign n4448 = n4445 | n4447;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:102 */
  assign n4450 = n4066 == 12'b101100011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:606:102 */
  assign n4451 = n4448 | n4450;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:33 */
  assign n4453 = n4066 == 12'b101100011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:33 */
  assign n4454 = n4451 | n4453;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:56 */
  assign n4456 = n4066 == 12'b101100011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:56 */
  assign n4457 = n4454 | n4456;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:79 */
  assign n4459 = n4066 == 12'b101100011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:79 */
  assign n4460 = n4457 | n4459;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:102 */
  assign n4462 = n4066 == 12'b101100011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:607:102 */
  assign n4463 = n4460 | n4462;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:608:33 */
  assign n4465 = n4066 == 12'b101110000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:608:33 */
  assign n4466 = n4463 | n4465;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:33 */
  assign n4468 = n4066 == 12'b101110000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:33 */
  assign n4469 = n4466 | n4468;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:56 */
  assign n4471 = n4066 == 12'b101110000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:56 */
  assign n4472 = n4469 | n4471;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:79 */
  assign n4474 = n4066 == 12'b101110000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:79 */
  assign n4475 = n4472 | n4474;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:102 */
  assign n4477 = n4066 == 12'b101110000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:609:102 */
  assign n4478 = n4475 | n4477;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:33 */
  assign n4480 = n4066 == 12'b101110001000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:33 */
  assign n4481 = n4478 | n4480;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:56 */
  assign n4483 = n4066 == 12'b101110001001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:56 */
  assign n4484 = n4481 | n4483;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:79 */
  assign n4486 = n4066 == 12'b101110001010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:79 */
  assign n4487 = n4484 | n4486;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:102 */
  assign n4489 = n4066 == 12'b101110001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:610:102 */
  assign n4490 = n4487 | n4489;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:33 */
  assign n4492 = n4066 == 12'b101110001100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:33 */
  assign n4493 = n4490 | n4492;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:56 */
  assign n4495 = n4066 == 12'b101110001101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:56 */
  assign n4496 = n4493 | n4495;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:79 */
  assign n4498 = n4066 == 12'b101110001110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:79 */
  assign n4499 = n4496 | n4498;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:102 */
  assign n4501 = n4066 == 12'b101110001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:611:102 */
  assign n4502 = n4499 | n4501;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:33 */
  assign n4504 = n4066 == 12'b101110010000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:33 */
  assign n4505 = n4502 | n4504;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:56 */
  assign n4507 = n4066 == 12'b101110010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:56 */
  assign n4508 = n4505 | n4507;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:79 */
  assign n4510 = n4066 == 12'b101110010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:79 */
  assign n4511 = n4508 | n4510;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:102 */
  assign n4513 = n4066 == 12'b101110010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:612:102 */
  assign n4514 = n4511 | n4513;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:33 */
  assign n4516 = n4066 == 12'b101110010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:33 */
  assign n4517 = n4514 | n4516;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:56 */
  assign n4519 = n4066 == 12'b101110010101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:56 */
  assign n4520 = n4517 | n4519;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:79 */
  assign n4522 = n4066 == 12'b101110010110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:79 */
  assign n4523 = n4520 | n4522;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:102 */
  assign n4525 = n4066 == 12'b101110010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:613:102 */
  assign n4526 = n4523 | n4525;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:33 */
  assign n4528 = n4066 == 12'b101110011000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:33 */
  assign n4529 = n4526 | n4528;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:56 */
  assign n4531 = n4066 == 12'b101110011001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:56 */
  assign n4532 = n4529 | n4531;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:79 */
  assign n4534 = n4066 == 12'b101110011010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:79 */
  assign n4535 = n4532 | n4534;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:102 */
  assign n4537 = n4066 == 12'b101110011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:614:102 */
  assign n4538 = n4535 | n4537;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:33 */
  assign n4540 = n4066 == 12'b101110011100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:33 */
  assign n4541 = n4538 | n4540;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:56 */
  assign n4543 = n4066 == 12'b101110011101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:56 */
  assign n4544 = n4541 | n4543;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:79 */
  assign n4546 = n4066 == 12'b101110011110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:79 */
  assign n4547 = n4544 | n4546;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:102 */
  assign n4549 = n4066 == 12'b101110011111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:615:102 */
  assign n4550 = n4547 | n4549;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:616:33 */
  assign n4552 = n4066 == 12'b001100100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:616:33 */
  assign n4553 = n4550 | n4552;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:33 */
  assign n4555 = n4066 == 12'b001100100100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:33 */
  assign n4556 = n4553 | n4555;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:56 */
  assign n4558 = n4066 == 12'b001100100101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:56 */
  assign n4559 = n4556 | n4558;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:79 */
  assign n4561 = n4066 == 12'b001100100110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:79 */
  assign n4562 = n4559 | n4561;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:102 */
  assign n4564 = n4066 == 12'b001100100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:617:102 */
  assign n4565 = n4562 | n4564;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:33 */
  assign n4567 = n4066 == 12'b001100101000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:33 */
  assign n4568 = n4565 | n4567;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:56 */
  assign n4570 = n4066 == 12'b001100101001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:56 */
  assign n4571 = n4568 | n4570;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:79 */
  assign n4573 = n4066 == 12'b001100101010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:79 */
  assign n4574 = n4571 | n4573;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:102 */
  assign n4576 = n4066 == 12'b001100101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:618:102 */
  assign n4577 = n4574 | n4576;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:33 */
  assign n4579 = n4066 == 12'b001100101100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:33 */
  assign n4580 = n4577 | n4579;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:56 */
  assign n4582 = n4066 == 12'b001100101101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:56 */
  assign n4583 = n4580 | n4582;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:79 */
  assign n4585 = n4066 == 12'b001100101110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:79 */
  assign n4586 = n4583 | n4585;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:102 */
  assign n4588 = n4066 == 12'b001100101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:619:102 */
  assign n4589 = n4586 | n4588;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:33 */
  assign n4591 = n4066 == 12'b001100110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:33 */
  assign n4592 = n4589 | n4591;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:56 */
  assign n4594 = n4066 == 12'b001100110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:56 */
  assign n4595 = n4592 | n4594;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:79 */
  assign n4597 = n4066 == 12'b001100110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:79 */
  assign n4598 = n4595 | n4597;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:102 */
  assign n4600 = n4066 == 12'b001100110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:620:102 */
  assign n4601 = n4598 | n4600;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:33 */
  assign n4603 = n4066 == 12'b001100110100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:33 */
  assign n4604 = n4601 | n4603;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:56 */
  assign n4606 = n4066 == 12'b001100110101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:56 */
  assign n4607 = n4604 | n4606;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:79 */
  assign n4609 = n4066 == 12'b001100110110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:79 */
  assign n4610 = n4607 | n4609;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:102 */
  assign n4612 = n4066 == 12'b001100110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:621:102 */
  assign n4613 = n4610 | n4612;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:33 */
  assign n4615 = n4066 == 12'b001100111000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:33 */
  assign n4616 = n4613 | n4615;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:56 */
  assign n4618 = n4066 == 12'b001100111001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:56 */
  assign n4619 = n4616 | n4618;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:79 */
  assign n4621 = n4066 == 12'b001100111010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:79 */
  assign n4622 = n4619 | n4621;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:102 */
  assign n4624 = n4066 == 12'b001100111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:622:102 */
  assign n4625 = n4622 | n4624;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:33 */
  assign n4627 = n4066 == 12'b001100111100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:33 */
  assign n4628 = n4625 | n4627;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:56 */
  assign n4630 = n4066 == 12'b001100111101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:56 */
  assign n4631 = n4628 | n4630;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:79 */
  assign n4633 = n4066 == 12'b001100111110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:79 */
  assign n4634 = n4631 | n4633;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:102 */
  assign n4636 = n4066 == 12'b001100111111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:623:102 */
  assign n4637 = n4634 | n4636;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:7 */
  assign n4641 = n4066 == 12'b110000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:25 */
  assign n4643 = n4066 == 12'b110000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:25 */
  assign n4644 = n4641 | n4643;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:39 */
  assign n4646 = n4066 == 12'b110000000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:39 */
  assign n4647 = n4644 | n4646;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:56 */
  assign n4649 = n4066 == 12'b101100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:56 */
  assign n4650 = n4647 | n4649;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:72 */
  assign n4652 = n4066 == 12'b101100000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:72 */
  assign n4653 = n4650 | n4652;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:89 */
  assign n4655 = n4066 == 12'b110010000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:628:89 */
  assign n4656 = n4653 | n4655;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:25 */
  assign n4658 = n4066 == 12'b110010000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:25 */
  assign n4659 = n4656 | n4658;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:39 */
  assign n4661 = n4066 == 12'b110010000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:39 */
  assign n4662 = n4659 | n4661;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:56 */
  assign n4664 = n4066 == 12'b101110000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:56 */
  assign n4665 = n4662 | n4664;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:72 */
  assign n4667 = n4066 == 12'b101110000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:629:72 */
  assign n4668 = n4665 | n4667;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:7 */
  assign n4672 = n4066 == 12'b001100100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:28 */
  assign n4674 = n4066 == 12'b001100100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:28 */
  assign n4675 = n4672 | n4674;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:48 */
  assign n4677 = n4066 == 12'b011100100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:48 */
  assign n4678 = n4675 | n4677;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:67 */
  assign n4680 = n4066 == 12'b011100100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:633:67 */
  assign n4681 = n4678 | n4680;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:7 */
  assign n4685 = n4066 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:23 */
  assign n4687 = n4066 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:23 */
  assign n4688 = n4685 | n4687;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:35 */
  assign n4690 = n4066 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:637:35 */
  assign n4691 = n4688 | n4690;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:7 */
  assign n4695 = n4066 == 12'b011110100000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:26 */
  assign n4697 = n4066 == 12'b011110100001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:26 */
  assign n4698 = n4695 | n4697;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:41 */
  assign n4700 = n4066 == 12'b011110100010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:41 */
  assign n4701 = n4698 | n4700;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:56 */
  assign n4703 = n4066 == 12'b011110100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:56 */
  assign n4704 = n4701 | n4703;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:71 */
  assign n4706 = n4066 == 12'b011110100100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:641:71 */
  assign n4707 = n4704 | n4706;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:5 */
  assign n4709 = {n4707, n4691, n4681, n4668, n4637, n4201, n4140, n4130, n4076};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:561:5 */
  always @*
    case (n4709)
      9'b100000000: n4710 = 1'b0;
      9'b010000000: n4710 = 1'b0;
      9'b001000000: n4710 = 1'b0;
      9'b000100000: n4710 = 1'b0;
      9'b000010000: n4710 = 1'b0;
      9'b000001000: n4710 = 1'b0;
      9'b000000100: n4710 = 1'b1;
      9'b000000010: n4710 = 1'b1;
      9'b000000001: n4710 = 1'b0;
      default: n4710 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:22 */
  assign n4711 = ctrl[178:177]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:37 */
  assign n4713 = n4711 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:17 */
  assign n4714 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:64 */
  assign n4716 = n4714 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:17 */
  assign n4717 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:64 */
  assign n4719 = n4717 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:654:83 */
  assign n4720 = n4716 | n4719;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:656:17 */
  assign n4721 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:656:58 */
  assign n4723 = n4721 != 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:655:83 */
  assign n4724 = n4720 | n4723;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:45 */
  assign n4725 = n4724 & n4713;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:653:5 */
  assign n4728 = n4725 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:25 */
  assign n4732 = ctrl[176:175]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:38 */
  assign n4734 = n4732 != 2'b00;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:56 */
  assign n4735 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:66 */
  assign n4736 = ~n4735;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:47 */
  assign n4737 = n4736 & n4734;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:672:5 */
  assign n4740 = n4737 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:17 */
  assign n4743 = exec[10:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:7 */
  assign n4745 = n4743 == 7'b0110111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:25 */
  assign n4747 = n4743 == 7'b0010111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:25 */
  assign n4748 = n4745 | n4747;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:42 */
  assign n4750 = n4743 == 7'b1101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:688:42 */
  assign n4751 = n4748 | n4750;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:20 */
  assign n4752 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:67 */
  assign n4754 = n4752 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:693:9 */
  assign n4757 = n4754 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:692:7 */
  assign n4759 = n4743 == 7'b1100111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:20 */
  assign n4760 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:69 */
  assign n4762 = n4760 != 2'b01;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:78 */
  assign n4764 = n4762 | 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:699:9 */
  assign n4767 = n4764 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:698:7 */
  assign n4769 = n4743 == 7'b1100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:705:21 */
  assign n4770 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:11 */
  assign n4772 = n4770 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:28 */
  assign n4774 = n4770 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:28 */
  assign n4775 = n4772 | n4774;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:42 */
  assign n4777 = n4770 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:42 */
  assign n4778 = n4775 | n4777;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:56 */
  assign n4780 = n4770 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:56 */
  assign n4781 = n4778 | n4780;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:71 */
  assign n4783 = n4770 == 3'b101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:706:71 */
  assign n4784 = n4781 | n4783;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:705:9 */
  always @*
    case (n4784)
      1'b1: n4787 = 1'b0;
      default: n4787 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:704:7 */
  assign n4789 = n4743 == 7'b0000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:712:21 */
  assign n4790 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:11 */
  assign n4792 = n4790 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:28 */
  assign n4794 = n4790 == 3'b001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:28 */
  assign n4795 = n4792 | n4794;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:42 */
  assign n4797 = n4790 == 3'b010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:713:42 */
  assign n4798 = n4795 | n4797;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:712:9 */
  always @*
    case (n4798)
      1'b1: n4801 = 1'b0;
      default: n4801 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:711:7 */
  assign n4803 = n4743 == 7'b0100011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:718:7 */
  assign n4843 = n4743 == 7'b0101111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:7 */
  assign n4845 = n4743 == 7'b0110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:25 */
  assign n4847 = n4743 == 7'b0010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:25 */
  assign n4848 = n4845 | n4847;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:41 */
  assign n4850 = n4743 == 7'b1010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:41 */
  assign n4851 = n4848 | n4850;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:56 */
  assign n4853 = n4743 == 7'b0111011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:56 */
  assign n4854 = n4851 | n4853;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:72 */
  assign n4856 = n4743 == 7'b0011011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:72 */
  assign n4857 = n4854 | n4856;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:89 */
  assign n4859 = n4743 == 7'b0001011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:89 */
  assign n4860 = n4857 | n4859;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:106 */
  assign n4862 = n4743 == 7'b0101011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:728:106 */
  assign n4863 = n4860 | n4862;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:20 */
  assign n4864 = exec[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:69 */
  assign n4866 = n4864 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:733:9 */
  assign n4869 = n4866 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:732:7 */
  assign n4871 = n4743 == 7'b0001111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:20 */
  assign n4872 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:67 */
  assign n4874 = n4872 == 3'b000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:22 */
  assign n4875 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:63 */
  assign n4877 = n4875 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:86 */
  assign n4878 = exec[15:11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:125 */
  assign n4880 = n4878 == 5'b00000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:74 */
  assign n4881 = n4880 & n4877;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:25 */
  assign n4882 = exec[35:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:742:15 */
  assign n4884 = n4882 == 12'b000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:743:15 */
  assign n4886 = n4882 == 12'b000000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:64 */
  assign n4887 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:56 */
  assign n4888 = ~n4887;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:89 */
  assign n4889 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:75 */
  assign n4890 = n4888 | n4889;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:744:15 */
  assign n4892 = n4882 == 12'b001100000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:70 */
  assign n4893 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:55 */
  assign n4894 = ~n4893;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:745:15 */
  assign n4896 = n4882 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:64 */
  assign n4897 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:56 */
  assign n4898 = ~n4897;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:83 */
  assign n4899 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:75 */
  assign n4900 = n4898 & n4899;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:746:15 */
  assign n4902 = n4882 == 12'b000100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:13 */
  assign n4903 = {n4902, n4896, n4892, n4886, n4884};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:741:13 */
  always @*
    case (n4903)
      5'b10000: n4907 = n4900;
      5'b01000: n4907 = n4894;
      5'b00100: n4907 = n4890;
      5'b00010: n4907 = 1'b0;
      5'b00001: n4907 = 1'b0;
      default: n4907 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:740:11 */
  assign n4909 = n4881 ? n4907 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:23 */
  assign n4910 = exec[18:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:70 */
  assign n4912 = n4910 == 3'b100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:756:26 */
  assign n4914 = csr_valid == 3'b111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:756:9 */
  assign n4917 = n4914 ? 1'b0 : 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:750:9 */
  assign n4919 = n4912 ? 1'b1 : n4917;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:739:9 */
  assign n4920 = n4874 ? n4909 : n4919;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:738:7 */
  assign n4922 = n4743 == 7'b1110011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:5 */
  assign n4923 = {n4922, n4871, n4863, n4843, n4803, n4789, n4769, n4759, n4751};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:685:5 */
  always @*
    case (n4923)
      9'b100000000: n4928 = n4920;
      9'b010000000: n4928 = n4869;
      9'b001000000: n4928 = 1'b0;
      9'b000100000: n4928 = 1'b1;
      9'b000010000: n4928 = n4801;
      9'b000001000: n4928 = n4787;
      9'b000000100: n4928 = n4767;
      9'b000000010: n4928 = n4757;
      9'b000000001: n4928 = 1'b0;
      default: n4928 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:772:16 */
  assign n4932 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:16 */
  assign n4934 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:22 */
  assign n4936 = n4934 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:776:64 */
  assign n4938 = monitor_cnt + 10'b0000000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:775:7 */
  assign n4940 = n4936 ? n4938 : 10'b0000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:31 */
  assign n4946 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:37 */
  assign n4948 = n4946 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:59 */
  assign n4949 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:65 */
  assign n4951 = n4949 == 4'b0101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:50 */
  assign n4952 = n4948 | n4951;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:787:37 */
  assign n4953 = monitor_cnt[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:787:59 */
  assign n4954 = n4953 | illegal_cmd;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:80 */
  assign n4955 = n4954 & n4952;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:786:19 */
  assign n4956 = n4955 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:798:16 */
  assign n4959 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:29 */
  assign n4961 = debug_ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:39 */
  assign n4962 = {n4961, irq_fast_i};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:804:52 */
  assign n4963 = {n4962, irq_machine_i};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:41 */
  assign n4964 = irq_pnd[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:98 */
  assign n4965 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:87 */
  assign n4966 = env_pend & n4965;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:806:74 */
  assign n4967 = n4964 | n4966;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:41 */
  assign n4968 = irq_pnd[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:65 */
  assign n4969 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:57 */
  assign n4970 = n4968 & n4969;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:98 */
  assign n4971 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:87 */
  assign n4972 = env_pend & n4971;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:807:74 */
  assign n4973 = n4970 | n4972;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:41 */
  assign n4974 = irq_pnd[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:65 */
  assign n4975 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:57 */
  assign n4976 = n4974 & n4975;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:98 */
  assign n4977 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:87 */
  assign n4978 = env_pend & n4977;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:808:74 */
  assign n4979 = n4976 | n4978;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:41 */
  assign n4980 = irq_pnd[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:65 */
  assign n4981 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:57 */
  assign n4982 = n4980 & n4981;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:98 */
  assign n4983 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:87 */
  assign n4984 = env_pend & n4983;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:809:74 */
  assign n4985 = n4982 | n4984;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n4986 = irq_pnd[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n4987 = csr[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n4988 = n4986 & n4987;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n4989 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n4990 = env_pend & n4989;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n4991 = n4988 | n4990;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n4992 = irq_pnd[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n4993 = csr[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n4994 = n4992 & n4993;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n4995 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n4996 = env_pend & n4995;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n4997 = n4994 | n4996;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n4998 = irq_pnd[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n4999 = csr[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5000 = n4998 & n4999;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5001 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5002 = env_pend & n5001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5003 = n5000 | n5002;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5004 = irq_pnd[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5005 = csr[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5006 = n5004 & n5005;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5007 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5008 = env_pend & n5007;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5009 = n5006 | n5008;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5010 = irq_pnd[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5011 = csr[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5012 = n5010 & n5011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5013 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5014 = env_pend & n5013;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5015 = n5012 | n5014;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5016 = irq_pnd[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5017 = csr[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5018 = n5016 & n5017;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5019 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5020 = env_pend & n5019;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5021 = n5018 | n5020;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5022 = irq_pnd[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5023 = csr[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5024 = n5022 & n5023;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5025 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5026 = env_pend & n5025;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5027 = n5024 | n5026;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5028 = irq_pnd[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5029 = csr[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5030 = n5028 & n5029;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5031 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5032 = env_pend & n5031;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5033 = n5030 | n5032;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5034 = irq_pnd[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5035 = csr[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5036 = n5034 & n5035;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5037 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5038 = env_pend & n5037;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5039 = n5036 | n5038;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5040 = irq_pnd[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5041 = csr[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5042 = n5040 & n5041;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5043 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5044 = env_pend & n5043;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5045 = n5042 | n5044;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5046 = irq_pnd[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5047 = csr[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5048 = n5046 & n5047;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5049 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5050 = env_pend & n5049;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5051 = n5048 | n5050;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5052 = irq_pnd[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5053 = csr[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5054 = n5052 & n5053;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5055 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5056 = env_pend & n5055;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5057 = n5054 | n5056;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5058 = irq_pnd[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5059 = csr[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5060 = n5058 & n5059;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5061 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5062 = env_pend & n5061;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5063 = n5060 | n5062;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5064 = irq_pnd[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5065 = csr[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5066 = n5064 & n5065;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5067 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5068 = env_pend & n5067;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5069 = n5066 | n5068;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5070 = irq_pnd[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5071 = csr[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5072 = n5070 & n5071;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5073 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5074 = env_pend & n5073;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5075 = n5072 | n5074;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:44 */
  assign n5076 = irq_pnd[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:77 */
  assign n5077 = csr[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:61 */
  assign n5078 = n5076 & n5077;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:106 */
  assign n5079 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:95 */
  assign n5080 = env_pend & n5079;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:811:82 */
  assign n5081 = n5078 | n5080;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:41 */
  assign n5082 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:57 */
  assign n5083 = n5082 | instr_be;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:88 */
  assign n5084 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:814:83 */
  assign n5085 = n5083 & n5084;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:41 */
  assign n5086 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:57 */
  assign n5087 = n5086 | instr_il;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:88 */
  assign n5088 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:815:83 */
  assign n5089 = n5087 & n5088;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:41 */
  assign n5090 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:57 */
  assign n5091 = n5090 | instr_ma;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:88 */
  assign n5092 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:816:83 */
  assign n5093 = n5091 & n5092;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:41 */
  assign n5094 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:57 */
  assign n5095 = n5094 | ecall;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:88 */
  assign n5096 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:817:83 */
  assign n5097 = n5095 & n5096;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:41 */
  assign n5098 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:57 */
  assign n5099 = n5098 | ebreak_trig;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:88 */
  assign n5100 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:818:83 */
  assign n5101 = n5099 & n5100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:41 */
  assign n5102 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:69 */
  assign n5103 = lsu_err_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:57 */
  assign n5104 = n5102 | n5103;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:88 */
  assign n5105 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:819:83 */
  assign n5106 = n5104 & n5105;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:41 */
  assign n5107 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:69 */
  assign n5108 = lsu_err_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:57 */
  assign n5109 = n5107 | n5108;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:88 */
  assign n5110 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:820:83 */
  assign n5111 = n5109 & n5110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:41 */
  assign n5112 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:69 */
  assign n5113 = lsu_err_i[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:57 */
  assign n5114 = n5112 | n5113;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:88 */
  assign n5115 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:821:83 */
  assign n5116 = n5114 & n5115;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:41 */
  assign n5117 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:69 */
  assign n5118 = lsu_err_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:57 */
  assign n5119 = n5117 | n5118;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:88 */
  assign n5120 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:822:83 */
  assign n5121 = n5119 & n5120;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:41 */
  assign n5122 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:71 */
  assign n5123 = debug_ctrl[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:57 */
  assign n5124 = n5122 | n5123;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:88 */
  assign n5125 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:823:83 */
  assign n5126 = n5124 & n5125;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:41 */
  assign n5127 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:71 */
  assign n5128 = debug_ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:57 */
  assign n5129 = n5127 | n5128;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:88 */
  assign n5130 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:824:83 */
  assign n5131 = n5129 & n5130;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:41 */
  assign n5132 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:71 */
  assign n5133 = debug_ctrl[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:57 */
  assign n5134 = n5132 | n5133;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:88 */
  assign n5135 = ~env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:825:83 */
  assign n5136 = n5134 & n5135;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  assign n5137 = {n5136, n5131, n5126, n5121, n5116, n5111, n5106, n5101, n5097, n5093, n5089, n5085};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  assign n5140 = {n4967, n5081, n5075, n5069, n5063, n5057, n5051, n5045, n5039, n5033, n5027, n5021, n5015, n5009, n5003, n4997, n4991, n4979, n4985, n4973};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:39 */
  assign n5149 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:26 */
  assign n5150 = ebreak & n5149;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:63 */
  assign n5151 = csr[191]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:55 */
  assign n5152 = ~n5151;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:50 */
  assign n5153 = n5150 & n5152;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:97 */
  assign n5154 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:82 */
  assign n5155 = ~n5154;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:77 */
  assign n5156 = n5153 & n5155;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:39 */
  assign n5157 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:31 */
  assign n5158 = ~n5157;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:26 */
  assign n5159 = ebreak & n5158;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:63 */
  assign n5160 = csr[192]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:55 */
  assign n5161 = ~n5160;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:50 */
  assign n5162 = n5159 & n5161;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:97 */
  assign n5163 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:82 */
  assign n5164 = ~n5163;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:831:77 */
  assign n5165 = n5162 & n5164;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:830:103 */
  assign n5166 = n5156 | n5165;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:838:16 */
  assign n5168 = ~rstn_i;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5176 = irq_fire[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5178 = 1'b0 | n5176;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5180 = irq_fire[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5181 = n5178 | n5180;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:843:30 */
  assign n5182 = exc_fire | n5181;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:843:7 */
  assign n5184 = n5182 ? 1'b1 : env_pend;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:841:7 */
  assign n5186 = env_enter ? 1'b0 : n5184;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5197 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5199 = 1'b0 | n5197;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5201 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5202 = n5199 | n5201;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5203 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5204 = n5202 | n5203;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5205 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5206 = n5204 | n5205;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5207 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5208 = n5206 | n5207;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5209 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5210 = n5208 | n5209;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5211 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5212 = n5210 | n5211;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5213 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5214 = n5212 | n5213;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5215 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5216 = n5214 | n5215;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5217 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5218 = n5216 | n5217;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5219 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5220 = n5218 | n5219;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5221 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5222 = n5220 | n5221;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:12 */
  assign n5224 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:18 */
  assign n5226 = n5224 == 4'b0100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:40 */
  assign n5227 = exec[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:46 */
  assign n5229 = n5227 == 4'b1010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:31 */
  assign n5230 = n5226 | n5229;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5238 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5240 = 1'b0 | n5238;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5242 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5243 = n5240 | n5242;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5244 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5245 = n5243 | n5244;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5246 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5247 = n5245 | n5246;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5248 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5249 = n5247 | n5248;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5250 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5251 = n5249 | n5250;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5252 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5253 = n5251 | n5252;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5254 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5255 = n5253 | n5254;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5256 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5257 = n5255 | n5256;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5258 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5259 = n5257 | n5258;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5260 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5261 = n5259 | n5260;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5262 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5263 = n5261 | n5262;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5264 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5265 = n5263 | n5264;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5266 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5267 = n5265 | n5266;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5268 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5269 = n5267 | n5268;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5270 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5271 = n5269 | n5270;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5272 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5273 = n5271 | n5272;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5274 = irq_buf[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5275 = n5273 | n5274;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n5276 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n5277 = n5275 | n5276;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:854:58 */
  assign n5278 = n5277 & n5230;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:11 */
  assign n5279 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:38 */
  assign n5280 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:48 */
  assign n5281 = ~n5280;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:30 */
  assign n5282 = n5279 | n5281;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:855:70 */
  assign n5283 = n5282 & n5278;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:17 */
  assign n5284 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:21 */
  assign n5285 = ~n5284;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:856:66 */
  assign n5286 = n5285 & n5283;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:37 */
  assign n5287 = csr[193]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:47 */
  assign n5288 = ~n5287;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:857:28 */
  assign n5289 = n5288 & n5286;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:853:22 */
  assign n5290 = n5289 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:860:25 */
  assign n5292 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:33 */
  assign n5294 = exc_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:20 */
  assign n5295 = n5294 ? 7'b0000001 : n5298;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:868:33 */
  assign n5297 = exc_buf[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:867:56 */
  assign n5298 = n5297 ? 7'b0000010 : n5301;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:869:33 */
  assign n5300 = exc_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:868:56 */
  assign n5301 = n5300 ? 7'b0000000 : n5303;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:870:33 */
  assign n5302 = exc_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:869:56 */
  assign n5303 = n5302 ? trap_env : n5306;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:871:33 */
  assign n5305 = exc_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:870:56 */
  assign n5306 = n5305 ? 7'b0000011 : n5309;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:872:33 */
  assign n5308 = exc_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:871:56 */
  assign n5309 = n5308 ? 7'b0000110 : n5312;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:873:33 */
  assign n5311 = exc_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:872:56 */
  assign n5312 = n5311 ? 7'b0000100 : n5315;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:874:33 */
  assign n5314 = exc_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:873:56 */
  assign n5315 = n5314 ? 7'b0000111 : n5318;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:875:33 */
  assign n5317 = exc_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:874:56 */
  assign n5318 = n5317 ? 7'b0000101 : n5321;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:877:33 */
  assign n5320 = irq_buf[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:875:56 */
  assign n5321 = n5320 ? 7'b1100011 : n5324;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:878:33 */
  assign n5323 = exc_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:877:56 */
  assign n5324 = n5323 ? 7'b1100010 : n5327;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:879:33 */
  assign n5326 = exc_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:878:56 */
  assign n5327 = n5326 ? 7'b0100001 : n5330;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:880:33 */
  assign n5329 = exc_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:879:56 */
  assign n5330 = n5329 ? 7'b1100100 : n5333;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:882:33 */
  assign n5332 = irq_buf[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:880:56 */
  assign n5333 = n5332 ? 7'b1010000 : n5336;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:883:33 */
  assign n5335 = irq_buf[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:882:56 */
  assign n5336 = n5335 ? 7'b1010001 : n5339;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:884:33 */
  assign n5338 = irq_buf[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:883:56 */
  assign n5339 = n5338 ? 7'b1010010 : n5342;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:885:33 */
  assign n5341 = irq_buf[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:884:56 */
  assign n5342 = n5341 ? 7'b1010011 : n5345;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:886:33 */
  assign n5344 = irq_buf[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:885:56 */
  assign n5345 = n5344 ? 7'b1010100 : n5348;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:887:33 */
  assign n5347 = irq_buf[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:886:56 */
  assign n5348 = n5347 ? 7'b1010101 : n5351;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:888:33 */
  assign n5350 = irq_buf[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:887:56 */
  assign n5351 = n5350 ? 7'b1010110 : n5354;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:889:33 */
  assign n5353 = irq_buf[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:888:56 */
  assign n5354 = n5353 ? 7'b1010111 : n5357;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:890:33 */
  assign n5356 = irq_buf[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:889:56 */
  assign n5357 = n5356 ? 7'b1011000 : n5360;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:891:33 */
  assign n5359 = irq_buf[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:890:56 */
  assign n5360 = n5359 ? 7'b1011001 : n5363;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:892:33 */
  assign n5362 = irq_buf[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:891:56 */
  assign n5363 = n5362 ? 7'b1011010 : n5366;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:893:33 */
  assign n5365 = irq_buf[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:892:56 */
  assign n5366 = n5365 ? 7'b1011011 : n5369;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:894:33 */
  assign n5368 = irq_buf[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:893:56 */
  assign n5369 = n5368 ? 7'b1011100 : n5372;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:895:33 */
  assign n5371 = irq_buf[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:894:56 */
  assign n5372 = n5371 ? 7'b1011101 : n5375;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:896:33 */
  assign n5374 = irq_buf[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:895:56 */
  assign n5375 = n5374 ? 7'b1011110 : n5378;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:897:33 */
  assign n5377 = irq_buf[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:896:56 */
  assign n5378 = n5377 ? 7'b1011111 : n5381;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:899:33 */
  assign n5380 = irq_buf[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:897:56 */
  assign n5381 = n5380 ? 7'b1001011 : n5384;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:900:33 */
  assign n5383 = irq_buf[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:899:56 */
  assign n5384 = n5383 ? 7'b1000011 : 7'b1000111;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:44 */
  assign n5386 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:38 */
  assign n5388 = {5'b00010, n5386};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:60 */
  assign n5389 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:904:54 */
  assign n5390 = {n5388, n5389};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:15 */
  assign n5391 = exec[116:85]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:31 */
  assign n5392 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:19 */
  assign n5393 = n5392 ? n5391 : n5394;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:907:52 */
  assign n5394 = exec[84:53]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:16 */
  assign n5422 = exec[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:37 */
  assign n5423 = ~n5422;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:980:48 */
  assign n5425 = exec[23:19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:980:39 */
  assign n5427 = {27'b000000000000000000000000000, n5425};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:977:5 */
  assign n5428 = n5423 ? rf_rs1_i : n5427;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:17 */
  assign n5429 = exec[17:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:983:45 */
  assign n5430 = csr_rdata | n5428;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:983:7 */
  assign n5432 = n5429 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:50 */
  assign n5433 = ~n5428;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:45 */
  assign n5434 = csr_rdata & n5433;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:984:7 */
  assign n5436 = n5429 == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:5 */
  assign n5437 = {n5436, n5432};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:982:5 */
  always @*
    case (n5437)
      2'b10: n5438 = n5434;
      2'b01: n5438 = n5430;
      default: n5438 = n5428;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:994:16 */
  assign n5441 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:16 */
  assign n5466 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:19 */
  assign n5467 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1027:42 */
  assign n5468 = csr_wdata[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1028:42 */
  assign n5469 = csr_wdata[7]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5477 = csr_wdata[12]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5479 = 1'b1 & n5477;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5481 = csr_wdata[11]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5482 = n5479 & n5481;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1030:42 */
  assign n5483 = csr_wdata[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1031:42 */
  assign n5484 = csr_wdata[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1026:11 */
  assign n5486 = n5467 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1034:38 */
  assign n5487 = csr_wdata[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1035:38 */
  assign n5488 = csr_wdata[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1036:38 */
  assign n5489 = csr_wdata[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1037:38 */
  assign n5490 = csr_wdata[31:16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1033:11 */
  assign n5492 = n5467 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:35 */
  assign n5493 = csr_wdata[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:49 */
  assign n5495 = {n5493, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:66 */
  assign n5496 = csr_wdata[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1040:55 */
  assign n5497 = {n5495, n5496};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1039:11 */
  assign n5499 = n5467 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1042:11 */
  assign n5501 = n5467 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1045:11 */
  assign n5503 = n5467 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1049:34 */
  assign n5504 = csr_wdata[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1049:48 */
  assign n5506 = {n5504, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1048:11 */
  assign n5508 = n5467 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:36 */
  assign n5509 = csr_wdata[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:52 */
  assign n5510 = csr_wdata[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1052:41 */
  assign n5511 = {n5509, n5510};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1051:11 */
  assign n5513 = n5467 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1054:11 */
  assign n5515 = n5467 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1058:42 */
  assign n5516 = csr_wdata[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1059:42 */
  assign n5517 = csr_wdata[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1060:42 */
  assign n5518 = csr_wdata[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5526 = csr_wdata[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5528 = 1'b1 & n5526;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n5530 = csr_wdata[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n5531 = n5528 & n5530;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1057:11 */
  assign n5533 = n5467 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1063:11 */
  assign n5538 = n5467 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1066:11 */
  assign n5540 = n5467 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  assign n5541 = {n5540, n5538, n5533, n5515, n5513, n5508, n5503, n5501, n5499, n5492, n5486};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5542 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5543 = n5542;
      11'b01000000000: n5543 = n5542;
      11'b00100000000: n5543 = n5542;
      11'b00010000000: n5543 = n5542;
      11'b00001000000: n5543 = n5542;
      11'b00000100000: n5543 = n5542;
      11'b00000010000: n5543 = n5542;
      11'b00000001000: n5543 = n5542;
      11'b00000000100: n5543 = n5542;
      11'b00000000010: n5543 = n5542;
      11'b00000000001: n5543 = n5468;
      default: n5543 = n5542;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5544 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5545 = n5544;
      11'b01000000000: n5545 = n5544;
      11'b00100000000: n5545 = n5544;
      11'b00010000000: n5545 = n5544;
      11'b00001000000: n5545 = n5544;
      11'b00000100000: n5545 = n5544;
      11'b00000010000: n5545 = n5544;
      11'b00000001000: n5545 = n5544;
      11'b00000000100: n5545 = n5544;
      11'b00000000010: n5545 = n5544;
      11'b00000000001: n5545 = n5469;
      default: n5545 = n5544;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5546 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5547 = n5546;
      11'b01000000000: n5547 = n5546;
      11'b00100000000: n5547 = n5546;
      11'b00010000000: n5547 = n5546;
      11'b00001000000: n5547 = n5546;
      11'b00000100000: n5547 = n5546;
      11'b00000010000: n5547 = n5546;
      11'b00000001000: n5547 = n5546;
      11'b00000000100: n5547 = n5546;
      11'b00000000010: n5547 = n5546;
      11'b00000000001: n5547 = n5482;
      default: n5547 = n5546;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5548 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5549 = n5548;
      11'b01000000000: n5549 = n5548;
      11'b00100000000: n5549 = n5548;
      11'b00010000000: n5549 = n5548;
      11'b00001000000: n5549 = n5548;
      11'b00000100000: n5549 = n5548;
      11'b00000010000: n5549 = n5548;
      11'b00000001000: n5549 = n5548;
      11'b00000000100: n5549 = n5548;
      11'b00000000010: n5549 = n5548;
      11'b00000000001: n5549 = n5483;
      default: n5549 = n5548;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5550 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5551 = n5550;
      11'b01000000000: n5551 = n5550;
      11'b00100000000: n5551 = n5550;
      11'b00010000000: n5551 = n5550;
      11'b00001000000: n5551 = n5550;
      11'b00000100000: n5551 = n5550;
      11'b00000010000: n5551 = n5550;
      11'b00000001000: n5551 = n5550;
      11'b00000000100: n5551 = n5550;
      11'b00000000010: n5551 = n5550;
      11'b00000000001: n5551 = n5484;
      default: n5551 = n5550;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5552 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5553 = n5552;
      11'b01000000000: n5553 = n5552;
      11'b00100000000: n5553 = n5552;
      11'b00010000000: n5553 = n5552;
      11'b00001000000: n5553 = n5552;
      11'b00000100000: n5553 = n5552;
      11'b00000010000: n5553 = n5552;
      11'b00000001000: n5553 = n5552;
      11'b00000000100: n5553 = n5552;
      11'b00000000010: n5553 = n5487;
      11'b00000000001: n5553 = n5552;
      default: n5553 = n5552;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5554 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5555 = n5554;
      11'b01000000000: n5555 = n5554;
      11'b00100000000: n5555 = n5554;
      11'b00010000000: n5555 = n5554;
      11'b00001000000: n5555 = n5554;
      11'b00000100000: n5555 = n5554;
      11'b00000010000: n5555 = n5554;
      11'b00000001000: n5555 = n5554;
      11'b00000000100: n5555 = n5554;
      11'b00000000010: n5555 = n5489;
      11'b00000000001: n5555 = n5554;
      default: n5555 = n5554;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5556 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5557 = n5556;
      11'b01000000000: n5557 = n5556;
      11'b00100000000: n5557 = n5556;
      11'b00010000000: n5557 = n5556;
      11'b00001000000: n5557 = n5556;
      11'b00000100000: n5557 = n5556;
      11'b00000010000: n5557 = n5556;
      11'b00000001000: n5557 = n5556;
      11'b00000000100: n5557 = n5556;
      11'b00000000010: n5557 = n5488;
      11'b00000000001: n5557 = n5556;
      default: n5557 = n5556;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5558 = csr[24:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5559 = n5558;
      11'b01000000000: n5559 = n5558;
      11'b00100000000: n5559 = n5558;
      11'b00010000000: n5559 = n5558;
      11'b00001000000: n5559 = n5558;
      11'b00000100000: n5559 = n5558;
      11'b00000010000: n5559 = n5558;
      11'b00000001000: n5559 = n5558;
      11'b00000000100: n5559 = n5558;
      11'b00000000010: n5559 = n5490;
      11'b00000000001: n5559 = n5558;
      default: n5559 = n5558;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5560 = csr[56:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5561 = n5560;
      11'b01000000000: n5561 = n5560;
      11'b00100000000: n5561 = n5560;
      11'b00010000000: n5561 = n5560;
      11'b00001000000: n5561 = n5560;
      11'b00000100000: n5561 = n5506;
      11'b00000010000: n5561 = n5560;
      11'b00000001000: n5561 = n5560;
      11'b00000000100: n5561 = n5560;
      11'b00000000010: n5561 = n5560;
      11'b00000000001: n5561 = n5560;
      default: n5561 = n5560;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5562 = csr[62:57]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5563 = n5562;
      11'b01000000000: n5563 = n5562;
      11'b00100000000: n5563 = n5562;
      11'b00010000000: n5563 = n5562;
      11'b00001000000: n5563 = n5511;
      11'b00000100000: n5563 = n5562;
      11'b00000010000: n5563 = n5562;
      11'b00000001000: n5563 = n5562;
      11'b00000000100: n5563 = n5562;
      11'b00000000010: n5563 = n5562;
      11'b00000000001: n5563 = n5562;
      default: n5563 = n5562;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5564 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5565 = n5564;
      11'b01000000000: n5565 = n5564;
      11'b00100000000: n5565 = n5564;
      11'b00010000000: n5565 = n5564;
      11'b00001000000: n5565 = n5564;
      11'b00000100000: n5565 = n5564;
      11'b00000010000: n5565 = n5564;
      11'b00000001000: n5565 = n5564;
      11'b00000000100: n5565 = n5497;
      11'b00000000010: n5565 = n5564;
      11'b00000000001: n5565 = n5564;
      default: n5565 = n5564;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5566 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5567 = n5566;
      11'b01000000000: n5567 = n5566;
      11'b00100000000: n5567 = n5566;
      11'b00010000000: n5567 = csr_wdata;
      11'b00001000000: n5567 = n5566;
      11'b00000100000: n5567 = n5566;
      11'b00000010000: n5567 = n5566;
      11'b00000001000: n5567 = n5566;
      11'b00000000100: n5567 = n5566;
      11'b00000000010: n5567 = n5566;
      11'b00000000001: n5567 = n5566;
      default: n5567 = n5566;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5568 = csr[158:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5569 = n5568;
      11'b01000000000: n5569 = n5568;
      11'b00100000000: n5569 = n5568;
      11'b00010000000: n5569 = n5568;
      11'b00001000000: n5569 = n5568;
      11'b00000100000: n5569 = n5568;
      11'b00000010000: n5569 = csr_wdata;
      11'b00000001000: n5569 = n5568;
      11'b00000000100: n5569 = n5568;
      11'b00000000010: n5569 = n5568;
      11'b00000000001: n5569 = n5568;
      default: n5569 = n5568;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5570 = csr[190:159]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5571 = n5570;
      11'b01000000000: n5571 = n5570;
      11'b00100000000: n5571 = n5570;
      11'b00010000000: n5571 = n5570;
      11'b00001000000: n5571 = n5570;
      11'b00000100000: n5571 = n5570;
      11'b00000010000: n5571 = n5570;
      11'b00000001000: n5571 = csr_wdata;
      11'b00000000100: n5571 = n5570;
      11'b00000000010: n5571 = n5570;
      11'b00000000001: n5571 = n5570;
      default: n5571 = n5570;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5572 = csr[191]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5573 = n5572;
      11'b01000000000: n5573 = n5572;
      11'b00100000000: n5573 = n5518;
      11'b00010000000: n5573 = n5572;
      11'b00001000000: n5573 = n5572;
      11'b00000100000: n5573 = n5572;
      11'b00000010000: n5573 = n5572;
      11'b00000001000: n5573 = n5572;
      11'b00000000100: n5573 = n5572;
      11'b00000000010: n5573 = n5572;
      11'b00000000001: n5573 = n5572;
      default: n5573 = n5572;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5574 = csr[192]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5575 = n5574;
      11'b01000000000: n5575 = n5574;
      11'b00100000000: n5575 = n5517;
      11'b00010000000: n5575 = n5574;
      11'b00001000000: n5575 = n5574;
      11'b00000100000: n5575 = n5574;
      11'b00000010000: n5575 = n5574;
      11'b00000001000: n5575 = n5574;
      11'b00000000100: n5575 = n5574;
      11'b00000000010: n5575 = n5574;
      11'b00000000001: n5575 = n5574;
      default: n5575 = n5574;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5576 = csr[193]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5577 = n5576;
      11'b01000000000: n5577 = n5576;
      11'b00100000000: n5577 = n5516;
      11'b00010000000: n5577 = n5576;
      11'b00001000000: n5577 = n5576;
      11'b00000100000: n5577 = n5576;
      11'b00000010000: n5577 = n5576;
      11'b00000001000: n5577 = n5576;
      11'b00000000100: n5577 = n5576;
      11'b00000000010: n5577 = n5576;
      11'b00000000001: n5577 = n5576;
      default: n5577 = n5576;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5578 = csr[194]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1024:9 */
  always @*
    case (n5541)
      11'b10000000000: n5579 = n5578;
      11'b01000000000: n5579 = n5578;
      11'b00100000000: n5579 = n5531;
      11'b00010000000: n5579 = n5578;
      11'b00001000000: n5579 = n5578;
      11'b00000100000: n5579 = n5578;
      11'b00000010000: n5579 = n5578;
      11'b00000001000: n5579 = n5578;
      11'b00000000100: n5579 = n5578;
      11'b00000000010: n5579 = n5578;
      11'b00000000001: n5579 = n5578;
      default: n5579 = n5578;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:24 */
  assign n5584 = debug_ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:28 */
  assign n5585 = ~n5584;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1086:37 */
  assign n5587 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1088:37 */
  assign n5589 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:39 */
  assign n5590 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:51 */
  assign n5591 = ecause[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1089:43 */
  assign n5592 = {n5590, n5591};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1090:36 */
  assign n5593 = epc[31:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1090:50 */
  assign n5595 = {n5593, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:23 */
  assign n5596 = ecause[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:27 */
  assign n5597 = ~n5596;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1092:25 */
  assign n5598 = ecause[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:28 */
  assign n5599 = ecause[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:41 */
  assign n5601 = n5599 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:42 */
  assign n5602 = exec[52]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:32 */
  assign n5604 = n5602 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1096:47 */
  assign n5605 = exec[51:36]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1096:40 */
  assign n5607 = {16'b0000000000000000, n5605};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1098:37 */
  assign n5608 = exec[35:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1095:17 */
  assign n5609 = n5604 ? n5607 : n5608;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1094:15 */
  assign n5611 = n5601 ? n5609 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1092:15 */
  assign n5612 = n5598 ? lsu_mar_i : n5611;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1091:13 */
  assign n5614 = n5597 ? n5612 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5615 = {n5587, n5589, 1'b0, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5616 = {n5592, n5595};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5617 = csr[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1078:9 */
  assign n5618 = n5585 ? n5615 : n5617;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5619 = csr[62:25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5620 = n5642 ? n5616 : n5619;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5621 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5622 = n5644 ? n5614 : n5621;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1121:32 */
  assign n5623 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:19 */
  assign n5624 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:31 */
  assign n5626 = n5624 != 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5628 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1122:11 */
  assign n5629 = n5626 ? 1'b0 : n5628;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1126:35 */
  assign n5631 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5633 = {n5629, 1'b0, 1'b1, n5631, n5623};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5634 = csr[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5635 = env_exit ? n5633 : n5634;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5636 = n5635[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5637 = env_enter ? n5618 : n5636;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1114:7 */
  assign n5638 = n5635[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5639 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5640 = env_enter ? n5639 : n5638;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5642 = n5585 & env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1077:7 */
  assign n5644 = n5585 & env_enter;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5645 = {n5640, n5637};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5646 = {n5579, n5577, n5575, n5573, n5571, n5569, n5567, n5565, n5563, n5561, n5559, n5557, n5555, n5553, n5551, n5549, n5547, n5545, n5543};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5648 = n5645[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5649 = csr[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5650 = n5466 ? n5649 : n5648;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5651 = n5645[4:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5652 = n5646[3:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5653 = n5466 ? n5652 : n5651;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5654 = n5646[23:4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5655 = csr[24:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5656 = n5466 ? n5654 : n5655;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5657 = n5646[61:24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5658 = n5466 ? n5657 : n5620;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5659 = n5646[93:62]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5660 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5661 = n5466 ? n5659 : n5660;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5662 = n5646[125:94]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5663 = n5466 ? n5662 : n5622;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5664 = n5646[193:126]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5665 = csr[194:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1023:7 */
  assign n5666 = n5466 ? n5664 : n5665;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:152:10 */
  assign n5671 = n5666[31:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1018:5 */
  assign n5685 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 29'b00000000000000000000000000000, 3'b000, n5671, n5663, n5661, n5658, n5656, n5653, n5650};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:994:5 */
  assign n5687 = {32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 32'b00000000000000000000000000000000, 6'b000000, 32'b00000000000000000000000000000000, 16'b0000000000000000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1176:16 */
  assign n5691 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:16 */
  assign n5693 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:19 */
  assign n5694 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1187:34 */
  assign n5695 = csr[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1188:34 */
  assign n5696 = csr[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1189:34 */
  assign n5697 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1190:34 */
  assign n5698 = csr[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1191:34 */
  assign n5699 = csr[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1192:34 */
  assign n5700 = csr[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1192:45 */
  assign n5703 = n5700 & 1'b1;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1186:11 */
  assign n5705 = n5694 == 12'b001100000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1194:11 */
  assign n5723 = n5694 == 12'b001100000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1206:34 */
  assign n5724 = csr[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1207:34 */
  assign n5725 = csr[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1208:34 */
  assign n5726 = csr[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n5727 = csr[24:9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1205:11 */
  assign n5729 = n5694 == 12'b001100000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5730 = csr[94:63]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1211:11 */
  assign n5732 = n5694 == 12'b001100000101;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1214:11 */
  assign n5734 = n5694 == 12'b001100000110;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5735 = csr[158:127]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1222:11 */
  assign n5737 = n5694 == 12'b001101000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:34 */
  assign n5738 = csr[56:26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5740 = {n5738, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1225:11 */
  assign n5742 = n5694 == 12'b001101000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1229:40 */
  assign n5743 = csr[62]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5744 = csr[61:57]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1228:11 */
  assign n5746 = n5694 == 12'b001101000010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5747 = csr[126:95]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1232:11 */
  assign n5749 = n5694 == 12'b001101000011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1236:37 */
  assign n5750 = irq_pnd[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1237:37 */
  assign n5751 = irq_pnd[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1238:37 */
  assign n5752 = irq_pnd[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n5753 = irq_pnd[18:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1235:11 */
  assign n5755 = n5694 == 12'b001101000100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1244:11 */
  assign n5757 = n5694 == 12'b111100010001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1245:11 */
  assign n5759 = n5694 == 12'b111100010010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1246:11 */
  assign n5761 = n5694 == 12'b111100010011;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1247:11 */
  assign n5763 = n5694 == 12'b111100010100;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1252:11 */
  assign n5765 = n5694 == 12'b011110110000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1253:11 */
  assign n5767 = n5694 == 12'b011110110001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1254:11 */
  assign n5769 = n5694 == 12'b011110110010;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1259:11 */
  assign n5833 = n5694 == 12'b111111000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1293:11 */
  assign n5839 = n5694 == 12'b111111000001;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  assign n5840 = {n5839, n5833, n5769, n5767, n5765, n5763, n5761, n5759, n5757, n5755, n5749, n5746, n5742, n5737, n5734, n5732, n5729, n5723, n5705};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5841 = n5730[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5842 = n5735[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5843 = n5740[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5844 = n5744[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5845 = n5747[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5850 = xcsr_rdata_i[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5852 = 1'b0;
      19'b0100000000000000000: n5852 = 1'b1;
      19'b0010000000000000000: n5852 = 1'b0;
      19'b0001000000000000000: n5852 = 1'b0;
      19'b0000100000000000000: n5852 = 1'b0;
      19'b0000010000000000000: n5852 = 1'b0;
      19'b0000001000000000000: n5852 = 1'b0;
      19'b0000000100000000000: n5852 = 1'b1;
      19'b0000000010000000000: n5852 = 1'b0;
      19'b0000000001000000000: n5852 = 1'b0;
      19'b0000000000100000000: n5852 = n5845;
      19'b0000000000010000000: n5852 = n5844;
      19'b0000000000001000000: n5852 = n5843;
      19'b0000000000000100000: n5852 = n5842;
      19'b0000000000000010000: n5852 = 1'b0;
      19'b0000000000000001000: n5852 = n5841;
      19'b0000000000000000100: n5852 = 1'b0;
      19'b0000000000000000010: n5852 = 1'b0;
      19'b0000000000000000001: n5852 = 1'b0;
      default: n5852 = n5850;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5853 = n5730[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5854 = n5735[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5855 = n5740[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5856 = n5744[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5857 = n5747[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5862 = xcsr_rdata_i[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5864 = 1'b0;
      19'b0100000000000000000: n5864 = 1'b1;
      19'b0010000000000000000: n5864 = 1'b0;
      19'b0001000000000000000: n5864 = 1'b0;
      19'b0000100000000000000: n5864 = 1'b0;
      19'b0000010000000000000: n5864 = 1'b0;
      19'b0000001000000000000: n5864 = 1'b1;
      19'b0000000100000000000: n5864 = 1'b1;
      19'b0000000010000000000: n5864 = 1'b0;
      19'b0000000001000000000: n5864 = 1'b0;
      19'b0000000000100000000: n5864 = n5857;
      19'b0000000000010000000: n5864 = n5856;
      19'b0000000000001000000: n5864 = n5855;
      19'b0000000000000100000: n5864 = n5854;
      19'b0000000000000010000: n5864 = 1'b0;
      19'b0000000000000001000: n5864 = n5853;
      19'b0000000000000000100: n5864 = 1'b0;
      19'b0000000000000000010: n5864 = 1'b0;
      19'b0000000000000000001: n5864 = 1'b0;
      default: n5864 = n5862;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5865 = n5730[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5866 = n5735[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5867 = n5740[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5868 = n5744[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5869 = n5747[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5874 = xcsr_rdata_i[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5876 = 1'b0;
      19'b0100000000000000000: n5876 = 1'b0;
      19'b0010000000000000000: n5876 = 1'b0;
      19'b0001000000000000000: n5876 = 1'b0;
      19'b0000100000000000000: n5876 = 1'b0;
      19'b0000010000000000000: n5876 = 1'b0;
      19'b0000001000000000000: n5876 = 1'b0;
      19'b0000000100000000000: n5876 = 1'b0;
      19'b0000000010000000000: n5876 = 1'b0;
      19'b0000000001000000000: n5876 = 1'b0;
      19'b0000000000100000000: n5876 = n5869;
      19'b0000000000010000000: n5876 = n5868;
      19'b0000000000001000000: n5876 = n5867;
      19'b0000000000000100000: n5876 = n5866;
      19'b0000000000000010000: n5876 = 1'b0;
      19'b0000000000000001000: n5876 = n5865;
      19'b0000000000000000100: n5876 = 1'b0;
      19'b0000000000000000010: n5876 = 1'b1;
      19'b0000000000000000001: n5876 = 1'b0;
      default: n5876 = n5874;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5877 = n5730[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5878 = n5735[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5879 = n5740[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5880 = n5744[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5881 = n5747[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5886 = xcsr_rdata_i[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5888 = 1'b0;
      19'b0100000000000000000: n5888 = 1'b0;
      19'b0010000000000000000: n5888 = 1'b0;
      19'b0001000000000000000: n5888 = 1'b0;
      19'b0000100000000000000: n5888 = 1'b0;
      19'b0000010000000000000: n5888 = 1'b0;
      19'b0000001000000000000: n5888 = 1'b0;
      19'b0000000100000000000: n5888 = 1'b0;
      19'b0000000010000000000: n5888 = 1'b0;
      19'b0000000001000000000: n5888 = n5750;
      19'b0000000000100000000: n5888 = n5881;
      19'b0000000000010000000: n5888 = n5880;
      19'b0000000000001000000: n5888 = n5879;
      19'b0000000000000100000: n5888 = n5878;
      19'b0000000000000010000: n5888 = 1'b0;
      19'b0000000000000001000: n5888 = n5877;
      19'b0000000000000000100: n5888 = n5724;
      19'b0000000000000000010: n5888 = 1'b0;
      19'b0000000000000000001: n5888 = n5695;
      default: n5888 = n5886;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5889 = n5730[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5890 = n5735[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5891 = n5740[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1230:48 */
  assign n5892 = n5744[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5893 = n5747[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5898 = xcsr_rdata_i[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5900 = 1'b0;
      19'b0100000000000000000: n5900 = 1'b0;
      19'b0010000000000000000: n5900 = 1'b0;
      19'b0001000000000000000: n5900 = 1'b0;
      19'b0000100000000000000: n5900 = 1'b0;
      19'b0000010000000000000: n5900 = 1'b0;
      19'b0000001000000000000: n5900 = 1'b0;
      19'b0000000100000000000: n5900 = 1'b1;
      19'b0000000010000000000: n5900 = 1'b0;
      19'b0000000001000000000: n5900 = 1'b0;
      19'b0000000000100000000: n5900 = n5893;
      19'b0000000000010000000: n5900 = n5892;
      19'b0000000000001000000: n5900 = n5891;
      19'b0000000000000100000: n5900 = n5890;
      19'b0000000000000010000: n5900 = 1'b0;
      19'b0000000000000001000: n5900 = n5889;
      19'b0000000000000000100: n5900 = 1'b0;
      19'b0000000000000000010: n5900 = 1'b0;
      19'b0000000000000000001: n5900 = 1'b0;
      default: n5900 = n5898;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5901 = n5730[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5902 = n5735[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5903 = n5740[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5904 = n5747[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5909 = xcsr_rdata_i[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5911 = 1'b0;
      19'b0100000000000000000: n5911 = 1'b0;
      19'b0010000000000000000: n5911 = 1'b0;
      19'b0001000000000000000: n5911 = 1'b0;
      19'b0000100000000000000: n5911 = 1'b0;
      19'b0000010000000000000: n5911 = 1'b0;
      19'b0000001000000000000: n5911 = 1'b0;
      19'b0000000100000000000: n5911 = 1'b0;
      19'b0000000010000000000: n5911 = 1'b0;
      19'b0000000001000000000: n5911 = 1'b0;
      19'b0000000000100000000: n5911 = n5904;
      19'b0000000000010000000: n5911 = 1'b0;
      19'b0000000000001000000: n5911 = n5903;
      19'b0000000000000100000: n5911 = n5902;
      19'b0000000000000010000: n5911 = 1'b0;
      19'b0000000000000001000: n5911 = n5901;
      19'b0000000000000000100: n5911 = 1'b0;
      19'b0000000000000000010: n5911 = 1'b0;
      19'b0000000000000000001: n5911 = 1'b0;
      default: n5911 = n5909;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5912 = n5730[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5913 = n5735[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5914 = n5740[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5915 = n5747[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5920 = xcsr_rdata_i[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5922 = 1'b0;
      19'b0100000000000000000: n5922 = 1'b0;
      19'b0010000000000000000: n5922 = 1'b0;
      19'b0001000000000000000: n5922 = 1'b0;
      19'b0000100000000000000: n5922 = 1'b0;
      19'b0000010000000000000: n5922 = 1'b0;
      19'b0000001000000000000: n5922 = 1'b0;
      19'b0000000100000000000: n5922 = 1'b0;
      19'b0000000010000000000: n5922 = 1'b0;
      19'b0000000001000000000: n5922 = 1'b0;
      19'b0000000000100000000: n5922 = n5915;
      19'b0000000000010000000: n5922 = 1'b0;
      19'b0000000000001000000: n5922 = n5914;
      19'b0000000000000100000: n5922 = n5913;
      19'b0000000000000010000: n5922 = 1'b0;
      19'b0000000000000001000: n5922 = n5912;
      19'b0000000000000000100: n5922 = 1'b0;
      19'b0000000000000000010: n5922 = 1'b0;
      19'b0000000000000000001: n5922 = 1'b0;
      default: n5922 = n5920;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5923 = n5730[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5924 = n5735[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5925 = n5740[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5926 = n5747[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5931 = xcsr_rdata_i[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5933 = 1'b0;
      19'b0100000000000000000: n5933 = 1'b0;
      19'b0010000000000000000: n5933 = 1'b0;
      19'b0001000000000000000: n5933 = 1'b0;
      19'b0000100000000000000: n5933 = 1'b0;
      19'b0000010000000000000: n5933 = 1'b0;
      19'b0000001000000000000: n5933 = 1'b0;
      19'b0000000100000000000: n5933 = 1'b0;
      19'b0000000010000000000: n5933 = 1'b0;
      19'b0000000001000000000: n5933 = n5751;
      19'b0000000000100000000: n5933 = n5926;
      19'b0000000000010000000: n5933 = 1'b0;
      19'b0000000000001000000: n5933 = n5925;
      19'b0000000000000100000: n5933 = n5924;
      19'b0000000000000010000: n5933 = 1'b0;
      19'b0000000000000001000: n5933 = n5923;
      19'b0000000000000000100: n5933 = n5725;
      19'b0000000000000000010: n5933 = 1'b0;
      19'b0000000000000000001: n5933 = n5696;
      default: n5933 = n5931;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5934 = n5730[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5935 = n5735[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5936 = n5740[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5937 = n5747[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5942 = xcsr_rdata_i[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5944 = 1'b0;
      19'b0100000000000000000: n5944 = 1'b0;
      19'b0010000000000000000: n5944 = 1'b0;
      19'b0001000000000000000: n5944 = 1'b0;
      19'b0000100000000000000: n5944 = 1'b0;
      19'b0000010000000000000: n5944 = 1'b0;
      19'b0000001000000000000: n5944 = 1'b1;
      19'b0000000100000000000: n5944 = 1'b0;
      19'b0000000010000000000: n5944 = 1'b0;
      19'b0000000001000000000: n5944 = 1'b0;
      19'b0000000000100000000: n5944 = n5937;
      19'b0000000000010000000: n5944 = 1'b0;
      19'b0000000000001000000: n5944 = n5936;
      19'b0000000000000100000: n5944 = n5935;
      19'b0000000000000010000: n5944 = 1'b0;
      19'b0000000000000001000: n5944 = n5934;
      19'b0000000000000000100: n5944 = 1'b0;
      19'b0000000000000000010: n5944 = 1'b1;
      19'b0000000000000000001: n5944 = 1'b0;
      default: n5944 = n5942;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5945 = n5730[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5946 = n5735[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5947 = n5740[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5948 = n5747[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5953 = xcsr_rdata_i[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5955 = 1'b0;
      19'b0100000000000000000: n5955 = 1'b0;
      19'b0010000000000000000: n5955 = 1'b0;
      19'b0001000000000000000: n5955 = 1'b0;
      19'b0000100000000000000: n5955 = 1'b0;
      19'b0000010000000000000: n5955 = 1'b0;
      19'b0000001000000000000: n5955 = 1'b1;
      19'b0000000100000000000: n5955 = 1'b0;
      19'b0000000010000000000: n5955 = 1'b0;
      19'b0000000001000000000: n5955 = 1'b0;
      19'b0000000000100000000: n5955 = n5948;
      19'b0000000000010000000: n5955 = 1'b0;
      19'b0000000000001000000: n5955 = n5947;
      19'b0000000000000100000: n5955 = n5946;
      19'b0000000000000010000: n5955 = 1'b0;
      19'b0000000000000001000: n5955 = n5945;
      19'b0000000000000000100: n5955 = 1'b0;
      19'b0000000000000000010: n5955 = 1'b0;
      19'b0000000000000000001: n5955 = 1'b0;
      default: n5955 = n5953;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5956 = n5730[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5957 = n5735[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5958 = n5740[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5959 = n5747[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5964 = xcsr_rdata_i[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5966 = 1'b0;
      19'b0100000000000000000: n5966 = 1'b0;
      19'b0010000000000000000: n5966 = 1'b0;
      19'b0001000000000000000: n5966 = 1'b0;
      19'b0000100000000000000: n5966 = 1'b0;
      19'b0000010000000000000: n5966 = 1'b0;
      19'b0000001000000000000: n5966 = 1'b0;
      19'b0000000100000000000: n5966 = 1'b0;
      19'b0000000010000000000: n5966 = 1'b0;
      19'b0000000001000000000: n5966 = 1'b0;
      19'b0000000000100000000: n5966 = n5959;
      19'b0000000000010000000: n5966 = 1'b0;
      19'b0000000000001000000: n5966 = n5958;
      19'b0000000000000100000: n5966 = n5957;
      19'b0000000000000010000: n5966 = 1'b0;
      19'b0000000000000001000: n5966 = n5956;
      19'b0000000000000000100: n5966 = 1'b0;
      19'b0000000000000000010: n5966 = 1'b0;
      19'b0000000000000000001: n5966 = 1'b0;
      default: n5966 = n5964;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5967 = n5730[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5968 = n5735[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5969 = n5740[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5970 = n5747[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5975 = xcsr_rdata_i[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5977 = 1'b0;
      19'b0100000000000000000: n5977 = 1'b0;
      19'b0010000000000000000: n5977 = 1'b0;
      19'b0001000000000000000: n5977 = 1'b0;
      19'b0000100000000000000: n5977 = 1'b0;
      19'b0000010000000000000: n5977 = 1'b0;
      19'b0000001000000000000: n5977 = 1'b0;
      19'b0000000100000000000: n5977 = 1'b0;
      19'b0000000010000000000: n5977 = 1'b0;
      19'b0000000001000000000: n5977 = n5752;
      19'b0000000000100000000: n5977 = n5970;
      19'b0000000000010000000: n5977 = 1'b0;
      19'b0000000000001000000: n5977 = n5969;
      19'b0000000000000100000: n5977 = n5968;
      19'b0000000000000010000: n5977 = 1'b0;
      19'b0000000000000001000: n5977 = n5967;
      19'b0000000000000000100: n5977 = n5726;
      19'b0000000000000000010: n5977 = 1'b0;
      19'b0000000000000000001: n5977 = n5697;
      default: n5977 = n5975;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5978 = n5730[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5979 = n5735[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5980 = n5740[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5981 = n5747[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5986 = xcsr_rdata_i[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5988 = 1'b0;
      19'b0100000000000000000: n5988 = 1'b0;
      19'b0010000000000000000: n5988 = 1'b0;
      19'b0001000000000000000: n5988 = 1'b0;
      19'b0000100000000000000: n5988 = 1'b0;
      19'b0000010000000000000: n5988 = 1'b0;
      19'b0000001000000000000: n5988 = 1'b0;
      19'b0000000100000000000: n5988 = 1'b0;
      19'b0000000010000000000: n5988 = 1'b0;
      19'b0000000001000000000: n5988 = 1'b0;
      19'b0000000000100000000: n5988 = n5981;
      19'b0000000000010000000: n5988 = 1'b0;
      19'b0000000000001000000: n5988 = n5980;
      19'b0000000000000100000: n5988 = n5979;
      19'b0000000000000010000: n5988 = 1'b0;
      19'b0000000000000001000: n5988 = n5978;
      19'b0000000000000000100: n5988 = 1'b0;
      19'b0000000000000000010: n5988 = 1'b1;
      19'b0000000000000000001: n5988 = n5698;
      default: n5988 = n5986;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n5989 = n5730[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n5990 = n5735[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n5991 = n5740[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n5992 = n5747[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n5997 = xcsr_rdata_i[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n5999 = 1'b0;
      19'b0100000000000000000: n5999 = 1'b0;
      19'b0010000000000000000: n5999 = 1'b0;
      19'b0001000000000000000: n5999 = 1'b0;
      19'b0000100000000000000: n5999 = 1'b0;
      19'b0000010000000000000: n5999 = 1'b0;
      19'b0000001000000000000: n5999 = 1'b0;
      19'b0000000100000000000: n5999 = 1'b0;
      19'b0000000010000000000: n5999 = 1'b0;
      19'b0000000001000000000: n5999 = 1'b0;
      19'b0000000000100000000: n5999 = n5992;
      19'b0000000000010000000: n5999 = 1'b0;
      19'b0000000000001000000: n5999 = n5991;
      19'b0000000000000100000: n5999 = n5990;
      19'b0000000000000010000: n5999 = 1'b0;
      19'b0000000000000001000: n5999 = n5989;
      19'b0000000000000000100: n5999 = 1'b0;
      19'b0000000000000000010: n5999 = 1'b0;
      19'b0000000000000000001: n5999 = 1'b0;
      default: n5999 = n5997;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6000 = n5730[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6001 = n5735[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6002 = n5740[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6003 = n5747[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6008 = xcsr_rdata_i[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
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
      19'b0000000000010000000: n6010 = 1'b0;
      19'b0000000000001000000: n6010 = n6002;
      19'b0000000000000100000: n6010 = n6001;
      19'b0000000000000010000: n6010 = 1'b0;
      19'b0000000000000001000: n6010 = n6000;
      19'b0000000000000000100: n6010 = 1'b0;
      19'b0000000000000000010: n6010 = 1'b0;
      19'b0000000000000000001: n6010 = 1'b0;
      default: n6010 = n6008;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6011 = n5730[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6012 = n5735[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6013 = n5740[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6014 = n5747[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6019 = xcsr_rdata_i[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6021 = 1'b0;
      19'b0100000000000000000: n6021 = 1'b0;
      19'b0010000000000000000: n6021 = 1'b0;
      19'b0001000000000000000: n6021 = 1'b0;
      19'b0000100000000000000: n6021 = 1'b0;
      19'b0000010000000000000: n6021 = 1'b0;
      19'b0000001000000000000: n6021 = 1'b0;
      19'b0000000100000000000: n6021 = 1'b0;
      19'b0000000010000000000: n6021 = 1'b0;
      19'b0000000001000000000: n6021 = 1'b0;
      19'b0000000000100000000: n6021 = n6014;
      19'b0000000000010000000: n6021 = 1'b0;
      19'b0000000000001000000: n6021 = n6013;
      19'b0000000000000100000: n6021 = n6012;
      19'b0000000000000010000: n6021 = 1'b0;
      19'b0000000000000001000: n6021 = n6011;
      19'b0000000000000000100: n6021 = 1'b0;
      19'b0000000000000000010: n6021 = 1'b0;
      19'b0000000000000000001: n6021 = 1'b0;
      default: n6021 = n6019;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6022 = n5727[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6023 = n5730[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6024 = n5735[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6025 = n5740[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6026 = n5747[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6027 = n5753[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6032 = xcsr_rdata_i[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6034 = 1'b0;
      19'b0100000000000000000: n6034 = 1'b0;
      19'b0010000000000000000: n6034 = 1'b0;
      19'b0001000000000000000: n6034 = 1'b0;
      19'b0000100000000000000: n6034 = 1'b0;
      19'b0000010000000000000: n6034 = 1'b0;
      19'b0000001000000000000: n6034 = 1'b1;
      19'b0000000100000000000: n6034 = 1'b0;
      19'b0000000010000000000: n6034 = 1'b0;
      19'b0000000001000000000: n6034 = n6027;
      19'b0000000000100000000: n6034 = n6026;
      19'b0000000000010000000: n6034 = 1'b0;
      19'b0000000000001000000: n6034 = n6025;
      19'b0000000000000100000: n6034 = n6024;
      19'b0000000000000010000: n6034 = 1'b0;
      19'b0000000000000001000: n6034 = n6023;
      19'b0000000000000000100: n6034 = n6022;
      19'b0000000000000000010: n6034 = 1'b0;
      19'b0000000000000000001: n6034 = 1'b0;
      default: n6034 = n6032;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6035 = n5727[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6036 = n5730[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6037 = n5735[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6038 = n5740[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6039 = n5747[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6040 = n5753[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6045 = xcsr_rdata_i[17]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6047 = 1'b0;
      19'b0100000000000000000: n6047 = 1'b0;
      19'b0010000000000000000: n6047 = 1'b0;
      19'b0001000000000000000: n6047 = 1'b0;
      19'b0000100000000000000: n6047 = 1'b0;
      19'b0000010000000000000: n6047 = 1'b0;
      19'b0000001000000000000: n6047 = 1'b1;
      19'b0000000100000000000: n6047 = 1'b0;
      19'b0000000010000000000: n6047 = 1'b0;
      19'b0000000001000000000: n6047 = n6040;
      19'b0000000000100000000: n6047 = n6039;
      19'b0000000000010000000: n6047 = 1'b0;
      19'b0000000000001000000: n6047 = n6038;
      19'b0000000000000100000: n6047 = n6037;
      19'b0000000000000010000: n6047 = 1'b0;
      19'b0000000000000001000: n6047 = n6036;
      19'b0000000000000000100: n6047 = n6035;
      19'b0000000000000000010: n6047 = 1'b0;
      19'b0000000000000000001: n6047 = n5699;
      default: n6047 = n6045;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6048 = n5727[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6049 = n5730[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6050 = n5735[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6051 = n5740[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6052 = n5747[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6053 = n5753[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6058 = xcsr_rdata_i[18]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6060 = 1'b0;
      19'b0100000000000000000: n6060 = 1'b0;
      19'b0010000000000000000: n6060 = 1'b0;
      19'b0001000000000000000: n6060 = 1'b0;
      19'b0000100000000000000: n6060 = 1'b0;
      19'b0000010000000000000: n6060 = 1'b0;
      19'b0000001000000000000: n6060 = 1'b0;
      19'b0000000100000000000: n6060 = 1'b0;
      19'b0000000010000000000: n6060 = 1'b0;
      19'b0000000001000000000: n6060 = n6053;
      19'b0000000000100000000: n6060 = n6052;
      19'b0000000000010000000: n6060 = 1'b0;
      19'b0000000000001000000: n6060 = n6051;
      19'b0000000000000100000: n6060 = n6050;
      19'b0000000000000010000: n6060 = 1'b0;
      19'b0000000000000001000: n6060 = n6049;
      19'b0000000000000000100: n6060 = n6048;
      19'b0000000000000000010: n6060 = 1'b0;
      19'b0000000000000000001: n6060 = 1'b0;
      default: n6060 = n6058;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6061 = n5727[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6062 = n5730[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6063 = n5735[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6064 = n5740[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6065 = n5747[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6066 = n5753[3]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6071 = xcsr_rdata_i[19]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6073 = 1'b0;
      19'b0100000000000000000: n6073 = 1'b0;
      19'b0010000000000000000: n6073 = 1'b0;
      19'b0001000000000000000: n6073 = 1'b0;
      19'b0000100000000000000: n6073 = 1'b0;
      19'b0000010000000000000: n6073 = 1'b0;
      19'b0000001000000000000: n6073 = 1'b0;
      19'b0000000100000000000: n6073 = 1'b0;
      19'b0000000010000000000: n6073 = 1'b0;
      19'b0000000001000000000: n6073 = n6066;
      19'b0000000000100000000: n6073 = n6065;
      19'b0000000000010000000: n6073 = 1'b0;
      19'b0000000000001000000: n6073 = n6064;
      19'b0000000000000100000: n6073 = n6063;
      19'b0000000000000010000: n6073 = 1'b0;
      19'b0000000000000001000: n6073 = n6062;
      19'b0000000000000000100: n6073 = n6061;
      19'b0000000000000000010: n6073 = 1'b0;
      19'b0000000000000000001: n6073 = 1'b0;
      default: n6073 = n6071;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6074 = n5727[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6075 = n5730[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6076 = n5735[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6077 = n5740[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6078 = n5747[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6079 = n5753[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6084 = xcsr_rdata_i[20]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6086 = 1'b0;
      19'b0100000000000000000: n6086 = 1'b0;
      19'b0010000000000000000: n6086 = 1'b0;
      19'b0001000000000000000: n6086 = 1'b0;
      19'b0000100000000000000: n6086 = 1'b0;
      19'b0000010000000000000: n6086 = 1'b0;
      19'b0000001000000000000: n6086 = 1'b1;
      19'b0000000100000000000: n6086 = 1'b0;
      19'b0000000010000000000: n6086 = 1'b0;
      19'b0000000001000000000: n6086 = n6079;
      19'b0000000000100000000: n6086 = n6078;
      19'b0000000000010000000: n6086 = 1'b0;
      19'b0000000000001000000: n6086 = n6077;
      19'b0000000000000100000: n6086 = n6076;
      19'b0000000000000010000: n6086 = 1'b0;
      19'b0000000000000001000: n6086 = n6075;
      19'b0000000000000000100: n6086 = n6074;
      19'b0000000000000000010: n6086 = 1'b1;
      19'b0000000000000000001: n6086 = 1'b0;
      default: n6086 = n6084;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6087 = n5727[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6088 = n5730[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6089 = n5735[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6090 = n5740[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6091 = n5747[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6092 = n5753[5]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6097 = xcsr_rdata_i[21]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6099 = 1'b0;
      19'b0100000000000000000: n6099 = 1'b0;
      19'b0010000000000000000: n6099 = 1'b0;
      19'b0001000000000000000: n6099 = 1'b0;
      19'b0000100000000000000: n6099 = 1'b0;
      19'b0000010000000000000: n6099 = 1'b0;
      19'b0000001000000000000: n6099 = 1'b0;
      19'b0000000100000000000: n6099 = 1'b0;
      19'b0000000010000000000: n6099 = 1'b0;
      19'b0000000001000000000: n6099 = n6092;
      19'b0000000000100000000: n6099 = n6091;
      19'b0000000000010000000: n6099 = 1'b0;
      19'b0000000000001000000: n6099 = n6090;
      19'b0000000000000100000: n6099 = n6089;
      19'b0000000000000010000: n6099 = 1'b0;
      19'b0000000000000001000: n6099 = n6088;
      19'b0000000000000000100: n6099 = n6087;
      19'b0000000000000000010: n6099 = 1'b0;
      19'b0000000000000000001: n6099 = n5703;
      default: n6099 = n6097;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6100 = n5727[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6101 = n5730[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6102 = n5735[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6103 = n5740[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6104 = n5747[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6105 = n5753[6]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6110 = xcsr_rdata_i[22]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6112 = 1'b0;
      19'b0100000000000000000: n6112 = 1'b0;
      19'b0010000000000000000: n6112 = 1'b0;
      19'b0001000000000000000: n6112 = 1'b0;
      19'b0000100000000000000: n6112 = 1'b0;
      19'b0000010000000000000: n6112 = 1'b0;
      19'b0000001000000000000: n6112 = 1'b0;
      19'b0000000100000000000: n6112 = 1'b0;
      19'b0000000010000000000: n6112 = 1'b0;
      19'b0000000001000000000: n6112 = n6105;
      19'b0000000000100000000: n6112 = n6104;
      19'b0000000000010000000: n6112 = 1'b0;
      19'b0000000000001000000: n6112 = n6103;
      19'b0000000000000100000: n6112 = n6102;
      19'b0000000000000010000: n6112 = 1'b0;
      19'b0000000000000001000: n6112 = n6101;
      19'b0000000000000000100: n6112 = n6100;
      19'b0000000000000000010: n6112 = 1'b0;
      19'b0000000000000000001: n6112 = 1'b0;
      default: n6112 = n6110;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6113 = n5727[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6114 = n5730[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6115 = n5735[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6116 = n5740[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6117 = n5747[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6118 = n5753[7]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6123 = xcsr_rdata_i[23]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6125 = 1'b0;
      19'b0100000000000000000: n6125 = 1'b0;
      19'b0010000000000000000: n6125 = 1'b0;
      19'b0001000000000000000: n6125 = 1'b0;
      19'b0000100000000000000: n6125 = 1'b0;
      19'b0000010000000000000: n6125 = 1'b0;
      19'b0000001000000000000: n6125 = 1'b0;
      19'b0000000100000000000: n6125 = 1'b0;
      19'b0000000010000000000: n6125 = 1'b0;
      19'b0000000001000000000: n6125 = n6118;
      19'b0000000000100000000: n6125 = n6117;
      19'b0000000000010000000: n6125 = 1'b0;
      19'b0000000000001000000: n6125 = n6116;
      19'b0000000000000100000: n6125 = n6115;
      19'b0000000000000010000: n6125 = 1'b0;
      19'b0000000000000001000: n6125 = n6114;
      19'b0000000000000000100: n6125 = n6113;
      19'b0000000000000000010: n6125 = 1'b1;
      19'b0000000000000000001: n6125 = 1'b0;
      default: n6125 = n6123;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6126 = n5727[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6127 = n5730[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6128 = n5735[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6129 = n5740[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6130 = n5747[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6131 = n5753[8]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6136 = xcsr_rdata_i[24]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6138 = 1'b0;
      19'b0100000000000000000: n6138 = 1'b0;
      19'b0010000000000000000: n6138 = 1'b0;
      19'b0001000000000000000: n6138 = 1'b0;
      19'b0000100000000000000: n6138 = 1'b0;
      19'b0000010000000000000: n6138 = 1'b0;
      19'b0000001000000000000: n6138 = 1'b1;
      19'b0000000100000000000: n6138 = 1'b0;
      19'b0000000010000000000: n6138 = 1'b0;
      19'b0000000001000000000: n6138 = n6131;
      19'b0000000000100000000: n6138 = n6130;
      19'b0000000000010000000: n6138 = 1'b0;
      19'b0000000000001000000: n6138 = n6129;
      19'b0000000000000100000: n6138 = n6128;
      19'b0000000000000010000: n6138 = 1'b0;
      19'b0000000000000001000: n6138 = n6127;
      19'b0000000000000000100: n6138 = n6126;
      19'b0000000000000000010: n6138 = 1'b0;
      19'b0000000000000000001: n6138 = 1'b0;
      default: n6138 = n6136;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6139 = n5727[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6140 = n5730[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6141 = n5735[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6142 = n5740[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6143 = n5747[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6144 = n5753[9]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6149 = xcsr_rdata_i[25]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6151 = 1'b0;
      19'b0100000000000000000: n6151 = 1'b0;
      19'b0010000000000000000: n6151 = 1'b0;
      19'b0001000000000000000: n6151 = 1'b0;
      19'b0000100000000000000: n6151 = 1'b0;
      19'b0000010000000000000: n6151 = 1'b0;
      19'b0000001000000000000: n6151 = 1'b0;
      19'b0000000100000000000: n6151 = 1'b0;
      19'b0000000010000000000: n6151 = 1'b0;
      19'b0000000001000000000: n6151 = n6144;
      19'b0000000000100000000: n6151 = n6143;
      19'b0000000000010000000: n6151 = 1'b0;
      19'b0000000000001000000: n6151 = n6142;
      19'b0000000000000100000: n6151 = n6141;
      19'b0000000000000010000: n6151 = 1'b0;
      19'b0000000000000001000: n6151 = n6140;
      19'b0000000000000000100: n6151 = n6139;
      19'b0000000000000000010: n6151 = 1'b0;
      19'b0000000000000000001: n6151 = 1'b0;
      default: n6151 = n6149;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6152 = n5727[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6153 = n5730[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6154 = n5735[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6155 = n5740[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6156 = n5747[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6157 = n5753[10]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6162 = xcsr_rdata_i[26]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6164 = 1'b0;
      19'b0100000000000000000: n6164 = 1'b0;
      19'b0010000000000000000: n6164 = 1'b0;
      19'b0001000000000000000: n6164 = 1'b0;
      19'b0000100000000000000: n6164 = 1'b0;
      19'b0000010000000000000: n6164 = 1'b0;
      19'b0000001000000000000: n6164 = 1'b0;
      19'b0000000100000000000: n6164 = 1'b0;
      19'b0000000010000000000: n6164 = 1'b0;
      19'b0000000001000000000: n6164 = n6157;
      19'b0000000000100000000: n6164 = n6156;
      19'b0000000000010000000: n6164 = 1'b0;
      19'b0000000000001000000: n6164 = n6155;
      19'b0000000000000100000: n6164 = n6154;
      19'b0000000000000010000: n6164 = 1'b0;
      19'b0000000000000001000: n6164 = n6153;
      19'b0000000000000000100: n6164 = n6152;
      19'b0000000000000000010: n6164 = 1'b0;
      19'b0000000000000000001: n6164 = 1'b0;
      default: n6164 = n6162;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6165 = n5727[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6166 = n5730[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6167 = n5735[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6168 = n5740[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6169 = n5747[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6170 = n5753[11]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6175 = xcsr_rdata_i[27]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6177 = 1'b0;
      19'b0100000000000000000: n6177 = 1'b0;
      19'b0010000000000000000: n6177 = 1'b0;
      19'b0001000000000000000: n6177 = 1'b0;
      19'b0000100000000000000: n6177 = 1'b0;
      19'b0000010000000000000: n6177 = 1'b0;
      19'b0000001000000000000: n6177 = 1'b0;
      19'b0000000100000000000: n6177 = 1'b0;
      19'b0000000010000000000: n6177 = 1'b0;
      19'b0000000001000000000: n6177 = n6170;
      19'b0000000000100000000: n6177 = n6169;
      19'b0000000000010000000: n6177 = 1'b0;
      19'b0000000000001000000: n6177 = n6168;
      19'b0000000000000100000: n6177 = n6167;
      19'b0000000000000010000: n6177 = 1'b0;
      19'b0000000000000001000: n6177 = n6166;
      19'b0000000000000000100: n6177 = n6165;
      19'b0000000000000000010: n6177 = 1'b0;
      19'b0000000000000000001: n6177 = 1'b0;
      default: n6177 = n6175;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6178 = n5727[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6179 = n5730[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6180 = n5735[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6181 = n5740[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6182 = n5747[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6183 = n5753[12]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6188 = xcsr_rdata_i[28]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6190 = 1'b0;
      19'b0100000000000000000: n6190 = 1'b1;
      19'b0010000000000000000: n6190 = 1'b0;
      19'b0001000000000000000: n6190 = 1'b0;
      19'b0000100000000000000: n6190 = 1'b0;
      19'b0000010000000000000: n6190 = 1'b0;
      19'b0000001000000000000: n6190 = 1'b0;
      19'b0000000100000000000: n6190 = 1'b0;
      19'b0000000010000000000: n6190 = 1'b0;
      19'b0000000001000000000: n6190 = n6183;
      19'b0000000000100000000: n6190 = n6182;
      19'b0000000000010000000: n6190 = 1'b0;
      19'b0000000000001000000: n6190 = n6181;
      19'b0000000000000100000: n6190 = n6180;
      19'b0000000000000010000: n6190 = 1'b0;
      19'b0000000000000001000: n6190 = n6179;
      19'b0000000000000000100: n6190 = n6178;
      19'b0000000000000000010: n6190 = 1'b0;
      19'b0000000000000000001: n6190 = 1'b0;
      default: n6190 = n6188;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6191 = n5727[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6192 = n5730[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6193 = n5735[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6194 = n5740[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6195 = n5747[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6196 = n5753[13]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6201 = xcsr_rdata_i[29]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6203 = 1'b0;
      19'b0100000000000000000: n6203 = 1'b0;
      19'b0010000000000000000: n6203 = 1'b0;
      19'b0001000000000000000: n6203 = 1'b0;
      19'b0000100000000000000: n6203 = 1'b0;
      19'b0000010000000000000: n6203 = 1'b0;
      19'b0000001000000000000: n6203 = 1'b0;
      19'b0000000100000000000: n6203 = 1'b0;
      19'b0000000010000000000: n6203 = 1'b0;
      19'b0000000001000000000: n6203 = n6196;
      19'b0000000000100000000: n6203 = n6195;
      19'b0000000000010000000: n6203 = 1'b0;
      19'b0000000000001000000: n6203 = n6194;
      19'b0000000000000100000: n6203 = n6193;
      19'b0000000000000010000: n6203 = 1'b0;
      19'b0000000000000001000: n6203 = n6192;
      19'b0000000000000000100: n6203 = n6191;
      19'b0000000000000000010: n6203 = 1'b0;
      19'b0000000000000000001: n6203 = 1'b0;
      default: n6203 = n6201;
    endcase
  assign n6204 = n5721[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6205 = n5727[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6206 = n5730[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6207 = n5735[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6208 = n5740[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6209 = n5747[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6210 = n5753[14]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6215 = xcsr_rdata_i[30]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6217 = 1'b0;
      19'b0100000000000000000: n6217 = 1'b0;
      19'b0010000000000000000: n6217 = 1'b0;
      19'b0001000000000000000: n6217 = 1'b0;
      19'b0000100000000000000: n6217 = 1'b0;
      19'b0000010000000000000: n6217 = 1'b0;
      19'b0000001000000000000: n6217 = 1'b0;
      19'b0000000100000000000: n6217 = 1'b0;
      19'b0000000010000000000: n6217 = 1'b0;
      19'b0000000001000000000: n6217 = n6210;
      19'b0000000000100000000: n6217 = n6209;
      19'b0000000000010000000: n6217 = 1'b0;
      19'b0000000000001000000: n6217 = n6208;
      19'b0000000000000100000: n6217 = n6207;
      19'b0000000000000010000: n6217 = 1'b0;
      19'b0000000000000001000: n6217 = n6206;
      19'b0000000000000000100: n6217 = n6205;
      19'b0000000000000000010: n6217 = n6204;
      19'b0000000000000000001: n6217 = 1'b0;
      default: n6217 = n6215;
    endcase
  assign n6218 = n5721[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1209:44 */
  assign n6219 = n5727[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1212:30 */
  assign n6220 = n5730[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1223:30 */
  assign n6221 = n5735[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1226:48 */
  assign n6222 = n5740[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1233:30 */
  assign n6223 = n5747[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1239:47 */
  assign n6224 = n5753[15]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:18:8 */
  assign n6229 = xcsr_rdata_i[31]; // extract
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1181:9 */
  always @*
    case (n5840)
      19'b1000000000000000000: n6231 = 1'b0;
      19'b0100000000000000000: n6231 = 1'b0;
      19'b0010000000000000000: n6231 = 1'b0;
      19'b0001000000000000000: n6231 = 1'b0;
      19'b0000100000000000000: n6231 = 1'b0;
      19'b0000010000000000000: n6231 = 1'b0;
      19'b0000001000000000000: n6231 = 1'b0;
      19'b0000000100000000000: n6231 = 1'b0;
      19'b0000000010000000000: n6231 = 1'b0;
      19'b0000000001000000000: n6231 = n6224;
      19'b0000000000100000000: n6231 = n6223;
      19'b0000000000010000000: n6231 = n5743;
      19'b0000000000001000000: n6231 = n6222;
      19'b0000000000000100000: n6231 = n6221;
      19'b0000000000000010000: n6231 = 1'b0;
      19'b0000000000000001000: n6231 = n6220;
      19'b0000000000000000100: n6231 = n6219;
      19'b0000000000000000010: n6231 = n6218;
      19'b0000000000000000001: n6231 = 1'b0;
      default: n6231 = n6229;
    endcase
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:7 */
  assign n6232 = {n6231, n6217, n6203, n6190, n6177, n6164, n6151, n6138, n6125, n6112, n6099, n6086, n6073, n6060, n6047, n6034, n6021, n6010, n5999, n5988, n5977, n5966, n5955, n5944, n5933, n5922, n5911, n5900, n5888, n5876, n5864, n5852};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1180:7 */
  assign n6234 = n5693 ? n6232 : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:106:16 */
  assign n6240 = {n3788, n3786, n3784};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:107:16 */
  assign n6241 = {n3164, n3824, n3823, n3821, n3819, n3838, n3817, n3816, n3815, n3813, n3811, n3809, n3807, n3255, n3806, n3805, n3804, n3802, n3800, n3832, n3798, n3796, n3829, n3794, n3827, n3792};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:114:10 */
  assign n6242 = {n5292, n5290};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:159:10 */
  assign n6244 = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:164:10 */
  assign n6245 = {n4710, n4728, n4740};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:166:10 */
  assign n6246 = {n4063, n4057, n4051, n4043, n4034, n4028, n4019, n4011, n4005};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:71:5 */
  assign n6247 = {n4000, exc_fire, env_enter, n3999, n3998, n3997, n3996, n3995, cnt_event, csr_wdata, n3994, n3993, n3992, n3991, n3989, n3985, n3979, n3974, n3973, n3972, n3971, n3953, n3935, n3917, n3916, n3915, n3914, n3913, n3912, n3911, n3910, n3909, n3908, n3907, n3877, n3874, n3871, n3868, n3866, n3861};
  /*# ../../rtl/core/neorv32_cpu_control.vhd:204:5 */
  always @(posedge clk_i or posedge n3138)
    if (n3138)
      n6248 <= n3148;
    else
      n6248 <= exec_nxt;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:204:5 */
  always @(posedge clk_i or posedge n3138)
    if (n3138)
      n6249 <= 262'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n6249 <= ctrl_nxt;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n4959)
    if (n4959)
      n6250 <= 12'b000000000000;
    else
      n6250 <= n5137;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n4959)
    if (n4959)
      n6251 <= 20'b00000000000000000000;
    else
      n6251 <= n4963;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:802:5 */
  always @(posedge clk_i or posedge n4959)
    if (n4959)
      n6252 <= 20'b00000000000000000000;
    else
      n6252 <= n5140;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:840:5 */
  always @(posedge clk_i or posedge n5168)
    if (n5168)
      n6253 <= 1'b0;
    else
      n6253 <= n5186;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1018:5 */
  always @(posedge clk_i or posedge n5441)
    if (n5441)
      n6254 <= n5687;
    else
      n6254 <= n5685;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:1178:5 */
  always @(posedge clk_i or posedge n5691)
    if (n5691)
      n6255 <= 32'b00000000000000000000000000000000;
    else
      n6255 <= n6234;
  /*# ../../rtl/core/neorv32_cpu_control.vhd:774:5 */
  always @(posedge clk_i or posedge n4932)
    if (n4932)
      n6256 <= 10'b0000000000;
    else
      n6256 <= n4940;
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
  wire [261:0] n2798;
  wire [4:0] n2800;
  wire [31:0] n2801;
  wire [31:0] n2802;
  wire [3:0] n2803;
  wire n2804;
  wire n2805;
  wire n2806;
  wire [3:0] n2807;
  wire n2808;
  wire n2809;
  wire [33:0] n2810;
  wire n2814;
  wire [31:0] n2815;
  wire [15:0] n2816;
  wire n2817;
  wire n2818;
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
  wire n2820;
  wire [1:0] n2827;
  wire [31:0] n2829;
  wire n2830;
  wire n2831;
  wire n2834;
  wire n2836;
  wire [1:0] n2839;
  wire [1:0] n2840;
  wire [1:0] n2841;
  wire n2843;
  wire n2844;
  wire [31:0] n2845;
  wire [31:0] n2847;
  wire [29:0] n2849;
  wire n2850;
  wire [1:0] n2853;
  wire [31:0] n2854;
  wire [1:0] n2855;
  wire [1:0] n2856;
  wire [31:0] n2857;
  wire [31:0] n2858;
  wire n2860;
  wire [2:0] n2861;
  reg [1:0] n2863;
  reg n2865;
  wire [31:0] n2866;
  reg [31:0] n2868;
  wire n2869;
  reg n2871;
  wire n2872;
  reg n2874;
  wire [36:0] n2875;
  wire [36:0] n2877;
  wire n2880;
  wire n2881;
  wire n2882;
  wire [29:0] n2883;
  wire [31:0] n2885;
  wire n2886;
  wire n2887;
  wire [2:0] n2889;
  wire n2890;
  wire [3:0] n2891;
  wire [4:0] n2893;
  wire [29:0] n2894;
  wire [31:0] n2896;
  wire [1:0] n2898;
  wire n2900;
  wire n2902;
  wire n2903;
  wire n2904;
  wire n2913;
  wire n2914;
  wire [15:0] n2915;
  wire [16:0] n2916;
  wire n2917;
  wire n2918;
  wire [15:0] n2919;
  wire [16:0] n2920;
  wire [1:0] n2922;
  wire n2924;
  wire n2925;
  wire n2926;
  wire n2927;
  wire n2928;
  wire n2930;
  wire n2931;
  wire n2932;
  wire [1:0] n2935;
  wire n2937;
  wire n2938;
  wire n2939;
  wire n2940;
  wire [16:0] n2942;
  wire n2943;
  wire \prefetch_buffer[0]_ipb_inst_n2944 ;
  wire n2945;
  wire [16:0] \prefetch_buffer[0]_ipb_inst_n2946 ;
  wire \prefetch_buffer[0]_ipb_inst_n2947 ;
  wire [16:0] n2954;
  wire n2955;
  wire \prefetch_buffer[1]_ipb_inst_n2956 ;
  wire n2957;
  wire [16:0] \prefetch_buffer[1]_ipb_inst_n2958 ;
  wire \prefetch_buffer[1]_ipb_inst_n2959 ;
  wire [15:0] n2967;
  wire n2968;
  wire [15:0] n2969;
  wire [15:0] n2970;
  wire n2972;
  wire n2974;
  wire n2975;
  wire n2976;
  wire n2977;
  wire n2978;
  wire n2979;
  wire n2980;
  wire n2981;
  wire n2982;
  wire n2983;
  wire n2989;
  wire [1:0] n2990;
  wire n2992;
  wire n2993;
  wire n2994;
  wire n2996;
  wire n2998;
  wire n2999;
  wire n3000;
  wire n3001;
  wire n3002;
  wire n3003;
  wire n3004;
  wire n3005;
  wire n3006;
  wire [15:0] n3007;
  wire [15:0] n3008;
  wire [31:0] n3009;
  wire [1:0] n3011;
  wire [1:0] n3012;
  wire [31:0] n3013;
  wire [1:0] n3014;
  wire n3016;
  wire [1:0] n3017;
  wire [1:0] n3018;
  wire [1:0] n3019;
  wire [1:0] n3020;
  wire n3022;
  wire n3023;
  wire n3025;
  wire n3026;
  wire n3028;
  wire n3029;
  wire n3030;
  wire n3031;
  wire n3032;
  wire n3033;
  wire n3034;
  wire n3035;
  wire n3036;
  wire [15:0] n3037;
  wire [15:0] n3038;
  wire [31:0] n3039;
  wire [1:0] n3041;
  wire [1:0] n3042;
  wire [31:0] n3043;
  wire [1:0] n3044;
  wire n3046;
  wire [1:0] n3047;
  wire [1:0] n3048;
  wire [1:0] n3049;
  wire [31:0] n3050;
  wire [1:0] n3051;
  wire n3053;
  wire n3056;
  wire [1:0] n3058;
  wire n3060;
  wire n3061;
  wire n3062;
  wire n3063;
  wire n3064;
  wire n3065;
  wire n3066;
  wire n3067;
  wire n3068;
  wire [33:0] n3069;
  wire [33:0] n3070;
  wire [1:0] n3071;
  wire [1:0] n3072;
  wire [1:0] n3073;
  wire [1:0] n3074;
  wire [81:0] n3075;
  wire [50:0] n3076;
  reg [36:0] n3077;
  reg n3078;
  assign \ibus_req_o[meta]  = n2800; //(module output)
  assign \ibus_req_o[addr]  = n2801; //(module output)
  assign \ibus_req_o[data]  = n2802; //(module output)
  assign \ibus_req_o[ben]  = n2803; //(module output)
  assign \ibus_req_o[stb]  = n2804; //(module output)
  assign \ibus_req_o[rw]  = n2805; //(module output)
  assign \ibus_req_o[amo]  = n2806; //(module output)
  assign \ibus_req_o[amoop]  = n2807; //(module output)
  assign \ibus_req_o[burst]  = n2808; //(module output)
  assign \ibus_req_o[lock]  = n2809; //(module output)
  assign pmp_addr_o = n2885; //(module output)
  assign pmp_priv_o = n2886; //(module output)
  assign \frontend_o[valid]  = n2814; //(module output)
  assign \frontend_o[i32]  = n2815; //(module output)
  assign \frontend_o[i16]  = n2816; //(module output)
  assign \frontend_o[compr]  = n2817; //(module output)
  assign \frontend_o[fault]  = n2818; //(module output)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2798 = {\ctrl_i[cpu_debug] , \ctrl_i[cpu_sync_exc] , \ctrl_i[cpu_trap] , \ctrl_i[cpu_priv] , \ctrl_i[ir_rvc] , \ctrl_i[ir_opcode] , \ctrl_i[ir_funct12] , \ctrl_i[ir_funct3] , \ctrl_i[cnt_event] , \ctrl_i[csr_wdata] , \ctrl_i[csr_addr] , \ctrl_i[csr_re] , \ctrl_i[csr_we] , \ctrl_i[lsu_fence] , \ctrl_i[lsu_priv] , \ctrl_i[lsu_mi_en] , \ctrl_i[lsu_mo_en] , \ctrl_i[lsu_wr] , \ctrl_i[lsu_rd] , \ctrl_i[lsu_req] , \ctrl_i[alu_cp_fpu] , \ctrl_i[alu_cp_cfu] , \ctrl_i[alu_cp_alu] , \ctrl_i[alu_imm] , \ctrl_i[alu_unsigned] , \ctrl_i[alu_opb_mux] , \ctrl_i[alu_opa_mux] , \ctrl_i[alu_sub] , \ctrl_i[alu_op] , \ctrl_i[rf_zero] , \ctrl_i[rf_rd] , \ctrl_i[rf_rs2] , \ctrl_i[rf_rs1] , \ctrl_i[rf_wb_en] , \ctrl_i[pc_ret] , \ctrl_i[pc_nxt] , \ctrl_i[pc_cur] , \ctrl_i[if_fence] , \ctrl_i[if_ready] , \ctrl_i[if_reset] };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2800 = n3075[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2801 = n3075[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2802 = n3075[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2803 = n3075[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2804 = n3075[73]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2805 = n3075[74]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2806 = n3075[75]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2807 = n3075[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2808 = n3075[80]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2809 = n3075[81]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2810 = {\ibus_rsp_i[data] , \ibus_rsp_i[err] , \ibus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2814 = n3076[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2815 = n3076[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2816 = n3076[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2817 = n3076[49]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:22:8 */
  assign n2818 = n3076[50]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign fetch = n3077; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:79:10 */
  assign restart = n2882; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:10 */
  assign ipb_wdata = n3069; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:21 */
  assign ipb_rdata = n3070; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:10 */
  assign ipb_we = n3071; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:21 */
  assign ipb_re = n3072; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:10 */
  assign ipb_free = n3073; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:21 */
  assign ipb_avail = n3074; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:10 */
  assign align_q = n3078; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:19 */
  assign align_set = n3053; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:88:30 */
  assign align_clr = n3056; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:89:10 */
  assign issue_valid = n3058; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:90:10 */
  assign cmd16 = n2969; // (signal)
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:103:16 */
  assign n2820 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:18 */
  assign n2827 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:115:33 */
  assign n2829 = n2798[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:116:33 */
  assign n2830 = n2798[258]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:117:33 */
  assign n2831 = n2798[261]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:112:9 */
  assign n2834 = n2827 == 2'b00;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:123:24 */
  assign n2836 = ipb_free == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2839 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:125:11 */
  assign n2840 = restart ? 2'b00 : n2839;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:123:11 */
  assign n2841 = n2836 ? 2'b10 : n2840;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:120:9 */
  assign n2843 = n2827 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:26 */
  assign n2844 = n2810[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:133:63 */
  assign n2845 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:133:69 */
  assign n2847 = n2845 + 32'b00000000000000000000000000000100;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2849 = n2847[31:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2850 = n2847[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:135:13 */
  assign n2853 = restart ? 2'b00 : 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2854 = {n2849, 1'b0, n2850};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2855 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2856 = n2844 ? n2853 : n2855;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2857 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:132:11 */
  assign n2858 = n2844 ? n2854 : n2857;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:129:9 */
  assign n2860 = n2827 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  assign n2861 = {n2860, n2843, n2834};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2861)
      3'b100: n2863 = n2856;
      3'b010: n2863 = n2841;
      3'b001: n2863 = 2'b01;
      default: n2863 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2861)
      3'b100: n2865 = restart;
      3'b010: n2865 = restart;
      3'b001: n2865 = 1'b0;
      default: n2865 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2866 = fetch[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2861)
      3'b100: n2868 = n2858;
      3'b010: n2868 = n2866;
      3'b001: n2868 = n2829;
      default: n2868 = 32'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2869 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2861)
      3'b100: n2871 = n2869;
      3'b010: n2871 = n2869;
      3'b001: n2871 = n2830;
      default: n2871 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:76:10 */
  assign n2872 = fetch[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:110:7 */
  always @*
    case (n2861)
      3'b100: n2874 = n2872;
      3'b010: n2874 = n2872;
      3'b001: n2874 = n2831;
      default: n2874 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:109:5 */
  assign n2875 = {n2874, n2871, n2868, n2865, n2863};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:103:5 */
  assign n2877 = {1'b0, 1'b1, 32'b00000000000000000000000000000000, 1'b1, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:20 */
  assign n2880 = fetch[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:36 */
  assign n2881 = n2798[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:147:26 */
  assign n2882 = n2880 | n2881;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:150:27 */
  assign n2883 = fetch[34:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:150:41 */
  assign n2885 = {n2883, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:151:23 */
  assign n2886 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:74 */
  assign n2887 = fetch[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:66 */
  assign n2889 = {2'b00, n2887};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:88 */
  assign n2890 = fetch[35]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:80 */
  assign n2891 = {n2889, n2890};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:154:93 */
  assign n2893 = {n2891, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:155:33 */
  assign n2894 = fetch[34:5]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:155:47 */
  assign n2896 = {n2894, 2'b00};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:39 */
  assign n2898 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:45 */
  assign n2900 = n2898 == 2'b01;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:72 */
  assign n2902 = ipb_free == 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:58 */
  assign n2903 = n2902 & n2900;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:156:27 */
  assign n2904 = n2903 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:31 */
  assign n2913 = n2810[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:35 */
  assign n2914 = n2913 | pmp_err_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:66 */
  assign n2915 = n2810[17:2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:166:49 */
  assign n2916 = {n2914, n2915};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:31 */
  assign n2917 = n2810[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:35 */
  assign n2918 = n2917 | pmp_err_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:66 */
  assign n2919 = n2810[33:18]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:167:49 */
  assign n2920 = {n2918, n2919};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:32 */
  assign n2922 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:38 */
  assign n2924 = n2922 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:67 */
  assign n2925 = n2810[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:51 */
  assign n2926 = n2925 & n2924;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:94 */
  assign n2927 = fetch[4]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:98 */
  assign n2928 = ~n2927;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:105 */
  assign n2930 = n2928 | 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:78 */
  assign n2931 = n2930 & n2926;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:170:20 */
  assign n2932 = n2931 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:32 */
  assign n2935 = fetch[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:38 */
  assign n2937 = n2935 == 2'b10;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:67 */
  assign n2938 = n2810[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:51 */
  assign n2939 = n2938 & n2937;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:171:20 */
  assign n2940 = n2939 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:188:27 */
  assign n2942 = ipb_wdata[33:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:189:24 */
  assign n2943 = ipb_we[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:192:24 */
  assign n2945 = ipb_re[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:177:5 */
  neorv32_cpu_frontend_ipb_Bneorv32_cpu_frontend_ipb_rtl_Lneorv32_1_17 \prefetch_buffer[0]_ipb_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(restart),
    .wdata_i(n2942),
    .we_i(n2943),
    .re_i(n2945),
    .free_o(\prefetch_buffer[0]_ipb_inst_n2944 ),
    .rdata_o(\prefetch_buffer[0]_ipb_inst_n2946 ),
    .avail_o(\prefetch_buffer[0]_ipb_inst_n2947 ));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:188:27 */
  assign n2954 = ipb_wdata[16:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:189:24 */
  assign n2955 = ipb_we[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:192:24 */
  assign n2957 = ipb_re[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:177:5 */
  neorv32_cpu_frontend_ipb_Bneorv32_cpu_frontend_ipb_rtl_Lneorv32_1_17 \prefetch_buffer[1]_ipb_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(restart),
    .wdata_i(n2954),
    .we_i(n2955),
    .re_i(n2957),
    .free_o(\prefetch_buffer[1]_ipb_inst_n2956 ),
    .rdata_o(\prefetch_buffer[1]_ipb_inst_n2958 ),
    .avail_o(\prefetch_buffer[1]_ipb_inst_n2959 ));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:207:5 */
  neorv32_cpu_decompressor_Bneorv32_cpu_decompressor_rtl_Lneorv32_1489f923c4dca729178b3e3233458550d8dddf29 issue_enabled_neorv32_cpu_decompressor_inst (
    .instr_i(cmd16),
    .instr_o(cmd32));
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:26 */
  assign n2967 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:54 */
  assign n2968 = ~align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:40 */
  assign n2969 = n2968 ? n2967 : n2970;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:218:78 */
  assign n2970 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:225:18 */
  assign n2972 = ~rstn_i;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:228:19 */
  assign n2974 = fetch[2]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:229:35 */
  assign n2975 = n2798[36]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:22 */
  assign n2976 = ipb_re[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:43 */
  assign n2977 = ipb_re[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:33 */
  assign n2978 = n2976 | n2977;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:36 */
  assign n2979 = ~align_clr;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:31 */
  assign n2980 = align_q & n2979;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:231:52 */
  assign n2981 = n2980 | align_set;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:230:9 */
  assign n2982 = n2978 ? n2981 : align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:228:9 */
  assign n2983 = n2974 ? n2975 : n2982;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:19 */
  assign n2989 = ~align_q;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:25 */
  assign n2990 = ipb_rdata[18:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:38 */
  assign n2992 = n2990 != 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:244:40 */
  assign n2993 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:245:40 */
  assign n2994 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:247:43 */
  assign n2996 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:40 */
  assign n2998 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:57 */
  assign n2999 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:251:44 */
  assign n3000 = n2998 & n2999;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:40 */
  assign n3001 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:57 */
  assign n3002 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:252:44 */
  assign n3003 = n3001 & n3002;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:43 */
  assign n3004 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:63 */
  assign n3005 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:253:48 */
  assign n3006 = n3004 | n3005;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:43 */
  assign n3007 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:71 */
  assign n3008 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:254:57 */
  assign n3009 = {n3007, n3008};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3011 = {n3006, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3012 = {n2996, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3013 = n2992 ? cmd32 : n3009;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3014 = n2992 ? n3012 : n3011;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3016 = n2992 ? n2993 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3017 = {n3003, n3000};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3018 = {1'b0, n2994};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:243:9 */
  assign n3019 = n2992 ? n3018 : n3017;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:25 */
  assign n3020 = ipb_rdata[1:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:38 */
  assign n3022 = n3020 != 2'b11;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:260:40 */
  assign n3023 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:262:40 */
  assign n3025 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:263:43 */
  assign n3026 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:40 */
  assign n3028 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:57 */
  assign n3029 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:267:44 */
  assign n3030 = n3028 & n3029;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:40 */
  assign n3031 = ipb_avail[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:57 */
  assign n3032 = ipb_avail[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:268:44 */
  assign n3033 = n3031 & n3032;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:43 */
  assign n3034 = ipb_rdata[33]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:63 */
  assign n3035 = ipb_rdata[16]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:269:48 */
  assign n3036 = n3034 | n3035;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:43 */
  assign n3037 = ipb_rdata[32:17]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:71 */
  assign n3038 = ipb_rdata[15:0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:270:57 */
  assign n3039 = {n3037, n3038};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3041 = {n3036, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3042 = {n3026, 1'b1};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3043 = n3022 ? cmd32 : n3039;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3044 = n3022 ? n3042 : n3041;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3046 = n3022 ? n3023 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3047 = {n3033, n3030};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3048 = {n3025, 1'b0};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:259:9 */
  assign n3049 = n3022 ? n3048 : n3047;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3050 = n2989 ? n3013 : n3043;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3051 = n2989 ? n3014 : n3044;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3053 = n2989 ? n3016 : 1'b0;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3056 = n2989 ? 1'b0 : n3046;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:242:7 */
  assign n3058 = n2989 ? n3019 : n3049;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:36 */
  assign n3060 = issue_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:54 */
  assign n3061 = issue_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:277:40 */
  assign n3062 = n3060 | n3061;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:29 */
  assign n3063 = issue_valid[0]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:44 */
  assign n3064 = n2798[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:280:33 */
  assign n3065 = n3063 & n3064;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:29 */
  assign n3066 = issue_valid[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:44 */
  assign n3067 = n2798[1]; // extract
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:281:33 */
  assign n3068 = n3066 & n3067;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:10 */
  assign n3069 = {n2916, n2920};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:83:21 */
  assign n3070 = {\prefetch_buffer[0]_ipb_inst_n2946 , \prefetch_buffer[1]_ipb_inst_n2958 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:10 */
  assign n3071 = {n2940, n2932};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:84:21 */
  assign n3072 = {n3068, n3065};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:10 */
  assign n3073 = {\prefetch_buffer[1]_ipb_inst_n2956 , \prefetch_buffer[0]_ipb_inst_n2944 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:85:21 */
  assign n3074 = {\prefetch_buffer[1]_ipb_inst_n2959 , \prefetch_buffer[0]_ipb_inst_n2947 };
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:35:5 */
  assign n3075 = {1'b0, 1'b0, 4'b0000, 1'b0, 1'b0, n2904, 4'b1111, 32'b00000000000000000000000000000000, n2896, n2893};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:42:5 */
  assign n3076 = {n3051, cmd16, n3050, n3062};
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:109:5 */
  always @(posedge clk_i or posedge n2820)
    if (n2820)
      n3077 <= n2877;
    else
      n3077 <= n2875;
  /*# ../../rtl/core/neorv32_cpu_frontend.vhd:227:7 */
  always @(posedge clk_i or posedge n2972)
    if (n2972)
      n3078 <= 1'b0;
    else
      n3078 <= n2983;
endmodule

module neorv32_sysinfo_Bneorv32_sysinfo_rtl_Lneorv32_16_2048_1_100000000_2_16384_16384_4_4_64_3592969d31b6bbf38f334a2a4d979986a3a69b1a
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
  wire [81:0] n2592;
  wire n2594;
  wire n2595;
  wire [31:0] n2596;
  wire [127:0] sysinfo;
  wire n2598;
  wire n2601;
  wire n2602;
  wire n2603;
  wire [1:0] n2604;
  wire n2606;
  wire n2607;
  wire [31:0] n2608;
  wire [7:0] n2617;
  wire [7:0] n2621;
  wire n2629;
  wire n2633;
  wire n2636;
  wire n2639;
  wire n2643;
  wire n2647;
  wire n2651;
  wire n2655;
  wire n2662;
  wire n2666;
  wire n2670;
  wire n2674;
  wire n2678;
  wire n2682;
  wire n2686;
  wire n2690;
  wire n2694;
  wire n2698;
  wire n2702;
  wire n2706;
  wire n2710;
  wire n2714;
  wire n2718;
  wire n2722;
  wire n2726;
  wire n2730;
  wire n2734;
  wire n2738;
  wire n2742;
  wire [3:0] n2746;
  wire [3:0] n2750;
  wire [3:0] n2754;
  wire [3:0] n2758;
  wire n2762;
  wire n2766;
  wire n2768;
  wire [1:0] n2769;
  wire [1:0] n2772;
  wire n2776;
  wire [1:0] n2777;
  wire n2779;
  wire n2780;
  wire n2783;
  wire [33:0] n2784;
  wire [33:0] n2786;
  wire [127:0] n2792;
  reg [33:0] n2793;
  wire [31:0] n2794;
  wire [31:0] n2795;
  reg [31:0] n2796;
  wire [31:0] n2797;
  assign \bus_rsp_o[ack]  = n2594; //(module output)
  assign \bus_rsp_o[err]  = n2595; //(module output)
  assign \bus_rsp_o[data]  = n2596; //(module output)
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2592 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2594 = n2793[0]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2595 = n2793[1]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:18:8 */
  assign n2596 = n2793[33:2]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:85:10 */
  assign sysinfo = n2792; // (signal)
  /*# ../../rtl/core/neorv32_sysinfo.vhd:93:16 */
  assign n2598 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:21 */
  assign n2601 = n2592[73]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:47 */
  assign n2602 = n2592[74]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:32 */
  assign n2603 = n2602 & n2601;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:76 */
  assign n2604 = n2592[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:89 */
  assign n2606 = n2604 == 2'b00;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:96:57 */
  assign n2607 = n2606 & n2603;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:97:33 */
  assign n2608 = n2592[68:37]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:104:83 */
  assign n2617 = 1'b1 ? 8'b00001110 : 8'b00000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:105:83 */
  assign n2621 = 1'b1 ? 8'b00001110 : 8'b00000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:113:25 */
  assign n2629 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:114:25 */
  assign n2633 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:115:25 */
  assign n2636 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:116:25 */
  assign n2639 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:117:25 */
  assign n2643 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:118:25 */
  assign n2647 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:119:25 */
  assign n2651 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:120:25 */
  assign n2655 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:124:25 */
  assign n2662 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:125:25 */
  assign n2666 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:126:25 */
  assign n2670 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:127:25 */
  assign n2674 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:128:25 */
  assign n2678 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:129:25 */
  assign n2682 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:130:25 */
  assign n2686 = 1'b1 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:131:25 */
  assign n2690 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:132:25 */
  assign n2694 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:133:25 */
  assign n2698 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:134:25 */
  assign n2702 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:135:25 */
  assign n2706 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:136:25 */
  assign n2710 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:137:25 */
  assign n2714 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:138:25 */
  assign n2718 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:139:25 */
  assign n2722 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:140:25 */
  assign n2726 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:141:25 */
  assign n2730 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:142:25 */
  assign n2734 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:143:25 */
  assign n2738 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:144:25 */
  assign n2742 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:148:81 */
  assign n2746 = 1'b0 ? 4'b0110 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:149:81 */
  assign n2750 = 1'b0 ? 4'b0010 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:150:81 */
  assign n2754 = 1'b0 ? 4'b0010 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:151:45 */
  assign n2758 = 1'b0 ? 4'b1111 : 4'b0000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:152:35 */
  assign n2762 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:159:16 */
  assign n2766 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:21 */
  assign n2768 = n2592[73]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:69 */
  assign n2769 = n2592[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:35 */
  assign n2772 = 2'b11 - n2769;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:23 */
  assign n2776 = n2592[74]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:52 */
  assign n2777 = n2592[8:7]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:65 */
  assign n2779 = n2777 != 2'b00;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:33 */
  assign n2780 = n2779 & n2776;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:166:9 */
  assign n2783 = n2780 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:7 */
  assign n2784 = {n2797, n2783, 1'b1};
  /*# ../../rtl/core/neorv32_sysinfo.vhd:163:7 */
  assign n2786 = n2768 ? n2784 : 34'b0000000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:85:10 */
  assign n2792 = {n2796, 5'b01011, 5'b00100, 2'b10, 4'b0001, n2621, n2617, n2742, n2738, n2734, n2730, n2726, n2722, n2718, n2714, n2710, n2706, n2702, n2698, n2694, n2690, n2686, n2682, n2678, n2674, n2670, n2666, n2662, 1'b0, 1'b0, 1'b0, n2655, n2651, n2647, n2643, n2639, n2636, n2633, n2629, 15'b000000000000000, n2762, n2758, n2754, n2750, n2746};
  /*# ../../rtl/core/neorv32_sysinfo.vhd:161:5 */
  always @(posedge clk_i or posedge n2766)
    if (n2766)
      n2793 <= 34'b0000000000000000000000000000000000;
    else
      n2793 <= n2786;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  assign n2794 = sysinfo[127:96]; // extract
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  assign n2795 = n2607 ? n2608 : n2794;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:95:5 */
  always @(posedge clk_i or posedge n2598)
    if (n2598)
      n2796 <= 32'b00000101111101011110000100000000;
    else
      n2796 <= n2795;
  /*# ../../rtl/core/neorv32_sysinfo.vhd:164:35 */
  assign n2797 = sysinfo[n2772 * 32 +: 32]; //(Bmux)
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
  wire [81:0] n2136;
  wire n2138;
  wire n2139;
  wire [31:0] n2140;
  wire uart_clk;
  wire [19:0] ctrl;
  wire [28:0] tx;
  wire [28:0] rx;
  wire rx_overrun;
  wire [20:0] rx_fifo;
  wire [20:0] tx_fifo;
  wire n2145;
  wire n2156;
  localparam [31:0] n2158 = 32'b00000000000000000000000000000000;
  wire n2159;
  wire n2160;
  wire n2161;
  wire n2162;
  wire n2163;
  wire n2164;
  wire n2167;
  wire n2168;
  wire [2:0] n2169;
  wire [9:0] n2170;
  wire n2171;
  wire n2172;
  wire n2173;
  wire n2174;
  wire [19:0] n2175;
  wire n2177;
  wire n2178;
  wire n2179;
  wire n2180;
  wire n2183;
  wire n2184;
  wire [2:0] n2185;
  wire [9:0] n2186;
  wire n2187;
  wire n2188;
  wire n2189;
  wire n2190;
  wire n2191;
  wire n2192;
  wire n2193;
  wire n2194;
  wire n2195;
  wire n2196;
  wire n2197;
  wire n2198;
  wire n2199;
  wire [7:0] n2200;
  wire [15:0] n2203;
  wire [23:0] n2204;
  wire [1:0] n2205;
  wire [15:0] n2206;
  wire [15:0] n2207;
  wire [7:0] n2208;
  wire [7:0] n2209;
  wire [7:0] n2210;
  wire [1:0] n2211;
  wire [1:0] n2212;
  wire [23:0] n2213;
  wire [23:0] n2214;
  wire [23:0] n2215;
  wire [1:0] n2216;
  wire [1:0] n2217;
  wire n2218;
  wire [23:0] n2219;
  wire [23:0] n2220;
  wire [1:0] n2221;
  wire [1:0] n2222;
  wire [5:0] n2224;
  wire n2225;
  wire [33:0] n2226;
  wire [19:0] n2231;
  wire [2:0] n2234;
  wire \tx_fifo_inst.free_o ;
  wire [7:0] \tx_fifo_inst.rdata_o ;
  wire \tx_fifo_inst.avail_o ;
  wire n2238;
  wire [7:0] n2239;
  wire n2240;
  wire n2242;
  wire n2246;
  wire n2247;
  wire n2248;
  wire n2249;
  wire n2250;
  wire [7:0] n2252;
  wire n2254;
  wire n2255;
  wire n2256;
  wire n2257;
  wire n2258;
  wire n2259;
  wire n2261;
  wire \rx_fifo_inst.free_o ;
  wire [7:0] \rx_fifo_inst.rdata_o ;
  wire \rx_fifo_inst.avail_o ;
  wire n2262;
  wire [7:0] n2263;
  wire n2264;
  wire n2266;
  wire n2270;
  wire n2271;
  wire n2272;
  wire n2273;
  wire n2274;
  wire [7:0] n2276;
  wire n2277;
  wire n2279;
  wire n2280;
  wire n2281;
  wire n2282;
  wire n2283;
  wire n2284;
  wire n2285;
  wire n2288;
  wire n2290;
  wire n2291;
  wire n2292;
  wire n2293;
  wire n2294;
  wire n2295;
  wire n2296;
  wire n2297;
  wire n2298;
  wire n2299;
  wire n2300;
  wire n2301;
  wire n2302;
  wire n2303;
  wire n2304;
  wire n2305;
  wire n2306;
  wire n2307;
  wire n2308;
  wire n2314;
  wire [1:0] n2322;
  wire [2:0] n2323;
  wire [2:0] n2324;
  wire [2:0] n2325;
  wire n2327;
  wire [1:0] n2328;
  wire [9:0] n2329;
  wire [7:0] n2331;
  wire [8:0] n2333;
  wire n2334;
  wire n2335;
  wire n2336;
  wire n2337;
  wire n2338;
  wire n2339;
  wire n2340;
  wire n2341;
  wire n2342;
  wire n2343;
  wire n2345;
  wire n2346;
  wire n2348;
  wire n2350;
  wire n2351;
  wire n2359;
  wire n2361;
  wire n2363;
  wire n2364;
  wire n2365;
  wire n2366;
  wire n2367;
  wire n2368;
  wire n2369;
  wire n2370;
  wire n2371;
  wire n2372;
  wire n2373;
  wire n2374;
  wire n2375;
  wire n2376;
  wire n2377;
  wire n2378;
  wire n2379;
  wire n2380;
  wire n2381;
  wire [9:0] n2382;
  wire [3:0] n2383;
  wire [3:0] n2385;
  wire [7:0] n2386;
  wire [8:0] n2388;
  wire [9:0] n2389;
  wire [9:0] n2391;
  wire [22:0] n2392;
  wire [12:0] n2393;
  wire [12:0] n2394;
  wire [12:0] n2395;
  wire [9:0] n2396;
  wire [9:0] n2397;
  wire [22:0] n2398;
  wire [22:0] n2399;
  wire [22:0] n2400;
  wire [3:0] n2401;
  wire n2403;
  wire n2406;
  wire n2407;
  wire n2408;
  wire n2410;
  wire [1:0] n2412;
  reg n2414;
  reg n2416;
  wire [8:0] n2417;
  wire [8:0] n2418;
  reg [8:0] n2419;
  wire [3:0] n2420;
  wire [3:0] n2421;
  reg [3:0] n2422;
  wire [9:0] n2423;
  wire [9:0] n2424;
  reg [9:0] n2425;
  reg n2426;
  wire [28:0] n2428;
  wire [28:0] n2432;
  wire n2436;
  wire [1:0] n2444;
  wire [2:0] n2445;
  wire [2:0] n2446;
  wire [2:0] n2447;
  wire n2449;
  wire [1:0] n2450;
  wire [8:0] n2451;
  wire [9:0] n2453;
  wire [1:0] n2455;
  wire n2457;
  wire n2459;
  wire n2460;
  wire n2462;
  wire n2464;
  wire n2472;
  wire n2474;
  wire n2476;
  wire n2477;
  wire n2478;
  wire n2479;
  wire n2480;
  wire n2481;
  wire n2482;
  wire n2483;
  wire n2484;
  wire n2485;
  wire n2486;
  wire n2487;
  wire n2488;
  wire n2489;
  wire n2490;
  wire n2491;
  wire n2492;
  wire n2493;
  wire n2494;
  wire [9:0] n2495;
  wire [3:0] n2496;
  wire [3:0] n2498;
  wire n2499;
  wire n2500;
  wire n2501;
  wire [7:0] n2502;
  wire [8:0] n2503;
  wire [9:0] n2504;
  wire [9:0] n2506;
  wire [22:0] n2507;
  wire [12:0] n2508;
  wire [12:0] n2509;
  wire [12:0] n2510;
  wire [9:0] n2511;
  wire [9:0] n2512;
  wire [22:0] n2513;
  wire [22:0] n2514;
  wire [22:0] n2515;
  wire [3:0] n2516;
  wire n2518;
  wire n2521;
  wire n2522;
  wire n2523;
  wire n2525;
  wire [1:0] n2527;
  reg n2528;
  wire [8:0] n2529;
  wire [8:0] n2530;
  reg [8:0] n2531;
  wire [3:0] n2532;
  wire [3:0] n2533;
  reg [3:0] n2534;
  wire [9:0] n2535;
  wire [9:0] n2536;
  reg [9:0] n2537;
  reg n2538;
  wire [28:0] n2539;
  wire [28:0] n2541;
  wire n2545;
  wire n2547;
  wire n2548;
  wire n2549;
  wire n2550;
  wire n2551;
  wire n2552;
  wire n2553;
  wire n2554;
  wire n2555;
  wire n2556;
  wire n2557;
  wire n2558;
  wire n2559;
  wire n2560;
  wire n2561;
  wire n2562;
  wire n2563;
  wire n2564;
  wire n2565;
  wire n2566;
  wire n2568;
  wire n2570;
  wire n2572;
  wire [20:0] n2580;
  wire [20:0] n2581;
  reg [33:0] n2582;
  reg n2583;
  reg n2584;
  reg n2585;
  wire [19:0] n2586;
  reg [19:0] n2587;
  reg [28:0] n2588;
  reg [28:0] n2589;
  reg n2590;
  wire n2591;
  assign \bus_rsp_o[ack]  = n2138; //(module output)
  assign \bus_rsp_o[err]  = n2139; //(module output)
  assign \bus_rsp_o[data]  = n2140; //(module output)
  assign uart_txd_o = n2583; //(module output)
  assign uart_rtsn_o = n2584; //(module output)
  assign irq_o = n2585; //(module output)
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2136 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2138 = n2582[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2139 = n2582[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:24:8 */
  assign n2140 = n2582[33:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:78:10 */
  assign uart_clk = n2591; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:92:10 */
  assign ctrl = n2587; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign tx = n2588; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign rx = n2589; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:104:10 */
  assign rx_overrun = n2590; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:112:10 */
  assign rx_fifo = n2580; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:112:19 */
  assign tx_fifo = n2581; // (signal)
  /*# ../../rtl/core/neorv32_uart.vhd:120:16 */
  assign n2145 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:133:35 */
  assign n2156 = n2136[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:21 */
  assign n2159 = n2136[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:23 */
  assign n2160 = n2136[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:29 */
  assign n2161 = n2136[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:33 */
  assign n2162 = ~n2161;
  /*# ../../rtl/core/neorv32_uart.vhd:140:49 */
  assign n2163 = n2136[37]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:141:49 */
  assign n2164 = n2136[38]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:141:65 */
  assign n2167 = n2164 & 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:142:49 */
  assign n2168 = n2136[39]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:143:49 */
  assign n2169 = n2136[42:40]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:144:49 */
  assign n2170 = n2136[52:43]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:145:49 */
  assign n2171 = n2136[57]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:146:49 */
  assign n2172 = n2136[58]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:147:49 */
  assign n2173 = n2136[59]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:148:49 */
  assign n2174 = n2136[60]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:139:11 */
  assign n2175 = {n2174, n2173, n2172, n2171, n2170, n2169, n2168, n2167, n2163};
  /*# ../../rtl/core/neorv32_uart.vhd:151:29 */
  assign n2177 = n2136[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:33 */
  assign n2178 = ~n2177;
  /*# ../../rtl/core/neorv32_uart.vhd:152:70 */
  assign n2179 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:153:70 */
  assign n2180 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:153:79 */
  assign n2183 = n2180 & 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:154:70 */
  assign n2184 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:155:70 */
  assign n2185 = ctrl[5:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:156:70 */
  assign n2186 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:157:73 */
  assign n2187 = rx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:158:77 */
  assign n2188 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:158:65 */
  assign n2189 = ~n2188;
  /*# ../../rtl/core/neorv32_uart.vhd:159:77 */
  assign n2190 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:159:65 */
  assign n2191 = ~n2190;
  /*# ../../rtl/core/neorv32_uart.vhd:160:73 */
  assign n2192 = tx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:161:70 */
  assign n2193 = ctrl[16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:162:70 */
  assign n2194 = ctrl[17]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:163:70 */
  assign n2195 = ctrl[18]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:164:70 */
  assign n2196 = ctrl[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:73 */
  assign n2197 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:88 */
  assign n2198 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:166:77 */
  assign n2199 = n2197 | n2198;
  /*# ../../rtl/core/neorv32_uart.vhd:168:85 */
  assign n2200 = rx_fifo[18:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2203 = {4'b0000, 4'b0000, n2200};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2204 = {n2196, n2195, n2194, n2193, n2192, n2191, n2189, n2187, n2186, n2185, n2184, n2183, n2179};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2205 = {n2199, rx_overrun};
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2206 = n2204[15:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2207 = n2178 ? n2206 : n2203;
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2208 = n2204[23:16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2209 = n2158[23:16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2210 = n2178 ? n2208 : n2209;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2211 = n2158[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:151:11 */
  assign n2212 = n2178 ? n2205 : n2211;
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2213 = {n2210, n2207};
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2214 = n2158[23:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2215 = n2160 ? n2214 : n2213;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2216 = n2158[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2217 = n2160 ? n2216 : n2212;
  /*# ../../rtl/core/neorv32_uart.vhd:138:9 */
  assign n2218 = n2162 & n2160;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2219 = n2158[23:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2220 = n2159 ? n2215 : n2219;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2221 = n2158[31:30]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2222 = n2159 ? n2217 : n2221;
  /*# ../../rtl/core/neorv32_uart.vhd:33:5 */
  assign n2224 = n2158[29:24]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:137:7 */
  assign n2225 = n2218 & n2159;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  assign n2226 = {n2222, n2224, n2220, 1'b0, n2156};
  /*# ../../rtl/core/neorv32_uart.vhd:120:5 */
  assign n2231 = {1'b0, 1'b0, 1'b0, 1'b0, 10'b0000000000, 3'b000, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_uart.vhd:178:49 */
  assign n2234 = ctrl[5:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:183:3 */
  neorv32_prim_fifo_Bneorv32_prim_fifo_rtl_Lneorv32_0_8_5ba93c9db0cff93f52b521d7420e43f6eda2784f tx_fifo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(n2238),
    .wdata_i(n2239),
    .we_i(n2240),
    .re_i(n2242),
    .free_o(\tx_fifo_inst.free_o ),
    .rdata_o(\tx_fifo_inst.rdata_o ),
    .avail_o(\tx_fifo_inst.avail_o ));
  /*# ../../rtl/core/neorv32_uart.vhd:193:24 */
  assign n2238 = tx_fifo[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:195:24 */
  assign n2239 = tx_fifo[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:196:24 */
  assign n2240 = tx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:199:24 */
  assign n2242 = tx_fifo[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:35 */
  assign n2246 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:42 */
  assign n2247 = ~n2246;
  /*# ../../rtl/core/neorv32_uart.vhd:204:58 */
  assign n2248 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:204:49 */
  assign n2249 = n2247 | n2248;
  /*# ../../rtl/core/neorv32_uart.vhd:204:24 */
  assign n2250 = n2249 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:205:34 */
  assign n2252 = n2136[44:37]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:40 */
  assign n2254 = n2136[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:66 */
  assign n2255 = n2136[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:51 */
  assign n2256 = n2255 & n2254;
  /*# ../../rtl/core/neorv32_uart.vhd:206:95 */
  assign n2257 = n2136[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:206:76 */
  assign n2258 = n2257 & n2256;
  /*# ../../rtl/core/neorv32_uart.vhd:206:24 */
  assign n2259 = n2258 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:207:23 */
  assign n2261 = tx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:212:3 */
  neorv32_prim_fifo_Bneorv32_prim_fifo_rtl_Lneorv32_0_8_5ba93c9db0cff93f52b521d7420e43f6eda2784f rx_fifo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .clear_i(n2262),
    .wdata_i(n2263),
    .we_i(n2264),
    .re_i(n2266),
    .free_o(\rx_fifo_inst.free_o ),
    .rdata_o(\rx_fifo_inst.rdata_o ),
    .avail_o(\rx_fifo_inst.avail_o ));
  /*# ../../rtl/core/neorv32_uart.vhd:222:24 */
  assign n2262 = rx_fifo[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:224:24 */
  assign n2263 = rx_fifo[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:225:24 */
  assign n2264 = rx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:228:24 */
  assign n2266 = rx_fifo[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:35 */
  assign n2270 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:42 */
  assign n2271 = ~n2270;
  /*# ../../rtl/core/neorv32_uart.vhd:233:58 */
  assign n2272 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:233:49 */
  assign n2273 = n2271 | n2272;
  /*# ../../rtl/core/neorv32_uart.vhd:233:24 */
  assign n2274 = n2273 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:234:27 */
  assign n2276 = rx[9:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:235:23 */
  assign n2277 = rx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:40 */
  assign n2279 = n2136[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:66 */
  assign n2280 = n2136[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:69 */
  assign n2281 = ~n2280;
  /*# ../../rtl/core/neorv32_uart.vhd:236:51 */
  assign n2282 = n2281 & n2279;
  /*# ../../rtl/core/neorv32_uart.vhd:236:95 */
  assign n2283 = n2136[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:236:76 */
  assign n2284 = n2283 & n2282;
  /*# ../../rtl/core/neorv32_uart.vhd:236:24 */
  assign n2285 = n2284 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:243:16 */
  assign n2288 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:246:21 */
  assign n2290 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:22 */
  assign n2291 = ctrl[18]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:53 */
  assign n2292 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:247:41 */
  assign n2293 = ~n2292;
  /*# ../../rtl/core/neorv32_uart.vhd:247:36 */
  assign n2294 = n2291 & n2293;
  /*# ../../rtl/core/neorv32_uart.vhd:248:22 */
  assign n2295 = ctrl[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:248:48 */
  assign n2296 = tx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:248:36 */
  assign n2297 = n2295 & n2296;
  /*# ../../rtl/core/neorv32_uart.vhd:247:61 */
  assign n2298 = n2294 | n2297;
  /*# ../../rtl/core/neorv32_uart.vhd:249:22 */
  assign n2299 = ctrl[16]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:249:48 */
  assign n2300 = rx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:249:36 */
  assign n2301 = n2299 & n2300;
  /*# ../../rtl/core/neorv32_uart.vhd:248:61 */
  assign n2302 = n2298 | n2301;
  /*# ../../rtl/core/neorv32_uart.vhd:250:22 */
  assign n2303 = ctrl[17]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:250:53 */
  assign n2304 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:250:41 */
  assign n2305 = ~n2304;
  /*# ../../rtl/core/neorv32_uart.vhd:250:36 */
  assign n2306 = n2303 & n2305;
  /*# ../../rtl/core/neorv32_uart.vhd:249:61 */
  assign n2307 = n2302 | n2306;
  /*# ../../rtl/core/neorv32_uart.vhd:246:28 */
  assign n2308 = n2290 & n2307;
  /*# ../../rtl/core/neorv32_uart.vhd:259:16 */
  assign n2314 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:269:27 */
  assign n2322 = tx[26:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:269:40 */
  assign n2323 = {n2322, uart_ctsn_i};
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2324 = tx[27:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:268:7 */
  assign n2325 = uart_clk ? n2323 : n2324;
  /*# ../../rtl/core/neorv32_uart.vhd:273:27 */
  assign n2327 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:15 */
  assign n2328 = tx[1:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:278:30 */
  assign n2329 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:280:33 */
  assign n2331 = tx_fifo[18:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:280:39 */
  assign n2333 = {n2331, 1'b0};
  /*# ../../rtl/core/neorv32_uart.vhd:281:23 */
  assign n2334 = tx_fifo[20]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:44 */
  assign n2335 = tx[28]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:49 */
  assign n2336 = ~n2335;
  /*# ../../rtl/core/neorv32_uart.vhd:281:36 */
  assign n2337 = n2336 & n2334;
  /*# ../../rtl/core/neorv32_uart.vhd:283:25 */
  assign n2338 = tx[26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:283:29 */
  assign n2339 = ~n2338;
  /*# ../../rtl/core/neorv32_uart.vhd:283:45 */
  assign n2340 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:283:53 */
  assign n2341 = ~n2340;
  /*# ../../rtl/core/neorv32_uart.vhd:283:36 */
  assign n2342 = n2339 | n2341;
  /*# ../../rtl/core/neorv32_uart.vhd:282:33 */
  assign n2343 = n2342 & uart_clk;
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2345 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:281:11 */
  assign n2346 = n2348 ? 1'b1 : n2345;
  /*# ../../rtl/core/neorv32_uart.vhd:281:11 */
  assign n2348 = n2343 & n2337;
  /*# ../../rtl/core/neorv32_uart.vhd:276:9 */
  assign n2350 = n2328 == 2'b10;
  /*# ../../rtl/core/neorv32_uart.vhd:290:32 */
  assign n2351 = tx[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2359 = tx[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2361 = 1'b0 | n2359;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2363 = tx[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2364 = n2361 | n2363;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2365 = tx[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2366 = n2364 | n2365;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2367 = tx[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2368 = n2366 | n2367;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2369 = tx[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2370 = n2368 | n2369;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2371 = tx[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2372 = n2370 | n2371;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2373 = tx[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2374 = n2372 | n2373;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2375 = tx[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2376 = n2374 | n2375;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2377 = tx[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2378 = n2376 | n2377;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2379 = tx[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2380 = n2378 | n2379;
  /*# ../../rtl/core/neorv32_uart.vhd:292:41 */
  assign n2381 = ~n2380;
  /*# ../../rtl/core/neorv32_uart.vhd:293:34 */
  assign n2382 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:294:59 */
  assign n2383 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:294:67 */
  assign n2385 = n2383 - 4'b0001;
  /*# ../../rtl/core/neorv32_uart.vhd:295:42 */
  assign n2386 = tx[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:295:33 */
  assign n2388 = {1'b1, n2386};
  /*# ../../rtl/core/neorv32_uart.vhd:297:59 */
  assign n2389 = tx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:297:68 */
  assign n2391 = n2389 - 10'b0000000001;
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2392 = {n2382, n2385, n2388};
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2393 = n2392[12:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2394 = tx[14:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2395 = n2381 ? n2393 : n2394;
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2396 = n2392[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:292:13 */
  assign n2397 = n2381 ? n2396 : n2391;
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2398 = {n2397, n2395};
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2399 = tx[24:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2400 = uart_clk ? n2398 : n2399;
  /*# ../../rtl/core/neorv32_uart.vhd:300:18 */
  assign n2401 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:300:25 */
  assign n2403 = n2401 == 4'b0000;
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2406 = tx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:300:11 */
  assign n2407 = n2403 ? 1'b0 : n2406;
  /*# ../../rtl/core/neorv32_uart.vhd:300:11 */
  assign n2408 = n2403 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:288:9 */
  assign n2410 = n2328 == 2'b11;
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  assign n2412 = {n2410, n2350};
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2414 = n2351;
      2'b01: n2414 = 1'b1;
      default: n2414 = 1'b1;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2416 = n2407;
      2'b01: n2416 = n2346;
      default: n2416 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2417 = n2400[8:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2418 = tx[10:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2419 = n2417;
      2'b01: n2419 = n2333;
      default: n2419 = n2418;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2420 = n2400[12:9]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2421 = tx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2422 = n2420;
      2'b01: n2422 = 4'b1011;
      default: n2422 = n2421;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:291:11 */
  assign n2423 = n2400[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:10 */
  assign n2424 = tx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2425 = n2423;
      2'b01: n2425 = n2329;
      default: n2425 = n2424;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:274:7 */
  always @*
    case (n2412)
      2'b10: n2426 = n2408;
      2'b01: n2426 = 1'b0;
      default: n2426 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  assign n2428 = {n2426, n2325, n2425, n2422, n2419, n2327, n2416};
  /*# ../../rtl/core/neorv32_uart.vhd:259:5 */
  assign n2432 = {1'b0, 3'b000, 10'b0000000000, 4'b0000, 9'b000000000, 2'b00};
  /*# ../../rtl/core/neorv32_uart.vhd:318:16 */
  assign n2436 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:327:27 */
  assign n2444 = rx[26:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:327:40 */
  assign n2445 = {n2444, uart_rxd_i};
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2446 = rx[27:25]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:326:7 */
  assign n2447 = uart_clk ? n2445 : n2446;
  /*# ../../rtl/core/neorv32_uart.vhd:330:27 */
  assign n2449 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:15 */
  assign n2450 = rx[1:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:335:40 */
  assign n2451 = ctrl[15:7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:335:29 */
  assign n2453 = {1'b0, n2451};
  /*# ../../rtl/core/neorv32_uart.vhd:337:22 */
  assign n2455 = rx[27:26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:337:35 */
  assign n2457 = n2455 == 2'b10;
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2459 = rx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:337:11 */
  assign n2460 = n2462 ? 1'b1 : n2459;
  /*# ../../rtl/core/neorv32_uart.vhd:337:11 */
  assign n2462 = uart_clk & n2457;
  /*# ../../rtl/core/neorv32_uart.vhd:333:9 */
  assign n2464 = n2450 == 2'b10;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2472 = rx[24]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2474 = 1'b0 | n2472;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2476 = rx[23]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2477 = n2474 | n2476;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2478 = rx[22]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2479 = n2477 | n2478;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2480 = rx[21]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2481 = n2479 | n2480;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2482 = rx[20]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2483 = n2481 | n2482;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2484 = rx[19]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2485 = n2483 | n2484;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2486 = rx[18]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2487 = n2485 | n2486;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2488 = rx[17]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2489 = n2487 | n2488;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2490 = rx[16]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2491 = n2489 | n2490;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n2492 = rx[15]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n2493 = n2491 | n2492;
  /*# ../../rtl/core/neorv32_uart.vhd:346:41 */
  assign n2494 = ~n2493;
  /*# ../../rtl/core/neorv32_uart.vhd:347:34 */
  assign n2495 = ctrl[15:6]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:348:59 */
  assign n2496 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:348:67 */
  assign n2498 = n2496 - 4'b0001;
  /*# ../../rtl/core/neorv32_uart.vhd:349:37 */
  assign n2499 = rx[27]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:52 */
  assign n2500 = rx[26]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:41 */
  assign n2501 = n2499 & n2500;
  /*# ../../rtl/core/neorv32_uart.vhd:349:66 */
  assign n2502 = rx[10:3]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:349:57 */
  assign n2503 = {n2501, n2502};
  /*# ../../rtl/core/neorv32_uart.vhd:351:59 */
  assign n2504 = rx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:351:68 */
  assign n2506 = n2504 - 10'b0000000001;
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2507 = {n2495, n2498, n2503};
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2508 = n2507[12:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2509 = rx[14:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2510 = n2494 ? n2508 : n2509;
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2511 = n2507[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:346:13 */
  assign n2512 = n2494 ? n2511 : n2506;
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2513 = {n2512, n2510};
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2514 = rx[24:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2515 = uart_clk ? n2513 : n2514;
  /*# ../../rtl/core/neorv32_uart.vhd:354:18 */
  assign n2516 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:354:25 */
  assign n2518 = n2516 == 4'b0000;
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2521 = rx[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:354:11 */
  assign n2522 = n2518 ? 1'b0 : n2521;
  /*# ../../rtl/core/neorv32_uart.vhd:354:11 */
  assign n2523 = n2518 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_uart.vhd:343:9 */
  assign n2525 = n2450 == 2'b11;
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  assign n2527 = {n2525, n2464};
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2527)
      2'b10: n2528 = n2522;
      2'b01: n2528 = n2460;
      default: n2528 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2529 = n2515[8:0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2530 = rx[10:2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2527)
      2'b10: n2531 = n2529;
      2'b01: n2531 = n2530;
      default: n2531 = n2530;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2532 = n2515[12:9]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2533 = rx[14:11]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2527)
      2'b10: n2534 = n2532;
      2'b01: n2534 = 4'b1010;
      default: n2534 = n2533;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:345:11 */
  assign n2535 = n2515[22:13]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:103:14 */
  assign n2536 = rx[24:15]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2527)
      2'b10: n2537 = n2535;
      2'b01: n2537 = n2453;
      default: n2537 = n2536;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:331:7 */
  always @*
    case (n2527)
      2'b10: n2538 = n2523;
      2'b01: n2538 = 1'b0;
      default: n2538 = 1'b0;
    endcase
  /*# ../../rtl/core/neorv32_uart.vhd:325:5 */
  assign n2539 = {n2538, n2447, n2537, n2534, n2531, n2449, n2528};
  /*# ../../rtl/core/neorv32_uart.vhd:318:5 */
  assign n2541 = {1'b0, 3'b000, 10'b0000000000, 4'b0000, 9'b000000000, 2'b00};
  /*# ../../rtl/core/neorv32_uart.vhd:370:16 */
  assign n2545 = ~rstn_i;
  /*# ../../rtl/core/neorv32_uart.vhd:374:27 */
  assign n2547 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:50 */
  assign n2548 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:41 */
  assign n2549 = ~n2548;
  /*# ../../rtl/core/neorv32_uart.vhd:374:74 */
  assign n2550 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:374:62 */
  assign n2551 = ~n2550;
  /*# ../../rtl/core/neorv32_uart.vhd:374:58 */
  assign n2552 = n2549 | n2551;
  /*# ../../rtl/core/neorv32_uart.vhd:374:35 */
  assign n2553 = n2547 & n2552;
  /*# ../../rtl/core/neorv32_uart.vhd:375:16 */
  assign n2554 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:375:23 */
  assign n2555 = ~n2554;
  /*# ../../rtl/core/neorv32_uart.vhd:377:22 */
  assign n2556 = rx_fifo[1]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:377:45 */
  assign n2557 = rx_fifo[19]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:377:50 */
  assign n2558 = ~n2557;
  /*# ../../rtl/core/neorv32_uart.vhd:377:32 */
  assign n2559 = n2558 & n2556;
  /*# ../../rtl/core/neorv32_uart.vhd:379:24 */
  assign n2560 = n2136[73]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:50 */
  assign n2561 = n2136[74]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:53 */
  assign n2562 = ~n2561;
  /*# ../../rtl/core/neorv32_uart.vhd:379:35 */
  assign n2563 = n2562 & n2560;
  /*# ../../rtl/core/neorv32_uart.vhd:379:79 */
  assign n2564 = n2136[7]; // extract
  /*# ../../rtl/core/neorv32_uart.vhd:379:83 */
  assign n2565 = ~n2564;
  /*# ../../rtl/core/neorv32_uart.vhd:379:60 */
  assign n2566 = n2565 & n2563;
  /*# ../../rtl/core/neorv32_uart.vhd:379:7 */
  assign n2568 = n2566 ? 1'b0 : rx_overrun;
  /*# ../../rtl/core/neorv32_uart.vhd:377:7 */
  assign n2570 = n2559 ? 1'b1 : n2568;
  /*# ../../rtl/core/neorv32_uart.vhd:375:7 */
  assign n2572 = n2555 ? 1'b0 : n2570;
  /*# ../../rtl/core/neorv32_uart.vhd:112:10 */
  assign n2580 = {\rx_fifo_inst.avail_o , \rx_fifo_inst.free_o , \rx_fifo_inst.rdata_o , n2276, n2285, n2277, n2274};
  /*# ../../rtl/core/neorv32_uart.vhd:112:19 */
  assign n2581 = {\tx_fifo_inst.avail_o , \tx_fifo_inst.free_o , \tx_fifo_inst.rdata_o , n2252, n2261, n2259, n2250};
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  always @(posedge clk_i or posedge n2145)
    if (n2145)
      n2582 <= 34'b0000000000000000000000000000000000;
    else
      n2582 <= n2226;
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  always @(posedge clk_i or posedge n2314)
    if (n2314)
      n2583 <= 1'b1;
    else
      n2583 <= n2414;
  /*# ../../rtl/core/neorv32_uart.vhd:373:5 */
  always @(posedge clk_i or posedge n2545)
    if (n2545)
      n2584 <= 1'b0;
    else
      n2584 <= n2553;
  /*# ../../rtl/core/neorv32_uart.vhd:245:5 */
  always @(posedge clk_i or posedge n2288)
    if (n2288)
      n2585 <= 1'b0;
    else
      n2585 <= n2308;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  assign n2586 = n2225 ? n2175 : ctrl;
  /*# ../../rtl/core/neorv32_uart.vhd:131:5 */
  always @(posedge clk_i or posedge n2145)
    if (n2145)
      n2587 <= n2231;
    else
      n2587 <= n2586;
  /*# ../../rtl/core/neorv32_uart.vhd:267:5 */
  always @(posedge clk_i or posedge n2314)
    if (n2314)
      n2588 <= n2432;
    else
      n2588 <= n2428;
  /*# ../../rtl/core/neorv32_uart.vhd:325:5 */
  always @(posedge clk_i or posedge n2436)
    if (n2436)
      n2589 <= n2541;
    else
      n2589 <= n2539;
  /*# ../../rtl/core/neorv32_uart.vhd:373:5 */
  always @(posedge clk_i or posedge n2545)
    if (n2545)
      n2590 <= 1'b0;
    else
      n2590 <= n2572;
  /*# ../../rtl/core/neorv32_uart.vhd:178:24 */
  assign n2591 = clkgen_i[n2234 * 1 +: 1]; //(Bmux)
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
  wire [81:0] n1643;
  wire n1645;
  wire n1646;
  wire [31:0] n1647;
  wire [4:0] n1649;
  wire [31:0] n1650;
  wire [31:0] n1651;
  wire [3:0] n1652;
  wire n1653;
  wire n1654;
  wire n1655;
  wire [3:0] n1656;
  wire n1657;
  wire n1658;
  wire [33:0] n1659;
  wire [4:0] n1661;
  wire [31:0] n1662;
  wire [31:0] n1663;
  wire [3:0] n1664;
  wire n1665;
  wire n1666;
  wire n1667;
  wire [3:0] n1668;
  wire n1669;
  wire n1670;
  wire [33:0] n1671;
  wire [4:0] n1673;
  wire [31:0] n1674;
  wire [31:0] n1675;
  wire [3:0] n1676;
  wire n1677;
  wire n1678;
  wire n1679;
  wire [3:0] n1680;
  wire n1681;
  wire n1682;
  wire [33:0] n1683;
  wire [4:0] n1685;
  wire [31:0] n1686;
  wire [31:0] n1687;
  wire [3:0] n1688;
  wire n1689;
  wire n1690;
  wire n1691;
  wire [3:0] n1692;
  wire n1693;
  wire n1694;
  wire [33:0] n1695;
  wire [4:0] n1697;
  wire [31:0] n1698;
  wire [31:0] n1699;
  wire [3:0] n1700;
  wire n1701;
  wire n1702;
  wire n1703;
  wire [3:0] n1704;
  wire n1705;
  wire n1706;
  wire [33:0] n1707;
  wire [4:0] n1709;
  wire [31:0] n1710;
  wire [31:0] n1711;
  wire [3:0] n1712;
  wire n1713;
  wire n1714;
  wire n1715;
  wire [3:0] n1716;
  wire n1717;
  wire n1718;
  wire [33:0] n1719;
  wire [4:0] n1721;
  wire [31:0] n1722;
  wire [31:0] n1723;
  wire [3:0] n1724;
  wire n1725;
  wire n1726;
  wire n1727;
  wire [3:0] n1728;
  wire n1729;
  wire n1730;
  wire [33:0] n1731;
  wire [4:0] n1733;
  wire [31:0] n1734;
  wire [31:0] n1735;
  wire [3:0] n1736;
  wire n1737;
  wire n1738;
  wire n1739;
  wire [3:0] n1740;
  wire n1741;
  wire n1742;
  wire [33:0] n1743;
  wire [4:0] n1745;
  wire [31:0] n1746;
  wire [31:0] n1747;
  wire [3:0] n1748;
  wire n1749;
  wire n1750;
  wire n1751;
  wire [3:0] n1752;
  wire n1753;
  wire n1754;
  wire [33:0] n1755;
  wire [4:0] n1757;
  wire [31:0] n1758;
  wire [31:0] n1759;
  wire [3:0] n1760;
  wire n1761;
  wire n1762;
  wire n1763;
  wire [3:0] n1764;
  wire n1765;
  wire n1766;
  wire [33:0] n1767;
  wire [4:0] n1769;
  wire [31:0] n1770;
  wire [31:0] n1771;
  wire [3:0] n1772;
  wire n1773;
  wire n1774;
  wire n1775;
  wire [3:0] n1776;
  wire n1777;
  wire n1778;
  wire [33:0] n1779;
  wire [4:0] n1781;
  wire [31:0] n1782;
  wire [31:0] n1783;
  wire [3:0] n1784;
  wire n1785;
  wire n1786;
  wire n1787;
  wire [3:0] n1788;
  wire n1789;
  wire n1790;
  wire [33:0] n1791;
  wire [4:0] n1793;
  wire [31:0] n1794;
  wire [31:0] n1795;
  wire [3:0] n1796;
  wire n1797;
  wire n1798;
  wire n1799;
  wire [3:0] n1800;
  wire n1801;
  wire n1802;
  wire [33:0] n1803;
  wire [4:0] n1805;
  wire [31:0] n1806;
  wire [31:0] n1807;
  wire [3:0] n1808;
  wire n1809;
  wire n1810;
  wire n1811;
  wire [3:0] n1812;
  wire n1813;
  wire n1814;
  wire [33:0] n1815;
  wire [4:0] n1817;
  wire [31:0] n1818;
  wire [31:0] n1819;
  wire [3:0] n1820;
  wire n1821;
  wire n1822;
  wire n1823;
  wire [3:0] n1824;
  wire n1825;
  wire n1826;
  wire [33:0] n1827;
  wire [4:0] n1829;
  wire [31:0] n1830;
  wire [31:0] n1831;
  wire [3:0] n1832;
  wire n1833;
  wire n1834;
  wire n1835;
  wire [3:0] n1836;
  wire n1837;
  wire n1838;
  wire [33:0] n1839;
  wire [4:0] n1841;
  wire [31:0] n1842;
  wire [31:0] n1843;
  wire [3:0] n1844;
  wire n1845;
  wire n1846;
  wire n1847;
  wire [3:0] n1848;
  wire n1849;
  wire n1850;
  wire [33:0] n1851;
  wire [4:0] n1853;
  wire [31:0] n1854;
  wire [31:0] n1855;
  wire [3:0] n1856;
  wire n1857;
  wire n1858;
  wire n1859;
  wire [3:0] n1860;
  wire n1861;
  wire n1862;
  wire [33:0] n1863;
  wire [4:0] n1865;
  wire [31:0] n1866;
  wire [31:0] n1867;
  wire [3:0] n1868;
  wire n1869;
  wire n1870;
  wire n1871;
  wire [3:0] n1872;
  wire n1873;
  wire n1874;
  wire [33:0] n1875;
  wire [4:0] n1877;
  wire [31:0] n1878;
  wire [31:0] n1879;
  wire [3:0] n1880;
  wire n1881;
  wire n1882;
  wire n1883;
  wire [3:0] n1884;
  wire n1885;
  wire n1886;
  wire [33:0] n1887;
  wire [4:0] n1889;
  wire [31:0] n1890;
  wire [31:0] n1891;
  wire [3:0] n1892;
  wire n1893;
  wire n1894;
  wire n1895;
  wire [3:0] n1896;
  wire n1897;
  wire n1898;
  wire [33:0] n1899;
  wire [4:0] n1901;
  wire [31:0] n1902;
  wire [31:0] n1903;
  wire [3:0] n1904;
  wire n1905;
  wire n1906;
  wire n1907;
  wire [3:0] n1908;
  wire n1909;
  wire n1910;
  wire [33:0] n1911;
  wire [4:0] n1913;
  wire [31:0] n1914;
  wire [31:0] n1915;
  wire [3:0] n1916;
  wire n1917;
  wire n1918;
  wire n1919;
  wire [3:0] n1920;
  wire n1921;
  wire n1922;
  wire [33:0] n1923;
  wire [4:0] n1925;
  wire [31:0] n1926;
  wire [31:0] n1927;
  wire [3:0] n1928;
  wire n1929;
  wire n1930;
  wire n1931;
  wire [3:0] n1932;
  wire n1933;
  wire n1934;
  wire [33:0] n1935;
  wire [4:0] n1937;
  wire [31:0] n1938;
  wire [31:0] n1939;
  wire [3:0] n1940;
  wire n1941;
  wire n1942;
  wire n1943;
  wire [3:0] n1944;
  wire n1945;
  wire n1946;
  wire [33:0] n1947;
  wire [4:0] n1949;
  wire [31:0] n1950;
  wire [31:0] n1951;
  wire [3:0] n1952;
  wire n1953;
  wire n1954;
  wire n1955;
  wire [3:0] n1956;
  wire n1957;
  wire n1958;
  wire [33:0] n1959;
  wire [4:0] n1961;
  wire [31:0] n1962;
  wire [31:0] n1963;
  wire [3:0] n1964;
  wire n1965;
  wire n1966;
  wire n1967;
  wire [3:0] n1968;
  wire n1969;
  wire n1970;
  wire [33:0] n1971;
  wire [4:0] n1973;
  wire [31:0] n1974;
  wire [31:0] n1975;
  wire [3:0] n1976;
  wire n1977;
  wire n1978;
  wire n1979;
  wire [3:0] n1980;
  wire n1981;
  wire n1982;
  wire [33:0] n1983;
  wire [4:0] n1985;
  wire [31:0] n1986;
  wire [31:0] n1987;
  wire [3:0] n1988;
  wire n1989;
  wire n1990;
  wire n1991;
  wire [3:0] n1992;
  wire n1993;
  wire n1994;
  wire [33:0] n1995;
  wire [4:0] n1997;
  wire [31:0] n1998;
  wire [31:0] n1999;
  wire [3:0] n2000;
  wire n2001;
  wire n2002;
  wire n2003;
  wire [3:0] n2004;
  wire n2005;
  wire n2006;
  wire [33:0] n2007;
  wire [4:0] n2009;
  wire [31:0] n2010;
  wire [31:0] n2011;
  wire [3:0] n2012;
  wire n2013;
  wire n2014;
  wire n2015;
  wire [3:0] n2016;
  wire n2017;
  wire n2018;
  wire [33:0] n2019;
  wire [4:0] n2021;
  wire [31:0] n2022;
  wire [31:0] n2023;
  wire [3:0] n2024;
  wire n2025;
  wire n2026;
  wire n2027;
  wire [3:0] n2028;
  wire n2029;
  wire n2030;
  wire [33:0] n2031;
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
  wire [4:0] n2032;
  wire [31:0] n2033;
  wire [31:0] n2034;
  wire [3:0] n2035;
  wire n2036;
  wire n2037;
  wire n2038;
  wire [3:0] n2039;
  wire n2040;
  wire n2041;
  wire [33:0] n2042;
  wire [81:0] n2044;
  wire n2046;
  wire n2047;
  wire [31:0] n2048;
  wire [81:0] n2049;
  wire [81:0] n2050;
  wire [81:0] n2051;
  wire [81:0] n2052;
  wire [81:0] n2053;
  wire [81:0] n2054;
  wire [81:0] n2055;
  wire [81:0] n2056;
  wire [81:0] n2057;
  wire [81:0] n2058;
  wire [81:0] n2059;
  wire [81:0] n2060;
  wire [81:0] n2061;
  wire [81:0] n2062;
  wire [81:0] n2063;
  wire [81:0] n2064;
  wire [81:0] n2065;
  wire [81:0] n2066;
  wire [81:0] n2067;
  wire [81:0] n2068;
  wire [81:0] n2069;
  wire [81:0] n2070;
  wire [81:0] n2071;
  wire [81:0] n2072;
  wire [81:0] n2073;
  wire [81:0] n2074;
  wire [81:0] n2075;
  wire [81:0] n2076;
  wire [81:0] n2077;
  wire [81:0] n2078;
  wire [81:0] n2079;
  wire [81:0] n2080;
  wire [4:0] n2083;
  wire n2085;
  wire n2086;
  wire n2088;
  wire [7:0] n2089;
  wire [72:0] n2090;
  wire [4:0] n2093;
  wire n2095;
  wire n2096;
  wire n2098;
  wire [7:0] n2099;
  wire [72:0] n2100;
  localparam [33:0] n2104 = 34'b0000000000000000000000000000000000;
  wire [31:0] n2105;
  wire [31:0] n2106;
  wire [31:0] n2107;
  localparam [33:0] n2108 = 34'b0000000000000000000000000000000000;
  wire [1:0] n2109;
  wire [33:0] n2110;
  wire n2111;
  wire n2112;
  wire n2113;
  wire n2114;
  wire [33:0] n2115;
  wire n2116;
  wire n2117;
  wire n2118;
  wire [33:0] n2119;
  wire [31:0] n2120;
  wire [31:0] n2121;
  wire [31:0] n2122;
  wire [33:0] n2123;
  wire n2124;
  wire n2125;
  wire n2126;
  wire [33:0] n2127;
  wire n2128;
  wire n2129;
  wire n2130;
  wire [33:0] n2131;
  wire [2623:0] n2134;
  wire [1087:0] n2135;
  assign \main_rsp_o[ack]  = n1645; //(module output)
  assign \main_rsp_o[err]  = n1646; //(module output)
  assign \main_rsp_o[data]  = n1647; //(module output)
  assign \dev_00_req_o[meta]  = n1649; //(module output)
  assign \dev_00_req_o[addr]  = n1650; //(module output)
  assign \dev_00_req_o[data]  = n1651; //(module output)
  assign \dev_00_req_o[ben]  = n1652; //(module output)
  assign \dev_00_req_o[stb]  = n1653; //(module output)
  assign \dev_00_req_o[rw]  = n1654; //(module output)
  assign \dev_00_req_o[amo]  = n1655; //(module output)
  assign \dev_00_req_o[amoop]  = n1656; //(module output)
  assign \dev_00_req_o[burst]  = n1657; //(module output)
  assign \dev_00_req_o[lock]  = n1658; //(module output)
  assign \dev_01_req_o[meta]  = n1661; //(module output)
  assign \dev_01_req_o[addr]  = n1662; //(module output)
  assign \dev_01_req_o[data]  = n1663; //(module output)
  assign \dev_01_req_o[ben]  = n1664; //(module output)
  assign \dev_01_req_o[stb]  = n1665; //(module output)
  assign \dev_01_req_o[rw]  = n1666; //(module output)
  assign \dev_01_req_o[amo]  = n1667; //(module output)
  assign \dev_01_req_o[amoop]  = n1668; //(module output)
  assign \dev_01_req_o[burst]  = n1669; //(module output)
  assign \dev_01_req_o[lock]  = n1670; //(module output)
  assign \dev_02_req_o[meta]  = n1673; //(module output)
  assign \dev_02_req_o[addr]  = n1674; //(module output)
  assign \dev_02_req_o[data]  = n1675; //(module output)
  assign \dev_02_req_o[ben]  = n1676; //(module output)
  assign \dev_02_req_o[stb]  = n1677; //(module output)
  assign \dev_02_req_o[rw]  = n1678; //(module output)
  assign \dev_02_req_o[amo]  = n1679; //(module output)
  assign \dev_02_req_o[amoop]  = n1680; //(module output)
  assign \dev_02_req_o[burst]  = n1681; //(module output)
  assign \dev_02_req_o[lock]  = n1682; //(module output)
  assign \dev_03_req_o[meta]  = n1685; //(module output)
  assign \dev_03_req_o[addr]  = n1686; //(module output)
  assign \dev_03_req_o[data]  = n1687; //(module output)
  assign \dev_03_req_o[ben]  = n1688; //(module output)
  assign \dev_03_req_o[stb]  = n1689; //(module output)
  assign \dev_03_req_o[rw]  = n1690; //(module output)
  assign \dev_03_req_o[amo]  = n1691; //(module output)
  assign \dev_03_req_o[amoop]  = n1692; //(module output)
  assign \dev_03_req_o[burst]  = n1693; //(module output)
  assign \dev_03_req_o[lock]  = n1694; //(module output)
  assign \dev_04_req_o[meta]  = n1697; //(module output)
  assign \dev_04_req_o[addr]  = n1698; //(module output)
  assign \dev_04_req_o[data]  = n1699; //(module output)
  assign \dev_04_req_o[ben]  = n1700; //(module output)
  assign \dev_04_req_o[stb]  = n1701; //(module output)
  assign \dev_04_req_o[rw]  = n1702; //(module output)
  assign \dev_04_req_o[amo]  = n1703; //(module output)
  assign \dev_04_req_o[amoop]  = n1704; //(module output)
  assign \dev_04_req_o[burst]  = n1705; //(module output)
  assign \dev_04_req_o[lock]  = n1706; //(module output)
  assign \dev_05_req_o[meta]  = n1709; //(module output)
  assign \dev_05_req_o[addr]  = n1710; //(module output)
  assign \dev_05_req_o[data]  = n1711; //(module output)
  assign \dev_05_req_o[ben]  = n1712; //(module output)
  assign \dev_05_req_o[stb]  = n1713; //(module output)
  assign \dev_05_req_o[rw]  = n1714; //(module output)
  assign \dev_05_req_o[amo]  = n1715; //(module output)
  assign \dev_05_req_o[amoop]  = n1716; //(module output)
  assign \dev_05_req_o[burst]  = n1717; //(module output)
  assign \dev_05_req_o[lock]  = n1718; //(module output)
  assign \dev_06_req_o[meta]  = n1721; //(module output)
  assign \dev_06_req_o[addr]  = n1722; //(module output)
  assign \dev_06_req_o[data]  = n1723; //(module output)
  assign \dev_06_req_o[ben]  = n1724; //(module output)
  assign \dev_06_req_o[stb]  = n1725; //(module output)
  assign \dev_06_req_o[rw]  = n1726; //(module output)
  assign \dev_06_req_o[amo]  = n1727; //(module output)
  assign \dev_06_req_o[amoop]  = n1728; //(module output)
  assign \dev_06_req_o[burst]  = n1729; //(module output)
  assign \dev_06_req_o[lock]  = n1730; //(module output)
  assign \dev_07_req_o[meta]  = n1733; //(module output)
  assign \dev_07_req_o[addr]  = n1734; //(module output)
  assign \dev_07_req_o[data]  = n1735; //(module output)
  assign \dev_07_req_o[ben]  = n1736; //(module output)
  assign \dev_07_req_o[stb]  = n1737; //(module output)
  assign \dev_07_req_o[rw]  = n1738; //(module output)
  assign \dev_07_req_o[amo]  = n1739; //(module output)
  assign \dev_07_req_o[amoop]  = n1740; //(module output)
  assign \dev_07_req_o[burst]  = n1741; //(module output)
  assign \dev_07_req_o[lock]  = n1742; //(module output)
  assign \dev_08_req_o[meta]  = n1745; //(module output)
  assign \dev_08_req_o[addr]  = n1746; //(module output)
  assign \dev_08_req_o[data]  = n1747; //(module output)
  assign \dev_08_req_o[ben]  = n1748; //(module output)
  assign \dev_08_req_o[stb]  = n1749; //(module output)
  assign \dev_08_req_o[rw]  = n1750; //(module output)
  assign \dev_08_req_o[amo]  = n1751; //(module output)
  assign \dev_08_req_o[amoop]  = n1752; //(module output)
  assign \dev_08_req_o[burst]  = n1753; //(module output)
  assign \dev_08_req_o[lock]  = n1754; //(module output)
  assign \dev_09_req_o[meta]  = n1757; //(module output)
  assign \dev_09_req_o[addr]  = n1758; //(module output)
  assign \dev_09_req_o[data]  = n1759; //(module output)
  assign \dev_09_req_o[ben]  = n1760; //(module output)
  assign \dev_09_req_o[stb]  = n1761; //(module output)
  assign \dev_09_req_o[rw]  = n1762; //(module output)
  assign \dev_09_req_o[amo]  = n1763; //(module output)
  assign \dev_09_req_o[amoop]  = n1764; //(module output)
  assign \dev_09_req_o[burst]  = n1765; //(module output)
  assign \dev_09_req_o[lock]  = n1766; //(module output)
  assign \dev_10_req_o[meta]  = n1769; //(module output)
  assign \dev_10_req_o[addr]  = n1770; //(module output)
  assign \dev_10_req_o[data]  = n1771; //(module output)
  assign \dev_10_req_o[ben]  = n1772; //(module output)
  assign \dev_10_req_o[stb]  = n1773; //(module output)
  assign \dev_10_req_o[rw]  = n1774; //(module output)
  assign \dev_10_req_o[amo]  = n1775; //(module output)
  assign \dev_10_req_o[amoop]  = n1776; //(module output)
  assign \dev_10_req_o[burst]  = n1777; //(module output)
  assign \dev_10_req_o[lock]  = n1778; //(module output)
  assign \dev_11_req_o[meta]  = n1781; //(module output)
  assign \dev_11_req_o[addr]  = n1782; //(module output)
  assign \dev_11_req_o[data]  = n1783; //(module output)
  assign \dev_11_req_o[ben]  = n1784; //(module output)
  assign \dev_11_req_o[stb]  = n1785; //(module output)
  assign \dev_11_req_o[rw]  = n1786; //(module output)
  assign \dev_11_req_o[amo]  = n1787; //(module output)
  assign \dev_11_req_o[amoop]  = n1788; //(module output)
  assign \dev_11_req_o[burst]  = n1789; //(module output)
  assign \dev_11_req_o[lock]  = n1790; //(module output)
  assign \dev_12_req_o[meta]  = n1793; //(module output)
  assign \dev_12_req_o[addr]  = n1794; //(module output)
  assign \dev_12_req_o[data]  = n1795; //(module output)
  assign \dev_12_req_o[ben]  = n1796; //(module output)
  assign \dev_12_req_o[stb]  = n1797; //(module output)
  assign \dev_12_req_o[rw]  = n1798; //(module output)
  assign \dev_12_req_o[amo]  = n1799; //(module output)
  assign \dev_12_req_o[amoop]  = n1800; //(module output)
  assign \dev_12_req_o[burst]  = n1801; //(module output)
  assign \dev_12_req_o[lock]  = n1802; //(module output)
  assign \dev_13_req_o[meta]  = n1805; //(module output)
  assign \dev_13_req_o[addr]  = n1806; //(module output)
  assign \dev_13_req_o[data]  = n1807; //(module output)
  assign \dev_13_req_o[ben]  = n1808; //(module output)
  assign \dev_13_req_o[stb]  = n1809; //(module output)
  assign \dev_13_req_o[rw]  = n1810; //(module output)
  assign \dev_13_req_o[amo]  = n1811; //(module output)
  assign \dev_13_req_o[amoop]  = n1812; //(module output)
  assign \dev_13_req_o[burst]  = n1813; //(module output)
  assign \dev_13_req_o[lock]  = n1814; //(module output)
  assign \dev_14_req_o[meta]  = n1817; //(module output)
  assign \dev_14_req_o[addr]  = n1818; //(module output)
  assign \dev_14_req_o[data]  = n1819; //(module output)
  assign \dev_14_req_o[ben]  = n1820; //(module output)
  assign \dev_14_req_o[stb]  = n1821; //(module output)
  assign \dev_14_req_o[rw]  = n1822; //(module output)
  assign \dev_14_req_o[amo]  = n1823; //(module output)
  assign \dev_14_req_o[amoop]  = n1824; //(module output)
  assign \dev_14_req_o[burst]  = n1825; //(module output)
  assign \dev_14_req_o[lock]  = n1826; //(module output)
  assign \dev_15_req_o[meta]  = n1829; //(module output)
  assign \dev_15_req_o[addr]  = n1830; //(module output)
  assign \dev_15_req_o[data]  = n1831; //(module output)
  assign \dev_15_req_o[ben]  = n1832; //(module output)
  assign \dev_15_req_o[stb]  = n1833; //(module output)
  assign \dev_15_req_o[rw]  = n1834; //(module output)
  assign \dev_15_req_o[amo]  = n1835; //(module output)
  assign \dev_15_req_o[amoop]  = n1836; //(module output)
  assign \dev_15_req_o[burst]  = n1837; //(module output)
  assign \dev_15_req_o[lock]  = n1838; //(module output)
  assign \dev_16_req_o[meta]  = n1841; //(module output)
  assign \dev_16_req_o[addr]  = n1842; //(module output)
  assign \dev_16_req_o[data]  = n1843; //(module output)
  assign \dev_16_req_o[ben]  = n1844; //(module output)
  assign \dev_16_req_o[stb]  = n1845; //(module output)
  assign \dev_16_req_o[rw]  = n1846; //(module output)
  assign \dev_16_req_o[amo]  = n1847; //(module output)
  assign \dev_16_req_o[amoop]  = n1848; //(module output)
  assign \dev_16_req_o[burst]  = n1849; //(module output)
  assign \dev_16_req_o[lock]  = n1850; //(module output)
  assign \dev_17_req_o[meta]  = n1853; //(module output)
  assign \dev_17_req_o[addr]  = n1854; //(module output)
  assign \dev_17_req_o[data]  = n1855; //(module output)
  assign \dev_17_req_o[ben]  = n1856; //(module output)
  assign \dev_17_req_o[stb]  = n1857; //(module output)
  assign \dev_17_req_o[rw]  = n1858; //(module output)
  assign \dev_17_req_o[amo]  = n1859; //(module output)
  assign \dev_17_req_o[amoop]  = n1860; //(module output)
  assign \dev_17_req_o[burst]  = n1861; //(module output)
  assign \dev_17_req_o[lock]  = n1862; //(module output)
  assign \dev_18_req_o[meta]  = n1865; //(module output)
  assign \dev_18_req_o[addr]  = n1866; //(module output)
  assign \dev_18_req_o[data]  = n1867; //(module output)
  assign \dev_18_req_o[ben]  = n1868; //(module output)
  assign \dev_18_req_o[stb]  = n1869; //(module output)
  assign \dev_18_req_o[rw]  = n1870; //(module output)
  assign \dev_18_req_o[amo]  = n1871; //(module output)
  assign \dev_18_req_o[amoop]  = n1872; //(module output)
  assign \dev_18_req_o[burst]  = n1873; //(module output)
  assign \dev_18_req_o[lock]  = n1874; //(module output)
  assign \dev_19_req_o[meta]  = n1877; //(module output)
  assign \dev_19_req_o[addr]  = n1878; //(module output)
  assign \dev_19_req_o[data]  = n1879; //(module output)
  assign \dev_19_req_o[ben]  = n1880; //(module output)
  assign \dev_19_req_o[stb]  = n1881; //(module output)
  assign \dev_19_req_o[rw]  = n1882; //(module output)
  assign \dev_19_req_o[amo]  = n1883; //(module output)
  assign \dev_19_req_o[amoop]  = n1884; //(module output)
  assign \dev_19_req_o[burst]  = n1885; //(module output)
  assign \dev_19_req_o[lock]  = n1886; //(module output)
  assign \dev_20_req_o[meta]  = n1889; //(module output)
  assign \dev_20_req_o[addr]  = n1890; //(module output)
  assign \dev_20_req_o[data]  = n1891; //(module output)
  assign \dev_20_req_o[ben]  = n1892; //(module output)
  assign \dev_20_req_o[stb]  = n1893; //(module output)
  assign \dev_20_req_o[rw]  = n1894; //(module output)
  assign \dev_20_req_o[amo]  = n1895; //(module output)
  assign \dev_20_req_o[amoop]  = n1896; //(module output)
  assign \dev_20_req_o[burst]  = n1897; //(module output)
  assign \dev_20_req_o[lock]  = n1898; //(module output)
  assign \dev_21_req_o[meta]  = n1901; //(module output)
  assign \dev_21_req_o[addr]  = n1902; //(module output)
  assign \dev_21_req_o[data]  = n1903; //(module output)
  assign \dev_21_req_o[ben]  = n1904; //(module output)
  assign \dev_21_req_o[stb]  = n1905; //(module output)
  assign \dev_21_req_o[rw]  = n1906; //(module output)
  assign \dev_21_req_o[amo]  = n1907; //(module output)
  assign \dev_21_req_o[amoop]  = n1908; //(module output)
  assign \dev_21_req_o[burst]  = n1909; //(module output)
  assign \dev_21_req_o[lock]  = n1910; //(module output)
  assign \dev_22_req_o[meta]  = n1913; //(module output)
  assign \dev_22_req_o[addr]  = n1914; //(module output)
  assign \dev_22_req_o[data]  = n1915; //(module output)
  assign \dev_22_req_o[ben]  = n1916; //(module output)
  assign \dev_22_req_o[stb]  = n1917; //(module output)
  assign \dev_22_req_o[rw]  = n1918; //(module output)
  assign \dev_22_req_o[amo]  = n1919; //(module output)
  assign \dev_22_req_o[amoop]  = n1920; //(module output)
  assign \dev_22_req_o[burst]  = n1921; //(module output)
  assign \dev_22_req_o[lock]  = n1922; //(module output)
  assign \dev_23_req_o[meta]  = n1925; //(module output)
  assign \dev_23_req_o[addr]  = n1926; //(module output)
  assign \dev_23_req_o[data]  = n1927; //(module output)
  assign \dev_23_req_o[ben]  = n1928; //(module output)
  assign \dev_23_req_o[stb]  = n1929; //(module output)
  assign \dev_23_req_o[rw]  = n1930; //(module output)
  assign \dev_23_req_o[amo]  = n1931; //(module output)
  assign \dev_23_req_o[amoop]  = n1932; //(module output)
  assign \dev_23_req_o[burst]  = n1933; //(module output)
  assign \dev_23_req_o[lock]  = n1934; //(module output)
  assign \dev_24_req_o[meta]  = n1937; //(module output)
  assign \dev_24_req_o[addr]  = n1938; //(module output)
  assign \dev_24_req_o[data]  = n1939; //(module output)
  assign \dev_24_req_o[ben]  = n1940; //(module output)
  assign \dev_24_req_o[stb]  = n1941; //(module output)
  assign \dev_24_req_o[rw]  = n1942; //(module output)
  assign \dev_24_req_o[amo]  = n1943; //(module output)
  assign \dev_24_req_o[amoop]  = n1944; //(module output)
  assign \dev_24_req_o[burst]  = n1945; //(module output)
  assign \dev_24_req_o[lock]  = n1946; //(module output)
  assign \dev_25_req_o[meta]  = n1949; //(module output)
  assign \dev_25_req_o[addr]  = n1950; //(module output)
  assign \dev_25_req_o[data]  = n1951; //(module output)
  assign \dev_25_req_o[ben]  = n1952; //(module output)
  assign \dev_25_req_o[stb]  = n1953; //(module output)
  assign \dev_25_req_o[rw]  = n1954; //(module output)
  assign \dev_25_req_o[amo]  = n1955; //(module output)
  assign \dev_25_req_o[amoop]  = n1956; //(module output)
  assign \dev_25_req_o[burst]  = n1957; //(module output)
  assign \dev_25_req_o[lock]  = n1958; //(module output)
  assign \dev_26_req_o[meta]  = n1961; //(module output)
  assign \dev_26_req_o[addr]  = n1962; //(module output)
  assign \dev_26_req_o[data]  = n1963; //(module output)
  assign \dev_26_req_o[ben]  = n1964; //(module output)
  assign \dev_26_req_o[stb]  = n1965; //(module output)
  assign \dev_26_req_o[rw]  = n1966; //(module output)
  assign \dev_26_req_o[amo]  = n1967; //(module output)
  assign \dev_26_req_o[amoop]  = n1968; //(module output)
  assign \dev_26_req_o[burst]  = n1969; //(module output)
  assign \dev_26_req_o[lock]  = n1970; //(module output)
  assign \dev_27_req_o[meta]  = n1973; //(module output)
  assign \dev_27_req_o[addr]  = n1974; //(module output)
  assign \dev_27_req_o[data]  = n1975; //(module output)
  assign \dev_27_req_o[ben]  = n1976; //(module output)
  assign \dev_27_req_o[stb]  = n1977; //(module output)
  assign \dev_27_req_o[rw]  = n1978; //(module output)
  assign \dev_27_req_o[amo]  = n1979; //(module output)
  assign \dev_27_req_o[amoop]  = n1980; //(module output)
  assign \dev_27_req_o[burst]  = n1981; //(module output)
  assign \dev_27_req_o[lock]  = n1982; //(module output)
  assign \dev_28_req_o[meta]  = n1985; //(module output)
  assign \dev_28_req_o[addr]  = n1986; //(module output)
  assign \dev_28_req_o[data]  = n1987; //(module output)
  assign \dev_28_req_o[ben]  = n1988; //(module output)
  assign \dev_28_req_o[stb]  = n1989; //(module output)
  assign \dev_28_req_o[rw]  = n1990; //(module output)
  assign \dev_28_req_o[amo]  = n1991; //(module output)
  assign \dev_28_req_o[amoop]  = n1992; //(module output)
  assign \dev_28_req_o[burst]  = n1993; //(module output)
  assign \dev_28_req_o[lock]  = n1994; //(module output)
  assign \dev_29_req_o[meta]  = n1997; //(module output)
  assign \dev_29_req_o[addr]  = n1998; //(module output)
  assign \dev_29_req_o[data]  = n1999; //(module output)
  assign \dev_29_req_o[ben]  = n2000; //(module output)
  assign \dev_29_req_o[stb]  = n2001; //(module output)
  assign \dev_29_req_o[rw]  = n2002; //(module output)
  assign \dev_29_req_o[amo]  = n2003; //(module output)
  assign \dev_29_req_o[amoop]  = n2004; //(module output)
  assign \dev_29_req_o[burst]  = n2005; //(module output)
  assign \dev_29_req_o[lock]  = n2006; //(module output)
  assign \dev_30_req_o[meta]  = n2009; //(module output)
  assign \dev_30_req_o[addr]  = n2010; //(module output)
  assign \dev_30_req_o[data]  = n2011; //(module output)
  assign \dev_30_req_o[ben]  = n2012; //(module output)
  assign \dev_30_req_o[stb]  = n2013; //(module output)
  assign \dev_30_req_o[rw]  = n2014; //(module output)
  assign \dev_30_req_o[amo]  = n2015; //(module output)
  assign \dev_30_req_o[amoop]  = n2016; //(module output)
  assign \dev_30_req_o[burst]  = n2017; //(module output)
  assign \dev_30_req_o[lock]  = n2018; //(module output)
  assign \dev_31_req_o[meta]  = n2021; //(module output)
  assign \dev_31_req_o[addr]  = n2022; //(module output)
  assign \dev_31_req_o[data]  = n2023; //(module output)
  assign \dev_31_req_o[ben]  = n2024; //(module output)
  assign \dev_31_req_o[stb]  = n2025; //(module output)
  assign \dev_31_req_o[rw]  = n2026; //(module output)
  assign \dev_31_req_o[amo]  = n2027; //(module output)
  assign \dev_31_req_o[amoop]  = n2028; //(module output)
  assign \dev_31_req_o[burst]  = n2029; //(module output)
  assign \dev_31_req_o[lock]  = n2030; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1643 = {\main_req_i[lock] , \main_req_i[burst] , \main_req_i[amoop] , \main_req_i[amo] , \main_req_i[rw] , \main_req_i[stb] , \main_req_i[ben] , \main_req_i[data] , \main_req_i[addr] , \main_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1645 = n2042[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1646 = n2042[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1647 = n2042[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1649 = n2049[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1650 = n2049[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1651 = n2049[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1652 = n2049[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1653 = n2049[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1654 = n2049[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1655 = n2049[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1656 = n2049[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1657 = n2049[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1658 = n2049[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1659 = {\dev_00_rsp_i[data] , \dev_00_rsp_i[err] , \dev_00_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1661 = n2050[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1662 = n2050[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1663 = n2050[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1664 = n2050[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1665 = n2050[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1666 = n2050[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1667 = n2050[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1668 = n2050[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1669 = n2050[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1670 = n2050[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1671 = {\dev_01_rsp_i[data] , \dev_01_rsp_i[err] , \dev_01_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1673 = n2051[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1674 = n2051[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1675 = n2051[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1676 = n2051[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1677 = n2051[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1678 = n2051[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1679 = n2051[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1680 = n2051[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1681 = n2051[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1682 = n2051[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1683 = {\dev_02_rsp_i[data] , \dev_02_rsp_i[err] , \dev_02_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1685 = n2052[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1686 = n2052[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1687 = n2052[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1688 = n2052[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1689 = n2052[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1690 = n2052[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1691 = n2052[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1692 = n2052[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1693 = n2052[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1694 = n2052[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1695 = {\dev_03_rsp_i[data] , \dev_03_rsp_i[err] , \dev_03_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1697 = n2053[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1698 = n2053[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1699 = n2053[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1700 = n2053[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1701 = n2053[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1702 = n2053[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1703 = n2053[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1704 = n2053[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1705 = n2053[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1706 = n2053[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1707 = {\dev_04_rsp_i[data] , \dev_04_rsp_i[err] , \dev_04_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1709 = n2054[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1710 = n2054[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1711 = n2054[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1712 = n2054[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1713 = n2054[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1714 = n2054[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1715 = n2054[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1716 = n2054[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1717 = n2054[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1718 = n2054[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1719 = {\dev_05_rsp_i[data] , \dev_05_rsp_i[err] , \dev_05_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1721 = n2055[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1722 = n2055[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1723 = n2055[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1724 = n2055[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1725 = n2055[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1726 = n2055[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1727 = n2055[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1728 = n2055[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1729 = n2055[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1730 = n2055[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1731 = {\dev_06_rsp_i[data] , \dev_06_rsp_i[err] , \dev_06_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1733 = n2056[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1734 = n2056[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1735 = n2056[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1736 = n2056[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1737 = n2056[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1738 = n2056[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1739 = n2056[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1740 = n2056[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1741 = n2056[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1742 = n2056[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1743 = {\dev_07_rsp_i[data] , \dev_07_rsp_i[err] , \dev_07_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1745 = n2057[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1746 = n2057[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1747 = n2057[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1748 = n2057[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1749 = n2057[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1750 = n2057[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1751 = n2057[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1752 = n2057[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1753 = n2057[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1754 = n2057[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1755 = {\dev_08_rsp_i[data] , \dev_08_rsp_i[err] , \dev_08_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1757 = n2058[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1758 = n2058[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1759 = n2058[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1760 = n2058[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1761 = n2058[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1762 = n2058[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1763 = n2058[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1764 = n2058[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1765 = n2058[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1766 = n2058[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1767 = {\dev_09_rsp_i[data] , \dev_09_rsp_i[err] , \dev_09_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1769 = n2059[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1770 = n2059[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1771 = n2059[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1772 = n2059[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1773 = n2059[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1774 = n2059[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1775 = n2059[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1776 = n2059[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1777 = n2059[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1778 = n2059[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1779 = {\dev_10_rsp_i[data] , \dev_10_rsp_i[err] , \dev_10_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1781 = n2060[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1782 = n2060[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1783 = n2060[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1784 = n2060[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1785 = n2060[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1786 = n2060[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1787 = n2060[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1788 = n2060[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1789 = n2060[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1790 = n2060[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1791 = {\dev_11_rsp_i[data] , \dev_11_rsp_i[err] , \dev_11_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1793 = n2061[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1794 = n2061[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1795 = n2061[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1796 = n2061[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1797 = n2061[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1798 = n2061[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1799 = n2061[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1800 = n2061[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1801 = n2061[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1802 = n2061[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1803 = {\dev_12_rsp_i[data] , \dev_12_rsp_i[err] , \dev_12_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1805 = n2062[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1806 = n2062[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1807 = n2062[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1808 = n2062[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1809 = n2062[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1810 = n2062[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1811 = n2062[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1812 = n2062[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1813 = n2062[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1814 = n2062[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1815 = {\dev_13_rsp_i[data] , \dev_13_rsp_i[err] , \dev_13_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1817 = n2063[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1818 = n2063[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1819 = n2063[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1820 = n2063[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1821 = n2063[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1822 = n2063[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1823 = n2063[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1824 = n2063[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1825 = n2063[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1826 = n2063[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1827 = {\dev_14_rsp_i[data] , \dev_14_rsp_i[err] , \dev_14_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1829 = n2064[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1830 = n2064[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1831 = n2064[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1832 = n2064[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1833 = n2064[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1834 = n2064[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1835 = n2064[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1836 = n2064[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1837 = n2064[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1838 = n2064[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1839 = {\dev_15_rsp_i[data] , \dev_15_rsp_i[err] , \dev_15_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1841 = n2065[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1842 = n2065[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1843 = n2065[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1844 = n2065[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1845 = n2065[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1846 = n2065[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1847 = n2065[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1848 = n2065[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1849 = n2065[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1850 = n2065[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1851 = {\dev_16_rsp_i[data] , \dev_16_rsp_i[err] , \dev_16_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1853 = n2066[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1854 = n2066[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1855 = n2066[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1856 = n2066[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1857 = n2066[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1858 = n2066[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1859 = n2066[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1860 = n2066[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1861 = n2066[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1862 = n2066[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1863 = {\dev_17_rsp_i[data] , \dev_17_rsp_i[err] , \dev_17_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1865 = n2067[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1866 = n2067[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1867 = n2067[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1868 = n2067[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1869 = n2067[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1870 = n2067[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1871 = n2067[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1872 = n2067[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1873 = n2067[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1874 = n2067[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1875 = {\dev_18_rsp_i[data] , \dev_18_rsp_i[err] , \dev_18_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1877 = n2068[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1878 = n2068[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1879 = n2068[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1880 = n2068[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1881 = n2068[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1882 = n2068[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1883 = n2068[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1884 = n2068[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1885 = n2068[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1886 = n2068[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1887 = {\dev_19_rsp_i[data] , \dev_19_rsp_i[err] , \dev_19_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1889 = n2069[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1890 = n2069[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1891 = n2069[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1892 = n2069[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1893 = n2069[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1894 = n2069[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1895 = n2069[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1896 = n2069[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1897 = n2069[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1898 = n2069[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1899 = {\dev_20_rsp_i[data] , \dev_20_rsp_i[err] , \dev_20_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1901 = n2070[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1902 = n2070[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1903 = n2070[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1904 = n2070[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1905 = n2070[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1906 = n2070[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1907 = n2070[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1908 = n2070[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1909 = n2070[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1910 = n2070[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1911 = {\dev_21_rsp_i[data] , \dev_21_rsp_i[err] , \dev_21_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1913 = n2071[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1914 = n2071[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1915 = n2071[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1916 = n2071[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1917 = n2071[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1918 = n2071[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1919 = n2071[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1920 = n2071[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1921 = n2071[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1922 = n2071[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1923 = {\dev_22_rsp_i[data] , \dev_22_rsp_i[err] , \dev_22_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1925 = n2072[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1926 = n2072[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1927 = n2072[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1928 = n2072[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1929 = n2072[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1930 = n2072[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1931 = n2072[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1932 = n2072[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1933 = n2072[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1934 = n2072[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1935 = {\dev_23_rsp_i[data] , \dev_23_rsp_i[err] , \dev_23_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1937 = n2073[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1938 = n2073[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1939 = n2073[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1940 = n2073[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1941 = n2073[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1942 = n2073[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1943 = n2073[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1944 = n2073[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1945 = n2073[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1946 = n2073[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1947 = {\dev_24_rsp_i[data] , \dev_24_rsp_i[err] , \dev_24_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1949 = n2074[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1950 = n2074[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1951 = n2074[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1952 = n2074[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1953 = n2074[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1954 = n2074[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1955 = n2074[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1956 = n2074[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1957 = n2074[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1958 = n2074[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1959 = {\dev_25_rsp_i[data] , \dev_25_rsp_i[err] , \dev_25_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1961 = n2075[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1962 = n2075[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1963 = n2075[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1964 = n2075[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1965 = n2075[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1966 = n2075[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1967 = n2075[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1968 = n2075[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1969 = n2075[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1970 = n2075[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1971 = {\dev_26_rsp_i[data] , \dev_26_rsp_i[err] , \dev_26_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1973 = n2076[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1974 = n2076[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1975 = n2076[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1976 = n2076[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1977 = n2076[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1978 = n2076[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1979 = n2076[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1980 = n2076[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1981 = n2076[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1982 = n2076[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1983 = {\dev_27_rsp_i[data] , \dev_27_rsp_i[err] , \dev_27_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1985 = n2077[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1986 = n2077[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1987 = n2077[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1988 = n2077[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1989 = n2077[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1990 = n2077[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1991 = n2077[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1992 = n2077[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1993 = n2077[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1994 = n2077[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1995 = {\dev_28_rsp_i[data] , \dev_28_rsp_i[err] , \dev_28_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1997 = n2078[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1998 = n2078[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n1999 = n2078[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2000 = n2078[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2001 = n2078[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2002 = n2078[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2003 = n2078[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2004 = n2078[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2005 = n2078[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2006 = n2078[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2007 = {\dev_29_rsp_i[data] , \dev_29_rsp_i[err] , \dev_29_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2009 = n2079[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2010 = n2079[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2011 = n2079[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2012 = n2079[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2013 = n2079[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2014 = n2079[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2015 = n2079[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2016 = n2079[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2017 = n2079[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2018 = n2079[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2019 = {\dev_30_rsp_i[data] , \dev_30_rsp_i[err] , \dev_30_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2021 = n2080[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2022 = n2080[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2023 = n2080[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2024 = n2080[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2025 = n2080[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2026 = n2080[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2027 = n2080[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2028 = n2080[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2029 = n2080[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2030 = n2080[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:523:8 */
  assign n2031 = {\dev_31_rsp_i[data] , \dev_31_rsp_i[err] , \dev_31_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign dev_req = n2134; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:634:10 */
  assign dev_rsp = n2135; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:637:10 */
  assign main_req = n2044; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:638:10 */
  assign main_rsp = n2131; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  neorv32_bus_reg_Bneorv32_bus_reg_rtl_Lneorv32_9159cb8bcee7fcb95582f140960cdae72788d326 neorv32_bus_reg_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\host_req_i[meta] (n2032),
    .\host_req_i[addr] (n2033),
    .\host_req_i[data] (n2034),
    .\host_req_i[ben] (n2035),
    .\host_req_i[stb] (n2036),
    .\host_req_i[rw] (n2037),
    .\host_req_i[amo] (n2038),
    .\host_req_i[amoop] (n2039),
    .\host_req_i[burst] (n2040),
    .\host_req_i[lock] (n2041),
    .\device_rsp_i[ack] (n2046),
    .\device_rsp_i[err] (n2047),
    .\device_rsp_i[data] (n2048),
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
  assign n2032 = n1643[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2033 = n1643[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2034 = n1643[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2035 = n1643[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2036 = n1643[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2037 = n1643[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2038 = n1643[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2039 = n1643[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2040 = n1643[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2041 = n1643[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2042 = {\neorv32_bus_reg_inst.host_rsp_o[data] , \neorv32_bus_reg_inst.host_rsp_o[err] , \neorv32_bus_reg_inst.host_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2044 = {\neorv32_bus_reg_inst.device_req_o[lock] , \neorv32_bus_reg_inst.device_req_o[burst] , \neorv32_bus_reg_inst.device_req_o[amoop] , \neorv32_bus_reg_inst.device_req_o[amo] , \neorv32_bus_reg_inst.device_req_o[rw] , \neorv32_bus_reg_inst.device_req_o[stb] , \neorv32_bus_reg_inst.device_req_o[ben] , \neorv32_bus_reg_inst.device_req_o[data] , \neorv32_bus_reg_inst.device_req_o[addr] , \neorv32_bus_reg_inst.device_req_o[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2046 = main_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2047 = main_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:644:3 */
  assign n2048 = main_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:662:26 */
  assign n2049 = dev_req[2623:2542]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:663:26 */
  assign n2050 = dev_req[2541:2460]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:664:26 */
  assign n2051 = dev_req[2459:2378]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:665:26 */
  assign n2052 = dev_req[2377:2296]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:666:26 */
  assign n2053 = dev_req[2295:2214]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:667:26 */
  assign n2054 = dev_req[2213:2132]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:668:26 */
  assign n2055 = dev_req[2131:2050]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:669:26 */
  assign n2056 = dev_req[2049:1968]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:670:26 */
  assign n2057 = dev_req[1967:1886]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:671:26 */
  assign n2058 = dev_req[1885:1804]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:672:26 */
  assign n2059 = dev_req[1803:1722]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:673:26 */
  assign n2060 = dev_req[1721:1640]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:674:26 */
  assign n2061 = dev_req[1639:1558]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:675:26 */
  assign n2062 = dev_req[1557:1476]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:676:26 */
  assign n2063 = dev_req[1475:1394]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:677:26 */
  assign n2064 = dev_req[1393:1312]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:678:26 */
  assign n2065 = dev_req[1311:1230]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:679:26 */
  assign n2066 = dev_req[1229:1148]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:680:26 */
  assign n2067 = dev_req[1147:1066]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:681:26 */
  assign n2068 = dev_req[1065:984]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:682:26 */
  assign n2069 = dev_req[983:902]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:683:26 */
  assign n2070 = dev_req[901:820]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:684:26 */
  assign n2071 = dev_req[819:738]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:685:26 */
  assign n2072 = dev_req[737:656]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:686:26 */
  assign n2073 = dev_req[655:574]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:687:26 */
  assign n2074 = dev_req[573:492]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:688:26 */
  assign n2075 = dev_req[491:410]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:689:26 */
  assign n2076 = dev_req[409:328]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:690:26 */
  assign n2077 = dev_req[327:246]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:691:26 */
  assign n2078 = dev_req[245:164]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:692:26 */
  assign n2079 = dev_req[163:82]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:693:26 */
  assign n2080 = dev_req[81:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:26 */
  assign n2083 = main_req[25:21]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:55 */
  assign n2085 = n2083 == 5'b10101;
  /*# ../../rtl/core/neorv32_bus.vhd:706:38 */
  assign n2086 = main_req[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:9 */
  assign n2088 = n2085 ? n2086 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2089 = main_req[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2090 = main_req[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:26 */
  assign n2093 = main_req[25:21]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:55 */
  assign n2095 = n2093 == 5'b11110;
  /*# ../../rtl/core/neorv32_bus.vhd:706:38 */
  assign n2096 = main_req[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:705:9 */
  assign n2098 = n2095 ? n2096 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2099 = main_req[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2100 = main_req[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:29 */
  assign n2105 = n2104[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:48 */
  assign n2106 = dev_rsp[373:342]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:34 */
  assign n2107 = n2105 | n2106;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2109 = n2108[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2110 = {n2107, n2109};
  /*# ../../rtl/core/neorv32_bus.vhd:729:29 */
  assign n2111 = n2110[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:48 */
  assign n2112 = dev_rsp[340]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:34 */
  assign n2113 = n2111 | n2112;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2114 = n2108[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2115 = {n2107, n2114, n2113};
  /*# ../../rtl/core/neorv32_bus.vhd:730:29 */
  assign n2116 = n2115[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:48 */
  assign n2117 = dev_rsp[341]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:34 */
  assign n2118 = n2116 | n2117;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2119 = {n2107, n2118, n2113};
  /*# ../../rtl/core/neorv32_bus.vhd:728:29 */
  assign n2120 = n2119[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:48 */
  assign n2121 = dev_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:728:34 */
  assign n2122 = n2120 | n2121;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2123 = {n2122, n2118, n2113};
  /*# ../../rtl/core/neorv32_bus.vhd:729:29 */
  assign n2124 = n2123[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:48 */
  assign n2125 = dev_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:729:34 */
  assign n2126 = n2124 | n2125;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2127 = {n2122, n2118, n2126};
  /*# ../../rtl/core/neorv32_bus.vhd:730:29 */
  assign n2128 = n2127[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:48 */
  assign n2129 = dev_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:730:34 */
  assign n2130 = n2128 | n2129;
  /*# ../../rtl/core/neorv32_bus.vhd:723:14 */
  assign n2131 = {n2122, n2130, n2126};
  /*# ../../rtl/core/neorv32_bus.vhd:633:10 */
  assign n2134 = {82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n2089, n2088, n2090, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n2099, n2098, n2100, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_bus.vhd:634:10 */
  assign n2135 = {n1659, n1671, n1683, n1695, n1707, n1719, n1731, n1743, n1755, n1767, n1779, n1791, n1803, n1815, n1827, n1839, n1851, n1863, n1875, n1887, n1899, n1911, n1923, n1935, n1947, n1959, n1971, n1983, n1995, n2007, n2019, n2031};
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
  wire [81:0] n1600;
  wire n1602;
  wire n1603;
  wire [31:0] n1604;
  wire [31:0] rdata;
  wire wren;
  wire [1:0] rden;
  wire [3:0] ben;
  wire n1605;
  wire [31:0] n1606;
  wire [31:0] n1607;
  wire [31:0] dmem_ram_inst_n1608;
  wire [3:0] n1611;
  wire n1612;
  wire [3:0] n1613;
  wire n1616;
  wire n1618;
  wire n1619;
  wire n1620;
  wire n1621;
  wire n1622;
  wire n1623;
  wire n1624;
  wire n1625;
  wire [1:0] n1626;
  wire n1634;
  wire [31:0] n1635;
  wire n1638;
  wire n1639;
  wire [33:0] n1640;
  reg n1641;
  reg [1:0] n1642;
  assign \bus_rsp_o[ack]  = n1602; //(module output)
  assign \bus_rsp_o[err]  = n1603; //(module output)
  assign \bus_rsp_o[data]  = n1604; //(module output)
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1600 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1602 = n1640[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1603 = n1640[1]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:17:8 */
  assign n1604 = n1640[33:2]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:55:10 */
  assign rdata = dmem_ram_inst_n1608; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:56:10 */
  assign wren = n1641; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:57:10 */
  assign rden = n1642; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:58:10 */
  assign ben = n1613; // (signal)
  /*# ../../rtl/core/neorv32_dmem.vhd:72:25 */
  assign n1605 = n1600[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:73:25 */
  assign n1606 = n1600[36:5]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:74:25 */
  assign n1607 = n1600[68:37]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:64:3 */
  neorv32_dmem_ram_Bneorv32_dmem_ram_rtl_Lneorv32_14_0 dmem_ram_inst (
    .clk_i(clk_i),
    .en_i(ben),
    .rw_i(n1605),
    .addr_i(n1606),
    .data_i(n1607),
    .data_o(dmem_ram_inst_n1608));
  /*# ../../rtl/core/neorv32_dmem.vhd:79:20 */
  assign n1611 = n1600[72:69]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:79:40 */
  assign n1612 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:79:24 */
  assign n1613 = n1612 ? n1611 : 4'b0000;
  /*# ../../rtl/core/neorv32_dmem.vhd:85:16 */
  assign n1616 = ~rstn_i;
  /*# ../../rtl/core/neorv32_dmem.vhd:89:25 */
  assign n1618 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:89:43 */
  assign n1619 = n1600[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:89:29 */
  assign n1620 = n1618 & n1619;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:19 */
  assign n1621 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:36 */
  assign n1622 = n1600[73]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:59 */
  assign n1623 = n1600[74]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:90:45 */
  assign n1624 = ~n1623;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:40 */
  assign n1625 = n1622 & n1624;
  /*# ../../rtl/core/neorv32_dmem.vhd:90:23 */
  assign n1626 = {n1621, n1625};
  /*# ../../rtl/core/neorv32_dmem.vhd:94:37 */
  assign n1634 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:94:27 */
  assign n1635 = n1634 ? rdata : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_dmem.vhd:96:25 */
  assign n1638 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_dmem.vhd:96:36 */
  assign n1639 = n1638 | wren;
  /*# ../../rtl/core/neorv32_dmem.vhd:26:5 */
  assign n1640 = {n1635, 1'b0, n1639};
  /*# ../../rtl/core/neorv32_dmem.vhd:88:5 */
  always @(posedge clk_i or posedge n1616)
    if (n1616)
      n1641 <= 1'b0;
    else
      n1641 <= n1620;
  /*# ../../rtl/core/neorv32_dmem.vhd:88:5 */
  always @(posedge clk_i or posedge n1616)
    if (n1616)
      n1642 <= 2'b00;
    else
      n1642 <= n1626;
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
  wire [81:0] n1555;
  wire n1557;
  wire n1558;
  wire [31:0] n1559;
  wire [31:0] rdata;
  wire wren;
  wire [1:0] rden;
  wire n1560;
  wire [31:0] n1561;
  wire [31:0] imem_rom_imem_rom_inst_n1562;
  wire n1570;
  wire n1572;
  wire n1573;
  wire n1574;
  wire n1575;
  wire n1576;
  wire n1577;
  wire n1578;
  wire n1579;
  wire [1:0] n1580;
  wire n1588;
  wire [31:0] n1589;
  wire n1592;
  wire n1594;
  wire n1595;
  wire n1596;
  wire [33:0] n1597;
  reg n1598;
  reg [1:0] n1599;
  assign \bus_rsp_o[ack]  = n1557; //(module output)
  assign \bus_rsp_o[err]  = n1558; //(module output)
  assign \bus_rsp_o[data]  = n1559; //(module output)
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1555 = {\bus_req_i[lock] , \bus_req_i[burst] , \bus_req_i[amoop] , \bus_req_i[amo] , \bus_req_i[rw] , \bus_req_i[stb] , \bus_req_i[ben] , \bus_req_i[data] , \bus_req_i[addr] , \bus_req_i[meta] };
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1557 = n1597[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1558 = n1597[1]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:17:8 */
  assign n1559 = n1597[33:2]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:72:10 */
  assign rdata = imem_rom_imem_rom_inst_n1562; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:73:10 */
  assign wren = n1598; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:74:10 */
  assign rden = n1599; // (signal)
  /*# ../../rtl/core/neorv32_imem.vhd:90:27 */
  assign n1560 = n1555[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:91:27 */
  assign n1561 = n1555[36:5]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:83:5 */
  neorv32_imem_rom_Bneorv32_imem_rom_rtl_Lneorv32_14_0 imem_rom_imem_rom_inst (
    .clk_i(clk_i),
    .en_i(n1560),
    .addr_i(n1561),
    .data_o(imem_rom_imem_rom_inst_n1562));
  /*# ../../rtl/core/neorv32_imem.vhd:122:16 */
  assign n1570 = ~rstn_i;
  /*# ../../rtl/core/neorv32_imem.vhd:126:25 */
  assign n1572 = n1555[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:126:43 */
  assign n1573 = n1555[74]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:126:29 */
  assign n1574 = n1572 & n1573;
  /*# ../../rtl/core/neorv32_imem.vhd:127:19 */
  assign n1575 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:36 */
  assign n1576 = n1555[73]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:59 */
  assign n1577 = n1555[74]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:127:45 */
  assign n1578 = ~n1577;
  /*# ../../rtl/core/neorv32_imem.vhd:127:40 */
  assign n1579 = n1576 & n1578;
  /*# ../../rtl/core/neorv32_imem.vhd:127:23 */
  assign n1580 = {n1575, n1579};
  /*# ../../rtl/core/neorv32_imem.vhd:132:37 */
  assign n1588 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:132:27 */
  assign n1589 = n1588 ? rdata : 32'b00000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_imem.vhd:134:25 */
  assign n1592 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:134:36 */
  assign n1594 = 1'b1 ? n1592 : n1596;
  /*# ../../rtl/core/neorv32_imem.vhd:134:60 */
  assign n1595 = rden[0]; // extract
  /*# ../../rtl/core/neorv32_imem.vhd:134:71 */
  assign n1596 = n1595 | wren;
  /*# ../../rtl/core/neorv32_imem.vhd:27:5 */
  assign n1597 = {n1589, 1'b0, n1594};
  /*# ../../rtl/core/neorv32_imem.vhd:125:5 */
  always @(posedge clk_i or posedge n1570)
    if (n1570)
      n1598 <= 1'b0;
    else
      n1598 <= n1574;
  /*# ../../rtl/core/neorv32_imem.vhd:125:5 */
  always @(posedge clk_i or posedge n1570)
    if (n1570)
      n1599 <= 2'b00;
    else
      n1599 <= n1580;
endmodule

module neorv32_bus_gateway_Bneorv32_bus_gateway_rtl_Lneorv32_16384_16_16384_16_268435456_2048_2097152_16_2048_7f8345992e02d837ae3d2c5e4eea30e3ae29fc9f
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
  wire [81:0] n1280;
  wire n1282;
  wire n1283;
  wire [31:0] n1284;
  wire [4:0] n1286;
  wire [31:0] n1287;
  wire [31:0] n1288;
  wire [3:0] n1289;
  wire n1290;
  wire n1291;
  wire n1292;
  wire [3:0] n1293;
  wire n1294;
  wire n1295;
  wire [33:0] n1296;
  wire [4:0] n1298;
  wire [31:0] n1299;
  wire [31:0] n1300;
  wire [3:0] n1301;
  wire n1302;
  wire n1303;
  wire n1304;
  wire [3:0] n1305;
  wire n1306;
  wire n1307;
  wire [33:0] n1308;
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
  wire [4:0] port_sel;
  wire [4:0] tmo_bits;
  wire tmo_fire;
  wire [409:0] port_req;
  wire [169:0] port_rsp;
  wire [33:0] int_rsp;
  wire [19:0] keeper;
  wire bus_err;
  wire [17:0] n1346;
  wire n1348;
  wire n1350;
  wire n1351;
  wire [17:0] n1354;
  wire n1356;
  wire n1358;
  wire n1359;
  wire n1363;
  wire [10:0] n1366;
  wire n1368;
  wire n1370;
  wire n1371;
  wire n1375;
  wire [81:0] n1377;
  wire [81:0] n1378;
  wire [81:0] n1379;
  wire [81:0] n1380;
  wire [81:0] n1381;
  wire n1384;
  wire n1385;
  wire n1386;
  wire [7:0] n1387;
  wire [72:0] n1388;
  wire n1389;
  wire n1390;
  wire n1391;
  wire [7:0] n1392;
  wire [72:0] n1393;
  wire n1394;
  wire n1395;
  wire n1396;
  wire [7:0] n1397;
  wire [72:0] n1398;
  localparam [33:0] n1402 = 34'b0000000000000000000000000000000000;
  wire [31:0] n1403;
  wire [31:0] n1404;
  wire [31:0] n1405;
  localparam [33:0] n1406 = 34'b0000000000000000000000000000000000;
  wire [1:0] n1407;
  wire [33:0] n1408;
  wire n1409;
  wire n1410;
  wire n1411;
  wire n1412;
  wire [33:0] n1413;
  wire n1414;
  wire n1415;
  wire n1416;
  wire [33:0] n1417;
  wire [31:0] n1418;
  wire [31:0] n1419;
  wire [31:0] n1420;
  wire [33:0] n1421;
  wire n1422;
  wire n1423;
  wire n1424;
  wire [33:0] n1425;
  wire n1426;
  wire n1427;
  wire n1428;
  wire [33:0] n1429;
  wire [31:0] n1430;
  wire [31:0] n1431;
  wire [31:0] n1432;
  wire [33:0] n1433;
  wire n1434;
  wire n1435;
  wire n1436;
  wire [33:0] n1437;
  wire n1438;
  wire n1439;
  wire n1440;
  wire [33:0] n1441;
  wire [31:0] n1444;
  wire n1445;
  wire n1446;
  wire n1447;
  wire n1448;
  wire n1450;
  wire [1:0] n1456;
  wire n1457;
  wire n1459;
  wire [1:0] n1461;
  wire [1:0] n1462;
  wire n1464;
  wire n1465;
  wire [11:0] n1467;
  wire [11:0] n1469;
  wire [11:0] n1470;
  wire n1472;
  wire n1473;
  wire n1474;
  wire [1:0] n1476;
  wire [1:0] n1477;
  wire n1478;
  wire [1:0] n1480;
  wire [1:0] n1481;
  wire [1:0] n1482;
  wire [1:0] n1483;
  wire n1485;
  wire n1486;
  wire n1487;
  wire n1488;
  wire n1489;
  wire n1490;
  wire [1:0] n1492;
  wire [1:0] n1493;
  wire [1:0] n1494;
  reg [1:0] n1495;
  wire n1496;
  reg n1497;
  wire [4:0] n1498;
  reg [4:0] n1499;
  wire [11:0] n1500;
  reg [11:0] n1501;
  wire [19:0] n1502;
  wire [19:0] n1504;
  wire n1507;
  wire n1509;
  wire n1511;
  wire n1513;
  wire n1515;
  wire n1517;
  wire n1519;
  wire n1521;
  wire n1523;
  wire n1525;
  wire [4:0] n1528;
  wire [4:0] n1529;
  wire n1535;
  wire n1537;
  wire n1539;
  wire n1540;
  wire n1541;
  wire n1542;
  wire n1543;
  wire n1544;
  wire n1545;
  wire n1546;
  wire n1547;
  wire n1548;
  wire [4:0] n1549;
  wire [4:0] n1550;
  wire [409:0] n1551;
  wire [169:0] n1552;
  wire [33:0] n1553;
  reg [19:0] n1554;
  assign term_o = n1548; //(module output)
  assign \rsp_o[ack]  = n1282; //(module output)
  assign \rsp_o[err]  = n1283; //(module output)
  assign \rsp_o[data]  = n1284; //(module output)
  assign \a_req_o[meta]  = n1286; //(module output)
  assign \a_req_o[addr]  = n1287; //(module output)
  assign \a_req_o[data]  = n1288; //(module output)
  assign \a_req_o[ben]  = n1289; //(module output)
  assign \a_req_o[stb]  = n1290; //(module output)
  assign \a_req_o[rw]  = n1291; //(module output)
  assign \a_req_o[amo]  = n1292; //(module output)
  assign \a_req_o[amoop]  = n1293; //(module output)
  assign \a_req_o[burst]  = n1294; //(module output)
  assign \a_req_o[lock]  = n1295; //(module output)
  assign \b_req_o[meta]  = n1298; //(module output)
  assign \b_req_o[addr]  = n1299; //(module output)
  assign \b_req_o[data]  = n1300; //(module output)
  assign \b_req_o[ben]  = n1301; //(module output)
  assign \b_req_o[stb]  = n1302; //(module output)
  assign \b_req_o[rw]  = n1303; //(module output)
  assign \b_req_o[amo]  = n1304; //(module output)
  assign \b_req_o[amoop]  = n1305; //(module output)
  assign \b_req_o[burst]  = n1306; //(module output)
  assign \b_req_o[lock]  = n1307; //(module output)
  assign \c_req_o[meta]  = n1310; //(module output)
  assign \c_req_o[addr]  = n1311; //(module output)
  assign \c_req_o[data]  = n1312; //(module output)
  assign \c_req_o[ben]  = n1313; //(module output)
  assign \c_req_o[stb]  = n1314; //(module output)
  assign \c_req_o[rw]  = n1315; //(module output)
  assign \c_req_o[amo]  = n1316; //(module output)
  assign \c_req_o[amoop]  = n1317; //(module output)
  assign \c_req_o[burst]  = n1318; //(module output)
  assign \c_req_o[lock]  = n1319; //(module output)
  assign \d_req_o[meta]  = n1322; //(module output)
  assign \d_req_o[addr]  = n1323; //(module output)
  assign \d_req_o[data]  = n1324; //(module output)
  assign \d_req_o[ben]  = n1325; //(module output)
  assign \d_req_o[stb]  = n1326; //(module output)
  assign \d_req_o[rw]  = n1327; //(module output)
  assign \d_req_o[amo]  = n1328; //(module output)
  assign \d_req_o[amoop]  = n1329; //(module output)
  assign \d_req_o[burst]  = n1330; //(module output)
  assign \d_req_o[lock]  = n1331; //(module output)
  assign \x_req_o[meta]  = n1334; //(module output)
  assign \x_req_o[addr]  = n1335; //(module output)
  assign \x_req_o[data]  = n1336; //(module output)
  assign \x_req_o[ben]  = n1337; //(module output)
  assign \x_req_o[stb]  = n1338; //(module output)
  assign \x_req_o[rw]  = n1339; //(module output)
  assign \x_req_o[amo]  = n1340; //(module output)
  assign \x_req_o[amoop]  = n1341; //(module output)
  assign \x_req_o[burst]  = n1342; //(module output)
  assign \x_req_o[lock]  = n1343; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1280 = {\req_i[lock] , \req_i[burst] , \req_i[amoop] , \req_i[amo] , \req_i[rw] , \req_i[stb] , \req_i[ben] , \req_i[data] , \req_i[addr] , \req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1282 = n1553[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1283 = n1553[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1284 = n1553[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1286 = n1377[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1287 = n1377[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1288 = n1377[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1289 = n1377[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1290 = n1377[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1291 = n1377[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1292 = n1377[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1293 = n1377[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1294 = n1377[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1295 = n1377[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1296 = {\a_rsp_i[data] , \a_rsp_i[err] , \a_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1298 = n1378[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1299 = n1378[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1300 = n1378[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1301 = n1378[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1302 = n1378[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1303 = n1378[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1304 = n1378[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1305 = n1378[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1306 = n1378[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1307 = n1378[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1308 = {\b_rsp_i[data] , \b_rsp_i[err] , \b_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1310 = n1379[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1311 = n1379[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1312 = n1379[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1313 = n1379[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1314 = n1379[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1315 = n1379[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1316 = n1379[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1317 = n1379[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1318 = n1379[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1319 = n1379[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1320 = {\c_rsp_i[data] , \c_rsp_i[err] , \c_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1322 = n1380[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1323 = n1380[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1324 = n1380[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1325 = n1380[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1326 = n1380[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1327 = n1380[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1328 = n1380[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1329 = n1380[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1330 = n1380[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1331 = n1380[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1332 = {\d_rsp_i[data] , \d_rsp_i[err] , \d_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1334 = n1381[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1335 = n1381[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1336 = n1381[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1337 = n1381[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1338 = n1381[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1339 = n1381[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1340 = n1381[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1341 = n1381[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1342 = n1381[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1343 = n1381[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:264:8 */
  assign n1344 = {\x_rsp_i[data] , \x_rsp_i[err] , \x_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:319:10 */
  assign port_sel = n1549; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:350:10 */
  assign tmo_bits = n1550; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:351:10 */
  assign tmo_fire = n1546; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign port_req = n1551; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:371:10 */
  assign port_rsp = n1552; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:374:10 */
  assign int_rsp = n1441; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign keeper = n1554; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:384:10 */
  assign bus_err = n1547; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:390:47 */
  assign n1346 = n1280[36:19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:390:66 */
  assign n1348 = n1346 == 18'b000000000000000000;
  /*# ../../rtl/core/neorv32_bus.vhd:390:32 */
  assign n1350 = n1348 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:390:22 */
  assign n1351 = n1350 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:391:47 */
  assign n1354 = n1280[36:19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:391:66 */
  assign n1356 = n1354 == 18'b100000000000000000;
  /*# ../../rtl/core/neorv32_bus.vhd:391:32 */
  assign n1358 = n1356 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:391:22 */
  assign n1359 = n1358 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:392:22 */
  assign n1363 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:393:47 */
  assign n1366 = n1280[36:26]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:393:66 */
  assign n1368 = n1366 == 11'b11111111111;
  /*# ../../rtl/core/neorv32_bus.vhd:393:32 */
  assign n1370 = n1368 & 1'b1;
  /*# ../../rtl/core/neorv32_bus.vhd:393:22 */
  assign n1371 = n1370 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:394:22 */
  assign n1375 = 1'b0 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:398:22 */
  assign n1377 = port_req[409:328]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:399:22 */
  assign n1378 = port_req[327:246]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:400:22 */
  assign n1379 = port_req[245:164]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:401:22 */
  assign n1380 = port_req[163:82]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:402:22 */
  assign n1381 = port_req[81:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1384 = n1280[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1385 = port_sel[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1386 = n1384 & n1385;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1387 = n1280[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1388 = n1280[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1389 = n1280[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1390 = port_sel[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1391 = n1389 & n1390;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1392 = n1280[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1393 = n1280[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:34 */
  assign n1394 = n1280[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:50 */
  assign n1395 = port_sel[3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:411:38 */
  assign n1396 = n1394 & n1395;
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1397 = n1280[81:74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1398 = n1280[72:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1403 = n1402[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1404 = port_rsp[169:138]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1405 = n1403 | n1404;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1407 = n1406[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1408 = {n1405, n1407};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1409 = n1408[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1410 = port_rsp[136]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1411 = n1409 | n1410;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1412 = n1406[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1413 = {n1405, n1412, n1411};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1414 = n1413[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1415 = port_rsp[137]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1416 = n1414 | n1415;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1417 = {n1405, n1416, n1411};
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1418 = n1417[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1419 = port_rsp[135:104]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1420 = n1418 | n1419;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1421 = {n1420, n1416, n1411};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1422 = n1421[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1423 = port_rsp[102]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1424 = n1422 | n1423;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1425 = {n1420, n1416, n1424};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1426 = n1425[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1427 = port_rsp[103]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1428 = n1426 | n1427;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1429 = {n1420, n1428, n1424};
  /*# ../../rtl/core/neorv32_bus.vhd:423:29 */
  assign n1430 = n1429[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:49 */
  assign n1431 = port_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:423:34 */
  assign n1432 = n1430 | n1431;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1433 = {n1432, n1428, n1424};
  /*# ../../rtl/core/neorv32_bus.vhd:424:29 */
  assign n1434 = n1433[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:49 */
  assign n1435 = port_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:424:34 */
  assign n1436 = n1434 | n1435;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1437 = {n1432, n1428, n1436};
  /*# ../../rtl/core/neorv32_bus.vhd:425:29 */
  assign n1438 = n1437[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:49 */
  assign n1439 = port_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:425:34 */
  assign n1440 = n1438 | n1439;
  /*# ../../rtl/core/neorv32_bus.vhd:418:14 */
  assign n1441 = {n1432, n1440, n1436};
  /*# ../../rtl/core/neorv32_bus.vhd:432:25 */
  assign n1444 = int_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:433:25 */
  assign n1445 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:433:29 */
  assign n1446 = n1445 | bus_err;
  /*# ../../rtl/core/neorv32_bus.vhd:434:25 */
  assign n1447 = int_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:434:29 */
  assign n1448 = n1447 | bus_err;
  /*# ../../rtl/core/neorv32_bus.vhd:440:16 */
  assign n1450 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:446:19 */
  assign n1456 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:450:32 */
  assign n1457 = n1280[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:453:21 */
  assign n1459 = n1280[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1461 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:453:11 */
  assign n1462 = n1459 ? 2'b01 : n1461;
  /*# ../../rtl/core/neorv32_bus.vhd:448:9 */
  assign n1464 = n1456 == 2'b00;
  /*# ../../rtl/core/neorv32_bus.vhd:460:23 */
  assign n1465 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:463:61 */
  assign n1467 = keeper[19:8]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:463:66 */
  assign n1469 = n1467 + 12'b000000000001;
  /*# ../../rtl/core/neorv32_bus.vhd:460:11 */
  assign n1470 = n1465 ? 12'b000000000000 : n1469;
  /*# ../../rtl/core/neorv32_bus.vhd:468:25 */
  assign n1472 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:23 */
  assign n1473 = n1280[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:28 */
  assign n1474 = ~n1473;
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1476 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:469:13 */
  assign n1477 = n1474 ? 2'b00 : n1476;
  /*# ../../rtl/core/neorv32_bus.vhd:472:26 */
  assign n1478 = int_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1480 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:472:11 */
  assign n1481 = n1478 ? 2'b00 : n1480;
  /*# ../../rtl/core/neorv32_bus.vhd:468:11 */
  assign n1482 = n1472 ? n1477 : n1481;
  /*# ../../rtl/core/neorv32_bus.vhd:466:11 */
  assign n1483 = tmo_fire ? 2'b11 : n1482;
  /*# ../../rtl/core/neorv32_bus.vhd:457:9 */
  assign n1485 = n1456 == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:478:22 */
  assign n1486 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:27 */
  assign n1487 = ~n1486;
  /*# ../../rtl/core/neorv32_bus.vhd:478:44 */
  assign n1488 = n1280[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:49 */
  assign n1489 = ~n1488;
  /*# ../../rtl/core/neorv32_bus.vhd:478:34 */
  assign n1490 = n1487 | n1489;
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1492 = keeper[1:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:478:11 */
  assign n1493 = n1490 ? 2'b00 : n1492;
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  assign n1494 = {n1485, n1464};
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1494)
      2'b10: n1495 = n1483;
      2'b01: n1495 = n1462;
      default: n1495 = n1493;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1496 = keeper[2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1494)
      2'b10: n1497 = n1496;
      2'b01: n1497 = n1457;
      default: n1497 = n1496;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1498 = keeper[7:3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1494)
      2'b10: n1499 = n1498;
      2'b01: n1499 = port_sel;
      default: n1499 = n1498;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:383:10 */
  assign n1500 = keeper[19:8]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:446:7 */
  always @*
    case (n1494)
      2'b10: n1501 = n1470;
      2'b01: n1501 = 12'b000000000000;
      default: n1501 = n1500;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:445:5 */
  assign n1502 = {n1501, n1499, n1497, n1495};
  /*# ../../rtl/core/neorv32_bus.vhd:440:5 */
  assign n1504 = {12'b000000000000, 5'b00000, 1'b0, 2'b00};
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1507 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1509 = 1'b1 ? n1507 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1511 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1513 = 1'b1 ? n1511 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1515 = keeper[19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1517 = 1'b1 ? n1515 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1519 = keeper[12]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1521 = 1'b1 ? n1519 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:489:30 */
  assign n1523 = keeper[19]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:489:55 */
  assign n1525 = 1'b1 ? n1523 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:491:47 */
  assign n1528 = keeper[7:3]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:491:36 */
  assign n1529 = tmo_bits & n1528;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1535 = n1529[4]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1537 = 1'b0 | n1535;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1539 = n1529[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1540 = n1537 | n1539;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1541 = n1529[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1542 = n1540 | n1541;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1543 = n1529[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1544 = n1542 | n1543;
  /*# ../../rtl/core/neorv32_package.vhd:1201:18 */
  assign n1545 = n1529[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1201:14 */
  assign n1546 = n1544 | n1545;
  /*# ../../rtl/core/neorv32_bus.vhd:494:26 */
  assign n1547 = keeper[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:495:26 */
  assign n1548 = keeper[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:319:10 */
  assign n1549 = {n1375, n1371, n1363, n1359, n1351};
  /*# ../../rtl/core/neorv32_bus.vhd:350:10 */
  assign n1550 = {n1525, n1521, n1517, n1513, n1509};
  /*# ../../rtl/core/neorv32_bus.vhd:370:10 */
  assign n1551 = {n1387, n1386, n1388, n1392, n1391, n1393, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000, n1397, n1396, n1398, 82'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_bus.vhd:371:10 */
  assign n1552 = {n1296, n1308, n1320, n1332, n1344};
  /*# ../../rtl/core/neorv32_bus.vhd:297:5 */
  assign n1553 = {n1444, n1448, n1446};
  /*# ../../rtl/core/neorv32_bus.vhd:445:5 */
  always @(posedge clk_i or posedge n1450)
    if (n1450)
      n1554 <= n1504;
    else
      n1554 <= n1502;
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
  wire [81:0] n1092;
  wire n1094;
  wire n1095;
  wire [31:0] n1096;
  wire [81:0] n1097;
  wire n1099;
  wire n1100;
  wire [31:0] n1101;
  wire [4:0] n1103;
  wire [31:0] n1104;
  wire [31:0] n1105;
  wire [3:0] n1106;
  wire n1107;
  wire n1108;
  wire n1109;
  wire [3:0] n1110;
  wire n1111;
  wire n1112;
  wire [33:0] n1113;
  wire [1:0] state;
  wire [1:0] state_nxt;
  wire a_req;
  wire b_req;
  wire sel;
  wire sel_q;
  wire stb;
  wire [1:0] lock;
  wire [1:0] lock_nxt;
  wire n1115;
  wire n1118;
  wire n1119;
  wire n1121;
  wire n1123;
  wire n1125;
  wire n1126;
  wire n1128;
  wire n1130;
  wire n1148;
  wire n1149;
  wire n1150;
  wire n1151;
  wire n1152;
  wire n1153;
  wire n1154;
  wire n1155;
  wire n1156;
  wire n1157;
  wire [1:0] n1159;
  wire n1161;
  wire n1162;
  wire n1163;
  wire n1164;
  wire n1165;
  wire n1166;
  wire n1167;
  wire n1168;
  wire n1169;
  wire n1170;
  wire n1171;
  wire [1:0] n1173;
  wire n1175;
  wire n1176;
  wire n1177;
  wire [1:0] n1178;
  wire n1179;
  wire n1180;
  wire n1181;
  wire n1182;
  wire [1:0] n1184;
  wire n1187;
  wire n1190;
  wire [1:0] n1192;
  wire n1194;
  wire n1196;
  wire n1198;
  wire [2:0] n1199;
  reg [1:0] n1201;
  reg n1205;
  reg n1208;
  reg [1:0] n1211;
  wire [4:0] n1213;
  wire n1214;
  wire [4:0] n1215;
  wire [4:0] n1216;
  wire [31:0] n1217;
  wire n1218;
  wire [31:0] n1219;
  wire [31:0] n1220;
  wire [31:0] n1221;
  wire [31:0] n1223;
  wire [31:0] n1224;
  wire [31:0] n1226;
  wire [31:0] n1227;
  wire n1228;
  wire [31:0] n1229;
  wire [31:0] n1230;
  wire [3:0] n1231;
  wire n1232;
  wire [3:0] n1233;
  wire [3:0] n1234;
  wire n1235;
  wire n1236;
  wire n1237;
  wire n1238;
  wire n1239;
  wire n1240;
  wire n1241;
  wire n1242;
  wire [3:0] n1243;
  wire n1244;
  wire [3:0] n1245;
  wire [3:0] n1246;
  wire n1247;
  wire n1248;
  wire n1249;
  wire n1250;
  wire n1251;
  wire n1252;
  wire n1253;
  wire n1254;
  wire n1255;
  wire n1256;
  wire n1257;
  wire n1259;
  wire n1260;
  wire n1261;
  wire [31:0] n1263;
  wire n1264;
  wire n1265;
  wire n1267;
  wire n1268;
  wire [31:0] n1270;
  wire [33:0] n1271;
  wire [33:0] n1272;
  wire [81:0] n1273;
  reg [1:0] n1274;
  reg n1275;
  reg n1276;
  reg n1277;
  reg [1:0] n1278;
  assign \a_rsp_o[ack]  = n1094; //(module output)
  assign \a_rsp_o[err]  = n1095; //(module output)
  assign \a_rsp_o[data]  = n1096; //(module output)
  assign \b_rsp_o[ack]  = n1099; //(module output)
  assign \b_rsp_o[err]  = n1100; //(module output)
  assign \b_rsp_o[data]  = n1101; //(module output)
  assign \x_req_o[meta]  = n1103; //(module output)
  assign \x_req_o[addr]  = n1104; //(module output)
  assign \x_req_o[data]  = n1105; //(module output)
  assign \x_req_o[ben]  = n1106; //(module output)
  assign \x_req_o[stb]  = n1107; //(module output)
  assign \x_req_o[rw]  = n1108; //(module output)
  assign \x_req_o[amo]  = n1109; //(module output)
  assign \x_req_o[amoop]  = n1110; //(module output)
  assign \x_req_o[burst]  = n1111; //(module output)
  assign \x_req_o[lock]  = n1112; //(module output)
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1092 = {\a_req_i[lock] , \a_req_i[burst] , \a_req_i[amoop] , \a_req_i[amo] , \a_req_i[rw] , \a_req_i[stb] , \a_req_i[ben] , \a_req_i[data] , \a_req_i[addr] , \a_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1094 = n1271[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1095 = n1271[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1096 = n1271[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1097 = {\b_req_i[lock] , \b_req_i[burst] , \b_req_i[amoop] , \b_req_i[amo] , \b_req_i[rw] , \b_req_i[stb] , \b_req_i[ben] , \b_req_i[data] , \b_req_i[addr] , \b_req_i[meta] };
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1099 = n1272[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1100 = n1272[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1101 = n1272[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1103 = n1273[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1104 = n1273[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1105 = n1273[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1106 = n1273[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1107 = n1273[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1108 = n1273[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1109 = n1273[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1110 = n1273[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1111 = n1273[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1112 = n1273[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:17:8 */
  assign n1113 = {\x_rsp_i[data] , \x_rsp_i[err] , \x_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_bus.vhd:38:10 */
  assign state = n1274; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:38:17 */
  assign state_nxt = n1201; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:10 */
  assign a_req = n1275; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:17 */
  assign b_req = n1276; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:24 */
  assign sel = n1205; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:29 */
  assign sel_q = n1277; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:39:36 */
  assign stb = n1208; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:40:10 */
  assign lock = n1278; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:40:16 */
  assign lock_nxt = n1211; // (signal)
  /*# ../../rtl/core/neorv32_bus.vhd:48:16 */
  assign n1115 = ~rstn_i;
  /*# ../../rtl/core/neorv32_bus.vhd:58:17 */
  assign n1118 = state == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:60:22 */
  assign n1119 = n1092[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:60:7 */
  assign n1121 = n1119 ? 1'b1 : a_req;
  /*# ../../rtl/core/neorv32_bus.vhd:58:7 */
  assign n1123 = n1118 ? 1'b0 : n1121;
  /*# ../../rtl/core/neorv32_bus.vhd:63:17 */
  assign n1125 = state == 2'b10;
  /*# ../../rtl/core/neorv32_bus.vhd:65:22 */
  assign n1126 = n1097[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:65:7 */
  assign n1128 = n1126 ? 1'b1 : b_req;
  /*# ../../rtl/core/neorv32_bus.vhd:63:7 */
  assign n1130 = n1125 ? 1'b0 : n1128;
  /*# ../../rtl/core/neorv32_bus.vhd:87:24 */
  assign n1148 = n1092[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:18 */
  assign n1149 = lock[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:42 */
  assign n1150 = n1092[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:47 */
  assign n1151 = ~n1150;
  /*# ../../rtl/core/neorv32_bus.vhd:88:29 */
  assign n1152 = n1151 & n1149;
  /*# ../../rtl/core/neorv32_bus.vhd:88:64 */
  assign n1153 = lock[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:68 */
  assign n1154 = ~n1153;
  /*# ../../rtl/core/neorv32_bus.vhd:88:88 */
  assign n1155 = n1113[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:88:75 */
  assign n1156 = n1155 & n1154;
  /*# ../../rtl/core/neorv32_bus.vhd:88:55 */
  assign n1157 = n1152 | n1156;
  /*# ../../rtl/core/neorv32_bus.vhd:88:9 */
  assign n1159 = n1157 ? 2'b00 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:84:7 */
  assign n1161 = state == 2'b01;
  /*# ../../rtl/core/neorv32_bus.vhd:95:24 */
  assign n1162 = n1097[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:18 */
  assign n1163 = lock[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:42 */
  assign n1164 = n1097[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:47 */
  assign n1165 = ~n1164;
  /*# ../../rtl/core/neorv32_bus.vhd:96:29 */
  assign n1166 = n1165 & n1163;
  /*# ../../rtl/core/neorv32_bus.vhd:96:64 */
  assign n1167 = lock[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:68 */
  assign n1168 = ~n1167;
  /*# ../../rtl/core/neorv32_bus.vhd:96:88 */
  assign n1169 = n1113[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:96:75 */
  assign n1170 = n1169 & n1168;
  /*# ../../rtl/core/neorv32_bus.vhd:96:55 */
  assign n1171 = n1166 | n1170;
  /*# ../../rtl/core/neorv32_bus.vhd:96:9 */
  assign n1173 = n1171 ? 2'b00 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:92:7 */
  assign n1175 = state == 2'b10;
  /*# ../../rtl/core/neorv32_bus.vhd:102:29 */
  assign n1176 = n1097[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:102:44 */
  assign n1177 = n1092[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:102:34 */
  assign n1178 = {n1176, n1177};
  /*# ../../rtl/core/neorv32_bus.vhd:104:23 */
  assign n1179 = n1092[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:104:34 */
  assign n1180 = n1179 | a_req;
  /*# ../../rtl/core/neorv32_bus.vhd:108:26 */
  assign n1181 = n1097[73]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:108:37 */
  assign n1182 = n1181 | b_req;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1184 = n1182 ? 2'b10 : state;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1187 = n1182 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:108:11 */
  assign n1190 = n1182 ? 1'b1 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1192 = n1180 ? 2'b01 : n1184;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1194 = n1180 ? 1'b0 : n1187;
  /*# ../../rtl/core/neorv32_bus.vhd:104:11 */
  assign n1196 = n1180 ? 1'b1 : n1190;
  /*# ../../rtl/core/neorv32_bus.vhd:100:7 */
  assign n1198 = state == 2'b00;
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  assign n1199 = {n1198, n1175, n1161};
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1199)
      3'b100: n1201 = n1192;
      3'b010: n1201 = n1173;
      3'b001: n1201 = n1159;
      default: n1201 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1199)
      3'b100: n1205 = n1194;
      3'b010: n1205 = 1'b1;
      3'b001: n1205 = 1'b0;
      default: n1205 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1199)
      3'b100: n1208 = n1196;
      3'b010: n1208 = n1162;
      3'b001: n1208 = n1148;
      default: n1208 = 1'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:82:5 */
  always @*
    case (n1199)
      3'b100: n1211 = n1178;
      3'b010: n1211 = lock;
      3'b001: n1211 = lock;
      default: n1211 = 2'bX;
    endcase
  /*# ../../rtl/core/neorv32_bus.vhd:130:28 */
  assign n1213 = n1092[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:130:44 */
  assign n1214 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:130:34 */
  assign n1215 = n1214 ? n1213 : n1216;
  /*# ../../rtl/core/neorv32_bus.vhd:130:64 */
  assign n1216 = n1097[4:0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:131:28 */
  assign n1217 = n1092[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:131:44 */
  assign n1218 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:131:34 */
  assign n1219 = n1218 ? n1217 : n1220;
  /*# ../../rtl/core/neorv32_bus.vhd:131:64 */
  assign n1220 = n1097[36:5]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:28 */
  assign n1221 = n1097[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:34 */
  assign n1223 = 1'b0 ? n1221 : n1226;
  /*# ../../rtl/core/neorv32_bus.vhd:133:28 */
  assign n1224 = n1092[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:132:51 */
  assign n1226 = 1'b1 ? n1224 : n1229;
  /*# ../../rtl/core/neorv32_bus.vhd:134:28 */
  assign n1227 = n1092[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:134:44 */
  assign n1228 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:133:51 */
  assign n1229 = n1228 ? n1227 : n1230;
  /*# ../../rtl/core/neorv32_bus.vhd:134:64 */
  assign n1230 = n1097[68:37]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:135:28 */
  assign n1231 = n1092[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:135:44 */
  assign n1232 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:135:34 */
  assign n1233 = n1232 ? n1231 : n1234;
  /*# ../../rtl/core/neorv32_bus.vhd:135:64 */
  assign n1234 = n1097[72:69]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:136:28 */
  assign n1235 = n1092[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:136:44 */
  assign n1236 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:136:34 */
  assign n1237 = n1236 ? n1235 : n1238;
  /*# ../../rtl/core/neorv32_bus.vhd:136:64 */
  assign n1238 = n1097[74]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:137:28 */
  assign n1239 = n1092[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:137:44 */
  assign n1240 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:137:34 */
  assign n1241 = n1240 ? n1239 : n1242;
  /*# ../../rtl/core/neorv32_bus.vhd:137:64 */
  assign n1242 = n1097[75]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:138:28 */
  assign n1243 = n1092[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:138:44 */
  assign n1244 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:138:34 */
  assign n1245 = n1244 ? n1243 : n1246;
  /*# ../../rtl/core/neorv32_bus.vhd:138:64 */
  assign n1246 = n1097[79:76]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:139:28 */
  assign n1247 = n1092[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:139:44 */
  assign n1248 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:139:34 */
  assign n1249 = n1248 ? n1247 : n1250;
  /*# ../../rtl/core/neorv32_bus.vhd:139:64 */
  assign n1250 = n1097[80]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:140:28 */
  assign n1251 = n1092[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:140:44 */
  assign n1252 = ~sel;
  /*# ../../rtl/core/neorv32_bus.vhd:140:34 */
  assign n1253 = n1252 ? n1251 : n1254;
  /*# ../../rtl/core/neorv32_bus.vhd:140:64 */
  assign n1254 = n1097[81]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:145:27 */
  assign n1255 = n1113[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:145:43 */
  assign n1256 = ~sel_q;
  /*# ../../rtl/core/neorv32_bus.vhd:145:31 */
  assign n1257 = n1256 ? n1255 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:146:27 */
  assign n1259 = n1113[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:146:43 */
  assign n1260 = ~sel_q;
  /*# ../../rtl/core/neorv32_bus.vhd:146:31 */
  assign n1261 = n1260 ? n1259 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:147:27 */
  assign n1263 = n1113[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:149:27 */
  assign n1264 = n1113[0]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:149:31 */
  assign n1265 = sel_q ? n1264 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:150:27 */
  assign n1267 = n1113[1]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:150:31 */
  assign n1268 = sel_q ? n1267 : 1'b0;
  /*# ../../rtl/core/neorv32_bus.vhd:151:27 */
  assign n1270 = n1113[33:2]; // extract
  /*# ../../rtl/core/neorv32_bus.vhd:27:5 */
  assign n1271 = {n1263, n1261, n1257};
  /*# ../../rtl/core/neorv32_bus.vhd:29:5 */
  assign n1272 = {n1270, n1268, n1265};
  /*# ../../rtl/core/neorv32_bus.vhd:30:5 */
  assign n1273 = {n1253, n1249, n1245, n1241, n1237, stb, n1233, n1223, n1219, n1215};
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1115)
    if (n1115)
      n1274 <= 2'b00;
    else
      n1274 <= state_nxt;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1115)
    if (n1115)
      n1275 <= 1'b0;
    else
      n1275 <= n1123;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1115)
    if (n1115)
      n1276 <= 1'b0;
    else
      n1276 <= n1130;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1115)
    if (n1115)
      n1277 <= 1'b0;
    else
      n1277 <= sel;
  /*# ../../rtl/core/neorv32_bus.vhd:54:5 */
  always @(posedge clk_i or posedge n1115)
    if (n1115)
      n1278 <= 2'b00;
    else
      n1278 <= lock_nxt;
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
  wire n774;
  wire [31:0] n775;
  wire [31:0] n776;
  wire n777;
  wire n778;
  wire n779;
  wire [1:0] n780;
  wire [1:0] n781;
  wire n782;
  wire n783;
  wire n784;
  wire [31:0] n785;
  wire [4:0] n786;
  wire [4:0] n787;
  wire [31:0] n788;
  wire [31:0] n789;
  wire [4:0] n790;
  wire [31:0] n791;
  wire [31:0] n792;
  wire [31:0] n793;
  wire [11:0] n794;
  wire [31:0] n795;
  wire [31:0] n796;
  wire [31:0] n797;
  wire [3:0] n798;
  wire [3:0] n799;
  wire [31:0] n800;
  wire [31:0] n801;
  wire [4:0] n805;
  wire [31:0] n806;
  wire [31:0] n807;
  wire [3:0] n808;
  wire n809;
  wire n810;
  wire n811;
  wire [3:0] n812;
  wire n813;
  wire n814;
  wire [33:0] n815;
  wire [4:0] n818;
  wire [31:0] n819;
  wire [31:0] n820;
  wire [3:0] n821;
  wire n822;
  wire n823;
  wire n824;
  wire [3:0] n825;
  wire n826;
  wire n827;
  wire [33:0] n828;
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
  wire n879;
  wire n880;
  wire n881;
  wire [31:0] n882;
  wire [31:0] n883;
  wire [31:0] n884;
  wire n885;
  wire [4:0] n886;
  wire [4:0] n887;
  wire [4:0] n888;
  wire n889;
  wire [2:0] n890;
  wire n891;
  wire n892;
  wire n893;
  wire n894;
  wire [31:0] n895;
  wire n896;
  wire n897;
  wire n898;
  wire n899;
  wire n900;
  wire n901;
  wire n902;
  wire n903;
  wire n904;
  wire n905;
  wire n906;
  wire n907;
  wire [11:0] n908;
  wire [31:0] n909;
  wire [8:0] n910;
  wire [2:0] n911;
  wire [11:0] n912;
  wire [6:0] n913;
  wire [15:0] n914;
  wire n915;
  wire n916;
  wire n917;
  wire n918;
  wire [81:0] n919;
  wire n921;
  wire n922;
  wire [31:0] n923;
  wire [50:0] n926;
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
  wire [261:0] n928;
  wire n930;
  wire [31:0] n931;
  wire [15:0] n932;
  wire n933;
  wire n934;
  wire [1:0] n936;
  wire [2:0] n937;
  wire [31:0] n938;
  wire [31:0] n939;
  wire [31:0] n940;
  wire n941;
  wire n942;
  wire n943;
  wire n944;
  wire n948;
  wire n949;
  wire n950;
  wire [31:0] n951;
  wire [31:0] n952;
  wire [31:0] n953;
  wire n954;
  wire [4:0] n955;
  wire [4:0] n956;
  wire [4:0] n957;
  wire n958;
  wire [2:0] n959;
  wire n960;
  wire n961;
  wire n962;
  wire n963;
  wire [31:0] n964;
  wire n965;
  wire n966;
  wire n967;
  wire n968;
  wire n969;
  wire n970;
  wire n971;
  wire n972;
  wire n973;
  wire n974;
  wire n975;
  wire n976;
  wire [11:0] n977;
  wire [31:0] n978;
  wire [8:0] n979;
  wire [2:0] n980;
  wire [11:0] n981;
  wire [6:0] n982;
  wire [15:0] n983;
  wire n984;
  wire n985;
  wire n986;
  wire n987;
  wire [31:0] n990;
  wire [31:0] n991;
  wire [31:0] n992;
  wire [31:0] n993;
  wire n994;
  wire n995;
  wire n996;
  wire [31:0] n997;
  wire [31:0] n998;
  wire [31:0] n999;
  wire n1000;
  wire [4:0] n1001;
  wire [4:0] n1002;
  wire [4:0] n1003;
  wire n1004;
  wire [2:0] n1005;
  wire n1006;
  wire n1007;
  wire n1008;
  wire n1009;
  wire [31:0] n1010;
  wire n1011;
  wire n1012;
  wire n1013;
  wire n1014;
  wire n1015;
  wire n1016;
  wire n1017;
  wire n1018;
  wire n1019;
  wire n1020;
  wire n1021;
  wire n1022;
  wire [11:0] n1023;
  wire [31:0] n1024;
  wire [8:0] n1025;
  wire [2:0] n1026;
  wire [11:0] n1027;
  wire [6:0] n1028;
  wire [15:0] n1029;
  wire n1030;
  wire n1031;
  wire n1032;
  wire n1033;
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
  wire n1039;
  wire n1040;
  wire n1041;
  wire [31:0] n1042;
  wire [31:0] n1043;
  wire [31:0] n1044;
  wire n1045;
  wire [4:0] n1046;
  wire [4:0] n1047;
  wire [4:0] n1048;
  wire n1049;
  wire [2:0] n1050;
  wire n1051;
  wire n1052;
  wire n1053;
  wire n1054;
  wire [31:0] n1055;
  wire n1056;
  wire n1057;
  wire n1058;
  wire n1059;
  wire n1060;
  wire n1061;
  wire n1062;
  wire n1063;
  wire n1064;
  wire n1065;
  wire n1066;
  wire n1067;
  wire [11:0] n1068;
  wire [31:0] n1069;
  wire [8:0] n1070;
  wire [2:0] n1071;
  wire [11:0] n1072;
  wire [6:0] n1073;
  wire [15:0] n1074;
  wire n1075;
  wire n1076;
  wire n1077;
  wire n1078;
  wire [81:0] n1083;
  wire n1085;
  wire n1086;
  wire [31:0] n1087;
  localparam [461:0] n1091 = 462'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000;
  assign \trace_o[valid]  = n774; //(module output)
  assign \trace_o[order]  = n775; //(module output)
  assign \trace_o[insn]  = n776; //(module output)
  assign \trace_o[trap]  = n777; //(module output)
  assign \trace_o[halt]  = n778; //(module output)
  assign \trace_o[intr]  = n779; //(module output)
  assign \trace_o[mode]  = n780; //(module output)
  assign \trace_o[ixl]  = n781; //(module output)
  assign \trace_o[debug]  = n782; //(module output)
  assign \trace_o[compr]  = n783; //(module output)
  assign \trace_o[delta]  = n784; //(module output)
  assign \trace_o[cmd32]  = n785; //(module output)
  assign \trace_o[rs1_addr]  = n786; //(module output)
  assign \trace_o[rs2_addr]  = n787; //(module output)
  assign \trace_o[rs1_rdata]  = n788; //(module output)
  assign \trace_o[rs2_rdata]  = n789; //(module output)
  assign \trace_o[rd_addr]  = n790; //(module output)
  assign \trace_o[rd_rdata]  = n791; //(module output)
  assign \trace_o[pc_rdata]  = n792; //(module output)
  assign \trace_o[pc_wdata]  = n793; //(module output)
  assign \trace_o[csr_addr]  = n794; //(module output)
  assign \trace_o[csr_rdata]  = n795; //(module output)
  assign \trace_o[csr_wdata]  = n796; //(module output)
  assign \trace_o[mem_addr]  = n797; //(module output)
  assign \trace_o[mem_rmask]  = n798; //(module output)
  assign \trace_o[mem_wmask]  = n799; //(module output)
  assign \trace_o[mem_rdata]  = n800; //(module output)
  assign \trace_o[mem_wdata]  = n801; //(module output)
  assign sleep_o = n942; //(module output)
  assign ifence_o = n943; //(module output)
  assign \ibus_req_o[meta]  = n805; //(module output)
  assign \ibus_req_o[addr]  = n806; //(module output)
  assign \ibus_req_o[data]  = n807; //(module output)
  assign \ibus_req_o[ben]  = n808; //(module output)
  assign \ibus_req_o[stb]  = n809; //(module output)
  assign \ibus_req_o[rw]  = n810; //(module output)
  assign \ibus_req_o[amo]  = n811; //(module output)
  assign \ibus_req_o[amoop]  = n812; //(module output)
  assign \ibus_req_o[burst]  = n813; //(module output)
  assign \ibus_req_o[lock]  = n814; //(module output)
  assign dfence_o = n944; //(module output)
  assign \dbus_req_o[meta]  = n818; //(module output)
  assign \dbus_req_o[addr]  = n819; //(module output)
  assign \dbus_req_o[data]  = n820; //(module output)
  assign \dbus_req_o[ben]  = n821; //(module output)
  assign \dbus_req_o[stb]  = n822; //(module output)
  assign \dbus_req_o[rw]  = n823; //(module output)
  assign \dbus_req_o[amo]  = n824; //(module output)
  assign \dbus_req_o[amoop]  = n825; //(module output)
  assign \dbus_req_o[burst]  = n826; //(module output)
  assign \dbus_req_o[lock]  = n827; //(module output)
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n774 = n1091[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n775 = n1091[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n776 = n1091[64:33]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n777 = n1091[65]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n778 = n1091[66]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n779 = n1091[67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n780 = n1091[69:68]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n781 = n1091[71:70]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n782 = n1091[72]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n783 = n1091[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n784 = n1091[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n785 = n1091[106:75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n786 = n1091[111:107]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n787 = n1091[116:112]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n788 = n1091[148:117]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n789 = n1091[180:149]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n790 = n1091[185:181]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n791 = n1091[217:186]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n792 = n1091[249:218]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n793 = n1091[281:250]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n794 = n1091[293:282]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n795 = n1091[325:294]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n796 = n1091[357:326]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n797 = n1091[389:358]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n798 = n1091[393:390]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n799 = n1091[397:394]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n800 = n1091[429:398]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n801 = n1091[461:430]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n805 = n919[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n806 = n919[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n807 = n919[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n808 = n919[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n809 = n919[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n810 = n919[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n811 = n919[75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n812 = n919[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n813 = n919[80]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n814 = n919[81]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n815 = {\ibus_rsp_i[data] , \ibus_rsp_i[err] , \ibus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n818 = dbus_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n819 = dbus_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n820 = dbus_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n821 = dbus_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n822 = dbus_req[73]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n823 = dbus_req[74]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n824 = dbus_req[75]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n825 = dbus_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n826 = dbus_req[80]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n827 = dbus_req[81]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:21:8 */
  assign n828 = {\dbus_rsp_i[data] , \dbus_rsp_i[err] , \dbus_rsp_i[ack] };
  /*# ../../rtl/core/neorv32_cpu.vhd:121:10 */
  assign ctrl = n928; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:122:10 */
  assign frontend = n926; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:123:10 */
  assign dbus_req = n1083; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:128:10 */
  assign if_pmp_err = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:129:10 */
  assign rw_pmp_err = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:130:10 */
  assign hwtrig = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:131:10 */
  assign rf_wdata = n993; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:143:10 */
  assign irq_machine = n937; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:10 */
  assign xcsr_tm = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:19 */
  assign xcsr_cnt = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:29 */
  assign xcsr_pmp = 32'b00000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:146:49 */
  assign xcsr_res = n940; // (signal)
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  neorv32_cpu_frontend_Bneorv32_cpu_frontend_rtl_Lneorv32_0_9508e90548b0440a4a61e5743b76c1e309b23b7f neorv32_cpu_frontend_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n879),
    .\ctrl_i[if_ready] (n880),
    .\ctrl_i[if_fence] (n881),
    .\ctrl_i[pc_cur] (n882),
    .\ctrl_i[pc_nxt] (n883),
    .\ctrl_i[pc_ret] (n884),
    .\ctrl_i[rf_wb_en] (n885),
    .\ctrl_i[rf_rs1] (n886),
    .\ctrl_i[rf_rs2] (n887),
    .\ctrl_i[rf_rd] (n888),
    .\ctrl_i[rf_zero] (n889),
    .\ctrl_i[alu_op] (n890),
    .\ctrl_i[alu_sub] (n891),
    .\ctrl_i[alu_opa_mux] (n892),
    .\ctrl_i[alu_opb_mux] (n893),
    .\ctrl_i[alu_unsigned] (n894),
    .\ctrl_i[alu_imm] (n895),
    .\ctrl_i[alu_cp_alu] (n896),
    .\ctrl_i[alu_cp_cfu] (n897),
    .\ctrl_i[alu_cp_fpu] (n898),
    .\ctrl_i[lsu_req] (n899),
    .\ctrl_i[lsu_rd] (n900),
    .\ctrl_i[lsu_wr] (n901),
    .\ctrl_i[lsu_mo_en] (n902),
    .\ctrl_i[lsu_mi_en] (n903),
    .\ctrl_i[lsu_priv] (n904),
    .\ctrl_i[lsu_fence] (n905),
    .\ctrl_i[csr_we] (n906),
    .\ctrl_i[csr_re] (n907),
    .\ctrl_i[csr_addr] (n908),
    .\ctrl_i[csr_wdata] (n909),
    .\ctrl_i[cnt_event] (n910),
    .\ctrl_i[ir_funct3] (n911),
    .\ctrl_i[ir_funct12] (n912),
    .\ctrl_i[ir_opcode] (n913),
    .\ctrl_i[ir_rvc] (n914),
    .\ctrl_i[cpu_priv] (n915),
    .\ctrl_i[cpu_trap] (n916),
    .\ctrl_i[cpu_sync_exc] (n917),
    .\ctrl_i[cpu_debug] (n918),
    .\ibus_rsp_i[ack] (n921),
    .\ibus_rsp_i[err] (n922),
    .\ibus_rsp_i[data] (n923),
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
  assign n879 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n880 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n881 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n882 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n883 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n884 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n885 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n886 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n887 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n888 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n889 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n890 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n891 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n892 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n893 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n894 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n895 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n896 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n897 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n898 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n899 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n900 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n901 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n902 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n903 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n904 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n905 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n906 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n907 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n908 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n909 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n910 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n911 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n912 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n913 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n914 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n915 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n916 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n917 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n918 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n919 = {\neorv32_cpu_frontend_inst.ibus_req_o[lock] , \neorv32_cpu_frontend_inst.ibus_req_o[burst] , \neorv32_cpu_frontend_inst.ibus_req_o[amoop] , \neorv32_cpu_frontend_inst.ibus_req_o[amo] , \neorv32_cpu_frontend_inst.ibus_req_o[rw] , \neorv32_cpu_frontend_inst.ibus_req_o[stb] , \neorv32_cpu_frontend_inst.ibus_req_o[ben] , \neorv32_cpu_frontend_inst.ibus_req_o[data] , \neorv32_cpu_frontend_inst.ibus_req_o[addr] , \neorv32_cpu_frontend_inst.ibus_req_o[meta] };
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n921 = n815[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n922 = n815[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n923 = n815[33:2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:224:3 */
  assign n926 = {\neorv32_cpu_frontend_inst.frontend_o[fault] , \neorv32_cpu_frontend_inst.frontend_o[compr] , \neorv32_cpu_frontend_inst.frontend_o[i16] , \neorv32_cpu_frontend_inst.frontend_o[i32] , \neorv32_cpu_frontend_inst.frontend_o[valid] };
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  neorv32_cpu_control_Bneorv32_cpu_control_rtl_Lneorv32_0_4276033fa0415472228fc3f7d7c8a0a76b50f4af neorv32_cpu_control_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\frontend_i[valid] (n930),
    .\frontend_i[i32] (n931),
    .\frontend_i[i16] (n932),
    .\frontend_i[compr] (n933),
    .\frontend_i[fault] (n934),
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
  assign n928 = {\neorv32_cpu_control_inst.ctrl_o[cpu_debug] , \neorv32_cpu_control_inst.ctrl_o[cpu_sync_exc] , \neorv32_cpu_control_inst.ctrl_o[cpu_trap] , \neorv32_cpu_control_inst.ctrl_o[cpu_priv] , \neorv32_cpu_control_inst.ctrl_o[ir_rvc] , \neorv32_cpu_control_inst.ctrl_o[ir_opcode] , \neorv32_cpu_control_inst.ctrl_o[ir_funct12] , \neorv32_cpu_control_inst.ctrl_o[ir_funct3] , \neorv32_cpu_control_inst.ctrl_o[cnt_event] , \neorv32_cpu_control_inst.ctrl_o[csr_wdata] , \neorv32_cpu_control_inst.ctrl_o[csr_addr] , \neorv32_cpu_control_inst.ctrl_o[csr_re] , \neorv32_cpu_control_inst.ctrl_o[csr_we] , \neorv32_cpu_control_inst.ctrl_o[lsu_fence] , \neorv32_cpu_control_inst.ctrl_o[lsu_priv] , \neorv32_cpu_control_inst.ctrl_o[lsu_mi_en] , \neorv32_cpu_control_inst.ctrl_o[lsu_mo_en] , \neorv32_cpu_control_inst.ctrl_o[lsu_wr] , \neorv32_cpu_control_inst.ctrl_o[lsu_rd] , \neorv32_cpu_control_inst.ctrl_o[lsu_req] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_fpu] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_cfu] , \neorv32_cpu_control_inst.ctrl_o[alu_cp_alu] , \neorv32_cpu_control_inst.ctrl_o[alu_imm] , \neorv32_cpu_control_inst.ctrl_o[alu_unsigned] , \neorv32_cpu_control_inst.ctrl_o[alu_opb_mux] , \neorv32_cpu_control_inst.ctrl_o[alu_opa_mux] , \neorv32_cpu_control_inst.ctrl_o[alu_sub] , \neorv32_cpu_control_inst.ctrl_o[alu_op] , \neorv32_cpu_control_inst.ctrl_o[rf_zero] , \neorv32_cpu_control_inst.ctrl_o[rf_rd] , \neorv32_cpu_control_inst.ctrl_o[rf_rs2] , \neorv32_cpu_control_inst.ctrl_o[rf_rs1] , \neorv32_cpu_control_inst.ctrl_o[rf_wb_en] , \neorv32_cpu_control_inst.ctrl_o[pc_ret] , \neorv32_cpu_control_inst.ctrl_o[pc_nxt] , \neorv32_cpu_control_inst.ctrl_o[pc_cur] , \neorv32_cpu_control_inst.ctrl_o[if_fence] , \neorv32_cpu_control_inst.ctrl_o[if_ready] , \neorv32_cpu_control_inst.ctrl_o[if_reset] };
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n930 = frontend[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n931 = frontend[32:1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n932 = frontend[48:33]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n933 = frontend[49]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:250:3 */
  assign n934 = frontend[50]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:325:24 */
  assign n936 = {mei_i, mti_i};
  /*# ../../rtl/core/neorv32_cpu.vhd:325:32 */
  assign n937 = {n936, msi_i};
  /*# ../../rtl/core/neorv32_cpu.vhd:328:23 */
  assign n938 = xcsr_tm | xcsr_cnt;
  /*# ../../rtl/core/neorv32_cpu.vhd:328:35 */
  assign n939 = n938 | xcsr_alu;
  /*# ../../rtl/core/neorv32_cpu.vhd:328:47 */
  assign n940 = n939 | xcsr_pmp;
  /*# ../../rtl/core/neorv32_cpu.vhd:331:32 */
  assign n941 = ctrl[211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:331:14 */
  assign n942 = ~n941;
  /*# ../../rtl/core/neorv32_cpu.vhd:334:20 */
  assign n943 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:335:20 */
  assign n944 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  neorv32_cpu_regfile_Bneorv32_cpu_regfile_rtl_Lneorv32_32_5_0 neorv32_cpu_regfile_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n948),
    .\ctrl_i[if_ready] (n949),
    .\ctrl_i[if_fence] (n950),
    .\ctrl_i[pc_cur] (n951),
    .\ctrl_i[pc_nxt] (n952),
    .\ctrl_i[pc_ret] (n953),
    .\ctrl_i[rf_wb_en] (n954),
    .\ctrl_i[rf_rs1] (n955),
    .\ctrl_i[rf_rs2] (n956),
    .\ctrl_i[rf_rd] (n957),
    .\ctrl_i[rf_zero] (n958),
    .\ctrl_i[alu_op] (n959),
    .\ctrl_i[alu_sub] (n960),
    .\ctrl_i[alu_opa_mux] (n961),
    .\ctrl_i[alu_opb_mux] (n962),
    .\ctrl_i[alu_unsigned] (n963),
    .\ctrl_i[alu_imm] (n964),
    .\ctrl_i[alu_cp_alu] (n965),
    .\ctrl_i[alu_cp_cfu] (n966),
    .\ctrl_i[alu_cp_fpu] (n967),
    .\ctrl_i[lsu_req] (n968),
    .\ctrl_i[lsu_rd] (n969),
    .\ctrl_i[lsu_wr] (n970),
    .\ctrl_i[lsu_mo_en] (n971),
    .\ctrl_i[lsu_mi_en] (n972),
    .\ctrl_i[lsu_priv] (n973),
    .\ctrl_i[lsu_fence] (n974),
    .\ctrl_i[csr_we] (n975),
    .\ctrl_i[csr_re] (n976),
    .\ctrl_i[csr_addr] (n977),
    .\ctrl_i[csr_wdata] (n978),
    .\ctrl_i[cnt_event] (n979),
    .\ctrl_i[ir_funct3] (n980),
    .\ctrl_i[ir_funct12] (n981),
    .\ctrl_i[ir_opcode] (n982),
    .\ctrl_i[ir_rvc] (n983),
    .\ctrl_i[cpu_priv] (n984),
    .\ctrl_i[cpu_trap] (n985),
    .\ctrl_i[cpu_sync_exc] (n986),
    .\ctrl_i[cpu_debug] (n987),
    .rd_i(rf_wdata),
    .rs1_o(rs1),
    .rs2_o(rs2));
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n948 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n949 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n950 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n951 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n952 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n953 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n954 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n955 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n956 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n957 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n958 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n959 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n960 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n961 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n962 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n963 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n964 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n965 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n966 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n967 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n968 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n969 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n970 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n971 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n972 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n973 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n974 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n975 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n976 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n977 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n978 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n979 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n980 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n981 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n982 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n983 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n984 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n985 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n986 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:400:3 */
  assign n987 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:418:23 */
  assign n990 = alu_res | lsu_rdata;
  /*# ../../rtl/core/neorv32_cpu.vhd:418:36 */
  assign n991 = n990 | csr_rdata;
  /*# ../../rtl/core/neorv32_cpu.vhd:418:57 */
  assign n992 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:418:49 */
  assign n993 = n991 | n992;
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  neorv32_cpu_alu_Bneorv32_cpu_alu_rtl_Lneorv32_f76e51fa32cd911aa74f5a7b915d61ba4b7734d9 neorv32_cpu_alu_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n994),
    .\ctrl_i[if_ready] (n995),
    .\ctrl_i[if_fence] (n996),
    .\ctrl_i[pc_cur] (n997),
    .\ctrl_i[pc_nxt] (n998),
    .\ctrl_i[pc_ret] (n999),
    .\ctrl_i[rf_wb_en] (n1000),
    .\ctrl_i[rf_rs1] (n1001),
    .\ctrl_i[rf_rs2] (n1002),
    .\ctrl_i[rf_rd] (n1003),
    .\ctrl_i[rf_zero] (n1004),
    .\ctrl_i[alu_op] (n1005),
    .\ctrl_i[alu_sub] (n1006),
    .\ctrl_i[alu_opa_mux] (n1007),
    .\ctrl_i[alu_opb_mux] (n1008),
    .\ctrl_i[alu_unsigned] (n1009),
    .\ctrl_i[alu_imm] (n1010),
    .\ctrl_i[alu_cp_alu] (n1011),
    .\ctrl_i[alu_cp_cfu] (n1012),
    .\ctrl_i[alu_cp_fpu] (n1013),
    .\ctrl_i[lsu_req] (n1014),
    .\ctrl_i[lsu_rd] (n1015),
    .\ctrl_i[lsu_wr] (n1016),
    .\ctrl_i[lsu_mo_en] (n1017),
    .\ctrl_i[lsu_mi_en] (n1018),
    .\ctrl_i[lsu_priv] (n1019),
    .\ctrl_i[lsu_fence] (n1020),
    .\ctrl_i[csr_we] (n1021),
    .\ctrl_i[csr_re] (n1022),
    .\ctrl_i[csr_addr] (n1023),
    .\ctrl_i[csr_wdata] (n1024),
    .\ctrl_i[cnt_event] (n1025),
    .\ctrl_i[ir_funct3] (n1026),
    .\ctrl_i[ir_funct12] (n1027),
    .\ctrl_i[ir_opcode] (n1028),
    .\ctrl_i[ir_rvc] (n1029),
    .\ctrl_i[cpu_priv] (n1030),
    .\ctrl_i[cpu_trap] (n1031),
    .\ctrl_i[cpu_sync_exc] (n1032),
    .\ctrl_i[cpu_debug] (n1033),
    .rs1_i(rs1),
    .rs2_i(rs2),
    .cmp_o(alu_cmp),
    .res_o(alu_res),
    .add_o(alu_add),
    .csr_o(xcsr_alu),
    .done_o(alu_cp_done));
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n994 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n995 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n996 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n997 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n998 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n999 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1000 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1001 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1002 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1003 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1004 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1005 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1006 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1007 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1008 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1009 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1010 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1011 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1012 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1013 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1014 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1015 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1016 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1017 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1018 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1019 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1020 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1021 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1022 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1023 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1024 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1025 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1026 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1027 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1028 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1029 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1030 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1031 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1032 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:423:3 */
  assign n1033 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  neorv32_cpu_lsu_Bneorv32_cpu_lsu_rtl_Lneorv32_0_5ba93c9db0cff93f52b521d7420e43f6eda2784f neorv32_cpu_lsu_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .\ctrl_i[if_reset] (n1039),
    .\ctrl_i[if_ready] (n1040),
    .\ctrl_i[if_fence] (n1041),
    .\ctrl_i[pc_cur] (n1042),
    .\ctrl_i[pc_nxt] (n1043),
    .\ctrl_i[pc_ret] (n1044),
    .\ctrl_i[rf_wb_en] (n1045),
    .\ctrl_i[rf_rs1] (n1046),
    .\ctrl_i[rf_rs2] (n1047),
    .\ctrl_i[rf_rd] (n1048),
    .\ctrl_i[rf_zero] (n1049),
    .\ctrl_i[alu_op] (n1050),
    .\ctrl_i[alu_sub] (n1051),
    .\ctrl_i[alu_opa_mux] (n1052),
    .\ctrl_i[alu_opb_mux] (n1053),
    .\ctrl_i[alu_unsigned] (n1054),
    .\ctrl_i[alu_imm] (n1055),
    .\ctrl_i[alu_cp_alu] (n1056),
    .\ctrl_i[alu_cp_cfu] (n1057),
    .\ctrl_i[alu_cp_fpu] (n1058),
    .\ctrl_i[lsu_req] (n1059),
    .\ctrl_i[lsu_rd] (n1060),
    .\ctrl_i[lsu_wr] (n1061),
    .\ctrl_i[lsu_mo_en] (n1062),
    .\ctrl_i[lsu_mi_en] (n1063),
    .\ctrl_i[lsu_priv] (n1064),
    .\ctrl_i[lsu_fence] (n1065),
    .\ctrl_i[csr_we] (n1066),
    .\ctrl_i[csr_re] (n1067),
    .\ctrl_i[csr_addr] (n1068),
    .\ctrl_i[csr_wdata] (n1069),
    .\ctrl_i[cnt_event] (n1070),
    .\ctrl_i[ir_funct3] (n1071),
    .\ctrl_i[ir_funct12] (n1072),
    .\ctrl_i[ir_opcode] (n1073),
    .\ctrl_i[ir_rvc] (n1074),
    .\ctrl_i[cpu_priv] (n1075),
    .\ctrl_i[cpu_trap] (n1076),
    .\ctrl_i[cpu_sync_exc] (n1077),
    .\ctrl_i[cpu_debug] (n1078),
    .addr_i(alu_add),
    .wdata_i(rs2),
    .pmp_fault_i(rw_pmp_err),
    .\dbus_rsp_i[ack] (n1085),
    .\dbus_rsp_i[err] (n1086),
    .\dbus_rsp_i[data] (n1087),
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
  assign n1039 = ctrl[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1040 = ctrl[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1041 = ctrl[2]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1042 = ctrl[34:3]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1043 = ctrl[66:35]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1044 = ctrl[98:67]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1045 = ctrl[99]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1046 = ctrl[104:100]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1047 = ctrl[109:105]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1048 = ctrl[114:110]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1049 = ctrl[115]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1050 = ctrl[118:116]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1051 = ctrl[119]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1052 = ctrl[120]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1053 = ctrl[121]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1054 = ctrl[122]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1055 = ctrl[154:123]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1056 = ctrl[155]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1057 = ctrl[156]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1058 = ctrl[157]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1059 = ctrl[158]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1060 = ctrl[159]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1061 = ctrl[160]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1062 = ctrl[161]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1063 = ctrl[162]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1064 = ctrl[163]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1065 = ctrl[164]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1066 = ctrl[165]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1067 = ctrl[166]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1068 = ctrl[178:167]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1069 = ctrl[210:179]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1070 = ctrl[219:211]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1071 = ctrl[222:220]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1072 = ctrl[234:223]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1073 = ctrl[241:235]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1074 = ctrl[257:242]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1075 = ctrl[258]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1076 = ctrl[259]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1077 = ctrl[260]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1078 = ctrl[261]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1083 = {\neorv32_cpu_lsu_inst.dbus_req_o[lock] , \neorv32_cpu_lsu_inst.dbus_req_o[burst] , \neorv32_cpu_lsu_inst.dbus_req_o[amoop] , \neorv32_cpu_lsu_inst.dbus_req_o[amo] , \neorv32_cpu_lsu_inst.dbus_req_o[rw] , \neorv32_cpu_lsu_inst.dbus_req_o[stb] , \neorv32_cpu_lsu_inst.dbus_req_o[ben] , \neorv32_cpu_lsu_inst.dbus_req_o[data] , \neorv32_cpu_lsu_inst.dbus_req_o[addr] , \neorv32_cpu_lsu_inst.dbus_req_o[meta] };
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1085 = n828[0]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1086 = n828[1]; // extract
  /*# ../../rtl/core/neorv32_cpu.vhd:469:3 */
  assign n1087 = n828[33:2]; // extract
endmodule

module neorv32_sys_clock_Bneorv32_sys_clock_rtl_Lneorv32
  (input  clk_i,
   input  rstn_i,
   input  enable_i,
   output [7:0] clk_en_o);
  wire [11:0] cnt;
  wire [11:0] cnt2;
  wire [11:0] en;
  wire n747;
  wire [11:0] n750;
  wire [11:0] n752;
  wire [11:0] n760;
  wire [11:0] n761;
  wire n762;
  wire n763;
  wire n764;
  wire n765;
  wire n766;
  wire n767;
  wire n768;
  wire n769;
  wire [7:0] n770;
  reg [11:0] n771;
  reg [11:0] n772;
  assign clk_en_o = n770; //(module output)
  /*# ../../rtl/core/neorv32_sys.vhd:108:10 */
  assign cnt = n771; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:108:15 */
  assign cnt2 = n772; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:108:21 */
  assign en = n761; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:115:16 */
  assign n747 = ~rstn_i;
  /*# ../../rtl/core/neorv32_sys.vhd:120:48 */
  assign n750 = cnt + 12'b000000000001;
  /*# ../../rtl/core/neorv32_sys.vhd:119:7 */
  assign n752 = enable_i ? n750 : 12'b000000000000;
  /*# ../../rtl/core/neorv32_sys.vhd:129:18 */
  assign n760 = ~cnt2;
  /*# ../../rtl/core/neorv32_sys.vhd:129:13 */
  assign n761 = cnt & n760;
  /*# ../../rtl/core/neorv32_sys.vhd:132:32 */
  assign n762 = en[0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:133:32 */
  assign n763 = en[1]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:134:32 */
  assign n764 = en[2]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:135:32 */
  assign n765 = en[5]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:136:32 */
  assign n766 = en[6]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:137:32 */
  assign n767 = en[9]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:138:32 */
  assign n768 = en[10]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:139:32 */
  assign n769 = en[11]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:102:5 */
  assign n770 = {n769, n768, n767, n766, n765, n764, n763, n762};
  /*# ../../rtl/core/neorv32_sys.vhd:118:5 */
  always @(posedge clk_i or posedge n747)
    if (n747)
      n771 <= 12'b000000000000;
    else
      n771 <= n752;
  /*# ../../rtl/core/neorv32_sys.vhd:118:5 */
  always @(posedge clk_i or posedge n747)
    if (n747)
      n772 <= 12'b000000000000;
    else
      n772 <= cnt;
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
  wire n671;
  wire [2:0] n673;
  wire [3:0] n675;
  wire n682;
  wire n684;
  wire n686;
  wire n687;
  wire n688;
  wire n689;
  wire n690;
  wire n691;
  wire n692;
  wire n693;
  wire n694;
  wire [2:0] n695;
  wire [3:0] n697;
  wire [3:0] n699;
  wire n706;
  wire n708;
  wire n710;
  wire n711;
  wire n712;
  wire n713;
  wire n714;
  wire n715;
  wire n730;
  reg n739;
  reg n740;
  reg n741;
  reg n742;
  reg [3:0] n743;
  reg [3:0] n744;
  assign rstn_ext_o = n739; //(module output)
  assign rstn_sys_o = n740; //(module output)
  assign xrstn_wdt_o = n741; //(module output)
  assign xrstn_ocd_o = n742; //(module output)
  /*# ../../rtl/core/neorv32_sys.vhd:36:10 */
  assign sreg_ext = n743; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:36:20 */
  assign sreg_sys = n744; // (signal)
  /*# ../../rtl/core/neorv32_sys.vhd:43:20 */
  assign n671 = ~rstn_ext_i;
  /*# ../../rtl/core/neorv32_sys.vhd:50:29 */
  assign n673 = sreg_ext[2:0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:50:56 */
  assign n675 = {n673, 1'b1};
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n682 = sreg_ext[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n684 = 1'b1 & n682;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n686 = sreg_ext[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n687 = n684 & n686;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n688 = sreg_ext[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n689 = n687 & n688;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n690 = sreg_ext[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n691 = n689 & n690;
  /*# ../../rtl/core/neorv32_sys.vhd:53:22 */
  assign n692 = ~rstn_wdt_i;
  /*# ../../rtl/core/neorv32_sys.vhd:53:44 */
  assign n693 = ~rstn_dbg_i;
  /*# ../../rtl/core/neorv32_sys.vhd:53:29 */
  assign n694 = n692 | n693;
  /*# ../../rtl/core/neorv32_sys.vhd:56:29 */
  assign n695 = sreg_sys[2:0]; // extract
  /*# ../../rtl/core/neorv32_sys.vhd:56:56 */
  assign n697 = {n695, 1'b1};
  /*# ../../rtl/core/neorv32_sys.vhd:53:7 */
  assign n699 = n694 ? 4'b0000 : n697;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n706 = sreg_sys[3]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n708 = 1'b1 & n706;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n710 = sreg_sys[2]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n711 = n708 & n710;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n712 = sreg_sys[1]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n713 = n711 & n712;
  /*# ../../rtl/core/neorv32_package.vhd:1213:19 */
  assign n714 = sreg_sys[0]; // extract
  /*# ../../rtl/core/neorv32_package.vhd:1213:14 */
  assign n715 = n713 & n714;
  /*# ../../rtl/core/neorv32_sys.vhd:65:20 */
  assign n730 = ~rstn_ext_i;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n671)
    if (n671)
      n739 <= 1'b0;
    else
      n739 <= n691;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n671)
    if (n671)
      n740 <= 1'b0;
    else
      n740 <= n715;
  /*# ../../rtl/core/neorv32_sys.vhd:68:5 */
  always @(posedge clk_i or posedge n730)
    if (n730)
      n741 <= 1'b0;
    else
      n741 <= rstn_wdt_i;
  /*# ../../rtl/core/neorv32_sys.vhd:68:5 */
  always @(posedge clk_i or posedge n730)
    if (n730)
      n742 <= 1'b0;
    else
      n742 <= rstn_dbg_i;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n671)
    if (n671)
      n743 <= 4'b0000;
    else
      n743 <= n675;
  /*# ../../rtl/core/neorv32_sys.vhd:48:5 */
  always @(posedge clk_i or posedge n671)
    if (n671)
      n744 <= 4'b0000;
    else
      n744 <= n699;
endmodule

module neorv32_top_Bneorv32_top_rtl_Lneorv32_100000000_2_0_0_0_4_0_40_16384_16384_4_4_64_2048_0_1_1_1_1_1_1_1_1_1_0_1_3_5_64_1_0_1_4_1_1_1_6e3c239da792a1cf02e3b569dfcea5aaaa030a63
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
  wire n116;
  wire [31:0] n117;
  wire [31:0] n118;
  wire n119;
  wire n120;
  wire n121;
  wire [1:0] n122;
  wire [1:0] n123;
  wire n124;
  wire n125;
  wire n126;
  wire [31:0] n127;
  wire [4:0] n128;
  wire [4:0] n129;
  wire [31:0] n130;
  wire [31:0] n131;
  wire [4:0] n132;
  wire [31:0] n133;
  wire [31:0] n134;
  wire [31:0] n135;
  wire [11:0] n136;
  wire [31:0] n137;
  wire [31:0] n138;
  wire [31:0] n139;
  wire [3:0] n140;
  wire [3:0] n141;
  wire [31:0] n142;
  wire [31:0] n143;
  wire n145;
  wire [31:0] n146;
  wire [31:0] n147;
  wire n148;
  wire n149;
  wire n150;
  wire [1:0] n151;
  wire [1:0] n152;
  wire n153;
  wire n154;
  wire n155;
  wire [31:0] n156;
  wire [4:0] n157;
  wire [4:0] n158;
  wire [31:0] n159;
  wire [31:0] n160;
  wire [4:0] n161;
  wire [31:0] n162;
  wire [31:0] n163;
  wire [31:0] n164;
  wire [11:0] n165;
  wire [31:0] n166;
  wire [31:0] n167;
  wire [31:0] n168;
  wire [3:0] n169;
  wire [3:0] n170;
  wire [31:0] n171;
  wire [31:0] n172;
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
  wire [33:0] sys1_rsp;
  wire [33:0] sys2_rsp;
  wire [33:0] amo_rsp;
  wire [33:0] sys3_rsp;
  wire [33:0] imem_rsp;
  wire [33:0] dmem_rsp;
  wire [33:0] smc_rsp;
  wire [33:0] io_rsp;
  wire [33:0] xbus_rsp;
  wire [1803:0] iodev_req;
  wire [747:0] iodev_rsp;
  wire [14:0] firq;
  wire [15:0] cpu_firq;
  wire mti;
  wire msi;
  wire [63:0] mtime;
  wire \soc_generators_neorv32_sys_reset_inst.rstn_ext_o ;
  localparam n262 = 1'b1;
  wire n265;
  wire n266;
  wire n267;
  wire n268;
  wire n269;
  wire n270;
  wire n271;
  wire n272;
  wire n273;
  wire n274;
  wire n275;
  wire n276;
  wire n277;
  wire n278;
  wire n279;
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
  wire [461:0] n280;
  wire [81:0] n283;
  wire n285;
  wire n286;
  wire [31:0] n287;
  wire [81:0] n289;
  wire n291;
  wire n292;
  wire [31:0] n293;
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
  wire [4:0] n296;
  wire [31:0] n297;
  wire [31:0] n298;
  wire [3:0] n299;
  wire n300;
  wire n301;
  wire n302;
  wire [3:0] n303;
  wire n304;
  wire n305;
  wire [33:0] n306;
  wire [4:0] n308;
  wire [31:0] n309;
  wire [31:0] n310;
  wire [3:0] n311;
  wire n312;
  wire n313;
  wire n314;
  wire [3:0] n315;
  wire n316;
  wire n317;
  wire [33:0] n318;
  wire [81:0] n320;
  wire n322;
  wire n323;
  wire [31:0] n324;
  wire [461:0] n326;
  localparam [33:0] n328 = 34'b0000000000000000000000000000000000;
  wire \neorv32_bus_gateway_inst.term_o ;
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
  wire [4:0] n333;
  wire [31:0] n334;
  wire [31:0] n335;
  wire [3:0] n336;
  wire n337;
  wire n338;
  wire n339;
  wire [3:0] n340;
  wire n341;
  wire n342;
  wire [33:0] n343;
  wire [81:0] n345;
  wire n347;
  wire n348;
  wire [31:0] n349;
  wire [81:0] n350;
  wire n352;
  wire n353;
  wire [31:0] n354;
  wire n357;
  wire n358;
  wire [31:0] n359;
  wire [81:0] n360;
  wire n362;
  wire n363;
  wire [31:0] n364;
  wire n367;
  wire n368;
  wire [31:0] n369;
  wire \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] ;
  wire \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] ;
  wire [31:0] \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] ;
  wire [4:0] n370;
  wire [31:0] n371;
  wire [31:0] n372;
  wire [3:0] n373;
  wire n374;
  wire n375;
  wire n376;
  wire [3:0] n377;
  wire n378;
  wire n379;
  wire [33:0] n380;
  wire \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] ;
  wire \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] ;
  wire [31:0] \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] ;
  wire [4:0] n382;
  wire [31:0] n383;
  wire [31:0] n384;
  wire [3:0] n385;
  wire n386;
  wire n387;
  wire n388;
  wire [3:0] n389;
  wire n390;
  wire n391;
  wire [33:0] n392;
  localparam n395 = 1'b0;
  localparam n396 = 1'b0;
  localparam [1:0] n397 = 2'b11;
  localparam n398 = 1'b0;
  localparam [31:0] n400 = 32'b00000000000000000000000000000000;
  localparam [31:0] n401 = 32'b00000000000000000000000000000000;
  localparam [2:0] n402 = 3'b000;
  localparam [2:0] n403 = 3'b000;
  localparam n404 = 1'b0;
  localparam [3:0] n405 = 4'b0000;
  localparam n406 = 1'b0;
  localparam n407 = 1'b0;
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
  wire [4:0] n408;
  wire [31:0] n409;
  wire [31:0] n410;
  wire [3:0] n411;
  wire n412;
  wire n413;
  wire n414;
  wire [3:0] n415;
  wire n416;
  wire n417;
  wire [33:0] n418;
  wire [81:0] n420;
  wire n423;
  wire n424;
  wire [31:0] n425;
  wire n427;
  wire n428;
  wire [31:0] n429;
  wire n431;
  wire n432;
  wire [31:0] n433;
  wire n435;
  wire n436;
  wire [31:0] n437;
  wire n439;
  wire n440;
  wire [31:0] n441;
  wire n443;
  wire n444;
  wire [31:0] n445;
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
  wire [81:0] n462;
  wire n465;
  wire n466;
  wire [31:0] n467;
  wire [81:0] n468;
  wire n471;
  wire n472;
  wire [31:0] n473;
  wire [81:0] n474;
  wire n477;
  wire n478;
  wire [31:0] n479;
  wire [81:0] n480;
  wire n483;
  wire n484;
  wire [31:0] n485;
  wire n487;
  wire n488;
  wire [31:0] n489;
  wire [81:0] n490;
  wire n493;
  wire n494;
  wire [31:0] n495;
  wire [81:0] n496;
  wire n499;
  wire n500;
  wire [31:0] n501;
  wire [81:0] n502;
  wire n505;
  wire n506;
  wire [31:0] n507;
  wire [81:0] n508;
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
  localparam [255:0] n593 = 256'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  localparam n594 = 1'b0;
  localparam [31:0] n596 = 32'b00000000000000000000000000000000;
  localparam [31:0] n597 = 32'b00000000000000000000000000000000;
  localparam [63:0] n602 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[ack] ;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[err] ;
  wire [31:0] \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[data] ;
  wire \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.irq_o ;
  wire [4:0] n604;
  wire [31:0] n605;
  wire [31:0] n606;
  wire [3:0] n607;
  wire n608;
  wire n609;
  wire n610;
  wire [3:0] n611;
  wire n612;
  wire n613;
  wire [33:0] n614;
  localparam n619 = 1'b0;
  localparam n620 = 1'b1;
  localparam n622 = 1'b0;
  localparam n623 = 1'b0;
  localparam [7:0] n624 = 8'b11111111;
  localparam n626 = 1'b1;
  localparam n627 = 1'b1;
  localparam n629 = 1'b1;
  localparam [31:0] n631 = 32'b00000000000000000000000000000000;
  localparam n634 = 1'b0;
  localparam n636 = 1'b1;
  localparam n639 = 1'b0;
  localparam [31:0] n640 = 32'b00000000000000000000000000000000;
  localparam [3:0] n641 = 4'b0000;
  localparam n642 = 1'b0;
  localparam n643 = 1'b0;
  wire \io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] ;
  wire \io_system_neorv32_sysinfo_inst.bus_rsp_o[err] ;
  wire [31:0] \io_system_neorv32_sysinfo_inst.bus_rsp_o[data] ;
  wire [4:0] n646;
  wire [31:0] n647;
  wire [31:0] n648;
  wire [3:0] n649;
  wire n650;
  wire n651;
  wire n652;
  wire [3:0] n653;
  wire n654;
  wire n655;
  wire [33:0] n656;
  wire [1803:0] n662;
  wire [747:0] n663;
  wire [14:0] n664;
  wire [15:0] n665;
  assign \trace_cpu0_o[valid]  = n116; //(module output)
  assign \trace_cpu0_o[order]  = n117; //(module output)
  assign \trace_cpu0_o[insn]  = n118; //(module output)
  assign \trace_cpu0_o[trap]  = n119; //(module output)
  assign \trace_cpu0_o[halt]  = n120; //(module output)
  assign \trace_cpu0_o[intr]  = n121; //(module output)
  assign \trace_cpu0_o[mode]  = n122; //(module output)
  assign \trace_cpu0_o[ixl]  = n123; //(module output)
  assign \trace_cpu0_o[debug]  = n124; //(module output)
  assign \trace_cpu0_o[compr]  = n125; //(module output)
  assign \trace_cpu0_o[delta]  = n126; //(module output)
  assign \trace_cpu0_o[cmd32]  = n127; //(module output)
  assign \trace_cpu0_o[rs1_addr]  = n128; //(module output)
  assign \trace_cpu0_o[rs2_addr]  = n129; //(module output)
  assign \trace_cpu0_o[rs1_rdata]  = n130; //(module output)
  assign \trace_cpu0_o[rs2_rdata]  = n131; //(module output)
  assign \trace_cpu0_o[rd_addr]  = n132; //(module output)
  assign \trace_cpu0_o[rd_rdata]  = n133; //(module output)
  assign \trace_cpu0_o[pc_rdata]  = n134; //(module output)
  assign \trace_cpu0_o[pc_wdata]  = n135; //(module output)
  assign \trace_cpu0_o[csr_addr]  = n136; //(module output)
  assign \trace_cpu0_o[csr_rdata]  = n137; //(module output)
  assign \trace_cpu0_o[csr_wdata]  = n138; //(module output)
  assign \trace_cpu0_o[mem_addr]  = n139; //(module output)
  assign \trace_cpu0_o[mem_rmask]  = n140; //(module output)
  assign \trace_cpu0_o[mem_wmask]  = n141; //(module output)
  assign \trace_cpu0_o[mem_rdata]  = n142; //(module output)
  assign \trace_cpu0_o[mem_wdata]  = n143; //(module output)
  assign \trace_cpu1_o[valid]  = n145; //(module output)
  assign \trace_cpu1_o[order]  = n146; //(module output)
  assign \trace_cpu1_o[insn]  = n147; //(module output)
  assign \trace_cpu1_o[trap]  = n148; //(module output)
  assign \trace_cpu1_o[halt]  = n149; //(module output)
  assign \trace_cpu1_o[intr]  = n150; //(module output)
  assign \trace_cpu1_o[mode]  = n151; //(module output)
  assign \trace_cpu1_o[ixl]  = n152; //(module output)
  assign \trace_cpu1_o[debug]  = n153; //(module output)
  assign \trace_cpu1_o[compr]  = n154; //(module output)
  assign \trace_cpu1_o[delta]  = n155; //(module output)
  assign \trace_cpu1_o[cmd32]  = n156; //(module output)
  assign \trace_cpu1_o[rs1_addr]  = n157; //(module output)
  assign \trace_cpu1_o[rs2_addr]  = n158; //(module output)
  assign \trace_cpu1_o[rs1_rdata]  = n159; //(module output)
  assign \trace_cpu1_o[rs2_rdata]  = n160; //(module output)
  assign \trace_cpu1_o[rd_addr]  = n161; //(module output)
  assign \trace_cpu1_o[rd_rdata]  = n162; //(module output)
  assign \trace_cpu1_o[pc_rdata]  = n163; //(module output)
  assign \trace_cpu1_o[pc_wdata]  = n164; //(module output)
  assign \trace_cpu1_o[csr_addr]  = n165; //(module output)
  assign \trace_cpu1_o[csr_rdata]  = n166; //(module output)
  assign \trace_cpu1_o[csr_wdata]  = n167; //(module output)
  assign \trace_cpu1_o[mem_addr]  = n168; //(module output)
  assign \trace_cpu1_o[mem_rmask]  = n169; //(module output)
  assign \trace_cpu1_o[mem_wmask]  = n170; //(module output)
  assign \trace_cpu1_o[mem_rdata]  = n171; //(module output)
  assign \trace_cpu1_o[mem_wdata]  = n172; //(module output)
  assign jtag_tdo_o = jtag_tdi_i; //(module output)
  assign smc_ioen_o = n395; //(module output)
  assign smc_sck_o = n396; //(module output)
  assign smc_csn_o = n397; //(module output)
  assign smc_sdo_o = n398; //(module output)
  assign xbus_adr_o = n400; //(module output)
  assign xbus_dat_o = n401; //(module output)
  assign xbus_cti_o = n402; //(module output)
  assign xbus_tag_o = n403; //(module output)
  assign xbus_we_o = n404; //(module output)
  assign xbus_sel_o = n405; //(module output)
  assign xbus_stb_o = n406; //(module output)
  assign xbus_cyc_o = n407; //(module output)
  assign slink_rx_rdy_o = n639; //(module output)
  assign slink_tx_dat_o = n640; //(module output)
  assign slink_tx_dst_o = n641; //(module output)
  assign slink_tx_val_o = n642; //(module output)
  assign slink_tx_lst_o = n643; //(module output)
  assign gpio_dir_o = n596; //(module output)
  assign gpio_o = n597; //(module output)
  assign uart1_txd_o = n619; //(module output)
  assign uart1_rtsn_o = n620; //(module output)
  assign spi_clk_o = n622; //(module output)
  assign spi_dat_o = n623; //(module output)
  assign spi_csn_o = n624; //(module output)
  assign sdi_dat_o = n594; //(module output)
  assign twi_sda_o = n626; //(module output)
  assign twi_scl_o = n627; //(module output)
  assign twd_sda_o = n629; //(module output)
  assign onewire_o = n636; //(module output)
  assign pwm_o = n631; //(module output)
  assign cfs_out_o = n593; //(module output)
  assign neoled_o = n634; //(module output)
  assign mtime_time_o = n602; //(module output)
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n116 = cpu_trace[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n117 = cpu_trace[32:1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n118 = cpu_trace[64:33]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n119 = cpu_trace[65]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n120 = cpu_trace[66]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n121 = cpu_trace[67]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n122 = cpu_trace[69:68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n123 = cpu_trace[71:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n124 = cpu_trace[72]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n125 = cpu_trace[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n126 = cpu_trace[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n127 = cpu_trace[106:75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n128 = cpu_trace[111:107]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n129 = cpu_trace[116:112]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n130 = cpu_trace[148:117]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n131 = cpu_trace[180:149]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n132 = cpu_trace[185:181]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n133 = cpu_trace[217:186]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n134 = cpu_trace[249:218]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n135 = cpu_trace[281:250]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n136 = cpu_trace[293:282]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n137 = cpu_trace[325:294]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n138 = cpu_trace[357:326]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n139 = cpu_trace[389:358]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n140 = cpu_trace[393:390]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n141 = cpu_trace[397:394]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n142 = cpu_trace[429:398]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n143 = cpu_trace[461:430]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n145 = n326[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n146 = n326[32:1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n147 = n326[64:33]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n148 = n326[65]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n149 = n326[66]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n150 = n326[67]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n151 = n326[69:68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n152 = n326[71:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n153 = n326[72]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n154 = n326[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n155 = n326[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n156 = n326[106:75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n157 = n326[111:107]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n158 = n326[116:112]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n159 = n326[148:117]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n160 = n326[180:149]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n161 = n326[185:181]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n162 = n326[217:186]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n163 = n326[249:218]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n164 = n326[281:250]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n165 = n326[293:282]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n166 = n326[325:294]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n167 = n326[357:326]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n168 = n326[389:358]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n169 = n326[393:390]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n170 = n326[397:394]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n171 = n326[429:398]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:21:8 */
  assign n172 = n326[461:430]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:331:10 */
  assign rstn_wdt = 1'b1; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:341:10 */
  assign dci_ndmrstn = 1'b1; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:342:10 */
  assign dci_haltreq = 1'b0; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:346:10 */
  assign cpu_trace = n280; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:10 */
  assign cpu_i_req = n283; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:21 */
  assign cpu_d_req = n289; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:32 */
  assign icache_req = cpu_i_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:44 */
  assign dcache_req = cpu_d_req; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:354:56 */
  assign core_req = n320; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:10 */
  assign cpu_i_rsp = icache_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:21 */
  assign cpu_d_rsp = dcache_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:32 */
  assign icache_rsp = n318; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:355:44 */
  assign dcache_rsp = n306; // (signal)
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
  assign imem_req = n345; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:68 */
  assign dmem_req = n350; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:358:87 */
  assign io_req = n360; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:10 */
  assign sys1_rsp = sys2_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:20 */
  assign sys2_rsp = amo_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:39 */
  assign amo_rsp = sys3_rsp; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:48 */
  assign sys3_rsp = n343; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:58 */
  assign imem_rsp = n380; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:68 */
  assign dmem_rsp = n392; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:78 */
  assign smc_rsp = 34'b0000000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:87 */
  assign io_rsp = n418; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:359:95 */
  assign xbus_rsp = 34'b0000000000000000000000000000000000; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:370:10 */
  assign iodev_req = n662; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:371:10 */
  assign iodev_rsp = n663; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:379:10 */
  assign firq = n664; // (signal)
  /*# ../../rtl/core/neorv32_top.vhd:380:10 */
  assign cpu_firq = n665; // (signal)
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
  assign n265 = firq[8]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:526:23 */
  assign n266 = firq[13]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:527:23 */
  assign n267 = firq[12]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:528:23 */
  assign n268 = firq[14]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:529:23 */
  assign n269 = firq[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:530:23 */
  assign n270 = firq[11]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:531:23 */
  assign n271 = firq[9]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:532:23 */
  assign n272 = firq[6]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:533:23 */
  assign n273 = firq[7]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:534:23 */
  assign n274 = firq[3]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:535:23 */
  assign n275 = firq[10]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:536:23 */
  assign n276 = firq[5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:537:23 */
  assign n277 = firq[4]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:538:23 */
  assign n278 = firq[2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:539:23 */
  assign n279 = firq[1]; // extract
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
    .\ibus_rsp_i[ack] (n285),
    .\ibus_rsp_i[err] (n286),
    .\ibus_rsp_i[data] (n287),
    .\dbus_rsp_i[ack] (n291),
    .\dbus_rsp_i[err] (n292),
    .\dbus_rsp_i[data] (n293),
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
  assign n280 = {\core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_wmask] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_rmask] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mem_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[csr_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_wdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[pc_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rd_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_rdata] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs2_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[rs1_addr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[cmd32] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[delta] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[compr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[debug] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[ixl] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[mode] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[intr] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[halt] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[trap] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[insn] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[order] , \core_complex_gen[0]_neorv32_cpu_inst.trace_o[valid] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n283 = {\core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[lock] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[burst] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amoop] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[amo] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[rw] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[stb] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[ben] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[data] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[addr] , \core_complex_gen[0]_neorv32_cpu_inst.ibus_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n285 = cpu_i_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n286 = cpu_i_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n287 = cpu_i_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n289 = {\core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[lock] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[burst] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amoop] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[amo] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[rw] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[stb] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[ben] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[data] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[addr] , \core_complex_gen[0]_neorv32_cpu_inst.dbus_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n291 = cpu_d_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n292 = cpu_d_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:547:5 */
  assign n293 = cpu_d_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  neorv32_bus_switch_Bneorv32_bus_switch_rtl_Lneorv32_2547cc736e951fa4919853c43ae890861a3b3264 \core_complex_gen[0]_neorv32_core_bus_switch_inst  (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\a_req_i[meta] (n296),
    .\a_req_i[addr] (n297),
    .\a_req_i[data] (n298),
    .\a_req_i[ben] (n299),
    .\a_req_i[stb] (n300),
    .\a_req_i[rw] (n301),
    .\a_req_i[amo] (n302),
    .\a_req_i[amoop] (n303),
    .\a_req_i[burst] (n304),
    .\a_req_i[lock] (n305),
    .\b_req_i[meta] (n308),
    .\b_req_i[addr] (n309),
    .\b_req_i[data] (n310),
    .\b_req_i[ben] (n311),
    .\b_req_i[stb] (n312),
    .\b_req_i[rw] (n313),
    .\b_req_i[amo] (n314),
    .\b_req_i[amoop] (n315),
    .\b_req_i[burst] (n316),
    .\b_req_i[lock] (n317),
    .\x_rsp_i[ack] (n322),
    .\x_rsp_i[err] (n323),
    .\x_rsp_i[data] (n324),
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
  assign n296 = dcache_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n297 = dcache_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n298 = dcache_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n299 = dcache_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n300 = dcache_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n301 = dcache_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n302 = dcache_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n303 = dcache_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n304 = dcache_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n305 = dcache_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n306 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[err] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.a_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n308 = icache_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n309 = icache_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n310 = icache_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n311 = icache_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n312 = icache_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n313 = icache_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n314 = icache_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n315 = icache_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n316 = icache_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n317 = icache_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n318 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[err] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.b_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n320 = {\core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[lock] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[burst] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amoop] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[amo] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[rw] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[stb] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[ben] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[data] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[addr] , \core_complex_gen[0]_neorv32_core_bus_switch_inst.x_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n322 = core_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n323 = core_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:697:5 */
  assign n324 = core_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:718:45 */
  assign n326 = 1'b0 ? cpu_trace : 462'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000;
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  neorv32_bus_gateway_Bneorv32_bus_gateway_rtl_Lneorv32_16384_16_16384_16_268435456_2048_2097152_16_2048_7f8345992e02d837ae3d2c5e4eea30e3ae29fc9f neorv32_bus_gateway_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\req_i[meta] (n333),
    .\req_i[addr] (n334),
    .\req_i[data] (n335),
    .\req_i[ben] (n336),
    .\req_i[stb] (n337),
    .\req_i[rw] (n338),
    .\req_i[amo] (n339),
    .\req_i[amoop] (n340),
    .\req_i[burst] (n341),
    .\req_i[lock] (n342),
    .\a_rsp_i[ack] (n347),
    .\a_rsp_i[err] (n348),
    .\a_rsp_i[data] (n349),
    .\b_rsp_i[ack] (n352),
    .\b_rsp_i[err] (n353),
    .\b_rsp_i[data] (n354),
    .\c_rsp_i[ack] (n357),
    .\c_rsp_i[err] (n358),
    .\c_rsp_i[data] (n359),
    .\d_rsp_i[ack] (n362),
    .\d_rsp_i[err] (n363),
    .\d_rsp_i[data] (n364),
    .\x_rsp_i[ack] (n367),
    .\x_rsp_i[err] (n368),
    .\x_rsp_i[data] (n369),
    .term_o(),
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
    .\x_req_o[meta] (),
    .\x_req_o[addr] (),
    .\x_req_o[data] (),
    .\x_req_o[ben] (),
    .\x_req_o[stb] (),
    .\x_req_o[rw] (),
    .\x_req_o[amo] (),
    .\x_req_o[amoop] (),
    .\x_req_o[burst] (),
    .\x_req_o[lock] ());
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n333 = sys3_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n334 = sys3_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n335 = sys3_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n336 = sys3_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n337 = sys3_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n338 = sys3_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n339 = sys3_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n340 = sys3_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n341 = sys3_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n342 = sys3_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n343 = {\neorv32_bus_gateway_inst.rsp_o[data] , \neorv32_bus_gateway_inst.rsp_o[err] , \neorv32_bus_gateway_inst.rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n345 = {\neorv32_bus_gateway_inst.a_req_o[lock] , \neorv32_bus_gateway_inst.a_req_o[burst] , \neorv32_bus_gateway_inst.a_req_o[amoop] , \neorv32_bus_gateway_inst.a_req_o[amo] , \neorv32_bus_gateway_inst.a_req_o[rw] , \neorv32_bus_gateway_inst.a_req_o[stb] , \neorv32_bus_gateway_inst.a_req_o[ben] , \neorv32_bus_gateway_inst.a_req_o[data] , \neorv32_bus_gateway_inst.a_req_o[addr] , \neorv32_bus_gateway_inst.a_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n347 = imem_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n348 = imem_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n349 = imem_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n350 = {\neorv32_bus_gateway_inst.b_req_o[lock] , \neorv32_bus_gateway_inst.b_req_o[burst] , \neorv32_bus_gateway_inst.b_req_o[amoop] , \neorv32_bus_gateway_inst.b_req_o[amo] , \neorv32_bus_gateway_inst.b_req_o[rw] , \neorv32_bus_gateway_inst.b_req_o[stb] , \neorv32_bus_gateway_inst.b_req_o[ben] , \neorv32_bus_gateway_inst.b_req_o[data] , \neorv32_bus_gateway_inst.b_req_o[addr] , \neorv32_bus_gateway_inst.b_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n352 = dmem_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n353 = dmem_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n354 = dmem_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n357 = smc_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n358 = smc_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n359 = smc_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n360 = {\neorv32_bus_gateway_inst.d_req_o[lock] , \neorv32_bus_gateway_inst.d_req_o[burst] , \neorv32_bus_gateway_inst.d_req_o[amoop] , \neorv32_bus_gateway_inst.d_req_o[amo] , \neorv32_bus_gateway_inst.d_req_o[rw] , \neorv32_bus_gateway_inst.d_req_o[stb] , \neorv32_bus_gateway_inst.d_req_o[ben] , \neorv32_bus_gateway_inst.d_req_o[data] , \neorv32_bus_gateway_inst.d_req_o[addr] , \neorv32_bus_gateway_inst.d_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n362 = io_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n363 = io_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n364 = io_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n367 = xbus_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n368 = xbus_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:857:3 */
  assign n369 = xbus_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  neorv32_imem_Bneorv32_imem_rtl_Lneorv32_16384_0e356ba505631fbf715758bed27d503f8b260e3a memory_system_neorv32_imem_enabled_neorv32_imem_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n370),
    .\bus_req_i[addr] (n371),
    .\bus_req_i[data] (n372),
    .\bus_req_i[ben] (n373),
    .\bus_req_i[stb] (n374),
    .\bus_req_i[rw] (n375),
    .\bus_req_i[amo] (n376),
    .\bus_req_i[amoop] (n377),
    .\bus_req_i[burst] (n378),
    .\bus_req_i[lock] (n379),
    .\bus_rsp_o[ack] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n370 = imem_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n371 = imem_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n372 = imem_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n373 = imem_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n374 = imem_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n375 = imem_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n376 = imem_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n377 = imem_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n378 = imem_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n379 = imem_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:915:7 */
  assign n380 = {\memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[data] , \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[err] , \memory_system_neorv32_imem_enabled_neorv32_imem_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  neorv32_dmem_Bneorv32_dmem_rtl_Lneorv32_16384_5ba93c9db0cff93f52b521d7420e43f6eda2784f memory_system_neorv32_dmem_enabled_neorv32_dmem_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n382),
    .\bus_req_i[addr] (n383),
    .\bus_req_i[data] (n384),
    .\bus_req_i[ben] (n385),
    .\bus_req_i[stb] (n386),
    .\bus_req_i[rw] (n387),
    .\bus_req_i[amo] (n388),
    .\bus_req_i[amoop] (n389),
    .\bus_req_i[burst] (n390),
    .\bus_req_i[lock] (n391),
    .\bus_rsp_o[ack] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n382 = dmem_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n383 = dmem_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n384 = dmem_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n385 = dmem_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n386 = dmem_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n387 = dmem_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n388 = dmem_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n389 = dmem_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n390 = dmem_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n391 = dmem_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:938:7 */
  assign n392 = {\memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[data] , \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[err] , \memory_system_neorv32_dmem_enabled_neorv32_dmem_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  neorv32_bus_io_switch_Bneorv32_bus_io_switch_rtl_Lneorv32_65536_1b53c2fe5410ef4bb6e1726f52befa7beb54e9a8 io_system_neorv32_bus_io_switch_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\main_req_i[meta] (n408),
    .\main_req_i[addr] (n409),
    .\main_req_i[data] (n410),
    .\main_req_i[ben] (n411),
    .\main_req_i[stb] (n412),
    .\main_req_i[rw] (n413),
    .\main_req_i[amo] (n414),
    .\main_req_i[amoop] (n415),
    .\main_req_i[burst] (n416),
    .\main_req_i[lock] (n417),
    .\dev_00_rsp_i[ack] (n423),
    .\dev_00_rsp_i[err] (n424),
    .\dev_00_rsp_i[data] (n425),
    .\dev_01_rsp_i[ack] (n427),
    .\dev_01_rsp_i[err] (n428),
    .\dev_01_rsp_i[data] (n429),
    .\dev_02_rsp_i[ack] (n431),
    .\dev_02_rsp_i[err] (n432),
    .\dev_02_rsp_i[data] (n433),
    .\dev_03_rsp_i[ack] (n435),
    .\dev_03_rsp_i[err] (n436),
    .\dev_03_rsp_i[data] (n437),
    .\dev_04_rsp_i[ack] (n439),
    .\dev_04_rsp_i[err] (n440),
    .\dev_04_rsp_i[data] (n441),
    .\dev_05_rsp_i[ack] (n443),
    .\dev_05_rsp_i[err] (n444),
    .\dev_05_rsp_i[data] (n445),
    .\dev_06_rsp_i[ack] (n447),
    .\dev_06_rsp_i[err] (n448),
    .\dev_06_rsp_i[data] (n449),
    .\dev_07_rsp_i[ack] (n451),
    .\dev_07_rsp_i[err] (n452),
    .\dev_07_rsp_i[data] (n453),
    .\dev_08_rsp_i[ack] (n455),
    .\dev_08_rsp_i[err] (n456),
    .\dev_08_rsp_i[data] (n457),
    .\dev_09_rsp_i[ack] (n459),
    .\dev_09_rsp_i[err] (n460),
    .\dev_09_rsp_i[data] (n461),
    .\dev_10_rsp_i[ack] (n465),
    .\dev_10_rsp_i[err] (n466),
    .\dev_10_rsp_i[data] (n467),
    .\dev_11_rsp_i[ack] (n471),
    .\dev_11_rsp_i[err] (n472),
    .\dev_11_rsp_i[data] (n473),
    .\dev_12_rsp_i[ack] (n477),
    .\dev_12_rsp_i[err] (n478),
    .\dev_12_rsp_i[data] (n479),
    .\dev_13_rsp_i[ack] (n483),
    .\dev_13_rsp_i[err] (n484),
    .\dev_13_rsp_i[data] (n485),
    .\dev_14_rsp_i[ack] (n487),
    .\dev_14_rsp_i[err] (n488),
    .\dev_14_rsp_i[data] (n489),
    .\dev_15_rsp_i[ack] (n493),
    .\dev_15_rsp_i[err] (n494),
    .\dev_15_rsp_i[data] (n495),
    .\dev_16_rsp_i[ack] (n499),
    .\dev_16_rsp_i[err] (n500),
    .\dev_16_rsp_i[data] (n501),
    .\dev_17_rsp_i[ack] (n505),
    .\dev_17_rsp_i[err] (n506),
    .\dev_17_rsp_i[data] (n507),
    .\dev_18_rsp_i[ack] (n511),
    .\dev_18_rsp_i[err] (n512),
    .\dev_18_rsp_i[data] (n513),
    .\dev_19_rsp_i[ack] (n517),
    .\dev_19_rsp_i[err] (n518),
    .\dev_19_rsp_i[data] (n519),
    .\dev_20_rsp_i[ack] (n523),
    .\dev_20_rsp_i[err] (n524),
    .\dev_20_rsp_i[data] (n525),
    .\dev_21_rsp_i[ack] (n529),
    .\dev_21_rsp_i[err] (n530),
    .\dev_21_rsp_i[data] (n531),
    .\dev_22_rsp_i[ack] (n535),
    .\dev_22_rsp_i[err] (n536),
    .\dev_22_rsp_i[data] (n537),
    .\dev_23_rsp_i[ack] (n541),
    .\dev_23_rsp_i[err] (n542),
    .\dev_23_rsp_i[data] (n543),
    .\dev_24_rsp_i[ack] (n547),
    .\dev_24_rsp_i[err] (n548),
    .\dev_24_rsp_i[data] (n549),
    .\dev_25_rsp_i[ack] (n553),
    .\dev_25_rsp_i[err] (n554),
    .\dev_25_rsp_i[data] (n555),
    .\dev_26_rsp_i[ack] (n559),
    .\dev_26_rsp_i[err] (n560),
    .\dev_26_rsp_i[data] (n561),
    .\dev_27_rsp_i[ack] (n565),
    .\dev_27_rsp_i[err] (n566),
    .\dev_27_rsp_i[data] (n567),
    .\dev_28_rsp_i[ack] (n571),
    .\dev_28_rsp_i[err] (n572),
    .\dev_28_rsp_i[data] (n573),
    .\dev_29_rsp_i[ack] (n577),
    .\dev_29_rsp_i[err] (n578),
    .\dev_29_rsp_i[data] (n579),
    .\dev_30_rsp_i[ack] (n583),
    .\dev_30_rsp_i[err] (n584),
    .\dev_30_rsp_i[data] (n585),
    .\dev_31_rsp_i[ack] (n589),
    .\dev_31_rsp_i[err] (n590),
    .\dev_31_rsp_i[data] (n591),
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
  assign n408 = io_req[4:0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n409 = io_req[36:5]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n410 = io_req[68:37]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n411 = io_req[72:69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n412 = io_req[73]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n413 = io_req[74]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n414 = io_req[75]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n415 = io_req[79:76]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n416 = io_req[80]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n417 = io_req[81]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n418 = {\io_system_neorv32_bus_io_switch_inst.main_rsp_o[data] , \io_system_neorv32_bus_io_switch_inst.main_rsp_o[err] , \io_system_neorv32_bus_io_switch_inst.main_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n420 = {\io_system_neorv32_bus_io_switch_inst.dev_00_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_00_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n423 = iodev_rsp[714]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n424 = iodev_rsp[715]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n425 = iodev_rsp[747:716]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n427 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n428 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n429 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n431 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n432 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n433 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n435 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n436 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n437 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n439 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n440 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n441 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n443 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n444 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n445 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n447 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n448 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n449 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n451 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n452 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n453 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n455 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n456 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n457 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n459 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n460 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n461 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n462 = {\io_system_neorv32_bus_io_switch_inst.dev_10_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_10_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n465 = iodev_rsp[68]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n466 = iodev_rsp[69]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n467 = iodev_rsp[101:70]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n468 = {\io_system_neorv32_bus_io_switch_inst.dev_11_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_11_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n471 = iodev_rsp[102]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n472 = iodev_rsp[103]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n473 = iodev_rsp[135:104]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n474 = {\io_system_neorv32_bus_io_switch_inst.dev_12_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_12_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n477 = iodev_rsp[136]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n478 = iodev_rsp[137]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n479 = iodev_rsp[169:138]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n480 = {\io_system_neorv32_bus_io_switch_inst.dev_13_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_13_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n483 = iodev_rsp[170]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n484 = iodev_rsp[171]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n485 = iodev_rsp[203:172]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n487 = n328[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n488 = n328[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n489 = n328[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n490 = {\io_system_neorv32_bus_io_switch_inst.dev_15_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_15_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n493 = iodev_rsp[0]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n494 = iodev_rsp[1]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n495 = iodev_rsp[33:2]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n496 = {\io_system_neorv32_bus_io_switch_inst.dev_16_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_16_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n499 = iodev_rsp[204]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n500 = iodev_rsp[205]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n501 = iodev_rsp[237:206]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n502 = {\io_system_neorv32_bus_io_switch_inst.dev_17_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_17_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n505 = iodev_rsp[238]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n506 = iodev_rsp[239]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n507 = iodev_rsp[271:240]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n508 = {\io_system_neorv32_bus_io_switch_inst.dev_18_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_18_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n511 = iodev_rsp[272]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n512 = iodev_rsp[273]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n513 = iodev_rsp[305:274]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n514 = {\io_system_neorv32_bus_io_switch_inst.dev_19_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_19_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n517 = iodev_rsp[34]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n518 = iodev_rsp[35]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n519 = iodev_rsp[67:36]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n520 = {\io_system_neorv32_bus_io_switch_inst.dev_20_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_20_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n523 = iodev_rsp[306]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n524 = iodev_rsp[307]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n525 = iodev_rsp[339:308]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n526 = {\io_system_neorv32_bus_io_switch_inst.dev_21_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_21_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n529 = iodev_rsp[340]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n530 = iodev_rsp[341]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n531 = iodev_rsp[373:342]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n532 = {\io_system_neorv32_bus_io_switch_inst.dev_22_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_22_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n535 = iodev_rsp[374]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n536 = iodev_rsp[375]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n537 = iodev_rsp[407:376]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n538 = {\io_system_neorv32_bus_io_switch_inst.dev_23_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_23_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n541 = iodev_rsp[408]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n542 = iodev_rsp[409]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n543 = iodev_rsp[441:410]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n544 = {\io_system_neorv32_bus_io_switch_inst.dev_24_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_24_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n547 = iodev_rsp[442]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n548 = iodev_rsp[443]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n549 = iodev_rsp[475:444]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n550 = {\io_system_neorv32_bus_io_switch_inst.dev_25_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_25_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n553 = iodev_rsp[476]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n554 = iodev_rsp[477]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n555 = iodev_rsp[509:478]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n556 = {\io_system_neorv32_bus_io_switch_inst.dev_26_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_26_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n559 = iodev_rsp[510]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n560 = iodev_rsp[511]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n561 = iodev_rsp[543:512]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n562 = {\io_system_neorv32_bus_io_switch_inst.dev_27_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_27_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n565 = iodev_rsp[544]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n566 = iodev_rsp[545]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n567 = iodev_rsp[577:546]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n568 = {\io_system_neorv32_bus_io_switch_inst.dev_28_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_28_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n571 = iodev_rsp[578]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n572 = iodev_rsp[579]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n573 = iodev_rsp[611:580]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n574 = {\io_system_neorv32_bus_io_switch_inst.dev_29_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_29_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n577 = iodev_rsp[612]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n578 = iodev_rsp[613]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n579 = iodev_rsp[645:614]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n580 = {\io_system_neorv32_bus_io_switch_inst.dev_30_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_30_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n583 = iodev_rsp[646]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n584 = iodev_rsp[647]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n585 = iodev_rsp[679:648]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n586 = {\io_system_neorv32_bus_io_switch_inst.dev_31_req_o[lock] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[burst] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amoop] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[amo] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[rw] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[stb] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[ben] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[data] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[addr] , \io_system_neorv32_bus_io_switch_inst.dev_31_req_o[meta] };
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n589 = iodev_rsp[680]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n590 = iodev_rsp[681]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1044:5 */
  assign n591 = iodev_rsp[713:682]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  neorv32_uart_Bneorv32_uart_rtl_Lneorv32_1_1 io_system_neorv32_uart0_enabled_neorv32_uart0_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n604),
    .\bus_req_i[addr] (n605),
    .\bus_req_i[data] (n606),
    .\bus_req_i[ben] (n607),
    .\bus_req_i[stb] (n608),
    .\bus_req_i[rw] (n609),
    .\bus_req_i[amo] (n610),
    .\bus_req_i[amoop] (n611),
    .\bus_req_i[burst] (n612),
    .\bus_req_i[lock] (n613),
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
  assign n604 = iodev_req[824:820]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n605 = iodev_req[856:825]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n606 = iodev_req[888:857]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n607 = iodev_req[892:889]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n608 = iodev_req[893]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n609 = iodev_req[894]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n610 = iodev_req[895]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n611 = iodev_req[899:896]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n612 = iodev_req[900]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n613 = iodev_req[901]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1290:7 */
  assign n614 = {\io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[data] , \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[err] , \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  neorv32_sysinfo_Bneorv32_sysinfo_rtl_Lneorv32_16_2048_1_100000000_2_16384_16384_4_4_64_3592969d31b6bbf38f334a2a4d979986a3a69b1a io_system_neorv32_sysinfo_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_sys),
    .\bus_req_i[meta] (n646),
    .\bus_req_i[addr] (n647),
    .\bus_req_i[data] (n648),
    .\bus_req_i[ben] (n649),
    .\bus_req_i[stb] (n650),
    .\bus_req_i[rw] (n651),
    .\bus_req_i[amo] (n652),
    .\bus_req_i[amoop] (n653),
    .\bus_req_i[burst] (n654),
    .\bus_req_i[lock] (n655),
    .\bus_rsp_o[ack] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] ),
    .\bus_rsp_o[err] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[err] ),
    .\bus_rsp_o[data] (\io_system_neorv32_sysinfo_inst.bus_rsp_o[data] ));
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n646 = iodev_req[1562:1558]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n647 = iodev_req[1594:1563]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n648 = iodev_req[1626:1595]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n649 = iodev_req[1630:1627]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n650 = iodev_req[1631]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n651 = iodev_req[1632]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n652 = iodev_req[1633]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n653 = iodev_req[1637:1634]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n654 = iodev_req[1638]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n655 = iodev_req[1639]; // extract
  /*# ../../rtl/core/neorv32_top.vhd:1635:5 */
  assign n656 = {\io_system_neorv32_sysinfo_inst.bus_rsp_o[data] , \io_system_neorv32_sysinfo_inst.bus_rsp_o[err] , \io_system_neorv32_sysinfo_inst.bus_rsp_o[ack] };
  /*# ../../rtl/core/neorv32_top.vhd:370:10 */
  assign n662 = {n420, n586, n580, n574, n568, n562, n556, n550, n544, n538, n532, n526, n520, n508, n502, n496, n480, n474, n468, n462, n514, n490};
  /*# ../../rtl/core/neorv32_top.vhd:371:10 */
  assign n663 = {34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, n656, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, n614, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000, 34'b0000000000000000000000000000000000};
  /*# ../../rtl/core/neorv32_top.vhd:379:10 */
  assign n664 = {1'b0, \io_system_neorv32_uart0_enabled_neorv32_uart0_inst.irq_o , 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
  /*# ../../rtl/core/neorv32_top.vhd:380:10 */
  assign n665 = {n279, n278, n277, n276, n275, n274, n273, n272, n271, n270, n269, n268, n267, n266, n265, 1'b0};
endmodule

module neorv32_verilog_wrapper
  (input  clk_i,
   input  rstn_i,
   output uart0_txd_o,
   input  uart0_rxd_i);
  localparam n5 = 1'b0;
  localparam n6 = 1'b0;
  localparam n8 = 1'b0;
  localparam n13 = 1'b0;
  localparam [31:0] n22 = 32'b00000000000000000000000000000000;
  localparam n23 = 1'b0;
  localparam n24 = 1'b0;
  localparam [31:0] n25 = 32'b00000000000000000000000000000000;
  localparam [3:0] n26 = 4'b0000;
  localparam n27 = 1'b0;
  localparam n28 = 1'b0;
  localparam n34 = 1'b0;
  localparam [31:0] n37 = 32'b00000000000000000000000000000000;
  wire neorv32_top_inst_n38;
  localparam n40 = 1'b0;
  localparam n42 = 1'b0;
  localparam n44 = 1'b0;
  localparam n47 = 1'b0;
  localparam n49 = 1'b0;
  localparam n51 = 1'b0;
  localparam n52 = 1'b1;
  localparam n53 = 1'b1;
  localparam n55 = 1'b1;
  localparam n57 = 1'b1;
  localparam n59 = 1'b1;
  localparam n60 = 1'b1;
  localparam [255:0] n63 = 256'b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  localparam n67 = 1'b0;
  localparam n68 = 1'b0;
  localparam n69 = 1'b0;
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
  wire [31:0] \neorv32_top_inst.xbus_adr_o ;
  wire [31:0] \neorv32_top_inst.xbus_dat_o ;
  wire [2:0] \neorv32_top_inst.xbus_cti_o ;
  wire [2:0] \neorv32_top_inst.xbus_tag_o ;
  wire \neorv32_top_inst.xbus_we_o ;
  wire [3:0] \neorv32_top_inst.xbus_sel_o ;
  wire \neorv32_top_inst.xbus_stb_o ;
  wire \neorv32_top_inst.xbus_cyc_o ;
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
  assign uart0_txd_o = neorv32_top_inst_n38; //(module output)
  /*# neorv32_verilog_wrapper.vhd:34:3 */
  neorv32_top_Bneorv32_top_rtl_Lneorv32_100000000_2_0_0_0_4_0_40_16384_16384_4_4_64_2048_0_1_1_1_1_1_1_1_1_1_0_1_3_5_64_1_0_1_4_1_1_1_6e3c239da792a1cf02e3b569dfcea5aaaa030a63 neorv32_top_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .jtag_tck_i(1'b0),
    .jtag_tdi_i(1'b0),
    .jtag_tms_i(1'b0),
    .smc_sdi_i(1'b0),
    .xbus_dat_i(32'b00000000000000000000000000000000),
    .xbus_ack_i(1'b0),
    .xbus_err_i(1'b0),
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
    .xbus_adr_o(),
    .xbus_dat_o(),
    .xbus_cti_o(),
    .xbus_tag_o(),
    .xbus_we_o(),
    .xbus_sel_o(),
    .xbus_stb_o(),
    .xbus_cyc_o(),
    .slink_rx_rdy_o(),
    .slink_tx_dat_o(),
    .slink_tx_dst_o(),
    .slink_tx_val_o(),
    .slink_tx_lst_o(),
    .gpio_dir_o(),
    .gpio_o(),
    .uart0_txd_o(neorv32_top_inst_n38),
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

