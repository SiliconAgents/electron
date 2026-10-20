# nangate_mpn read-back: the netlist with its port assigns made buffers, read
# again: the same instances, nothing over its limit
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v al_mpn.v
set TOP_MODULE al_top
elaborate
report_design
repair_drive -vts any -table ../../library/nangate.sizing.tsv -dry_run
exit
