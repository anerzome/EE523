`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2026 02:06:00
// Design Name: 
// Module Name: dilithium_block
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


module dilithium_block(
    input [45:0] ip,
    output [25:0] op1,
    output [25:0] op2,
    output [25:0] op3,
    output [25:0] op4,
    output [25:0] op5,
    output [25:0] op6
    );
    wire [45:0] neg_ip;
    assign neg_ip = ~ip;
    assign op1 = {3'b000, ip[22:0]};
    assign op2 = {3'b000, neg_ip[45:23]};
    assign op3 = {3'b000, ip[32:23],neg_ip[45:33]};
    assign op4 = {3'b000, ip[42:33],10'b0,neg_ip[45:43]};
    assign op5 = {11'b0, ip[45:43], 12'b0};
    assign op6 = 26'b11011111111101111111111011;
endmodule
