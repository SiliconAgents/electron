`timescale 1ns/1ps

// mxu_1024 -- a 32x32 systolic matrix unit, 1024 multipliers.
//
// Four mxu_256 abutted 2x2, which is four mxu_tile64 each, which is four
// mxu_tile16 each, which is sixteen mac_pe each.  Every level is the same 2x2
// composition, and that is the whole point: a systolic array scales by
// abutment and nothing else changes -- no longer wires, no broadcast, no
// retiming.  A TPU v1 MXU is this design with 256 rows instead of 32.
//
//          w_in / psum_in
//            |        |
//   a_in -  T00  ->  T01  - a_out        each T is 16x16 PEs
//            v        v
//   a_in -  T10  ->  T11  - a_out
//            |        |
//          w_out / psum_out
//
// WHY THIS SIZE EXISTS ALONGSIDE mxu_256
//
// To find out whether the flow stays linear, with nothing else changing.
//
//   design      mults  modules  instances    measured
//   mxu_tile64     64      14      213,568    1m29,  1.2G
//   mxu_256       256      15      855,424    5m23,  4.2G
//   mxu_1024     1024      16    ~3,400,000   this
//
// Each step is four times the instances and ONE more distinct module.  That
// asymmetry is the thing under test: hier_place_all walks distinct modules, so
// its cost should barely move, while hier2flat, legalize_flat and write_def
// work on every instance and should go up four times.  If mxu_1024 lands near
// four times mxu_256 the flow is linear; if it lands well above, something on
// the flat side is superlinear and this is the design that says so.
//
// It is the same sources as the smaller two -- synthesize -top picks the size
// -- so a difference between them is a difference in scale and nothing else.

module mxu_1024(clk, a_in, w_in, psum_in, a_out, w_out, psum_out);
    input clk;
    input  [511:0]  a_in;
    input  [511:0]  w_in;
    input  [1279:0] psum_in;
    output [511:0]  a_out;
    output [511:0]  w_out;
    output [1279:0] psum_out;

    // one set of edge buses per child tile
    wire [ 255:0] ta_0_0;  wire [ 255:0] tw_0_0;  wire [ 639:0] ts_0_0;
    wire [ 255:0] ta_0_1;  wire [ 255:0] tw_0_1;  wire [ 639:0] ts_0_1;
    wire [ 255:0] ta_1_0;  wire [ 255:0] tw_1_0;  wire [ 639:0] ts_1_0;
    wire [ 255:0] ta_1_1;  wire [ 255:0] tw_1_1;  wire [ 639:0] ts_1_1;

    // 2x2 of mxu_256: a rightwards, w and psum downwards
    mxu_256 T00(clk, a_in[ 255:   0]     , w_in[ 255:   0]     , psum_in[ 639:   0]    ,
                     ta_0_0, tw_0_0, ts_0_0);
    mxu_256 T01(clk, ta_0_0              , w_in[ 511: 256]     , psum_in[1279: 640]    ,
                     ta_0_1, tw_0_1, ts_0_1);
    mxu_256 T10(clk, a_in[ 511: 256]     , tw_0_0              , ts_0_0                ,
                     ta_1_0, tw_1_0, ts_1_0);
    mxu_256 T11(clk, ta_1_0              , tw_0_1              , ts_0_1                ,
                     ta_1_1, tw_1_1, ts_1_1);

    // outer edges: rightmost column of tiles, bottom row of tiles
    assign a_out[ 255:   0]    = ta_0_1;
    assign a_out[ 511: 256]    = ta_1_1;
    assign w_out[ 255:   0]    = tw_1_0;
    assign w_out[ 511: 256]    = tw_1_1;
    assign psum_out[ 639:   0] = ts_1_0;
    assign psum_out[1279: 640] = ts_1_1;

endmodule
