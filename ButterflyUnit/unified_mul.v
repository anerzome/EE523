module unified_multiplier (
    input  signed [23:0] a,
    input  signed [23:0] b,
    input         sel,      // 0 = Dilithium, 1 = Kyber
    output signed [47:0] d
);

// split inputs
wire signed [11:0] a_lo = a[11:0];
wire signed [11:0] a_hi = a[23:12];
wire signed [11:0] b_lo = b[11:0];
wire signed [11:0] b_hi = b[23:12];

// extend to 24 bits
wire signed [23:0] a_hi_ext = sel ? {{12{a_hi[11]}}, a_hi} : {{12{a[23]}}, a_hi};
wire signed [23:0] a_lo_ext = sel ? {{12{a_lo[11]}}, a_lo} : {{12{a[23]}}, a_lo};
wire signed [23:0] b_hi_ext = sel ? {{12{b_hi[11]}}, b_hi} : {{12{b[23]}}, b_hi};
wire signed [23:0] b_lo_ext = sel ? {{12{b_lo[11]}}, b_lo} : {{12{b[23]}}, b_lo};

// d0 selection
wire signed [23:0] d0 = sel ? b_hi_ext : b;

// m0 
wire signed [47:0] m0 = d0 * a_hi_ext;

// shift 
wire signed [47:0] m1 = sel ? (m0 <<< 24) : (m0 <<< 12);

// d1 
wire signed [23:0] d1 = sel ? b_lo_ext : b;

// m2 
wire signed [47:0] m2 = d1 * a_lo_ext;

// final 
assign d = m2 + m1;

endmodule