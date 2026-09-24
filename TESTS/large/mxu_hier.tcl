# A 16x16 systolic matrix unit, synthesised and placed hierarchically.
#
#   cd TESTS/large && make mxu_256
#
# The largest testcase here.  256 mac_pe, each with its own vedic_16x16, in the
# arrangement an AI engine's matrix unit actually has: weights and partial sums
# shifting down the columns, activations shifting along the rows, every path
# registered, no broadcast and no wire longer than one PE.
#
#     mxu_256          4 x mxu_tile64     16x16 PEs, 2305 ports
#       mxu_tile64     4 x mxu_tile16      8x8 PEs
#         mxu_tile16  16 x mac_pe          4x4 PEs
#           mac_pe     1 x vedic_16x16 + 88 flops
#             vedic_16x16 ... down to halfAdder
#
# Nine levels, fifteen distinct modules, 689,664 mapped cells, 855,424
# instances, 38,912 flops, about 1mm2 of cell area.
#
# WHY A SYSTOLIC ARRAY IS THE RIGHT SHAPE FOR THIS TEST
#
# Two reasons, and they pull in opposite directions, which is the useful part.
#
# It is the EASIEST thing to place.  Four identical blocks, connected only at
# abutting edges, repeated at three levels.  A placer that cannot make a tidy
# mesh out of that cannot do anything, so the result is easy to judge by eye
# and easy to check by script: every tile's cells should sit inside its own
# block, and the four instances of a module should be identical because they
# share one floorplan.
#
# It is the HARDEST thing for the flat side.  855,424 instances is four times
# the matrix multiply and two hundred times the small test.  hier2flat composes
# a transform for every one of them, legalize_flat sorts them all into rows,
# and write_def writes them out.
#
# So the walk is cheap and constant -- fifteen modules, the same fifteen
# however big the array -- while everything after hier2flat is linear in the
# instance count.  Running this next to mxu_64, which is the SAME SOURCES with
# a different -top, separates the two: if both slow down it is the placer, if
# only this one does it is the flat side.
#
# EXPECT THIS TO TAKE A WHILE AND A FEW GIGABYTES.  16m19 and 5.8GB peak when
# this was written.  It is not in any "all" target for that reason.
#
# WHAT THE FIRST RUN MEASURED, SO THE NEXT ONE HAS SOMETHING TO BEAT
#
# Block containment is exact at every level.  Each of the four mxu_tile64
# clusters is 631.51 x 630.68um inside a block declared 747.89 square, each
# mxu_tile16 is 315.21 x 314.38 inside 315.78, each mac_pe is 78.25 x 77.42
# inside 78.81, and nothing overflows its block anywhere.  All four instances
# of a module are identical to the centimetre, which is the shared floorplan
# being shared.
#
# Mesh ORDERING is the weak part, and this design is what makes it visible.
# Measuring the manhattan distance between the centroids of PEs that are
# directly connected -- one pitch apart in a good placement:
#
#                       ideal    mean   worst   links adjacent
#   tile64 at the top   747.9   1087.6  1495.4      2 of 4
#   tile16 inside T00   315.8    474.5   632.6      2 of 4
#   mac_pe, the 4x4      78.8    197.2   370.4      5 of 24   (21%)
#
# So the placer puts the blocks in their boxes but does not order them into the
# mesh: in the 4x4 PE array only a fifth of the nearest neighbour links end up
# physically adjacent, and the average one is two and a half pitches long.
#
# That is NOT a matter of running the placer longer.  -batch 3000 instead of
# 300, ten times the steps, moves the mac_pe mean from 197.2 to 195.9um and
# leaves the adjacent count at 5 of 24.  It has converged; the local minimum it
# converges to is simply not the mesh.
#
# Worth knowing because a systolic array is the easiest placement problem there
# is -- identical blocks, nearest neighbour connections only, no broadcast -- so
# 21% is a floor on what to expect from this placer on anything harder, and any
# improvement to hier_place should move these numbers first.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# One filelist, two tops: -top mxu_256 here, -top mxu_tile64 in mxu64_hier.tcl.
# yosys's "hierarchy -check -top" keeps only what the chosen top reaches, so
# the 64 and 256 multiplier designs are literally the same sources.
#
# The flop count is the check that the hierarchy survived: 38912 is 256 PEs at
# 88 flops each plus 256 vedic_16x16 at 64 each.  Anything else means yosys
# optimised across a boundary or flattened, and a flattened netlist has nothing
# in it for a hierarchical placer.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/mxu/mxu.f -top mxu_256 -out synth256 --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.  set_floorplan rather than edit_module -util, because
# legalize_flat needs the ROWs only set_floorplan creates.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place all nine levels, top down.
#
# -batch places headlessly; without it each of the fifteen modules would open
# the hier_place window and wait for someone to press Save & Close.
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design
write_def -output mxu_256.recurse.def --overwrite

#-----------------------------------------------------------------------------
# Legalize.  The first point at which the placement is legal: nothing in the
# hierarchical path snaps a cell to a row.
#-----------------------------------------------------------------------------
legalize_flat
write_def -output mxu_256.legal.def --overwrite

exit
