# Hierarchical placement on Nangate45, self contained.
#
#   cd TESTS && make nangate_hier
#
# The same vedic_16x16 as nangate_flat.tcl, placed as a hierarchy instead of
# as one flat sea of cells.  vedic_16x16 holds seven hierarchical instances --
# four vedic_8x8, two adder24 and one adder16 -- and this arranges those seven
# blocks and the sixty-four ports, then pushes the result down into the flat
# database so the same write_def sees it.
#
# The flow is the hier one and needs electron_hier:
#
#   edit_module            build the pseudo model of the module from VNOM
#   hier_place -batch      arrange the blocks and ports
#   commit_module          write the arrangement back to the floorplan
#   hier2flat              expand the hierarchy into %CADB and %PORTS_ALREADY
#
# -batch is what makes this a test rather than a session.  hier_place is a
# PyQt5 window that waits for Save & Close, so with no display it aborts and
# nothing is placed; -batch runs the same physics for a fixed number of steps,
# writes the nodefile and exits.  Same placer, no window, nothing to click.
#
# WHAT THIS PLACES, AND WHAT IT DOES NOT
#
# hier_place places blocks, not cells.  After this run the seven blocks and
# the sixty-four ports of vedic_16x16 have locations, and the 4233 leaf cells
# inside those blocks do not: the DEF comes out with its PINS placed and its
# COMPONENTS unplaced.  That is the flow working as designed, not a failure.
#
# Filling the blocks is a second pass, one per module, and it is a different
# problem: a module whose children are blocks wants hier_place again, and a
# module whose children are leaf cells wants a flat placer inside its own
# floorplan.  Doing the whole tree means walking it bottom up -- halfAdder,
# the adders, vedic_2x2, vedic_4x4, vedic_8x8, then the top -- because
# commit_module sizes an instance from its child's committed floorplan, so a
# child has to be placed before its parent can be.  No such loop exists any
# more: the one that did, place_hier_mpl, drove 3RDBIN/mpl, which is not in
# this tree, so it placed nothing and committed that nothing over the whole
# hierarchy.  It has been removed.
#
# So this test covers the three commands it names, on one level of hierarchy.
# nangate_flat.tcl is the one that produces a fully placed DEF.

#-----------------------------------------------------------------------------
# Library and netlist, exactly as the flat test reads them
#-----------------------------------------------------------------------------
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design

#-----------------------------------------------------------------------------
# The pseudo model of the top module.
#
# -util sizes the module from the area of the cells underneath it, which is
# what there is to go on: no floorplan has been read and none of these modules
# has one of its own yet.  --top means the module named by TOP_MODULE.
#-----------------------------------------------------------------------------
edit_module --top -util 50

#-----------------------------------------------------------------------------
# Place the blocks and the ports.
#
# The graph handed to the placer is the anchor hypergraph: the seven blocks and
# the ports are nodes, and every cone of combinational logic between them
# becomes one hyperedge, so a connection running block -> glue -> block is one
# edge rather than two unrelated nets.
#
# -kinds INST,PORT places the ports as well as the blocks.  Comma separated on
# purpose: the command parser splits on whitespace and keeps the quotes, so a
# quoted list arrives in two pieces and the shell sees an unterminated string.
# Without the ports they keep whatever location they had, which for a module
# that has never been floorplanned is none -- and a port with no location is a
# port hier2flat cannot place.
#-----------------------------------------------------------------------------
hier_place -kinds INST,PORT -batch 400

#-----------------------------------------------------------------------------
# Commit, then flatten.
#
# --physical_only commits geometry and leaves the netlist alone.  Committing
# connectivity as well would rebuild this module's conn lines from the pseudo
# net tables, which is a thing to do deliberately and not in a placement test.
#
# hier2flat --physical is the bridge to the flat database: it walks the whole
# hierarchy and rebuilds %CADB and %PORTS_ALREADY from it, which is what
# write_def, the flat view and the routers all read.  Nothing else carries a
# hierarchical placement across to the flat side.
#-----------------------------------------------------------------------------
commit_module --physical_only
hier2flat --physical

report_design
write_def -output vedic_16x16.hier.def --overwrite

exit
