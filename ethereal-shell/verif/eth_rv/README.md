# `eth_rv` DiffTest harness

Lockstep-style commit-trace DiffTest for the self-developed `eth_rv` RISC-V core
(**S15-应用处理器子系统.md §2.2**: *"验证 >> RTL —— 第一天就上 DiffTest 锁步 co-sim vs Spike"*,
ADR-018 rev3). The reference model is Spike; the DUT is anything that can emit an
ordered stream of retired instructions — today a trace file, an in-process
callback, or the worked-example Python interpreter in `rv_model.py`; tomorrow the
`eth_rv` RTL testbench, plugged into the same seam with no harness rework.

Nothing here depends on `eth_rv` existing yet: the harness, the corpus and the
protocol are in place so the first RTL commit lands into a working verification
vehicle.

```
Spike ──(--log-commits)──► rv_spike ──normalize──┐
                                                 ├─► rv_difftest ──► MATCH / first DIVERGENCE
DUT ──(dump file | callback | model)──► rv_dut ──┘   (pc / rd / value / memory, exit code)
```

## Quick start

```bash
# 1. one-time: build Spike (and its dtc dependency) into generated/ (gitignored)
mkdir -p generated/rv_difftest && cd generated/rv_difftest
git clone https://github.com/riscv-software-src/riscv-isa-sim.git spike
git clone https://github.com/dgibson/dtc.git dtc
make -C dtc -j"$(nproc)" NO_PYTHON=1
cd spike && mkdir -p build && cd build
PATH="$PWD/../../../dtc:$PATH" ../configure --prefix="$PWD/../install"
make -j"$(nproc)" && make install          # -> generated/rv_difftest/spike/install/bin/spike

# 2. build the bare-metal corpus (needs riscv64-unknown-elf-gcc)
python3 ethereal-shell/verif/eth_rv/corpus/build_corpus.py --out generated/rv_difftest/corpus

# 3. DiffTest: Spike golden vs the model DUT
python3 ethereal-shell/verif/eth_rv/rv_difftest.py \
    --elf generated/rv_difftest/corpus/cor_alu.elf \
    --dut model:generated/rv_difftest/corpus/cor_alu.elf
# -> MATCH: 221 commits compared, 0 divergence — pc, rd and value agree   (exit 0)

# 4. prove the harness actually catches a wrong DUT (fault injection demo)
python3 ethereal-shell/verif/eth_rv/rv_difftest.py \
    --elf generated/rv_difftest/corpus/cor_alu.elf \
    --dut model:generated/rv_difftest/corpus/cor_alu.elf \
    --inject 12:value=0xdeadbeef
# -> DIVERGENCE (value_mismatch) at commit #12 (cycle 13): pc=0x… rd=x…   (exit 1)

# 5. harness tests (no toolchain/Spike needed — fixtures are checked in)
.venv/bin/pytest -q ethereal-shell/verif/eth_rv/tests
.venv/bin/ruff check ethereal-shell/verif/eth_rv
.venv/bin/mypy --strict ethereal-shell/verif/eth_rv
```

Pinned upstream commits this harness was built and verified against:

| dependency | commit | notes |
|---|---|---|
| riscv-isa-sim (Spike) | `1e05ddac3a6c351bfc0aeed0cf3a68940e7200ab` (2026-09-11) | `Spike RISC-V ISA Simulator 1.1.1-dev` |
| dtc | `7a1e017926004ecff5fce62d62d42ce9f3e00082` (2026-09-08) | Spike shells out to `dtc` **at run time** to build its device tree; without it Spike cannot boot an ELF (`Failed to run dtc`) |

Neither is vendored: both live under `generated/rv_difftest/` (gitignored). If
Spike is installed elsewhere, point the harness at it with `--spike PATH` or
`$RV_DIFFTEST_SPIKE`; `$RV_DIFFTEST_DTC` overrides the `dtc` directory.

## Layout

| path | what it is |
|---|---|
| `rv_trace.py` | The protocol: `Commit` record, canonical trace format, parser/validator |
| `rv_image.py` | Program images (ELF64 loader with symbol lookup, or self-describing hex) |
| `rv_spike.py` | Golden generator: locate/run Spike, normalize `--log-commits` output |
| `rv_dut.py` | DUT adapters (`dump:` / `model:` / `callback:`) + fault injection |
| `rv_model.py` | Worked-example DUT: RV64IMC interpreter (RV64I + M + integer C subset) |
| `rv_difftest.py` | CLI + comparator: first divergence with pc/rd/cycle, exit codes |
| `corpus/` | Bare-metal RV64IMC corpus: `crt0.S`, `link.ld`, eight `cor_*.S` programs, builder |
| `tests/` | pytest suite; `tests/fixtures/` holds the checked-in golden fixtures |

## The trace protocol

One retired instruction per line, in the order the core retires them:

```
# rv_difftest trace v1
# generator: spike[rv64imc] cor_model.elf (Spike RISC-V ISA Simulator 1.1.1-dev)
# fields: cycle pc rd value [mem_addr mem_wdata [mem_rmask mem_wmask]]
1 0x0000000080000000 x2 0x000000008000a000
2 0x0000000080000004 x2 0x000000008000a000
3 0x0000000080000008 -  -
64 0x00000000800000ee - - 0x0000000080009fe0 0x0000000080000010
70 0x00000000800000fa x1 0x0000000080000010 0x0000000080009fe0 -
```

* `cycle` — commit ordinal. Spike is not cycle-accurate, so the golden stream
  numbers retirements 1..N; a DUT that knows its own commit cycles (an RTL
  testbench) may put those there instead. Use `--no-cycle-check` when the two
  streams legitimately disagree about cycles.
* `pc` — 64-bit program counter of the retired instruction.
* `rd` — `x0`..`x31` (ABI names like `a0`/`sp` are accepted on input), or `-`
  when the instruction writes no architectural register (stores, branches,
  `jal x0`, …). Writes to `x0` are dropped: RISC-V hard-wires it, and Spike does
  not log them either.
* `value` — 64-bit value written to `rd`, `-` when `rd` is `-`.
* the optional **memory suffix** (C14 §5.2): 6 fields add `mem_addr mem_wdata`
  and 8 fields add the two byte-lane masks. `mem_addr` is the exact byte address
  of the retired instruction's load/store, `mem_wdata` the store data in the
  golden model's convention (the low `size` bytes of the stored register,
  *unshifted* — exactly what Spike prints), and the masks are the byte lanes the
  access reads/writes **relative to the 8-byte-aligned window at
  `mem_addr & ~7`** (the RVFI convention). `-` in `mem_addr` means "this commit
  performs no memory access"; `-` in `mem_wdata` means "load"; `-` in a mask
  means "not reported".

The memory suffix is optional and variable-width, and so is the comparison: a
stream with no memory information at all (a 4-field dump) is still compared on
`pc`/`rd`/`value`, and the run then reports the memory stream as **not provided**
rather than silently passing it. Spike has no mask field, so a golden stream
never carries masks; a DUT that reports them gets them cross-checked against the
golden's load/store direction and for internal consistency (a mask must be a
contiguous run of lanes starting at `addr[2:0]`).

A DUT may also emit the lenient 3-field form `pc rd value` (cycle = line
ordinal) — that is what a Verilator testbench `$fwrite` naturally produces.
Lines are `#`-commented; blank lines are ignored. Anything else fails loudly with
`<source>:<line>: <message>` and exit code 2 — a malformed DUT dump never turns
into a silent "short trace".

The comparator checks, per commit: `cycle` (optional), `pc`, `rd`, `value` and
then the memory stream (`mem_addr`, `mem_wdata`, mask direction/consistency), and
reports the **first** divergence with kind, commit index, cycle, pc and register.
`insn` is carried along when the producer knows it (Spike does) purely for
debugging.

## Golden side: Spike

`--elf ELF` runs Spike as
`spike --isa=rv64imc -l --log-commits --log=<tmp> <ELF>` and normalizes its log.
Two details matter and are handled for you:

* **A trapping instruction is not committed.** Spike logs the exception
  (`core 0: exception trap_…, epc …`) instead of a commit line, so a trapping
  instruction appears in neither stream — the DUT must take the trap without
  emitting a trace record, which is what `eth_rv_core` does.
* **Spike's boot ROM is not the DUT.** Spike executes a debug ROM at `0x1000`
  (`auipc`/`csrr mhartid`/`ld`/`jr`) before jumping to the ELF entry; the golden
  stream starts at the first commit whose pc equals the ELF entry point.
* **Spike keeps committing after the exit store.** A program signals completion
  by storing to the HTIF mailbox (`tohost`); Spike notices asynchronously and
  keeps retiring the program's final spin loop for thousands of instructions.
  The golden stream therefore stops at the commit that stores to that address
  (read from the ELF symbol table), which is exactly where a DUT stops too.

`--golden TRACE` replays a captured stream instead, so the harness (and its
tests) run without Spike. A *canonical* trace needs nothing else; a *raw* Spike
log additionally needs `--elf` so the two rules above can be applied.

## DUT side: how the `eth_rv` RTL plugs in

The RTL is here now (`ethereal-shell/rtl/eth_rv/`, E2-RV1): the core's RVFI port
feeds the testbench below, and `ethereal-shell/verif/eth_rv_core/run_difftest.py`
(the `make verif-rv-rtl` target) drives the whole loop — corpus →
`$readmemh` image → Verilated run → `dump:` comparison → console assertion.

Three adapters, one contract: an ordered iterator of commits.

1. **Trace file — `--dut dump:PATH`.** The Verilator testbench writes one line
   per retirement; the harness diffs it. Nothing else is required:

   ```systemverilog
   // in the eth_rv testbench: pc, rd, value and the D-port access
   always @(posedge clk) if (commit_valid_r)
     $fwrite(trace_fd, "%0d 0x%016x %s 0x%016x 0x%016x 0x%016x - 0x%02x\n",
             cycle_r, pc_r, rd_r, wdata_r, mem_addr_r, mem_wdata_r, mem_wmask_r);
   ```

   Canonical 4-field lines are preferred; `pc rd value` (3 fields) is accepted,
   and so is the memory suffix (`ethereal-shell/verif/eth_rv_core/tb_eth_rv_core.sv`
   is the reference producer: it always emits the 8-field form).
2. **In-process callback — `--dut callback:MODULE:FUNC`.** `FUNC()` returns an
   iterable of `rv_trace.Commit` objects or trace-line strings; `MODULE` is
   imported with `--dut-path DIR` prepended to `sys.path`. This is the zero-I/O
   hook for a cocotb/Verilator testbench that imports the harness directly, and
   the natural place for a future `dut_eth_rv.py` that adapts the RTL's commit
   port (`pc`, `rd`, `wdata`, `valid`) to `Commit` objects.
3. **Worked example — `--dut model:PATH`.** `rv_model.py` is a bit-accurate
   RV64IMC interpreter that retires the same instruction sequence as Spike for
   the corpus (proved by `tests/test_rv_model.py`). It exists so the pass path
   and the first-divergence path are exercised by real runs *today*; treat it as
   the template for the RTL adapter, not as a permanent second core.

`--inject INDEX:FIELD=VALUE` corrupts one field of one DUT commit (`pc`/`rd`/
`value`/`cycle`/`mem_addr`/`mem_wdata`/`mem_rmask`/`mem_wmask`) — a demo/self-test
switch that proves the harness detects the class of bug the RTL will eventually
produce, memory stream included.

## Corpus

Eight self-checking bare-metal programs (`-march=rv64imc_zicsr -mabi=lp64 -nostdlib
-mcmodel=medany`, linked at `0x8000_0000` by `corpus/link.ld`, entered via
`corpus/crt0.S`):

| program | coverage |
|---|---|
| `cor_alu.S` | RV64I ALU/shift/compare/branch, identity cross-checks, C-extension ALU forms |
| `cor_mem.S` | all load/store widths, sign/zero extension, little-endian order, loops, stack |
| `cor_muldiv.S` | RV64M incl. high halves, div-by-zero, `INT64_MIN / -1`, W-forms |
| `cor_csr.S` | M-mode CSR read/write semantics: `mhartid`, `mscratch` (all three op forms + immediate), `misa` (read-only), `mie` (mask), `mip` (access legality), `mtvec` (MODE kept), `mepc` (bit 0 RO), `mcause`/`mtval`, `mstatus` (write mask) |
| `cor_trap.S` | the exception path: `ecall`, compressed/32-bit `ebreak`, illegal (32-bit + compressed), misaligned load/store (all widths + a compressed store), unimplemented CSR numbers, `mstatus` bookkeeping, trap-aborts-the-access, a MODE=1 `mtvec` |
| `cor_model.S` | the C forms the example DUT implements — source of the checked-in fixtures |
| `cor_hello.S` | the C14 §8 checkpoint 5 bring-up vehicle: polls the SoC UART's line-status register and writes a known string to its transmit register at `0x1000_0000`, then exits via HTIF — see "Console" below |
| `cor_fault.S` | the port error responses (E2-RV1 increment 5): access faults on addresses no region claims (loads *and* stores, incl. a 64-bit address above the AXI window), on a non-byte access to the one-byte-wide console page, and on a fetch outside mapped memory; plus the console page's byte-offset *aliasing* (the offsets that used to wedge) — see "Port error responses" below |

`main` returns 0 on success or the index of the first failed check; `crt0.S`
turns that into the HTIF exit store, so a corpus bug shows up as a non-zero
Spike exit status *and* as a divergent trace. `-mcmodel=medany` is required:
absolute `lui` addressing cannot materialize `0x8000_xxxx` on RV64, where `lui`
sign-extends from bit 31.

The corpus is built with `-march=rv64imc_zicsr` (binutils no longer implies
`Zicsr` from `I`, and `cor_csr`/`cor_trap` need the CSR instructions). Spike
enables `zicsr` for `--isa=rv64imc` by default, so nothing on the golden side
changes — and the RV64I/M/C programs assemble to the same bytes either way.

Toolchain note: `riscv64-unknown-elf-gcc 13.2.0` is a full RV64 toolchain
(`--print-multi-lib` offers `rv64i`/`rv64im`/`rv64imac`/`rv64imafdc`/…), but there
is **no `rv64imc` multilib** — C is folded into `rv64imac`/`rv64imafc`. That does
not matter here because the corpus is `-nostdlib -nostartfiles -ffreestanding`:
`-march=rv64imc -mabi=lp64` compiles and links as-is. If a future corpus program
needs libc/libgcc, build it for `rv64imac` (or add a multilib) — Spike and the
harness take the ISA string from `--isa`, so nothing else changes.

## Console: bare-metal `hello` over the SoC UART (C14 §8 checkpoint 5)

`cor_hello.S` is the bring-up vehicle the RV-B milestone is defined by: a
bare-metal program that makes itself visible on a serial line, on a channel
independent of the BMC/mFSM mailbox (S15 §5). The SoC side is
`ethereal-shell/rtl/eth_rv/eth_rv_uart.sv` (a 16550-subset byte-register
peripheral with an 8N1 transmit shifter and a parameterised clock divisor) behind
`ethereal-shell/rtl/eth_rv/eth_rv_mmio_mux.sv` (the D-port address decoder, on the
same `0x1000_0000` page Spike's own `ns16550` answers on). The testbench
(`verif/eth_rv_core/tb_eth_rv_core.sv`) decodes the serial line and the RTL runner
asserts the result:

```bash
PATH="$HOME/oss-cad-suite/bin:$PATH" make verif-rv-rtl          # all eight programs
python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_hello
# -> [rv-rtl] cor_hello: UART 15 bytes 'hello, eth_rv!\n' — 15 frames of 160 cycles
#            (16-cycle bit cell), gap 160..160, 0 frame error(s)
#    MATCH: 134 commits compared, 0 divergence — pc, rd and value agree
python3 ethereal-shell/verif/eth_rv_core/run_difftest.py --only cor_hello --uart-fault 0:1
# -> [rv-rtl] cor_hello: UART negative control caught: payload 'iello, eth_rv!\n' != …
```

What exactly is asserted, and why it is a *bit-timing* claim rather than a byte
count: the testbench samples each frame at the centre of its ten bit cells with
the same divisor the transmitter was built with, checks the start/stop levels
(framing), counts the frames, and measures the start-edge-to-start-edge distance
of every consecutive pair — they must all equal exactly `10 × BIT_CYCLES`. A
transmitter whose bit rate were off, or that left an idle bit between frames,
fails that measurement even if the bits happened to be sampled correctly.

The register-visible status of the UART is deliberately Spike's model rather than
the physical transmitter's: Spike's `ns16550` never reports a busy transmitter
(`tx_byte()` writes the character and leaves `TEMT|THRE` set), so `LSR` reads
`0x60` on both sides at all times and a `while (!(lsr & THRE)) ;` poll retires
exactly the same number of instructions under Spike and under the RTL. A UART
that exposed its real divider-paced state would make the poll loop take a
different number of iterations on each side, and the two commit streams could not
match at all. The physical state is exported as the module's `tx_busy_o` /
`tx_overflow_o` ports (verification status, not program-visible state), and the
testbench uses the first to know when the burst has drained and the second to FAIL
loudly if a byte was ever dropped. `expected` payloads are per-program
(`EXPECTED_UART` in `verif/eth_rv_core/run_difftest.py`): `hello` must produce its
string and every other program must leave the line completely idle.

Not implemented on purpose, and the reason: the receiver, the `FCR` FIFO-clear
bits and `MCR` loopback — each is unobservable in Spike's model for a program
that only transmits (`rx_queue` stays empty unless the program pushes to it, and
`lsr` stays `0x60`), so a transmit-only console mirrors the golden byte for byte.
Reading `RBR` with an empty queue is equivalent and is exercised (`cor_fault.S`
reads the aliased offset `0x1000_0010`, and both sides return 0 — the read's only
side effect is clearing `LSR.DR`, which is already clear, and no interrupt is
implemented to observe it). What stays out of scope until the RX path exists is a
program that enables the FIFO (`FCR`) or loopback (`MCR.LOOP`, which in Spike
pushes the written byte into `rx_queue`, so a later read would return it).

## Port error responses (E2-RV1 increment 5)

Nothing may hang on an access the platform cannot serve, and nothing may succeed
silently either. Every request on the core's two memory ports is therefore
answered **in the cycle it is made**, and when the access cannot be served the
answer is an *error response*: `eth_rv_core` samples `imem_err_i` with
`imem_ready_i` (a fetch) and `dmem_err_i` with `dmem_ready_i` (a data access), and
turns the pair into the architectural trap Spike raises for the same access:

| access | `mcause` | `mtval` |
|---|---|---|
| fetch of an address no region claims | 1 (instruction access fault) | the fetch address (`mepc` is the same value) |
| load the port cannot serve | 5 (load access fault) | the access address |
| store the port cannot serve | 7 (store access fault) | the access address |

The trapping instruction does not commit — no trace record, no register write,
for a store no bus transaction — which is exactly Spike's behaviour (it logs the
exception instead of a commit line), so the two streams still agree.

**What "cannot be served" means, per the golden model** (Spike was run on the
specific addresses before the RTL was written, not the other way round):

* an address no device and no memory claims — Spike's `bus_t` finds nothing for
  `0x2000_0000`/`0x4000_0000` (`mmio_load`/`mmio_fetch` return false) — including
  a 64-bit address above the D port's AXI window (`0x1_8000_0000`), which
  `eth_rv_axi_master` answers here and now instead of truncating the address into
  a valid window (a truncated address could land inside the DRAM socket and
  quietly succeed);
* inside the console page (`0x1000_0000`, 4 KiB): **a non-byte access**. Spike's
  `ns16550_t::load/store` return false when `reg_io_width != len`, and the width
  check also subsumes its page-crossing rejection (`addr + len > PGSIZE`). The
  RTL knows the access width from the core's `dmem_size_o`, which
  `eth_rv_mmio_mux.sv` checks;
* a read or write response the bus did not complete — the DRAM socket's `DECERR`
  for an address outside its window — reported per transaction by
  `eth_rv_axi_master.dmem_err_o`. An erroring read burst never validates the
  master's one-line read cache either, so a poisoned line cannot serve wrong
  bytes to the following sequential loads.

**The previous increment's note was wrong about one thing, and this is where the
correction lives**: an *unimplemented* offset inside the claimed console page
(`0x1000_0008`..`0x1000_0FFF`) is **not** an access fault in Spike. Its device
does `addr &= 7`, so every page offset aliases onto one of the eight byte
registers — `0x1000_000F` is the scratch register and `0x1000_0010` the receiver.
The RTL now aliases identically (a byte access anywhere in the page is answered),
and `cor_fault.S` checks both directions of that: the scratch register written at
`0x1000_0007` reads back at `0x1000_000F`, and `0x1000_0010` reads the (empty)
receiver. Those two offsets are also the regression control for the old wedge:
the D port used to answer neither.

**Wedge guard.** The testbench FAILs any port request that stays unanswered for
`PORT_STARVE_CYCLES` (4096) cycles, naming the address — much tighter than the
cycle budget, and asserted inside every run (the `PASS` line reports the longest
port wait actually seen: 0 cycles on the beat build, ≤ 13 on the AXI build,
where it is a real read-burst latency).

**Negative controls** (all sim-only, none of them reachable from the corpus):

| control | what it proves | evidence |
|---|---|---|
| `+starve_dmem=1` withholds the acknowledge for an out-of-window access — the old wedge, reproduced on purpose | the wedge guard is live | `ETH_RV_TB: FAIL the D port never answered the access at 0x0000000020000000 (4097 cycles, we=0) — wedge`, exit 1 |
| `+no_dmem_err=1` drops the error response, so an unservable access looks successful | the error response is load-bearing: the DUT then retires the access and the DiffTest catches it | `DIVERGENCE (pc_mismatch) at commit #20 (cycle 21)` — golden (Spike) is in the trap handler at `0x80000218`, the DUT still committing the faulting `ld` at `0x80000058` |
| `--fault INDEX:FIELD=VALUE` (the runner's standard control) | the comparator is live on the new program too | `--only cor_fault --fault 12:value=0xdeadbeef` → caught at commit #12 |

To run the first two by hand (the runner drives the trace comparison, these drive
only the testbench):

```bash
TB=generated/rv_difftest/rtl/obj_beat_lat0/Veth_rv_tb     # built by make verif-rv-rtl
$TB +mem=generated/rv_difftest/rtl/cor_fault.mem.hex +trace=/tmp/w.trace \
    +base=0x80000000 +tohost=0x80001000 +starve_dmem=1     # -> FAIL … wedge
$TB +mem=generated/rv_difftest/rtl/cor_fault.mem.hex +trace=/tmp/s.trace \
    +base=0x80000000 +tohost=0x80001000 +no_dmem_err=1     # -> PASS, but the trace diverges
python3 ethereal-shell/verif/eth_rv/rv_difftest.py --elf generated/rv_difftest/corpus/cor_fault.elf \
    --dut dump:/tmp/s.trace                                # -> DIVERGENCE at commit #20
```

### Known deviations from Spike's map (reported, not papered over)

These are address ranges where the two models deliberately differ, none of them
touched by the corpus:

* **The RTL's mapped memory is smaller than Spike's DRAM.** Spike's DRAM is
  2048 MiB at `0x8000_0000`; the DUT's socket window is its implemented memory
  (`MEM_BYTES`: 1 MiB on the AXI build, 256 KiB of behavioral beats on the other),
  so an access to e.g. `0x8010_0000` *succeeds* under Spike (it reads the
  uninitialized DRAM as zero — verified with the probe program this increment used
  as the oracle) and is an access fault on the RTL. A program must stay inside the
  socket window; closing the difference properly means configuring the golden's
  memory to the socket's (`spike -m0x80000000:0x40000`), a harness change this
  increment's scope excludes.
* **No boot ROM, no CLINT/PLIC.** Spike's ROM page (`0x1000`), its CLINT
  (`0x0200_0000`) and its PLIC (`0x0c00_0000`) answer accesses; the RTL has none
  of them, so an access there faults. A *fetch* from the UART page faults on both
  sides (the 4-byte fetch is a width the ns16550 rejects).
* **`eth_rv_axi_master.axi_err_o`** (sticky, SoC observability) still reports
  every non-OKAY response, including the ones that are now legitimate access
  faults; the testbench only FAILs on it if no access-fault trap was taken.

## Tests and fixtures

`tests/fixtures/` holds three files derived from `cor_model.S`, all regenerable:

| fixture | regenerated by | used for |
|---|---|---|
| `cor_model.hex` | `build_corpus.py --hex-out tests/fixtures` | running the model DUT with no toolchain |
| `cor_model.spike_log.txt` | `build_corpus.py --golden-out tests/fixtures` | normalization tests (real Spike output, incl. boot ROM and post-exit spin lines) |
| `cor_model.trace` | same | `--golden` replay with no Spike |

Regenerate all three with:

```bash
python3 ethereal-shell/verif/eth_rv/corpus/build_corpus.py --only cor_model \
    --out generated/rv_difftest/corpus \
    --hex-out ethereal-shell/verif/eth_rv/tests/fixtures \
    --golden-out ethereal-shell/verif/eth_rv/tests/fixtures
```

The tracked raw log is truncated 50 lines past the HTIF exit store
(`LOG_TAIL_LINES`) — deterministic, so regeneration reproduces it byte for byte.
(It is named `*_log.txt` rather than `*.log` on purpose: the repo-wide
`.gitignore` ignores `*.log`, and a golden reference vector must be tracked.)
Tests that need the toolchain (`corpus_elfs`) or Spike (`spike_binary`) skip
themselves when the tool is missing; the rest of the suite is hermetic.

## CLI reference

```
rv_difftest.py (--elf ELF | --golden TRACE) --dut SPEC [options]

  --elf ELF               ELF under test: Spike becomes the golden source
  --golden TRACE          replay a captured canonical trace (raw Spike log: give --elf too)
  --dut SPEC              dump:PATH | model:PATH | callback:MODULE:FUNC
  --dut-path DIR          extra sys.path entry for callback: adapters (repeatable)
  --inject INDEX:FIELD=VALUE   corrupt one DUT commit (pc|rd|value|cycle; repeatable)
  --isa NAME              Spike --isa string (default rv64imc)
  --spike PATH            Spike binary (default: $RV_DIFFTEST_SPIKE, repo build, $PATH)
  --timeout SECONDS       Spike run timeout (default 300)
  --max-commits N         compare only the first N commits
  --no-cycle-check        ignore the cycle field
```

Exit status: `0` full match (prints `MATCH: N commits compared, 0 divergence`),
`1` first divergence (prints `DIVERGENCE (kind) at commit #N (cycle C): pc=… rd=…`
plus both commit lines and a detail string), `2` usage/IO/toolchain/trace-format
error.

## Limitations / next steps

* **Memory masks are DUT-side only.** Spike's log has no byte-lane masks, so the
  golden stream cannot state them; the harness compares `mem_addr`/`mem_wdata`
  against it and cross-checks a DUT's masks against the golden's load/store
  direction plus their own lane consistency. A golden with masks (a second DUT,
  or a patched Spike) would be compared value-by-value — the comparator already
  does that when both sides provide them.
* **CSRs/traps are not modelled** by the example Python DUT (it raises
  `UnsupportedInstruction` by design); `cor_csr`/`cor_trap` are the RTL's corpus
  and run through the RTL runner. An interrupt *stream* (CLINT/PLIC, Sv39) is
  still ahead, in RV-C.
* **The CLINT is deferred** (C14 §8 checkpoint 5 needs none): Spike ticks `mtime`
  from its own instruction counter, so a value a program reads back is a function
  of the golden model's progress and cannot be matched by RTL running at a
  different cycles-per-retirement rate. It becomes verifiable together with the
  interrupt path it exists for.
* **The console UART is transmit-only, byte-register, and mirrored to Spike's
  model.** `LSR`/`IIR`/`MSR` are the ns16550 values Spike's own device returns
  (`0x60`, `0xC1`/`0xC2`, `0xD0`); the receiver, the `FCR` clear bits and `MCR`
  loopback are not implemented (see "Console" above). The corpus therefore only
  ever uses byte accesses to the page (a wider one is an access fault; any page
  offset aliases onto register 0..7 — see "Port error responses").
* **Port error responses are in** (see "Port error responses"): an unservable
  access is an access fault (mcause 1/5/7, mtval = the address) on both ports, the
  console page rejects widths it cannot serve and aliases its byte offsets the way
  Spike's device does, and both the wedge guard and the two negative controls
  above are asserted in every run. What is still open is the *address map*: the
  RTL implements fewer regions than Spike's model (no ROM, no CLINT/PLIC, and a
  smaller DRAM window) — the deliberate deviations are listed at the end of that
  section.
* **Single hart, no MMU, no atomics/floating point** in the model; clock-domain
  and reset behaviour are out of scope for a commit diff.
* **Not a lockstep co-sim yet.** This is a post-hoc commit diff (the standard
  DiffTest shape): Spike runs first and produces the golden stream, then the DUT
  stream is compared. A live lockstep (DUT stepping until divergence, with
  memory-sync) is a later increment and can reuse `rv_dut`/comparator unchanged.
* The example DUT executes a *subset* by design and raises
  `UnsupportedInstruction` for anything else rather than guessing.

## Build/lint commands

```bash
python3 ethereal-shell/verif/eth_rv/corpus/build_corpus.py --out generated/rv_difftest/corpus
.venv/bin/pytest -q ethereal-shell/verif/eth_rv/tests
.venv/bin/ruff check ethereal-shell/verif/eth_rv ethereal-shell/verif/eth_rv_core
.venv/bin/mypy --strict ethereal-shell/verif/eth_rv ethereal-shell/verif/eth_rv_core
```

The root `Makefile` carries both halves already: `make verif-rv` (build the corpus +
run this suite) and `make verif-rv-rtl` (run the corpus on the Verilated RTL — all
twelve programs, both D-port builds with `--dram`, and the console assertion). The
corpus step needs `riscv64-unknown-elf-gcc`, the RTL step needs Verilator, and the
tests self-skip when a tool is missing.

The console peripherals (`eth_rv_uart.sv`, `eth_rv_mmio_mux.sv`) are linted with
the same strict command `make lint` uses per module
(`verilator --lint-only -Wall --top-module <m>`); `eth_rv_uart.sv` needs no
waiver and `eth_rv_mmio_mux.sv` (which now carries the CLINT as a second module)
keeps the single scoped, justified `DECLFILENAME` waiver described above. Neither
needs a `Makefile` change.

## Privilege modes, trap delegation and interrupts (E2-RV1 increment 6)

The RV-B core grows the M/S/U privilege machine and the trap machinery RV-C needs.
Everything below is DiffTest-verified against the pinned Spike
(`--isa=rv64imc`, which enables S and U), not asserted.

**What is implemented**

* **Privilege state**: `mstatus.MPP/MPIE/MIE/SPP/SPIE/SIE` (plus the WARL bits
  Spike carries: `MPRV`, `SUM`, `MXR`, `TVM`, `TW`, `TSR`, `FS`, and `SD`
  derived from `FS`), `mret`, `sret`. `mstatus`/`sstatus` are one register with
  an S-mode *view*, exactly like Spike's `sstatus` proxy: `SSTATUS_WMASK` is the
  S-owned subset carried in the package.
* **`ecall` per mode**: cause 11 (M), 9 (S), 8 (U). `mret` is M-only (illegal
  from S/U), `sret` needs S or M and needs M when `TSR = 1`.
* **CSR access rules**: a CSR's privilege is its address field `[9:8]` (00 = U,
  01 = S, 10 = H, 11 = M), a write to a read-only CSR is illegal even from M
  (Spike's `if (write && csr_read_only)` — `mhartid` is the one such CSR here),
  and in S-mode the comparison is against HS (2). `sie`/`sip`/`sstatus` are
  views: `sie` writes are masked by `mideleg`, `sip` can set only SSIP.
* **Trap delegation**: `medeleg` (writable mask `0xb3fe`) routes an exception
  raised *below M* to `stvec` with `scause`/`sepc`/`stval`/`sstatus`; `mideleg`
  (mask `0x222`) does the same for interrupts. A trap raised in M-mode is never
  delegated, whatever the registers say.
* **CLINT** (inside `eth_rv_mmio_mux.sv`, so no build-file change is needed):
  Spike's MSIP (`0x0200_0000`) / MTIMECMP (`0x0200_4000`) / MTIME (`0x0200_bff8`)
  window, size `0xc000`, with Spike's byte-lane behaviour. `msip`/`mtimecmp`
  write-through is combinational: a store is accepted in MEM in the same cycle
  the *next* instruction is in EX, which is precisely the boundary Spike uses, so
  without the bypass the interrupt would land one instruction late.
* **Interrupts**: `mip`/`mie`/`sip`/`sie` with Spike's masks (MIP = SSIP/STIP/
  SEIP writable, `mideleg` = SSI/STI/SEI), Spike's priority (MEI, MSI, MTI, SEI,
  SSI, STI), vectored `mtvec`/`stvec` (`base + 4 * cause` for interrupts only,
  MODE bit 0), and delegation of the S bits.

**Corpus** (the four programs added here; the counts are the beats compared on
the behavioral and AXI/DRAM D-port builds):

| program | coverage | commits |
|---|---|---|
| `cor_priv.S` | mstatus/sstatus WARL and the view, tvec/epc WARL, delegation masks, `mip` at reset (MTIP pending), `mret` to S, S-mode CSR legality, `sret` to U, U-mode legality, mstatus on trap entry | 604 |
| `cor_deleg.S` | medeleg delegation of ecall-S/ecall-U/a load access fault, the S-mode stack (SPP/SPIE/SIE + sret), an undelegated cause still going to M, an M-mode trap never delegated | 244 |
| `cor_intr.S` | MTI via MTIP, MSI via the CLINT's MSIP, MSI > MTI priority, pending bits armed through `mip`, a NEGATIVE CONTROL (pending + enabled but MIE = 0 ⇒ no interrupt), vectored `mtvec` (the stub at `base+28` proves the vector), S-delegated SSI armed through `sip` | 491 |
| `cor_time.S` | the MTIME staircase read in a trap-free loop across two RTC ticks (0 → 50 → 100) | 6517 |

Every `cor_intr`/`cor_deleg` handler pins the exact instruction the trap must
land on with a label, so the interrupt/trap *boundary* is compared, not just the
architectural effect.

**Boundaries — what is deliberately NOT compared** (each with its reason, so no
comparison is silently weakened):

* **MMU / paging**: `satp` and `sfence.vma` are not implemented (illegal), and
  the MMU-related `mstatus` bits are WARL storage with no translation behaviour.
  No corpus program touches them. `mstatus`'s MMU bits are still stored so a
  `mstatus` round trip reproduces Spike's value bit for bit.
* **`wfi`** is not implemented (illegal). Spike's `wfi` waits for an interrupt
  and never commits; it has no place in a commit-stream DiffTest.
* **Counters**: `cycle`/`time`/`instret` do **not exist** in Spike under
  `--isa=rv64imc` (no Zicntr) — the RTL rejects them as illegal too, which is
  why `mcounteren`/`scounteren` exist with a zero write mask and read 0. Spike's
  *machine* `mcycle`/`minstret` do exist under that ISA; they are its own
  step/cycle counters and are not implemented.
* **MEIP** has no source: Spike's default configuration has no PLIC, so the core's
  `meip_i` is tied low and `mip.MEIP` stays 0. The other five sources are all
  exercised.
* **MTIME after a trap**: the staircase read path *is* proved (`cor_time`), but a
  program that traps is out of scope — Spike ends its step early on a trap
  (`n = instret`), which shifts the tick phase in a way no hart-side counter can
  reproduce. `cor_intr` therefore arms the timer only with `mtimecmp = 0` (MTIP
  permanently pending) and `= -1` (never), which are phase-independent.
* **Interrupt-taking boundary**: the RTL takes a pending, enabled interrupt at the
  next instruction boundary; Spike only breaks its loop at a *serialization*
  point (the barrier before a CSR instruction, or the boundary right after a
  CSR/xRET — `riscv/decode_macros.h` `validate_csr`/`serialize`). The two agree
  whenever the source is armed by a CSR write, or the enabling write is the
  instruction right before the intended trap point — which is how every `cor_intr`
  test is written. A program that arms a source with a store while enabled and
  then runs non-serializing instructions would diverge; that window is not
  compared, and `cor_intr.S` documents it at the top of the file.

**Lint/build note**: the CLINT lives in `eth_rv_mmio_mux.sv` as a second module
on purpose — the project lint rule resolves a module's dependencies by filename,
so a separate `eth_rv_clint.sv` would need a `Makefile` dependency line that this
increment's scope excludes. The one resulting `DECLFILENAME` warning is waived
with the written justification in the file; every other `-Wall` warning still
fails. No `Makefile` edit is required by this increment.
