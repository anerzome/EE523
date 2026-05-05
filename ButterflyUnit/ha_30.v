`timescale 1ns / 1ps

module ha_30(
    input [29:0] x,y,z,
    output [29:0] s,c
    );
    genvar i;
    generate
        for (i=0; i<30; i=i+1) begin
            ha u0 (.a(x[i]),.b(y[i]),.s(s[i]),.c(c[i]));
        end
    endgenerate
endmodule
