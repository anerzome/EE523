`timescale 1ns / 1ps
//==============================================================================
// KaLi - Testbench: unified_bfu (Butterfly Unit)
//
// Tests:
//   1. Dilithium forward NTT butterfly (CT algorithm)
//   2. Dilithium inverse NTT butterfly (GS algorithm)
//   3. Kyber forward NTT butterfly (two packed 12-bit lanes)
//   4. Kyber inverse NTT butterfly
//   5. Boundary and stress cases
//
// BFU pipeline latency = 5 cycles (4 internal + 1 output register).
// Each test waits 6 cycles for safety.
//
// Reference model (software golden):
//   Dilithium forward: y0 = (xj + w*xjt) mod q_d
//                      y1 = (xj - w*xjt) mod q_d
//   Dilithium inverse: y0 = (xj + xjt) / 2 mod q_d
//                      y1 = (w * (xj - xjt)) / 2 mod q_d
//   Kyber: same formulas applied independently to each 12-bit lane.
//==============================================================================

module tb_bfu;

    // ---- DUT ports ----
    reg  clk, rst;
    reg  [23:0] xj, xjt, w;
    reg  mode, inv;
    wire [23:0] y0, y1;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    unified_bfu dut (
        .clk (clk),
        .rst (rst),
        .xj  (xj),
        .xjt (xjt),
        .w   (w),
        .mode(mode),
        .inv (inv),
        .y0  (y0),
        .y1  (y1)
    );

    // ---- Constants ----
    localparam integer QD = 8380417;
    localparam integer QK = 3329;

    // ---- Counters ----
    integer pass, fail;

    // ---- Reference model ----
    // Dilithium forward butterfly
    task ref_dil_fwd;
        input [22:0] xj_i, xjt_i, w_i;
        output [22:0] r0, r1;
        reg [45:0] tmp;
        begin
            tmp = (xjt_i * w_i) % QD;
            r0  = (xj_i + tmp) % QD;
            r1  = (xj_i + QD - tmp) % QD;
        end
    endtask

    // Kyber forward butterfly (single lane)
    task ref_kyo_fwd;
        input [11:0] xj_i, xjt_i, w_i;
        output [11:0] r0, r1;
        reg [23:0] tmp;
        begin
            tmp = (xjt_i * w_i) % QK;
            r0  = (xj_i + tmp) % QK;
            r1  = (xj_i + QK - tmp) % QK;
        end
    endtask

    // Dilithium inverse butterfly
    task ref_dil_inv;
        input [22:0] xj_i, xjt_i, w_i;
        output [22:0] r0, r1;
        reg [22:0] sum, diff;
        reg [45:0] tmp;
        begin
            sum  = (xj_i + xjt_i) % QD;
            diff = (xj_i + QD - xjt_i) % QD;
            tmp  = (diff * w_i) % QD;
            // divide by 2: multiply by modular inverse of 2 mod q
            // inv(2) mod 8380417 = 4190209
            r0 = (sum  * 32'd4190209) % QD;
            r1 = (tmp  * 32'd4190209) % QD;
        end
    endtask

    // Kyber inverse butterfly (single lane)
    task ref_kyo_inv;
        input [11:0] xj_i, xjt_i, w_i;
        output [11:0] r0, r1;
        reg [11:0] sum, diff;
        reg [23:0] tmp;
        begin
            sum  = (xj_i + xjt_i) % QK;
            diff = (xj_i + QK - xjt_i) % QK;
            tmp  = (diff * w_i) % QK;
            // inv(2) mod 3329 = 1665
            r0 = (sum * 16'd1665) % QK;
            r1 = (tmp * 16'd1665) % QK;
        end
    endtask

    // Pipeline latency
    localparam PIPE = 6;

    // ---- Packed result checking ----
    reg [22:0] exp_y0_d, exp_y1_d;
    reg [11:0] exp_y0_k_lo, exp_y1_k_lo, exp_y0_k_hi, exp_y1_k_hi;

    // ---- Task: test Dilithium forward ----
    task test_dil_fwd;
        input [22:0] xj_i, xjt_i, w_i;
        begin
            @(negedge clk);
            xj   = {1'b0, xj_i};
            xjt  = {1'b0, xjt_i};
            w    = {1'b0, w_i};
            mode = 0; inv = 0;

            repeat(PIPE) @(posedge clk);
            @(negedge clk);

            ref_dil_fwd(xj_i, xjt_i, w_i, exp_y0_d, exp_y1_d);

            if ((y0[22:0] === exp_y0_d) && (y1[22:0] === exp_y1_d)) begin
                pass = pass + 1;
                $display("[PASS] DIL_FWD xj=%0d xjt=%0d w=%0d → y0=%0d y1=%0d",
                          xj_i, xjt_i, w_i, y0[22:0], y1[22:0]);
            end else begin
                fail = fail + 1;
                $display("[FAIL] DIL_FWD xj=%0d xjt=%0d w=%0d → y0=%0d(exp %0d) y1=%0d(exp %0d) <<<",
                          xj_i, xjt_i, w_i, y0[22:0], exp_y0_d, y1[22:0], exp_y1_d);
            end
        end
    endtask

    // ---- Task: test Kyber forward ----
    task test_kyo_fwd;
        input [11:0] xj_lo, xjt_lo, w_lo;
        input [11:0] xj_hi, xjt_hi, w_hi;
        begin
            @(negedge clk);
            xj   = {xj_hi,  xj_lo};
            xjt  = {xjt_hi, xjt_lo};
            w    = {w_hi,   w_lo};
            mode = 1; inv = 0;

            repeat(PIPE) @(posedge clk);
            @(negedge clk);

            ref_kyo_fwd(xj_lo,  xjt_lo,  w_lo,  exp_y0_k_lo, exp_y1_k_lo);
            ref_kyo_fwd(xj_hi,  xjt_hi,  w_hi,  exp_y0_k_hi, exp_y1_k_hi);

            if ((y0[11:0] === exp_y0_k_lo) && (y1[11:0] === exp_y1_k_lo) &&
                (y0[23:12]=== exp_y0_k_hi) && (y1[23:12]=== exp_y1_k_hi)) begin
                pass = pass + 1;
                $display("[PASS] KYB_FWD lo:(%0d,%0d,w=%0d)→(%0d,%0d) hi:(%0d,%0d,w=%0d)→(%0d,%0d)",
                    xj_lo,xjt_lo,w_lo,y0[11:0],y1[11:0],xj_hi,xjt_hi,w_hi,y0[23:12],y1[23:12]);
            end else begin
                fail = fail + 1;
                $display("[FAIL] KYB_FWD lo:exp(%0d,%0d) got(%0d,%0d) hi:exp(%0d,%0d) got(%0d,%0d) <<<",
                    exp_y0_k_lo,exp_y1_k_lo,y0[11:0],y1[11:0],
                    exp_y0_k_hi,exp_y1_k_hi,y0[23:12],y1[23:12]);
            end
        end
    endtask

    // ---- Task: test Dilithium inverse ----
    task test_dil_inv;
        input [22:0] xj_i, xjt_i, w_i;
        begin
            @(negedge clk);
            xj   = {1'b0, xj_i};
            xjt  = {1'b0, xjt_i};
            w    = {1'b0, w_i};
            mode = 0; inv = 1;

            repeat(PIPE) @(posedge clk);
            @(negedge clk);

            ref_dil_inv(xj_i, xjt_i, w_i, exp_y0_d, exp_y1_d);

            if ((y0[22:0] === exp_y0_d) && (y1[22:0] === exp_y1_d)) begin
                pass = pass + 1;
                $display("[PASS] DIL_INV xj=%0d xjt=%0d w=%0d → y0=%0d y1=%0d",
                          xj_i, xjt_i, w_i, y0[22:0], y1[22:0]);
            end else begin
                fail = fail + 1;
                $display("[FAIL] DIL_INV xj=%0d xjt=%0d w=%0d → y0=%0d(exp %0d) y1=%0d(exp %0d) <<<",
                          xj_i, xjt_i, w_i, y0[22:0], exp_y0_d, y1[22:0], exp_y1_d);
            end
        end
    endtask

    // ---- Task: test Kyber inverse ----
    task test_kyo_inv;
        input [11:0] xj_lo, xjt_lo, w_lo;
        input [11:0] xj_hi, xjt_hi, w_hi;
        begin
            @(negedge clk);
            xj   = {xj_hi,  xj_lo};
            xjt  = {xjt_hi, xjt_lo};
            w    = {w_hi,   w_lo};
            mode = 1; inv = 1;

            repeat(PIPE) @(posedge clk);
            @(negedge clk);

            ref_kyo_inv(xj_lo,  xjt_lo,  w_lo,  exp_y0_k_lo, exp_y1_k_lo);
            ref_kyo_inv(xj_hi,  xjt_hi,  w_hi,  exp_y0_k_hi, exp_y1_k_hi);

            if ((y0[11:0] === exp_y0_k_lo) && (y1[11:0] === exp_y1_k_lo) &&
                (y0[23:12]=== exp_y0_k_hi) && (y1[23:12]=== exp_y1_k_hi)) begin
                pass = pass + 1;
                $display("[PASS] KYB_INV lo:(%0d,%0d)→(%0d,%0d) hi:(%0d,%0d)→(%0d,%0d)",
                    xj_lo,xjt_lo,y0[11:0],y1[11:0],xj_hi,xjt_hi,y0[23:12],y1[23:12]);
            end else begin
                fail = fail + 1;
                $display("[FAIL] KYB_INV lo:exp(%0d,%0d) got(%0d,%0d) hi:exp(%0d,%0d) got(%0d,%0d) <<<",
                    exp_y0_k_lo,exp_y1_k_lo,y0[11:0],y1[11:0],
                    exp_y0_k_hi,exp_y1_k_hi,y0[23:12],y1[23:12]);
            end
        end
    endtask

    // ========================= STIMULUS =========================
    initial begin
        clk  = 0; rst = 0;
        xj   = 0; xjt = 0; w = 0;
        mode = 0; inv = 0;
        pass = 0; fail = 0;

        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        repeat(4) @(posedge clk);

        // -------- Dilithium Forward --------
        $display("\n=== Dilithium Forward NTT Butterfly ===");
        test_dil_fwd(23'd135,   23'd848,   23'd23102);
        test_dil_fwd(23'd0,     23'd0,     23'd1);       // trivial zero
        test_dil_fwd(23'd1,     23'd1,     23'd1);       // 1+1=2
        test_dil_fwd(23'd8380416, 23'd1,   23'd1);       // q-1, w=1 → (q,q-2)
        test_dil_fwd(23'd4000000, 23'd4000000, 23'd2);
        test_dil_fwd(23'd7654321, 23'd1234567, 23'd5678901);

        // -------- Dilithium Inverse --------
        $display("\n=== Dilithium Inverse NTT Butterfly ===");
        test_dil_inv(23'd135,   23'd848,   23'd23102);
        test_dil_inv(23'd100,   23'd200,   23'd1);
        test_dil_inv(23'd8380416, 23'd8380416, 23'd1);
        test_dil_inv(23'd5000000, 23'd3000000, 23'd7654321);

        // -------- Kyber Forward --------
        $display("\n=== Kyber Forward NTT Butterfly ===");
        test_kyo_fwd(12'd135,  12'd848,  12'd5,   12'd457,  12'd1048, 12'd5);
        test_kyo_fwd(12'd0,    12'd0,    12'd1,   12'd0,    12'd0,    12'd1);
        test_kyo_fwd(12'd3328, 12'd1,    12'd1,   12'd3328, 12'd1,    12'd1);
        test_kyo_fwd(12'd1000, 12'd2000, 12'd3000,12'd500,  12'd1500, 12'd2500);
        test_kyo_fwd(12'd3000, 12'd3000, 12'd3000,12'd1,    12'd1,    12'd1);

        // -------- Kyber Inverse --------
        $display("\n=== Kyber Inverse NTT Butterfly ===");
        test_kyo_inv(12'd135,  12'd848,  12'd5,   12'd457,  12'd1048, 12'd5);
        test_kyo_inv(12'd200,  12'd100,  12'd1,   12'd200,  12'd100,  12'd1);
        test_kyo_inv(12'd3328, 12'd3328, 12'd1,   12'd3328, 12'd3328, 12'd1);
        test_kyo_inv(12'd1000, 12'd2000, 12'd3000,12'd500,  12'd1500, 12'd2500);

        // -------- Mode-switch stress --------
        $display("\n=== Mode-switch stress ===");
        begin : STRESS
            integer s;
            for (s = 0; s < 5; s = s + 1) begin
                test_dil_fwd(23'd1111111, 23'd2222222, 23'd3333333);
                test_kyo_fwd(12'd111,12'd222,12'd333, 12'd444,12'd555,12'd666);
            end
        end

        // -------- Report --------
        $display("\n==================================================");
        $display("BFU RESULTS: PASS=%0d  FAIL=%0d", pass, fail);
        if (fail == 0)
            $display("ALL TESTS PASSED");
        else
            $display("*** FAILURES DETECTED ***");
        $display("==================================================\n");
        $finish;
    end

endmodule
