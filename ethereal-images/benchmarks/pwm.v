// SPDX-License-Identifier: MIT
// Module:      pwm
// Function:    Combinational PWM comparator. `out` is high while the (external)
//              free-running counter value `count` is below the duty threshold
//              `duty`:  out = (count < duty).
// Size est.:   ~6-8 eLUT4 (one 8-bit unsigned less-than).
// Why combinational: the counter is an INPUT, so the DUT is pure combinational
//              and bit-true-testable without a clocking harness. (fabric_sim's
//              eLUT4-FF path has no per-cycle step interface — see E0-MAP5
//              report — so all Phase-0 benchmarks are kept combinational.)
// Golden convention: drive `count` and `duty` as 8-bit integers; `out` is the
//              single PO. make_golden_tb: apply random (count, duty) vectors,
//              #1 settle, $display count/duty/out.
// Tags:        BENCHMARK, COMBINATIONAL
// Plan-Ref:    ethereal-plan (E0-MAP5 benchmark set)
`default_nettype none

module pwm #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] duty,
    input  wire [WIDTH-1:0] count,
    output wire             out
);

    assign out = (count < duty);

endmodule
`default_nettype wire
