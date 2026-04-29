`timescale 1ns / 1ps
//==============================================================================
// KaLi — Unified Cryptoprocessor for CRYSTALS-Kyber and CRYSTALS-Dilithium
//
// Design Sources  (all modules in one file for easy Vivado / ModelSim import)
//
// Module hierarchy:
//   fa, ha
//   fa_30, ha_30
//   carry_save_adder
//   ripple_carry_adder
//   reg_30b, reg_block_row
//   mux
//   kyber_block, dilithium_block
//   selector
//   mod_red                   ← modular reduction top-level
//
//   unified_add, unified_sub
//   unified_right_shift
//   unified_multiplier
//   unified_bfu               ← butterfly unit (uses mod_red internally)
//
//   compress_unit
//   decompress_unit
//   compress_decompress       ← compress/decompress wrapper
//   encode_unit
//   decode_unit
//
// Constants:
//   Dilithium q = 8380417 = 2^23 − 2^13 + 1   (23-bit prime)
//   Kyber     q = 3329   = 2^12 − 2^9 − 2^8 + 1  (12-bit prime)
//==============================================================================


// ============================================================
//  PRIMITIVES
// ============================================================

module fa (
    input  x, y, z,
    output s, c
);
    assign s = x ^ y ^ z;
    assign c = (x & y) | (y & z) | (z & x);
endmodule

//------------------------------------------------------------

module ha (
    input  a, b,
    output s, c
);
    assign s = a ^ b;
    assign c = a & b;
endmodule

//------------------------------------------------------------

module fa_30 (
    input  [29:0] x, y, z,
    output [29:0] s, c
);
    genvar i;
    generate
        for (i = 0; i < 30; i = i + 1) begin : FA30
            fa u0 (.x(x[i]), .y(y[i]), .z(z[i]), .s(s[i]), .c(c[i]));
        end
    endgenerate
endmodule

//------------------------------------------------------------

module ha_30 (
    input  [29:0] x, y,
    // z port retained for structural symmetry; unused
    input  [29:0] z,
    output [29:0] s, c
);
    genvar i;
    generate
        for (i = 0; i < 30; i = i + 1) begin : HA30
            ha u0 (.a(x[i]), .b(y[i]), .s(s[i]), .c(c[i]));
        end
    endgenerate
    // synthesis translate_off
    wire _unused_z = |z;
    // synthesis translate_on
endmodule


// ============================================================
//  MODULAR REDUCTION BUILDING BLOCKS
// ============================================================

// ------ kyber_block ------------------------------------------
// Partial-result generator for Kyber prime using
//   2^12 ≡ 2^9 + 2^8 − 1  and  2^11 ≡ −2^10 − 2^8 − 1
// Input:  ip[23:0]  one 24-bit product term
// Output: op1..op8  fifteen-bit partial results for the CSA tree

module kyber_block (
    input  [23:0] ip,
    output [14:0] op1, op2, op3, op4, op5, op6, op7, op8
);
    wire [23:0] neg_ip = ~ip;

    assign op1 = {3'b000, ip[11:0]};
    assign op2 = {3'b000, ip[13], {2{ip[12]}}, neg_ip[19:12]};
    assign op3 = {3'b000, ip[17], ip[13], ip[17], neg_ip[22:18], neg_ip[16:14]};
    assign op4 = {3'b000, ip[19], ip[15], ip[19], neg_ip[23:19], {3{neg_ip[17]}}};
    assign op5 = {3'b000, neg_ip[18], ip[19], neg_ip[23], 1'b0, neg_ip[23:20], {3{neg_ip[18]}}};
    assign op6 = {3'b000, neg_ip[16], ip[18], neg_ip[18], 3'b000, neg_ip[23:22], neg_ip[19], neg_ip[20], neg_ip[19]};
    assign op7 = {3'b000, neg_ip[15], 1'b0, neg_ip[14], 4'b0000, neg_ip[23], {2{neg_ip[21]}}, neg_ip[20]};
    assign op8 = {12'b110110101010, neg_ip[22], 2'b10};
endmodule

// ------ dilithium_block --------------------------------------
// Partial-result generator for Dilithium prime using
//   2^23 ≡ 2^13 − 1 (applied recursively on 46-bit product)
// op6 is a constant 2's-complement correction term

module dilithium_block (
    input  [45:0] ip,
    output [25:0] op1, op2, op3, op4, op5, op6
);
    wire [45:0] neg_ip = ~ip;

    assign op1 = {3'b000, ip[22:0]};
    assign op2 = {3'b000, neg_ip[45:23]};
    assign op3 = {3'b000, ip[32:23], neg_ip[45:33]};
    assign op4 = {3'b000, ip[42:33], 10'b0, neg_ip[45:43]};
    assign op5 = {11'b0, ip[45:43], 12'b0};
    assign op6 = 26'b11011111111101111111111011;   // constant correction
endmodule

// ------ carry_save_adder -------------------------------------
// 8-input, 30-bit CSA tree → (sum S, carry C) pair

module carry_save_adder (
    input  [29:0] ip1, ip2, ip3, ip4, ip5, ip6, ip7, ip8,
    output [29:0] c, s
);
    wire [29:0] s10,s11,s12, c10,c11,c12;
    wire [29:0] s20,s21,     c20,c21;
    wire [29:0] s30,         c30;
    wire [29:0] ip10,ip11,ip12, ip20,ip21, ip30, ip40;

    fa_30 u0 (.x(ip1),.y(ip2),.z(ip3),.s(s10),.c(c10));
    fa_30 u1 (.x(ip4),.y(ip5),.z(ip6),.s(s11),.c(c11));
    ha_30 u2 (.x(ip7),.y(ip8),.z(30'b0),.s(s12),.c(c12));

    assign ip10=c10<<1; assign ip11=c11<<1; assign ip12=c12<<1;

    fa_30 u3 (.x(ip10),.y(ip11),.z(ip12),.s(s20),.c(c20));
    fa_30 u4 (.x(s10), .y(s11), .z(s12), .s(s21),.c(c21));

    assign ip20=c20<<1; assign ip21=c21<<1;

    fa_30 u5 (.x(ip20),.y(ip21),.z(s20),.s(s30),.c(c30));

    assign ip30=c30<<1;
    fa_30 u6 (.x(ip30),.y(s30),.z(s21),.s(s),.c(ip40));
    assign c = ip40<<1;
endmodule

// ------ ripple_carry_adder -----------------------------------

module ripple_carry_adder (
    input  [29:0] x, y,
    output [29:0] z
);
    assign z = x + y;
endmodule

// ------ reg_30b ----------------------------------------------

module reg_30b (
    input  clk, rst,
    input  [29:0] ip,
    output reg [29:0] op
);
    always @(posedge clk)
        if (rst) op <= 30'b0;
        else     op <= ip;
endmodule

// ------ reg_block_row ----------------------------------------

module reg_block_row (
    input  clk, rst,
    input  [29:0] ip1,ip2,ip3,ip4,ip5,ip6,ip7,ip8,
    output reg [29:0] op1,op2,op3,op4,op5,op6,op7,op8
);
    always @(posedge clk) begin
        if (rst) begin
            op1<=30'b0; op2<=30'b0; op3<=30'b0; op4<=30'b0;
            op5<=30'b0; op6<=30'b0; op7<=30'b0; op8<=30'b0;
        end else begin
            op1<=ip1; op2<=ip2; op3<=ip3; op4<=ip4;
            op5<=ip5; op6<=ip6; op7<=ip7; op8<=ip8;
        end
    end
endmodule

// ------ mux --------------------------------------------------

module mux (
    input  [29:0] a1,a2,a3,a4,a5,a6,a7,a8,
    input  [29:0] b1,b2,b3,b4,b5,b6,b7,b8,
    input  s,
    output reg [29:0] o1,o2,o3,o4,o5,o6,o7,o8
);
    always @(*) begin
        if (!s) begin
            o1=a1; o2=a2; o3=a3; o4=a4; o5=a5; o6=a6; o7=a7; o8=a8;
        end else begin
            o1=b1; o2=b2; o3=b3; o4=b4; o5=b5; o6=b6; o7=b7; o8=b8;
        end
    end
endmodule

// ------ selector ---------------------------------------------
// Final range-correction block.
//   dk=0 Dilithium: 26-bit raw result → [0, 8380417)
//   dk=1 Kyber ×2: two packed 15-bit lanes → each [0, 3329)

module selector (
    input  [29:0] x,
    input  dk,
    input  clk,     // retained for port compatibility
    output reg [29:0] y
);
    localparam [14:0] QKS = 15'd3329;
    localparam [29:0] QD  = 30'd8380417;

    reg [29:0] t4, t1, t2, t3, t5, t6, t7, t8;
    reg [14:0] lo, hi, r_lo, r_hi;

    always @(*) begin
        if (dk) begin
            lo = x[14:0];
            hi = x[29:15];

            if      (lo <  QKS)      r_lo = lo;
            else if (lo < 2*QKS)     r_lo = lo - QKS;
            else if (lo < 3*QKS)     r_lo = lo - 2*QKS;
            else                     r_lo = lo - 3*QKS;

            if      (hi <  QKS)      r_hi = hi;
            else if (hi < 2*QKS)     r_hi = hi - QKS;
            else if (hi < 3*QKS)     r_hi = hi - 2*QKS;
            else                     r_hi = hi - 3*QKS;

            y = {r_hi, r_lo};
        end else begin
            t4 = {4'b0, x[25:0]};
            t1 = t4 + QD;
            t2 = t4 - QD;
            t3 = t4 - 2*QD;
            t5 = QD - t1; t6 = QD - t2; t7 = QD - t3; t8 = QD - t4;

            if      (!t8[29]) y = t4;
            else if (!t6[29]) y = t2;
            else if (!t7[29]) y = t3;
            else if (!t5[29]) y = t1;
            else              y = 30'b0;
        end
    end
endmodule

// ------ mod_red ----------------------------------------------
// Modular Reduction top-level (Fig. 3 in paper)
// Latency: 2 clock cycles
//   dk=0: d_ip[45:0] → c[25:0] reduced mod 8380417
//   dk=1: k_ip1[23:0],k_ip2[23:0] → c[29:15]/c[14:0] each mod 3329

module mod_red (
    input  clk, rst,
    input  dk,
    input  [23:0] k_ip1, k_ip2,
    input  [45:0] d_ip,
    output [29:0] c
);
    wire [14:0] k1a,k2a,k3a,k4a,k5a,k6a,k7a,k8a;
    wire [14:0] k1b,k2b,k3b,k4b,k5b,k6b,k7b,k8b;
    wire [29:0] k1,k2,k3,k4,k5,k6,k7,k8;
    wire [25:0] d1,d2,d3,d4,d5,d6;

    kyber_block kb1 (.ip(k_ip1),
        .op1(k1a),.op2(k2a),.op3(k3a),.op4(k4a),
        .op5(k5a),.op6(k6a),.op7(k7a),.op8(k8a));
    kyber_block kb2 (.ip(k_ip2),
        .op1(k1b),.op2(k2b),.op3(k3b),.op4(k4b),
        .op5(k5b),.op6(k6b),.op7(k7b),.op8(k8b));

    assign k1={k1b,k1a}; assign k2={k2b,k2a};
    assign k3={k3b,k3a}; assign k4={k4b,k4a};
    assign k5={k5b,k5a}; assign k6={k6b,k6a};
    assign k7={k7b,k7a}; assign k8={k8b,k8a};

    dilithium_block db (.ip(d_ip),
        .op1(d1),.op2(d2),.op3(d3),.op4(d4),.op5(d5),.op6(d6));

    wire [29:0] d_r1,d_r2,d_r3,d_r4,d_r5,d_r6,d_r7,d_r8;
    wire [29:0] k_r1,k_r2,k_r3,k_r4,k_r5,k_r6,k_r7,k_r8;

    reg_block_row rk (.clk(clk),.rst(rst),
        .ip1(k1),.ip2(k2),.ip3(k3),.ip4(k4),
        .ip5(k5),.ip6(k6),.ip7(k7),.ip8(k8),
        .op1(k_r1),.op2(k_r2),.op3(k_r3),.op4(k_r4),
        .op5(k_r5),.op6(k_r6),.op7(k_r7),.op8(k_r8));

    reg_block_row rd (.clk(clk),.rst(rst),
        .ip1({4'b0,d1}),.ip2({4'b0,d2}),.ip3({4'b0,d3}),.ip4({4'b0,d4}),
        .ip5({4'b0,d5}),.ip6({4'b0,d6}),.ip7(30'b0),.ip8(30'b0),
        .op1(d_r1),.op2(d_r2),.op3(d_r3),.op4(d_r4),
        .op5(d_r5),.op6(d_r6),.op7(d_r7),.op8(d_r8));

    wire [29:0] a1,a2,a3,a4,a5,a6,a7,a8;
    mux m0 (.a1(d_r1),.a2(d_r2),.a3(d_r3),.a4(d_r4),
            .a5(d_r5),.a6(d_r6),.a7(d_r7),.a8(d_r8),
            .b1(k_r1),.b2(k_r2),.b3(k_r3),.b4(k_r4),
            .b5(k_r5),.b6(k_r6),.b7(k_r7),.b8(k_r8),
            .s(dk),
            .o1(a1),.o2(a2),.o3(a3),.o4(a4),
            .o5(a5),.o6(a6),.o7(a7),.o8(a8));

    wire [29:0] sum1, carr1, temp1, temp2;
    carry_save_adder csa0 (
        .ip1(a1),.ip2(a2),.ip3(a3),.ip4(a4),
        .ip5(a5),.ip6(a6),.ip7(a7),.ip8(a8),
        .s(sum1),.c(carr1));
    ripple_carry_adder rca0 (.x(sum1),.y(carr1),.z(temp1));
    reg_30b rf (.clk(clk),.rst(rst),.ip(temp1),.op(temp2));
    selector sel0 (.x(temp2),.dk(dk),.clk(clk),.y(c));
endmodule


// ============================================================
//  UNIFIED POLYNOMIAL ARITHMETIC UNIT
// ============================================================

// ------ unified_add -----------------------------------------

module unified_add (
    input  [23:0] a, b,
    input  mode,        // 0=Dilithium (full 24-bit), 1=Kyber (two 12-bit)
    output [23:0] c
);
    wire carry;
    wire [11:0] c_lo, c_hi;
    assign {carry, c_lo} = a[11:0] + b[11:0];
    assign c_hi = mode ? (a[23:12] + b[23:12]) : (a[23:12] + b[23:12] + carry);
    assign c = {c_hi, c_lo};
endmodule

// ------ unified_sub -----------------------------------------

module unified_sub (
    input  [23:0] a, b,
    input  mode,
    output [23:0] c
);
    wire borrow;
    wire [11:0] c_lo, c_hi;
    assign {borrow, c_lo} = a[11:0] - b[11:0];
    assign c_hi = mode ? (a[23:12] - b[23:12]) : (a[23:12] - b[23:12] - borrow);
    assign c = {c_hi, c_lo};
endmodule

// ------ unified_right_shift ---------------------------------

module unified_right_shift (
    input  [23:0] a,
    input  mode,
    output [23:0] c
);
    assign c = mode ? {a[23:12] >> 1, a[11:0] >> 1} : (a >> 1);
endmodule

// ------ unified_multiplier (Algorithm 2) -------------------
// sel=0 (Dilithium): a[22:0] * b[22:0] → d[45:0]
// sel=1 (Kyber):     {a_hi,a_lo} * {b_hi,b_lo} → {d_hi,d_lo} packed in d[47:0]

module unified_multiplier (
    input  signed [23:0] a, b,
    input  sel,
    output signed [47:0] d
);
    wire signed [11:0] a_lo = a[11:0], a_hi = a[23:12];
    wire signed [11:0] b_lo = b[11:0], b_hi = b[23:12];

    // sign-extend to 24 bits
    wire signed [23:0] a_hi_e = sel ? {{12{a_hi[11]}},a_hi} : {{12{a[23]}},a_hi};
    wire signed [23:0] a_lo_e = sel ? {{12{a_lo[11]}},a_lo} : {{12{a[23]}},a_lo};
    wire signed [23:0] b_hi_e = sel ? {{12{b_hi[11]}},b_hi} : {{12{b[23]}},b_hi};

    wire signed [23:0] d0 = sel ? b_hi_e : b;
    wire signed [47:0] m0 = d0 * a_hi_e;
    wire signed [47:0] m1 = sel ? (m0 <<< 24) : (m0 <<< 12);

    wire signed [23:0] d1 = sel ? {{12{b_lo[11]}},b_lo} : b;
    wire signed [47:0] m2 = d1 * a_lo_e;

    assign d = m2 + m1;
endmodule

// ------ unified_bfu (Fig. 4) --------------------------------
// Forward NTT (inv=0, CT butterfly):
//   y0 = (xj  + w*xjt) mod q
//   y1 = (xj  - w*xjt) mod q
// Inverse NTT (inv=1, GS butterfly):
//   y0 = (xj + xjt) * inv(2) mod q
//   y1 = (w * (xj - xjt)) * inv(2) mod q
//
// mode=0 → Dilithium (23-bit), mode=1 → Kyber (two packed 12-bit)
// Pipeline latency: 5 cycles (registered output on final cycle)

module unified_bfu (
    input  clk, rst,
    input  [23:0] xj, xjt, w,
    input  mode, inv,
    output reg [23:0] y0, y1
);

// --------- Stage 1: combinational add/sub ----------
wire [23:0] add_s1, sub_s1;
unified_add  s1_add (.a(xj),.b(xjt),.mode(mode),.c(add_s1));
unified_sub  s1_sub (.a(xj),.b(xjt),.mode(mode),.c(sub_s1));

reg [23:0] xj_r1,xjt_r1,add_r1,sub_r1,w_r1;
reg mode_r1,inv_r1;
always @(posedge clk) begin
    xj_r1<=xj; xjt_r1<=xjt; add_r1<=add_s1;
    sub_r1<=sub_s1; w_r1<=w; mode_r1<=mode; inv_r1<=inv;
end

// xj pipeline: needs to reach output stage (5 cycles from input)
reg [23:0] xj_r2,xj_r3,xj_r4,xj_r5;
always @(posedge clk) begin
    xj_r2<=xj_r1; xj_r3<=xj_r2; xj_r4<=xj_r3; xj_r5<=xj_r4;
end

// --------- Stage 2: multiply ----------
wire [23:0] mul_in = inv_r1 ? sub_r1 : xjt_r1;
wire signed [47:0] mul_out;
unified_multiplier umul (.a(w_r1),.b(mul_in),.sel(mode_r1),.d(mul_out));

reg signed [47:0] mul_r2;
reg [23:0] add_r2;
reg mode_r2,inv_r2;
always @(posedge clk) begin
    mul_r2<=mul_out; add_r2<=add_r1; mode_r2<=mode_r1; inv_r2<=inv_r1;
end

// --------- Stage 3+4: modular reduction (2 cycles in mod_red) ----------
// Sign handling: take absolute value before reduction, negate output if needed

wire neg_lo_s2 = mul_r2[23];
wire neg_hi_s2 = mul_r2[47];

wire [23:0] abs_lo = neg_lo_s2 ? (~mul_r2[23:0]  + 1) : mul_r2[23:0];
wire [23:0] abs_hi = neg_hi_s2 ? (~mul_r2[47:24] + 1) : mul_r2[47:24];
wire [45:0] abs_dil= neg_hi_s2 ? (~mul_r2[45:0]  + 1) : mul_r2[45:0];

wire [29:0] modred_out;
mod_red mr (
    .clk(clk),.rst(rst),.dk(mode_r2),
    .k_ip1(abs_lo),.k_ip2(abs_hi),
    .d_ip(abs_dil),
    .c(modred_out)
);

// Pipeline side-channel signals through mod_red's 2-cycle delay
reg neg_lo_r3,neg_hi_r3,mode_r3,inv_r3;
reg neg_lo_r4,neg_hi_r4,mode_r4,inv_r4;
reg [23:0] add_r3,add_r4;
always @(posedge clk) begin
    neg_lo_r3<=neg_lo_s2; neg_hi_r3<=neg_hi_s2;
    mode_r3<=mode_r2; inv_r3<=inv_r2; add_r3<=add_r2;
    neg_lo_r4<=neg_lo_r3; neg_hi_r4<=neg_hi_r3;
    mode_r4<=mode_r3; inv_r4<=inv_r3; add_r4<=add_r3;
end

// Post-reduction sign correction
localparam [11:0] QK = 12'd3329;
localparam [22:0] QD = 23'd8380417;

wire [11:0] red_lo  = modred_out[11:0];
wire [11:0] red_hi  = modred_out[26:15];   // selector packs Kyber into [29:15],[14:0]
wire [22:0] red_d   = modred_out[22:0];

wire [11:0] cor_k_lo = neg_lo_r4 ? (QK - red_lo) : red_lo;
wire [11:0] cor_k_hi = neg_hi_r4 ? (QK - red_hi) : red_hi;
wire [22:0] cor_d    = neg_hi_r4 ? (QD - red_d)  : red_d;

wire [23:0] modredout = mode_r4 ?
    {cor_k_hi, cor_k_lo} :
    {1'b0, cor_d};

// --------- Stage 5: output formation ----------
wire [23:0] y0_fwd, y1_fwd, y0_inv, y1_inv;
unified_add  o_add (.a(xj_r5),.b(modredout),.mode(mode_r4),.c(y0_fwd));
unified_sub  o_sub (.a(xj_r5),.b(modredout),.mode(mode_r4),.c(y1_fwd));
unified_right_shift rs0 (.a(add_r4),   .mode(mode_r4),.c(y0_inv));
unified_right_shift rs1 (.a(modredout),.mode(mode_r4),.c(y1_inv));

always @(posedge clk) begin
    if (inv_r4) begin y0<=y0_inv; y1<=y1_inv; end
    else        begin y0<=y0_fwd; y1<=y1_fwd; end
end

// Debug wires for waveform inspection
wire [11:0] dbg_y0_lo=y0[11:0], dbg_y0_hi=y0[23:12];
wire [11:0] dbg_y1_lo=y1[11:0], dbg_y1_hi=y1[23:12];

endmodule


// ============================================================
//  COMPRESS / DECOMPRESS UNIT  (Algorithm 3 + Fig. 10)
// ============================================================

// ------ compress_unit ----------------------------------------
// Implements y = ⌈(2^d / q) · x⌋ mod 2^d,  q=3329
// Latency: 1 cycle

module compress_unit (
    input  clk,
    input  [11:0] x,
    input  [3:0]  d,
    output reg [10:0] y
);
    reg [39:0] t;
    reg [10:0] yc;

    always @(*) begin
        t = 40'd0; yc = 11'd0;
        case (d)
            4'd1:  begin t = 40'd10079   * {28'd0,x}; yc = t[34:24] + t[23]; yc = yc & 11'h001; end
            4'd4:  begin t = 40'd315     * {28'd0,x}; yc = t[26:16] + t[15]; yc = yc & 11'h00F; end
            4'd5:  begin t = 40'd630     * {28'd0,x}; yc = t[26:16] + t[15]; yc = yc & 11'h01F; end
            4'd10: begin t = 40'd5160669 * {28'd0,x}; yc = t[34:24] + t[23]; yc = yc & 11'h3FF; end
            4'd11: begin t = 40'd10321339* {28'd0,x}; yc = t[34:24] + t[23]; yc = yc & 11'h7FF; end
            default: yc = 11'd0;
        endcase
    end

    always @(posedge clk) y <= yc;
endmodule

// ------ decompress_unit --------------------------------------
// Implements x = ⌈(q / 2^d) · y⌋,  q=3329
// Fully combinational

module decompress_unit (
    input  [10:0] y,
    input  [3:0]  d,
    output reg [11:0] x
);
    localparam [12:0] Q = 13'd3329;
    reg [25:0] num;

    always @(*) begin
        num = Q * {15'b0, y};
        case (d)
            4'd1:  x = (num + 26'd1)    >> 1;
            4'd4:  x = (num + 26'd8)    >> 4;
            4'd5:  x = (num + 26'd16)   >> 5;
            4'd10: x = (num + 26'd512)  >> 10;
            4'd11: x = (num + 26'd1024) >> 11;
            default: x = 12'd0;
        endcase
    end
endmodule

// ------ compress_decompress wrapper --------------------------
// compress=1 → compress path; compress=0 → decompress path
// Registered output (1 cycle latency)

module compress_decompress (
    input  clk, rst,
    input  compress,
    input  [11:0] data_in,
    input  [3:0]  d,
    output reg [11:0] data_out
);
    wire [10:0] comp_out;
    wire [11:0] decomp_out;

    compress_unit   cu  (.clk(clk),.x(data_in),.d(d),.y(comp_out));
    decompress_unit du  (.y(data_in[10:0]),.d(d),.x(decomp_out));

    always @(posedge clk) begin
        if (rst) data_out <= 12'd0;
        else     data_out <= compress ? {1'b0, comp_out} : decomp_out;
    end
endmodule


// ============================================================
//  ENCODE / DECODE UNIT  (Section III-E-2)
//  Supported coefficient widths: 1, 4, 5, 10, 11 bits
// ============================================================

// ------ encode_unit ------------------------------------------
// 4 coefficients → packed 64-bit word using a 104-bit internal buffer
// Outputs valid_out=1 when a complete 64-bit word is available.

module encode_unit (
    input  clk, rst,
    input  valid_in,
    input  [3:0]  coeff_w,
    input  [10:0] c0, c1, c2, c3,
    output reg        valid_out,
    output reg [63:0] packed_out
);
    reg [103:0] buf_r;
    reg [6:0]   fill;

    always @(posedge clk) begin
        if (rst) begin
            buf_r<=104'b0; fill<=7'd0; valid_out<=1'b0; packed_out<=64'b0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                case (coeff_w)
                    4'd1: begin
                        buf_r[fill+:1]  <= c0[0]; buf_r[fill+1+:1] <= c1[0];
                        buf_r[fill+2+:1]<= c2[0]; buf_r[fill+3+:1] <= c3[0];
                        fill <= fill + 7'd4;
                    end
                    4'd4: begin
                        buf_r[fill+:4]   <= c0[3:0]; buf_r[fill+4+:4]  <= c1[3:0];
                        buf_r[fill+8+:4] <= c2[3:0]; buf_r[fill+12+:4] <= c3[3:0];
                        fill <= fill + 7'd16;
                    end
                    4'd5: begin
                        buf_r[fill+:5]   <= c0[4:0]; buf_r[fill+5+:5]  <= c1[4:0];
                        buf_r[fill+10+:5]<= c2[4:0]; buf_r[fill+15+:5] <= c3[4:0];
                        fill <= fill + 7'd20;
                    end
                    4'd10: begin
                        buf_r[fill+:10]  <= c0[9:0]; buf_r[fill+10+:10]<= c1[9:0];
                        buf_r[fill+20+:10]<=c2[9:0]; buf_r[fill+30+:10]<= c3[9:0];
                        fill <= fill + 7'd40;
                    end
                    4'd11: begin
                        buf_r[fill+:11]  <= c0[10:0]; buf_r[fill+11+:11]<= c1[10:0];
                        buf_r[fill+22+:11]<=c2[10:0]; buf_r[fill+33+:11]<= c3[10:0];
                        fill <= fill + 7'd44;
                    end
                    default: ;
                endcase

                if (fill >= 7'd64) begin
                    packed_out <= buf_r[63:0];
                    buf_r      <= buf_r >> 64;
                    fill       <= fill - 7'd64;
                    valid_out  <= 1'b1;
                end
            end
        end
    end
endmodule

// ------ decode_unit ------------------------------------------
// 64-bit packed word → 4 coefficients, 72-bit internal buffer

module decode_unit (
    input  clk, rst,
    input  valid_in,
    input  [3:0]  coeff_w,
    input  [63:0] packed_in,
    output reg        valid_out,
    output reg [10:0] c0, c1, c2, c3
);
    reg [71:0] buf_r;
    reg [6:0]  fill;

    always @(posedge clk) begin
        if (rst) begin
            buf_r<=72'b0; fill<=7'd0; valid_out<=1'b0;
            c0<=0; c1<=0; c2<=0; c3<=0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                buf_r[fill+:64] <= packed_in;
                fill <= fill + 7'd64;
            end

            if (fill >= {3'b0, coeff_w, 2'b00}) begin  // fill >= 4*coeff_w
                case (coeff_w)
                    4'd1:  begin
                        c0<={10'b0,buf_r[0]}; c1<={10'b0,buf_r[1]};
                        c2<={10'b0,buf_r[2]}; c3<={10'b0,buf_r[3]};
                        buf_r<=buf_r>>4; fill<=fill-7'd4; valid_out<=1'b1;
                    end
                    4'd4:  begin
                        c0<={7'b0,buf_r[3:0]};  c1<={7'b0,buf_r[7:4]};
                        c2<={7'b0,buf_r[11:8]}; c3<={7'b0,buf_r[15:12]};
                        buf_r<=buf_r>>16; fill<=fill-7'd16; valid_out<=1'b1;
                    end
                    4'd5:  begin
                        c0<={6'b0,buf_r[4:0]};   c1<={6'b0,buf_r[9:5]};
                        c2<={6'b0,buf_r[14:10]}; c3<={6'b0,buf_r[19:15]};
                        buf_r<=buf_r>>20; fill<=fill-7'd20; valid_out<=1'b1;
                    end
                    4'd10: begin
                        c0<={1'b0,buf_r[9:0]};   c1<={1'b0,buf_r[19:10]};
                        c2<={1'b0,buf_r[29:20]}; c3<={1'b0,buf_r[39:30]};
                        buf_r<=buf_r>>40; fill<=fill-7'd40; valid_out<=1'b1;
                    end
                    4'd11: begin
                        c0<=buf_r[10:0]; c1<=buf_r[21:11];
                        c2<=buf_r[32:22]; c3<=buf_r[43:33];
                        buf_r<=buf_r>>44; fill<=fill-7'd44; valid_out<=1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
