# `ethereal-sim` — simulation / open-source EDA image (task E0-INF3)

Reproducible environment for Phase 0+ simulation and the mapping toolchain.
This is the **single source of truth** for "what version of Verilator / Yosys /
VPR / cocotb / Python does the Ethereal Logic Platform build against?" —
pinned in [`Dockerfile`](Dockerfile) and consumed by CI (task `E0-INF2`).

> **Image name (CONTRACT):** `ethereal-sim` · **Dockerfile:** `docker/Dockerfile`
> · **build context:** `docker/`
> Plan-Ref: `ethereal-plan/phases/phase-0-基础设施与仿真验证.md §1 (E0-INF3)`,
> `ethereal-plan/subsystems/S14-验证与CI基础设施.md §3`.

---

## Local alternative: OSS-CAD Suite (no Docker needed for lint/sim)

The authoring machine has **OSS-CAD Suite** installed at `~/oss-cad-suite`
(Verilator 5.051, Yosys 0.67, iverilog 14, cocotb). With it on `PATH` you can run
the **lint + simulation** part of the toolchain **locally, without Docker**:

```bash
export PATH=~/oss-cad-suite/bin:$PATH
make lint        # verilator --lint-only -Wall over project RTL (clean)
make test-sv     # SystemVerilog testbenches via iverilog/vvp
make test-model  # pure-Python golden-model pytest (any Python 3.12)
```

The **Docker `ethereal-sim` image is still the pinned/reproducible source of
truth** (above) and is required for: the **VPR/VTR** mapping toolchain (`E0-MAP2`,
not in OSS-CAD's scope), **CI parity**, and any contributor without OSS-CAD.
Use OSS-CAD for fast local lint/sim; use the image for reproducible full-chain +
CI. (Note: OSS-CAD's bundled cocotb is a py3.11 egg vs the system py3.12 — hence
`make test-sv` via iverilog is the local DUT validation path; cocotb DUT tests
run inside the Docker image.)

---

## What's inside (pinned versions)

| Tool | Version | Tag / source | Why this pin |
|---|---|---|---|
| **Verilator** | **5.028** | `v5.028` (github.com/verilator/verilator) | Maintainer-suggested stable; widely deployed; contemporaneous with Ubuntu 22.04 / GCC 11. Drives rule G1 (`--lint-only -Wall`) + cycle sim. |
| **Yosys** | **0.59** | `yosys-0.59` (github.com/YosysHQ/yosys) | Stable in the 0.5x series with solid SystemVerilog support; ISC-licensed; used by the fabric techlib mapper (`E0-MAP1`). |
| **VPR / VTR** | **8.0.0** | `v8.0.0` (github.com/verilog-to-routing/vtr-verilog-to-routing) | MIT-licensed; the canonical academic P&R for the MAP route A toolchain (`E0-MAP2`). Released ~2022, matches the GCC-11 base. |
| **cocotb** | **1.9.x** | `pip` | Stable series with reliable Verilator `--timing` support for `Clock` / `RisingEdge` triggers. |
| **cocotb-test** | latest | `pip` | Lets CI run cocotb through pytest (`E0-INF2`). |
| **Python** | **3.12** | deadsnakes PPA | Matches `ethereal-tools` G1 requirement (`ruff` + `mypy --strict`). |
| Base OS | Ubuntu 22.04 + GCC 11 | `ubuntu:22.04` | Contemporaneous with all three EDA releases → highest first-build success probability. |

> **ASSUMPTION (G6, 2026-07-24):** the three EDA tags build cleanly on
> Ubuntu 22.04 / GCC 11. This image is **NOT build-tested locally** — the
> authoring environment has no `docker` and no `vpr`/`VTR` (OSS-CAD Suite
> provides Verilator/Yosys/iverilog for local lint/sim — see above — but not
> VPR, and Docker itself is absent). The maintainer must run `make docker-build`
> once and paste results; if any tag fails, see the per-RUN fallback notes in
> [`Dockerfile`](Dockerfile) and update the report.

---

## Build & run

All day-to-day use goes through the **root `Makefile`** so the image name and
mount path stay consistent:

```bash
make docker-build      # docker build -f docker/Dockerfile -t ethereal-sim docker/   (~45-90 min cold; cached after)
make docker-shell      # interactive bash, repo bind-mounted at /work
# then, inside the container:
make help              # list targets
make lint              # verilator --lint-only -Wall over all ethereal-fabric/ + ethereal-shell/ RTL
make test              # cocotb regression (smoke test minimum, Phase 0)
make sim               # quick smoke simulation (counter)
make clean             # rm -rf obj_dir/ sim_build/ *.vcd *.fst
```

### `docker compose` alternative

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml run --rm sim make test
docker compose -f docker/docker-compose.yml run --rm sim bash
```

---

## The "30-minute clean-machine reproduce" promise

`ethereal-plan/phases/phase-0-基础设施与仿真验证.md §1` sets the E0-INF3
acceptance bar at "clean machine 30-min reproduce". It is interpreted as:

> **On a clean machine with Docker installed, after `make docker-build`
> completes once (or after `docker pull ethereal-sim` once a registry is set
> up in a later task), a new contributor reaches a green `make test` in under
> 30 minutes** — i.e. clone → `make docker-shell` → `make test` ≤ 30 min.

It is **not** a 30-minute cold-`docker-build` promise: the first build compiles
Verilator + Yosys + VPR from source. Once the image is built (or pulled),
layer cache + the bind mount make every subsequent `make test` a sub-minute
operation. Publishing the image to GHCR is deferred to a later infra task.

---

## File layout

```
docker/
├── Dockerfile          # the ethereal-sim image (pinned versions above)
├── .dockerignore       # keeps build context tiny (image never COPY's repo src)
├── docker-compose.yml  # optional convenience wrapper (Makefile is canonical)
└── README.md           # this file
```

The smoke test that proves the image works lives outside this dir, in
[`../ethereal-fabric/tests/smoke/`](../ethereal-fabric/tests/smoke/)
(`counter.sv` + `test_counter.py` + cocotb `Makefile`).
