`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_pkg
// Description: Frozen parameter pack + decode/writeback control types for eth_rv (RV64IMC, RV-B).
// Details:     Single blessed configuration (C14 §2): XLEN = 64, one hart, no MMU / FPU /
//              CSR / trap path. Every pipeline-control field travels as one packed
//              struct (`ctrl_t`) so the IF->ID->EX->MEM->WB registers stay flat
//              vectors and the core lints clean under `-Wall`.
//
//              The enum values are chosen so that a zeroed struct is a legal
//              "no write / no memory / add" control word: the decoder starts from
//              `ctrl = '0` and overrides only what an encoding needs, which is
//              what keeps the decoder free of latches and of repeated defaults.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §2 (frozen parameter pack),
//              §3 (micro-architecture), §4 (RVFI trace port)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       RV-B v0 scope: RV64I + M + C integer subset. Unimplemented encodings
//              (SYSTEM/CSR/FPU/atomics) set `ctrl_t.illegal` and raise the core error
//              strobe — they NEVER retire silently (C14 §3).
package eth_rv_pkg;

    // ---------------------------------------------------------------- config
    localparam int unsigned XLEN     = 64;
    localparam int unsigned REG_ADDR = 5;
    localparam int unsigned REG_NUM  = 32;

    localparam logic [63:0] RESET_PC = 64'h0000_0000_8000_0000;
    // ------------------------------------------------------------- alu ops
    typedef enum logic [3:0] {
        ALU_ADD   = 4'd0,
        ALU_SUB   = 4'd1,
        ALU_SLL   = 4'd2,
        ALU_SLT   = 4'd3,
        ALU_SLTU  = 4'd4,
        ALU_XOR   = 4'd5,
        ALU_SRL   = 4'd6,
        ALU_SRA   = 4'd7,
        ALU_OR    = 4'd8,
        ALU_AND   = 4'd9,
        ALU_PASSB = 4'd10
    } alu_op_e;

    // --------------------------------------------------- operand / wb select
    typedef enum logic [1:0] {
        OP_A_RS1  = 2'd0,
        OP_A_PC   = 2'd1,
        OP_A_ZERO = 2'd2
    } op_a_sel_e;

    typedef enum logic [1:0] {
        OP_B_RS2 = 2'd0,
        OP_B_IMM = 2'd1
    } op_b_sel_e;

    typedef enum logic [1:0] {
        WB_ALU  = 2'd0,
        WB_MEM  = 2'd1,
        WB_LINK = 2'd2   // pc + 2 (compressed) or pc + 4
    } wb_sel_e;

    // ------------------------------------------------ M-extension operation
    typedef enum logic [3:0] {
        MD_MUL    = 4'd0,
        MD_MULH   = 4'd1,
        MD_MULHSU = 4'd2,
        MD_MULHU  = 4'd3,
        MD_DIV    = 4'd4,
        MD_DIVU   = 4'd5,
        MD_REM    = 4'd6,
        MD_REMU   = 4'd7,
        MD_MULW   = 4'd8,
        MD_DIVW   = 4'd9,
        MD_DIVUW  = 4'd10,
        MD_REMW   = 4'd11,
        MD_REMUW  = 4'd12
    } md_op_e;

    // ------------------------------------------------- memory access size
    typedef enum logic [1:0] {
        SZ_BYTE = 2'd0,
        SZ_HALF = 2'd1,
        SZ_WORD = 2'd2,
        SZ_DWRD = 2'd3
    } mem_size_e;

    // ----------------------------------------------- decode control bundle
    // Field order matters only for readability; the struct is packed for the
    // pipeline registers. `ctrl = '0` == {no write, ALU add, no memory, legal}.
    typedef struct packed {
        logic       illegal;     // unimplemented/reserved encoding -> core error strobe
        logic       rf_we;       // instruction has a destination register (rd may still be x0)
        wb_sel_e    wb_sel;
        alu_op_e    alu_op;
        logic       alu_w;       // 32-bit word op: truncate + sign-extend
        op_a_sel_e  alu_a;
        op_b_sel_e  alu_b;
        logic       is_branch;   // conditional branch (uses br_f3)
        logic       is_jump;     // unconditional transfer (jal / jalr / c.j / c.jr)
        logic       is_indirect; // jump target comes from a register (jalr family)
        logic [2:0] br_f3;       // branch compare select (RISC-V funct3)
        logic       is_load;
        logic       is_store;
        mem_size_e  mem_size;
        logic       mem_signed;  // sign-extend the loaded value
        logic       is_muldiv;
        md_op_e     md_op;
    } ctrl_t;

    // ------------------------------------------------------ error condition
    typedef enum logic [3:0] {
        ERR_NONE     = 4'd0,
        ERR_ILLEGAL  = 4'd1,  // unimplemented / reserved encoding
        ERR_MISALIGN = 4'd2   // data access a single aligned beat cannot serve
    } err_code_e;

    // ---------------------------------------------- commit-stage control
    // The WB stage needs four control bits, not the whole decode bundle: keeping
    // the commit stage lean is what makes the trace path (and its `-Wall`) simple.
    typedef struct packed {
        logic illegal;
        logic rf_we;
        logic is_load;
        logic is_store;
    } commit_ctrl_t;

    // ------------------------------------------------ memory-stage control
    // Everything the MEM stage and its load/store datapath actually consume.
    typedef struct packed {
        logic      illegal;
        logic      rf_we;        // drives the MEM -> EX bypass
        logic      is_load;
        logic      is_store;
        mem_size_e mem_size;
        logic      mem_signed;
    } mem_ctrl_t;

endpackage
`default_nettype wire
