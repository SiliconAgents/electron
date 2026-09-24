`timescale 1ns/1ps

// vedic_dot4 -- four 16x16 products, summed and registered.
//
//     acc <= a0*b0 + a1*b1 + a2*b2 + a3*b3
//
// One element of a 4x4 matrix product: row i of A against column j of B.
//
// WHY THIS MODULE EXISTS RATHER THAN INSTANTIATING THE MULTIPLIERS AT THE TOP
//
// It gives the hierarchy a middle level that has BOTH kinds of content: four
// hierarchical blocks and an adder tree of loose combinational cells that
// belong to this module and to no block.  That is the case the hierarchical
// placer has to handle in two passes -- hier_place arranges the blocks, the
// flops and the ports, and hier_place_cells fills the adder tree in around
// them.  A level holding only blocks, or only cells, exercises one pass.
//
// The concatenations are there so every operand of the add is the same width.
// Left implicit, a 32 bit + 32 bit sum is 32 bits wide in Verilog and the
// carry out of four products would be dropped; widening to 34 up front keeps
// it.
//
// vedic_16x16 registers its own operands and its own product, so a product
// appears two clocks after the operands and this stage adds a third.  There is
// no handshake and nothing here checks the result -- this is a placement
// testcase.  The pipelining matters only in that it puts flops on both sides
// of every block, which is what gives the anchor graph something to work with:
// an untyped combinational cone gets collapsed into a hyperedge, a flop is an
// anchor and gets placed.

module vedic_dot4(clk, a0, a1, a2, a3, b0, b1, b2, b3, acc);
    input clk;
    input  [15:0] a0, a1, a2, a3;
    input  [15:0] b0, b1, b2, b3;
    output reg [33:0] acc;

    wire [31:0] p0, p1, p2, p3;

    vedic_16x16 M0(clk, a0, b0, p0);
    vedic_16x16 M1(clk, a1, b1, p1);
    vedic_16x16 M2(clk, a2, b2, p2);
    vedic_16x16 M3(clk, a3, b3, p3);

    always @(posedge clk) begin
        acc <= {2'b00, p0} + {2'b00, p1} + {2'b00, p2} + {2'b00, p3};
    end

endmodule
