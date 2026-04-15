`timescale 1ns/1ps

// tb_top: top modülü tam sistem testi — Preset 0 (A=I4, B=I4)
//
// Kapsam:
//   1. reset → auto-start → hesaplama → done_flag
//   2. C[r][c] doğrulama: köşegen=1, köşegen dışı=0
//   3. btnR/btnL ile sel_reg artış/azalış
//   4. sel_reg wrap: 15→0 ve 0→15
//   5. btnU ile show_upper toggle (dp değişimi)
//
// Simülasyon kolaylığı:
//   defparam ile btn_sync DEBOUNCE_COUNT=2 (normalde 1_000_000)
//   Toplam test süresi: ~600 çevrim × 10 ns = ~6 µs
//
// Beklenen sonuçlar — I4×I4=I4:
//   sel_reg ∈ {0,5,10,15} → hex_word=32'd1
//   sel_reg ∈ diğerleri  → hex_word=32'd0
//
// Test listesi (16 kontrol):
//   T1 : done_flag=1 (hesaplama tamamlandı)
//   T2 : sel_reg=0 (reset sonrası varsayılan)
//   T3 : C[0][0]=1
//   T4 : sel_reg=1 (btnR ×1)
//   T5 : C[0][1]=0
//   T6 : sel_reg=5 (btnR ×4 daha)
//   T7 : C[1][1]=1
//   T8 : sel_reg=15 (btnR ×10 daha)
//   T9 : C[3][3]=1
//   T10: sel_reg=14 (btnL ×1)
//   T11: C[3][2]=0
//   T12: dp=1 (show_upper=0, active-low söndürülmüş)
//   T13: dp=0 (show_upper=1 → btnU ×1, active-low yanar)
//   T14: dp=1 (show_upper=0 → btnU ×1 geri toggle)
//   T15: sel_reg=0 (wrap: 14→15→0)
//   T16: sel_reg=15 (wrap: 0→15)

module tb_top;

    // --- DUT portları ---
    reg        clk;
    reg        btnC, btnR, btnL, btnU;
    reg  [3:0] sw;
    wire [6:0] seg;
    wire       dp;
    wire [3:0] an;
    wire [15:0] led;

    // --- DUT ---
    top dut (
        .clk (clk),
        .btnC(btnC),
        .btnR(btnR),
        .btnL(btnL),
        .btnU(btnU),
        .sw  (sw),
        .seg (seg),
        .dp  (dp),
        .an  (an),
        .led (led)
    );

    // --- Debounce override: 1_000_000 → 2 (sim hızı) ---
    defparam dut.u_btn_r.DEBOUNCE_COUNT = 2;
    defparam dut.u_btn_l.DEBOUNCE_COUNT = 2;
    defparam dut.u_btn_u.DEBOUNCE_COUNT = 2;

    // --- Saat: 10 ns periyot (100 MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test sayaçları ---
    integer pass_count;
    integer fail_count;

    // 32-bit karşılaştırma
    task check_val;
        input [31:0] got;
        input [31:0] exp;
        input integer tid;
        begin
            if (got === exp) begin
                $display("PASS [T%0d] got=%08h", tid, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [T%0d] got=%08h beklenen=%08h", tid, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---------- Yardımcı görevler ----------

    // Reset: btnC=1 için 5 çevrim → btnC=0
    //   2-FF senkronizör: rst P2'de 1, P7'de 0
    //   auto-start: P8'de start=1 → input_seq IDLE→LOAD
    task do_reset;
        begin
            btnC = 1;
            repeat(5) @(posedge clk); #1;
            btnC = 0;
        end
    endtask

    // btnR: 1→6 çevrim bekle→0→6 çevrim bekle
    //   DEBOUNCE_COUNT=2 ile pulse 3. çevrimde ateşlenir
    task press_r;
        begin
            btnR = 1;
            repeat(6) @(posedge clk); #1;
            btnR = 0;
            repeat(6) @(posedge clk); #1;
        end
    endtask

    task press_l;
        begin
            btnL = 1;
            repeat(6) @(posedge clk); #1;
            btnL = 0;
            repeat(6) @(posedge clk); #1;
        end
    endtask

    task press_u;
        begin
            btnU = 1;
            repeat(6) @(posedge clk); #1;
            btnU = 0;
            repeat(6) @(posedge clk); #1;
        end
    endtask

    // ---------- Ana test akışı ----------
    initial begin
        pass_count = 0;
        fail_count = 0;
        btnC = 0; btnR = 0; btnL = 0; btnU = 0;
        sw   = 4'd0;  // Preset 0: A=I4, B=I4

        // =============================================================
        // TEST 1-2: Reset → auto-start → hesaplama → done
        //
        // Zamanlama (posedgeler):
        //   P8 : start=1 → IDLE→LOAD
        //   P9-P15 : LOAD (cycle 0-6)
        //   P16 : DONE → seq_done←1
        //   P17-P19 : 3-aşamalı drain shift
        //   P20 : latch_en=1 → c_out_latch örneklenir, done_flag=1
        //   C[3][3] son akümülasyonu P18'de — P20 < P18 olmadığından güvenli
        // =============================================================
        $display("--- TEST 1-2: reset/auto-start/done_flag ---");
        do_reset;
        // reset sonrası ~25 çevrim = P30 → P20'de done_flag PASS
        repeat(25) @(posedge clk); #1;

        check_val(led[15],   1, 1);  // T1: done_flag=1
        check_val(led[3:0],  0, 2);  // T2: sel_reg=0 (reset sonrası)

        // =============================================================
        // TEST 3: C[0][0] — sel_reg=0, PE[0][0], I4×I4=I4 → 1
        // =============================================================
        $display("--- TEST 3: C[0][0]=1 ---");
        check_val(dut.hex_word, 32'd1, 3);

        // =============================================================
        // TEST 4-5: btnR × 1 → sel_reg=1 → C[0][1]=0
        // =============================================================
        $display("--- TEST 4-5: btnR, sel_reg=1, C[0][1] ---");
        press_r;
        check_val(led[3:0],    1, 4);  // T4: sel_reg=1
        check_val(dut.hex_word, 32'd0, 5);  // T5: C[0][1]=0

        // =============================================================
        // TEST 6-7: btnR × 4 → sel_reg=5 → C[1][1]=1
        //   5 = 4'b0101 → r=1, c=1
        // =============================================================
        $display("--- TEST 6-7: btnR ×4, sel_reg=5, C[1][1] ---");
        repeat(4) press_r;
        check_val(led[3:0],    5, 6);  // T6: sel_reg=5
        check_val(dut.hex_word, 32'd1, 7);  // T7: C[1][1]=1

        // =============================================================
        // TEST 8-9: btnR × 10 → sel_reg=15 → C[3][3]=1
        //   15 = 4'b1111 → r=3, c=3
        // =============================================================
        $display("--- TEST 8-9: btnR ×10, sel_reg=15, C[3][3] ---");
        repeat(10) press_r;
        check_val(led[3:0],    15, 8);  // T8: sel_reg=15
        check_val(dut.hex_word, 32'd1, 9);  // T9: C[3][3]=1

        // =============================================================
        // TEST 10-11: btnL × 1 → sel_reg=14 → C[3][2]=0
        //   14 = 4'b1110 → r=3, c=2
        // =============================================================
        $display("--- TEST 10-11: btnL, sel_reg=14, C[3][2] ---");
        press_l;
        check_val(led[3:0],    14, 10);  // T10: sel_reg=14
        check_val(dut.hex_word, 32'd0, 11);  // T11: C[3][2]=0

        // =============================================================
        // TEST 12-14: show_upper toggle (dp değişimi)
        //   dp = ~show_upper (active-low: 1=söndürülmüş, 0=yanar)
        // =============================================================
        $display("--- TEST 12-14: show_upper/dp toggle ---");
        check_val(dp, 1'b1, 12);  // T12: show_upper=0 → dp=1 (söndürülmüş)
        press_u;
        check_val(dp, 1'b0, 13);  // T13: show_upper=1 → dp=0 (yanar)
        press_u;
        check_val(dp, 1'b1, 14);  // T14: show_upper=0 → dp=1 (geri döndü)

        // =============================================================
        // TEST 15: sel_reg wrap 15→0
        //   Şu an sel_reg=14, 2 press: 14→15→0
        // =============================================================
        $display("--- TEST 15: sel_reg wrap 15->0 ---");
        press_r;  // 14 → 15
        press_r;  // 15 → 0 (4-bit taşma)
        check_val(led[3:0], 0, 15);  // T15: sel_reg=0

        // =============================================================
        // TEST 16: sel_reg wrap 0→15
        //   1 press_l: 0 → 15 (4-bit alt taşma)
        // =============================================================
        $display("--- TEST 16: sel_reg wrap 0->15 ---");
        press_l;
        check_val(led[3:0], 15, 16);  // T16: sel_reg=15

        // =============================================================
        // Sonuç
        // =============================================================
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
