# nangate_l_die: nangate_fixed_fp's legalized placement read back from a DEF whose DIEAREA is the
# die with its notch cut out -- eight corners -- and forty cells moved into the notch.  read_def
# has to make the notch a placement blockage by itself (INFO-PAR-DEF 044), a flow's own
# set_placement_blockage for the same notch must not add it twice (ST_PL_BLK 007), and
# legalize_flat has to move the forty out of it.
#
#   cd TESTS && make nangate_l_die      (after nangate_fixed_fp)
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
read_lef -lef ../fixed_fp/testram.lef
read_verilog -v vedic_fixed.vg
set TOP_MODULE vedic_16x16
elaborate
read_def -def l_die.def --floorplan --components
set_placement_blockage -rect 98 47 110 63
set_placement_blockage --report
set_macro_halo -sites 4 -rows 1
legalize_flat --incremental
write_def -output l_die.legal.def --overwrite
exit
