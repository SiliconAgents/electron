# RTL filelist for the electron synthesize command.
#
# A 4x4 matrix multiply built out of the vedic multiplier that the other tests
# use: 16 dot product units, four vedic_16x16 each, 64 multipliers in all.
#
# Paths are relative to THIS file, which is how dbfSynthExpandFileList
# resolves them, so the list works from any directory.
#
# The multiplier sources are not copied here.  They are the same files
# TESTS/rtls/vedic/vedic.f reads, and a second copy would be a second thing to
# keep in step -- the kind of divergence that has the two tests silently
# placing different designs.

# The vedic multiplier, bottom up, exactly as vedic.f lists it
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

# The two levels this directory adds
vedic_dot4.v
matmul_4x4.v
