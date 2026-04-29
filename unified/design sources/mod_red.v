`timescale 1ns / 1ps
//==============================================================================
// KaLi - Modular Reduction Unit
//
// Supports:
//   dk=0 : Dilithium  (q = 8380417 = 2^23 - 2^13 + 1), 46-bit input
//   dk=1 : Kyber x2   (q = 3329   = 2^12 - 2^9 - 2^8 + 1), two 24-bit inputs
//
// Pipeline stages: 2 clock cycles (reg_block_row stage + reg_30b stage)
// Output c [29:0]:
//   dk=0 : c[25:0] = d mod q_dilithium
//   dk=1 : c[29:15] = k_ip2 mod q_kyber,  c[14:0] = k_ip1 mod q_kyber
//==============================================================================

//------------------------------------------------------------------------------
// kyber_block: partial-result generator for Kyber prime
//   Implements 2^12 ≡ 2^9 + 2^8 - 1  and  2^11 ≡ -2^10 - 2^8 - 1
//   Input  ip  [23:0] : one 24-bit raw product (coefficients are 12-bit,
//                       so raw product ≤ 23 bits; upper bit can be sign)
//   Output op1..op8 [14:0] : partial results for CSA tree
//------------------------------------------------------------------------------
module kyber_block (
    input  [23:0] ip,
    output [14:0] op1, op2, op3, op4, op5, op6, op7, op8
);
    wire [23:0] neg_ip;
    assign neg_ip = ~ip;

    assign op1 = {3'b000, ip[11:0]};
    assign op2 = {3'b000, ip[13], {2{ip[12]}}, neg_ip[19:12]};
    assign op3 = {3'b000, ip[17], ip[13], ip[17], neg_ip[22:18], neg_ip[16:14]};
    assign op4 = {3'b000, ip[19], ip[15], ip[19], neg_ip[23:19], {3{neg_ip[17]}}};
    assign op5 = {3'b000, neg_ip[18], ip[19], neg_ip[23], 1'b0, neg_ip[23:20], {3{neg_ip[18]}}};
    assign op6 = {3'b000, neg_ip[16], ip[18], neg_ip[18], 3'b000, neg_ip[23:22], neg_ip[19], neg_ip[20], neg_ip[19]};
    assign op7 = {3'b000, neg_ip[15], 1'b0, neg_ip[14], 4'b0000, neg_ip[23], {2{neg_ip[21]}}, neg_ip[20]};
    assign op8 = {12'b110110101010, neg_ip[22], 2'b10};
endmodule

//------------------------------------------------------------------------------
// dilithium_block: partial-result generator for Dilithium prime
//   Implements 2^23 ≡ 2^13 - 1 applied recursively on a 46-bit product
//   Output op1..op6 [25:0] : partial results for CSA tree
//   op6 is a constant correction term
//------------------------------------------------------------------------------
module dilithium_block (
    input  [45:0] ip,
    output [25:0] op1, op2, op3, op4, op5, op6
);
    wire [45:0] neg_ip;
    assign neg_ip = ~ip;

    assign op1 = {3'b000, ip[22:0]};
    assign op2 = {3'b000, neg_ip[45:23]};
    assign op3 = {3'b000, ip[32:23], neg_ip[45:33]};
    assign op4 = {3'b000, ip[42:33], 10'b0, neg_ip[45:43]};
    assign op5 = {11'b0, ip[45:43], 12'b0};
    assign op6 = 26'b11011111111101111111111011;   // constant: 2's complement correction
endmodule

//------------------------------------------------------------------------------
// carry_save_adder: 8-input CSA tree → (sum, carry) in [29:0]
//------------------------------------------------------------------------------
module carry_save_adder (
    input  [29:0] ip1, ip2, ip3, ip4, ip5, ip6, ip7, ip8,
    output [29:0] c, s
);
    wire [29:0] s10, s11, s12, s20, s21, s30;
    wire [29:0] c10, c11, c12, c20, c21, c30;
    wire [29:0] ip10, ip11, ip12;
    wire [29:0] ip20, ip21;
    wire [29:0] ip30, ip40;

    fa_30 u0 (.x(ip1), .y(ip2), .z(ip3), .s(s10), .c(c10));
    fa_30 u1 (.x(ip4), .y(ip5), .z(ip6), .s(s11), .c(c11));
    ha_30 u2 (.x(ip7), .y(ip8), .z(30'b0), .s(s12), .c(c12));

    assign ip10 = c10 << 1;
    assign ip11 = c11 << 1;
    assign ip12 = c12 << 1;

    fa_30 u3 (.x(ip10), .y(ip11), .z(ip12), .s(s20), .c(c20));
    fa_30 u4 (.x(s10),  .y(s11),  .z(s12),  .s(s21), .c(c21));

    assign ip20 = c20 << 1;
    assign ip21 = c21 << 1;

    fa_30 u5 (.x(ip20), .y(ip21), .z(s20), .s(s30), .c(c30));

    assign ip30 = c30 << 1;
    fa_30 u6 (.x(ip30), .y(s30), .z(s21), .s(s), .c(ip40));
    assign c = ip40 << 1;
endmodule

//------------------------------------------------------------------------------
// ripple_carry_adder: trivial 30-bit adder to collapse CSA output
//------------------------------------------------------------------------------
module ripple_carry_adder (
    input  [29:0] x, y,
    output [29:0] z
);
    assign z = x + y;
endmodule

//------------------------------------------------------------------------------
// reg_30b: single 30-bit pipeline register
//------------------------------------------------------------------------------
module reg_30b (
    input  clk, rst,
    input  [29:0] ip,
    output reg [29:0] op
);
    always @(posedge clk) begin
        if (rst) op <= 30'b0;
        else     op <= ip;
    end
endmodule

//------------------------------------------------------------------------------
// reg_block_row: 8 × 30-bit pipeline registers
//------------------------------------------------------------------------------
module reg_block_row (
    input  clk, rst,
    input  [29:0] ip1, ip2, ip3, ip4, ip5, ip6, ip7, ip8,
    output reg [29:0] op1, op2, op3, op4, op5, op6, op7, op8
);
    always @(posedge clk) begin
        if (rst) begin
            op1 <= 30'b0; op2 <= 30'b0; op3 <= 30'b0; op4 <= 30'b0;
            op5 <= 30'b0; op6 <= 30'b0; op7 <= 30'b0; op8 <= 30'b0;
        end else begin
            op1 <= ip1; op2 <= ip2; op3 <= ip3; op4 <= ip4;
            op5 <= ip5; op6 <= ip6; op7 <= ip7; op8 <= ip8;
        end
    end
endmodule

//------------------------------------------------------------------------------
// mux: 8×30-bit 2-to-1 mux (selects Dilithium or Kyber partial results)
//------------------------------------------------------------------------------
module mux (
    input  [29:0] a1, a2, a3, a4, a5, a6, a7, a8,
    input  [29:0] b1, b2, b3, b4, b5, b6, b7, b8,
    input  s,
    output reg [29:0] o1, o2, o3, o4, o5, o6, o7, o8
);
    always @(*) begin
        if (s == 1'b0) begin
            o1 = a1; o2 = a2; o3 = a3; o4 = a4;
            o5 = a5; o6 = a6; o7 = a7; o8 = a8;
        end else begin
            o1 = b1; o2 = b2; o3 = b3; o4 = b4;
            o5 = b5; o6 = b6; o7 = b7; o8 = b8;
        end
    end
endmodule

//------------------------------------------------------------------------------
// selector: final range correction to bring result into [0, q)
//
//   dk=0  Dilithium: 26-bit raw → reduce mod 8380417 → [0, 8380417)
//   dk=1  Kyber×2 : two packed 15-bit halves, each → [0, 3329)
//
// Fully combinational (registered one cycle upstream in reg_30b).
//------------------------------------------------------------------------------
module selector (
    input  [29:0] x,
    input  dk,
    input  clk,      // kept for port compatibility; combinational inside
    output reg [29:0] y
);
    localparam [14:0] QKS = 15'd3329;
    localparam [29:0] QD  = 30'd8380417;

    reg [29:0] temp1, temp2, temp3, temp4, temp5, temp6, temp7, temp8;
    reg [14:0] t_lo, t_hi;
    reg [14:0] r_lo, r_hi;

    always @(*) begin
        if (dk == 1'b1) begin
            // ---- Kyber: two packed 15-bit lanes ----
            t_lo = x[14:0];
            t_hi = x[29:15];

            // lane 0
            if      ($signed({1'b0, t_lo}) < $signed({1'b0, QKS}))       r_lo = t_lo;
            else if ($signed({1'b0, t_lo}) < $signed({1'b0, 2*QKS}))     r_lo = t_lo - QKS;
            else if ($signed({1'b0, t_lo}) < $signed({1'b0, 3*QKS}))     r_lo = t_lo - 2*QKS;
            else                                                           r_lo = t_lo - 3*QKS;

            // lane 1
            if      ($signed({1'b0, t_hi}) < $signed({1'b0, QKS}))       r_hi = t_hi;
            else if ($signed({1'b0, t_hi}) < $signed({1'b0, 2*QKS}))     r_hi = t_hi - QKS;
            else if ($signed({1'b0, t_hi}) < $signed({1'b0, 3*QKS}))     r_hi = t_hi - 2*QKS;
            else                                                           r_hi = t_hi - 3*QKS;

            y = {r_hi, r_lo};
        end else begin
            // ---- Dilithium: single 26-bit value ----
            temp4 = {4'b0, x[25:0]};
            temp1 = temp4 + QD;
            temp2 = temp4 - QD;
            temp3 = temp4 - 2*QD;
            temp5 = QD - temp1;
            temp6 = QD - temp2;
            temp7 = QD - temp3;
            temp8 = QD - temp4;

            if      (!temp8[29]) y = temp4;
            else if (!temp6[29]) y = temp2;
            else if (!temp7[29]) y = temp3;
            else if (!temp5[29]) y = temp1;
            else                 y = 30'b0;
        end
    end
endmodule

//------------------------------------------------------------------------------
// mod_red: top-level modular reduction
//   This is the module instantiated by the BFU.
//   Inputs:
//     dk=0 : d_ip[45:0] = 46-bit Dilithium product
//     dk=1 : k_ip1[23:0], k_ip2[23:0] = two 24-bit Kyber products
//   Output:
//     c[29:0] — same encoding as selector above
//   Latency: 2 clock cycles
//------------------------------------------------------------------------------
module mod_red (
    input  clk, rst,
    input  dk,
    // Kyber paths (used when dk=1)
    input  [23:0] k_ip1,
    input  [23:0] k_ip2,
    // Dilithium path (used when dk=0)
    input  [45:0] d_ip,
    output [29:0] c
);
    // ---- Partial result buses ----
    wire [14:0] k1a, k2a, k3a, k4a, k5a, k6a, k7a, k8a;  // ip1 partial results
    wire [14:0] k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8b;  // ip2 partial results
    wire [29:0] k1, k2, k3, k4, k5, k6, k7, k8;
    wire [25:0] d1, d2, d3, d4, d5, d6;

    kyber_block kb1 (.ip(k_ip1),
        .op1(k1a), .op2(k2a), .op3(k3a), .op4(k4a),
        .op5(k5a), .op6(k6a), .op7(k7a), .op8(k8a));
    kyber_block kb2 (.ip(k_ip2),
        .op1(k1b), .op2(k2b), .op3(k3b), .op4(k4b),
        .op5(k5b), .op6(k6b), .op7(k7b), .op8(k8b));

    assign k1 = {k1b, k1a}; assign k2 = {k2b, k2a};
    assign k3 = {k3b, k3a}; assign k4 = {k4b, k4a};
    assign k5 = {k5b, k5a}; assign k6 = {k6b, k6a};
    assign k7 = {k7b, k7a}; assign k8 = {k8b, k8a};

    dilithium_block db (.ip(d_ip),
        .op1(d1), .op2(d2), .op3(d3), .op4(d4), .op5(d5), .op6(d6));

    // ---- Mux between Dilithium and Kyber partial results ----
    wire [29:0] add_ip1, add_ip2, add_ip3, add_ip4,
                add_ip5, add_ip6, add_ip7, add_ip8;

    wire [29:0] d_r1, d_r2, d_r3, d_r4, d_r5, d_r6, d_r7, d_r8;
    wire [29:0] k_r1, k_r2, k_r3, k_r4, k_r5, k_r6, k_r7, k_r8;

    reg_block_row rk (
        .clk(clk), .rst(rst),
        .ip1(k1), .ip2(k2), .ip3(k3), .ip4(k4),
        .ip5(k5), .ip6(k6), .ip7(k7), .ip8(k8),
        .op1(k_r1), .op2(k_r2), .op3(k_r3), .op4(k_r4),
        .op5(k_r5), .op6(k_r6), .op7(k_r7), .op8(k_r8));

    reg_block_row rd (
        .clk(clk), .rst(rst),
        .ip1({4'b0, d1}), .ip2({4'b0, d2}), .ip3({4'b0, d3}), .ip4({4'b0, d4}),
        .ip5({4'b0, d5}), .ip6({4'b0, d6}), .ip7(30'b0),       .ip8(30'b0),
        .op1(d_r1), .op2(d_r2), .op3(d_r3), .op4(d_r4),
        .op5(d_r5), .op6(d_r6), .op7(d_r7), .op8(d_r8));

    mux m0 (
        .a1(d_r1), .a2(d_r2), .a3(d_r3), .a4(d_r4),
        .a5(d_r5), .a6(d_r6), .a7(d_r7), .a8(d_r8),
        .b1(k_r1), .b2(k_r2), .b3(k_r3), .b4(k_r4),
        .b5(k_r5), .b6(k_r6), .b7(k_r7), .b8(k_r8),
        .s(dk),
        .o1(add_ip1), .o2(add_ip2), .o3(add_ip3), .o4(add_ip4),
        .o5(add_ip5), .o6(add_ip6), .o7(add_ip7), .o8(add_ip8));

    // ---- CSA + RCA ----
    wire [29:0] sum1, carr1, temp1;
    carry_save_adder csa0 (
        .ip1(add_ip1), .ip2(add_ip2), .ip3(add_ip3), .ip4(add_ip4),
        .ip5(add_ip5), .ip6(add_ip6), .ip7(add_ip7), .ip8(add_ip8),
        .s(sum1), .c(carr1));
    ripple_carry_adder rca0 (.x(sum1), .y(carr1), .z(temp1));

    // ---- Pipeline register ----
    wire [29:0] temp2;
    reg_30b rf (.clk(clk), .rst(rst), .ip(temp1), .op(temp2));

    // ---- Final range correction ----
    selector sel0 (.x(temp2), .dk(dk), .clk(clk), .y(c));
endmodule
