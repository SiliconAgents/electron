read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
hier_synthesis -liberty ../library/NangateOpenCellLibrary_PDKv1_2_v2008_10_slow_conditional_ecsm.lib -rtl ../undefined_mod/top.f -top unknown_top -out hs_strict -jobs 1 -abc_delay 2000 -netlist strict.vg.gz
exit
