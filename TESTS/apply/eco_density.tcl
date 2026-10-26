# nangate_photon_repeat_density: apply Photon's ECO sized under a density cap;
# the resized cells overlap their neighbours, which legalize_flat moves
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def vedic_16x16.legal.def --floorplan --components
apply_eco -eco sta/vedic_16x16.dens.eco.tsv
legalize_flat --incremental
# and now nothing should need to move
legalize_flat --incremental --report_only
write_def -output vedic_16x16.dens.def --overwrite
exit
