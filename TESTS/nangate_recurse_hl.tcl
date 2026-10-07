# nangate_recurse_qp, legalized the hierarchical way: hier_place_all --legalize
# runs legalize_module on every module before its commit, so hier2flat copies
# legal arrangements into every instance, and legalize_flat --incremental then
# keeps every cell that is already legal and repairs only the rest (here the
# tiny modules, a row or two tall, whose boxes cannot hold their own cells).
# No full flat legalization.  3RDBIN/def_check_legal judges the result.
#
#   cd TESTS && make nangate_recurse_hl
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
edit_module --top
hier_place_all -batch 300 -cells_batch 300 -cells_placer qp --free_flops -args --array,4 --legalize
report_design
write_def -output vedic_16x16.hl.def --overwrite
legalize_flat --incremental
write_def -output vedic_16x16.hl.legal.def --overwrite
exit
