# Flat place and route on Nangate45, self contained.
#
#   cd TESTS && make nangate_flat
#
# Everything this needs is in the repository: the netlist is
# rtls/vedic/vedic.vg, already mapped to Nangate cells, and the library comes
# from CONFIG/library.config.  No PDK, no synthesis, no network.  That is the
# point -- the scripts that used to sit beside this one (awgn.tcl, vedic.tcl,
# demo1.pl) all reached for a vendor tree under /ef or /home/ubuntu that has
# not existed for years, so none of them ran; they have been removed.
#
# Runs from TESTS/workarea, which the Makefile creates.  It also does the
# egrep that produces vedic_filter.vg: vedic.vg is raw yosys output and
# carries 103 (* src = ... *) attributes, which read_verilog cannot parse --
# it fails with "ERROR-PAR-VERI : 017 : something is wrong with the verilog
# file" and elaborates nothing.
#
# The design is 4233 instances over 4489 nets and exercises the assign-buffer
# path as well as placement and routing.

#-----------------------------------------------------------------------------
# Library, from the config rather than a hardcoded path.
#
# read_config_file does two things a bare read_lef does not.  It records the
# liberty paths for get_std_cell_libs without opening them, and once the
# library is loaded it chooses the assign buffer and the tie cells -- so the
# 15 assign statements in this netlist become real buffers instead of being
# dropped.  That is the whole difference between 4233 instances here and the
# 3617 a read_lef gives.
#
# The config names its files as $ELECTRON_HOME/TESTS/library/..., expanded
# when the config is parsed, so this is right in any checkout.
#-----------------------------------------------------------------------------
read_config_file -config ../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6

read_verilog -v vedic_filter.vg
set TOP_MODULE vedic_16x16
elaborate
report_design

#<!-- Utilisation rather than a fixed die.  A WIDTH/HEIGHT big enough to be
#     safe is usually so empty that routing it proves nothing. -->
set_floorplan_parameters -ASPECT_RATIO 1 -UTILIZATION 50
set_floorplan

#<!-- legalize_flat is not optional before routing.  The flat placer returns
#     continuous positions, overlapping and off the row grid; routing that
#     directly leaves roughly ten times as many nets unrouted. -->
place_flat_design
write_def -output vedic_16x16.placed.def --overwrite

legalize_flat
write_def -output vedic_16x16.legal.def --overwrite

#<!-- -lef matters.  Left to itself qroute writes a LEF from the database with
#     write_lef, and that drops the per layer OFFSET and the second PITCH
#     value, so the track grid lands in the wrong place and pins sit between
#     tracks.  Measured on a similar design, same placement: 624 failed nets
#     with the written LEF against 351 with the PDK file, and every "has no
#     taps" failure came from the written one. -->
qroute -out route -lef ../library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef

#<!-- qroute reads the routed DEF back in, so this one carries the routing -->
write_def -output vedic_16x16.routed.def --overwrite
report_design

exit
