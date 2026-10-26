# nangate_rowstart, part 1: place and legalize a chain of buffers in which
# every fifth one is two rows tall, on one of two sites.  -row_start says
# which row orientation each site's cells must start on; check_rowstart.py
# checks the result without electron.
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_lef -lef ../rowstart/tall.lef
read_verilog -v ../rowstart/rowstart.v
set TOP_MODULE rowstart
elaborate
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan
place_flat_design
legalize_flat -row_start tallStartN=N,tallStartFS=FS
write_def -output rowstart.legal.def --overwrite
exit
