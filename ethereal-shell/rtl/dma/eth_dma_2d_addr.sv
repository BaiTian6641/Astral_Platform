`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_dma_2d_addr
// Description: ND-strided rectangle address walker (N <= 3) of the 2D graphics
//              DMA `eth_dma_2d` (S15 §3 "ND-strided 地址引擎（2D=N2）"): it
//              walks every LINE of a (x, y, z) rectangle and offers the line's
//              byte address, guarding it against a software-declared address
//              window.  It moves no data — `eth_dma_2d` streams the beats of
//              each offered line through the shared AXI4 engine; this module
//              owns ONLY the address arithmetic, which is what makes it
//              formally provable on its own (eth_dma_2d_addr.sby).
//
//  ADDRESS MODEL (the whole of it):
//      addr(z, y) = base + z * plane_stride + y * line_stride        z, y >= 0
//  with x (the byte inside a line) implicit: a line is the contiguous byte
//  range [addr(z,y), addr(z,y) + h_bytes).  Order of traversal is
//      z = 0: y = 0 .. v_lines-1  ->  z = 1: y = 0 .. v_lines-1  ->  ...
//  i.e. x fastest, then y, then z.  The walk is INCREMENTAL — the three
//  strides are never multiplied (there is no multiplier in this module): the
//  current plane's origin is accumulated by plane_stride at every plane
//  boundary and the current line by line_stride at every line boundary, so the
//  hardware cost is two 64-bit adders and two counters, independent of the
//  rectangle size.
//
//  ASSUMPTION: the ND address engine is capped at N = 3 (x, y, z); the plan
//  names ND-strided addressing without fixing N.  (TBD, 2026-09-13)
//
//  DIMENSION LIMIT (documented, deliberate): N = 3 (x, y, z).  The plan's ND
//  engine (PULP `tensor_ND`) is general, but every step beyond 3 needs another
//  accumulated origin register, another counter and another stride field in
//  the CSR (a 4th dimension would be ~30 more bits of register and a wider
//  plane jump for no graphics use case): planar video (Y/U/V) is exactly 3D,
//  and tiled/batched transfers are N x 2D, not 4D.  A >3D walk is synthesised
//  by software as a chain of this DMA's frames.
//
//  CLIPPING / EDGES (v0 rules, enforced by `eth_dma_2d` at START — this module
//  assumes a legal rectangle):
//    * a transfer is a whole number of LINES: h_bytes is a non-zero multiple of
//      the beat size, so the last line's last beat is never partial (the AXI
//      master writes full beats with WSTRB all ones);
//    * base, line_stride and plane_stride are beat-aligned (INCR bursts);
//    * h_bytes <= line_stride: lines do not overlap inside a plane;
//    * THERE IS NO RECTANGLE CLIP INSIDE THIS MODULE.  The rectangle *is* the
//      clip: software clips by programming base/HSIZE/VSIZE, so the engine
//      never reads or writes a byte outside the programmed rectangle.  There is
//      deliberately no scissor register — a second, redundant clip would be
//      state that nothing else in the SoC reads.
//      ASSUMPTION: a rectangle clip / scissor register is out of scope for v0
//      (the plan defines no clipping model; the rectangle bounds are the clip).
//      (TBD, 2026-09-13)
//
//  WINDOW GUARD (the safety boundary, and the reason this module is separate):
//  every line the walker offers is checked BEFORE its first beat is issued
//  against the software-declared window [win_lo_i, win_hi_i):
//      safe_c = (line_addr + h_bytes) <= win_hi  &&  line_addr >= win_lo
//               && (line_addr + h_bytes) does not carry out of the AXI address
//               space (2**AXI_AW)
//  The comparison is 65-bit, so a line that would wrap the 64-bit address space
//  can never be called safe.  `safe_o` is the ONLY licence `eth_dma_2d` has to
//  emit beats for a line: a beat address is always line_addr + k*beat with
//  k < h_bytes/beat, hence inside the window.  A line that fails the check puts
//  the walker in A_FAULT, where it stays (fully frozen, `line_addr_o` holding
//  the first illegal line address) until the next `start_i`.
//
//  FSM (two-segment):
//      A_IDLE  : idle / armed; `start_i` loads base and counters -> A_RUN
//      A_RUN   : the current (z, y) line is offered on line_addr_o, guarded by
//                safe_o; `step_i` (one per finished line) advances y, or wraps
//                to the next plane (accumulating plane_stride), or - after the
//                last line of the last plane - completes the frame -> A_DONE.
//                A line that fails the window guard, or a stride add that would
//                carry out of 64 bits, faults -> A_FAULT (no wrap is ever
//                silently taken: the step is refused, not truncated).
//      A_DONE  : frame complete; the walk is frozen until start_i
//      A_FAULT : first illegal line frozen in line_addr_o; until start_i
//  `start_i` is accepted in A_IDLE/A_DONE/A_FAULT (a new frame re-initialises
//  everything); it is ignored in A_RUN, so a start can never corrupt a frame in
//  flight.  `step_i` is honoured only in A_RUN with a safe line.  `abort_i`
//  parks the walk from ANY state into A_IDLE: the caller asserts it when it
//  abandons a frame (engine fault / software ABORT / CFG rejection), which is
//  what guarantees a walk is never left running across frames.
//
//  CONTRACT with the caller (`eth_dma_2d`): the geometry and window inputs are
//  HELD STABLE for the whole frame.  That is not an assumption the caller may
//  break: `eth_dma_2d` copies every frame parameter into shadow registers at
//  START (VDMA-style double buffering — register writes during a frame take
//  effect at the next frame), and asserts that stability under `ifdef FORMAL`.
// Maintainer:  BaiTian6641
// Created:     2026-09-13
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/subsystems/S15-应用处理器子系统.md §3 (2D 图形 DMA
//              `eth_dma_2d`: ND-strided 地址引擎，2D=N2，参考 PULP `tensor_ND`) ·
//              docs/adr/ADR-018-axi-noc-riscv-cluster.md §7
// Notes:       iverilog -g2012 compatible (two-segment FSM, no procedural loops,
//              sized literals).  AXI_AW is the width of the attached AXI4 master
//              port; the walker itself is 64-bit address-clean and refuses (via
//              safe_o/fault_o) any line above 2**AXI_AW.
//              ASSUMPTION (TBD, 2026-09-13): the first frame parameter set is
//              sampled into shadow registers rather than the live CSR registers
//              (VDMA-style); if the spec later requires live parameter updates
//              mid-frame this module needs a re-arm input — it is deliberately
//              NOT provided because a mid-frame geometry change is a race.
module eth_dma_2d_addr #(
    parameter int AXI_AW = 32       // address width of the attached AXI4 master
) (
    input  logic            clk_i,
    input  logic            rst_ni,
    // ---- frame geometry + window (stable for the whole frame) ----
    input  logic [63:0]     base_i,
    input  logic [63:0]     line_stride_i,
    input  logic [63:0]     plane_stride_i,
    input  logic [15:0]     h_bytes_i,
    input  logic [15:0]     v_lines_i,
    input  logic [15:0]     planes_i,
    input  logic [63:0]     win_lo_i,
    input  logic [63:0]     win_hi_i,
    // ---- control ----
    input  logic            start_i,     // 1-cycle: arm/restart (not while A_RUN)
    input  logic            step_i,      // 1-cycle: the offered line is finished
    input  logic            abort_i,     // 1-cycle: abandon the walk -> A_IDLE
    // ---- current line ----
    output logic            run_o,       // walking: a line is offered
    output logic            safe_o,      // the offered line is inside the window
    output logic [63:0]     line_addr_o, // [line_addr, line_addr + h_bytes)
    output logic            done_o,      // frame complete
    output logic            fault_o      // window/carry fault latched
);

    // ------------------------------------------------------------------
    // State + walk registers
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {
        A_IDLE  = 2'd0,
        A_RUN   = 2'd1,
        A_DONE  = 2'd2,
        A_FAULT = 2'd3
    } addr_state_e;

    addr_state_e state_r,      state_nxt;
    logic [63:0] line_addr_r,  line_addr_nxt;    // origin of the current line
    logic [63:0] plane_addr_r, plane_addr_nxt;   // origin of the current plane
    logic [15:0] y_r,          y_nxt;
    logic [15:0] z_r,          z_nxt;

    // ------------------------------------------------------------------
    // 65-bit sums: bit 64 is "carried out of the 64-bit address space".
    // AXI_LIMIT is 2**AXI_AW as a 65-bit constant (representable for every
    // AXI_AW <= 64, which is what keeps the guard width-independent).
    // ------------------------------------------------------------------
    localparam logic [64:0] AXI_LIMIT = 65'(1) << AXI_AW;

    logic [64:0] line_end_c;    // line_addr + h_bytes  (exclusive end)
    logic [64:0] line_nxt_c;    // line_addr + line_stride
    logic [64:0] plane_nxt_c;   // plane_addr + plane_stride
    logic        y_last_c;
    logic        z_last_c;
    logic        safe_c;

    assign line_end_c  = {1'b0, line_addr_r} + {{49{1'b0}}, h_bytes_i};
    assign line_nxt_c  = {1'b0, line_addr_r} + {1'b0, line_stride_i};
    assign plane_nxt_c = {1'b0, plane_addr_r} + {1'b0, plane_stride_i};

    assign y_last_c = (y_r == (v_lines_i - 16'd1));
    assign z_last_c = (z_r == (planes_i - 16'd1));

    // A line may be transferred only when it is entirely inside the declared
    // window AND entirely inside the AXI address space.
    assign safe_c = (line_end_c <= AXI_LIMIT) &&
                    ({1'b0, line_addr_r} >= {1'b0, win_lo_i}) &&
                    (line_end_c <= {1'b0, win_hi_i});

    assign run_o       = (state_r == A_RUN);
    assign safe_o      = (state_r == A_RUN) && safe_c;
    assign line_addr_o = line_addr_r;
    assign done_o      = (state_r == A_DONE);
    assign fault_o     = (state_r == A_FAULT);

    // ------------------------------------------------------------------
    // Next state (combinational; defaults first)
    // ------------------------------------------------------------------
    always_comb begin
        state_nxt      = state_r;
        line_addr_nxt  = line_addr_r;
        plane_addr_nxt = plane_addr_r;
        y_nxt          = y_r;
        z_nxt          = z_r;

        case (state_r)
            A_IDLE, A_DONE, A_FAULT: begin
                if (start_i) begin
                    state_nxt      = A_RUN;
                    line_addr_nxt  = base_i;
                    plane_addr_nxt = base_i;
                    y_nxt          = 16'd0;
                    z_nxt          = 16'd0;
                end
            end
            A_RUN: begin
                if (!safe_c) begin
                    // the offered line is illegal: freeze and report it
                    state_nxt = A_FAULT;
                end else if (step_i) begin
                    if (y_last_c) begin
                        if (z_last_c) begin
                            state_nxt = A_DONE;
                        end else if (plane_nxt_c[64]) begin
                            // the next plane origin would wrap: refuse the step
                            state_nxt = A_FAULT;
                        end else begin
                            plane_addr_nxt = plane_nxt_c[63:0];
                            line_addr_nxt  = plane_nxt_c[63:0];
                            y_nxt          = 16'd0;
                            z_nxt          = z_r + 16'd1;
                        end
                    end else if (line_nxt_c[64]) begin
                        // the next line address would wrap: refuse the step
                        state_nxt = A_FAULT;
                    end else begin
                        line_addr_nxt = line_nxt_c[63:0];
                        y_nxt         = y_r + 16'd1;
                    end
                end
            end
            default: begin
                state_nxt = A_IDLE;
            end
        endcase

        // `abort_i` parks the walk from ANY state (the engine asserts it when it
        // abandons a frame, so a walk can never be left running across frames);
        // it wins over `start_i`, which the engine never asserts in the same
        // cycle.  A parked walk offers nothing (run_o = safe_o = 0).
        if (abort_i) begin
            state_nxt = A_IDLE;
        end
    end

    // ------------------------------------------------------------------
    // State update
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r        <= A_IDLE;
            line_addr_r    <= 64'h0;
            plane_addr_r   <= 64'h0;
            y_r            <= 16'd0;
            z_r            <= 16'd0;
        end else begin
            state_r        <= state_nxt;
            line_addr_r    <= line_addr_nxt;
            plane_addr_r   <= plane_addr_nxt;
            y_r            <= y_nxt;
            z_r            <= z_nxt;
        end
    end

    // ------------------------------------------------------------------
    // Formal properties (SymbiYosys / smtbmc; NOT compiled for lint or sim).
    // Proven by ethereal-shell/formal/eth_dma_2d_addr.sby.  Every property is a
    // one-step relation over (state, inputs, next state) or a frozen-output
    // check, so the proof holds by k-induction at unbounded depth.  The
    // environment is the caller contract: a legal rectangle whose geometry and
    // window are held stable for the whole frame (`eth_dma_2d` discharges that
    // with its shadow registers).
    // ------------------------------------------------------------------
`ifdef FORMAL
    logic past_valid = 1'b0;

    always_ff @(posedge clk_i) past_valid <= 1'b1;

    // hold reset in the first cycle so the walk cannot start from an arbitrary
    // state (no spurious counterexamples)
    always_ff @(posedge clk_i) if (!past_valid) assume(!rst_ni);

    always_ff @(posedge clk_i) begin
        if (past_valid && $past(rst_ni) && rst_ni) begin
            // ---- environment contract ---------------------------------
            assume(h_bytes_i != 16'd0);
            assume(v_lines_i != 16'd0);
            assume(planes_i  != 16'd0);
            assume(line_stride_i != 64'h0);                 // engine: >= h_bytes
            assume({1'b0, win_lo_i} < {1'b0, win_hi_i});    // non-empty window
            assume({1'b0, win_hi_i} <= AXI_LIMIT);          // inside the AXI space
            // geometry is stable while the walk is in flight (shadow registers)
            if ($past(state_r) == A_RUN && state_r == A_RUN) begin
                assume(base_i         == $past(base_i));
                assume(line_stride_i  == $past(line_stride_i));
                assume(plane_stride_i == $past(plane_stride_i));
                assume(h_bytes_i      == $past(h_bytes_i));
                assume(v_lines_i      == $past(v_lines_i));
                assume(planes_i       == $past(planes_i));
                assume(win_lo_i       == $past(win_lo_i));
                assume(win_hi_i       == $past(win_hi_i));
            end

            // ---- W1: a line offered for transfer is inside the window ---
            if (safe_o) begin
                assert({1'b0, line_addr_o} >= {1'b0, win_lo_i});
                assert(line_end_c <= {1'b0, win_hi_i});
                assert(line_end_c[64] == 1'b0);
                assert(line_end_c <= AXI_LIMIT);
            end

            // ---- W2: the walk never leaves the declared rectangle --------
            if (state_r == A_RUN) begin
                assert(y_r < v_lines_i);
                assert(z_r < planes_i);
            end

            // ---- W3: address arithmetic moves only by declared strides and
            //          never takes a wrapping step -------------------------
            if (state_r == A_RUN && safe_o && step_i) begin
                if (y_nxt == y_r + 16'd1) begin
                    assert(line_nxt_c[64] == 1'b0);
                    assert(line_addr_nxt == line_addr_r + line_stride_i);
                    assert(line_addr_nxt > line_addr_r);
                end
                if (z_nxt == z_r + 16'd1) begin
                    assert(plane_nxt_c[64] == 1'b0);
                    assert(plane_addr_nxt == plane_addr_r + plane_stride_i);
                    assert(line_addr_nxt == plane_addr_nxt);
                end
            end

            // ---- W4: A_DONE is reachable only from the last line of the
            //          last plane, and no accepted step is silently swallowed
            //          (it advances y, or z, or completes the frame) --------
            if (state_r == A_RUN && safe_o && step_i) begin
                if (state_nxt == A_DONE) begin
                    assert(y_last_c && z_last_c);
                end
                // (with abort_i the step is abandoned rather than swallowed:
                // the walker is parked and the caller restarts the frame, so
                // the "advance or complete" obligation only applies without it)
                if ((state_nxt != A_FAULT) && !abort_i) begin
                    assert((state_nxt == A_DONE) ||
                           (y_nxt == y_r + 16'd1) ||
                           (z_nxt == z_r + 16'd1));
                end
            end

            // ---- W5: DONE and FAULT are terminal until the next start -----
            if ((state_r == A_DONE) || (state_r == A_FAULT)) begin
                if (!start_i && !abort_i) begin
                    assert(state_nxt == state_r);
                    assert(line_addr_nxt == line_addr_r);
                    assert(plane_addr_nxt == plane_addr_r);
                    assert(y_nxt == y_r);
                    assert(z_nxt == z_r);
                end
            end
            // a pulse cannot re-enter A_RUN out of a frozen state
            if (state_r == A_DONE && !start_i) assert(state_nxt != A_RUN);

            // ---- W6: `start_i` cannot (re)load a frame while the walk is
            //          running: in A_RUN the next line address is either
            //          unchanged, the guard fault, or one of the two declared
            //          stride steps -- never the origin of a new walk -------
            if (state_r == A_RUN && start_i) begin
                assert((state_nxt == A_FAULT) ||
                       (line_addr_nxt == line_addr_r) ||
                       (line_addr_nxt == line_nxt_c[63:0]) ||
                       (line_addr_nxt == plane_nxt_c[63:0]));
            end

            // ---- W7: abort parks the walk from any state (A_IDLE offers no
            //          line, so its counters are irrelevant) ----------------
            if (abort_i) begin
                assert(state_nxt == A_IDLE);
            end

            // ---- covers (non-vacuity of the safety proof) -----------------
            cover(state_r == A_RUN && safe_o);
            cover(state_r == A_DONE);
            cover(state_r == A_FAULT && !safe_c);
        end
    end
`endif

endmodule

`default_nettype wire
