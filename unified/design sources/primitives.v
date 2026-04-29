`timescale 1ns / 1ps
//==============================================================================
// KaLi - Primitives: fa, ha, fa_30, ha_30
// Full adder and half adder, scalar and 30-bit vector versions
//==============================================================================

module fa (
    input  x, y, z,
    output s, c
);
    assign s = x ^ y ^ z;
    assign c = (x & y) | (y & z) | (z & x);
endmodule

//------------------------------------------------------------------------------

module ha (
    input  a, b,
    output s, c
);
    assign s = a ^ b;
    assign c = a & b;
endmodule

//------------------------------------------------------------------------------

module fa_30 (
    input  [29:0] x, y, z,
    output [29:0] s, c
);
    genvar i;
    generate
        for (i = 0; i < 30; i = i + 1) begin : FA_LOOP
            fa u0 (.x(x[i]), .y(y[i]), .z(z[i]), .s(s[i]), .c(c[i]));
        end
    endgenerate
endmodule

//------------------------------------------------------------------------------
// ha_30: 30-bit half-adder array (z port kept for structural symmetry with fa_30)

module ha_30 (
    input  [29:0] x, y, z,
    output [29:0] s, c
);
    genvar i;
    generate
        for (i = 0; i < 30; i = i + 1) begin : HA_LOOP
            ha u0 (.a(x[i]), .b(y[i]), .s(s[i]), .c(c[i]));
        end
    endgenerate
    // z is unused in half-adder; suppress lint warning
    // synthesis translate_off
    wire _unused = |z;
    // synthesis translate_on
endmodule
