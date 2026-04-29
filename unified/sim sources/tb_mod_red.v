`timescale 1ns / 1ps
//==============================================================================
// KaLi - Testbench: mod_red (Modular Reduction Unit)
//
// Tests:
//   1. Dilithium mode (dk=0): several 46-bit products reduced mod 8380417
//   2. Kyber mode    (dk=1): pairs of 24-bit products reduced mod 3329 each
//   3. Boundary cases: 0, q-1, q, q+1, 2q-1
//   4. Large random-style values to stress the CSA tree
//
// Pipeline latency of mod_red = 2 cycles (reg_block_row + reg_30b).
// We wait 4 cycles after applying input before sampling output to be safe.
//==============================================================================

module tb_mod_red;

    // ---- DUT ports ----
    reg  clk, rst, dk;
    reg  [23:0] k_ip1, k_ip2;
    reg  [45:0] d_ip;
    wire [29:0] c;

    // ---- Clock ----
    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- DUT ----
    mod_red dut (
        .clk   (clk),
        .rst   (rst),
        .dk    (dk),
        .k_ip1 (k_ip1),
        .k_ip2 (k_ip2),
        .d_ip  (d_ip),
        .c     (c)
    );

    // ---- Constants ----
    localparam [22:0] QD = 23'd8380417;
    localparam [11:0] QK = 12'd3329;

    // ---- Reference model ----
    // Returns expected Dilithium reduction
    function [29:0] ref_dil;
        input [45:0] inp;
        reg [63:0] v;
        begin
            v = inp % QD;
            ref_dil = v[29:0];
        end
    endfunction

    // Returns expected Kyber reduction (single lane)
    function [14:0] ref_kyo;
        input [23:0] inp;
        reg [24:0] v;
        begin
            v = inp % QK;
            ref_kyo = v[14:0];
        end
    endfunction

    // ---- Variables ----
    integer pass_d, fail_d, pass_k, fail_k;
    integer i;
    reg [29:0] expected;
    reg [14:0] exp_k_lo, exp_k_hi;

    // ---- Task: apply one Dilithium test ----
    task test_dilithium;
        input [45:0] inp;
        input [45:0] tag;
        begin
            @(negedge clk);
            dk   = 0;
            d_ip = inp;

            // Wait for 2-cycle pipeline to flush
            repeat(3) @(posedge clk);
            @(negedge clk);   // sample after falling edge

            expected = ref_dil(inp);
            if (c[25:0] === expected[25:0]) begin
                pass_d = pass_d + 1;
                $display("[PASS] DILITHIUM  inp=%0d  got=%0d  exp=%0d",
                          inp, c[25:0], expected[25:0]);
            end else begin
                fail_d = fail_d + 1;
                $display("[FAIL] DILITHIUM  inp=%0d  got=%0d  exp=%0d  <<<<<",
                          inp, c[25:0], expected[25:0]);
            end
        end
    endtask

    // ---- Task: apply one Kyber test ----
    task test_kyber;
        input [23:0] inp1;
        input [23:0] inp2;
        begin
            @(negedge clk);
            dk    = 1;
            k_ip1 = inp1;
            k_ip2 = inp2;

            repeat(3) @(posedge clk);
            @(negedge clk);

            exp_k_lo = ref_kyo(inp1);
            exp_k_hi = ref_kyo(inp2);

            if ((c[14:0] === exp_k_lo) && (c[29:15] === exp_k_hi)) begin
                pass_k = pass_k + 1;
                $display("[PASS] KYBER  ip1=%0d ip2=%0d  got=(%0d,%0d) exp=(%0d,%0d)",
                          inp1, inp2, c[14:0], c[29:15], exp_k_lo, exp_k_hi);
            end else begin
                fail_k = fail_k + 1;
                $display("[FAIL] KYBER  ip1=%0d ip2=%0d  got=(%0d,%0d) exp=(%0d,%0d) <<<<<",
                          inp1, inp2, c[14:0], c[29:15], exp_k_lo, exp_k_hi);
            end
        end
    endtask

    // ---- Stimulus ----
    initial begin
        clk    = 0;
        rst    = 0;
        dk     = 0;
        k_ip1  = 0;
        k_ip2  = 0;
        d_ip   = 0;
        pass_d = 0; fail_d = 0;
        pass_k = 0; fail_k = 0;

        // Reset
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        @(negedge clk);

        $display("======================================================");
        $display("       mod_red Testbench: Dilithium Mode");
        $display("======================================================");

        // --- Dilithium boundary tests ---
        test_dilithium(46'd0,                     0);    // 0 mod q = 0
        test_dilithium(46'd8380417,               1);    // q mod q = 0
        test_dilithium(46'd8380416,               2);    // q-1
        test_dilithium(46'd8380418,               3);    // q+1
        test_dilithium(46'd16760834,              4);    // 2q
        test_dilithium(46'd16760833,              5);    // 2q-1

        // --- Dilithium known-value tests (a^2 mod q) ---
        // 135^2 = 18225; 18225 mod 8380417 = 18225
        test_dilithium(46'd18225,                 6);
        // 8380416^2 = (q-1)^2 = q^2 - 2q + 1 ≡ 1 mod q
        test_dilithium(46'd1,                     7);
        // 1234567890 mod 8380417
        test_dilithium(46'd1234567890,            8);
        // Large: 70368744177663 = 2^46 - 1
        test_dilithium(46'h3FFFFFFFFFFF,          9);

        $display("======================================================");
        $display("       mod_red Testbench: Kyber Mode");
        $display("======================================================");

        // --- Kyber boundary tests ---
        test_kyber(24'd0,       24'd0);        // both zero
        test_kyber(24'd3329,    24'd3329);      // both = q → 0
        test_kyber(24'd3328,    24'd3328);      // q-1
        test_kyber(24'd3330,    24'd3330);      // q+1 → 1
        test_kyber(24'd6657,    24'd1);         // 2q-1 and 1
        test_kyber(24'd6658,    24'd6658);      // 2q → 0

        // --- Kyber known multiplications (result of 12-bit * 12-bit products) ---
        // 135 * 848 = 114480;  114480 mod 3329 = 114480 - 34*3329 = 114480 - 113186 = 1294
        test_kyber(24'd114480,  24'd0);
        // 457 * 1048 = 479,096; 479096 mod 3329 = ?
        // 479096 / 3329 = 143 r 2029 → 3329*143=476047; 479096-476047=3049
        test_kyber(24'd0,       24'd479096);
        // Mix: both lanes active
        test_kyber(24'd114480,  24'd479096);
        // Upper range
        test_kyber(24'd16711680, 24'd123456);

        $display("======================================================");
        $display("       mod_red Testbench: Mode-switch stress");
        $display("======================================================");
        // Rapid alternation between modes (pipeline state must be clean)
        begin : MODE_SWITCH
            integer j;
            for (j = 0; j < 8; j = j + 1) begin
                test_dilithium(46'd9568312, j);
                test_kyber(24'd7348, 24'd15483);
            end
        end

        $display("======================================================");
        $display("RESULTS: Dilithium PASS=%0d FAIL=%0d | Kyber PASS=%0d FAIL=%0d",
                  pass_d, fail_d, pass_k, fail_k);
        if ((fail_d == 0) && (fail_k == 0))
            $display("ALL TESTS PASSED");
        else
            $display("*** FAILURES DETECTED ***");
        $display("======================================================");
        $finish;
    end

endmodule
