`timescale 1ns / 1ps

module bfu_tb;

reg clk;
reg rst;

reg [23:0] xj;
reg [23:0] xjt;
reg [23:0] w;
reg mode;
reg inv;

unified_bfu uut(
    .clk(clk),
    .rst(rst),
    .xj(xj),
    .xjt(xjt),
    .w(w),
    .mode(mode),
    .inv(inv)
    );

initial begin
    clk = 0;
    rst = 0;
    
    xj = 24'd135;
    xjt = 24'd848;
    w = 24'd23102;
    mode = 1'b0;
    inv = 1'b0;
    
    #200;
    
    xj = {12'd135,12'd457};
    xjt = {12'd848,12'd1048};
    w = {12'd5,12'd5};
    mode = 1'b1;
    inv = 1'b0;
    
    #200
    
    xj = 24'd135;
    xjt = 24'd848;
    w = 24'd23102;
    mode = 1'b0;
    inv = 1'b1;
    
    #200;
    
    xj = {12'd135,12'd457};
    xjt = {12'd848,12'd1048};
    w = {12'd5,12'd5};
    mode = 1'b1;
    inv = 1'b1;
    
    #200
    $finish;
end

always begin
    #5 clk = ~clk;
end

endmodule
