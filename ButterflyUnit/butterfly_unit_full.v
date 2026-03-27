module unified_bfu (
    input clk,
    input rst,

    input [23:0] xj,
    input [23:0] xjt,
    input [23:0] w,

    input mode,     // 0 = Dilithium, 1 = Kyber
    input inv,      // 0 = NTT, 1 = INTT

    output reg [23:0] y0,
    output reg [23:0] y1
);

// Stage 1: Add/Sub

wire [23:0] add_out_s1;
wire [23:0] sub_out_s1;

unified_add add_unit (
    .a(xj),
    .b(xjt),
    .mode(mode),
    .c(add_out_s1)
);

unified_sub sub_unit (
    .a(xj),
    .b(xjt),
    .mode(mode),
    .c(sub_out_s1)
);

// Pipelining xj
reg [23:0] xj_s1_r, xj_s2_r, xj_s3_r;

always @(posedge clk) begin
    xj_s1_r <= xj;
    xj_s2_r <= xj_s1_r;
    xj_s3_r <= xj_s2_r;
end

// pipeline regs
reg [23:0] xjt_s1_r, add_s1_r, sub_s1_r, w_s1_r;
reg mode_s1, inv_s1;

always @(posedge clk) begin
    xjt_s1_r <= xjt;
    add_s1_r <= add_out_s1;
    sub_s1_r <= sub_out_s1;
    w_s1_r   <= w;
    mode_s1  <= mode;
    inv_s1   <= inv;
end

// Stage 2: Multiply

wire [47:0] mul_out_s2;

wire [23:0] mul_in_s1;

assign mul_in_s1 = inv_s1 ? sub_s1_r : xjt_s1_r;


unified_multiplier mul_inst (
    .a(w_s1_r),
    .b(mul_in_s1),
    .sel(mode_s1),
    .d(mul_out_s2)
);

// pipeline regs
reg [47:0] mul_s2_r;
reg [23:0] add_s2_r;
reg mode_s2, inv_s2;

always @(posedge clk) begin
    mul_s2_r <= mul_out_s2;
    add_s2_r <= add_s1_r;
    mode_s2  <= mode_s1;
    inv_s2   <= inv_s1;
end

// Stage 3: Modular Reduction

wire [29:0] mod_s3_pre;
wire [23:0] mod_s3 = mode ? {mod_s3_pre[26:15],mod_s3_pre[11:0]} : mod_s3_pre;

wire [47:0] modredin_pre_low = mul_s2_r[23] ? ~mul_s2_r[23:0]+1 : mul_s2_r[23:0];
wire [47:0] modredin_pre_hi = mul_s2_r[47] ? ~mul_s2_r[47:24]+1 : mul_s2_r[47:24];
wire [47:0] modredin_pre = mul_s2_r[47] ? ~mul_s2_r+1 : mul_s2_r;

mod_red modred (
    .k_ip1(modredin_pre_low),
    .k_ip2(modredin_pre_hi),
    .d_ip(modredin_pre),
    .clk(clk),
    .rst(rst),
    .dk(mode),
    .c(mod_s3_pre)
);

wire [11:0] modredout_post_low = mul_s2_r[23] ? (23'd3329-mod_s3[11:0]) : mod_s3[11:0];
wire [11:0] modredout_post_hi = mul_s2_r[47] ? (23'd3329-mod_s3[23:12]) : mod_s3[23:12];
wire [23:0] modredout_post = mul_s2_r[47] ? (23'd8380417-mod_s3) : mod_s3;
                                    
wire [23:0] modredout = mode ? {modredout_post_hi,modredout_post_low} : modredout_post;

// pipeline regs
reg signed [23:0] mod_s3_r, add_s3_r;
reg mode_s3, inv_s3;

always @(posedge clk) begin
    mod_s3_r <= modredout;
    add_s3_r <= add_s2_r;
    mode_s3  <= mode_s2;
    inv_s3   <= inv_s2;
end

wire [23:0] y0_fwd;
wire [23:0] y1_fwd;

unified_add add_unit1 (
    .a(xj_s3_r),
    .b(mod_s3_r),
    .mode(mode),
    .c(y0_fwd)
);

unified_sub sub_unit1 (
    .a(xj_s3_r),
    .b(mod_s3_r),
    .mode(mode),
    .c(y1_fwd)
);


wire [23:0] y0_inv;
wire [23:0] y1_inv;

unified_right_shift y0_rightshift (.a(add_s3_r),.mode(mode),.c(y0_inv));
unified_right_shift y1_rightshift (.a(mod_s3_r),.mode(mode),.c(y1_inv));

always @(posedge clk) begin
    if (inv_s3) begin
        y0 <= y0_inv;
        y1 <= y1_inv;
    end else begin
        y0 <= y0_fwd;
        y1 <= y1_fwd;
    end
end

wire [11:0] y0low = y0[11:0];
wire [11:0] y0high = y0[23:12];
wire [11:0] y1low = y1[11:0];
wire [11:0] y1high = y1[23:12];

endmodule
