// nangate_unshare: two lane wrappers, different modules, each holding one
// vedic_8x8 -- the shape of two vector units' lanes sharing one unit.  laneB adds an
// adder16 beside it, so the two parents give the multiplier different boxes.
module laneA(a, b, r);
  input [7:0] a;
  input [7:0] b;
  output [15:0] r;
  vedic_8x8 M (
    .a(a),
    .b(b),
    .result(r)
  );
endmodule

module laneB(a, b, r);
  input [7:0] a;
  input [7:0] b;
  output [15:0] r;
  wire [15:0] p;
  vedic_8x8 M (
    .a(a),
    .b(b),
    .result(p)
  );
  adder16 S (
    .a(p),
    .b({ a, b }),
    .sum(r)
  );
endmodule

module two_lanes(a, b, r);
  input [7:0] a;
  input [7:0] b;
  output [31:0] r;
  laneA LA (
    .a(a),
    .b(b),
    .r(r[15:0])
  );
  laneB LB (
    .a(b),
    .b(a),
    .r(r[31:16])
  );
endmodule
