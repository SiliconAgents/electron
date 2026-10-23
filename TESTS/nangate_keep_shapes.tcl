# Re-placing only the top of a placed hierarchy, the step a fast floorplan
# loop repeats.  vedic_16x16 is placed all the way down as nangate_recurse_qp
# does, then the top alone is placed again from a floorplan spec with
# --keep_shapes: every child keeps the width x height it was placed in, so its
# cells must move with it as one piece.  ks1.def is before, ks2.def after the
# top is re-placed (both before legalising, so a rigid move is exact);
# check_rigid.py compares them.  ks4.def is vedic_8x8 re-placed with -only
# (ks5.def the same through a full hier2flat): its children move rigidly in
# all four copies and nothing outside them moves.
# ks3.def is the same placement through a full hier2flat: the rigid shift the
# re-place used must give exactly what rebuilding every location gives.
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget --slice_blocks
write_def -output ks1.def --overwrite
# the top only, its own cells included; the children keep their placement
hier_place_all -depth 0 --keep_shapes -sizing budget --slice_blocks -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -floorplan_spec ../keep_shapes.spec
write_def -output ks2.def --overwrite
hier2flat --physical
write_def -output ks3.def --overwrite
# one level down: vedic_8x8 alone, in the boxes the top gave its four copies
hier_place_all -only vedic_8x8 --keep_shapes -sizing budget --slice_blocks -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -floorplan_spec ../keep_shapes_only.spec
write_moves -output ks4.moves
write_def -output ks4.def --overwrite
hier2flat --physical
write_def -output ks5.def --overwrite
legalize_flat
exit
