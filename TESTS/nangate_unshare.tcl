# nangate_unshare: hier_place_all --unshare on two lane wrappers that share
# one vedic_8x8 (unshare_lanes.v).  Placed once as it is (us0) and once with
# every module under two parent modules split into a copy per parent (us1):
# the timing graphs must hold the same connections and the DEFs the same
# instances -- only module names change -- the copies are placed, and laneB's
# blocks (4% overlap with its multiplier in laneA's shape) overlap no more.
#
#   cd TESTS && make nangate_unshare
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
read_verilog -v ../unshare_lanes.v
set TOP_MODULE two_lanes
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget --legalize_blocks
write_def -output us0.def --overwrite
write_sgraph -output us0.sgraph
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget --legalize_blocks --unshare
write_def -output us1.def --overwrite
write_sgraph -output us1.sgraph
legalize_flat
exit
