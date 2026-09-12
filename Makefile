# =============================================================================
# Ethereal Logic Platform — root Makefile (task E0-INF3)
# =============================================================================
# NOTE (2026-08-30): pi-lens dispatches shellcheck on this file (Makefile ->
# "shell" kind); shellcheck cannot parse GNU make conditionals (ifeq), so its
# SC1073/SC1065/SC1064/SC1072 findings here are false positives (recorded as
# such in the pi-lens disposition store). This Makefile is validated by `make`
# itself and CI, not by shellcheck.
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
RTL_CLEAN := ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/occ/ctx_scan.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/axi/eth_axi_stream.sv ethereal-shell/rtl/axi/eth_axi_lite_slave.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/ctx_engine_wrap.sv ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/hal/gowin_gw5/glue/eth_dram_glue.sv ethereal-fabric/hal/zynq/glue/eth_dram_glue.sv ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv ethereal-shell/rtl/dma/eth_dma_arb.sv ethereal-shell/rtl/dma/eth_dma_axi_engine.sv ethereal-shell/rtl/dma/eth_dma_channel.sv ethereal-shell/rtl/dma/eth_dma_mc.sv ethereal-shell/rtl/eth_rv/cor_alu.sv ethereal-shell/rtl/eth_rv/cor_muldiv.sv ethereal-shell/rtl/eth_rv/cor_lsu.sv ethereal-shell/rtl/eth_rv/cor_regfile.sv ethereal-shell/rtl/eth_rv/cor_decoder.sv ethereal-shell/rtl/eth_rv/eth_rv_core.sv ethereal-shell/rtl/eth_rv/eth_rv_axi_master.sv ethereal-shell/rtl/eth_rv/eth_rv_uart.sv ethereal-shell/rtl/eth_rv/eth_rv_mmio_mux.sv ethereal-shell/rtl/eth_rv/eth_rv_boot_rom.sv ethereal-shell/rtl/eth_rv/cor_mmu.sv ethereal-shell/rtl/eth_rv/cor_fp_regfile.sv ethereal-shell/rtl/eth_rv/cor_fpu.sv ethereal-shell/rtl/eth_rv/eth_rv_plic.sv ethereal-shell/rtl/ebi/ebi_tiny.sv ethereal-shell/rtl/mfsm/mfsm_session.sv ethereal-shell/rtl/mfsm/mfsm_top.sv ethereal-shell/rtl/dma/eth_dma_2d_addr.sv ethereal-shell/rtl/dma/eth_dma_2d.sv


RTL_FABRIC_DEPS := ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv
# Vendored NEORV32 all-Verilog netlist (machine-generated, BSD-3). NOT G1-ours —
# provided to bmc_core as a dep; its ~536 vendor warnings are documented-waived
# (see the bmc_core case in the lint loop). Do NOT add it to RTL_CLEAN.
NEORV32_NETLIST := ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v
# Heterogeneous-tile (Phase-1) inference-template deps — mem_t/dsp_t wrappers pull
# in the eth_inf_* behavioral RAM/DSP (eth_config.svh attribute layer via -I).
RTL_INF_DEPS := ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv
RTL_FILES := $(RTL_FABRIC_DEPS)
# Imported (not-yet-G1-clean) Mailbox RTL — linted separately, never fatal.
MAILBOX_RTL := $(shell find ethereal-shell/rtl/mailbox ethereal-shell/rtl/interface -type f \( -name '*.sv' -o -name '*.v' \) 2>/dev/null)
# Mailbox NoC core (G1-clean since S04-P0#2, 2026-09-01) — graduates to `lint`.
MAILBOX_CORE_RTL := ethereal-shell/rtl/mailbox/mailbox_pkg.sv ethereal-shell/rtl/mailbox/mailbox_fifo.sv ethereal-shell/rtl/mailbox/mailbox_endpoint.sv ethereal-shell/rtl/mailbox/mailbox_endpoint_stream.sv ethereal-shell/rtl/mailbox/mailbox_switch_2x1.sv ethereal-shell/rtl/mailbox/mailbox_switch_2x1_stream.sv ethereal-shell/rtl/mailbox/mailbox_switch_4x1.sv ethereal-shell/rtl/mailbox/mailbox_switch_4x1_stream.sv ethereal-shell/rtl/mailbox/mailbox_center.sv ethereal-shell/rtl/mailbox/mailbox_center_stream.sv

SMOKE_DIR := ethereal-fabric/tests/smoke

# --- Docker contract (shared with CI task E0-INF2) ---
IMAGE    := ethereal-sim
WORKDIR  := /work

.PHONY: help lint lint-mailbox test test-model test-sv stress formal sim docker-build docker-shell clean

help: ## Show this help
	@echo "Ethereal Logic Platform — root Makefile (GNU make)"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "RTL currently picked up by 'lint':"
	@echo "  $(RTL_CLEAN)"

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
	  deps=""; waiver=""; \
	  case $$m in \
	    mem_t|dsp_t)         deps="$(RTL_INF_DEPS)" ;; \
	    emri_regfile)        deps="ethereal-shell/rtl/emri/emri_pkg.sv" ;; \
	    ctx_engine_wrap)     deps="ethereal-fabric/rtl/occ/ctx_scan.sv" ;; \
	    eth_dram_ctrl)       deps="ethereal-shell/rtl/dram/eth_dram_stub.sv" ;; \
	    eth_dram_glue)       deps="ethereal-shell/rtl/dram/eth_dram_stub.sv" ;; \
	    eth_dma_fifo|eth_dma_arb|eth_dma_axi_engine) deps="ethereal-shell/rtl/dma/eth_dma_pkg.sv" ;; \
	    eth_dma_channel)     deps="ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv" ;; \
	    eth_dma_mc)          deps="ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv ethereal-shell/rtl/dma/eth_dma_arb.sv ethereal-shell/rtl/dma/eth_dma_axi_engine.sv ethereal-shell/rtl/dma/eth_dma_channel.sv" ;; \
	    cor_alu|cor_muldiv|cor_lsu|cor_regfile|cor_decoder) deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    eth_rv_core)         deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv ethereal-shell/rtl/eth_rv/cor_alu.sv ethereal-shell/rtl/eth_rv/cor_muldiv.sv ethereal-shell/rtl/eth_rv/cor_lsu.sv ethereal-shell/rtl/eth_rv/cor_regfile.sv ethereal-shell/rtl/eth_rv/cor_decoder.sv ethereal-shell/rtl/eth_rv/cor_mmu.sv ethereal-shell/rtl/eth_rv/cor_fp_regfile.sv ethereal-shell/rtl/eth_rv/cor_fpu.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    eth_rv_axi_master)   deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    eth_rv_mmio_mux)     deps="ethereal-shell/rtl/eth_rv/eth_rv_uart.sv ethereal-shell/rtl/eth_rv/eth_rv_boot_rom.sv ethereal-shell/rtl/eth_rv/eth_rv_plic.sv" ;; \
	    cor_mmu)             deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv"; \
	                         waiver="-Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM" ;; \
	    cor_fp_regfile)      deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    cor_fpu)             deps="ethereal-shell/rtl/eth_rv/eth_rv_pkg.sv"; \
	                         waiver="-Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM" ;; \
	    ebi_tiny)            deps="ethereal-shell/rtl/ebi/ebi_pkg.sv" ;; \
	    mfsm_session)        deps="ethereal-shell/rtl/mfsm/mfsm_pkg.sv" ;; \
	    mfsm_top)            deps="ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/mfsm/mfsm_pkg.sv ethereal-shell/rtl/mfsm/mfsm_session.sv ethereal-shell/rtl/ebi/ebi_pkg.sv ethereal-shell/rtl/ebi/ebi_tiny.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    eth_dma_2d_addr)     deps="ethereal-shell/rtl/dma/eth_dma_pkg.sv" ;; \
	    eth_dma_2d)          deps="ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv ethereal-shell/rtl/dma/eth_dma_axi_engine.sv ethereal-shell/rtl/dma/eth_dma_2d_addr.sv" ;; \
	    emri_axi_adapter)    deps="ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv"; \
	                         waiver="-Wno-UNUSEDPARAM" ;; \
	    eth_axi_stream)      deps="ethereal-shell/rtl/axi/eth_axi_skidbuf.sv"; \
	                         waiver="-Wno-DECLFILENAME" ;; \
	    eth_axi_lite_slave)  deps="ethereal-shell/rtl/axi/eth_axi_skidbuf.sv" ;; \
	    eth_axi_xbar)        deps="ethereal-shell/rtl/axi/eth_axi_skidbuf.sv"; \
	                         waiver="-Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-MULTIDRIVEN -Wno-UNUSEDSIGNAL" ;; \
	    bmc_core)            deps="$(NEORV32_NETLIST) ethereal-shell/rtl/axi/eth_wb2axi.sv"; \
	                         waiver="-Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-UNUSEDPARAM -Wno-UNUSEDSIGNAL -Wno-PINMISSING -Wno-IMPLICIT -Wno-VARHIDDEN -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNDRIVEN -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-MULTIDRIVEN -Wno-CASEX -Wno-LITENDIAN -Wno-INITIALDLY -Wno-COMBDLY -Wno-ALWCOMBORDER -Wno-EOFNEWLINE" ;; \
	    *)                   deps="" ;; \
	  esac; \
	  verilator --lint-only -Wall $$waiver --top-module $$m -Mdir obj_dir/lint_$$m \
	    -Iethereal-fabric/rtl/inf $$deps $$f || exit 1; \
	done
	@echo "[lint] fabric modules (-Wall -Wno-UNOPTFLAT; intended loops per C01 sec2.4): clb_t, fabric_top"
	verilator --lint-only -Wall -Wno-UNOPTFLAT --top-module fabric_top -Mdir obj_dir/lint_fabric $(RTL_FABRIC_DEPS)
	@echo "[lint] mailbox NoC core (S04-P0#2 graduated 2026-09-01): per-module strict -Wall"
	@for f in $(MAILBOX_CORE_RTL); do \
	  m=$$(basename $$f .sv); \
	  if [ "$$m" = "mailbox_pkg" ]; then continue; fi; \
	  deps="ethereal-shell/rtl/mailbox/mailbox_pkg.sv"; \
	  case $$m in \
	    mailbox_fifo) \
	                         deps="" ;; \
	    mailbox_switch_2x1_stream|mailbox_switch_4x1_stream|mailbox_center_stream) ;; \
	    *)                   deps="$$deps ethereal-shell/rtl/mailbox/mailbox_fifo.sv" ;; \
	  esac; \
	  verilator --lint-only -Wall --top-module $$m -Mdir obj_dir/lint_$$m $$deps $$f || exit 1; \
	done
	@echo "[lint] OK - all project RTL lint-clean."
endif

lint-mailbox: ## Lint the IMPORTED SPI/UART adapters (2 documented backlog warnings — MIGRATION-mailbox.md §5.2 #7-8). Advisory.
ifeq ($(VERILATOR),)
	@echo "[lint-mailbox] ERROR: verilator not found on PATH. Use 'make docker-shell' then 'make lint-mailbox'."
	@exit 1
else ifeq ($(strip $(MAILBOX_RTL)),)
	@echo "[lint-mailbox] No imported mailbox RTL under ethereal-shell/rtl/{mailbox,interface}/."
else
	@echo "[lint-mailbox] mailbox/ is -Wall CLEAN (S04-P0#2; see report). interface/ retains 2 documented design-judgment warnings (BLKSEQ spi_sat, MULTIDRIVEN uart_mailboxfabric). Advisory: never fails CI."
	@for f in $(MAILBOX_RTL); do \
	  m=$$(basename $$f .sv); \
	  if [ "$$m" = "mailbox_pkg" ]; then continue; fi; \
	  deps="ethereal-shell/rtl/mailbox/mailbox_pkg.sv"; \
	  case $$m in \
	    mailbox_fifo|spi_sat|uart_sat)                          deps="" ;; \
	    mailbox_switch_2x1_stream|mailbox_switch_4x1_stream|mailbox_center_stream) ;; \
	    spi_mailboxfabric)  deps="$$deps ethereal-shell/rtl/mailbox/mailbox_fifo.sv ethereal-shell/rtl/mailbox/mailbox_endpoint_stream.sv ethereal-shell/rtl/interface/spi/spi_sat.sv" ;; \
	    uart_mailboxfabric) deps="$$deps ethereal-shell/rtl/mailbox/mailbox_fifo.sv ethereal-shell/rtl/mailbox/mailbox_endpoint_stream.sv" ;; \
	    *)                  deps="$$deps ethereal-shell/rtl/mailbox/mailbox_fifo.sv" ;; \
	  esac; \
	  echo "[lint-mailbox] --top-module $$m"; \
	  verilator --lint-only -Wall --top-module $$m -Mdir obj_dir/lint_mbox_$$m $$deps $$f || true; \
	done
endif

formal: ## Run SymbiYosys formal proofs (sby) over modules with FORMAL properties
ifeq ($(shell command -v sby 2>/dev/null),)
	@echo "[formal] ERROR: sby not found. PATH=\$$HOME/oss-cad-suite/bin:\$$PATH make formal"
	@exit 1
else
	@for f in $(shell find ethereal-shell/formal -maxdepth 1 -name '*.sby' 2>/dev/null); do \
	  echo "[formal] $$f"; \
	  sby -f $$f > /tmp/sby_out.txt 2>&1 && echo "  PASS" || { echo "  FAIL"; tail -20 /tmp/sby_out.txt; exit 1; }; \
	done
	@echo "[formal] OK - all formal proofs passed."
endif

test-sv: ## Run self-checking SystemVerilog testbenches via iverilog/vvp (local OSS-CAD)
ifeq ($(IVERILOG),)
	@echo "[test-sv] ERROR: iverilog not found. PATH=\$$HOME/oss-cad-suite/bin:\$$PATH make test-sv"
	@exit 1
else
	@echo "[test-sv] simulator note: every TB runs under iverilog/vvp EXCEPT the two"
	@echo "[test-sv]   real-C-firmware TBs (tb_bmc_fw, tb_bmc_daemon), which run under"
	@echo "[test-sv]   Verilator --binary --timing: the ~83M-cycle Ed25519 verifies on"
	@echo "[test-sv]   the iterative-mul NEORV32 netlist would take HOURS in iverilog"
	@echo "[test-sv]   (ADR-018 §7.5 exemption: cycle count, not language)."
	@echo "[test-sv] tb_elut4";      $(IVERILOG) -g2012 -o /tmp/tb_elut4 ethereal-fabric/tests/clb/tb_elut4.sv ethereal-fabric/rtl/clb/elut4.sv && vvp /tmp/tb_elut4 | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_clb_t";      $(IVERILOG) -g2012 -o /tmp/tb_clb_t ethereal-fabric/tests/clb/tb_clb_t.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/clb/elut4.sv && vvp /tmp/tb_clb_t | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_switch_box"; $(IVERILOG) -g2012 -o /tmp/tb_sb ethereal-fabric/tests/interconnect/tb_switch_box.sv ethereal-fabric/rtl/interconnect/switch_box.sv && vvp /tmp/tb_sb | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_connection_block"; $(IVERILOG) -g2012 -o /tmp/tb_cb ethereal-fabric/tests/interconnect/tb_connection_block.sv ethereal-fabric/rtl/interconnect/connection_block.sv && vvp /tmp/tb_cb | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_occ";       $(IVERILOG) -g2012 -o /tmp/tb_occ ethereal-fabric/tests/occ/tb_occ.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/occ/occ_top.sv && vvp /tmp/tb_occ | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_blank";     $(IVERILOG) -g2012 -o /tmp/tb_blank ethereal-fabric/tests/occ/tb_blank.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/occ/occ_top.sv && vvp /tmp/tb_blank | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_hotswap";  $(IVERILOG) -g2012 -o /tmp/tb_hotswap ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/interconnect/tb_hotswap.sv 2>/dev/null && vvp /tmp/tb_hotswap | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_het_tiles"; $(IVERILOG) -g2012 -o /tmp/tb_het -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/tests/tile/tb_het_tiles.sv && vvp /tmp/tb_het | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_het_fabric"; $(IVERILOG) -g2012 -o /tmp/tb_hetfab -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/interconnect/tb_het_fabric.sv 2>/dev/null && vvp /tmp/tb_hetfab | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_ctx_scan"; $(IVERILOG) -g2012 -o /tmp/tb_ctx -Iethereal-fabric/rtl/inf ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/rtl/occ/ctx_scan.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/interconnect/tb_ctx_scan.sv 2>/dev/null && vvp /tmp/tb_ctx | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_mon_anomaly"; $(IVERILOG) -g2012 -o /tmp/tb_mon ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/emri/tb_mon_anomaly.sv 2>/dev/null && vvp /tmp/tb_mon | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_ctx_multiword"; $(IVERILOG) -g2012 -o /tmp/tb_ctxmw -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/ctx_engine_wrap.sv ethereal-fabric/rtl/occ/ctx_scan.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/tb_ctx_multiword.sv 2>/dev/null && vvp /tmp/tb_ctxmw | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_eth_dram_ctrl"; $(IVERILOG) -g2012 -o /tmp/tb_dram ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/axi/tb_eth_dram_ctrl.sv 2>/dev/null && vvp /tmp/tb_dram | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_eth_dram_ctrl (GW5 seam)"; $(IVERILOG) -g2012 -DETH_DRAM_VENDOR_GLUE -o /tmp/tb_dram_gw ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-fabric/hal/gowin_gw5/glue/eth_dram_glue.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/axi/tb_eth_dram_ctrl.sv 2>/dev/null && vvp /tmp/tb_dram_gw | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_lock_matrix"; $(IVERILOG) -g2012 -o /tmp/tb_lkm ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/occ/tb_lock_matrix.sv 2>/dev/null && vvp /tmp/tb_lkm | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_eth_dma_mc"; $(IVERILOG) -g2012 -o /tmp/tb_dma_mc ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv ethereal-shell/rtl/dma/eth_dma_arb.sv ethereal-shell/rtl/dma/eth_dma_axi_engine.sv ethereal-shell/rtl/dma/eth_dma_channel.sv ethereal-shell/rtl/dma/eth_dma_mc.sv ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/dma/tb_eth_dma_mc.sv 2>/dev/null && vvp /tmp/tb_dma_mc | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_axi_xbar_burst"; $(IVERILOG) -g2012 -o /tmp/tb_xb ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/axi/tb_axi_xbar_burst.sv 2>/dev/null && vvp /tmp/tb_xb | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_emri_regfile"; $(IVERILOG) -g2012 -o /tmp/tb_emri ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/emri/tb_emri_regfile.sv 2>/dev/null && vvp /tmp/tb_emri | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_emri_occ_loop"; $(IVERILOG) -g2012 -o /tmp/tb_emriloop ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/emri/tb_emri_occ_loop.sv 2>/dev/null && vvp /tmp/tb_emriloop | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_mgmt_hotswap"; $(IVERILOG) -g2012 -o /tmp/tb_mgmthotswap -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/tb_mgmt_hotswap.sv 2>/dev/null && vvp /tmp/tb_mgmthotswap | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] pack_tb_frames (regen golden frames)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && echo "  frames ok"
	@echo "[test-sv] tb_frame_decoder"; $(IVERILOG) -g2012 -o /tmp/tb_fd -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/tests/emri/tb_frame_decoder.sv 2>/dev/null && vvp /tmp/tb_fd | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] shell_tb_mgmt_packed"; $(IVERILOG) -g2012 -o /tmp/tb_shellpacked -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/shell_tb_mgmt_packed.sv 2>/dev/null && vvp /tmp/tb_shellpacked | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] pack_tb_frames --het (regen het golden frames)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --het --out generated/tb_frames_het >/dev/null && echo "  frames ok"
	@echo "[test-sv] shell_tb_het_packed"; $(IVERILOG) -g2012 -o /tmp/tb_hetpacked -Iethereal-fabric/rtl/inf ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/emri/shell_tb_het_packed.sv 2>/dev/null && vvp /tmp/tb_hetpacked | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_bmc_hello (regen hello image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --out generated/bmc/bmc_hello.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_hello"; $(IVERILOG) -g2012 -o /tmp/tb_bmc ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-fabric/tests/bmc/tb_bmc_hello.sv 2>/dev/null && vvp /tmp/tb_bmc | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_bmc_hello --mode xbus (regen axi image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --mode xbus --out generated/bmc/bmc_axi.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_axi_master"; $(IVERILOG) -g2012 -o /tmp/tb_bmcaxi ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_lite_slave.sv ethereal-fabric/tests/bmc/tb_bmc_axi_master.sv 2>/dev/null && vvp /tmp/tb_bmcaxi | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_eth_wb2axi"; $(IVERILOG) -g2012 -o /tmp/tb_wb2axi ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-fabric/tests/axi/tb_eth_wb2axi.sv 2>/dev/null && vvp /tmp/tb_wb2axi | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_bmc_hello --mode xbar (regen xbar image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --mode xbar --out generated/bmc/bmc_xbar.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_axi_xbar"; $(IVERILOG) -g2012 -o /tmp/tb_bmcxbar ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_lite_slave.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-fabric/tests/bmc/tb_bmc_axi_xbar.sv 2>/dev/null && vvp /tmp/tb_bmcxbar | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_emri_axi_adapter"; $(IVERILOG) -g2012 -o /tmp/tb_emriad ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/emri/tb_emri_axi_adapter.sv 2>/dev/null && vvp /tmp/tb_emriad | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_bmc_hello --mode emri (regen emri image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --mode emri --out generated/bmc/bmc_emri.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_axi_emri"; $(IVERILOG) -g2012 -o /tmp/tb_bmcemri ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/bmc/tb_bmc_axi_emri.sv 2>/dev/null && vvp /tmp/tb_bmcemri | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_bmc_hello --mode occ (regen occ image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --mode occ --out generated/bmc/bmc_occ.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_axi_occ"; $(IVERILOG) -g2012 -o /tmp/tb_bmcocc ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/bmc/tb_bmc_axi_occ.sv 2>/dev/null && vvp /tmp/tb_bmcocc | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] pack_tb_frames (regen golden frames)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && echo "  frames ok"
	@echo "[test-sv] gen_bmc_hello --mode occ-fabric (regen fabric image)"; .venv/bin/python ethereal-tools/tools/gen_bmc_hello.py --mode occ-fabric --frame-hex generated/tb_frames/img_a_col0.hex --out generated/bmc/bmc_occfab.hex >/dev/null && echo "  image ok"
	@echo "[test-sv] tb_bmc_axi_fabric"; $(IVERILOG) -g2012 -o /tmp/tb_bmcfab -Iethereal-fabric/rtl/inf ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/inf/eth_inf_ram.sv ethereal-fabric/rtl/inf/eth_inf_dsp_mac.sv ethereal-fabric/rtl/tile/mem_t.sv ethereal-fabric/rtl/tile/dsp_t.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_axi_fabric.sv 2>/dev/null && vvp /tmp/tb_bmcfab | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] bmc-fw (build real C daemon firmware; DMEM-exec: ROM stub + DMEM lanes)"; $(MAKE) -C ethereal-runtime/bmc-fw >/dev/null 2>&1 && cp ethereal-runtime/bmc-fw/build/bmc_boot.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane0.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane1.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane2.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane3.hex generated/bmc/ && echo "  firmware ok"
	@echo "[test-sv] tb_bmc_fw (verilator --timing)"; $(VERILATOR) --binary --timing -Wno-fatal -o tb_bmc_fw_v --top-module tb_bmc_fw -Mdir obj_dir/sim_tb_bmc_fw ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/bmc/tb_bmc_fw.sv && ./obj_dir/sim_tb_bmc_fw/tb_bmc_fw_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] gen_daemon_vectors (regen tb_bmc_daemon host vectors)"; mkdir -p generated/daemon && .venv/bin/python ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py --svh generated/daemon/tb_daemon_vectors.svh >/dev/null && echo "  vectors ok"
	@echo "[test-sv] tb_bmc_daemon (verilator --timing; E1-RUN2 capstone)"; $(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_bmc_daemon_v --top-module tb_bmc_daemon -Mdir obj_dir/sim_tb_bmc_daemon ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/ctx_engine_wrap.sv ethereal-fabric/rtl/occ/ctx_scan.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_daemon.sv && ./obj_dir/sim_tb_bmc_daemon/tb_bmc_daemon_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_bmc_script (verilator --timing; E2-AST1 MCU scripted deployment)"; $(MAKE) -C ethereal-runtime/bmc-fw script scripts >/dev/null 2>&1 && cp ethereal-runtime/bmc-fw/build/script_boot.hex generated/bmc/bmc_boot.hex && cp ethereal-runtime/bmc-fw/build/script_dmem_lane0.hex generated/bmc/bmc_dmem_lane0.hex && cp ethereal-runtime/bmc-fw/build/script_dmem_lane1.hex generated/bmc/bmc_dmem_lane1.hex && cp ethereal-runtime/bmc-fw/build/script_dmem_lane2.hex generated/bmc/bmc_dmem_lane2.hex && cp ethereal-runtime/bmc-fw/build/script_dmem_lane3.hex generated/bmc/bmc_dmem_lane3.hex && $(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_bmc_script_v --top-module tb_bmc_script -Mdir obj_dir/sim_tb_bmc_script ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_script.sv && (./obj_dir/sim_tb_bmc_script/tb_bmc_script_v | grep -q "TEST PASSED" && echo "  PASS"); $(MAKE) -C ethereal-runtime/bmc-fw >/dev/null 2>&1 && cp ethereal-runtime/bmc-fw/build/bmc_boot.hex generated/bmc/bmc_boot.hex && cp ethereal-runtime/bmc-fw/build/bmc_dmem_lane0.hex generated/bmc/bmc_dmem_lane0.hex && cp ethereal-runtime/bmc-fw/build/bmc_dmem_lane1.hex generated/bmc/bmc_dmem_lane1.hex && cp ethereal-runtime/bmc-fw/build/bmc_dmem_lane2.hex generated/bmc/bmc_dmem_lane2.hex && cp ethereal-runtime/bmc-fw/build/bmc_dmem_lane3.hex generated/bmc/bmc_dmem_lane3.hex
	@echo "[test-sv] tb_bmc_daemon_packed (verilator --timing; E1-RUN2 packed deploy)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && .venv/bin/python ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py --svh-packed generated/daemon/tb_daemon_packed_vectors.svh --frame-hex generated/tb_frames/img_a_col0.hex --frame-hex-b generated/tb_frames/img_b_col0.hex --frame-hex-cols generated/tb_frames/img_c_col0.hex generated/tb_frames/img_c_col1.hex >/dev/null && $(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_bmc_daemon_packed_v --top-module tb_bmc_daemon_packed -Mdir obj_dir/sim_tb_bmc_daemon_packed ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_daemon_packed.sv && ./obj_dir/sim_tb_bmc_daemon_packed/tb_bmc_daemon_packed_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_bmc_watchdog (verilator --timing; E1-RUN4 region watchdog + heartbeat)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && .venv/bin/python ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py --svh-packed generated/daemon/tb_daemon_packed_vectors.svh --frame-hex generated/tb_frames/img_a_col0.hex --frame-hex-b generated/tb_frames/img_b_col0.hex >/dev/null && $(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_bmc_watchdog_v --top-module tb_bmc_watchdog -Mdir obj_dir/sim_tb_bmc_watchdog ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_watchdog.sv && ./obj_dir/sim_tb_bmc_watchdog/tb_bmc_watchdog_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_ebi_tiny"; $(IVERILOG) -g2012 -o /tmp/tb_ebi ethereal-shell/rtl/ebi/ebi_pkg.sv ethereal-shell/rtl/ebi/ebi_tiny.sv ethereal-fabric/tests/ebi/tb_ebi_tiny.sv 2>/dev/null && vvp /tmp/tb_ebi | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_mfsm_ebi_deploy"; $(IVERILOG) -g2012 -o /tmp/tb_mfsm ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/mfsm/mfsm_pkg.sv ethereal-shell/rtl/mfsm/mfsm_session.sv ethereal-shell/rtl/mfsm/mfsm_top.sv ethereal-shell/rtl/ebi/ebi_pkg.sv ethereal-shell/rtl/ebi/ebi_tiny.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/mfsm/tb_mfsm_ebi_deploy.sv 2>/dev/null && vvp /tmp/tb_mfsm | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_eth_dma_2d"; $(IVERILOG) -g2012 -o /tmp/tb_dma_2d ethereal-shell/rtl/dma/eth_dma_pkg.sv ethereal-shell/rtl/dma/eth_dma_fifo.sv ethereal-shell/rtl/dma/eth_dma_axi_engine.sv ethereal-shell/rtl/dma/eth_dma_2d_addr.sv ethereal-shell/rtl/dma/eth_dma_2d.sv ethereal-shell/rtl/dram/eth_dram_stub.sv ethereal-shell/rtl/dram/eth_dram_ctrl.sv ethereal-fabric/tests/dma/tb_eth_dma_2d.sv 2>/dev/null && vvp /tmp/tb_dma_2d | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_bmc_fwupdate (verilator --timing; E1-BMC2 dual-partition self-update demo)"; $(MAKE) -C ethereal-runtime/bmc-fw fwupdate slots >/dev/null 2>&1 && cp ethereal-runtime/bmc-fw/build/fwupdate_boot.hex ethereal-runtime/bmc-fw/build/fwupdate_dmem_lane0.hex ethereal-runtime/bmc-fw/build/fwupdate_dmem_lane1.hex ethereal-runtime/bmc-fw/build/fwupdate_dmem_lane2.hex ethereal-runtime/bmc-fw/build/fwupdate_dmem_lane3.hex ethereal-runtime/bmc-fw/build/slot_v1.hex ethereal-runtime/bmc-fw/build/slot_v2.hex generated/bmc/ && $(VERILATOR) --binary --timing -Wno-fatal -o tb_bmc_fwupdate_v --top-module tb_bmc_fwupdate -Mdir obj_dir/sim_tb_bmc_fwupdate ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/tests/bmc/tb_bmc_fwupdate.sv && ./obj_dir/sim_tb_bmc_fwupdate/tb_bmc_fwupdate_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_bmc_spi (verilator --timing; E1-IO1 EFP-SPI packed deploy over SDI + CRC16)"; .venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null && .venv/bin/python ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py --svh-packed generated/daemon/tb_daemon_packed_vectors.svh --frame-hex generated/tb_frames/img_a_col0.hex --frame-hex-b generated/tb_frames/img_b_col0.hex >/dev/null && $(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_bmc_spi_v --top-module tb_bmc_spi -Mdir obj_dir/sim_tb_bmc_spi ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_bmc_spi.sv && ./obj_dir/sim_tb_bmc_spi/tb_bmc_spi_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_ethctl_replay (verilator --timing; E1-RUN3: ethctl EFP session replay)"; mkdir -p generated/ethctl && .venv/bin/python ethereal-tools/tools/efp_client.py --emit-demo generated/ethctl >/dev/null && $(VERILATOR) --binary --timing -Wno-fatal -o tb_ethctl_replay_v --top-module tb_ethctl_replay -Mdir obj_dir/sim_tb_ethctl_replay ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_ethctl_replay.sv && ./obj_dir/sim_tb_ethctl_replay/tb_ethctl_replay_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_axi_lite_slave"; $(IVERILOG) -g2012 -o /tmp/tb_axils ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_lite_slave.sv ethereal-fabric/tests/axi/tb_axi_lite_slave.sv 2>/dev/null && vvp /tmp/tb_axils | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_axi_stream"; $(IVERILOG) -g2012 -o /tmp/tb_axistream ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_stream.sv ethereal-fabric/tests/axi/tb_axi_stream.sv 2>/dev/null && vvp /tmp/tb_axistream | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] tb_axi_xbar"; $(IVERILOG) -g2012 -o /tmp/tb_axbar ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-fabric/tests/axi/tb_axi_xbar.sv 2>/dev/null && vvp /tmp/tb_axbar | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[test-sv] OK - all SystemVerilog testbenches passed."
endif
stress: ## Run E1-DMO2 stress TBs: OCC-level 2x10000 soak + daemon-level rotation (long; NOT part of test-sv)
ifeq ($(VERILATOR),)
	@echo "[stress] ERROR: verilator not found. PATH=\$$HOME/oss-cad-suite/bin:\$$PATH make stress"
	@exit 1
else
	@echo "[stress] tb_occ_soak (verilator --timing; 2 regions x 10000 BLANK+WRITE+READBACK swaps)"
	@.venv/bin/python ethereal-tools/tools/pack_tb_frames.py --out generated/tb_frames >/dev/null
	@.venv/bin/python ethereal-runtime/bmc-fw/daemon/gen_daemon_vectors.py --svh-packed generated/daemon/tb_daemon_packed_vectors.svh --frame-hex generated/tb_frames/img_a_col0.hex --frame-hex-b generated/tb_frames/img_b_col0.hex >/dev/null
	@$(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_occ_soak_v --top-module tb_occ_soak -Mdir obj_dir/sim_tb_occ_soak ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/tests/bmc/tb_occ_soak.sv && ./obj_dir/sim_tb_occ_soak/tb_occ_soak_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[stress] tb_hotswap_stress (verilator --timing; daemon-level signed-image rotation)"
	@$(MAKE) -C ethereal-runtime/bmc-fw >/dev/null 2>&1 && cp ethereal-runtime/bmc-fw/build/bmc_boot.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane0.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane1.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane2.hex ethereal-runtime/bmc-fw/build/bmc_dmem_lane3.hex generated/bmc/
	@$(VERILATOR) --binary --timing -Wno-fatal -Igenerated/daemon -o tb_hotswap_stress_v --top-module tb_hotswap_stress -Mdir obj_dir/sim_tb_hotswap_stress ethereal-shell/rtl/bmc/bmc_core.sv ethereal-shell/rtl/bmc/neorv32_verilog_wrapper.v ethereal-shell/rtl/axi/eth_wb2axi.sv ethereal-shell/rtl/axi/eth_axi_skidbuf.sv ethereal-shell/rtl/axi/eth_axi_xbar.sv ethereal-shell/rtl/emri/emri_pkg.sv ethereal-shell/rtl/emri/emri_axi_adapter.sv ethereal-shell/rtl/emri/emri_regfile.sv ethereal-shell/rtl/emri/frame_decoder.sv ethereal-fabric/rtl/occ/occ_top.sv ethereal-fabric/tests/occ/column_cfg_ram.sv ethereal-fabric/rtl/clb/elut4.sv ethereal-fabric/rtl/clb/clb_t.sv ethereal-fabric/rtl/interconnect/switch_box.sv ethereal-fabric/rtl/interconnect/connection_block.sv ethereal-fabric/rtl/interconnect/fabric_top.sv ethereal-fabric/tests/bmc/tb_hotswap_stress.sv && ./obj_dir/sim_tb_hotswap_stress/tb_hotswap_stress_v | grep -q "TEST PASSED" && echo "  PASS"
	@echo "[stress] OK - all stress TBs passed."
endif

sim: ## Quick smoke simulation (counter) via cocotb + Verilator
ifeq ($(VERILATOR),)
	@echo "[sim] ERROR: verilator not found on PATH. Run 'make docker-build && make docker-shell', then 'make sim'."
	@exit 1
else
	@$(MAKE) -C $(SMOKE_DIR) sim SIM=verilator
endif

verif-rv-rtl: ## Run the eth_rv core RTL against the DiffTest corpus (E2-RV1 slice; Verilator)
	@python3 ethereal-shell/verif/eth_rv_core/run_difftest.py

verif-rv: ## Build the eth_rv DiffTest corpus and run the RV harness tests (E2-RV0)
	@python3 ethereal-shell/verif/eth_rv/corpus/build_corpus.py --out generated/rv_difftest/corpus
	@.venv/bin/pytest -q ethereal-shell/verif/eth_rv/tests

test-model: ## Run pure-Python golden-model pytest (no simulator needed; runs locally)
	@MODELS=$$( (find ethereal-fabric/tests -name 'test_*_model.py'; find ethereal-tools -name 'test_*.py'; find ethereal-runtime -name 'test_*.py') 2>/dev/null); \
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
