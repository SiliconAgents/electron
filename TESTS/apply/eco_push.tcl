# nangate_photon_repeat_push: apply Photon's ECO sized with neighbours pushed aside;
# Photon kept the rows legal, so legalize_flat must find nothing to move
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def vedic_16x16.legal.def --floorplan --components
apply_eco -eco sta/vedic_16x16.push.eco.tsv

legalize_flat --incremental --report_only
write_def -output vedic_16x16.push.def --overwrite
exit
