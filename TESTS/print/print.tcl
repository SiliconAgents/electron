# nangate_print: see TESTS/Makefile for what is checked
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set
hier_synthesis -rtl ../../rtls/print/print.f -top print_top -out hs -netlist print_hier.v
synthesize -rtl ../../rtls/print/print.f -top print_top -out flat
exit
