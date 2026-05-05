`timescale 1ns / 1ps

module fa(
    input x,y,z,
    output s,c
    );
    assign s = (x^y)^z;
    assign c = ((x&y)|(y&z))|(z&x);
endmodule
