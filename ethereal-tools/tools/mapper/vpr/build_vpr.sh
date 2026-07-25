#!/usr/bin/env bash
# build_vpr.sh — build VTR v8.0.0's vpr binary natively (E0-MAP2 toolchain).
#
# Why gcc-12: this box is Ubuntu 24.04 + GCC 13.3, but the project pins VTR
# v8.0.0 (Aug 2022, GCC-11/12 era). GCC 13 is stricter and rejects some v8.0.0
# code, so we build with gcc-12/g++-12 to preserve CI parity with the ethereal-sim
# Docker image (Dockerfile pins v8.0.0). Documented as ASSUMPTION in the E0-MAP2
# report. Builds ONLY the vpr target (not all of VTR) to save time.
#
# Usage:  bash build_vpr.sh
# Output: ~/vtr/build/vpr/vpr  (run from there; build tree kept for shared libs)
set -euo pipefail
JOBS="$(nproc)"
VTR=~/vtr

cd "$VTR"
echo "=== [1/4] init submodules (shallow) ==="
git submodule update --init --recursive --depth 1

echo "=== [2/4] cmake (gcc-12, Unix Makefiles, Release) ==="
# NOTE: ninja-build not installed; use the default Unix Makefiles generator
# (make is present, parallel via -j below). Drop -G Ninja.
#
# v8.0.0 (Aug 2022) relies on libstdc++ transitively including <limits> /
# <algorithm>; the 2024-era libstdc++ (gcc-12 on Ubuntu 24.04) dropped those
# transitive includes, so every TU using std::numeric_limits / std::max fails.
# Fix once globally by force-including both headers into every translation unit
# (avoids patching dozens of v8.0.0 source files). Documented in E0-MAP2 report.
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc-12 \
  -DCMAKE_CXX_COMPILER=g++-12 \
  -DCMAKE_CXX_FLAGS="-include limits -include algorithm"

echo "=== [3/4] build vpr target only (jobs=$JOBS) ==="
cmake --build build --target vpr -- -j"$JOBS"

echo "=== [4/4] smoke ==="
"$VTR/build/vpr/vpr" --version || true
echo "vpr built at: $VTR/build/vpr/vpr"
