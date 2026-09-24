# Recursive hierarchical placement, left running so the result can be poked at.
#
#   cd TESTS && make nangate_recurse-interactive
#
# Same flow as nangate_recurse.tcl -- hier_place_all over the whole vedic_16x16
# tree -- with two differences: it does not legalize, and it does not exit.
# When the run finishes you get the electron prompt with the placed design in
# memory.
#
# WHY THERE IS NO "exit" AND WHY THE TARGET STILL PASSES --nogui
#
# Those two are the same decision.  The wrapper's startup is:
#
#     if   ( $dbInitFile )        { &source($INIT_FILE); }   # this file
#     ...
#     elsif ( $WINSTART == 1 )    { &win; &exit; }           # no --nogui
#     ...
#     print "$PROMPT > ";  while (<STDIN>) { ... }           # --nogui
#
# so the -f script always runs FIRST, and what happens afterwards depends on
# --nogui:
#
#   without --nogui   the wrapper forks the GUI and the parent exits.  A
#                     window, and no prompt behind it.
#   with --nogui      the wrapper falls through to the STDIN loop.  A prompt,
#                     and no window -- until you ask for one.
#
# The prompt is the more useful end state, because from it you can still get
# the window by typing
#
#     gui
#
# which runs the same &win.  That forks the GUI as a child and the prompt
# stays, so you end up with both.  The other way round you cannot get back.
#
# Two things follow from the script running before the GUI exists:
#
#   - "exit" here would kill the tool before anything interactive happens.
#     That is why the other -gui target has to have its exit commented out.
#
#   - a display command here cannot work.  design_display reaches for the Tk
#     main window and dies with "Can't call method title on an undefined
#     value", and since the exit banner comes from an END block that death
#     reads as a clean exit.  Nothing is drawn from this file.
#
# THINGS WORTH TYPING WHEN IT STOPS
#
# Open the window:
#
#     gui
#
# Two views, two tabs, two different databases:
#
#   Hier-View    the PSEUDO database of the module being edited: blocks as
#                boxes, hierarchical pins on the boundary.  This is the view
#                hier_place works in.  Raising the tab draws it, and it comes
#                up on the top: seven blocks -- four vedic_8x8, two adder24,
#                one adder16 -- and 64 ports.
#
#   FlatView     the FLAT database: %CADB, one rectangle per leaf cell, all
#                4233 of them.  Raising this tab only focuses the canvas; it
#                does NOT draw.  Press "Refresh GUI" on the right hand
#                toolbar, or Display from the menu.
#
# They are not two renderings of one thing.  The Hier-View is what the placer
# decided, the FlatView is what that means for the cells, and the only thing
# between them is hier2flat, which hier_place_all has already run.
#
# Legalize and see what it costs:
#
#     legalize_flat
#
# then refresh.  Average move is about 11um, so the per module clusters blur.
# Worth seeing next to the unlegalized picture, which is why this script
# leaves it undone -- and vedic_16x16.recurse_interactive.def is written
# before you legalize, so there is a before to go back to.
#
# Look inside a block:
#
#     edit_module -module vedic_8x8
#
# then refresh the Hier-View.  That module was placed by this run, so its four
# vedic_4x4, its adders and its ports are where hier_place_all put them.
#
# Mind what edit_module does on the way back.  It moves TOP_MODULE, and
# write_def means TOP_MODULE by "the design": descend, then write a DEF, and
# you get vedic_8x8 -- block-sized die, no pins, every component of the real
# design outside the boundary.  Put it back before writing anything:
#
#     edit_module -module vedic_16x16
#
# And to leave:
#
#     exit

#-----------------------------------------------------------------------------
# Library and netlist
#-----------------------------------------------------------------------------
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design

#-----------------------------------------------------------------------------
# Floorplan.
#
# set_floorplan rather than edit_module -util, because legalize_flat is one of
# the things to try at the prompt and it needs the ROWs only set_floorplan
# creates.  Without them it stops with "vedic_16x16 has no ROWs".
#-----------------------------------------------------------------------------
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#-----------------------------------------------------------------------------
# Place the whole tree: eleven modules, five levels, top down.
#
# -batch is not optional.  hier_place is a PyQt5 window of its own, nothing to
# do with the Tk one, and without -batch each of the eleven modules would open
# it and wait for someone to press Save & Close.
#-----------------------------------------------------------------------------
edit_module --top
hier_place_all -batch 300 -cells_batch 300

report_design

#-----------------------------------------------------------------------------
# A DEF of the unlegalized hierarchical placement, so the run leaves something
# behind that outlives the session -- and so there is a before to compare with
# after you legalize at the prompt.
#-----------------------------------------------------------------------------
write_def -output vedic_16x16.recurse_interactive.def --overwrite

#-----------------------------------------------------------------------------
# No exit.  The prompt is the point.
#-----------------------------------------------------------------------------
