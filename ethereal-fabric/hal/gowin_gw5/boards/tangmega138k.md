# Tang Mega 138K Dock — board notes (hal/gowin_gw5)

> Plan-Ref: `ethereal-plan/components/C12-平台组件.md` §3 (constraints) §6 (open items)
> Status: notes only — pin/constraint files are generated from the Board
> Manifest (C12 §3 single-source rule), which is itself blocked on open item 1.

## Device

- FPGA: **Gowin GW5AST-LV138PG484AC1/I0** (GW5AST-138C chip family), 138,240 LUT4,
  BSRAM + DSP hard blocks, PG484A package (324 user IOB).
- Open-chain support confirmed by the E1-PLT4 spike (2026-09-01):
  yosys `synth_gowin -family gw5a` → nextpnr-himbaechel
  `--device GW5AST-LV138PG484AC1/I0` → `gowin_pack -d GW5AST-138C`;
  chipdb ships with oss-cad-suite; openFPGALoader has a `tangmega138k` board
  entry (FT2232).
- Reference constraint example: apicula `examples/gw5a/tangmega138k.cst`
  (clk pin V22, LED row) — used by the spike's probe wrapper; **authoritative
  pins must come from the Dock schematic via the Board Manifest, not from the
  example**.

## Clocks

- ASSUMPTION (TBD, 2026-09-01): main crystal frequency + clock-capable pin
  unconfirmed (C12 §6 #1). `glue/gowin_clkstub.sv` carries placeholder
  `CLKIN_HZ = 50 MHz` → `CLKOUT_HZ = 100 MHz` sys_clk with 75/50 MHz fallback
  gears per C12 §2.3.
- Rescue clock: GW5 on-chip oscillator (OSC hard block, ~2.5 MHz class —
  exact GW5A OSC frequency TBD) via DCS dynamic switch, per C12 §2.1. Glue
  module for OSC/DCS is a follow-up when the reset sequencer lands (E1-SHL*).

## Host link (ADR-008)

- SPI (data/config) + I2C (PMBus-style monitor) pin assignment: **TBD**, Board
  Manifest deliverable. JTAG/UART debug pins likewise TBD.
- ADR-007: region logic never touches physical pins; L1 pin mux + L2 protocol
  proxy live in the Shell, so this directory holds no IO logic — only `.cst`
  templates generated later from the Manifest.

## Flash

- On-board 128 Mbit SPI Flash: v1 accesses it via a generic (inferable) SPI
  controller; the MSPI dedicated-port primitive remains a C13 §4 exception
  candidate if bandwidth demands it (no glue module yet — add here if taken).

## Bitstream / flash layout

- `base.fs` from gowin_pack is ~34.7 MB for a 4×4-fabric build (E1-PLT4
  measured); Flash region layout (base / FW-A / FW-B / image pool / log) is
  C12 §6 #4, pending.
