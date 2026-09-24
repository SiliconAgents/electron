# Synthesis only: the 4x4 matrix multiply from RTL to a mapped netlist.
#
#   cd TESTS/large && make matmul_synth
#
# The cheap half of matmul_hier.tcl, about a minute, and the quickest way to
# check that the RTL, the filelist and the liberty still hold together without
# paying for placement.  Useful on its own when the question is whether yosys
# still produces what electron can read.
#
# WHAT TO LOOK AT IN THE OUTPUT
#
# The flop count.  4640 DFF_X2 is the number that says the hierarchy came
# through intact: 64 vedic_16x16 at 64 flops each is 4096, plus 16 vedic_dot4
# at 34 each is 544.  Anything else means yosys optimised across a boundary,
# or flattened, or dropped a module -- and a flattened netlist has nothing in
# it for the hierarchical placer to work on.
#
# The instance count from report_design is larger than the cell count yosys
# reports, and that is expected: yosys counts mapped cells, report_design
# counts what elaborate built, which includes the assign buffers.

#-----------------------------------------------------------------------------
# Library and liberty
#-----------------------------------------------------------------------------
read_config_file -config ../../../CONFIG/library.config -foundary nangate -technode 45nm -layer 6
get_std_cell_libs --first --set

#-----------------------------------------------------------------------------
# Synthesis.
#
# --read reads the filtered netlist back and elaborates it, so the database is
# populated and report_design has something to count.  The filter is not
# optional: yosys writes (* src = ... *) attributes that read_verilog cannot
# parse, and synthesize strips them.
#-----------------------------------------------------------------------------
synthesize -rtl ../rtls/matmul/matmul.f -top matmul_4x4 -out synth --read
report_design

exit
