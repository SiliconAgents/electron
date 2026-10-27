# nangate_jobs: hier_place_all -jobs, against the same walk one module at a
# time.  The Makefile runs this twice, in two sessions, with JOBS replaced by
# 1 and by 4 and the Perl hash seed pinned; the two DEFs must place every
# instance and pin in the same place.  Two lane modules sharing a vedic_8x8,
# split by --unshare, so every subtree can go to a worker.
#
#   cd TESTS && make nangate_jobs
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
read_verilog -v ../unshare_lanes.v
set TOP_MODULE two_lanes
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget --legalize_blocks --unshare -jobs JOBS
write_def -output jobsJOBS.def --overwrite
legalize_flat
exit
