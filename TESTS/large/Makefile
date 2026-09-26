# The large testcases.
#
# Separate from TESTS/Makefile and deliberately NOT in nangate_all, because
# these are minutes rather than seconds and the push hook should not be waiting
# on them.  Run them when a change could plausibly scale badly.
#
# WHAT IS HERE
#
# Four designs, all built from the same vedic_16x16 the small tests place one
# of, and all measured on this machine:
#
#   target      design        mults  modules  levels    cells     instances  wall   peak
#   ----------  ------------  -----  -------  ------  ---------  ----------  -----  ----
#   matmul_hier matmul_4x4      64      13      7       164,336     204,816   1m30   1.2G
#   mxu_64      mxu_tile64      64      14      8       172,416     213,568   1m29   1.2G
#   mxu_256     mxu_256        256      15      9       689,664     855,424   5m23   4.2G
#   mxu_1024    mxu_1024      1024      16     10     2,758,656   3,424,000  25m47  16.1G
#
# WHAT THE SCALING SET ANSWERED
#
# mxu_64, mxu_256 and mxu_1024 are the SAME SOURCES with a different -top, and
# each step is four times the instances and exactly ONE more distinct module.
# That is the whole design of the experiment, and the answer is that the flow
# is NOT uniformly linear:
#
#   phase              mxu_256   mxu_1024   ratio for 4x the cells
#   ---------------   --------  ---------  ------------------------
#   synth + elaborate     0m32      1m57    3.7x   linear
#   hier_place_all        155s       518s   3.3x   SUBlinear, ~n^0.87
#   write_def (each)       17s        38s   2.2x   sublinear
#   legalize_flat         109s       821s   7.5x   SUPERlinear, ~n^1.46
#
# hier_place_all comes out sublinear because most of it is the module walk,
# and that walk is 15 modules against 16 however many instances hang off them.
# legalize_flat was the one that hurt: 13m41 of the 25m47, over half the run,
# and the only phase getting worse per cell as the design grew.
#
# THAT HAS SINCE BEEN FIXED, which is what this test was for.  It was one line
# -- the nearest row was found by scanning every row for every cell, O(cells x
# rows), and rows grow as the square root of cells.  A bisection instead, plus
# turning the density pass off by default:
#
#   legalize_flat        mxu_256   mxu_1024
#   as measured above      109s       821s
#   after the bisection     27s       172s
#   density pass off        23s       108s
#
# so the wall times in the table above are the pessimistic ones.
#
# AND DO NOT REACH FOR -placer HERE.  IT IS SLOWER.
#
# 3RDBIN/legalize_flat is the NumPy one, and its compute genuinely is much
# faster -- 16.2s against the Perl's ~108s on mxu_1024.  End to end it loses,
# because the whole design has to be written to a text file and read back:
#
#   legalize_flat        mxu_256   mxu_1024
#   internal (Perl)         23s       128s -> 108s
#   -placer NumPy           30s       128s
#     of which compute       4.0s      16.2s
#     so marshalling        ~26s      ~112s
#
# Identical placements both ways at both sizes -- same average move, same worst
# cell -- so this is purely about where the time goes, and it goes into Perl
# writing and re-reading several million lines.  The external path only starts
# to pay once that is not text: see the note in 3RDBIN/legalize_flat.
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
# legalize_flat WAS not deterministic run to run: two identical runs of
# matmul_hier agreed on 88.8% of cells and moved the rest by 11um on average.
# It sorted over "keys %load" with no tie break and Perl randomises hash order
# per process.  Fixed -- two runs now agree on all 204,816 cells exactly, as
# hier_place_all already did.
#
# The other half of that warning still stands, and always will: two DEFs of
# one design are not comparable byte for byte, because write_def walks
# "keys %CADB" and the order differs per process.  Sort the records first.
#
# matmul_4x4 is a plain 4x4 matrix product: sixteen dot product units, four
# multipliers each.  mxu_tile64 and mxu_256 are systolic matrix units -- the
# shape an AI engine's matrix unit has, weights and partial sums shifting down
# the columns and activations along the rows, every path registered, no
# broadcast and no wire longer than one PE.  A TPU v1 MXU is mxu_1024 with 256
# rows instead of 32, and the only difference that makes to the hierarchy is
# one more level of the same composition -- which is exactly what mxu_1024 is
# over mxu_256, and mxu_256 over mxu_64.
#
# WHY THERE ARE FOUR AND NOT ONE
#
# Because the two halves of the flow scale differently and no single design
# separates them.
#
# hier_place_all works on the DISTINCT MODULES, and that column barely moves:
# 13, 14, 15, 16.  A module has one floorplan, so all 1024 copies of
# vedic_16x16 share one arrangement and the walk places it once.  hier2flat,
# write_def and legalize_flat work on every INSTANCE, and that column goes up
# four times per step.
#
# Run the set and the two are separated: if everything slows down it is the
# placer, if only the big ones do it is the flat side.  TESTS/nangate_recurse,
# at 4,233 instances, is the small end of the same line -- five points from
# 4,233 to 3,424,000, a factor of 800.
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
# about 1mm2 of cell area, 5m23.  The middle size, and the biggest one that is
# still comfortable to sit in front of.  Same sources as mxu_64 and mxu_1024 --
# synthesize -top picks which -- so a difference between them is a difference
# in scale and nothing else.
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

# The 32x32 systolic matrix unit: 1024 mac_pe, 10 levels, 3,424,000 instances,
# 3.95mm2 of cell area.  The largest thing in this repository, and slow and
# large enough that it is something you run deliberately.  Same sources again.
mxu_1024:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../mxu1024_hier.tcl

# The same run left at the prompt.  Note the cost: it holds ~15GB, and "gui"
# forks a child with its own copy, so asking for the window roughly doubles
# that.  The FlatView draws one rectangle per instance and there are 3.4
# million -- the Hier-View is the one worth looking at at this size, or use
# mxu_256-interactive, which is a quarter of the size and shows the same thing.
mxu_1024-interactive:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../mxu1024_hier_interactive.tcl

# The set, for the scaling comparison the header describes.  Four times the
# instances per step and one more distinct module per step.
mxu_both:  mxu_64 mxu_256
mxu_scale: mxu_64 mxu_256 mxu_1024

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

# synth/ holds the yosys script, its log, the netlist and the decompressed
# liberty, which is a couple of GB.  It goes with the rest.
clean:
	rm -rf workarea

.PHONY: matmul_synth matmul_hier matmul_hier-interactive mxu_64 mxu_256 mxu_256-interactive mxu_1024 mxu_1024-interactive mxu_both mxu_scale app clean
