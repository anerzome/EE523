`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.02.2026 16:44:18
// Design Name: 
// Module Name: mux
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


module mux(
    input [29:0] a1,a2,a3,a4,a5,a6,a7,a8,b1,b2,b3,b4,b5,b6,b7,b8,
    input s,
    output reg [29:0] o1,o2,o3,o4,o5,o6,o7,o8
    );
    always @* begin
        if (s==1'b0) begin 
        o1<=a1;
        o2<=a2;
        o3<=a3;
        o4<=a4;
        o5<=a5;
        o6<=a6;
        o7<=a7;
        o8<=a8;
        end
        else begin
        o1<=b1;
        o2<=b2;
        o3<=b3;
        o4<=b4;
        o5<=b5;
        o6<=b6;
        o7<=b7;
        o8<=b8;
        end
    end
endmodule
