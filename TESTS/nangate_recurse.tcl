# Recursive hierarchical placement on Nangate45: the whole tree, every level.
#
#   cd TESTS && make nangate_recurse
#
# The same vedic_16x16 as the other two tests, but placed all the way down
# rather than one level deep.  hier_place_all walks the hierarchy and runs, per
# module,
#
#   edit_module   -module M              open M, take its box from the parent
#   hier_place    -module M              blocks, flops and ports
#   hier_place_cells -module M           the combinational logic around them
#   commit_module -module M --physical_only
#
# and then reopens the top and expands the whole thing into the flat database.
#
# WHAT THIS COVERS THAT nangate_hier.tcl DOES NOT
#
# nangate_hier.tcl places the seven blocks of the top and stops, which leaves
# the 4233 leaf cells inside those blocks unplaced -- its DEF has PINS and no
# placed COMPONENTS.  This one places all 4233.
#
# The tree is eleven distinct modules and five levels deep:
#
#   vedic_16x16
#     adder16
#     adder24     x2
#     vedic_8x8   x4
#       adder12   x2
#       adder8
#       vedic_4x4 x4
#         adder4
#         adder6  x2
#         vedic_2x2 x4
#           halfAdder x2
#
# Note the multiplicities.  A module's internal placement lives in its own
# floorplan, of which there is one, so the four vedic_8x8 instances share one
# arrangement -- they come out identical, and hier_place_all says so rather
# than letting it pass unremarked.  That is the hierarchy model, not a
# shortcut: there is nowhere to put a second arrangement of one module.
#
# ORDER MATTERS AND THE TEST WOULD CATCH IT IF IT STOPPED MATTERING
#
# Parents are placed before children because a child has no size of its own
# until its instance box in the parent's committed floorplan gives it one.
# Get that backwards and the child opens with zero area, which a placer reads
# as no density: every cell lands on top of every other.  The sizes printed by
# hier_place_all show the inheritance working -- vedic_8x8 comes out 33.78um
# square because that is the box the top gave it.

#-----------------------------------------------------------------------------
# Library and netlist, exactly as the other two tests read them
#-----------------------------------------------------------------------------
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design

#-----------------------------------------------------------------------------
# A real floorplan, not -util.
#
# set_floorplan is what creates the ROWs, and legalize_flat at the end of this
# needs them: sized with edit_module -util instead, the module gets a die and
# no rows and legalization stops with "vedic_16x16 has no ROWs".
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Open the top, then place everything under it.
#
# hier_place_all leaves an already open, already sized module alone -- it will
# not reopen this one and lose the floorplan it is sitting on.
#
# -batch is what makes this a test rather than a session: hier_place is a PyQt5
# window that waits for Save & Close, and -batch runs the same physics for a
# fixed number of steps with no display and nothing to click.  It applies to
# every module in the walk.
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design
write_def -output vedic_16x16.recurse.def --overwrite

#-----------------------------------------------------------------------------
# Legalize.
#
# Nothing in the hierarchical path snaps a cell to a row: hier_place spreads on
# a continuous field, so every level comes out overlapping and off grid.  Row
# legalization happens once, here, on the flat database -- there is no
# legalizer that works on the pseudo database, and doing it per module would
# need one.
#-----------------------------------------------------------------------------
legalize_flat
write_def -output vedic_16x16.recurse.legal.def --overwrite

exit
