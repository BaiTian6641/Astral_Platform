# =============================================================================
# Ethereal Logic Platform — root Makefile (task E0-INF3)
# =============================================================================
# GNU make required (cocotb's makefiles and the awk help target assume GNU
# make). All recipes use TAB indentation per the Makefile spec.
#
# CONTRACT (consumed by CI task E0-INF2 — keep target names + image name stable):
#     make help          list targets
#     make lint          verilator --lint-only -Wall over all RTL
#     make test          cocotb regression (smoke test minimum)
#     make test-model    pure-Python golden-model pytest (LOCAL, no simulator)
#     make test-sv       SystemVerilog testbenches via iverilog/vvp (LOCAL OSS-CAD)
#     make sim           quick smoke simulation (counter)
#     make docker-build  docker build -f docker/Dockerfile -t ethereal-sim docker/
#     make docker-shell  run ethereal-sim interactively, repo mounted at /work
#     make clean         remove build artifacts
#
# DESIGN: each native target (lint/test/sim) detects whether the required tool
# is on PATH; if not, it prints a clear "use the Docker image" message and
# exits non-zero so CI fails loudly rather than silently no-op'ing.
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# --- Tool detection (override on the command line if needed, e.g. VERILATOR=...) ---
VERILATOR ?= $(shell command -v verilator 2>/dev/null)
IVERILOG   ?= $(shell command -v iverilog 2>/dev/null)
DOCKER     ?= $(shell command -v docker 2>/dev/null)

# --- Repo layout ---
# `make lint` covers PROJECT RTL only: ethereal-fabric/rtl/{clb,interconnect}/*.sv.
# Testbenches (tests/**/tb_*.sv) and the smoke DUT (tests/smoke/counter.sv) are
# NOT linted here (lint them via their test Makefiles). The IMPORTED Mailbox NoC
# + SPI/UART adapters under ethereal-shell/rtl/{mailbox,interface}/ (S04-P0#1)
# carry a KNOWN G1-cleanup backlog -> linted separately via `make lint-mailbox`
# (advisory). Fabric loop-modules (clb_t feedback, fabric_top routing rings) are
# linted with a documented -Wno-UNOPTFLAT waiver (intended virtual loops, C01 sec2.4).
RTL_CLEAN := ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv
RTL_FABRIC_DEPS := ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv
# Heterogeneous-tile (Phase-1) inference-template deps — mem_t/dsp_t wrappers pull
# in the eth_inf_* behavioral RAM/DSP (eth_config.svh attribute layer via -I).
RTL_INF_DEPS := ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv
RTL_FILES := $(RTL_FABRIC_DEPS)
# Imported (not-yet-G1-clean) Mailbox RTL — linted separately, never fatal.
MAILBOX_RTL := $(shell find ethereal-shell/rtl/mailbox ethereal-shell/rtl/interface -type f \( -name '*.sv' -o -name '*.v' \) 2>/dev/null)

SMOKE_DIR := ethereal-fabric/tests/smoke

# --- Docker contract (shared with CI task E0-INF2) ---
IMAGE    := ethereal-sim
WORKDIR  := /work

.PHONY: help lint lint-mailbox test test-model test-sv sim docker-build docker-shell clean

help: ## Show this help
	@echo "Ethereal Logic Platform — root Makefile (GNU make)"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "RTL currently picked up by 'lint':"
	@echo "  $(if $(strip $(RTL_FILES)),$(strip $(RTL_FILES)),<none yet — fabric RTL lands in E0-FAB1..6>)"

lint: ## Verilator --lint-only -Wall over project RTL (clean modules strict; fabric loop-modules with documented -Wno-UNOPTFLAT, C01 sec2.4)
ifeq ($(VERILATOR),)
	@echo "[lint] ERROR: verilator not found on PATH. Options:"
	@echo "[lint]   (local, no Docker):  PATH=\$$HOME/oss-cad-suite/bin:\$$PATH make lint"
	@echo "[lint]   (reproducible img):  make docker-build && make docker-shell  # then make lint"
	@exit 1
else
	@echo "[lint] clean modules (strict -Wall): $(RTL_CLEAN)"
	@for f in $(RTL_CLEAN); do \
	  m=$$(basename $$f .sv); \
	  case $$m in \
	    mem_t|dsp_t)         deps="$(RTL_INF_DEPS)" ;; \
	    emri_regfile)        deps="ethereal-shell/rtl/emri/emri_pkg.sv" ;; \
	    *)                   deps="" ;; \
	  esac; \
	  verilator --lint-only -Wall --top-module $$m -Mdir obj_dir/lint_$$m \
	    -Iethereal-fabric/rtl/inf $$deps $$f || exit 1; \
	done
	@echo "[lint] fabric modules (-Wall -Wno-UNOPTFLAT; intended loops per C01 sec2.4): clb_t, fabric_top"
	verilator --lint-only -Wall -Wno-UNOPTFLAT --top-module fabric_top -Mdir obj_dir/lint_fabric $(RTL_FABRIC_DEPS)
	@echo "[lint] OK - all project RTL lint-clean."
endif

lint-mailbox: ## Lint the IMPORTED Mailbox NoC (NOT G1-clean yet — see MIGRATION-mailbox.md §5). Advisory; warnings expected.
ifeq ($(VERILATOR),)
	@echo "[lint-mailbox] ERROR: verilator not found on PATH. Use 'make docker-shell' then 'make lint-mailbox'."
	@exit 1
else ifeq ($(strip $(MAILBOX_RTL)),)
	@echo "[lint-mailbox] No imported mailbox RTL under ethereal-shell/rtl/{mailbox,interface}/."
else
	@echo "[lint-mailbox] Imported Mailbox RTL is NOT yet G1-clean (cleanup backlog pending). Warnings are EXPECTED; this target never fails CI."
	-verilator --lint-only -Wall $(MAILBOX_RTL)
endif

test-sv: ## Run self-checking SystemVerilog testbenches via iverilog/vvp (local OSS-CAD)
ifeq ($(IVERILOG),)
	@echo "[test-sv] ERROR: iverilog not found. PATH=\$$HOME/oss-cad-suite/bin:\$$PATH make test-sv"
	@exit 1
else
	@echo "[test-sv] tb_elut4";      $(IVERILOG) -g2012 -o /tmp/tb_elut4 ethereal-fabric/tests/clb/tb_elut4.sv ethereal-fabric/rtl/clb/elut4.sv && vvp /tmp/tb_elut4 | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_clb_t";      $(IVERILOG) -g2012 -o /tmp/tb_clb_t ethereal-fabric/tests/clb/tb_clb_t.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/clb/elut4.sv && vvp /tmp/tb_clb_t | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_switch_box"; $(IVERILOG) -g2012 -o /tmp/tb_sb ethereal-fabric/tests/interconnect/tb_switch_box.sv ethereal-fabric/rtl/interconnect/switch_box.sv && vvp /tmp/tb_sb | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_connection_block"; $(IVERILOG) -g2012 -o /tmp/tb_cb ethereal-fabric/tests/interconnect/tb_connection_block.sv ethereal-fabric/rtl/interconnect/connection_block.sv && vvp /tmp/tb_cb | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_occ";       $(IVERILOG) -g2012 -o /tmp/tb_occ ethereal-fabric/tests/occ/tb_occ.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/occ/occ_top.sv && vvp /tmp/tb_occ | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_blank";     $(IVERILOG) -g2012 -o /tmp/tb_blank ethereal-fabric/tests/occ/tb_blank.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/occ/occ_top.sv && vvp /tmp/tb_blank | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_hotswap";  $(IVERILOG) -g2012 -o /tmp/tb_hotswap ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/interconnect/tb_hotswap.sv 2>/dev/null && vvp /tmp/tb_hotswap | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_het_tiles"; $(IVERILOG) -g2012 -o /tmp/tb_het -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/tests/tile/tb_het_tiles.sv && vvp /tmp/tb_het | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_het_fabric"; $(IVERILOG) -g2012 -o /tmp/tb_hetfab -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/interconnect/tb_het_fabric.sv 2>/dev/null && vvp /tmp/tb_hetfab | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_vbus_route"; $(IVERILOG) -g2012 -o /tmp/tb_vbus -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/interconnect/tb_vbus_route.sv 2>/dev/null && vvp /tmp/tb_vbus | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_emri_regfile"; $(IVERILOG) -g2012 -o /tmp/tb_emri ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/emri/tb_emri_regfile.sv 2>/dev/null && vvp /tmp/tb_emri | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_emri_occ_loop"; $(IVERILOG) -g2012 -o /tmp/tb_emriloop ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/emri/tb_emri_occ_loop.sv 2>/dev/null && vvp /tmp/tb_emriloop | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_mgmt_hotswap"; $(IVERILOG) -g2012 -o /tmp/tb_mgmthotswap -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/tb_mgmt_hotswap.sv 2>/dev/null && vvp /tmp/tb_mgmthotswap | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] pack_tb_frames (regen golden frames)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && echo "  frames ok"
	@echo "[test-sv] tb_frame_decoder"; $(IVERILOG) -g2012 -o /tmp/tb_fd -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/tests/emri/tb_frame_decoder.sv 2>/dev/null && vvp /tmp/tb_fd | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] shell_tb_mgmt_packed"; $(IVERILOG) -g2012 -o /tmp/tb_shellpacked -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/shell_tb_mgmt_packed.sv 2>/dev/null && vvp /tmp/tb_shellpacked | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] pack_tb_frames --het (regen het golden frames)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --het --out generated/tb_frames_het >/dev/null && echo "  frames ok"
	@echo "[test-sv] shell_tb_het_packed"; $(IVERILOG) -g2012 -o /tmp/tb_hetpacked -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/shell_tb_het_packed.sv 2>/dev/null && vvp /tmp/tb_hetpacked | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] OK - all SystemVerilog testbenches passed."
endif

sim: ## Quick smoke simulation (counter) via cocotb + Verilator
ifeq ($(VERILATOR),)
	@echo "[sim] ERROR: verilator not found on PATH. Run 'make docker-build && make docker-shell', then 'make sim'."
	@exit 1
else
	@$(MAKE) -C $(SMOKE_DIR) sim SIM=verilator
endif

test-model: ## Run pure-Python golden-model pytest (no simulator needed; runs locally)
	@MODELS=$$( (find ethereal-fabric/tests -name 'test_*_model.py'; find ethereal-tools -name 'test_*.py') 2>/dev/null); \
	if [ -z "$$MODELS" ]; then \
		echo "[test-model] No test_*_model.py found under ethereal-fabric/tests."; \
		exit 0; \
	fi; \
	if command -v pytest >/dev/null 2>&1; then PYTEST=pytest; \
	elif [ -x .venv/bin/pytest ]; then PYTEST=.venv/bin/pytest; \
	else echo "[test-model] pytest not found. Create a venv: python3 -m venv .venv && .venv/bin/pip install pytest"; exit 1; fi; \
	echo "[test-model] running: $$PYTEST $$MODELS"; \
	$$PYTEST -q $$MODELS

test: ## Run cocotb regression (smoke test minimum, Phase 0)
ifeq ($(VERILATOR),)
	@echo "[test] ERROR: verilator not found on PATH. Run 'make docker-build && make docker-shell', then 'make test'."
	@exit 1
else
	@$(MAKE) -C $(SMOKE_DIR) test SIM=verilator
endif

docker-build: ## Build the ethereal-sim Docker image (~45-90 min cold; cached after)
ifeq ($(DOCKER),)
	@echo "[docker-build] ERROR: docker not found on PATH. Install Docker, then 'make docker-build'."
	@exit 1
else
	docker build -f docker/Dockerfile -t $(IMAGE) docker/
endif

docker-shell: ## Run ethereal-sim interactively with the repo mounted at /work
ifeq ($(DOCKER),)
	@echo "[docker-shell] ERROR: docker not found on PATH. Install Docker, then 'make docker-shell'."
	@exit 1
else
	docker run --rm -it -v "$$(pwd):$(WORKDIR)" -w $(WORKDIR) $(IMAGE)
endif

clean: ## Remove build artifacts (obj_dir/ sim_build/ *.vcd *.fst)
	rm -rf obj_dir sim_build *.vcd *.fst
	@$(MAKE) -C $(SMOKE_DIR) clean 2>/dev/null || true
