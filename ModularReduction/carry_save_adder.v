`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2026 16:40:44
// Design Name: 
// Module Name: carry_save_adder
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


module carry_save_adder(
    input [29:0] ip1,ip2,ip3,ip4,ip5,ip6,ip7,ip8,
    output [29:0] c,s
    );
    wire [29:0] s10,s11,s12,s20,s21,s30;
    wire [29:0] c10,c11,c12,c20,c21,c30;
    wire [29:0] ip10,ip11,ip12;
    wire [29:0] ip20,ip21;
    wire [29:0] ip30,ip40;
    fa_30 u0(.x(ip1),.y(ip2),.z(ip3),.s(s10),.c(c10));
    fa_30 u1(.x(ip4),.y(ip5),.z(ip6),.s(s11),.c(c11));
    ha_30 u2(.x(ip7),.y(ip8),.s(s12),.c(c12));
    assign ip10 = c10 << 1;
    assign ip11 = c11 << 1;
    assign ip12 = c12 << 1;
    fa_30 u3(.x(ip10),.y(ip11),.z(ip12),.s(s20),.c(c20));
    fa_30 u4(.x(s10),.y(s11),.z(s12),.s(s21),.c(c21));
    assign ip20 = c20 << 1;
    assign ip21 = c21 << 1;
    fa_30 u5(.x(ip20),.y(ip21),.z(s20),.s(s30),.c(c30));
    assign ip30 = c30 << 1;
    fa_30 u6(.x(ip30),.y(s30),.z(s21),.s(s),.c(ip40));
    assign c = ip40 << 1;
    
endmodule
