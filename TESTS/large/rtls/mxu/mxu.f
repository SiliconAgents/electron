# RTL filelist for the electron synthesize command.
#
# A systolic matrix unit built from the same vedic multiplier the rest of TESTS
# uses.  ONE filelist, TWO tops:
#
#     synthesize -top mxu_tile64    8x8 array,    64 multipliers
#     synthesize -top mxu_256      16x16 array,  256 multipliers
#
# Both tops are in here and yosys's "hierarchy -check -top" keeps only what the
# chosen one reaches, so the small and the large design are literally the same
# sources.  Nothing is duplicated and the two cannot drift apart.
#
# Paths are relative to THIS file, which is how dbfSynthExpandFileList resolves
# them.  The multiplier sources are referenced where they live rather than
# copied: a second copy is a second thing to keep in step.

# The vedic multiplier, bottom up, as TESTS/rtls/vedic/vedic.f lists it
../../../rtls/vedic/vedicMultiplier/halfAdder.v
../../../rtls/vedic/vedicMultiplier/adder4.v
../../../rtls/vedic/vedicMultiplier/adder6.v
../../../rtls/vedic/vedicMultiplier/adder8.v
../../../rtls/vedic/vedicMultiplier/adder12.v
../../../rtls/vedic/vedicMultiplier/adder16.v
../../../rtls/vedic/vedicMultiplier/adder24.v
../../../rtls/vedic/vedicMultiplier/vedic_2x2.v
../../../rtls/vedic/vedicMultiplier/vedic_4x4.v
../../../rtls/vedic/vedicMultiplier/vedic_8x8.v
../../../rtls/vedic/vedicMultiplier/vedic_16x16.v

# The systolic array, bottom up
mac_pe.v
mxu_tile16.v
mxu_tile64.v
mxu_256.v
