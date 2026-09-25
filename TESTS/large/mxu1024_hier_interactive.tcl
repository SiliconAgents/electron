# The 32x32 systolic matrix unit, placed hierarchically and left at the prompt.
#
#   cd TESTS/large && make mxu_1024-interactive
#
# mxu1024_hier.tcl with the legalisation and the exit taken off, so when it
# stops the placed design is still in memory: 3,424,000 instances, ten levels,
# 1024 vedic_16x16 in a weight stationary array, 3.95mm2 of cell area.
#
# Roughly fifteen minutes to get here and about 15GB held while you work.
#
# WHY --nogui KEEPS THE PROMPT
#
# The wrapper runs a -f script first and only then decides: without --nogui it
# forks the GUI and the parent exits, leaving a window and no prompt; with
# --nogui it falls through to the STDIN loop, and typing "gui" still forks the
# window afterwards.  The long version is in the header of
# ../nangate_recurse_interactive.tcl.
#
# READ THIS BEFORE TYPING "gui"
#
# The GUI is a forked child with its OWN COPY of the database.  At this size
# that is another ~15GB, so "gui" roughly doubles the memory this session
# holds.  The machine can take it; know that you are asking for it.
#
# And the FlatView will not be pleasant.  It draws one rectangle per instance,
# and there are 3.4 million of them -- expect "Refresh GUI" to take a long time
# and the canvas to be sluggish afterwards.  The Hier-View is cheap by
# comparison and is the one worth looking at here: at the top it is four boxes
# and 4609 pins.  If you want to see cells, descend first --
# "edit_module -module mac_pe" is one PE and one multiplier -- or use
# mxu_256-interactive, which is a quarter of the size and shows the same thing.
#
# THINGS WORTH TYPING WHEN IT STOPS
#
#     gui                             the window, at the cost above
#     legalize_flat                   what this script leaves undone, minutes
#     edit_module -module mxu_256     one level down
#     edit_module -module mxu_tile64  two
#     edit_module -module mac_pe      four: one PE
#     edit_module -module mxu_1024    put the top back before write_def
#
# Mind that last one.  edit_module moves TOP_MODULE, and write_def means
# TOP_MODULE by "the design": descend, then write a DEF, and you get mac_pe --
# a 79um die, no pins, and every component of the real design outside it.
#
# WHAT THIS DESIGN WAS BUILT TO SHOW
#
# Scaling, not placement quality.  mxu_256 already settled the quality
# question: blocks land inside their boxes exactly and are NOT ordered into the
# mesh, 2 of 4 nearest neighbour links adjacent at the top and 5 of 24 inside a
# tile16, and ten times the placer steps does not move it.  The numbers are in
# mxu_hier.tcl.  What this one adds is a fourth point on the instance-count
# line with only ONE more distinct module.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# 155648 flops is the check that the hierarchy survived: 1024 PEs at 88 flops
# each plus 1024 vedic_16x16 at 64 each.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/mxu/mxu.f -top mxu_1024 -out synth1024 --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.  set_floorplan rather than edit_module -util, so legalize_flat has
# the ROWs it needs when you type it at the prompt.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place all ten levels, top down
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design

#-----------------------------------------------------------------------------
# A DEF of the unlegalised placement, so there is a before to compare with
# after you legalise at the prompt.  It is about 700MB and takes ~40s.
#
# Compare THIS one between runs, not the legalised one: hier_place_all is
# deterministic and legalize_flat is not.
#-----------------------------------------------------------------------------
write_def -output mxu_1024.recurse_interactive.def --overwrite

#-----------------------------------------------------------------------------
# No exit.  The prompt is the point.
#-----------------------------------------------------------------------------
