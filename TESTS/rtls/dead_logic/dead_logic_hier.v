// remove_dead_logic -hier: dl_sub is tied off in one instance and live in the
// other, so its cells stay; dl_tied is tied off in its only instance and loses
// its enable-held flop, mux and dead inverter; the top loses a constant chain.
// dl_sub's ports have "reg" inside their names and the top drives an escaped
// bus bit through an assign: both used to be written back wrong.
module dl_sub (i_reg_en, d, clk, rst, o_reg_q);
  input [1:0] i_reg_en;
  input d, clk, rst;
  output o_reg_q;
  wire de, qe;
  MUX2_X1 m (.A(qe), .B(d), .S(i_reg_en[0]), .Z(de));
  DFFR_X1 f (.D(de), .RN(rst), .CK(clk), .Q(qe), .QN());
  AND2_X1 o (.A1(qe), .A2(i_reg_en[1]), .ZN(o_reg_q));
endmodule
module dl_tied (d, clk, rst, q);
  input d, clk, rst;
  output q;
  wire de, qe, x;
  MUX2_X1 m (.A(qe), .B(d), .S(1'b0), .Z(de));
  DFFR_X1 f (.D(de), .RN(rst), .CK(clk), .Q(qe), .QN());
  OR2_X1  o (.A1(qe), .A2(d), .ZN(q));
  INV_X1  dead (.A(d), .ZN(x));
endmodule
module htop (clk, rst, a, b, en, y1, y2, y3, y4, y5);
  input clk, rst, a, b;
  input [1:0] en;
  output y1, y2, y3, y4, y5;
  wire n0, q0;
  wire [1:0] \b.bus ;
  assign \b.bus [0] = b;
  AND2_X1 u_live (.A1(a), .A2(b), .ZN(y1));
  AND2_X1 u_and0 (.A1(1'b0), .A2(a), .ZN(n0));
  DFF_X1  u_ff0  (.D(n0), .CK(clk), .Q(q0), .QN());
  OR2_X1  u_or   (.A1(q0), .A2(b), .ZN(y2));
  dl_sub  u_s1 (.i_reg_en(2'h2), .d(a), .clk(clk), .rst(rst), .o_reg_q(y3));
  dl_sub  u_s2 (.i_reg_en(en), .d(\b.bus [0] ), .clk(clk), .rst(rst), .o_reg_q(y4));
  dl_tied u_t1 (.d(a), .clk(clk), .rst(rst), .q(y5));
endmodule
