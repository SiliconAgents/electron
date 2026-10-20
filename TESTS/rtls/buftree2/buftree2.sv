// mixed loads: a reset reaching 128 flops in the parent itself AND 4 child
// instances (64 flops each, behind their rst port) -- a tree in the parent
// whose groups hold both leaf pins and child ports.
module bt2_child (input clk, input rst, input [63:0] d, output reg [63:0] q);
  always @(posedge clk or posedge rst) if (rst) q <= 0; else q <= d;
endmodule
module bt2_top (input clk, input [3:0] a, input [127:0] d, output reg [127:0] q, output [255:0] qc);
  wire rst = &a;
  always @(posedge clk or posedge rst) if (rst) q <= 0; else q <= d;
  for (genvar i = 0; i < 4; i = i + 1) begin : g_c
    bt2_child u_c (.clk(clk), .rst(rst), .d(d[64*(i%2)+:64]), .q(qc[64*i+:64]));
  end
endmodule
