`timescale 1ns/1ps

module tb_unified_bfu;

reg clk, rst;

reg [23:0] xj, xjt, w;
reg mode, inv;

wire [23:0] y0, y1;

// DUT
unified_bfu dut (
    .clk(clk),
    .rst(rst),
    .xj(xj),
    .xjt(xjt),
    .w(w),
    .mode(mode),
    .inv(inv),
    .y0(y0),
    .y1(y1)
);

// File handles
integer fin, fexp;
integer r;

// Expected outputs
reg [23:0] y0_exp, y1_exp;

integer cycle = 0;
integer errors = 0;

//
// Clock
//
always #5 clk = ~clk;

//
// Test
//
initial begin
    clk = 0;
    rst = 1;

    #20;
    rst = 0;

    fin  = $fopen("bfu_input.txt", "r");
    fexp = $fopen("bfu_expected.txt", "r");

    if (fin == 0 || fexp == 0) begin
        $display("ERROR: Could not open files");
        $finish;
    end

    // Wait a bit
    #10;

    while (!$feof(fin)) begin

        // Read input
        r = $fscanf(fin, "%d %d %d %d %d\n", xj, xjt, w, mode, inv);

        // Read expected output
        r = $fscanf(fexp, "%d %d\n", y0_exp, y1_exp);

        #100;  // apply inputs

        // Wait 1 cycle (since you're ignoring pipeline in MATLAB)
        #100;

        // Compare
        if (y0 !== y0_exp || y1 !== y1_exp) begin
            $display("Mismatch at cycle %0d", cycle);
            $display("Input: xj=%d xjt=%d w=%d mode=%d inv=%d", xj, xjt, w, mode, inv);
            $display("Expected: y0=%d y1=%d", y0_exp, y1_exp);
            $display("Got     : y0=%d y1=%d", y0, y1);
            errors = errors + 1;
        end

        cycle = cycle + 1;
    end

    $display("Test completed. Errors = %0d", errors);
    $finish;
end

endmodule