`default_nettype none
// SPDX-License-Identifier: CERN-OHL-S-2.0
// Module:      eth_rv_uart
// Description: MMIO console UART (transmit) for the eth_rv SoC — the C14 §8
//              checkpoint 5 bring-up peripheral: a bare-metal `hello` becomes
//              visible on a serial line, on a channel independent of the
//              BMC/mFSM mailbox (S15 §5, C06 "UART 16550 简化子集").
// Details:     REGISTER FILE (ns16550 subset, one BYTE register per offset, the
//              classic reg-shift = 0 / reg-io-width = 1 layout of C06 §2):
//
//                off  read            write         this implementation
//                0    RBR             THR           write = transmit byte (DLAB: DLL)
//                1    IER             IER           R/W (DLAB: DLM)
//                2    IIR             FCR           IIR computed; FCR store ignored
//                3    LCR             LCR           R/W (DLAB = lcr[7])
//                4    MCR             MCR           R/W (stored, no modem effect)
//                5    LSR             (test)        0x60 constant: TEMT|THRE
//                6    MSR             (unused)      0xD0 constant: DCD|DSR|CTS
//                7    SCR             SCR           R/W
//
//              WHY LSR IS A CONSTANT (the load-bearing decision): the whole
//              point of this peripheral is that a program driving it still
//              MATCHes Spike's commit trace *bit for bit* (C14 §5), and Spike's
//              own ns16550 (`riscv/ns16550.cc`, the golden model this register
//              file mirrors) has a transmitter that is *never* busy: `tx_byte()`
//              writes the character to the console and leaves TEMT|THRE set, so
//              `LSR` reads 0x60 forever and a `while (!(lsr & THRE)) ;` poll
//              costs exactly one iteration on the golden side. If this UART
//              instead reported its real (divider-paced) transmitter state,
//              every poll would retire a different NUMBER of instructions than
//              Spike's and the two streams could not match at all. The
//              register-visible status is therefore the same "ready" model, and
//              the physical transmitter's real state is exported as the
//              `tx_busy_o`/`tx_overflow_o` ports — verification status, not
//              program-visible state (a MMIO status bit that Spike does not have
//              would be exactly the divergence this design exists to avoid).
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
//              FRAME FORMAT: 8 data bits, no parity, 1 stop bit (8N1), LSB
//              first, one start bit: ten bit cells of `BIT_CYCLES` cycles each
//              (`BIT_CYCLES` = the clock divisor, i.e. clk / baud; e.g. 16 for a
//              100 MHz sim clock, 217 for 115200 baud at 25 MHz). That is a
//              full-rate (1x) shift clock rather than C06's 16x oversampling:
//              a transmitter needs no oversampling — the phase of its bit clock
//              is trivial — so the divisor counter is exact and there is no
//              sampling-phase error to budget, which is why the testbench can
//              assert the frame timing as an exact cycle count.
//
//              NOT IMPLEMENTED, and why: the receiver (RBR/LSR.DR), the FCR
//              FIFO-clear bits and MCR loopback. Each of them is unobservable in
//              Spike's model for a program that only transmits (`rx_queue` stays
//              empty unless the program enables the FIFO, `lsr` stays 0x60), so
//              a TX-only console mirrors the golden byte for byte. A corpus
//              program that writes FCR bit 0, reads RBR or enables loopback would
//              leave that equivalence — see verif/eth_rv/README.md.
//              `DLM` has no reset value in Spike (its constructor leaves it
//              uninitialised), so the reset value here is 0 by choice; nothing
//              reads it without setting DLAB first.
// Maintainer:  BaiTian6641
// Created:     2026-09-12
// Modified:    2026-09-12 - E2-RV1 increment 4: C14 §8 checkpoint 5 (UART hello)
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
//              accept is what the behavioral memory of the v0 testbench does
//              too. Two-segment TX FSM, no procedural loops, no vendor
//              primitives (ADR-017); `-Wall` clean without waivers.
module eth_rv_uart #(
    parameter int unsigned BIT_CYCLES = 16,   // clock cycles per 8N1 bit cell (clk / baud)
    parameter int unsigned FIFO_DEPTH = 64    // transmit queue depth in bytes
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
    output logic       uart_tx_o,    // 8N1 serial output (idle high)
    output logic       tx_busy_o,    // queue non-empty or a frame is on the line
    output logic       tx_overflow_o // sticky: a transmit byte was dropped
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
    // iir = 0x01 base | 0xC0 type bits, and UART_IIR_THRI once IER.THRI is set).
    localparam logic [7:0] LSR_VALUE = 8'h60;
    localparam logic [7:0] MSR_VALUE = 8'hD0;
    localparam logic [7:0] IIR_BASE  = 8'hC0;

    logic [7:0] ier_r;
    logic [7:0] dll_r;
    logic [7:0] dlm_r;
    logic [7:0] lcr_r;
    logic [7:0] mcr_r;
    logic [7:0] scr_r;

    logic       dlab;
    logic       thr_wr;

    assign dlab   = lcr_r[7];
    assign thr_wr = req_i && we_i && (off_i == REG_DATA) && !dlab;

    // ------------------------------------------------------------ register read
    always_comb begin
        rdata_o = 8'h00;
        case (off_i)
            REG_DATA: rdata_o = dlab ? dll_r : 8'h00;                      // RBR (no RX: 0)
            REG_IER:  rdata_o = dlab ? dlm_r : ier_r;
            REG_IIR:  rdata_o = IIR_BASE | (ier_r[1] ? 8'h02 : 8'h01);     // IIR.THRI when enabled
            REG_LCR:  rdata_o = lcr_r;
            REG_MCR:  rdata_o = mcr_r;
            REG_LSR:  rdata_o = LSR_VALUE;
            REG_MSR:  rdata_o = MSR_VALUE;
            default:  rdata_o = scr_r;                                     // REG_SCR
        endcase
    end

    assign ready_o = 1'b1;

    // ------------------------------------------------------------ register write
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ier_r <= 8'h00;
            dll_r <= 8'h0c;   // Spike's ns16550 reset value (dll = 0x0C)
            dlm_r <= 8'h00;   // Spike leaves dlm uninitialised; 0 is our choice (see Notes)
            lcr_r <= 8'h00;
            mcr_r <= 8'h08;   // MCR.OUT2, Spike's ns16550 reset value
            scr_r <= 8'h00;
        end else if (req_i && we_i) begin
            case (off_i)
                REG_DATA: if (dlab) dll_r <= wdata_i;
                REG_IER:  if (dlab) dlm_r <= wdata_i; else ier_r <= wdata_i & 8'h0f;
                REG_LCR:  lcr_r <= wdata_i;
                REG_MCR:  mcr_r <= wdata_i;
                REG_SCR:  scr_r <= wdata_i;
                default:  ;   // IIR/FCR, LSR, MSR carry no writable state (see Details)
            endcase
        end
    end

    // =====================================================================
    // Transmit path: queue + 8N1 shifter
    // =====================================================================
    localparam int unsigned PTR_W  = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int unsigned CNT_W  = $clog2(FIFO_DEPTH + 1);
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
