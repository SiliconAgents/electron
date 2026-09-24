# An 8x8 systolic matrix unit, synthesised and placed hierarchically.
#
#   cd TESTS/large && make mxu_64
#
# The control for mxu_hier.tcl.  Same sources, same flow, a different -top:
# mxu_tile64 instead of mxu_256, so 64 mac_pe instead of 256 and one fewer
# level of composition.
#
#     mxu_tile64       4 x mxu_tile16      8x8 PEs, 1153 ports
#       mxu_tile16    16 x mac_pe          4x4 PEs
#         mac_pe       1 x vedic_16x16 + 88 flops
#           vedic_16x16 ... down to halfAdder
#
# Eight levels, fourteen distinct modules, 172,416 mapped cells, 213,568
# instances, 9,728 flops.
#
# WHY IT IS WORTH RUNNING BOTH
#
# The two designs differ by exactly one level of composition, which is four
# times the instances and ONE more distinct module.  hier_place_all works on
# distinct modules, everything after hier2flat works on instances, so running
# the pair separates a placer regression from a flat side regression: if both
# slow down it is the placer, if only mxu_256 does it is the flat side.
#
# This one is also the cheaper thing to run while iterating -- it is about a
# quarter of the cost and tests the same code paths.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# 9728 flops is the check that the hierarchy survived: 64 PEs at 88 flops each
# plus 64 vedic_16x16 at 64 each.  mxu_256 wants 38912 by the same arithmetic.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/mxu/mxu.f -top mxu_tile64 -out synth64 --read
report_design

#-----------------------------------------------------------------------------
# Floorplan
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place all eight levels, top down
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design
write_def -output mxu_tile64.recurse.def --overwrite

#-----------------------------------------------------------------------------
# Legalize
#-----------------------------------------------------------------------------
legalize_flat
write_def -output mxu_tile64.legal.def --overwrite

exit
