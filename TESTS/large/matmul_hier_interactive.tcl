# The 4x4 matrix multiply, placed hierarchically and left at the prompt.
#
#   cd TESTS/large && make matmul_hier-interactive
#
# matmul_hier.tcl with the legalisation and the exit taken off, so when it
# stops the placed design -- 204,816 instances of it -- is still in memory.
#
# WHY --nogui KEEPS THE PROMPT
#
# The wrapper runs a -f script first and only then decides: without --nogui it
# forks the GUI and the parent exits, leaving a window and no prompt; with
# --nogui it falls through to the STDIN loop, and typing "gui" still forks the
# window afterwards.  The long version of this is in the header of
# ../nangate_recurse_interactive.tcl.
#
# THINGS WORTH TYPING WHEN IT STOPS
#
#     gui                     the window.  Hier-View draws on tab raise;
#                             FlatView needs the "Refresh GUI" button
#     legalize_flat           what this script leaves undone
#     edit_module -module vedic_dot4        one level down
#     edit_module -module vedic_16x16       two levels down
#     edit_module -module matmul_4x4        put the top back before write_def
#
# A WARNING SPECIFIC TO THIS DESIGN'S SIZE
#
# The GUI is a forked child with its own copy of the database, and that copy is
# a couple of gigabytes here.  "gui" therefore costs real memory, and anything
# you place inside the window does not come back to this prompt -- write the
# DEF from inside the window, or from here, but know which one you are in.
#
# Drawing 204,816 rectangles is also not instant.  Expect the FlatView refresh
# to take a while; the Hier-View is cheap by comparison, since at the top it is
# sixteen boxes and 1057 pins.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/matmul/matmul.f -top matmul_4x4 -out synth --read
report_design

#-----------------------------------------------------------------------------
# Floorplan.  set_floorplan rather than edit_module -util, so that
# legalize_flat has the ROWs it needs when you type it at the prompt.
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place the whole tree, top down
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design

#-----------------------------------------------------------------------------
# A DEF of the unlegalised placement, so there is a before to go back to after
# you legalise at the prompt.
#-----------------------------------------------------------------------------
write_def -output matmul_4x4.recurse_interactive.def --overwrite

#-----------------------------------------------------------------------------
# No exit.  The prompt is the point.
#-----------------------------------------------------------------------------
