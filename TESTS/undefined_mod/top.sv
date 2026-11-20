// "macro" is instantiated but defined nowhere: no RTL, no stub.
module unknown_top(input logic clk, input logic [3:0] d, output logic [3:0] q);
  logic [3:0] m;
  macro u_macro(.a(d), .y(m));
  always_ff @(posedge clk) q <= m ^ d;
endmodule
