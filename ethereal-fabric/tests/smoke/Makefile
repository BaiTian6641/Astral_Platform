# cocotb smoke test for counter.sv (task E0-INF3)
# -----------------------------------------------------------------------------
# Invoked by the root Makefile as:
#     make -C ethereal-fabric/tests/smoke {sim|test|lint} SIM=verilator
# GNU make required (cocotb's makefiles assume GNU make). Recipes use TABS.
#
# SIM defaults to verilator (matches the ethereal-sim image). Override for
# other simulators, e.g.  make sim SIM=icarus.

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog
VERILOG_SOURCES += $(CURDIR)/counter.sv
TOPLEVEL        = counter
MODULE          = test_counter

# Verilator needs --timing so cocotb's Clock / RisingEdge triggers fire.
# -Wall mirrors project rule G1; -Wno-DECLFILENAME silences the cosmetic
# "declaration filename != module name" note (file is counter.sv == module
# counter, but keep the suppression in case of fsdb/symlink scenarios).
EXTRA_ARGS += --timing -Wall -Wno-DECLFILENAME

# Pull in cocotb's verilator build + run rules (provides the default `sim`
# and `clean` targets). Must be included AFTER the variables above.
include $(shell cocotb-config --makefiles)/Makefile.simules

# --- Extra convenience targets (cocotb does not define `test` or `lint`) -------
.PHONY: test lint
test: sim

lint:
	verilator --lint-only -Wall $(CURDIR)/counter.sv
