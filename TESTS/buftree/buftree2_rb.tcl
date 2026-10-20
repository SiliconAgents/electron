# nangate_buftree_mixed read-back: the repaired netlist, read again, needs no repair
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v bt2_repaired.v
set TOP_MODULE bt2_top
elaborate
repair_drive -vts any -margin 0.1 -table ../../library/nangate.sizing.tsv -dry_run
exit
