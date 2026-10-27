# nangate_block_growth: nangate_legalize_blocks again with -block_growth
# budgeting vedic_8x8 at 1.3x its cells' area, as a plan does for a module
# whose upsizing found no room last time.  Its block must come out 1.3x as
# big as without, less what the re-solved utilization takes back.
#
#   cd TESTS && make nangate_block_growth
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget -block_targets ../legalize_blocks.targets -block_growth ../block_growth.tsv
write_def -output bg.def --overwrite
legalize_flat
exit
