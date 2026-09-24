# A 4x4 matrix multiply, synthesised and placed hierarchically all the way down.
#
#   cd TESTS/large && make matmul_hier
#
# This is the large testcase.  Same flow as TESTS/nangate_recurse.tcl on a
# design about forty times the size: 64 instances of the vedic_16x16 that the
# other tests place one of, inside 16 dot product units, under one top.
#
#     matmul_4x4        16 x vedic_dot4, 1057 ports
#       vedic_dot4      4 x vedic_16x16 + an adder tree
#         vedic_16x16   4 x vedic_8x8 + 3 adders + 64 flops
#           vedic_8x8   4 x vedic_4x4 + 3 adders
#             vedic_4x4 4 x vedic_2x2 + 3 adders
#               vedic_2x2
#                 halfAdder
#
# WHAT SCALES AND WHAT DOES NOT
#
# Thirteen distinct modules, seven levels.  Thirteen is the number
# hier_place_all works on, and it does not grow with the matrix: a module has
# one floorplan, so all 64 copies of vedic_16x16 share one arrangement and the
# walk places it once.  Placement cost is therefore roughly the same as the
# small test's.
#
# What grows is everything on the flat side.  hier2flat composes a transform
# per instance and rebuilds the flat stores from the whole hierarchy, and
# write_def and legalize_flat then work on all of it.  So this test says little
# about the hierarchical placer that nangate_recurse does not, and quite a lot
# about whether the rest of the flow survives a design of this size.
#
# That asymmetry is the point.  If a change makes the placer slower, the small
# test shows it; if a change makes the flat side quadratic, only this one does.

#-----------------------------------------------------------------------------
# Library
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

#-----------------------------------------------------------------------------
# Liberty, for synthesis: dfflibmap needs it to map the 4640 flops, and abc
# needs it to map the logic.  read_config_file records the paths without
# opening them; --set parks the first one where synthesize looks.
#-----------------------------------------------------------------------------
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# No flatten in the script synthesize writes, so the hierarchy survives -- and
# it has to, or there is nothing here to place hierarchically.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/matmul/matmul.f -top matmul_4x4 -out synth --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.
#
# set_floorplan rather than edit_module -util, because legalize_flat at the
# end needs the ROWs only set_floorplan creates.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
write_def -output matmul_4x4.fplan.def --overwrite

#-----------------------------------------------------------------------------
# Place the whole tree, top down.
#
# -batch places headlessly; without it each of the thirteen modules would open
# the hier_place window and wait for someone to press Save & Close.
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design
write_def -output matmul_4x4.recurse.def --overwrite

#-----------------------------------------------------------------------------
# Legalize.  Nothing in the hierarchical path snaps a cell to a row, so this is
# the first point at which the placement is legal.
#-----------------------------------------------------------------------------
legalize_flat
write_def -output matmul_4x4.legal.def --overwrite

exit
