# =============================================================================
# ethereal-sim — Ethereal Logic Platform simulation image (task E0-INF3)
# =============================================================================
# Reproducible simulation + open-source EDA environment for Phase 0+:
#   * Verilator  v5.028      RTL lint (--lint-only -Wall, project rule G1) + sim
#   * Yosys      yosys-0.59  synthesis + techlib mapping (ethereal mapper, E0-MAP1)
#   * VPR / VTR  v8.0.0      pack / place / route (MAP route A, E0-MAP2)
#   * cocotb + cocotb-test   Python-driven testbenches / BFMs (ethereal-fabric/tb)
#   * Python 3.12 + ruff + mypy --strict   ethereal-tools toolchain (G1)
#
# Build context : docker/    (see docker/.dockerignore)
# Image name    : ethereal-sim   (CONTRACT — shared with CI task E0-INF2)
#
#   make docker-build      # docker build -f docker/Dockerfile -t ethereal-sim docker/
#   make docker-shell      # repo mounted at /work
#
# FIRST-BUILD TIME: this image compiles Verilator + Yosys + VPR from source,
# so the initial `docker build` takes ~45-90 min on a warm laptop. Subsequent
# builds reuse Docker layer cache. The Phase-0 "clean-machine 30-min reproduce"
# promise (ethereal-plan/phases/phase-0-基础设施与仿真验证.md §1) applies to
# `make docker-shell && make test` AFTER the image is built or pulled from a
# registry; it is NOT a 30-min cold-build promise.
#
# ASSUMPTION (G6, 2026-07-24): the three pinned tags are chosen to be
# contemporaneous with Ubuntu 22.04 / GCC 11 (VTR 8.0.0 released ~2022,
# Verilator 5.028 and Yosys 0.59 validated on GCC 11). This Dockerfile is
# NOT build-tested locally — docker / verilator / yosys / vpr are absent in
# the authoring environment; the maintainer runs `make docker-build` and
# pastes results. If VPR v8.0.0 fails on this base, see §"Fallback" notes
# below each RUN.
# =============================================================================

FROM ubuntu:22.04

# Make apt fully non-interactive; force UTF-8 so Python / cocotb don't choke.
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ---- 1. System build prerequisites ------------------------------------------------
# deadsnakes PPA provides python3.12 on Ubuntu 22.04 (which ships 3.10).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl wget git make cmake ninja-build \
        software-properties-common gnupg \
        autoconf flex bison ccache \
        libfl-dev libgoogle-perftools-dev libjemalloc-dev \
        zlib1g-dev liblz4-dev libreadline-dev \
        graphviz help2man perl \
        libffi-dev libftdi1-dev libusb-1.0-0-dev \
        tcl-dev \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3.12 python3.12-dev python3.12-venv python3.12-distutils \
    && rm -rf /var/lib/apt/lists/*

# Make python3.12 the default `python3`, then bootstrap pip for it.
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ---- 2. Verilator v5.028 ----------------------------------------------------------
# Source build for reproducibility (apt pkg is far behind). --depth 1 keeps the
# clone small; tags are fetched automatically by --branch.
ARG VERILATOR_TAG=v5.028
RUN git clone --depth 1 --branch ${VERILATOR_TAG} https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator \
    && autoconf \
    && ./configure \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/verilator \
    && verilator --version

# ---- 3. Yosys yosys-0.59 ----------------------------------------------------------
# Full clone (not --depth 1) because we must checkout the tag then re-sync the
# ABC / abc plugins submodules to that tag's pinned commits.
ARG YOSYS_TAG=yosys-0.59
RUN git clone https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && cd /tmp/yosys \
    && git checkout ${YOSYS_TAG} \
    && git submodule update --init --recursive \
    && make config-gcc \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/yosys \
    && yosys -V

# ---- 4. VPR / VTR v8.0.0 ----------------------------------------------------------
# Heaviest + most compiler-sensitive build. Isolated in its own RUN layer so it
# is cached and can be rebuilt independently. `make` at the cmake build root
# builds every target; vpr lands at build/vpr/vpr — copy it onto PATH.
# Fallback if v8.0.0 fails on this GCC: try Ubuntu 24.04 + GCC 13 with a newer
# VTR release candidate, or pin a known-good commit; document in the E0-INF3
# report before changing the tag.
ARG VTR_TAG=v8.0.0
RUN git clone --recursive --branch ${VTR_TAG} https://github.com/verilog-to-routing/vtr-verilog-to-routing.git /tmp/vtr \
    && mkdir /tmp/vtr/build \
    && cd /tmp/vtr/build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. \
    && make -j"$(nproc)" \
    && cp vpr/vpr /usr/local/bin/vpr \
    && chmod +x /usr/local/bin/vpr \
    && rm -rf /tmp/vtr \
    && (vpr --version || true)

# ---- 5. Python toolchain (cocotb regression + ethereal-tools G1 lint) ------------
# cocotb 1.9.x is the current stable series with reliable Verilator --timing
# support; cocotb-test enables pytest-driven runs for the CI gate (E0-INF2).
RUN python3 -m pip install --no-cache-dir \
        "cocotb==1.9.*" \
        cocotb-test \
        ruff \
        mypy \
        pytest

# ---- 6. Workdir ------------------------------------------------------------------
# The repo is bind-mounted here by `make docker-shell` / docker-compose.
WORKDIR /work
CMD ["/bin/bash"]
