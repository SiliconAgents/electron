// nangate_assignload: one gate whose load is behind assigns.  The child drives
// eight output bits with one value, so synthesis writes one gate and seven
// "assign y[k] = y[0]" -- which read_verilog holds as buffer instances and
// write_verilog writes back as assigns.  Each bit fans out to six gates in the
// parent: the gate really drives 48 loads, over its limit; counting the
// assigns as seven buffer inputs, repair_drive saw 13 and left it alone.
// The child also passes f straight through to fo, a feedthrough:
// fix_multiple_port_nets (nangate_mpn) must make that a buffer too.
module al_src (input [7:0] a, input f, output [7:0] y, output fo);
  assign y = {8{&a}};
  assign fo = f;
endmodule

module al_top (input clk, input [7:0] a, input f, input [47:0] d, output reg [47:0] q, output fo);
  wire [7:0] y;
  al_src s (.a(a), .f(f), .y(y), .fo(fo));
  genvar i;
  for (i = 0; i < 48; i = i + 1) begin : g
    always @(posedge clk) q[i] <= d[i] & y[i % 8];
  end
endmodule
