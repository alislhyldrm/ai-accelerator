`timescale 1ns/1ps

module tb_clk_div;

    // --- DUT portları ---
    reg  clk;
    reg  rst;
    wire tick;

    // --- DUT ---
    // Küçük parametrelerle hız kazanmak için: 100 Hz hedef (1_000_000 / 100 = 10_000 çevrim)
    // Ancak gerçek parametrelerle doğruluk testi yapıyoruz — CLK_FREQ küçültüldü.
    // 10 MHz / 1000 Hz = 10_000 çevrim → simülasyon ~20ms sürer (10ns periyot × 20_000)
    localparam CLK_FREQ_TB   = 10_000_000;
    localparam REFRESH_HZ_TB = 1_000;
    localparam COUNT_MAX_TB  = CLK_FREQ_TB / REFRESH_HZ_TB;  // 10_000 çevrim = 1 ms

    clk_div #(
        .CLK_FREQ   (CLK_FREQ_TB),
        .REFRESH_HZ (REFRESH_HZ_TB)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .tick (tick)
    );

    // --- Saat: 10 MHz → 100 ns periyot ---
    initial clk = 0;
    always #50 clk = ~clk;  // 50 ns yarım periyot

    // --- Ölçüm değişkenleri ---
    integer tick_count;
    time    t0, t1;
    integer errors;

    initial begin
        errors     = 0;
        tick_count = 0;
        t0         = 0;
        t1         = 0;

        // Reset uygula
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;

        // --- Test 1: İlk tick'i bekle ---
        @(posedge tick);
        t0 = $time;
        tick_count = tick_count + 1;

        // --- Test 2: İkinci tick'i bekle ---
        @(posedge tick);
        t1 = $time;
        tick_count = tick_count + 1;

        // Periyot = t1 - t0; beklenen: COUNT_MAX_TB çevrim × 100 ns = 1_000_000 ns
        if ((t1 - t0) !== COUNT_MAX_TB * 100) begin
            $display("FAIL  periyot=%0t ns, beklenen=%0d ns",
                     t1 - t0, COUNT_MAX_TB * 100);
            errors = errors + 1;
        end else begin
            $display("PASS  periyot=%0t ns (1 ms = %0d çevrim)",
                     t1 - t0, COUNT_MAX_TB);
        end

        // --- Test 3: tick genişliği 1 çevrim mi? ---
        // tick posedge'den sonra negedge'e kadar olan süre = 100 ns olmalı
        begin : width_check
            time rise, fall;
            @(posedge tick); rise = $time;
            @(negedge tick); fall = $time;
            if ((fall - rise) !== 100) begin
                $display("FAIL  tick genişliği=%0t ns, beklenen=100 ns", fall - rise);
                errors = errors + 1;
            end else begin
                $display("PASS  tick genişliği=%0t ns (1 çevrim)", fall - rise);
            end
        end

        // --- Test 4: Reset sonrası tick sıfırlanıyor mu? ---
        rst = 1;
        @(posedge clk);
        if (tick !== 1'b0) begin
            $display("FAIL  reset sırasında tick=%b, beklenen=0", tick);
            errors = errors + 1;
        end else begin
            $display("PASS  reset sırasında tick=0");
        end
        rst = 0;

        // Sonuç
        if (errors == 0)
            $display("ALL PASS — clk_div doğrulandı");
        else
            $display("TOPLAM HATA: %0d", errors);

        $finish;
    end

    // Zaman aşımı
    initial #50_000_000 begin
        $display("TIMEOUT — simülasyon bitmedi");
        $finish;
    end

endmodule
