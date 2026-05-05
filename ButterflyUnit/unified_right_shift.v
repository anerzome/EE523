`timescale 1ns / 1ps

module unified_right_shift(
    input [23:0] a,
    input mode,
    output [23:0] c
    );
    
assign c = mode ? {a[23:12]>>>1, a[11:0]>>>1} : a>>1; 
endmodule
