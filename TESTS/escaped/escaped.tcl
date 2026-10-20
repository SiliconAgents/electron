# nangate_escaped: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set
hier_synthesis -rtl ../../rtls/escaped/escaped.f -top esc_top -out hs -netlist esc_hier.v --read
set_tie_cells -tie_high LOGIC1_X1 -tie_low LOGIC0_X1
remove_dead_logic -const -hier -liberty ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib
repair_drive -vts any -table ../../library/nangate.sizing.tsv -report repair.rpt
report_design
write_verilog -output esc_repaired.v --hier --overwrite
exit
