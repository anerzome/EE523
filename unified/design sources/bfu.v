`timescale 1ns / 1ps
//==============================================================================
// KaLi - Unified Polynomial Arithmetic Unit
//
// unified_add          : 24-bit adder; mode=0 → Dilithium (propagate carry),
//                        mode=1 → Kyber (two independent 12-bit adds)
// unified_sub          : same structure for subtraction
// unified_right_shift  : divide-by-2 for INTT scaling
// unified_multiplier   : flexible 24-bit×24-bit (Algorithm 2 in paper)
// unified_bfu          : complete butterfly unit (Fig. 4 in paper)
//                        Latency: 4 clock cycles
//==============================================================================

//------------------------------------------------------------------------------
// unified_add
//------------------------------------------------------------------------------
module unified_add (
    input  [23:0] a,
    input  [23:0] b,
    input         mode,   // 0=Dilithium, 1=Kyber
    output [23:0] c
);
    wire [11:0] a_lo = a[11:0],  a_hi = a[23:12];
    wire [11:0] b_lo = b[11:0],  b_hi = b[23:12];
    wire carry;
    wire [11:0] c_lo, c_hi;

    assign {carry, c_lo} = a_lo + b_lo;
    // Kyber: independent halves; Dilithium: full 24-bit with carry propagation
    assign c_hi = mode ? (a_hi + b_hi) : (a_hi + b_hi + carry);
    assign c = {c_hi, c_lo};
endmodule

//------------------------------------------------------------------------------
// unified_sub
//------------------------------------------------------------------------------
module unified_sub (
    input  [23:0] a,
    input  [23:0] b,
    input         mode,
    output [23:0] c
);
    wire [11:0] a_lo = a[11:0],  a_hi = a[23:12];
    wire [11:0] b_lo = b[11:0],  b_hi = b[23:12];
    wire borrow;
    wire [11:0] c_lo, c_hi;

    assign {borrow, c_lo} = a_lo - b_lo;
    assign c_hi = mode ? (a_hi - b_hi) : (a_hi - b_hi - borrow);
    assign c = {c_hi, c_lo};
endmodule

//------------------------------------------------------------------------------
// unified_right_shift  (for INTT N^{-1} scaling, each butterfly divides by 2)
//------------------------------------------------------------------------------
module unified_right_shift (
    input  [23:0] a,
    input         mode,
    output [23:0] c
);
    // Kyber: shift each 12-bit lane independently; Dilithium: 24-bit shift
    assign c = mode ? {a[23:12] >> 1, a[11:0] >> 1} : (a >> 1);
endmodule

//------------------------------------------------------------------------------
// unified_multiplier   (Algorithm 2 in paper)
//   sel=0 (Dilithium): one 23-bit×23-bit → 46-bit product in d[45:0]
//   sel=1 (Kyber)    : two 12-bit×12-bit → products packed in d[47:24] / d[23:0]
//------------------------------------------------------------------------------
module unified_multiplier (
    input  signed [23:0] a,
    input  signed [23:0] b,
    input                sel,
    output signed [47:0] d
);
    wire signed [11:0] a_lo = a[11:0];
    wire signed [11:0] a_hi = a[23:12];
    wire signed [11:0] b_lo = b[11:0];
    wire signed [11:0] b_hi = b[23:12];

    // Sign-extend to 24 bits depending on mode
    wire signed [23:0] a_hi_ext = sel ? {{12{a_hi[11]}}, a_hi} : {{12{a[23]}}, a_hi};
    wire signed [23:0] a_lo_ext = sel ? {{12{a_lo[11]}}, a_lo} : {{12{a[23]}}, a_lo};
    wire signed [23:0] b_hi_ext = sel ? {{12{b_hi[11]}}, b_hi} : {{12{b[23]}}, b_hi};

    // d0 = sel ? b_hi : b
    wire signed [23:0] d0 = sel ? b_hi_ext : b;
    wire signed [47:0] m0 = d0 * a_hi_ext;

    // m1 shift: 24 for Kyber (packed), 12 for Dilithium
    wire signed [47:0] m1 = sel ? (m0 <<< 24) : (m0 <<< 12);

    // d1 = sel ? b_lo : b
    wire signed [23:0] d1 = sel ? {{12{b_lo[11]}}, b_lo} : b;
    wire signed [47:0] m2 = d1 * a_lo_ext;

    assign d = m2 + m1;
endmodule

//------------------------------------------------------------------------------
// unified_bfu  (Fig. 4 in paper, Algorithm 1 steps 7-10)
//
//  Forward NTT (inv=0):
//    y0 = (xj  + w*xjt) mod q   [standard CT butterfly]
//    y1 = (xj  - w*xjt) mod q
//
//  Inverse NTT (inv=1):
//    y0 = (xj  + xjt) / 2  (GS butterfly without twiddle on sum)
//    y1 = (w * (xj - xjt)) / 2  (twiddle applied to difference)
//
//  mode=0 → Dilithium (one 23-bit operation)
//  mode=1 → Kyber     (two packed 12-bit operations)
//
//  Pipeline latency: 4 clock cycles
//    stage 1: add/sub inputs  (combinational, registered out)
//    stage 2: multiply        (combinational, registered out)
//    stage 3: mod reduction   (2-cycle inside mod_red → stage 3+4)
//    stage 4: final add/sub or shift
//
//  Note: The BFU exposes d_ip / k_ip1 / k_ip2 wires internally to mod_red.
//------------------------------------------------------------------------------
module unified_bfu (
    input  clk,
    input  rst,

    input  [23:0] xj,     // upper coefficient
    input  [23:0] xjt,    // lower coefficient  (xj+t in CT notation)
    input  [23:0] w,      // twiddle factor

    input  mode,          // 0=Dilithium, 1=Kyber
    input  inv,           // 0=NTT forward, 1=INTT inverse

    output reg [23:0] y0,
    output reg [23:0] y1
);

// ========================= STAGE 1 =========================
// Compute add and sub of (xj, xjt); also latch inputs for pipeline

wire [23:0] add_s1, sub_s1;

unified_add  add_u  (.a(xj), .b(xjt), .mode(mode), .c(add_s1));
unified_sub  sub_u  (.a(xj), .b(xjt), .mode(mode), .c(sub_s1));

reg [23:0] xj_r1, xjt_r1, add_r1, sub_r1, w_r1;
reg mode_r1, inv_r1;

always @(posedge clk) begin
    xj_r1   <= xj;
    xjt_r1  <= xjt;
    add_r1  <= add_s1;
    sub_r1  <= sub_s1;
    w_r1    <= w;
    mode_r1 <= mode;
    inv_r1  <= inv;
end

// Pipeline xj through to stage 3 for final output formation
reg [23:0] xj_r2, xj_r3;
always @(posedge clk) begin
    xj_r2 <= xj_r1;
    xj_r3 <= xj_r2;
end

// ========================= STAGE 2 =========================
// Multiply: forward → w * xjt;  inverse → w * (xj - xjt)

wire [23:0] mul_in = inv_r1 ? sub_r1 : xjt_r1;

wire signed [47:0] mul_out;
unified_multiplier mul_u (
    .a(w_r1),
    .b(mul_in),
    .sel(mode_r1),
    .d(mul_out)
);

reg signed [47:0] mul_r2;
reg [23:0] add_r2;
reg mode_r2, inv_r2;

always @(posedge clk) begin
    mul_r2  <= mul_out;
    add_r2  <= add_r1;
    mode_r2 <= mode_r1;
    inv_r2  <= inv_r1;
end

// ========================= STAGE 3+4 =========================
// Modular reduction (2-cycle pipeline inside mod_red)
//
// For Dilithium: absolute-value the 46-bit product before feeding mod_red,
//   then negate the output if original was negative.
// For Kyber: split packed 48-bit → two 24-bit products, same sign logic.

// --- sign extraction and absolute-value formation ---
wire neg_lo = mul_r2[23];   // sign of Kyber low lane (bit 23)
wire neg_hi = mul_r2[47];   // sign of Kyber high lane (bit 47) / Dilithium sign

wire [23:0] abs_lo = neg_lo ? (~mul_r2[23:0]  + 1) : mul_r2[23:0];
wire [23:0] abs_hi = neg_hi ? (~mul_r2[47:24] + 1) : mul_r2[47:24];
wire [45:0] abs_dil= neg_hi ? (~mul_r2[45:0]  + 1) : mul_r2[45:0];

wire [29:0] modred_out;

mod_red mr (
    .clk    (clk),
    .rst    (rst),
    .dk     (mode_r2),
    .k_ip1  (abs_lo),
    .k_ip2  (abs_hi),
    .d_ip   (abs_dil),
    .c      (modred_out)
);

// Pipeline sign and mode through the 2-cycle mod_red delay
reg neg_lo_r3, neg_hi_r3, mode_r3, inv_r3, neg_lo_r4, neg_hi_r4, mode_r4, inv_r4;
reg [23:0] add_r3, add_r4;

always @(posedge clk) begin
    neg_lo_r3 <= neg_lo;
    neg_hi_r3 <= neg_hi;
    mode_r3   <= mode_r2;
    inv_r3    <= inv_r2;
    add_r3    <= add_r2;

    neg_lo_r4 <= neg_lo_r3;
    neg_hi_r4 <= neg_hi_r3;
    mode_r4   <= mode_r3;
    inv_r4    <= inv_r3;
    add_r4    <= add_r3;
end

// --- Post-reduction sign correction ---
localparam [11:0] Q_K = 12'd3329;
localparam [22:0] Q_D = 23'd8380417;

wire [11:0] red_lo = modred_out[14:0];   // Kyber low lane from selector output
wire [11:0] red_hi = modred_out[29:15];  // Kyber high lane
wire [22:0] red_d  = modred_out[22:0];   // Dilithium

wire [11:0] modredout_k_lo = neg_lo_r4 ? (Q_K - red_lo) : red_lo;
wire [11:0] modredout_k_hi = neg_hi_r4 ? (Q_K - red_hi) : red_hi;
wire [22:0] modredout_d    = neg_hi_r4 ? (Q_D - red_d)  : red_d;

wire [23:0] modredout = mode_r4 ?
    {modredout_k_hi, modredout_k_lo} :
    {1'b0, modredout_d};

// ========================= OUTPUT STAGE =========================
// Forward NTT:   y0 = xj_r3 + modredout,  y1 = xj_r3 - modredout
// Inverse NTT:   y0 = (add_r4) >> 1,       y1 = modredout >> 1

wire [23:0] y0_fwd, y1_fwd;
unified_add fwd_add (.a(xj_r3), .b(modredout), .mode(mode_r4), .c(y0_fwd));
unified_sub fwd_sub (.a(xj_r3), .b(modredout), .mode(mode_r4), .c(y1_fwd));

wire [23:0] y0_inv, y1_inv;
unified_right_shift rs0 (.a(add_r4),   .mode(mode_r4), .c(y0_inv));
unified_right_shift rs1 (.a(modredout),.mode(mode_r4), .c(y1_inv));

always @(posedge clk) begin
    if (inv_r4) begin
        y0 <= y0_inv;
        y1 <= y1_inv;
    end else begin
        y0 <= y0_fwd;
        y1 <= y1_fwd;
    end
end

endmodule
