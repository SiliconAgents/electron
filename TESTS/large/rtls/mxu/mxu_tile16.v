`timescale 1ns/1ps

// mxu_tile16 -- a 4x4 systolic tile, sixteen mac_pe.
//
// The smallest complete array.  Activations enter on the left and shift right
// along each row; weights and partial sums enter at the top and shift down
// each column.  Nothing crosses the tile except at its edges, so tiles compose
// by abutment -- which is what mxu_tile64 and mxu_256 do, and why an MXU can
// be any size.
//
//                w_in/psum_in (4 columns)
//                 |    |    |    |
//          a_in - P00  P01  P02  P03 - a_out
//          a_in - P10  P11  P12  P13 - a_out
//          a_in - P20  P21  P22  P23 - a_out
//          a_in - P30  P31  P32  P33 - a_out
//                 |    |    |    |
//                w_out/psum_out
//
// PORT PACKING, WHICH IS WHAT MAKES THE TILING CLEAN
//
// Row i's activation is a_in[16*i +: 16] and column j's partial sum is
// psum_in[40*j +: 40].  Pack them that way and a group of four adjacent rows
// is a CONTIGUOUS slice -- rows 4r..4r+3 are a_in[64*r +: 64] -- so a 2x2
// composition of these tiles wires up with whole slices and no per bit
// fiddling.  Every level above this one is four instances and twelve slices.

module mxu_tile16(clk, a_in, w_in, psum_in, a_out, w_out, psum_out);
    input clk;
    input  [63:0]  a_in;
    input  [63:0]  w_in;
    input  [159:0] psum_in;
    output [63:0]  a_out;
    output [63:0]  w_out;
    output [159:0] psum_out;

    // one set of outputs per PE: a goes right, w and s go down
    wire [15:0] a_0_0;  wire [15:0] w_0_0;  wire [39:0] s_0_0;
    wire [15:0] a_0_1;  wire [15:0] w_0_1;  wire [39:0] s_0_1;
    wire [15:0] a_0_2;  wire [15:0] w_0_2;  wire [39:0] s_0_2;
    wire [15:0] a_0_3;  wire [15:0] w_0_3;  wire [39:0] s_0_3;
    wire [15:0] a_1_0;  wire [15:0] w_1_0;  wire [39:0] s_1_0;
    wire [15:0] a_1_1;  wire [15:0] w_1_1;  wire [39:0] s_1_1;
    wire [15:0] a_1_2;  wire [15:0] w_1_2;  wire [39:0] s_1_2;
    wire [15:0] a_1_3;  wire [15:0] w_1_3;  wire [39:0] s_1_3;
    wire [15:0] a_2_0;  wire [15:0] w_2_0;  wire [39:0] s_2_0;
    wire [15:0] a_2_1;  wire [15:0] w_2_1;  wire [39:0] s_2_1;
    wire [15:0] a_2_2;  wire [15:0] w_2_2;  wire [39:0] s_2_2;
    wire [15:0] a_2_3;  wire [15:0] w_2_3;  wire [39:0] s_2_3;
    wire [15:0] a_3_0;  wire [15:0] w_3_0;  wire [39:0] s_3_0;
    wire [15:0] a_3_1;  wire [15:0] w_3_1;  wire [39:0] s_3_1;
    wire [15:0] a_3_2;  wire [15:0] w_3_2;  wire [39:0] s_3_2;
    wire [15:0] a_3_3;  wire [15:0] w_3_3;  wire [39:0] s_3_3;

    // The mesh.  a from the left neighbour or the tile edge; w and s
    // from the PE above or the tile edge.
    mac_pe P00(clk, a_in[ 15:  0]   , w_in[ 15:  0]   , psum_in[ 39:  0]    , a_0_0, w_0_0, s_0_0);
    mac_pe P01(clk, a_0_0           , w_in[ 31: 16]   , psum_in[ 79: 40]    , a_0_1, w_0_1, s_0_1);
    mac_pe P02(clk, a_0_1           , w_in[ 47: 32]   , psum_in[119: 80]    , a_0_2, w_0_2, s_0_2);
    mac_pe P03(clk, a_0_2           , w_in[ 63: 48]   , psum_in[159:120]    , a_0_3, w_0_3, s_0_3);
    mac_pe P10(clk, a_in[ 31: 16]   , w_0_0           , s_0_0               , a_1_0, w_1_0, s_1_0);
    mac_pe P11(clk, a_1_0           , w_0_1           , s_0_1               , a_1_1, w_1_1, s_1_1);
    mac_pe P12(clk, a_1_1           , w_0_2           , s_0_2               , a_1_2, w_1_2, s_1_2);
    mac_pe P13(clk, a_1_2           , w_0_3           , s_0_3               , a_1_3, w_1_3, s_1_3);
    mac_pe P20(clk, a_in[ 47: 32]   , w_1_0           , s_1_0               , a_2_0, w_2_0, s_2_0);
    mac_pe P21(clk, a_2_0           , w_1_1           , s_1_1               , a_2_1, w_2_1, s_2_1);
    mac_pe P22(clk, a_2_1           , w_1_2           , s_1_2               , a_2_2, w_2_2, s_2_2);
    mac_pe P23(clk, a_2_2           , w_1_3           , s_1_3               , a_2_3, w_2_3, s_2_3);
    mac_pe P30(clk, a_in[ 63: 48]   , w_2_0           , s_2_0               , a_3_0, w_3_0, s_3_0);
    mac_pe P31(clk, a_3_0           , w_2_1           , s_2_1               , a_3_1, w_3_1, s_3_1);
    mac_pe P32(clk, a_3_1           , w_2_2           , s_2_2               , a_3_2, w_3_2, s_3_2);
    mac_pe P33(clk, a_3_2           , w_2_3           , s_2_3               , a_3_3, w_3_3, s_3_3);

    // tile edges: the last PE of each row, and the last of each column
    assign a_out[ 15:  0]    = a_0_3;
    assign a_out[ 31: 16]    = a_1_3;
    assign a_out[ 47: 32]    = a_2_3;
    assign a_out[ 63: 48]    = a_3_3;
    assign w_out[ 15:  0]    = w_3_0;
    assign w_out[ 31: 16]    = w_3_1;
    assign w_out[ 47: 32]    = w_3_2;
    assign w_out[ 63: 48]    = w_3_3;
    assign psum_out[ 39:  0] = s_3_0;
    assign psum_out[ 79: 40] = s_3_1;
    assign psum_out[119: 80] = s_3_2;
    assign psum_out[159:120] = s_3_3;

endmodule
