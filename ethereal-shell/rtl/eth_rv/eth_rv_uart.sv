`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_uart
// Description: MMIO console UART (ns16550 subset) for the eth_rv SoC — the
//              C14 §8 checkpoint 5 bring-up peripheral (a bare-metal `hello`
//              becomes visible on a serial line) and, since E2-RV2 increment 6,
//              the console a *usable* Linux needs: a receive path with its
//              interrupt, wired into the PLIC (S15 §5, C06 "UART 16550 简化子集").
// Details:     REGISTER FILE (ns16550 subset, one BYTE register per offset, the
//              classic reg-shift = 0 / reg-io-width = 1 layout of C06 §2):
//
//                off  read            write         this implementation
//                0    RBR             THR           read pops the RX queue;
//                                                     write transmits (DLAB: DLL;
//                                                     MCR.LOOP: injects into RX)
//                1    IER             IER           R/W (DLAB: DLM)
//                2    IIR             FCR           IIR computed; FCR bits act
//                                                     on the FIFOs and self-clear
//                3    LCR             LCR           R/W (DLAB = lcr[7])
//                4    MCR             MCR           R/W (bit 4 = loopback)
//                5    LSR             (test)        TEMT|THRE constant, DR = RX queue
//                6    MSR             (unused)      0xB0 constant: DCD|DSR|CTS
//                7    SCR             SCR           R/W
//
//              WHY LSR'S TRANSMIT BITS ARE A CONSTANT (the load-bearing decision):
//              the whole point of this peripheral is that a program driving it
//              still MATCHes Spike's commit trace *bit for bit* (C14 §5), and
//              Spike's own ns16550 (`riscv/ns16550.cc`, the golden model this
//              register file mirrors) has a transmitter that is *never* busy:
//              `tx_byte()` writes the character to the console and leaves
//              TEMT|THRE set, so those bits read 1 forever and a
//              `while (!(lsr & THRE)) ;` poll costs exactly one iteration on the
//              golden side. If this UART instead reported its real (divider-paced)
//              transmitter state, every poll would retire a different NUMBER of
//              instructions than Spike's and the two streams could not match at
//              all. The register-visible status is therefore the same "ready"
//              model, and the physical transmitter's real state is exported as the
//              `tx_busy_o`/`tx_overflow_o` ports — verification status, not
//              program-visible state (a MMIO status bit that Spike does not have
//              would be exactly the divergence this design exists to avoid).
//              The same rule shapes LSR.DR and the receive queue below: DR is
//              exactly "the queue is not empty", which is Spike's `rx_queue`.
//
//              WHY A TX FIFO: because LSR always reports ready, a byte store is
//              accepted on every cycle, so back-to-back stores (the natural way
//              to write a string) need somewhere to pile up while the line is
//              paced at `BIT_CYCLES` cycles per 8N1 bit cell. The queue is
//              `FIFO_DEPTH` bytes deep and a push that finds it full is DROPPED
//              and flagged in `tx_overflow_o` (sticky) — the testbench turns
//              that into a hard FAIL rather than a quietly shortened string.
//              `tx_busy_o` stays high until the queue is empty AND the shifter
//              is idle, so a bring-up harness can wait for the burst to drain.
//
//              THE RECEIVE PATH (E2-RV2 increment 6, G8) has three inputs, and
//              every one of them is the golden model's:
//                * the serial line `uart_rx_i` (idle high, 8N1, LSB first) is
//                  sampled at the centre of each bit cell by a two-flop
//                  synchroniser plus a small FSM, and a completed byte enters the
//                  same `FIFO_DEPTH`-deep queue Spike's `rx_queue` is;
//                * a THR store while `MCR.LOOP` is set injects the byte into that
//                  queue directly (Spike's `store` does exactly that, and *not*
//                  through the receiver) — this is the one injection route a
//                  DiffTest can drive, so `cor_uart_rx` uses it to compare the
//                  whole receive register interface against Spike;
//                * `FCR.CLEAR_RCVR` flushes the queue, `FCR.CLEAR_XMIT` has no
//                  state to clear (the transmitter is never busy), and both bits
//                  self-clear — Spike's `update_interrupt` behaviour.
//              A push into a full queue is dropped silently, as Spike drops it;
//              `rx_overflow_o` is the verification-status flag for it, and
//              `rx_frame_err_o` reports a start/stop-bit violation (Spike's model
//              has no framing-error bits at all, so a program-visible LSR.FE
//              would be a divergence of exactly the kind this file avoids).
//
//              THE INTERRUPT LINE, `irq_o`, IS THE GOLDEN MODEL'S `interrupts != 0`:
//              `(IER.RDI && LSR.DR) | IER.THRI` — Spike ORs the two causes into
//              one IIR value, so with an empty-transmitter always ready and
//              IER = 0b11 the register reads 0xC6 while data is pending (the real
//              16550 would say line-status, 0x06), and the corpus pins that.
//              `irq_o` is presented for the state the access in flight leaves
//              behind, because Spike's device calls `set_interrupt_level` at the
//              END of the access: a store to IER or a loopback byte store must be
//              visible to the PLIC in the very cycle it is accepted, exactly as
//              the CLINT pushes its lines combinationally. `irq_upd_o` says "the
//              device re-evaluated the line on this access" — Spike's
//              `set_interrupt_level` call — which the PLIC needs because the
//              latter re-latches a source's pending priority on every call.
//
//              FRAME FORMAT: 8 data bits, no parity, 1 stop bit (8N1), LSB first,
//              one start bit: ten bit cells of `BIT_CYCLES` cycles each
//              (`BIT_CYCLES` = the clock divisor, i.e. clk / baud; e.g. 16 for a
//              100 MHz sim clock, 217 for 115200 baud at 25 MHz). That is a
//              full-rate (1x) shift clock rather than C06's 16x oversampling: a
//              transmitter needs no oversampling — the phase of its bit clock is
//              trivial — and the receiver samples each cell at its centre, which
//              is what the testbench's own frame-timing assertions measure. The
//              divisor is a PARAMETER, not LCR/DLL/DLM: those registers are stored
//              and read back (Spike's model stores them and ignores them too), but
//              a bit rate derived from them is a board-level property that no
//              DiffTest can compare (E2-RV2 §3.6) — it stays a testbench assertion.
//
//              NOT IMPLEMENTED, and why: the modem-status deltas (RI/loopback
//              handshakes beyond MCR bit 4), parity and 2-stop-bit programming
//              (LCR bits 3..5 are stored but the shift is fixed 8N1), and a bit
//              rate programmed through DLL/DLM. None of them is observable in
//              Spike's model for any program the corpus can compare. `DLM` has no
//              reset value in Spike (its constructor leaves it uninitialised —
//              a probe read 0x5F), so the reset value here is 0 by choice;
//              nothing reads it without setting DLAB first.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 4: C14 §8 checkpoint 5 (UART hello)
//              2026-09-12 - E2-RV2 increment 6 (S5): receive path (RBR/LSR.DR,
//              FCR clear bits, MCR loopback), the RX interrupt line for the PLIC,
//              and MSR corrected to Spike's `0xB0` (DCD|DSR|CTS — the previous
//              0xD0 was an arithmetic slip in the constant, never observed because
//              no program read it)
// Tags:        RTL, SYNTH
// Plan-Ref:    ethereal-plan/components/C14-eth_rv-RV64核心.md §4 (MMIO via the D port),
//              §8 checkpoint 5 (bare-metal hello over UART) ·
//              ethereal-plan/components/C06-IO组件.md §2 (UART: baud generator + shift, 16550 subset) ·
//              ethereal-plan/subsystems/S15-应用处理器子系统.md §2.2, §5
// Notes:       One-byte-register slave: the D-port beat is narrowed in front of
//              this module (eth_rv_mmio_mux), which is why the register offset
//              arrives here as a 3-bit port. `ready_o` is combinational (a
//              register access completes in the cycle it is requested) — the
//              core's D port is a held-until-ready contract, and a single-cycle
//              accept is what the behavioral memory of the v0 testbench does too.
//              Two-segment FSMs (transmit and receive), no procedural loops, no
//              vendor primitives (ADR-017); `-Wall` clean without waivers.
module eth_rv_uart #(
    parameter int unsigned BIT_CYCLES = 16,   // clock cycles per 8N1 bit cell (clk / baud)
    parameter int unsigned FIFO_DEPTH = 64    // transmit AND receive queue depth in bytes
) (
    input  logic       clk_i,
    input  logic       rst_ni,

    // ---- byte-register MMIO slave ----
    input  logic       req_i,       // register access this cycle
    input  logic       we_i,        // 1 = store, 0 = load
    input  logic [2:0] off_i,       // register offset within the peripheral (addr[2:0])
    input  logic [7:0] wdata_i,     // store data (already narrowed to the addressed byte lane)
    output logic       ready_o,     // access accepted (always — see the LSR note above)
    output logic [7:0] rdata_o,     // load data

    // ---- serial line + verification status ----
    input  logic       uart_rx_i,    // 8N1 serial input (idle high)
    output logic       uart_tx_o,    // 8N1 serial output (idle high)
    output logic       tx_busy_o,    // queue non-empty or a frame is on the line
    output logic       tx_overflow_o, // sticky: a transmit byte was dropped
    output logic       rx_overflow_o, // sticky: a received byte was dropped
    output logic       rx_frame_err_o, // sticky: a start/stop bit was violated

    // ---- interrupt line to the PLIC (source 1 of the SoC's interrupt map) ----
    output logic       irq_o,        // `(IER.RDI && LSR.DR) | IER.THRI`, Spike's rule
    output logic       irq_upd_o     // this access re-evaluated `irq_o` (a device update)
);

    // ---------------------------------------------------------------- register map
    localparam logic [2:0] REG_DATA = 3'd0;  // R: RBR  / W: THR (DLAB: DLL)
    localparam logic [2:0] REG_IER  = 3'd1;  // R/W: IER       (DLAB: DLM)
    localparam logic [2:0] REG_IIR  = 3'd2;  // R: IIR  / W: FCR
    localparam logic [2:0] REG_LCR  = 3'd3;
    localparam logic [2:0] REG_MCR  = 3'd4;
    localparam logic [2:0] REG_LSR  = 3'd5;
    localparam logic [2:0] REG_MSR  = 3'd6;
    localparam logic [2:0] REG_SCR  = 3'd7;

    // Read-only status values, chosen to equal Spike's ns16550 model exactly
    // (riscv/ns16550.cc: lsr = TEMT|THRE from construction, msr = DCD|DSR|CTS,
    // iir = 0x01 base | 0xC0 type bits, and UART_IIR_RDI / UART_IIR_THRI once the
    // corresponding enable bit is set).
    localparam logic [7:0] LSR_VALUE = 8'h60;   // TEMT|THRE: the transmitter is never busy
    localparam logic [7:0] MSR_VALUE = 8'hB0;   // DCD|DSR|CTS (Spike's reset value)
    localparam logic [7:0] IIR_BASE  = 8'hC0;   // UART_IIR_TYPE_BITS
    localparam logic [7:0] IIR_RDI   = 8'h04;   // UART_IIR_RDI
    localparam logic [7:0] IIR_THRI  = 8'h02;   // UART_IIR_THRI
    localparam logic [7:0] IIR_NONE  = 8'h01;   // UART_IIR_NO_INT

    logic [3:0] ier_r;
    logic [7:0] dll_r;
    logic [7:0] dlm_r;
    logic [7:0] lcr_r;
    logic [7:0] mcr_r;
    logic [7:0] scr_r;

    localparam int unsigned PTR_W = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int unsigned CNT_W = $clog2(FIFO_DEPTH + 1);

    logic dlab;
    logic loop;
    logic thr_wr;      // a real transmit byte this cycle
    logic thr_inj;     // a loopback byte this cycle (Spike's MCR.LOOP path)
    logic rbr_rd;      // a receive-buffer read that pops this cycle
    logic ier_wr;
    logic fcr_wr;
    logic fcr_clr_rcvr;

    assign dlab         = lcr_r[7];
    assign loop         = mcr_r[4];
    assign thr_wr       = req_i && we_i && (off_i == REG_DATA) && !dlab && !loop;
    assign thr_inj      = req_i && we_i && (off_i == REG_DATA) && !dlab && loop;
    assign ier_wr       = req_i && we_i && (off_i == REG_IER) && !dlab;
    assign fcr_wr       = req_i && we_i && (off_i == REG_IIR);
    // FCR bit 1 (CLEAR_RCVR) flushes the receive queue; bit 2 (CLEAR_XMIT) sets
    // TEMT|THRE, which this model holds permanently high, so accepting it is a
    // no-op. Both self-clear, and bit 0 (ENABLE_FIFO) only gates Spike's terminal
    // poll — unobservable here (see the header's receive-path note).
    assign fcr_clr_rcvr = fcr_wr && wdata_i[1];

    // ------------------------------------------------------------ receive queue
    // One queue, Spike's `rx_queue`: a push is a loopback store or a completed
    // frame, a pop is an RBR read, and LSR.DR is exactly "not empty".
    logic [7:0]      rx_fifo_r [0:FIFO_DEPTH-1];
    logic [PTR_W-1:0] rx_wr_ptr_r;
    logic [PTR_W-1:0] rx_rd_ptr_r;
    logic [CNT_W-1:0] rx_count_r;
    logic             rx_full;
    logic             rx_empty;
    logic             rx_push;
    logic             rx_pop;
    logic             rx_flush;
    logic             rx_drop;
    logic             rx_overflow_r;
    logic             rx_frame_err_r;

    assign rx_full  = (rx_count_r == CNT_W'(FIFO_DEPTH));
    assign rx_empty = (rx_count_r == {CNT_W{1'b0}});
    assign rbr_rd   = req_i && !we_i && (off_i == REG_DATA) && !dlab;
    assign rx_pop   = rbr_rd && !rx_empty;
    assign rx_flush = fcr_clr_rcvr;
    assign rx_push  = (thr_inj || rx_done) && !rx_flush;
    assign rx_drop  = (thr_inj || rx_done) && (rx_flush || rx_full);

    // --------------------------------------------------------- receive receiver
    // A 2-flop synchroniser and a mid-cell sampler. The frame is 8N1: the start
    // cell is sampled half a cell after its falling edge (that IS its centre),
    // then one data bit per BIT_CYCLES cycles, LSB first, then the stop bit.
    logic        rx_sync0_r;
    logic        rx_sync1_r;
    logic        rx_bit_in;
    logic        rx_start_edge;

    typedef enum logic [1:0] {
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3
    } rx_state_e;

    rx_state_e         rx_state_r;
    rx_state_e         rx_state_nxt;
    logic [3:0]        rx_bit_r;
    logic [3:0]        rx_bit_nxt;
    logic [7:0]        rx_shift_r;
    logic [7:0]        rx_shift_nxt;
    logic [15:0]       rx_baud_r;
    logic [15:0]       rx_baud_nxt;
    logic              rx_cell_done;
    logic              rx_done;        // a frame completed this cycle
    logic              rx_frame_err;

    // A falling edge of the SYNCHRONISED line: `rx_sync0_r` IS the line one cycle
    // back, so the edge is "the older sample high, the newer low" — the inverted
    // comparison would be an edge that never happens.
    assign rx_bit_in     = rx_sync1_r;
    assign rx_start_edge = rx_sync1_r && !rx_sync0_r;
    assign rx_cell_done  = (rx_baud_r == 16'd0);

    // One cell: the first (start-bit) wait is half a cell, every later one a whole
    // cell, so each sample lands at the centre of its cell.
    always_comb begin
        rx_state_nxt   = rx_state_r;
        rx_bit_nxt     = rx_bit_r;
        rx_shift_nxt   = rx_shift_r;
        rx_baud_nxt    = rx_cell_done ? 16'(BIT_CYCLES - 1) : (rx_baud_r - 16'd1);
        rx_done        = 1'b0;
        rx_frame_err   = 1'b0;
        case (rx_state_r)
            RX_IDLE: begin
                if (rx_start_edge) begin
                    rx_state_nxt = RX_START;
                    rx_baud_nxt  = 16'((BIT_CYCLES / 2) - 1);
                    rx_bit_nxt   = 4'd0;
                    rx_shift_nxt = 8'h00;
                end
            end
            RX_START: begin
                if (rx_cell_done) begin
                    if (rx_bit_in) begin      // the start cell must still be low
                        rx_frame_err = 1'b1;
                        rx_state_nxt = RX_IDLE;
                    end else begin
                        rx_state_nxt = RX_DATA;
                    end
                end
            end
            RX_DATA: begin
                if (rx_cell_done) begin
                    rx_shift_nxt = {rx_bit_in, rx_shift_r[7:1]};   // LSB first
                    if (rx_bit_r == 4'd7) begin
                        rx_state_nxt = RX_STOP;
                    end else begin
                        rx_bit_nxt = rx_bit_r + 4'd1;
                    end
                end
            end
            default: begin                    // RX_STOP
                if (rx_cell_done) begin
                    if (!rx_bit_in) rx_frame_err = 1'b1;           // the stop cell must be high
                    else begin
                        rx_done = 1'b1;                            // a whole byte, ready to queue
                    end
                    rx_state_nxt = RX_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync0_r <= 1'b1;
            rx_sync1_r <= 1'b1;
            rx_state_r <= RX_IDLE;
            rx_bit_r   <= 4'd0;
            rx_shift_r <= 8'h00;
            rx_baud_r  <= 16'd0;
        end else begin
            rx_sync0_r <= uart_rx_i;
            rx_sync1_r <= rx_sync0_r;
            rx_state_r <= rx_state_nxt;
            rx_bit_r   <= rx_bit_nxt;
            rx_shift_r <= rx_shift_nxt;
            rx_baud_r  <= rx_baud_nxt;
        end
    end

    logic [7:0] rx_push_data;
    assign rx_push_data = thr_inj ? wdata_i : rx_shift_r;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_wr_ptr_r <= '0;
            rx_rd_ptr_r <= '0;
            rx_count_r  <= '0;
        end else begin
            if (rx_flush) begin
                // Spike empties the queue (`while (!rx_queue.empty()) pop()`), so an
                // empty ring has its read pointer AT the write pointer. Zeroing the
                // count alone would leave the read pointer on a byte the flush
                // dropped and the next read would return a stale entry — the
                // DiffTest caught exactly that on `cor_uart_rx`.
                rx_count_r  <= '0;
                rx_rd_ptr_r <= rx_wr_ptr_r;
            end else begin
                if (rx_push && !rx_full) begin
                    rx_fifo_r[rx_wr_ptr_r] <= rx_push_data;
                    rx_wr_ptr_r            <= rx_wr_ptr_r + 1'b1;
                end
                if (rx_pop) rx_rd_ptr_r <= rx_rd_ptr_r + 1'b1;
                case ({rx_push && !rx_full, rx_pop})
                    2'b10:   rx_count_r <= rx_count_r + 1'b1;
                    2'b01:   rx_count_r <= rx_count_r - 1'b1;
                    default: rx_count_r <= rx_count_r;
                endcase
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_overflow_r  <= 1'b0;
            rx_frame_err_r <= 1'b0;
        end else begin
            if (rx_drop)         rx_overflow_r  <= 1'b1;
            if (rx_frame_err)    rx_frame_err_r <= 1'b1;
        end
    end

    assign rx_overflow_o  = rx_overflow_r;
    assign rx_frame_err_o = rx_frame_err_r;

    // ------------------------------------------------------------ interrupt line
    // Spike's `update_interrupt`, evaluated for the state the access in flight
    // leaves behind (`*_eff`): the device calls `set_interrupt_level` at the end
    // of the access, so the PLIC must see the new level in that very cycle.
    // Only RDI (bit 0) and THRI (bit 1) drive the line: Spike's `update_interrupt`
    // ignores RLSI and MSI, so the other two enable bits are stored, read back and
    // otherwise inert (the corpus pins IIR for that).
    logic [1:0]  ier_eff;
    logic [CNT_W-1:0] rx_count_eff;
    logic        dr_eff;

    assign ier_eff = ier_wr ? wdata_i[1:0] : ier_r[1:0];
    assign rx_count_eff = rx_flush ? {CNT_W{1'b0}}
                         : (rx_count_r + (((rx_push && !rx_full) ? CNT_W'(1) : CNT_W'(0))
                                          - (rx_pop ? CNT_W'(1) : CNT_W'(0))));
    assign dr_eff  = (rx_count_eff != {CNT_W{1'b0}});
    assign irq_o      = (ier_eff[0] && dr_eff) || ier_eff[1];
    // A completed frame is an update too: Spike's terminal `tick()` pushes the byte
    // and then calls `update_interrupt()`, which is what raises the line.
    // The accesses that make the device re-evaluate it are a THR/IER/FCR/LCR/MCR
    // store and an RBR read — the ones Spike's `update_interrupt` follows.
    assign irq_upd_o  = rx_done
                        || (req_i && (we_i ? ((off_i == REG_DATA) || (off_i == REG_IER)
                                              || (off_i == REG_IIR) || (off_i == REG_LCR)
                                              || (off_i == REG_MCR))
                                          : (off_i == REG_DATA)));

    // ------------------------------------------------------------ register read
    always_comb begin
        rdata_o = 8'h00;
        case (off_i)
            REG_DATA: rdata_o = dlab ? dll_r : (rx_empty ? 8'h00 : rx_fifo_r[rx_rd_ptr_r]);
            REG_IER:  rdata_o = dlab ? dlm_r : {4'd0, ier_r};
            REG_IIR:  rdata_o = IIR_BASE
                                | (((ier_r[0] && !rx_empty) ? IIR_RDI : 8'h00)
                                   | (ier_r[1] ? IIR_THRI : 8'h00))
                                | (((ier_r[0] && !rx_empty) || ier_r[1]) ? 8'h00 : IIR_NONE);
            REG_LCR:  rdata_o = lcr_r;
            REG_MCR:  rdata_o = mcr_r;
            REG_LSR:  rdata_o = LSR_VALUE | (rx_empty ? 8'h00 : 8'h01);   // DR = queue
            REG_MSR:  rdata_o = MSR_VALUE;
            default:  rdata_o = scr_r;                                     // REG_SCR
        endcase
    end

    assign ready_o = 1'b1;

    // ------------------------------------------------------------ register write
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ier_r <= 4'h0;
            dll_r <= 8'h0c;   // Spike's ns16550 reset value (dll = 0x0C)
            dlm_r <= 8'h00;   // Spike leaves dlm uninitialised; 0 is our choice (see Notes)
            lcr_r <= 8'h00;
            mcr_r <= 8'h08;   // MCR.OUT2, Spike's ns16550 reset value
            scr_r <= 8'h00;
        end else if (req_i && we_i) begin
            case (off_i)
                REG_DATA: if (dlab) dll_r <= wdata_i;
                REG_IER:  if (dlab) dlm_r <= wdata_i; else ier_r <= wdata_i[3:0];
                REG_LCR:  lcr_r <= wdata_i;
                REG_MCR:  mcr_r <= wdata_i;
                REG_SCR:  scr_r <= wdata_i;
                default:  ;   // FCR, LSR and MSR carry no writable state of their own
            endcase
        end
    end

    // =====================================================================
    // Transmit path: queue + 8N1 shifter (unchanged since increment 4)
    // =====================================================================
    localparam int unsigned BAUD_W = (BIT_CYCLES <= 1) ? 1 : $clog2(BIT_CYCLES);

    typedef enum logic [1:0] {
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3
    } tx_state_e;

    logic [7:0]        fifo_r [0:FIFO_DEPTH-1];
    logic [PTR_W-1:0]  wr_ptr_r;
    logic [PTR_W-1:0]  rd_ptr_r;
    logic [CNT_W-1:0]  count_r;
    logic              fifo_empty;
    logic              fifo_full;
    logic              tx_pop;
    logic              tx_overflow_r;

    tx_state_e         tx_state_r;
    tx_state_e         tx_state_nxt;
    logic [3:0]        tx_bit_r;
    logic [3:0]        tx_bit_nxt;
    logic [7:0]        tx_shift_r;
    logic [7:0]        tx_shift_nxt;
    logic [BAUD_W-1:0] tx_baud_r;
    logic [BAUD_W-1:0] tx_baud_nxt;

    logic              cell_done;
    logic              frame_end;
    logic              start_frame;

    assign fifo_empty = (count_r == {CNT_W{1'b0}});
    assign fifo_full  = (count_r == CNT_W'(FIFO_DEPTH));
    assign cell_done  = (tx_baud_r == {BAUD_W{1'b0}});

    // The stop cell of a frame ends here: a queued byte starts its start bit in
    // the very next cycle, so back-to-back frames are exactly 10 * BIT_CYCLES
    // apart with no idle bit between them (which is what a transmitter with a
    // byte ready has to do, and what the testbench's bit-timing assertion
    // measures as the start-edge-to-start-edge distance).
    assign frame_end   = (tx_state_r == TX_STOP) && cell_done;
    assign start_frame = !fifo_empty && ((tx_state_r == TX_IDLE) || frame_end);
    assign tx_pop      = start_frame;

    // The bit-cell counter restarts every cell; a cell is `BIT_CYCLES` cycles
    // long, so a frame (start + 8 data + stop) is exactly 10 * BIT_CYCLES.
    always_comb begin
        tx_state_nxt = tx_state_r;
        tx_bit_nxt   = tx_bit_r;
        tx_shift_nxt = tx_shift_r;
        tx_baud_nxt  = cell_done ? BAUD_W'(BIT_CYCLES - 1) : (tx_baud_r - 1'b1);
        if (start_frame) begin                  // load the next queued frame
            tx_state_nxt = TX_START;
            tx_shift_nxt = fifo_r[rd_ptr_r];
            tx_bit_nxt   = 4'd0;
            tx_baud_nxt  = BAUD_W'(BIT_CYCLES - 1);
        end else begin
            case (tx_state_r)
                TX_START: begin
                    if (cell_done) tx_state_nxt = TX_DATA;
                end
                TX_DATA: begin
                    if (cell_done) begin
                        tx_shift_nxt = {1'b0, tx_shift_r[7:1]};   // LSB first
                        if (tx_bit_r == 4'd7) tx_state_nxt = TX_STOP;
                        else tx_bit_nxt = tx_bit_r + 4'd1;
                    end
                end
                default: begin                  // TX_IDLE (queue empty), TX_STOP (queue empty)
                    if (cell_done) tx_state_nxt = TX_IDLE;
                end
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_state_r <= TX_IDLE;
            tx_bit_r   <= 4'd0;
            tx_shift_r <= 8'h00;
            tx_baud_r  <= {BAUD_W{1'b0}};
        end else begin
            tx_state_r <= tx_state_nxt;
            tx_bit_r   <= tx_bit_nxt;
            tx_shift_r <= tx_shift_nxt;
            tx_baud_r  <= tx_baud_nxt;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_r <= '0;
            rd_ptr_r <= '0;
            count_r  <= '0;
        end else begin
            if (thr_wr && !fifo_full) begin
                fifo_r[wr_ptr_r] <= wdata_i;
                wr_ptr_r         <= wr_ptr_r + 1'b1;
            end
            if (tx_pop) begin
                rd_ptr_r <= rd_ptr_r + 1'b1;
            end
            case ({thr_wr && !fifo_full, tx_pop})
                2'b10:   count_r <= count_r + 1'b1;
                2'b01:   count_r <= count_r - 1'b1;
                default: count_r <= count_r;
            endcase
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_overflow_r <= 1'b0;
        end else if (thr_wr && fifo_full) begin
            tx_overflow_r <= 1'b1;
        end
    end

    assign tx_overflow_o = tx_overflow_r;
    assign tx_busy_o     = (tx_state_r != TX_IDLE) || !fifo_empty;

    // The line: idle mark (high), start bit (low), 8 data bits LSB first, stop (high).
    assign uart_tx_o = (tx_state_r == TX_START) ? 1'b0
                     : (tx_state_r == TX_DATA)  ? tx_shift_r[0]
                     : 1'b1;

endmodule
`default_nettype wire
