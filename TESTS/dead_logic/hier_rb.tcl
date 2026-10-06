# nangate_dead_logic, hier read back: the written hierarchy, flattened again
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v htop.hier.v
set TOP_MODULE htop
elaborate
report_design
exit
