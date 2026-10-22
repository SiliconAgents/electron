# nangate_photon_repeat: the legal placement's graph with its physical section
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def vedic_16x16.legal.def --floorplan --components
write_sgraph -output vedic_16x16.phys.sgraph
exit
