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
//                * Traps: illegal instruction, ebreak, ecall, load/store address
//                  misaligned, and the three ACCESS faults (instruction/load/
//                  store, `mcause` 1/5/7) raised by a port error response — an
//                  address no device claims, a device that rejects the access,
//                  or a DECERR/SLVERR bus response. Every one of them carries
//                  Spike's `mtval`: the access address (the faulting fetch pc for
//                  cause 1). The trapping instruction does NOT commit;
//                  `mepc`/`mcause`/`mtval` are written, `mstatus.MPIE <= MIE`,
//                  `mstatus.MIE <= 0`, `mstatus.MPP <= M`, and the front-end
//                  redirects to `mtvec & ~1` (mtvec MODE is preserved as data;
//                  like Spike, only interrupts would vector, and RV-B has none).
//                * `mret` restores `mstatus` (MIE <= MPIE, MPIE <= 1, MPP <= U)
//                  and redirects to `mepc`.
//              * `err_o` stays the "never silently" strobe, but it is no longer
//                a halt: it pulses for one cycle on every trap with
//                `err_code_o` = the architectural `mcause` value (`err_o` is
//                the valid strobe, since cause 0 is a legal code).
//
//              Sv39 address translation (E2-RV2 increment 1, C14 §3):
//                `satp` is a real CSR, the walk is `cor_mmu`, and both memory
//                ports see PHYSICAL addresses while the pipeline, the trace and
//                the trap CSRs keep the VIRTUAL ones. Translation applies when
//                `satp.MODE` is Sv39 (8) and the access is made below M-mode;
//                M-mode is never translated (MPRV stays a documented boundary —
//                the bit is WARL storage, its behaviour is not implemented).
//                * fetch: the front-end translates `fetch_pc_r` before it asks
//                  the I port, so `imem_addr_o` is physical while `rvfi_pc_o`,
//                  `mepc`/`sepc` and a fetch fault's `mtval` stay virtual. A
//                  translation fault is latched into IF/ID *as* the fetched
//                  instruction (cause 12, or 1 when the PTE read itself faulted),
//                  so it takes the ordinary EX-side trap path and never reaches
//                  the port.
//                * data: the MEM stage walks before it drives the D port, so
//                  `dmem_addr_o`/`dmem_wdata_o`/`dmem_wstrb_o` describe the
//                  physical transfer while `rvfi_mem_addr_o` (what Spike logs)
//                  is the virtual address the instruction named — the page
//                  offset is common to both, which `rvfi_mem_paddr_o` (the
//                  physical address of the committed access) makes explicit.
//                * one walker serves both paths. The pipeline stalls while a
//                  walk runs (the walk drives the D port, so the MEM stage
//                  cannot), and the MEM stage always wins the arbitration — the
//                  fetch side only asks when the front-end is already free to
//                  move, so a deferred fetch walk costs cycles and never
//                  correctness.
//                * `sfence.vma` is a privilege check and nothing else here: the
//                  walker keeps no TLB and no PTE cache, so there is no cached
//                  translation for it to invalidate. The trade is deliberate
//                  (see verif/eth_rv/README.md "Sv39 translation").
//
//              v0 memory ports (see `notes`; the AXI4 master of the next slice
//              keeps the request/response shape and moves the alignment into an
//              adapter):
//                I port: `imem_req_o` + `imem_addr_o` (16-bit-aligned PC);
//                        `imem_ready_i` marks the cycle in which `imem_rdata_i`
//                        carries the four bytes at that address, and
//                        `imem_err_i` — sampled on that same cycle — marks the
//                        fetch as unservable: the data is void and the
//                        instruction raises `CAUSE_INSN_ACCESS` at its own pc
//                        (the fetch of an unmapped address, exactly Spike's
//                        `trap_instruction_access_fault`). It is never decoded.
//                D port: `dmem_req_o` + `dmem_addr_o` + `dmem_we_o` +
//                        `dmem_wstrb_o`/`dmem_wdata_o` + `dmem_size_o`; the bus is
//                        a **64-bit aligned beat**, i.e. exactly the AXI4
//                        data-channel shape: `dmem_rdata_i` is the eight bytes at
//                        `dmem_addr_o & ~7`, and a write stores
//                        `dmem_wdata_o[8*lane +: 8]` at `(dmem_addr_o & ~7) + lane`
//                        for every lane `dmem_wstrb_o` marks. `dmem_ready_i` marks
//                        the cycle the beat is taken; the request is held until
//                        then. `dmem_err_i`, sampled with `dmem_ready_i`, marks
//                        the beat as an error response: the bytes are void, the
//                        access raises `CAUSE_LOAD_ACCESS`/`CAUSE_STORE_ACCESS`
//                        with `mtval` = `dmem_addr_o`, and nothing is written to
//                        the register file or to memory. A transfer that one
//                        aligned beat cannot serve (misaligned halfword/word/
//                        dword) is NOT issued and raises the misaligned trap
//                        instead. `dmem_size_o` carries the access's byte count
//                        (`eth_rv_pkg::mem_size_e`) so a byte-register device can
//                        reject a width it does not serve.
//                Both ports must tolerate a dropped request before ready (a
//                redirect or an error abandons an in-flight fetch) and are
//                idempotent, which is what a following AXI4 adapter needs anyway.
//                An error response NEVER becomes a silent success and never a
//                wedge: `dmem_ready_i` and `dmem_err_i` arrive in the same cycle
//                and the pipeline traps on that beat.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 5: D/I-port error responses (access faults)
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
    input  logic        imem_err_i,      // with imem_ready_i: this fetch faulted

    // ---- data port ----
    output logic        dmem_req_o,
    output logic        dmem_we_o,
    output logic [63:0] dmem_addr_o,
    output logic [63:0] dmem_wdata_o,
    output logic [7:0]  dmem_wstrb_o,
    output logic [1:0]  dmem_size_o,     // eth_rv_pkg::mem_size_e: the access's byte count
    input  logic        dmem_ready_i,
    input  logic [63:0] dmem_rdata_i,
    input  logic        dmem_err_i,      // with dmem_ready_i: this access faulted

    // ---- interrupt lines (C14 §3; the CLINT in eth_rv_mmio_mux drives them) ----
    input  logic        msip_i,          // machine software interrupt (CLINT msip[0])
    input  logic        mtip_i,          // machine timer interrupt (mtime >= mtimecmp)
    input  logic        meip_i,          // machine external interrupt (no PLIC: tied 0)

    // ---- RVFI-style commit trace (C14 §4) ----
    output logic        rvfi_valid_o,
    output logic [63:0] rvfi_order_o,
    output logic [63:0] rvfi_pc_o,
    output logic [31:0] rvfi_insn_o,
    output logic        rvfi_rd_we_o,
    output logic [4:0]  rvfi_rd_addr_o,
    output logic [63:0] rvfi_rd_wdata_o,
    output logic        rvfi_rd_fp_o,      // the record writes an FP register (F/D)
    output logic        rvfi_fflags_we_o,  // this commit wrote `fflags`
    output logic [4:0]  rvfi_fflags_o,
    output logic        rvfi_frm_we_o,     // this commit wrote `frm`
    output logic [2:0]  rvfi_frm_o,
    output logic        rvfi_mem_valid_o,
    output logic [63:0] rvfi_mem_addr_o,
    output logic [63:0] rvfi_mem_wdata_o,
    output logic [7:0]  rvfi_mem_wmask_o,
    output logic [7:0]  rvfi_mem_rmask_o,
    output logic [63:0] rvfi_mem_paddr_o,  // the PHYSICAL address of that access

    // ---- error strobe: unimplemented encoding, never retired silently ----
    output logic        err_o,
    output logic [63:0] err_pc_o,
    output logic [31:0] err_insn_o,
    output logic [3:0]  err_code_o,
    output logic        err_irq_o,   // with err_o: this trap is an interrupt

    // ---- executed-instruction strobe (the SoC CLINT's mtime cadence) ----
    output logic        step_o
);

    // ---- package names used unqualified in this module --------------------
    // The wildcard `import eth_rv_pkg::*;` is not accepted by the yosys
    // frontend the formal flow reads this file with, so the handful of names
    // this module uses are aliased explicitly — the established repo pattern
    // (see emri/emri_regfile.sv). Verilator/iverilog see the same names either
    // way, and a name used here but not aliased is a compile error, not a
    // silent default.
    typedef eth_rv_pkg::ctrl_t        ctrl_t;
    typedef eth_rv_pkg::mem_ctrl_t    mem_ctrl_t;
    typedef eth_rv_pkg::commit_ctrl_t commit_ctrl_t;

    localparam logic [63:0]           RESET_PC   = eth_rv_pkg::RESET_PC;
    localparam eth_rv_pkg::op_a_sel_e OP_A_PC    = eth_rv_pkg::OP_A_PC;
    localparam eth_rv_pkg::op_a_sel_e OP_A_ZERO  = eth_rv_pkg::OP_A_ZERO;
    localparam eth_rv_pkg::op_b_sel_e OP_B_IMM   = eth_rv_pkg::OP_B_IMM;
    localparam eth_rv_pkg::wb_sel_e   WB_LINK    = eth_rv_pkg::WB_LINK;

    // =====================================================================
    // IF stage
    // =====================================================================
    logic [63:0] fetch_pc_r;
    logic        fetch_is_c;
    logic [31:0] fetch_insn;
    logic [63:0] fetch_pred_pc;
    logic        fetch_hit;
    logic [3:0]  fetch_fault_cause;  // 0 = no fault, else the architectural cause
    logic        fetch_take;         // this cycle's fetch becomes the IF/ID instruction

    assign fetch_is_c = (imem_rdata_i[1:0] != 2'b11);
    assign fetch_insn = fetch_is_c ? {16'd0, imem_rdata_i[15:0]} : imem_rdata_i;

    // ---- Sv39: the fetch address is translated before it reaches the port ----
    // `ft_*` holds the translation of the CURRENT `fetch_pc_r`: the page base
    // (the 4 KiB offset comes from the virtual address, so a superset of it is
    // preserved) and, when the walk faulted, the architectural cause. It is
    // invalidated whenever the fetch pc moves (a new translation is needed) and
    // whenever the translation's inputs could have changed — a CSR write, a
    // trap, an xRET or `sfence.vma`. No TLB and no PTE cache: a miss costs one
    // walk of `cor_mmu`, which is the whole cache design.
    logic        ft_valid_r;
    logic [51:0] ft_page_r;
    logic [3:0]  ft_fault_r;
    logic [63:0] fw_vaddr_r;    // the vaddr the walk in flight was started for
    logic        ft_hit;
    logic        ft_fault_hit;
    logic        fetch_ready;       // the front-end may take a fetch this cycle
    logic        imem_req_w;

    assign ft_hit       = ft_valid_r && (ft_fault_r == 4'd0);
    assign ft_fault_hit = ft_valid_r && (ft_fault_r != 4'd0);
    // "the front-end wants a fetch": the IF/ID slot is empty or being vacated,
    // and nothing is freezing it. Identical to the pre-Sv39 condition, with the
    // stall terms factored out so the translation request can use it too.
    assign fetch_ready  = !flush_all && !ex_stall && (!id_valid_r || !load_use);
    assign imem_req_w   = fetch_ready && (!mmu_fetch_on || ft_hit);
    assign fetch_hit    = imem_req_w && imem_ready_i;
    assign fetch_take   = fetch_hit || (fetch_ready && ft_fault_hit);
    // A taken fetch either has no fault (the port may still answer with an error
    // response: `imem_err_i` with `imem_ready_i` means no instruction is there,
    // cause 1) or carries the walk's fault (cause 12, or 1 when the PTE read
    // itself was refused). The bytes on `imem_rdata_i` are void in both cases, so
    // the encoding is NOT decoded — the cause travels down the pipe instead.
    assign fetch_fault_cause = (fetch_ready && ft_fault_hit) ? ft_fault_r
                               : (fetch_hit && imem_err_i)  ? eth_rv_pkg::CAUSE_INSN_ACCESS
                                                            : 4'd0;

    // A fetch walk is started for whichever pc the front-end has reached, and the
    // front-end then cannot move (no translation, so no request) until the walk
    // finishes — EXCEPT that an older instruction can redirect the pc while the
    // walk is in flight (a taken branch, a jalr, an mret, a trap). The result is
    // therefore tagged with the address it was started for and accepted only
    // while that is still the current `fetch_pc_r`: without the tag, a
    // speculative walk (the predicted fall-through of a jalr, say) that finishes
    // in or after the redirect's cycle hands its page to the new pc, and the
    // front-end then fetches the right *virtual* address from the wrong page.
    logic        walk_done_fetch;
    assign walk_done_fetch = mmu_done && walk_is_fetch_r;

     ctrl_t       dec_ctrl;
    logic [4:0]  dec_rd;
    logic [4:0]  dec_rs1;
    logic [4:0]  dec_rs2;
    logic [4:0]  dec_rs3;
    logic [63:0] dec_imm;

    logic        dec_pred_taken;
    cor_decoder u_decoder (
        .is_c_i    (fetch_is_c),
        .insn_i    (fetch_insn),
        .ctrl_o    (dec_ctrl),
         .rd_addr_o (dec_rd),
        .rs1_addr_o(dec_rs1),
        .rs2_addr_o(dec_rs2),
        .rs3_addr_o(dec_rs3),
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
    logic [3:0]  id_fault_r;    // this instruction's fetch faulted (0 = it did not)
    ctrl_t       id_ctrl_r;
     logic [4:0]  id_rd_r;
    logic [4:0]  id_rs1_r;
    logic [4:0]  id_rs2_r;
    logic [4:0]  id_rs3_r;
    logic [63:0] id_imm_r;

    // =====================================================================
    // ID: register file read (combinational, no bypass)
    // =====================================================================
     logic [63:0] id_rs1_val;
    logic [63:0] id_rs2_val;
    logic [63:0] id_fp_rs1_val;
    logic [63:0] id_fp_rs2_val;
    logic [63:0] id_fp_rs3_val;

    // =====================================================================
    // ID/EX register
    // =====================================================================
    logic        ex_valid_r;
    logic [63:0] ex_pc_r;
    logic [31:0] ex_insn_r;
    logic        ex_is_c_r;
    logic [63:0] ex_pred_r;
    logic [3:0]  ex_fault_r;    // this instruction's fetch fault (0 = it did not)
    ctrl_t       ex_ctrl_r;
     logic [4:0]  ex_rd_r;
    logic [4:0]  ex_rs1_r;
    logic [4:0]  ex_rs2_r;
    logic [4:0]  ex_rs3_r;
    logic [63:0] ex_rs1_val_r;
    logic [63:0] ex_rs2_val_r;
    logic [63:0] ex_fp_rs1_val_r;
    logic [63:0] ex_fp_rs2_val_r;
    logic [63:0] ex_fp_rs3_val_r;
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
    logic        mem_fflags_we_r;
    logic [4:0]  mem_fflags_val_r;
    logic        mem_frm_we_r;
    logic [2:0]  mem_frm_val_r;

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
    logic [63:0] wb_paddr_r;
    logic [63:0] wb_store_data_r;
    logic [7:0]  wb_wmask_r;
    logic [7:0]  wb_rmask_r;
    logic [63:0] order_r;
    // the FP CSRs whose write a commit reports (the trace's `fflags=`/`frm=`)
    logic        wb_fflags_we_r;
    logic [4:0]  wb_fflags_r;
    logic        wb_frm_we_r;
    logic [2:0]  wb_frm_r;

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
    // ---- F/D (E2-RV2 increment 2) ----
    logic        fp_start;        // launch the FPU this cycle
    logic        fp_wait;         // EX holds an FP op whose result is not ready
    logic        fp_valid;        // the FPU's result strobe
    logic [63:0] fp_result;
    logic [4:0]  fp_fflags;       // flags this FP operation raised
    logic        fp_started_r;    // the launch pulse has been issued
    logic [2:0]  ex_fp_rm_eff;    // rm after the dynamic (frm) substitution
    logic        ex_fp_needs_fpu; // FP op that runs on the FPU (not a load/store)
    logic        ex_fp_illegal;   // an FP instruction while mstatus.FS is Off
    logic        ex_fp_rm_illegal;// a reserved rounding mode
    logic        ex_fp_csr_off;   // fcsr/fflags/frm access while FS is Off
    logic        ex_fs_dirty;     // this instruction sets mstatus.FS to Dirty
    logic        ex_fpu_ff_we;    // this instruction raises fflags bits
    logic [4:0]  ex_fpu_ff;       // ... and the bits it raises
    logic        ex_fp_csr_we;    // this instruction writes an FP CSR
    logic [63:0] ex_op1, ex_op2, ex_op3;  // class-resolved operands for the FPU

    logic        ex_redirect;
    logic [63:0] ex_next_pc;
    logic        ex_target_misaligned;
    logic        mem_misaligned;
    logic        mem_access_err;
    logic        ex_trap;        // instruction-side exception, taken in EX
    logic        mem_trap;       // data-side exception, taken in MEM
    logic        trap_hit;
    logic        trap_is_irq;    // this trap is an interrupt (bit 63 of the cause)
    logic        trap_to_s;      // ... and it is delegated to S-mode
    logic [63:0] trap_pc;
    logic [63:0] trap_mtval;
    logic [31:0] trap_insn;
    logic [3:0]  trap_cause;
    logic [63:0] trap_target;
    logic [3:0]  ex_cause;
    logic [63:0] ex_trap_value;

    // privilege-aware legality of SYSTEM instructions and CSR accesses (the
    // decoder classifies the encoding; the *current* mode decides legality)
    logic        ex_csr_write_form;
    logic        ex_csr_priv_ok;
    logic        ex_csr_illegal;
    logic        ex_mret_illegal;
    logic        ex_sret_illegal;
    logic        ex_sfence_illegal;
    logic [1:0]  priv_eff;

    // ---- Sv39 translation (E2-RV2 increment 1) -----------------------------
    // One walker (`u_mmu`) serves the fetch path and the MEM stage; the MEM
    // stage arbitrates with priority, and the walk drives the D port.
    logic [63:0] csr_satp_r;
    logic        mmu_on;            // satp.MODE is Sv39
    logic        mmu_xlate;         // ... and this access is below M-mode
    logic        mmu_fetch_on;      // a fetch must be translated
    logic        mmu_data_on;       // a data access must be translated
    logic        mmu_start;
    logic [63:0] mmu_vaddr;
    eth_rv_pkg::acc_e mmu_acc;
    logic        mmu_busy;
    logic        mmu_done;
    logic [63:0] mmu_paddr;
    logic [3:0]  mmu_fault;
    logic        walk_is_fetch_r;   // the walk in flight serves the fetch path
    logic        fetch_walk_start;
    logic        mem_walk_start;
    logic        mem_start;
    logic        mem_owns_dport;   // the MEM stage's access owns the D port

    // MEM stage access sequencing: walk first, then drive the D port, exactly
    // one access at a time.
    typedef enum logic [1:0] {
        MEM_IDLE = 2'd0,
        MEM_WALK = 2'd1,
        MEM_ACC  = 2'd2
    } mem_phase_e;

    mem_phase_e  mem_phase_r;
    logic [63:0] mem_paddr_r;       // the translated address of the access in MEM
    logic        mem_is_access;
    logic        mem_xlate_fault;

    // ---- A extension (RV64A) + wfi (E2-RV2 increment 3) ---------------------
    // An AMO is the one access that needs TWO D-port beats (read, then write), so
    // MEM_ACC has a sub-phase: `amo_write_r` is low for the read beat and high for
    // the write beat. Every other access — a load, a store, an lr, an sc that will
    // store — stays a single-beat MEM_ACC, exactly as before.
    logic        amo_write_r;       // MEM_ACC is issuing the AMO's write beat
    logic [63:0] amo_old_r;         // the memory operand the AMO's read beat returned
    logic        mem_amo_read;      // this beat is an AMO's read
    logic        mem_amo_write;     // this beat is an AMO's write
    logic [63:0] amo_result_w;      // op(old, rs2) the write beat stores
    logic [63:0] lsu_store_data;    // what cor_lsu treats as the store data
    logic        mem_beat_off;      // this MEM_ACC issues no beat at all (failing SC)
    logic        mem_beat_err;      // the beat was answered with a port error
    logic        mem_beat_last;     // this beat finishes the access (an AMO's write)
    logic        mem_acc_done;      // the access's last beat is accepted this cycle
    logic [63:0] mem_late_rd;       // the rd value of a late-rd instruction
    // The reservation: a single (valid, address) pair, exactly Spike's
    // `mmu_t::load_reservation_address`. lr arms it, sc consumes it.
    logic        resv_valid_r;
    logic [63:0] resv_addr_r;       // Spike compares PHYSICAL addresses
    logic        sc_have_resv;      // the SC's reservation matches its address
    logic        lr_beat;           // the LR's beat is accepted this cycle
    logic        sc_exec;           // the SC ends its access this cycle (consumes the reservation)
    // wfi: MEM holds the instruction until `mip & mie` is non-zero (see the
    // interrupt section: that is Spike's exact "exit WFI" condition).
    logic        wfi_wait;
    logic        ex_wfi_illegal;    // U-mode wfi

    // the D port, muxed between the MEM stage and the walker's PTE read
    logic        dmem_we_core;
    logic [63:0] dmem_addr_core;
    logic [63:0] dmem_wdata_core;
    logic [7:0]  dmem_wstrb_core;
    logic [1:0]  dmem_size_core;
    logic        mmu_pte_req;
    logic [63:0] mmu_pte_addr;

    // interrupt lines and selection
    logic [63:0] mip_eff;        // mip as the CSR/read path sees it
    logic [11:0] irq_pending;    // mip & mie, restricted to the six IRQ bits
    logic        irq_m_enabled;
    logic        irq_s_enabled;
    logic        irq_take;       // an interrupt is deliverable in this cycle
    logic [3:0]  irq_code;
    logic        ex_irq;         // ... and it is taken for the instruction in EX

    assign md_wait  = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_muldiv && !md_valid;
    // The FPU handshake mirrors the M extension's: the launch is a one-cycle pulse
    // (`fp_started_r` keeps it from re-issuing while the unit runs) and EX holds the
    // instruction until `fp_valid`. FP loads and stores never enter the FPU — they
    // are ordinary memory accesses whose destination happens to be a F register.
     assign ex_fp_needs_fpu = ex_ctrl_r.is_fp && !ex_ctrl_r.is_load && !ex_ctrl_r.is_store
                             && !ex_fp_illegal && !ex_fp_rm_illegal;
    assign fp_wait  = ex_valid_r && !ex_ctrl_r.illegal && ex_fp_needs_fpu && !fp_valid;
    // The MEM stage holds its instruction until the access is done, which now
    // takes three steps: walk (if translation is on), drive, accept. A
    // misaligned access is a trap, not a stall: it never enters that sequence,
    // so waiting for `dmem_ready_i` would wedge the pipeline.
    assign mem_is_access = mem_valid_r && !mem_ctrl_r.illegal
                           && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && !lsu_misaligned;
    // ---- A extension: the two-beat AMO, the conditional store, and the
    //      reservation the lr/sc pair shares (E2-RV2 increment 3) --------------
    // The AMO's read beat is a plain read of the addressed window; its write beat
    // stores `amo_result_w` through the same cor_lsu lane logic a store uses. The
    // read value is latched (`amo_old_r`) because the D port is busy with the
    // write when the commit happens.
    assign mem_amo_read  = mem_ctrl_r.is_amo && !amo_write_r;
    assign mem_amo_write = mem_ctrl_r.is_amo && amo_write_r;
    assign amo_result_w  = eth_rv_pkg::amo_result(
        mem_ctrl_r.amo_op, amo_old_r, mem_store_data_r,
        (mem_ctrl_r.mem_size == eth_rv_pkg::SZ_WORD));
    // The store data the D port sees: rs2 for every store, the AMO's result on an
    // AMO's write beat. cor_lsu derives the beat data, the strobes and the
    // unshifted trace value from it, so both paths share one lane/offset rule.
    assign lsu_store_data = mem_amo_write ? amo_result_w : mem_store_data_r;
    // An sc whose reservation is gone performs NO access at all: Spike's
    // `store_conditional()` checks the reservation before it stores, and the
    // architectural effect is rd = 1 with no memory traffic and no bus beat.
    assign sc_have_resv = resv_valid_r && (resv_addr_r == mem_paddr_r);
    assign mem_beat_off = mem_ctrl_r.is_sc && !sc_have_resv;
    assign lr_beat      = (mem_phase_r == MEM_ACC) && mem_ctrl_r.is_lr && dmem_ready_i;
    // Spike's store_conditional() consumes the reservation exactly when the sc
    // COMPLETES: it yields on the store's way out (or, for a lost reservation,
    // without storing at all). It must NOT be keyed on "the sc is in MEM_ACC":
    // with a multi-cycle D port (memlat > 0, the AXI/DRAM path) MEM_ACC spans
    // several cycles, and clearing on the first of them made the sc lose its own
    // reservation before its store beat — it then took the lost-reservation path
    // and stored nothing (caught by the DiffTest on the slow D-port path).
    // A store beat answered with an error propagates BEFORE the yield, so it does
    // not consume the reservation either.
    assign sc_exec      = (mem_phase_r == MEM_ACC) && mem_ctrl_r.is_sc
                          && (mem_beat_off || (dmem_ready_i && !dmem_err_i));
    // The access is over when its LAST beat is accepted: an AMO's read beat is
    // not the last one, and a suppressed sc has no beat to wait for.
    assign mem_beat_last = !mem_amo_read;
    assign mem_acc_done  = (mem_phase_r == MEM_ACC)
                           && (mem_beat_off || (dmem_ready_i && mem_beat_last));
    assign mem_wait = mem_is_access && !mem_acc_done;
    // The rd value of every late-rd instruction (see `rd_late` in the package):
    // a load or lr writes the loaded value, an amo writes the OLD value (Spike's
    // `WRITE_RD(sext32(MMU.amo<...>))`), an sc writes 0 on success and 1 on
    // failure. All three are read at the commit edge, which is why they are one
    // signal: the WB register simply carries whichever this access produced.
    assign mem_late_rd = mem_ctrl_r.is_amo ? amo_old_r
                       : mem_ctrl_r.is_sc  ? {63'd0, !sc_have_resv}
                                           : mem_load_data;
    // WFI holds the MEM slot until `mip & mie` is non-zero — Spike's exact
    // "exit WFI" condition (processor.cc: take_pending_interrupt() clears
    // in_wfi as soon as `mip & mie` is non-zero, so a LOCALLY ENABLED source is
    // enough and the global mstatus.MIE plays no part). A hart with nothing
    // pending then waits, which on this single-hart SoC is exactly what the
    // idle path of OpenSBI/Linux needs.
    assign wfi_wait = mem_valid_r && !mem_ctrl_r.illegal && mem_ctrl_r.is_wfi
                      && (irq_pending == 12'd0);
    // A port ERROR RESPONSE is a trap too, and for the same reason: the beat is
    // accepted (`dmem_ready_i`) and the error arrives with it, so nothing waits.
    // An error beat means the platform cannot serve the access — an unmapped
    // address, a device that rejects it, or a DECERR/SLVERR bus response — and
    // the architectural answer is Spike's `trap_{load,store}_access_fault` with
    // `mtval` = the access address. Never a silent success, never a wedge.
    assign mem_xlate_fault = (mem_phase_r == MEM_WALK) && mmu_done
                             && !walk_is_fetch_r && (mmu_fault != 4'd0);
    // A suppressed sc drives no request, so a ready/error seen in that cycle is
    // the environment's answer to somebody else's access and must not be read as
    // this one's (the guard is what keeps "no beat" from becoming "failed beat").
    assign mem_beat_err = (mem_phase_r == MEM_ACC) && mem_is_access && !mem_beat_off
                          && dmem_ready_i && dmem_err_i;
    assign mem_access_err = mem_beat_err;
    // An FP load's destination is an FP register, `f0` included, so the hazard
    // rule differs per class: the integer side keeps the x0 exclusion and matches
    // only integer operands, the FP side matches FP operands (including `f0`) and
    // the fused forms' third source.
    assign load_use = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.rd_late && id_valid_r
                      && (ex_ctrl_r.fp_we
                          ? (((ex_rd_r == id_rs1_r) && id_ctrl_r.fp_rs1_fp)
                             || ((ex_rd_r == id_rs2_r) && id_ctrl_r.fp_rs2_fp)
                             || ((ex_rd_r == id_rs3_r)
                                 && eth_rv_pkg::fp_op_is_fma(id_ctrl_r.fp_op)))
                          : ((ex_rd_r != 5'd0)
                             && (((ex_rd_r == id_rs1_r) && !id_ctrl_r.fp_rs1_fp)
                                 || ((ex_rd_r == id_rs2_r) && !id_ctrl_r.fp_rs2_fp))));
    assign mem_misaligned = mem_valid_r && !mem_ctrl_r.illegal
                            && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && lsu_misaligned;

    // ---- SYSTEM legality under the current privilege ------------------------
    // The decoder classifies the encoding; whether the *current* mode may execute
    // it is decided here, exactly as Spike's require_privilege()/validate_csr():
    //   * mret requires M;
    //   * sret requires S (or M) and requires M when mstatus.TSR = 1;
    //   * a CSR access requires the CSR's own privilege ([9:8] of the address) not
    //     to exceed the current one, and a write to a read-only CSR (mhartid) is
    //     illegal even from M;
    //   * ecall is legal everywhere; only its cause depends on the mode.
    // In S-mode the comparison is against PRV_HS (2): Spike's S-mode *is* HS
    // without the H extension, so an S-owned CSR is one level below the current
    // mode. csr_priv = 2'b10 (H-owned) is never legal here — the address decode
    // rejects it.
    assign priv_eff = (csr_priv_r == eth_rv_pkg::PRV_S) ? 2'd2 : csr_priv_r;
    assign ex_csr_write_form = ex_ctrl_r.is_csr
                               && ((ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RW)
                                   || ((ex_ctrl_r.csr_imm ? (ex_imm_r[4:0] != 5'd0)
                                                          : (ex_rs1_r != 5'd0))));
    assign ex_csr_priv_ok = (ex_ctrl_r.csr_addr[9:8] != 2'b10)
                            && (ex_ctrl_r.csr_addr[9:8] <= priv_eff);
    assign ex_csr_illegal = ex_ctrl_r.is_csr
                            && (!ex_csr_priv_ok
                                || ((ex_ctrl_r.csr_addr[11:10] == 2'b11)
                                    && ex_csr_write_form)
                                || ((ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_SATP)
                                    && (csr_priv_r == eth_rv_pkg::PRV_S)
                                    && ((csr_mstatus_r & eth_rv_pkg::MSTATUS_TVM) != 64'd0)));
    // ---- F/D legality (Spike's `require_fp`, `validate_rm`, float_csr_t) ------
    // While `mstatus.FS` is Off every FP instruction — arithmetic, load/store,
    // move, compare, classify — is an illegal instruction, and so is any access to
    // `fflags`/`frm`/`fcsr`. A rounding-mode field of 5..7 (after the `frm`
    // substitution for the dynamic form) is illegal too; the compare/min/max/sgnj/
    // class/move forms carry no rm field and are exempt, exactly like Spike.
    assign ex_fp_rm_eff     = (ex_ctrl_r.fp_rm == 3'b111) ? csr_frm_r : ex_ctrl_r.fp_rm;
    assign ex_fp_illegal    = ex_ctrl_r.is_fp
                              && ((csr_mstatus_r & eth_rv_pkg::MSTATUS_FS)
                                  == eth_rv_pkg::MSTATUS_FS_OFF);
    assign ex_fp_rm_illegal = ex_ctrl_r.is_fp && ex_ctrl_r.fp_rm_used
                              && (ex_fp_rm_eff > 3'd4);
    assign ex_fp_csr_off    = ex_ctrl_r.is_csr
                              && eth_rv_pkg::csr_is_fp(ex_ctrl_r.csr_addr)
                              && ((csr_mstatus_r & eth_rv_pkg::MSTATUS_FS)
                                  == eth_rv_pkg::MSTATUS_FS_OFF);
    assign ex_mret_illegal = ex_ctrl_r.is_mret && (csr_priv_r != eth_rv_pkg::PRV_M);
    // TSR (mstatus bit 22): when set, sret is an M-only instruction. TVM
    // (bit 20) is what makes `sfence.vma` and `satp` M-only in S-mode
    // (Spike's require_privilege(TVM ? PRV_M : PRV_S)); in U-mode both are
    // illegal whatever TVM says, which is the same condition.
    assign ex_sret_illegal = ex_ctrl_r.is_sret
                             && ((csr_priv_r == eth_rv_pkg::PRV_U)
                                 || ((csr_priv_r == eth_rv_pkg::PRV_S) && csr_mstatus_r[22]));
    // sfence.vma is legal in M and in S, and illegal in U — and in S only when
    // TVM is set (Spike's `require_privilege(TVM ? PRV_M : PRV_S)`).
    assign ex_sfence_illegal = ex_ctrl_r.is_sfence
                               && ((csr_priv_r == eth_rv_pkg::PRV_U)
                                   || ((csr_priv_r == eth_rv_pkg::PRV_S)
                                       && ((csr_mstatus_r & eth_rv_pkg::MSTATUS_TVM) != 64'd0)));
    // wfi is a privileged instruction: U-mode wfi is an illegal instruction
    // (Spike's `require_privilege(PRV_S)`, from wfi.h's S-extension branch). The
    // privileged forms are legal in S and M, and `mstatus.TW` is NOT trapped on:
    // TW's trap exists to virtualize WFI for a hypervisor, this hart has no
    // hypervisor, and the phenomenon the bit guards (a wait the hart never leaves)
    // is a scheduling question for the kernel, not an architectural one.
    assign ex_wfi_illegal = ex_ctrl_r.is_wfi && (csr_priv_r == eth_rv_pkg::PRV_U);

    // ---- interrupt selection (Spike's take_interrupt/priority order) --------
    // pending = mip & mie; M-eligible = pending & ~mideleg while an M interrupt
    // can be taken (in any mode below M, or in M with mstatus.MIE); S-eligible =
    // pending & mideleg while an S interrupt can be taken (below S, or in S with
    // sstatus.SIE). The M set wins wholesale, and within a set Spike's priority
    // is MEI, MSI, MTI, SEI, SSI, STI. MEIP has no source in this platform (there
    // is no PLIC), so it stays 0 — exactly like the golden model's default.
    assign mip_eff = csr_mip_r
                     | (msip_i ? eth_rv_pkg::MIP_MSIP : 64'd0)
                     | (mtip_i ? eth_rv_pkg::MIP_MTIP : 64'd0)
                     | (meip_i ? eth_rv_pkg::MIP_MEIP : 64'd0);
    assign irq_pending   = mip_eff[11:0] & csr_mie_r[11:0];
    assign irq_m_enabled = (csr_priv_r != eth_rv_pkg::PRV_M) || csr_mstatus_r[3];
    assign irq_s_enabled = (csr_priv_r != eth_rv_pkg::PRV_S) || csr_mstatus_r[1];

    always_comb begin
        logic [11:0] m_elig;
        logic [11:0] s_elig;
        logic [11:0] sel;
        // The two eligibility sets are disjoint by construction (one takes
        // ~mideleg, the other mideleg), so the union IS the selection, and the
        // reduction below is "is anything deliverable".
        m_elig = irq_m_enabled ? (irq_pending & ~csr_mideleg_r[11:0]) : 12'd0;
        s_elig = irq_s_enabled ? (irq_pending &  csr_mideleg_r[11:0]) : 12'd0;
        sel      = m_elig | s_elig;
        irq_take = |sel;
        if      (sel[11]) irq_code = eth_rv_pkg::IRQ_MEI;
        else if (sel[3])  irq_code = eth_rv_pkg::IRQ_MSI;
        else if (sel[7])  irq_code = eth_rv_pkg::IRQ_MTI;
        else if (sel[9])  irq_code = eth_rv_pkg::IRQ_SEI;
        else if (sel[1])  irq_code = eth_rv_pkg::IRQ_SSI;
        else if (sel[5])  irq_code = eth_rv_pkg::IRQ_STI;
        else              irq_code = 4'd0;
    end

    // ---- exception detection -------------------------------------------
    // Instruction-side exceptions are recognised in EX: an unimplemented
    // encoding, an illegal SYSTEM operation (CSR privilege/read-only, mret/sret
    // in the wrong mode), ecall/ebreak, a control transfer to an odd address, or
    // a fetch the instruction port answered with an error (`ex_fault_r`, the same
    // class as a data-side error response — see `mem_access_err`). The misaligned
    // target check is structurally unreachable while IALIGN = 16 and JALR clears
    // bit 0 — it is kept so a future IALIGN = 32 config (or a JALR that stopped
    // masking) cannot silently fetch from a misaligned address.
    // Data-side exceptions are recognised in MEM. The older fault wins: MEM is
    // architecturally ahead of EX, so a misaligned data access is taken even when
    // the instruction behind it also faults.
    // A fetch-faulted instruction was never decoded (`ex_ctrl_r` is zeroed for
    // it), so the fault marker — not the (void) fetched bytes — decides. It still
    // needs `!ex_stall`, exactly like every other EX-side trap: the trap is taken
    // in the first cycle the instruction can leave EX.
    //
    // INTERRUPTS are checked one stage earlier in *time*: Spike calls
    // take_pending_interrupt() before it fetches each instruction, so an
    // interrupt pre-empts the next instruction before that instruction starts.
    // Here the instruction in EX is that "next instruction" — it is taken in the
    // cycle it can first leave EX, and `md_start` is suppressed in the same cycle,
    // so a mul/div is pre-empted before it starts rather than after it finishes.
    // A fetch fault is deliberately NOT pre-empted: the fetch already failed, and
    // in Spike that trap is raised at fetch time, before any later interrupt
    // check. A MEM-side trap outranks everything (its instruction is older).
    assign ex_target_misaligned = ex_valid_r && !ex_ctrl_r.illegal
                                  && (ex_fault_r == 4'd0) && ex_next_pc[0];
     assign ex_trap = ex_valid_r && !ex_stall
                     && ((ex_fault_r != 4'd0) || ex_ctrl_r.illegal || ex_ctrl_r.is_ecall
                         || ex_ctrl_r.is_ebreak || ex_target_misaligned
                         || ex_csr_illegal || ex_mret_illegal || ex_sret_illegal
                         || ex_sfence_illegal || ex_fp_illegal || ex_fp_rm_illegal
                         || ex_fp_csr_off || ex_wfi_illegal);
     assign ex_irq = ex_valid_r && (ex_fault_r == 4'd0) && !md_started_r
                    && !fp_started_r && !mem_trap && irq_take;
    assign mem_trap = mem_misaligned || mem_xlate_fault || mem_access_err;
    assign trap_is_irq = !mem_trap && ex_irq;
    assign trap_hit = mem_trap || ex_irq || ex_trap;
    assign trap_pc   = mem_trap ? mem_pc_r   : ex_pc_r;
    assign trap_insn = mem_trap ? mem_insn_r : ex_insn_r;

    always_comb begin
        // The fetch fault is checked first: a faulted fetch carries no valid
        // encoding, so nothing else about it may be interpreted. The cause is
        // whatever the fetch path decided: 1 for a port error response, 12 for a
        // translation fault, 1 again when the walk's own PTE read was refused.
        if (ex_fault_r != 4'd0) begin
            ex_cause = ex_fault_r;
        end else if (ex_ctrl_r.is_ecall) begin
            // Environment call: the cause names the mode that issued it.
            ex_cause = (csr_priv_r == eth_rv_pkg::PRV_M) ? eth_rv_pkg::CAUSE_ECALL_M
                       : (csr_priv_r == eth_rv_pkg::PRV_S) ? eth_rv_pkg::CAUSE_ECALL_S
                                                           : eth_rv_pkg::CAUSE_ECALL_U;
        end else if (ex_ctrl_r.is_ebreak) begin
            ex_cause = eth_rv_pkg::CAUSE_BREAKPOINT;
        end else if (ex_target_misaligned) begin
            ex_cause = eth_rv_pkg::CAUSE_INSN_MISALIGN;
        end else begin
            // Every remaining EX-side trap is an illegal instruction: an
            // unimplemented encoding, a CSR the current mode may not touch, a
            // write to a read-only CSR, or mret/sret in a mode that forbids it.
            ex_cause = eth_rv_pkg::CAUSE_ILLEGAL;
        end
    end

    always_comb begin
        // mtval: the faulting fetch address (access fault), the misaligned target
        // (fetch), the pc (breakpoint), zero (ecall) or the offending instruction
        // word (illegal) — Spike's exact choices.
        if (ex_fault_r != 4'd0) begin
            ex_trap_value = ex_pc_r;
        end else if (ex_ctrl_r.is_ebreak) begin
            ex_trap_value = ex_pc_r;
        end else if (ex_target_misaligned) begin
            ex_trap_value = ex_next_pc;
        end else if (ex_ctrl_r.is_ecall) begin
            ex_trap_value = 64'd0;
        end else begin
            ex_trap_value = {32'd0, ex_insn_r};
        end
    end

    // The MEM-side cause tells the two trap classes apart: misaligned (4/6) is
    // decided before the access is issued, an access fault (5/7) is the port's
    // error response to the issued access. Both report `mtval` = the address.
    // An interrupt carries its IRQ code with bit 63 set in the cause word and
    // `tval` = 0 (Spike: `trap_t::get_tval()` is 0 for every interrupt).
    // The MEM-side causes: misaligned (4/6) is decided before the access is
    // issued, a translation fault (13/15 for a page fault, 5/7 when the walk's
    // PTE read was refused) comes from the walker, and an access fault (5/7) is
    // the port's error response to the issued access. All three report
    // `mtval` = the VIRTUAL address the instruction named — the physical one
    // never reaches a CSR.
    assign trap_cause = mem_misaligned
                        ? (mem_ctrl_r.is_store ? eth_rv_pkg::CAUSE_STORE_MISALIGN
                                               : eth_rv_pkg::CAUSE_LOAD_MISALIGN)
                        : mem_xlate_fault
                          ? mmu_fault
                          : mem_access_err
                            ? (mem_ctrl_r.is_store ? eth_rv_pkg::CAUSE_STORE_ACCESS
                                                   : eth_rv_pkg::CAUSE_LOAD_ACCESS)
                            : trap_is_irq ? irq_code : ex_cause;
    assign trap_mtval = mem_trap ? mem_addr_r : (trap_is_irq ? 64'd0 : ex_trap_value);
    // Delegation: an exception is handled in S-mode when medeleg[i] is set, an
    // interrupt when mideleg[i] is set — but only for a trap taken below M-mode,
    // exactly like Spike's `state.prv <= PRV_S` guard (a trap raised while in
    // M-mode is never delegated, whatever the delegation registers say).
    assign trap_to_s  = (csr_priv_r != eth_rv_pkg::PRV_M)
                        && ((((trap_is_irq ? csr_mideleg_r : csr_medeleg_r)
                              >> trap_cause) & 64'd1) == 64'd1);
    // Vectoring: Spike vectors only interrupts (`(tvec & 1) && interrupt`), and
    // only on MODE bit 0. Exceptions always take the direct base.
    assign trap_target = ((trap_to_s ? csr_stvec_r : csr_mtvec_r) & ~64'd1)
                         + ((trap_is_irq && (trap_to_s ? csr_stvec_r[0] : csr_mtvec_r[0]))
                            ? {58'd0, trap_cause, 2'b00} : 64'd0);

     assign ex_stall    = md_wait || mem_wait || fp_wait || wfi_wait;
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
        // ... but only for a producer whose value was ready when it left EX: a
        // late-rd instruction (a load, or an lr/sc/amo) still has no value in MEM,
        // so its consumer waits for the WB bypass instead (the `rd_late` hazard).
        if (mem_valid_r && mem_ctrl_r.rf_we && !mem_ctrl_r.rd_late
            && (mem_rd_r != 5'd0) && (mem_rd_r == ex_rs1_r)) begin
            ex_fwd_a = mem_wb_pre_r;      // younger producer in MEM wins
        end
    end

    always_comb begin
        ex_fwd_b = ex_rs2_val_r;
        if (wb_valid_r && wb_ctrl_r.rf_we && (wb_rd_r != 5'd0) && (wb_rd_r == ex_rs2_r)) begin
            ex_fwd_b = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.rf_we && !mem_ctrl_r.rd_late
            && (mem_rd_r != 5'd0) && (mem_rd_r == ex_rs2_r)) begin
            ex_fwd_b = mem_wb_pre_r;
        end
    end

    always_comb begin
        ex_alu_a = ex_op1_eff;
        if (ex_ctrl_r.alu_a == OP_A_PC) begin
            ex_alu_a = ex_pc_r;
        end else if (ex_ctrl_r.alu_a == OP_A_ZERO) begin
            ex_alu_a = 64'd0;
        end
    end

    assign ex_alu_b = (ex_ctrl_r.alu_b == OP_B_IMM) ? ex_imm_r : ex_op2_eff;

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
            3'b000:  ex_taken = (ex_op1_eff == ex_op2_eff);
            3'b001:  ex_taken = (ex_op1_eff != ex_op2_eff);
            3'b100:  ex_taken = ($signed(ex_op1_eff) < $signed(ex_op2_eff));
            3'b101:  ex_taken = !($signed(ex_op1_eff) < $signed(ex_op2_eff));
            3'b110:  ex_taken = (ex_op1_eff < ex_op2_eff);
            3'b111:  ex_taken = !(ex_op1_eff < ex_op2_eff);
            default: ex_taken = 1'b0;
        endcase
    end

    always_comb begin
        if (ex_ctrl_r.is_mret) begin
            // mret/sret are not predicted as jumps (the decoder leaves them to the
            // fall-through), so the redirect below catches them exactly like any
            // other mispredicted transfer.
            ex_next_pc = csr_mepc_r;
        end else if (ex_ctrl_r.is_sret) begin
            ex_next_pc = csr_sepc_r;
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
    // instruction must not redirect to its own (possibly misaligned) target, and
    // a fetch-faulted instruction has no meaningful target at all: the trap
    // machinery owns the PC in that cycle.
    assign ex_redirect = ex_valid_r && !ex_ctrl_r.illegal && (ex_fault_r == 4'd0)
                         && !ex_target_misaligned && (ex_next_pc != ex_pred_r);

    // ---- writeback value before the memory access ----
     always_comb begin
        if (ex_fp_needs_fpu) begin
            ex_wb_pre = fp_result;         // FPU: arithmetic, compare, convert, move
        end else if (ex_ctrl_r.is_muldiv) begin
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
    // CSR file: M-mode set + the S-mode trap set (C14 §3, increment 6)
    // =====================================================================
    // `csr_mstatus_r` holds the whole mstatus register bar SD, which is derived
    // from FS on every read (Spike's adjust_sd()). `sstatus` is a *view* of the
    // same register, so a write through sstatus and a read through mstatus can
    // never disagree — the DiffTest leans on exactly that. The S-mode trap CSRs
    // (stvec/sepc/scause/stval/sscratch) are independent registers, and
    // mcounteren/scounteren have no state at all: with no Zicntr in the ISA the
    // golden model's write mask is zero, so a write is legal and drops.
    logic [1:0]  csr_priv_r;        // current privilege, PRV_U/PRV_S/PRV_M
    logic [63:0] csr_mstatus_r;
    logic [63:0] csr_mie_r;
    logic [63:0] csr_mtvec_r;
    logic [63:0] csr_mepc_r;
    logic [63:0] csr_mcause_r;
    logic [63:0] csr_mtval_r;
    logic [63:0] csr_mscratch_r;
    logic [63:0] csr_medeleg_r;
    logic [63:0] csr_mideleg_r;
    logic [63:0] csr_mip_r;         // software-writable pending bits only
    logic [63:0] csr_stvec_r;
    logic [63:0] csr_sepc_r;
    logic [63:0] csr_scause_r;
    logic [63:0] csr_stval_r;
    logic [63:0] csr_sscratch_r;
    // F extension: `fflags` and `frm` are independent registers (Spike's
    // float_csr_t over two sub-CSRs) and `fcsr` is a VIEW of both, so a write
    // through `fcsr` and a read through `fflags` + `frm` can never disagree.
    logic [4:0]  csr_fflags_r;
    logic [2:0]  csr_frm_r;

    logic [63:0] csr_rdata;
    logic [63:0] csr_wdata;
    logic [63:0] csr_mstatus_rd;
    logic [63:0] ex_csr_src;
    logic        ex_csr_we;
    logic        ex_mret_we;
    logic        ex_sret_we;
    logic [63:0] mstatus_wr;
    logic [1:0]  mpp_wr;
    logic        ex_sfence_we;

    // mstatus as read: the stored value with SD derived from FS (Spike sets SD on
    // every write of FS = 11 and clears it otherwise).
    assign csr_mstatus_rd = ((csr_mstatus_r & eth_rv_pkg::MSTATUS_FS) == eth_rv_pkg::MSTATUS_FS)
                            ? (csr_mstatus_r | eth_rv_pkg::MSTATUS_SD)
                            : (csr_mstatus_r & ~eth_rv_pkg::MSTATUS_SD);

    always_comb begin
        unique case (ex_ctrl_r.csr_addr)
            eth_rv_pkg::CSR_MSTATUS:   csr_rdata = csr_mstatus_rd;
            eth_rv_pkg::CSR_SSTATUS:   csr_rdata = csr_mstatus_rd & eth_rv_pkg::SSTATUS_RMASK;
            eth_rv_pkg::CSR_MISA:      csr_rdata = eth_rv_pkg::MISA_VALUE;
            eth_rv_pkg::CSR_MIE:       csr_rdata = csr_mie_r;
            // sie is mie masked by mideleg (Spike's generic accessor: ie_read =
            // mie & deleg_mask & read_mask, and only the S bits are delegable).
            eth_rv_pkg::CSR_SIE:       csr_rdata = csr_mie_r & csr_mideleg_r;
            eth_rv_pkg::CSR_MTVEC:     csr_rdata = csr_mtvec_r;
            eth_rv_pkg::CSR_STVEC:     csr_rdata = csr_stvec_r;
            eth_rv_pkg::CSR_MEDELEG:   csr_rdata = csr_medeleg_r;
            eth_rv_pkg::CSR_MIDELEG:   csr_rdata = csr_mideleg_r;
            // mcounteren/scounteren exist but have a zero write mask under
            // `--isa=rv64imc` (no Zicntr), so they read 0 whatever is written.
            eth_rv_pkg::CSR_MCOUNTEREN, eth_rv_pkg::CSR_SCOUNTEREN: csr_rdata = 64'd0;
            eth_rv_pkg::CSR_SATP:      csr_rdata = csr_satp_r;
            eth_rv_pkg::CSR_MIP:       csr_rdata = mip_eff;
            // sip sees the delegated pending bits: mip & mideleg (Spike's
            // mip_proxy read through the MIDELEG accessor; MVIP aliasing is off).
            eth_rv_pkg::CSR_SIP:       csr_rdata = mip_eff & csr_mideleg_r;
            eth_rv_pkg::CSR_MSCRATCH:  csr_rdata = csr_mscratch_r;
            eth_rv_pkg::CSR_SSCRATCH:  csr_rdata = csr_sscratch_r;
            eth_rv_pkg::CSR_MEPC:      csr_rdata = csr_mepc_r;
            eth_rv_pkg::CSR_SEPC:      csr_rdata = csr_sepc_r;
            eth_rv_pkg::CSR_MCAUSE:    csr_rdata = csr_mcause_r;
            eth_rv_pkg::CSR_SCAUSE:    csr_rdata = csr_scause_r;
            eth_rv_pkg::CSR_MTVAL:     csr_rdata = csr_mtval_r;
            eth_rv_pkg::CSR_STVAL:     csr_rdata = csr_stval_r;
            eth_rv_pkg::CSR_MHARTID:   csr_rdata = eth_rv_pkg::MHARTID_VALUE;
            eth_rv_pkg::CSR_FFLAGS:    csr_rdata = {59'd0, csr_fflags_r};
            eth_rv_pkg::CSR_FRM:       csr_rdata = {61'd0, csr_frm_r};
            eth_rv_pkg::CSR_FCSR:      csr_rdata = {56'd0, csr_frm_r, csr_fflags_r};
            default:                   csr_rdata = 64'd0;
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
    // (or an interrupt) traps.
     assign ex_csr_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_csr
                       && ((ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RW) || (ex_csr_src != 64'd0));
    assign ex_fp_csr_we = ex_csr_we && eth_rv_pkg::csr_is_fp(ex_ctrl_r.csr_addr);
    // `sfence.vma`: no translation state is cached (see cor_mmu), so the
    // instruction has nothing to invalidate beyond its privilege check. It
    // writes no register, so it must not execute as a CSR write either.
    assign ex_sfence_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_sfence;
    assign csr_wdata = (ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RW) ? ex_csr_src
                       : (ex_ctrl_r.csr_op == eth_rv_pkg::CSR_RS) ? (csr_rdata | ex_csr_src)
                                                                  : (csr_rdata & ~ex_csr_src);
    // The FP CSRs' write values: `fcsr` splits into frm[7:5] and fflags[4:0],
    // exactly Spike's composite_csr_t over the two sub-CSRs.
    logic [4:0] csr_wdata_fflags;
    logic [2:0] csr_wdata_frm;
    assign csr_wdata_fflags = csr_wdata[4:0] & eth_rv_pkg::FFLAGS_MASK;
    assign csr_wdata_frm    = ((ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_FCSR)
                               ? csr_wdata[7:5] : csr_wdata[2:0])
                              & eth_rv_pkg::FRM_MASK;
    // The FPU's own fflags accrual: an FP operation writes fflags only when it
    // RAISED a flag (SoftFloat's `raise_fp_exceptions` is `if (flags) write(...)`),
    // and a trap outranks it exactly like every other EX-side CSR write. The FPU
    // raises its flags on the cycle it completes, which is the cycle the
    // instruction leaves EX — so the register is read by the NEXT instruction.
    assign ex_fpu_ff_we = fp_valid && ex_valid_r && !trap_hit && (fp_fflags != 5'd0);
    assign ex_fpu_ff    = fp_fflags;
    // An instruction that writes an FP REGISTER sets mstatus.FS to Dirty — Spike
    // reaches it through `WRITE_FRD`, so it covers arithmetic, conversions, moves
    // and FP LAODS, but not FP stores or the integer-producing compares/fclass.
    // The FP CSR writes set it from their own write branch below.
    assign ex_fs_dirty = ex_valid_r && !ex_stall && !trap_hit
                         && ex_ctrl_r.is_fp && ex_ctrl_r.fp_we;

    // What this instruction reports to the commit trace as an `fflags`/`frm`
    // update: the new register value, or "no write". It is written here (EX) and
    // carried to the commit stage, so the trace record and the architectural
    // update are the same event.
    logic        ex_fflags_wr_we;
    logic [4:0]  ex_fflags_wr_val;
    logic        ex_frm_wr_we;
    logic [2:0]  ex_frm_wr_val;

    always_comb begin
        ex_fflags_wr_we  = ex_fpu_ff_we;
        ex_fflags_wr_val = csr_fflags_r | ex_fpu_ff;
        ex_frm_wr_we     = 1'b0;
        ex_frm_wr_val    = csr_frm_r;
        if (ex_fp_csr_we) begin
            ex_fflags_wr_we  = (ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_FFLAGS)
                               || (ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_FCSR);
            ex_fflags_wr_val = csr_wdata_fflags;
            ex_frm_wr_we     = (ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_FRM)
                               || (ex_ctrl_r.csr_addr == eth_rv_pkg::CSR_FCSR);
            ex_frm_wr_val    = csr_wdata_frm;
        end
    end

    // mstatus write value: the WARL mask, with MPP legalized (Spike's
    // legalize_privilege(): 2'b10 is not a mode this hart has, so it becomes U).
    assign mpp_wr = (csr_wdata[12:11] == 2'b10) ? eth_rv_pkg::PRV_U
                                                : csr_wdata[12:11];
    assign mstatus_wr = ((csr_mstatus_r & ~eth_rv_pkg::MSTATUS_WMASK)
                         | (csr_wdata & eth_rv_pkg::MSTATUS_WMASK
                            & ~eth_rv_pkg::MSTATUS_MPP))
                        | {51'd0, mpp_wr, 11'd0};

    // mret restores the interrupt-enable stack and returns to mepc; sret does the
    // same for the S-mode stack and sepc. Both drop MPRV (Spike clears it unless
    // the restored mode is M) and return to the least-privileged mode when the
    // saved field says U — with U implemented, "MPP <= U" means the field is
    // cleared. Legalizing the restored mode is what makes a stored 2'b10 return
    // to U rather than to a mode that does not exist.
    assign ex_mret_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_mret;
    assign ex_sret_we = ex_valid_r && !ex_stall && !trap_hit && ex_ctrl_r.is_sret;

    // =====================================================================

    // ---- M extension ----
    // An interrupt taken in this cycle pre-empts the instruction *before* it
    // starts, so it must also suppress the mul/div launch: Spike checks for
    // pending interrupts before executing, and a live multiplier would otherwise
    // finish work the golden model never started.
     assign md_start = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_muldiv
                      && !md_started_r && !ex_irq;
    assign fp_start = ex_valid_r && !ex_ctrl_r.illegal && ex_fp_needs_fpu
                      && !fp_started_r && !ex_irq;

    // =====================================================================
    // Sv39 walker: shared by the fetch path and the MEM stage
    // =====================================================================
    // Both clients translate only below M-mode, and only while satp.MODE is
    // Sv39. The MEM stage asks first (`mem_walk_start` is what stops the fetch
    // side from starting a second walk), and a walk already in flight is never
    // preempted — it is at most four cycles long, so a deferred fetch walk costs
    // nothing but time.
    assign mmu_on       = (csr_satp_r[63:60] == 4'd8);
    assign mmu_xlate    = mmu_on && (csr_priv_r != eth_rv_pkg::PRV_M);
    assign mmu_fetch_on = mmu_xlate;
    assign mmu_data_on  = mmu_xlate;

    // The MEM stage enters its sequence as soon as the walker is free: with
    // translation off it goes straight to the access, with it on it walks first.
    assign mem_start        = (mem_phase_r == MEM_IDLE) && mem_is_access && !mmu_busy;
    assign mem_walk_start   = mem_start && mmu_data_on;
    // ... and while it has an access in flight, the D port is exclusively its
    // own: a fetch walk started in that window would have to share the port, and
    // the mux below gives the walker priority, so the access would lose its
    // address/data (a store would go out as a read). The fetch side therefore
    // waits for the whole MEM sequence — it is never needed by an older
    // instruction, so deferring it costs cycles and nothing else.
    assign mem_owns_dport   = mem_valid_r && mem_is_access;
    assign fetch_walk_start = fetch_ready && !flush_all && mmu_fetch_on && !ft_valid_r
                              && !mmu_busy && !mem_owns_dport;
    assign mmu_start    = mem_walk_start || fetch_walk_start;
    assign mmu_vaddr    = mem_walk_start ? mem_addr_r : fetch_pc_r;
    assign mmu_acc      = mem_walk_start ? (mem_ctrl_r.is_store ? eth_rv_pkg::ACC_STORE
                                                                : eth_rv_pkg::ACC_LOAD)
                                         : eth_rv_pkg::ACC_FETCH;

    cor_mmu u_mmu (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .start_i    (mmu_start),
        .vaddr_i    (mmu_vaddr),
        .acc_i      (mmu_acc),
        .priv_s_i   (csr_priv_r == eth_rv_pkg::PRV_S),
        .sum_i      (csr_mstatus_r[18]),
        .mxr_i      (csr_mstatus_r[19]),
        .ppn_i      (csr_satp_r[43:0]),
        .busy_o     (mmu_busy),
        .done_o     (mmu_done),
        .paddr_o    (mmu_paddr),
        .fault_o    (mmu_fault),
        .pte_req_o  (mmu_pte_req),
        .pte_addr_o (mmu_pte_addr),
        .pte_ready_i(dmem_ready_i),
        .pte_rdata_i(dmem_rdata_i),
        .pte_err_i  (dmem_err_i)
    );

    cor_muldiv u_muldiv (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),
        .start_i (md_start),
        .op_i    (ex_ctrl_r.md_op),
        .a_i     (ex_op1_eff),
        .b_i     (ex_op2_eff),
        .result_o(md_result),
        .valid_o (md_valid)
    );
    // =====================================================================
    // F/D: the FP register file, its forwarding network and the FPU
    // =====================================================================
    // The FP registers are a SEPARATE 32-entry file with its own write port and its
    // own forwarding network: an FP producer must never forward into an integer
    // operand (or the other way round), which the `fp_we` class bit of each
    // pipeline stage selects. `f0` is an ordinary register, so there is no
    // hard-wired-zero rule on either the write or the bypass.
    logic [63:0] ex_fwd_a_fp;
    logic [63:0] ex_fwd_b_fp;
    logic [63:0] ex_fwd_c_fp;

    always_comb begin
        ex_fwd_a_fp = ex_fp_rs1_val_r;
        if (wb_valid_r && wb_ctrl_r.fp_we && (wb_rd_r == ex_rs1_r)) begin
            ex_fwd_a_fp = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.fp_we && !mem_ctrl_r.is_load
            && (mem_rd_r == ex_rs1_r)) begin
            ex_fwd_a_fp = mem_wb_pre_r;      // the younger producer wins
        end
    end

    always_comb begin
        ex_fwd_b_fp = ex_fp_rs2_val_r;
        if (wb_valid_r && wb_ctrl_r.fp_we && (wb_rd_r == ex_rs2_r)) begin
            ex_fwd_b_fp = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.fp_we && !mem_ctrl_r.is_load
            && (mem_rd_r == ex_rs2_r)) begin
            ex_fwd_b_fp = mem_wb_pre_r;
        end
    end

    always_comb begin
        ex_fwd_c_fp = ex_fp_rs3_val_r;
        if (wb_valid_r && wb_ctrl_r.fp_we && (wb_rd_r == ex_rs3_r)) begin
            ex_fwd_c_fp = wb_data_r;
        end
        if (mem_valid_r && mem_ctrl_r.fp_we && !mem_ctrl_r.is_load
            && (mem_rd_r == ex_rs3_r)) begin
            ex_fwd_c_fp = mem_wb_pre_r;
        end
    end

    // the operand's class is a property of the ENCODING (fcvt.d.w reads an integer
    // register, fcvt.w.d an FP one), so the mux is driven by the decode bits
    assign ex_op1 = ex_ctrl_r.fp_rs1_fp ? ex_fwd_a_fp : ex_fwd_a;
    assign ex_op2 = ex_ctrl_r.fp_rs2_fp ? ex_fwd_b_fp : ex_fwd_b;
    assign ex_op3 = ex_fwd_c_fp;

    // ---- the operands a STALLED EX instruction executes with ------------------
    // A stall freezes the EX slot but not the stages ahead of it: the MEM and WB
    // slots keep draining, so the forwarding network can lose the producer while
    // the stalled instruction is still in EX, and the re-evaluated operands fall
    // back to the stale register-file values the ID stage read. That is a real
    // divergence, not a corner case: `addi sp,sp,-64; sd ..,0(sp); sd ..,8(sp)`
    // puts the second store one MEM stall away from its producer (the first store
    // still finds it in MEM, the second needed it in WB, which the stall had
    // already drained into a bubble) — the DiffTest caught it on cor_atomic's
    // trap handler.
    //
    // The operands are therefore latched on the FIRST frozen cycle and used until
    // the slot advances: whatever the forwarding resolved in the cycle the stall
    // began is what the instruction must execute with. (The mul/div and FPU
    // launches read these same values in that cycle — each captures its inputs
    // with its own start strobe — so freezing them changes nothing there.)
    logic        ex_op_hold_r;
    logic [63:0] ex_op1_hold_r;
    logic [63:0] ex_op2_hold_r;
    logic [63:0] ex_op3_hold_r;
    logic [63:0] ex_op1_eff;
    logic [63:0] ex_op2_eff;
    logic [63:0] ex_op3_eff;

    assign ex_op1_eff = ex_op_hold_r ? ex_op1_hold_r : ex_op1;
    assign ex_op2_eff = ex_op_hold_r ? ex_op2_hold_r : ex_op2;
    assign ex_op3_eff = ex_op_hold_r ? ex_op3_hold_r : ex_op3;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ex_op_hold_r <= 1'b0;
        end else if (!(ex_valid_r && ex_stall)) begin
            // the slot flows, drains, or is claimed by a trap: nothing stays
            // frozen past this edge (a trap is taken out of a stalled slot, and
            // the handler's first instruction must not inherit its operands)
            ex_op_hold_r <= 1'b0;
        end else if (!ex_op_hold_r) begin
            ex_op_hold_r  <= 1'b1;
            ex_op1_hold_r <= ex_op1;
            ex_op2_hold_r <= ex_op2;
            ex_op3_hold_r <= ex_op3;
        end
    end

    // The FPU's third operand port is the ADDEND: rs3 for the fused forms, and the
    // second source for add/subtract (whose encode has no rs3 field at all — the
    // fused `b` port is the unit multiplier there).
    logic [63:0] fp_opc;
    assign fp_opc = ((ex_ctrl_r.fp_op == eth_rv_pkg::FP_ADD)
                     || (ex_ctrl_r.fp_op == eth_rv_pkg::FP_SUB)) ? ex_op2_eff : ex_op3_eff;

    cor_fpu u_fpu (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .start_i      (fp_start),
        .op_i         (ex_ctrl_r.fp_op),
        .single_i     (ex_ctrl_r.fp_single),
        .src_single_i (ex_ctrl_r.fp_src_single),
        .iw_i         (ex_ctrl_r.fp_iw),
        .rm_i         (ex_fp_rm_eff),
        .a_i          (ex_op1_eff),
        .b_i          (ex_op2_eff),
        .c_i          (fp_opc),
        .result_o     (fp_result),
        .fflags_o     (fp_fflags),
        .valid_o      (fp_valid)
    );

    // =====================================================================
    // MEM stage
    // =====================================================================
    logic [63:0] lsu_load_data;
    logic [63:0] lsu_wdata;
    logic [7:0]  lsu_wstrb;
    logic [7:0]  lsu_rmask;
    logic        lsu_misaligned;
    logic [63:0] mem_load_data;   // after the FLW NaN-box

    // FLW loads a binary32 into an F register, and every single-precision value in
    // an F register is NaN-boxed: the upper 32 bits are all ones (Spike's
    // `WRITE_FRD(f32(MMU.load<uint32_t>(…)))`). FLD needs no such step.
    assign mem_load_data = (mem_ctrl_r.fp_we && (mem_ctrl_r.mem_size == eth_rv_pkg::SZ_WORD))
                           ? {32'hffff_ffff, lsu_load_data[31:0]}
                           : lsu_load_data;

    cor_lsu u_lsu (
        .signed_i    (mem_ctrl_r.mem_signed),
        .size_i      (mem_ctrl_r.mem_size),
        .byte_off_i  (mem_addr_r[2:0]),
        .store_data_i(lsu_store_data),
        .rdata_i     (dmem_rdata_i),
        .load_data_o (lsu_load_data),
        .wdata_o     (lsu_wdata),
        .wstrb_o     (lsu_wstrb),
        .rmask_o     (lsu_rmask),
        .misaligned_o(lsu_misaligned)
    );

    // The D port is shared: the MEM stage drives its access in the MEM_ACC
    // phase, the walker drives its PTE reads, and the two are mutually exclusive
    // by construction (the MEM stage only issues in MEM_ACC, which is only
    // entered after its own walk has finished). The address the MEM stage
    // presents is PHYSICAL (`mem_paddr_r`); the byte lanes and the store data
    // come from the virtual address, whose low 12 bits — and therefore whose
    // lane and offset — the walk preserves.
    // An AMO's read beat is a read: `we`/`wdata`/`wstrb` stay low while the old
    // value is fetched, and only the second beat writes.
    assign dmem_we_core    = mem_ctrl_r.is_store && !mem_amo_read;
    assign dmem_addr_core  = mem_paddr_r;
    assign dmem_wdata_core = (mem_ctrl_r.is_store && !mem_amo_read) ? lsu_wdata : 64'd0;
    assign dmem_wstrb_core = (mem_ctrl_r.is_store && !mem_amo_read) ? lsu_wstrb : 8'd0;
    assign dmem_size_core  = mem_ctrl_r.mem_size;

    // Exactly one client at a time, and which one is a function of the phase
    // register alone: in MEM_ACC the port is the MEM stage's (its translated
    // address, data and strobes go out verbatim), otherwise it belongs to the
    // walker's PTE read. Stating the multiplexer on `mem_phase_r` rather than on
    // the walker's request is what lets the formal proof tie a committed record
    // to the transfer it came from: at the commit edge the phase IS MEM_ACC, so
    // `dmem_addr_o`/`dmem_wstrb_o` are exactly the values the record latched.
    // A failing sc is the one MEM_ACC cycle that drives nothing at all.
    // ... and the MEM stage drives it only while it really holds an access: an
    // EX-side trap empties `mem_valid_r` in the middle of a multi-cycle access,
    // and the phase then lingers for the one cycle it takes the state machine to
    // notice — driving the port from a dead slot would repeat the beat (or, after
    // a translation, hand the walker's request the stale address).
    assign dmem_req_o   = (mem_owns_dport && (mem_phase_r == MEM_ACC) && !mem_beat_off)
                          || mmu_pte_req;
    assign dmem_we_o    = (mem_phase_r == MEM_ACC) && dmem_we_core;
    assign dmem_addr_o  = (mem_phase_r == MEM_ACC) ? dmem_addr_core : mmu_pte_addr;
    assign dmem_wdata_o = (mem_phase_r == MEM_ACC) ? dmem_wdata_core : 64'd0;
    assign dmem_wstrb_o = (mem_phase_r == MEM_ACC) ? dmem_wstrb_core : 8'd0;
    // The access size describes the access, not the beat: it is what lets a
    // byte-register peripheral (the console UART) reject an access it cannot
    // serve, exactly as Spike's ns16550 rejects `len != reg_io_width`. A PTE
    // read is always a doubleword — Sv39 PTEs are 8 bytes and 8-byte aligned.
    assign dmem_size_o  = (mem_phase_r == MEM_ACC) ? dmem_size_core : eth_rv_pkg::SZ_DWRD;

    // =====================================================================
    // WB stage / commit + trace
    // =====================================================================
    logic wb_we;
    logic wb_fp_we;

    assign wb_we = wb_valid_r && wb_ctrl_r.rf_we && !wb_ctrl_r.illegal && (wb_rd_r != 5'd0);
    // ... and the FP half of the commit: `f0` is a real register, so the only guard
    // is "it was not rejected as illegal".
    assign wb_fp_we = wb_valid_r && wb_ctrl_r.fp_we && !wb_ctrl_r.illegal;

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
    cor_fp_regfile u_fp_regfile (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .we_i     (wb_fp_we),
        .waddr_i  (wb_rd_r),
        .wdata_i  (wb_data_r),
        .raddr_a_i(id_rs1_r),
        .raddr_b_i(id_rs2_r),
        .raddr_c_i(id_rs3_r),
        .rdata_a_o(id_fp_rs1_val),
        .rdata_b_o(id_fp_rs2_val),
        .rdata_c_o(id_fp_rs3_val)
    );

     assign rvfi_valid_o     = wb_valid_r;
    assign rvfi_order_o     = order_r;
    assign rvfi_pc_o        = wb_pc_r;
    assign rvfi_insn_o      = wb_insn_r;
    assign rvfi_rd_we_o     = wb_we || wb_fp_we;
    assign rvfi_rd_fp_o     = wb_fp_we;
    // ... and the FP state a commit reports: gated on the record being a real
    // commit, because the MEM/WB pipeline register keeps its old `we` while a
    // bubble passes through it.
    assign rvfi_fflags_we_o = wb_valid_r && wb_fflags_we_r;
    assign rvfi_fflags_o    = wb_fflags_r;
    assign rvfi_frm_we_o    = wb_valid_r && wb_frm_we_r;
    assign rvfi_frm_o       = wb_frm_r;
    assign rvfi_rd_addr_o   = wb_rd_r;
    assign rvfi_rd_wdata_o  = wb_data_r;
    // ... and a record reports a memory access only when the access really went
    // to the port: a failing `sc` commits (rd = 1) with no memory traffic at all,
    // which is what Spike's log shows for it (no `mem` field on the commit line).
    assign rvfi_mem_valid_o = wb_valid_r && !wb_ctrl_r.illegal
                              && (wb_ctrl_r.is_load || wb_ctrl_r.is_store)
                              && wb_ctrl_r.mem_ok;
    assign rvfi_mem_addr_o  = wb_addr_r;
    // The trace records what the golden model records: the address, the stored
    // value truncated to the access size and unshifted (Spike's `mem` field), and
    // the byte lanes of the aligned window at `addr & ~7` (RVFI) — the D-port's
    // own lane-shifted beat data is `dmem_wdata_o`/`dmem_wstrb_o` and is used to
    // drive the bus, not to describe the architectural effect.
    // An AMO reports its WRITE (address, result, write mask) — the "report the
    // write" convention the harness's golden normalizer shares: Spike logs the
    // read and the write of an AMO as two `mem` fields, and the canonical trace's
    // one-access record keeps the write, because rd (the old value) and this data
    // (the new one) together pin the whole read-modify-write.
    assign rvfi_mem_wdata_o = wb_ctrl_r.is_store ? wb_store_data_r : 64'd0;
    assign rvfi_mem_wmask_o = wb_wmask_r;
    assign rvfi_mem_rmask_o = wb_rmask_r;
    // ... and the PHYSICAL address the transfer actually went to: the trace
    // reports the virtual one (what Spike logs), so this port is what lets the
    // formal proof tie the record to the D-port transfer.
    assign rvfi_mem_paddr_o = wb_paddr_r;

    // The error strobe no longer latches (nothing halts): it pulses for one cycle
    // when a trap is taken and carries the architectural cause. `err_o` is the
    // valid strobe — CAUSE_INSN_MISALIGN is 0.
    assign err_o      = trap_hit;
    assign err_pc_o   = trap_pc;
    assign err_insn_o = trap_insn;
    assign err_code_o = trap_hit ? trap_cause : 4'd0;
    // The 4-bit cause code cannot carry bit 63, so the "this is an interrupt"
    // bit travels beside it: a trap is either an exception or an interrupt, and
    // only the former can be an access fault.
    assign err_irq_o  = trap_hit && trap_is_irq;

    // "an instruction left EX this cycle": the hart's executed-instruction count,
    // which is what Spike's CLINT counts to tick mtime (INSNS_PER_RTC_TICK).
    // Squashed instructions never appear here (an older MEM trap drops the EX
    // slot), and a mul/div that is still running is not counted until it leaves.
    assign step_o = ex_valid_r && !ex_stall && !mem_trap;

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
        end else if (fetch_take) begin
            fetch_pc_r <= fetch_pred_pc;
        end
    end

    // The I port sees a PHYSICAL address whenever the fetch is translated; the
    // virtual `fetch_pc_r` is what the pipeline, the trace and the trap CSRs
    // carry. Nothing is requested until the translation (or its fault) is in:
    // `imem_req_w` is low then, so a faulting fetch never reaches the port.
    assign imem_req_o  = imem_req_w;
    assign imem_addr_o = mmu_fetch_on ? {ft_page_r, fetch_pc_r[11:0]} : fetch_pc_r;
    // ---- CSR state: trap effects outrank a younger instruction's CSR write ----
    // Trap entry is split by destination: an M-mode trap writes mepc/mcause/mtval
    // and the M stack, a delegated trap writes sepc/scause/stval and the S stack.
    // Both write the *same* mstatus register — sstatus is a view of it — which is
    // what keeps the two stacks consistent, exactly like Spike's
    // nonvirtual_sstatus proxy. A trap in M-mode is never delegated.
    logic [63:0] trap_cause_word;
    assign trap_cause_word = eth_rv_pkg::cause_word(trap_is_irq, trap_cause);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            csr_priv_r     <= eth_rv_pkg::PRV_M;
            csr_mstatus_r  <= eth_rv_pkg::MSTATUS_XL;
            csr_mie_r      <= 64'd0;
            csr_mtvec_r    <= 64'd0;
            csr_mepc_r     <= 64'd0;
            csr_mcause_r   <= 64'd0;
            csr_mtval_r    <= 64'd0;
            csr_mscratch_r <= 64'd0;
            csr_medeleg_r  <= 64'd0;
            csr_mideleg_r  <= 64'd0;
            csr_mip_r      <= 64'd0;
            csr_stvec_r    <= 64'd0;
            csr_sepc_r     <= 64'd0;
            csr_scause_r   <= 64'd0;
            csr_stval_r    <= 64'd0;
             csr_sscratch_r <= 64'd0;
            csr_satp_r     <= 64'd0;
            csr_fflags_r   <= 5'd0;
            csr_frm_r      <= 3'd0;
        end else if (trap_hit) begin
            if (trap_to_s) begin
                // Delegated trap: the S-mode stack. SPIE <= SIE, SPP <= the mode
                // that trapped, SIE <= 0, and the hart enters S-mode.
                csr_sepc_r    <= trap_pc;
                csr_scause_r  <= trap_cause_word;
                csr_stval_r   <= trap_mtval;
                csr_mstatus_r <= (csr_mstatus_r
                                  & ~(eth_rv_pkg::MSTATUS_SIE | eth_rv_pkg::MSTATUS_SPIE
                                      | eth_rv_pkg::MSTATUS_SPP))
                                 | (csr_mstatus_r[1] ? eth_rv_pkg::MSTATUS_SPIE : 64'd0)
                                 | (csr_priv_r[0] ? eth_rv_pkg::MSTATUS_SPP : 64'd0);
                csr_priv_r    <= eth_rv_pkg::PRV_S;
            end else begin
                // M-mode trap: MPIE <= MIE, MPP <= the mode that trapped, MIE <= 0.
                csr_mepc_r    <= trap_pc;
                csr_mcause_r  <= trap_cause_word;
                csr_mtval_r   <= trap_mtval;
                csr_mstatus_r <= (csr_mstatus_r
                                  & ~(eth_rv_pkg::MSTATUS_MIE | eth_rv_pkg::MSTATUS_MPIE
                                      | eth_rv_pkg::MSTATUS_MPP))
                                 | (csr_mstatus_r[3] ? eth_rv_pkg::MSTATUS_MPIE : 64'd0)
                                 | ({62'd0, csr_priv_r} << 11);
                csr_priv_r    <= eth_rv_pkg::PRV_M;
            end
        end else if (ex_csr_we) begin
            unique case (ex_ctrl_r.csr_addr)
                eth_rv_pkg::CSR_MSTATUS: begin
                    csr_mstatus_r <= mstatus_wr;
                end
                // A write through sstatus touches only the S-owned fields, and the
                // SD/XL bits keep their derived/read-only values.
                eth_rv_pkg::CSR_SSTATUS: begin
                    csr_mstatus_r <= (csr_mstatus_r & ~eth_rv_pkg::SSTATUS_WMASK)
                                     | (csr_wdata & eth_rv_pkg::SSTATUS_WMASK);
                end
                eth_rv_pkg::CSR_MIE: begin
                    csr_mie_r <= csr_wdata & eth_rv_pkg::MIE_WMASK;
                end
                // sie is the S-mode view: only bits the delegation register hands
                // to S-mode can be written through it.
                eth_rv_pkg::CSR_SIE: begin
                    csr_mie_r <= (csr_mie_r & ~(csr_mideleg_r & eth_rv_pkg::MIE_WMASK))
                                 | (csr_wdata & csr_mideleg_r & eth_rv_pkg::MIE_WMASK);
                end
                eth_rv_pkg::CSR_MIP: begin
                    csr_mip_r <= (csr_mip_r & ~eth_rv_pkg::MIP_SW_WMASK)
                                 | (csr_wdata & eth_rv_pkg::MIP_SW_WMASK);
                end
                // sip can only set SSIP, and only while SSIP is delegated.
                eth_rv_pkg::CSR_SIP: begin
                    csr_mip_r <= (csr_mip_r & ~(csr_mideleg_r & eth_rv_pkg::MIP_SIP_WMASK))
                                 | (csr_wdata & csr_mideleg_r & eth_rv_pkg::MIP_SIP_WMASK);
                end
                eth_rv_pkg::CSR_MEDELEG: begin
                    csr_medeleg_r <= csr_wdata & eth_rv_pkg::MEDELEG_WMASK;
                end
                eth_rv_pkg::CSR_MIDELEG: begin
                    csr_mideleg_r <= csr_wdata & eth_rv_pkg::MIDELEG_WMASK;
                end
                eth_rv_pkg::CSR_MTVEC: begin
                    csr_mtvec_r <= csr_wdata & eth_rv_pkg::MTVEC_MASK;
                end
                eth_rv_pkg::CSR_STVEC: begin
                    csr_stvec_r <= csr_wdata & eth_rv_pkg::MTVEC_MASK;
                end
                eth_rv_pkg::CSR_MEPC: begin
                    csr_mepc_r <= csr_wdata & eth_rv_pkg::MEPC_MASK;
                end
                eth_rv_pkg::CSR_SEPC: begin
                    csr_sepc_r <= csr_wdata & eth_rv_pkg::MEPC_MASK;
                end
                eth_rv_pkg::CSR_MCAUSE: begin
                    csr_mcause_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_SCAUSE: begin
                    csr_scause_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_MTVAL: begin
                    csr_mtval_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_STVAL: begin
                    csr_stval_r <= csr_wdata;
                end
                eth_rv_pkg::CSR_MSCRATCH: begin
                    csr_mscratch_r <= csr_wdata;
                end
                // satp. Spike's CSR_SATP is the virtualized wrapper, whose
                // unlogged_write() keeps `read()` unless satp_valid() — so a mode
                // field this hart does not have leaves the WHOLE register (MODE,
                // ASID and PPN) unchanged, while a legal mode stores the value
                // verbatim. Sv39 (8) and Off (0) are the modes this hart has;
                // Spike's device tree advertises `riscv,sv57`, so it also accepts
                // 9 and 10 — the one documented boundary of this slice (see
                // verif/eth_rv/README.md "Sv39 translation").
                eth_rv_pkg::CSR_SATP: begin
                    if ((csr_wdata[63:60] == 4'd0) || (csr_wdata[63:60] == 4'd8)) begin
                        csr_satp_r <= csr_wdata;
                    end
                end
                 eth_rv_pkg::CSR_SSCRATCH: begin
                    csr_sscratch_r <= csr_wdata;
                end
                // The F-extension CSRs: `fflags` and `frm` are independent
                // registers, `fcsr` writes both halves. A write to any of them
                // also sets `mstatus.FS` to Dirty (float_csr_t::unlogged_write),
                // which the shared FS-dirty term below carries.
                eth_rv_pkg::CSR_FFLAGS: begin
                    csr_fflags_r <= csr_wdata_fflags;
                end
                eth_rv_pkg::CSR_FRM: begin
                    csr_frm_r <= csr_wdata_frm;
                end
                eth_rv_pkg::CSR_FCSR: begin
                    csr_fflags_r <= csr_wdata_fflags;
                    csr_frm_r    <= csr_wdata_frm;
                end
                 // misa is WARL read-only in practice, mcounteren/scounteren have a
                // zero write mask without Zicntr, and a write to the read-only
                // mhartid never gets here (it traps as an illegal instruction).
                default: ;
            endcase
        end else if (ex_fpu_ff_we) begin
            // an FP operation accrued flags: fflags |= raised (SoftFloat's
            // `raise_fp_exceptions`)
            csr_fflags_r <= csr_fflags_r | ex_fpu_ff;
        end else if (ex_fs_dirty) begin
            // any instruction that WRITES an FP register — arithmetic, conversion,
            // move, or an FP load — sets FS to Dirty (Spike's `dirty_fp_state`,
            // reached through `WRITE_FRD`). An FP STORE does not: Spike's
            // fsd/fsw only read the register.
            csr_mstatus_r <= csr_mstatus_r | eth_rv_pkg::MSTATUS_FS;
        end else if (ex_mret_we) begin
            // xRET: MIE <= MPIE, MPIE <= 1, MPP <= U (the least-privileged mode),
            // MPRV cleared unless the restored mode is M, and the hart returns to
            // the restored (legalized) mode.
            csr_mstatus_r <= (csr_mstatus_r
                              & ~(eth_rv_pkg::MSTATUS_MIE | eth_rv_pkg::MSTATUS_MPIE
                                  | eth_rv_pkg::MSTATUS_MPP | eth_rv_pkg::MSTATUS_MPRV))
                             | eth_rv_pkg::MSTATUS_MPIE
                             | (csr_mstatus_r[7] ? eth_rv_pkg::MSTATUS_MIE : 64'd0)
                             // MPRV survives only when the restored mode is M
                             // (Spike's mret.h: `if (prev_prv != PRV_M)`).
                             | ((csr_mstatus_r[12:11] == 2'b11)
                                ? (csr_mstatus_r & eth_rv_pkg::MSTATUS_MPRV) : 64'd0);
            csr_priv_r    <= (csr_mstatus_r[12:11] == 2'b10) ? eth_rv_pkg::PRV_U
                                                             : csr_mstatus_r[12:11];
        end else if (ex_sret_we) begin
            // sret: SIE <= SPIE, SPIE <= 1, SPP <= U, MPRV cleared, return to SPP.
            csr_mstatus_r <= (csr_mstatus_r
                              & ~(eth_rv_pkg::MSTATUS_SIE | eth_rv_pkg::MSTATUS_SPIE
                                  | eth_rv_pkg::MSTATUS_SPP | eth_rv_pkg::MSTATUS_MPRV))
                             | eth_rv_pkg::MSTATUS_SPIE
                             | (csr_mstatus_r[5] ? eth_rv_pkg::MSTATUS_SIE : 64'd0);
            csr_priv_r    <= csr_mstatus_r[8] ? eth_rv_pkg::PRV_S : eth_rv_pkg::PRV_U;
        end
    end


    // ---- the fetch translation register (Sv39) ------------------------------
    // `ft_page_r`/`ft_fault_r` describe the walk that resolved the CURRENT
    // `fetch_pc_r`; `walk_is_fetch_r` says which client the walk in flight
    // belongs to. The entry survives until the fetch pc moves (`fetch_take`), a
    // trap or redirect takes over (`flush_all`), or one of the translation's
    // inputs changes (a CSR write, mret/sret, sfence.vma) — a conservative list
    // rather than a tag comparison, because a stale translation is a silent
    // wrong fetch.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ft_valid_r      <= 1'b0;
            ft_page_r       <= 52'd0;
            ft_fault_r      <= 4'd0;
            fw_vaddr_r      <= 64'd0;
            walk_is_fetch_r <= 1'b0;
        end else begin
            if (mmu_start) begin
                walk_is_fetch_r <= fetch_walk_start;
                if (fetch_walk_start) begin
                    fw_vaddr_r <= mmu_vaddr;
                end
            end
            if (walk_done_fetch && (fw_vaddr_r == fetch_pc_r)
                && !(fetch_take || flush_all || ex_csr_we || ex_mret_we
                     || ex_sret_we || ex_sfence_we)) begin
                // the walk finished and still describes the pc being fetched
                ft_valid_r <= 1'b1;
                ft_page_r  <= mmu_paddr[63:12];
                // The walker's fault is mapped into the FETCH cause pair here:
                // a fetch walk either faulted its own translation (12) or had a
                // PTE read refused (1, which the walker publishes as the fetch
                // access fault). Written as a function of the walker's output —
                // rather than copied — so the cause register is provably one of
                // {0, 1, 12} by construction, which is what the formal fetch-fault
                // invariant needs.
                ft_fault_r <= (mmu_fault == eth_rv_pkg::CAUSE_INSN_PAGE)
                              ? eth_rv_pkg::CAUSE_INSN_PAGE
                              : ((mmu_fault == 4'd0) ? 4'd0 : eth_rv_pkg::CAUSE_INSN_ACCESS);
            end else if (walk_done_fetch || fetch_take || flush_all || ex_csr_we
                         || ex_mret_we || ex_sret_we || ex_sfence_we) begin
                // the pc moved (a redirect/trap), a CSR changed a translation
                // input, or the walk's answer is for an address the front-end has
                // already left: no translation is known for the current pc. The
                // clear outranks the set on purpose: a walk that completes in the
                // SAME cycle as a redirect would otherwise publish a page for a pc
                // the redirect has already replaced (the formal P10 invariant
                // `ft_valid_r -> fw_vaddr_r == fetch_pc_r` is exactly this).
                ft_valid_r <= 1'b0;
            end
        end
    end

    // ---- the MEM stage's access sequencing (Sv39) ---------------------------
    // MEM_IDLE -> (walk when translation is on) -> MEM_WALK -> MEM_ACC -> MEM_IDLE.
    // A walk that faults leaves the stage in MEM_IDLE (the trap has it); an
    // access that is not a load/store never leaves MEM_IDLE.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mem_phase_r <= MEM_IDLE;
            mem_paddr_r <= 64'd0;
            amo_write_r <= 1'b0;
            amo_old_r   <= 64'd0;
        end else if (mem_start) begin
            mem_phase_r <= mmu_data_on ? MEM_WALK : MEM_ACC;
            amo_write_r <= 1'b0;      // a new access always starts at its read beat
            if (!mmu_data_on) begin
                // no translation: the physical address IS the virtual one, and
                // recording it here keeps `mem_paddr_r` the single answer to
                // "where did this access go" for the trace and the bus alike
                mem_paddr_r <= mem_addr_r;
            end
        end else if ((mem_phase_r == MEM_WALK) && mmu_done && !walk_is_fetch_r) begin
            mem_paddr_r <= mmu_paddr;
            mem_phase_r <= (mmu_fault == 4'd0) ? MEM_ACC : MEM_IDLE;
        end else if ((mem_phase_r == MEM_ACC) && (mem_beat_off || dmem_ready_i)) begin
            // An AMO's read beat is followed by its write beat inside the SAME
            // MEM_ACC phase: the address, the size and the memoized translation
            // are already right, only the direction changes. An error response on
            // the read abandons the pair (the trap owns the pipeline), exactly
            // like every other access that is refused. The old value the read
            // returned is latched here — it is what the AMO's rd reports (a `.w`
            // form's `mem_signed` makes it the sign-extended word, which is the
            // `sext32` Spike's `WRITE_RD(...)` applies) and what the operation
            // combines with rs2.
            if (mem_is_access && mem_amo_read && !dmem_err_i && !mem_beat_off) begin
                amo_write_r <= 1'b1;
                amo_old_r   <= mem_load_data;
            end else begin
                amo_write_r <= 1'b0;
                mem_phase_r <= MEM_IDLE;
            end
        end else if (!mem_is_access) begin
            mem_phase_r <= MEM_IDLE;
        end
    end

    // ---- the lr/sc reservation (E2-RV2 increment 3) -------------------------
    // Spike's single-hart reservation is one (valid, physical address) pair:
    // `lr` sets it (`mmu_t::load_reserved` -> `load_reservation_address = paddr`),
    // `sc` consumes it (`store_conditional` compares, and then ALWAYS calls
    // `yield_load_reservation()`), and nothing else touches it — an ordinary
    // store or an AMO does NOT break a reservation in this model, which is what
    // the corpus pins (see verif/eth_rv/README.md "LR/SC: the boundary").
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            resv_valid_r <= 1'b0;
            resv_addr_r  <= 64'd0;
        end else begin
            if (lr_beat && !dmem_err_i) begin
                resv_valid_r <= 1'b1;
                resv_addr_r  <= mem_paddr_r;
            end
            if (sc_exec && !(mem_beat_err)) begin
                resv_valid_r <= 1'b0;
            end
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
            id_fault_r <= 4'd0;
            id_ctrl_r  <= '0;
             id_rd_r    <= 5'd0;
            id_rs1_r   <= 5'd0;
            id_rs2_r   <= 5'd0;
            id_rs3_r   <= 5'd0;
            id_imm_r   <= 64'd0;
        end else if (flush_all) begin
            id_valid_r <= 1'b0;
        end else if (ex_stall) begin
            id_valid_r <= id_valid_r;
        end else if (id_consumed || !id_valid_r) begin
            id_valid_r <= fetch_take;
            if (fetch_take) begin
                id_pc_r    <= fetch_pc_r;
                id_insn_r  <= fetch_insn;
                id_is_c_r  <= fetch_is_c;
                id_pred_r  <= fetch_pred_pc;
                id_fault_r <= fetch_fault_cause;
                // a faulted fetch has no encoding to decode: the control word is
                // zeroed so the fault marker alone decides what happens in EX
                id_ctrl_r  <= (fetch_fault_cause != 4'd0) ? '0 : dec_ctrl;
                 id_rd_r    <= dec_rd;
                id_rs1_r   <= dec_rs1;
                id_rs2_r   <= dec_rs2;
                id_rs3_r   <= dec_rs3;
                id_imm_r   <= dec_imm;
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
            ex_fault_r    <= 4'd0;
            ex_ctrl_r     <= '0;
             ex_rd_r       <= 5'd0;
            ex_rs1_r      <= 5'd0;
            ex_rs2_r      <= 5'd0;
            ex_rs3_r      <= 5'd0;
            ex_rs1_val_r  <= 64'd0;
            ex_rs2_val_r  <= 64'd0;
            ex_fp_rs1_val_r <= 64'd0;
            ex_fp_rs2_val_r <= 64'd0;
            ex_fp_rs3_val_r <= 64'd0;
            ex_imm_r      <= 64'd0;
            md_started_r  <= 1'b0;
            fp_started_r  <= 1'b0;
        end else begin
             if (md_start) begin
                md_started_r <= 1'b1;
            end else if (!ex_stall) begin
                md_started_r <= 1'b0;
            end
            // the FPU's launch pulse is a one-shot too
            if (fp_start) begin
                fp_started_r <= 1'b1;
            end else if (!ex_stall || trap_hit) begin
                fp_started_r <= 1'b0;
            end
            // A trap outranks the stall: an interrupt is taken in the EX slot's
            // first cycle (before the instruction starts), even while `ex_stall`
            // freezes the stage, and the pre-empted instruction must be discarded
            // rather than held. No other trap can coincide with a stall — a
            // MEM-side trap needs a completed beat, and an EX-side exception is
            // itself gated by `!ex_stall`.
            if (trap_hit) begin
                ex_valid_r <= 1'b0;
            end else if (ex_stall) begin
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
                    ex_fault_r   <= id_fault_r;
                    ex_ctrl_r    <= id_ctrl_r;
                     ex_rd_r      <= id_rd_r;
                    ex_rs1_r     <= id_rs1_r;
                    ex_rs2_r     <= id_rs2_r;
                    ex_rs3_r     <= id_rs3_r;
                    ex_rs1_val_r <= id_rs1_val;
                    ex_rs2_val_r <= id_rs2_val;
                    ex_fp_rs1_val_r <= id_fp_rs1_val;
                    ex_fp_rs2_val_r <= id_fp_rs2_val;
                    ex_fp_rs3_val_r <= id_fp_rs3_val;
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
            mem_fflags_we_r  <= 1'b0;
            mem_fflags_val_r <= 5'd0;
            mem_frm_we_r     <= 1'b0;
            mem_frm_val_r    <= 3'd0;
        end else if (trap_hit) begin
            // the trapping instruction (or the younger one behind a MEM trap) must
            // not enter MEM: neither may perform a memory access or commit. This
            // outranks the stall: a walk that faults has `mem_wait` asserted (the
            // stage is waiting for the walker), and if the stall won the trapping
            // access would simply be re-issued from the frozen slot.
            mem_valid_r <= 1'b0;
        end else if (mem_wait || wfi_wait) begin
            // ... and a wfi waiting for an interrupt freezes the stage the same
            // way, so the instruction it holds is still the wfi when the wait ends
            mem_valid_r <= mem_valid_r;
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
                mem_ctrl_r.fp_we      <= ex_ctrl_r.fp_we;
                mem_ctrl_r.is_amo     <= ex_ctrl_r.is_amo;
                mem_ctrl_r.is_lr      <= ex_ctrl_r.is_lr;
                mem_ctrl_r.is_sc      <= ex_ctrl_r.is_sc;
                mem_ctrl_r.amo_op     <= ex_ctrl_r.amo_op;
                mem_ctrl_r.rd_late    <= ex_ctrl_r.rd_late;
                mem_ctrl_r.is_wfi     <= ex_ctrl_r.is_wfi;
                mem_rd_r         <= ex_rd_r;
                mem_wb_pre_r     <= ex_wb_pre;
                mem_addr_r       <= ex_alu_res;      // load/store address
                 mem_store_data_r <= ex_op2_eff;      // store data (rs2, FP-aware)
                mem_fflags_we_r  <= ex_fflags_wr_we;
                mem_fflags_val_r <= ex_fflags_wr_val;
                mem_frm_we_r     <= ex_frm_wr_we;
                mem_frm_val_r    <= ex_frm_wr_val;
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
            wb_paddr_r      <= 64'd0;
            wb_store_data_r <= 64'd0;
            wb_wmask_r      <= 8'd0;
             wb_rmask_r      <= 8'd0;
            order_r         <= 64'd1;
            wb_fflags_we_r  <= 1'b0;
            wb_fflags_r     <= 5'd0;
            wb_frm_we_r     <= 1'b0;
            wb_frm_r        <= 3'd0;
        end else begin
            // a trapping MEM instruction must not reach WB: no commit record, no
            // register write and (for a store) no bus transaction
            wb_valid_r      <= (mem_wait || wfi_wait || mem_trap) ? 1'b0 : mem_valid_r;
            if (mem_valid_r && !mem_wait && !wfi_wait && !mem_trap) begin
                wb_pc_r         <= mem_pc_r;
                wb_insn_r       <= mem_insn_r;
                wb_ctrl_r.illegal  <= mem_ctrl_r.illegal;
                wb_ctrl_r.rf_we    <= mem_ctrl_r.rf_we;
                wb_ctrl_r.is_load  <= mem_ctrl_r.is_load;
                 wb_ctrl_r.is_store <= mem_ctrl_r.is_store;
                wb_ctrl_r.fp_we    <= mem_ctrl_r.fp_we;
                // ... and whether the access it describes really happened (a
                // failing sc commits without one): see rvfi_mem_valid_o.
                wb_ctrl_r.mem_ok   <= !mem_beat_off;
                wb_rd_r         <= mem_rd_r;
                 wb_data_r       <= mem_ctrl_r.rd_late ? mem_late_rd : mem_wb_pre_r;
                wb_addr_r       <= mem_addr_r;
                wb_paddr_r      <= mem_paddr_r;
                // Spike logs the stored data truncated to the access size, so the
                // trace carries exactly that (see the RVFI block above)
                wb_store_data_r <= eth_rv_pkg::store_wdata(lsu_store_data,
                                                           mem_ctrl_r.mem_size);
                 wb_wmask_r      <= mem_ctrl_r.is_store ? lsu_wstrb : 8'd0;
                wb_rmask_r      <= mem_ctrl_r.is_load  ? lsu_rmask : 8'd0;
                wb_fflags_we_r  <= mem_fflags_we_r;
                wb_fflags_r     <= mem_fflags_val_r;
                wb_frm_we_r     <= mem_frm_we_r;
                wb_frm_r        <= mem_frm_val_r;
            end
            if (wb_valid_r) begin
                order_r <= order_r + 64'd1;
            end
        end
    end

    // =====================================================================
    // Formal trace/commit contract (C14 §8 checkpoint 6; SymbiYosys/smtbmc,
    // NOT compiled for lint or sim).  Proven by eth_rv_core.sby.
    //
    // Every property below is a transition relation over (previous state,
    // current state, inputs) plus one-cycle `$past` lookbacks on registered
    // signals, so the proof holds by k-induction at unbounded depth.  The I/D
    // port environment is deliberately left free: the trace discipline must
    // hold for ANY compliant memory behaviour, so no assumption is made about
    // the two ports (an assumption here would weaken exactly the claim the
    // DiffTest relies on).  The cover task witnesses real retirements, real
    // traps and real load/store traffic, so the safety proof is non-vacuous.
    //
    // Property map (C14 §4/§5):
    //   P1  a record (rvfi_valid_o) exists only for an instruction that left
    //       MEM legally: not stalled on the D port, not trapped;
    //   P2  the record's payload IS that MEM instruction — so a squashed
    //       (flushed or never-executed) instruction can never be recorded;
    //   P3  retirement chain: a flush empties the ID/EX and IF/ID slots of its
    //       cycle, a trap empties MEM, a stalled D port freezes the MEM slot and
    //       its payload, and MEM is only filled from an EX slot that EX accepted
    //       (valid, not stalled, legal) — together with P1/P2 this is "no record
    //       for a flushed/never-retired instruction" and "rvfi_valid only with a
    //       legitimately retired instruction";
    //   P3b commit-path control invariant: an instruction is never decoded as
    //       both a load and a store (asserted at the decoder output and on the
    //       pipeline registers it feeds), which is what makes a record exactly
    //       one direction and the D-port mask discipline hold;
    //   P4  the trace ordinal advances exactly once per record — one record per
    //       retired instruction, in order.  It is stated relationally (rather
    //       than as "order >= 1") so it stays inductive at unbounded depth; the
    //       ordinal starts at 1 (the reset value), which the base case covers;
    //   P5  the recorded memory access is the D-port transfer that happened:
    //       the request was driven and accepted, the address/mask are the bus
    //       values, the mask is a legal byte-lane run of the addressed 8-byte
    //       beat, and the store bytes on the bus match the trace;
    //   P6  D-port write discipline: no write with a zero mask, the mask is a
    //       subset of the addressed beat, a read never writes;
    //   P7  a record never reports an architectural write to x0.
    // =====================================================================
`ifdef FORMAL
    // `formal_past_valid` seeds a deterministic start (reset held in the first
    // cycle) and makes every `$past` reference well-defined; assertions are
    // only checked out of reset.
    logic formal_past_valid = 1'b0;

    always_ff @(posedge clk_i) formal_past_valid <= 1'b1;
    always_ff @(posedge clk_i) if (!formal_past_valid) assume(!rst_ni);

    // Byte lanes of the addressed beat that the D-port access covers: the size
    // mask rotated to the access offset — the same convention as cor_lsu and
    // the RVFI masks (lanes of the window at `addr & ~7`).
    logic [7:0] dport_beat_lane_mask;

    always_comb begin
        case (mem_ctrl_r.mem_size)
            eth_rv_pkg::SZ_BYTE: dport_beat_lane_mask = 8'h01 << mem_addr_r[2:0];
            eth_rv_pkg::SZ_HALF: dport_beat_lane_mask = 8'h03 << mem_addr_r[2:0];
            eth_rv_pkg::SZ_WORD: dport_beat_lane_mask = 8'h0f << mem_addr_r[2:0];
            default:             dport_beat_lane_mask = 8'hff;
        endcase
    end

    // A legal byte-lane run of the addressed beat: 2^k contiguous lanes starting
    // at a multiple of 2^k (byte/half/word/dword at its natural alignment), i.e.
    // one of the fifteen masks a single-beat access can produce.
    function automatic logic legal_beat_mask(input logic [7:0] mask);
        legal_beat_mask = 1'b1;
        case (mask)
            8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80,
            8'h03, 8'h0c, 8'h30, 8'hc0,
            8'h0f, 8'hf0,
            8'hff: ;
            default: legal_beat_mask = 1'b0;
        endcase
    endfunction

    // True when the D-port beat carries, in the byte lanes the write mask
    // marks, exactly the unshifted stored value the commit trace reports; the
    // shift is the recorded access offset, so a lane/offset wiring error
    // makes this fail.
    function automatic logic store_bytes_match(input logic [63:0] beat,
                                              input logic [2:0]  off,
                                              input logic [63:0] trace_wdata,
                                              input logic [7:0]  wmask);
        store_bytes_match = (((beat >> {off, 3'b000}) ^ trace_wdata)
                             & {56'd0, (wmask >> off)}) == 64'd0;
    endfunction

    always_ff @(posedge clk_i) begin
        if (formal_past_valid && $past(rst_ni) && rst_ni) begin
            // ---- P1: a record exists only for an instruction that retired ----
            if (rvfi_valid_o) begin
                assert($past(mem_valid_r));
                assert(!$past(mem_wait));       // not stalled on the D port
                assert(!$past(mem_trap));       // not trapped in MEM
                // ... and the committed encoding was not rejected as illegal
                assert(!$past(mem_ctrl_r.illegal));
            end

            // ---- P2: the record is that MEM instruction ----------------------
            if (rvfi_valid_o) begin
                assert(rvfi_pc_o   == $past(mem_pc_r));
                assert(rvfi_insn_o == $past(mem_insn_r));
            end

            // ---- P3: retirement chain ---------------------------------------
            // a redirect or trap empties the ID/EX and IF/ID slots of its cycle
            // (the instruction being consumed there is squashed) ...
            if ($past(flush_all) && !$past(ex_stall)) begin
                assert(!ex_valid_r);
            end
            if ($past(flush_all)) begin
                assert(!id_valid_r);
            end
            // ... a MEM-side trap clears the MEM slot, so the trapping
            // instruction and everything behind it can never commit. An EX-side
            // trap (exception or interrupt) does NOT: the instruction in MEM is
            // OLDER and must keep committing — only the EX slot is dropped, which
            // the chain below states.
            if ($past(mem_trap)) begin
                assert(!mem_valid_r);
            end
            // ... and an EX-side trap drops the EX slot in the same cycle, even
            // when a stall was freezing it (an interrupt is taken in the EX
            // instruction's first cycle, before it starts), so the trapped
            // instruction can never be re-executed out of a held slot.
            if ($past(trap_hit) && !$past(mem_trap)) begin
                assert(!ex_valid_r);
            end
            // ... a stalled D-port access FREEZES the MEM slot, so the
            // instruction it holds across the stall is the same one. A trap
            // outranks the stall — a walk that faults stalls the stage AND takes
            // the instruction — so the freeze is stated for the cycles no trap
            // claims the slot.
            if ($past(mem_wait) && !$past(trap_hit)) begin
                assert(mem_valid_r == $past(mem_valid_r));
                assert(mem_pc_r    == $past(mem_pc_r));
                assert(mem_insn_r  == $past(mem_insn_r));
                assert(mem_addr_r  == $past(mem_addr_r));
                assert(mem_ctrl_r  == $past(mem_ctrl_r));
            end
            // ... and MEM is only ever FILLED from an EX slot that EX accepted:
            // a valid, un-stalled, non-illegal encoding (which is what rules a
            // squashed ID/EX instruction out of the commit path).
            if (mem_valid_r && !$past(mem_valid_r)) begin
                assert($past(ex_valid_r));
                assert(!$past(ex_stall));
                assert(!$past(ex_ctrl_r.illegal));
            end
            if (!mem_valid_r && !$past(mem_valid_r)) begin
                assert(!$past(ex_valid_r) || $past(ex_stall) || $past(ex_ctrl_r.illegal)
                       || $past(ex_ctrl_r.is_ecall) || $past(ex_ctrl_r.is_ebreak)
                       || $past(trap_hit));
            end
            if (ex_valid_r && !$past(ex_stall)) begin
                assert($past(id_consumed));
            end

            // ---- the fetch fault cause is one of the two a fetch can raise ---
            // A fetch either was refused by the port (cause 1) or faulted in its
            // own translation (cause 12); both a 1-bit flag and a 4-bit cause
            // would otherwise be free in the induction step, which is what makes
            // the P8 statement below inductive.
            // The walker publishes 0 or one of the six architectural causes (it
            // asserts the same of itself), and a fetch only ever sees the two a
            // fetch can raise — the chain from `mmu_fault` through `ft_fault_r`,
            // `id_fault_r` and `ex_fault_r` is what makes the P8 disjunction
            // below inductive rather than a free 4-bit value.
            assert((mmu_fault == 4'd0) || (mmu_fault == eth_rv_pkg::CAUSE_INSN_ACCESS)
                   || (mmu_fault == eth_rv_pkg::CAUSE_LOAD_ACCESS)
                   || (mmu_fault == eth_rv_pkg::CAUSE_STORE_ACCESS)
                   || (mmu_fault == eth_rv_pkg::CAUSE_INSN_PAGE)
                   || (mmu_fault == eth_rv_pkg::CAUSE_LOAD_PAGE)
                   || (mmu_fault == eth_rv_pkg::CAUSE_STORE_PAGE));
            assert((ft_fault_r == 4'd0) || (ft_fault_r == eth_rv_pkg::CAUSE_INSN_ACCESS)
                   || (ft_fault_r == eth_rv_pkg::CAUSE_INSN_PAGE));
            assert((id_fault_r == 4'd0) || (id_fault_r == eth_rv_pkg::CAUSE_INSN_ACCESS)
                   || (id_fault_r == eth_rv_pkg::CAUSE_INSN_PAGE));
            assert((ex_fault_r == 4'd0) || (ex_fault_r == eth_rv_pkg::CAUSE_INSN_ACCESS)
                   || (ex_fault_r == eth_rv_pkg::CAUSE_INSN_PAGE));
            // ... and while the EX slot holds a faulted fetch — and no older MEM
            // trap or interrupt claims the cycle — the reported cause IS that
            // fetch's cause, which is what makes the P8 statement about `$past`
            // inductive (a 4-bit cause register is otherwise free in the
            // induction step).
            if ((ex_fault_r != 4'd0) && !mem_trap) begin
                assert(trap_cause == ex_fault_r);
            end
            // ... and a translation fault is always one of the six causes a walk
            // can raise (the memory-side twin of the same invariant).
            assert((trap_cause == eth_rv_pkg::CAUSE_LOAD_MISALIGN)
                   || (trap_cause == eth_rv_pkg::CAUSE_STORE_MISALIGN)
                   || (trap_cause == eth_rv_pkg::CAUSE_INSN_ACCESS)
                   || (trap_cause == eth_rv_pkg::CAUSE_LOAD_ACCESS)
                   || (trap_cause == eth_rv_pkg::CAUSE_STORE_ACCESS)
                   || (trap_cause == eth_rv_pkg::CAUSE_ILLEGAL)
                   || (trap_cause == eth_rv_pkg::CAUSE_BREAKPOINT)
                   || (trap_cause == eth_rv_pkg::CAUSE_INSN_MISALIGN)
                   || (trap_cause == eth_rv_pkg::CAUSE_INSN_PAGE)
                   || (trap_cause == eth_rv_pkg::CAUSE_LOAD_PAGE)
                   || (trap_cause == eth_rv_pkg::CAUSE_STORE_PAGE)
                   || (trap_cause == 4'd8) || (trap_cause == 4'd9)
                   || (trap_cause == 4'd11)
                   || (trap_cause == eth_rv_pkg::IRQ_SSI)
                   || (trap_cause == eth_rv_pkg::IRQ_MSI)
                   || (trap_cause == eth_rv_pkg::IRQ_STI)
                   || (trap_cause == eth_rv_pkg::IRQ_MTI)
                   || (trap_cause == eth_rv_pkg::IRQ_SEI)
                   || (trap_cause == eth_rv_pkg::IRQ_MEI));

            // ---- P3b: commit-path control invariant ---------------------------
            // A record is a load or a store, never both, and the D-port mask
            // discipline rests on the same fact: no instruction is decoded as
            // both. Asserted at the decoder output — a purely combinational
            // contract over the fetched encoding — and on the pipeline registers
            // it feeds, which carries the invariant into MEM/WB inductively.
            assert(!(dec_ctrl.is_load && dec_ctrl.is_store));
            assert(!(id_ctrl_r.is_load && id_ctrl_r.is_store));
            assert(!(ex_ctrl_r.is_load && ex_ctrl_r.is_store));
            assert(!(mem_ctrl_r.is_load && mem_ctrl_r.is_store));
            assert(!(wb_ctrl_r.is_load && wb_ctrl_r.is_store));

            // ---- P4: one record per retirement, in order (see the property map)
            assert(rvfi_order_o == $past(rvfi_order_o) + {63'd0, $past(rvfi_valid_o)});

            // ---- P5: the recorded access is the D-port transfer that happened
            if (rvfi_mem_valid_o) begin
                assert($past(dmem_req_o));              // it really was driven
                assert($past(dmem_ready_i));            // and accepted
                // The record carries the VIRTUAL address (what Spike logs), the
                // bus the PHYSICAL one, and translation preserves the page offset.
                // The tie is to the REGISTER the bus was driven from, plus the
                // fact that the MEM stage owned the port in that cycle (the
                // walker's PTE read would otherwise be what `dmem_addr_o`
                // multiplexes): `rvfi_mem_paddr_o` is `wb_paddr_r`, which the
                // commit edge loaded from `mem_paddr_r` — the same value the D
                // port presented — so the recorded access IS the bus transfer.
                assert(rvfi_mem_paddr_o == $past(mem_paddr_r));
                // (The virtual record and the physical transfer share the page
                // offset — translation rewrites the page number — but that is a
                // property of the walker's output, not of the commit path, and it
                // is checked end to end by the DiffTest: the comparator matches
                // the virtual address against Spike while the memory model
                // serves the physical one, so a dropped offset shows up as a
                // value divergence. The proof keeps the tie it must: the record's
                // physical address IS the register the bus was driven from.)
                assert(rvfi_mem_wmask_o == $past(dmem_wstrb_o));
                // exactly one direction per record
                assert((rvfi_mem_wmask_o & rvfi_mem_rmask_o) == 8'd0);
                assert((rvfi_mem_wmask_o | rvfi_mem_rmask_o) != 8'd0);
                assert(wb_ctrl_r.is_store
                       ? ((rvfi_mem_wmask_o != 8'd0) && (rvfi_mem_rmask_o == 8'd0))
                       : ((rvfi_mem_rmask_o != 8'd0) && (rvfi_mem_wmask_o == 8'd0)));
                // the direction's mask is a legal byte-lane run of the beat
                assert(wb_ctrl_r.is_store ? legal_beat_mask(rvfi_mem_wmask_o)
                                          : legal_beat_mask(rvfi_mem_rmask_o));
                // the byte lanes the write mask marks carry, on the D-port beat,
                // exactly the unshifted stored value the trace reports
                assert(store_bytes_match($past(dmem_wdata_o), rvfi_mem_addr_o[2:0],
                                         rvfi_mem_wdata_o, rvfi_mem_wmask_o));
            end

            // ---- P6: D-port write discipline ---------------------------------
            if (dmem_req_o) begin
                assert(!dmem_we_o || (dmem_wstrb_o != 8'd0));            // no zero-mask write
                assert(!dmem_we_o || (dmem_wstrb_o == dport_beat_lane_mask));
                assert((dmem_wstrb_o & ~dport_beat_lane_mask) == 8'd0);  // subset of the beat
                assert(dmem_we_o || (dmem_wstrb_o == 8'd0));             // a read never writes
            end

            // ---- P7: a record never reports an INTEGER write to x0 -----------
            // x0 is hard-wired zero, so an integer record never names it. `f0` is
            // an ORDINARY register (F/D, E2-RV2 increment 2), so the rule is
            // class-dependent: a record may write f0.
            assert(!rvfi_rd_we_o || (rvfi_valid_o
                                     && (rvfi_rd_fp_o || (rvfi_rd_addr_o != 5'd0))));
            assert(!rvfi_rd_fp_o || rvfi_rd_we_o);   // the class bit implies a write

            // ---- P11: the FP record only ever accompanies a commit ------------
            // `fflags`/`frm` are reported by the instruction that wrote them, so a
            // report on a bubble (or in a record that does not exist) is a bug.
            assert(!rvfi_fflags_we_o || rvfi_valid_o);
            assert(!rvfi_frm_we_o || rvfi_valid_o);

            // ---- P9: the D port has exactly one client ------------------------
            // The walker's PTE read and the MEM stage's access are mutually
            // exclusive by construction; sharing the port would let the mux take
            // a store's write-enable and address away from it (a store would go
            // out as a read of the walker's address).
            assert(!(mmu_pte_req && (mem_phase_r == MEM_ACC)));
            // (No helper invariant is needed: the MEM_ACC state machine is gated
            // on `mem_is_access` — an EX-side trap can empty `mem_valid_r`
            // mid-access, and both the AMO's self-loop and the D-port request
            // below are held off while that is true, so a MEM_ACC that holds no
            // access cannot outlive its cycle. Stating "phase == MEM_ACC implies a
            // live access" as an assertion would instead be FALSE in exactly that
            // trap cycle.)
            // ... a walk that faults never leaves its instruction with a
            // translation it can use: the MEM slot is dropped by the trap, so the
            // trapping access cannot be re-issued from a frozen slot ...
            if ($past(mem_xlate_fault)) begin
                assert(!mem_valid_r);
                assert(!rvfi_valid_o);
                assert($past(trap_hit));
                assert($past(trap_mtval) == $past(mem_addr_r));
            end
            // ... and a fetch walk's result is only ever published for the address
            // it was started for: while `ft_valid_r` is set, the tagged address is
            // still the pc being fetched, so a speculative walk cannot hand its
            // page to a pc that a redirect has already moved to. (Stated as an
            // invariant on the register rather than as a next-cycle implication,
            // which is what makes it inductive.)
            if (ft_valid_r) begin
                assert(fw_vaddr_r == fetch_pc_r);
            end

            // ---- P8: an error response never retires --------------------------
            // A D-port beat answered with an error is an access fault: the
            // instruction cannot commit (no trace record) and the trap machinery
            // is what reports it, with the access address in `mtval`. That is the
            // "no silent success on an unmapped or rejected access" half of the
            // port contract, stated over the free I/D-port environment.
            if ($past(mem_access_err)) begin
                assert(!rvfi_valid_o);
                assert($past(trap_hit));
                assert(($past(trap_cause) == eth_rv_pkg::CAUSE_LOAD_ACCESS)
                       || ($past(trap_cause) == eth_rv_pkg::CAUSE_STORE_ACCESS));
                assert($past(trap_mtval) == $past(mem_addr_r));
            end
            // The instruction side of the same rule: a fetch the port answered
            // with an error never enters MEM (so it can never be committed) and
            // is reported as an instruction access fault at its own pc. Two
            // guards keep the statement about THIS trap: the payload registers of
            // a flushed EX slot keep their old value (only `ex_valid_r` gates
            // them, the convention everywhere in this file), so the slot must be
            // one EX actually holds; and an older MEM-side fault outranks it —
            // then the reported trap is the data one, which is what the design
            // says must happen.
            if ($past(ex_valid_r) && ($past(ex_fault_r) != 4'd0) && !$past(ex_stall)
                && !$past(mem_trap)) begin
                assert(!mem_valid_r);
                assert($past(ex_trap));
                assert($past(trap_hit));
                assert(($past(trap_cause) == eth_rv_pkg::CAUSE_INSN_ACCESS)
                       || ($past(trap_cause) == eth_rv_pkg::CAUSE_INSN_PAGE));
                assert($past(trap_mtval) == $past(ex_pc_r));
            end

            // ---- covers: witness the scenarios the safety proof speaks about -
            cover(rvfi_valid_o);
            cover(rvfi_valid_o && rvfi_rd_we_o);
            cover(rvfi_valid_o && !rvfi_rd_we_o);
            // F/D (E2-RV2 increment 2): the FP record classes
            cover(rvfi_valid_o && rvfi_rd_fp_o);
            cover(rvfi_valid_o && rvfi_rd_fp_o && (rvfi_rd_addr_o == 5'd0));
            cover(rvfi_valid_o && rvfi_fflags_we_o);
            cover(rvfi_valid_o && rvfi_frm_we_o);
            cover(rvfi_valid_o && rvfi_fflags_we_o && rvfi_frm_we_o);
            cover(rvfi_valid_o && rvfi_mem_valid_o && wb_ctrl_r.is_load);
            cover(rvfi_valid_o && rvfi_mem_valid_o && wb_ctrl_r.is_store);
            cover(rvfi_valid_o && rvfi_mem_valid_o && (rvfi_mem_wmask_o == 8'hff));
            cover(trap_hit && mem_trap);
            cover(trap_hit && ex_trap);
            cover(ex_redirect);
            cover(mem_wait);
            cover(rvfi_order_o == 64'd8);
            cover(mem_access_err);
            cover(trap_hit && (trap_cause == eth_rv_pkg::CAUSE_LOAD_ACCESS));
            cover(trap_hit && (trap_cause == eth_rv_pkg::CAUSE_STORE_ACCESS));
            cover(ex_valid_r && (ex_fault_r != 4'd0) && !ex_stall);
            // Sv39 (E2-RV2 increment 1): the walk, a translated record, and the
            // three page faults on both translation paths.
            cover(mmu_pte_req);
            cover(mmu_done && !mmu_fault);
            cover(mmu_start && fetch_walk_start);
            cover(mem_start && mmu_data_on);
            cover(trap_hit && (trap_cause == eth_rv_pkg::CAUSE_LOAD_PAGE));
            cover(trap_hit && (trap_cause == eth_rv_pkg::CAUSE_STORE_PAGE));
            cover(trap_hit && (trap_cause == eth_rv_pkg::CAUSE_INSN_PAGE));
            cover(mem_xlate_fault);
            cover(rvfi_valid_o && rvfi_mem_valid_o && (rvfi_mem_addr_o != rvfi_mem_paddr_o));
            // A extension + wfi (E2-RV2 increment 3): a committed AMO (the record
            // is its write beat) and a committed wfi (the hart waited for nothing
            // because a locally enabled source was already pending). Both are
            // stated as "the record, and the MEM slot the cycle before", which is
            // the commit relation the whole proof uses.
            cover(rvfi_valid_o && $past(mem_amo_write) && $past(dmem_ready_i));
            cover(rvfi_valid_o && $past(mem_ctrl_r.is_wfi));
            cover(wfi_wait);
            // ... and the lr/sc pair's two outcomes: an sc that stores and an sc
            // that reports a lost reservation without touching the bus.
            cover(mem_ctrl_r.is_lr && (mem_phase_r == MEM_ACC) && dmem_ready_i);
            cover(mem_ctrl_r.is_sc && (mem_phase_r == MEM_ACC) && !mem_beat_off);
            cover(mem_ctrl_r.is_sc && mem_beat_off);
        end
    end
`endif

endmodule
`default_nettype wire
