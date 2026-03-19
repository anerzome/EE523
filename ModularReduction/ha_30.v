`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2026 00:47:12
// Design Name: 
// Module Name: ha_30
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
