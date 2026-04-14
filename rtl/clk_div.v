`timescale 1ns/1ps

// clk_div: 100 MHz girişten 1 kHz 7-segment refresh tick üretir.
// tick: her 1 ms'de bir saat çevrimi genişliğinde HIGH darbe.
// Bölme oranı: CLK_FREQ / REFRESH_HZ = 100_000 çevrim.
module clk_div #(
    parameter CLK_FREQ   = 100_000_000,  // Giriş saat frekansı (Hz)
    parameter REFRESH_HZ = 1_000         // Hedef refresh frekansı (Hz)
)(
    input  wire clk,
    input  wire rst,
    output reg  tick  // 1 çevrim genişliğinde 1 kHz darbe
);

    localparam COUNT_MAX = CLK_FREQ / REFRESH_HZ - 1;  // 99_999

    // 17 bit: 2^17 = 131_072 > 99_999
    reg [16:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count <= 17'd0;
            tick  <= 1'b0;
        end else if (count == COUNT_MAX[16:0]) begin
            count <= 17'd0;
            tick  <= 1'b1;
        end else begin
            count <= count + 17'd1;
            tick  <= 1'b0;
        end
    end

endmodule
