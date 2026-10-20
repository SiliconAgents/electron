// nangate_escaped: names synthesis can only write escaped.  The enable every
// lane reads is a register inside a generate block, and each lane is a small
// module hier_synthesis absorbs into the top with a register of its own, so
// the netlist carries names like \g_drv[0].en_r and \g_lane[3].u_lane.r --
// and the enable's one flop drives about 512 pins, more than any flop can,
// which repair_drive has to buffer.
module esc_lane (input clk, input en, input d, output q);
  reg r;
  always @(posedge clk) if (en) r <= d ^ r;
  assign q = r & en;
endmodule

module esc_top (input clk, input [7:0] a, input [7:0] b, output [255:0] y);
  for (genvar j = 0; j < 1; j = j + 1) begin : g_drv
    reg en_r;
    always @(posedge clk) en_r <= &a;
  end
  for (genvar i = 0; i < 256; i = i + 1) begin : g_lane
    esc_lane u_lane (.clk(clk), .en(g_drv[0].en_r), .d(b[i % 8] ^ a[(i + 3) % 8]), .q(y[i]));
  end
endmodule
