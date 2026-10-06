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

# The same run left running: no exit at the end, so it stops at the electron
# prompt with the placed design in memory.  Type "gui" there for the window --
# Hier-View for the blocks, FlatView plus Refresh GUI for all 4233 cells --
# and "legalize_flat" to see what legalization costs.
#
# --nogui is what keeps the prompt, which reads backwards and is not a
# mistake: without it the wrapper forks the GUI and the parent exits, leaving
# a window and no prompt.  With it the wrapper falls through to the STDIN
# loop, and "gui" still gets you the window afterwards.  See the header of
# nangate_recurse_interactive.tcl.
#
# The placement is left UNLEGALIZED on purpose; the DEF is written before you
# legalize, so there is a before to go back to.
nangate_recurse-interactive:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_recurse_interactive.tcl

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
#
# The large ones are NOT here.  TESTS/large holds a 4x4 matrix multiply built
# from 64 of the same vedic_16x16 these place one of -- 204,816 instances --
# and it takes about five minutes end to end, which is too long for something
# the push hook can be asked to run.  "cd large && make matmul_hier".
# check_dead_logic, check_const_logic and remove_dead_logic on small designs
# whose every cell has a known fate (rtls/dead_logic/dead_logic.v says which):
# a dead self-toggling flop, constants through a flop, an enable flop held by
# a constant tied in through a hierarchical port, a no-reset flop that is
# constant only for a chosen power-up value, a dead cell kept by its d0nt_
# name, and 25 loads on two constant nets for tie sharing; the last is also
# written with write_verilog --flat and must parse in yosys with its bus port
# intact.  Each runs in its own session, because removal changes the
# database.  A fourth removes with -hier from a hierarchy where one module is
# tied off in only one of its two instances (so it keeps its cells), writes it
# with write_verilog --hier, and reads it back in a fifth session to the same
# instance count.  Fails unless each removes exactly
# what it should and the checks run afterwards find nothing left.
comma := ,
DL_RUN = cd workarea/dl_$(1) && PATH=/usr/bin:$$PATH $(ELECTRON)/electron --nogui --cleanlog --nolog -f ../../dead_logic/$(1).tcl > run.log 2>&1
DL_EXPECT = grep -q "$(2)" workarea/dl_$(1)/run.log || { echo "nangate_dead_logic $(1): expected \"$(2)\""; exit 1; }
nangate_dead_logic:
	mkdir -p workarea/dl_reset workarea/dl_powerup workarea/dl_ties workarea/dl_hier
	$(call DL_RUN,reset)
	$(call DL_RUN,powerup)
	$(call DL_RUN,ties)
	$(call DL_RUN,hier)
	cd workarea/dl_hier && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../dead_logic/hier_rb.tcl > readback.log 2>&1
	$(call DL_EXPECT,reset,removing 9 instance(s)$(comma) 3 of them flops: 4 const$(comma) 2 const-flop$(comma) 2 dead$(comma) 1 dead-after-fold)
	$(call DL_EXPECT,reset,dead: 0 of)
	$(call DL_EXPECT,reset,: 0 cell(s) fold to a tie)
	$(call DL_EXPECT,powerup,removing 12 instance(s)$(comma) 4 of them flops)
	$(call DL_EXPECT,powerup,dead: 0 of)
	$(call DL_EXPECT,powerup,: 0 cell(s) fold to a tie)
	$(call DL_EXPECT,ties,added 2 tie cell(s) for 2 constant net(s))
	cd workarea/dl_ties && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog dl_ties.flat.v; hierarchy -check -top dl_ties" > yosys.log 2>&1 || { echo "nangate_dead_logic ties: write_verilog --flat output does not parse, see workarea/dl_ties/yosys.log"; exit 1; }
	grep -q "^output \[24:0\] o;" workarea/dl_ties/dl_ties.flat.v || { echo "nangate_dead_logic ties: bus port o not written as output [24:0] o"; exit 1; }
	$(call DL_EXPECT,hier,per module: 5 cell(s) in 2 module(s) go)
	grep -q "Instance count : 12" workarea/dl_hier/run.log || { echo "nangate_dead_logic hier: expected 12 instances after removal"; exit 1; }
	grep -q "Instance count : 12" workarea/dl_hier/readback.log || { echo "nangate_dead_logic hier: htop.hier.v does not read back to the same 12 instances"; exit 1; }
	cd workarea/dl_hier && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire htop.hier.v; hierarchy -check -top htop" > yosys.log 2>&1 || { echo "nangate_dead_logic hier: write_verilog --hier output does not parse, see workarea/dl_hier/yosys.log"; exit 1; }
	@echo "nangate_dead_logic: all expected results"

# $display / $write in RTL must not reach a gate netlist.  yosys keeps them as
# $print cells through every pass and write_verilog puts them back as initial
# or always blocks; a clocked one also keeps alive the logic its arguments read.
# rtls/print/print.sv has both kinds, in the top and in a child instantiated
# twice; hier_synthesis and synthesize must each write a netlist with no
# initial, always or $write, and without the XOR that only fed the $display.
nangate_print:
	mkdir -p workarea/print
	cd workarea/print && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../print/print.tcl > run.log 2>&1
	for f in workarea/print/print_hier.v workarea/print/flat/print_top.vg; do \
	  test -s $$f || { echo "nangate_print: $$f was not written"; exit 1; }; \
	  if grep -qE 'initial|always|\$$write|\$$display' $$f; then echo "nangate_print: $$f has simulation code left in it"; exit 1; fi; \
	  if grep -qE 'X(N)?OR' $$f; then echo "nangate_print: $$f kept the logic that only fed a \$$display"; exit 1; fi; \
	done
	@echo "nangate_print: no simulation code in either netlist"

nangate_both: nangate_flat nangate_hier
nangate_all:  nangate_flat nangate_hier nangate_recurse nangate_rtl_hier nangate_dead_logic nangate_print

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)
