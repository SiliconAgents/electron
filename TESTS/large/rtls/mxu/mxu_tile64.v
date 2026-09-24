`timescale 1ns/1ps

// mxu_tile64 -- an 8x8 systolic array, four mxu_tile16 abutted 2x2.
//
//          w_in / psum_in
//            |        |
//   a_in -  T00  ->  T01  - a_out        each T is 4x4 PEs
//            v        v
//   a_in -  T10  ->  T11  - a_out
//            |        |
//          w_out / psum_out
//
// This is also a top in its own right: "make mxu_64" synthesises THIS module,
// which gives a 64 multiplier design out of the same sources as the 256
// multiplier one.  Two sizes, one filelist, nothing duplicated -- synthesize
// -top picks which.
//
// Rows of the composed array are still packed contiguously, so each child
// takes a whole slice of each bus and the wiring is twelve assignments.

module mxu_tile64(clk, a_in, w_in, psum_in, a_out, w_out, psum_out);
    input clk;
    input  [127:0]  a_in;
    input  [127:0]  w_in;
    input  [319:0] psum_in;
    output [127:0]  a_out;
    output [127:0]  w_out;
    output [319:0] psum_out;

    // one set of edge buses per child tile
    wire [ 63:0] ta_0_0;  wire [ 63:0] tw_0_0;  wire [159:0] ts_0_0;
    wire [ 63:0] ta_0_1;  wire [ 63:0] tw_0_1;  wire [159:0] ts_0_1;
    wire [ 63:0] ta_1_0;  wire [ 63:0] tw_1_0;  wire [159:0] ts_1_0;
    wire [ 63:0] ta_1_1;  wire [ 63:0] tw_1_1;  wire [159:0] ts_1_1;

    // 2x2 of mxu_tile16: a rightwards, w and psum downwards
    mxu_tile16 T00(clk, a_in[  63:   0]     , w_in[  63:   0]     , psum_in[ 159:   0]    ,
                        ta_0_0, tw_0_0, ts_0_0);
    mxu_tile16 T01(clk, ta_0_0              , w_in[ 127:  64]     , psum_in[ 319: 160]    ,
                        ta_0_1, tw_0_1, ts_0_1);
    mxu_tile16 T10(clk, a_in[ 127:  64]     , tw_0_0              , ts_0_0                ,
                        ta_1_0, tw_1_0, ts_1_0);
    mxu_tile16 T11(clk, ta_1_0              , tw_0_1              , ts_0_1                ,
                        ta_1_1, tw_1_1, ts_1_1);

    // outer edges: rightmost column of tiles, bottom row of tiles
    assign a_out[  63:   0]    = ta_0_1;
    assign a_out[ 127:  64]    = ta_1_1;
    assign w_out[  63:   0]    = tw_1_0;
    assign w_out[ 127:  64]    = tw_1_1;
    assign psum_out[ 159:   0] = ts_1_0;
    assign psum_out[ 319: 160] = ts_1_1;

endmodule
