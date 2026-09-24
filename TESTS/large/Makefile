# The large testcases.
#
# Separate from TESTS/Makefile and deliberately NOT in nangate_all, because
# these are minutes rather than seconds and the push hook should not be waiting
# on them.  Run them when a change could plausibly scale badly.
#
# WHAT IS HERE
#
#   matmul_4x4     a 4x4 by 4x4 matrix multiply, 16 bit elements, built from
#                  the same vedic_16x16 the small tests place one of.  64
#                  multipliers, 164k mapped cells, 13 distinct modules, 7
#                  levels of hierarchy.
#
# The split that makes it worth having: hier_place_all works on the 13 distinct
# MODULES, which does not grow with the matrix, while hier2flat, write_def and
# legalize_flat work on all 200k+ INSTANCES, which does.  A change that makes
# the placer slower shows up in TESTS/nangate_recurse; a change that makes the
# flat side quadratic only shows up here.
#
# Like the tests one directory up, nothing in here launches apptainer.  Start
# the container first -- "make app" -- then run a target at its prompt.  PATH
# is prepended because the container shell sources the host ~/.bashrc, which
# puts a miniconda ahead of /usr/bin; only python3 is shadowed, and that one
# has no scipy.

ELECTRON = $(abspath ../..)

# pysparkpp is pysparkplusbuild plus qrouter.  Build it with
#   cd $(ELECTRON)/INSTALL/podman && make qrouter
PPSIF    = $(ELECTRON)/INSTALL/podman/pysparkpp.sif

# Synthesis only: RTL to mapped netlist, read back and elaborated.  About a
# minute, and the quickest way to check the RTL and the filelist still hold
# together without paying for placement.
matmul_synth:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../matmul_synth.tcl

# The whole thing: synthesise, floorplan, place all seven levels with
# hier_place_all, flatten, legalise.  Results land in TESTS/large/workarea/:
#   matmul_4x4.fplan.def     the floorplan, before any placement
#   matmul_4x4.recurse.def   after hier_place_all, unlegalised
#   matmul_4x4.legal.def     after legalize_flat
matmul_hier:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../matmul_hier.tcl

# Same run left at the prompt, so the result can be looked at: "gui" for the
# window, "legalize_flat" for the legalisation this one skips.  --nogui is what
# keeps the prompt; see the header of ../nangate_recurse_interactive.tcl for
# why that reads backwards.
matmul_hier-interactive:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../matmul_hier_interactive.tcl

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

# synth/ holds the yosys script, its log, the netlist and the decompressed
# liberty, which is a couple of GB.  It goes with the rest.
clean:
	rm -rf workarea

.PHONY: matmul_synth matmul_hier matmul_hier-interactive app clean
