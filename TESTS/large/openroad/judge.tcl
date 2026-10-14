# judge.tcl -- one OpenROAD engine scoring any placed DEF, whoever placed it.
#
#   JUDGE_LEFS="a.lef b.lef" JUDGE_DEF=placed.def JUDGE_SDC=constraint.sdc \
#   JUDGE_TAG=name JUDGE_OUT=dir  openroad -no_init -exit judge.tcl
#
# Runs inside the ORFS image.  Timing: OpenSTA on the typical Nangate45
# liberty, parasitics estimated from placement with the platform's RC.
# Routability: FastRoute with the platform's layer adjustments, allowed to
# finish congested so that overflow can be reported rather than stopping.
# Then timing again from the global routes.  Every number here comes from
# the same code whichever tool produced the DEF.
#
# Prints "JUDGE <key> <value>" lines for compare to collect.

set plat /OpenROAD-flow-scripts/flow/platforms/nangate45
set tag  $::env(JUDGE_TAG)
set out  $::env(JUDGE_OUT)
set_thread_count [exec nproc]

foreach l $::env(JUDGE_LEFS) { read_lef $l }
read_liberty $plat/lib/NangateOpenCellLibrary_typical.lib
read_def $::env(JUDGE_DEF)
read_sdc $::env(JUDGE_SDC)
source $plat/setRC.tcl

# The same tracks for every DEF: the platform's own.  Electron writes one
# direction per layer, which FastRoute rejects ("Missing track structure");
# ORFS writes both.  Pitches and offsets agree, so replacing them is neutral.
set ntg [llength [[ord::get_db_block] getTrackGrids]]
foreach tg [[ord::get_db_block] getTrackGrids] { odb::dbTrackGrid_destroy $tg }
source $plat/make_tracks.tcl
puts "JUDGE tracks platform (replaced $ntg from the DEF)"

# Electron's MXU flow leaves its ports illegal for a router -- all on metal1,
# stacked several to a spot, most sticking out of the die -- and FastRoute
# stops with GRT-0080.  JUDGE_PLACE_PINS=1 re-places them with OpenROAD's own
# pin placer on the platform's IO layers, the same placer ORFS's run used, so
# that routing can be judged at all.  It is applied before timing too, so both
# stages see the same pins.
if { [info exists ::env(JUDGE_PLACE_PINS)] && $::env(JUDGE_PLACE_PINS) } {
  place_pins -hor_layers metal3 -ver_layers metal2
  puts "JUDGE pins replaced_by_place_pins"
} else {
  puts "JUDGE pins as_in_def"
}

proc judge_timing { stage } {
  set wns [sta::worst_slack -max]
  set tns [sta::total_negative_slack -max]
  puts "JUDGE ${stage}_worst_slack_ns [format %.4f $wns]"
  puts "JUDGE ${stage}_tns_ns [format %.3f $tns]"
  report_checks -path_delay max -fields {slew cap fanout} -digits 3 > $::out/$::tag.$stage.path.rpt
}

estimate_parasitics -placement
judge_timing placement

set ::env(MIN_ROUTING_LAYER) metal2
set ::env(MIN_CLK_ROUTING_LAYER) metal2
set ::env(MAX_ROUTING_LAYER) metal10
source $plat/fastroute.tcl

set t0 [clock milliseconds]
global_route -allow_congestion -verbose -congestion_report_file $out/$tag.congestion.rpt
puts "JUDGE grt_seconds [expr ([clock milliseconds] - $t0) / 1000.0]"

estimate_parasitics -global_routing
judge_timing global_route
puts "JUDGE done 1"
