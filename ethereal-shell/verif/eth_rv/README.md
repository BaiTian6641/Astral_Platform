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
DUT ──(dump file | callback | model)──► rv_dut ──┘                    (pc / rd / cycle, exit code)
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
| `corpus/` | Bare-metal RV64IMC corpus: `crt0.S`, `link.ld`, four `cor_*.S` programs, builder |
| `tests/` | pytest suite; `tests/fixtures/` holds the checked-in golden fixtures |

## The trace protocol

One retired instruction per line, in the order the core retires them:

```
# rv_difftest trace v1
# generator: spike[rv64imc] cor_model.elf (Spike RISC-V ISA Simulator 1.1.1-dev)
# fields: cycle pc rd value
1 0x0000000080000000 x2 0x000000008000a000
2 0x0000000080000004 x2 0x000000008000a000
3 0x0000000080000008 -  -
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

A DUT may also emit the lenient 3-field form `pc rd value` (cycle = line
ordinal) — that is what a Verilator testbench `$fwrite` naturally produces.
Lines are `#`-commented; blank lines are ignored. Anything else fails loudly with
`<source>:<line>: <message>` and exit code 2 — a malformed DUT dump never turns
into a silent "short trace".

The comparator checks, per commit: `cycle` (optional), `pc`, `rd`, `value`, in
that order, and reports the **first** divergence. `insn` is carried along when
the producer knows it (Spike does) purely for debugging.

## Golden side: Spike

`--elf ELF` runs Spike as
`spike --isa=rv64imc -l --log-commits --log=<tmp> <ELF>` and normalizes its log.
Two details matter and are handled for you:

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

## DUT side: how the future `eth_rv` RTL plugs in

Three adapters, one contract: an ordered iterator of commits.

1. **Trace file — `--dut dump:PATH`.** The Verilator testbench writes one line
   per retirement; the harness diffs it. Nothing else is required:

   ```systemverilog
   // in the eth_rv testbench: pc, rd, value of the committed instruction
   always @(posedge clk) if (commit_valid_r)
     $fwrite(trace_fd, "%0d 0x%016x %s 0x%016x\n", cycle_r, pc_r, rd_r, wdata_r);
   ```

   Canonical 4-field lines are preferred; `pc rd value` (3 fields) is accepted.
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

`--inject INDEX:FIELD=VALUE` corrupts one field of one DUT commit
(`pc`/`rd`/`value`/`cycle`) — a demo/self-test switch that proves the harness
detects the class of bug the RTL will eventually produce.

## Corpus

Four self-checking bare-metal programs (`-march=rv64imc -mabi=lp64 -nostdlib
-mcmodel=medany`, linked at `0x8000_0000` by `corpus/link.ld`, entered via
`corpus/crt0.S`):

| program | coverage |
|---|---|
| `cor_alu.S` | RV64I ALU/shift/compare/branch, identity cross-checks, C-extension ALU forms |
| `cor_mem.S` | all load/store widths, sign/zero extension, little-endian order, loops, stack |
| `cor_muldiv.S` | RV64M incl. high halves, div-by-zero, `INT64_MIN / -1`, W-forms |
| `cor_model.S` | the C forms the example DUT implements — source of the checked-in fixtures |

`main` returns 0 on success or the index of the first failed check; `crt0.S`
turns that into the HTIF exit store, so a corpus bug shows up as a non-zero
Spike exit status *and* as a divergent trace. `-mcmodel=medany` is required:
absolute `lui` addressing cannot materialize `0x8000_xxxx` on RV64, where `lui`
sign-extends from bit 31.

Toolchain note: `riscv64-unknown-elf-gcc 13.2.0` is a full RV64 toolchain
(`--print-multi-lib` offers `rv64i`/`rv64im`/`rv64imac`/`rv64imafdc`/…), but there
is **no `rv64imc` multilib** — C is folded into `rv64imac`/`rv64imafc`. That does
not matter here because the corpus is `-nostdlib -nostartfiles -ffreestanding`:
`-march=rv64imc -mabi=lp64` compiles and links as-is. If a future corpus program
needs libc/libgcc, build it for `rv64imac` (or add a multilib) — Spike and the
harness take the ISA string from `--isa`, so nothing else changes.

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

* **Memory accesses are not compared.** Spike's log carries `mem <addr> [<value>]`
  fields; the canonical record is `cycle pc rd value`, so a DUT that stores to
  the wrong address but keeps pc/rd/value identical is not caught yet. Extending
  `Commit` with a `mem_write` field is the natural next increment (the Spike
  parser already sees the data).
* **CSRs/traps are not modelled** by the example DUT, and the comparator has no
  CSR stream. `eth_rv` phase RV-C (Sv39, interrupts) will need one.
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
.venv/bin/ruff check ethereal-shell/verif/eth_rv
.venv/bin/mypy --strict ethereal-shell/verif/eth_rv
```

Suggested root-Makefile target (the parent adds it; this directory does not
edit the `Makefile`):

```make
verif-rv: ## eth_rv DiffTest: build the bare-metal corpus + run the harness tests
	python3 ethereal-shell/verif/eth_rv/corpus/build_corpus.py --out generated/rv_difftest/corpus
	@if [ -x .venv/bin/pytest ]; then .venv/bin/pytest -q ethereal-shell/verif/eth_rv/tests; \
	else pytest -q ethereal-shell/verif/eth_rv/tests; fi
```

(Add it to `.PHONY` and the `help` text if the maintainer wants it in `make help`.
The corpus step needs `riscv64-unknown-elf-gcc`; the Spike golden path needs the
Spike build, and the tests self-skip when either is missing.)
