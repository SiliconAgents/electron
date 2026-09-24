`timescale 1ns/1ps

// mxu_256 -- a 16x16 systolic matrix unit, 256 multipliers.
//
// Four mxu_tile64 abutted 2x2, so 16 rows by 16 columns of mac_pe, each with
// its own vedic_16x16.  The shape an AI engine's matrix unit actually has: a
// TPU MXU is this with 256 rows instead of 16, and the only difference that
// makes to the hierarchy is one more level of the same composition.
//
//          w_in / psum_in
//            |        |
//   a_in -  T00  ->  T01  - a_out        each T is 8x8 PEs
//            v        v
//   a_in -  T10  ->  T11  - a_out
//            |        |
//          w_out / psum_out
//
// THE HIERARCHY, WHICH IS THE POINT
//
//     mxu_256        4 x mxu_tile64
//       mxu_tile64   4 x mxu_tile16
//         mxu_tile16 16 x mac_pe
//           mac_pe   1 x vedic_16x16 + 88 flops
//             vedic_16x16 ... down to halfAdder
//
// Nine levels and fifteen distinct modules, and fifteen is what
// hier_place_all walks.  256 copies of vedic_16x16 share one floorplan, all
// four mxu_tile64 share one, all sixteen mxu_tile16 share one -- so the
// placement cost of this design is barely above the 64 multiplier one, while
// everything on the flat side is four times bigger.  That gap is what makes
// it worth having both.
//
// It is also the right shape for a systolic array to be placed as: identical
// blocks, nearest neighbour connections only, no broadcast.  If hier_place
// cannot make a tidy mesh out of four identical blocks with edge connections,
// it cannot do anything.

module mxu_256(clk, a_in, w_in, psum_in, a_out, w_out, psum_out);
    input clk;
    input  [255:0]  a_in;
    input  [255:0]  w_in;
    input  [639:0] psum_in;
    output [255:0]  a_out;
    output [255:0]  w_out;
    output [639:0] psum_out;

    // one set of edge buses per child tile
    wire [127:0] ta_0_0;  wire [127:0] tw_0_0;  wire [319:0] ts_0_0;
    wire [127:0] ta_0_1;  wire [127:0] tw_0_1;  wire [319:0] ts_0_1;
    wire [127:0] ta_1_0;  wire [127:0] tw_1_0;  wire [319:0] ts_1_0;
    wire [127:0] ta_1_1;  wire [127:0] tw_1_1;  wire [319:0] ts_1_1;

    // 2x2 of mxu_tile64: a rightwards, w and psum downwards
    mxu_tile64 T00(clk, a_in[ 127:   0]     , w_in[ 127:   0]     , psum_in[ 319:   0]    ,
                        ta_0_0, tw_0_0, ts_0_0);
    mxu_tile64 T01(clk, ta_0_0              , w_in[ 255: 128]     , psum_in[ 639: 320]    ,
                        ta_0_1, tw_0_1, ts_0_1);
    mxu_tile64 T10(clk, a_in[ 255: 128]     , tw_0_0              , ts_0_0                ,
                        ta_1_0, tw_1_0, ts_1_0);
    mxu_tile64 T11(clk, ta_1_0              , tw_0_1              , ts_0_1                ,
                        ta_1_1, tw_1_1, ts_1_1);

    // outer edges: rightmost column of tiles, bottom row of tiles
    assign a_out[ 127:   0]    = ta_0_1;
    assign a_out[ 255: 128]    = ta_1_1;
    assign w_out[ 127:   0]    = tw_1_0;
    assign w_out[ 255: 128]    = tw_1_1;
    assign psum_out[ 319:   0] = ts_1_0;
    assign psum_out[ 639: 320] = ts_1_1;

endmodule
