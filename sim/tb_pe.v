`timescale 1ns/1ps

module tb_pe;

    // --- DUT portları ---
    reg        clk;
    reg        rst;
    reg  [7:0] a_in;
    reg  [7:0] b_in;
    wire [7:0] a_out;
    wire [7:0] b_out;
    wire [31:0] acc_out;

    // --- DUT ---
    pe #(
        .DATA_WIDTH(8),
        .ACC_WIDTH(32)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .a_in    (a_in),
        .b_in    (b_in),
        .a_out   (a_out),
        .b_out   (b_out),
        .acc_out (acc_out)
    );

    // --- Saat: 10 ns periyot ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Test sayacı ---
    integer pass_count;
    integer fail_count;

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [63:0] test_id;  // test numarası (display için)
        begin
            if (actual === expected) begin
                $display("PASS [T%0d] acc_out=%0d", test_id, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [T%0d] acc_out=%0d (beklenen=%0d)", test_id, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // --- Reset ---
        rst  = 1;
        a_in = 0;
        b_in = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // -------------------------------------------------------
        // TEST 1: Tek adım MAC — 3×4 = 12
        // -------------------------------------------------------
        a_in = 8'd3;
        b_in = 8'd4;
        @(posedge clk); #1;
        check(acc_out, 32'd12, 1);

        // a_out / b_out iletimi kontrolü
        if (a_out === 8'd3 && b_out === 8'd4)
            $display("PASS [T1b] a_out=%0d b_out=%0d iletimi dogru", a_out, b_out);
        else begin
            $display("FAIL [T1b] a_out=%0d b_out=%0d (beklenen 3,4)", a_out, b_out);
            fail_count = fail_count + 1;
        end

        // -------------------------------------------------------
        // TEST 2: Birikimli toplam — 3×4 + 5×6 = 12 + 30 = 42
        // -------------------------------------------------------
        a_in = 8'd5;
        b_in = 8'd6;
        @(posedge clk); #1;
        check(acc_out, 32'd42, 2);

        // -------------------------------------------------------
        // TEST 3: Reset akümülatörü sıfırlar
        // -------------------------------------------------------
        rst = 1;
        @(posedge clk); #1;
        rst  = 0;
        a_in = 8'd0;
        b_in = 8'd0;
        #1;
        check(acc_out, 32'd0, 3);

        // -------------------------------------------------------
        // TEST 4: Overflow davranışı — a_in=255, b_in=255, 4 çevrim
        // Her çevrim 65025 eklenir. 32-bit max: 4_294_967_295
        // Overflow eşiği: ceil(4_294_967_295 / 65025) = 66050 çevrim
        // 4×4 array'de PE başına max 4 çevrim → overflow olmaz
        // -------------------------------------------------------
        rst = 1;
        @(posedge clk); #1;
        rst  = 0;
        a_in = 8'd255;
        b_in = 8'd255;

        @(posedge clk); #1;
        $display("INFO [T4] çevrim 1: acc_out=%0d (beklenen=65025)",  acc_out);
        check(acc_out, 32'd65025, 4);

        @(posedge clk); #1;
        $display("INFO [T4] çevrim 2: acc_out=%0d (beklenen=130050)", acc_out);
        check(acc_out, 32'd130050, 4);

        @(posedge clk); #1;
        $display("INFO [T4] çevrim 3: acc_out=%0d (beklenen=195075)", acc_out);
        check(acc_out, 32'd195075, 4);

        @(posedge clk); #1;
        $display("INFO [T4] çevrim 4: acc_out=%0d (beklenen=260100)", acc_out);
        check(acc_out, 32'd260100, 4);

        $display("BELGE: 4x4 array icin max birikme = 4 x 65025 = 260100");
        $display("BELGE: 32-bit sinir = 4294967295, overflow olmaz.");
        $display("BELGE: Overflow esigi = 66050 cevrim (normal calisma disinda).");

        // -------------------------------------------------------
        // Sonuç
        // -------------------------------------------------------
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
