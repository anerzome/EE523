`timescale 1ns / 1ps

module top_level_tb;

    // Testbench signals
    reg [23:0] k_ip1, k_ip2;
    reg [45:0] d_ip;
    reg dk, rst, clk;
    wire [29:0] c;
    
    // Clock period
    parameter CLK_PERIOD = 10;
    
    // Instantiate the DUT (Device Under Test)
    top_level dut (
        .k_ip1(k_ip1),
        .k_ip2(k_ip2),
        .d_ip(d_ip),
        .dk(dk),
        .rst(rst),
        .clk(clk),
        .c(c)
    );
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst = 0;
        dk = 0;  // Start with Dilithium mode
        k_ip1 = 24'h000000;
        k_ip2 = 24'h000000;
        d_ip = 46'h00000000000;
        
        // Apply reset
        @(negedge clk);
        rst = 1;
        @(negedge clk);
        rst = 0;
        
        // Set Dilithium inputs
        k_ip1 = 24'h000000;  // Kyber inputs (ignored in Dilithium mode)
        k_ip2 = 24'h000000;
        d_ip = 46'd8380418;  // Dilithium input
        dk = 0;
        
        // Wait for pipeline to fill
        repeat(10) @(negedge clk);
        d_ip = 46'd9568312;
        
        repeat(5)
        k_ip1 = 23'd7348;
        k_ip2 = 24'd15483;
        dk = 1;
        
        $display("Time = %0t, c = %h", $time, c);

    end
endmodule
