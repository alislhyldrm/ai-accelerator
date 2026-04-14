`timescale 1ns/1ps

// DEBOUNCE_COUNT=10: 2 çevrim sync + 10 çevrim debounce + 1 kenar = 13 çevrim
// btn_in yükseldikten 13 çevrim sonra tek bir pulse beklenir.

module tb_btn_sync;

    // --- DUT portları ---
    reg  clk;
    reg  rst;
    reg  btn_in;
    wire btn_pulse;

    // --- DUT: hızlı test için DEBOUNCE_COUNT=10 ---
    btn_sync #(.DEBOUNCE_COUNT(10)) dut (
        .clk      (clk),
        .rst      (rst),
        .btn_in   (btn_in),
        .btn_pulse(btn_pulse)
    );

    // --- Saat: 10 ns periyot ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test sayaçları ---
    integer pass_count;
    integer fail_count;

    // --- Pulse sayacı: her posedge'de btn_pulse izlenir ---
    integer pulse_count;
    always @(posedge clk) begin
        if (btn_pulse)
            pulse_count = pulse_count + 1;
    end

    task check;
        input integer actual;
        input integer expected;
        input integer test_id;
        begin
            if (actual === expected) begin
                $display("PASS [T%0d] deger=%0d", test_id, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [T%0d] deger=%0d (beklenen=%0d)",
                         test_id, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task do_reset;
        begin
            rst    = 1;
            btn_in = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 0;
        end
    endtask

    initial begin
        pass_count  = 0;
        fail_count  = 0;
        pulse_count = 0;
        rst         = 1;
        btn_in      = 0;

        do_reset;

        // ============================================================
        // SENARYO 1: Normal Basış
        //   btn_in sabit yüksek → sync(2) + debounce(10) + kenar(1) = 13 çevrim
        //   → 15 çevrim bekle, tam 1 pulse beklenir
        //   btn_in serbest bırakılınca ek pulse üretilmemeli (yalnız yükselen kenar)
        // ============================================================
        $display("--- Senaryo 1: Normal Basış ---");
        pulse_count = 0;

        btn_in = 1;
        repeat (15) @(posedge clk); #1;
        $display("  15 cevrim beklendi, pulse_count=%0d", pulse_count);
        check(pulse_count, 1, 1);

        btn_in = 0;                          // bırak
        repeat (15) @(posedge clk); #1;
        $display("  Birakma sonrasi, pulse_count=%0d (artmamali)", pulse_count);
        check(pulse_count, 1, 2);

        do_reset;

        // ============================================================
        // SENARYO 2: Gürültülü Basış (Bounce)
        //   2 × (4 çevrim yüksek / 5 çevrim alçak): sayaç hiç 9'a ulaşamaz
        //   Bounce sırasında: 0 pulse
        //   Ardından 15 çevrim kararlı basış: 1 pulse
        //
        //   Neden sayaç 9'a ulaşamaz?
        //     sync gecikmesi 2 çevrim, 4 çevrim yüksek → sync_1 en fazla 2 çevrim
        //     yüksek kalır → count maks 2–3; btn_in düşünce sayaç sıfırlanır
        // ============================================================
        $display("--- Senaryo 2: Gurultulu Basıs ---");
        pulse_count = 0;

        btn_in = 1; repeat (4) @(posedge clk); #1;  // bounce 1 yüksek
        btn_in = 0; repeat (5) @(posedge clk); #1;  // bounce 1 alçak
        btn_in = 1; repeat (4) @(posedge clk); #1;  // bounce 2 yüksek
        btn_in = 0; repeat (5) @(posedge clk); #1;  // bounce 2 alçak

        $display("  2x bounce sonrasi, pulse_count=%0d (0 olmali)", pulse_count);
        check(pulse_count, 0, 3);

        btn_in = 1;
        repeat (15) @(posedge clk); #1;
        $display("  Kararli basıs sonrasi, pulse_count=%0d", pulse_count);
        check(pulse_count, 1, 4);

        do_reset;

        // ============================================================
        // SENARYO 3: Debounce Sürerken Reset
        //   btn_in yüksek, 5 çevrimde kesilir → sayaç tamamlanmadan sıfırlanır
        //   Reset sırasında ve sonrasında pulse üretilmemeli
        //   Reset sonrası modül yeniden doğru çalışmalı
        // ============================================================
        $display("--- Senaryo 3: Debounce Sururken Reset ---");
        pulse_count = 0;

        btn_in = 1;
        repeat (5) @(posedge clk); #1;      // debounce başlar (~sayaç=3), tamamlanmaz
        $display("  5 cevrim (debounce yari): pulse_count=%0d (0 olmali)", pulse_count);
        check(pulse_count, 0, 5);

        rst = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst    = 0;
        btn_in = 0;
        repeat (5) @(posedge clk); #1;

        $display("  Reset sonrasi: pulse_count=%0d (0 olmali)", pulse_count);
        check(pulse_count, 0, 6);

        // Reset sonrası normal basış yine doğru çalışmalı
        btn_in = 1;
        repeat (15) @(posedge clk); #1;
        $display("  Reset sonrasi normal basıs: pulse_count=%0d", pulse_count);
        check(pulse_count, 1, 7);

        // ============================================================
        // Sonuç
        // ============================================================
        $display("-----------------------------");
        $display("Sonuc: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("TUM TESTLER GECTI");
        else
            $display("BAZI TESTLER BASARISIZ");
        $display("-----------------------------");

        $finish;
    end

endmodule
