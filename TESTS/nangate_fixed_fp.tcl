# nangate_fixed_fp: vedic_16x16 in a floorplan given rather than made -- two hard macros and three
# pins held where fixed_fp/fixed_fp.nodes puts them (one macro mirrored), a corner of the die
# blocked mid-right (set_placement_blockage, as an L-shaped die's notch is), the blocks laid out around them
# toward nangate_legalize_blocks's targets.
#
#   cd TESTS && make nangate_fixed_fp
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_lef -lef ../fixed_fp/testram.lef
read_verilog -v vedic_fixed.vg
set TOP_MODULE vedic_16x16
elaborate
set_floorplan_parameters -WIDTH 110 -HEIGHT 110
set_floorplan
set_placement_blockage -rect 98 47 110 63
edit_module --top
read_pseudo_nodefile -module vedic_16x16 -input ../fixed_fp/fixed_fp.nodes
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget -mixed_whitespace 20 -block_targets ../legalize_blocks.targets
edit_module -module vedic_16x16
write_def -output ff.def --overwrite
set_macro_halo -sites 4 -rows 1
legalize_flat
write_def -output ff.legal.def --overwrite
write_sgraph -output ff.sgraph
exit
