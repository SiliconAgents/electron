// Testcases for check_dead_logic, check_const_logic and remove_dead_logic.
// Each cell says what the checks must conclude about it.
module dl_sub (en, d, clk, rst, q);
  input [1:0] en;
  input d, clk, rst;
  output q;
  wire de, qe;
  // enable flop with its enable tied off by the parent: holds its reset value
  MUX2_X1 m (.A(qe), .B(d), .S(en[0]), .Z(de));
  DFFR_X1 f (.D(de), .RN(rst), .CK(clk), .Q(qe), .QN());
  AND2_X1 o (.A1(qe), .A2(en[1]), .ZN(q));
endmodule
module dl_top (clk, rst, a, b, c, y1, y2, y3, y4);
  input clk, rst, a, b, c;
  output y1, y2, y3, y4;
  wire an, n0, q0, qp, dp, ql, dl, kq, kd;
  // live
  AND2_X1 u_live (.A1(a), .A2(b), .ZN(y1));
  // constant through a flop: AND with 0 -> DFF D=0 -> AND -> output port, constant
  INV_X1  u_inv  (.A(a), .ZN(an));
  AND2_X1 u_and0 (.A1(1'b0), .A2(an), .ZN(n0));
  DFF_X1  u_ff0  (.D(n0), .CK(clk), .Q(q0), .QN());
  AND2_X1 u_and1 (.A1(q0), .A2(b), .ZN(y2));
  // no-reset flop that only holds 1: constant only with -powerup
  MUX2_X1 u_pm (.A(qp), .B(1'b1), .S(c), .Z(dp));
  DFF_X1  u_p1 (.D(dp), .CK(clk), .Q(qp), .QN());
  BUF_X1  u_pb (.A(qp), .Z(y4));
  // dead loop
  DFF_X1  u_loop (.D(dl), .CK(clk), .Q(ql), .QN());
  INV_X1  u_linv (.A(ql), .ZN(dl));
  // dead, but dont_touch by name
  DFF_X1  d0nt_keep (.D(kd), .CK(clk), .Q(kq), .QN());
  INV_X1  u_kinv (.A(kq), .ZN(kd));
  // constant tied through a hierarchical port
  dl_sub u_sub (.en(2'h2), .d(a), .clk(clk), .rst(rst), .q(y3));
endmodule
module dl_ties (a, b, c, o);
  input a, b, c;
  output [24:0] o;
  wire z1, z2;
  AND2_X1 u_c1 (.A1(1'b0), .A2(a), .ZN(z1));
  AND2_X1 u_c2 (.A1(1'b0), .A2(b), .ZN(z2));
  OR2_X1 u_or0 (.A1(z1), .A2(c), .ZN(o[0]));
  OR2_X1 u_or1 (.A1(z1), .A2(c), .ZN(o[1]));
  OR2_X1 u_or2 (.A1(z1), .A2(c), .ZN(o[2]));
  OR2_X1 u_or3 (.A1(z1), .A2(c), .ZN(o[3]));
  OR2_X1 u_or4 (.A1(z1), .A2(c), .ZN(o[4]));
  OR2_X1 u_or5 (.A1(z1), .A2(c), .ZN(o[5]));
  OR2_X1 u_or6 (.A1(z1), .A2(c), .ZN(o[6]));
  OR2_X1 u_or7 (.A1(z1), .A2(c), .ZN(o[7]));
  OR2_X1 u_or8 (.A1(z1), .A2(c), .ZN(o[8]));
  OR2_X1 u_or9 (.A1(z1), .A2(c), .ZN(o[9]));
  OR2_X1 u_or10 (.A1(z1), .A2(c), .ZN(o[10]));
  OR2_X1 u_or11 (.A1(z1), .A2(c), .ZN(o[11]));
  OR2_X1 u_or12 (.A1(z1), .A2(c), .ZN(o[12]));
  OR2_X1 u_or13 (.A1(z1), .A2(c), .ZN(o[13]));
  OR2_X1 u_or14 (.A1(z1), .A2(c), .ZN(o[14]));
  OR2_X1 u_or15 (.A1(z2), .A2(c), .ZN(o[15]));
  OR2_X1 u_or16 (.A1(z2), .A2(c), .ZN(o[16]));
  OR2_X1 u_or17 (.A1(z2), .A2(c), .ZN(o[17]));
  OR2_X1 u_or18 (.A1(z2), .A2(c), .ZN(o[18]));
  OR2_X1 u_or19 (.A1(z2), .A2(c), .ZN(o[19]));
  OR2_X1 u_or20 (.A1(z2), .A2(c), .ZN(o[20]));
  OR2_X1 u_or21 (.A1(z2), .A2(c), .ZN(o[21]));
  OR2_X1 u_or22 (.A1(z2), .A2(c), .ZN(o[22]));
  OR2_X1 u_or23 (.A1(z2), .A2(c), .ZN(o[23]));
  OR2_X1 u_or24 (.A1(z2), .A2(c), .ZN(o[24]));
endmodule
