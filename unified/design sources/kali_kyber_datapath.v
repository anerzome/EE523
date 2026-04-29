`timescale 1ns/1ps
//==============================================================================
// kali_kyber_datapath.v  -  FIXED for Verilog-2001 / Vivado xvlog
//
// Changes from previous version:
//  1. "parameter integer" -> "parameter" (integer keyword in #() illegal
//     in Verilog-2001 strict mode that xvlog uses by default)
//  2. localparam MASK=(1<<D)-1 removed - param-dependent localparams
//     cause elaboration errors; replaced with always @(*) case statements
//  3. {(25-D){1'b0}} replaced with explicit 24-bit multiply width
//  4. All dynamic shifts use a wire [4:0] D5=D[4:0] for clean elaboration
//  5. Port widths declared at max (11-bit coeff, not [D-1:0]) to avoid
//     param-dependent port width; TB zero-pads upper bits naturally
//  6. ACC_W fixed at 18 (= max D + 7 = 11+7) - no param-dependent sizing
//==============================================================================


//==============================================================================
// compress_unit
//==============================================================================
module compress_unit #(
    parameter D = 11,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [11:0] i_coeff,
    input  wire        i_valid,
    output wire        i_ready,

    output reg  [10:0] o_coeff,    // full 11 bits; TB uses [D-1:0]
    output reg         o_valid,
    input  wire        o_ready
);
    wire stall = o_valid & ~o_ready;
    assign i_ready = ~stall;

    reg [39:0] t;
    reg [10:0] y_comb;

    always @(*) begin
        t      = 40'd0;
        y_comb = 11'd0;
        case (D)
            1:  begin
                    t      = 40'd10079    * {28'd0, i_coeff};
                    y_comb = t[34:24] + {10'd0, t[23]};
                    y_comb = y_comb & 11'h001;
                end
            4:  begin
                    t      = 40'd315      * {28'd0, i_coeff};
                    y_comb = t[26:16] + {10'd0, t[15]};
                    y_comb = y_comb & 11'h00F;
                end
            5:  begin
                    t      = 40'd630      * {28'd0, i_coeff};
                    y_comb = t[26:16] + {10'd0, t[15]};
                    y_comb = y_comb & 11'h01F;
                end
            10: begin
                    t      = 40'd5160669  * {28'd0, i_coeff};
                    y_comb = t[34:24] + {10'd0, t[23]};
                    y_comb = y_comb & 11'h3FF;
                end
            11: begin
                    t      = 40'd10321339 * {28'd0, i_coeff};
                    y_comb = t[34:24] + {10'd0, t[23]};
                    y_comb = y_comb & 11'h7FF;
                end
            default: y_comb = 11'd0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_coeff <= 11'd0;
            o_valid <= 1'b0;
        end else if (!stall) begin
            o_valid <= i_valid;
            o_coeff <= y_comb;
        end
    end

endmodule


//==============================================================================
// decompress_unit
//==============================================================================
module decompress_unit #(
    parameter D = 11,
    parameter Q = 3329,
    parameter N = 256
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [10:0] i_coeff,    // TB drives [D-1:0]; upper bits zero
    input  wire        i_valid,
    output wire        i_ready,

    output reg  [11:0] o_coeff,
    output reg         o_valid,
    input  wire        o_ready
);
    wire stall = o_valid & ~o_ready;
    assign i_ready = ~stall;

    // Q*y: max 3329*2047 = 6,814,063 < 2^23 - 24 bits sufficient
    reg [23:0] num;
    reg [11:0] x_comb;

    // 2^(D-1) as a case-derived constant
    reg [10:0] half;
    always @(*) begin
        case (D)
            1:  half = 11'd1;
            4:  half = 11'd8;
            5:  half = 11'd16;
            10: half = 11'd512;
            11: half = 11'd1024;
            default: half = 11'd1;
        endcase
    end

    always @(*) begin
        num    = 13'd3329 * {13'd0, i_coeff};
        x_comb = (num + {13'd0, half}) >> D;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            o_coeff <= 12'd0;
            o_valid <= 1'b0;
        end else if (!stall) begin
            o_valid <= i_valid;
            o_coeff <= x_comb;
        end
    end

endmodule


//==============================================================================
// encode_unit
// Packs N D-bit coefficients into NBYTES bytes, LSB-first (Kyber spec)
//==============================================================================
module encode_unit #(
    parameter D      = 11,
    parameter N      = 256,
    parameter NBYTES = 352
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [10:0] i_coeff,    // [D-1:0] significant
    input  wire        i_valid,
    output reg         i_ready,

    output reg  [7:0]  o_byte,
    output reg         o_valid,
    input  wire        o_ready,
    output reg         o_done
);
    // Fixed accumulator width: D_MAX + 7 = 11 + 7 = 18
    localparam ACC_W = 18;

    reg [ACC_W-1:0] acc;
    reg [4:0]       fill;
    reg [8:0]       coeff_cnt;   // max 256 → 9 bits
    reg [9:0]       byte_cnt;    // max 352 → 10 bits

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_COEFF = 2'd1;
    localparam [1:0] S_FLUSH = 2'd2;
    localparam [1:0] S_DONE  = 2'd3;

    reg [1:0] state;

    // D as 5-bit for shift operations
    wire [4:0] D5 = D[4:0];

    // Mask for D bits - avoids (1<<D)-1 localparam
    reg [10:0] coeff_mask;
    always @(*) begin
        case (D)
            1:  coeff_mask = 11'h001;
            4:  coeff_mask = 11'h00F;
            5:  coeff_mask = 11'h01F;
            10: coeff_mask = 11'h3FF;
            11: coeff_mask = 11'h7FF;
            default: coeff_mask = 11'h7FF;
        endcase
    end

    wire [10:0] coeff_in_masked = i_coeff & coeff_mask;

    always @(posedge clk) begin
        if (!rst_n) begin
            acc       <= {ACC_W{1'b0}};
            fill      <= 5'd0;
            coeff_cnt <= 9'd0;
            byte_cnt  <= 10'd0;
            state     <= S_IDLE;
            i_ready   <= 1'b0;
            o_byte    <= 8'd0;
            o_valid   <= 1'b0;
            o_done    <= 1'b0;
        end else begin
            o_done <= 1'b0;

            case (state)

                S_IDLE: begin
                    acc       <= {ACC_W{1'b0}};
                    fill      <= 5'd0;
                    coeff_cnt <= 9'd0;
                    byte_cnt  <= 10'd0;
                    o_valid   <= 1'b0;
                    i_ready   <= 1'b1;
                    state     <= S_COEFF;
                end

                S_COEFF: begin
                    i_ready <= 1'b1;

                    // Accept one coefficient
                    if (i_valid && i_ready) begin
                        acc       <= acc | ({{(ACC_W-11){1'b0}}, coeff_in_masked} << fill);
                        fill      <= fill + D5;
                        coeff_cnt <= coeff_cnt + 1'b1;
                    end

                    // Emit one byte when >= 8 bits in accumulator
                    if (fill >= 5'd8) begin
                        if (!o_valid || o_ready) begin
                            o_byte   <= acc[7:0];
                            o_valid  <= 1'b1;
                            acc      <= acc >> 8;
                            fill     <= fill - 5'd8;
                            byte_cnt <= byte_cnt + 1'b1;
                        end else begin
                            // downstream stalled - pause input
                            i_ready <= 1'b0;
                        end
                    end

                    // All N coefficients consumed
                    if (coeff_cnt == N[8:0]) begin
                        i_ready <= 1'b0;
                        state   <= S_FLUSH;
                    end
                end

                S_FLUSH: begin
                    i_ready <= 1'b0;
                    if (fill > 5'd0) begin
                        if (!o_valid || o_ready) begin
                            o_byte   <= acc[7:0];
                            o_valid  <= 1'b1;
                            acc      <= acc >> 8;
                            fill     <= (fill >= 5'd8) ? (fill - 5'd8) : 5'd0;
                            byte_cnt <= byte_cnt + 1'b1;
                        end
                    end else begin
                        o_valid <= 1'b0;
                        state   <= S_DONE;
                    end
                end

                S_DONE: begin
                    o_done  <= 1'b1;
                    o_valid <= 1'b0;
                    state   <= S_IDLE;
                end

            endcase
        end
    end

endmodule


//==============================================================================
// decode_unit
// Unpacks NBYTES bytes -> N D-bit coefficients, LSB-first
//==============================================================================
module decode_unit #(
    parameter D      = 11,
    parameter N      = 256,
    parameter NBYTES = 352
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  i_byte,
    input  wire        i_valid,
    output reg         i_ready,

    output reg  [10:0] o_coeff,    // [D-1:0] significant
    output reg         o_valid,
    input  wire        o_ready,
    output reg         o_done
);
    localparam ACC_W = 18;

    reg [ACC_W-1:0] acc;
    reg [4:0]       fill;
    reg [9:0]       byte_cnt;
    reg [8:0]       coeff_cnt;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_BYTE = 2'd1;
    localparam [1:0] S_DONE = 2'd2;

    reg [1:0] state;

    wire [4:0] D5 = D[4:0];

    // Extract D bits from accumulator bottom - case avoids dynamic bit-select
    reg [10:0] coeff_out;
    always @(*) begin
        case (D)
            1:  coeff_out = {10'd0, acc[0]};
            4:  coeff_out = {7'd0,  acc[3:0]};
            5:  coeff_out = {6'd0,  acc[4:0]};
            10: coeff_out = {1'd0,  acc[9:0]};
            11: coeff_out =         acc[10:0];
            default: coeff_out = acc[10:0];
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            acc       <= {ACC_W{1'b0}};
            fill      <= 5'd0;
            byte_cnt  <= 10'd0;
            coeff_cnt <= 9'd0;
            state     <= S_IDLE;
            i_ready   <= 1'b0;
            o_coeff   <= 11'd0;
            o_valid   <= 1'b0;
            o_done    <= 1'b0;
        end else begin
            o_done <= 1'b0;

            case (state)

                S_IDLE: begin
                    acc       <= {ACC_W{1'b0}};
                    fill      <= 5'd0;
                    byte_cnt  <= 10'd0;
                    coeff_cnt <= 9'd0;
                    o_valid   <= 1'b0;
                    i_ready   <= 1'b1;
                    state     <= S_BYTE;
                end

                S_BYTE: begin
                    i_ready <= 1'b1;

                    // Accept one byte
                    if (i_valid && i_ready) begin
                        acc      <= acc | ({{(ACC_W-8){1'b0}}, i_byte} << fill);
                        fill     <= fill + 5'd8;
                        byte_cnt <= byte_cnt + 1'b1;
                    end

                    // Emit one coefficient when >= D bits available
                    if (fill >= D5) begin
                        if (!o_valid || o_ready) begin
                            o_coeff   <= coeff_out;
                            o_valid   <= 1'b1;
                            acc       <= acc >> D;
                            fill      <= fill - D5;
                            coeff_cnt <= coeff_cnt + 1'b1;
                        end else begin
                            i_ready <= 1'b0;
                        end
                    end else begin
                        i_ready <= (byte_cnt < NBYTES[9:0]);
                    end

                    if (coeff_cnt == N[8:0]) begin
                        i_ready <= 1'b0;
                        o_valid <= 1'b0;
                        state   <= S_DONE;
                    end
                end

                S_DONE: begin
                    o_done <= 1'b1;
                    state  <= S_IDLE;
                end

            endcase
        end
    end

endmodule