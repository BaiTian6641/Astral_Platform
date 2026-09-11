`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_core
// Description: eth_rv RV64IMC in-order 5-stage core with a first-class RVFI commit-trace port.
// Details:     Pipeline: IF -> ID -> EX -> MEM -> WB (C14 §3), single issue, in
//              order, no MMU / FPU / CSR / trap path (RV-B v0 slice).
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
//
//              Static prediction (C14 §3): backward branches and direct jumps
//              are predicted taken; JALR/C.JR/C.JALR fall through. A misprediction
//              is a redirect from EX that flushes IF/ID, and the redirect is
//              derived from "actual next PC != the next PC carried down the
//              pipe", so it cannot be forgotten for one instruction class.
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
    // Control: stalls, flushes, hazard detection
    // =====================================================================
    logic err_r;
    logic [63:0] err_pc_r;
    logic [31:0] err_insn_r;
    logic [3:0]  err_code_r;

    logic md_wait;      // EX is a mul/div without its result yet
    logic mem_wait;     // MEM is waiting for dmem_ready_i
    logic load_use;     // EX holds a load that ID needs
    logic ex_stall;     // freeze ID/EX (and the front-end)
    logic front_stall;  // freeze IF/ID
    logic flush_all;    // discard IF/ID + ID/EX (redirect or error)
    logic id_consumed;  // ID moves into ID/EX this cycle

    logic        md_start;
    logic        md_valid;
    logic [63:0] md_result;
    logic        md_started_r;

    logic        ex_redirect;
    logic [63:0] ex_next_pc;
    logic        ex_illegal_hit;
    logic        mem_misaligned;
    logic        err_hit;
    logic [63:0] err_pc_nxt;
    logic [31:0] err_insn_nxt;
    logic [3:0]  err_code_nxt;

    assign md_wait  = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_muldiv && !md_valid;
    assign mem_wait = mem_valid_r && !mem_ctrl_r.illegal
                      && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && !dmem_ready_i;
    assign load_use = ex_valid_r && !ex_ctrl_r.illegal && ex_ctrl_r.is_load
                      && (ex_rd_r != 5'd0) && id_valid_r
                      && ((ex_rd_r == id_rs1_r) || (ex_rd_r == id_rs2_r));
    assign ex_illegal_hit = ex_valid_r && ex_ctrl_r.illegal;
    assign mem_misaligned = mem_valid_r && !mem_ctrl_r.illegal
                            && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && lsu_misaligned;
    assign err_hit      = ex_illegal_hit || mem_misaligned;
    // the older fault wins: MEM is architecturally ahead of EX, so a misaligned
    // data access is reported even when the instruction behind it is also bad.
    assign err_pc_nxt   = mem_misaligned ? mem_pc_r   : ex_pc_r;
    assign err_insn_nxt = mem_misaligned ? mem_insn_r : ex_insn_r;
    assign err_code_nxt = mem_misaligned ? ERR_MISALIGN : ERR_ILLEGAL;
    assign ex_stall    = md_wait || mem_wait;
    assign front_stall = ex_stall || load_use;
    assign flush_all   = ex_redirect || err_r;
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
        if (ex_ctrl_r.is_jump) begin
            // direct: pc + imm; indirect (jalr family): (rs1 + imm) with bit 0 cleared
            ex_next_pc = ex_ctrl_r.is_indirect ? (ex_alu_res & ~64'd1) : ex_alu_res;
        end else if (ex_ctrl_r.is_branch && ex_taken) begin
            ex_next_pc = ex_alu_res;
        end else begin
            ex_next_pc = ex_pc_r + ex_len;
        end
    end

    // "did the fetched-path assumption hold?" — one condition for every
    // instruction class, so no control transfer can escape the flush.
    assign ex_redirect = ex_valid_r && !ex_ctrl_r.illegal && (ex_next_pc != ex_pred_r);

    // ---- writeback value before the memory access ----
    always_comb begin
        if (ex_ctrl_r.is_muldiv) begin
            ex_wb_pre = md_result;
        end else if (ex_ctrl_r.wb_sel == WB_LINK) begin
            ex_wb_pre = ex_pc_r + ex_len;
        end else begin
            ex_wb_pre = ex_alu_res;
        end
    end

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
    logic [7:0]  lsu_lane_mask;
    logic        lsu_misaligned;

    cor_lsu u_lsu (
        .signed_i    (mem_ctrl_r.mem_signed),
        .size_i      (mem_ctrl_r.mem_size),
        .byte_off_i  (mem_addr_r[2:0]),
        .store_data_i(mem_store_data_r),
        .rdata_i     (dmem_rdata_i),
        .load_data_o (lsu_load_data),
        .wdata_o     (lsu_wdata),
        .wstrb_o     (lsu_lane_mask),
        .misaligned_o(lsu_misaligned)
    );

    assign dmem_req_o   = mem_valid_r && !mem_ctrl_r.illegal
                          && (mem_ctrl_r.is_load || mem_ctrl_r.is_store) && !lsu_misaligned;
    assign dmem_we_o    = mem_ctrl_r.is_store;
    assign dmem_addr_o  = mem_addr_r;
    assign dmem_wdata_o = mem_ctrl_r.is_store ? lsu_wdata : 64'd0;
    assign dmem_wstrb_o = mem_ctrl_r.is_store ? lsu_lane_mask : 8'd0;

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
    assign rvfi_mem_wdata_o = wb_store_data_r;
    assign rvfi_mem_wmask_o = wb_wmask_r;
    assign rvfi_mem_rmask_o = wb_rmask_r;

    assign err_o      = err_r;
    assign err_pc_o   = err_pc_r;
    assign err_insn_o = err_insn_r;
    assign err_code_o = err_r ? err_code_r : ERR_NONE;

    // =====================================================================
    // Sequential
    // =====================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            fetch_pc_r <= RESET_PC;
        end else if (ex_redirect) begin
            fetch_pc_r <= ex_next_pc;
        end else if (fetch_hit) begin
            fetch_pc_r <= fetch_pred_pc;
        end
    end

    assign imem_req_o  = !flush_all && !ex_stall && (id_consumed || !id_valid_r);
    assign imem_addr_o = fetch_pc_r;
    assign fetch_hit   = imem_req_o && imem_ready_i;
    // ---- error latch: an illegal/unimplemented encoding is never retired ----
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            err_r      <= 1'b0;
            err_pc_r   <= 64'd0;
            err_insn_r <= 32'd0;
            err_code_r <= ERR_NONE;
        end else if (err_hit && !err_r) begin
            err_r      <= 1'b1;
            err_pc_r   <= err_pc_nxt;
            err_insn_r <= err_insn_nxt;
            err_code_r <= err_code_nxt;
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
        end else begin
            mem_valid_r <= ex_valid_r && !ex_stall && !ex_ctrl_r.illegal;
            if (ex_valid_r && !ex_stall) begin
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
            wb_valid_r      <= mem_wait ? 1'b0 : mem_valid_r;
            if (mem_valid_r && !mem_wait) begin
                wb_pc_r         <= mem_pc_r;
                wb_insn_r       <= mem_insn_r;
                wb_ctrl_r.illegal  <= mem_ctrl_r.illegal;
                wb_ctrl_r.rf_we    <= mem_ctrl_r.rf_we;
                wb_ctrl_r.is_load  <= mem_ctrl_r.is_load;
                wb_ctrl_r.is_store <= mem_ctrl_r.is_store;
                wb_rd_r         <= mem_rd_r;
                wb_data_r       <= mem_ctrl_r.is_load ? lsu_load_data : mem_wb_pre_r;
                wb_addr_r       <= mem_addr_r;
                wb_store_data_r <= mem_store_data_r;
                wb_wmask_r      <= mem_ctrl_r.is_store ? lsu_lane_mask : 8'd0;
                wb_rmask_r      <= mem_ctrl_r.is_load  ? lsu_lane_mask : 8'd0;
            end
            if (wb_valid_r) begin
                order_r <= order_r + 64'd1;
            end
        end
    end

endmodule
`default_nettype wire
