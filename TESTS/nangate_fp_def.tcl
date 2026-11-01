# nangate_fp_def: vedic_16x16 placed inside another tool's floorplan DEF (read_floorplan_def).
# The DEF is nangate_fixed_fp's legalized placement made to look like one: an L-shaped DIEAREA,
# rows that start FS under a second site's decoy rows, the two macros FIXED (one inside a block,
# w1/ram1, so it has to be dissolved into the top to be held), and forty FIXED physical-only
# cells (FILLCELL_X1, standing in for well taps), five of them also unconnected cells of the netlist.
#
#   cd TESTS && make nangate_fp_def      (after nangate_fixed_fp)
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_lef -lef ../fixed_fp/testram.lef
read_verilog -v vedic_fpdef.vg
set TOP_MODULE vedic_16x16
elaborate
read_floorplan_def -def fp_in.def -write_nodes fp_def.nodes
edit_module --top
read_pseudo_nodefile -module vedic_16x16 -input fp_def.nodes
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 -sizing budget -mixed_whitespace 20 -block_targets ../legalize_blocks.targets
edit_module -module vedic_16x16
read_floorplan_def -def fp_in.def --physical_cells
delete_physical_cells --report
set_macro_halo -sites 4 -rows 1
legalize_flat
write_def -output fp_def.legal.def --overwrite
delete_physical_cells -ref FILLCELL*
write_def -output fp_def.notaps.def --overwrite
exit
