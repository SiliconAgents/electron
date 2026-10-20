// nangate_buftree: a select that fans out INSIDE a child module, to 256 gates,
// and the child instantiated twice from one driver.  Kept hierarchical
// (-flatten_below 0), so repair_drive must build the tree inside the shared
// child definition -- port-local -- and the top then sees only each copy's
// tree inputs on its sel port.
// The child also registers its output on a clock that arrives by a port, the
// same fanout; that net must NOT get a tree -- clocks are CTS's.
module bt_bank (input clk, input sel, input [255:0] d, output reg [255:0] q);
  always @(posedge clk) q <= d & {256{sel}};
endmodule

module bt_top (input clk, input [7:0] a, input [255:0] d0, input [255:0] d1, output [255:0] q0, output [255:0] q1);
  wire sel = &a;
  bt_bank b0 (.clk(clk), .sel(sel), .d(d0), .q(q0));
  bt_bank b1 (.clk(clk), .sel(sel), .d(d1), .q(q1));
endmodule
