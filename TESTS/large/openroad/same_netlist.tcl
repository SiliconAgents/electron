# same_netlist.tcl -- OpenROAD's placers on electron's exact netlist.
#
#   SAME_LEF=nangate_4000.lef SAME_DEF=unplaced.def SAME_OUT=placed.def \
#   openroad -no_init -exit same_netlist.tcl
#
# SAME_DEF is electron's placed DEF put through  prep_def.py --unplace : every
# component UNPLACED, electron's die, rows and port locations kept, so the
# two placers get the same netlist and the same boundary.  Global placement is
# wirelength-only at 0.60 density, as in config.mk; then detailed placement
# and mirroring.  No resizing and no tap cells, since electron has neither.
set_thread_count [exec nproc]
read_lef $::env(SAME_LEF)
read_def $::env(SAME_DEF)
set t0 [clock milliseconds]
global_placement -density 0.60 -pad_left 0 -pad_right 0
set t1 [clock milliseconds]
detailed_placement
optimize_mirroring
set t2 [clock milliseconds]
check_placement -verbose
puts "PHASE global_placement [expr ($t1 - $t0) / 1000.0] s"
puts "PHASE detailed_placement [expr ($t2 - $t1) / 1000.0] s"
write_def $::env(SAME_OUT)
