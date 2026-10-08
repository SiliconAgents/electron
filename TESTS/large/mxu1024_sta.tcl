# Static timing on the 32x32 systolic matrix unit, through OpenSTA.
#
#   cd TESTS/large && make mxu_1024_sta
#
# Reads the netlist "make mxu_1024" left in workarea/synth1024/ and writes a
# timing report.  Nothing comes back into electron: report_sta writes the
# OpenSTA script, runs it, and leaves the report for whatever wants to read
# it.
#
# WHAT IT IS FOR
#
# The biggest netlist here -- 2,758,656 mapped cells, 155,648 flops -- against
# a real NLDM delay model, which is the first time any number in this flow has
# been a delay rather than a placeholder.  The Perl timer in TE/make_rw_hta
# charges a fixed 2500 per arc; this does not.
#
# It is also the scale test for the timer itself.  OpenSTA is single threaded,
# so the question this answers is what a 2.7M cell design costs it, which is
# what decides whether a per-module or partitioned approach is needed above
# this size.
#
# WHAT THE NUMBERS ARE NOT
#
# -period 10 is a round number, not a target anybody chose, so the slack is
# arbitrary by exactly that much.  What is not arbitrary is the path
# structure: which endpoints are worst, how deep they are, and what the
# arrival is.  Those are the numbers worth reading.
#
# There is no SPEF either, so net delay is wire load only and every number is
# optimistic.  On this design -- 3.95mm2 of cell area -- that is a large
# effect, and report_sta says so on every run.

#-----------------------------------------------------------------------------
# Library and liberty.  The same corner the placement runs use, and the NLDM
# one: OpenSTA does not parse CCS/LVF any more than yosys does.
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# The report.  -period with no -sdc puts one clock on every register clock pin
# and zero IO delay against it; see report_sta -h for why that is a smoke test
# and not constraints.
#-----------------------------------------------------------------------------
# One line: the command parser splits on the newline, so a trailing backslash
# ends the command rather than continuing it.
report_sta -netlist synth1024/mxu_1024.vg -top mxu_1024 -period 10.0 -paths 20 -out mxu_1024.sta.rpt

exit
