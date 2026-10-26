`include "flop_macros.svh"
module counter (input logic CLK, input logic RESET, output logic [3:0] q);
  logic [3:0] n;
  assign n = q + 4'd1;
  `FF_ASYNC_RESET(q, n, 4'h0, RESET, CLK)
endmodule
