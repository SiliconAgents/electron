// nangate_aldff, part 2: a gate netlist with one behavioural block in its
// first module -- the reader must say so, not drop the second module
module first (input CLK, input R, input V, input D, output reg Q);
  always @(posedge CLK, posedge R)
    if (R) Q <= V;
    else Q <= D;
endmodule
module second (input A, output Z);
  INV_X1 u0 (.A(A), .ZN(Z));
endmodule
