`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2026 01:37:40
// Design Name: 
// Module Name: kyber_block
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


module kyber_block(
    input [23:0] ip,
    output [14:0] op1,op2,op3,op4,op5,op6,op7,op8
    );
    wire [23:0] neg_ip;
    assign neg_ip = ~ip;
    assign op1 = {3'b000,ip[11:0]};
    assign op2 = {3'b000,ip[13],{2{ip[12]}},neg_ip[19:12]};
    assign op3 = {3'b000,ip[17], ip[13], ip[17], neg_ip[22:18], neg_ip[16:14]};
    assign op4 = {3'b000,ip[19],ip[15],ip[19],neg_ip[23:19],{3{neg_ip[17]}}};
    assign op5 = {3'b000,neg_ip[18],ip[19],neg_ip[23],1'b0,neg_ip[23:20],{3{neg_ip[18]}}};
    assign op6 = {3'b000,neg_ip[16],ip[18],neg_ip[18],3'b000,neg_ip[23:22],neg_ip[19],neg_ip[20],neg_ip[19]};
    assign op7 = {3'b000,neg_ip[15],1'b0,neg_ip[14],4'b0000,neg_ip[23],{2{neg_ip[21]}},neg_ip[20]};
    assign op8 = {12'b110110101010,neg_ip[22],2'b10};
endmodule
