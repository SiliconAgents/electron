# nangate_dead_logic, ties: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
set_tie_cells -tie_high LOGIC1_X1 -tie_low LOGIC0_X1
read_verilog -v ../../rtls/dead_logic/dead_logic.v
set TOP_MODULE dl_ties
elaborate
remove_dead_logic -const -liberty ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib -report removed.txt
check_dead_logic
write_verilog -output dl_ties.flat.v --flat --overwrite
check_const_logic -liberty ../../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib -reset_only
exit
