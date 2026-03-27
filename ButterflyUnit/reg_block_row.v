`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.02.2026 12:46:53
// Design Name: 
// Module Name: reg_block_row
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


module reg_block_row(
    input [29:0] ip1,ip2,ip3,ip4,ip5,ip6,ip7,ip8,
    input clk,rst,
    output reg [29:0] op1,op2,op3,op4,op5,op6,op7,op8
    );
    always @(posedge clk) begin
        if (rst) begin
            op1<=30'b0;
            op2<=30'b0;
            op3<=30'b0;
            op4<=30'b0;
            op5<=30'b0;
            op6<=30'b0;
            op7<=30'b0;
            op8<=30'b0;        
        end
        else begin
            op1<=ip1;
            op2<=ip2;
            op3<=ip3;
            op4<=ip4;
            op5<=ip5;
            op6<=ip6;
            op7<=ip7;
            op8<=ip8;
        end
    end
endmodule
