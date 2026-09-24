# The 16x16 systolic matrix unit, placed hierarchically and left at the prompt.
#
#   cd TESTS/large && make mxu_256-interactive
#
# mxu_hier.tcl with the legalisation and the exit taken off, so when it stops
# the placed design is still in memory -- 855,424 instances of it, nine levels
# deep, 256 vedic_16x16 in a weight stationary array.
#
# About five and a half minutes to get here, and it holds roughly 4GB while you
# work.  Both numbers are in the Makefile header with the rest.
#
# WHY --nogui KEEPS THE PROMPT
#
# The wrapper runs a -f script first and only then decides: without --nogui it
# forks the GUI and the parent exits, leaving a window and no prompt; with
# --nogui it falls through to the STDIN loop, and typing "gui" still forks the
# window afterwards.  The long version is in the header of
# ../nangate_recurse_interactive.tcl.
#
# Commenting out the "exit" at the end of mxu_hier.tcl gets you most of the way
# to the same place, and that is what this file is for instead: that target
# also legalises, which is the one step you most want to run by hand here so
# you can see the placement on both sides of it.
#
# THINGS WORTH TYPING WHEN IT STOPS
#
#     gui                     the window.  Hier-View draws on tab raise;
#                             FlatView needs the "Refresh GUI" button
#     legalize_flat           what this script leaves undone, about 1m50 here
#     edit_module -module mxu_tile64     one level down
#     edit_module -module mxu_tile16     two
#     edit_module -module mac_pe         three: one PE, one multiplier
#     edit_module -module mxu_256        put the top back before write_def
#
# WHAT TO LOOK FOR, SINCE THIS DESIGN WAS BUILT TO SHOW ONE THING
#
# On the Hier-View at the top: four identical mxu_tile64 blocks that should
# form a 2x2 mesh, because that is how they are wired -- activations left to
# right, weights and partial sums top to bottom, nothing else.  They will be in
# their boxes and NOT in mesh order; measured, only 2 of the 4 nearest
# neighbour links come out adjacent, and inside a tile16 only 5 of 24.  That is
# the placer's local minimum and not a matter of running it longer.  The
# numbers are in mxu_hier.tcl's header.
#
# WARNINGS SPECIFIC TO THIS DESIGN'S SIZE
#
# "gui" forks a child with its own copy of the database, so it costs another
# few GB, and anything you place inside the window does not come back to this
# prompt.  Drawing 855,424 rectangles is not instant either -- expect the
# FlatView refresh to take a while.  The Hier-View is cheap by comparison: at
# the top it is four boxes and 2305 pins.
#
# And mind what edit_module does on the way back.  It moves TOP_MODULE, and
# write_def means TOP_MODULE by "the design": descend, then write a DEF, and
# you get mac_pe -- a 79um die, no pins, and every component of the real design
# outside the boundary.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# 38912 flops is the check that the hierarchy survived: 256 PEs at 88 flops
# each plus 256 vedic_16x16 at 64 each.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/mxu/mxu.f -top mxu_256 -out synth256 --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.  set_floorplan rather than edit_module -util, so legalize_flat has
# the ROWs it needs when you type it at the prompt.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place all nine levels, top down
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design

#-----------------------------------------------------------------------------
# A DEF of the unlegalised placement, so there is a before to compare with
# after you legalise at the prompt.
#
# Compare THIS one between runs, not the legalised one: hier_place_all is
# deterministic and legalize_flat is not.
#-----------------------------------------------------------------------------
write_def -output mxu_256.recurse_interactive.def --overwrite

#-----------------------------------------------------------------------------
# No exit.  The prompt is the point.
#-----------------------------------------------------------------------------
