`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_decoder
// Description: RV64IMAFDC instruction decoder for eth_rv (32-bit + compressed 16-bit forms).
// Details:     Combinational, stateless: one 32-bit instruction image in, one
//              `ctrl_t` + register addresses + 64-bit immediate out. The core
//              instantiates exactly one decoder and drives it from the IF stage,
//              so the static branch predictor and the ID stage share the same
//              decode result (no duplicated immediate logic to drift out of sync).
//
//              Illegal / reserved / unimplemented encodings set `ctrl_t.illegal`
//              instead of decoding to something plausible: the core turns that
//              into the error strobe and never retires the instruction (C14 §3,
//              "未实现 CSR 访问 -> 非法指令异常，不静默").
//
//              Coverage is the corpus subset: RV64I (LUI/AUIPC/JAL/JALR/branch/
//              load/store/OP-IMM/OP-IMM-32/OP/OP-32, FENCE as a no-op), RV64M
//              (all eight mul/div plus the four W forms), the integer RV64C
//              forms and the SYSTEM subset (CSRRW/CSRRS/CSRRC + the immediate
//              forms on the implemented CSRs, ecall, ebreak, mret, sret).
//              Any other SYSTEM encoding (wfi/sfence/…) and any CSR number this
//              core does not implement decodes to illegal — never to a no-op
//              (C14 §3). The *privilege* rules of SYSTEM (which mode may execute
//              mret/sret, which may touch a given CSR, and which ecall cause a
//              mode raises) depend on runtime state, so they are enforced in
//              eth_rv_core, not here.
//
//              Immediate bit mappings were cross-checked field by field against
//              the reference interpreter in the DiffTest harness (rv_model.py),
//              including the two C-extension traps C14 §5.4 calls out: the
//              odd bit-5 of C.J and the scattered C.ADDI16SP/C.ADDI4SPN maps.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (ID stage), §5.4 (C-extension traps)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       No procedural loops, defaults-first, `unique case` on enum selects
//              so a missed encoding is a lint error rather than a silent default.
module cor_decoder (
    input  logic                is_c_i,     // insn_i[1:0] != 2'b11 (computed by IF)
    input  logic [31:0]         insn_i,
    output eth_rv_pkg::ctrl_t   ctrl_o,
    output logic [4:0]          rd_addr_o,
    output logic [4:0]          rs1_addr_o,
    output logic [4:0]          rs2_addr_o,
    output logic [4:0]          rs3_addr_o,
    output logic [eth_rv_pkg::XLEN-1:0] imm_o,
    output logic                pred_taken_o   // static prediction (IF only: backward branch)
);

    // ------------------------------------------------------- opcode map
    localparam logic [6:0] OP_LUI     = 7'h37;
    localparam logic [6:0] OP_AUIPC   = 7'h17;
    localparam logic [6:0] OP_JAL     = 7'h6f;
    localparam logic [6:0] OP_JALR    = 7'h67;
    localparam logic [6:0] OP_BRANCH  = 7'h63;
    localparam logic [6:0] OP_LOAD    = 7'h03;
    localparam logic [6:0] OP_STORE   = 7'h23;
    localparam logic [6:0] OP_IMM     = 7'h13;
    localparam logic [6:0] OP_IMM32   = 7'h1b;
    localparam logic [6:0] OP_REG     = 7'h33;
    localparam logic [6:0] OP_REG32   = 7'h3b;
    localparam logic [6:0] OP_MISC    = 7'h0f;
    localparam logic [6:0] OP_AMO     = 7'h2f;   // lr.w/d, sc.w/d, amo*.{w,d} (A)
    localparam logic [6:0] OP_SYSTEM  = 7'h73;
    // floating point (E2-RV2 increment 2): the F/D opcodes
    localparam logic [6:0] OP_LOADFP  = 7'h07;   // flw / fld
    localparam logic [6:0] OP_STOREFP = 7'h27;   // fsw / fsd
    localparam logic [6:0] OP_FP      = 7'h53;   // the OP-FP group
    localparam logic [6:0] OP_FMADD   = 7'h43;
    localparam logic [6:0] OP_FMSUB   = 7'h47;
    localparam logic [6:0] OP_FNMSUB  = 7'h4b;
    localparam logic [6:0] OP_FNMADD  = 7'h4f;

    // ------------------------------------------------------- fields
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd;         // 32-bit instruction fields
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd_p;       // compressed prime register class (x8..x15)
    logic [4:0] rs1_p;
    logic [4:0] rs2_p;
    logic [1:0] q;          // compressed quadrant
    logic [4:0] c_rd;
    logic [4:0] c_rs2;
    logic [5:0] c_imm6;     // C.LI / C.ADDI / C.ANDI 6-bit signed immediate
    logic [5:0] c_shamt;    // C.SLLI / C.SRLI / C.SRAI shift amount (6 bits in RV64C)
    logic [1:0] c_funct2w;  // C.SUB..C.ANDW sub-op (C.SRLI..C.ANDI use insn[11:10])

    // ------------------------------------------------------- immediates
    logic [63:0] i_imm;
    logic [63:0] s_imm;
    logic [63:0] b_imm;
    logic [63:0] j_imm;
    logic [63:0] u_imm;
    logic [63:0] ci4spn_imm;
    logic [63:0] clw_imm;
    logic [63:0] cld_imm;
    logic [63:0] cimm6_sext;
    logic [63:0] caddi16sp_imm;
    logic [63:0] clui_imm;
    logic [63:0] cj_imm;
    logic [63:0] cb_imm;
    logic [63:0] cshamt_imm;
    logic [63:0] clwsp_imm;
    logic [63:0] cldsp_imm;
    logic [63:0] cswsp_imm;
    logic [63:0] csdsp_imm;

    assign opcode = insn_i[6:0];
    assign funct3 = insn_i[14:12];
    assign funct7 = insn_i[31:25];
    assign rd     = insn_i[11:7];
    assign rs1    = insn_i[19:15];
    assign rs2    = insn_i[24:20];
    assign q      = insn_i[1:0];
    assign rd_p   = 5'd8 + {2'b00, insn_i[4:2]};
    assign rs1_p  = 5'd8 + {2'b00, insn_i[9:7]};
    assign rs2_p  = 5'd8 + {2'b00, insn_i[4:2]};
    assign c_rd   = insn_i[11:7];
    assign c_rs2  = insn_i[6:2];
    assign c_imm6 = {insn_i[12], insn_i[6:2]};
    assign c_shamt = {insn_i[12], insn_i[6:2]};
    assign c_funct2w = insn_i[6:5];

    assign i_imm = {{52{insn_i[31]}}, insn_i[31:20]};
    assign s_imm = {{52{insn_i[31]}}, insn_i[31:25], insn_i[11:7]};
    assign b_imm = {{51{insn_i[31]}}, insn_i[31], insn_i[7], insn_i[30:25], insn_i[11:8], 1'b0};
    assign j_imm = {{43{insn_i[31]}}, insn_i[31], insn_i[19:12], insn_i[20], insn_i[30:21], 1'b0};
    assign u_imm = {{32{insn_i[31]}}, insn_i[31:12], 12'd0};

    // C.ADDI4SPN: nzuimm = {insn[10:7], insn[12:11], insn[5], insn[6], 2'b00}
    assign ci4spn_imm = {54'd0, insn_i[10:7], insn_i[12:11], insn_i[5], insn_i[6], 2'b00};
    // C.LW / C.SW offset = {insn[5], insn[12:10], insn[6], 2'b00}
    assign clw_imm = {57'd0, insn_i[5], insn_i[12:10], insn_i[6], 2'b00};
    // C.LD / C.SD offset = {insn[6:5], insn[12:10], 3'b000}
    assign cld_imm = {56'd0, insn_i[6:5], insn_i[12:10], 3'b000};
    assign cimm6_sext = {{58{c_imm6[5]}}, c_imm6};
    // C.ADDI16SP: nzimm = {insn[12], insn[4:3], insn[5], insn[2], insn[6], 4'b0000}
    assign caddi16sp_imm = {{54{insn_i[12]}}, insn_i[12], insn_i[4:3], insn_i[5], insn_i[2],
                            insn_i[6], 4'b0000};
    assign clui_imm = cimm6_sext << 12;
    // C.J: offset = {insn[12], insn[8], insn[10:9], insn[6], insn[7], insn[2],
    //                insn[11], insn[5:3], 1'b0}
    assign cj_imm = {{52{insn_i[12]}}, insn_i[12], insn_i[8], insn_i[10:9], insn_i[6],
                     insn_i[7], insn_i[2], insn_i[11], insn_i[5:3], 1'b0};
    // C.BEQZ/C.BNEZ: offset = {insn[12], insn[6:5], insn[2], insn[11:10], insn[4:3], 1'b0}
    assign cb_imm = {{55{insn_i[12]}}, insn_i[12], insn_i[6:5], insn_i[2], insn_i[11:10],
                     insn_i[4:3], 1'b0};
    assign cshamt_imm = {58'd0, c_shamt};
    // C.LWSP offset = {insn[3:2], insn[12], insn[6:4], 2'b00}
    assign clwsp_imm = {56'd0, insn_i[3:2], insn_i[12], insn_i[6:4], 2'b00};
    // C.LDSP offset = {insn[4:2], insn[12], insn_i[6:5], 3'b000}
    assign cldsp_imm = {55'd0, insn_i[4:2], insn_i[12], insn_i[6:5], 3'b000};
    // C.SWSP offset = {insn[8:7], insn[12:9], 2'b00}
    assign cswsp_imm = {56'd0, insn_i[8:7], insn_i[12:9], 2'b00};
    // C.SDSP offset = {insn[9:7], insn[12:10], 3'b000}
    assign csdsp_imm = {55'd0, insn_i[9:7], insn_i[12:10], 3'b000};

    // ------------------------------------------------------- decode
    always_comb begin
        ctrl_o       = '0;
        pred_taken_o = 1'b0;
        rd_addr_o = 5'd0;
        rs1_addr_o = 5'd0;
        rs2_addr_o = 5'd0;
        rs3_addr_o = 5'd0;
        imm_o     = 64'd0;

        if (!is_c_i) begin
            unique case (opcode)
                // ----------------------------------------------------
                OP_LUI: begin
                    ctrl_o.rf_we   = 1'b1;
                    ctrl_o.wb_sel  = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_op  = eth_rv_pkg::ALU_PASSB;
                    ctrl_o.alu_a   = eth_rv_pkg::OP_A_ZERO;
                    ctrl_o.alu_b   = eth_rv_pkg::OP_B_IMM;
                    rd_addr_o      = rd;
                    imm_o          = u_imm;
                end
                OP_AUIPC: begin
                    ctrl_o.rf_we   = 1'b1;
                    ctrl_o.wb_sel  = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_op  = eth_rv_pkg::ALU_ADD;
                    ctrl_o.alu_a   = eth_rv_pkg::OP_A_PC;
                    ctrl_o.alu_b   = eth_rv_pkg::OP_B_IMM;
                    rd_addr_o      = rd;
                    imm_o          = u_imm;
                end
                OP_JAL: begin
                    ctrl_o.rf_we   = 1'b1;
                    ctrl_o.wb_sel  = eth_rv_pkg::WB_LINK;
                    ctrl_o.alu_op  = eth_rv_pkg::ALU_ADD;
                    ctrl_o.alu_a   = eth_rv_pkg::OP_A_PC;
                    ctrl_o.alu_b   = eth_rv_pkg::OP_B_IMM;
                    ctrl_o.is_jump = 1'b1;
                    rd_addr_o      = rd;
                    imm_o          = j_imm;
                end
                OP_JALR: begin
                    if (funct3 == 3'b000) begin
                        ctrl_o.rf_we       = 1'b1;
                        ctrl_o.wb_sel      = eth_rv_pkg::WB_LINK;
                        ctrl_o.alu_op      = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a       = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b       = eth_rv_pkg::OP_B_IMM;
                        ctrl_o.is_jump     = 1'b1;
                        ctrl_o.is_indirect = 1'b1;
                        rd_addr_o          = rd;
                        rs1_addr_o         = rs1;
                        imm_o              = i_imm;
                    end else begin
                        ctrl_o.illegal = 1'b1;
                    end
                end
                OP_BRANCH: begin
                    if (funct3 == 3'b010 || funct3 == 3'b011) begin
                        ctrl_o.illegal = 1'b1;
                    end else begin
                        ctrl_o.is_branch  = 1'b1;
                        pred_taken_o      = b_imm[63];
                        ctrl_o.br_f3      = funct3;
                        ctrl_o.alu_op     = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a      = eth_rv_pkg::OP_A_PC;
                        ctrl_o.alu_b      = eth_rv_pkg::OP_B_IMM;
                        rs1_addr_o        = rs1;
                        rs2_addr_o        = rs2;
                        imm_o             = b_imm;
                    end
                end
                OP_LOAD: begin
                    if (funct3 == 3'b111) begin
                        ctrl_o.illegal = 1'b1;
                    end else begin
                        ctrl_o.rf_we      = 1'b1;
                        ctrl_o.wb_sel     = eth_rv_pkg::WB_MEM;
                        ctrl_o.is_load    = 1'b1;
                        ctrl_o.rd_late    = 1'b1;
                        ctrl_o.mem_signed = (funct3[2] == 1'b0);
                        ctrl_o.mem_size   = mem_size_of(funct3[1:0]);
                        ctrl_o.alu_op     = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a      = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b      = eth_rv_pkg::OP_B_IMM;
                        rd_addr_o         = rd;
                        rs1_addr_o        = rs1;
                        imm_o             = i_imm;
                    end
                end
                OP_STORE: begin
                    if (funct3[2] == 1'b1) begin
                        ctrl_o.illegal = 1'b1;
                    end else begin
                        ctrl_o.is_store = 1'b1;
                        ctrl_o.mem_size = mem_size_of(funct3[1:0]);
                        ctrl_o.alu_op   = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a    = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b    = eth_rv_pkg::OP_B_IMM;
                        rs1_addr_o      = rs1;
                        rs2_addr_o      = rs2;
                        imm_o           = s_imm;
                    end
                end
                // ----------------------------------------------------
                // A extension (RV64A, E2-RV2 increment 3): lr/sc/amo. The single
                // memory operand is `(rs1)` — the encoding has an rs1 field and NO
                // immediate — so the address comes straight from the ALU like a
                // register-register op (`alu_b` stays the zeroed OP_B_RS2 default
                // and `imm_o` is 0, so `rs1 + 0` is the address).
                //
                // Width: funct3 = 010 is the .w form (4 bytes, sign-extended into
                // rd) and 011 the .d form (8 bytes), exactly like a load/store of
                // that width, so the misalignment rule and the byte-lane masks are
                // cor_lsu's and need no A-extension special case. Any other funct3
                // is reserved and illegal.
                //
                // `aq` (bit 26) and `rl` (bit 25) are accepted and ignored: they
                // order accesses against *other* harts, and this core is a
                // single-hart, single-outstanding-access machine whose program
                // order IS the memory order (see verif/eth_rv/README.md).
                OP_AMO: begin
                    // The width is funct3 = 010 (.w) or 011 (.d) — the same two
                    // encodings the load/store group uses, and the same
                    // `mem_size_of(funct3[1:0])` decode: 10 -> SZ_WORD, 11 ->
                    // SZ_DWRD. (`funct3 == 3'b011` is the .d form, so the low bit
                    // is what selects the width; testing the HIGH bit instead
                    // marks every .d form illegal.)
                    if ((funct3 == 3'b010) || (funct3 == 3'b011)) begin
                        ctrl_o.mem_size = mem_size_of(funct3[1:0]);
                        // the .w forms extend the loaded word into rd (LR) / hold
                        // the 32-bit memory word (AMO); .d is a full doubleword
                        ctrl_o.mem_signed = (funct3 == 3'b010);
                        ctrl_o.alu_op     = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a      = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b      = eth_rv_pkg::OP_B_IMM;   // rs1 + 0 = rs1: the encoding has no offset
                        ctrl_o.wb_sel     = eth_rv_pkg::WB_MEM;
                        rs1_addr_o        = rs1;
                        imm_o             = 64'd0;
                        unique case (insn_i[31:27])
                            // lr.w / lr.d: a load that also arms the reservation.
                            // Spike's encoding mask (MASK_LR_W = 0xf9f0707f) holds
                            // rs2 to zero in the match, so an lr with rs2 != 0 is
                            // not an lr at all and stays illegal.
                            5'b00010: begin
                                if (rs2 == 5'd0) begin
                                    ctrl_o.is_load = 1'b1;
                                    ctrl_o.is_lr   = 1'b1;
                                    ctrl_o.rd_late = 1'b1;
                                    ctrl_o.rf_we   = 1'b1;
                                    rd_addr_o      = rd;
                                end else begin
                                    ctrl_o.illegal = 1'b1;
                                end
                            end
                            // sc.w / sc.d: a conditional store; rd reports success
                            5'b00011: begin
                                ctrl_o.is_store = 1'b1;
                                ctrl_o.is_sc    = 1'b1;
                                ctrl_o.rd_late  = 1'b1;
                                ctrl_o.rf_we    = 1'b1;
                                rs2_addr_o      = rs2;
                                rd_addr_o       = rd;
                            end
                            // the nine amo.* read-modify-write forms
                            5'b00000, 5'b00001, 5'b00100, 5'b01000, 5'b01100,
                            5'b10000, 5'b10100, 5'b11000, 5'b11100: begin
                                ctrl_o.is_store = 1'b1;
                                ctrl_o.is_amo   = 1'b1;
                                ctrl_o.rd_late  = 1'b1;
                                ctrl_o.rf_we    = 1'b1;
                                ctrl_o.amo_op   = amo_op_of(insn_i[31:27]);
                                rs2_addr_o      = rs2;
                                rd_addr_o       = rd;
                            end
                            default: ctrl_o.illegal = 1'b1;   // reserved funct5
                        endcase
                    end else begin
                        ctrl_o.illegal = 1'b1;   // reserved width / funct3
                    end
                end
                // ----------------------------------------------------
                OP_IMM: begin
                    ctrl_o.rf_we  = 1'b1;
                    ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                    ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                    rd_addr_o     = rd;
                    rs1_addr_o    = rs1;
                    imm_o         = i_imm;
                    unique case (funct3)
                        3'b000: ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                        3'b010: ctrl_o.alu_op = eth_rv_pkg::ALU_SLT;
                        3'b011: ctrl_o.alu_op = eth_rv_pkg::ALU_SLTU;
                        3'b100: ctrl_o.alu_op = eth_rv_pkg::ALU_XOR;
                        3'b110: ctrl_o.alu_op = eth_rv_pkg::ALU_OR;
                        3'b111: ctrl_o.alu_op = eth_rv_pkg::ALU_AND;
                        3'b001: begin
                            // slli: insn[31:26] must be zero (shamt[5] lives in insn[25])
                            if (insn_i[31:26] != 6'd0) begin
                                ctrl_o.illegal = 1'b1;
                            end else begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SLL;
                            end
                        end
                        3'b101: begin
                            if (insn_i[31:26] == 6'd0) begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SRL;
                            end else if (insn_i[31:26] == 6'b010000) begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SRA;
                            end else begin
                                ctrl_o.illegal = 1'b1;
                            end
                        end
                        default: ctrl_o.illegal = 1'b1;
                    endcase
                end
                OP_IMM32: begin
                    ctrl_o.rf_we  = 1'b1;
                    ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_w  = 1'b1;
                    ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                    ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                    rd_addr_o     = rd;
                    rs1_addr_o    = rs1;
                    imm_o         = i_imm;
                    unique case (funct3)
                        3'b000: ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                        3'b001: begin
                            if (funct7 != 7'd0) begin
                                ctrl_o.illegal = 1'b1;
                            end else begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SLL;
                            end
                        end
                        3'b101: begin
                            if (funct7 == 7'd0) begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SRL;
                            end else if (funct7 == 7'b0100000) begin
                                ctrl_o.alu_op = eth_rv_pkg::ALU_SRA;
                            end else begin
                                ctrl_o.illegal = 1'b1;
                            end
                        end
                        default: ctrl_o.illegal = 1'b1;
                    endcase
                end
                // ----------------------------------------------------
                OP_REG: begin
                    ctrl_o.rf_we = 1'b1;
                    ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_b = eth_rv_pkg::OP_B_RS2;
                    rd_addr_o    = rd;
                    rs1_addr_o   = rs1;
                    rs2_addr_o   = rs2;
                    if (funct7 == 7'b0000001) begin
                        ctrl_o.is_muldiv = 1'b1;
                        ctrl_o.alu_a     = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.md_op     = md_op_of(funct3, 1'b0);
                    end else begin
                        ctrl_o.alu_a = eth_rv_pkg::OP_A_RS1;
                        unique case ({funct7, funct3})
                            {7'b0000000, 3'b000}: ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                            {7'b0000000, 3'b001}: ctrl_o.alu_op = eth_rv_pkg::ALU_SLL;
                            {7'b0000000, 3'b010}: ctrl_o.alu_op = eth_rv_pkg::ALU_SLT;
                            {7'b0000000, 3'b011}: ctrl_o.alu_op = eth_rv_pkg::ALU_SLTU;
                            {7'b0000000, 3'b100}: ctrl_o.alu_op = eth_rv_pkg::ALU_XOR;
                            {7'b0000000, 3'b101}: ctrl_o.alu_op = eth_rv_pkg::ALU_SRL;
                            {7'b0000000, 3'b110}: ctrl_o.alu_op = eth_rv_pkg::ALU_OR;
                            {7'b0000000, 3'b111}: ctrl_o.alu_op = eth_rv_pkg::ALU_AND;
                            {7'b0100000, 3'b000}: ctrl_o.alu_op = eth_rv_pkg::ALU_SUB;
                            {7'b0100000, 3'b101}: ctrl_o.alu_op = eth_rv_pkg::ALU_SRA;
                            default:              ctrl_o.illegal = 1'b1;
                        endcase
                    end
                end
                OP_REG32: begin
                    ctrl_o.rf_we = 1'b1;
                    ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                    ctrl_o.alu_w = 1'b1;
                    ctrl_o.alu_b = eth_rv_pkg::OP_B_RS2;
                    rd_addr_o    = rd;
                    rs1_addr_o   = rs1;
                    rs2_addr_o   = rs2;
                    if (funct7 == 7'b0000001) begin
                        ctrl_o.is_muldiv = 1'b1;
                        ctrl_o.alu_a     = eth_rv_pkg::OP_A_RS1;
                        if (funct3 == 3'b001 || funct3 == 3'b010 || funct3 == 3'b011) begin
                            ctrl_o.illegal = 1'b1;   // no mulh/mulhsu/mulhu W-forms in RV64M
                        end else begin
                            ctrl_o.md_op = md_op_of(funct3, 1'b1);
                        end
                    end else begin
                        ctrl_o.alu_a = eth_rv_pkg::OP_A_RS1;
                        unique case ({funct7, funct3})
                            {7'b0000000, 3'b000}: ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                            {7'b0000000, 3'b001}: ctrl_o.alu_op = eth_rv_pkg::ALU_SLL;
                            {7'b0000000, 3'b101}: ctrl_o.alu_op = eth_rv_pkg::ALU_SRL;
                            {7'b0100000, 3'b000}: ctrl_o.alu_op = eth_rv_pkg::ALU_SUB;
                            {7'b0100000, 3'b101}: ctrl_o.alu_op = eth_rv_pkg::ALU_SRA;
                            default:              ctrl_o.illegal = 1'b1;
                        endcase
                    end
                end
                // fence / fence.i: no architectural effect (model DUT: no-op)
                OP_MISC: begin
                    ctrl_o.alu_a = eth_rv_pkg::OP_A_ZERO;
                    ctrl_o.alu_b = eth_rv_pkg::OP_B_IMM;
                end
                // ---- FP loads / stores (F/D) --------------------------------
                // The base register is an INTEGER register, the data register an
                // FP one; `mem_signed` is irrelevant (the load zero-extends into
                // the format and FLW NaN-boxes in the MEM stage).
                OP_LOADFP: begin
                    if (funct3 == 3'b010 || funct3 == 3'b011) begin
                        ctrl_o.is_fp       = 1'b1;
                        ctrl_o.fp_we       = 1'b1;
                        ctrl_o.fp_single   = (funct3 == 3'b010);
                        ctrl_o.wb_sel      = eth_rv_pkg::WB_MEM;
                        ctrl_o.is_load     = 1'b1;
                        ctrl_o.rd_late     = 1'b1;
                        ctrl_o.mem_size    = (funct3 == 3'b010) ? eth_rv_pkg::SZ_WORD
                                                                : eth_rv_pkg::SZ_DWRD;
                        ctrl_o.alu_op      = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a       = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b       = eth_rv_pkg::OP_B_IMM;
                        rd_addr_o          = rd;
                        rs1_addr_o         = rs1;
                        imm_o              = i_imm;
                    end else begin
                        ctrl_o.illegal = 1'b1;
                    end
                end
                OP_STOREFP: begin
                    if (funct3 == 3'b010 || funct3 == 3'b011) begin
                        ctrl_o.is_fp     = 1'b1;
                        ctrl_o.fp_single = (funct3 == 3'b010);
                        ctrl_o.fp_rs2_fp = 1'b1;
                        ctrl_o.is_store  = 1'b1;
                        ctrl_o.mem_size  = (funct3 == 3'b010) ? eth_rv_pkg::SZ_WORD
                                                              : eth_rv_pkg::SZ_DWRD;
                        ctrl_o.alu_op    = eth_rv_pkg::ALU_ADD;
                        ctrl_o.alu_a     = eth_rv_pkg::OP_A_RS1;
                        ctrl_o.alu_b     = eth_rv_pkg::OP_B_IMM;
                        rs1_addr_o       = rs1;
                        rs2_addr_o       = rs2;
                        imm_o            = s_imm;
                    end else begin
                        ctrl_o.illegal = 1'b1;
                    end
                end
                // ---- OP-FP: arithmetic, compare, convert, move --------------
                OP_FP: begin
                    if (funct7[1:0] == 2'b10 || funct7[1:0] == 2'b11) begin
                        ctrl_o.illegal = 1'b1;   // no half / quad precision
                    end else begin
                         ctrl_o.is_fp     = 1'b1;
                        ctrl_o.fp_single = (funct7[1:0] == 2'b00);
                        ctrl_o.fp_rs1_fp = 1'b1;
                        ctrl_o.fp_rs2_fp = 1'b1;
                        // every OP-FP form writes an FP register unless the case
                        // below overrides it (the compares and the FP->int converts
                        // write an integer register instead)
                        ctrl_o.fp_we     = 1'b1;
                        rd_addr_o        = rd;
                        rs1_addr_o       = rs1;
                        rs2_addr_o       = rs2;
                        unique case (funct7[6:2])
                            5'b00000: begin ctrl_o.fp_op = eth_rv_pkg::FP_ADD; end
                            5'b00001: begin ctrl_o.fp_op = eth_rv_pkg::FP_SUB; end
                            5'b00010: begin ctrl_o.fp_op = eth_rv_pkg::FP_MUL; end
                            5'b00011: begin ctrl_o.fp_op = eth_rv_pkg::FP_DIV; end
                            5'b01011: begin ctrl_o.fp_op = eth_rv_pkg::FP_SQRT; end
                            5'b00100: begin
                                unique case (funct3)
                                    3'b000: ctrl_o.fp_op = eth_rv_pkg::FP_SGNJ;
                                    3'b001: ctrl_o.fp_op = eth_rv_pkg::FP_SGNJN;
                                    3'b010: ctrl_o.fp_op = eth_rv_pkg::FP_SGNJX;
                                    default: ctrl_o.illegal = 1'b1;
                                endcase
                            end
                            5'b00101: begin
                                unique case (funct3)
                                    3'b000: ctrl_o.fp_op = eth_rv_pkg::FP_MIN;
                                    3'b001: ctrl_o.fp_op = eth_rv_pkg::FP_MAX;
                                    default: ctrl_o.illegal = 1'b1;
                                endcase
                            end
                            // fsgnj*/fmin/fmax write an FP register and read no rm
                            // 01000: fcvt.s.d / fcvt.d.s (rs2 selects the source)
                            5'b01000: begin
                                ctrl_o.fp_op        = eth_rv_pkg::FP_CVT_FP_FP;
                                ctrl_o.fp_src_single = (rs2 == 5'd0);
                                if (rs2 > 5'd1) begin
                                    ctrl_o.illegal = 1'b1;
                                end
                            end
                            // 10100: the comparisons (integer destination)
                            5'b10100: begin
                                ctrl_o.fp_we = 1'b0;
                                ctrl_o.rf_we = 1'b1;
                                unique case (funct3)
                                    3'b010: ctrl_o.fp_op = eth_rv_pkg::FP_EQ;
                                    3'b001: ctrl_o.fp_op = eth_rv_pkg::FP_LT;
                                    3'b000: ctrl_o.fp_op = eth_rv_pkg::FP_LE;
                                    default: ctrl_o.illegal = 1'b1;
                                endcase
                            end
                            // 11000: fcvt.{w,wu,l,lu}.{s,d}  (FP -> integer)
                            5'b11000: begin
                                ctrl_o.fp_we = 1'b0;
                                ctrl_o.rf_we = 1'b1;
                                ctrl_o.fp_op = eth_rv_pkg::FP_CVT_FP_I;
                                ctrl_o.fp_iw = rs2[1:0];
                                if (rs2 > 5'd3) begin
                                    ctrl_o.illegal = 1'b1;
                                end
                            end
                            // 11010: fcvt.{s,d}.{w,wu,l,lu}  (integer -> FP)
                            5'b11010: begin
                                ctrl_o.fp_we     = 1'b1;
                                ctrl_o.fp_rs1_fp = 1'b0;
                                ctrl_o.fp_rs2_fp = 1'b0;
                                ctrl_o.fp_op     = eth_rv_pkg::FP_CVT_I_FP;
                                ctrl_o.fp_iw     = rs2[1:0];
                                if (rs2 > 5'd3) begin
                                    ctrl_o.illegal = 1'b1;
                                end
                            end
                            // 11100: fclass (funct3 = 001) / fmv.x.w|d (funct3 = 000)
                            5'b11100: begin
                                ctrl_o.fp_we = 1'b0;
                                ctrl_o.rf_we = 1'b1;
                                unique case (funct3)
                                    3'b001: ctrl_o.fp_op = eth_rv_pkg::FP_CLASS;
                                    3'b000: ctrl_o.fp_op = eth_rv_pkg::FP_MV_X_FP;
                                    default: ctrl_o.illegal = 1'b1;
                                endcase
                            end
                            // 11110: fmv.w.x / fmv.d.x
                            5'b11110: begin
                                ctrl_o.fp_we     = 1'b1;
                                ctrl_o.fp_rs1_fp = 1'b0;
                                ctrl_o.fp_rs2_fp = 1'b0;
                                ctrl_o.fp_op     = eth_rv_pkg::FP_MV_FP_X;
                                if (rs2 != 5'd0) begin
                                    ctrl_o.illegal = 1'b1;
                                end
                            end
                            default: ctrl_o.illegal = 1'b1;
                        endcase
                        // arithmetic / convert forms carry an rm field
                        if (eth_rv_pkg::fp_op_uses_rm(ctrl_o.fp_op)) begin
                            ctrl_o.fp_rm_used = 1'b1;
                            ctrl_o.fp_rm      = funct3;
                        end
                    end
                end
                // ---- fused multiply-add -------------------------------------
                OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD: begin
                    if (insn_i[26:25] == 2'b10 || insn_i[26:25] == 2'b11) begin
                        ctrl_o.illegal = 1'b1;   // no half / quad precision
                    end else begin
                        ctrl_o.is_fp     = 1'b1;
                        ctrl_o.fp_we     = 1'b1;
                        ctrl_o.fp_single = (insn_i[26:25] == 2'b00);
                        ctrl_o.fp_rs1_fp = 1'b1;
                        ctrl_o.fp_rs2_fp = 1'b1;
                        ctrl_o.fp_rm_used = 1'b1;
                        ctrl_o.fp_rm     = funct3;
                        rd_addr_o        = rd;
                        rs1_addr_o       = rs1;
                        rs2_addr_o       = rs2;
                        rs3_addr_o       = insn_i[31:27];
                        unique case (opcode)
                            OP_FMADD:  ctrl_o.fp_op = eth_rv_pkg::FP_MADD;
                            OP_FMSUB:  ctrl_o.fp_op = eth_rv_pkg::FP_MSUB;
                            OP_FNMSUB: ctrl_o.fp_op = eth_rv_pkg::FP_NMSUB;
                            default:   ctrl_o.fp_op = eth_rv_pkg::FP_NMADD;
                        endcase
                    end
                end
                // SYSTEM: the trap/CSR instructions of the M/S/U machine. The
                // privilege rules of mret/sret/wfi (and of every CSR access) depend
                // on the *current* privilege, so the decoder only classifies the
                // encoding; eth_rv_core raises the illegal-instruction trap when
                // the mode forbids it. Anything else stays illegal and must never
                // become an unnoticed no-op.
                OP_SYSTEM: begin
                    if (funct3 == 3'b000) begin
                        // sfence.vma (E2-RV2 increment 1) is decoded FIRST: its
                        // imm[11:5] is 0001001, so the trap/CSR case below would
                        // otherwise mark it illegal (imm[4:0] is rs2, which no
                        // other encoding here uses). Only the x0, x0 form is
                        // architecturally the plain fence; the rs1/rs2 forms carry
                        // a vaddr/ASID the RTL has no cached translation to filter
                        // (see cor_mmu), so all of them decode the same way. rd is
                        // read-only zero in the encoding, so nothing writes back.
                        if (insn_i[31:25] == 7'b0001001) begin
                            ctrl_o.is_sfence = 1'b1;
                            rd_addr_o        = 5'd0;
                        end else begin
                            unique case (insn_i[31:20])
                                12'h000: ctrl_o.is_ecall  = 1'b1;
                                12'h001: ctrl_o.is_ebreak = 1'b1;
                                12'h102: ctrl_o.is_sret   = 1'b1;
                                12'h302: ctrl_o.is_mret   = 1'b1;
                                // wfi (E2-RV2 increment 3). Spike's encoding table
                                // masks the whole word (MASK_WFI is 0xffffffff), so
                                // only the exact 0x10500073 form is the
                                // architectural wfi: the 12-bit `imm` here carries
                                // the 0x105 (its low five bits land in bits 24:20,
                                // which are an IMMEDIATE field for funct3 = 000 —
                                // NOT an rs2), leaving rd and rs1 as the only
                                // register fields, which must both be zero. The
                                // privilege rule (S or M; U-mode wfi is an illegal
                                // instruction) is applied in eth_rv_core, where the
                                // current mode is known.
                                12'h105: begin
                                    if ((rd == 5'd0) && (rs1 == 5'd0)) begin
                                        ctrl_o.is_wfi = 1'b1;
                                    end else begin
                                        ctrl_o.illegal = 1'b1;
                                    end
                                end
                                default: ctrl_o.illegal   = 1'b1;
                            endcase
                        end
                    end else if (funct3[1:0] != 2'b00) begin
                        // csrrw/csrrs/csrrc + the immediate (uimm) forms. The op
                        // select is exactly funct3[1:0] (see csr_op_e).
                        if (eth_rv_pkg::csr_implemented(insn_i[31:20])) begin
                            ctrl_o.is_csr   = 1'b1;
                            ctrl_o.csr_op   = eth_rv_pkg::csr_op_e'(funct3[1:0]);
                            ctrl_o.csr_imm  = funct3[2];
                            ctrl_o.csr_addr = insn_i[31:20];
                            ctrl_o.rf_we    = 1'b1;   // rd may still be x0
                            ctrl_o.alu_a    = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b    = eth_rv_pkg::OP_B_IMM;
                            ctrl_o.wb_sel   = eth_rv_pkg::WB_CSR;
                            rd_addr_o       = rd;
                            if (funct3[2]) begin
                                // immediate form: the uimm rides the immediate bus,
                                // so no register read (and no false hazard) happens
                                imm_o = {59'd0, rs1};
                            end else begin
                                rs1_addr_o = rs1;
                            end
                        end else begin
                            // Unimplemented CSR number: illegal, never silent.
                            ctrl_o.illegal = 1'b1;
                        end
                    end else begin
                        ctrl_o.illegal = 1'b1;   // funct3 = 100 (reserved)
                    end
                end
                default: begin
                    ctrl_o.illegal = 1'b1;
                end
            endcase
        end else begin
            // ======================= compressed (16-bit) =======================
            unique case (q)
                2'b00: begin
                    unique case (insn_i[15:13])
                        3'b000: begin
                            if (ci4spn_imm == 64'd0) begin
                                ctrl_o.illegal = 1'b1;
                            end else begin
                                ctrl_o.rf_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                                ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                                ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                                rd_addr_o     = rd_p;
                                rs1_addr_o    = 5'd2;   // sp
                                imm_o         = ci4spn_imm;
                            end
                        end
                        3'b010, 3'b011: begin
                            // C.LW / C.LD
                            ctrl_o.rf_we      = 1'b1;
                            ctrl_o.wb_sel     = eth_rv_pkg::WB_MEM;
                            ctrl_o.is_load    = 1'b1;
                            ctrl_o.rd_late    = 1'b1;
                            ctrl_o.mem_signed = (insn_i[13] == 1'b0);
                            ctrl_o.mem_size   = (insn_i[13] == 1'b0) ? eth_rv_pkg::SZ_WORD
                                                                    : eth_rv_pkg::SZ_DWRD;
                            ctrl_o.alu_op     = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a      = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b      = eth_rv_pkg::OP_B_IMM;
                            rd_addr_o         = rd_p;
                            rs1_addr_o        = rs1_p;
                            imm_o             = (insn_i[13] == 1'b0) ? clw_imm : cld_imm;
                        end
                        3'b001, 3'b101: begin
                            // C.FLD / C.FSD (RV64); C.FLW / C.FSW do not exist in
                            // the RV64 C extension, so these are the FP pair.
                            ctrl_o.is_fp     = 1'b1;
                            ctrl_o.fp_single = 1'b0;
                            ctrl_o.mem_size  = eth_rv_pkg::SZ_DWRD;
                            ctrl_o.alu_op    = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a     = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b     = eth_rv_pkg::OP_B_IMM;
                            rs1_addr_o       = rs1_p;
                            imm_o            = cld_imm;
                            // C.FLD (funct3 = 001) and C.FSD (funct3 = 101) differ in
                            // bit 15 — bits 14 and 13 are 0 and 1 in BOTH (funct3's
                            // low bits), so only the high funct3 bit splits them.
                            if (insn_i[15] == 1'b0) begin
                                // C.FLD: an FP destination
                                ctrl_o.fp_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_MEM;
                                ctrl_o.is_load = 1'b1;
                                ctrl_o.rd_late = 1'b1;
                                rd_addr_o     = rd_p;
                            end else begin
                                // C.FSD: an FP source
                                ctrl_o.fp_rs2_fp = 1'b1;
                                ctrl_o.is_store  = 1'b1;
                                rs2_addr_o       = rs2_p;
                            end
                        end
                        3'b110, 3'b111: begin
                            // C.SW / C.SD
                            ctrl_o.is_store = 1'b1;
                            ctrl_o.mem_size = (insn_i[13] == 1'b0) ? eth_rv_pkg::SZ_WORD
                                                                  : eth_rv_pkg::SZ_DWRD;
                            ctrl_o.alu_op   = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a    = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b    = eth_rv_pkg::OP_B_IMM;
                            rs1_addr_o      = rs1_p;
                            rs2_addr_o      = rs2_p;
                            imm_o           = (insn_i[13] == 1'b0) ? clw_imm : cld_imm;
                        end
                        default: ctrl_o.illegal = 1'b1;   // FP loads / reserved
                    endcase
                end
                2'b01: begin
                    unique case (insn_i[15:13])
                        3'b000: begin
                            // C.ADDI (rd = x0 is the C.NOP hint; still a legal no-write)
                            ctrl_o.rf_we  = 1'b1;
                            ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                            ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                            rd_addr_o     = c_rd;
                            rs1_addr_o    = c_rd;
                            imm_o         = cimm6_sext;
                        end
                        3'b001: begin
                            // C.ADDIW (rd = 0 reserved)
                            if (c_rd == 5'd0) begin
                                ctrl_o.illegal = 1'b1;
                            end else begin
                                ctrl_o.rf_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                                ctrl_o.alu_w  = 1'b1;
                                ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                                ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                                rd_addr_o     = c_rd;
                                rs1_addr_o    = c_rd;
                                imm_o         = cimm6_sext;
                            end
                        end
                        3'b010: begin
                            // C.LI
                            ctrl_o.rf_we  = 1'b1;
                            ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                            ctrl_o.alu_op = eth_rv_pkg::ALU_PASSB;
                            ctrl_o.alu_a  = eth_rv_pkg::OP_A_ZERO;
                            ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                            rd_addr_o     = c_rd;
                            imm_o         = cimm6_sext;
                        end
                        3'b011: begin
                            if (c_rd == 5'd2) begin
                                // C.ADDI16SP
                                ctrl_o.rf_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                                ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                                ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                                rd_addr_o     = 5'd2;
                                rs1_addr_o    = 5'd2;
                                imm_o         = caddi16sp_imm;
                            end else begin
                                // C.LUI (rd = 0 is a hint; the write is dropped)
                                ctrl_o.rf_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                ctrl_o.alu_op = eth_rv_pkg::ALU_PASSB;
                                ctrl_o.alu_a  = eth_rv_pkg::OP_A_ZERO;
                                ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                                rd_addr_o     = c_rd;
                                imm_o         = clui_imm;
                            end
                        end
                        3'b100: begin
                            // C.SRLI / C.SRAI / C.ANDI / C.SUB..C.AND / C.SUBW / C.ADDW
                            ctrl_o.rf_we  = 1'b1;
                            ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                            ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                            rd_addr_o     = rs1_p;
                            rs1_addr_o    = rs1_p;
                            unique case (insn_i[11:10])
                                2'b00: begin
                                    ctrl_o.alu_op = eth_rv_pkg::ALU_SRL;
                                    imm_o         = cshamt_imm;
                                end
                                2'b01: begin
                                    ctrl_o.alu_op = eth_rv_pkg::ALU_SRA;
                                    imm_o         = cshamt_imm;
                                end
                                2'b10: begin
                                    ctrl_o.alu_op = eth_rv_pkg::ALU_AND;
                                    imm_o         = cimm6_sext;
                                end
                                default: begin
                                    ctrl_o.alu_b = eth_rv_pkg::OP_B_RS2;
                                    rs2_addr_o   = rs2_p;
                                    if (insn_i[12] == 1'b0) begin
                                        unique case (c_funct2w)
                                            2'b00: ctrl_o.alu_op = eth_rv_pkg::ALU_SUB;
                                            2'b01: ctrl_o.alu_op = eth_rv_pkg::ALU_XOR;
                                            2'b10: ctrl_o.alu_op = eth_rv_pkg::ALU_OR;
                                            default: ctrl_o.alu_op = eth_rv_pkg::ALU_AND;
                                        endcase
                                    end else begin
                                        ctrl_o.alu_w = 1'b1;
                                        unique case (c_funct2w)
                                            2'b00: ctrl_o.alu_op = eth_rv_pkg::ALU_SUB;
                                            2'b01: ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                                            default: ctrl_o.illegal = 1'b1;
                                        endcase
                                    end
                                end
                            endcase
                        end
                        3'b101, 3'b110, 3'b111: begin
                            // C.J / C.BEQZ / C.BNEZ
                            ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a  = eth_rv_pkg::OP_A_PC;
                            ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                            rs1_addr_o    = rs1_p;
                            if (insn_i[15:13] == 3'b101) begin
                                ctrl_o.is_jump = 1'b1;
                                imm_o          = cj_imm;
                            end else begin
                                ctrl_o.is_branch  = 1'b1;
                                ctrl_o.br_f3      = (insn_i[15:13] == 3'b110) ? 3'b000 : 3'b001;
                                pred_taken_o      = cb_imm[63];
                                imm_o             = cb_imm;
                            end
                        end
                        default: ctrl_o.illegal = 1'b1;
                    endcase
                end
                2'b10: begin
                    unique case (insn_i[15:13])
                        3'b000: begin
                            // C.SLLI
                            ctrl_o.rf_we  = 1'b1;
                            ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                            ctrl_o.alu_op = eth_rv_pkg::ALU_SLL;
                            ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b  = eth_rv_pkg::OP_B_IMM;
                            rd_addr_o     = c_rd;
                            rs1_addr_o    = c_rd;
                            imm_o         = cshamt_imm;
                        end
                        3'b001, 3'b101: begin
                            // C.FLDSP / C.FSDSP (RV64)
                            ctrl_o.is_fp     = 1'b1;
                            ctrl_o.fp_single = 1'b0;
                            ctrl_o.mem_size  = eth_rv_pkg::SZ_DWRD;
                            ctrl_o.alu_op    = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a     = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b     = eth_rv_pkg::OP_B_IMM;
                            rs1_addr_o       = 5'd2;
                            if (insn_i[15] == 1'b0) begin
                                ctrl_o.fp_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_MEM;
                                ctrl_o.is_load = 1'b1;
                                ctrl_o.rd_late = 1'b1;
                                rd_addr_o     = c_rd;
                                imm_o         = cldsp_imm;
                            end else begin
                                ctrl_o.fp_rs2_fp = 1'b1;
                                ctrl_o.is_store  = 1'b1;
                                rs2_addr_o       = c_rs2;
                                imm_o            = csdsp_imm;
                            end
                        end
                        3'b010, 3'b011: begin
                            // C.LWSP / C.LDSP (rd = 0 reserved)
                            if (c_rd == 5'd0) begin
                                ctrl_o.illegal = 1'b1;
                            end else begin
                                ctrl_o.rf_we      = 1'b1;
                                ctrl_o.wb_sel     = eth_rv_pkg::WB_MEM;
                                ctrl_o.is_load    = 1'b1;
                                ctrl_o.rd_late    = 1'b1;
                                ctrl_o.mem_signed = 1'b0;
                                ctrl_o.mem_size   = (insn_i[13] == 1'b0) ? eth_rv_pkg::SZ_WORD
                                                                        : eth_rv_pkg::SZ_DWRD;
                                ctrl_o.alu_op     = eth_rv_pkg::ALU_ADD;
                                ctrl_o.alu_a      = eth_rv_pkg::OP_A_RS1;
                                ctrl_o.alu_b      = eth_rv_pkg::OP_B_IMM;
                                rd_addr_o         = c_rd;
                                rs1_addr_o        = 5'd2;   // sp
                                imm_o             = (insn_i[13] == 1'b0) ? clwsp_imm : cldsp_imm;
                            end
                        end
                        3'b100: begin
                            if (insn_i[12] == 1'b1) begin
                                if (c_rs2 == 5'd0) begin
                                    if (c_rd == 5'd0) begin
                                        // C.EBREAK: the same breakpoint exception as the
                                        // 32-bit encoding (a trap, never a no-op)
                                        ctrl_o.is_ebreak = 1'b1;
                                    end else begin
                                        // C.JALR (link into x1)
                                        ctrl_o.rf_we       = 1'b1;
                                        ctrl_o.wb_sel      = eth_rv_pkg::WB_LINK;
                                        ctrl_o.alu_op      = eth_rv_pkg::ALU_ADD;
                                        ctrl_o.alu_a       = eth_rv_pkg::OP_A_RS1;
                                        ctrl_o.alu_b       = eth_rv_pkg::OP_B_IMM;
                                        ctrl_o.is_jump     = 1'b1;
                                        ctrl_o.is_indirect = 1'b1;
                                        rd_addr_o          = 5'd1;
                                        rs1_addr_o         = c_rd;
                                    end
                                end else begin
                                    // C.ADD
                                    ctrl_o.rf_we  = 1'b1;
                                    ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                    ctrl_o.alu_op = eth_rv_pkg::ALU_ADD;
                                    ctrl_o.alu_a  = eth_rv_pkg::OP_A_RS1;
                                    ctrl_o.alu_b  = eth_rv_pkg::OP_B_RS2;
                                    rd_addr_o     = c_rd;
                                    rs1_addr_o    = c_rd;
                                    rs2_addr_o    = c_rs2;
                                end
                            end else if (c_rs2 == 5'd0) begin
                                if (c_rd == 5'd0) begin
                                    ctrl_o.illegal = 1'b1;       // C.JR x0 reserved
                                end else begin
                                    // C.JR
                                    ctrl_o.alu_op      = eth_rv_pkg::ALU_ADD;
                                    ctrl_o.alu_a       = eth_rv_pkg::OP_A_RS1;
                                    ctrl_o.alu_b       = eth_rv_pkg::OP_B_IMM;
                                    ctrl_o.is_jump     = 1'b1;
                                    ctrl_o.is_indirect = 1'b1;
                                    rs1_addr_o         = c_rd;
                                end
                            end else begin
                                // C.MV
                                ctrl_o.rf_we  = 1'b1;
                                ctrl_o.wb_sel = eth_rv_pkg::WB_ALU;
                                ctrl_o.alu_op = eth_rv_pkg::ALU_PASSB;
                                ctrl_o.alu_a  = eth_rv_pkg::OP_A_ZERO;
                                ctrl_o.alu_b  = eth_rv_pkg::OP_B_RS2;
                                rd_addr_o     = c_rd;
                                rs2_addr_o    = c_rs2;
                            end
                        end
                        3'b110, 3'b111: begin
                            // C.SWSP / C.SDSP
                            ctrl_o.is_store = 1'b1;
                            ctrl_o.mem_size = (insn_i[13] == 1'b0) ? eth_rv_pkg::SZ_WORD
                                                                  : eth_rv_pkg::SZ_DWRD;
                            ctrl_o.alu_op   = eth_rv_pkg::ALU_ADD;
                            ctrl_o.alu_a    = eth_rv_pkg::OP_A_RS1;
                            ctrl_o.alu_b    = eth_rv_pkg::OP_B_IMM;
                            rs1_addr_o      = 5'd2;   // sp
                            rs2_addr_o      = c_rs2;
                            imm_o           = (insn_i[13] == 1'b0) ? cswsp_imm : csdsp_imm;
                        end
                        default: ctrl_o.illegal = 1'b1;   // FP / reserved
                    endcase
                end
                default: ctrl_o.illegal = 1'b1;   // quadrant 3 does not exist
            endcase
        end
    end

    // --------------------------------------------------------- helpers
    function automatic eth_rv_pkg::mem_size_e mem_size_of(input logic [1:0] code);
        unique case (code)
            2'b00:   mem_size_of = eth_rv_pkg::SZ_BYTE;
            2'b01:   mem_size_of = eth_rv_pkg::SZ_HALF;
            2'b10:   mem_size_of = eth_rv_pkg::SZ_WORD;
            default: mem_size_of = eth_rv_pkg::SZ_DWRD;
        endcase
    endfunction

    // funct5 of the AMO encodings (insn[31:27], with aq/rl in 26:25 ignored) ->
    // the operation the MEM stage's read-modify-write datapath applies. Only
    // called for the nine forms the decode case accepts, so the default arm is
    // unreachable.
    function automatic eth_rv_pkg::amo_op_e amo_op_of(input logic [4:0] funct5);
        unique case (funct5)
            5'b00000: amo_op_of = eth_rv_pkg::AMO_ADD;
            5'b00001: amo_op_of = eth_rv_pkg::AMO_SWAP;
            5'b00100: amo_op_of = eth_rv_pkg::AMO_XOR;
            5'b01000: amo_op_of = eth_rv_pkg::AMO_OR;
            5'b01100: amo_op_of = eth_rv_pkg::AMO_AND;
            5'b10000: amo_op_of = eth_rv_pkg::AMO_MIN;
            5'b10100: amo_op_of = eth_rv_pkg::AMO_MAX;
            5'b11000: amo_op_of = eth_rv_pkg::AMO_MINU;
            default:  amo_op_of = eth_rv_pkg::AMO_MAXU;   // 5'b11100
        endcase
    endfunction

    function automatic eth_rv_pkg::md_op_e md_op_of(input logic [2:0] f3, input logic w);
        unique case ({w, f3})
            {1'b0, 3'b000}: md_op_of = eth_rv_pkg::MD_MUL;
            {1'b0, 3'b001}: md_op_of = eth_rv_pkg::MD_MULH;
            {1'b0, 3'b010}: md_op_of = eth_rv_pkg::MD_MULHSU;
            {1'b0, 3'b011}: md_op_of = eth_rv_pkg::MD_MULHU;
            {1'b0, 3'b100}: md_op_of = eth_rv_pkg::MD_DIV;
            {1'b0, 3'b101}: md_op_of = eth_rv_pkg::MD_DIVU;
            {1'b0, 3'b110}: md_op_of = eth_rv_pkg::MD_REM;
            {1'b0, 3'b111}: md_op_of = eth_rv_pkg::MD_REMU;
            {1'b1, 3'b000}: md_op_of = eth_rv_pkg::MD_MULW;
            {1'b1, 3'b100}: md_op_of = eth_rv_pkg::MD_DIVW;
            {1'b1, 3'b101}: md_op_of = eth_rv_pkg::MD_DIVUW;
            {1'b1, 3'b110}: md_op_of = eth_rv_pkg::MD_REMW;
            default:        md_op_of = eth_rv_pkg::MD_REMUW;   // {1'b1, 3'b111}
        endcase
    endfunction

endmodule
`default_nettype wire
