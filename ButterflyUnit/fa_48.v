`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2026 00:28:37
// Design Name: 
// Module Name: fa_48
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


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
