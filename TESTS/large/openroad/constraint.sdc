# One clock for the whole array.  mac_pe registers every path and the vedic
# multiplier registers its operands and product, so the longest path is one
# 16x16 multiply.  10ns is loose on purpose: the comparison is about placement,
# and a tight clock would make ORFS spend its time repairing timing, which
# electron does not do at all.
create_clock -name clk -period 10.0 [get_ports clk]
set_input_delay  1.0 -clock clk [delete_from_list [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]
