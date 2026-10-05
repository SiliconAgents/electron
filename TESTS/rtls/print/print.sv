// $display and $write in RTL: simulation only, so neither the messages nor the
// logic that only feeds them (a ^ b below) may reach a gate netlist.
module dbg_child (input clk, input [3:0] a, b, output reg [3:0] q);
  initial $write("child: build note\n");
  always @(posedge clk) begin
    q <= a & b;
    $display("x=%d", a ^ b);
  end
endmodule

module print_top (input clk, input [3:0] a, b, c, output [3:0] q0, q1);
  initial begin
    if (1'b1) $write("top: build note\n");
  end
  dbg_child u0 (.clk(clk), .a(a), .b(b), .q(q0));
  dbg_child u1 (.clk(clk), .a(b), .b(c), .q(q1));
endmodule
