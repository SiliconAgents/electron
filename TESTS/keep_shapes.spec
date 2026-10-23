# nangate_keep_shapes: hier_place_all puts vedic_16x16's three adders in a
# column on the left and its four 8x8 multipliers in a 2x2 grid beside them.
# This is that arrangement mirrored -- the grid on the left with its columns
# swapped, the adders on the right with the top's own logic among them -- so
# every block has to move, and it fits the shapes the blocks already have.
vedic_16x16 : H( V( H( V11 V12 ) H( V10 V9 ) )  V( A3 A5 * A4 ) )
