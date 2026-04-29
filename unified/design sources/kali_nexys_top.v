`timescale 1ns / 1ps
//==============================================================================
// kali_nexys_top.v
// Top-level wrapper for KaLi on Nexys A7-100T (xc7a100tcsg324-1)
//
// ┌─────────────────────────────────────────────────────────────────┐
// │                     INPUT MAPPING                               │
// │  SW[0]        → mode         (0=Dilithium, 1=Kyber)            │
// │  SW[1]        → inv          (0=NTT forward, 1=INTT inverse)   │
// │  SW[2]        → compress_sel (0=decompress, 1=compress)        │
// │  SW[6:3]      → d[3:0]       (compress bits: 1/4/5/10/11)      │
// │  SW[15:7]     → coeff_in[8:0] (lower 9 bits of coefficient)    │
// │  CPU_RESETN   → rst_n        (active-low reset, held = reset)  │
// │  BTNC         → valid_in     (press to trigger one operation)  │
// │  BTNU         → page_up      (cycle 7-seg display page up)     │
// │  BTND         → page_dn      (cycle 7-seg display page down)   │
// ├─────────────────────────────────────────────────────────────────┤
// │                     OUTPUT MAPPING                              │
// │  LED[15:0]    → result[15:0] (lower 16 bits of active result)  │
// │  LED16_R      → mode indicator (1 = Kyber)                     │
// │  LED16_G      → inv indicator  (1 = INTT)                      │
// │  LED16_B      → valid_out pulse (blinks when result ready)     │
// │  LED17_R      → compress_sel indicator                         │
// │  7-segment    → full numeric result (8 hex digits, 2 pages)    │
// ├─────────────────────────────────────────────────────────────────┤
// │                  WHAT EACH UNIT OUTPUTS                         │
// │                                                                 │
// │  mod_red (page 0):                                              │
// │    Dilithium: coeff_in^2 mod 8380417  shown on 7-seg           │
// │    Kyber:     coeff_in^2 mod 3329 (x2 lanes, same input)       │
// │                                                                 │
// │  compress/decompress (page 1):                                  │
// │    Shows compressed or decompressed value of coeff_in           │
// │                                                                 │
// │  7-segment pages (BTNU/BTND to switch):                        │
// │    Page 0: mod_red result   (hex, 8 digits)                    │
// │    Page 1: compress result  (hex, 4 digits) + d value          │
// └─────────────────────────────────────────────────────────────────┘
//
// Clock: 100 MHz on-board oscillator → used directly
// All internal logic runs at 100 MHz.
//==============================================================================

module kali_nexys_top (
    // Clock & Reset
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,    // active LOW

    // Switches
    input  wire [15:0] SW,

    // Buttons
    input  wire        BTNC,          // valid_in trigger
    input  wire        BTNU,          // page up
    input  wire        BTND,          // page down

    // LEDs
    output wire [15:0] LED,
    output wire        LED16_R,
    output wire        LED16_G,
    output wire        LED16_B,
    output wire        LED17_R,
    output wire        LED17_G,
    output wire        LED17_B,

    // 7-Segment Display
    output wire [7:0]  AN,
    output wire        CA, CB, CC, CD, CE, CF, CG,
    output wire        DP
);

    // =========================================================================
    // 1. SIGNAL DECLARATIONS
    // =========================================================================

    wire clk  = CLK100MHZ;
    wire rst  = ~CPU_RESETN;          // active-high internal reset

    // --- Switch decoding ---
    wire        mode         = SW[0];
    wire        inv          = SW[1];
    wire        compress_sel = SW[2];
    wire [3:0]  d            = SW[6:3];
    wire [11:0] coeff_in     = {3'b000, SW[15:7]};  // 9-bit switch → 12-bit coeff

    // --- Button debounce outputs ---
    wire valid_in_db;
    wire btnu_db;
    wire btnd_db;

    // --- mod_red wiring ---
    // We feed coeff_in * coeff_in as a demonstration product.
    // Kyber:    k_ip1 = k_ip2 = coeff_in (packed 24-bit, two 12-bit lanes)
    // Dilithium: d_ip = coeff_in * coeff_in (23-bit * 23-bit = 46-bit)
    wire [23:0] k_ip1 = {12'b0, coeff_in};          // Kyber low lane = coeff_in
    wire [23:0] k_ip2 = {12'b0, coeff_in};          // Kyber high lane = coeff_in
    wire [45:0] d_ip  = {23'b0, coeff_in} *
                        {23'b0, coeff_in};           // Dilithium: coeff^2
    wire [29:0] modred_result;

    // --- BFU wiring ---
    // xj = coeff_in (upper), xjt = coeff_in shifted by 1, w = SW[15:7] as twiddle
    wire [23:0] bfu_xj  = mode ? {coeff_in, coeff_in} : {12'b0, coeff_in};
    wire [23:0] bfu_xjt = mode ? {coeff_in, coeff_in} : {12'b0, coeff_in};
    wire [23:0] bfu_w   = mode ? {SW[15:7], 3'b0, SW[15:7], 3'b0}
                               : {1'b0, coeff_in, 11'b0};
    wire [23:0] bfu_y0, bfu_y1;

    // --- compress/decompress wiring ---
    wire [11:0] comp_result;

    // --- page register ---
    reg  [1:0] page;

    // --- 7-segment input (32-bit value to display) ---
    reg  [31:0] seg_value;

    // --- valid_out capture ---
    reg  valid_out_r;

    // =========================================================================
    // 2. BUTTON DEBOUNCERS (simple synchronous, ~10ms at 100MHz)
    // =========================================================================

    debounce db_valid (.clk(clk),.rst(rst),.btn_in(BTNC),.btn_out(valid_in_db));
    debounce db_btnu  (.clk(clk),.rst(rst),.btn_in(BTNU),.btn_out(btnu_db));
    debounce db_btnd  (.clk(clk),.rst(rst),.btn_in(BTND),.btn_out(btnd_db));

    // =========================================================================
    // 3. KaLi MODULES
    // =========================================================================

    // --- Modular Reduction ---
    mod_red mr_inst (
        .clk   (clk),
        .rst   (rst),
        .dk    (mode),
        .k_ip1 (k_ip1),
        .k_ip2 (k_ip2),
        .d_ip  (d_ip),
        .c     (modred_result)
    );

    // --- Butterfly Unit ---
    unified_bfu bfu_inst (
        .clk  (clk),
        .rst  (rst),
        .xj   (bfu_xj),
        .xjt  (bfu_xjt),
        .w    (bfu_w),
        .mode (mode),
        .inv  (inv),
        .y0   (bfu_y0),
        .y1   (bfu_y1)
    );

    // --- Compress / Decompress ---
    compress_decompress cd_inst (
        .clk      (clk),
        .rst      (rst),
        .compress (compress_sel),
        .data_in  (coeff_in),
        .d        (d),
        .data_out (comp_result)
    );

    // =========================================================================
    // 4. PAGE CONTROL (BTNU = next page, BTND = prev page)
    // =========================================================================

    always @(posedge clk) begin
        if (rst) begin
            page <= 2'd0;
        end else begin
            if (btnu_db && page < 2'd1) page <= page + 1;
            if (btnd_db && page > 2'd0) page <= page - 1;
        end
    end

    // =========================================================================
    // 5. VALID_OUT CAPTURE
    //    We use valid_in_db as a strobe — result is ready 2 cycles later
    //    for mod_red (2-cycle pipeline), or 1 cycle for compress.
    //    We just keep a registered "result ready" flag for LED blink.
    // =========================================================================

    reg [3:0] valid_sr;
    always @(posedge clk) begin
        if (rst) begin
            valid_sr  <= 4'b0;
            valid_out_r <= 1'b0;
        end else begin
            valid_sr  <= {valid_sr[2:0], valid_in_db};
            valid_out_r <= valid_sr[3];  // pulse 4 cycles after button press
        end
    end

    // =========================================================================
    // 6. 7-SEGMENT MUX — select what to display by page
    //    Page 0: mod_red result (30-bit, shown as 8 hex digits)
    //    Page 1: compress result (12-bit) + d value (4-bit) on upper digits
    // =========================================================================

    always @(*) begin
        case (page)
            2'd0: seg_value = modred_result[31:0];         // mod_red output
            2'd1: seg_value = {16'b0, comp_result, d};     // compress + d bits
            default: seg_value = 32'hDEAD_BEEF;
        endcase
    end

    // =========================================================================
    // 7. LED OUTPUTS
    //    LED[15:0]  → lower 16 bits of the currently selected result
    //    LED16_R    → mode (Kyber=1)
    //    LED16_G    → inv  (INTT=1)
    //    LED16_B    → valid_out pulse
    //    LED17_R    → compress_sel
    //    LED17_G    → page[0]
    //    LED17_B    → page[1]
    // =========================================================================

    assign LED = seg_value[15:0];

    assign LED16_R = mode;
    assign LED16_G = inv;
    assign LED16_B = valid_out_r;
    assign LED17_R = compress_sel;
    assign LED17_G = page[0];
    assign LED17_B = page[1];

    // =========================================================================
    // 8. 7-SEGMENT DISPLAY CONTROLLER
    // =========================================================================

    seg7_controller seg_ctrl (
        .clk      (clk),
        .rst      (rst),
        .value    (seg_value),
        .dp_mask  (8'b00000000),   // no decimal points
        .AN       (AN),
        .segments ({CA,CB,CC,CD,CE,CF,CG}),
        .DP       (DP)
    );

endmodule


//==============================================================================
// debounce
// Simple synchronous debouncer: requires signal stable for ~10ms (1M cycles
// at 100MHz) before passing through. Outputs a single-cycle pulse.
//==============================================================================
module debounce (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_out
);
    reg [19:0] cnt;
    reg        sync0, sync1, stable;

    always @(posedge clk) begin
        if (rst) begin
            cnt <= 0; sync0 <= 0; sync1 <= 0; stable <= 0; btn_out <= 0;
        end else begin
            sync0 <= btn_in;
            sync1 <= sync0;

            if (sync1 != stable) begin
                cnt <= cnt + 1;
                if (cnt == 20'hFFFFF) begin
                    stable  <= sync1;
                    cnt     <= 0;
                end
            end else begin
                cnt <= 0;
            end

            // single-cycle pulse on rising edge of stable
            btn_out <= (sync1 & ~stable);
        end
    end
endmodule


//==============================================================================
// seg7_controller
// Drives the 8-digit 7-segment display on Nexys A7.
// Takes a 32-bit value and displays it as 8 hex digits.
// Multiplexes at ~1kHz (100MHz / 100000 = 1kHz refresh per digit).
//
// Digit mapping (left to right):
//   Digit 7 (AN[7]) = value[31:28]  (most significant)
//   Digit 0 (AN[0]) = value[3:0]    (least significant)
//==============================================================================
module seg7_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] value,
    input  wire [7:0]  dp_mask,   // which digits have decimal point lit
    output reg  [7:0]  AN,
    output reg  [6:0]  segments,  // {CA,CB,CC,CD,CE,CF,CG}
    output reg         DP
);
    // Refresh counter — 100MHz / 100000 = 1kHz per digit, 8kHz full cycle
    reg [16:0] refresh_cnt;
    reg [2:0]  digit_sel;

    always @(posedge clk) begin
        if (rst) begin
            refresh_cnt <= 0;
            digit_sel   <= 0;
        end else begin
            if (refresh_cnt == 17'd99999) begin
                refresh_cnt <= 0;
                digit_sel   <= digit_sel + 1;
            end else begin
                refresh_cnt <= refresh_cnt + 1;
            end
        end
    end

    // Anode decode — active LOW on Nexys A7
    always @(*) begin
        AN = 8'b11111111;
        AN[digit_sel] = 1'b0;
    end

    // Nibble select
    reg [3:0] nibble;
    always @(*) begin
        case (digit_sel)
            3'd7: nibble = value[31:28];
            3'd6: nibble = value[27:24];
            3'd5: nibble = value[23:20];
            3'd4: nibble = value[19:16];
            3'd3: nibble = value[15:12];
            3'd2: nibble = value[11:8];
            3'd1: nibble = value[7:4];
            3'd0: nibble = value[3:0];
        endcase
    end

    // Decimal point
    always @(*) DP = ~dp_mask[digit_sel];

    // 7-segment hex decoder
    // Segments: {CA, CB, CC, CD, CE, CF, CG}  — active LOW on Nexys A7
    // Segment layout: CA=top, CB=top-right, CC=bot-right,
    //                 CD=bot,  CE=bot-left,  CF=top-left, CG=middle
    always @(*) begin
        case (nibble)
            4'h0: segments = 7'b0000001;   // 0
            4'h1: segments = 7'b1001111;   // 1
            4'h2: segments = 7'b0010010;   // 2
            4'h3: segments = 7'b0000110;   // 3
            4'h4: segments = 7'b1001100;   // 4
            4'h5: segments = 7'b0100100;   // 5
            4'h6: segments = 7'b0100000;   // 6
            4'h7: segments = 7'b0001111;   // 7
            4'h8: segments = 7'b0000000;   // 8
            4'h9: segments = 7'b0000100;   // 9
            4'hA: segments = 7'b0001000;   // A
            4'hB: segments = 7'b1100000;   // b
            4'hC: segments = 7'b0110001;   // C
            4'hD: segments = 7'b1000010;   // d
            4'hE: segments = 7'b0110000;   // E
            4'hF: segments = 7'b0111000;   // F
        endcase
    end

endmodule
