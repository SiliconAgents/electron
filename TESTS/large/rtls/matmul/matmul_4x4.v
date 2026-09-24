`timescale 1ns/1ps

// matmul_4x4 -- a 4x4 by 4x4 matrix multiply, 16 bit elements.
//
//     C[i][j] = sum over k of A[i][k] * B[k][j]
//
// Sixteen vedic_dot4 units, each holding four vedic_16x16 multipliers, so the
// design carries SIXTY FOUR instances of vedic_16x16 -- about 271,000 leaf
// cells against the 4,233 of the multiplier on its own.  That is what this
// directory is for.
//
// WHAT IT IS A TEST OF
//
// The hierarchy, not the arithmetic.  Nothing here checks a product; there is
// no handshake, no valid, and the pipeline depth is whatever falls out of
// vedic_16x16 registering its own operands and result.  What matters is the
// shape:
//
//     matmul_4x4                 16 dot4 blocks, 1057 ports
//       vedic_dot4               4 multipliers + an adder tree
//         vedic_16x16            4 vedic_8x8 + 3 adders + 64 flops
//           vedic_8x8            4 vedic_4x4 + 3 adders
//             vedic_4x4          4 vedic_2x2 + 3 adders
//               vedic_2x2        2 halfAdder + gates
//                 halfAdder
//
// Seven levels and thirteen distinct modules.  Thirteen is the number that
// matters to hier_place_all: a module has one floorplan, so all 64 copies of
// vedic_16x16 share one arrangement and the walk places it ONCE.  The 64
// instances are only the flat side's problem, and that is where this design
// gets expensive -- hier2flat composes a transform per instance, and the flat
// instance store ends up with a quarter of a million entries.
//
// WHY THE PORTS AND WIRES ARE WRITTEN OUT LONGHAND
//
// A generate loop would be four lines instead of a hundred, and yosys handles
// it perfectly.  The problem is downstream: yosys names an instance inside a
// generate block "\gen_row[0].gen_col[1].DOT" -- brackets, a dot, and a
// leading backslash.  Electron joins hierarchical instance names with "/" and
// writes them into a DEF, so a name carrying its own brackets and dots is
// asking for trouble from parsers that have never had to survive one.  D00
// through D33 cannot surprise anything.
//
// The matrices arrive as flat vectors because a 2-D port is not Verilog-2001.
// Row major, so A[i][k] is a[16*(4*i+k) +: 16], and the named wires below are
// that arithmetic done once, where it can be read.

module matmul_4x4(clk, a, b, c);
    input clk;
    input  [255:0] a;
    input  [255:0] b;
    output [543:0] c;

    // A, row major: aik is A[i][k]
    wire [15:0] a00 = a[ 15:  0];
    wire [15:0] a01 = a[ 31: 16];
    wire [15:0] a02 = a[ 47: 32];
    wire [15:0] a03 = a[ 63: 48];
    wire [15:0] a10 = a[ 79: 64];
    wire [15:0] a11 = a[ 95: 80];
    wire [15:0] a12 = a[111: 96];
    wire [15:0] a13 = a[127:112];
    wire [15:0] a20 = a[143:128];
    wire [15:0] a21 = a[159:144];
    wire [15:0] a22 = a[175:160];
    wire [15:0] a23 = a[191:176];
    wire [15:0] a30 = a[207:192];
    wire [15:0] a31 = a[223:208];
    wire [15:0] a32 = a[239:224];
    wire [15:0] a33 = a[255:240];

    // B, row major: bkj is B[k][j]
    wire [15:0] b00 = b[ 15:  0];
    wire [15:0] b01 = b[ 31: 16];
    wire [15:0] b02 = b[ 47: 32];
    wire [15:0] b03 = b[ 63: 48];
    wire [15:0] b10 = b[ 79: 64];
    wire [15:0] b11 = b[ 95: 80];
    wire [15:0] b12 = b[111: 96];
    wire [15:0] b13 = b[127:112];
    wire [15:0] b20 = b[143:128];
    wire [15:0] b21 = b[159:144];
    wire [15:0] b22 = b[175:160];
    wire [15:0] b23 = b[191:176];
    wire [15:0] b30 = b[207:192];
    wire [15:0] b31 = b[223:208];
    wire [15:0] b32 = b[239:224];
    wire [15:0] b33 = b[255:240];

    // C, row major: cij is C[i][j]
    wire [33:0] c00;
    assign c[ 33:  0] = c00;
    wire [33:0] c01;
    assign c[ 67: 34] = c01;
    wire [33:0] c02;
    assign c[101: 68] = c02;
    wire [33:0] c03;
    assign c[135:102] = c03;
    wire [33:0] c10;
    assign c[169:136] = c10;
    wire [33:0] c11;
    assign c[203:170] = c11;
    wire [33:0] c12;
    assign c[237:204] = c12;
    wire [33:0] c13;
    assign c[271:238] = c13;
    wire [33:0] c20;
    assign c[305:272] = c20;
    wire [33:0] c21;
    assign c[339:306] = c21;
    wire [33:0] c22;
    assign c[373:340] = c22;
    wire [33:0] c23;
    assign c[407:374] = c23;
    wire [33:0] c30;
    assign c[441:408] = c30;
    wire [33:0] c31;
    assign c[475:442] = c31;
    wire [33:0] c32;
    assign c[509:476] = c32;
    wire [33:0] c33;
    assign c[543:510] = c33;

    // One dot product unit per element of C: row i of A against column j of B
    vedic_dot4 D00(clk, a00, a01, a02, a03, b00, b10, b20, b30, c00);
    vedic_dot4 D01(clk, a00, a01, a02, a03, b01, b11, b21, b31, c01);
    vedic_dot4 D02(clk, a00, a01, a02, a03, b02, b12, b22, b32, c02);
    vedic_dot4 D03(clk, a00, a01, a02, a03, b03, b13, b23, b33, c03);
    vedic_dot4 D10(clk, a10, a11, a12, a13, b00, b10, b20, b30, c10);
    vedic_dot4 D11(clk, a10, a11, a12, a13, b01, b11, b21, b31, c11);
    vedic_dot4 D12(clk, a10, a11, a12, a13, b02, b12, b22, b32, c12);
    vedic_dot4 D13(clk, a10, a11, a12, a13, b03, b13, b23, b33, c13);
    vedic_dot4 D20(clk, a20, a21, a22, a23, b00, b10, b20, b30, c20);
    vedic_dot4 D21(clk, a20, a21, a22, a23, b01, b11, b21, b31, c21);
    vedic_dot4 D22(clk, a20, a21, a22, a23, b02, b12, b22, b32, c22);
    vedic_dot4 D23(clk, a20, a21, a22, a23, b03, b13, b23, b33, c23);
    vedic_dot4 D30(clk, a30, a31, a32, a33, b00, b10, b20, b30, c30);
    vedic_dot4 D31(clk, a30, a31, a32, a33, b01, b11, b21, b31, c31);
    vedic_dot4 D32(clk, a30, a31, a32, a33, b02, b12, b22, b32, c32);
    vedic_dot4 D33(clk, a30, a31, a32, a33, b03, b13, b23, b33, c33);

endmodule
