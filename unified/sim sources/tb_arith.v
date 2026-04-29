`timescale 1ns / 1ps
//==============================================================================
// KaLi - Testbench: Unified Arithmetic Primitives
//   Tests unified_add, unified_sub, unified_right_shift, unified_multiplier
//   All combinational (no clock needed), but we use a clock for $monitor style.
//==============================================================================

module tb_arith;

    localparam QD = 8380417;
    localparam QK = 3329;

    integer pass, fail;

    // ---- unified_add ----
    reg  [23:0] add_a, add_b;
    reg         add_mode;
    wire [23:0] add_c;
    unified_add uadd (.a(add_a), .b(add_b), .mode(add_mode), .c(add_c));

    // ---- unified_sub ----
    reg  [23:0] sub_a, sub_b;
    reg         sub_mode;
    wire [23:0] sub_c;
    unified_sub usub (.a(sub_a), .b(sub_b), .mode(sub_mode), .c(sub_c));

    // ---- unified_right_shift ----
    reg  [23:0] rs_a;
    reg         rs_mode;
    wire [23:0] rs_c;
    unified_right_shift urs (.a(rs_a), .mode(rs_mode), .c(rs_c));

    // ---- unified_multiplier ----
    reg  signed [23:0] mul_a, mul_b;
    reg                mul_sel;
    wire signed [47:0] mul_d;
    unified_multiplier umul (.a(mul_a), .b(mul_b), .sel(mul_sel), .d(mul_d));

    // ---- helpers ----
    task chk_add_dil;
        input [22:0] a, b;
        reg [23:0] exp;
        begin
            add_a = {1'b0, a}; add_b = {1'b0, b}; add_mode = 0;
            #1;
            exp = {1'b0, a} + {1'b0, b};
            if (add_c === exp) begin pass=pass+1;
                $display("[PASS] ADD_DIL %0d+%0d=%0d", a, b, add_c);
            end else begin fail=fail+1;
                $display("[FAIL] ADD_DIL %0d+%0d got=%0d exp=%0d <<<", a, b, add_c, exp);
            end
        end
    endtask

    task chk_add_kyo;
        input [11:0] a_lo, a_hi, b_lo, b_hi;
        reg [23:0] exp;
        begin
            add_a = {a_hi, a_lo}; add_b = {b_hi, b_lo}; add_mode = 1;
            #1;
            exp = {a_hi + b_hi, a_lo + b_lo};
            if (add_c === exp) begin pass=pass+1;
                $display("[PASS] ADD_KYO hi:%0d+%0d lo:%0d+%0d=%0d|%0d",
                    a_hi,b_hi,a_lo,b_lo, add_c[23:12], add_c[11:0]);
            end else begin fail=fail+1;
                $display("[FAIL] ADD_KYO got=%h exp=%h <<<", add_c, exp);
            end
        end
    endtask

    task chk_sub_dil;
        input [22:0] a, b;
        reg signed [23:0] exp;
        begin
            sub_a = {1'b0, a}; sub_b = {1'b0, b}; sub_mode = 0;
            #1;
            exp = {1'b0, a} - {1'b0, b};
            if (sub_c === exp) begin pass=pass+1;
                $display("[PASS] SUB_DIL %0d-%0d=%0d", a, b, sub_c);
            end else begin fail=fail+1;
                $display("[FAIL] SUB_DIL %0d-%0d got=%0d exp=%0d <<<", a, b, sub_c, exp);
            end
        end
    endtask

    task chk_rs_dil;
        input [22:0] a;
        reg [23:0] exp;
        begin
            rs_a = {1'b0, a}; rs_mode = 0; #1;
            exp = {1'b0, a} >> 1;
            if (rs_c === exp) begin pass=pass+1;
                $display("[PASS] RS_DIL  %0d>>1=%0d", a, rs_c);
            end else begin fail=fail+1;
                $display("[FAIL] RS_DIL  %0d>>1 got=%0d exp=%0d <<<", a, rs_c, exp);
            end
        end
    endtask

    task chk_rs_kyo;
        input [11:0] lo, hi;
        reg [23:0] exp;
        begin
            rs_a = {hi, lo}; rs_mode = 1; #1;
            exp  = {hi >> 1, lo >> 1};
            if (rs_c === exp) begin pass=pass+1;
                $display("[PASS] RS_KYO  hi:%0d>>1=%0d lo:%0d>>1=%0d",
                    hi, rs_c[23:12], lo, rs_c[11:0]);
            end else begin fail=fail+1;
                $display("[FAIL] RS_KYO  got=%h exp=%h <<<", rs_c, exp);
            end
        end
    endtask

    task chk_mul_dil;
        input signed [22:0] a, b;
        reg signed [47:0] exp;
        begin
            mul_a = {{1{a[22]}}, a}; mul_b = {{1{b[22]}}, b}; mul_sel = 0; #1;
            exp = mul_a * mul_b;
            if (mul_d === exp) begin pass=pass+1;
                $display("[PASS] MUL_DIL %0d*%0d=%0d", a, b, mul_d);
            end else begin fail=fail+1;
                $display("[FAIL] MUL_DIL %0d*%0d got=%0d exp=%0d <<<", a, b, mul_d, exp);
            end
        end
    endtask

    task chk_mul_kyo;
        input signed [11:0] a_lo, a_hi, b_lo, b_hi;
        reg signed [23:0] exp_lo, exp_hi;
        begin
            mul_a = {a_hi, a_lo}; mul_b = {b_hi, b_lo}; mul_sel = 1; #1;
            exp_lo = a_lo * b_lo;
            exp_hi = a_hi * b_hi;
            if ((mul_d[23:0] === exp_lo) && (mul_d[47:24] === exp_hi)) begin
                pass=pass+1;
                $display("[PASS] MUL_KYO lo:%0d*%0d=%0d hi:%0d*%0d=%0d",
                    a_lo,b_lo,mul_d[23:0], a_hi,b_hi,mul_d[47:24]);
            end else begin fail=fail+1;
                $display("[FAIL] MUL_KYO lo:got=%0d exp=%0d hi:got=%0d exp=%0d <<<",
                    mul_d[23:0],exp_lo, mul_d[47:24],exp_hi);
            end
        end
    endtask

    initial begin
        pass = 0; fail = 0;

        $display("\n=== unified_add ===");
        chk_add_dil(23'd0,       23'd0);
        chk_add_dil(23'd135,     23'd848);
        chk_add_dil(23'd8380416, 23'd1);       // wraps in 24-bit arithmetic
        chk_add_dil(23'd4000000, 23'd4000000);
        chk_add_kyo(12'd135,12'd457, 12'd848,12'd1048);
        chk_add_kyo(12'd0,  12'd0,   12'd0,  12'd0);
        chk_add_kyo(12'd3328,12'd3328, 12'd1,12'd1);

        $display("\n=== unified_sub ===");
        chk_sub_dil(23'd848, 23'd135);
        chk_sub_dil(23'd0,   23'd1);       // underflow (correct: wraps)
        chk_sub_dil(23'd8380416, 23'd8380416);

        $display("\n=== unified_right_shift ===");
        chk_rs_dil(23'd848);
        chk_rs_dil(23'd0);
        chk_rs_dil(23'd8380417);
        chk_rs_kyo(12'd848,  12'd135);
        chk_rs_kyo(12'd1,    12'd1);
        chk_rs_kyo(12'd3328, 12'd3328);

        $display("\n=== unified_multiplier ===");
        chk_mul_dil(23'd135,  23'd848);
        chk_mul_dil(23'd23102, 23'd848);
        chk_mul_dil(23'd0,    23'd99999);
        chk_mul_dil(23'd8380416, 23'd2);
        chk_mul_kyo(12'd5,  12'd5,   12'd135, 12'd457);
        chk_mul_kyo(12'd0,  12'd0,   12'd0,   12'd0);
        chk_mul_kyo(12'd3328, 12'd3328, 12'd1, 12'd1);
        chk_mul_kyo(12'd100, 12'd200, 12'd300, 12'd400);

        $display("\n==================================================");
        $display("ARITH RESULTS: PASS=%0d  FAIL=%0d", pass, fail);
        if (fail==0) $display("ALL TESTS PASSED");
        else         $display("*** FAILURES DETECTED ***");
        $display("==================================================\n");
        $finish;
    end

endmodule
