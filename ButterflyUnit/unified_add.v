module unified_add (
    input  [23:0] a,
    input  [23:0] b,
    input         mode,     // 0 = Dilithium, 1 = Kyber
    output [23:0] c
);

wire [11:0] a_lo = a[11:0];
wire [11:0] a_hi = a[23:12];
wire [11:0] b_lo = b[11:0];
wire [11:0] b_hi = b[23:12];

wire [11:0] c_lo, c_hi;
wire carry;

// lower 12 bit
assign {carry, c_lo} = (a_lo + b_lo);

// upper 12 bit
assign c_hi = mode ? (a_hi + b_hi) : (a_hi + b_hi + carry);

assign c = {c_hi, c_lo};

endmodule
