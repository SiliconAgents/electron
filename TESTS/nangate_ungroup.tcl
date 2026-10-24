# Dissolving child instances into their parent for placement.  vedic_16x16
# is placed all the way down, then the two adder12 instances (A4, A5) of
# vedic_8x8 -- four copies of it -- are ungrouped and vedic_8x8 alone is
# placed again with their cells as its own.  ug0 is before, ug1 after (rigid
# hier2flat), ug2 the same through a full hier2flat; the timing graphs before
# and after must hold the same connections: only the grouping changed.
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget --slice_blocks
write_def -output ug0.def --overwrite
write_sgraph -output ug0.sgraph
ungroup -module vedic_8x8 -cell adder12
hier_place_all -only vedic_8x8 --keep_shapes -sizing budget --slice_blocks -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -floorplan_spec ../ungroup.spec
write_moves -output ug1.moves
write_def -output ug1.def --overwrite
write_sgraph -output ug1.sgraph
hier2flat --physical
write_def -output ug2.def --overwrite
legalize_flat
exit
