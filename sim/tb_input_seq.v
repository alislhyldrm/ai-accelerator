`timescale 1ns/1ps

// tb_input_seq: input_seq modülü için testbench
//
// Kapsam: Preset 0 (A=I4, B=I4) ve Preset 1 (A=zigzag, B=I4)
//
// Zamanlama (start sonrası çevrim sayısı):
//   Çevrim 0-6 : LOAD, a_in/b_in skewed veri
//   Çevrim 7   : DONE, a_in/b_in=0, done=0
//   Çevrim 8   : IDLE, done=1  ← pulse burada
//   Çevrim 9   : IDLE, done=0
//
// Toplam: 4 × (7 skew + 2 done) = 36 kontrol
//
// Beklenen — Preset 0 (I4×I4, köşegen skew):
//   t=0: a=00000001 b=00000001
//   t=1: a=00000000 b=00000000
//   t=2: a=00000100 b=00000100  ← A[1][1]=1, B[1][1]=1
//   t=3: a=00000000 b=00000000
//   t=4: a=00010000 b=00010000  ← A[2][2]=1, B[2][2]=1
//   t=5: a=00000000 b=00000000
//   t=6: a=01000000 b=01000000  ← A[3][3]=1, B[3][3]=1
//
// Beklenen — Preset 1 (A=zigzag, B=I4):
//   t=0: a=00000001 b=00000001
//   t=1: a=00000502 b=00000000  ← A[0][1]=2,A[1][0]=5
//   t=2: a=00010603 b=00000100  ← A[0][2]=3,A[1][1]=6,A[2][0]=1
//   t=3: a=05020704 b=00000000  ← A[0][3]=4,A[1][2]=7,A[2][1]=2,A[3][0]=5
//   t=4: a=06030800 b=00010000  ← A[1][3]=8,A[2][2]=3,A[3][1]=6
//   t=5: a=07040000 b=00000000  ← A[2][3]=4,A[3][2]=7
//   t=6: a=08000000 b=01000000  ← A[3][3]=8

module tb_input_seq;

    // --- DUT portları ---
    reg        clk;
    reg        rst;
    reg        start;
    reg  [1:0] sw;
    wire [31:0] a_in;
    wire [31:0] b_in;
    wire        done;

    // --- DUT ---
    input_seq dut (
        .clk  (clk),
        .rst  (rst),
        .start(start),
        .sw   (sw),
        .a_in (a_in),
        .b_in (b_in),
        .done (done)
    );

    // --- Saat: 10 ns periyot ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test sayaçları ---
    integer pass_count;
    integer fail_count;

    // a_in ve b_in'i birlikte kontrol eder (1 pass/fail per cycle)
    task check_ab;
        input [31:0] exp_a;
        input [31:0] exp_b;
        input integer test_id;
        begin
            if (a_in === exp_a && b_in === exp_b) begin
                $display("PASS [T%0d] a=%08h b=%08h", test_id, a_in, b_in);
                pass_count = pass_count + 1;
            end else begin
                if (a_in !== exp_a)
                    $display("FAIL [T%0d] a_in=%08h (beklenen=%08h)",
                             test_id, a_in, exp_a);
                if (b_in !== exp_b)
                    $display("FAIL [T%0d] b_in=%08h (beklenen=%08h)",
                             test_id, b_in, exp_b);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_done_sig;
        input integer exp_done;
        input integer test_id;
        begin
            if (done === exp_done[0]) begin
                $display("PASS [T%0d] done=%0d", test_id, done);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [T%0d] done=%0d (beklenen=%0d)",
                         test_id, done, exp_done);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task do_reset;
        begin
            rst   = 1;
            start = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 0;
        end
    endtask

    // start=1 → posedge yakalanır → state=LOAD, cycle=0
    // Görev bittikten sonra: a_in/b_in t=0 verisini gösterir
    task send_start;
        begin
            start = 1;
            @(posedge clk); #1;
            start = 0;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst        = 1;
        start      = 0;
        sw         = 2'd0;

        do_reset;

        // ============================================================
        // SENARYO 1: Preset 0 — A=I4, B=I4
        //   Birim matris skewed besleme: sadece köşegen elemanlar gelir.
        //   a_in ve b_in her zaman eşit (I4 simetrik).
        //   done: t=6'dan 2 çevrim sonra (çevrim 8).
        // ============================================================
        $display("--- Senaryo 1: Preset 0 (A=I4, B=I4) ---");
        sw = 2'd0;

        send_start;
        check_ab(32'h00000001, 32'h00000001,  1); // t=0: A[0][0]=1, B[0][0]=1
        @(posedge clk); #1;
        check_ab(32'h00000000, 32'h00000000,  2); // t=1: tümü 0
        @(posedge clk); #1;
        check_ab(32'h00000100, 32'h00000100,  3); // t=2: A[1][1]=1, B[1][1]=1
        @(posedge clk); #1;
        check_ab(32'h00000000, 32'h00000000,  4); // t=3: tümü 0
        @(posedge clk); #1;
        check_ab(32'h00010000, 32'h00010000,  5); // t=4: A[2][2]=1, B[2][2]=1
        @(posedge clk); #1;
        check_ab(32'h00000000, 32'h00000000,  6); // t=5: tümü 0
        @(posedge clk); #1;
        check_ab(32'h01000000, 32'h01000000,  7); // t=6: A[3][3]=1, B[3][3]=1

        // t=6 sonrası: state→DONE (a_in/b_in=0), done henüz 0
        @(posedge clk); #1;
        // DONE→IDLE: done pulse
        @(posedge clk); #1;
        check_done_sig(1, 8);   // done=1 bekleniyor
        @(posedge clk); #1;
        check_done_sig(0, 9);   // done geri 0'a dönmeli

        do_reset;

        // ============================================================
        // SENARYO 2: Preset 1 — A=[[1,2,3,4],[5,6,7,8],[1,2,3,4],[5,6,7,8]], B=I4
        //   a_in'de satır değerleri diyagonalde kayar.
        //   b_in=I4 olduğundan Preset 0 ile aynı.
        // ============================================================
        $display("--- Senaryo 2: Preset 1 (A=zigzag, B=I4) ---");
        sw = 2'd1;

        send_start;
        check_ab(32'h00000001, 32'h00000001, 10); // t=0: A[0][0]=1
        @(posedge clk); #1;
        check_ab(32'h00000502, 32'h00000000, 11); // t=1: A[0][1]=2,A[1][0]=5
        @(posedge clk); #1;
        check_ab(32'h00010603, 32'h00000100, 12); // t=2: A[0][2]=3,A[1][1]=6,A[2][0]=1
        @(posedge clk); #1;
        check_ab(32'h05020704, 32'h00000000, 13); // t=3: tüm satır uç uca
        @(posedge clk); #1;
        check_ab(32'h06030800, 32'h00010000, 14); // t=4: A[1][3]=8,A[2][2]=3,A[3][1]=6
        @(posedge clk); #1;
        check_ab(32'h07040000, 32'h00000000, 15); // t=5: A[2][3]=4,A[3][2]=7
        @(posedge clk); #1;
        check_ab(32'h08000000, 32'h01000000, 16); // t=6: A[3][3]=8

        @(posedge clk); #1;
        @(posedge clk); #1;
        check_done_sig(1, 17);  // done pulse
        @(posedge clk); #1;
        check_done_sig(0, 18);  // done geri 0

        do_reset;

        // ============================================================
        // SENARYO 3: Preset 2 — A=Fibonacci, B=I4
        //   A=[[1,1,2,3],[5,8,13,21],[1,2,3,5],[8,13,21,34]], B=I4
        //   13=0x0D, 21=0x15, 34=0x22
        // ============================================================
        $display("--- Senaryo 3: Preset 2 (A=Fibonacci, B=I4) ---");
        sw = 2'd2;

        send_start;
        check_ab(32'h00000001, 32'h00000001, 19); // t=0: A[0][0]=1
        @(posedge clk); #1;
        check_ab(32'h00000501, 32'h00000000, 20); // t=1: A[0][1]=1,A[1][0]=5
        @(posedge clk); #1;
        check_ab(32'h00010802, 32'h00000100, 21); // t=2: A[0][2]=2,A[1][1]=8,A[2][0]=1
        @(posedge clk); #1;
        check_ab(32'h08020D03, 32'h00000000, 22); // t=3: A[0][3]=3,A[1][2]=13,A[2][1]=2,A[3][0]=8
        @(posedge clk); #1;
        check_ab(32'h0D031500, 32'h00010000, 23); // t=4: A[1][3]=21,A[2][2]=3,A[3][1]=13
        @(posedge clk); #1;
        check_ab(32'h15050000, 32'h00000000, 24); // t=5: A[2][3]=5,A[3][2]=21
        @(posedge clk); #1;
        check_ab(32'h22000000, 32'h01000000, 25); // t=6: A[3][3]=34

        @(posedge clk); #1;
        @(posedge clk); #1;
        check_done_sig(1, 26);
        @(posedge clk); #1;
        check_done_sig(0, 27);

        do_reset;

        // ============================================================
        // SENARYO 4: Preset 3 — A=döngüsel, B=döngüsel
        //   A=[[1,1,1,1],[2,2,2,2],[3,3,3,3],[4,4,4,4]]
        //   B=[[1,2,3,4],[1,2,3,4],[1,2,3,4],[1,2,3,4]]
        //   Her iki matris de sıfır içermiyor — tüm skew basamakları dolu.
        //   Beklenen: t=3'te a_in=b_in=32'h04030201 (tam dolu dalga)
        // ============================================================
        $display("--- Senaryo 4: Preset 3 (A=dongüsel, B=dongüsel) ---");
        sw = 2'd3;

        send_start;
        check_ab(32'h00000001, 32'h00000001, 28); // t=0: A[0][0]=1, B[0][0]=1
        @(posedge clk); #1;
        check_ab(32'h00000201, 32'h00000201, 29); // t=1: A[0][1]=1,A[1][0]=2; B[1][0]=1,B[0][1]=2
        @(posedge clk); #1;
        check_ab(32'h00030201, 32'h00030201, 30); // t=2: A[2][0]=3,A[1][1]=2,A[0][2]=1; B simetrik
        @(posedge clk); #1;
        check_ab(32'h04030201, 32'h04030201, 31); // t=3: tüm 4 basamak dolu
        @(posedge clk); #1;
        check_ab(32'h04030200, 32'h04030200, 32); // t=4: A[1][3]=2,A[2][2]=3,A[3][1]=4
        @(posedge clk); #1;
        check_ab(32'h04030000, 32'h04030000, 33); // t=5: A[2][3]=3,A[3][2]=4
        @(posedge clk); #1;
        check_ab(32'h04000000, 32'h04000000, 34); // t=6: A[3][3]=4, B[3][3]=4

        @(posedge clk); #1;
        @(posedge clk); #1;
        check_done_sig(1, 35);
        @(posedge clk); #1;
        check_done_sig(0, 36);

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
