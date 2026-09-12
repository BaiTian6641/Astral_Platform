`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_pkg
// Description: Frozen parameter pack + decode/writeback control types for eth_rv (RV64IMC, RV-B).
// Details:     Single blessed configuration (C14 §2): XLEN = 64, one hart, no MMU / FPU;
//              the M-mode CSR + trap path is the minimal set of C14 §3. Every
//              pipeline-control field travels as one packed struct (`ctrl_t`) so the
//              IF->ID->EX->MEM->WB registers stay flat vectors and the core lints
//              clean under `-Wall`.
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
// Notes:       RV-B v0 scope: RV64I + M + C integer subset, plus the M-mode CSR/trap
//              path (`mstatus/misa/mie/mip/mtvec/mepc/mcause/mtval/mscratch/mhartid`,
//              ecall/ebreak/illegal/misaligned). An unimplemented encoding or CSR
//              number sets `ctrl_t.illegal` and raises the error strobe — it NEVER
//              retires silently (C14 §3).
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
        WB_LINK = 2'd2,  // pc + 2 (compressed) or pc + 4
        WB_CSR  = 2'd3   // the old value of a CSR (SYSTEM CSRRS/CSRRW/…)
    } wb_sel_e;

    // ------------------------------------------------------------ CSR access
    // CSR op select, encoded exactly like funct3[1:0] of the SYSTEM encodings:
    // 1 = read/write, 2 = read/set, 3 = read/clear (funct3 0 is not a CSR op).
    typedef enum logic [1:0] {
        CSR_RW = 2'd1,
        CSR_RS = 2'd2,
        CSR_RC = 2'd3
    } csr_op_e;

    // M-mode CSR addresses of the RV-B minimal set (C14 §3).
    localparam logic [11:0] CSR_MSTATUS  = 12'h300;
    localparam logic [11:0] CSR_MISA     = 12'h301;
    localparam logic [11:0] CSR_MIE      = 12'h304;
    localparam logic [11:0] CSR_MTVEC    = 12'h305;
    localparam logic [11:0] CSR_MSCRATCH = 12'h340;
    localparam logic [11:0] CSR_MEPC     = 12'h341;
    localparam logic [11:0] CSR_MCAUSE   = 12'h342;
    localparam logic [11:0] CSR_MTVAL    = 12'h343;
    localparam logic [11:0] CSR_MIP      = 12'h344;
    localparam logic [11:0] CSR_MHARTID  = 12'hf14;
    localparam logic [11:0] CSR_MEDELEG  = 12'h302;
    localparam logic [11:0] CSR_MIDELEG  = 12'h303;
    localparam logic [11:0] CSR_MCOUNTEREN = 12'h306;

    // S-mode CSR set (C14 §3; E2-RV1 increment 6). The S-mode trap CSRs are
    // registers of their own — unlike mstatus/sstatus, they are not a view of a
    // machine register. `satp` is implemented as of E2-RV2 increment 1 (Sv39
    // only: see cor_mmu.sv and verif/eth_rv/README.md).
    localparam logic [11:0] CSR_SATP       = 12'h180;
    localparam logic [11:0] CSR_SSTATUS    = 12'h100;
    localparam logic [11:0] CSR_SIE        = 12'h104;
    localparam logic [11:0] CSR_STVEC      = 12'h105;
    localparam logic [11:0] CSR_SCOUNTEREN = 12'h106;
    localparam logic [11:0] CSR_SSCRATCH   = 12'h140;
    localparam logic [11:0] CSR_SEPC       = 12'h141;
    localparam logic [11:0] CSR_SCAUSE     = 12'h142;
    localparam logic [11:0] CSR_STVAL      = 12'h143;
    localparam logic [11:0] CSR_SIP        = 12'h144;

    // ------------------------------------------------------- privilege levels
    // The hart supports U, S and M: `misa` advertises S and U, and the golden
    // model's `--isa=rv64imc` enables both. PRV_M = 2'b11 is the architectural
    // encoding; 2'b10 (HS) never occurs without the H extension.
    typedef enum logic [1:0] {
        PRV_U = 2'd0,
        PRV_S = 2'd1,
        PRV_M = 2'd3
    } priv_e;

    // Read-only CSR values. `misa` advertises exactly what this hart implements
    // (MXL=64, I, M, C, S, U) and the mstatus XL fields are the RV64 values, so a
    // program that reads them sees the same bit pattern as the Spike golden model
    // (see verif/eth_rv/README.md). `mip` is a real register as of increment 6.
    localparam logic [63:0] MISA_VALUE    = 64'h8000_0000_0014_1104;
    localparam logic [63:0] MSTATUS_XL    = 64'h0000_000a_0000_0000;  // SXL = UXL = 2
    localparam logic [63:0] MHARTID_VALUE = 64'd0;

    // Write masks of the writable CSRs, each one exactly the golden model's WARL
    // mask — the DiffTest compares CSR round trips, so a mask that differs by one
    // bit is a visible failure, not a silent one.
    //
    // mstatus: with S/U implemented and the golden model carrying an MMU, Spike's
    // writable set is SIE|SPIE|SPP|FS|MPP|MPIE|MIE|MPRV|SUM|MXR|TVM|TW|TSR. eth_rv
    // has no MMU and implements none of the MMU/TW/TSR *behaviour*, but the bits are
    // WARL storage here too: a corpus round trip through mstatus must reproduce the
    // golden value bit for bit. `mstatus.SD` is derived from FS (Spike's
    // adjust_sd()), and sstatus is the S-mode view: its write mask is the S-owned
    // subset, its read mask adds UXL (read-only 2) and SD.
    localparam logic [63:0] MSTATUS_WMASK = 64'h0000_0000_007e_79aa;
    localparam logic [63:0] SSTATUS_WMASK = 64'h0000_0000_000c_6122;  // SIE|SPIE|SPP|FS|SUM|MXR
    localparam logic [63:0] SSTATUS_RMASK = 64'h8000_0002_000c_6122;  // | UXL | SD
    localparam logic [63:0] MSTATUS_FS    = 64'h0000_0000_0000_6000;  // FS = 2'b11 -> SD
    localparam logic [63:0] MSTATUS_SD    = 64'h8000_0000_0000_0000;
    localparam logic [63:0] MSTATUS_MIE   = 64'h0000_0000_0000_0008;
    localparam logic [63:0] MSTATUS_MPIE  = 64'h0000_0000_0000_0080;
    localparam logic [63:0] MSTATUS_SIE   = 64'h0000_0000_0000_0002;
    localparam logic [63:0] MSTATUS_TVM   = 64'h0000_0000_0010_0000;
    localparam logic [63:0] MSTATUS_SPIE  = 64'h0000_0000_0000_0020;
    localparam logic [63:0] MSTATUS_SPP   = 64'h0000_0000_0000_0100;
    localparam logic [63:0] MSTATUS_MPP   = 64'h0000_0000_0000_1800;
    localparam logic [63:0] MSTATUS_MPRV  = 64'h0000_0000_0002_0000;
    // Interrupt pending/enable/delegation masks. Spike (rv64imc, no AIA) has six
    // interrupt sources: SSI(1), MSI(3), STI(5), MTI(7), SEI(9), MEI(11). The
    // machine bits are hardware-driven; the supervisor bits are software-writable
    // through `mip`, and `sip` can write only SSIP (Spike's generic accessor
    // ip_write_mask = MIP_SSIP | MIP_LCOFIP). mideleg is writable for the three
    // supervisor bits; medeleg for causes 1..9 plus the three page faults Spike's
    // MMU defines (12/13/15), which are WARL storage here because eth_rv never
    // raises them.
    localparam logic [63:0] MIP_MSIP      = 64'h0000_0000_0000_0008;
    localparam logic [63:0] MIP_MTIP      = 64'h0000_0000_0000_0080;
    localparam logic [63:0] MIP_MEIP      = 64'h0000_0000_0000_0800;
    localparam logic [63:0] MIP_SW_WMASK  = 64'h0000_0000_0000_0222;  // mip: SSIP|STIP|SEIP
    localparam logic [63:0] MIP_SIP_WMASK = 64'h0000_0000_0000_0002;  // sip: SSIP only
    localparam logic [63:0] MIE_WMASK     = 64'h0000_0000_0000_0aaa;  // SSIE MSIE STIE MTIE SEIE MEIE
    localparam logic [63:0] MEDELEG_WMASK = 64'h0000_0000_0000_b3fe;  // 1..9, 12, 13, 15
    localparam logic [63:0] MIDELEG_WMASK = 64'h0000_0000_0000_0222;  // SSI, STI, SEI
    // mtvec/stvec keep MODE bit 0 and clear bit 1 (Spike's tvec_csr_t); mepc/sepc[0]
    // is read-only zero (IALIGN = 16).
    localparam logic [63:0] MEPC_MASK     = 64'hffff_ffff_ffff_fffe;
    localparam logic [63:0] MTVEC_MASK    = 64'hffff_ffff_ffff_fffd;

    // ------------------------------------------------------ exception causes
    // The architectural `mcause` values of the exceptions RV-B can raise
    // (interrupts are not implemented yet, so bit 63 is always clear). The
    // codes double as the core's error-strobe codes: `err_o` is the valid
    // strobe, so CAUSE_INSN_MISALIGN = 0 is distinguishable from "no trap".
    //
    // The three ACCESS faults (1/5/7) are the port error responses: a memory
    // port answers an access the platform cannot serve (no device claims the
    // address, a device rejects it, or the bus returns DECERR/SLVERR) by
    // raising `*_err_i` on the cycle it accepts the beat, and the core turns
    // that into the architectural trap Spike raises for the same access.
    // `mtval` is always the access address, exactly like Spike's
    // `trap_{instruction,load,store}_access_fault(virt, addr, 0, 0)`.
    typedef enum logic [3:0] {
        CAUSE_INSN_MISALIGN  = 4'd0,   // instruction address misaligned
        CAUSE_INSN_ACCESS    = 4'd1,   // instruction access fault (fetch of an unmapped address)
        CAUSE_ILLEGAL        = 4'd2,   // illegal / unimplemented instruction
        CAUSE_BREAKPOINT     = 4'd3,   // ebreak
        CAUSE_LOAD_MISALIGN  = 4'd4,   // load address misaligned
        CAUSE_LOAD_ACCESS    = 4'd5,   // load access fault (unmapped / rejected / DECERR)
        CAUSE_STORE_MISALIGN = 4'd6,   // store address misaligned
        CAUSE_STORE_ACCESS   = 4'd7,   // store access fault (unmapped / rejected / DECERR)
        CAUSE_ECALL_U        = 4'd8,   // ecall from U-mode
        CAUSE_ECALL_S        = 4'd9,   // ecall from S-mode
        CAUSE_ECALL_M        = 4'd11,  // ecall from M-mode
        // The three PAGE faults (E2-RV2 increment 1). They are what the Sv39
        // walk raises: `mtval`/`stval` is the faulting VIRTUAL address (never
        // the physical one), exactly like Spike's
        // `trap_{instruction,load,store}_page_fault(virt, addr, 0, 0)`. A PTE
        // read the platform answers with an error is the *access* fault of the
        // access type instead (Spike's pte_load -> throw_access_exception).
        CAUSE_INSN_PAGE      = 4'd12,  // instruction page fault
        CAUSE_LOAD_PAGE      = 4'd13,  // load page fault
        CAUSE_STORE_PAGE     = 4'd15   // store/AMO page fault
    } trap_cause_e;

    // ---------------------------------------------- translation access type
    // What the Sv39 walk is for. The three values map to the three page-fault
    // causes (12/13/15) and to the three access-fault causes (1/5/7) a failed
    // PTE read raises, so cor_mmu carries one enum instead of two `case`s.
    typedef enum logic [1:0] {
        ACC_FETCH = 2'd0,
        ACC_LOAD  = 2'd1,
        ACC_STORE = 2'd2
    } acc_e;

    // The architectural cause a page fault of this access type carries.
    function automatic logic [3:0] page_fault_cause(input acc_e acc);
        unique case (acc)
            eth_rv_pkg::ACC_FETCH: page_fault_cause = eth_rv_pkg::CAUSE_INSN_PAGE;
            eth_rv_pkg::ACC_LOAD:  page_fault_cause = eth_rv_pkg::CAUSE_LOAD_PAGE;
            default:               page_fault_cause = eth_rv_pkg::CAUSE_STORE_PAGE;
        endcase
    endfunction

    // ... and the access fault a PTE read that the platform cannot serve raises.
    function automatic logic [3:0] access_fault_cause(input acc_e acc);
        unique case (acc)
            eth_rv_pkg::ACC_FETCH: access_fault_cause = eth_rv_pkg::CAUSE_INSN_ACCESS;
            eth_rv_pkg::ACC_LOAD:  access_fault_cause = eth_rv_pkg::CAUSE_LOAD_ACCESS;
            default:               access_fault_cause = eth_rv_pkg::CAUSE_STORE_ACCESS;
        endcase
    endfunction

    // Interrupt cause codes (the low bits of `mcause`/`scause` when bit 63 is
    // set). The names are the architectural ones; the values are Spike's IRQ_*
    // numbering, and the priority order below is Spike's
    // select_an_interrupt_with_default_priority().
    localparam logic [3:0] IRQ_SSI = 4'd1;
    localparam logic [3:0] IRQ_MSI = 4'd3;
    localparam logic [3:0] IRQ_STI = 4'd5;
    localparam logic [3:0] IRQ_MTI = 4'd7;
    localparam logic [3:0] IRQ_SEI = 4'd9;
    localparam logic [3:0] IRQ_MEI = 4'd11;

    // The architectural cause word: bit 63 marks an interrupt, exactly as both
    // mcause and scause are written on trap entry.
    function automatic logic [63:0] cause_word(input logic is_irq, input logic [3:0] code);
        cause_word = {is_irq, 59'd0, code};
    endfunction

    // True when `addr` names a CSR this core implements. Anything else is an
    // illegal instruction (C14 §3: unimplemented CSR access NEVER succeeds
    // silently) — matching Spike, which rejects e.g. `mstatush` on RV64.
    // (Members of the package are spelled `eth_rv_pkg::NAME` on purpose: the
    // yosys frontend the formal flow reads with does not resolve a bare
    // package-local name inside a function body, and the qualified form is the
    // same identifier in simulators.)
    function automatic logic csr_implemented(input logic [11:0] addr);
        unique case (addr)
            eth_rv_pkg::CSR_MSTATUS, eth_rv_pkg::CSR_MISA, eth_rv_pkg::CSR_MIE,
            eth_rv_pkg::CSR_MTVEC, eth_rv_pkg::CSR_MSCRATCH, eth_rv_pkg::CSR_MEPC,
            eth_rv_pkg::CSR_MCAUSE, eth_rv_pkg::CSR_MTVAL, eth_rv_pkg::CSR_MIP,
            eth_rv_pkg::CSR_MHARTID, eth_rv_pkg::CSR_MEDELEG, eth_rv_pkg::CSR_MIDELEG,
            eth_rv_pkg::CSR_MCOUNTEREN,
            eth_rv_pkg::CSR_SATP,
            eth_rv_pkg::CSR_SSTATUS, eth_rv_pkg::CSR_SIE, eth_rv_pkg::CSR_STVEC,
            eth_rv_pkg::CSR_SCOUNTEREN, eth_rv_pkg::CSR_SSCRATCH, eth_rv_pkg::CSR_SEPC,
            eth_rv_pkg::CSR_SCAUSE, eth_rv_pkg::CSR_STVAL, eth_rv_pkg::CSR_SIP:
                csr_implemented = 1'b1;
            default: csr_implemented = 1'b0;
        endcase
    endfunction

    // The privilege level a CSR belongs to is address bits [9:8] (00 = U, 01 =
    // S/HS, 10 = H, 11 = M) and a read-only CSR is one whose [11:10] field is 11
    // — the decode Spike's csr_t::verify_permissions() uses. eth_rv_core applies
    // both checks directly on the decoded address.

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
        // ---- SYSTEM (C14 §3): CSR access, ecall/ebreak, mret ----
        logic       is_csr;      // csrrw/csrrs/csrrc + the immediate forms
        logic       csr_imm;     // source is the 5-bit uimm (insn[19:15]), not rs1
        csr_op_e    csr_op;
        logic [11:0] csr_addr;
        logic       is_ecall;
        logic       is_ebreak;
        logic       is_mret;
        logic       is_sret;     // sret (S-mode return; legal in M when TSR = 0)
        logic       is_sfence;   // sfence.vma (E2-RV2 increment 1)
    } ctrl_t;

    // The error strobe's code type is `trap_cause_e`: the core no longer halts on
    // an exception, it takes the trap, so the strobe reports the architectural
    // `mcause` value (see the type's own comment).

    // The stored value in the trace/RVFI convention: the low `size` bytes of the
    // store data, unshifted — exactly what Spike prints for a store's `mem` field
    // (`sb` of 0x1234 logs 0x34), so the harness can compare it byte for byte.
    function automatic logic [63:0] store_wdata(input logic [63:0] data,
                                                input mem_size_e size);
        unique case (size)
            eth_rv_pkg::SZ_BYTE: store_wdata = {56'd0, data[7:0]};
            eth_rv_pkg::SZ_HALF: store_wdata = {48'd0, data[15:0]};
            eth_rv_pkg::SZ_WORD: store_wdata = {32'd0, data[31:0]};
            default:             store_wdata = data;
        endcase
    endfunction

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
