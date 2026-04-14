`timescale 1ns/1ps

// seg7_drv: 4 haneli hex → 7-segment multiplexer sürücüsü
//
// hex_val[15:12]=digit3 (sol) ... hex_val[3:0]=digit0 (sağ)
// tick: clk_div'den gelen 1 kHz refresh darbesi — her tick'te sonraki hane
// an[3:0]  : active-low anode seçim  (an[3]=sol, an[0]=sağ)
// seg[6:0] : active-low segment sürücü ({g, f, e, d, c, b, a})
//
// Basys3 donanımında an ve seg pinleri active-low'dur.
module seg7_drv (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick,       // 1 kHz multiplexing darbesi
    input  wire [15:0] hex_val,    // gösterilecek 4 hex hanesi
    output reg  [6:0]  seg,        // segment sürücü (active-low)
    output reg  [3:0]  an          // anode seçim   (active-low)
);

    // -----------------------------------------------------------------
    // 2-bit digit seçim sayacı — tick gelince sıradaki haneye geç
    // -----------------------------------------------------------------
    reg [1:0] digit_sel;

    always @(posedge clk) begin
        if (rst)
            digit_sel <= 2'd0;
        else if (tick)
            digit_sel <= digit_sel + 2'd1;
    end

    // -----------------------------------------------------------------
    // Seçilen hanenin nibble'ı (combinational)
    // -----------------------------------------------------------------
    reg [3:0] nibble;

    always @(*) begin
        case (digit_sel)
            2'd0: nibble = hex_val[3:0];
            2'd1: nibble = hex_val[7:4];
            2'd2: nibble = hex_val[11:8];
            2'd3: nibble = hex_val[15:12];
        endcase
    end

    // -----------------------------------------------------------------
    // Anode seçimi: sadece seçili hane LOW
    // an[3]=digit3(sol) ... an[0]=digit0(sağ)
    // -----------------------------------------------------------------
    always @(*) begin
        case (digit_sel)
            2'd0: an = 4'b1110;
            2'd1: an = 4'b1101;
            2'd2: an = 4'b1011;
            2'd3: an = 4'b0111;
        endcase
    end

    // -----------------------------------------------------------------
    // Hex → 7-segment dekoderi (active-low, {g, f, e, d, c, b, a})
    //   Segment düzeni: a=üst, b=sağ-üst, c=sağ-alt, d=alt,
    //                   e=sol-alt, f=sol-üst, g=orta
    // -----------------------------------------------------------------
    always @(*) begin
        case (nibble)
            4'h0: seg = 7'h40;   // 0b1000000
            4'h1: seg = 7'h79;   // 0b1111001
            4'h2: seg = 7'h24;   // 0b0100100
            4'h3: seg = 7'h30;   // 0b0110000
            4'h4: seg = 7'h19;   // 0b0011001
            4'h5: seg = 7'h12;   // 0b0010010
            4'h6: seg = 7'h02;   // 0b0000010
            4'h7: seg = 7'h78;   // 0b1111000
            4'h8: seg = 7'h00;   // 0b0000000
            4'h9: seg = 7'h10;   // 0b0010000
            4'hA: seg = 7'h08;   // 0b0001000
            4'hB: seg = 7'h03;   // 0b0000011
            4'hC: seg = 7'h46;   // 0b1000110
            4'hD: seg = 7'h21;   // 0b0100001
            4'hE: seg = 7'h06;   // 0b0000110
            4'hF: seg = 7'h0E;   // 0b0001110
        endcase
    end

endmodule
