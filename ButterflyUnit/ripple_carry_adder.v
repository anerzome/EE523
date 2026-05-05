`timescale 1ns / 1ps

module ripple_carry_adder(
    input [29:0] x,y,
    output [29:0] z
    );
    assign z = x+y;
endmodule
