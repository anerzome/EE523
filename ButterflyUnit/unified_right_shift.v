`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2026 02:38:30
// Design Name: 
// Module Name: unified_right_shift
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

module unified_right_shift(
    input [23:0] a,
    input mode,
    output [23:0] c
    );
    
assign c = mode ? {a[23:12]>>1, a[11:0]>>1} : a>>1; 
endmodule
