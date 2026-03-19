`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2026 16:01:55
// Design Name: 
// Module Name: reg_30b
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


module reg_30b(
    input [29:0] ip,
    input clk, rst,
    output reg [29:0] op
    );
    always @(posedge clk) begin
    if (rst) op<=29'b0;
    else  op<=ip;
    end
endmodule
