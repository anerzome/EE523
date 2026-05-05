`timescale 1ns / 1ps

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
