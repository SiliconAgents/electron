# nangate_recurse with the analytic cell pass: the same vedic_16x16, the same
# hier_place_all walk, but each module's cells are placed by
# 3RDBIN/hier_place_qp (-cells_placer qp), the flops move with them
# (--free_flops), and identical sibling blocks are laid out on a grid
# (-args --array,4).  See nangate_recurse.tcl for the walk itself.
#
#   cd TESTS && make nangate_recurse_qp
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4
report_design
write_def -output vedic_16x16.qp.def --overwrite
legalize_flat
write_def -output vedic_16x16.qp.legal.def --overwrite
exit
