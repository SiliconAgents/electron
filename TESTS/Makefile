ELECTRON = $(abspath ..)

# pysparkpp is pysparkplusbuild plus qrouter.  Build it with
#   cd $(ELECTRON)/INSTALL/podman && make qrouter
PPSIF    = $(ELECTRON)/INSTALL/podman/pysparkpp.sif

clean:
	rm -rf placement.*
	rm -rf *.def ;
	rm -rf *.log* electron.cmd* ;
	rm -rf all.lef
	rm -rf route.tcl
	rm -rf workarea

# Flat place and route on Nangate45, using only what is in this repository.
#
# Start the container first -- "make app" -- then "make nangate_flat" at its
# prompt.  Nothing here launches apptainer, so this behaves the same whether
# you want the GUI or not.
#
# The egrep is required, not tidying.  rtls/vedic/vedic.vg is raw yosys output
# with 103 (* src = ... *) attributes, and read_verilog cannot parse them: it
# reports "something is wrong with the verilog file" and elaborates nothing.
#
# PATH is prepended because the container shell sources the host ~/.bashrc,
# which puts a miniconda ahead of /usr/bin.  Only python3 is shadowed, and
# that miniconda has no scipy, so place_flat_design dies with "No module named
# scipy" in an image that has scipy 1.15.3.
#
# Results land in TESTS/workarea/:
#   vedic_16x16.placed.def   after the flat placer
#   vedic_16x16.legal.def    after legalisation
#   vedic_16x16.routed.def   after routing, read back into the database
#   route/route.log          qrouter's own log
#   route/failed.nets        the nets it could not finish
nangate_flat:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron --nogui --cleanlog --nolog -f ../nangate_flat.tcl

# Same run with the GUI up.  Needs DISPLAY.  The script ends in "exit";
# comment that line out if you want the GUI to stay open at the end.
nangate_flat-gui:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron --cleanlog --nolog -f ../nangate_flat.tcl

# Stop after legalisation, for looking at placement without waiting on the
# router.
nangate_flat-place:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; sed '/^qroute/,$$d' ../nangate_flat.tcl > place_only.tcl ; echo exit >> place_only.tcl
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron --nogui --cleanlog --nolog -f place_only.tcl

# Hierarchical placement of the same design: edit_module, hier_place,
# commit_module, hier2flat.  Needs electron_hier, not electron -- the pseudo
# model and these commands live in the hier tool.
#
# hier_place runs with -batch, so no window opens and nothing waits for a
# click.  It still needs PyQt5, which the container has; it does not need a
# display.
nangate_hier:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_hier.tcl

# The same design placed all the way down instead of one level deep:
# hier_place_all walks the eleven modules of the tree, placing and committing
# each one, then flattens and legalises.  This is the target that produces a
# fully placed DEF from the hierarchical flow; nangate_hier stops after the
# top's seven blocks.
nangate_recurse:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_recurse.tcl

# From the registered RTL instead of the checked-in netlist: synthesise, then
# floorplan, then place hierarchically.  This is the only test with flops in
# it -- vedic.vg, which the other two read, was synthesised from the
# combinational version of the design.
#
# No vedic_filter.vg here: synthesize runs yosys itself and does its own
# attribute filtering.
nangate_rtl_hier:
	mkdir -p workarea
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_rtl_hier.tcl

# Every test, in order of what they cover.
nangate_both: nangate_flat nangate_hier
nangate_all:  nangate_flat nangate_hier nangate_recurse nangate_rtl_hier

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)
