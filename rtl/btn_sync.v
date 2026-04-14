`timescale 1ns/1ps

// btn_sync: 2-FF senkronizör + debounce + tek çevrimlik yükselen-kenar pulse
//
// Sinyal akışı:
//   btn_in (async) → [FF1 → FF2] → debounce sayacı → kenar dedektörü → btn_pulse
//
// DEBOUNCE_COUNT: sinyalin kararlı sayılması için gereken çevrim sayısı
//   Varsayılan 1_000_000 → 100 MHz'de ~10 ms
module btn_sync #(
    parameter DEBOUNCE_COUNT = 1_000_000
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output wire btn_pulse
);

    // -----------------------------------------------------------------
    // Aşama 1: 2-FF senkronizör
    // -----------------------------------------------------------------
    reg sync_0, sync_1;

    always @(posedge clk) begin
        if (rst) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // -----------------------------------------------------------------
    // Aşama 2: Debounce sayacı
    //   sync_1 == debounced  → sayaç sıfırlanır (kararlı durum)
    //   sync_1 != debounced  → sayaç artar; DEBOUNCE_COUNT-1'e ulaşırsa
    //                          debounced güncellenir
    // -----------------------------------------------------------------
    reg [$clog2(DEBOUNCE_COUNT)-1:0] count;
    reg debounced;

    always @(posedge clk) begin
        if (rst) begin
            count     <= 0;
            debounced <= 1'b0;
        end else if (sync_1 == debounced) begin
            count <= 0;
        end else if (count == DEBOUNCE_COUNT - 1) begin
            debounced <= sync_1;
            count     <= 0;
        end else begin
            count <= count + 1;
        end
    end

    // -----------------------------------------------------------------
    // Aşama 3: Yükselen-kenar dedektörü → tek çevrimlik pulse
    // -----------------------------------------------------------------
    reg debounced_prev;

    always @(posedge clk) begin
        if (rst)
            debounced_prev <= 1'b0;
        else
            debounced_prev <= debounced;
    end

    assign btn_pulse = debounced & ~debounced_prev;

endmodule
