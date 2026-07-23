# cocotb tests for the interconnect (E0-FAB3): switch_box + fabric_top
# -----------------------------------------------------------------------------
# Default runs the fabric_top elaboration test. Override for the switch_box:
#     make -C ethereal-fabric/tests/interconnect sim TOPLEVEL=switch_box MODULE=test_switch_box
# Pure-Python golden-model + graph tests live alongside (sb_model.py,
# fabric_model.py, test_*_model.py) and run locally via `make test-model`.
# GNU make required. Recipes use TABS.

SIM            ?= verilator
TOPLEVEL_LANG  ?= verilog
CLB_DIR         = $(CURDIR)/../../rtl/clb
INT_DIR         = $(CURDIR)/../../rtl/interconnect
VERILOG_SOURCES += $(CLB_DIR)/elut4.sv $(CLB_DIR)/clb_t.sv \
                   $(INT_DIR)/switch_box.sv $(INT_DIR)/fabric_top.sv
TOPLEVEL        ?= fabric_top
MODULE          ?= test_fabric_top

export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

EXTRA_ARGS += --timing -Wall -Wno-DECLFILENAME

include $(shell cocotb-config --makefiles)/Makefile.simules

.PHONY: test lint
test: sim

lint:
	verilator --lint-only -Wall \
	  $(CLB_DIR)/elut4.sv $(CLB_DIR)/clb_t.sv \
	  $(INT_DIR)/switch_box.sv $(INT_DIR)/fabric_top.sv
