// A flop macro written as a ternary on the async reset, the form yosys-slang
// will not infer an async-load flop from.  For rtl_patch's header test.
`define FF_ASYNC_RESET(Q, D, V = '0, R = RESET, C = CLK) \
   always_ff @(posedge C or posedge R) Q <= R ? V : D;
