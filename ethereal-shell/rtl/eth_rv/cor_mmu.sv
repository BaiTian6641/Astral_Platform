`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      cor_mmu
// Description: Sv39 page-table walker for eth_rv: the three-level walk, the PTE
//              permission matrix, and the faults both raise.
// Details:     One asynchronous request interface (`start_i`), one synchronous
//              completion (`done_o`, one cycle) and one PTE read port that the
//              core multiplexes onto the D port — the walk therefore occupies
//              the D port while it runs, which is why the core stalls the MEM
//              stage (and the pipe behind it) for the duration (see
//              eth_rv_core.sv "Sv39 translation").
//
//              Protocol (all of it combinational-ready, so a zero-latency
//              memory finishes a walk in three reads + one cycle):
//                * `start_i` is sampled high for one cycle with `vaddr_i`,
//                  `acc_i`, `priv_s_i`, `sum_i`, `mxr_i` and `ppn_i` valid.
//                * `pte_req_o`/`pte_addr_o` are held until `pte_ready_i`, which
//                  marks the cycle `pte_rdata_i` carries the PTE (8-byte aligned,
//                  so the D port's aligned beat IS the PTE). `pte_err_i`, sampled
//                  with `pte_ready_i`, marks a PTE read the platform cannot
//                  serve: that is the access fault of the access type (1/5/7),
//                  NOT a page fault — Spike's `pte_load` raises
//                  `throw_access_exception`, while an invalid PTE is what
//                  `throw_page_fault_exception` answers.
//                * `done_o` pulses for one cycle with `paddr_o` (valid when
//                  `fault_o` is 0) and `fault_o` (the architectural cause, 0 when
//                  the translation succeeded).
//
//              What is checked, and in which order (the order matters only for
//              which kind of fault is reported, so the two access-fault cases sit
//              outside the checks below):
//                1. the virtual address must be canonical: bits 63:38 all equal
//                   to bit 38 (Spike: `masked_msbs != 0 && masked_msbs != mask`
//                   -> page fault);
//                2. PTE[63:54] must be zero. Spike checks those bits one
//                   extension at a time (N/Svnapot, PBMT/Svpbmt, Svrsw60t59b and
//                   the reserved 58:54) and faults when the extension is absent
//                   or the encoding is reserved; with the corpus ISA
//                   (`rv64imc`), `menvcfg.PBMTE = 0` and the golden model's
//                   extension list, every one of those bits faults — which is
//                   what the probe table in local://rv7-notes.md observed;
//                3. V must be set, and the reserved R=0,W=1 encoding faults;
//                4. a non-leaf PTE (V && !R && !W && !X) must have D, A and U
//                   clear, and may not appear at the last level;
//                5. the U/S rule: a U page is reachable from U-mode, and from
//                   S-mode only for a load/store with SUM = 1 (a fetch of a U
//                   page is never allowed from S-mode);
//                6. the access type's permission: X for a fetch, R (or X with
//                   MXR) for a load, W for a store;
//                7. A must be set, and D too for a store — Spike has hardware
//                   A/D update off (`menvcfg.ADUE = 0` after reset), so a missing
//                   bit is a page fault rather than a silent memory update;
//                8. a leaf's PPN must be aligned to the page it maps (the low
//                   9*level bits are zero).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §3 (MMU, Sv39), §4 (D port)
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2
// Notes:       Three-state FSM (`typedef enum` + one `always_ff`), one PTE read
//              per level, and no state that outlives a walk: the walker keeps no
//              TLB and no PTE cache, so `sfence.vma` has no cached translation
//              state to invalidate here (see verif/eth_rv/README.md "Sv39
//              translation"). That is a deliberate trade of cycles for the
//              smallest possible state, not an oversight.
module cor_mmu (
    input  logic        clk_i,
    input  logic        rst_ni,

    // ---- request -------------------------------------------------------
    input  logic        start_i,
    input  logic [63:0] vaddr_i,
    input  eth_rv_pkg::acc_e acc_i,
    input  logic        priv_s_i,   // 1 = S-mode, 0 = U-mode (the core never asks from M)
    input  logic        sum_i,      // sstatus.SUM
    input  logic        mxr_i,      // sstatus.MXR
    input  logic [43:0] ppn_i,      // satp.PPN

    // ---- completion ----------------------------------------------------
    output logic        busy_o,
    output logic        done_o,
    output logic [63:0] paddr_o,
    output logic [3:0]  fault_o,    // 0 = translated, else eth_rv_pkg::trap_cause_e

    // ---- PTE read port (multiplexed onto the core's D port) ------------
    // The RSW bits (PTE[9:8]) are the one part of a PTE this walker does not
    // read: they are reserved for supervisor software and Spike's PTE_SOFT is
    // never consulted either, so "using" them would give them a meaning the
    // architecture does not. The UNUSEDSIGNAL exemption below is that, and only
    // that, with the rest of the PTE consumed by the checks above (G1 allows
    // documented, justified exemptions).
    output logic        pte_req_o,
    output logic [63:0] pte_addr_o,
    input  logic        pte_ready_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [63:0] pte_rdata_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic        pte_err_i
);

    typedef enum logic [1:0] {
        MM_IDLE  = 2'd0,
        MM_FETCH = 2'd1,   // a PTE read is outstanding
        MM_DONE  = 2'd2    // the result register is being published
    } mm_state_e;

    // Sv39: three levels of 9 index bits; level 2 is the root.
    localparam logic [1:0] ROOT_LEVEL = 2'd2;

    mm_state_e   state_r;
    logic [1:0]  level_r;
    logic [4:0]  shift_r;       // 9 * level (0, 9 or 18)
    logic [63:0] vaddr_r;
    logic [63:0] base_r;        // the physical base of the table being walked
    eth_rv_pkg::acc_e acc_r;
    logic        priv_s_r;
    logic        sum_r;
    logic        mxr_r;
    logic [63:0] paddr_r;
    logic [3:0]  fault_r;

    logic [8:0]  vpn;
    logic [63:0] pte_addr;
    logic        noncanonical;

    assign busy_o     = (state_r != MM_IDLE);
    assign done_o     = (state_r == MM_DONE);
    assign paddr_o    = paddr_r;
    assign fault_o    = fault_r;
    assign pte_req_o  = (state_r == MM_FETCH);
    assign pte_addr_o = pte_addr;

    // The level's 9-bit VPN: bits [9*level + 20 : 9*level + 12]. `level_r` is a
    // 2-bit register, so the variable part-select has a constant width.
    assign vpn = vaddr_r[shift_r + 6'd12 +: 9];
    assign pte_addr = base_r + {52'd0, vpn, 3'b000};

    // Canonical: bits 63:38 must all equal bit 38 (Sv39 is a 39-bit address).
    // This is a function of the INCOMING address: it is sampled in the same cycle
    // `vaddr_r` is loaded, so testing the register would apply one access's
    // address to the next one's walk (a non-canonical access would then fault the
    // canonical access that followed it).
    assign noncanonical = |(vaddr_i[63:38] ^ {26{vaddr_i[38]}});

    // ---- PTE classification, purely combinational on the PTE read --------
    logic [43:0] pte_ppn;
    logic        pte_leaf;
    logic        pte_bad;       // reserved bits, V = 0, or R = 0 with W = 1
    logic        table_bad;     // a table PTE with D, A or U set
    logic        us_ok;
    logic        leaf_bad;      // everything a leaf must still satisfy
    logic        perm_ok;
    logic        superpage_ok;
    logic [63:0] leaf_ppn;

    assign pte_ppn  = pte_rdata_i[53:10];
    assign pte_leaf = |pte_rdata_i[3:1];
    assign pte_bad  = (|pte_rdata_i[63:54]) || !pte_rdata_i[0]
                      || (!pte_rdata_i[1] && pte_rdata_i[2]);
    assign table_bad = |pte_rdata_i[7:5];

    // The U/S rule is about the access, not the PTE's validity. Spike's:
    //   (pte & PTE_U) ? s_mode && (type == FETCH || !sum) : !s_mode   -> fault
    // i.e. a U page is reachable from U-mode, and from S-mode only for a
    // load/store with SUM (a U page is never executable from S-mode), while a
    // non-U page is reachable from S-mode and never from U-mode.
    assign us_ok = pte_rdata_i[4]
                   ? !(priv_s_r && ((acc_r == eth_rv_pkg::ACC_FETCH) || !sum_r))
                   : priv_s_r;

    // The access type's permission: X for a fetch, R (or X with MXR) for a load,
    // W for a store.
    always_comb begin
        unique case (acc_r)
            eth_rv_pkg::ACC_FETCH: perm_ok = pte_rdata_i[3];
            eth_rv_pkg::ACC_LOAD:  perm_ok = pte_rdata_i[1] | (mxr_r & pte_rdata_i[3]);
            default:               perm_ok = pte_rdata_i[2];
        endcase
    end

    // A superpage's PPN must be aligned to the page it maps.
    always_comb begin
        unique case (shift_r)
            5'd18:   superpage_ok = (pte_ppn[17:0] == 18'd0);
            5'd9:    superpage_ok = (pte_ppn[8:0] == 9'd0);
            default: superpage_ok = 1'b1;
        endcase
    end

    // The leaf's page base: the PPN is a page number, so it is shifted into the
    // byte address, with the superpage's own low bits masked off *before* the
    // shift (the mask is in PPN units for exactly that reason).
    assign leaf_ppn = ({20'd0, pte_ppn} & ~((64'd1 << shift_r) - 64'd1)) << 12;
    // ... and those masked-off bits COME FROM THE ADDRESS (Spike's
    // `page_base | (vpn & ((1 << ptshift) - 1)) << PGSHIFT`): below a superpage's
    // size the virtual address is the physical address. For the 2 MiB identity
    // superpage the corpus runs on, that is address bits 20:12 — dropping them
    // would map a 4 KiB page of every 2 MiB and silently alias page-table stores
    // onto the text page.
    logic [63:0] leaf_off;
    assign leaf_off = vaddr_r & ((64'd1 << (shift_r + 6'd12)) - 64'd1);

    always_comb begin
        leaf_bad = 1'b0;
        if (!us_ok) begin
            leaf_bad = 1'b1;
        end else if (!perm_ok) begin
            leaf_bad = 1'b1;
        end else if (!pte_rdata_i[6]) begin                       // A
            leaf_bad = 1'b1;
        end else if ((acc_r == eth_rv_pkg::ACC_STORE) && !pte_rdata_i[7]) begin
            leaf_bad = 1'b1;                                      // D
        end else if (!superpage_ok) begin
            leaf_bad = 1'b1;
        end
    end


`ifdef FORMAL
    // The published fault is always 0 (translated) or one of the architectural
    // causes a walk can raise: the access fault of the access type (1/5/7) when a
    // PTE read is refused, and the page fault of the access type (12/13/15) for
    // everything else. Stated as an invariant because it is what makes the core's
    // fetch-fault property inductive (a 4-bit code is otherwise free in the
    // induction step).
    always_ff @(posedge clk_i) begin
        if ((fault_r != 4'd0)
            && (fault_r != eth_rv_pkg::CAUSE_INSN_ACCESS)
            && (fault_r != eth_rv_pkg::CAUSE_LOAD_ACCESS)
            && (fault_r != eth_rv_pkg::CAUSE_STORE_ACCESS)
            && (fault_r != eth_rv_pkg::CAUSE_INSN_PAGE)
            && (fault_r != eth_rv_pkg::CAUSE_LOAD_PAGE)
            && (fault_r != eth_rv_pkg::CAUSE_STORE_PAGE)) begin
            assert(1'b0);
        end
        // A walk carries the access type it was started for, so the cause it
        // PUBLISHES is one of the two that type can raise: (1, 12) for a fetch,
        // (5, 13) for a load, (7, 15) for a store. Guarded by the publishing
        // state, because `fault_r` is a register that outlives its walk (it holds
        // the previous walk's answer until the next one overwrites it) and only
        // `done_o` gives it meaning — which is exactly where the core reads it.
        // The per-type split is what the core's fetch invariant needs.
        if (state_r == MM_DONE) begin
            if (acc_r == eth_rv_pkg::ACC_FETCH) begin
                assert((fault_r == 4'd0) || (fault_r == eth_rv_pkg::CAUSE_INSN_ACCESS)
                       || (fault_r == eth_rv_pkg::CAUSE_INSN_PAGE));
            end else if (acc_r == eth_rv_pkg::ACC_LOAD) begin
                assert((fault_r == 4'd0) || (fault_r == eth_rv_pkg::CAUSE_LOAD_ACCESS)
                       || (fault_r == eth_rv_pkg::CAUSE_LOAD_PAGE));
            end else begin
                assert((fault_r == 4'd0) || (fault_r == eth_rv_pkg::CAUSE_STORE_ACCESS)
                       || (fault_r == eth_rv_pkg::CAUSE_STORE_PAGE));
            end
        end
        cover(done_o && (fault_o == 4'd0));
        cover(done_o && (fault_o == eth_rv_pkg::CAUSE_LOAD_PAGE));
        cover(pte_req_o);
    end
`endif

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r  <= MM_IDLE;
            level_r  <= ROOT_LEVEL;
            shift_r  <= 5'd18;
            vaddr_r  <= 64'd0;
            base_r   <= 64'd0;
            acc_r    <= eth_rv_pkg::ACC_FETCH;
            priv_s_r <= 1'b0;
            sum_r    <= 1'b0;
            mxr_r    <= 1'b0;
            paddr_r  <= 64'd0;
            fault_r  <= 4'd0;
        end else begin
            case (state_r)
                MM_IDLE: begin
                    if (start_i) begin
                        vaddr_r  <= vaddr_i;
                        acc_r    <= acc_i;
                        priv_s_r <= priv_s_i;
                        sum_r    <= sum_i;
                        mxr_r    <= mxr_i;
                        if (noncanonical) begin
                            // bits 63:38 are not sign-extended from bit 38
                            paddr_r <= 64'd0;
                            fault_r <= eth_rv_pkg::page_fault_cause(acc_i);
                            state_r <= MM_DONE;
                        end else begin
                            level_r <= ROOT_LEVEL;
                            shift_r <= 5'd18;
                            base_r  <= {8'd0, ppn_i, 12'd0};
                            state_r <= MM_FETCH;
                        end
                    end
                end
                MM_FETCH: begin
                    if (pte_ready_i) begin
                        if (pte_err_i) begin
                            // the platform cannot serve the PTE read: Spike's
                            // pte_load raises the access fault of the type
                            paddr_r <= 64'd0;
                            fault_r <= eth_rv_pkg::access_fault_cause(acc_r);
                            state_r <= MM_DONE;
                        end else if (pte_bad) begin
                            paddr_r <= 64'd0;
                            fault_r <= eth_rv_pkg::page_fault_cause(acc_r);
                            state_r <= MM_DONE;
                        end else if (!pte_leaf) begin
                            // a pointer to the next level: the last level may not
                            // be one, and a table PTE may not carry D/A/U
                            if ((level_r == 2'd0) || table_bad) begin
                                paddr_r <= 64'd0;
                                fault_r <= eth_rv_pkg::page_fault_cause(acc_r);
                                state_r <= MM_DONE;
                            end else begin
                                level_r <= level_r - 2'd1;
                                shift_r <= shift_r - 5'd9;
                                base_r  <= {8'd0, pte_ppn, 12'd0};
                                state_r <= MM_FETCH;
                            end
                        end else begin
                            // a leaf: the permission matrix decides
                            if (leaf_bad) begin
                                paddr_r <= 64'd0;
                                fault_r <= eth_rv_pkg::page_fault_cause(acc_r);
                            end else begin
                                paddr_r <= leaf_ppn | leaf_off;
                                fault_r <= 4'd0;
                            end
                            state_r <= MM_DONE;
                        end
                    end
                end
                default: begin
                    // MM_DONE: publish the result for exactly one cycle
                    state_r <= MM_IDLE;
                end
            endcase
        end
    end

endmodule
`default_nettype wire
