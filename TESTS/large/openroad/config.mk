# OpenROAD-flow-scripts configuration for the electron MXU testcases.
#
# The same RTL electron places in TESTS/large, on ORFS's nangate45 platform,
# which is the same Nangate FreePDK45 cell library electron reads from
# TESTS/library -- same cell names, same 0.19 x 1.4um site.  So the two tools
# start from the same sources and the same cells, and differ in the flow.
#
# Driven by the Makefile beside this file; see its header for how to run it
# and DOCS/USER_MANUAL.md for what to compare.
#
# Pick the size with DESIGN_NAME, exactly as electron picks it with
# synthesize -top:
#   mxu_tile64    64 PEs,     ~214k instances
#   mxu_256      256 PEs,     ~855k instances
#   mxu_1024    1024 PEs,   ~3.4M instances

# ORFS includes this file, so lastword of MAKEFILE_LIST is this file's path.
MXU_CFG_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
MXU_RTL     := $(abspath $(MXU_CFG_DIR)/../rtls/mxu)
VEDIC_RTL   := $(abspath $(MXU_CFG_DIR)/../../rtls/vedic/vedicMultiplier)

export DESIGN_NAME     ?= mxu_tile64
export DESIGN_NICKNAME ?= $(DESIGN_NAME)
export PLATFORM         = nangate45

# The same list and order as TESTS/large/rtls/mxu/mxu.f.  yosys keeps only
# what DESIGN_NAME reaches, as it does for electron.
export VERILOG_FILES = \
	$(VEDIC_RTL)/halfAdder.v   $(VEDIC_RTL)/adder4.v    $(VEDIC_RTL)/adder6.v \
	$(VEDIC_RTL)/adder8.v      $(VEDIC_RTL)/adder12.v   $(VEDIC_RTL)/adder16.v \
	$(VEDIC_RTL)/adder24.v     $(VEDIC_RTL)/vedic_2x2.v $(VEDIC_RTL)/vedic_4x4.v \
	$(VEDIC_RTL)/vedic_8x8.v   $(VEDIC_RTL)/vedic_16x16.v \
	$(MXU_RTL)/mac_pe.v        $(MXU_RTL)/mxu_tile16.v  $(MXU_RTL)/mxu_tile64.v \
	$(MXU_RTL)/mxu_256.v       $(MXU_RTL)/mxu_1024.v

export SDC_FILE = $(MXU_CFG_DIR)/constraint.sdc

# Keep the module boundaries, as electron's synthesize does.  ORFS flattens by
# default, which gives yosys more room and a different cell count; keeping
# them makes the two netlists comparable.  Set it to 0 to see what ORFS does
# with its default flow.
export SYNTH_HIERARCHICAL ?= 1

# The electron scripts: set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
export CORE_UTILIZATION  ?= 50
export CORE_ASPECT_RATIO ?= 1
export PLACE_DENSITY     ?= 0.60

# Electron's placers are wirelength-only.  Turn off OpenROAD's timing and
# routability driven modes for the like-for-like run; set both to 1 for the
# "what does the full tool do" run.
export GPL_TIMING_DRIVEN      ?= 0
export GPL_ROUTABILITY_DRIVEN ?= 0
