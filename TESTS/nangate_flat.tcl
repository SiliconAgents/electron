# Flat place and route on Nangate45, self contained.
#
#   cd TESTS && make nangate_flat
#
# Everything this needs is in the repository: the netlist is
# rtls/vedic/vedic.vg, already mapped to Nangate cells, and the LEF is
# library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef.  No PDK, no synthesis,
# no network.  That is the point -- the scripts that used to sit beside this
# one (awgn.tcl, vedic.tcl, demo1.pl) all reached for an XFAB tree under /ef
# or /home/ubuntu that has not existed for years, so none of them ran; they
# have been removed.
#
# Runs from TESTS/workarea, which the Makefile creates.  It also does the
# egrep that produces vedic_filter.vg: vedic.vg is raw yosys output and
# carries 103 (* src = ... *) attributes, which read_verilog cannot parse --
# it fails with "ERROR-PAR-VERI : 017 : something is wrong with the verilog
# file" and elaborates nothing.
#
# The design is 3617 instances over 4073 nets, and includes 15 assign
# statements, so it exercises the assign-buffer path as well as placement and
# routing.

read_lef -lef ../library/NangateOpenCellLibrary_PDKv1_2_v2008_10.lef -tech also

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
