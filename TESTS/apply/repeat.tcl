# nangate_repeat: see TESTS/Makefile for what is checked
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def vedic_16x16.legal.def --floorplan --components
# fanout 2 so the small nets still build trees several levels deep
apply_advice -nets repeat.nets.tsv -max_fanout 2 -report repeat.rpt
legalize_flat --incremental
write_def -output vedic_16x16.repeated.def --overwrite
write_sgraph -output vedic_16x16.repeated.sgraph
exit
