`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_plic
// Description: Platform-Level Interrupt Controller for the eth_rv SoC: the
//              register map, arbitration and M/S context outputs Spike's
//              `plic_t` models, at Spike's addresses (riscv/plic.cc).
// Details:     WHY THIS EXISTS (E2-RV2 G7): a supervisor-mode hart cannot receive
//              a standard external interrupt without a hardware source for
//              `mip.SEIP` — the bit is writable from `mip` but a device line has
//              nowhere to land — and with no PLIC there is no `interrupts-extended`
//              S context for a kernel's driver to attach to. This module is that
//              source: its S context drives the hart's `seip_i`, its M context the
//              existing `meip_i`.
//
//              REGISTER MAP (base + offset; word accesses only — see WIDTHS):
//
//                0x000000 + 4*id            priority[id]        id in 1..NDEV
//                0x001000 + 4*id            pending[id]         read-only
//                0x002000 + 0x80*ctx + 4*w  enable[ctx][w]      w < NUM_ID_WORDS
//                0x200000 + 0x1000*ctx + 0  threshold[ctx]
//                0x200000 + 0x1000*ctx + 4  claim / complete
//
//              Two contexts, in Spike's order for a single hart with S enabled:
//              context 0 is M (``MIP.MEIP``), context 1 is S (``MIP.SEIP``). The
//              module is deliberately sized to that one-hart M+S configuration,
//              which is what `eth_rv.core.yaml` declares; a second hart would add
//              contexts to the same algorithm and nothing else.
//
//              THE SEMANTICS ARE THE GOLDEN MODEL'S, INCLUDING ITS QUIRKS. They
//              were probed against the pinned Spike before this file was written
//              (`local://rv11-plic-notes.md` §1.1 records the table and the
//              evidence), because every one of them is program-visible and so a
//              DiffTest compares them:
//
//                * priority is 4 bits (`PLIC_PRIO_BITS`), so a `sw -1` reads back
//                  0xF; priority[0] and priority[id > NDEV] read 0 and swallow
//                  writes without faulting.
//                * the pending word is read-only (a store to it is dropped) and a
//                  read is the OR of every context's pending bits.
//                * an enable write masks source 0's bit off (`sw -1` reads back
//                  0xFFFFFFFE), and a write to an enable word past the configured
//                  sources is ignored — neither faults.
//                * the arbitration uses the priority LATCHED with the pending bit
//                  (Spike's `pending_priority` per context), never the current
//                  priority register: a source that becomes pending while its
//                  priority is 0 stays masked after the program raises the
//                  priority, until its enable bit is written again. That is not a
//                  bug to fix — it is what the golden stream contains, and
//                  `cor_plic` pins it.
//                * the winner is the highest latched priority among pending,
//                  unclaimed sources; ties go to the LOWEST id, which the chain
//                  below produces by walking ids in ascending order with a strict
//                  `>` comparison — `context_best_pending`'s exact rule.
//                * the threshold masks `prio <= threshold`, so priority 0 is never
//                  delivered.
//                * a claim READ returns the winner and marks it claimed (the
//                  context's line drops although the source is still high); a
//                  second claim returns 0; a COMPLETE write clears the claim, so a
//                  still-asserting level-triggered source re-raises the line. The
//                  level can only be cleared by clearing the source.
//                * a source's level change updates only the FIRST context, in
//                  M-then-S order, that has the source enabled (Spike's
//                  `set_interrupt_level`). With both contexts enabled one of them
//                  therefore keeps a stale pending bit when the level falls;
//                  `cor_plic` pins that, and it is why the corpus enables one
//                  context at a time when it wants a deterministic owner.
//                * a software-written `mip.SEIP` is NOT this device's bit: Spike
//                  keeps the software bit in `mvip` and ORs it into `mip`'s read,
//                  so the PLIC line can neither set nor clear it (probed: a
//                  software SEIP survives a `context_update` that drops the line).
//                  `eth_rv_core` therefore models SEIP as "software bit OR
//                  `seip_i`", which is the same composition.
//
//              WIDTHS: only 4- and 8-byte accesses are served; anything narrower
//              is answered with `err_o` (the architectural access fault Spike
//              raises when its device returns false for `reg_io_width != len`), a
//              reserved context offset reads 0 but its WRITE faults, and a context
//              index the configuration does not have faults in both directions. An
//              address whose access would leave the window is not claimed at all —
//              `sel_o` stays low and the D-port decoder answers it (a fault, since
//              no region owns it).
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV2 increment 6 (S5): PLIC with M and S contexts
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (MMIO via the D port),
//              §8 checkpoint 5/6 (the devices a usable Linux needs) ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2, §5 (SoC map) ·
//              ethereal-shell/verif/eth_rv/README.md ("PLIC and the S-mode SEI path")
// Notes:       Combinational single-cycle slave like the console UART and the
//              CLINT: every request is answered in the cycle it is made, with or
//              without an error. The arbitration is a generate chain over source
//              ids (no procedural loops); the per-context state updates are
//              vector operations, so one `always_ff` per context carries them all.
module eth_rv_plic #(
    parameter logic [63:0] BASE      = 64'h0000_0000_0c00_0000,  // Spike PLIC_BASE
    parameter logic [63:0] PLIC_SIZE = 64'h0000_0000_0100_0000,  // Spike PLIC_SIZE (16 MiB)
    parameter int unsigned NDEV      = 31,                       // interrupt sources (ids 1..NDEV)
    parameter int unsigned PRIO_BITS = 4                         // Spike PLIC_PRIO_BITS
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // ---- core D-port slave (64-bit aligned beat, held until ready) ----
    input  logic        req_i,
    input  logic        we_i,
    input  logic [63:0] addr_i,
    input  logic [63:0] wdata_i,
    input  logic [1:0]  size_i,     // eth_rv_pkg::mem_size_e of the access
    output logic        sel_o,      // this access is inside the PLIC window
    output logic [63:0] rdata_o,    // the bytes of the addressed beat
    output logic        err_o,      // with sel_o: the access is an ERROR response

    // ---- interrupt sources and context outputs ----
    // `src_level_i[id]` is the live level of source `id`; bit 0 is never a source
    // (Spike: "interrupt source 0 does not exist") and is ignored.
    // `src_upd_i[id]` is its device's "I re-evaluated this line" strobe: Spike's
    // `set_interrupt_level` is called at the END of every access to the device
    // (and on a received byte), and each call re-latches the source's pending bit
    // and priority in the first enabled context. A level change on its own is
    // therefore not enough; the strobe is what the golden model keys on.
    input  logic [NDEV:0] src_level_i,
    input  logic [NDEV:0] src_upd_i,
    // One line per context, in Spike's order: bit 0 = context 0 = M (MEIP),
    // bit 1 = context 1 = S (SEIP).
    output logic [1:0]    ctx_irq_o
);

    localparam int unsigned ID_W   = (NDEV + 1 <= 1) ? 1 : $clog2(NDEV + 1);
    localparam int unsigned PRIO_W = PRIO_BITS;

    // window layout, as Spike's plic.cc defines it (byte offsets)
    localparam logic [23:0] PEND_OFF     = 24'h00_1000;   // PENDING_BASE
    localparam logic [23:0] ENAB_OFF     = 24'h00_2000;   // ENABLE_BASE
    localparam logic [23:0] CTX_OFF      = 24'h20_0000;   // CONTEXT_BASE

    // How many 32-bit words one context's enable block has. Spike decodes this
    // (`num_ids_word`); for 31 sources it is one word.
    localparam int unsigned NUM_ID_WORDS = (NDEV + 1 + 31) / 32;

    // --------------------------------------------------------------- decode
    logic        dword;          // eth_rv_pkg::SZ_DWORD
    logic        word;           // eth_rv_pkg::SZ_WORD
    logic        in_window;
    logic [23:0] off;            // byte offset inside the window
    logic [23:0] off_hi;         // ... and of a dword's second word
    logic [11:0] ctx_lo;         // context index of `off`
    logic [9:0]  sub_lo;         // 32-bit word index inside that context
    logic [11:0] ctx_hi;         // ... and the same for `off_hi`
    logic [9:0]  sub_hi;

    assign dword     = (size_i == 2'd3);
    assign word      = (size_i == 2'd2);
    // Spike's `find_device` requires the whole access inside the device, so an
    // address whose access would run past the window is not this device's.
    assign in_window = req_i && (addr_i >= BASE)
                       && ((addr_i + (dword ? 64'd8 : 64'd4)) <= (BASE + PLIC_SIZE));
    assign off       = 24'(addr_i - BASE);
    assign off_hi    = off + 24'd4;
    assign sel_o     = in_window;

    assign ctx_lo     = 12'((off - CTX_OFF) >> 12);
    assign sub_lo     = 10'((off - CTX_OFF) >> 2);
    assign ctx_hi     = 12'((off_hi - CTX_OFF) >> 12);
    assign sub_hi     = 10'((off_hi - CTX_OFF) >> 2);

    // --------------------------------------------------------------- state
    logic [1:0][NDEV:0]             enable_r;
    logic [1:0][NDEV:0]             pending_r;
    logic [1:0][NDEV:0][PRIO_W-1:0] pend_prio_r;
    logic [1:0][NDEV:0]             claimed_r;
    logic [1:0][PRIO_W-1:0]         threshold_r;
    logic [NDEV:0][PRIO_W-1:0]      priority_r;
    // Spike's `level[]`: the level each source was last seen at. It is kept in step
    // with the line on every cycle, which is equivalent to Spike's per-update
    // assignment because a source's line only moves when its device says so.
    logic [NDEV:0]                  level_r;

    // ------------------------------------------------------------- read side
    // One 4-byte word of the register map, decoded from its byte offset. `err` is
    // the device's own rejection (a context the configuration does not have);
    // `claim` says this word is a claim register, whose read marks the winner.
    typedef struct packed {
        logic [31:0] data;
        logic        err;
        logic        claim;
    } plic_rd_t;

    function automatic plic_rd_t word_read(input logic [23:0] o);
        plic_rd_t    r;
        logic [11:0] ctx_e;
        logic [4:0]  word_e;
        logic [11:0] ctx_c;
        logic [9:0]  sub_c;
        logic [9:0]  wid;             // the 32-bit word index inside the region
        begin
            r     = '{data: 32'd0, err: 1'b0, claim: 1'b0};
            wid   = o[11:2];
            ctx_e = 12'((o - ENAB_OFF) >> 7);
            word_e = 5'((o - ENAB_OFF) >> 2);
            ctx_c = 12'((o - CTX_OFF) >> 12);
            // The word index INSIDE that context: a context's register block is
            // 0x1000 bytes, so this is bits [11:2] of the offset within it — the
            // context index must come out first, or a context past the first one
            // looks like a reserved offset (which is exactly the S context).
            sub_c = 10'((o - CTX_OFF) >> 2) & 10'h3FF;
            if (o < PEND_OFF) begin
                // priority[id]: id 0 and every id past the sources read 0
                if ((wid >= 10'd1) && (wid <= 10'(NDEV))) begin
                    r.data = {28'd0, priority_r[wid[ID_W-1:0]]};
                end
            end else if (o < ENAB_OFF) begin
                // pending: read-only, the OR of every context's pending word
                if (wid == 10'(PEND_OFF >> 2)) begin
                    r.data = 32'(pending_r[0] | pending_r[1]);
                end
            end else if (o < CTX_OFF) begin
                // enable[ctx][word]
                if (ctx_e >= 12'd2) begin
                    r.err = 1'b1;
                end else if (word_e < 5'(NUM_ID_WORDS)) begin
                    r.data = 32'(enable_r[ctx_e[0]]);
                end
            end else begin
                // threshold / claim / reserved, per context
                if (ctx_c >= 12'd2) begin
                    r.err = 1'b1;
                end else if (sub_c == 10'd0) begin
                    r.data = {28'd0, threshold_r[ctx_c[0]]};
                end else if (sub_c == 10'd1) begin
                    r.data  = 32'(claim_val[ctx_c[0]]);
                    r.claim = 1'b1;
                end
            end
            return r;
        end
    endfunction

    plic_rd_t rd_lo;
    plic_rd_t rd_hi;
    assign rd_lo = word_read(off);
    assign rd_hi = word_read(off_hi);

    // ------------------------------------------------------------ write side
    // Where a 4-byte word store lands. At most one field is active per word, and
    // the two halves of a dword store are independent words, so both apply.
    typedef struct packed {
        logic            prio_we;
        logic [ID_W-1:0] prio_id;
        logic            en_we;
        logic            en_ctx;      // 0 = the M context, 1 = the S context
        logic [4:0]      en_word;     // 32 enable words per context
        logic            thr_we;
        logic            thr_ctx;
        logic            comp_we;
        logic            comp_ctx;
        logic [31:0]     comp_id;     // the COMPLETE id, unclamped (Spike compares it)
        logic            err;
    } plic_wr_t;

    function automatic plic_wr_t word_write_intent(input logic [23:0] o, input logic [31:0] data);
        plic_wr_t    r;
        logic [11:0] ctx_e;
        logic [4:0]  word_e;
        logic [11:0] ctx_c;
        logic [11:0] sub_c;
        logic [9:0]  wid;
        begin
            r      = '{prio_we: 1'b0, prio_id: '0, en_we: 1'b0, en_ctx: 1'b0,
                       en_word: 5'd0, thr_we: 1'b0, thr_ctx: 1'b0, comp_we: 1'b0,
                       comp_ctx: 1'b0, comp_id: 32'd0, err: 1'b0};
            wid    = o[11:2];
            ctx_e  = 12'((o - ENAB_OFF) >> 7);
            word_e = 5'((o - ENAB_OFF) >> 2);
            ctx_c  = 12'((o - CTX_OFF) >> 12);
            sub_c  = 12'((o - CTX_OFF) >> 2) & 12'h3FF;   // word inside the context
            if (o < ENAB_OFF) begin
                // the priority region, and (silently dropped) the pending region
                if ((wid >= 10'd1) && (wid <= 10'(NDEV))) begin
                    r.prio_we = 1'b1;
                    r.prio_id = wid[ID_W-1:0];
                end
            end else if (o < CTX_OFF) begin
                if (ctx_e >= 12'd2) begin
                    r.err = 1'b1;
                end else begin
                    r.en_we   = 1'b1;
                    r.en_ctx  = ctx_e[0];
                    r.en_word = word_e;            // 32 words (0x80 bytes) per context
                end
            end else begin
                if (ctx_c >= 12'd2) begin
                    r.err = 1'b1;
                end else if (sub_c == 12'd0) begin
                    r.thr_we  = 1'b1;
                    r.thr_ctx = ctx_c[0];
                end else if (sub_c == 12'd1) begin
                    r.comp_we  = 1'b1;
                    r.comp_ctx = ctx_c[0];
                    r.comp_id  = data;             // compared whole, as Spike does

                end else begin
                    r.err = 1'b1;       // a reserved context offset: writes fault
                end
            end
            return r;
        end
    endfunction

    logic [31:0] wdata_lo;      // the addressed 4-byte word of the store beat
    logic [31:0] wdata_hi;      // ... and the next one (dword stores only)

    assign wdata_lo = addr_i[2] ? wdata_i[63:32] : wdata_i[31:0];
    assign wdata_hi = wdata_i[63:32];

    plic_wr_t wr_lo;
    plic_wr_t wr_hi;
    assign wr_lo = word_write_intent(off, wdata_lo);
    assign wr_hi = word_write_intent(off_hi, wdata_hi);

    // ------------------------------------------------------------ arbitration
    // The winner per context: the pending, unclaimed source with the highest
    // latched priority, ties to the lowest id. The chain walks ids 0..NDEV in
    // ascending order and keeps the running winner on a strict `>`, which is
    // Spike's `best_id_prio < pending_priority[id]` rule stated that way round.
    //
    // Two variants are needed, because a claim read both REPORTS the winner and
    // MARKS it claimed: Spike returns the winner computed *before* the mark and
    // only then sets `claimed`, so the value a claim read yields and the line it
    // leaves behind are different states of the same cycle. Variant 0 is what the
    // claim read returns (and what the mark is derived from), variant 1 is what
    // the context line becomes after the mark.
    generate
        for (genvar gc = 0; gc < 2; gc = gc + 1) begin : g_arb
            for (genvar gk = 0; gk < 2; gk = gk + 1) begin : g_var
                for (genvar gi = 0; gi <= NDEV; gi = gi + 1) begin : g_id
                    logic               elig;
                    logic [PRIO_W-1:0] prev_prio;
                    logic [ID_W-1:0]   prev_id;
                    logic               win;
                    logic [PRIO_W-1:0] stage_prio;
                    logic [ID_W-1:0]   stage_id;

                    // Source 0 does not exist: its enable bit can never be set, so
                    // it is never eligible and contributes a constant zero.
                    assign elig = (gi != 0) && g_state[gc].pend_eff[gi]
                                  && !((gk == 0) ? g_state[gc].claimed_pre[gi]
                                                 : g_state[gc].claimed_eff[gi]);
                    if (gi == 0) begin : g_first
                        assign prev_prio = '0;
                        assign prev_id   = '0;
                    end else begin : g_next
                        assign prev_prio = g_arb[gc].g_var[gk].g_id[gi-1].stage_prio;
                        assign prev_id   = g_arb[gc].g_var[gk].g_id[gi-1].stage_id;
                    end
                    assign win        = elig && (g_state[gc].prio_eff[gi] > prev_prio);
                    assign stage_prio = win ? g_state[gc].prio_eff[gi] : prev_prio;
                    assign stage_id   = win ? ID_W'(gi) : prev_id;
                end
            end
        end
    endgenerate

    assign best_id_rd[0]   = g_arb[0].g_var[0].g_id[NDEV].stage_id;
    assign best_prio_rd[0] = g_arb[0].g_var[0].g_id[NDEV].stage_prio;
    assign best_id_rd[1]   = g_arb[1].g_var[0].g_id[NDEV].stage_id;
    assign best_prio_rd[1] = g_arb[1].g_var[0].g_id[NDEV].stage_prio;
    assign best_id_ln[0]   = g_arb[0].g_var[1].g_id[NDEV].stage_id;
    assign best_prio_ln[0] = g_arb[0].g_var[1].g_id[NDEV].stage_prio;
    assign best_id_ln[1]   = g_arb[1].g_var[1].g_id[NDEV].stage_id;
    assign best_prio_ln[1] = g_arb[1].g_var[1].g_id[NDEV].stage_prio;

    // A claim read returns the winner only when the threshold lets it through
    // (`context_best_pending` masks `prio <= threshold` before returning), and
    // that masked value is what the mark is derived from as well.
    assign claim_val[0] = (best_prio_rd[0] > g_state[0].thr_eff) ? best_id_rd[0] : '0;
    assign claim_val[1] = (best_prio_rd[1] > g_state[1].thr_eff) ? best_id_rd[1] : '0;

    // The threshold masks `prio <= threshold`, which is why priority 0 is never
    // delivered.
    assign ctx_irq_o[0] = (best_id_ln[0] != '0) && (best_prio_ln[0] > g_state[0].thr_eff);
    assign ctx_irq_o[1] = (best_id_ln[1] != '0) && (best_prio_ln[1] > g_state[1].thr_eff);

    // ------------------------------------------------------- access classes
    logic by_width;     // this access is a 4- or 8-byte one
    logic read_acc;
    logic write_acc;

    assign by_width  = dword || word;
    assign read_acc  = sel_o && by_width && !we_i;
    assign write_acc = sel_o && by_width && we_i;

    // A dword is two word accesses (Spike: `load(addr,4) && load(addr+4,4)`), so
    // either half failing fails the whole access — the low half's effects, if any,
    // have already happened, exactly as they have in the golden model.
    assign err_o = sel_o && (!by_width
                   || (we_i ? (wr_lo.err || (dword && wr_hi.err))
                            : (rd_lo.err || (dword && rd_hi.err))));

    // The one read with a side effect: reading a context's claim register reports
    // the winner and marks it claimed. The second half of a dword is only reached
    // when the first one succeeded (Spike's short-circuit `&&`).
    logic claim_rd_w0;
    logic claim_rd_w1;
    logic claim_rd_h0;
    logic claim_rd_h1;

    assign claim_rd_w0 = read_acc && !rd_lo.err && rd_lo.claim
                         && (ctx_lo == 12'd0) && (sub_lo == 10'd1);
    assign claim_rd_w1 = read_acc && !rd_lo.err && rd_lo.claim
                         && (ctx_lo == 12'd1) && (sub_lo == 10'd1);
    assign claim_rd_h0 = dword && read_acc && !rd_lo.err && !rd_hi.err && rd_hi.claim
                         && (ctx_hi == 12'd0) && (sub_hi == 10'd1);
    assign claim_rd_h1 = dword && read_acc && !rd_lo.err && !rd_hi.err && rd_hi.claim
                         && (ctx_hi == 12'd1) && (sub_hi == 10'd1);

    // Read data: the addressed word, and its neighbour for a dword, placed at the
    // byte lanes the core rotates out of the beat.
    assign rdata_o = dword     ? {rd_hi.data, rd_lo.data}
                   : addr_i[2] ? {rd_lo.data, 32'd0}
                               : {32'd0, rd_lo.data};

    // ---- arbitration results (driven by the chains below; declared here so the
    // per-context block and the register read path can both refer to them) ------
    // `_rd` is the state a CLAIM READ sees (Spike marks the winner only after
    // `context_best_pending` returned); `_ln` is the state the context LINE sees,
    // with the claim's mark applied.
    logic [1:0][ID_W-1:0]    best_id_rd;
    logic [1:0][PRIO_W-1:0]  best_prio_rd;
    logic [1:0][ID_W-1:0]    best_id_ln;
    logic [1:0][PRIO_W-1:0]  best_prio_ln;
    logic [1:0][ID_W-1:0]    claim_val;

    // ------------------------------------------------- per-context registers
    // Every update below is a vector operation: one word write, one source-level
    // update, one claim and one complete are each a mask over the source vector.
    //
    // `*_eff` IS THE STATE THE ACCESS IN FLIGHT LEAVES BEHIND, and the arbitration
    // uses it rather than the registers because of a pipeline fact: Spike's device
    // applies its level/claim update *inside* the access, so the very next
    // instruction already sees the new `mip`. In this core that next instruction
    // is in EX while the access is in MEM, so a line derived from the registered
    // state alone would rise one instruction too late (the same one-cycle hazard
    // `eth_rv_clint` solves for its combinational msip/mtip outputs).
    generate
        for (genvar gc = 0; gc < 2; gc = gc + 1) begin : g_state
            // an enable write to this context's word 0: the bits that changed move
            // pending/priority/claim state with them, and source 0 is masked off
            logic               en_wr_lo;
            logic               en_wr_hi;
            logic [NDEV:0]      en_nxt;
            logic [NDEV:0]      changed;
            logic [NDEV:0]      en_set;
            logic [NDEV:0]      en_clr;
            // the source-level update: only the FIRST enabled context takes it
            logic [NDEV:0]      first_en;
            logic [NDEV:0]      lvl_set;
            logic [NDEV:0]      lvl_clr;
            // claim read / complete write, as one-hot masks
            logic               claim_rd;
            logic [NDEV:0]      claim_oh;
            logic               comp_wr;
            logic [31:0]        comp_id;
            logic [NDEV:0]      comp_oh;
            // the combined update, and the state the arbiter and the lines use
            logic [NDEV:0]      set_mask;
            logic [NDEV:0]      clr_mask;
            logic [NDEV:0]      pend_nxt;
            logic [NDEV:0][PRIO_W-1:0] pp_nxt;
            logic [NDEV:0]      claimed_nxt;
            logic [NDEV:0]      pend_eff;
            logic [PRIO_W-1:0]  thr_eff;       // the threshold a threshold write leaves
            logic               thr_wr_lo;
            logic               thr_wr_hi;
            logic [NDEV:0][PRIO_W-1:0] prio_eff;
            // A source mask is one BIT per source; the priority vector is one
            // NIBBLE per source, so a mask has to be expanded before it can be
            // applied: bit i of `set_mask` covers the four-bit field of source i.
            logic [(NDEV+1)*PRIO_W-1:0] set_nib;
            logic [(NDEV+1)*PRIO_W-1:0] clr_nib;
            logic [NDEV:0]      claimed_pre;   // with this cycle's clears, no claim mark
            logic [NDEV:0]      claimed_eff;   // ... and with the claim-read mark
            logic               thr_wr;

            // Only one enable word exists for a configuration of up to 32 sources
            // (this one has 31), so a write past it is ignored — as in Spike,
            // where `context_enable_write` returns true without doing anything.
            // Both halves of a dword store are applied (Spike stores them as two
            // word stores); the two words can never be the same context's word 0.
            assign en_wr_lo = write_acc && wr_lo.en_we && (wr_lo.en_ctx == 1'(gc))
                              && (wr_lo.en_word == 5'd0);
            assign en_wr_hi = dword && write_acc && wr_hi.en_we && (wr_hi.en_ctx == 1'(gc))
                              && (wr_hi.en_word == 5'd0);
            assign en_nxt = (en_wr_lo || en_wr_hi)
                            ? ((en_wr_lo ? wdata_lo[NDEV:0] : wdata_hi[NDEV:0])
                               & {{(NDEV){1'b1}}, 1'b0})
                            : enable_r[gc];

            assign changed = (en_wr_lo || en_wr_hi) ? (enable_r[gc] ^ en_nxt) : '0;
            // An enable write that turns a bit on takes the source's last sampled
            // level (Spike's `level[]`), not the live line.
            assign en_set  = changed & en_nxt & level_r;
            assign en_clr  = changed & ~en_nxt;

            assign first_en = (gc == 0) ? enable_r[0] : (enable_r[1] & ~enable_r[0]);
            assign lvl_set  = src_upd_i & src_level_i & first_en;
            assign lvl_clr  = src_upd_i & ~src_level_i & first_en;

            assign claim_rd = (gc == 0) ? (claim_rd_w0 || claim_rd_h0)
                                        : (claim_rd_w1 || claim_rd_h1);
            // `claim_val` is the thresholded winner a claim read returns (see the
            // chain below); nothing is marked claimed when it is masked, which is
            // `context_best_pending`'s rule.
            assign claim_oh  = (claim_rd && (claim_val[gc] != '0))
                               ? ({{(NDEV){1'b0}}, 1'b1} << claim_val[gc]) : '0;

            assign comp_wr = write_acc
                             && ((wr_lo.comp_we && (wr_lo.comp_ctx == 1'(gc)))
                                 || (dword && wr_hi.comp_we && (wr_hi.comp_ctx == 1'(gc))));
            assign comp_id = (wr_lo.comp_we && (wr_lo.comp_ctx == 1'(gc)))
                             ? wr_lo.comp_id : wr_hi.comp_id;
            assign comp_oh = (comp_wr && (comp_id <= 32'(NDEV))
                              && enable_r[gc][comp_id[ID_W-1:0]])
                             ? ({{(NDEV){1'b0}}, 1'b1} << comp_id[ID_W-1:0]) : '0;

            assign set_mask    = en_set | lvl_set;
            assign clr_mask    = en_clr | lvl_clr;
            for (genvar gi = 0; gi <= NDEV; gi = gi + 1) begin : g_nib
                assign set_nib[gi*PRIO_W +: PRIO_W] = {PRIO_W{set_mask[gi]}};
                assign clr_nib[gi*PRIO_W +: PRIO_W] = {PRIO_W{clr_mask[gi]}};
            end

            assign pend_nxt    = (pending_r[gc] & ~clr_mask) | set_mask;
            assign pp_nxt      = (pend_prio_r[gc] & ~clr_nib) | (priority_r & set_nib);
            assign claimed_nxt = (claimed_r[gc] & ~clr_mask & ~comp_oh) | claim_oh;

            assign pend_eff    = pend_nxt;
            assign prio_eff    = pp_nxt;
            assign claimed_pre = claimed_r[gc] & ~clr_mask & ~comp_oh;
            assign claimed_eff = claimed_pre | claim_oh;

            // A WRITE to this context's threshold: `write_acc` is part of both the
            // register update and the arbitration bypass, because the intent decode
            // is only an address match — a *read* of the threshold register must not
            // look like a write of whatever the load lane carries.
            assign thr_wr_lo = write_acc && wr_lo.thr_we && (wr_lo.thr_ctx == 1'(gc));
            assign thr_wr_hi = dword && write_acc && wr_hi.thr_we
                               && (wr_hi.thr_ctx == 1'(gc));
            assign thr_wr = thr_wr_lo || thr_wr_hi;
            // The value the threshold register takes, which is ALSO the value the
            // arbitration has to compare against in the cycle of the write: the
            // instruction after a threshold store reads `mip` while that store is
            // in MEM, and Spike applied it already.
            assign thr_eff = thr_wr_lo ? wdata_lo[PRIO_W-1:0]
                           : thr_wr_hi ? wdata_hi[PRIO_W-1:0]
                           : threshold_r[gc];

            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    enable_r[gc]    <= '0;
                    pending_r[gc]   <= '0;
                    pend_prio_r[gc] <= '0;
                    claimed_r[gc]   <= '0;
                    threshold_r[gc] <= '0;
                end else begin
                    enable_r[gc]    <= en_nxt;
                    pending_r[gc]   <= pend_nxt;
                    pend_prio_r[gc] <= pp_nxt;
                    claimed_r[gc]   <= claimed_nxt;
                    if (thr_wr) threshold_r[gc] <= thr_eff;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            priority_r <= '0;
            level_r    <= '0;
        end else begin
            level_r <= src_level_i;
            if (write_acc && wr_lo.prio_we) begin
                priority_r[wr_lo.prio_id] <= wdata_lo[PRIO_W-1:0];
            end
            if (dword && write_acc && wr_hi.prio_we) begin
                priority_r[wr_hi.prio_id] <= wdata_hi[PRIO_W-1:0];
            end
        end
    end

endmodule
`default_nettype wire
