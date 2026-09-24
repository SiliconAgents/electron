# The large testcases.
#
# Separate from TESTS/Makefile and deliberately NOT in nangate_all, because
# these are minutes rather than seconds and the push hook should not be waiting
# on them.  Run them when a change could plausibly scale badly.
#
# WHAT IS HERE
#
# Three designs, all built from the same vedic_16x16 the small tests place one
# of, and all measured on this machine:
#
#   target      design        mults  modules  levels   cells    instances  wall   peak
#   ----------  ------------  -----  -------  ------  -------  ----------  -----  ----
#   matmul_hier matmul_4x4      64      13      7     164,336    204,816   5m00   1.3G
#   mxu_64      mxu_tile64      64      14      8     172,416    213,568   3m45   1.7G
#   mxu_256     mxu_256        256      15      9     689,664    855,424  16m19   5.8G
#
# Where mxu_256's sixteen minutes go, because it is not where you would guess:
#
#   synthesis + elaborate                        0m32
#   hier_place_all, the 15 module walk           ~4m
#   hier2flat, components (855,424)              ~1m
#   hier2flat, NETS (952,833)                    ~8m     <-- the real cost
#   write_def x2 (174MB each)                    0m34
#   legalize_flat (855,424 cells)                1m49
#
# Half the run is hier2flat's net loop, which walks the hierarchy once per net.
# That is the thing to watch, and the reason this test exists.
#
# matmul_4x4 is a plain 4x4 matrix product: sixteen dot product units, four
# multipliers each.  mxu_tile64 and mxu_256 are systolic matrix units -- the
# shape an AI engine's matrix unit has, weights and partial sums shifting down
# the columns and activations along the rows, every path registered, no
# broadcast and no wire longer than one PE.  A TPU MXU is mxu_256 with 256 rows
# instead of 16, and the only difference that makes to the hierarchy is one
# more level of the same composition.
#
# WHY THERE ARE THREE AND NOT ONE
#
# Because the two halves of the flow scale differently and no single design
# separates them.
#
# hier_place_all works on the DISTINCT MODULES, and that column barely moves:
# 13, 14, 15.  A module has one floorplan, so all 256 copies of vedic_16x16
# share one arrangement and the walk places it once.  hier2flat, write_def and
# legalize_flat work on every INSTANCE, and that column goes up four times
# between mxu_64 and mxu_256 -- which are the SAME SOURCES with a different
# -top, so nothing else differs.
#
# Run the pair and the two are separated: if both slow down it is the placer,
# if only mxu_256 does it is the flat side.  TESTS/nangate_recurse, at 4,233
# instances, is the third point on that line.
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

# The 8x8 systolic matrix unit: 64 mac_pe, 8 levels, 213,568 instances.  About
# four minutes.  The cheaper of the two MXUs and the one to use while
# iterating -- same code paths, a quarter of the cost.
mxu_64:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../mxu64_hier.tcl

# The 16x16 systolic matrix unit: 256 mac_pe, 9 levels, 855,424 instances,
# about 1mm2 of cell area.  The largest thing in this repository.  Same sources
# as mxu_64 -- synthesize -top picks which -- so a difference between the two
# is a difference in scale and nothing else.
mxu_256:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../mxu_hier.tcl

# The pair, for the comparison the header describes.
mxu_both: mxu_64 mxu_256

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

# synth/ holds the yosys script, its log, the netlist and the decompressed
# liberty, which is a couple of GB.  It goes with the rest.
clean:
	rm -rf workarea

.PHONY: matmul_synth matmul_hier matmul_hier-interactive mxu_64 mxu_256 mxu_both app clean
