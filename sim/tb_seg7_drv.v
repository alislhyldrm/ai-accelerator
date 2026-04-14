`timescale 1ns/1ps

// Beklenen seg değerleri (active-low, {g,f,e,d,c,b,a}):
//   0→7'h40  1→7'h79  2→7'h24  3→7'h30  4→7'h19  5→7'h12
//   6→7'h02  7→7'h78  8→7'h00  9→7'h10  A→7'h08  B→7'h03
//   C→7'h46  D→7'h21  E→7'h06  F→7'h0E
//
// Senaryo başına 4 digit × 4 senaryo = 16 kontrol

module tb_seg7_drv;

    // --- DUT portları ---
    reg        clk;
    reg        rst;
    reg        tick;
    reg [15:0] hex_val;
    wire [6:0] seg;
    wire [3:0] an;

    // --- DUT ---
    seg7_drv dut (
        .clk    (clk),
        .rst    (rst),
        .tick   (tick),
        .hex_val(hex_val),
        .seg    (seg),
        .an     (an)
    );

    // --- Saat: 10 ns periyot ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test sayaçları ---
    integer pass_count;
    integer fail_count;

    // seg ve an'ı birlikte tek digit çıktısı olarak kontrol eder
    task check_digit;
        input [6:0] actual_seg;
        input [6:0] expected_seg;
        input [3:0] actual_an;
        input [3:0] expected_an;
        input integer test_id;
        begin
            if (actual_seg === expected_seg && actual_an === expected_an) begin
                $display("PASS [T%0d] an=%b seg=%h", test_id, actual_an, actual_seg);
                pass_count = pass_count + 1;
            end else begin
                if (actual_seg !== expected_seg)
                    $display("FAIL [T%0d] seg=%h (beklenen=%h)",
                             test_id, actual_seg, expected_seg);
                if (actual_an !== expected_an)
                    $display("FAIL [T%0d] an=%b (beklenen=%b)",
                             test_id, actual_an, expected_an);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // tick: bir saat çevrimi HIGH, ardından LOW → digit_sel +1
    task send_tick;
        begin
            tick = 1;
            @(posedge clk); #1;
            tick = 0;
        end
    endtask

    task do_reset;
        begin
            rst  = 1;
            tick = 0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 0;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst        = 1;
        tick       = 0;
        hex_val    = 16'h0000;

        do_reset;

        // ============================================================
        // SENARYO 1: hex_val=0x1234
        //   digit0=4(7'h19)  digit1=3(7'h30)  digit2=2(7'h24)  digit3=1(7'h79)
        // ============================================================
        $display("--- Senaryo 1: hex_val=16'h1234 ---");
        hex_val = 16'h1234; #1;

        check_digit(seg, 7'h19, an, 4'b1110, 1);   // digit_sel=0 → digit0=4
        send_tick;
        check_digit(seg, 7'h30, an, 4'b1101, 2);   // digit_sel=1 → digit1=3
        send_tick;
        check_digit(seg, 7'h24, an, 4'b1011, 3);   // digit_sel=2 → digit2=2
        send_tick;
        check_digit(seg, 7'h79, an, 4'b0111, 4);   // digit_sel=3 → digit3=1

        do_reset;

        // ============================================================
        // SENARYO 2: hex_val=0xABCD
        //   digit0=D(7'h21)  digit1=C(7'h46)  digit2=B(7'h03)  digit3=A(7'h08)
        // ============================================================
        $display("--- Senaryo 2: hex_val=16'hABCD ---");
        hex_val = 16'hABCD; #1;

        check_digit(seg, 7'h21, an, 4'b1110, 5);   // digit_sel=0 → digit0=D
        send_tick;
        check_digit(seg, 7'h46, an, 4'b1101, 6);   // digit_sel=1 → digit1=C
        send_tick;
        check_digit(seg, 7'h03, an, 4'b1011, 7);   // digit_sel=2 → digit2=B
        send_tick;
        check_digit(seg, 7'h08, an, 4'b0111, 8);   // digit_sel=3 → digit3=A

        do_reset;

        // ============================================================
        // SENARYO 3: hex_val=0x0000 — tüm haneler "0" (7'h40)
        // ============================================================
        $display("--- Senaryo 3: hex_val=16'h0000 ---");
        hex_val = 16'h0000; #1;

        check_digit(seg, 7'h40, an, 4'b1110,  9);
        send_tick;
        check_digit(seg, 7'h40, an, 4'b1101, 10);
        send_tick;
        check_digit(seg, 7'h40, an, 4'b1011, 11);
        send_tick;
        check_digit(seg, 7'h40, an, 4'b0111, 12);

        do_reset;

        // ============================================================
        // SENARYO 4: hex_val=0xFFFF — tüm haneler "F" (7'h0E)
        // ============================================================
        $display("--- Senaryo 4: hex_val=16'hFFFF ---");
        hex_val = 16'hFFFF; #1;

        check_digit(seg, 7'h0E, an, 4'b1110, 13);
        send_tick;
        check_digit(seg, 7'h0E, an, 4'b1101, 14);
        send_tick;
        check_digit(seg, 7'h0E, an, 4'b1011, 15);
        send_tick;
        check_digit(seg, 7'h0E, an, 4'b0111, 16);

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
