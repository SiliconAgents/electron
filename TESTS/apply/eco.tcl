# nangate_photon_repeat: apply Photon's placed repeater ECO, then check
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def vedic_16x16.legal.def --floorplan --components
apply_eco -eco sta/vedic_16x16.prep.eco.tsv
# nothing should need to move: the buffers came placed in free space
legalize_flat --incremental --report_only
write_def -output vedic_16x16.eco.def --overwrite
write_sgraph -output vedic_16x16.eco.sgraph
exit
