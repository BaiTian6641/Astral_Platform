# cocotb test for elut4.sv (task E0-FAB1)
# -----------------------------------------------------------------------------
# Invoked by the root Makefile as:
#     make -C ethereal-fabric/tests/clb {sim|test|lint} SIM=verilator
# The golden model elut4_model.py lives next to this test; it is put on
# PYTHONPATH so `from elut4_model import Elut4, Elut4Config` resolves.
# GNU make required. Recipes use TABS.

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog
VERILOG_SOURCES += $(CURDIR)/../../rtl/clb/elut4.sv
TOPLEVEL        = elut4
MODULE          = test_elut4

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
	verilator --lint-only -Wall $(CURDIR)/../../rtl/clb/elut4.sv
