`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_core
// Description: eth_rv RV64IMC in-order 5-stage core with a first-class RVFI commit-trace port.
// Details:     Pipeline: IF -> ID -> EX -> MEM -> WB (C14 §3), single issue, in
//              order, no MMU / FPU; the RV-B M-mode CSR set and the trap path of
//              C14 §3 are implemented (see "CSR / trap path" below).
//
//              * IF   fetches through a held-until-ready instruction port and
//                     decodes combinationally, so the static predictor and the
//                     ID stage share one decoder instance.
//              * ID   reads the register file (no internal bypass — every hazard
//                     is forwarded in EX, which keeps forwarding bugs visible).
//              * EX   ALU (cor_alu), M extension (cor_muldiv, stalled until its
//                     result strobe), branch resolution and the redirect.
//                     Forwarding is EX/MEM -> EX and WB -> EX, MEM ahead of WB
//                     (the younger producer wins). A load-use hazard inserts one
//                     bubble; the consumer then takes the load from WB.
//              * MEM  data port access; waits on `dmem_ready_i` (arbitrary
//                     latency, the request is held until accepted).
//              * WB   register write + ONE RVFI trace record per retired
//                     instruction, in commit order.
//
//              Trace contract (C14 §4/§5, first-class interface):
//                `rvfi_valid_o` is high for exactly one cycle per retired
//                instruction and stays low for bubbles; `rvfi_order_o` counts
//                retirements 1..N and is the `cycle` field of the harness trace
//                format. Nothing commits from the WB stage that was not executed
//                to completion in EX, so a squashed (mispredicted) instruction
//                can never appear in the stream. `rvfi_rd_we_o` is low for
//                writes to x0, for stores/branches/fences, matching the
//                harness's "no architectural write" rule.
//                A TRAPPING instruction never reaches WB, so it produces no
//                trace record at all — which is also what Spike's
//                `--log-commits` does (it logs the exception instead of a commit
//                line), and therefore what the golden stream expects. The
//                `rvfi_mem_*` group reports the D-port access in Spike's
//                convention: `rvfi_mem_addr_o` is the exact (unaligned) address,
//                `rvfi_mem_wdata_o` the stored value truncated to the access
//                size (unshifted) and the masks are the byte lanes of the
//                8-byte-aligned window at `rvfi_mem_addr_o & ~7` (RVFI), so the
//                harness can compare address + store data against Spike and
//                cross-check the masks' direction against it.
//
//                Static prediction (C14 §3): backward branches and direct jumps
//                are predicted taken; JALR/C.JR/C.JALR fall through. A misprediction
//                is a redirect from EX that flushes IF/ID, and the redirect is
//                derived from "actual next PC != the next PC carried down the
//                pipe", so it cannot be forgotten for one instruction class.
//
//              CSR / trap path (C14 §3, RV-B minimal set):
//                * CSRs: mstatus/misa/mie/mip/mtvec/mepc/mcause/mtval/mscratch/
//                  mhartid. The read-only values (`misa`, `mip`, `mhartid`, the
//                  mstatus XL fields) are chosen to match the Spike golden model
//                  bit for bit; `mip` has no interrupt source yet (no CLINT), so
//                  it reads zero. `mstatus`/`mie`/`mtvec`/`mepc` implement the
//                  architectural write masks (WARL), and an access to any CSR
//                  number outside the set is an illegal instruction.
//                * Traps: illegal instruction, ebreak, ecall, and load/store
//                  address misaligned. The trapping instruction does NOT commit;
//                  `mepc`/`mcause`/`mtval` are written, `mstatus.MPIE <= MIE`,
//                  `mstatus.MIE <= 0`, `mstatus.MPP <= M`, and the front-end
//                  redirects to `mtvec & ~1` (mtvec MODE is preserved as data;
//                  like Spike, only interrupts would vector, and RV-B has none).
//                * `mret` restores `mstatus` (MIE <= MPIE, MPIE <= 1, MPP <= U)
//                  and redirects to `mepc`.
//                * `err_o` stays the "never silently" strobe, but it is no longer
//                  a halt: it pulses for one cycle on every trap with
//                  `err_code_o` = the architectural `mcause` value (`err_o` is
//                  the valid strobe, since cause 0 is a legal code).
//
//              v0 memory ports (see `notes`; the AXI4 master of the next slice
//              keeps the request/response shape and moves the alignment into an
//              adapter):
//                I port: `imem_req_o` + `imem_addr_o` (16-bit-aligned PC);
//                        `imem_ready_i` marks the cycle in which `imem_rdata_i`
//                        carries the four bytes at that address.
//                D port: `dmem_req_o` + `dmem_addr_o` + `dmem_we_o` +
//                        `dmem_wstrb_o`/`dmem_wdata_o`; the bus is a **64-bit
//                        aligned beat**, i.e. exactly the AXI4 data-channel
//                        shape: `dmem_rdata_i` is the eight bytes at
//                        `dmem_addr_o & ~7`, and a write stores
//                        `dmem_wdata_o[8*lane +: 8]` at `(dmem_addr_o & ~7) + lane`
//                        for every lane `dmem_wstrb_o` marks. `dmem_ready_i` marks
//                        the cycle the beat is taken; the request is held until
//                        then. A transfer that one aligned beat cannot serve
//                        (misaligned halfword/word/dword) is NOT issued and
//                        raises the core error strobe instead.
//                Both ports must tolerate a dropped request before ready (a
//                redirect or an error abandons an in-flight fetch) and are
//                idempotent, which is what a following AXI4 adapter needs anyway.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - initial RV-B v0 slice (E2-RV1)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (5-stage pipeline, forwarding,
//              static prediction), §4 (I/D/RVFI port contract), §5 (DiffTest integration)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       No procedural loops in `always_*`; two-segment FSM styling is not
//              needed here (the only FSM lives in cor_muldiv). Branch prediction
//              is the one deviation from C14 worth naming: C14 §3 says "backward
//              taken", implemented exactly, but there is no branch-target cache —
//              the target comes straight from EX/MEM, so a taken branch costs the
//              same as a mispredict and the trace is unaffected either way.
module eth_rv_core (
    input  logic        clk_i,
    input  logic        rst_ni,

    // ---- instruction port ----
    output logic        imem_req_o,
    output logic [63:0] imem_addr_o,
    input  logic        imem_ready_i,
    input  logic [31:0] imem_rdata_i,

    // ---- data port ----
    output logic        dmem_req_o,
    output logic        dmem_we_o,
    output logic [63:0] dmem_addr_o,
    output logic [63:0] dmem_wdata_o,
    output logic [7:0]  dmem_wstrb_o,
    input  logic        dmem_ready_i,
    input  logic [63:0] dmem_rdata_i,

    // ---- RVFI-style commit trace (C14 §4) ----
    output logic        rvfi_valid_o,
    output logic [63:0] rvfi_order_o,
    output logic [63:0] rvfi_pc_o,
    output logic [31:0] rvfi_insn_o,
    output logic        rvfi_rd_we_o,
    output logic [4:0]  rvfi_rd_addr_o,
    output logic [63:0] rvfi_rd_wdata_o,
    output logic        rvfi_mem_valid_o,
    output logic [63:0] rvfi_mem_addr_o,
    output logic [63:0] rvfi_mem_wdata_o,
    output logic [7:0]  rvfi_mem_wmask_o,
    output logic [7:0]  rvfi_mem_rmask_o,

    // ---- error strobe: unimplemented encoding, never retired silently ----
    output logic        err_o,
    output logic [63:0] err_pc_o,
    output logic [31:0] err_insn_o,
    output logic [3:0]  err_code_o
);

    import eth_rv_pkg::*;

    // =====================================================================
    // IF stage
    // =====================================================================
    logic [63:0] fetch_pc_r;
    logic        fetch_is_c;
    logic [31:0] fetch_insn;
    logic [63:0] fetch_pred_pc;
    logic        fetch_hit;

    assign fetch_is_c = (imem_rdata_i[1:0] != 2'b11);
    assign fetch_insn = fetch_is_c ? {16'd0, imem_rdata_i[15:0]} : imem_rdata_i;

    ctrl_t       dec_ctrl;
    logic [4:0]  dec_rd;
    logic [4:0]  dec_rs1;
    logic [4:0]  dec_rs2;
    logic [63:0] dec_imm;

    logic        dec_pred_taken;
    cor_decoder u_decoder (
        .is_c_i    (fetch_is_c),
        .insn_i    (fetch_insn),
        .ctrl_o    (dec_ctrl),
        .rd_addr_o (dec_rd),
        .rs1_addr_o(dec_rs1),
        .rs2_addr_o(dec_rs2),
        .imm_o     (dec_imm),
        .pred_taken_o(dec_pred_taken)
    );

    // Static prediction: direct jumps are always taken, branches only when the
    // offset is negative (backward), indirect jumps fall through.
    always_comb begin
        fetch_pred_pc = fetch_pc_r + (fetch_is_c ? 64'd2 : 64'd4);
        if (dec_ctrl.is_jump && !dec_ctrl.is_indirect) begin
            fetch_pred_pc = fetch_pc_r + dec_imm;
        end else if (dec_ctrl.is_branch && dec_pred_taken) begin
            fetch_pred_pc = fetch_pc_r + dec_imm;
        end
    end

    // =====================================================================
    // IF/ID register (also the one-deep fetch buffer)
    // =====================================================================
    logic        id_valid_r;
    logic [63:0] id_pc_r;
    logic [31:0] id_insn_r;
    logic        id_is_c_r;
    logic [63:0] id_pred_r;
    ctrl_t       id_ctrl_r;
    logic [4:0]  id_rd_r;
    logic [4:0]  id_rs1_r;
    logic [4:0]  id_rs2_r;
    logic [63:0] id_imm_r;

    // =====================================================================
    // ID: register file read (combinational, no bypass)
    // =====================================================================
    logic [63:0] id_rs1_val;
    logic [63:0] id_rs2_val;

    // =====================================================================
    // ID/EX register
    // =====================================================================
    logic        ex_valid_r;
    logic [63:0] ex_pc_r;
    logic [31:0] ex_insn_r;
    logic        ex_is_c_r;
    logic [63:0] ex_pred_r;
    ctrl_t       ex_ctrl_r;
    logic [4:0]  ex_rd_r;
    logic [4:0]  ex_rs1_r;
    logic [4:0]  ex_rs2_r;
    logic [63:0] ex_rs1_val_r;
    logic [63:0] ex_rs2_val_r;
    logic [63:0] ex_imm_r;

    // =====================================================================
    // EX/MEM register (MEM stage)
    // =====================================================================
    logic        mem_valid_r;
    logic [63:0] mem_pc_r;
    logic [31:0] mem_insn_r;
    mem_ctrl_t    mem_ctrl_r;
    logic [4:0]  mem_rd_r;
    logic [63:0] mem_wb_pre_r;      // result before the memory access (ALU / muldiv / link)
    logic [63:0] mem_addr_r;
    logic [63:0] mem_store_data_r;

    // =====================================================================
    // MEM/WB register (WB stage == commit stage)
    // =====================================================================
    logic        wb_valid_r;
    logic [63:0] wb_pc_r;
    logic [31:0] wb_insn_r;
    commit_ctrl_t wb_ctrl_r;
    logic [4:0]  wb_rd_r;
    logic [63:0] wb_data_r;
    logic [63:0] wb_addr_r;
    logic [63:0] wb_store_data_r;
    logic [7:0]  wb_wmask_r;
    logic [7:0]  wb_rmask_r;
    logic [63:0] order_r;

    // =====================================================================
    // Control: stalls, flushes, hazard detection, trap detection
    // =====================================================================
    logic md_wait;      // EX is a mul/div without its result yet
    logic mem_wait;     // MEM is waiting for dmem_ready_i
    logic load_use;     // EX holds a load that ID needs
    logic ex_stall;     // freeze ID/EX (and the front-end)
    logic front_stall;  // freeze IF/ID
    logic flush_all;    // discard IF/ID + ID/EX (redirect or trap)
    logic id_consumed;  // ID moves into ID/EX this cycle

    logic        md_start;
    logic        md_valid;
    logic [63:0] md_result;
    logic        md_started_r;

    logic        ex_redirect;
    logic [63:0] ex_next_pc;
    logic        ex_target_misaligned;
    logic        mem_misaligned;
    logic        ex_trap;        // instruction-side exception, taken in EX
    logic        mem_trap;       // data-side exception, taken in MEM
    logic        trap_hit;
    logic [63:0] trap_pc;
    logic [63:0] trap_mtval;
    logic [31:0] trap_insn;
    logic [3:0]  trap_cause;
    logic [63:0] trap_target;
    logic [3:0]  ex_cause;
    logic [63:0] ex_trap_value;

    assign md_wait  = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_muldiv && !md_valid;
    // A misaligned access is a trap, not a stall: it never asserts `dmem_req_o`, so
    // waiting for `dmem_ready_i` would wedge the pipeline.
    assign mem_wait = mem_valid_r && !mem_ctrl_r.illegal
                      && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && !lsu_misaligned
                      && !dmem_ready_i;
    assign load_use = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_load
                      && (ex_rd_r != 5'd0) && id_valid_r
                      && ((ex_rd_r == id_rs1_r) || (ex_rd_r == id_rs2_r));
    assign mem_misaligned = mem_valid_r && !mem_ctrl_r.illegal
                            && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && lsu_misaligned;

    // ---- exception detection -------------------------------------------
    // Instruction-side exceptions are recognised in EX: an unimplemented
    // encoding, ecall/ebreak, or a control transfer to an odd address. That last
    // one is structurally unreachable while IALIGN = 16 and JALR clears bit 0 —
    // it is kept so a future IALIGN = 32 config (or a JALR that stopped masking)
    // cannot silently fetch from a misaligned address.
    // Data-side exceptions are recognised in MEM. The older fault wins: MEM is
    // architecturally ahead of EX, so a misaligned data access is taken even when
    // the instruction behind it also faults.
    assign ex_target_misaligned = ex_valid_r && !ex_ctrl_r.illegal && ex_next_pc[0];
    assign ex_trap = ex_valid_r && !ex_stall
                     && (ex_ctrl_r.illegal || ex_ctrl_r.is_ecall || ex_ctrl_r.is_ebreak
                         || ex_target_misaligned);
    assign mem_trap = mem_misaligned;
    assign trap_hit = mem_trap || ex_trap;
    assign trap_pc   = mem_trap ? mem_pc_r   : ex_pc_r;
    assign trap_insn = mem_trap ? mem_insn_r : ex_insn_r;

    always_comb begin
        if (ex_ctrl_r.is_ecall) begin
            ex_cause = eth_rv_pkg::CAUSE_ECALL_M;
        end else if (ex_ctrl_r.is_ebreak) begin
            ex_cause = eth_rv_pkg::CAUSE_BREAKPOINT;
        end else if (ex_target_misaligned) begin
            ex_cause = eth_rv_pkg::CAUSE_INSN_MISALIGN;
        end else begin
            ex_cause = eth_rv_pkg::CAUSE_ILLEGAL;
        end
    end

    always_comb begin
        // mtval: the misaligned target (fetch), the pc (breakpoint), zero (ecall)
        // or the offending instruction word (illegal) — Spike's exact choices.
        if (ex_ctrl_r.is_ebreak) begin
            ex_trap_value = ex_pc_r;
        end else if (ex_target_misaligned) begin
            ex_trap_value = ex_next_pc;
        end else if (ex_ctrl_r.is_ecall) begin
            ex_trap_value = 64'd0;
        end else begin
            ex_trap_value = {32'd0, ex_insn_r};
        end
    end

    assign trap_cause = mem_trap
                        ? (mem_ctrl_r.is_store ? eth_rv_pkg::CAUSE_STORE_MISALIGN
                                               : eth_rv_pkg::CAUSE_LOAD_MISALIGN)
                        : ex_cause;
    assign trap_mtval = mem_trap ? mem_addr_r : ex_trap_value;
    // Exceptions always go to the direct base, exactly like Spike — mtvec MODE is
    // kept as a data bit but only interrupts would vector, and RV-B has none.
    assign trap_target = csr_mtvec_r & ~64'd1;

    assign ex_stall    = md_wait || mem_wait;
    assign front_stall = ex_stall || load_use;
    assign flush_all   = ex_redirect || trap_hit;
    assign id_consumed = id_valid_r && !front_stall && !flush_all;

    // =====================================================================
    // EX datapath
    // =====================================================================
    logic [63:0] ex_fwd_a;      // forwarded rs1
    logic [63:0] ex_fwd_b;      // forwarded rs2
    logic [63:0] ex_alu_a;
    logic [63:0] ex_alu_b;
    logic [63:0] ex_alu_res;
    logic [63:0] ex_wb_pre;
    logic        ex_taken;
    logic [63:0] ex_len;

    assign ex_len = ex_is_c_r ? 64'd2 : 64'd4;

    // WB -> EX forwarding (a load's data is already in the WB register)
    always_comb begin
        ex_fwd_a = ex_rs1_val_r;
        if (wb_valid_r && wb_ctrl_r.rf_we && (wb_rd_r != 5'd0) && (wb_rd_r == ex_rs1_r)) begin
            ex_fwd_a = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.rf_we && !mem_ctrl_r.is_load
            && (mem_rd_r != 5'd0) && (mem_rd_r == ex_rs1_r)) begin
            ex_fwd_a = mem_wb_pre_r;      // younger producer in MEM wins
        end
    end

    always_comb begin
        ex_fwd_b = ex_rs2_val_r;
        if (wb_valid_r && wb_ctrl_r.rf_we && (wb_rd_r != 5'd0) && (wb_rd_r == ex_rs2_r)) begin
            ex_fwd_b = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.rf_we && !mem_ctrl_r.is_load
            && (mem_rd_r != 5'd0) && (mem_rd_r == ex_rs2_r)) begin
            ex_fwd_b = mem_wb_pre_r;
        end
    end

    always_comb begin
        ex_alu_a = ex_fwd_a;
        if (ex_ctrl_r.alu_a == OP_A_PC) begin
            ex_alu_a = ex_pc_r;
        end else if (ex_ctrl_r.alu_a == OP_A_ZERO) begin
            ex_alu_a = 64'd0;
        end
    end

    assign ex_alu_b = (ex_ctrl_r.alu_b == OP_B_IMM) ? ex_imm_r : ex_fwd_b;

    cor_alu u_alu (
        .op_i (ex_ctrl_r.alu_op),
        .w_i  (ex_ctrl_r.alu_w),
        .a_i  (ex_alu_a),
        .b_i  (ex_alu_b),
        .res_o(ex_alu_res)
    );

    // ---- branch / jump resolution ----
    always_comb begin
        ex_taken = 1'b0;
        unique case (ex_ctrl_r.br_f3)
            3'b000:  ex_taken = (ex_fwd_a == ex_fwd_b);
            3'b001:  ex_taken = (ex_fwd_a != ex_fwd_b);
            3'b100:  ex_taken = ($signed(ex_fwd_a) < $signed(ex_fwd_b));
            3'b101:  ex_taken = !($signed(ex_fwd_a) < $signed(ex_fwd_b));
            3'b110:  ex_taken = (ex_fwd_a < ex_fwd_b);
            3'b111:  ex_taken = !(ex_fwd_a < ex_fwd_b);
            default: ex_taken = 1'b0;
        endcase
    end

    always_comb begin
        if (ex_ctrl_r.is_mret) begin
            // mret is not predicted as a jump (the decoder leaves it to the
            // fall-through), so the redirect below catches it exactly like any
            // other mispredicted transfer.
            ex_next_pc = csr_mepc_r;
        end else if (ex_ctrl_r.is_jump) begin
            // direct: pc + imm; indirect (jalr family): (rs1 + imm) with bit 0 cleared
            ex_next_pc = ex_ctrl_r.is_indirect ? (ex_alu_res & ~64'd1) : ex_alu_res;
        end else if (ex_ctrl_r.is_branch && ex_taken) begin
            ex_next_pc = ex_alu_res;
        end else begin
            ex_next_pc = ex_pc_r + ex_len;
        end
    end

    // "did the fetched-path assumption hold?" — one condition for every
    // instruction class, so no control transfer can escape the flush. A trapping
    // instruction must not redirect to its own (possibly misaligned) target: the
    // trap machinery owns the PC in that cycle.
    assign ex_redirect = ex_valid_r && !ex_ctrl_r.illegal && !ex_target_misaligned
                         && (ex_next_pc != ex_pred_r);

    // ---- writeback value before the memory access ----
    always_comb begin
        if (ex_ctrl_r.is_muldiv) begin
            ex_wb_pre = md_result;
        end else if (ex_ctrl_r.wb_sel == WB_LINK) begin
            ex_wb_pre = ex_pc_r + ex_len;
        end else if (ex_ctrl_r.is_csr) begin
            ex_wb_pre = csr_rdata;         // CSRRS/CSRRW/… write the OLD value to rd
        end else begin
            ex_wb_pre = ex_alu_res;
        end
    end

    // =====================================================================
    // M-mode CSR file (C14 §3)
    // =====================================================================
    // Only the writable CSRs have state; misa/mip/mhartid are read-only constants
    // (their values live in the package so the golden model and the RTL cannot
    // drift apart). The reset value of mstatus (`MSTATUS_XL`) and `misa` match
    // Spike's for RV64IMC, which is what makes a corpus program that reads them
    // compare clean against the golden stream.
    logic [63:0] csr_mstatus_r;
    logic [63:0] csr_mie_r;
    logic [63:0] csr_mtvec_r;
    logic [63:0] csr_mepc_r;
    logic [63:0] csr_mcause_r;
    logic [63:0] csr_mtval_r;
    logic [63:0] csr_mscratch_r;

    logic [63:0] csr_rdata;
    logic [63:0] csr_wdata;
    logic [63:0] ex_csr_src;
    logic        ex_csr_we;
    logic        ex_mret_we;

    always_comb begin
        unique case (ex_ctrl_r.csr_addr)
            eth_rv_pkg::CSR_MSTATUS:  csr_rdata = csr_mstatus_r;
            eth_rv_pkg::CSR_MISA:     csr_rdata = eth_rv_pkg::MISA_VALUE;
            eth_rv_pkg::CSR_MIE:      csr_rdata = csr_mie_r;
            eth_rv_pkg::CSR_MTVEC:    csr_rdata = csr_mtvec_r;
            eth_rv_pkg::CSR_MSCRATCH: csr_rdata = csr_mscratch_r;
            eth_rv_pkg::CSR_MEPC:     csr_rdata = csr_mepc_r;
            eth_rv_pkg::CSR_MCAUSE:   csr_rdata = csr_mcause_r;
            eth_rv_pkg::CSR_MTVAL:    csr_rdata = csr_mtval_r;
            eth_rv_pkg::CSR_MIP:      csr_rdata = eth_rv_pkg::MIP_VALUE;
            eth_rv_pkg::CSR_MHARTID:  csr_rdata = eth_rv_pkg::MHARTID_VALUE;
            default:                  csr_rdata = 64'd0;
        endcase
    end

    // The source operand: rs1 for the register forms, the zero-extended uimm for
    // the immediate forms (the decoder put the uimm on the immediate bus and
    // suppressed the register read, so no false hazard is created).
    assign ex_csr_src = ex_ctrl_r.csr_imm ? ex_imm_r : ex_fwd_a;

    // CSRRS/CSRRC with rs1 = x0 (or uimm = 0) must not write the CSR; the
    // read side effect still happens. A CSR is written on the cycle the
    // instruction LEAVES EX: `!ex_stall` keeps a frozen stage from writing twice,
    // and `!trap_hit` keeps a younger instruction from writing when an older one
    // traps in MEM.
    assign ex_csr_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_csr
                       && ((ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RW) || (ex_csr_src != 64'd0));
    assign csr_wdata = (ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RW) ? ex_csr_src
                       : (ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RS) ? (csr_rdata | ex_csr_src)
                                                                  : (csr_rdata & ~ex_csr_src);

    // mret restores the interrupt-enable stack and returns to mepc. MPP is left as
    // the least-privileged mode value (U) exactly as Spike does; the hart does not
    // implement privilege levels, so MPP/MPIE are maintained as data to keep the
    // trap bookkeeping bit-exact with the golden model.
    assign ex_mret_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_mret;

    // =====================================================================

    // ---- M extension ----
    assign md_start = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_muldiv
                      && !md_started_r;

    cor_muldiv u_muldiv (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .start_i (md_start),
        .op_i    (ex_ctrl_r.md_op),
        .a_i     (ex_fwd_a),
        .b_i     (ex_fwd_b),
        .result_o(md_result),
        .valid_o (md_valid)
    );

    // =====================================================================
    // MEM stage
    // =====================================================================
    logic [63:0] lsu_load_data;
    logic [63:0] lsu_wdata;
    logic [7:0]  lsu_wstrb;
    logic [7:0]  lsu_rmask;
    logic        lsu_misaligned;

    cor_lsu u_lsu (
        .signed_i    (mem_ctrl_r.mem_signed),
        .size_i      (mem_ctrl_r.mem_size),
        .byte_off_i  (mem_addr_r[2:0]),
        .store_data_i(mem_store_data_r),
        .rdata_i     (dmem_rdata_i),
        .load_data_o (lsu_load_data),
        .wdata_o     (lsu_wdata),
        .wstrb_o     (lsu_wstrb),
        .rmask_o     (lsu_rmask),
        .misaligned_o(lsu_misaligned)
    );

    assign dmem_req_o   = mem_valid_r && !mem_ctrl_r.illegal
                          && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && !lsu_misaligned;
    assign dmem_we_o    = mem_ctrl_r.is_store;
    assign dmem_addr_o  = mem_addr_r;
    assign dmem_wdata_o = mem_ctrl_r.is_store ? lsu_wdata : 64'd0;
    assign dmem_wstrb_o = mem_ctrl_r.is_store ? lsu_wstrb : 8'd0;

    // =====================================================================
    // WB stage / commit + trace
    // =====================================================================
    logic wb_we;

    assign wb_we = wb_valid_r && wb_ctrl_r.rf_we && !wb_ctrl_r.illegal && (wb_rd_r != 5'd0);

    cor_regfile u_regfile (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .we_i     (wb_we),
        .waddr_i  (wb_rd_r),
        .wdata_i  (wb_data_r),
        .raddr_a_i(id_rs1_r),
        .raddr_b_i(id_rs2_r),
        .rdata_a_o(id_rs1_val),
        .rdata_b_o(id_rs2_val)
    );

    assign rvfi_valid_o     = wb_valid_r;
    assign rvfi_order_o     = order_r;
    assign rvfi_pc_o        = wb_pc_r;
    assign rvfi_insn_o      = wb_insn_r;
    assign rvfi_rd_we_o     = wb_valid_r && wb_ctrl_r.rf_we && !wb_ctrl_r.illegal
                              && (wb_rd_r != 5'd0);
    assign rvfi_rd_addr_o   = wb_rd_r;
    assign rvfi_rd_wdata_o  = wb_data_r;
    assign rvfi_mem_valid_o = wb_valid_r && !wb_ctrl_r.illegal
                              && (wb_ctrl_r.is_load || wb_ctrl_r.is_store);
    assign rvfi_mem_addr_o  = wb_addr_r;
    // The trace records what the golden model records: the address, the stored
    // value truncated to the access size and unshifted (Spike's `mem` field), and
    // the byte lanes of the aligned window at `addr & ~7` (RVFI) — the D-port's
    // own lane-shifted beat data is `dmem_wdata_o`/`dmem_wstrb_o` and is used to
    // drive the bus, not to describe the architectural effect.
    assign rvfi_mem_wdata_o = wb_ctrl_r.is_store ? wb_store_data_r : 64'd0;
    assign rvfi_mem_wmask_o = wb_wmask_r;
    assign rvfi_mem_rmask_o = wb_rmask_r;

    // The error strobe no longer latches (nothing halts): it pulses for one cycle
    // when a trap is taken and carries the architectural cause. `err_o` is the
    // valid strobe — CAUSE_INSN_MISALIGN is 0.
    assign err_o      = trap_hit;
    assign err_pc_o   = trap_pc;
    assign err_insn_o = trap_insn;
    assign err_code_o = trap_hit ? trap_cause : 4'd0;

    // =====================================================================
    // Sequential
    // =====================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            fetch_pc_r <= RESET_PC;
        end else if (trap_hit) begin
            fetch_pc_r <= trap_target;      // a trap outranks any redirect
        end else if (ex_redirect) begin
            fetch_pc_r <= ex_next_pc;
        end else if (fetch_hit) begin
            fetch_pc_r <= fetch_pred_pc;
        end
    end

    assign imem_req_o  = !flush_all && !ex_stall && (id_consumed || !id_valid_r);
    assign imem_addr_o = fetch_pc_r;
    assign fetch_hit   = imem_req_o && imem_ready_i;
    // ---- CSR state: trap effects outrank a younger instruction's CSR write ----
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            csr_mstatus_r  <= eth_rv_pkg::MSTATUS_XL;
            csr_mie_r      <= 64'd0;
            csr_mtvec_r    <= 64'd0;
            csr_mepc_r     <= 64'd0;
            csr_mcause_r   <= 64'd0;
            csr_mtval_r    <= 64'd0;
            csr_mscratch_r <= 64'd0;
        end else if (trap_hit) begin
            // The trapping instruction is older than whatever sits in EX, so its
            // effects win; mepc/mcause/mtval follow the ISA and Spike.
            csr_mepc_r   <= trap_pc;
            csr_mcause_r <= {60'd0, trap_cause};
            csr_mtval_r  <= trap_mtval;
            csr_mstatus_r <= (csr_mstatus_r & ~eth_rv_pkg::MSTATUS_WMASK)
                             | (csr_mstatus_r[3] ? eth_rv_pkg::MSTATUS_MPIE : 64'd0)
                             | eth_rv_pkg::MSTATUS_MPP_M;
        end else if (ex_csr_we) begin
            unique case (ex_ctrl_r.csr_addr)
                eth_rv_pkg::CSR_MSTATUS: begin
                    csr_mstatus_r <= (csr_mstatus_r & ~eth_rv_pkg::MSTATUS_WMASK)
                                     | (csr_wdata & eth_rv_pkg::MSTATUS_WMASK);
                end
                eth_rv_pkg::CSR_MIE: begin
                    csr_mie_r <= csr_wdata & eth_rv_pkg::MIE_WMASK;
                end
                eth_rv_pkg::CSR_MTVEC: begin
                    csr_mtvec_r <= csr_wdata;   // MODE kept verbatim; the trap target masks bit 0
                end
                eth_rv_pkg::CSR_MEPC: begin
                    csr_mepc_r <= csr_wdata & eth_rv_pkg::MEPC_MASK;
                end
                eth_rv_pkg::CSR_MCAUSE: begin
                    csr_mcause_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_MTVAL: begin
                    csr_mtval_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_MSCRATCH: begin
                    csr_mscratch_r <= csr_wdata;
                end
                // misa / mip / mhartid are read-only: the access is legal and the
                // write is dropped (WARL), never a trap and never silent damage.
                default: ;
            endcase
        end else if (ex_mret_we) begin
            csr_mstatus_r <= (csr_mstatus_r & ~eth_rv_pkg::MSTATUS_WMASK)
                             | eth_rv_pkg::MSTATUS_MPIE
                             | (csr_mstatus_r[7] ? eth_rv_pkg::MSTATUS_MIE : 64'd0);
        end
    end

    // IF/ID
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            id_valid_r <= 1'b0;
            id_pc_r    <= 64'd0;
            id_insn_r  <= 32'd0;
            id_is_c_r  <= 1'b0;
            id_pred_r  <= 64'd0;
            id_ctrl_r  <= '0;
            id_rd_r    <= 5'd0;
            id_rs1_r   <= 5'd0;
            id_rs2_r   <= 5'd0;
            id_imm_r   <= 64'd0;
        end else if (flush_all) begin
            id_valid_r <= 1'b0;
        end else if (ex_stall) begin
            id_valid_r <= id_valid_r;
        end else if (id_consumed || !id_valid_r) begin
            id_valid_r <= fetch_hit;
            if (fetch_hit) begin
                id_pc_r   <= fetch_pc_r;
                id_insn_r <= fetch_insn;
                id_is_c_r <= fetch_is_c;
                id_pred_r <= fetch_pred_pc;
                id_ctrl_r <= dec_ctrl;
                id_rd_r   <= dec_rd;
                id_rs1_r  <= dec_rs1;
                id_rs2_r  <= dec_rs2;
                id_imm_r  <= dec_imm;
            end
        end
    end

    // ID/EX
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ex_valid_r    <= 1'b0;
            ex_pc_r       <= 64'd0;
            ex_insn_r     <= 32'd0;
            ex_is_c_r     <= 1'b0;
            ex_pred_r     <= 64'd0;
            ex_ctrl_r     <= '0;
            ex_rd_r       <= 5'd0;
            ex_rs1_r      <= 5'd0;
            ex_rs2_r      <= 5'd0;
            ex_rs1_val_r  <= 64'd0;
            ex_rs2_val_r  <= 64'd0;
            ex_imm_r      <= 64'd0;
            md_started_r  <= 1'b0;
        end else begin
            if (md_start) begin
                md_started_r <= 1'b1;
            end else if (!ex_stall) begin
                md_started_r <= 1'b0;
            end
            if (ex_stall) begin
                ex_valid_r <= ex_valid_r;
            end else if (flush_all) begin
                ex_valid_r <= 1'b0;
            end else begin
                ex_valid_r <= id_consumed;
                if (id_consumed) begin
                    ex_pc_r      <= id_pc_r;
                    ex_insn_r    <= id_insn_r;
                    ex_is_c_r    <= id_is_c_r;
                    ex_pred_r    <= id_pred_r;
                    ex_ctrl_r    <= id_ctrl_r;
                    ex_rd_r      <= id_rd_r;
                    ex_rs1_r     <= id_rs1_r;
                    ex_rs2_r     <= id_rs2_r;
                    ex_rs1_val_r <= id_rs1_val;
                    ex_rs2_val_r <= id_rs2_val;
                    ex_imm_r     <= id_imm_r;
                end
            end
        end
    end

    // EX/MEM
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mem_valid_r      <= 1'b0;
            mem_pc_r         <= 64'd0;
            mem_insn_r       <= 32'd0;
            mem_ctrl_r       <= '0;
            mem_rd_r         <= 5'd0;
            mem_wb_pre_r     <= 64'd0;
            mem_addr_r       <= 64'd0;
            mem_store_data_r <= 64'd0;
        end else if (mem_wait) begin
            mem_valid_r <= mem_valid_r;
        end else if (trap_hit) begin
            // the trapping instruction (or the younger one behind a MEM trap) must
            // not enter MEM: neither may perform a memory access or commit
            mem_valid_r <= 1'b0;
        end else begin
            mem_valid_r <= ex_valid_r && !ex_stall && !ex_ctrl_r.illegal
                           && !ex_ctrl_r.is_ecall && !ex_ctrl_r.is_ebreak;
            if (ex_valid_r && !ex_stall && !ex_ctrl_r.illegal) begin
                mem_pc_r         <= ex_pc_r;
                mem_insn_r       <= ex_insn_r;
                mem_ctrl_r.illegal    <= ex_ctrl_r.illegal;
                mem_ctrl_r.rf_we      <= ex_ctrl_r.rf_we;
                mem_ctrl_r.is_load    <= ex_ctrl_r.is_load;
                mem_ctrl_r.is_store   <= ex_ctrl_r.is_store;
                mem_ctrl_r.mem_size   <= ex_ctrl_r.mem_size;
                mem_ctrl_r.mem_signed <= ex_ctrl_r.mem_signed;
                mem_rd_r         <= ex_rd_r;
                mem_wb_pre_r     <= ex_wb_pre;
                mem_addr_r       <= ex_alu_res;      // load/store address
                mem_store_data_r <= ex_fwd_b;        // store data (rs2)
            end
        end
    end

    // MEM/WB + commit counter
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_valid_r      <= 1'b0;
            wb_pc_r         <= 64'd0;
            wb_insn_r       <= 32'd0;
            wb_ctrl_r       <= '0;
            wb_rd_r         <= 5'd0;
            wb_data_r       <= 64'd0;
            wb_addr_r       <= 64'd0;
            wb_store_data_r <= 64'd0;
            wb_wmask_r      <= 8'd0;
            wb_rmask_r      <= 8'd0;
            order_r         <= 64'd1;
        end else begin
            // a trapping MEM instruction must not reach WB: no commit record, no
            // register write and (for a store) no bus transaction
            wb_valid_r      <= (mem_wait || mem_trap) ? 1'b0 : mem_valid_r;
            if (mem_valid_r && !mem_wait && !mem_trap) begin
                wb_pc_r         <= mem_pc_r;
                wb_insn_r       <= mem_insn_r;
                wb_ctrl_r.illegal  <= mem_ctrl_r.illegal;
                wb_ctrl_r.rf_we    <= mem_ctrl_r.rf_we;
                wb_ctrl_r.is_load  <= mem_ctrl_r.is_load;
                wb_ctrl_r.is_store <= mem_ctrl_r.is_store;
                wb_rd_r         <= mem_rd_r;
                wb_data_r       <= mem_ctrl_r.is_load ? lsu_load_data : mem_wb_pre_r;
                wb_addr_r       <= mem_addr_r;
                // Spike logs the stored data truncated to the access size, so the
                // trace carries exactly that (see the RVFI block above)
                wb_store_data_r <= eth_rv_pkg::store_wdata(mem_store_data_r,
                                                           mem_ctrl_r.mem_size);
                wb_wmask_r      <= mem_ctrl_r.is_store ? lsu_wstrb : 8'd0;
                wb_rmask_r      <= mem_ctrl_r.is_load  ? lsu_rmask : 8'd0;
            end
            if (wb_valid_r) begin
                order_r <= order_r + 64'd1;
            end
        end
    end

endmodule
`default_nettype wire
