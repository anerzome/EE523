`timescale 1ns / 1ps
//==============================================================================
// KaLi - Testbench: Compress / Decompress / Encode / Decode Units
// Fixed: all reg declarations moved to top of task / module (Verilog-2001)
//==============================================================================

module tb_compress_encode;

localparam CLK_PERIOD = 10;
reg clk, rst;
always #(CLK_PERIOD/2) clk = ~clk;

// ---- Shared counters (declared at module level) ----
integer pass, fail;
integer wait_cnt;

//==============================================================================
// compress_decompress DUT
//==============================================================================
reg        compress_sel;
reg [11:0] cd_in;
reg [3:0]  cd_d;
wire[11:0] cd_out;

compress_decompress cd_dut (
    .clk      (clk),
    .rst      (rst),
    .compress (compress_sel),
    .data_in  (cd_in),
    .d        (cd_d),
    .data_out (cd_out)
);

//==============================================================================
// encode DUT
//==============================================================================
reg         enc_valid;
reg  [3:0]  enc_w;
reg  [10:0] enc_c0, enc_c1, enc_c2, enc_c3;
wire        enc_valid_out;
wire [63:0] enc_out;

encode_unit enc_dut (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (enc_valid),
    .coeff_w   (enc_w),
    .c0(enc_c0),.c1(enc_c1),.c2(enc_c2),.c3(enc_c3),
    .valid_out (enc_valid_out),
    .packed_out(enc_out)
);

//==============================================================================
// decode DUT
//==============================================================================
reg         dec_valid;
reg  [3:0]  dec_w;
reg  [63:0] dec_in;
wire        dec_valid_out;
wire [10:0] dec_c0, dec_c1, dec_c2, dec_c3;

decode_unit dec_dut (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (dec_valid),
    .coeff_w   (dec_w),
    .packed_in (dec_in),
    .valid_out (dec_valid_out),
    .c0(dec_c0),.c1(dec_c1),.c2(dec_c2),.c3(dec_c3)
);

//==============================================================================
// Reference functions
//==============================================================================

// Reference compress (Algorithm 3)
function [10:0] ref_compress;
    input [11:0] x;
    input [3:0]  d;
    reg [39:0] t;
    reg [10:0] y;
    begin
        t = 40'd0; y = 11'd0;
        case (d)
            4'd1:  begin t = 40'd10079    * {28'd0,x}; y = t[34:24] + t[23]; y = y & 11'h001; end
            4'd4:  begin t = 40'd315      * {28'd0,x}; y = t[26:16] + t[15]; y = y & 11'h00F; end
            4'd5:  begin t = 40'd630      * {28'd0,x}; y = t[26:16] + t[15]; y = y & 11'h01F; end
            4'd10: begin t = 40'd5160669  * {28'd0,x}; y = t[34:24] + t[23]; y = y & 11'h3FF; end
            4'd11: begin t = 40'd10321339 * {28'd0,x}; y = t[34:24] + t[23]; y = y & 11'h7FF; end
            default: y = 11'd0;
        endcase
        ref_compress = y;
    end
endfunction

// Reference decompress
function [11:0] ref_decompress;
    input [10:0] y;
    input [3:0]  d;
    reg [25:0] num;
    begin
        num = 13'd3329 * {15'b0, y};
        case (d)
            4'd1:  ref_decompress = (num + 26'd1)    >> 1;
            4'd4:  ref_decompress = (num + 26'd8)    >> 4;
            4'd5:  ref_decompress = (num + 26'd16)   >> 5;
            4'd10: ref_decompress = (num + 26'd512)  >> 10;
            4'd11: ref_decompress = (num + 26'd1024) >> 11;
            default: ref_decompress = 12'd0;
        endcase
    end
endfunction

// Reference pack
function [63:0] ref_pack;
    input [3:0]  w;
    input [10:0] a, b, c_, d_;
    reg [63:0] v;
    begin
        v = 64'b0;
        case (w)
            4'd1:  begin
                v[0]=a[0]; v[1]=b[0]; v[2]=c_[0]; v[3]=d_[0];
            end
            4'd4:  begin
                v[3:0]=a[3:0];   v[7:4]=b[3:0];
                v[11:8]=c_[3:0]; v[15:12]=d_[3:0];
            end
            4'd5:  begin
                v[4:0]=a[4:0];    v[9:5]=b[4:0];
                v[14:10]=c_[4:0]; v[19:15]=d_[4:0];
            end
            4'd10: begin
                v[9:0]=a[9:0];    v[19:10]=b[9:0];
                v[29:20]=c_[9:0]; v[39:30]=d_[9:0];
            end
            4'd11: begin
                v[10:0]=a[10:0];  v[21:11]=b[10:0];
                v[32:22]=c_[10:0];v[43:33]=d_[10:0];
            end
            default: ;
        endcase
        ref_pack = v;
    end
endfunction

//==============================================================================
// Tasks  — ALL reg declarations at the very top of each task
//==============================================================================

// ---- test_compress ----
task test_compress;
    input [11:0] x;
    input [3:0]  d;
    // declarations first
    reg [10:0] exp;
    begin
        @(negedge clk);
        compress_sel = 1;
        cd_in = x;
        cd_d  = d;
        @(posedge clk);   // compress_unit registered output
        @(negedge clk);

        exp = ref_compress(x, d);
        if (cd_out[10:0] === exp) begin
            pass = pass + 1;
            $display("[PASS] COMPRESS x=%4d d=%2d -> got=%4d exp=%4d", x, d, cd_out[10:0], exp);
        end else begin
            fail = fail + 1;
            $display("[FAIL] COMPRESS x=%4d d=%2d -> got=%4d exp=%4d <<<", x, d, cd_out[10:0], exp);
        end
    end
endtask

// ---- test_decompress ----
task test_decompress;
    input [10:0] y;
    input [3:0]  d;
    reg [11:0] exp;
    begin
        @(negedge clk);
        compress_sel = 0;
        cd_in = {1'b0, y};
        cd_d  = d;
        @(posedge clk);
        @(negedge clk);

        exp = ref_decompress(y, d);
        if (cd_out === exp) begin
            pass = pass + 1;
            $display("[PASS] DECOMPRESS y=%4d d=%2d -> got=%4d exp=%4d", y, d, cd_out, exp);
        end else begin
            fail = fail + 1;
            $display("[FAIL] DECOMPRESS y=%4d d=%2d -> got=%4d exp=%4d <<<", y, d, cd_out, exp);
        end
    end
endtask

// ---- test_encode_decode ----
task test_encode_decode;
    input [3:0]  w;
    input [10:0] a, b, c_, d_;
    // ALL declarations at top of task — this was the bug
    reg [63:0] exp_packed;
    reg [10:0] mask;
    reg        enc_ok;
    begin
        // --- encode ---
        @(negedge clk);
        enc_valid = 1;
        enc_w  = w;
        enc_c0 = a; enc_c1 = b; enc_c2 = c_; enc_c3 = d_;
        @(posedge clk); @(negedge clk);
        enc_valid = 0;

        // wait for encode output (max 8 cycles)
        wait_cnt = 0;
        while (!enc_valid_out && wait_cnt < 8) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        @(negedge clk);

        exp_packed = ref_pack(w, a, b, c_, d_);
        enc_ok = 0;

        if (!enc_valid_out) begin
            fail = fail + 1;
            $display("[FAIL] ENCODE w=%2d: valid_out never asserted <<<", w);
        end else if (enc_out === exp_packed) begin
            pass  = pass + 1;
            enc_ok = 1;
            $display("[PASS] ENCODE w=%2d: packed=%h exp=%h", w, enc_out, exp_packed);
        end else begin
            fail = fail + 1;
            $display("[FAIL] ENCODE w=%2d: packed=%h exp=%h <<<", w, enc_out, exp_packed);
        end

        // --- decode the packed output (only if encode passed) ---
        if (enc_ok) begin
            @(negedge clk);
            dec_valid = 1;
            dec_w     = w;
            dec_in    = enc_out;
            @(posedge clk); @(negedge clk);
            dec_valid = 0;

            wait_cnt = 0;
            while (!dec_valid_out && wait_cnt < 8) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end
            @(negedge clk);

            // mask to w bits
            mask = (11'd1 << w) - 11'd1;

            if (!dec_valid_out) begin
                fail = fail + 1;
                $display("[FAIL] DECODE w=%2d: valid_out never asserted <<<", w);
            end else if (((dec_c0 & mask) === (a  & mask)) &&
                         ((dec_c1 & mask) === (b  & mask)) &&
                         ((dec_c2 & mask) === (c_ & mask)) &&
                         ((dec_c3 & mask) === (d_ & mask))) begin
                pass = pass + 1;
                $display("[PASS] DECODE w=%2d: c0=%0d c1=%0d c2=%0d c3=%0d",
                    w, dec_c0&mask, dec_c1&mask, dec_c2&mask, dec_c3&mask);
            end else begin
                fail = fail + 1;
                $display("[FAIL] DECODE w=%2d: got(%0d,%0d,%0d,%0d) exp(%0d,%0d,%0d,%0d) <<<",
                    w, dec_c0&mask, dec_c1&mask, dec_c2&mask, dec_c3&mask,
                    a&mask, b&mask, c_&mask, d_&mask);
            end
        end
    end
endtask

//==============================================================================
// STIMULUS
//==============================================================================
initial begin
    clk = 0; rst = 0;
    compress_sel = 0; cd_in = 0; cd_d = 4'd1;
    enc_valid = 0; enc_w = 4'd4;
    enc_c0=0; enc_c1=0; enc_c2=0; enc_c3=0;
    dec_valid = 0; dec_w = 4'd4; dec_in = 0;
    pass = 0; fail = 0; wait_cnt = 0;

    @(negedge clk); rst = 1;
    repeat(2) @(negedge clk); rst = 0;
    repeat(2) @(posedge clk);

    // ------------------------------------------------------------------
    $display("\n=== Compress: d=1 ===");
    test_compress(12'd0,    4'd1);
    test_compress(12'd3329, 4'd1);
    test_compress(12'd1664, 4'd1);
    test_compress(12'd1000, 4'd1);
    test_compress(12'd3328, 4'd1);

    $display("\n=== Compress: d=4 ===");
    test_compress(12'd0,    4'd4);
    test_compress(12'd3329, 4'd4);
    test_compress(12'd208,  4'd4);
    test_compress(12'd1000, 4'd4);
    test_compress(12'd3000, 4'd4);

    $display("\n=== Compress: d=5 ===");
    test_compress(12'd0,    4'd5);
    test_compress(12'd104,  4'd5);
    test_compress(12'd1000, 4'd5);
    test_compress(12'd2000, 4'd5);
    test_compress(12'd3328, 4'd5);

    $display("\n=== Compress: d=10 ===");
    test_compress(12'd0,    4'd10);
    test_compress(12'd3328, 4'd10);
    test_compress(12'd1000, 4'd10);
    test_compress(12'd2500, 4'd10);

    $display("\n=== Compress: d=11 ===");
    test_compress(12'd0,    4'd11);
    test_compress(12'd3328, 4'd11);
    test_compress(12'd1000, 4'd11);
    test_compress(12'd2048, 4'd11);

    // ------------------------------------------------------------------
    $display("\n=== Decompress: various d ===");
    test_decompress(11'd0,    4'd1);
    test_decompress(11'd1,    4'd1);
    test_decompress(11'd0,    4'd4);
    test_decompress(11'd8,    4'd4);
    test_decompress(11'd15,   4'd4);
    test_decompress(11'd0,    4'd5);
    test_decompress(11'd16,   4'd5);
    test_decompress(11'd0,    4'd10);
    test_decompress(11'd512,  4'd10);
    test_decompress(11'd1023, 4'd10);
    test_decompress(11'd0,    4'd11);
    test_decompress(11'd1024, 4'd11);
    test_decompress(11'd2047, 4'd11);

    // ------------------------------------------------------------------
    $display("\n=== Encode + Decode round-trip: d=1 ===");
    test_encode_decode(4'd1, 11'd0, 11'd1, 11'd0, 11'd1);
    test_encode_decode(4'd1, 11'd1, 11'd1, 11'd0, 11'd0);

    $display("\n=== Encode + Decode round-trip: d=4 ===");
    test_encode_decode(4'd4, 11'd3,  11'd7,  11'd11, 11'd15);
    test_encode_decode(4'd4, 11'd0,  11'd0,  11'd0,  11'd0);
    test_encode_decode(4'd4, 11'd15, 11'd15, 11'd15, 11'd15);

    $display("\n=== Encode + Decode round-trip: d=5 ===");
    test_encode_decode(4'd5, 11'd31, 11'd0,  11'd16, 11'd8);
    test_encode_decode(4'd5, 11'd1,  11'd2,  11'd4,  11'd8);

    $display("\n=== Encode + Decode round-trip: d=10 ===");
    test_encode_decode(4'd10, 11'd0,   11'd511, 11'd512, 11'd1023);
    test_encode_decode(4'd10, 11'd100, 11'd200, 11'd300, 11'd400);

    $display("\n=== Encode + Decode round-trip: d=11 ===");
    test_encode_decode(4'd11, 11'd0,    11'd1023, 11'd1024, 11'd2047);
    test_encode_decode(4'd11, 11'd1111, 11'd222,  11'd333,  11'd444);

    // ------------------------------------------------------------------
    $display("\n==================================================");
    $display("COMPRESS/ENCODE RESULTS: PASS=%0d  FAIL=%0d", pass, fail);
    if (fail == 0)
        $display("ALL TESTS PASSED");
    else
        $display("*** FAILURES DETECTED ***");
    $display("==================================================\n");
    $finish;
end

endmodule