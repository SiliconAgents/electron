// An asynchronous reset that loads a SIGNAL, not a constant (a flop macro of
// the form `Q <= R ? V : D` with V a net): yosys makes it a $_ALDFF_, which
// no library cell implements directly.  Plus an ordinary async-reset flop
// after it, so a reader that stops early loses something countable.
module aldff (input logic CLK, input logic RESET, input logic v, input logic d,
              input logic e, output logic q, output logic qe, output logic q2);
  always_ff @(posedge CLK or posedge RESET) if (RESET) q <= v; else q <= d;
  always_ff @(posedge CLK or posedge RESET) if (RESET) qe <= ~v; else if (e) qe <= d;
  always_ff @(posedge CLK or posedge RESET) if (RESET) q2 <= 1'b0; else q2 <= q ^ qe;
endmodule
