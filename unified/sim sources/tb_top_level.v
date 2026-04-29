`timescale 1ns / 1ps
//==============================================================================
// KaLi - Testbench: top_level modular reduction (mod_red wrapper)
//   Mirrors the original top_level_tb from modular_reduction.txt but
//   corrected: proper @(negedge clk) timing, no repeat() missing begin/end,
//   and extended with pass/fail checking.
//==============================================================================

module tb_top_level;

    reg  [23:0] k_ip1, k_ip2;
    reg  [45:0] d_ip;
    reg  dk, rst, clk;
    wire [29:0] c;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Instantiate mod_red directly (same interface as original top_level)
    mod_red dut (
        .k_ip1 (k_ip1),
        .k_ip2 (k_ip2),
        .d_ip  (d_ip),
        .dk    (dk),
        .rst   (rst),
        .clk   (clk),
        .c     (c)
    );

    integer pass_d, fail_d, pass_k, fail_k;

    function [29:0] expected_dil;
        input [45:0] inp;
        begin expected_dil = inp % 8380417; end
    endfunction

    function [14:0] expected_kyo;
        input [23:0] inp;
        begin expected_kyo = inp % 3329; end
    endfunction

    initial begin
        clk   = 0; rst = 0; dk = 0;
        k_ip1 = 0; k_ip2 = 0; d_ip = 0;
        pass_d = 0; fail_d = 0; pass_k = 0; fail_k = 0;

        // Reset
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;

        // ---- Dilithium tests (mirroring original + extensions) ----
        dk   = 0;
        d_ip = 46'd8380418;        // q+1 → expected 1
        repeat(4) @(posedge clk);
        @(negedge clk);
        if (c[25:0] === expected_dil(46'd8380418)) begin pass_d=pass_d+1;
            $display("[PASS] DIL inp=8380418 got=%0d exp=1", c[25:0]);
        end else begin fail_d=fail_d+1;
            $display("[FAIL] DIL inp=8380418 got=%0d exp=1 <<<", c[25:0]);
        end

        d_ip = 46'd9568312;
        repeat(4) @(posedge clk);
        @(negedge clk);
        if (c[25:0] === expected_dil(46'd9568312)) begin pass_d=pass_d+1;
            $display("[PASS] DIL inp=9568312 got=%0d exp=%0d",
                      c[25:0], expected_dil(46'd9568312));
        end else begin fail_d=fail_d+1;
            $display("[FAIL] DIL inp=9568312 got=%0d exp=%0d <<<",
                      c[25:0], expected_dil(46'd9568312));
        end

        // ---- Switch to Kyber mode ----
        dk    = 1;
        k_ip1 = 24'd7348;
        k_ip2 = 24'd15483;
        d_ip  = 0;
        repeat(4) @(posedge clk);
        @(negedge clk);
        if ((c[14:0] === expected_kyo(24'd7348)) &&
            (c[29:15]=== expected_kyo(24'd15483))) begin
            pass_k = pass_k + 1;
            $display("[PASS] KYB ip1=7348 ip2=15483 got=(%0d,%0d) exp=(%0d,%0d)",
                c[14:0], c[29:15], expected_kyo(24'd7348), expected_kyo(24'd15483));
        end else begin
            fail_k = fail_k + 1;
            $display("[FAIL] KYB ip1=7348 ip2=15483 got=(%0d,%0d) exp=(%0d,%0d) <<<",
                c[14:0], c[29:15], expected_kyo(24'd7348), expected_kyo(24'd15483));
        end

        $display("Time = %0t, c = %h", $time, c);
        $display("RESULTS: Dilithium PASS=%0d FAIL=%0d | Kyber PASS=%0d FAIL=%0d",
                  pass_d, fail_d, pass_k, fail_k);
        $finish;
    end

endmodule
