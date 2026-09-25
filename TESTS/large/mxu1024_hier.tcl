# A 32x32 systolic matrix unit, synthesised and placed hierarchically.
#
#   cd TESTS/large && make mxu_1024
#
# The largest thing in this repository: 1024 mac_pe, each with its own
# vedic_16x16, in ten levels of hierarchy.  2,758,656 mapped cells, 3,424,000
# instances, 155,648 flops, 3.95mm2 of cell area.
#
#     mxu_1024         4 x mxu_256        32x32 PEs, 4609 ports
#       mxu_256        4 x mxu_tile64     16x16 PEs
#         mxu_tile64   4 x mxu_tile16      8x8 PEs
#           mxu_tile16 16 x mac_pe         4x4 PEs
#             mac_pe    1 x vedic_16x16 + 88 flops
#               vedic_16x16 ... down to halfAdder
#
# WHAT IT IS FOR
#
# Finding out whether the flow stays linear, with nothing else changing.  It is
# the same sources as the two smaller MXUs -- synthesize -top picks the size --
# so a difference between them is a difference in scale and nothing else:
#
#   design      mults  modules  instances    wall    peak
#   mxu_tile64     64      14      213,568   1m29    1.2G
#   mxu_256       256      15      855,424   5m23    4.2G
#   mxu_1024     1024      16    3,424,000   see the Makefile header
#
# Each step is four times the instances and exactly ONE more distinct module.
# That asymmetry is the thing under test.  hier_place_all walks distinct
# modules, so its cost should barely move; hier2flat, legalize_flat and
# write_def touch every instance and should go up four times.  Land near four
# times mxu_256 and the flow is linear.  Land well above and something on the
# flat side is superlinear, and this is the design that says which.
#
# EXPECT IT TO BE SLOW AND LARGE.  Synthesis and elaborate alone are 1m57 and
# 11.6GB.  Not in any "all" target, and not a thing to run while iterating --
# mxu_64 tests the same code paths for a fifteenth of the cost.
#
# A NOTE ON WHAT IT WILL NOT SHOW
#
# Not placement quality.  mxu_256 already established that: blocks land inside
# their boxes exactly and are NOT ordered into the mesh -- 2 of 4 nearest
# neighbour links adjacent at the top, 5 of 24 inside a tile16, and ten times
# the placer steps does not move it.  Adding a level does not change that
# answer, it just costs more to get.  See mxu_hier.tcl for the numbers.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# 155648 flops is the check that the hierarchy survived: 1024 PEs at 88 flops
# each plus 1024 vedic_16x16 at 64 each.  Anything else means yosys optimised
# across a boundary or flattened, and a flattened netlist has nothing in it for
# a hierarchical placer.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/mxu/mxu.f -top mxu_1024 -out synth1024 --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.  set_floorplan rather than edit_module -util, because
# legalize_flat needs the ROWs only set_floorplan creates.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place all ten levels, top down.
#
# Sixteen modules, which is one more than mxu_256 and two more than mxu_64.
# The walk does not care that there are 1024 multipliers: a module has one
# floorplan, so all 1024 copies of vedic_16x16 share one arrangement and it is
# placed once.
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design
write_def -output mxu_1024.recurse.def --overwrite

#-----------------------------------------------------------------------------
# Legalize.  The first point at which the placement is legal.
#-----------------------------------------------------------------------------
legalize_flat
write_def -output mxu_1024.legal.def --overwrite

exit
