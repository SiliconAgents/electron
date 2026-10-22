# nangate_apply: see TESTS/Makefile for what is checked
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
# the placement nangate_flat legalized, restored onto the elaborated netlist
read_def -def vedic_16x16.legal.def --floorplan --components
apply_advice -resize sta/vedic_16x16.advise.resize.tsv -nets sta/vedic_16x16.advise.nets.tsv -report apply.rpt
legalize_flat --incremental
write_def -output vedic_16x16.applied.def --overwrite
write_sgraph -output vedic_16x16.applied.sgraph
exit
