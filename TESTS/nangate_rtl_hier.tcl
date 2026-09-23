# RTL to hierarchical placement on Nangate45: synthesis, floorplan, hier place.
#
#   cd TESTS && make nangate_rtl_hier
#
# This starts from the Verilog rather than from a netlist, and from the
# REGISTERED vedic multiplier: vedic_16x16 clocks a and b into a_reg and b_reg
# and its product into result, so the design has 64 flops and a clock.  That
# is the difference from the other two tests, which both read the checked-in
# vedic.vg -- a netlist synthesised years ago from the combinational version
# of the same design, with no flop in it anywhere.
#
# So the three tests are:
#
#   nangate_flat.tcl      vedic.vg, combinational, flat place and route
#   nangate_hier.tcl      vedic.vg, combinational, hierarchical placement
#   nangate_rtl_hier.tcl  this one: registered RTL, synthesised here, then
#                         floorplanned and placed hierarchically
#
# Needs electron_hier: edit_module, hier_place and commit_module live in the
# hier tool.

#-----------------------------------------------------------------------------
# Library
#-----------------------------------------------------------------------------
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

#-----------------------------------------------------------------------------
# Liberty, for synthesis.
#
# read_config_file records the liberty paths without opening them; --set parks
# one where synthesize looks, so the liberty is named once, in the config.
# yosys needs it for dfflibmap, which is what maps the 64 flops.
#-----------------------------------------------------------------------------
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# synthesize expands the filelist, writes the yosys script, runs it in the
# container, strips the (* *) attributes read_verilog cannot parse, and
# reports the cell count.  --read reads the filtered netlist back and
# elaborates it, so the database is ready for the floorplan.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/vedic/vedic.f -top vedic_16x16 -out synth --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.
#
# A real floorplan before edit_module, rather than letting it estimate the
# module size from cell area with -util.  The module then takes its size and
# its die from the floorplan, which is what a hierarchical run would normally
# start from.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
write_def -output vedic_16x16.fplan.def --overwrite

#-----------------------------------------------------------------------------
# Hierarchical placement.
#
# edit_module builds the pseudo model of the top from VNOM; hier_place
# arranges its blocks and ports; commit_module writes the arrangement back to
# the floorplan and hier2flat expands it into the flat database.
#
# -batch places headlessly.  hier_place is a PyQt5 window that waits for
# Save & Close, so with no display it aborts and nothing is placed; -batch
# runs the same physics for a fixed number of steps and writes the nodefile.
#
# -kinds INST,PORT places the ports too, comma separated because the command
# parser splits on whitespace and would tear a quoted list in half.
#
# What ends up placed, and what does not.
#
# The config names a cell function map, so the 64 flops are typed sequential
# and the anchor graph keeps them: 136 nodes, being 7 blocks, 65 ports and 64
# flops, where an untyped run has 72 and collapses every flop into a hyperedge
# with the logic around it.  hier_place then places the blocks AND the flops.
#
# In the DEF that means 65 pins and 152 components carry a location, but read
# the 152 carefully: 64 are the flops, at real and distinct coordinates, and
# the other 88 are top-level assign buffers sitting at ( 0 0 ).  hier2flat
# marks a leaf instance PLACED on the strength of its orientation, so a cell
# nothing ever placed still comes out PLACED at the origin.  The leaf cells
# inside the seven blocks are not placed at all; filling those is a second
# pass per module, walked bottom up.
#-----------------------------------------------------------------------------
edit_module --top
hier_place -kinds INST,PORT -batch 400
commit_module --physical_only
hier2flat --physical

report_design
write_def -output vedic_16x16.rtl_hier.def --overwrite

exit
