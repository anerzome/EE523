`timescale 1ns / 1ps

module fa_30(
    input [29:0] x,y,z,
    output [29:0] s,c
    );
    genvar i;
    generate
        for (i=0; i<30; i=i+1) begin
            fa u0 (.x(x[i]),.y(y[i]),.z(z[i]),.s(s[i]),.c(c[i]));
        end
    endgenerate
endmodule
