# nangate_legalize_blocks: vedic_16x16 placed with every module's child blocks
# laid out by --legalize_blocks (3RDBIN/block_legalize) instead of slicing --
# reshaped, no overlap, as near the block pass's positions as fits -- and the
# top laid out toward -block_targets that ask for an arrangement no slicing can
# make: adder A3 in the middle, the four 8x8 multipliers around it.
#
#   cd TESTS && make nangate_legalize_blocks
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget -block_targets ../legalize_blocks.targets
write_def -output lb.def --overwrite
legalize_flat
write_def -output lb.legal.def --overwrite
exit
