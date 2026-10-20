# nangate_escaped read-back: the repaired netlist, read again, needs no repair
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v esc_repaired.v
set TOP_MODULE esc_top
elaborate
report_design
repair_drive -vts any -table ../../library/nangate.sizing.tsv -dry_run
exit
