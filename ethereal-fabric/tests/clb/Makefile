# cocotb tests for the CLB: elut4.sv (E0-FAB1) and clb_t.sv (E0-FAB2)
# -----------------------------------------------------------------------------
# Default runs the elut4 test. Override TOPLEVEL/MODULE for clb_t:
#     make -C ethereal-fabric/tests/clb sim TOPLEVEL=clb_t MODULE=test_clb_t
#     make -C ethereal-fabric/tests/clb {sim|test|lint} SIM=verilator
# The golden models (elut4_model.py, clb_t_model.py) live next to the tests and
# are put on PYTHONPATH so the imports resolve.
# GNU make required. Recipes use TABS.

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog
VERILOG_SOURCES += $(CURDIR)/../../rtl/clb/elut4.sv $(CURDIR)/../../rtl/clb/clb_t.sv
TOPLEVEL        ?= elut4
MODULE          ?= test_elut4

# Golden model lives in this dir; export it on PYTHONPATH for the test import.
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

# Verilator needs --timing so cocotb's Clock / RisingEdge triggers fire.
# -Wall mirrors project rule G1; -Wno-DECLFILENAME silences the cosmetic note.
EXTRA_ARGS += --timing -Wall -Wno-DECLFILENAME

# Pull in cocotb's verilator build + run rules (provides the default `sim`
# and `clean` targets). Must be included AFTER the variables above.
include $(shell cocotb-config --makefiles)/Makefile.simules

# --- Extra convenience targets (cocotb does not define `test` or `lint`) -------
.PHONY: test lint
test: sim

lint:
	verilator --lint-only -Wall $(CURDIR)/../../rtl/clb/elut4.sv $(CURDIR)/../../rtl/clb/clb_t.sv
