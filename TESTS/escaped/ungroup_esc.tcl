# nangate_ungroup_escaped: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v ../../escaped/ungroup_esc.v
set TOP_MODULE top
elaborate
ungroup -module top -cell child
write_verilog -output ug_assign.v --hier --overwrite
set_write_assign_as_buffer
write_verilog -output ug_buf.v --hier --overwrite
exit
