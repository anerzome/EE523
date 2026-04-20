`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2026 01:30:26
// Design Name: 
// Module Name: selector
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


module selector(
    input [29:0] x,
    input dk,clk,
    output reg [29:0] y
    );
    wire [29:0] qk,qd,qks;
    reg [29:0] q;
    reg [29:0] temp1,temp2,temp3,temp4,temp5,temp6,temp7,temp8,temp9,temp10,temp13,temp14;
    reg [14:0] temp11,temp12,temp21,temp22,temp31,temp32,temp41,temp42,temp51;
    reg [14:0] y1,y2;
    assign qk = 30'b000110100000001000110100000001; //Two 3329 concatenated
    assign qd = 30'b000000011111111110000000000001; //8380417
    assign qks = 30'b000000000000000000110100000001;
    always @(x,dk,clk) begin
        if (dk==1'b1) q = qk;
        else q = qd;
        if (dk==1'b1) begin
            temp4 = x;
            temp41 = temp4[14:0];
            temp51 = temp4[29:15];
            temp42 = temp51 - 15'd1;
            temp11 = temp41 + qks;
            temp12 = temp42 + qks;
            temp21 = temp41 - qks;
            temp22 = temp42 - qks;
            temp31 = temp41 - qks - qks;
            temp32 = temp42 - qks - qks;
            temp5 = qks-temp11;
            temp6 = qks-temp21;
            temp7 = qks-temp31;
            temp8 = qks-temp41;
            temp9 = qks-temp12;
            temp10 = qks-temp22;
            temp13 = qks-temp32;
            temp14 = qks-temp42;
            if (temp8[29]==1'b0) y1 = temp41; 
            else if (temp6[29]==1'b0) y1 = temp21;
            else if (temp7[29]==1'b0) y1 = temp31;
            else if (temp5[29]==1'b0) y1 = temp11;
            else y1 = (15'b0);
            if (temp14[29]==1'b0) y2 = temp42; 
            else if (temp10[29]==1'b0) y2 = temp22;
            else if (temp13[29]==1'b0) y2 = temp32;
            else if (temp9[29]==1'b0) y2 = temp12;
            else y2 = (15'b0);
            y[29:15] = y2;
            y[14:0] = y1;
        end
        else begin
            temp4[25:0] = x;
            temp4[29:26] = 4'b0000;
            temp1 <= temp4 + q;
            temp2 <= temp4 - q;
            temp3 <= (temp4 - q) - q;
            temp1[29:26] = 4'b0000;
            temp2[29:26] = 4'b0000;
            temp3[29:26] = 4'b0000;
            temp5 = q-temp1;
            temp6 = q-temp2;
            temp7 = q-temp3;
            temp8 = q-temp4;
            if (temp8[29]==1'b0) y = temp4; 
            else if (temp6[29]==1'b0) y = temp2;
            else if (temp7[29]==1'b0) y = temp3;
            else if (temp5[29]==1'b0) y = temp1;
            else y = (30'b0);
        end   
    end
endmodule
