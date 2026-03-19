`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2026 02:06:44
// Design Name: 
// Module Name: top_level
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


module top_level(
    input [23:0] k_ip1,k_ip2,
    input [45:0] d_ip,
    input dk,rst,clk,
    output [29:0] c
    );
    wire [29:0] k1,k2,k3,k4,k5,k6,k7,k8,k_op1,k_op2,k_op3,k_op4,k_op5,k_op6,k_op7,k_op8,d_op1,d_op2,d_op3,d_op4,d_op5,d_op6,d_op7,d_op8;
    wire [29:0] add_ip1,add_ip2,add_ip3,add_ip4,add_ip5,add_ip6,add_ip7,add_ip8;
    wire [29:0] sum1,carr1,temp1,temp2;
    wire [25:0] d1,d2,d3,d4,d5,d6;
    kyber_block ku1(.ip(k_ip1),.op1(k1[14:0]),.op2(k2[14:0]),.op3(k3[14:0]),.op4(k4[14:0]),.op5(k5[14:0]),.op6(k6[14:0]),.op7(k7[14:0]),.op8(k8[14:0]));
    kyber_block ku2(.ip(k_ip2),.op1(k1[29:15]),.op2(k2[29:15]),.op3(k3[29:15]),.op4(k4[29:15]),.op5(k5[29:15]),.op6(k6[29:15]),.op7(k7[29:15]),.op8(k8[29:15]));    
    dilithium_block du(.ip(d_ip),.op1(d1),.op2(d2),.op3(d3),.op4(d4),.op5(d5),.op6(d6));
    reg_block_row rk(.ip1(k1),.ip2(k2),.ip3(k3),.ip4(k4),.ip5(k5),.ip6(k6),.ip7(k7),.ip8(k8),.clk(clk),.rst(rst),.op1(k_op1),.op2(k_op2),.op3(k_op3),.op4(k_op4),.op5(k_op5),.op6(k_op6),.op7(k_op7),.op8(k_op8));
    reg_block_row rd(.ip1({4'b0000,d1}),.ip2({4'b0000,d2}),.ip3({4'b0000,d3}),.ip4({4'b0000,d4}),.ip5({4'b0000,d5}),.ip6({4'b0000,d6}),.ip7(30'b0),.ip8(30'b0),.clk(clk),.rst(rst),.op1(d_op1),.op2(d_op2),.op3(d_op3),.op4(d_op4),.op5(d_op5),.op6(d_op6),.op7(d_op7),.op8(d_op8));    
    mux m0(.a1(d_op1),.a2(d_op2),.a3(d_op3),.a4(d_op4),.a5(d_op5),.a6(d_op6),.a7(d_op7),.a8(d_op8),.b1(k_op1),.b2(k_op2),.b3(k_op3),.b4(k_op4),.b5(k_op5),.b6(k_op6),.b7(k_op7),.b8(k_op8),.s(dk),.o1(add_ip1),.o2(add_ip2),.o3(add_ip3),.o4(add_ip4),.o5(add_ip5),.o6(add_ip6),.o7(add_ip7),.o8(add_ip8));
    carry_save_adder add0(.ip1(add_ip1),.ip2(add_ip2),.ip3(add_ip3),.ip4(add_ip4),.ip5(add_ip5),.ip6(add_ip6),.ip7(add_ip7),.ip8(add_ip8),.s(sum1),.c(carr1));
    ripple_carry_adder add1(.x(sum1),.y(carr1),.z(temp1));
    reg_30b rf(.ip(temp1),.clk(clk),.rst(rst),.op(temp2));
    selector s0(.x(temp2),.dk(dk),.y(c),.clk(clk));
endmodule
