`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_pkg
// Description: Frozen parameter pack + decode/writeback control types for eth_rv (RV64IMAFDC, RV-C).
// Details:     Single blessed configuration (C14 §2): XLEN = 64, one hart. As of
//              E2-RV2 increment 2 the MMU is Sv39-only (cor_mmu) and the F/D
//              floating-point extensions are implemented (cor_fpu), so `misa`
//              advertises I/M/A/F/D/C, and `wfi` plus the A extension (lr/sc/amo) are implemented
//              (E2-RV2 increment 3), and Zicntr with the identification/envcfg CSR
//              floor firmware needs for an S-mode handoff is in place (increment 4:
//              `cycle`/`time`/`instret` over `mcycle`/`mtime`/`minstret`,
//              `mcounteren`/`scounteren`/`mcountinhibit`, `mvendorid`/`marchid`/
//              `mimpid`/`mconfigptr`/`menvcfg`/`senvcfg`). The M-mode CSR + trap path
//              is the minimal set of C14 §3. Every
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
// Modified:    2026-09-12 - E2-RV2 increment 5 (S3): RESET_PC moves to the BootROM
//              base (0x1000); the payload entry is a ROM data word, not a constant
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §2 (frozen parameter pack),
//              §3 (micro-architecture), §4 (RVFI trace port) ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2, §5 (DDR-less boot:
//              BootROM reset vector + a0/a1 handoff)
// Notes:       Single blessed configuration (C14 §2): XLEN 64, one hart, RV64IMAFDC +
//              Zicsr/Zicntr — the extension set `misa` advertises. This package holds
//              only the CONFIGURATION and the decode/writeback control types; the
//              architectural behaviour lives in eth_rv_core and its unit modules.
//              RESET_PC is the BootROM base (see the comment on it below). An
//              unimplemented encoding or CSR number sets `ctrl_t.illegal` and raises
//              the error strobe — it NEVER retires silently (C14 §3).
package eth_rv_pkg;

    // ---------------------------------------------------------------- config
    localparam int unsigned XLEN     = 64;
    localparam int unsigned REG_ADDR = 5;
    localparam int unsigned REG_NUM  = 32;

    // Reset PC: the BootROM base (E2-RV2 increment 5, S3). The core executes the
    // M-mode stub at 0x1000 first — it sets a0 = mhartid and a1 = 0x8000_2000
    // (the DTB) and jumps to the payload entry word the harness patches — so the
    // core itself starts in a ROM, not in the DRAM socket, and the payload may be
    // loaded at any entry (see eth_rv_boot_rom / rtl/eth_rv/rom/boot_rom.S).
    localparam logic [63:0] RESET_PC = 64'h0000_0000_0000_1000;
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
    // The floating-point CSRs of the F extension. `fcsr` is a *view*: bits 7:5 are
    // `frm` (write mask 3'h7) and bits 4:0 are `fflags` (write mask 5'h1f), exactly
    // Spike's composite_csr_t over two independent sub-CSRs.
    localparam logic [11:0] CSR_FFLAGS    = 12'h001;
    localparam logic [11:0] CSR_FRM       = 12'h002;
    localparam logic [11:0] CSR_FCSR      = 12'h003;

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
    // ------------------------------- Zicntr + the identity/envcfg floor (E2-RV2 inc. 4)
    // The counters, their enables and the identification / environment-configuration
    // set. Every value and mask below is the pinned Spike's, measured with
    // `--isa=rv64imafdc_zicsr_zicntr` (commit 1e05ddac) BEFORE this RTL was
    // written; the probe table is in `local://rv10-counter-notes.md` and the
    // README's "Counters and the CSR floor" section. The RV32-only halves
    // (`mcycleh`/`minstreth`/`mstatush`/`menvcfgh`/`senvcfgh`) are deliberately
    // absent: on RV64 the golden model traps them, so implementing one would be a
    // divergence rather than a courtesy.
    localparam logic [11:0] CSR_MVENDORID     = 12'hf11;
    localparam logic [11:0] CSR_MARCHID       = 12'hf12;
    localparam logic [11:0] CSR_MIMPID        = 12'hf13;
    localparam logic [11:0] CSR_MCONFIGPTR    = 12'hf15;
    localparam logic [11:0] CSR_MENVCFG       = 12'h30a;
    localparam logic [11:0] CSR_SENVCFG       = 12'h10a;
    localparam logic [11:0] CSR_MCOUNTINHIBIT = 12'h320;
    localparam logic [11:0] CSR_MCYCLE        = 12'hb00;
    localparam logic [11:0] CSR_MINSTRET      = 12'hb02;
    localparam logic [11:0] CSR_CYCLE         = 12'hc00;
    localparam logic [11:0] CSR_TIME          = 12'hc01;
    localparam logic [11:0] CSR_INSTRET       = 12'hc02;

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
    localparam logic [63:0] MISA_VALUE    = 64'h8000_0000_0014_112d;
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
    // F/D (E2-RV2 increment 2): an FP instruction, an FP load/store or an FP move
    // sets `mstatus.FS` to Dirty; while FS is Off (its reset value) every one of
    // those, and every access to the three FP CSRs, is an ILLEGAL INSTRUCTION —
    // Spike's `require_fp` / float_csr_t::verify_permissions — never a silent no-op.
     localparam logic [63:0] MSTATUS_FS_OFF = 64'h0000_0000_0000_0000;
    // The write masks of `fflags` and `frm` (Spike's float_csr_t masks).
    localparam logic [4:0]  FFLAGS_MASK   = 5'h1f;
    localparam logic [2:0]  FRM_MASK      = 3'h7;
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
    // SEIP (bit 9) has a hardware source since E2-RV2 increment 6: the PLIC's S
    // context drives `seip_i`, and the bit is ORed with the software-writable
    // pending bit (Spike keeps the software bit in `mvip` and composes the read).
    localparam logic [63:0] MIP_SEIP      = 64'h0000_0000_0000_0200;
    localparam logic [63:0] MIP_SW_WMASK  = 64'h0000_0000_0000_0222;  // mip: SSIP|STIP|SEIP
    localparam logic [63:0] MIP_SIP_WMASK = 64'h0000_0000_0000_0002;  // sip: SSIP only
    localparam logic [63:0] MIE_WMASK     = 64'h0000_0000_0000_0aaa;  // SSIE MSIE STIE MTIE SEIE MEIE
    // 1..9, 12, 13, 15 and — since the golden ISA string enables Zicntr — bit 19:
    // Spike adds `1 << CAUSE_HARDWARE_ERROR_FAULT` to medeleg's write mask exactly
    // when Zicntr is on (csrs.cc `medeleg_csr_t::unlogged_write`). It is WARL
    // storage here: eth_rv raises no hardware-error fault.
    localparam logic [63:0] MEDELEG_WMASK = 64'h0000_0000_0008_b3fe;
    localparam logic [63:0] MIDELEG_WMASK = 64'h0000_0000_0000_0222;  // SSI, STI, SEI
    // mtvec/stvec keep MODE bit 0 and clear bit 1 (Spike's tvec_csr_t); mepc/sepc[0]
    // is read-only zero (IALIGN = 16).
    localparam logic [63:0] MEPC_MASK     = 64'hffff_ffff_ffff_fffe;
    localparam logic [63:0] MTVEC_MASK    = 64'hffff_ffff_ffff_fffd;
    // ------------------------------------------- the Zicntr floor's masks/values
    // `counteren_mask` in the pinned Spike is `Zicntr ? 0x7 : 0` (it adds
    // `Zihpm ? 0xffff_fff8 : 0`, and the golden ISA string has no Zihpm), so
    // mcounteren/scounteren are CY|TM|IR and mcountinhibit is the same mask minus
    // the timer bit (the inhibit register has no TM bit at all).
    localparam logic [63:0] MCOUNTEREN_WMASK    = 64'h0000_0000_0000_0007;
    localparam logic [63:0] SCOUNTEREN_WMASK    = 64'h0000_0000_0000_0007;
    localparam logic [63:0] MCOUNTINHIBIT_WMASK = 64'h0000_0000_0000_0005;
    // The user proxies are gated by the bit their own address names (C00/C01/C02 ->
    // bits 0/1/2 of mcounteren and scounteren, see `csr_counter_bit`), so only the
    // two inhibit bits mcountinhibit actually has need a name here.
    localparam int unsigned COUNTER_CY_BIT      = 0;   // mcycle, mcountinhibit.CY
    localparam int unsigned COUNTER_IR_BIT      = 2;   // minstret, mcountinhibit.IR
    // menvcfg/senvcfg are FIOM-only: Spike makes FIOM writable exactly when S-mode
    // and paging both exist, and the other bits belong to extensions this hart
    // does not have (Zicbom/Zicboz/Svpbmt/Sstc/…). Probe: write -1 reads 0x1.
    localparam logic [63:0] MENVCFG_WMASK       = 64'h0000_0000_0000_0001;
    localparam logic [63:0] SENVCFG_WMASK       = 64'h0000_0000_0000_0001;
    // The identification CSRs are read-only constants; `marchid` is the pinned
    // Spike's own id (5), not a guess — reading it is a comparable event.
    localparam logic [63:0] MVENDORID_VALUE     = 64'd0;
    localparam logic [63:0] MARCHID_VALUE       = 64'd5;
    localparam logic [63:0] MIMPID_VALUE        = 64'd0;
    localparam logic [63:0] MCONFIGPTR_VALUE    = 64'd0;
    // The counters start at the golden model's boot-ROM count, exactly like
    // `eth_rv_clint`'s STEP_PRELOAD: Spike executes five boot-ROM instructions
    // before the ELF entry and its mcycle/minstret count them, so a corpus program
    // that reads `cycle`/`instret` sees the same absolute value on both sides.
    localparam logic [63:0] COUNTER_PRELOAD     = 64'd5;

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

    // The 29 machine performance counters (0xB03..0xB1F) exist and read zero, with
    // every write dropped: Spike instantiates each as a `const_csr_t(0)`
    // (csr_init.cc:88-105). Their *user* proxies (`hpmcounter3`, 0xC03..) are added
    // only `add_const_ext_csr(EXT_ZIHPM, …)`, and the golden ISA string does not
    // enable Zihpm — so those stay illegal, a distinction the corpus pins.
    // Stated as arithmetic ranges rather than 29 `case` items: the yosys frontend
    // the formal flow reads with handles the comparisons, and the ranges are the
    // architectural definition anyway.
    function automatic logic csr_is_mhpmcounter(input logic [11:0] addr);
        csr_is_mhpmcounter = (addr >= 12'hb03) && (addr <= 12'hb1f);
    endfunction

    // `mhpmevent3..31` (0x323..0x33F): `mevent_csr_t` with a write mask of 0
    // (Sscofpmf and Smcntrpmf are both absent), so a write is legal and drops.
    function automatic logic csr_is_mhpmevent(input logic [11:0] addr);
        csr_is_mhpmevent = (addr >= 12'h323) && (addr <= 12'h33f);
    endfunction

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
            // E2-RV2 increment 4: the counters, their enables, the inhibit register
            // and the identification/envcfg floor.
            eth_rv_pkg::CSR_MVENDORID, eth_rv_pkg::CSR_MARCHID, eth_rv_pkg::CSR_MIMPID,
            eth_rv_pkg::CSR_MCONFIGPTR, eth_rv_pkg::CSR_MENVCFG,
            eth_rv_pkg::CSR_SENVCFG, eth_rv_pkg::CSR_MCOUNTINHIBIT,
            eth_rv_pkg::CSR_MCYCLE, eth_rv_pkg::CSR_MINSTRET,
            eth_rv_pkg::CSR_CYCLE, eth_rv_pkg::CSR_TIME, eth_rv_pkg::CSR_INSTRET,
            eth_rv_pkg::CSR_FFLAGS, eth_rv_pkg::CSR_FRM, eth_rv_pkg::CSR_FCSR,
            eth_rv_pkg::CSR_SATP,
            eth_rv_pkg::CSR_SSTATUS, eth_rv_pkg::CSR_SIE, eth_rv_pkg::CSR_STVEC,
            eth_rv_pkg::CSR_SCOUNTEREN, eth_rv_pkg::CSR_SSCRATCH, eth_rv_pkg::CSR_SEPC,
            eth_rv_pkg::CSR_SCAUSE, eth_rv_pkg::CSR_STVAL, eth_rv_pkg::CSR_SIP:
                csr_implemented = 1'b1;
            // The 29 performance-counter pairs are implemented as zero-valued,
            // write-dropping registers rather than listed one by one: see the two
            // range helpers below, which are the architectural definition anyway.
            default: csr_implemented = eth_rv_pkg::csr_is_mhpmcounter(addr)
                                       || eth_rv_pkg::csr_is_mhpmevent(addr);
        endcase
    endfunction
    // The three user counter proxies: whatever privilege they carry, the golden
    // model gates them on `mcounteren` (from below M-mode) and, from U-mode, on
    // `scounteren` as well (counter_proxy_csr_t::verify_permissions).
    function automatic logic csr_is_counter_proxy(input logic [11:0] addr);
        csr_is_counter_proxy = (addr == eth_rv_pkg::CSR_CYCLE)
                               || (addr == eth_rv_pkg::CSR_TIME)
                               || (addr == eth_rv_pkg::CSR_INSTRET);
    endfunction

    // Which `mcounteren`/`scounteren`/`mcountinhibit` bit a counter proxy is gated
    // by: the proxy's low address bits are the counter index (C00/C01/C02 → CY, TM,
    // IR), exactly the bit `counter_proxy_csr_t::myenable` shifts out. The argument
    // is those two bits rather than the whole address so the function reads exactly
    // the bits it uses (a 12-bit argument would leave ten of them unused, which
    // `-Wall` rejects).
    function automatic logic [2:0] csr_counter_bit(input logic [1:0] idx);
        csr_counter_bit = 3'd1 << idx;
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

    // -------------------------------------------------- float ops
    // One op-select for the whole FPU (cor_fpu). Every encoding the decoder accepts
    // carries exactly one of these; FP_NONE is the "not an FP op" value and is what
    // a zeroed ctrl_t carries.
    typedef enum logic [5:0] {
        FP_NONE     = 6'd0,
        FP_ADD      = 6'd1,   // fadd.s/.d
        FP_SUB      = 6'd2,   // fsub.s/.d
        FP_MUL      = 6'd3,   // fmul.s/.d
        FP_DIV      = 6'd4,   // fdiv.s/.d
        FP_SQRT     = 6'd5,   // fsqrt.s/.d
        FP_MADD     = 6'd6,   // fmadd.s/.d :   rs1 * rs2 + rs3
        FP_MSUB     = 6'd7,   // fmsub.s/.d :   rs1 * rs2 - rs3
        FP_NMADD    = 6'd8,   // fnmadd.s/.d: -(rs1 * rs2) - rs3
        FP_NMSUB    = 6'd9,   // fnmsub.s/.d: -(rs1 * rs2) + rs3
        FP_SGNJ     = 6'd10,  // fsgnj.s/.d
        FP_SGNJN    = 6'd11,  // fsgnjn.s/.d
        FP_SGNJX    = 6'd12,  // fsgnjx.s/.d
        FP_MIN      = 6'd13,  // fmin.s/.d
        FP_MAX      = 6'd14,  // fmax.s/.d
        FP_EQ       = 6'd15,  // feq.s/.d
        FP_LT       = 6'd16,  // flt.s/.d
        FP_LE       = 6'd17,  // fle.s/.d
        FP_CLASS    = 6'd18,  // fclass.s/.d
        FP_MV_X_FP  = 6'd19,  // fmv.x.w / fmv.x.d : FP bits -> integer register
        FP_MV_FP_X  = 6'd20,  // fmv.w.x / fmv.d.x : integer bits -> FP (NaN-boxed)
        FP_CVT_FP_I = 6'd21,  // fcvt.{w,wu,l,lu}.{s,d}
        FP_CVT_I_FP = 6'd22,  // fcvt.{s,d}.{w,wu,l,lu}
        FP_CVT_FP_FP = 6'd23  // fcvt.s.d / fcvt.d.s
    } fp_op_e;

    // The architectural rounding modes of the F extension. The FPU only ever sees a
    // VALIDATED value (0..4): the core resolves `rm = 3'b111` against `frm` and
    // raises an illegal instruction for a resolved mode of 5..7, exactly Spike's
    // `validate_rm` (which is applied only to the op classes that carry an rm field).
    typedef enum logic [2:0] {
        RM_RNE = 3'd0,
        RM_RTZ = 3'd1,
        RM_RDN = 3'd2,
        RM_RUP = 3'd3,
        RM_RMM = 3'd4
    } fp_rm_e;

    // True when `op` is one of the fused multiply-add forms: those are the only
    // encodings that name a THIRD source register (rs3), and it is always an FP one.
    function automatic logic fp_op_is_fma(input fp_op_e op);
        unique case (op)
            eth_rv_pkg::FP_MADD, eth_rv_pkg::FP_MSUB,
            eth_rv_pkg::FP_NMADD, eth_rv_pkg::FP_NMSUB:
                fp_op_is_fma = 1'b1;
            default:
                fp_op_is_fma = 1'b0;
        endcase
    endfunction

    // True when `addr` is one of the three F-extension CSRs that `fcsr` is a view
    // of. Accessing any of them while `mstatus.FS` is Off is an illegal
    // instruction (Spike's float_csr_t::verify_permissions).
    function automatic logic csr_is_fp(input logic [11:0] addr);
        unique case (addr)
            eth_rv_pkg::CSR_FFLAGS, eth_rv_pkg::CSR_FRM, eth_rv_pkg::CSR_FCSR:
                csr_is_fp = 1'b1;
            default:
                csr_is_fp = 1'b0;
        endcase
    endfunction

    // True when `op` reads the rounding mode from its encoding / `frm`. The compare,
    // min/max, sign-injection, classify and move forms do not — their rm field is
    // part of funct3 — and Spike does not validate rm for them.
    function automatic logic fp_op_uses_rm(input fp_op_e op);
        unique case (op)
            eth_rv_pkg::FP_ADD, eth_rv_pkg::FP_SUB, eth_rv_pkg::FP_MUL,
            eth_rv_pkg::FP_DIV, eth_rv_pkg::FP_SQRT, eth_rv_pkg::FP_MADD,
            eth_rv_pkg::FP_MSUB, eth_rv_pkg::FP_NMADD, eth_rv_pkg::FP_NMSUB,
            eth_rv_pkg::FP_CVT_FP_I, eth_rv_pkg::FP_CVT_I_FP,
            eth_rv_pkg::FP_CVT_FP_FP:
                fp_op_uses_rm = 1'b1;
            default:
                fp_op_uses_rm = 1'b0;
        endcase
    endfunction

    // -------------------------------------------------- A extension (RV64A)
    // The nine AMO read-modify-write forms of `amo_op_e`. `lr.w/d` and `sc.w/d`
    // are not here: they have no operation — LR is a load that also arms the
    // reservation and SC is a conditional store — so the decoder marks them with
    // their own `is_lr`/`is_sc` bits and this select is only inspected when
    // `is_amo` is set.
    typedef enum logic [3:0] {
        AMO_ADD  = 4'd0,   // amoadd.{w,d}
        AMO_SWAP = 4'd1,   // amoswap.{w,d}
        AMO_XOR  = 4'd2,   // amoxor.{w,d}
        AMO_AND  = 4'd3,   // amoand.{w,d}
        AMO_OR   = 4'd4,   // amoor.{w,d}
        AMO_MIN  = 4'd5,   // amomin.{w,d}   signed
        AMO_MAX  = 4'd6,   // amomax.{w,d}   signed
        AMO_MINU = 4'd7,   // amominu.{w,d}  unsigned
        AMO_MAXU = 4'd8    // amomaxu.{w,d}  unsigned
    } amo_op_e;

    // The value an AMO writes back to memory: `op(old, rs2)` at the access width.
    //
    // `word` selects the `.w` form: Spike instantiates its `mmu.amo<uint32_t>`
    // for those, so the operands are the LOW 32 BITS of both registers (the old
    // value as loaded, rs2 as read) and the result is that 32-bit value
    // zero-extended — a `.w` amoadd that carries out of bit 31 wraps there, which
    // is exactly `uint32_t` arithmetic, not the 64-bit sum truncated afterwards.
    // `old_v` is the loaded memory operand (its low bits are the memory word),
    // `src_v` is rs2.
    function automatic logic [63:0] amo_result(input amo_op_e   op,
                                              input logic [63:0] old_v,
                                              input logic [63:0] src_v,
                                              input logic        word);
        logic [63:0] o;
        logic [63:0] s;
        logic [63:0] so;
        logic [63:0] ss;
        logic [63:0] res;
        o  = word ? {32'd0, old_v[31:0]} : old_v;
        s  = word ? {32'd0, src_v[31:0]} : src_v;
        // the compare operands of the signed min/max forms: Spike's
        // `std::min(int32_t(lhs), int32_t(RS2))` sign-extends the truncated word
        so = word ? {{32{old_v[31]}}, old_v[31:0]} : old_v;
        ss = word ? {{32{src_v[31]}}, src_v[31:0]} : src_v;
        unique case (op)
            eth_rv_pkg::AMO_ADD:  res = o + s;                        // wraps at the width
            eth_rv_pkg::AMO_SWAP: res = s;
            eth_rv_pkg::AMO_XOR:  res = o ^ s;
            eth_rv_pkg::AMO_AND:  res = o & s;
            eth_rv_pkg::AMO_OR:   res = o | s;
            eth_rv_pkg::AMO_MIN:  res = ($signed(so) < $signed(ss)) ? o : s;
            eth_rv_pkg::AMO_MAX:  res = ($signed(so) > $signed(ss)) ? o : s;
            eth_rv_pkg::AMO_MINU: res = (o < s) ? o : s;
            eth_rv_pkg::AMO_MAXU: res = (o > s) ? o : s;
            default:              res = o;                            // unreachable: !is_amo
        endcase
        amo_result = word ? {32'd0, res[31:0]} : res;
    endfunction

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
        // ---- floating point (F/D, E2-RV2 increment 2) ----
        logic       is_fp;       // any FP instruction (FS gate + FS -> Dirty)
        logic       fp_we;       // the destination register is a FLOAT register
        fp_op_e     fp_op;
        logic       fp_single;   // .s form: the operand/result format is binary32
        logic       fp_src_single; // FP->FP cvt: the SOURCE format is binary32
        logic       fp_rm_used;  // this encoding carries an rm field
        logic [2:0] fp_rm;       // the encoding's rm field (3'b111 = dynamic)
        logic [1:0] fp_iw;       // cvt integer form: 0 = w, 1 = wu, 2 = l, 3 = lu
        logic       fp_rs1_fp;   // rs1 is read from the FP register file
        logic       fp_rs2_fp;   // rs2 is read from the FP register file
        // ---- A extension (RV64A, E2-RV2 increment 3) ----
        // `is_load`/`is_store` still say which DIRECTION the instruction's memory
        // access is, because that is what the misalignment cause (4 vs 6), the
        // D-port write-enable and the trace's mask class each key off:
        //   * lr.w/d  -> is_load  (a read; a misaligned LR is cause 4)
        //   * sc.w/d  -> is_store (a conditional write; a misaligned SC is cause 6)
        //   * amo.*   -> is_store (a read-modify-WRITE; a misaligned AMO is cause 6)
        // An AMO therefore never sets both bits, which keeps P3b's "a record is
        // exactly one direction" invariant true.
        logic       is_amo;      // one of the nine amo.* read-modify-write forms
        logic       is_lr;       // lr.w / lr.d: load + arm the reservation
        logic       is_sc;       // sc.w / sc.d: conditional store (rd = 0/1)
        amo_op_e    amo_op;      // which amo.* operation (read only when is_amo)
        logic       rd_late;     // rd becomes available only at the END of MEM
                                 // (any load, and every A-extension instruction):
                                 // the consumer hazard rule and the MEM->EX
                                 // bypass are keyed off this, not off is_load
        // ---- WFI ----
        logic       is_wfi;      // wfi: commit, then hold the hart until mip & mie
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
        logic fp_we;      // the destination is an FP register (trace record class)
        logic mem_ok;     // the D-port access of this load/store really happened:
                          // a failing `sc` commits with no memory traffic at all,
                          // so the record must carry no `mem` field for it
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
        logic      fp_we;        // the load destination is an FP register
        logic      is_amo;       // amo.*: MEM issues a read beat THEN a write beat
        logic      is_lr;        // lr.w/d: arm the reservation when the beat lands
        logic      is_sc;        // sc.w/d: consult/clear the reservation
        amo_op_e   amo_op;       // which amo.* operation the write beat stores
        logic      rd_late;      // see ctrl_t: MEM->EX bypass of a late rd
        logic      is_wfi;       // wfi: MEM holds the instruction until mip & mie
        // Which machine counters this instruction increments when it retires
        // (E2-RV2 increment 4): bit 0 = mcycle, bit 1 = minstret. The decision is
        // made in EX, where `mcountinhibit` still holds the value the instruction
        // itself was gated by — a `csrw mcountinhibit` must be counted under the
        // OLD inhibit value, exactly as the golden model samples it at the start
        // of the quantum it ends. A counter the instruction writes is marked 0
        // here (the write lands in EX) and a younger reader adds this pending bit
        // to its own value.
        logic [1:0] counter_inc;
    } mem_ctrl_t;

endpackage
`default_nettype wire
