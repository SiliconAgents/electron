# nangate_rowstart, part 2: the legal placement with every two-row cell moved
# up one row, onto rows of the wrong orientation.  --incremental has to move
# exactly those, and a report-only pass after it has to find nothing.
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_lef -lef ../rowstart/tall.lef
read_verilog -v ../rowstart/rowstart.v
set TOP_MODULE rowstart
elaborate
read_def -def rowstart.wrong.def --floorplan --components
legalize_flat --incremental -row_start tallStartN=N,tallStartFS=FS
legalize_flat --incremental --report_only -row_start tallStartN=N,tallStartFS=FS
write_def -output rowstart.inc.def --overwrite
exit
