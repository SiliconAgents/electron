# RTL filelist for the electron synthesize command.
#
# This is the registered vedic multiplier: vedic_16x16 clocks its two inputs
# into a_reg and b_reg and its product into result, so the design has 64 flops
# (16 + 16 + 32) and everything below the top is combinational.
#
# Paths are relative to this file, so the list works from anywhere.
vedicMultiplier/halfAdder.v
vedicMultiplier/adder4.v
vedicMultiplier/adder6.v
vedicMultiplier/adder8.v
vedicMultiplier/adder12.v
vedicMultiplier/adder16.v
vedicMultiplier/adder24.v
vedicMultiplier/vedic_2x2.v
vedicMultiplier/vedic_4x4.v
vedicMultiplier/vedic_8x8.v
vedicMultiplier/vedic_16x16.v
