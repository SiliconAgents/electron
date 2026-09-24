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
#   matmul_hier matmul_4x4      64      13      7     164,336    204,816   1m30   1.2G
#   mxu_64      mxu_tile64      64      14      8     172,416    213,568   1m29   1.2G
#   mxu_256     mxu_256        256      15      9     689,664    855,424   5m23   4.2G
#
# WHAT THIS DIRECTORY ALREADY PAID FOR
#
# Those numbers used to be 3m43, 3m46 and 16m19.  Half of each run was
# hier2flat's second loop, which walks the hierarchy once per net to transfer
# ROUTING -- and in a place-only flow no floorplan holds a net, so it walked
# 952,833 times to produce 1.9 million empty objects.  hier2flat now checks
# first.  Measured by running each design twice in the same build, once with
# the skip and once with --routing to force the old behaviour back:
#
#   design        nets      skipped   walked   the walk    per net
#   ----------  ---------   -------   ------   --------   --------
#   matmul_4x4    224,305    1m30      3m43      133s      0.59ms
#   mxu_tile64    238,209    1m29      3m46      137s      0.58ms
#   mxu_256       952,833    5m23     16m19      656s      0.69ms
#
# Cost per net is flat to within a fifth, and the drift upwards is the
# hierarchy getting deeper -- nine levels against seven -- which is what the
# walk climbs.  Memory went with it: 1.55G to 1.15G on matmul, 5.8G to 4.2G on
# mxu_256, being the 1.9 million objects never allocated.
#
# Nothing smaller would have shown any of this.  At the 4,233 instances of
# TESTS/nangate_recurse the same loop costs under a second.
#
# A WARNING FOR ANYONE COMPARING TWO RUNS HERE
#
# legalize_flat is NOT deterministic run to run.  Two identical runs of
# matmul_hier leave 88.8% of cells in the same place and move the rest by 11um
# on average.  hier_place_all is deterministic -- before legalization two runs
# agree on all 204,816 cells exactly -- so compare the .recurse.def, never the
# .legal.def, when you want to know whether a change did anything.
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

# The 8x8 systolic matrix unit: 64 mac_pe, 8 levels, 213,568 instances, 1m29.
# The cheaper of the two MXUs and the one to use while iterating -- same code
# paths, a quarter of the cost.
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

# The same run left at the prompt, with the legalisation undone so you can see
# the placement on both sides of it: "gui" for the window, "legalize_flat" to
# watch 855,424 cells snap into rows.  About 5m30 to get there and roughly 4GB
# held while you work.
mxu_256-interactive:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../mxu_hier_interactive.tcl

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

.PHONY: matmul_synth matmul_hier matmul_hier-interactive mxu_64 mxu_256 mxu_256-interactive mxu_both app clean
