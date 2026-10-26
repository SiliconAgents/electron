# nangate_aldff, part 1: hier_synthesis on aldff.sv -- the async-load flops
# must become set/clear flops and the netlist must read back whole
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
hier_synthesis -liberty ../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib -rtl ../aldff/aldff.f -top aldff -out hs_aldff -jobs 1 -abc_delay 2000 -netlist aldff.vg.gz --read
report_design
exit
