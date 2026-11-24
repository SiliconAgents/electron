// nangate_ungroup_escaped: an escaped child instance dissolved into its parent,
// its ports on escaped nets (a scalar and a bus bit), one of them through an
// assign.  See TESTS/Makefile.
module child ( a, b, o, p );
  input a, b;
  output o, p;
  wire \n[3].x ;
  AND2_X1 g1 ( .A1(a), .A2(b), .ZN(\n[3].x ) );
  INV_X1 g2 ( .A(\n[3].x ), .ZN(o) );
  assign p = \n[3].x ;
endmodule
module top ( a, b, o, q, r );
  input a, b;
  output o, q, r;
  wire \w[0].y ;
  wire [1:0] \rd.d ;
  child \g[0].u ( .a(a), .b(b), .o(\w[0].y ), .p(\rd.d [1]) );
  INV_X1 g3 ( .A(\w[0].y ), .ZN(o) );
  INV_X1 g4 ( .A(\rd.d [1]), .ZN(r) );
  assign q = \w[0].y ;
endmodule
