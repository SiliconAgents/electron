# The 4x4 matrix multiply, placed hierarchically and left at the prompt.
#
#   cd TESTS/large && make matmul_hier-interactive
#
# matmul_hier.tcl followed by improve_congestion, with the exit taken off, so
# when it stops the placed, legalised and wirelength-optimised design --
# 204,816 instances of it -- is still in memory.
#
# Three DEFs are written on the way, one per stage, so any two can be compared:
#
#     matmul_4x4.recurse_interactive.def    after hier_place_all, unlegalised
#     matmul_4x4.legal_interactive.def      after legalize_flat
#     matmul_4x4.improved_interactive.def   after improve_congestion
#
# Their own names, not matmul_hier's, so this run does not overwrite the DEFs
# of the batch one.
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
#     improve_congestion      another round; each one gains less than the
#                             last, and it says how much
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
# Floorplan.  set_floorplan rather than edit_module -util, because
# legalize_flat needs the ROWs only set_floorplan creates.
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
# A DEF of the unlegalised placement, the before for both steps below.
#-----------------------------------------------------------------------------
write_def -output matmul_4x4.recurse_interactive.def --overwrite

#-----------------------------------------------------------------------------
# Legalize.  The first point at which the placement is legal: nothing in the
# hierarchical path snaps a cell to a row.  The internal legalizer, as in
# matmul_hier.tcl, so the two runs stay comparable.
#-----------------------------------------------------------------------------
legalize_flat
write_def -output matmul_4x4.legal_interactive.def --overwrite

#-----------------------------------------------------------------------------
# Wirelength driven detailed placement on the legal result.  It refuses a
# placement that is not legal, so it has to come after legalize_flat, and
# every move it makes is legal to legal: overlaps stay at zero.
#
# It gains most on a hierarchical placement.  hier_place puts each block in
# its box but does not order the blocks into the mesh, and this recovers much
# of that: on mxu_256 it took HPWL down 48%, in 5m39.
#-----------------------------------------------------------------------------
improve_congestion
write_def -output matmul_4x4.improved_interactive.def --overwrite

#-----------------------------------------------------------------------------
# No exit.  The prompt is the point.
#-----------------------------------------------------------------------------
