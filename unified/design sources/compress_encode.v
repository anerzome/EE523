`timescale 1ns / 1ps
//==============================================================================
// KaLi - Compress / Decompress Unit  (Algorithm 3 + Fig. 10 in paper)
//
// compress_unit:
//   Implements y = round((2^d / q) * x) mod 2^d  for Kyber (q=3329).
//   All multiplications by constants are synthesised using LUT add-shift chains.
//   Supported d values: 1, 4, 5, 10, 11.
//   Latency: 1 clock cycle (registered output).
//
// decompress_unit:
//   Implements y = round((q / 2^d) * x)  for Kyber.
//   Trivial shift + rounding, combinational.
//
// compress_decompress:
//   Wrapper that selects compress or decompress based on `compress` flag.
//   Registered output.
//==============================================================================

//------------------------------------------------------------------------------
// compress_unit
//   Input:  x [11:0]  coefficient ∈ Z_3329
//           d [3:0]   compression bits ∈ {1,4,5,10,11}
//   Output: y [10:0]  compressed coefficient (at most 11 bits)
//   Latency: 1 cycle
//------------------------------------------------------------------------------
module compress_unit (
    input  clk,
    input  [11:0] x,
    input  [3:0]  d,
    output reg [10:0] y
);
    // Pre-computed constants:
    // round((2^d / 3329) * x)  ≈ (CONST * x) >> SHIFT  with rounding
    // Matches Algorithm 3 in the KaLi paper.
    //
    //  d=1 : k=10079, shift=24   → t = 10079*x; y = (t>>24) + t[23]
    //  d=4 : k=315,   shift=16   → t = 315*x;   y = (t>>16) + t[15]
    //  d=5 : k=630,   shift=16   → t = 630*x;   y = (t>>16) + t[15]
    //  d=10: k=5160669,shift=24  → t = 5160669*x; y = (t>>24) + t[23]
    //  d=11: k=10321339,shift=24 → t = 10321339*x; y = (t>>24) + t[23]

    reg [10:0] y_comb;
    reg [33:0] t;   // large enough for biggest multiply (10321339 * 4095 ≈ 42G < 2^36; use 34b)
    // Note: 10321339 * 3328 = 34,349,781,472 which fits in 36 bits.
    // Using 40-bit t to be safe.
    reg [39:0] t40;

    always @(*) begin
        t40 = 40'd0;
        y_comb = 11'd0;
        case (d)
            4'd1: begin
                t40 = 10079 * {28'b0, x};
                y_comb = t40[34:24] + t40[23];   // (t>>24) + round bit
            end
            4'd4: begin
                t40 = 315 * {28'b0, x};
                y_comb = t40[26:16] + t40[15];
            end
            4'd5: begin
                t40 = 630 * {28'b0, x};
                y_comb = t40[26:16] + t40[15];
            end
            4'd10: begin
                t40 = 5160669 * {28'b0, x};
                y_comb = t40[34:24] + t40[23];
            end
            4'd11: begin
                t40 = 10321339 * {28'b0, x};
                y_comb = t40[34:24] + t40[23];
            end
            default: y_comb = 11'd0;
        endcase
    end

    // Mask to 2^d bits
    reg [10:0] y_masked;
    always @(*) begin
        case (d)
            4'd1:  y_masked = y_comb & 11'h001;   // mod 2
            4'd4:  y_masked = y_comb & 11'h00F;   // mod 16
            4'd5:  y_masked = y_comb & 11'h01F;   // mod 32
            4'd10: y_masked = y_comb & 11'h3FF;   // mod 1024
            4'd11: y_masked = y_comb & 11'h7FF;   // mod 2048
            default: y_masked = 11'd0;
        endcase
    end

    always @(posedge clk)
        y <= y_masked;
endmodule

//------------------------------------------------------------------------------
// decompress_unit
//   Input:  y [10:0]  compressed coefficient
//           d [3:0]   compression bits
//   Output: x [11:0]  decompressed coefficient ∈ Z_3329
//   Formula: x = round((3329 / 2^d) * y)  =  (3329 * y + 2^(d-1)) >> d
//   Combinational.
//------------------------------------------------------------------------------
module decompress_unit (
    input  [10:0] y,
    input  [3:0]  d,
    output reg [11:0] x
);
    localparam [12:0] Q = 13'd3329;
    reg [25:0] num;   // 3329 * 2047 < 7M < 2^23; 26 bits fine

    always @(*) begin
        num = Q * {15'b0, y};
        case (d)
            4'd1:  x = (num + 11'd1)  >> 1;
            4'd4:  x = (num + 11'd8)  >> 4;
            4'd5:  x = (num + 11'd16) >> 5;
            4'd10: x = (num + 11'd512) >> 10;
            4'd11: x = (num + 11'd1024) >> 11;
            default: x = 12'd0;
        endcase
    end
endmodule

//------------------------------------------------------------------------------
// compress_decompress  (top-level wrapper matching Fig. 10)
//   compress=1 → compress;  compress=0 → decompress
//   Registered output (1 cycle for compress; combinational path registered for decomp)
//------------------------------------------------------------------------------
module compress_decompress (
    input  clk,
    input  rst,
    input  compress,           // 1 = compress, 0 = decompress
    input  [11:0] data_in,
    input  [3:0]  d,
    output reg [11:0] data_out
);
    wire [10:0] comp_out;
    wire [11:0] decomp_out;

    compress_unit   cu  (.clk(clk), .x(data_in), .d(d), .y(comp_out));
    decompress_unit du  (.y(data_in[10:0]), .d(d), .x(decomp_out));

    always @(posedge clk) begin
        if (rst) data_out <= 12'd0;
        else     data_out <= compress ? {1'b0, comp_out} : decomp_out;
    end
endmodule


//==============================================================================
// KaLi - Encode / Decode Unit  (Section III-E-2)
//
// Kyber uses coefficient-to-byte and byte-to-coefficient packing for
// transmission of public keys / ciphertexts.
// Supported coefficient widths: 1, 4, 5, 10, 11 bits.
//
// encode_unit:  4 coefficients in → packed 64-bit word out (partial fill)
//               Uses 104-bit internal buffer as per paper.
// decode_unit:  64-bit word in     → 4 coefficients out (partial)
//               Uses 72-bit internal buffer as per paper.
//
// For simulation / testbench purposes the units process one "group" of
// coefficients at a time; real integration would pipeline multiple groups.
//==============================================================================

//------------------------------------------------------------------------------
// encode_unit
//   Packs `num_coeffs` coefficients of width `coeff_w` into `out_bytes`.
//   coeff_w ∈ {1,4,5,10,11}.
//   4 coefficients are accepted per call to keep the interface simple.
//   Output is a 64-bit packed word (may contain partial bits for 5-bit case).
//------------------------------------------------------------------------------
module encode_unit (
    input  clk,
    input  rst,
    input  valid_in,
    input  [3:0]  coeff_w,         // coefficient bit-width
    input  [10:0] c0, c1, c2, c3,  // four input coefficients (max 11-bit)
    output reg        valid_out,
    output reg [63:0] packed_out
);
    reg [103:0] buf_r;  // 104-bit internal buffer (as per paper)
    reg [6:0]   fill;   // how many bits are filled

    always @(posedge clk) begin
        if (rst) begin
            buf_r     <= 104'b0;
            fill      <= 7'd0;
            valid_out <= 1'b0;
            packed_out<= 64'b0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                case (coeff_w)
                    4'd1: begin
                        buf_r[fill +: 1] <= c0[0];
                        buf_r[fill+1 +: 1] <= c1[0];
                        buf_r[fill+2 +: 1] <= c2[0];
                        buf_r[fill+3 +: 1] <= c3[0];
                        fill <= fill + 7'd4;
                    end
                    4'd4: begin
                        buf_r[fill +:  4] <= c0[3:0];
                        buf_r[fill+4 +: 4] <= c1[3:0];
                        buf_r[fill+8 +: 4] <= c2[3:0];
                        buf_r[fill+12+: 4] <= c3[3:0];
                        fill <= fill + 7'd16;
                    end
                    4'd5: begin
                        buf_r[fill +:  5] <= c0[4:0];
                        buf_r[fill+5 +: 5] <= c1[4:0];
                        buf_r[fill+10+: 5] <= c2[4:0];
                        buf_r[fill+15+: 5] <= c3[4:0];
                        fill <= fill + 7'd20;
                    end
                    4'd10: begin
                        buf_r[fill +:  10] <= c0[9:0];
                        buf_r[fill+10 +: 10] <= c1[9:0];
                        buf_r[fill+20 +: 10] <= c2[9:0];
                        buf_r[fill+30 +: 10] <= c3[9:0];
                        fill <= fill + 7'd40;
                    end
                    4'd11: begin
                        buf_r[fill +:  11] <= c0[10:0];
                        buf_r[fill+11 +: 11] <= c1[10:0];
                        buf_r[fill+22 +: 11] <= c2[10:0];
                        buf_r[fill+33 +: 11] <= c3[10:0];
                        fill <= fill + 7'd44;
                    end
                    default: ;
                endcase

                if (fill >= 7'd64) begin
                    packed_out <= buf_r[63:0];
                    buf_r      <= buf_r >> 64;
                    fill       <= fill - 7'd64;
                    valid_out  <= 1'b1;
                end
            end
        end
    end
endmodule

//------------------------------------------------------------------------------
// decode_unit
//   Unpacks a 64-bit word into 4 coefficients of width `coeff_w`.
//   Uses a 72-bit internal buffer (as per paper).
//------------------------------------------------------------------------------
module decode_unit (
    input  clk,
    input  rst,
    input  valid_in,
    input  [3:0]  coeff_w,
    input  [63:0] packed_in,
    output reg        valid_out,
    output reg [10:0] c0, c1, c2, c3
);
    reg [71:0] buf_r;  // 72-bit buffer
    reg [6:0]  fill;

    always @(posedge clk) begin
        if (rst) begin
            buf_r     <= 72'b0;
            fill      <= 7'd0;
            valid_out <= 1'b0;
            c0 <= 0; c1 <= 0; c2 <= 0; c3 <= 0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                buf_r[fill +: 64] <= packed_in;
                fill <= fill + 7'd64;
            end

            if (fill >= (4 * coeff_w)) begin
                case (coeff_w)
                    4'd1:  begin
                        c0 <= {10'b0, buf_r[0]};
                        c1 <= {10'b0, buf_r[1]};
                        c2 <= {10'b0, buf_r[2]};
                        c3 <= {10'b0, buf_r[3]};
                        buf_r <= buf_r >> 4;
                        fill  <= fill - 7'd4;
                    end
                    4'd4:  begin
                        c0 <= {7'b0, buf_r[3:0]};
                        c1 <= {7'b0, buf_r[7:4]};
                        c2 <= {7'b0, buf_r[11:8]};
                        c3 <= {7'b0, buf_r[15:12]};
                        buf_r <= buf_r >> 16;
                        fill  <= fill - 7'd16;
                    end
                    4'd5:  begin
                        c0 <= {6'b0, buf_r[4:0]};
                        c1 <= {6'b0, buf_r[9:5]};
                        c2 <= {6'b0, buf_r[14:10]};
                        c3 <= {6'b0, buf_r[19:15]};
                        buf_r <= buf_r >> 20;
                        fill  <= fill - 7'd20;
                    end
                    4'd10: begin
                        c0 <= {1'b0, buf_r[9:0]};
                        c1 <= {1'b0, buf_r[19:10]};
                        c2 <= {1'b0, buf_r[29:20]};
                        c3 <= {1'b0, buf_r[39:30]};
                        buf_r <= buf_r >> 40;
                        fill  <= fill - 7'd40;
                    end
                    4'd11: begin
                        c0 <= buf_r[10:0];
                        c1 <= buf_r[21:11];
                        c2 <= buf_r[32:22];
                        c3 <= buf_r[43:33];
                        buf_r <= buf_r >> 44;
                        fill  <= fill - 7'd44;
                    end
                    default: ;
                endcase
                valid_out <= 1'b1;
            end
        end
    end
endmodule
