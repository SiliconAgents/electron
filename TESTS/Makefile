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

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)
