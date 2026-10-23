ELECTRON = $(abspath ..)
include $(ELECTRON)/INSTALL/sparksta.mk

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

# nangate_recurse with the analytic cell pass (3RDBIN/hier_place_qp), the flops
# placed with the logic, and identical sibling blocks laid out on a grid.  Fails
# unless the new placer ran for all eleven modules, they were all placed, and
# legalize_flat got through.  ELECTRON_HOME is set because the container image
# bakes in the main checkout's, and -cells_placer qp resolves the placer from
# it: a branch would otherwise be tested against master's 3RDBIN.
QP_EXPECT = grep -q "$(1)" workarea/recurse_qp.log || { echo "nangate_recurse_qp: expected \"$(1)\" in workarea/recurse_qp.log"; exit 1; }
nangate_recurse_qp:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH ELECTRON_HOME=$(ELECTRON) $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_recurse_qp.tcl > recurse_qp.log 2>&1
	test `grep -c "^hier_place_qp: \(wrote\|no movable\)" workarea/recurse_qp.log` -eq 11 || { echo "nangate_recurse_qp: hier_place_qp did not run for all 11 modules"; exit 1; }
	$(call QP_EXPECT,HR_PL_ALL : 016 : 11 module(s) placed)
	$(call QP_EXPECT,INFO-ALG-LEGAL : 018 : legalized)
	@echo "nangate_recurse_qp: all expected results"

# nangate_recurse_qp legalized module by module (hier_place_all --legalize) and
# repaired with legalize_flat --incremental instead of a full flat pass.  Fails
# unless every module was legalized, the repair ran, and 3RDBIN/def_check_legal
# finds nothing illegal in the result.
HL_EXPECT = grep -q "$(1)" workarea/recurse_hl.log || { echo "nangate_recurse_hl: expected \"$(1)\" in workarea/recurse_hl.log"; exit 1; }
nangate_recurse_hl:
	mkdir -p workarea
	egrep -v "\(\*" rtls/vedic/vedic.vg > workarea/vedic_filter.vg
	cd workarea ; PATH=/usr/bin:$$PATH ELECTRON_HOME=$(ELECTRON) $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../nangate_recurse_hl.tcl > recurse_hl.log 2>&1
	test `grep -c "LEG_MOD : 010" workarea/recurse_hl.log` -eq 11 || { echo "nangate_recurse_hl: legalize_module did not run for all 11 modules"; exit 1; }
	$(call HL_EXPECT,INFO-ALG-LEGAL : 054 : --incremental)
	cd workarea ; $(ELECTRON)/3RDBIN/def_check_legal vedic_16x16.hl.legal.def load_lefs.tcl > recurse_hl.check || { cat recurse_hl.check; echo "nangate_recurse_hl: vedic_16x16.hl.legal.def is not legal"; exit 1; }
	@echo "nangate_recurse_hl: all expected results"

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

# Escaped names, end to end.  Synthesis writes every net a flatten builds from
# a generate scope or an absorbed child as an escaped name, "\\g_lane[3].u.n ";
# no other test has one, and three commands mishandled them before it existed.
# Checked: the synthesised netlist has them; repair_drive buffers the
# overloaded enable, one of whose nets is escaped; the repaired netlist reads
# back to the same instance count with no driver left over its limit; yosys
# parses it.  The sizing table is built here from the test liberty.
NG_SIZING = library/nangate.sizing.tsv
$(NG_SIZING): library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib $(ELECTRON)/3RDBIN/liberty_sizing
	python3 $(ELECTRON)/3RDBIN/liberty_sizing -o $@ -j 1 $<

nangate_escaped: $(NG_SIZING)
	mkdir -p workarea/escaped && find workarea/escaped -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/escaped && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../escaped/escaped.tcl > run.log 2>&1
	grep -qF '\' workarea/escaped/esc_hier.v || { echo "nangate_escaped: no escaped name in the synthesised netlist -- the test no longer tests anything"; exit 1; }
	grep -qE "RP_DRV : 008 : .* [1-9][0-9]* buffer" workarea/escaped/run.log || { echo "nangate_escaped: repair_drive added no buffer, see workarea/escaped/run.log"; exit 1; }
	grep -qE "repdrv_buf_[0-9]+ *\\(.*\\\\" workarea/escaped/esc_repaired.v || { echo "nangate_escaped: no buffer drives an escaped net"; exit 1; }
	cd workarea/escaped && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../escaped/escaped_rb.tcl > readback.log 2>&1
	grep -q "iteration 1: 0 driver(s) over max_capacitance" workarea/escaped/readback.log || { echo "nangate_escaped: the repaired netlist still has drivers over their limit, see workarea/escaped/readback.log"; exit 1; }
	a=$$(grep "Instance count" workarea/escaped/run.log | tail -1 | grep -oE "[0-9]+$$"); b=$$(grep "Instance count" workarea/escaped/readback.log | tail -1 | grep -oE "[0-9]+$$"); \
	  [ -n "$$a" ] && [ "$$a" = "$$b" ] || { echo "nangate_escaped: repaired $$a instance(s), read back $$b"; exit 1; }
	cd workarea/escaped && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire esc_repaired.v; hierarchy -check -top esc_top" > yosys.log 2>&1 || { echo "nangate_escaped: the repaired netlist does not parse, see workarea/escaped/yosys.log"; exit 1; }
	@echo "nangate_escaped: escaped names survive synthesis, repair, write and read-back"

# Buffer trees, port-local.  A select fans out to 256 gates inside a child
# module that is instantiated twice and kept as its own module (-flatten_below
# 0); -margin 0.1 makes that load need a tree.  The tree must be built inside
# the shared child definition, on its sel port, so both copies have it and the
# top's driver sees only the tree inputs, and the child's clock, the same
# fanout through a port, is left for CTS.  Checked: the tree is reported and
# is in bt_bank; the repaired netlist reads back to the same instance count
# with no driver left over its limit; yosys parses it.
nangate_buftree: $(NG_SIZING)
	mkdir -p workarea/buftree && find workarea/buftree -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/buftree && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../buftree/buftree.tcl > run.log 2>&1
	awk -F'\t' '$$1=="tree" && $$2=="bt_bank" && $$3=="sel" && $$4 ~ /^256 load/' workarea/buftree/repair.rpt | grep -q . || { echo "nangate_buftree: no tree on bt_bank's sel port, see workarea/buftree/repair.rpt"; exit 1; }
	[ "$$(awk '/^module bt_bank/,/^endmodule/' workarea/buftree/bt_repaired.v | grep -c repdrv_tb_)" -gt 1 ] || { echo "nangate_buftree: the tree is not inside bt_bank"; exit 1; }
	awk -F'\t' '$$1=="tree" && $$3 ~ /clk/' workarea/buftree/repair.rpt | grep -q . && { echo "nangate_buftree: a clock net was given a buffer tree"; exit 1; } || true
	grep -q "RP_DRV : 012 : 2 clock net" workarea/buftree/run.log || { echo "nangate_buftree: the two clock nets (bt_bank.clk and the top clk feeding it) were not both recognised, see workarea/buftree/run.log"; exit 1; }
	cd workarea/buftree && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../buftree/buftree_rb.tcl > readback.log 2>&1
	grep -q "iteration 1: 0 driver(s) over max_capacitance" workarea/buftree/readback.log || { echo "nangate_buftree: the repaired netlist still has drivers over their limit, see workarea/buftree/readback.log"; exit 1; }
	a=$$(grep "Instance count" workarea/buftree/run.log | tail -1 | grep -oE "[0-9]+$$"); b=$$(grep "Instance count" workarea/buftree/readback.log | tail -1 | grep -oE "[0-9]+$$"); \
	  [ -n "$$a" ] && [ "$$a" = "$$b" ] || { echo "nangate_buftree: repaired $$a instance(s), read back $$b"; exit 1; }
	cd workarea/buftree && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire bt_repaired.v; hierarchy -check -top bt_top" > yosys.log 2>&1 || { echo "nangate_buftree: the repaired netlist does not parse, see workarea/buftree/yosys.log"; exit 1; }
	@echo "nangate_buftree: a port-local tree in the shared child, read back clean"

# Buffer trees with mixed loads.  A reset reaches 128 flops in the parent and,
# through their rst ports, 4 copies of a child with 64 flops each.  repair_drive
# must upsize before it builds trees (the child's reset inverters grow, which
# lifts the child's port load over the tree threshold, so the child builds its
# own port-local tree) and give each tree group a buffer that carries it.
# Before both fixes the read-back found 19 inserted buffers over their limit:
# trees sized on pre-upsize loads, and a "largest buffer" that a lexical $b
# turned into the smallest.  Checked: the child's tree, a clean read-back with
# the same instance count, and a netlist yosys parses.
nangate_buftree_mixed: $(NG_SIZING)
	mkdir -p workarea/buftree2 && find workarea/buftree2 -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/buftree2 && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../buftree/buftree2.tcl > run.log 2>&1
	awk -F'\t' '$$1=="tree" && $$2=="bt2_child" && $$3=="rst"' workarea/buftree2/repair.rpt | grep -q . || { echo "nangate_buftree_mixed: no port-local tree on bt2_child's rst, see workarea/buftree2/repair.rpt"; exit 1; }
	cd workarea/buftree2 && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../buftree/buftree2_rb.tcl > readback.log 2>&1
	grep -q "iteration 1: 0 driver(s) over max_capacitance" workarea/buftree2/readback.log || { echo "nangate_buftree_mixed: the repaired netlist still has drivers over their limit, see workarea/buftree2/readback.log"; exit 1; }
	cd workarea/buftree2 && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire bt2_repaired.v; hierarchy -check -top bt2_top" > yosys.log 2>&1 || { echo "nangate_buftree_mixed: the repaired netlist does not parse, see workarea/buftree2/yosys.log"; exit 1; }
	@echo "nangate_buftree_mixed: upsize first, a port-local tree in the child, read back clean"

# A gate whose load is behind assigns.  read_verilog holds an assign as a
# buffer instance and write_verilog writes it back as the assign, so counting
# it as a cell undercounts the load.  The read-back is of the repaired netlist
# flattened by yosys, which merges the assigns into plain nets -- electron's
# own read-back would hold them as buffers again and repeat the mistake.  The
# committed code before the fix saw no violator here; this read-back found one.
nangate_assignload: $(NG_SIZING)
	mkdir -p workarea/assignload && find workarea/assignload -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/assignload && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../assignload/assignload.tcl > run.log 2>&1
	[ "$$(grep -c '^\s*assign' workarea/assignload/al_repaired.v)" -gt 0 ] || { echo "nangate_assignload: no assign in the netlist -- the test no longer tests anything"; exit 1; }
	awk -F'\t' '$$1=="resize" && $$2=="al_src"' workarea/assignload/repair.rpt | grep -q . || { echo "nangate_assignload: the gate behind the assigns was not upsized, see workarea/assignload/repair.rpt"; exit 1; }
	cd workarea/assignload && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire al_repaired.v; hierarchy -check -top al_top; flatten; opt_clean -purge; write_verilog -noattr al_flat.v" > yosys.log 2>&1 || { echo "nangate_assignload: the repaired netlist does not flatten, see workarea/assignload/yosys.log"; exit 1; }
	cd workarea/assignload && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../assignload/assignload_rb.tcl > readback.log 2>&1
	grep -q "iteration 1: 0 driver(s) over max_capacitance" workarea/assignload/readback.log || { echo "nangate_assignload: flattened, the repaired netlist still has a driver over its limit, see workarea/assignload/readback.log"; exit 1; }
	@echo "nangate_assignload: the load behind assigns counted, clean once they are merged"

# fix_multiple_port_nets on the same design: the child's seven port-to-port
# aliases and its feedthrough become buffers, the written child has no assign
# left, and the netlist reads back to the same instances with nothing over its
# limit.
nangate_mpn: $(NG_SIZING)
	mkdir -p workarea/mpn && find workarea/mpn -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/mpn && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../assignload/mpn.tcl > run.log 2>&1
	[ "$$(awk -F'\t' '$$6=="port to port"' workarea/mpn/mpn.rpt | wc -l)" -eq 7 ] && [ "$$(awk -F'\t' '$$6=="feedthrough"' workarea/mpn/mpn.rpt | wc -l)" -eq 1 ] || { echo "nangate_mpn: expected 7 port-to-port assigns and 1 feedthrough made buffers, see workarea/mpn/mpn.rpt"; exit 1; }
	[ "$$(awk '/^module al_src/,/^endmodule/' workarea/mpn/al_mpn.v | grep -c '^\s*assign')" -eq 0 ] || { echo "nangate_mpn: al_src still has assigns, see workarea/mpn/al_mpn.v"; exit 1; }
	[ "$$(awk '/^module al_src/,/^endmodule/' workarea/mpn/al_mpn.v | grep -c fmpn_buf_)" -eq 8 ] || { echo "nangate_mpn: al_src does not have the 8 buffers, see workarea/mpn/al_mpn.v"; exit 1; }
	cd workarea/mpn && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../assignload/mpn_rb.tcl > readback.log 2>&1
	grep -q "iteration 1: 0 driver(s) over max_capacitance" workarea/mpn/readback.log || { echo "nangate_mpn: the netlist read back has a driver over its limit, see workarea/mpn/readback.log"; exit 1; }
	a=$$(grep "Instance count" workarea/mpn/run.log | tail -1 | grep -oE "[0-9]+$$"); b=$$(grep "Instance count" workarea/mpn/readback.log | tail -1 | grep -oE "[0-9]+$$"); \
	  [ -n "$$a" ] && [ "$$a" = "$$b" ] || { echo "nangate_mpn: wrote $$a instance(s), read back $$b"; exit 1; }
	cd workarea/mpn && yosys -q -p "read_liberty -lib ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib; read_verilog -noautowire al_mpn.v; hierarchy -check -top al_top" > yosys.log 2>&1 || { echo "nangate_mpn: the netlist does not parse, see workarea/mpn/yosys.log"; exit 1; }
	@echo "nangate_mpn: port assigns made buffers, written as cells, read back clean"

# $display / $write in RTL must not reach a gate netlist.  yosys keeps them as
# $print cells through every pass and write_verilog puts them back as initial
# or always blocks; a clocked one also keeps alive the logic its arguments read.
# rtls/print/print.sv has both kinds, in the top and in a child instantiated
# twice; hier_synthesis and synthesize must each write a netlist with no
# initial, always or $write, and without the XOR that only fed the $display.
# From an empty directory: hier_synthesis resumes from an hs/design.il and an
# hs/cells.v it finds, so a stale one would be tested instead of the code.
nangate_print:
	mkdir -p workarea/print && find workarea/print -mindepth 1 -maxdepth 1 ! -name ".nfs*" -exec rm -rf {} +
	cd workarea/print && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../../print/print.tcl > run.log 2>&1
	for f in workarea/print/print_hier.v workarea/print/flat/print_top.vg; do \
	  test -s $$f || { echo "nangate_print: $$f was not written"; exit 1; }; \
	  if grep -qE 'initial|always|\$$write|\$$display' $$f; then echo "nangate_print: $$f has simulation code left in it"; exit 1; fi; \
	  if grep -qE 'X(N)?OR' $$f; then echo "nangate_print: $$f kept the logic that only fed a \$$display"; exit 1; fi; \
	done
	@echo "nangate_print: no simulation code in either netlist"

nangate_both: nangate_flat nangate_hier
nangate_all:  nangate_escaped nangate_buftree nangate_buftree_mixed nangate_assignload nangate_mpn nangate_flat nangate_hier nangate_recurse nangate_recurse_qp nangate_recurse_hl nangate_rtl_hier nangate_dead_logic nangate_print nangate_sgraph nangate_repeat

# The container the targets above need.  apptainer shell inherits DISPLAY,
# which is what lets the electron GUI open.
app:
	apptainer shell --bind /tech:/tech --bind /proj_pd:/proj_pd --bind /home/$$USER:/home/$$USER $(PPSIF)

#-----------------------------------------------------------------------------
# Timing graphs.  Synthesis writes one (nangate_rtl_hier), and so does every
# placement that ends legalized (nangate_flat, nangate_recurse): the same
# write_sgraph, before and after, so segment timing can run at both points.
#
#   nangate_sgraph    checks the graphs exist and that placement put real
#                     locations in them; part of nangate_all, costs nothing
#   nangate_store     the Nangate library as a Spark arc store, built once where
#                     CONFIG/library.config's sta-arc-store says, in seconds
#   nangate_sparksta  segment timing on Spark of the synthesis graph and the
#                     placed one; needs PYSPARK=<pyspark_cad checkout>
#   nangate_advise    Photon's optimisation advisor (repeaters, sizing) on the
#                     placed graph; needs PYSPARK
#   nangate_apply     electron applies that advice to the placed design and
#                     writes a new graph; with PYSPARK, re-timed against the advice
#   nangate_repeat    electron builds repeater trees on the 20 largest nets of the
#                     legal placement, as if advised, and an independent check of
#                     the DEF proves every sink still reached and no overlaps;
#                     with PYSPARK, the repeated graph is timed
#-----------------------------------------------------------------------------
NG_LIB   = $(ELECTRON)/TESTS/library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib
NG_STORE = $(call SPARKSTA_STORE_OF,$(ELECTRON)/CONFIG/library.config,nangate,45nm,6)
NG_PERIOD ?= 20

nangate_sgraph:
	test -s workarea/vedic_16x16.synth.sgraph || { echo "nangate_sgraph: no synthesis graph from nangate_rtl_hier"; exit 1; }
	grep -q "^NETS" workarea/vedic_16x16.synth.sgraph || { echo "nangate_sgraph: synthesis graph has no edges"; exit 1; }
	for f in place recurse; do \
	  test -s workarea/vedic_16x16.$$f.sgraph || { echo "nangate_sgraph: no vedic_16x16.$$f.sgraph"; exit 1; }; \
	  grep -v " UND" workarea/vedic_16x16.$$f.sgraph | grep -q "^NETS" || { echo "nangate_sgraph: vedic_16x16.$$f.sgraph has no placed rows"; exit 1; }; \
	done
	for f in synth place recurse; do \
	  grep -qE "^DBU [1-9][0-9]*$$" workarea/vedic_16x16.$$f.sgraph || { echo "nangate_sgraph: vedic_16x16.$$f.sgraph has no DBU line"; exit 1; }; \
	done
	@echo "nangate_sgraph: synthesis and placement graphs written, placement carries locations and its DBU"

nangate_store: $(NG_STORE)/arcs

$(NG_STORE)/arcs:
	mkdir -p workarea && echo $(NG_LIB) > workarea/nangate_libs.txt
	$(call SPARKSTA_STORE_FROM,workarea/nangate_libs.txt,$(NG_STORE))

nangate_sparksta: nangate_store
	$(call SPARKSTA,workarea/vedic_16x16.synth.sgraph,$(NG_STORE),slow,$(NG_PERIOD),workarea/sta/vedic_16x16.synth.seg.tsv)
	$(call SPARKSTA,workarea/vedic_16x16.place.sgraph,$(NG_STORE),slow,$(NG_PERIOD),workarea/sta/vedic_16x16.place.seg.tsv)

# Photon's optimisation advisor on the placed graph (needs PYSPARK too).  At
# NG_ADVISE_PERIOD most paths fail, so there are nets to repeat and cells to
# resize; the test library has no Vt column, hence VTS any.  Checked: every
# advice file is written, the summary has its three timings, and sizing ran.
NG_ADVISE_PERIOD ?= 2
nangate_advise: SPARKSTA_CELLS = $(NG_SIZING)
nangate_advise: SPARKSTA_VTS = any
nangate_advise: SPARKSTA_ROUNDS = 2
nangate_advise: SPARKSTA_ADVISE_MEM = 4g
nangate_advise: nangate_store $(NG_SIZING)
	$(call SPARKSTA_ADVISE,workarea/vedic_16x16.place.sgraph,$(NG_STORE),slow,$(NG_ADVISE_PERIOD),workarea/sta/vedic_16x16.advise)
	@if [ -n "$(PYSPARK)" ]; then \
	  for f in summary.txt nets.tsv repeaters.tsv size_rounds.txt resize.tsv; do \
	    test -s workarea/sta/vedic_16x16.advise.$$f || { echo "nangate_advise: no vedic_16x16.advise.$$f"; exit 1; }; done; \
	  [ "$$(grep -cE '^  (no wires|wires, unbuffered|wires, ideal repeaters) ' workarea/sta/vedic_16x16.advise.summary.txt)" -eq 3 ] || { echo "nangate_advise: summary lacks its three timings"; exit 1; }; \
	  grep -q "^  best:" workarea/sta/vedic_16x16.advise.size_rounds.txt || { echo "nangate_advise: sizing did not finish"; exit 1; }; \
	  echo "nangate_advise: wire plan and sizing advice written"; fi

# Applying the advice in electron: the legal placement restored onto the
# elaborated netlist (read_def --components keeps connectivity), the resizes
# applied to the flat database, legalize_flat --incremental, a new graph.
# Checked: every advised resize applied; the graph has the same edges as the
# placed one (a resize changes cells, not connectivity); and, with PYSPARK,
# Photon's re-time of the applied design is within 50 ps of the WNS the
# advisor predicted (the few cells legalization moves account for the rest).
nangate_apply: nangate_advise
	cd workarea && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../apply/apply.tcl > apply.log 2>&1
	n=$$(grep -vc '^inst' workarea/sta/vedic_16x16.advise.resize.tsv); \
	  grep -q "AP_ADV : 005 : $$n resize(s) applied" workarea/apply.log || { echo "nangate_apply: not every one of the $$n advised resize(s) applied, see workarea/apply.log"; exit 1; }
	[ "$$(grep -c '^NETS' workarea/vedic_16x16.applied.sgraph)" -eq "$$(grep -c '^NETS' workarea/vedic_16x16.place.sgraph)" ] || { echo "nangate_apply: the applied graph's edges differ from the placed one"; exit 1; }
	@if [ -n "$(PYSPARK)" ]; then \
	  $(MAKE) --no-print-directory nangate_apply_sta; \
	  p=$$(grep "^  best:" workarea/sta/vedic_16x16.advise.size_rounds.txt | awk '{print $$3}'); \
	  a=$$(tr '\r' '\n' < workarea/sta/vedic_16x16.applied.seg.tsv.log | grep -oE "photon: period [0-9.]+ +WNS -?[0-9.]+" | awk '{print $$NF}'); \
	  awk -v p=$$p -v a=$$a 'BEGIN{d=a-p; if(d<0)d=-d; exit !(d <= 0.05)}' || { echo "nangate_apply: re-timed WNS $$a ns is not within 50 ps of the predicted $$p"; exit 1; }; \
	  echo "nangate_apply: advice applied, re-timed WNS $$a ns against $$p predicted"; \
	else echo "nangate_apply: advice applied (set PYSPARK to re-time it)"; fi
nangate_apply_sta: nangate_store
	$(call SPARKSTA,workarea/vedic_16x16.applied.sgraph,$(NG_STORE),slow,$(NG_ADVISE_PERIOD),workarea/sta/vedic_16x16.applied.seg.tsv)

# The advice on this design repeats nothing -- its nets are all short -- so the
# test asks for 3 repeaters on each of its 20 largest nets, with a 40 um
# "hpwl" (a 10 um segment) and fanout 2, to get trees several levels deep.
nangate_repeat:
	test -s workarea/vedic_16x16.legal.def || { echo "nangate_repeat: no legal placement, run nangate_flat"; exit 1; }
	{ printf 'net\thpwl_um\trepeaters\trepeater_cell\n'; \
	  awk '/^NETS/{f=1;next} /^END NETS/{f=0} \
	       f && /^ *- /{if(n!="")print c"\t"n; n=$$2; c=0; next} f && /^\t\(/{c++} END{if(n!="")print c"\t"n}' \
	    workarea/vedic_16x16.legal.def | sort -k1,1nr -k2,2 | head -20 | awk '{print $$2"\t40\t3\tBUF_X4"}'; \
	} > workarea/repeat.nets.tsv
	cd workarea && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../apply/repeat.tcl > repeat.log 2>&1
	grep -q "AP_ADV : 011 : 20 net(s) of 20" workarea/repeat.log || { echo "nangate_repeat: not all 20 nets repeated, see workarea/repeat.log"; grep "AP_ADV" workarea/repeat.log; exit 1; }
	python3 apply/check_repeat.py workarea/vedic_16x16.legal.def workarea/vedic_16x16.repeated.def \
	  library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef
	[ "$$(grep -c '^NETS' workarea/vedic_16x16.repeated.sgraph)" -gt "$$(grep -c '^NETS' workarea/vedic_16x16.place.sgraph)" ] || { echo "nangate_repeat: the repeated graph has no more edges than the placed one"; exit 1; }
	@if [ -n "$(PYSPARK)" ]; then \
	  $(MAKE) --no-print-directory nangate_repeat_sta && \
	  tr '\r' '\n' < workarea/sta/vedic_16x16.repeated.seg.tsv.log | grep -E "photon: period" | tail -1; fi
	@echo "nangate_repeat: $$(grep -oE 'AP_ADV : 011 : .*' workarea/repeat.log | cut -c16-)"
# Photon's own trees (repeat.sca), then two rounds of sizing in place: a wire
# of 2000 ohm/um so that this design's short nets need repeaters at all;
# checked like nangate_repeat once electron has applied the ECO -- the overlap
# check is what proves a resized cell only grew into free space.
nangate_photon_repeat: SPARKSTA_CELLS = $(NG_SIZING)
nangate_photon_repeat: SPARKSTA_VTS = any
nangate_photon_repeat: SPARKSTA_WIRE_RC = 2000 0.2
nangate_photon_repeat: SPARKSTA_ADVISE_MEM = 4g
nangate_photon_repeat: SPARKSTA_SIZE_ROUNDS = 2
nangate_photon_repeat: nangate_store $(NG_SIZING)
	test -s workarea/vedic_16x16.legal.def || { echo "nangate_photon_repeat: no legal placement, run nangate_flat"; exit 1; }
	cd workarea && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../apply/phys.tcl > phys.log 2>&1
	$(call SPARKSTA_REPEAT,workarea/vedic_16x16.phys.sgraph,$(NG_STORE),slow,$(NG_ADVISE_PERIOD),workarea/sta/vedic_16x16.prep)
	@if [ -n "$(PYSPARK)" ]; then \
	  cd workarea && PATH=/usr/bin:$$PATH $(ELECTRON)/electron_hier --nogui --cleanlog --nolog -f ../apply/eco.tcl > eco.log 2>&1; cd ..; \
	  b=$$(grep -c '^BUF' workarea/sta/vedic_16x16.prep.eco.tsv); \
	  m=$$(grep -c '^MOVE' workarea/sta/vedic_16x16.prep.eco.tsv); \
	  r=$$(grep -c '^RESIZE' workarea/sta/vedic_16x16.prep.eco.tsv); \
	  grep -q "AP_ECO : 004 : $$b buffer(s) added, $$m cell(s) slid aside, $$r resized" workarea/eco.log || { echo "nangate_photon_repeat: the ECO's $$b buffer(s), $$m move(s) and $$r resize(s) were not applied, see workarea/eco.log"; exit 1; }; \
	  grep -q "LEGAL : 054 : --incremental: [0-9]* cell(s) already legal and kept, 0 moved" workarea/eco.log || { echo "nangate_photon_repeat: Photon placed a buffer somewhere not legal"; grep "LEGAL : 054" workarea/eco.log; exit 1; }; \
	  python3 apply/check_repeat.py workarea/vedic_16x16.legal.def workarea/vedic_16x16.eco.def library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef || exit 1; \
	  [ "$$(grep -c '^NETS' workarea/vedic_16x16.eco.sgraph)" -eq "$$(grep -c '^NETS' workarea/sta/vedic_16x16.prep.sgraph)" ] || { echo "nangate_photon_repeat: electron's graph after the ECO is not the one Photon timed"; exit 1; }; \
	  echo "nangate_photon_repeat: $$b buffer(s) placed and $$r cell(s) resized by Photon ($$m slid aside), applied by electron, legal, every sink reached"; fi
nangate_repeat_sta: nangate_store
	$(call SPARKSTA,workarea/vedic_16x16.repeated.sgraph,$(NG_STORE),slow,$(NG_PERIOD),workarea/sta/vedic_16x16.repeated.seg.tsv)
