`timescale 1ns/1ps

// mac_pe -- one processing element of a weight stationary systolic array.
//
// The cell an AI engine's matrix unit is tiled out of.  Three things flow
// through it and one stays:
//
//     a_in    -> a_out       activations, left to right along a row
//     w_in    -> w_out       weights, top to bottom down a column
//     psum_in -> psum_out    partial sums, top to bottom down a column
//     w_reg                  the weight that stays, and is multiplied
//
// Every path is registered, which is what makes it systolic: a PE only ever
// talks to its immediate neighbours, so the array has no long wires and no
// broadcast, and it can be tiled to any size without the timing changing.
// That is the property this testcase is really about -- physically it means
// the array is a mesh of identical blocks with only nearest neighbour
// connections, which is the easiest thing in the world to place well and a
// good way to find out whether a placer is doing anything at all.
//
// The multiply is the same vedic_16x16 the rest of TESTS uses.  It registers
// its own operands and product, so a product arrives two clocks after the
// activation; psum_out adds a third.  Nothing here compensates for that and
// nothing checks a result.  A real MXU would skew the input data across the
// array edge so the partial sums meet the right activations; this is a
// placement testcase and the skew buffers would be noise.
//
// psum is 40 bits: a 32 bit product accumulated down a column of up to 256
// PEs needs 8 bits of headroom, which is what a real accumulator width is
// chosen for too.

module mac_pe(clk, a_in, w_in, psum_in, a_out, w_out, psum_out);
    input clk;
    input  [15:0] a_in;
    input  [15:0] w_in;
    input  [39:0] psum_in;
    output reg [15:0] a_out;
    output reg [15:0] w_out;
    output reg [39:0] psum_out;

    reg  [15:0] w_reg;
    wire [31:0] prod;

    vedic_16x16 M(clk, a_in, w_reg, prod);

    always @(posedge clk) begin
        w_reg    <= w_in;
        w_out    <= w_reg;
        a_out    <= a_in;
        psum_out <= psum_in + {8'b00000000, prod};
    end

endmodule
