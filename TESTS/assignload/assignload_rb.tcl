# nangate_assignload read-back: the repaired netlist flattened by yosys, so its
# assigns are merged into plain nets, needs no repair
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v al_flat.v
set TOP_MODULE al_top
elaborate
report_design
repair_drive -vts any -table ../../library/nangate.sizing.tsv -dry_run
exit
