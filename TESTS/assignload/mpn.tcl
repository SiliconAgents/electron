# nangate_mpn: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set
hier_synthesis -rtl ../../rtls/assignload/assignload.f -top al_top -out hs -netlist al_hier.v -flatten_below 0 --read
report_design
fix_multiple_port_nets -report mpn.rpt
report_design
repair_drive -vts any -table ../../library/nangate.sizing.tsv -report repair.rpt
write_verilog -output al_mpn.v --hier --overwrite
exit
