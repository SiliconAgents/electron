# nangate_buftree: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set
hier_synthesis -rtl ../../rtls/buftree/buftree.f -top bt_top -out hs -netlist bt_hier.v -flatten_below 0 --read
repair_drive -vts any -margin 0.1 -table ../../library/nangate.sizing.tsv -report repair.rpt
report_design
write_verilog -output bt_repaired.v --hier --overwrite
exit
